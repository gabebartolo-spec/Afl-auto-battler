extends SceneTree
## UI audit of the screens the director's PC playtest flagged (ROADMAP §1.11), at a
## phone's size or a PC window's, so both can be compared shot for shot:
##   godot --path . --script tools/visual/capture_phone_audit.gd -- --out /tmp/audit [--size 390x844]
## Writes <out>_<size>_<NN>_<screen>.png for each screen and <out>_<size>_report.txt:
## per screen, how many screens of scrolling it holds, text cut short, anything
## running off the side and taps shorter than a thumb (44 px). A fresh Collingwood
## career; nothing here touches a real save.

const THUMB := 44.0

var out := "/tmp/audit"
var size := Vector2i(390, 844)
var tag := ""
var shot_n := 0
var report := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	tag = "%dx%d" % [size.x, size.y]
	await process_frame
	root.size = size
	DisplayServer.window_set_size(size)
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_audit.save"
	state.settings_path = "user://capture_audit.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	UK.apply_appearance("dark")
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Out of a match: the menu, a new career, Club Forge and the week's screens.
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _shot("main_menu")
	main.call("_on_new_career")
	await _shot("new_career")
	main.queue_free()
	await _settle()
	await _scene("ClubForgeScene", "club_forge")
	state.start_season("COL", db.club_list("COL"))
	for s in [["HubScene", "hub"], ["SelectionScene", "selection"], ["ListScene", "list"],
			["TrainingScene", "training"], ["CoachingScene", "coaching"], ["StaffScene", "staff"],
			["LadderScene", "ladder"]]:
		await _scene(s[0], s[1])

	# A live match, through each box the playtest flagged.
	if state.prepare_interactive_match():
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		await _shot("match_prebounce")
		var start: Node = m.find_child("StartQuarter", true, false)
		if start != null:
			start.emit_signal("pressed")
			await _settle()
		var pitch = m.get("_pitch")
		if pitch != null:
			pitch.set_speed(8.0)
		var moment_shot := false
		var guard := 0
		while m.find_child("CoachBox", true, false) == null and guard < 4000:
			if pitch != null and pitch.playing:
				pitch._process(0.25)
			await process_frame
			guard += 1
			var card = m.find_child("MomentCard", true, false)
			if card != null:
				if not moment_shot:
					await _settle()
					await _shot("match_decision")
					moment_shot = true
				var pick: Button = card.find_child("Moment_0", true, false)
				if pick != null:
					pick.emit_signal("pressed")
				await _settle()
		await _shot("match_live_feed_quarter_time")
		var box: Node = m.find_child("CoachBox", true, false)
		if box != null:
			await _shot("match_quarter_break")
			var bm: Control = box.find_child("BreakMatchups", true, false)
			if bm != null:
				await _scroll_to(bm)
				await _shot("match_key_matchups")
			var more: Button = box.find_child("MoreCallsToggle", true, false)
			if more != null:
				more.emit_signal("pressed")
				await _settle()
				await _shot("match_more_calls")
		# On to half time without watching.
		guard = 0
		var sim = state.pending_sim
		while not (sim.current_quarter >= 3 and m.find_child("CoachBox", true, false) != null) and guard < 40:
			guard += 1
			var sb = m.find_child("StartQuarter", true, false)
			if sb != null:
				sb.emit_signal("pressed")
				await _settle()
			var card = m.find_child("MomentCard", true, false)
			if card != null:
				var pick: Button = card.find_child("Moment_0", true, false)
				if pick != null:
					pick.emit_signal("pressed")
				await _settle()
			if m.find_child("CoachBox", true, false) == null and m.find_child("MomentCard", true, false) == null and pitch != null:
				pitch.skip_to_end()
				await _settle()
		await _shot("match_half_time")
		var ht: Node = m.find_child("HalfTimeReport", true, false)
		if ht != null:
			ht.emit_signal("pressed")
			await _settle()
			await _shot("match_half_time_report")
			m.call("handle_back")
			await _settle()
		m.call("_on_skip")
		for i in range(60):
			await process_frame
		await _shot("match_full_time_summary")
		var st: Node = m.find_child("ReviewTab_stats", true, false)
		if st != null:
			st.emit_signal("pressed")
			await _settle()
			await _shot("match_full_time_stats")
		m.queue_free()
		await _settle()
	else:
		report.append("!! no live match could be prepared")

	# The offseason and the League Draft.
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	await _scene("OffseasonScene", "offseason")
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted(), db.active_clubs(2026).duplicate(), 12345)
	var draft = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(draft)
	draft.call("_on_club_chosen", "MEL")
	await _shot("draft")
	draft.queue_free()

	var path := "%s_%s_report.txt" % [out, tag]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	print("\n".join(report))
	print("wrote ", path)
	quit(0)


