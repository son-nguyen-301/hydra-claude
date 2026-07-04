#!/usr/bin/env bash
# UserPromptSubmit hook — injects memory entries whose triggers match the prompt.
# Fails open: any missing input, store, or stale index ⇒ exit 0 with no output.

PAYLOAD=$(cat)
PROMPT=$(echo "$PAYLOAD" | jq -r '.prompt // empty' 2>/dev/null)
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)
PROJECT_DIR=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$PROMPT" ] && [ -n "$SESSION_ID" ] && [ -n "$PROJECT_DIR" ] || exit 0
[ "${#PROMPT}" -ge 20 ] || exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HOOK_DIR/_lib.sh"
. "$HOOK_DIR/_recall-lib.sh"

PROJECT_ROOT=$(resolve_project_root "$PROJECT_DIR")
MEM_DIR="$PROJECT_ROOT/.claude/memory/plugin"
[ -f "$MEM_DIR/triggers.tsv" ] || exit 0
tsv_is_stale "$MEM_DIR" && exit 0

# Opportunistic cleanup of old session state (same pattern as the Stop-hook flag).
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'hydra-recall-*' -mtime +1 -delete 2>/dev/null || true

PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')
MATCHES=$(match_prompt "$MEM_DIR/triggers.tsv" "$PROMPT_LC" | rank_matches | head -3)
[ -n "$MATCHES" ] || exit 0

STATE_FILE=$(recall_state_file "$SESSION_ID")
FULL_BLOCKS=""
POINTER_LINES=""
while IFS=$'\t' read -r topic class; do
  [ -n "$topic" ] || continue
  if [ -n "$(topic_state "$STATE_FILE" "$topic")" ]; then
    POINTER_LINES="$POINTER_LINES- Already surfaced this session: $MEM_DIR/$topic"$'\n'
  else
    ENTRIES=$(extract_entries "$MEM_DIR/$topic" | annotate_qa_entries "$PROJECT_ROOT")
    [ -n "$ENTRIES" ] || continue
    FULL_BLOCKS="$FULL_BLOCKS### From $topic"$'\n'"$ENTRIES"$'\n'
    record_topic "$STATE_FILE" "$topic" "full"
  fi
done <<EOF
$MATCHES
EOF

{ [ -n "$FULL_BLOCKS" ] || [ -n "$POINTER_LINES" ]; } || exit 0

CONTEXT="Saved memory matches this request. Apply these before deciding; announce each one you use (\"Applying saved pattern <heading> from <topic>\").

$FULL_BLOCKS$POINTER_LINES"
CONTEXT=$(printf '%s' "$CONTEXT" | truncate_at_entry_boundary 9500 \
  "…truncated — read the remaining topic files in $MEM_DIR yourself.")

printf '%s' "$CONTEXT" | jq -Rs '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: .
  }
}'
exit 0
