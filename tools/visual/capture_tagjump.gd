extends SceneTree
## Visual review tool: the break before the first ball-up, before and after a
## tag target is tapped (the sections must not change column).
##   --size WxH  --club CODE (default FRE)  --out PREFIX
## Writes <out>_before.png and <out>_after.png. Never touches a real save.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "tagjump"
	var club := "FRE"
	var w := 1280
	var h := 720
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--club":
				club = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				w = int(wh[0])
				h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_tagjump.save"
	state.settings_path = "user://capture_tagjump.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	if not state.prepare_interactive_match():
		quit(1)
		return
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(w, h))
	for i in range(10):
		await process_frame
	var factor := float(w) / maxf(1.0, root.get_visible_rect().size.x)
	if factor > 1.05:
		DisplayServer.window_set_size(Vector2i(int(w * factor), int(h * factor)))
		for i in range(10):
			await process_frame
	print("visible ", root.get_visible_rect().size)
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	for i in range(12):
		await process_frame
	root.get_texture().get_image().save_png(out + "_before.png")
	var tp: Node = scene.find_child("TagPicker", true, false)
	for b in tp.find_children("TagPickerGrid_*", "Button", true, false):
		if str(b.name) != "TagPickerGrid_":
			b.emit_signal("pressed")
			break
	for i in range(12):
		await process_frame
	root.get_texture().get_image().save_png(out + "_after.png")
	quit()
