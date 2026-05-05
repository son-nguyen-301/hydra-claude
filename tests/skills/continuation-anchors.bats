#!/usr/bin/env bats
# Regression tests for continuation anchors and return contract language
# Verify that skills and agents maintain non-terminal language to prevent workflow interruption

load '../test_helper'

# Path references for skill and agent files
READ_PLAN_SKILL="$ROOT/skills/read-plan/SKILL.md"
SPLIT_PLAN_SKILL="$ROOT/skills/split-plan/SKILL.md"
REVIEW_PLAN_SKILL="$ROOT/skills/review-plan/SKILL.md"
PLAN_REVIEWER_AGENT="$ROOT/agents/plan-reviewer.md"
DEBUG_SKILL="$ROOT/skills/debug/SKILL.md"
READ_JIRA_SKILL="$ROOT/skills/read-jira/SKILL.md"
READ_CONFLUENCE_SKILL="$ROOT/skills/read-confluence/SKILL.md"
READ_DEBUG_FINDINGS_SKILL="$ROOT/skills/read-debug-findings/SKILL.md"
REVIEW_CODE_SKILL="$ROOT/skills/review-code/SKILL.md"
WORKSPACE_CORE="$ROOT/skills/_shared/workspace-core.md"
WORKSPACE_TEMPLATES="$ROOT/skills/_shared/workspace-templates.md"
PLAN_TASK_SKILL="$ROOT/skills/plan-task/SKILL.md"
SPRINTER_AGENT="$ROOT/agents/sprinter.md"
BUILDER_AGENT="$ROOT/agents/builder.md"
ARCHITECT_AGENT="$ROOT/agents/architect.md"
CODE_REVIEWER_AGENT="$ROOT/agents/code-reviewer.md"
DOC_WRITER_AGENT="$ROOT/agents/doc-writer.md"

@test "read-plan return contract uses non-terminal language" {
  run grep -q "Do NOT output the plan content to chat" "$READ_PLAN_SKILL"
  assert_success
}

@test "read-plan has caller continuation guidance" {
  run grep -q "proceed immediately to the caller's next step" "$READ_PLAN_SKILL"
  assert_success
}

@test "split-plan has continuation anchor" {
  run grep -q "Do NOT stop here or output the plan content" "$SPLIT_PLAN_SKILL"
  assert_success
}

@test "plan-reviewer has continuation anchor" {
  run grep -q "Do NOT stop here or output the plan content" "$PLAN_REVIEWER_AGENT"
  assert_success
}

@test "review-plan has continuation anchor" {
  run grep -q "Do NOT stop here or output the plan content" "$REVIEW_PLAN_SKILL"
  assert_success
}

@test "review-plan has dedup guard" {
  run grep -q "already been read in this conversation" "$REVIEW_PLAN_SKILL"
  assert_success
}

@test "read-jira has non-terminal return contract" {
  run grep -q "do NOT stop or treat this as a terminal action" "$READ_JIRA_SKILL"
  assert_success
}

@test "read-confluence has non-terminal return contract" {
  run grep -q "do NOT stop or treat this as a terminal action" "$READ_CONFLUENCE_SKILL"
  assert_success
}

@test "read-debug-findings has non-terminal return contract" {
  run grep -q "do NOT stop or treat this as a terminal action" "$READ_DEBUG_FINDINGS_SKILL"
  assert_success
}

@test "debug has non-terminal return contract" {
  run grep -q "do NOT stop or treat this as a terminal action" "$DEBUG_SKILL"
  assert_success
}

@test "review-code has continuation anchor" {
  run grep -q "Do NOT stop here or output the plan content" "$REVIEW_CODE_SKILL"
  assert_success
}

@test "review-code uses non-terminal return language" {
  run grep -q "Provide the caller with" "$REVIEW_CODE_SKILL"
  assert_success
}

@test "review-plan uses non-terminal return language" {
  run grep -q "Provide the caller with" "$REVIEW_PLAN_SKILL"
  assert_success
}

@test "workspace templates contain Summary sections" {
  count=$(grep -c '## Summary' "$WORKSPACE_TEMPLATES")
  [ "$count" -ge 3 ]
}

@test "plan-task uses absolute file path" {
  run grep -q "absolute file path" "$PLAN_TASK_SKILL"
  assert_success
}

