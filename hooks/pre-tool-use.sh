#!/usr/bin/env bash
# PreToolUse hook — blocks direct Edit/Write calls before they execute
# Whitelist: allows writes to internal Claude directories

PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  # Allow subagents — they have agent_id in the payload
  AGENT_ID=$(echo "$PAYLOAD" | jq -r '.agent_id // empty' 2>/dev/null)
  if [[ -n "$AGENT_ID" ]]; then
    exit 0
  fi

  # Extract file_path from tool_input
  FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

  # Check if path matches internal Claude workspace directories
  if [[ -n "$FILE_PATH" ]]; then
    # Whitelist patterns for internal Claude directories
    if [[ "$FILE_PATH" =~ ^$HOME/\.claude/projects/.*/plans/ ]] || \
       [[ "$FILE_PATH" =~ ^$HOME/\.claude/projects/.*/memory/ ]] || \
       [[ "$FILE_PATH" =~ ^$HOME/\.claude/projects/.*/tasks/ ]] || \
       [[ "$FILE_PATH" =~ ^$HOME/\.claude/projects/.*/debug-findings/ ]]; then
      exit 0
    fi
  fi

  echo "BLOCKED: Direct file edit is not allowed. Follow the workflow:
(1) Use plan-task to create a plan file.
(2) Get user approval.
(3) Delegate to the correct subagent (sprinter/builder/architect) with the plan file path." >&2
  exit 2
fi

exit 0
