#!/usr/bin/env bash
# SessionStart hook — injects plugin CLAUDE.md and (conditionally) plugin memory into session context

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

# Health-check: warn if no rules found for a known project dir
if [ -n "$PROJECT_DIR" ] && [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
  echo "WARNING [inject-learned]: No plugin rules or memory patterns found for project: $PROJECT_DIR" >&2
fi

# Exit 0 if both are empty
if [ -z "$PLUGIN_RULES" ] && [ -z "$MEMORY_CONTENT" ]; then
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
