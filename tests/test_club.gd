extends RefCounted
## The board, morale and the weekly event card. Run through
## tests/run_club_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_test_rules()
	_test_season_flow()
	_test_events()
	_test_backing_rules()
	_test_backing_flow()
	_test_backing_card_guard()
	_test_backing_lasts_the_season()
	_test_firsts_rules()
	_test_firsts_flow()
	_test_firsts_goals()
	_test_first_goal_candidates()
	_test_sacking()
	_test_team_form()
	_test_board_confidence()
	_test_coaching_hub()
	_test_how_we_play_reads()
	_test_how_we_play_quiet()
	_test_how_we_play_unlocks_on_the_third_game()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Club tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_rules() -> void:
	_check(str(ClubLife.board_goal(2, 3)["key"]) == "top4" and str(ClubLife.board_goal(17)["key"]) == "wins7",
			"The board expects more from a stronger list")
	# Bands match what a list of that rank reaches most years; only a top list
	# that finished top four last year is asked to do it again.
	var keys := []
	for r in [1, 2, 3, 7, 8, 12, 13, 18]:
		keys.append(str(ClubLife.board_goal(r)["key"]))
	_check(keys == ["finals", "finals", "finals", "finals", "top12", "top12", "wins7", "wins7"],
			"Board goals follow the list's rank (%s)" % str(keys))
	_check(str(ClubLife.board_goal(1, 4)["key"]) == "top4" and str(ClubLife.board_goal(1, 5)["key"]) == "finals"
			and str(ClubLife.board_goal(3, 1)["key"]) == "finals" and str(ClubLife.board_goal(1, 0)["key"]) == "finals",
			"Top four is asked only of a top list that was top four last year")
	_check(ClubLife.goal_met({"pos": 8}, 6, 12) and not ClubLife.goal_met({"pos": 8}, 10, 12)
			and ClubLife.goal_met({"wins": 7}, 15, 7), "Goals are judged on position or wins")
	_check(int(ClubLife.after_match(60, 45)["confidence"]) == 63 and int(ClubLife.after_match(60, -10)["confidence"]) == 58,
			"Wins lift the board, losses cost it, a thrashing counts one more")
	var star := {"id": "s", "overall": 85, "morale": 70}
	var kid := {"id": "k", "overall": 60, "morale": 70}
	ClubLife.morale_after_match([star, kid], {"k": true}, true)
	_check(int(star["morale"]) == 64 and int(kid["morale"]) == 74,
			"Playing and winning lifts morale; a star left out sulks")
	star["morale"] = 30
	var unhappy_price := Contracts.asking_salary(star)
	star["morale"] = 70
	_check(unhappy_price > Contracts.asking_salary(star), "An unhappy player asks more to re-sign")
	_check(ClubLife.form({"morale": 100}) > 0.0 and ClubLife.form({"morale": 20}) < 0.0,
			"Morale nudges match form")
	# The profile says so wherever it matters, in the same direction as the engine.
	for m in [20, 50, 70, 90, 100]:
		var said := ClubLife.mood_effect(m)
		var f := ClubLife.form({"morale": m})
		_check((said == "") == (absf(f) < 0.015) and (said.contains("lifting") == (f > 0.0) or said == ""),
				"The profile's word on morale %d matches its match effect (%s)" % [m, said])


func _test_season_flow() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.board_goal_text() != "" and GameState.board_confidence() == ClubLife.START_CONFIDENCE,
			"A season starts with a board goal")
	# Settle this week's decision card first: some defaults move the board
	# (backing a player in the papers costs -4), and the season seed comes from
	# the clock, so which card appears varies run to run. Measure the match alone.
	GameState._settle_week_event()
	var before := GameState.board_confidence()
	var rival_before := {}
	for code in GameState.season.lists:
		if code != "GEE":
			for p in GameState.season.lists[code]:
				rival_before[str(p["id"])] = ClubLife.morale(p)
	GameState.advance()
	var res := GameState.last_match
	var side := 0 if str(res["home"]) == "GEE" else 1
	var margin := int(res["score"][side]) - int(res["score"][1 - side])
	var moved := GameState.board_confidence() - before
	_check((margin > 0 and moved > 0) or (margin < 0 and moved < 0) or margin == 0,
			"The board reacts to your result (%+d after a %+d game)" % [moved, margin])
	var changed := false
	for p in GameState.my_list:
		if ClubLife.morale(p) != ClubLife.MORALE_BASE:
			changed = true
	_check(changed, "Morale moves after a game")
	# Morale moves match form, so a rival's players take the week by the same
	# rule as yours: who played is lifted (more for a win), a fit player left
	# out loses some. Run for your club alone it was a free edge every week.
	var rival_ok := true
	var played_count := 0
	var left_out_count := 0
	for r in GameState.last_results:
		for s in range(2):
			var code := str(r["home"] if s == 0 else r["away"])
			if code == "GEE":
				continue
			var won := int(r["score"][s]) > int(r["score"][1 - s])
			var on := {}
			for row in (r["roster"] as Array)[s]:
				on[str(row["id"])] = true
			for p in GameState.season.lists[code]:
				var was := int(rival_before.get(str(p["id"]), ClubLife.MORALE_BASE))
				if on.has(str(p["id"])):
					rival_ok = rival_ok and ClubLife.morale(p) == clampi(was + (4 if won else 1), 5, 100)
					played_count += 1
				elif int(p.get("injury_weeks", 0)) <= 0 and was > 5:
					rival_ok = rival_ok and ClubLife.morale(p) < was
					left_out_count += 1
	_check(rival_ok and played_count > 100 and left_out_count > 0,
			"Rival players' morale moves by your club's rule (%d played, %d left out)" % [played_count, left_out_count])
	_check(GameState.club_goals.size() == GameState.season.ladder.size() and GameState.club_goals.has("GEE"),
			"Every club gets a board goal")
	var goals_before := str(GameState.club_goals)
	_check(GameState.save_career() and GameState.load_career()
			and GameState.board_goal_text() != "", "The board survives a save and load")
	_check(str(GameState.club_goals) == goals_before, "Every club's board goal survives a save and load")
	# Last year's finish feeds the board: the top list, top four last year, is asked again.
	var saved_goals: Dictionary = GameState.club_goals.duplicate(true)
	var saved_board: Dictionary = GameState.board.duplicate(true)
	var ranked := []
	for code in GameState.season.ladder:
		ranked.append([Squad.new(str(code), GameState.season.lists[code], true, str(code)).strength(), code])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	var best := str(ranked[0][1])
	GameState._last_finish = {best: 2}
	GameState._open_board_season()
	_check(str(GameState.club_goals[best]["key"]) == "top4", "The best list, top four last year, is asked for top four again")
	GameState._last_finish = {}
	GameState._open_board_season()
	_check(str(GameState.club_goals[best]["key"]) == "finals", "Without that history the best list is asked for finals")
	GameState.club_goals = saved_goals
	GameState.board = saved_board
	var season = GameState.season
	season.round_index = season.fixture.size()
	GameState.ensure_finals()
	while not season.is_season_over():
		GameState.advance()
	var hist: Array = GameState.board.get("history", [])
	_check(hist.size() == 1 and str(GameState.board.get("verdict", "")) != "",
			"The board gives its verdict at season's end")
	_check(GameState.week_event.is_empty(), "No event cards once the season is over")


