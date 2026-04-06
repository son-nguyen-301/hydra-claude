# hydra-claude

A Claude Code plugin that enforces structured, cost-aware AI development workflows. It provides a planning-first system with specialized agents, real-time token tracking, automatic context management, and integrations with Jira and Confluence.

---

## What it does

Out of the box, Claude Code will happily edit any file on request. hydra-claude adds a disciplined layer on top:

- **Plan before touching files.** Every request that requires code changes goes through a planning step. The plan is saved and the user approves it before any edits happen.
- **Delegate to the right agent.** Three specialized agents (sprinter, builder, architect) handle execution at the appropriate complexity tier. The orchestrating Claude instance never edits directly.
- **Track tokens continuously.** A status line shows live input/output token counts and context window pressure. A hook warns before the context gets dangerously full.
- **Inject learned patterns at session start.** Repo-specific conventions are captured once and injected into every new session automatically.
- **Integrate with Jira and Confluence.** Pull ticket details or page content into the planning context without leaving the terminal.

---

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed and authenticated
- macOS or Linux (hooks use bash)
- `jq` installed (`brew install jq` / `apt install jq`)
- Optional: Atlassian Rovo MCP server configured, for Jira and Confluence skills

---

## Installation

### Option 1 — Plugin mode (recommended)

Load hydra-claude as a Claude Code plugin. This is the cleanest approach: hooks and skills load automatically without modifying your personal settings.

```bash
# Clone the repo
git clone https://github.com/your-org/hydra-claude.git ~/hydra-claude

# Start Claude Code with the plugin loaded
claude --plugin-dir ~/hydra-claude
```

> The `--plugin-dir` flag tells Claude Code to load `plugin.json` from that directory. Hooks, agents, and skills are all registered from there.

To avoid typing `--plugin-dir` every session, add an alias to your shell profile:

```bash
echo 'alias cc="claude --plugin-dir ~/hydra-claude"' >> ~/.zshrc
source ~/.zshrc
```

### Option 2 — Project-local (per repo)

If you want hydra-claude active only when working inside a specific project, copy the settings file into that project:

```bash
cd /your/project
cp ~/hydra-claude/settings.json .claude/settings.json
```

Claude Code automatically picks up `.claude/settings.json` when it exists in the project root. The hooks reference scripts by absolute path via `${CLAUDE_PLUGIN_ROOT}`, so the hooks directory must still be present at the path defined in the settings file. Symlink or copy the `hooks/` directory alongside it if needed.

### Option 3 — Use from the project itself

If you want to develop or customize hydra-claude, work directly from its directory:

```bash
cd ~/hydra-claude
claude --plugin-dir .
```

---

## Project structure

```
hydra-claude/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata, hooks, agents, and skills config
│   └── marketplace.json     # Marketplace listing info
├── agents/
│   ├── sprinter.md          # Low-complexity agent (Haiku)
│   ├── builder.md           # Medium/high-complexity agent (Sonnet)
│   ├── architect.md         # Expert-complexity agent (Opus)
│   └── doc-writer.md        # Documentation agent
├── hooks/
│   ├── token-logger.sh      # PostToolUse: writes token usage to disk
│   ├── context-compactor.sh # UserPromptSubmit: warns at 50% context capacity
│   ├── inject-learned.sh    # SessionStart: injects learned.md as system context
│   └── statusline.sh        # StatusLine: displays tokens and ctx% in CLI
├── skills/
│   ├── plan-task/           # Creates a plan before any code change
│   ├── explore-codebase/    # Maps codebase structure and conventions
│   ├── learn/               # Captures repo-specific patterns into memory
│   ├── read-plan/           # Retrieves a saved plan by ID or path
│   ├── read-jira/           # Fetches Jira ticket details
│   ├── read-confluence/     # Fetches Confluence page content
│   └── write-confluence/    # Creates or updates Confluence pages
├── tests/
│   └── run.sh               # Test runner
├── CLAUDE.md                # Orchestrator rules (plan-first, no direct edits)
└── settings.json            # Local dev hook definitions (mirrors plugin.json hooks)
```

---

## How it works

### The orchestration model

hydra-claude enforces a strict separation between planning and execution:

```
User request
    │
    ▼
Orchestrator (main Claude instance)
    │
    ├─ Runs plan-task skill → writes .claude/plans/plan-NNN.md
    │
    ├─ User approves plan
    │
    └─ Invokes subagent with plan path only
           │
           ├─ sprinter  (trivial / low complexity)
           ├─ builder   (medium / high complexity)
           └─ architect (expert complexity)
                  │
                  └─ Reads plan → edits files → writes task summary
```

The orchestrator passes only the plan file path to the subagent. The agent reads the plan itself. This keeps the agent prompt small and the plan the single source of truth.

### Hooks

Four hooks run automatically in every session:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `token-logger.sh` | PostToolUse (every API call) | Parses the transcript for token usage and writes totals to `~/.hydra-claude/token-summary.json` |
| `context-compactor.sh` | UserPromptSubmit (each message) | Reads the token summary; warns with exit code 2 if input tokens exceed 50% of the 200k context window |
| `inject-learned.sh` | SessionStart (once per new session) | Reads `.claude/memory/learned.md` and injects it as additional system context under the heading "Repo-specific learned patterns (MUST follow strictly)" |
| `statusline.sh` | StatusLine (continuous) | Displays `↑{input} ↓{output} tokens | ctx:XX%` in the CLI status bar with color-coded pressure indicators |

