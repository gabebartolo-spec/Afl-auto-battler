extends SceneTree
## The match's call panes as a phone and a PC show them: before the first ball-up, at quarter time,
## the break's Match stats sheet and the full-time Stats tab. Needs a real renderer:
##   godot --path . --script tools/visual/capture_break_panes.gd -- --out /tmp/bp --size 1280x720 [--club FRE --vs MEL] [--seed 2050] [--logical 1280x720] [--tag]
## --size is the canvas in UI units. --logical draws a bigger window the way the game does on a PC: ScreenLayout
## gives a 2560x1440 window a 1280x720 canvas at twice the pixels, so --size 2560x1440 --logical 1280x720.
## --tag picks a tag first (Who tags shows), to measure the fullest pre-bounce pane.
## Writes <out>_pre_1..n.png (the pane from the top, then scrolled on), <out>_qt.png, <out>_qtplan.png,
## <out>_qtstats.png, <out>_fulltimestats.png, and prints each column's height, what is in it and how much
## of the pane is empty under it. Seeded; never touches a real save.

var _w := 390
var _h := 844
var _lw := 0
var _lh := 0
var _vp: SubViewport
var _tag := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "bp"
	var club := "FRE"
	var vs := "MEL"
	var seed_from := 2050
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--tag":
			_tag = true
		if i >= a.size() - 1:
			continue
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--vs": vs = str(a[i + 1])
			"--seed": seed_from = int(a[i + 1])
			"--logical":
				var lwh := str(a[i + 1]).split("x")
				_lw = int(lwh[0])
				_lh = int(lwh[1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_break_panes.save"
	state.settings_path = "user://capture_break_panes.cfg"
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	_vp = SubViewport.new()
	_vp.size = Vector2i(_w, _h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _lw > 0:
		_vp.size_2d_override = Vector2i(_lw, _lh)
		_vp.size_2d_override_stretch = true
	root.add_child(_vp)
	await _frames(4)
	var tries := 0
	while true:
		state.reset()
		state.career_seed = seed_from + tries
		state.replay_seed = seed_from + tries
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		state.prepare_interactive_match()
		var s0 = state.pending_sim
		var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
		if them == vs or tries > 80:
			break
		tries += 1
	print("SEED ", state.replay_seed, " ", club, " v ", vs)
	var sim = state.pending_sim
	# Before the first ball-up.
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	_vp.add_child(scene)
	await _frames(24)
	if _tag:
		for b in scene.find_children("TagPickerGrid_*", "Button", true, false):
			if str(b.name) != "TagPickerGrid_":
				(b as Button).emit_signal("pressed")
				break
		await _frames(24)
	_measure(scene, "PRE")
	await _shots(scene, out + "_pre")
	scene.queue_free()
	await _frames(4)
	# Quarter time: Q1 played, the calls as they stand.
	sim.run_quarter()
	scene = load("res://scenes/MatchScene.tscn").instantiate()
	_vp.add_child(scene)
	await _frames(24)
	_measure(scene, "QT")
	await _shot(out + "_qt.png")
	if _w < 700:
		var row: Node = scene.find_child("CallRow_plan", true, false)
		if row != null:
			(row as Button).emit_signal("pressed")
			await _frames(16)
			await _shot(out + "_qtplan.png")
			scene.call("_close_top_break_sheet")
			await _frames(6)
	scene.call("_show_break_stats")
	await _frames(14)
	await _shot(out + "_qtstats.png")
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
	await _shot(out + "_fulltimestats.png")
	quit()


## What the pre-bounce pane holds: each column's height and parts, the room under it, the pane's scroll.
func _measure(scene: Node, tag: String) -> void:
	var box: Node = scene.find_child("CoachBox", true, false)
	if box == null:
		print(tag, " no CoachBox")
		return
	var sc: ScrollContainer = null
	for s in box.find_children("*", "ScrollContainer", true, false):
		sc = s
		break
	if sc != null:
		var inner := sc.get_child(0) as Control
		print(tag, " SCROLL room ", int(sc.size.y), " holds ", int(inner.get_combined_minimum_size().y),
				" overflow ", int(inner.get_combined_minimum_size().y - sc.size.y))
	var ruck: Node = box.find_child("MainRuckPicker", true, false)
	print(tag, " MAINRUCK ", "drawn" if ruck != null else "not drawn (fewer than two rucks on the ground)")
	if ruck != null:
		for b in ruck.find_children("*", "Button", true, false):
			print(tag, " MAINRUCK card: ", str((b as Button).text).replace("
", " | "))
	for r in box.find_children("BreakMatchup_*", "HBoxContainer", true, false):
		var ml := r.find_child("MatchupLine", true, false) as RichTextLabel
		var mc := r.find_child("ChangeMatchup", true, false) as Button
		if ml != null and mc != null:
			var last := ml.get_line_count() - 1
			var rng := ml.get_line_range(last)
			var shown := ml.get_parsed_text().substr(rng.x, rng.y - rng.x).strip_edges(false, true)
			var ends := ml.get_global_rect().position.x + ml.get_theme_font("normal_font").get_string_size(
					shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ml.get_theme_font_size("normal_font_size")).x
			print(tag, " MATCHUP ", r.name, " lines ", ml.get_line_count(), " row ", r.get_global_rect(), " line ", ml.get_global_rect(),
					" change ", mc.get_global_rect(), " gap from sentence end ", snappedf(mc.get_global_rect().position.x - ends, 0.1))
	var cols: Node = box.find_child("BreakColumns", true, false)
	if cols == null:
		return
	var tallest := 0.0
	var hs := []
	for c in cols.get_children():
		var col := c as VBoxContainer
		var t := 0.0
		var parts := []
		for n in col.get_children():
			var ctl := n as Control
			if ctl == null or not ctl.visible:
				continue
			t += ctl.get_combined_minimum_size().y + float(col.get_theme_constant("separation"))
			parts.append("%s:%d" % [ctl.name, int(ctl.get_combined_minimum_size().y)])
		hs.append(t)
		tallest = maxf(tallest, t)
		print(tag, " COL ", col.name, " height ", int(t), " ", parts)
	var i := 0
	for hh in hs:
		print(tag, " COL", i, " empty ", int(tallest - float(hh)), " px = ", int(100.0 * (tallest - float(hh)) / maxf(tallest, 1.0)), "%")
		i += 1
	print(tag, " TALLEST ", int(tallest), " viewport ", _vp.get_visible_rect().size)


## The pre-bounce pane from the top, then scrolled on by 80% of its height each time.
func _shots(scene: Node, prefix: String) -> void:
	var box: Node = scene.find_child("CoachBox", true, false)
	var sc: ScrollContainer = null
	if box != null:
		for s in box.find_children("*", "ScrollContainer", true, false):
			sc = s
			break
	var n := 1
	await _shot("%s_%d.png" % [prefix, n])
	if sc == null:
		return
	var inner := sc.get_child(0) as Control
	var room := sc.size.y
	var most := int(inner.get_combined_minimum_size().y - room)
	var at := 0
	while at < most and n < 6:
		at = mini(most, at + int(room * 0.8))
		sc.scroll_vertical = at
		await _frames(4)
		n += 1
		await _shot("%s_%d.png" % [prefix, n])
	sc.scroll_vertical = 0


func _shot(path: String) -> void:
	await _frames(2)
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
