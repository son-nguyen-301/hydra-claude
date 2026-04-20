---
name: explore-codebase
description: "Map a codebase's structure, conventions, and architecture into codebase-knowledge.md. Invoke when the user says 'explore the codebase', 'understand project structure', 'onboard me', 'what does this project do', 'I'm new to this repo', 'map conventions', or 'learn the tech stack'. All other skills and agents depend on the output of this skill."
---

> Workspace path, slug computation, and ID scheme are in `skills/_shared/workspace-core.md`. Output templates are in `skills/_shared/workspace-templates.md`. Read both files first.

**Step 0 — Check GitNexus availability**
Call `list_repos` to check whether the current repository is indexed in GitNexus. If the repo is not indexed, skip Step 1 entirely and proceed directly to Step 2 (file-level exploration). Note in the output that GitNexus was unavailable. Rationale: querying an unindexed repo wastes tool calls with no new information.

**Step 1 — Map the codebase with GitNexus**

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

Read a representative set of files from GitNexus output when available, or choose representative files directly from the repository tree if GitNexus is unavailable. Focus on:
- Coding conventions and style (a few typical implementation files)
- Tech stack and dependencies (`package.json`, `go.mod`, `pyproject.toml`, etc.)
- Testing patterns (a test file or two)
- Build/lint/format config

**Step 2.1 — Find existing rule files**
Read the repo for any existing rule files (e.g., `.eslintrc`, `prettier.config.*`, `CLAUDE.md`, `.cursor/rules`, etc.).

**Step 3 — Save to shared memory**
Compute `<slug>` from CWD. Write findings to `~/.claude/projects/<slug>/memory/codebase-knowledge.md` following the `codebase-knowledge.md` outline from the shared reference. Create the directory if needed. Return the path.
