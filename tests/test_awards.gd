extends RefCounted
## Awards: 3-2-1 Brownlow votes per home-and-away match (none in finals),
## 5-4-3-2-1 best-and-fairest points per side, and a full season producing
## the Brownlow, Coleman, Rising Star, club B&Fs, a valid All-Australian 22,
## the honour roll and records - all surviving a save.
## Run through tests/run_awards_tests.gd.

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
	_t("_test_vote_arithmetic")
	_t("_test_brownlow_eligibility")
	_t("_test_norm_smith_rules")
	_t("_test_comeback_records")
	_t("_test_bf_names")
	_t("_test_career_record")
	_t("_test_golden_fist_rule")
	_t("_test_golden_fist_trophy_room")
	_t("_test_award_count_rounds")
	_t("_test_full_season")
	_t("_test_award_count_late_start")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Awards", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


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


## The club best and fairest by its real name (P-54, data/bf_medals.json).
func _test_bf_names() -> void:
	var want := {"ADE": "Malcolm Blight Medal", "BRL": "Merrett–Murray Medal", "CAR": "John Nicholls Medal",
			"COL": "Copeland Trophy", "ESS": "Crichton Medal", "FRE": "Doig Medal", "GEE": "Carji Greeves Medal",
			"GCS": "Club Champion", "GWS": "Kevin Sheedy Medal", "HAW": "Peter Crimmins Medal",
			"MEL": "Keith \"Bluey\" Truscott Medal", "NTH": "Syd Barker Medal", "PAD": "John Cahill Medal",
			"RIC": "Jack Dyer Medal", "STK": "Trevor Barker Award", "SYD": "Bob Skilton Medal",
			"WCE": "John Worsfold Medal", "WBD": "Charles Sutton Medal"}
	var wrong := []
	for code in want:
		if BestAndFairest.award_name(code) != str(want[code]):
			wrong.append("%s: %s" % [code, BestAndFairest.award_name(code)])
	_check(wrong.is_empty(), "All 18 real clubs carry their own best and fairest name (%s)" % str(wrong))
	var sourced := true
	for code in want:
		var e: Dictionary = BestAndFairest.data()["clubs"].get(code, {})
		sourced = sourced and str(e.get("source", "")).begins_with("https://")
	_check(sourced, "Every medal name records the page it was checked against")
	for code in ["TAS", "CANB", "FORGE", ""]:
		_check(BestAndFairest.award_name(code) == "Best and fairest" and not BestAndFairest.is_named(code),
				"%s has no medal of its own and keeps Best and fairest" % (code if code != "" else "No club"))
	_check(BestAndFairest.heading("FRE", "Fremantle") == "Doig Medal"
			and BestAndFairest.heading("FORGE", "Redbacks") == "Redbacks best and fairest",
			"A heading is the medal's name, or the club's best and fairest")
	_check(BestAndFairest.count_line("NTH", "North Melbourne", 1) == "Syd Barker Medal"
			and BestAndFairest.count_line("NTH", "North Melbourne", 3) == "3 Syd Barker Medals"
			and BestAndFairest.count_line("COL", "Collingwood", 2) == "2 Copeland Trophies"
			and BestAndFairest.count_line("FORGE", "Redbacks", 2) == "2 Redbacks best and fairests",
			"A coach's count reads in the medal's own words")
	# Wherever a club best and fairest is named, the medal's name is used (T5.Q19).
	var fre := Remembered.facts({}, {}, "FRE", {"bf": [2030]}, {})
	var forge := Remembered.facts({}, {}, "FORGE", {"bf": [2030]}, {})
	_check(str(fre[0]["sheet"]) == "Doig Medal, 2030." and str(fre[0]["said"]) == "He won the Doig Medal in 2030.",
			"A remembered best and fairest carries the medal's name (%s)" % str(fre[0]))
	_check(str(forge[0]["sheet"]) == "Best and fairest, 2030." and str(forge[0]["said"]) == "He won your best and fairest in 2030.",
			"A club with no medal keeps best and fairest (%s)" % str(forge[0]))
	var hero := str(Almanac.story_parts({"club": "NTH", "year": 2030, "bf": [{"name": "J. Smith"}]}, {})["hero"])
	_check(hero == "J. Smith won the Syd Barker Medal.", "The almanac story names the medal (%s)" % hero)
	hero = str(Almanac.story_parts({"club": "FORGE", "year": 2030, "bf": [{"name": "J. Smith"}]}, {})["hero"])
	_check(hero == "J. Smith won the best and fairest.", "A club with no medal keeps best and fairest (%s)" % hero)
	hero = str(Almanac.story_parts({"club": "GCS", "year": 2030, "bf": [{"name": "J. Smith"}]}, {})["hero"])
	_check(hero == "J. Smith won the best and fairest.", "A club champion award is not said as 'won the Club Champion' (%s)" % hero)
	# A wildcard final comes before the qualifying finals and the Grand Final.
	_check(Remembered._time(2030, "Wildcard Final 1") < Remembered._time(2030, "Qualifying Final 1")
			and Remembered._time(2030, "Wildcard Final 2") < Remembered._time(2030, "Grand Final")
			and Remembered._time(2030, "Round 24") < Remembered._time(2030, "Wildcard Final 1"),
			"A remembered wildcard final sorts in finals week one")
	var gcs := Remembered.facts({}, {}, "GCS", {"bf": [2030]}, {})
	_check(str(gcs[0]["said"]) == "He won your best and fairest in 2030.", "Gold Coast's line reads naturally (%s)" % str(gcs[0]))
	var legend := {"honours": {"bf": {"FRE": 3, "FORGE": 3}}}
	var lm := Almanac.legend_marks(legend, "FRE")
	_check(lm.has("3 Doig Medals"), "A legend's medal tally names the medal (%s)" % str(lm))
	lm = Almanac.legend_marks(legend, "FORGE")
	_check(lm.has("3 %s best and fairests" % GameDB.club_name("FORGE")), "A club with no medal keeps best and fairests (%s)" % str(lm))


