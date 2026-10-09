extends SceneTree
## Visual review tool for the sit-down when a promised run ends (RPG-001), on
## the Hub on a phone (390x844):
##   godot --path . --script tools/visual/capture_backing_talk.gd -- --out /tmp/talk
## Writes <out>_sheet.png: a run that went well, a quiet one, a broken promise.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/talk"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var Backing = load("res://scripts/sim/Backing.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	state.start_season("GEE", db.club_list("GEE"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var kids: Array = state.my_list.duplicate()
	kids.sort_custom(func(x, y): return float(x.get("age", 30.0)) < float(y.get("age", 30.0)))
	var runs := [
		{"state": "done", "games": 3, "played": 3, "goals": 4, "disp": 39},
		{"state": "done", "games": 3, "played": 3, "goals": 0, "disp": 22},
		{"state": "broken", "games": 3, "played": 1, "goals": 0, "disp": 11},
	]
	var shots := []
	for i in range(runs.size()):
		state.backing_talk = Backing.talk(kids[i], runs[i])
		state.media_conference = {}
		var hub = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		shots.append(await _shot())
		hub.queue_free()
		await process_frame
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	quit(0)
