extends SceneTree
## godot --headless --path . --script tests/run_matchday_tests.gd
## Matchday words (tests/test_matchday.gd), then your match on a phone: the
## score, clock and leader at a glance, a feed of what matters, the breaks
## as "what happened, then your calls", and Back closing a report first.

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
	var script = load("res://tests/test_matchday.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_matchday.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	for sz in [Vector2i(420, 860), Vector2i(360, 740)]:
		await _phone_match(sz)
	print("Matchday + match screen tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _phone_match(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared (%s)" % tag)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var viewport := Rect2(Vector2.ZERO, Vector2(sz))

	# Before the bounce: the calls, no report, no numbers from the engine.
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The match opens on your calls (%s)" % tag)
	var text := _text(box)
	_check(not text.contains("pts") and not text.contains("Expected points") and not text.contains("%"),
			"The first coach box shows no engine numbers (%s)" % tag)
	for n in ["PlanPicker", "TagPicker", "FocusPicker", "PepPicker", "RotationPicker", "LegsView", "TagNote"]:
		_check(box.find_child(n, true, false) != null, "The coach box keeps %s (%s)" % [n, tag])
	_check(not text.to_lower().contains("recommend") and not text.to_lower().contains("should"),
			"The coach box never advises (%s)" % tag)
	var start: Button = box.find_child("StartQuarter", true, false)
	_check(start != null and start.size.y >= 44, "Starting is one thumb-sized tap (%s)" % tag)

	# The calls are taps, not dropdowns.
	_check(box.find_children("*", "OptionButton", true, false).is_empty(), "No dropdowns at the break (%s)" % tag)
	# Tag: a few players first, "Other player..." for the rest of their side.
	var tag_box: Node = box.find_child("TagPicker", true, false)
	var tag_choices := tag_box.find_children("TagPickerGrid_*", "Button", true, false)
	_check(tag_choices.size() >= 3 and tag_choices.size() <= 6, "Tag shows a few players, not a wall (%d, %s)" % [tag_choices.size(), tag])
	var tag_other: Button = tag_box.find_child("TagPickerOther", true, false)
	_check(tag_other != null, "Every tag_other player is a tap away (%s)" % tag)
	var opp_side: Array = m.get("_res")["roster"][1 - int(m.get("_my_side"))]
	if tag_other != null:
		tag_other.emit_signal("pressed")
		await _settle()
		var sheet: Node = m.find_child("PlayerSheet", true, false)
		_check(sheet != null and sheet.find_children("Sheet_*", "Button", true, false).size() == opp_side.size(),
				"The full list has their whole side on the ground (%s)" % tag)
		var backed: bool = m.call("handle_back")
		await _settle()
		_check(backed and m.find_child("PlayerSheet", true, false) == null
				and m.find_child("CoachBox", true, false) != null, "Back closes the list and keeps the break (%s)" % tag)
		tag_other.emit_signal("pressed")
		await _settle()
		sheet = m.find_child("PlayerSheet", true, false)
		var last: Button = sheet.find_children("Sheet_*", "Button", true, false).back()
		var picked_id := str(last.name).trim_prefix("Sheet_")
		last.emit_signal("pressed")
		await _settle()
		_check(box.find_child("TagPickerGrid_" + picked_id, true, false) != null,
				"A player picked from the list joins the choices (%s)" % tag)
	var small_calls := []
	for b in box.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			small_calls.append(b.name)
	_check(small_calls.is_empty(), "Every call is thumb-sized (%s: %s)" % [tag, str(small_calls)])
	start.emit_signal("pressed")
	await _settle()
	_check(m.find_child("CoachBox", true, false) == null, "The box closes and play starts (%s)" % tag)
	var setup: Label = m.find_child("SetupLine", true, false)
	_check(setup != null and setup.visible and setup.text.contains("tagging "),
			"The live screen says your gameplan and who you are tagging (%s: %s)" % [tag, setup.text if setup else "-"])
	var clock: Label = m.find_child("Clock", true, false)
	var lead: Label = m.find_child("LeadLine", true, false)
	_check(clock != null and clock.text.begins_with("Q1") and viewport.encloses(clock.get_global_rect()),
			"The clock is on screen (%s)" % tag)
	_check(lead != null and lead.text == "Scores level", "Who leads, before a score: level (%s)" % tag)

	# Play the quarter out fast, watching the feed.
	var pitch = m.get("_pitch")
	pitch.set_speed(8.0)
	var guard := 0
	# Drive playback in fixed steps, not wall-clock frames, so a slow runner
	# plays the same quarter (long frames release the same events: see
	# test_match_visual).
	while m.find_child("CoachBox", true, false) == null and guard < 4000:
		if pitch.playing:
			pitch._process(0.25)
		await process_frame
		guard += 1
		var card = m.find_child("MomentCard", true, false)
		if card != null:
			var pick: Button = card.find_child("Moment_0", true, false)
			if pick != null:
				pick.emit_signal("pressed")
			await _settle()
	box = m.find_child("CoachBox", true, false)
	_check(box != null, "Quarter time opens the break (%s)" % tag)
	var feed: Node = m.find_child("Feed", true, false)
	var feed_text := _text(feed)
	_check(not feed_text.contains(" def ") and not feed_text.contains("defeated"),
			"No result words in the live feed (%s)" % tag)
	for w in ["marks", "handballs", "tackles", "clanger", "rebounds it", "sends it inside 50"]:
		_check(not feed_text.contains(w), "Routine play stays off the feed: %s (%s)" % [w, tag])
	_check(feed_text.contains("Quarter time: "), "The feed calls quarter time (%s)" % tag)
	var g: Array = m.get("_shown_goals")
	var shown := 0
	for c in feed.get_children():
		if str(c.get_meta("feed_kind", "")) == "goal":
			shown += 1
	_check(shown == int(g[0]) + int(g[1]), "Every goal has its own row (%d of %d, %s)" % [shown, int(g[0]) + int(g[1]), tag])
	var score_text: String = lead.text
	var sc := [int(g[0]) * 6 + int(m.get("_shown_behinds")[0]), int(g[1]) * 6 + int(m.get("_shown_behinds")[1])]
	_check(score_text == ("Scores level" if sc[0] == sc[1] else "%s by %d" % [
			db.club_short(str(m.get("_res")["home"] if sc[0] > sc[1] else m.get("_res")["away"])), absi(sc[0] - sc[1])]),
			"The lead line matches the scoreboard (%s: %s)" % [tag, score_text])

	# The break: the score, what happened, then the calls.
	_check(box.find_child("BreakScore", true, false) != null and box.find_child("QuarterFacts", true, false) != null,
			"Quarter time says the score and what happened (%s)" % tag)
	var bt := _text(box)
	_check(not bt.contains("pts") and not bt.contains("Expected points") and not bt.contains(" def ")
			and not bt.contains("defeated"), "The break shows no engine numbers or result words (%s)" % tag)
	_check(bt.contains("Tag on ") and box.find_child("CallsDid", true, false) != null,
			"The break says what your calls did, your tag among them (%s)" % tag)
	_check(bt.contains("What's happening"), "The break leads with what is happening (%s)" % tag)
	var more_calls: Control = box.find_child("MoreCalls", true, false)
	var more_btn: Button = box.find_child("MoreCallsToggle", true, false)
	_check(more_calls != null and not more_calls.visible and more_btn != null and box.find_child("PlanPicker", true, false).is_visible_in_tree()
			and box.find_child("TagPicker", true, false).is_visible_in_tree(),
			"The plan and the tag are in view; the rest of the calls are one tap away (%s)" % tag)
	if more_btn != null:
		more_btn.emit_signal("pressed")
		await _settle()
		_check(more_calls.visible and box.find_child("RotationPicker", true, false).is_visible_in_tree(),
				"More calls opens the rest (%s)" % tag)
	var small := []
	for b in box.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 40:
			small.append("%s %.0f" % [b.name, b.size.y])
	_check(small.is_empty(), "Every break button is thumb-sized (%s: %s)" % [tag, str(small)])
	for c in m.find_children("*", "Control", true, false):
		if c is Label and c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
			_check(false, "Nothing runs off the side of the phone: %s (%s)" % [c.name, tag])
			break

	# Half time: the assistant's report is one tap away and Back closes it.
	var sim = _state.pending_sim
	# Get to half time without watching: play out each segment at once, the
	# way the pitch does when a quarter is skipped (frame counts vary by box).
	guard = 0
	while not (sim.current_quarter >= 3 and m.find_child("CoachBox", true, false) != null) and guard < 40:
		guard += 1
		var sb = m.find_child("StartQuarter", true, false)
		if sb != null:
			sb.emit_signal("pressed")
			await _settle()
		var card = m.find_child("MomentCard", true, false)
		if card != null:
			var pick: Button = card.find_child("Moment_0", true, false)
			if pick != null:
				pick.emit_signal("pressed")
			await _settle()
		if m.find_child("CoachBox", true, false) == null and m.find_child("MomentCard", true, false) == null:
			pitch.skip_to_end()
			await _settle()
	await _settle()
	box = m.find_child("CoachBox", true, false)
	var report_btn: Button = box.find_child("HalfTimeReport", true, false) if box != null else null
	_check(report_btn != null, "Half time offers the assistant's report (%s)" % tag)
	if report_btn != null:
		report_btn.emit_signal("pressed")
		await _settle()
		var rep: Node = m.find_child("AssistantReport", true, false)
		_check(rep != null and rep.find_child("MatchRead", true, false) != null
				and rep.find_child("ReportBest", true, false) != null, "The report opens at a glance (%s)" % tag)
		var rt := _text(rep)
		_check(not rt.contains("vs par") and not rt.contains("disp (") and not rt.contains("Where the game is being won"),
				"The short report is words, not a stat dump (%s)" % tag)
		_check(rep.find_child("FullReportButton", true, false) == null and not rt.contains("Half time:"),
				"One report: no full-report stat wall, no second scoreline (%s)" % tag)
		_check(rt.contains("Half time, "), "It says where the game stands, once (%s)" % tag)
		_check(m.call("handle_back") == true, "Back is handled on the report (%s)" % tag)
		await _settle()
		_check(m.find_child("AssistantReport", true, false) == null and m.find_child("CoachBox", true, false) != null,
				"Back closes the report and keeps the break (%s)" % tag)
	_check(m.call("handle_back") == true and m.find_child("CoachBox", true, false) != null,
			"Back cannot abandon a live match (%s)" % tag)

	# Full time: the result word belongs here.
	m.call("_on_skip")
	for i in range(60):
		await process_frame
	var ft_box: Node = m.find_child("FullTime", true, false)
	var ft := _text(ft_box)
	_check(ft_box != null and ft.contains("Full time"), "Full time is unmistakable (%s)" % tag)
	var verdict: Label = ft_box.find_child("Verdict", true, false) if ft_box != null else null
	_check(verdict != null and (verdict.text.begins_with("Won by") or verdict.text.begins_with("Lost by")
			or verdict.text == "Draw"), "Full time leads with the result (%s: %s)" % [tag, verdict.text if verdict else "-"])
	for n in ["MatchFactors", "BestPlayers", "KeyStats", "FinalScore_0", "FinalScore_1", "StandoutRating"]:
		_check(ft_box != null and ft_box.find_child(n, true, false) != null, "Full time shows %s (%s)" % [n, tag])
	_check(not ft.contains("pts") and not ft.contains("Expected points") and not ft.contains("Possession chains"),
			"The full-time screen keeps the analysis a tap away (%s)" % tag)
	_check(not ft.contains(" XP"), "Development reads in words at full time, not XP (%s)" % tag)
	# One review, two tabs, one way out: the Summary is the one report.
	for n in ["ReviewTab_summary", "ReviewTab_stats", "FullTimeContinue"]:
		_check(ft_box != null and ft_box.find_child(n, true, false) != null, "Full time has %s (%s)" % [n, tag])
	_check(ft_box != null and ft_box.find_child("ReviewTab_report", true, false) == null
			and not ft.contains("Second-half notes") and not ft.contains("Match read"),
			"One coaching report, not a summary plus a report (%s)" % tag)
	var stats_btn: Button = ft_box.find_child("ReviewTab_stats", true, false) if ft_box != null else null
	_check(stats_btn != null and stats_btn.size.y >= 44, "Match stats is one tap away (%s)" % tag)
	if stats_btn != null:
		stats_btn.emit_signal("pressed")
		await _settle()
		var ms: Node = m.find_child("MatchStats", true, false)
		_check(ms != null and _text(ms).contains("Quarter by quarter") and _text(ms).contains("Player stats"),
				"Match stats holds the full numbers (%s)" % tag)
		var table: Node = ms.find_child("PlayerStats", true, false) if ms != null else null
		var roster: Array = m.get("_res")["roster"]
		var my_side: int = m.get("_my_side")
		_check(table != null and table.find_children("PlayerRow_*", "Button", true, false).size()
				== (roster[my_side] as Array).size(), "Every player of yours has a row (%s)" % tag)
		if table != null:
			var other: Button = table.find_child("StatsTab_%d" % (1 - my_side), true, false)
			other.emit_signal("pressed")
			await _settle()
			_check(table.find_children("PlayerRow_*", "Button", true, false).size()
					== (roster[1 - my_side] as Array).size(), "...and so does every opponent (%s)" % tag)
			var sort_d: Button = table.find_child("Sort_disposals", true, false)
			sort_d.emit_signal("pressed")
			await _settle()
			var cells := []
			for row in table.find_children("PlayerRow_*", "Button", true, false):
				var labels := row.find_children("*", "Label", true, false)
				cells.append(int(str(labels[2].text)))
			var sorted_ok := true
			for i in range(1, cells.size()):
				if int(cells[i]) > int(cells[i - 1]):
					sorted_ok = false
			_check(sorted_ok and not cells.is_empty(), "A column header sorts the table (%s)" % tag)
			var first_row: Button = table.find_children("PlayerRow_*", "Button", true, false)[0]
			first_row.emit_signal("pressed")
			await _settle()
			_check(table.find_child("PlayerDetail", true, false) != null, "A tap opens the rest of his line (%s)" % tag)
			var more = table.find_child("PlayerDetail", true, false)
			_check(more != null and str(more.text).contains("metres gained") and str(more.text).contains("disposal efficiency"),
					"His line includes metres gained and disposal efficiency (%s)" % tag)
			var fits := true
			for row in table.find_children("PlayerRow_*", "Button", true, false):
				if row.is_visible_in_tree() and row.get_global_rect().end.x > sz.x + 1:
					fits = false
			_check(fits, "The player table fits the phone (%s)" % tag)
		_check(m.find_children("*", "Control", true, false).filter(func(c): return str(c.name) == "FullTime").size() == 1,
				"Stats opens in the same review, not a new layer (%s)" % tag)
		_check(m.call("handle_back") == true, "Back on Stats is handled (%s)" % tag)
		await _settle()
		_check(m.find_child("MatchStats", true, false) == null and m.find_child("BestPlayers", true, false) != null,
				"...and returns to Summary (%s)" % tag)
		_check(m.call("handle_back") == false, "Back on Summary leaves as full time always has (%s)" % tag)
	m.queue_free()
	await _settle()


func _text(node: Node) -> String:
	if node == null:
		return ""
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
