#!/usr/bin/env bash
# ============================================================
# oracle-kit — Ultimate Start Script
# ============================================================
# One command to rule them all:
#   bash start.sh
#
# Pipeline:
#   1. Auto-generate config (if missing)
#   2. Start Docker services (api + studio + maw)
#      OR native tmux (if no Docker)
#   3. Wait for health checks
#   4. Clone oracle repos (if missing)
#   5. maw wake all → start all oracle agents in tmux
#   6. Show status
#
# Usage:
#   bash start.sh              # full start (auto-detect)
#   bash start.sh docker       # force Docker mode
#   bash start.sh native       # force native mode
#   bash start.sh stop         # stop everything
#   bash start.sh restart      # stop + start
#   bash start.sh status       # health check
#   bash start.sh wake         # wake oracle agents only
#   bash start.sh logs [svc]   # follow logs (api|studio|maw)
#   bash start.sh build        # rebuild Docker images
#   bash start.sh update       # pull latest + rebuild
#   bash start.sh index        # re-index oracle repos
#   bash start.sh config       # regenerate .env + maw.config.json
# ============================================================

set -e
KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── Load / generate config ────────────────────────────────────
if [ ! -f "$KIT_ROOT/.env" ]; then
  echo "⚙️  No .env found — auto-generating config..."
  bash "$KIT_ROOT/generate-config.sh"
fi
export $(grep -v '^#' "$KIT_ROOT/.env" | grep -v '^$' | xargs) 2>/dev/null || true

ORACLE_PORT="${ORACLE_PORT:-47778}"
STUDIO_PORT="${STUDIO_PORT:-3000}"
MAW_PORT="${MAW_PORT:-3456}"
GHQ_ROOT="${GHQ_ROOT:-/Users/$(whoami)/ghq/github.com}"
USE_DOCKER="${USE_DOCKER:-false}"

# ── Colors + helpers ──────────────────────────────────────────
BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
ok()    { echo -e "  ${GREEN}✓${RESET}  $1"; }
fail()  { echo -e "  ${RED}✖${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
info()  { echo -e "  ${CYAN}→${RESET}  $1"; }
step()  { echo -e "\n${BOLD}$1${RESET}"; }

port_alive()  { curl -s --max-time 2 "http://localhost:$1" > /dev/null 2>&1; }
has_docker()  { command -v docker &>/dev/null && docker info &>/dev/null 2>&1; }
has_maw()     { command -v maw &>/dev/null; }

# Detect mode
if has_docker; then DEFAULT_MODE="docker"; else DEFAULT_MODE="native"; fi
MODE="${1:-$DEFAULT_MODE}"
[[ "$USE_DOCKER" == "false" ]] && [[ "$1" == "" ]] && MODE="native"

# ── Wait for service ─────────────────────────────────────────
wait_for_port() {
  local port=$1 name=$2 max=${3:-30}
  local i=0
  echo -n "    Waiting for $name"
  while ! port_alive $port; do
    sleep 2; i=$((i+2)); echo -n "."
    [ $i -ge $max ] && { echo " timeout"; return 1; }
  done
  echo " ready"
  return 0
}

# ── Clone oracle repos (native) ───────────────────────────────
clone_repos() {
  IFS=' ' read -ra REPOS <<< "${ORACLE_REPOS:-allday9z/database-oracle}"
  for repo in "${REPOS[@]}"; do
    repo_path="$GHQ_ROOT/$repo"
    if [ ! -d "$repo_path/.git" ]; then
      info "Cloning $repo..."
      mkdir -p "$(dirname "$repo_path")"
      git clone --depth 1 "https://github.com/$repo" "$repo_path" --quiet && ok "$repo cloned"
    fi
  done
}

# ── Start Docker services ─────────────────────────────────────
start_docker() {
  step "🐳 Docker Compose"
  docker compose -f "$KIT_ROOT/docker-compose.yml" --env-file "$KIT_ROOT/.env" up -d
  echo ""
  wait_for_port $ORACLE_PORT "oracle-api" 60
  wait_for_port $STUDIO_PORT "oracle-studio" 60
  wait_for_port $MAW_PORT    "maw" 60
}

# ── Start native services ─────────────────────────────────────
start_native() {
  step "🖥️  Native Services (tmux)"
  bash "$KIT_ROOT/setup.sh" --start
}

# ── Wake oracle agents ────────────────────────────────────────
wake_agents() {
  step "🤖 Wake Oracle Agents"
  if ! has_maw; then
    warn "maw not in PATH — install: cd maw-js && bun install && bun link"
    return
  fi

  # Sync fleet configs
  MAW_DIR="$GHQ_ROOT/Soul-Brews-Studio/maw-js"
  if [ -d "$MAW_DIR/fleet" ]; then
    cp "$KIT_ROOT/fleet/"*.json "$MAW_DIR/fleet/" 2>/dev/null || true
    ok "Fleet configs synced"
  fi

  # Ensure repos are cloned
  clone_repos

  # Wake all
  info "Running: maw wake all"
  maw wake all 2>/dev/null && ok "All agents signaled" || warn "Some agents may have failed to wake (check: maw ls)"
  sleep 3

  # Show fleet status
  echo ""
  maw ls 2>/dev/null | head -15 || true
}

# ── Show final status ─────────────────────────────────────────
show_status() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}☀️  oracle-kit ready!${RESET}"
  echo ""

  # DB stats
  STATS=$(curl -s --max-time 3 "http://localhost:$ORACLE_PORT/api/stats" 2>/dev/null || echo "")
  [ -n "$STATS" ] && echo "$STATS" | python3 -c "
