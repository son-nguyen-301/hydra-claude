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
