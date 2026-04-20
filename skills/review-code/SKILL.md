---
name: review-code
description: "Use this skill to review a completed implementation through seven lenses (Plan Compliance, Correctness, Security, Conventions, Edge Cases, Test Quality, Code Quality). Invoke when the user says 'review the code', 'check the implementation', 'code review', or automatically after a subagent completes implementation."
---

> Workspace path, slug computation, and ID scheme are defined in `skills/_shared/workspace-core.md`. Read that file first.

## Step 0 — Precondition

Compute `<slug>` from CWD (every `/` replaced by `-`). Attempt to read `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. If it exists, use it throughout the review to check convention alignment. If it does not exist, note this in the review summary and suggest `explore-codebase`, but continue — the review proceeds without it.

## Step 1 — Identify what to review

Accept a plan ID or plan path from the user. If none is provided, check the most recent delegation in the conversation. If still unclear, scan `~/.claude/projects/<slug>/plans/` for the latest `plan-NNN.md` and confirm with the user before proceeding.

## Step 2 — Spawn the code-reviewer agent

Invoke the `code-reviewer` agent. Pass only the plan file path — do NOT include the plan content in the agent prompt. The agent reads the plan itself.

## Step 3 — Read and present the verdict

After the agent completes, read `~/.claude/projects/<slug>/code-reviews/review-{plan-id}.md`. Tell the user the review file path and the verdict in one sentence. Do NOT print the full review to chat — context stays clean.

## Step 4 — Gate next steps

Act on the verdict exactly as follows. This is a hard gate — do not proceed without an explicit user answer.

- **Approve** — Inform the user the task is done. The implementation passes all review lenses. Do not suggest committing or creating a PR.
- **Fix-required** — Ask the user whether to: (a) spawn the original executor agent with both the plan path and the review path to apply fixes, (b) fix manually, or (c) override and accept the implementation as-is.
- **Rework** — Ask the user whether to: (a) re-plan using `plan-task` with the review findings as additional context, or (b) escalate to the `architect` agent.
