# hydra-claude

A Claude Code plugin that enforces structured, cost-aware AI development workflows. It provides a planning-first system with specialized agents, real-time token tracking, automatic context management, and integrations with Jira and Confluence.

---

## What it does

Out of the box, Claude Code will happily edit any file on request. hydra-claude adds a disciplined layer on top:

- **Plan before touching files.** Every request that requires code changes goes through a planning step. The plan is saved and the user approves it before any edits happen.
- **Delegate to the right agent.** Three specialized agents (sprinter, builder, architect) handle execution at the appropriate complexity tier. The orchestrating Claude instance never edits directly.
- **Track tokens continuously.** A status line shows live input/output token counts and context window pressure. Token metrics refresh automatically after every compaction.
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

### Option 1 — Marketplace (recommended)

Install hydra-claude directly from the Claude Code plugin marketplace:

```
/plugin marketplace add https://github.com/son-nguyen-301/hydra-claude
/plugin install hydra-claude@hydra-claude
```

### Option 2 — Plugin mode (via `--plugin-dir`)

Clone the repo and load it as a plugin at startup:

```bash
# Clone the repo
git clone https://github.com/son-nguyen-301/hydra-claude.git ~/hydra-claude

# Start Claude Code with the plugin loaded
claude --plugin-dir ~/hydra-claude
```

To avoid typing `--plugin-dir` every session, add an alias to your shell profile:

```bash
echo 'alias cc="claude --plugin-dir ~/hydra-claude"' >> ~/.zshrc
source ~/.zshrc
```

### Option 3 — Project-local (per repo)

Copy the settings file into a specific project to activate hydra-claude only there:

```bash
cd /your/project
cp ~/hydra-claude/settings.json .claude/settings.json
```

Claude Code automatically picks up `.claude/settings.json` when it exists in the project root. The hooks reference scripts by absolute path via `${CLAUDE_PLUGIN_ROOT}`, so the hooks directory must still be present at the path defined in the settings file.

### Option 4 — Develop from source

Work directly from the cloned directory:

```bash
cd ~/hydra-claude
claude --plugin-dir .
```

---

## Permissions

