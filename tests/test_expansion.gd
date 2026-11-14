extends RefCounted
## Expansion suite: Tasmania enters in 2028 and Canberra in 2030. Each club
## is inactive before its entry year (no fixtures, ladder, draft or selection
## presence) and a normal active club from it - including odd-club fixtures,
## the generated debut list, season transitions and saves.
## Run through tests/run_expansion_tests.gd.

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
	_t("_test_entry_gates")
	_t("_test_fair_fixture")
	_t("_test_return_spacing")
	_t("_test_saved_fixture_kept")
	_t("_test_2026_baseline")
	_t("_test_rollover_to_2028")
	_t("_test_2028_season_runs")
	_t("_test_rollover_to_2030")
	_t("_test_save_load_across_expansion")
	_t("_test_expansion_ceilings")
	_t("_test_expansion_entry_history")
	_t("_test_created_club_rules")
	_t("_test_created_club_career")
	_t("_test_club_count_defaults")
	_t("_test_redraft_new_clubs_join_later")
	_t("_test_redraft_tasmania_2028")
	_t("_test_redraft_entry_saved")
	_t("_test_real_lists_play_to_2030")
	_t("_test_real_lists_tasmania_2028")
	GameState.reset()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Expansion", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## A fair fixture at 18, 19 and 20 clubs, over several seeds: every club
## plays the same number of games, hosts half of them (within one), rests the
## same number of times, and the byes and repeats follow the seed, not the
## club list (Season.build_fixture).

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)
func _test_fair_fixture() -> void:
	# 18 to 21 clubs: a created club (Club Forge) can make any of them in any
	# year, so the counts are built here, not taken from the calendar.
	var all_clubs: Array = GameDB.active_clubs(2030)
	for n in [18, 19, 20, 21]:
		var codes: Array = all_clubs.slice(0, mini(n, all_clubs.size()))
		while codes.size() < n:
			codes.append("NEW%d" % codes.size())
		var lists := {}
		for c in codes:
			lists[c] = GameDB.club_list(str(c))
		var problems := []
		var first_rest := {}
		for sd in [11, 222, 3333, 44444]:
			var s := Season.new(codes, lists, sd)
			var games := {}
			var home := {}
			var rests := {}
			var pairs := {}
			for c in codes:
				games[c] = 0
				home[c] = 0
				rests[c] = []
			if s.fixture.size() != Season.REGULAR_ROUNDS:
				problems.append("%d rounds" % s.fixture.size())
			var short := 0
			for ri in range(s.fixture.size()):
				var size := (s.fixture[ri] as Array).size()
				if size < n / 2 - 1:
					problems.append("round %d has %d matches" % [ri + 1, size])
				if size < n / 2:
					short += 1
					if n % 2 == 0 and (ri < Season.BYE_FIRST or ri > Season.BYE_LAST):
						problems.append("a bye in round %d, outside the mid-season rounds" % (ri + 1))
				var seen := {}
				for m in s.fixture[ri]:
					var a := str(m["home"])
					var b := str(m["away"])
					if seen.has(a) or seen.has(b) or a == b:
						problems.append("round %d plays a club twice" % (ri + 1))
					seen[a] = true
					seen[b] = true
					games[a] += 1
					games[b] += 1
					home[a] += 1
					pairs[a + "|" + b if a < b else b + "|" + a] = true
				for c in codes:
					if not seen.has(c):
						(rests[c] as Array).append(ri)
			# Matches a full round can't hold: 18 clubs nine rounds of eight; 21
			# clubs nine of nine.
			var g0 := int(games[codes[0]])
			if short != Season.REGULAR_ROUNDS * (n / 2) - n * g0 / 2:
				problems.append("%d rounds a match short" % short)
			if g0 != (23 if codes.size() % 2 == 0 else 22):
				problems.append("%d games, not 23 (22 for an odd count)" % g0)
			for c in codes:
				if int(games[c]) != g0:
					problems.append("%s plays %d, %s plays %d" % [codes[0], g0, c, games[c]])
				if absf(float(home[c]) - float(games[c]) / 2.0) > 1.0:
					problems.append("%s hosts %d of %d" % [c, home[c], games[c]])
				if (rests[c] as Array).size() != (rests[codes[0]] as Array).size():
					problems.append("%s rests %d times" % [c, (rests[c] as Array).size()])
			if pairs.size() != codes.size() * (codes.size() - 1) / 2:
				problems.append("%d pairs meet" % pairs.size())
			if codes.size() % 2 == 1:
				first_rest[sd] = str(codes.filter(func(c): return (rests[c] as Array).has(0))[0])
			var again := Season.new(codes, lists, sd)
			if str(again.fixture) != str(s.fixture):
				problems.append("seed %d does not repeat" % sd)
		_check(problems.is_empty(), "%d clubs: 23 games each (22 at an odd count), home within one of half, equal rests, every pair meets, no round more than a match short, byes mid-season at an even count (%s)" % [
				codes.size(), str(problems.slice(0, 4))])
		if codes.size() % 2 == 1:
			var who := {}
			for sd in first_rest:
				who[first_rest[sd]] = true
			_check(who.size() >= 2, "%d clubs: who rests first follows the seed, not the club list (%s)" % [codes.size(), str(first_rest)])


