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
mkdir -p ~/.claude/projects
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
│   ├── doc-writer.md        # Documentation agent
│   ├── code-reviewer.md     # Independent code review agent (Opus)
│   └── plan-reviewer.md     # Independent plan review agent (Opus)
├── hooks/
│   ├── inject-learned.sh       # SessionStart: injects plugin rules + MEMORY.md index; detects native auto-memory
│   ├── post-compact.sh         # PostCompact: re-injects plugin rules and memory index; detects native auto-memory
│   ├── user-prompt-submit.sh   # UserPromptSubmit: injects condensed rule reminder on every user turn
│   ├── session-end-learn.sh    # Stop: prompts learn skill when session ends with significant activity
│   └── statusline.sh           # StatusLine: displays tokens, cost, and rate limits
├── skills/
│   ├── _shared/
│   │   ├── workspace-core.md      # Paths, slugs, IDs, preconditions, execution record
│   │   └── workspace-templates.md # All output + document templates (including plan template)
│   ├── plan-task/           # Creates a plan before any code change
│   ├── review-plan/         # Reviews a plan through five lenses before execution
│   ├── explore-codebase/    # Maps codebase structure and conventions
│   ├── learn/               # Captures repo-specific patterns into memory
│   ├── debug/               # Investigates bugs and writes debug-report findings
│   ├── read-plan/           # Retrieves a saved plan by ID or path
│   ├── read-debug-findings/ # Retrieves a saved debug report by ID or path
│   ├── read-jira/           # Fetches Jira ticket details
│   ├── read-confluence/     # Fetches Confluence page content
│   ├── write-confluence/    # Creates or updates Confluence pages
│   ├── review-code/         # Post-implementation code review via code-reviewer agent
│   └── split-plan/          # Decomposes plans into parallel subtasks
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
    ├─ Runs plan-reviewer agent → writes plan-reviews/review-NNN.md
    │
    ├─ User approves parent plan
    │
    └─ Runs split-plan skill → decomposes into sub-plans
           │
           ├─ Presents dependency/wave table → User approves sub-plans
           │   (loop: user may request changes to any sub-plan; update and re-present until approved)
           │
           └─ Orchestrates parallel execution in waves
                  │
                  ├─ Wave 1: independent subtasks run in parallel
                  │       └─ sprinter / builder / architect (per subtask complexity)
                  ├─ Wave 2: subtasks whose Wave-1 dependencies completed
                  │       └─ ...
                  └─ Wave N: ...
                         │
                         ▼
               code-reviewer agent (unified review with 7 lenses + professional behaviors)
                         │
                         ├─ Approve       → task complete
                         ├─ Fix-required  → executor re-applies fixes
                         └─ Rework        → re-plan or escalate
