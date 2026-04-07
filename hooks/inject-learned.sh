#!/usr/bin/env bash
# SessionStart hook — injects learned.md into session context

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

# --- Session reset ---
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

# Fallback: derive session_id from transcript filename ({session_id}.jsonl)
if [ -z "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ]; then
  SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
fi

SUMMARY_FILE="$HOME/.hydra-claude/token-summary.json"
SESSIONS_DIR="$HOME/.hydra-claude/sessions"
STATE_FILE="$HOME/.hydra-claude/current-session.json"
mkdir -p "$SESSIONS_DIR"

# Archive the previous session's summary (keyed by its stored session_id)
if [ -f "$SUMMARY_FILE" ] && [ -n "$SESSION_ID" ]; then
  OLD_SID=$(jq -r '.session_id // empty' "$SUMMARY_FILE" 2>/dev/null)
  if [ -n "$OLD_SID" ] && [ "$OLD_SID" != "$SESSION_ID" ]; then
    cp "$SUMMARY_FILE" "$SESSIONS_DIR/${OLD_SID}.json" 2>/dev/null
  fi
fi

# Reset token summary for the new session (guard kept; SESSION_ID is always set via fallback)
if [ -n "$SESSION_ID" ]; then
  printf '{"total_input":0,"total_output":0,"total_input_subagents":0,"total_output_subagents":0,"session_id":"%s"}\n' \
    "$SESSION_ID" > "$SUMMARY_FILE" 2>/dev/null

  # Write session state for token-logger and statusline to consume
  START_EPOCH=$(date +%s)
  printf '{"session_id":"%s","transcript_path":"%s","start_epoch":%d}\n' \
    "$SESSION_ID" "$TRANSCRIPT" "$START_EPOCH" > "$STATE_FILE" 2>/dev/null
fi
# --- End session reset ---

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

LEARNED_FILE="$PROJECT_DIR/.claude/memory/learned.md"

if [ ! -f "$LEARNED_FILE" ]; then
  exit 0
fi

CONTENT=$(cat "$LEARNED_FILE")

if [ -z "$CONTENT" ]; then
  exit 0
fi

printf '%s' "$CONTENT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("Repo-specific learned patterns (MUST follow strictly):\n\n" + .)
  }
}'
