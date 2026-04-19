---
name: read-plan
description: "This skill should be used when a plan file needs to be read by ID or path. MUST be invoked before delegating to any executor agent (sprinter, builder, architect) so the agent receives the plan. Also use when the user references a plan by ID or path, or when checking plan status."
---

> Workspace, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace.md`. Read that file first.

## Return contract

Return the full plan content verbatim. Do not summarize.

If the plan content exceeds 400 lines, return it in full and flag it as unusually large so the caller can decide whether to summarize before forwarding to a subagent. Never truncate.

If an Execution record section is present at the bottom of the plan, include it in the returned content so the caller can see the plan's completion status at a glance.

## Procedure

- If a full path is provided, read it directly with the Read tool.
- If a plan ID is provided, compute `<slug>` and read `~/.claude/projects/<slug>/plans/plan-{id}.md`.
- If the file is not found, glob `~/.claude/projects/<slug>/plans/plan-*.md`, sort by modification time descending, return the 3--5 most recent filenames.
