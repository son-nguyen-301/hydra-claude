---
name: read-confluence
description: "This skill should be used when the user provides a Confluence page URL and needs its content fetched. Trigger when a Confluence URL is pasted (e.g. /wiki/spaces/SPACE/pages/ID/..., tiny links /x/id, direct page-id links), even without explicit instruction to fetch. Also invoked by plan-task when requirements reference a Confluence page."
---

## Return contract

Hold the fetched page content in context for subsequent processing. Do NOT output the page content to chat unless this skill is the top-level user request (e.g., user pasted a Confluence URL directly).

When invoked as a sub-step of another skill (e.g., plan-task), proceed immediately to the caller's next step after fetching — do NOT stop or treat this as a terminal action.

## URL shapes and ID extraction

- `https://<org>.atlassian.net/wiki/spaces/<SPACE>/pages/<ID>/<title>` -- extract page ID
- `https://<org>.atlassian.net/wiki/x/<tinyId>` -- tiny link, extract tinyId
- `https://<org>.atlassian.net/wiki/spaces/<SPACE>/pages/<ID>` -- direct page-id link
- Bare page ID (numeric) -- use as-is

## Procedure

**Step 1 — Fetch the page**
Call `getConfluencePage` with the resolved numeric page ID.

**Step 2 — Fetch child pages (when relevant)**
If the page is a parent/index page or the user needs the full section, call `getConfluencePageDescendants` to retrieve child pages. Note child page titles and IDs so the user can request specific children.

**Step 3 — Output content**
Provide the full page content (title, body, labels, version). If the page has inline or footer comments relevant to the task, include those as well using `getConfluencePageInlineComments` or `getConfluencePageFooterComments`.

If MCP tools are unavailable, report a clear failure message.
