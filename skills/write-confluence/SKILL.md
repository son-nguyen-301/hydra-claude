---
name: write-confluence
description: "This skill should be used when the user wants to write or update a Confluence page."
---

Call `updateConfluencePage` if the page already exists, or `createConfluencePage` for a new page. Pass the provided content and page identifier.

Return status `done` on success, or `failed` with explanation if MCP tools are unavailable. Do NOT return the written content.
