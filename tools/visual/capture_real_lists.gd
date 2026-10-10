extends SceneTree
## Visual review tool for a real 2026 lists career (ARD-M5-016) on a phone
## (390x844):
##   godot --path . --script tools/visual/capture_real_lists.gd -- --out /tmp/real
## Writes <out>_sheet.png: New career with Real 2026 lists chosen, the club
## choice for the 2026 National Draft, the draft board, and the 2027 Hub.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/real"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.set_setting("seen_weekly_loop_intro", true)
	state.reset()
	state.replay_seed = 77
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var shots := []
	# 1. New career, Real 2026 lists picked.
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("_show_setup")
	await process_frame
	var b: Button = main.find_child("StartMode_real", true, false)
	if b != null:
		b.emit_signal("pressed")
	shots.append(await _shot())
	main.queue_free()
	await process_frame
	# 2. The club choice for the 2026 National Draft.
	state.begin_real_lists()
	var ds = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ds)
	shots.append(await _shot())
	# 3. The board, as Geelong.
	ds.call("_on_club_chosen", "GEE")
	shots.append(await _shot())
	ds.queue_free()
	await process_frame
	# 4. Draft done: the 2027 Hub.
	var guard := 0
	while not state.draft.is_finished() and guard < 400:
		guard += 1
		if state.draft.is_user_turn():
			var board: Array = state.draft.board("", "", "", "overall", true)
			if board.is_empty() or not state.draft.pick(board[0]):
				break
	state.finish_intake_draft()
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	shots.append(await _shot())
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	quit(0)