## A pair that meets twice meets at least RETURN_GAP rounds apart, never a
## third time, and (nearly always) once in each half - at 18 to 21 clubs over
## many seeds (director, 2026-11-07: Hawthorn in rounds 1 and 6).
func _test_return_spacing() -> void:
	var all_clubs: Array = GameDB.active_clubs(2030)
	for n in [18, 19, 20, 21]:
		var codes: Array = all_clubs.slice(0, mini(n, all_clubs.size()))
		while codes.size() < n:
			codes.append("NEW%d" % codes.size())
		_check(codes.size() == n, "%d clubs to draw from" % n)
		var lists := {}
		for c in codes:
			lists[c] = []
		var closest := Season.REGULAR_ROUNDS
		var returns := 0
		var halves := 0
		var thrice := []
		var thin := []
		var early := []
		# 120 spread seeds, then the seeds a 1,500-seed audit of an earlier
		# draft of this builder flagged (a round two short, a bye outside 9-20).
		var seeds := []
		for sd in range(1, 121):
			seeds.append(sd * 7919)
		seeds.append_array({18: [10263445, 100016198], 20: [68388040, 112688407,
				133634207, 139184844, 151961782, 53202335, 128239041, 73256316]}.get(n, []))
		for sd in seeds:
			var s := Season.new(codes, lists, sd)
			var meets := {}
			for ri in range(s.fixture.size()):
				var size := (s.fixture[ri] as Array).size()
				if size < n / 2 - 1:
					thin.append("seed %d round %d: %d matches" % [sd, ri + 1, size])
				if n % 2 == 0 and size < n / 2 and (ri < Season.BYE_FIRST or ri > Season.BYE_LAST):
					early.append("seed %d round %d" % [sd, ri + 1])
				for m in s.fixture[ri]:
					var a := str(m["home"])
					var b := str(m["away"])
					var key := a + "|" + b if a < b else b + "|" + a
					if not meets.has(key):
						meets[key] = []
					(meets[key] as Array).append(ri)
			for key in meets:
				var at: Array = meets[key]
				if at.size() > 2:
					thrice.append("seed %d %s %s" % [sd, key, str(at)])
				if at.size() == 2:
					returns += 1
					closest = mini(closest, int(at[1]) - int(at[0]))
					if int(at[0]) < Season.REGULAR_ROUNDS / 2 and int(at[1]) >= Season.REGULAR_ROUNDS / 2:
						halves += 1
		_check(returns > 0, "%d clubs: some pairs meet twice" % n)
		_check(closest >= Season.RETURN_GAP, "%d clubs: a pair's two meetings at least %d rounds apart over %d seeds (closest %d)" % [
				n, Season.RETURN_GAP, seeds.size(), closest])
		_check(thrice.is_empty(), "%d clubs: no pair meets three times (%s)" % [n, str(thrice.slice(0, 3))])
		_check(thin.is_empty(), "%d clubs: no round two or more matches short (%s)" % [n, str(thin.slice(0, 3))])
		_check(early.is_empty(), "%d clubs: byes only in rounds %d-%d (%s)" % [
				n, Season.BYE_FIRST + 1, Season.BYE_LAST + 1, str(early.slice(0, 3))])
		_check(halves * 100 >= returns * 95, "%d clubs: return games split first half / second half (%d of %d)" % [n, halves, returns])


## A season already in a save keeps its fixture on loading: the builder can
## change for new seasons without moving a saved one's games.
func _test_saved_fixture_kept() -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	# One the builder never draws: the old round-robin-and-return shape.
	GameState.season.fixture = GameState.season._legacy_fixture()
	var saved := str(GameState.season.fixture)
	_check(saved != str(GameState.season.build_fixture()), "the stand-in fixture differs from a fresh draw")
	GameState.save_career()
	_check(GameState.load_career(), "the career loads")
	_check(str(GameState.season.fixture) == saved, "the saved fixture comes back unchanged, not redrawn")
	GameState.delete_saved_career()


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
				"%s has no 2026-data players (its list is generated at entry)" % code)

	# A League redraft without Canberra: the founding eighteen draft in 2027,
	# Tasmania join in 2028 (director, 2026-11-12: "Join in 2028"); Canberra
	# never join.
	GameState.reset()
	GameState.begin_draft()
	_check(GameState.draft.clubs.size() == 18
			and not GameState.draft.clubs.has("TAS")
			and not GameState.draft.clubs.has("CANB")
			and GameDB.enter_year("TAS") == 2028
			and GameDB.enter_year("CANB") == Expansion.NEVER,
			"A League redraft with Canberra No: 18 clubs in 2027, Tasmania from 2028, no Canberra")
	# Real 2026 lists without Canberra: unchanged, Tasmania join in 2028.
	GameState.reset()
	GameState.begin_real_lists()
	_check(GameState.draft.clubs.size() == 18 and not GameState.draft.clubs.has("TAS")
			and GameDB.enter_year("TAS") == 2028 and not GameState.sim_ahead,
			"Real 2026 lists with Canberra No: the founding eighteen in 2027, Tasmania from 2028")
	GameState.reset()
	_check(GameDB.enter_year("TAS") == 2028, "A reset puts Tasmania back on its 2028 entry")


# ---------------------------------------------------------------------------
# A career through the expansion
# ---------------------------------------------------------------------------
func _new_first_season() -> Season:
	GameState.reset()
	# Canberra is the coach's choice at New career; this career takes it.
	GameState.set_canberra(true)
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	return GameState.season


func _test_2026_baseline() -> void:
	var season := _new_first_season()
	_check(GameState.season_year == 2027, "A career's first season is 2027")
	_check(season.ladder.size() == 18, "The 2027 ladder has eighteen clubs")
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2027")
	for r in season.fixture:
		_check((r as Array).size() == 9 or (r as Array).size() == 8,
				"Eighteen clubs play nine matches a round, eight in a bye round")


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
	# The Rookie Draft settles before the first round, as it does in play: a
	# list short of the minimum fills after it (GameState._fill_short_lists).
	RookieList.settle(GameState)


func _test_rollover_to_2028() -> void:
	# 2027 -> 2028: the first rollover, and Tasmania arrives.
	_rollover()
	_check(GameState.season_year == 2028, "The career advances to 2028")
	var season: Season = GameState.season
	_check(season.ladder.size() == 19, "Nineteen clubs on the 2028 ladder")
	_check(season.ladder.has("TAS"), "Tasmania is on the 2028 ladder")
	_check(not season.ladder.has("CANB"), "Canberra is not yet on the ladder")

	# The entry news is posted the moment the rollover commits.
	var news_ok := false
	for item in GameState.news:
		if str(item["kind"]) == "expansion" and str(item["text"]).contains("Tasmania"):
			news_ok = true
	_check(news_ok, "Tasmania's entry made the news")

	# The debut list: a full squad, in the right size band, with contracts
	# ready when the season opens.
	var tas: Array = season.lists["TAS"]
	_check(tas.size() >= Contracts.min_list() and tas.size() <= Ratings.LIST_SIZE,
			"Tasmania debuts with a full list (%d)" % tas.size())
	var ages := 0.0
	var id_seen := {}
	for p in tas:
		ages += float(p["age"])
		_check(not id_seen.has(str(p["id"])), "Tasmania ids are unique")
		id_seen[str(p["id"])] = true
		_check(int(p.get("contract_years", 0)) > 0,
				"Every Tasmanian has a contract at the season start")
	_check(ages / float(tas.size()) > 19.0 and ages / float(tas.size()) < 27.0,
			"The debut list mixes ages (%.1f)" % (ages / float(tas.size())))

	# The odd-club fixture: 24 rounds, two byes each so every club plays 22
	# games, and every pair meets at least once.
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2028")
	var games := {}
	var pairs := {}
	for r in season.fixture:
		var round: Array = r
		_check(round.size() == 8 or round.size() == 9,
				"A 2028 round has eight or nine matches (%d)" % round.size())
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
		_check(n == 22, "%s plays 22 games in 2028 (%d)" % [code, n])


