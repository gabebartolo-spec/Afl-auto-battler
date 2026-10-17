extends SceneTree
## The pre-season card stop (row 39, slice 5) for the lead's check and the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_preseason_cards.gd -- --out /tmp/precards --club FRE [--size 1280x720]
## Writes <out>_recruit.png (card 1, a named player), <out>_camp.png (card 4, three choices)
## and <out>_starlast.png (card 9, the time trial's back marker). Each stop is the real
## pre-season screen after week 3, with the card forced so it is the one on show.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames(40)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if W >= 760 and img.get_width() != W:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/precards"
	var club := "FRE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	load("res://scripts/core/Features.gd").set_on("preseason", true)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_precards.save"
	state.settings_path = "user://capture_precards_settings.cfg"
	state.show_real_names = true
	state.reset()
	state.career_seed = 4127
	state.replay_seed = 4127
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("seen_training_intro", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	await _frames(10)
	var layout = root.get_node("ScreenLayout")
	var density: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, density)
	layout._update_scale()
	await _frames(13)
	state.start_season(club, db.club_list(club))
	state.open_preseason()
	state.preseason_advance()   # weeks 1 to 3: the time trial
	state.preseason["trial_seen"] = true
	var trial: Dictionary = state.preseason_trial()
	var recruit: Dictionary = state.my_list[6]
	recruit["joined"] = state.season_year - 1
	var star: Dictionary = state.list_player(str((trial["worst"] as Array)[0]))
	for shot in [["pre_recruit_behind", recruit, "recruit"], ["pre_camp", {}, "camp"], ["pre_star_last", star, "starlast"]]:
		var card: Dictionary = state.story_card(str(shot[0]), shot[1])
		print(shot[2], " card: ", card.get("title", "EMPTY"))
		state.week_events = [card]
		state.preseason["story_pending"] = true
		root.get_node("Router").go("hub")
		await _frames(12)
		print("scene ", current_scene.name, " stop ", state.preseason_stop())
		await _shot(out + "_" + str(shot[2]) + ".png")
	quit()
