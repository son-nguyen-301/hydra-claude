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

**Step 1 — Map the codebase with GitNexus**
Use GitNexus MCP tools and skills to understand the full codebase structure: files, folders, symbols, components, composables, hooks, utilities, etc. Gather as much information as possible.

**Step 2 — Read key files**
Select a representative set of files from the GitNexus output. Read them to understand:
- Coding conventions and style
- Tech stack and dependencies
- Testing patterns
- Linting and formatting rules

**Step 2.1 — Find existing rule files**
Read the repo for any existing rule files (e.g., `.eslintrc`, `prettier.config.*`, `CLAUDE.md`, `.cursor/rules`, etc.).

**Step 3 — Save to shared memory**
Compute `<slug>` from the current working directory using the formula above. Write everything discovered — patterns, conventions, rules, tech stack details — to `~/.claude/projects/<slug>/memory/codebase-knowledge.md`. Create the `memory/` directory if it does not exist. This path is consistent across all Claude Code sessions working in the same project.

## Output

The path `~/.claude/projects/<slug>/memory/codebase-knowledge.md`.