### Status line

```
↑87k ↓15k tokens | ctx:43%
```

- `↑` — input tokens (cyan): current context window usage including cache
- `↓` — output tokens (green): total generated tokens this session, including subagents
- `ctx:%` — context window fill: green < 50%, yellow 50–80%, red ≥ 80%

### Token tracking details

The token logger tracks each session's consumption to disk at `~/.hydra-claude/token-summary.json`. It uses the **latest** message's `input_tokens` (not a running sum) because each message already reflects the full current context size. Output tokens from subagents are tracked separately by scanning the transcript directory for sibling `.jsonl` files created during the same session.

---

## Skills

Skills are invoked by typing `/hydra-claude:<skill-name>` in the Claude Code prompt. The `plan-task` skill is triggered automatically per CLAUDE.md rules.

### `plan-task`

Analyzes a task, finds the relevant code area, assesses complexity, and writes a plan to `.claude/plans/plan-NNN.md`. Returns the plan path and a recommended subagent tier. The orchestrator uses this to determine which agent to invoke.

**Complexity tiers:**

| Complexity | Agent |
|-----------|-------|
| Trivial / low | `hydra-claude:sprinter` |
| Medium / high | `hydra-claude:builder` |
| Expert | `hydra-claude:architect` |

### `read-plan`

Retrieve a saved plan by ID or path.

```
/hydra-claude:read-plan 3
/hydra-claude:read-plan .claude/plans/plan-003.md
```

If the plan is not found, the skill lists the 3–5 most recent plans.

### `explore-codebase`

Maps the project's structure, conventions, tech stack, and testing patterns. Writes a summary to `.claude/memory/codebase-knowledge.md`. Subagents read this file for context when implementing tasks.

### `learn`

Scans the current conversation for repo-specific patterns, decisions, and corrections that should persist across sessions. Merges findings into `.claude/memory/learned.md`. This file is injected automatically at every session start.

Run this at the end of a productive session:

```
/hydra-claude:learn
```

### `read-jira`

Fetches a Jira ticket by URL.

```
/hydra-claude:read-jira https://your-org.atlassian.net/browse/PROJ-123
```

Requires the Atlassian Rovo MCP server to be configured.

### `read-confluence`

Fetches a Confluence page by URL.

```
/hydra-claude:read-confluence https://your-org.atlassian.net/wiki/spaces/PROJ/pages/123456
```

### `write-confluence`

Creates or updates a Confluence page with content you provide.

---

## Agents

Agents are subprocesses launched by the orchestrator to perform the actual file editing. Each is tuned for its complexity tier.

| Agent | Model | Best for |
|-------|-------|---------|
| `hydra-claude:sprinter` | claude-haiku-4-5 | Simple edits, single-file changes, low-stakes tasks |
| `hydra-claude:builder` | claude-sonnet-4-6 | Day-to-day features, multi-file changes, medium complexity |
| `hydra-claude:architect` | claude-opus-4-6 | System design decisions, complex refactors, high-precision tasks |
| `hydra-claude:doc-writer` | claude-haiku-4-5 | Writing documentation |

---

## Memory

hydra-claude uses two memory files within the project:

| File | Purpose |
|------|---------|
| `.claude/memory/learned.md` | Repo-specific patterns captured by the `learn` skill; injected at session start |
| `.claude/memory/codebase-knowledge.md` | Codebase map created by `explore-codebase`; read by agents during task execution |
| `.claude/plans/plan-NNN.md` | Task plans created by `plan-task`; passed to agents for execution |

These files are project-local. The `learn` skill never writes to `~/.claude/`.

---

## Customizing

### Adding a skill

Create a new directory under `skills/` and add a `SKILL.md` file:

```bash
mkdir skills/my-skill
touch skills/my-skill/SKILL.md
```

The `plugin.json` `"skills": "./skills/"` directive auto-loads every subdirectory. No registration step needed.

### Adding a hook

Register the hook in **both** files to ensure it works in all load paths:

1. `.claude-plugin/plugin.json` — for plugin users (`claude --plugin-dir`)
2. `settings.json` — for local dev sessions

### Modifying agent behavior

Edit the relevant `.md` file in `agents/`. Each file is a system prompt that defines the agent's behavior, tools, and constraints.

---

## Testing

```bash
npm test
# or directly
bash tests/run.sh
```

When testing hooks, use `HOME` override to isolate file system side effects:

```bash
echo "$payload" | HOME="$TMPDIR" bash hooks/token-logger.sh
```

Never `source` hook scripts in tests — run them as subprocesses.

---

## Troubleshooting

**Status line not showing token counts**

The status line reads from `~/.hydra-claude/token-summary.json`. If the file doesn't exist yet, the display will be blank until the first tool use writes it. Make sure `jq` is installed.

**Context warning not firing**

The `context-compactor.sh` hook uses exit code 2 to signal a warning to Claude Code. If warnings are not appearing, check that the hook is registered under `UserPromptSubmit` in your active settings file.

**Skills not found**

Skills must be loaded from a directory specified in `plugin.json` under `"skills"`. If running without `--plugin-dir`, skills won't be available unless you've configured them manually.

**Jira / Confluence skills failing**

These skills require the Atlassian Rovo MCP server to be configured and authenticated. Check your MCP server configuration in `~/.claude/settings.json` or your Claude Code MCP settings.

---

## License

MIT