## The Career section's facts (CareerRecord, T5.r110): only what is on record,
## each said once, nothing for a player yet to play.
func _test_career_record() -> void:
	var names := func(c): return {"FRE": "Fremantle", "MEL": "Melbourne"}.get(c, c)
	var rookie := {"id": "r1", "career": Career.fresh()}
	_check(CareerRecord.lines(rookie, [], Milestones.empty(), "FRE", names).is_empty(),
			"A player yet to play has no career facts")
	_check(PlayerSheet._only_club(rookie, "FRE"),
			"A first-season player's games are all his With us line's, so the totals are not said twice")
	var unknown := {"id": "u1", "career": {"games": 0, "goals": 0, "through": 0, "unknown": [[0, 2025]],
			"stints": [["FRE", 2020, 2025, 80, 10]]}}
	_check(CareerRecord.lines(unknown, [], Milestones.empty(), "FRE", names).is_empty(),
			"No debut is guessed for a career not on record in full")
	var vet := {"id": "v1", "career": {"games": 210, "goals": 90, "through": 2031, "unknown": [],
			"stints": [["MEL", 2020, 2027, 150, 60], ["FRE", 2028, 2031, 60, 30]]},
			"honours": {"bf": {"MEL": 2}, "aa": 1, "captain": {"FRE": 2}},
			"firsts": {}}
	var roll := [
		{"year": 2026, "premier": "MEL", "my_club": "FRE", "brownlow": [{"id": "v1"}]},
		{"year": 2029, "premier": "FRE", "my_club": "FRE", "my_bf": [{"id": "v1"}], "my_aa": ["v1"]},
		{"year": 2030, "premier": "FRE", "my_club": "FRE", "brownlow": [{"id": "v1"}], "norm_smith": [{"id": "x"}]},
	]
	var ml := Milestones.empty()
	ml["log"] = [{"who": "player", "kind": "games", "value": 200, "id": "v1", "year": 2030, "label": "Round 9"},
			{"who": "player", "kind": "debut", "value": 1, "id": "v1", "year": 2020, "label": "Round 1"},
			{"who": "player", "kind": "games", "value": 100, "id": "other", "year": 2030, "label": "Round 9"}]
	var texts := CareerRecord.lines(vet, roll, ml, "FRE", names).map(func(l): return str(l["text"]))
	var want := ["Debuted in 2020, for Melbourne.", "200th game in Round 9, 2030.",
			"At Melbourne for the 2026 premiership.", "At Fremantle for the 2029 and 2030 premierships.",
			"Brownlow Medal 2026, 2030.", "%s 2029." % BestAndFairest.heading("FRE", "Fremantle"),
			"%s at Melbourne." % BestAndFairest.count_line("MEL", "Melbourne", 2), "All-Australian 2029.",
			"Captain of Fremantle, 2 seasons."]
	_check(texts == want, "A veteran's career facts, in order (%s)" % str(texts))
	# What his "With us" lines say is left to them.
	var skipped := CareerRecord.lines(vet, roll, ml, "FRE", names, {"flag:2029": true, "bf:2029": true})
	var st := skipped.map(func(l): return str(l["text"]))
	_check(st.has("At Fremantle for the 2030 premiership.") and not str(st).contains("2029 and")
			and not st.has("%s 2029." % BestAndFairest.heading("FRE", "Fremantle")),
			"A flag or best and fairest the With us block says is not said again (%s)" % str(st))
	_check(skipped.filter(func(l): return bool(l["bold"])).size() == skipped.size() - 3,
			"Honours are bold, the debut, milestone and captaincy plain")
	# A debut he made for you names the match.
	vet["firsts"] = {"debut": {"year": 2028, "label": "Round 3"}}
	vet["career"]["stints"] = [["FRE", 2028, 2031, 60, 30]]
	_check(str(CareerRecord.lines(vet, [], Milestones.empty(), "FRE", names)[0]["text"]) == "Debuted in Round 3, 2028, for Fremantle.",
			"A debut for you names the match")
	_check(str(CareerRecord.lines(vet, [], Milestones.empty(), "FRE", names, {"debut": true})).find("Debuted") < 0,
			"...unless his With us lines already say it")
	var keys := Remembered.sheet_keys({"firsts": {"debut": {"year": 2028, "label": "Round 3"}}}, {}, "FRE",
			{"flags": [2030], "bf": [2029]}, {})
	_check(keys.has("debut") and keys.has("flag:2030") and keys.has("bf:2029"),
			"The With us lines name what they say (%s)" % str(keys))


func _test_vote_arithmetic() -> void:
	var res := _one_match()
	var tally := {}
	Awards.tally_match(tally, res, true)
	_check(_sum(tally, "votes") == 6, "A home-and-away match hands out 3-2-1 votes")
	_check(_sum(tally, "coaches") == 15, "A home-and-away match hands out 5-4-3-2-1 coaches votes")
	_check(_sum(tally, "bf", "GEE") == 15 and _sum(tally, "bf", "HAW") == 15,
			"Each side hands out 5-4-3-2-1 best-and-fairest points")
	var finals := {}
	Awards.tally_match(finals, res, false)
	_check(_sum(finals, "votes") == 0 and _sum(finals, "coaches") == 0 and _sum(finals, "goals_ha") == 0,
			"Finals give no Brownlow/coaches votes and no Coleman goals")
	_check(_sum(finals, "goals") > 0, "Finals goals still count in the season tally")


