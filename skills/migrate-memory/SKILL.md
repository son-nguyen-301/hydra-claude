---
name: migrate-memory
description: "Legacy migration tool for v2.8→v2.9 upgrades. Migrates a project's learned.md into the MEMORY.md index + categorized topic files structure. Most users do not need this."
---

> Workspace path, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace-core.md` and `skills/_shared/workspace-templates.md`. Read both files first.

## Step 0 — Create memory/plugin/ directory

Create the `memory/plugin/` directory if it doesn't exist:
```bash
mkdir -p ~/.claude/projects/<slug>/memory/plugin/
```

## Step 1 — Compute workspace path

Reference `skills/_shared/workspace-core.md` for slug computation. Compute `<slug>` from CWD. Set `MEMORY_DIR=~/.claude/projects/<slug>/memory/plugin/`.

## Step 2 — Pre-flight checks

- Read `~/.claude/projects/<slug>/memory/learned.md` (root level). If it doesn't exist, inform the user: "No learned.md found at {path} — nothing to migrate." and stop.
- Check if `$MEMORY_DIR/MEMORY.md` (i.e., `memory/plugin/MEMORY.md`) already exists. If yes, warn the user: "MEMORY.md already exists. This will overwrite existing topic files for categories found in learned.md." Ask whether to proceed or abort.
- Check if `~/.claude/projects/<slug>/memory/learned.md.bak` already exists. If yes, warn: "learned.md.bak already exists from a previous migration. Remove it to proceed." Ask whether to delete it and continue, or abort.

## Step 3 — Parse entries

Read `learned.md`. Parse each `## heading` + body block (up to next `---` separator or next `## ` heading) as a pattern entry. Collect an array of (heading, body) pairs.

## Step 4 — Semantically categorize entries

For each parsed entry from learned.md:

1. Read the current MEMORY.md index (starts empty for the first entry, grows as categories are created during this migration).
2. Decide if the entry fits an existing category's scope description by matching against the one-line descriptions in the MEMORY.md index.
3. If the match is ambiguous, read the full YAML frontmatter scope block (`scope`, `not`, `anchors`) of at most 3 candidate topic files to disambiguate — pay particular attention to the `not` clause to rule out false positives.
4. If no existing category fits, create a new topic file using the topic file template from `skills/_shared/workspace-templates.md`. The new file must have a YAML frontmatter block at the top with:
   - `scope`: a 1-2 sentence description of what belongs in this file.
   - `not`: what does NOT belong (prevents category drift).
   - `anchors`: 2-3 representative example entry titles.
   Add the new category to the MEMORY.md index immediately so subsequent entries can be routed to it.
5. Assign the entry to the chosen category.
6. Log the decision: `"heading" → filename (reason: one-line justification)`

When reading existing topic files to check for duplicate `## heading` entries, skip the YAML frontmatter block (the first `---`...`---` section at the top of the file) — scan only the entry content below it.

## Step 5 — Write topic files

For each category that has entries, write a topic file to `$MEMORY_DIR/{filename}`. Always include the YAML frontmatter scope block at the top, even when source entries predate this format. Use the topic file template from `skills/_shared/workspace-templates.md`. Format entries separated by `---`, each as `## heading` + body.

If the topic file already exists (re-migration scenario), overwrite it with the entries from learned.md for that category, preserving the YAML frontmatter scope block.

## Step 6 — Generate MEMORY.md index

Write `$MEMORY_DIR/MEMORY.md` with header `# Memory Index` followed by one line per topic file that has entries. Use the `scope` field from each file's YAML frontmatter as the description:

```
- [Category name](filename.md) — {scope summary}
```

Reference the MEMORY.md index template from `skills/_shared/workspace-templates.md`.

## Step 7 — Backup original

Rename `~/.claude/projects/<slug>/memory/learned.md` to `~/.claude/projects/<slug>/memory/learned.md.bak` using Bash `mv`.

## Step 8 — Report summary

Print a summary to the user:
- Total entries migrated
- Topic files created with entry counts
- Path to MEMORY.md
- Reminder: "The inject-learned hook will now load memory/plugin/MEMORY.md instead of learned.md."
