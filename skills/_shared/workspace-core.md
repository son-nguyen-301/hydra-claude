# Shared Reference — Project-local memory paths

This file is the single source of truth for where plugin memory lives. The `learn` skill references this file. Do NOT duplicate these rules elsewhere.

---

## Memory path

All plugin memory for a project lives at `<project-root>/.claude/memory/plugin/`.

`<project-root>` is the nearest ancestor of the current working directory that contains a `.git/` directory (preferred) or a `.claude/` directory (fallback). If neither marker is found before reaching `/`, the project root is the current working directory itself.

Layout inside `plugin/`:

| File             | Purpose                                                          |
|------------------|------------------------------------------------------------------|
| `MEMORY.md`      | One-line index of all categories with their scope summaries.     |
| `*.md`           | Topic files: one category per file, each with YAML frontmatter.  |

The category filenames are not predefined; they emerge as the learn skill encounters new patterns. See `workspace-templates.md` for the topic-file template.

---

## Legacy home-directory path (pre-3.1.0)

Versions before 3.1.0 stored memory at `~/.claude/projects/<slug>/memory/plugin/`, where `<slug>` was the project's absolute path with `/` replaced by `-`.

On first `SessionStart` after upgrading to 3.1.0+, hydra-claude's `inject-learned.sh` hook auto-copies any existing legacy memory into the new project-local location. The migration is idempotent (won't re-run once the project-local directory exists) and non-destructive (the legacy location is left in place as a backup). Users can manually remove the legacy directory once they've verified the migration.
