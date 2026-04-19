#!/usr/bin/env bats
# Tests for hooks/inject-learned.sh

load '../test_helper'

INJECT_LEARNED_HOOK="$ROOT/hooks/inject-learned.sh"

# Helper: compute the workspace slug from a project dir path
# (same formula as inject-learned.sh: replace all '/' with '-')
_workspace_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/learned.md"
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

@test "inject-learned: missing learned.md exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing learned.md produces valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing learned.md injects plugin rules" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: empty learned.md exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  touch "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty learned.md produces valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  touch "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty learned.md injects plugin rules" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  touch "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: with content exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: output is valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: hookEventName == SessionStart" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output "SessionStart"
}

@test "inject-learned: additionalContext contains file content" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: plugin rules + learned exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: plugin rules + learned output is valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: additionalContext contains plugin rules header" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES — TOP PRIORITY"
}

@test "inject-learned: additionalContext contains learned patterns header" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Repo-specific learned patterns"
}

@test "inject-learned: additionalContext contains learned.md content" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: additionalContext contains separator" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(_workspace_for "$PROJECT_DIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$LEARNED_FILE"

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

@test "inject-learned: no orphan learned patterns header when only plugin rules present" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Repo-specific learned patterns"
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

@test "inject-learned: no learned.md exits 0" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no learned.md produces valid JSON" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no learned.md injects plugin rules" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: no orphan learned patterns header when no learned.md" {
  setup_isolated_home
  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Repo-specific learned patterns"
}
