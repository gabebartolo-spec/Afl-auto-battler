#!/usr/bin/env bash
# Run every check CI runs, locally or in GitHub Actions:
#   1. import the project (a script that fails to compile fails the run)
#   2. every Godot test suite in tests/, each with a time limit so a hang
#      fails fast instead of eating the runner; a suite whose log shows a
#      script error fails even if every check it reached passed
#   3. the dataset check and the intake/development harness
#
# A green suite must mean every check ran:
#   - suites run on a fixed frame clock (--fixed-fps), so a busy machine
#     cannot change how far a match plays between two checks;
#   - every suite has a floor in tests/expected_checks.txt; a suite that
#     reports fewer checks fails ("checks went missing"), and a suite with no
#     floor fails until one is added;
#   - a check a suite skips on purpose prints "SKIP: <reason>", and the
#     summary shows how many were skipped.
#
#   GODOT=/path/to/godot tools/run_tests.sh          # default: godot on PATH
#   SUITE_TIMEOUT=900 tools/run_tests.sh ai finals   # just some suites
#
# Exits nonzero if anything failed.
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-900}"
# The check floors (tools/test_run_tests.sh points this at its own file).
EXPECTED_CHECKS="${EXPECTED_CHECKS:-tests/expected_checks.txt}"
# SUITES_ONLY=1 skips the dataset, export and harness steps after the suites.
SUITES_ONLY="${SUITES_ONLY:-0}"
ALL_SUITES=(draft draft_ui intake intake_ui expansion finals save chronology career coaches coach_market coach_pathway coach_effects career_ui potential ratings ai training selection matchup matchday roles injuries awards achievements contracts league club match_game pressure match_visual league_balance calibration balance)
[ "$#" -gt 0 ] && SUITES=("$@") || SUITES=("${ALL_SUITES[@]}")

LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
# Suites save careers and settings under user://, which Godot puts in one
# folder per project name - shared by every checkout and worktree. Give this
# run its own user data (Godot on Linux reads XDG_DATA_HOME), so two runs at
# once cannot overwrite each other's saves. Only the suites use it: the
# import and export steps keep the real data dir and its export templates.
RUN_DATA="$(mktemp -d)"
trap 'rm -rf "$RUN_DATA"' EXIT
failed=0
summary=()
in_ci=0
[ -n "${GITHUB_ACTIONS:-}" ] && in_ci=1

note_error() {  # message
	if [ "$in_ci" = 1 ]; then echo "::error::$1"; else echo "ERROR: $1"; fi
}

echo "== Godot: $("$GODOT" --headless --version 2>/dev/null | tail -1)"
echo "== Importing the project"
timeout 600 "$GODOT" --headless --path . --editor --import > "$LOG_DIR/import.log" 2>&1
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log"
	note_error "scripts failed to compile during import"
	failed=1
	summary+=("| import | FAIL | scripts failed to compile |")
else
	summary+=("| import | pass | |")
fi

