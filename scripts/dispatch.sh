#!/usr/bin/env bash
# dispatch.sh — Send a task from database-oracle to another agent via maw
# Usage: ./dispatch.sh [agent] [message]
# Example: ./dispatch.sh conductor "/nnn build DAPP product page"

AGENT="${1:-conductor}"
MESSAGE="${2:-/recap}"
ORACLE_API="http://localhost:47778"

# maw session map
# Session map (use arrays compatible with bash 3 on macOS)
get_session() {
  case "$1" in
    conductor) echo "04-conductor" ;;
    m2manager) echo "03-m2manager" ;;
    phukhao) echo "01-phukhao" ;;
    opensourcenatbrain) echo "02-opensourcenatbrain" ;;
    database) echo "05-database" ;;
    devops) echo "07-devops" ;;
    *) echo "" ;;
  esac
}

SESSION="$(get_session "$AGENT")"
if [ -z "$SESSION" ]; then
  echo "❌ Unknown agent: $AGENT"
  echo "   Available: ${!SESSIONS[@]}"
  exit 1
fi

echo "📡 Dispatching to $AGENT ($SESSION): $MESSAGE"

# Post to conductor-inbox thread (thread 2) for audit trail
PAYLOAD=$(python3 -c "
import json
print(json.dumps({
  'thread_id': 2,
  'message': 'DISPATCH FROM:database-oracle TO:$AGENT MSG:$MESSAGE',
  'role': 'claude'
}))
")
curl -s -X POST "$ORACLE_API/api/thread" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

# Send via maw (--force sends even if no active Claude session)
maw "$AGENT" "$MESSAGE" --force 2>/dev/null || maw hey "$AGENT" "$MESSAGE"

echo "✓ Dispatched"
