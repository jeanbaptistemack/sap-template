#!/bin/bash
# =============================================================================
# Project-specific post-start — runs on every container start
# This file is owned by the project, NOT the template.
# Template updates will never overwrite this file.
# =============================================================================

WORKSPACE_DIR="${1:-$(pwd)}"

# Source .env for GITHUB_PERSONAL_ACCESS_TOKEN (needed to pull private repos)
if [ -f "$WORKSPACE_DIR/.env" ]; then
  set -a; source "$WORKSPACE_DIR/.env"; set +a
fi

# =============================================================================
# Helper: pull + rebuild an MCP server (background)
# Auto-detects project type: Python (pyproject.toml) or Node.js (package.json)
# =============================================================================
update_mcp_server() {
  local NAME="$1"
  local DEST="/opt/$NAME"
  local LOG="/tmp/$NAME.log"

  echo "[project] $NAME update (background)..."
  if [ -d "$DEST" ]; then
    (
      cd "$DEST"
      # Configure git to use token for private repos
      if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
        git remote set-url origin "$(git remote get-url origin | sed "s|https://github.com|https://${GITHUB_PERSONAL_ACCESS_TOKEN}@github.com|")" 2>/dev/null
      fi
      git pull --quiet 2>/dev/null

      if [ -f "pyproject.toml" ]; then
        uv sync --quiet 2>/dev/null && \
          echo "[$(date -Iseconds)] $NAME updated (Python)" >> "$LOG" || \
          echo "[$(date -Iseconds)] $NAME update failed" >> "$LOG"
      elif [ -f "package.json" ]; then
        npm ci --silent 2>/dev/null && \
          npm run build --silent 2>/dev/null && \
          echo "[$(date -Iseconds)] $NAME updated (Node.js)" >> "$LOG" || \
          echo "[$(date -Iseconds)] $NAME update failed" >> "$LOG"
      fi
    ) &
    echo "  running in background (log: $LOG)"
  else
    echo "  not installed — run Rebuild Container to install"
  fi
}

# =============================================================================
# SAP ADT MCP
# =============================================================================
update_mcp_server "sap-adt-mcp"

# =============================================================================
# SAP GUI MCP
# =============================================================================
update_mcp_server "sap-gui-mcp"
