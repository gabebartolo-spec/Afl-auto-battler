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
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _coach_descriptions(sz)
		await _tag_targets(sz)
		await _minder_cards(sz)
	await _tag_not_saved()
	await _bounce_close_up()
	await _playtest_bounce_scene()
	await _rings_on_the_oval()
	await _first_goal_line()
	await _momentum_meter()
	await _vignettes_setting()
	await _vignettes_off_match()
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
	for n in ["PlanPicker", "TagPicker", "FocusPicker_focus_mid", "FocusPicker_focus_fwd", "FocusPicker_focus_def",
			"PepPicker", "RotationPicker", "LegsView", "TagNote"]:
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
	_check(box.find_child("MoreCallsToggle", true, false) == null and box.find_child("PlanPicker", true, false).is_visible_in_tree()
			and box.find_child("TagPicker", true, false).is_visible_in_tree()
			and box.find_child("PepPicker", true, false).is_visible_in_tree()
			and box.find_child("RotationPicker", true, false).is_visible_in_tree(),
			"Every call is in view at the break, with no More calls button (%s)" % tag)
	_check((box.find_child("BreakColumns", true, false) != null) == bool(m.call("_wide_break")),
			"A wide PC window lays the break out in columns; a phone keeps one (%s)" % tag)
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
	var small := []
	for b in box.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 40:
			small.append("%s %.0f" % [b.name, b.size.y])
	_check(small.is_empty(), "Every break button is thumb-sized (%s: %s)" % [tag, str(small)])
	for c in m.find_children("*", "Control", true, false):
		if c is Label and c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
			_check(false, "Nothing runs off the side of the phone: %s (%s)" % [c.name, tag])
			break

	# Half time: the full match stats are one tap away and Back closes them.
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
	var stats_b: Button = box.find_child("BreakStats", true, false) if box != null else null
	_check(stats_b != null and box.find_child("HalfTimeReport", true, false) == null,
			"Half time offers the match stats, not a prose report (%s)" % tag)
	if stats_b != null:
		_check((await Tap.tap(stats_b)) == "", "The Match stats button takes a tap (%s)" % tag)
		await _settle()
		var sheet: Node = m.find_child("BreakStatsSheet", true, false)
		var bs: Node = sheet.find_child("BreakBoxScore", true, false) if sheet != null else null
		var bs_text := _text(bs) if bs != null else ""
		_check(bs != null and bs_text.contains("Q2") and not bs_text.contains("Q3")
				and bs.find_child("Worm", true, false) != null,
				"The box score shows the quarters played so far, and the worm (%s)" % tag)
		# A finger on a quarter's column says that quarter (director, 2026-10-08).
		var q1: Button = bs.find_child("BoxQuarter_1", true, false) if bs != null else null
		var says: Label = bs.find_child("WormSays", true, false) if bs != null else null
		var why_q: String = (await Tap.tap(q1)) if q1 != null else "no Q1 column"
		await _settle()
		_check(why_q == "" and says != null and says.text.begins_with("Q1:"),
				"A finger on Q1 says the first quarter (%s: %s)" % [tag, why_q if why_q != "" else (says.text if says else "-")])
		var team_t: Node = sheet.find_child("TeamStats", true, false) if sheet != null else null
		_check(team_t != null and team_t.find_child("TeamRow_disposals", true, false) != null,
				"Team stats open first, both clubs side by side (%s)" % tag)
		# Laid out for the phone from the first look, not only after a
		# quarter is picked (director's playtest, 2026-10-08).
		var first_spill := ""
		for c in sheet.find_children("*", "Control", true, false):
			if c is Label and c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
				first_spill = str(c.name)
				break
		var view_script = load("res://scripts/ui/match/MatchStatsView.gd")
		_check(team_t is GridContainer and (team_t as GridContainer).columns
				== clampi(int(sz.x / (float(view_script.GROUP_W) + 40.0)), 1, (view_script.GROUPS as Array).size())
				and first_spill == "", "The stats open laid out for this screen (%s%s)"
				% [tag, (": " + first_spill) if first_spill != "" else ""])
		var so_far := 0
		var mine_d: Node = team_t.find_child("TeamRow_disposals", true, false) if team_t != null else null
		if mine_d != null:
			so_far = int(str((mine_d.get_child(0) as Label).text))
		var q2: Button = sheet.find_child("StatsScope_2", true, false) if sheet != null else null
		_check(q2 != null and sheet.find_child("StatsScope_3", true, false) == null,
				"Each quarter played can be seen on its own, no more (%s)" % tag)
		if q2 != null:
			q2.emit_signal("pressed")
			await _settle()
			var q_d: Node = sheet.find_child("TeamRow_disposals", true, false)
			var in_q := int(str((q_d.get_child(0) as Label).text)) if q_d != null else -1
			_check(in_q > 0 and in_q < so_far, "The second quarter alone is less than the match so far (%d of %d, %s)" % [in_q, so_far, tag])
		var players_tab: Button = sheet.find_child("StatsView_players", true, false) if sheet != null else null
		if players_tab != null:
			players_tab.emit_signal("pressed")
			await _settle()
		var ptable: Node = sheet.find_child("PlayerStats", true, false) if sheet != null else null
		var roster_h: Array = m.get("_res")["roster"]
		_check(ptable != null and ptable.find_children("PlayerRow_*", "Button", true, false).size()
				== (roster_h[m.get("_my_side")] as Array).size(), "Player stats list every one of yours at the break (%s)" % tag)
		_check(ptable != null and ptable.find_child("StatsKey", true, false) != null,
				"A key spells out the column headings (%s)" % tag)
		var spill := ""
		for c in sheet.find_children("*", "Control", true, false):
			if c is Label and c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
				spill = str(c.name)
				break
		_check(spill == "", "The stats fit the screen (%s%s)" % [tag, (": " + spill) if spill != "" else ""])
		_check(m.call("handle_back") == true, "Back is handled on the stats (%s)" % tag)
		await _settle()
		_check(m.find_child("BreakStatsSheet", true, false) == null and m.find_child("CoachBox", true, false) != null,
				"Back closes the stats and keeps the break (%s)" % tag)
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
		_check(ms != null and ms.find_child("BoxScore", true, false) != null and ms.find_child("TeamStats", true, false) != null
				and ms.find_child("StatsView_players", true, false) != null,
				"Match stats holds the full numbers: team stats, players a tab away (%s)" % tag)
		var ptab: Button = ms.find_child("StatsView_players", true, false) if ms != null else null
		if ptab != null:
			ptab.emit_signal("pressed")
			await _settle()
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


