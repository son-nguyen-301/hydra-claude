# Review Lenses — Full Checklists

Reference for the `review-plan` skill. Five lenses, each with a checklist, common anti-patterns, and one worked example finding.

---

## TOC

1. [Staff Engineer](#staff-engineer)
2. [Tech Lead](#tech-lead)
3. [SRE](#sre)
4. [Security](#security)
5. [QA](#qa)

---

## Severity calibration — 3 worked examples

Use these as anchors when triangulating novel situations. When in doubt between Blocker and Major, prefer Major.

1. **Missing tests on a standard refactor → Major, QA lens.**
   No automated tests on a well-scoped refactor. Cost is real — regressions ship silently — but tests can be added after the fact and the refactor itself is not destructive. Escalate to Major, not Blocker: the plan can still ship with an amendment rather than a full restart.

2. **Unauthenticated admin endpoint on a payment service → Blocker, Security lens.**
   The plan as written produces an endpoint that, if deployed, is exploitable from day 1. No amount of after-the-fact fixing recovers the credentials-exposure window. Blocker.

3. **One-shot SQL migration that drops a column with no backup step → Blocker, SRE / Staff Engineer lens.**
   Rollback requires the old column's data, which this plan deletes before taking a snapshot. There is no after-the-fact fix — once the migration runs, the data is gone. Blocker even though the code itself is correct.

---

## Staff Engineer

### What to look for

- Does the plan introduce a new abstraction? Is it the right level — not too thin, not too wide?
- Are module boundaries clear? Does new code reach across boundaries it should not?
- Is there coupling to a specific implementation where an interface would be safer?
- Does the plan reuse existing code, or does it reinvent something already present?
- Is there a versioning concern — does this change a public API or a shared contract?
- Is backward compatibility addressed? If breaking, is a migration path specified?
- What is the blast radius? Which other components, teams, or consumers are affected?
- Are writes idempotent where they need to be? Is state shape explicitly defined?
- Are there concurrency risks (shared mutable state, race conditions, ordering dependencies)?
- Does the plan leave any architectural decision deferred without flagging it as a known gap?
- Is the chosen approach aligned with the system's existing patterns, or does it introduce a second pattern?
- Is the scope consistent with the stated goal — neither under-engineered nor over-engineered?

### Common anti-patterns in plans

- **Abstraction-free plan** — direct implementation across multiple call sites with no shared helper or interface; fine for one-off scripts, wrong for anything shared.
- **Hidden coupling** — plan touches module A but implicitly relies on internal state in module B without an explicit dependency declaration.
- **Partial backward compatibility** — breaking change to a shared contract with no mention of callers, migration scripts, or deprecation path.
- **Undeclared state shape** — new persistent state (DB table, file, env var) introduced without a schema or format spec.
- **Concurrency hand-wave** — plan says "this will be called from multiple workers" but doesn't address locking, ordering, or idempotency.
- **Reinvented wheel** — plan adds a utility function that already exists in the codebase under a slightly different name.

### Worked example finding

**Severity:** Major
**Lens:** Staff Engineer
**Location:** Step 3 — Implementation (Files to create)
**Observation:** The plan adds a `slugify(path)` helper inline inside `hooks/inject-learned.sh` without checking that the same transformation is already performed in `hooks/post-compact.sh` and `hooks/user-prompt-submit.sh`. Three independent implementations of the same logic will drift.
**Suggested rewrite:** Extract a shared `_slug()` function into a new file `hooks/_lib/slug.sh`, source it from all three hooks, and delete the inline copies. Update `tests/hooks/` to cover the shared function directly.
**Rationale:** Shared helpers reduce the surface for silent divergence across scripts that run in the same runtime context. The existing hooks already demonstrate this drift risk — `post-compact.sh` and `inject-learned.sh` each have subtly different path-handling.

---

## Tech Lead

### What to look for

- Does the plan solve the problem stated in the requirements, or does it solve an adjacent problem?
- Is the scope right-sized — does it do too much (scope creep) or too little (incomplete solution)?
- Is the assigned agent tier correct? A Blocker-level architectural decision shouldn't go to `sprinter`.
- Does the plan reference `codebase-knowledge.md` conventions, or does it invent new conventions?
- Are all files that need to change listed? Are any obviously missing (tests, manifests, docs)?
- Are dependencies (library updates, infra changes, config changes) called out explicitly?
- Is the "done" definition clear? Can a reviewer verify completion without guessing?
- Is delivery risk assessed? Does the plan call out what could go wrong and provide fallback options?
- Are there open questions that should be resolved before execution begins?
- Does the plan slot naturally into the existing orchestration model (plan → review → delegate)?
- Does the complexity assessment match the actual work described in the plan body?

### Common anti-patterns in plans

- **Requirements drift** — plan starts solving the stated problem then gradually pivots to a refactor that wasn't asked for.
- **Wrong agent tier** — plan labeled `sprinter` but touches six files across three modules, or labeled `architect` for a single-line config change.
- **Missing file list** — plan describes logic changes but omits the test files, README updates, or manifest bumps that are clearly required by convention.
- **Underspecified "done"** — plan says "add the feature" with no acceptance criteria and no pointer to how to verify it works.
- **Hidden dependency** — plan assumes a library upgrade or infra change has already happened without calling it out as a prerequisite.

### Worked example finding

**Severity:** Major
**Lens:** Tech Lead
**Location:** ## Complexity / Suggested agent
**Observation:** The plan is labeled `sprinter` (trivial/low complexity) but the body lists changes across `hooks/inject-learned.sh`, `hooks/post-compact.sh`, `.claude-plugin/plugin.json`, `hooks.json`, `settings.json`, and two test files. Six-file multi-manifest changes consistently map to `builder` per the complexity table in `codebase-knowledge.md`.
**Suggested rewrite:** Change `Suggested agent: sprinter` to `Suggested agent: builder`.
**Rationale:** Running a medium-complexity change through `sprinter` (Haiku) risks incomplete or incorrect edits due to the model tier's context limits. The complexity table in `codebase-knowledge.md` §5 explicitly maps multi-file manifest changes to `builder`.

---

## SRE

### What to look for

- Are new log lines structured (JSON / key=value fields)? Are existing log lines preserved or explicitly removed?
- Are metrics or traces emitted for new code paths that will be monitored in production?
- Are new feature flags defined — name, default value, rollout scope?
- Are new config values / env vars called out with their name, type, default, and where they are read?
- Is the rollout strategy specified (direct deploy, shadow, canary, blue-green, gradual percentage)?
- Is there an explicit rollback procedure if the rollout goes wrong?
- Does the change affect on-call runbooks or alerting thresholds?
- Are rate limits, retries, and timeouts set for any new external calls?
- Is there a circuit breaker or graceful degradation path for dependency failures?
- Does the plan introduce new state (files, DB rows, cache entries) that persists across restarts?

### Common anti-patterns in plans

- **Log-blind rollout** — plan adds a new code path but specifies no log output, making production incidents hard to diagnose.
- **Unconfigured config** — plan references an env var by name but doesn't specify the default, the valid range, or where it is read.
- **No rollback path** — plan deploys a schema migration or writes a new file format without mentioning how to roll back if the migration fails.
- **Unlimited retries** — plan adds an HTTP call with retry logic but doesn't cap the number of attempts or add a timeout.
- **Persistent side effects with no cleanup** — plan writes new files to disk on every request without a TTL, rotation, or cleanup job.

### Worked example finding

**Severity:** Minor
**Lens:** SRE
**Location:** Step 2 — Hook implementation
**Observation:** The plan adds a new hook that writes to `~/.hydra-claude/token-summary.json` on every `Stop` event but does not specify a maximum file size, rotation policy, or cleanup strategy. Over a long-running session the file grows without bound.
**Suggested rewrite:** Add to the plan: "Cap `token-summary.json` at the last 1000 entries. On each write, read the file, append the new entry, slice to `[-1000:]`, and write back. Add a `@test` that writes 1001 entries and verifies only 1000 remain."
**Rationale:** Unbounded log files are a common on-call pain point; specifying the cap in the plan ensures the executor implements it rather than deferring it.

---

## Security

### What to look for

- Does the plan add a new HTTP endpoint or inter-service call? Is authentication and authorization explicitly specified?
- Are all user-supplied inputs validated before use? Is the validation strategy stated?
- Is output encoding specified for any new data rendered to a terminal, web page, or log?
- Are there shell injection surfaces? (Bash `eval`, unquoted variables in command substitution, `jq` with `--arg` vs. string interpolation.)
- Are there SQL / template / path traversal injection surfaces?
- How are secrets (API keys, tokens, passwords) handled? Are they stored, logged, or passed as arguments?
- Does the plan expose PII in logs, error messages, or file outputs?
- Are token lifetimes and rotation policies specified for new credentials?
- Is there audit logging for privileged operations?
- Does the plan follow least-privilege — does it request only the permissions it needs?
- Is there a TOCTOU (time-of-check / time-of-use) race in any file or resource access?
- Are new third-party dependencies vetted? Is the supply chain risk acknowledged?

### Common anti-patterns in plans

- **Auth-free endpoint** — plan adds a new internal HTTP route with no mention of authentication middleware or token validation.
- **Secret in argument** — plan passes a secret via a CLI argument or env var without noting that it will appear in `ps` output or shell history.
- **Unquoted shell variable** — plan includes bash snippets where user-controlled values are interpolated directly into a command string without quoting or `--arg`.
- **PII in structured logs** — plan logs a user ID, email, or IP address without noting that log retention and access controls are already in place.
- **Overly broad permission** — plan requests `WRITE(/)` or `Read(/etc/)` when only a specific subdirectory is needed.

### Worked example finding

**Severity:** Blocker
**Lens:** Security
**Location:** Step 2 — API layer (Files to create: `handlers/webhook.go`)
**Observation:** The plan adds a new `/internal/webhook` HTTP endpoint but specifies no authentication or authorization check. Any process that can reach the service can trigger the webhook handler.
**Suggested rewrite:** Add to the plan before the handler implementation step: "Register the `RequireInternalToken` middleware on the `/internal/webhook` route. The middleware reads `INTERNAL_WEBHOOK_SECRET` from the environment and validates the `X-Internal-Token` request header using a constant-time comparison (`subtle.ConstantTimeCompare`). Document the secret rotation procedure in the runbook."
**Rationale:** Unauthenticated internal endpoints are a common lateral movement surface. Even on a private network, an attacker with any internal foothold can trigger the endpoint. Constant-time comparison prevents timing-based token enumeration.

---

## QA

### What to look for

- Does the plan specify a test strategy — which types of tests will be added (unit, integration, e2e)?
- Are coverage targets or coverage gaps explicitly addressed?
- Are edge cases enumerated? (empty input, max-size input, concurrent access, missing config, network failure)
- Does the plan include failure injection — how do you verify the error paths?
- Is regression risk assessed? Which existing tests might break and why?
- Are there flaky-test risks (timing dependencies, external calls, file system state)?
- Is a fixture or test data strategy specified for complex inputs?
- For API changes: are contract tests updated?
- Are any manual test steps included where automation is not feasible?
- Does the plan explicitly state what `tests/run.sh` should report after the change?

### Common anti-patterns in plans

- **Test-last afterthought** — plan describes all implementation steps, then ends with "add tests" as a single bullet with no detail on what to test.
- **Happy-path-only coverage** — plan tests the success case but doesn't mention what happens when the input is empty, the file is missing, or the network call fails.
- **No regression safety net** — plan modifies an existing function that is called in many places but doesn't mention which existing tests exercise it.
- **Flake-prone fixtures** — plan uses `sleep` or wall-clock time in test assertions, or relies on file modification timestamps that may not advance in fast CI runs.
- **Missing test for the thing being planned** — plan adds a new script but omits a corresponding `.bats` file, relying on manual verification only.

### Worked example finding

**Severity:** Major
**Lens:** QA
**Location:** ## Verification (item 3 — "run tests/run.sh")
**Observation:** The plan modifies `hooks/session-end-learn.sh` to add a new threshold check but does not add a `@test` block for the new branch. The existing `tests/hooks/inject-learned.bats` only tests the happy path. If the threshold logic regresses, `tests/run.sh` will still pass.
**Suggested rewrite:** Add to the plan's Files to edit section: "Append two `@test` blocks to `tests/hooks/session-end-learn.bats`: (1) payload with `input_tokens` below threshold → assert exit 0 and no stderr message; (2) payload with `input_tokens` at or above threshold → assert exit 2 and stderr contains 'run learn'. Use `setup_isolated_home` to isolate file system side effects per the bats conventions in `codebase-knowledge.md` §9."
**Rationale:** Untested branches are the primary source of regressions in hook scripts. The bats pattern is already established in the repo — adding two targeted tests takes under 20 lines and closes the coverage gap completely.
