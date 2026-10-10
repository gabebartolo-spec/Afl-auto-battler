extends SceneTree
## Team rating and category (TeamRating), for the director's look, in the four
## places it shows. Needs a real renderer:
##   godot --path . --script tools/visual/capture_team_rating.gd -- --out /tmp/tr [--size 390x844]
## Writes <out>_ladder.png (Season stats > Ladder), <out>_side.png (a club
## tapped on the ladder), <out>_hub.png (your club's line and this week's
## opponent, scrolled to the opponent), <out>_trade.png (the off-season Trade
## tab) and <out>_draft.png (the draft order). A fresh Collingwood career,
## eight rounds in; the trade and draft shots skip to the off-season.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/tr"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_tr.save"
	state.settings_path = "user://capture_tr.cfg"
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	for k in ["seen_season_stats_intro", "seen_weekly_loop_intro", "seen_training_intro"]:
		state.set_setting(k, true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("COL", db.club_list("COL"))
	for r in range(8):
		state.advance()
	# The ladder, and a club tapped on it.
	load("res://scripts/ui/stats/StatsLadder.gd").reset()
	load("res://scripts/ui/StatsHubScene.gd").current = "ladder"
	var stats: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(stats)
	await _frames(10)
	_shot(out + "_ladder.png")
	var row: Button = stats.find_child("Club_" + str(state.my_club), true, false)
	if row != null:
		row.emit_signal("pressed")
		await _frames(10)
		_shot(out + "_side.png")
	stats.queue_free()
	await _frames(2)
	# The hub: your club's line, then this week's opponent.
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _frames(12)
	_shot(out + "_hub.png")
	var opp: Control = hub.find_child("OppTeamOutlook", true, false)
	if opp != null:
		var sc: ScrollContainer = _scroll_of(opp)
		if sc != null:
			sc.scroll_vertical = int(opp.global_position.y - sc.global_position.y + sc.scroll_vertical - H / 2)
			await _frames(6)
			_shot(out + "_hub_opponent.png")
	hub.queue_free()
	await _frames(2)
	# The off-season: Trade, then the draft order.
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	var off: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	off.set("_tab", "trade")
	root.add_child(off)
	off.call("_build")
	await _frames(10)
	_shot(out + "_trade.png")
	off.set("_choosing_club", true)
	off.call("_build")
	await _frames(8)
	_shot(out + "_trade_clubs.png")
	off.queue_free()
	await _frames(2)
	if state.begin_intake_draft():
		var draft: Control = load("res://scenes/DraftScene.tscn").instantiate()
		root.add_child(draft)
		await _frames(10)
		var done: Button = draft.find_child("MeetingDone", true, false)
		if done != null:
			done.emit_signal("pressed")
			await _frames(6)
		var order: Button = draft.find_child("Tab_order", true, false)
		if order == null:
			order = draft.find_child("SideTab_order", true, false)
		if order != null:
			order.emit_signal("pressed")
			await _frames(8)
		_shot(out + "_draft.png")
	quit(0)


func _scroll_of(n: Node) -> ScrollContainer:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)