## Every coaching choice says what it does, the neutral one too, and the
## words follow the choice. Real taps (tests/tap.gd) at the break, and the
## plan line under the clock shows every call in full.
func _coach_descriptions(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the coaching words (%s)" % tag)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The coaching words are checked on the break (%s)" % tag)
	if box == null:
		m.queue_free()
		return
	# PC is not a big phone (director, 2026-10-11): at 1280x720 every call
	# and its heading is in view before the bounce, nothing scrolls.
	if bool(m.call("_wide_break")) and sz.x >= 1200 and sz.y >= 700:
		var bc: Control = box.find_child("BreakColumns", true, false)
		var bsc: ScrollContainer = null
		var up: Node = bc
		while up != null and bsc == null:
			bsc = up as ScrollContainer
			up = up.get_parent()
		var room := bsc.size.y if bsc != null else 0.0
		var need := (bsc.get_child(0) as Control).get_combined_minimum_size().y if bsc != null else INF
		_check(need <= room + 1.0, "The PC break fits the window without scrolling (%.0f of %.0f, %s)" % [need, room, tag])
	var pep_btn: Button = null
	var pep_grid: Node = box.find_child("PepPicker", true, false)
	if pep_grid != null:
		for c in pep_grid.find_children("*", "Button", true, false):
			pep_btn = c
	var why: String = await Tap.tap(pep_btn)
	_check(why == "", "A finger reaches a call in the rest of the calls, no button first (%s: %s)" % [tag, why])
	await _settle()
	var legs_text := _text(box.find_child("LegsView", true, false))
	# Loaded, not named: the autoloads are not there when this script compiles.
	var report = load("res://scripts/sim/CoachReport.gd")
	var policies: Dictionary = load("res://scripts/sim/MatchSim.gd").ROTATION_POLICIES

	# Pep talk: all four choices, Composed included, explain themselves.
	var pep_seen := {}
	for k in ["steady", "fire_up", "calm", "heat"]:
		var b: Button = box.find_child("PepPicker_" + k, true, false)
		var w: String = await Tap.tap(b)
		_check(w == "", "A finger picks the %s pep talk (%s: %s)" % [k, tag, w])
		await _settle()
		var note: Label = box.find_child("PepNote", true, false)
		_check(note != null and note.is_visible_in_tree() and note.text != "" and note.text == report.pep_summary(k),
				"The %s pep talk shows its own description (%s)" % [k, tag])
		pep_seen[note.text if note != null else ""] = true
	_check(pep_seen.size() == 4, "Each pep talk has its own words (%s)" % tag)
	var composed: Button = box.find_child("PepPicker_steady", true, false)
	await Tap.tap(composed)
	await _settle()
	var pn: Label = box.find_child("PepNote", true, false)
	_check(pn != null and pn.text.begins_with("Keep them as they are"), "Back on Composed, its words return (%s)" % tag)

	# Rotations: Normal as much as the other two, and never the legs report.
	var rot_seen := {}
	for k in policies:
		var rb: Button = box.find_child("RotationPicker_" + str(k), true, false)
		var rw: String = await Tap.tap(rb)
		_check(rw == "", "A finger picks the %s rotation (%s: %s)" % [k, tag, rw])
		await _settle()
		var rn: Label = box.find_child("RotationNote", true, false)
		_check(rn != null and rn.is_visible_in_tree() and rn.text == str(policies[k]["text"]),
				"The %s rotation shows its own description (%s)" % [k, tag])
		_check(rn != null and rn.text != legs_text and not box.find_child("LegsView", true, false).is_ancestor_of(rn),
				"The rotation words are not the legs report (%s: %s)" % [k, str(k)])
		rot_seen[rn.text if rn != null else ""] = true
	_check(rot_seen.size() == policies.size(), "Each rotation has its own words (%s)" % tag)

	# Tag: "No tag" says so; a name brings the tagger line back.
	var tn: Label = box.find_child("TagNote", true, false)
	var none: Button = box.find_child("TagPickerGrid_", true, false)
	_check(tn != null and none != null and tn.text.begins_with("No tag"), "With no tag, the tag line says so (%s: %s)" % [tag, tn.text if tn else "-"])
	var named: Button = null
	for b in box.find_child("TagPicker", true, false).find_children("TagPickerGrid_*", "Button", true, false):
		if str(b.name) != "TagPickerGrid_":
			named = b
			break
	_check(named != null, "A player can be tagged (%s)" % tag)
	if named != null:
		var tw: String = await Tap.tap(named)
		await _settle()
		_check(tw == "" and tn.text.contains("goes to him"), "Picking a player brings the tagger line (%s: %s)" % [tag, tn.text])
		var tw2: String = await Tap.tap(box.find_child("TagPickerGrid_", true, false))
		await _settle()
		_check(tw2 == "" and tn.text.begins_with("No tag"), "Back to no tag, the line says so (%s)" % tag)
		await Tap.tap(named)
		await _settle()

	# Play through, three calls: each offers only the men who fill its job, and
	# its note says his job and what it does; with nobody, what that means. Real taps.
	var notes = load("res://scripts/ui/match/MatchNotes.gd")
	var me := int(m.get("_my_side"))
	var ground: Array = _state.pending_sim.squads[me].ground
	var slot_jobs := {"focus_mid": ["MID", "our midfield pillar", "the ball goes to him more often through the midfield"],
			"focus_fwd": ["FWD", "our key forward target", "more of the ball up forward and more of the shots at goal"],
			"focus_def": ["DEF", "our backline distributor", "first use of the ball out of the back half"]}
	for slot in slot_jobs:
		var fnote: Label = box.find_child("FocusNote_" + slot, true, false)
		_check(fnote != null and fnote.text.begins_with("Nobody:"), "With nobody picked, %s says what that means (%s)" % [slot, tag])
		var who: Dictionary = {}
		var other_job: Dictionary = {}
		for gp in ground:
			if str(gp["role"]) == str(slot_jobs[slot][0]) and who.is_empty():
				who = gp
			if not (load("res://scripts/sim/MatchSim.gd").FOCUS_SLOT_ROLES[slot] as Array).has(str(gp["role"])) and other_job.is_empty():
				other_job = gp
		if who.is_empty():
			continue
		_check(other_job.is_empty() or box.find_child("FocusPicker_%sGrid_%s" % [slot, str(other_job["id"])], true, false) == null,
				"%s offers only the men who fill that job (%s)" % [slot, tag])
		var pick: Button = box.find_child("FocusPicker_%sGrid_%s" % [slot, str(who["id"])], true, false)
		if pick == null:
			await Tap.tap(box.find_child("FocusPicker_%sOther" % slot, true, false))
			await _settle()
			pick = m.find_child("Sheet_" + str(who["id"]), true, false)
		var pw: String = await Tap.tap(pick)
		await _settle()
		var nm := str(db.player_display_name_by_id(str(who["id"]), ""))
		fnote = box.find_child("FocusNote_" + slot, true, false)
		_check(pw == "" and fnote.text == "%s is %s: %s." % [nm, str(slot_jobs[slot][1]), str(slot_jobs[slot][2])],
				"%s reads as his job (%s: %s)" % [slot, tag, fnote.text])
		_check(notes.focus_slot_note(slot, nm, false, true) == "%s is on the bench: the call waits until he is back on." % nm,
				"A benched man's call says it waits (%s)" % slot)
		await Tap.tap(box.find_child("FocusPicker_%sGrid_" % slot, true, false))
		await _settle()
		_check(box.find_child("FocusNote_" + slot, true, false).text.begins_with("Nobody:"), "Picking no one brings the line back (%s, %s)" % [slot, tag])

	# Start with a tag: the plan line names every call, in full, and nothing
	# it sits above is pushed off the screen.
	var go: Button = box.find_child("StartQuarter", true, false)
	var gw: String = await Tap.tap(go)
	_check(gw == "", "A finger starts the quarter (%s: %s)" % [tag, gw])
	await _settle()
	var side := int(m.get("_my_side"))
	var longest := func(roster: Array) -> String:
		var best := ""
		for r in roster:
			var id := str(r["id"])
			if db.player_display_name_by_id(id, "").length() > db.player_display_name_by_id(best, "").length():
				best = id
		return best
	var mine: Array = m.call("_roster_side", side)
	var theirs: Array = m.call("_roster_side", 1 - side)
	var defs := mine.filter(func(r): return str(r["role"]) == "DEF")
	var calls := {"gameplan": "defensive", "tag_id": longest.call(theirs), "focus_id": longest.call(mine),
			"interceptor_id": longest.call(defs), "spare_accountable": false}
	m.call("_show_setup", calls)
	await _settle()
	var line: Label = m.find_child("SetupLine", true, false)
	var jobs := {"MID": "our key midfielder", "FWD": "our key forward target",
			"DEF": "our key distributor", "RUCK": "our key man in the middle"}
	var focus_role := ""
	for r in mine:
		if str(r["id"]) == str(calls["focus_id"]):
			focus_role = str(r["role"])
	var full := "Your plan: Defensive press  ·  tagging %s  ·  %s %s  ·  %s loose behind the ball" % [
			db.player_display_name_by_id(str(calls["tag_id"]), ""), db.player_display_name_by_id(str(calls["focus_id"]), ""),
			str(jobs[focus_role]), db.player_display_name_by_id(str(calls["interceptor_id"]), "")]
	_check(line != null and line.visible and line.text == full, "The plan line names every call (%s)" % tag)
	_check(line.autowrap_mode != TextServer.AUTOWRAP_OFF and line.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
			"The plan line wraps, it does not trim (%s)" % tag)
	_check(line.size.y >= line.get_minimum_size().y - 0.5 and line.get_line_count() >= 1 and line.get_visible_line_count() == line.get_line_count(),
			"Every line of the plan is drawn (%s: %d lines)" % [tag, line.get_line_count()])
	var win := Rect2(Vector2.ZERO, Vector2(sz))
	_check(win.encloses(line.get_global_rect()), "The plan line sits on the screen (%s)" % tag)
	var off := []
	for b in m.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not win.encloses(b.get_global_rect()):
			off.append(str(b.name))
	_check(off.is_empty(), "A long plan line pushes no button off the screen (%s: %s)" % [tag, str(off)])
	m.queue_free()
	await _settle()


