#!/bin/bash
# =============================================================================
# Post-start script — runs on every container start (postStartCommand)
# =============================================================================

WORKSPACE_DIR="${containerWorkspaceFolder:-$(pwd)}"
BASHRC="$HOME/.bashrc"

# postStartCommand inherits a minimal system PATH and does not source ~/.bashrc,
# so user-installed CLIs (uv, cargo, claude) are invisible here and to any
# subprocess we launch (notably post-start-project.sh and the MCP servers it
# spawns). Re-export the same PATH that post-create.sh sets up.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.claude/bin:$PATH"

echo "============================================"
echo "  Post-start checks..."
echo "============================================"

mkdir -p /tmp/claude-code

# --- Claude alias ---
echo "[1/3] Claude alias..."
if ! grep -q "alias claude=" "$BASHRC" 2>/dev/null; then
  echo 'alias claude="claude --dangerously-skip-permissions"' >> "$BASHRC"
  echo "  alias added"
else
  echo "  already set"
fi

# --- Sécurisation des fichiers sensibles ---
echo "[2/3] Securing sensitive files..."
chmod 600 "$WORKSPACE_DIR/.env"      2>/dev/null && echo "  .env" || true
chmod 600 "$WORKSPACE_DIR/.mcp.json" 2>/dev/null && echo "  .mcp.json" || true

# --- Chargement du .env ---
echo "[3/3] Loading .env..."
if [ -f "$WORKSPACE_DIR/.env" ]; then
  set -a; source "$WORKSPACE_DIR/.env"; set +a
  echo "  .env loaded"
else
  echo "  .env not found — copy from .env.example if needed"
fi

# =============================================================================
# Project-specific checks (not managed by template — safe from copier update)
# =============================================================================
PROJECT_POST_START="$WORKSPACE_DIR/.devcontainer/post-start-project.sh"
if [ -f "$PROJECT_POST_START" ]; then
  echo ""
  echo "--- Project-specific post-start ---"
  bash "$PROJECT_POST_START" "$WORKSPACE_DIR"
else
  echo "  (no post-start-project.sh — see post-start-project.example.sh)"
fi

echo ""
echo "============================================"
echo "  Post-start complete!"
echo "============================================"
