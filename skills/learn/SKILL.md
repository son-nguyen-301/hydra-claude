---
name: learn
description: "This skill should be used when the user asks to 'learn from this session', 'save patterns', 'remember these conventions', or at session end when significant patterns were discovered."
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

**Step 1 — Read the conversation**
Review the current conversation for repo-specific patterns, decisions, corrections, and validated workflows.

Focus on:
- Coding conventions discovered or enforced during this session
- Architectural decisions made
- Corrections the user gave (what to do / what NOT to do)
- Workflows that were validated as correct
- File structure or naming patterns observed

**Step 2 — Filter for repo-specific patterns only**
Filter to repo-specific patterns only. Exclude generic best practices already covered by existing rules. Only save what is specific to this repository and would not be obvious from reading the code.

**Step 3 — Save to project workspace memory**
Compute `<slug>` from CWD. Write extracted patterns to `~/.claude/projects/<slug>/memory/learned.md`. Merge with existing content — do not overwrite unless entries conflict. Create the `memory/` directory if it does not exist. Format each entry as a brief rule with a **Why:** explanation.

Confirm that `~/.claude/projects/<slug>/memory/learned.md` has been updated and summarize what was added.
