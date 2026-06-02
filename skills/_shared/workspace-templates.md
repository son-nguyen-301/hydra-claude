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

## Archive layout

Superseded and confirmed-stale entries are moved out of the live topic file into `<project-root>/.claude/memory/plugin/archive/{original-filename}`. Archived entries are **never injected at session start and never read during check-before-ask lookups** — they exist only for audit/history. Live topic files hold only `status: active` entries.
