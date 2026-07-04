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

@test "session-end-learn: flag stores the token count at fire time" {
  local payload='{"transcript_path":"/tmp/test-session-armx.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
  run cat "/tmp/hydra-claude-learn-done-test-session-armx.jsonl.flag"
  assert_output "6000"
}

@test "session-end-learn: small delta after fire does not re-fire" {
  local flag="/tmp/hydra-claude-learn-done-test-session-army.jsonl.flag"
  printf '6000' > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-army.jsonl","context_window":{"input_tokens":8000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
}

@test "session-end-learn: >=5k delta re-fires and updates the flag" {
  local flag="/tmp/hydra-claude-learn-done-test-session-armz.jsonl.flag"
  printf '6000' > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-armz.jsonl","context_window":{"input_tokens":11500}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
  run cat "$flag"
  assert_output "11500"
}

@test "session-end-learn: legacy empty flag treated as zero (fires when above threshold)" {
  local flag="/tmp/hydra-claude-learn-done-test-session-arml.jsonl.flag"
  : > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-arml.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
}

@test "session-end-learn: shrunken token count re-baselines the flag without firing" {
  local flag="/tmp/hydra-claude-learn-done-test-session-shrink.jsonl.flag"
  printf '20000' > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-shrink.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_success
  run cat "$flag"
  assert_output "6000"
}

@test "session-end-learn: fires again after re-baseline once delta reaches 5k" {
  local flag="/tmp/hydra-claude-learn-done-test-session-rearm.jsonl.flag"
  printf '6000' > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-rearm.jsonl","context_window":{"input_tokens":11500}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  assert_failure 2
}

@test "session-end-learn: leading-zero flag content does not error" {
  local flag="/tmp/hydra-claude-learn-done-test-session-octal.jsonl.flag"
  printf '008' > "$flag"
  local payload='{"transcript_path":"/tmp/test-session-octal.jsonl","context_window":{"input_tokens":6000}}'
  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$SESSION_END_LEARN_HOOK"
  refute_output --partial "value too great for base"
}