func _test_2028_season_runs() -> void:
	# One round proves the 19-club fixture plays (a bye club rests); the rest
	# of the home and away season is not under test, so the finals come next.
	var season: Season = GameState.season
	var first: int = (season.fixture[0] as Array).size()
	GameState.advance()
	_check(first >= 8 and GameState.last_results.size() == first and season.round_index == 1,
			"A 19-club round plays every match on it (%d of %d)" % [GameState.last_results.size(), first])
	_skip_to_finals()
	var guard := 0
	while not season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	_check(season.is_season_over(), "The 19-club 2028 season runs to a premier")
	_check(season.finals["top"].size() == Season.FINALISTS,
			"Ten finalists come off the 19-club ladder")
	_check(GameState.premier() != "", "A 2028 premier is crowned")

	# Tasmania's early-flag achievement only fires when it applies.
	var tas_flag := GameState.premier() == "TAS"
	_check(tas_flag == GameState.achievements.has("tas_early_flag"),
			"Tasmania's early-flag achievement matches its result")
	var stored: Dictionary = GameState.achievements.get("tas_early_flag", {})
	_check(_stamped(stored, 2028), "The achievement, when unlocked, is stamped 2028")
	# The stamp is an int: whether Tasmania wins the 2028 flag depends on
	# the sim, so the unlocked path is checked on a stamp of its own too (an
	# int compared with "" is a script error that skipped the 2029 rollover).
	_check(_stamped({"year": 2028}, 2028) and not _stamped({"year": 2029}, 2028)
			and _stamped({}, 2028), "An int year stamp reads without a script error")

	# 2028 -> 2029: Tasmania stays, the league ages on.
	_rollover()
	_check(GameState.season_year == 2029, "The career advances to 2029")
	var again: Array = GameState.season.lists["TAS"]
	_check(again.size() >= Contracts.min_list(), "Tasmania keeps a full list into 2029")


## The home-and-away rounds left are skipped and the finals open, as a season
## that has been played out (tests/run_career_ui_tests.gd does the same).
func _skip_to_finals() -> void:
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	GameState.ensure_finals()


## The years played without you, step by step as the loading cover plays them
## (GameState.sim_ahead_step). Each season plays its first `rounds` rounds;
## the rest of its home and away season is skipped (the cover's lines, the
## drafts and the rollovers are under test, not the matches), then its finals.
func _sim_ahead(lines: Array, limit: int, rounds := 2) -> int:
	var steps := 0
	while steps < limit:
		steps += 1
		var line := GameState.sim_ahead_step()
		if line == "":
			break
		lines.append(line)
		var season: Season = GameState.season
		if season != null and not season.is_regular_done() and season.round_index >= rounds:
			_skip_to_finals()
	return steps


## True when the achievement is not unlocked, or is stamped `year`.
func _stamped(stored: Dictionary, year: int) -> bool:
	return not stored.has("year") or int(stored["year"]) == year


func _test_rollover_to_2030() -> void:
	_rollover()
	_check(GameState.season_year == 2030, "The career advances to 2030")
	var season: Season = GameState.season
	_check(season.ladder.size() == 20, "Twenty clubs on the 2030 ladder")
	_check(season.ladder.has("CANB") and season.ladder.has("TAS"),
			"Both expansion clubs are on the 2030 ladder")
	var canb: Array = season.lists["CANB"]
	_check(canb.size() >= Contracts.min_list() and canb.size() <= Ratings.LIST_SIZE,
			"Canberra debuts with a full list (%d)" % canb.size())
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2030")
	for r in season.fixture:
		_check((r as Array).size() == 10, "Twenty even clubs play ten a round")
		break
	# The league's lists never share a player and every club stays in band.
	# One check for the whole league: the floor counts the rule, not how many
	# players the lists happen to hold.
	var seen := {}
	var twice := ""
	for code in season.ladder:
		var arr: Array = season.lists[code]
		_check(arr.size() >= Contracts.min_list() and arr.size() <= Ratings.LIST_SIZE,
				"%s stays in the list band in 2030 (%d)" % [code, arr.size()])
		for p in arr:
			if seen.has(str(p["id"])):
				twice += str(p["id"]) + " "
			seen[str(p["id"])] = true
	_check(twice == "", "No player on two lists (%s)" % twice)


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


## An expansion list's seasoned players have the ceiling of their age, not
## of an 18-year-old draft pick; its young players keep the draft-style one.
func _test_expansion_ceilings() -> void:
	for spec in [["TAS", 2028], ["CANB", 2030]]:
		var lst: Array = Prospects.generate_expansion_list(str(spec[0]), int(spec[1]))
		var old_ok := true
		var old_n := 0
		var young_room := 0.0
		var young_n := 0
		for p in lst:
			var age := float(p["age"])
			var room := int(p["potential"]) - int(p["overall"])
			if age > Potential.MAX_PROSPECT_AGE:
				old_n += 1
				if room > int(Potential._headroom(age)) + 3:
					old_ok = false
			else:
				young_room += float(room)
				young_n += 1
		_check(old_n > 0 and old_ok,
				"%s %d: no seasoned expansion player has a draftee's ceiling (%d over 21)" % [spec[0], spec[1], old_n])
		_check(young_n > 0 and young_room / young_n >= 10.0,
				"%s %d: young expansion players keep real upside (mean +%.1f)" % [spec[0], spec[1], young_room / maxf(1, young_n)])


## T3.F defect "implausible generated veteran": a seasoned expansion player's
## history said he came out of the under-18s in the club's first year. Over
## many careers' foundation lists, nobody of 20 or more has a Talent League
## season as his record, and nobody past draft age is ranked in that year's
## draft class; the under-20s still can be.
func _test_expansion_entry_history() -> void:
	var n := 0
	var bad: Array = []
	var young_talent := 0
	for spec in [["TAS", 2028], ["CANB", 2030]]:
		for s in range(60):
			var salt := "" if s == 0 else "%04d" % s
			for p in Prospects.generate_expansion_list(str(spec[0]), int(spec[1]), 36, salt):
				n += 1
				var age := float(p["age"])
				var league := str(p.get("draft_league", ""))
				if age < 20.0 and league == "Talent League":
					young_talent += 1
				if (age >= 20.0 and league == "Talent League") \
						or (age > Potential.MAX_PROSPECT_AGE and int(p.get("draft_rank", 0)) > 0):
					bad.append("%s age %.1f: %s" % [p["id"], age, PlayerProfile.pedigree(p)])
	_check(n == 2 * 60 * 36, "Every foundation list is generated (%d players)" % n)
	_check(bad.is_empty(), "No expansion veteran came out of the under-18s in the club's first year (%d: %s)"
			% [bad.size(), str(bad.slice(0, 3))])
	_check(young_talent > 0, "Young expansion players still come from the Talent League (%d)" % young_talent)


