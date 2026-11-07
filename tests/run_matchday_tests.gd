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
	# Return visits: the first-visit intros (FirstVisitIntro.gd) have their own suite.
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		_state.set_setting("seen_%s_intro" % key, true)
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
	# and the break would differ from run to run.
	_state.replay_seed = 2026
	for sz in [Vector2i(420, 860), Vector2i(360, 740)]:
		await _t("_test_phone_match", [sz])
	await _t("_test_ground_fit")
	_state.replay_seed = SUITE_SEED
	await _t("_test_plan_at_first_bounce")
	await _t("_test_break_panes_layout")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _t("_test_coach_descriptions", [sz])
		await _t("_test_tag_targets", [sz])
		await _t("_test_minder_cards", [sz])
		await _t("_test_df_how_its_going", [sz])
		await _t("_test_loose_interceptor", [sz])
		await _t("_test_best_so_far", [sz])
		await _t("_test_one_line_break", [sz])
	for sz in [Vector2i(390, 844), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		await _t("_test_tag_tap_keeps_columns", [sz])
	_t("_test_break_units_keep_followups")
	_t("_test_break_packing_is_shortest")
	_t("_test_club_ink_all")
	for club in ["COL", "GWS", "STK"]:
		await _t("_test_pc_break_worst_case", [club])
	await _t("_test_tag_not_saved")
	await _t("_test_bounce_close_up")
	await _t("_test_ballup_two_scene")
	await _t("_test_playtest_bounce_scene")
	await _t("_test_rings_on_the_oval")
	await _t("_test_first_goal_line")
	await _t("_test_feed_colours")
	await _t("_test_momentum_meter")
	await _t("_test_vignettes_setting")
	await _t("_test_game_feel_effects")
	_t("_test_broken_calls")
	await _t("_test_vignettes_off_match")
	await _t("_test_match_day_setup")
	await _t("_test_match_preview")
	await _t("_test_skip_to_break")
	await _t("_test_side_keeps_calls")
	await _t("_test_match_way_poster")
	_t("_test_appearance")
	# Battery: nothing is redrawn unless it changes, and never above 60 fps.
	_t("_test_battery")
	print(Ran.line("Matchday + match screen", self, [suite]))
	quit(0 if _failures.is_empty() else 1)


## Battery: idle screens are not redrawn and frames are capped (the check written in _run).
func _test_battery() -> void:
	_check(bool(ProjectSettings.get_setting("application/run/low_processor_mode", false))
			and int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 60,
			"Idle screens are not redrawn every frame, and frames are capped at 60")


## The plan you take into a live match is the plan at the first bounce: the
## pre-bounce box shows it, Start without touching it keeps it, and a change
## in the box is what plays. Read from the engine's own record of the
## quarter (tactics_history), not from a stored setting or a label.
func _test_plan_at_first_bounce() -> void:
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


func _test_ground_fit() -> void:
	# The wide layout and the whole-ground camera follow the screen's shape, not
	# the platform: the web build (is_desktop() false) gets them on a PC-sized
	# window, and a phone-sized one keeps the close-up (director, 2026-10-12).
	var sl = load("res://scripts/core/ScreenLayout.gd")
	var db = root.get_node("GameDB")
	sl.force_web = true
	_check(sl.roomy(1280.0, 720.0) and sl.roomy(1920.0, 1080.0) and not sl.roomy(390.0, 844.0),
			"Wide layouts follow the window's shape, on the web as on a desktop")
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(390, 844)]:
		_state.reset()
		_state.replay_seed = 2026
		_state.start_season("COL", db.club_list("COL"))
		root.size = sz
		_state.prepare_interactive_match()
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		var pitch = m.get("_pitch")
		var wide: bool = sz.x > sz.y
		_check(not pitch.camera_enabled and pitch.upright == not wide,
				"The whole ground shows, left to right in a wide window and top to bottom on a phone held upright, web or not (%dx%d: camera %s, upright %s)" % [
				sz.x, sz.y, str(pitch.camera_enabled), str(pitch.upright)])
		if wide:
			var panel: Control = m.get("_side_panel")
			var ground: Rect2 = pitch.call("pitch_rect")
			var gr := Rect2((pitch as Control).get_global_rect().position + ground.position, ground.size)
			_check((pitch as Control).get_global_rect().encloses(gr) and (pitch as Control).get_global_rect().end.x <= panel.get_global_rect().position.x + 1.0,
					"The whole ground sits inside the pitch, left of the side panel (%dx%d)" % [sz.x, sz.y])
		m.queue_free()
		await _settle()
	sl.force_web = false
	# A phone's browser (web_android / web_ios) is a phone: the close-up camera and
	# its own layouts, wide window or not (a phone turned sideways), and "Tap".
	sl.force_web_phone = true
	_check(not sl.roomy(844.0, 390.0) and sl.tap_word() == "Tap" and not sl.is_desktop(),
			"A phone's browser, even turned sideways (844x390), keeps the phone layouts and says Tap")
	_state.reset()
	_state.replay_seed = 2026
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(844, 390)
	_state.prepare_interactive_match()
	var side: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(side)
	await _settle()
	_check(side.get("_pitch").camera_enabled and not side.get("_pitch").upright,
			"A phone sideways keeps the close-up camera, the ground left to right")
	side.queue_free()
	await _settle()
	sl.force_web_phone = false
	_check(sl.tap_word() == "Click", "Click on a desktop or a PC browser")


