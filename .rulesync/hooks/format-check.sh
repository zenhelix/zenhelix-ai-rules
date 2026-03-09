#!/usr/bin/env bash
set -euo pipefail

# Post-tool-use hook: auto-format JVM source files after Write/Edit operations.
# Idempotent, non-blocking. Always exits 0.

FILE_PATH="${CLAUDE_FILE_PATH:-}"

# Skip if no file path provided
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only format JVM source files
case "$FILE_PATH" in
  *.kt|*.kts|*.java) ;;
  *) exit 0 ;;
esac

# Detect and run available formatter
if [[ -x "./gradlew" ]]; then
  if grep -q "spotless" build.gradle.kts 2>/dev/null; then
    ./gradlew spotlessApply --quiet 2>/dev/null || true
  elif grep -q "ktlint" build.gradle.kts 2>/dev/null; then
    ./gradlew ktlintFormat --quiet 2>/dev/null || true
  fi
fi

exit 0
