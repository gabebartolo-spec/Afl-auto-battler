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
## The smallest type a stats sheet may use on a wide screen: UiKit.SMALL, the smallest
## body size the hub itself uses (the calls block used to run at 12 and 11).
const BODY_FLOOR := 13
## A wide sheet fills its screen (to its 12 unit margins); the breaks and full time.
const SHEET_FILL := 0.97
const SIZES := [Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(390, 844)]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


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
		await _t("_test_box_score", [size])
		await _t("_test_match_sheets", [size])
		if size == SIZES[0]:
			await _t("_test_calls_seeds", [size])
		for key in SCREENS:
			await _t("_test_screen", [str(key), size])
		for section in ["ladder", "players", "ratings", "awards", "trophies"]:
			load("res://scripts/ui/StatsHubScene.gd").current = section
			await _open("stats")
			_t("_test_audit", [current_scene, "stats %s %dx%d" % [section, size.x, size.y]])
		load("res://scripts/ui/StatsHubScene.gd").current = "fixture"
	print(Ran.line("Row gap", self))
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


func _test_screen(key: String, size: Vector2i) -> void:
	await _open(key)
	_t("_test_audit", [current_scene, "%s %dx%d" % [key, size.x, size.y]])


## The match stats sheet as MatchScene hosts it: the box score in a full-width body.
func _test_box_score(size: Vector2i) -> void:
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
	_t("_test_audit", [bg, "boxscore %dx%d" % [size.x, size.y]])
	_inked(bg, str(res["home"]), str(res["away"]), "boxscore %dx%d" % [size.x, size.y])
	bg.queue_free()
	await _settle(2)


## The break's Match stats sheet and full time's Stats tab, on a real MatchScene. On a
## PC the score and the team numbers fit one screen (director, 2026-10-14: "having to
## scroll down to see the stats part is bad"), which a 1280x720 window must show with
## nothing to scroll; a phone stacks them and scrolls.
func _test_match_sheets(size: Vector2i) -> void:
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
		_t("_test_audit", [sheet, "break stats %dx%d" % [size.x, size.y]])
		var bres: Dictionary = scene.get("_res")
		_inked(sheet, str(bres["home"]), str(bres["away"]), "break stats %dx%d" % [size.x, size.y])
		if size.x >= 1280:
			_one_page(sheet, "break stats %dx%d" % [size.x, size.y])
			_wide_sheet(sheet, "break stats %dx%d" % [size.x, size.y], size)
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
		_t("_test_audit", [ft, "full time stats %dx%d" % [size.x, size.y]])
		var fres: Dictionary = scene.get("_res")
		_inked(ft, str(fres["home"]), str(fres["away"]), "full time stats %dx%d" % [size.x, size.y])
		if size.x >= 1280:
			_one_page(ft.find_child("StatsColumns", true, false), "full time stats %dx%d" % [size.x, size.y])
			_wide_sheet(ft, "full time stats %dx%d" % [size.x, size.y], size)
			_calls_in_view(ft, "full time stats %dx%d" % [size.x, size.y])
		else:
			_phone_scorers(ft, "full time stats %dx%d" % [size.x, size.y])
	scene.queue_free()
	await _settle(4)


## Both clubs treated alike (director A1, 2026-10-14: club ink wherever a club or a player is
## named): each club's name and score, and every goalkicker and best-rated name under it, wear
## that club's ink (UiKit.club_ink_pair), not plain white for one of them.
func _inked(node: Node, home: String, away: String, tag: String) -> void:
	var inks: Array = load("res://scripts/ui/UiKit.gd").club_ink_pair(home, away)
	for side in [0, 1]:
		var head: Node = node.find_child("BoxHeader_%d" % side, true, false)
		_check(head != null, "%s: the score header for side %d is there" % [tag, side])
		if head != null:
			var fig: Node = head.find_child("BoxScore_%d" % side, true, false)
			_check(fig is Label and (fig as Label).get_theme_color("font_color") == (inks[side] as Color),
					"%s: side %d's score is in its club's ink" % [tag, side])
		var col: Node = node.find_child("BoxPlayers_%d" % side, true, false)
		var names: Array = col.find_children("BoxPlayerName_*", "Label", true, false) if col != null else []
		_check(names.size() >= 2, "%s: side %d lists goalkickers and best-rated players (%d)" % [tag, side, names.size()])
		var plain := []
		for n in names:
			if (n as Label).get_theme_color("font_color") != load("res://scripts/ui/UiKit.gd").club_name_colour(inks[side] as Color):
				plain.append((n as Label).text)
		_check(plain.is_empty(), "%s: every player name for side %d is in his club's ink (not: %s)" % [tag, side, str(plain)])


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


