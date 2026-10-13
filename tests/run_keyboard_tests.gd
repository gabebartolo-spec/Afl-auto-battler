extends SceneTree
## godot --headless --path . --script tests/run_keyboard_tests.gd
## The phone keyboard, on every screen with a text field (director's clips,
## 2026-10-14, phone on its side: the keyboard opened and closed by itself and
## the letters never reached "Search players").
##
## What a browser does when the keyboard comes up is stood in for here:
##  - the window loses height and keeps its width in pixels (browsers that
##    make room for the keyboard), on a phone on its side, a phone upright and
##    a tablet, the sizes crossing the draft's short-layout line (680 units)
##    and ScreenLayout's 320-unit floor (a phone on its side with the keyboard
##    up is under it);
##  - the letters arrive the way the engine's web keyboard sends them
##    (DisplayServerWeb::_vk_input_text_callback): the whole text of the box
##    is set on whatever has the focus, with its "text changed" signal, then
##    the caret is walked to its place with Right key presses.
## Each time the SAME field must still be there, still have the focus, and the
## text must land in it and filter the list. The web export must have the
## engine's phone keyboard switched on (export_presets.cfg): without it there
## is no keyboard support in a phone's browser at all.
## Not proved here: a real phone's browser. See the PR for the list to try.

const Tap := preload("res://tests/tap.gd")
## [label, a phone's browser, the window, the window with the keyboard up]
const SIZES := [
	["phone on its side", true, Vector2i(800, 360), Vector2i(800, 140)],
	["big phone on its side", true, Vector2i(915, 412), Vector2i(915, 170)],
	["phone upright", true, Vector2i(360, 800), Vector2i(360, 420)],
	["tablet browser", false, Vector2i(1024, 768), Vector2i(1024, 300)],
]

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []


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
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_state.autosave_enabled = false
	_state.save_path = "user://test_keyboard.save"
	_state.settings_path = "user://test_keyboard.cfg"
	_state.show_real_names = false
	_state.delete_saved_career()

	_preset()
	for row in SIZES:
		await _draft(row)
	for row in [SIZES[0], SIZES[2]]:
		await _screen_field(row, "selection", "BuilderSearch", Callable())
		await _screen_field(row, "training", "", Callable())
		await _screen_field(row, "forge", "ForgeClubName", _open_club_form)
		await _screen_field(row, "list", "NicknameField", _open_nickname)

	load("res://scripts/core/ScreenLayout.gd").force_web_phone = false
	load("res://scripts/core/ScreenLayout.gd").force_web = false
	print("Keyboard tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


## The web export has the engine's phone keyboard on. With it off the only
## thing raising a keyboard is the engine's desktop input-method helper, which
## opens and closes by itself and drops what a phone keyboard types
## (godotengine/godot#99602).
func _preset() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(text.contains("html/experimental_virtual_keyboard=true")
			and not text.contains("html/experimental_virtual_keyboard=false"),
			"The web export has the phone keyboard switched on")


## The engine's web keyboard: every letter typed or deleted, the browser's
## text box hands over its whole text. The engine sets it on the control that
## has the focus ("_set_text" with the signal, from the window's text input
## callback) and presses Right once per character to put the caret at the end.
func _web_keyboard(text: String) -> void:
	var owner := root.gui_get_focus_owner()
	if owner == null or not owner.has_method("_set_text"):
		return
	owner.call("_set_text", text, true)
	for i in range(text.length()):
		for down in [true, false]:
			var k := InputEventKey.new()
			k.keycode = KEY_RIGHT
			k.pressed = down
			Input.parse_input_event(k)
	Input.flush_buffered_events()
	await process_frame


## Stand in for the web build: a phone's browser, or a tablet's or PC's.
func _platform(phone: bool) -> void:
	var layout = load("res://scripts/core/ScreenLayout.gd")
	layout.force_web_phone = phone
	layout.force_web = not phone


func _units() -> Vector2:
	return root.get_visible_rect().size


## Keyboard up and down three times: the same field, focused, text kept, and
## the screen's width in units as it was (so nothing is laid out again).
func _cycles(label: String, field: LineEdit, full: Vector2i, up: Vector2i, finder: Callable) -> void:
	var width := _units().x
	var text := field.text
	for cycle in range(3):
		for size in [up, full]:
			var word := "up" if size == up else "down"
			root.size = size
			await _settle()
			var ok := is_instance_valid(field)
			_check(ok, "%s, keyboard %s %d: the field was not freed" % [label, word, cycle])
			if not ok:
				return
			_check(finder.call() == field, "%s, keyboard %s %d: it is the same field" % [label, word, cycle])
			_check(field.has_focus() and field.is_editing(),
					"%s, keyboard %s %d: the field still has the focus" % [label, word, cycle])
			_check(field.text == text, "%s, keyboard %s %d: its text is kept" % [label, word, cycle])
			_check(absf(_units().x - width) < 1.0,
					"%s, keyboard %s %d: the screen is as wide as it was (%s, was %s)"
					% [label, word, cycle, str(_units().x), str(width)])


func _new_draft() -> Control:
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	return ui


func _draft(row: Array) -> void:
	var label := "Draft, %s" % str(row[0])
	var full: Vector2i = row[2]
	var up: Vector2i = row[3]
	_platform(bool(row[1]))
	root.size = full
	await _settle()
	var ui := _new_draft()
	await _settle()
	ui.call("_select_tab", "pool")
	await _settle()
	var finder := func(): return ui.find_child("PlayerSearch", true, false)
	var field: LineEdit = finder.call()
	_check(field != null and field.is_visible_in_tree(), "%s: Search players is on the pool" % label)
	if field == null:
		ui.queue_free()
		return
	var why: String = await Tap.tap(field)
	_check(field.has_focus(), "%s: a real tap on Search players gives it the focus (%s)" % [label, why])
	var key_before: String = ui.get("_layout_key")
	await _cycles(label, field, full, up, finder)
	if not is_instance_valid(field):
		ui.queue_free()
		return
	_check(ui.get("_layout_key") == key_before, "%s: the draft kept its layout" % label)

	# Typing with the keyboard up: the engine's web keyboard sends the box's
	# whole text each time a letter is added or deleted.
	root.size = up
	await _settle()
	for typed in ["v", "va", "van"]:
		await _web_keyboard(typed)
	await create_timer(0.4).timeout
	await _settle()
	_check(is_instance_valid(field) and field.text == "van" and field.caret_column == 3,
			"%s: typing van with the keyboard up fills the field (%s)" % [label, field.text])
	var all_n: int = _state.draft.board("", "", "", "overall", true).size()
	var want: int = _state.draft.board("", "", "van", "overall", true).size()
	_check(str(ui.get("_search")) == "van" and want < all_n,
			"%s: the pool is filtered to van (%s)" % [label, str(ui.get("_search"))])
	_check(str(ui.get("_board_info").text).contains(str(want)),
			"%s: the list shows the %d found (%s)" % [label, want, ui.get("_board_info").text])
	_check(finder.call() == field and field.has_focus(),
			"%s: the list filtering leaves the field alone" % label)
	await _web_keyboard("va")
	await create_timer(0.4).timeout
	await _settle()
	_check(field.text == "va" and str(ui.get("_search")) == "va",
			"%s: deleting a letter reaches the field and the list (%s)" % [label, field.text])
	root.size = full
	await _settle()
	_check(is_instance_valid(field) and field.has_focus() and field.text == "va",
			"%s: keyboard down, the field and its text are as they were" % label)

	# Turning the phone while typing: the draft lays itself out for the new
	# shape, and the search text and the focus come with it.
	root.size = Vector2i(full.y, full.x)
	await _settle()
	var turned: LineEdit = finder.call()
	_check(ui.get("_layout_key") != key_before or bool(row[1]) == false,
			"%s: turning the phone lays the draft out again" % label)
	_check(turned != null and turned.text == "va" and turned.has_focus(),
			"%s: turning the phone keeps the search text and the focus" % label)
	if turned != null:
		turned.release_focus()
	ui.queue_free()
	root.size = full
	await _settle()


func _fresh_career() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_state.tutorials = false


func _open_club_form() -> void:
	var b: Button = current_scene.find_child("ForgeCreateClub", true, false)
	if b != null:
		await Tap.tap(b)
		await _settle()


## A player of your own, his profile, and "Add a nickname".
func _open_nickname() -> void:
	var sheet = load("res://scripts/ui/PlayerSheet.gd")
	var mine: Array = _state.my_list() if _state.has_method("my_list") else []
	var p: Dictionary = mine[0] if not mine.is_empty() else {}
	if p.is_empty():
		for q in _db.club_list("COL"):
			if not _state.list_player(str(q.get("id", ""))).is_empty():
				p = _state.list_player(str(q["id"]))
				break
	if p.is_empty():
		return
	sheet.open(current_scene, p)
	await _settle()
	var edit: Button = current_scene.find_child("NicknameEdit", true, false)
	if edit != null:
		await Tap.tap(edit)
		await _settle()


## Any other screen with a text field: tap it, keyboard up and down, type.
func _screen_field(row: Array, route: String, field_name: String, opener: Callable) -> void:
	var label := "%s, %s" % [route.capitalize(), str(row[0])]
	var full: Vector2i = row[2]
	var up: Vector2i = row[3]
	_platform(bool(row[1]))
	root.size = full
	await _settle()
	_fresh_career()
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	_router.go(route)
	await _settle()
	if opener.is_valid():
		await opener.call()
	var finder := func():
		if field_name != "":
			return current_scene.find_child(field_name, true, false)
		for f in current_scene.find_children("*", "LineEdit", true, false):
			if f.is_visible_in_tree():
				return f
		return null
	var field: LineEdit = finder.call()
	_check(field != null and field.is_visible_in_tree(), "%s: the text field is on the screen" % label)
	if field == null or not field.is_visible_in_tree():
		return
	var why: String = await Tap.tap(field)
	await _settle()
	if not is_instance_valid(field):
		_check(false, "%s: the tap freed the field" % label)
		return
	_check(field.has_focus(), "%s: a real tap gives the field the focus (%s)" % [label, why])
	if not field.has_focus():
		field.grab_focus()
	await _cycles(label, field, full, up, finder)
	if not is_instance_valid(field):
		return
	root.size = up
	await _settle()
	await _web_keyboard("Bo")
	await _settle()
	_check(is_instance_valid(field) and finder.call() == field and field.text == "Bo",
			"%s: typing with the keyboard up lands in the field (%s)"
			% [label, field.text if is_instance_valid(field) else "freed"])
	_check(is_instance_valid(field) and field.has_focus(), "%s: and the field keeps the focus" % label)
	root.size = full
	await _settle()
	_check(is_instance_valid(field) and field.has_focus() and field.text == "Bo",
			"%s: keyboard down, the field and its text are as they were" % label)
	if is_instance_valid(field):
		field.release_focus()
	await _settle()
