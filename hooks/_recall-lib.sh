#!/usr/bin/env bash
# Shared helpers for the recall hooks. Source this file; do not execute.
# bash 3.2 compatible (no ${var,,}, no name refs).

# ── per-session dedup state ────────────────────────────────────────────────────

recall_state_file() {
  printf '%s/hydra-recall-%s' "${TMPDIR:-/tmp}" "$1"
}

# Echoes the recorded state (full|denied) for a topic, or nothing.
topic_state() {
  local state_file="$1" topic="$2"
  [ -f "$state_file" ] || return 0
  awk -F '\t' -v t="$topic" '$1 == t { print $2; exit }' "$state_file"
}

record_topic() {
  local state_file="$1" topic="$2" state="$3"
  printf '%s\t%s\n' "$topic" "$state" >> "$state_file"
}

# ── index staleness ───────────────────────────────────────────────────────────

# True (exit 0) when the TSV is missing or any topic file is newer than it.
tsv_is_stale() {
  local mem_dir="$1" tsv="$1/triggers.tsv"
  [ -f "$tsv" ] || return 0
  [ -n "$(find "$mem_dir" -maxdepth 1 -name '*.md' -newer "$tsv" -print 2>/dev/null | head -1)" ]
}

# ── matching ──────────────────────────────────────────────────────────────────

# Match keyword (fixed-string) and command (ERE) rows against a lowercased prompt.
# Single awk pass — O(1) forks regardless of TSV row count (was one grep fork per
# row). The prompt is passed via ENVIRON (not -v, which mangles backslashes) so its
# content survives byte-exactly. `path` rows are ignored, as before.
# Emits: topic<TAB>class<TAB>count
# Fails open: a malformed dynamic ERE on any `command` row aborts the awk process
# (BWK awk has no per-row recovery); output is buffered until END, so an abort
# yields no output at all rather than partial/corrupt lines. stderr is discarded.
match_prompt() {
  local tsv="$1" prompt_lc="$2"
  [ -f "$tsv" ] || return 0
  HYDRA_MATCH_TEXT="$prompt_lc" awk -F '\t' '
    BEGIN { lprompt = tolower(ENVIRON["HYDRA_MATCH_TEXT"]) }
    $1 == "" { next }
    $2 == "keyword" {
      if (index(lprompt, tolower($3)) > 0) { count[$1]++; cls[$1] = $4 }
      next
    }
    $2 == "command" {
      # Case-insensitive ERE: lowercasing both sides is equivalent to grep -iE
      # for the caseless patterns capture-side authors write.
      if (lprompt ~ tolower($3)) { count[$1]++; cls[$1] = $4 }
    }
    END {
      for (f in count) printf "%s\t%s\t%d\n", f, cls[f], count[f]
    }
  ' "$tsv" 2>/dev/null
  return 0
}

