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

# >>> deny-once gate inserted here by Task 11 <<<

FULL_BLOCKS=""
POINTER_LINES=""
NEW_TOPICS=""
# Recording of "full" topics is deferred until after truncation below, so a topic
# whose block gets truncated away isn't marked as surfaced (it would otherwise be
# silently lost for the rest of the session — see CONTEXT truncation below).
# heredoc (not a pipe) so loop-body variable mutations (FULL_BLOCKS, POINTER_LINES,
# NEW_TOPICS) persist after the loop; MATCHES is trusted TSV-derived text.
while IFS=$'\t' read -r topic class; do
  [ -n "$topic" ] || continue
  if [ -n "$(topic_state "$STATE_FILE" "$topic")" ]; then
    POINTER_LINES="$POINTER_LINES- Already surfaced this session: $MEM_DIR/$topic"$'\n'
  else
    ENTRIES=$(extract_entries "$MEM_DIR/$topic" | annotate_qa_entries "$PROJECT_ROOT")
    [ -n "$ENTRIES" ] || continue
    FULL_BLOCKS="$FULL_BLOCKS### From $topic"$'\n'"$ENTRIES"$'\n'
    NEW_TOPICS="$NEW_TOPICS$topic"$'\n'
  fi
done <<EOF
$MATCHES
EOF

{ [ -n "$FULL_BLOCKS" ] || [ -n "$POINTER_LINES" ]; } || exit 0

CONTEXT="Saved memory matches the action you just took ($TOOL_NAME). Apply these to your NEXT steps; announce each one you use (\"Applying saved pattern <heading> from <topic>\").

$FULL_BLOCKS$POINTER_LINES"
CONTEXT=$(printf '%s' "$CONTEXT" | truncate_at_entry_boundary 9500 \
  "…truncated — read the remaining topic files in $MEM_DIR yourself.")

# Only record a topic as "full" once we know its block survived truncation above.
# Topics dropped by truncate_at_entry_boundary are NOT recorded, so they remain
# eligible to inject in full on a later, smaller match. A plain substring
# check for "### From $topic" is not sufficient — see topic_block_survived.
# heredoc (not a pipe) for consistency with the loop above; NEW_TOPICS is
# newline-separated topic names built from trusted TSV-derived text.
while IFS= read -r topic; do
  [ -n "$topic" ] || continue
  [ -n "$(topic_block_survived "$CONTEXT" "$topic")" ] && record_topic "$STATE_FILE" "$topic" "full"
done <<EOF
$NEW_TOPICS
EOF

printf '%s' "$CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: .
  }
}'
exit 0
