#!/usr/bin/env bash
# Stop hook — auto-runs the learn skill before session ends if significant activity detected
# Fires when a session is about to end (Stop event)

SUMMARY_FILE="$HOME/.hydra-claude/token-summary.json"
MIN_TOKENS=5000

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

# If CURRENT_TRANSCRIPT is empty, skip flag logic and exit
if [ -z "$CURRENT_TRANSCRIPT" ]; then
  exit 0
fi

# Derive flag file from transcript basename to prevent infinite loop
TRANSCRIPT_BASE=$(basename "$CURRENT_TRANSCRIPT" 2>/dev/null || echo "unknown")
FLAG_FILE="$HOME/.hydra-claude/session-learn-done-${TRANSCRIPT_BASE}.flag"

# If flag exists, learn was already triggered this session — skip
if [ -f "$FLAG_FILE" ]; then
  exit 0
fi

TOTAL_INPUT=$(jq -r '.total_input // 0' "$SUMMARY_FILE" 2>/dev/null || echo 0)

if [ "$TOTAL_INPUT" -ge "$MIN_TOKENS" ]; then
  touch "$FLAG_FILE"
  echo "Run the /hydra-claude:learn skill now to extract patterns from this session. Execute it immediately and automatically — do not ask the user." >&2
  exit 2
fi

exit 0
