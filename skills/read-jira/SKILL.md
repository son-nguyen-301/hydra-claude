---
name: read-jira
description: "This skill should be used when the user provides a Jira ticket URL and needs its content fetched. Trigger when a Jira URL is pasted (e.g. https://org.atlassian.net/browse/PROJ-123, shortlinks), even without explicit instruction to fetch. Also invoked by plan-task when requirements reference a Jira ticket."
---

## URL shapes and key extraction

- `https://<org>.atlassian.net/browse/PROJ-123` -- extract key `PROJ-123`
- `https://<org>.atlassian.net/jira/software/projects/PROJ/boards/<N>/backlog?selectedIssue=PROJ-123` -- extract key `PROJ-123`
- Shortlink or bare key (e.g., `PROJ-123`) -- use as-is

## Procedure

**Step 1 — Fetch the issue**
Call `getJiraIssue` with the extracted issue key.

**Step 2 — Fetch comments and linked issues**
Call `getJiraIssue` or the relevant MCP tools to retrieve comments and linked issues. Do not stop at the issue body alone.

**Step 3 — Return shape**
Return all of the following fields (when present):
- Title
- Status
- Description
- Acceptance criteria
- Assignee
- Reporter
- Comments
- Linked issues (blockers, relates-to, duplicates)

If MCP tools are unavailable, return a clear failure message.
