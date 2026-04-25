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

# ── plan-task ──────────────────────────────────────────────────────────────────

@test "skills/plan-task: SKILL.md exists" {
  _check_skill_file_exists plan-task
}

@test "skills/plan-task: starts with frontmatter (---)" {
  _check_skill_frontmatter_start plan-task
}

@test "skills/plan-task: has name: field in frontmatter" {
  _check_skill_has_name plan-task
}

@test "skills/plan-task: has description: field in frontmatter" {
  _check_skill_has_description plan-task
}

@test "skills/plan-task: file is non-empty (> 5 lines)" {
  _check_skill_non_empty plan-task
}

@test "skills/plan-task: description >= 40 chars" {
  _check_skill_description_length plan-task
}

# ── explore-codebase ───────────────────────────────────────────────────────────

@test "skills/explore-codebase: SKILL.md exists" {
  _check_skill_file_exists explore-codebase
}

@test "skills/explore-codebase: starts with frontmatter (---)" {
  _check_skill_frontmatter_start explore-codebase
}

@test "skills/explore-codebase: has name: field in frontmatter" {
  _check_skill_has_name explore-codebase
}

@test "skills/explore-codebase: has description: field in frontmatter" {
  _check_skill_has_description explore-codebase
}

@test "skills/explore-codebase: file is non-empty (> 5 lines)" {
  _check_skill_non_empty explore-codebase
}

@test "skills/explore-codebase: description >= 40 chars" {
  _check_skill_description_length explore-codebase
}

# ── read-confluence ────────────────────────────────────────────────────────────

@test "skills/read-confluence: SKILL.md exists" {
  _check_skill_file_exists read-confluence
}

@test "skills/read-confluence: starts with frontmatter (---)" {
  _check_skill_frontmatter_start read-confluence
}

@test "skills/read-confluence: has name: field in frontmatter" {
  _check_skill_has_name read-confluence
}

@test "skills/read-confluence: has description: field in frontmatter" {
  _check_skill_has_description read-confluence
}

@test "skills/read-confluence: file is non-empty (> 5 lines)" {
  _check_skill_non_empty read-confluence
}

@test "skills/read-confluence: description >= 40 chars" {
  _check_skill_description_length read-confluence
}

# ── read-jira ──────────────────────────────────────────────────────────────────

@test "skills/read-jira: SKILL.md exists" {
  _check_skill_file_exists read-jira
}

@test "skills/read-jira: starts with frontmatter (---)" {
  _check_skill_frontmatter_start read-jira
}

@test "skills/read-jira: has name: field in frontmatter" {
  _check_skill_has_name read-jira
}

@test "skills/read-jira: has description: field in frontmatter" {
  _check_skill_has_description read-jira
}

@test "skills/read-jira: file is non-empty (> 5 lines)" {
  _check_skill_non_empty read-jira
}

@test "skills/read-jira: description >= 40 chars" {
  _check_skill_description_length read-jira
}

# ── read-plan ──────────────────────────────────────────────────────────────────

@test "skills/read-plan: SKILL.md exists" {
  _check_skill_file_exists read-plan
}

@test "skills/read-plan: starts with frontmatter (---)" {
  _check_skill_frontmatter_start read-plan
}

@test "skills/read-plan: has name: field in frontmatter" {
  _check_skill_has_name read-plan
}

@test "skills/read-plan: has description: field in frontmatter" {
  _check_skill_has_description read-plan
}

@test "skills/read-plan: file is non-empty (> 5 lines)" {
  _check_skill_non_empty read-plan
}

@test "skills/read-plan: description >= 40 chars" {
  _check_skill_description_length read-plan
}

# ── write-confluence ───────────────────────────────────────────────────────────

@test "skills/write-confluence: SKILL.md exists" {
  _check_skill_file_exists write-confluence
}

@test "skills/write-confluence: starts with frontmatter (---)" {
  _check_skill_frontmatter_start write-confluence
}

@test "skills/write-confluence: has name: field in frontmatter" {
  _check_skill_has_name write-confluence
}

@test "skills/write-confluence: has description: field in frontmatter" {
  _check_skill_has_description write-confluence
}

@test "skills/write-confluence: file is non-empty (> 5 lines)" {
  _check_skill_non_empty write-confluence
}

