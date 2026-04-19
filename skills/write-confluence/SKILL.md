---
name: write-confluence
description: "This skill should be used when the user wants to write or update a Confluence page. Trigger when producing docs destined for Confluence, when the user says 'publish to Confluence', 'update the wiki', or when doc-writer routes output to a Confluence target."
---

## Procedure

**Step 1 — Determine create vs update**
If a page identifier (ID, URL, or title + space) was provided, call `getConfluencePage` first to check if the page exists.
- If found: proceed to update (Step 2a).
- If not found: proceed to create (Step 2b).

**Step 2a — Update existing page**
Call `updateConfluencePage` with the page ID and version set to the current version + 1 (from the `getConfluencePage` response). Pass the content in Confluence storage format (XHTML).

If a version conflict occurs (409), re-read the page with `getConfluencePage`, re-merge the content, and retry once. If the retry also fails, report the conflict to the user.

**Step 2b — Create new page**
Call `createConfluencePage` with the space key, title, and content in Confluence storage format (XHTML).

**Step 3 — Content format**
Content must be in Confluence storage format (XHTML). If the input is Markdown, convert it to storage format before sending. Key conversions: headings to `<h1>`--`<h6>`, lists to `<ul>`/`<ol>`, code blocks to `<ac:structured-macro ac:name="code">`.

Return status `done` on success with the page URL, or `failed` with explanation if MCP tools are unavailable. Do NOT return the written content.
