#!/usr/bin/env bash
# auto-dispatch.sh — Check GitHub project and dispatch pending tasks to agents
# Runs on session start + cron every 5 min
# Usage: ./auto-dispatch.sh [--wake]

export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ORACLE_API="http://localhost:47778"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
WAKE_MODE="${1:-}"

# ── Agent → maw session mapping ──────────────────────────────────────
agent_session() {
  case "$1" in
    m2-manager-oracle|m2manager) echo "03-m2manager" ;;
    conductor-oracle|conductor)  echo "04-conductor" ;;
    database-oracle|database)    echo "05-database"  ;;
    *) echo "" ;;
  esac
}

# maw target name (for maw hey)
agent_maw() {
  case "$1" in
    m2-manager-oracle|m2manager) echo "m2manager" ;;
    conductor-oracle|conductor)  echo "conductor" ;;
    database-oracle|database)    echo "database"  ;;
    *) echo "$1" ;;
  esac
}

echo "🤖 auto-dispatch.sh — $TIMESTAMP"
echo ""

# ── Step 0: Wake all agents if --wake flag ────────────────────────────
if [ "$WAKE_MODE" = "--wake" ]; then
  echo "⚡ Waking all oracle agents..."
  maw wake all 2>/dev/null
  sleep 3
fi

# ── Step 1: Fetch GitHub project items ───────────────────────────────
echo "📋 Checking GitHub project #2 (M2Developer Agent Team)..."

ITEMS=$(gh project item-list 2 --owner allday9z --format json 2>/dev/null)
if [ -z "$ITEMS" ]; then
  echo "  ⚠️  Could not fetch project items"
  exit 1
fi

# ── Step 2: Find Backlog / Ready items in m2developer.com ─────────────
PENDING=$(echo "$ITEMS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('items', [])
result = []
for item in items:
  status = item.get('status', '')
  repo = item.get('repository', '')
  if status in ('Backlog', 'Ready', 'In Progress') and 'm2developer.com' in repo:
    num = item['content']['number']
    title = item['content']['title']
    body = item['content'].get('body', '')
    # Extract agent hint from body
    agent = ''
    for line in body.split('\n'):
      if '**Agent**:' in line:
        agent = line.split('**Agent**:')[1].strip()
        break
    result.append({'number': num, 'title': title, 'agent': agent, 'status': status})
for r in result:
  print(f\"{r['number']}|{r['status']}|{r['agent']}|{r['title']}\")
" 2>/dev/null)

if [ -z "$PENDING" ]; then
  echo "  ✅ No pending items — all done!"
  curl -s -X POST "$ORACLE_API/api/thread" \
    -H "Content-Type: application/json" \
    -d "{\"threadId\": 3, \"message\": \"AUTO-DISPATCH:$TIMESTAMP STATUS:no pending tasks, all project items done\", \"role\": \"claude\"}" > /dev/null 2>&1
  exit 0
fi

echo ""
echo "📌 Pending items:"
echo "$PENDING" | while IFS='|' read num status agent title; do
  echo "  #$num [$status] → $agent: $title"
done

# ── Step 3: Dispatch each pending item to its assigned agent ──────────
echo ""
echo "📡 Dispatching tasks..."

echo "$PENDING" | while IFS='|' read num status agent title; do
  if [ -z "$agent" ]; then
    echo "  ⚠️  #$num has no assigned agent — skipping"
    continue
  fi

  MAW_AGENT=$(agent_maw "$agent")

  # Build dispatch message
  MSG="🎯 Task from M2Developer project #$num [$status]

**Issue**: $title
**Repo**: allday9z/m2developer.com
**Issue URL**: https://github.com/allday9z/m2developer.com/issues/$num

Please claim this issue and execute the task. When done, close the issue with:
  gh issue close $num --repo allday9z/m2developer.com --comment 'Done by $agent'

Start with /recap then dive in."

  echo "  → Dispatching #$num to $MAW_AGENT..."
  maw hey "$MAW_AGENT" "$MSG" --force 2>/dev/null && echo "    ✓ Sent" || echo "    ⚠️  maw hey failed"

  # Log to oracle thread
  curl -s -X POST "$ORACLE_API/api/thread" \
    -H "Content-Type: application/json" \
    -d "{\"threadId\": 2, \"message\": \"AUTO-DISPATCH:$TIMESTAMP issue=#$num title='$title' assigned=$agent status=$status\", \"role\": \"claude\"}" > /dev/null 2>&1
done

echo ""
echo "📦 Auto-committing database-oracle changes..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/auto-commit.sh" "$(dirname "$(dirname "$SCRIPT_DIR")")" "auto: dispatch run $TIMESTAMP"

echo ""
echo "✅ auto-dispatch complete — $TIMESTAMP"
