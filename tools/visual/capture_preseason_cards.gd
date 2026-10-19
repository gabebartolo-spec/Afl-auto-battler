extends SceneTree
## The pre-season card stop (row 39, slice 5) for the lead's check and the director's look.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_preseason_cards.gd -- --out /tmp/precards --club FRE [--size 1280x720]
## Writes <out>_<NN>_<card>.png for each of the 11 cards (01_recruit ... 11_heated), and
## <out>_<NN>_<card>_low.png scrolled to the foot when the card runs past the screen. Each
## stop is the real pre-season screen after week 3, with the card and its player forced so
## it is the one on show.

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
	var senior: Dictionary = state.my_list[2]
	senior["contract_years"] = 1
	senior["age"] = maxf(29.0, float(senior.get("age", 29.0)))
	var young: Dictionary = state.my_list[12]
	young["age"] = 20.0
	young["potential"] = int(young.get("overall", 60)) + 10
	var knee: Dictionary = state.my_list[9]
	knee["injury_weeks"] = 3
	knee["injury_kind"] = "knee"
	var kid: Dictionary = state.list_player(str((trial["best"] as Array)[0]))
	var star: Dictionary = state.list_player(str((trial["worst"] as Array)[0]))
	var shots := [["pre_recruit_behind", recruit, "01_recruit"], ["pre_contract_talk", senior, "02_contract"],
			["pre_bulking_up", young, "03_bulking"], ["pre_camp", {}, "04_camp"], ["pre_leaders_vote", {}, "05_leaders"],
			["pre_knee_return", knee, "06_knee"], ["pre_flag_hangover", {}, "07_flag"], ["pre_kid_flying", kid, "08_kid"],
			["pre_star_last", star, "09_starlast"], ["pre_members_open", {}, "10_members"], ["pre_sim_heated", {}, "11_heated"]]
	for shot in shots:
		var card: Dictionary = state.story_card(str(shot[0]), shot[1])
		print(shot[2], " card: ", card.get("title", "EMPTY"))
		state.week_events = [card]
		state.preseason["story_pending"] = true
		root.get_node("Router").go("hub")
		await _frames(12)
		print("scene ", current_scene.name, " stop ", state.preseason_stop())
		await _shot(out + "_" + str(shot[2]) + ".png")
		var page: Node = current_scene.find_child("PreSeasonPage", true, false)
		var sc := page.get_parent() as ScrollContainer if page != null else null
		if sc != null and sc.get_v_scroll_bar().max_value > sc.size.y + 4.0:
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
			await _shot(out + "_" + str(shot[2]) + "_low.png")
	quit()
