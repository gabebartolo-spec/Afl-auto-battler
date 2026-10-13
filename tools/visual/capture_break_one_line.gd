extends SceneTree
## Visual review tool for the break from quarter time on (one line a call).
## Needs a real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_break_one_line \
##       -f args="--size 390x844 --club FRE --vs MEL"
##   --size WxH   window (default 390x844; 760 wide and up is the PC sheet)
##   --club CODE  your club (default FRE)   --vs CODE  the opponent ("" = as drawn, never COL)
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
				vs = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_break_one_line.save"
	state.settings_path = "user://capture_break_one_line.cfg"
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
	print("match: ", sim.squads[0].code, " v ", sim.squads[1].code, " seed ", state.career_seed)
	var t: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
	t["gameplan"] = "defensive"
	sim.set_tactics(me, t)
	sim.run_quarter()
	sim.run_quarter()
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
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(16)
	await _shot(scene, out, "1_break")
	_press(scene, "CallRow_tag")
	await _frames(8)
	var tp: Node = scene.find_child("TagPicker", true, false)
	if tp != null:
		for b in tp.find_children("TagPickerGrid_*", "Button", true, false):
			if str(b.name) != "TagPickerGrid_":
				(b as Button).emit_signal("pressed")
				break
	await _frames(8)
	await _shot(scene, out, "2_tag")
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
