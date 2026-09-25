#!/usr/bin/env bash
# Guard the exported build's data path. The editor and every other test read
# the source tree, where all CSVs exist whatever their importer - so a CSV on
# Godot's default csv_translation importer (which an export leaves out) goes
# unnoticed there. This exports a real .pck and runs the game data load from
# that pack alone.
#
#   GODOT=/path/to/godot tools/check_export_data.sh
#
# Step 1 (no Godot needed): every data/*.csv must be imported with "keep".
# Step 2: export a pack from the tracked + working-tree files with a throwaway
# preset, then run tests/export_data_check.gd against the pack in an empty
# directory: the player data must be there, loaded, with ages.
set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
GODOT="${GODOT:-godot}"
fail=0

echo "-- data CSV import settings"
for csv in data/*.csv; do
	imp="$csv.import"
	if [ ! -f "$imp" ]; then
		echo "FAIL: $csv has no .import file (Godot would default it to a translation import)"
		fail=1
	elif ! grep -q '^importer="keep"' "$imp"; then
		echo "FAIL: $imp is not importer=\"keep\" ($(grep '^importer=' "$imp")) - an export would leave $csv out"
		fail=1
	fi
done
[ "$fail" = 0 ] && echo "all data CSVs use the keep importer"

echo "-- exported pack data load"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/project" "$WORK/run"
# Tracked and new (unignored) files as they are on disk: the same set an
# export from this checkout would see, without .godot/ caches or builds.
git ls-files -co --exclude-standard -z | (cd "$ROOT" && tar --null -T - -cf -) | tar -xf - -C "$WORK/project"
cat > "$WORK/project/export_presets.cfg" <<'PRESET'
[preset.0]

name="DataCheck"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""

[preset.0.options]

binary_format/embed_pck=false
binary_format/architecture="x86_64"
PRESET
"$GODOT" --headless --path "$WORK/project" --import > "$WORK/import.log" 2>&1
if ! "$GODOT" --headless --path "$WORK/project" --export-pack "DataCheck" "$WORK/run/game.pck" > "$WORK/export.log" 2>&1 \
		|| [ ! -s "$WORK/run/game.pck" ]; then
	tail -20 "$WORK/export.log"
	echo "FAIL: could not export a pack"
	exit 1
fi
# Run from an empty directory so res:// can only resolve inside the pack.
if (cd "$WORK/run" && timeout 300 "$GODOT" --headless --main-pack game.pck \
		--script "$ROOT/tests/export_data_check.gd") > "$WORK/check.log" 2>&1; then
	grep "Export data check:" "$WORK/check.log"
else
	grep -E "Export data check|^ERROR" "$WORK/check.log" | head -20
	echo "FAIL: the exported pack does not load complete player data"
	fail=1
fi
exit "$fail"
