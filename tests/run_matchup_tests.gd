extends SceneTree
## godot --headless --path . --script tests/run_matchup_tests.gd
## Opponent facts (tests/test_matchup.gd), then the weekly hub on a phone:
## this week first, at most three facts, an obvious next action, the ladder at
## full height, and sensible states for a bye, a finished season and results.

const Tap := preload("res://tests/tap.gd")
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
	await _wide_hub_footer()
	await _regular_bye()
	await _finals_week_by_week()
	await _coach_approach_card()
	await _season_wrap()
	await _season_review_scrolls()
	await _pre_match_scene()
	_pre_match_captions()
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
	var venue: Label = hub.find_child("MatchVenue", true, false)
	# "at Adelaide" is the defect; "Adelaide Oval" is a ground (the Crows' own),
	# so the check looks for the word, not the club's name anywhere.
	_check(venue != null and venue.text.begins_with("Home · " if str(nxt["venue"]) == "home" else "Away · ")
			and not venue.text.contains("at " + db.club_name(str(nxt["code"]))),
			"Then where: home or away and the ground, not 'at' the opponent (%s)" % (venue.text if venue else "-"))
	var facts := hub.find_children("Fact_*", "Label", true, false)
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
	var note: Label = hub.find_child("OwnNote_0", true, false)
	_check(note != null and note.text.contains("out injured"), "Your injured star is this week's news")
	best.erase("injury_weeks")
	hub.queue_free()
	await _settle()

	# Run the season out: no fixture, no facts, a clear next step every week.
	# One check per rule however many finals weeks you play: the season is
	# not seeded, so a per-week check count would move with it.
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
			if not up and not hub.find_children("Fact_*", "Label", true, false).is_empty():
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
	_check(hub.find_children("Fact_*", "Label", true, false).is_empty(), "No facts once the season is over")
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
	_state.reset()
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
	_state.reset()
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
		_state.reset()
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
	_state.reset()
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
	_state.reset()
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
	_state.reset()
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
func _pre_match_captions() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
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
		_state.reset()
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
