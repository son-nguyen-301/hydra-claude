#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit|Bash) — surfaces memory matching the
# pending tool input. Advisory injection lands next to the tool result and
# steers subsequent actions. Fails open on any missing input.

PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$TOOL_NAME" ] && [ -n "$SESSION_ID" ] && [ -n "$PROJECT_DIR" ] || exit 0

case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    VALUE=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    KIND="path"
    ;;
  Bash)
    VALUE=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)
    KIND="command"
    ;;
  *) exit 0 ;;
esac
[ -n "$VALUE" ] || exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HOOK_DIR/_lib.sh"
. "$HOOK_DIR/_recall-lib.sh"

PROJECT_ROOT=$(resolve_project_root "$PROJECT_DIR")
MEM_DIR="$PROJECT_ROOT/.claude/memory/plugin"
[ -f "$MEM_DIR/triggers.tsv" ] || exit 0
tsv_is_stale "$MEM_DIR" && exit 0

MATCHES=$(match_tool "$MEM_DIR/triggers.tsv" "$KIND" "$VALUE" "$PROJECT_ROOT" | rank_matches | head -3)
[ -n "$MATCHES" ] || exit 0

STATE_FILE=$(recall_state_file "$SESSION_ID")

# Deny-once gate: a correction/directive topic matching this action that has not
# yet been surfaced this session blocks the call ONCE, carrying the entries in
# the reason. State is written BEFORE emitting, so the retry can never re-trigger.
while IFS=$'\t' read -r topic class; do
  [ -n "$topic" ] || continue
  case "$class" in correction|directive) ;; *) continue ;; esac
  [ -z "$(topic_state "$STATE_FILE" "$topic")" ] || continue
  GATE_ENTRIES=$(extract_entries_by_class "$MEM_DIR/$topic" "correction|directive")
  [ -n "$GATE_ENTRIES" ] || continue
  record_topic "$STATE_FILE" "$topic" "denied" 2>/dev/null || continue
  REASON="Automated memory gate — not a user denial and not an error. A saved correction/directive applies to this exact action:

$GATE_ENTRIES
Retry the same call, applying it (or adjust the call if the saved rule forbids it)."
  printf '%s' "$REASON" | jq -Rs '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: .
    }
  }'
  exit 0
done <<EOF
$MATCHES
EOF

assemble_and_emit_recall "$MATCHES" "$MEM_DIR" "$STATE_FILE" "$PROJECT_ROOT" \
  "Saved memory matches the action you just took ($TOOL_NAME). Apply these to your NEXT steps; announce each one you use (\"Applying saved pattern <heading> from <topic>\")." \
  "PreToolUse"
exit 0
