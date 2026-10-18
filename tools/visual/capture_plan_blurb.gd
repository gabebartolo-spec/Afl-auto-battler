extends SceneTree
## Review capture: the break's Game plan, Pep talk and Rotations panes.
##   --size WxH  --club CODE  --out PREFIX (a path, no extension)
##   --mode plans   one capture per game plan, the plan pane open (quarter 1 not yet played)
##   --mode panes   the three panes at half time (--quarters 2) and three-quarter time (3)
##   --quarters N   quarters played before the break (panes mode)
## Needs a real renderer. Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames(8)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var out := "plan_blurb"
	var club := "MEL"
	var mode := "plans"
	var quarters := 0
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--club":
				club = str(a[i + 1])
			"--mode":
				mode = str(a[i + 1])
			"--quarters":
				quarters = int(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_blurb.save"
	state.settings_path = "user://capture_blurb.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	if not state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	var sim = state.pending_sim
	var mine := 0
	var plans_seq := ["attacking", "defensive", "contest"]
	var peps := ["steady", "fire_up", "heat"]
	var rots := ["normal", "hard", "stars"]
	for q in range(quarters):
		mine = int(sim.moment_side)
		sim.set_tactics(mine, {"gameplan": plans_seq[q % 3], "pep": peps[q % 3], "focus_id": "", "tag_id": ""})
		sim.set_rotation_policy(mine, rots[q % 3])
		sim.run_quarter()
	UK.apply_appearance("dark")
	if _w >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(_w, _h))
		await _frames(10)
		var factor := float(_w) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(_w * factor), int(_h * factor)))
			await _frames(10)
	else:
		root.size = Vector2i(_w, _h)
		DisplayServer.window_set_size(Vector2i(_w, _h))
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(14)
	var more: Button = scene.find_child("MoreCallsToggle", true, false)
	if more != null:
		more.emit_signal("pressed")
	await _frames(6)
	if mode == "plans":
		var row: Button = scene.find_child("CallRow_plan", true, false)
		if row != null:
			row.emit_signal("pressed")
			await _frames(10)
		for k in ["balanced", "attacking", "defensive", "contest", "controlled", "through_stars"]:
			var b: Button = scene.find_child("PlanPicker_" + k, true, false)
			if b == null:
				push_error("no plan button " + k)
				continue
			b.emit_signal("pressed")
			await _frames(6)
			await _shot("%s_%s.png" % [out, k])
	else:
		for key in ["plan", "pep", "rot"]:
			var row: Button = scene.find_child("CallRow_" + key, true, false)
			if row != null:
				row.emit_signal("pressed")
				await _frames(10)
			await _shot("%s_q%d_%s.png" % [out, quarters, key])
	quit(0)
