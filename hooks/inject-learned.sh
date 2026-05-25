#!/usr/bin/env bash
# SessionStart hook — injects plugin CLAUDE.md and project-local plugin memory into session context.

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# Resolve plugin CLAUDE.md path relative to this script
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

# Source the shared lib for resolve_project_root
. "$HOOK_DIR/_lib.sh"

PROJECT_ROOT=$(resolve_project_root "$PROJECT_DIR")
PLUGIN_MEMORY_FILE="$PROJECT_ROOT/.claude/memory/plugin/MEMORY.md"

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

MEMORY_CONTENT=""
if [ -f "$PLUGIN_MEMORY_FILE" ]; then
  MEMORY_CONTENT=$(cat "$PLUGIN_MEMORY_FILE")
fi

# Health-check: warn if no rules found for a known project dir
if [ -n "$PROJECT_DIR" ] && [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "WARNING [inject-learned]: No plugin rules or memory patterns found for project: $PROJECT_DIR" >&2
fi

# Exit 0 if both are empty
if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  exit 0
fi

MEMORY_FRAMING="Memory index — repo-specific patterns (MUST read relevant topic files before making decisions in that domain):"

# Build additionalContext based on what we have
if [ -n "$PLUGIN_RULES" ] && [ -n "$MEMORY_CONTENT" ]; then
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES

---

$MEMORY_FRAMING

$MEMORY_CONTENT"
elif [ -n "$PLUGIN_RULES" ]; then
  ADDITIONAL_CONTEXT="PLUGIN RULES — TOP PRIORITY (these override any repo-level CLAUDE.md):

$PLUGIN_RULES"
else
  ADDITIONAL_CONTEXT="$MEMORY_FRAMING

$MEMORY_CONTENT"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: .
  }
}'