## Ineligibility changes only who can receive the medal. Votes remain in
## raw order, and a successful challenge (flag cleared) restores eligibility.
func _test_brownlow_eligibility() -> void:
	var tally := {
		"reported": {"club": "GEE", "games": 20, "goals_ha": 10, "votes": 30,
				"coaches": 40, "bf": 50, "influence": 160.0},
		"eligible": {"club": "HAW", "games": 20, "goals_ha": 8, "votes": 24,
				"coaches": 35, "bf": 45, "influence": 150.0},
	}
	var players := {
		"reported": {"role": "MID", "age": 26.0, "brownlow_ineligible": true},
		"eligible": {"role": "MID", "age": 25.0},
	}
	var aw := Awards.season_awards(tally, players, 2030)
	var count: Array = aw["brownlow"]
	_check(str(count[0]["id"]) == "reported" and int(count[0]["votes"]) == 30
			and not bool(count[0]["brownlow_eligible"]),
			"An ineligible player keeps every vote and stays in raw vote order")
	_check(str((aw["brownlow_winner"] as Dictionary).get("id", "")) == "eligible",
			"The medal goes to the highest eligible poller")
	(players["reported"] as Dictionary).erase("brownlow_ineligible")
	var appealed := Awards.season_awards(tally, players, 2030)
	_check(str((appealed["brownlow_winner"] as Dictionary).get("id", "")) == "reported",
			"A successful appeal restores Brownlow eligibility without changing votes")


## The Norm Smith Medal: the most influential player of the Grand Final from
## either side, by the same measure as the votes, and the same man every time.
func _test_norm_smith_rules() -> void:
	var res := _one_match()
	res["tag"] = "GF"
	var before := JSON.stringify(res)
	var best := {}
	for side in range(2):
		for r in res["roster"][side]:
			var inf := CoachReport.influence(res["players"].get(str(r["id"]), {}))
			if best.is_empty() or inf > float(best["inf"]):
				best = {"id": str(r["id"]), "inf": inf, "side": side}
	var m := Awards.norm_smith(res)
	_check(str(m.get("id", "")) == str(best["id"]) and float(m["influence"]) == float(best["inf"]),
			"The Norm Smith Medal goes to the most influential player on the ground")
	_check(str(m["club"]) == str([res["home"], res["away"]][int(best["side"])]),
			"...and carries his own club")
	_check(Awards.norm_smith(res) == m and JSON.stringify(res) == before,
			"The same match always names the same man, and the result is left untouched")
	_check(str(m["line"]) == Awards.plain_line(res["players"][str(m["id"])]),
			"His line is in plain words (%s)" % str(m["line"]))
	_check(Awards.plain_line({"goals": 3.0, "disposals": 25.0, "marks": 8.0, "tackles": 2.0}) == "3 goals, 25 disposals and 8 marks"
			and Awards.plain_line({"goals": 1.0, "disposals": 1.0, "tackles": 5.0, "marks": 9.0}) == "1 goal, 1 disposal and 9 marks"
			and Awards.plain_line({"disposals": 30.0, "tackles": 7.0, "marks": 4.0, "behinds": 2.0}) == "30 disposals and 7 tackles"
			and not Awards.plain_line({"disposals": 22.0, "clearances": 11.0, "inside50": 6.0}).contains("CLR"),
			"At most three headline figures, goals first, no codes or percentages")
	# The losing side can win it: lift one of the beaten side's players clear.
	var home_won: bool = int(res["score"][0]) > int(res["score"][1])
	var loser_side := 1 if home_won else 0
	var star: String = str(res["roster"][loser_side][0]["id"])
	res["players"][star] = {"disposals": 60.0, "goals": 9.0}
	var lm := Awards.norm_smith(res)
	_check(str(lm["id"]) == star and str(lm["club"]) == str([res["home"], res["away"]][loser_side]),
			"A player on the losing side can win the medal")
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var plain: Dictionary = res.duplicate(true)
	plain.erase("tag")
	_check(GameState.norm_smith_for(plain).is_empty(), "Only a Grand Final has a Norm Smith Medal")
	var shown: Dictionary = GameState.norm_smith_for(res)
	_check(str(shown.get("text", "")).begins_with("Norm Smith Medal: ")
			and str(shown["text"]).contains(GameDB.club_name(str(shown["club"])))
			and str(shown["text"]).ends_with(str(shown["line"])),
			"The result line reads 'Norm Smith Medal: name (club), stat line' (%s)" % str(shown.get("text", "")))
	_check(Awards.norm_smith({}).is_empty(), "A match with no player stats names nobody")


func _find_player(id: String) -> Dictionary:
	var groups: Array = [GameState.my_list, GameState.free_agents]
	for code in GameState.season.lists:
		groups.append(GameState.season.lists[code])
	for arr in groups:
		for p in arr:
			if p is Dictionary and str(p.get("id", "")) == id:
				return p
	var gone = GameState.departed_names.get(id)
	return gone if gone is Dictionary and (gone as Dictionary).has("attr") else {}


