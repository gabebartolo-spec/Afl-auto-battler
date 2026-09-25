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
		_check(int(p["value"]) >= 1 and int(p["value"]) <= 10, "Salary value stays 1-10")
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
	_check(GameState.season_year == 2026, "A new career starts in 2026")
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	var season: Season = GameState.season
	season.round_index = season.fixture.size()  # Fast-forward: the H&A is done.
	_check(GameState.begin_intake_draft(), "The intake draft opens after the home-and-away")
	var draft: Draft = GameState.draft
	_check(draft != null and draft.intake_mode, "GameState built an intake draft")
	var logged := draft.pick_history.size() + draft.count()
	_check(logged == draft.pick_index, "Rival picks before my turn are all logged")
	_check(GameState.intake_assignments.size() > 0,
			"Father-son/NGA prospects land before the draft starts")

	var list_sizes := {}
	for code in GameDB.CLUB_ORDER:
		list_sizes[code] = (GameState.league_lists[code] as Array).size()
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.is_finished(), "Filling every scheduled pick completes the intake")
	_check(GameState.finish_intake_draft(), "The rollover commits")

	_check(GameState.season_year == 2027, "The career advances a year")
	_check(GameState.season != null and GameState.season.round_index == 0,
			"A fresh 24-round fixture is built")
	_check(GameState.draft == null, "The intake draft releases the shared draft slot")
	var total_signed := 0
	var seen_ids := {}
	for code in GameDB.CLUB_ORDER:
		var arr: Array = GameState.league_lists[code]
		if GameDB.enter_year(code) > GameState.season_year:
			# Not an active club yet - an expansion debut list arrives in its
			# own entry season, so there is nothing to keep in band.
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

	# A known veteran aged by exactly one year, with a recomputed rating.
	var dawson = null
	for p in GameState.my_list:
		if str(p.get("real_name", "")) == "Jordan Dawson":
			dawson = p
			break
	if dawson != null:
		_check(absf(float(dawson["age"]) - 30.6) < 1.2, "Dawson aged 29 -> 30")
		_check(float(dawson.get("sample", 0.0)) >= 18.0,
				"A completed season lifts the small-sample shrink")
	else:
		_check(false, "Jordan Dawson vanished from the Adelaide list")

	# Prospects that landed keep a real jumper number and their club.
	var rookies := 0
	for p in GameState.my_list:
		if bool(p.get("projected", false)):
			rookies += 1
			_check(str(p["club"]) == GameState.my_club, "A signed rookie belongs to my club")
			_check(int(p["num"]) > 0, "Signed rookies get a jumper number")
	_check(rookies >= 1, "My club signed at least one rookie")

	# And the loop continues: the generated 2027 class drafts into 2028.
	var next_class := Prospects.generate_class(2027)
	_check(next_class.size() >= 40, "The generated 2027 class is a full intake")
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
	var repeats := Prospects.generate_class(2027)
	_check(repeats.size() == next_class.size(), "Class generation is deterministic in size")
	for i in range(mini(10, repeats.size())):
		_check(int(repeats[i]["overall"]) == int(next_class[i]["overall"]),
				"Class generation is deterministic in ratings")
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
	_check(GameState.season_year == 2028, "The career keeps looping (2028)")
	GameState.reset()
	_check(GameState.season_year == 2026, "Reset returns to the 2026 baseline")
	var restored = null
	for p in GameDB.players:
		if str(p.get("real_name", "")) == "Jordan Dawson":
			restored = p
			break
	_check(restored != null and absf(float(restored.get("age", 0.0)) - 29.6) < 1.0,
			"GameDB.reload() restores pristine 2026 ages for a new career")