## Tag targets are midfielders only, in the suggestions and in "Other
## player...", by where each plays now (the director's PC playtest,
## 2026-10-07). Their ruck is put in a midfield slot and a midfielder in the
## ruck: the roster copy would call the ruck a midfielder. Real taps.
func _tag_targets(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the tag targets (%s)" % tag)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var opp: Object = sim.squads[1 - me]
	var Rt = load("res://scripts/sim/Ratings.gd")
	var ri := -1
	var mi := -1
	for i in range(opp.ground.size()):
		var r := str(opp.ground[i]["role"])
		if r == "RUCK" and ri < 0:
			ri = i
		if r == "MID" and mi < 0:
			mi = i
	_check(ri >= 0 and mi >= 0, "The other side has a ruck and a midfielder (%s)" % tag)
	var ruck: Dictionary = (opp.ground[ri] as Dictionary).duplicate(true)
	ruck["role2"] = ""
	var mid: Dictionary = opp.ground[mi]
	opp.ground[mi] = Rt._for_slot(ruck, "MID")
	opp.ground[ri] = Rt._for_slot(mid, "RUCK")
	var ruck_id := str(ruck["id"])
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The break opens for the tag targets (%s)" % tag)
	if box == null:
		m.queue_free()
		return
	var eligible := {}
	for p in opp.ground:
		if sim.tag_target_ok(1 - me, str(p["id"])):
			eligible[str(p["id"])] = true
	_check(eligible.size() >= 3 and not eligible.has(ruck_id), "Only midfielders are eligible, their ruck in a midfield slot is not (%s)" % tag)
	var tag_box: Node = box.find_child("TagPicker", true, false)
	var wrong := []
	for b in tag_box.find_children("TagPickerGrid_*", "Button", true, false):
		var id := str(b.name).trim_prefix("TagPickerGrid_")
		if id != "" and not eligible.has(id):
			wrong.append(id)
	_check(wrong.is_empty(), "The suggestions are all midfielders (%s: %s)" % [tag, str(wrong)])
	var other: Button = tag_box.find_child("TagPickerOther", true, false)
	var why: String = await Tap.tap(other)
	_check(why == "", "A finger opens Other player (%s: %s)" % [tag, why])
	await _settle()
	var sheet: Node = m.find_child("PlayerSheet", true, false)
	var rows: Array = sheet.find_children("Sheet_*", "Button", true, false) if sheet != null else []
	var bad := []
	for b in rows:
		if not eligible.has(str(b.name).trim_prefix("Sheet_")):
			bad.append(str(b.name))
	_check(not rows.is_empty() and bad.is_empty() and rows.size() == eligible.size(),
			"The full list is every midfielder and nobody else (%s: %d of %d, off: %s)" % [tag, rows.size(), eligible.size(), str(bad)])
	_check(sheet != null and sheet.find_child("Sheet_" + ruck_id, true, false) == null, "Their ruck is not on the list (%s)" % tag)
	var pick: Button = rows.back() if not rows.is_empty() else null
	var picked := str(pick.name).trim_prefix("Sheet_") if pick != null else ""
	var pw: String = await Tap.tap(pick)
	await _settle()
	_check(pw == "" and box.find_child("TagPickerGrid_" + picked, true, false) != null,
			"A finger picks a midfielder from the list (%s: %s)" % [tag, pw])
	var go: Button = box.find_child("StartQuarter", true, false)
	await Tap.tap(go)
	await _settle()
	_check(str((sim.tactics[me] as Dictionary).get("tag_id", "")) == picked,
			"The tag in force is the midfielder picked (%s)" % tag)
	# The sim refuses anything else, whatever asks: no forward, no ruck. The
	# quarter has started, so the rotations may have changed who is on: read
	# the midfield again rather than trusting the list from the break.
	for p in opp.ground:
		if not sim.tag_target_ok(1 - me, str(p["id"])):
			sim.set_tactics(me, {"gameplan": "balanced", "tag_id": str(p["id"])})
			if str((sim.tactics[me] as Dictionary).get("tag_id", "")) != "":
				_check(false, "The sim refuses a tag on a %s (%s)" % [str(p["role"]), tag])
				break
	_check(str((sim.tactics[me] as Dictionary).get("tag_id", "")) == "", "A tag on anyone but a midfielder ends the tag (%s)" % tag)
	m.queue_free()
	await _settle()


## A live match is not saved: a career saved and loaded mid-match comes back
## with no match and no tag, so no stale target can survive a load.
func _tag_not_saved() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	_check(_state.prepare_interactive_match(), "A live match is prepared for the save check")
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var mid_id := ""
	for p in sim.squads[1 - me].ground:
		if sim.tag_target_ok(1 - me, str(p["id"])):
			mid_id = str(p["id"])
			break
	sim.set_tactics(me, {"gameplan": "balanced", "tag_id": mid_id})
	_check(str((sim.tactics[me] as Dictionary).get("tag_id", "")) == mid_id, "(setup) a tag is in force")
	_check(_state.save_career(), "The career saves")
	_check(_state.load_career(), "The career loads")
	_check(_state.pending_sim == null, "A load brings back no live match, so no tag survives it")
	_check(_state.prepare_interactive_match() and str((_state.pending_sim.tactics[_state.pending_sim.moment_side] as Dictionary).get("tag_id", "")) == "",
			"A match prepared after the load starts with no tag")


## Assign defensive forward (director, 2026-10-07): the heading, the question
## that names their loose defender and his club, "No defensive forward
## assigned", a card for every forward with his position, trait and Pressure,
## the same on the "Other player..." sheet; real taps; no text cut off.
func _minder_cards(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the defensive forward (%s)" % tag)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var Mu = load("res://scripts/sim/Matchups.gd")
	var spare: Dictionary = Mu.best_interceptor((sim.squads[1 - me] as Object).ground, 0.0)
	sim.set_interceptor(1 - me, str(spare.get("id", "")), false)
	var opp_club := str((sim.squads[1 - me] as Object).code)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The break opens for the defensive forward (%s)" % tag)
	if box == null:
		m.queue_free()
		return
	var block: Node = box.find_child("MinderBlock", true, false)
	var text := _text(block)
	_check(block != null and text.begins_with("Assign defensive forward"), "The control is headed Assign defensive forward (%s)" % tag)
	var all_text := _text(box)
	_check(not all_text.contains("Their loose defender") and not all_text.contains("Nobody"),
			"No 'Their loose defender' heading and no 'Nobody' at the break (%s)" % tag)
	var notes = load("res://scripts/ui/match/MatchNotes.gd")
	var q: Label = box.find_child("MinderQuestion", true, false)
	var want_q: String = notes.minder_question(db.player_display_name(spare), db.club_name(opp_club))
	_check(q != null and q.text == want_q and q.text.contains("(%s)" % db.club_name(opp_club)),
			"It names their loose defender and his club (%s: %s)" % [tag, "" if q == null else q.text])
	var cost: Label = box.find_child("MinderNote", true, false)
	_check(cost != null and cost.text == notes.minder_cost_line(), "One line says what it does and costs (%s)" % tag)
	var none_b: Button = box.find_child("SpareMinderPickerGrid_", true, false)
	_check(none_b != null and none_b.text == "No defensive forward assigned", "The none choice reads No defensive forward assigned (%s)" % tag)
	var fwds: Array = Mu.minder_candidates((sim.squads[me] as Object).ground)
	var cards := box.find_child("SpareMinderPicker", true, false).find_children("SpareMinderPickerGrid_*", "Button", true, false)
	var shown := 0
	var bad := []
	for b in cards:
		var id := str(b.name).trim_prefix("SpareMinderPickerGrid_")
		if id == "":
			continue
		shown += 1
		var p: Dictionary = {}
		for f in fwds:
			if str(f["id"]) == id:
				p = f
		var press := roundi(float((p.get("attr", {}) as Dictionary).get("pressure", -1.0)))
		var is_spec: bool = load("res://scripts/sim/Traits.gd").has(p, "def_forward")
		if not (b.text.contains("Pressure %d" % press) and b.text.contains("Forward") and b.text.contains("Defensive forward") == is_spec):
			bad.append(b.text)
		if b.size.y + 1.0 < b.get_combined_minimum_size().y:
			bad.append("cut: " + b.text)
	_check(shown >= 2 and bad.is_empty(), "Every card shows position, Pressure and the trait, none cut off (%s: %d cards %s)" % [tag, shown, str(bad)])
	for l in block.find_children("*", "Label", true, false):
		if l.size.y + 1.0 < l.get_combined_minimum_size().y:
			bad.append("label cut: " + l.text)
	_check(bad.is_empty(), "No line of the control is cut off (%s)" % tag)
	# A real tap on a card sets who goes.
	var first_id := ""
	for b in cards:
		var cid := str(b.name).trim_prefix("SpareMinderPickerGrid_")
		if cid != "":
			first_id = cid
			break
	var card: Button = box.find_child("SpareMinderPickerGrid_" + first_id, true, false)
	var why: String = await Tap.tap(card)
	_check(why == "", "A finger picks a forward to go (%s: %s)" % [tag, why])
	await _settle()
	# The full list: every forward, with the same facts.
	var other: Button = box.find_child("SpareMinderPickerOther", true, false)
	var ow: String = await Tap.tap(other)
	await _settle()
	var sheet: Node = m.find_child("PlayerSheet", true, false)
	var rows: Array = sheet.find_children("Sheet_*", "Button", true, false) if sheet != null else []
	var row_bad := []
	for r in rows:
		if not (r.text.contains("Pressure") and r.text.contains("Forward")):
			row_bad.append(r.text)
		if r.size.y + 1.0 < r.get_combined_minimum_size().y:
			row_bad.append("cut: " + r.text)
	_check(ow == "" and rows.size() == fwds.size() and row_bad.is_empty(),
			"Other player lists every forward with position, trait and Pressure, none cut off (%s: %d of %d %s)" % [tag, rows.size(), fwds.size(), str(row_bad)])
	var pick: Button = rows.back() if not rows.is_empty() else null
	var picked := str(pick.name).trim_prefix("Sheet_") if pick != null else ""
	var pw: String = await Tap.tap(pick)
	await _settle()
	var go: Button = box.find_child("StartQuarter", true, false)
	await Tap.tap(go)
	await _settle()
	var tactics: Dictionary = sim.tactics[me]
	_check(pw == "" and picked != "" and bool(tactics.get("spare_accountable", false)) and str(tactics.get("spare_minder_id", "")) == picked,
			"The forward picked from the list is the one sent (%s)" % tag)
	if is_instance_valid(m):
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
				looks_ok = looks_ok and t["look"] == db.figure_look(p)
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
		for anim in ["idle", "jog", "tap", "tap_b", "ready", "ready_turn"]:
			moves_ok = moves_ok and _sheet_has(VignetteFigures.BODIES[build], anim, ["front", "back"])
	_check(moves_ok and Vector2i((vig.FIGURE_SHADE as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE
			and Vector2i((vig.FIGURE_MASK as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE
			and Vector2i((vig.FIGURE_DESIGN as Texture2D).get_size()) == VignetteFigures.SHEET_SIZE / VignetteFigures.DESIGN_SCALE,
			"The figure sheets hold every move the scene plays, front and back")
	# Living players: the two ruckmen never go up as twins, and men standing in the
	# square are ready (not stock-still) and never all in step.
	var rucks: Array = tokens.filter(func(t): return str(t["slot"]) == "R")
	_check(rucks.size() < 2 or str((rucks[0]["ruck"] as Dictionary)["anim"]) != str((rucks[1]["ruck"] as Dictionary)["anim"]),
			"The two ruckmen contest with different techniques")
	vig.set("_t", 2.5)
	var picks := {}
	var standing := 0
	for t in tokens:
		if str(t["slot"]) == "R" or bool(vig.call("_moving", t)):
			continue
		var pick: Array = vig.call("_frame", t, 0.0, vig.call("_pos", t), bool(t["mine"]))
		standing += 1
		picks["%s/%d/%s" % [pick[0], pick[1], pick[2]]] = true
		moves_ok = moves_ok and str(pick[0]).begins_with("ready")
	_check(standing < 2 or (picks.size() > 1 and moves_ok), "Men standing in the square are ready, and not all in step")
	vig.set("_t", 0.0)
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
	# No choice looks recommended: every button wears the same style
	# (director's PC playtest, 2026-10-07: the filled first button read as
	# the best call).
	var looks := {}
	for b in card.find_children("Moment_*", "Button", true, false):
		var sb := (b as Button).get_theme_stylebox("normal")
		looks[str(sb.bg_color) if sb is StyleBoxFlat else "other"] = true
	_check(looks.size() == 1, "Every choice stands equal, none filled as the recommended one (%s)" % str(looks.keys()))
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
	var focus_id := _first_pick(box, "FocusPicker_focus_midGrid_")
	var tag_id := _first_pick(box, "TagPickerGrid_")
	_check(focus_id != "" and tag_id != "", "A play-through and a tag are on offer")
	if focus_id == "" or tag_id == "":
		m.queue_free()
		return
	box.find_child("FocusPicker_focus_midGrid_" + focus_id, true, false).emit_signal("pressed")
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


## The momentum meter (director, 2026-10-07): labelled, the club on top
## named, its colour from the centre; a real tap explains it and Back closes
## that; the first match you watch says what it is once.
func _momentum_meter() -> void:
	var db = root.get_node("GameDB")
	_state.set_vignettes_on(false)
	_state.set_setting("seen_momentum_intro", false)
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(390, 844)
	_state.prepare_interactive_match()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box = m.find_child("CoachBox", true, false)
	var start: Button = box.find_child("StartQuarter", true, false) if box != null else null
	if start != null:
		start.emit_signal("pressed")
	await _settle()
	var res: Dictionary = m.get("_res")
	var bar: Button = m.find_child("MomentumBar", true, false)
	var word: Label = m.find_child("MomentumWord", true, false)
	_check(bar != null and _text(bar).contains("Momentum") and word != null, "The meter is labelled Momentum")
	m.call("_track_momentum", {"mom": 0.0})
	_check(word != null and word.text == "Even", "Level, it says Even (%s)" % (word.text if word else "-"))
	m.call("_track_momentum", {"mom": 0.6})
	_check(word.text == "%s on top" % db.club_short(str(res["home"])), "Home on top is named (%s)" % word.text)
	var note: Label = m.find_child("MomentumNote", true, false)
	_check(note != null and note.visible and bool(_state.get_setting("seen_momentum_intro", false)),
			"The first match you watch says what it is, once it moves")
	m.call("_track_momentum", {"mom": -0.6})
	_check(word.text == "%s on top" % db.club_short(str(res["away"])), "Away on top is named (%s)" % word.text)
	var why: String = await Tap.tap(bar)
	await _settle()
	_check(why == "" and m.find_child("MomentumInfo", true, false) != null
			and _text(m.find_child("MomentumInfo", true, false)).contains("halves at every break"),
			"A finger on the meter explains it (%s)" % why)
	_check(m.call("handle_back") == true, "Back is handled on the explanation")
	await _settle()
	_check(m.find_child("MomentumInfo", true, false) == null, "Back closes it")
	m.queue_free()
	await _settle()
	# A later match: no note.
	_state.prepare_interactive_match()
	var m2: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m2)
	await _settle()
	m2.call("_track_momentum", {"mom": 0.6})
	var note2: Label = m2.find_child("MomentumNote", true, false)
	_check(note2 != null and not note2.visible, "The next match does not say it again")
	m2.queue_free()
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
	# Long sleeves: a player's own, from his id alone - about one in seven, one in four
	# in the wet (everyone who wears them dry still does), and the same every time.
	var dry := 0
	var wet := 0
	var kept := true
	for i in range(3000):
		var id := "gen_%d" % i
		var d := Appearance.long_sleeves(id)
		var w := Appearance.long_sleeves(id, true)
		dry += 1 if d else 0
		wet += 1 if w else 0
		kept = kept and (w or not d) and d == Appearance.long_sleeves(id)
	var fl: Dictionary = db.figure_look(fake)
	_check(dry > 360 and dry < 540 and wet > 630 and wet < 870 and kept
			and fl["long_sleeves"] == Appearance.long_sleeves(str(fake["id"])) and fl["hair_style"] == db.player_appearance(fake)["hair_style"],
			"Long sleeves are a player's own: %d of 3000 dry, %d in the wet, stable per id" % [dry, wet])
	# The figure's draw colour packs kit, sleeves and mirror so the shader reads them back.
	var sv: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var packs := true
	for kit in range(4):
		for sl in [false, true]:
			for mi in [false, true]:
				var code := int(round(float(sv.kit_code(kit, sl, mi)) * 16.0))
				packs = packs and code / 4 == kit and ((code / 2) % 2 == 1) == sl and (code % 2 == 1) == mi
	var plain: Dictionary = db.club_guernsey("COL")
	var hooped := plain.duplicate()
	hooped["sock_hoops"] = 2
	var extra: Array = (sv.figure_material([plain, hooped]) as ShaderMaterial).get_shader_parameter("kit_extra")
	_check(packs and extra.size() == 4 and is_zero_approx((extra[0] as Vector4).y) and int((extra[1] as Vector4).y) == 2,
			"A figure's draw colour carries kit, sleeves and mirror; sock hoops are off unless a kit asks")
	var chosen := {"id": "C_1", "look": {"skin": 5, "hair": 2, "hair_style": "afro", "beard": "nonsense", "scars": 9}}
	var cf: Dictionary = db.player_appearance(chosen)
	_check(cf["hair_style"] == "afro" and cf["beard"] == "clean" and not cf.has("scars")
			and db.player_looks(chosen) == {"skin": 5, "hair": 2} and int(cf["beard_colour"]) == 2,
			"A chosen look is kept where valid, a stale scars key is ignored, and its colours reach the figures")
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
		rows_ok = rows_ok and keys.has(db._look_key(d)) and int(d["skin"]) >= 1 and int(d["skin"]) <= 6 \
				and Appearance.HAIR_KEYS.has(d["hair"]) and d["status"] in ["draft", "unsure", "confirmed"] \
				and str(d["source"]).begins_with("http")
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


## Press answers keep their board and morale effects, and each says what it
## does under its button (director, 2026-10-10). A real tap on the
## accountable answer moves the board and the players exactly as its line says.
func _test_press_effects_shown(db) -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_state.media_conference = MC.pick({"club": "COL", "opponent_name": "Carlton", "round": 8,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, {})
	var opts: Array = _state.media_conference.get("options", [])
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	if hub.find_child("MediaConference", true, false) == null:
		hub.call("_show_media_conference")
		await _settle()
	var shown := opts.size() == 3
	for i in range(opts.size()):
		var line: Label = hub.find_child("MediaAnswerLine_%d" % i, true, false)
		var o: Dictionary = opts[i]
		var text := "" if line == null else line.text
		var board_ok := (int(o.get("board", 0)) > 0) == text.begins_with("The board likes it") \
				and (int(o.get("board", 0)) < 0) == text.contains("the board wanted")
		var morale_ok := (int(o.get("morale", 0)) < 0) == text.contains("hung out to dry") \
				and (int(o.get("morale", 0)) > 0) == text.contains("feel backed")
		shown = shown and line != null and line.is_visible_in_tree() and board_ok and morale_ok \
				and not text.contains("%") and not text.contains("+")
	_check(shown, "Every press answer shows what it does to the board and the players, in words")
	_state.board["confidence"] = 50
	var who: Dictionary = _state.my_list[0]
	who["morale"] = 50
	var answer: Button = hub.find_child("MediaAnswer_0", true, false)
	var o0: Dictionary = opts[0] if not opts.is_empty() else {}
	var tapped: String = await Tap.tap(answer) if answer != null else "missing"
	await _settle()
	_check(tapped == "" and _state.board_confidence() == 50 + int(o0.get("board", 0))
			and int(who["morale"]) == 50 + int(o0.get("morale", 0)) and int(o0.get("board", 0)) > 0
			and int(o0.get("morale", 0)) < 0,
			"A real tap on the accountable answer lifts the board and costs the players, as its line says (%s)" % tapped)
	if is_instance_valid(hub):
		hub.queue_free()
	_state.media_conference = {}
	await _settle()


func _settle() -> void:
	for i in range(6):
		await process_frame


# ---------------------------------------------------------------------------
# Vignettes On/Off (Settings, ROADMAP §1.11)
# ---------------------------------------------------------------------------
## The setting is in the options at a phone's size and a PC's, takes a real
## tap, and stays put across a reload of the settings.
func _vignettes_setting() -> void:
	_state.set_vignettes_on(true)
	var options = load("res://scripts/ui/OptionsSheet.gd")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		var host := Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		host.size = Vector2(sz)
		var sheet: Control = options.open(host, true)
		await _settle()
		var on: Button = sheet.find_child("SettingsVignettes_on", true, false)
		var off: Button = sheet.find_child("SettingsVignettes_off", true, false)
		_check(on != null and off != null and _text(sheet).contains("Vignettes"),
				"Settings has a Vignettes On/Off row (%s)" % tag)
		if off != null:
			_check((await Tap.tap(off)) == "", "Vignettes Off takes a real tap (%s)" % tag)
			await _settle()
			_check(not _state.vignettes_on(), "Off turns the vignettes off (%s)" % tag)
		# Battery saver: a real tap caps drawing at 30 frames a second, and Off
		# puts it back to 60.
		if tag == "390x844":
			var saver: Button = sheet.find_child("SettingsBatterySaver_on", true, false)
			var tapped: String = await Tap.tap(saver) if saver != null else "missing"
			await _settle()
			_check(tapped == "" and _state.battery_saver() and Engine.max_fps == _state.FPS_SAVER,
					"Battery saver On caps drawing at 30 a second (%s, %d)" % [tapped, Engine.max_fps])
			var normal: Button = sheet.find_child("SettingsBatterySaver_off", true, false)
			tapped = await Tap.tap(normal) if normal != null else "missing"
			await _settle()
			_check(tapped == "" and not _state.battery_saver() and Engine.max_fps == _state.FPS_NORMAL,
					"Battery saver Off puts it back to 60 (%s)" % tapped)
		host.queue_free()
		await _settle()
		# A reload: a fresh read of the settings file, and a fresh career state.
		var cfg := ConfigFile.new()
		_check(cfg.load(_state.settings_path) == OK and cfg.get_value("ui", "vignettes", true) == false,
				"Off is saved with the settings (%s)" % tag)
		_state.reset()
		_check(not _state.vignettes_on(), "Off survives a reload (%s)" % tag)
		host = Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		host.size = Vector2(sz)
		sheet = options.open(host, true)
		await _settle()
		on = sheet.find_child("SettingsVignettes_on", true, false)
		if on != null:
			_check((await Tap.tap(on)) == "", "Vignettes On takes a real tap (%s)" % tag)
			await _settle()
			_check(_state.vignettes_on(), "On turns them back on (%s)" % tag)
		# Screen size, on a desktop: a finger on TV makes the game bigger.
		var tv: Button = sheet.find_child("SettingsScreenSize_tv", true, false)
		_check(tv != null and sheet.find_child("SettingsFullscreen_on", true, false) != null,
				"Settings has Screen size and Full screen on a desktop (%s)" % tag)
		if tv != null:
			_check((await Tap.tap(tv)) == "", "TV takes a real tap (%s)" % tag)
			await _settle()
			_check(_state.screen_size() == "tv" and is_equal_approx(float(root.get_node("ScreenLayout").ui_scale), 1.6),
					"TV is kept and applied (%s)" % tag)
			_state.set_screen_size("standard")
			await _settle()
		host.queue_free()
		await _settle()


## The same seeded match, the same calls, with vignettes on and off: every
## call still comes and is made, no scene is ever built with them off, and
## the football is identical. Then the hub's Play match, the press conference
## and the awards night with them off.
func _vignettes_off_match() -> void:
	var with_on: Dictionary = await _drive_match(true)
	var with_off: Dictionary = await _drive_match(false)
	print("Vignettes on: %d scenes, calls %s, %s. Off: %d scenes, calls %s, %s." % [int(with_on["vignettes"]),
			str(with_on["kinds"]), str(with_on["score"]), int(with_off["vignettes"]), str(with_off["kinds"]),
			str(with_off["score"])])
	_check(int(with_on["vignettes"]) > 0, "With vignettes on, the match plays its scenes (%d)" % int(with_on["vignettes"]))
	_check(int(with_off["vignettes"]) == 0, "With vignettes off, no scene is built at any point (%d)" % int(with_off["vignettes"]))
	_check(not (with_off["kinds"] as Array).is_empty() and with_off["kinds"] == with_on["kinds"],
			"With vignettes off every call still comes, the same ones (%s)" % str(with_off["kinds"]))
	_check((with_off["kinds"] as Array).has("bounce") and bool(with_off["bounce_facts"]),
			"The centre ball-up call comes as a card, with its facts (%s)" % str(with_off["kinds"]))
	_check(int(with_off["chosen"]) == int(with_off["offered"]) and int(with_off["offered"]) > 0,
			"Every call offered with vignettes off is chosen by the coach (%d of %d)" % [int(with_off["chosen"]), int(with_off["offered"])])
	_check(with_off["score"] == with_on["score"], "The same result with vignettes on or off (%s v %s)"
			% [str(with_on["score"]), str(with_off["score"])])
	_check(with_off["events"] == with_on["events"], "The same match events, every one")
	_check(with_off["players"] == with_on["players"], "The same player stats")
	_state.set_bounce_scene_every_match(false)

	# The hub: Play match goes straight to the match, no banner scene.
	_state.set_vignettes_on(false)
	var db = root.get_node("GameDB")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(390, 844)
	var seen := [0]
	var watch := func(n: Node) -> void:
		if str(n.name).contains("Vignette") or str(n.name) == "PreMatch":
			seen[0] += 1
	node_added.connect(watch)
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	hub.call("_on_play_match")
	await _settle()
	_check(seen[0] == 0 and _state.pending_sim != null and current_scene != null and current_scene.name == "MatchScene",
			"Play match goes straight to the match with vignettes off (%d scenes)" % seen[0])
	if current_scene != null:
		current_scene.queue_free()
	if is_instance_valid(hub):
		hub.queue_free()
	await _settle()
	# The press conference: the question straight away, no stage.
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	_state.media_conference = {"question": "How do you rate the win?", "options": [{"label": "Proud of them"}]}
	hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	if hub.find_child("MediaConference", true, false) == null:
		hub.call("_show_media_conference")
		await _settle()
	var q: Label = hub.find_child("MediaQuestion", true, false)
	var answer: Button = hub.find_child("MediaAnswer_0", true, false)
	_check(q != null and q.is_visible_in_tree() and answer != null and answer.is_visible_in_tree()
			and hub.find_child("MediaConferenceStage", true, false) == null and seen[0] == 0,
			"The press conference asks straight away, without its stage")
	hub.queue_free()
	_state.media_conference = {}
	await _settle()
	await _test_press_effects_shown(db)
	# A promised run just ended: the sit-down is the week's one ask, and a real
	# tap on Done closes it.
	_state.backing_talk = {"player_id": "calder", "title": "Sit-down with Calder",
			"lines": ["Three games: a goal, 14 disposals a game.", "He is glad of the chance and knows there is more in him."]}
	_state.media_conference = {"question": "How do you rate the win?", "options": [{"label": "Proud of them"}]}
	hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	_check(hub.find_child("BackingTalk", true, false) != null and hub.find_child("MediaConference", true, false) == null,
			"A sit-down is the week's one ask: the press does not stack on it")
	var done: Button = hub.find_child("BackingTalkDone", true, false)
	var tapped: String = await Tap.tap(done) if done != null else "missing"
	await _settle()
	_check(tapped == "" and hub.find_child("BackingTalk", true, false) == null and not _state.backing_talk_pending(),
			"Done closes the sit-down with a real tap (%s)" % tapped)
	hub.queue_free()
	_state.media_conference = {}
	await _settle()
	# Awards night: the winner, without the stage.
	var ids := []
	for p in _state.season.lists["COL"]:
		ids.append(str(p["id"]))
	_state.season_awards = {"year": _state.season_year, "brownlow": [{"id": ids[0], "club": "COL", "votes": 30}],
		"coleman": [], "all_australian": [], "best_and_fairest": {}}
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	stage.size = Vector2(390, 844)
	var awards: Control = load("res://scripts/ui/SeasonAwards.gd").open(stage)
	await _settle()
	(awards.find_child("AwardsNext", true, false) as Button).emit_signal("pressed")
	await _settle()
	_check(awards.find_child("AwardWinner", true, false) == null and seen[0] == 0
			and _text(awards).contains(_state.award_name({"id": ids[0]})),
			"The Brownlow winner is named, without the stage")
	stage.queue_free()
	_state.season_awards = {}
	node_added.disconnect(watch)
	_state.set_vignettes_on(true)
	await _settle()


## A seeded live match played through the match screen, every call answered
## with its first choice. With the centre ball-up call forced in the last
## quarter, so the one call with a scene of its own always comes.
func _drive_match(vignettes: bool) -> Dictionary:
	var db = root.get_node("GameDB")
	_state.set_vignettes_on(vignettes)
	_state.set_bounce_scene_every_match(true)
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(390, 844)
	_state.prepare_interactive_match()
	var seen := [0]
	var watch := func(n: Node) -> void:
		var named := str(n.name).contains("Vignette")
		var script: Script = n.get_script()
		if named or (script != null and str(script.get_global_name()).ends_with("Vignette")):
			seen[0] += 1
	node_added.connect(watch)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var kinds := []
	var offered := 0
	var chosen := 0
	var bounce_facts := false
	var guard := 0
	while not bool(m.get("_fulltime_shown")) and guard < 60000:
		guard += 1
		var box = m.find_child("CoachBox", true, false)
		if box != null:
			var start: Button = box.find_child("StartQuarter", true, false)
			if start != null:
				start.emit_signal("pressed")
			await _settle()
			continue
		var card = m.find_child("MomentCard", true, false)
		if card != null:
			if not card.has_meta("counted"):
				card.set_meta("counted", true)
				offered += 1
			var pick: Button = card.find_child("Moment_0", true, false)
			if pick != null and not pick.disabled and pick.is_visible_in_tree():
				var kind := str(_state.pending_sim.pending_moment.get("kind", ""))
				kinds.append(kind)
				if kind == "bounce" and not vignettes:
					bounce_facts = card.find_child("BounceFact", true, false) != null
				pick.emit_signal("pressed")
				chosen += 1
				await _settle()
				continue
		var pitch = m.get("_pitch")
		if pitch != null and pitch.playing:
			pitch._process(0.25)
		await process_frame
	var res: Dictionary = m.get("_res")
	var out := {"vignettes": seen[0], "kinds": kinds, "offered": offered, "chosen": chosen,
		"bounce_facts": bounce_facts, "guard": guard,
		"score": "%s-%s" % [str(res.get("goals", [])), str(res.get("behinds", []))],
		"events": JSON.stringify(res.get("events", [])), "players": JSON.stringify(res.get("players", {}))}
	_check(bool(m.get("_fulltime_shown")), "The match reaches full time (vignettes %s)" % ("on" if vignettes else "off"))
	node_added.disconnect(watch)
	m.queue_free()
	await _settle()
	return out


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
