extends SceneTree
## Visual review tool for the sit-down when a promised run ends (RPG-001), on
## the Hub on a phone (390x844):
##   godot --path . --script tools/visual/capture_backing_talk.gd -- --out /tmp/talk
## Writes <out>_sheet.png: a key back's run that went well, a midfielder's quiet
## one, a ruck's broken promise.

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
	# A key back, a midfielder and a ruck: each is judged on his own job's numbers.
	var pick := func(kind):
		for q in state.my_list:
			if Backing.kpi_kind(q) == kind:
				return q
		return state.my_list[0]
	var kids := [pick.call("key_back"), pick.call("mid"), pick.call("ruck")]
	var runs := [
		{"state": "done", "games": 3, "played": 3, "tot": {"spoils": 17, "marks": 14}},
		{"state": "done", "games": 3, "played": 3, "tot": {"disposals": 28, "clearances": 2}},
		{"state": "broken", "games": 3, "played": 1, "tot": {"hitouts": 14, "clearances": 1}},
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
