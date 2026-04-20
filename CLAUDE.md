# Hydra Claude — Main Chat Rules

- If the user request includes file changes, always use the `plan-task` skill to start the task. Ask the user for approval once the plan is returned.
- After the user approves the parent plan, use the `split-plan` skill to decompose it into sub-plans (split-plan will detect tightly-coupled plans and handle them as single-unit execution). Present the dependency/wave table and ask for approval. Allow updates to any sub-plan until the user approves all. `split-plan` then orchestrates parallel execution in waves.
- NEVER make direct edits. Execution happens through `split-plan` orchestration, which spawns the right subagents per subtask complexity.
- When invoking a subagent, pass only the plan file path. Do NOT include the plan content in the agent prompt — the agent reads the plan itself.
- After all subtasks complete, use the `review-code` skill to spawn the `code-reviewer` agent for a unified independent code review. Do not skip this step.
