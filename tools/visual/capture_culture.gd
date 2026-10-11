extends SceneTree
const Tap := preload("res://tests/tap.gd")
## The Club culture sheet (stories P2-3), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_culture.gd -- --out /tmp/cult [--size 1280x720]
## Writes <out>_list.png (My list, the Club culture row), <out>_culture.png (the three strands in words) and <out>_why.png (a strand's
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


## A finger's tap, as tests/tap.gd sends it, with the point scaled from the
## canvas to the window (the capture window is not at the canvas scale the
## suites run at). Returns "" when the button took it.
func _tap(c: Control) -> String:
	var at := Tap.screen_point(c) * (Vector2(root.size) / root.get_visible_rect().size)
	var hit := [false]
	var on_press := func(): hit[0] = true
	(c as BaseButton).pressed.connect(on_press)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		for i in range(3):
			await process_frame
	if is_instance_valid(c):
		(c as BaseButton).pressed.disconnect(on_press)
	return "" if hit[0] else "the tap missed"


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
		# As the suites do it (root size only), so a real tap lands where it should.
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
	# Three seasons of a well-disciplined list, so Standards reads a named band.
	for y in [state.season_year - 2, state.season_year - 1, state.season_year]:
		Culture.change(state.relations, state.my_club, "standards", 4,
				"The list's discipline is well above the league's", y, "Off-season")
	# Five and more reasons on Togetherness, so the PC sheet has to scroll with Close pinned.
	var y0: int = state.season_year
	for why in ["Played finals", "A run of five wins", "A settled list: far fewer new faces from other clubs than most",
			"A run of four losses", "Finished near the bottom of the ladder", "Premiers"]:
		Culture.change(state.relations, state.my_club, "together", 3, why, y0 - 1, "Off-season")
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	await _shot(out + "_list.png")
	# A real tap on the row, then on each Why.
	for i in range(20):
		await process_frame
	var open_btn: Button = current_scene.find_child("CultureOpen", true, false)
	# A real tap where the capture window maps touches true (the roles suite proves
	# the tap on its own); else the press, so the shot is still taken.
	var why: String = await _tap(open_btn) if W < 760 else "not tapped on the PC canvas"
	if why != "" or current_scene.find_child("CultureSheet", true, false) == null:
		print("tap not mapped here (", why, "): pressing instead")
		open_btn.emit_signal("pressed")
	await _shot(out + "_culture.png")
	for b in current_scene.find_children("StrandWhy", "Button", true, false):
		if W >= 760 or await _tap(b) != "":
			b.emit_signal("pressed")
	await _shot(out + "_why.png")
	quit(0)
