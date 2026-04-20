# Code Review Lenses — Full Checklists

Reference for the `code-reviewer` agent. Seven lenses, each with a checklist, common anti-patterns, and one worked example finding.

---

## TOC

1. [Plan Compliance](#plan-compliance)
2. [Correctness](#correctness)
3. [Security](#security)
4. [Conventions](#conventions)
5. [Edge Cases](#edge-cases)
6. [Test Quality](#test-quality)
7. [Code Quality](#code-quality)

---

## Severity calibration — 3 worked examples

Use these as anchors when triangulating novel findings. When in doubt between Blocker and Major, prefer Major.

1. **Critical logic path skipped by implementation → Blocker, Plan Compliance lens.**
   A plan step that wires a new agent into `plugin.json` is missing from the implementation. The feature is silently non-functional. No after-the-fact diagnosis is obvious. Blocker.

2. **Null dereference on empty input → Major, Correctness lens.**
   A shell script crashes when its input file is empty because it does not guard against the empty case. Users with no prior data will hit this immediately, but the fix is straightforward and does not require re-planning. Major.

3. **Variable name `x` in a function used by three callers → Nit, Code Quality lens.**
   The name is unclear but the logic is correct and the scope is small. Renaming is pure style. Nit.

---

## Plan Compliance

### What to look for

- Does every step in the plan have a corresponding implementation? Check each plan step explicitly.
- Are all files listed under "Files to create" actually created?
- Are all files listed under "Files to edit" actually edited?
- Are any changes present that were not in the plan (unplanned modifications)?
- Is the verification section satisfiable? Can each verification item actually be run?
- Does the agent tier match what the plan specified?
- Are all plan-specified test additions present in the implementation?
- Is the version bump applied to all manifests if the plan called for it?
- Does the implementation match the plan's stated complexity level?
- Are any partial implementations left that the plan treated as complete steps?
- Is the execution record appended to the plan file per the workspace protocol?

### Common anti-patterns

- **Step skipped silently** — plan listed a step, implementation omits it with no note; the caller assumes it's done.
- **Wrong file modified** — implementation edited a similarly named file instead of the one the plan specified.
- **Partial wiring** — new code was written but not registered or imported where the plan called for it (e.g., agent created but not added to plugin.json).
- **Verification gap** — plan verification items reference commands or paths that don't exist in the implementation.
- **Scope creep** — implementation added unplanned changes that increase risk surface without plan coverage.

### Worked example finding

**Severity:** Blocker
**Lens:** Plan Compliance
**File:** `.claude-plugin/plugin.json`
**Observation:** The plan's Step 6 requires adding `"./agents/code-reviewer.md"` to the `agents` array in `plugin.json`. The file was not modified — the agents array still contains only the original four entries. The `code-reviewer` agent is silently unregistered.
**Suggested fix:** Add `"./agents/code-reviewer.md"` to the `agents` array in `.claude-plugin/plugin.json`. The array should read: `["./agents/architect.md", "./agents/sprinter.md", "./agents/builder.md", "./agents/doc-writer.md", "./agents/code-reviewer.md"]`.
**Rationale:** An unregistered agent cannot be invoked by Claude Code. Every user of the `review-code` skill will hit a silent failure at Step 2. The fix is one line but the impact of omission is total.
**Effort:** Low

---

## Correctness

### What to look for

- Are there null or undefined dereferences on unguarded inputs?
- Are type mismatches present — string where integer expected, array where scalar expected?
- Are there race conditions in asynchronous or concurrent code?
- Are resources (file handles, connections, locks) properly released on all code paths including errors?
- Are there off-by-one errors in loops, array slicing, or index arithmetic?
- Are there stale closures capturing loop variables by reference in async callbacks?
- Are errors swallowed — caught but not logged or propagated?
- Are all branches of conditionals handled — no missing `else` or `default` in a switch?
- Is mutation contained — no leaked object references that allow unintended external modification?
- Are `await` keywords present on all async calls where the result is used?
- Are shell variables quoted where they can contain spaces or special characters?
- Are exit codes from subprocesses checked before proceeding?

### Common anti-patterns

- **Swallowed error** — `catch (e) {}` or `|| true` hides a failure that callers depend on detecting.
- **Unquoted variable** — bash `$var` without quotes breaks when the value contains spaces or glob characters.
- **Missing await** — async function called without `await`, result is a Promise object instead of the resolved value.
- **Partial failure ignored** — multi-step operation continues after one step fails, producing corrupt state.
- **Mutation leak** — function returns a reference to an internal mutable object; caller can corrupt the internal state.

### Worked example finding

**Severity:** Major
**Lens:** Correctness
**File:** `hooks/session-end-learn.sh:42`
**Observation:** The script reads `$TOKEN_FILE` with `cat "$TOKEN_FILE"` but does not check whether the file exists first. When a session ends without prior token tracking, `cat` fails with an error written to stderr, and `jq` receives no input, causing a cryptic parse failure rather than a clean "nothing to do" exit.
**Suggested fix:** Add a guard before the `cat` call: `[ -f "$TOKEN_FILE" ] || exit 0`. This matches the pattern used in `inject-learned.sh` lines 18–20 for the same class of optional-file reads.
**Rationale:** The "file does not exist" case is the common case for first-time users. A cryptic jq parse error in the Stop hook will surface as a confusing error message every time a new user ends their first session. The guard costs one line and eliminates the failure mode entirely.
**Effort:** Low

---

## Security

### What to look for

- Are there shell injection surfaces — unquoted variables in command substitution, `eval`, or string interpolation passed to `bash -c`?
- Are there SQL injection surfaces — user input concatenated into queries without parameterization?
- Are there template injection surfaces — user-controlled content rendered in a template engine?
- Are there path traversal risks — file paths constructed from user input without canonicalization?
- Are there XSS surfaces — user input rendered into HTML without encoding?
- Are there CSRF risks on new state-mutating endpoints?
- Are authentication and authorization checks present on all new HTTP surfaces?
- Are secrets, tokens, or passwords handled safely — not logged, not passed as CLI arguments, not hardcoded?
- Is PII (email, IP, user ID) present in log lines without an explicit justification?
- Are new input validation boundaries defined and enforced?
- Are output encoding requirements met for each output channel (terminal, HTML, JSON)?
- Is there a TOCTOU race between checking a resource and using it?
- Are new third-party dependencies reviewed for supply chain risk?

### Common anti-patterns

- **Unquoted shell input** — `bash -c "cmd $USER_INPUT"` allows arbitrary command injection when `USER_INPUT` contains `;`, `&&`, or `$(...)`.
- **Secret as argument** — API key passed via CLI argument appears in `ps` output and shell history.
- **Hardcoded credential** — token or password literal embedded in a script or config file.
- **Overly broad file permission** — script writes to or reads from `/tmp` without a unique subdirectory, allowing symlink attacks from other processes.
- **PII in structured log** — user email or IP address written to a log file that has no documented retention or access control policy.

### Worked example finding

**Severity:** Blocker
**Lens:** Security
**File:** `hooks/user-prompt-submit.sh:31`
**Observation:** The hook builds a jq filter by string-interpolating `$USER_PROMPT` directly: `jq -r ".prompt = \"$USER_PROMPT\""`. If `USER_PROMPT` contains double quotes or `$(...)`, the interpolation allows shell command injection or jq syntax errors that corrupt the hook output.
**Suggested fix:** Pass the user prompt as a jq argument: `jq -r --arg prompt "$USER_PROMPT" '.prompt = $prompt'`. The `--arg` flag ensures the value is treated as a literal string, not as jq syntax.
**Rationale:** `UserPromptSubmit` fires on every user message. Any user can trigger this path with a crafted message. The `--arg` pattern is already used correctly in `inject-learned.sh` line 27 — use the same approach here.
**Effort:** Low

---

## Conventions

### What to look for

- Do naming patterns match the codebase? (Check `codebase-knowledge.md` §11 for conventions.)
- Are new files placed in the correct directory per the project layout?
- Is import ordering consistent with existing files?
- Is error handling style consistent — does it match the existing pattern (propagate vs. log-and-continue)?
- Is logging style consistent — structured vs. unstructured, log level choices?
- Are existing project utilities reused rather than re-implemented inline?
- Are type or interface definitions placed where the project convention says they belong?
- Do function and variable names follow the project's case convention (UPPER_SNAKE for globals, lowercase for locals in bash)?
- Are shell scripts started with `#!/usr/bin/env bash` and a one-line purpose comment?
- Is JSON manipulated with `jq` exclusively — no regex on JSON?
- Are ANSI escape codes using `$'\033[...m'` with a paired `RESET`?
- Are paths derived with `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` rather than `$PWD`?

### Common anti-patterns

- **Convention island** — new file uses a completely different naming or style convention from all surrounding files, requiring extra cognitive load to read.
- **Reinvented utility** — new helper function duplicates one already present in the repo under a slightly different name.
- **Direct JSON regex** — `grep '"version"'` or `sed` used to parse JSON instead of `jq`.
- **Hardcoded home path** — `/Users/hardcoded-name/...` embedded in a script instead of `$HOME` or `~`.
- **Missed manifest** — new component added to code but not registered in `plugin.json` or `marketplace.json`, breaking the plugin load path.

### Worked example finding

**Severity:** Minor
**Lens:** Conventions
**File:** `agents/code-reviewer.md:1`
**Observation:** The new agent file does not begin with a YAML frontmatter block (`---`). All other agent files (`builder.md`, `sprinter.md`, `architect.md`, `doc-writer.md`) begin with frontmatter containing `name`, `description`, and `model`. Omitting frontmatter breaks the Claude Code agent registration pattern.
**Suggested fix:** Add frontmatter at the top of the file: `---\nname: code-reviewer\ndescription: "..."\nmodel: claude-opus-4-6\n---`. Match the style of `agents/builder.md` exactly.
**Rationale:** Claude Code reads agent files expecting the frontmatter format. Without it, the agent may not register correctly. Consistent frontmatter also makes the agents discoverable by automated tooling and tests.
**Effort:** Low

---

## Edge Cases

### What to look for

- Is empty or null input handled — what happens when a list is empty, a file is missing, or a value is null?
- Are boundary values handled — what happens at 0, -1, and maximum integer values?
- Is large input handled — what happens when a file is very long or a list has thousands of items?
- Are special characters handled — unicode, emojis, null bytes, newlines in field values?
- Is concurrent access handled — what if two processes read/write the same file simultaneously?
- Is network failure handled — what happens when an HTTP call or MCP tool call fails or times out?
- Is missing config handled — what if an env var or config file is absent?
- Is partial failure handled — what if step 3 of 5 fails; is state left consistent?
- Are duplicate entries handled — what if the same plan ID is processed twice?
- Are timeout scenarios handled — what if an agent call never returns?

### Common anti-patterns

- **Optimistic file read** — code reads a file assuming it exists; no guard for "file not found".
- **Integer overflow blind spot** — arithmetic on user-supplied counts with no cap; large inputs produce unexpected results.
- **Single-process assumption** — state file written with no locking, assuming only one process runs at a time.
- **Happy-path-only error handling** — error branch exists but only for the expected error type; unexpected errors propagate uncaught.
- **Locale-sensitive comparison** — string comparison that breaks under non-UTF-8 locales or case-insensitive filesystems.

### Worked example finding

**Severity:** Major
**Lens:** Edge Cases
**File:** `skills/review-code/SKILL.md:Step 1`
**Observation:** The skill infers the plan from "the most recent delegation" when no plan ID is provided, but does not handle the case where no delegation has occurred in the current session (fresh session, first review). The skill will attempt to read a non-existent plan path and fail silently or confusingly.
**Suggested fix:** Add an explicit guard: "If no plan is inferable from the session and no ID is provided, prompt the user: 'No plan ID provided and no recent delegation found. Please provide a plan ID or path.' Do not proceed until the user responds."
**Rationale:** Users starting a review in a fresh context (e.g., after a `/compact`) will hit this path. Failing silently or with a cryptic file-not-found error is a poor experience. An explicit prompt resolves the ambiguity in one round-trip.
**Effort:** Low

---

## Test Quality

### What to look for

- Are all new code paths covered by at least one test?
- Are edge cases covered in tests — empty input, missing file, error path?
- Are tests isolated — no shared mutable state between test cases?
- Are assertions specific — not just `.toBeDefined()` or `assert_success` alone, but checking actual output values?
- Are there flaky-test patterns — `sleep`, wall-clock comparisons, external HTTP calls, non-deterministic ordering?
- Are negative tests present — tests that assert the system rejects invalid input or returns a specific error?
- Are test names descriptive enough to diagnose a failure without reading the test body?
- Does the test file follow the project's bats conventions (load `../test_helper`, use `setup_isolated_home` for file system tests)?
- Are new bats files auto-discovered — no manual registration needed since `tests/run.sh` globs `*.bats`?
- Is coverage symmetric — if a new skill is added, are frontmatter tests added for it?

### Common anti-patterns

- **Assertion-free test** — `@test "foo works" { run foo; assert_success }` with no check on the actual output; passes even when the output is wrong.
- **Shared home directory** — hook test modifies `$HOME` without `setup_isolated_home`, leaving side effects that corrupt subsequent tests.
- **Sleep-based timing** — test uses `sleep 1` to wait for an async side effect; breaks under slow CI.
- **Positive-only coverage** — every test exercises the success path; error paths and missing-input cases are untested.
- **Copy-paste test block** — test duplicates 10 lines from another test with one variable changed; a shared helper or parameterized test would be cleaner.

### Worked example finding

**Severity:** Major
**Lens:** Test Quality
**File:** `tests/config/validate-json.bats`
**Observation:** The plan requires adding a test that verifies the `agents` array in `plugin.json` includes `code-reviewer.md`. This test is absent. The existing test only checks that the agents array is non-empty — it would pass even if `code-reviewer.md` was never added to `plugin.json`.
**Suggested fix:** Add the following test block:
```bash
@test "plugin.json: agents array includes code-reviewer.md" {
  run jq -e '.agents[] | select(. == "./agents/code-reviewer.md")' "$PLUGIN_JSON"
  assert_success
}
```
**Rationale:** The non-empty check provides false confidence. The specific-entry check is the only assertion that would catch the regression where a developer adds `code-reviewer` to code but forgets to register it in `plugin.json`. This is one of the most common integration gaps in plugin development.
**Effort:** Low

---

## Code Quality

### What to look for

- Is there overengineering — a class hierarchy or abstraction layer for a 3-line task?
- Are there unnecessary abstractions — helper functions called only once with no reuse benefit?
- Is there premature optimization — caching, batching, or parallelism added before there is evidence it is needed?
- Is there dead code — functions, variables, or branches that are never reached?
- Are there god functions — functions that do too many things and could be split for clarity?
- Is there copy-paste duplication — identical or near-identical blocks in two or more places?
- Are there magic numbers — literal values with no named constant or comment explaining their meaning?
- Is there over-defensive coding — excessive null checks on values that are always defined in this context, redundant validation of already-validated inputs?
- Are there unnecessary dependencies — a new library added for something trivially implementable with existing tools?
- Is separation of concerns maintained — parsing, logic, and I/O in separate functions where the code is long enough to warrant it?
- Could this be simpler? Ask: "Is there a 10-line version of this 50-line function that does the same thing?"

### Common anti-patterns

- **One-time helper** — function defined, used exactly once, adds indirection without reuse. Inline it.
- **Defensive null chain** — `if [ -n "$A" ] && [ -n "$B" ] && [ -n "$C" ]` on values that are always set by the calling context; adds noise without safety.
- **God function** — a single bash function that reads config, validates input, writes output, and handles errors; refactor into pipeline stages.
- **Copy-paste variation** — two nearly identical blocks differ by one variable name; extract a shared function with a parameter.
- **Abstraction for one** — a `Formatter` class with one method called from one place; the method could be a function or even an inline expression.

### Worked example finding

**Severity:** Minor
**Lens:** Code Quality
**File:** `agents/code-reviewer.md:Step 2`
**Observation:** The step defines four separate strategies for identifying changed files (task summary, `git diff HEAD~1`, `git diff`, `git diff --cached`) as four sequential `if` branches, each with 3–4 lines of bash. This pattern will be repeated verbatim every time the agent is instantiated. Extracting the strategy into a named procedure with a documented fallback order would make the intent clearer in 5 lines instead of 16.
**Suggested fix:** Replace the four branches with a single "try-in-order" note: "To identify changed files, try in order: (1) parse 'Files touched' from the task summary, (2) `git diff HEAD~1 --name-only`, (3) `git diff --name-only`, (4) `git diff --cached --name-only`. Use the first strategy that returns at least one file." The agent can implement this as a pipeline.
**Rationale:** The four-branch pattern is not wrong, but the sequential fallback intent is clearer when stated as a priority list. This also reduces the chance that a future edit changes three of the four branches but misses the fourth.
**Effort:** Low
