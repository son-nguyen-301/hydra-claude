#!/usr/bin/env bash
# Tests for hooks/token-logger.sh

TOKEN_LOGGER_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/token-logger.sh"

test_token_logger_empty_transcript_path() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local payload='{"transcript_path":""}'
  echo "$payload" | HOME="$TMPDIR" bash "$TOKEN_LOGGER_HOOK"
  local exit_code=$?

  assert_exit 0 "$exit_code" "token-logger: empty transcript_path exits 0"
  if [ ! -f "$TMPDIR/.hydra-claude/token-summary.json" ]; then
    pass "token-logger: empty transcript_path writes no summary file"
  else
    fail "token-logger: empty transcript_path writes no summary file" "file was unexpectedly created"
  fi
}

test_token_logger_nonexistent_transcript() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local payload='{"transcript_path":"/nonexistent/path/transcript.jsonl"}'
  echo "$payload" | HOME="$TMPDIR" bash "$TOKEN_LOGGER_HOOK"
  local exit_code=$?

  assert_exit 0 "$exit_code" "token-logger: nonexistent transcript exits 0"
}

test_token_logger_valid_transcript() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local transcript="$TMPDIR/transcript.jsonl"
  printf '%s\n' \
    '{"message":{"id":"msg_01","usage":{"input_tokens":1000,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' \
    > "$transcript"

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$transcript")
  echo "$payload" | HOME="$TMPDIR" bash "$TOKEN_LOGGER_HOOK"
  local exit_code=$?

  assert_exit 0 "$exit_code" "token-logger: valid transcript exits 0"
  assert_file_exists "$TMPDIR/.hydra-claude/token-summary.json" "token-logger: valid transcript writes summary file"

  local summary="$TMPDIR/.hydra-claude/token-summary.json"
  if [ -f "$summary" ]; then
    local has_total_input has_total_output has_last_updated has_transcript_path
    has_total_input=$(jq 'has("total_input")' "$summary" 2>/dev/null)
    has_total_output=$(jq 'has("total_output")' "$summary" 2>/dev/null)
    has_last_updated=$(jq 'has("last_updated")' "$summary" 2>/dev/null)
    has_transcript_path=$(jq 'has("transcript_path")' "$summary" 2>/dev/null)
    assert_eq "true" "$has_total_input" "token-logger: summary has total_input field"
    assert_eq "true" "$has_total_output" "token-logger: summary has total_output field"
    assert_eq "true" "$has_last_updated" "token-logger: summary has last_updated field"
    assert_eq "true" "$has_transcript_path" "token-logger: summary has transcript_path field"
  fi
}

test_token_logger_cache_tokens() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' RETURN

  local transcript="$TMPDIR/transcript.jsonl"
  # input_tokens=1000, cache_creation=200, cache_read=100 → total_input should be 1300
  printf '%s\n' \
    '{"message":{"id":"msg_01","usage":{"input_tokens":1000,"output_tokens":50,"cache_creation_input_tokens":200,"cache_read_input_tokens":100}}}' \
    > "$transcript"

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$transcript")
  echo "$payload" | HOME="$TMPDIR" bash "$TOKEN_LOGGER_HOOK"

  local summary="$TMPDIR/.hydra-claude/token-summary.json"
  if [ -f "$summary" ]; then
    local total_input
    total_input=$(jq -r '.total_input' "$summary" 2>/dev/null)
    assert_eq "1300" "$total_input" "token-logger: total_input = input + cache_creation + cache_read"
  else
    fail "token-logger: cache tokens — summary file not written"
  fi
}
