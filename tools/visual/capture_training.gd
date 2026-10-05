extends SceneTree
## Visual review tool for learning a position on the Training screen, on a
## phone (390x844). Needs a real renderer:
##   godot --path . --script tools/visual/capture_training.gd -- --out /tmp/training
## Writes <out>_sheet.png: a candidate's plan choices, the project under way,
## and the list row.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(4):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/training"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var cand := {}
	for p in state.my_list:
		if (state.learnable_jobs(p) as Array).size() >= 2:
			cand = p
			break
	if cand.is_empty():
		print("no candidate")
		quit(1)
		return
	var scene = load("res://scenes/TrainingScene.tscn").instantiate()
	root.add_child(scene)
	var shots := []
	scene._open_player(str(cand["id"]))
	shots.append(await _shot())
	var job: String = state.learnable_jobs(cand)[0]
	state.set_player_plan(str(cand["id"]), state.LEARN_PREFIX + job)
	cand["project"]["weeks"] = 3
	scene._build()
	shots.append(await _shot())
	scene._showing_detail = false
	scene._build()
	shots.append(await _shot())
	var sheet := Image.create(W * 3, H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