# ---------------------------------------------------------------------------
# Club Forge: a created club (ARD-M7-009)
# ---------------------------------------------------------------------------
func _forge_spec(extra := {}) -> Dictionary:
	var spec := {"name": "Port Melbourne", "short": "Borough", "code": "PMB",
			"location": "port-melbourne", "primary": "#1B3A8C", "secondary": "#C8102E",
			"accent": "#FFFFFF", "design": "hoops", "kit": "p/s/a"}
	spec.merge(extra, true)
	return spec


func _test_created_club_rules() -> void:
	GameState.reset()
	GameState.set_canberra(true)
	_check(ClubForge.locations().size() >= 50, "Club Forge reads the location library")
	_check(ClubForge.club_problem(_forge_spec()) == "", "A complete spec makes a club")
	_check(ClubForge.club_problem(_forge_spec({"name": " "})) != "", "A club needs a name")
	_check(ClubForge.club_problem(_forge_spec({"short": ""})) != "", "A club needs a nickname")
	_check(ClubForge.club_problem(_forge_spec({"name": "Geelong"})) != "",
			"A created club cannot share an AFL club's name")
	for code in ["GEE", "TAS", "CANB", "BYE", "SKN", "pm", "P", "PORTM", "P1"]:
		_check(ClubForge.club_problem(_forge_spec({"code": code})) != "",
				"%s is not a free abbreviation" % code)
	_check(ClubForge.club_problem(_forge_spec({"location": "melbourne"})) != "",
			"The home must come from the location library")
	_check(ClubForge.club_problem(_forge_spec({"ground": "The MCG"})) != "",
			"The ground must be one of the place's own")
	_check(ClubForge.club_problem(_forge_spec({"location": "williamstown",
			"ground": "Williamstown Cricket Ground"})) == "",
			"A place's alternative ground can be chosen")
	_check(ClubForge.club_problem(_forge_spec({"design": "suit"})) != ""
			and ClubForge.club_problem(_forge_spec({"design": "map"})) != "",
			"The coach's suit and Tasmania's map are not club designs")
	_check(ClubForge.club_problem(_forge_spec({"kit": "p/p/a"})) != "",
			"The guernsey and its pattern are different colours")
	_check(ClubForge.club_problem(_forge_spec({"secondary": "#1C3B8D"})) != "",
			"A pattern too close to the guernsey's colour is refused")
	_check(ClubForge.club_problem(_forge_spec({"design": "plain", "secondary": "#1C3B8D"})) == "",
			"A plain guernsey needs no contrasting pattern")
	_check(ClubForge.make_club(_forge_spec({"code": "GEE"})).is_empty(),
			"No club is made from a spec with a problem")

	_check(GameState.create_club(_forge_spec({"code": "GEE"})) != ""
			and not GameDB.clubs.has("PMB") and GameDB.club_order.size() == GameDB.CLUB_ORDER.size(),
			"A refused club changes nothing")
	_check(GameState.create_club(_forge_spec()) == "", "The club is created")
	var c: Dictionary = GameDB.club("PMB")
	_check(GameDB.club_name("PMB") == "Port Melbourne" and GameDB.club_short("PMB") == "Borough",
			"The created club answers to its name and nickname")
	_check(str(c.get("ground", "")) == "North Port Oval" and str(c.get("state", "")) == "VIC",
			"The created club plays at its place's ground")
	var g: Dictionary = GameDB.club_guernsey("PMB")
	_check(str(g["design"]) == "hoops" and g["base"] == Color.html("#1B3A8C")
			and g["pattern"] == Color.html("#C8102E"),
			"The created club wears its own guernsey")
	_check(GameDB.club_marker_colours("PMB").size() == 3, "Its marker shows all three colours")
	_check(GameDB.active_clubs(2027).size() == 19 and GameDB.active_clubs(2027).has("PMB"),
			"A club entering with the career is the nineteenth in 2027")
	_check(GameDB.active_clubs(2030).size() == 21, "With Tasmania and Canberra it is the 21st by 2030")
	_check(GameDB.enter_year("PMB") == GameDB.START_YEAR
			and ClubForge.make_club(_forge_spec({"enter": 2030}))["enter"] == GameDB.START_YEAR,
			"A created club always enters with the career")
	_check(GameState.create_club(_forge_spec({"name": "Port Melbourne Borough", "code": "PMFC"})) == ""
			and not GameDB.clubs.has("PMB") and GameDB.clubs.has("PMFC")
			and GameDB.active_clubs(2027).size() == 19,
			"Making the club again replaces it: one created club a career")
	var kit := ClubForge.preset({"colour_tags": ["Navy blue", "red"], "pattern_tags": ["unknown", "hoops"]})
	_check(kit.get("primary") == ClubForge.palette_hex("navy") and kit.get("secondary") == ClubForge.palette_hex("red")
			and kit.get("accent") == ClubForge.palette_hex("white") and kit.get("design") == "hoops",
			"A place's tradition becomes a starting kit: its colours, a third, its pattern")
	# A save keeps each colour's hex: the original fifteen never change, and
	# the wider palette (director 2026-11-11) has no two colours alike.
	var original := {"navy": "#13234B", "blue": "#1F4FA8", "sky": "#6CACE4", "teal": "#00808A",
			"green": "#1E6B3A", "maroon": "#6E1F2E", "red": "#C8102E", "orange": "#E8762B", "gold": "#F2B231",
			"yellow": "#F7D417", "brown": "#5C3A21", "purple": "#4B2A7B", "grey": "#8A8D91", "black": "#111111",
			"white": "#F5F5F5"}
	var moved := []
	for id in original:
		if ClubForge.palette_hex(id) != original[id]:
			moved.append(id)
	_check(moved.is_empty(), "The Forge's original colours keep their hex, so saved clubs load unchanged (%s)" % str(moved))
	var ids := {}
	var hexes := {}
	var twins := []
	for col in ClubForge.PALETTE:
		if ids.has(col[0]) or hexes.has(str(col[2]).to_upper()):
			twins.append(col[0])
		ids[col[0]] = true
		hexes[str(col[2]).to_upper()] = true
	_check(ClubForge.PALETTE.size() >= 27 and twins.is_empty(),
			"The Forge offers %d colours, each its own (%s)" % [ClubForge.PALETTE.size(), str(twins)])
	var bottle := ClubForge.preset({"colour_tags": ["Bottle green", "Old gold"], "pattern_tags": []})
	_check(bottle.get("primary") == ClubForge.palette_hex("bottle") and bottle.get("secondary") == ClubForge.palette_hex("oldgold"),
			"Bottle green and old gold are their own colours in a place's tradition")
	_check(ClubForge.preset({"colour_tags": ["blue"], "pattern_tags": []}).is_empty(),
			"A place with one known colour gives no starting kit")
	var preset_spec := _forge_spec()
	preset_spec.merge(ClubForge.preset({"colour_tags": ["black", "white"], "pattern_tags": ["stripes"]}), true)
	_check(ClubForge.club_problem(preset_spec) == "", "A starting kit makes a valid club")
	GameState.reset()
	_check(not GameDB.clubs.has("PMFC") and GameDB.club_order == GameDB.CLUB_ORDER
			and GameState.custom_club.is_empty(),
			"A new career starts without the created club")


