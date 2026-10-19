#!/usr/bin/env bash
# The test runner must not report green when a test never ran. Runs through
# tools/run_tests.sh:
#   1. one quick real suite                                 -> must pass
#   2. a fixture with a _test_ function nobody calls        -> must fail ("functions short")
#   3. a fixture with a _test_ function that makes no check -> must fail, by name
# The fixtures are tests/fixtures/run_<name>_tests.gd.
set -u
cd "$(dirname "$0")/.." || exit 1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0

if SUITES_ONLY=1 tools/run_tests.sh selection > "$tmp/out.txt" 2>&1; then echo "ok: a real suite passes"
else echo "FAIL: the selection suite should pass"; tail -20 "$tmp/out.txt"; bad=1; fi

if RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh uncalled > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a suite with an uncalled test function passed"; bad=1
elif grep -q "functions short" "$tmp/out.txt" && grep -q "_test_x is never called" "$tmp/out.txt"; then
	echo "ok: an uncalled test function fails the run, by name"
else echo "FAIL: the uncalled fixture failed without saying why"; tail -20 "$tmp/out.txt"; bad=1; fi

if RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh nocheck > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a test function with no check passed"; bad=1
elif grep -q "_test_empty made no checks" "$tmp/out.txt"; then
	echo "ok: a test function with no check fails the run, by name"
else echo "FAIL: the no-check fixture failed without saying why"; tail -20 "$tmp/out.txt"; bad=1; fi
exit "$bad"
