extends SceneTree
## The role trial on a phone (story card "Try him as a ..."): the selection screen with
## "Trial: 2 games left" beside him, then the result card after the third game, passed
## and failed. Seeded; never touches a real save.
##   godot --path . --script tools/visual/capture_trial.gd -- --out PREFIX [--club FRE] [--seed 2031] [--size 390x844]
## Writes <prefix>_selection.png, <prefix>_worked.png, <prefix>_not_yet.png and prints
## the position, the games left and his role before, during and after.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _fresh(club: String, seed_: int) -> void:
	var gs = root.get_node("GameState")
	gs.reset()
	gs.career_seed = seed_
	gs.replay_seed = seed_
	gs.set_setting("seen_training_intro", true)
	gs.set_setting("seen_season_stats_intro", true)
	gs.set_setting("seen_weekly_loop_intro", true)
	gs.start_season(club, root.get_node("GameDB").club_list(club))
	for i in range(3):
		gs.advance()


func _candidate(gs) -> Dictionary:
	for f in ClubStories.player_facts(gs):
		if bool(f["starting"]) and bool(f["fit"]) and bool(f["has_role2"]):
			return gs.list_player(str(f["id"]))
	return {}


func _snap(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var out := "trial"
	var club := "FRE"
	var seed_ := 2031
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		match str(cli[i]):
			"--out": out = str(cli[i + 1])
			"--club": club = str(cli[i + 1])
			"--seed": seed_ = int(cli[i + 1])
			"--size":
				var wh := str(cli[i + 1]).split("x")
				W = int(wh[0])
				H = int(wh[1])
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_trial.save"
	gs.settings_path = "user://capture_trial.cfg"
	gs.show_real_names = false
	seed(seed_)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	await _frames(10)
	var layout = root.get_node("ScreenLayout")
	layout.ui_scale = 1.0 / maxf(1.0, layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0))
	layout._update_scale()
	await _frames(10)
	# The selection screen mid-trial: two games left.
	_fresh(club, seed_)
	var p := _candidate(gs)
	var id := str(p["id"])
	var role2 := ClubStories.trial_role(p)
	print("TRIAL ", gs.player_display_name(p) if gs.has_method("player_display_name") else p.get("name"), " home ", gs._line_of(gs.current_side(), id), " to ", role2)
	print(gs.start_role_trial(p, 3))
	gs.advance()
	print("TRIAL after one game: left ", gs.role_trial.get("left", "none"), " line ", gs._line_of(gs.current_side(), id))
	var ui: Control = load("res://scenes/SelectionScene.tscn").instantiate()
	root.add_child(ui)
	await _frames(20)
	var note = ui.find_child("Trial_" + id, true, false)
	if note == null:
		push_error("capture_trial: no trial note on the selection screen")
	else:
		var n: Node = note.get_parent()
		while n != null and not (n is ScrollContainer):
			n = n.get_parent()
		if n != null:
			(n as ScrollContainer).ensure_control_visible(note)
		await _frames(10)
		print("NOTE text: ", (note as Label).text)
	_snap("%s_selection.png" % out)
	ui.queue_free()
	await _frames(2)
	# The result card, after the third game: a pass, then a fail.
	for pass_it in [true, false]:
		_fresh(club, seed_)
		p = _candidate(gs)
		id = str(p["id"])
		role2 = ClubStories.trial_role(p)
		gs.start_role_trial(p, 3)
		gs.advance()
		gs.advance()
		gs.pos_ratings[role2] = [0, 1] if pass_it else [9999, 1]
		gs.advance()
		print("RESULT pass=", pass_it, " role now ", gs._line_of(gs.current_side(), id), " project ", gs.project_job(gs.list_player(id)),
				" weeks ", (gs.list_player(id).get("project", {}) as Dictionary).get("weeks", 0), " plan ", gs.list_player(id).get("train_plan", ""))
		var scene: Control = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(scene)
		await _frames(60)
		var card = scene.find_child("WeekEvent", true, false)
		if card != null:
			var n2: Node = card.get_parent()
			while n2 != null and not (n2 is ScrollContainer):
				n2 = n2.get_parent()
			if n2 != null:
				(n2 as ScrollContainer).ensure_control_visible(card)
		await _frames(40)
		_snap("%s_%s.png" % [out, "worked" if pass_it else "not_yet"])
		scene.queue_free()
		await _frames(2)
	quit()
