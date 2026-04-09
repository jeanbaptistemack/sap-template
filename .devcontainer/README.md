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

## Template scripts (generic)

**post-create.sh** (runs once after build):
1. Install Claude Code CLI (with ~/.claude.json backup restore)
2. Install uv + copier (Python toolchain)
3. Install GitHub CLI
4. `npm install` if `package.json` exists
5. `git submodule update --init --recursive` if `.gitmodules` exists
6. `npm install + build` in each submodule

**post-start.sh** (runs on every start):
1. Claude alias (`--dangerously-skip-permissions` in .bashrc)
2. Create `.claude.json` project permissions if missing
3. `chmod 600` on sensitive files (.env, .mcp.json, .claude.json)
4. Source `.env`
5. Check AWS credentials
6. Check Azure SP credentials

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

### MCP SAP Docs (ABAP variant)

`post-create-project.example.sh` and `post-start-project.example.sh` ship with
[marianfoo/mcp-sap-docs](https://github.com/marianfoo/mcp-sap-docs) support:

- **post-create**: clones the repo, indexes 25 SAP documentation repositories
  locally via BM25 + semantic embeddings (sqlite) in `/opt/mcp-sap-docs`
- **post-start**: pulls latest SAP doc repos and rebuilds the index in background
  (container is available immediately, log in `/tmp/mcp-sap-docs.log`)

Exposed MCP tools: `search`, `fetch`, `abap_feature_matrix`, `abap_lint`,
`sap_community_search`.