func _test_full_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	var aw: Dictionary = GameState.season_awards
	_check(int(aw.get("year", 0)) == GameDB.START_YEAR, "The season's awards are decided at the Grand Final")
	var brownlow: Array = aw.get("brownlow", [])
	var brownlow_winner: Dictionary = aw.get("brownlow_winner", {})
	_check(not brownlow_winner.is_empty() and int(brownlow_winner["votes"]) >= 15,
			"A Brownlow medallist with a real tally (%d)" % (int(brownlow_winner.get("votes", 0))))
	var coaches: Array = aw.get("coaches_award", [])
	_check(not coaches.is_empty() and int(coaches[0]["coaches"]) > 0,
			"A Coaches Award winner comes from accumulated match votes")
	var coleman: Array = aw.get("coleman", [])
	_check(not coleman.is_empty() and int(coleman[0]["goals"]) >= 30,
			"A Coleman medallist with a real tally (%d)" % (int(coleman[0]["goals"]) if not coleman.is_empty() else 0))
	# A credible scorer wins it: across 8 drafted-league seasons every
	# medallist was a spearman (59-81 goals, 1.6-2.6 a game in 2026) and no
	# 60-goal season came from a below-median kick. Unusual winners stay
	# possible; a middling forward funnelled into a Coleman does not.
	if not coleman.is_empty():
		var kicks := []
		var winner := {}
		for c in GameState.season.lists:
			for p in GameState.season.lists[c]:
				if str(p.get("role", "")) == "FWD":
					kicks.append(float(p["attr"]["goalkicking"]))
		# He may have been delisted as the season closed (the off-season opens
		# first), so look him up as the screens do: lists, then free agents.
		winner = _find_player(str(coleman[0].get("id", "")))
		kicks.sort()
		var median: float = kicks[kicks.size() / 2]
		_check(not winner.is_empty() and float(winner["attr"]["goalkicking"]) >= median,
				"The Coleman medallist can kick goals (%d, league forward median %d)" % [
				int(winner.get("attr", {}).get("goalkicking", 0)), int(median)])
	var rising: Array = aw.get("rising_star", [])
	_check(not rising.is_empty() and float(rising[0]["age"]) <= Awards.RISING_STAR_AGE,
			"A Rising Star aged 21 or under")
	_check((aw.get("best_and_fairest", {}) as Dictionary).size() == GameState.season.ladder.size(),
			"Every active club has a best and fairest")
	var aa: Array = aw.get("all_australian", [])
	var slots := {}
	var ids := {}
	var games_ok := true
	for r in aa:
		slots[str(r["slot"])] = int(slots.get(str(r["slot"]), 0)) + 1
		ids[str(r["id"])] = true
		if int(r["games"]) < Awards.AA_MIN_GAMES:
			games_ok = false
	_check(aa.size() == 23 and ids.size() == 23, "The All-Australian team is 23 different players")
	_check(slots == {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6, "BENCH": 5},
			"All-Australian is the 6-6-6 shape (1 ruck, 5 mids, 6 def, 6 fwd) plus 5 (%s)" % str(slots))
	_check(games_ok, "All-Australians played 12+ games")
	_check(GameState.honour_roll.size() == 1 and not GameState.records.is_empty(),
			"The honour roll and records are written")
	_check(GameState.award_name(brownlow_winner) != "", "Award winners have names")
	# The Norm Smith Medal: from the Grand Final itself, recorded, in the news.
	var gf := {}
	for week in GameState.season.finals.get("weeks", []):
		for r in week:
			if str(r.get("tag", "")) == "GF":
				gf = r
	var nsm: Dictionary = aw.get("norm_smith", {})
	_check(not gf.is_empty() and not nsm.is_empty() and nsm == Awards.norm_smith(gf),
			"The season's awards name the Grand Final's most influential player")
	var roll_ns: Array = (GameState.honour_roll.back() as Dictionary).get("norm_smith", [])
	_check(roll_ns.size() == 1 and str(roll_ns[0]["id"]) == str(nsm.get("id", "x")),
			"The Norm Smith Medal is recorded on the honour roll beside the premier")
	var ns_news := ""
	for item in GameState.news:
		if str(item["text"]).begins_with("Norm Smith Medal: "):
			ns_news = str(item["text"])
	_check(ns_news == "Norm Smith Medal: %s (%s), %s" % [GameState.award_name(nsm),
			GameDB.club_name(str(nsm.get("club", ""))), str(nsm.get("line", ""))],
			"The news says it in plain words (%s)" % ns_news)
	var nsm_id: String = str(nsm.get("id", ""))
	_check(GameState.norm_smith_years(nsm_id) == [GameDB.START_YEAR],
			"His profile can list the year he won it")
	# An older save: a season with no Norm Smith on its entry loads and says nothing.
	var kept_roll: Array = GameState.honour_roll.duplicate(true)
	var old_roll: Array = GameState.honour_roll.duplicate(true)
	(old_roll[0] as Dictionary).erase("norm_smith")
	GameState.honour_roll = old_roll
	GameState.save_career()
	GameState.load_career()
	_check(GameState.honour_roll.size() == 1 and GameState.norm_smith_years(nsm_id).is_empty(),
			"An old save's season has no Norm Smith recorded and is not back-filled")
	GameState.honour_roll = kept_roll
	# The Golden Fist (T5.Q11c): a listed defender with the games, the same
	# answer from the same book, on the honour roll and in the news.
	var fist: Array = aw.get("golden_fist", [])
	var fist_id := str(fist[0].get("id", "")) if not fist.is_empty() else ""
	var fist_p := _find_player(fist_id)
	_check(not fist.is_empty() and str(fist_p.get("role", "")) == "DEF" and int(fist[0]["games"]) >= Awards.AA_MIN_GAMES,
			"The Golden Fist goes to a defender with 12+ games (%s, %s)" % [fist_id, str(fist_p.get("role", ""))])
	var fist_players := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			fist_players[str(p["id"])] = p
	for r in fist:
		var q := _find_player(str(r["id"]))
		if not q.is_empty():
			fist_players[str(r["id"])] = q
	var again := Awards.golden_fist(GameState.season_stats, fist_players)
	_check(not again.is_empty() and str(again[0]["id"]) == fist_id,
			"The same season's book names the same Golden Fist winner (seed %d)" % SUITE_SEED)
	var roll_fist: Array = (GameState.honour_roll.back() as Dictionary).get("golden_fist", [])
	_check(roll_fist.size() == 1 and str(roll_fist[0]["id"]) == fist_id,
			"The Golden Fist is kept on the honour roll")
	var fist_news := ""
	for item in GameState.news:
		if str(item["text"]).contains(Awards.GOLDEN_FIST):
			fist_news = str(item["text"])
	_check(not fist.is_empty() and fist_news == "%s (%s) won the %s with %s." % [GameState.award_name(fist[0]),
			GameDB.club_name(str(fist[0]["club"])), Awards.GOLDEN_FIST, Awards.golden_fist_line(fist[0])],
			"The news names the Golden Fist with what won it (%s)" % fist_news)
	var alm: Dictionary = GameState.almanac.back()
	_check((alm.get("golden_fist", []) as Array).size() == 1
			and str(alm["golden_fist"][0].get("id", "")) == fist_id,
			"The almanac's season page keeps the Golden Fist")
	# An older save: no Golden Fist anywhere loads cleanly and is not back-filled.
	var kept_awards: Dictionary = GameState.season_awards.duplicate(true)
	var old2: Array = GameState.honour_roll.duplicate(true)
	(old2[0] as Dictionary).erase("golden_fist")
	GameState.honour_roll = old2
	GameState.season_awards.erase("golden_fist")
	GameState.save_career()
	GameState.load_career()
	_check(not (GameState.honour_roll[0] as Dictionary).has("golden_fist")
			and not GameState.season_awards.has("golden_fist")
			and ClubTrophies.player_honours(GameState.honour_roll).all(func(it): return str(it["key"]) != "golden_fist"),
			"An old save with no Golden Fist loads and shows none")
	GameState.honour_roll = kept_roll
	GameState.season_awards = kept_awards
	GameState.save_career()
	GameState.load_career()
	_check(int(GameState.season_awards.get("year", 0)) == GameDB.START_YEAR and GameState.honour_roll.size() == 1,
			"Awards, honour roll and records survive a save")
	_check((GameState.season_awards.get("golden_fist", []) as Array).size() == fist.size()
			and str(((GameState.honour_roll[0] as Dictionary).get("golden_fist", [{}]) as Array)[0].get("id", "")) == fist_id,
			"The Golden Fist survives a save")
	# Awards night's count, from the finished season (T5.Q23b).
	_award_count_season_checks()
	GameState.start_next_season()
	_check(GameState.season_tally.is_empty() and GameState.honour_roll.size() == 1,
			"A new season starts a fresh tally and keeps the honour roll")
	_check((GameState.award_counts.get("rounds", []) as Array).is_empty(),
			"A new season starts the awards-night record empty")


