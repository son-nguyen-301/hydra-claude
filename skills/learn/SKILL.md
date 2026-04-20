---
name: learn
description: "Capture repo-specific patterns, corrections, and conventions from the current session into learned.md. Invoke when the user says 'learn from this', 'save patterns', 'remember this convention', 'save this for next time', or proactively at session end when significant patterns were discovered during the conversation."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

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

## Example entries

**Good** (repo-specific, actionable):
```
## Always use `setup_isolated_home` in bats tests
**Why:** Tests that write to `~/.claude/` without isolation pollute each
other's state and cause flaky failures in CI.
```

**Good** (correction from user):
```
## Never use `git add -A` in hook scripts
**Why:** User corrected this — hooks should only stage files they explicitly
created, not sweep up unrelated changes.
```

**Bad** (too generic — not repo-specific):
```
## Use descriptive variable names
**Why:** Readability.
```
This is a universal best practice. It belongs in a linter config, not learned.md.

**Step 3 — Dedup pass**
Before adding a new entry, scan `learned.md` for an existing rule whose intent matches. If found, merge the **Why:** lines rather than appending a duplicate.

**Step 4 — Conflict resolution**
When a new entry contradicts an existing one, keep the newer entry and move the older one to a `## Superseded` section at the bottom of the file with the date it was replaced. Do not silently delete.

**Step 5 — Save to project workspace memory**
Compute `<slug>` from CWD. Write extracted patterns to `~/.claude/projects/<slug>/memory/learned.md`. Create the `memory/` directory if it does not exist. Format each entry as a brief rule with a **Why:** explanation.

**Step 6 — Length budget check**
Target: learned.md should be no more than ~400 lines (~8000 tokens). After writing, check the line count. If the file exceeds 400 lines, surface a warning to the user listing the oldest/lowest-value entries and ask which ones to retire. Do not auto-trim.

Confirm that `~/.claude/projects/<slug>/memory/learned.md` has been updated and summarize what was added.
