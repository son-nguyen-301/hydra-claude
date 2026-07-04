#!/usr/bin/env bash
# Stop hook — auto-runs the learn skill before session ends if significant activity detected
# Fires when a session is about to end (Stop event). Reads token count from the Stop payload.

MIN_TOKENS=5000

# Read the Stop event payload from stdin
PAYLOAD=$(cat)

# Extract transcript path from payload
CURRENT_TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

# If no transcript path, nothing meaningful happened — skip
if [ -z "$CURRENT_TRANSCRIPT" ]; then
  exit 0
fi

# Derive flag file from transcript basename to prevent infinite loop
TRANSCRIPT_BASE=$(basename "$CURRENT_TRANSCRIPT" 2>/dev/null || echo "unknown")
FLAG_FILE="/tmp/hydra-claude-learn-done-${TRANSCRIPT_BASE}.flag"

# Flag stores the input-token count at last fire (legacy empty flag = 0).
LAST_FIRED=0
if [ -f "$FLAG_FILE" ]; then
  LAST_FIRED=$(cat "$FLAG_FILE" 2>/dev/null)
  case "$LAST_FIRED" in ''|*[!0-9]*) LAST_FIRED=0 ;; esac
fi

# Extract token count from Stop payload (context_window.input_tokens)
TOTAL_INPUT=$(echo "$PAYLOAD" | jq -r '.context_window.input_tokens // 0' 2>/dev/null || echo 0)
case "$TOTAL_INPUT" in ''|*[!0-9]*) TOTAL_INPUT=0 ;; esac

if [ $(( TOTAL_INPUT - LAST_FIRED )) -ge "$MIN_TOKENS" ]; then
  printf '%s' "$TOTAL_INPUT" > "$FLAG_FILE"
  # Clean up flag files older than 24h to prevent /tmp pollution
  find /tmp -name "hydra-claude-learn-done-*.flag" -mtime +1 -delete 2>/dev/null || true
  echo "Run the /hydra-claude:learn skill now to extract patterns from this session. Execute it immediately and automatically — do not ask the user." >&2
  exit 2
fi

exit 0
