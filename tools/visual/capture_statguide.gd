extends SceneTree
## Captures the stat guide opened over Training at a given size. Needs a real renderer:
##   godot --path . --script tools/visual/capture_statguide.gd -- --out /tmp/sg --w 1280 --h 720

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/sg"
	var w := 390
	var h := 844
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--w": w = int(a[i + 1])
			"--h": h = int(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var scene = load("res://scenes/TrainingScene.tscn").instantiate()
	root.add_child(scene)
	for i in range(6):
		await process_frame

	var btn: Button = scene.find_child("StatGuideButton", true, false)
	btn.emit_signal("pressed")
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + "_%dx%d.png" % [w, h])
	print("wrote ", out)
	quit(0)
