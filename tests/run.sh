#!/usr/bin/env bash
# Test runner — sources all test files and reports results

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize counters (exported so assert.sh can access them)
TESTS_PASSED=0
TESTS_FAILED=0

# Source the assert library first
source "$TESTS_DIR/lib/assert.sh"

# Source all test files (they define test functions)
source "$TESTS_DIR/hooks/post-compact.test.sh"
source "$TESTS_DIR/hooks/statusline.test.sh"
source "$TESTS_DIR/hooks/inject-learned.test.sh"
source "$TESTS_DIR/config/validate-json.test.sh"
source "$TESTS_DIR/skills/skills-frontmatter.test.sh"

printf "\n── Running tests ──────────────────────────────────────────────────\n\n"

printf "hooks/post-compact.sh\n"
test_post_compact_outputs_message
test_post_compact_exits_zero
test_post_compact_empty_stdin

printf "\nhooks/statusline.sh\n"
test_statusline_no_data
test_statusline_token_display
test_statusline_cost_display
test_statusline_cost_color_green
test_statusline_cost_color_yellow
test_statusline_cost_color_red
test_statusline_ctx_display
test_statusline_ctx_color_green
test_statusline_ctx_color_yellow
test_statusline_ctx_color_red
test_statusline_rate_limit_display
test_statusline_rate_limit_reset_time
test_statusline_rate_limit_no_reset_below_80
test_statusline_rate_limit_color_green
test_statusline_rate_limit_color_yellow
test_statusline_rate_limit_color_red

printf "\nhooks/inject-learned.sh\n"
test_inject_learned_no_cwd
test_inject_learned_no_learned_file
test_inject_learned_empty_file
test_inject_learned_with_content

printf "\nconfig/validate-json\n"
test_plugin_json_valid
test_plugin_json_has_name
test_plugin_json_has_version
test_plugin_json_has_no_post_tool_use_token_logger
test_plugin_json_has_hooks_post_compact
test_plugin_json_has_hooks_session_start
test_plugin_json_has_status_line_command
test_plugin_json_agents_non_empty_array
test_plugin_json_has_skills
test_settings_json_valid
test_settings_json_has_status_line_command
test_settings_json_has_hooks_post_compact

printf "\nskills/frontmatter\n"
test_skills_frontmatter_all

# ── Summary ──────────────────────────────────────────────────────────────────

printf "\n────────────────────────────────────────────────────────────────────\n"
printf "%d passed, %d failed\n" "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
