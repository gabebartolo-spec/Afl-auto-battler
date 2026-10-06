extends SceneTree
## Films the scenes where a man holds the ball, at a phone's device resolution: the umpire's
## centre bounce (StoppageVignette), the goal-line crumb and the boundary snap
## (BroadcastVignette). Laid out at 390 x 844 and drawn --k times larger in a SubViewport, as a
## phone draws it, so the hands and the ball can be judged; no window size needed.
##   godot --path . --script tools/visual/film_held_ball.gd -- --out /tmp/held --scene bounce [--k 3]
## --scene bounce | goal_line | boundary_snap. Writes <out>_<scene>_NNN.png at 12 frames a
## second over the held phase. Nothing here touches a save.

const W := 390
const H := 844
const FPS := 12.0
## Seconds filmed per scene: walking in through the bounce; the gather, run and snap.
const SPANS := {"bounce": [0.9, 3.5], "goal_line": [1.3, 3.2], "boundary_snap": [0.0, 1.9]}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/held"
	var scene := "bounce"
	var k := 3
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--scene": scene = str(a[i + 1])
			"--k": k = int(a[i + 1])
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(W * k, H * k)
	vp.size_2d_override = Vector2i(W, H)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var vig: Control
	if scene == "bounce":
		vig = await _stoppage()
	else:
		vig = _broadcast(scene, vp)
	if vig.get_parent() != null:
		vig.get_parent().remove_child(vig)
	vp.add_child(vig)
	vig.position = Vector2.ZERO
	vig.size = Vector2(W, H)
	vig.set_process(false)
	var span: Array = SPANS[scene]
	var n := 0
	var t: float = span[0]
	while t <= float(span[1]) + 0.001:
		vig.set("_t", t)
		vig.queue_redraw()
		for i in range(3):
			await process_frame
		var img: Image = vp.get_texture().get_image()
		if img != null:                  # headless: no picture
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s_%s_%03d.png" % [out, scene, n])
		n += 1
		t += 1.0 / FPS
	print("filmed %s: %d frames at %dx" % [scene, n, k])
	quit(0)


## The centre-bounce call on a live match, as capture_vignette.gd stages it.
func _stoppage() -> Control:
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(W, H)
	state.prepare_interactive_match()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	for i in range(6):
		await process_frame
	m.find_child("StartQuarter", true, false).emit_signal("pressed")
	for i in range(6):
		await process_frame
	m.get("_pitch").pause()
	var sim = state.pending_sim
	var me := int(m.get("_my_side"))
	sim.pending_moment = {}
	sim.moment_side = me
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim.set("_moments_this_q", 0)
	sim.set("_last_moment_chain", -1000)
	sim.set("_run", [0, 0])
	sim.call("_boundary_moment")
	m.call("_show_moment")
	var vig: Control = m.find_child("StoppageVignette", true, false)
	m.visible = false
	return vig


## A broadcast kind with a real small forward of Collingwood's featured, as capture_broadcast.gd.
func _broadcast(kind: String, vp: SubViewport) -> Control:
	var db = root.get_node("GameDB")
	var squad: Array = db.club_list("COL").duplicate()
	squad.sort_custom(func(x, y): return float(x.get("height_cm", 0)) < float(y.get("height_cm", 0)))
	var small: Dictionary = squad.filter(func(x): return float(x.get("height_cm", 0)) > 0)[0]
	var ev := {"kind": "goal", "side": 0, "num": int(small.get("num", 7)), "player_id": str(small["id"]),
			"club": "COL", "q": 4, "set_shot": false, "crumb": kind == "goal_line"}
	var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
	vp.add_child(vig)
	vig.size = Vector2(W, H)
	vig.setup(kind, ev, {}, {"home": "COL", "away": "CAR"})
	return vig
