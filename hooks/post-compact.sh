#!/usr/bin/env bash
# PostCompact hook — re-injects plugin rules and plugin memory after context compaction

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
WORKSPACE="$HOME/.claude/projects/$PROJECT_SLUG"

MEMORY_CONTENT=""
MEMORY_SOURCE=""

PLUGIN_MEMORY_FILE="$WORKSPACE/memory/plugin/MEMORY.md"
if [ -f "$PLUGIN_MEMORY_FILE" ]; then
  MEMORY_CONTENT=$(cat "$PLUGIN_MEMORY_FILE")
  MEMORY_SOURCE="plugin"
fi

if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "Context compacted. Token metrics updated."
  exit 0
fi

MEMORY_FRAMING="Memory index — repo-specific patterns (MUST read relevant topic files before making decisions in that domain):"

# Build additionalContext based on what we have
if [ -n "$PLUGIN_RULES" ] && [ -n "$MEMORY_CONTENT" ]; then
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES

---

$MEMORY_FRAMING

$MEMORY_CONTENT"
elif [ -n "$PLUGIN_RULES" ]; then
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES"
else
  ADDITIONAL_CONTEXT="Context compacted — rules re-injected.

$MEMORY_FRAMING

$MEMORY_CONTENT"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "PostCompact",
    additionalContext: .
  }
}'
