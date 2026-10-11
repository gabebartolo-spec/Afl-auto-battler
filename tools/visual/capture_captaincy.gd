extends SceneTree
## The Captaincy page (stories P2-2), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_captaincy.gd -- --out /tmp/capt [--size 1280x720]
## Writes <out>_sheet.png (the page), <out>_picker.png (the list to pick from),
## <out>_cost.png (a pick that passes over a senior player, its cost said above Confirm)
## and <out>_mid.png (a mid-season change: the one change and what it costs).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/capt"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_capt.save"
	state.settings_path = "user://capture_capt_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	state.start_season("GEE", db.club_list("GEE"))
	var list := current_scene
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	current_scene.call("_open_captaincy")
	await _shot(out + "_sheet.png")
	var slot: Button = current_scene.find_child("CaptaincySlot_0", true, false)
	slot.emit_signal("pressed")
	await _shot(out + "_picker.png")
	# Pick the lowest-Leadership player who is not already named over a senior one.
	var target: Button = null
	var low := 999
	var rec: Dictionary = state.captaincy_record(state.my_club)
	for q in state.my_list:
		if Captaincy.is_named(rec, str(q["id"])):
			continue
		var l: int = Leadership.of(q)
		if l < low and float(q.get("age", 30.0)) < 24.0:
			low = l
			target = current_scene.find_child("Pick_" + str(q["id"]), true, false)
	if target != null:
		target.emit_signal("pressed")
	await _shot(out + "_cost.png")
	var confirm: Button = current_scene.find_child("CaptaincyConfirm", true, false)
	if confirm != null:
		confirm.emit_signal("pressed")
	await process_frame
	# Play a round, so the season has begun, then take the armband off again.
	state.advance()
	current_scene.call("_open_captaincy")
	for i in range(3):
		await process_frame
	slot = current_scene.find_child("CaptaincySlot_0", true, false)
	slot.emit_signal("pressed")
	for i in range(3):
		await process_frame
	var back: Button = null
	for q in state.my_list:
		if Leadership.of(q) > low and float(q.get("age", 0.0)) >= 28.0:
			back = current_scene.find_child("Pick_" + str(q["id"]), true, false)
			break
	if back != null:
		back.emit_signal("pressed")
	await _shot(out + "_mid.png")
	quit(0)
