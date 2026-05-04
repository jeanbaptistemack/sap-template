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
# SAP ADT MCP — pull/rebuild + launch streamable-http server
# =============================================================================
update_mcp_server "sap-adt-mcp"

# Since Sprint 4 PR-S4.2, sap-adt-mcp is a streamable-http server (no longer
# stdio): .mcp.json points at http://127.0.0.1:8000/mcp, so a process must
# actually listen there. Launch in background, after `uv sync` finishes.
SAP_ADT_LOG="/tmp/sap-adt-mcp.log"
if [ -d "/opt/sap-adt-mcp" ]; then
  if pgrep -f "sap_adt_mcp" > /dev/null 2>&1; then
    echo "[project] sap-adt-mcp HTTP server already running"
  else
    echo "[project] sap-adt-mcp HTTP server starting..."
    (
      for _ in 1 2 3 4 5 6; do
        pgrep -f "uv sync" > /dev/null 2>&1 || break
        sleep 1
      done
      cd /opt/sap-adt-mcp || exit 1
      nohup uv run python -m sap_adt_mcp >> "$SAP_ADT_LOG" 2>&1 &
      disown 2>/dev/null || true
    ) &
    echo "  log: $SAP_ADT_LOG — endpoint: http://127.0.0.1:8000/mcp"
  fi
fi

# =============================================================================
# SAP GUI MCP — remote (Windows VM via HTTP), nothing to start locally
# =============================================================================
echo "[project] sap-gui-mcp is remote (see .mcp.json) — no local start"

# =============================================================================
# IaC — Azure CLI session check
# =============================================================================
# echo "[iac] Azure CLI session check..."
# if command -v az &>/dev/null; then
#   az account show &>/dev/null 2>&1 \
#     && echo "  az logged in: $(az account show --query name -o tsv)" \
#     || echo "  az not logged in — run: just az-login"
# fi
