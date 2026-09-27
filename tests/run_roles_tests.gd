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
	var standing: Label = ui.find_child("LineStanding", true, false)
	var digits := RegEx.new()
	digits.compile("\\d")
	_check(standing != null and standing.text.contains("Midfield") and digits.search(standing.text) == null,
			"The side's lines read in words, not engine numbers (%s)" % (standing.text if standing else "-"))
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
	# The synergy rules are one tap away, in full, without progress counts.
	var rules_btn: Button = ui.find_child("SynergyRules", true, false)
	_check(rules_btn != null and rules_btn.size.y >= 44, "A Synergies button opens the rules")
	if rules_btn != null:
		rules_btn.emit_signal("pressed")
		await _settle()
		var guide: Node = ui.find_child("SynergyGuide", true, false)
		var all_rules := guide != null
		if guide != null:
			for key in Traits.SYNERGIES:
				var row: Node = guide.find_child("Synergy_" + str(key), true, false)
				var req: Label = row.find_child("Requires", true, false) if row != null else null
				if req == null or not req.text.begins_with("Requires "):
					all_rules = false
		_check(all_rules, "Every synergy states exactly what it requires")
		var gtext := _screen_text(guide) if guide != null else ""
		var prog := RegEx.new()
		prog.compile("\\d/\\d")
		_check(prog.search(gtext) == null and not gtext.to_lower().contains("one more") and not gtext.contains("%"),
				"The rules carry no progress counts, advice or percentages")
		_check(gtext.contains("Requires 2 Contested bulls on the ground.")
				and gtext.contains("Requires 1 Aerial threat and 1 Crumber in the forward line."),
				"Requirements read in plain words")
		_check(ui.call("handle_back") == true and not is_instance_valid(ui.get("_synergy_overlay")),
				"Back closes the synergy guide first")
		await _settle()
	var recipe := RegEx.new()
	recipe.compile("\\d/\\d [A-Z][a-z]")
	_check(recipe.search(text) == null, "Synergies are not a recipe: no 'one more X' counts")
	_check(not text.to_lower().contains("best available") and not text.contains("best 22"),
			"Auto-pick is described as sensible, not best")
	_check(ui.find_child("SelectionHint", true, false) == null and not text.contains("could tag")
			and not text.contains("coach box"), "Selection surfaces the problem, not the answer")

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
		# Width is what a phone row must fit; a row half-scrolled past the
		# bottom of the list is fine.
		var r: Rect2 = b.get_global_rect()
		if b.is_visible_in_tree() and (r.position.x < -1.0 or r.end.x > viewport.size.x + 1.0):
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
	await _list_tests()


## My list: one line per player, a profile a tap away, Back closes it.
func _list_tests() -> void:
	var ls: Control = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	for b in ls.find_children("*", "Button", true, false):
		if b.text == "Full list":
			b.emit_signal("pressed")
	await _settle()
	var rows := ls.find_children("Row_*", "Button", true, false)
	_check(rows.size() == _state.my_list.size(), "Every listed player has a row (%d)" % rows.size())
	var ids := ls.find_children("RowIdentity", "Label", true, false)
	_check(not ids.is_empty() and not str(ids[0].text).contains("XP"), "Rows say who a player is, not his XP")
	var tall := true
	for r in rows:
		if r.is_visible_in_tree() and r.size.y < 44:
			tall = false
	_check(tall, "Each row is a thumb-sized tap")
	_check(ls.find_children("*", "GridContainer", true, false).is_empty(),
			"No attribute grids on the list itself")
	if not rows.is_empty():
		rows[0].emit_signal("pressed")
		await _settle()
		var prof: Node = ls.find_child("PlayerProfile", true, false)
		_check(prof != null and prof.find_child("ProfileAttributes", true, false) != null
				and prof.find_child("ProfileDevelopment", true, false) != null,
				"A tap opens the profile, attributes and development included")
		_check(ls.call("handle_back") == true, "Back is handled on the profile")
		await _settle()
		_check(ls.find_child("PlayerProfile", true, false) == null, "Back closes the profile")
	ls.queue_free()
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
