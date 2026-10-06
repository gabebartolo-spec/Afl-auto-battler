extends SceneTree
## Visual review tool for the break screen's "Their loose defender" call
## (ARD-M4-004): which of your forwards goes up the ground with their loose
## man, "Nobody" first. Phone portrait (390x844), dark. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_minder_picker.gd
## Environment: CAP_OUT (png path, default "minder_picker.png"), CAP_MODE
## ("dark" default or "light"). A fresh Melbourne career's first match, opened
## at quarter time with the other side's loose defender set (the AI's own rule
## picks one only after he's beaten in the air, so it's set here to show the
## call). Never touches a real save.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "minder_picker.png"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "dark"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_minder.save"
	state.settings_path = "user://capture_minder.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	if not state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	var sim = state.pending_sim
	sim.run_quarter()
	var opp: int = 1 - int(sim.moment_side)
	var loose := ""
	for p in (sim.squads[opp]).ground:
		if str(p.get("role", "")) == "DEF":
			loose = str(p["id"])
			break
	sim.set_interceptor(opp, loose, false)
	print("loose: ", loose, " quarter ", sim.current_quarter)
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	for i in range(10):
		await process_frame
	var pick: Control = scene.find_child("SpareMinderPicker", true, false)
	if pick == null:
		push_error("no SpareMinderPicker on the break screen")
	else:
		var box: ScrollContainer = null
		var n: Node = pick.get_parent()
		while n != null and box == null:
			if n is ScrollContainer:
				box = n
			n = n.get_parent()
		if box != null:
			box.scroll_vertical = int(pick.global_position.y - box.global_position.y) - 120
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(out) != OK:
		push_error("could not save " + out)
	print("wrote ", out)
	quit()
