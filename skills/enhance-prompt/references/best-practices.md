# Prompt Best Practices Checklist

Distilled from FACTORY_AI.md, CLAUDE_PROMPT.md, and CODEX.md. Use this checklist to evaluate and improve prompts before execution.

---

## 1. Clarity & Specificity

- [ ] The desired outcome is stated explicitly (not implied).
- [ ] Vague language is replaced with concrete language ("improve performance" → "reduce p99 latency below 200ms").
- [ ] The request has a single, well-defined goal — not multiple loosely coupled goals in one prompt.
- [ ] Ambiguous pronouns or references are resolved ("it", "that thing", "the component").

**Weak:** "Fix the login bug."
**Strong:** "Fix the login timeout bug where users are logged out after 5 minutes of inactivity. The session should persist for 24 hours unless the user explicitly logs out."

---

## 2. Context

- [ ] The relevant module, layer, or file is identified (frontend / backend / DB / service name).
- [ ] What already exists is described (current behavior, existing code paths).
- [ ] The trigger or circumstance for the request is explained (why this needs to change now).
- [ ] Related constraints from prior decisions are mentioned (e.g., "we use Redis for sessions, not JWTs").

**Weak:** "Add caching to the API."
**Strong:** "Add Redis caching to the `GET /api/products` endpoint in `services/product-service`. The endpoint currently queries the database on every request. Cache the response for 5 minutes; invalidate on product update or delete."

---

## 3. Structure

- [ ] Complex prompts use XML tags to separate concerns (`<context>`, `<task>`, `<requirements>`, `<constraints>`).
- [ ] Sequential procedures use numbered steps.
- [ ] Examples are placed in a dedicated section or fenced block — not mixed into prose.
- [ ] Long prompts lead with context and end with the specific ask (not the other way around).

**Example with XML tags:**
```
<context>
We use Express.js with a PostgreSQL backend. Authentication is handled by Passport.js.
</context>

<task>
Add rate limiting to the /api/auth/login endpoint.
</task>

<requirements>
- Limit to 5 attempts per IP per 15-minute window
- Return HTTP 429 with a Retry-After header on limit exceeded
- Use the existing redis client at lib/redis.js
</requirements>

<constraints>
- Do not modify the Passport.js strategy files
- Do not add new npm dependencies
</constraints>
```

---

## 4. Constraints & Acceptance Criteria

- [ ] What must NOT change is stated (files to leave alone, behaviors to preserve).
- [ ] Performance or scale constraints are quantified (e.g., "must handle 1000 req/s").
- [ ] Compatibility constraints are explicit (Node version, browser support, API contracts).
- [ ] Acceptance criteria are concrete and binary — each criterion is either met or not.

**Acceptance criteria examples:**
- `GET /api/products` response time < 50ms for cached entries (measured via curl)
- Existing unit tests pass without modification
- A new test covers the cache-miss path

---

## 5. Verification

- [ ] There are steps to reproduce the current problem (if bug-related).
- [ ] There are steps to verify the fix or feature works correctly.
- [ ] Edge cases to test are identified (empty input, boundary values, error paths).
- [ ] The command or process for running tests is included if non-obvious.

**Verification example:**
```
To verify:
1. Run `npm test` — all existing tests must pass
2. Hit `GET /api/products` twice; the second response should include `X-Cache: HIT` header
3. Check Redis with `redis-cli keys "products:*"` — confirm a key was created
```

---

## 6. Scope Management

- [ ] The task is focused enough to complete in one session (not a multi-day project disguised as a single prompt).
- [ ] If the task is large, it is broken into smaller steps and the prompt requests one step at a time.
- [ ] For complex tasks, the prompt asks Claude to propose a plan before implementing ("propose a plan, then wait for approval").
- [ ] Dependencies between steps are explicit.

**Weak (too broad):** "Refactor the authentication system."
**Strong (appropriately scoped):** "Step 1 of 3: Extract the session management logic from `auth/controller.js` into a new `auth/session-manager.js` module. Keep the public API identical. Do not change any tests yet — that is Step 2."

---

## 7. Anti-patterns — Before/After Examples

### Anti-pattern 1: Vague outcome
**Before:** "Make the dashboard faster."
**After:** "Reduce the initial load time of `/dashboard` from ~3s to under 1s. Profile with Chrome DevTools and address the top two bottlenecks. Do not change the visual design."

### Anti-pattern 2: Missing context
**Before:** "Add error handling."
**After:** "Add error handling to the `uploadFile()` function in `services/storage.js`. Currently it throws unhandled promise rejections when the S3 bucket is unreachable. Catch network errors and return `{ success: false, error: 'storage_unavailable' }` instead."

### Anti-pattern 3: No acceptance criteria
**Before:** "Write tests for the payment module."
**After:** "Write unit tests for `services/payment.js`. Coverage must reach ≥80% for that file. Test the `chargeCard`, `refund`, and `getTransaction` functions. Mock the Stripe SDK — do not make real API calls."

### Anti-pattern 4: Unbounded scope
**Before:** "Refactor the codebase to use TypeScript."
**After:** "Migrate `utils/date-helpers.js` to TypeScript. Add strict types for all exported functions. Ensure the compiled output passes the existing Jest tests. Do not migrate any other files in this PR."