## A season book row: games and {stat: total}.
func _book_row(club: String, games: int, s: Dictionary) -> Dictionary:
	return {"club": club, "clubs": {club: games}, "games": games, "s": s}


## The Golden Fist rule (T5.Q11c): listed defenders with 12+ games, a lockdown
## and an intercept path each judged against the field, ties to games then id.
func _test_golden_fist_rule() -> void:
	var players := {}
	for id in ["lock", "int", "avg1", "avg2", "short", "tie_a", "tie_b"]:
		players[id] = {"id": id, "role": "DEF"}
	players["mid"] = {"id": "mid", "role": "MID"}
	var book := {
		# A lockdown back: all fist, few intercepts.
		"lock": _book_row("CAR", 22, {"spoils": 140.0, "smothers": 12.0, "tackles": 40.0,
				"intercept_marks": 6.0, "intercepts": 14.0, "rebounds": 20.0}),
		# An intercept back: reads the ball, rarely spoils.
		"int": _book_row("GEE", 22, {"spoils": 20.0, "smothers": 2.0, "tackles": 22.0,
				"intercept_marks": 60.0, "intercepts": 95.0, "rebounds": 80.0}),
		"avg1": _book_row("HAW", 20, {"spoils": 50.0, "smothers": 5.0, "tackles": 30.0,
				"intercept_marks": 25.0, "intercepts": 45.0, "rebounds": 40.0}),
		"avg2": _book_row("ESS", 20, {"spoils": 45.0, "smothers": 4.0, "tackles": 28.0,
				"intercept_marks": 22.0, "intercepts": 40.0, "rebounds": 38.0}),
		# Left out: a midfielder with a defender's numbers, a defender short of games.
		"mid": _book_row("COL", 22, {"spoils": 400.0, "intercept_marks": 200.0}),
		"short": _book_row("SYD", 11, {"spoils": 300.0, "intercept_marks": 150.0}),
	}
	var rows := Awards.golden_fist(book, players)
	var ids := rows.map(func(r): return str(r["id"]))
	_check(not ids.has("mid") and not ids.has("short") and ids.size() == 4,
			"Only listed defenders with 12+ games are in it (%s)" % str(ids))
	_check(str(rows[0]["id"]) == "lock" and str(rows[0]["path"]) == "lockdown",
			"A lockdown defender can win it on spoils (%s via %s)" % [str(rows[0]["id"]), str(rows[0]["path"])])
	var int_row: Dictionary = rows[ids.find("int")]
	_check(str(int_row["path"]) == "intercept", "The interceptor is judged on his intercepts")
	_check(Awards.golden_fist(book, players) == rows, "The same book always gives the same order")
	_check(Awards.golden_fist_line(rows[0]) == "140 spoils, 12 smothers and 40 tackles in 22 games"
			and Awards.golden_fist_line(int_row) == "60 intercept marks, 95 intercepts and 80 rebound 50s in 22 games",
			"The line is his raw counts on his own path (%s / %s)" % [
			Awards.golden_fist_line(rows[0]), Awards.golden_fist_line(int_row)])
	# A quieter lockdown season: now the interceptor wins, on his path.
	(book["lock"]["s"] as Dictionary)["spoils"] = 40.0
	rows = Awards.golden_fist(book, players)
	_check(str(rows[0]["id"]) == "int" and str(rows[0]["path"]) == "intercept",
			"An intercept defender can win it on intercepts (%s via %s)" % [str(rows[0]["id"]), str(rows[0]["path"])])
	# Raw counts never decide it: each path is judged against its own field.
	var scaled := {
		"lock": _book_row("CAR", 20, {"spoils": 100.0, "intercept_marks": 10.0}),
		"int": _book_row("GEE", 20, {"spoils": 60.0, "intercept_marks": 40.0}),
		"avg1": _book_row("HAW", 20, {"spoils": 80.0, "intercept_marks": 10.0}),
		"avg2": _book_row("ESS", 20, {"spoils": 80.0, "intercept_marks": 10.0}),
	}
	rows = Awards.golden_fist(scaled, players)
	_check(str(rows[0]["id"]) == "int", "Each path is judged against its own field, not the bigger raw count")
	# A game at a time: fewer spoils in fewer games beats more spoils in more,
	# and the line says the games, so the lower total reads true.
	var rate := {
		"few": _book_row("CAR", 14, {"spoils": 112.0}),
		"many": _book_row("GEE", 24, {"spoils": 160.0}),
		"avg1": _book_row("HAW", 20, {"spoils": 60.0}),
	}
	rows = Awards.golden_fist(rate, {"few": {"role": "DEF"}, "many": {"role": "DEF"}, "avg1": {"role": "DEF"}})
	_check(str(rows[0]["id"]) == "few" and Awards.golden_fist_line(rows[0]) == "112 spoils in 14 games"
			and Awards.golden_fist_line(rows[1]) == "160 spoils in 24 games",
			"Judged per game: 112 spoils in 14 games beats 160 in 24 (%s)" % str(rows.map(func(r): return Awards.golden_fist_line(r))))
	# Ties: the same score goes to more games, then to the lower id. The higher
	# id has the more games, so only the games rule can put him first.
	var tied := {
		"tie_a": _book_row("CAR", 12, {"spoils": 48.0}),
		"tie_b": _book_row("GEE", 24, {"spoils": 96.0}),
		"avg1": _book_row("HAW", 20, {"spoils": 20.0}),
	}
	rows = Awards.golden_fist(tied, players)
	_check(str(rows[0]["id"]) == "tie_b" and float(rows[0]["score"]) == float(rows[1]["score"]),
			"A level score goes to the defender with more games, even with the higher id")
	# The book lists the higher id first, so order of entry cannot decide it.
	tied = {"tie_b": _book_row("GEE", 12, {"spoils": 48.0}), "tie_a": _book_row("CAR", 12, {"spoils": 48.0}),
			"avg1": _book_row("HAW", 20, {"spoils": 20.0})}
	rows = Awards.golden_fist(tied, players)
	_check(str(rows[0]["id"]) == "tie_a" and str(rows[1]["id"]) == "tie_b",
			"Level on score and games, the lower id wins, every time")
	_check(Awards.golden_fist({}, players).is_empty(), "No book (an older save): no award")
	var part := Awards.golden_fist(book, players, Awards.aa_min_games(6))
	_check(part.map(func(r): return str(r["id"])).has("short"),
			"A book begun part way through asks for games in proportion")


