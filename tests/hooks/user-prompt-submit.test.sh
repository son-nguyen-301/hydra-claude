#!/usr/bin/env bash
# Tests for hooks/user-prompt-submit.sh

USER_PROMPT_SUBMIT_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/user-prompt-submit.sh"

test_user_prompt_submit_outputs_json() {
  local output
  output=$(echo '{}' | bash "$USER_PROMPT_SUBMIT_HOOK")

  # Validate output is valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "user-prompt-submit: outputs valid JSON"
  else
    fail "user-prompt-submit: outputs valid JSON" "output was: $output"
  fi

  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "RULE REMINDER" "$additional_context" \
    "user-prompt-submit: additionalContext contains RULE REMINDER"

  assert_contains "plan-task" "$additional_context" \
    "user-prompt-submit: additionalContext mentions plan-task"
}

test_user_prompt_submit_exits_zero() {
  echo '{}' | bash "$USER_PROMPT_SUBMIT_HOOK" > /dev/null
  local exit_code=$?

  assert_exit 0 "$exit_code" "user-prompt-submit: exits 0"
}

test_user_prompt_submit_no_plugin_file() {
  # Test with a temp directory that has no CLAUDE.md to simulate missing plugin file
  local TEMP_HOOK_DIR
  TEMP_HOOK_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_HOOK_DIR"' RETURN

  # Copy the hook to temp dir (HOOK_DIR will be temp dir, no CLAUDE.md parent)
  cp "$USER_PROMPT_SUBMIT_HOOK" "$TEMP_HOOK_DIR/user-prompt-submit.sh"
  # HOOK_DIR/../CLAUDE.md won't exist (temp dir parent has no CLAUDE.md)

  local output
  output=$(echo '{}' | bash "$TEMP_HOOK_DIR/user-prompt-submit.sh")
  local exit_code=$?

  assert_exit 0 "$exit_code" "user-prompt-submit: exits 0 when no plugin file"
  assert_eq "" "$output" "user-prompt-submit: produces no output when plugin file missing"
}
