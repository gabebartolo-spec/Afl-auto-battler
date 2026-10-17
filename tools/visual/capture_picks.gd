extends SceneTree
## Review captures for "where the pick came from", the pick-order line and the
## untouchable mark, on a phone (390x844), dark. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_picks.gd
## Environment: CAP_DIR (folder for the pngs, default "."), CAP_CLUB (default "MEL").
## A fresh career fast-forwarded to the off-season, with two pick trades made
## so every kind of line shows: your own pick, one bought from a rival for a
## player, one sent to a rival, one traded on. Never touches a real save.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n := 8) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames()
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)


func _scroll_to(scene: Node, target: Control, above := 70) -> void:
	var boxes := scene.find_children("*", "ScrollContainer", true, false)
	for b in boxes:
		var box := b as ScrollContainer
		if box.is_visible_in_tree() and box.is_ancestor_of(target):
			box.scroll_vertical = maxi(0, int(target.global_position.y - box.global_position.y) - above + box.scroll_vertical)
	await _frames()


func _run() -> void:
	var dir := OS.get_environment("CAP_DIR") if OS.get_environment("CAP_DIR") != "" else "."
	var club := OS.get_environment("CAP_CLUB") if OS.get_environment("CAP_CLUB") != "" else "MEL"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_picks.save"
	state.settings_path = "user://capture_picks.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	state.set_setting("seen_weekly_loop_intro", true)
	UK.apply_appearance("dark")
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# 1. The hub in the last rounds: where the first pick would fall today.
	var season = state.season
	# Played for real, so the ladder and the form line are true (a faked round leaves
	# "Form: Steady, no games yet" at round 22).
	while season.round_index < season.fixture.size() - 3:
		state.advance()
	state.backing_talk = {}
	state.media_conference = {}   # the press question and sit-down is not what this capture shows
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _frames(10)
	print("pick line: ", state.pick_order_line())
	var line: Control = hub.find_child("DraftPickLine", true, false)
	if line != null:
		await _scroll_to(hub, line, 160)
	await _shot(dir + "/picks_hub_line.png")
	hub.queue_free()
	await _frames()

	# 2. The off-season: trades that leave a story on the picks.
	while not season.is_regular_done():
		state.advance()
	state.open_offseason()
	state.pick_owner = {}
	state.pick_got = {}
	state.trade_requests = {}
	var year: int = state.season_year
	var mine: Array = state.my_list.duplicate()
	mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var rival := "CAR" if club != "CAR" else "ESS"
	var other := "GEE" if club != "GEE" and rival != "GEE" else "SYD"
	# A first-round pick bought from the rival for a depth player.
	var paid: Dictionary = mine[3]
	state._execute_trade(rival, club, [state.pick_asset(state.pick_id(year, 1, rival))], [paid])
	# Your second-round pick sent to another club for one of its fringe players.
	var their: Array = (state.season.lists[other] as Array).duplicate()
	their.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	state._execute_trade(club, other, [state.pick_asset(state.pick_id(year, 2, club))], [their[1]])
	# Next year's first from a third club, for two players.
	var third := "RIC" if club != "RIC" and rival != "RIC" and other != "RIC" else "WCE"
	state._execute_trade(third, club, [state.pick_asset(state.pick_id(year + 1, 1, third))], [mine[5], mine[6]])
	print("story 1: ", state.pick_story(year, 1, rival))
	print("story 2: ", state.pick_story(year, 2, club))
	print("story 3: ", state.pick_story(year + 1, 1, third))

	# The trade tab: your picks with their lines.
	var off = load("res://scenes/OffseasonScene.tscn").instantiate()
	off.set("_tab", "trade")
	off.set("_trade_side", "mine")
	root.add_child(off)
	off.call("_build")
	await _frames(10)
	var story: Control = off.find_child("PickStory_*", true, false)
	if story != null:
		await _scroll_to(off, story, 190)
	await _shot(dir + "/picks_trade_mine.png")
	off.set("_trade_club", other)
	off.set("_trade_side", "theirs")
	off.call("_build")
	await _frames(10)
	story = off.find_child("PickStory_*", true, false)
	if story != null:
		await _scroll_to(off, story, 190)
	await _shot(dir + "/picks_trade_theirs.png")
	off.queue_free()
	await _frames()

	# 3. The draft: the order tab and Your picks.
	state.compensation = []
	if state.begin_intake_draft():
		var draft = state.draft
		var ui = load("res://scenes/DraftScene.tscn").instantiate()
		root.add_child(ui)
		await _frames(10)
		var done = ui.find_child("MeetingDone", true, false)
		if done != null:
			done.emit_signal("pressed")
			await _frames(6)
		ui.call("_select_tab", "order")
		await _frames(8)
		var via: Control = ui.find_child("ViaPick", true, false)
		if via != null:
			await _scroll_to(ui, via, 150)
		await _shot(dir + "/picks_draft_order.png")
		ui.call("_select_tab", "squad")
		await _frames(8)
		await _shot(dir + "/picks_draft_mine.png")
		ui.queue_free()
		await _frames()

	# 4. My list: the untouchable mark, and the toggle on his profile.
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.start_season(club, db.club_list(club))
	var star: Dictionary = state.my_list[0]
	var lst: Array = state.my_list.duplicate()
	lst.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	state.set_untouchable(str(lst[1]["id"]), true)
	var ls = load("res://scenes/ListScene.tscn").instantiate()
	ls.set("_pane", "list")
	root.add_child(ls)
	await _frames(10)
	var mark: Control = ls.find_child("RowUntouchable", true, false)
	if mark != null:
		await _scroll_to(ls, mark, 200)
	await _shot(dir + "/picks_list_mark.png")
	ls.call("_open_profile", str(lst[0]["id"]))
	await _frames(10)
	var toggle = ls.find_child("Untouchable", true, false)
	await _shot(dir + "/picks_profile_toggle.png")
	print("toggle button: ", toggle)
	quit()
