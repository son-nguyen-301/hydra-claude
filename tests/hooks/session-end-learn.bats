#!/usr/bin/env bats
# Tests for hooks/session-end-learn.sh

load '../test_helper'

SESSION_END_LEARN_HOOK="$ROOT/hooks/session-end-learn.sh"

setup() {
  setup_isolated_home
  # Clean up any leftover flag files from previous test runs
  rm -f /tmp/hydra-claude-learn-done-test-session-*.flag 2>/dev/null || true
}

teardown() {
  rm -f /tmp/hydra-claude-learn-done-test-session-*.flag 2>/dev/null || true
}

@test "session-end-learn: empty payload exits 0" {
  run bash -c 'echo "" | HOME="$1" bash "$2"' _ "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
}

@test "session-end-learn: no transcript_path exits 0" {
  local payload='{"context_window":{"input_tokens":9999}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
}

@test "session-end-learn: tokens below threshold exits 0" {
  local payload='{"transcript_path":"/tmp/test-session-below.jsonl","context_window":{"input_tokens":1000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
}

@test "session-end-learn: tokens above threshold exits 2" {
  local payload='{"transcript_path":"/tmp/test-session-above-exit.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
}

@test "session-end-learn: tokens above threshold outputs learn message" {
  local payload='{"transcript_path":"/tmp/test-session-above-msg.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>&1 >/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_output --partial "learn"
}

@test "session-end-learn: flag file prevents double trigger" {
  local payload='{"transcript_path":"/tmp/test-session-flag.jsonl","context_window":{"input_tokens":6000}}'

  # First run: should exit 2 and create the flag
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2

  # Second run: flag exists, should exit 0
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
}

@test "session-end-learn: different transcript triggers again" {
  local payload_a='{"transcript_path":"/tmp/test-session-diff-a.jsonl","context_window":{"input_tokens":6000}}'
  local payload_b='{"transcript_path":"/tmp/test-session-diff-b.jsonl","context_window":{"input_tokens":6000}}'

  # First transcript: triggers (exit 2)
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload_a" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2

  # Different transcript: also triggers (exit 2)
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload_b" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
}
