#!/usr/bin/env bats
# Tests for scripts/build-triggers-index.sh

load '../test_helper'

BUILDER="$ROOT/scripts/build-triggers-index.sh"

# Write a topic file with a full triggers block into $1/<name>.
_write_topic() {
  local dir="$1" name="$2"
  cat > "$dir/$name" <<'EOF'
---
scope: "Hook script conventions."
not: "Test conventions."
anchors:
  - "Some anchor"
triggers:
  paths:
    - "hooks/*.sh"
  commands:
    - "git (push|worktree)"
  keywords:
    - "hook"
---

## Some pattern
class: correction

Body text.

**Why:** because.

---
EOF
}

setup() {
  MEM_DIR="$BATS_TEST_TMPDIR/mem"
  mkdir -p "$MEM_DIR"
}

@test "builder: missing dir exits 0" {
  run bash "$BUILDER" "$BATS_TEST_TMPDIR/nope"
  assert_success
}

@test "builder: no args exits 0" {
  run bash "$BUILDER"
  assert_success
}

@test "builder: empty store produces empty TSV" {
  run bash "$BUILDER" "$MEM_DIR"
  assert_success
  [ -f "$MEM_DIR/triggers.tsv" ]
  [ ! -s "$MEM_DIR/triggers.tsv" ]
}

@test "builder: emits one row per pattern with kind and class" {
  _write_topic "$MEM_DIR" "patterns-hooks.md"
  run bash "$BUILDER" "$MEM_DIR"
  assert_success
  run sort "$MEM_DIR/triggers.tsv"
  assert_line "$(printf 'patterns-hooks.md\tpath\thooks/*.sh\tcorrection')"
  assert_line "$(printf 'patterns-hooks.md\tcommand\tgit (push|worktree)\tcorrection')"
  assert_line "$(printf 'patterns-hooks.md\tkeyword\thook\tcorrection')"
}

@test "builder: class defaults to pattern when no class lines present" {
  _write_topic "$MEM_DIR" "patterns-hooks.md"
  sed -i.bak '/^class: correction$/d' "$MEM_DIR/patterns-hooks.md" && rm -f "$MEM_DIR/patterns-hooks.md.bak"
  run bash "$BUILDER" "$MEM_DIR"
  run grep -c $'\tpattern$' "$MEM_DIR/triggers.tsv"
  assert_output "3"
}

@test "builder: directive outranks pattern for max-class" {
  _write_topic "$MEM_DIR" "patterns-hooks.md"
  sed -i.bak 's/^class: correction$/class: directive/' "$MEM_DIR/patterns-hooks.md" && rm -f "$MEM_DIR/patterns-hooks.md.bak"
  run bash "$BUILDER" "$MEM_DIR"
  run grep -c $'\tdirective$' "$MEM_DIR/triggers.tsv"
  assert_output "3"
}

@test "builder: skips MEMORY.md and files without triggers" {
  printf -- '- [X](x.md) — x\n' > "$MEM_DIR/MEMORY.md"
  printf -- '---\nscope: "no triggers here"\n---\n\n## E\nbody\n' > "$MEM_DIR/plain.md"
  run bash "$BUILDER" "$MEM_DIR"
  assert_success
  [ ! -s "$MEM_DIR/triggers.tsv" ]
}

@test "builder: skips archive directory" {
  mkdir -p "$MEM_DIR/archive"
  _write_topic "$MEM_DIR/archive" "old.md"
  run bash "$BUILDER" "$MEM_DIR"
  assert_success
  [ ! -s "$MEM_DIR/triggers.tsv" ]
}

@test "builder: regeneration replaces, not appends" {
  _write_topic "$MEM_DIR" "patterns-hooks.md"
  bash "$BUILDER" "$MEM_DIR"
  bash "$BUILDER" "$MEM_DIR"
  run grep -c 'patterns-hooks.md' "$MEM_DIR/triggers.tsv"
  assert_output "3"
}

@test "builder: drops malformed command ERE rows with a warning" {
  cat > "$MEM_DIR/badre.md" <<'EOF'
---
scope: "x"
triggers:
  commands:
    - "((("
    - "git push"
---

## E

B.

---
EOF
  run bash -c 'bash "$1" "$2" 2>&1' _ "$BUILDER" "$MEM_DIR"
  assert_success
  assert_output --partial "malformed command pattern"
  run grep -c $'badre.md\tcommand' "$MEM_DIR/triggers.tsv"
  assert_output "1"
}
