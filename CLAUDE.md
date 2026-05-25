# Hydra Claude — Memory rules

- When you discover a repo-specific pattern, receive a user correction, or validate a non-obvious workflow, write it to the appropriate `~/.claude/projects/<slug>/memory/plugin/` topic file.
- Read `~/.claude/projects/<slug>/memory/plugin/MEMORY.md` first to see existing categories before creating new ones.
- At session end, the `/hydra-claude:learn` skill runs automatically to capture patterns from the conversation. You can also invoke it manually with `/hydra-claude:learn`.

`<slug>` is the project's absolute CWD path with every `/` replaced by `-` (e.g. `/Users/foo/bar` becomes `-Users-foo-bar`).
