extends RefCounted
## Season rules by year (P4, legacy mode): the table's rows, each past year's
## fixture shape (14, 15 and 16 clubs, byes every round at 15), every finals
## bracket played through to a premier with the real years' pairings, a drawn
## final replayed, the Grand Final's venue, no Gather Round before 2023, and
## the game's own league (2026 on) byte-identical to before season rules
## existed (tests/season_golden.gd).
## Run through tests/run_season_rules_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season here is built with its own seed (C15).
const SUITE_SEED := 2027

## tests/season_golden.gd's digest of the game's league, recorded from the
## code before season rules (commit 6e3e96a8). Any change is a change to the
## 2026 fixture or finals. The played seasons depend on the ratings data:
## GOLDEN as tools/run_tests.sh and CI run it (AFL_SKIP_OVR_ROWS=1, the
## ratings overrides off), PLAYED_WITH_OVR when the suite runs on its own.
## The played seasons were redrawn when the weather could turn at a break
## (row 160): a turned day plays on in the new condition.
const GOLDEN := {
	"fixture:1": "88379d64dfcfdf22f88fcc1bbcc1bab4",
	"fixture:2": "15aab1f43b8c605b37bc9eef32c73406",
	"fixture:3": "928bc55d620e04e745cf7adb88b56ae8",
	"fixture:2027": "57bffb38d600d4036767ef691d623a80",
	"fixture:90210": "1734a8fcc9068e3e444e293a25f944b4",
	"played:2027": "0d3f654039a6a254d39e9fbdaca5f102",
	"played:7": "11a9d3a80e35ead63e71c779940cc9b6",
}
const PLAYED_WITH_OVR := {
	"played:2027": "f717eb64566f9b222cb5125e5b4f238c",
	"played:7": "e2a5c195f8348fd1b759cd24ee8c7896",
}

