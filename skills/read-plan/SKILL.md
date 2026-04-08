---
name: read-plan
description: Use this skill to read a plan file by plan ID or plan path.
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

## Input

A plan ID (e.g., `42`) or a plan file path (e.g., `~/.claude/projects/<slug>/plans/plan-42.md`).

## Output

The full content of the plan file. If the plan file is not found, return a list of the 3–5 most recent plan files so the user can pick one.

## How It Works

1. If a full path is given, read it directly.
2. If a plan ID is given, compute `<slug>` from the current working directory, then read `~/.claude/projects/<slug>/plans/plan-{id}.md`.
3. If not found, glob for `~/.claude/projects/<slug>/plans/plan-*.md`, sort by modification time descending, and return the 3–5 most recent filenames so the user can pick one.
