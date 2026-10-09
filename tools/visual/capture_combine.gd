extends SceneTree
## The National Draft Combine on a phone: the pool sorted on the 20 m sprint,
## then one prospect's testing. Plays a season out first, so it takes a while.
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_combine.gd -- --out PREFIX
## Writes <prefix>_pool.png and <prefix>_prospect.png. Never touches a real save.

func _initialize() -> void:
	_run.call_deferred()


func _shot(frames := 8) -> Image:
	for i in range(frames):
		await process_frame
	return root.get_viewport().get_texture().get_image()


func _run() -> void:
	var out := "combine"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_combine.save"
	gs.settings_path = "user://capture_combine.cfg"
	gs.reset()
	gs.start_season("MEL", db.club_list("MEL"))
	var g := 0
	while not gs.season.is_season_over() and g < 60:
		gs.advance()
		g += 1
	gs.begin_intake_draft()
	gs.draft_meeting_year = gs.season_year
	root.size = Vector2i(390, 844)
	var scene: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(scene)
	await _shot(4)
	scene.set("_combine", "sprint")
	scene.set("_combine_open", true)
	scene.call("_show_board")
	(await _shot()).save_png(out + "_pool.png")
	var rows: Array = scene.call("_board_rows")
	if not rows.is_empty():
		scene.call("_open_player", str(rows[0]["id"]))
		(await _shot()).save_png(out + "_prospect.png")
	quit()
