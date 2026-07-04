#!/usr/bin/env bats
# Tests for plugin manifests and local settings (v3.0.0 memory-only)

load '../test_helper'

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"
# settings.json has a leading space in its filename (filesystem artifact)
SETTINGS_JSON="$ROOT/ settings.json"

# ── plugin.json tests ─────────────────────────────────────────────────────────

@test "plugin.json: is valid JSON" {
  run jq . "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has 'name' field" {
  run jq -r '.name // empty' "$PLUGIN_JSON"
  assert_success
  assert [ -n "$output" ]
}

@test "plugin.json: version is 3.7.0" {
  run jq -r '.version // empty' "$PLUGIN_JSON"
  assert_success
  assert_equal "3.7.0" "$output"
}

@test "plugin.json: has skills field" {
  run jq -e '.skills' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: agents field is absent (memory-only)" {
  run jq -e '.agents' "$PLUGIN_JSON"
  assert_failure
}

@test "plugin.json: statusLine field is absent (memory-only)" {
  run jq -e '.statusLine' "$PLUGIN_JSON"
  assert_failure
}

@test "plugin.json: hooks.UserPromptSubmit registered (recall)" {
  run jq -r '.hooks.UserPromptSubmit[0].hooks[0].command // empty' "$PLUGIN_JSON"
  assert_success
  assert_output --partial "recall-prompt.sh"
}

@test "plugin.json: hooks.PreToolUse registered with tool matcher" {
  run jq -r '.hooks.PreToolUse[0].matcher // empty' "$PLUGIN_JSON"
  assert_success
  assert_output "Edit|Write|MultiEdit|Bash"
  run jq -r '.hooks.PreToolUse[0].hooks[0].command // empty' "$PLUGIN_JSON"
  assert_output --partial "recall-pretool.sh"
}

@test "plugin.json: hooks.PostToolUse is absent" {
  run jq -e '.hooks.PostToolUse' "$PLUGIN_JSON"
  assert_failure
}

@test "plugin.json: has hooks.SessionStart" {
  run jq -e '.hooks.SessionStart' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has hooks.PostCompact" {
  run jq -e '.hooks.PostCompact' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has hooks.Stop" {
  run jq -e '.hooks.Stop' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: hooks.SubagentStart registered (recall)" {
  run jq -r '.hooks.SubagentStart[0].hooks[0].command // empty' "$PLUGIN_JSON"
  assert_success
  assert_output --partial "inject-learned.sh"
}

# ── marketplace.json tests ────────────────────────────────────────────────────

@test "marketplace.json: is valid JSON" {
  run jq . "$MARKETPLACE_JSON"
  assert_success
}

@test "marketplace.json: plugins[0].version is 3.7.0" {
  run jq -r '.plugins[0].version // empty' "$MARKETPLACE_JSON"
  assert_success
  assert_equal "3.7.0" "$output"
}

# ── ' settings.json' tests ────────────────────────────────────────────────────

@test "settings.json: is valid JSON" {
  run jq . "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: statusLine field is absent (memory-only)" {
  run jq -e '.statusLine' "$SETTINGS_JSON"
  assert_failure
}

@test "settings.json: hooks.UserPromptSubmit registered (recall)" {
  run jq -r '.hooks.UserPromptSubmit[0].hooks[0].command // empty' "$SETTINGS_JSON"
  assert_success
  assert_output --partial "recall-prompt.sh"
}

@test "settings.json: hooks.PreToolUse registered with tool matcher" {
  run jq -r '.hooks.PreToolUse[0].matcher // empty' "$SETTINGS_JSON"
  assert_success
  assert_output "Edit|Write|MultiEdit|Bash"
}

@test "settings.json: has hooks.SessionStart" {
  run jq -e '.hooks.SessionStart' "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: has hooks.PostCompact" {
  run jq -e '.hooks.PostCompact' "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: has hooks.Stop" {
  run jq -e '.hooks.Stop' "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: hooks.SubagentStart registered (recall)" {
  run jq -r '.hooks.SubagentStart[0].hooks[0].command // empty' "$SETTINGS_JSON"
  assert_success
  assert_output --partial "inject-learned.sh"
}
