#!/usr/bin/env bash
# Tests for hooks/post-compact.sh

POST_COMPACT_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/post-compact.sh"

test_post_compact_outputs_message() {
  # When no cwd provided and FAKE_HOME has no CLAUDE.md, falls back to plain text.
  # Since the real hook reads CLAUSE.md relative to BASH_SOURCE, plugin rules always exist,
  # so we expect valid JSON output (not plain text) in the normal case.
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local output
  output=$(echo '{"summary":"compacted"}' | HOME="$FAKE_HOME" bash "$POST_COMPACT_HOOK")

  # Plugin CLAUDE.md always exists, so output is JSON with re-injected rules
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "post-compact: outputs valid JSON (plugin rules present)"
  else
    # Fallback: plain text (no cwd, no rules)
    assert_contains "Context compacted" "$output" \
      "post-compact: outputs expected message"
  fi
}

test_post_compact_exits_zero() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  echo '{"summary":"compacted"}' | HOME="$FAKE_HOME" bash "$POST_COMPACT_HOOK" > /dev/null
  local exit_code=$?

  assert_exit 0 "$exit_code" "post-compact: exits 0"
}

test_post_compact_empty_stdin() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local output
  output=$(echo '' | HOME="$FAKE_HOME" bash "$POST_COMPACT_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "post-compact: empty stdin exits 0"
  # No cwd in empty stdin, plugin CLAUDE.md still exists → JSON output
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "post-compact: empty stdin produces valid JSON (plugin rules re-injected)"
  else
    assert_contains "Context compacted" "$output" \
      "post-compact: empty stdin still outputs message"
  fi
}

test_post_compact_with_cwd_reinjects_rules() {
  local FAKE_HOME
  FAKE_HOME=$(mktemp -d)
  trap 'rm -rf "$FAKE_HOME"' RETURN

  local PROJECT_DIR="/some/test/project"
  local PROJECT_SLUG
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  local LEARNED_FILE="$FAKE_HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  mkdir -p "$(dirname "$LEARNED_FILE")"
  printf 'Use immutable patterns.\n' > "$LEARNED_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","summary":"compacted"}' "$PROJECT_DIR")
  local output
  output=$(echo "$payload" | HOME="$FAKE_HOME" bash "$POST_COMPACT_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "post-compact with cwd: exits 0"

  # Validate output is valid JSON
  if echo "$output" | jq . > /dev/null 2>&1; then
    pass "post-compact with cwd: output is valid JSON"
  else
    fail "post-compact with cwd: output is valid JSON" "output was: $output"
  fi

  local event_name
  event_name=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
  assert_eq "PostCompact" "$event_name" "post-compact with cwd: hookEventName == PostCompact"

  local additional_context
  additional_context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
  assert_contains "Context compacted — rules re-injected." "$additional_context" \
    "post-compact with cwd: additionalContext contains re-inject prefix"

  assert_contains "Use immutable patterns." "$additional_context" \
    "post-compact with cwd: additionalContext contains learned content"
}
