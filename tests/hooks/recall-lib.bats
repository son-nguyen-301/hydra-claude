#!/usr/bin/env bats
# Tests for hooks/_recall-lib.sh (part 1: state, staleness, matching, ranking)

load '../test_helper'

LIB="$ROOT/hooks/_recall-lib.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  MEM_DIR="$BATS_TEST_TMPDIR/mem"
  mkdir -p "$MEM_DIR"
  TSV="$MEM_DIR/triggers.tsv"
  printf 'patterns-hooks.md\tkeyword\thook\tcorrection\n'      >  "$TSV"
  printf 'patterns-hooks.md\tpath\thooks/*.sh\tcorrection\n'   >> "$TSV"
  printf 'patterns-hooks.md\tcommand\tgit push\tcorrection\n'  >> "$TSV"
  printf 'patterns-tests.md\tkeyword\tbats\tpattern\n'         >> "$TSV"
  printf 'patterns-tests.md\tkeyword\ttest\tpattern\n'         >> "$TSV"
}

_lib() { bash -c ". \"$LIB\"; $1"; }

@test "state: file path derives from session id and TMPDIR" {
  run _lib 'recall_state_file abc123'
  assert_output "$BATS_TEST_TMPDIR/hydra-recall-abc123"
}

@test "state: record then read back a topic state" {
  run _lib 'sf=$(recall_state_file s1); record_topic "$sf" patterns-hooks.md full; topic_state "$sf" patterns-hooks.md'
  assert_output "full"
}

@test "state: unknown topic yields empty" {
  run _lib 'sf=$(recall_state_file s2); record_topic "$sf" a.md full; topic_state "$sf" b.md'
  assert_output ""
}

@test "staleness: missing TSV is stale" {
  rm -f "$TSV"
  run _lib "tsv_is_stale \"$MEM_DIR\""
  assert_success
}

@test "staleness: fresh TSV is not stale" {
  run _lib "tsv_is_stale \"$MEM_DIR\""
  assert_failure
}

@test "staleness: newer topic file makes TSV stale" {
  touch "$MEM_DIR/newer.md"
  # Backdate the TSV (portable BSD/GNU form: CCYYMMDDhhmm).
  touch -t 200101010000 "$TSV"
  run _lib "tsv_is_stale \"$MEM_DIR\""
  assert_success
}

@test "match_prompt: keyword match is case-insensitive fixed-string" {
  run _lib "match_prompt \"$TSV\" 'add a new HOOK for edits' "
  assert_line "$(printf 'patterns-hooks.md\tcorrection\t1')"
}

@test "match_prompt: counts multiple keyword hits per topic" {
  run _lib "match_prompt \"$TSV\" 'run the bats test suite'"
  assert_line "$(printf 'patterns-tests.md\tpattern\t2')"
}

@test "match_prompt: no match emits nothing" {
  run _lib "match_prompt \"$TSV\" 'completely unrelated words'"
  assert_output ""
}

@test "match_tool: path glob matches project-relative path" {
  run _lib "match_tool \"$TSV\" path /proj/hooks/foo.sh /proj"
  assert_line "$(printf 'patterns-hooks.md\tcorrection\t1')"
}

@test "match_tool: path glob does not match outside pattern" {
  run _lib "match_tool \"$TSV\" path /proj/src/foo.ts /proj"
  assert_output ""
}

@test "match_tool: command ERE matches Bash command" {
  run _lib "match_tool \"$TSV\" command 'git push --force origin main' /proj"
  assert_line "$(printf 'patterns-hooks.md\tcorrection\t1')"
}

@test "rank_matches: correction outranks higher-count pattern" {
  run _lib "printf 'patterns-tests.md\tpattern\t5\npatterns-hooks.md\tcorrection\t1\n' | rank_matches"
  assert_line --index 0 "$(printf 'patterns-hooks.md\tcorrection')"
  assert_line --index 1 "$(printf 'patterns-tests.md\tpattern')"
}

@test "rank_matches: within a class, higher count first" {
  run _lib "printf 'a.md\tpattern\t1\nb.md\tpattern\t4\n' | rank_matches"
  assert_line --index 0 "$(printf 'b.md\tpattern')"
}

@test "match_prompt: matches last TSV row even without trailing newline" {
  printf 'no-newline.md\tkeyword\tzebra\tpattern' >> "$TSV"
  run _lib "match_prompt \"$TSV\" 'a zebra walked by'"
  assert_line "$(printf 'no-newline.md\tpattern\t1')"
}

@test "match_prompt: preserves topic filenames containing spaces" {
  printf 'weird topic name.md\tkeyword\tqux\tpattern\n' >> "$TSV"
  run _lib "match_prompt \"$TSV\" 'the qux keyword appears'"
  assert_line "$(printf 'weird topic name.md\tpattern\t1')"
}

