---
name: plan-task
description: "Use when the user requests any code change, feature, refactor, or bug fix. Triggers on: 'implement X', 'build X', 'add X', 'change X', 'fix X', 'refactor X', 'update X', 'plan a task', 'create a plan'. This is the entry point for ALL file-changing work — invoke proactively even when the user doesn't explicitly say 'plan'."
---

### Step 1 — Categorize the task

Determine if this is a **Coding Task** or a **Bug Fixing Task**.

---

### Coding Task

**Step 1 — Gather requirements**
Gather requirements from the current conversation. If a Jira ticket reference is provided, invoke the `read-jira` skill to fetch it. If a Confluence page reference is provided, invoke the `read-confluence` skill to fetch it. Clarify until requirements are unambiguous. NEVER assume — ask the user if anything is unclear.

**Step 2 — Locate the implementation area**
Locate the implementation area using GitNexus MCP tools. If unavailable, use Grep, Glob, Read.

**Step 3 — Assess complexity**

| Complexity    | Signals                                                                                                                          | Suggested agent |
|---------------|----------------------------------------------------------------------------------------------------------------------------------|-----------------|
| trivial / low | Single-fact Q&A, doc lookup, config change, rename, single-file clear-intent change, fetch + write structured output             | `sprinter`      |
| medium / high | Standard implement / debug / refactor, multi-file changes, bounded code review                                                   | `builder`       |
| expert        | Architectural decisions, unknown-root-cause debugging, security review, cross-cutting refactor                                   | `architect`     |

**Step 4 — Write the plan**
Follow the [Shared: Writing the plan](#shared-writing-the-plan) section below.

---

### Bug Fixing Task

**Step 1 — Understand the bug**
Gather bug details from the current conversation. If a Jira ticket URL is provided, invoke the `read-jira` skill to fetch it. If a Confluence page URL is provided, invoke the `read-confluence` skill to fetch it. NEVER assume — ask the user if anything is unclear.

**Step 2 — Find the root cause**
Invoke the `debug` skill to investigate the root cause. Then invoke `read-debug-findings` to read the findings before writing the plan.

**Step 3 — Assess complexity**

| Complexity    | Signals                                                                                                    | Suggested agent |
|---------------|------------------------------------------------------------------------------------------------------------|-----------------|
| trivial / low | One-line fix, obvious typo, known off-by-one, isolated to a single file                                    | `sprinter`      |
| medium        | Single-module fix, clear repro steps, well-scoped regression                                               | `builder`       |
| high / expert | Unknown root cause, cross-module impact, security/concurrency concern, requires understanding multiple subsystems | `architect`     |

**Step 4 — Write the plan**
Follow the [Shared: Writing the plan](#shared-writing-the-plan) section below.

---

### Shared: Writing the plan

> Workspace path, slug computation, and ID scheme are in `skills/_shared/workspace-core.md`. Output templates are in `skills/_shared/workspace-templates.md`. Read both files first.

Read and follow the rules in `~/.claude/projects/<slug>/memory/codebase-knowledge.md` before writing the plan. Write the plan to `~/.claude/projects/<slug>/plans/plan-{plan-id}.md` (create the plans/ directory if it does not exist). Use the `plan-{id}.md` template from `workspace-templates.md`.

**Step 1 — Write the plan**
Inform the user of the plan filename and the suggested subagent. Update the plan if the user provides additional input. Do NOT print the plan content to the user.

**Step 2 — Spawn the plan-reviewer agent (MANDATORY)**
Spawn the `plan-reviewer` agent with the plan path. The plan-reviewer agent will invoke the review-plan skill internally, apply its six professional review behaviors, and return a verdict: `Approve`, `Approve-with-changes`, or `Revise`.

**Step 3 — Handle the review verdict**

- **Approve**: The plan is solid and ready. Inform the user that the plan passed review and is ready to proceed.
- **Approve-with-changes**: The plan is generally good but has some suggestions for improvement. Present the major findings to the user and ask: "Should I apply these suggested rewrites to the plan before proceeding, or proceed with the current plan as-is?"
  - If the user chooses to rewrite: apply the changes and re-run the plan-reviewer to confirm.
  - If the user chooses to proceed: continue to Step 4 with the current plan.
- **Revise**: The plan has blocking issues that must be resolved. Present the blockers to the user and offer: "I found issues that should be fixed before proceeding. Would you like me to re-plan with these findings as context?"
  - If yes: incorporate the findings and return to Step 1.
  - If no: proceed with the current plan at the user's risk.

**Step 4 — User approval and execution**
Ask the user for final approval to proceed with the plan. Once approved, invoke the `split-plan` skill with the plan path. The `split-plan` skill handles decomposition into sub-plans, the sub-plan approval loop, parallel execution in waves, and the final code review. Do NOT directly invoke a subagent — that is now the responsibility of `split-plan`.
