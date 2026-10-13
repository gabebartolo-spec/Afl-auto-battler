extends SceneTree
## The season plan screens (season fitness PR2), for the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_season_plan.gd -- --out /tmp/plan [--size 1280x720]
## Writes <out>_hub.png (the hub, the line in words), <out>_sheet.png (the
## pre-season sheet), <out>_picked.png (Peak for September picked, not yet
## confirmed), <out>_hub_set.png (the hub after Confirm), <out>_training.png
## (Training, the same line), <out>_r14.png (round 14: a late change and what
## it costs), <out>_locked.png (between revision points) and <out>_late.png
## (the last month, September ahead).

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
	var out := "/tmp/plan"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_plan.save"
	state.settings_path = "user://capture_plan_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
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
	state.start_season("GEE", db.club_list("GEE"))
	root.get_node("Router").go("hub")
	await _frames(8)
	await _to_line()
	await _shot(out + "_hub.png")
	await _press("SeasonPlanLine")
	await _frames(4)
	await _shot(out + "_sheet.png")
	await _press("Plan_peak")
	await _shot(out + "_picked.png")
	await _press("SeasonPlanConfirm")
	await _press("SeasonPlanClose")
	await _frames(4)
	await _to_line()
	await _shot(out + "_hub_set.png")
	root.get_node("Router").go("training")
	await _frames(8)
	await _shot(out + "_training.png")
	# Between revision points.
	state.season.round_index = 6
	root.get_node("Router").go("hub")
	await _frames(8)
	await _press("SeasonPlanLine")
	await _frames(4)
	await _shot(out + "_locked.png")
	await _press("SeasonPlanClose")
	await _frames(3)
	# Round 14: change to Develop; a late change says what it costs.
	state.season.round_index = 13
	root.get_node("Router").go("hub")
	await _frames(8)
	await _press("SeasonPlanLine")
	await _frames(4)
	await _press("Plan_develop")
	await _shot(out + "_r14.png")
	await _press("SeasonPlanConfirm")
	await _press("SeasonPlanClose")
	await _frames(3)
	# The last month: back to a September peak, with little time to build.
	state.season.round_index = 20
	root.get_node("Router").go("hub")
	await _frames(8)
	await _press("SeasonPlanLine")
	await _frames(4)
	await _press("Plan_peak")
	await _shot(out + "_late.png")
	quit(0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Scroll the hub so the season line is on screen.
func _to_line() -> void:
	await _frames(3)
	var line: Node = current_scene.find_child("SeasonPlanLine", true, false)
	var p: Node = line.get_parent() if line != null else null
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(line as Control)
			break
		p = p.get_parent()
	await _frames(3)


func _press(node_name: String) -> void:
	await _frames(3)
	var b: Node = current_scene.find_child(node_name, true, false)
	if b is Button:
		(b as Button).emit_signal("pressed")
	else:
		print("MISSING ", node_name)
	await _frames(3)
