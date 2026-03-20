#!/usr/bin/env bash
# oracle-kit — Full Health Report
# Usage: bash health.sh

KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
[ -f "$KIT_ROOT/.env" ] && export $(grep -v '^#' "$KIT_ROOT/.env" | xargs) 2>/dev/null

ORACLE_PORT="${ORACLE_PORT:-47778}"
STUDIO_PORT="${STUDIO_PORT:-3000}"
MAW_PORT="${MAW_PORT:-3456}"
ORACLE_API="http://localhost:$ORACLE_PORT"

GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"
ok()   { echo -e "  ${GREEN}●${RESET} $1"; }
down() { echo -e "  ${RED}●${RESET} $1"; }
warn() { echo -e "  ${YELLOW}●${RESET} $1"; }
port_alive() { curl -s --max-time 2 "http://localhost:$1" > /dev/null 2>&1; }
has_docker()  { command -v docker &>/dev/null && docker info &>/dev/null 2>&1; }

echo ""
echo -e "${BOLD}☀️  oracle-kit — Health Report${RESET}  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# ── Services ─────────────────────────────────────────────────
echo -e "${BOLD}Services:${RESET}"
port_alive $ORACLE_PORT && ok "oracle API     http://localhost:$ORACLE_PORT" || down "oracle API     DOWN  → bash start.sh"
port_alive $STUDIO_PORT && ok "oracle-studio  http://localhost:$STUDIO_PORT"  || down "oracle-studio  DOWN  → bash start.sh"
port_alive $MAW_PORT    && ok "maw UI         http://localhost:$MAW_PORT"     || down "maw UI         DOWN  → bash start.sh"
pgrep -x ollama > /dev/null 2>&1 && ok "ollama         running (port 11434)" || warn "ollama         not running — no vector search"

# ── Oracle DB ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Oracle DB:${RESET}"
STATS=$(curl -s --max-time 3 "$ORACLE_API/api/stats" 2>/dev/null)
if [ -n "$STATS" ]; then
  echo "$STATS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
docs=d.get('total',d.get('total_documents','?'))
fts=d.get('fts_status','?')
vec_status=d.get('vector_status','?')
vecs=d.get('vectors',[])
total_v=sum(x.get('count',0) for x in vecs) if vecs else 0
types=d.get('by_type',{})
print(f'  Documents : {docs}')
print(f'  Vectors   : {total_v}  (FTS: {fts} | Vector: {vec_status})')
if types:
    print()
    print('  By type:')
    for t,c in sorted(types.items(), key=lambda x: -x[1]):
        print(f'    {t:<26}: {c}')
" 2>/dev/null || echo "  (parse error)"
else
  warn "oracle API not responding"
fi

# ── Docker ───────────────────────────────────────────────────
if has_docker; then
  echo ""
  echo -e "${BOLD}Docker containers:${RESET}"
  docker compose -f "$KIT_ROOT/docker-compose.yml" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null \
    | sed 's/^/  /' || echo "  (not running via Docker Compose)"
fi

# ── tmux ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}tmux:${RESET}"
if tmux ls 2>/dev/null | grep -q .; then
  tmux ls -F "  #{session_name} (#{session_windows} windows)" 2>/dev/null
  echo ""
  for sess in "oracle-kit" "05-database"; do
    tmux has-session -t "$sess" 2>/dev/null && {
      echo "  $sess windows:"
      tmux list-windows -t "$sess" -F "    #{window_index}: #{window_name}  [#{pane_current_command}]" 2>/dev/null
    }
  done
else
  echo "  (no sessions)"
fi

# ── maw Fleet ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}maw fleet:${RESET}"
maw ls 2>/dev/null | sed 's/^/  /' || echo "  (maw not available — run: bash setup.sh)"

# ── Crons ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Cron jobs:${RESET}"
CRONS=$(crontab -l 2>/dev/null | grep -E "oracle|dispatch|sync" | grep -v "^#")
if [ -n "$CRONS" ]; then
  echo "$CRONS" | sed 's/^/  /'
else
  warn "No oracle crons configured"
  echo ""
  echo "  Add these to crontab (crontab -e):"
  echo "    */5  * * * *  bash $KIT_ROOT/scripts/auto-dispatch.sh"
  echo "    */30 * * * *  bash $KIT_ROOT/scripts/index-all.sh"
fi

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  bash start.sh          # start all services"
echo "  bash start.sh status   # service status"
echo "  bash start.sh index    # re-index oracle repos"
echo ""
