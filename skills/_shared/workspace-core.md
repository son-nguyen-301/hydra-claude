# Shared Reference — Workspace paths, IDs, and Preconditions

This file is the single source of truth for workspace path, slug computation, ID scheme, preconditions, and execution records. All skills and agents reference this file. Do NOT duplicate these rules.

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
| `code-reviews/`    | Code reviews written by `code-reviewer` agent |

---

## ID computation

All IDs are three-digit zero-padded sequential numbers, computed per kind per project.

**Plan ID:** scan `~/.claude/projects/<slug>/plans/` for existing `plan-NNN.md` files. The next ID is `max(NNN) + 1`, zero-padded to three digits. If the `plans/` directory does not exist or is empty, the first ID is `001`.

**Debug ID:** same scheme, scanning `~/.claude/projects/<slug>/debug-findings/` for `debug-report-NNN.md`. First ID is `001`.

**Task ID:** matches the plan ID that produced it. File naming: `task-{plan-id}.md`. If the agent receives a free-text task description (no plan ID), compute the next available `task-NNN.md` by scanning the `tasks/` directory using the same scheme.

---

## Precondition — codebase-knowledge.md

Before making any code changes, read `~/.claude/projects/<slug>/memory/codebase-knowledge.md` if it exists. If it does not exist, note this in your output and suggest running the `explore-codebase` skill first. Skip this step only when the task explicitly does not involve code changes (e.g., pure documentation from provided content).

---

## Plan cross-reference (executor agents)

After writing the task summary, append an execution record to the bottom of the originating plan file (if it exists):

```markdown
---
## Execution record
Status: Done | Failed | Partial
Task summary: ~/.claude/projects/<slug>/tasks/task-{plan-id}.md
Completed-at: {ISO8601 timestamp}
Agent: {sprinter|builder|architect}
```

`Partial` is used by `split-plan` when some subtasks succeed and others fail.

If the plan file is not found (free-text task), skip this step. If the section already exists (retry / re-run), replace it rather than duplicating.
