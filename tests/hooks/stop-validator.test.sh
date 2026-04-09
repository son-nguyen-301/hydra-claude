#!/usr/bin/env bash
# Tests for hooks/stop-validator.sh

STOP_VALIDATOR_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/stop-validator.sh"

# Helper: create a fake transcript file with a given tool name in the last assistant message
_make_transcript() {
  local tmpfile="$1"
  local tool_name="$2"

  if [ -z "$tool_name" ]; then
    # Assistant message with no tool uses
    cat > "$tmpfile" <<'EOF'
{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Done."}]}}
EOF
  else
    cat > "$tmpfile" <<EOF
{"type":"message","message":{"role":"assistant","content":[{"type":"tool_use","name":"$tool_name","id":"abc","input":{}}]}}
EOF
  fi
}

test_stop_validator_no_transcript() {
  local output
  output=$(echo '{}' | bash "$STOP_VALIDATOR_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "stop-validator: no transcript exits 0"
}

test_stop_validator_missing_transcript_file() {
  local output
  output=$(echo '{"transcript_path":"/nonexistent/path/transcript.jsonl"}' | bash "$STOP_VALIDATOR_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "stop-validator: missing transcript file exits 0"
}

test_stop_validator_no_tool_use() {
  local TMPFILE
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' RETURN
  _make_transcript "$TMPFILE" ""

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$TMPFILE")
  local output
  output=$(echo "$payload" | bash "$STOP_VALIDATOR_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "stop-validator: no tool use exits 0"
}

test_stop_validator_agent_tool_use() {
  local TMPFILE
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' RETURN
  _make_transcript "$TMPFILE" "Agent"

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$TMPFILE")
  local output
  output=$(echo "$payload" | bash "$STOP_VALIDATOR_HOOK" 2>&1)
  local exit_code=$?

  assert_exit 0 "$exit_code" "stop-validator: Agent tool use exits 0 (valid delegation)"
}

test_stop_validator_direct_edit_violation() {
  local TMPFILE
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' RETURN
  _make_transcript "$TMPFILE" "Edit"

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$TMPFILE")
  local stderr_output
  stderr_output=$(echo "$payload" | bash "$STOP_VALIDATOR_HOOK" 2>&1 >/dev/null)
  local exit_code=$?

  assert_exit 2 "$exit_code" "stop-validator: Edit tool use exits 2 (violation)"
  assert_contains "RULE VIOLATION" "$stderr_output" \
    "stop-validator: Edit violation writes RULE VIOLATION to stderr"
}

test_stop_validator_direct_write_violation() {
  local TMPFILE
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' RETURN
  _make_transcript "$TMPFILE" "Write"

  local payload
  payload=$(printf '{"transcript_path":"%s"}' "$TMPFILE")
  local exit_code
  echo "$payload" | bash "$STOP_VALIDATOR_HOOK" > /dev/null 2>&1
  exit_code=$?

  assert_exit 2 "$exit_code" "stop-validator: Write tool use exits 2 (violation)"
}
