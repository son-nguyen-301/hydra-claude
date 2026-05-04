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

# Helper: return path to memory/MEMORY.md (old path, for fallback tests)
_old_workspace_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/MEMORY.md"
}

# Helper: return path to learned.md (for fallback tests)
_learned_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/learned.md"
}

# Helper: write a settings.json with autoMemoryEnabled=false to HYDRA_FAKE_HOME
_disable_native_automemory() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  printf '{"autoMemoryEnabled": false}\n' > "$home_dir/.claude/settings.json"
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
  _disable_native_automemory "$HYDRA_FAKE_HOME"
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
  _disable_native_automemory "$HYDRA_FAKE_HOME"
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
  _disable_native_automemory "$HYDRA_FAKE_HOME"
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
  _disable_native_automemory "$HYDRA_FAKE_HOME"
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
  _disable_native_automemory "$HYDRA_FAKE_HOME"
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

@test "post-compact with cwd: falls back to learned.md when MEMORY.md absent" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_learned_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Fallback pattern from learned.md.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")

  # Output should contain learned.md content
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Fallback pattern from learned.md."
}

# --- Tests for native auto-memory detection ---

@test "post-compact: native automemory enabled skips plugin memory but injects rules" {
  setup_isolated_home
  # Write settings with autoMemoryEnabled: true (native is ON — plugin memory should be skipped)
  mkdir -p "$HYDRA_FAKE_HOME/.claude"
  printf '{"autoMemoryEnabled": true}\n' > "$HYDRA_FAKE_HOME/.claude/settings.json"

  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Plugin pattern that should be skipped.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  refute_output --partial "Plugin pattern that should be skipped."
}

@test "post-compact: native automemory disabled injects plugin memory" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"

  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Plugin memory content injected.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  assert_output --partial "Plugin memory content injected."
}

@test "post-compact: CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 injects plugin memory" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Env-var-triggered memory injection.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Env-var-triggered memory injection."
}

@test "post-compact: fallback from plugin/MEMORY.md to memory/MEMORY.md" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"

  local PROJECT_DIR="/some/test/project"
  # Put content only at old path (memory/MEMORY.md), not plugin/MEMORY.md
  local OLD_MEMORY_FILE
  OLD_MEMORY_FILE=$(_old_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$OLD_MEMORY_FILE")"
  printf 'Old memory path content.\n' > "$OLD_MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$POST_COMPACT_HOOK"
  assert_success
  assert_output --partial "Old memory path content."
}
