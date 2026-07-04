---
name: seed-memory
description: "Onboard a new project by scanning the codebase and seeding initial memory entries. Invoke when the user says 'seed project memory', 'onboard this project', 'set up memory for a new project', or when starting work on a project that has no .claude/memory/plugin/ directory yet."
---

> Project-local memory path and output templates are defined in `skills/_shared/workspace-core.md` and `skills/_shared/workspace-templates.md`. Read both files first.

This skill scans a project's codebase and seeds initial memory at `<project-root>/.claude/memory/plugin/` by drafting candidate findings, getting user approval, deduping against any existing memory, and writing approved findings via the `learn` skill in focused mode.

**Project root resolution.** Same as the learn skill: if you are inside a **linked git worktree** (detectable when `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`), the project root is the **main worktree** — the first entry of `git worktree list --porcelain` — so memory is written to the main repo rather than the worktree. Otherwise, it is the nearest ancestor of the current working directory containing `.git/` (preferred) or `.claude/` (fallback); if neither marker is found, use the current working directory. Memory lives at `<project-root>/.claude/memory/plugin/`.

---

## Phase 1 — Scan

Read in this priority order, stopping early when a file doesn't exist. Use the Read tool for files, Bash `ls -la` for directory listings.

1. **Manifest files** at the project root: `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json`, `mix.exs`, etc. Read whichever exists.
2. **README** at project root: `README.md`, `README.rst`, `README.txt`. Read if present.
3. **Top-level file tree**: `ls -la <project-root>` plus one level into subdirectories that look like source (`src/`, `lib/`, `app/`, `cmd/`).
4. **Config files** (if present, read at most 10): `tsconfig.json`, `vite.config.*`, `webpack.config.*`, `jest.config.*`, `vitest.config.*`, `.eslintrc*`, `prettier.config.*`, `tailwind.config.*`, `next.config.*`, `pyproject.toml` (if not already read as manifest), `Dockerfile`, `docker-compose.yml`, `.python-version`, `.nvmrc`, `Makefile`.
5. **CI config** (if present): `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`. Read the first 2 workflow files at most.
6. **Main entry point**: whatever the manifest points at (`main` / `module` field in `package.json`, `[lib]`/`[[bin]]` in `Cargo.toml`, etc.). Read just the first 200 lines.
7. **One representative test file**: if `tests/`, `__tests__/`, `test/`, `spec/` exists OR any `*.test.*` / `*.spec.*` files in src — pick ONE and read its first 200 lines.

**Bounds:**
- Skip vendored directories: `node_modules`, `vendor`, `.venv`, `target`, `dist`, `build`, `__pycache__`.
- Skip individual files larger than 500 lines (or read only the first 200 lines).
- Stop the scan when reasonable signal has been gathered — do not exhaustively read every config.

---

## Phase 2 — Propose

From the scan, draft candidate findings. Each finding is ONE pattern in this form:

```
PATTERN: <one-line title>
WHY: <one or two sentences explaining why this matters>
```

**Filter for repo-specific patterns only.** Same rule as the learn skill: exclude generic best practices. Only save what is specific to THIS repository and would not be obvious from reading any README.

Examples of valid findings:
- `PATTERN: Tests use vitest with @vitest/coverage-v8` — tech-stack signal.
- `PATTERN: All TypeScript files use ESM imports (type: module in package.json)` — convention signal.
- `PATTERN: CI runs npm run lint && npm test on every PR via .github/workflows/ci.yml` — workflow signal.
- `PATTERN: Test setup invokes setup_isolated_X for filesystem isolation` — testing-pattern signal.

Invalid findings (filter these out):
- "Use descriptive variable names" — generic best practice.
- "Functions should be small" — generic.
- "Use semantic commit messages" — universal, not repo-specific unless enforced by tooling.

Group findings under a **proposed category** (a short slug like `tech-stack`, `testing`, `ci`, `conventions`, or `patterns-<domain-slug>` following the learn-skill naming convention from `workspace-templates.md`). Present the list to the user:

```
Found N candidate memory entries from project scan:

Proposed category: tech-stack
  1. <title>
  2. <title>

Proposed category: testing
  3. <title>
  ...

Approve all (yes), edit specific entries (e.g., "edit 3"), drop entries (e.g., "drop 5"), or abort (no)?
```

