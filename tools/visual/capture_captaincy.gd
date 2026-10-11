extends SceneTree
## The Captaincy page (stories P2-2), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_captaincy.gd -- --out /tmp/capt [--size 1280x720]
## Writes <out>_sheet.png (the page), <out>_picker.png (the list to pick from),
## <out>_cost.png (a pick that overlooks a senior player), <out>_nocost.png (a vice-captain added: "No cost."),
## <out>_refused.png (a second mid-season change, refused with the reason) and
## <out>_mid.png (a first mid-season change and what it costs).

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
	var out := "/tmp/capt"
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
	state.save_path = "user://capture_capt.save"
	state.settings_path = "user://capture_capt_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	if W >= 760:
		# A PC window, laid out on the 1280x720 desktop canvas as the game does.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(W, H))
		for i in range(10):
			await process_frame
		# The canvas is laid out in device-independent pixels: grow the window by
		# the display scale until the canvas is the 1280x720 a PC player gets.
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
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	var young: Array = []
	var senior: Array = []
	for q in state.my_list:
		if float(q.get("age", 30.0)) < 24.0:
			young.append(q)
		elif float(q.get("age", 0.0)) >= 28.0 and Leadership.games(q) >= 150:
			senior.append(q)
	young.sort_custom(func(x, y): return Leadership.of(x) < Leadership.of(y))
	senior.sort_custom(func(x, y): return Leadership.of(x) > Leadership.of(y))
	current_scene.call("_open_captaincy")
	await _shot(out + "_sheet.png")
	await _press("CaptaincySlot_0")
	await _shot(out + "_picker.png")
	await _press("Pick_" + str(young[0]["id"]))
	await _shot(out + "_cost.png")
	await _press("CaptaincyConfirm")
	await _press("CaptaincyClose")
	# A vice-captain added to the next free spot: no cost.
	current_scene.call("_open_captaincy")
	await _frames(3)
	var n: int = Captaincy.slots(state.captaincy_record(state.my_club)).size()
	await _press("CaptaincySlot_%d" % n)
	await _press("Pick_" + str(young[1]["id"]))
	await _shot(out + "_nocost.png")
	await _press("CaptaincyConfirm")
	await _press("CaptaincyClose")
	# The season begins; taking the armband off now costs, once.
	state.advance()
	current_scene.call("_open_captaincy")
	await _frames(3)
	await _press("CaptaincySlot_0")
	await _press("Pick_" + str(senior[0]["id"]))
	await _shot(out + "_mid.png")
	await _press("CaptaincyConfirm")
	await _press("CaptaincyClose")
	# A second change the same season: refused.
	current_scene.call("_open_captaincy")
	await _frames(3)
	await _press("CaptaincySlot_0")
	await _press("Pick_" + str(senior[1]["id"]))
	await _shot(out + "_refused.png")
	quit(0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _press(node_name: String) -> void:
	await _frames(3)
	var b: Node = current_scene.find_child(node_name, true, false)
	if b is Button:
		(b as Button).emit_signal("pressed")
	await _frames(3)
