---
name: debug
description: "This skill should be used when the user reports a bug, asks to 'debug', 'find root cause', 'investigate an error', or 'trace a failure'. Use to pinpoint the bug location and write a findings report."
---

> Workspace, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace.md`. Read that file first.

**Step 0 — Precondition**
Compute `<slug>` from the CWD (replace every `/` with `-`). Read `~/.claude/projects/<slug>/memory/codebase-knowledge.md` if it exists. If it does not exist, note this in your output and suggest running the `explore-codebase` skill first. Continue regardless.

**Step 1 — Exploration**
Pinpoint the exact locations where the bug occurs using GitNexus MCP tools. If unavailable, use Grep, Glob, Read. Trace functions, call chains, and dependencies related to the bug.

**Step 2 — Root cause analysis**
Determine the root cause from the exploration findings.

**Step 3 — Write findings**
Write findings to `~/.claude/projects/<slug>/debug-findings/debug-report-{bug-id}.md` using the `debug-report-{id}.md` template from the shared reference. Create the directory if needed. Return the file path.
