# .devcontainer architecture

## Lifecycle

```
devcontainer.json
  ├── initializeCommand      mkdir ~/.claude (host-side, before build)
  ├── onCreateCommand        git config + claude dirs (once, at image creation)
  ├── postCreateCommand  →   post-create.sh (once, after build)
  │                            └── post-create-project.sh (if exists)
  └── postStartCommand   →   post-start.sh (every container start)
                               └── post-start-project.sh (if exists)
```

## File ownership

| File | Owner | Updated by |
|---|---|---|
| `devcontainer.json` | template | `copier update` |
| `post-create.sh` | template | `copier update` |
| `post-start.sh` | template | `copier update` |
| `post-create-project.sh` | **project** | developer (never overwritten by template) |
| `post-start-project.sh` | **project** | developer (never overwritten by template) |
| `*.example.sh` | template | reference/documentation |
| `.mcp.json.example` | template | `copier update` (project root) |

## Template scripts (generic)

**post-create.sh** (runs once after build):
1. Install just (command runner)
2. Git LFS setup
3. Restore Claude auth from backup
4. Install uv + copier (Python toolchain)
5. Install Claude Code CLI
6. Python dependencies (`uv sync`)
7. Git submodules init

**post-start.sh** (runs on every start):
1. Claude alias (`--dangerously-skip-permissions` in .bashrc)
2. `chmod 600` on sensitive files (.env, .mcp.json)
3. Source `.env`

## Project-specific scripts

To add project-specific setup, create these files:

```bash
# Copy from examples
cp .devcontainer/post-create-project.example.sh .devcontainer/post-create-project.sh
cp .devcontainer/post-start-project.example.sh  .devcontainer/post-start-project.sh
```

These files receive `$WORKSPACE_DIR` as `$1` and are called at the end of the
template scripts. They are **never overwritten** by `copier update`.

## Available examples

### SAP MCP Servers (ADT + GUI)

`post-create-project.example.sh` and `post-start-project.example.sh` ship with
support for two MCP servers:

- [sap-adt-mcp](https://github.com/4ITServices/sap-adt-mcp) (>= 2.6.1) — SAP
  ABAP Development Tools (ADT REST API + RFC + HANA). Streamable-HTTP transport
  on `http://127.0.0.1:8000/mcp`. Read/write ABAP objects, syntax check,
  activation, transport management, abapGit bridge (Phase D), HANA queries.
- [sap-gui-mcp](https://github.com/jeanbaptistemack/sap-gui-mcp) — SAP GUI
  automation, runs remote on a Windows VM (referenced via `.mcp.json` only,
  no local install).

**post-create**: clones sap-adt-mcp into `/opt/sap-adt-mcp` and runs
`uv sync`. Symlinks the workspace `.env` so pydantic-settings finds SAP
credentials.

**post-start**: foreground `git pull` + `uv sync` of `/opt/sap-adt-mcp`,
then delegates to the canonical launcher `scripts/mcp-server.sh start`
shipped by sap-adt-mcp (manages PID file, log file at
`/opt/sap-adt-mcp/logs/server.log`, health check on
`/.well-known/oauth-protected-resource`, idempotent).

### Dual-stack: ECC EHP8 second instance (optional)

When the template is generated with `enable_ecc_stack: true`, a second
sap-adt-mcp instance can run side-by-side on port 8001, targeting SAP
ECC EHP8 (NetWeaver 7.50, ~155 tools — RAP / CDS / SRVB excluded). The
two instances cohabit on the same machine:

| Stack | Port | Launcher | Log | PID |
|---|---|---|---|---|
| S/4HANA 2023 FPS03 | 8000 | `scripts/mcp-server.sh` | `logs/server.log` | `.mcp-server.pid` |
| ECC EHP8 | 8001 | `scripts/mcp-server-ecc.sh` | `logs/server-ecc.log` | `.mcp-server-ecc.pid` |

To activate at runtime:

1. Copy `.env.ecc.example` → `.env.ecc` and fill in the ECC credentials.
2. Rebuild the container (or run `bash .devcontainer/post-start-project.sh`).
3. `.mcp.json` exposes both instances under names `sap-adt` (S/4) and
   `sap-adt-ecc` (ECC). Tools are addressable via `mcp__sap-adt__*` and
   `mcp__sap-adt-ecc__*` respectively.

The ECC launcher reads `/opt/sap-adt-mcp/.env.ecc` (symlinked from the
workspace by `post-create-project.sh`), overrides `MCP_PORT=8001`, then
delegates to the same canonical `mcp-server.sh`. To disable: delete
`.env.ecc` — the post-start block becomes a no-op.

ECC quirks (15 SAP-side + 3 ZMCP) are documented upstream in
`/opt/sap-adt-mcp/docs/ecc-ehp8-quirks.md`.

### MCP configuration (.mcp.json)

Copy `.mcp.json.example` to `.mcp.json` :

```bash
cp .mcp.json.example .mcp.json
```

Les credentials SAP (SAP_URL, SAP_USER, SAP_PASSWORD, etc.) sont lus automatiquement
depuis `.env` par pydantic-settings. Le `.mcp.json` ne contient que la config
structurelle (commandes, chemins). Pas de secrets dedans.

### Explicit MCP permissions

The template uses `bypassPermissions` by default. If you switch to explicit
permissions in `.claude/settings.json`, add:

```json
{
  "permissions": {
    "allow": [
      "mcp__sap-adt-mcp__*",
      "mcp__sap-gui-mcp__*"
    ]
  }
}
```
