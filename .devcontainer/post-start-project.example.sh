#!/bin/bash
# =============================================================================
# Project-specific post-start — runs on every container start
# This file is owned by the project, NOT the template.
# Template updates will never overwrite this file.
# =============================================================================

WORKSPACE_DIR="${1:-$(pwd)}"

# =============================================================================
# MCP SAP Docs — pull latest SAP doc repos + rebuild index (background)
# Runs in background so the container is available immediately.
# =============================================================================
echo "[project] MCP SAP Docs update (background)..."
MCP_SAP_DOCS="/opt/mcp-sap-docs"

if [ -d "$MCP_SAP_DOCS" ]; then
  (
    cd "$MCP_SAP_DOCS"
    git submodule update --remote --merge --quiet 2>/dev/null && \
      MCP_VARIANT=abap npm run build --silent 2>/dev/null && \
      echo "[$(date -Iseconds)] mcp-sap-docs index updated" >> /tmp/mcp-sap-docs.log || \
      echo "[$(date -Iseconds)] mcp-sap-docs update failed" >> /tmp/mcp-sap-docs.log
  ) &
  echo "  running in background (log: /tmp/mcp-sap-docs.log)"
else
  echo "  not installed — run Rebuild Container to install"
fi
