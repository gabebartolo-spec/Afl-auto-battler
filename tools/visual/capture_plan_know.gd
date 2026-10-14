extends SceneTree
## Plan familiarity, for the lead's check and the director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_plan_know.gd -- --out /tmp/pk --club FRE [--size 1280x720]
## Writes <out>_drill.png (a Game plan block and the plans it can drill, with how
## well the side knows each), <out>_drill_two.png (two plans drilled),
## <out>_tiles.png (the pre-match plan tiles, "Knows this plan"), <out>_break.png
## (the break's plan call and the line under it). The levels shown are set by this
## tool for the look (contest barely, controlled partly); it is not a balance read.

var W := 390
var H := 844


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
	var out := "/tmp/pk"
	var club := "FRE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	load("res://scripts/core/Features.gd").set_on("preseason", true)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_plan_know.save"
	state.settings_path = "user://capture_plan_know_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.career_seed = 4127
	state.replay_seed = 4127
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("seen_training_intro", true)
	if W >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(W, H))
		for i in range(10):
			await process_frame
		var factor := float(W) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(W * factor), int(H * factor)))
			for i in range(10):
				await process_frame
	else:
		DisplayServer.window_set_size(Vector2i(W, H))
		root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	state.start_season(club, db.club_list(club))
	state.set_club_plan("attacking")
	state.open_preseason()
	# For the look: a side that knows its plans unevenly.
	state.plan_known[club]["contest"] = 0
	state.plan_known[club]["controlled"] = 1
	state.plan_known[club]["defensive"] = 1
	root.get_node("Router").go("hub")
	await _frames(10)
	await _press("Focus0_plan")
	await _press("Drill0_contest")
	await _press("Drill0_attacking")
	await _scroll_to("BlockCost_0")
	await _shot(out + "_drill.png")
	await _press("Drill0_defensive")
	await _scroll_to("BlockCost_0")
	await _shot(out + "_drill_two.png")
	await _press("Drill0_defensive")
	await _press("PreSeasonSim")
	await _frames(20)
	print("scene ", current_scene.name, " after: contest ", state.plan_level(club, "contest"), " attacking ",
			state.plan_level(club, "attacking"))
	state.plan_known[club]["controlled"] = 1
	state.plan_known[club]["through_stars"] = 0
	root.get_node("Router").go("coaching")
	await _frames(12)
	await _scroll_to("ClubPlan")
	await _shot(out + "_tiles.png")
	if state.prepare_interactive_match():
		root.get_node("Router").go("match")
		await _frames(40)
		await _press("PlanPicker_through_stars")
		await _scroll_to("PlanNote")
		await _shot(out + "_break.png")
	quit(0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Bring a node into view in whatever scroll holds it.
func _scroll_to(node_name: String) -> void:
	await _frames(4)
	var n: Node = current_scene.find_child(node_name, true, false)
	var p: Node = n.get_parent() if n != null else null
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		(p as ScrollContainer).ensure_control_visible(n as Control)
	elif n == null:
		print("MISSING ", node_name)
	await _frames(4)


func _press(node_name: String) -> void:
	await _frames(3)
	var b: Node = current_scene.find_child(node_name, true, false)
	if b is Button:
		(b as Button).emit_signal("pressed")
	else:
		print("MISSING ", node_name)
	await _frames(3)
