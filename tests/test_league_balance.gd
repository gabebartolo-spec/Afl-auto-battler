extends RefCounted
## Smoke checks for the competitive-balance harness (tools/balance). It must
## stay reproducible and keep exercising the real game code - this suite does
## not assert any balance target. The full measurement is a manual run: see
## docs/LEAGUE_BALANCE.md. Run through tests/run_league_balance_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	var lb = load("res://tools/balance/league_balance.gd").new()
	_test_stats(lb)
	_test_draft(lb)
	_test_draft_variant(lb)
	_test_season(lb)
	_test_sensitivity(lb)
	print("League balance tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_stats(lb) -> void:
	_check(is_equal_approx(lb.pearson([1, 2, 3, 4], [2, 4, 6, 8]), 1.0), "Pearson of a perfect line is 1")
	_check(is_equal_approx(lb.spearman([1, 2, 3, 4], [10, 20, 25, 100]), 1.0), "Spearman ignores scale")
	_check(is_equal_approx(lb.percentile([0, 10, 20, 30, 40], 0.5), 20.0), "Median")
	var w: Array = lb.wilson(50.0, 100.0)
	_check(float(w[0]) > 0.39 and float(w[0]) < 0.41 and float(w[1]) > 0.59 and float(w[1]) < 0.61,
			"Wilson 95% interval for 50/100 is about 40-60%")


func _ids(lists: Dictionary) -> Dictionary:
	var out := {}
	for c in lists:
		var ids := []
		for p in lists[c]:
			ids.append(str(p["id"]))
		out[c] = ids
	return out


func _test_draft(lb) -> void:
	var a: Dictionary = lb.drafted_lists(7)
	var b: Dictionary = lb.drafted_lists(7)
	_check(_ids(a["lists"]) == _ids(b["lists"]) and a["order"] == b["order"],
			"The seeded career draft is reproducible")
	var c: Dictionary = lb.drafted_lists(8)
	_check(_ids(a["lists"]) != _ids(c["lists"]), "A different draft seed gives a different league")
	var sizes := {}
	for code in a["lists"]:
		sizes[(a["lists"][code] as Array).size()] = true
	_check((a["lists"] as Dictionary).size() == lb.clubs().size() and sizes.size() == 1,
			"Every founding club drafts a list of the same size")
	_check(str(a["sig"]) != str(c["sig"]) and str(a["user_club"]) != "",
			"With your picks from the board policy, seeds give genuinely different leagues")
	# Documents a property of the career draft: with every club (yours
	# included) picking like the AI, the seed only reorders the same 18 lists.
	var ai1: Dictionary = lb.drafted_lists(7, "ai")
	var ai2: Dictionary = lb.drafted_lists(8, "ai")
	_check(str(ai1["sig"]) == str(ai2["sig"]),
			"An all-AI career draft yields the same league for every seed (relabelled)")
	var ratings: Dictionary = lb.club_ratings(a["lists"], lb.clubs())
	var st := []
	for code in ratings:
		st.append(float(ratings[code]["strength"]))
	_check(lb.sd(st) > 0.0, "Drafted clubs differ in preseason strength")


## The draft-compression experiment's model (tools/balance/draft_variant.gd)
## must reproduce the shipped draft when every knob is at its shipped value,
## so each variant changes only the mechanism it names.
func _test_draft_variant(lb) -> void:
	var shipped: Dictionary = lb.drafted_lists(7, "ai")
	var same: Dictionary = lb.drafted_lists(7, "ai", 5,
			{"order": "snake", "score": "current", "need_scale": 1.0, "vorp_scale": 1.0,
			"cap_penalty": true, "budget_mult": 1.0, "noise_sd": 0.0})
	_check(str(same["sig"]) == str(shipped["sig"]),
			"The experiment draft model at shipped settings reproduces the shipped draft")
	var linear: Dictionary = lb.drafted_lists(7, "ai", 5, {"order": "linear"})
	_check(str(linear["sig"]) != str(shipped["sig"]), "A linear draft order changes the league")
	var noisy1: Dictionary = lb.drafted_lists(7, "ai", 5, {"noise_sd_max": 8.0})
	var noisy2: Dictionary = lb.drafted_lists(7, "ai", 5, {"noise_sd_max": 8.0})
	_check(str(noisy1["sig"]) == str(noisy2["sig"]) and str(noisy1["sig"]) != str(shipped["sig"]),
			"Club valuation noise is seeded: reproducible, and it changes the league")


func _test_season(lb) -> void:
	var lists: Dictionary = lb.drafted_lists(7)["lists"]
	var ratings: Dictionary = lb.club_ratings(lists, lb.clubs())
	var recs := []
	for i in range(2):
		var season := Season.new(lb.clubs(), lists, 7001)
		for r in range(3):
			season.play_round()
		recs.append(lb.season_record(season, ratings, {"source": "drafted", "league": "7"}))
	var scores := []
	for rec in recs:
		var s := []
		for m in rec["matches"]:
			s.append([m["hs"], m["as"]])
		scores.append(s)
	_check(scores[0] == scores[1], "A season replayed from the same seed is identical")
	var rec: Dictionary = recs[0]
	_check((rec["clubs"] as Array).size() == lb.clubs().size()
			and (rec["matches"] as Array).size() == 3 * lb.clubs().size() / 2,
			"Season records carry every club and every match")
	var rank_ok := true
	var seen := {}
	for row in rec["clubs"]:
		seen[int(row["strength_rank"])] = true
	for rk in range(1, lb.clubs().size() + 1):
		if not seen.has(rk):
			rank_ok = false
	_check(rank_ok, "Every club gets a distinct preseason strength rank")


func _test_sensitivity(lb) -> void:
	var lists: Dictionary = lb.drafted_lists(7)["lists"]
	var subject: String = lb.median_club(lists)
	var rows: Array = lb.sensitivity(lists, subject, [0, 10], 1, 7 * 7919, {"league": "7"})
	var margin := {0: 0.0, 10: 0.0}
	var n := {0: 0, 10: 0}
	for r in rows:
		margin[int(r["k"])] += float(r["margin"])
		n[int(r["k"])] += 1
	_check(n[0] == 2 * (lb.clubs().size() - 1) and n[10] == n[0],
			"Each k plays every opponent home and away")
	_check(margin[10] / n[10] > margin[0] / n[0] + 10.0,
			"A list 10 OVR better wins by more on identical seeds (%.1f vs %.1f)" % [
			margin[10] / n[10], margin[0] / n[0]])
	var original := 0.0
	for p in lists[subject]:
		original += float(p["overall"])
	var shifted: Array = lb.shifted_list(lists[subject], 10)
	var after := 0.0
	for p in shifted:
		after += float(p["overall"])
	var still := 0.0
	for p in lists[subject]:
		still += float(p["overall"])
	_check(after / shifted.size() - original / shifted.size() > 8.0,
			"The shift raises the list's ratings through the game's own refit")
	_check(is_equal_approx(still, original), "Shifting works on copies, not the league's players")
