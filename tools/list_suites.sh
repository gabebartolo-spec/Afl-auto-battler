#!/usr/bin/env bash
# Prints every test suite, one per line: each tests/run_<suite>_tests.gd is a suite.
# Nothing lists suites by hand; tools/run_tests.sh, the CI shards (tools/ci_shards.py),
# the compile preflight and the seed check all discover them this way.
#   tools/list_suites.sh [runner dir, default tests]
dir="${1:-tests}"
for f in "$dir"/run_*_tests.gd; do
	[ -f "$f" ] || continue
	f="${f##*/run_}"
	echo "${f%_tests.gd}"
done