func _settle() -> void:
	for i in range(6):
		await process_frame


func _scene(scene: String, label: String) -> void:
	var node = load("res://scenes/%s.tscn" % scene).instantiate()
	root.add_child(node)
	await _shot(label)
	node.queue_free()
	await _settle()


## Scroll the nearest scroll container so c is at the top of it.
func _scroll_to(c: Control) -> void:
	var p := c.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		(p as ScrollContainer).ensure_control_visible(c)
		await _settle()


func _shot(label: String) -> void:
	await _settle()
	shot_n += 1
	# Headless (no renderer) still measures the layout; it just has no picture.
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("%s_%s_%02d_%s.png" % [out, tag, shot_n, label])
	report.append("== %02d %s" % [shot_n, label])
	for line in _measure():
		report.append("   " + line)


## What a thumb and an eye meet on the screen as it stands.
func _measure() -> PackedStringArray:
	var lines := PackedStringArray()
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var deepest := 0.0
	var off_side := []
	var cut := []
	var small := []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if c is ScrollContainer and r.size.y > 0.0 and c.get_child_count() > 0:
			var inner := c.get_child(0) as Control
			if inner != null:
				deepest = maxf(deepest, inner.size.y / r.size.y)
		if not (c is Label or c is BaseButton):
			continue
		if not r.intersects(view):
			continue
		var name := _name(c)
		if r.end.x > view.end.x + 1.0 or r.position.x < -1.0:
			off_side.append(name)
		if c is Label:
			var l := c as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text != "":
				var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						l.get_theme_font_size("font_size")).x
				if w > r.size.x + 1.0:
					cut.append("%s \"%s\"" % [name, l.text.left(40)])
		elif c is Button:
			var b := c as Button
			if b.text != "" and (b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
				var w := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						b.get_theme_font_size("font_size")).x
				if w > r.size.x - 8.0:
					cut.append("%s \"%s\"" % [name, b.text.left(40)])
		if c is BaseButton and r.size.y < THUMB - 0.5 and view.encloses(r):
			small.append("%s (%d px)" % [name, int(r.size.y)])
	lines.append("scroll: %.1f screens deep" % deepest if deepest > 1.05 else "scroll: fits")
	if not off_side.is_empty():
		lines.append("off the side (%d): %s" % [off_side.size(), ", ".join(off_side.slice(0, 8))])
	if not cut.is_empty():
		lines.append("text cut short (%d): %s" % [cut.size(), "; ".join(cut.slice(0, 8))])
	if not small.is_empty():
		lines.append("taps under %d px (%d): %s" % [int(THUMB), small.size(), ", ".join(small.slice(0, 8))])
	return lines


func _name(c: Control) -> String:
	var s := str(c.name)
	if s.begins_with("@"):
		s = c.get_class()
		if c is Button and (c as Button).text != "":
			s += " \"" + (c as Button).text.left(24) + "\""
		elif c is Label:
			s += " \"" + (c as Label).text.left(24) + "\""
	return s
