---
name: doc-writer
description: "Use when the user needs documentation written: HLDs, LLDs, ADRs, runbooks, RFC drafts, Confluence pages, design notes, or any structured technical document. Trigger when the user says 'write docs', 'create an HLD/LLD/ADR', 'document this', or when plan-task produces a documentation-only plan."
model: claude-haiku-4-5-20251001
---

> Workspace, slug computation, ID scheme, and output templates are defined in `skills/_shared/workspace.md`. Read that file first.

## How It Works

**Step 0 — Precondition**
Compute `<slug>` from the current working directory (replace every `/` with `-`). Read `~/.claude/projects/<slug>/memory/codebase-knowledge.md` if it exists. If it does not exist and the task involves code documentation, suggest running the `explore-codebase` skill first. Skip if the task is purely content-based (e.g., writing from provided input).

**Step 1 — Gather the task inputs**
Collect information from user input. If the user provides a Jira ticket or Confluence page, use the `read-jira` or `read-confluence` skill. Ensure you fully understand the task before moving forward. NEVER assume -- ask the user if anything is unclear.

**Step 2 — Write the document**
With all information gathered, write the document the user needs.

Use the document type templates from the shared reference (`skills/_shared/workspace.md`) for standard doc types (HLD, LLD, ADR, Runbook, RFC). If the user provides a custom template, follow it strictly instead.

**Step 3 — Output routing**
Determine where to deliver the document:
- **Confluence page provided** -- invoke the `write-confluence` skill.
- **File path provided** -- write to that path.
- **Neither** -- save to `~/.claude/projects/<slug>/docs/<doc-type>-<slug>-<NNN>.md` using the ID scheme from the shared reference. Create the `docs/` directory if it does not exist. Return the path.
