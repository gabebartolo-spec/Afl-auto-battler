extends SceneTree
## A player's Leadership on his profile (stories P2-1), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_leadership.gd -- --out /tmp/lead [--size 1280x720]
## Writes <out>_top.png (the real captain's profile with his 2026 role) and
## <out>_ratings.png (scrolled to the Ratings with Leadership at the end).

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
	var out := "/tmp/lead"
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
	state.save_path = "user://capture_lead.save"
	state.settings_path = "user://capture_lead_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	state.start_season("GEE", db.club_list("GEE"))
	var cap: Dictionary = state.my_list[0]
	for q in state.my_list:
		if Leadership.role_2026(q) == "captain":
			cap = q
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	current_scene.call("_open_profile", str(cap["id"]))
	await _shot(out + "_top.png")
	var note: Control = current_scene.find_child("ProfileLeadershipNote", true, false)
	var n: Node = note
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(note)
		(n as ScrollContainer).scroll_vertical += 400
	await _shot(out + "_ratings.png")
	quit(0)
