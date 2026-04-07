#!/bin/bash
# =============================================================================
# Post-start script — runs on every container start (postStartCommand)
# =============================================================================

WORKSPACE_DIR="${containerWorkspaceFolder:-$(pwd)}"
BASHRC="$HOME/.bashrc"

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

echo ""
echo "============================================"
echo "  Post-start complete!"
echo "============================================"
