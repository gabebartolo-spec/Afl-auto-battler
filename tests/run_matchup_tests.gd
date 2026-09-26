extends SceneTree
## godot --headless --path . --script tests/run_matchup_tests.gd
## Opponent facts (tests/test_matchup.gd), then the weekly hub on a phone:
## this week first, at most three facts, an obvious next action, the ladder at
## full height, and sensible states for a bye, a finished season and results.

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
	var script = load("res://tests/test_matchup.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_matchup.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	await _hub_tests()
	print("Matchup + hub tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _hub_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	for i in range(3):
		_state.advance()
	root.size = Vector2i(420, 860)
	var hub := await _open_hub()
	var week: Control = hub.find_child("ThisWeek", true, false)
	_check(week != null, "The hub leads with this week")
	var opp: Label = hub.find_child("Opponent", true, false)
	var nxt: Dictionary = _state.my_next_opponent()
	_check(opp != null and opp.text.contains(db.club_name(str(nxt["code"]))), "The opponent is named at the top")
	var facts := hub.find_children("Fact_*", "Label", true, false)
	_check(facts.size() <= 3, "At most three facts about them (%d)" % facts.size())
	var expected: Array = _state.opponent_facts(str(nxt["code"]))
	_check(facts.size() == expected.size(), "The hub shows exactly the derived facts")
	var form: Label = hub.find_child("OppFormLine", true, false)
	_check(form != null and not form.text.contains("(") and form.text.contains("on the ladder"),
			"Their standing reads in words (%s)" % (form.text if form else "-"))
	var mine: Label = hub.find_child("FormLine", true, false)
	var rx := RegEx.new()
	rx.compile("[+-]\\d")
	_check(mine != null and rx.search(mine.text) == null, "Your form hides the internal number")
	var actions: Control = hub.find_child("WeekActions", true, false)
	var play := _button(actions, "Play match")
	_check(play != null and play.size.y >= 44, "Play match sits in this week, thumb-sized")
	_check(_button(actions, "Pick the side") != null, "The side is one tap away from the matchup")
	var ladder: Control = hub.find_child("LadderSection", true, false)
	var clubs: int = _state.season.ladder.size()
	_check(ladder != null and ladder.size.y >= clubs * 16, "The ladder gets its full height (%.0f px for %d clubs)" % [ladder.size.y if ladder else 0.0, clubs])
	var footer: Control = hub.find_child("HubFooter", true, false)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(footer != null and viewport.grow(1).encloses(footer.get_global_rect()), "The footer stays on the phone")
	for b in hub.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			_check(false, "Touch target too small: %s" % b.name)

	# Sim a round from the hub: the result says what it means and what's next.
	hub.call("_on_sim_round")
	await _settle()
	var move: Label = hub.find_child("LadderMove", true, false)
	_check(move != null and move.text.ends_with("on the ladder."), "The results say where you now sit (%s)" % (move.text if move else "-"))
	var nl: Label = hub.find_child("NextFixture", true, false)
	_check(nl != null and nl.text.begins_with("Next: Round"), "The results say who is next (%s)" % (nl.text if nl else "-"))
	hub.queue_free()
	await _settle()

	# Your best player injured: the week says so.
	var best: Dictionary = _state.my_list[0]
	for p in _state.my_list:
		if int(p["overall"]) > int(best["overall"]):
			best = p
	best["injury_weeks"] = 2
	hub = await _open_hub()
	var note: Label = hub.find_child("OwnNote_0", true, false)
	_check(note != null and note.text.contains("out injured"), "Your injured star is this week's news")
	best.erase("injury_weeks")
	hub.queue_free()
	await _settle()

	# Run the season out: no fixture, no facts, a clear next step every week.
	var guard := 0
	while not _state.season.is_season_over() and guard < 40:
		_state.advance()
		guard += 1
		if _state.season.is_regular_done() and not _state.season.is_season_over():
			hub = await _open_hub()
			var status: String = _state.my_finals_status()
			var up := hub.find_child("Opponent", true, false) != null
			if not up:
				_check(hub.find_children("Fact_*", "Label", true, false).is_empty(),
						"No fixture, no facts (%s)" % status)
			var acts: Control = hub.find_child("WeekActions", true, false)
			_check(acts != null and acts.get_child_count() > 0, "Finals week has a next action (%s)" % status)
			hub.queue_free()
			await _settle()
	hub = await _open_hub()
	_check(_screen_text(hub).contains("Season complete"), "A finished season says so")
	_check(hub.find_children("Fact_*", "Label", true, false).is_empty(), "No facts once the season is over")
	_check(_button(hub.find_child("WeekActions", true, false), "National Draft") != null,
			"The national draft is the next step")
	hub.queue_free()
	await _settle()


func _open_hub() -> Control:
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	return hub


func _button(parent: Node, text: String) -> Button:
	if parent == null:
		return null
	for b in parent.find_children("*", "Button", true, false):
		if str(b.text).contains(text):
			return b
	return null


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
