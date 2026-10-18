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
	_t("_test_full_season")
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
	GameState.save_career()
	GameState.load_career()
	_check(int(GameState.season_awards.get("year", 0)) == GameDB.START_YEAR and GameState.honour_roll.size() == 1,
			"Awards, honour roll and records survive a save")
	GameState.start_next_season()
	_check(GameState.season_tally.is_empty() and GameState.honour_roll.size() == 1,
			"A new season starts a fresh tally and keeps the honour roll")


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
