#!/bin/bash
# =============================================================================
# Post-create script — runs once after container build (postCreateCommand)
# =============================================================================
# No set -e — each step handles its own errors to avoid cascading failures

WORKSPACE_DIR="${containerWorkspaceFolder:-$(pwd)}"
cd "$WORKSPACE_DIR"

echo "============================================"
echo "  Post-create setup starting..."
echo "============================================"

# =============================================================================
# 1. Install Claude Code CLI
# =============================================================================
echo "[1/5] Installing Claude Code CLI..."
if command -v claude &>/dev/null; then
  echo "  claude found at $(which claude)"
else
  echo "  claude not found, installing..."
  curl -fsSL https://claude.ai/install.sh | bash || \
    npm install -g @anthropic-ai/claude-code 2>/dev/null || \
    echo "  WARNING: install failed — run manually"
fi
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"' >> ~/.bashrc

# Restore ~/.claude.json from backup if missing (created by Claude installer)
if [ ! -f "$HOME/.claude.json" ]; then
  BACKUP=$(ls "$HOME/.claude/backups/.claude.json.backup."* 2>/dev/null | sort | tail -1)
  if [ -n "$BACKUP" ]; then
    cp "$BACKUP" "$HOME/.claude.json"
    echo "  ~/.claude.json restored from backup"
  fi
fi

# =============================================================================
# 2. npm install (if package.json exists)
# =============================================================================
echo "[2/5] Project dependencies..."
if [ -f "$WORKSPACE_DIR/package.json" ]; then
  npm install --silent 2>/dev/null && echo "  npm install done" || echo "  WARNING: npm install failed"
else
  echo "  no package.json — skipping"
fi

# =============================================================================
# 3. Git submodules (no-op if no .gitmodules)
# =============================================================================
echo "[3/5] Git submodules..."
if [ -f "$WORKSPACE_DIR/.gitmodules" ]; then
  git submodule update --init --recursive 2>/dev/null && \
    echo "  submodules initialized" || echo "  WARNING: submodule init failed"
else
  echo "  no .gitmodules — skipping"
fi

# =============================================================================
# 4. npm install in submodules (if any have package.json)
# =============================================================================
echo "[4/5] Submodule dependencies..."
if [ -f "$WORKSPACE_DIR/.gitmodules" ]; then
  git submodule foreach --quiet \
    'if [ -f package.json ]; then echo "  Building $name..."; npm install --silent && npm run build 2>/dev/null && echo "    OK" || echo "    WARNING: build failed"; fi' \
    2>/dev/null || true
else
  echo "  no submodules — skipping"
fi

# =============================================================================
# 5. MCP SAP Docs (ABAP variant) — initial install
# Uncomment to enable: clones marianfoo/mcp-sap-docs, indexes ABAP documentation
# locally via BM25 + embeddings (sqlite). Requires Node.js (feature already added).
# =============================================================================
# echo "[5/5] MCP SAP Docs (ABAP)..."
# MCP_SAP_DOCS="/opt/mcp-sap-docs"
#
# if [ ! -d "$MCP_SAP_DOCS" ]; then
#   sudo git clone https://github.com/marianfoo/mcp-sap-docs.git "$MCP_SAP_DOCS" 2>/dev/null && \
#     sudo chown -R "$(whoami):$(whoami)" "$MCP_SAP_DOCS" || \
#     { echo "  WARNING: clone failed"; exit 0; }
#   cd "$MCP_SAP_DOCS"
#   echo "abap" > .mcp-variant
#   npm ci --silent 2>/dev/null || echo "  WARNING: npm ci failed"
#   MCP_VARIANT=abap npm run setup 2>/dev/null || echo "  WARNING: setup failed"
#   MCP_VARIANT=abap npm run build 2>/dev/null && \
#     echo "  mcp-sap-docs installed and indexed" || echo "  WARNING: build failed"
#   cd "$WORKSPACE_DIR"
# else
#   echo "  already installed at $MCP_SAP_DOCS"
# fi

echo ""
echo "============================================"
echo "  Post-create setup complete!"
echo "============================================"