@test "skills/write-confluence: description >= 40 chars" {
  _check_skill_description_length write-confluence
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

# ── debug ──────────────────────────────────────────────────────────────────────

@test "skills/debug: SKILL.md exists" {
  _check_skill_file_exists debug
}

@test "skills/debug: starts with frontmatter (---)" {
  _check_skill_frontmatter_start debug
}

@test "skills/debug: has name: field in frontmatter" {
  _check_skill_has_name debug
}

@test "skills/debug: has description: field in frontmatter" {
  _check_skill_has_description debug
}

@test "skills/debug: file is non-empty (> 5 lines)" {
  _check_skill_non_empty debug
}

@test "skills/debug: description >= 40 chars" {
  _check_skill_description_length debug
}

# ── read-debug-findings ────────────────────────────────────────────────────────

@test "skills/read-debug-findings: SKILL.md exists" {
  _check_skill_file_exists read-debug-findings
}

@test "skills/read-debug-findings: starts with frontmatter (---)" {
  _check_skill_frontmatter_start read-debug-findings
}

@test "skills/read-debug-findings: has name: field in frontmatter" {
  _check_skill_has_name read-debug-findings
}

@test "skills/read-debug-findings: has description: field in frontmatter" {
  _check_skill_has_description read-debug-findings
}

@test "skills/read-debug-findings: file is non-empty (> 5 lines)" {
  _check_skill_non_empty read-debug-findings
}

@test "skills/read-debug-findings: description >= 40 chars" {
  _check_skill_description_length read-debug-findings
}

# ── review-plan ────────────────────────────────────────────────────────────────

@test "skills/review-plan: SKILL.md exists" {
  _check_skill_file_exists review-plan
}

@test "skills/review-plan: starts with frontmatter (---)" {
  _check_skill_frontmatter_start review-plan
}

@test "skills/review-plan: has name: field in frontmatter" {
  _check_skill_has_name review-plan
}

@test "skills/review-plan: has description: field in frontmatter" {
  _check_skill_has_description review-plan
}

@test "skills/review-plan: file is non-empty (> 5 lines)" {
  _check_skill_non_empty review-plan
}

@test "skills/review-plan: description >= 40 chars" {
  _check_skill_description_length review-plan
}

# ── review-code ────────────────────────────────────────────────────────────────

@test "skills/review-code: SKILL.md exists" {
  _check_skill_file_exists review-code
}

@test "skills/review-code: starts with frontmatter (---)" {
  _check_skill_frontmatter_start review-code
}

@test "skills/review-code: has name: field in frontmatter" {
  _check_skill_has_name review-code
}

@test "skills/review-code: has description: field in frontmatter" {
  _check_skill_has_description review-code
}

@test "skills/review-code: file is non-empty (> 5 lines)" {
  _check_skill_non_empty review-code
}

@test "skills/review-code: description >= 40 chars" {
  _check_skill_description_length review-code
}

# ── split-plan ─────────────────────────────────────────────────────────────────

@test "skills/split-plan: SKILL.md exists" {
  _check_skill_file_exists split-plan
}

@test "skills/split-plan: starts with frontmatter (---)" {
  _check_skill_frontmatter_start split-plan
}

@test "skills/split-plan: has name: field in frontmatter" {
  _check_skill_has_name split-plan
}

@test "skills/split-plan: has description: field in frontmatter" {
  _check_skill_has_description split-plan
}

@test "skills/split-plan: file is non-empty (> 5 lines)" {
  _check_skill_non_empty split-plan
}

@test "skills/split-plan: description >= 40 chars" {
  _check_skill_description_length split-plan
}

# ── enhance-prompt ─────────────────────────────────────────────────────────────

@test "skills/enhance-prompt: SKILL.md exists" {
  _check_skill_file_exists enhance-prompt
}

@test "skills/enhance-prompt: starts with frontmatter (---)" {
  _check_skill_frontmatter_start enhance-prompt
}

@test "skills/enhance-prompt: has name: field in frontmatter" {
  _check_skill_has_name enhance-prompt
}

@test "skills/enhance-prompt: has description: field in frontmatter" {
  _check_skill_has_description enhance-prompt
}

@test "skills/enhance-prompt: file is non-empty (> 5 lines)" {
  _check_skill_non_empty enhance-prompt
}

@test "skills/enhance-prompt: description >= 40 chars" {
  _check_skill_description_length enhance-prompt
}
