extends SceneTree
## Season stats > Player stats, for the director's look. Needs a real
## renderer:
##   godot --path . --script tools/visual/capture_stats_players.gd -- --out /tmp/sp [--size 1280x720]
##       [--rounds 8] [--group disposals] [--pergame] [--filters] [--sort accuracy] [--player]
## --filters: the filter row open with a club filter set. --player: his
## season and career sheet open. Writes <out>_sheet.png.

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/sp"
	var rounds := 8
	var group := "disposals"
	var per_game := false
	var filters := false
	var sort := ""
	var player := false
	var picker := false
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
			"--rounds": rounds = int(v)
			"--group": group = v
			"--pergame": per_game = true
			"--filters": filters = true
			"--sort": sort = v
			"--player": player = true
			"--picker": picker = true
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.replay_seed = 2031
	state.reset()
	state.set_setting("seen_season_stats_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("COL", db.club_list("COL"))
	for r in range(rounds):
		state.advance()
	# Loaded, not named: a --script tool compiles before the autoloads exist.
	var sp = load("res://scripts/ui/stats/StatsPlayers.gd")
	sp.reset_view()
	sp.pick_group(group)
	if per_game:
		sp.set("_per_game", true)
	if sort != "":
		sp.sort_by(sort)
	if filters:
		sp.set("_show_filters", true)
		sp.set_filter("club", "COL")
	load("res://scripts/ui/StatsHubScene.gd").current = "players"
	var ui: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(ui)
	for i in range(8):
		await process_frame
	if player:
		var rows: Array = ui.find_children("PlayerRow_*", "Button", true, false)
		if not rows.is_empty():
			(rows[0] as Button).emit_signal("pressed")
	if picker:
		# The stat list open: a sheet (a Button) or the old pop-up menu (an OptionButton).
		var pick = ui.find_child("StatPick", true, false)
		if pick is OptionButton:
			(pick as OptionButton).show_popup()
		elif pick != null:
			(pick as Button).emit_signal("pressed")
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
