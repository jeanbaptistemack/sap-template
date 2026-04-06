#!/bin/bash
# =============================================================================
# Post-start script — runs on every container start (postStartCommand)
# Loads env, configures Claude, checks credentials & connectivity
# =============================================================================

WORKSPACE_DIR="${containerWorkspaceFolder:-$(pwd)}"
BASHRC="$HOME/.bashrc"

echo "============================================"
echo "  Post-start checks..."
echo "============================================"

# =============================================================================
# 1. Create tmp dirs
# =============================================================================
mkdir -p /tmp/claude-code

# =============================================================================
# 2. Claude alias (belt-and-suspenders alongside .claude/settings.json)
# =============================================================================
echo "[1/6] Claude alias..."
if ! grep -q "alias claude=" "$BASHRC" 2>/dev/null; then
  echo 'alias claude="claude --dangerously-skip-permissions"' >> "$BASHRC"
  echo "  alias added"
else
  echo "  already set"
fi

# =============================================================================
# 3. Project-level .claude.json (allowedTools + permissions)
# =============================================================================
echo "[2/6] Project Claude config..."
CLAUDE_PROJECT="$WORKSPACE_DIR/.claude.json"
if [ ! -f "$CLAUDE_PROJECT" ]; then
  cat > "$CLAUDE_PROJECT" << 'EOF'
{
  "allowedTools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "WebFetch", "WebSearch", "Task", "NotebookEdit"],
  "permissions": {
    "allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)"],
    "deny": []
  }
}
EOF
  echo "  .claude.json created"
else
  echo "  already exists"
fi

# =============================================================================
# 4. Secure sensitive files
# =============================================================================
echo "[3/6] Securing sensitive files..."
chmod 600 "$WORKSPACE_DIR/.env"       2>/dev/null && echo "  .env" || true
chmod 600 "$WORKSPACE_DIR/.mcp.json"  2>/dev/null && echo "  .mcp.json" || true
chmod 600 "$CLAUDE_PROJECT"           2>/dev/null && echo "  .claude.json" || true

# =============================================================================
# 5. Source .env
# =============================================================================
echo "[4/6] Loading .env..."
ENV_FILE="$WORKSPACE_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
  echo "  .env loaded"
else
  echo "  .env not found — skipping (create from .env.example if needed)"
fi

# =============================================================================
# 6. AWS credentials
# =============================================================================
echo "[5/6] AWS credentials..."
if command -v aws &>/dev/null; then
  if aws sts get-caller-identity &>/dev/null; then
    echo "  AWS: OK ($(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null))"
  else
    echo "  AWS: credentials not configured"
  fi
else
  echo "  AWS CLI not available, skipping"
fi

# =============================================================================
# 7. Azure credentials
# =============================================================================
echo "[6/6] Azure credentials..."
if command -v az &>/dev/null && [ -n "${AZURE_TENANT_ID:-}" ] && [ -n "${AZURE_CLIENT_SECRET:-}" ]; then
  az login --service-principal \
    --tenant "$AZURE_TENANT_ID" \
    --username "$AZURE_CLIENT_ID" \
    --password "$AZURE_CLIENT_SECRET" \
    --output none 2>/dev/null && \
    az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>/dev/null && \
    echo "  Azure: SP authenticated" || echo "  Azure: login failed"
else
  echo "  Azure: CLI or credentials not available, skipping"
fi

# =============================================================================
# 8. MCP SAP Docs — pull updates + rebuild index (background)
# Uncomment to enable: pulls latest SAP doc repos + rebuilds sqlite index.
# Runs in background so the container is available immediately.
# Requires step 5 in post-create.sh to be enabled first.
# =============================================================================
# echo "[7/7] MCP SAP Docs update (background)..."
# MCP_SAP_DOCS="/opt/mcp-sap-docs"
#
# if [ -d "$MCP_SAP_DOCS" ]; then
#   (
#     cd "$MCP_SAP_DOCS"
#     git submodule update --remote --merge --quiet 2>/dev/null && \
#       MCP_VARIANT=abap npm run build --silent 2>/dev/null && \
#       echo "[mcp-sap-docs] index updated" >> /tmp/mcp-sap-docs.log || \
#       echo "[mcp-sap-docs] update failed" >> /tmp/mcp-sap-docs.log
#   ) &
#   echo "  running in background (log: /tmp/mcp-sap-docs.log)"
# else
#   echo "  not installed — run Rebuild Container to install"
# fi

echo ""
echo "============================================"
echo "  Post-start checks complete!"
echo "============================================"
