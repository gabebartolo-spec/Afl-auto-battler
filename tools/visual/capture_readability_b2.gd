extends SceneTree
## Readability roll-out batch 2 (director, 2026-10-13): This week, Coaching,
## Staff, Club Forge and the menu, for one match-up "your club v opponent".
##   godot --path . --script tools/visual/capture_readability_b2.gd -- --club COL --opp CAR --size 390x844 --out /tmp/rb2
## Writes <out>_selection.png, _plan.png, _coaching.png, _staff.png, _forge.png, _main.png
## and prints the deterministic clipped-text check: "CLIPPED n" is the number
## of visible labels with more lines than they may show, or with trimmed text
## on a one-line label, on all of these screens.

var W := 390
var H := 844
var _clipped: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(n := 8) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames()
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _check_clipped(scene: Node, tag: String) -> void:
	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text == "" or l.size.x < 2.0:
			continue
		if l.get_line_count() > l.get_visible_line_count():
			_clipped.append("%s: %s (lines)" % [tag, l.text.left(40)])
			continue
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var f := l.get_theme_font("font")
			var fs := l.get_theme_font_size("font_size")
			var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > l.size.x + 1.0:
				_clipped.append("%s: %s (trimmed)" % [tag, l.text.left(40)])


func _run() -> void:
	var out := "/tmp/rb2"
	var club := "COL"
	var opp := "CAR"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--opp": opp = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				W = int(wh[0])
				H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season(club, db.club_list(club))
	var guard := 0
	while str(state.my_next_opponent().get("code", "")) != opp and guard < 26:
		state.advance()
		guard += 1
	print("next opponent ", state.my_next_opponent().get("code", ""), " after ", guard, " rounds")

	var ui: Control = load("res://scenes/SelectionScene.tscn").instantiate()
	root.add_child(ui)
	await _frames(10)
	var week: Control = ui.find_child("SelectionWeek", true, false)
	var sc: ScrollContainer = ui.find_child("SelectionScroll", true, false)
	if sc != null and week != null:
		for i in range(3):
			sc.scroll_vertical = int(week.global_position.y - sc.global_position.y + sc.scroll_vertical - 8)
			await _frames(3)
	await _shot(out + "_selection.png")
	_check_clipped(ui, "selection")
	var chg: Button = ui.find_child("ChangePlan", true, false)
	if chg != null:
		chg.emit_signal("pressed")
		await _frames()
		await _shot(out + "_plan.png")
		_check_clipped(ui, "plan")
	ui.queue_free()
	await _frames(3)

	for pair in [["CoachingScene", "coaching"], ["StaffScene", "staff"], ["Main", "main"]]:
		var s: Node = load("res://scenes/%s.tscn" % pair[0]).instantiate()
		root.add_child(s)
		await _frames(10)
		await _shot("%s_%s.png" % [out, pair[1]])
		_check_clipped(s, str(pair[1]))
		s.queue_free()
		await _frames(3)

	state.reset()
	state.set_forge_club({})
	var f: Node = load("res://scenes/ClubForgeScene.tscn").instantiate()
	root.add_child(f)
	await _frames(6)
	var create = f.find_child("ForgeCreateClub", true, false)
	if create != null:
		create.emit_signal("pressed")
		await _frames(6)
	await _shot(out + "_forge.png")
	_check_clipped(f, "forge")
	print("CLIPPED ", _clipped.size(), " ", str(_clipped))
	quit(0)
