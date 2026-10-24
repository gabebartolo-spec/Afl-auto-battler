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
	await _t("_test_hub_tests")
	await _t("_test_poster_ball")
	await _t("_test_fact_options")
	_t("_test_former_rules")
	await _t("_test_former_player")
	await _t("_test_wide_hub_footer")
	await _t("_test_phone_footer_fits")
	await _t("_test_regular_bye")
	await _t("_test_finals_week_by_week")
	await _t("_test_finals_cup")
	await _t("_test_finals_status_paths")
	await _t("_test_coach_approach_card")
	await _t("_test_season_wrap")
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
	# does not hang on how the season falls.
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
	_check(_button(hub.find_child("WeekActions", true, false), "National Draft") != null,
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
	for vacancies in [0, 1]:
		for w in [320, 360, 390, 412]:
			_reset()
			_state.start_season("MEL", db.club_list("MEL"))
			_state.set_setting("seen_weekly_loop_intro", true)
			if vacancies > 0:
				_state.staff_vacancies = [{"reason": "A coach has retired."}]
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
	_check(text.contains("Bye") and not text.contains("Season over for you")
			and not text.contains("missed the top"), "A mid-season bye is not the end of the season")
	var actions: Node = hub.find_child("WeekActions", true, false)
	_check(actions != null and actions.find_child("SimToGrandFinal", true, false) == null
			and actions.find_child("SimFinalsWeek", true, false) == null,
			"No finals controls before the home-and-away season is done")
	_check(hub.find_child("FinalsOpen", true, false) == null, "No finals series button before September")
	var sim: Button = actions.find_child("SimByeRound", true, false) if actions != null else null
	_check(sim != null and sim.text == "Play Round %d" % (r0 + 1), "The bye round can be simmed on its own")
	hub.call("_on_sim_to_end")
	_check(season.round_index == r0, "Sim to Grand Final never runs through home-and-away rounds")
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
## only after the Grand Final. Sim to Grand Final stays as the fast-forward.
func _test_finals_week_by_week() -> void:
	var db = root.get_node("GameDB")
	var out := ""
	for code in ["GWS", "RIC", "NTH", "WCE", "STK", "ESS", "ADE"]:
		if not db.active_clubs(2027).has(code):
			continue
		_reset()
		_state.start_season(code, db.club_list(code))
		_state.season.round_index = _state.season.fixture.size() - 1
		_state.advance()
		if not (_state.season.finals["top"] as Array).has(code):
			out = code
			break
	_check(out != "", "A club misses the finals to test with")
	if out == "":
		return
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
		var skip: Button = actions.find_child("SimToGrandFinal", true, false) if actions != null else null
		if week == null or skip == null:
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
			clear = clear and not (c as Control).get_global_rect().grow(7.5).intersects(ball.get_global_rect())
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
		_check(ink.contains("[color=#%s]" % kit.club_name_colour(kit.club_ink(opp)).to_html(false)) and not ink.contains(kit.club_ink("FRE").to_html(false)),
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


## Every opposition fact comes with your options beside it (P-13, director
## 2026-10-14, A9). Each fact the hub states has a row of the responses the rules
## allow, in a fixed order, none marked best; the unsuitable ones are disabled
## and say why; a real tap on one starts the match on that call's picker, with the
## fact restated above it, and the pick lands as it does from the break.
func _test_fact_options() -> void:
	var db = root.get_node("GameDB")
	var FO = load("res://scripts/sim/FactOptions.gd")
	_reset()
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.start_season("FRE", db.club_list("FRE"))
	# The table, for every club as the opponent: the options of each fact are
	# exactly the table's for its kind, in the table's order, each disabled one
	# with a reason and each enabled one with a cost.
	var kinds := {}
	var table_ok := true
	var reasons_ok := true
	var order_ok := true
	var words_ok := true
	var words := ["best", "recommend", "suggest", "ideal", "should", "advice", "optimal", "top pick"]
	var disabled_seen := 0
	var shown_ok := true
	var ruck_clean := true
	var ruck_facts := 0
	var enabled_seen := 0
	for code in _state.season.lists:
		var facts: Array = _state.opponent_facts(str(code))
		var opts: Array = _state.opponent_fact_options(str(code), facts, true)
		var shown: Array = _state.opponent_fact_options(str(code), facts)
		for i in range(mini(facts.size(), shown.size())):
			for o in shown[i]:
				shown_ok = shown_ok and bool(o["enabled"])
				if str(facts[i]["key"]) == "ruck":
					ruck_clean = ruck_clean and str(o["call"]) == "ruck"
					ruck_facts += 1
		table_ok = table_ok and opts.size() == facts.size()
		for i in range(mini(facts.size(), opts.size())):
			var key := str(facts[i]["key"])
			kinds[key] = true
			var want := []
			for row in FO.TABLE[key]:
				want.append("plan:" + str(row[1]) if str(row[0]) == "plan" else str(row[0]))
			var got := []
			var last := -1
			for o in opts[i]:
				got.append("plan:" + str(o["plan"]) if str(o["call"]) == "plan" else str(o["call"]))
				var at: int = FO.ORDER.find(str(o["call"]))
				order_ok = order_ok and at >= last
				last = at
				if bool(o["enabled"]):
					enabled_seen += 1
					words_ok = words_ok and str(o["cost"]) != "" and str(o["reason"]) == ""
				else:
					disabled_seen += 1
					reasons_ok = reasons_ok and str(o["reason"]).length() > 8 and str(o["cost"]) == ""
				for w in words:
					words_ok = words_ok and not (str(o["label"]) + " " + str(o["cost"]) + " " + str(o["reason"])).to_lower().contains(w)
			got.sort()
			want.sort()
			if got != want:
				table_ok = false
				push_error("%s %s: options %s, table %s" % [code, key, str(got), str(want)])
	_check(table_ok, "Every fact of every opponent has exactly the table's responses for its kind")
	_check(shown_ok, "The hub shows only responses the coach can take (no greyed ones)")
	_check(ruck_clean, "No ruck fact carries Tag, Key match-up or a plan across all clubs (%d ruck facts)" % ruck_facts)
	var two_r := {"id": "r1", "role": "RUCK", "overall": 80, "attr": {}}
	var one_r := {"id": "r2", "role": "RUCK", "overall": 80, "attr": {}}
	var mid_r := {"id": "m", "role": "MID", "overall": 70, "attr": {}}
	_check(FO.takeable(FO.options({"key": "ruck", "player_id": "r1"}, [two_r], [mid_r, one_r], [two_r])).is_empty(),
			"With one ruck of his own the ruck fact shows nothing")
	_check(_names(FO.takeable(FO.options({"key": "ruck", "player_id": "r1"}, [two_r], [one_r, one_r.duplicate()], [two_r]))) == ["ruck"],
			"With two rucks the ruck fact offers the Main ruck call and nothing else")
	_check(_names(FO.takeable(FO.options({"key": "danger", "player_id": "r1"}, [two_r], [one_r, one_r.duplicate()], [two_r]))) == ["ruck"],
			"A danger man who is a ruck is answered by the Main ruck call alone, never a tag")
	_check(order_ok, "The responses always come in the fixed order: tag, key match-up, defensive forward, main ruck, loose interceptor, plan")
	_check(reasons_ok and disabled_seen > 0, "Every unsuitable response is disabled with its reason (%d seen)" % disabled_seen)
	_check(words_ok and enabled_seen > 0, "Every other one carries its cost, and none says best, recommended or should (%d seen)" % enabled_seen)
	_check(kinds.has("danger") and kinds.has("interceptor") and (kinds.has("midfield") or kinds.has("ruck")),
			"The league covers the danger man, the roaming defender and a line (%s)" % ", ".join(kinds.keys()))
	# Every match-day gate's gain and cost carry the sim's own constants
	# (bible §4, director 2026-10-18); the templates hold no figure.
	_gate_odds()
	# A forward who is only a forward cannot be tagged: the response says why.
	var fwd := {"id": "x", "role": "FWD", "overall": 80, "attr": {}}
	var tagged: Array = FO.options({"key": "danger", "player_id": "x"}, [], [], [fwd])
	_check(not tagged.is_empty() and str(tagged[0]["call"]) == "tag" and not bool(tagged[0]["enabled"])
			and str(tagged[0]["reason"]) == "He plays forward: a tag needs a midfielder.",
			"A forward cannot be tagged and the response says why (%s)" % (str(tagged[0]["reason"]) if not tagged.is_empty() else "-"))
	var mid_fwd := {"id": "y", "role": "FWD", "role2": "MID", "overall": 80, "attr": {}}
	var rank: Array = FO.options({"key": "danger", "player_id": "y"}, [], [], [mid_fwd])
	_check(not rank.is_empty() and bool(rank[0]["enabled"]), "A mid/forward can be tagged, as the director asked (A9)")
	var ruck_mid := {"id": "z", "role": "RUCK", "role2": "MID", "overall": 85, "attr": {}}
	var rm: Array = FO.options({"key": "danger", "player_id": "z"}, [ruck_mid], [], [ruck_mid])
	_check(not rm.is_empty() and str(rm[0]["call"]) == "tag" and not bool(rm[0]["enabled"]),
			"A ruckman is never offered a tag, even one who also lists midfield (lead ruling, 2026-10-18)")

	# No one tags ruckmen (director, 2026-10-18): across every club's list, a
	# ruck-first player is never a tag target, whatever else he lists.
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

	# The hub, phone and PC: the rows are under their facts, thumb-sized, whole.
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		var hub := await _open_hub()
		var nxt: Dictionary = _state.my_next_opponent()
		var facts: Array = _state.opponent_facts(str(nxt["code"]))
		var opts: Array = _state.opponent_fact_options(str(nxt["code"]), facts)
		var rows_ok := true
		var rows_n := 0
		var fits := true
		var all_text := ""
		for i in range(facts.size()):
			var row: Control = hub.find_child("FactOptions_%d" % i, true, false)
			var want_n: int = (opts[i] as Array).size()
			if want_n == 0:
				rows_ok = rows_ok and row == null
				continue
			rows_n += 1
			rows_ok = rows_ok and row != null and row.get_child_count() == want_n
			if row == null:
				continue
			var fact_label: Control = hub.find_child("Fact_%d" % i, true, false)
			rows_ok = rows_ok and fact_label != null and row.get_index() == fact_label.get_index() + 1
			for b in row.find_children("FactOption_*", "Button", true, false):
				fits = fits and (b as Button).size.y >= (44.0 if sz.x < 600 else 36.0) and b.get_global_rect().size.x > 0.0
				var o: Dictionary = b.get_meta("option")
				var sub := b.get_parent().find_child("OptionSub", true, false) as Label
				rows_ok = rows_ok and b.disabled == (not bool(o["enabled"])) \
						and sub != null and sub.text == (str(o["cost"]) if bool(o["enabled"]) else str(o["reason"]))
				var up := b.get_parent().find_child("OptionGain", true, false) as Label
				rows_ok = rows_ok and (not bool(o["enabled"]) or (up != null and up.text == str(o["gain"])
						and up.text.begins_with("Gain: ") and sub.text.begins_with("Cost: ")))
				all_text += " " + sub.text + " " + (b.get_parent().find_child("OptionName", true, false) as Label).text
		_check(rows_n > 0 and rows_ok, "%s: each stated fact has its options row beside it, with a cost or a reason on every one (%d rows)" % [tag, rows_n])
		_check(fits, "%s: every option is a thumb tall and on the screen" % tag)
		var lowered := all_text.to_lower()
		var clean := true
		for w in words:
			clean = clean and not lowered.contains(w)
		_check(clean, "%s: no option says best, recommended or should" % tag)
		hub.queue_free()
		await _settle()

	# A real tap on an option: the match opens on that call's picker with the
	# one fact above it, and a pick made there is the call the quarter plays.
	_state.set_vignettes_on(false)
	# Fremantle meet a side with plan responses; Brisbane meet one whose danger man can be tagged.
	for case in [["FRE", "plan"], ["BRL", "tag"]]:
		var want_call: String = case[1]
		_reset()
		_state.set_setting("seen_weekly_loop_intro", true)
		_state.start_season(str(case[0]), db.club_list(str(case[0])))
		root.size = Vector2i(390, 844)
		var hub2 := await _open_hub()
		var nxt2: Dictionary = _state.my_next_opponent()
		var facts2: Array = _state.opponent_facts(str(nxt2["code"]))
		var opts2: Array = _state.opponent_fact_options(str(nxt2["code"]), facts2)
		var chosen: Button = null
		var fact_text := ""
		var option: Dictionary = {}
		for i in range(opts2.size()):
			for o in opts2[i]:
				if chosen == null and bool(o["enabled"]) and str(o["call"]) == want_call:
					var key: String = str(o["plan"]) if want_call == "plan" else want_call
					chosen = hub2.find_child("FactOption_%d_%s" % [i, key], true, false)
					fact_text = str(facts2[i]["text"])
					option = o
		if chosen == null:
			_check(false, "%s meet a fact with a %s response to tap" % [str(case[0]), want_call])
			hub2.queue_free()
			await _settle()
			continue
		var why: String = await Tap.tap(chosen)
		await _settle()
		await _settle()
		var scene: Node = current_scene
		var box: Node = scene.find_child("CoachBox", true, false) if scene != null else null
		_check(why == "" and scene != null and scene.name == "MatchScene" and box != null,
				"A real tap on the %s response opens the match on its calls (%s)" % [want_call, why])
		var restated: Node = box.find_child("CallIntentFact", true, false) if box != null else null
		var picker_name: String = {"plan": "PlanPicker", "tag": "TagPicker"}[want_call]
		var picker: Node = box.find_child(picker_name, true, false) if box != null else null
		var plain := ""
		if restated != null and restated.has_meta("plain"):
			plain = str(restated.get_meta("plain"))
		elif restated is Label:
			plain = (restated as Label).text
		_check(restated != null and plain == fact_text and picker != null and restated.get_parent() == picker.get_parent()
				and restated.get_index() < picker.get_index(),
				"The %s picker opens with the one fact above it (%s)" % [want_call, plain])
		_check(_state.call_intent.is_empty(), "The tap's intent is used once and not kept")
		if want_call == "tag" and picker != null:
			# The same TagPicker main builds (its question, its candidates): no ruck on offer.
			var opp_code: String = str(_state.my_next_opponent()["code"])
			var rucks := 0
			for tb in picker.find_children("TagPickerGrid_*", "Button", true, false):
				var tid: String = str(tb.name).trim_prefix("TagPickerGrid_")
				for lp in _state.season.lists[opp_code]:
					if str(lp.get("id", "")) == tid and str(load("res://scripts/sim/Ratings.gd").positions(lp)[0]) == "RUCK":
						rucks += 1
			var asks := false
			var ask_text: String = load("res://scripts/ui/match/MatchNotes.gd").tag_question()
			for lab in picker.get_parent().find_children("*", "Label", true, false):
				if (lab as Label).text == ask_text:
					asks = true
			_check(rucks == 0 and asks, "The opened tag picker is main's own: its question, and no ruck among the names (%d)" % rucks)
		# Saves are unchanged: an intent held at save time never reaches the file.
		_state.call_intent = {"call": "tag", "plan": "", "player_id": "x", "fact": "A fact."}
		var wrote: bool = _state.save_career()
		var back: Dictionary = CareerSave.read(_state.save_path)
		_check(wrote and not back.is_empty() and not str(back).contains("call_intent") and not str(back).contains("A fact."),
				"A held intent is not written into the save")
		_state.call_intent = {}
		_check(box != null and box.find_children("CallIntentFact", "", true, false).size() == 1,
				"Only that one fact is added to the pane")
		# The pick, from the same picker, a real tap; then the quarter.
		var pick: Button = null
		var pick_id := ""
		if want_call == "plan":
			pick = box.find_child("PlanPicker_" + str(option["plan"]), true, false) if box != null else null
		elif picker != null:
			for b in picker.find_children("TagPickerGrid_*", "Button", true, false):
				if not str(b.name).ends_with("_"):
					pick = b
					pick_id = str(b.name).trim_prefix("TagPickerGrid_")
					break
		var why2: String = await Tap.tap(pick) if pick != null else "no pick"
		_check(why2 == "", "A real tap picks from the opened %s picker (%s)" % [want_call, why2])
		var start: Button = box.find_child("StartQuarter", true, false) if box != null else null
		var sim = _state.pending_sim
		var side: int = sim.moment_side if sim != null else 0
		if start != null:
			start.emit_signal("pressed")
			await _settle()
		var played := {}
		if sim != null and not sim.tactics_history.is_empty():
			played = (sim.tactics_history[0]["plans"][side] as Dictionary)
		if want_call == "plan":
			_check(str(played.get("gameplan", "")) == str(option["plan"]), "The plan picked there is the one the first quarter plays (%s)" % str(played.get("gameplan", "")))
		elif pick_id != "":
			_check(str(played.get("tag_id", "")) == pick_id, "The tag picked there is the one the first quarter plays (%s)" % str(played.get("tag_id", "")))
		if current_scene != null:
			current_scene.queue_free()
		if is_instance_valid(hub2):
			hub2.queue_free()
		await _settle()
	_state.set_vignettes_on(true)
	root.size = Vector2i(390, 844)


func _reset() -> void:
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.replay_seed = SUITE_SEED


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
		root.size = Vector2i(390, 844)
		var hub: Control = await _open_hub()
		var play := _button(hub.find_child("WeekActions", true, false), "Play match")
		play.emit_signal("pressed")
		var vig = root.find_child("PreMatchVignette", true, false)
		_check(vig != null, "Play match cuts to the pre-match scene in the same frame")
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


func _names(opts: Array) -> Array:
	var r := []
	for o in opts:
		r.append(str(o["call"]))
	return r


## Each gate's lines name the constant they describe, worked out the way the
## sim uses it, and no template carries a digit of its own.
func _gate_odds() -> void:
	var GO = load("res://scripts/sim/GateOdds.gd")
	var Ms = load("res://scripts/sim/MatchSim.gd")
	var RL = load("res://scripts/sim/Roles.gd")
	var RT = load("res://scripts/sim/Ratings.gd")
	var MU = load("res://scripts/sim/Matchups.gd")
	var digits := RegEx.create_from_string("[0-9]")
	var templates := [GO.GAIN, GO.COST, GO.TAG_GAIN, GO.TAG_COST, GO.MATCHUP_GAIN, GO.MATCHUP_COST_NEXT,
			GO.MATCHUP_COST_LOOSE, GO.MINDER_GAIN, GO.MINDER_COST, GO.RUCK_GAIN, GO.RUCK_COST, GO.LOOSE_GAIN,
			GO.LOOSE_COST, GO.TAG_GIVES, GO.TAG_NOTE, GO.SKIP_FIRST, GO.SKIP_LATER, GO.BACK_STATS, GO.BACK_CM,
			GO.DUEL_GAIN, GO.DUEL_COST_SWAP, GO.DUEL_COST_LOOSE, GO.DUEL_COST_FREE, GO.DUEL_COST_KEEP,
			GO.FOR_MINUTES, GO.TO_SIREN, GO.TO_BREAK, GO.NONE_GAIN, GO.NONE_COST_RUN, GO.NONE_COST_BOUNCE]
	for d in [GO.PLAN_GAIN, GO.PLAN_COST, GO.BURST_GAIN, GO.BURST_COST]:
		templates.append_array((d as Dictionary).values())
	var literal := templates.filter(func(t): return digits.search(str(t)) != null)
	_check(literal.is_empty(), "No match-day gate template carries a number of its own (%s)" % str(literal))
	var pct := func(x: float) -> String: return GO.pct(x)
	var tag: Array = GO.tag_lines()
	_check(str(tag[0]).contains(pct.call(RL.TAG_WITH_TAGGER)) and str(tag[0]).contains(pct.call(RL.TAG_PLAIN))
			and str(tag[1]).contains(pct.call(Ms.TAGGER_COST)) and GO.tag_gives().contains(pct.call(1.0 - Ms.TAGGER_BALL)),
			"Tag: the hold a Tagger and anyone else leave, and the share of his own game given up (%s / %s)" % tag)
	var md: Array = GO.minder_lines()
	_check(str(md[0]).contains(pct.call(float(Ms.MINDER_ROAM["other"]))) and str(md[0]).contains(pct.call(float(Ms.MINDER_ROAM["specialist"])))
			and str(md[1]).contains(pct.call(1.0 - Ms.MINDER_INVOLVE)), "Defensive forward: his reach both ways and your forward's cost (%s / %s)" % md)
	var rk: Array = GO.ruck_lines()
	_check(str(rk[1]).contains(pct.call(float(Ms.ROLE_DRAIN["RUCK"]) / float(Ms.ROLE_DRAIN["FWD"]) - 1.0)), "Main ruck: how much faster he tires (%s)" % rk[1])
	var att: Array = GO.plan_lines("attacking")
	_check(str(att[0]).contains(pct.call(float(Ms.PLANS["attacking"]["goal"]) - 1.0)) and str(att[1]).contains(pct.call(float(Ms.PLANS["attacking"]["clangers"]) - 1.0))
			and str(att[1]).contains(pct.call(float(Ms.PLANS["attacking"]["exposed"]) - 1.0)), "Attack corridor: both sides from PLANS (%s / %s)" % att)
	var ctl: Array = GO.plan_lines("controlled")
	_check(str(ctl[0]).contains(pct.call(1.0 - float(Ms.PLANS["controlled"]["clangers"]))) and str(ctl[1]).contains(pct.call(1.0 - float(Ms.PLANS["controlled"]["gain"]))),
			"Controlled tempo: both sides from PLANS (%s / %s)" % ctl)
	var dfn: Array = GO.plan_lines("defensive")
	_check(str(dfn[0]).contains(pct.call(float(Ms.PRESS_PLAN_ZONE[0]) - 1.0)) and str(dfn[1]).contains(pct.call(1.0 - float(Ms.PLANS["defensive"]["goal"]))),
			"Defensive press: both sides from PLANS and the press zones (%s / %s)" % dfn)
	_check(str(GO.plan_lines("contest")[0]).contains(pct.call(float(Ms.PLANS["contest"]["contest"]))), "Win contest: its stoppage edge")
	_check(GO.skip_line(1).contains("plan you took in") and GO.skip_line(3).contains("last quarter's calls")
			and GO.skip_line(3).contains("no change") and GO.skip_line(1).contains("Only a match-up changed here is kept"),
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
	var fwd := {"id": "f", "role": "FWD", "height_cm": 196, "attr": {"marking": 80}}
	var back := {"id": "d", "role": "DEF", "height_cm": 192, "attr": {"intercept": 74, "marking": 68}}
	var edge: float = MU.AERIAL_EDGE if load("res://scripts/sim/Traits.gd").has(fwd, "aerial") else 0.0
	var want := clampf(MU.MARK_BASE + edge + (MU.forward_air(fwd) - MU.defender_air(back) - MU.DUEL_CENTRE) / MU.DUEL_SCALE,
			MU.MARK_FLOOR, MU.DUEL_CAP)
	_check(is_equal_approx(MU.mark_chance(fwd, back), want) and GO.back_stats(back) == "Intercept 74 · Marking 68 · 192 cm",
			"A back's card: Intercept, Marking and height, and the mark chance the duel rule gives (%.3f, %s)" % [want, GO.back_stats(back)])