@test "match_tool: matches last TSV row even without trailing newline" {
  printf 'no-newline.md\tcommand\tzebra\tpattern' >> "$TSV"
  run _lib "match_tool \"$TSV\" command 'run zebra now' /proj"
  assert_line "$(printf 'no-newline.md\tpattern\t1')"
}

@test "match_tool: malformed ERE anywhere yields all-or-nothing, no partial leak" {
  printf 'good1.md\tcommand\tgit push\tpattern\nbad.md\tcommand\t(((\tpattern\ngood2.md\tcommand\tgit pull\tpattern\n' > "$TSV"
  run _lib "match_tool \"$TSV\" command 'git push && git pull' /proj 2>/dev/null"
  assert_success
  assert_output ""
}

@test "match_tool: well-formed rows all match when no malformed ERE present" {
  printf 'good1.md\tcommand\tgit push\tpattern\ngood2.md\tcommand\tgit pull\tpattern\n' > "$TSV"
  run _lib "match_tool \"$TSV\" command 'git push && git pull' /proj"
  assert_line "$(printf 'good1.md\tpattern\t1')"
  assert_line "$(printf 'good2.md\tpattern\t1')"
}

# ── part 2: extraction, freshness, truncation ────────────────────────────────

_write_qa_topic() {
  cat > "$MEM_DIR/qa.md" <<EOF
---
scope: "Q&A."
---

## What test framework do we use?
type: qa
answer: bats
captured: $1
freshness: 365d

**Why:** vendored bats-core.

---

## Plain pattern entry

Body line.

**Why:** reasons.

---
EOF
}

@test "extract_entries: skips frontmatter, keeps all entries" {
  _write_qa_topic 2020-01-01
  run _lib "extract_entries \"$MEM_DIR/qa.md\""
  assert_line --partial "## What test framework do we use?"
  assert_line --partial "## Plain pattern entry"
  refute_line --partial 'scope:'
}

@test "extract_entries_by_class: keeps only matching classes" {
  cat > "$MEM_DIR/c.md" <<'EOF'
---
scope: "x"
---

## Keep me
class: correction

A.

---

## Drop me

B.

---
EOF
  run _lib "extract_entries_by_class \"$MEM_DIR/c.md\" 'correction|directive'"
  assert_line --partial "## Keep me"
  refute_line --partial "## Drop me"
}

@test "date_to_epoch: parses ISO date on this platform" {
  run _lib 'date_to_epoch 2026-01-02'
  assert_success
  [ "$output" -gt 1767000000 ]
}

@test "qa_freshness: recent capture within window is fresh" {
  run _lib "qa_freshness $(date +%Y-%m-%d) 365d '' /nonexistent"
  assert_output "fresh"
}

@test "qa_freshness: expired window is stale" {
  run _lib "qa_freshness 2020-01-01 90d '' /nonexistent"
  assert_output "stale"
}

@test "qa_freshness: anchor changed after capture is stale" {
  local repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo" && cd "$repo"
  git init -q . && git config user.email t@t && git config user.name t
  echo x > anchored.txt && git add . && git commit -qm one
  run _lib "qa_freshness 2020-01-01 36500d anchored.txt \"$repo\""
  assert_output "stale"
}

@test "annotate_qa_entries: qa heading gets a freshness tag, plain entry untouched" {
  _write_qa_topic "$(date +%Y-%m-%d)"
  run _lib "extract_entries \"$MEM_DIR/qa.md\" | annotate_qa_entries /nonexistent"
  assert_line --partial "## What test framework do we use? [fresh]"
  assert_line "## Plain pattern entry"
}

@test "annotate_qa_entries: expired qa entry tagged needs-reconfirm" {
  _write_qa_topic 2020-01-01
  run _lib "extract_entries \"$MEM_DIR/qa.md\" | annotate_qa_entries /nonexistent"
  assert_line --partial "[needs-reconfirm"
}

@test "annotate_qa_entries: processes last line even without trailing newline" {
  run _lib "printf '## Q\ntype: qa\ncaptured: 2020-01-01\nfreshness: 365d' | annotate_qa_entries /nonexistent"
  assert_line --partial "freshness: 365d"
  assert_line --partial "[needs-reconfirm"
}

@test "truncate: under budget passes through unchanged" {
  run _lib "printf '## A\nbody\n' | truncate_at_entry_boundary 9500 'PTR'"
  refute_line "PTR"
  assert_line "## A"
}

@test "truncate: drops whole entries over budget and appends pointer" {
  run _lib "{ printf '## A\n'; head -c 300 /dev/zero | tr '\0' 'a'; printf '\n## B\nsmall\n'; } | truncate_at_entry_boundary 250 'PTR'"
  assert_line "PTR"
  refute_line "## B"
}
