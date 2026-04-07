#!/usr/bin/env bash
# PostToolUse hook — reads token usage from transcript and writes totals to ~/.hydra-claude/token-summary.json

LOG_DIR="$HOME/.hydra-claude"
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
# For output tokens, sum the FINAL occurrence of each message ID (last in streaming sequence).
TOTALS=$(jq -rn --rawfile t "$TRANSCRIPT" '
  ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
  | ($all | map(select(.message.usage != null)) | last) as $latest
  | if $latest == null then {total_input: 0, total_output: 0}
    else {
      total_input: (
        ($latest.message.usage.input_tokens // 0)
        + ($latest.message.usage.cache_creation_input_tokens // 0)
        + ($latest.message.usage.cache_read_input_tokens // 0)
      ),
      total_output: (
        [$all[] | select(.message.role == "assistant" and .message.usage != null)]
        | group_by(.message.id)
        | map(.[-1].message.usage.output_tokens // 0)
        | add // 0
      )
    }
    end
' 2>/dev/null)

if [ -z "$TOTALS" ]; then
  exit 0
fi

# Extract session_id with fallback to transcript filename
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)
if [ -z "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ]; then
  SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
fi

# Sum output tokens from subagent transcripts created in this session.
# Read session start from current-session.json; fall back to transcript parsing.
TRANSCRIPT_DIR=$(dirname "$TRANSCRIPT")
STATE_FILE="$HOME/.hydra-claude/current-session.json"
SESSION_EPOCH=0
if [ -f "$STATE_FILE" ]; then
  STATE_SID=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
  if [ -z "$SESSION_ID" ] || [ -z "$STATE_SID" ] || [ "$SESSION_ID" = "$STATE_SID" ]; then
    SESSION_EPOCH=$(jq -r '.start_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  fi
fi
if [ "$SESSION_EPOCH" -eq 0 ]; then
  SESSION_EPOCH=$(jq -rn --rawfile t "$TRANSCRIPT" '
    ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
    | ($all | map(select(.timestamp != null)) | first | .timestamp)
    | if . then fromdate else 0 end
  ' 2>/dev/null || echo 0)
fi
SESSION_START=$((SESSION_EPOCH - 60))

SUBAGENT_OUTPUT=0
SUBAGENT_INPUT=0
for f in "$TRANSCRIPT_DIR"/*.jsonl; do
  [ "$f" = "$TRANSCRIPT" ] && continue
  [ ! -f "$f" ] && continue
  F_MTIME=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
  [ "$F_MTIME" -lt "$SESSION_START" ] && continue

  file_output=$(jq -rn --rawfile t "$f" '
    ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
    | [$all[] | select(.message.role == "assistant" and .message.usage != null)]
    | group_by(.message.id)
    | map(.[-1].message.usage.output_tokens // 0)
    | add // 0
  ' 2>/dev/null || echo 0)
  SUBAGENT_OUTPUT=$((SUBAGENT_OUTPUT + file_output))

  # input tokens — use latest message only (same rationale as main session)
  file_input=$(jq -rn --rawfile t "$f" '
    ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
    | ($all | map(select(.message.usage != null)) | last) as $latest
    | if $latest == null then 0
      else (
        ($latest.message.usage.input_tokens // 0)
        + ($latest.message.usage.cache_creation_input_tokens // 0)
        + ($latest.message.usage.cache_read_input_tokens // 0)
      )
      end
  ' 2>/dev/null || echo 0)
  SUBAGENT_INPUT=$((SUBAGENT_INPUT + file_input))
done

echo "$TOTALS" | jq --arg updated "$TIMESTAMP" --arg transcript "$TRANSCRIPT" \
  --arg sid "$SESSION_ID" \
  --argjson subagent_output "$SUBAGENT_OUTPUT" --argjson subagent_input "$SUBAGENT_INPUT" \
  '. + {last_updated: $updated, transcript_path: $transcript, session_id: $sid,
        total_output_subagents: $subagent_output, total_input_subagents: $subagent_input}' \
  > "$SUMMARY_FILE" 2>/dev/null

if [ -n "$SESSION_ID" ]; then
  mkdir -p "$LOG_DIR/sessions"
  cp "$SUMMARY_FILE" "$LOG_DIR/sessions/${SESSION_ID}.json" 2>/dev/null
fi

exit 0
