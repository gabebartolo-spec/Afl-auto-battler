extends SceneTree
## Review capture of the Training screen's news with 13 risers named (dark).
## Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_training_rises.gd
## Environment: CAP_DIR (default "."), CAP_TAG (default "rises"), CAP_CLUB (default "FRE").
## A fresh career in a scratch save; never touches a real save.


func _frames(n := 8) -> void:
	for i in range(n):
		await process_frame


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := _env("CAP_DIR", ".")
	var tag := _env("CAP_TAG", "rises")
	var club := _env("CAP_CLUB", "FRE")
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_rises.save"
	state.settings_path = "user://capture_rises.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	UK.apply_appearance("dark")
	var rises := []
	var n := 0
	for p in state.my_list:
		if n >= 13:
			break
		rises.append([str(p["id"]), 70 + n % 5, 71 + n % 5 + (1 if n % 4 == 0 else 0)])
		n += 1
	state.last_training_report = {"count": 2, "label": "Round 3", "reserves_count": 17,
			"auto": {"rises": rises, "traits": [[str(state.my_list[2]["id"]), "wet_weather"]], "at_pot": []}}
	for size in [Vector2i(960, 540), Vector2i(390, 844)]:
		root.size = size
		DisplayServer.window_set_size(size)
		var bg := ColorRect.new()
		bg.color = UK.BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
		var sc = load("res://scenes/TrainingScene.tscn").instantiate()
		root.add_child(sc)
		await _frames(40)
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("%s/%s_%dx%d.png" % [dir, tag, size.x, size.y])
		sc.queue_free()
		bg.queue_free()
		await _frames(4)
	quit()
