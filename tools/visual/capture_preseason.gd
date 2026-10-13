extends SceneTree
## The pre-season stops (slice 1), for the lead's check and the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_preseason.gd -- --out /tmp/pre --club FRE [--size 1280x720] [--seed 4127] [--risk 0.3]
## Writes <out>_plan.png (the plan as it opens), <out>_plan_low.png (the same,
## scrolled to the foot), <out>_plan_set.png (a Heavy running block and a Heavy
## last block picked), <out>_trial.png and <out>_trial_low.png (the time trial
## stop) and <out>_round1.png (the hub at Round 1, the base in the plan line).

var W := 390
var H := 844
var _seed := 4127
var _risk := -1.0


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if W >= 760 and img.get_width() != W:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/pre"
	var club := "FRE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--risk":
			# A bigger Heavy-week risk than the game's, so the "Hurt in training"
			# list is sure to show (for the look only; never a balance read).
			_risk = float(a[i + 1])
		if str(a[i]) == "--seed":
			_seed = int(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_preseason.save"
	state.settings_path = "user://capture_preseason_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.career_seed = _seed
	state.replay_seed = _seed
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("seen_training_intro", true)
	if W >= 760:
		# A PC window, laid out on the 1280x720 desktop canvas as the game does.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(W, H))
		for i in range(10):
			await process_frame
		var factor := float(W) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(W * factor), int(H * factor)))
			for i in range(10):
				await process_frame
		print("visible ", root.get_visible_rect().size)
	else:
		DisplayServer.window_set_size(Vector2i(W, H))
		root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	state.start_season(club, db.club_list(club))
	state.open_preseason()
	if _risk >= 0.0:
		load("res://scripts/sim/PreSeason.gd").data()["heavy_week_injury"] = _risk
	for m in state.season.fixture[0]:
		if str(m["home"]) == club or str(m["away"]) == club:
			print("round 1: ", m["home"], " v ", m["away"])
	root.get_node("Router").go("hub")
	await _frames(10)
	print("scene ", current_scene.name, " stop ", state.preseason_stop())
	await _shot(out + "_plan.png")
	await _scroll(true)
	await _shot(out + "_plan_low.png")
	await _scroll(false)
	await _press("Load0_heavy")
	await _press("Focus1_running")
	await _press("Load2_heavy")
	await _shot(out + "_plan_set.png")
	await _press("PreSeasonGo")
	await _frames(8)
	print("scene ", current_scene.name, " stop ", state.preseason_stop())
	await _shot(out + "_trial.png")
	var hurt: Node = current_scene.find_child("TrialHurt_0", true, false)
	if hurt != null:
		# The "Hurt in training" list, brought into view.
		var hp: Node = hurt.get_parent()
		while hp != null and not (hp is ScrollContainer):
			hp = hp.get_parent()
		if hp != null:
			(hp as ScrollContainer).ensure_control_visible(hurt as Control)
			(hp as ScrollContainer).scroll_vertical += 60
		await _shot(out + "_trial_hurt.png")
	await _scroll(true)
	await _shot(out + "_trial_low.png")
	await _press("PreSeasonGo")
	await _frames(12)
	print("scene ", current_scene.name, " week ", state.preseason_week(), " line ", state.fitness_status_line())
	var line: Node = current_scene.find_child("SeasonPlanLine", true, false)
	var p: Node = line.get_parent() if line != null else null
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(line as Control)
			break
		p = p.get_parent()
	await _shot(out + "_round1.png")
	quit(0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## The page to its foot, or back to the top.
func _scroll(to_foot: bool) -> void:
	await _frames(3)
	var page: Node = current_scene.find_child("PreSeasonPage", true, false)
	var sc := page.get_parent() as ScrollContainer if page != null else null
	if sc != null:
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value) if to_foot else 0
	await _frames(3)


func _press(node_name: String) -> void:
	await _frames(3)
	var b: Node = current_scene.find_child(node_name, true, false)
	if b is Button:
		(b as Button).emit_signal("pressed")
	else:
		print("MISSING ", node_name)
	await _frames(3)
