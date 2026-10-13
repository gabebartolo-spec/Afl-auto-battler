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
	var p: Dictionary = {}
	var papers: Dictionary = {}
	# Try seeds until the club is in a real run of losses in rounds 8 to 12.
	for seed in range(1, 25):
		state.replay_seed = seed
		state.career_seed = seed
		state.start_season(club, db.club_list(club))
		p = state.my_list[4]
		state.advance()
		state.week_events = [state.story_card("media_in_the_papers", p)]
		papers = state.week_events[0]
		for oi in range((papers["options"] as Array).size()):
			for e in (papers["options"][oi]["effects"] as Array):
				if str(e.get("op", "")) == "flag" and str(e.get("name", "")) == "backed_in_papers":
					state.resolve_card(0, oi)
					break
			if bool(papers.get("resolved", false)):
				break
		var found := false
		for k in range(11):
			state.advance()
			if state.season.round_index >= 7 and state.season.round_index <= 11 and state.losing_streak >= 3:
				found = true
				break
		if found:
			print("seed ", seed)
			break
	print("round ", state.season.round_index + 1, " losing run ", state.losing_streak, " papers resolved ", papers.get("resolved", false))
	var cap: Dictionary = {}
	var rec: Dictionary = state.captaincy_record("FRE")
	for q in state.my_list:
		if Captaincy.role_of(rec, str(q["id"])) == "captain":
			cap = q
	for pair in [["captain_group_flat", cap, "_captain"], ["training_extra_session", {}, "_one"], ["media_papers_again", p, "_two"], ["selection_talk_dropped", p, "_three"], ["health_pulled_up_sore", p, "_risk"]]:
		state.media_conference = {}
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
