extends Control
## Frame times on a real phone (visual audit 4.3 and 4.8: "no phone has ever been measured").
## The "Android Probe" export preset starts here instead of the game (custom feature "probe",
## project.godot: application/run/main_scene.probe). It holds the vignettes that draw footballers
## at busy moments, as tools/visual/measure_vignettes.gd does on a desktop, redraws each for
## FRAMES frames with vsync off, and shows the results on screen in big type (and writes
## user://phone_probe.json): the CPU frame time and the GPU's render time, mean and 95th
## percentile, draw calls, and the first vignette frame (the shader compiling: the hitch a
## player sees on his first close-up). Nothing here touches a save.

const FRAMES := 300

var _out: RichTextLabel


func _ready() -> void:
	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_out.add_theme_font_size_override("normal_font_size", 30)
	_out.text = "Measuring... (about a minute)"
	add_child(_out)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var root := get_tree().root
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://probe.save"
	state.settings_path = "user://probe_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	var SV: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	SV.log_frames = true
	var size := get_viewport_rect().size
	var results := {"screen": [int(size.x), int(size.y)], "renderer": RenderingServer.get_video_adapter_name(),
			"driver": RenderingServer.get_video_adapter_api_version(), "device": OS.get_model_name()}
	var first := true
	var opp_squad = load("res://scripts/sim/Squad.gd").new("ESS", state.season.lists["ESS"], false, "ESS")
	for phase in [["warm", 0.7], ["huddle", 3.6], ["run", 5.2]]:
		var vig = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, "COL", "ESS",
				state.my_squad().ground + state.my_squad().bench, opp_squad.ground + opp_squad.bench,
				"Round 1", false, {})
		vig.set_process(false)
		if phase[0] != "warm":
			vig.set("_t", 0.76)
			vig.set_progress(0.6)
		if phase[0] == "run":
			vig.set("_t", 3.8)
			vig.run_out()
		vig.set("_t", phase[1])
		if first:
			results["first_vignette_frame_ms"] = await _first_frame(vig)
			first = false
		results["prematch_" + phase[0]] = await _measure(vig, SV)
	var star: Dictionary = db.club_list("COL")[0]
	for kind in ["speccy_front", "goal_line"]:
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = size
		vig.setup(kind, {"kind": "mark" if kind.begins_with("speccy") else "goal", "side": 0,
				"num": int(star.get("num", 7)), "player_id": str(star["id"]), "club": "COL", "q": 4,
				"crumb": kind == "goal_line"}, {}, {"home": "COL", "away": "CAR"})
		vig.set_process(false)
		vig.set("_t", 1.3)
		results["broadcast_" + kind] = await _measure(vig, SV)
	if state.prepare_interactive_match():
		var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(bounce)
		bounce.size = size
		bounce.setup(state.pending_sim, 0, "Centre bounce")
		bounce.set_process(false)
		bounce.set("_t", 3.3)
		results["centre_bounce"] = await _measure(bounce, SV)
	SV.log_frames = false
	var f := FileAccess.open("user://phone_probe.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	_out.text = _report(results)
	move_to_front()
	print("PHONE_PROBE ", JSON.stringify(results))


## The first frame a vignette draws: the figure shader compiling, before any warm-up.
func _first_frame(vig: Control) -> float:
	var t := Time.get_ticks_usec()
	vig.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	return snappedf((Time.get_ticks_usec() - t) / 1000.0, 0.1)


func _measure(vig: Control, SV: GDScript) -> Dictionary:
	var vp := get_tree().root.get_viewport_rid()
	for i in range(30):
		vig.queue_redraw()
		await get_tree().process_frame
	SV.frame_log.clear()
	vig.queue_redraw()
	await get_tree().process_frame
	var figures: int = SV.frame_log.size()
	var cpu := []
	var gpu := []
	var calls := []
	var last := Time.get_ticks_usec()
	for i in range(FRAMES):
		vig.queue_redraw()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		cpu.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	vig.queue_free()
	await get_tree().process_frame
	return {"figures": figures, "cpu_ms": _stats(cpu), "gpu_ms": _stats(gpu), "draw_calls": _stats(calls)}


func _stats(v: Array) -> Dictionary:
	var s := v.duplicate()
	s.sort()
	var total := 0.0
	for x in s:
		total += float(x)
	return {"mean": snappedf(total / maxi(1, s.size()), 0.01), "p95": snappedf(float(s[int(s.size() * 0.95)]), 0.01)}


## What a person reads off the phone (and photographs): one line per scene.
func _report(r: Dictionary) -> String:
	var lines := ["[b]Phone probe[/b]  %s  %dx%d" % [str(r["device"]), int(r["screen"][0]), int(r["screen"][1])],
			str(r["renderer"]), "First vignette frame: %s ms" % str(r.get("first_vignette_frame_ms", "-")), ""]
	for k in ["prematch_warm", "prematch_huddle", "prematch_run", "broadcast_speccy_front", "broadcast_goal_line", "centre_bounce"]:
		if not r.has(k):
			continue
		var m: Dictionary = r[k]
		lines.append("[b]%s[/b] (%d figures)" % [k, int(m["figures"])])
		lines.append("  frame %s ms (p95 %s)   GPU %s ms (p95 %s)   calls %s" % [str(m["cpu_ms"]["mean"]),
				str(m["cpu_ms"]["p95"]), str(m["gpu_ms"]["mean"]), str(m["gpu_ms"]["p95"]), str(m["draw_calls"]["mean"])])
	lines.append("")
	lines.append("Saved to user://phone_probe.json")
	return "\n".join(PackedStringArray(lines))
