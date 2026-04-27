#!/usr/bin/env bash
# PostCompact hook — re-injects plugin rules and memory index (or learned.md) after context compaction

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

MEMORY_CONTENT=""
MEMORY_SOURCE=""
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_SLUG=$(echo "$PROJECT_DIR" | tr '/' '-')
  WORKSPACE="$HOME/.claude/projects/$PROJECT_SLUG"
  MEMORY_INDEX_FILE="$WORKSPACE/memory/MEMORY.md"
  LEARNED_FILE="$WORKSPACE/memory/learned.md"
  if [ -f "$MEMORY_INDEX_FILE" ]; then
    MEMORY_CONTENT=$(cat "$MEMORY_INDEX_FILE")
    MEMORY_SOURCE="index"
  elif [ -f "$LEARNED_FILE" ]; then
    MEMORY_CONTENT=$(cat "$LEARNED_FILE")
    MEMORY_SOURCE="fallback"
    echo "NOTICE [post-compact]: MEMORY.md not found, falling back to learned.md. Run /hydra-claude:migrate-memory to upgrade." >&2
  fi
fi

if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "Context compacted. Token metrics updated."
  exit 0
fi

# Choose framing text based on memory source
if [ "$MEMORY_SOURCE" = "index" ]; then
  MEMORY_FRAMING="Memory index — repo-specific patterns (MUST read relevant topic files before making decisions in that domain):"
else
  MEMORY_FRAMING="Repo-specific learned patterns (MUST follow strictly):"
fi

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
