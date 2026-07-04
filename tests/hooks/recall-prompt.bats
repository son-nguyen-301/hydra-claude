#!/usr/bin/env bats
# Tests for hooks/recall-prompt.sh

load '../test_helper'

HOOK="$ROOT/hooks/recall-prompt.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  setup_isolated_project
  MEM_DIR="$HYDRA_FAKE_PROJECT/.claude/memory/plugin"
  mkdir -p "$MEM_DIR"
  cat > "$MEM_DIR/patterns-hooks.md" <<'EOF'
---
scope: "Hook conventions."
triggers:
  keywords:
    - "hook"
---

## Hooks must fail open

Body of the pattern.

**Why:** recall must never block work.

---
EOF
  bash "$ROOT/scripts/build-triggers-index.sh" "$MEM_DIR"
}

_run_hook() {
  local prompt="$1" sid="${2:-sess1}"
  local payload
  payload=$(jq -n --arg p "$prompt" --arg s "$sid" --arg c "$HYDRA_FAKE_PROJECT" \
    '{prompt: $p, session_id: $s, cwd: $c}')
  run bash -c 'echo "$1" | TMPDIR="$2" bash "$3"' _ "$payload" "$TMPDIR" "$HOOK"
}

@test "recall-prompt: garbage payload exits 0 silently" {
  run bash -c 'echo "not json" | bash "$1"' _ "$HOOK"
  assert_success
  assert_output ""
}

@test "recall-prompt: short prompt is skipped" {
  _run_hook "add a hook"
  assert_success
  assert_output ""
}

@test "recall-prompt: no match exits silently" {
  _run_hook "please refactor the css stylesheet colors today"
  assert_success
  assert_output ""
}

@test "recall-prompt: keyword match injects entry text as UserPromptSubmit context" {
  _run_hook "please add a new hook that fires on file edits"
  assert_success
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.hookEventName'" _ "$output"
  assert_output "UserPromptSubmit"
}

@test "recall-prompt: injected context contains the entry and announce instruction" {
  _run_hook "please add a new hook that fires on file edits"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.additionalContext'" _ "$output"
  assert_output --partial "## Hooks must fail open"
  assert_output --partial "Applying saved pattern"
}

@test "recall-prompt: second match in same session injects pointer, not full text" {
  _run_hook "please add a new hook that fires on file edits"
  _run_hook "another prompt about the hook lifecycle behavior"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.additionalContext'" _ "$output"
  assert_output --partial "Already surfaced this session"
  refute_output --partial "## Hooks must fail open"
}

@test "recall-prompt: stale TSV is a silent no-op" {
  touch "$MEM_DIR/patterns-hooks.md"
  # Backdate the TSV (portable BSD/GNU form: CCYYMMDDhhmm).
  touch -t 200101010000 "$MEM_DIR/triggers.tsv"
  _run_hook "please add a new hook that fires on file edits"
  assert_success
  assert_output ""
}

@test "recall-prompt: missing store is a silent no-op" {
  rm -rf "$MEM_DIR"
  _run_hook "please add a new hook that fires on file edits"
  assert_success
  assert_output ""
}
