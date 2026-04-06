---
name: read-jira
description: Use this skill when you need to gather information from a Jira ticket.
---

## Input

A Jira ticket URL.

## Output

All information from the Jira ticket, or a failure message if MCP server tools are unavailable.

## How It Works

Use the Atlassian Rovo MCP server tools to fetch the Jira issue. Extract the issue key from the URL and call `getJiraIssue`. If the MCP server tools are not available, return a clear failure message to the user.
