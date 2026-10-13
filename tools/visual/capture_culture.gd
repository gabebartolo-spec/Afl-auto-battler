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
	var club := "GEE"
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
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_cult.save"
	state.settings_path = "user://capture_cult_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_weekly_loop_intro", true)
	# The canvas is the size a player's screen gives the game: 1280x720 on a PC, 390x844 on a
	# phone. ScreenLayout would scale it by this machine's display density, so undo that here.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var base: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, base)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
	for i in range(3):
		await process_frame
	state.start_season(club, db.club_list(club))
	# Six reasons on Togetherness from the real movers, each with its own sign and
	# never two opposed finishes in one season, so the PC sheet scrolls with Close pinned.
	var y0: int = state.season_year
	var moves := [
		[y0 - 2, "Round 6", Culture.run_step(0, 5)],
		[y0 - 2, "Off-season", _first(Culture.season_steps(1, 18, true, 0.0, 0.0), "together")],
		[y0 - 1, "Round 10", Culture.run_step(4, 0)],
		[y0 - 1, "Round 20", Culture.run_step(0, 5)],
		[y0 - 1, "Off-season", _first(Culture.season_steps(6, 18, false, 0.0, 0.0), "together")],
		[y0, "Off-season", _first(Culture.new_faces_step(1, 6.0), "together")],
	]
	for m in moves:
		var mv = m[2]
		if mv is Array:
			Culture.change(state.relations, state.my_club, str(mv[0]), int(mv[1]), str(mv[2]), int(m[0]), str(m[1]))
		elif mv is Dictionary:
			Culture.change(state.relations, state.my_club, str(mv["strand"]), int(mv["d"]), str(mv["why"]), int(m[0]), str(m[1]))
	var guard := 0
	while not state.season.is_season_over() and guard < 40:
		if state.week_event_pending():
			state.resolve_week_event(0)
		state.advance()
		guard += 1
	# Three seasons of a well-disciplined list, so Standards reads a named band.
	for y in [state.season_year - 2, state.season_year - 1, state.season_year]:
		Culture.change(state.relations, state.my_club, "standards", 4,
				"The list holds itself to a higher standard than most clubs", y, "Off-season")
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	await _shot(out + "_list.png")
	# Each treatment (CultureSheet.variant): the way in by a real tap (phone), the
	# screen, the reasons, then Back. Writes <out>_<V>_culture.png and <out>_<V>_reasons.png.
	for v in ["A", "B", "C"]:
		CultureSheet.variant = v
		current_scene.queue_free()
		await process_frame
		root.get_node("Router").go("list")
		for i in range(20):
			await process_frame
		var open_btn: Button = current_scene.find_child("CultureOpen", true, false)
		var why: String = await _tap(open_btn) if W < 760 else "not tapped on the PC canvas"
		if why != "" or current_scene.find_child("CultureSheet", true, false) == null:
			print(v, ": tap not mapped here (", why, "): pressing instead")
			open_btn.emit_signal("pressed")
		await _shot(out + "_" + v + "_culture.png")
		print(v, " clipped text: ", _clipped(current_scene.find_child("CultureSheet", true, false)))
		var all: Button = current_scene.find_child("CultureAllReasons", true, false)
		if all != null:
			all.emit_signal("pressed")
		await _shot(out + "_" + v + "_reasons.png")
		print(v, " clipped text (reasons): ", _clipped(current_scene.find_child("CultureSheet", true, false)))
		var closed := false
		for k in range(2):
			if current_scene.find_child("CultureSheet", true, false) != null:
				current_scene.handle_back()
				await process_frame
		closed = current_scene.find_child("CultureSheet", true, false) == null
		print(v, " back closes: ", closed)
	quit(0)


## Labels whose text does not fit the box they were given, or that sit off the
## screen (outside a scroll). 0 is the answer.
func _clipped(sheet: Node) -> int:
	var n := 0
	if sheet == null:
		return -1
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1.0)
	for l in sheet.find_children("*", "Label", true, false):
		var lab := l as Label
		if not lab.is_visible_in_tree() or lab.text == "":
			continue
		if lab.size.y + 1.0 < lab.get_combined_minimum_size().y:
			n += 1
			print("  clipped: ", lab.text)
			continue
		var in_scroll := false
		var p := lab.get_parent()
		while p != null and p != sheet:
			if p is ScrollContainer:
				in_scroll = true
			p = p.get_parent()
		if not in_scroll and not screen.encloses(lab.get_global_rect()):
			n += 1
			print("  off screen: ", lab.text)
	return n


func _first(steps: Array, strand: String):
	for st in steps:
		if str(st["strand"]) == strand:
			return st
	return null
