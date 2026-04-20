---
name: write-confluence
description: "Write or update Confluence pages. Invoke when the user says 'publish to Confluence', 'update the wiki', 'create a wiki page', when producing docs destined for Confluence, or when doc-writer routes output to a Confluence target. Handles create, update, version conflicts, and Markdown-to-Confluence-XHTML conversion."
---

## Procedure

**Step 1 — Determine create vs update**
If a page identifier was provided, resolve it to a numeric page ID first:
- Numeric ID: use as-is.
- Confluence URL: extract the page ID from the URL path (see `read-confluence` skill for URL shapes).
- Title + space key: call `searchConfluence` with the title and space to locate the page ID.

Then call `getConfluencePage` with the resolved page ID to check if the page exists.
- If found: proceed to update (Step 2a).
- If not found or no identifier was provided: proceed to create (Step 2b).

**Step 2a — Update existing page**
Call `updateConfluencePage` with the page ID and version set to the current version + 1 (from the `getConfluencePage` response). Pass the content in Confluence storage format (XHTML).

If a version conflict occurs (409), re-read the page with `getConfluencePage`, re-merge the content, and retry once. If the retry also fails, report the conflict to the user.

**Step 2b — Create new page**
Call `createConfluencePage` with the space key, title, and content in Confluence storage format (XHTML).

**Step 3 — Content format**
Content must be in Confluence storage format (XHTML). If the input is Markdown, convert it to storage format before sending using the conversion reference below.

## Conversion reference (Markdown → Confluence storage format)

| Markdown | Confluence XHTML |
|---|---|
| `# Heading` | `<h1>Heading</h1>` |
| `## Heading` | `<h2>Heading</h2>` |
| `- item` | `<ul><li>item</li></ul>` |
| `1. item` | `<ol><li>item</li></ol>` |
| `**bold**` | `<strong>bold</strong>` |
| `*italic*` | `<em>italic</em>` |
| `` `code` `` | `<code>code</code>` |
| Code block (```lang) | `<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">lang</ac:parameter><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>` |
| `\| table \|` | `<table><tbody><tr><td>table</td></tr></tbody></table>` |
| `> blockquote` | `<blockquote><p>...</p></blockquote>` |
| `![alt](url)` | `<ac:image><ri:url ri:value="url"/></ac:image>` |
| Info panel | `<ac:structured-macro ac:name="info"><ac:rich-text-body><p>...</p></ac:rich-text-body></ac:structured-macro>` |
| Warning panel | `<ac:structured-macro ac:name="warning"><ac:rich-text-body><p>...</p></ac:rich-text-body></ac:structured-macro>` |
| `[text](url)` | `<a href="url">text</a>` |
| `@mention` | `<ac:link><ri:user ri:account-id="..."/></ac:link>` (requires lookupJiraAccountId) |

Return status `done` on success with the page URL, or `failed` with explanation if MCP tools are unavailable. Do NOT return the written content.
