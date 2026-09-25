extends RefCounted
## Expansion suite: Tasmania enters in 2028 and Canberra in 2030. Each club
## is inactive before its entry year (no fixtures, ladder, draft or selection
## presence) and a normal active club from it - including odd-club fixtures,
## the generated debut list, season transitions and saves.
## Run through tests/run_expansion_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_entry_gates()
	_test_2026_baseline()
	_test_rollover_to_2028()
	_test_2028_season_runs()
	_test_rollover_to_2030()
	_test_save_load_across_expansion()
	GameState.reset()
	GameState.delete_saved_career()
	print("Expansion tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


# ---------------------------------------------------------------------------
# Entry years
# ---------------------------------------------------------------------------
func _test_entry_gates() -> void:
	_check(GameDB.enter_year("GEE") == 2026, "Founding clubs enter in 2026")
	_check(GameDB.enter_year("TAS") == 2028, "Tasmania's entry year is 2028")
	_check(GameDB.enter_year("CANB") == 2030, "Canberra's entry year is 2030")

	_check(GameDB.active_clubs(2026).size() == 18, "Eighteen clubs in 2026")
	_check(not GameDB.active_clubs(2026).has("TAS")
			and not GameDB.active_clubs(2026).has("CANB"),
			"Neither expansion club is active in 2026")
	_check(GameDB.active_clubs(2027).size() == 18, "Eighteen clubs in 2027")
	_check(not GameDB.active_clubs(2027).has("TAS"), "Tasmania is not active in 2027")
	_check(GameDB.active_clubs(2028).has("TAS")
			and GameDB.active_clubs(2028).size() == 19,
			"Nineteen clubs from 2028, Tasmania included")
	_check(not GameDB.active_clubs(2028).has("CANB"), "Canberra is not active in 2028")
	_check(not GameDB.active_clubs(2029).has("CANB"), "Canberra is not active in 2029")
	_check(GameDB.active_clubs(2030).has("CANB")
			and GameDB.active_clubs(2030).size() == 20,
			"Twenty clubs from 2030, Canberra included")
	_check(GameDB.active_clubs(2035).size() == 20, "The twenty-club league holds")

	# The club records carry real data for the new clubs.
	for code in ["TAS", "CANB"]:
		var c: Dictionary = GameDB.club(code)
		_check(str(c.get("name", "")) != "" and str(c.get("ground", "")) != "",
				"%s has a name and a ground" % code)
		_check((GameDB.club_list(code) as Array).is_empty(),
				"%s has no 2026 players (its list is generated at entry)" % code)

	# The new career's draft and club selection only see 2026's active clubs.
	GameState.reset()
	GameState.begin_draft()
	_check(GameState.draft.clubs.size() == 18
			and not GameState.draft.clubs.has("TAS")
			and not GameState.draft.clubs.has("CANB"),
			"The 2026 career draft runs the founding eighteen only")
	GameState.reset()


# ---------------------------------------------------------------------------
# A career through the expansion
# ---------------------------------------------------------------------------
func _new_2026_season() -> Season:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	return GameState.season


func _test_2026_baseline() -> void:
	var season := _new_2026_season()
	_check(season.ladder.size() == 18, "The 2026 ladder has eighteen clubs")
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2026")
	for r in season.fixture:
		_check((r as Array).size() == 9, "Eighteen clubs play nine matches a round")


## Finish the current season's intake draft the same way a career would.
func _rollover() -> void:
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	_check(GameState.begin_intake_draft(), "The intake draft opens after the season")
	var draft: Draft = GameState.draft
	var guard := 0
	while not draft.is_finished() and guard < 600:
		guard += 1
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.is_finished(), "The intake draft completes")
	_check(GameState.finish_intake_draft(), "The rollover commits")


