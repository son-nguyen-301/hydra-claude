---
name: learn
description: "Capture repo-specific patterns, corrections, and conventions from the current session into categorized memory topic files. Invoke when the user says 'learn from this', 'save patterns', 'remember this convention', 'save this for next time', or proactively at session end when significant patterns were discovered during the conversation."
---

> Project-local memory path and output templates are defined in `skills/_shared/workspace-core.md` and `skills/_shared/workspace-templates.md`. Read both files first.

**Project root resolution.** All memory paths in this skill are relative to the project root. If you are inside a **linked git worktree** (detectable when `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`), the project root is the **main worktree** — the first entry of `git worktree list --porcelain` — so memory is written to the main repo rather than the worktree. Otherwise, the project root is the nearest ancestor of the current working directory that contains a `.git/` directory (preferred) or a `.claude/` directory (fallback); use `pwd` and walk up until you find one, and if you reach `/` without finding either marker, use `pwd`. All memory lives at `<project-root>/.claude/memory/plugin/`.

**Focused mode (mid-session capture).** If the user prompt invoking this skill contains a `PATTERN:` line and a `WHY:` line, you were invoked in focused mode. Skip Steps 1-2 entirely — do not scan the conversation. Treat the provided PATTERN as the single pattern title to save, and WHY as its rationale. Jump directly to Step 3 (Read memory index) and follow Steps 3-10 normally for that one pattern.

