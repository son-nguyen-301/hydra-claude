# hydra-claude

Memory provider for Claude Code. Captures repo-specific patterns at session end and re-injects them on session start and post-compact, so Claude builds up a durable, repo-aware knowledge base across sessions.

---

## What it does

- **Auto-capture at session end.** When you stop a Claude Code session that had meaningful activity (≥5,000 input tokens), hydra-claude runs the `learn` skill, which scans the conversation for repo-specific patterns, corrections, and validated conventions, then routes each one to a categorized topic file under `~/.claude/projects/<slug>/memory/plugin/`.
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

Three Claude Code hooks plus one skill:

| Hook | Script | Purpose |
|------|--------|---------|
| `SessionStart` | `hooks/inject-learned.sh` | Injects plugin `CLAUDE.md` + the project's `MEMORY.md` index. |
| `PostCompact` | `hooks/post-compact.sh` | Same content, re-injected after Claude compacts context. |
| `Stop` | `hooks/session-end-learn.sh` | Fires when the session ends. If ≥5k input tokens of activity, exits with code 2 to trigger `/hydra-claude:learn`. |

The `learn` skill (`skills/learn/SKILL.md`) is the capture procedure: filter the conversation to repo-specific patterns, route each to an existing category or create a new one, write to the topic file, and update the `MEMORY.md` index.

---

## Workspace storage

All memory lives under `~/.claude/projects/<slug>/` where `<slug>` is the project's absolute path with every `/` replaced by `-`.

Example: `/Users/foo/bar` → `-Users-foo-bar` → `~/.claude/projects/-Users-foo-bar/`.

Layout:

```
~/.claude/projects/<slug>/
└── memory/
    └── plugin/
        ├── MEMORY.md              # one-line index of categories
        ├── corrections.md          # example category
        ├── patterns-testing.md     # example category
        └── ...                     # more categories as they emerge
```

To auto-approve writes into this workspace from a specific project, add to that project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Write(~/.claude/projects/*)",
      "Bash(mkdir -p ~/.claude/projects/*)"
    ]
  }
}
```

---

## Manual usage

- **Invoke learn explicitly:** `/hydra-claude:learn` at any point in a session to capture patterns mid-conversation.
- **Write memory by hand:** Edit any topic file under `~/.claude/projects/<slug>/memory/plugin/` directly. Add an entry to `MEMORY.md` if you create a new category.
- **Inspect memory:** `cat ~/.claude/projects/<slug>/memory/plugin/MEMORY.md` to see the routing index.

---

## Migrating from v2.x

v2.x bundled orchestration agents (sprinter/builder/architect/doc-writer/code-reviewer/plan-reviewer), planning skills (plan-task/split-plan/review-plan/review-code), and Jira/Confluence/debug helpers. **v3.0.0 removes all of those.** Hydra is now memory-only.

Existing memory files under `~/.claude/projects/*/memory/plugin/` are unaffected by the upgrade — only the in-repo plugin code changes.

If you relied on the orchestration agents or planning skills, pin to the v2.12.2 tag or fork before upgrading.

---

## License

MIT.
