extends SceneTree
## What the coach sees of a new club building its list (the feature switch
## "expansion_package"), for the director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_expansion.gd -- --out /tmp/exp [--club FRE] [--size 1280x720]
## Writes:
##   <out>_setup.png   the new-career screen with the Canberra choice
##   <out>_setup_info.png   the same with the choice's "?" note open
##   <out>_card.png    the card: a new club has approached your player
##   <out>_order.png   the draft order before the new club's first season
##   <out>_news.png    the league news after the new club joins

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames(8)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if W >= 760 and img.get_width() != W:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote ", path)


func _run_draft(d) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c: Dictionary = d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _run() -> void:
	var out := "/tmp/exp"
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
	var router = root.get_node("Router")
	var features = load("res://scripts/core/Features.gd")
	var build = load("res://scripts/state/ExpansionBuild.gd")
	var draft_class = load("res://scripts/sim/Draft.gd")
	features.set_on("expansion_package", true)
	state.autosave_enabled = false
	state.save_path = "user://capture_expansion.save"
	state.settings_path = "user://capture_expansion_settings.cfg"
	state.show_real_names = false
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("tutorials", false)
	if W >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(W, H))
		await _frames(10)
		var factor := float(W) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(W * factor), int(H * factor)))
			await _frames(10)
	else:
		DisplayServer.window_set_size(Vector2i(W, H))
		root.size = Vector2i(W, H)
	await _frames(3)

	# 1. The new-career screen.
	router.go("main")
	await _frames(8)
	var main: Node = root.get_tree().current_scene
	main._on_new_career()
	await _frames(6)
	await _shot(out + "_setup.png")
	var info: Node = main.find_child("CanberraInfo", true, false)
	if info != null:
		info.emit_signal("pressed")
	await _shot(out + "_setup_info.png")

	# A League Draft career, every club drafting as a rival does.
	state.reset()
	state.career_seed = 7
	state.replay_seed = 7
	var pool: Array = db.all_players_sorted() + db.all_draftees_sorted()
	pool.sort_custom(func(x, y): return x["overall"] > y["overall"])
	state.draft = draft_class.new(pool, db.active_clubs(state.season_year).duplicate(), 7)
	state.draft.start_for_user(club)
	_run_draft(state.draft)
	state.start_season(club, state.draft.list())

	# 2. The card. Late in the season the new club makes its approaches; yours
	# is your best out-of-contract player.
	state.season.round_index = 20
	state._next_week_event()
	var has_card := false
	for c in state.week_events:
		if str(c.get("tid", "")) == "contracts_new_club_approach":
			has_card = true
			state.week_events = [c]
	print("card dealt ", has_card)
	state.media_conference = {}
	router.go("hub")
	await _frames(8)
	var card: Control = root.get_tree().current_scene.find_child("WeekEvent", true, false)
	var sc: Node = card.get_parent() if card != null else null
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc != null:
		(sc as ScrollContainer).scroll_vertical = 0
		await _frames(3)
		(sc as ScrollContainer).scroll_vertical = int(card.global_position.y - (sc as Control).global_position.y) - 24
		await _frames(4)
	await _shot(out + "_card.png")
	if has_card:
		state.resolve_card(0, 1)

	# 3. The draft before the new club's first season, on the Order tab.
	state.season.round_index = state.season.fixture.size()
	state.begin_intake_draft()
	router.go("draft")
	await _frames(10)
	var scene: Node = root.get_tree().current_scene
	var meeting: Node = scene.find_child("MeetingDone", true, false)
	if meeting != null:
		meeting.emit_signal("pressed")
		await _frames(4)
	if scene.has_method("_select_tab"):
		scene._select_tab("order")
	await _frames(6)
	await _shot(out + "_order.png")

	# 4. The news once the club has joined.
	_run_draft(state.draft)
	state.finish_intake_draft()
	print("year ", state.season_year, " list ", (state.season.lists["TAS"] as Array).size(), " build ", build.entry_line(state, "TAS"))
	router.go("hub")
	await _frames(8)
	var hub: Node = root.get_tree().current_scene
	if hub.has_method("_show_news"):
		hub._show_news()
	await _shot(out + "_news.png")
	features.clear("expansion_package")
	quit(0)
