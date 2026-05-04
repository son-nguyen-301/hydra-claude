#!/usr/bin/env bash
# PostCompact hook — re-injects plugin rules and (conditionally) plugin memory after context compaction

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

# Detect whether Claude Code's native auto-memory is disabled.
# Returns 0 (true) if disabled, 1 (false) if enabled or unknown.
_is_native_automemory_disabled() {
  # Env var override — explicit disable
  if [ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-}" = "1" ]; then
    return 0
  fi

  # Check global user settings
  local global_settings="$HOME/.claude/settings.json"
  if [ -f "$global_settings" ]; then
    local val
    val=$(jq -r 'if has("autoMemoryEnabled") then .autoMemoryEnabled | tostring else "null" end' "$global_settings" 2>/dev/null)
    if [ "$val" = "false" ]; then
      return 0
    fi
  fi

  # Check project-local settings
  local project_settings="$PROJECT_DIR/.claude/settings.json"
  if [ -f "$project_settings" ]; then
    local val
    val=$(jq -r 'if has("autoMemoryEnabled") then .autoMemoryEnabled | tostring else "null" end' "$project_settings" 2>/dev/null)
    if [ "$val" = "false" ]; then
      return 0
    fi
  fi

  # Default: native auto-memory is assumed enabled
  return 1
}

MEMORY_CONTENT=""
MEMORY_SOURCE=""

if _is_native_automemory_disabled; then
  # Native auto-memory is off — inject plugin memory via fallback chain
  PLUGIN_MEMORY_FILE="$WORKSPACE/memory/plugin/MEMORY.md"
  OLD_MEMORY_FILE="$WORKSPACE/memory/MEMORY.md"
  LEARNED_FILE="$WORKSPACE/memory/learned.md"

  if [ -f "$PLUGIN_MEMORY_FILE" ]; then
    MEMORY_CONTENT=$(cat "$PLUGIN_MEMORY_FILE")
    MEMORY_SOURCE="plugin"
  elif [ -f "$OLD_MEMORY_FILE" ]; then
    MEMORY_CONTENT=$(cat "$OLD_MEMORY_FILE")
    MEMORY_SOURCE="index"
  elif [ -f "$LEARNED_FILE" ]; then
    MEMORY_CONTENT=$(cat "$LEARNED_FILE")
    MEMORY_SOURCE="fallback"
  fi
fi

if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "Context compacted. Token metrics updated."
  exit 0
fi

# Choose framing text based on memory source
if [ "$MEMORY_SOURCE" = "plugin" ] || [ "$MEMORY_SOURCE" = "index" ]; then
  MEMORY_FRAMING="Memory index — repo-specific patterns (MUST read relevant topic files before making decisions in that domain):"
else
  MEMORY_FRAMING="Repo-specific learned patterns (MUST follow strictly):"
fi

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
