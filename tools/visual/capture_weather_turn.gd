extends SceneTree
## Visual review tool for the weather turning at a break (TODO row 160). Needs a
## real renderer:
##   godot --path . --script tools/visual/capture_weather_turn.gd -- --out <dir>/wx [--size 390x844] [--club FRE]
## Finds the first career seed from 2026 whose first match turns at a break,
## then writes:
##   <out>_1_forecast.png  before the first ball-up: the forecast and its odds
##   <out>_2_turn.png      the break it turns at: the announcement
##   <out>_3_plan.png      that break's Game plan sheet, sized for the new weather
## and prints the match, its weather, the odds and the turn. Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "weather_turn"
	var club := "FRE"
	var want := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--club":
				club = str(a[i + 1])
			"--to":
				want = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_weather_turn.save"
	state.settings_path = "user://capture_weather_turn.cfg"
	UK.apply_appearance("dark")
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	var sim = null
	for tries in range(400):
		state.reset()
		state.career_seed = 2026 + tries
		state.replay_seed = 2026 + tries
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		if not state.prepare_interactive_match():
			continue
		var s = state.pending_sim
		if not s.weather_turn.is_empty() and (want == "" or str(s.weather_turn["to"]) == want):
			sim = s
			break
	if sim == null:
		push_error("no match turns in 400 seeds")
		quit(1)
		return
	var after := int(sim.weather_turn["after"])
	print("match: %s v %s seed %d weather %s odds %.2f turns at break %d to %s" % [sim.squads[0].code,
			sim.squads[1].code, state.career_seed, sim.weather, sim.weather_odds, after, sim.weather_turn["to"]])
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(16)
	await _shot(out, "1_forecast")
	root.remove_child(scene)
	scene.queue_free()
	await _frames(6)
	for i in range(after):
		sim.run_quarter()
	print("at the break: weather now %s, ahead %s, announced %s" % [sim.weather, sim.weather_ahead(), str(sim.weather_turn_now())])
	scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(16)
	# The quarters were run off-screen: the scoreboard shows the sim's score, as
	# it would after the oval had played them.
	var res: Dictionary = sim.result()
	scene.set("_shown_goals", (res["goals"] as Array).duplicate())
	scene.set("_shown_behinds", (res["behinds"] as Array).duplicate())
	scene.call("_paint_scoreboard")
	await _frames(4)
	await _shot(out, "2_turn")
	var b: Node = scene.find_child("CallRow_plan", true, false)
	if b is Button:
		(b as Button).emit_signal("pressed")
		await _frames(8)
		# The plan the new weather favours (MatchSim.WEATHER_PLAN), so its gain
		# line shows the sizing for the quarters left.
		var fav := {"wet": "contest", "windy": "controlled", "hot": "attacking", "perfect": "attacking"}
		var pick: Node = scene.find_child("PlanPicker_" + str(fav.get(sim.weather_ahead(), "controlled")), true, false)
		if pick is Button:
			(pick as Button).emit_signal("pressed")
			await _frames(8)
		await _shot(out, "3_plan")
	else:
		print("MISSING CallRow_plan")
	quit()


func _shot(out: String, shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		print("no renderer: ", shot)
		return
	img.convert(Image.FORMAT_RGBA8)
	var path := "%s_%s.png" % [out, shot]
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
