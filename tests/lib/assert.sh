#!/usr/bin/env bash
# Test assertion helpers

TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

# ANSI colors
_GREEN=$'\033[0;32m'
_RED=$'\033[0;31m'
_RESET=$'\033[0m'

pass() {
  local label="$1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "%s  PASS%s  %s\n" "$_GREEN" "$_RESET" "$label"
}

fail() {
  local label="$1"
  local details="${2:-}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "%s  FAIL%s  %s\n" "$_RED" "$_RESET" "$label" >&2
  if [ -n "$details" ]; then
    printf "         %s\n" "$details" >&2
  fi
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label" "expected: $(printf '%q' "$expected")  actual: $(printf '%q' "$actual")"
  fi
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "expected to contain: $(printf '%q' "$needle")"
  fi
}

assert_exit() {
  local expected_code="$1"
  local actual_code="$2"
  local label="$3"
  if [ "$expected_code" -eq "$actual_code" ]; then
    pass "$label"
  else
    fail "$label" "expected exit $expected_code  got exit $actual_code"
  fi
}

assert_file_exists() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label" "file not found: $path"
  fi
}

assert_json_valid() {
  local file="$1"
  local label="$2"
  if jq . "$file" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label" "invalid JSON in: $file"
  fi
}
