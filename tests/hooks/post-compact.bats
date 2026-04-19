#!/usr/bin/env bats
# Tests for hooks/post-compact.sh

load '../test_helper'

POST_COMPACT_HOOK="$ROOT/hooks/post-compact.sh"

@test "post-compact: outputs valid JSON (plugin rules present)" {
  setup_isolated_home
  run bash -c 'echo "{\"summary\":\"compacted\"}" | HOME="$1" bash "$2"' _ "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  run bash -c 'echo "$1" | jq . > /dev/null 2>&1' _ "$output"
  assert_success
}

@test "post-compact: exits 0" {
  setup_isolated_home
  run bash -c 'echo "{\"summary\":\"compacted\"}" | HOME="$1" bash "$2" > /dev/null' _ "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
}

@test "post-compact: empty stdin exits 0" {
  setup_isolated_home
  run bash -c 'echo "" | HOME="$1" bash "$2" > /dev/null' _ "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
}

@test "post-compact: empty stdin produces valid JSON (plugin rules re-injected)" {
  setup_isolated_home
  run bash -c 'echo "" | HOME="$1" bash "$2"' _ "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  run bash -c 'echo "$1" | jq . > /dev/null 2>&1' _ "$output"
  assert_success
}

@test "post-compact with cwd: exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$HYDRA_FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
}

@test "post-compact with cwd: output is valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$HYDRA_FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  run bash -c 'echo "$1" | jq . > /dev/null 2>&1' _ "$output"
  assert_success
}

@test "post-compact with cwd: hookEventName == PostCompact" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$HYDRA_FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output "PostCompact"
}

@test "post-compact with cwd: additionalContext contains re-inject prefix" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$HYDRA_FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Context compacted — rules re-injected."
}

@test "post-compact with cwd: additionalContext contains learned content" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$HYDRA_FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Use immutable patterns."
}
