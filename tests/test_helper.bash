# tests/test_helper.bash — shared setup loaded by every .bats file

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load "${TESTS_DIR}/vendor/bats-support/load"
load "${TESTS_DIR}/vendor/bats-assert/load"

ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
export ROOT

# Create an isolated HOME under BATS_TEST_TMPDIR for each test.
# BATS_TEST_TMPDIR is automatically cleaned up by bats — no manual trap/rm -rf needed.
setup_isolated_home() {
  export HYDRA_FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HYDRA_FAKE_HOME"
}
