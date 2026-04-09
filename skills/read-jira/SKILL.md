---
name: read-jira
description: "This skill should be used when the user provides a Jira ticket URL and needs its content fetched."
---

Extract the issue key from the provided URL. Call the `getJiraIssue` Atlassian MCP tool with the issue key. Return all issue content.

If MCP tools are unavailable, return a clear failure message.
