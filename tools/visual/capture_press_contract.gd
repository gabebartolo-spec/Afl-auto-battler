extends SceneTree
## A named press answer's contract weight, for QC at phone size:
##   godot --path . --resolution 390x844 --windowed --script tools/visual/capture_press_contract.gd -- --out DIR
## Writes DIR/press_contract_gate.png (the Muckraker after a heavy loss, the
## answer naming a player in his last contract year scrolled into view, its
## line saying what it does to re-signing him), DIR/press_contract_result.png
## (answered) and DIR/press_contract_talks.png (the season over, contract talks
## with him: the line saying what he remembers). Seeded; never touches a real save.


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Waits for the question to show (the room hands over to it), up to ~6 s.
func _question_up() -> bool:
	for i in range(360):
		await process_frame
		var q: Control = root.find_child("MediaQuestion", true, false)
		if q != null and q.is_visible_in_tree():
			await _frames(20)
			return true
	return false


func _shot(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _fail(why: String) -> void:
	push_error("capture_press_contract: " + why)
	quit(1)


func _run() -> void:
	var out := "caps"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]).begins_with("--out="):
			out = str(a[i]).substr(6)
		elif str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	var MC = load("res://scripts/sim/MediaConference.gd")
	var club := "COL"
	state.autosave_enabled = false
	state.save_path = "user://capture_press_contract.save"
	state.settings_path = "user://capture_press_contract.cfg"
	seed(2031)
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_weekly_loop_intro", true)
	state.start_season(club, db.club_list(club))
	state.set_vignettes_on(false)
	DisplayServer.window_set_size(Vector2i(390, 844))
	root.size = Vector2i(390, 844)
	await _frames(4)
	# The Muckraker after a heavy loss; the fourth answer names a player whose
	# deal ends this season.
	var named: Dictionary = state.my_list[3]
	named["contract_years"] = 1
	var id := str(named["id"])
	state.media_conference = MC.pick({"club": club, "opponent_name": "Carlton", "round": 8,
			"year": int(state.season_year), "result": {"home": club, "away": "CAR", "score": [55, 101]},
			"named": {"heavy_loss": {"id": id, "name": str(db.player_display_name(named))}}}, {})
	state.media_conference["opp"] = "Carlton"
	router.stack = []
	router.go("press")
	if not await _question_up():
		_fail("the question did not show")
		return
	var ans: Button = root.find_child("MediaAnswer_3", true, false)
	if ans == null:
		_fail("no fourth answer")
		return
	var sc: Node = ans.get_parent()
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc != null:
		(sc as ScrollContainer).scroll_vertical = 100000
	await _frames(20)
	_shot(out.path_join("press_contract_gate.png"))
	ans.emit_signal("pressed")
	await _frames(30)
	if root.find_child("MediaOutcomeLine", true, false) == null:
		_fail("the result did not show")
		return
	_shot(out.path_join("press_contract_result.png"))
	state.media_conference = {}
	if not named.has("press_memory"):
		_fail("he does not remember the answer")
		return
	# The season played out; contract talks with him.
	var season = state.season
	season.round_index = season.fixture.size()
	state.ensure_finals()
	while not season.is_season_over():
		state.advance()
	router.stack = []
	router.go("offseason")
	# The router loads the screen in the background: wait for it, up to ~10 s.
	var scene: Node = null
	for i in range(600):
		await process_frame
		if current_scene != null and current_scene.has_method("_open_talks"):
			scene = current_scene
			break
	await _frames(20)
	if scene == null or not scene.has_method("_open_talks"):
		_fail("no off-season screen")
		return
	scene.call("_open_talks", id)
	await _frames(20)
	if root.find_child("TalksPress", true, false) == null:
		_fail("the talks show no press line")
		return
	_shot(out.path_join("press_contract_talks.png"))
	quit(0)
