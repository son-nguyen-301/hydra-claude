#!/usr/bin/env bash
# Regenerates <memory-dir>/triggers.tsv from topic-file `triggers:` frontmatter.
# Usage: build-triggers-index.sh <memory-dir>
# Always exits 0. Format: topic-filename<TAB>kind<TAB>pattern<TAB>max-class
set -u

MEM_DIR="${1:-}"
[ -n "$MEM_DIR" ] && [ -d "$MEM_DIR" ] || exit 0

TSV="$MEM_DIR/triggers.tsv"
TMP="$TSV.tmp.$$"
: > "$TMP"

for f in "$MEM_DIR"/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "MEMORY.md" ] && continue

  # Highest entry class in the file (correction > directive > pattern; the gate
  # only distinguishes correction/directive, so preference folds into the default).
  max_class="pattern"
  if grep -qE '^class:[[:space:]]*correction[[:space:]]*$' "$f"; then
    max_class="correction"
  elif grep -qE '^class:[[:space:]]*directive[[:space:]]*$' "$f"; then
    max_class="directive"
  fi

  awk -v file="$base" -v class="$max_class" '
    NR == 1 && !/^---[[:space:]]*$/ { exit }        # no frontmatter
    NR == 1                          { next }
    /^---[[:space:]]*$/              { exit }        # end of frontmatter
    /^triggers:/                     { in_triggers = 1; next }
    in_triggers && /^[a-zA-Z_]/      { in_triggers = 0 }   # left the block
    in_triggers && /^  paths:/       { kind = "path"; next }
    in_triggers && /^  commands:/    { kind = "command"; next }
    in_triggers && /^  keywords:/    { kind = "keyword"; next }
    in_triggers && kind != "" && /^    - / {
      pat = $0
      sub(/^    - /, "", pat)
      gsub(/^"|"$/, "", pat)
      if (pat != "") printf "%s\t%s\t%s\t%s\n", file, kind, pat, class
    }
  ' "$f" >> "$TMP"
done

# Validate command-kind rows' EREs before they ever reach the TSV. A malformed
# dynamic ERE surviving into triggers.tsv aborts the matcher awk mid-file at
# match time (see hooks/_recall-lib.sh); catching it here, at build time, means
# a bad pattern only costs its own row instead of silently suppressing all
# recall matching until the index is regenerated. Keywords are fixed strings
# and path globs are shell `case` patterns — neither can fail to compile — so
# only `command` rows need this check.
VALIDATED="$TSV.validated.$$"
while IFS=$'\t' read -r vfile vkind vpat vclass || [ -n "$vfile" ]; do
  [ -n "$vfile" ] || continue
  if [ "$vkind" = "command" ]; then
    # -v mangles backslashes in the pattern; ARGV passes it through untouched.
    # awk exits non-zero when a dynamic regex fails to compile/use.
    if ! awk 'BEGIN { if ("" ~ ARGV[1]) exit 0; exit 0 }' "$vpat" 2>/dev/null; then
      echo "[build-triggers-index] dropping malformed command pattern in $vfile: $vpat" >&2
      continue
    fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$vfile" "$vkind" "$vpat" "$vclass"
done < "$TMP" > "$VALIDATED"
rm -f "$TMP"

mv "$VALIDATED" "$TSV"
exit 0
