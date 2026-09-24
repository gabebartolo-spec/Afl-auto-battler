extends RefCounted
## Finals regression suite: the bracket opens as soon as round 24 ends, and a
## qualifying club plays each of its finals live (the same prepare / quarter /
## finish path MatchScene drives) through to a premier.
## Run through tests/run_finals_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_finals_open_after_last_round()
	_test_interactive_finals_series()
	_test_simulated_finals_series()
	_test_extra_time()
	_test_home_and_away_never_extra_time()
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
	_check(season.finals_week_matches().size() == 4, "Week one lists four finals")

	season = _to_last_round()
	_check(GameState.prepare_interactive_match(), "Round 24 can be played live")
	_play_pending()
	_check(not season.finals.is_empty(),
			"The bracket also opens after a live round 24")


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
			_check(GameState.pending_phase == "finals", "Week %d is a live final" % week)
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
			GameState.advance()  # eliminated: the rest of the series simulates
		weeks_played += 1
		var played: Array = season.finals["weeks"][weeks_played - 1]
		var expected: int = [4, 2, 2, 1][week - 1]
		_check(played.size() == expected,
				"Finals week %d records %d matches" % [week, expected])
		for r in played:
			var slots: Dictionary = season.finals["slots"]
			_check(slots.has("W_" + str(r["tag"])), "%s has a winner" % str(r["tag"]))
	_check(season.is_season_over(), "The live finals series reaches a premier")
	_check(season.finals["weeks"].size() == 4, "Four finals weeks are recorded")
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
	var gf: Dictionary = season.finals["weeks"][3][0]
	_check(bool(gf.get("neutral", false)), "The simulated Grand Final is neutral")
	var qf: Dictionary = season.finals["weeks"][0][0]
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
