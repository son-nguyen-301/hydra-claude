#!/usr/bin/env bats
# Tests for the Q&A memory + staleness feature (structural invariants on markdown).

load '../test_helper'

TEMPLATES="$ROOT/skills/_shared/workspace-templates.md"
CORE="$ROOT/skills/_shared/workspace-core.md"

@test "templates: documents the type: qa entry shape" {
  run grep -q "type: qa" "$TEMPLATES"
  assert_success
}

@test "templates: qa template documents the anchor: field" {
  run grep -Eq "anchor:" "$TEMPLATES"
  assert_success
}

@test "templates: qa template documents the status: field" {
  run grep -Eq "status:" "$TEMPLATES"
  assert_success
}

@test "templates: qa template documents the freshness: field" {
  run grep -Eq "freshness:" "$TEMPLATES"
  assert_success
}

@test "templates: documents the archive layout and that it is never read" {
  run grep -q "Archive layout" "$TEMPLATES"
  assert_success
  run grep -qi "never injected" "$TEMPLATES"
  assert_success
}

@test "core: documents the archive/ path" {
  run grep -q "archive/" "$CORE"
  assert_success
}

LEARN="$ROOT/skills/learn/SKILL.md"

@test "learn: recognizes the QA focused-mode block" {
  run grep -q "QA:" "$LEARN"
  assert_success
}

@test "learn: documents the durability gate" {
  run grep -qi "durab" "$LEARN"
  assert_success
}

@test "learn: defines the per-type freshness defaults" {
  run grep -q "365d" "$LEARN"
  assert_success
  run grep -q "90d" "$LEARN"
  assert_success
  run grep -q "180d" "$LEARN"
  assert_success
}

@test "learn: writes captured date and active status for qa entries" {
  run grep -q "status: active" "$LEARN"
  assert_success
}

@test "learn: documents contradiction-supersede for qa entries" {
  run grep -qi "superseded" "$LEARN"
  assert_success
}

@test "learn: moves dead entries to archive" {
  run grep -q "archive/" "$LEARN"
  assert_success
}

@test "learn: proliferation advisory bumped to 20" {
  run grep -q "exceeds 20" "$LEARN"
  assert_success
}

@test "learn: names MEMORY.md size as the true injection guard" {
  run grep -qi "true guard" "$LEARN"
  assert_success
}

CLAUDEMD="$ROOT/CLAUDE.md"

@test "CLAUDE.md: has a check-before-ask retrieval rule" {
  run grep -qi "before asking" "$CLAUDEMD"
  assert_success
}

@test "CLAUDE.md: requires reuse to be announced, never silent" {
  run grep -qi "never silent" "$CLAUDEMD"
  assert_success
}

@test "CLAUDE.md: lazy anchor staleness check uses git log" {
  run grep -q "git log" "$CLAUDEMD"
  assert_success
}

@test "CLAUDE.md: adds the clarifying-answer auto-write trigger with a QA block" {
  run grep -qi "Clarifying answer" "$CLAUDEMD"
  assert_success
  run grep -q "QA:" "$CLAUDEMD"
  assert_success
}

ENHANCE="$ROOT/skills/enhance-prompt/SKILL.md"

@test "enhance-prompt: notes that type: qa entries are usable facts" {
  run grep -q "type: qa" "$ENHANCE"
  assert_success
}
