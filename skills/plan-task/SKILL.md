---
name: plan-task
description: "This skill should be used when the user requests file changes, asks to 'plan a task', 'create a plan', 'analyze requirements', or when any coding or bug-fixing task needs to be started."
---

### Step 1 — Categorize the task

Determine if this is a **Coding Task** or a **Bug Fixing Task**.

---

### Coding Task

**Step 1 — Gather requirements**
Gather requirements from the current conversation. If a Jira ticket URL is provided, invoke the `read-jira` skill to fetch it. If a Confluence page URL is provided, invoke the `read-confluence` skill to fetch it. Clarify until requirements are unambiguous. NEVER assume — ask the user if anything is unclear.

**Step 2 — Locate the implementation area**
Locate the implementation area using GitNexus MCP tools. If unavailable, use Grep, Glob, Read.

**Step 3 — Assess complexity**

| Complexity    | Signals                                                                                                                          | Suggested agent |
|---------------|----------------------------------------------------------------------------------------------------------------------------------|-----------------|
| trivial / low | Single-fact Q&A, doc lookup, config change, rename, single-file clear-intent change, fetch + write structured output             | `sprinter`      |
| medium / high | Standard implement / debug / refactor, multi-file changes, bounded code review                                                   | `builder`       |
| expert        | Architectural decisions, unknown-root-cause debugging, security review, cross-cutting refactor                                   | `architect`     |

**Step 4 — Write the plan**

Workspace path formula:
> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

Read and follow the rules in `~/.claude/projects/<slug>/memory/codebase-knowledge.md` before writing the plan. Write the plan to `~/.claude/projects/<slug>/plans/plan-{plan-id}.md` (create the plans/ directory if it does not exist). Inform the user of the plan filename and the suggested subagent. Update the plan if the user provides additional input. Do NOT print the plan content to the user.

---

### Bug Fixing Task

**Step 1 — Understand the bug**
Gather bug details from the current conversation. If a Jira ticket URL is provided, invoke the `read-jira` skill to fetch it. If a Confluence page URL is provided, invoke the `read-confluence` skill to fetch it. NEVER assume — ask the user if anything is unclear.

**Step 2 — Find the root cause**
Invoke the `debug` skill to investigate the root cause. Then invoke `read-debug-findings` to read the findings before writing the plan.

**Step 3 — Assess complexity**

| Complexity    | Suggested agent |
|---------------|-----------------|
| trivial / low | `sprinter`      |
| medium        | `builder`       |
| high / expert | `architect`     |

**Step 4 — Write the plan**

Workspace path formula:
> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

Read and follow the rules in `~/.claude/projects/<slug>/memory/codebase-knowledge.md` before writing the plan. Write the plan to `~/.claude/projects/<slug>/plans/plan-{plan-id}.md` (create the plans/ directory if it does not exist). Inform the user of the plan filename and the suggested subagent, then ask for approval. Update the plan if the user provides additional input. Do NOT print the plan content to the user.
