#!/usr/bin/env bats
# Tests for hooks/_lib.sh::resolve_project_root

load '../test_helper'

LIB="$ROOT/hooks/_lib.sh"

# Helper: invoke resolve_project_root in a subshell with the given cwd
_run_resolver() {
  local cwd="$1"
  bash -c 'source "$1" && resolve_project_root "$2"' _ "$LIB" "$cwd"
}

@test "resolve_project_root: returns git root when cwd is the git root" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root/.git"
  run _run_resolver "$root"
  assert_success
  assert_output "$root"
}

@test "resolve_project_root: returns git root when cwd is nested inside a git repo" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root/.git" "$root/src/deep/nested"
  run _run_resolver "$root/src/deep/nested"
  assert_success
  assert_output "$root"
}

@test "resolve_project_root: prefers .git over .claude when both are present at the same level" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root/.git" "$root/.claude"
  run _run_resolver "$root"
  assert_success
  assert_output "$root"
}

@test "resolve_project_root: returns .claude ancestor when there is no .git" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root/.claude" "$root/src"
  run _run_resolver "$root/src"
  assert_success
  assert_output "$root"
}

@test "resolve_project_root: returns nearest marker when nested git is inside an outer .claude project" {
  local outer="$BATS_TEST_TMPDIR/outer"
  local inner="$outer/inner"
  mkdir -p "$outer/.claude" "$inner/.git" "$inner/src"
  run _run_resolver "$inner/src"
  assert_success
  assert_output "$inner"
}

@test "resolve_project_root: falls back to cwd when no marker found anywhere up to /" {
  local root="$BATS_TEST_TMPDIR/lonely"
  mkdir -p "$root/a/b"
  run _run_resolver "$root/a/b"
  assert_success
  assert_output "$root/a/b"
}

@test "resolve_project_root: returns the main worktree root when cwd is the main worktree" {
  local root="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" -c user.email=test@example.com -c user.name=test \
    commit -q --allow-empty -m init
  run _run_resolver "$root"
  assert_success
  assert_output "$root"
}

@test "resolve_project_root: returns the main worktree when cwd is a linked worktree" {
  local root="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" -c user.email=test@example.com -c user.name=test \
    commit -q --allow-empty -m init
  local wt="$BATS_TEST_TMPDIR/wt"
  git -C "$root" worktree add -q "$wt" -b feat
  # git prints canonical absolute paths; compare like-for-like to survive
  # symlinked tmpdir prefixes.
  local expected
  expected=$(git -C "$wt" worktree list --porcelain | sed -n '1s/^worktree //p')
  run _run_resolver "$wt"
  assert_success
  assert_output "$expected"
}
