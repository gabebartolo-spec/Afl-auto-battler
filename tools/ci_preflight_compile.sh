#!/usr/bin/env bash
# Compile-checks every test runner headless before the CI shards start, so a runner
# that does not compile, or whose load hangs, fails in seconds naming the runner
# instead of burning the 900 s suite timeout (that hang cost 15 minutes of CI three
# times on 2026-10-17/18, each time a runner naming a class whose load chain reaches an
# autoload; the fix is load() by path inside _run(), see
# .claude/skills/afl-godot-tests/SKILL.md).
#
#   GODOT=/path/to/godot tools/ci_preflight_compile.sh               # every suite (tools/list_suites.sh)
#   GODOT=... tools/ci_preflight_compile.sh tests/run_ai_tests.gd    # just these scripts
#
# Fast path: ONE Godot process loads every runner in turn (about 6 s for all 53 on a
# development PC, against about a second of start-up per runner one by one), under a
# PREFLIGHT_TIMEOUT total (default 30 s). If it fails or times out, the last "LOADING"
# line names the runner; if that is missing, each runner is retried alone under
# PREFLIGHT_RUNNER_TIMEOUT (default 20 s) until one fails. Exits 1 naming the runner.
#
# Then a second pass compiles each runner alone with --check-only --script, the way a
# suite starts it, before the autoloads exist (see the comment above that pass). With no
# arguments that pass also covers every other `extends SceneTree` harness under tools/
# (balance workers, audits, perf probes, captures), which start the same way.
#
# The runners are every tests/run_<suite>_tests.gd (tools/list_suites.sh), the same
# suites tools/run_tests.sh and the CI shards run. The project is imported first, because a fresh
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
	all=$(tools/list_suites.sh)
	if [ -z "$all" ]; then
		echo "ERROR: no tests/run_*_tests.gd found" >&2
		exit 1
	fi
	runners=()
	for s in $all; do runners+=("tests/run_${s}_tests.gd"); done
	# Second pass only: the tools/ harnesses run with godot --script too (tools/balance.sh,
	# audit.yml, captures), so a cast to a class that reaches an autoload breaks them the
	# same way. They are not loaded in the fast pass, which runs their _initialize().
	mapfile -t harnesses < <(grep -rlE '^extends SceneTree' tools --include='*.gd' | sort)
fi
harnesses=("${harnesses[@]+"${harnesses[@]}"}")

note_error() {  # message
	if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::$1"; else echo "ERROR: $1"; fi
}

fail() {  # what failed, reason
	note_error "$1: $2"
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error|^ERROR" "$LOG" | head -20
	# A crash (signal, abort) names no script: show the end of the log, where
	# Godot prints its backtrace, so the failure says where it died.
	if ! grep -qE "SCRIPT ERROR|Parse Error|Compile Error|^ERROR" "$LOG"; then
		echo "--- last 60 lines of the Godot log ---"
		tail -60 "$LOG"
	fi
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

# PREFLIGHT_EXTRA="path path": more scripts to check (used to prove the check fails).
# shellcheck disable=SC2206
[ -n "${PREFLIGHT_EXTRA:-}" ] && runners+=(${PREFLIGHT_EXTRA})
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
echo "ok: ${#runners[@]} test runners load ($(( $(date +%s) - start )) s)"

# Second pass: compile each runner exactly as a suite starts it (godot --script), where
# the runner compiles BEFORE the autoloads exist. The fast path above load()s inside
# _initialize(), after the autoload names are registered, so it cannot see a runner
# that names a class whose chain reaches GameDB or ScreenLayout (the matchday break of
# 2026-11-05, PR #978: "Identifier not found: GameDB", then the 3000 s nightly timeout).
# --check-only compiles without running; it exits 0 even on a compile error, so the
# output is searched. PREFLIGHT_JOBS parallel Godots (default: the CPU count).
jobs="${PREFLIGHT_JOBS:-$(nproc 2>/dev/null || echo 4)}"
check_one() {  # runner -> prints "OK <runner>" or "FAIL <runner>: why" plus the errors
	local out code
	out=$(timeout "$RUNNER_LIMIT" "$GODOT" --headless --path . --check-only --script "$1" 2>&1)
	code=$?
	if [ "$code" = 124 ]; then
		echo "FAIL $1: --check-only timed out after $RUNNER_LIMIT s"
	elif [ "$code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" <<< "$out"; then
		echo "FAIL $1: does not compile as godot --script (exit $code)"
		grep -E "SCRIPT ERROR|Parse Error|Compile Error|^ +at: " <<< "$out" | head -8
	else
		echo "OK $1"
	fi
}
export -f check_one
export GODOT RUNNER_LIMIT
start=$(date +%s)
scripts=("${runners[@]}" "${harnesses[@]+"${harnesses[@]}"}")
printf '%s
' "${scripts[@]}" | xargs -P "$jobs" -I{} bash -c 'check_one "$1"' _ {} > "$LOG" 2>&1
bad=$(grep -c '^FAIL ' "$LOG")
if [ "$bad" != 0 ] || [ "$(grep -c '^OK ' "$LOG")" != "${#scripts[@]}" ]; then
	grep -vE '^OK ' "$LOG" | head -40
	note_error "$bad script(s) do not compile as godot --script: $hang_hint"
	exit 1
fi
echo "ok: ${#runners[@]} test runners and ${#harnesses[@]} tools harnesses compile as godot --script ($(( $(date +%s) - start )) s, $jobs at a time)"
