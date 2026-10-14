extends SceneTree
## Visual review tool for the break from quarter time on (one line a call).
## Needs a real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_break_one_line \
##       -f args="--size 390x844 --club FRE --vs MEL"
##   --size WxH   window (default 390x844; 760 wide and up is the PC sheet)
##   --quarters 2,3,4  the as-built set: at each break named, <out>_qN_1_break.png and <out>_qN_2_<call>.png
##   --played  play the first quarter on the oval from Ball it up, then <out>_played_quarter_time.png, and
##             print what the scoreboard behind the break reads against the sim's score
##   --club CODE  your club (default FRE)   --vs CODE  the opponent ("any" = the first drawn that is not COL)
## Plays a first half with Defensive press, then writes, at half time:
##   phone: <out>_1_break.png, _2_tag.png (the Tag sheet, a tag picked), _3_who.png (who tags),
##          _4_changed.png (back on the break, the Tag row marked), _5_best.png (Best so far)
##   PC:    <out>_1_break.png (Game plan beside the list), _2_tag.png (a tag picked, the cards in the pane),
##          _3_forward.png (Defensive forward), _4_through.png (Play through)
## and prints FIT lines: each scrolling list's room and what it holds. Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "break_one_line"
	var club := "FRE"
	var vs := "MEL"
	var quarters: Array = []
	var played := false
	var open_key := ""
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
			"--vs":
				vs = "" if str(a[i + 1]) == "any" else str(a[i + 1])
			"--open":
				open_key = str(a[i + 1])
			"--played":
				played = true
			"--quarters":
				# The as-built set: for each break named (2 = quarter time, 3 = half
				# time, 4 = three-quarter time) the break, then one call opened.
				for q in str(a[i + 1]).split(","):
					quarters.append(int(q))
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_break_one_line.save"
	state.settings_path = "user://capture_break_one_line.cfg"
	UK.apply_appearance("dark")
	var pc := _w >= 760
	if pc:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(_w, _h))
		await _frames(10)
		var factor := float(_w) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(_w * factor), int(_h * factor)))
			await _frames(10)
	else:
		root.size = Vector2i(_w, _h)
		DisplayServer.window_set_size(Vector2i(_w, _h))
	print("visible ", root.get_visible_rect().size)
	if played:
		await _played(state, db, club, vs, out)
		quit()
		return
	var as_built := not quarters.is_empty()
	if not as_built:
		quarters = [3]
	# Which call is opened at each break of the as-built set.
	var opened := {2: "plan", 3: "tag", 4: "loose"}
	for q in quarters:
		var tries := 0
		while true:
			state.reset()
			state.career_seed = 2026 + tries
			state.replay_seed = 2026 + tries
			state.set_setting("seen_training_intro", true)
			state.start_season(club, db.club_list(club))
			if not state.prepare_interactive_match():
				push_error("no match to prepare")
				quit(1)
				return
			var s0 = state.pending_sim
			var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
			if (vs == "" and them != "COL") or them == vs or tries > 80:
				break
			tries += 1
		var sim = state.pending_sim
		var me := int(sim.moment_side)
		print("match: ", sim.squads[0].code, " v ", sim.squads[1].code, " seed ", state.career_seed, " break before quarter ", q)
		var t: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
		t["gameplan"] = "defensive"
		sim.set_tactics(me, t)
		for i in range(int(q) - 1):
			sim.run_quarter()
		var scene = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(scene)
		await _frames(16)
		var pre := ("q%d_" % int(q)) if as_built else ""
		await _shot(scene, out, pre + "1_break")
		var key := str(opened.get(int(q), "tag")) if as_built else "tag"
		if open_key != "":
			key = open_key
		_press(scene, "CallRow_" + key)
		await _frames(8)
		if key == "tag":
			var tp: Node = scene.find_child("TagPicker", true, false)
			if tp != null:
				for b in tp.find_children("TagPickerGrid_*", "Button", true, false):
					if str(b.name) != "TagPickerGrid_":
						(b as Button).emit_signal("pressed")
						break
			await _frames(8)
		await _shot(scene, out, pre + ("2_" + key if as_built else "2_tag"))
		if as_built:
			root.remove_child(scene)
			scene.queue_free()
			await _frames(6)
			continue
		if pc:
			for step in [["CallRow_minder", "3_forward"], ["CallRow_pt", "4_through"]]:
				_press(scene, str(step[0]))
				await _frames(8)
				await _shot(scene, out, str(step[1]))
		else:
			_press(scene, "WhoTagsChange")
			await _frames(8)
			await _shot(scene, out, "3_who")
			scene.call("handle_back")
			await _frames(6)
			scene.call("handle_back")
			await _frames(8)
			await _shot(scene, out, "4_changed")
			_press(scene, "BestSoFarOpen")
			await _frames(8)
			await _shot(scene, out, "5_best")
	quit()


## A match played the way a player plays it: Ball it up, the first quarter runs
## on the oval, and the quarter-time break opens over the live scoreboard.
## Prints what the scoreboard behind the break reads against the sim's score.
func _played(state, db, club: String, vs: String, out: String) -> void:
	var tries := 0
	while true:
		state.reset()
		state.career_seed = 2026 + tries
		state.replay_seed = 2026 + tries
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		if not state.prepare_interactive_match():
			push_error("no match to prepare")
			return
		var s0 = state.pending_sim
		var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
		if (vs == "" and them != "COL") or them == vs or tries > 80:
			break
		tries += 1
	var sim = state.pending_sim
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(16)
	_press(scene, "StartQuarter")
	await _frames(8)
	var pitch = scene.get("_pitch")
	var guard := 0
	while scene.find_child("CoachBox", true, false) == null and guard < 6000:
		if pitch.playing:
			pitch._process(0.25)
		await process_frame
		guard += 1
		var card: Node = scene.find_child("MomentCard", true, false)
		if card != null:
			var pick: Node = card.find_child("Moment_0", true, false)
			if pick is Button:
				(pick as Button).emit_signal("pressed")
			await _frames(6)
	await _frames(12)
	var goals: Array = sim.result().get("goals", [0, 0])
	var behinds: Array = sim.result().get("behinds", [0, 0])
	var band: Node = scene.find_child("BreakScore", true, false)
	print("PLAYED break open: ", scene.find_child("CoachBox", true, false) != null, " after ", guard, " steps")
	print("PLAYED sim score: ", goals, " ", behinds)
	print("PLAYED scoreboard: home '", (scene.get("_score_home") as Label).text, "' away '", (scene.get("_score_away") as Label).text,
			"' clock '", (scene.get("_clock") as Label).text, "' shown goals ", scene.get("_shown_goals"), " behinds ", scene.get("_shown_behinds"))
	print("PLAYED break says: ", (band as Label).text if band is Label else "-")
	await _shot(scene, out, "played_quarter_time")


func _press(scene: Node, node_name: String) -> void:
	var b: Node = scene.find_child(node_name, true, false)
	if b is Button and not (b as Button).disabled:
		(b as Button).emit_signal("pressed")
	else:
		print("MISSING ", node_name)


## Save the screen and say whether each scrolling list on the break fits its room.
func _shot(scene: Node, out: String, shot: String) -> void:
	for o in scene.get_children():
		if not (o is Control) or not (str(o.name) == "CoachBox" or str(o.name).begins_with("CallSheet_")):
			continue
		for sc in o.find_children("*", "ScrollContainer", true, false):
			if (sc as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				continue
			for ch in sc.get_children():
				if ch is Control and not (ch is ScrollBar):
					print("FIT ", shot, " ", o.name, " room ", (sc as Control).size.y, " holds ", (ch as Control).size.y)
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
