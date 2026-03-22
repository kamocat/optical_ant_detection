#!/usr/bin/env bash
# Basic regression tests for count_ants.
# Place known test image pairs in tests/fixtures/ named:
#   <label>_a.jpg  <label>_b.jpg
# with a matching expected count in:
#   <label>.expected   (single integer)
#
# Usage:
#   ./tests/run_tests.sh [path/to/count_ants]
#
# The binary path defaults to ./build/count_ants.

set -euo pipefail

BINARY="${1:-./build/count_ants}"
FIXTURES_DIR="$(dirname "$0")/fixtures"
PASS=0
FAIL=0

if [ ! -x "$BINARY" ]; then
    echo "ERROR: binary not found or not executable: $BINARY" >&2
    exit 1
fi

for expected_file in "$FIXTURES_DIR"/*.expected; do
    [ -f "$expected_file" ] || { echo "No test fixtures found in $FIXTURES_DIR" >&2; exit 1; }

    label="$(basename "$expected_file" .expected)"
    img_a="$FIXTURES_DIR/${label}_a.jpg"
    img_b="$FIXTURES_DIR/${label}_b.jpg"
    expected="$(cat "$expected_file")"

    if [ ! -f "$img_a" ] || [ ! -f "$img_b" ]; then
        echo "SKIP $label — image pair not found"
        continue
    fi

    actual="$("$BINARY" "$img_a" "$img_b" 2>/dev/null)"

    if [ "$actual" = "$expected" ]; then
        echo "PASS $label (got $actual)"
        PASS=$((PASS + 1))
    else
        echo "FAIL $label — expected $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
