extends SceneTree
## godot --headless --path . --script tests/run_namelink_tests.gd
## A player's name opens his profile (director, 2026-10-14: "virtually every time
## you see a players name anywhere in the game i want to be able to click on it
## and open their bio"). Real touches at 390x844 and 1280x720: the Training
## header, a row's Profile tap, a name in the week's news, and a drag that starts
## on a name still scrolls. Back closes the profile and leaves the screen as it was.

const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2027

var _checks := 0
var _failures: Array = []
var _gs: Node
var _db: Node
var _router: Node
var _nl: GDScript
var _ui: GDScript


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
	_nl = load("res://scripts/ui/NameLink.gd")
	_ui = load("res://scripts/ui/UiKit.gd")
	_gs = root.get_node("GameState")
	_db = root.get_node("GameDB")
	_router = root.get_node("Router")
	_gs.autosave_enabled = false
	_gs.save_path = "user://test_namelink.save"
	_gs.settings_path = "user://test_namelink.cfg"
	_gs.show_real_names = false
	for club in ["FRE", "MEL"]:
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			await _training(club, sz)
	await _hub_tribunal(Vector2i(390, 844))
	await _hub_tribunal(Vector2i(1280, 720))
	await _inked_lines(Vector2i(390, 844))
	await _inked_lines(Vector2i(1280, 720))
	await _plain_names(Vector2i(390, 844))
	await _plain_names(Vector2i(1280, 720))
	await _drag_over_name(Vector2i(390, 844))
	await _line_pitch(Vector2i(390, 844))
	await _line_pitch(Vector2i(1280, 720))
	print("Name link tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)


func _sheet(host: Node) -> Control:
	return host.get_node_or_null("PlayerProfile") as Control


func _sheet_name(sheet: Control) -> String:
	if sheet == null:
		return ""
	for c in sheet.find_children("*", "Label", true, false):
		return (c as Label).text
	return ""


func _training(club: String, sz: Vector2i) -> void:
	var tag := "%s %dx%d" % [club, sz.x, sz.y]
	_gs.reset()
	_gs.set_setting("seen_training_intro", true)
	_gs.start_season(club, _db.club_list(club))
	_gs.replay_seed = SUITE_SEED
	var mine: Array = _gs.my_list
	# A rise in the last game's news, for two of his players.
	var a: Dictionary = mine[0]
	var b: Dictionary = mine[1]
	_gs.last_training_report = {"count": 2, "label": "Round 1", "auto": {
			"rises": [[str(a["id"]), 70, 71], [str(b["id"]), 65, 66]], "traits": [], "at_pot": []}}
	root.size = sz
	var scene: Control = load("res://scenes/TrainingScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	current_scene = scene
	var wide := sz.x >= 760
	var other: Dictionary = mine[3]
	# Every control NameLink-built on Training is thumb sized on the phone: each row's
	# Profile tap is at least 44 x 44 and none of them reaches into the row's own tap.
	if not wide:
		var taps := scene.find_children("Profile_*", "Button", true, false)
		_check(taps.size() >= 4, "%s: the rows carry Profile taps (%d)" % [tag, taps.size()])
		for t in taps:
			var tb := t as Button
			_check(tb.size.x >= 44.0 and tb.size.y >= 44.0, "%s: %s is at least 44x44 (%s)" % [tag, tb.name, str(tb.size)])
			var row := tb.get_parent() as Control
			var rest := row.get_global_rect()
			_check(tb.get_global_rect().position.x >= rest.position.x and tb.get_global_rect().end.x <= rest.end.x + 0.5,
					"%s: %s stays inside its row" % [tag, tb.name])
	# Phone: a row opens the plan first.
	if not wide:
		var row: Button = scene.find_child("Trainee_" + str(a["id"]), true, false)
		_check(row != null, "%s: the first player has a row" % tag)
		if row != null:
			var why: String = await Tap.tap(row)
			await _settle()
			_check(why == "" and bool(scene.get("_showing_detail")), "%s: a row still selects him (%s)" % [tag, why])
	var selected := str(scene.get("_selected"))
	var header: Button = scene.find_child("PlayerNameLink", true, false)
	_check(header != null, "%s: the plan's name header is a tap" % tag)
	if header != null:
		_check(header.size.y >= 44.0, "%s: the name header is thumb tall (%d)" % [tag, int(header.size.y)])
		var why2: String = await Tap.tap(header)
		await _settle()
		var sheet := _sheet(scene)
		var want: String = _db.player_display_name(_gs.list_player(selected))
		_check(why2 == "" and sheet != null and _sheet_name(sheet) == want,
				"%s: tapping the header opens %s's profile (%s, got '%s')" % [tag, want, why2, _sheet_name(sheet)])
		_router.handle_back()
		await _settle()
		_check(_sheet(scene) == null and str(scene.get("_selected")) == selected,
				"%s: Back closes the profile and leaves Training on the same player" % tag)
		_check(is_instance_valid(scene) and scene.is_inside_tree(), "%s: Back stayed on Training" % tag)
	# A row's Profile tap opens that row's player, not the selected one.
	if not wide:
		scene.call("handle_back")
		await _settle()
	var pbtn: Button = scene.find_child("Profile_" + str(other["id"]), true, false)
	_check(pbtn != null, "%s: a row has a Profile tap" % tag)
	if pbtn != null:
		_check(pbtn.size.x >= 44.0 and pbtn.size.y >= 44.0, "%s: the Profile tap is thumb sized (%s)" % [tag, str(pbtn.size)])
		var before := str(scene.get("_selected"))
		var why3: String = await Tap.tap(pbtn)
		await _settle()
		var want2: String = _db.player_display_name(other)
		_check(why3 == "" and _sheet_name(_sheet(scene)) == want2,
				"%s: a row's Profile tap opens %s (%s, got '%s')" % [tag, want2, why3, _sheet_name(_sheet(scene))])
		_check(str(scene.get("_selected")) == before, "%s: the Profile tap does not select him for training" % tag)
		_router.handle_back()
		await _settle()
		_check(_sheet(scene) == null, "%s: Back closes it" % tag)
	# The week's news: a real tap on a name.
	var news: Node = null
	var rises_box := scene.find_child("TrainingRises", true, false)
	if rises_box != null and rises_box.get_child_count() > 0:
		news = rises_box.get_child(0)
	_check(rises_box != null and rises_box.get_child_count() == 2, "%s: both risers are listed by name" % tag)
	_check(news is RichTextLabel and (news as RichTextLabel).get_theme_font("normal_font") == load("res://assets/fonts/ARDSignwriter-Regular.ttf")
			and (news as RichTextLabel).get_theme_font("bold_font") == load("res://assets/fonts/ARDSignwriter-Bold.ttf"),
			"%s: the news names are set in the game's faces" % tag)
	_check(news is RichTextLabel, "%s: the news line carries tappable names" % tag)
	if news is RichTextLabel:
		var opened := await _tap_scan(news, scene)
		var got := _sheet_name(_sheet(scene))
		var names := [_db.player_display_name(a), _db.player_display_name(b)]
		_check(opened and names.has(got), "%s: tapping a name in the news opens his profile (got '%s')" % [tag, got])
		_router.handle_back()
		await _settle()
		_check(_sheet(scene) == null, "%s: Back closes the news profile" % tag)
	scene.queue_free()
	await _settle()


## Touch along the label's lines until a profile opens.
func _tap_scan(label: Control, host: Node) -> bool:
	var r := label.get_global_rect()
	var y := r.position.y + 8.0
	while y < r.end.y:
		var x := r.position.x + 4.0
		while x < r.end.x:
			await _touch(Vector2(x, y), true)
			await _touch(Vector2(x, y), false)
			await _settle(2)
			if _sheet(host) != null:
				return true
			x += 5.0
		y += 14.0
	return false


func _touch(pos: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = down
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await process_frame


func _drag(pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = pos
	d.relative = rel
	Input.parse_input_event(d)
	Input.flush_buffered_events()
	await process_frame


## A swipe that begins on a name scrolls the page and opens nothing.
func _drag_over_name(sz: Vector2i) -> void:
	_gs.reset()
	_gs.start_season("FRE", _db.club_list("FRE"))
	root.size = sz
	var p: Dictionary = _gs.my_list[0]
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	var body := VBoxContainer.new()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = "%s kicks it long." % _nl.url(_db.player_display_name(p), str(p["id"]))
	_nl.wire(r)
	body.add_child(r)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(10, 2000)
	body.add_child(pad)
	var sc: ScrollContainer = _ui.scroll(body)
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(sc)
	await _settle()
	var lr := r.get_global_rect()
	var from := Vector2(lr.position.x + 10.0, lr.position.y + 8.0)
	await _touch(from, true)
	var at := from
	for i in range(8):
		at.y -= 30.0
		await _drag(at, Vector2(0, -30))
	await _touch(at, false)
	await _settle(3)
	_check(sc.scroll_vertical > 60, "a swipe that starts on a name scrolls the page (got %d)" % sc.scroll_vertical)
	_check(_sheet(page) == null, "a swipe that starts on a name does not open a profile")
	# A tap on the same name opens it.
	sc.scroll_vertical = 0
	await _settle(2)
	var tapped := await _tap_scan(r, page)
	_check(tapped and _sheet_name(_sheet(page)) == _db.player_display_name(p), "a tap on the name opens his profile")
	page.queue_free()
	await _settle()


## A hub line that names a player: the tribunal card's case.
func _hub_tribunal(sz: Vector2i) -> void:
	var tag := "hub %dx%d" % [sz.x, sz.y]
	_gs.reset()
	_gs.set_setting("seen_training_intro", true)
	_gs.start_season("MEL", _db.club_list("MEL"))
	_gs.replay_seed = SUITE_SEED
	_gs.tutorials = false
	var p: Dictionary = _gs.my_list[2]
	_gs.last_mro = [{"id": str(p["id"]), "name": _db.player_display_name(p), "club": "MEL",
			"outcome": "suspension", "weeks": 2, "reason": "rough conduct", "round": 1}]
	root.size = sz
	var scene: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _settle()
	var line := scene.find_child("TribunalLine", true, false)
	_check(line is RichTextLabel, "%s: the tribunal case names the player as a tap" % tag)
	if line is RichTextLabel:
		var opened := await _tap_scan(line, scene)
		_check(opened and _sheet_name(_sheet(scene)) == _db.player_display_name(p),
				"%s: tapping his name on the hub opens his profile (got '%s')" % [tag, _sheet_name(_sheet(scene))])
		_router.handle_back()
		await _settle()
		_check(_sheet(scene) == null and is_instance_valid(scene) and scene.is_inside_tree(), "%s: Back closes it and stays on the hub" % tag)
	scene.queue_free()
	await _settle()


## A name tinted by NameInk (match feed, breaks, full time, hub lines) is a tap too;
## inside a button it is not, so the button keeps its own tap.
func _inked_lines(sz: Vector2i) -> void:
	var tag := "inked %dx%d" % [sz.x, sz.y]
	var ink: GDScript = load("res://scripts/ui/NameInk.gd")
	_gs.reset()
	_gs.start_season("FRE", _db.club_list("FRE"))
	root.size = sz
	var p: Dictionary = _gs.my_list[4]
	var who: String = _db.player_display_name(p)
	var index: Dictionary = ink.from_squads([_gs.my_list], ["FRE"])
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	current_scene = page
	var v := VBoxContainer.new()
	page.add_child(v)
	var line: Control = ink.label("Early in the second, %s snaps a goal." % who, index, 16)
	v.add_child(line)
	var held := Button.new()
	held.text = "Pick %s" % who
	held.custom_minimum_size = Vector2(300, 60)
	v.add_child(held)
	var inside: Control = ink.label("%s" % who, index, 16)
	held.add_child(inside)
	await _settle()
	_check(line is RichTextLabel and line.mouse_filter == Control.MOUSE_FILTER_PASS, "%s: a tinted line takes taps on its names" % tag)
	_check(inside is RichTextLabel and inside.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: a tinted name inside a button leaves the tap to the button" % tag)
	var opened := await _tap_scan(line, page)
	_check(opened and _sheet_name(_sheet(page)) == who, "%s: a tap on the tinted name opens %s (got '%s')" % [tag, who, _sheet_name(_sheet(page))])
	_router.handle_back()
	await _settle()
	_check(_sheet(page) == null, "%s: Back closes it" % tag)
	page.queue_free()
	await _settle()


## Phase 2 helpers: a plain label that is a name, and a row with a job of its own.
func _plain_names(sz: Vector2i) -> void:
	var tag := "plain %dx%d" % [sz.x, sz.y]
	_gs.reset()
	_gs.start_season("MEL", _db.club_list("MEL"))
	root.size = sz
	var p: Dictionary = _gs.my_list[5]
	var id := str(p["id"])
	var who: String = _db.player_display_name(p)
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	current_scene = page
	var v := VBoxContainer.new()
	page.add_child(v)
	var label := Label.new()
	label.text = who
	v.add_child(_nl.tappable(label, id))
	var row := Button.new()
	row.custom_minimum_size = Vector2(sz.x - 20, 60)
	row.text = "Row with a job"
	var did := [0]
	row.pressed.connect(func():
		if not _nl.on_profile_tap(row):
			did[0] += 1)
	v.add_child(row)
	var tap: Button = _nl.profile_tap(row, id)
	await _settle()
	var opened := await _tap_scan(label, page)
	_check(opened and _sheet_name(_sheet(page)) == who, "%s: a tap on a plain name opens his profile (got '%s')" % [tag, _sheet_name(_sheet(page))])
	_router.handle_back()
	await _settle()
	_check(_sheet(page) == null, "%s: Back closes it" % tag)
	_check(tap.size.x >= 44.0 and tap.size.y >= 44.0, "%s: the row's Profile tap is thumb sized (%s)" % [tag, str(tap.size)])
	var why: String = await Tap.tap(tap)
	await _settle()
	_check(why == "" and _sheet_name(_sheet(page)) == who, "%s: the row's Profile tap opens his profile (%s)" % [tag, why])
	_check(did[0] == 0, "%s: the row's own job did not run on the Profile tap" % tag)
	_router.handle_back()
	await _settle()
	var why2: String = await Tap.tap(row)
	await _settle()
	_check(why2 == "" and did[0] == 1 and _sheet(page) == null, "%s: the rest of the row still does its job (%s)" % [tag, why2])
	page.queue_free()
	await _settle()


## Names in stacked lines: a thumb that lands in the gap between two lines still opens
## the name on the nearer line, and the two lines' strips never overlap.
func _line_pitch(sz: Vector2i) -> void:
	var tag := "pitch %dx%d" % [sz.x, sz.y]
	_gs.reset()
	_gs.start_season("FRE", _db.club_list("FRE"))
	root.size = sz
	var a: Dictionary = _gs.my_list[0]
	var b: Dictionary = _gs.my_list[1]
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	current_scene = page
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.set_anchors_preset(Control.PRESET_TOP_WIDE)
	page.add_child(v)
	var lines := []
	for p in [a, b]:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.text = "%s kicks it long." % _nl.url(_db.player_display_name(p), str(p["id"]))
		_nl.wire(r)
		v.add_child(r)
		lines.append(r)
	await _settle()
	var r1: Rect2 = (lines[0] as Control).get_global_rect()
	var r2: Rect2 = (lines[1] as Control).get_global_rect()
	var h1 := (lines[0] as Control).get_node_or_null("NameHit") as Control
	var h2 := (lines[1] as Control).get_node_or_null("NameHit") as Control
	_check(h1 != null and h2 != null, "%s: each line has a hit strip" % tag)
	if h1 != null and h2 != null:
		var g1 := h1.get_global_rect()
		var g2 := h2.get_global_rect()
		_check(g1.end.y <= g2.position.y + 0.5, "%s: the strips do not overlap (%s, %s)" % [tag, str(g1), str(g2)])
		_check(g1.end.y > r1.end.y + 3.0 and g2.position.y < r2.position.y - 3.0, "%s: the strips reach into the gap" % tag)
	# Find an x on the text where the exact tap opens him, then tap there but in the gap.
	var x := 0.0
	var found := false
	var xx := r1.position.x + 4.0
	while xx < r1.end.x and not found:
		await _touch(Vector2(xx, r1.position.y + 6.0), true)
		await _touch(Vector2(xx, r1.position.y + 6.0), false)
		await _settle(2)
		if _sheet(page) != null:
			found = true
			x = xx
		xx += 5.0
	_check(found, "%s: the name on the first line opens on the text (line %s, strip %s)" % [tag, str(r1), str(h1.get_global_rect()) if h1 != null else "none"])
	_router.handle_back()
	await _settle()
	if found:
		var below := Vector2(x, r1.end.y + 4.0)
		await _touch(below, true)
		await _touch(below, false)
		await _settle(3)
		_check(_sheet_name(_sheet(page)) == _db.player_display_name(a),
				"%s: a tap in the gap just under the first line opens %s (got '%s')" % [tag, _db.player_display_name(a), _sheet_name(_sheet(page))])
		_router.handle_back()
		await _settle()
		var above := Vector2(x, r2.position.y - 4.0)
		await _touch(above, true)
		await _touch(above, false)
		await _settle(3)
		_check(_sheet_name(_sheet(page)) == _db.player_display_name(b),
				"%s: a tap in the gap just over the second line opens %s (got '%s')" % [tag, _db.player_display_name(b), _sheet_name(_sheet(page))])
		_router.handle_back()
		await _settle()
	page.queue_free()
	await _settle()
