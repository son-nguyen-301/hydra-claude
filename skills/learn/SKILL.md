---
name: learn
description: Use this skill at session end or on demand to extract repo-specific patterns from the conversation and save them to the project workspace memory for future sessions.
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

## How It Works

**Step 1 — Read the conversation**
Review the entire current conversation for patterns, decisions, corrections, and conventions that are specific to this repo and worth preserving across sessions.

Focus on:
- Coding conventions discovered or enforced during this session
- Architectural decisions made
- Corrections the user gave (what to do / what NOT to do)
- Workflows that were validated as correct
- File structure or naming patterns observed

**Step 2 — Filter for repo-specific patterns only**
Exclude generic best practices already covered by the existing rules. Only save what is specific to this repository and would not be obvious from reading the code.

**Step 3 — Save to project workspace memory**
Write the extracted patterns to `~/.claude/projects/<slug>/memory/learned.md`.
- Compute `<slug>` from the current working directory using the formula above.
- Create the `memory/` directory if it does not exist.
- If `learned.md` already exists, merge new patterns in — do not overwrite existing ones unless they conflict.
- Format each entry as a brief rule with a **Why:** explanation.

## Output

Confirm that `~/.claude/projects/<slug>/memory/learned.md` has been updated and summarize what was added.
