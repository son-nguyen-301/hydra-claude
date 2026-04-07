---
name: read-debug-findings
description: Use this skill to read a debug findings file by file path or file ID.
---

## Input

- File path (e.g., `.claude/debug/debug-report-001.md`)
- OR file ID (e.g., `001`)

## Output

The full content of the debug findings file. If the file is not found by ID, list the 3–5 most recent debug report files so the user can pick one.

## How It Works

If a full path is provided, read it directly. If only an ID is provided, look for `.claude/debug/debug-report-{id}.md`. Return the full content of the file.
