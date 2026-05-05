---
name: debug
description: "Investigate bugs and trace root causes. Invoke when the user reports a bug, says 'debug this', 'find root cause', 'why is X failing', 'trace this error', 'investigate', or pastes an error message or stack trace. Also invoke proactively when plan-task encounters a bug-fixing task."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

## Return contract

After writing findings, hold the file path in context for the caller. Do NOT output the full report content to chat.

When invoked as a sub-step of another skill (e.g., plan-task bug-fixing branch), proceed immediately to the caller's next step after writing findings — do NOT stop or treat this as a terminal action.

---

**Step 0 — Precondition**
Load project memory per the shared precondition in `workspace-core.md`: read the native auto-memory index (`memory/MEMORY.md`), plugin memory index (`memory/plugin/MEMORY.md`), and `codebase-knowledge.md`. For each, read if it exists, note absence and continue.

---

## Decision tree: investigate vs. ask

Before proceeding, determine whether to investigate independently or ask the user for more information:

- **Investigate independently** when: the error message is clear and specific (stack trace, exception type, file + line), the affected code is accessible and readable, and the symptom can be reproduced from information already in the conversation.
- **Ask the user first** when: symptoms are vague ("it's broken", "something is wrong"), the bug involves external systems, infrastructure, or runtime state not visible in the code, or reproduction steps are missing and cannot be inferred.

If asking, request: exact error message or stack trace, steps to reproduce, expected vs. actual behavior, and when the bug first appeared.

---

**Step 1 — Gather symptoms**
Collect all available evidence from the conversation:
- Error messages, exception types, and stack traces (exact text)
- Steps to reproduce (what triggers the bug)
- Expected vs. actual behavior
- When it started (recent commit? After a deployment? Always present?)
- Environment details if relevant (OS, version, config)

If critical information is missing and cannot be inferred, ask the user before proceeding to Step 2.

**Step 2 — Narrow scope**
Identify the blast radius before diving deep:
- Run `git log --oneline -20` to surface recent commits — many bugs are regressions from a recent change.
- Run existing tests to see which ones fail: `npm test`, `pytest`, `go test ./...`, or equivalent.
- Identify the affected module, function, or subsystem from the stack trace or error message.
- Check if the bug is isolated (one file, one function) or cross-cutting (multiple modules, shared state).

**Step 3 — Deep investigation**
Trace the bug using the best available tools. See `skills/debug/references/debug-methodology.md` for specific GitNexus Cypher queries and investigation patterns.

Priority order:
1. **GitNexus** (if the repo is indexed): use `query` to find the affected function, then Cypher queries to trace callers, dependencies, and recent changes.
2. **Grep + Glob** (if GitNexus is unavailable or repo is not indexed): search for the function name, error string, or relevant identifiers. Read the files that contain them.
3. **Read** key files directly: trace the call chain manually from the entry point to the failure site.

At each step, check:
- What are the inputs to this function?
- What is the expected output vs. the actual output?
- Where does the data diverge from what is expected?
- Is there shared mutable state, race condition, or off-by-one error?

**Step 4 — Root cause confirmation**
Confirm the hypothesis before writing findings:
- Trace the exact data flow that triggers the bug end-to-end.
- Identify the single root cause (not just a symptom).
- If possible, describe a minimal reproduction: the smallest input or code path that causes the failure.
- Note whether the fix is a one-line change or requires structural work (this affects plan complexity).

**Step 5 — Write findings**
Write findings to `~/.claude/projects/<slug>/debug-findings/debug-report-{bug-id}.md` using the `debug-report-{id}.md` template from the shared reference. Create the directory if needed. Note the file path for the caller.

Populate all template fields:
- **Summary**: one paragraph, what the bug is and where it lives
- **Reproduction**: exact steps to reproduce
- **Suspected root cause**: the confirmed (or most likely) root cause with code location (file:line)
- **Affected code**: all paths and line ranges touched by the bug
- **Fix hypothesis**: what change would fix it and why
- **Open questions**: any remaining uncertainty that the plan author should resolve
