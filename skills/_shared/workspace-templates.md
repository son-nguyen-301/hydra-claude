# Shared Reference — Output Templates

This file contains all output and document templates used by skills and agents. Do NOT duplicate these templates — reference this file instead.

---

## Output templates

### plan-{id}.md

```markdown
# Plan {id}: {title}

## Context / Requirements

## Complexity: {trivial|low|medium|high|expert}
## Suggested agent: {sprinter|builder|architect}

## Implementation steps

## Files to create / edit

## Verification

## Risks / open questions
```

### sub-plan-{parent-id}-{letter}.md

```markdown
# Sub-plan {parent-id}-{letter}: {title}

## Parent plan
plan-{parent-id}.md

## Dependencies
{list of sub-plan letter IDs this depends on, or "None"}

## Context / Requirements

## Complexity: {trivial|low|medium|high|expert}
## Suggested agent: {sprinter|builder|architect}

## Implementation steps

## Files to create / edit

## Verification
```

### debug-report-{id}.md

```markdown
# Debug Report {id}
## Summary
## Reproduction
## Suspected root cause
## Affected code (paths:lines)
## Fix hypothesis
## Open questions
```

### task-{plan-id}.md

```markdown
# Task {plan-id}
## Status: Done | Failed
## What changed
## Files touched (paths only)
## Verification run
## Follow-ups
```

### codebase-knowledge.md outline

The `explore-codebase` skill produces a file following this outline:

1. What this repo is
2. Tech stack and tooling
3. Top-level layout
4. Architecture
5. Orchestration model
6. Workspace layout
7. Hooks
8. Skills
9. Tests
10. JSON manifests
11. Coding conventions
12. Existing rule files
13. Gotchas / learned patterns
14. Task completion checklist

### code-review-{plan-id}.md

```markdown
# Code Review {plan-id}

## Metadata
- Plan: ~/.claude/projects/<slug>/plans/plan-{plan-id}.md
- Task: ~/.claude/projects/<slug>/tasks/task-{plan-id}.md
- Reviewed-at: {ISO8601}
- Files reviewed: {count}
- Lenses applied: Plan Compliance, Correctness, Security, Conventions, Edge Cases, Test Quality, Code Quality

## Verdict
One of: **Approve | Fix-required | Rework**

## Summary
(2-5 sentences: overall quality, top risks, what stood out.)

## Statistics
- Total findings: {count}
- Blockers: {count} | Majors: {count} | Minors: {count} | Nits: {count}

## Findings

### Blockers
(Omit section if none. Each finding: Severity - Lens - File:lines - Observation - Suggested fix - Rationale - Effort.)

### Major
...

### Minor
...

### Nit
...

## Plan compliance checklist
(For each plan step: ✅ Done / ❌ Missing / ⚠️ Partial / ↔️ Deviated with brief note.)

## Lens coverage
Brief note per lens (even when no findings) so the orchestrator sees what was checked.

## Recommended next step
Either: "Spawn {original-agent} to apply fixes listed above." OR "Task is done — implementation passes all review lenses."
```

---

## Document type templates (doc-writer)

### HLD (High-Level Design)

```markdown
# {title} — HLD
## Problem statement
## Goals and non-goals
## Proposed architecture
## Alternatives considered
## Risks and mitigations
## Rollout plan
```

### LLD (Low-Level Design)

```markdown
# {title} — LLD
## Interfaces
## Data shapes
## Control flow
## Error handling
## Test plan
```

### ADR (Architecture Decision Record)

```markdown
# ADR-{NNN}: {title}
## Status: Proposed | Accepted | Deprecated | Superseded
## Context
## Decision
## Consequences
```

### Runbook

```markdown
# Runbook: {title}
## Trigger / when to use
## Preconditions
## Steps
## Verification
## Rollback procedure
## Oncall contact
```

### RFC (Request for Comments)

```markdown
# RFC: {title}
## Author
## Status: Draft | Under Review | Accepted | Rejected
## Summary
## Motivation
## Detailed design
## Open questions
```
