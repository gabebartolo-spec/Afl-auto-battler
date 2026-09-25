extends SceneTree
## Run against an EXPORTED pack, not the source tree (tools/check_export_data.sh
## does this): godot --headless --main-pack game.pck --script <this file>
## An exported build only contains a data CSV whose .import uses the "keep"
## importer. The game must find its player data there with real bio fields -
## never quietly load players without ages.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var db = root.get_node("GameDB")
	var failures: Array[String] = []
	var path: String = db.PLAYERS_ENRICHED_CSV
	if not FileAccess.file_exists(path):
		failures.append("%s is missing from the exported pack" % path)
	if not db.loaded or db.players.is_empty():
		failures.append("GameDB loaded no players from the exported pack")
	var no_age := 0
	var no_dob := 0
	for p in db.players:
		if float(p.get("age", 0.0)) <= 0.0:
			no_age += 1
		if str(p.get("dob", "")) == "":
			no_dob += 1
	if no_age > 0:
		failures.append("%d of %d players have no age" % [no_age, db.players.size()])
	if no_dob > 0:
		failures.append("%d of %d players have no date of birth" % [no_dob, db.players.size()])
	for f in failures:
		push_error("Export data check: " + f)
	print("Export data check: %d players, %d failures" % [db.players.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