for suite in "${SUITES[@]}"; do
	runner="tests/run_${suite}_tests.gd"
	log="$LOG_DIR/$suite.log"
	start=$(date +%s)
	XDG_DATA_HOME="$RUN_DATA" timeout "$SUITE_TIMEOUT" "$GODOT" --headless --fixed-fps 60 --path . --script "$runner" > "$log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	result=$(grep -E "[0-9]+ checks, [0-9]+ failures" "$log" | tail -1)
	if [ "$code" = 124 ]; then
		status="FAIL"; detail="timed out after ${SUITE_TIMEOUT}s"
	elif [ "$code" != 0 ] || [ -z "$result" ]; then
		status="FAIL"; detail="${result:-no result (exit $code)}"
	elif grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then
		# A runtime error aborts the test function it hit, so the checks after
		# it never run and the suite can still report 0 failures.
		status="FAIL"; detail="$result, but a script error stopped part of the suite"
	else
		status="pass"; detail="$result"
	fi
	# Every check must have run: compare with the suite's floor.
	ran=$(echo "$result" | grep -oE "[0-9]+ checks" | head -1 | grep -oE "[0-9]+")
	floor=$(grep -E "^$suite[[:space:]]" "$EXPECTED_CHECKS" 2>/dev/null | awk '{print $2}')
	skipped=$(grep -c "^SKIP:" "$log")
	if [ "$status" = pass ] && [ -z "$floor" ]; then
		status="FAIL"; detail="$result, but $EXPECTED_CHECKS has no floor for '$suite'"
	elif [ "$status" = pass ] && [ -n "$ran" ] && [ "$ran" -lt "$floor" ]; then
		status="FAIL"; detail="$result, but only $ran of at least $floor checks ran: checks went missing"
	fi
	if [ "$skipped" -gt 0 ]; then
		detail="$detail ($skipped skipped on purpose)"
	fi
	printf '%-5s %-11s %4ss  %s\n' "$status" "$suite" "$secs" "$detail"
	if [ "$status" = FAIL ]; then
		failed=1
		note_error "suite '$suite' failed: $detail"
	[ "$in_ci" = 1 ] && echo "::group::$suite log (errors)"
	grep -E -A4 "^ERROR|SCRIPT ERROR" "$log" | head -60
	[ "$in_ci" = 1 ] && echo "::endgroup::"
	# Surface parse errors and failed-check messages as job annotations so a
	# red run is diagnosable without downloading the full log.
	if [ "$in_ci" = 1 ]; then
		grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$log" | head -20 | while IFS= read -r l; do
			printf '::error::%s-log::%s\n' "$suite" "$l"
		done
		grep -E "^ERROR" "$log" | head -30 | while IFS= read -r l; do
			printf '::error::%s-check::%s\n' "$suite" "${l#ERROR: }"
		done
	fi
	fi
	summary+=("| $suite | $status | $detail (${secs}s) |")
done

if [ "$SUITES_ONLY" != 1 ]; then
echo "== Dataset check"
if python3 tools/validate_data.py > "$LOG_DIR/validate.log" 2>&1; then
	summary+=("| validate_data | pass | |")
else
	tail -15 "$LOG_DIR/validate.log"
	note_error "tools/validate_data.py found problems"
	failed=1
	summary+=("| validate_data | FAIL | see log |")
fi

echo "== Exported-build data check"
if GODOT="$GODOT" tools/check_export_data.sh > "$LOG_DIR/export_data.log" 2>&1; then
	summary+=("| export_data | pass | |")
else
	tail -15 "$LOG_DIR/export_data.log"
	note_error "tools/check_export_data.sh: an exported build would not load complete player data"
	failed=1
	summary+=("| export_data | FAIL | see log |")
fi

echo "== Intake / development harness"
if python3 tools/intake_harness.py --quiet > "$LOG_DIR/intake_harness.log" 2>&1; then
	summary+=("| intake_harness | pass | |")
else
	tail -15 "$LOG_DIR/intake_harness.log"
	note_error "tools/intake_harness.py failed"
	failed=1
	summary+=("| intake_harness | FAIL | see log |")
fi
fi

# The harness checks itself: a truncated or unfloored suite must fail.
if [ "$SUITES_ONLY" != 1 ] && [ "$#" -eq 0 ]; then
	echo "== Harness self-test"
	if GODOT="$GODOT" tools/test_run_tests.sh > "$LOG_DIR/harness_selftest.log" 2>&1; then
		summary+=("| harness_selftest | pass | |")
	else
		tail -15 "$LOG_DIR/harness_selftest.log"
		note_error "tools/test_run_tests.sh: the test runner no longer catches missing checks"
		failed=1
		summary+=("| harness_selftest | FAIL | see log |")
	fi
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Test results"
		echo "| Check | Result | Detail |"
		echo "|---|---|---|"
		printf '%s\n' "${summary[@]}"
	} >> "$GITHUB_STEP_SUMMARY"
fi
echo "Logs: $LOG_DIR"
[ "$failed" = 0 ] && echo "All checks passed." || echo "Some checks FAILED."
exit "$failed"
