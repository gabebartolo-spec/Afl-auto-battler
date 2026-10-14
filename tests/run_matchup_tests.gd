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
	await _hub_tests()
	await _poster_ball()
	await _wide_hub_footer()
	await _regular_bye()
	await _finals_week_by_week()
	await _finals_cup()
	await _finals_status_paths()
	await _coach_approach_card()
	await _season_wrap()
	await _season_review_scrolls()
	await _pre_match_scene()
	_pre_match_captions()
	_banner_scene_budget()
	_state.replay_seed = 0
	print("Matchup + hub tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _hub_tests() -> void:
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
		if not (str(t).begins_with("They ") or str(t).begins_with("Their ")) or RegEx.create_from_string("\\d").search(str(t)) != null:
			style_ok = false
	_check(style_ok, "Their style reads as football, no numbers (%s)" % " ".join(style))
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
	var mine: Label = hub.find_child("FormLine", true, false)
	var rx := RegEx.new()
	rx.compile("[+-]\\d")
	_check(mine != null and rx.search(mine.text) == null, "Your form hides the internal number")
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
func _wide_hub_footer() -> void:
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


func _regular_bye() -> void:
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
func _finals_week_by_week() -> void:
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
func _coach_approach_card() -> void:
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
func _season_review_scrolls() -> void:
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
func _season_wrap() -> void:
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
func _poster_ball() -> void:
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


func _reset() -> void:
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.replay_seed = SUITE_SEED


## The status line over the bracket on every path a side can take through the finals: a
## qualifying final's loser is still alive (the double chance), every other loser's season
## has ended, the premiers say so (found by uiart: "Your season ended in the Qualifying
## Final 2" over a side in the Grand Final).
func _finals_status_paths() -> void:
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
		_check(text.contains(str(c[3])), "Finals status, %s: reads %s (%s)" % [c[0], c[3], text])
		if str(c[3]) == "Still alive":
			_check(not text.contains("ended"), "Finals status, %s: never says the season ended" % c[0])
		host.queue_free()
		sea.finals = saved
		await _settle()


## The cup on the finals series (director, 2026-10-14): the real cup art over
## the Grand Final before it is played, phone and PC, and big in the
## premier's colour once it is won. Every match is still there to tap.
func _finals_cup() -> void:
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
func _banner_scene_budget() -> void:
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


func _pre_match_captions() -> void:
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
func _pre_match_scene() -> void:
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
