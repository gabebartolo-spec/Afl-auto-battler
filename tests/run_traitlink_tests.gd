extends SceneTree
## godot --headless --path . --script tests/run_traitlink_tests.gd
## A trait's name explains itself (director, 2026-10-19: "can we hover on traits and
## it shows us their effects?"). Hover gives the effect as a tooltip; a real touch on
## the name opens a small sheet with the exact effect and what earns it; a synergy's
## sheet says what it needs. Close, a tap outside and Back all return to the screen.
## Real touches at 390x844 and 1280x720.

const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2027

var _checks := 0
var _failures: Array = []
var _gs: Node
var _db: Node
var _router: Node
var _tl: GDScript
var _ps: GDScript


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
	_tl = load("res://scripts/ui/TraitLink.gd")
	_ps = load("res://scripts/ui/PlayerSheet.gd")
	_gs = root.get_node("GameState")
	_db = root.get_node("GameDB")
	_router = root.get_node("Router")
	_gs.autosave_enabled = false
	_gs.save_path = "user://test_traitlink.save"
	_gs.settings_path = "user://test_traitlink.cfg"
	_gs.show_real_names = false
	_words()
	for club in ["FRE", "MEL"]:
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			await _sheet_flow(club, sz)
	await _line_flow(Vector2i(390, 844))
	await _line_flow(Vector2i(1280, 720))
	await _training_news(Vector2i(390, 844))
	print("Trait link tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)


## Every trait and synergy has a name that can be tapped and words that explain it.
func _words() -> void:
	var all: Dictionary = _tl.names()
	var want := Traits.DEFS.size() + Traits.SYNERGIES.size() + Traits.EARNED.size() + 1
	_check(all.size() == want, "every trait and synergy is a tappable name (%d of %d)" % [all.size(), want])
	for shown in all:
		var key := str(all[shown])
		var rows: Array = _tl.sheet_lines(key)
		_check(str(rows[0]) == str(shown) and str(rows[2]) != "", "%s: the sheet names it and says what it does" % key)
		_check(_tl.tip(key) == Traits.text(key) and Traits.text(key) != "", "%s: the hover is its exact effect" % key)
		_check(_tl.markup("Has %s here." % shown).contains("[url=trait:%s]" % key), "%s: found in a sentence" % key)
		if Traits.DEFS.has(key):
			_check(_tl.earn_text(key) != "", "%s: says what earns it" % key)
		if Traits.SYNERGIES.has(key):
			_check(rows.has(Traits.requirement_text(key)), "%s: says exactly what it needs" % key)
	# The longer name wins ("Lockdown unit" is the synergy, not the trait inside it).
	_check(_tl.markup("Lockdown unit").contains("trait:lockdown_unit"), "Lockdown unit is not read as Lockdown")
	_check(_tl.markup("Lockdowns").find("[url") < 0, "a name inside a longer word is left alone")
	_check(_tl.earn_text("hothead").contains("20"), "Hothead says its line")
	_check(_tl.earn_text("wet_weather").contains("78"), "Wet-weather says its line")


func _overlay(host: Node, name: String) -> Control:
	return host.get_node_or_null(name) as Control


func _touch(pos: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = down
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await process_frame


## A player with traits, on a player sheet over a screen.
func _sheet_flow(club: String, sz: Vector2i) -> void:
	var tag := "%s %dx%d" % [club, sz.x, sz.y]
	_gs.reset()
	_gs.start_season(club, _db.club_list(club))
	_gs.replay_seed = SUITE_SEED
	root.size = sz
	var host := Control.new()
	host.name = "Screen"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	current_scene = host
	var p: Dictionary = {}
	for q in _gs.my_list:
		if not Traits.of(q).is_empty():
			p = q
			break
	_check(not p.is_empty(), "%s: someone on the list has a trait" % tag)
	if p.is_empty():
		host.queue_free()
		return
	_ps.open(host, p)
	await _settle()
	for t in Traits.of(p):
		var key := str(t)
		var line := host.find_child("Trait_" + key, true, false) as Control
		_check(line != null, "%s: %s shows on his sheet" % [tag, key])
		if line == null:
			continue
		_check(line.tooltip_text == Traits.text(key), "%s: hovering %s shows its effect" % [tag, key])
		await Tap.tap(line)
		await _settle()
		var sheet := _overlay(host, _tl.SHEET_NAME)
		_check(sheet != null, "%s: a touch on %s opens its sheet" % [tag, key])
		if sheet == null:
			continue
		var title := sheet.find_child("TraitTitle", true, false) as Label
		var effect := sheet.find_child("TraitEffect", true, false) as Label
		_check(title != null and title.text == Traits.label(key), "%s: the sheet is %s" % [tag, key])
		_check(effect != null and effect.text == Traits.text(key), "%s: the sheet gives its exact effect" % tag)
		_check(_overlay(host, "PlayerProfile") != null, "%s: his profile stays underneath" % tag)
		# Close.
		var close := sheet.find_child("TraitClose", true, false) as Button
		var why: String = await Tap.tap(close)
		await _settle()
		_check(why == "" and _overlay(host, _tl.SHEET_NAME) == null, "%s: Close puts the sheet away (%s)" % [tag, why])
		# Back.
		_tl.open(line, key)
		await _settle()
		_check(_overlay(host, _tl.SHEET_NAME) != null, "%s: it opens again" % tag)
		_router.handle_back()
		await _settle()
		_check(_overlay(host, _tl.SHEET_NAME) == null and _overlay(host, "PlayerProfile") != null,
				"%s: Back closes the trait and leaves his profile" % tag)
		# A tap outside.
		_tl.open(line, key)
		await _settle()
		await _touch(Vector2(3, 3), true)
		await _touch(Vector2(3, 3), false)
		await _settle()
		_check(_overlay(host, _tl.SHEET_NAME) == null, "%s: a tap outside closes it" % tag)
		break
	host.queue_free()
	await _settle()


## A synergy named in a sentence: a real touch along the line finds it.
func _line_flow(sz: Vector2i) -> void:
	var tag := "line %dx%d" % [sz.x, sz.y]
	root.size = sz
	var host := Control.new()
	host.name = "Screen"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	current_scene = host
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	host.add_child(box)
	var l: RichTextLabel = _tl.line("Your side has: %s." % Traits.with_effect("engine_room"), 13, Color.WHITE)
	box.add_child(l)
	await _settle()
	var opened := await _scan(l, host)
	var sheet := _overlay(host, _tl.SHEET_NAME)
	_check(opened and sheet != null, "%s: a touch on the synergy's name opens it" % tag)
	if sheet != null:
		var all := ""
		for c in sheet.find_children("*", "Label", true, false):
			all += (c as Label).text + "\n"
		_check(all.contains("Engine room") and all.contains("+5% stoppage wins."), "%s: it says what it does" % tag)
		_check(all.contains(Traits.requirement_text("engine_room")), "%s: it says what it needs" % tag)
		_router.handle_back()
		await _settle()
		_check(_overlay(host, _tl.SHEET_NAME) == null, "%s: Back closes it" % tag)
	# Words that are not names do nothing.
	var plain: RichTextLabel = _tl.line("Nothing to see here.", 13, Color.WHITE)
	box.add_child(plain)
	await _settle()
	_check(not await _scan(plain, host), "%s: a line with no trait in it opens nothing" % tag)
	host.queue_free()
	await _settle()


func _training_news(sz: Vector2i) -> void:
	var tag := "news %dx%d" % [sz.x, sz.y]
	_gs.reset()
	_gs.set_setting("seen_training_intro", true)
	_gs.start_season("FRE", _db.club_list("FRE"))
	_gs.replay_seed = SUITE_SEED
	var a: Dictionary = _gs.my_list[0]
	_gs.last_training_report = {"count": 1, "label": "Round 1", "auto": {
			"rises": [], "traits": [[str(a["id"]), "sharpshooter"]], "at_pot": []}}
	root.size = sz
	var scene: Control = load("res://scenes/TrainingScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	current_scene = scene
	var news := scene.find_child("TrainingNews", true, false)
	_check(news is RichTextLabel and (news as RichTextLabel).text.contains("[url=trait:sharpshooter]"),
			"%s: the news line makes the unlocked trait a tap" % tag)
	_check(news is RichTextLabel and (news as RichTextLabel).text.contains("[url=player:" + str(a["id"]) + "]"),
			"%s: and still makes his name a tap" % tag)
	if news is RichTextLabel:
		var seen := await _scan(news, scene)
		var sheet := _overlay(scene, _tl.SHEET_NAME)
		var profile := _overlay(scene, "PlayerProfile")
		_check(seen and (sheet != null or profile != null), "%s: a touch along the line opens something" % tag)
		# A touch on the trait word itself.
		_router.handle_back()
		await _settle()
		_router.handle_back()
		await _settle()
		var r := news as RichTextLabel
		var parsed := r.get_parsed_text()
		var idx := parsed.find("Sharpshooter")
		_check(idx >= 0, "%s: the line says Sharpshooter" % tag)
		if idx >= 0:
			var font := r.get_theme_font("bold_font")
			var size := r.get_theme_font_size("normal_font_size")
			var line_start := idx
			while line_start > 0 and r.get_character_line(line_start - 1) == r.get_character_line(idx):
				line_start -= 1
			var x0 := font.get_string_size(parsed.substr(line_start, idx - line_start), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var w := font.get_string_size("Sharpshooter", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var at := r.get_global_rect().position + Vector2(x0 + w * 0.5, 8.0 + 18.0 * r.get_character_line(idx))
			await _touch(at, true)
			await _touch(at, false)
			await _settle()
			var s2 := _overlay(scene, _tl.SHEET_NAME)
			_check(s2 != null and (s2.find_child("TraitTitle", true, false) as Label).text == "Sharpshooter",
					"%s: a touch on the word Sharpshooter opens its sheet" % tag)
			_router.handle_back()
			await _settle()
			_check(_overlay(scene, _tl.SHEET_NAME) == null, "%s: Back closes it" % tag)
	scene.queue_free()
	await _settle()


## Touch along the label's lines until a sheet (trait or profile) opens.
func _scan(label: Control, host: Node) -> bool:
	var r := label.get_global_rect()
	var y := r.position.y + 8.0
	while y < r.end.y:
		var x := r.position.x + 4.0
		while x < r.end.x:
			await _touch(Vector2(x, y), true)
			await _touch(Vector2(x, y), false)
			await _settle(2)
			if _overlay(host, _tl.SHEET_NAME) != null or _overlay(host, "PlayerProfile") != null:
				return true
			x += 5.0
		y += 14.0
	return false
