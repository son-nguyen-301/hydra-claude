---
name: review-plan
description: "Review methodology tool that applies five plan review lenses (Staff Engineer, Tech Lead, SRE, Security, QA). Accepts a plan path, produces structured findings, and writes a review file. Used internally by the plan-reviewer agent."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

## Step 0 — Precondition

Compute `<slug>` from CWD (every `/` replaced by `-`). Attempt to read `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. If it exists, use it throughout the review to check convention alignment. If it does not exist, note this in the review summary and suggest `explore-codebase`, but continue — the review proceeds without it.

## Step 1 — Load the plan

Invoke the `read-plan` skill with the plan ID or path provided by the user. Use the returned content verbatim. Do not guess paths or reconstruct the plan from memory.

## Step 2 — Apply the five review lenses

Walk all five lenses even when some produce no findings — absence is itself a signal that the plan is clean on that axis. Record coverage for each lens in the final file.

Full checklists and worked examples for each lens are in `skills/review-plan/references/review-lenses.md`. Read that file before producing findings.

Lens overview:

1. **Staff Engineer** — architecture, abstractions, coupling, reuse vs. new code, versioning, backward compatibility, blast radius, idempotency, concurrency, state shape.
2. **Tech Lead** — requirements fidelity, scope sizing, agent-tier fit (sprinter / builder / architect), convention alignment with `codebase-knowledge.md`, file-touch completeness, delivery risk, "done" definition clarity.
3. **SRE** — logs/metrics/traces added or removed, feature flags, config / env vars, rollout / rollback path, on-call impact, rate limits, retries, timeouts, graceful degradation.
4. **Security** — authn/authz on new surfaces, input validation, output encoding, injection surfaces, secrets handling, PII exposure, audit logging, least privilege.
5. **QA** — unit / integration / e2e strategy, coverage for new code paths, edge cases, failure injection, regression risk, test data strategy.

## Step 3 — Produce findings

Every finding must carry all six fields:

| Field | Content |
|-------|---------|
| **Severity** | Blocker / Major / Minor / Nit |
| **Lens** | Which of the five lenses raised this |
| **Location** | Plan section heading or line reference |
| **Observation** | What is wrong or missing |
| **Suggested rewrite** | Mandatory — concrete replacement text the orchestrator can apply verbatim |
| **Rationale** | One or two sentences explaining why this matters; helps the orchestrator weigh edge cases |

Severity definitions:

- **Blocker** — executing this plan as written would directly cause an incident: a security breach, data loss or corruption, a broken production path with no rollback, or a correctness violation that cannot be caught after-the-fact. If a competent reviewer would accept the plan with just a written-down fix, it is NOT a Blocker.
- **Major** — significant risk or a clear gap in rigor (missing tests, missing rollback plan, missing observability, unclear rounding/concurrency semantics, wrong agent tier). The plan can and should ship after the rewrite is applied, but shipping it as-is is a bad idea.
- **Minor** — improvement that makes the plan or resulting code materially better; can be folded in during execution without re-review.
- **Nit** — stylistic, optional, or purely taste-level.

*Calibration:* when in doubt between Blocker and Major, prefer Major. A Blocker is a veto; a Major is a required rewrite. Missing-tests, missing-rollback, and missing-observability are Majors by default — they become Blockers only when the nature of the change means you cannot add them after the fact (e.g., a one-shot data migration that deletes rows).

**Verdict selection** — derive the verdict from the severity of findings, not from gut feel:

- **Revise** — at least one Blocker finding is present. The plan cannot be safely executed even with rewrites applied within the same plan file; a re-plan is required.
- **Approve-with-changes** — zero Blockers, one or more Majors. The plan should ship after the suggested rewrites are applied to the plan file. The orchestrator either applies the rewrites and re-invokes `review-plan` for a sanity check, or folds the rewrites directly into the delegation prompt.
- **Approve** — zero Blockers, zero Majors. Minors and Nits are acceptable as-is; the orchestrator delegates immediately, optionally folding the Minors/Nits into the task summary for the executor agent.

Count findings, not sentiment: two Majors is *still* Approve-with-changes, not Revise. If a reviewer feels the situation is worse than the severity counts suggest, promote one of the findings to Blocker with a rationale — don't bump the verdict without a corresponding severity.

## Step 4 — Write the review file

Determine the plan ID from the filename (e.g., `plan-042.md` → `042`). Write the review to `~/.claude/projects/<slug>/plan-reviews/review-{plan-id}.md`. Create the `plan-reviews/` directory if it does not exist.

Use this template verbatim — fill in every section; omit a severity section only when it has zero findings:

```markdown
# Plan Review {plan-id}

## Metadata
- Plan: ~/.claude/projects/<slug>/plans/plan-{plan-id}.md
- Reviewed-at: {ISO8601}
- Reviewer lenses: Staff Engineer, Tech Lead, SRE, Security, QA

## Verdict
One of: **Approve | Approve-with-changes | Revise**

## Summary
(2–5 sentences: overall assessment and top risks.)

## Findings

### Blockers
(Omit section if none. Each finding: Lens • Location • Observation • Suggested rewrite • Rationale.)

### Major
...

### Minor
...

### Nit
...

## Lens coverage
Brief note per lens (even when no findings) so the orchestrator can see what was checked.

## Recommended next step
Either: "Apply the rewrites above to plan-{plan-id}.md, then re-invoke review-plan" OR "Proceed to delegate to {agent}".
```

## Step 5 — Return findings

Return to the caller:
- Verdict (one word)
- Review file path
- Finding counts: `Blockers: N | Majors: N | Minors: N | Nits: N`

Do NOT print the full review file content to chat.
