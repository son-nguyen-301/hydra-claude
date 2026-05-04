#!/usr/bin/env bats
# Tests for hooks/inject-learned.sh

load '../test_helper'

INJECT_LEARNED_HOOK="$ROOT/hooks/inject-learned.sh"

# Helper: compute the workspace slug from a project dir path and return path to plugin/MEMORY.md
# (same formula as inject-learned.sh: replace all '/' with '-')
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

@test "inject-learned: no cwd exits 0" {
  run bash -c 'echo "{}" | bash "$1"' _ "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no cwd produces no output" {
  run bash -c 'echo "{}" | bash "$1"' _ "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output ""
}

@test "inject-learned: missing MEMORY.md exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing MEMORY.md produces valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing MEMORY.md injects plugin rules" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: empty MEMORY.md exits 0" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty MEMORY.md produces valid JSON" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty MEMORY.md injects plugin rules" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: with MEMORY.md content exits 0" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: output is valid JSON" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: hookEventName == SessionStart" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output "SessionStart"
}

@test "inject-learned: additionalContext contains MEMORY.md file content" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: plugin rules + MEMORY.md exits 0" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: plugin rules + MEMORY.md output is valid JSON" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: additionalContext contains plugin rules header" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES — TOP PRIORITY"
}

@test "inject-learned: additionalContext contains memory index framing" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Memory index"
}

@test "inject-learned: additionalContext contains MEMORY.md content" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: additionalContext contains separator" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "---"
}

@test "inject-learned: plugin rules only exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: plugin rules only output is valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no orphan memory patterns header when only plugin rules present" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Memory index"
}

@test "inject-learned: health-check emits warning when no rules found" {
  setup_isolated_home
  local TEMP_HOOK_DIR="$BATS_TEST_TMPDIR/hook_dir"
  mkdir -p "$TEMP_HOOK_DIR"
  cp "$INJECT_LEARNED_HOOK" "$TEMP_HOOK_DIR/inject-learned.sh"

  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")

  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>&1 >/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$TEMP_HOOK_DIR/inject-learned.sh"
  assert_output --partial "WARNING [inject-learned]"
}

@test "inject-learned: no MEMORY.md exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no MEMORY.md produces valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no MEMORY.md injects plugin rules" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: no orphan memory patterns header when no MEMORY.md" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Memory index"
}

@test "inject-learned: falls back to learned.md when MEMORY.md absent" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_learned_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Fallback pattern from learned.md.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")

  # Output should contain learned.md content
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Fallback pattern from learned.md."
}

# --- New tests for native auto-memory detection ---

@test "inject-learned: native automemory enabled skips plugin memory but injects rules" {
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
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  refute_output --partial "Plugin pattern that should be skipped."
}

@test "inject-learned: native automemory disabled injects plugin memory" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"

  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Plugin memory content injected.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  assert_output --partial "Plugin memory content injected."
}

@test "inject-learned: CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 injects plugin memory" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local MEMORY_FILE
  MEMORY_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Env-var-triggered memory injection.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Env-var-triggered memory injection."
}

@test "inject-learned: fallback from plugin/MEMORY.md to memory/MEMORY.md" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"

  local PROJECT_DIR="/some/test/project"
  # Put content only at old path (memory/MEMORY.md), not plugin/MEMORY.md
  local OLD_MEMORY_FILE
  OLD_MEMORY_FILE=$(_old_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$OLD_MEMORY_FILE")"
  printf 'Old memory path content.\n' > "$OLD_MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Old memory path content."
}

@test "inject-learned: fallback from memory/MEMORY.md to learned.md" {
  setup_isolated_home
  _disable_native_automemory "$HYDRA_FAKE_HOME"

  local PROJECT_DIR="/some/test/project"
  # Put content only at learned.md, not at plugin/MEMORY.md or memory/MEMORY.md
  local LEARNED_FILE
  LEARNED_FILE=$(_learned_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Legacy learned.md content.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Legacy learned.md content."
}
