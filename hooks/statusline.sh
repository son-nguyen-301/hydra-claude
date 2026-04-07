#!/usr/bin/env bash
# Status line: colored token usage display
# Reads from stdin (Claude Code JSON) and ~/.hydra-claude/token-summary.json

SUMMARY="$HOME/.hydra-claude/token-summary.json"

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

# Read context window data from stdin
INPUT_JSON=$(cat)

USED_PCT=$(echo "$INPUT_JSON" | jq -r '.context_window.used_percentage // empty')

# Build token counts from summary file
STATE_FILE="$HOME/.hydra-claude/current-session.json"

if [ -f "$SUMMARY" ]; then
  SUMMARY_SID=$(jq -r '.session_id // empty' "$SUMMARY" 2>/dev/null)
  CURRENT_SID=""
  if [ -f "$STATE_FILE" ]; then
    CURRENT_SID=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
  fi

  # Show zero if the summary belongs to a different (prior) session
  if [ -n "$CURRENT_SID" ] && [ -n "$SUMMARY_SID" ] && [ "$CURRENT_SID" != "$SUMMARY_SID" ]; then
    TOKENS_PART="${DIM}↑0 ↓0 tokens${RESET}"
  else
    TOTAL_IN=$(jq -r '.total_input // 0' "$SUMMARY" 2>/dev/null)
    TOTAL_IN_SUBAGENTS=$(jq -r '.total_input_subagents // 0' "$SUMMARY" 2>/dev/null)
    TOTAL_IN=$((TOTAL_IN + TOTAL_IN_SUBAGENTS))
    TOTAL_OUT=$(jq -r '(.total_output // 0) + (.total_output_subagents // 0)' "$SUMMARY" 2>/dev/null)

    FMT_IN=$(format_tokens "$TOTAL_IN")
    FMT_OUT=$(format_tokens "$TOTAL_OUT")
    TOKENS_PART="${CYAN}↑${FMT_IN}${RESET} ${GREEN}↓${FMT_OUT}${RESET} ${DIM}tokens${RESET}"
  fi
else
  TOKENS_PART="${DIM}Tokens: –${RESET}"
fi

# Append context window usage if available
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

printf "%s%s\n" "${TOKENS_PART}" "${CTX_PART}"
