extends RefCounted
## Retired players becoming coaches (CoachPathway.gd, Coaching Phase 4): the
## snapshot taken at retirement, identity and names, the once-only interest
## roll, the pathway, skills that ignore playing ability, specialty, fading
## fame, the club link, entry to the ordinary market, archive, save/load.
## Run through tests/run_coach_pathway_tests.gd.

var failures: Array[String] = []
var checks := 0
const Y := 2040
const SEED := 777


func run() -> void:
	failures.clear()
	checks = 0
	_test_snapshot()
	_test_identity()
	_test_interest()
	_test_pathway_and_specialty()
	_test_skills_ignore_playing()
	_test_reputation()
	_test_market()
	_test_archive()
	_test_generated_and_expansion()
	_test_game_flow()
	GameState.delete_saved_career()
	print("Coach pathway tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## A retiring player, with the transient state a real one carries.
func _player(id: String, games: int, goals: int, role := "MID", ovr := 70) -> Dictionary:
	return {
		"id": id, "real_name": "", "generic_name": "Lachlan Mercer", "name": "Lachlan Mercer",
		"role": role, "own_role": role, "role2": "", "age": 34.0, "overall": ovr, "potential": ovr + 2,
		"attr": {"kicking": 70, "marking": 60}, "xp": 400, "morale": 0.4, "salary": 900,
		"contract_years": 1, "plan": "balanced", "injury": {"weeks": 2}, "history": [[2039, ovr]],
		"drafted_year": 2024, "drafted_type": "national", "drafted_pick": 31,
		"career": {"games": games, "goals": goals, "unknown": [], "through": Y,
				"stints": [["ADE", 2025, 2036, games - 40, goals - 10], ["FRE", 2037, Y, 40, 10]]},
	}


func _test_snapshot() -> void:
	var p := _player("P1", 263, 187)
	var roll := [{"year": 2030, "brownlow": [{"id": "P1"}], "coleman": [{"id": "X"}]},
			{"year": 2031, "brownlow": [], "coleman": [{"id": "P1"}]}]
	var s := CoachPathway.snapshot(p, Y, roll)
	_check(int(s["games"]) == 263 and int(s["goals"]) == 187, "Career games and goals are copied")
	_check((s["stints"] as Array).size() == 2 and str(s["stints"][0][0]) == "ADE" and int(s["stints"][1][3]) == 40,
			"Club stints are copied")
	_check(str(s["draft"]) == str([2024, 31, "national"]), "Draft year, pick and type are copied")
	_check(str(s["pos"]) == "MID" and int(s["retired"]) == Y, "Position and retirement year are kept")
	_check(int(s["honours"]["brownlow"]) == 1 and int(s["honours"]["coleman"]) == 1,
			"A Brownlow and a Coleman won in the save are kept")
	var leaked := false
	for k in ["attr", "overall", "potential", "xp", "morale", "salary", "contract_years", "plan",
			"injury", "history", "id", "age"]:
		if s.has(k):
			leaked = true
	_check(not leaked, "No ratings, contract, training, injury or stat history is kept")
	s["stints"][0][3] = 0
	_check(int(p["career"]["stints"][0][3]) == 223, "The snapshot is a copy, not the player's own record")
	_check(CoachPathway.draft_line(CoachPathway.snapshot(p, Y, [])) == "Pick 31, 2024 national draft",
			"The draft reads as football")
	var none := _player("P2", 12, 1)
	none.erase("drafted_year")
	_check(CoachPathway.draft_line(CoachPathway.snapshot(none, Y, [])) == "" \
			and not CoachPathway.snapshot(none, Y, []).has("honours"), "Unknown draft and no honours are left out")


func _test_identity() -> void:
	var p := _player("P1", 263, 187)
	p["real_name"] = "Rory Laird"
	var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
	_check(str(c["cid"]) == "C_P_P1" and str(c["former_player_id"]) == "P1", "Coach id C_P_<player id>, player id kept")
	_check(str(c["real_name"]) == "Rory Laird" and str(c["generic_name"]) == "Lachlan Mercer",
			"He keeps his real name and exactly his fictional name: no new alias")
	var real := GameState.show_real_names
	GameState.show_real_names = true
	var both_real := GameDB.player_display_name(c) == GameDB.player_display_name(p)
	GameState.show_real_names = false
	var both_fic := GameDB.player_display_name(c) == GameDB.player_display_name(p)
	GameState.show_real_names = real
	_check(both_real and both_fic, "Coach and player show the same name in either name mode")
	_check(not c.has("id") and not c.has("attr") and not c.has("role"), "The coach record is not a player record")
	_check(str(c["origin"]) == "player" and (c["stints"] as Array).is_empty(), "A new coach, no coaching history yet")


func _test_interest() -> void:
	var base := {"games": 40}
	_check(is_equal_approx(CoachPathway.interest_chance(base), 0.19), "Base interest 19%")
	_check(is_equal_approx(CoachPathway.interest_chance({"games": 160}), 0.22), "150+ games: 22%")
	_check(is_equal_approx(CoachPathway.interest_chance({"games": 260}), 0.25), "250+ games (a typical retiree here): 25%")
	_check(CoachPathway.interest_chance({"games": 300, "honours": {"brownlow": 3, "coleman": 4}}) <= 0.30 + 0.0001,
			"Capped at 30%")
	var same := true
	var yes := 0
	for i in range(2000):
		var pl := {"games": 260}
		var a := CoachPathway.interested("R%d" % i, pl, SEED)
		if a != CoachPathway.interested("R%d" % i, pl, SEED):
			same = false
		if a:
			yes += 1
	_check(same, "The interest roll is deterministic: reloading never rerolls it")
	_check(yes > 440 and yes < 560, "About one veteran retiree in four goes into coaching (%d of 2000)" % yes)


func _test_pathway_and_specialty() -> void:
	var gaps := {}
	var dev := 0
	var line_ok := true
	var n := 1000
	for i in range(n):
		var role: String = ["MID", "RUCK", "FWD", "DEF"][i % 4]
		var p := _player("S%d" % i, 120, 30, role)
		var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
		var gap := int(c["free_from"]) - Y - 1
		gaps[gap] = true
		if str(c["spec"]) == "DEV":
			dev += 1
		elif str(c["spec"]) != role:
			line_ok = false
		var again := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
		if int(again["free_from"]) != int(c["free_from"]) or str(again["spec"]) != str(c["spec"]):
			line_ok = false
	_check(gaps.keys().size() == 3 and gaps.has(1) and gaps.has(3), "One to three seasons in the pathway, deterministic")
	_check(line_ok, "His specialty is his playing line (a ruckman coaches rucks)")
	_check(dev > 170 and dev < 270, "About one in five start as development coaches (%d of %d)" % [dev, n])
	var p := _player("W1", 120, 30)
	var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
	_check(str(c["status"]) == "out" and CoachPathway.in_pathway(c) and str(c["note"]) != "",
			"He starts out of sight in the pathways")


## Fame is not coaching ability: skills come from the coach id alone.
func _test_skills_ignore_playing() -> void:
	var a := _player("K1", 320, 400, "FWD", 92)
	var b := _player("K1", 15, 0, "FWD", 41)
	var ca := CoachPathway.make_coach(a, CoachPathway.snapshot(a, Y, [{"brownlow": [{"id": "K1"}]}]), Y, SEED)
	var cb := CoachPathway.make_coach(b, CoachPathway.snapshot(b, Y, []), Y, SEED)
	_check(str(ca["skills"]) == str(cb["skills"]), "A champion and a battler with the same id start with the same skills")
	var gs := []
	var sk := []
	var rep := []
	var lo := 99
	var hi := 0
	for i in range(3000):
		var games := (i * 37) % 360
		var p := _player("Q%d" % i, games + 40, games / 3, "MID", 40 + (i * 13) % 55)
		var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
		var mean := 0.0
		for k in Coaches.SKILLS:
			mean += float(c["skills"][k]) / 3.0
			lo = mini(lo, int(c["skills"][k]))
			hi = maxi(hi, int(c["skills"][k]))
		gs.append(float(games))
		sk.append(mean)
		rep.append(float(c["rep"]))
	var r_skill := _corr(gs, sk)
	var r_rep := _corr(gs, rep)
	_check(absf(r_skill) < 0.05, "Playing games and coaching skill do not correlate (r = %.3f)" % r_skill)
	_check(r_rep > 0.5, "Playing games do lift starting reputation (r = %.2f)" % r_rep)
	_check(lo >= 55 and hi <= 72, "Starting skills stay in 55-72 (%d-%d)" % [lo, hi])


func _corr(x: Array, y: Array) -> float:
	var n := float(x.size())
	var mx := 0.0
	var my := 0.0
	for i in range(x.size()):
		mx += float(x[i]) / n
		my += float(y[i]) / n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(x.size()):
		sxy += (float(x[i]) - mx) * (float(y[i]) - my)
		sxx += pow(float(x[i]) - mx, 2)
		syy += pow(float(y[i]) - my, 2)
	return sxy / sqrt(maxf(1e-9, sxx * syy))


func _test_reputation() -> void:
	var star := _player("F1", 330, 200)
	var battler := _player("F2", 20, 2)
	var cs := CoachPathway.make_coach(star, CoachPathway.snapshot(star, Y, []), Y, SEED)
	var cb := CoachPathway.make_coach(battler, CoachPathway.snapshot(battler, Y, []), Y, SEED)
	_check(int(cs["rep"]) > int(cb["rep"]) + 8, "A long career starts with a bigger name (%d v %d)" % [int(cs["rep"]), int(cb["rep"])])
	_check(int(cs["rep"]) < 55, "But no new coach starts as a big name (%d)" % int(cs["rep"]))
	# The same coach twice, one with a playing name: after years coaching the
	# name has washed out of his reputation.
	var a := cs.duplicate(true)
	var b := cs.duplicate(true)
	b["fame"] = 0
	b["fame_left"] = 0
	b["rep"] = int(a["rep"]) - int(a["fame"])
	for c in [a, b]:
		c["status"] = "club"
		c["club"] = "CAR"
		c["job"] = "DEV"
	var coaches := {"A": a, "B": b}
	var gap0 := int(a["rep"]) - int(b["rep"])
	for yr in range(Y + 1, Y + 1 + CoachPathway.FAME_FADE_YEARS):
		CoachMarket._reputation(coaches, {}, "", yr)
	_check(gap0 > 0 and int(a["rep"]) == int(b["rep"]) and int(a["fame_left"]) == 0,
			"His playing name fades over his first %d seasons coaching" % CoachPathway.FAME_FADE_YEARS)
	var waiting := CoachPathway.make_coach(battler, CoachPathway.snapshot(battler, Y, []), Y, SEED)
	var r0 := int(waiting["rep"])
	CoachMarket._reputation({"W": waiting}, {}, "", Y + 1)
	_check(int(waiting["rep"]) == r0, "Nothing is judged while he is in the pathways")


func _test_market() -> void:
	var p := _player("M1", 180, 60, "FWD")
	var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y, []), Y, SEED)
	c["status"] = "free"
	var other := c.duplicate(true)
	other["played"] = {}
	var at_ade := CoachMarket.hire_score(c, "ADE", "FWD", Y, SEED) - CoachMarket.hire_score(other, "ADE", "FWD", Y, SEED)
	var at_car := CoachMarket.hire_score(c, "CAR", "FWD", Y, SEED) - CoachMarket.hire_score(other, "CAR", "FWD", Y, SEED)
	_check(at_ade > 0.0 and at_ade <= 0.03 and is_zero_approx(at_car),
			"A former Adelaide player has a small edge at Adelaide only (+%.3f)" % at_ade)
	# The pathway ends: an ordinary available coach from this offseason.
	var q := _player("M2", 200, 90, "DEF")
	var ex := CoachPathway.make_coach(q, CoachPathway.snapshot(q, Y - 2, []), Y - 2, SEED)
	ex["free_from"] = Y + 1
	var coaches := Coaches.seed("GEE")
	coaches[str(ex["cid"])] = ex
	var out := CoachMarket.offseason({"coaches": coaches, "archive": {}, "year": Y, "my_club": "GEE",
			"clubs": GameDB.active_clubs(Y + 1), "results": {}, "premier": "", "seed": SEED})
	var now: Dictionary = coaches.get(str(ex["cid"]), {})
	_check(not now.is_empty() and str(now["status"]) in ["free", "club"], "When his pathway ends he joins the market")
	_check(int(out["log"].get("ex_players_in", 0)) >= 1, "The offseason counts him in")
	var said := false
	for t in out["news"]:
		if "joined the coaching ranks" in str(t) or "who played" in str(t):
			said = true
	_check(said, "A 200-game former player joining the coaching ranks is news")
	# Still in the pathway: not hireable yet.
	var early := CoachPathway.make_coach(q, CoachPathway.snapshot(q, Y, []), Y, SEED)
	_check(not CoachMarket.would_take(early, "CAR", "DEV", Y), "Not hireable while in the pathways")
	# An overloaded market: he waits a season more, never lost.
	var w := CoachPathway.make_coach(q, CoachPathway.snapshot(q, Y, []), Y, SEED)
	var ff := int(w["free_from"])
	_check(not CoachPathway.enter_market(w, Y, 99, 52) and int(w["free_from"]) == ff + 1 and CoachPathway.in_pathway(w),
			"A flooded market keeps him in the pathways a season longer")
	for i in range(CoachPathway.MAX_WAIT):
		CoachPathway.enter_market(w, Y, 99, 52)
	_check(str(w["status"]) == "free", "But never more than %d extra seasons" % CoachPathway.MAX_WAIT)