```

The orchestrator passes only the plan file path to the subagent. The agent reads the plan itself. This keeps the agent prompt small and the plan the single source of truth.

### Hooks

The plugin registers the following hooks automatically:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `inject-learned.sh` | SessionStart (once per new session) | Injects MEMORY.md (memory index) and plugin CLAUDE.md as additional system context; detects native auto-memory and skips plugin injection when active; fallback to learned.md for un-migrated projects |
| `post-compact.sh` | PostCompact | Re-injects plugin rules and memory index after context compaction so rules are never lost; detects native auto-memory and skips when active |
| `user-prompt-submit.sh` | UserPromptSubmit (every user turn) | Prepends a condensed 5-rule reminder to every message to prevent rule drift over long sessions |
| `session-end-learn.sh` | Stop | Checks token activity at session end; prompts the `learn` skill to run if significant work was done |
| `statusline.sh` | StatusLine (Claude Code) | Reads the statusLine JSON from Claude Code stdin; displays tokens, cost, and rate limit usage |

**Rule enforcement behaviors:**

- **Rule Re-injection (PostCompact)**: After context compaction, all plugin rules and learned patterns are automatically re-injected into the context, ensuring rules survive the `/compact` operation.
- **Per-Turn Rule Reminder (UserPromptSubmit)**: A condensed 5-rule reminder is prepended to every user message to prevent rule drift over long sessions.
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

### `review-plan` (automatically invoked by plan-reviewer agent)

Review a plan produced by `plan-task` through five lenses (Staff Eng, Tech Lead, SRE, Security, QA) and emit a structured review with Blocker/Major/Minor/Nit findings + concrete rewrites. Writes the review to `~/.claude/projects/<slug>/plan-reviews/review-{plan-id}.md`. This is automatically invoked after plan-task completes.

```
/hydra-claude:review-plan 042
/hydra-claude:review-plan ~/.claude/projects/<slug>/plans/plan-042.md
```

Returns the verdict (Approve / Approve-with-changes / Revise), the review file path, and finding counts to the calling agent.

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

Captures patterns into dynamically categorized topic files under `memory/plugin/` using semantic routing. The agent reads the `memory/plugin/MEMORY.md` index and scope blocks to decide where each pattern belongs. Updates the MEMORY.md index automatically. Patterns are injected at every session start.

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

### `debug`

Investigates bugs and traces root causes. Writes a debug report to `~/.claude/projects/<slug>/debug-findings/debug-report-NNN.md`.

```
/hydra-claude:debug
```

Used automatically by `plan-task` when handling bug-fixing tasks.

### `read-debug-findings`

Retrieve a saved debug report by ID or path.

```
/hydra-claude:read-debug-findings 3
/hydra-claude:read-debug-findings ~/.claude/projects/<slug>/debug-findings/debug-report-003.md
```

### `review-code` (methodology tool — used internally by the code-reviewer agent)

Review methodology tool that applies seven code review lenses (Plan Compliance, Correctness, Security, Conventions, Edge Cases, Test Quality, Code Quality) to changed files. Accepts a plan path, identifies changed files, produces structured findings with Blocker/Major/Minor/Nit severities, and writes a review file. Used internally by the `code-reviewer` agent.

```
/hydra-claude:review-code 042
/hydra-claude:review-code ~/.claude/projects/<slug>/plans/plan-042.md
```

Writes the review to `~/.claude/projects/<slug>/code-reviews/review-{plan-id}.md`.

**Review lenses:**

| Lens | What it checks |
|------|---------------|
| Plan Compliance | Every plan step implemented; no unplanned changes; wiring complete |
| Correctness | Logic errors, null handling, type mismatches, resource leaks, async gaps |
| Security | Injection surfaces, auth gaps, hardcoded secrets, PII in logs |
| Conventions | Naming, file placement, import order, project utilities reuse |
| Edge Cases | Empty/null inputs, boundary values, large inputs, partial failure |
| Test Quality | Coverage, isolation, assertion specificity, no flaky patterns |
| Code Quality | Overengineering, unnecessary abstractions, dead code, magic numbers |

**Verdict levels:**

| Verdict | Meaning |
|---------|---------|
| `Approve` | Zero Blockers, zero Majors — task is done |
| `Fix-required` | Zero Blockers, one or more Majors — apply fixes then re-review |
| `Rework` | One or more Blockers — re-plan or escalate |

### `split-plan`

Decomposes a parent plan into smaller subtasks with explicit dependencies, then orchestrates parallel execution. Independent subtasks run in parallel; dependent subtasks wait for their dependencies to complete first.

```
/hydra-claude:split-plan 042
/hydra-claude:split-plan ~/.claude/projects/<slug>/plans/plan-042.md
```

Writes subtask plans to `~/.claude/projects/<slug>/plans/` and coordinates execution in waves. A subtask marked as `Partial` indicates some of its subtasks succeeded while others failed.

### `enhance-prompt`

Analyzes a prompt against seven best-practice dimensions (clarity, context, constraints, acceptance criteria, structure, verification, scope) and presents an enhanced version for review.

```
/enhance-prompt Add caching to the API
/enhance-prompt Refactor the auth module
```

The skill classifies the prompt first: trivial or already well-structured prompts are skipped with an explanation. For prompts that need improvement, it identifies the gaps, rewrites the prompt incorporating missing elements, and asks: **"Use this enhanced prompt? (yes / no / edit)"**

### `tdd`

Opt-in TDD methodology for coding agents. When active, coding agents (sprinter, builder, architect) follow a strict RED→GREEN→REFACTOR cycle: write a failing test first, implement the minimum code to pass it, then refactor while tests stay green.

This skill is **not applied automatically**. Trigger it by including any of these keywords in your request: `TDD`, `test-driven`, `red-green-refactor`, `write tests first`, `start with a failing test`.

**RED→GREEN→REFACTOR in brief:**

- **RED** — Write the smallest failing test that describes the next behaviour. Confirm it fails before writing any implementation.
- **GREEN** — Write only enough code to make the test pass. Hardcoding is acceptable at this stage.
- **REFACTOR** — Clean up while all tests remain green. Extract duplication, improve naming, tighten types.

The skill is framework-agnostic — it applies regardless of whether the project uses a particular test runner or component framework. Framework-specific test setup follows the project's existing conventions.

### `migrate-memory` (deprecated)

Migrates a project's `learned.md` into the MEMORY.md index + dynamically categorized topic files structure. This skill parses learned.md, uses semantic categorization to organize patterns by domain, writes to the appropriate topic files under `memory/plugin/`, and generates a MEMORY.md routing index. Available on any machine with the plugin installed.

For new projects, use native auto-memory or the `learn` skill instead. Run this only if you have an existing `learned.md` to migrate.

```
/hydra-claude:migrate-memory
```

---

## Execution roles

Claude Code exposes these as registered agents.

| Agent | Model | Best for |
|-------|-------|---------|
| `sprinter` | Low-complexity implementation | Simple edits, single-file changes, low-stakes tasks |
| `builder` | Medium/high-complexity implementation | Day-to-day features, multi-file changes |
| `architect` | Expert implementation | System design decisions, complex refactors |
| `doc-writer` | Documentation writing | Docs, design notes, Confluence updates |
| `code-reviewer` | Independent code review (Opus) | Post-implementation review through 7 lenses + 6 professional behaviors; invoked directly by orchestrator |
| `plan-reviewer` | Independent plan review (Opus) | Automatic plan review through 5 lenses + 6 professional behaviors; invoked directly by orchestrator after plan-task completes |

---

## Memory

hydra-claude stores all workspace files outside the repo, in a shared Hydra workspace:

```
~/.claude/projects/<slug>/
  plans/           — task plans created by plan-task
  plan-reviews/    — plan review reports written by review-plan
  tasks/           — task summaries written by agents
  debug-findings/  — debug reports written by the debug skill
  code-reviews/    — code review reports written by the code-reviewer agent
  memory/
    MEMORY.md                — memory index/routing table; injected at session start
    <topic-files>            — dynamically created topic files based on pattern content
    codebase-knowledge.md    — codebase map created by explore-codebase
    learned.md               — (deprecated) legacy patterns file for un-migrated projects
    plugin/
      MEMORY.md              — plugin memory index for structured patterns
      <topic-files>          — plugin-managed topic files (patterns, corrections, workflows)