## The trophy room lists your Golden Fist with what won it; another club's
## winner is not yours.
func _test_golden_fist_trophy_room() -> void:
	var keep_club := GameState.my_club
	GameState.my_club = "GEE"
	var row := {"id": "gf1", "club": "GEE", "games": 22, "path": "intercept", "score": 1.8,
			"counts": {"intercept_marks": 14, "intercepts": 40, "rebounds": 31}}
	var seasons := [{"year": 2026, "my_club": "GEE", "golden_fist": [row]},
			{"year": 2027, "my_club": "GEE", "golden_fist": [{"id": "gf2", "club": "CAR", "path": "lockdown",
				"counts": {"spoils": 70}}]},
			{"year": 2028, "my_club": "GEE"}]
	var items := ClubTrophies.player_honours(seasons)
	var fists := items.filter(func(it): return str(it["key"]) == "golden_fist")
	_check(fists.size() == 1 and str(fists[0]["id"]) == "gf1" and int(fists[0]["year"]) == 2026
			and str(fists[0]["name"]) == Awards.GOLDEN_FIST
			and str(fists[0]["count"]) == "14 intercept marks, 40 intercepts and 31 rebound 50s in 22 games",
			"Your Golden Fist is on the shelf with its counts; another club's is not (%s)" % str(fists))
	_check(ClubTrophies.kinds_won(seasons).has("golden_fist"), "The trophy room's filter offers the Golden Fist")
	GameState.my_club = keep_club


