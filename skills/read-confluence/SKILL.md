---
name: read-confluence
description: "This skill should be used when the user provides a Confluence page URL and needs its content fetched."
---

Extract the page ID or tiny link ID from the provided URL. Call the `getConfluencePage` Atlassian MCP tool. Return all page content.

If MCP tools are unavailable, return a clear failure message.
