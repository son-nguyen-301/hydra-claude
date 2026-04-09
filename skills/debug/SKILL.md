---
name: debug
description: "This skill should be used when the user reports a bug, asks to 'debug', 'find root cause', 'investigate an error', or 'trace a failure'. Use to pinpoint the bug location and write a findings report."
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

**Step 1 — Exploration**
Pinpoint the exact locations where the bug occurs using GitNexus MCP tools. If unavailable, use Grep, Glob, Read. Trace functions, call chains, and dependencies related to the bug.

**Step 2 — Root cause analysis**
Determine the root cause from the exploration findings.

**Step 3 — Write findings**
Compute `<slug>` from the CWD (replace every `/` with `-`). Write findings to `~/.claude/projects/<slug>/debug-findings/debug-report-{bug-id}.md`. Create the directory if needed. Return the file path.
