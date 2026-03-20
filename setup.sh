#!/usr/bin/env bash
# ============================================================
# oracle-kit — Native Setup (no Docker)
# ============================================================
# Usage:
#   bash setup.sh           # full setup
#   bash setup.sh --quick   # skip indexing + vault
#   bash setup.sh --start   # start services only
# ============================================================

set -e
KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
GHQ_ROOT="${GHQ_ROOT:-/Users/$(whoami)/ghq/github.com}"
ORACLE_V2="$GHQ_ROOT/allday9z/oracle-v2"
ORACLE_STUDIO="$GHQ_ROOT/Soul-Brews-Studio/oracle-studio"
MAW_DIR="$GHQ_ROOT/Soul-Brews-Studio/maw-js"

# Load .env if exists
[ -f "$KIT_ROOT/.env" ] && export $(grep -v '^#' "$KIT_ROOT/.env" | xargs) 2>/dev/null

ORACLE_PORT="${ORACLE_PORT:-47778}"
STUDIO_PORT="${STUDIO_PORT:-3000}"
MAW_PORT="${MAW_PORT:-3456}"
LANCEDB_PATH="$HOME/.oracle/lancedb"
PRIMARY_REPO="${GHQ_ROOT}/${ORACLE_PRIMARY_REPO:-allday9z/database-oracle}"

QUICK=false; START_ONLY=false
[[ "$*" == *"--quick"* ]] && QUICK=true
[[ "$*" == *"--start"* ]] && START_ONLY=true

# Colors
BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
err()  { echo -e "  ${RED}✖${RESET}  $1"; }
step() { echo -e "\n${BOLD}── $1${RESET}"; }

port_alive() { curl -s --max-time 2 "http://localhost:$1" > /dev/null 2>&1; }
tmux_has_window() { tmux list-windows -t "$1" -F "#{window_name}" 2>/dev/null | grep -q "^$2$"; }
tmux_run() {
  local sess="$1" win="$2" cmd="$3"
  if ! tmux has-session -t "$sess" 2>/dev/null; then tmux new-session -d -s "$sess" -n "$win"
  elif ! tmux_has_window "$sess" "$win"; then tmux new-window -t "$sess" -n "$win"; fi
  tmux send-keys -t "$sess:$win" "$cmd" Enter
}

echo ""
echo -e "${BOLD}☀️  oracle-kit — Native Setup${RESET}"
echo "   GHQ Root: $GHQ_ROOT"
echo ""

if ! $START_ONLY; then

step "0 / 6  Prerequisites"
MISSING=false
for cmd in bun tmux git curl python3; do
  command -v "$cmd" &>/dev/null && ok "$cmd" || { err "$cmd NOT found"; MISSING=true; }
done
command -v ghq &>/dev/null && ok "ghq" || warn "ghq not found (install: brew install ghq) — will use git clone"
command -v ollama &>/dev/null && ok "ollama" || warn "ollama not found — vector search disabled"
command -v gh &>/dev/null && ok "gh CLI" || warn "gh not found — auto-dispatch disabled"
$MISSING && { echo ""; err "Fix missing tools above."; exit 1; }

step "1 / 6  oracle-v2 (API → :$ORACLE_PORT)"
if [ -d "$ORACLE_V2" ]; then
  ok "Already cloned"; cd "$ORACLE_V2" && git pull --quiet && ok "Pulled latest"
else
  mkdir -p "$(dirname "$ORACLE_V2")"
  git clone --depth 1 https://github.com/allday9z/oracle-v2 "$ORACLE_V2" && ok "Cloned"
fi
cd "$ORACLE_V2" && bun install --silent 2>/dev/null && ok "Dependencies ready"

step "2 / 6  oracle-studio (Dashboard → :$STUDIO_PORT)"
if [ -d "$ORACLE_STUDIO" ]; then
  ok "Already cloned"; cd "$ORACLE_STUDIO" && git pull --quiet && ok "Pulled latest"
else
  mkdir -p "$(dirname "$ORACLE_STUDIO")"
  git clone --depth 1 https://github.com/Soul-Brews-Studio/oracle-studio "$ORACLE_STUDIO" && ok "Cloned"
fi
cd "$ORACLE_STUDIO" && bun install --silent 2>/dev/null && ok "Dependencies ready"
[ ! -d "$ORACLE_STUDIO/dist" ] && { cd "$ORACLE_STUDIO" && bun run build 2>&1 | tail -2 && ok "Built"; } || ok "dist/ ready"

step "3 / 6  maw-js (Fleet UI → :$MAW_PORT)"
if [ -d "$MAW_DIR" ]; then
  ok "Already cloned"
else
  mkdir -p "$(dirname "$MAW_DIR")"
  git clone --depth 1 https://github.com/Soul-Brews-Studio/maw-js "$MAW_DIR" && ok "Cloned"
fi
cd "$MAW_DIR" && bun install --silent 2>/dev/null && ok "Dependencies ready"
[ ! -d "$MAW_DIR/dist-office" ] && { cd "$MAW_DIR" && bun run build:office 2>&1 | tail -2 && ok "Built frontend"; } || ok "dist-office/ ready"

