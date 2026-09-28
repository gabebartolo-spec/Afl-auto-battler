extends RefCounted
## The board, morale and the weekly event card. Run through
## tests/run_club_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_rules()
	_test_season_flow()
	_test_events()
	_test_sacking()
	_test_team_form()
	_test_coaching_hub()
	GameState.delete_saved_career()
	print("Club tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_rules() -> void:
	_check(str(ClubLife.board_goal(2)["key"]) == "top4" and str(ClubLife.board_goal(17)["key"]) == "wins7",
			"The board expects more from a stronger list")
	_check(ClubLife.goal_met({"pos": 8}, 6, 12) and not ClubLife.goal_met({"pos": 8}, 10, 12)
			and ClubLife.goal_met({"wins": 7}, 15, 7), "Goals are judged on position or wins")
	_check(ClubLife.after_match(60, 45) == 64 and ClubLife.after_match(60, -10) == 57,
			"Wins lift the board, losses cost it, thrashings count double")
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
	_check(GameState.save_career() and GameState.load_career()
			and GameState.board_goal_text() != "", "The board survives a save and load")
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
	# An unanswered card takes its default when the round is played.
	var ev := ClubLife._training()
	GameState.week_event = ev
	GameState.advance()
	_check(bool(ev.get("resolved", false)) and int(ev["choice"]) == int(ev["default"]),
			"An unanswered card takes its default when the round is played")
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
	# An unhappy player: sitting down with him commits you to a game.
	var sulk: Dictionary = GameState.my_list[26]
	sulk["morale"] = 30
	GameState.week_event = ClubLife._unhappy(sulk)
	GameState.resolve_week_event(0)
	_check(ClubLife.morale(sulk) == 45 and bool(sulk.get("expects_game", false)), "A talk lifts him, and he expects a game")
	var side: Dictionary = GameState.current_side()
	var in_side := false
	for k in side:
		if (side[k] as Array).has(str(sulk["id"])):
			in_side = true
	var before := ClubLife.morale(sulk)
	GameState.advance()
	if not in_side and int(sulk.get("injury_weeks", 0)) <= 0:
		_check(ClubLife.morale(sulk) <= before - 12 + 2, "Left out after the talk, it sours (%d -> %d)" % [before, ClubLife.morale(sulk)])
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
	_check(ClubLife.extension_wanted(star, {}), "A good player out of contract asks to extend")
	var offered_broke := false
	for r in range(1, 40):
		var ev := ClubLife.pick_event({"list": GameState.my_list, "round": r, "seed": 7,
				"cap_room": -50, "memory": {}, "selected": {}})
		if str(ev.get("key", "")) == "extension":
			offered_broke = true
	_check(not offered_broke, "No extension card when the cap cannot carry it")
	_check(not ClubLife.extension_wanted(star, {"extension|" + str(star["id"]): true}),
			"He asks once a season, not every week")
	GameState.salary_cap = 9999
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
	GameState.salary_cap = 9999
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
	_check(int(style["games"]) >= 3 and (style["win"] as Array).size() + (style["beaten"] as Array).size() > 0
			and (style["win"] as Array).size() <= 3 and (style["beaten"] as Array).size() <= 3,
			"After a few games, up to three lines each on how you win and get beaten (%s)" % str(style))
	var mine: Dictionary = GameState.season_team["GEE"]
	_check(mine.has("from_turnover") and mine.has("conceded_stoppage")
			and float(mine["from_turnover"]) + float(mine["from_stoppage"]) <= float(mine["for"]) + 0.01,
			"Where our points come from, both ways, is kept for the season")
	for line in (style["win"] as Array) + (style["beaten"] as Array):
		_check(str(line).contains("a game") and not str(line).contains("%"), "A style line is football words and a number: %s" % str(line))
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
