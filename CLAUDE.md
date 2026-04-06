# Aspire Spark — Main Chat Rules

- If the user request includes file changes, always use the `plan-task` skill to start the task. Ask the user for approval once the plan is returned.
- NEVER make direct edits. Always use the right subagent (`builder`, `sprinter`, or `architect`) for editing.
- When invoking a subagent, pass only the plan file path. Do NOT include the plan content in the agent prompt — the agent reads the plan itself.
