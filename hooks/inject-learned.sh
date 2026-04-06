#!/usr/bin/env bash
# SessionStart hook — injects learned.md into session context

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

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
