extends SceneTree
## The papers stop (pre-season, week 8), for the lead's check and the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_papers.gd -- --out /tmp/pap --club FRE [--size 1280x720] [--seed 4127]
## Writes <out>_<kind>.png for each story (finish, pressure, breakout) as it
## opens, <out>_<kind>_low.png (scrolled to the ladder), and <out>_finish_answered.png
## (the club talked up). The story kind is forced for the look only.

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
		if str(a[i]) == "--art" and str(a[i + 1]) == "off":
			# The stops without their pictures, as they were (the before shot).
			load("res://scripts/ui/UiArt.gd").set("dir", "res://assets/ui/none")
		if str(a[i]) == "--seed":
			_seed = int(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	# The pre-season is behind a feature switch that ships off: on for this tool.
	load("res://scripts/core/Features.gd").set_on("preseason", true)
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
	# The canvas a player's screen gives the game, whatever this machine's display density.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var density: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, density)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
	for i in range(3):
		await process_frame
	state.start_season(club, db.club_list(club))
	state.open_preseason()
	if _risk >= 0.0:
		load("res://scripts/sim/PreSeason.gd").data()["heavy_week_injury"] = _risk
	for m in state.season.fixture[0]:
		if str(m["home"]) == club or str(m["away"]) == club:
			print("round 1: ", m["home"], " v ", m["away"])
	# Press on to week 8.
	var guard := 0
	while state.preseason_active() and state.preseason_stop() != "papers" and guard < 12:
		guard += 1
		state.preseason_advance()
	print("stop ", state.preseason_stop())
	# For the look only: the paper has the club 13th, so the ladder and the words agree.
	var order: Array = state.papers_record()["order"]
	order.erase(club)
	order.insert(12, club)
	for kind in ["finish", "pressure", "breakout"]:
		var rec: Dictionary = state.papers_record()
		rec["kind"] = kind
		rec["pred"] = 13
		rec["claim"] = 0
		rec["answered"] = false
		rec["result"] = ""
		rec["pid"] = state._papers_breakout() if kind == "breakout" else ""
		root.get_node("Router").go("hub")
		await _frames(10)
		print("scene ", current_scene.name, " ", kind)
		await _shot(out + "_" + kind + ".png")
		await _scroll(true)
		await _shot(out + "_" + kind + "_low.png")
		await _scroll(false)
	var rec2: Dictionary = state.papers_record()
	rec2["kind"] = "finish"
	rec2["pid"] = ""
	rec2["answered"] = false
	root.get_node("Router").go("hub")
	await _frames(10)
	await _press("Papers_2")
	await _frames(6)
	await _shot(out + "_finish_answered.png")
	quit(0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


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
