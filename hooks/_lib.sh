#!/usr/bin/env bash
# Shared helpers for hydra-claude hooks.
# Source this file from hook scripts; do not execute directly.

# Echoes the absolute path of the project root for the given cwd.
# If cwd is inside a LINKED git worktree, returns the main worktree (so plugin memory
# consolidates in the main repo, not the worktree). Otherwise walks up from cwd and
# returns the nearest ancestor containing .git/ or .claude/. Falls back to cwd itself
# if neither marker is found before reaching /.
resolve_project_root() {
  local cwd="$1"

  # Linked-worktree redirect. In a linked worktree, `git rev-parse --git-dir` points
  # at <main>/.git/worktrees/<name> while `--git-common-dir` points at <main>/.git;
  # they differ. In the main worktree (or a non-git dir) they are equal or empty, so
  # we fall through to the marker walk below.
  if command -v git >/dev/null 2>&1; then
    local git_dir common_dir main_wt
    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_dir" ]; then
      common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
      if [ -n "$common_dir" ] && [ "$git_dir" != "$common_dir" ]; then
        main_wt=$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
          | sed -n '1s/^worktree //p')
        if [ -n "$main_wt" ]; then
          printf '%s' "$main_wt"
          return 0
        fi
      fi
    fi
  fi

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
