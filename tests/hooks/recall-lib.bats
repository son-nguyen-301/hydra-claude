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
