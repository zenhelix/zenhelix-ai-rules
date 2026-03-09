#!/usr/bin/env bash

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts|*.java) ;;
  *) exit 0 ;;
esac

find_gradlew() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -x "$dir/gradlew" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_gradle_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/settings.gradle.kts" || -f "$dir/settings.gradle" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_module_dir() {
  local dir="$1"
  local root="$2"
  while [[ "$dir" != "/" && "$dir" != "$(dirname "$root")" ]]; do
    if [[ -f "$dir/build.gradle.kts" || -f "$dir/build.gradle" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

GRADLEW_DIR=$(find_gradlew "$(dirname "$FILE_PATH")") || exit 0
GRADLE_ROOT=$(find_gradle_root "$(dirname "$FILE_PATH")") || exit 0
MODULE_DIR=$(find_module_dir "$(dirname "$FILE_PATH")" "$GRADLE_ROOT") || exit 0

if [[ "$MODULE_DIR" == "$GRADLE_ROOT" ]]; then
  TASK_PREFIX=""
else
  REL_PATH="${MODULE_DIR#"$GRADLE_ROOT"/}"
  TASK_PREFIX=":${REL_PATH//\//:}:"
fi

if [[ "$GRADLE_ROOT" == "$GRADLEW_DIR" ]]; then
  GRADLE_OPTS=()
else
  GRADLE_OPTS=("-p" "$GRADLE_ROOT")
fi

TASKS=$("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}tasks" --all --quiet 2>/dev/null) || exit 0

if echo "$TASKS" | grep -q "spotlessApply"; then
  ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}spotlessApply" --quiet 2>/dev/null) || true
elif echo "$TASKS" | grep -q "ktlintFormat"; then
  ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}ktlintFormat" --quiet 2>/dev/null) || true
fi

exit 0
