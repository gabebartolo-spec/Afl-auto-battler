extends RefCounted
## Awards: 3-2-1 Brownlow votes per home-and-away match (none in finals),
## 5-4-3-2-1 best-and-fairest points per side, and a full season producing
## the Brownlow, Coleman, Rising Star, club B&Fs, a valid All-Australian 22,
## the honour roll and records - all surviving a save.
## Run through tests/run_awards_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_vote_arithmetic()
	_test_full_season()
	GameState.delete_saved_career()
	print("Awards tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _one_match() -> Dictionary:
	var home := Squad.new("H", GameDB.club_list("GEE"), true, "GEE")
	var away := Squad.new("A", GameDB.club_list("HAW"), false, "HAW")
	var res := MatchSim.new(home, away, 77).run()
	return res


func _sum(tally: Dictionary, key: String, club := "") -> int:
	var total := 0
	for id in tally:
		if club == "" or str(tally[id]["club"]) == club:
			total += int(tally[id][key])
	return total


func _test_vote_arithmetic() -> void:
	var res := _one_match()
	var tally := {}
	Awards.tally_match(tally, res, true)
	_check(_sum(tally, "votes") == 6, "A home-and-away match hands out 3-2-1 votes")
	_check(_sum(tally, "bf", "GEE") == 15 and _sum(tally, "bf", "HAW") == 15,
			"Each side hands out 5-4-3-2-1 best-and-fairest points")
	var finals := {}
	Awards.tally_match(finals, res, false)
	_check(_sum(finals, "votes") == 0 and _sum(finals, "goals_ha") == 0,
			"Finals give no Brownlow votes and no Coleman goals")
	_check(_sum(finals, "goals") > 0, "Finals goals still count in the season tally")


func _test_full_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	var aw: Dictionary = GameState.season_awards
	_check(int(aw.get("year", 0)) == 2026, "The season's awards are decided at the Grand Final")
	var brownlow: Array = aw.get("brownlow", [])
	_check(not brownlow.is_empty() and int(brownlow[0]["votes"]) >= 15,
			"A Brownlow medallist with a real tally (%d)" % (int(brownlow[0]["votes"]) if not brownlow.is_empty() else 0))
	var coleman: Array = aw.get("coleman", [])
	_check(not coleman.is_empty() and int(coleman[0]["goals"]) >= 30,
			"A Coleman medallist with a real tally (%d)" % (int(coleman[0]["goals"]) if not coleman.is_empty() else 0))
	var rising: Array = aw.get("rising_star", [])
	_check(not rising.is_empty() and float(rising[0]["age"]) <= Awards.RISING_STAR_AGE,
			"A Rising Star aged 21 or under")
	_check((aw.get("best_and_fairest", {}) as Dictionary).size() == GameDB.CLUB_ORDER.size(),
			"Every club has a best and fairest")
	var aa: Array = aw.get("all_australian", [])
	var slots := {}
	var ids := {}
	var games_ok := true
	for r in aa:
		slots[str(r["slot"])] = int(slots.get(str(r["slot"]), 0)) + 1
		ids[str(r["id"])] = true
		if int(r["games"]) < Awards.AA_MIN_GAMES:
			games_ok = false
	_check(aa.size() == 22 and ids.size() == 22, "The All-Australian team is 22 different players")
	_check(slots == {"RUCK": 1, "MID": 7, "DEF": 5, "FWD": 5, "BENCH": 4},
			"All-Australian is 1-7-5-5 plus 4 (%s)" % str(slots))
	_check(games_ok, "All-Australians played 12+ games")
	_check(GameState.honour_roll.size() == 1 and not GameState.records.is_empty(),
			"The honour roll and records are written")
	_check(GameState.award_name(brownlow[0]) != "", "Award winners have names")
	GameState.save_career()
	GameState.load_career()
	_check(int(GameState.season_awards.get("year", 0)) == 2026 and GameState.honour_roll.size() == 1,
			"Awards, honour roll and records survive a save")
	GameState.start_next_season()
	_check(GameState.season_tally.is_empty() and GameState.honour_roll.size() == 1,
			"A new season starts a fresh tally and keeps the honour roll")
