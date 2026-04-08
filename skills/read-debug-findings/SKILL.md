---
name: read-debug-findings
description: Use this skill to read a debug findings file by file path or file ID.
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

## Input

- File path (e.g., `~/.claude/projects/<slug>/debug-findings/debug-report-001.md`)
- OR file ID (e.g., `001`)

## Output

The full content of the debug findings file. If the file is not found by ID, list the 3–5 most recent debug report files so the user can pick one.

## How It Works

If a full path is provided, read it directly. If only an ID is provided, compute `<slug>` from the current working directory using the formula above, then look for `~/.claude/projects/<slug>/debug-findings/debug-report-{id}.md`. Return the full content of the file.
