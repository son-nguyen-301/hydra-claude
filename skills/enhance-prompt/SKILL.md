---
name: enhance-prompt
description: "Memory-aware prompt enhancer. Reads the project's captured patterns from .claude/memory/plugin/, fills gaps, asks targeted clarifying questions, and writes an improved prompt to a markdown artifact. Invoke ONLY when the user explicitly types /enhance-prompt. NEVER invoke proactively or automatically."
---

> This skill is invoked manually with `/enhance-prompt <your prompt>`. No hooks, no auto-trigger.

**IMPORTANT: This skill is optional and user-initiated only. Do NOT invoke this skill proactively, automatically, or as part of any other workflow. It runs only when the user explicitly types `/enhance-prompt`.**

This is a **memory-aware** enhancer: its purpose is to turn hydra's captured
repo-specific patterns into concrete, context-rich prompts. It reads the project's
`.claude/memory/plugin/` memory and uses those real facts to fill the Context and
Constraints of the enhanced prompt, instead of generic placeholders.

## Step 1 — Resolve project root & load memory

Resolve the project root. If you are inside a **linked git worktree** (detectable when
`git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`), the project
root is the **main worktree** — the first entry of `git worktree list --porcelain` — so
memory is read from and written to the main repo rather than the worktree. Otherwise,
it is the nearest ancestor of the current working directory that contains a `.git/`
directory (preferred) or a `.claude/` directory (fallback); use `pwd` and walk up until
you find one, and if you reach `/` without finding either marker, use `pwd`.

Read `<project-root>/.claude/memory/plugin/MEMORY.md` if it exists. Using the
one-line scope summaries in the index, select 1–3 topic files whose scope matches the
prompt's domain and read them. These captured facts (conventions, constraints,
corrections) are the source for the Context and Constraints dimensions below.

If `MEMORY.md` does not exist, note that no memory is available and proceed with
memory-free behavior (the enhancement still works; it just can't cite repo facts).

Q&A entries (`type: qa`) in those topic files are also captured facts — use fresh ones to fill Context and Constraints. Skip any entry whose `status:` is `superseded` or `needs-reconfirm`, and do not treat a stale answer as authoritative.

## Step 2 — Load best practices

Read `skills/enhance-prompt/references/best-practices.md` to load the full checklist
used during analysis.

## Step 3 — Classify the prompt

Determine whether the prompt should be enhanced or skipped.

**SKIP if any of the following apply:**
- The prompt is a single word or a brief acknowledgment (e.g., "ok", "yes", "done", "thanks").
- The prompt already contains XML tags (`<context>`, `<task>`, `<requirements>`, `<constraints>`, or similar structural tags).
- The prompt already has numbered steps, explicit acceptance criteria, and clearly stated constraints.
- The prompt is too vague to meaningfully improve (no discernible task intent).

**ENHANCE if the prompt is:**
- A task request, feature description, bug report, refactor request, or other instruction.
- Missing one or more of: clear outcome, background context, constraints, acceptance criteria, verification steps, or structural clarity.

If SKIP: output a brief message explaining why no enhancement is needed (e.g., "This prompt is already well-structured — it has explicit acceptance criteria, constraints, and numbered steps. No enhancement needed."). Stop here.

## Step 4 — Gap analysis

For each of the seven dimensions below, tag it as exactly one of: **filled-from-memory**
(a captured repo pattern supplies it), **present** (already in the user's prompt),
**missing-needs-user** (material and not derivable from memory), or
**intentionally-omitted** (the user clearly left it out on purpose — do not force it).

| Dimension | Question to answer |
|-----------|-------------------|
| Clarity | Is the desired outcome specific and unambiguous? |
| Context | Does the prompt provide relevant background (module, layer, what already exists)? |
| Constraints | Are boundaries stated (what not to change, performance limits, compatibility)? |
| Acceptance criteria | How will success be measured? Are there concrete pass/fail conditions? |
| Structure | Would XML tags, numbered steps, or examples improve readability? |
| Verification | Are there steps to validate or test the result? |
| Scope | Is the task scoped appropriately, or should it be broken into smaller steps? |

Do not add elements the user clearly left out intentionally (e.g., do not add formal acceptance criteria to a casual one-liner where informality is the point).

## Step 5 — Ask, then rewrite

Take the 1–3 **missing-needs-user** gaps with the highest impact and ask the user
about them using the `AskUserQuestion` tool (multiple-choice options where possible).
If there are no **missing-needs-user** gaps, skip questions entirely and go straight
to Step 6. Do not ask about gaps you already filled from memory.

## Step 6 — Produce the enhanced prompt

Rewrite the prompt incorporating the missing elements identified in Steps 4–5. Follow these rules:

- Preserve the user's intent and voice.
- Use XML tags (`<context>`, `<task>`, `<requirements>`, `<constraints>`, `<acceptance-criteria>`, `<verification>`) where they add clarity — do not force them on simple prompts.
- Use numbered steps for procedural sequences.
- Weave in the real context from memory and the user's answers.
- Keep the enhanced prompt focused; do not pad with generic boilerplate.

## Step 7 — Write the artifact

1. Compute a timestamp: run `date +%Y-%m-%d-%H%M%S`.
2. Derive a short kebab-case slug (2–4 words) from the prompt's intent.
3. Ensure the output directory exists: `mkdir -p <project-root>/.claude/enhanced-prompts`.
4. Write the artifact to
   `<project-root>/.claude/enhanced-prompts/<timestamp>-<slug>.md` with this structure:

   ````markdown
   # Enhanced prompt — <slug>

   ## Enhanced prompt

   ```
   <the enhanced prompt, ready to copy>
   ```

   ## What was improved
   - <bullet per gap filled, e.g. "Added context: which module/layer is affected">

   ## Memory used
   - <topic category that informed the context>, or "No project memory was available."
   ````

## Step 8 — Present & confirm

Report the **absolute path** of the written artifact prominently so the user can open
it easily. Then present the "What was improved" summary inline and ask:

**Use this enhanced prompt? (yes / no / edit)**

- **yes**: confirm the user can copy the artifact's enhanced-prompt block and use it as their next message.
- **no**: confirm you are discarding it and continuing with the original prompt. (Leave the artifact file in place.)
- **edit**: apply the user's requested changes, rewrite the artifact file in place at the same path, and re-present.
