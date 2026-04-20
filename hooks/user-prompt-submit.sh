#!/usr/bin/env bash
# UserPromptSubmit hook — injects a condensed rule reminder on every user turn

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_RULES_FILE="$HOOK_DIR/../CLAUDE.md"

# Only inject if the plugin is active (CLAUDE.md present)
if [ ! -f "$PLUGIN_RULES_FILE" ]; then
  exit 0
fi

REMINDER="RULE REMINDER: (1) Always use plan-task before any file changes. (2) After plan approval, use split-plan to decompose into sub-plans — it handles approval loop, parallel execution, and code review. (3) Never edit directly — execution is orchestrated by split-plan. (4) Pass only the plan file path to subagents, not the plan content. (5) Use the correct agent tier: trivial→sprinter, medium/high→builder, expert→architect."

printf '%s' "$REMINDER" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: .
  }
}'
