# hydra-claude

A Claude Code plugin for structured, cost-aware AI development workflows. It provides planning-first execution, reusable role prompts, automatic context reinjection, and Jira/Confluence helper skills.

---

## What it does

Out of the box, Claude Code will happily edit any file on request. hydra-claude adds a disciplined layer on top:

- **Plan before touching files.** Every request that requires code changes goes through a planning step. The plan is saved and the user approves it before any edits happen.
- **Use the right execution role.** `sprinter`, `builder`, `architect`, and `doc-writer` prompts are available as Claude agents.
- **Track tokens continuously in Claude Code.** A status line shows live input/output token counts and context window pressure. Token metrics refresh automatically after every compaction.
- **Inject learned patterns at session start.** Repo-specific conventions are captured once and injected into every new session automatically.
- **Integrate with Jira and Confluence.** Pull ticket details or page content into the planning context without leaving the terminal.

---

## Requirements

- [Claude Code](https://claude.ai/code) available
- macOS or Linux (hooks use bash)
- `jq` installed (`brew install jq` / `apt install jq`)
- Optional: Atlassian Rovo MCP server configured, for Jira and Confluence skills

---

## Installation

### Claude Code

Install hydra-claude directly from the Claude Code plugin marketplace:

```
/plugin marketplace add https://github.com/son-nguyen-301/hydra-claude
/plugin install hydra-claude@hydra-claude
```

Or clone the repo and load it directly:

```bash
git clone https://github.com/son-nguyen-301/hydra-claude.git ~/hydra-claude
claude --plugin-dir ~/hydra-claude
```

### Claude project-local mode

Copy the repo's local settings file into a specific project to activate hydra-claude only there. Note that this repository currently stores that file as ` settings.json` with a leading space.

```bash
cd /your/project
cp ~/hydra-claude/' settings.json' .claude/settings.json
```

Claude Code automatically picks up `.claude/settings.json` when it exists in the project root.

---

## Workspace storage

hydra-claude now stores shared state for Claude Code under `~/.claude/projects/<slug>/`, where `<slug>` is derived from the absolute project path with each `/` replaced by `-`.

For Claude Code, if you want to auto-approve writes into this workspace, add the following to your project's `.claude/settings.json`:

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

Replace `/Users/<you>` with your actual home directory path.

**Migrating from versions before 3.0.0:** Workspace files previously lived under `~/.hydra-claude/projects/`. To migrate, move your existing data and optionally keep a backup:

```bash
cp -r ~/.hydra-claude/projects/ ~/.claude/projects-backup-hydra
mv ~/.hydra-claude/projects/*/ ~/.claude/projects/
```

Merge any conflicting files manually if both directories already exist.

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
│   └── statusline.sh           # StatusLine: displays tokens, cost, and rate limits
├── skills/
│   ├── plan-task/           # Creates a plan before any code change
│   ├── review-plan/         # Reviews a plan through five lenses before execution
│   ├── explore-codebase/    # Maps codebase structure and conventions
│   ├── learn/               # Captures repo-specific patterns into memory
│   ├── read-plan/           # Retrieves a saved plan by ID or path
│   ├── read-jira/           # Fetches Jira ticket details
│   ├── read-confluence/     # Fetches Confluence page content
│   └── write-confluence/    # Creates or updates Confluence pages
├── tests/
│   └── run.sh               # Test runner
├── CLAUDE.md                # Orchestrator rules (plan-first, no direct edits)
└──  settings.json              # Claude project-local hook definitions
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
    ├─ (Optional) Runs review-plan skill → writes plan-reviews/review-NNN.md
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

The plugin registers the following hooks automatically:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `inject-learned.sh` | SessionStart (once per new session) | Reads plugin CLAUDE.md and `~/.claude/projects/<slug>/memory/learned.md`; injects both as additional system context |
| `post-compact.sh` | PostCompact | Re-injects plugin rules and learned patterns after context compaction so rules are never lost |
| `user-prompt-submit.sh` | UserPromptSubmit (every user turn) | Prepends a condensed 4-line rule reminder to every message to prevent rule drift over long sessions |
| `session-end-learn.sh` | Stop | Checks token activity at session end; prompts the `learn` skill to run if significant work was done |
| `statusline.sh` | StatusLine (Claude Code) | Reads the statusLine JSON from Claude Code stdin; displays tokens, cost, and rate limit usage |

**Rule enforcement behaviors:**

- **Rule Re-injection (PostCompact)**: After context compaction, all plugin rules and learned patterns are automatically re-injected into the context, ensuring rules survive the `/compact` operation.
- **Per-Turn Rule Reminder (UserPromptSubmit)**: A condensed 4-line rule reminder is prepended to every user message to prevent rule drift over long sessions.
The active enforcement layers are context reinjection at session start and after compaction, plus the per-turn reminder on every user prompt.

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

In Claude Code, skills are invoked with `/hydra-claude:<skill-name>`.

### `plan-task`

Analyzes a task, finds the relevant code area, assesses complexity, and writes a plan to `~/.claude/projects/<slug>/plans/plan-NNN.md`. Returns the plan path and a recommended execution role.

**Complexity tiers:**

| Complexity | Role |
|-----------|-------|
| Trivial / low | `hydra-claude:sprinter` |
| Medium / high | `hydra-claude:builder` |
| Expert | `hydra-claude:architect` |

### `review-plan`

Review a plan produced by `plan-task` through five lenses (Staff Eng, Tech Lead, SRE, Security, QA) and emit a structured review with Blocker/Major/Minor/Nit findings + concrete rewrites. Writes the review to `~/.claude/projects/<slug>/plan-reviews/review-{plan-id}.md`.

```
/hydra-claude:review-plan 042
/hydra-claude:review-plan ~/.claude/projects/<slug>/plans/plan-042.md
```

Returns the verdict (Approve / Approve-with-changes / Revise) and asks for user approval before the orchestrator proceeds.

### `read-plan`

Retrieve a saved plan by ID or path.

```
/hydra-claude:read-plan 3
/hydra-claude:read-plan ~/.claude/projects/<slug>/plans/plan-003.md
```

If the plan is not found, the skill lists the 3–5 most recent plans.

### `explore-codebase`

Maps the project's structure, conventions, tech stack, and testing patterns. Writes a summary to `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. Execution roles read this file for context when implementing tasks.

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

## Execution roles

Claude Code exposes these as registered agents.

| Agent | Model | Best for |
|-------|-------|---------|
| `sprinter` | Low-complexity implementation | Simple edits, single-file changes, low-stakes tasks |
| `builder` | Medium/high-complexity implementation | Day-to-day features, multi-file changes |
| `architect` | Expert implementation | System design decisions, complex refactors |
| `doc-writer` | Documentation writing | Docs, design notes, Confluence updates |

---

## Memory

hydra-claude stores all workspace files outside the repo, in a shared Hydra workspace:

```
~/.claude/projects/<slug>/
  plans/           — task plans created by plan-task
  plan-reviews/    — plan review reports written by review-plan
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

1. `.claude-plugin/plugin.json` — Claude Code plugin users
2. ` settings.json` — Claude project-local sessions

### Modifying agent behavior

Edit the relevant file in `agents/`.

---

## Running tests

After cloning, initialize the vendored test dependencies:

```bash
git submodule update --init --recursive
npm test          # or: bash tests/run.sh
```

Tests use [bats-core](https://github.com/bats-core/bats-core) (vendored under `tests/vendor/`). No global install required.

When testing hooks, use `HOME` override to isolate file system side effects:

```bash
echo "" | HOME="$TMPDIR" bash hooks/post-compact.sh
```

Never `source` hook scripts in tests — run them as subprocesses.

---

## Troubleshooting

**Status line not showing token counts**

The status line is Claude Code-specific. If counts are blank, ensure `jq` is installed and the statusLine hook is registered in `.claude-plugin/plugin.json` or ` settings.json`.

**Skills not found**

Skills must be loaded from a directory specified in `plugin.json` under `"skills"`. If running without `--plugin-dir`, skills won't be available unless you've configured them manually.

**Jira / Confluence skills failing**

These skills require the Atlassian Rovo MCP server to be configured and authenticated. Check your MCP server configuration in `~/.claude/settings.json` or your Claude Code MCP settings.

---

## License

MIT
