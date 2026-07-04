#!/usr/bin/env bash
# Shared helpers for the recall hooks. Source this file; do not execute.
# bash 3.2 compatible (no ${var,,}, no name refs).

# ── per-session dedup state ────────────────────────────────────────────────────

recall_state_file() {
  printf '%s/hydra-recall-%s' "${TMPDIR:-/tmp}" "$1"
}

# Echoes the recorded state (full|pointer|denied) for a topic, or nothing.
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
# Emits: topic<TAB>class<TAB>count
match_prompt() {
  local tsv="$1" prompt_lc="$2"
  [ -f "$tsv" ] || return 0
  local file kind pat class
  while IFS=$'\t' read -r file kind pat class || [ -n "$file" ]; do
    [ -n "$file" ] || continue
    case "$kind" in
      keyword)
        printf '%s' "$prompt_lc" | grep -qiF -- "$pat" && printf '%s\t%s\n' "$file" "$class"
        ;;
      command)
        printf '%s' "$prompt_lc" | grep -qiE -- "$pat" && printf '%s\t%s\n' "$file" "$class"
        ;;
    esac
  done < "$tsv" | sort | uniq -c | awk '{
    count = $1
    line = $0
    sub(/^[[:space:]]*[0-9]+[[:space:]]/, "", line)
    n = split(line, parts, "\t")
    if (n >= 2) printf "%s\t%s\t%s\n", parts[1], parts[2], count
  }'
}

# Match one tool value against rows of one kind.
# kind=path: bash-glob against the project-relative (and raw) path.
# kind=command: ERE against the raw value.
# Emits: topic<TAB>class<TAB>1
match_tool() {
  local tsv="$1" match_kind="$2" value="$3" project_root="$4"
  [ -f "$tsv" ] || return 0
  local rel="$value"
  case "$value" in
    "$project_root"/*) rel="${value#"$project_root"/}" ;;
  esac
  local file kind pat class
  while IFS=$'\t' read -r file kind pat class || [ -n "$file" ]; do
    [ "$kind" = "$match_kind" ] || continue
    if [ "$kind" = "path" ]; then
      case "$rel" in
        $pat) printf '%s\t%s\n' "$file" "$class" ;;
      esac
    else
      printf '%s' "$value" | grep -qE -- "$pat" && printf '%s\t%s\n' "$file" "$class"
    fi
  done < "$tsv" | sort -u | awk -F '\t' '{ print $1 "\t" $2 "\t1" }'
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