# Match one tool value against rows of one kind.
# kind=path: bash-glob (shell `case`, a builtin — zero forks) against the
#   project-relative (and raw) path; deduped in the same single trailing awk pass.
# kind=command: single awk pass, case-SENSITIVE dynamic ERE against the raw value,
#   passed via ENVIRON. Fails open the same way as match_prompt (see comment there).
# Emits: topic<TAB>class<TAB>1
match_tool() {
  local tsv="$1" match_kind="$2" value="$3" project_root="$4"
  [ -f "$tsv" ] || return 0

  if [ "$match_kind" = "command" ]; then
    HYDRA_MATCH_TEXT="$value" awk -F '\t' '
      BEGIN { text = ENVIRON["HYDRA_MATCH_TEXT"] }
      $1 == "" { next }
      $2 == "command" {
        if (text ~ $3) {
          if (!seen[$1]++) printf "%s\t%s\t1\n", $1, $4
        }
      }
    ' "$tsv" 2>/dev/null
    return 0
  fi

  local rel="$value"
  case "$value" in
    "$project_root"/*) rel="${value#"$project_root"/}" ;;
  esac
  local file kind pat class
  { while IFS=$'\t' read -r file kind pat class || [ -n "$file" ]; do
      [ "$kind" = "path" ] || continue
      case "$rel" in
        $pat) printf '%s\t%s\n' "$file" "$class" ;;
      esac
    done < "$tsv"
  } | awk -F '\t' '!seen[$1]++ { printf "%s\t%s\t1\n", $1, $2 }'
  return 0
}

# Order matched topics: class priority, then count desc. stdin/stdout filter.
# In:  topic<TAB>class<TAB>count   Out: topic<TAB>class
rank_matches() {
  awk -F '\t' '{
    p = 3
    if ($2 == "correction") p = 0
    else if ($2 == "directive") p = 1
    else if ($2 == "pattern") p = 2
    printf "%d\t%d\t%s\t%s\n", p, -$3, $1, $2
  }' | sort -t "$(printf '\t')" -k1,1n -k2,2n | cut -f3,4
}

# ── entry extraction ──────────────────────────────────────────────────────────

# Print all `## ` entries from a topic file (frontmatter skipped).
extract_entries() {
  local topic_file="$1"
  [ -f "$topic_file" ] || return 0
  awk '
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/   { in_fm = 0; next }
    in_fm                          { next }
    /^## /                         { in_body = 1 }
    in_body                        { print }
  ' "$topic_file"
}

# Print only entries whose class: line matches the ERE (e.g. "correction|directive").
extract_entries_by_class() {
  local topic_file="$1" class_re="$2"
  extract_entries "$topic_file" | awk -v re="$class_re" '
    /^## / { if (keep) printf "%s", buf; buf = ""; keep = 0 }
    { buf = buf $0 "\n" }
    $0 ~ ("^class:[[:space:]]*(" re ")[[:space:]]*$") { keep = 1 }
    END { if (keep) printf "%s", buf }
  '
}

# ── Q&A freshness ─────────────────────────────────────────────────────────────

# Epoch seconds for YYYY-MM-DD. Tries BSD date (macOS) then GNU date. Empty on failure.
date_to_epoch() {
  local d="$1"
  date -j -f '%Y-%m-%d' "$d" '+%s' 2>/dev/null && return 0
  date -d "$d" '+%s' 2>/dev/null
}

# Echo "fresh" or "stale". Stale when: unparseable fields, decay window passed,
# or any comma-separated anchor path changed (git) after the captured date.
qa_freshness() {
  local captured="$1" freshness="$2" anchor_csv="$3" project_root="$4"
  local now cap_epoch days
  now=$(date '+%s')
  cap_epoch=$(date_to_epoch "$captured")
  [ -n "$cap_epoch" ] || { echo stale; return 0; }
  days="${freshness%d}"
  case "$days" in ''|*[!0-9]*) echo stale; return 0 ;; esac
  if [ $(( cap_epoch + days * 86400 )) -lt "$now" ]; then
    echo stale; return 0
  fi
  if [ -n "$anchor_csv" ] && command -v git >/dev/null 2>&1; then
    local old_ifs="$IFS" anchor last_iso last_epoch
    IFS=','
    for anchor in $anchor_csv; do
      IFS="$old_ifs"
      anchor="${anchor# }"
      last_iso=$(git -C "$project_root" log -1 --format=%cI -- "$anchor" 2>/dev/null)
      if [ -n "$last_iso" ]; then
        last_epoch=$(date_to_epoch "${last_iso%%T*}")
        if [ -n "$last_epoch" ] && [ "$last_epoch" -gt "$cap_epoch" ]; then
          echo stale; return 0
        fi
      fi
      IFS=','
    done
    IFS="$old_ifs"
  fi
  echo fresh
}

# stdin→stdout: tag each `type: qa` entry heading with [fresh] / [needs-reconfirm…].
# Globals prefixed _aq_ to stay bash-3.2 safe without nameref tricks.
_aq_flush() {
  [ -n "$_aq_buf" ] || return 0
  if [ "$_aq_is_qa" = "1" ] && [ -n "$_aq_captured" ] && [ -n "$_aq_freshness" ]; then
    local status
    status=$(qa_freshness "$_aq_captured" "$_aq_freshness" "$_aq_anchor" "$_aq_root")
    if [ "$status" = "fresh" ]; then
      printf '%s' "$_aq_buf" | sed '1s/$/ [fresh]/'
    else
      printf '%s' "$_aq_buf" | sed '1s/$/ [needs-reconfirm — ask the user before relying on this]/'
    fi
  else
    printf '%s' "$_aq_buf"
  fi
}

annotate_qa_entries() {
  _aq_root="$1"
  _aq_buf=""; _aq_is_qa=0; _aq_captured=""; _aq_freshness=""; _aq_anchor=""
  local line v
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '## '*)
        _aq_flush
        _aq_buf="$line"$'\n'; _aq_is_qa=0; _aq_captured=""; _aq_freshness=""; _aq_anchor=""
        continue
        ;;
      'type: qa'*)    _aq_is_qa=1 ;;
      'captured: '*)  v="${line#captured: }";  _aq_captured=$(printf '%s' "${v%%#*}" | awk '{print $1}') ;;
      'freshness: '*) v="${line#freshness: }"; _aq_freshness=$(printf '%s' "${v%%#*}" | awk '{print $1}') ;;
      'anchor: '*)    v="${line#anchor: }";    _aq_anchor="${v%%#*}" ;;
    esac
    _aq_buf="$_aq_buf$line"$'\n'
  done
  _aq_flush
}

# True (prints "yes") when a "### From $topic" marker line in $context is
# immediately followed — before the next "### From " marker or EOF — by an
# entry heading line ("## "). Truncation flushes at "## " boundaries, so a
# topic's marker can survive alongside the *previous* topic's surviving chunk
# even though this topic's own entry got truncated away; a plain substring
# check for the marker alone is therefore not enough to know the topic's
# content actually reached context.
topic_block_survived() {
  local context="$1" topic="$2"
  printf '%s' "$context" | awk -v marker="### From $topic" '
    $0 == marker    { found = 1; next }
    found && /^### From / { exit }
    found && /^## /       { print "yes"; exit }
  '
}

# ── output budget ─────────────────────────────────────────────────────────────

# stdin→stdout: emit whole `## ` chunks while they fit in max_chars; once a chunk
# is dropped, drop everything after it too and append the pointer line.
truncate_at_entry_boundary() {
  local max="$1" pointer="$2"
  awk -v max="$max" -v ptr="$pointer" '
    function flush() {
      if (buf == "") return
      if (!truncated && total + length(buf) <= max) {
        printf "%s", buf; total += length(buf)
      } else {
        truncated = 1
      }
      buf = ""
    }
    /^## / { flush() }
    { buf = buf $0 "\n" }
    END {
      flush()
      if (truncated && ptr != "") print ptr
    }
  '
}

# ── recall assembly ───────────────────────────────────────────────────────────

# assemble_and_emit_recall <matches> <mem_dir> <state_file> <project_root> <framing_text> <event_name>
# Assembles full/pointer blocks from ranked matches (topic<TAB>class lines), truncates
# at entry boundaries (9500), records surviving topics, and emits the additionalContext
# JSON for <event_name>. Emits nothing and returns 0 when there is nothing to inject.
assemble_and_emit_recall() {
  local matches="$1" mem_dir="$2" state_file="$3" project_root="$4" framing="$5" event_name="$6"
  local FULL_BLOCKS="" POINTER_LINES="" NEW_TOPICS=""
  # Recording of "full" topics is deferred until after truncation below, so a topic
  # whose block gets truncated away isn't marked as surfaced (it would otherwise be
  # silently lost for the rest of the session — see CONTEXT truncation below).
  # heredoc (not a pipe) so loop-body variable mutations (FULL_BLOCKS, POINTER_LINES,
  # NEW_TOPICS) persist after the loop; matches is trusted TSV-derived text.
  local topic class
  while IFS=$'\t' read -r topic class; do
    [ -n "$topic" ] || continue
    if [ -n "$(topic_state "$state_file" "$topic")" ]; then
      POINTER_LINES="$POINTER_LINES- Already surfaced this session: $mem_dir/$topic"$'\n'
    else
      local entries
      entries=$(extract_entries "$mem_dir/$topic" | annotate_qa_entries "$project_root")
      [ -n "$entries" ] || continue
      FULL_BLOCKS="$FULL_BLOCKS### From $topic"$'\n'"$entries"$'\n'
      NEW_TOPICS="$NEW_TOPICS$topic"$'\n'
    fi
  done <<EOF
$matches
EOF

  { [ -n "$FULL_BLOCKS" ] || [ -n "$POINTER_LINES" ]; } || return 0

  local context
  context="$framing

$FULL_BLOCKS$POINTER_LINES"
  context=$(printf '%s' "$context" | truncate_at_entry_boundary 9500 \
    "…truncated — read the remaining topic files in $mem_dir yourself.")

  # Only record a topic as "full" once we know its block survived truncation above.
  # Topics dropped by truncate_at_entry_boundary are NOT recorded, so they remain
  # eligible to inject in full on a later, smaller match. A plain substring
  # check for "### From $topic" is not sufficient — see topic_block_survived.
  # heredoc (not a pipe) for consistency with the loop above; NEW_TOPICS is
  # newline-separated topic names built from trusted TSV-derived text.
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ -n "$(topic_block_survived "$context" "$t")" ] && record_topic "$state_file" "$t" "full" 2>/dev/null
  done <<EOF
$NEW_TOPICS
EOF

  printf '%s' "$context" | jq -Rs --arg event "$event_name" '{
    hookSpecificOutput: {
      hookEventName: $event,
      additionalContext: .
    }
  }'
  return 0
}
