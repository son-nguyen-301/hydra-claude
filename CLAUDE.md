# Hydra Claude — Memory rules

- When you discover a repo-specific pattern, receive a user correction, or validate a non-obvious workflow, write it to the appropriate `.claude/memory/plugin/` topic file (relative to the project root).
- Read `.claude/memory/plugin/MEMORY.md` first to see existing categories before creating new ones.
- At session end, the `/hydra-claude:learn` skill runs automatically to capture patterns from the conversation. You can also invoke it manually with `/hydra-claude:learn`.

The project root is the nearest ancestor of the current working directory containing a `.git/` directory or a `.claude/` directory. If neither marker is found, the project root is the current working directory.

## Auto-write triggers

When any of these fire mid-conversation, invoke `/hydra-claude:learn` IMMEDIATELY in focused mode. Do not wait for session end; do not batch.

1. **Explicit save request** — user says "remember this", "save this", "learn this", "save for next time", or any direct request to capture the moment.
2. **User correction** — user tells you to stop doing X, not do X, or to use Y instead of X. Capturing immediately prevents you from repeating the corrected behavior in later turns of the same session.
3. **User directive** — user states "always X", "never X", "from now on X", or declares a fixed convention.
4. **Validated non-obvious approach** — user confirms a non-obvious judgment call you made with an affirmation that specifically endorses the choice ("yes exactly", "perfect, that's the right call"). Distinguish from casual approval ("looks good", "ok", "thanks") which is NOT a trigger. Only fire when the choice was genuinely non-obvious AND the user's affirmation directly endorses it.

For each trigger, derive ONE pattern title and ONE rationale paragraph, then invoke learn with:

```
/hydra-claude:learn

PATTERN: <one-line pattern title>
WHY: <one or two sentences explaining why this matters>
```

One trigger fire = one learn invocation. Do not batch multiple patterns into one invocation. Session-end learn will catch anything you missed.