func _test_events() -> void:
	var list := GameDB.club_list("GEE").duplicate(true)
	var seen := {}
	var quiet := 0
	for r in range(1, 60):
		var e := ClubLife.pick_event({"list": list, "round": r, "seed": 99, "losses": 3, "selected": {}})
		if e.is_empty():
			quiet += 1
			continue
		seen[str(e["key"])] = true
		var opts: Array = e["options"]
		if not (opts.size() >= 2 and int(e["default"]) < opts.size()):
			_check(false, "Event %s offers a real choice" % e["key"])
	_check(quiet > 5 and quiet < 35, "Some weeks are quiet (%d of 59)" % quiet)
	_check(seen.has("pressure") and seen.has("training"), "Losing streaks bring the board to your door")
	# Resolving: rest a sore star and he sits out.
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var star: Dictionary = GameState.my_list[0]
	GameState.week_event = ClubLife._sore_star(star)
	GameState.resolve_week_event(0)
	var side: Dictionary = GameState.current_side()
	var picked := false
	for k in side:
		if (side[k] as Array).has(str(star["id"])):
			picked = true
	_check(bool(star.get("rested", false)) and not picked, "Resting a sore star keeps him out of the side")
	GameState.advance()
	_check(not star.has("rested"), "He is back for the next week")
	# An unanswered card gives nothing for free: a training card left alone
	# is a normal week (no XP, no morale, no fresh legs) ...
	var ev := ClubLife._training()
	GameState.week_event = ev
	var xp_before := {}
	var morale_before := {}
	for q in GameState.my_list:
		xp_before[str(q["id"])] = int(q.get("xp", 0))
		morale_before[str(q["id"])] = ClubLife.morale(q)
	GameState._settle_week_event()
	var untouched := true
	for q in GameState.my_list:
		untouched = untouched and int(q.get("xp", 0)) == int(xp_before[str(q["id"])]) \
				and ClubLife.morale(q) == int(morale_before[str(q["id"])]) and not q.has("fresh") and not q.has("heavy_legs")
	_check(bool(ev.get("resolved", false)) and int(ev["choice"]) == -1 and untouched,
			"An unanswered training card changes nothing")
	GameState.advance()
	# ... but not acting has its consequences: a sore star nobody rested
	# plays sore, and silence over an incident costs the board's confidence.
	var sore_star: Dictionary = {}
	for q in GameState.my_list:
		if int(q.get("injury_weeks", 0)) == 0 and not q.has("rested"):
			sore_star = q  # a fit player: an injured one is "ruled out anyway"
			break
	GameState.week_event = ClubLife._sore_star(sore_star)
	GameState._settle_week_event()
	_check(bool(sore_star.get("sore", false)) and not bool(sore_star.get("rested", false)),
			"A sore star nobody rests plays sore")
	var conf_before := GameState.board_confidence()
	var paper_man: Dictionary = GameState.my_list[2]
	var paper_morale := ClubLife.morale(paper_man)
	GameState.week_event = ClubLife._media(paper_man)
	var silence: Dictionary = GameState.week_event["unanswered"]
	_check(str(silence.get("hint", "")).contains("(%d)" % int(silence["board"])),
			"The card says what saying nothing costs: %s" % str(silence.get("hint", "")))
	GameState._settle_week_event()
	_check(GameState.board_confidence() == clampi(conf_before - 4, 0, 100) and ClubLife.morale(paper_man) == paper_morale,
			"Saying nothing about an incident costs the board, and lifts nobody")
	GameState.advance()
	var heavy := ClubLife._training()
	GameState.week_event = heavy
	GameState.resolve_week_event(0)
	var p3: Dictionary = GameState.my_list[3]
	_check(bool(p3.get("heavy_legs", false)), "A heavy week leaves heavy legs for game day")
	var sim := MatchSim.new(GameState.my_squad(), Squad.new("COL", GameDB.club_list("COL"), false, "COL"), 5)
	var legs_ok := true
	for p in sim.squads[0].ground:
		if float(sim.energy[str(p["id"])]) > 88.0:
			legs_ok = false
	_check(legs_ok, "Heavy legs start the match below full energy")
	_test_event_tradeoffs()
	_test_event_decisions()


## Every card is a trade-off: neither answer is all upside.
func _test_event_tradeoffs() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(ClubLife._training()["options"].size() == 2, "No free 'normal week' beside a free recovery week")
	# A kid pushing for games: a development week costs him this week's game.
	var kid: Dictionary = GameState.my_list[30]
	kid["morale"] = 70
	kid["xp"] = 0
	GameState.week_event = ClubLife._young_gun(kid)
	GameState.resolve_week_event(1)
	_check(bool(kid.get("rested", false)) and not Ratings.available(kid),
			"A development week takes him out of this week's game")
	_check(ClubLife.morale(kid) == 70, "A development week is not a free morale lift")
	_check(ClubLife.DEV_WEEK_XP + GameState.XP_SQUAD < GameState.XP_SENIOR_GAME
			and ClubLife.DEV_WEEK_XP + GameState.XP_SQUAD > GameState.reserves_xp(),
			"A development week is worth less than a senior game and more than the reserves")
	# ...or his chance: he expects to be picked.
	var kid2: Dictionary = GameState.my_list[31]
	kid2["morale"] = 70
	GameState.week_event = ClubLife._young_gun(kid2)
	GameState.resolve_week_event(0)
	_check(Ratings.available(kid2) and ClubLife.morale(kid2) == 75 and int(kid2.get("expects_game", 0)) == 10,
			"Giving him a game: thrilled, available, and he expects to be picked")
	# On auto-pick he is named on the ground, without you touching the side.
	var on_ground := false
	for p in GameState.my_squad().ground:
		if str(p["id"]) == str(kid2["id"]):
			on_ground = true
	_check(on_ground, "Auto-pick names the kid you gave a game (%s)" % GameState.week_event.get("outcome", ""))
	_check(str(GameState.week_event.get("outcome", "")).contains("Auto-pick names him"),
			"The outcome says auto-pick has him")
	kid2.erase("expects_game")
	# An unhappy player: sitting down with him commits you to a game.
	var sulk: Dictionary = GameState.my_list[26]
	sulk["morale"] = 30
	GameState.week_event = ClubLife._unhappy(sulk)
	GameState.resolve_week_event(0)
	_check(ClubLife.morale(sulk) == 45 and bool(sulk.get("expects_game", false)), "A talk lifts him, and he expects a game")
	# Your own side that leaves him out: the promise is broken, and it sours.
	var side: Dictionary = GameState.current_side()
	for k in side:
		(side[k] as Array).erase(str(sulk["id"]))
	side["OUT"] = [str(sulk["id"])]
	GameState.set_selection(side)
	var before := ClubLife.morale(sulk)
	GameState.advance()
	GameState.set_selection({})
	if int(sulk.get("injury_weeks", 0)) <= 0:
		_check(ClubLife.morale(sulk) <= before - 12 + 2, "Left out after the talk, it sours (%d -> %d)" % [before, ClubLife.morale(sulk)])
	else:
		print("SKIP: he was injured this week, so being left out says nothing")
	_check(not sulk.has("expects_game"), "The expectation lasts one week")
	var sulk2: Dictionary = GameState.my_list[27]
	var mate: Dictionary = GameState.my_list[0]
	sulk2["morale"] = 30
	mate["morale"] = 70
	GameState.week_event = ClubLife._unhappy(sulk2)
	GameState.resolve_week_event(1)
	_check(ClubLife.morale(sulk2) == 25 and ClubLife.morale(mate) == 72, "Earn it: he dips, the group lifts")

