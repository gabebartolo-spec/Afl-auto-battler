extends SceneTree
## Visual review tool for the recurring journalists (RPG-002): one press
## question from each of the five, on the Hub on a phone (390x844), with the
## stage skipped so the question shows:
##   godot --path . --script tools/visual/capture_journalists.gd -- --out /tmp/press
## Writes <out>_sheet.png: Muckraker (holding you to a claim), Sycophant, Stats
## Geek, Bogan, Philosopher, left to right.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/press"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var MC = load("res://scripts/sim/MediaConference.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("vignettes", false)
	state.start_season("GEE", db.club_list("GEE"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var y := int(state.season_year)
	var said := {"said|big_win": {"year": y, "option": 1, "opp": "Carlton"}}
	var star_name := str(db.player_display_name(state.my_list[0]))
	var asks := [
		[{"result": {"home": "GEE", "away": "ESS", "score": [44, 101]}, "opponent_name": "Essendon"}, said],
		[{"result": {"home": "GEE", "away": "CAR", "score": [120, 61]}, "opponent_name": "Carlton"}, {}],
		[{"result": {"home": "GEE", "away": "SYD", "score": [80, 83], "team": [{"inside50": 54}, {"inside50": 41}]},
				"opponent_name": "Sydney"}, {}],
		[{"result": {"home": "GEE", "away": "HAW", "score": [95, 70]}, "opponent_name": "Hawthorn",
				"star": {"name": star_name, "line": "kicked 7 goals"}}, {}],
		[{"result": {"home": "GEE", "away": "MEL", "score": [90, 74]}, "opponent_name": "Melbourne", "young": 6}, {}],
	]
	var shots := []
	for ask in asks:
		var ctx: Dictionary = ask[0]
		ctx["club"] = "GEE"
		ctx["round"] = 12
		ctx["year"] = y
		state.media_conference = MC.pick(ctx, ask[1])
		var hub = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		shots.append(await _shot())
		hub.queue_free()
		await process_frame
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out + "_sheet.png")
	quit(0)
