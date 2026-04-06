---
name: learn
description: Use this skill at session end or on demand to extract repo-specific patterns from the conversation and save them to .claude/memory/learned.md for future sessions.
---

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

**Step 3 — Save to project-local shared memory**
Write the extracted patterns to `.claude/memory/learned.md` in the **project root** (the directory where `claude` was launched).
- Create `.claude/memory/` if it does not exist.
- If `learned.md` already exists, merge new patterns in — do not overwrite existing ones unless they conflict.
- Format each entry as a brief rule with a **Why:** explanation.
- **NEVER** write to `~/.claude/skills/learned/` or any path under `~/.claude/`. These patterns are repo-specific and must stay local to the project.

## Output

Confirm that `.claude/memory/learned.md` has been updated and summarize what was added.