## Each card is a decision, not a good button and a bad one: both options
## carry a cost, the costs are real, and nothing repeats every week.
func _test_event_decisions() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	# --- Contract: a real premium for certainty, only when affordable ------
	var star: Dictionary = GameState.my_list[2]
	star["overall"] = 80
	star["contract_years"] = 1
	star["morale"] = 70
	star["age"] = 24.0
	var ask := Contracts.asking_salary(star)
	var early := ClubLife.early_price(star)
	_check(early >= ask + 1 and float(early) >= float(ask) * 1.12,
			"Extending early costs materially more than today's price (%d v %d)" % [early, ask])
	_check(ClubLife.extension_wanted(star, {}), "A star out of contract asks to extend")
	var good: Dictionary = star.duplicate()
	good["overall"] = ClubLife.EXTENSION_MIN_OVR - 4
	_check(not ClubLife.extension_wanted(good, {}), "A good player below star level waits for the off-season")
	_check(not ClubLife.extension_wanted(star, {"extension|someone_else": true}),
			"Only one star asks to extend early in a season")
	var offered_broke := false
	for r in range(1, 40):
		var ev := ClubLife.pick_event({"list": GameState.my_list, "round": r, "seed": 7,
				"cap_room": -50, "memory": {}, "selected": {}})
		if str(ev.get("key", "")) == "extension":
			offered_broke = true
	_check(not offered_broke, "No extension card when the cap cannot carry it")
	_check(not ClubLife.extension_wanted(star, {"extension|" + str(star["id"]): true}),
			"He asks once a season, not every week")
	GameState.salary_cap = 999999999
	var sal_before := int(star["salary"])
	GameState.week_event = ClubLife._extension(star)
	GameState.resolve_week_event(1)
	_check(int(star["contract_years"]) == 1 and int(star["salary"]) == sal_before and ClubLife.morale(star) == 65,
			"Waiting commits nothing and costs a little morale")
	GameState.week_event = ClubLife._extension(star)
	GameState.resolve_week_event(0)
	_check(int(star["salary"]) == early and int(star["contract_years"]) == 3,
			"Extending locks in the early price for three seasons (young)")
	var vet: Dictionary = GameState.my_list[3]
	vet["contract_years"] = 1
	vet["age"] = 31.0
	_check(ClubLife.early_years(vet) == 2, "An older player extends for less time")
	# Already re-signed when the card resolves: nothing changes.
	var signed: Dictionary = GameState.my_list[4]
	signed["contract_years"] = 3
	var s_sal := int(signed["salary"])
	GameState.week_event = ClubLife._extension(signed)
	GameState.resolve_week_event(0)
	_check(int(signed["salary"]) == s_sal and int(signed["contract_years"]) == 3,
			"An extension card for a player already signed changes nothing")
	# The cap filled up since the card was drawn: no extension, no punishment.
	var late: Dictionary = GameState.my_list[5]
	late["contract_years"] = 1
	late["morale"] = 70
	GameState.salary_cap = 0
	GameState.week_event = ClubLife._extension(late)
	GameState.resolve_week_event(0)
	_check(int(late["contract_years"]) == 1 and ClubLife.morale(late) == 70,
			"No cap room at resolution: he waits, and is not punished for it")
	GameState.salary_cap = 999999999
	# --- Sore player: playing is a real risk, resting a real cost ----------
	var sore: Dictionary = GameState.my_list[1]
	var base_risk := Injuries.chance(sore)
	GameState.week_event = ClubLife._sore_star(sore)
	GameState.resolve_week_event(1)
	var risk := Injuries.chance(sore)
	_check(is_equal_approx(risk, base_risk * ClubLife.SORE_RISK) and risk > 0.15 and risk < 0.4,
			"Playing him sore: a real but not certain breakdown risk (%.2f)" % risk)
	_check(is_equal_approx(MatchSim._start_energy(sore), ClubLife.SORE_LEGS), "...and he starts short of a gallop")
	# --- Training: development against freshness ---------------------------
	var q: Dictionary = GameState.my_list[6]
	var r0 := Injuries.chance(q)
	GameState.week_event = ClubLife._training()
	GameState.resolve_week_event(0)
	_check(Injuries.chance(q) > r0 and float(MatchSim._start_energy(q)) < 100.0,
			"A heavy week: heavier legs and more soft-tissue risk")
	GameState.advance()
	var q2: Dictionary = GameState.my_list[6]
	var m0 := ClubLife.morale(q2)
	var r1 := Injuries.chance(q2)
	GameState.week_event = ClubLife._training()
	GameState.resolve_week_event(1)
	_check(Injuries.chance(q2) < r1 and ClubLife.morale(q2) >= mini(100, m0 + 3),
			"A recovery week: fewer injuries and a lift")
	# --- Board pressure: once a losing run, not every week of it -----------
	var fires := {}
	for losses in [3, 4, 5, 6]:
		var hit := false
		for r in range(1, 60):
			if str(ClubLife.pick_event({"list": GameState.my_list, "round": r, "seed": 3,
					"losses": losses}).get("key", "")) == "pressure":
				hit = true
		fires[losses] = hit
	_check(fires[3] and not fires[4] and not fires[5] and fires[6],
			"The board calls at three and six straight losses, not every week (%s)" % str(fires))
	# --- Unhappy: not the same player again straight away; never injured --
	var sad: Dictionary = GameState.my_list[20]
	sad["morale"] = 20
	var no_repeat := true
	for r in range(1, 50):
		var ev := ClubLife.pick_event({"list": [sad], "round": r, "seed": 5,
				"memory": {"unhappy|" + str(sad["id"]): r - 2}})
		if str(ev.get("key", "")) == "unhappy":
			no_repeat = false
	_check(no_repeat, "The same unhappy player does not come back two weeks later")
	sad["injury_weeks"] = 3
	var injured_card := false
	for r in range(1, 50):
		if str(ClubLife.pick_event({"list": [sad], "round": r, "seed": 5}).get("key", "")) == "unhappy":
			injured_card = true
	_check(not injured_card, "No 'sit down with him' card for an injured player you cannot pick")
	sad["injury_weeks"] = 0
	# The promise resolves once.
	sad["morale"] = 30
	GameState.week_event = ClubLife._unhappy(sad)
	GameState.resolve_week_event(0)
	GameState.advance()
	var after_one := ClubLife.morale(sad)
	# Only the promise is measured: next week's card (settled with its
	# default when left unanswered) can move the whole group's morale.
	GameState.week_event = {}
	GameState.advance()
	_check(not sad.has("expects_game") and absi(ClubLife.morale(sad) - after_one) <= 6,
			"A promised game is judged once, not every week after")
	# --- Repetition: never the same card two weeks running with others about
	var repeats := 0
	var last := ""
	for r in range(1, 80):
		var ev := ClubLife.pick_event({"list": GameState.my_list, "round": r, "seed": 11,
				"last_key": last})
		var k := str(ev.get("key", ""))
		if k != "" and k == last:
			repeats += 1
		last = k
	_check(repeats == 0, "No card twice in a row (%d repeats)" % repeats)
	# --- A player who has left before the card resolves ---------------------
	var gone := {"id": "gone_player", "overall": 80, "attr": {"durability": 50}}
	GameState.week_event = ClubLife._sore_star(gone)
	var outcome := GameState.resolve_week_event(1)
	_check(outcome.begins_with("The moment has passed"), "A card about a departed player resolves harmlessly")


func _test_sacking() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.board["goal"] = {"key": "top4", "text": "Finish in the top four", "pos": 0}
	GameState.board["confidence"] = 10
	var season = GameState.season
	season.round_index = season.fixture.size()
	GameState.ensure_finals()
	while not season.is_season_over():
		GameState.advance()
	var met_flag: bool = GameState.premier() == "GEE"
	if not met_flag:
		_check(bool(GameState.board.get("warned", false)) and not GameState.is_sacked(),
				"A first bad season brings a final warning")
		GameState.board["confidence"] = 10
		GameState._board_season_end()
		_check(GameState.is_sacked(), "A second one and you are sacked")
	else:
		print("SKIP: GEE won the flag, so the warning never comes")
		print("SKIP: GEE won the flag, so the sacking never comes")


