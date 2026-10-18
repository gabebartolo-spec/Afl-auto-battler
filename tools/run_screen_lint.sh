#!/usr/bin/env bash
# Builders run this before any capture reaches the lead: the hub, the draft and the match pre-bounce
# pane at phone (390x844) and PC (1280x720). Use the team's Godot wrapper and an isolated APPDATA:
#   SCREENLINT_GODOT="bash <scratchpad>/godot_quiet.sh" tools/run_screen_lint.sh <yourname> [-- --club MEL]
# (claim a Godot slot around it, in the same command). Exit 1 when any screen has a FIX.
set -u
cd "$(dirname "$0")/.." || exit 1
RUNNER="${SCREENLINT_GODOT:-godot --headless}"
NAME="${1:-me}"
export APPDATA="${SCREENLINT_APPDATA:-${TMPDIR:-/tmp}/appdata_screenlint_$NAME}"
mkdir -p "$APPDATA"
EXTRA=()
if [ "${2:-}" = "--" ]; then EXTRA=("${@:3}"); fi
rc=0
for screen in hub draft prebounce; do
  for size in 390x844 1280x720; do
    out=$($RUNNER --path . --script tools/visual/screen_lint.gd -- --screen "$screen" --size "$size" "${EXTRA[@]}" 2>&1)
    echo "$out" | awk '/^SCREEN LINT/{on=1} on{print} /^(PASS|FIX)/{on=0}' | cat
    echo "$out" | grep -E "^SCRIPT ERROR" | head -3
    echo "$out" | grep -qE "^PASS" || rc=1
    echo
  done
done
exit $rc
