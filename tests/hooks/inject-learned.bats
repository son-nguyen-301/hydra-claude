#!/usr/bin/env bats
# Tests for hooks/inject-learned.sh

load '../test_helper'

INJECT_LEARNED_HOOK="$ROOT/hooks/inject-learned.sh"

# Helper: return the project-local plugin/MEMORY.md path for a given project dir.
# The project dir must already exist on disk (use setup_isolated_project).
_memory_file_for() {
  local project_dir="$1"
  echo "$project_dir/.claude/memory/plugin/MEMORY.md"
}


@test "inject-learned: no cwd exits 0" {
  run bash -c 'echo "{}" | bash "$1"' _ "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no cwd produces no output" {
  run bash -c 'echo "{}" | bash "$1"' _ "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output ""
}

@test "inject-learned: missing MEMORY.md exits 0" {
  setup_isolated_home
  setup_isolated_project
  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing MEMORY.md produces valid JSON" {
  setup_isolated_home
  setup_isolated_project
  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: missing MEMORY.md injects plugin rules" {
  setup_isolated_home
  setup_isolated_project
  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: empty MEMORY.md exits 0" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty MEMORY.md produces valid JSON" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: empty MEMORY.md injects plugin rules" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  touch "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: with MEMORY.md content exits 0" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: output is valid JSON" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: hookEventName == SessionStart" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output "SessionStart"
}

@test "inject-learned: additionalContext contains MEMORY.md file content" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: plugin rules + MEMORY.md exits 0" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: plugin rules + MEMORY.md output is valid JSON" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: additionalContext contains plugin rules header" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES — TOP PRIORITY"
}

@test "inject-learned: additionalContext contains memory index framing" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Memory index"
}

@test "inject-learned: additionalContext contains MEMORY.md content" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "Always use immutable patterns."
}

@test "inject-learned: additionalContext contains separator" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "---"
}

@test "inject-learned: plugin rules only exits 0" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: plugin rules only output is valid JSON" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no orphan memory patterns header when only plugin rules present" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Memory index"
}

@test "inject-learned: health-check emits warning when no rules found" {
  setup_isolated_home
  setup_isolated_project
  local TEMP_HOOK_DIR="$BATS_TEST_TMPDIR/hook_dir"
  mkdir -p "$TEMP_HOOK_DIR"
  cp "$INJECT_LEARNED_HOOK" "$TEMP_HOOK_DIR/inject-learned.sh"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")

  run bash -c 'echo "$1" | HOME="$2" bash "$3" 2>&1 >/dev/null' _ "$payload" "$HYDRA_FAKE_HOME" "$TEMP_HOOK_DIR/inject-learned.sh"
  assert_output --partial "WARNING [inject-learned]"
}

@test "inject-learned: no MEMORY.md exits 0" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no MEMORY.md produces valid JSON" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq . > /dev/null 2>&1' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
}

@test "inject-learned: no MEMORY.md injects plugin rules" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
}

@test "inject-learned: no orphan memory patterns header when no MEMORY.md" {
  setup_isolated_home
  setup_isolated_project

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  refute_output --partial "Memory index"
}

@test "inject-learned: plugin/MEMORY.md present — injects plugin memory regardless of native automemory setting" {
  setup_isolated_home
  setup_isolated_project
  # Write settings with autoMemoryEnabled: true (native auto-memory is ON)
  mkdir -p "$HYDRA_FAKE_HOME/.claude"
  printf '{"autoMemoryEnabled": true}\n' > "$HYDRA_FAKE_HOME/.claude/settings.json"

  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Plugin memory always injected.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output --partial "PLUGIN RULES"
  assert_output --partial "Plugin memory always injected."
}

# ── migration from legacy home-directory memory ───────────────────────────────

# Helper: return the legacy slug-based MEMORY.md path under HYDRA_FAKE_HOME
_legacy_memory_file_for() {
  local project_dir="$1"
  local home_dir="$2"
  local slug
  slug=$(echo "$project_dir" | tr '/' '-')
  echo "$home_dir/.claude/projects/$slug/memory/plugin/MEMORY.md"
}

