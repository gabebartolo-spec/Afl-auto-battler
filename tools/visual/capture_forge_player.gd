extends SceneTree
## Visual review tool for Create a player's preview (PlayerPreview), on a phone
## (390x844) or any size given as --size WxH (1280x720 for the PC).
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_forge_player.gd -- --out /tmp/forge_player
## Writes <out>_sheet.png: a new prospect as he starts; a named midfielder with
## his own look and number; a tall ruckman; a small forward, bald; the form
## scrolled to the look with the preview still in view.

var W := 390
var H := 844

## [first, last, role, height, number, skin, hair colour, hair style]
const LOOKS := [
	["Jack", "Mercer", "MID", 186, 7, 1, 0, "swept_back"],
	["Tom", "Okafor", "RUCK", 204, 23, 4, 0, "dreadlocks"],
	["Billy", "Nash", "FWD", 176, 41, 0, 4, "bald"],
]


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/forge_player"
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
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var shots := []
	var scene = load("res://scenes/ClubForgeScene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.find_child("ForgeCreatePlayer", true, false).emit_signal("pressed")
	shots.append(await _shot())
	for l in LOOKS:
		var s: Dictionary = scene._spec
		s["first"] = l[0]
		s["last"] = l[1]
		s["role"] = l[2]
		s["height_cm"] = l[3]
		s["number_pref"] = l[4]
		s["look"]["skin"] = l[5]
		s["look"]["hair"] = l[6]
		s["look"]["hair_style"] = l[7]
		scene._build()
		shots.append(await _shot())
	var sc: ScrollContainer = scene._scroll
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value * 0.8)
	shots.append(await _shot())
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out, "_sheet.png")
	quit(0)
