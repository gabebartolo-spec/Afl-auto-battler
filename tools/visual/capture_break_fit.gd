extends SceneTree
## Does each break fit its sheet? Quarter, half and three-quarter time at one canvas size, drawn in a
## SubViewport of exactly that size (a window can be clamped by the screen; this cannot). Needs a real renderer:
##   godot --windowed --path . --script tools/visual/capture_break_fit.gd -- --out /tmp/fit --size 1280x720 [--club FRE --vs MEL] [--picks]
## --picks names all three Play through players first (the longest Play through row).
## Writes <out>_q2.png, <out>_q3.png, <out>_q4.png and prints, per break, the sheet's scroll room against what
## it holds, each column's height and each call row's needs against its room. Seeded; never touches a real save.

var _w := 1280
var _h := 720
var _vp: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "fit"
	var club := "FRE"
	var vs := "MEL"
	var picks := false
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--picks":
			picks = true
		if i >= a.size() - 1:
			continue
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
	state.save_path = "user://capture_break_fit.save"
	state.settings_path = "user://capture_break_fit.cfg"
	state.set_setting("seen_training_intro", true)
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	_vp = SubViewport.new()
	_vp.size = Vector2i(_w, _h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	await _frames(4)
	for q in [2, 3, 4]:
		var tries := 0
		while true:
			state.reset()
			state.career_seed = 2050 + tries
			state.replay_seed = 2050 + tries
			state.start_season(club, db.club_list(club))
			state.prepare_interactive_match()
			var s0 = state.pending_sim
			var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
			if them == vs or tries > 80:
				break
			tries += 1
		var sim = state.pending_sim
		if picks:
			var me := int(sim.moment_side)
			var t: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
			var used := {}
			for slot in load("res://scripts/ui/match/MatchNotes.gd").FOCUS_ORDER:
				for p in sim.squads[me].ground:
					if not used.has(str(p["id"])):
						t[slot] = str(p["id"])
						used[str(p["id"])] = true
						break
			sim.set_tactics(me, t)
		for i in range(q - 1):
			sim.run_quarter()
		var scene = load("res://scenes/MatchScene.tscn").instantiate()
		_vp.add_child(scene)
		await _frames(24)
		print("BREAK q", q, " ", club, " v ", vs, " canvas ", _vp.get_visible_rect().size)
		_measure(scene, "q%d" % q)
		await _shot("%s_q%d.png" % [out, q])
		# Then each call opened, so its own room shows.
		for key in ["tag", "pt", "def"]:
			var row: Node = scene.find_child("CallRow_" + key, true, false)
			if row is Button and _w >= 760:
				(row as Button).emit_signal("pressed")
				await _frames(6)
				await _shot("%s_q%d_%s.png" % [out, q, key])
				if key == "tag":
					# A tag on: Who tags and the longer note under it.
					for b in scene.find_children("TagPickerGrid_*", "Button", true, false):
						if str(b.name) != "TagPickerGrid_":
							(b as Button).emit_signal("pressed")
							break
					await _frames(6)
					_measure_scroll(scene, "q%d tagged" % q)
					await _shot("%s_q%d_tagged.png" % [out, q])
		scene.queue_free()
		await _frames(4)
	quit()


func _measure(scene: Node, tag: String) -> void:
	var box: Node = scene.find_child("CoachBox", true, false)
	if box == null:
		print(tag, " no CoachBox")
		return
	_measure_scroll(scene, tag)
	var cols: Node = box.find_child("BreakColumns", true, false)
	if cols != null:
		for c in cols.get_children():
			var col := c as Control
			print(tag, " COL ", col.name, " size ", col.size, " needs ", col.get_combined_minimum_size())
	var pane: Node = box.find_child("CallPane", true, false)
	if pane != null:
		print(tag, " PANE kept ", (pane as Control).custom_minimum_size.y, " size ", (pane as Control).size)
		for b in pane.get_children():
			print(tag, " BODY ", b.name, " ", b.get_meta("call", ""), " needs ", (b as Control).get_combined_minimum_size().y)
	for r in box.find_children("CallRow_*", "Button", true, false):
		var inside := (r as Control).get_child(0) as Control
		var ans: Node = (r as Node).find_child("RowAnswer", true, false)
		var lab: Node = (r as Node).find_child("RowLabel", true, false)
		print(tag, " ROW ", r.name, " row ", (r as Control).size, " needs ", inside.get_combined_minimum_size(),
				" label ", (lab as Label).text if lab is Label else "",
				" answer '", (ans as RichTextLabel).get_parsed_text() if ans is RichTextLabel else "", "' ",
				int((ans as RichTextLabel).get_content_width()) if ans is RichTextLabel else -1, "/",
				int((ans as Control).size.x) if ans != null else -1)


## The sheet's scroll room against what it holds (holds > room: the break scrolls).
func _measure_scroll(scene: Node, tag: String) -> void:
	var box: Node = scene.find_child("CoachBox", true, false)
	if box == null:
		return
	for s in box.find_children("*", "ScrollContainer", true, false):
		var sc := s as ScrollContainer
		var inner := sc.get_child(0) as Control
		print(tag, " SCROLL room ", int(sc.size.y), " holds ", int(inner.get_combined_minimum_size().y),
				" wide ", int(sc.size.x), " needs ", int(inner.get_combined_minimum_size().x))
		break


func _shot(path: String) -> void:
	await _frames(2)
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
