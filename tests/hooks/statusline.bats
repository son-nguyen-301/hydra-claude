#!/usr/bin/env bats
# Tests for hooks/statusline.sh

load '../test_helper'

STATUSLINE_HOOK="$ROOT/hooks/statusline.sh"

# Strip ANSI escape codes using Python
_strip_ansi() {
  printf '%s' "$1" | python3 -c "
import sys, re
data = sys.stdin.buffer.read().decode('utf-8', errors='replace')
print(re.sub(r'\x1b\[[0-9;]*m', '', data), end='')
"
}

# Check if output contains an ANSI color sequence immediately followed by text
# Usage: _has_colored_text <color_code> <text> <output>
_has_colored_text() {
  local color="$1"
  local text="$2"
  local output="$3"
  printf '%s' "$output" | python3 -c "
import sys, re
data = sys.stdin.buffer.read().decode('utf-8', errors='replace')
pattern = r'\x1b\[${color}m' + re.escape('${text}')
sys.exit(0 if re.search(pattern, data) else 1)
"
}

@test "statusline: empty input shows up-arrow dash fallback" {
  run bash -c 'echo "{}" | bash "$1"' _ "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(0 if '↑–' in s else 1)" <<< "$plain"
  assert_success
}

@test "statusline: empty input shows down-arrow dash fallback" {
  run bash -c 'echo "{}" | bash "$1"' _ "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(0 if '↓–' in s else 1)" <<< "$plain"
  assert_success
}

@test "statusline: input tokens sum formats as ↑44.5k" {
  local json
  json='{"context_window":{"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":1500},"total_output_tokens":59}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(0 if '↑44.5k' in s else 1)" <<< "$plain"
  assert_success
}

@test "statusline: total_output_tokens shows ↓59" {
  local json
  json='{"context_window":{"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":1500},"total_output_tokens":59}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(0 if '↓59' in s else 1)" <<< "$plain"
  assert_success
}

@test "statusline: cost 0.11867745 rounds to \$0.12" {
  local json='{"cost":{"total_cost_usd":0.11867745}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  assert [ "${plain}" = "${plain/\$0.12/}" ] && false || true
  run bash -c 'echo "$1" | grep -q "\$0.12"' _ "$plain"
  assert_success
}

@test "statusline: cost < \$0.50 is green" {
  local json='{"cost":{"total_cost_usd":0.30}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;32" '$0.30' "$output"
}

@test "statusline: cost \$0.50-\$2.00 is yellow" {
  local json='{"cost":{"total_cost_usd":1.00}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;33" '$1.00' "$output"
}

@test "statusline: cost >= \$2.00 is red" {
  local json='{"cost":{"total_cost_usd":2.50}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;31" '$2.50' "$output"
}

@test "statusline: used_percentage=22 shows ctx:22%" {
  local json='{"context_window":{"used_percentage":22}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run bash -c 'echo "$1" | grep -q "ctx:22%"' _ "$plain"
  assert_success
}

@test "statusline: ctx < 50% is green" {
  local json='{"context_window":{"used_percentage":30}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;32" 'ctx:30%' "$output"
}

@test "statusline: ctx 50-80% is yellow" {
  local json='{"context_window":{"used_percentage":60}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;33" 'ctx:60%' "$output"
}

@test "statusline: ctx >= 80% is red" {
  local json='{"context_window":{"used_percentage":85}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;31" 'ctx:85%' "$output"
}

@test "statusline: five_hour used_percentage=66 shows 5h:66%" {
  local json='{"rate_limits":{"five_hour":{"used_percentage":66}}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run bash -c 'echo "$1" | grep -q "5h:66%"' _ "$plain"
  assert_success
}

@test "statusline: >= 80% rate limit shows reset time with ↻" {
  local EPOCH=1700000000
  local json
  json=$(printf '{"rate_limits":{"five_hour":{"used_percentage":85,"resets_at":%d}}}' "$EPOCH")
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(0 if '↻' in s else 1)" <<< "$plain"
  assert_success
}

@test "statusline: < 80% rate limit does not show reset time" {
  local json='{"rate_limits":{"five_hour":{"used_percentage":70,"resets_at":1700000000}}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  local plain
  plain=$(_strip_ansi "$output")
  run python3 -c "import sys; s=open('/dev/stdin').read(); sys.exit(1 if '↻' in s else 0)" <<< "$plain"
  assert_success
}

@test "statusline: 5h < 50% is green" {
  local json='{"rate_limits":{"five_hour":{"used_percentage":40}}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;32" '5h:40%' "$output"
}

@test "statusline: 5h 50-80% is yellow" {
  local json='{"rate_limits":{"five_hour":{"used_percentage":70}}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;33" '5h:70%' "$output"
}

@test "statusline: 5h >= 80% is red" {
  local json='{"rate_limits":{"five_hour":{"used_percentage":90}}}'
  run bash -c 'echo "$1" | bash "$2"' _ "$json" "$STATUSLINE_HOOK"
  assert_success
  _has_colored_text "0;31" '5h:90%' "$output"
}
