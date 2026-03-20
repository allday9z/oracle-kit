#!/usr/bin/env bash
# index-all.sh — Re-index all oracle repos into shared DB
# Usage: bash scripts/index-all.sh

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[ -f "$KIT_ROOT/.env" ] && export $(grep -v '^#' "$KIT_ROOT/.env" | xargs) 2>/dev/null

GHQ_ROOT="${GHQ_ROOT:-/Users/$(whoami)/ghq/github.com}"
ORACLE_V2="$GHQ_ROOT/allday9z/oracle-v2"
LANCEDB_PATH="$HOME/.oracle/lancedb"

echo "📚 Indexing oracle repos..."
IFS=' ' read -ra REPOS <<< "${ORACLE_REPOS:-allday9z/database-oracle}"
cd "$ORACLE_V2"
for repo in "${REPOS[@]}"; do
  repo_path="$GHQ_ROOT/$repo"
  if [ -d "$repo_path/ψ" ]; then
    echo "  → $(basename "$repo")"
    ORACLE_VECTOR_DB=lancedb ORACLE_EMBEDDING_PROVIDER=ollama \
      ORACLE_VECTOR_DB_PATH="$LANCEDB_PATH" \
      ORACLE_REPO_ROOT="$repo_path" \
      bun src/indexer.ts 2>&1 | grep -E "Indexed|Added" | tail -1
  fi
done
echo "✅ Done → ~/.oracle/oracle.db"