func _test_archive() -> void:
	var p := _player("A1", 90, 20)
	var c := CoachPathway.make_coach(p, CoachPathway.snapshot(p, Y - 10, []), Y - 10, SEED)
	c["status"] = "retired"
	c["stints"] = [["CAR", "DEV", Y - 7, Y - 5], ["CAR", "FWD", Y - 4, Y]]
	var q := _player("A2", 40, 3)
	var brief := CoachPathway.make_coach(q, CoachPathway.snapshot(q, Y - 3, []), Y - 3, SEED)
	brief["status"] = "retired"
	brief["stints"] = [["CAR", "DEV", Y - 1, Y]]
	var coaches := {str(c["cid"]): c, str(brief["cid"]): brief}
	var archive := {}
	CoachMarket._prune(coaches, archive, Y, "GEE", {"archived": 0, "pruned": 0})
	_check(archive.has(str(c["cid"])) and int(archive[str(c["cid"])]["played"]["games"]) == 90,
			"A former player who coached for years is archived with his playing career")
	_check(not archive.has(str(brief["cid"])), "A two-season coach with a short playing career is not kept forever")
	var mine := CoachPathway.make_coach(q, CoachPathway.snapshot(q, Y - 3, []), Y - 3, SEED)
	mine["status"] = "retired"
	mine["played"]["stints"] = [["GEE", 2030, 2036, 120, 30]]
	var arch2 := {}
	CoachMarket._prune({"X": mine}, arch2, Y, "GEE", {"archived": 0, "pruned": 0})
	_check(arch2.has("X"), "One of your own long-serving players is always kept")


