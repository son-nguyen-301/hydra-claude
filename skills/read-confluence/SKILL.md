---
name: read-confluence
description: Use this skill when you need to gather information from a Confluence page.
---

## Input

A Confluence page URL.

## Output

All information from the Confluence page, or a failure message if MCP server tools are unavailable.

## How It Works

Use the Atlassian Rovo MCP server tools to fetch the Confluence page. Extract the page ID or tiny link ID from the URL and call `getConfluencePage`. If the MCP server tools are not available, return a clear failure message to the user.
