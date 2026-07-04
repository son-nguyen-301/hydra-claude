# Shared Reference — Memory output templates

This file contains the output templates the `learn` skill uses when writing project-local memory. Memory lives at `<project-root>/.claude/memory/plugin/` (see `workspace-core.md`).

---

## MEMORY.md index template

```markdown
# Memory Index

- [{Category name}]({filename}.md) — {scope summary from the file's scope field}
```

Each line points to a topic file. The description after `—` is the scope summary used by the learn skill to route new patterns. Categories are not predefined — they emerge dynamically based on project content.

---

## Topic file template

```markdown
---
scope: "{1-2 sentence description of what belongs in this file}"
not: "{What does NOT belong — prevents the category from becoming a dumping ground}"
anchors:
  - "{Example entry title 1 — representative of this category}"
  - "{Example entry title 2}"
---

## {Rule title}

{Description of the pattern or convention.}

**Why:** {Explanation of why this matters, with context.}

---
```

Note on `---` delimiters: The YAML frontmatter is delimited by the first two `---` lines at the top of the file. The `---` lines between entries (separating `## heading` blocks) are entry separators and are distinguished by position — they appear between entries, not at the top of the file.

---

## Q&A entry template (`type: qa`)

A Q&A entry is an ordinary topic-file entry that also carries a question and a freshness contract. The `## heading` is the **normalized question**. These fields sit directly under the heading, before the `**Why:**` line:

```markdown
## {Normalized question}
type: qa
answer: {short answer}
anchor: {comma-separated files/config the answer depends on; omit for preferences}
captured: {YYYY-MM-DD}
status: active            # active | superseded | needs-reconfirm
freshness: {window}       # 365d preference · 90d fact · 180d decision

**Why:** {why this answer holds, with context}

---
```

Plain pattern entries carry none of these fields and are unchanged. Routing, dedup, and conflict resolution treat a Q&A heading the same as any other entry heading.

---

## Archive layout

Superseded and confirmed-stale entries are moved out of the live topic file into `<project-root>/.claude/memory/plugin/archive/{original-filename}`. Archived entries are **never injected at session start and never read during check-before-ask lookups** — they exist only for audit/history. Live topic files hold only `status: active` entries.

---

## Trigger metadata (`triggers:` frontmatter block)

Topic files MAY carry a `triggers:` block in their YAML frontmatter. It is machine-read by `scripts/build-triggers-index.sh`; keep the exact indentation shown (2 spaces for the kind keys, 4 spaces + `- ` for items, values in double quotes):

```yaml
---
scope: "..."
not: "..."
anchors:
  - "..."
triggers:
  paths:
    - "hooks/*.sh"
    - "tests/**/*.bats"
  commands:
    - "git (push|worktree)"
    - "rm -rf"
  keywords:
    - "hook"
    - "session-end"
---
```

- `paths` — bash-glob patterns matched against Edit/Write file paths (relative to project root; `*` crosses `/`) and used verbatim as `paths:` in compiled rules.
- `commands` — POSIX EREs matched against Bash tool commands. Write character ranges as [A-Za-z]-style classes, not POSIX names like [[:upper:]] — command patterns are matched caselessly by lowercasing both sides, which POSIX class names bypass.
- `keywords` — lowercase substrings matched against the user prompt.

All three lists are optional. Files without `triggers:` are simply not matched at decision time (voluntary recall still applies).

## Entry `class:` marker

An optional line directly under an entry's `## ` heading (same position as `type: qa`):

```markdown
## Never force-push to shared branches
class: correction
```

Valid `class:` values: `correction`, `directive`, `pattern`, `preference` — one value per entry (absent = `pattern`). `correction` and `directive` entries participate in the PreToolUse deny-once gate; the learn skill assigns the class from the capture trigger (user correction → `correction`, "always/never X" → `directive`, validated approach → `pattern`, Q&A preference → `preference`).

## Machine index — `triggers.tsv`

`<memory-dir>/triggers.tsv` is regenerated in full by `scripts/build-triggers-index.sh` on every learn/seed write. One row per trigger pattern, four tab-separated columns:

```
<topic-filename>	<kind>	<pattern>	<max-class>
```

where `kind` is one of `path|command|keyword` and `max-class` is the highest entry class in the file (`correction` > `directive` > `pattern`; default `pattern`). Hooks read ONLY this file for matching — never the YAML. `MEMORY.md` and `archive/` are never indexed.

## Compiled rules — `.claude/rules/hydra/<topic>.md`

`scripts/compile-rules.sh` compiles every topic file that has `triggers.paths` into a native Claude Code path-scoped rule at `<project-root>/.claude/rules/hydra/<topic>.md`:

```markdown
---
paths:
  - "hooks/*.sh"
---
<!-- GENERATED BY hydra-claude from .claude/memory/plugin/<topic>.md — edit that file, not this one. -->

...entry content...
```

Rules are build artifacts: regenerated on every write, removed when their topic file no longer has path triggers. If a topic exceeds the ~100-line budget, only `correction`/`directive` entries are compiled plus a pointer to the full topic file.
