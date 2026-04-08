#!/usr/bin/env bash
# SessionStart hook — injects plugin CLAUDE.md and learned.md into session context

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# Resolve plugin CLAUDE.md path relative to this script
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
WORKSPACE="$HOME/.claude/projects/$PROJECT_SLUG"
LEARNED_FILE="$WORKSPACE/memory/learned.md"

LEARNED_CONTENT=""
if [ -f "$LEARNED_FILE" ]; then
  LEARNED_CONTENT=$(cat "$LEARNED_FILE")
fi

# Exit 0 if both are empty
if [ -z "$PLUGIN_RULES" ] && [ -z "$LEARNED_CONTENT" ]; then
  exit 0
fi

# Build additionalContext based on what we have
if [ -n "$PLUGIN_RULES" ] && [ -n "$LEARNED_CONTENT" ]; then
  # Both sections present
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES

---

Repo-specific learned patterns (MUST follow strictly):

$LEARNED_CONTENT"
elif [ -n "$PLUGIN_RULES" ]; then
  # Only plugin rules
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES"
else
  # Only learned patterns (original behavior)
  ADDITIONAL_CONTEXT="Repo-specific learned patterns (MUST follow strictly):

$LEARNED_CONTENT"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: .
  }
}'
