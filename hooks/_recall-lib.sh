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
