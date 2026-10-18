#!/usr/bin/env bash
# Compile-checks every test runner headless before the CI shards start, so a runner
# that does not compile, or whose load hangs, fails in seconds naming the runner
# instead of burning the 900 s suite timeout (that hang cost 15 minutes of CI three
# times on 2026-10-17/18, each time a runner naming a class whose load chain reaches an
# autoload; the fix is load() by path inside _run(), see
# .claude/skills/afl-godot-tests/SKILL.md).
#
#   GODOT=/path/to/godot tools/ci_preflight_compile.sh               # every suite in ALL_SUITES
#   GODOT=... tools/ci_preflight_compile.sh tests/run_ai_tests.gd    # just these scripts
#
# Fast path: ONE Godot process loads every runner in turn (about 6 s for all 53 on a
# development PC, against about a second of start-up per runner one by one), under a
# PREFLIGHT_TIMEOUT total (default 30 s). If it fails or times out, the last "LOADING"
# line names the runner; if that is missing, each runner is retried alone under
# PREFLIGHT_RUNNER_TIMEOUT (default 20 s) until one fails. Exits 1 naming the runner.
#
# The runners come from ALL_SUITES in tools/run_tests.sh (tools/check_ci_shards.sh keeps
# that identical to tools/ci_shards.txt). The project is imported first, because a fresh
# checkout has no class cache and every named class would look undeclared;
# PREFLIGHT_SKIP_IMPORT=1 skips that when it is already imported.
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
TOTAL_LIMIT="${PREFLIGHT_TIMEOUT:-30}"
RUNNER_LIMIT="${PREFLIGHT_RUNNER_TIMEOUT:-20}"
CHECKER="tools/ci_preflight_compile.gd"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

if [ "$#" -gt 0 ]; then
	runners=("$@")
else
	all=$(sed -n 's/^ALL_SUITES=(\(.*\))[[:space:]]*$/\1/p' tools/run_tests.sh | tr -d '\r')
	if [ -z "$all" ]; then
		echo "ERROR: no ALL_SUITES list found in tools/run_tests.sh" >&2
		exit 1
	fi
	runners=()
	for s in $all; do runners+=("tests/run_${s}_tests.gd"); done
fi

note_error() {  # message
	if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::$1"; else echo "ERROR: $1"; fi
}

fail() {  # what failed, reason
	note_error "$1: $2"
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error|^ERROR" "$LOG" | head -20
	exit 1
}

hang_hint="a runner must not name a class whose load chain reaches an autoload: load() it by path inside _run()"

# One Godot run over the given runner paths; sets code, leaves the output in $LOG.
run_godot() {  # seconds, paths...
	timeout "$1" "$GODOT" --headless --path . --script "$CHECKER" -- "${@:2}" > "$LOG" 2>&1
	code=$?
}

start=$(date +%s)
if [ "${PREFLIGHT_SKIP_IMPORT:-0}" != 1 ]; then
	timeout 600 "$GODOT" --headless --path . --editor --import > "$LOG" 2>&1
	import_code=$?
	if [ "$import_code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$LOG"; then
		fail "the project import" "scripts failed to compile during import (exit $import_code)"
	fi
	echo "import: $(( $(date +%s) - start )) s"
fi

for r in "${runners[@]}"; do
	[ -f "$r" ] || { note_error "test runner $r: file not found"; exit 1; }
done

start=$(date +%s)
run_godot "$TOTAL_LIMIT" "${runners[@]}"
if [ "$code" != 0 ] || [ "$(grep -c '^OK ' "$LOG")" != "${#runners[@]}" ]; then
	why="did not compile (exit $code)"
	[ "$code" = 124 ] && why="timed out: the load hung ($hang_hint)"
	last=$(grep -E "^(LOADING|FAIL) " "$LOG" | tail -1)
	if [ -n "$last" ]; then
		fail "test runner ${last#* }" "$why"
	fi
	# No progress line reached the log: find the culprit one runner at a time.
	for r in "${runners[@]}"; do
		run_godot "$RUNNER_LIMIT" "$r"
		if [ "$code" = 124 ]; then fail "test runner $r" "timed out after ${RUNNER_LIMIT} s: the load hung ($hang_hint)"; fi
		if [ "$code" != 0 ] || ! grep -q '^OK ' "$LOG"; then fail "test runner $r" "did not compile (exit $code)"; fi
	done
	note_error "test runners: the combined check failed ($why) but every runner passed alone"
	exit 1
fi
echo "ok: ${#runners[@]} test runners compile ($(( $(date +%s) - start )) s)"
