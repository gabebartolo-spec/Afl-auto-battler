extends SceneTree
## godot --headless --path . --script tests/run_matchday_tests.gd
## Matchday words (tests/test_matchday.gd), then your match on a phone: the
## score, clock and leader at a glance, a feed of what matters, the breaks
## as "what happened, then your calls", and Back closing a report first.

const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2027

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
	# Never the clock: every season in this suite starts from a fixed seed, so
	# a run can't pass or fail on which opponent it happened to draw.
	_state.replay_seed = SUITE_SEED
	var script = load("res://tests/test_matchday.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_matchday.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	# A fixed season seed: the clock would pick a different opponent each run,
	# and some field no key forward at quarter time (no match-up to change).
	_state.replay_seed = 2026
	for sz in [Vector2i(420, 860), Vector2i(360, 740)]:
		await _phone_match(sz)
	_state.replay_seed = SUITE_SEED
	await _plan_at_first_bounce()
	await _bounce_close_up()
	await _playtest_bounce_scene()
	await _rings_on_the_oval()
	await _first_goal_line()
	_appearance()
	# Battery: nothing is redrawn unless it changes, and never above 60 fps.
	_check(bool(ProjectSettings.get_setting("application/run/low_processor_mode", false))
			and int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 60,
			"Idle screens are not redrawn every frame, and frames are capped at 60")
	print("Matchday + match screen tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The plan you take into a live match is the plan at the first bounce: the
## pre-bounce box shows it, Start without touching it keeps it, and a change
## in the box is what plays. Read from the engine's own record of the
## quarter (tactics_history), not from a stored setting or a label.
func _plan_at_first_bounce() -> void:
	var db = root.get_node("GameDB")
	for want in [["defensive", ""], ["controlled", "contest"]]:
		var chosen := str(want[0])
		var change := str(want[1])
		_state.reset()
		_state.start_season("COL", db.club_list("COL"))
		root.size = Vector2i(420, 860)
		_state.set_club_plan(chosen)
		_check(_state.prepare_interactive_match(), "A live match is prepared (plan %s)" % chosen)
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		var box: Node = m.find_child("CoachBox", true, false)
		_check(box != null, "The pre-bounce box opens (plan %s)" % chosen)
		if box == null:
			m.queue_free()
			continue
		var shown: Button = box.find_child("PlanPicker_" + chosen, true, false)
		_check(shown != null and shown.get_theme_stylebox("normal").border_width_left == 2,
				"The pre-bounce box shows the plan you took in (%s)" % chosen)
		if change != "":
			var other: Button = box.find_child("PlanPicker_" + change, true, false)
			_check(other != null, "Another plan can be picked before the bounce (%s)" % change)
			if other != null:
				other.emit_signal("pressed")
				await _settle()
		var start: Button = box.find_child("StartQuarter", true, false)
		start.emit_signal("pressed")
		await _settle()
		var sim = _state.pending_sim
		var side := int(sim.moment_side)
		var hist: Array = sim.tactics_history
		var played := str(((hist[0] as Dictionary)["plans"][side] as Dictionary).get("gameplan", "")) if not hist.is_empty() else ""
		var expect := change if change != "" else chosen
		_check(played == expect, "The first quarter is played on %s (engine: %s)" % [expect, played])
		m.queue_free()
		await _settle()


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
	# A tag is a midfield job: the list is their midfielders on the ground.
	var opp_side: Array = (m.get("_res")["roster"][1 - int(m.get("_my_side"))] as Array).filter(
			func(r): return str(r["role"]) == "MID")
	if tag_other != null:
		tag_other.emit_signal("pressed")
		await _settle()
		var sheet: Node = m.find_child("PlayerSheet", true, false)
		_check(sheet != null and sheet.find_children("Sheet_*", "Button", true, false).size() == opp_side.size(),
				"The full list has every one of their midfielders (%s)" % tag)
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
	var facts: Node = box.find_child("QuarterFacts", true, false)
	_check(facts != null and facts.get_child_count() <= 3,
			"What happened in the quarter is three things at most (%s)" % tag)
	var bt := _text(box)
	_check(not bt.contains("pts") and not bt.contains("Expected points") and not bt.contains(" def ")
			and not bt.contains("defeated"), "The break shows no engine numbers or result words (%s)" % tag)
	_check(bt.contains("Tag on ") and box.find_child("CallsDid", true, false) != null,
			"The break says what your calls did, your tag among them (%s)" % tag)
	var qh: Label = box.find_child("QuarterHeading", true, false)
	_check(qh != null and qh.text == "First quarter" and not bt.contains("What's happening"),
			"Quarter time leads with the quarter just played, by name (%s)" % tag)
	var more_calls: Control = box.find_child("MoreCalls", true, false)
	var more_btn: Button = box.find_child("MoreCallsToggle", true, false)
	_check(more_calls != null and not more_calls.visible and more_btn != null and box.find_child("PlanPicker", true, false).is_visible_in_tree()
			and box.find_child("TagPicker", true, false).is_visible_in_tree(),
			"The plan and the tag are in view; the rest of the calls are one tap away (%s)" % tag)
	# Key match-ups: their key forwards and who is on them, changed in a tap
	# - and the change is the engine's from the next bounce.
	var qsim = _state.pending_sim
	var myside := int(m.get("_my_side"))
	var bm: Node = box.find_child("BreakMatchups", true, false)
	_check(bm != null, "The break shows the key match-ups (%s)" % tag)
	_check(bm != null and bm.find_child("AssistantNote", true, false) != null and qsim.assistant_active(myside),
			"The break shows your assistant's set-up as your starting point (%s)" % tag)
	var ch: Button = bm.find_child("ChangeMatchup", true, false) if bm != null else null
	# Required: without a Change button the checks below would be skipped.
	_check(ch != null, "The break offers a Change for their key forward (%s)" % tag)
	if ch != null:
		var fid := str((qsim.duels[myside] as Dictionary).keys()[0])
		var cur := str(qsim.duels[myside][fid])
		# Real taps from here (tests/tap.gd): a touch on the screen, not a call
		# to the handler. First, the tool itself: a sheet over the button must
		# take the tap.
		var cover := ColorRect.new()
		cover.color = Color(0, 0, 0, 0)
		cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_child(cover)
		await _settle()
		var blocked: String = await Tap.tap(ch)
		_check(blocked != "" and m.find_child("MatchupChooser", true, false) == null,
				"A tap on a covered button doesn't reach it (%s: %s)" % [tag, blocked])
		cover.queue_free()
		await _settle()
		var why: String = await Tap.tap(ch)
		_check(why == "", "A finger's tap on Change reaches it (%s: %s)" % [tag, why])
		await _settle()
		var chooser: Node = m.find_child("MatchupChooser", true, false)
		var pick: Button = null
		if chooser != null:
			for b2 in chooser.find_children("Defender_*", "Button", true, false):
				if str(b2.name) != "Defender_" + cur and pick == null:
					pick = b2
		_check(pick != null, "Your defenders are offered for their forward (%s)" % tag)
		if pick != null:
			var picked := str(pick.name).trim_prefix("Defender_")
			var why2: String = await Tap.tap(pick)
			_check(why2 == "", "A finger's tap picks the defender (%s: %s)" % [tag, why2])
			await _settle()
			_check(str(qsim.duels[myside][fid]) == picked
					and int(qsim.duel_changes[qsim.duel_changes.size() - 1]["from"]) == 2,
					"The defender goes to him from the next quarter (%s)" % tag)
			_check(((qsim._own[myside] as Dictionary)["duels"] as Dictionary).has(fid),
					"A match-up you change stays your call (%s)" % tag)
			var btext := _text(box)
			_check(not btext.contains("%") and not btext.contains("pts"), "The match-ups show no engine numbers (%s)" % tag)
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
		_check(not rt.contains("Opposition danger"),
				"Their best players are an observation, not a problem to solve (%s)" % tag)
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
	_check(RegEx.create_from_string("\\bpts\\b").search(ft) == null and not ft.contains("Expected points")
			and not ft.contains("Possession chains"),
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


## The late centre-bounce call opens on a close-up of that stoppage
## (ARD-M8-007): only the players at the bounce, from this match, freezing
## before the call; the lines under it are MatchSim's own numbers; the call
## is MatchSim's and closes back to the match view.
func _bounce_close_up() -> void:
	var sz := Vector2i(360, 740)
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared (bounce close-up)")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var start: Button = m.find_child("StartQuarter", true, false)
	start.emit_signal("pressed")
	await _settle()
	var pitch = m.get("_pitch")
	pitch.pause()
	var sim = _state.pending_sim
	var me := int(m.get("_my_side"))
	var them := 1 - me
	# A tight last quarter at a centre bounce, as MatchSim would reach it.
	sim.pending_moment = {}
	sim.moment_side = me
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim.set("_moments_this_q", 0)
	sim.set("_last_moment_chain", -1000)
	sim.set("_run", [0, 0])
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 9.0 + side
		(sim.team_stats[side] as Dictionary)["behinds"] = 8.0
	(sim.team_stats[me] as Dictionary)["clearances"] = 5.0
	(sim.team_stats[them] as Dictionary)["clearances"] = 12.0
	var their_mids: Array = sim.squads[them].ground.filter(
			func(p): return str(p["role"]) == "MID")
	for side in range(2):
		for p in sim.squads[side].ground:
			sim.energy[str(p["id"])] = 90.0
	for p in their_mids:
		sim.energy[str(p["id"])] = 30.0
	_check(sim.call("_boundary_moment") and str(sim.pending_moment.get("kind", "")) == "bounce",
			"MatchSim asks the late centre-bounce call (%s)" % str(sim.pending_moment.get("kind", "-")))
	m.call("_show_moment")
	await _settle()
	var card = m.find_child("MomentCard", true, false)
	var vig = m.find_child("StoppageVignette", true, false)
	_check(card != null and vig != null, "The call opens on the close-up of the bounce")
	if card == null or vig == null:
		m.queue_free()
		return
	var viewport := Rect2(Vector2.ZERO, Vector2(sz))
	_check(vig.size.y >= 220.0 and viewport.encloses(vig.get_global_rect()),
			"The close-up fills the top of a phone (%s)" % str(vig.get_global_rect()))
	# Only the stoppage: both rucks, the centre-square mids and the wings.
	var tokens: Array = vig.tokens
	var sides := {}
	var names_ok := true
	for t in tokens:
		sides[int(t["side"])] = true
		var found := false
		for p in sim.squads[int(t["side"])].ground:
			if int(p["num"]) == int(t["num"]) and db.player_display_name(p).ends_with(str(t["name"])):
				found = true
		names_ok = names_ok and found
	_check(tokens.size() >= 6 and tokens.size() <= 8 and sides.size() == 2,
			"Only the players at the bounce, both sides (%d)" % tokens.size())
	_check(names_ok, "Every player in the close-up is on the ground in this match")
	_check(tokens.filter(func(t): return str(t["slot"]) == "R").size() == 2, "Both rucks are at the bounce")
	# The players at the bounce are MatchSim's own: its ruck contestant and centre-bounce attendees.
	_check(_bounce_matches_sim(vig.tokens, sim), "The close-up shows MatchSim's rucks and centre-bounce mids")
	var looks_ok := true
	for t in vig.tokens:
		for p in sim.squads[int(t["side"])].ground:
			if str(p["id"]) == str(t["id"]):
				looks_ok = looks_ok and t["look"] == db.player_looks(p)
	_check(looks_ok, "Each player in the scene wears his own look")
	# The resting-ruck case: a midfielder stands in the ruck spot while the ruckman rests
	# up forward. MatchSim sends the ruckman up, so the scene must show him taking the tap.
	var before_at: Dictionary = sim.bounce_attendees(them)
	var resting: Dictionary = before_at["ruck"]
	var stand_in = null
	for p in before_at["mids"]:
		if not sim._is_ruckman(p) and stand_in == null:
			stand_in = p      # one of the inside mids steps into the ruck spot
	if not resting.is_empty() and stand_in != null:
		var saved := [str(resting["role"]), resting.get("own_role", null), str(stand_in["role"])]
		resting["own_role"] = "RUCK"     # a listed ruckman, resting up forward
		resting["role"] = "FWD"
		stand_in["role"] = "RUCK"
		vig.setup(sim, me, "")
		var tapper: Array = (vig.tokens as Array).filter(
				func(t): return int(t["side"]) == them and str(t["slot"]) == "R")
		var tapper_is_ruckman := false
		for p in sim.squads[them].ground:
			if not tapper.is_empty() and str(p["id"]) == str(tapper[0]["id"]):
				tapper_is_ruckman = sim._is_ruckman(p)
		_check(tapper.size() == 1 and str(tapper[0]["id"]) != str(stand_in["id"]) and tapper_is_ruckman
				and _bounce_matches_sim(vig.tokens, sim),
				"A midfielder in the ruck spot doesn't take the tap: a ruckman does, as in MatchSim")
		resting["role"] = saved[0]
		if saved[1] == null:
			resting.erase("own_role")
		else:
			resting["own_role"] = saved[1]
		stand_in["role"] = saved[2]
		vig.setup(sim, me, "")
	else:
		_check(false, "The resting-ruck case can be staged (a ruck and an inside mid at the bounce)")
	# The players are the pre-rendered figures, each side in its own club's colours.
	var mat := vig.material as ShaderMaterial
	var kits: Array = Array(mat.get_shader_parameter("kit_base")) if mat != null else []
	var designs: Array = Array(mat.get_shader_parameter("kit_design")) if mat != null else []
	var mine: Dictionary = db.club_guernsey(str(sim.squads[me].code))
	var theirs: Dictionary = db.club_guernsey(str(sim.squads[them].code))
	_check(kits.size() == 4 and kits[me] == mine["base"] and kits[them] == theirs["base"]
			and int(designs[me]) == db.GUERNSEY_DESIGNS.find(mine["design"])
			and int(designs[them]) == db.GUERNSEY_DESIGNS.find(theirs["design"]),
			"The players are drawn as figures in both clubs' guernseys")
	# Every club's guernsey names a design the figures can wear, and every colour in it
	# is one of the club's own (p, s, a) or written out (#RRGGBB).
	var guernseys_ok := true
	for code in db.clubs:
		var row: String = str(db.clubs[code].get("guernsey", ""))
		var parts := row.split(":")
		var slots := parts[1].split("/") if parts.size() > 1 else PackedStringArray()
		var colours_ok := slots.size() >= 3 and slots.size() <= 4
		for token in slots:
			colours_ok = colours_ok and (token in ["p", "s", "a"]
					or (token.begins_with("#") and token.length() == 7 and Color.html_is_valid(token)))
		guernseys_ok = guernseys_ok and colours_ok and db.GUERNSEY_DESIGNS.has(parts[0]) \
				and str(db.club_guernsey(str(code))["design"]) == parts[0]
	_check(guernseys_ok and db.clubs.size() >= 18, "Every club's guernsey is a design the figures can wear")
	# What the scene plays: both builds stand, run and tap (the ruck contest, one-handed),
	# facing either way; the umpire (the average build, facing the camera) bounces.
	var moves_ok := _sheet_has(VignetteFigures.BODIES["average"], "bounce", ["front"])
	for build in ["average", "ruck"]:          # the footballers (the sheet also holds the coach)
		for anim in ["idle", "jog", "tap"]:
			moves_ok = moves_ok and _sheet_has(VignetteFigures.BODIES[build], anim, ["front", "back"])
	_check(moves_ok and Vector2i((vig.FIGURE_SHADE as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE
			and Vector2i((vig.FIGURE_MASK as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE
			and Vector2i((vig.FIGURE_DESIGN as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE / 2,
			"The figure sheets hold every move the scene plays, front and back")
	# It plays as a scene: the players run into the set-up before the freeze.
	var before: Vector2 = vig.call("_pos", tokens[0])
	for i in range(20):
		await process_frame
	_check(float(vig.get("_t")) > 0.0 and (vig.call("_pos", tokens[0]) as Vector2).distance_to(before) > 0.1,
			"The players move into the set-up before the freeze")
	# It plays in, then freezes for the call; no tap makes the call early.
	var b0: Button = card.find_child("Moment_0", true, false)
	_check(not vig.is_frozen() and b0 != null and b0.disabled, "The call waits for the bounce")
	vig.finish_now()
	await _settle()
	_check(vig.is_frozen() and not b0.disabled, "Frozen on the bounce, the call is live")
	var text := _text(card)
	_check(text.contains("They have been winning it out of the middle all day."),
			"The commentary tells the story of the stoppages, from the match (%s)" % text)
	_check(text.contains("Their ") and text.contains("is running on empty."),
			"Their tired midfielder is called out (%s)" % text)
	var said := " ".join(vig.facts)
	_check(not said.contains("%") and not said.contains("clearances") and not text.to_lower().contains("recommend"),
			"No stats, percentages or advice over the scene")
	var t0: float = vig.get("_t")
	await _settle()
	_check(is_equal_approx(float(vig.get("_t")), t0), "The scene holds still while the call is up")
	var off := []
	for b in card.find_children("Moment_*", "Button", true, false):
		if not viewport.encloses((b as Button).get_global_rect()) or (b as Button).size.y < 44:
			off.append(b.name)
	_check(off.is_empty(), "Every option is on screen and thumb-sized (%s)" % str(off))
	# The call is MatchSim's; then straight back to the match view.
	var asked: int = sim.moments.size()
	var straight: Button = card.find_child("Moment_2", true, false)
	straight.emit_signal("pressed")
	_check(sim.moments.size() == asked + 1 and str((sim.moments[-1] as Dictionary).get("kind", "")) == "bounce",
			"MatchSim takes the call")
	_check(not is_instance_valid(card) or card.name != "MomentCard", "The scene cuts back to the match")
	for i in range(40):
		await process_frame
	_check(not is_instance_valid(card), "The scene is gone once it has faded")
	m.queue_free()
	await _settle()


## The playtest switch (Settings, ARD-M8-007): the centre-bounce scene comes even
## where no call could - early in the last quarter of a blowout, the quarter's calls
## spent - and plays through the real match screen.
func _playtest_bounce_scene() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(360, 740)
	_state.set_bounce_scene_every_match(true)
	_check(_state.prepare_interactive_match() and bool(_state.pending_sim.always_offer_bounce),
			"The playtest switch reaches the match")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	m.find_child("StartQuarter", true, false).emit_signal("pressed")
	await _settle()
	m.get("_pitch").pause()
	var sim = _state.pending_sim
	var me := int(m.get("_my_side"))
	sim.pending_moment = {}
	sim.moment_side = me
	sim.current_quarter = 4
	sim.current_minute = 91
	sim.at_centre = true
	sim.set("_moments_this_q", 2)
	sim.set("_last_moment_chain", int(sim.get("_chain_no")))
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 6.0 if side == me else 15.0
		(sim.team_stats[side] as Dictionary)["behinds"] = 5.0
	sim.always_offer_bounce = false
	_check(not sim.call("_boundary_moment") and sim.pending_moment.is_empty(),
			"Without the switch, a blowout early in the last quarter brings no call")
	sim.always_offer_bounce = true
	_check(sim.call("_boundary_moment") and str(sim.pending_moment.get("kind", "")) == "bounce"
			and int(sim.get("_moments_this_q")) == 2,
			"With it, the centre-bounce call comes anyway, outside the quarter's calls")
	m.call("_show_moment")
	await _settle()
	_check(m.find_child("StoppageVignette", true, false) != null, "The playtest call opens the centre-bounce scene")
	m.queue_free()
	await _settle()
	_state.set_bounce_scene_every_match(false)


## Your calls ring your people on the oval (MatchRings, drawn by PitchView): no
## one before you have made a call, then the player you play through and the
## player who goes to your tag from the bounce, never the man you tag, and a run
## you promised as the next event plays.
func _rings_on_the_oval() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	_check(_state.prepare_interactive_match(), "A live match is prepared (rings)")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var pitch = m.get("_pitch")
	var sim = _state.pending_sim
	var me := int(m.get("_my_side"))
	_check(pitch.rings.is_empty(), "No one is ringed before you have made a call")
	var box: Node = m.find_child("CoachBox", true, false)
	var focus_id := _first_pick(box, "FocusPickerGrid_")
	var tag_id := _first_pick(box, "TagPickerGrid_")
	_check(focus_id != "" and tag_id != "", "A play-through and a tag are on offer")
	if focus_id == "" or tag_id == "":
		m.queue_free()
		return
	box.find_child("FocusPickerGrid_" + focus_id, true, false).emit_signal("pressed")
	box.find_child("TagPickerGrid_" + tag_id, true, false).emit_signal("pressed")
	box.find_child("StartQuarter", true, false).emit_signal("pressed")
	await _settle()
	_check(pitch.ringed(focus_id), "The player you play through is ringed from the bounce")
	var tagger = load("res://scripts/sim/MatchSim.gd").tagger_for(sim.squads[me].ground)
	_check(tagger != null and pitch.ringed(str(tagger["id"])), "So is the player who goes to your tag")
	_check(not pitch.ringed(tag_id), "The man you tag is not ringed")
	var mine := {}
	for r in (m.get("_res")["roster"][me] as Array):
		mine[str(r["id"])] = true
	var only_mine: bool = not pitch.rings.is_empty()
	for id in pitch.rings:
		if not mine.has(str(id)):
			only_mine = false
	_check(only_mine, "Only your own players are ringed")
	# A run you promise shows from the next event.
	var kid := ""
	for r in sim.squads[me].ground:
		if not pitch.ringed(str(r["id"])):
			kid = str(r["id"])
			break
	var backing = load("res://scripts/sim/Backing.gd")
	for p in _state.my_list:
		if str(p["id"]) == kid:
			backing.start(p, 2027, 1, 0)
	var guard := 0
	while not pitch.ringed(kid) and guard < 400:
		pitch._process(0.25)
		guard += 1
	_check(kid != "" and pitch.ringed(kid), "A player you promised a run is ringed as the next event plays")
	m.queue_free()
	await _settle()


## The live feed says a first AFL goal for one of yours: the screen is told who it
## could be (GameState.first_goal_candidates), and says it once, and only of them.
func _first_goal_line() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	_check(_state.prepare_interactive_match(), "A live match is prepared (first goal)")
	var sim = _state.pending_sim
	var me := 0 if str(_state.pending_match["home"]) == _state.my_club else 1
	# One of your side, on a career on record in full with no goal yet.
	var kicker: Dictionary = sim.squads[me].ground[0]
	var pid := str(kicker["id"])
	var p: Dictionary = _state.list_player(pid)
	p["career"] = {"games": 3, "goals": 0, "stints": [], "through": _state.season_year - 1, "unknown": []}
	_state.season_tally.erase(pid)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var told: Dictionary = m.get("_duel_mem").get("first_goal", {})
	var opp_ids := {}
	for r in sim.squads[1 - me].ground:
		opp_ids[str(r["id"])] = true
	var only_mine: bool = not told.is_empty()
	for id in told:
		if opp_ids.has(id):
			only_mine = false
	_check(told.has(pid) and only_mine, "The screen is told whose first goal it could be, and only yours")
	var feed: Node = m.find_child("Feed", true, false)
	var said := func() -> Array:
		var out := []
		for c in feed.get_children():
			if str(c.get_meta("feed_kind", "")) == "StoryLine":
				out.append(str(c.text))
		return out
	var goal := {"kind": "goal", "q": 1, "min": 3, "side": me, "player_id": pid, "name": "Test Kicker",
			"score": [6, 0]}
	m.call("_story_feed", goal)
	var rows: Array = said.call()
	_check(rows.size() == 1 and str(rows[0]).ends_with("First AFL goal for Test Kicker."),
			"His first goal reaches the feed (%s)" % str(rows))
	m.call("_story_feed", goal)
	_check((said.call() as Array).size() == 1, "...once")
	var theirs := goal.duplicate()
	theirs["side"] = 1 - me
	theirs["player_id"] = str((sim.squads[1 - me].ground[0] as Dictionary)["id"])
	theirs["name"] = "Their Kicker"
	m.call("_story_feed", theirs)
	_check((said.call() as Array).size() == 1, "Nothing is said of the other side's first goals")
	m.queue_free()
	await _settle()


## The first player a call offers: the id behind a "<prefix><id>" button.
func _first_pick(box: Node, prefix: String) -> String:
	for b in box.find_children(prefix + "*", "Button", true, false):
		var id := str(b.name).trim_prefix(prefix)
		if id != "":
			return id
	return ""


## How players look on the figures (Appearance.gd, data/player_appearance.csv):
## presentation only, never a guess about a real person, never tied to a rating.
func _appearance() -> void:
	var db = root.get_node("GameDB")
	# Generated players: from the id alone - stable, and the same whatever the ratings say.
	var fake := {"id": "GEN_1", "generated": true, "overall": 50, "role": "MID"}
	var again := {"id": "GEN_1", "generated": true, "overall": 95, "role": "RUCK", "potential": 99}
	var counts := [0, 0, 0, 0, 0, 0]
	for i in range(3000):
		counts[int(db.player_looks({"id": "gen_%d" % i, "generated": true})["skin"])] += 1
	var mix_ok := true
	var total := 0.0
	for w in db.skin_mix:
		total += float(w)
	for t in range(6):
		mix_ok = mix_ok and absf(counts[t] / 3000.0 - float(db.skin_mix[t]) / total) < 0.03
	_check(db.player_looks(fake) == db.player_looks(again) and mix_ok,
			"Generated players' looks come from their id alone, spread like the league (%s)" % str(counts))
	# Real players: their curated row, or the neutral look until one exists - never a random one.
	var curated := 0
	var uncurated_ok := true
	for p in db.players:
		var row: Dictionary = db.appearance.get(db._look_key(p), {})
		if row.is_empty():
			uncurated_ok = uncurated_ok and db.player_looks(p) == Appearance.UNCURATED
		else:
			curated += 1
			uncurated_ok = uncurated_ok and db.player_looks(p) == {"skin": int(row["skin"]), "hair": int(row["hair"])}
	_check(uncurated_ok, "Real players look as curated, or neutral until they are - never guessed")
	# The full look (Club Forge): a real player's style is the plain base,
	# never a guess; a generated one's varies with his id and nothing else.
	var real_ok := true
	for p in db.players.slice(0, 40):
		var full: Dictionary = db.player_appearance(p)
		for k in Appearance.BASE_LOOK:
			if k != "beard_colour":
				real_ok = real_ok and full[k] == Appearance.BASE_LOOK[k]
	_check(real_ok, "A real player's style is the plain base look until it is chosen")
	var styles := {}
	var bald := 0
	var clean := 0
	var inked := 0
	var valid_ok := true
	for i in range(3000):
		var g: Dictionary = db.player_appearance({"id": "gen_%d" % i, "generated": true})
		styles[g["hair_style"]] = true
		bald += 1 if g["hair_style"] == "bald" else 0
		clean += 1 if g["beard"] == "clean" else 0
		inked += 1 if not (g["tattoos"] as Array).is_empty() else 0
		for k in g:
			valid_ok = valid_ok and Appearance.valid(k, g[k])
	_check(db.player_appearance(fake) == db.player_appearance(again) and styles.size() >= 12
			and bald > 30 and bald < 240 and clean > 1200 and clean < 1600 and inked > 600 and inked < 1200 and valid_ok,
			"Generated players vary across the library from their id alone (%d styles, %d bald, %d clean-shaven, %d inked)" % [
					styles.size(), bald, clean, inked])
	var chosen := {"id": "C_1", "look": {"skin": 5, "hair": 2, "hair_style": "afro", "beard": "nonsense", "scars": 9}}
	var cf: Dictionary = db.player_appearance(chosen)
	_check(cf["hair_style"] == "afro" and cf["beard"] == "clean" and int(cf["scars"]) == 0
			and db.player_looks(chosen) == {"skin": 5, "hair": 2} and int(cf["beard_colour"]) == 2,
			"A chosen look is kept where valid, and its colours reach the figures")
	# Every curated row is a real player, with a tone, a hair colour, a status and a source.
	var keys := {}
	for p in db.players + db.draftees:
		keys[db._look_key(p)] = true
	var rows_ok := true
	var f := FileAccess.open("res://data/player_appearance.csv", FileAccess.READ)
	var header := f.get_csv_line()
	var n := 0
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < header.size() or (r.size() == 1 and r[0] == ""):
			continue
		n += 1
		var d := {}
		for j in range(header.size()):
			d[header[j]] = r[j]
		rows_ok = rows_ok and keys.has(db._look_key(d)) and int(d["skin"]) >= 1 and int(d["skin"]) <= 6 				and Appearance.HAIR_KEYS.has(d["hair"]) and d["status"] in ["draft", "unsure", "confirmed"] 				and str(d["source"]).begins_with("http")
	_check(rows_ok and n == db.appearance.size() and curated == n,
			"Every curated look is a real player's, complete and sourced (%d rows)" % n)


## The bounce scene's players, side by side, are MatchSim's: the ruck in the R
## spot and the attending mids in the C, RR and RV spots, in its order.
func _bounce_matches_sim(tokens: Array, sim) -> bool:
	for side in range(2):
		var at: Dictionary = sim.bounce_attendees(side)
		var want := []
		if not (at["ruck"] as Dictionary).is_empty():
			want.append(["R", str(at["ruck"]["id"])])
		var mids: Array = at["mids"]
		for i in range(mids.size()):
			want.append([["C", "RR", "RV"][i], str(mids[i]["id"])])
		var shown := []
		for t in tokens:
			if int(t["side"]) == side:
				shown.append([str(t["slot"]), str(t["id"])])
		if shown != want:
			return false
	return true


func _settle() -> void:
	for i in range(6):
		await process_frame


## True when a body on the figure sheet has the move from every one of those sides.
func _sheet_has(body: Dictionary, anim: String, facings: Array) -> bool:
	for facing in facings:
		var info: Dictionary = ((body["anims"] as Dictionary).get(anim, {}) as Dictionary).get(facing, {})
		if int(info.get("frames", 0)) <= 0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
