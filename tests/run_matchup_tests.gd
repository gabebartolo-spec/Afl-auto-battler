extends SceneTree
## godot --headless --path . --script tests/run_matchup_tests.gd
## Opponent facts (tests/test_matchup.gd), then the weekly hub on a phone:
## this week first, at most three facts, an obvious next action, the ladder at
## full height, and sensible states for a bye, a finished season and results.

const Tap := preload("res://tests/tap.gd")
var _state: Node
var _checks := 0
var _failures: Array[String] = []
## Every season here is seeded: a clock seed plays a different league each run,
## so a check could pass or fail on the opponent it drew.
const SUITE_SEED := 2031


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	# These tests drive the hub for other things: no club card opens over it.
	_state.event_sheets = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_matchup_settings.cfg"  # its own: other suites on the machine share test_settings.cfg
	# Return visits: the first-visit intros (FirstVisitIntro.gd) have their own suite.
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		_state.set_setting("seen_%s_intro" % key, true)
	var script = load("res://tests/test_matchup.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_matchup.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	await _t("_test_hub_tests")
	await _t("_test_poster_ball")
	await _t("_test_hub_hero")
	await _t("_test_facts_without_options")
	_t("_test_no_ruck_tag")
	_t("_test_gate_odds")
	_t("_test_former_rules")
	await _t("_test_former_player")
	_t("_test_old_club_rules")
	await _t("_test_old_club_preview")
	await _t("_test_wide_hub_footer")
	await _t("_test_phone_footer_fits")
	await _t("_test_regular_bye")
	await _t("_test_finals_week_by_week")
	await _t("_test_finals_cup")
	await _t("_test_finals_status_paths")
	await _t("_test_premiership_streamers")
	await _t("_test_coach_approach_card")
	await _t("_test_season_wrap")
	await _t("_test_season_wrap_trades")
	await _t("_test_season_review_scrolls")
	await _t("_test_pre_match_scene")
	_t("_test_pre_match_captions")
	_t("_test_banner_scene_budget")
	_state.replay_seed = 0
	print(Ran.line("Matchup + hub", self, [suite]))
	quit(0 if _failures.is_empty() else 1)


func _test_hub_tests() -> void:
	var db = root.get_node("GameDB")
	_reset()
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
	var venue: Label = hub.find_child("MatchVenue", true, false)
	# "at Adelaide" is the defect; "Adelaide Oval" is a ground (the Crows' own),
	# so the check looks for the word, not the club's name anywhere.
	_check(venue != null and venue.text.begins_with("Home · " if str(nxt["venue"]) == "home" else "Away · ")
			and not venue.text.contains("at " + db.club_name(str(nxt["code"]))),
			"Then where: home or away and the ground, not 'at' the opponent (%s)" % (venue.text if venue else "-"))
	var facts := hub.find_children("Fact_*", "Control", true, false)
	_check(facts.size() <= 3, "At most three facts about them (%d)" % facts.size())
	var expected: Array = _state.opponent_facts(str(nxt["code"]))
	# How they play, after three games: at most two lines, words not numbers.
	var style: Array = _state.their_style(str(nxt["code"]))
	var style_ok := style.size() <= 2
	for t in style:
		if not (str(t).begins_with("They ") or str(t).begins_with("Their ")):
			style_ok = false
	_check(style_ok, "Their style reads as football (%s)" % " ".join(style))
	var any_style := false
	for c in _state.season.lists:
		if not _state.their_style(str(c)).is_empty():
			any_style = true
	_check(any_style, "After three rounds some sides have a style worth saying")
	var ppl_ok := true
	for f in _state.opponent_people(str(nxt["code"])):
		if not ["missing", "danger", "form"].has(str(f["key"])):
			ppl_ok = false
	_check(ppl_ok, "The people facts are people, not lines")
	_check(facts.size() == expected.size(), "The hub shows exactly the derived facts")
	var form: Label = hub.find_child("OppFormLine", true, false)
	_check(form != null and not form.text.contains("(") and form.text.contains("on the ladder"),
			"Their standing reads in words (%s)" % (form.text if form else "-"))
	# Each result in its own colour, letters kept: a W reads as a win.
	var streak: Node = hub.find_child("FormStreak", true, false)
	var letters := ""
	var coloured := true
	var kit = load("res://scripts/ui/UiKit.gd")
	for l in (streak.get_children() if streak != null else []):
		var ch := str((l as Label).text)
		letters += ch
		var want: Color = kit.GOOD if ch == "W" else (kit.BAD if ch == "L" else kit.MUTED)
		coloured = coloured and (l as Label).get_theme_color("font_color").is_equal_approx(want)
	var info: Dictionary = _state.club_form_info(_state.my_club)
	_check(streak != null and letters == str(info.get("last", "")) and letters != "",
			"The form line keeps the result letters (%s)" % letters)
	_check(coloured, "Wins, losses and draws each read in their own colour (%s)" % letters)
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
	var note: Control = hub.find_child("OwnNote_0", true, false)
	_check(note != null and _plain(note).contains("out injured"), "Your injured star is this week's news")
	best.erase("injury_weeks")
	hub.queue_free()
	await _settle()

	# Run the season out: no fixture, no facts, a clear next step every week.
	# One check per rule however many finals weeks you play, so the check count
	# does not hang on how the season falls. The rest of the home and away
	# season is skipped: only its finals weeks are visited.
	_to_finals()
	var guard := 0
	var weeks := 0
	var facts_bad := []
	var acts_bad := []
	while not _state.season.is_season_over() and guard < 40:
		_state.advance()
		guard += 1
		if _state.season.is_regular_done() and not _state.season.is_season_over():
			weeks += 1
			hub = await _open_hub()
			var status: String = _state.my_finals_status()
			var up := hub.find_child("Opponent", true, false) != null
			if not up and not hub.find_children("Fact_*", "Control", true, false).is_empty():
				facts_bad.append(status)
			var acts: Control = hub.find_child("WeekActions", true, false)
			if not (acts != null and acts.get_child_count() > 0):
				acts_bad.append(status)
			hub.queue_free()
			await _settle()
	_check(weeks > 0, "The finals weeks are visited (%d)" % weeks)
	_check(facts_bad.is_empty(), "No fixture, no facts (%s)" % str(facts_bad))
	_check(acts_bad.is_empty(), "Every finals week has a next action (%s)" % str(acts_bad))
	hub = await _open_hub()
	_check(_screen_text(hub).contains("Season complete"), "A finished season says so")
	_check(hub.find_children("Fact_*", "Control", true, false).is_empty(), "No facts once the season is over")
	# A rival club's letter is answered first: the draft button follows it.
	var letter: bool = load("res://scripts/state/ClubMoves.gd").letter_open(_state)
	_check(letter or _button(hub.find_child("WeekActions", true, false), "National Draft") != null,
			"The national draft is the next step")
	hub.queue_free()
	await _settle()


## A home-and-away bye (an odd club count rotates one) is a week off, not
## the end of the season: no "missed the finals" copy, no finals controls,
## and simming it plays one round and brings the next match back.
## On a PC window the club buttons stay pinned in view but sit under the
## ladder column, not stretched across the whole page (director: no
## full-width bars on PC). Real taps reach them.
func _test_wide_hub_footer() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("COL", db.club_list("COL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(1280, 720)
	var hub: Control = await _open_hub()
	var footer: Control = hub.find_child("HubFooter", true, false)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var r := footer.get_global_rect() if footer != null else Rect2()
	_check(footer != null and viewport.grow(1).encloses(r), "PC: the club buttons stay on screen")
	_check(r.size.x <= root.size.x * 0.55 and r.position.x >= root.size.x * 0.45,
			"PC: the club buttons sit under the ladder, not across the page (%.0f wide at x %.0f)" % [r.size.x, r.position.x])
	var ladder: Control = hub.find_child("LadderSection", true, false)
	_check(ladder != null and absf(ladder.get_global_rect().position.x - r.position.x) < 24.0,
			"PC: the club buttons line up with the ladder column")
	# A real tap at the button's place (its route to Training unhooked, so
	# the tap does not leave the hub mid-test).
	var training := _button(footer, "Training")
	var why := "no Training button"
	if training != null:
		for c in training.pressed.get_connections():
			training.pressed.disconnect(c["callable"])
		why = await Tap.tap(training)
	_check(why == "", "PC: a real tap on Training reaches the button (%s)" % why)
	hub.queue_free()
	await _settle()
	root.size = Vector2i(390, 844)


## The hub's bottom row on the phone widths players have (360, 390, 412) and at 320, the
## narrowest ScreenLayout allows (a 390 px wide window on a desktop is scaled to 320 units,
## where "Sim the week" was cut to "Sim the we..."): every label shows
## in full (none ellipsised), each button is thumb-high, the row stays on screen, and a real
## finger's tap reaches "Sim the week" where it now sits. Checked with no job open on the
## staff and with one open ("Coaching · 1", the longest label the row carries).
func _test_phone_footer_fits() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("MEL", db.club_list("MEL"))
	_state.set_setting("seen_weekly_loop_intro", true)
	for vacancies in [0, 1]:
		for w in [320, 360, 390, 412]:
			_state.staff_vacancies = [{"reason": "A coach has retired."}] if vacancies > 0 else []
			root.size = Vector2i(w, 844)
			var hub: Control = await _open_hub()
			var footer: Control = hub.find_child("HubFooter", true, false)
			var tag := "%d wide, %d open jobs" % [w, vacancies]
			_check(footer != null, "%s: the bottom row is there" % tag)
			if footer == null:
				hub.queue_free()
				continue
			var texts: Array = []
			for b in footer.find_children("*", "Button", true, false):
				var btn := b as Button
				texts.append(btn.text)
				var font: Font = btn.get_theme_font("font")
				var fs: int = btn.get_theme_font_size("font_size")
				var sb: StyleBox = btn.get_theme_stylebox("normal")
				var room := btn.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
				var need := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				_check(need <= room + 0.5, "%s: '%s' shows in full (%.0f px of text in %.0f)" % [tag, btn.text, need, room])
				_check(btn.size.y >= 44.0, "%s: '%s' is thumb-high (%.0f px)" % [tag, btn.text, btn.size.y])
			var sim: Button = footer.find_child("SimRound", true, false) as Button
			_check(sim != null and sim.text == "Sim the week", "%s: the button still says Sim the week (%s)" % [tag, ", ".join(texts)])
			_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(footer.get_global_rect()), "%s: the row stays on the phone" % tag)
			if vacancies == 0 and sim != null:
				# A real tap at its place (its route unhooked, so the tap does not play a week).
				for c in sim.pressed.get_connections():
					sim.pressed.disconnect(c["callable"])
				var hit := [false]
				sim.pressed.connect(func(): hit[0] = true)
				var why: String = await Tap.tap(sim)
				_check(why == "" and hit[0], "%s: a real tap on Sim the week reaches it (%s)" % [tag, why])
			hub.queue_free()
			await _settle()
	_state.staff_vacancies = []
	root.size = Vector2i(390, 844)


func _test_regular_bye() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("MEL", db.club_list("MEL"))
	var season = _state.season
	# A round MEL plays, with a match the round after (its own bye is elsewhere).
	var plays := func(ri: int) -> bool:
		for m in season.fixture[ri]:
			if m["home"] == "MEL" or m["away"] == "MEL":
				return true
		return false
	var r0 := 14
	while not (plays.call(r0) and plays.call(r0 + 1)):
		r0 += 1
	season.round_index = r0
	var round_matches: Array = season.fixture[r0]
	for m in round_matches.duplicate():
		if m["home"] == "MEL" or m["away"] == "MEL":
			round_matches.erase(m)
	root.size = Vector2i(390, 844)
	var hub: Control = await _open_hub()
	var text := _screen_text(hub)
	_check(text.contains("Bye") and not text.contains("Season over")
			and not text.contains("missed the top"), "A mid-season bye is not the end of the season")
	var actions: Node = hub.find_child("WeekActions", true, false)
	_check(actions != null and actions.find_child("SimFinalsWeek", true, false) == null,
			"No finals controls before the home-and-away season is done")
	_check(hub.find_child("FinalsOpen", true, false) == null, "No finals series button before September")
	var sim: Button = actions.find_child("SimByeRound", true, false) if actions != null else null
	_check(sim != null and sim.text == "Play Round %d" % (r0 + 1), "The bye round can be simmed on its own")
	if sim != null:
		sim.emit_signal("pressed")
		await _settle()
	_check(season.round_index == r0 + 1 and season.finals.is_empty(), "Simming the bye plays one round")
	_check(not (hub.call("_upcoming_match") as Dictionary).is_empty(), "The next home-and-away match is back")
	hub.call("handle_back")
	hub.queue_free()
	await _settle()


## Out of the finals, the league still plays them a week at a time: the hub
## offers the week, shows its results, and the season (and its awards) ends
## only after the Grand Final. There is no skip to the Grand Final.
func _test_finals_week_by_week() -> void:
	var db = root.get_node("GameDB")
	var out := ""
	# One career, its club put at the foot of the ladder by hand before the
	# last round (only its own match played): a club that misses the finals.
	var code := "GWS"
	_reset()
	_state.start_season(code, db.club_list(code))
	var sea = _state.season
	var codes: Array = sea.ladder.keys()
	codes.sort()
	codes.erase(code)
	codes.append(code)
	for i in range(codes.size()):
		var row: Dictionary = sea.ladder[codes[i]]
		row["w"] = 20 - i
		row["l"] = 2 + i
		row["d"] = 0
		row["p"] = 22
		row["pf"] = 2300 - i * 20
		row["pa"] = 2000
	sea.round_index = sea.fixture.size() - 1
	sea.recalc_ladder()
	_mine_only(code)
	_state.advance()
	if not (_state.season.finals["top"] as Array).has(code):
		out = code
	_check(out != "", "A club misses the finals to test with")
	if out == "":
		return
	# The last round lands a training report, which opens over the hub: mark it
	# read, as a player who closed it would, so the tap below reaches Finals.
	if not _state.training_report.is_empty():
		_state.training_report["dismissed"] = true
	root.size = Vector2i(390, 844)
	var hub: Control = await _open_hub()
	# The series beside the ladder: a finger's tap opens it, Back closes it.
	# A press conference waiting over the hub is skipped first, as a player would.
	var guard := 0
	while hub.find_child("MediaConference", true, false) != null and guard < 4:
		hub.call("handle_back")
		await _settle()
		guard += 1
	var series: Button = hub.find_child("FinalsOpen", true, false)
	var why: String = await preload("res://tests/tap.gd").tap(series) if series != null else "no Finals button"
	await _settle()
	var sheet: Node = hub.find_child("FinalsSheet", true, false)
	_check(why == "" and sheet != null and sheet.find_child("FinalsBracket", true, false) != null,
			"In September a tap on Finals opens the series (%s)" % why)
	hub.call("handle_back")
	await _settle()
	_check(hub.find_child("FinalsSheet", true, false) == null, "Back closes the finals series")
	var weeks := 0
	var one_at_a_time := true
	while not _state.season.is_season_over() and weeks < 6:
		var actions: Node = hub.find_child("WeekActions", true, false)
		var week: Button = actions.find_child("SimFinalsWeek", true, false) if actions != null else null
		if week == null or actions.find_child("SimToGrandFinal", true, false) != null:
			one_at_a_time = false
			break
		var before := int(_state.season.finals.get("week", 0))
		week.emit_signal("pressed")
		await _settle()
		weeks += 1
		one_at_a_time = one_at_a_time and (_state.season.is_season_over()
				or int(_state.season.finals.get("week", 0)) == before + 1)
		one_at_a_time = one_at_a_time and hub.get("_results_overlay") != null
		if not _state.season.is_season_over():
			one_at_a_time = one_at_a_time and int(_state.season_awards.get("year", 0)) != _state.season_year
		hub.call("handle_back")
		await _settle()
	_check(one_at_a_time and weeks >= 4, "Out of the finals: every week can be played one at a time, results each week (%d weeks)" % weeks)
	_check(_state.season.is_season_over() and int(_state.season_awards.get("year", 0)) == _state.season_year,
			"The season, and its awards, close only after the Grand Final")
	hub.queue_free()


## A rival's approach for your coach sits on the hub until you answer it: a
## finger's tap on an answer settles it and leaves the outcome in words.
func _test_coach_approach_card() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("GEE", db.club_list("GEE"))
	var mid: Dictionary = _state.club_staff("GEE").get("MID", {})
	_check(not mid.is_empty(), "A midfield coach to approach")
	if mid.is_empty():
		return
	_state.coach_approaches = [{"cid": str(mid["cid"]), "from_job": "MID", "club": "HAW", "job": "SA",
			"choice": "", "kept": false, "text": ""}]
	# A second approach answered with a promise (row 117).
	var fwd: Dictionary = _state.club_staff("GEE").get("FWD", {})
	if not fwd.is_empty():
		fwd["since"] = _state.season_year - 10
		_state.coach_approaches.append({"cid": str(fwd["cid"]), "from_job": "FWD", "club": "CAR", "job": "FWD",
				"choice": "", "kept": false, "text": ""})
	root.size = Vector2i(390, 844)
	var hub: Control = await _open_hub()
	var guard := 0
	while hub.find_child("MediaConference", true, false) != null and guard < 4:
		hub.call("handle_back")
		await _settle()
		guard += 1
	var card: Node = hub.find_child("Approach_0", true, false)
	_check(card != null and _screen_text(hub).contains("Hawthorn want"), "The approach is on the hub, the club named")
	var go: Button = hub.find_child("Approach_0_go", true, false)
	var why: String = await preload("res://tests/tap.gd").tap(go) if go != null else "no Let him go"
	await _settle()
	_check(why == "" and str(_state.coach_approaches[0]["choice"]) == "go", "A tap on Let him go answers it (%s)" % why)
	_check(hub.find_child("Approach_0_go", true, false) == null and _screen_text(hub).contains("Hawthorn"),
			"The answer replaces the choices, in words")
	if not fwd.is_empty():
		_check(hub.find_child("Approach_1_promise_weight", true, false) != null and _screen_text(hub).contains("weighs it"),
				"Each answer shows how he weighs it")
		var pr: Button = hub.find_child("Approach_1_promise", true, false)
		var why2: String = await preload("res://tests/tap.gd").tap(pr) if pr != null else "no Promise the job"
		await _settle()
		_check(why2 == "" and str(_state.coach_approaches[1]["choice"]) == "promise", "A tap on Promise the job answers it (%s)" % why2)
		_check(_screen_text(hub).contains("senior assistant's job by"), "The promise and its season are in words")
	hub.queue_free()
	await _settle()


## The Season Review runs well past one phone screen: everything under the
## top bar scrolls, so the National Draft button at the bottom is reachable.
func _test_season_review_scrolls() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(360, 740)
	var review: Control = load("res://scenes/SeasonReviewScene.tscn").instantiate()
	root.add_child(review)
	await _settle()
	var page: Control = review.find_child("ReviewPage", true, false)
	var sc := page.get_parent() as ScrollContainer if page != null else null
	_check(sc != null, "The Season Review sits in a scroll")
	var draft: Button = review.find_child("NationalDraft", true, false)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	if sc != null and draft != null:
		_check(page.size.y > sc.size.y, "On a phone the review runs past one screen (%.0f > %.0f)" % [page.size.y, sc.size.y])
		sc.scroll_vertical = int(page.size.y)
		await _settle()
		_check(viewport.encloses(draft.get_global_rect()), "Scrolled down, the National Draft button is on screen")
	review.queue_free()
	await _settle()


## The wrap's Trade period (row 176; director 2026-11-12: "no colour coding on
## names"): every club in its colours and every player in the ink of the club
## he moved to. A fixture: deals forced through the trade log (no valuation),
## chosen so red clubs (St Kilda, Melbourne) are in it; not believable trades.
func _test_season_wrap_trades() -> void:
	var db = root.get_node("GameDB")
	var CL = load("res://scripts/ui/ClubLink.gd")
	var NI = load("res://scripts/ui/NameInk.gd")
	_reset()
	_state.start_season("MEL", db.club_list("MEL"))
	_state.season.round_index = _state.season.fixture.size()
	_state.open_offseason()
	_state.offseason_log = []
	var lists: Dictionary = _state.season.lists
	var best := func(code: String, n: int) -> Dictionary:
		var l: Array = (lists[code] as Array).duplicate()
		l.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		return l[n]
	# [buyer, seller, the player the buyer gets, what it gives]
	var pick: Dictionary = _state.pick_asset(_state.pick_id(_state.season_year + 1, 1, "STK"))
	_check(not pick.is_empty(), "St Kilda's first-round pick can be traded")
	var deals := [
		["FRE", "WBD", best.call("WBD", 2), [best.call("FRE", 3)]],
		["STK", "ADE", best.call("ADE", 1), [best.call("STK", 4)] + ([pick] if not pick.is_empty() else [])],
		["WBD", "FRE", best.call("FRE", 5), [best.call("WBD", 6)]],
	]
	var moved := []   # [display name, club he moved to]
	for d in deals:
		_state._log_ai_trade(d[0], d[1], d[2], d[3], "")
		moved.append([db.player_display_name(d[2]), d[0]])
		for g in d[3]:
			if not str(g.get("id", "")).begins_with("pick:"):
				moved.append([db.player_display_name(g), d[1]])
	var lines: Array = _state.offseason_log.map(func(e): return str(e["text"]))
	var ours: Dictionary = best.call("MEL", 0)
	lines.append("You turned down St Kilda's offer for %s." % db.player_display_name(ours))
	moved.append([db.player_display_name(ours), "MEL"])
	_state.season_wrap = {"year": _state.season_year, "seen": false, "ins": [], "outs": [],
			"staff": [], "trades": lines, "goal": "", "reason": ""}
	root.size = Vector2i(390, 844)
	var hub: Control = await _open_hub()
	var marked := ""
	for i in range(lines.size()):
		var row: Node = hub.find_child("WrapTrade_%d" % i, true, false)
		_check(row is RichTextLabel, "Trade line %d is inked: %s" % [i, lines[i]])
		if row is RichTextLabel:
			marked += (row as RichTextLabel).text + "\n"
	var ink := func(name: String, col: Color) -> String:
		return "[color=#%s]%s[/color]" % [col.to_html(false), name.replace(" ", NI.NBSP)]
	for m in moved:
		# Exactly his club's name colour: a red club's players are not left white.
		_check(marked.contains(ink.call(str(m[0]), CL.colour(str(m[1])))), "%s wears %s's colours" % [m[0], m[1]])
	for code in ["FRE", "WBD", "STK", "ADE"]:
		var name := str(db.club_name(code))
		_check(marked.contains(ink.call(name, CL.colour(code))), "%s is in its colours" % name)
	hub.queue_free()
	await _settle()


## The off-season wrap sits over the hub until you begin the season.
func _test_season_wrap() -> void:
	_reset()
	_state.start_season("GEE", root.get_node("GameDB").club_list("GEE"))
	_state.season_wrap = {"year": _state.season_year, "seen": false,
			"ins": [{"id": "x1", "name": "New Recruit", "how": "pick 7"}],
			"outs": [{"id": "x2", "name": "Old Hand", "how": "retired"}],
			"staff": [], "goal": "Make the finals", "reason": "The board sees a list good enough to play finals."}
	root.size = Vector2i(390, 844)
	var hub: Control = await _open_hub()
	_check(hub.find_child("SeasonWrap", true, false) != null, "Round 1 waits behind the off-season wrap")
	var goal: Label = hub.find_child("WrapGoal", true, false)
	_check(goal != null and goal.text == "Make the finals", "The wrap names the board's goal")
	_check(hub.find_child("WrapIn_0", true, false) != null and hub.find_child("WrapOut_0", true, false) != null,
			"Ins and outs are listed")
	var go: Button = hub.find_child("BeginSeason", true, false)
	go.emit_signal("pressed")
	await _settle()
	_check(hub.find_child("SeasonWrap", true, false) == null and not _state.needs_season_wrap(),
			"Begin season closes it for good")
	hub.queue_free()
	await _settle()
	var again: Control = await _open_hub()
	_check(again.find_child("SeasonWrap", true, false) == null, "It does not come back")
	again.queue_free()
	await _settle()
	# A coach leaving your staff is a notice on the hub, not only a badge.
	_state.staff_vacancies = [{"job": "FWD", "reason": "Tom Hart left to become senior coach at Carlton."}]
	var hub2: Control = await _open_hub()
	var notice: Control = hub2.find_child("StaffNotice", true, false)
	_check(notice != null and hub2.find_child("StaffNoticeGo", true, false) != null,
			"A coach leaving your staff shows on the hub with the way to replace him")
	_state.staff_vacancies = []
	hub2.queue_free()
	await _settle()
	var hub3: Control = await _open_hub()
	_check(hub3.find_child("StaffNotice", true, false) == null, "No notice once the job is filled")
	hub3.queue_free()
	await _settle()


## The poster leads the hub (6.Q2): first in the week, the week's other asks
## under it, the decision pinned in view on a phone; a card still waiting on the
## coach stands above it (director, 2026-11-08) and the poster still shows.
func _test_hub_hero() -> void:
	var db = root.get_node("GameDB")
	root.size = Vector2i(390, 844)
	_reset()
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.start_season("FRE", db.club_list("FRE"))
	var hub := await _open_hub()
	var week: Control = hub.find_child("ThisWeek", true, false)
	var poster: Control = hub.find_child("MatchPoster", true, false)
	_check(week != null and poster != null and poster.get_parent() == week and poster.get_index() == 0,
			"The poster is the first thing in the week")
	var page: ScrollContainer = hub.find_children("*", "ScrollContainer", true, false)[0]
	var play: Button = hub.find_child("PlayMatch", true, false)
	var pick: Button = _button(hub, "Pick the side")
	_check(play != null and pick != null and not page.is_ancestor_of(play) and not page.is_ancestor_of(pick),
			"On a phone Pick the side and Play match are pinned under the page")
	var window := Rect2(Vector2.ZERO, hub.get_viewport_rect().size)
	_check(play != null and window.encloses(play.get_global_rect()) and window.encloses(pick.get_global_rect()),
			"Both are on the first screen")
	# Their routes unhooked, so the taps do not leave the hub mid-test.
	for b in [pick, play]:
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"])
		var why: String = await Tap.tap(b)
		_check(why == "", "A real tap reaches %s where it is pinned (%s)" % [b.text, why])
	hub.queue_free()
	await _settle()
	# A job or a notice sits under the poster, never above it.
	_state.staff_vacancies = [{"reason": "Your head of list management has left."}]
	hub = await _open_hub()
	week = hub.find_child("ThisWeek", true, false)
	poster = hub.find_child("MatchPoster", true, false)
	var notice: Control = hub.find_child("StaffNotice", true, false)
	_check(poster != null and poster.get_index() == 0 and notice != null and notice.get_index() > poster.get_index(),
			"With more to ask, the poster still leads the week")
	_state.staff_vacancies = []
	hub.queue_free()
	await _settle()
	# A card waiting on the coach comes first; the poster is under it with no
	# hole between, so its colours run under the fade.
	var card: Dictionary = _state.story_card("members_open_training")
	card["popped"] = true
	_state.week_events = [card]
	hub = await _open_hub()
	await _settle()
	var waiting: Control = hub.find_child("WaitingEvents", true, false)
	poster = hub.find_child("MatchPoster", true, false)
	page = hub.find_children("*", "ScrollContainer", true, false)[0]
	_check(waiting != null and poster != null
			and waiting.get_global_rect().position.y < poster.get_global_rect().position.y,
			"A waiting card stands above the poster")
	_check(hub.find_child("HubFoldGap", true, false) == null or poster == null
			or poster.get_index() == 0, "No gap is pushed in over the poster")
	_check(poster != null and poster.get_global_rect().position.y < page.get_global_rect().end.y,
			"The poster starts on the first screen under the card (%s in %s)" % [
			poster.get_global_rect() if poster != null else "-", page.get_global_rect()])
	hub.queue_free()
	await _settle()
	_state.week_events = []
	# Every club's name is whole on the poster and the two match, down to 320 wide.
	var codes: Array = db.players_by_club.keys()
	_check(codes.size() >= 18, "Every club is walked (%d)" % codes.size())
	var Poster = load("res://scripts/ui/MatchPoster.gd")
	for w in [320, 390]:
		var whole := true
		var same := true
		for code in codes:
			var holder := Control.new()
			holder.size = Vector2(w - 54, 300)
			root.add_child(holder)
			var other: String = codes[0] if code != codes[0] else codes[1]
			var one: Control = Poster.new().setup(code, other, true, "Home · MCG · Wet", true)
			one.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			holder.add_child(one)
			await _settle()
			var sizes := {}
			for lab: Label in one._names:
				var fs := lab.get_theme_font_size("font_size")
				sizes[fs] = true
				if lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lab.size.x + 0.5:
					whole = false
			same = same and sizes.size() == 1
			holder.free()
		_check(whole, "%d wide: no club's name is cut off on the poster" % w)
		_check(same, "%d wide: the two names are the same size" % w)


## A fresh career on the suite's seeds (tools/audit/README.md: both seeds,
## after reset and before start_season).
## The match ball on the poster (director, 2026-10-14): the real picture
## where the "v" was, never tinted, taking no room from the clubs' names and
## no taps; without the file the "v" is back and nothing has moved.
func _test_poster_ball() -> void:
	var db = root.get_node("GameDB")
	var art = load("res://scripts/ui/UiArt.gd")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		_reset()
		# The first-visit intro is answered, as a returning player has.
		_state.set_setting("seen_weekly_loop_intro", true)
		_state.start_season("FRE", db.club_list("FRE"))
		root.size = sz
		var hub := await _open_hub()
		var poster: Control = hub.find_child("MatchPoster", true, false)
		var ball: TextureRect = poster.find_child("MatchBall", true, false) if poster != null else null
		var tex: Texture2D = ball.texture if ball != null else null
		_check(tex != null and tex.resource_path == "res://assets/ui/models/match_ball.png"
				and float(tex.get_width()) >= 2.0 * ball.size.x,
				"%s: the poster shows the match ball's own picture, sharp at this size (%s)" % [tag, tex.resource_path if tex != null else "missing"])
		if ball == null:
			hub.queue_free()
			await _settle()
			continue
		var img := tex.get_image()
		var mid := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		_check(img.get_pixel(0, 0).a < 0.05 and mid.a > 0.95 and mid.r > 2.0 * mid.g and mid.r > 2.0 * mid.b
				and ball.modulate == Color.WHITE,
				"%s: it is a red football on a clear background, in no club's colour" % tag)
		var crests := poster.find_children("ClubMarker", "", true, false)
		var clear := poster.get_global_rect().grow(0.5).encloses(ball.get_global_rect())
		for c in crests:
			# The guernsey as drawn, narrower than its box.
			var box := (c as Control).get_global_rect()
			var drawn := box.grow_individual(-box.size.x * 0.2, 0, -box.size.x * 0.2, 0)
			clear = clear and not drawn.grow(7.5).intersects(ball.get_global_rect())
		var venue: Label = poster.find_child("MatchVenue", true, false)
		clear = clear and not venue.get_global_rect().intersects(ball.get_global_rect())
		_check(crests.size() == 2 and clear and absf(ball.get_global_rect().get_center().x - poster.get_global_rect().get_center().x) <= 1.0,
				"%s: the ball sits between the two guernseys, on the poster's centre, at least 8 from each and clear of the fixture line" % tag)
		var names_fit := true
		var name_places := []
		for l in poster.find_children("*", "Label", true, false):
			var lab := l as Label
			if lab.name == "Versus" or lab.name == "Opponent":
				continue
			name_places.append(lab.get_global_rect())
			var need := lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x
			if lab.autowrap_mode == TextServer.AUTOWRAP_OFF and need > lab.size.x + 0.5:
				names_fit = false
			if lab.autowrap_mode == TextServer.AUTOWRAP_OFF and Rect2(lab.global_position.x + (lab.size.x - need) / 2.0,
					lab.global_position.y, need, lab.size.y).intersects(ball.get_global_rect()):
				names_fit = false
		_check(names_fit, "%s: both clubs' names are whole and clear of the ball" % tag)
		_check(ball.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and (poster.find_child("MatchBallShadow", true, false) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"%s: the ball takes no taps" % tag)
		if sz.x < 600:
			var acts: Control = hub.find_child("WeekActions", true, false)
			var first: Button = null
			for b in (acts.find_children("*", "Button", true, false) if acts != null else []):
				if (b as Button).is_visible_in_tree() and not (b as Button).disabled:
					first = b
					break
			var act_h := first.size.y if first != null else 0.0
			var poster_rect := poster.get_global_rect()
			# Its route unhooked, so the tap does not leave the hub mid-test.
			for c in (first.pressed.get_connections() if first != null else []):
				first.pressed.disconnect(c["callable"])
			var why: String = await Tap.tap(first)
			_check(why == "", "%s: a real tap still reaches the week's first action under the poster (%s)" % [tag, why])
			if is_instance_valid(hub):
				hub.queue_free()
			await _settle()
			# Without the file: the "v", and every word where it was.
			art.dir = "res://assets/ui/no_such_folder"
			hub = await _open_hub()
			poster = hub.find_child("MatchPoster", true, false)
			var v: Label = poster.find_child("Versus", true, false)
			var same := poster.get_global_rect().is_equal_approx(poster_rect)
			var i := 0
			for l in poster.find_children("*", "Label", true, false):
				if (l as Label).name != "Versus" and (l as Label).name != "Opponent":
					same = same and i < name_places.size() and (l as Label).get_global_rect().is_equal_approx(name_places[i])
					i += 1
			_check(poster.find_child("MatchBall", true, false) == null and v != null and v.self_modulate.a == 1.0 and v.text == "v",
					"%s: without the picture the poster says 'v', as before" % tag)
			_check(same and i == name_places.size(), "%s: the ball moves no word on the poster and does not change its size" % tag)
			acts = hub.find_child("WeekActions", true, false)
			first = null
			for b in (acts.find_children("*", "Button", true, false) if acts != null else []):
				if (b as Button).is_visible_in_tree() and not (b as Button).disabled:
					first = b
					break
			_check(first != null and is_equal_approx(first.size.y, act_h) and act_h >= 44.0,
					"%s: the week's actions keep their size, a thumb tall (%d)" % [tag, int(act_h)])
			art.dir = "res://assets/ui/models"
		hub.queue_free()
		await _settle()

## The one who got away (P-16): the rules on their own. A player who played
## for you in this career and left is one; one who never played for you, or
## whose spell with you ended before the game began, is not. The report says
## what he did only when he played most of it or kicked a goal.
func _test_former_rules() -> void:
	var FP = load("res://scripts/sim/FormerPlayers.gd")
	var gone := {"id": "fp_gone", "club": "CAR", "career": {"stints": [["FRE", 2026, 2031, 142, 37], ["CAR", 2032, 2032, 9, 2]]}}
	var never := {"id": "fp_never", "club": "CAR", "career": {"stints": [["CAR", 2027, 2032, 80, 10]]}}
	var before := {"id": "fp_before", "club": "CAR", "career": {"stints": [["FRE", 2019, 2024, 60, 4], ["CAR", 2026, 2032, 70, 3]]}}
	var short := {"id": "fp_short", "club": "CAR", "career": {"stints": [["FRE", 2030, 2031, 12, 1]]}}
	var rows: Array = FP.against([never, short, gone, before], "FRE", 2033, {}, {}, [])
	_check(rows.size() == 2 and str(rows[0]["id"]) == "fp_gone" and str(rows[1]["id"]) == "fp_short",
			"Former players: only those who played for you in this career, most games first (%s)" % str(rows.map(func(r): return r["id"])))
	_check(not rows.is_empty() and int(rows[0]["games"]) == 142 and int(rows[0]["goals"]) == 37
			and int(rows[0]["from"]) == 2026 and int(rows[0]["to"]) == 2031,
			"Former players: his games, goals and years for you come from his career")
	_check(FP.against([gone], "", 2033).is_empty() and FP.against([gone], "CAR", 2033).is_empty(),
			"Former players: none without a club, and none for the club he plays for now")
	var cap := {"slots": [{"id": "fp_gone", "role": "captain"}]}
	var wrap := {"year": 2033, "outs": [{"id": "fp_short", "how": "trade"}, {"id": "fp_gone", "how": "delisted"}]}
	rows = FP.against([gone, short], "FRE", 2033, wrap, cap, [{"year": 2029, "my_club": "FRE", "my_bf": [{"id": "fp_gone"}]}])
	_check(rows.size() == 2 and str(rows[0]["role"]) == "captain" and str(rows[0]["how"]) == "delisted" and rows[0]["bf"] == [2029]
			and str(rows[1]["how"]) == "traded" and bool(rows[1]["moved"]),
			"Former players: how he left, his role now and his best and fairests are what was kept")
	if rows.size() < 2:
		return
	_check(FP.poster_line(rows[0], "Sam Walsh", "Carlton") == "Sam Walsh, 142 games for you, now Carlton's captain.",
			"Poster line with a role: %s" % FP.poster_line(rows[0], "Sam Walsh", "Carlton"))
	_check(FP.poster_line(rows[1], "Jo Bloggs", "Carlton") == "Jo Bloggs, traded to Carlton last year, lines up against you.",
			"Poster line for last year's trade: %s" % FP.poster_line(rows[1], "Jo Bloggs", "Carlton"))
	var older: Array = FP.against([short], "FRE", 2034, wrap)
	_check(older.size() == 1 and FP.poster_line(older[0], "Jo Bloggs", "Carlton") == "Jo Bloggs, 12 games for you, now plays for Carlton.",
			"An older move is not called last year's")
	_check(FP.report_line("Sam Walsh", 31, 1) == "Sam Walsh against his old side: 31 touches, 1 goal."
			and FP.report_line("Sam Walsh", 12, 0) == "Sam Walsh against his old side: 12 touches, no goals.",
			"Report line: %s" % FP.report_line("Sam Walsh", 31, 1))
	# Minutes on the ground from the bench and the interchanges: he starts, goes
	# off at 50 and back on at 80 (90 minutes); a bench player on at 100 (20).
	var res := {"roster": [[{"id": "m1", "num": 1}], [{"id": "fp_gone", "num": 7}, {"id": "fp_short", "num": 30}, {"id": "b2", "num": 31}]],
			"bench": [[], [{"id": "fp_short", "num": 30}]],
			"players": {"fp_gone": {"disposals": 31.0, "goals": 0.0}, "fp_short": {"disposals": 4.0, "goals": 0.0}},
			"events": [{"kind": "sub", "side": 1, "min": 50, "player_id": "b2", "off_num": 7},
				{"kind": "sub", "side": 1, "min": 80, "player_id": "fp_gone", "off_num": 31},
				{"kind": "sub", "side": 1, "min": 100, "player_id": "fp_short", "off_num": 31},
				{"kind": "final", "side": -1, "min": 120}]}
	_check(FP.minutes_on(res, 1, "fp_gone") == 90 and FP.minutes_on(res, 1, "fp_short") == 20
			and FP.minutes_on(res, 1, "nobody") == -1,
			"Minutes on the ground: %d and %d" % [FP.minutes_on(res, 1, "fp_gone"), FP.minutes_on(res, 1, "fp_short")])
	var lines: Array = FP.report_lines(res, 0, rows)
	_check(lines.size() == 1 and str(lines[0]["id"]) == "fp_gone" and str(lines[0]["text"]).ends_with(": 31 touches, no goals."),
			"Report: only the one who played most of it (%s)" % str(lines))
	res["players"]["fp_short"]["goals"] = 1.0
	lines = FP.report_lines(res, 0, rows)
	_check(lines.size() == 2 and str(lines[1]["id"]) == "fp_short",
			"Report: a goal off the bench is said too")
	_check(FP.report_lines(res, 1, rows).is_empty(), "Report: nothing when he is on your side of the sheet")


## A Fremantle player let go and now on the next opponent's list: one line under
## the poster, his name in his new club's ink and a tap on it opens him; nothing
## for one who never played for you. After the match the report says what he did,
## only when he played.
func _test_former_player() -> void:
	var db = root.get_node("GameDB")
	var kit = load("res://scripts/ui/UiKit.gd")
	var FP = load("res://scripts/sim/FormerPlayers.gd")
	_reset()
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.start_season("FRE", db.club_list("FRE"))
	root.size = Vector2i(390, 844)
	var opp := str(_state.my_next_opponent()["code"])
	var hub := await _open_hub()
	_check(hub.find_children("FormerPlayer_*", "Control", true, false).is_empty(),
			"No former-player line when none of yours is on their list")
	hub.queue_free()
	await _settle()
	# Your best player, delisted after 42 games, and one who never played for
	# you, both now with the opponent.
	var mine: Array = _state.season.lists["FRE"]
	var best_i := 0
	for i in range(mine.size()):
		if int(mine[i].get("overall", 0)) > int(mine[best_i].get("overall", 0)):
			best_i = i
	var gone: Dictionary = mine[best_i]
	var never: Dictionary = mine[(best_i + 1) % mine.size()]
	for p in [gone, never]:
		mine.remove_at(mine.find(p))
		if _state.my_list.has(p):
			_state.my_list.erase(p)
		p["club"] = opp
		(_state.season.lists[opp] as Array).append(p)
	gone["career"] = {"games": 42, "goals": 11, "stints": [["FRE", 2023, 2026, 42, 11]], "through": 2025, "unknown": []}
	never["career"] = {"games": 0, "goals": 0, "stints": [], "through": 2025, "unknown": []}
	_state.season_wrap = {"year": _state.season_year, "outs": [{"id": str(gone["id"]), "how": "delisted"},
			{"id": str(never["id"]), "how": "delisted"}], "seen": true}
	var gname: String = db.player_display_name(gone)
	var want := "%s, 42 games for you, now plays for %s." % [gname, db.club_name(opp)]
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		hub = await _open_hub()
		current_scene = hub
		var got := hub.find_children("FormerPlayer_*", "Control", true, false)
		_check(got.size() == 1 and _plain(got[0]) == want,
				"%s: one line for the player you let go, not for one who never played for you (%s)" % [tag, " | ".join(got.map(func(c): return _plain(c)))])
		var line: Control = got[0] if not got.is_empty() else null
		var ink := (line as RichTextLabel).text if line is RichTextLabel else ""
		_check(ink.contains("[color=#%s]" % kit.club_ink(opp).to_html(false)) and not ink.contains(kit.club_ink("FRE").to_html(false)),
				"%s: his name wears %s's ink, not yours" % [tag, opp])
		if line is RichTextLabel:
			var sc: Node = line.get_parent()
			while sc != null and not (sc is ScrollContainer):
				sc = sc.get_parent()
			if sc != null:
				(sc as ScrollContainer).ensure_control_visible(line)
				await _settle()
			var opened := await _tap_scan(line, hub)
			var sheet: Node = hub.get_node_or_null("PlayerProfile")
			var shown := ""
			if sheet != null:
				for c in sheet.find_children("*", "Label", true, false):
					shown = (c as Label).text
					break
			_check(opened and shown == gname, "%s: a tap on his name opens his profile (got '%s')" % [tag, shown])
		hub.queue_free()
		current_scene = null
		await _settle()
	# His role now leads: made their captain.
	_state.captaincy[opp] = {"slots": [{"id": str(gone["id"]), "role": "captain"}], "since": _state.season_year}
	var rows: Array = _state.former_players(opp)
	_check(rows.size() == 1 and FP.poster_line(rows[0], gname, db.club_name(opp)) == "%s, 42 games for you, now %s's captain." % [gname, db.club_name(opp)],
			"His captaincy at his new club is in the line")
	# The match: the report line is there exactly when he played most of it or kicked one.
	root.size = Vector2i(390, 844)
	_mine_only("FRE")
	_check(_state.prepare_interactive_match(), "A live match against your former player is prepared")
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	await _settle()
	var box: Node = m.find_child("CoachBox", true, false)
	var start: Button = box.find_child("StartQuarter", true, false) if box != null else null
	if start != null:
		start.emit_signal("pressed")
		await _settle()
	m.call("_on_skip")
	for i in range(60):
		await process_frame
	var res: Dictionary = m.get("_res")
	var me := 0 if str(res.get("home", "")) == "FRE" else 1
	var expect: Array = FP.report_lines(res, me, _state.former_players(opp))
	var lines := m.find_children("FormerAgainst_*", "Control", true, false)
	var mins: int = FP.minutes_on(res, 1 - me, str(gone["id"]))
	_check(not expect.is_empty() and lines.size() == expect.size() and _plain(lines[0]) == str(expect[0]["text"])
			and _plain(lines[0]).begins_with(gname + " against his old side: "),
			"The report says what he did against you (%d minutes: %s)" % [mins, " | ".join(lines.map(func(c): return _plain(c)))])
	var st: Dictionary = (res.get("players", {}) as Dictionary).get(str(gone["id"]), {})
	_check(not lines.is_empty() and _plain(lines[0]).contains(": %d touch" % int(float(st.get("disposals", 0.0)))),
			"The report's touches are his from this match")
	m.queue_free()
	await _settle()



## Storylines before the bounce (T5.Q9, "Build, 100+ games"): the rules on
## their own. 100 games at the old club earns a line, 99 does not; your man
## meeting his old club and theirs meeting yours; most games first; an id
## another line already names is left out; the line says the stored games.
func _test_old_club_rules() -> void:
	var OC = load("res://scripts/sim/OldClubLines.gd")
	var hundred := {"id": "oc_100", "club": "FRE", "career": {"stints": [["CAR", 2014, 2019, 60, 9], ["FRE", 2020, 2025, 50, 3], ["CAR", 2026, 2027, 40, 2]]}}
	var ninety_nine := {"id": "oc_99", "club": "FRE", "career": {"stints": [["CAR", 2015, 2022, 99, 12], ["FRE", 2023, 2025, 30, 1]]}}
	var theirs := {"id": "oc_theirs", "club": "CAR", "career": {"stints": [["FRE", 2012, 2022, 187, 40], ["CAR", 2023, 2025, 44, 6]]}}
	var home := {"id": "oc_home", "club": "CAR", "career": {"stints": [["CAR", 2010, 2025, 250, 80]]}}
	# The rules take the count as given; this one sums the stored stints.
	var stints := func(p: Dictionary, club: String) -> int:
		var g := 0
		for st in p["career"]["stints"]:
			if str(st[0]) == club:
				g += int(st[3])
		return g
	var rows: Array = OC.rows([ninety_nine, hundred], [home, theirs], "FRE", "CAR", stints)
	_check(rows.size() == 2 and str(rows[0]["id"]) == "oc_theirs" and str(rows[1]["id"]) == "oc_100",
			"Old club: 100 games earns a line, 99 does not, nor his own club; most games first (%s)" % str(rows.map(func(r): return r["id"])))
	_check(rows.size() == 2 and str(rows[0]["old"]) == "FRE" and not bool(rows[0]["mine"])
			and str(rows[1]["old"]) == "CAR" and bool(rows[1]["mine"]) and int(rows[1]["games"]) == 100,
			"Old club: which club and whose man come from the stints")
	_check(OC.rows([hundred], [theirs], "FRE", "CAR", stints, {"oc_theirs": true}).size() == 1
			and OC.rows([hundred], [], "", "CAR", stints).is_empty() and OC.rows([hundred], [], "CAR", "CAR", stints).is_empty()
			and OC.rows([hundred], [], "FRE", "CAR", Callable()).is_empty(),
			"Old club: a player already named is not told twice; none without two clubs or a count")
	var counted: Array = OC.rows([ninety_nine], [], "FRE", "CAR", func(_p, _c): return 100)
	_check(counted.size() == 1 and int(counted[0]["games"]) == 100,
			"Old club: the count given (this season included) decides the 100")
	if rows.size() < 2:
		return
	_check(OC.line(rows[1], "Jack Gunston", "Carlton") == "Jack Gunston faces his old club: 100 games for Carlton."
			and OC.line(rows[0], "Sam Walsh", "Fremantle") == "Sam Walsh faces his old club: 187 games for you.",
			"Old club lines: %s | %s" % [OC.line(rows[1], "Jack Gunston", "Carlton"), OC.line(rows[0], "Sam Walsh", "Fremantle")])
	# That MatchSim never names OldClubLines is a static lint: tools/lint/boundaries.py.


## The Hub's preview: a Fremantle man on 100 games for the opponent gets a line,
## one on 99 does not, and their man on 151 for Fremantle gets one; each line
## reads his stored games. Three lines at most; a tap on the name opens him.
func _test_old_club_preview() -> void:
	var db = root.get_node("GameDB")
	var Sq = load("res://scripts/sim/Squad.gd")
	_reset()
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.start_season("FRE", db.club_list("FRE"))
	root.size = Vector2i(390, 844)
	var opp := str(_state.my_next_opponent()["code"])
	# A clean slate: nobody in either list has a record anywhere.
	var blank := {}
	for p in _state.season.lists["FRE"] + _state.season.lists[opp] + _state.my_list:
		p["career"] = {"games": 0, "goals": 0, "stints": [], "through": 2025, "unknown": []}
		blank[str(p.get("id", ""))] = true
	var hub := await _open_hub()
	_check(blank.size() > 40 and hub.find_children("OldClub_*", "Control", true, false).is_empty(),
			"No old-club line when no one has played for the other club")
	hub.queue_free()
	await _settle()
	# The squads hold match copies: edit the list's own records of the picked men.
	var by_id := {}
	for p in _state.my_list + _state.season.lists[opp]:
		by_id[str(p.get("id", ""))] = p
	var their_sq = Sq.new(db.club_name(opp), _state.season.lists[opp], true, opp, _state.season.selections.get(opp, {}))
	var mine: Array = _state.my_squad().ground.map(func(p): return by_id.get(str(p.get("id", "")), {}))
	var theirs: Array = their_sq.ground.map(func(p): return by_id.get(str(p.get("id", "")), {}))
	_check(mine.size() >= 4 and theirs.size() >= 1, "Both sides are picked (%d, %d)" % [mine.size(), theirs.size()])
	if mine.size() < 4 or theirs.is_empty():
		return
	var a: Dictionary = mine[0]
	var b: Dictionary = mine[1]
	var t: Dictionary = theirs[0]
	a["career"] = {"games": 160, "goals": 25, "stints": [[opp, 2016, 2021, 100, 20], ["FRE", 2022, 2025, 60, 5]], "through": 2025, "unknown": []}
	b["career"] = {"games": 159, "goals": 25, "stints": [[opp, 2016, 2021, 99, 20], ["FRE", 2022, 2025, 60, 5]], "through": 2025, "unknown": []}
	t["career"] = {"games": 201, "goals": 43, "stints": [["FRE", 2014, 2022, 151, 40], [opp, 2023, 2025, 50, 3]], "through": 2025, "unknown": []}
	var an: String = db.player_display_name(a)
	var bn: String = db.player_display_name(b)
	var tn: String = db.player_display_name(t)
	var want := ["%s faces his old club: 151 games for you." % tn,
			"%s faces his old club: 100 games for %s." % [an, db.club_name(opp)]]
	hub = await _open_hub()
	current_scene = hub
	var got := hub.find_children("OldClub_*", "Control", true, false)
	var said: Array = got.map(func(c): return _plain(c))
	_check(said == want, "The preview says the 100-game men from their records, not the 99 (%s)" % " | ".join(said))
	_check(not " ".join(said).contains(bn), "No line for %s on 99 games" % bn)
	if not got.is_empty():
		var line: Control = got[0]
		var sc: Node = line.get_parent()
		while sc != null and not (sc is ScrollContainer):
			sc = sc.get_parent()
		if sc != null:
			(sc as ScrollContainer).ensure_control_visible(line)
			await _settle()
		var opened := await _tap_scan(line, hub)
		var sheet: Node = hub.get_node_or_null("PlayerProfile")
		var shown := ""
		if sheet != null:
			for c in sheet.find_children("*", "Label", true, false):
				shown = (c as Label).text
				break
		_check(opened and shown == tn, "A tap on his name opens his profile (got '%s')" % shown)
	hub.queue_free()
	current_scene = null
	await _settle()
	# Four with a long record: three lines, the most games first.
	mine[2]["career"] = {"games": 130, "goals": 1, "stints": [[opp, 2012, 2025, 130, 1]], "through": 2025, "unknown": []}
	mine[3]["career"] = {"games": 120, "goals": 1, "stints": [[opp, 2012, 2025, 120, 1]], "through": 2025, "unknown": []}
	hub = await _open_hub()
	got = hub.find_children("OldClub_*", "Control", true, false)
	said = got.map(func(c): return _plain(c))
	_check(said.size() == 3 and str(said[0]).ends_with("151 games for you.") and str(said[1]).ends_with("130 games for %s." % db.club_name(opp))
			and str(said[2]).ends_with("120 games for %s." % db.club_name(opp)),
			"At most three storylines, the most games first (%s)" % " | ".join(said))
	hub.queue_free()
	await _settle()

## Touch along a line until a profile opens on `host`.
func _tap_scan(label: Control, host: Node) -> bool:
	var r := label.get_global_rect()
	var y := r.position.y + 8.0
	while y < r.end.y:
		var x := r.position.x + 4.0
		while x < r.end.x:
			for down in [true, false]:
				var t := InputEventScreenTouch.new()
				t.index = 0
				t.position = Vector2(x, y)
				t.pressed = down
				Input.parse_input_event(t)
				Input.flush_buffered_events()
				await process_frame
			await process_frame
			await process_frame
			if host.get_node_or_null("PlayerProfile") != null:
				return true
			x += 5.0
		y += 14.0
	return false


## The opposition facts on the hub are facts only (director, 2026-11-08: "These
## functions all belong to the pregame so it's just repetitive"): each fact the
## hub states is its line from opponent_facts, with no response cards under it
## and no gap where they were, and every name in it wears his club's ink. Tag,
## defensive set-up and game plan stay on the pre-bounce setup. Play match
## takes a real tap: with Watch chosen it opens the match preview, with Skip
## chosen it opens your match skipped.
func _test_facts_without_options() -> void:
	var db = root.get_node("GameDB")
	var NI = load("res://scripts/ui/NameInk.gd")
	var kit = load("res://scripts/ui/UiKit.gd")
	for club in ["FRE", "BRL"]:
		_reset()
		_state.set_setting("seen_weekly_loop_intro", true)
		_state.start_season(club, db.club_list(club))
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			var tag := "%s %dx%d" % [club, sz.x, sz.y]
			root.size = sz
			_state.set_match_way("watch")
			var hub := await _open_hub()
			var opp := str(_state.my_next_opponent()["code"])
			var facts: Array = _state.opponent_facts(opp)
			var index: Dictionary = NI.from_lists(_state.season.lists)
			var opp_ink := "[color=#%s]" % kit.club_ink(opp).to_html(false)
			var said := true
			var close := true
			var inked := true
			var named := 0
			var opp_named := 0
			var bad := ""
			for i in range(facts.size()):
				var fl: Control = hub.find_child("Fact_%d" % i, true, false)
				var ok: bool = fl != null and _plain(fl) == str(facts[i]["text"])
				if not ok and bad == "":
					bad = "Fact_%d: %s" % [i, _plain(fl) if fl != null else "missing"]
				said = said and ok
				# A name in the fact wears his club's ink: the line is the
				# NameInk markup of its words, the opponent's in theirs.
				var want: String = NI.markup(str(facts[i]["text"]), index)
				if want != "":
					named += 1
					inked = inked and fl is RichTextLabel and (fl as RichTextLabel).text == want
					if want.contains(opp_ink):
						opp_named += 1
				if i > 0 and fl != null:
					var before: Control = hub.find_child("Fact_%d" % (i - 1), true, false)
					close = close and before != null and before.get_parent() == fl.get_parent() \
							and fl.get_index() == before.get_index() + 1
			_check(facts.size() >= 2 and said, "%s: each opposition fact is on the hub, word for word (%d facts) %s" % [tag, facts.size(), bad])
			_check(close, "%s: each fact follows the one before it, nothing left between them" % tag)
			_check(named > 0 and inked and opp_named > 0,
					"%s: each name in a fact wears his club's ink, %s's own in theirs (%d named, %d in %s ink)" % [
						tag, opp, named, opp_named, opp])
			var cards := hub.find_children("FactOption*", "", true, false)
			_check(cards.is_empty(), "%s: no response cards under the facts (%d found)" % [tag, cards.size()])
			hub.queue_free()
			await _settle()
		# Skip chosen: the main button says Skip to full time.
		root.size = Vector2i(390, 844)
		_state.set_match_way("skip")
		var hub2 := await _open_hub()
		var play: Button = hub2.find_child("PlayMatch", true, false)
		_check(play != null and play.text == "Skip to full time",
				"%s: with Skip chosen the main button says Skip to full time (%s)" % [club, play.text if play != null else "none"])
		hub2.queue_free()
		await _settle()
		# The setting outlives _reset: put Watch back for the suites after this one.
		_state.set_match_way("watch")
	root.size = Vector2i(390, 844)
	await _play_tap_routes()


## A real tap on the hub's main button, the way a finger reaches it: with Watch
## chosen, Play match opens the match preview; with Skip chosen, Skip to full
## time opens your match, taken as a skip (director, 2026-11-08: the hub's
## facts carry no response cards, so nothing turns a Skip into a Watch).
func _play_tap_routes() -> void:
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	var vignettes_were: bool = _state.vignettes_on()
	# One career for both: Watch only opens the preview, so Skip meets the same
	# unplayed Round 1, with only your match in it.
	_reset()
	_state.set_vignettes_on(false)
	_state.start_season("FRE", db.club_list("FRE"))
	_mine_only("FRE")
	for way in ["watch", "skip"]:
		_state.set_match_way(way)
		router.stack = []
		router.go("hub")
		await _settle()
		var hub: Node = get_current_scene()
		var play: Button = hub.find_child("PlayMatch", true, false) if hub != null else null
		var why: String = await Tap.tap(play) if play != null else "missing"
		var want := "MatchPreviewScene" if way == "watch" else "MatchScene"
		var at: Node = null
		var saw_box := false
		for i in range(120):
			await process_frame
			at = get_current_scene()
			if at != null and at.name == "MatchScene":
				saw_box = saw_box or at.find_child("CoachBox", true, false) != null
			# A skip is let run to its full time before the screen is put away.
			if at != null and at.name == want and (way == "watch" or bool(at.get("_fulltime_shown"))):
				break
		var landed := at != null and at.name == want
		if way == "watch":
			_check(why == "" and landed and at.find_child("PreviewContinue", true, false) != null,
					"Watch chosen: a real tap on Play match opens the match preview (%s, %s)" % [
						why, str(at.name) if at != null else "none"])
		else:
			# MatchScene takes the skip and puts the live way back to Watch, so
			# the proof is the screen: full time, no coach box on the way.
			var ft := landed and bool(at.get("_fulltime_shown"))
			_check(why == "" and ft and not saw_box and _state.pending_sim == null,
					"Skip chosen: a real tap on Skip to full time takes your match straight to full time (%s, %s, full time %s, coach box %s)" % [
						why, str(at.name) if at != null else "none", str(ft), str(saw_box)])
		if at != null:
			at.queue_free()
		_state.pending_sim = null
		_state.pending_match = {}
		router.stack = []
		await _settle()
	_state.set_match_way("watch")
	_state.set_vignettes_on(vignettes_were)


## No one tags ruckmen (director, 2026-10-18): across every club's list, a
## ruck-first player is never a tag target, whatever else he lists.
func _test_no_ruck_tag() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("FRE", db.club_list("FRE"))
	var RT = load("res://scripts/sim/Ratings.gd")
	var MSX = load("res://scripts/sim/MatchSim.gd")
	var ruck_seen := 0
	var ruck_ok := true
	var clubs_seen := 0
	for code in _state.season.lists:
		clubs_seen += 1
		for p in _state.season.lists[code]:
			if str(RT.positions(p)[0]) == "RUCK":
				ruck_seen += 1
				var in_mid: Dictionary = (p as Dictionary).duplicate(true)
				in_mid["own_role"] = "RUCK"
				in_mid["role"] = "MID"
				ruck_ok = ruck_ok and not MSX.can_be_tagged(p) and not MSX.taggable(in_mid)
	_check(ruck_ok and clubs_seen >= 18 and ruck_seen > 18,
			"No ruck-first player on any club's list can be tagged, even picked in the midfield (%d clubs, %d rucks)" % [clubs_seen, ruck_seen])


## Every match-day gate's gain and cost carry the sim's own constants (bible
## §4, director 2026-10-18); the templates hold no figure.
func _test_gate_odds() -> void:
	_gate_odds()


func _reset() -> void:
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.replay_seed = SUITE_SEED


## The coming round with only `code`'s match left in it, where a test reads
## only that club's week: the other matches are most of a round's time.
func _mine_only(code: String) -> void:
	var s = _state.season
	if s == null or s.round_index >= s.fixture.size():
		return
	var rm: Array = s.fixture[s.round_index]
	for m in rm.duplicate():
		if str(m["home"]) != code and str(m["away"]) != code:
			rm.erase(m)


## Straight to September: the home and away season is not under test, only
## the finals weeks after it.
func _to_finals() -> void:
	_state.season.round_index = _state.season.fixture.size()
	_state.ensure_finals()


## The status line over the bracket on every path a side can take through the finals: a
## qualifying final's loser is still alive (the double chance), every other loser's season
## has ended, the premiers say so (found by uiart: "Your season ended in the Qualifying
## Final 2" over a side in the Grand Final).
func _test_finals_status_paths() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("FRE", db.club_list("FRE"))
	var top: Array = ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10"]
	var me := "A1"
	var cases := [
		["a week off in the wildcard round", {}, false, "Still alive"],
		["lost the qualifying final", {"L_QF1": me}, false, "Still alive"],
		["lost the qualifying final, won the semi", {"L_QF1": me, "W_SF1": me}, false, "Still alive"],
		["lost the qualifying final, won the semi and the preliminary final", {"L_QF1": me, "W_SF1": me, "W_PF1": me}, false, "Still alive"],
		["lost the qualifying final, then the semi", {"L_QF1": me, "L_SF1": me}, false, "season ended in the Semi Final 1"],
		["won the qualifying final, lost the preliminary final", {"W_QF1": me, "L_PF1": me}, false, "season ended in the Preliminary Final 1"],
		["lost an elimination final", {"L_EF1": me}, false, "season ended in the Elimination Final 1"],
		["lost a wildcard final", {"L_WC1": me}, false, "season ended in the Wildcard Final 1"],
		["lost the Grand Final", {"W_QF1": me, "L_GF": me}, true, "season ended in the Grand Final"],
		["won the Grand Final", {"W_QF1": me, "W_GF": me}, true, "Premiers"],
	]
	for c in cases:
		var f: Dictionary = {"week": 5, "top": top, "slots": (c[1] as Dictionary).duplicate(), "weeks": [], "premier": "", "runner_up": "", "done": bool(c[2])}
		if str(c[3]) == "Premiers":
			f["premier"] = me
		var sea = _state.season
		var saved: Dictionary = sea.finals
		sea.finals = f
		var host := MarginContainer.new()
		root.add_child(host)
		var fb = load("res://scripts/ui/FinalsBracket.gd").new()
		host.add_child(fb)
		fb.setup(sea, me, func(_md): pass)
		await _settle()
		var you: Label = fb.find_child("FinalsYou", true, false)
		var text := you.text if you != null else "-"
		if str(c[3]) == "Premiers":
			# The premiers' cup says it (#736): one "Premiers" over the club's name, and
			# the status line under it stays silent rather than saying it twice.
			var said := ""
			for n in fb.find_children("*", "Label", true, false):
				if (n as Label).text == "Premiers":
					said = (n as Label).text
			_check(said == "Premiers", "Finals status, %s: the cup reads Premiers (%s)" % [c[0], said])
			_check(fb.find_child("FinalsPremier", true, false) != null, "Finals status, %s: the cup names the club" % c[0])
			_check(you == null, "Finals status, %s: the line under it does not say it twice (%s)" % [c[0], text])
		else:
			_check(text.contains(str(c[3])), "Finals status, %s: reads %s (%s)" % [c[0], c[3], text])
		if str(c[3]) == "Still alive":
			_check(not text.contains("ended"), "Finals status, %s: never says the season ended" % c[0])
		host.queue_free()
		sea.finals = saved
		await _settle()


## The cup on the finals series (director, 2026-10-14): the real cup art over
## the Grand Final before it is played, phone and PC, and big in the
## premier's colour once it is won. Every match is still there to tap.
func _test_finals_cup() -> void:
	var db = root.get_node("GameDB")
	var kit = load("res://scripts/ui/UiKit.gd")
	_reset()
	_state.start_season("FRE", db.club_list("FRE"))
	_to_finals()
	var guard := 0
	while guard < 400 and not _state.season.is_season_over():
		var f: Dictionary = _state.season.finals
		if not f.is_empty() and int(f.get("week", 1)) >= 5:
			break
		_state.advance()
		guard += 1
	for decided in [false, true]:
		if decided:
			guard = 0
			while guard < 10 and not _state.season.is_season_over():
				_state.advance()
				guard += 1
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			var tag := "%dx%d %s" % [sz.x, sz.y, "decided" if decided else "Grand Final week"]
			root.size = sz
			var host := MarginContainer.new()
			root.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var tapped := []
			var fb = load("res://scripts/ui/FinalsBracket.gd").new()
			host.add_child(fb)
			fb.setup(_state.season, _state.my_club, func(md): tapped.append(str(md["tag"])))
			fb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			await _settle()
			var gf: Button = fb.find_child("Final_GF", true, false)
			if not decided:
				var cup: Control = fb.find_child("FinalsCup", true, false)
				var art: TextureRect = cup.find_child("Art_premiership_cup", true, false) if cup != null else null
				_check(art != null and art.texture.resource_path == "res://assets/honours/premiership_cup.png" and art.modulate == Color.WHITE
						and art.size.y >= 120.0,
						"%s: the real cup stands over the Grand Final, silver, %d tall" % [tag, int(art.size.y) if art != null else 0])
				_check(gf != null and cup != null and cup.get_global_rect().end.y <= gf.global_position.y + 0.5
						and Rect2(Vector2.ZERO, Vector2(sz)).encloses(cup.get_global_rect()) and gf.size.y >= 44.0,
						"%s: the cup is whole on the screen and the Grand Final sits under it, a thumb tall" % tag)
				if sz.x < 600:
					_check(fb.find_child("FinalsCupBand", true, false) != null and (fb.find_child("FinalsCupBand", true, false) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
							"%s: with both Grand Finalists known the cup stands between their colours" % tag)
				_check(fb.find_child("FinalsRibbons", true, false) == null, "%s: no ribbons before there is a premier" % tag)
				var why: String = await Tap.tap(gf)
				_check(why == "" and tapped == ["GF"], "%s: a real tap still opens the Grand Final (%s)" % [tag, why])
			else:
				var prem := str(_state.season.finals.get("premier", ""))
				var hero: Control = fb.find_child("FinalsHero", true, false)
				var art: TextureRect = hero.find_child("Art_premiership_cup", true, false) if hero != null else null
				_check(art != null and art.texture.resource_path == "res://assets/honours/premiership_cup.png" and art.size.y >= 130.0,
						"%s: the premiers' cup is the real art, big (%d)" % [tag, int(art.size.y) if art != null else 0])
				var wash = hero.find_child("FinalsWash", true, false) if hero != null else null
				var ink: Color = kit.club_ink(prem)
				_check(wash != null and kit.contrast((wash.colour as Color).darkened(0.2), Color.WHITE) >= 3.5
						and (absf((wash.colour as Color).h - ink.h) < 0.03 or ink.s < 0.1),
						"%s: the cup stands in the premier's own colour, dark enough for white type (%s for %s)" % [tag, (wash.colour as Color).to_html(false) if wash != null else "-", prem])
				var who: Label = hero.find_child("FinalsPremier", true, false) if hero != null else null
				var whole := who != null and who.text == str(db.club_short(prem))
				for l in (hero.find_children("*", "Label", true, false) if hero != null else []):
					var lab := l as Label
					if lab.size.y + 1.0 < lab.get_combined_minimum_size().y or not hero.get_global_rect().grow(0.5).encloses(lab.get_global_rect()):
						whole = false
					if lab.autowrap_mode == TextServer.AUTOWRAP_OFF and lab.get_theme_font("font").get_string_size(lab.text,
							HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x > lab.size.x + 0.5:
						whole = false
				_check(whole and Rect2(Vector2.ZERO, Vector2(sz)).encloses(hero.get_global_rect()),
						"%s: the premiers are named whole beside the cup, on the screen (%s)" % [tag, who.text if who != null else "-"])
				var you: Label = fb.find_child("FinalsYou", true, false)
				var said := 0
				for l in fb.find_children("*", "Label", true, false):
					if (l as Label).is_visible_in_tree() and (l as Label).text.begins_with("Premiers"):
						said += 1
				_check(said == 1 and ((prem == str(_state.my_club) and you == null)
						or (prem != str(_state.my_club) and you != null and you.text != "" and you.global_position.y >= hero.get_global_rect().end.y - 0.5)),
						"%s: 'Premiers' is said once, and your own finish under it unless the cup is yours (%s)" % [tag, you.text if you != null else "the cup is yours"])
				_check(fb.find_child("FinalsCup", true, false) == null, "%s: one cup on the screen, not two" % tag)
				var rib: Control = hero.find_child("FinalsRibbons", true, false) if hero != null else null
				var rib_art: TextureRect = rib.find_child("Art_premiership_ribbons", true, false) if rib != null else null
				var rib_mat: ShaderMaterial = rib_art.material as ShaderMaterial if rib_art != null else null
				var cols: Array = db.club_colours(prem)
				_check(rib_art != null and rib_art.texture.resource_path == "res://assets/honours/premiership_ribbons.png" and rib_mat != null
						and (rib_mat.get_shader_parameter("primary") as Color).is_equal_approx(cols[0])
						and (rib_mat.get_shader_parameter("secondary") as Color).is_equal_approx(cols[1])
						and art != null and rib_art.get_global_rect().is_equal_approx(art.get_global_rect()),
						"%s: the cup wears the premier's ribbons in the club's two colours, laid straight over it (%s)" % [tag, prem])
				var why: String = await Tap.tap(gf) if gf != null and gf.is_visible_in_tree() else "the Grand Final is not shown"
				_check(why == "" and tapped == ["GF"], "%s: a real tap still opens the Grand Final that was played (%s)" % [tag, why])
			host.queue_free()
			await _settle()
	root.size = Vector2i(390, 844)


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


## Premiership streamers (director, 2026-11-04: particles only for the
## premiership and the Brownlow reveal). They fall once when the finals series
## opens with the flag decided, in the premiers' two colours, go through a
## finger, stay clear of Done, and play nowhere else.
func _test_premiership_streamers() -> void:
	var db = root.get_node("GameDB")
	var feel = load("res://scripts/ui/Feel.gd")
	var kit = load("res://scripts/ui/UiKit.gd")
	_reset()
	_state.start_season("FRE", db.club_list("FRE"))
	# The first postseason's intro (FirstVisitIntro, once per career) is its own
	# test: seen already here, so it never lies over Finals. Whether it comes up
	# on these hubs otherwise turns on whether the seeded season leaves a press
	# conference waiting after the Grand Final, which it is held back behind.
	_state.mark_intro_seen("postseason")
	_state.season.round_index = _state.season.fixture.size() - 1
	_mine_only("FRE")
	_state.advance()
	if not _state.training_report.is_empty():
		_state.training_report["dismissed"] = true
	root.size = Vector2i(390, 844)
	feel.test_motion = true
	var hub: Control = await _open_hub()
	await _clear_hub(hub)
	# September, the flag not yet decided: the series opens with no streamers.
	hub.call("_show_finals")
	await _frames(20)
	_check(hub.find_child("FinalsSheet", true, false) != null
			and hub.find_children("PremiershipStreamers", "", true, false).is_empty(),
			"Before the Grand Final the finals series has no streamers")
	hub.call("_close_finals")
	hub.queue_free()
	await _settle()
	var guard := 0
	while not _state.season.is_season_over() and guard < 12:
		_state.advance()
		guard += 1
	var premier := str(_state.season.finals.get("premier", ""))
	_check(premier != "", "A premier to celebrate")
	if not _state.training_report.is_empty():
		_state.training_report["dismissed"] = true
	# Reduced motion: nothing falls.
	feel.reduced = true
	hub = await _open_hub()
	await _clear_hub(hub)
	hub.call("_show_finals")
	await _settle()
	_check(hub.find_children("PremiershipStreamers", "", true, false).is_empty(),
			"With Reduced motion on, no streamers fall")
	hub.call("_close_finals")
	hub.queue_free()
	await _settle()
	feel.reduced = false
	feel.moved.clear()
	hub = await _open_hub()
	await _clear_hub(hub)
	var series: Button = hub.find_child("FinalsOpen", true, false)
	await Tap.steady(series)
	var why: String = await Tap.tap(series) if series != null else "no Finals button"
	await _frames(20)
	var found := hub.find_children("PremiershipStreamers", "", true, false)
	_check(why == "" and found.size() == 1, "The flag decided: a tap on Finals starts the streamers (%s, %d)" % [why, found.size()])
	if found.size() != 1:
		feel.test_motion = false
		hub.queue_free()
		return
	var fall: Control = found[0]
	fall.set_process(false)   # the test moves the clock
	var want: Array = [kit.club_ink(premier), kit.club_ink_second(premier)]
	var cols: Array = fall.get("colours")
	_check(str(fall.get("club")) == premier and cols.size() == 2 and (cols[0] as Color).is_equal_approx(want[0])
			and (cols[1] as Color).is_equal_approx(want[1]) and not (want[0] as Color).is_equal_approx(want[1]),
			"The streamers are the premiers' two colours")
	_check(feel.moved.count("streamers") == 1, "They start once")
	var done: Button = hub.find_child("FinalsDone", true, false)
	var both := false
	var clear := true
	var t := 0.2
	while t < float(fall.get("DURATION")):
		fall.call("seek", t)
		var seen := [false, false]
		for r in fall.call("ribbons"):
			var c: Color = r[1]
			for i in 2:
				var w: Color = want[i]
				if is_equal_approx(c.r, w.r) and is_equal_approx(c.g, w.g) and is_equal_approx(c.b, w.b):
					seen[i] = true
			for pt in r[0]:
				if (fall.global_position.y + (pt as Vector2).y) >= done.global_position.y:
					clear = false
		if is_equal_approx(t, 1.6):
			both = seen[0] and seen[1]
		t += 0.2
	_check(both, "Mid-fall both colours are on screen")
	_check(clear, "No streamer reaches the Done button at any moment")
	# The bracket redraws when a stage is picked: no second fall.
	fall.call("seek", 1.6)
	var stage: Node = hub.find_child("FinalsStage", true, false)
	var tab: Button = null
	if stage != null:
		for b in stage.find_children("*", "BaseButton", true, false):
			if not (b as BaseButton).button_pressed:
				tab = b
				break
	var tab_why: String = await Tap.tap(tab) if tab != null else "no stage tab"
	await _settle()
	var after := hub.find_children("PremiershipStreamers", "", true, false)
	_check(tab_why == "" and after.size() == 1 and after[0] == fall and feel.moved.count("streamers") == 1,
			"A tap goes through the streamers to the stage tabs, and no second fall starts (%s)" % tab_why)
	# The fall ends and takes itself away; nothing plays again on this visit.
	fall.call("seek", float(fall.get("DURATION")))
	await _settle()
	_check(hub.find_children("PremiershipStreamers", "", true, false).is_empty()
			and feel.moved.count("streamers") == 1 and hub.find_child("FinalsSheet", true, false) != null,
			"After one fall the streamers are gone and stay gone while the series is open")
	hub.call("_close_finals")
	await _settle()
	# Done under a fall: the finger reaches it.
	hub.call("_show_finals")
	await _frames(20)
	var again := hub.find_children("PremiershipStreamers", "", true, false)
	_check(again.size() == 1, "Opening the series again is a new visit: one fall")
	if again.size() == 1:
		(again[0] as Control).set_process(false)
		(again[0] as Control).call("seek", 1.6)
	done = hub.find_child("FinalsDone", true, false)
	var done_why: String = await Tap.tap(done) if done != null else "no Done"
	await _settle()
	_check(done_why == "" and hub.find_child("FinalsSheet", true, false) == null,
			"Done closes the series under falling streamers (%s)" % done_why)
	feel.test_motion = false
	hub.queue_free()
	await _settle()
	# Nowhere else: only the hub's finals series names the streamers.
	var users := []
	_scripts_naming("res://scripts", "PremiershipStreamers", users)
	users.sort()
	_check(users == ["res://scripts/ui/HubScene.gd", "res://scripts/ui/PremiershipStreamers.gd"],
			"Only the finals series plays streamers (%s)" % str(users))
	var hub_src := FileAccess.get_file_as_string("res://scripts/ui/HubScene.gd")
	_check(hub_src.count("PremiershipStreamers") == 1, "The hub starts them in one place only")


## Close whatever opened over a fresh hub, as a player would.
func _clear_hub(hub: Control) -> void:
	var guard := 0
	while hub.find_child("MediaConference", true, false) != null and guard < 4:
		hub.call("handle_back")
		await _settle()
		guard += 1


## Suites run on a fixed frame clock (60 a second): 20 frames lets a sheet rise.
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scripts_naming(dir: String, word: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_scripts_naming(dir + "/" + d, word, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir + "/" + f).contains(word):
			out.append(dir + "/" + f)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## The words under the pre-match scene are atmosphere, and a final opens with
## its own line. Only a real final counts as one: every final's label does, no
## home-and-away round does, and a missing label is not a final. (Only the
## selection is tested; the fixed words are not.)
## The banner scene's frame budget (web build on a PC ran it slowly): what is the same
## every frame is worked out once, not each frame - the stand ring, the oval's turf and
## markings points - and the banner's tear times are the same as working each piece out.

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)
func _test_banner_scene_budget() -> void:
	var VG = load("res://scripts/ui/match/VignetteGround.gd")
	var a = VG._ring_columns(74.0, 86.0, 2.1875)
	_check(is_same(a, VG._ring_columns(74.0, 86.0, 2.1875)), "The stand ring is made once, not every frame")
	_check(is_same(VG._ellipse_ring(68.0, 80.0, 0.0, 0.0, 360), VG._ellipse_ring(68.0, 80.0, 0.0, 0.0, 360)),
			"The boundary's points are made once")
	_check(is_same(VG._band(0.0, 12.0), VG._band(0.0, 12.0)), "A mown stripe's points are made once")
	_check(is_same(VG._arc(79.0, 1.0), VG._arc(79.0, 1.0)), "The 50 m arc's points are made once")
	_check((a as Array).size() > 100 and float(a[a.size() - 1][0]) >= TAU - 0.0001, "The ring still closes round the ground")
	var pm = load("res://scripts/ui/match/PreMatchVignette.gd")
	var v = pm.new()
	var crossings := []
	for i in range(23):
		crossings.append([(float(i) - 11.0) * 0.7, 1.0 + float(i) * 0.05])
	var cached: PackedFloat64Array = v._tear_times(crossings)
	_check(cached.size() == pm.BANNER_COLS * pm.BANNER_ROWS, "A tear time for every piece of the banner")
	var cw: float = 2.0 * pm.BANNER_W / pm.BANNER_COLS
	var ch: float = (pm.BANNER_TOP - pm.BANNER_LOW) / pm.BANNER_ROWS
	var same := true
	for c in range(pm.BANNER_COLS):
		for r in range(pm.BANNER_ROWS):
			var want: float = v._tear_time(-pm.BANNER_W + (c + 0.5) * cw, pm.BANNER_LOW + (r + 0.5) * ch, c * 31 + r * 7, crossings)
			if cached[c * pm.BANNER_ROWS + r] != want:
				same = false
	_check(same, "The cached tear times are the piece-by-piece ones")
	v.free()
	var t0 := Time.get_ticks_usec()
	for i in range(200):
		VG._ring_columns(74.0, 86.0, 2.1875)
	_check(Time.get_ticks_usec() - t0 < 50000, "200 frames of the stand ring take under 50 ms (a generous ceiling)")


func _test_pre_match_captions() -> void:
	var db = root.get_node("GameDB")
	_reset()
	_state.start_season("COL", db.club_list("COL"))
	var ground: Array = _state.my_squad().ground
	var pm = load("res://scripts/ui/match/PreMatchVignette.gd")
	_check(pm.is_final("Wildcard Final 1") and pm.is_final("Qualifying Final 2")
			and pm.is_final("Elimination Final 1") and pm.is_final("Semi Final 2")
			and pm.is_final("Preliminary Final 1") and pm.is_final("Grand Final"),
			"Every final's fixture label counts as a final")
	_check(not pm.is_final("Round 1") and not pm.is_final("Round 24") and not pm.is_final(""),
			"No round, and no missing label, counts as a final")
	var final_scene = pm.new()
	final_scene.setup_prematch("COL", "SYD", ground, ground, "Grand Final", true)
	var round_scene = pm.new()
	round_scene.setup_prematch("COL", "SYD", ground, ground, "Round 24", false)
	_check(final_scene.copy == "Finals footy. Here we go.",
			"A final opens with its own line (%s)" % final_scene.copy)
	_check(round_scene.copy == "Warming up",
			"An ordinary round still opens with Warming up (%s)" % round_scene.copy)
	final_scene.free()
	round_scene.free()


## Play match puts the pre-match scene up in the same frame as the tap:
## a couple of seconds of match day (warm-up, final instructions, through the
## banner) while the match is set up, then the match. A tap sends them
## through the banner at once.
func _test_pre_match_scene() -> void:
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	for skip in [false, true]:
		_reset()
		_state.start_season("COL", db.club_list("COL"))
		# The round's other matches would play on threads behind this one; the
		# scene is about COL's match alone.
		_mine_only("COL")
		root.size = Vector2i(390, 844)
		var hub: Control = await _open_hub()
		var play := _button(hub.find_child("WeekActions", true, false), "Play match")
		play.emit_signal("pressed")
		# Play match opens the match preview first (director, 2026-11-07: its own
		# step before the setup); its Continue starts the match.
		var cont: Button = null
		for i in range(30):
			await process_frame
			var pv := get_current_scene()
			cont = pv.find_child("PreviewContinue", true, false) if pv != null and pv.name == "MatchPreviewScene" else null
			if cont != null:
				break
		_check(cont != null, "Play match opens the match preview, Continue on it")
		if cont == null:
			hub.queue_free()
			return
		cont.emit_signal("pressed")
		var vig = root.find_child("PreMatchVignette", true, false)
		_check(vig != null, "Continue cuts to the pre-match scene in the same frame")
		if vig == null:
			hub.queue_free()
			return
		if not skip:
			# The banner is this match's rhyme (Banners.pick on GameState.banner_context).
			var ctx: Dictionary = root.get_node("GameState").banner_context(hub._upcoming_match())
			var want := str(load("res://scripts/core/Banners.gd").pick(ctx))
			_check(vig.banner != "" and vig.banner == (want if want != "" else db.club_name("COL")) 					and str(vig.title).contains(db.club_name("COL")),
					"The scene is your club's: this match's banner and this week's match (%s: %s)" % [str(vig.title), vig.banner])
		var seen := {}
		var frames_before_run := 0
		var frames := 0
		while frames < 900 and (router.current() != "match" or root.find_child("PreMatch", true, false) != null):
			if is_instance_valid(vig):
				if skip and frames == 5:
					var tap := InputEventMouseButton.new()
					tap.button_index = MOUSE_BUTTON_LEFT
					tap.pressed = true
					vig._gui_input(tap)
				seen[str(vig.phase())] = true
				if str(vig.phase()) != "run":
					frames_before_run += 1
			await process_frame
			frames += 1
		if skip:
			_check(frames_before_run <= 8, "A tap sends them through the banner at once (%d frames)" % frames_before_run)
		else:
			_check(seen.has("warm") and seen.has("huddle") and seen.has("run"),
					"Warm-up, final instructions, then through the banner (%s)" % str(seen.keys()))
			_check(frames_before_run >= 100 and frames_before_run <= 240,
					"A couple of seconds of match day, not a wait (%d frames at 60)" % frames_before_run)
		_check(router.current() == "match" and root.find_child("PreMatch", true, false) == null,
				"Then the match, and the scene is gone")
		if get_current_scene() != null:
			get_current_scene().queue_free()
		if is_instance_valid(hub):
			hub.queue_free()
		await process_frame


## The words a line shows, whether a Label or a tinted RichTextLabel carries them.
func _plain(c: Control) -> String:
	if c.has_meta("plain"):
		return str(c.get_meta("plain"))
	if c is Label:
		return (c as Label).text
	return (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else ""


## Each gate's lines name the constant they describe, worked out the way the
## sim uses it, and no template carries a digit of its own.
func _gate_odds() -> void:
	var GO = load("res://scripts/sim/GateOdds.gd")
	var Ms = load("res://scripts/sim/MatchSim.gd")
	var RT = load("res://scripts/sim/Ratings.gd")
	var MU = load("res://scripts/sim/Matchups.gd")
	var digits := RegEx.create_from_string("[0-9]")
	var templates := [GO.GAIN, GO.COST, GO.TAG_GIVES, GO.TAG_TOUCHES, GO.TAG_BREAK_GAIN, GO.TAG_BENCH_COST, GO.TAG_NOBODY_GAIN, GO.TAG_NONE_GAIN, GO.TAG_NONE_COST_ANY, GO.TAG_HOT_GAIN, GO.TAG_HOT_COST, GO.TAG_LEAVE_GAIN, GO.TAG_LEAVE_COST, GO.TAG_MOVE_COST, GO.TAG_STAY_GAIN, GO.SKIP_FIRST, GO.SKIP_LATER,
			GO.FOR_MINUTES, GO.TO_SIREN, GO.TO_BREAK, GO.NONE_GAIN, GO.NONE_COST_RUN, GO.NONE_COST_BOUNCE]
	for d in [GO.BURST_GAIN, GO.BURST_COST]:
		templates.append_array((d as Dictionary).values())
	var literal := templates.filter(func(t): return digits.search(str(t)) != null)
	_check(literal.is_empty(), "No match-day gate template carries a number of its own (%s)" % str(literal))
	var pct := func(x: float) -> String: return GO.pct(x)
	_check(GO.tag_gives().contains(pct.call(Ms.TAGGER_COST)) and GO.tag_gives().contains(pct.call(1.0 - Ms.TAGGER_BALL))
			and str(GO.tag_break_texts("B", "A", 20)[1]).contains(GO.tag_gives())
			and str(GO.tag_break_texts("", "A", 20)[0]).contains(GO.tag_gives())
			and str(GO.tag_break_texts("", "A", 20, "", "C")[1]).contains("C gets his usual %d touches" % GO.usual_touches())
			and str(GO.tag_break_texts("B", "", 0)[0]).begins_with("none"),
			"Tag: the share of his own game given up, from the tagger's constants (%s)" % GO.tag_gives())
	_check(GO.skip_line(1).contains("plan you took in") and GO.skip_line(3).contains("last quarter's calls")
			and GO.skip_line(3).contains("no change") and GO.skip_line(1).contains("Nothing changed here is kept"),
			"Skip says what it plays with and that the sheet's other changes are not kept")
	var mins := func(k: String) -> String: return str(roundi(float(Ms.BURSTS[k]["chains"]) * float(Ms.GAME_MINUTES) / float(RT.T["chains_per_game"])))
	var surge: Array = GO.burst_lines("surge", 60)
	_check(str(surge[0]).contains(pct.call(Ms.SURGE_CONTEST)) and str(surge[0]).contains(pct.call(Ms.SURGE_GOAL - 1.0)) and str(surge[0]).contains(mins.call("surge") + " minutes")
			and str(surge[1]).contains(pct.call(Ms.SURGE_OPP_GOAL - 1.0)) and str(surge[1]).contains(pct.call(Ms.SURGE_PACE - 1.0)),
			"Throw numbers: up, down and how long, from its constants (%s / %s)" % surge)
	var hold: Array = GO.burst_lines("hold", 60)
	_check(str(hold[0]).contains(pct.call(1.0 - Ms.HOLD_CLANGERS)) and str(hold[0]).contains(pct.call(1.0 - Ms.HOLD_OPP_GOAL))
			and str(hold[1]).contains(pct.call(1.0 - Ms.HOLD_GOAL)) and str(hold[1]).contains(pct.call(1.0 - Ms.BACK_GAIN)),
			"Slow it down: up and down from its constants (%s / %s)" % hold)
	var stack: Array = GO.burst_lines("stack", 15)
	_check(str(stack[0]).contains(pct.call(Ms.STACK_CONTEST)) and str(stack[0]).contains(pct.call(float(RT.T["contest_clamp"])))
			and str(stack[1]).contains(pct.call(Ms.STACK_OPP_GOAL - 1.0)), "Stack the stoppage: the edge, its cap and its cost (%s / %s)" % stack)
	_check(str(GO.burst_lines("flood", 20, false)[0]).ends_with(GO.TO_BREAK), "Before the last quarter a call that outlasts it runs to the break")
	var flood: Array = GO.burst_lines("flood", 15)
	_check(str(flood[0]).contains(pct.call(1.0 - Ms.FLOOD_OPP_GOAL)) and str(flood[0]).ends_with(GO.TO_SIREN)
			and str(flood[1]).contains(pct.call(1.0 - Ms.FLOOD_GOAL)), "Flood: to the siren, both sides from its constants (%s / %s)" % flood)
	var push: Array = GO.burst_lines("push", 15)
	_check(str(push[0]).contains(pct.call(Ms.PUSH_GOAL - 1.0)) and str(push[0]).contains(pct.call(Ms.PUSH_GAIN - 1.0)) and str(push[0]).ends_with(GO.TO_SIREN)
			and str(push[1]).contains(pct.call(Ms.PUSH_OPP_GOAL - 1.0)), "Push numbers forward: to the siren, both sides from its constants (%s / %s)" % push)
	var fwd := {"id": "f", "role": "FWD", "height_cm": 196, "attr": {"marking": 80}}
	var back := {"id": "d", "role": "DEF", "height_cm": 192, "attr": {"intercept": 74, "marking": 68}}
	var edge: float = MU.AERIAL_EDGE if load("res://scripts/sim/Traits.gd").has(fwd, "aerial") else 0.0
	var want := clampf(MU.MARK_BASE + edge + (MU.forward_air(fwd) - MU.defender_air(back) - MU.DUEL_CENTRE) / MU.DUEL_SCALE,
			MU.MARK_FLOOR, MU.DUEL_CAP)
	_check(is_equal_approx(MU.mark_chance(fwd, back), want),
			"The mark chance is the duel rule's (%.3f)" % want)
