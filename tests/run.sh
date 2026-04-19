#!/usr/bin/env bash
# Test runner — invokes vendored bats-core on the tests/ tree.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="$TESTS_DIR/vendor/bats-core/bin/bats"

if [ ! -x "$BATS" ]; then
  echo "bats-core not found at $BATS" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

# Collect .bats files explicitly, excluding the vendor directory
BATS_FILES=()
while IFS= read -r -d '' f; do
  BATS_FILES+=("$f")
done < <(find "$TESTS_DIR" -name '*.bats' -not -path '*/vendor/*' -print0 | sort -z)

if [ "${#BATS_FILES[@]}" -eq 0 ]; then
  echo "No .bats test files found under $TESTS_DIR" >&2
  exit 1
fi

# Use --pretty when stdout is a TTY for human-readable output
if [ -t 1 ]; then
  exec "$BATS" --pretty "${BATS_FILES[@]}"
else
  exec "$BATS" "${BATS_FILES[@]}"
fi
