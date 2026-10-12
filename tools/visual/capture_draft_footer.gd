extends SceneTree
## The League Draft's footer once the draft is over: a list short at a position,
## a list the rules refuse (over the cap), and a list with every position covered.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_draft_footer.gd -- --out /tmp/draft_footer [--size 390x844]
## Writes <out>_short.png, <out>_invalid.png and <out>_ready.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/draft_footer"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
		if str(a[i]) == "--size" and i + 1 < a.size():
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	for variant in ["short", "invalid", "ready"]:
		var ui: Control = await _finished_draft(variant == "ready")
		if variant == "invalid":
			state.draft.budget = state.draft.spent() - 1000
			ui.call("_refresh")
			for i in range(6):
				await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("%s_%s.png" % [out, variant])
		print("wrote %s_%s.png: %s" % [out, variant, (ui.find_child("UpcomingPicks", true, false) as Label).text.replace("\n", " / ")])
		ui.queue_free()
		await process_frame
	quit(0)


## A League Draft for COL played to the end, cheapest players first. When
## `cover`, a position still short is filled before any other; otherwise no
## defender is taken.
func _finished_draft(cover: bool) -> Control:
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.reset()
	state.replay_seed = 4242
	state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted(),
			db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	for i in range(6):
		await process_frame
	var d = state.draft
	var guard := 0
	while not d.is_finished() and guard < 80:
		guard += 1
		var want := ""
		if cover:
			var status: Dictionary = d.position_status()
			for role in ["RUCK", "DEF", "MID", "FWD"]:
				if int((status[role] as Dictionary)["short"]) > 0:
					want = role
					break
		var board: Array = d.board(want, "", "", "overall", true)
		board = board.filter(func(p): return d.can_pick_player(p))
		if not cover:
			board = board.filter(func(p): return str(p["role"]) != "DEF" and str(p.get("role2", "")) != "DEF")
		if board.is_empty():
			break
		board.sort_custom(func(x, y): return int(x["value"]) < int(y["value"]))
		ui.call("_on_pick", board[0])
	ui.call("_refresh")
	for i in range(8):
		await process_frame
	return ui
