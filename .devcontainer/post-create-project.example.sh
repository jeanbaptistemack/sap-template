#!/bin/bash
# =============================================================================
# Project-specific post-create — runs once after container build
# This file is owned by the project, NOT the template.
# Template updates will never overwrite this file.
# =============================================================================

WORKSPACE_DIR="${1:-$(pwd)}"

# Source .env for GITHUB_PERSONAL_ACCESS_TOKEN (needed to clone private repos)
if [ -f "$WORKSPACE_DIR/.env" ]; then
  set -a; source "$WORKSPACE_DIR/.env"; set +a
fi

# =============================================================================
# Helper: clone + build a Node.js MCP server into /opt/
# =============================================================================
install_mcp_server() {
  local NAME="$1"
  local REPO="$2"
  local DEST="/opt/$NAME"

  echo "[project] $NAME install..."
  if [ ! -d "$DEST" ]; then
    # Inject GitHub token into URL for private repos
    local CLONE_URL="$REPO"
    if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
      CLONE_URL="${REPO/https:\/\/github.com/https://${GITHUB_PERSONAL_ACCESS_TOKEN}@github.com}"
    fi

    sudo mkdir -p "$DEST" && sudo chown -R "$(whoami):$(whoami)" "$DEST"
    git clone "$CLONE_URL" "$DEST" 2>/dev/null || \
      { echo "  WARNING: clone failed for $NAME"; return 0; }
    cd "$DEST"
    npm ci --silent 2>/dev/null || npm install --silent 2>/dev/null || \
      echo "  WARNING: npm install failed for $NAME"
    npm run build 2>/dev/null && \
      echo "  $NAME installed" || echo "  WARNING: build failed for $NAME"
    cd "$WORKSPACE_DIR"
  else
    echo "  already installed at $DEST"
  fi
}

# =============================================================================
# SAP ADT MCP — ABAP Development Tools (ADT REST + RFC)
# =============================================================================
install_mcp_server "sap-adt-mcp" "https://github.com/jeanbaptistemack/sap-adt-mcp.git"

# =============================================================================
# SAP GUI MCP — SAP GUI automation
# =============================================================================
install_mcp_server "sap-gui-mcp" "https://github.com/jeanbaptistemack/sap-gui-mcp.git"
