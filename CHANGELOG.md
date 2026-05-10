# Changelog

All notable changes to this template are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Earlier releases (v0.1.0–v0.8.11) are documented in their git tag annotations
and commit messages; this changelog starts at v0.8.12.

## [0.8.13] — 2026-05-10

### Changed

- Bump sap-adt-mcp deployment to **v2.6.1+**. Repository moved from
  `jeanbaptistemack/sap-adt-mcp` to `4ITServices/sap-adt-mcp`.
  - `post-create-project.example.sh` clones the new origin URL.
  - `.devcontainer/README.md` updates URL and describes the new launch
    flow / log path.
- `post-start-project.example.sh` delegates to the canonical launcher
  shipped by sap-adt-mcp itself: `scripts/mcp-server.sh start`. The
  script handles PID file, log file (`/opt/sap-adt-mcp/logs/server.log`),
  health check on `/.well-known/oauth-protected-resource`, and is
  idempotent. Drops our local `setsid -f uv run …` block — the v2.x
  upstream script does the same detachment and adds health-wait + PID
  management.

### Added

- `.env.example.jinja` (mcp-server projects): optional
  `VOYAGE_API_KEY` / `OPENAI_API_KEY` (commented) for sap-adt-mcp's
  offline SAP Docs semantic search. Without them, sap-adt-mcp falls
  back to BM25 (plain-text) automatically.

### Notes

- Phase D (split of `ZCL_MCP_ICF` into 3 classes) is handled SAP-side
  via `bridge_install_offline` / `bridge_migrate_v2` MCP tools — the
  template does not ship ABAP bootstrap scripts for ZMCP, so no change
  needed here. Existing downstream projects with the legacy mono-class
  in their SAP system should run `bridge_migrate_v2 confirm:true`.
- `SAP_STACK` / `SAP_DB` are auto-detected by sap-adt-mcp at lifespan
  startup; not added to `.env.example` to avoid inventing config that
  isn't in the canonical sap-adt-mcp `.env.example`.

## [0.8.12] — 2026-05-04

### Fixed

- `devcontainer.json` now declares `remoteUser: "vscode"`,
  `userEnvProbe: "loginShell"`, and `containerEnv.HOME: "/home/vscode"` so
  `$HOME` is invariant across all lifecycle stages (Feature install, hooks,
  attached terminals, orphaned daemons). The previous reliance on the
  toolchain to inject HOME caused intermittent empty-`$HOME` expansions in
  `postStartCommand`, which broke every PATH lookup downstream.
- `post-start-project.example.sh` refactored: the `update_mcp_server` helper
  now runs **foreground** (was a `(...) &` subshell), and the daemon launch
  uses `setsid -f` (atomic fork+setsid+exec) instead of the
  `setsid nohup ... </dev/null & + disown` chain wrapped in `(...) &`.
  Together this eliminates the race between concurrent `uv sync` and the
  HTTP server start, and the daemon enters its new session **before** the
  parent returns — so SIGHUP/SIGTERM from the postStart wrapper never
  reaches it.

### Notes

- Resolves the chain of cold-rebuild MCP startup failures tracked in
  v0.8.7–v0.8.11. Each prior fix addressed one symptom (transport,
  symlink, setsid, PATH, HOME) but exposed the next; v0.8.12 fixes the
  underlying invariants once.
- General pattern for any future devcontainer daemon: declare invariants
  in `containerEnv` (not `remoteEnv`, which is unset during lifecycle
  hooks), and launch with `setsid -f` (not nested background subshells).
