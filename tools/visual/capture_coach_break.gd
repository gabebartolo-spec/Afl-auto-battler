extends SceneTree
## Visual review tool for the break screen's coaching descriptions and the
## plan line under the clock. Needs a real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_coach_break \
##       -f args="--size 390x844"
## Writes <out>_focus.png (a forward picked for Play through), <out>_pep.png (Pep talk and Rotations, the neutral choices picked, so
## their descriptions show), <out>_tag.png (Tag with no tag picked) and
## <out>_plan.png (the match screen with a long plan line: every call in full).
##   --size WxH   window size (default 390x844)    --light   light appearance
## A fresh Melbourne career's first match at quarter time. Never touches a
## real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "coach_break"
	var mode := "dark"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--light":
				mode = "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_coach.save"
	state.settings_path = "user://capture_coach.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	if not state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	state.pending_sim.run_quarter()
	UK.apply_appearance(mode)
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	var more: Button = scene.find_child("MoreCallsToggle", true, false)
	if more != null:
		more.emit_signal("pressed")
	await _frames(6)
	# A forward picked for Play through: the note says his job.
	var side0 := int(scene.get("_my_side"))
	var fwd := ""
	for p in state.pending_sim.squads[side0].ground:
		if str(p["role"]) == "FWD":
			fwd = str(p["id"])
			break
	var pick: Button = scene.find_child("FocusPickerGrid_" + fwd, true, false)
	if pick == null:
		var other: Button = scene.find_child("FocusPickerOther", true, false)
		if other != null:
			other.emit_signal("pressed")
			await _frames(6)
		pick = scene.find_child("Sheet_" + fwd, true, false)
	if pick != null:
		pick.emit_signal("pressed")
		await _frames(6)
	await _shoot(scene.find_child("FocusPicker", true, false), out + "_focus.png")
	await _frames(8)
	# Composed and Normal are the defaults: their words show without a tap.
	await _shoot(scene.find_child("PepPicker", true, false), out + "_pep.png")
	await _frames(8)
	# A tag picked (their first card), so the note and who goes to him show.
	var tag_btns := scene.find_children("TagPickerGrid_?*", "Button", true, false)
	if not tag_btns.is_empty():
		(tag_btns[0] as Button).emit_signal("pressed")
		await _frames(6)
	await _shoot(scene.find_child("TagPicker", true, false), out + "_tag.png")
	await _frames(8)
	# A long plan line: the longest names on either side, every call set.
	var side := int(scene.get("_my_side"))
	var mine: Array = scene.call("_roster_side", side)
	var theirs: Array = scene.call("_roster_side", 1 - side)
	var calls := {"gameplan": "defensive", "tag_id": _longest(db, theirs), "focus_id": fwd if fwd != "" else _longest(db, mine),
			"interceptor_id": _longest(db, mine.filter(func(r): return str(r["role"]) == "DEF")),
			"spare_accountable": false}
	var go: Button = scene.find_child("StartQuarter", true, false)
	if go != null:
		go.emit_signal("pressed")
	await _frames(10)
	scene.call("_show_setup", calls)
	await _frames(10)
	_save(out + "_plan.png")
	quit()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _longest(db, roster: Array) -> String:
	var best := ""
	for r in roster:
		var id := str(r["id"])
		if db.player_display_name_by_id(id, "").length() > db.player_display_name_by_id(best, "").length():
			best = id
	return best


## Scroll the break so `target` sits near the top, then save the screen.
func _shoot(target: Control, path: String) -> void:
	if target != null:
		var n: Node = target.get_parent()
		while n != null:
			if n is ScrollContainer:
				(n as ScrollContainer).scroll_vertical = maxi(0, int(target.global_position.y - n.global_position.y) - 40)
				break
			n = n.get_parent()
	else:
		push_error("missing control for " + path)
	await process_frame
	await process_frame
	_save(path)


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
