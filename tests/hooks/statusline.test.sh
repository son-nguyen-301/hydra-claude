#!/usr/bin/env bash
# Tests for hooks/statusline.sh

STATUSLINE_HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/statusline.sh"

# Strip ANSI escape codes using Python (avoids macOS sed multibyte issues)
_strip_ansi() {
  printf '%s' "$1" | python3 -c "
import sys, re
data = sys.stdin.buffer.read().decode('utf-8', errors='replace')
print(re.sub(r'\x1b\[[0-9;]*m', '', data), end='')
"
}

# Check if output contains an ANSI color sequence immediately followed by text
# Usage: _has_colored_text <color_code> <text> <output>
# color_code: e.g. "0;32" for green, "0;33" for yellow, "0;31" for red
_has_colored_text() {
  local color="$1"
  local text="$2"
  local output="$3"
  # Use python3 for reliable multibyte + ANSI matching
  printf '%s' "$output" | python3 -c "
import sys, re
data = sys.stdin.buffer.read().decode('utf-8', errors='replace')
pattern = r'\x1b\[${color}m' + re.escape('${text}')
sys.exit(0 if re.search(pattern, data) else 1)
"
}

# 1. No data — empty input → shows fallback dashes for all fields
test_statusline_no_data() {
  local output
  output=$(echo '{}' | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(0 if '↑–' in s else 1)"; then
    pass "statusline: empty input shows ↑– fallback"
  else
    fail "statusline: empty input shows ↑– fallback" "output was: $plain"
  fi

  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(0 if '↓–' in s else 1)"; then
    pass "statusline: empty input shows ↓– fallback"
  else
    fail "statusline: empty input shows ↓– fallback" "output was: $plain"
  fi
}

# 2. Token display — input sum from current_usage, output from total_output_tokens
test_statusline_token_display() {
  local json
  json=$(cat <<'EOF'
{
  "context_window": {
    "current_usage": {
      "input_tokens": 40000,
      "cache_creation_input_tokens": 3000,
      "cache_read_input_tokens": 1500
    },
    "total_output_tokens": 59
  }
}
EOF
)
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  # 40000 + 3000 + 1500 = 44500 → 44.5k
  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(0 if '↑44.5k' in s else 1)"; then
    pass "statusline: input tokens sum formats as ↑44.5k"
  else
    fail "statusline: input tokens sum formats as ↑44.5k" "output was: $plain"
  fi

  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(0 if '↓59' in s else 1)"; then
    pass "statusline: total_output_tokens shows ↓59"
  else
    fail "statusline: total_output_tokens shows ↓59" "output was: $plain"
  fi
}

# 3. Cost display — rounds to 2 decimal places
test_statusline_cost_display() {
  local json='{"cost":{"total_cost_usd":0.11867745}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains '$0.12' "$plain" "statusline: cost 0.11867745 rounds to \$0.12"
}

# 4. Cost color thresholds
test_statusline_cost_color_green() {
  local json='{"cost":{"total_cost_usd":0.30}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;32" '$0.30' "$output"; then
    pass "statusline: cost < \$0.50 is green"
  else
    fail "statusline: cost < \$0.50 is green" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_cost_color_yellow() {
  local json='{"cost":{"total_cost_usd":1.00}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;33" '$1.00' "$output"; then
    pass "statusline: cost \$0.50-\$2.00 is yellow"
  else
    fail "statusline: cost \$0.50-\$2.00 is yellow" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_cost_color_red() {
  local json='{"cost":{"total_cost_usd":2.50}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;31" '$2.50' "$output"; then
    pass "statusline: cost >= \$2.00 is red"
  else
    fail "statusline: cost >= \$2.00 is red" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

# 5. Context window display
test_statusline_ctx_display() {
  local json='{"context_window":{"used_percentage":22}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "ctx:22%" "$plain" "statusline: used_percentage=22 shows ctx:22%"
}

# 6. Context color thresholds
test_statusline_ctx_color_green() {
  local json='{"context_window":{"used_percentage":30}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;32" 'ctx:30%' "$output"; then
    pass "statusline: ctx < 50% is green"
  else
    fail "statusline: ctx < 50% is green" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_ctx_color_yellow() {
  local json='{"context_window":{"used_percentage":60}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;33" 'ctx:60%' "$output"; then
    pass "statusline: ctx 50-80% is yellow"
  else
    fail "statusline: ctx 50-80% is yellow" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_ctx_color_red() {
  local json='{"context_window":{"used_percentage":85}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;31" 'ctx:85%' "$output"; then
    pass "statusline: ctx >= 80% is red"
  else
    fail "statusline: ctx >= 80% is red" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

# 7. Rate limit display
test_statusline_rate_limit_display() {
  local json='{"rate_limits":{"five_hour":{"used_percentage":66}}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  assert_contains "5h:66%" "$plain" "statusline: five_hour used_percentage=66 shows 5h:66%"
}

# 8. Rate limit reset time shown when >= 80%
test_statusline_rate_limit_reset_time() {
  local EPOCH=1700000000
  local json
  json=$(printf '{"rate_limits":{"five_hour":{"used_percentage":85,"resets_at":%d}}}' "$EPOCH")
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(0 if '↻' in s else 1)"; then
    pass "statusline: >= 80% rate limit shows reset time with ↻"
  else
    fail "statusline: >= 80% rate limit shows reset time with ↻" "output was: $plain"
  fi
}

test_statusline_rate_limit_no_reset_below_80() {
  local json='{"rate_limits":{"five_hour":{"used_percentage":70,"resets_at":1700000000}}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  local plain
  plain=$(_strip_ansi "$output")

  if printf '%s' "$plain" | python3 -c "import sys; s=sys.stdin.read(); sys.exit(1 if '↻' in s else 0)"; then
    pass "statusline: < 80% rate limit does not show reset time"
  else
    fail "statusline: < 80% rate limit does not show reset time" "output was: $plain"
  fi
}

# 9. Rate limit color thresholds
test_statusline_rate_limit_color_green() {
  local json='{"rate_limits":{"five_hour":{"used_percentage":40}}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;32" '5h:40%' "$output"; then
    pass "statusline: 5h < 50% is green"
  else
    fail "statusline: 5h < 50% is green" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_rate_limit_color_yellow() {
  local json='{"rate_limits":{"five_hour":{"used_percentage":70}}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;33" '5h:70%' "$output"; then
    pass "statusline: 5h 50-80% is yellow"
  else
    fail "statusline: 5h 50-80% is yellow" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}

test_statusline_rate_limit_color_red() {
  local json='{"rate_limits":{"five_hour":{"used_percentage":90}}}'
  local output
  output=$(echo "$json" | bash "$STATUSLINE_HOOK")
  if _has_colored_text "0;31" '5h:90%' "$output"; then
    pass "statusline: 5h >= 80% is red"
  else
    fail "statusline: 5h >= 80% is red" "output was: $(printf '%s' "$output" | cat -v)"
  fi
}
