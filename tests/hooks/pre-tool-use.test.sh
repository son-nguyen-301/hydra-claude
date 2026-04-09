#!/usr/bin/env bash
# Tests for hooks/pre-tool-use.sh

PRE_TOOL_USE_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/pre-tool-use.sh"

test_pre_tool_use_edit_blocked() {
  local stderr_output
  stderr_output=$(printf '{"tool_name":"Edit"}' | bash "$PRE_TOOL_USE_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "pre-tool-use: Edit tool is blocked (exit 2)"
  assert_contains "BLOCKED" "$stderr_output" \
    "pre-tool-use: Edit block writes BLOCKED to stderr"
}

test_pre_tool_use_write_blocked() {
  local stderr_output
  stderr_output=$(printf '{"tool_name":"Write"}' | bash "$PRE_TOOL_USE_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "pre-tool-use: Write tool is blocked (exit 2)"
  assert_contains "BLOCKED" "$stderr_output" \
    "pre-tool-use: Write block writes BLOCKED to stderr"
}

test_pre_tool_use_read_allowed() {
  local output
  output=$(printf '{"tool_name":"Read"}' | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Read tool is allowed (exit 0)"
}

test_pre_tool_use_bash_allowed() {
  local output
  output=$(printf '{"tool_name":"Bash"}' | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Bash tool is allowed (exit 0)"
}

test_pre_tool_use_empty_tool_name_allowed() {
  local output
  output=$(printf '{}' | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: empty/missing tool_name is allowed (exit 0)"
}
