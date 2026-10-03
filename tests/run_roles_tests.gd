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
	await _team_changes_tests()
	print("Roles + selection tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _selection_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	var ui := await _open()
	var text := _screen_text(ui)
	var midfield: Node = ui.find_child("Formation_Midfield", true, false)
	var midfield_buttons := midfield.find_children("FormationPlayer_*", "Button", true, false) if midfield != null else []
	_check(midfield != null and midfield_buttons.size() == 6 and text.contains("Wing") and text.contains("Ruck"),
			"The midfield reads as centre square and wings")
	# This week, line against line: both sides in the same words, no numbers.
	var h2h: Node = ui.find_child("HeadToHead", true, false)
	var digits := RegEx.new()
	digits.compile("\\d")
	var h2h_lines: Array = h2h.get_children() if h2h != null else []
	var h2h_ok := h2h_lines.size() == 4
	for l in h2h_lines:
		if digits.search(str(l.text)) != null or not (str(l.text).contains("yours") or str(l.text).contains(" v ")):
			h2h_ok = false
	_check(h2h_ok, "The matchup reads line against line, in words (%s)" %
			" | ".join(h2h_lines.map(func(l): return str(l.text))))
	var mid_line: Label = ui.find_child("H2H_midfield", true, false)
	_check(mid_line != null and mid_line.text.begins_with("Midfield: yours "), "Midfield sets yours against theirs")
	# Their key forwards, and who you put on them.
	var km: Node = ui.find_child("KeyMatchups", true, false)
	_check(km != null and km.find_child("MatchupLine", true, false) != null
			and str(km.find_child("MatchupLine", true, false).text).contains(" on him"),
			"Selection names their key forwards and who is on them")
	var chm: Button = km.find_child("ChangeMatchup", true, false) if km != null else null
	if chm != null:
		chm.emit_signal("pressed")
		await _settle()
		var mc: Node = ui.find_child("MatchupChooser", true, false)
		var defs_b := mc.find_children("Defender_*", "Button", true, false) if mc != null else []
		_check(defs_b.size() >= 2, "Your defenders are offered, each described (%d)" % defs_b.size())
		if defs_b.size() >= 2:
			var last: Button = defs_b[defs_b.size() - 1]
			var want := str(last.name).trim_prefix("Defender_")
			last.emit_signal("pressed")
			await _settle()
			_check(_state.my_matchups.values().has(want), "Your choice is kept for the match")
			var rows: Array = _state.week_matchups(str(_state.my_next_opponent()["code"]))
			var shown := false
			for r in rows:
				if str(r["def"]["id"]) == want:
					shown = true
			_check(shown, "The match-up line follows your choice")
		_state.my_matchups = {}
	# The game plan you take in is on show, and changed here.
	var plan_line: Label = ui.find_child("PlanLine", true, false)
	var plan_before: String = plan_line.text if plan_line != null else ""
	_check(plan_line != null and plan_line.text.begins_with("Game plan: ") and plan_line.text.length() > 11,
			"The game plan you take in is on show (%s)" % (plan_line.text if plan_line else "-"))
	var change: Button = ui.find_child("ChangePlan", true, false)
	_check(change != null and change.size.y >= 44, "The plan can be changed from selection")
	if change != null:
		change.emit_signal("pressed")
		await _settle()
		var chooser: Node = ui.find_child("PlanChooser", true, false)
		var contest: Button = chooser.find_child("ClubPlan_contest", true, false) if chooser != null else null
		_check(contest != null, "The chooser offers the plans")
		if contest != null:
			contest.emit_signal("pressed")
			await _settle()
			_check(_state.club_plan == "contest", "Picking a plan sets the standing plan")
			var note: Label = chooser.find_child("PlanNote", true, false)
			_check(note != null and note.text.contains("clearances"), "The plan says what it does (%s)" % (note.text if note else "-"))
			plan_line = ui.find_child("PlanLine", true, false)
			_check(plan_line != null and plan_line.text != plan_before and plan_line.text == "Game plan: " + contest.text,
					"The plan line follows the pick")
		_check(ui.call("handle_back") == true, "Back closes the plan chooser")
		await _settle()
		_state.set_club_plan("balanced")
	var rows := ui.find_children("RoleLabel", "Label", true, false)
	var formation_players := ui.find_children("FormationPlayer_*", "Button", true, false)
	_check(formation_players.size() == 22, "Every picked player appears in the formation (%d)" % formation_players.size())
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
		var carriers_ok := guide != null
		if guide != null:
			for key in Traits.SYNERGIES:
				var row2: Node = guide.find_child("Synergy_" + str(key), true, false)
				var cl: Label = row2.find_child("Carriers", true, false) if row2 != null else null
				if cl == null or not cl.text.contains("in your side:"):
					carriers_ok = false
				else:
					for c in Traits.carriers(str(key), _state.my_squad().ground):
						for p in c[1]:
							if not cl.text.contains(str(root.get_node("GameDB").player_display_name(p))):
								carriers_ok = false
		_check(carriers_ok, "Each synergy names who in your side carries what it needs")
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
	# The formation card is the position control: tapping one picked player
	# opens only his existing move row below the formation.
	_check(ui.find_children("To_*", "Button", true, false).is_empty(), "No move buttons until you ask for them")
	var player_btn: Button = ui.find_child("FormationPlayer_" + target, true, false)
	_check(player_btn != null and player_btn.size.y >= 44 and player_btn.tooltip_text == "Move him",
			"Each formation player is a thumb-sized move target")
	var sc: ScrollContainer = ui.find_child("SelectionScroll", true, false)
	sc.scroll_vertical = 300
	await _settle()
	var at: int = sc.scroll_vertical
	if player_btn != null:
		player_btn.emit_signal("pressed")
		await _settle()
	var move: Node = ui.find_child("Move_" + target, true, false)
	var to_wing: Button = move.find_child("To_WING", true, false) if move != null else null
	_check(to_wing != null and to_wing.size.y >= 44, "The formation tap opens his move choices")
	_check(ui.find_children("Move_*", "Node", true, false).size() == 1, "Only one player's choices are open")
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var off := false
	for b in ui.find_children("To_*", "Button", true, false):
		var r: Rect2 = b.get_global_rect()
		if b.is_visible_in_tree() and (r.position.x < -1.0 or r.end.x > viewport.size.x + 1.0):
			off = true
	_check(not off, "The move choices fit a phone row")
	if to_wing != null:
		to_wing.emit_signal("pressed")
		await _settle()
		sc = ui.find_child("SelectionScroll", true, false)
		_check((_state.my_selection()["WING"] as Array).has(target), "Moving a player to the wing names him there")
		_check(_screen_text(ui).contains("3 named"), "An over-full wing group says so")
		_check(ui.find_children("To_*", "Button", true, false).is_empty(), "The choices close after a move")
		_check(sc != null and sc.scroll_vertical == at, "A move keeps your place in the list (%d, was %d)" % [
				sc.scroll_vertical if sc else -1, at])
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
	await _selection_profile_tests()
	await _ladder_tests()


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


## Selection: a tap on a player opens his profile over the list, and closing
## it leaves the side, the mode and your place in the list as they were.
func _selection_profile_tests() -> void:
	_state.set_selection(_state.current_side())
	var before: Dictionary = _state.my_selection().duplicate(true)
	var ui := await _open()
	var sc: ScrollContainer = ui.find_child("SelectionScroll", true, false)
	sc.scroll_vertical = 600
	await _settle()
	var at: int = sc.scroll_vertical
	var target: Button = null
	for b in ui.find_children("Profile_*", "Button", true, false):
		if b.is_visible_in_tree() and b.get_global_rect().position.y > 200:
			target = b
			break
	_check(target != null and target.size.y >= 44, "A player's name area is a thumb-sized tap")
	if target != null:
		target.emit_signal("pressed")
		await _settle()
		var prof: Node = ui.find_child("PlayerProfile", true, false)
		_check(prof != null and prof.find_child("ProfileAttributes", true, false) != null,
				"The tap opens his profile over Selection")
		_check(ui.call("handle_back") == true, "Back is handled on the profile")
		await _settle()
		_check(ui.find_child("PlayerProfile", true, false) == null and _state.my_selection() == before
				and sc.scroll_vertical == at and is_instance_valid(sc),
				"Back returns to Selection as it was: same side, same place (%d)" % sc.scroll_vertical)
	# On a small phone the rating and the position button never overlap.
	root.size = Vector2i(360, 740)
	await _settle()
	var clash := ""
	for ov in ui.find_children("Ovr", "Label", true, false):
		var row: Node = ov.get_parent()
		for sb in row.get_children():
			if str(sb.name).begins_with("Slot_") and ov.get_global_rect().intersects(sb.get_global_rect()):
				clash = str(sb.name)
	_check(clash == "", "Rating and position button sit side by side at 360 wide (%s)" % clash)
	root.size = Vector2i(420, 860)
	ui.queue_free()
	await _settle()
	_state.set_selection({})


## The ladder first, then the Coleman race one goalkicker to a row, all on
## a phone screen without scrolling.
func _ladder_tests() -> void:
	for i in range(3):
		_state.advance()
	for sz in [Vector2i(420, 860), Vector2i(360, 740)]:
		root.size = sz
		var lad: Control = load("res://scenes/LadderScene.tscn").instantiate()
		root.add_child(lad)
		await _settle()
		var box: Node = lad.find_child("ColemanLeaders", true, false)
		var rows := lad.find_children("Coleman_*", "HBoxContainer", true, false)
		var leaders: Array = _state.coleman_leaders(5)
		_check(box != null and rows.size() == leaders.size(), "The Coleman race has a row per leader (%d)" % rows.size())
		var view := Rect2(Vector2.ZERO, Vector2(sz)).grow(1)
		var fits := true
		for r in rows:
			if not view.encloses(r.get_global_rect()):
				fits = false
		_check(fits, "The Coleman race fits under the ladder without scrolling (%dx%d)" % [sz.x, sz.y])
		if not rows.is_empty():
			var words := ""
			for l in rows[0].find_children("*", "Label", true, false):
				words += str(l.text) + "|"
			_check(words.contains(str(int(leaders[0]["goals"]))), "A row shows his goals (%s)" % words)
		lad.queue_free()
		await _settle()
	root.size = Vector2i(420, 860)


## The team sheet: after a match, a player who is injured is out, and the
## player who comes in is named in for him.
func _team_changes_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.autosave_enabled = false
	_state.start_season("COL", db.club_list("COL"))
	var before := await _open()
	_check(before.find_child("TeamChanges", true, false) == null, "No team changes before the first match")
	before.queue_free()
	_state.advance()
	_check(not _state.last_side.is_empty(), "Your last match's side is remembered (%d)" % _state.last_side.size())
	var hurt: Dictionary = _state.list_player(str(_state.last_side[0]))
	hurt["injury_weeks"] = 2
	var ch: Dictionary = _state.week_changes()
	var out_ok := false
	for o in ch["outs"]:
		if str(o["id"]) == str(hurt["id"]) and str(o["why"]) == "injured, 2 wks":
			out_ok = true
	_check(out_ok, "An injured player is out, with how long (%s)" % str(ch["outs"]))
	var for_ok := false
	for i in ch["ins"]:
		if str(i["for"]) == str(hurt["id"]):
			for_ok = true
	_check(for_ok, "Someone comes in for him (%s)" % str(ch["ins"]))
	var ui := await _open()
	var line: Label = ui.find_child("TeamChanges", true, false)
	var name: String = db.player_display_name(hurt)
	_check(line != null and line.text.contains("Outs: ") and line.text.contains(name)
			and line.text.contains("for " + name), "Selection reads the team sheet (%s)" % (line.text if line else "-"))
	var said := 0
	for l in ui.find_children("*", "Label", true, false):
		if str(l.text).contains(name) and str(l.text).contains("injur"):
			said += 1
	_check(said == 1, "His injury is said once, on the team sheet (%d)" % said)
	ui.queue_free()
	var kid := {"id": "KID", "career": {"games": 0, "goals": 0, "stints": [], "through": 2026, "unknown": []}}
	_check(_state.games_note(kid) == "debut", "A player yet to play a senior game is on debut")
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
