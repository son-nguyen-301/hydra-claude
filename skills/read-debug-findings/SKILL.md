---
name: read-debug-findings
description: "This skill should be used when a debug findings file needs to be read by ID or path. Invoked by plan-task (Bug-fixing branch) after the debug skill writes findings and before writing the fix plan. Also use when the user asks to review previous debug findings."
---

> Workspace, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace.md`. Read that file first.

## Return contract

Return the full debug report content verbatim. Do not summarize. The intended consumer is the `plan-task` skill (Bug-fixing branch), which reads these findings before writing a bug-fix plan — the return shape must be self-contained.

If the report content exceeds 400 lines, return it in full and flag it as unusually large so the caller can decide whether to summarize. Never truncate.

## Procedure

- If a full path is provided, read it directly with the Read tool.
- If only an ID is provided, compute `<slug>` and read `~/.claude/projects/<slug>/debug-findings/debug-report-{id}.md`.
- If the file is not found, list the 3--5 most recent `debug-report-*.md` files so the user can pick one.
