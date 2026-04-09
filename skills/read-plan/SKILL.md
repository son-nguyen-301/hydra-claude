---
name: read-plan
description: "This skill should be used when a plan file needs to be read by plan ID or path."
---

Workspace formula: `<slug>` = absolute CWD path with every `/` replaced by `-`.

- If a full path is provided, read it directly with the Read tool.
- If a plan ID is provided, compute `<slug>` and read `~/.claude/projects/<slug>/plans/plan-{id}.md`.
- If the file is not found, glob `~/.claude/projects/<slug>/plans/plan-*.md`, sort by modification time descending, return the 3–5 most recent filenames.

Return the full plan content.
