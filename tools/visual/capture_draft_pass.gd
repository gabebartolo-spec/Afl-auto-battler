extends SceneTree
## The National Draft screen on your own pick, with the Pass and Pick for me
## buttons (and, with --blocked, Pass refused under the minimum list).
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_draft_pass.gd -- --out /tmp/draft_pass [--size 390x844] [--club FRE] [--blocked]
## Writes <out>_sheet.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/draft_pass"
	var club := "FRE"
	var blocked := false
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
		if str(a[i]) == "--club" and i + 1 < a.size():
			club = str(a[i + 1])
		if str(a[i]) == "--size" and i + 1 < a.size():
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
		if str(a[i]) == "--blocked":
			blocked = true
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.replay_seed = 2027
	state.reset()
	state.start_season(club, db.club_list(club))
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	if not state.begin_intake_draft():
		print("no draft")
		quit(1)
		return
	var draft = state.draft
	if blocked:
		draft.existing_sizes[club] = 30
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	for i in range(6):
		await process_frame
	var done: Button = ui.find_child("MeetingDone", true, false)
	if done != null:
		done.emit_signal("pressed")
	var guard := 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	for i in range(12):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
