---
name: learn
description: "Capture repo-specific patterns, corrections, and conventions from the current session into categorized memory topic files. Invoke when the user says 'learn from this', 'save patterns', 'remember this convention', 'save this for next time', or proactively at session end when significant patterns were discovered during the conversation."
---

> Workspace path, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace-core.md` and `skills/_shared/workspace-templates.md`. Read both files first.

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
Read `~/.claude/projects/<slug>/memory/MEMORY.md` if it exists. This is the list of all existing categories with their scope summaries. If MEMORY.md does not exist, note this — all patterns will create new categories.

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
2. Write the new topic file with a YAML frontmatter scope block:
   - `scope`: 1-2 sentences describing what belongs. Write it broadly enough to capture related future patterns, but specific enough to be useful for routing.
   - `not`: 1 sentence describing what does NOT belong. Think about adjacent categories that might cause confusion.
   - `anchors`: use the current pattern's title as the first anchor. Leave room for 1-2 more.
3. Add the new file to MEMORY.md index: `- [Category name](filename.md) — {scope summary}`

**Step 6 — Write pattern to topic file**
Read the target topic file. When reading a topic file that has a YAML frontmatter block (delimited by opening and closing `---` lines at the top of the file), skip the frontmatter when scanning for existing `## heading` entries. The frontmatter ends at the second `---` line. All entry separators within the body use `---` as before but are distinguished by position (they appear between `## heading` blocks, not at the top of the file).

If the target topic file does not have a YAML frontmatter block (legacy file from before this change), add one. Infer the `scope` and `not` fields from the existing entries in the file. Use the first 2-3 entry headings as initial anchors. This one-time upgrade happens transparently on first write.

Apply dedup and conflict resolution:
- **Duplicate** (same heading, semantically equivalent): skip or merge `**Why:**` lines.
- **Conflict** (same heading, contradictory content): overwrite in-place with `<!-- Replaced: ... -->` comment.
- **New** (no heading match): append to file.

After writing, check if the new entry is more representative of the category than existing anchors. If so, update the anchors list in the YAML frontmatter (keep max 3 anchors).

**Step 7 — Update MEMORY.md index**
If a new category was created, the index was already updated in Step 5. If an existing category's scope description no longer accurately reflects its contents (e.g., the category has evolved), update the one-line description in MEMORY.md.

**Step 8 — Proliferation control**
If the number of categories in MEMORY.md exceeds 15, warn the user and suggest merging the two most similar categories. Do not auto-merge — present the candidates and let the user decide. If the user declines the merge, proceed normally. The warning is advisory only — the system functions correctly with any number of categories. The threshold exists to encourage periodic housekeeping, not to enforce a hard limit.

**Step 9 — Length budget check**
Each topic file max ~100 lines. MEMORY.md max 200 lines. Warn if exceeded.

Confirm that the relevant `~/.claude/projects/<slug>/memory/` topic files have been updated and summarize what was added to each file.
