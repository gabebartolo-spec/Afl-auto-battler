extends SceneTree
## Frame time of the vignettes that draw footballers, for before/after comparisons
## of figure drawing (the hair overlays add a draw per figure). Each scene is held
## at a busy moment and redrawn for --frames frames with vsync off, at a phone's
## 390 x 844; it reports the figures drawn per frame (StoppageVignette.frame_log)
## and the CPU frame time and the GPU's render time, mean and 95th percentile.
## Needs a real renderer and a window (keep it off screen with an override.cfg):
##   godot --path . --script tools/visual/measure_vignettes.gd -- --out /tmp/perf.json [--frames 600]
## Run the same build of the tool on both trees, one after the other, on an idle machine.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/perf.json"
	var frames := 600
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--frames":
			frames = int(a[i + 1])
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://measure.save"
	state.settings_path = "user://measure_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	var SV: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	SV.log_frames = true
	var results := {}
	# The pre-match: both squads on the ground (the most figures of any scene).
	var opp_squad = load("res://scripts/sim/Squad.gd").new("ESS", state.season.lists["ESS"], false, "ESS")
	# As capture_prematch.gd stages them: warming up, gathered in, running out.
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
		results["prematch_" + phase[0]] = await _measure(vig, SV, frames)
	# A broadcast close-up and the centre bounce.
	var star: Dictionary = db.club_list("COL")[0]
	for kind in ["speccy_front", "goal_line"]:
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = Vector2(W, H)
		vig.setup(kind, {"kind": "mark" if kind.begins_with("speccy") else "goal", "side": 0,
				"num": int(star.get("num", 7)), "player_id": str(star["id"]), "club": "COL", "q": 4,
				"crumb": kind == "goal_line"}, {}, {"home": "COL", "away": "CAR"})
		vig.set_process(false)
		vig.set("_t", 1.3)
		results["broadcast_" + kind] = await _measure(vig, SV, frames)
	if state.prepare_interactive_match():
		var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(bounce)
		bounce.size = Vector2(W, H)
		bounce.setup(state.pending_sim, 0, "Centre bounce")
		bounce.set_process(false)
		bounce.set("_t", 3.3)
		results["centre_bounce"] = await _measure(bounce, SV, frames)
	SV.log_frames = false
	results["renderer"] = RenderingServer.get_video_adapter_name()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	f.close()
	print(JSON.stringify(results))
	quit()


## Redraws vig every frame for n frames (after a warm-up) and returns figures per
## frame and frame times in milliseconds.
func _measure(vig: Control, SV: GDScript, n: int) -> Dictionary:
	for i in range(30):
		vig.queue_redraw()
		await process_frame
	SV.frame_log.clear()
	vig.queue_redraw()
	await process_frame
	var figures: int = SV.frame_log.size()
	var cpu := []
	var gpu := []
	var last := Time.get_ticks_usec()
	for i in range(n):
		vig.queue_redraw()
		await process_frame
		var now := Time.get_ticks_usec()
		cpu.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	vig.queue_free()
	await process_frame
	return {"figures": figures, "cpu_ms": _stats(cpu), "gpu_ms": _stats(gpu)}


func _stats(v: Array) -> Dictionary:
	var s := v.duplicate()
	s.sort()
	var total := 0.0
	for x in s:
		total += float(x)
	return {"mean": snappedf(total / maxi(1, s.size()), 0.001), "p95": snappedf(float(s[int(s.size() * 0.95)]), 0.001)}
