extends SceneTree
## Draft night's pick trading (director 2026-10-25) for the look gate: the board
## on your pick with Trade picks beside Pick for me and Pass; the trade sheet
## with a club's pick and yours on the table and its answer; the board strip
## after a deal, with the trade row among the picks. Needs a real renderer:
##   godot --path . --windowed --script tools/visual/capture_draft_trade.gd -- --out /tmp/trade [--size 390x844] [--club FRE] [--seed 2027]
## Writes <out>_board.png, <out>_sheet.png, <out>_offers.png (when a rival made
## one), <out>_strip.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	var out := "/tmp/trade"
	var club := "FRE"
	var seed := 2027
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
		if str(a[i]) == "--club" and i + 1 < a.size():
			club = str(a[i + 1])
		if str(a[i]) == "--size" and i + 1 < a.size():
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
		if str(a[i]) == "--seed" and i + 1 < a.size():
			seed = int(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.replay_seed = seed
	state.reset()
	state.start_season(club, db.club_list(club))
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	if not state.begin_intake_draft():
		print("no draft")
		quit(1)
		return
	var draft = state.draft
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var base: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, base)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	for i in range(6):
		await process_frame
	var done: Button = ui.find_child("MeetingDone", true, false)
	if done != null:
		done.emit_signal("pressed")
	var guard := 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	ui.call("_finish_night")
	await _wait(0.5)
	var trade_btn: Button = ui.find_child("TradePicks", true, false)
	print("trade button: ", trade_btn.text if trade_btn else "missing")
	_shot(out + "_board.png")
	# The sheet: offers first if any came in.
	ui.call("_on_trade_picks")
	await _wait(0.4)
	if not state.open_trade_offers().is_empty():
		_shot(out + "_offers.png")
	# Their picks and yours on the table: the latest rival in this round for
	# the clearest gap; the club answers in words.
	var index: int = draft.pick_index
	var rnd := int(draft.pick_rounds[index])
	var year: int = state.season_year
	var me: String = state.my_club
	var my_pick: String = state.pick_id(year, rnd, str(draft.pick_origin[index]))
	var rivals := []
	for i in range(index + 1, draft.pick_sequence.size()):
		if int(draft.pick_rounds[i]) == rnd and str(draft.pick_sequence[i]) != me:
			rivals.push_front([i, str(draft.pick_sequence[i])])
	var sheet = ui.find_child("TradeSheet", true, false).get_meta("sheet")
	var deal := {}
	for lr in rivals:
		var rival := str(lr[1])
		var their_pick: String = state.pick_id(year, rnd, str(draft.pick_origin[int(lr[0])]))
		for mine_ids in [[my_pick]]:
			if bool(state.evaluate_trade(rival, mine_ids, [their_pick])["ok"]):
				deal = {"club": rival, "mine": mine_ids, "theirs": [their_pick]}
			else:
				for pk in state.club_picks(rival):
					if str(pk["id"]) != their_pick and bool(state.evaluate_trade(rival, mine_ids, [their_pick, str(pk["id"])])["ok"]):
						deal = {"club": rival, "mine": mine_ids, "theirs": [their_pick, str(pk["id"])]}
						break
		if not deal.is_empty():
			break
	if deal.is_empty() and not rivals.is_empty():
		deal = {"club": str(rivals[0][1]), "mine": [my_pick],
				"theirs": [state.pick_id(year, rnd, str(draft.pick_origin[int(rivals[0][0])]))]}
	sheet._club = str(deal["club"])
	sheet._mine = (deal["mine"] as Array).duplicate()
	sheet._theirs = (deal["theirs"] as Array).duplicate()
	sheet._side = "mine"
	sheet._build()
	await _wait(0.5)
	var verdict: Label = ui.find_child("TradeVerdict", true, false)
	print("verdict: ", verdict.text if verdict else "-")
	_shot(out + "_sheet.png")
	# The deal, then the board runs on to your next pick: the strip shows it.
	var go: Button = ui.find_child("MakeTrade", true, false)
	if go != null and not go.disabled:
		go.emit_signal("pressed")
		await _wait(0.3)
	var close: Button = ui.find_child("TradeSheetClose", true, false)
	if close != null:
		close.emit_signal("pressed")
	# The board has just started replaying from the deal: the trade row is the
	# newest thing on the strip.
	await _wait(0.25)
	print("night trades: ", draft.night_trades.size(), " recent rows: ",
			ui.find_children("RecentTrade_*", "Control", true, false).size())
	_shot(out + "_strip.png")
	quit(0)
