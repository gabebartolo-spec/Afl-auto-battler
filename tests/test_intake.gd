extends RefCounted
## Intake-draft model regression suite: the shipped 2026 draft class, the
## projection maths, the reversed-ladder intake flow, and the season rollover
## (development, retirement, next year's class). Uses the shipped GDScript.
## Run through tests/run_intake_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_draft_class_data()
	_test_projection_model()
	_test_intake_draft_flow()
	_test_list_cap_skip()
	_test_career_rollover()
	_test_class_tiers()
	_test_retirement_talk()
	print("Intake tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_draft_class_data() -> void:
	var pool: Array = GameDB.draftees
	_check(pool.size() >= 50, "The shipped draft class carries at least 50 prospects")
	var ids := {}
	var aliases := {}
	for p in GameDB.players:
		aliases[str(p.get("generic_name", ""))] = true
	var ranks := {}
	var rucks := 0
	var strong_ruck := false
	var ties_ok := true
	for p in pool:
		var id := str(p["id"])
		_check(not ids.has(id), "Prospect ids are unique (%s)" % id)
		ids[id] = true
		_check(not aliases.has(str(p["generic_name"])),
				"Prospect aliases do not collide with the season pool")
		aliases[str(p["generic_name"])] = true
		var rank := int(p["draft_rank"])
		_check(not ranks.has(rank), "Draft ranks are unique (%d)" % rank)
		ranks[rank] = true
		_check(str(p["role"]) in ["RUCK", "MID", "DEF", "FWD"], "Role is one of the four")
		_check(bool(p.get("projected", false)), "Prospects are flagged as projections")
		var ov := int(p["overall"])
		_check(ov >= 36 and ov <= 76, "Projected overall %d sits in the rookie band" % ov)
		_check(int(p["value"]) >= Contracts.SENIOR_MIN_2027 and int(p["value"]) <= Ratings.salary_value(99), "Salary value stays on the AFL scale")
		var a: Dictionary = p["attr"]
		var attrs_ok := a.size() == Prospects.ATTR_KEYS.size()
		for key in Prospects.ATTR_KEYS:
			var v := int(a.get(key, 0))
			if v < 1 or v > 99:
				attrs_ok = false
		_check(attrs_ok, "All 13 attributes are present and in range for %s" % id)
		if str(p["role"]) == "RUCK":
			rucks += 1
			if int(a.get("ruck", 0)) >= 65:
				strong_ruck = true
		var tie := str(p.get("tied_club", ""))
		if tie != "" and not GameDB.CLUB_ORDER.has(tie):
			ties_ok = false
	_check(rucks >= 3, "The class carries enough rucks for a league-wide intake")
	_check(strong_ruck, "At least one prospect projects as a genuine ruck option")
	_check(ties_ok, "Every father-son/NGA tag names a real club code")
	var first: Dictionary = pool[0]
	for p in pool:
		if int(p["draft_rank"]) == 1:
			first = p
	var last: Dictionary = pool[0]
	for p in pool:
		if int(p["draft_rank"]) == pool.size():
			last = p
	_check(int(first["overall"]) >= int(last["overall"]),
			"The consensus number one out-rates the last-ranked prospect")


func _test_projection_model() -> void:
	_check(Prospects.rank_base_overall(1) > Prospects.rank_base_overall(25),
			"Rank taper falls monotonically at the top")
	_check(Prospects.rank_base_overall(25) > Prospects.rank_base_overall(49),
			"Rank taper falls monotonically in the middle")
	_check(Prospects.rank_base_overall(49) > Prospects.rank_base_overall(60),
			"Rank taper keeps sliding past the published list")
	_check(Prospects.rank_base_overall(1) <= 71.0 and Prospects.rank_base_overall(1) >= 68.0,
			"The top prospect projects near the low 70s")
	_check(Prospects.days_between("2000-01-01", "2001-01-01") == 366,
			"Date maths honours the leap year")
	_check(Prospects.days_between("2008-02-28", "2008-03-01") == 2,
			"Date maths handles Feb 29")
	# Projection is deterministic per id and never outruns its band.
	var row := pool_sample()
	var before := int(row["overall"])
	Prospects.project(row)
	_check(int(row["overall"]) == before, "Re-projecting the same prospect is idempotent")


func pool_sample() -> Dictionary:
	# A standalone synthetic prospect so this test does not depend on the CSV.
	var p := {
		"id": "TEST_1", "first": "T", "last": "Est",
		"real_name": "T Est", "generic_name": "T Est", "name": "T Est",
		"club": "Test Eagles", "num": 1, "src": "U18",
		"role": "MID", "role2": "FWD", "height_cm": 183.0, "weight_kg": 0.0,
		"dob": "2008-04-01", "age": 18.6, "draft_year": 2026, "draft_rank": 3,
		"u18_gm": 12.0, "u18_di": 24.0, "u18_gl": 1.5, "u18_mk": 0.0,
		"u18_tk": 6.0, "u18_if50": 0.0, "u18_ho": 0.0,
	}
	for key in Ratings.STATS_ZERO_KEYS:
		p[key] = 0.0
	Prospects.project(p)
	return p


func _test_intake_draft_flow() -> void:
	var players := _tiny_pool(6)
	var draft := Draft.build_intake(players, ["A", "B", "C", "D"],
			["A", "B", "C", "D"], 777, {"A": 0, "B": 0, "C": 0, "D": 0}, {})
	_check(draft.intake_mode, "build_intake flags intake mode")
	_check(draft.target_size == 2, "Rounds are inferred from pool size (6 over 4 clubs)")
	_check(draft.pick_sequence.size() == 6, "Pick sequence truncates to the pool")
	_check(str(draft.draft_order[0]) == "A", "The reversed-ladder order is respected")
	var expected := ["A", "B", "C", "D", "D", "C"]
	for i in range(6):
		_check(str(draft.pick_sequence[i]) == expected[i],
				"Snake round two starts with the last club of round one")
	_check(not draft.is_valid(), "An unfinished intake draft is not valid yet")
	_check(draft.budget > 100000, "The intake cap is a formality")
	draft.start_for_user("A")
	_check(draft.is_user_turn(), "Club A is on the clock first")
	var best = draft.board("", "", "", "overall", true)[0]
	_check(draft.pick(best), "The user signs the top prospect on their turn")
	_check(draft.has(str(best["id"])), "The user's selection is on their list")
	# AI fills B..D and then round two for D and C; A's turn never comes again.
	_check(draft.is_finished(), "The draft concludes when the pool runs dry")
	_check(draft.remaining_pool() == 0, "No prospect is left undrafted")
	_check(draft.pick_history.size() == 6, "Every pick is logged")
	for i in range(draft.pick_history.size()):
		_check(int(draft.pick_history[i]["pick"]) == i + 1, "Logged pick numbers are contiguous")
	var owner_ids := {}
	for p in draft.pool:
		if draft.has(str(p["id"])):
			owner_ids[str(p["id"])] = true
	_check(owner_ids.size() == 6, "Ownership is complete and unique")
	_check(draft.count_for("D") == 2 and draft.count_for("A") == 1,
			"Truncated snake gives the last clubs the extra rookie")


func _test_list_cap_skip() -> void:
	var players := _tiny_pool(4)
	var draft := Draft.build_intake(players, ["A", "B", "C", "D"],
			["A", "B", "C", "D"], 5, {"A": Ratings.LIST_SIZE, "B": 0, "C": 0, "D": 0}, {})
	draft.start_for_user("B")
	_check(draft.current_club() == "B", "A full club's turn is skipped, not stalled")
	var best = draft.board("", "", "", "overall", true)[0]
	_check(draft.pick(best), "The next non-capped club gets its turn")
	_check(draft.is_finished(), "The intake finishes even with a full club in the order")
	_check(draft.count_for("A") == 0, "The capped club signs nobody")
	_check(draft.count_for("B") + draft.count_for("C") + draft.count_for("D") == 3,
			"Every scheduled pick after the skip is filled")
	_check(draft.remaining_pool() == 1,
			"The prospect the full club passed on stays available for next year")


func _tiny_pool(n: int) -> Array:
	var out := []
	for i in range(n):
		out.append({
			"id": "tiny_%d" % i,
			"name": "Tiny %d" % i, "generic_name": "Tiny %d" % i,
			"real_name": "Tiny %d" % i,
			"club": "ORIGINAL", "num": i,
			"role": ["MID", "DEF", "RUCK", "FWD", "MID", "DEF"][i % 6],
			"role2": "",
			"overall": 70 - i, "value": 2,
			"gl": i, "di": 100 - i, "gm": 0.0,
		})
	return out


func _test_career_rollover() -> void:
	GameState.reset()
	_check(GameState.season_year == 2027, "A new career starts in 2027")
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	# An established player in his prime and still under contract next year,
	# so neither the off-season market nor retirement can move him.
	var vet_id := ""
	var vet_start := 0.0
	var vet_ovr := -1
	for p in GameState.my_list:
		var age := float(p.get("age", 0.0))
		if int(p.get("contract_years", 1)) >= 2 and age >= 26.0 and age <= 30.0 \
				and int(p["overall"]) > vet_ovr:
			vet_id = str(p["id"])
			vet_start = age
			vet_ovr = int(p["overall"])
	var season: Season = GameState.season
	season.round_index = season.fixture.size()  # Fast-forward: the H&A is done.
	# Generated classes carry no father-son/NGA ties (only the real 2026 class
	# did, and it joins through the League Draft). Plant one to prove a tie
	# still lands with its club before the snake starts.
	var tied: Dictionary = GameState.draftee_pool[0]
	tied["tied_club"] = "ADE"
	tied["tied_type"] = "father-son"
	_check(GameState.begin_intake_draft(), "The intake draft opens after the home-and-away")
	var draft: Draft = GameState.draft
	_check(draft != null and draft.intake_mode, "GameState built an intake draft")
	var logged := draft.pick_history.size() + draft.count()
	_check(logged == draft.pick_index, "Rival picks before my turn are all logged")
	_check(GameState.intake_assignments.size() > 0,
			"Father-son/NGA prospects land before the draft starts")

	var list_sizes := {}
	for code in GameDB.CLUB_ORDER:
		list_sizes[code] = (GameState.league_lists.get(code, []) as Array).size()
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.is_finished(), "Filling every scheduled pick completes the intake")
	_check(GameState.finish_intake_draft(), "The rollover commits")

	_check(GameState.season_year == 2028, "The career advances a year")
	# The off-season wrap (ARD-M6-007): built once at the rollover, saved,
	# and shown before Round 1 until you begin the season.
	var wrap: Dictionary = GameState.season_wrap
	_check(GameState.needs_season_wrap(), "Finishing the draft leads to the off-season wrap, not straight to Round 1")
	var picks := (wrap.get("ins", []) as Array).filter(func(r): return str(r["how"]).begins_with("pick "))
	var mine_drafted := 0
	for p in GameState.my_list:
		if int(p.get("draft_pick", 0)) > 0 and str(p.get("drafted_type", "")) == "national" \
				and int(p.get("drafted_year", 0)) == 2027:
			mine_drafted += 1
	_check(picks.size() == mine_drafted, "Every draft pick is in the wrap with its number (%d of %d)" % [picks.size(), mine_drafted])
	var retired_here := (GameState.intake_summary.get("retired", []) as Array).filter(func(r): return str(r["club"]) == "ADE").size()
	var retired_wrap := (wrap.get("outs", []) as Array).filter(func(r): return str(r["how"]) == "retired").size()
	_check(retired_here == retired_wrap, "Every retirement from the list is in the wrap (%d)" % retired_here)
	_check((wrap.get("ins", []) as Array).any(func(r): return str(r["id"]) == str(tied["id"])),
			"A father-son signing is in the wrap too")
	_check(str(wrap.get("goal", "")) != "" and str(wrap.get("reason", "")) != "",
			"The wrap shows the board's goal and why (%s / %s)" % [wrap.get("goal", ""), wrap.get("reason", "")])
	var ins_before := (wrap.get("ins", []) as Array).size()
	_check(GameState.save_career() and GameState.load_career() and GameState.needs_season_wrap()
			and (GameState.season_wrap.get("ins", []) as Array).size() == ins_before,
			"A reload keeps the wrap, unseen and with nothing doubled")
	GameState.begin_season_from_wrap()
	_check(not GameState.needs_season_wrap(), "Once begun, the wrap is gone")
	_check(GameState.save_career() and GameState.load_career() and not GameState.needs_season_wrap(),
			"...and stays gone after a reload")
	_check(GameState.season != null and GameState.season.round_index == 0,
			"A fresh 24-round fixture is built")
	_check(GameState.draft == null, "The intake draft releases the shared draft slot")
	var total_signed := 0
	var seen_ids := {}
	for code in GameDB.CLUB_ORDER:
		var arr: Array = GameState.league_lists.get(code, [])
		if GameDB.enter_year(code) >= GameState.season_year:
			# Not active yet, or an expansion club whose debut list just
			# arrived (Tasmania in 2028): nothing was signed through the draft.
			continue
		total_signed += arr.size() - int(list_sizes[code])
		_check(arr.size() >= Prospects.MIN_LIST, "No club drops below the minimum list")
		_check(arr.size() <= Ratings.LIST_SIZE, "No club exceeds the 44-man list cap")
		for p in arr:
			var pid := str(p["id"])
			_check(not seen_ids.has(pid), "A player cannot belong to two clubs (%s)" % pid)
			seen_ids[pid] = true
			_check(not bool(p.get("retired", false)), "Retired players leave every list")
	_check(total_signed > 18, "Rookies actually arrived (signed: %d)" % total_signed)

	# A contracted veteran aged by exactly one year, with a recomputed rating.
	var vet = null
	for p in GameState.my_list:
		if str(p["id"]) == vet_id:
			vet = p
			break
	if vet != null:
		_check(absf(float(vet["age"]) - (vet_start + 1.0)) < 0.01,
				"A veteran aged exactly one year (%.2f -> %.2f)" % [vet_start, float(vet["age"])])
		_check(float(vet.get("sample", 0.0)) >= 18.0,
				"A completed season lifts the small-sample shrink")
	else:
		_check(false, "A contracted veteran (%s) vanished from the Adelaide list" % vet_id)

	# Prospects that landed keep a real jumper number and their club.
	var rookies := 0
	for p in GameState.my_list:
		if bool(p.get("projected", false)):
			rookies += 1
			_check(str(p["club"]) == GameState.my_club, "A signed rookie belongs to my club")
			_check(int(p["num"]) > 0, "Signed rookies get a jumper number")
	_check(rookies >= 1, "My club signed at least one rookie")

	# And the loop continues: the generated 2028 class drafts into 2029.
	var next_class := Prospects.generate_class(2028)
	_check(next_class.size() >= 40, "The generated 2028 class is a full intake")
	var again_ids := {}
	for p in next_class:
		var pid := str(p["id"])
		_check(not again_ids.has(pid), "Generated ids are unique")
		again_ids[pid] = true
		_check(str(p["generic_name"]) != "", "Generated prospects get aliases")
		_check(not str(p["generic_name"]).to_lower().begins_with("squadmate") \
				and not str(p["generic_name"]).to_lower().begins_with("player "),
				"Generated prospects never get placeholder names (%s)" % str(p["generic_name"]))
		_check(int(p["overall"]) >= 36 and int(p["overall"]) <= 76,
				"Generated prospects stay in the rookie band")
	var repeats := Prospects.generate_class(2028)
	_check(repeats.size() == next_class.size(), "Class generation is deterministic in size")
	for i in range(mini(10, repeats.size())):
		_check(int(repeats[i]["overall"]) == int(next_class[i]["overall"]),
				"Class generation is deterministic in ratings")
	# Forward lines need all three sizes (MatchSim.fwd_size): over five
	# generated classes there are small, general and key forwards.
	var fwd_sizes := {}
	for y in range(2028, 2033):
		for p in Prospects.generate_class(y):
			if str(p["role"]) == "FWD":
				var sz := MatchSim.fwd_size(p)
				fwd_sizes[sz] = int(fwd_sizes.get(sz, 0)) + 1
	_check(int(fwd_sizes.get("small", 0)) >= 5 and int(fwd_sizes.get("general", 0)) >= 5
			and int(fwd_sizes.get("key", 0)) >= 5,
			"Generated classes bring small, general and key forwards (%s)" % str(fwd_sizes))
	GameState.draftee_pool = next_class
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "The loop reaches a second intake draft")
	GameState.draft.start_for_user(GameState.my_club)
	var guard := 0
	while not GameState.draft.is_finished() and guard < 100:
		guard += 1
		var candidate := GameState.draft._best_ai_pick(GameState.draft.current_club())
		if candidate.is_empty() or not GameState.draft._draft_pick(GameState.draft.current_club(), candidate):
			GameState.draft._skip_current_pick()
	_check(GameState.draft.is_finished(), "The second intake draft can complete")
	_check(GameState.finish_intake_draft(), "The second rollover commits")
	_check(GameState.season_year == 2029, "The career keeps looping (2029)")
	GameState.reset()
	_check(GameState.season_year == 2027, "Reset returns to the 2027 start")
	var restored = null
	for p in GameDB.players:
		if str(p["id"]) == vet_id:
			restored = p
			break
	_check(restored != null and absf(float(restored.get("age", 0.0)) - vet_start) < 0.01,
			"GameDB.reload() restores pristine start-of-2027 ages for a new career")


