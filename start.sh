#!/usr/bin/env bash
# ============================================================
# oracle-kit — Smart Start (Docker or Native)
# ============================================================
# Usage:
#   bash start.sh              # auto-detect Docker/native, start all
#   bash start.sh docker       # force Docker Compose
#   bash start.sh native       # force native (tmux)
#   bash start.sh stop         # stop all services
#   bash start.sh status       # health check
#   bash start.sh logs [svc]   # follow logs (api|studio|maw)
#   bash start.sh build        # rebuild Docker images
#   bash start.sh index        # re-index oracle repos

set -e
KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
[ -f "$KIT_ROOT/.env" ] && export $(grep -v '^#' "$KIT_ROOT/.env" | xargs) 2>/dev/null

ORACLE_PORT="${ORACLE_PORT:-47778}"
STUDIO_PORT="${STUDIO_PORT:-3000}"
MAW_PORT="${MAW_PORT:-3456}"

BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; RESET="\033[0m"
ok()   { echo -e "  ${GREEN}●${RESET} $1"; }
down() { echo -e "  ${RED}●${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }

port_alive() { curl -s --max-time 2 "http://localhost:$1" > /dev/null 2>&1; }
has_docker()  { command -v docker &>/dev/null && docker info &>/dev/null 2>&1; }

# Auto-detect mode
if has_docker; then MODE="${1:-docker}"; else MODE="${1:-native}"; fi

case "${1:-}" in
  docker|native|stop|status|logs|build|index|"") : ;;
  *) echo "Unknown command: $1"; exec "$0" --help; exit 1 ;;
esac

show_status() {
  echo ""
  echo -e "${BOLD}  Services:${RESET}"
  port_alive $ORACLE_PORT && ok "oracle API     http://localhost:$ORACLE_PORT" || down "oracle API     DOWN"
  port_alive $STUDIO_PORT && ok "oracle-studio  http://localhost:$STUDIO_PORT"  || down "oracle-studio  DOWN"
  port_alive $MAW_PORT    && ok "maw UI         http://localhost:$MAW_PORT"     || down "maw UI         DOWN"
  echo ""
}

# ── Commands ─────────────────────────────────────────────────

case "${1:-}" in

  build)
    echo "🐳 Building Docker images..."
    docker compose -f "$KIT_ROOT/docker-compose.yml" --env-file "$KIT_ROOT/.env" build --no-cache
    echo "✅ Images built"
    ;;

  stop)
    echo "🛑 Stopping all services..."
    if has_docker && docker compose -f "$KIT_ROOT/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
      docker compose -f "$KIT_ROOT/docker-compose.yml" --env-file "$KIT_ROOT/.env" down
      echo "  ✓ Docker services stopped"
    fi
    lsof -ti:$ORACLE_PORT | xargs kill -9 2>/dev/null && echo "  ✓ oracle API stopped" || true
    lsof -ti:$STUDIO_PORT | xargs kill -9 2>/dev/null && echo "  ✓ oracle-studio stopped" || true
    lsof -ti:$MAW_PORT    | xargs kill -9 2>/dev/null && echo "  ✓ maw UI stopped" || true
    ;;

  status)
    echo -e "${BOLD}☀️  oracle-kit Status${RESET}"
    show_status
    # DB stats
    STATS=$(curl -s --max-time 3 "http://localhost:$ORACLE_PORT/api/stats" 2>/dev/null)
    [ -n "$STATS" ] && echo "$STATS" | python3 -c "
import json,sys; d=json.load(sys.stdin)
docs=d.get('total',d.get('total_documents','?'))
vecs=sum(x.get('count',0) for x in d.get('vectors',[])) if d.get('vectors') else 0
print(f'  Oracle DB: {docs} docs | {vecs} vectors')
" 2>/dev/null || true
    # Docker status
    if has_docker; then
      echo ""
      echo -e "  ${BOLD}Docker:${RESET}"
      docker compose -f "$KIT_ROOT/docker-compose.yml" ps 2>/dev/null | sed 's/^/    /' || true
    fi
    ;;

  logs)
    SVC="${2:-oracle-api}"
    if has_docker && docker compose -f "$KIT_ROOT/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
      docker compose -f "$KIT_ROOT/docker-compose.yml" logs -f "$SVC"
    else
      # Native: tmux attach
      case "$SVC" in
        api|oracle-api)   tmux attach -t "oracle-kit:api" ;;
        studio|oracle-studio) tmux attach -t "oracle-kit:studio" ;;
        maw)              tmux attach -t "oracle-kit:maw" ;;
        *) echo "Unknown service: $SVC (api|studio|maw)" ;;
      esac
    fi
    ;;

  index)
    echo "📚 Re-indexing oracle repos..."
    GHQ_ROOT="${GHQ_ROOT:-/Users/$(whoami)/ghq/github.com}"
    ORACLE_V2="$GHQ_ROOT/allday9z/oracle-v2"
    IFS=' ' read -ra REPOS <<< "${ORACLE_REPOS:-allday9z/database-oracle}"
    cd "$ORACLE_V2"
    for repo in "${REPOS[@]}"; do
      repo_path="$GHQ_ROOT/$repo"
      [ -d "$repo_path/ψ" ] && {
        echo "  → $(basename "$repo")"
        ORACLE_VECTOR_DB=lancedb ORACLE_EMBEDDING_PROVIDER=ollama \
          ORACLE_VECTOR_DB_PATH="$HOME/.oracle/lancedb" \
          ORACLE_REPO_ROOT="$repo_path" \
          bun src/indexer.ts 2>&1 | grep -E "Indexed|Added" | tail -1
      } || echo "  ⚠ $repo: no ψ/ found"
    done
    echo "✅ Done"
    ;;

  docker)
    echo "🐳 Starting with Docker Compose..."
    [ ! -f "$KIT_ROOT/.env" ] && { warn "No .env file — copying from .env.example"; cp "$KIT_ROOT/.env.example" "$KIT_ROOT/.env"; }
    docker compose -f "$KIT_ROOT/docker-compose.yml" --env-file "$KIT_ROOT/.env" up -d
    echo ""
    echo "  Waiting for services..."
    sleep 5
    show_status
    ;;

  native|"")
    if [ "$MODE" = "docker" ] && has_docker; then exec "$0" docker; fi
    echo "🖥️  Starting natively (tmux)..."
    bash "$KIT_ROOT/setup.sh" --start
    ;;

  --help|-h)
    echo -e "${BOLD}oracle-kit — Smart Start${RESET}"
    echo ""
    echo "Usage: bash start.sh [command]"
    echo ""
    echo "  (none)       Auto-detect Docker/native, start all"
    echo "  docker       Force Docker Compose"
    echo "  native       Force native tmux"
    echo "  stop         Stop all services"
    echo "  status       Health check"
    echo "  logs [svc]   Follow logs (api|studio|maw)"
    echo "  build        Rebuild Docker images"
    echo "  index        Re-index oracle repos"
    ;;
esac
