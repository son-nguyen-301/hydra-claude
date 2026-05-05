---
name: read-jira
description: "This skill should be used when the user provides a Jira ticket URL and needs its content fetched. Trigger when a Jira URL is pasted (e.g. https://org.atlassian.net/browse/PROJ-123, shortlinks), even without explicit instruction to fetch. Also invoked by plan-task when requirements reference a Jira ticket."
---

## Return contract

Hold the fetched issue content in context for subsequent processing. Do NOT output the issue content to chat unless this skill is the top-level user request (e.g., user pasted a Jira URL directly).

When invoked as a sub-step of another skill (e.g., plan-task), proceed immediately to the caller's next step after fetching — do NOT stop or treat this as a terminal action.

## URL shapes and key extraction

- `https://<org>.atlassian.net/browse/PROJ-123` -- extract key `PROJ-123`
- `https://<org>.atlassian.net/jira/software/projects/PROJ/boards/<N>/backlog?selectedIssue=PROJ-123` -- extract key `PROJ-123`
- Shortlink or bare key (e.g., `PROJ-123`) -- use as-is

## Procedure

**Step 1 — Fetch the issue**
Call `getJiraIssue` with the extracted issue key.

**Step 2 — Fetch related data**
The `getJiraIssue` response body includes comments and linked issues in the response fields. Parse them from the returned data. Additionally:
- If the issue has subtasks, note each subtask key and status.
- If the issue has a parent (epic or story), note the parent key for context.
- If linked issues include blockers, fetch the blocker's status to determine if it is resolved.

**Step 3 — Output shape**
If this skill is the top-level user request, provide all of the following fields (when present) to the user:
- Title
- Status
- Description
- Acceptance criteria
- Assignee
- Reporter
- Comments
- Subtasks (key and status)
- Parent (key)
- Linked issues (blockers, relates-to, duplicates; include blocker status/resolution when fetched)

If invoked as a sub-step, hold the content in context and proceed immediately to the caller's next step — do NOT stop or treat this as a terminal action.

If MCP tools are unavailable, report a clear failure message.