## A created club entering with the career drafts in the League Draft, plays,
## and keeps its identity through a save.
func _test_created_club_career() -> void:
	GameState.reset()
	_check(GameState.create_club(_forge_spec()) == "", "The club is created for a new career")
	GameState.begin_draft()
	_check(GameState.draft.clubs.size() == 19 and GameState.draft.clubs.has("PMB")
			and not GameState.draft.clubs.has("TAS"),
			"The created club takes part in the League Draft; Tasmania join in 2028")
	GameState.draft.start_for_user("PMB")
	var draft: Draft = GameState.draft
	var guard := 0
	while not draft.is_finished() and guard < 5000:
		guard += 1
		var cand := draft._best_ai_pick(draft.current_club())
		if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
			draft._skip_current_pick()
	_check(draft.is_finished(), "The 19-club League Draft completes")
	GameState.start_season("PMB", draft.list())
	var season: Season = GameState.season
	_check(GameState.my_club == "PMB" and season.ladder.size() == 19 and season.ladder.has("PMB"),
			"You coach the created club on a 19-club ladder in 2027 (Tasmania join in 2028)")
	# The director's PC playtest (2026-10-07): a created club started with
	# every coaching job vacant. It hires before its first season, from
	# coaches out of work; you are its senior coach.
	var staff := Coaches.staff(GameState.coaches, "PMB")
	_check(not staff.has("SC") and staff.size() == 5
			and ["SA", "MID", "FWD", "DEF", "DEV"].all(func(j): return staff.has(j)),
			"The created club starts with its five assistants (%s)" % str(staff.keys()))
	var seeded := Coaches.seed("PMB")
	var taken := false
	for cid in staff.values():
		var was: Dictionary = seeded.get(cid, {})
		taken = taken or str(was.get("status", "")) == "club"
	_check(not taken, "Nobody is taken from another club's staff")
	var others_same := true
	for club in GameDB.active_clubs(GameState.season_year):
		# Tasmania has no 2026 staff: it hires, like the created club.
		if club != "PMB" and club != "TAS" and Coaches.staff(GameState.coaches, club) != Coaches.staff(seeded, club):
			others_same = false
	_check(others_same, "Every other club keeps its 2026 staff")
	# One player per number on every list after the League Draft (director's
	# PC playtest, 2026-10-07: two players on his club both wore 35).
	var clashes := 0
	for code in season.lists:
		var seen := {}
		for p in season.lists[code]:
			var n := int(p.get("num", 0))
			if n <= 0 or seen.has(n):
				clashes += 1
			seen[n] = true
	_check(clashes == 0, "Every club's list has one player per number after the League Draft (%d clashes)" % clashes)
	var mine: Array = season.lists["PMB"]
	_check(mine.size() >= Contracts.min_list() and mine.size() <= Ratings.LIST_SIZE,
			"The created club drafts a full list (%d)" % mine.size())
	var played := 0
	var home_ground_ok := true
	for i in range(3):
		# Gather Round (Rounds 3 to 7) plays every match in one state.
		var gather := season.round_index == season.gather_round()
		GameState.advance()
		for res in GameState.last_results:
			if str(res.get("home", "")) == "PMB" or str(res.get("away", "")) == "PMB":
				played += 1
			if str(res.get("home", "")) == "PMB" and res.has("venue") and not gather:
				home_ground_ok = home_ground_ok and str(res["venue"]) == "North Port Oval"
	_check(played >= 2, "The created club plays its matches (%d in three rounds)" % played)
	_check(home_ground_ok, "Its home games are at its ground")
	_check(GameState.save_career(), "A created-club career saves")
	var meta := GameState.saved_career_meta()
	_check(str(meta.get("club_name", "")) == "Port Melbourne",
			"The main menu names the saved club before it loads")
	GameState.reset()
	_check(not GameDB.clubs.has("PMB"), "The created club leaves with the career")
	_check(GameState.load_career(), "The created-club career loads")
	_check(GameDB.club_name("PMB") == "Port Melbourne"
			and str(GameDB.club_guernsey("PMB")["design"]) == "hoops"
			and GameDB.active_clubs(GameState.season_year).has("PMB"),
			"The loaded career brings its club back, guernsey and all")
	_check(GameState.my_club == "PMB" and (GameState.season.lists["PMB"] as Array).size() == mine.size(),
			"The created club's list survives the round trip")
	# A save from before the fix: two players in one number. Loading fixes it,
	# and only the later one changes.
	var pmb: Array = GameState.season.lists["PMB"]
	var keep_num := int(pmb[0]["num"])
	var other_was := int(pmb[1]["num"])
	pmb[1]["num"] = keep_num
	_check(GameState.save_career(), "(a save with a doubled number)")
	_check(GameState.load_career(), "(it loads)")
	pmb = GameState.season.lists["PMB"]
	_check(int(pmb[0]["num"]) == keep_num and int(pmb[1]["num"]) != keep_num,
			"Loading gives the doubled number back to its first holder and the other a free one (%d, was %d)" % [int(pmb[1]["num"]), other_was])
	_check(Coaches.staff(GameState.coaches, "PMB") == staff, "The created club's staff survives the round trip")
	# A save made before the fix: the created club has nobody. Loading staffs it.
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("club", "")) == "PMB" and str(c.get("status", "")) == "club":
			c["status"] = "free"
			c["club"] = ""
			c["job"] = ""
	_check(Coaches.staff(GameState.coaches, "PMB").is_empty(), "(an old save's bare created club)")
	_check(GameState.save_career(), "The bare-club save is written")
	_check(GameState.load_career(), "The bare-club save loads")
	var repaired := Coaches.staff(GameState.coaches, "PMB")
	_check(repaired.size() == 5 and not repaired.has("SC"), "Loading an old save staffs its created club")
	_check(GameState.save_career(), "The repaired save is written")
	_check(GameState.load_career() and Coaches.staff(GameState.coaches, "PMB") == repaired,
			"The repair happens once: loading again changes nothing")
	# An AI-run created club gets a senior coach too.
	var probe := Coaches.seed("COL")
	var filled := CoachMarket.staff_new_clubs(probe, ["COL", "PMB"], "COL", 2026, 7)
	_check(filled.size() == 6 and Coaches.staff(probe, "PMB").size() == 6
			and Coaches.staff(probe, "COL") == Coaches.staff(Coaches.seed("COL"), "COL"),
			"A created club the AI runs hires all six; a seeded club is left alone")

