#!/usr/bin/env bats
# Tests for hooks/recall-pretool.sh (advisory path; deny gate tested separately)

load '../test_helper'

HOOK="$ROOT/hooks/recall-pretool.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  setup_isolated_project
  MEM_DIR="$HYDRA_FAKE_PROJECT/.claude/memory/plugin"
  mkdir -p "$MEM_DIR"
  cat > "$MEM_DIR/patterns-hooks.md" <<'EOF'
---
scope: "Hook conventions."
triggers:
  paths:
    - "hooks/*.sh"
  commands:
    - "git push"
---

## Hooks must fail open

Body of the pattern.

**Why:** recall must never block work.

---
EOF
  bash "$ROOT/scripts/build-triggers-index.sh" "$MEM_DIR"
}

_run_edit() {
  local fp="$1" sid="${2:-sess1}"
  local payload
  payload=$(jq -n --arg f "$fp" --arg s "$sid" --arg c "$HYDRA_FAKE_PROJECT" \
    '{tool_name: "Edit", tool_input: {file_path: $f}, session_id: $s, cwd: $c}')
  run bash -c 'echo "$1" | TMPDIR="$2" bash "$3"' _ "$payload" "$TMPDIR" "$HOOK"
}

_run_bash() {
  local cmd="$1" sid="${2:-sess1}"
  local payload
  payload=$(jq -n --arg b "$cmd" --arg s "$sid" --arg c "$HYDRA_FAKE_PROJECT" \
    '{tool_name: "Bash", tool_input: {command: $b}, session_id: $s, cwd: $c}')
  run bash -c 'echo "$1" | TMPDIR="$2" bash "$3"' _ "$payload" "$TMPDIR" "$HOOK"
}

@test "recall-pretool: garbage payload exits 0 silently" {
  run bash -c 'echo "{}" | bash "$1"' _ "$HOOK"
  assert_success
  assert_output ""
}

@test "recall-pretool: unmatched tool name exits silently" {
  local payload
  payload=$(jq -n --arg c "$HYDRA_FAKE_PROJECT" \
    '{tool_name: "Read", tool_input: {file_path: "hooks/x.sh"}, session_id: "s", cwd: $c}')
  run bash -c 'echo "$1" | bash "$2"' _ "$payload" "$HOOK"
  assert_success
  assert_output ""
}

@test "recall-pretool: matching edit path injects PreToolUse context" {
  _run_edit "$HYDRA_FAKE_PROJECT/hooks/foo.sh"
  assert_success
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.hookEventName'" _ "$output"
  assert_output "PreToolUse"
}

@test "recall-pretool: matching bash command injects entry text" {
  _run_bash "git push origin main"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.additionalContext'" _ "$output"
  assert_output --partial "## Hooks must fail open"
}

@test "recall-pretool: non-matching path is silent" {
  _run_edit "$HYDRA_FAKE_PROJECT/src/app.ts"
  assert_success
  assert_output ""
}

@test "recall-pretool: repeat match in same session becomes a pointer" {
  _run_edit "$HYDRA_FAKE_PROJECT/hooks/foo.sh"
  _run_edit "$HYDRA_FAKE_PROJECT/hooks/bar.sh"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.additionalContext'" _ "$output"
  assert_output --partial "Already surfaced this session"
  refute_output --partial "## Hooks must fail open"
}

@test "recall-pretool: state shared with recall-prompt (prompt first, tool becomes pointer)" {
  local payload
  payload=$(jq -n --arg s "sess1" --arg c "$HYDRA_FAKE_PROJECT" \
    '{prompt: "please edit a hook script for the plugin now", session_id: $s, cwd: $c}')
  # Add a keyword trigger so the prompt hook matches this topic too.
  printf 'patterns-hooks.md\tkeyword\thook\tpattern\n' >> "$MEM_DIR/triggers.tsv"
  bash -c 'echo "$1" | TMPDIR="$2" bash "$3"' _ "$payload" "$TMPDIR" "$ROOT/hooks/recall-prompt.sh" > /dev/null
  _run_edit "$HYDRA_FAKE_PROJECT/hooks/foo.sh"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.additionalContext'" _ "$output"
  assert_output --partial "Already surfaced this session"
}

@test "recall-pretool: truncated-away topic is not recorded as surfaced" {
  # Second topic large enough that topic1 + topic2 exceed the 9500 budget.
  # Matched via an Edit path trigger so it enters through match_tool, not match_prompt.
  {
    printf -- '---\nscope: "big"\ntriggers:\n  paths:\n    - "hooks/*.sh"\n---\n\n'
    printf '## Huge entry\n\n'
    i=0
    while [ "$i" -lt 400 ]; do
      printf 'Line %s of padding content to exceed the injection budget quickly.\n' "$i"
      i=$((i + 1))
    done
    printf '\n---\n'
  } > "$MEM_DIR/zz-huge.md"
  bash "$ROOT/scripts/build-triggers-index.sh" "$MEM_DIR"

  _run_edit "$HYDRA_FAKE_PROJECT/hooks/foo.sh" sessT
  # One of the two topics must have been truncated away; whichever survived is
  # recorded, the truncated one is not.
  run cat "$TMPDIR/hydra-recall-sessT"
  refute_output --partial "zz-huge.md"

  # A later edit matching again injecting the huge topic's content is not required
  # (it may truncate again); the invariant under test is only the state file.
}

# ── deny-once gate ────────────────────────────────────────────────────────────

_write_correction_topic() {
  cat > "$MEM_DIR/corrections.md" <<'EOF'
---
scope: "User corrections."
triggers:
  commands:
    - "git push --force"
---

## Never force-push
class: correction

User said never force-push shared branches.

**Why:** shared history.

---
EOF
  bash "$ROOT/scripts/build-triggers-index.sh" "$MEM_DIR"
}

@test "deny gate: first matching call is denied with the correction text" {
  _write_correction_topic
  _run_bash "git push --force origin main"
  assert_success
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecision'" _ "$output"
  assert_output "deny"
}

@test "deny gate: reason says automated gate and includes entry + retry instruction" {
  _write_correction_topic
  _run_bash "git push --force origin main"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecisionReason'" _ "$output"
  assert_output --partial "Automated memory gate"
  assert_output --partial "not a user denial"
  assert_output --partial "## Never force-push"
  assert_output --partial "Retry the same call"
}

@test "deny gate: second call in same session is NOT denied" {
  _write_correction_topic
  _run_bash "git push --force origin main"
  _run_bash "git push --force origin main"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecision // \"none\"'" _ "$output"
  assert_output "none"
}

@test "deny gate: pattern-class topics never deny" {
  _run_bash "git push origin main"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecision // \"none\"'" _ "$output"
  assert_output "none"
}

@test "deny gate: topic already surfaced by prompt hook is not denied" {
  _write_correction_topic
  local sf="$TMPDIR/hydra-recall-sess1"
  printf 'corrections.md\tfull\n' > "$sf"
  _run_bash "git push --force origin main"
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecision // \"none\"'" _ "$output"
  assert_output "none"
}

@test "deny gate: unwritable state file degrades to advisory, not permanent deny" {
  _write_correction_topic
  touch "$TMPDIR/hydra-recall-sessRO"
  chmod 400 "$TMPDIR/hydra-recall-sessRO"
  _run_bash "git push --force origin main" sessRO
  assert_success
  run bash -c "printf '%s' \"\$1\" | jq -r '.hookSpecificOutput.permissionDecision // \"none\"'" _ "$output"
  assert_output "none"
  chmod 600 "$TMPDIR/hydra-recall-sessRO"
}
