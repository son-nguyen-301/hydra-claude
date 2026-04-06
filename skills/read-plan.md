---
name: read-plan
description: Use this skill to read a plan file by plan ID or plan path.
---

## Input

A plan ID (e.g., `42`) or a plan file path (e.g., `.claude/plans/plan-42.md`).

## Output

The full content of the plan file. If the plan file is not found, return a list of the 3–5 most recent plan files so the user can pick one.

## How It Works

1. If a full path is given, read it directly.
2. If a plan ID is given, read `.claude/plans/plan-{id}.md`.
3. If not found, glob for `.claude/plans/plan-*.md`, sort by modification time descending, and return the 3–5 most recent filenames so the user can pick one.
