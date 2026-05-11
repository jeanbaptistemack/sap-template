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

# Since v2.x sap-adt-mcp ships its own canonical launcher at
# scripts/mcp-server.sh — it manages PID file, log file (logs/server.log),
# health check on /.well-known/oauth-protected-resource, and is idempotent
# (start = no-op if already running). Prefer it over a custom setsid call.
SAP_ADT_LAUNCHER="/opt/sap-adt-mcp/scripts/mcp-server.sh"
if [ -x "$SAP_ADT_LAUNCHER" ]; then
  "$SAP_ADT_LAUNCHER" start
elif [ -d "/opt/sap-adt-mcp" ]; then
  echo "[project] sap-adt-mcp present but scripts/mcp-server.sh missing —"
  echo "  upgrade /opt/sap-adt-mcp to v2.x (4ITServices/sap-adt-mcp >= 2.6.1)"
fi

# Optional second instance targeting SAP ECC EHP8 on port 8001. Only fires
# if both the ECC launcher and .env.ecc exist (so the dual-stack stays
# fully opt-in: drop .env.ecc → only S/4 starts on rebuild).
SAP_ADT_ECC_LAUNCHER="/opt/sap-adt-mcp/scripts/mcp-server-ecc.sh"
if [ -f "/opt/sap-adt-mcp/.env.ecc" ] && [ -x "$SAP_ADT_ECC_LAUNCHER" ]; then
  "$SAP_ADT_ECC_LAUNCHER" start
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
