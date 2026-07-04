# hydra-claude

Memory provider for Claude Code. Captures repo-specific patterns at session end and re-injects them on session start and post-compact, so Claude builds up a durable, repo-aware knowledge base across sessions.

---

## What it does

- **Auto-capture at session end.** When you stop a Claude Code session that had meaningful activity (≥5,000 input tokens), hydra-claude runs the `learn` skill, which scans the conversation for repo-specific patterns, corrections, and validated conventions, then routes each one to a categorized topic file under `<project-root>/.claude/memory/plugin/`.
- **Inject memory at session start.** On `SessionStart`, hydra-claude injects the plugin's `CLAUDE.md` rules plus the project's `MEMORY.md` index into Claude's context so Claude knows which topic files exist before deciding what to read.
- **Re-inject after compaction.** On `PostCompact`, the same content is re-injected so context-compacted sessions don't lose the memory map.

Memory format: one Markdown topic file per category, each with a YAML frontmatter `scope` block. The `MEMORY.md` index lists categories with one-line scope summaries for routing.

---

## Requirements

- [Claude Code](https://claude.ai/code)
- macOS or Linux (hooks use bash)
- `jq` installed (`brew install jq` / `apt install jq`)

---

## Installation

### Claude Code marketplace

```
/plugin marketplace add https://github.com/son-nguyen-301/hydra-claude
/plugin install hydra-claude@hydra-claude
```

### Local clone

```bash
git clone https://github.com/son-nguyen-301/hydra-claude.git ~/hydra-claude
claude --plugin-dir ~/hydra-claude
```

### Project-local mode

Copy the repo's settings file into a specific project to activate hydra-claude only there. The file is stored as ` settings.json` (with a leading space) for legacy reasons.

```bash
cd /your/project
cp ~/hydra-claude/' settings.json' .claude/settings.json
```

---

## How it works

Six Claude Code hooks plus one skill:

| Hook | Script | Purpose |
|------|--------|---------|
| `SessionStart` | `hooks/inject-learned.sh` | Injects plugin `CLAUDE.md` + the project's `MEMORY.md` index. |
| `SubagentStart` | `hooks/inject-learned.sh` | Same injection for subagents, so they aren't memory-blind. |
| `UserPromptSubmit` | `hooks/recall-prompt.sh` | Matches the prompt against the trigger index and injects the matching memory entries before the turn starts. |
| `PreToolUse` | `hooks/recall-pretool.sh` | Matches Edit/Write/Bash tool input against the trigger index; injects matching entries; corrections/directives gate the first matching action once per session. |
| `PostCompact` | `hooks/post-compact.sh` | Same content, re-injected after Claude compacts context. |
| `Stop` | `hooks/session-end-learn.sh` | Fires when the session ends. If ≥5k input tokens of activity, exits with code 2 to trigger `/hydra-claude:learn`. |

The `learn` skill (`skills/learn/SKILL.md`) is the capture procedure: filter the conversation to repo-specific patterns, route each to an existing category or create a new one, write to the topic file, and update the `MEMORY.md` index.

**Mid-session auto-capture.** In addition to the end-of-session scan, the plugin's `CLAUDE.md` instructs Claude to invoke `/hydra-claude:learn` immediately when a high-signal moment fires — an explicit save request, a user correction, a directive, or a validated non-obvious approach. The skill enters "focused mode" and writes just that one pattern without re-scanning the conversation. The end-of-session scan remains as a catch-all safety net.

### Decision-point recall

Recall no longer depends on the agent remembering to check memory. At capture time the learn skill writes machine-readable `triggers:` (path globs, command regexes, keywords) into each topic file, regenerates `.claude/memory/plugin/triggers.tsv`, and compiles path-anchored topics into native Claude Code rules at `.claude/rules/hydra/` (attached automatically when a matching file enters context). At decision time two bash hooks match the index in tens of milliseconds (~60ms measured on a typical store; scales with trigger count) and inject the matching entries: on every user prompt (before the turn) and on every Edit/Write/Bash call (advisory; corrections and directives deny the first matching call once per session with the rule in the deny reason). All injection is deduped per session, capped at 10k chars, and fails open — a missing or stale index simply degrades to the old voluntary behavior.

Uninstall/cleanup: remove the hook registrations, `rm -rf .claude/rules/hydra`, and delete `triggers.tsv`; topic files remain valid without them.

---

## Workspace storage

All memory lives inside the project at `<project-root>/.claude/memory/plugin/`. The plugin resolves the project root by walking up from Claude Code's working directory to the nearest ancestor that contains a `.git/` directory (preferred) or a `.claude/` directory (fallback). If neither marker is found, the current working directory is used.

Layout:

```
<project-root>/.claude/memory/plugin/
├── MEMORY.md              # one-line index of categories
├── corrections.md          # example category
├── patterns-testing.md     # example category
└── ...                     # more categories as they emerge
```

**Memory is committed to git by default**, so team members share the project's learned conventions. If you'd prefer per-developer memory, add `.claude/memory/` (or `.claude/memory/plugin/`) to your `.gitignore`.

To auto-approve writes from a strict-allowlist project, add to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Write(.claude/memory/plugin/*)",
      "Bash(mkdir -p .claude/memory/plugin/*)"
    ]
  }
}
```

Most users don't need this snippet — Claude Code allows writes inside the current project by default.

### Migrating from pre-3.1.0

Versions before 3.1.0 stored memory at `~/.claude/projects/<slug>/memory/plugin/`. On first SessionStart after upgrading, hydra-claude auto-copies any existing legacy memory into the new project-local location. The migration:

- runs only when the new project-local directory does not yet exist,
- is non-destructive — the legacy directory is left in place as a backup,
- emits one stderr log line (`[hydra-claude] migrated memory from ... to ...`) when it activates.

Once you've verified the migrated content, you can `rm -rf ~/.claude/projects/<slug>/` to reclaim the disk space. (If you launched Claude Code from multiple subdirectories of your project in pre-3.1.0, you may have multiple legacy directories — the migration runs per-cwd, so re-opening Claude Code from each prior subdirectory will trigger its own migration into the same project-local location.)

---

## Manual usage

- **Invoke learn explicitly:** `/hydra-claude:learn` at any point in a session to capture patterns mid-conversation.
- **Enhance a prompt:** `/hydra-claude:enhance-prompt <your prompt>` rewrites a rough prompt into a structured one. It is **memory-aware** — it reads the project's `.claude/memory/plugin/` patterns and fills the prompt's context and constraints from those captured facts, asks targeted clarifying questions only for gaps memory can't cover, then writes the result to a markdown artifact under `.claude/enhanced-prompts/` and prints its path. Manual only; never auto-triggered.
- **Write memory by hand:** Edit any topic file under `<project-root>/.claude/memory/plugin/` directly. Add an entry to `MEMORY.md` if you create a new category.
- **Inspect memory:** `cat <project-root>/.claude/memory/plugin/MEMORY.md` to see the routing index.

### Initial setup

For a fresh project with no memory yet, invoke `/hydra-claude:seed-memory` to scan the codebase and seed initial entries. The skill reads the project manifests, README, key config files, CI config, the main entry point, and one representative test file — then drafts candidate memory entries grouped by category and presents them for approval. Approved findings are written via the learn skill (so routing and dedup work the same way). Re-runs are safe: existing entries are detected and skipped.

---

## Migrating from v2.x

v2.x bundled orchestration agents (sprinter/builder/architect/doc-writer/code-reviewer/plan-reviewer), planning skills (plan-task/split-plan/review-plan/review-code), and Jira/Confluence/debug helpers. **v3.0.0 removes all of those.** Hydra is now memory-only.

Existing memory files are unaffected by the upgrade — only the in-repo plugin code changes.

If you relied on the orchestration agents or planning skills, pin to the v2.12.2 tag or fork before upgrading.

---

## License

MIT.
