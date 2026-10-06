#!/usr/bin/env bash
# C15 guard: no test suite may start a season, draft or match from the clock.
# Every suite in ALL_SUITES of tools/run_tests.sh must, in its runner
# (tests/run_<suite>_tests.gd) or its suite file (tests/test_<suite>.gd), either
# pin the seed (SUITE_SEED or replay_seed) or carry a one-line comment
#   ## Seeded by design: <why>
# when it is already deterministic another way (explicit MatchSim or Draft
# seeds, say). A suite with neither fails, named. CI runs it with the dataset
# and harness checks.
#
#   tools/check_suite_seeds.sh
set -u
cd "$(dirname "$0")/.." || exit 1

RUNNER="${RUNNER_FILE:-tools/run_tests.sh}"
all=$(sed -n 's/^ALL_SUITES=(\(.*\))[[:space:]]*$/\1/p' "$RUNNER")
if [ -z "$all" ]; then
	echo "ERROR: no ALL_SUITES list found in $RUNNER" >&2
	exit 1
fi

bad=0
n=0
for s in $all; do
	files=()
	for f in "tests/run_${s}_tests.gd" "tests/test_${s}.gd"; do
		[ -f "$f" ] && files+=("$f")
	done
	if [ "${#files[@]}" -eq 0 ]; then
		echo "ERROR: suite '$s' has no tests/run_${s}_tests.gd" >&2
		bad=1
		continue
	fi
	n=$((n + 1))
	if ! grep -q -E 'SUITE_SEED|replay_seed|## Seeded by design:' "${files[@]}"; then
		echo "ERROR: suite '$s' neither pins SUITE_SEED / replay_seed nor says '## Seeded by design: <why>' (${files[*]})" >&2
		bad=1
	fi
done

if [ "$bad" -ne 0 ]; then
	exit 1
fi
echo "ok: $n suites seeded or seeded by design"
