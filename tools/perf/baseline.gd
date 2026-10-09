extends SceneTree
## Performance baseline on this machine (no phone). Needs a real renderer, so it
## is not headless; run it offscreen with the Mobile renderer via
## tools/perf/run_baseline.sh, which sets that up and isolates the save folder.
## godot --path . --rendering-method mobile --script tools/perf/baseline.gd -- [--out FILE]
## Prints PERF lines; the same lines go to FILE when given. Measures: GameDB
## boot, each main scene's load and first draw (the Hub twice: first load,
## then again with the resources cached), autosave, the first broadcast
## vignette's frame hitch, and a match's frame times and draw calls.
## Nothing here touches a real save or the sim's results.

var _lines: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _say(s: String) -> void:
	print(s)
	_lines.append(s)


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(p * b.size()))])


func _frames(n: int, host: Node = null) -> Dictionary:
	# Real frame times and draw calls over n frames.
	var dts: Array = []
	var calls: Array = []
	var last := Time.get_ticks_usec()
	for i in range(n):
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"dts": dts, "calls": calls}


func _run() -> void:
	var out := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var gs = root.get_node("GameState")
	var router = root.get_node("Router")
	_say("PERF renderer %s | adapter %s | window %s" % [
			str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
			RenderingServer.get_video_adapter_name(), str(root.size)])
	_say("PERF engine start to first script frame %d ms (includes the GameDB and autoload boot)" % Time.get_ticks_msec())

	var t := Time.get_ticks_usec()
	db.reload()
	_say("PERF GameDB reload %.0f ms (%d clubs)" % [(Time.get_ticks_usec() - t) / 1000.0, db.clubs.size() if "clubs" in db else 0])

	gs.autosave_enabled = false
	seed(43000)
	gs.reset()
	gs.start_season("GEE", db.club_list("GEE"))

	# Scene loads: load, then add and wait for the first drawn frame.
	for key in ["hub", "hub", "list", "selection", "training", "staff", "coaching", "offseason", "season_review"]:
		var path: String = str(router.SCENES[key])
		var t0 := Time.get_ticks_usec()
		var ps: PackedScene = load(path)
		var t1 := Time.get_ticks_usec()
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		var t2 := Time.get_ticks_usec()
		await process_frame
		await process_frame
		var t3 := Time.get_ticks_usec()
		_say("PERF scene %-14s load %5.0f ms | instance and ready %5.0f ms | first draw %5.0f ms" % [
				key + (" (again)" if key == "hub" and _lines.back().find("scene hub ") >= 0 else ""),
				(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
		inst.queue_free()
		await process_frame

	# Autosave.
	gs.autosave_enabled = true
	var times: Array = []
	for i in range(7):
		gs.mark_dirty()
		var s0 := Time.get_ticks_usec()
		gs.save_career()
		times.append((Time.get_ticks_usec() - s0) / 1000.0)
	var size := 0
	var f := FileAccess.open(gs.save_path, FileAccess.READ)
	if f != null:
		size = f.get_length()
	_say("PERF autosave median %.0f ms, slowest %.0f ms, file %.1f MB" % [_median(times), float(_pct(times, 1.0)), size / 1048576.0])
	gs.autosave_enabled = false

	# First broadcast vignette: the frame times around its first draw.
	var squad: Array = db.club_list("COL")
	var star: Dictionary = squad[0]
	var ev := {"kind": "goal", "side": 0, "num": int(star.get("num", 7)), "player_id": str(star["id"]),
			"club": "COL", "q": 4, "set_shot": false, "crumb": false}
	var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
	root.add_child(vig)
	vig.size = Vector2(root.size)
	var v0 := Time.get_ticks_usec()
	vig.setup("goal_line", ev, {}, {"home": "COL", "away": "CAR"})
	var setup_ms := (Time.get_ticks_usec() - v0) / 1000.0
	var fr: Dictionary = await _frames(30)
	_say("PERF first vignette (goal_line) setup %.0f ms; first frame %.0f ms, then median %.1f ms, slowest %.1f ms" % [
			setup_ms, float((fr["dts"] as Array)[0]), _median((fr["dts"] as Array).slice(1)), float(_pct((fr["dts"] as Array).slice(1), 1.0))])
	vig.queue_free()
	await process_frame

	# A match in the live view: frame times and draw calls.
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim = load("res://scripts/sim/MatchSim.gd").new(
			squad_script.new("GEE", db.club_list("GEE"), true, "GEE"),
			squad_script.new("COL", db.club_list("COL"), false, "COL"), 42)
	var m0 := Time.get_ticks_usec()
	var res: Dictionary = sim.run()
	_say("PERF MatchSim.run %.0f ms (%d events)" % [(Time.get_ticks_usec() - m0) / 1000.0, (res["events"] as Array).size()])
	res["home"] = "GEE"
	res["away"] = "COL"
	var pitch = load("res://scripts/ui/PitchView.gd").new()
	pitch.size = Vector2(root.size)
	root.add_child(pitch)
	await process_frame
	pitch.setup(res)
	pitch.set_speed(1.0)
	pitch.play()
	var mf: Dictionary = await _frames(600)
	var d: Array = mf["dts"]
	var c: Array = mf["calls"]
	var slow := d.filter(func(x): return x > 33.4).size()
	_say("PERF match view, 600 frames: median %.1f ms, 95th %.1f ms, slowest %.1f ms, %d frames over 33 ms; draw calls median %d, most %d" % [
			_median(d), _pct(d, 0.95), float(_pct(d, 1.0)), slow, int(_median(c)), int(_pct(c, 1.0))])
	if out != "":
		var wf := FileAccess.open(out, FileAccess.WRITE)
		for l in _lines:
			wf.store_line(str(l))
	quit()
