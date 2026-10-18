extends SceneTree
## The pre-season practice match, for the lead's check and the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_practice.gd -- --out /tmp/prac --club FRE [--opp WBD] [--size 1280x720] [--seed 4127]
## Writes <out>_setup / _setup_low (the stop), _trialled / _trialled_low (three
## prospects trialled), _match_break / _match_play / _match_fulltime (the coached
## match), _report / _report_low, and _draft_card (a prospect seen that day).

var W := 390
var H := 844
var _seed := 4127
var _opp := ""


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
		if str(a[i]) == "--opp":
			_opp = str(a[i + 1])
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
	# On to the practice stop: the earlier stops are simmed.
	var guard := 0
	while state.preseason_active() and state.preseason_stop() != "practice" and guard < 12:
		guard += 1
		state.preseason_advance()
	if _opp != "":
		(state.preseason["practice"] as Dictionary)["opponent"] = _opp
	print("stop ", state.preseason_stop(), " opponent ", state.practice_opponent())
	root.get_node("Router").go("hub")
	await _frames(10)
	print("scene ", current_scene.name, " stop ", state.preseason_stop())
	await _shot(out + "_setup.png")
	await _scroll(true)
	await _shot(out + "_setup_low.png")
	await _scroll(false)
	var picked := 0
	for pr in state.intra_prospects():
		if picked >= 3:
			break
		await _press("Trial_" + str(pr["id"]))
		picked += 1
	await _shot(out + "_trialled.png")
	await _scroll(true)
	await _shot(out + "_trialled_low.png")
	await _scroll(false)
	await _press("PreSeasonGo")
	await _frames(30)
	print("scene ", current_scene.name, " ", state.pending_match)
	await _shot(out + "_match_break.png")
	await _press("StartQuarter")
	for i in range(240):
		await process_frame
	await _shot(out + "_match_play.png")
	current_scene.call("_on_skip")
	for i in range(600):
		await process_frame
		if current_scene.find_child("FullTimeContinue", true, false) != null and i > 30:
			break
	await _shot(out + "_match_fulltime.png")
	await _press("FullTimeContinue")
	await _frames(14)
	print("scene ", current_scene.name, " stop ", state.preseason_stop(), " played ", state.practice_played())
	await _shot(out + "_report.png")
	await _scroll(true)
	await _shot(out + "_report_low.png")
	await _scroll(false)
	# The draft card of a prospect seen in the practice match.
	var seen_id := ""
	for prospect in state.draftee_pool:
		var note: Dictionary = (prospect.get("seen", {}) as Dictionary).get(club, {})
		if seen_id == "" and str(note.get("kind", "")) == "practice":
			seen_id = str(prospect["id"])
	state.season.round_index = state.season.fixture.size()
	if seen_id != "" and state.begin_intake_draft():
		root.get_node("Router").go("draft")
		await _frames(12)
		current_scene.call("_open_player", seen_id)
		await _frames(6)
		var seen_lbl: Node = current_scene.find_child("SeenIntraClub", true, false)
		print("draft card ", seen_id, " line ", (seen_lbl as Label).text if seen_lbl != null else "MISSING")
		if seen_lbl != null:
			var lp: Node = seen_lbl.get_parent()
			while lp != null and not (lp is ScrollContainer):
				lp = lp.get_parent()
			if lp != null:
				(lp as ScrollContainer).ensure_control_visible(seen_lbl as Control)
		await _shot(out + "_draft_card.png")
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