func _test_rollover_to_2028() -> void:
	# 2026 -> 2027: nothing changes.
	_rollover()
	_check(GameState.season_year == 2027, "The career advances to 2027")
	_check(GameState.season.ladder.size() == 18, "2027 still has eighteen clubs")
	_check(GameState.season.fixture.size() == Season.REGULAR_ROUNDS,
			"2027 keeps a 24-round fixture")

	# 2027 -> 2028: Tasmania arrives.
	_rollover()
	_check(GameState.season_year == 2028, "The career advances to 2028")
	var season: Season = GameState.season
	_check(season.ladder.size() == 19, "Nineteen clubs on the 2028 ladder")
	_check(season.ladder.has("TAS"), "Tasmania is on the 2028 ladder")
	_check(not season.ladder.has("CANB"), "Canberra is not yet on the ladder")

	# The debut list: a full squad, in the right size band, with contracts
	# ready when the season opens.
	var tas: Array = season.lists["TAS"]
	_check(tas.size() >= Prospects.MIN_LIST and tas.size() <= Ratings.LIST_SIZE,
			"Tasmania debuts with a full list (%d)" % tas.size())
	var ages := 0.0
	var id_seen := {}
	for p in tas:
		ages += float(p["age"])
		_check(not id_seen.has(str(p["id"])), "Tasmania ids are unique")
		id_seen[str(p["id"])] = true
		_check(bool(p.get("contract_years", 0)) > 0,
				"Every Tasmanian has a contract at the season start")
	_check(ages / float(tas.size()) > 19.0 and ages / float(tas.size()) < 27.0,
			"The debut list mixes ages (%.1f)" % (ages / float(tas.size())))

	# The odd-club fixture: 24 rounds, a bye rotating so every club plays
	# 22 or 23 games, and every pair meets at least once.
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2028")
	var games := {}
	var pairs := {}
	for r in season.fixture:
		var round: Array = r
		_check(round.size() == 9 or round.size() == 10,
				"A 2028 round has nine or ten matches (%d)" % round.size())
		for m in round:
			var a := str(m["home"])
			var b := str(m["away"])
			_check(a != "BYE" and b != "BYE", "The virtual bye never appears on the fixture")
			games[a] = int(games.get(a, 0)) + 1
			games[b] = int(games.get(b, 0)) + 1
			var key := a + "|" + b if a < b else b + "|" + a
			pairs[key] = int(pairs.get(key, 0)) + 1
	_check(pairs.size() == 171, "Every pair of the 19 clubs meets at least once")
	for code in season.ladder:
		var n: int = games.get(code, 0)
		_check(n == 22 or n == 23,
				"%s plays 22 or 23 games in 2028 (%d)" % [code, n])


func _test_2028_season_runs() -> void:
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	var season: Season = GameState.season
	_check(season.is_season_over(), "The 19-club 2028 season runs to a premier")
	_check(season.finals["top"].size() == Season.FINALISTS,
			"Ten finalists come off the 19-club ladder")
	_check(GameState.premier() != "", "A 2028 premier is crowned")

	# The expansion news and the debut achievement only fire when they apply.
	var news_ok := false
	for item in GameState.news:
		if str(item["kind"]) == "expansion" and str(item["text"]).contains("Tasmania"):
			news_ok = true
	_check(news_ok, "Tasmania's entry made the news")
	if (season.finals["top"] as Array).has("TAS"):
		_check(GameState.achievements.has("tas_debut_finals"),
				"Tasmania made the finals in its debut season: achievement unlocked")
	var stored: Dictionary = GameState.achievements.get("tas_debut_finals", {})
	var debut_year: Variant = stored.get("year", "")
	_check(debut_year == "" or int(debut_year) == 2028,
			"The debut achievement, when unlocked, is stamped 2028")

	# 2028 -> 2029: Tasmania stays, the league ages on.
	_rollover()
	_check(GameState.season_year == 2029, "The career advances to 2029")
	var again: Array = GameState.season.lists["TAS"]
	_check(again.size() >= Prospects.MIN_LIST, "Tasmania keeps a full list into 2029")


func _test_rollover_to_2030() -> void:
	_rollover()
	_check(GameState.season_year == 2030, "The career advances to 2030")
	var season: Season = GameState.season
	_check(season.ladder.size() == 20, "Twenty clubs on the 2030 ladder")
	_check(season.ladder.has("CANB") and season.ladder.has("TAS"),
			"Both expansion clubs are on the 2030 ladder")
	var canb: Array = season.lists["CANB"]
	_check(canb.size() >= Prospects.MIN_LIST and canb.size() <= Ratings.LIST_SIZE,
			"Canberra debuts with a full list (%d)" % canb.size())
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2030")
	for r in season.fixture:
		_check((r as Array).size() == 10, "Twenty even clubs play ten a round")
		break
	# The league's lists never share a player and every club stays in band.
	var seen := {}
	for code in season.ladder:
		var arr: Array = season.lists[code]
		_check(arr.size() >= Prospects.MIN_LIST and arr.size() <= Ratings.LIST_SIZE,
				"%s stays in the list band in 2030 (%d)" % [code, arr.size()])
		for p in arr:
			_check(not seen.has(str(p["id"])), "No player on two lists (%s)" % str(p["id"]))
			seen[str(p["id"])] = true


func _test_save_load_across_expansion() -> void:
	var season: Season = GameState.season
	_check(GameState.save_career(), "A 2030 career saves")
	var canb_before: int = (season.lists["CANB"] as Array).size()
	GameState.load_career()
	_check(GameState.season_year == 2030, "The loaded career is still in 2030")
	_check(GameState.season.ladder.size() == 20, "The loaded ladder has twenty clubs")
	_check(GameState.season.ladder.has("CANB") and GameState.season.ladder.has("TAS"),
			"The loaded ladder keeps both expansion clubs")
	_check((GameState.season.lists["CANB"] as Array).size() == canb_before,
			"Canberra's list survives the round trip")
	_check(not GameState.season.finals.is_empty()
			or not GameState.season.is_regular_done(),
			"The loaded season is still playable")
