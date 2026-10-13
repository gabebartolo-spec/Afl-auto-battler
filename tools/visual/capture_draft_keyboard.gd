extends SceneTree
## The League Draft with "Search players" focused and the window shrunk the way
## a phone's keyboard shrinks it. Needs a real renderer:
##   godot --path . --script tools/visual/capture_draft_keyboard.gd -- --out /tmp/kbd
## Writes <out>_up.png (typed "van", window 390x464) and <out>_down.png (390x844).


func _initialize() -> void:
	_run.call_deferred()


func _frames(n := 8) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/kbd"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted(),
			db.active_clubs(2026).duplicate(), 12345)
	root.size = Vector2i(390, 844)
	DisplayServer.window_set_size(Vector2i(390, 844))
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "FRE")
	await _frames()
	ui.call("_select_tab", "pool")
	await _frames()
	var field: LineEdit = ui.find_child("PlayerSearch", true, false)
	field.grab_focus()
	field.insert_text_at_caret("van")
	await _frames()
	root.size = Vector2i(390, 464)
	DisplayServer.window_set_size(Vector2i(390, 464))
	await _frames(12)
	await _shot(out + "_up.png")
	var same := ui.find_child("PlayerSearch", true, false) == field and is_instance_valid(field)
	print("same field: ", same, " focused: ", same and field.has_focus())
	root.size = Vector2i(390, 844)
	DisplayServer.window_set_size(Vector2i(390, 844))
	await _frames(12)
	await _shot(out + "_down.png")
	quit(0)
