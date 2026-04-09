#!/usr/bin/env bash
# Stop hook — detects direct file edits that bypassed plan-task/subagent workflow

PAYLOAD=$(cat)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Find the last assistant message's tool uses
LAST_TOOL_NAMES=$(jq -rn '
  [inputs | select(.message.role == "assistant")] | last
  | (.message.content // [])
  | map(select(.type == "tool_use") | .name)
  | .[]
' "$TRANSCRIPT" 2>/dev/null)

if [ -z "$LAST_TOOL_NAMES" ]; then
  exit 0
fi

# Check for direct Edit or Write calls
if echo "$LAST_TOOL_NAMES" | grep -qE '^(Edit|Write)$'; then
  echo "RULE VIOLATION: Direct file edit detected. You must NEVER use Edit or Write directly. Always: (1) use plan-task to create a plan, (2) delegate to sprinter/builder/architect with the plan file path. Please correct this." >&2
  exit 2
fi

exit 0
