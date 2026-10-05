extends SceneTree
## Visual review tool for talking a veteran round on the off-season screen,
## on a phone (390x844):
##   godot --path . --script tools/visual/capture_retiring.gd -- --out /tmp/retiring
## Writes <out>_sheet.png: the Retiring section before and after asking.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(4):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/retiring"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season("GEE", db.club_list("GEE"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var best: Array = state.my_list.duplicate()
	best.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	for k in range(2):
		var p: Dictionary = best[k]
		p["age"] = 37.0
		p["morale"] = 70
		state.season_tally[str(p["id"])] = {"club": "GEE", "games": 20 - k * 16, "goals": 0, "goals_ha": 0,
				"disposals": 0, "distance_run": 0.0, "influence": 0.0, "votes": 0, "bf": 0, "polled": 0, "coaches": 0}
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	var scene = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	var shots := [await _shot()]
	for r in state.retiring_players():
		if bool(r["can_ask"]):
			state.talk_round(str(r["p"]["id"]))
	scene._build()
	shots.append(await _shot())
	var sheet := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