## Greatest comeback and biggest lead lost: from the break scores only, past the same bars as the
## comeback headline, never for an ordinary game, never from extra time.
func _test_comeback_records() -> void:
	# Quarter points, home first. GEE trail MEL by 38 at half time and win.
	var back := {"home": "GEE", "away": "MEL", "quarters": [[10, 20], [6, 34], [40, 6], [30, 10]]}
	back["score"] = [86, 70]
	var rec := {}
	Awards.update_records(rec, {"year": 2028}, [back])
	_check(int((rec.get("biggest_comeback", {}) as Dictionary).get("value", 0)) == 38 \
			and str(rec["biggest_comeback"]["club"]) == "GEE" and int(rec["biggest_comeback"]["at"]) == 1,
			"The comeback record is the winner's biggest deficit at a break (%s)" % str(rec))
	_check(str(rec["biggest_blown"]["club"]) == "MEL" and int(rec["biggest_blown"]["value"]) == 38,
			"The lead lost is the loser's biggest lead at a break")
	# A bigger one replaces it; a smaller one does not.
	var bigger := {"home": "COL", "away": "CAR", "quarters": [[0, 48], [6, 0], [40, 0], [30, 12]], "score": [76, 60]}
	var smaller := {"home": "HAW", "away": "ESS", "quarters": [[6, 30], [20, 0], [30, 0], [10, 6]], "score": [66, 36]}
	Awards.update_records(rec, {"year": 2029}, [smaller, bigger])
	_check(int(rec["biggest_comeback"]["value"]) == 48 and str(rec["biggest_comeback"]["club"]) == "COL" and int(rec["biggest_comeback"]["year"]) == 2029,
			"A bigger comeback replaces the record (%s)" % str(rec["biggest_comeback"]))
	# An ordinary game, a win from 12 down, a draw and extra time leave no record.
	var plain := {"home": "GEE", "away": "MEL", "quarters": [[20, 18], [15, 17], [14, 16], [20, 14]], "score": [69, 65]}
	var twelve := {"home": "GEE", "away": "MEL", "quarters": [[6, 18], [15, 17], [24, 0], [20, 14]], "score": [65, 49]}
	var level := {"home": "GEE", "away": "MEL", "quarters": [[30, 6], [10, 10], [10, 30], [10, 10]], "score": [60, 56]}
	level["score"] = [60, 60]
	var extra := back.duplicate(true)
	extra["score"] = [93, 71]
	var none := {}
	Awards.update_records(none, {"year": 2030}, [plain, twelve, level, extra])
	_check(not none.has("biggest_comeback") and not none.has("biggest_blown"),
			"No record from an ordinary game, a draw or a result with extra time (%s)" % str(none))
	# It reads in plain words.
	var old_records = GameState.records
	GameState.records = rec
	var lines: Array = GameState.history_record_lines()
	var text := " | ".join(PackedStringArray(lines.map(func(x): return str(x))))
	_check(text.contains("Greatest comeback: Collingwood, from 48 points down at quarter time, beat Carlton (2029)"),
			"The comeback record reads as football (%s)" % text)
	_check(text.contains("Biggest lead lost: Carlton led Collingwood by 48 points at quarter time and lost (2029)"),
			"The lead lost reads as football (%s)" % text)
	GameState.records = old_records


## Awards night's count (T5.Q23b): a round's record is the change in the
## season tally across it, so a home-and-away match reads 3-2-1 and your side
## 5-4-3-2-1; a final records only your club's points, and a round is never
## recorded twice. Recording never touches the tally.
func _test_award_count_rounds() -> void:
	var res := _one_match()
	res["round"] = 3
	res["label"] = "Round 3"
	var tally := {}
	var rec := AwardsCount.fresh(2026, "GEE")
	var before := AwardsCount.snapshot(tally, [res])
	Awards.tally_match(tally, res, true)
	var kept := tally.duplicate(true)
	AwardsCount.record_round(rec, before, tally, [res], "GEE")
	_check(tally == kept, "Recording a round leaves the season tally exactly as it was")
	var rounds: Array = rec["rounds"]
	var votes := []
	var sides := {}
	if rounds.size() == 1 and (rounds[0]["matches"] as Array).size() == 1:
		for v in rounds[0]["matches"][0]["votes"]:
			votes.append(int(v[1]))
			sides[str(v[2])] = true
	_check(votes == [3, 2, 1] and sides.keys().all(func(c): return c == "GEE" or c == "HAW"),
			"A home-and-away match records its 3-2-1, most first, with each player's club (%s)" % str(votes))
	var bf := []
	for b in rounds[0].get("bf", []) if rounds.size() == 1 else []:
		bf.append(int(b[1]))
	_check(bf == [5, 4, 3, 2, 1] and str(rounds[0].get("vs", "")) == "HAW",
			"Your side's 5-4-3-2-1 is recorded with the opponent (%s)" % str(bf))
	var again := AwardsCount.snapshot(tally, [res])
	Awards.tally_match(tally, res, true)
	AwardsCount.record_round(rec, again, tally, [res], "GEE")
	_check((rec["rounds"] as Array).size() == 1, "A round is never recorded twice")
	var gf := _one_match()
	gf["round"] = Season.REGULAR_ROUNDS + 1
	gf["label"] = "Qualifying Final 2"
	gf["tag"] = "QF"
	var other := AwardsCount.fresh(2026, "ESS")
	var fb := AwardsCount.snapshot(tally, [gf])
	Awards.tally_match(tally, gf, false)
	AwardsCount.record_round(rec, fb, tally, [gf], "GEE")
	AwardsCount.record_round(other, fb, tally, [gf], "ESS")
	var fin: Dictionary = (rec["rounds"] as Array).back()
	_check(bool(fin.get("final", false)) and (fin["matches"] as Array).is_empty()
			and (fin["bf"] as Array).size() == 5 and str(fin["label"]) == "Qualifying Final",
			"A final records your club's points only, by the week's name (%s)" % str(fin.get("label", "")))
	_check((other["rounds"] as Array).is_empty(), "A finals week without your club records nothing")
	var steps := AwardsCount.brownlow_steps(rec)
	_check(steps.size() == 1 and AwardsCount.club_steps(rec).size() == 2,
			"The Brownlow count leaves the finals out; your club's count keeps them")
	var board := AwardsCount.board(steps, 0, 1)
	_check(board.size() == 3 and int(board[0]["total"]) == 3 and int(board[0]["rank"]) == 1
			and AwardsCount.board(steps, 0, 0).is_empty(),
			"The board holds only the votes read so far")
	var level := [{"round": 1, "label": "Round 1", "matches": [{"home": "A", "away": "B",
			"votes": [["x", 3, "A"], ["y", 2, "B"], ["z", 1, "A"]]}]},
			{"round": 2, "label": "Round 2", "matches": [{"home": "A", "away": "B",
			"votes": [["y", 3, "B"], ["x", 2, "A"], ["z", 1, "A"]]}]}]
	var tied := AwardsCount.board(level, 2, 0, ["y", "x"])
	_check(str(tied[0]["id"]) == "y" and int(tied[0]["rank"]) == 1 and int(tied[1]["rank"]) == 1
			and bool(tied[0]["shared"]) and int(tied[2]["rank"]) == 3 and int(tied[0]["last"]) == 3,
			"Level totals share a rank, listed in the stored order; the last round's gain is kept")