## Team form: bounded, saturating, quick to turn, neutral by default, and
## narrow in the engine (composure only).
func _test_team_form() -> void:
	var f := func(r: String) -> float:
		var arr := []
		for c in r:
			arr.append(c)
		return ClubLife.team_form(arr)
	_check(is_zero_approx(f.call("")), "No games: neutral form")
	_check(is_zero_approx(f.call("WLWLW") - 0.30 + 0.25 - 0.20 + 0.15 - 0.10) and absf(f.call("WLWLW")) < 0.25,
			"Alternating results stay near neutral (%.2f)" % f.call("WLWLW"))
	_check(f.call("LLLWW") > 0.0 and f.call("LLLWW") < 0.25, "Two wins after a poor run: a small lift (%.2f)" % f.call("LLLWW"))
	_check(is_equal_approx(f.call("WWWWW"), 1.0) and is_equal_approx(f.call("WWWWWWWWWW"), 1.0),
			"Five straight wins hits the cap; more wins add nothing")
	_check(f.call("WWWW") > f.call("WW") and f.call("WWWWW") - f.call("WWWW") < f.call("WW") - f.call("W"),
			"Each extra win in a streak adds less")
	_check(is_equal_approx(f.call("WWWWWL"), 0.40) and is_equal_approx(f.call("WWWWWLL"), -0.10),
			"A streak turns quickly: one loss to +0.40, two to -0.10")
	_check(is_equal_approx(f.call("LLLLLLLL"), -1.0) and is_equal_approx(f.call("LLLLLW"), -0.40),
			"Losing runs are capped the same way and turn as fast")
	_check(ClubLife.team_form_label(f.call("WLDW")) == "Good" and ClubLife.team_form_label(f.call("LWDL")) == "Poor"
			and ClubLife.team_form_label(f.call("WWLWW")) == "Hot",
			"Forms landing exactly on a threshold get that label (WLDW %.17f)" % f.call("WLDW"))
	_check(ClubLife.team_form_label(1.0) == "Hot" and ClubLife.team_form_label(0.0) == "Steady"
			and ClubLife.team_form_label(-1.0) == "Cold", "Form reads Hot / Steady / Cold")

	# The engine: neutral form is the old engine exactly.
	var a := Squad.new("RIC", GameDB.club_list("RIC"), true, "RIC")
	var b := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
	var plain := MatchSim.new(a, b, 99).run()
	var a0 := Squad.new("RIC", GameDB.club_list("RIC"), true, "RIC")
	var b0 := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
	a0.form = 0.0
	b0.form = 0.0
	var zero := MatchSim.new(a0, b0, 99).run()
	_check(zero["events"] == plain["events"] and zero["score"] == plain["score"],
			"Neutral form changes nothing in a match")
	_check(not (plain["impact"][0] as Dictionary).has("form"), "Neutral form is credited nothing")
	# Hot form: a few fewer clangers, credited to team form, nothing else.
	var hot_cl := 0.0
	var cold_cl := 0.0
	var credit := 0.0
	for i in range(40):
		for sign in [1.0, -1.0]:
			var h := Squad.new("RIC", GameDB.club_list("RIC"), false, "RIC")
			var o := Squad.new("RIC", GameDB.club_list("RIC"), false, "RIC")
			h.form = sign
			var r := MatchSim.new(h, o, 300 + i).run()
			var cl := float(r["team"][0].get("clangers", 0))
			if sign > 0.0:
				hot_cl += cl
				credit += float((r["impact"][0] as Dictionary).get("form", 0.0))
			else:
				cold_cl += cl
	_check(hot_cl < cold_cl, "A side in form makes fewer clangers than one out of form (%d v %d)" % [int(hot_cl), int(cold_cl)])
	_check(credit / 40.0 > 0.5 and credit / 40.0 < 5.0,
			"Full form is worth a few points a game, not a landslide (%.2f)" % (credit / 40.0))

	# The season: form comes from the club's own results and survives a save.
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(is_zero_approx(GameState.season.club_form("GEE")), "Every club starts the season steady")
	for i in range(6):
		GameState.week_event = {}
		GameState.advance()
	var res: Array = GameState.season.club_results("GEE")
	_check(res.size() == 6, "Six rounds give six results (%d)" % res.size())
	var info := GameState.club_form_info("GEE")
	_check(is_equal_approx(float(info["value"]), ClubLife.team_form(res))
			and str(info["last"]) == "".join(res.slice(1)), "The hub shows the last five and the form they give")
	_check(GameState.form_line(info).begins_with("Form: " + str(info["label"])), "Form line reads Form: <label>")
	var before := GameState.season.club_form("GEE")
	GameState.save_career()
	GameState.load_career()
	_check(is_equal_approx(GameState.season.club_form("GEE"), before), "Form survives a save (it is derived from results)")


## How we play, read from a made-up league at 3, 6, 12 and 22 games: a
## point or two is never a trait, an early read needs a big gap, a real
## trait firms up, and a points source is not said next to its total.
func _test_how_we_play_reads() -> void:
	GameState.reset()
	var base := {"for": 85.0, "against": 85.0, "clearances": 37.0, "inside50": 50.0,
		"pressure_acts": 60.0, "marks": 90.0, "clangers": 50.0, "hitouts": 36.0,
		"from_turnover": 40.0, "from_stoppage": 30.0, "conceded_turnover": 40.0, "conceded_stoppage": 30.0}
	var read := func(delta: Dictionary, games: int) -> Array:
		GameState.season_team = {}
		for i in range(17):
			var row := {"games": games}
			for k in base:
				row[k] = float(base[k]) * games
			GameState.season_team["C%d" % i] = row
		var mine := {"games": games}
		for k in base:
			mine[k] = (float(base[k]) + float(delta.get(k, 0.0))) * games
		GameState.season_team["ME"] = mine
		return GameState._style_found("ME")
	var keys := func(found: Array) -> Array:
		return found.map(func(f): return str(f["k"]))
	var small_ok := true
	var floor_ok := true
	var said_ok := true
	for g in [3, 6, 12, 22]:
		if not (read.call({"for": 1.0, "against": -2.0, "clearances": 1.0, "hitouts": 3.0}, g) as Array).is_empty():
			small_ok = false
		for f in read.call({"for": 30.0, "against": 12.0, "marks": 7.0, "clangers": -5.0, "hitouts": 12.0}, g):
			if float(f["rel"]) < 1.0:
				floor_ok = false
		var style: Dictionary = GameState.how_we_play("ME")
		if (style["win"] as Array).size() > 2 or (style["beaten"] as Array).size() > 2:
			said_ok = false
	_check(small_ok, "A point or two a game is never how you play, early or late")
	_check(floor_ok, "Every trait said clears its own smallest worthwhile gap")
	_check(said_ok, "At most two lines each way, however many traits there are")
	var firm := {"for": 15.0}
	var early: Array = keys.call(read.call(firm, 3)) + keys.call(read.call(firm, 6))
	var late: Array = keys.call(read.call(firm, 12)) + keys.call(read.call(firm, 22))
	_check(not early.has("for") and late.count("for") == 2,
			"A real two-goal edge waits for the season to confirm it (%s / %s)" % [early, late])
	var loud: Array = read.call({"for": 30.0}, 3)
	_check(keys.call(loud) == ["for"] and int(loud[0]["n"]) >= 25,
			"A big early gap is said at once, with the real margin (%s)" % str(loud))
	var dup: Array = keys.call(read.call({"for": 15.0, "from_stoppage": 12.0, "conceded_stoppage": 10.0}, 22))
	_check(dup.has("for") and not dup.has("from_stoppage") and dup.has("conceded_stoppage"),
			"Where points come from is not repeated next to the total (%s)" % str(dup))
	# Turnover points differ by a point or two between clubs, never a goal:
	# they are not a line at all (territory, clangers and pressure say it).
	var turnover: Array = keys.call(read.call({"from_turnover": 20.0, "conceded_turnover": 20.0}, 22))
	_check(not GameState.STYLE_LINES.has("from_turnover") and not GameState.STYLE_LINES.has("conceded_turnover")
			and turnover.is_empty(), "Points from turnovers are not a how-we-play line (%s)" % str(turnover))
	GameState.reset()


## The How we play read opens the moment your third game is done, played
## live or simmed, and stays open through a save and load.
func _test_how_we_play_unlocks_on_the_third_game() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var counts := []
	for i in range(3):
		if i == 1:
			GameState.advance()
		elif GameState.prepare_interactive_match():
			var sim: MatchSim = GameState.pending_sim
			var res := {}
			while sim.current_quarter <= 4:
				res = sim.run_quarter()
			res["home"] = GameState.pending_match["home"]
			res["away"] = GameState.pending_match["away"]
			res["label"] = GameState.pending_match["label"]
			GameState.finish_interactive_match(res)
		counts.append(int(GameState.how_we_play()["games"]))
	_check(counts == [1, 2, 3], "Every game of yours counts, live or simmed (%s)" % str(counts))
	_check(GameState.save_career() and GameState.load_career()
			and int(GameState.how_we_play()["games"]) == 3,
			"Three games still read as three after a reload")
	GameState.reset()


