extends SceneTree
## Real renderer: godot --path . --rendering-method gl_compatibility --script tools/visual/capture_training_rows.gd
## Environment: CAP_W, CAP_H (default 390x800), CAP_OUT (file prefix, default
## "training_rows"). Saves <prefix>_list.png and <prefix>_group.png: the Training
## list with a long name, an injury stamp, a manual plan and a short name, then
## the same list with a group selected. Illustrative fixture only; it never
## touches a real save.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://capture_training.save"
	state.settings_path = "user://capture_training.cfg"
	state.show_real_names = false
	db.reload()
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	var w := int(OS.get_environment("CAP_W")) if OS.get_environment("CAP_W") != "" else 390
	var h := int(OS.get_environment("CAP_H")) if OS.get_environment("CAP_H") != "" else 800
	var prefix := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "training_rows"
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	# The states a real list shows: a long name, an injury stamp, a manual plan.
	var list: Array = state.my_list
	list[0]["generic_name"] = "Alexander Papaioannou-Featherstone"
	list[1]["injury_weeks"] = 3
	state.set_player_plan(str(list[2]["id"]), "manual")
	state.set_setting("seen_training_intro", true)
	router.go("training")
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix + "_list.png")
	var scene = current_scene
	scene.set("_bulk_selected", {str(list[1]["id"]): true, str(list[3]["id"]): true})
	scene.call("_build")
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix + "_group.png")
	print("CAPTURE saved ", prefix, " at ", w, "x", h)
	quit()