@test "inject-learned: migrates legacy memory when only old location exists" {
  setup_isolated_home
  setup_isolated_project

  # Seed only the legacy location.
  local LEGACY_FILE
  LEGACY_FILE=$(_legacy_memory_file_for "$HYDRA_FAKE_PROJECT" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEGACY_FILE")"
  printf 'Legacy content X.\n' > "$LEGACY_FILE"

  local NEW_FILE
  NEW_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  [ ! -f "$NEW_FILE" ] || fail "precondition: new file must not exist"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success

  # After the hook runs, the new location must exist and match the legacy content.
  [ -f "$NEW_FILE" ] || fail "new memory file was not created"
  run cat "$NEW_FILE"
  assert_output "Legacy content X."

  # Legacy location must still exist (non-destructive).
  [ -f "$LEGACY_FILE" ] || fail "legacy file should remain in place"
}

@test "inject-learned: migration is idempotent when new location already exists" {
  setup_isolated_home
  setup_isolated_project

  local LEGACY_FILE
  LEGACY_FILE=$(_legacy_memory_file_for "$HYDRA_FAKE_PROJECT" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEGACY_FILE")"
  printf 'Legacy content (should NOT overwrite new).\n' > "$LEGACY_FILE"

  local NEW_FILE
  NEW_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$NEW_FILE")"
  printf 'New content preserved.\n' > "$NEW_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success

  # New file content must be unchanged.
  run cat "$NEW_FILE"
  assert_output "New content preserved."
}

@test "inject-learned: migration is a no-op when neither location exists" {
  setup_isolated_home
  setup_isolated_project

  local NEW_FILE
  NEW_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success

  # No migration should have occurred — new dir/file must not exist.
  [ ! -f "$NEW_FILE" ] || fail "new memory file should not exist"
  [ ! -d "$(dirname "$NEW_FILE")" ] || fail "new memory dir should not exist"
}

@test "inject-learned: migrates when cwd is a subdirectory of the project (slug uses raw cwd)" {
  setup_isolated_home
  setup_isolated_project
  # Simulate launching Claude from a subdirectory of the project.
  local SUBDIR="$HYDRA_FAKE_PROJECT/src/deep"
  mkdir -p "$SUBDIR"

  # The legacy slug must be derived from the SUBDIR cwd, not the project root.
  local LEGACY_FILE
  LEGACY_FILE=$(_legacy_memory_file_for "$SUBDIR" "$HYDRA_FAKE_HOME")
  mkdir -p "$(dirname "$LEGACY_FILE")"
  printf 'Legacy from subdir.\n' > "$LEGACY_FILE"

  # The new file is at the project root (resolve_project_root walks up to .git).
  local NEW_FILE
  NEW_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  [ ! -f "$NEW_FILE" ] || fail "precondition: new file must not exist"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$SUBDIR")
  run bash -c 'echo "$1" | HOME="$2" bash "$3"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success

  # Migration must have copied the subdir-keyed legacy memory to the project-root new location.
  [ -f "$NEW_FILE" ] || fail "new memory file was not created at project root"
  run cat "$NEW_FILE"
  assert_output "Legacy from subdir."
}

# ── recall-era improvements ──────────────────────────────────────────────────

@test "inject-learned: context includes absolute store path" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf -- '- [Hooks](patterns-hooks.md) — hook conventions\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_output --partial "$HYDRA_FAKE_PROJECT/.claude/memory/plugin"
}

@test "inject-learned: store without MEMORY.md warns into context" {
  setup_isolated_home
  setup_isolated_project
  mkdir -p "$HYDRA_FAKE_PROJECT/.claude/memory/plugin"
  printf -- '---\nscope: "x"\n---\n\n## E\nB\n' > "$HYDRA_FAKE_PROJECT/.claude/memory/plugin/orphan.md"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_output --partial "MEMORY.md index is missing"
}

@test "inject-learned: stale triggers.tsv noted in context" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf -- '- [Hooks](patterns-hooks.md) — hooks\n' > "$MEMORY_FILE"
  # topic file exists, TSV absent → stale
  printf -- '---\nscope: "x"\n---\n\n## E\nB\n' > "$(dirname "$MEMORY_FILE")/patterns-hooks.md"

  local payload
  payload=$(printf '{"cwd":"%s"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.additionalContext"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_output --partial "triggers.tsv"
}

# ── SubagentStart event wiring ────────────────────────────────────────────────

@test "inject-learned: hook_event_name SubagentStart is passed through" {
  setup_isolated_home
  setup_isolated_project
  local MEMORY_FILE
  MEMORY_FILE=$(_memory_file_for "$HYDRA_FAKE_PROJECT")
  mkdir -p "$(dirname "$MEMORY_FILE")"
  printf 'Always use immutable patterns.\nPrefer early returns.\n' > "$MEMORY_FILE"

  local payload
  payload=$(printf '{"cwd":"%s","hook_event_name":"SubagentStart"}' "$HYDRA_FAKE_PROJECT")
  run bash -c 'echo "$1" | HOME="$2" bash "$3" | jq -r ".hookSpecificOutput.hookEventName"' _ "$payload" "$HYDRA_FAKE_HOME" "$INJECT_LEARNED_HOOK"
  assert_success
  assert_output "SubagentStart"
}
