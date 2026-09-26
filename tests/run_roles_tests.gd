extends SceneTree
## godot --headless --path . --script tests/run_roles_tests.gd
## Roles (tests/test_roles.gd), then the Selection screen on a phone: the
## wings as their own group, a football identity on every row, fit notes
## where they matter, a Wing move, and old sides split into wings.

var _state: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	var script = load("res://tests/test_roles.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_roles.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	await _selection_tests()
	print("Roles + selection tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _selection_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	var ui := await _open()
	var text := _screen_text(ui)
	_check(text.contains("Wings  2/2") and text.contains("Midfield  3/3"), "The midfield reads as centre square and wings")
	var rows := ui.find_children("RoleLabel", "Label", true, false)
	_check(rows.size() >= 22, "Every player row says who he is (%d)" % rows.size())
	var rx := RegEx.new()
	rx.compile("%")
	var leak := false
	for l in rows + ui.find_children("Fit", "Label", true, false):
		if rx.search(str(l.text)) != null:
			leak = true
	_check(not leak, "No percentages on the rows")
	_check(ui.find_child("SelectionWeek", true, false) != null, "Selection shows this week's opponent")

	# My selection: a Wing button on every row; moving a player there works.
	var mine: Button = ui.find_child("MySelection", true, false)
	mine.emit_signal("pressed")
	await _settle()
	var sel: Dictionary = _state.my_selection()
	_check((sel.get("WING", []) as Array).size() == 2, "My selection starts with two wings named")
	var target := ""
	for id in sel.get("MID", []):
		target = str(id)
		break
	var move: Node = ui.find_child("Move_" + target, true, false)
	var to_wing: Button = move.find_child("To_WING", true, false) if move != null else null
	_check(to_wing != null and to_wing.size.y >= 40, "Each row can move a player to the wing")
	if to_wing != null:
		to_wing.emit_signal("pressed")
		await _settle()
		_check((_state.my_selection()["WING"] as Array).has(target), "Moving a player to the wing names him there")
		_check(_screen_text(ui).contains("3 named"), "An over-full wing group says so")
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var off := false
	for b in ui.find_children("To_*", "Button", true, false):
		if b.is_visible_in_tree() and not viewport.grow(1).encloses(b.get_global_rect()) and b.get_global_rect().position.y < viewport.size.y:
			off = true
	_check(not off, "The move buttons fit a phone row")
	ui.queue_free()
	await _settle()

	# A side saved before wings existed is split on first open.
	var old: Dictionary = _state.current_side()
	old["MID"] = (old["MID"] as Array) + (old["WING"] as Array)
	old.erase("WING")
	_state.set_selection(old)
	ui = await _open()
	var fixed: Dictionary = _state.my_selection()
	_check((fixed.get("WING", []) as Array).size() == 2 and (fixed.get("MID", []) as Array).size() == 3,
			"An old five-man midfield is split into three and two wings")
	ui.queue_free()
	await _settle()


func _open() -> Control:
	var ui: Control = load("res://scenes/SelectionScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	return ui


func _screen_text(node: Node) -> String:
	var out := ""
	for n in node.find_children("*", "Label", true, false):
		out += str(n.text) + "\n"
	return out


func _settle() -> void:
	for i in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
