#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

COUNTER_FILE="/tmp/.claude-tool-calls-${PPID}-$(date +%Y%m%d)"

LOCK_DIR="$COUNTER_FILE.lock"

COUNT=0
if mkdir "$LOCK_DIR" 2>/dev/null; then
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
  CURRENT="$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")"
  COUNT=$((CURRENT + 1))
  echo "$COUNT" > "$COUNTER_FILE"
  rmdir "$LOCK_DIR" 2>/dev/null
  trap - EXIT
fi

if [[ "$COUNT" -ge 50 ]] && [[ $((COUNT % 25)) -eq 0 ]]; then
  echo "HINT: $COUNT tool calls this session. Consider /compact to free context." >&2
fi

exit 0
