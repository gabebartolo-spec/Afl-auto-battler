#!/usr/bin/env bash
# The test runner must not report green when checks went missing. Runs one
# quick real suite through tools/run_tests.sh three ways:
#   1. with its real floor           -> must pass
#   2. with an impossibly high floor -> must fail ("checks went missing")
#   3. with no floor at all          -> must fail
set -u
cd "$(dirname "$0")/.." || exit 1
SUITE=selection
real=$(grep -E "^$SUITE[[:space:]]" tests/expected_checks.txt | awk '{print $2}')
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0

printf '%s %s\n' "$SUITE" "$real" > "$tmp/ok.txt"
printf '%s %s\n' "$SUITE" 100000 > "$tmp/high.txt"
printf 'nothing 1\n' > "$tmp/none.txt"

run() {  # floor file
	EXPECTED_CHECKS="$1" SUITES_ONLY=1 tools/run_tests.sh "$SUITE" > "$tmp/out.txt" 2>&1
}

if run "$tmp/ok.txt"; then echo "ok: the real floor passes"; else echo "FAIL: the real floor should pass"; cat "$tmp/out.txt"; bad=1; fi
if run "$tmp/high.txt"; then echo "FAIL: a suite short of its floor passed"; bad=1
elif grep -q "checks went missing" "$tmp/out.txt"; then echo "ok: missing checks fail the run"
else echo "FAIL: short suite failed without saying why"; cat "$tmp/out.txt"; bad=1; fi
if run "$tmp/none.txt"; then echo "FAIL: a suite with no floor passed"; bad=1
elif grep -q "has no floor" "$tmp/out.txt"; then echo "ok: a suite with no floor fails"
else echo "FAIL: unfloored suite failed without saying why"; cat "$tmp/out.txt"; bad=1; fi
exit "$bad"
