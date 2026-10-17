extends SceneTree
## Visual review tool for comebacks told better (ComebackTelling). capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_comeback \
##       -f args="--club FRE --want win --size 390x844"
## Looks through first-match career seeds of --club for one whose last quarter turned it
## (--want win: you came from behind; --want loss: you let a lead go), then writes
## <out>_break.png (the three-quarter-time break, its line on top), <out>_full.png (the
## result, the turn first in How it went) and <out>_hub.png (the hub's last-result card). Never touches a real save.
##   --size WxH   window size (default 390x844)    --club CODE (default FRE)
##   --want win|loss    --max N   seeds to look through (default 120)

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _start(state, db, club: String, seed: int) -> bool:
	state.autosave_enabled = false
	state.save_path = "user://capture_comeback.save"
	state.settings_path = "user://capture_comeback.cfg"
	state.reset()
	state.career_seed = seed
	state.replay_seed = seed
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	return state.prepare_interactive_match()


func _run() -> void:
	var out := "comeback"
	var club := "FRE"
	var want := "win"
	var max_seeds := 120
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
			"--want":
				want = str(a[i + 1])
			"--max":
				max_seeds = int(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	var CT = load("res://scripts/core/ComebackTelling.gd")
	var found := -1
	for seed in range(1, max_seeds + 1):
		if not _start(state, db, club, seed):
			continue
		var sim = state.pending_sim
		var me := int(sim.moment_side)
		for q in range(4):
			sim.run_quarter()
		var res: Dictionary = sim.result()
		var line: String = CT.turn_line(res, me)
		var won: bool = int(res["score"][me]) > int(res["score"][1 - me])
		if line != "" and ((want == "win") == won):
			found = seed
			print("seed ", seed, " ", club, " ", line, " score ", res["score"])
			break
	if found < 0:
		push_error("no %s seed found" % want)
		quit(1)
		return
	# The three-quarter-time break.
	_start(state, db, club, found)
	for q in range(3):
		state.pending_sim.run_quarter()
	UK.apply_appearance("dark")
	_size_window()
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(12)
	print("break line: ", CT.break_line(state.pending_sim.result(), int(state.pending_sim.moment_side)))
	_save(out + "_break.png")
	scene.queue_free()
	await _frames(4)
	# The result.
	_start(state, db, club, found)
	var sim2 = state.pending_sim
	for q in range(4):
		sim2.run_quarter()
	var res2: Dictionary = sim2.result()
	res2["home"] = state.pending_match["home"]
	res2["away"] = state.pending_match["away"]
	res2["label"] = state.pending_match["label"]
	state.finish_interactive_match(res2)
	state.pending_sim = null
	state.pending_match = {}
	state.review_requested = true
	var full = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(full)
	await _frames(20)
	_save(out + "_full.png")
	full.queue_free()
	await _frames(4)
	# The hub's last-result card.
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _frames(10)
	hub._show_results(state.last_results)
	await _frames(20)
	_save(out + "_hub.png")
	quit(0)


func _size_window() -> void:
	if _w >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
