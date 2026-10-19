extends SceneTree
## The press conference with each answer's effect shown under it (director,
## 2026-10-10), for QC on a phone and on the director's PC:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_press_effects.gd -- \
##       --out PREFIX [--window 1170x2532 --canvas 390x844] [--club FRE]
## A phone is a 390x844 canvas at 3x; the director's PC is 3840x2160 at 300%
## (a 1280x720 canvas). Vignettes off, so the question shows straight away.
## Seeded; never touches a real save. Writes <out>_press.png, then taps the first answer
## and writes <out>_outcome.png (how it landed).


func _initialize() -> void:
	_run.call_deferred()


func _size(s: String) -> Vector2i:
	var p := s.split("x")
	return Vector2i(int(p[0]), int(p[1]))


func _run() -> void:
	var out := "press"
	var window := Vector2i(1170, 2532)
	var canvas := Vector2i(390, 844)
	var club := "GEE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--window": window = _size(str(a[i + 1]))
			"--canvas": canvas = _size(str(a[i + 1]))
			"--club": club = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var MC = load("res://scripts/sim/MediaConference.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_press.save"
	state.settings_path = "user://capture_press.cfg"
	seed(2031)
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("vignettes", false)
	state.start_season(club, db.club_list(club))
	state.media_conference = MC.pick({"club": club, "opponent_name": "Essendon", "round": 12,
			"year": int(state.season_year), "result": {"home": club, "away": "ESS", "score": [44, 101]}}, {})
	DisplayServer.window_set_size(window)
	root.size = window
	# Pin the stretch: the canvas scaled up to fill the window, whatever the
	# display server makes of a window taller than its screen.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = canvas
	await process_frame
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	root.content_scale_size = canvas
	for i in range(10):
		await process_frame
	if hub.find_child("MediaAnswerLine_0", true, false) == null:
		push_error("capture_press_effects: the answer lines did not show")
		quit(1)
		return
	root.get_viewport().get_texture().get_image().save_png(out + "_press.png")
	# Then the first answer, for the sheet that says how it landed. A window taller than the
	# screen puts the button off the real display, so this presses it; the real tap is proven
	# in the matchday suite (_test_press_effects_shown).
	var answer: Button = hub.find_child("MediaAnswer_0", true, false)
	var why := "" if answer != null else "missing"
	if answer != null:
		answer.emit_signal("pressed")
	for i in range(10):
		await process_frame
	if why != "" or hub.find_child("MediaOutcomeLine", true, false) == null:
		push_error("capture_press_effects: the outcome sheet did not show (%s)" % why)
		quit(1)
		return
	root.get_viewport().get_texture().get_image().save_png(out + "_outcome.png")
	quit(0)
