---
name: explore-codebase
description: Use this skill when you need to explore and understand the codebase conventions, structure, and patterns.
---

## Workspace path formula

> The workspace base is `~/.claude/projects/<slug>/`
> where `<slug>` = the project's absolute CWD path with every `/` replaced by `-`
> (e.g., `/Users/foo/bar` → `-Users-foo-bar`)
> Subdirectories: `plans/`, `tasks/`, `debug-findings/`, `memory/`

## How It Works

**Step 1 — Map the codebase with GitNexus (always run first)**

GitNexus provides a pre-built knowledge graph of the codebase. Always query it before reading any files.

**1a. Discover the repo**
Call `list_repos` to get the repo name and stats. If multiple repos are indexed, identify the correct one.
Then READ `gitnexus://repo/{name}/context` for a high-level overview.

**1b. Map functional communities (modules)**
Run a Cypher query to list all communities and their size:
```cypher
MATCH (f)-[:CodeRelation {type: 'MEMBER_OF'}]->(c:Community)
RETURN c.heuristicLabel AS community, count(f) AS members
ORDER BY members DESC
```
This reveals the major functional areas of the codebase (e.g., Auth, Payments, API, etc.).

**1c. Map execution flows (processes)**
Run a Cypher query to list all named processes and how many steps they have:
```cypher
MATCH (s)-[r:CodeRelation {type: 'STEP_IN_PROCESS'}]->(p:Process)
RETURN p.heuristicLabel AS process, count(s) AS steps
ORDER BY steps DESC
LIMIT 20
```
This reveals the main execution flows in the project.

**1d. Map entry points**
Run a Cypher query to list entry points:
```cypher
MATCH (f)-[:CodeRelation {type: 'ENTRY_POINT_OF'}]->(p:Process)
RETURN f.name AS symbol, f.filePath AS file, p.heuristicLabel AS process
```

**1e. Query key domain concepts**
Use `query` to find how core concerns are implemented. Run at least 3–5 queries covering the main areas visible from the communities (e.g., "authentication flow", "data access layer", "API request handling", "error handling", "testing patterns").

**1f. Map API routes (if applicable)**
If the project has API routes, call `route_map` (no filter) to get the full API surface: routes, handlers, middleware chains, and consumers.

**1g. Map MCP/RPC tools (if applicable)**
If the project exposes tools (MCP server, RPC), call `tool_map` to list all tool definitions and their handler files.

**Step 2 — Read key files for conventions**

Using the file paths surfaced by GitNexus, select a representative set of files to read. Focus on:
- Coding conventions and style (a few typical implementation files)
- Tech stack and dependencies (`package.json`, `go.mod`, `pyproject.toml`, etc.)
- Testing patterns (a test file or two)
- Build/lint/format config

**Step 2.1 — Find existing rule files**
Read the repo for any existing rule files (e.g., `.eslintrc`, `prettier.config.*`, `CLAUDE.md`, `.cursor/rules`, etc.).

**Step 3 — Save to shared memory**
Compute `<slug>` from the current working directory using the formula above. Write everything discovered — patterns, conventions, rules, tech stack details — to `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. Create the `memory/` directory if it does not exist. This path is consistent across all Claude Code sessions working in the same project.

## Output

The path `~/.claude/projects/<slug>/memory/codebase-knowledge.md`.
