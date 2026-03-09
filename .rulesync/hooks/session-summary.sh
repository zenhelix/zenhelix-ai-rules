#!/usr/bin/env bash

# Stop hook: display a brief summary of changes made during the session.
# Always exits 0.

echo "=== Session Summary ==="
echo ""

echo "--- Unstaged changes ---"
git diff --stat 2>/dev/null || echo "(no unstaged changes)"
echo ""

echo "--- Staged changes ---"
git diff --cached --stat 2>/dev/null || echo "(no staged changes)"
echo ""

echo "--- Overall ---"
SHORTSTAT=$(git diff --shortstat 2>/dev/null)
CACHED_SHORTSTAT=$(git diff --cached --shortstat 2>/dev/null)
if [[ -n "$SHORTSTAT" ]]; then
  echo "Unstaged: $SHORTSTAT"
fi
if [[ -n "$CACHED_SHORTSTAT" ]]; then
  echo "Staged:   $CACHED_SHORTSTAT"
fi
if [[ -z "$SHORTSTAT" && -z "$CACHED_SHORTSTAT" ]]; then
  echo "No changes detected."
fi

exit 0
