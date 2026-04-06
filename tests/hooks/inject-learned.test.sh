#!/usr/bin/env bash
# Tests for hooks/inject-learned.sh

INJECT_LEARNED_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/inject-learned.sh"

test_inject_learned_no_cwd() {
  local output
  output=$(echo '{}' | bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: no cwd exits 0"
  assert_eq "" "$output" "inject-learned: no cwd produces no output"
}

test_inject_learned_no_learned_file() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local payload
  payload=$(printf '{"cwd":"%s"}' "$TMPDIR")
  local output
  output=$(echo "$payload" | bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: missing learned.md exits 0"
  assert_eq "" "$output" "inject-learned: missing learned.md produces no output"
}

test_inject_learned_empty_file() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  mkdir -p "$TMPDIR/.claude/memory"
  touch "$TMPDIR/.claude/memory/learned.md"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$TMPDIR")
  local output
  output=$(echo "$payload" | bash "$INJECT_LEARNED_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "inject-learned: empty learned.md exits 0"
  assert_eq "" "$output" "inject-learned: empty learned.md produces no output"
}

test_inject_learned_with_content() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  mkdir -p "$TMPDIR/.claude/memory"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' \
    > "$TMPDIR/.claude/memory/learned.md"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$TMPDIR")
  local output
  output=$(echo "$payload" | bash "$INJECT_LEARNED_HOOK")
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