## Coaching hub: the standing game plan reaches every match of yours, form
## reads your players' last three games against their season, and how we
## play is read from the season's team numbers.
func _test_coaching_hub() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.club_plan == "balanced", "A career starts on a balanced plan")
	GameState.set_club_plan("nonsense")
	_check(GameState.club_plan == "balanced", "Only a real plan can be chosen")
	GameState.set_club_plan("defensive")
	_check(GameState.season.plans.get("GEE", "") == "defensive" and GameState.season.plans.size() == 1,
			"Your plan is yours alone: other clubs keep theirs")
	# A simmed match of yours runs on it from the first bounce.
	var sim_plan := ""
	var fx: Array = GameState.season.fixture[GameState.season.round_index]
	for m in fx:
		if m["home"] == "GEE" or m["away"] == "GEE":
			var res := GameState.season.simulate(str(m["home"]), str(m["away"]), 77)
			var side := 0 if m["home"] == "GEE" else 1
			var hist: Array = res.get("tactics_history", [])
			if not hist.is_empty():
				sim_plan = str(((hist[0]["plans"] as Array)[side] as Dictionary).get("gameplan", ""))
	_check(sim_plan == "defensive", "A simmed match of yours starts on your plan (%s)" % sim_plan)
	# Three rounds: no style read yet before three games, then one appears.
	_check(int(GameState.how_we_play()["games"]) == 0 and (GameState.how_we_play()["win"] as Array).is_empty(),
			"Nothing is said about how you play before a game")
	for i in range(6):
		GameState.advance()
	var style := GameState.how_we_play()
	_check(int(style["games"]) >= 3 and (style["win"] as Array).size() <= 2 and (style["beaten"] as Array).size() <= 2,
			"After a few games, at most two lines each on how you win and get beaten (%s)" % str(style))
	var mine: Dictionary = GameState.season_team["GEE"]
	_check(mine.has("from_turnover") and mine.has("conceded_stoppage")
			and float(mine["from_turnover"]) + float(mine["from_stoppage"]) <= float(mine["for"]) + 0.01,
			"Where our points come from, both ways, is kept for the season")
	var odd_lines := []
	for line in (style["win"] as Array) + (style["beaten"] as Array):
		if not str(line).contains("a game") or str(line).contains("%"):
			odd_lines.append(str(line))
	_check(odd_lines.is_empty(), "Every style line is football words and a number (%s)" % str(odd_lines))
	# Form: last three against his season, only with five games behind him.
	var some: String = GameState.form_log.keys()[0] if not GameState.form_log.is_empty() else ""
	_check(some != "" and (GameState.form_log[some]["last"] as Array).size() <= 3,
			"Each player's form keeps only his last three games")
	GameState.form_log = {"X1": {"last": [120, 110, 130], "sum": 600, "n": 8},
			"X2": {"last": [20, 30, 25], "sum": 600, "n": 8},
			"X3": {"last": [120, 110, 130], "sum": 360, "n": 3}}
	var keep := GameState.my_list
	GameState.my_list = [{"id": "X1"}, {"id": "X2"}, {"id": "X3"}]
	var form := GameState.player_form()
	GameState.my_list = keep
	_check((form["hot"] as Array).size() == 1 and str(form["hot"][0]["id"]) == "X1"
			and int(form["hot"][0]["recent"]) == 120 and int(form["hot"][0]["season"]) == 75,
			"In form: well above his own season (%s)" % str(form))
	_check((form["cold"] as Array).size() == 1 and str(form["cold"][0]["id"]) == "X2",
			"Out of form: well below it; too few games says nothing")
	_check(GameState.save_career() and GameState.load_career() and GameState.club_plan == "defensive"
			and GameState.form_log.has("X1") and not GameState.season_team.is_empty(),
			"The plan, form and season numbers survive a save")
	_check(GameState.season.plans.get("GEE", "") == "defensive", "A loaded career plays on its plan")
	GameState.set_club_plan("balanced")
	GameState.delete_saved_career()


## ARD-M6-003: the board is read in words, moves slowly against what the
## season's goal asks, and says why it moved.
func _test_board_confidence() -> void:
	var top4 := ClubLife.board_goal(2, 1)
	var battler := ClubLife.board_goal(17)
	var w_top := int(ClubLife.after_match(60, 12, ClubLife.goal_steps(top4))["delta"])
	var l_top := int(ClubLife.after_match(60, -12, ClubLife.goal_steps(top4))["delta"])
	var w_bat := int(ClubLife.after_match(60, 12, ClubLife.goal_steps(battler))["delta"])
	var l_bat := int(ClubLife.after_match(60, -12, ClubLife.goal_steps(battler))["delta"])
	_check(w_top < w_bat and l_top < l_bat and absi(l_top) > w_top and absi(l_bat) < w_bat,
			"A loss costs a top-four side more and a win earns it less than a side asked to win seven (%d/%d v %d/%d)" % [w_top, l_top, w_bat, l_bat])
	_check(absi(l_top) <= 3 and w_bat <= 3, "One ordinary result never moves the board more than three")
	var run := int(ClubLife.after_match(60, -12, ClubLife.goal_steps(top4), 4)["delta"])
	_check(run < l_top, "A long losing run starts to tell")
	_check(int(ClubLife.after_match(60, 0, ClubLife.goal_steps(top4))["delta"]) == 0, "A draw leaves the board where it was")
	var states := []
	for c in [90, 70, 50, 35, 10]:
		states.append(ClubLife.board_state(c))
	_check(states == ["Very secure", "Secure", "Stable", "Under pressure", "In trouble"],
			"The board reads in words (%s)" % str(states))
	_check(ClubLife.board_state(ClubLife.START_CONFIDENCE) == "Stable", "A new coach starts stable")
	_check(ClubLife.match_reason(top4, "Carlton", -5, 1) == "The loss to Carlton puts a top-four finish under threat."
			and ClubLife.match_reason(battler, "Carlton", 20, 0) == "The win over Carlton keeps seven wins in reach."
			and ClubLife.match_reason(top4, "Carlton", -5, 4).begins_with("Four losses in a row"),
			"The board says why it moved, in football words")
	# In a career: after a round the reason is there and the words show.
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState._settle_week_event()
	GameState.week_event = {}
	GameState.advance()
	_check(GameState.board_why() != "" and GameState.board_state() != "", "After a match the board has a mood and a reason")
	GameState.delete_saved_career()


# ---------------------------------------------------------------------------
# Backing a young player: a promised run (Backing.gd)
# ---------------------------------------------------------------------------
## A list player made ready to be backed: a career on record in full with
## `games` senior games, fit, settled, and no run on.
func _kid(p: Dictionary, games: int) -> Dictionary:
	p["career"] = {"games": games, "goals": 0, "stints": [],
			"through": GameState.season_year - 1, "unknown": []}
	for key in ["backed", "expects_game", "injury_weeks", "injury_kind", "suspension_weeks", "rested"]:
		p.erase(key)
	p["morale"] = 70
	return p


## The lowest-rated player on your list who is not a ruck: one auto-pick would
## not name on his own.
func _spare_kid(skip := []) -> Dictionary:
	var best := {}
	for p in GameState.my_list:
		if str(p["role"]) == "RUCK" or skip.has(str(p["id"])):
			continue
		if best.is_empty() or int(p["overall"]) < int(best["overall"]):
			best = p
	return best


func _in_side(side: Dictionary, p: Dictionary) -> bool:
	for k in side:
		if (side[k] as Array).has(str(p["id"])):
			return true
	return false


func _fresh_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState._settle_week_event()
	GameState.week_event = {}


## The rules: who can be backed, how a run moves and ends, what it says.
func _test_backing_rules() -> void:
	_fresh_season()
	var kid := _kid(GameState.my_list[30], 3)
	_check(Backing.can_back(kid, 3), "A player with few senior games can be backed")
	_check(not Backing.can_back(kid, Backing.FEW_GAMES) and not Backing.can_back(kid, 80),
			"A player with ten senior games is established, not a kid to back")
	var unknown := _kid(GameState.my_list[29], 3)
	unknown["career"]["unknown"] = [[2020, 2022]]
	_check(not Backing.can_back(unknown, 3), "A career not on record in full cannot be counted")
	var hurt := _kid(GameState.my_list[28], 3)
	hurt["injury_weeks"] = 2
	_check(not Backing.can_back(hurt, 3), "An injured player cannot be backed")
	var run := Backing.start(kid, 2027, 7, 0)
	_check(Backing.is_active(kid) and int(run["games"]) == Backing.RUN_GAMES and int(run["played"]) == 0
			and bool(run["debut"]) and int(run["round"]) == 7, "A run starts active, and on his debut")
	_check(not Backing.can_back(kid, 3), "No second run while one is on")
	_check(Backing.note(kid) == "You promised %s a run: game one of three." % GameDB.player_display_name(kid),
			"The reminder reads plainly (%s)" % Backing.note(kid))
	_check(Backing.after_match(kid, true, true) == "active" and int(run["played"]) == 1
			and Backing.note(kid).ends_with("game two of three."),
			"A game played counts, and the reminder moves on")
	kid["injury_weeks"] = 1
	_check(Backing.after_match(kid, false, false) == "active" and int(run["played"]) == 1
			and Backing.note(kid).ends_with("game two of three, when available."),
			"Unable to play, the run waits and says so")
	kid.erase("injury_weeks")
	_check(Backing.after_match(kid, true, true) == "active" and Backing.after_match(kid, true, true) == "done"
			and not Backing.is_active(kid) and Backing.note(kid) == "", "Three games complete the run")
	var kid2 := _kid(GameState.my_list[27], 5)
	Backing.start(kid2, 2027, 3, 5)
	_check(not bool(Backing.ledger(kid2)[0]["debut"]), "A player with games behind him is not on debut")
	_check(Backing.after_match(kid2, false, true) == "broken" and not Backing.is_active(kid2)
			and Backing.after_match(kid2, false, true) == "",
			"Left out while fit breaks the promise, once, and the run is over")
	var kid3 := _kid(GameState.my_list[26], 5)
	Backing.start(kid3, 2027, 20, 5)
	Backing.lapse(kid3)
	_check(str(Backing.ledger(kid3)[0]["state"]) == "lapsed" and not Backing.is_active(kid3),
			"A run unfinished at the end of the season lapses")
	Backing.start(kid2, 2028, 2, 5)
	_check(Backing.ledger(kid2).size() == 2 and str(Backing.ledger(kid2)[0]["state"]) == "broken"
			and Backing.is_active(kid2), "The ledger keeps what you did, and a new run can follow")
	# Auto-pick treats a run as a promise, ruck included.
	var list := []
	for p in GameDB.club_list("COL"):
		list.append((p as Dictionary).duplicate(true))
	var rucks := []
	for p in list:
		if Ratings.plays_role(p, "RUCK"):
			rucks.append(p)
	rucks = Ratings.by_ruck(rucks)
	if rucks.size() >= 2:
		var backup: Dictionary = rucks[1]
		var before := Ratings.select_22(list)
		_check(str((before["ground"] as Array)[0]["id"]) == str((rucks[0] as Dictionary)["id"]),
				"With no promise the better ruck takes the ruck spot")
		Backing.start(backup, 2027, 1, 0)
		var after := Ratings.select_22(list)
		_check(str((after["ground"] as Array)[0]["id"]) == str(backup["id"]),
				"A ruck on a run takes the ruck spot, as every other position's promise does")
	else:
		print("SKIP: COL has no second ruck to back")


