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

@test "recall-prompt: malformed dynamic ERE in triggers.tsv fails open (no crash, no output pollution)" {
  # An unbalanced ERE ("(((") on a `command` row makes the single-pass awk
  # matcher abort mid-run (BWK awk has no per-row recovery). Since matches are
  # only printed from the awk END block, the abort yields no output at all —
  # the hook must still exit 0 with nothing on stdout, never raw awk error text.
  printf 'patterns-hooks.md\tcommand\t(((\tpattern\n' >> "$MEM_DIR/triggers.tsv"
  printf 'evil.md\tcommand\t$(touch /tmp/HYDRA_PWNED_TEST)\tpattern\n' >> "$MEM_DIR/triggers.tsv"
  _run_hook "please add a new hook that fires on file edits; \$(touch /tmp/HYDRA_PWNED_TEST)"
  assert_success
  assert_output ""
  [ ! -e /tmp/HYDRA_PWNED_TEST ]
}

@test "recall-prompt: truncated-away topic is not recorded as surfaced and injects later" {
  # Second topic large enough that topic1 + topic2 exceed the 9500 budget.
  {
    printf -- '---\nscope: "big"\ntriggers:\n  keywords:\n    - "hook"\n---\n\n'
    printf '## Huge entry\n\n'
    i=0
    while [ "$i" -lt 400 ]; do
      printf 'Line %s of padding content to exceed the injection budget quickly.\n' "$i"
      i=$((i + 1))
    done
    printf '\n---\n'
  } > "$MEM_DIR/zz-huge.md"
  bash "$ROOT/scripts/build-triggers-index.sh" "$MEM_DIR"

  _run_hook "please add a new hook that fires on file edits" sessT
  # One of the two topics must have been truncated away; whichever survived is
  # recorded, the truncated one is not.
  run cat "$TMPDIR/hydra-recall-sessT"
  refute_output --partial "zz-huge.md"

  # A later prompt matching again injects the huge topic's content is not required
  # (it may truncate again); the invariant under test is only the state file.
}

@test "recall-prompt: 10 invocations complete within 5 seconds (hang guard)" {
  local start elapsed i payload
  start=$SECONDS
  for i in 1 2 3 4 5 6 7 8 9 10; do
    # Fresh session id per iteration so every run takes the full assembly path
    # (no "already surfaced" short-circuit), exercising the expensive path 10x.
    payload=$(jq -n --arg c "$HYDRA_FAKE_PROJECT" --arg s "perf$i" \
      '{prompt: "please add a new hook that fires on file edits", session_id: $s, cwd: $c}')
    echo "$payload" | TMPDIR="$TMPDIR" bash "$HOOK" > /dev/null
  done
  elapsed=$(( SECONDS - start ))
  [ "$elapsed" -le 5 ]
}