**Iterate** until the user responds:
- **yes** → proceed to Phase 3.
- **edit N** → rewrite entry N based on the user's instruction, then re-present the updated list. Continue iterating.
- **drop N** → remove entry N from the list, re-present. Continue iterating.
- **no** → abort. Do NOT write anything. Do NOT create the memory directory if it doesn't already exist.

---

## Phase 3 — Dedup (only when memory exists)

Check whether `<project-root>/.claude/memory/plugin/MEMORY.md` exists.

**If MEMORY.md does NOT exist:** First-time init. Skip dedup. All approved candidates go to Phase 4. (You will need to `mkdir -p <project-root>/.claude/memory/plugin/` before Phase 4 — but the learn skill in focused mode handles directory creation, so no explicit mkdir is required here.)

**If MEMORY.md exists:**
1. Read MEMORY.md to see existing category filenames + scope summaries.
2. For each approved candidate, locate the existing category that would match its content (or note "would create new category" if none fits).
3. For candidates routed to an existing category, read that topic file and compare the candidate's PATTERN title against existing `## headings`. Use semantic judgment (not strict string match) — two phrasings of the same convention count as a duplicate.
4. Build a filtered list of NEW findings only.
5. Report: `Filtered: <N_dup> of <N_total> candidates already in memory; writing <N_new>.`
6. If all candidates are duplicates: print `No new findings — all already captured. Aborting.` and exit without writing.

---

## Phase 4 — Write

For each approved + de-duped finding, invoke the `learn` skill in focused mode with the PATTERN/WHY block:

```
/hydra-claude:learn

PATTERN: <one-line title from the candidate>
WHY: <rationale from the candidate>
```

The learn skill handles category routing (Step 4), new-category creation (Step 5), topic-file writing with dedup (Step 6), and MEMORY.md index updates (Step 7). Do NOT write topic files directly from this skill — always delegate to learn.

**Triggers.** This skill never writes `triggers:` frontmatter itself. When learn creates a new category for a finding (its Step 5) or extends an existing one (its Step 6 trigger maintenance), it populates/extends the `triggers:` block using the same derivation rules as full-scan captures (see `workspace-templates.md` → "Trigger metadata"): `paths`/`commands` from the concrete files and commands the scan found, `keywords` from the domain. Give learn enough signal to do this well — phrase each `PATTERN`/`WHY` around the actual evidence (config filenames, command lines, tool names) rather than a vague paraphrase.

**Entry class for seeded findings.** Seeded entries are always written as `class: pattern` (or with no `class:` line at all, which defaults to pattern) — never `class: correction` or `class: directive`. Those two classes feed the PreToolUse deny-once enforcement gate and are reserved for live user corrections/directives captured by the learn skill's own triggers (see learn/SKILL.md's Entry class paragraph); a static scan of lint/CI/pre-commit config cannot endorse enforcement on the user's behalf, so seeding must never assign either class itself. When a scanned source shows the convention is mechanically enforced (a lint rule set to error, a required CI check, a pre-commit hook that fails the build), note that provenance in the entry's `**Why:**` prose instead — e.g. "enforced by `.pre-commit-config.yaml`" — prose, not class.

Invoke learn ONE finding at a time (one invocation per pattern). Do not batch multiple PATTERN/WHY blocks into a single learn invocation.

After all invocations complete, print a one-line summary:

```
Wrote <N> entries across <M> categories. See <project-root>/.claude/memory/plugin/MEMORY.md.
```

---

## Phase 5 — Regenerate machine artifacts

After all Phase 4 invocations are done, regenerate the trigger index and compiled rules by running both scripts (they live in the plugin's `scripts/` directory — resolve it relative to this skill's base directory, i.e. `<skill-base-dir>/../../scripts/`):

```bash
bash <plugin-root>/scripts/build-triggers-index.sh <project-root>/.claude/memory/plugin
bash <plugin-root>/scripts/compile-rules.sh <project-root>/.claude/memory/plugin <project-root>/.claude/rules
```

Run them in that order (the compiler assumes topic files are final). Both are idempotent and always safe to run. Skipping this step leaves decision-time recall degraded (the hooks no-op on a stale index), so it is NOT optional.
