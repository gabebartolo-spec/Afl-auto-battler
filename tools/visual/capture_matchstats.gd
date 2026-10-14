extends SceneTree
## The match stats sheets as a PC and a phone show them (readability: a figure sits next to its name).
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_matchstats.gd -- --out /tmp/ms --size 1280x720 [--club ADE --vs MEL]
## Writes <out>_break.png (the break's Match stats sheet) and <out>_fulltime.png (full time, Stats tab),
## and prints each sheet's scroll room and what it holds. Seeded; never touches a real save.

var _w := 390
var _h := 844
var _vp: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "ms"
	var club := "ADE"
	var vs := "MEL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--vs": vs = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_matchstats.save"
	state.settings_path = "user://capture_matchstats.cfg"
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	# The scene is drawn in its own viewport of exactly the size asked for, whatever
	# this machine's screen and scaling.
	_vp = SubViewport.new()
	_vp.size = Vector2i(_w, _h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	await _frames(4)
	var tries := 0
	while true:
		state.reset()
		state.career_seed = 2026 + tries
		state.replay_seed = 2026 + tries
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		state.prepare_interactive_match()
		var s0 = state.pending_sim
		var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
		if them == vs or tries > 80:
			break
		tries += 1
	var sim = state.pending_sim
	var tag_me: Dictionary = (sim.tactics[sim.moment_side] as Dictionary).duplicate()
	tag_me["gameplan"] = "defensive"
	sim.set_tactics(sim.moment_side, tag_me)
	sim.run_quarter()
	sim.run_quarter()
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	_vp.add_child(scene)
	await _frames(16)
	scene.call("_show_break_stats")
	await _frames(14)
	var cols = scene.find_child("StatsColumns", true, false)
	print("VIEW ", _vp.get_visible_rect().size, " columns ", (cols as Control).size if cols != null else "none",
			" boxscore ", (scene.find_child("BreakBoxScore", true, false) as Control).size)
	_shot(scene, out + "_break.png", "BreakStatsSheet")
	scene.call("_close_report")
	await _frames(4)
	sim.run_quarter()
	sim.run_quarter()
	scene.set("_res", sim.result())
	scene.set("_finished", true)
	scene.call("_show_fulltime")
	await _frames(14)
	scene.set("_ft_tab", "stats")
	scene.call("_render_ft")
	await _frames(14)
	_shot(scene, out + "_fulltime.png", "FullTime")
	quit()


func _shot(scene: Node, path: String, sheet: String) -> void:
	var o: Node = scene.find_child(sheet, true, false)
	if o != null:
		for sc in o.find_children("*", "ScrollContainer", true, false):
			for ch in sc.get_children():
				if ch is Control and not (ch is ScrollBar):
					print("SCROLL ", sheet, " room ", (sc as Control).size.y, " holds ", (ch as Control).size.y)
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
