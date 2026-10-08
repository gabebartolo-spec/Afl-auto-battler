extends SceneTree
## STYLE-07 review: the game as a PC shows it, fullscreen or in a window, on
## this machine's real display (needs a real renderer and a desktop):
##   godot --path . --script tools/visual/capture_desktop.gd -- --out /tmp/desk [--window 1600x900]
##       [--screen-size standard|large|tv]
## Writes <out>_sheet.png: main menu, New career, the hub and your list, each
## shrunk to a quarter-width tile, with the window, logical canvas and scale
## printed.

const TILE := 0.25


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(img.get_width() * TILE), int(img.get_height() * TILE), Image.INTERPOLATE_LANCZOS)
	return img


func _run() -> void:
	var out := "/tmp/desk"
	var window := ""
	var screen_size := "standard"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--screen-size":
			screen_size = str(a[i + 1])
		elif str(a[i]) == "--window":
			window = str(a[i + 1])
	root.get_node("ScreenLayout").call("set_screen_size", screen_size)
	if window == "":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		var wh := window.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	for i in range(10):
		await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_desktop.save"
	state.settings_path = "user://capture_desktop_settings.cfg"
	state.reset()
	print("window %s logical %s screen scale %s dpi %d" % [root.size, root.content_scale_size,
			DisplayServer.screen_get_scale(), DisplayServer.screen_get_dpi()])
	var shots := []
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	shots.append(await _shot())
	main._on_new_career()
	shots.append(await _shot())
	main.queue_free()
	state.start_season("MEL", db.club_list("MEL"))
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	shots.append(await _shot())
	hub.queue_free()
	var lst = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(lst)
	shots.append(await _shot())
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
