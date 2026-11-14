extends RefCounted
## Legacy mode season rules by year (row 142, phase L4): list sizes, the
## rookie list (1997 on), Category B, free agency (2012 on), the mid-season
## draft, the interchange bench and the substitute each follow the season
## being played (data/legacy/era_rules.csv, EraRules) and switch at the
## rollover. 2026 on is the game's own rules, unchanged.
## Run through tests/run_era_rules_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 1990
## The default career's first season (Datasets "2026"): GameDB.START_YEAR
## changes with the loaded set.
const GAME_YEAR := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	GameState.replay_seed = SUITE_SEED
	_t("_test_game_values_are_the_constants")
	_t("_test_rule_table")
	_t("_test_today_is_untouched")
	_t("_test_1990_season")
	_t("_test_campaign_1990_to_1998")
	_t("_test_smart_delisting")
	_t("_test_rollover_2011_to_2012")
	_t("_test_rollover_2025_to_2026")
	_t("_test_tactical_sub_2011")
	_t("_test_medical_sub_2021")
	_t("_test_no_sub_2016")
	_t("_test_coaches_votes_from_2003")
	GameState.reset()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	EraRules.year = 0
	EraRules.list_ahead = false
	print(Ran.line("Era rules", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## A career whose first season is `year`: the real 1990 start's league (its
## clubs come and go by year) for an era season, today's for a game year.
## Past 1990 the 1990 lists stand in (the rules are what is under test), and
## a club that joined since gets the list a rollover would build it.
func _career(year: int, club := "GEE") -> void:
	GameState.reset("1990" if EraRules.is_era(year) else Datasets.DEFAULT)
	GameState.season_year = year
	GameState.start_season(club, GameDB.club_list(club))
	var built := false
	for code in GameState.season.lists:
		if (GameState.season.lists[code] as Array).is_empty():
			var list := Prospects.generate_expansion_list(code, year)
			GameState.season.lists[code] = list
			GameState.league_lists[code] = list
			built = true
	if built:
		GameState.ensure_contracts()


## The season's home-and-away rounds are skipped; the finals are played.
## The board never sacks the test coach: this suite rolls rules, not careers,
## and a sacking with no job left would end the campaign mid-roll.
func _to_offseason() -> void:
	GameState.board["warned"] = false
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	var guard := 0
	while not GameState.season.is_season_over() and guard < 10:
		guard += 1
		GameState.advance()
	# The rules under test, not the board: a seeded season's results move with
	# any ratings change, and a sacking would stop the career rolling.
	GameState.board.erase("sacked")


## The season is treated as played, finals and all: each final is given a
## result (the higher seed wins), for a test whose subject is the rules each
## new season brings, not the football. Simulating the finals cost about 6 s
## a season on CI.
func _finals_given() -> void:
	var s: Season = GameState.season
	s.round_index = s.fixture.size()
	GameState.ensure_finals()
	var guard := 0
	while not s.is_season_over() and guard < 10:
		guard += 1
		var played := []
		for m in s.finals_week_matches():
			var top: Array = s.finals["top"]
			var home_higher := top.find(str(m["home"])) < top.find(str(m["away"]))
			var res := {"home": str(m["home"]), "away": str(m["away"]), "score": [80, 60] if home_higher else [60, 80]}
			s.record_final(m, res)
			played.append(res)
		s.complete_finals_week(played)
	_check(s.is_season_over() and str(s.finals.get("premier", "")) != "", "%d is played to a premier" % GameState.season_year)


## The off-season, then the rollover into the next season the way a career
## takes it: the National Draft (your picks made for you), then the Rookie
## Draft that opens in the new season. The finals are given results
## (_finals_given): the rollover is under test, not the football.
func _roll() -> bool:
	_finals_given()
	_open_off()
	GameState._close_free_agency()
	return _draft_and_start()


## A rival board's letter, or a sacking with jobs on offer, holds the
## off-season until the coach answers: he stays put, or takes the first job.
func _open_off() -> void:
	if ClubMoves.letter_open(GameState):
		ClubMoves.decline_letter(GameState)
	if GameState.is_sacked() and not ClubMoves.offers(GameState).is_empty():
		ClubMoves.take_job(GameState, str(ClubMoves.offers(GameState)[0].get("code", "")))
	GameState.open_offseason()


## The National Draft is left out: the 1990s drafts are not this suite's
## subject. The rollover, then the Rookie Draft as finish_intake_draft opens it.
func _draft_and_start() -> bool:
	var order := GameState.intake_order()
	var ok := GameState.start_next_season()
	RookieList.open_draft(GameState, order)
	for i in range(50):
		if not RookieList.waiting(GameState):
			break
		RookieList.settle(GameState)
	return ok


## Every list in the league is within the season's limits.
func _lists_within(label: String) -> void:
	_check(GameState.season.lists.size() >= 14, "%s: the league has its clubs (%d)" % [label, GameState.season.lists.size()])
	var over := []
	for code in GameState.season.lists:
		var list: Array = GameState.season.lists[code]
		if list.size() > Contracts.max_list() or RookieList.senior_count(list) > RookieList.senior_spots():
			over.append("%s %d" % [code, list.size()])
	_check(over.is_empty(), "%s: every list within %d (%d senior): %s" % [label, Contracts.max_list(),
			RookieList.senior_spots(), str(over.slice(0, 5))])


## A match of `year` between Geelong and Carlton on `seed`.
func _match(year: int, seed: int) -> MatchSim:
	EraRules.year = year
	EraRules.list_ahead = false
	var sim := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"),
			Squad.new("CAR", GameDB.club_list("CAR"), false, "CAR"), seed)
	sim.run()
	return sim


## `kind` "substitute": the substitute's own "sub" events, not interchange rotations.
func _events(sim: MatchSim, kind: String) -> Array:
	var out := []
	for e in sim.events:
		if (kind == "substitute" and bool(e.get("substitute", false))) or str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## Today's constants are GAME's values: a 2026 career reads them unchanged.
func _test_game_values_are_the_constants() -> void:
	_check(int(EraRules.GAME["senior_list_max"]) == RookieList.SENIOR_SPOTS
			and int(EraRules.GAME["rookie_list_max"]) == RookieList.CAT_A_SPOTS
			and int(EraRules.GAME["cat_b_rookie"]) == RookieList.CAT_B_SPOTS,
			"GAME's list sizes are RookieList's constants")
	_check(int(EraRules.GAME["senior_list_max"]) + int(EraRules.GAME["rookie_list_max"]) == Contracts.MAX_LIST,
			"GAME's list total is Contracts.MAX_LIST")
	_check(int(EraRules.GAME["interchange"]) == Ratings.INTERCHANGE and int(EraRules.GAME["substitutes"]) == 0,
			"GAME's bench is Ratings.INTERCHANGE with no substitute")


## Each change year reads its own rules from the record.
func _test_rule_table() -> void:
	# year: [bench, subs, medical, senior, cat A, cat B, rookie list, free agency, mid-season draft]
	var rows := {
		1990: [2, 0, false, 52, 0, 0, false, false, true],
		1993: [2, 0, false, 52, 0, 0, false, false, true],
		1994: [3, 0, false, 42, 0, 0, false, false, false],
		1997: [3, 0, false, 42, 6, 0, true, false, false],
		1998: [4, 0, false, 42, 6, 0, true, false, false],
		2001: [4, 0, false, 40, 6, 0, true, false, false],
		2006: [4, 0, false, 40, 6, 2, true, false, false],
		2009: [4, 0, false, 40, 8, 2, true, false, false],
		2011: [3, 1, false, 40, 8, 2, true, false, false],
		2012: [3, 1, false, 40, 8, 2, true, true, false],
		2013: [3, 1, false, 40, 6, 2, true, true, false],
		2016: [4, 0, false, 40, 6, 2, true, true, false],
		2019: [4, 0, false, 40, 6, 2, true, true, true],
		2021: [4, 1, true, 38, 6, 2, true, true, true],
		2025: [4, 1, true, 38, 6, 2, true, true, true],
		2026: [5, 0, false, 38, 6, 2, true, true, true],
		2027: [5, 0, false, 38, 6, 2, true, true, true],
	}
	for y in rows:
		var want: Array = rows[y]
		var got := [EraRules.interchange(y), EraRules.substitutes(y), EraRules.medical_sub(y),
				EraRules.senior_spots(y), EraRules.cat_a_spots(y), EraRules.cat_b_spots(y),
				EraRules.on("rookie_list", y), EraRules.on("free_agency", y), EraRules.on("midseason_draft", y)]
		_check(str(got) == str(want), "%d rules %s, want %s" % [y, str(got), str(want)])
	# Every era season has a list size and a bench of its own in the record.
	for y in range(1990, 2026):
		_check(EraRules.has("senior_list_max", y) and EraRules.has("interchange", y),
				"%d has a senior list size and a bench in era_rules.csv" % y)
		# The list minimum is the year's own, never over its maximum (director
		# 2026-11-13: "by era, obviously").
		_check(EraRules.has("list_min", y) and EraRules.list_min(y) <= EraRules.list_max(y),
				"%d has a list minimum of its own, under the maximum (%d, max %d)" % [y, EraRules.list_min(y), EraRules.list_max(y)])
	var mins := [EraRules.list_min(1990), EraRules.list_min(1994), EraRules.list_min(2004), EraRules.list_min(2010), EraRules.list_min(2021), EraRules.list_min(2026)]
	_check(str(mins) == str([48, 38, 37, 38, 37, Contracts.MIN_LIST]),
			"The list minimum by era: 48 to 1993, 38 from 1994, 37 in 2004, 38 to 2020, 37 from 2021 and today (%s)" % str(mins))


## Year 0 and today's seasons read GAME, whatever the record holds.
func _test_today_is_untouched() -> void:
	for y in [0, 2026, 2027, 2040]:
		EraRules.year = y
		EraRules.list_ahead = false
		_check(Ratings.bench() == Ratings.bench_size and Ratings.subs() == 0
				and Contracts.max_list() == Contracts.MAX_LIST
				and RookieList.senior_spots() == RookieList.SENIOR_SPOTS
				and RookieList.cat_a_spots() == RookieList.CAT_A_SPOTS
				and RookieList.cat_b_spots() == RookieList.CAT_B_SPOTS
				and RookieList.in_force() and EraRules.on("free_agency") and EraRules.on("midseason_draft"),
				"%d: bench, lists and switches are the game's" % y)
	_career(GAME_YEAR)
	var sq := Squad.new("GEE", GameState.my_list, true, "GEE")
	_check(sq.bench.size() == Ratings.INTERCHANGE and sq.sub.is_empty(),
			"A %d side names %d on the bench and no substitute" % [GAME_YEAR, sq.bench.size()])


## A 1990 season: two on the bench, a 52-man list, no rookie list.
func _test_1990_season() -> void:
	_career(1990)
	_check(EraRules.year == 1990 and not EraRules.list_ahead, "The season sets the rules year")
	_check(Ratings.bench() == 2 and Ratings.subs() == 0, "1990: two interchange players, no substitute")
	_check(Contracts.max_list() == 52 and RookieList.cat_a_spots() == 0 and not RookieList.in_force(),
			"1990: a 52-man list and no rookie list")
	var sq := Squad.new("GEE", GameState.my_list, true, "GEE")
	_check(sq.ground.size() == 18 and sq.bench.size() == 2 and sq.sub.is_empty(),
			"A 1990 side is 18 and two (%d and %d)" % [sq.ground.size(), sq.bench.size()])


## The 1990 start rolled season by season to 1998: each season plays under
## its own rules, switched at the rollover (lists from 52 to 42 in 1994, the
## third interchange in 1994, the first rookie lists in 1997, the fourth
## interchange in 1998), and no player walks to free agency.
func _test_campaign_1990_to_1998() -> void:
	_career(1990)
	# season: [bench, max list, rookie list]
	var want := {1990: [2, 52, false], 1991: [2, 52, false], 1992: [2, 52, false], 1993: [2, 52, false],
			1994: [3, 42, false], 1995: [3, 42, false], 1996: [3, 42, false], 1997: [3, 48, true], 1998: [4, 48, true]}
	for y in range(1990, 1999):
		_check(GameState.season_year == y and EraRules.year == y and not EraRules.list_ahead,
				"The rules year follows the season (%d, %d)" % [GameState.season_year, EraRules.year])
		var got := [Ratings.bench(), Contracts.max_list(), RookieList.in_force()]
		_check(str(got) == str(want[y]), "%d plays under %s, want %s" % [y, str(got), str(want[y])])
		_lists_within(str(y))
		var active := GameDB.active_clubs(y).size()
		var fielded := 0
		var sizes := {}
		for code in GameState.season.lists:
			sizes[code] = (GameState.season.lists[code] as Array).size()
			if int(sizes[code]) >= 23:
				fielded += 1
		_check(fielded == active, "%d: all %d clubs can field a side: %s" % [y, active, str(sizes)])
		var sq := Squad.new(GameState.my_club, GameState.my_list, true, GameState.my_club)
		_check(sq.ground.size() == 18 and sq.bench.size() == int(want[y][0]) and sq.sub.is_empty(),
				"%d: a side of 18 and %d" % [y, sq.bench.size()])
		var rookies := 0
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				if str(p.get("rookie_list", "")) != "":
					rookies += 1
		_check((rookies > 0) == bool(want[y][2]), "%d: rookie-listed players %d" % [y, rookies])
		if y == 1998:
			break
		_finals_given()
		_open_off()
		_check(EraRules.list_ahead and Contracts.max_list() == int(want[y + 1][1]),
				"The %d off-season plans %d's lists of %d (ahead %s, off-season year %d, sacked %s)" % [y, y + 1,
				Contracts.max_list(), str(EraRules.list_ahead), GameState.offseason_year, str(GameState.is_sacked())])
		var testing := 0
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				if GameState.tests_market(p, GameState.season.lists[code]):
					testing += 1
		_check(testing == 0, "No %d player tests the free-agent market (%d)" % [y, testing])
		GameState._close_free_agency()
		_check(_draft_and_start(), "%d rolls into %d" % [y, y + 1])


## A rival over next season's smaller list delists on worth, not rating
## alone (director, 2026-11-13): a 69 at 20 with 75 to come stays, a 70 at 35
## goes.
func _test_smart_delisting() -> void:
	_career(1993)
	_finals_given()
	var rival := "CAR"
	var list: Array = GameState.season.lists[rival]
	var kid := {}
	var vet := {}
	for p in list:
		if str(p.get("rookie_list", "")) != "" or GameState.retiring_now(p):
			continue
		if kid.is_empty():
			kid = p
		elif vet.is_empty():
			vet = p
	kid.merge({"overall": 69, "potential": 75, "age": 20.0, "contract_years": 3}, true)
	vet.merge({"overall": 70, "potential": 70, "age": 35.0, "contract_years": 3}, true)
	vet.erase("retiring")
	# Everyone else outranks both, so one of the two must go to reach 42.
	var others := 0
	for p in list:
		if p != kid and p != vet:
			p["overall"] = maxi(int(p.get("overall", 0)), 80)
			p["age"] = minf(float(p.get("age", 25.0)), 27.0)
			others += 1
	var base: Dictionary = {}
	for p in list:
		if p != kid and p != vet and str(p.get("rookie_list", "")) == "":
			base = p
			break
	# Exactly one over the 42: drop other seniors first (the list may already be
	# past it at the end of the season), then pad if it is short.
	for p in list.duplicate():
		if RookieList.senior_count(GameState.staying_on(list)) <= 43:
			break
		if p != kid and p != vet and p != base and str(p.get("rookie_list", "")) == "":
			list.erase(p)
	while RookieList.senior_count(GameState.staying_on(list)) < 43:
		var extra: Dictionary = base.duplicate(true)
		extra["id"] = "era_extra_%d" % list.size()
		extra["rookie_list"] = ""
		extra.erase("retiring")
		list.append(extra)
	EraRules.year = 1993
	EraRules.list_ahead = true
	GameState._era_trim_rivals()
	_check(list.has(kid), "The 69-rated 20-year-old with 75 to come is kept")
	_check(not list.has(vet), "The 70-rated 35-year-old is delisted first")
	_check(RookieList.senior_count(GameState.staying_on(list)) <= 42,
			"The list is down to 42")
	EraRules.list_ahead = false


## 2011 to 2012: free agency begins in the 2012 off-season, not before.
func _test_rollover_2011_to_2012() -> void:
	_career(2011)
	_check(Ratings.bench() == 3 and Ratings.subs() == 1 and not EraRules.medical_sub(),
			"2011: three on the bench and a substitute")
	_check(not EraRules.on("free_agency"), "2011: no free agency")
	_check(_roll(), "2011 rolls into 2012")
	_check(EraRules.on("free_agency"), "2012: free agency")
	# Today's lists stand in, so their clubs' tenures postdate 2012: the gate
	# is checked on the players who test the market in a game year.
	_career(GAME_YEAR)
	var testers := []
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if GameState.tests_market(p, GameState.season.lists[code]):
				testers.append([p, code])
	_check(not testers.is_empty(), "Some %d players test the market (%d)" % [GAME_YEAR, testers.size()])
	var walk := {2011: 0, 2012: 0}
	for y in walk:
		EraRules.year = y
		for t in testers:
			if GameState.tests_market(t[0], GameState.season.lists[t[1]]):
				walk[y] += 1
	EraRules.year = GameState.season_year
	_check(walk[2011] == 0 and walk[2012] == testers.size(),
			"The same players: none test the market under 2011's rules, all under 2012's (%s)" % str(walk))


## 2025 to 2026: the game's own rules take over.
func _test_rollover_2025_to_2026() -> void:
	_career(2025)
	_check(Ratings.bench() == 4 and EraRules.medical_sub(), "2025: four on the bench and a medical substitute")
	_check(_roll(), "2025 rolls into 2026")
	_check(Ratings.bench() == Ratings.INTERCHANGE and Ratings.subs() == 0
			and Contracts.max_list() == Contracts.MAX_LIST,
			"2026: the game's bench of %d, no substitute, lists of %d" % [Ratings.bench(), Contracts.max_list()])
	_lists_within("2026")


## 2011-2015: each side's substitute comes on once (for an injury, or at
## three-quarter time at the latest), and the man he replaces stays off.
func _test_tactical_sub_2011() -> void:
	var sim := _match(2011, 31)
	for side in range(2):
		var on := 0
		for e in _events(sim, "substitute"):
			if int(e.get("side", -1)) == side:
				on += 1
		_check(on == 1, "Side %d brings its substitute on once (%d)" % [side, on])
		var sq: Squad = sim.squads[side]
		var still_on := false
		for p in sim.subbed_off[side]:
			for q in sq.ground + sq.bench:
				if str(q["id"]) == str(p["id"]):
					still_on = true
		_check(not still_on, "Side %d: the man subbed off stays off" % side)
		_check((sim.rosters()[side] as Array).size() <= 23, "Side %d uses at most 22 players" % side)
	# The feed calls the substitute; an interchange stays on the oval.
	for e in _events(sim, "substitute"):
		var club := "GEE" if int(e["side"]) == 0 else "CAR"
		var want := "Substitute: %s on for %s (%s)" % [e["name"], e["off_name"], GameDB.club_short(club)]
		var line := MatchNotes.feed_line(e, "GEE", "CAR")
		if bool(e.get("for_injury", false)):
			# On for a hurt man: the injury line names him, once.
			_check(line.is_empty(), "A substitute on for an injury is said once, in the injury line")
		else:
			_check(str(line.get("text", "")) == want, "Feed calls the substitute: '%s'" % str(line.get("text", "")))
	for e in _events(sim, "injury"):
		if str(e.get("on_sub", "")) != "":
			var said := MatchNotes.story_feed_line({}, e)
			_check(said.contains("won't return: the substitute, "), "The injury line names the substitute: '%s'" % said)
	for e in sim.events:
		if str(e.get("kind", "")) == "sub" and not bool(e.get("substitute", false)):
			_check(MatchNotes.feed_line(e, "GEE", "CAR").is_empty(), "An interchange stays out of the feed")
			break


## 2021-2025: the substitute comes on only for an injured player.
func _test_medical_sub_2021() -> void:
	var seen_injury := false
	for seed in range(1, 40):
		var sim := _match(2021, seed)
		var subs := _events(sim, "substitute")
		var hurt := _events(sim, "injury")
		_check(subs.size() <= hurt.size(), "Seed %d: a 2021 substitute only for an injury (%d subs, %d injuries)"
				% [seed, subs.size(), hurt.size()])
		_check((sim.subbed_off[0] as Array).is_empty() and (sim.subbed_off[1] as Array).is_empty(),
				"Seed %d: nobody is subbed off fit in 2021" % seed)
		if not hurt.is_empty():
			seen_injury = true
			_check(not subs.is_empty(), "Seed %d: the injury brings the substitute on" % seed)
			for e in subs:
				_check(MatchNotes.feed_line(e, "GEE", "CAR").is_empty(),
						"The medical sub is said once, in the injury line")
			for e in hurt:
				if str(e.get("on", "")) != "":
					var said := MatchNotes.story_feed_line({}, e)
					_check(said.contains("won't return: the medical sub, ") and said.ends_with(", comes on."),
							"The injury line names the medical sub: '%s'" % said)
			break
	_check(seen_injury, "Some 2021 match in 40 seeds has an injury")


## 2016-2020: no substitute at all.
func _test_no_sub_2016() -> void:
	var sim := _match(2016, 31)
	_check(_events(sim, "substitute").is_empty() and (sim.squads[0] as Squad).sub.is_empty(),
			"No substitute in 2016")
	_check((sim.squads[0] as Squad).bench.size() == 4, "Four on a 2016 bench")


## The coaches' votes began in 2003 (director 2026-11-13, "Hide before 2003"):
## before it, no Coaches Award and no votes heading or counts at full time.
func _test_coaches_votes_from_2003() -> void:
	var want := {1990: false, 2002: false, 2003: true, 2025: true, 2026: true, 2027: true}
	for y in want:
		_check(EraRules.on("coaches_votes", y) == bool(want[y]), "%d coaches' votes %s" % [y, str(want[y])])
	var tally := {"p1": {"club": "FIT", "votes": 3, "polled": 1, "coaches": 10, "games": 1, "goals_ha": 2,
			"bf": 5, "influence": 9.0}}
	var players := {"p1": {"id": "p1", "club": "FIT", "first": "Paul", "last": "Roos", "age": 26}}
	_check((Awards.season_awards(tally, players, 1990)["coaches_award"] as Array).is_empty(),
			"1990: no Coaches Award")
	_check(not (Awards.season_awards(tally, players, 2003)["coaches_award"] as Array).is_empty(),
			"2003: a Coaches Award")
	var ms = load("res://scenes/MatchScene.tscn").instantiate()
	EraRules.year = 1990
	var h1: Control = ms.call("_votes_header")
	var f1: Control = ms.call("_votes_figure", {"p1": 10}, "p1")
	EraRules.year = 2026
	var h2: Control = ms.call("_votes_header")
	var f2: Control = ms.call("_votes_figure", {"p1": 10}, "p1")
	_check(not h1.visible and not f1.visible, "1990 full time: no votes heading, no vote counts")
	_check(h2.visible and f2.visible, "2026 full time: the votes heading and counts show")
	EraRules.year = 0
	for n in [h1, f1, h2, f2, ms]:
		n.free()
