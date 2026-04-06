#!/usr/bin/env bash
# Tests for hooks/statusline.sh

STATUSLINE_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/statusline.sh"

_strip_ansi() {
  printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

_statusline_write_summary() {
  local dir="$1"
  local total_input="${2:-1000}"
  local total_output="${3:-50}"
  mkdir -p "$dir/.hydra-claude"
  printf '{"total_input":%d,"total_output":%d,"last_updated":"2024-01-01T00:00:00Z"}\n' \
    "$total_input" "$total_output" \
    > "$dir/.hydra-claude/token-summary.json"
}

test_statusline_no_summary_file() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local output
  output=$(echo '{}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "Tokens: –" "$plain" "statusline: no summary file shows 'Tokens: –'"
}

test_statusline_with_summary() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _statusline_write_summary "$TMPDIR" 1234 56

  local output
  output=$(echo '{}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "↑1234" "$plain" "statusline: output contains ↑<input>"
  assert_contains "↓56" "$plain" "statusline: output contains ↓<output>"
  assert_contains "tokens" "$plain" "statusline: output contains 'tokens'"
}

test_statusline_no_context_window() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _statusline_write_summary "$TMPDIR"

  local output
  output=$(echo '{}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  if [[ "$plain" != *"ctx:"* ]]; then
    pass "statusline: no used_percentage means no 'ctx:' in output"
  else
    fail "statusline: no used_percentage means no 'ctx:' in output" "output was: $plain"
  fi
}

test_statusline_ctx_30_percent() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _statusline_write_summary "$TMPDIR"

  local output
  output=$(echo '{"context_window":{"used_percentage":30}}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "ctx:30%" "$plain" "statusline: used_percentage=30 shows ctx:30%"
}

test_statusline_ctx_60_percent() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _statusline_write_summary "$TMPDIR"

  local output
  output=$(echo '{"context_window":{"used_percentage":60}}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "ctx:60%" "$plain" "statusline: used_percentage=60 shows ctx:60%"
}

test_statusline_ctx_85_percent() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _statusline_write_summary "$TMPDIR"

  local output
  output=$(echo '{"context_window":{"used_percentage":85}}' | HOME="$TMPDIR" bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "ctx:85%" "$plain" "statusline: used_percentage=85 shows ctx:85%"
}
