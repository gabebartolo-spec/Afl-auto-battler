extends RefCounted
## Finals regression suite: the wildcard bracket opens as soon as round 24
## ends (10 finalists), week one is the two wildcard finals, the winners
## reseed by original ladder position, and a live club plays each of its
## finals (the same prepare / quarter / finish path MatchScene drives)
## through to a premier.
## Run through tests/run_finals_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_finals_open_after_last_round()
	_test_wildcard_week_and_reseed()
	_test_interactive_finals_series()
	_test_simulated_finals_series()
	_test_extra_time()
	_test_home_and_away_never_extra_time()
	_test_grand_final_neutral()
	_test_ladder_result_word()
	print("Finals tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Fast-forward to the last home-and-away round and play it.
func _to_last_round() -> Season:
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	var season: Season = GameState.season
	season.round_index = season.fixture.size() - 1
	return season


## Play the prepared match the way MatchScene does: quarter by quarter, with
## the home/away/label stamped on the result, then hand it back.
func _play_pending() -> Dictionary:
	var sim: MatchSim = GameState.pending_sim
	var res := {}
	while sim.current_quarter <= 4:
		res = sim.run_quarter()
	res["home"] = GameState.pending_match["home"]
	res["away"] = GameState.pending_match["away"]
	res["label"] = GameState.pending_match["label"]
	GameState.finish_interactive_match(res)
	return res


func _test_finals_open_after_last_round() -> void:
	var season := _to_last_round()
	GameState.advance()
	_check(season.is_regular_done(), "Round 24 completes the home-and-away")
	_check(not season.finals.is_empty(),
			"The finals bracket opens as soon as round 24 is played")
	var top: Array = season.finals["top"]
	_check(top.size() == Season.FINALISTS,
			"Ten clubs make the finals (top %d)" % Season.FINALISTS)
	_check(season.finals_week_matches().size() == 2,
			"Week one lists the two wildcard finals")

	season = _to_last_round()
	_check(GameState.prepare_interactive_match(), "Round 24 can be played live")
	_play_pending()
	_check(not season.finals.is_empty(),
			"The bracket also opens after a live round 24")


## Week one is 7v10 and 8v9; the winners reseed by their original ladder
## position into the 7th and 8th seeds for week two.
func _test_wildcard_week_and_reseed() -> void:
	var season := _to_last_round()
	GameState.advance()
	var top: Array = season.finals["top"]

	# The top six wait out the wildcard round: none of them plays in week one.
	for m in season.finals_week_matches():
		var codes := [str(m["home"]), str(m["away"])]
		for i in range(6):
			_check(not codes.has(str(top[i])),
					"Seed %d has a week-one bye" % (i + 1))

	var by_tag := {}
	for m in season.finals_week_matches():
		by_tag[str(m["tag"])] = m
	_check(by_tag.has("WC1") and by_tag.has("WC2"), "Week one tags are WC1 and WC2")
	_check(str(by_tag["WC1"]["home"]) == str(top[6]) and str(by_tag["WC1"]["away"]) == str(top[9]),
			"WC1 is 7v10, higher seed hosting")
	_check(str(by_tag["WC2"]["home"]) == str(top[7]) and str(by_tag["WC2"]["away"]) == str(top[8]),
			"WC2 is 8v9, higher seed hosting")

	GameState.advance()  # play the wildcard round
	var s: Dictionary = season.finals["slots"]
	_check(str(s.get("W_WC1", "")) == str(top[6]) or str(s.get("W_WC1", "")) == str(top[9]),
			"WC1 has a winner")
	_check(str(s.get("W_WC2", "")) == str(top[7]) or str(s.get("W_WC2", "")) == str(top[8]),
			"WC2 has a winner")

	# Week two: 1-4 play the qualifying finals, the wildcard winners take the
	# 7th and 8th seeds - the winner of 7v10 is the 7th seed (EF2), the
	# winner of 8v9 the 8th (EF1).
	var week2 := {}
	for m in season.finals_week_matches():
		week2[str(m["tag"])] = m
	_check(week2.has("QF1") and week2.has("QF2") and week2.has("EF1") and week2.has("EF2"),
			"Week two is two qualifying and two elimination finals")
	_check(str(week2["QF1"]["home"]) == str(top[0]) and str(week2["QF1"]["away"]) == str(top[3]),
			"QF1 is 1v4")
	_check(str(week2["QF2"]["home"]) == str(top[1]) and str(week2["QF2"]["away"]) == str(top[2]),
			"QF2 is 2v3")
	_check(str(week2["EF1"]["home"]) == str(top[4]) and str(week2["EF1"]["away"]) == str(s["W_WC2"]),
			"EF1 is 5th v the WC2 winner (the 8th seed)")
	_check(str(week2["EF2"]["home"]) == str(top[5]) and str(week2["EF2"]["away"]) == str(s["W_WC1"]),
			"EF2 is 6th v the WC1 winner (the 7th seed)")


func _test_interactive_finals_series() -> void:
	var season := _to_last_round()
	GameState.advance()
	var top: Array = season.finals["top"]
	GameState.my_club = str(top[0])
	GameState.my_list = season.lists[GameState.my_club]

	var weeks_played := 0
	var guard := 0
	while not season.is_season_over() and guard < 8:
		guard += 1
		var week := int(season.finals["week"])
		var status := GameState.my_finals_status()
		_check(status in ["alive", "bye", "eliminated"],
				"Finals status is known in week %d (%s)" % [week, status])
		_check(GameState.prepare_interactive_match() == (status == "alive") \
				or GameState.pending_phase == "finals",
				"Only an alive club gets a live final")
		if GameState.pending_phase == "finals":
			_check(season.finals["weeks"].size() == weeks_played,
					"Nothing is recorded while the final is being coached")
			var res := _play_pending()
			_check(str(res.get("tag", "")) != "", "Your final carries its bracket tag")
			_check(bool(res.get("neutral", true)) == (str(res.get("tag", "")) == "GF"),
					"Only the Grand Final is at a neutral venue")
			_check(GameState.last_match == res, "Your final is the match of the week")
			_check(GameState.pending_match.is_empty(), "The pending match clears")
			_check(GameState.finals_outcome_line(res) != "",
					"Every final gets an outcome line (%s)" % str(res["tag"]))
			if str(res["tag"]).begins_with("QF"):
				var next := GameState.my_finals_status()
				_check(next == "bye" or next == "alive",
						"A qualifying final never knocks you out")
		else:
			GameState.advance()  # bye week or eliminated: the series simulates
		weeks_played += 1
		var played: Array = season.finals["weeks"][weeks_played - 1]
		var expected: int = [2, 4, 2, 2, 1][week - 1]
		_check(played.size() == expected,
				"Finals week %d records %d matches" % [week, expected])
		for r in played:
			var slots: Dictionary = season.finals["slots"]
			_check(slots.has("W_" + str(r["tag"])), "%s has a winner" % str(r["tag"]))
	_check(season.is_season_over(), "The live finals series reaches a premier")
	_check(season.finals["weeks"].size() == 5, "Five finals weeks are recorded")
	_check(GameState.premier() != "", "A premier is crowned")
	_check(GameState.my_finals_status() in ["premier", "runner_up", "eliminated"],
			"A finished series gives a final status")
	_check(GameState.last_phase == "done" or GameState.last_phase == "finals",
			"The last finals week reports its phase")


func _test_simulated_finals_series() -> void:
	var season := _to_last_round()
	GameState.advance()
	var guard := 0
	while not season.is_season_over() and guard < 8:
		GameState.advance()
		guard += 1
	_check(season.is_season_over(), "Simming the finals still crowns a premier")
	_check(GameState.last_phase == "done", "The Grand Final week reports done")
	_check(season.finals["weeks"].size() == 5, "Five weeks on the bracket")
	var gf: Dictionary = season.finals["weeks"][4][0]
	_check(bool(gf.get("neutral", false)), "The simulated Grand Final is neutral")
	var wc: Dictionary = season.finals["weeks"][0][0]
	_check(not bool(wc.get("neutral", true)), "The higher seed hosts a wildcard final")
	var qf: Dictionary = season.finals["weeks"][1][0]
	_check(not bool(qf.get("neutral", true)), "The higher seed hosts a qualifying final")


func _new_sim(seed: int) -> MatchSim:
	var home := Squad.new("Home", GameDB.club_list("GEE"), true, "GEE")
	var away := Squad.new("Away", GameDB.club_list("HAW"), false, "HAW")
	return MatchSim.new(home, away, seed)


## Find a real level final and check extra time settles it.
func _test_extra_time() -> void:
	var found := {}
	# Finals play a little differently (big-game players lift), so look for
	# a final that was level at the end of the fourth quarter.
	for seed in range(1, 1500):
		var sim := _new_sim(seed)
		sim.finals_mode = true
		var res := sim.run()
		if bool(res["extra_time"]):
			found = res
			break
	_check(not found.is_empty(), "A level final turns up within 1,500 seeds")
	if found.is_empty():
		return
	var q4: Array = ((found["quarter_teams"] as Array)[3] as Dictionary)["score"]
	_check(int(q4[0]) == int(q4[1]) and bool(found["extra_time"]),
			"A level final goes to extra time")
	_check((found["q_goals"] as Array).size() == 5, "Extra time gets its own period")
	var events: Array = found["events"]
	var finals := 0
	for ev in events:
		if str(ev["kind"]) == "final":
			finals += 1
	_check(finals == 1, "Only one full-time siren, after extra time")
	_check(str((events[events.size() - 1] as Dictionary)["kind"]) == "final",
			"The siren is the last event")
	_check(int(found["score"][0]) != int(found["score"][1]),
			"Extra time (or the next score) breaks the tie")
	var ev_q5 := 0
	for ev in events:
		if int(ev["q"]) == 5:
			ev_q5 += 1
	_check(ev_q5 > 0, "Extra-time events are stamped as period 5")


## Regular matches never go to extra time and keep four periods.
func _test_home_and_away_never_extra_time() -> void:
	for seed in range(1, 1500):
		var sim := _new_sim(seed)
		var res := sim.run()
		if int(res["score"][0]) == int(res["score"][1]):
			_check(not bool(res["extra_time"]), "A home-and-away draw stays a draw")
			_check((res["q_goals"] as Array).size() == 4, "Draws keep four quarters")
			return


## The Grand Final is at a neutral venue: the side in the home slot gets no
## home-ground edge. An ordinary home side, and the higher seed hosting every
## other final, keep it. (Tests the engine's input, not random scores.)
func _test_grand_final_neutral() -> void:
	var bonus := float(Ratings.T["home_ground_bonus"])
	var ordinary := _new_sim(3)
	_check(bonus > 0.0 and ordinary.squads[0].home and is_equal_approx(ordinary.home_edge(), bonus),
			"An ordinary home side has the home-ground edge")
	# The stoppage odds really use it: the same seed draws the same numbers,
	# so the home side can only win more stoppages than a neutral one.
	var at_home := _new_sim(11)
	var neutral := MatchSim.new(Squad.new("Home", GameDB.club_list("GEE"), false, "GEE"),
			Squad.new("Away", GameDB.club_list("HAW"), false, "HAW"), 11)
	var won := [0, 0]
	for i in range(400):
		won[0] += 1 if at_home.contest_winner(false, 0.0) == 0 else 0
		won[1] += 1 if neutral.contest_winner(false, 0.0) == 0 else 0
	_check(neutral.home_edge() == 0.0 and int(won[0]) > int(won[1]),
			"At a neutral venue the home slot wins fewer stoppages (%d v %d of 400)" % [won[1], won[0]])
	var season := _to_last_round()
	GameState.advance()
	# Each finals week, coach that week's first final live (the same prepare
	# path MatchScene uses) and read the engine's home edge for it.
	var edges := {}
	var guard := 0
	while not season.is_season_over() and guard < 8:
		guard += 1
		var m: Dictionary = season.finals_week_matches()[0]
		GameState.my_club = str(m["home"])
		GameState.my_list = season.lists[GameState.my_club]
		if not GameState.prepare_interactive_match():
			break
		var sim: MatchSim = GameState.pending_sim
		edges[str(GameState.pending_match["tag"])] = [sim.home_edge(), sim.squads[0].home,
				bool(GameState.pending_match["neutral"])]
		_play_pending()
	_check(edges.has("GF"), "The Grand Final was coached live")
	var gf: Array = edges.get("GF", [1.0, true, false])
	_check(float(gf[0]) == 0.0 and not bool(gf[1]) and bool(gf[2]),
			"The Grand Final gives the home-slot side no home-ground edge")
	var hosted := edges.size() > 1
	for tag in edges:
		if str(tag) == "GF":
			continue
		var e: Array = edges[tag]
		if not (is_equal_approx(float(e[0]), bonus) and bool(e[1]) and not bool(e[2])):
			hosted = false
	_check(hosted, "The higher seed still hosts every other final (%s)" % str(edges.keys()))


## The ladder's finals rows put the home side first; the word between the
## scores says who won (it read "d." even when the away side won).
func _test_ladder_result_word() -> void:
	var ladder = load("res://scripts/ui/LadderScene.gd")
	_check(ladder.result_word({"score": [80, 62]}) == "d.", "A home win reads 'd.'")
	_check(ladder.result_word({"score": [62, 80]}) == "lost to", "An away win reads 'lost to'")
	_check(ladder.result_word({"score": [70, 70]}) == "drew with",
			"A level final reads 'drew with'")
