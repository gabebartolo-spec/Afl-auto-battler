extends SceneTree
## Visual review tool for Season stats > Trophy room (the Stats patch, ROADMAP
## §1.11). Needs a real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_trophies \
##       -f args="--size 390x844"
## A fresh Collingwood career plays its first season out, then the honour roll
## is seeded so every shelf has something on it: that season made a
## premiership (with a Brownlow and an All-Australian), plus an older season
## from before the room recorded records and All-Australians. Writes
## <out>_empty.png (before the first game), <out>.png, <out>_lower.png
## (scrolled to your seasons), <out>_flag.png and <out>_medal.png (the sheets).
##   --size WxH   window size (default 390x844)    --light   light appearance
## Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "trophies"
	var mode := "dark"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--light":
				mode = "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_trophies.save"
	state.settings_path = "user://capture_trophies.cfg"
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.start_season("COL", db.club_list("COL"))
	# The hub's first-visit note would sit over the room.
	state.set_setting("seen_season_stats_intro", true)
	UK.apply_appearance(mode)
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	var hub_script = load("res://scripts/ui/StatsHubScene.gd")
	hub_script.current = "trophies"
	var scene: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	_save(out + "_empty.png")
	scene.queue_free()
	await _frames(2)
	var guard := 0
	while not state.season_is_over() and guard < 40:
		state.advance()
		guard += 1
	var year: int = state.season_year
	var entry: Dictionary = state.honour_roll.back()
	var ids := []
	for p in state.season.lists["COL"]:
		ids.append(str(p["id"]))
	entry["premier"] = "COL"
	entry["runner_up"] = "CAR"
	entry["my_position"] = 1
	# A record that fits a minor premier (the season played may not).
	entry["my_record"] = "18-5-0"
	entry["brownlow"] = [{"id": ids[0], "club": "COL", "votes": 31}]
	entry["my_aa"] = [ids[2], ids[5]]
	var old := {"year": year - 1, "my_club": "COL", "premier": "GEE", "runner_up": "COL", "my_position": 3,
		"brownlow": [], "coleman": [{"id": ids[4], "club": "COL", "goals": 71}], "rising_star": [],
		"coaches_award": [], "my_bf": [{"id": ids[1], "club": "COL", "bf": 120}]}
	state.honour_roll = [old, entry]
	scene = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	_save(out + ".png")
	var sc: ScrollContainer = scene.find_child("StatsScroll", true, false)
	var t: Control = scene.find_child("Tenure", true, false)
	if sc != null and t != null:
		sc.scroll_vertical = int(t.global_position.y - sc.global_position.y) + sc.scroll_vertical
		await _frames(6)
		_save(out + "_lower.png")
		sc.scroll_vertical = 0
		await _frames(4)
	await _tap(scene, "Club_premiership_%d" % year)
	_save(out + "_flag.png")
	scene.call("handle_back")
	await _frames(6)
	await _tap(scene, "Player_0")
	_save(out + "_medal.png")
	quit()


func _tap(scene: Node, node_name: String) -> void:
	var b: Button = scene.find_child(node_name, true, false)
	if b == null:
		push_error("no " + node_name)
		return
	b.emit_signal("pressed")
	await _frames(10)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
