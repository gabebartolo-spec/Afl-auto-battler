extends SceneTree
## The New career setup with its two difficulty dials, for the lead's look:
##   godot --path . --script tools/visual/capture_dials.gd -- --out /tmp/dials [--size 390x844] [--club FRE] [--board ruthless --rivals cutthroat] [--scroll 1]
## Writes <out>.png (the whole screen) and <out>_dials_crop2x.png (the two dial rows at 2x).
## Needs a real renderer (see godot_quiet.sh --render).

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> Image:
	for i in range(14):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)
	return img


func _arg(name: String, fallback: String) -> String:
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == name:
			return str(a[i + 1])
	return fallback


func _run() -> void:
	var out := _arg("--out", "/tmp/dials")
	var wh := _arg("--size", "1280x720").split("x")
	W = int(wh[0])
	H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_dials.save"
	state.settings_path = "user://capture_dials_settings.cfg"
	state.reset()
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	# A club on the device, so the menu wears real colours (never Collingwood).
	var club := _arg("--club", "FRE")
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	root.get_node("Router").to_main_menu(false)
	await process_frame
	current_scene._on_new_career()
	var board := _arg("--board", "")
	var rivals := _arg("--rivals", "")
	await _shot(out + "_pre.png")
	if board != "":
		var b: Button = current_scene.find_child("BoardPatience_" + board, true, false)
		if b != null:
			b.emit_signal("pressed")
	if rivals != "":
		var r: Button = current_scene.find_child("RivalRecruiting_" + rivals, true, false)
		if r != null:
			r.emit_signal("pressed")
	if _arg("--scroll", "") != "":
		# The setup scrolls on a short window: scroll until both dials are in view.
		await process_frame
		await process_frame
		var note: Control = current_scene.find_child("RivalRecruitingNote", true, false)
		for sc in current_scene.find_children("*", "ScrollContainer", true, false):
			if (sc as Control).is_visible_in_tree() and (sc as Control).is_ancestor_of(note):
				var pos: float = float(note.get_global_rect().end.y - (sc as Control).get_global_rect().end.y) + 24.0
				(sc as ScrollContainer).scroll_vertical += int(maxf(pos, 0.0))
	var img := await _shot(out + ".png")
	var vis := root.get_visible_rect().size
	var k := float(img.get_width()) / vis.x
	var top: Control = current_scene.find_child("BoardPatienceNote", true, false)
	var first: Control = null
	for n in ["BoardPatience_patient"]:
		first = current_scene.find_child(n, true, false)
	var last: Control = current_scene.find_child("RivalRecruitingNote", true, false)
	if first != null and last != null and top != null:
		var a: Rect2 = first.get_global_rect()
		var z: Rect2 = last.get_global_rect()
		var box := Rect2((Vector2(a.position.x, a.position.y - 40) - Vector2(30, 0)) * k,
				(Vector2(z.end.x - a.position.x, z.end.y - a.position.y + 50) + Vector2(60, 0)) * k)
		box = box.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
		var crop := img.get_region(Rect2i(box))
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(out + "_dials_crop2x.png")
	for n in ["BoardPatience_patient", "BoardPatience_fair", "BoardPatience_ruthless", "BoardPatienceNote",
			"RivalRecruiting_easygoing", "RivalRecruiting_shrewd", "RivalRecruiting_cutthroat", "RivalRecruitingNote", "StartCareer"]:
		var c: Control = current_scene.find_child(n, true, false)
		if c != null:
			print("DIALS %s at %s, visible %s" % [n, str(c.get_global_rect()), str(c.is_visible_in_tree())])
	print("DIALS window %s image %dx%d (%.2f px per UI unit)" % [str(root.size), img.get_width(), img.get_height(), k])
	quit(0)
