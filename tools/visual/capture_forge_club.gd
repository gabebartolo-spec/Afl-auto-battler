extends SceneTree
## Visual review tool for Club Forge's Create a club, on a phone (390x844) or
## any size given as --size WxH (1280x720 for the PC).
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_forge_club.gd -- --out /tmp/forge_club
## Writes <out>_sheet.png: the Forge with no club; the form's home, name and
## colours; its guernsey; the Forge with the club saved; New career offering it.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _scroll_to(scene: Node, frac: float) -> void:
	await process_frame
	await process_frame
	var sc: ScrollContainer = scene._scroll
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value * frac)


func _run() -> void:
	var out := "/tmp/forge_club"
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
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_forge_player({})
	state.set_forge_club({})
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var shots := []
	var scene = load("res://scenes/ClubForgeScene.tscn").instantiate()
	root.add_child(scene)
	shots.append(await _shot())
	scene.find_child("ForgeCreateClub", true, false).emit_signal("pressed")
	await process_frame
	scene._pick_place("port-melbourne")
	scene._club["short"] = "Borough"
	scene._club["code"] = "PMB"
	scene._club["design"] = "hoops"
	scene._build()
	shots.append(await _shot())
	# Paint the hoops gold, then outline them as the pointer would.
	scene._brush = "#F2B231"
	scene._paint_part("pattern")
	scene._brush = "#F5F5F5"
	scene._rebuild_paint()
	for c in scene.find_children("Forge*", "GuernseyCrest", true, false):
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.highlight = "pattern"
			c.queue_redraw()
	await _scroll_to(scene, 0.45)
	shots.append(await _shot())
	await _scroll_to(scene, 1.0)
	shots.append(await _shot())
	scene._on_save_club()
	shots.append(await _shot())
	scene.queue_free()
	await process_frame
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_new_career()
	shots.append(await _shot())
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	state.set_forge_club({})
	print("wrote ", out + "_sheet.png")
	quit(0)
