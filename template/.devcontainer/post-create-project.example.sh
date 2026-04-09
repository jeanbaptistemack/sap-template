#!/bin/bash
# =============================================================================
# Project-specific post-create — runs once after container build
# This file is owned by the project, NOT the template.
# Template updates will never overwrite this file.
# =============================================================================

WORKSPACE_DIR="${1:-$(pwd)}"

# =============================================================================
# MCP SAP Docs (ABAP variant) — initial install
# Clones marianfoo/mcp-sap-docs, indexes ABAP documentation locally
# via BM25 + embeddings (sqlite). Requires Node.js feature in devcontainer.json.
# =============================================================================
echo "[project] MCP SAP Docs (ABAP) install..."
MCP_SAP_DOCS="/opt/mcp-sap-docs"

if [ ! -d "$MCP_SAP_DOCS" ]; then
  sudo git clone https://github.com/marianfoo/mcp-sap-docs.git "$MCP_SAP_DOCS" 2>/dev/null && \
    sudo chown -R "$(whoami):$(whoami)" "$MCP_SAP_DOCS" || \
    { echo "  WARNING: clone failed"; return 0 2>/dev/null || exit 0; }
  cd "$MCP_SAP_DOCS"
  echo "abap" > .mcp-variant
  npm ci --silent 2>/dev/null || echo "  WARNING: npm ci failed"
  MCP_VARIANT=abap npm run setup 2>/dev/null || echo "  WARNING: setup failed"
  MCP_VARIANT=abap npm run build 2>/dev/null && \
    echo "  mcp-sap-docs installed and indexed" || echo "  WARNING: build failed"
  cd "$WORKSPACE_DIR"
else
  echo "  already installed at $MCP_SAP_DOCS"
fi
