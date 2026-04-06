---
name: plan-task
description: Use this skill to create a plan before working on any coding or bug-fixing task.
---

## Thought Process

### Step 1 — Categorize the task

Determine if this is a **Coding Task** or a **Bug Fixing Task**.

---

### Coding Task

**Step 1 — Gather requirements**
Collect requirements from user input. If the user provides a Jira ticket or Confluence page, use the `read-jira` or `read-confluence` skill. Clarify until requirements are unambiguous. NEVER assume — ask the user if anything is unclear.

**Step 2 — Locate the implementation area**
Use `GitNexus` MCP tools and skills to find where the changes should be made. If GitNexus is unavailable, use other available tools (Grep, Glob, Read, etc.).

**Step 3 — Assess complexity**

| Complexity    | Signals                                                                                                                          | Suggested agent |
|---------------|----------------------------------------------------------------------------------------------------------------------------------|-----------------|
| trivial / low | Single-fact Q&A, doc lookup, config change, rename, single-file clear-intent change, fetch + write structured output             | `sprinter`      |
| medium / high | Standard implement / debug / refactor, multi-file changes, bounded code review                                                   | `builder`       |
| expert        | Architectural decisions, unknown-root-cause debugging, security review, cross-cutting refactor                                   | `architect`     |

**Step 4 — Write the plan**
Write the plan to `.claude/plans/plan-{plan-id}.md` (create `.claude/plans/` if it does not exist). Always read and follow the rules in `.claude/memory/codebase-knowledge.md` before writing the plan. Inform the user of the plan filename and the suggested subagent. Update the plan if the user provides additional input. Do NOT print the plan content to the user.

---

### Bug Fixing Task

**Step 1 — Understand the bug**
Gather bug details from user input. If the user provides a Jira ticket or Confluence page, use the `read-jira` or `read-confluence` skill. NEVER assume — ask the user if anything is unclear.

**Step 2 — Find the root cause**
Use `GitNexus` MCP tools and skills to trace the root cause and identify which files need to change. If GitNexus is unavailable, use other available tools.

**Step 3 — Assess complexity**

| Complexity    | Suggested agent |
|---------------|-----------------|
| trivial / low | `sprinter`      |
| medium        | `builder`       |
| high / expert | `architect`     |

**Step 4 — Write the plan**
Write the plan to `.claude/plans/plan-{plan-id}.md` (create `.claude/plans/` if it does not exist). Always read and follow the rules in `.claude/memory/codebase-knowledge.md` before writing the plan. Inform the user of the plan filename and the suggested subagent, then ask for approval. Update the plan if the user provides additional input. Do NOT print the plan content to the user.
