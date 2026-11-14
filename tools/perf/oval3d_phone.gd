extends Node
## Phone cost of the 3D oval (row 197): the main scene of a separate measuring APK, never of the game.
## A seeded Fremantle v St Kilda match plays on the 3D oval with the phone's behind-the-play
## camera, through five set-ups, 2 s to settle then 8 s measured each. At the end the table
## stays on screen (screenshot it) and is saved to user://oval3d_phone.txt.
## Columns: frame = wall time a frame (vsync caps it); sync = CPU for the animation and
## placement; proc = the whole frame's process time (Performance.TIME_PROCESS: includes the
## skeletons' own modifier pass, e.g. the head look-at, which sync does not see); cpu / gpu =
## the renderer's own measured time (skinning runs on the GPU). The header gives the 3D size
## (the window); the 2D canvas is stretched and smaller.

const WARM := 2.0
const MEASURE := 8.0
# [name, extra figures, shadow mode (0 off, 1 as shown, 2 low), mesh LOD threshold, head look-at on]
const STAGES := [
	["As shown", 0, 1, 1.0, true],
	["Low shadows", 0, 2, 1.0, true],
	["No shadows", 0, 0, 1.0, true],
	["Coarser LOD", 0, 1, 4.0, true],
	["52 figures", 9, 1, 1.0, true],
	["Look-at off", 0, 1, 1.0, false],
	["As shown, again", 0, 1, 1.0, true],
]

var oval
var director
var sun: DirectionalLight3D
var extras: Array = []
var looks: Array = []         # [LookAtModifier3D, its skeleton]
var label: Label
var rows: Array = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(8, 8)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
	_run.call_deferred()


func _run() -> void:
	var gdb = get_node("/root/GameDB")
	var Squad_ = load("res://scripts/sim/Squad.gd")
	var Sim = load("res://scripts/sim/MatchSim.gd")
	label.text = "Playing the match..."
	await get_tree().process_frame
	var res: Dictionary = Sim.new(Squad_.new("FRE", gdb.club_list("FRE"), true, "FRE"),
			Squad_.new("STK", gdb.club_list("STK"), false, "STK"), 31).run()
	res["home"] = "FRE"
	res["away"] = "STK"
	director = load("res://scripts/ui/match/MatchDirector.gd").new()
	director.setup(res, res["events"])
	oval = load("res://scripts/ui/match/Oval3D.gd").new()
	add_child(oval)
	oval.build(director, "FRE", "STK")
	sun = oval.find_children("*", "DirectionalLight3D", true, false)[0]
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for st in STAGES:
		_setup(st)
		await _play(WARM, null)
		var acc := {"frames": [], "sync": 0.0, "proc": 0.0, "cpu": 0.0, "gpu": 0.0, "n": 0}
		await _play(MEASURE, acc)
		var fr: Array = acc["frames"]
		fr.sort()
		var n := maxi(1, int(acc["n"]))
		var avg := 0.0
		for f in fr:
			avg += f
		avg /= maxf(1.0, fr.size())
		rows.append("%-12s %5.1f %5.1f %5.2f %5.2f %5.1f %5.1f" % [st[0], avg,
				fr[int(fr.size() * 0.95)] if fr.size() > 0 else 0.0,
				acc["sync"] / n, acc["proc"] / n, acc["cpu"] / n, acc["gpu"] / n])
	var win := DisplayServer.window_get_size()
	var head := "%s | %s | 3D %dx%d\n" % [OS.get_model_name(), RenderingServer.get_video_adapter_name(),
			win.x, win.y]
	var table := "set-up        frame  p95  sync  proc   cpu   gpu  (ms)\n" + "\n".join(rows)
	head += "look-at modifiers: %d\n" % looks.size()
	label.text = head + table + "\nDone: screenshot this."
	var f := FileAccess.open("user://oval3d_phone.txt", FileAccess.WRITE)
	if f:
		f.store_string(head + table + "\n")
	print(head + table)
	if "quit" in OS.get_cmdline_user_args():
		get_tree().quit()


func _setup(st: Array) -> void:
	sun.shadow_enabled = int(st[2]) != 0
	if int(st[2]) == 2:
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	else:
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	get_viewport().mesh_lod_threshold = float(st[3])
	# Row 198's head look-at (LookAtModifier3D under each skeleton), when the build has it.
	# Oval3DAnim sets each modifier's active flag every frame, so "off" takes the modifiers
	# out of their skeletons (the skeleton then never runs them) and "on" puts them back.
	if looks.is_empty():
		for m in oval.find_children("*", "LookAtModifier3D", true, false):
			looks.append([m, m.get_parent()])
	for pair in looks:
		var m: Node = pair[0]
		var skel: Node = pair[1]
		if bool(st[4]) and m.get_parent() == null:
			skel.add_child(m)
		elif not bool(st[4]) and m.get_parent() != null:
			skel.remove_child(m)
	# Stand-ins for more figures (the 7 umpires are already in build()): jogging near the play.
	while extras.size() < int(st[1]):
		var scene: PackedScene = load("res://assets/oval3d/player_average.glb")
		var kit = oval._kit({"design": "plain", "base": Color(0.95, 0.85, 0.2), "shorts": Color(0.1, 0.1, 0.12)})
		var p: Dictionary = oval._player(scene, kit, [Color(0.95, 0.85, 0.2)])
		(p["anim"] as AnimationPlayer).play("jog")
		extras.append(p)
	for i in range(extras.size()):
		(extras[i]["node"] as Node3D).visible = i < int(st[1])
	label.text = "Measuring: %s" % st[0]


func _play(secs: float, acc) -> void:
	var t := 0.0
	var vp := get_viewport().get_viewport_rid()
	while t < secs:
		await get_tree().process_frame
		var dt := minf(get_process_delta_time(), 0.1)
		t += dt
		var t0 := Time.get_ticks_usec()
		director.advance(dt)
		oval.sync(dt)
		for i in range(extras.size()):
			var p: Dictionary = extras[i]
			var nd: Node3D = p["node"]
			if nd.visible:
				(p["anim"] as AnimationPlayer).advance(dt)
				var ang := t * 0.4 + i
				nd.position = Vector3(oval._look.x + cos(ang) * 14.0, 0.0, oval._look.z + sin(ang) * 14.0)
		oval.aim_end(34.0, 52.0)
		if acc != null:
			acc["sync"] += (Time.get_ticks_usec() - t0) / 1000.0
			acc["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			acc["frames"].append(dt * 1000.0)
			acc["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			acc["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			acc["n"] += 1