@test "plan-reviewer specifies absolute path" {
  run grep -q "absolute path" "$PLAN_REVIEWER_AGENT"
  assert_success
}

@test "code-reviewer specifies absolute path" {
  run grep -q "absolute path" "$CODE_REVIEWER_AGENT"
  assert_success
}

@test "split-plan specifies absolute paths" {
  run grep -q "absolute" "$SPLIT_PLAN_SKILL"
  assert_success
}

@test "review-plan specifies absolute path" {
  run grep -q "absolute path" "$REVIEW_PLAN_SKILL"
  assert_success
}

@test "review-code specifies absolute path" {
  run grep -q "absolute path" "$REVIEW_CODE_SKILL"
  assert_success
}

@test "sprinter specifies absolute path" {
  run grep -q "absolute path" "$SPRINTER_AGENT"
  assert_success
}

@test "builder specifies absolute path" {
  run grep -q "absolute path" "$BUILDER_AGENT"
  assert_success
}

@test "architect specifies absolute path" {
  run grep -q "absolute path" "$ARCHITECT_AGENT"
  assert_success
}

@test "plan-reviewer has Write in tools" {
  run grep -q "tools: Read, Write, Bash, Grep, Glob" "$PLAN_REVIEWER_AGENT"
  assert_success
}

@test "plan-reviewer does NOT have Write in disallowedTools" {
  run grep "disallowedTools:" "$PLAN_REVIEWER_AGENT"
  assert_output "disallowedTools: Edit, NotebookEdit"
}

@test "plan-reviewer has Edit and NotebookEdit in disallowedTools" {
  run grep -q "disallowedTools: Edit, NotebookEdit" "$PLAN_REVIEWER_AGENT"
  assert_success
}

@test "code-reviewer has Write in tools" {
  run grep -q "tools: Read, Write, Bash, Grep, Glob" "$CODE_REVIEWER_AGENT"
  assert_success
}

@test "code-reviewer does NOT have Write in disallowedTools" {
  run grep "disallowedTools:" "$CODE_REVIEWER_AGENT"
  assert_output "disallowedTools: Edit, NotebookEdit"
}

@test "code-reviewer has Edit and NotebookEdit in disallowedTools" {
  run grep -q "disallowedTools: Edit, NotebookEdit" "$CODE_REVIEWER_AGENT"
  assert_success
}

@test "workspace-core.md contains memory/MEMORY.md reference" {
  run grep -q "memory/MEMORY.md" "$WORKSPACE_CORE"
  assert_success
}

@test "workspace-core.md contains memory/plugin/MEMORY.md reference" {
  run grep -q "memory/plugin/MEMORY.md" "$WORKSPACE_CORE"
  assert_success
}

@test "sprinter references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$SPRINTER_AGENT"
  assert_success
}

@test "builder references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$BUILDER_AGENT"
  assert_success
}

@test "architect references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$ARCHITECT_AGENT"
  assert_success
}

@test "plan-reviewer references MEMORY.md in load context step" {
  run grep -q "MEMORY.md" "$PLAN_REVIEWER_AGENT"
  assert_success
}

@test "code-reviewer references MEMORY.md in load context step" {
  run grep -q "MEMORY.md" "$CODE_REVIEWER_AGENT"
  assert_success
}

@test "doc-writer references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$DOC_WRITER_AGENT"
  assert_success
}

@test "debug skill references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$DEBUG_SKILL"
  assert_success
}

@test "review-plan skill references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$REVIEW_PLAN_SKILL"
  assert_success
}

@test "review-code skill references MEMORY.md in precondition" {
  run grep -q "MEMORY.md" "$REVIEW_CODE_SKILL"
  assert_success
}

@test "plan-task skill references project memory" {
  run grep -q "project memory" "$PLAN_TASK_SKILL"
  assert_success
}

@test "architect skills frontmatter contains explore-codebase" {
  run grep -q "hydra-claude:explore-codebase" "$ARCHITECT_AGENT"
  assert_success
}

@test "doc-writer skills frontmatter contains explore-codebase" {
  run grep -q "hydra-claude:explore-codebase" "$DOC_WRITER_AGENT"
  assert_success
}
