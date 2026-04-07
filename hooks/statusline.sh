#!/usr/bin/env bash
# Status line: colored token/cost/rate-limit display
# Reads all data from stdin (Claude Code statusLine JSON)

# ANSI color codes — use $'...' quoting so \033 is interpreted as ESC byte
CYAN=$'\033[0;36m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1f\", $n/1000000}" | sed 's/\.0$//'
    printf "M"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1f\", $n/1000}" | sed 's/\.0$//'
    printf "k"
  else
    echo "$n"
  fi
}

INPUT_JSON=$(cat)

# --- Token counts ---
# Only show values when context_window data is actually present
HAS_CTX_DATA=$(echo "$INPUT_JSON" | jq -r 'if .context_window then "yes" else "no" end' 2>/dev/null)

if [ "$HAS_CTX_DATA" = "yes" ]; then
  TOTAL_IN=$(echo "$INPUT_JSON" | jq -r '
    (.context_window.current_usage.input_tokens // 0)
    + (.context_window.current_usage.cache_creation_input_tokens // 0)
    + (.context_window.current_usage.cache_read_input_tokens // 0)
  ' 2>/dev/null)
  TOTAL_OUT=$(echo "$INPUT_JSON" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
  FMT_IN=$(format_tokens "$TOTAL_IN")
  FMT_OUT=$(format_tokens "$TOTAL_OUT")
  TOKENS_PART="${CYAN}↑${FMT_IN}${RESET} ${GREEN}↓${FMT_OUT}${RESET}"
else
  TOKENS_PART="${DIM}↑– ↓–${RESET}"
fi

# --- Cost ---
COST=$(echo "$INPUT_JSON" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
if [ -n "$COST" ]; then
  COST_FMT=$(awk "BEGIN {printf \"\$%.2f\", $COST}")
  if awk "BEGIN {exit !($COST >= 2.0)}"; then
    COST_COLOR="$RED"
  elif awk "BEGIN {exit !($COST >= 0.5)}"; then
    COST_COLOR="$YELLOW"
  else
    COST_COLOR="$GREEN"
  fi
  COST_PART=" ${COST_COLOR}${COST_FMT}${RESET}"
else
  COST_PART=" ${DIM}$–${RESET}"
fi

# --- Context window ---
USED_PCT=$(echo "$INPUT_JSON" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -n "$USED_PCT" ]; then
  if awk "BEGIN {exit !($USED_PCT >= 80)}"; then
    CTX_COLOR="$RED"
  elif awk "BEGIN {exit !($USED_PCT >= 50)}"; then
    CTX_COLOR="$YELLOW"
  else
    CTX_COLOR="$GREEN"
  fi
  CTX_PCT=$(printf '%.0f' "$USED_PCT")
  CTX_PART=" ${DIM}|${RESET} ${CTX_COLOR}ctx:${CTX_PCT}%${RESET}"
else
  CTX_PART=""
fi

# --- 5h rate limit ---
FIVE_HOUR_PCT=$(echo "$INPUT_JSON" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
if [ -n "$FIVE_HOUR_PCT" ]; then
  if awk "BEGIN {exit !($FIVE_HOUR_PCT >= 80)}"; then
    FIVE_COLOR="$RED"
  elif awk "BEGIN {exit !($FIVE_HOUR_PCT >= 50)}"; then
    FIVE_COLOR="$YELLOW"
  else
    FIVE_COLOR="$GREEN"
  fi
  FIVE_PCT=$(printf '%.0f' "$FIVE_HOUR_PCT")
  FIVE_PART=" ${DIM}|${RESET} ${FIVE_COLOR}5h:${FIVE_PCT}%${RESET}"

  # Append reset time when >= 80%
  if awk "BEGIN {exit !($FIVE_HOUR_PCT >= 80)}"; then
    FIVE_HOUR_RESET=$(echo "$INPUT_JSON" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
    if [ -n "$FIVE_HOUR_RESET" ]; then
      RESET_TIME=$(date -r "$FIVE_HOUR_RESET" +"%H:%M" 2>/dev/null \
        || date -d "@$FIVE_HOUR_RESET" +"%H:%M" 2>/dev/null)
      if [ -n "$RESET_TIME" ]; then
        FIVE_PART="${FIVE_PART} ${DIM}↻${RESET_TIME}${RESET}"
      fi
    fi
  fi
else
  FIVE_PART=""
fi

printf "%s%s%s%s\n" "${TOKENS_PART}" "${COST_PART}" "${CTX_PART}" "${FIVE_PART}"