## Draft classes have a quality tier per career and year: deterministic, at
## the planned frequencies, lifting a strong class's top end and ceilings
## without changing who is in it, and never touching the real 2026 class.
func _test_class_tiers() -> void:
	_check(Prospects.class_tier(123, 2031) == Prospects.class_tier(123, 2031),
			"The same career and year always roll the same tier")
	var differs := false
	for seed in range(1, 40):
		if Prospects.class_tier(seed, 2031) != Prospects.class_tier(seed + 1000, 2031):
			differs = true
	_check(differs, "Different careers do not share every class tier")
	var counts := {}
	var n := 4000
	for i in range(n):
		var t := Prospects.class_tier(7, 2027 + i)
		counts[t] = int(counts.get(t, 0)) + 1
	var freq_ok := true
	for t in Prospects.CLASS_TIERS:
		var share := float(counts.get(str(t[0]), 0)) / float(n)
		if absf(share - float(t[1])) > 0.02:
			freq_ok = false
	_check(freq_ok, "Tiers come up at their planned rates (%s)" % str(counts))
	_check(str(Prospects.class_shifts("normal", 1)) == str([0.0, 0.0]), "A normal class is unchanged")
	var s1: Array = Prospects.class_shifts("super", 1)
	var s40: Array = Prospects.class_shifts("super", 40)
	_check(float(s1[0]) > float(s40[0]) and float(s40[0]) > 0.0 and float(s1[1]) > 0.0
			and float(s40[1]) == 0.0, "A superdraft lifts the top most, the depth a little, the top ceilings")
	_check(float(Prospects.class_shifts("weak", 1)[0]) < 0.0, "A weak class sits lower")
	# Same year, a super roll against a normal one: the same prospects,
	# a better top end and more high ceilings.
	var super_seed := -1
	var normal_seed := -1
	for seed in range(1, 5000):
		var t := Prospects.class_tier(seed, 2033)
		if t == "super" and super_seed < 0:
			super_seed = seed
		if t == "normal" and normal_seed < 0:
			normal_seed = seed
		if super_seed > 0 and normal_seed > 0:
			break
	var sup := Prospects.generate_class(2033, super_seed)
	var nor := Prospects.generate_class(2033, normal_seed)
	var same := sup.size() == nor.size()
	for i in range(mini(sup.size(), nor.size())):
		if str(sup[i]["id"]) != str(nor[i]["id"]) or str(sup[i]["role"]) != str(nor[i]["role"]):
			same = false
	_check(same, "A class's tier never changes who is in it or their positions")
	var top := func(cls: Array, key: String) -> float:
		var t := 0.0
		for p in cls.slice(0, 20):
			t += float(p[key])
		return t / 20.0
	_check(float(top.call(sup, "overall")) > float(top.call(nor, "overall")) + 1.0
			and float(top.call(sup, "potential")) > float(top.call(nor, "potential")) + 2.0,
			"A superdraft's top 20 rate higher now and higher later")
	var tail_rookies := true
	for p in sup.slice(sup.size() - 5):
		if int(p["overall"]) > 64:
			tail_rookies = false
	_check(tail_rookies, "A superdraft still has ordinary late picks")
	var untouched := true
	for p in GameDB.draftees:
		if (p as Dictionary).has("class_shift"):
			untouched = false
	_check(untouched, "The real 2026 class is never tiered")
	# A career keeps its seed and its record of tiers through a save.
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	var seed_before: int = GameState.career_seed
	_check(seed_before > 0, "A new career rolls its seed")
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.start_next_season()
	_check(GameState.class_tiers.has("2027")
			and str(GameState.class_tiers["2027"]) == Prospects.class_tier(seed_before, 2027),
			"The rollover records the new class's tier")
	_check(GameState.save_career() and GameState.load_career(), "The career saves and loads")
	_check(GameState.career_seed == seed_before and GameState.class_tiers.has("2027"),
			"The seed and the tier record survive a reload, so nothing re-rolls")
	GameState.delete_saved_career()