func _test_generated_and_expansion() -> void:
	var gen: Array = Prospects.generate_class(2031, SEED)
	var g: Dictionary = gen[0]
	Career.add_season(g, 2032, "CAR", 20, 12)
	var cg := CoachPathway.make_coach(g, CoachPathway.snapshot(g, 2040, []), 2040, SEED)
	_check(str(cg["generic_name"]) == str(g.get("generic_name", g.get("name", ""))) and str(cg["real_name"]) == "",
			"A generated player coaches under the name he played under")
	var tas: Array = Prospects.generate_expansion_list("TAS", 2028)
	var t: Dictionary = tas[0]
	Career.add_season(t, 2028, "TAS", 22, 5)
	var ct := CoachPathway.make_coach(t, CoachPathway.snapshot(t, 2038, []), 2038, SEED)
	_check(str(ct["cid"]) == "C_P_" + str(t["id"]) and CoachPathway.played_for(ct["played"], "TAS"),
			"An expansion player goes through the same pathway")


func _test_game_flow() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.season.round_index = GameState.season.fixture.size()
	# One veteran whose seeded roll says he will coach: he retires this offseason.
	var pick := {}
	for code in GameState.season.lists:
		if code == "GEE":
			continue
		for p in GameState.season.lists[code]:
			var pl := CoachPathway.snapshot(p, GameState.season_year, [])
			if int(pl["games"]) >= 100 and CoachPathway.interested(str(p["id"]), pl, GameState.career_seed):
				pick = p
				break
		if not pick.is_empty():
			break
	_check(not pick.is_empty(), "A retiree who will coach exists")
	if pick.is_empty():
		return
	pick["age"] = 37.0
	var pid := str(pick["id"])
	var name := GameDB.player_display_name(pick)
	var games := int(Career.of(pick)["games"])
	_check(GameState.start_next_season(), "The season rolls over")
	var still_listed := false
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if str(p["id"]) == pid:
				still_listed = true
	var cid := CoachPathway.cid_for(pid)
	_check(not still_listed, "He has left the lists")
	_check(GameState.coaches.has(cid), "Captured as a coach at the moment he retired")
	if not GameState.coaches.has(cid):
		return
	var c: Dictionary = GameState.coaches[cid]
	_check(GameDB.player_display_name(c) == name and int(c["played"]["games"]) == games,
			"Same person, same name, same career games")
	var n := GameState.coaches.size()
	GameState._career_over(pick)
	_check(GameState.coaches.size() == n, "One former player never becomes two coaches")
	_check(GameState.save_career() and GameState.load_career(), "The career saves and loads")
	var back: Dictionary = GameState.coaches.get(cid, {})
	_check(not back.is_empty() and int(back["played"]["games"]) == games \
			and str(back["played"]["stints"]) == str(c["played"]["stints"]) and str(back["status"]) == "out",
			"His playing snapshot and pathway survive a reload")
	_check(not back.has("id") and not back.has("attr"), "He loads as a coach, not a player")
	var lines := CoachSheet.playing_lines(back["played"])
	_check(not lines.is_empty(), "His profile has a playing career (%s)" % str(lines))
