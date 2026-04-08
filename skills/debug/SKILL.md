---
name: debug
description: Use this skill when you need to debug a Backend bug. It explores the codebase to pinpoint the bug location, finds the root cause, and writes findings to a report file.
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

## Input

- Bug description
- Images (optional)
- Jira ticket URL (optional)
- Confluence page URL (optional)

## Output

The path to the debug findings file (`debug-report-{bug-id}.md`).

## How It Works

**Step 1 — Exploration**
Based on user input, pinpoint the exact locations where the bug occurs. Use `GitNexus` MCP tools and skills to find functions, call chains, and dependencies related to the bug. Use other available tools (Grep, Glob, Read) if GitNexus is unavailable.

**Step 2 — Root cause analysis**
From the findings in Step 1, determine the root cause of the bug.

**Step 3 — Write findings**
Compute `<slug>` from the current working directory using the formula above. Write the findings to `~/.claude/projects/<slug>/debug-findings/debug-report-{bug-id}.md` (create the directory if it does not exist). Return the path to the file.
