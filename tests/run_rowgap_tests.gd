extends SceneTree
## godot --headless --path . --script tests/run_rowgap_tests.gd [-- --explore]
## A number sits next to the name it belongs to (director, 2026-10-14: "having all
## this space between divorces the number from the source and harms readability").
## Screens are opened at 1280x720, 2560x1440 and 390x844; on each, every row that
## puts a label and a figure side by side must leave no more than MAX_GAP logical
## pixels between the end of the label's text and the start of the figure.

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []
var _explore := false

const SUITE_SEED := 2027
const MAX_GAP := 160.0
const SCREENS := ["list", "training", "coaching", "staff", "stats", "offseason", "season_review", "forge", "hub", "selection"]
const SIZES := [Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(390, 844)]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _settle(n := 6) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	_explore = "--explore" in OS.get_cmdline_user_args()
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_state.autosave_enabled = false
	_state.save_path = "user://test_rowgap.save"
	_state.settings_path = "user://test_rowgap.cfg"
	_state.delete_saved_career()
	for size in SIZES:
		root.size = size
		await _settle()
		await _box_score(size)
		await _match_sheets(size)
		for key in SCREENS:
			await _screen(str(key), size)
		for section in ["ladder", "players", "ratings", "awards", "trophies"]:
			load("res://scripts/ui/StatsHubScene.gd").current = section
			await _open("stats")
			_audit(current_scene, "stats %s %dx%d" % [section, size.x, size.y])
		load("res://scripts/ui/StatsHubScene.gd").current = "fixture"
	print("Row gap tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


func _open(key: String) -> void:
	_state.reset()
	_state.start_season("MEL", _db.club_list("MEL"))
	_state.replay_seed = SUITE_SEED
	_state.tutorials = false
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	_router.go(key)
	for i in range(90):
		var sc := current_scene as CanvasItem
		if sc == null or sc.modulate.a >= 0.99:
			break
		await process_frame
	await _settle(8)


func _screen(key: String, size: Vector2i) -> void:
	await _open(key)
	_audit(current_scene, "%s %dx%d" % [key, size.x, size.y])


## The match stats sheet as MatchScene hosts it: the box score in a full-width body.
func _box_score(size: Vector2i) -> void:
	var squad = load("res://scripts/sim/Squad.gd")
	var sim = load("res://scripts/sim/MatchSim.gd").new(
			squad.new("ADE", _db.club_list("ADE"), true, "ADE"),
			squad.new("MEL", _db.club_list("MEL"), false, "MEL"), 42)
	for q in range(4):
		sim.run_quarter()
	var res: Dictionary = sim.result()
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(body)
	body.add_child(load("res://scripts/ui/match/BoxScore.gd").new().setup(res))
	await _settle(8)
	_audit(bg, "boxscore %dx%d" % [size.x, size.y])
	bg.queue_free()
	await _settle(2)


## The break's Match stats sheet and full time's Stats tab, on a real MatchScene. On a
## PC the score and the team numbers fit one screen (director, 2026-10-14: "having to
## scroll down to see the stats part is bad"), which a 1280x720 window must show with
## nothing to scroll; a phone stacks them and scrolls.
func _match_sheets(size: Vector2i) -> void:
	_state.reset()
	_state.career_seed = 2026
	_state.replay_seed = 2026
	_state.set_setting("seen_training_intro", true)
	_state.start_season("ADE", _db.club_list("ADE"))
	_state.prepare_interactive_match()
	var sim = _state.pending_sim
	sim.run_quarter()
	sim.run_quarter()
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _settle(16)
	scene.call("_show_break_stats")
	await _settle(14)
	var sheet = scene.find_child("BreakStatsSheet", true, false)
	_check(sheet != null, "break stats sheet opens at %dx%d" % [size.x, size.y])
	if sheet != null:
		_audit(sheet, "break stats %dx%d" % [size.x, size.y])
		if size.x >= 1280:
			_one_page(sheet, "break stats %dx%d" % [size.x, size.y])
	scene.call("_close_report")
	await _settle(4)
	sim.run_quarter()
	sim.run_quarter()
	scene.set("_res", sim.result())
	scene.set("_finished", true)
	scene.call("_show_fulltime")
	await _settle(14)
	scene.set("_ft_tab", "stats")
	scene.call("_render_ft")
	await _settle(14)
	var ft = scene.find_child("FullTime", true, false)
	_check(ft != null, "full time opens at %dx%d" % [size.x, size.y])
	if ft != null:
		_audit(ft, "full time stats %dx%d" % [size.x, size.y])
		if size.x >= 1280:
			_one_page(ft.find_child("StatsColumns", true, false), "full time stats %dx%d" % [size.x, size.y])
	scene.queue_free()
	await _settle(4)


## The score and team numbers sit side by side, and the sheet's scroll holds them all.
func _one_page(node: Node, tag: String) -> void:
	if node == null:
		_check(false, tag + ": the score and team numbers share a page (StatsColumns)")
		return
	var cols = node if node.name == "StatsColumns" else node.find_child("StatsColumns", true, false)
	_check(cols != null, tag + ": the score and team numbers share a page (StatsColumns)")
	if cols == null:
		return
	var sc: Node = cols
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc != null:
		var room: float = (sc as Control).size.y
		var held: float = (cols as Control).size.y
		print("PAGE %s: columns %d px, room %d px; width %d, kids %s" % [tag, int(held), int(room), int((cols as Control).size.x),
				", ".join((cols.get_children() as Array).map(func(c): return "%s %d min %d" % [c.name, int((c as Control).size.x), int((c as Control).get_combined_minimum_size().x)]))])
		_check(held <= room + 1.0, "%s: score and team numbers fit without scrolling (%d of %d px)" % [tag, int(held), int(room)])


func _audit(scene: Node, tag: String) -> void:
	# A phone's row is as wide as the phone: only a screen with room is held to it.
	if root.size.x < 900:
		return
	var worst := 0.0
	var where := ""
	for h in scene.find_children("*", "BoxContainer", true, false):
		if not (h is HBoxContainer) or not (h as Control).is_visible_in_tree():
			continue
		var kids: Array = []
		for c in h.get_children():
			if c is Control and (c as Control).visible:
				kids.append(c)
		for i in range(kids.size() - 1):
			var a = kids[i]
			if not (a is Label) or str((a as Label).text).strip_edges() == "":
				continue
			if kids[i + 1] is Label and str((kids[i + 1] as Label).text).ends_with("›"):
				continue    # a way on, not a figure
			var b = null
			for j in range(i + 1, kids.size()):
				if kids[j] is Label and str((kids[j] as Label).text).strip_edges() != "":
					b = kids[j]
					break
				if (kids[j] as Control).size.x > 1.0 or kids[j] is Label:
					break
			if b == null:
				continue
			var gap := _text_start(b) - _text_end(a)
			if gap > worst:
				worst = gap
				where = "'%s' / '%s'" % [(a as Label).text.left(24), (b as Label).text.left(16)]
			if gap > MAX_GAP and _explore:
				print("GAP %s %d px: %s" % [tag, int(gap), "'%s' / '%s'" % [(a as Label).text.left(24), (b as Label).text.left(16)]])
	_check(worst <= MAX_GAP, "%s: label and figure %d px apart (%s)" % [tag, int(worst), where])


func _text_w(l: Label) -> float:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	return minf(f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, l.size.x)


func _text_end(l: Label) -> float:
	var x := l.global_position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT: return x + l.size.x
		HORIZONTAL_ALIGNMENT_CENTER: return x + (l.size.x + _text_w(l)) * 0.5
	return x + _text_w(l)


func _text_start(l: Label) -> float:
	var x := l.global_position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT: return x + l.size.x - _text_w(l)
		HORIZONTAL_ALIGNMENT_CENTER: return x + (l.size.x - _text_w(l)) * 0.5
	return x
