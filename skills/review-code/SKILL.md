---
name: review-code
description: "Used internally by the code-reviewer agent. Review methodology tool that applies seven code review lenses. Accepts a plan path, identifies changed files, produces structured findings, and writes a review file."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

## Step 0 — Precondition

Compute `<slug>` from CWD (every `/` replaced by `-`). Attempt to read `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. If it exists, use it throughout the review to check convention alignment. If it does not exist, note this in the review summary and suggest `explore-codebase`, but continue — the review proceeds without it.

## Step 1 — Load context

Accept a plan path or plan ID. Use the `read-plan` skill to load the plan. Also read the task summary at `~/.claude/projects/<slug>/tasks/task-{plan-id}.md`. Note any file that is absent and continue — do not abort.

## Step 2 — Identify changed files

Try the following strategies in order; use the first that returns at least one file:

1. Parse the "Files touched" section from the task summary.
2. `git diff HEAD~1 --name-only`
3. `git diff --name-only`
4. `git diff --cached --name-only`

Read each changed file in full. Also read the diff for each file (use `git diff HEAD~1 -- <file>` or the appropriate variant from the strategy that succeeded above).

## Step 3 — Apply seven review lenses

Read `skills/review-code/references/code-review-lenses.md`. Apply all seven lenses to the changed files:

1. Plan Compliance
2. Correctness
3. Security
4. Conventions
5. Edge Cases
6. Test Quality
7. Code Quality

Walk every lens even when it produces no findings — absence of findings is itself a signal.

## Step 4 — Produce findings

Every finding must carry all seven fields:

| Field | Content |
|-------|---------|
| **Severity** | Blocker / Major / Minor / Nit |
| **Lens** | Which of the seven lenses raised this |
| **File** | path:lines |
| **Observation** | What is wrong or missing |
| **Suggested fix** | Concrete code or text the executor can apply verbatim |
| **Rationale** | One or two sentences explaining why this matters |
| **Effort** | Low / Medium / High |

Severity definitions:

- **Blocker** — executing this as-is would directly cause an incident or a silent non-functional feature. If a competent reviewer would accept the code with a written-down fix, prefer Major.
- **Major** — significant risk or a clear gap; must be fixed before the task is considered done.
- **Minor** — improvement that makes the code materially better; can be applied on the next pass.
- **Nit** — stylistic or optional.

When in doubt between Blocker and Major, prefer Major.

## Step 5 — Build Plan compliance checklist

For each step in the plan, assign one status:
- Done — fully implemented as specified
- Missing — step was skipped with no implementation present
- Partial — step is partially implemented
- Deviated — step was implemented differently from the plan spec; note the deviation

## Step 6 — Determine verdict

Derive from severity counts:

- **Rework** — one or more Blockers present. The implementation has fundamental issues; a re-plan may be needed.
- **Fix-required** — zero Blockers, one or more Majors. Apply fixes and re-review.
- **Approve** — zero Blockers, zero Majors. Minors and Nits are acceptable.

## Step 7 — Write review file

Write to `~/.claude/projects/<slug>/code-reviews/review-{plan-id}.md`. Create the `code-reviews/` directory if it does not exist. Use the `code-review-{plan-id}.md` template from `skills/_shared/workspace-templates.md`.

## Step 8 — Return findings

Return to the caller:
- Verdict (one word)
- Review file path
- Finding counts: `Blockers: N | Majors: N | Minors: N | Nits: N`

Do NOT print the full review file content to chat.
