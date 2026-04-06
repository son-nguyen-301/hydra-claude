#!/usr/bin/env bash
# Tests for skills SKILL.md frontmatter

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_DIR="$ROOT/skills"

SKILL_NAMES=(
  plan-task
  explore-codebase
  read-confluence
  read-jira
  read-plan
  write-confluence
  learn
)

_test_skill() {
  local skill="$1"
  local skill_file="$SKILLS_DIR/$skill/SKILL.md"

  # 1. File exists
  assert_file_exists "$skill_file" "skills/$skill: SKILL.md exists"

  if [ ! -f "$skill_file" ]; then
    # Skip remaining checks if file doesn't exist
    fail "skills/$skill: starts with frontmatter" "file not found"
    fail "skills/$skill: has name: field" "file not found"
    fail "skills/$skill: has description: field" "file not found"
    fail "skills/$skill: file is non-empty (> 5 lines)" "file not found"
    return
  fi

  # 2. Starts with ---
  local first_line
  first_line=$(head -1 "$skill_file")
  if [ "$first_line" = "---" ]; then
    pass "skills/$skill: starts with frontmatter (---)"
  else
    fail "skills/$skill: starts with frontmatter (---)" "first line: $first_line"
  fi

  # 3. Has name: field in frontmatter
  local has_name
  has_name=$(awk '/^---/{f++} f==1 && /^name:/{print; exit}' "$skill_file")
  if [ -n "$has_name" ]; then
    pass "skills/$skill: has name: field in frontmatter"
  else
    fail "skills/$skill: has name: field in frontmatter" "not found"
  fi

  # 4. Has description: field in frontmatter
  local has_desc
  has_desc=$(awk '/^---/{f++} f==1 && /^description:/{print; exit}' "$skill_file")
  if [ -n "$has_desc" ]; then
    pass "skills/$skill: has description: field in frontmatter"
  else
    fail "skills/$skill: has description: field in frontmatter" "not found"
  fi

  # 5. File is non-empty (> 5 lines)
  local line_count
  line_count=$(wc -l < "$skill_file")
  if [ "$line_count" -gt 5 ]; then
    pass "skills/$skill: file is non-empty (> 5 lines, got $line_count)"
  else
    fail "skills/$skill: file is non-empty (> 5 lines)" "got $line_count lines"
  fi
}

test_skills_frontmatter_all() {
  for skill in "${SKILL_NAMES[@]}"; do
    _test_skill "$skill"
  done
}
