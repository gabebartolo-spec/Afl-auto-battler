extends SceneTree
## Full-size captures of the hub and My list for a PC window (needs a real
## renderer; capture.yml runs it):
##   gh workflow run capture.yml --ref <branch> -f tool=capture_hub_pc -f args="--size 1280x720"
## Writes <out>_hub.png and <out>_list.png. A fresh Collingwood career; never
## touches a real save.

var _w := 1280
var _h := 720
var _scroll := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "hub_pc"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--scroll":
				_scroll = int(str(a[i + 1]))
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://capture_hub.save"
	state.settings_path = "user://capture_hub.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	router.stack = []
	router.go("main")
	await _frames(8)
	router.go("hub")
	await _frames(20)
	# The first-visit intro is answered, as a returning player has.
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == "Got it" and (b as Button).is_visible_in_tree():
			(b as Button).emit_signal("pressed")
	await _frames(20)
	if _scroll > 0:
		# Scrolled, as a player reading down the week would be.
		for sc in root.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = _scroll
			break
		await _frames(10)
	_save(out + "_hub.png")
	router.go("list")
	await _frames(20)
	_save(out + "_list.png")
	quit()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
