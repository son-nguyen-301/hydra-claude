#!/usr/bin/env bash
# SessionStart hook — injects plugin CLAUDE.md and memory index (or learned.md) into session context

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
MEMORY_INDEX_FILE="$WORKSPACE/memory/MEMORY.md"
LEARNED_FILE="$WORKSPACE/memory/learned.md"

MEMORY_CONTENT=""
MEMORY_SOURCE=""
if [ -f "$MEMORY_INDEX_FILE" ]; then
  MEMORY_CONTENT=$(cat "$MEMORY_INDEX_FILE")
  MEMORY_SOURCE="index"
elif [ -f "$LEARNED_FILE" ]; then
  MEMORY_CONTENT=$(cat "$LEARNED_FILE")
  MEMORY_SOURCE="fallback"
  echo "NOTICE [inject-learned]: MEMORY.md not found, falling back to learned.md. Run /hydra-claude:migrate-memory to upgrade." >&2
fi

# Health-check: warn if no rules found for a known project dir
if [ -n "$PROJECT_DIR" ] && [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "WARNING [inject-learned]: No plugin rules or memory patterns found for project: $PROJECT_DIR" >&2
fi

# Exit 0 if both are empty
if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  exit 0
fi

# Choose framing text based on memory source
if [ "$MEMORY_SOURCE" = "index" ]; then
  MEMORY_FRAMING="Memory index — repo-specific patterns (MUST read relevant topic files before making decisions in that domain):"
else
  MEMORY_FRAMING="Repo-specific learned patterns (MUST follow strictly):"
fi

# Build additionalContext based on what we have
if [ -n "$PLUGIN_RULES" ] && [ -n "$MEMORY_CONTENT" ]; then
  # Both sections present
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES

---

$MEMORY_FRAMING

$MEMORY_CONTENT"
elif [ -n "$PLUGIN_RULES" ]; then
  # Only plugin rules
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES"
else
  # Only memory content (original behavior path)
  ADDITIONAL_CONTEXT="$MEMORY_FRAMING

$MEMORY_CONTENT"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: .
  }
}'