# Sync fleet configs from kit
echo "  Syncing fleet configs..."
cp "$KIT_ROOT/fleet/"*.json "$MAW_DIR/fleet/" 2>/dev/null && ok "Fleet configs synced" || warn "No fleet configs in kit"

step "4 / 6  Ollama"
if command -v ollama &>/dev/null; then
  ollama list 2>/dev/null | grep -q "nomic-embed-text" && ok "nomic-embed-text ready" || { echo "  Pulling (274 MB)..."; ollama pull nomic-embed-text; ok "Pulled"; }
  pgrep -x ollama > /dev/null 2>&1 && ok "ollama running" || { ollama serve > /dev/null 2>&1 & sleep 2; ok "ollama started"; }
else
  warn "Skipped — FTS search only (no vectors)"
fi

step "5 / 6  Index oracle repos"
if ! $QUICK; then
  IFS=' ' read -ra REPOS <<< "${ORACLE_REPOS:-allday9z/database-oracle}"
  cd "$ORACLE_V2"
  for repo in "${REPOS[@]}"; do
    repo_path="$GHQ_ROOT/$repo"
    if [ -d "$repo_path/ψ" ]; then
      name=$(basename "$repo")
      result=$(ORACLE_VECTOR_DB=lancedb ORACLE_EMBEDDING_PROVIDER=ollama \
        ORACLE_VECTOR_DB_PATH="$LANCEDB_PATH" ORACLE_REPO_ROOT="$repo_path" \
        bun src/indexer.ts 2>&1 | grep -E "Added|Indexed [0-9]+" | tail -1)
      ok "$name: ${result:-indexed}"
    else
      warn "$repo: no ψ/ found (not cloned?)"
    fi
  done
else
  warn "Skipped (--quick)"
fi

fi  # end !START_ONLY

step "6 / 6  Start all services (tmux: oracle-kit)"
! tmux has-session 2>/dev/null && tmux new-session -d -s "oracle-kit" -n "api"

# oracle API
if port_alive $ORACLE_PORT; then ok "oracle API already running → http://localhost:$ORACLE_PORT"
else
  tmux_run "oracle-kit" "api" "cd $ORACLE_V2 && ORACLE_VECTOR_DB=lancedb ORACLE_EMBEDDING_PROVIDER=ollama ORACLE_VECTOR_DB_PATH=$LANCEDB_PATH ORACLE_REPO_ROOT=$PRIMARY_REPO ORACLE_PORT=$ORACLE_PORT bun src/server.ts"
  sleep 3
  port_alive $ORACLE_PORT && ok "oracle API → http://localhost:$ORACLE_PORT" || warn "API starting... (tmux attach -t oracle-kit:api)"
fi

# oracle-studio
if port_alive $STUDIO_PORT; then ok "oracle-studio already running → http://localhost:$STUDIO_PORT"
else
  [ -d "$ORACLE_STUDIO" ] && {
    tmux_run "oracle-kit" "studio" "cd $ORACLE_STUDIO && ORACLE_API_URL=http://localhost:$ORACLE_PORT PORT=$STUDIO_PORT bun run serve 2>/dev/null || ORACLE_API_URL=http://localhost:$ORACLE_PORT bun dev"
    sleep 3
    port_alive $STUDIO_PORT && ok "oracle-studio → http://localhost:$STUDIO_PORT" || warn "studio starting... (tmux attach -t oracle-kit:studio)"
  } || warn "oracle-studio not found — re-run without --start"
fi

# maw
if port_alive $MAW_PORT; then ok "maw UI already running → http://localhost:$MAW_PORT"
else
  [ -d "$MAW_DIR" ] && {
    tmux_run "oracle-kit" "maw" "cd $MAW_DIR && MAW_PORT=$MAW_PORT bun src/cli.ts serve"
    sleep 3
    port_alive $MAW_PORT && ok "maw UI → http://localhost:$MAW_PORT" || warn "maw starting... (tmux attach -t oracle-kit:maw)"
  } || warn "maw-js not found — re-run without --start"
fi

# ── Summary ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}☀️  oracle-kit ready!${RESET}"
echo ""
STATS=$(curl -s --max-time 3 "http://localhost:$ORACLE_PORT/api/stats" 2>/dev/null)
[ -n "$STATS" ] && {
  echo "$STATS" | python3 -c "
import json,sys; d=json.load(sys.stdin)
docs=d.get('total',d.get('total_documents','?'))
vecs=sum(x.get('count',0) for x in d.get('vectors',[])) if d.get('vectors') else 0
print(f'  Oracle DB: {docs} docs | {vecs} vectors')
" 2>/dev/null; echo ""
}
port_alive $ORACLE_PORT && echo -e "  ${GREEN}●${RESET} oracle API     http://localhost:$ORACLE_PORT" || echo -e "  ${RED}●${RESET} oracle API     DOWN"
port_alive $STUDIO_PORT && echo -e "  ${GREEN}●${RESET} oracle-studio  http://localhost:$STUDIO_PORT"  || echo -e "  ${RED}●${RESET} oracle-studio  DOWN"
port_alive $MAW_PORT    && echo -e "  ${GREEN}●${RESET} maw UI         http://localhost:$MAW_PORT"     || echo -e "  ${RED}●${RESET} maw UI         DOWN"
echo ""
echo "  bash health.sh       # full health report"
echo "  bash start.sh stop   # stop all services"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
