#!/usr/bin/env bash
# UserPromptSubmit hook — requests compaction when cumulative tokens exceed 50% of context window
# Claude Sonnet/Opus context window: ~200k tokens. 50% threshold = 100k tokens.

SUMMARY_FILE="$HOME/.hydra-claude/token-summary.json"
CONTEXT_THRESHOLD=100000

if [ ! -f "$SUMMARY_FILE" ]; then
  exit 0
fi

# Read the current prompt payload to get the current transcript path
PAYLOAD=$(cat)
CURRENT_TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

# Read the transcript path that was active when the summary was last written
SUMMARY_TRANSCRIPT=$(jq -r '.transcript_path // empty' "$SUMMARY_FILE" 2>/dev/null)

# If transcripts don't match, the summary is from a different session — skip
if [ -n "$CURRENT_TRANSCRIPT" ] && [ -n "$SUMMARY_TRANSCRIPT" ]; then
  if [ "$CURRENT_TRANSCRIPT" != "$SUMMARY_TRANSCRIPT" ]; then
    exit 0
  fi
fi

TOTAL_INPUT=$(jq -r '.total_input // 0' "$SUMMARY_FILE" 2>/dev/null || echo 0)

format_tokens() {
  local n=$1
  if [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN {
      k = n / 1000
      if (k == int(k)) printf "%dk", k
      else printf "%.1fk", k
    }'
  else
    echo "$n"
  fi
}

if [ "$TOTAL_INPUT" -ge "$CONTEXT_THRESHOLD" ]; then
  FORMATTED=$(format_tokens "$TOTAL_INPUT")
  echo "Context window is at or above 50% capacity (${FORMATTED} input tokens used). Please run /compact before proceeding to keep the session healthy." >&2
  exit 2
fi

exit 0
