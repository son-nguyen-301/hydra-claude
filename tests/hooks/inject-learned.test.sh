#!/usr/bin/env bash
# Tests for hooks/inject-learned.sh

INJECT_LEARNED_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/inject-learned.sh"

# Helper: compute the workspace slug from a project dir path
# (same formula as inject-learned.sh: replace all '/' with '-')
workspace_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/learned.md"
}

test_inject_learned_no_cwd() {
  local output
  output=$(echo '{}' | bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: no cwd exits 0"
  assert_eq "" "$output" "inject-learned: no cwd produces no output"
}

test_inject_learned_no_learned_file() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: missing learned.md exits 0"

  # Plugin CLAUDE.md exists, so output will contain plugin rules only
  # Validate it's valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: missing learned.md produces valid JSON"
  else
    fail "inject-learned: missing learned.md produces valid JSON" "output was: $output"
  fi

  # Verify plugin rules are in output
  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "PLUGIN RULES" "$additional_context" \
    "inject-learned: missing learned.md injects plugin rules"
}

test_inject_learned_empty_file() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(workspace_for "$PROJECT_DIR" "$FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  touch "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: empty learned.md exits 0"

  # Plugin CLAUDE.md exists, so output will contain plugin rules only
  # Validate it's valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: empty learned.md produces valid JSON"
  else
    fail "inject-learned: empty learned.md produces valid JSON" "output was: $output"
  fi

  # Verify plugin rules are in output
  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "PLUGIN RULES" "$additional_context" \
    "inject-learned: empty learned.md injects plugin rules"
}

test_inject_learned_with_content() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(workspace_for "$PROJECT_DIR" "$FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' \
    > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: with content exits 0"

  # Validate output is valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: output is valid JSON"
  else
    fail "inject-learned: output is valid JSON" "output was: $output"
  fi

  local event_name
  event_name=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
  assert_eq "SessionStart" "$event_name" "inject-learned: hookEventName == SessionStart"

  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "Always use immutable patterns." "$additional_context" \
    "inject-learned: additionalContext contains file content"
}

test_inject_learned_plugin_rules_and_learned() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  local LEARNED_FILE
  LEARNED_FILE=$(workspace_for "$PROJECT_DIR" "$FAKE_HOME")
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' \
    > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: plugin rules + learned exits 0"

  # Validate output is valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: plugin rules + learned output is valid JSON"
  else
    fail "inject-learned: plugin rules + learned output is valid JSON" "output was: $output"
  fi

  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)

  # Verify plugin rules header appears first
  assert_contains "PLUGIN RULES — TOP PRIORITY" "$additional_context" \
    "inject-learned: additionalContext contains plugin rules header"

  # Verify learned patterns header appears
  assert_contains "Repo-specific learned patterns" "$additional_context" \
    "inject-learned: additionalContext contains learned patterns header"

  # Verify learned content is present
  assert_contains "Always use immutable patterns." "$additional_context" \
    "inject-learned: additionalContext contains learned.md content"

  # Verify separator is present
  assert_contains "---" "$additional_context" \
    "inject-learned: additionalContext contains separator"
}

test_inject_learned_plugin_rules_only() {
  # Tests plugin rules injection when learned.md doesn't exist or is empty
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  # Don't create learned.md to test plugin-only scenario

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: plugin rules only exits 0"

  # Validate output is valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: plugin rules only output is valid JSON"
  else
    fail "inject-learned: plugin rules only output is valid JSON" "output was: $output"
  fi

  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)

  # Verify plugin rules header appears
  assert_contains "PLUGIN RULES — TOP PRIORITY" "$additional_context" \
    "inject-learned: additionalContext contains plugin rules header"

  # Verify learned patterns header does NOT appear
  if echo "$additional_context" | grep -q "Repo-specific learned patterns"; then
    fail "inject-learned: no orphan learned patterns header when only plugin rules present"
  else
    pass "inject-learned: no orphan learned patterns header when only plugin rules present"
  fi
}

test_inject_learned_neither_exists() {
  # Note: Plugin CLAUDE.md always exists, so this test verifies
  # that when learned.md doesn't exist, only plugin rules are injected.
  # Truly "neither exists" scenario isn't testable with current plugin setup.
  # This test instead verifies that plugin rules are always injected
  # when learned.md is missing.

  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  # Don't create workspace directory at all

  local payload
  payload=$(printf '{"cwd":"%s"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: no learned.md exits 0"

  # Plugin CLAUDE.md exists, so output will contain plugin rules
  # Validate it's valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "inject-learned: no learned.md produces valid JSON"
  else
    fail "inject-learned: no learned.md produces valid JSON" "output was: $output"
  fi

  # Verify plugin rules are in output
  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "PLUGIN RULES" "$additional_context" \
    "inject-learned: no learned.md injects plugin rules"

  # Verify learned patterns header does NOT appear when no learned.md
  if echo "$additional_context" | grep -q "Repo-specific learned patterns"; then
    fail "inject-learned: no orphan learned patterns header when no learned.md"
  else
    pass "inject-learned: no orphan learned patterns header when no learned.md"
  fi
}