## Through a season: the card, the tap, auto-pick, three games, a broken
## promise, an injury that waits, and what the screen is told.
func _test_backing_flow() -> void:
	_fresh_season()
	# The card: back him for three games.
	var kid := _kid(GameState.my_list[31], 0)
	GameState.week_event = ClubLife._young_gun(kid)
	GameState.resolve_week_event(0)
	_check(Backing.is_active(kid) and ClubLife.morale(kid) == 70 + Backing.THRILL
			and int(kid.get("expects_game", 0)) == Backing.STING and bool(Backing.current(kid)["debut"]),
			"Backing a kid on the card starts a run on his debut: thrilled, and he expects to be picked")
	_check(str(GameState.week_event.get("outcome", "")).contains("run of three games")
			and str(GameState.week_event.get("outcome", "")).contains("Auto-pick names him"),
			"The card says it is a run, and that auto-pick has him")
	# The tap: a player auto-pick would not name.
	var low := _kid(_spare_kid([str(kid["id"])]), 2)
	_check(not _in_side(GameState.current_side(), low), "Auto-pick leaves the lowest-rated player out")
	_check(GameState.can_back(low), "A player with two senior games can be backed from Selection")
	var said := GameState.back_player(str(low["id"]))
	_check(said == "%s has your word for three games. Auto-pick names the player this week." % GameDB.player_display_name(low),
			"The tap says what changed (%s)" % said)
	_check(_in_side(GameState.current_side(), low), "Auto-pick names a player on a run, ahead of better players")
	_check(not GameState.can_back(low) and GameState.back_player(str(low["id"])) == "",
			"A player on a run cannot be backed again")
	var vet := _kid(GameState.my_list[3], 120)
	_check(not GameState.can_back(vet) and GameState.back_player(str(vet["id"])) == "" and not Backing.is_active(vet),
			"A player with a long record is not backed from Selection")
	var notes := GameState.backing_notes()
	var texts := []
	for n in notes:
		texts.append(str(n["text"]))
	_check(notes.size() == 2 and texts.has(Backing.note(kid)) and texts.has(Backing.note(low)),
			"Selection is told each run in a line (%s)" % str(texts))
	# Three games: both play every week (healed between rounds so the run is
	# not at the mercy of a random injury) and the runs are done.
	for i in range(Backing.RUN_GAMES):
		GameState.advance()
		for q in [kid, low]:
			for key in ["injury_weeks", "injury_kind", "suspension_weeks"]:
				q.erase(key)
	var kl: Dictionary = Backing.ledger(kid)[0]
	var ll: Dictionary = Backing.ledger(low)[0]
	_check(str(kl["state"]) == "done" and int(kl["played"]) == 3 and str(ll["state"]) == "done" and int(ll["played"]) == 3,
			"Three games complete each run (%s %d, %s %d)" % [kl["state"], kl["played"], ll["state"], ll["played"]])
	_check(not kid.has("expects_game") and not low.has("expects_game") and GameState.backing_notes().is_empty(),
			"A finished run leaves no expectation and no line")

	# Left out while fit: the promise breaks and it stings, once.
	_fresh_season()
	var k2 := _kid(_spare_kid(), 4)
	var control := _kid(_spare_kid([str(k2["id"])]), 4)
	GameState.back_player(str(k2["id"]))
	var side := GameState.current_side()
	for key in side:
		(side[key] as Array).erase(str(k2["id"]))
		(side[key] as Array).erase(str(control["id"]))
	side["OUT"] = [str(k2["id"]), str(control["id"])]
	GameState.set_selection(side)
	var m0 := ClubLife.morale(k2)
	var c0 := ClubLife.morale(control)
	GameState.advance()
	var m1 := ClubLife.morale(k2)
	var c1 := ClubLife.morale(control)
	_check(str(Backing.ledger(k2)[0]["state"]) == "broken" and not Backing.is_active(k2) and not k2.has("expects_game"),
			"Left out while fit, the run is broken")
	_check((m0 - m1) - (c0 - c1) >= 5,
			"Breaking the promise costs more than being left out (%d v %d)" % [m0 - m1, c0 - c1])
	GameState.advance()
	var m2 := ClubLife.morale(k2)
	var c2 := ClubLife.morale(control)
	_check((m1 - m2) - (c1 - c2) <= 2, "It stings once: a second week costs no more than for anyone else left out")
	GameState.set_selection({})

	# Hurt: the run waits, even when the injury ends with this very round.
	_fresh_season()
	var k3 := _kid(_spare_kid(), 1)
	GameState.back_player(str(k3["id"]))
	k3["injury_weeks"] = 1
	var run3: Dictionary = Backing.ledger(k3)[0]
	var mm0 := ClubLife.morale(k3)
	GameState.advance()
	# The ordinary drift for a player not on the field is allowed; the sting is not.
	_check(str(run3["state"]) == "active" and int(run3["played"]) == 0 and ClubLife.morale(k3) >= mm0 - 5,
			"An injury that ends with the round does not break the run (%d -> %d)" % [mm0, ClubLife.morale(k3)])
	_check(Backing.note(k3) != "" and not Backing.note(k3).contains("when available"),
			"Fit again, the reminder is back to the plain line")
	GameState.advance()
	_check(int(run3["played"]) == 1, "Named again when he is fit, he plays game one")
	GameState.delete_saved_career()


## The young-gun card is not for a player who is already on a run.
func _test_backing_card_guard() -> void:
	_fresh_season()
	var list := []
	for i in range(8):
		var p: Dictionary = (GameState.my_list[i] as Dictionary).duplicate(true)
		p["age"] = 28.0
		p.erase("injury_weeks")
		list.append(p)
	var young: Dictionary = (GameState.my_list[8] as Dictionary).duplicate(true)
	young["age"] = 19.0
	young["potential"] = int(young["overall"]) + 12
	young.erase("injury_weeks")
	list.append(young)
	var drawn := 0
	var drawn_backed := 0
	for s in range(120):
		var ctx := {"list": list, "round": 6, "seed": s, "losses": 0, "selected": {}, "cap_room": 0,
				"memory": {}, "last_key": ""}
		if str(ClubLife.pick_event(ctx).get("key", "")) == "young_gun":
			drawn += 1
	Backing.start(young, 2027, 6, 0)
	for s in range(120):
		var ctx := {"list": list, "round": 6, "seed": s, "losses": 0, "selected": {}, "cap_room": 0,
				"memory": {}, "last_key": ""}
		if str(ClubLife.pick_event(ctx).get("key", "")) == "young_gun":
			drawn_backed += 1
	_check(drawn > 0 and drawn_backed == 0,
			"The kid-pushing-for-games card is not drawn for a player on a run (%d v %d)" % [drawn, drawn_backed])


