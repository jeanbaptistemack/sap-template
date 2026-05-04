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
# Helper: pull + rebuild an MCP server (FOREGROUND on cold rebuild)
# Auto-detects project type: Python (pyproject.toml) or Node.js (package.json)
#
# Foreground (was background in v0.8.9): adds 5-30s to postStart on cold
# rebuild but eliminates the race with the daemon launch below — the venv
# is guaranteed ready and the log is reliably written.
# =============================================================================
update_mcp_server() {
  local NAME="$1"
  local DEST="/opt/$NAME"
  local LOG="/tmp/$NAME.log"

  echo "[project] $NAME update..."
  if [ ! -d "$DEST" ]; then
    echo "  not installed — run Rebuild Container to install"
    return 0
  fi

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
  cd "$WORKSPACE_DIR"
  echo "  done (log: $LOG)"
}

# =============================================================================
# SAP ADT MCP — pull/rebuild + launch streamable-http server
# =============================================================================
update_mcp_server "sap-adt-mcp"

# Since Sprint 4 PR-S4.2, sap-adt-mcp is a streamable-http server (no longer
# stdio): .mcp.json points at http://127.0.0.1:8000/mcp, so a process must
# actually listen there.
#
# `setsid -f` does fork+setsid+exec atomically: the daemon enters a new
# session BEFORE the parent returns, so it's immune to the SIGHUP/SIGTERM
# postStartCommand sends to its process group on exit. No nested `(...) &`,
# no `nohup`, no `disown`, no wait-loop — update_mcp_server above ran
# foreground so there's no concurrent `uv sync` to race against.
SAP_ADT_LOG="/tmp/sap-adt-mcp.log"
if [ -d "/opt/sap-adt-mcp" ] && ! pgrep -f "sap_adt_mcp" > /dev/null 2>&1; then
  echo "[project] sap-adt-mcp HTTP server starting..."
  cd /opt/sap-adt-mcp
  setsid -f uv run python -m sap_adt_mcp >> "$SAP_ADT_LOG" 2>&1 < /dev/null
  cd "$WORKSPACE_DIR"
  echo "  log: $SAP_ADT_LOG — endpoint: http://127.0.0.1:8000/mcp"
elif pgrep -f "sap_adt_mcp" > /dev/null 2>&1; then
  echo "[project] sap-adt-mcp HTTP server already running"
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
