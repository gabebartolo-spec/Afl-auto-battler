extends SceneTree
## The Club culture sheet (stories P2-3), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_culture.gd -- --out /tmp/cult [--size 1280x720]
## Writes <out>_culture.png (the three strands in words) and <out>_why.png (a strand's
## reasons open). Plays a season first, so the strands have something to say.

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
	var out := "/tmp/cult"
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
	state.save_path = "user://capture_cult.save"
	state.settings_path = "user://capture_cult_settings.cfg"
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
	var guard := 0
	while not state.season.is_season_over() and guard < 40:
		if state.week_event_pending():
			state.resolve_week_event(0)
		state.advance()
		guard += 1
	# Something for Standards to say, so no strand reads empty in the capture.
	state._culture_move(state.my_club, "standards", 6, "The list's discipline is well above the league's")
	state._culture_move(state.my_club, "standards", 6, "The list's discipline is well above the league's")
	state._culture_move(state.my_club, "standards", 6, "The list's discipline is well above the league's")
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	current_scene.call("_open_culture")
	await _shot(out + "_culture.png")
	for b in current_scene.find_children("StrandWhy", "Button", true, false):
		b.emit_signal("pressed")
	await _shot(out + "_why.png")
	quit(0)
