extends SceneTree
## Frame-rate benchmark for the banner scene (PreMatchVignette) and, for comparison, the
## centre bounce and a broadcast close-up. Opens the scene as a season's first match
## would (fresh process, nothing warmed) and records, per frame, the wall-clock time of
## the first --frames frames (the first load shows up as one long frame) and then a
## steady run, plus node count, draw calls, primitives, texture memory, textures and
## materials. Needs a real renderer and a window, at the size to test:
##   godot --path . --rendering-method gl_compatibility --resolution 1920x1080 \
##       --script tools/visual/perf_banner.gd -- --scene prematch --out perf.json [--frames 120] [--steady 300]
## --scene prematch | bounce | broadcast. The browser is slower than a desktop (WebAssembly,
## WebGL2, one thread): compare the numbers between scenes and builds, not with a browser.
## --warm: call PreMatchVignette.warm() first (when it exists) so the fix can be measured.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "perf.json"
	var scene := "prematch"
	var frames := 120
	var steady := 300
	var warm := false
	var want := Vector2i.ZERO
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--scene":
			scene = str(a[i + 1])
		elif str(a[i]) == "--frames":
			frames = int(a[i + 1])
		elif str(a[i]) == "--steady":
			steady = int(a[i + 1])
		elif str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			want = Vector2i(int(wh[0]), int(wh[1]))
		elif str(a[i]) == "--warm":
			warm = true
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://perf.save"
	state.settings_path = "user://perf_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	if want != Vector2i.ZERO:
		# The window at that many physical pixels (ScreenLayout may have shrunk the first one).
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position(Vector2i(0, 0))
		for i in range(5):
			await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var res := {"scene": scene, "window": DisplayServer.window_get_size(), "scale": root.get_final_transform().get_scale(), "viewport": root.get_visible_rect().size,
			"renderer": RenderingServer.get_video_adapter_name(), "method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))}
	var stages := {}
	var t0 := Time.get_ticks_usec()
	if warm and scene == "prematch":
		var P: GDScript = load("res://scripts/ui/match/PreMatchVignette.gd")
		if P.has_method("warm"):
			P.warm("COL", "ESS")
		stages["warm_ms"] = _ms(t0)
		await process_frame
	t0 = Time.get_ticks_usec()
	var opp_squad = load("res://scripts/sim/Squad.gd").new("ESS", state.season.lists["ESS"], false, "ESS")
	var vig: Control
	if scene == "prematch":
		vig = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, "COL", "ESS",
				state.my_squad().ground + state.my_squad().bench, opp_squad.ground + opp_squad.bench,
				"Round 1", false, {})
		vig.play_through(4.2)
	elif scene == "bounce":
		state.prepare_interactive_match()
		vig = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(vig)
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vig.setup(state.pending_sim, 0, "Centre bounce")
	else:
		var star: Dictionary = db.club_list("COL")[0]
		vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vig.setup("goal_line", {"kind": "goal", "side": 0, "num": int(star.get("num", 7)),
				"player_id": str(star["id"]), "club": "COL", "q": 4, "crumb": true}, {},
				{"home": "COL", "away": "CAR"})
	stages["open_ms"] = _ms(t0)
	var ft := []
	var last := Time.get_ticks_usec()
	var calls := []
	var prims := []
	var gpu := []
	for i in range(frames + steady):
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var first: Array = ft.slice(0, frames)
	var rest: Array = ft.slice(frames)
	res["stages"] = stages
	res["first_frame_ms"] = snappedf(first[0], 0.1)
	res["first_%d" % frames] = _stats(first)
	res["steady"] = _stats(rest)
	res["frames_over_50ms_in_first"] = first.filter(func(x): return x > 50.0).size()
	res["draw_calls_steady"] = _stats(calls.slice(frames))
	res["primitives_steady"] = _stats(prims.slice(frames))
	res["gpu_ms_steady"] = _stats(gpu.slice(frames))
	res["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	res["objects_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	res["texture_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)
	res["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	res["draw_calls_hist_first10"] = calls.slice(0, 10)
	res["first10_ms"] = ft.slice(0, 10).map(func(x): return snappedf(x, 0.1))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("PERF ", JSON.stringify(res))
	quit()


func _ms(t0: int) -> float:
	return snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)


func _stats(v: Array) -> Dictionary:
	var s := v.duplicate()
	s.sort()
	var total := 0.0
	for x in s:
		total += float(x)
	return {"mean": snappedf(total / maxi(1, s.size()), 0.01), "p50": snappedf(float(s[int(s.size() * 0.5)]), 0.01),
			"p95": snappedf(float(s[int(s.size() * 0.95)]), 0.01), "max": snappedf(float(s[s.size() - 1]), 0.01)}
