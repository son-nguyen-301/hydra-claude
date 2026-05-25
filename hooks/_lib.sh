#!/usr/bin/env bash
# Shared helpers for hydra-claude hooks.
# Source this file from hook scripts; do not execute directly.

# Echoes the absolute path of the project root for the given cwd.
# Walks up from cwd; returns the nearest ancestor that contains .git/ or .claude/.
# Falls back to cwd itself if neither marker is found before reaching /.
resolve_project_root() {
  local cwd="$1"
  local d="$cwd"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.git" ] || [ -d "$d/.claude" ]; then
      printf '%s' "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  printf '%s' "$cwd"
}
