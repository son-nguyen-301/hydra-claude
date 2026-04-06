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

# Read context window data from stdin
INPUT_JSON=$(cat)

USED_PCT=$(echo "$INPUT_JSON" | jq -r '.context_window.used_percentage // empty')

# Build token counts from summary file
if [ -f "$SUMMARY" ]; then
  TOTAL_IN=$(jq -r '.total_input // 0' "$SUMMARY" 2>/dev/null)
  TOTAL_OUT=$(jq -r '.total_output // 0' "$SUMMARY" 2>/dev/null)

  TOKENS_PART="${CYAN}↑${TOTAL_IN}${RESET} ${GREEN}↓${TOTAL_OUT}${RESET} ${DIM}tokens${RESET}"
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
