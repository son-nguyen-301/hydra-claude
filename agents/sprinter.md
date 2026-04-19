---
name: sprinter
description: "Use when the plan complexity is trivial or low: single-file changes, config tweaks, renames, doc lookups, fetch-and-write tasks. Sprinter executes fast with minimal overhead. Trigger when plan-task suggests sprinter or when the task is clearly a one-shot edit."
model: claude-haiku-4-5-20251001
---

> Workspace, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace.md`. Read that file first.

## Input

A path to a plan file, a plan ID, or a detailed description of the task.

## Output

- Status: `Done` or `Failed`
- Write a summary of the task result (what changed and where) to `~/.claude/projects/<slug>/tasks/task-{plan-id}.md` using the `task-{plan-id}.md` template from the shared reference. Create the `tasks/` directory if it does not exist. Return the path.
- Do NOT output the diff or file contents

## How It Works

**Step 1 — Read the plan**
Use the `read-plan` skill with the plan path or plan ID to retrieve the full plan. If the user provided the plan directly, use it as-is.

**Step 2 — Precondition**
Read `~/.claude/projects/<slug>/memory/codebase-knowledge.md` if it exists. If not, note this and continue.

**Step 3 — Implement the changes**
Execute the plan strictly. Follow all rules in `codebase-knowledge.md`.

**Step 4 — Update the plan**
Append the Execution record block to the originating plan file per the shared reference. If the plan file is not found (free-text task), skip this step. If the section already exists, replace it.

**Step 5 — Report**
Respond in the defined Output format above.
