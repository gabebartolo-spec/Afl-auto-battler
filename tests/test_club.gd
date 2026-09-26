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