## A run is saved with the career, waits out a long injury, and lapses with the
## season: it never carries into the next one.
func _test_backing_lasts_the_season() -> void:
	_fresh_season()
	var ranked := GameState.my_list.duplicate()
	ranked.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var kid := _kid(ranked[10], 2)
	kid["age"] = 20.0
	var id := str(kid["id"])
	_check(GameState.back_player(id) != "", "A mid-list young player can be backed")
	kid["injury_weeks"] = 60
	GameState.advance()
	GameState.save_career()
	_check(GameState.load_career(), "The career loads")
	var again: Dictionary = GameState.list_player(id)
	_check(not again.is_empty() and Backing.is_active(again) and int(Backing.current(again)["played"]) == 0
			and Backing.note(again).ends_with("when available."),
			"The run is saved with the career, waiting on his injury")
	var guard := 0
	while not GameState.season.is_season_over() and guard < 60:
		guard += 1
		GameState.advance()
	_check(Backing.is_active(GameState.list_player(id)), "A long injury keeps the run waiting through the season")
	if GameState.begin_intake_draft():
		var d: Draft = GameState.draft
		var g2 := 0
		while not d.is_finished() and g2 < 3000:
			g2 += 1
			var c := d._best_ai_pick(d.current_club())
			if c.is_empty() or not d._draft_pick(d.current_club(), c):
				d._skip_current_pick()
		GameState.finish_intake_draft()
	else:
		GameState.start_next_season()
	var next: Dictionary = GameState.list_player(id)
	if next.is_empty():
		print("SKIP: he left the list in the roll-over, so there is no run to lapse")
	else:
		_check(not Backing.is_active(next) and str(Backing.ledger(next)[0]["state"]) == "lapsed"
				and not next.has("expects_game"), "The run lapses with the season")
	GameState.delete_saved_career()


# ---------------------------------------------------------------------------
# The payoff: what a player did first for you (Firsts.gd)
# ---------------------------------------------------------------------------
## The rules and the words: written once, said where it happened, and "on your
## say-so" only when a promise was kept.
func _test_firsts_rules() -> void:
	var p := {"id": "kid", "name": "Ari Bramble"}
	_check(not Firsts.has(p, "debut") and Firsts.with_us_bits(p).is_empty(),
			"A player with nothing on record has nothing to say")
	_check(Firsts.note(p, "debut", 2028, "Round 7") and not Firsts.note(p, "debut", 2029, "Round 1"),
			"A first is written once")
	_check(Firsts.in_match(p, "debut", 2028, "Round 7") and not Firsts.in_match(p, "debut", 2028, "Round 8")
			and not Firsts.in_match(p, "debut", 2029, "Round 7") and not Firsts.in_match(p, "goal", 2028, "Round 7"),
			"...and which match it was")
	for row in [["Round 7", "in Round 7, 2028"], ["Grand Final", "in the Grand Final, 2028"],
			["Semi Final 2", "in a Semi Final, 2028"], ["Elimination Final 1", "in an Elimination Final, 2028"],
			["Qualifying Final 1", "in a Qualifying Final, 2028"], ["Wildcard Final 2", "in a Wildcard Final, 2028"],
			["", "in 2028"]]:
		var said := Firsts.when_text({"year": 2028, "label": row[0]})
		_check(said == row[1], "\"%s\" reads \"%s\" (%s)" % [row[0], row[1], said])
	_check(Firsts.with_us_bits(p) == ["Debuted in Round 7, 2028."], "A debut says where, and nothing about a promise")
	Firsts.note(p, "goal", 2028, "Round 9")
	_check(Firsts.with_us_bits(p) == ["Debuted in Round 7, 2028.", "First goal in Round 9, 2028."],
			"The first goal follows the debut (%s)" % str(Firsts.with_us_bits(p)))
	var q := {"id": "kid2", "name": "Ben Carter"}
	Firsts.note(q, "debut", 2028, "Round 7")
	Firsts.note(q, "goal", 2028, "Round 7")
	_check(Firsts.with_us_bits(q) == ["Debuted in Round 7, 2028.", "First goal on debut."],
			"A goal in the debut game is one thing, not two (%s)" % str(Firsts.with_us_bits(q)))
	Backing.start(q, 2028, 7, 0)
	_check(Firsts.with_us_bits(q)[0] == "Debuted in Round 7, 2028.", "A promise not yet kept is not his say-so")
	Backing.after_match(q, true, true)
	_check(Firsts.with_us_bits(q)[0] == "Debuted in Round 7, 2028, on your say-so.",
			"He debuted on the run you promised: on your say-so")
	var vet := {"id": "vet", "name": "Dan Old"}
	Backing.start(vet, 2028, 7, 40)
	Backing.after_match(vet, true, true)
	Firsts.note(vet, "debut", 2028, "Round 7")
	_check(not Backing.debuted_on_run(vet) and not str(Firsts.with_us_bits(vet)[0]).contains("say-so"),
			"A run for a player with games behind him is not a debut on a promise")
	_check(Firsts.debut_line("Ari Bramble", 0) == "Ari Bramble debuted."
			and Firsts.debut_line("Ari Bramble", 1) == "Ari Bramble kicked a goal on debut."
			and Firsts.debut_line("Ari Bramble", 2) == "Ari Bramble kicked two on debut.",
			"A debut is said with its goals, in words")
	# Where a run ended: only the match that finished it.
	var r := {"id": "run"}
	Backing.start(r, 2028, 5, 0)
	Backing.after_match(r, true, true, {"year": 2028, "label": "Round 5"})
	Backing.after_match(r, false, false, {"year": 2028, "label": "Round 6"})
	_check(not Backing.ledger(r)[0].has("ended"), "A run that is still on has not ended anywhere")
	Backing.after_match(r, true, true, {"year": 2028, "label": "Round 7"})
	Backing.after_match(r, true, true, {"year": 2028, "label": "Round 8"})
	_check(not Backing.finished_in(r, 2028, "Round 8").is_empty() and Backing.finished_in(r, 2028, "Round 7").is_empty()
			and Backing.finished_in(r, 2029, "Round 8").is_empty(),
			"A finished run knows the match that finished it")
	var b := {"id": "brk"}
	Backing.start(b, 2028, 5, 3)
	Backing.after_match(b, false, true, {"year": 2028, "label": "Round 5"})
	_check(str(Backing.ledger(b)[0]["state"]) == "broken" and Backing.ledger(b)[0].has("ended")
			and Backing.finished_in(b, 2028, "Round 5").is_empty(),
			"A broken run keeps where it broke, and is not a finished one")
	# Full time: a debut on your promise, a run done, any debut, a first goal;
	# three at most, and silence for a match that settled nothing.
	var people := {}
	for row in [["a", "Ari Bramble"], ["b", "Ben Carter"], ["c", "Cal Dunn"], ["d", "Dev Evans"], ["e", "Eli Frost"]]:
		people[row[0]] = {"id": row[0], "name": row[1]}
	Firsts.note(people["a"], "debut", 2028, "Round 7")
	Backing.start(people["a"], 2028, 7, 0)
	Backing.after_match(people["a"], true, true)
	Firsts.note(people["b"], "goal", 2028, "Round 7")
	Backing.start(people["c"], 2028, 5, 6)
	for label in ["Round 5", "Round 6", "Round 7"]:
		Backing.after_match(people["c"], true, true, {"year": 2028, "label": label})
	Firsts.note(people["d"], "debut", 2028, "Round 7")
	var res := {"home": "GEE", "away": "COL", "label": "Round 7",
			"roster": [[{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}, {"id": "e"}], []],
			"players": {"a": {"goals": 2}, "b": {"goals": 1}, "d": {"goals": 0}}}
	var find := func(id): return people.get(id, {})
	var lines := Firsts.match_lines(res, 0, 2028, find)
	_check(lines == ["Ari Bramble kicked two on debut.", "Cal Dunn's three-game run is done.", "Dev Evans debuted."],
			"A debut on your promise, a finished run, then a debut; three at most (%s)" % str(lines))
	people.erase("d")
	lines = Firsts.match_lines(res, 0, 2028, find)
	_check(lines == ["Ari Bramble kicked two on debut.", "Cal Dunn's three-game run is done.", "First AFL goal for Ben Carter."],
			"A first goal is said when there is room (%s)" % str(lines))
	var other := res.duplicate()
	other["label"] = "Round 8"
	_check(Firsts.match_lines(other, 0, 2028, find).is_empty() and Firsts.match_lines(res, 0, 2029, find).is_empty()
			and Firsts.match_lines(res, 1, 2028, find).is_empty() and Firsts.match_lines(res, -1, 2028, find).is_empty(),
			"Another match, another year, the other side, or none of yours: silence")


