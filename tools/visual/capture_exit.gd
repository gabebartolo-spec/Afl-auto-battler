extends SceneTree
## The main menu with its Exit game button, for the director's look:
##   godot --path . --script tools/visual/capture_exit.gd -- --out /tmp/exit [--size 1280x720]
## Writes <out>_fresh.png (no career) and <out>_saved.png (a career to Continue).
## Needs a real renderer (capture.yml).

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(12):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/exit"
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
	state.save_path = "user://capture_exit.save"
	state.settings_path = "user://capture_exit_settings.cfg"
	state.reset()
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	root.get_node("Router").to_main_menu(false)
	await _shot(out + "_fresh.png")
	var btn: Control = current_scene.find_child("ExitGame", true, false)
	print("EXIT button %s, rect %s" % ["missing" if btn == null else str(btn.get("text")), "-" if btn == null else str(btn.get_global_rect())])
	state.start_season("COL", db.club_list("COL"))
	state.tutorials = false
	root.get_node("Router").to_main_menu(false)
	await _shot(out + "_saved.png")
	quit(0)
