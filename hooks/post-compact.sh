#!/usr/bin/env bash
# PostCompact hook — re-injects plugin rules and project-local plugin memory after context compaction.

PAYLOAD=$(cat)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

# Source the shared lib for resolve_project_root.
. "$HOOK_DIR/_lib.sh"
. "$HOOK_DIR/_recall-lib.sh"

SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)

PLUGIN_RULES=""
if [ -f "$PLUGIN_RULES_FILE" ]; then
  PLUGIN_RULES=$(cat "$PLUGIN_RULES_FILE")
fi

PROJECT_ROOT=""
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_ROOT=$(resolve_project_root "$PROJECT_DIR")
fi

MEMORY_CONTENT=""
if [ -n "$PROJECT_DIR" ]; then
  PLUGIN_MEMORY_FILE="$PROJECT_ROOT/.claude/memory/plugin/MEMORY.md"
  if [ -f "$PLUGIN_MEMORY_FILE" ]; then
    MEMORY_CONTENT=$(cat "$PLUGIN_MEMORY_FILE")
  fi
fi

RECALLED=""
if [ -n "$SESSION_ID" ] && [ -n "$PROJECT_DIR" ]; then
  STATE_FILE=$(recall_state_file "$SESSION_ID")
  if [ -f "$STATE_FILE" ]; then
    MEM_DIR_ABS="$PROJECT_ROOT/.claude/memory/plugin"
    RECALLED=$(cut -f1 "$STATE_FILE" | sort -u | while IFS= read -r t; do
      printf -- '- %s/%s\n' "$MEM_DIR_ABS" "$t"
    done)
  fi
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

if [ -n "$RECALLED" ]; then
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT

Topics already recalled this session (compaction may have dropped their content — re-read as needed):
$RECALLED"
fi

printf '%s' "$ADDITIONAL_CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "PostCompact",
    additionalContext: .
  }
}'
