extends SceneTree
## Legacy, Fitzroy fight off the merger (director, 2026-11-13):
##   godot --path . --script tools/visual/capture_legacy_brand.gd -- --out DIR
## Writes DIR/brand_card.png (the Bears-or-Lions card on the hub, phone size),
## DIR/brand_answered.png (after a real tap on Become the Lions), and the oval
## for Fitzroy v the Bears and v the Lions, before and after the reshade:
## DIR/oval_FIT_<bears|lions>_<raw|shaded>.png.

const Tap := preload("res://tests/tap.gd")
const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _wait(40)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var LegacyRollover = load("res://scripts/state/LegacyRollover.gd")
	var out := "/tmp/legacy_brand"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_legacy_brand.save"
	state.settings_path = "user://capture_legacy_brand_settings.cfg"
	state.reset("1990")
	state.set_setting("seen_weekly_loop_intro", true)
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	await _wait(3)
	# The ovals first (no scene on screen).
	for lions in [false, true]:
		for shaded in [false, true]:
			db.reload("1990")
			db.apply_era(1997)
			db.keep_club("FIT")
			if lions:
				db.unpin_era("BRL")
			else:
				db.pin_era("BRL", 1996)
			if shaded:
				LegacyRollover.separate_colours()
			print("FIT v %s %s: gap %.1f" % ["Lions" if lions else "Bears", "shaded" if shaded else "raw", LegacyRollover.kit_gap()])
			await _oval(out.path_join("oval_FIT_%s_%s.png" % ["lions" if lions else "bears", "shaded" if shaded else "raw"]))
	# The card on the hub, then a real tap on Become the Lions.
	state.reset("1990")
	state.replay_seed = 3
	state.career_seed = 3
	state.start_season("BRL", db.club_list("BRL"))
	state.legacy = {"fitzroy": "stays"}
	LegacyRollover.keep_fitzroy()
	db.apply_era(1997)
	state.media_conference = {}
	state.week_events = []
	LegacyRollover.week(state)
	root.get_node("Router").go("hub")
	await _wait(400)
	await _shot(out.path_join("brand_card.png"))
	var sheet: Node = current_scene.find_child("EventSheet", true, false) if current_scene != null else null
	var lions_btn: Button = sheet.find_child("Event_0", true, false) if sheet != null else null
	print("tap: ", (await Tap.tap(lions_btn)) if lions_btn != null else "missing")
	await _shot(out.path_join("brand_answered.png"))
	quit(0)


func _oval(path: String) -> void:
	var PV = load("res://scripts/ui/PitchView.gd")
	var Squad_ = load("res://scripts/sim/Squad.gd")
	var Sim = load("res://scripts/sim/MatchSim.gd")
	var gdb = root.get_node("GameDB")
	var h := "FIT"
	var w := "BRL"
	var res: Dictionary = Sim.new(Squad_.new(h, gdb.club_list(h), true, h), Squad_.new(w, gdb.club_list(w), false, w), 31).run()
	res["home"] = h
	res["away"] = w
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(W, 640)
	var pv = PV.new()
	pv.size = Vector2(W, 640)
	root.add_child(pv)
	pv.setup(res)
	pv.set_speed(4.0)
	pv.play()
	for i in range(500):
		pv._process(1.0 / 30.0)
	for i in range(5):
		pv.queue_redraw()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("wrote ", path)
	pv.queue_free()
	await process_frame
	root.size = Vector2i(W, H)