**Q&A focused mode.** If the invoking prompt contains a `QA:` block (a `QA:` line with `QUESTION:`, `ANSWER:`, `TYPE:`, `ANCHOR:`, and `WHY:` fields), you are in Q&A focused mode, capturing a reusable clarifying answer. (`TYPE` — one of `preference`/`fact`/`decision` — determines the entry's `freshness:` window.) Skip Steps 1-2. Before writing, apply the **durability gate**: only capture answers reusable beyond the current task. Drop anything scoped to a single PR/branch/ticket or phrased "this time"/"for now"; when unsure, do not capture and say so. If it passes the gate, use the normalized `QUESTION` as the entry heading and follow Steps 3-10, but write a **`type: qa` entry** (see the Q&A capture rules in Step 6) instead of a plain pattern.

If no `PATTERN:`/`WHY:` and no `QA:` block is present, use full-scan mode: start at Step 1 and scan the conversation.

**Step 1 — Read the conversation**
Review the current conversation for repo-specific patterns, decisions, corrections, and validated workflows.

Focus on:
- Coding conventions discovered or enforced during this session
- Architectural decisions made
- Corrections the user gave (what to do / what NOT to do)
- Workflows that were validated as correct
- File structure or naming patterns observed

**Step 2 — Filter for repo-specific patterns only**
Filter to repo-specific patterns only. Exclude generic best practices already covered by existing rules. Only save what is specific to this repository and would not be obvious from reading the code.

## Example entries

**Good** (repo-specific, actionable):
```
## Always use `setup_isolated_home` in bats tests
**Why:** Tests that write to `~/.claude/` without isolation pollute each
other's state and cause flaky failures in CI.
```

**Good** (correction from user):
```
## Never use `git add -A` in hook scripts
**Why:** User corrected this — hooks should only stage files they explicitly
created, not sweep up unrelated changes.
```

**Bad** (too generic — not repo-specific):
```
## Use descriptive variable names
**Why:** Readability.
```
This is a universal best practice. It belongs in a linter config, not a patterns file.

**Step 3 — Read memory index**
Read `<project-root>/.claude/memory/plugin/MEMORY.md` if it exists. This is the list of all existing categories with their scope summaries. If MEMORY.md does not exist, note this — all patterns will create new categories. If the `<project-root>/.claude/memory/plugin/` directory does not exist, create it (using Bash `mkdir -p <project-root>/.claude/memory/plugin/`).

**Step 4 — Route each pattern**
For each new pattern to save:
1. Read the MEMORY.md index lines. For each category, the one-line description after `—` is the scope summary.
2. Decide: does this pattern fit an existing category's scope?
   - **Clear match** → select that category.
   - **Ambiguous** (2-3 candidates seem plausible) → read the full YAML frontmatter scope block of each candidate file. Check the `not` clause and `anchors` to disambiguate. Select the best fit. Read at most 3 candidate files. If a topic file cannot be read (missing, empty, or malformed frontmatter), skip it and continue with the remaining candidates. If all candidates are unreadable, create a new category.
   - **No match** → create a new category (see Step 5).
3. When routing to an existing category, always use the existing filename as-is (e.g., `corrections.md`). The `patterns-{domain-slug}.md` naming convention applies only to newly created categories. Existing files retain their original names regardless of the naming pattern.
4. Log the routing decision: `"pattern title" → filename (reason: one-line justification)`

**Step 5 — Create new category (when needed)**
When no existing category fits a pattern:
1. Choose a descriptive filename: `patterns-{domain-slug}.md` (lowercase, hyphenated). The slug should be a concise 1-3 word domain name.
2. Write the new topic file with a YAML frontmatter scope block to `<project-root>/.claude/memory/plugin/{filename}`:
   - `scope`: 1-2 sentences describing what belongs. Write it broadly enough to capture related future patterns, but specific enough to be useful for routing.
   - `not`: 1 sentence describing what does NOT belong. Think about adjacent categories that might cause confusion.
   - `anchors`: use the current pattern's title as the first anchor. Leave room for 1-2 more.
   - `triggers`: populate the machine-matchable trigger block (see `workspace-templates.md` → "Trigger metadata"). Derive from the pattern itself: `paths` = globs for the files the pattern governs (from anchor files or paths discussed in the conversation), `commands` = EREs for shell commands it constrains, `keywords` = 2-4 lowercase topic words a future prompt about this domain would contain. Omit lists that don't apply; never invent triggers broader than the pattern's real scope (a false trigger injects noise into every matching action).
3. Add the new file to `<project-root>/.claude/memory/plugin/MEMORY.md` index: `- [Category name](filename.md) — {scope summary}`

**Step 6 — Write pattern to topic file**
Read the target topic file at `<project-root>/.claude/memory/plugin/{filename}`. When reading a topic file that has a YAML frontmatter block (delimited by opening and closing `---` lines at the top of the file), skip the frontmatter when scanning for existing `## heading` entries. The frontmatter ends at the second `---` line. All entry separators within the body use `---` as before but are distinguished by position (they appear between `## heading` blocks, not at the top of the file).

If the target topic file does not have a YAML frontmatter block (legacy file from before this change), add one. Infer the `scope` and `not` fields from the existing entries in the file. Use the first 2-3 entry headings as initial anchors. This one-time upgrade happens transparently on first write.

Apply dedup and conflict resolution:
- **Duplicate** (same heading, semantically equivalent): skip or merge `**Why:**` lines.
- **Conflict** (same heading, contradictory content): overwrite in-place with `<!-- Replaced: ... -->` comment. *(For `type: qa` entries, do NOT use this in-place overwrite — follow the Q&A contradiction-supersede rules below instead.)*
- **New** (no heading match): append to file.

**Entry class.** Directly under the entry's `## ` heading, write a `class:` line derived from what fired the capture: user correction → `class: correction`; "always/never/from now on" directive → `class: directive`; validated approach or observed convention → `class: pattern` (may be omitted — it is the default); Q&A preference → `class: preference`. `correction` and `directive` entries are enforced by the PreToolUse deny-once gate, so only use them when the user genuinely corrected or directed.

**Trigger maintenance on existing files.** When writing to a file that has a `triggers:` block, extend it if the new entry introduces new paths/commands/keywords. When writing to a file WITHOUT a `triggers:` block (legacy), backfill one as part of the same transparent in-place upgrade that adds missing frontmatter: derive triggers from ALL existing entries in the file, not just the new one.

After writing, check if the new entry is more representative of the category than existing anchors. If so, update the anchors list in the YAML frontmatter (keep max 3 anchors).

**Q&A entry write rules (`type: qa`).** *(Step 6 variant — applies only in Q&A focused mode)* When writing a Q&A entry (Q&A focused mode), build it from the QA block using the `type: qa` template in `workspace-templates.md`:

- Heading = the normalized `QUESTION`.
- `answer:` = `ANSWER`. `anchor:` = `ANCHOR` (omit the field entirely if `ANCHOR` is `none`; the omission is gated on the `ANCHOR` value, not on `TYPE` — a preference may still carry an anchor).
- `captured:` = today's date — get it by running `date +%Y-%m-%d`.
- `status: active`.
- `freshness:` from `TYPE`: **365d** for `preference`, **90d** for `fact`, **180d** for `decision`.
- `**Why:**` = `WHY`.
- Do NOT add a Q&A entry's question heading to the category `anchors` list. Anchors are reserved for representative pattern titles — skip the anchors-update (the closing sentence of Step 6) for `type: qa` entries.

**Q&A contradiction-supersede.** This overrides the generic **Conflict** rule above for `type: qa` entries. Before appending a `type: qa` entry, check the target file for an existing `type: qa` entry with the same (or semantically equivalent) question heading:

- **Same question, same answer** → edit the existing entry in-place: replace its `captured:` value with today's date (from `date +%Y-%m-%d`) and confirm `status:` reads `active`. Do NOT create a second entry.
- **Same question, different answer** → the new answer wins. Set the old entry's `status: superseded`, then **move the old entry out of the live file into `<project-root>/.claude/memory/plugin/archive/`** using the same filename as the live topic file (create `archive/` with `mkdir -p` if needed; append the entry there as-is, keeping its `status: superseded` marker). Write the new entry as `status: active` in the live file.
- **No existing match** → append the new `type: qa` entry normally.

Archived entries are never injected and never read during lookups — `archive/` is write-only from this skill's perspective.

**Step 7 — Update MEMORY.md index**
If a new category was created, the index was already updated in Step 5. If an existing category's scope description no longer accurately reflects its contents (e.g., the category has evolved), update the one-line description in `<project-root>/.claude/memory/plugin/MEMORY.md`.

**Step 8 — Proliferation control**
If the number of categories in MEMORY.md exceeds 20, warn the user and suggest merging the two most similar categories. (Q&A entries prefer routing into existing domain categories, but may create new ones — such as `preferences` or `decisions` — when none fits; the advisory was raised from 15 to 20 to accommodate this.) The category count is only a soft proxy — the **true guard** against injection bloat is the `MEMORY.md` size budget in Step 9, since `MEMORY.md` is the file actually injected at session start. Do not auto-merge — present the candidates and let the user decide. If the user declines the merge, proceed normally. The warning is advisory only — the system functions correctly with any number of categories. The threshold exists to encourage periodic housekeeping, not to enforce a hard limit.

**Step 9 — Length budget check**
Each topic file max ~100 lines. MEMORY.md max 200 lines. Warn if exceeded.

Confirm that the relevant `<project-root>/.claude/memory/plugin/` topic files have been updated and summarize what was added to each file.

**Step 10 — Regenerate machine artifacts**
After all topic-file writes are done, regenerate the trigger index and compiled rules by running both scripts (they live in the plugin's `scripts/` directory — resolve it relative to this skill's base directory, i.e. `<skill-base-dir>/../../scripts/`):

```bash
bash <plugin-root>/scripts/build-triggers-index.sh <project-root>/.claude/memory/plugin
bash <plugin-root>/scripts/compile-rules.sh <project-root>/.claude/memory/plugin <project-root>/.claude/rules
```

Run them in that order (the compiler assumes topic files are final). Both are idempotent and always safe to run. Skipping this step leaves decision-time recall degraded (the hooks no-op on a stale index), so it is NOT optional.
