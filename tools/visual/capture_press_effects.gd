extends SceneTree
## The press conference with each answer's effect shown under it (director,
## 2026-10-10), for QC on a phone and on the director's PC:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_press_effects.gd -- \
##       --out PREFIX [--window 1170x2532 --canvas 390x844]
## A phone is a 390x844 canvas at 3x; the director's PC is 3840x2160 at 300%
## (a 1280x720 canvas). Vignettes off, so the question shows straight away.
## Seeded; never touches a real save. Writes <out>_press.png.


func _initialize() -> void:
	_run.call_deferred()


func _size(s: String) -> Vector2i:
	var p := s.split("x")
	return Vector2i(int(p[0]), int(p[1]))


func _run() -> void:
	var out := "press"
	var window := Vector2i(1170, 2532)
	var canvas := Vector2i(390, 844)
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--window": window = _size(str(a[i + 1]))
			"--canvas": canvas = _size(str(a[i + 1]))
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
	state.start_season("GEE", db.club_list("GEE"))
	state.media_conference = MC.pick({"club": "GEE", "opponent_name": "Essendon", "round": 12,
			"year": int(state.season_year), "result": {"home": "GEE", "away": "ESS", "score": [44, 101]}}, {})
	DisplayServer.window_set_size(window)
	root.size = window
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
	quit(0)
