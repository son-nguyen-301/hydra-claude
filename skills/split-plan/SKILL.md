---
name: split-plan
description: "Decompose a parent plan into parallel-executable subtasks and orchestrate their execution in dependency waves. Invoke when the user says 'split the plan', 'break down the plan', 'parallelize', 'decompose into subtasks', or 'run subtasks in parallel'."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Output templates are in `skills/_shared/workspace-templates.md`. Read both files first.

## Step 1 — Read the parent plan

Invoke the `read-plan` skill with the provided plan path or plan ID to retrieve the full plan content.

After the plan content is loaded, proceed immediately to Step 2. Do NOT stop here or output the plan content to chat.

Compute `<slug>` from CWD (every `/` replaced by `-`).

## Step 2 — Analyze and decompose

Analyze the parent plan's implementation steps. Identify natural split points: groups of steps that can be worked on independently (different files, no shared data dependencies, no ordering constraints between them).

If no independent groups can be identified (all steps are tightly coupled), inform the user that the plan is not a good candidate for splitting and stop here. Do NOT force a split.

### Dependency detection rules

Apply these rules when determining dependencies between subtasks:

- **File-level conflict**: if two subtasks edit the same file, they MUST be in different waves — the later one depends on the earlier.
- **Type/interface dependency**: if subtask B uses a type or interface created by subtask A, B depends on A.
- **Import chain**: if subtask B imports a module created or significantly modified by subtask A, B depends on A.
- **Test dependency**: if subtask B writes tests for code created by subtask A, B depends on A.

When in doubt about independence, add a dependency — false dependencies only slow execution, but missing dependencies cause merge conflicts or build failures.

For each independent group (subtask), determine:

| Field | What to decide |
|-------|---------------|
| Letter ID | `a`, `b`, `c`, ... (sequential, up to `z`) |
| Title | Clear description of what this subtask does |
| Implementation steps | The subset of parent plan steps belonging to this subtask |
| Files to create / edit | The subset of files scoped to this subtask |
| Dependencies | List of sub-plan letter IDs this subtask depends on, or `None` |
| Complexity | `trivial`, `low`, `medium`, `high`, or `expert` |
| Suggested agent | `sprinter` (trivial/low), `builder` (medium/high), `architect` (expert) |
| Verification | Criteria specific to this subtask |

Assign wave numbers: Wave 1 = subtasks with no dependencies. Wave 2 = subtasks whose only dependencies are all in Wave 1. Continue until all subtasks are assigned a wave.

## Step 3 — Write sub-plans and get approval

Write each subtask to:
```
~/.claude/projects/<slug>/plans/plan-{parent-id}-{letter}.md
```

Use the `sub-plan-{parent-id}-{letter}.md` template from `workspace-templates.md`.

When presenting the dependency table to the user, show the absolute expanded paths (with `~` resolved to the actual home directory), not the slug template.

Present a dependency summary table to the user:

| Sub-plan | Title | Dependencies | Wave | Agent |
|----------|-------|-------------|------|-------|
| plan-{parent-id}-a | ... | None | 1 | sprinter |
| plan-{parent-id}-b | ... | a | 2 | builder |
| ... | | | | |

Ask the user for approval before proceeding. If the user requests changes to any sub-plan, update that sub-plan file, re-present the full dependency table, and ask for approval again. If the user wants to change the parent plan itself, inform them to update the parent plan (re-run `plan-task` if needed) before proceeding. Loop until the user explicitly approves all sub-plans before moving to Step 4.

## Step 4 — Orchestrate execution in waves

Execute subtasks wave by wave:

**For each wave:**
1. Identify all subtasks in the current wave whose dependencies have all completed successfully.
2. Spawn each subtask in parallel as its own subagent in a single message, using the Agent tool with the appropriate `subagent_type` matching the sub-plan's suggested agent (`sprinter`, `builder`, or `architect`). Pass only the sub-plan file path — do NOT include the sub-plan content in the agent prompt.
3. Wait for all agents in the wave to complete before proceeding.
4. If any subtask fails:
   - Report which subtask failed and what the agent returned.
   - Ask the user how to proceed: (a) retry the failed subtask, (b) skip it and continue with unblocked waves, or (c) abort all remaining subtasks.
   - Honor the user's choice before continuing.

Repeat until all subtasks are done or the user aborts.

## Step 5 — Aggregate and report

After all subtasks complete (or after a user-directed partial completion):

1. Collect all task summaries from `~/.claude/projects/<slug>/tasks/task-{parent-id}-{letter}.md` for each completed subtask.
2. Append an execution record to the parent plan file listing each subtask's status:

```markdown
---
## Execution record
Status: Done | Partial | Failed
Subtasks:
  - plan-{parent-id}-a: Done | Failed | Skipped
  - plan-{parent-id}-b: Done | Failed | Skipped
  - ...
Task summaries: ~/.claude/projects/<slug>/tasks/task-{parent-id}-*.md
Completed-at: {ISO8601 timestamp}
Agent: split-plan
```

3. Report the overall status to the user (all done, partial failure with details, or aborted). Always show absolute paths for the parent plan, task summaries, and any review files so the user can easily open them.

## Step 6 — Code review

Spawn the `code-reviewer` agent with the parent plan path for a unified review of all changes made across all subtasks. After the code reviewer returns, show the user the review verdict, finding counts, and the review file's absolute path.
