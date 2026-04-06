---
name: write-confluence
description: Use this skill when you need to write content to a Confluence page.
---

## Input

- Confluence page URL
- The content to write

## Output

Status: `done` or `failed`. Do NOT return the written content.

## How It Works

Use the Atlassian Rovo MCP server tools (`updateConfluencePage` or `createConfluencePage`) to write the provided content to the specified Confluence page. If the MCP server tools are not available, return a `failed` status with a clear explanation.
