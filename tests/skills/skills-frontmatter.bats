#!/usr/bin/env bats
# Tests for skills SKILL.md frontmatter
# One @test per skill for better failure granularity

load '../test_helper'

SKILLS_DIR="$ROOT/skills"

# Helper: check frontmatter for a single skill
_check_skill_file_exists() {
  local skill="$1"
  assert [ -f "$SKILLS_DIR/$skill/SKILL.md" ]
}

_check_skill_frontmatter_start() {
  local skill="$1"
  local first_line
  first_line=$(head -1 "$SKILLS_DIR/$skill/SKILL.md")
  assert_equal "---" "$first_line"
}

_check_skill_has_name() {
  local skill="$1"
  local has_name
  has_name=$(awk '/^---/{f++} f==1 && /^name:/{print; exit}' "$SKILLS_DIR/$skill/SKILL.md")
  assert [ -n "$has_name" ]
}

_check_skill_has_description() {
  local skill="$1"
  local has_desc
  has_desc=$(awk '/^---/{f++} f==1 && /^description:/{print; exit}' "$SKILLS_DIR/$skill/SKILL.md")
  assert [ -n "$has_desc" ]
}

_check_skill_non_empty() {
  local skill="$1"
  local line_count
  line_count=$(wc -l < "$SKILLS_DIR/$skill/SKILL.md")
  assert [ "$line_count" -gt 5 ]
}

_check_skill_description_length() {
  local skill="$1"
  local desc
  desc=$(awk '/^---/{f++} f==1 && /^description:/{gsub(/^description:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print; exit}' "$SKILLS_DIR/$skill/SKILL.md")
  local len=${#desc}
  assert [ "$len" -ge 40 ]
}

# ── learn ──────────────────────────────────────────────────────────────────────

@test "skills/learn: SKILL.md exists" {
  _check_skill_file_exists learn
}

@test "skills/learn: starts with frontmatter (---)" {
  _check_skill_frontmatter_start learn
}

@test "skills/learn: has name: field in frontmatter" {
  _check_skill_has_name learn
}

@test "skills/learn: has description: field in frontmatter" {
  _check_skill_has_description learn
}

@test "skills/learn: file is non-empty (> 5 lines)" {
  _check_skill_non_empty learn
}

@test "skills/learn: description >= 40 chars" {
  _check_skill_description_length learn
}

# ── init ───────────────────────────────────────────────────────────────────────

@test "skills/init: SKILL.md exists" {
  _check_skill_file_exists init
}

@test "skills/init: starts with frontmatter (---)" {
  _check_skill_frontmatter_start init
}

@test "skills/init: has name: field in frontmatter" {
  _check_skill_has_name init
}

@test "skills/init: has description: field in frontmatter" {
  _check_skill_has_description init
}

@test "skills/init: file is non-empty (> 5 lines)" {
  _check_skill_non_empty init
}

@test "skills/init: description >= 40 chars" {
  _check_skill_description_length init
}