func _tally(id: String, games: int) -> void:
	GameState.season_tally[id] = {"club": GameState.my_club, "games": games, "goals": 0, "goals_ha": 0,
			"disposals": 0, "distance_run": 0.0, "influence": 0.0, "votes": 0, "bf": 0, "polled": 0, "coaches": 0}


## Talking a healthy veteran round (director, 2026-10-06): retirements are
## decided when the off-season opens, a healthy one can be asked once, his
## answer follows his record, rivals ask by the same rules, and the rollover
## does exactly what was shown.
func _test_retirement_talk() -> void:
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	var best := GameState.my_list.duplicate()
	best.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var keen: Dictionary = best[0]     # fit, happy, played: he stays
	var sore: Dictionary = best[1]     # injured: he goes
	var fringe: Dictionary = best[best.size() - 1]  # not in the best 22: not asked
	for p in [keen, sore, fringe]:
		p["age"] = 37.0
		p["morale"] = 70
		p["injury_weeks"] = 0
		_tally(str(p["id"]), 18)
	sore["injury_weeks"] = 4
	sore["injury_kind"] = "hamstring"
	fringe["overall"] = 40
	sore["contract_years"] = 1
	# A rival veteran out of contract and retiring: not for free agency.
	var rival_vet := {}
	for code in GameState.season.lists:
		if str(code) != GameState.my_club:
			rival_vet = (GameState.season.lists[code] as Array)[0]
			break
	rival_vet["age"] = 37.0
	rival_vet["contract_years"] = 1
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	GameState.open_offseason()
	var year := GameState.season_year + 1
	_check(int(keen.get("retiring", 0)) == year and int(fringe.get("retiring", 0)) == year,
			"Retirements are decided when the off-season opens")
	var rows: Array = GameState.retiring_players()
	var askable := {}
	for r in rows:
		askable[str(r["p"]["id"])] = bool(r["can_ask"])
	_check(askable.get(str(keen["id"]), false) and not askable.get(str(fringe["id"]), true),
			"A healthy veteran can be asked; one outside the best 22 cannot")
	var yes := GameState.talk_round(str(keen["id"]))
	_check(bool(yes.get("stays", false)) and int(keen.get("play_on", 0)) == year,
			"Fit, happy and in the side: he goes around again (%s)" % str(yes.get("reason", "")))
	_check(GameState.talk_round(str(keen["id"])).is_empty(), "He is asked once")
	var no := GameState.talk_round(str(sore["id"]))
	_check(not bool(no.get("stays", true)) and str(no.get("reason", "")).contains("hamstring"),
			"Still injured: he sticks with it, and says why (%s)" % str(no.get("reason", "")))
	# Same record, same answer: no dice.
	var again := Retirement.answer(sore, GameState.season_year, 18)
	_check(str(again["reason"]) == str(no["reason"]), "His answer follows his record, not a roll")
	sore["injury_weeks"] = 0
	sore["injury_log"] = [GameState.season_year, GameState.season_year, GameState.season_year - 1]
	_check(not bool(Retirement.answer(sore, GameState.season_year, 18)["stays"]),
			"Three injuries in two seasons: he won't do another rehab")
	sore["injury_log"] = []
	sore["morale"] = 30
	_check(not bool(Retirement.answer(sore, GameState.season_year, 18)["stays"]), "An unhappy veteran goes")
	sore["morale"] = 70
	_check(not bool(Retirement.answer(sore, GameState.season_year, 3)["stays"]), "Barely played: he sees no role")
	# Rival clubs ask by the same rules.
	var rival_asked := 0
	for code in GameState.season.lists:
		if str(code) == GameState.my_club:
			continue
		for p in GameState.season.lists[code]:
			if int((p.get("retire_talk", {}) as Dictionary).get("year", 0)) == year:
				rival_asked += 1
	_check(rival_asked >= 0, "Rival clubs' healthy veterans are asked too (%d)" % rival_asked)
	_check(not GameState.free_agents.has(rival_vet), "A retiring veteran is not put on the free-agent market")
	var expiring_shown := Contracts.expiring(GameState.my_list).filter(func(q): return not GameState.retiring_now(q))
	_check(not expiring_shown.has(sore), "A retiring player is not up for a contract")
	# Save mid-off-season: the decisions hold.
	GameState.save_career()
	GameState.load_career()
	var k := GameState.list_player(str(keen["id"]))
	_check(int(k.get("play_on", 0)) == year and k.has("talked_round"), "A yes survives a save")
	# The rollover does what was shown.
	_check(GameState.begin_intake_draft(), "(setup) the intake opens")
	var draft: Draft = GameState.draft
	while not draft.is_finished():
		var c := draft._best_ai_pick(draft.current_club())
		if c.is_empty() or not draft._draft_pick(draft.current_club(), c):
			draft._skip_current_pick()
	GameState.finish_intake_draft()
	var gone := {}
	for r in GameState.intake_summary.get("retired", []):
		gone[str(r["id"])] = true
	_check(not gone.has(str(keen["id"])) and not GameState.list_player(str(keen["id"])).is_empty(),
			"The veteran you talked round plays on")
	_check(gone.has(str(sore["id"])) and gone.has(str(fringe["id"])), "The others retire as shown")
	_check(not bool(sore.get("resigned", false)), "Nobody re-signed a player who was retiring")
	# Once a career: next year he goes.
	var k2 := GameState.list_player(str(keen["id"]))
	_check(not Retirement.can_ask(k2, GameState.my_list, GameState.season_year + 1),
			"Talked round once already: he cannot be asked again")
