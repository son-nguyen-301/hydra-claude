---
name: enhance-prompt
description: "User-triggered prompt enhancer. Invoke ONLY when the user explicitly types /enhance-prompt. NEVER invoke proactively or automatically — this is an optional tool the user chooses to use."
---

> This skill is invoked manually with `/enhance-prompt <your prompt>`. No hooks, no auto-trigger.

**IMPORTANT: This skill is optional and user-initiated only. Do NOT invoke this skill proactively, automatically, or as part of any other workflow (plan-task, split-plan, etc.). It runs only when the user explicitly types `/enhance-prompt`.**

## Step 1 — Load best practices

Read `skills/enhance-prompt/references/best-practices.md` to load the full checklist used during analysis.

## Step 2 — Classify the prompt

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

## Step 3 — Analyze gaps

For each of the seven dimensions below, note whether it is present, partial, or absent in the original prompt:

| Dimension | Question to answer |
|-----------|-------------------|
| Clarity | Is the desired outcome specific and unambiguous? |
| Context | Does the prompt provide relevant background (module, layer, what already exists)? |
| Constraints | Are boundaries stated (what not to change, performance limits, compatibility)? |
| Acceptance criteria | How will success be measured? Are there concrete pass/fail conditions? |
| Structure | Would XML tags, numbered steps, or examples improve readability? |
| Verification | Are there steps to validate or test the result? |
| Scope | Is the task scoped appropriately, or should it be broken into smaller steps? |

Only fill in gaps that are genuinely missing. Do not add elements the user clearly left out intentionally (e.g., do not add formal acceptance criteria to a casual one-liner where informality is the point).

## Step 4 — Produce the enhanced prompt

Rewrite the prompt incorporating the missing elements identified in Step 3. Follow these rules:

- Preserve the user's intent and voice.
- Use XML tags (`<context>`, `<task>`, `<requirements>`, `<constraints>`, `<acceptance-criteria>`, `<verification>`) where they add clarity — do not force them on simple prompts.
- Use numbered steps for procedural sequences.
- Keep the enhanced prompt focused; do not pad with generic boilerplate.
- Do not add elements not warranted by the gap analysis.

## Step 5 — Output

Present the result in this format:

**What was improved** (bullet list of gaps filled, e.g.):
- Added context: which module/layer is affected
- Added constraints: what should not be changed
- Added acceptance criteria: definition of done
- Added verification: how to confirm the fix works

**Enhanced prompt:**

```
<paste the enhanced prompt here>
```

Then ask: **Use this enhanced prompt? (yes / no / edit)**

- If the user says **yes**: confirm they can copy it and use it as their next message.
- If the user says **no**: discard and confirm you are continuing with the original.
- If the user says **edit**: present the enhanced prompt in an editable block and apply their requested changes.
