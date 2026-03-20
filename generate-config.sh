#!/usr/bin/env bash
# ============================================================
# oracle-kit — Auto Config Generator
# Detects EVERYTHING from your environment, no manual input.
# ============================================================
# Usage:
#   bash generate-config.sh           # auto-detect all
#   bash generate-config.sh --force   # overwrite existing .env
# ============================================================

set -e
KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; RED="\033[31m"; RESET="\033[0m"
ok()    { echo -e "  ${GREEN}✓${RESET}  $1"; }
found() { echo -e "  ${CYAN}→${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
ask()   { echo -e "  ${YELLOW}?${RESET}   $1"; }

FORCE=false; [[ "$*" == *"--force"* ]] && FORCE=true

echo ""
echo -e "${BOLD}☀️  oracle-kit — Auto Config Generator${RESET}"
echo ""

# Skip if .env already exists
if [ -f "$KIT_ROOT/.env" ] && ! $FORCE; then
  ok ".env already exists (use --force to regenerate)"
  exit 0
fi

echo -e "${BOLD}Detecting your environment...${RESET}"
echo ""

# ── 1. Claude OAuth Token ────────────────────────────────────
echo "🔑 Claude OAuth Token:"
CLAUDE_TOKEN=""

# Try macOS keychain first
if command -v security &>/dev/null; then
  CLAUDE_TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "
import sys,json
try:
    raw=sys.stdin.read().strip()
    d=json.loads(raw)
    data=d.get('claudeAiOauth',{})
    if isinstance(data,str):
        import ast; data=ast.literal_eval(data)
    print(data.get('accessToken',''))
except: print('')
" 2>/dev/null || true)
fi

# Try Claude config file
if [ -z "$CLAUDE_TOKEN" ] && [ -f "$HOME/.claude/credentials.json" ]; then
  CLAUDE_TOKEN=$(python3 -c "
import json
d=json.load(open('$HOME/.claude/credentials.json'))
print(d.get('claudeAiOauth',{}).get('accessToken','') or d.get('access_token',''))
" 2>/dev/null || true)
fi

# Try env
[ -z "$CLAUDE_TOKEN" ] && CLAUDE_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"

if [ -n "$CLAUDE_TOKEN" ]; then
  TOKEN_LEN=${#CLAUDE_TOKEN}
  ok "Found in keychain (${TOKEN_LEN} chars)"
else
  warn "Not found — you'll need to add CLAUDE_CODE_OAUTH_TOKEN to .env manually"
  warn "Get it: security find-generic-password -s 'Claude Code-credentials' -w"
fi

# ── 2. GHQ Root ──────────────────────────────────────────────
echo ""
echo "📁 GHQ Root:"
GHQ_ROOT=""
command -v ghq &>/dev/null && GHQ_ROOT=$(ghq root 2>/dev/null || true)
[ -z "$GHQ_ROOT" ] && [ -d "$HOME/ghq/github.com" ] && GHQ_ROOT="$HOME/ghq/github.com"
[ -z "$GHQ_ROOT" ] && [ -d "$HOME/ghq" ] && GHQ_ROOT="$HOME/ghq/github.com"
[ -z "$GHQ_ROOT" ] && GHQ_ROOT="/Users/$(whoami)/ghq/github.com"

if [[ "$GHQ_ROOT" == *"/github.com" ]]; then
  ok "GHQ Root: $GHQ_ROOT"
else
  GHQ_ROOT="$GHQ_ROOT/github.com"
  ok "GHQ Root: $GHQ_ROOT (appended /github.com)"
fi

# ── 3. Oracle repos present ──────────────────────────────────
echo ""
echo "🔍 Oracle repos:"
ORACLE_REPOS_LIST=""
for repo in allday9z/database-oracle allday9z/conductor-oracle allday9z/m2-manager-oracle allday9z/m2developer.com; do
  if [ -d "$GHQ_ROOT/$repo" ]; then
    ok "$repo"
    [ -n "$ORACLE_REPOS_LIST" ] && ORACLE_REPOS_LIST="$ORACLE_REPOS_LIST $repo" || ORACLE_REPOS_LIST="$repo"
  else
    warn "$repo (not cloned — will auto-clone on setup)"
    [ -n "$ORACLE_REPOS_LIST" ] && ORACLE_REPOS_LIST="$ORACLE_REPOS_LIST $repo" || ORACLE_REPOS_LIST="$repo"
  fi
done
# Default to core 3
ORACLE_REPOS="${ORACLE_REPOS_LIST:-allday9z/database-oracle allday9z/conductor-oracle allday9z/m2-manager-oracle}"

# ── 4. GitHub auth ───────────────────────────────────────────
echo ""
echo "🐙 GitHub:"
GITHUB_USER=""
if command -v gh &>/dev/null; then
  GITHUB_USER=$(gh api user --jq '.login' 2>/dev/null || true)
  [ -n "$GITHUB_USER" ] && ok "Authenticated as @$GITHUB_USER" || warn "Not authenticated (run: gh auth login)"
else
  warn "gh CLI not installed"
fi

# ── 5. Docker ────────────────────────────────────────────────
echo ""
echo "🐳 Docker:"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
  ok "Docker $DOCKER_VER"
  USE_DOCKER="true"
else
  warn "Docker not running — will use native mode"
  USE_DOCKER="false"
fi

# ── 6. Ollama ────────────────────────────────────────────────
echo ""
echo "🧠 Ollama:"
OLLAMA_URL="http://host.docker.internal:11434"
if pgrep -x ollama > /dev/null 2>&1 || curl -s --max-time 1 http://localhost:11434 > /dev/null 2>&1; then
  ok "Running on :11434"
  # Test if model available
  if curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if any('nomic' in m.get('name','') for m in d.get('models',[])) else 'missing')" 2>/dev/null | grep -q "ok"; then
    ok "nomic-embed-text model ready"
  else
    warn "nomic-embed-text not pulled yet (run: ollama pull nomic-embed-text)"
  fi
else
  warn "Not running (start: ollama serve)"
fi

# ── 7. Ports ─────────────────────────────────────────────────
echo ""
echo "🔌 Ports (checking availability):"
check_port() {
  local port=$1 name=$2
  if lsof -ti:$port > /dev/null 2>&1; then
    warn "$name :$port already in use"
    echo "$port"
  else
    ok "$name :$port available"
    echo "$port"
  fi
}
ORACLE_PORT=$(check_port 47778 "oracle-api" | tail -1)
STUDIO_PORT=$(check_port 3000 "oracle-studio" | tail -1)
MAW_PORT=$(check_port 3456 "maw" | tail -1)

# ── Write .env ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}Writing .env...${RESET}"

cat > "$KIT_ROOT/.env" << EOF
# ============================================================
# oracle-kit — Auto-generated $(date '+%Y-%m-%d %H:%M:%S %Z')
# Regenerate: bash generate-config.sh --force
# ============================================================

# ── Ports ────────────────────────────────────────────────────
ORACLE_PORT=$ORACLE_PORT
STUDIO_PORT=$STUDIO_PORT
MAW_PORT=$MAW_PORT

# ── Oracle Repos ─────────────────────────────────────────────
GHQ_ROOT=$GHQ_ROOT
ORACLE_REPOS=$ORACLE_REPOS
ORACLE_PRIMARY_REPO=allday9z/database-oracle

# ── Vector DB ────────────────────────────────────────────────
ORACLE_VECTOR_DB=lancedb
ORACLE_EMBEDDING_PROVIDER=ollama
OLLAMA_URL=$OLLAMA_URL

# ── Claude (for maw fleet + oracle agents) ───────────────────
CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_TOKEN

# ── GitHub ───────────────────────────────────────────────────
GITHUB_USER=${GITHUB_USER:-allday9z}
GITHUB_PROJECT_OWNER=allday9z
GITHUB_PROJECT_NUMBER=2

# ── Docker ───────────────────────────────────────────────────
USE_DOCKER=$USE_DOCKER
EOF

ok "Written → $KIT_ROOT/.env"

# ── Write maw.config.json ────────────────────────────────────
MAW_DIR="$GHQ_ROOT/Soul-Brews-Studio/maw-js"
if [ -d "$MAW_DIR" ]; then
  echo ""
  echo -e "${BOLD}Writing maw.config.json...${RESET}"
  # Only write if token exists and config doesn't have it
  if [ -n "$CLAUDE_TOKEN" ]; then
    cat > "$MAW_DIR/maw.config.json" << EOF
{
  "host": "local",
  "port": $MAW_PORT,
  "ghqRoot": "$GHQ_ROOT",
  "oracleUrl": "http://localhost:$ORACLE_PORT",
  "env": {
    "CLAUDE_CODE_OAUTH_TOKEN": "$CLAUDE_TOKEN"
  },
  "commands": {
    "default": "claude --dangerously-skip-permissions --continue",
    "*-oracle": "claude --dangerously-skip-permissions --continue"
  },
  "sessions": {
    "database": "05-database",
    "conductor": "04-conductor",
    "m2manager": "03-m2manager",
    "phukhao": "01-phukhao",
    "opensourcenatbrain": "02-opensourcenatbrain",
    "devops": "07-devops"
  }
}
EOF
    ok "maw.config.json updated with OAuth token"
  else
    warn "No Claude token — maw.config.json not updated"
  fi
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}✅ Config generated!${RESET}"
echo ""
echo "  .env written with:"
echo "    GHQ_ROOT     = $GHQ_ROOT"
echo "    ORACLE_PORT  = $ORACLE_PORT"
echo "    USE_DOCKER   = $USE_DOCKER"
echo "    Claude token = $([ -n "$CLAUDE_TOKEN" ] && echo "✓ found" || echo "✗ MISSING — add manually")"
echo ""
echo "  Next:"
echo "    bash start.sh    # start everything"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
