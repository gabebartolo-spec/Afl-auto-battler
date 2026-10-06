extends SceneTree
## Idle and redraw audit (backlog item 23): in each state of a live match,
## how many frames are actually drawn, how often the main loop ticks, which
## nodes redraw and which keep processing. Report only; it changes nothing.
##   godot --path . --script tools/visual/measure_idle.gd [-- --secs 3]
## Prints IDLE lines, one per state:
##   playing   the match playing
##   paused    the view paused by the coach (play/pause)
##   frozen    a stoppage call up, the scene frozen behind it, after it settles
##   covered   a player sheet open over the paused match
##   covered_playing  the same sheet over a playing match
##   background  the app told it lost focus and was paused (as Android does)

var _draws := {}      # node path -> redraws in this window
var _ticks := 0


func _initialize() -> void:
	_run.call_deferred()


func _hook(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).draw.is_connected(_on_draw.bind(n)):
		(n as CanvasItem).draw.connect(_on_draw.bind(n))
	for c in n.get_children():
		_hook(c)


func _on_draw(n: Node) -> void:
	var key := "%s (%s)" % [n.name, n.get_class() if n.get_script() == null else str(n.get_script().resource_path).get_file()]
	_draws[key] = int(_draws.get(key, 0)) + 1


func _on_tick() -> void:
	_ticks += 1


func _processing(n: Node, out: Array) -> void:
	if n.is_processing() or n.is_physics_processing():
		out.append("%s%s" % [n.name, "" if n.get_script() == null else " (%s)" % str(n.get_script().resource_path).get_file()])
	for c in n.get_children():
		_processing(c, out)


func _measure(label: String, secs: float) -> void:
	_hook(root)
	_draws = {}
	_ticks = 0
	var f0 := Engine.get_frames_drawn()
	await create_timer(secs).timeout
	var frames := Engine.get_frames_drawn() - f0
	var procs := []
	_processing(root, procs)
	var top: Array = _draws.keys()
	top.sort_custom(func(a, b): return int(_draws[a]) > int(_draws[b]))
	var shown := []
	for k in top.slice(0, 6):
		shown.append("%s %.1f/s" % [k, float(_draws[k]) / secs])
	print("IDLE %-16s | frames drawn %5.1f/s | loop ticks %5.1f/s | redraws: %s | processing: %s" % [
		label, frames / secs, _ticks / secs,
		", ".join(shown) if not shown.is_empty() else "none", ", ".join(procs) if not procs.is_empty() else "none"])


func _run() -> void:
	await process_frame
	var secs := 3.0
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--secs":
			secs = float(a[i + 1])
	print("IDLE setup | low_processor_mode %s, sleep %d us, max_fps %d" % [OS.low_processor_usage_mode,
		OS.low_processor_usage_mode_sleep_usec, Engine.max_fps])
	process_frame.connect(_on_tick)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://idle.save"
	state.settings_path = "user://idle_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(412, 915)
	DisplayServer.window_set_size(root.size)
	state.prepare_interactive_match()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	for i in range(6):
		await process_frame
	m.find_child("StartQuarter", true, false).emit_signal("pressed")
	for i in range(6):
		await process_frame
	var pitch = m.get("_pitch")
	pitch.play()
	await _measure("playing", secs)
	pitch.pause()
	# Redraws after a pause, second by second: the camera's settle.
	var settle := []
	for i in range(6):
		var f := Engine.get_frames_drawn()
		await create_timer(1.0).timeout
		settle.append(Engine.get_frames_drawn() - f)
	print("IDLE paused settle | frames drawn each second after the pause: %s" % str(settle))
	await _measure("paused", secs)
	# What a processing node costs when nothing changes: its _process, timed.
	var t0 := Time.get_ticks_usec()
	for i in range(2000):
		pitch._process(1.0 / 60.0)
	print("IDLE paused cost | PitchView._process %.1f us a tick while paused" % [float(Time.get_ticks_usec() - t0) / 2000.0])
	print("IDLE paused why | cam moving %s, zoom moving %s, flash %s, caption %s" % [
		pitch.get("_cam").distance_to(pitch.get("_drawn_cam")) > 0.05,
		absf(float(pitch.get("_zoom")) - float(pitch.get("_drawn_zoom"))) > 0.002,
		not (pitch.director.flash as Dictionary).is_empty(), not (pitch.get("_caption") as Dictionary).is_empty()])
	pitch.set_process(false)
	await _measure("paused_noproc", secs)
	pitch.set_process(true)

	# A player sheet over the paused match, then over a playing one.
	m.call("_player_sheet", "Pick a player", m.call("_roster_side", int(m.get("_my_side"))), "",
			func(_id): pass)
	await create_timer(0.5).timeout
	await _measure("covered", secs)
	pitch.play()
	await _measure("covered_playing", secs)
	m.call("_close_sheet")
	pitch.pause()

	# A stoppage call: the scene freezes behind it once its film has run.
	var sim = state.pending_sim
	sim.pending_moment = {}
	sim.moment_side = int(m.get("_my_side"))
	sim.set("_moments_this_q", 0)
	sim.set("_last_moment_chain", -1000)
	sim.set("_run", [0, 0])
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	for side in range(2):
		sim.team_stats[side]["goals"] = 9.0 + side
		sim.team_stats[side]["behinds"] = 8.0
		for p in sim.squads[side].ground:
			sim.energy[str(p["id"])] = 90.0
	sim.call("_boundary_moment")
	if not sim.pending_moment.is_empty():
		m.call("_show_moment")
		await create_timer(6.0).timeout
		await _measure("frozen", secs)
		var vig = m.find_child("StoppageVignette", true, false)
		if vig != null:
			var t1 := Time.get_ticks_usec()
			for i in range(2000):
				vig._process(1.0 / 60.0)
			print("IDLE frozen cost | StoppageVignette._process %.1f us a tick once frozen" % [float(Time.get_ticks_usec() - t1) / 2000.0])
	else:
		print("IDLE frozen           | no stoppage call came up; not measured")

	# Backgrounded: what Android sends when the app goes behind another.
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await create_timer(0.5).timeout
	await _measure("background", secs)
	quit(0)