## A club with no recorded expectation or goal position follows the club count,
## not 18 (a created club makes a league of 19 to 21).
func _test_club_count_defaults() -> void:
	_check(ClubLife.default_rank(18) == 9 and ClubLife.default_rank(21) == 10,
			"With no expectation a club is taken as mid-table: 9 of 18, 10 of 21")
	_check(ClubLife.goal_met({}, 21, 0, 21) and not ClubLife.goal_met({}, 19, 0),
			"A goal with no position asks the club count: 21st of 21 meets it, 19th of 18 does not")
	_check(ClubLife.goal_met({"pos": 12}, 12, 0, 21) and not ClubLife.goal_met({"pos": 12}, 13, 0, 21),
			"A set goal position is not moved by the club count")

# ---------------------------------------------------------------------------
# New career: who is in the league from the start (director, 2026-11-08)
# ---------------------------------------------------------------------------
func _ai_finish(draft: Draft) -> void:
	var guard := 0
	draft.auto_until_user_turn()
	while not draft.is_finished() and guard < 8000:
		guard += 1
		var cand := draft._best_ai_pick(draft.current_club())
		if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
			draft._skip_current_pick()
		draft.auto_until_user_turn()


func _saved_state() -> Dictionary:
	return CareerSave.read(GameState.save_path)


## League redraft with Canberra Yes and a created club (director, 2026-11-12:
## "Join in 2028"): the 2027 clubs draft alone, 19 with yours; Tasmania enter
## in 2028 and Canberra in 2030 on their own years, and neither is in the draft.
func _test_redraft_new_clubs_join_later() -> void:
	GameState.reset()
	GameState.set_canberra(true)
	_check(GameState.create_club(_forge_spec()) == "", "The club is created for a new career")
	GameState.begin_draft()
	var draft: Draft = GameState.draft
	_check(draft.clubs.size() == 19 and draft.clubs.has("PMB")
			and not draft.clubs.has("TAS") and not draft.clubs.has("CANB")
			and GameDB.active_clubs(2027).size() == 19,
			"League redraft, Canberra Yes, your club: 19 clubs in 2027 (%d)" % draft.clubs.size())
	_check(GameDB.enter_year("TAS") == 2028 and GameDB.enter_year("CANB") == 2030
			and GameDB.active_clubs(2028).size() == 20 and GameDB.active_clubs(2030).size() == 21,
			"Tasmania join in 2028 and Canberra in 2030 (TAS %d, CANB %d)" % [
				GameDB.enter_year("TAS"), GameDB.enter_year("CANB")])
	_check(GameState.expansion_from == 0, "A new redraft keeps the new clubs' own entry years")
	GameState.reset()


## A League redraft career's 2027 ladder has 18 clubs, and Tasmania arrive at
## the rollover with the debut list every new club gets: 19 clubs in 2028.
func _test_redraft_tasmania_2028() -> void:
	GameState.reset()
	GameState.begin_draft()
	var draft: Draft = GameState.draft
	draft.start_for_user("FRE")
	_ai_finish(draft)
	_check(draft.is_finished(), "The 18-club League Draft completes")
	GameState.start_season("FRE", draft.list())
	var season: Season = GameState.season
	_check(GameState.season_year == 2027 and season.ladder.size() == 18 and not season.ladder.has("TAS"),
			"A redraft career's 2027 ladder has 18 clubs, no Tasmania (%d)" % season.ladder.size())
	_rollover()
	season = GameState.season
	_check(GameState.season_year == 2028 and season.ladder.size() == 19 and season.ladder.has("TAS")
			and not season.ladder.has("CANB"),
			"Its 2028 ladder has 19 clubs, Tasmania in (%d)" % season.ladder.size())
	var tas: Array = season.lists.get("TAS", [])
	_check(tas.size() >= Contracts.min_list() and tas.size() <= Ratings.LIST_SIZE,
			"Tasmania debut with a full list, as in a real-lists career (%d)" % tas.size())
	GameState.reset()


## A new redraft career saves without the entry field and loads on the data
## years; a redraft saved while the new clubs entered in 2027 (2026-11-08 to
## 11-12) keeps that entry when it loads.
func _test_redraft_entry_saved() -> void:
	GameState.reset()
	GameState.set_canberra(true)
	GameState.begin_draft()
	GameState.draft.start_for_user("FRE")
	_ai_finish(GameState.draft)
	GameState.start_season("FRE", GameState.draft.list())
	_check(GameState.save_career(), "A redraft career saves")
	var saved := _saved_state()
	_check(not saved.is_empty() and not saved.has("expansion_from"), "A new redraft's save has no 2027 entry")
	GameState.reset()
	_check(GameState.load_career() and GameState.expansion_from == 0
			and GameDB.enter_year("TAS") == 2028 and GameDB.enter_year("CANB") == 2030
			and GameState.season.ladder.size() == 18,
			"Loaded, Tasmania join in 2028 and Canberra in 2030 (TAS %d, CANB %d)" % [
				GameDB.enter_year("TAS"), GameDB.enter_year("CANB")])
	# The same save as one written before the ruling, with the 2027 entry.
	saved["expansion_from"] = 2027
	_check(CareerSave.write(saved, CareerSave.read_meta(GameState.save_path), GameState.save_path),
			"An older redraft save is written")
	GameState.reset()
	_check(GameState.load_career() and GameState.expansion_from == 2027
			and GameDB.enter_year("TAS") == 2027 and GameDB.enter_year("CANB") == 2027,
			"An older redraft save keeps Tasmania and Canberra from 2027 (TAS %d, CANB %d)" % [
				GameDB.enter_year("TAS"), GameDB.enter_year("CANB")])
	GameState.reset()
	GameState.begin_real_lists()
	GameState.choose_real_club("FRE")
	_ai_finish(GameState.draft)
	GameState.finish_intake_draft()
	_check(GameState.save_career(), "A real-lists career saves")
	var state := _saved_state()
	GameState.reset()
	_check(not state.is_empty() and not state.has("expansion_from")
			and GameState.load_career() and GameState.expansion_from == 0 and not GameState.sim_ahead
			and GameDB.enter_year("TAS") == 2028,
			"A career without the new field loads with the data entry years")
	GameState.reset()


