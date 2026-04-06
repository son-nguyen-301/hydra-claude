#!/usr/bin/env bash
# PostToolUse hook — reads token usage from transcript and writes totals to ~/.aspire-spark/token-summary.json

LOG_DIR="$HOME/.aspire-spark"
SUMMARY_FILE="$LOG_DIR/token-summary.json"

mkdir -p "$LOG_DIR"

PAYLOAD=$(cat)

TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Parse transcript: use the most recent assistant message's input tokens to measure current context size.
# Summing across turns inflates the count — each message's input_tokens reflects the full context at
# that moment, not a delta. The latest message is the ground truth for current context window usage.
TOTALS=$(jq -rn --rawfile t "$TRANSCRIPT" '
  ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
  | ($all | map(select(.message.usage != null)) | unique_by(.message.id) | last) as $latest
  | if $latest == null then {total_input: 0, total_output: 0}
    else {
      total_input: (
        ($latest.message.usage.input_tokens // 0)
        + ($latest.message.usage.cache_creation_input_tokens // 0)
        + ($latest.message.usage.cache_read_input_tokens // 0)
      ),
      total_output: ($latest.message.usage.output_tokens // 0)
    }
    end
' 2>/dev/null)

if [ -z "$TOTALS" ]; then
  exit 0
fi

echo "$TOTALS" | jq --arg updated "$TIMESTAMP" --arg transcript "$TRANSCRIPT" \
  '. + {last_updated: $updated, transcript_path: $transcript}' \
  > "$SUMMARY_FILE" 2>/dev/null

exit 0