const Golden := preload("res://tests/season_golden.gd")


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	# First: the other tests play seasons, which wear the shared player lists
	# (form, injuries), and the golden digest was recorded on fresh lists.
	_t("_test_golden_2026")
	_t("_test_rules_table")
	_t("_test_default_league")
	_t("_test_fixture_shapes")
	_t("_test_gather_round_from_2023")
	_t("_test_grand_final_venue")
	_t("_test_extra_time_or_replay")
	_t("_test_mcintyre_five")
	_t("_test_final_six")
	_t("_test_final_six_1991")
	_t("_test_mcintyre_eight")
	_t("_test_afl_eight_and_wildcard")
	_t("_test_drawn_final_replayed")
	_t("_test_week_titles")
	_t("_test_past_season_played_through")
	_t("_test_save_round_trip")
	GameState.replay_seed = 0
	print(Ran.line("Season rules", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _codes(n: int) -> Array:
	var all: Array = GameDB.active_clubs(2027).duplicate()
	return all.slice(0, n)


func _season(year: int, n: int, sd := 11) -> Season:
	var codes := _codes(n)
	return Season.new(codes, Golden.lists(codes), sd, year)


## A season of `year` with its finals open (the ladder order is the clubs'
## order; the seeds are read from finals["top"]).
func _finals(year: int) -> Season:
	var n := 18
	if year > 0 and year <= 1990:
		n = 14
	elif year > 0 and year <= 1994:
		n = 15
	elif year > 0 and year <= 1999:
		n = 16
	var s := _season(year, n)
	s.round_index = s.fixture.size()
	s.start_finals()
	return s


func _seed(s: Season, code: String) -> int:
	return (s.finals["top"] as Array).find(code) + 1


## Plays the finals with `pick` naming each final's winner; returns each week's
## pairings as "TAG:homeSeed-awaySeed ..." (a drawn final when pick returns "").
func _drive(s: Season, pick: Callable, weeks := 10) -> Array:
	var out := []
	var guard := 0
	while not s.is_season_over() and guard < weeks:
		guard += 1
		var week := []
		var played := []
		for m in s.finals_week_matches():
			var home := str(m["home"])
			var away := str(m["away"])
			_check(home != "" and away != "", "%s: both sides of %s are known when it is played" % [s.finals_format(), m["tag"]])
			week.append("%s:%d-%d" % [m["tag"], _seed(s, home), _seed(s, away)])
			var w := str(pick.call(s, m))
			var score := [70, 70] if w == "" else ([80, 60] if w == home else [60, 80])
			var res := {"home": home, "away": away, "score": score}
			s.record_final(m, res)
			played.append(res)
		s.complete_finals_week(played)
		out.append(" ".join(week))
	return out


func _higher(s: Season, m: Dictionary) -> String:
	return str(m["home"]) if _seed(s, str(m["home"])) < _seed(s, str(m["away"])) else str(m["away"])


func _lower(s: Season, m: Dictionary) -> String:
	return str(m["away"]) if _seed(s, str(m["home"])) < _seed(s, str(m["away"])) else str(m["home"])


func _premier_seed(s: Season) -> int:
	return _seed(s, str(s.finals.get("premier", "")))


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
## Every year 1990-2025 has exactly one row, each row names a bracket that
## exists, and the bracket seeds exactly the row's finalists.
func _test_rules_table() -> void:
	var rows := SeasonRules.rows()
	_check(rows.size() >= 10, "season_rules.csv has its rows (%d)" % rows.size())
	for y in range(1990, 2027):
		var hits := 0
		for r in rows:
			if y >= int(r["from_year"]) and y <= int(r["to_year"]):
				hits += 1
		_check(hits == 1, "%d is in exactly one row of season_rules.csv (%d)" % [y, hits])
		var rule := SeasonRules.for_year(y)
		var fmt := str(rule["finals"])
		_check(SeasonRules.BRACKETS.has(fmt), "%d's finals format %s is a bracket" % [y, fmt])
		var top := 0
		for week in SeasonRules.bracket(fmt):
			for e in week:
				for side in [str(e[2]), str(e[3])]:
					if side.begins_with("S") and side.substr(1).is_valid_int():
						top = maxi(top, int(side.substr(1)))
		_check(top == int(rule["finalists"]), "%d's bracket seeds its %d finalists (%d)" % [y, rule["finalists"], top])
		_check(SeasonRules.finals_weeks(fmt) == (SeasonRules.WEEK_NAMES[fmt] as Array).size(),
				"%s names every finals week" % fmt)
	_check(int(SeasonRules.for_year(1990)["finalists"]) == 5, "1990: a final five")
	_check(int(SeasonRules.for_year(1992)["finalists"]) == 6, "1992: a final six")
	_check(str(SeasonRules.for_year(1997)["finals"]) == "mcintyre8", "1997: the McIntyre final eight")
	_check(str(SeasonRules.for_year(2005)["finals"]) == "afl8", "2005: the AFL final eight")
	_check(int(SeasonRules.for_year(2020)["rounds"]) == 18, "2020: 18 rounds")


## The game's league (2027 on, or no year at all) is the old constants; so is
## a 2026 season whose clubs are not 2026's real ones (a created club). The
## real 2026 (its fixture, 25 rounds) is tests/test_real_fixture.gd's.
func _test_default_league() -> void:
	var created := _codes(17)
	created.append("TAS")
	for y in [0, 2026, 2027, 2040]:
		var s := _season(y, 18)
		if y == 2026:
			s = Season.new(created, Golden.lists(created), 11, y)
			_check(not s.is_real_fixture(), "2026 with a club that did not play it: a drawn fixture")
		_check(s.regular_rounds() == Season.REGULAR_ROUNDS, "%d: %d rounds" % [y, Season.REGULAR_ROUNDS])
		_check(s.finalists() == Season.FINALISTS, "%d: the top %d play finals" % [y, Season.FINALISTS])
		_check(s.finals_format() == "wildcard10", "%d: the wildcard finals" % y)
		_check(s.finals_weeks() == 5, "%d: five finals weeks" % y)
		_check(s.grand_final_venue() == Season.GRAND_FINAL_VENUE, "%d: the Grand Final at the MCG" % y)
		_check(s.fixture.size() == Season.REGULAR_ROUNDS, "%d: a %d-round fixture" % [y, Season.REGULAR_ROUNDS])


## Each past year's fixture: its rounds, every club its games, nobody twice in
## a round, an odd league's bye every round, every pair met once or twice,
## home and away near even.
func _test_fixture_shapes() -> void:
	# [year, clubs, rounds, games each]
	var cases := [[1990, 14, 22, 22], [1991, 15, 24, 22], [1993, 15, 22, 20], [1994, 15, 24, 22],
			[1997, 16, 22, 22], [2005, 16, 22, 22], [2012, 18, 23, 22], [2020, 18, 18, 17],
			[2023, 18, 24, 23], [2024, 18, 25, 23]]
	for c in cases:
		var y := int(c[0])
		var n := int(c[1])
		# 18 clubs are a real year's clubs (its real fixture); with one
		# changed the season is drawn, so the generator is checked too.
		var runs := [[0, 3], [0, 19]]
		if n == 18:
			runs += [[1, 3], [1, 19]]
		for run in runs:
			var variant := int(run[0])
			var sd := int(run[1])
			var codes := _codes(n)
			if variant == 1:
				codes[n - 1] = "TAS"
			var s := Season.new(codes, Golden.lists(codes), sd, y)
			var tag := "%d (%d clubs%s, seed %d)" % [y, n, ", one changed" if variant == 1 else "", sd]
			_check(s.fixture.size() == int(c[2]), "%s: %d rounds (%d)" % [tag, c[2], s.fixture.size()])
			var games := {}
			var home := {}
			var met := {}
			var empty := 0
			var no_bye := 0
			for r in s.fixture:
				var seen := {}
				if (r as Array).is_empty():
					empty += 1
				for m in r:
					var h := str(m["home"])
					var a := str(m["away"])
					_check(not seen.has(h) and not seen.has(a), "%s: no club plays twice in a round" % tag)
					seen[h] = true
					seen[a] = true
					games[h] = int(games.get(h, 0)) + 1
					games[a] = int(games.get(a, 0)) + 1
					home[h] = int(home.get(h, 0)) + 1
					var k := h + "-" + a if h < a else a + "-" + h
					met[k] = int(met.get(k, 0)) + 1
				if seen.size() == n:
					no_bye += 1
			_check(empty == 0, "%s: no empty round (%d)" % [tag, empty])
			if n % 2 == 1:
				_check(no_bye == 0, "%s: a bye every round" % tag)
			var bad := []
			for code in s.clubs:
				if int(games.get(code, 0)) != int(c[3]):
					bad.append("%s %d" % [code, games.get(code, 0)])
				var hg := int(home.get(code, 0))
				# A real fixture is as the AFL drew it (Hawthorn had 7 home games in 2020).
				if absi(hg - (int(c[3]) - hg)) > 2 and not s.is_real_fixture():
					bad.append("%s %d home" % [code, hg])
			_check(bad.is_empty(), "%s: every club %d games, home and away near even (%s)" % [tag, c[3], ", ".join(bad)])
			var pairs := n * (n - 1) / 2
			var lone := 0
			for k in met:
				if int(met[k]) > 2:
					lone += 100
			_check(met.size() == pairs and lone == 0, "%s: every pair meets once or twice (%d of %d pairs)" % [tag, met.size(), pairs])


func _test_gather_round_from_2023() -> void:
	for y in [1990, 2000, 2022]:
		_check(_season(y, 18 if y > 1999 else 14).gather_round() == -1, "%d: no Gather Round" % y)
	for y in [2023, 2025, 0]:
		_check(_season(y, 18).gather_round() >= 0, "%d: a Gather Round" % y)


func _test_grand_final_venue() -> void:
	var cases := {1990: "MCG", 1991: "Waverley Park", 2020: "The Gabba", 2021: "Optus Stadium", 2022: "MCG", 0: "MCG"}
	for y in cases:
		var s := _season(int(y), 18 if int(y) > 1999 or int(y) == 0 else 14)
		var m := {"tag": "GF", "home": s.clubs[0], "away": s.clubs[1]}
		_check(s.finals_venue(m) == str(cases[y]), "%d: the Grand Final at %s (%s)" % [y, cases[y], s.finals_venue(m)])


func _test_extra_time_or_replay() -> void:
	# [year, tag, extra time]
	for c in [[1990, "QF", false], [1990, "GF", false], [2000, "QF", true], [2010, "GF", false],
			[2016, "GF", true], [0, "GF", true], [0, "WC1", true]]:
		var s := _season(int(c[0]), 18 if int(c[0]) > 1999 or int(c[0]) == 0 else 14)
		_check(s.finals_extra_time({"tag": c[1]}) == bool(c[2]),
				"%d %s: %s" % [c[0], c[1], "extra time" if c[2] else "a drawn final is replayed"])


## 1990: 2nd v 3rd and 4th v 5th; the minor premier waits for the
## qualifying final's winner in the second semi.
func _test_mcintyre_five() -> void:
	var s := _finals(1990)
	_check(s.finals_format() == "mcintyre5" and (s.finals["top"] as Array).size() == 5, "1990: five finalists")
	var log := _drive(s, _higher)
	_check(log == ["QF:2-3 EF:4-5", "SF1:3-4 SF2:1-2", "PF:2-3", "GF:1-2"],
			"1990 favourites: the McIntyre final five's road (%s)" % " | ".join(log))
	_check(_premier_seed(s) == 1 and s.is_season_over(), "1990 favourites: the minor premier wins the flag")
	s = _finals(1990)
	log = _drive(s, _lower)
	# Lower wins: W_QF 3, L_QF 2, W_EF 5; SF1 2 v 5 -> 5; SF2 1 v 3 -> 3 (L 1);
	# PF L_SF2 1 v W_SF1 5 -> 5; GF W_SF2 3 v W_PF 5 -> 5.
	_check(log == ["QF:2-3 EF:4-5", "SF1:2-5 SF2:1-3", "PF:1-5", "GF:3-5"],
			"1990 upsets: the McIntyre final five's road (%s)" % " | ".join(log))
	_check(_premier_seed(s) == 5, "1990 upsets: fifth wins the flag")


## 1992-93: 1st v 2nd (both go on), 3rd v 6th, 4th v 5th; the higher
## elimination winner meets the qualifying winner.
func _test_final_six() -> void:
	var s := _finals(1992)
	_check(s.finals_format() == "final6" and (s.finals["top"] as Array).size() == 6, "1992: six finalists")
	var log := _drive(s, _lower)
	_check(log == ["QF:1-2 EF1:3-6 EF2:4-5", "SF1:2-5 SF2:1-6", "PF:2-6", "GF:5-6"],
			"1992 upsets: the final six's road (%s)" % " | ".join(log))
	_check(_premier_seed(s) == 6, "1992 upsets: sixth wins the flag")
	s = _finals(1993)
	log = _drive(s, _higher, 1)
	_check(not s.finals_eliminated(str(s.finals["top"][1])), "1993: the qualifying final's loser plays on")
	_check(s.finals_eliminated(str(s.finals["top"][5])), "1993: an elimination final's loser is out")
	log += _drive(s, _higher)
	_check(log == ["QF:1-2 EF1:3-6 EF2:4-5", "SF1:1-3 SF2:2-4", "PF:2-3", "GF:1-2"],
			"1993 favourites: the final six's road (%s)" % " | ".join(log))


## 1991 drew its first week 3rd v 4th and 5th v 6th; the Grand Final at Waverley.
func _test_final_six_1991() -> void:
	var s := _finals(1991)
	var log := _drive(s, _higher)
	_check(log == ["QF:1-2 EF1:3-4 EF2:5-6", "SF1:1-3 SF2:2-5", "PF:2-3", "GF:1-2"],
			"1991 favourites: the final six's road (%s)" % " | ".join(log))
	var gf: Dictionary = (s.finals["weeks"] as Array).back()[0]
	_check(str(gf.get("venue", "")) == "Waverley Park", "1991: the Grand Final at Waverley Park (%s)" % gf.get("venue", ""))


## 1994-99: 1v8, 2v7, 3v6, 4v5; the two best-placed winners rest a week, the
## two worst-placed losers go out.
func _test_mcintyre_eight() -> void:
	var s := _finals(1997)
	_check(s.finals_format() == "mcintyre8" and (s.finals["top"] as Array).size() == 8, "1997: eight finalists")
	var log := _drive(s, _higher, 1)
	_check(log == ["QF1:1-8 QF2:2-7 QF3:3-6 QF4:4-5"], "1997 week one (%s)" % " | ".join(log))
	var top: Array = s.finals["top"]
	_check(s.finals_eliminated(str(top[6])) and s.finals_eliminated(str(top[7])), "1997: seventh and eighth out after losing")
	_check(not s.finals_eliminated(str(top[4])) and not s.finals_eliminated(str(top[5])), "1997: fifth and sixth play on after losing")
	log = _drive(s, _higher)
	_check(log == ["SF1:3-5 SF2:4-6", "PF1:1-4 PF2:2-3", "GF:1-2"], "1997 favourites: the road on (%s)" % " | ".join(log))
	# Eighth beats first: winners rank 2, 3, 4, 8 and losers 1, 5, 6, 7.
	s = _finals(1998)
	var upset := func(ss: Season, m: Dictionary) -> String:
		return str(m["away"]) if str(m["tag"]) == "QF1" else _higher(ss, m)
	log = _drive(s, upset)
	_check(log == ["QF1:1-8 QF2:2-7 QF3:3-6 QF4:4-5", "SF1:4-1 SF2:8-5", "PF1:2-5 PF2:3-1", "GF:1-2"],
			"1998, eighth beats first: the McIntyre eight reranks (%s)" % " | ".join(log))
	top = s.finals["top"]
	_check(_premier_seed(s) == 1 and not s.finals_eliminated(str(top[0])), "1998: first plays on after losing to eighth, and wins the flag")


func _test_afl_eight_and_wildcard() -> void:
	var s := _finals(2005)
	var log := _drive(s, _higher, 1)
	_check(s.finals_eliminated(str(s.finals["top"][7])) and not s.finals_eliminated(str(s.finals["top"][3])),
			"2005: an elimination final's loser is out, a qualifying final's is not")
	log += _drive(s, _higher)
	_check(log == ["QF1:1-4 QF2:2-3 EF1:5-8 EF2:6-7", "SF1:4-5 SF2:3-6", "PF1:1-3 PF2:2-4", "GF:1-2"],
			"2005 favourites: the AFL final eight (%s)" % " | ".join(log))
	s = _finals(0)
	log = _drive(s, _higher)
	_check(log == ["WC1:7-10 WC2:8-9", "QF1:1-4 QF2:2-3 EF1:5-8 EF2:6-7", "SF1:4-5 SF2:3-6", "PF1:1-3 PF2:2-4", "GF:1-2"],
			"The game's league: the wildcard round, then the final eight (%s)" % " | ".join(log))


## 1990's qualifying final was drawn and played again the next week; the
## bracket waits for it.
func _test_drawn_final_replayed() -> void:
	var s := _finals(1990)
	var draw_qf := func(ss: Season, m: Dictionary) -> String:
		return "" if str(m["tag"]) == "QF" and not str(m["label"]).ends_with("Replay") else _higher(ss, m)
	var log := _drive(s, draw_qf, 1)
	_check(log == ["QF:2-3 EF:4-5"], "1990 week one (%s)" % " | ".join(log))
	_check(int(s.finals["week"]) == 1 and s.finals.get("replay", []) == ["QF"], "1990: the drawn qualifying final holds the week")
	var ms := s.finals_week_matches()
	_check(ms.size() == 1 and str(ms[0]["label"]) == "Qualifying Final Replay", "1990: the next week is the replay alone")
	_check(s.finals_round() == 22 + 2, "1990: the replay is the season's 24th week (%d)" % s.finals_round())
	_check(s.finals_eliminated(str(s.finals["top"][4])), "1990: the elimination final's loser is out meanwhile")
	log = _drive(s, draw_qf)
	_check(log == ["QF:2-3", "SF1:3-4 SF2:1-2", "PF:2-3", "GF:1-2"], "1990: the series goes on after the replay (%s)" % " | ".join(log))
	_check(int(s.finals.get("replays", 0)) == 1 and s.is_season_over(), "1990: one replay, a premier")
	var weeks: Array = s.finals["weeks"]
	_check(weeks.size() == 5 and int((weeks.back()[0] as Dictionary)["round"]) == 22 + 5,
			"1990: the Grand Final the season's 27th week")
	# A drawn Grand Final from 1991 to 2015 is replayed; the game's league goes to extra time.
	s = _finals(2010)
	var draw_gf := func(ss: Season, m: Dictionary) -> String:
		return "" if str(m["label"]) == "Grand Final" else _higher(ss, m)
	log = _drive(s, draw_gf)
	_check(log.back() == "GF:1-2" and log.size() == 5 and s.is_season_over(), "2010: the drawn Grand Final is replayed (%s)" % " | ".join(log))


func _test_week_titles() -> void:
	var sf = load("res://scripts/ui/stats/StatsFixture.gd")
	var s := _finals(0)
	_check(sf.week_titles(s) == sf.FINALS_WEEKS, "The game's league: the five finals pages as before")
	s = _finals(1990)
	_check(sf.week_titles(s) == ["Qualifying and elimination finals", "Semi finals", "Preliminary final", "Grand Final"],
			"1990: the four finals pages (%s)" % [sf.week_titles(s)])
	var draw_qf := func(ss: Season, m: Dictionary) -> String:
		return "" if str(m["tag"]) == "QF" and not str(m["label"]).ends_with("Replay") else _higher(ss, m)
	_drive(s, draw_qf, 1)
	var t: Array = sf.week_titles(s)
	_check(t.size() == 5 and str(t[1]) == "Qualifying Final Replay", "1990: the replay has its own page (%s)" % [t])


## A past season simulated through: the engine plays 1990's league (14 clubs,
## no extra time) and 1991's (15 clubs, byes) to a premier. Two rounds are
## simulated (1991's with a bye club resting); the rest of the home and away
## rounds take a fixed result each, since the finals are what is played through.
func _test_past_season_played_through() -> void:
	for y in [1990, 1991]:
		var s := _season(y, 14 if y == 1990 else 15, 5)
		var simmed := 0
		for r in range(2):
			simmed += (s.fixture[r] as Array).size()
			s.play_round()
		var p := 0
		for row in s.ladder_sorted():
			p += int(row["p"])
		_check(simmed == (s.clubs.size() / 2) * 2 and p == simmed * 2,
				"%d: the two simulated rounds' %d games are on the ladder (%d)" % [y, simmed, p])
		while not s.is_regular_done():
			for m in s.fixture[s.round_index]:
				s.record_regular({"home": str(m["home"]), "away": str(m["away"]), "score": [80 + s.round_index, 60]})
			s.round_index += 1
			s.recalc_ladder()
		p = 0
		for row in s.ladder_sorted():
			p += int(row["p"])
		_check(p == s.clubs.size() * s.games_per_club(), "%d: every home-and-away game on the ladder (%d)" % [y, p])
		s.start_finals()
		var guard := 0
		while not s.is_season_over() and guard < 10:
			guard += 1
			s.play_finals_week()
		_check(s.is_season_over() and str(s.finals["premier"]) != "", "%d: a premier" % y)
		_check((s.finals["weeks"] as Array).size() == 4 + int(s.finals.get("replays", 0)),
				"%d: four finals weeks and any replays" % y)


## The season saves its year, not its rules: a reload reads the shape again
## from the year, and an old save (no year) is the game's league.
func _test_save_round_trip() -> void:
	var s := _season(1990, 14, 8)
	var sv := CareerSave.object_vars(s)
	sv.erase("rules")
	sv = JSON.parse_string(JSON.stringify(sv))
	_check(int(sv.get("year", 0)) == 1990, "A season's save keeps its year")
	var back := Season.new(sv["clubs"], s.lists, int(sv["seed"]), int(sv.get("year", 0)))
	CareerSave.apply_vars(back, sv)
	_check(back.finalists() == 5 and back.regular_rounds() == 22 and back.finals_format() == "mcintyre5",
			"1990 reloads as 1990: a final five, 22 rounds")
	sv.erase("year")
	var old := Season.new(sv["clubs"], s.lists, int(sv["seed"]), int(sv.get("year", 0)))
	CareerSave.apply_vars(old, sv)
	_check(old.year == 0 and old.finalists() == Season.FINALISTS, "A save from before season rules loads as the game's league")
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	_check(GameState.season.year == GameState.season_year and GameState.season.finals_format() == "wildcard10",
			"A new career's season carries its year (%d) and the game's league" % GameState.season.year)
	var saved: Dictionary = GameState._season_to_save()
	_check(saved.has("year") and not saved.has("rules"), "The career save writes the year, not the rules")


## The game's league is byte-identical to before season rules: the fixture
## for five seeds and two seasons played through the finals.
func _test_golden_2026() -> void:
	var d: Dictionary = Golden.digest(2027)
	_check(GOLDEN.size() == Golden.FIXTURE_SEEDS.size() + Golden.PLAYED_SEEDS.size(), "The golden digest is recorded")
	for k in GOLDEN:
		var want := str(GOLDEN[k])
		if not GameDB.skip_ovr_overrides and PLAYED_WITH_OVR.has(k):
			want = str(PLAYED_WITH_OVR[k])
		_check(str(d.get(k, "")) == want, "2026 league unchanged: %s (%s, was %s)" % [k, d.get(k, ""), want])
