extends SceneTree
## Draft night (P-15) for the look gate: the live board with your club on the
## clock, the board mid-replay, the stage beat on your pick, and a clip of one
## round (your pick on the stage, then the rival picks filling the board).
## Needs a real renderer (motion on):
##   godot --path . --windowed [--fixed-fps 25] --script tools/visual/capture_draft_night.gd -- --out /tmp/night [--size 390x844] [--club FRE] [--seed 2027] [--clip]
## Writes <out>_board.png, <out>_replay.png, <out>_beat.png, and with --clip
## <out>_clip_NNN.png, every rendered frame: your pick on the stage, the fade,
## part of the replay, then a finger's tap on the board that finishes it. Run
## the clip with --fixed-fps so each frame is one even step of game time.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	var out := "/tmp/night"
	var club := "FRE"
	var clip := false
	var seed := 2027
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
		if str(a[i]) == "--seed" and i + 1 < a.size():
			seed = int(a[i + 1])
		if str(a[i]) == "--clip":
			clip = true
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.replay_seed = seed
	state.reset()
	state.start_season(club, db.club_list(club))
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	if not state.begin_intake_draft():
		print("no draft")
		quit(1)
		return
	var draft = state.draft
	# The canvas is the size a player's screen gives the game (1280x720 on a PC,
	# 390x844 on a phone): undo this machine's display density, as
	# capture_culture.gd does.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var base: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, base)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
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
	# First pick made, so the board's last three carry rival picks: pick, cut
	# the show, and the board waits on your next pick.
	ui.call("_on_pick_for_me")
	ui.call("_finish_night")
	await _wait(0.6)
	print("view %s, usable %s, recent rows %d" % [str(root.get_visible_rect().size), str(ui.call("_usable_size")),
			ui.find_children("RecentPick_*", "Control", true, false).size()])
	_shot(out + "_board.png")
	# Your next pick: the stage beat, at the moment his arms go up.
	var frame := 0
	ui.call("_on_pick_for_me")
	if clip:
		# Every frame: the beat, its fade, five rival picks, then a finger on the board.
		var picks_seen := 0
		var last_status := ""
		var tapped := false
		var after_tap := 0
		while frame < 600 and after_tap < 15:
			await process_frame
			_shot("%s_clip_%03d.png" % [out, frame])
			frame += 1
			var st: Label = ui.find_child("DraftStatus", true, false)
			if ui.find_child("DraftNightStage", true, false) == null and ui.call("replaying") and st != null:
				if st.text != last_status:
					picks_seen += 1
					last_status = st.text
				if picks_seen > 6 and not tapped:
					tapped = true
					_tap(ui.find_child("LiveBoard", true, false))
			if tapped or (ui.find_child("DraftNightStage", true, false) == null and not ui.call("replaying")):
				after_tap += 1
		print("clip frames ", frame, " tapped ", tapped)
		quit(0)
		return
	await _wait(1.9)
	_shot(out + "_beat.png")
	# A tap ends the beat; part-way through the replay.
	var stage: Button = ui.find_child("DraftNightStage", true, false)
	if stage != null:
		stage.emit_signal("pressed")
	await _wait(0.3 * 4 + 0.25)
	_shot(out + "_replay.png")
	quit(0)


## A finger's tap at the control's centre (as tests/tap.gd does).
func _tap(c: Control) -> void:
	if c == null:
		return
	var at: Vector2 = load("res://tests/tap.gd").screen_point(c)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
