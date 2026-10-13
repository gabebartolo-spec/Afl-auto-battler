extends SceneTree
## The cost line under each answer on the hub's decision card, for the director's
## look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_card_stakes.gd -- --out /tmp/stakes [--size 1280x720]
## Writes <out>_one.png (one cost: the extra session), <out>_two.png (two costs on
## one answer: the club press row) and <out>_risk.png (a risk: playing a sore player).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if W >= 760 and img.get_width() != W:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/stakes"
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
	state.save_path = "user://capture_stakes.save"
	state.settings_path = "user://capture_stakes_settings.cfg"
	state.show_real_names = false
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	if W >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(W, H))
		for i in range(10):
			await process_frame
		var factor := float(W) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(W * factor), int(H * factor)))
			for i in range(10):
				await process_frame
		print("visible ", root.get_visible_rect().size)
	else:
		DisplayServer.window_set_size(Vector2i(W, H))
		root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	state.start_season("FRE", db.club_list("FRE"))
	var p: Dictionary = state.my_list[4]
	var cap: Dictionary = {}
	var rec: Dictionary = state.captaincy_record("FRE")
	for q in state.my_list:
		if Captaincy.role_of(rec, str(q["id"])) == "captain":
			cap = q
	for pair in [["captain_group_flat", cap, "_captain"], ["training_extra_session", {}, "_one"], ["media_papers_again", p, "_two"], ["selection_talk_dropped", p, "_three"], ["health_pulled_up_sore", p, "_risk"]]:
		state.week_events = [state.story_card(str(pair[0]), pair[1])]
		root.get_node("Router").go("hub")
		for i in range(8):
			await process_frame
		var card: Control = root.get_tree().current_scene.find_child("WeekEvent", true, false)
		var sc := card.get_parent() if card != null else null
		while sc != null and not (sc is ScrollContainer):
			sc = sc.get_parent()
		if sc != null:
			(sc as ScrollContainer).scroll_vertical = 0
			for i in range(3):
				await process_frame
			(sc as ScrollContainer).scroll_vertical = int(card.global_position.y - (sc as Control).global_position.y) + (sc as ScrollContainer).scroll_vertical - 24
			for i in range(4):
				await process_frame
		await _shot(out + str(pair[2]) + ".png")
	quit(0)
