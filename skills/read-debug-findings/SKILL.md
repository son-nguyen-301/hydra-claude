---
name: read-debug-findings
description: "This skill should be used when a debug findings file needs to be read by ID or path."
---

Workspace formula: `<slug>` = absolute CWD path with every `/` replaced by `-`.

- If a full path is provided, read it directly with the Read tool.
- If only an ID is provided, compute `<slug>` and read `~/.claude/projects/<slug>/debug-findings/debug-report-{id}.md`.
- If the file is not found, list the 3–5 most recent `debug-report-*.md` files so the user can pick one.

Return the full file content.