By default, Claude Code will prompt for approval each time hydra-claude writes to its working directories (plans, memory, debug findings, tasks). These directories now live in the Claude Code project workspace at `~/.claude/projects/<slug>/` where `<slug>` is derived from your project's absolute path (each `/` replaced with `-`). To auto-approve these writes without being prompted, add the following to your project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Write(/Users/<you>/.claude/projects/*)",
      "Bash(mkdir -p ~/.claude/projects/*)"
    ]
  }
}
```

Replace `/Users/<you>` with your actual home directory path. If `.claude/settings.json` doesn't exist yet, create it at the root of your project.

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
│   ├── inject-learned.sh       # SessionStart: injects plugin rules + learned.md as system context
│   ├── post-compact.sh         # PostCompact: re-injects plugin rules and learned patterns after compaction
│   ├── user-prompt-submit.sh   # UserPromptSubmit: injects condensed rule reminder on every user turn
│   ├── session-end-learn.sh    # Stop: prompts learn skill when session ends with significant activity
│   ├── stop-validator.sh       # Stop: detects direct Edit/Write calls and blocks rule violations
│   └── statusline.sh        # StatusLine: displays tokens, cost, and rate limits
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
    ├─ Runs plan-task skill → writes ~/.claude/projects/<slug>/plans/plan-NNN.md
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

Seven hooks run automatically in every session:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `inject-learned.sh` | SessionStart (once per new session) | Reads plugin CLAUDE.md and `~/.claude/projects/<slug>/memory/learned.md`; injects both as additional system context |
| `post-compact.sh` | PostCompact | Re-injects plugin rules and learned patterns after context compaction so rules are never lost |
| `user-prompt-submit.sh` | UserPromptSubmit (every user turn) | Prepends a condensed 4-line rule reminder to every message to prevent rule drift over long sessions |
| `session-end-learn.sh` | Stop | Checks token activity at session end; prompts the `learn` skill to run if significant work was done |
| `stop-validator.sh` | Stop | Scans the transcript for direct `Edit`/`Write` calls; blocks the turn with a correction message if a rule violation is detected |
| `statusline.sh` | StatusLine (continuous) | Reads the statusLine JSON from Claude Code stdin; displays tokens, cost, and rate limit usage |

**Rule enforcement behaviors:**

- **Rule Re-injection (PostCompact)**: After context compaction, all plugin rules and learned patterns are automatically re-injected into the context, ensuring rules survive the `/compact` operation.
- **Per-Turn Rule Reminder (UserPromptSubmit)**: A condensed 4-line rule reminder is prepended to every user message to prevent rule drift over long sessions.
- **Rule Violation Detector (Stop)**: After each turn, the Stop hook scans the transcript for direct `Edit`/`Write` calls. If detected, Claude is blocked and must correct itself before the turn ends.

### Status line

```
↑87k ↓15k $0.42 | ctx:43% | 5h:12%
```

- `↑` — input tokens (cyan): current context window usage including cache
- `↓` — output tokens (green): total generated tokens this session
- `$X.XX` — session cost (green < $0.50, yellow $0.50–$2.00, red ≥ $2.00)
- `ctx:%` — context window fill: green < 50%, yellow 50–80%, red ≥ 80%
- `5h:%` — 5-hour rate limit usage; shows reset time when ≥ 80%

### Token tracking details

The status line reads token data directly from the Claude Code `statusLine` JSON object passed via stdin. No intermediate file is written to disk. The `context_window` field provides input tokens (including cache creation and cache read), output tokens, and context fill percentage. Cost and rate limit data are also provided by Claude Code and displayed directly.

---

## Skills

Skills are invoked by typing `/hydra-claude:<skill-name>` in the Claude Code prompt. The `plan-task` skill is triggered automatically per CLAUDE.md rules.

### `plan-task`

Analyzes a task, finds the relevant code area, assesses complexity, and writes a plan to `~/.claude/projects/<slug>/plans/plan-NNN.md`. Returns the plan path and a recommended subagent tier. The orchestrator uses this to determine which agent to invoke.

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
/hydra-claude:read-plan ~/.claude/projects/<slug>/plans/plan-003.md
```

If the plan is not found, the skill lists the 3–5 most recent plans.

### `explore-codebase`

Maps the project's structure, conventions, tech stack, and testing patterns. Writes a summary to `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. Subagents read this file for context when implementing tasks.

### `learn`

Scans the current conversation for repo-specific patterns, decisions, and corrections that should persist across sessions. Merges findings into `~/.claude/projects/<slug>/memory/learned.md`. This file is injected automatically at every session start.

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

hydra-claude stores all workspace files outside the repo, in the Claude Code project workspace:

```
~/.claude/projects/<slug>/
  plans/           — task plans created by plan-task
  tasks/           — task summaries written by agents
  debug-findings/  — debug reports written by the debug skill
  memory/
    learned.md           — repo-specific patterns; injected at session start
    codebase-knowledge.md — codebase map created by explore-codebase
```

The slug is derived from the project's absolute CWD: every `/` is replaced with `-`. For example, `/Users/foo/bar` becomes `-Users-foo-bar`.

These files never live inside the repo and are never committed to git.

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
echo "" | HOME="$TMPDIR" bash hooks/post-compact.sh
```

Never `source` hook scripts in tests — run them as subprocesses.

---

## Troubleshooting

**Status line not showing token counts**

The status line reads directly from Claude Code's statusLine JSON via stdin. If counts are blank, ensure `jq` is installed and the statusLine hook is registered in `plugin.json` (or `settings.json` for local dev).

**Skills not found**

Skills must be loaded from a directory specified in `plugin.json` under `"skills"`. If running without `--plugin-dir`, skills won't be available unless you've configured them manually.

**Jira / Confluence skills failing**

These skills require the Atlassian Rovo MCP server to be configured and authenticated. Check your MCP server configuration in `~/.claude/settings.json` or your Claude Code MCP settings.

---

## License

MIT
