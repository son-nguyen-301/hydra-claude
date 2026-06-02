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
