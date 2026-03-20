# oracle-kit ☀️

> One repo. One command. Everything works.

Zero manual config. Auto-detects your environment, starts all services, wakes all oracle agents.

## Services

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| oracle-api | 47778 | http://localhost:47778 | MCP + HTTP API (LanceDB + Ollama) |
| oracle-studio | 3000 | http://localhost:3000 | 3D knowledge map dashboard |
| maw UI | 3456 | http://localhost:3456 | Fleet + tmux orchestrator |
| Oracle agents | tmux | `maw ls` | Claude instances (conductor, m2manager, database...) |

---

## Quick Start (2 commands)

```bash
git clone https://github.com/allday9z/oracle-kit
cd oracle-kit
bash start.sh
```

That's it. `start.sh` will:
1. **Auto-detect** Claude token, GHQ root, Docker, Ollama
2. **Generate** `.env` + `maw.config.json` automatically
3. **Start** all Docker services (api + studio + maw)
4. **Clone** oracle repos if not present
5. **Wake** all oracle agents via `maw wake all`

---

## Requirements

### Docker mode (recommended)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- `bun` + `maw` (for oracle agents)

```bash
brew install bun
cd ~/ghq/github.com/Soul-Brews-Studio/maw-js && bun install && bun link
```

### Native mode (no Docker)
```bash
brew install bun tmux git ollama
```

---

## Commands

```bash
bash start.sh              # auto-detect + start everything
bash start.sh docker       # force Docker mode
bash start.sh native       # force native (tmux)
bash start.sh stop         # stop all services + agents
bash start.sh restart      # stop + start
bash start.sh status       # health check
bash start.sh wake         # re-wake oracle agents (maw wake all)
bash start.sh logs api     # follow oracle-api logs
bash start.sh logs studio  # follow oracle-studio logs
bash start.sh build        # rebuild Docker images
bash start.sh update       # pull latest + rebuild + restart
bash start.sh index        # re-index oracle repos into DB
bash start.sh config       # regenerate .env + maw.config.json

bash generate-config.sh    # auto-detect config only (no start)
bash health.sh             # full health report
```

---

## How Auto-Config Works

`generate-config.sh` detects everything automatically:

| Config | Source |
|--------|--------|
| `CLAUDE_CODE_OAUTH_TOKEN` | macOS Keychain → `Claude Code-credentials` |
| `GHQ_ROOT` | `ghq root` command |
| `ORACLE_REPOS` | Scans `$GHQ_ROOT/allday9z/` for oracle repos |
| `USE_DOCKER` | `docker info` availability check |
| `OLLAMA_URL` | Port 11434 alive check |
| Ports (47778/3000/3456) | `lsof` conflict check |

Run manually:
```bash
bash generate-config.sh           # generate .env (skip if exists)
bash generate-config.sh --force   # overwrite existing .env
```

---

## Docker Details

All 4 services in one compose:

```
oracle-init  →  oracle-api  →  oracle-studio
                             →  maw
```

```bash
# Start all (auto-pulls images + clones repos on first run)
docker compose up -d

# With Ollama in Docker (instead of host Ollama)
docker compose --profile ollama up -d

# Rebuild after code changes
bash start.sh build

# View logs
docker compose logs -f oracle-api
docker compose logs -f oracle-studio

# Stop + remove containers (keep data)
docker compose down

# Remove everything including data volumes (WARNING)
docker compose down -v
```

### Volumes

| Volume | Contents |
|--------|----------|
| `oracle-data` | SQLite DB + LanceDB vectors (persisted) |
| `oracle-repos` | Cloned oracle git repos (auto-updated) |
| `oracle-ollama-data` | Ollama model weights (`--profile ollama`) |

---

## Oracle Agents (tmux)

Oracle agents (Claude instances) run natively in **tmux** via `maw`. They cannot run inside Docker because they need interactive TTY + OAuth.

```bash
maw ls              # see all agents + status
maw wake all        # wake entire fleet
maw wake conductor  # wake specific agent
maw hey conductor "plan the next sprint"
maw view database   # attach to database-oracle tmux pane
maw overview        # war-room: all agents split view
```

Fleet configs (pre-configured):

| Session | Oracle | Role |
|---------|--------|------|
| 05-database | database-oracle | Memory hub (THE SUN) |
| 04-conductor | conductor-oracle | Orchestrator |
| 03-m2manager | m2-manager-oracle | Project manager |
| 07-devops | devops-oracle | DevOps |
| 01-phukhao | phukhao-oracle | — |

---

## Architecture

```
oracle-kit/
├── docker-compose.yml      # oracle-init + api + studio + maw (+ ollama profile)
├── Dockerfile.api          # oracle-v2 (bun, multi-stage)
├── Dockerfile.studio       # oracle-studio (bun serve)
├── Dockerfile.maw          # maw web UI (bun)
├── .env.example            # config template
├── generate-config.sh      # auto-detect everything → write .env
├── start.sh                # ultimate start: config → docker → agents
├── setup.sh                # native setup (no Docker)
├── health.sh               # full health report
├── fleet/                  # maw fleet configs (all oracles)
└── scripts/
    ├── dispatch.sh         # send task to oracle agent
    ├── auto-dispatch.sh    # auto-dispatch GitHub Project items
    └── index-all.sh        # re-index oracle repos
```

---

## Oracle Family

- **database-oracle** — Memory hub → [allday9z/database-oracle](https://github.com/allday9z/database-oracle)
- **conductor-oracle** — Orchestrator → [allday9z/conductor-oracle](https://github.com/allday9z/conductor-oracle)
- **m2-manager-oracle** — Project manager → [allday9z/m2-manager-oracle](https://github.com/allday9z/m2-manager-oracle)
- **oracle-v2** — MCP backend → [allday9z/oracle-v2](https://github.com/allday9z/oracle-v2)
- **oracle-studio** — Dashboard → [Soul-Brews-Studio/oracle-studio](https://github.com/Soul-Brews-Studio/oracle-studio)
- **maw-js** — Fleet orchestrator → [Soul-Brews-Studio/maw-js](https://github.com/Soul-Brews-Studio/maw-js)

76+ Oracles. Form and Formless. Many bodies, one soul.
