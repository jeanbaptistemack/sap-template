#!/bin/bash
# =============================================================================
# Project-specific post-start — runs on every container start
# This file is owned by the project, NOT the template.
# Template updates will never overwrite this file.
# =============================================================================

WORKSPACE_DIR="${1:-$(pwd)}"

# =============================================================================
# Helper: pull + rebuild a Node.js MCP server (background)
# =============================================================================
update_mcp_server() {
  local NAME="$1"
  local DEST="/opt/$NAME"
  local LOG="/tmp/$NAME.log"

  echo "[project] $NAME update (background)..."
  if [ -d "$DEST" ]; then
    (
      cd "$DEST"
      git pull --quiet 2>/dev/null && \
        npm ci --silent 2>/dev/null && \
        npm run build --silent 2>/dev/null && \
        echo "[$(date -Iseconds)] $NAME updated" >> "$LOG" || \
        echo "[$(date -Iseconds)] $NAME update failed" >> "$LOG"
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
