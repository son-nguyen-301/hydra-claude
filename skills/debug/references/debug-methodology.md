# Debug Methodology Reference

Used by `skills/debug/SKILL.md`. Contains GitNexus Cypher queries, investigation patterns, and a worked example.

---

## GitNexus Cypher queries for debugging

Use these queries via the `cypher` MCP tool when the repo is indexed in GitNexus.

### Find all callers of a function

```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(target {name: 'functionName'})
RETURN caller.name AS caller, caller.filePath AS file, caller.startLine AS line
ORDER BY file, line
```

Replace `'functionName'` with the name of the function you suspect is the bug site.

### Find test files covering a module

```cypher
MATCH (test)-[:CodeRelation {type: 'IMPORTS'}]->(module {filePath: 'path/to/module.js'})
WHERE test.filePath CONTAINS 'test' OR test.filePath CONTAINS 'spec'
RETURN test.filePath AS testFile
```

Replace `'path/to/module.js'` with the suspected module path.

### Find recent changes to affected files

```cypher
MATCH (f:File {filePath: 'path/to/file.js'})
RETURN f.lastModified AS lastModified, f.name AS file
```

For deeper change history, use `git log --oneline -20 -- path/to/file.js` in Bash.

### Trace a function's dependencies

```cypher
MATCH (f {name: 'functionName'})-[:CodeRelation {type: 'CALLS'}]->(dep)
RETURN dep.name AS dependency, dep.filePath AS file
ORDER BY file
```

### Find all usages of a variable or constant

```cypher
MATCH (usage)-[:CodeRelation {type: 'READS'}]->(symbol {name: 'SYMBOL_NAME'})
RETURN usage.name AS usedIn, usage.filePath AS file, usage.startLine AS line
ORDER BY file, line
```

### Trace all nodes in a community (module boundary)

```cypher
MATCH (f)-[:CodeRelation {type: 'MEMBER_OF'}]->(c:Community {heuristicLabel: 'CommunityName'})
RETURN f.name AS symbol, f.filePath AS file, f.type AS type
ORDER BY file
```

---

## Common investigation patterns

### Pattern 1: Binary search (bisect)

Use when the bug is a regression (worked before, broken now) and the commit history is accessible.

1. Find the last known-good commit: `git log --oneline` and ask the user when it last worked.
2. Check out the midpoint: `git checkout <mid-commit>` and reproduce the bug.
3. If bug present at midpoint → narrow to first half. If absent → narrow to second half.
4. Repeat until the introducing commit is found.
5. `git show <commit>` to see what changed.

This pattern is O(log n) over commits. Most bugs are found in 5–7 bisects.

### Pattern 2: Trace-and-log

Use when the bug produces wrong output but no crash. The data is correct at some point and wrong at another.

1. Identify the pipeline: input → transform A → transform B → output.
2. Add debug logging (or use Read to inspect intermediate values in tests).
3. Check the value after each transform.
4. The transform where the value first diverges from expectation is the bug site.

### Pattern 3: Diff analysis

Use when the bug appeared after a specific change but bisect is impractical.

1. `git diff <good-commit>..<bad-commit> -- path/to/suspected/file` to see what changed.
2. Focus on logic changes, not formatting changes.
3. Look for: removed null checks, changed conditionals, refactored shared state, modified function signatures.

### Pattern 4: Boundary check

Use for off-by-one errors, null pointer dereferences, type mismatches, and input validation bugs.

1. Identify the boundary conditions: empty input, single item, max size, null, undefined, negative numbers.
2. Read the function's input handling code.
3. Check: does the code handle the boundary case that is failing?
4. Check: what happens when the input is `null` / `undefined` / `[]` / `0`?

---

## Worked example: tracing a null-pointer through a call chain

**Scenario:** The API returns a 500 error with message `TypeError: Cannot read properties of undefined (reading 'id')` in `routes/users.js:42`.

**Step 1 — Gather symptoms**

Error: `TypeError: Cannot read properties of undefined (reading 'id')`
Location: `routes/users.js:42`
Trigger: GET `/api/users/profile` after a fresh login
When: Started after last deployment

**Step 2 — Narrow scope**

```bash
git log --oneline -10
# d3f3a7f Refactor user session handling
# ...
```

The refactor of user session handling is suspicious. Check `routes/users.js` and the session module.

**Step 3 — Deep investigation**

Read `routes/users.js` line 42:
```js
// line 40
const session = await sessionService.getSession(req.sessionId);
// line 41
const userId = session.user.id;   // <-- line 42: session.user is undefined
```

Grep for `getSession` to find its implementation:
```
Grep: pattern="getSession", output: services/session.js:15
```

Read `services/session.js:15`:
```js
async getSession(sessionId) {
  const record = await db.sessions.findOne({ id: sessionId });
  return record;   // record.user may be null if user was deleted
}
```

Before the refactor, `getSession` joined the user table. After the refactor, it returns the bare session record — the `user` field is now null when the user account does not exist or was deleted mid-session.

**Step 4 — Root cause confirmation**

Root cause: `sessionService.getSession` was refactored to return a bare session record without the joined `user` object. `routes/users.js` was not updated to handle a null `session.user`, causing a null-pointer dereference on line 42.

Minimal reproduction: log in, delete the user account via the DB console, hit `/api/users/profile` → 500 error.

**Fix hypothesis:** Either (a) restore the user join in `getSession`, or (b) add a null-check in `routes/users.js` and return a 401 when `session.user` is null.

**Step 5 — Write findings** — use the template at `~/.claude/projects/<slug>/debug-findings/debug-report-{id}.md`.
