#!/usr/bin/env bash
# Tests for .claude-plugin/plugin.json and settings.json

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
SETTINGS_JSON="$ROOT/settings.json"

# ── plugin.json tests ─────────────────────────────────────────────────────────

test_plugin_json_valid() {
  assert_json_valid "$PLUGIN_JSON" "plugin.json: is valid JSON"
}

test_plugin_json_has_name() {
  local val
  val=$(jq -r '.name // empty' "$PLUGIN_JSON" 2>/dev/null)
  if [ -n "$val" ]; then
    pass "plugin.json: has 'name' field"
  else
    fail "plugin.json: has 'name' field" "field missing or empty"
  fi
}

test_plugin_json_has_version() {
  local val
  val=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null)
  if [ -n "$val" ]; then
    pass "plugin.json: has 'version' field"
  else
    fail "plugin.json: has 'version' field" "field missing or empty"
  fi
}

test_plugin_json_has_no_post_tool_use_token_logger() {
  local val
  val=$(jq -e '.hooks.PostToolUse' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -ne 0 ]; then
    pass "plugin.json: hooks.PostToolUse removed (token-logger deleted)"
  else
    fail "plugin.json: hooks.PostToolUse removed (token-logger deleted)" "field still present"
  fi
}

test_plugin_json_has_hooks_post_compact() {
  local val
  val=$(jq -e '.hooks.PostCompact' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "plugin.json: has hooks.PostCompact"
  else
    fail "plugin.json: has hooks.PostCompact" "field missing"
  fi
}

test_plugin_json_has_hooks_session_start() {
  local val
  val=$(jq -e '.hooks.SessionStart' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "plugin.json: has hooks.SessionStart"
  else
    fail "plugin.json: has hooks.SessionStart" "field missing"
  fi
}

test_plugin_json_has_status_line_command() {
  local val
  val=$(jq -r '.statusLine.command // empty' "$PLUGIN_JSON" 2>/dev/null)
  if [ -n "$val" ]; then
    pass "plugin.json: has statusLine.command"
  else
    fail "plugin.json: has statusLine.command" "field missing or empty"
  fi
}

test_plugin_json_agents_non_empty_array() {
  local count
  count=$(jq -r 'if (.agents | type) == "array" then .agents | length else 0 end' "$PLUGIN_JSON" 2>/dev/null)
  if [ "$count" -gt 0 ] 2>/dev/null; then
    pass "plugin.json: agents is a non-empty array"
  else
    fail "plugin.json: agents is a non-empty array" "agents count: $count"
  fi
}

test_plugin_json_has_skills() {
  local val
  val=$(jq -e '.skills' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "plugin.json: has skills field"
  else
    fail "plugin.json: has skills field" "field missing"
  fi
}

test_plugin_json_has_hooks_user_prompt_submit() {
  local val
  val=$(jq -e '.hooks.UserPromptSubmit' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "plugin.json: has hooks.UserPromptSubmit"
  else
    fail "plugin.json: has hooks.UserPromptSubmit" "field missing"
  fi
}

test_plugin_json_has_hooks_stop() {
  local val
  val=$(jq -e '.hooks.Stop' "$PLUGIN_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "plugin.json: has hooks.Stop"
  else
    fail "plugin.json: has hooks.Stop" "field missing"
  fi
}

# ── settings.json tests ───────────────────────────────────────────────────────

test_settings_json_valid() {
  assert_json_valid "$SETTINGS_JSON" "settings.json: is valid JSON"
}

test_settings_json_has_status_line_command() {
  local val
  val=$(jq -r '.statusLine.command // empty' "$SETTINGS_JSON" 2>/dev/null)
  if [ -n "$val" ]; then
    pass "settings.json: has statusLine.command"
  else
    fail "settings.json: has statusLine.command" "field missing or empty"
  fi
}

test_settings_json_has_hooks_post_compact() {
  local val
  val=$(jq -e '.hooks.PostCompact' "$SETTINGS_JSON" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "settings.json: has hooks.PostCompact"
  else
    fail "settings.json: has hooks.PostCompact" "field missing"
  fi
}
