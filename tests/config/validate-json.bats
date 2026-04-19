#!/usr/bin/env bats
# Tests for plugin manifests and local settings

load '../test_helper'

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
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

@test "plugin.json: has 'version' field" {
  run jq -r '.version // empty' "$PLUGIN_JSON"
  assert_success
  assert [ -n "$output" ]
}

@test "plugin.json: hooks.PostToolUse removed (token-logger deleted)" {
  run jq -e '.hooks.PostToolUse' "$PLUGIN_JSON"
  assert_failure
}

@test "plugin.json: has hooks.PostCompact" {
  run jq -e '.hooks.PostCompact' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has hooks.SessionStart" {
  run jq -e '.hooks.SessionStart' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has hooks.UserPromptSubmit" {
  run jq -e '.hooks.UserPromptSubmit' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has hooks.Stop" {
  run jq -e '.hooks.Stop' "$PLUGIN_JSON"
  assert_success
}

@test "plugin.json: has statusLine.command" {
  run jq -r '.statusLine.command // empty' "$PLUGIN_JSON"
  assert_success
  assert [ -n "$output" ]
}

@test "plugin.json: agents is a non-empty array" {
  run jq -r 'if (.agents | type) == "array" then .agents | length else 0 end' "$PLUGIN_JSON"
  assert_success
  assert [ "$output" -gt 0 ]
}

@test "plugin.json: has skills field" {
  run jq -e '.skills' "$PLUGIN_JSON"
  assert_success
}

# ── settings.json tests ───────────────────────────────────────────────────────

@test "settings.json: is valid JSON" {
  run jq . "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: has statusLine.command" {
  run jq -r '.statusLine.command // empty' "$SETTINGS_JSON"
  assert_success
  assert [ -n "$output" ]
}

@test "settings.json: has hooks.PostCompact" {
  run jq -e '.hooks.PostCompact' "$SETTINGS_JSON"
  assert_success
}

@test "settings.json: has hooks.SessionStart" {
  run jq -e '.hooks.SessionStart' "$SETTINGS_JSON"
  assert_success
}
