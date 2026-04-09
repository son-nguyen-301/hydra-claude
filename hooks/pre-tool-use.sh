#!/usr/bin/env bash
# PreToolUse hook — blocks direct Edit/Write calls before they execute

PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  echo "BLOCKED: Direct file edit is not allowed. Follow the workflow:
(1) Use plan-task to create a plan file.
(2) Get user approval.
(3) Delegate to the correct subagent (sprinter/builder/architect) with the plan file path." >&2
  exit 2
fi

exit 0