## Real 2026 lists with Canberra Yes: 2027 to 2029 play without you, every
## club AI-run; you choose any club, Tasmania and Canberra included, at the
## 2029 National Draft and start in 2030. Canberra taken by you keeps the
## exact build its own staff would have had.
## Real lists, Canberra No (director, 2026-11-09): "Yes, start 2028". Tasmania
## can be taken at the 2026 draft: 2027 plays without you, and you build the
## club at the 2027 National Draft with the same deal as under its own staff.
func _test_real_lists_tasmania_2028() -> void:
	GameState.reset()
	GameState.set_canberra(false)
	GameState.challenge = {"kind": "youth"}
	GameState.begin_real_lists()
	_check(GameState.waiting_club() == "TAS" and not GameState.draft.clubs.has("TAS"),
			"At the 2026 draft Tasmania can be waited for, and are not in that draft")
	_check(not GameState.begin_wait_for_club("COL"), "Only the club that joins next can be waited for")
	_check(GameState.begin_wait_for_club("TAS") and GameState.sim_ahead and not GameState.has_career()
			and not GameState.save_career() and GameState.challenge.is_empty(),
			"Waiting is not a career yet: nothing is saved, and the challenge is held")
	var lines := []
	var steps := _sim_ahead(lines, 200)
	_check(GameState.choosing_club() and GameState.season_year == 2027 and GameState.season.is_season_over(),
			"2027 is played and the 2027 National Draft waits (%d steps, %d)" % [steps, GameState.season_year])
	_check(lines.has("Playing 2027: the Grand Final...") and GameState.draft.user_club == "" and GameState.draft.pick_index == 0,
			"The cover names the weeks, and no pick is made before you take over")
	var draft: Draft = GameState.draft
	_check(draft.clubs.has("TAS") and draft.clubs.size() == 19, "All 19 clubs are in this draft (%d)" % draft.clubs.size())
	_check(ExpansionBuild.has_package(GameState, "TAS"), "Tasmania have their new-club build")
	var tas_picks := draft.upcoming_picks("TAS", 0)
	var col_picks := draft.upcoming_picks("COL", 0)
	_check(tas_picks.size() > col_picks.size(), "Tasmania have their priority picks (%s; Collingwood %s)" % [str(tas_picks), str(col_picks)])
	_check(GameState.choose_sim_ahead_club("TAS") and GameState.my_club == "TAS" and not GameState.sim_ahead
			and GameState.has_career() and draft.user_club == "TAS" and str(GameState.challenge.get("kind", "")) == "youth",
			"Tasmania are yours, and your challenge starts now")
	var tas_list: Array = ExpansionBuild.list_of(GameState, "TAS")
	var signed_tas := (GameState.expansion["TAS"]["signings"] as Array).size()
	_check(signed_tas > 0 and signed_tas <= Expansion.SIGNINGS, "The player chooses, so Tasmania sign out-of-contract players (%d)" % signed_tas)
	_check((GameState.expansion["TAS"]["traded_picks"] as Array).size() == 4, "Picks 5, 7, 11 and 13 are traded for senior players")
	_check(tas_list.size() + tas_picks.size() <= RookieList.SENIOR_SPOTS, "Every pick they hold fits on the list (%d + %d)" % [tas_list.size(), tas_picks.size()])
	var top_signed := 0
	for p in tas_list:
		if (GameState.expansion["TAS"]["signings"] as Array).has(str(p["id"])):
			top_signed = maxi(top_signed, int(p["overall"]))
	_check(top_signed > 0 and top_signed < Expansion.STAR_STAYS_OVERALL + 4, "Rivals' stars stay put: their best signing is rated %d" % top_signed)
	var academy_ok := true
	for row in GameState.intake_assignments:
		if str(row["kind"]) == "NGA" and str(row["club"]) != "TAS":
			academy_ok = false
	for p in draft.pool if "pool" in draft else []:
		if str(p.get("state", "")) == "TAS":
			academy_ok = false
	_check(academy_ok, "Tasmanian prospects join Tasmania before the draft, none reach the open pool")
	_check(draft.upcoming_picks("TAS", 0) == tas_picks, "Taken by you, Tasmania keep the same picks (%s, then %s)" % [str(tas_picks), str(draft.upcoming_picks("TAS", 0))])
	_check(GameState.club_yet_to_play(), "Their first draft comes before any season of theirs, so Continue returns to it")
	_check(GameState.save_career(), "Their first draft saves")
	_check(GameState.load_career() and GameState.club_yet_to_play() and GameState.draft != null
			and GameState.draft.user_club == "TAS" and GameState.draft.intake_mode, "It reloads at that draft")
	draft = GameState.draft
	_check(load("res://scripts/sim/Almanac.gd").rows(GameState.almanac, GameState.honour_roll).is_empty(),
			"2027 is not on your record: you did not coach it")
	_ai_finish(draft)
	GameState.finish_intake_draft()
	print("TAS 2028 list %d, picks %s" % [GameState.my_list.size(), str(tas_picks)])
	_check(GameState.season_year == 2028 and GameState.season != null and GameState.season.ladder.size() == 19
			and GameState.season.ladder.has("TAS") and GameState.my_club == "TAS",
			"Your first season is 2028, on a 19-club ladder (%d)" % GameState.season_year)
	_check(GameState.my_list.size() >= Contracts.min_list(), "Tasmania have a full list (%d)" % GameState.my_list.size())
	_check(not GameState.club_yet_to_play(), "Tasmania play 2028, so the Hub is home")
	_check(GameState.cap_room() == GameState.salary_cap + ExpansionBuild.relief(GameState, "TAS") - GameState.my_payroll()
			and ExpansionBuild.relief(GameState, "TAS") > 0, "The sign-on money counts on your own cap room")
	_check(GameState.save_career(), "The 2028 career saves")
	_check(GameState.load_career() and GameState.my_club == "TAS" and not GameState.sim_ahead and GameState.season_year == 2028,
			"It loads as a 2028 Tasmania career")
	GameState.reset()
	GameState.set_canberra(true)
	GameState.begin_sim_ahead()
	_check(GameState.waiting_club() == "" and GameState.sim_ahead_to == 2030, "Real lists with Canberra still wait for 2030")
	GameState.reset()
	GameState.set_canberra(false)
	GameState.challenge = {"kind": "rebuild"}
	GameState.begin_real_lists()
	# Row T5.Q25: a Rebuild picks the bottom club or a club joining the league.
	var bottom := str(GameState.challenge.get("club", ""))
	var kept := (GameState.league_lists[bottom] as Array).size()
	_check(GameState.my_club == "" and GameState.waiting_clubs() == ["TAS"] and bottom != "" and (GameState.challenge["gone"] as Array).is_empty(),
			"A rebuild offers the bottom club (%s) or Tasmania, and nobody has walked out yet (%s)" % [bottom, str(GameState.waiting_clubs())])
	GameState.choose_real_club("COL")
	_check(GameState.my_club == "", "A rebuild cannot take a club other than the bottom one")
	_check(GameState.begin_wait_for_club("TAS") and str(GameState._sim_ahead_challenge.get("club", "")) == "TAS"
			and (GameState._sim_ahead_challenge["gone"] as Array).is_empty() and (GameState.league_lists[bottom] as Array).size() == kept,
			"Rebuild at Tasmania: built from nothing, the challenge waits for 2028 and %s keep their three" % bottom)
	GameState.reset()
	GameState.set_canberra(true)
	GameState.challenge = {"kind": "rebuild"}
	GameState.begin_real_lists()
	_check(GameState.waiting_clubs() == ["TAS", "CANB"] and not GameState.sim_ahead,
			"With Canberra on, a rebuild starts in 2027 and can wait for Tasmania or Canberra: %s" % str(GameState.waiting_clubs()))
	_check(GameState.begin_wait_for_club("CANB") and GameState.sim_ahead_to == 2030, "Rebuild at Canberra waits for 2030")
	GameState.reset()
	GameState.set_canberra(false)
	GameState.challenge = {"kind": "rebuild"}
	GameState.begin_real_lists()
	GameState.choose_real_club(bottom)
	_check(GameState.my_club == bottom and (GameState.challenge["gone"] as Array).size() == 3
			and (GameState.league_lists[bottom] as Array).size() == kept - 3
			and int(GameState.draft.existing_sizes[bottom]) == RookieList.draft_size(GameState.league_lists[bottom]),
			"Rebuild at %s: three walk out as he takes over, and the draft counts the list without them" % bottom)
	GameState.reset()
	_check(GameState.sim_ahead_to == 2030, "A reset clears it")


