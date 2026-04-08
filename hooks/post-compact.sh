#!/usr/bin/env bash
# PostCompact hook — re-injects plugin rules and learned patterns after context compaction

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

LEARNED_CONTENT=""
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  LEARNED_FILE="$HOME/.claude/projects/$PROJECT_SLUG/memory/learned.md"
  if [ -f "$LEARNED_FILE" ]; then
    LEARNED_CONTENT=$(cat "$LEARNED_FILE")
  fi
fi

if [ -z "$PLUGIN_RULES" ] && [ -z "$LEARNED_CONTENT" ]; then
  echo "Context compacted. Token metrics updated."
  exit 0
fi

if [ -n "$PLUGIN_RULES" ] && [ -n "$LEARNED_CONTENT" ]; then
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES

---

Repo-specific learned patterns (MUST follow strictly):

$LEARNED_CONTENT"
elif [ -n "$PLUGIN_RULES" ]; then
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES"
else
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

Repo-specific learned patterns (MUST follow strictly):

$LEARNED_CONTENT"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "PostCompact",
    additionalContext: .
  }
}'
