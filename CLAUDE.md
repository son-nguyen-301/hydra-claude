# Hydra Claude — Memory rules

- When you discover a repo-specific pattern, receive a user correction, or validate a non-obvious workflow, write it to the appropriate `.claude/memory/plugin/` topic file (relative to the project root).
- Read `.claude/memory/plugin/MEMORY.md` first to see existing categories before creating new ones.
- At session end, the `/hydra-claude:learn` skill runs automatically to capture patterns from the conversation. You can also invoke it manually with `/hydra-claude:learn`.
- For a fresh project with no memory yet, invoke `/hydra-claude:seed-memory` to scan the codebase and seed initial entries.

The project root is resolved as follows. If the current working directory is inside a linked git worktree (when `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`), the project root is the main worktree — the first entry of `git worktree list --porcelain` — so memory consolidates in the main repo rather than the worktree. Otherwise, it is the nearest ancestor of the current working directory containing a `.git/` directory or a `.claude/` directory; if neither marker is found, the project root is the current working directory.

## Check before asking (Q&A reuse)

Before asking the user ANY clarifying question, check the Q&A memory first:

1. Use the injected `MEMORY.md` scope summaries to pick the 1–2 categories whose scope matches the question's domain, and read only those topic files. Do not scan the whole store. Never read `archive/`.
2. Look for a `type: qa` entry whose heading matches (exactly or is semantically equivalent to) the question. If there is none, ask the user as normal.
3. If a match exists, check freshness before reuse:
   - **Decay:** if `captured` + `freshness` is in the past, treat the answer as needs-reconfirm (add the `freshness` day count — e.g. `365d` = 365 days — to the `captured` date; if that date is before today, it is stale).
   - **Anchor:** if the entry has an `anchor`, run `git log -1 --format=%cI -- <anchor paths>`; if the anchor's last change is more recent than `captured`, treat the answer as needs-reconfirm.
4. **Reuse (fresh):** use the stored answer AND announce it explicitly — **never silent**. For example: "Reusing a saved answer — last session you said the test framework is bats. Continuing on that basis."
5. **Re-confirm (stale):** surface the answer and ask whether it still holds ("Last session you said X — still true?"). If confirmed, invoke learn in Q&A focused mode with a QA block (trigger 5 format) to refresh it. If changed, the new answer supersedes the old (trigger 5 handles the supersede/archive).

## Auto-write triggers

When any of these fire mid-conversation, invoke `/hydra-claude:learn` IMMEDIATELY in focused mode. Do not wait for session end; do not batch.

1. **Explicit save request** — user says "remember this", "save this", "learn this", "save for next time", or any direct request to capture the moment.
2. **User correction** — user tells you to stop doing X, not do X, or to use Y instead of X. Capturing immediately prevents you from repeating the corrected behavior in later turns of the same session.
3. **User directive** — user states "always X", "never X", "from now on X", or declares a fixed convention.
4. **Validated non-obvious approach** — user confirms a non-obvious judgment call you made with an affirmation that specifically endorses the choice ("yes exactly", "perfect, that's the right call"). Distinguish from casual approval ("looks good", "ok", "thanks") which is NOT a trigger. Only fire when the choice was genuinely non-obvious AND the user's affirmation directly endorses it.
5. **Clarifying answer (durable)** — you asked the user a clarifying question and got an answer reusable beyond the current task (a durable preference, project fact, or decision+rationale). Capture it; do NOT capture task-local answers (anything scoped to this PR/branch/ticket, or phrased "this time"/"for now"). When unsure, do not capture. Invoke learn in focused mode with a QA block instead of the PATTERN/WHY block:

   ```
   /hydra-claude:learn

   QA: 1
   QUESTION: <normalized question>
   ANSWER: <short answer>
   TYPE: preference | fact | decision
   ANCHOR: <comma-separated files the answer depends on, or "none">
   WHY: <one or two sentences on why this answer holds>
   ```

For each of triggers 1–4, derive ONE pattern title and ONE rationale paragraph, then invoke learn with the PATTERN/WHY block below. (Trigger 5 uses the QA block shown in its own entry, not PATTERN/WHY.)

```
/hydra-claude:learn

PATTERN: <one-line pattern title>
WHY: <one or two sentences explaining why this matters>
```

One trigger fire = one learn invocation. Do not batch multiple patterns into one invocation. Session-end learn will catch anything you missed.
