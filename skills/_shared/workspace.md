# Shared Reference — Workspace, IDs, and Templates

This file is the single source of truth for workspace conventions used by all
skills and agents. Do NOT duplicate these rules — reference this file instead.

---

## Workspace path

The workspace base is `~/.claude/projects/<slug>/`.

`<slug>` = the project's absolute CWD path with every `/` replaced by `-`
(e.g., `/Users/foo/bar` becomes `-Users-foo-bar`).

Directory layout:

| Directory          | Purpose                                  |
|--------------------|------------------------------------------|
| `plans/`           | Task plans created by `plan-task`        |
| `tasks/`           | Task summaries written by executor agents|
| `debug-findings/`  | Debug reports written by the `debug` skill|
| `memory/`          | `learned.md` and `codebase-knowledge.md` |
| `docs/`            | Documents produced by `doc-writer`       |

---

## ID computation

All IDs are three-digit zero-padded sequential numbers, computed per kind per
project.

**Plan ID:** scan `~/.claude/projects/<slug>/plans/` for existing `plan-NNN.md`
files. The next ID is `max(NNN) + 1`, zero-padded to three digits. If the
`plans/` directory does not exist or is empty, the first ID is `001`.

**Debug ID:** same scheme, scanning `~/.claude/projects/<slug>/debug-findings/`
for `debug-report-NNN.md`. First ID is `001`.

**Task ID:** matches the plan ID that produced it. File naming:
`task-{plan-id}.md`. If the agent receives a free-text task description (no
plan ID), compute the next available `task-NNN.md` by scanning the `tasks/`
directory using the same scheme.

---

## Precondition — codebase-knowledge.md

Before making any code changes, read
`~/.claude/projects/<slug>/memory/codebase-knowledge.md` if it exists. If it
does not exist, note this in your output and suggest running the
`explore-codebase` skill first. Skip this step only when the task explicitly
does not involve code changes (e.g., pure documentation from provided content).

---

## Output templates

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

## Plan cross-reference (executor agents)

After writing the task summary, append an execution record to the bottom of the
originating plan file (if it exists):

```markdown
---
## Execution record
Status: Done | Failed
Task summary: ~/.claude/projects/<slug>/tasks/task-{plan-id}.md
Completed-at: {ISO8601 timestamp}
Agent: {sprinter|builder|architect}
```

If the plan file is not found (free-text task), skip this step. If the section
already exists (retry / re-run), replace it rather than duplicating.

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
