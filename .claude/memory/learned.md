# Learned Patterns — hydra-claude plugin

## Always use `plan-task` skill before any file changes

Every task that involves file edits must go through `plan-task` first. The plan is written to `.claude/plans/plan-NNN.md` and the user must approve before the builder/sprinter/architect agent proceeds.

**Why:** Enforced by CLAUDE.md. Direct edits without a plan are not allowed in this repo.

---

## Use subagents for all edits — never edit directly

All actual file creation/editing must be delegated to the correct subagent (`hydra-claude:builder`, `hydra-claude:sprinter`, or `hydra-claude:architect`). The orchestrating Claude instance only plans and reviews.

**Why:** CLAUDE.md rule. Direct edits bypass the builder/reviewer separation.

---

## Complexity tiers map to specific agents

| Complexity | Agent |
|------------|-------|
| trivial/low | `hydra-claude:sprinter` |
| medium/high | `hydra-claude:builder` |
| expert | `hydra-claude:architect` |

**Why:** Each agent is tuned for its complexity level. Using the wrong tier wastes cost or misses nuance.

---

## Hooks are registered in two places

Any new hook must be added to BOTH:
1. `.claude-plugin/plugin.json` — for plugin users (`claude --plugin-dir .`)
2. `settings.json` — for local dev sessions

**Why:** The two files serve different load paths. Updating only one means the hook only works in one context.

---

## Test hooks with `HOME` override, not by sourcing

When testing bash hooks, run them as subprocesses with `HOME="$TMPDIR"` to isolate file system side effects. Do not `source` hook scripts in tests.

```bash
echo "$payload" | HOME="$TMPDIR" bash hooks/script.sh
```

**Why:** Sourcing runs in the same shell and can't be isolated. HOME override redirects all `~/.dir` writes to a safe temp location without modifying the scripts.

---

## Skills live in `skills/<name>/SKILL.md`

Each skill is a subdirectory under `skills/` with a `SKILL.md` file. The `plugin.json` `"skills": "./skills/"` directive auto-loads all of them.

**Why:** Adding a new skill only requires creating the directory + file. No registration step needed.

---

## jq deduplication for streaming JSONL token counts

Claude Code writes assistant messages multiple times during streaming — each write has the same `.message.id` but an increasing `output_tokens` count. `unique_by(.message.id)` keeps the **first** (partial) value. Use `group_by` + last instead:

```jq
[$all[] | select(.message.role == "assistant" and .message.usage != null)]
| group_by(.message.id)
| map(.[-1].message.usage.output_tokens // 0)
| add // 0
```

For input tokens, `last` on the full message list is correct (input is cumulative).

**Why:** Observed in `token-logger.sh` — reported 40 tokens vs correct 43,589 due to this bug.

---

## Transcript lazy-creation gap for subagent detection

Claude Code creates the main transcript file on first write, not session start. Subagent transcripts may finish before the main file exists, making their `mtime` older than `stat -f "%B"` on the main file. Use the first timestamp **inside** the transcript as the session anchor, minus a 1800s buffer:

```bash
SESSION_EPOCH=$(jq -rn --rawfile t "$TRANSCRIPT" '
  ($t | split("\n") | map(select(length > 0) | try fromjson catch null) | map(select(. != null))) as $all
  | ($all | map(select(.timestamp != null)) | first | .timestamp)
  | if . then fromdate else 0 end
' 2>/dev/null || echo 0)
SESSION_START=$((SESSION_EPOCH - 1800))
```

**Why:** `stat -f "%B"` gave a birth time 80s after the Explore agent finished, permanently excluding it.

---

## `SessionStart` hook for session-scoped context injection

Use `SessionStart` hook (not `UserPromptSubmit`) when injecting a file into every session once. Output structured JSON:

```bash
printf '%s' "$content" | jq -Rs '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: ("Prefix:\n\n" + .) }
}'
```

**Why:** `UserPromptSubmit` fires on every user message. `SessionStart` fires exactly once per session start/resume.
