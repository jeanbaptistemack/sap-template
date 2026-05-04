# Changelog

All notable changes to this template are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Earlier releases (v0.1.0–v0.8.11) are documented in their git tag annotations
and commit messages; this changelog starts at v0.8.12.

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