```

**How memory works:**

hydra-claude supports two complementary memory systems that coexist without conflict:

- **Native auto-memory** (Claude Code built-in): handles organic discoveries automatically. When active, `inject-learned.sh` and `post-compact.sh` detect it and skip plugin memory injection to avoid duplication.
- **Plugin memory** (`memory/plugin/`): handles structured patterns written explicitly by the `learn` skill or by Claude during a session. Use this for repo-specific conventions, user corrections, and validated non-obvious workflows.

For plugin memory specifically:

- **Categories are not predefined** — the agent creates them dynamically based on the content of each pattern.
- Each topic file carries a **YAML frontmatter scope block** with `scope`, `not`, and `anchors` fields that help future agents route new patterns to the correct file.
- **`memory/plugin/MEMORY.md`** serves as an index/routing table pointing to topic files that emerge organically per project.
- The `learn` skill uses semantic routing: it reads the MEMORY.md index and scope blocks in each topic file to decide where each pattern belongs, and writes patterns to `memory/plugin/`.
- Hooks inject `memory/plugin/MEMORY.md` at session start; Claude reads topic files on-demand.
- For existing projects with only `learned.md`, run `/hydra-claude:migrate-memory` to migrate to the categorized topic files structure. Note: `migrate-memory` is deprecated for new projects — use native auto-memory or the `learn` skill instead.

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
