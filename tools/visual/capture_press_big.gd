extends SceneTree
## The press conference sheet at a given window size: capture, check every control is on screen,
## then a real tap on the first answer (tests/tap.gd). Needs a real renderer:
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_press_big.gd -- --size 1280x720 --out /tmp/press_big
## Writes <out>_<w>x<h>.png and prints PASS/FAIL lines. Nothing touches a real save.
const Tap := preload("res://tests/tap.gd")

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var out := "press_big"
	var w := 1280
	var h := 720
	var club := "MEL"
	var tap := true
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				w = int(wh[0])
				h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://capture_press_big.save"
	state.settings_path = "user://capture_press_big.cfg"
	state.reset()
	state.start_season(club, db.club_list(club))
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	router.stack = []
	router.go("main")
	await _frames(8)
	router.go("hub")
	await _frames(20)
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == "Got it" and (b as Button).is_visible_in_tree():
			(b as Button).emit_signal("pressed")
	await _frames(10)
	state.media_conference = MediaConference.pick({"club": club, "opponent_name": "Carlton", "round": 8,
			"result": {"home": club, "away": "CAR", "score": [55, 101]}}, {})
	var hub = root.find_child("HubScene", true, false)
	if hub == null:
		hub = router.get_child(router.get_child_count() - 1)
	hub.call("_show_media_conference")
	await _frames(10)
	var v = root.find_child("MediaConference", true, false)
	var scene = root.find_child("MediaConferenceVignette", true, false)
	if scene != null:
		scene.call("finish_now")
	await _frames(20)
	var win := Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
	var ok := v != null
	var names := ["MediaByline", "MediaQuestion", "MediaAnswer_0", "MediaAnswer_1", "MediaAnswer_2", "MediaAnswerLine_2", "MediaSkip"]
	for n in names:
		var c: Control = root.find_child(n, true, false)
		var inside := c != null and c.is_visible_in_tree() and win.encloses(c.get_global_rect())
		print("%s %s %s" % ["PASS" if inside else "FAIL", n, "" if c == null else str(c.get_global_rect())])
		ok = ok and inside
	var shell = v.find_child("*", true, false) if v != null else null
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s_%dx%d.png" % [out, w, h])
	var answer: Button = root.find_child("MediaAnswer_0", true, false)
	var why: String = await Tap.tap(answer) if answer != null else "missing"
	await _frames(6)
	var closed := root.find_child("MediaConference", true, false) == null
	print("%s real tap on answer 0 at %dx%d (%s), sheet closed %s, viewport %s" % ["PASS" if why == "" and closed else "FAIL", w, h, why, str(closed), str(win.size)])
	print("RESULT ", "PASS" if ok and why == "" and closed else "FAIL")
	quit()
