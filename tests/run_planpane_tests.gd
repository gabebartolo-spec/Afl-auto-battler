extends SceneTree
## godot --headless --path . --script tests/run_planpane_tests.gd
## The break's Game plan, Pep talk and Rotations panes: the plan under the
## buttons as short separate lines (what it does, Gain, Cost, what it beats,
## who makes it work), and the "Calls so far" record under each pane.

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
	_state.replay_seed = 2027
	await _plan_lines()
	await _calls_record()
	print("Plan pane tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## Every plan's blurb has the parts it should, none of them grey or long.
func _plan_lines() -> void:
	var UK = load("res://scripts/ui/UiKit.gd")
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	_state.set_club_plan("defensive")
	_check(_state.prepare_interactive_match(), "A live match is prepared (plan lines)")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The pre-bounce box opens (plan lines)")
	if box != null:
			# The plan under the buttons: short separate lines, each plan with its parts.
			for pk in ["balanced", "attacking", "defensive", "contest", "controlled", "through_stars"]:
				var pb: Button = box.find_child("PlanPicker_" + pk, true, false)
				if pb == null:
					_check(false, "Plan button %s exists" % pk)
					continue
				pb.emit_signal("pressed")
				await _settle()
				var pn: Node = box.find_child("PlanNote", true, false)
				_check(pn != null and pn is VBoxContainer and pn.find_child("PlanDoes", true, false) != null,
						"The plan blurb is separate lines with a lead line (%s)" % pk)
				if pn == null:
					continue
				_check((pk == "balanced") == (pn.find_child("PlanGain", true, false) == null)
						and (pk == "balanced") == (pn.find_child("PlanCost", true, false) == null),
						"Every plan but Balanced has Gain and Cost rows (%s)" % pk)
				_check((pk in ["attacking", "defensive", "controlled"]) == (pn.find_child("PlanBeats", true, false) != null),
						"The beats line shows for the plans with a counter (%s)" % pk)
				_check((pk == "balanced") == (pn.find_child("PlanBest", true, false) == null),
						"The best-for-it line names players (%s)" % pk)
				var longest := 0
				for lb in pn.find_children("*", "Label", true, false):
					longest = maxi(longest, (lb as Label).text.split(" ", false).size())
					_check((lb as Label).get_theme_color("font_color") != UK.MUTED, "Blurb text is not in muted grey (%s)" % pk)
				_check(longest <= 22, "No blurb line runs over 22 words (%s: %d)" % [pk, longest])
			var back: Button = box.find_child("PlanPicker_defensive", true, false)
			back.emit_signal("pressed")
			await _settle()
	m.queue_free()
	await _settle()


## The record of calls under the Game plan, Pep talk and Rotations: nothing
## before the first bounce, then a line for each quarter played, in order,
## with the right clubs and calls (theirs only for the game plan).
func _calls_record() -> void:
	var db = root.get_node("GameDB")
	var Cr = load("res://scripts/sim/CoachReport.gd")
	var UK = load("res://scripts/ui/UiKit.gd")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		_state.reset()
		_state.start_season("MEL", db.club_list("MEL"))
		_check(_state.prepare_interactive_match(), "A live match is prepared (calls record %s)" % str(sz))
		var sim = _state.pending_sim
		var mine := int(sim.moment_side)
		var pre: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(pre)
		await _settle()
		_check(pre.find_child("CallsRecord_gameplan", true, false) == null and pre.find_child("CallsRecord_pep", true, false) == null,
				"No record, and no header, before the first bounce (%s)" % str(sz))
		pre.queue_free()
		await _settle()
		var plans := ["attacking", "defensive"]
		var peps := ["fire_up", "heat"]
		var rots := ["hard", "stars"]
		for q in range(2):
			sim.set_tactics(mine, {"gameplan": plans[q], "pep": peps[q], "focus_id": "", "tag_id": ""})
			sim.set_rotation_policy(mine, rots[q])
			sim.run_quarter()
			if q == 0:
				root.size = sz
				var m0: Control = load("res://scenes/MatchScene.tscn").instantiate()
				root.add_child(m0)
				await _settle()
				_check(m0.find_child("CallsRecord_gameplan", true, false) != null,
						"After Q1 the record appears (%s)" % str(sz))
				m0.queue_free()
				await _settle()
		root.size = sz
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		var other := 1 - mine
		var mine_code := str(sim.squads[mine].code)
		var other_code := str(sim.squads[other].code)
		for kind in ["gameplan", "pep", "rotation"]:
			var rec: Node = m.find_child("CallsRecord_" + kind, true, false)
			_check(rec != null, "A record of %s calls shows at half time (%s)" % [kind, str(sz)])
			if rec == null:
				continue
			for q in range(2):
				var row: Node = rec.find_child("CallsRecordRow_Q%d" % (q + 1), true, false)
				_check(row != null, "Row for Q%d (%s, %s)" % [q + 1, kind, str(sz)])
				if row == null:
					continue
				var names := row.find_children("ClubName*", "Label", true, false)
				var words := row.find_children("CallWords*", "Label", true, false)
				var want_clubs: Array = [db.club_short(mine_code)] if kind != "gameplan" 						else [db.club_short(mine_code), db.club_short(other_code)]
				var got_clubs := []
				for n in names:
					got_clubs.append((n as Label).text.trim_suffix(": "))
				_check(got_clubs == want_clubs, "Right clubs on Q%d %s (%s)" % [q + 1, kind, str(got_clubs)])
				var want_mine: String = Cr.plan_label(plans[q]) if kind == "gameplan" 						else (Cr.pep_label(peps[q]) if kind == "pep" else str(ROTATION_WORDS[rots[q]]))
				_check(words.size() == want_clubs.size() and (words[0] as Label).text == want_mine,
						"Right call on Q%d %s (%s)" % [q + 1, kind, (words[0] as Label).text if not words.is_empty() else "-"])
				if kind == "gameplan":
					var theirs: String = Cr.plan_label(str(((sim.tactics_history[q]["plans"] as Array)[other] as Dictionary).get("gameplan", "balanced")))
					_check(words.size() == 2 and (words[1] as Label).text == theirs, "Their plan in Q%d is theirs (%s)" % [q + 1, theirs])
					_check(names.size() == 2 and (names[0] as Label).get_theme_color("font_color") == UK.club_name_colour(UK.club_ink(mine_code)),
							"Club names wear club colour (Q%d)" % [q + 1])
		m.queue_free()
		await _settle()


const ROTATION_WORDS := {"hard": "Freshness", "normal": "Balanced", "stars": "Key players"}


func _settle() -> void:
	for i in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
