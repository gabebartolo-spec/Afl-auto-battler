#!/usr/bin/env bash
# Run every check CI runs, locally or in GitHub Actions:
#   1. import the project (a script that fails to compile fails the run)
#   2. every Godot test suite in tests/, each with a time limit so a hang
#      fails fast instead of eating the runner
#   3. the dataset check and the intake/development harness
#
#   GODOT=/path/to/godot tools/run_tests.sh          # default: godot on PATH
#   SUITE_TIMEOUT=900 tools/run_tests.sh ai finals   # just some suites
#
# Exits nonzero if anything failed.
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-900}"
ALL_SUITES=(draft draft_ui intake intake_ui finals save career_ui potential ai training selection injuries awards contracts league match_game calibration balance)
[ "$#" -gt 0 ] && SUITES=("$@") || SUITES=("${ALL_SUITES[@]}")

LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
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
	timeout "$SUITE_TIMEOUT" "$GODOT" --headless --path . --script "$runner" > "$log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	result=$(grep -E "[0-9]+ checks, [0-9]+ failures" "$log" | tail -1)
	if [ "$code" = 124 ]; then
		status="FAIL"; detail="timed out after ${SUITE_TIMEOUT}s"
	elif [ "$code" != 0 ] || [ -z "$result" ]; then
		status="FAIL"; detail="${result:-no result (exit $code)}"
	else
		status="pass"; detail="$result"
	fi
	printf '%-5s %-11s %4ss  %s\n' "$status" "$suite" "$secs" "$detail"
	if [ "$status" = FAIL ]; then
		failed=1
		note_error "suite '$suite' failed: $detail"
		[ "$in_ci" = 1 ] && echo "::group::$suite log (errors)"
		grep -E -A4 "^ERROR|SCRIPT ERROR" "$log" | head -60
		[ "$in_ci" = 1 ] && echo "::endgroup::"
	fi
	summary+=("| $suite | $status | $detail (${secs}s) |")
done

echo "== Dataset check"
if python3 tools/validate_data.py > "$LOG_DIR/validate.log" 2>&1; then
	summary+=("| validate_data | pass | |")
else
	tail -15 "$LOG_DIR/validate.log"
	note_error "tools/validate_data.py found problems"
	failed=1
	summary+=("| validate_data | FAIL | see log |")
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