## Full time on the Stats tab at 1280x720 over several matches (different clubs, seeds and
## numbers of calls): the calls block is inside the page every time, not one lucky game.
func _test_calls_seeds(size: Vector2i) -> void:
	for pair in [["ADE", 2026], ["MEL", 2031], ["GWS", 2040], ["WCE", 2052], ["RIC", 2067], ["FRE", 2075]]:
		_state.reset()
		_state.career_seed = int(pair[1])
		_state.replay_seed = int(pair[1])
		_state.set_setting("seen_training_intro", true)
		_state.start_season(str(pair[0]), _db.club_list(str(pair[0])))
		_state.prepare_interactive_match()
		var sim = _state.pending_sim
		for q in range(4):
			sim.run_quarter()
		var scene = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(scene)
		await _settle(16)
		scene.set("_res", sim.result())
		scene.set("_finished", true)
		scene.call("_show_fulltime")
		await _settle(14)
		scene.set("_ft_tab", "stats")
		scene.call("_render_ft")
		await _settle(14)
		var ft = scene.find_child("FullTime", true, false)
		_check(ft != null, "%s %d: full time opens" % [str(pair[0]), int(pair[1])])
		if ft != null:
			_calls_in_view(ft, "%s %d full time stats %dx%d" % [str(pair[0]), int(pair[1]), size.x, size.y])
		scene.queue_free()
		await _settle(4)


## The whole Stats tab shows at once: the scroll holds no more than it shows, and the
## "What your calls did" block (heading to last line) lies inside the visible page.
func _calls_in_view(ft: Node, tag: String) -> void:
	var calls := ft.find_child("CallsReadout", true, false) as Control
	_check(calls != null and calls.is_visible_in_tree(), tag + ": the calls block is on the Stats tab")
	var sc: Node = ft.find_child("MatchStats", true, false)
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	_check(sc != null, tag + ": the Stats tab sits in a scroll")
	if calls == null or sc == null:
		return
	var view := (sc as Control).get_global_rect()
	var at := calls.get_global_rect()
	var held := 0.0
	for ch in sc.get_children():
		if ch is Control and not (ch is ScrollBar):
			held = maxf(held, (ch as Control).size.y)
	print("CALLS %s: block %d px at y %d..%d, page %d..%d, scroll holds %d of %d" % [tag, int(at.size.y),
			int(at.position.y), int(at.end.y), int(view.position.y), int(view.end.y), int(held), int(view.size.y)])
	_check(at.position.y >= view.position.y - 1.0 and at.end.y <= view.end.y + 1.0,
			tag + ": the calls block is inside the page without scrolling (%d..%d of %d..%d)" % [int(at.position.y), int(at.end.y),
			int(view.position.y), int(view.end.y)])
	_check(at.position.x >= view.position.x - 1.0 and at.end.x <= view.end.x + 1.0, tag + ": the calls block is inside the page's width")
	_check(held <= view.size.y + 1.0, tag + ": the Stats tab needs no scrolling (%d of %d px)" % [int(held), int(view.size.y)])


## On a wide screen the sheet grows with it (to its margins) and no word on it is under
## BODY_FLOOR: the type is the hub's, not smaller.
func _wide_sheet(sheet: Node, tag: String, size: Vector2i) -> void:
	var sc: Node = sheet.find_child("StatsColumns", true, false)
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc == null:
		_check(false, tag + ": the sheet has a scroll")
		return
	var shell := (sc as Control).get_parent().get_parent() as Control
	var w := shell.size.x
	var most := float(size.x) - 24.0
	print("SHEET %s: %d of %d px wide" % [tag, int(w), int(most)])
	_check(w <= most + 1.0, tag + ": the sheet fits its screen (%d of %d)" % [int(w), int(most)])
	_check(w >= most * SHEET_FILL, tag + ": the sheet grows with the screen (%d of %d)" % [int(w), int(most)])
	var low := 99
	var where := ""
	for n in sheet.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var fs := 0
		var txt := ""
		if c is Label:
			txt = (c as Label).text
			fs = c.get_theme_font_size("font_size")
		elif c is RichTextLabel:
			txt = (c as RichTextLabel).get_parsed_text()
			fs = c.get_theme_font_size("normal_font_size")
		if txt.strip_edges() != "" and fs < low:
			low = fs
			where = txt.left(24)
	print("FONT %s: smallest %d px ('%s')" % [tag, low, where])
	_check(low >= BODY_FLOOR, tag + ": the smallest type is %d px, not under %d ('%s')" % [low, BODY_FLOOR, where])


## A phone's scorer rows keep the figure beside the name (the PR's own near_figure rule),
## not a screen away: no more than MAX_GAP between his name and his figure.
func _phone_scorers(sheet: Node, tag: String) -> void:
	var worst := 0.0
	var seen := 0
	var who := ""
	for b in sheet.find_children("BoxPlayer_*", "Button", true, false):
		var h: Node = null
		for c in b.get_children():
			if c is HBoxContainer:
				h = c
		if h == null or h.get_child_count() < 2:
			continue
		var a = h.get_child(0)
		var f = h.get_child(1)
		if not (a is Label and f is Label):
			continue
		seen += 1
		var gap := _text_start(f) - _text_end(a)
		if gap > worst:
			worst = gap
			who = (a as Label).text
	_check(seen >= 4, tag + ": scorer rows found (%d)" % seen)
	print("SCORERS %s: %d rows, widest name-to-figure gap %d px ('%s')" % [tag, seen, int(worst), who])
	_check(worst <= MAX_GAP, tag + ": a scorer's name and figure %d px apart ('%s')" % [int(worst), who])


func _test_audit(scene: Node, tag: String) -> void:
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
