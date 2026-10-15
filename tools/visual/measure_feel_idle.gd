extends SceneTree
## Battery check for the living background (director, 2026-10-11): how many
## frames the hub draws on arrival and then per idle minute, with
## low_processor_mode as the game ships. Report only; it changes nothing.
## Needs a window (headless draws nothing):
##   godot --path . --script tools/visual/measure_feel_idle.gd [-- --reduced] [--idle 60]
## --reduced: Reduced motion on (no fades, count-ups or drift): the still hub.
## Prints FEEL_IDLE lines: frames drawn in the first 15 s after arriving, then
## in the next --idle seconds with nothing touched, and what is still
## processing or redrawing at the end.

var _draws := {}


func _initialize() -> void:
	_run.call_deferred()


func _hook(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).draw.is_connected(_on_draw.bind(n)):
		(n as CanvasItem).draw.connect(_on_draw.bind(n))
	for c in n.get_children():
		_hook(c)


func _on_draw(n: Node) -> void:
	var key := str(n.name)
	_draws[key] = int(_draws.get(key, 0)) + 1


func _window(label: String, secs: float) -> void:
	_draws = {}
	var f0 := Engine.get_frames_drawn()
	await create_timer(secs).timeout
	var frames := Engine.get_frames_drawn() - f0
	var top: Array = _draws.keys()
	top.sort_custom(func(a, b): return int(_draws[a]) > int(_draws[b]))
	var shown := []
	for k in top.slice(0, 5):
		shown.append("%s %d" % [k, int(_draws[k])])
	print("FEEL_IDLE %-8s | %5.1f s | frames drawn %5d (%.1f/s, %d a minute) | redraws: %s" % [
		label, secs, frames, frames / secs, roundi(frames / secs * 60.0), ", ".join(shown) if not shown.is_empty() else "none"])


func _run() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	var reduced := a.has("--reduced")
	var idle := 60.0
	for i in range(a.size() - 1):
		if str(a[i]) == "--idle":
			idle = float(a[i + 1])
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://feel_idle.save"
	state.settings_path = "user://feel_idle_settings.cfg"
	if state.has_method("set_reduced_motion"):
		state.set_reduced_motion(reduced)
	state.reset()
	state.replay_seed = 2027
	state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(390, 844)
	DisplayServer.window_set_size(root.size)
	print("FEEL_IDLE setup | low_processor_mode %s, sleep %d us, max_fps %d, reduced motion %s" % [
		OS.low_processor_usage_mode, OS.low_processor_usage_mode_sleep_usec, Engine.max_fps, reduced])
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	_hook(root)
	await _window("arrival", 15.0)
	_hook(root)
	await _window("idle", idle)
	var timers := []
	for t in root.find_children("*", "Timer", true, false):
		if not (t as Timer).is_stopped():
			timers.append(str(t.get_path()))
	print("FEEL_IDLE end | running timers: %s" % (", ".join(timers) if not timers.is_empty() else "none"))
	quit(0)
