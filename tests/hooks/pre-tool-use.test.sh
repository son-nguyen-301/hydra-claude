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

# New tests for whitelisting

test_pre_tool_use_write_to_plans_allowed() {
  local output
  output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.claude/projects/test-proj/plans/plan-001.md"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Write to plans dir is allowed (exit 0)"
}

test_pre_tool_use_write_to_memory_allowed() {
  local output
  output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.claude/projects/test-proj/memory/notes.md"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Write to memory dir is allowed (exit 0)"
}

test_pre_tool_use_write_to_tasks_allowed() {
  local output
  output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.claude/projects/test-proj/tasks/task-001.md"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Write to tasks dir is allowed (exit 0)"
}

test_pre_tool_use_write_to_debug_findings_allowed() {
  local output
  output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.claude/projects/test-proj/debug-findings/issue-001.md"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Write to debug-findings dir is allowed (exit 0)"
}

test_pre_tool_use_edit_to_plans_allowed() {
  local output
  output=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.claude/projects/test-proj/plans/plan-001.md"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Edit to plans dir is allowed (exit 0)"
}

test_pre_tool_use_write_to_project_source_blocked() {
  local stderr_output
  stderr_output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/Documents/my-project/src/app.js"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "pre-tool-use: Write to project source is blocked (exit 2)"
  assert_contains "BLOCKED" "$stderr_output" \
    "pre-tool-use: Write to project source writes BLOCKED to stderr"
}

test_pre_tool_use_edit_to_project_source_blocked() {
  local stderr_output
  stderr_output=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/Documents/my-project/src/app.js"}}' "$HOME" | bash "$PRE_TOOL_USE_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "pre-tool-use: Edit to project source is blocked (exit 2)"
  assert_contains "BLOCKED" "$stderr_output" \
    "pre-tool-use: Edit to project source writes BLOCKED to stderr"
}

# Tests for subagent detection (agent_id present)

test_pre_tool_use_write_with_subagent_id_allowed() {
  local output
  output=$(printf '{"tool_name":"Write","agent_id":"agent-sprinter-001","tool_input":{"file_path":"/some/project/src/app.js"}}' | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Write with agent_id is allowed (exit 0)"
}

test_pre_tool_use_edit_with_subagent_id_allowed() {
  local output
  output=$(printf '{"tool_name":"Edit","agent_id":"agent-builder-002","agent_type":"builder","tool_input":{"file_path":"/some/project/src/component.tsx"}}' | bash "$PRE_TOOL_USE_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "pre-tool-use: Edit with agent_id is allowed (exit 0)"
}

test_pre_tool_use_write_without_agent_id_to_source_blocked() {
  local stderr_output
  stderr_output=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/some/project/src/app.js"}}' | bash "$PRE_TOOL_USE_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "pre-tool-use: Write without agent_id to source is blocked (exit 2)"
  assert_contains "BLOCKED" "$stderr_output" \
    "pre-tool-use: Write without agent_id to source writes BLOCKED to stderr"
}
