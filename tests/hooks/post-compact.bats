#!/usr/bin/env bats
# Tests for hooks/post-compact.sh

load '../test_helper'

POST_COMPACT_HOOK="$ROOT/hooks/post-compact.sh"

# Helper: compute the workspace slug from a project dir path and return path to plugin/MEMORY.md
_workspace_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/plugin/MEMORY.md"
}


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
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Use immutable patterns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
}

@test "post-compact with cwd: output is valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Use immutable patterns.\n' > "$MEMORY_FILE"

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
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Use immutable patterns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output "PostCompact"
}

@test "post-compact with cwd: additionalContext contains re-inject prefix" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Use immutable patterns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Context compacted — rules re-injected."
}

@test "post-compact with cwd: additionalContext contains MEMORY.md content" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Use immutable patterns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Use immutable patterns."
}

@test "post-compact: plugin/MEMORY.md present — injects plugin memory regardless of native automemory setting" {
  setup_isolated_home
  # Write settings with autoMemoryEnabled: true (native auto-memory is ON)
  mkdir -p "$HYDRA_FAKE_HOME/.claude"
  printf '{"autoMemoryEnabled": true}\n' > "$HYDRA_FAKE_HOME/.claude/settings.json"

  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Plugin memory always injected.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  assert_output --partial "Plugin memory always injected."
}
