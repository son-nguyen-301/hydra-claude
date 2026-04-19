#!/usr/bin/env bats
# Tests for hooks/user-prompt-submit.sh

load '../test_helper'

USER_PROMPT_SUBMIT_HOOK="$ROOT/hooks/user-prompt-submit.sh"

@test "user-prompt-submit: outputs valid JSON" {
  run bash -c 'echo "{}" | bash "$1"' _ "$USER_PROMPT_SUBMIT_HOOK"
  assert_success
  run bash -c 'echo "$1" | jq . > /dev/null 2>&1' _ "$output"
  assert_success
}

@test "user-prompt-submit: additionalContext contains RULE REMINDER" {
  run bash -c 'echo "{}" | bash "$1" | jq -r ".hookSpecificOutput.additionalContext"' _ "$USER_PROMPT_SUBMIT_HOOK"
  assert_success
  assert_output --partial "RULE REMINDER"
}

@test "user-prompt-submit: additionalContext mentions plan-task" {
  run bash -c 'echo "{}" | bash "$1" | jq -r ".hookSpecificOutput.additionalContext"' _ "$USER_PROMPT_SUBMIT_HOOK"
  assert_success
  assert_output --partial "plan-task"
}

@test "user-prompt-submit: exits 0" {
  run bash -c 'echo "{}" | bash "$1" > /dev/null' _ "$USER_PROMPT_SUBMIT_HOOK"
  assert_success
}

@test "user-prompt-submit: exits 0 when no plugin file" {
  local TEMP_HOOK_DIR="$BATS_TEST_TMPDIR/hook_dir"
  mkdir -p "$TEMP_HOOK_DIR"
  cp "$USER_PROMPT_SUBMIT_HOOK" "$TEMP_HOOK_DIR/user-prompt-submit.sh"

  run bash -c 'echo "{}" | bash "$1"' _ "$TEMP_HOOK_DIR/user-prompt-submit.sh"
  assert_success
}

@test "user-prompt-submit: produces no output when plugin file missing" {
  local TEMP_HOOK_DIR="$BATS_TEST_TMPDIR/hook_dir"
  mkdir -p "$TEMP_HOOK_DIR"
  cp "$USER_PROMPT_SUBMIT_HOOK" "$TEMP_HOOK_DIR/user-prompt-submit.sh"

  run bash -c 'echo "{}" | bash "$1"' _ "$TEMP_HOOK_DIR/user-prompt-submit.sh"
  assert_success
  assert_output ""
}
