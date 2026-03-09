#!/usr/bin/env bash

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts) FILE_TYPE="kotlin" ;;
  *.java)     FILE_TYPE="java" ;;
  *)          exit 0 ;;
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

if [[ "$FILE_TYPE" == "kotlin" ]]; then
  if echo "$TASKS" | grep -q "detektMain"; then
    ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}detektMain" --quiet 2>/dev/null) || true
  fi
elif [[ "$FILE_TYPE" == "java" ]]; then
  if echo "$TASKS" | grep -q "checkstyleMain"; then
    ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}checkstyleMain" --quiet 2>/dev/null) || true
  fi
  if echo "$TASKS" | grep -q "spotbugsMain"; then
    ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}spotbugsMain" --quiet 2>/dev/null) || true
  fi
fi

exit 0