## A season played from Round 1: every round recorded, the rounds add up to
## the season tally's votes and points, the count ends on the stored winner,
## and the record and a count left part way survive a save.
func _award_count_season_checks() -> void:
	var rec: Dictionary = GameState.award_counts
	var season: Season = GameState.season
	var year := int(GameState.season_awards.get("year", 0))
	_check(AwardsCount.complete(rec, year, "GEE", season.fixture.size()),
			"A season played from Round 1 is recorded whole (%d rounds)" % (rec.get("rounds", []) as Array).size())
	var steps := AwardsCount.brownlow_steps(rec)
	var totals := AwardsCount.totals(steps, steps.size(), 0)
	var off := []
	for id in GameState.season_tally:
		var want := int(GameState.season_tally[id].get("votes", 0))
		var got := int((totals.get(str(id), {}) as Dictionary).get("total", 0))
		if want != got:
			off.append("%s %d/%d" % [id, got, want])
	_check(off.is_empty() and steps.size() == season.fixture.size(),
			"The rounds' votes add up to every player's season tally (%s)" % str(off.slice(0, 3)))
	var club := AwardsCount.club_steps(rec)
	var pts := AwardsCount.totals(club, club.size(), 0)
	var bf_off := []
	for id in GameState.season_tally:
		var t: Dictionary = GameState.season_tally[id]
		if str(t.get("club", "")) != "GEE":
			continue
		if int(t.get("bf", 0)) != int((pts.get(str(id), {}) as Dictionary).get("total", 0)):
			bf_off.append(str(id))
	var finals := 0
	for st in club:
		finals += 1 if bool(st["final"]) else 0
	var played := 0
	for week in season.finals.get("weeks", []):
		for r in week:
			if str(r.get("home", "")) == "GEE" or str(r.get("away", "")) == "GEE":
				played += 1
	_check(bf_off.is_empty() and finals == played,
			"Your club's count adds up to its best and fairest, its %d finals included (%s)" % [played, str(bf_off.slice(0, 3))])
	var order := []
	for r in GameState.season_awards.get("brownlow", []):
		order.append(str(r["id"]))
	var board := AwardsCount.board(steps, steps.size(), 0, order)
	var top: Dictionary = (GameState.season_awards.get("brownlow", []) as Array)[0]
	_check(str(board[0]["id"]) == str(top["id"]) and int(board[0]["total"]) == int(top["votes"]),
			"The count ends on the stored leader (%s, %d votes)" % [GameState.award_name(top), int(top["votes"])])
	GameState.season_awards["count_at"] = {"stage": 0, "round": 7, "match": 2}
	var kept := rec.duplicate(true)
	GameState.save_career()
	GameState.load_career()
	_check(GameState.award_counts == kept and int((GameState.season_awards.get("count_at", {}) as Dictionary).get("round", 0)) == 7,
			"The record and the count's place survive a save")
	GameState.season_awards.erase("count_at")


## A save from before the record existed, or a record of another season, is
## started afresh from the next round played and is never counted.
func _test_award_count_late_start() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	for i in 3:
		GameState.advance()
	GameState.award_counts = AwardsCount.fresh(0, "")
	var next := GameState.season.round_index + 1
	GameState.advance()
	var rec: Dictionary = GameState.award_counts
	_check(int(rec.get("from", 0)) == next and int(rec.get("year", 0)) == GameState.season_year
			and (rec["rounds"] as Array).size() == 1 and int(rec["rounds"][0]["round"]) == next,
			"A record from another season starts again at the next round (Round %d)" % next)
	_check(not AwardsCount.complete(rec, GameState.season_year, "GEE", GameState.season.fixture.size()),
			"A season recorded part way is not counted round by round")