func _test_phone_match(sz: Vector2i) -> void:
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

	# Before the bounce: the calls, no report.
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null, "The match opens on your calls (%s)" % tag)
	var text := _text(box)
	for n in ["PlanPicker", "TagPicker", "PepPicker", "LegsView", "TagNote"]:
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
	# A tag is a midfield job, offered on their listed midfielders only: each
	# is a name here or behind "Other midfielder...", which is not drawn when
	# every one of them is already a name.
	var tag_sim = _state.pending_sim
	var opp_side: Array = (m.get("_res")["roster"][1 - int(m.get("_my_side"))] as Array).filter(
			func(r): return bool(m.call("_taggable_now", tag_sim, r)) and bool(m.call("_can_play_midfield", tag_sim, r)))
	var named := tag_choices.size() - 1
	_check((tag_other != null and tag_other.text == "Other player…") or named == opp_side.size(),
			"Every listed midfielder is a name or behind Other midfielder (%s: %d of %d named)" % [tag, named, opp_side.size()])
	if tag_other != null:
		tag_other.emit_signal("pressed")
		await _settle()
		var sheet: Node = m.find_child("PlayerSheet", true, false)
		_check(sheet != null and sheet.find_children("Sheet_*", "Button", true, false).size() == opp_side.size() - named,
				"The list behind it has their other listed midfielders, each once (%s)" % tag)
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
	var setup: Control = m.find_child("SetupLine", true, false)
	_check(setup != null and setup.visible and _plain(setup).contains("tagging "),
			"The live screen says your gameplan and who you are tagging (%s: %s)" % [tag, _plain(setup) if setup else "-"])
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
	_check(not bt.contains(" def ") and not bt.contains("defeated"), "The break shows no result words (%s)" % tag)
	_check(bt.contains("Tag on ") and box.find_child("CallsDid", true, false) != null,
			"The break says what your calls did, your tag among them (%s)" % tag)
	var dn: Node = box.find_child("CallsDidNote", true, false)
	_check(dn != null and _plain(dn) == load("res://scripts/ui/match/MatchNotes.gd").CALLS_DID_NOTE,
			"What your calls did says what its numbers are (%s)" % tag)
	var qh: Label = box.find_child("QuarterHeading", true, false)
	_check(qh != null and qh.text == "First quarter" and not bt.contains("What's happening"),
			"Quarter time leads with the quarter just played, by name (%s)" % tag)
	# One line a call from quarter time on: each call's row is in view, its
	# choices one tap behind it (the pickers are still on the break).
	var rows_seen := true
	for rk in ["plan", "tag", "pep"]:
		var call_row: Control = box.find_child("CallRow_" + rk, true, false)
		rows_seen = rows_seen and call_row != null and call_row.is_visible_in_tree()
	_check(box.find_child("MoreCallsToggle", true, false) == null and rows_seen
			and box.find_child("PlanPicker", true, false) != null and box.find_child("TagPicker", true, false) != null
			and box.find_child("PepPicker", true, false) != null and box.find_child("RotationPicker", true, false) == null,
			"Every call is in view at the break, with no More calls button (%s)" % tag)
	_check((box.find_child("BreakColumns", true, false) != null) == bool(m.call("_wide_break")),
			"A wide PC window lays the break out in columns; a phone keeps one (%s)" % tag)
	# Play through (director, 2026-11-07: back, in the slot Key match-ups had):
	# a finger picks the midfield pillar, and the note under it says what the
	# pick does or that it waits.
	var fp: Node = box.find_child("FocusPicker_focus_mid", true, false)
	_check(fp != null and box.find_child("FocusPicker_focus_fwd", true, false) != null
			and box.find_child("FocusPicker_focus_def", true, false) != null,
			"The break offers the three play-through picks (%s)" % tag)
	var fbtn: Button = null
	if fp != null:
		for b2 in fp.find_children("FocusPicker_focus_midGrid_*", "Button", true, false):
			if str(b2.name) != "FocusPicker_focus_midGrid_" and fbtn == null:
				fbtn = b2
	# Required: without a player to pick the checks below would be skipped.
	_check(fbtn != null, "The midfield pick offers a player (%s)" % tag)
	if fbtn != null:
		# Real taps from here (tests/tap.gd): a touch on the screen, not a call
		# to the handler. First, the tool itself: a sheet over the button must
		# take the tap.
		await _open_call_of(m, fbtn)
		var cover := ColorRect.new()
		cover.color = Color(0, 0, 0, 0)
		cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_child(cover)
		await _settle()
		# On a phone the call opens as its own sheet, outside the coach box.
		var fnote: Label = m.find_child("FocusNote_focus_mid", true, false)
		var note_was := fnote.text if fnote != null else ""
		var blocked: String = await Tap.tap(fbtn)
		_check(blocked != "" and fnote != null and fnote.text == note_was,
				"A tap on a covered button doesn't reach it (%s: %s)" % [tag, blocked])
		cover.queue_free()
		await _settle()
		var fid := str(fbtn.name).trim_prefix("FocusPicker_focus_midGrid_")
		var why: String = await Tap.tap(fbtn)
		_check(why == "", "A finger's tap picks the midfield pillar (%s: %s)" % [tag, why])
		await _settle()
		_check(fnote != null and fnote.text != "" and fnote.text == str(m.call("_focus_note_text", "focus_mid", fid)),
				"The note under the pick says what it does or that it waits (%s: %s)" % [tag, fnote.text if fnote != null else "none"])
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
	# From quarter time on the break is one line a call: on a phone the match
	# stats sit with Best so far, one tap from the break.
	var best_open_h: Button = box.find_child("BestSoFarOpen", true, false) if box != null else null
	if best_open_h != null:
		_check((await Tap.tap(best_open_h)) == "", "Best so far opens from the half-time break with a real tap (%s)" % tag)
		await _settle()
	var stats_b: Button = m.find_child("BreakStats", true, false) if box != null else null
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
		# One tap arrives as a touch and an emulated click in the same frame;
		# the pick must stay picked, not toggle on then off.
		var worm = bs.find_child("Worm", true, false) if bs != null else null
		if worm != null:
			bs._pick = {}
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = Vector2(worm.size.x * 0.5, 10.0)
			var click := InputEventMouseButton.new()
			click.pressed = true
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = touch.position
			worm._gui_input(touch)
			worm._gui_input(click)
		_check(worm != null and bs._pick.has("q"),
				"One tap delivered as touch and click picks the quarter once (%s)" % tag)
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
	for n in ["MatchFactors", "BestPlayers", "KeyStats", "FinalScore_0", "FinalScore_1", "StandoutVotes"]:
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
			_check(more != null and str(more.text).contains(" gained") and str(more.text).contains("disposal efficiency"),
					"His line includes metres gained and disposal efficiency (%s)" % tag)
			var one_rx := RegEx.create_from_string("(^|, )1 [a-z' -]*s(,|$)")
			_check(more != null and one_rx.search(str(more.text)) == null
					and table.detail_words("behinds", 1) == "behind" and table.detail_words("behinds", 2) == "behinds"
					and table.detail_words("hit-outs to advantage", 1) == "hit-out to advantage"
					and table.detail_words("frees against", 1) == "free against"
					and table.detail_words("frees against", 2) == "frees against"
					and table.detail_words("metres gained", 1) == "metre gained"
					and table.detail_words("inside 50s", 1) == "inside 50",
					"A count of one reads singular: 1 behind, 1 hit-out to advantage (%s)" % tag)
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
func _test_coach_descriptions(sz: Vector2i) -> void:
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

	# Pep talk: all four choices, Composed included, explain themselves.
	var pep_seen := {}
	for k in ["steady", "fire_up", "calm", "heat"]:
		var b: Button = box.find_child("PepPicker_" + k, true, false)
		var w: String = await Tap.tap(b)
		_check(w == "", "A finger picks the %s pep talk (%s: %s)" % [k, tag, w])
		await _settle()
		var note: Control = box.find_child("PepNote", true, false)
		_check(note != null and note.is_visible_in_tree() and _flat(_text(note)) != "" and _flat(_text(note)) == _flat(report.pep_summary(k)),
				"The %s pep talk shows its own description (%s)" % [k, tag])
		pep_seen[_flat(_text(note)) if note != null else ""] = true
	_check(pep_seen.size() == 4, "Each pep talk has its own words (%s)" % tag)
	var composed: Button = box.find_child("PepPicker_steady", true, false)
	await Tap.tap(composed)
	await _settle()
	var pn: Control = box.find_child("PepNote", true, false)
	_check(pn != null and _text(pn).begins_with("Keep them as they are"), "Back on Composed, its words return (%s)" % tag)

	# Tag: "No tag" says so; a name brings the tagger line back.
	var tn: Control = box.find_child("TagNote", true, false)
	var none: Button = box.find_child("TagPickerGrid_", true, false)
	_check(tn != null and none != null and _plain(tn).begins_with("No tag"), "With no tag, the tag line says so (%s: %s)" % [tag, _plain(tn) if tn else "-"])
	var named: Button = null
	for b in box.find_child("TagPicker", true, false).find_children("TagPickerGrid_*", "Button", true, false):
		if str(b.name) != "TagPickerGrid_":
			named = b
			break
	_check(named != null, "A player can be tagged (%s)" % tag)
	if named != null:
		var tw: String = await Tap.tap(named)
		await _settle()
		_check(tw == "" and _plain(tn).contains(" tags "), "Picking a player brings the tagger line (%s: %s)" % [tag, _plain(tn)])
		var tw2: String = await Tap.tap(box.find_child("TagPickerGrid_", true, false))
		await _settle()
		_check(tw2 == "" and _plain(tn).begins_with("No tag"), "Back to no tag, the line says so (%s)" % tag)
		await Tap.tap(named)
		await _settle()
		# Who tags: your assistant's man first, another midfielder a real tap away.
		var who_box: Node = box.find_child("TaggerPicker", true, false)
		var mine_btn: Button = null
		if who_box != null:
			for b in who_box.find_children("TaggerPickerGrid_*", "Button", true, false):
				if str(b.name) != "TaggerPickerGrid_":
					mine_btn = b
					break
		_check(who_box != null and mine_btn != null, "You are offered who goes to the tag (%s)" % tag)
		var dflt: Button = who_box.find_child("TaggerPickerGrid_", true, false) if who_box != null else null
		# The card's words are kept on the button (its labels are children); the
		# trade is his season Player rating, never his disposals (director, 2026-10-13).
		var words := func(b: Button) -> String: return str(b.get_meta("card_text", b.text))
		var gives := func(t: String) -> bool:
			var gv: String = load("res://scripts/sim/GateOdds.gd").tag_gives()
			return t.contains("Gives up " + gv.left(1).to_upper() + gv.substr(1) + " (") and t.contains("their man keeps ") and not t.contains("disposals") 					and (t.contains("season rating ") or t.contains("yet to play this season"))
		_check(dflt != null and gives.call(words.call(dflt)) and words.call(dflt).contains("Your assistant's pick")
				and mine_btn != null and gives.call(words.call(mine_btn)),
				"Your assistant's tagger shows what he gives up, like the others, marked as the pick (%s: %s)" % [tag, words.call(dflt).replace("
", " / ") if dflt else "-"])
		# Name bold on top, three labelled facts, the pick a quiet label on his card, your club's rule.
		var cards: Array = who_box.find_children("Card_TaggerPickerGrid_*", "Control", true, false) if who_box != null else []
		var shaped := not cards.is_empty()
		for cd in cards:
			shaped = shaped and cd.find_child("CardName", true, false) != null and cd.find_child("ClubRule", true, false) != null 					and (cd.find_child("CardFacts", true, false) as Container).get_child_count() >= 3
		_check(shaped, "Each Who tags card is a name, three labelled facts and your club's rule (%s)" % tag)
		_check(dflt != null and dflt.get_parent().find_child("CardPick", true, false) != null
				and cards.filter(func(cd): return cd.find_child("CardPick", true, false) != null).size() == 1,
				"Only your assistant's pick carries the pick label (%s)" % tag)
		if cards.size() >= 2:
			# One man to a row, the column's full width, so no fact wraps a
			# word to a line (A2: half-width cards stacked "57 / their / man").
			_check((cards[1] as Control).global_position.y > (cards[0] as Control).global_position.y + 10.0
					and absf((cards[1] as Control).global_position.x - (cards[0] as Control).global_position.x) < 2.0,
					"The Who tags cards are one man to a row (%s)" % tag)
			var tall := []
			for cd in cards:
				for f in (cd as Node).find_child("CardFacts", true, false).get_children():
					for l in (f as Node).get_children():
						if l is Label and (l as Label).get_line_count() > 1:
							tall.append((l as Label).text)
			_check(tall.is_empty(), "No Who tags fact wraps inside itself (%s: %s)" % [tag, str(tall)])
		if sz.x < 800:
			var short := []
			for pk in ["TagPicker", "TaggerPicker"]:
				var pk_node: Node = box.find_child(pk, true, false)
				if pk_node != null:
					for b in pk_node.find_children("*", "Button", true, false):
						if (b as Control).is_visible_in_tree() and (b as Control).size.y < 44.0:
							short.append("%s %.0f" % [b.name, (b as Control).size.y])
			_check(short.is_empty(), "Every Tag and Who tags button is a thumb's height on a phone (%s: %s)" % [tag, ", ".join(short)])
		if mine_btn != null:
			# The card's first line is his name; the facts sit under it.
			var mine_name: String = words.call(mine_btn).split("\n")[0].strip_edges()
			var ww: String = await Tap.tap(mine_btn)
			await _settle()
			_check(ww == "" and _plain(tn).begins_with(mine_name), "The midfielder you tap is the one who goes (%s: %s; tapped %s)" % [tag, _plain(tn), mine_name])
			var wd: String = await Tap.tap(who_box.find_child("TaggerPickerGrid_", true, false))
			await _settle()
			_check(wd == "" and not _plain(tn).begins_with(mine_name), "Back to your assistant's man (%s: %s; was %s)" % [tag, _plain(tn), mine_name])

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
	var calls := {"gameplan": "defensive", "tag_id": longest.call(theirs),
			"interceptor_id": longest.call(defs), "spare_accountable": false}
	m.call("_show_setup", calls)
	await _settle()
	var line: Control = m.find_child("SetupLine", true, false)
	var full := "Your plan: Defensive press  ·  tagging %s  ·  %s loose behind the ball" % [
			db.player_display_name_by_id(str(calls["tag_id"]), ""), db.player_display_name_by_id(str(calls["interceptor_id"]), "")]
	_check(line != null and line.visible and _plain(line) == full, "The plan line names every call (%s)" % tag)
	_check(line.autowrap_mode != TextServer.AUTOWRAP_OFF and (line is RichTextLabel or line.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING),
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
func _test_tag_targets(sz: Vector2i) -> void:
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
	var named_ids := {}
	for b in tag_box.find_children("TagPickerGrid_*", "Button", true, false):
		if str(b.name) != "TagPickerGrid_":
			named_ids[str(b.name).trim_prefix("TagPickerGrid_")] = true
	var listed_ids := {}
	for id in eligible:
		if bool(m.call("_can_play_midfield", sim, {"id": id})):
			listed_ids[id] = true
	_check(other != null or named_ids.size() == listed_ids.size(),
			"Every listed midfielder is a name or behind Other midfielder (%s: %d of %d named)" % [tag, named_ids.size(), listed_ids.size()])
	var pick: Button = null
	if other != null:
		var why: String = await Tap.tap(other)
		_check(why == "" and other.text == "Other player…", "A finger opens Other midfielder (%s: %s %s)" % [tag, other.text, why])
		await _settle()
		var sheet: Node = m.find_child("PlayerSheet", true, false)
		var rows: Array = sheet.find_children("Sheet_*", "Button", true, false) if sheet != null else []
		var bad := []
		for b in rows:
			var rid := str(b.name).trim_prefix("Sheet_")
			if not listed_ids.has(rid) or named_ids.has(rid):
				bad.append(rid)
		_check(not rows.is_empty() and bad.is_empty() and rows.size() == listed_ids.size() - named_ids.size(),
				"The list is their other listed midfielders and nobody else (%s: %d of %d, off: %s)" % [tag, rows.size(), listed_ids.size() - named_ids.size(), str(bad)])
		_check(sheet != null and sheet.find_child("Sheet_" + ruck_id, true, false) == null, "Their ruck is not on the list (%s)" % tag)
		pick = rows.back() if not rows.is_empty() else null
	else:
		# Every listed midfielder is already a name: no button, pick a name.
		_check(tag_box.find_child("TagPickerGrid_" + ruck_id, true, false) == null, "Their ruck is not among the names (%s)" % tag)
		for b in tag_box.find_children("TagPickerGrid_*", "Button", true, false):
			if str(b.name) != "TagPickerGrid_":
				pick = b
	var picked := str(pick.name).trim_prefix("Sheet_").trim_prefix("TagPickerGrid_") if pick != null else ""
	var pw: String = await Tap.tap(pick)
	await _settle()
	_check(pw == "" and box.find_child("TagPickerGrid_" + picked, true, false) != null,
			"A finger picks a midfielder from the list (%s: %s)" % [tag, pw])
	var go: Button = box.find_child("StartQuarter", true, false)
	var q0 := int(sim.current_quarter)
	var gw: String = await Tap.tap(go)
	await _settle()
	# The quarter can play out in one go here, and at its end your assistant
	# makes his calls for the next one: read the tag the quarter was played on.
	var played := ""
	for h in sim.tactics_history:
		if int(h.get("quarter", 0)) == q0:
			played = str(((h["plans"] as Array)[me] as Dictionary).get("tag_id", ""))
	_check(played == picked,
			"The tag in force is the midfielder picked (%s: %s, %s against %s)" % [tag, gw, played, picked])
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


## The fullest PC break we know (director, 2026-10-11): quarter time, their
## loose defender to answer, at 1280x720 - every call in view, nothing
## scrolls, and Match stats sits with the actions.
## Walking up from a follow-up at `at` in `par`, the first sibling that starts
## a call (marked break_unit, not a follow-up itself) is its question.
func _follows_its_question(par: Node, at: int) -> bool:
	for i in range(at - 1, -1, -1):
		var n: Node = par.get_child(i)
		if n.has_meta("break_unit") and not n.has_meta("break_follow"):
			return true
	return false


## The height packer deals a break's calls into four columns so the tallest is
## as short as it can be. The units are GWS's fullest PC break with Best so far
## (heights in px, measured): the old greedy deal left a column of 551, the
## best deal is 532.
func _test_break_packing_is_shortest() -> void:
	var ms = load("res://scripts/ui/MatchScene.gd")
	var h := [333.0, 96.0, 122.0, 133.0, 124.0, 263.0, 140.0, 240.0, 122.0, 207.0, 176.0, 122.0]
	var picks: Array = ms.call("_shortest_tallest", h, 4, 1000.0)
	var seen := []
	var tallest := 0.0
	for col in picks:
		var t := 0.0
		for k in col:
			seen.append(int(k))
			t += float(h[int(k)])
		tallest = maxf(tallest, t)
	seen.sort()
	_check(picks.size() == 4 and seen == range(h.size()), "Every call lands in exactly one column (%s)" % str(seen))
	_check(tallest <= 540.0, "The tallest column is the shortest there is, not the greedy 551 (%.0f)" % tallest)
	_check((ms.call("_shortest_tallest", h, 4, tallest) as Array).is_empty(),
			"No better deal exists than the shortest one found (%.0f)" % tallest)


## The packer's grouping on a made-up break (a follow-up is the first thing in
## the next column): it stays with its question, whichever column holds it.
func _test_break_units_keep_followups() -> void:
	var ms = load("res://scripts/ui/MatchScene.gd")
	var cols := []
	for i in range(3):
		var c := VBoxContainer.new()
		cols.append(c)
	var mk := func(col: int, nm: String, unit: bool, follow: bool) -> Control:
		var n := Control.new()
		n.name = nm
		if unit:
			n.set_meta("break_unit", true)
		if follow:
			n.set_meta("break_follow", true)
		(cols[col] as Node).add_child(n)
		return n
	mk.call(0, "tag", true, false)
	mk.call(0, "tag_note", false, false)
	mk.call(1, "who_tags", true, true)
	mk.call(1, "pep", true, false)
	mk.call(2, "loose", true, false)
	mk.call(2, "loose_cards", true, true)
	var units: Array = ms.call("_break_units", cols)
	var names := PackedStringArray()
	for u in units:
		var one := PackedStringArray()
		for n in u:
			one.append(str(n.name))
		names.append(",".join(one))
	_check("|".join(names) == "tag,tag_note,who_tags|pep|loose,loose_cards",
			"A follow-up joins its question's unit, across columns (%s)" % "|".join(names))
	for c in cols:
		c.free()


## Best so far on the break (director, 2026-10-11): three of each side by match
## rating so far, the numbers the match's own player stats, a real tap on
## "All player stats" opens the full table.
func _test_best_so_far(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var notes = load("res://scripts/ui/match/MatchNotes.gd")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for Best so far (%s)" % tag)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	sim.run_quarter()
	var res: Dictionary = sim.result()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	var block: Node = box.find_child("BestSoFar", true, false) if box != null else null
	_check(block != null, "The break shows Best so far (%s)" % tag)
	if block == null:
		m.queue_free()
		await _settle()
		return
	# On a phone it is one tap from the break, in its own sheet (one line a call).
	var best_open: Button = box.find_child("BestSoFarOpen", true, false)
	if best_open != null:
		_check((await Tap.tap(best_open)) == "" and (block as Control).is_visible_in_tree(),
				"On a phone Best so far opens from the break with a real tap (%s)" % tag)
		await _settle()
	# The top three of each side, most coaches' votes first, the match rating
	# breaking a tie; the subline is the player's two best stats.
	var votes_all: Dictionary = notes.coaches_votes(res)
	var want := []
	var per_side := 3 if sz.x >= 900 else 99
	for side in [me, 1 - me]:
		for r in notes.standouts_by_votes(res, side, per_side, votes_all):
			want.append(r)
	var bad := []
	var found := 0
	for r in want:
		var row: Node = block.find_child("BestRow_%s" % str(r["id"]), true, false)
		if row == null:
			# A PC break drops the third of each side when it will not fit 720 high.
			if not sz.x >= 900:
				bad.append("missing " + str(r["id"]))
			continue
		found += 1
		var votes_l: Label = row.find_child("StandoutVotes", true, false)
		var want_votes: String = notes.votes_text(votes_all, str(r["id"]))
		if want_votes == "–":
			bad.append("%s is listed with no votes" % str(r["id"]))
		# Only the leader's total is written ("10 votes"); the rest read in order.
		var is_lead: bool = int(votes_all.get(str(r["id"]), 0)) == int(votes_all.values().max())
		if votes_l == null or (is_lead and votes_l.text != "%s votes" % want_votes) or (not is_lead and votes_l.visible):
			bad.append("%s votes %s v %s" % [str(r["id"]), votes_l.text if votes_l else "-", want_votes])
		var line_l: Label = row.find_child("StandoutLine", true, false)
		if line_l == null or line_l.text != str(r["line"]):
			bad.append("%s line %s v %s" % [str(r["id"]), line_l.text if line_l else "-", str(r["line"])])
		if row.find_child("StandoutRating", true, false) != null:
			bad.append("%s still shows a rating" % str(r["id"]))
	_check((found == want.size() or sz.x >= 900) and bad.is_empty(), "Best so far lists the best of each side with the match's own ratings (%s: %s)" % [tag, str(bad)])
	# Each side under its own club name, even numbers each; on a phone the
	# block sits below the controls, so the next quarter's choices are never
	# pushed under the pinned Start button.
	_check(block.find_child("BestClub_%d" % me, true, false) != null and block.find_child("BestClub_%d" % (1 - me), true, false) != null
			and found > 0, "Best so far has a heading per club and lists every voted player (%s: %d rows)" % [tag, found])
	for r in block.find_children("StandoutVotes", "Label", true, false):
		_check((r as Label).text != "–", "No row shows a dash for votes (%s)" % tag)
	# Every touch target in the sheet is a full 48 px bar.
	for nm in ["BestSoFarAll", "BreakStats"]:
		var lk: Control = m.find_child(nm, true, false)
		if lk != null and sz.x < 900 and lk.is_visible_in_tree():
			_check(lk.size.y >= 47.5, "%s is at least 48 px tall (%s: %.0f)" % [nm, tag, lk.size.y])
	_check(block.find_children("RatingHeading", "Label", true, false).is_empty(), "Best so far carries no rating column (%s)" % tag)
	_check(block.find_children("VotesHeading", "Label", true, false).size() == 1, "Best so far says what the votes are once, over both clubs (%s)" % tag)
	var pair_inks: Array = load("res://scripts/ui/UiKit.gd").club_ink_pair(str(res["home"]), str(res["away"]))
	# Allegiance: each side has its club-colour bar; its name and ratings are in
	# the club's readable colour (4.5:1 on the break) or plain text, never a
	# club colour that fails (Carlton, Collingwood on dark).
	var uk = load("res://scripts/ui/UiKit.gd")
	var ally_bad := []
	for side in [me, 1 - me]:
		var code := str(res["home"] if side == 0 else res["away"])
		var bar: Node = block.find_child("BestSide_%d" % side, true, false).find_child("ClubBar", true, false)
		var nm: Label = block.find_child("BestClub_%d" % side, true, false)
		if bar == null or nm == null:
			ally_bad.append("side %d missing bar/name" % side)
			continue
		if (bar as ColorRect).color != pair_inks[side]:
			ally_bad.append("%s bar is not the pair's ink" % code)
		if (bar as ColorRect).custom_minimum_size.x < 4.0:
			ally_bad.append("%s bar is under 4 px" % code)
		var ink: Color = nm.get_theme_color("font_color")
		if ink != uk.club_name_colour(pair_inks[side]):
			ally_bad.append("%s name is not the club's name colour" % code)
		if uk.contrast(ink, uk.BG) < 4.5:
			ally_bad.append("%s name contrast %.1f" % [code, uk.contrast(ink, uk.BG)])
		for rl in (bar.get_parent() as Node).find_children("StandoutVotes", "Label", true, false):
			if (rl as Label).get_theme_color("font_color") != uk.TEXT:
				ally_bad.append("%s votes are not plain bold text" % code)
		for sl in (bar.get_parent() as Node).find_children("StandoutLine", "Label", true, false):
			var wash: Color = uk.PANEL.lerp(pair_inks[side], 0.3)
			if (sl as Label).get_theme_font_size("font_size") < 14:
				ally_bad.append("%s subline under 14 px" % code)
			if uk.contrast((sl as Label).get_theme_color("font_color"), wash) < 4.5:
				ally_bad.append("%s subline contrast %.1f" % [code, uk.contrast((sl as Label).get_theme_color("font_color"), wash)])
			# The sheet itself is washed in one colour behind both clubs.
			var sheet: Color = uk.PANEL.lerp(m._wash_col(), 0.3)
			if uk.contrast((sl as Label).get_theme_color("font_color"), sheet) < 4.5:
				ally_bad.append("%s subline contrast on the sheet wash %.1f" % [code, uk.contrast((sl as Label).get_theme_color("font_color"), sheet)])
	_check(ally_bad.is_empty(), "Best so far carries each club's colour, readable (%s: %s)" % [tag, str(ally_bad)])
	# Nothing in the block is clipped: every label's text fits its width.
	var clipped := []
	for lb in block.find_children("*", "Label", true, false):
		var l := lb as Label
		if l.text == "" or not l.is_visible_in_tree():
			continue
		var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		if w > l.size.x + 1.0 and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			clipped.append("%s (%.0f > %.0f)" % [l.text, w, l.size.x])
	_check(clipped.is_empty(), "Best so far clips no text (%s: %s)" % [tag, str(clipped)])
	var plan_pick: Node = box.find_child("PlanPicker", true, false)
	if sz.x < 900 and plan_pick != null and best_open == null:
		_check((plan_pick as Control).global_position.y < (block as Control).global_position.y,
				"On a phone Best so far sits below the gameplan choices (%s)" % tag)
	var all_b: Control = m.find_child("BestSoFarAll", true, false)
	_check(all_b != null and (await Tap.tap(all_b)) == "", "All player stats takes a real tap (%s)" % tag)
	await _settle()
	var sheet: Node = m.find_child("BreakStatsSheet", true, false)
	_check(sheet != null and sheet.find_child("PlayerStats", true, false) != null,
			"...and opens the full player table (%s)" % tag)
	m.queue_free()
	await _settle()


## The break from quarter time on is one line a call (director, 2026-10-14:
## the break was "VERY busy", "a huge info dump", and "it looks bad when the
## extra buttons pop in ... when we choosing our own tagger"). Every decision
## the old break had is a row that shows its answer and opens its own call; who
## tags lives inside the Tag call from the start, so picking a tag moves
## nothing; Back closes a sheet and keeps the break; the picks made behind the
## rows are the ones the quarter starts with. Real taps throughout. Fremantle v
## Melbourne at half time (seed 2050), where Melbourne's ruck is running
## through the middle: the tag names are their listed midfielders only.
func _test_one_line_break(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var was_seed = _state.replay_seed
	_state.reset()
	_state.replay_seed = 2050
	_state.career_seed = 2050
	_state.start_season("FRE", db.club_list("FRE"))
	_state.replay_seed = was_seed
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the one-line break (%s)" % tag)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var them := str((sim.squads[1 - me] as Object).code)
	sim.run_quarter()
	sim.run_quarter()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	await _settle()
	var box: Control = m.find_child("CoachBox", true, false)
	_check(box != null and box.has_meta("one_line"), "Half time is the one-line break (%s)" % tag)
	if box == null:
		m.queue_free()
		await _settle()
		return
	var pc := bool(m.call("_wide_break"))
	var keys: Array = []
	for r in box.find_children("CallRow_*", "Button", true, false):
		keys.append(str(r.name).trim_prefix("CallRow_"))
	# Every decision the break had is still a row: none is lost.
	var want := ["plan", "pep", "tag", "pt", "def"]
	_check(not keys.has("rot") and not keys.has("mu") and not keys.has("ruck") and not keys.has("minder") and not keys.has("loose"),
			"No Rotations, Key match-ups, Main ruck or split defensive rows (%s: %s)" % [tag, str(keys)])
	var lost := want.filter(func(k): return not keys.has(k))
	_check(lost.is_empty(), "Every call has its row at the break (%s; missing %s)" % [tag, str(lost)])
	# Each call's own controls are still there, behind its row.
	var controls := {"plan": "PlanPicker", "pep": "PepPicker", "tag": "TagPicker",
			"def": "DefenceSetupPicker", "pt": "FocusPicker_focus_fwd"}
	var orphan := []
	for k in keys:
		var body: Node = m.find_child("CallBody_" + str(k), true, false)
		if body == null or body.find_child(str(controls.get(k, "")), true, false) == null:
			orphan.append(k)
	for slot in ["focus_mid", "focus_def"]:
		var pt_body: Node = m.find_child("CallBody_pt", true, false)
		if pt_body == null or pt_body.find_child("FocusPicker_" + slot, true, false) == null:
			orphan.append(slot)
	_check(orphan.is_empty(), "Every call keeps its own choices behind its row (%s; without %s)" % [tag, str(orphan)])
	# A row says its answer now.
	var plan_row: Button = box.find_child("CallRow_plan", true, false)
	var plan_label := ""
	for g in ((m.get_script() as Script).get_script_constant_map()["GAMEPLANS"] as Array):
		if str(g[0]) == str(m.call("_current_plan", sim)):
			plan_label = str(g[1])
	_check(plan_row != null and _plain(plan_row.get_meta("answer")) == plan_label and plan_label != "",
			"The Game plan row says the plan in force (%s: %s)" % [tag, plan_label])
	var tag_row: Button = box.find_child("CallRow_tag", true, false)
	_check(tag_row != null and _plain(tag_row.get_meta("answer")) == "No tag"
			and not (tag_row.get_meta("changed") as Label).visible, "The Tag row says No tag, and is not marked changed (%s)" % tag)
	# The break fits the screen: nothing to scroll for.
	var fit := _break_fit(box)
	_check(fit[0] <= fit[1] + 1.0, "The break fits the screen without scrolling (%s: %.0f of %.0f)" % [tag, fit[0], fit[1]])
	var small := []
	for r in box.find_children("CallRow_*", "Button", true, false):
		if (r as Button).size.y < 43.5:
			small.append(str(r.name))
	_check(small.is_empty(), "Every call row is thumb-sized (%s: %s)" % [tag, str(small)])
	# Every row takes a real tap and opens its call; Back closes it, the break stays.
	var deaf := []
	var unopened := []
	var overflow := []
	var kept := true
	for k in keys:
		var row: Button = box.find_child("CallRow_" + str(k), true, false)
		var why: String = await Tap.tap(row)
		await _settle()
		if why != "":
			deaf.append("%s (%s)" % [k, why])
			continue
		var body: Control = m.find_child("CallBody_" + str(k), true, false)
		if pc:
			var pane: Node = box.find_child("CallPane", true, false)
			if pane == null or str(pane.get_meta("call", "")) != str(k) or body == null or not body.is_visible_in_tree():
				unopened.append(k)
			var f := _break_fit(box)
			if f[0] > f[1] + 1.0:
				overflow.append("%s %.0f of %.0f" % [k, f[0], f[1]])
		else:
			var sheet: Node = m.find_child("CallSheet_" + str(k), true, false)
			if sheet == null or body == null or not sheet.is_ancestor_of(body) or not body.is_visible_in_tree():
				unopened.append(k)
			kept = kept and m.call("handle_back") == true
			await _settle()
			if m.find_child("CallSheet_" + str(k), true, false) != null or m.find_child("CoachBox", true, false) == null:
				kept = false
	_check(deaf.is_empty(), "Every call row takes a real tap (%s: %s)" % [tag, str(deaf)])
	_check(unopened.is_empty(), "Every row opens its own call (%s: %s)" % [tag, str(unopened)])
	if pc:
		_check(overflow.is_empty(), "Every call fits beside the list on the PC sheet, nothing scrolls (%s: %s)" % [tag, str(overflow)])
	else:
		_check(kept, "Back closes a call's sheet and keeps the break (%s)" % tag)

	# The tag: its names are their listed midfielders, who tags is there before
	# a tag is picked, and picking one moves nothing.
	await Tap.tap(tag_row)
	await _settle()
	# Loaded, not named: the autoloads are not there when this script compiles.
	var rt = load("res://scripts/sim/Ratings.gd")
	var tp: Node = m.find_child("TagPicker", true, false)
	var names: Array = []
	var not_listed := []
	var pick: Button = null
	for b in (tp.find_children("TagPickerGrid_*", "Button", true, false) if tp != null else []):
		var id := str(b.name).trim_prefix("TagPickerGrid_")
		if id == "":
			continue
		names.append(db.player_display_name_by_id(id, id))
		if pick == null:
			pick = b
		var p: Dictionary = sim._on_ground(1 - me, id)
		if not p.is_empty() and not rt.positions(p).has("MID"):
			not_listed.append(names.back())
	_check(pick != null and not_listed.is_empty(), "The tag names are their listed midfielders only (%s: %s)" % [tag, str(not_listed)])
	if them == "MEL":
		# Max Gawn (a ruck in a midfield slot) and Jake Bowey (a defender with
		# midfield second) are both taggable in the sim at half time here.
		var through := []
		for p in (sim.squads[1 - me] as Object).ground:
			if sim.tag_target_ok(1 - me, str(p["id"])) and not rt.positions(p).has("MID"):
				through.append(str(p["id"]))
		var offered := through.filter(func(id): return tp.find_child("TagPickerGrid_" + str(id), true, false) != null)
		# Nobody who cannot play midfield is offered (with the new reading of "can
		# play midfield" there may be no such man on the ground at all).
		_check(offered.is_empty(),
				"A ruck or defender running through the middle is not among the tag names (%s: %d such, %d offered)" % [tag, through.size(), offered.size()])
		# "Other midfielder..." lists their listed midfielders not already
		# named, and is not drawn when none is left: nobody running through
		# the middle is behind it either.
		var listed_n := 0
		for r in (m.call("_roster_side", 1 - me) as Array):
			if bool(m.call("_taggable_now", sim, r)) and bool(m.call("_can_play_midfield", sim, r)):
				listed_n += 1
		var other: Button = tp.find_child("TagPickerOther", true, false)
		if other != null:
			var w_other: String = await Tap.tap(other)
			await _settle()
			var psheet: Node = m.find_child("PlayerSheet", true, false)
			var rest: Array = psheet.find_children("Sheet_*", "Button", true, false) if psheet != null else []
			var stray := []
			for b in rest:
				var rid := str(b.name).trim_prefix("Sheet_")
				if through.has(rid) or tp.find_child("TagPickerGrid_" + rid, true, false) != null:
					stray.append(rid)
			_check(w_other == "" and other.text == "Other player…" and stray.is_empty() and rest.size() == listed_n - names.size(),
					"Other midfielder lists only their listed midfielders not already named (%s: %d listed, %d named, %d behind, off %s%s)"
					% [tag, listed_n, names.size(), rest.size(), str(stray), (", " + w_other) if w_other != "" else ""])
			m.call("handle_back")
			await _settle()
		else:
			_check(names.size() == listed_n, "With every listed midfielder named there is no Other midfielder button (%s: %d of %d)" % [tag, names.size(), listed_n])
	else:
		_check(false, "(setup) seed 2050 draws Fremantle v Melbourne (%s: drew %s)" % [tag, them])
	var uk = load("res://scripts/ui/UiKit.gd")
	var grey := []
	for grid_name in ["PlanPicker", "TagPickerGrid", "DefenceSetupPicker"]:
		var grid: Node = m.find_child(grid_name, true, false)
		var outlined := 0
		var seen := 0
		for b in (grid.get_children() if grid != null else []):
			if not (b is Button) or str(b.name).ends_with("Other"):
				continue
			seen += 1
			if (b as Button).get_theme_color("font_color") != uk.TEXT:
				grey.append("%s is not body ink" % b.name)
			if ((b as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_width_left >= 2:
				outlined += 1
		if seen < 2 or outlined != 1:
			grey.append("%s: %d choices, %d outlined" % [grid_name, seen, outlined])
	_check(grey.is_empty(), "Game plan, Tag and Loose interceptor choices all read at body strength, only the chosen one outlined (%s: %s)" % [tag, str(grey)])
	var other_tagger: Button = m.find_child("TaggerPickerOther", true, false)
	_check(other_tagger == null or other_tagger.text == "Other tagger…",
			"Who tags names its own list Other tagger (%s: %s)" % [tag, other_tagger.text if other_tagger != null else "-"])
	var who: Control = (m.find_child("TaggerPicker", true, false) if pc else m.find_child("WhoTagsLine", true, false)) as Control
	var has_who := m.find_child("TaggerPicker", true, false) != null
	if has_who and pick != null:
		_check(who != null and who.is_visible_in_tree(), "Who tags is in the Tag call before a tag is picked (%s)" % tag)
		var scope: Node = box if pc else m.find_child("CallSheet_tag", true, false)
		var before := _visible_buttons(scope)
		# On a phone the sheet is centred, and a tag note that wraps to a second
		# line below Who tags re-centres the whole sheet: measure Who tags from
		# the sheet's own title, so only a move inside the sheet counts.
		var top: Control = null if pc or scope == null else scope.find_child("CallSheetTitle", true, false) as Control
		var who_y := (who.global_position.y - (top.global_position.y if top != null else 0.0)) if who != null else -1.0
		var w_pick: String = await Tap.tap(pick)
		await _settle()
		var after := _visible_buttons(scope)
		var who_y2 := (who.global_position.y - (top.global_position.y if top != null else 0.0)) if who != null else -1.0
		_check(w_pick == "" and after == before and who != null and (pc or top != null) and absf(who_y2 - who_y) < 0.5,
				"Picking a tag adds no buttons and moves nothing (%s: %d then %d buttons, Who tags at %.1f then %.1f%s)" % [tag, before, after,
				who_y, who_y2, (", " + w_pick) if w_pick != "" else ""])
		var picked_id := str(pick.name).trim_prefix("TagPickerGrid_")
		# Who tags: choose another man with a real tap.
		var other_card: Button = null
		if not pc:
			var w_change: String = await Tap.tap(m.find_child("WhoTagsChange", true, false))
			await _settle()
			_check(w_change == "" and m.find_child("CallSheet_who", true, false) != null, "Change opens who tags as its own sheet (%s%s)" % [tag, (": " + w_change) if w_change != "" else ""])
		for b in m.find_child("TaggerPicker", true, false).find_children("TaggerPickerGrid_*", "Button", true, false):
			if str(b.name) != "TaggerPickerGrid_" and other_card == null:
				other_card = b
		var w_card: String = await Tap.tap(other_card)
		await _settle()
		var tagger_id := str(other_card.name).trim_prefix("TaggerPickerGrid_") if other_card != null else ""
		if not pc:
			_check(m.call("handle_back") == true, "Back is handled on who tags (%s)" % tag)
			await _settle()
			_check(m.find_child("CallSheet_who", true, false) == null and m.find_child("CallSheet_tag", true, false) != null,
					"Back closes who tags and keeps the Tag sheet (%s)" % tag)
			var who_name: Label = m.find_child("WhoTagsName", true, false)
			_check(who_name != null and who_name.text == db.player_display_name_by_id(tagger_id, "?"),
					"The Tag sheet names the man you chose (%s: %s)" % [tag, who_name.text if who_name != null else "-"])
			var w_done: String = await Tap.tap(m.find_child("CallSheet_tag", true, false).find_child("CallDone", true, false))
			await _settle()
			_check(w_done == "" and m.find_child("CallSheet_tag", true, false) == null, "Done closes the Tag sheet (%s%s)" % [tag, (": " + w_done) if w_done != "" else ""])
		var said := _plain(tag_row.get_meta("answer"))
		var surname: String = db.player_display_name_by_id(picked_id, "?").get_slice(" ", 1)
		_check(w_card == "" and said.contains(surname) and said.contains(", by ") and (tag_row.get_meta("changed") as Label).visible,
				"The Tag row says who is tagged and by whom, marked changed this break (%s: %s)" % [tag, said])
		# A plan change behind its row, then Start quarter: the quarter starts with both.
		await Tap.tap(plan_row)
		await _settle()
		var new_plan := "contest" if str(m.call("_current_plan", sim)) != "contest" else "balanced"
		var w_plan: String = await Tap.tap(m.find_child("PlanPicker_" + new_plan, true, false))
		await _settle()
		if not pc:
			await Tap.tap(m.find_child("CallSheet_plan", true, false).find_child("CallDone", true, false))
			await _settle()
		_check(w_plan == "" and (plan_row.get_meta("changed") as Label).visible, "A plan picked behind its row marks the row changed (%s%s)" % [tag, (": " + w_plan) if w_plan != "" else ""])
		var w_start: String = await Tap.tap(m.find_child("StartQuarter", true, false))
		await _settle()
		var t: Dictionary = sim.tactics[me]
		_check(w_start == "" and m.find_child("CoachBox", true, false) == null, "Start quarter takes a real tap and closes the break (%s%s)" % [tag, (": " + w_start) if w_start != "" else ""])
		# A tag ends with its man if he goes off hurt or stops being a midfielder.
		var tag_ended := false
		for d in sim.tag_drops:
			tag_ended = tag_ended or str(d.get("id", "")) == picked_id
		for inj in sim.injuries:
			tag_ended = tag_ended or str(inj.get("id", "")) == picked_id
		_check(str(t.get("gameplan", "")) == new_plan and (str(t.get("tag_id", "")) == picked_id or (tag_ended and str(t.get("tag_id", "")) == "")) and str(t.get("tagger_id", "")) == tagger_id,
				"The quarter starts with the calls made behind the rows (%s: %s, tag %s by %s)" % [tag, str(t.get("gameplan", "")), str(t.get("tag_id", "")), str(t.get("tagger_id", ""))])
	else:
		_check(false, "(setup) a tag and a choice of tagger are on offer (%s)" % tag)
	m.queue_free()
	await _settle()


## What the break's list holds against the room it has (a break that fits does not scroll).
func _break_fit(box: Node) -> Array:
	for sc in box.find_children("*", "ScrollContainer", true, false):
		if (sc as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			continue
		for ch in sc.get_children():
			if ch is Control and not (ch is ScrollBar):
				return [(ch as Control).get_combined_minimum_size().y, (sc as Control).size.y]
	return [INF, 0.0]


func _visible_buttons(scope: Node) -> int:
	var n := 0
	if scope != null:
		for b in scope.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree():
				n += 1
	return n


## From quarter time on a call's controls sit behind its row: open the call
## that holds `c` with a real tap on its row, as a player would.
func _open_call_of(m: Node, c: Node) -> void:
	var up: Node = c
	while up != null and not str(up.name).begins_with("CallBody_"):
		up = up.get_parent()
	if up == null or (up as Control).is_visible_in_tree():
		return
	var row: Button = m.find_child("CallRow_" + str(up.name).trim_prefix("CallBody_"), true, false)
	if row != null:
		await Tap.tap(row)
		await _settle()


## Every club's two hand-picked inks (director, 2026-10-13: hand-picked, clash
## swap): each reads as text on the page and on a panel (4.5:1); no two clubs'
## first inks are closer than 8 in CIE76 Lab (a clear difference side by side;
## the two reds and two blues that are nearest sit at 8.8 and 9.9); and on a
## screen with both clubs, every pairing in both orders keeps the home ink and
## gives two inks at least 25 apart, so two sides are never near-identical.
## A red ink carries its bar and crest only: the name is plain TEXT.
func _test_club_ink_all() -> void:
	var uk = load("res://scripts/ui/UiKit.gd")
	var db = root.get_node("GameDB")
	var bad := []
	var codes: Array = db.clubs.keys()
	codes.sort()
	for code in codes:
		var c := str(code)
		for ink in [uk.club_ink(c), uk.club_ink_second(c)]:
			if uk.contrast(ink, uk.BG) < 4.5 or uk.contrast(ink, uk.PANEL) < 4.5:
				bad.append("%s ink %s contrast %.1f" % [c, (ink as Color).to_html(false), minf(uk.contrast(ink, uk.BG), uk.contrast(ink, uk.PANEL))])
	_check(codes.size() >= 18 and bad.is_empty(), "All %d clubs' two inks read on the page and a panel (%s)" % [codes.size(), str(bad)])
	var near := []
	for i in range(codes.size()):
		for j in range(i + 1, codes.size()):
			var a: String = codes[i]
			var b: String = codes[j]
			if a == "COL" or b == "COL":
				continue
			var d: float = uk.colour_distance(uk.club_ink(a), uk.club_ink(b))
			if d < 8.0:
				near.append("%s/%s %.1f" % [a, b, d])
	_check(near.is_empty(), "No two clubs' first inks are near-identical (%s)" % str(near))
	var pairs := 0
	var alike := []
	for h in codes:
		for a in codes:
			if h == a:
				continue
			pairs += 1
			var pr: Array = uk.club_ink_pair(str(h), str(a))
			if pr[0] != uk.club_ink(str(h)):
				alike.append("%s keeps its ink v %s" % [h, a])
			var d2: float = uk.colour_distance(pr[0], pr[1])
			if d2 < 25.0:
				alike.append("%s v %s %.1f" % [h, a, d2])
	_check(pairs >= 18 * 17 and alike.is_empty(), "Every pairing (%d, home and away) shows two inks 25 or more apart (%s)" % [pairs, str(alike)])
	var reds := ["ESS", "GCS", "MEL", "STK", "SYD"]
	var red_bad := []
	for code in codes:
		var c := str(code)
		var nm: Color = uk.club_name_colour(uk.club_ink(c))
		if reds.has(c) != (nm == uk.TEXT) and c != "COL":
			red_bad.append("%s name %s" % [c, nm.to_html(false)])
	_check(red_bad.is_empty(), "A red-ink club's name is plain TEXT, every other club's name is its ink (Adelaide's is gold since 2026-10-14) (%s)" % str(red_bad))
	# No name is painted in a raw red ink anywhere (found 2026-10-18: a Melbourne name read as the
	# primary-action red). Part 1: name markup, every club in turn.
	var ni = load("res://scripts/ui/NameInk.gd")
	var markup_bad := []
	var reds_seen := 0
	for code in codes:
		var c2 := str(code)
		var squad: Array = db.club_list(c2)
		if squad.is_empty():
			continue  # an expansion club with no list in this fixture: nothing to check
		reds_seen += 1 if reds.has(c2) else 0
		var who: String = db.player_display_name(squad[0])
		var bb: String = ni.markup(who, ni.from_clubs([c2]))
		var raw := "[color=#%s]" % uk.club_ink(c2).to_html(false)
		var shown := "[color=#%s]" % uk.club_name_colour(uk.club_ink(c2)).to_html(false)
		if not bb.contains(shown) or (reds.has(c2) and bb.contains(raw)):
			markup_bad.append("%s %s" % [c2, bb])
	_check(markup_bad.is_empty() and reds_seen == reds.size(), "Every club's player name markup uses the name colour, never a red club's raw ink (%s, %d red clubs checked)" % [str(markup_bad), reds_seen])
	# Part 2: no screen script hands a raw club ink to a name label or its font colour.
	var raw_paint := []
	var stack: Array = ["res://scripts/ui"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path + "/" + sub)
		for f in DirAccess.get_files_at(dir_path):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir_path + "/" + f)
			var n_line := 0
			for ln in src.split("\n"):
				n_line += 1
				var t: String = ln.strip_edges()
				if t.begins_with("#"):
					continue
				var paints: bool = (t.contains("lbl(") or t.contains("line(") or t.contains("ellipsis(") or t.contains("font_color")) 						and (t.contains("UiKit.club_ink(") or t.contains("UiKit.club_ink_second(")) 						and not t.contains("club_name_colour(")
				if paints:
					raw_paint.append("%s:%d" % [f, n_line])
	_check(raw_paint.is_empty(), "No screen paints a name label in a raw club ink (use UiKit.club_name_colour) (%s)" % str(raw_paint))


func _test_pc_break_worst_case(club := "COL") -> void:
	var db = root.get_node("GameDB")
	var Mu = load("res://scripts/sim/Matchups.gd")
	_state.reset()
	_state.start_season(club, db.club_list(club))
	root.size = Vector2i(1280, 720)
	_check(_state.prepare_interactive_match(), "A live match is prepared for the fullest PC break (%s)" % club)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var spare: Dictionary = Mu.best_interceptor((sim.squads[1 - me] as Object).ground, 0.0)
	sim.set_interceptor(1 - me, str(spare.get("id", "")), false)
	# Your own loose man too: from quarter time the break carries his tally
	# ("N intercepts so far"), the fullest the third column gets.
	# The defender with the longest name, and a double-figure tally: the line
	# that wraps in a narrow column.
	var mine: Dictionary = {}
	for q in (sim.squads[me] as Object).ground:
		if str(q["role"]) == "DEF" and (mine.is_empty() or db.player_display_name(q).length() > db.player_display_name(mine).length()):
			mine = q
	sim.set_interceptor(me, str(mine.get("id", "")), false)
	sim.run_quarter()
	(sim.player_stats.get(str(mine["id"]), {}) as Dictionary)["intercepts"] = 12.0
	if not sim.player_stats.has(str(mine["id"])):
		sim.player_stats[str(mine["id"])] = {"intercepts": 12.0}
	sim.set_interceptor(1 - me, str(spare.get("id", "")), true)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null and box.find_child("LooseTally", true, false) != null, "(setup) your loose man's tally is on the break")
	_check(box != null and box.find_child("BestSoFar", true, false) != null, "Best so far is on the fullest PC break (%s)" % club)
	# One line a call (director, 2026-10-14): the quarter and Best so far, the
	# rows, and the chosen call beside them. Whichever call is open, the sheet
	# fits 1280x720 with room to spare and never changes height.
	await _settle()
	var bc: Control = box.find_child("BreakColumns", true, false) if box != null else null
	_check(bc != null and box.has_meta("one_line") and box.find_child("DefenceSetupPicker_cover", true, false) != null,
			"Quarter time on a PC is the one-line break, with their loose man to cover (%s)" % club)
	var worst := 0.0
	var room := 0.0
	var tall := []
	var heights := {}
	for r in (box.find_children("CallRow_*", "Button", true, false) if box != null else []):
		var w_row: String = await Tap.tap(r)
		await _settle()
		var f := _break_fit(box)
		room = f[1]
		worst = maxf(worst, f[0])
		heights[snappedf(f[1], 1.0)] = true
		if w_row != "" or f[0] > f[1] + 1.0:
			tall.append("%s %.0f of %.0f %s" % [r.name, f[0], f[1], w_row])
	_check(tall.is_empty() and room > 0.0, "Quarter time with both loose men and your tally fits 1280x720 whichever call is open (%s: %s)" % [club, str(tall)])
	# 6 px: with every switch on, Collingwood's fullest break measures 601.
	_check(worst <= 608.0 - 6.0, "...with at least 6 px to spare (%s: %.0f of 608)" % [club, worst])
	_check(heights.size() == 1, "Choosing another call never changes the sheet's height (%s: %s)" % [club, str(heights.keys())])
	# The synergies line is a fact for the game plan: it sits in that call.
	var syn: Node = box.find_child("SynergyBlock", true, false) if box != null else null
	var plan_body: Node = box.find_child("CallBody_plan", true, false) if box != null else null
	_check(syn == null or (plan_body != null and plan_body.is_ancestor_of(syn)),
			"The synergies line sits with the game plan it informs (%s)" % club)
	# Best so far and the legs line stay beside the quarter they describe.
	var legs: Node = box.find_child("LegsView", true, false) if box != null else null
	var best_blk: Node = box.find_child("BestSoFar", true, false) if box != null else null
	_check(legs != null and best_blk != null and best_blk.get_parent() == legs.get_parent()
			and (best_blk as Control).is_visible_in_tree() and best_blk.get_index() > legs.get_index(),
			"Best so far sits under the quarter and the legs line, in view (%s)" % club)
	var stats: Button = box.find_child("BreakStats", true, false) if box != null else null
	var w: String = await Tap.tap(stats)
	_check(w == "" and m.find_child("BreakStatsSheet", true, false) != null, "Match stats opens from the actions row with a real tap (%s)" % w)
	m.queue_free()
	await _settle()
## Defensive set-up (director, 2026-11-03: Defensive forward and Loose
## interceptor are one call): the question, the shapes, your loose man's
## intercepts so far (his match stat in the sim; no loose man, no line), and
## a real tap on a shape names the men a coach would send. Real taps.
func _test_loose_interceptor(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var notes = load("res://scripts/ui/match/MatchNotes.gd")
	var Mu = load("res://scripts/sim/Matchups.gd")
	for named in [true, false]:
		_state.reset()
		_state.start_season("COL", db.club_list("COL"))
		root.size = sz
		_check(_state.prepare_interactive_match(), "A live match is prepared for the defensive set-up (%s)" % tag)
		var sim = _state.pending_sim
		var me := int(sim.moment_side)
		var loose: Dictionary = Mu.best_interceptor((sim.squads[me] as Object).ground, 0.0) if named else {}
		sim.coach_interceptor(me, str(loose.get("id", "")))
		sim.run_quarter()
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		var box: Node = m.find_child("CoachBox", true, false)
		var block: Node = box.find_child("DefenceBlock", true, false) if box != null else null
		_check(block != null, "Quarter time shows the Defensive set-up call (%s, named %s)" % [tag, named])
		if block == null:
			m.queue_free()
			await _settle()
			continue
		await _open_call_of(m, block)
		var ask: Label = block.find_child("DefenceQuestion", true, false)
		_check(ask != null and ask.text == notes.defence_question(), "The call asks how you set up behind the ball (%s)" % tag)
		var tally: Control = block.find_child("LooseTally", true, false)
		var id := str(sim.interceptor[me])
		if not named:
			_check(id == "" and tally == null, "With no loose man there is no intercepts line (%s: %s)" % [tag, id])
		else:
			var n: int = sim.intercepts_since_call(me)
			var who: String = db.player_display_name_by_id(id, "")
			_check(tally != null and _plain(tally) == notes.loose_tally_line(who, n),
					"The line says his intercepts since the call, %d (%s: %s)" % [n, tag, _plain(tally) if tally else "-"])
		var note: Label = block.find_child("DefenceNote", true, false)
		var man_b: Button = block.find_child("DefenceSetupPicker_man", true, false)
		var w: String = await Tap.tap(man_b)
		await _settle()
		_check(w == "" and note != null and note.text == notes.defence_setup_line("man", "", "", ""),
				"Man on man: every defender on his man (%s: %s)" % [tag, w])
		var loose_b: Button = block.find_child("DefenceSetupPicker_loose", true, false)
		_check(loose_b != null, "A loose defender is on offer (%s)" % tag)
		if loose_b != null:
			await _open_call_of(m, block)
			var lw: String = await Tap.tap(loose_b)
			await _settle()
			_check(lw == "", "The loose shape takes a real tap (%s: %s)" % [tag, lw])
			var done: Node = m.find_child("CallDone", true, false)
			if done != null and (done as Control).is_visible_in_tree():
				await Tap.tap(done)
				await _settle()
			_check(note.text.contains("plays loose behind the ball"), "The loose shape names who plays loose (%s: %s)" % [tag, note.text])
			# The man a coach would pick is read from the ground at the break: the
			# quarter Start plays can interchange him off before the check.
			var want := id if named else str((Mu.interceptor_candidates((sim.squads[me].ground as Array).filter(func(p): return str(p["role"]) == "DEF"))[0] as Dictionary)["id"])
			var gw: String = await Tap.tap(box.find_child("StartQuarter", true, false))
			await _settle()
			_check(gw == "" and str(sim.interceptor[me]) == want,
					"Start sends the loose man a coach would pick (%s: %s v %s)" % [tag, str(sim.interceptor[me]), want])
		m.queue_free()
		await _settle()


## A live match is not saved: a career saved and loaded mid-match comes back
## with no match and no tag, so no stale target can survive a load.
func _test_tag_not_saved() -> void:
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


## How it's going for your forward on their loose man, under the Defensive
## set-up call from quarter time on, from the sim's numbers.
func _test_df_how_its_going(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var Mu = load("res://scripts/sim/Matchups.gd")
	var Notes = load("res://scripts/ui/match/MatchNotes.gd")
	for q_done in [0, 2]:
		_state.reset()
		_state.replay_seed = SUITE_SEED
		_state.start_season("MEL", db.club_list("MEL"))
		root.size = sz
		if not _state.prepare_interactive_match():
			_check(false, "A live match is prepared for How it's going (%s)" % tag)
			return
		var sim = _state.pending_sim
		var me := int(sim.moment_side)
		for i in range(q_done):
			sim.run_quarter()
		var spare: Dictionary = sim._roaming_interceptor(1 - me)
		if spare.is_empty():
			spare = Mu.best_interceptor((sim.squads[1 - me] as Object).ground, 0.0)
			sim.set_interceptor(1 - me, str(spare.get("id", "")), false)
		var df: Dictionary = Mu.minder_candidates((sim.squads[me] as Object).ground)[0]
		var t: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
		t["spare_accountable"] = true
		t["spare_minder_id"] = str(df["id"])
		sim.set_tactics(me, t)
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		var row: Button = m.find_child("CallRow_def", true, false)
		var why: String = await Tap.tap(row)
		await _settle()
		var how: Node = m.find_child("DfHowItsGoing", true, false)
		if q_done == 0:
			_check(how == null, "No How it's going before the first bounce (%s)" % tag)
		else:
			var res: Dictionary = sim.result()
			var d: Dictionary = Notes.df_duel(res, str(df["id"]), str(spare["id"]))
			var lines: Array = Notes.df_duel_lines(d, Notes._pname(str(df["id"])).split(" ", false, 1)[-1],
					Notes._pname(str(spare["id"])).split(" ", false, 1)[-1])
			var shown := _text(how) if how != null else ""
			_check(why == "" and how != null and how.is_visible_in_tree() and shown.contains(str(lines[1]))
					and shown.contains(str(lines[0])) and shown.contains(str(d["df_rating"])) and shown.contains(str(d["roamer_rating"])),
					"A tap on Defensive set-up shows How it's going from the sim's numbers (%s: %s | %s)" % [tag, why, shown])
		m.queue_free()
		await _settle()


## Defensive set-up, the cover shapes (director, 2026-11-03): with their
## loose man up, "Cover their loose man" sends the forward a coach would
## (Matchups.minder_candidates' first) and the note names both men; with no
## loose man of theirs, no cover shape is offered. Real taps; nothing cut off.
func _test_minder_cards(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the cover shape (%s)" % tag)
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var Mu = load("res://scripts/sim/Matchups.gd")
	var spare: Dictionary = Mu.best_interceptor((sim.squads[1 - me] as Object).ground, 0.0)
	sim.set_interceptor(1 - me, str(spare.get("id", "")), false)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	var block: Node = box.find_child("DefenceBlock", true, false) if box != null else null
	_check(block != null and box.find_child("MinderBlock", true, false) == null and box.find_child("LooseBlock", true, false) == null,
			"One Defensive set-up block, no separate defensive forward or loose interceptor (%s)" % tag)
	if block == null:
		m.queue_free()
		await _settle()
		return
	await _open_call_of(m, block)
	var cover: Button = block.find_child("DefenceSetupPicker_cover", true, false)
	_check(cover != null and block.find_child("DefenceSetupPicker_both", true, false) != null,
			"With their loose man up, the cover shapes are offered (%s)" % tag)
	if cover == null:
		m.queue_free()
		await _settle()
		return
	var why: String = await Tap.tap(cover)
	await _settle()
	var fwd: Dictionary = Mu.minder_candidates((sim.squads[me] as Object).ground)[0]
	var note: Label = block.find_child("DefenceNote", true, false)
	_check(why == "" and note != null and note.text.contains(db.player_display_name(fwd)) and note.text.contains(db.player_display_name(spare)),
			"Cover names the forward sent and their loose man (%s: %s)" % [tag, note.text if note else "-"])
	var bad := []
	for l in block.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.size.y + 1.0 < l.get_combined_minimum_size().y:
			bad.append(l.text)
	_check(bad.is_empty(), "No line of the call is cut off (%s: %s)" % [tag, str(bad)])
	await Tap.tap(box.find_child("StartQuarter", true, false))
	await _settle()
	var tactics: Dictionary = sim.tactics[me]
	_check(bool(tactics.get("spare_accountable", false)) and str(tactics.get("spare_minder_id", "")) == str(fwd["id"])
			and str(sim.interceptor[me]) == "",
			"Cover sends that forward and no loose man of ours (%s)" % tag)
	if is_instance_valid(m):
		m.queue_free()
	await _settle()


func _text(node: Node) -> String:
	if node == null:
		return ""
	var out := ""
	for n in node.find_children("*", "Control", true, false):
		if n is Label or n is RichTextLabel:
			out += _plain(n) + "\n"
	return out


## The late centre-bounce call opens on a close-up of that stoppage
## (ARD-M8-007): only the players at the bounce, from this match, freezing
## before the call; the lines under it are MatchSim's own numbers; the call
## is MatchSim's and closes back to the match view.
func _test_bounce_close_up() -> void:
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
	# Two choices, no "play it straight": the second is Flood behind the ball.
	var flood: Button = card.find_child("Moment_1", true, false)
	flood.emit_signal("pressed")
	_check(sim.moments.size() == asked + 1 and str((sim.moments[-1] as Dictionary).get("kind", "")) == "bounce",
			"MatchSim takes the call")
	_check(not is_instance_valid(card) or card.name != "MomentCard", "The scene cuts back to the match")
	for i in range(40):
		await process_frame
	_check(not is_instance_valid(card), "The scene is gone once it has faded")
	m.queue_free()
	await _settle()


## Row 15: the late centre ball-up scene offers two choices,
## each with its gain and cost, both reachable by a real tap; the tap makes the call.
func _test_ballup_two_scene() -> void:
	var sz := Vector2i(360, 740)
	_state.reset()
	_state.start_season("COL", root.get_node("GameDB").club_list("COL"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared (two-choice ball-up)")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	(m.find_child("StartQuarter", true, false) as Button).emit_signal("pressed")
	await _settle()
	m.get("_pitch").pause()
	var sim = _state.pending_sim
	var me := int(m.get("_my_side"))
	sim.pending_moment = {}
	sim.moment_side = me
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim.set("_moments_this_q", 0)
	sim.set("_last_moment_chain", -1000)
	# No run of goals against still waiting for its call (it comes first).
	sim.set("_run", [0, 0])
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 9.0 + side
	_check(sim.call("_boundary_moment") and str(sim.pending_moment.get("kind", "")) == "bounce",
			"MatchSim asks the late centre-bounce call (%s)" % str(sim.pending_moment.get("kind", "-")))
	m.call("_show_moment")
	await _settle()
	var card = m.find_child("MomentCard", true, false)
	var vig = m.find_child("StoppageVignette", true, false)
	_check(card != null and vig != null, "The two-choice call opens on the close-up (art loaded, not a fallback)")
	if card == null or vig == null:
		m.queue_free()
		return
	vig.finish_now()
	await _settle()
	for i in range(30):
		await process_frame      # the call slides up (0.3 s)
	var btns := card.find_children("Moment_*", "Button", true, false)
	_check(btns.size() == 2 and card.find_child("Moment_2", true, false) == null, "Two choices on the card (%d)" % btns.size())
	var gains := 0
	var costs := 0
	for l in card.find_children("*", "Label", true, false):
		gains += 1 if (l as Label).text.begins_with("Gain: ") else 0
		costs += 1 if (l as Label).text.begins_with("Cost: ") else 0
	_check(gains == 2 and costs == 2, "Each choice says its gain and its cost (%d, %d)" % [gains, costs])
	var low := _text(card).to_lower()
	_check(not low.contains("play it straight") and not low.contains("recommend") and not low.contains("best"),
			"No third option and no advice (%s)" % _text(card))
	var asked: int = sim.moments.size()
	var played_from: int = sim.timeline.size()
	var why: String = await Tap.tap(card.find_child("Moment_1", true, false))
	_check(why == "", "A real tap on Flood behind the ball reaches it (%s)" % why)
	# The tap plays on at once (MatchScene._advance_segment) to the next call or the
	# break, and the break ends every call (MatchSim.end_quarter), so bursts may be
	# empty again by now. The timeline notes each side's calls at every chain played:
	# the flood must be in force for the play that followed the tap.
	var flood_played := false
	for e in sim.timeline.slice(played_from):
		flood_played = flood_played or (int(e["side"]) == me and (e["bursts"] as Array).has("flood"))
	_check(sim.moments.size() == asked + 1 and str((sim.moments[-1] as Dictionary).get("choice_label", "")) == "Flood behind the ball"
			and flood_played, "The tap makes the call, and the flood is on")
	m.queue_free()
	await _settle()


## The playtest switch (Settings, ARD-M8-007): the centre-bounce scene comes even
## where no call could - early in the last quarter of a blowout, the quarter's calls
## spent - and plays through the real match screen.
func _test_playtest_bounce_scene() -> void:
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
func _test_rings_on_the_oval() -> void:
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
	# Who tags is the coach's call: another midfielder on the ground takes the
	# job when named, and it goes back to the assistant's man when the named
	# player is not a midfielder on the ground.
	var MS = load("res://scripts/sim/MatchSim.gd")
	var other_mid = null
	var not_mid = null
	for p in sim.squads[me].ground:
		if MS.midfielder_on_ground(p) and tagger != null and str(p["id"]) != str(tagger["id"]) and other_mid == null:
			other_mid = p
		if not MS.midfielder_on_ground(p) and not_mid == null:
			not_mid = p
	_check(other_mid != null and not_mid != null, "The side has another midfielder to send")
	if other_mid != null and not_mid != null:
		var was: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
		sim.tactics[me]["tagger_id"] = str(other_mid["id"])
		_check(str(sim.tagger_of(me)["id"]) == str(other_mid["id"]), "The midfielder you name goes to the tag")
		_check(str(sim.tagger_of(1 - me)["id"]) == str(MS.tagger_for(sim.squads[1 - me].ground)["id"]),
				"The other side's tagger is its own")
		sim.tactics[me]["tagger_id"] = str(not_mid["id"])
		_check(str(sim.tagger_of(me)["id"]) == str(tagger["id"]), "A player who is not a midfielder on the ground cannot be sent")
		sim.tactics[me] = was
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


## Row 9: your goals read good, goals against read bad, a behind
## and a coach's call stay neutral.
func _test_feed_colours() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	_check(_state.prepare_interactive_match(), "A live match is prepared (feed colours)")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var me := int(m.get("_my_side"))
	var feed: Node = m.find_child("Feed", true, false)
	var head_col := func(row: Node) -> Color:
		var h: Control = row.get_child(1).get_child(0)
		return h.get_theme_color("default_color") if h is RichTextLabel else h.get_theme_color("font_color")
	var ui = load("res://scripts/ui/UiKit.gd")
	var goal := {"kind": "goal", "q": 1, "min": 3, "name": "Test Kicker", "goals": [1, 0], "behinds": [0, 0], "score": [6, 0]}
	goal["side"] = me
	m.call("_feed_add", goal)
	goal["side"] = 1 - me
	m.call("_feed_add", goal)
	var rows := []
	for c in feed.get_children():
		if str(c.get_meta("feed_kind", "")) == "goal":
			rows.append(c)
	_check(rows.size() == 2, "Both goals reach the feed (%d)" % rows.size())
	if rows.size() == 2:
		_check(str(rows[0].get_meta("tone")) == "good" and head_col.call(rows[0]) == ui.GOOD,
				"Your goal reads in the good colour")
		_check(str(rows[1].get_meta("tone")) == "bad" and head_col.call(rows[1]) == ui.BAD,
				"A goal against reads in the bad colour")
	var behind := {"kind": "behind", "q": 1, "min": 4, "side": me, "name": "Test Kicker", "score": [6, 1]}
	m.call("_feed_add", behind)
	var last: Node = feed.get_child(feed.get_child_count() - 1)
	_check(str(last.get_meta("feed_kind", "")) == "PlayLine"
			and (last as Control).get_theme_color("default_color" if last is RichTextLabel else "font_color") == ui.TEXT,
			"Your behind stays neutral")
	_check(load("res://scripts/ui/match/MatchNotes.gd").feed_tone({"kind": "moment", "side": me}, me) == "neutral", "A coach's call stays neutral")
	m.queue_free()
	await _settle()


## The live feed says a first AFL goal for one of yours: the screen is told who it
## could be (GameState.first_goal_candidates), and says it once, and only of them.
func _test_first_goal_line() -> void:
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
func _test_momentum_meter() -> void:
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
	# Row 78: the sheet says what a runaway does.
	why = await Tap.tap(bar)
	await _settle()
	var info_on: Node = m.find_child("MomentumInfo", true, false)
	_check(why == "" and info_on != null and _text(info_on).contains("run away with it")
			and not _text(info_on).contains("a small edge"),
			"The meter's sheet explains a runaway (%s)" % why)
	m.call("handle_back")
	await _settle()
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
func _test_appearance() -> void:
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


## Press answers are rolls with their odds shown (bible §4; director
## 2026-10-18, ch. 30 row 33): each line under an answer gives both ways it
## can land, the odds and the sizes. A real tap on the first answer applies
## the outcome the career's press stream drew, and the sheet after says so.
func _test_press_effects_shown(db) -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_state.media_conference = MC.pick({"club": "COL", "opponent_name": "Carlton", "round": 8,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, {})
	var opts: Array = _state.media_conference.get("options", [])
	_state.board["confidence"] = 50
	var who: Dictionary = _state.my_list[0]
	who["morale"] = 50
	who.erase("press_lift")
	var hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	if hub.find_child("MediaConference", true, false) == null:
		hub.call("_show_media_conference")
		await _settle()
	var shown := opts.size() == 3
	for i in range(opts.size()):
		var line: Label = hub.find_child("MediaAnswerLine_%d" % i, true, false)
		var kind: String = MC.kind_of(opts[i], i)
		var c: int = _state.press_chance(i)
		var text := "" if line == null else line.text
		shown = shown and line != null and line.is_visible_in_tree() and text == _state.press_odds_line(i) 				and text.contains("%d%% " % c) and text.contains("%d%% " % (100 - c))
		# The Muckraker's twist is on the gate (director 2026-11-06).
		if kind == "criticise":
			shown = shown and text.contains("His headline: 10% less likely") 					and not text.contains("The Siren gets read upstairs") and not text.contains(MC.FADE_NOTE)
	_check(shown, "Every press answer shows both ways it can land, with the odds and the sizes")
	var rules: Label = hub.find_child("MediaRules", true, false)
	_check(rules != null and rules.is_visible_in_tree() and rules.text == MC.rules_line(str(_state.media_conference.get("journalist", ""))),
			"How long the moves last is said once on the gate, above the answers (%s)" % ("missing" if rules == null else rules.text))
	var c0: int = _state.press_chance(0)
	var landed := "a" if MC.roll(_state.career_seed, _state.season_year, int(_state.media_conference.get("round", 0)),
			str(_state.media_conference.get("key", "")), 0) <= c0 else "b"
	var fx: Dictionary = MC.effects("criticise", _state.press_context(0))
	var out: Dictionary = fx[landed]
	var answer: Button = hub.find_child("MediaAnswer_0", true, false)
	var tapped: String = await Tap.tap(answer) if answer != null else "missing"
	await _settle()
	var after: Label = hub.find_child("MediaOutcomeLine", true, false)
	_check(tapped == "" and _state.board_confidence() == 50 + int(out["board"])
			and int(who["morale"]) == 50 + int(out["morale"]) and after != null and after.is_visible_in_tree()
			and after.text == str(load("res://scripts/ui/PressScene.gd").outcome_parts(MC.after_line("criticise", landed, fx))[0]) and int(out["board"]) == 1,
			"A real tap on the first answer applies the outcome the press stream drew, and the sheet after says how it landed (%s, %s)" % [tapped, landed])
	var done: Button = hub.find_child("MediaOutcomeDone", true, false)
	var closed: String = await Tap.tap(done) if done != null else "missing"
	await _settle()
	_check(closed == "" and hub.find_child("MediaOutcome", true, false) == null,
			"A real tap on Done closes the press outcome (%s)" % closed)
	if is_instance_valid(hub):
		hub.queue_free()
	_state.media_conference = {}
	await _settle()


## The press is its own full screen (ruling 3.52): the hub routes to it, a
## real tap answers, the result shows in the scene, and Done returns to the hub.
func _test_press_scene_routed() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var router = root.get_node("Router")
	_state.media_conference = MC.pick({"club": "COL", "opponent_name": "Carlton", "round": 8,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, {})
	router.stack = []
	router.go("hub")
	await _settle()
	await _settle()
	var press: Node = current_scene
	_check(press != null and press.name == "PressScene" and router.current() == "press"
			and press.find_child("MediaQuestion", true, false) != null,
			"A pending question opens the press conference as its own screen (%s, %s)" % [press.name if press else "-", router.current()])
	var answer: Button = press.find_child("MediaAnswer_0", true, false) if press != null else null
	var tapped: String = await Tap.tap(answer) if answer != null else "missing"
	await _settle()
	var line: Label = current_scene.find_child("MediaOutcomeLine", true, false)
	_check(tapped == "" and current_scene == press and line != null and line.is_visible_in_tree()
			and not _state.media_conference_pending(),
			"A real tap answers and the result shows in the press screen (%s)" % tapped)
	var done: Button = current_scene.find_child("MediaOutcomeDone", true, false)
	var closed: String = await Tap.tap(done) if done != null else "missing"
	await _settle()
	await _settle()
	_check(closed == "" and router.current() == "hub" and current_scene != null and current_scene.name == "HubScene"
			and current_scene.find_child("MediaConference", true, false) == null,
			"A real tap on Done returns to the hub (%s, %s)" % [closed, router.current()])
	_state.media_conference = {}


## The press screen at phone size, by real taps (director 2026-11-06, Q4):
## each of the four answers to the Muckraker (the fourth names a player) lands
## in the room and Continue returns to the hub; the Stats Geek shows the
## record; the bottom Skip, the top Skip and Android Back each skip without
## moving anything; Back after an answer leaves.
func _test_press_scene_taps() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var router = root.get_node("Router")
	_state.set_vignettes_on(false)
	root.size = Vector2i(390, 844)
	var named: Dictionary = _state.my_list[3]
	var other: Dictionary = _state.my_list[4]
	var muck := func() -> Dictionary:
		return MC.pick({"club": "COL", "opponent_name": "Carlton", "round": 8, "year": _state.season_year,
				"result": {"home": "COL", "away": "CAR", "score": [55, 101]},
				"named": {"heavy_loss": {"id": str(named["id"]), "name": str(root.get_node("GameDB").player_display_name(named))}}}, {})
	var open := func(conf: Dictionary) -> Node:
		_state.media_conference = conf
		_state.media_conference["opp"] = "Carlton"
		router.stack = []
		router.go("hub")
		await _settle()
		await _settle()
		return current_scene
	_check((muck.call() as Dictionary).get("options", []).size() == 4,
			"The Muckraker's heavy-loss question offers a fourth answer naming a player")
	for i in range(4):
		for p in _state.my_list:
			p.erase("press_lift")
			p.erase("press_wait")
		var press: Node = await open.call(muck.call())
		var label := str((_state.media_conference.get("options", [])[i] as Dictionary).get("label", ""))
		var where: Label = press.find_child("MediaWhere", true, false)
		var answer: Button = press.find_child("MediaAnswer_%d" % i, true, false)
		var tapped: String = await Tap.tap(answer) if answer != null else "missing"
		await _settle()
		var head: Label = press.find_child("MediaOutcomeLine", true, false)
		var chance: Label = press.find_child("MediaOutcomeChance", true, false)
		var said: Control = press.find_child("MediaSaid", true, false)
		var named_only := i != 3 or (int(named.get("press_lift", 0)) != 0 and not other.has("press_lift"))
		_check(tapped == "" and press.name == "PressScene" and not _state.media_conference_pending()
				and where != null and where.text == "Round 8 · v Carlton"
				and head != null and head.is_visible_in_tree() and chance != null and chance.text.ends_with("% chance.")
				and said != null and said.is_visible_in_tree() and press.find_child("MediaAnswer_0", true, false) == null
				and press.find_child("MediaTopSkip", true, false).disabled and named_only,
				"A real tap on answer %d lands it in the press screen, with its odds and only what it moves (%s; %s)" % [i, tapped, label])
		var done: Button = press.find_child("MediaOutcomeDone", true, false)
		var closed: String = await Tap.tap(done) if done != null else "missing"
		await _settle()
		await _settle()
		_check(closed == "" and router.current() == "hub" and current_scene.name == "HubScene",
				"A real tap on Continue after answer %d returns to the hub (%s)" % [i, closed])
	# The Stats Geek reads the record on the gate.
	var geek: Dictionary = MC.pick({"club": "COL", "opponent_name": "Carlton", "round": 16, "year": _state.season_year,
			"result": {"home": "COL", "away": "CAR", "score": [80, 83],
			"team": [{"inside50": 54, "clearances": 36}, {"inside50": 41, "clearances": 38}]}}, {})
	var gp: Node = await open.call(geek)
	var rec: Label = gp.find_child("MediaRecord", true, false)
	var jn: Label = gp.find_child("MediaJournalist", true, false)
	var g1: Button = gp.find_child("MediaAnswer_1", true, false)
	_check(rec != null and rec.is_visible_in_tree() and jn != null and jn.text == "Dev Mehta"
			and gp.find_child("MediaAnswer_3", true, false) == null,
			"The Stats Geek's gate shows who asks and the record line, with three answers")
	var gt: String = await Tap.tap(g1) if g1 != null else "missing"
	await _settle()
	_check(gt == "" and gp.find_child("MediaOutcomeLine", true, false) != null,
			"A real tap answers the Stats Geek in the room (%s)" % gt)
	router.handle_back(true)
	await _settle()
	await _settle()
	_check(router.current() == "hub", "Back after an answer leaves the press screen for the hub")
	# Each way of saying nothing: nothing moves and his standing stays.
	var ways := ["MediaSkip", "MediaTopSkip", "back"]
	for way in ways:
		var before: int = _state.press_standing("muckraker")
		var conf: Dictionary = muck.call()
		var key := str(conf.get("key", ""))
		_state.media_memory.erase(key)
		var sp: Node = await open.call(conf)
		var why := ""
		if way == "back":
			router.handle_back(true)
		else:
			var b: Button = sp.find_child(way, true, false)
			why = await Tap.tap(b) if b != null else "missing"
		await _settle()
		await _settle()
		_check(why == "" and router.current() == "hub" and not _state.media_conference_pending()
				and _state.media_memory.has(key) and _state.press_standing("muckraker") == before,
				"%s skips the press: back to the hub, nothing moved (%s)" % ["Android Back" if way == "back" else way, why])
	_state.media_conference = {}


func _settle() -> void:
	for i in range(6):
		await process_frame


## TODO row 25: every pre-match call sits before Start, the side included.
## Play match opens the setup; Change the side opens the same Team selection the
## hub's Team does; the new side is the one that plays. Real taps (tests/tap.gd).
func _test_match_day_setup() -> void:
	_state.set_vignettes_on(false)
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(390, 844)
	router.stack = ["hub"]
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	hub.call("_on_play_match")
	await _settle()
	var ms: Node = current_scene
	_check(ms != null and ms.name == "MatchScene" and _state.match_day_setup_open(),
			"Play match opens the match-day setup, nothing bounced yet")
	var side: Control = ms.find_child("ChangeSide", true, false) if ms != null else null
	var start: Control = ms.find_child("StartQuarter", true, false) if ms != null else null
	_check(side != null and start != null and (start as Button).text == "Start",
			"The setup has Change the side and Start (%s)" % ((start as Button).text if start else "-"))
	var sim_side: int = _state.pending_sim.moment_side
	var dropped := str(_state.pending_sim.squads[sim_side].ground[0]["id"])
	var why: String = await Tap.tap(side)
	await _settle()
	var sel: Node = current_scene
	_check(why == "" and sel != null and sel.name == "SelectionScene",
			"A tap on Change the side opens Team selection (%s)" % why)
	_state.set_selection({"OUT": [dropped]})
	if sel != null:
		sel.call("_build")
		await _settle()
	var back: Control = sel.find_child("BackToMatchDay", true, false) if sel != null else null
	why = await Tap.tap(back)
	await _settle()
	ms = current_scene
	var ids := []
	for p in _state.pending_sim.squads[sim_side].ground:
		ids.append(str(p["id"]))
	_check(why == "" and ms != null and ms.name == "MatchScene" and not ids.has(dropped)
			and _state.match_day_setup_open(),
			"Back to match day: the setup again, with the new side (%s)" % why)
	start = ms.find_child("StartQuarter", true, false) if ms != null else null
	why = await Tap.tap(start)
	await _settle()
	_check(why == "" and not _state.match_day_setup_open() and ms.find_child("ChangeSide", true, false) == null,
			"Start bounces the ball and the side is no longer open (%s)" % why)
	# The hub's Team is the same screen.
	router.stack = ["hub"]
	router.go("selection")
	await _settle()
	_check(current_scene != null and current_scene.name == "SelectionScene"
			and current_scene.find_child("BackToMatchDay", true, false) == null,
			"Team from the hub is the same Team selection, with no match-day way back")
	if current_scene != null:
		current_scene.queue_free()
	if is_instance_valid(hub):
		hub.queue_free()
	_state.pending_sim = null
	_state.side_from_match = false
	await _settle()


## The match preview (director, 2026-11-07: "It deserves its own place in the pre
## game flow"; "Own step before setup"). Real taps on a phone: Play match opens
## the preview, nothing prepared; its Back and Android Back return to the hub with
## nothing started; Continue opens the match-day setup, and full time's way back
## is the hub (the preview is not left under the match).
func _test_match_preview() -> void:
	_state.set_vignettes_on(false)
	_state.set_match_way("watch")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.tutorials = false
	root.size = Vector2i(390, 844)
	var round_at: int = _state.season.round_index
	var open_preview := func() -> String:
		router.stack = []
		router.go("hub")
		await _settle()
		var hub: Node = current_scene
		var play: Button = hub.find_child("PlayMatch", true, false) if hub != null else null
		if play == null:
			return "no Play match"
		var why: String = await Tap.tap(play)
		await _settle()
		return why
	var why: String = await open_preview.call()
	var pv: Node = current_scene
	_check(why == "" and pv != null and pv.name == "MatchPreviewScene" and _state.pending_sim == null
			and router.current() == "preview",
			"A real tap on Play match opens the match preview, nothing set up yet (%s)" % why)
	var cont: Button = pv.find_child("PreviewContinue", true, false) if pv != null else null
	var view := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(pv != null and pv.find_child("WeekPage", true, false) != null
			and pv.find_child("WeekHeading", true, false) != null
			and pv.find_child("WeekClubs", true, false) != null and pv.find_child("KeyMatchups", true, false) == null
			and pv.find_child("HeadToHead", true, false) != null
			and pv.find_child("SynergyLine", true, false) != null,
			"The preview holds the week: the round, you and them, line against line, synergies")
	_check(cont != null and cont.size.y >= 56.0 and cont.size.x >= 300.0
			and view.encloses(cont.get_global_rect()),
			"Continue is thumb-sized, across the page and on screen (%s)" % (str(cont.get_global_rect()) if cont else "-"))
	# Back (the top bar's, a real tap): the hub, nothing started.
	var back: Control = pv.find_child("TopBarBack", true, false) if pv != null else null
	why = await Tap.tap(back)
	await _settle()
	_check(why == "" and current_scene != null and current_scene.name == "HubScene" and _state.pending_sim == null
			and _state.season.round_index == round_at,
			"A real tap on Back returns to the hub with nothing started (%s)" % why)
	# Android Back: the same.
	why = await open_preview.call()
	_check(why == "" and current_scene != null and current_scene.name == "MatchPreviewScene",
			"Play match opens the preview again (%s)" % why)
	router.handle_back(true)
	await _settle()
	_check(current_scene != null and current_scene.name == "HubScene" and _state.pending_sim == null,
			"Android Back returns to the hub with nothing started")
	# Continue: the match-day setup, the preview off the back stack.
	why = await open_preview.call()
	cont = current_scene.find_child("PreviewContinue", true, false) if current_scene != null else null
	why = await Tap.tap(cont)
	await _settle()
	var ms: Node = current_scene
	_check(why == "" and ms != null and ms.name == "MatchScene" and _state.match_day_setup_open()
			and ms.find_child("StartQuarter", true, false) != null,
			"A real tap on Continue opens the match-day setup, nothing bounced yet (%s)" % why)
	_check(router.stack == ["hub", "match"], "The preview is not left under the match: %s" % str(router.stack))
	if ms != null:
		ms.queue_free()
	_state.pending_sim = null
	_state.pending_match = {}
	await _settle()


## Director's bug (2026-11-06): the calls you set on the match-day setup are
## still set after Change the side, on screen and in the match; a call the new
## side breaks (a dropped player) goes back to the assistant's pick for that
## call only. Real taps (tests/tap.gd).
func _test_side_keeps_calls() -> void:
	_state.set_vignettes_on(false)
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(390, 844)
	router.stack = ["hub"]
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	hub.call("_on_play_match")
	await _settle()
	var ms: Node = current_scene
	var sim = _state.pending_sim
	var side: int = sim.moment_side
	var taps := []
	# Every call away from what the sheet opened with.
	var plan := "attacking" if _state.club_plan != "attacking" else "contest"
	await _tap_named(ms, "PlanPicker_" + plan, taps)
	await _tap_named(ms, "PepPicker_fire_up", taps)
	var tag := _first_pick(ms.find_child("TagPicker", true, false), "TagPickerGrid_")
	await _tap_named(ms, "TagPickerGrid_" + tag, taps)
	var tagger := _first_pick(ms.find_child("TaggerPicker", true, false), "TaggerPickerGrid_")
	await _tap_named(ms, "TaggerPickerGrid_" + tagger, taps)
	var def_was := ""
	var def_key := ""
	for k in ["both", "man", "loose", "cover"]:
		if ms.find_child("DefenceSetupPicker_" + k, true, false) == null:
			continue
		if _is_chosen(ms, "DefenceSetupPicker_" + k):
			def_was = k
		elif def_key == "":
			def_key = k
	await _tap_named(ms, "DefenceSetupPicker_" + def_key, taps)
	# A forward to play through, who isn't the tagger.
	var picked := ""
	var fp: Node = ms.find_child("FocusPicker_focus_fwd", true, false)
	if fp != null:
		for b in fp.find_children("FocusPicker_focus_fwdGrid_*", "Button", true, false):
			var id := str(b.name).trim_prefix("FocusPicker_focus_fwdGrid_")
			if picked == "" and id != "" and id != tagger:
				picked = id
	await _tap_named(ms, "FocusPicker_focus_fwdGrid_" + picked, taps)
	_check(taps.is_empty() and tag != "" and tagger != "" and def_key != "" and picked != ""
			and _is_chosen(ms, "FocusPicker_focus_fwdGrid_" + picked),
			"Real taps set a plan, pep talk, tag, tagger, defensive set-up (%s, was %s) and a forward to play through (%s)"
			% [def_key, def_was, str(taps)])
	var loose_now := str(sim.interceptor[side])
	# Change the side, swap one midfielder nobody's call needs, come back.
	var busy := {tagger: true, picked: true, loose_now: true}
	var spare := ""
	for p in sim.squads[side].ground:
		if spare == "" and not busy.has(str(p["id"])) and str(p.get("role", "")) == "MID":
			spare = str(p["id"])
	await _tap_named(ms, "ChangeSide", taps)
	var sel: Node = current_scene
	_state.set_selection({"OUT": [spare]})
	sel.call("_build")
	await _settle()
	await _tap_named(sel, "BackToMatchDay", taps)
	ms = current_scene
	var nsim = _state.pending_sim
	var t: Dictionary = nsim.tactics[side]
	_check(taps.is_empty() and ms != null and ms.name == "MatchScene" and nsim != sim
			and not nsim.taking_part(side, spare),
			"Back to match day with the new side (%s)" % str(taps))
	_check(_is_chosen(ms, "PlanPicker_" + plan) and _is_chosen(ms, "PepPicker_fire_up")
			and _is_chosen(ms, "TagPickerGrid_" + tag) and _is_chosen(ms, "TaggerPickerGrid_" + tagger)
			and _is_chosen(ms, "DefenceSetupPicker_" + def_key) and _is_chosen(ms, "FocusPicker_focus_fwdGrid_" + picked),
			"After Change the side every call is still selected on the sheet")
	_check(str(t.get("gameplan", "")) == plan and str(t.get("pep", "")) == "fire_up"
			and str(t.get("tag_id", "")) == tag and str(t.get("tagger_id", "")) == tagger
			and str(t.get("focus_fwd", "")) == picked
			and str(nsim.interceptor[side]) == loose_now,
			"The new match holds the same calls (%s, loose %s/%s)" % [str(t), str(nsim.interceptor[side]), loose_now])
	# Now drop the forward played through and the tagger.
	await _tap_named(ms, "ChangeSide", taps)
	sel = current_scene
	_state.set_selection({"OUT": [spare, picked, tagger]})
	sel.call("_build")
	await _settle()
	await _tap_named(sel, "BackToMatchDay", taps)
	ms = current_scene
	var nsim2 = _state.pending_sim
	t = nsim2.tactics[side]
	_check(taps.is_empty() and nsim2 != nsim and not nsim2.taking_part(side, picked)
			and not nsim2.taking_part(side, tagger),
			"Back again without the forward played through and the tagger (%s)" % str(taps))
	_check(str(t.get("focus_fwd", "")) == "" and _is_chosen(ms, "FocusPicker_focus_fwdGrid_"),
			"The dropped forward's Play through pick goes back to no one (%s)" % str(t.get("focus_fwd", "")))
	_check(_is_chosen(ms, "TaggerPickerGrid_") and str(t.get("tagger_id", "")) == "",
			"The dropped tagger's job goes back to the assistant's pick")
	_check(_is_chosen(ms, "PlanPicker_" + plan) and _is_chosen(ms, "PepPicker_fire_up")
			and _is_chosen(ms, "TagPickerGrid_" + tag) and _is_chosen(ms, "DefenceSetupPicker_" + def_key)
			and str(t.get("gameplan", "")) == plan and str(t.get("pep", "")) == "fire_up"
			and str(t.get("tag_id", "")) == tag,
			"Every other call is kept, the tag on their player included (%s)" % str(t))
	# The calls reach the match: Start plays them.
	await _tap_named(ms, "StartQuarter", taps)
	t = nsim2.tactics[side]
	_check(taps.is_empty() and not _state.match_day_setup_open() and str(t.get("gameplan", "")) == plan
			and str(t.get("pep", "")) == "fire_up" and str(t.get("tag_id", "")) == tag,
			"Start plays the kept calls (%s %s)" % [str(taps), str(t)])
	router.stack = ["hub"]
	if current_scene != null:
		current_scene.queue_free()
	if is_instance_valid(hub):
		hub.queue_free()
	_state.pending_sim = null
	_state.side_from_match = false
	await _settle()


## A real tap on the named control under `scene`; what went wrong goes in `taps`.
func _tap_named(scene: Node, node_name: String, taps: Array) -> void:
	var c: Control = scene.find_child(node_name, true, false) if scene != null else null
	var why: String = await Tap.tap(c) if c != null else "missing"
	if why != "":
		taps.append("%s: %s" % [node_name, why])
	await _settle()


## Whether the named choice is the outlined (chosen) one.
func _is_chosen(scene: Node, node_name: String) -> bool:
	var b: Button = scene.find_child(node_name, true, false) if scene != null else null
	return b != null and b.get_theme_stylebox("normal").border_width_left == 2


# ---------------------------------------------------------------------------
# Vignettes On/Off (Settings, ROADMAP §1.11)
# ---------------------------------------------------------------------------
## The setting is in the options at a phone's size and a PC's, takes a real
## tap, and stays put across a reload of the settings.
func _test_vignettes_setting() -> void:
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
		# Phone is portrait only (director, 2026-11-05: "Drop landscape"): no
		# Screen row on a desktop or a phone, and an older saved landscape loads
		# as portrait.
		_check(sheet.find_child("SettingsOrientation_portrait", true, false) == null,
				"A desktop has no Screen orientation row (%s)" % tag)
		load("res://scripts/core/ScreenLayout.gd").force_web_phone = true
		host.queue_free()
		host = Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		host.size = Vector2(sz)
		sheet = options.open(host, true)
		await _settle()
		_check(sheet.find_child("SettingsOrientation_landscape", true, false) == null
				and sheet.find_child("SettingsOrientation_auto", true, false) == null
				and sheet.find_child("SettingsOrientation_portrait", true, false) == null,
				"A phone's Settings has no Screen row: portrait only (%s)" % tag)
		for old in ["landscape", "auto", "junk"]:
			_state.set_setting("screen_orientation", old)
			_state.clamp_saved_orientation()
			var cfg2 := ConfigFile.new()
			_check(cfg2.load(_state.settings_path) == OK and cfg2.get_value("ui", "screen_orientation") == "portrait",
					"A saved '%s' loads as portrait (%s)" % [old, tag])
		var cfg3 := ConfigFile.new()
		if cfg3.load(_state.settings_path) == OK and cfg3.has_section_key("ui", "screen_orientation"):
			cfg3.erase_section_key("ui", "screen_orientation")
			cfg3.save(_state.settings_path)
		_state.clamp_saved_orientation()
		var cfg4 := ConfigFile.new()
		_check(cfg4.load(_state.settings_path) != OK or not cfg4.has_section_key("ui", "screen_orientation"),
				"No saved orientation stays unsaved after the clamp (%s)" % tag)
		var gs_src := FileAccess.get_file_as_string("res://scripts/state/GameState.gd")
		var ready_body := gs_src.substr(gs_src.find("func _ready("))
		ready_body = ready_body.substr(0, ready_body.find("\nfunc ", 1))
		_check(ready_body.contains("clamp_saved_orientation()"),
				"GameState._ready clamps the saved orientation (%s)" % tag)
		# First tap (director, 2026-11-05): a phone's browser goes fullscreen and
		# holds portrait from a tap's release (the browser's user gesture), once.
		var sl_node: Node = root.get_node("ScreenLayout")
		sl_node.page_lock_done = false
		sl_node.page_lock_sent.clear()
		var key_ev := InputEventKey.new()
		key_ev.pressed = true
		key_ev.keycode = KEY_A
		sl_node._input(key_ev)
		var press := InputEventScreenTouch.new()
		press.pressed = true
		sl_node._input(press)
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		sl_node._input(right)
		var no_early: bool = sl_node.page_lock_sent.is_empty()
		var lift := InputEventScreenTouch.new()
		sl_node._input(lift)
		var click_up := InputEventMouseButton.new()
		click_up.button_index = MOUSE_BUTTON_LEFT
		sl_node._input(click_up)
		await process_frame
		sl_node._input(lift)
		_check(no_early and sl_node.page_lock_sent.size() == 1 and sl_node.page_lock_done
				and sl_node.page_lock_sent[0].contains("requestFullscreen")
				and sl_node.page_lock_sent[0].contains("document.documentElement")
				and sl_node.page_lock_sent[0].contains("lock(o)")
				and sl_node.page_lock_sent[0].ends_with("})('portrait');"),
				"A phone browser's first tap release sends the page fullscreen portrait lock once; not a key, a press or a right click (%s)" % tag)
		load("res://scripts/core/ScreenLayout.gd").force_web_phone = false
		var sl_cls = load("res://scripts/core/ScreenLayout.gd")
		_check(sl_cls.page_lock_for(["web", "web_android"]) and sl_cls.page_lock_for(["web", "web_ios"])
				and not sl_cls.page_lock_for(["web"]) and not sl_cls.page_lock_for(["android"])
				and not sl_cls.page_lock_for(["ios"]) and not sl_cls.page_lock_for([]),
				"Only a phone's browser gets the page lock: not a PC browser, a native phone or a desktop (%s)" % tag)
		sl_node.page_lock_done = false
		sl_node.page_lock_sent.clear()
		await process_frame
		sl_node._input(lift)
		_check(sl_node.page_lock_sent.is_empty() and not sl_node.page_lock_done,
				"A desktop's tap sends no page lock (%s)" % tag)
		var proj := FileAccess.get_file_as_string("res://project.godot")
		_check(proj.replace("\r", "").contains("window/handheld/orientation=1\n") and int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_PORTRAIT,
				"project.godot locks handhelds to portrait (%s)" % tag)
		host.queue_free()
		await _settle()


# ---------------------------------------------------------------------------
# Game feel (director, 2026-10-11): button sounds, vibration, reduced motion
# ---------------------------------------------------------------------------
## Every effect runs with its setting on and is skipped with it off: the
## sound, the buzz and the motion of a press, a choice, a big moment, an
## attention pulse and a living background. Read from Feel's own record of
## what it started (Feel.heard / felt / moved), and from the nodes.
func _test_game_feel_effects() -> void:
	var feel = load("res://scripts/ui/Feel.gd")
	var uk = load("res://scripts/ui/UiKit.gd")
	feel.force_phone = true
	feel.test_motion = true
	root.size = Vector2i(390, 844)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.size = Vector2(390, 844)
	var bd = load("res://scripts/ui/ClubBackdrop.gd").new().setup("COL")
	host.add_child(bd)
	var v: VBoxContainer = uk.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(v)
	var main: Button = uk.btn("Play match", uk.HEADING, true)
	main.name = "FeelMain"
	v.add_child(main)
	var soft: Button = uk.btn("Training", uk.BODY)
	v.add_child(soft)
	var grid: GridContainer = uk.choice_grid("FeelChoice", [["a", "Attack"], ["b", "Defend"]], "a", 2)
	v.add_child(grid)
	var big: Label = uk.lbl("Won by 23", 30, uk.TEXT, true)
	v.add_child(big)
	await _settle()
	var run := func() -> Dictionary:
		feel.clear()
		var r := {}
		r["main"] = await Tap.tap(main)
		r["tick"] = await Tap.tap(grid.find_child("FeelChoice_b", true, false))
		uk.land(big)
		uk.attention(soft, 0.0)
		uk.drift(bd, func(_t: float) -> void: bd.queue_redraw(), 0.3, 6.0)
		for i in range(4):
			await process_frame
		r["heard"] = feel.heard.duplicate()
		r["felt"] = feel.felt.duplicate()
		r["moved"] = feel.moved.duplicate()
		return r
	var on: Dictionary = await run.call()
	_check(on["main"] == "" and on["tick"] == "", "The feel buttons take real taps (%s, %s)" % [on["main"], on["tick"]])
	_check(on["heard"] == ["main", "tick", "land"],
			"On: a boot for the main action, a stud tick for a choice, the sting for a big moment (%s)" % str(on["heard"]))
	_check(on["felt"] == [22, 10, 40], "On: a phone buzzes for each, firmest for the big moment (%s)" % str(on["felt"]))
	_check(on["moved"].has("press") and on["moved"].has("land") and on["moved"].has("attention") and on["moved"].has("drift"),
			"On: the press-in, the landing, the pulse and the living background all move (%s)" % str(on["moved"]))
	# The pulse and the background stop: nothing left drawing once they're done.
	await create_timer(2.2).timeout
	var draws := [0]
	var count := func() -> void: draws[0] += 1
	bd.draw.connect(count)
	await create_timer(0.6).timeout
	bd.draw.disconnect(count)
	_check(draws[0] == 0 and bd.find_child("Drift", true, false) == null and soft.modulate == Color.WHITE
			and is_equal_approx(big.scale.x, 1.0),
			"Then everything holds still: no redraws, no timer, colour and size back to rest (%d)" % draws[0])
	_state.set_sounds_muted(true)
	var quiet: Dictionary = await run.call()
	_check(quiet["heard"].is_empty() and quiet["felt"] == [22, 10, 40],
			"Mute: no sound starts; the buzz still comes (%s)" % str(quiet["heard"]))
	_state.set_sounds_muted(false)
	_state.set_volume(0)
	var zero: Dictionary = await run.call()
	_check(zero["heard"].is_empty(), "Volume 0: no sound starts either (%s)" % str(zero["heard"]))
	_state.set_volume(100)
	_state.set_haptics_on(false)
	var still: Dictionary = await run.call()
	_check(still["felt"].is_empty() and still["heard"] == ["main", "tick", "land"],
			"Vibration Off: no buzz; the sounds still play (%s)" % str(still["felt"]))
	_state.set_haptics_on(true)
	await create_timer(2.2).timeout
	_state.set_reduced_motion(true)
	var calm: Dictionary = await run.call()
	_check(calm["moved"].is_empty() and is_equal_approx(main.scale.x, 1.0) and is_equal_approx(big.scale.x, 1.0)
			and soft.modulate == Color.WHITE,
			"Reduced motion: nothing presses in, lands, pulses or drifts (%s)" % str(calm["moved"]))
	_check(calm["heard"] == ["main", "tick", "land"] and calm["felt"] == [22, 10, 40],
			"Reduced motion keeps the sound and the buzz (their own settings)")
	_check(_state.screen_shake_on() and not uk.motion_on(),
			"Reduced motion stills the screen even with Screen shake on")
	_state.set_reduced_motion(false)
	feel.force_phone = false
	var pc: Dictionary = await run.call()
	_check(pc["felt"].is_empty(), "On a PC nothing buzzes")
	feel.test_motion = false
	feel.clear()
	host.queue_free()
	await _settle()
	# The sounds: made in-repo (tools/audio/build_feel.py), each one short and small.
	var bad := []
	for kind in feel.SOUNDS:
		var path := "res://assets/audio/feel/" + str(feel.SOUNDS[kind][0])
		var s := load(path) as AudioStream
		var f := FileAccess.open(path, FileAccess.READ)
		var bytes := f.get_length() if f != null else 0
		if not (s != null and s.get_length() > 0.02 and s.get_length() < 1.5 and bytes > 0 and bytes < 60000):
			bad.append("%s (%.2f s, %d bytes)" % [path.get_file(), s.get_length() if s != null else 0.0, bytes])
	_check(bad.is_empty() and feel.SOUNDS.size() == 5,
			"Every feel sound loads, is short and under 60 KB (%s)" % ", ".join(bad))


## The break's pulse is only for a call the quarter broke.
func _test_broken_calls() -> void:
	var notes = load("res://scripts/ui/match/MatchNotes.gd")
	var last := {"focus_id": "p1", "interceptor_id": "p2", "spare_minder_id": "p3", "tag_id": "o9"}
	var res := {"tag_drops": [{"side": 0, "q": 2, "id": "o9"}]}
	var hurt := [{"side": 0, "q": 2, "id": "p1"}, {"side": 0, "q": 2, "id": "p2"}, {"side": 0, "q": 2, "id": "p3"}]
	_check(notes.broken_calls(res, hurt, 0, 3, last) == ["TagPicker", "DefenceSetupPicker"],
			"Half time: the tag the match ended and a defensive set-up man gone off hurt need the coach, once; an old play-through key never")
	_check(notes.broken_calls({}, [], 0, 3, last).is_empty(),
			"Nothing broken, nothing pulses: an untouched call never nags")
	_check(notes.broken_calls(res, hurt, 0, 1, {}).is_empty(), "Before the first bounce nothing pulses")


## The same seeded match, the same calls, with vignettes on and off: every
## call still comes and is made, no scene is ever built with them off, and
## the football is identical. Then the hub's Play match, the press conference
## and the awards night with them off.
func _test_vignettes_off_match() -> void:
	# The vignettes-on match is taken in Key moments (P-14), the vignettes-off one
	# watched: the same match either way, so one pair proves both.
	var with_on: Dictionary = await _drive_match(true, "key")
	var with_off: Dictionary = await _drive_match(false)
	_key_moments_checks(with_on, with_off)
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
	await _t("_test_press_effects_shown", [db])
	await _t("_test_press_scene_routed")
	await _t("_test_press_scene_taps")
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
func _drive_match(vignettes: bool, way := "watch") -> Dictionary:
	var db = root.get_node("GameDB")
	_state.set_vignettes_on(vignettes)
	_state.set_bounce_scene_every_match(true)
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(390, 844)
	_state.set_match_way(way)
	_state.prepare_interactive_match()
	var seen := [0]
	var watch := func(n: Node) -> void:
		var named := str(n.name).contains("Vignette")
		var script: Script = n.get_script()
		if named or (script != null and str(script.get_global_name()).ends_with("Vignette")):
			seen[0] += 1
	node_added.connect(watch)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	# Key moments holds 1x for 1.8 real seconds after a stop; a tenth here keeps
	# the suite quick and leaves what stops the match the same.
	m.set("km_hold_seconds", 0.1)
	root.add_child(m)
	await _settle()
	var km_word: Control = m.find_child("KeyMomentsState", true, false)
	var km_shown := km_word != null and km_word.is_visible_in_tree() and str((km_word as Button).text) == "Key moments"
	var speeds_shown := 0
	for b in m.get("_speed_btns"):
		if (b as Control).is_visible_in_tree():
			speeds_shown += 1
	var km_watch: Control = m.find_child("KeyMomentsWatch", true, false)
	var row_ok := km_word != null and km_watch != null and km_watch.global_position.x < km_word.global_position.x
	for c in m.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree() and (c as Button).text in ["Pause", "Watch", "Key moments", "Skip to full time"]:
			row_ok = row_ok and (c as Control).size.y >= 44.0
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
		"events": JSON.stringify(res.get("events", [])), "players": JSON.stringify(res.get("players", {})),
		"log": (res.get("events", []) as Array).duplicate(true), "stops": (m.get("km_stops") as Array).duplicate(true),
		"trace": (m.get("km_trace") as Array).duplicate(true), "km_shown": km_shown, "speeds_shown": speeds_shown,
		"row_ok": row_ok}
	_check(bool(m.get("_fulltime_shown")), "The match reaches full time (vignettes %s)" % ("on" if vignettes else "off"))
	node_added.disconnect(watch)
	m.queue_free()
	await _settle()
	return out


## Key moments (P-14), from the seeded match taken that way (`key`) and the same
## match watched (`watch`): it stops at every goal, every call and every break
## in the sim's log and nowhere else, runs at top speed in between, and ends
## on the same match.
func _key_moments_checks(key: Dictionary, watch: Dictionary) -> void:
	var log: Array = key["log"]
	var goals := []
	var moments := 0
	for i in range(log.size()):
		var k := str((log[i] as Dictionary).get("kind", ""))
		if k == "goal":
			goals.append(i)
		elif k == "moment":
			moments += 1
	var goal_stops := []
	var moment_stops := 0
	var breaks := []
	var other := []
	for s in key["stops"]:
		match str(s["kind"]):
			"goal":
				goal_stops.append(int(s["event"]))
			"moment":
				moment_stops += 1
			"break":
				breaks.append(int(s["q"]))
			_:
				other.append(str(s["kind"]))
	print("Key moments: %d stops (%d goals of %d, %d calls of %d, breaks %s), %d events traced" % [
			(key["stops"] as Array).size(), goal_stops.size(), goals.size(), moment_stops, moments,
			str(breaks), (key["trace"] as Array).size()])
	_check(bool(key["km_shown"]) and int(key["speeds_shown"]) == 0,
			"Key moments shows its name where the speeds sit, the speeds put away (%d shown)" % int(key["speeds_shown"]))
	_check(bool(key["row_ok"]), "The match row reads Pause, Watch, Key moments, each at least 44 px tall")
	_check(not goals.is_empty() and goal_stops == goals,
			"Key moments stops for every goal in the log and only those (%d of %d)" % [goal_stops.size(), goals.size()])
	_check(moments > 0 and moment_stops == moments,
			"Key moments stops for every coach's call (%d of %d)" % [moment_stops, moments])
	_check(breaks == [2, 3, 4], "Key moments stops at quarter time, half time and three-quarter time (%s)" % str(breaks))
	_check(other.is_empty(), "Key moments stops for nothing else (%s)" % str(other))
	# Between the stops, top speed (8x): every event released below it belongs to
	# a stretch of 1x that holds a goal or a call's line.
	var stray := []
	var run_has_key := false
	var run_len := 0
	var trace: Array = key["trace"]
	for i in range(trace.size() + 1):
		var slow := i < trace.size() and float(trace[i][1]) < 8.0
		if slow:
			run_len += 1
			if str(trace[i][0]) in ["goal", "moment"]:
				run_has_key = true
			if str(trace[i][2]) == "":
				stray.append("%s at %sx with no stop" % [str(trace[i][0]), str(trace[i][1])])
		elif run_len > 0:
			if not run_has_key:
				stray.append("%d events slowed with no goal or call" % run_len)
			run_has_key = false
			run_len = 0
	_check(trace.size() == log.size() and stray.is_empty(),
			"Key moments runs at 8x except around a goal or a call (%d of %d traced; %s)" % [
				trace.size(), log.size(), str(stray.slice(0, 3))])
	_check(key["score"] == watch["score"] and key["events"] == watch["events"],
			"Key moments ends on the same match as watching it (%s v %s)" % [str(key["score"]), str(watch["score"])])


## The poster's three ways to take the match: a real tap picks one, the main
## button says Skip to full time only when Skip is chosen, the last one comes up
## chosen on the next visit, and a real tap on the main button with Skip chosen
## goes straight to your full time.
func _test_match_way_poster() -> void:
	var db = root.get_node("GameDB")
	_state.set_vignettes_on(true)
	_state.set_match_way("watch")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("FRE", db.club_list("FRE"))
	_state.set_setting("seen_weekly_loop_intro", true)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = sz
		_state.set_match_way("watch")
		var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		await _settle()
		var key: Button = hub.find_child("MatchWay_key", true, false)
		var skip: Button = hub.find_child("MatchWay_skip", true, false)
		var watch: Button = hub.find_child("MatchWay_watch", true, false)
		var play: Button = hub.find_child("PlayMatch", true, false)
		_check(watch != null and key != null and skip != null and _chosen(watch) and not _chosen(key)
				and play != null and play.text == "Play match",
				"%dx%d: the poster offers Watch, Key moments and Skip, Watch chosen for a new coach" % [sz.x, sz.y])
		var row_ok := watch != null and key != null and skip != null
		if row_ok:
			row_ok = (is_equal_approx(watch.global_position.y, key.global_position.y)
					and is_equal_approx(key.global_position.y, skip.global_position.y)
					and watch.global_position.x < key.global_position.x
					and key.global_position.x < skip.global_position.x)
		_check(row_ok, "%dx%d: the three choices sit in one row, Watch, Key moments, Skip" % [sz.x, sz.y])
		var tapped: String = await Tap.tap(key) if key != null else "missing"
		_check(tapped == "" and _state.match_way() == "key" and _chosen(key) and not _chosen(watch)
				and play != null and play.text == "Play match",
				"%dx%d: a real tap on Key moments chooses it and keeps it, Play match stays (%s, %s)" % [
					sz.x, sz.y, tapped, _state.match_way()])
		tapped = await Tap.tap(skip) if skip != null else "missing"
		_check(tapped == "" and _state.match_way() == "skip" and play != null and play.text == "Skip to full time",
				"%dx%d: a real tap on Skip chooses it and the main button says Skip to full time (%s, %s)" % [
					sz.x, sz.y, tapped, play.text if play != null else "-"])
		hub.queue_free()
		await _settle()
	# The next visit: Skip comes up chosen; a real tap on the main button goes
	# straight to your full time.
	root.size = Vector2i(390, 844)
	var hub2: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub2)
	await _settle()
	var skip2: Button = hub2.find_child("MatchWay_skip", true, false)
	var play2: Button = hub2.find_child("PlayMatch", true, false)
	_check(skip2 != null and _chosen(skip2) and play2 != null and play2.text == "Skip to full time",
			"The way chosen last comes up chosen on the next visit, the main button in its words")
	var tapped2: String = await Tap.tap(play2) if play2 != null else "missing"
	var saw_box := false
	var m: Node = null
	for i in range(60):
		await process_frame
		if current_scene != null and current_scene.name == "MatchScene":
			m = current_scene
			saw_box = saw_box or m.find_child("CoachBox", true, false) != null
			if bool(m.get("_fulltime_shown")):
				break
	_check(tapped2 == "" and m != null, "A real tap on Skip to full time opens your match (%s)" % tapped2)
	_check(m != null and bool(m.get("_fulltime_shown")) and not saw_box and _state.pending_sim == null,
			"Skip goes straight to your full time on the plan you took in, no break on the way")
	if m != null:
		m.queue_free()
	if is_instance_valid(hub2):
		hub2.queue_free()
	_state.set_match_way("watch")
	await _settle()


## A choice painted as chosen (UiKit.paint_choice): the 2 px outline.
func _chosen(b: Button) -> bool:
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	return sb != null and sb.border_width_left == 2


## True when a body on the figure sheet has the move from every one of those sides.
func _sheet_has(body: Dictionary, anim: String, facings: Array) -> bool:
	for facing in facings:
		var info: Dictionary = ((body["anims"] as Dictionary).get(anim, {}) as Dictionary).get(facing, {})
		if int(info.get("frames", 0)) <= 0:
			return false
	return true


## True when any button or label under a node says the text.
func _any_text(node: Node, text: String) -> bool:
	for n in node.find_children("*", "Control", true, false):
		if (n is Button or n is Label) and str(n.text).contains(text):
			return true
		if n is RichTextLabel and (n as RichTextLabel).get_parsed_text().contains(text):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## The call panes, Fremantle v Melbourne (the lead's captures of 2026-10-18, seed 2050).
## Before the first ball-up: "Tag which player?" is drawn over the tag choices; on a
## PC the game plan leads the first column, the tag and the play-through picks share one,
## the pep talk and the defensive forward share one, the columns are alike in height and
## the pane does not scroll. At quarter time the play-through row is there (key match-ups
## cut, director 2026-11-07), and Best so far's names are plain white.

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)
const NB := " "


func _fre_v_mel() -> bool:
	var db = root.get_node("GameDB")
	for tries in range(80):
		_state.reset()
		_state.career_seed = 2050 + tries
		_state.replay_seed = 2050 + tries
		_state.set_setting("seen_training_intro", true)
		_state.start_season("FRE", db.club_list("FRE"))
		_state.prepare_interactive_match()
		var sq = _state.pending_sim.squads
		if str(sq[0].code) == "MEL" or str(sq[1].code) == "MEL":
			return true
	return false


func _test_break_panes_layout() -> void:
	var UK = load("res://scripts/ui/UiKit.gd")
	var db = root.get_node("GameDB")
	var seed_before: int = _state.replay_seed
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		_check(_fre_v_mel(), "(setup) Fremantle meet Melbourne in a seed from 2050 (%s)" % tag)
		var sim = _state.pending_sim
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		await _settle()
		var box: Node = m.find_child("CoachBox", true, false)
		_check(box != null, "The pre-bounce box opens (%s)" % tag)
		if box == null:
			m.queue_free()
			continue
		var ask: Node = box.find_child("TagQuestion", true, false)
		var tag_picker: Node = box.find_child("TagPicker", true, false)
		_check(ask is Label and (ask as Label).text == "Tag which player?" and (ask as Label).is_visible_in_tree(),
				"Tag which player? is drawn over the tag choices (%s)" % tag)
		_check(ask != null and tag_picker != null and ask.get_parent() == tag_picker.get_parent()
				and ask.get_index() < tag_picker.get_index(), "...above the choices, in the Tag block (%s)" % tag)
		_notes_above_floor(box, "pre-bounce, " + tag)
		if sz.x >= 1200:
			var cols_node: Control = box.find_child("BreakColumns", true, false)
			var cols: Array = cols_node.get_children()
			var col_of := func(nm: String) -> int:
				var n: Node = box.find_child(nm, true, false)
				for i in range(cols.size()):
					if n != null and (cols[i] as Node).is_ancestor_of(n):
						return i
				return -1
			_check(cols.size() == 3, "Three call columns at 1280x720 (%d)" % cols.size())
			_check(int(col_of.call("PlanPicker")) == 0, "The game plan leads the first column (column %d)" % int(col_of.call("PlanPicker")))
			# The play-through picks are dealt by height (_deal_calls), the
			# three of them together in one column.
			var pt_col := int(col_of.call("FocusPicker_focus_mid"))
			_check(int(col_of.call("TagPicker")) == 1 and pt_col >= 0
					and int(col_of.call("FocusPicker_focus_fwd")) == pt_col and int(col_of.call("FocusPicker_focus_def")) == pt_col,
					"The tag leads the second column; the three play-through picks share a column (%d)" % pt_col)
			_check(int(col_of.call("PepPicker")) >= 0 and int(col_of.call("DefenceSetupPicker")) >= 0,
					"The pep talk and the defensive set-up are in the columns")
			var tallest := 0.0
			var heights := []
			var parts := []
			for c in cols:
				var t := 0.0
				for n in (c as Node).get_children():
					if (n as Control).visible:
						t += (n as Control).get_combined_minimum_size().y + 6.0
						parts.append("%s %.0f" % [n.name, (n as Control).get_combined_minimum_size().y])
				heights.append(t)
				tallest = maxf(tallest, t)
			var worst := 0.0
			for t in heights:
				worst = maxf(worst, (tallest - float(t)) / tallest)
			# Three columns before the bounce (director, 2026-11-03): no column
			# stands more than 30% empty, with Tag and Play through kept together.
			_check(worst <= 0.30, "No column stands more than 30%% empty (%.0f%%: %s %s)" % [worst * 100.0, str(heights), str(parts)])
			var bsc: ScrollContainer = null
			var up: Node = cols_node
			while up != null and bsc == null:
				bsc = up as ScrollContainer
				up = up.get_parent()
			var need := (bsc.get_child(0) as Control).get_combined_minimum_size().y if bsc != null else INF
			_check(need <= bsc.size.y + 1.0, "The pre-bounce pane does not scroll at 1280x720 (%.0f of %.0f)" % [need, bsc.size.y if bsc else 0.0])
		m.queue_free()
		await _settle()
		# Quarter time: the calls rows and Best so far.
		sim.run_quarter()
		var m2: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m2)
		await _settle()
		await _settle()
		var box2: Node = m2.find_child("CoachBox", true, false)
		if box2 != null:
			_notes_above_floor(box2, "quarter time, " + tag)
		_check(box2 != null and box2.find_child("CallRow_pt", true, false) != null and box2.find_child("CallRow_mu", true, false) == null,
				"Quarter time has the play-through row and no key match-ups row (%s)" % tag)
		var inks: Array = UK.club_ink_pair(str(sim.squads[0].code), str(sim.squads[1].code))
		for side in [0, 1]:
			var wrap: Node = box2.find_child("BestSide_%d" % side, true, false) if box2 != null else null
			var plain := []
			var count := 0
			for n in (wrap.find_children("StandoutName", "Label", true, false) if wrap != null else []):
				count += 1
				if (n as Label).get_theme_color("font_color") != UK.TEXT:
					plain.append((n as Label).text)
			_check(count >= 1 and plain.is_empty(), "Best so far names for side %d are plain white (the club colour is the bar and crest) (%s, %d, not: %s)" % [side, tag, count, str(plain)])
		m2.queue_free()
		await _settle()
	_state.replay_seed = seed_before


## The notes under the calls in a break pane are read mid-match (row 109,
## 6.Q18): every word in them is drawn above the 13 px floor at the screen's
## own scale, i.e. at UiKit.NOTE (14) or larger.
const BREAK_NOTES := ["TagNote", "DefenceNote", "LooseTally", "SkipNote", "LegsView", "MyInterceptor", "AssistantNote"]


func _notes_above_floor(box: Node, tag: String) -> void:
	var found := []
	var small := []
	for nm in BREAK_NOTES:
		var n: Node = box.find_child(nm, true, false)
		if n == null or not (n as Control).is_visible_in_tree():
			continue
		found.append(nm)
		var texts: Array = n.find_children("*", "Control", true, false)
		texts.append(n)
		for c in texts:
			var fs := 0
			if c is RichTextLabel:
				fs = (c as Control).get_theme_font_size("normal_font_size")
			elif c is Label:
				fs = (c as Control).get_theme_font_size("font_size")
			else:
				continue
			if not (c as Control).is_visible_in_tree():
				continue
			var px := float(fs) * (c as Control).get_global_transform().get_scale().y
			if px <= 13.0:
				small.append("%s %.0f px" % [nm, px])
	_check(found.size() >= 2, "The break pane has its notes (%s: %s)" % [tag, str(found)])
	_check(small.is_empty(), "Break-pane notes are above 13 px (%s: %s)" % [tag, str(small)])


func _plain_of(c: Control) -> String:
	return str(c.get_meta("plain")) if c.has_meta("plain") else (c as Label).text


## Tapping a tag target opens "Who tags", which was there, shut, from the start;
## no section moves, sideways or down, and nothing lies off the screen
## (director, 2026-10-14, A2: "heinous, awful UI design").
## Before the first ball-up nobody has played, so there is no Best so far.
func _test_tag_tap_keeps_columns(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("FRE", db.club_list("FRE"))
	root.size = sz
	_check(_state.prepare_interactive_match(), "A live match is prepared for the tag jump (%s)" % tag)
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	_check(box != null and box.find_child("BestSoFar", true, false) == null and box.find_child("BestSoFarOpen", true, false) == null,
			"Before the first ball-up there is no Best so far (%s)" % tag)
	var names := ["PlanPicker", "TagPicker", "PepPicker", "DefenceSetupPicker", "FocusPicker_focus_mid", "LegsView"]
	var before := {}
	for n in names:
		var c: Control = box.find_child(n, true, false) if box != null else null
		if c != null and c.is_visible_in_tree():
			before[n] = c.get_global_rect().position
	# Who tags is there before any tag, shut (A2: nothing appears and shoves).
	var who0: Node = box.find_child("TaggerPicker", true, false)
	var shut := who0 != null and (who0 as Control).is_visible_in_tree()
	if who0 != null:
		for wb in who0.find_children("*", "Button", true, false):
			shut = shut and (wb as Button).disabled
	_check(shut, "Who tags is on the break before a tag, shut until there is one (%s)" % tag)
	var named: Button = null
	for b in box.find_child("TagPicker", true, false).find_children("TagPickerGrid_*", "Button", true, false):
		if str(b.name) != "TagPickerGrid_":
			named = b
			break
	_check(named != null and before.size() >= 3, "A tag target and the sections are there (%s: %d)" % [tag, before.size()])
	if named != null:
		var why: String = await Tap.tap(named)
		await _settle()
		_check(why == "", "A real tap picks the tag target (%s: %s)" % [tag, why])
		for n in before:
			var c2: Control = box.find_child(n, true, false)
			_check(c2 != null and (c2.get_global_rect().position - (before[n] as Vector2)).length() < 6.0,
					"%s stays where it was after the tag tap, not sideways and not down (%s: %s -> %s)" % [n, tag,
					str(before[n]), str(c2.get_global_rect().position if c2 else Vector2(-1, -1))])
		var who: Control = box.find_child("TaggerPicker", true, false)
		var open := who != null
		if who != null:
			for wb in who.find_children("*", "Button", true, false):
				open = open and not (wb as Button).disabled
		_check(open, "Who tags opens after the tag tap (%s)" % tag)
		var out := []
		for c3 in box.find_children("*", "Control", true, false):
			var cc := c3 as Control
			if cc.is_visible_in_tree() and cc.get_global_rect().size.x > 0 and cc.get_global_rect().end.x > sz.x + 1.0 					and not _inside_scroll(cc):
				out.append(str(cc.name))
		_check(out.is_empty(), "Nothing lies past the right edge after the tag tap (%s: %s)" % [tag, str(out.slice(0, 5))])
	m.queue_free()
	await _settle()


## True when c sits inside a ScrollContainer (its overflow is scrolled, not lost).
func _inside_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## Words with the line breaks and the colons and semicolons that split a call's
## words into lines taken out, in lower case, so the lines can be compared with
## the call's full sentence.
func _flat(s: String) -> String:
	var out := s.to_lower().replace(":", " ").replace(";", " ").replace("\n", " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


## The words a line shows, whether a Label or a tinted RichTextLabel carries them.
func _plain(c: Control) -> String:
	if c.has_meta("plain"):
		return str(c.get_meta("plain"))
	if c is Label:
		return (c as Label).text
	return (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else ""


## Skip to the break (director, 2026-11-06): beside Skip to full time in the
## first three quarters, named for the break it skips to, gone in the last.
## A real tap rolls the rest of the quarter, every event reaches the feed, and
## the break comes up with every call. The same match, watched with the same
## calls, ends with the same result, event for event.
func _test_skip_to_break() -> void:
	_state.set_vignettes_on(false)
	var watched := await _play_match_for_skip(false)
	var skipped := await _play_match_for_skip(true)
	_check(not watched.is_empty() and watched == skipped,
			"Skipping to each break ends the match exactly as watching it does (watched %s, skipped %s)" % [
			str(watched.get("sig", "")), str(skipped.get("sig", ""))])


## One match from the hub at 390x844, the default calls at every break and
## moment. `skip`: a real tap on Skip to the break at each bounce of Q1-Q3.
func _play_match_for_skip(skip: bool) -> Dictionary:
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(390, 844)
	router.stack = ["hub"]
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	# Settings live in one file every test run on this machine shares: set
	# vignettes off again right before the match it is meant for.
	_state.set_vignettes_on(false)
	hub.call("_on_play_match")
	await _settle()
	var m: Node = current_scene
	if m == null or m.name != "MatchScene":
		_check(false, "The match opens (skip %s, %s)" % [str(skip), str(m.name) if m != null else "none"])
		# Leave nothing behind for the next test.
		for n in [hub, m, root.find_child("PreMatchVignette", true, false)]:
			if n != null and is_instance_valid(n) and n != root:
				n.queue_free()
		_state.pending_sim = null
		await _settle()
		return {}
	var tag := "skip" if skip else "watch"
	var names := ["quarter time", "half time", "three-quarter time"]
	var pv = m.get("_pitch")
	# At each siren the button still names the break that has just sounded:
	# a tap before the break opens lands on that break, not the next one.
	var at_siren: Array = []
	var on_siren := func(ev: Dictionary) -> void:
		var b: Button = m.find_child("SkipToBreak", true, false)
		if str(ev.get("kind", "")) == "quarter" and b != null and at_siren.size() < 3:
			at_siren.append(b.text)
	if not skip:
		pv.event_played.connect(on_siren)
	var guard := 0
	while not bool(m.get("_finished")) and guard < 20000:
		guard += 1
		var sim = _state.pending_sim
		var box = m.get("_coach_overlay")
		var mo = m.get("_moment_overlay")
		if box != null and is_instance_valid(box):
			var start: Control = m.find_child("StartQuarter", true, false)
			var why: String = await Tap.tap(start)
			await _settle()
			if why != "":
				_check(false, "A real tap on Start at each break (%s: %s)" % [tag, why])
				break
			var q: int = int(m.get("_breaks_played")) + 1
			var sb: Button = m.find_child("SkipToBreak", true, false)
			if q < 4:
				_check(sb != null and sb.is_visible_in_tree() and sb.text == "Skip to " + names[q - 1]
						and sb.size.y >= 44.0 and sb.get_global_rect().end.x <= 390.0,
						"Q%d: Skip to %s sits beside Skip to full time, thumb-sized (%s, %s)" % [
						q, names[q - 1], sb.text if sb else "-", str(sb.get_global_rect()) if sb else "-"])
				var fnt: Font = sb.get_theme_font("font") if sb else null
				var fs: int = sb.get_theme_font_size("font_size") if sb else 0
				var need := fnt.get_string_size(sb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if fnt else 9999.0
				var sty: StyleBox = sb.get_theme_stylebox("normal") if sb else null
				var pad := (sty.get_margin(SIDE_LEFT) + sty.get_margin(SIDE_RIGHT)) if sty else 0.0
				print("skip_to_break width Q%d: text %.0f + pad %.0f in %.0f px (busy text %.0f)" % [q, need, pad, sb.size.x,
						fnt.get_string_size("Playing on...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x])
				_check(need + pad <= sb.size.x, "Q%d: Skip to %s is read in full, not clipped (%.0f of %.0f px)" % [
						q, names[q - 1], need + pad, sb.size.x if sb else 0.0])
				# Not only at 390: the button never goes below its own text, so a
				# 320-wide screen (a small window, a small phone) reads it in full too.
				_check(sb != null and sb.custom_minimum_size.x >= need + pad,
						"Q%d: Skip to %s keeps room for its words on any width (min %.0f, needs %.0f)" % [
						q, names[q - 1], sb.custom_minimum_size.x if sb else 0.0, need + pad])
				if skip and q == 2:
					# Half way through a quarter, not only at the bounce: some of
					# Q2 is watched first (a call on the way is answered as ever).
					var watch_to: int = int(m.get("_playback_event_index")) + 60
					var g2 := 0
					while int(m.get("_playback_event_index")) < watch_to and g2 < 2000:
						g2 += 1
						var mo2 = m.get("_moment_overlay")
						if mo2 != null and is_instance_valid(mo2) and not sim.pending_moment.is_empty():
							m.call("_on_moment_choice", int(sim.pending_moment.get("default", 0)))
							await process_frame
							continue
						pv.set_speed(8.0)
						if pv.playing:
							pv._process(0.25)
						await process_frame
					var mo3 = m.get("_moment_overlay")
					if mo3 != null and is_instance_valid(mo3) and not sim.pending_moment.is_empty():
						m.call("_on_moment_choice", int(sim.pending_moment.get("default", 0)))
						await process_frame
				if skip:
					var feed_before: int = int(m.get("_playback_event_index"))
					var t0 := Time.get_ticks_usec()
					var why2: String = await Tap.tap(sb)
					var ms := (Time.get_ticks_usec() - t0) / 1000.0
					await _settle()
					var evs: int = (pv.events as Array).size()
					_check(why2 == "" and m.get("_coach_overlay") != null and is_instance_valid(m.get("_coach_overlay"))
							and int(m.get("_playback_event_index")) == evs and int(m.get("_breaks_played")) == q
							and sim.current_quarter == q + 1 and not sim.quarter_in_progress()
							and m.find_child("StartQuarter", true, false) != null,
							"Q%d: a real tap skips to %s: the quarter is played, all %d of its events reached the feed, the break is up with Start (%s)" % [
							q, names[q - 1], evs - feed_before, why2])
					print("skip_to_break Q%d: %d events released, tap-to-break %.1f ms" % [q, evs - feed_before, ms])
					# The scoreboard above the break shows the score at the siren.
					var qt: Dictionary = sim.quarter_teams[q - 1] if sim.quarter_teams.size() >= q else {}
					_check(not qt.is_empty() and m.get("_shown_goals") == qt.get("goals")
							and m.get("_shown_behinds") == qt.get("behinds"),
							"Q%d: after the skip the scoreboard shows the %s score (%s.%s, sim %s.%s)" % [
							q, names[q - 1], str(m.get("_shown_goals")), str(m.get("_shown_behinds")),
							str(qt.get("goals")), str(qt.get("behinds"))])
			else:
				_check(sb == null or not sb.is_visible_in_tree(),
						"The last quarter has Skip to full time only (%s)" % tag)
			continue
		if mo != null and is_instance_valid(mo) and sim != null and not sim.pending_moment.is_empty():
			m.call("_on_moment_choice", int(sim.pending_moment.get("default", 0)))
			await process_frame
			continue
		# Watch, fast: the real playback path, a few seconds of play a step.
		pv.set_speed(8.0)
		if pv.playing:
			pv._process(0.5)
		await process_frame
	if not skip:
		var want := names.map(func(n): return "Skip to " + n)
		_check(at_siren == want, "At each siren the button names the break just sounded, not the next (%s)" % str(at_siren))
	var res: Dictionary = m.get("_res")
	var evs_all: Array = res.get("events", [])
	var sig := "%s %s %d events, hash %d" % [str(res.get("goals")), str(res.get("behinds")),
			evs_all.size(), str(evs_all).hash()]
	_check(bool(m.get("_finished")), "The match reaches full time (%s)" % tag)
	if is_instance_valid(hub):
		hub.queue_free()
	if is_instance_valid(m):
		m.queue_free()
	_state.pending_sim = null
	await _settle()
	return {"sig": sig, "goals": res.get("goals"), "behinds": res.get("behinds"),
			"n": evs_all.size(), "h": str(evs_all).hash()}