func _test_real_lists_play_to_2030() -> void:
	GameState.reset()
	GameState.set_canberra(true)
	GameState.challenge = {"kind": "youth"}
	var old := {}
	for p in GameDB.all_players_sorted():
		if float(p.get("age", 0.0)) >= 34.0:
			old[str(p["id"])] = float(p["age"])
	GameState.begin_sim_ahead()
	_check(GameState.sim_ahead and GameState.my_club == "" and not GameState.has_career()
			and not GameState.save_career(),
			"The years played without you are not a career yet: nothing is saved")
	var lines := []
	var steps := _sim_ahead(lines, 400)
	_check(GameState.choosing_club() and GameState.season_year == 2029 and GameState.season.is_season_over(),
			"Played to the 2029 National Draft, which waits for your club (%d steps)" % steps)
	_check(lines.has("Starting the 2027 season...") and lines.has("Playing 2027: Round 2...")
			and lines.has("Playing 2029: the Grand Final..."),
			"The cover names each round and final as it plays (%s)" % str(lines.slice(0, 3)))
	_check(GameState.draft.user_club == "" and GameState.draft.pick_index == 0,
			"No pick is made before you choose")
	# Retirement is a judgement, not a cut-off, so a veteran or two can last.
	var still := 0
	var aged := true
	for code in GameState.league_lists:
		for p in GameState.league_lists[code]:
			if old.has(str(p["id"])):
				still += 1
				aged = aged and float(p["age"]) >= float(old[str(p["id"])]) + 1.9
	_check(not old.is_empty() and still * 4 <= old.size() and aged,
			"The players 34 or older at the 2027 start have mostly retired by 2029; any left aged two years (%d of %d)" % [still, old.size()])
	var tas: Array = GameState.league_lists.get("TAS", [])
	_check(tas.size() >= Contracts.min_list(), "Tasmania exists with a list (%d players)" % tas.size())
	_check(GameState.honour_roll.size() >= 3 and GameState.almanac.is_empty(),
			"2027 to 2029 are on the honour roll; your club annual is empty (%d, %d)" % [
				GameState.honour_roll.size(), GameState.almanac.size()])
	var draft: Draft = GameState.draft
	_check(draft.clubs.size() == 20 and draft.clubs.has("TAS") and draft.clubs.has("CANB"),
			"Choose your club: all 20 clubs, Tasmania and Canberra included (%d)" % draft.clubs.size())
	_check(ExpansionBuild.has_package(GameState, "CANB"),
			"Canberra, still under its own staff, has its new-club build")
	var canb_picks := draft.upcoming_picks("CANB", 0)
	var col_picks := draft.upcoming_picks("COL", 0)
	_check(canb_picks.size() > col_picks.size(),
			"Canberra has its priority picks (%s; Collingwood %s)" % [str(canb_picks), str(col_picks)])
	var relief_ai := ExpansionBuild.relief(GameState, "CANB")
	var signed := ExpansionBuild.list_of(GameState, "CANB").size()
	_check(GameState.choose_sim_ahead_club("CANB"), "You take Canberra")
	_check(GameState.my_club == "CANB" and not GameState.sim_ahead and GameState.has_career()
			and draft.user_club == "CANB" and str(GameState.challenge.get("kind", "")) == "youth",
			"Canberra is yours, and your challenge starts now")
	_check(draft.upcoming_picks("CANB", 0) == canb_picks and ExpansionBuild.relief(GameState, "CANB") == relief_ai
			and GameState.my_list.size() == signed,
			"Taken by you, Canberra keeps the same picks, cap room and signings (%d, %d; %s, then %s; relief %d; list %d)" % [relief_ai, signed, str(canb_picks), str(draft.upcoming_picks("CANB", 0)), ExpansionBuild.relief(GameState, "CANB"), GameState.my_list.size()])
	_check(not Coaches.staff(GameState.coaches, "CANB").has("SC"), "You are Canberra's senior coach")
	_ai_finish(draft)
	GameState.finish_intake_draft()
	_check(GameState.season_year == 2030 and GameState.season != null
			and GameState.season.ladder.size() == 20 and GameState.season.ladder.has("CANB")
			and GameState.my_club == "CANB",
			"Your first season is 2030, on a 20-club ladder (%d)" % GameState.season_year)
	_check(GameState.save_career(), "The 2030 career saves")
	_check(GameState.load_career() and GameState.my_club == "CANB" and not GameState.sim_ahead
			and GameState.season_year == 2030,
			"It loads as a 2030 Canberra career")
	# The campaign never ends (director: "campaigns can go for eternity"): the
	# 2030 start rolls on into 2031, twenty clubs, Canberra yours. One rollover
	# proves it; each one after is the same rollover (the nightly long suites
	# roll careers for decades).
	for year in [2031]:
		_rollover()
		_check(GameState.season_year == year and GameState.season != null
				and GameState.season.ladder.size() == 20 and GameState.season.ladder.has("CANB")
				and GameState.my_club == "CANB" and GameState.my_list.size() >= Contracts.min_list(),
				"The 2030 start rolls into %d: 20 clubs, Canberra yours on a full list (%d, %d clubs, list %d)" % [
					year, GameState.season_year, GameState.season.ladder.size() if GameState.season != null else 0,
					GameState.my_list.size()])
	_check(GameState.save_career(), "The 2031 career saves")
	_check(GameState.load_career() and GameState.my_club == "CANB" and GameState.season_year == 2031,
			"It loads as a 2031 Canberra career")
	GameState.reset()