import json,sys; d=json.load(sys.stdin)
docs=d.get('total',d.get('total_documents','?'))
vecs=sum(x.get('count',0) for x in d.get('vectors',[])) if d.get('vectors') else 0
print(f'  Oracle DB: {docs} docs | {vecs} vectors')
" 2>/dev/null && echo ""

  echo "  Services:"
  port_alive $ORACLE_PORT && echo -e "  ${GREEN}●${RESET} oracle API     http://localhost:$ORACLE_PORT" || echo -e "  ${RED}●${RESET} oracle API     DOWN"
  port_alive $STUDIO_PORT && echo -e "  ${GREEN}●${RESET} oracle-studio  http://localhost:$STUDIO_PORT"  || echo -e "  ${RED}●${RESET} oracle-studio  DOWN"
  port_alive $MAW_PORT    && echo -e "  ${GREEN}●${RESET} maw UI         http://localhost:$MAW_PORT"     || echo -e "  ${RED}●${RESET} maw UI         DOWN"
  echo ""
  echo "  Commands:"
  echo "    bash start.sh wake    # re-wake oracle agents"
  echo "    bash start.sh status  # service health"
  echo "    bash start.sh stop    # stop everything"
  echo "    bash health.sh        # full health report"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ═══════════════════════════════════════════════════════════════
# Commands
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in

  stop)
    step "🛑 Stopping everything..."
    # Docker
    if has_docker; then
      docker compose -f "$KIT_ROOT/docker-compose.yml" down 2>/dev/null && ok "Docker services stopped" || true
    fi
    # Native ports
    for port in $ORACLE_PORT $STUDIO_PORT $MAW_PORT; do
      lsof -ti:$port | xargs kill -9 2>/dev/null && ok "Port $port freed" || true
    done
    # Oracle agents
    has_maw && maw stop 2>/dev/null && ok "Oracle agents stopped" || true
    ok "Done"
    ;;

  restart)
    "$0" stop
    sleep 2
    "$0" "${@:2}"
    ;;

  status)
    echo -e "${BOLD}☀️  oracle-kit Status${RESET}"
    show_status
    has_docker && {
      echo ""
      echo -e "${BOLD}  Docker:${RESET}"
      docker compose -f "$KIT_ROOT/docker-compose.yml" ps 2>/dev/null | sed 's/^/    /' || true
    }
    ;;

  wake)
    wake_agents
    ;;

  logs)
    SVC="${2:-oracle-api}"
    if has_docker && docker compose -f "$KIT_ROOT/docker-compose.yml" ps -q "$SVC" 2>/dev/null | grep -q .; then
      docker compose -f "$KIT_ROOT/docker-compose.yml" logs -f "$SVC"
    else
      case "$SVC" in
        api|oracle-api)       tmux attach -t "oracle-kit:api" 2>/dev/null || tmux attach -t "05-database:database-oracle" ;;
        studio|oracle-studio) tmux attach -t "oracle-kit:studio" 2>/dev/null || tmux attach -t "05-database:studio" ;;
        maw|oracle-maw)       tmux attach -t "oracle-kit:maw" 2>/dev/null || tmux attach -t "05-database:maw" ;;
        *) echo "Services: api | studio | maw" ;;
      esac
    fi
    ;;

  build)
    step "🔨 Rebuilding Docker images..."
    docker compose -f "$KIT_ROOT/docker-compose.yml" --env-file "$KIT_ROOT/.env" build --no-cache
    ok "All images rebuilt"
    ;;

  update)
    step "⬆️  Updating oracle-kit..."
    # Pull this repo
    git -C "$KIT_ROOT" pull --quiet && ok "oracle-kit updated"
    # Rebuild images
    "$0" build
    "$0" restart
    ;;

  index)
    bash "$KIT_ROOT/scripts/index-all.sh"
    ;;

  config)
    bash "$KIT_ROOT/generate-config.sh" --force
    ;;

  docker)
    echo -e "${BOLD}☀️  oracle-kit starting (Docker mode)${RESET}"
    start_docker
    wake_agents
    show_status
    ;;

  native)
    echo -e "${BOLD}☀️  oracle-kit starting (Native mode)${RESET}"
    start_native
    wake_agents
    show_status
    ;;

  ""|--help|-h)
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
      echo -e "${BOLD}oracle-kit — Ultimate Start${RESET}"
      echo ""
      echo "Usage: bash start.sh [command]"
      echo ""
      echo "  (none)         Auto-detect Docker/native, start everything"
      echo "  docker         Force Docker Compose mode"
      echo "  native         Force native tmux mode"
      echo "  stop           Stop all services + agents"
      echo "  restart        Stop + start"
      echo "  status         Health check"
      echo "  wake           Wake oracle agents only (maw wake all)"
      echo "  logs [svc]     Follow logs (api|studio|maw)"
      echo "  build          Rebuild Docker images"
      echo "  update         Pull latest + rebuild + restart"
      echo "  index          Re-index oracle repos"
      echo "  config         Regenerate .env + maw.config.json"
      exit 0
    fi
    # Auto-start
    echo -e "${BOLD}☀️  oracle-kit — Starting (mode: $MODE)${RESET}"
    if [ "$MODE" = "docker" ]; then
      start_docker
    else
      start_native
    fi
    wake_agents
    show_status
    ;;

esac