## Through real rounds: the debut is kept when he plays it, "on your say-so"
## follows the promise, full time says the run is done the day it was, and a
## veteran or a career not on record in full is given nothing.
func _test_firsts_flow() -> void:
	_fresh_season()
	var year := GameState.season_year
	var kid := _kid(GameState.my_list[31], 0)
	GameState.week_event = ClubLife._young_gun(kid)
	GameState.resolve_week_event(0)
	var vet := _kid(GameState.my_list[3], 120)
	var unknown := _kid(GameState.my_list[29], 0)
	unknown["career"]["unknown"] = [[2020, 2022]]
	Backing.start(unknown, year, 0, 0)
	var who := GameDB.player_display_name(kid)
	var kid_id := str(kid["id"])
	GameState.advance()
	var d := Firsts.get_one(kid, "debut")
	_check(not d.is_empty() and int(d["year"]) == year and str(d["label"]) == "Round 1",
			"His first game is kept when he plays it (%s)" % str(d))
	_check(not Firsts.has(vet, "debut") and not Firsts.has(unknown, "debut"),
			"A veteran, and a career not on record in full, have no debut to keep")
	var sheet := GameState.with_us_text(kid)
	_check(sheet.contains("Debuted in Round 1, %d, on your say-so." % year),
			"His sheet says he debuted, where, and on your say-so (%s)" % sheet)
	var said_debut := false
	for l in GameState.payoff_lines(GameState.last_match):
		if str(l).begins_with(who) and str(l).contains("debut"):
			said_debut = true
	_check(said_debut, "Full time says he debuted (%s)" % str(GameState.payoff_lines(GameState.last_match)))
	for i in range(Backing.RUN_GAMES - 1):
		for key in ["injury_weeks", "injury_kind", "suspension_weeks"]:
			kid.erase(key)
		GameState.advance()
	var last_round := "Round %d" % Backing.RUN_GAMES
	_check(not Backing.finished_in(kid, year, last_round).is_empty(),
			"The run knows it was finished in %s" % last_round)
	_check(GameState.payoff_lines(GameState.last_match).has("%s's three-game run is done." % who),
			"Full time says the run is done, the day it was (%s)" % str(GameState.payoff_lines(GameState.last_match)))
	_check(str(Firsts.get_one(kid, "debut")["label"]) == "Round 1", "The debut stays where it happened")

	# The facts are saved with the career.
	var before := GameState.with_us_text(kid)
	GameState.save_career()
	_check(GameState.load_career(), "The career loads")
	var again := GameState.list_player(kid_id)
	_check(not again.is_empty() and GameState.with_us_text(again) == before and Firsts.has(again, "debut"),
			"What he did first is saved with the career (%s)" % before)
	GameState.delete_saved_career()


## A first goal, by the same rule as the league news: a career on record in full
## with none before the match. The season's tally holds the match once counted.
func _test_firsts_goals() -> void:
	_fresh_season()
	var year := GameState.season_year
	var scorer := _kid(GameState.my_list[30], 4)
	var veteran := _kid(GameState.my_list[3], 120)
	veteran["career"]["goals"] = 50
	var debutant := _kid(GameState.my_list[29], 0)
	var unknown := _kid(GameState.my_list[28], 0)
	unknown["career"]["unknown"] = [[2020, 2022]]
	var opp_id := str((GameDB.club_list("COL")[0] as Dictionary)["id"])
	var sid := str(scorer["id"])
	var res := {"home": "GEE", "away": "COL", "label": "Round 9",
			"roster": [[{"id": sid}, {"id": str(veteran["id"])}, {"id": str(debutant["id"])},
					{"id": str(unknown["id"])}], [{"id": opp_id}]],
			"players": {sid: {"goals": 2}, str(veteran["id"]): {"goals": 1}, str(debutant["id"]): {"goals": 1},
					str(unknown["id"]): {"goals": 1}, opp_id: {"goals": 3}}}
	_check(GameState.career_goals_before(scorer) == 0 and GameState.career_goals_before(veteran) == 50,
			"Career goals before a match: the record, and nothing counted twice")
	Awards.tally_match(GameState.season_tally, res, true)
	_check(GameState.career_goals_before(scorer, 2) == 0 and GameState.career_goals_before(veteran, 1) == 50,
			"...once the match is in the tally, its goals are taken back out")
	GameState._note_firsts([res])
	_check(Firsts.in_match(scorer, "goal", year, "Round 9") and not Firsts.has(scorer, "debut"),
			"A first goal is kept, and no debut for a player with games behind him")
	_check(not Firsts.has(veteran, "goal") and not Firsts.has(veteran, "debut"),
			"A goal for a player with goals behind him is no first")
	_check(Firsts.in_match(debutant, "debut", year, "Round 9") and Firsts.in_match(debutant, "goal", year, "Round 9"),
			"A debut and a goal in the same game are both kept")
	_check(not Firsts.has(unknown, "goal") and not Firsts.has(unknown, "debut"),
			"A career not on record in full is never given a first")
	var opp := GameState._find_player(opp_id)
	_check(not opp.is_empty() and not Firsts.has(opp, "goal") and not Firsts.has(opp, "debut"),
			"Only your own players are given one")
	_check(GameState.with_us_text(debutant).contains("Debuted in Round 9, %d. First goal on debut." % year),
			"His sheet: a debut, and a goal in it (%s)" % GameState.with_us_text(debutant))
	var told := GameState.payoff_lines(res)
	_check(told.has("First AFL goal for %s." % GameDB.player_display_name(scorer))
			and told.has("%s kicked a goal on debut." % GameDB.player_display_name(debutant)) and told.size() == 2,
			"Full time says a first goal, and a goal on debut once (%s)" % str(told))
	# A second match: the first goal stays where it was, and nothing new is a first.
	var res2 := {"home": "GEE", "away": "COL", "label": "Round 10",
			"roster": [[{"id": sid}], []], "players": {sid: {"goals": 1}}}
	Awards.tally_match(GameState.season_tally, res2, true)
	GameState._note_firsts([res2])
	_check(str(Firsts.get_one(scorer, "goal")["label"]) == "Round 9" and GameState.payoff_lines(res2).is_empty(),
			"A later goal is no first, and the first stays where it was")
	GameState.delete_saved_career()


## Who the live feed can say a first goal for: yours in the match about to be
## played, with a career on record in full and no goal yet this career or season.
func _test_first_goal_candidates() -> void:
	_fresh_season()
	_check(GameState.first_goal_candidates().is_empty(), "Nothing to say before a match is set up")
	var fresh_kid := _kid(GameState.my_list[30], 4)
	var scorer := _kid(GameState.my_list[3], 120)
	scorer["career"]["goals"] = 50
	var unknown := _kid(GameState.my_list[29], 0)
	unknown["career"]["unknown"] = [[2020, 2022]]
	var this_year := _kid(GameState.my_list[28], 10)
	GameState.season_tally[str(this_year["id"])] = {"club": "GEE", "games": 2, "goals": 1, "goals_ha": 1}
	# A run has auto-pick name them, so each is in the side.
	for p in [fresh_kid, scorer, unknown, this_year]:
		Backing.start(p, GameState.season_year, 0, 0)
	_check(GameState.prepare_interactive_match(), "A live match is set up")
	var cand := GameState.first_goal_candidates()
	var mine := {}
	for p in GameState.my_list:
		mine[str(p["id"])] = p
	var all_mine := not cand.is_empty()
	for id in cand:
		if not mine.has(id):
			all_mine = false
	_check(all_mine, "Only your own players are candidates")
	_check(cand.has(str(fresh_kid["id"])), "A player with no goals on a complete career is a candidate")
	_check(not cand.has(str(scorer["id"])) and not cand.has(str(unknown["id"])) and not cand.has(str(this_year["id"])),
			"Not a goalkicker, a career not on record in full, or a goal already this season")
	GameState.delete_saved_career()


## An empty How we get beaten says "yet" only early; past half a season a
## side with no material weakness is told so, not left waiting.
func _test_how_we_play_quiet() -> void:
	var cs = load("res://scripts/ui/CoachingScene.gd")
	_check(cs._quiet_line("beaten", 4) == "Nothing stands out yet.", "Early on, an empty read is provisional")
	var settled: String = cs._quiet_line("beaten", 12)
	_check(not settled.contains("yet") and settled.contains("costing you"),
			"Half a season in, no weakness is said plainly (%s)" % settled)
	_check(not str(cs._quiet_line("win", 12)).contains("yet"), "...and so is no stand-out strength")
