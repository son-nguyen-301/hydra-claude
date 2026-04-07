#!/usr/bin/env bash
# Tests for hooks/post-compact.sh

POST_COMPACT_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/post-compact.sh"

test_post_compact_outputs_message() {
  local output
  output=$(echo '{"summary":"compacted"}' | HOME="$TMPDIR" bash "$POST_COMPACT_HOOK")

  assert_contains "Context compacted. Token metrics updated." "$output" \
    "post-compact: outputs expected message"
}

test_post_compact_exits_zero() {
  echo '{"summary":"compacted"}' | HOME="$TMPDIR" bash "$POST_COMPACT_HOOK" > /dev/null
  local exit_code=$?

  assert_exit 0 "$exit_code" "post-compact: exits 0"
}

test_post_compact_empty_stdin() {
  local output
  output=$(echo '' | HOME="$TMPDIR" bash "$POST_COMPACT_HOOK")
  local exit_code=$?

  assert_exit 0 "$exit_code" "post-compact: empty stdin exits 0"
  assert_contains "Context compacted. Token metrics updated." "$output" \
    "post-compact: empty stdin still outputs message"
}
