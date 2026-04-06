#!/usr/bin/env bash
# Tests for hooks/context-compactor.sh

CONTEXT_COMPACTOR_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/context-compactor.sh"

_compactor_write_summary() {
  local dir="$1"
  local total_input="$2"
  local transcript="${3:-/tmp/fake-transcript.jsonl}"
  mkdir -p "$dir/.hydra-claude"
  printf '{"total_input":%d,"total_output":50,"transcript_path":"%s","last_updated":"2024-01-01T00:00:00Z"}\n' \
    "$total_input" "$transcript" \
    > "$dir/.hydra-claude/token-summary.json"
}

test_context_compactor_no_summary_file() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  echo '{"transcript_path":"/tmp/fake.jsonl"}' | HOME="$TMPDIR" bash "$CONTEXT_COMPACTOR_HOOK"
  local exit_code=$?
  assert_exit 0 "$exit_code" "context-compactor: no summary file exits 0"
}

test_context_compactor_different_transcript() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _compactor_write_summary "$TMPDIR" 200000 "/tmp/session-A.jsonl"

  echo '{"transcript_path":"/tmp/session-B.jsonl"}' | HOME="$TMPDIR" bash "$CONTEXT_COMPACTOR_HOOK"
  local exit_code=$?
  assert_exit 0 "$exit_code" "context-compactor: different transcript exits 0 (skipped)"
}

test_context_compactor_below_threshold() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _compactor_write_summary "$TMPDIR" 50000 "/tmp/session-X.jsonl"

  echo '{"transcript_path":"/tmp/session-X.jsonl"}' | HOME="$TMPDIR" bash "$CONTEXT_COMPACTOR_HOOK"
  local exit_code=$?
  assert_exit 0 "$exit_code" "context-compactor: total_input < 100000 exits 0"
}

test_context_compactor_at_threshold() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _compactor_write_summary "$TMPDIR" 100000 "/tmp/session-X.jsonl"

  echo '{"transcript_path":"/tmp/session-X.jsonl"}' | HOME="$TMPDIR" bash "$CONTEXT_COMPACTOR_HOOK" 2>/dev/null
  local exit_code=$?
  assert_exit 2 "$exit_code" "context-compactor: total_input == 100000 exits 2"
}

test_context_compactor_above_threshold() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  _compactor_write_summary "$TMPDIR" 150000 "/tmp/session-X.jsonl"

  local stderr_output
  stderr_output=$(echo '{"transcript_path":"/tmp/session-X.jsonl"}' | HOME="$TMPDIR" bash "$CONTEXT_COMPACTOR_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "context-compactor: total_input > 100000 exits 2"
  assert_contains "150k" "$stderr_output" "context-compactor: stderr contains formatted token count"
}
