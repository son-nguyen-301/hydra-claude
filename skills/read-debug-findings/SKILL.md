---
name: read-debug-findings
description: "Read a debug findings report by ID or path. Invoked by plan-task after the debug skill writes findings. Also use when the user asks to 'review debug findings', 'show me the debug report', or 'what did we find'."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

## Return contract

Read the debug report and hold its content in context for subsequent processing. The content is self-contained — do NOT re-fetch or supplement it. Do NOT output the report content to chat unless this skill is the top-level user request (e.g., user said "show me the debug report").

When invoked as a sub-step of another skill (e.g., plan-task bug-fixing branch), proceed immediately to the caller's next step after reading — do NOT stop or treat this as a terminal action.

If the report content exceeds 400 lines, flag it as unusually large so the caller can decide whether to summarize. Never truncate.

## Procedure

- If a full path is provided, read it directly with the Read tool.
- If only an ID is provided, compute `<slug>` and read `~/.claude/projects/<slug>/debug-findings/debug-report-{id}.md`.
- If the file is not found, list the 3--5 most recent `debug-report-*.md` files so the user can pick one.
