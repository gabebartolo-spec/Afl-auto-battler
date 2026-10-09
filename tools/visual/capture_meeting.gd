extends SceneTree
## The recruiting panel before the National Draft (RPG-007), on a phone, for
## the director's look. The home-and-away season is skipped, not played.
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_meeting.gd -- \
##       --out PREFIX [--size 390x844] [--scale 3] [--club COL] [--plan defensive] [--seed 2027]
## Writes <prefix>_meeting.png at size x scale pixels (a 390 x 844 phone at 3x
## is 1170 x 2532). Never touches a real save.

func _initialize() -> void:
	_run.call_deferred()


func _shot(frames := 8) -> Image:
	for i in range(frames):
		await process_frame
	return root.get_viewport().get_texture().get_image()


func _run() -> void:
	var out := "meeting"
	var w := 390
	var h := 844
	var scale := 3.0
	var club := "COL"
	var plan := "defensive"
	var seed := 2027
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		match str(cli[i]):
			"--out": out = str(cli[i + 1])
			"--size":
				var wh := str(cli[i + 1]).split("x")
				w = int(wh[0])
				h = int(wh[1])
			"--scale": scale = float(cli[i + 1])
			"--club": club = str(cli[i + 1])
			"--plan": plan = str(cli[i + 1])
			"--seed": seed = int(cli[i + 1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_meeting.save"
	gs.settings_path = "user://capture_meeting.cfg"
	gs.show_real_names = false
	# Every seed set (tools/audit/README.md): reset() rolls a career seed from
	# the global generator, so seed that too, or a rerun shows another class.
	seed(seed)
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	gs.start_season(club, db.club_list(club))
	gs.club_plan = plan
	gs.season.round_index = gs.season.fixture.size()
	gs.open_offseason()
	gs.begin_intake_draft()
	# The window in device pixels, the UI laid out in phone points.
	var px := Vector2i(roundi(w * scale), roundi(h * scale))
	DisplayServer.window_set_size(px)
	root.size = px
	await process_frame
	root.content_scale_size = Vector2i(w, h)
	var scene: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(scene)
	root.content_scale_size = Vector2i(w, h)
	(await _shot()).save_png(out + "_meeting.png")
	quit()
