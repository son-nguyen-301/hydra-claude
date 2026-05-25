# Hydra Claude — Memory rules

- When you discover a repo-specific pattern, receive a user correction, or validate a non-obvious workflow, write it to the appropriate `.claude/memory/plugin/` topic file (relative to the project root).
- Read `.claude/memory/plugin/MEMORY.md` first to see existing categories before creating new ones.
- At session end, the `/hydra-claude:learn` skill runs automatically to capture patterns from the conversation. You can also invoke it manually with `/hydra-claude:learn`.

The project root is the nearest ancestor of the current working directory containing a `.git/` directory or a `.claude/` directory. If neither marker is found, the project root is the current working directory.
