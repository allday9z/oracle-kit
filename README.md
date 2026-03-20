# oracle-kit ☀️

> One repo to rule them all — setup, run, and manage the Oracle ecosystem.

Clone once. Run once. Everything works.

## Services

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| oracle API | 47778 | http://localhost:47778 | MCP + HTTP API (LanceDB + Ollama) |
| oracle-studio | 3000 | http://localhost:3000 | 3D knowledge map dashboard |
| maw UI | 3456 | http://localhost:3456 | Fleet + tmux orchestrator |

---

## Quick Start

### Option A — Docker (recommended)

```bash
git clone https://github.com/allday9z/oracle-kit
cd oracle-kit
cp .env.example .env   # edit if needed
bash start.sh docker
```

Open http://localhost:3000

### Option B — Native (macOS)

```bash
git clone https://github.com/allday9z/oracle-kit
cd oracle-kit
cp .env.example .env   # edit GHQ_ROOT + ORACLE_REPOS
bash setup.sh
```

### Requirements

**Docker mode**: Docker Desktop

**Native mode**: `bun`, `tmux`, `git`, `ollama` (optional, for vectors)

```bash
brew install bun tmux ollama
```

---

## Commands

```bash
bash start.sh            # auto-detect Docker/native, start all
bash start.sh docker     # force Docker Compose
bash start.sh native     # force native (tmux)
bash start.sh stop       # stop all services
bash start.sh status     # health check
bash start.sh logs api   # follow oracle API logs
bash start.sh build      # rebuild Docker images
bash start.sh index      # re-index oracle repos

bash health.sh           # full health report (services + DB + fleet + crons)
bash setup.sh            # full native setup (first time)
bash setup.sh --start    # start services only (already set up)
bash setup.sh --quick    # skip indexing + vault sync
```

---

## Configuration (.env)

```bash
cp .env.example .env
```

Key settings:

```env
# Paths
GHQ_ROOT=/Users/yourname/ghq/github.com
ORACLE_REPOS=allday9z/database-oracle allday9z/conductor-oracle

# Ports
ORACLE_PORT=47778
STUDIO_PORT=3000
MAW_PORT=3456

# Ollama (Mac: use host, Docker: use host.docker.internal)
OLLAMA_URL=http://host.docker.internal:11434

# Claude (for maw fleet)
CLAUDE_CODE_OAUTH_TOKEN=your-token-here
```

---

## Docker Details

```bash
# Start with Ollama container (instead of host Ollama)
docker compose --profile ollama up -d

# Rebuild images (after code changes)
bash start.sh build

# View logs
docker compose logs -f oracle-api
docker compose logs -f oracle-studio

# Stop
docker compose down

# Remove data (WARNING: deletes oracle DB)
docker compose down -v
```

### Volumes

| Volume | Contents |
|--------|----------|
| `oracle-data` | SQLite DB + LanceDB vectors (persisted) |
| `ollama-data` | Ollama models (if using `--profile ollama`) |

---

## Fleet (maw)

Fleet configs are in `fleet/`. Copy to maw-js when setting up:

```bash
cp fleet/*.json ~/ghq/github.com/Soul-Brews-Studio/maw-js/fleet/
```

| Session | Oracle |
|---------|--------|
| 05-database | database-oracle |
| 04-conductor | conductor-oracle |
| 03-m2manager | m2-manager-oracle |
| 07-devops | devops-oracle |

---

## Architecture

```
oracle-kit/
├── docker-compose.yml    # All services
├── Dockerfile.api        # oracle-v2 (API + MCP)
├── Dockerfile.studio     # oracle-studio (dashboard)
├── .env.example          # Config template
├── setup.sh              # Native setup
├── start.sh              # Smart start (Docker or native)
├── health.sh             # Full health report
├── fleet/                # maw fleet configs
└── scripts/
    ├── dispatch.sh       # Send task to oracle agent
    ├── auto-dispatch.sh  # Auto-dispatch GitHub Project items
    └── index-all.sh      # Re-index all oracle repos
```

---

## Oracle Family

Part of the allday9z Oracle ecosystem:

- **database-oracle** — Memory hub (THE SUN) → [allday9z/database-oracle](https://github.com/allday9z/database-oracle)
- **conductor-oracle** — Orchestrator → [allday9z/conductor-oracle](https://github.com/allday9z/conductor-oracle)
- **m2-manager-oracle** — Project manager → [allday9z/m2-manager-oracle](https://github.com/allday9z/m2-manager-oracle)

76+ Oracles. Form and Formless. Many bodies, one soul.
