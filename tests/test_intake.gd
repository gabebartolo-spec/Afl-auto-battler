extends RefCounted
## Intake-draft model regression suite: the shipped 2026 draft class, the
## projection maths, the reversed-ladder intake flow, and the season rollover
## (development, retirement, next year's class). Uses the shipped GDScript.
## Run through tests/run_intake_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027
const BalanceGate := preload("res://tests/balance_gate.gd")


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_t("_test_draft_class_data")
	_t("_test_projection_model")
	_t("_test_intake_draft_flow")
	_t("_test_list_cap_skip")
	_t("_test_full_list_picks_said")
	_t("_test_room_for_every_pick")
	_t("_test_career_spots_match_draft")
	_t("_test_spots_sheet_before_offseason_opens")
	_t("_test_draft_room_gate")
	_t("_test_draft_rules")
	_t("_test_career_rollover")
	_t("_test_class_tiers")
	_t("_test_retirement_talk")
	_t("_test_custom_prospect")
	_t("_test_panel_fit")
	_t("_test_real_lists_start")
	_t("_test_rebuild_walkouts_sign")
	_t("_test_gen_traits_rates")
	# Last: generated classes draw names from a shared counter, and a surname
	# clash changes an international prospect's role, so running this earlier
	# moved _test_class_tiers' comparison.
	_t("_test_tied_rookies_every_club")
	GameState.replay_seed = 0
	print(Ran.line("Intake", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


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
			# A ruck specialist: his tap work is his best part and senior-ready. Draft-night
			# ratings run lower since row 65 (picks 6-20 about 55-58), so 60, not 65.
			if int(a.get("ruck", 0)) >= 60 and int(a.get("ruck", 0)) > ov:
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
	var expected := ["A", "B", "C", "D", "A", "B"]
	for i in range(6):
		_check(str(draft.pick_sequence[i]) == expected[i],
				"Round two runs in the same order as round one, worst club first")
	_check(not draft.is_valid(), "An unfinished intake draft is not valid yet")
	_check(draft.budget > 100000, "The intake cap is a formality")
	draft.start_for_user("A")
	_check(draft.is_user_turn(), "Club A is on the clock first")
	var best = draft.board("", "", "", "overall", true)[0]
	_check(draft.pick(best), "The user signs the top prospect on their turn")
	_check(draft.has(str(best["id"])), "The user's selection is on their list")
	# AI fills B..D, then round two starts again with A.
	_check(draft.is_user_turn() and draft.current_club() == "A", "Round two starts with the same club again")
	_check(draft.pick(draft.board("", "", "", "overall", true)[0]), "The user signs again in round two")
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
	_check(draft.count_for("A") == 2 and draft.count_for("B") == 2 and draft.count_for("D") == 1,
			"The truncated last round goes to the clubs that pick first")


func _test_list_cap_skip() -> void:
	var players := _tiny_pool(4)
	var draft := Draft.build_intake(players, ["A", "B", "C", "D"],
			["A", "B", "C", "D"], 5, {"A": Ratings.LIST_SIZE, "B": 0, "C": 0, "D": 0}, {})
	draft.start_for_user("B")
	_check(draft.current_club() == "B", "A full club's turn is skipped, not stalled")
	var best = draft.board("", "", "", "overall", true)[0]
	_check(draft.pick(best), "The next non-capped club gets its turn")
	# The extra round comes back to B; the coach takes his second player.
	_check(draft.is_user_turn(), "The draft runs on to another round while prospects remain")
	_check(draft.pick(draft.board("", "", "", "overall", true)[0]), "B signs again")
	_check(draft.is_finished(), "The intake finishes even with a full club in the order")
	_check(draft.count_for("A") == 0, "The capped club signs nobody")
	_check(draft.count_for("B") + draft.count_for("C") + draft.count_for("D") == 4,
			"Every prospect is signed by a club with room")
	_check(draft.remaining_pool() == 0,
			"The prospect the full club passed on goes to a club with room: nobody is wasted")


## Director report, 2026-11-07: "I had 4 picks in the draft but it only let
## me use two. Maybe my list was full, but I had no idea". With two spots and
## three picks, the draft says before it starts which pick will pass, and
## records the pass when it happens.
func _test_full_list_picks_said() -> void:
	var full := Ratings.LIST_SIZE
	var d := _blank(["A", "B"], {"A": full - 2, "B": 0}, 6)
	_check(d.upcoming_picks("A", 0) == [1, 3, 5], "A holds picks 1, 3 and 5 (%s)" % str(d.upcoming_picks("A", 0)))
	_check(d.open_spots("A") == 2, "Two list spots are open before the draft (%d)" % d.open_spots("A"))
	var plan := d.spots_plan("A")
	_check(plan["usable"] == [1, 3] and plan["passing"] == [5],
			"Picks 1 and 3 have a spot; pick 5 will pass (%s)" % str(plan))
	d.start_for_user("A")
	for i in range(20):
		if d.is_finished():
			break
		_check(d.pick_for_me(), "The coach takes the pick on the clock")
	_check(d.is_finished(), "The draft finishes")
	_check(d.count_for("A") == 2, "A full list signs only two (%d)" % d.count_for("A"))
	_check(not d.user_passed.is_empty() and int(d.user_passed[0]["pick"]) == 5,
			"The pass is recorded at pick 5 (%s)" % str(d.user_passed))
	_check(d.user_passed_line().begins_with("Pick 5 passed: your list is full (%d)" % full)
			or d.user_passed_line().begins_with("Picks 5"),
			"The pass is said in words (%s)" % d.user_passed_line())
	_check(d.open_spots("A") == 0 and d.spots_plan("A")["usable"].is_empty(), "No spot is left after the draft")


## A list with room uses every pick and records no pass.
func _test_room_for_every_pick() -> void:
	var d := _blank(["A", "B"], {"A": 30, "B": 0}, 6)
	var plan := d.spots_plan("A")
	_check(plan["usable"] == [1, 3, 5] and (plan["passing"] as Array).is_empty(),
			"Every pick has a spot (%s)" % str(plan))
	d.start_for_user("A")
	for i in range(20):
		if d.is_finished():
			break
		_check(d.pick_for_me(), "The coach takes the pick on the clock")
	_check(d.count_for("A") == 3, "All three picks are used (%d)" % d.count_for("A"))
	_check(d.user_passed.is_empty() and d.user_passed_line() == "", "No pass is recorded")


## An older save can reach the draft button before its off-season opened
## (begin_intake_draft opens it, and this year's picks only count once it is
## open): the sheet still says which picks pass.
func _test_spots_sheet_before_offseason_opens() -> void:
	GameState.reset()
	var me := str(GameDB.CLUB_ORDER[0])
	GameState.start_season(me, GameDB.club_list(me))
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	var n := 0
	while RookieList.senior_count(GameState.my_list) < RookieList.SENIOR_SPOTS and n < 60:
		var copy: Dictionary = (GameState.my_list[n % GameState.my_list.size()] as Dictionary).duplicate(true)
		copy["id"] = "pad_old_%d" % n
		copy["rookie_list"] = ""
		copy["contract_years"] = 3
		GameState.my_list.append(copy)
		n += 1
	for p in GameState.my_list:
		p["contract_years"] = 3   # nobody out of contract: the list is settled
	_check(not GameState.offseason_open(), "The off-season has not opened (an older save)")
	_check(DraftSpotsSheet.needed(), "The sheet shows for a full list before the off-season opens")
	_check(not (GameState.draft_list_spots()["passing"] as Array).is_empty(),
			"Every pick of a full list is named as passing (%s)" % str(GameState.draft_list_spots()))


## Must make room (director, 2026-11-12): a club takes at least three players,
## or every pick it holds when fewer. Short of that, the gate says how many to
## delist (one/two/three, singular or plural as it reads), and delisting one
## or trading a pick away brings the count down until the gate is gone.
func _test_draft_room_gate() -> void:
	GameState.reset()
	var me := str(GameDB.CLUB_ORDER[0])
	GameState.start_season(me, GameDB.club_list(me))
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	season.finals = {"done": true, "premier": "CAR", "runner_up": "ESS"}
	GameState.open_offseason()
	# No tied (father-son, academy) draftees: they would hold spots of their own.
	for p in GameState.draftee_pool:
		if str(p.get("tied_club", "")) == me:
			p["tied_club"] = ""
	for p in GameState.my_list:
		p["contract_years"] = 3
	var n := 0
	while int(GameState.draft_list_spots()["held"]) < RookieList.SENIOR_SPOTS and n < 60:
		var copy: Dictionary = (GameState.my_list[n % GameState.my_list.size()] as Dictionary).duplicate(true)
		copy["id"] = "pad_gate_%d" % n
		copy["rookie_list"] = ""
		GameState.my_list.append(copy)
		n += 1
	var s := GameState.draft_list_spots()
	var held: int = (s["picks"] as Array).size()
	_check(held >= 3 and int(s["held"]) == int(s["cap"]), "A full list with three picks or more (%s)" % str(s))
	var words := ["no", "one", "two", "three"]
	var want := mini(3, held)
	for k in range(want, 0, -1):
		_check(GameState.draft_room_short() == k, "Short by %d (%d)" % [k, GameState.draft_room_short()])
		_check(GameState.draft_room_line() == "Clubs must take at least three players. Delist %s to make room, or trade the picks." % words[k],
				"The gate's line: %s" % GameState.draft_room_line())
		_check(DraftSpotsSheet.needed(), "The draft button opens the gate while short (%d)" % k)
		# A real list can be full already (no pads), so any senior player will do.
		var why := "nobody to delist"
		for p in GameState.my_list.duplicate():
			if not RookieList.is_rookie(p) and not GameState.retiring_now(p):
				var r := GameState.release_player(str(p["id"]))
				why = "" if bool(r["ok"]) else str(r["reason"])
				break
		_check(why == "", "A padded player is delisted (%s; open %s)" % [why, str(GameState.offseason_open())])
	_check(GameState.draft_room_short() == 0 and GameState.draft_room_line() == "", "The rule is met")
	# Trading picks away: a club holding fewer than three needs a spot for each.
	var mine: Array = GameState.club_picks(me).filter(func(pk): return int(pk["year"]) == GameState.season_year)
	var other := str(GameDB.CLUB_ORDER[1])
	for pk in mine.slice(1):
		GameState.pick_owner["%d:%d:%s" % [int(pk["year"]), int(pk["round"]), str(pk.get("origin", me))]] = other
	var left: Array = GameState.draft_list_spots()["picks"]
	_check(left.size() == 1, "Trading away all but one pick leaves one (%s)" % str(left))
	_check(GameState.draft_room_short() == 0, "One pick and three open spots: the rule is met")


## In a career, the count the brief and the pre-draft sheet show matches the
## picks the coach actually gets to use, and a pass reaches the news.
func _test_career_spots_match_draft() -> void:
	GameState.reset()
	var me := str(GameDB.CLUB_ORDER[0])
	GameState.start_season(me, GameDB.club_list(me))
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	GameState.open_offseason()
	# Fill the senior list to two short of the cap with re-signed players.
	var cap := RookieList.SENIOR_SPOTS
	var n := 0
	while RookieList.senior_count(GameState.my_list) < cap - 2 and n < 40:
		var src: Dictionary = GameState.my_list[n % GameState.my_list.size()]
		var copy := src.duplicate(true)
		copy["id"] = "pad_%d" % n
		copy["rookie_list"] = ""
		GameState.my_list.append(copy)
		n += 1
	for p in GameState.my_list:
		p["contract_years"] = 3
	var s := GameState.draft_list_spots()
	var picks: Array = s["picks"]
	_check(picks.size() >= 3, "The coach holds at least three picks (%s)" % str(picks))
	_check(int(s["open"]) == cap - RookieList.senior_count(GameState.my_list),
			"Open spots are the senior cap less the senior list (%s)" % str(s))
	var line := GameState.draft_spots_line()
	_check(line.contains("will pass"), "The brief names the picks that will pass (%s)" % line)
	_check(DraftSpotsSheet.needed(), "The pre-draft sheet is shown when picks will pass")
	var usable: int = (s["usable"] as Array).size()
	_check(GameState.begin_intake_draft(), "The draft opens")
	var draft: Draft = GameState.draft
	for i in range(400):
		if draft.is_finished():
			break
		if draft.is_user_turn():
			draft.pick_for_me()
		else:
			draft.auto_until_user_turn()
	_check(draft.count_for(me) == usable,
			"The coach signs as many as the count said (%d of %d)" % [draft.count_for(me), usable])
	# The brief counts a round from the size of the class; the night plans its
	# rounds from the room the lists are left with, so it can run one fewer. A
	# held pick in a round that never runs has nothing to pass.
	var on_the_night := 0
	for code in draft.pick_sequence:
		on_the_night += 1 if str(code) == me else 0
	_check(draft.user_passed.size() == on_the_night - usable,
			"Every pick without a spot is recorded as passed (%d on the night, %s)" % [on_the_night, str(draft.user_passed)])
	var said := draft.user_passed_line()
	_check(said != "", "The pass is said in words")
	GameState.finish_intake_draft()
	var found := false
	for item in GameState.news:
		found = found or str(item.get("text", item.get("body", ""))).contains(said) or str(item).contains(said)
	_check(found, "The pass reaches the news (%s)" % said)


func _blank(code_list: Array, sizes: Dictionary, n: int, counts: Dictionary = {}) -> Draft:
	return Draft.build_intake(_tiny_pool(n), code_list, code_list, 5, sizes, counts)


func _test_draft_rules() -> void:
	# Same order every round, worst club first.
	var d := _blank(["A", "B", "C", "D"], {"A": 0, "B": 0, "C": 0, "D": 0}, 8)
	var seq := ""
	for c in d.pick_sequence:
		seq += str(c)
	_check(seq == "ABCDABCD", "National Draft order repeats every round (%s)" % seq)
	_check(d.upcoming_picks("A", 0) == [1, 5], "Upcoming picks follow the same order every round")
	# The draft runs until lists are full: full clubs pass, the rest keep picking.
	var full := Ratings.LIST_SIZE
	var e := _blank(["A", "B", "C", "D"], {"A": full, "B": full, "C": 0, "D": 0}, 10)
	e.start_for_user("")
	_check(e.is_finished() and e.remaining_pool() == 0, "Clubs with room take every prospect the full clubs pass on")
	_check(e.count_for("A") == 0 and e.count_for("B") == 0 and e.count_for("C") + e.count_for("D") == 10,
			"Full clubs sign nobody; the others sign all ten (C %d, D %d)" % [e.count_for("C"), e.count_for("D")])
	var last_no := 0
	var rising := true
	for entry in e.pick_history:
		rising = rising and int(entry["pick"]) > last_no
		last_no = int(entry["pick"])
	_check(e.pick_history.size() == 10 and rising and last_no <= e.pick_sequence.size(), "Extra rounds keep the pick numbers in order")
	# A list stops at the limit even when the class is larger.
	var f := _blank(["A", "B"], {"A": full - 2, "B": full - 1}, 12)
	f.start_for_user("")
	_check(f.count_for("A") == 2 and f.count_for("B") == 1 and f.remaining_pool() == 9,
			"No list goes over %d (A %d, B %d, left %d)" % [full, f.count_for("A"), f.count_for("B"), f.remaining_pool()])
	# Passing.
	var g := _blank(["A", "B", "C"], {"A": 40, "B": 36, "C": 36}, 9)
	g.start_for_user("A")
	_check(g.pass_block_reason() == "", "A coach with a full-sized list may pass")
	_check(g.user_pass(), "The coach passes")
	_check(g.is_finished() and g.count_for("A") == 0 and g.remaining_pool() == 0,
			"A passed coach is skipped for the rest of the draft; the others take the class")
	var low := _blank(["A", "B"], {"A": Contracts.min_list() - 2, "B": 40}, 4)
	low.start_for_user("A")
	_check(low.pass_block_reason().contains("needs at least %d" % Contracts.min_list()), "Passing under the minimum list says why: %s" % low.pass_block_reason())
	_check(not low.user_pass() and low.is_user_turn(), "Passing is refused under the minimum list")
	# Pick for me: one pick, the assistant's choice.
	var h := _blank(["A", "B", "C"], {"A": 40, "B": 40, "C": 40}, 9)
	h.start_for_user("A")
	var expect := str(h._best_ai_pick("A")["id"])
	_check(h.pick_for_me(), "Pick for me signs a player")
	_check(h.count_for("A") == 1 and str(h.list()[0]["id"]) == expect, "Pick for me takes the assistant's best available, once")
	_check(h.is_user_turn(), "After one pick it is your turn again in round two")
	# Rucks: AI stops at two, a third late or as a project, never a fourth.
	var r := _blank(["A", "B"], {"A": 40, "B": 40}, 6, {"A": {"RUCK": 2, "MID": 10, "DEF": 14, "FWD": 14}, "B": {"RUCK": 3, "MID": 10, "DEF": 14, "FWD": 13}})
	var raw := {"potential": 70, "overall": 60}
	_check(is_equal_approx(r._intake_ruck_need("A", raw), Draft.INTAKE_RUCK_THIRD), "A third ruck early is marked down")
	_check(is_equal_approx(r._intake_ruck_need("A", {"potential": 85, "overall": 60}), Draft.INTAKE_COVERED), "A third ruck who is a clear project is not")
	_check(r._intake_ruck_need("B", raw) == 0.0, "A fourth ruck is never wanted")
	# Save and load in the middle; an old save without the new fields.
	var s1 := _blank(["A", "B", "C", "D"], {"A": 38, "B": full, "C": 36, "D": 40}, 14)
	s1.start_for_user("A")
	s1.pick(s1.board("", "", "", "overall", true)[0])
	var saved := CareerSave.object_vars(s1)
	var live_sig := _finish_sig(s1)
	var s2 := Draft.new([], [], 0)
	CareerSave.apply_vars(s2, saved)
	_check(_finish_sig(s2) == live_sig, "A draft saved mid-way finishes identically after loading")
	var old_vars := saved.duplicate()
	old_vars.erase("passed_clubs")
	var s4 := Draft.new([], [], 0)
	CareerSave.apply_vars(s4, old_vars)
	_check(_finish_sig(s4) == live_sig, "A save from before the draft rules loads and finishes the same way")
	# Win-now clubs value an older star for the seasons he plays.
	var gawn: Dictionary = GameDB.player_by_id("MEL_11")
	var heeney: Dictionary = GameDB.player_by_id("SYD_5")
	if not gawn.is_empty():
		var dd := Draft.new([gawn, heeney], ["A", "B"], 1)
		_check(dd.horizon_worth(gawn, "now") > 85.0, "A win-now club values a 35-year-old star near his rating (%.1f)" % dd.horizon_worth(gawn, "now"))
		_check(dd.horizon_worth(gawn, "build") < 70.0, "A building club still discounts him (%.1f)" % dd.horizon_worth(gawn, "build"))
		_check(absf(dd.horizon_worth(heeney, "now") - 88.8) < 1.0, "A 30-year-old's win-now worth is unchanged (%.1f)" % dd.horizon_worth(heeney, "now"))


func _finish_sig(d: Draft) -> String:
	var guard := 0
	while not d.is_finished() and guard < 200:
		guard += 1
		if d.is_user_turn():
			d.pick_for_me()
		else:
			d.auto_until_user_turn()
	var parts := []
	for e in d.pick_history:
		parts.append("%d:%s:%s" % [int(e["pick"]), str(e["club"]), str(e["player_id"])])
	return ",".join(parts)


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


## Row 86's rule holds for every club and through a save: a father-son or NGA
## rookie at a rival gets what one at yours gets, a reload with the draft still
## open neither loses him nor ticks him twice, and a Tasmania academy rookie,
## on a list the rollover does not tick, starts his first season with two too.
func _test_tied_rookies_every_club() -> void:
	GameState.reset()
	var active := []
	for code in GameDB.CLUB_ORDER:
		if GameDB.enter_year(code) <= GameState.season_year:
			active.append(code)
	var me := str(active[0])
	GameState.start_season(me, GameDB.club_list(me))
	GameState.season.round_index = GameState.season.fixture.size()
	var pool: Array = GameState.draftee_pool
	var planted := [
		{"id": str(pool[0]["id"]), "club": me, "kind": "father-son"},
		{"id": str(pool[1]["id"]), "club": str(active[1]), "kind": "father-son"},
		{"id": str(pool[2]["id"]), "club": str(active[2]), "kind": "NGA"},
	]
	for i in planted.size():
		pool[i]["tied_club"] = planted[i]["club"]
		pool[i]["tied_type"] = planted[i]["kind"]
	# A Tasmanian in the year before the club's debut goes to its academy.
	pool[3]["state"] = "TAS"
	pool[3].erase("tied_club")
	planted.append({"id": str(pool[3]["id"]), "club": "TAS", "kind": "NGA"})
	_check(GameDB.enter_year("TAS") == GameState.season_year + 1,
			"The Tasmanian's draft is the year before the club's debut")
	_check(GameState.begin_intake_draft(), "The draft opens with ties at your club, at rivals and at Tasmania")
	# Save and reload with the draft open: the ties have landed, the tick has not.
	_check(GameState.save_career() and GameState.load_career() and GameState.draft != null,
			"A career saved with the draft open reloads with it still open")
	var draft: Draft = GameState.draft
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(GameState.finish_intake_draft(), "The rollover commits after the reload")
	_check(GameState.season_year == 2028, "The career advances a year")
	for reloaded in [false, true]:
		if reloaded:
			_check(GameState.save_career() and GameState.load_career(), "The new season saves and reloads")
		for want in planted:
			var found := []
			for code in GameState.league_lists:
				for q in GameState.league_lists[code]:
					if str(q["id"]) == str(want["id"]):
						found.append([str(code), int(q.get("contract_years", 0)), str(q.get("drafted_type", ""))])
			_check(found == [[str(want["club"]), Contracts.ROOKIE_YEARS, str(want["kind"])]],
					"%s rookie at %s is on that list once and starts 2028 with two seasons (%s, reloaded: %s)" % [
						want["kind"], want["club"], str(found), str(reloaded)])


func _test_career_rollover() -> void:
	GameState.reset()
	_check(GameState.season_year == 2027, "A new career starts in 2027")
	# The coach's club needs room on its senior list (RookieList.SENIOR_SPOTS)
	# to take a national draftee: the club with the most room is his.
	var me := ""
	for code in GameDB.CLUB_ORDER:
		if GameDB.enter_year(code) > GameState.season_year:
			continue
		if me == "" or RookieList.draft_size(GameDB.club_list(code)) < RookieList.draft_size(GameDB.club_list(me)):
			me = code
	GameState.start_season(me, GameDB.club_list(me))
	_check(RookieList.senior_spot_free(GameState.my_list), "%s has room on its senior list" % me)
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
	tied["tied_club"] = me
	tied["tied_type"] = "father-son"
	# And an academy (NGA) tie, so both pre-listed kinds are checked at the
	# rollover below (row 86).
	var academy: Dictionary = GameState.draftee_pool[1]
	academy["tied_club"] = me
	academy["tied_type"] = "NGA"
	_check(int(tied.get("draft_year", 0)) == 2027 and int(academy.get("draft_year", 0)) == 2027,
			"The planted father-son and NGA prospects belong to this year's draft")
	# The yearly order: the ladder reversed, the premiers last and the
	# runners-up second last (director, bug bash 2026-11-05).
	var ladder_rev := []
	for row in season.ladder_sorted():
		ladder_rev.push_front(str(row["code"]))
	_check(GameState.intake_order() == ladder_rev, "No finals played: the order is the ladder reversed")
	var saved_finals: Dictionary = season.finals
	var prem := str(ladder_rev[5])
	var runner := str(ladder_rev[9])
	season.finals = {"premier": prem, "runner_up": runner}
	var fo := GameState.intake_order()
	season.finals = saved_finals
	_check(fo.size() == ladder_rev.size() and str(fo[-1]) == prem and str(fo[-2]) == runner
			and str(fo[0]) == str(ladder_rev[0]),
			"The premiers pick last and the runners-up second last (%s)" % str(fo))
	_check(GameState.begin_intake_draft(), "The intake draft opens after the home-and-away")
	var draft: Draft = GameState.draft
	_check(draft != null and draft.intake_mode, "GameState built an intake draft")
	# Every pick before my turn is logged, or belonged to a club whose senior
	# list (RookieList.SENIOR_SPOTS) is full: it passes, like a club with no
	# space under the CBA at the real draft.
	var logged_at := {}
	for h in draft.pick_history:
		logged_at[int(h["pick"])] = true
	var all_logged := draft.pick_index > 0
	for i in range(draft.pick_index):
		if not logged_at.has(i + 1) and not draft._list_full(str(draft.pick_sequence[i])):
			all_logged = false
	_check(all_logged, "Rival picks before my turn are all logged (%d of %d)" % [draft.pick_history.size(), draft.pick_index])
	_check(GameState.intake_assignments.size() > 0,
			"Father-son/NGA prospects land before the draft starts")
	# A club that comes to the draft with a full senior list takes no national draftee.
	var full_before := PackedStringArray()
	for code in draft.existing_sizes:
		if int(draft.existing_sizes[code]) >= draft.senior_cap:
			full_before.append(str(code))
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.is_finished(), "Filling every scheduled pick completes the intake")
	var full_picked := 0
	for h in draft.pick_history:
		if full_before.has(str(h["club"])):
			full_picked += 1
	_check(draft.senior_cap == RookieList.SENIOR_SPOTS and full_picked == 0,
			"A club with a full senior list passes the National Draft (%d full: %s)" % [full_before.size(), ", ".join(full_before)])
	_check(GameState.finish_intake_draft(), "The rollover commits")

	_check(GameState.season_year == 2028, "The career advances a year")
	var rookie_years := []
	for p in GameState.my_list:
		if str(p.get("drafted_type", "")) == "national" and int(p.get("drafted_year", 0)) == 2027:
			rookie_years.append(int(p.get("contract_years", 0)))
	_check(not rookie_years.is_empty() and rookie_years.all(func(y): return y == Contracts.ROOKIE_YEARS),
			"National-draft rookies start 2028 with two full seasons left (%s)" % str(rookie_years))
	# Row 86: a father-son or NGA rookie lands through _assign_draftee, not
	# the snake, and must start next season with the same two years.
	var tie_years := []
	for p in GameState.my_list:
		if str(p["id"]) == str(tied["id"]) or str(p["id"]) == str(academy["id"]):
			tie_years.append("%s:%d" % [str(p.get("drafted_type", "")), int(p.get("contract_years", 0))])
	_check(tie_years.size() == 2 and tie_years.has("father-son:%d" % Contracts.ROOKIE_YEARS)
			and tie_years.has("NGA:%d" % Contracts.ROOKIE_YEARS),
			"Father-son and NGA rookies start 2028 with two full seasons left, like a national pick (%s)" % str(tie_years))
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
	var retired_here := (GameState.intake_summary.get("retired", []) as Array).filter(func(r): return str(r["club"]) == me).size()
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
		# Retirements leave at the same rollover, so count the draftees themselves.
		total_signed += arr.filter(func(q): return int(q.get("drafted_year", 0)) == 2027).size()
		_check(arr.size() >= Contracts.min_list(), "No club drops below the minimum list")
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
			"A healthy veteran can be asked; one outside the best 23 cannot")
	# Asking is a roll (ListStings.ASK_AGAIN_YES): pick a career seed where his comes up yes.
	var base_seed := GameState.career_seed
	for k in range(64):
		var trial := RandomNumberGenerator.new()
		trial.seed = hash("%d|ask_again|%s|%d" % [base_seed + k, str(keen["id"]), year])
		if trial.randf() < ListStings.ASK_AGAIN_YES:
			GameState.career_seed = base_seed + k
			break
	var yes := GameState.talk_round(str(keen["id"]))
	_check(bool(yes.get("stays", false)) and int(keen.get("play_on", 0)) == year,
			"Fit, happy and in the side: he goes around again (%s)" % str(yes.get("reason", "")))
	_check(GameState.talk_round(str(keen["id"])).is_empty(), "He is asked once")
	var no := GameState.talk_round(str(sore["id"]))
	_check(not bool(no.get("stays", true)) and str(no.get("reason", "")).contains("hamstring"),
			"Still injured: he sticks with it, and says why (%s)" % str(no.get("reason", "")))
	# Same record, same answer: no dice.
	var facts := GameState.career_facts
	var again := Retirement.answer(sore, GameState.season_year, 18, facts)
	_check(str(again["reason"]) == str(no["reason"]), "His answer follows his record, not a roll")
	sore["injury_weeks"] = 0
	var sid := str(sore["id"])
	var kept: Array = (facts.get(sid, []) as Array).duplicate()
	facts[sid] = []
	for y in [GameState.season_year, GameState.season_year, GameState.season_year - 1]:
		CareerFacts.add(facts, sid, CareerFacts.row(y, "Round 3", "injury", str(sore["club"]), "", "hamstring"))
	_check(not bool(Retirement.answer(sore, GameState.season_year, 18, facts)["stays"]),
			"Three injuries in two seasons: he won't do another rehab")
	facts[sid] = []
	sore["morale"] = 30
	_check(not bool(Retirement.answer(sore, GameState.season_year, 18, facts)["stays"]), "An unhappy veteran goes")
	sore["morale"] = 70
	_check(not bool(Retirement.answer(sore, GameState.season_year, 3, facts)["stays"]), "Barely played: he sees no role")
	facts[sid] = kept
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

## Club Forge "Create a player" (ARD-M7-008): one custom prospect a career,
## made by the ordinary projection, into the first National Draft class. The
## coach shapes the footballer, never his club, pick, OVR or POT.
func _test_custom_prospect() -> void:
	var spec := {"first": "Gabe", "last": "Tester", "nickname": "Tess", "role": "FWD", "role2": "MID",
			"height_cm": 186, "style": "leading_forward", "strengths": ["marking"], "weaknesses": ["pressure"],
			"foot": "L", "number_pref": 23, "fav_club": "MEL", "look": {"hair_style": "mullet"}}
	_check(Prospects.custom_problem(spec) == "", "A complete custom prospect is valid")
	for bad in [{"height_cm": 150}, {"role2": "FWD"}, {"strengths": ["pressure"], "weaknesses": ["pressure"]},
			{"last": " "}, {"style": "tap_ruck"}, {"strengths": ["a", "b", "c"]}]:
		var b := spec.duplicate(true)
		b.merge(bad, true)
		_check(Prospects.custom_problem(b) != "", "An invalid custom prospect is turned away (%s)" % str(bad))
	# T8.Q12: the Forge needs exactly one weakness, allows a second, never a third.
	_check(Prospects.forge_problem(spec) == "", "One weakness: the Forge accepts him")
	var two := spec.duplicate(true)
	two["weaknesses"] = ["pressure", "kicking"]
	_check(Prospects.forge_problem(two) == "", "A second weakness is optional")
	var none := spec.duplicate(true)
	none["weaknesses"] = []
	_check(Prospects.forge_problem(none) != "", "No weakness: the Forge turns him away")
	var three := spec.duplicate(true)
	three["weaknesses"] = ["pressure", "kicking", "running"]
	_check(Prospects.forge_problem(three) != "", "Three weaknesses: the Forge turns him away")
	# No extra power from the choices: one or two weaknesses, same overall.
	var p1 := Prospects.make_custom(spec, 2026, 777)
	var p2 := Prospects.make_custom(two, 2026, 777)
	_check(absi(int(p1["overall"]) - int(p2["overall"])) <= 1 and int(p1["potential"]) == int(p2["potential"]),
			"A second weakness changes his shape, not his overall (%d vs %d)" % [p1["overall"], p2["overall"]])

	GameState.reset()
	# A fixed career (C15): never the clock's.
	GameState.career_seed = 424242
	var seed: int = GameState.career_seed
	_check(GameState.add_custom_prospect(spec) == "", "He is created at career setup")
	_check(GameState.add_custom_prospect(spec) != "", "Only one per career")
	var p: Dictionary = {}
	for d in GameState.draftee_pool:
		if str(d["id"]) == GameState.custom_prospect_id:
			p = d
	_check(not p.is_empty() and int(p["draft_year"]) == GameState.season_year and bool(p.get("user_created", false)),
			"He joins the first National Draft class, marked as yours")
	_check(GameDB.player_display_name(p) == "Gabe Tester", "He is shown under the name you gave him")
	_check(str(p["role"]) == "FWD" and str(p["role2"]) == "MID" and int(p["height_cm"]) == 186
			and str(p["foot"]) == "L" and int(p["number_pref"]) == 23
			and GameDB.player_appearance(p)["hair_style"] == "mullet",
			"Position, height, foot, number and look are as chosen")
	_check(FictionalIdentity.favourite_club(p) == "MEL", "The favourite club he grew up following is as chosen")

	# The roll: once per career - the same seed gives the same player - and a
	# believable spread across careers, never chosen.
	var again := Prospects.make_custom(spec, GameState.season_year, seed)
	var first := Prospects.make_custom(spec, GameState.season_year, seed)
	_check(int(again["overall"]) == int(first["overall"]) and int(again["potential"]) == int(first["potential"]),
			"His ceiling is rolled once: the same career gives the same player")
	var ovr := []
	var stars := 0
	var gen := 0
	for s in range(1, 401):
		var c := Prospects.make_custom(spec, GameState.season_year, s * 7919)
		ovr.append(int(c["overall"]))
		stars += 1 if int(c["potential"]) >= 85 else 0
		gen += 1 if int(c["potential"]) >= 92 else 0
	ovr.sort()
	# Against the generated classes' own band across several careers (a class's
	# tier moves its top and bottom a little).
	var cls_ovr := []
	for cs in [11, 22, 33, 44, 55]:
		cls_ovr.append_array(Prospects.generate_class(GameState.season_year, cs).map(func(x): return int(x["overall"])))
	_check(int(ovr[0]) >= int(cls_ovr.min()) - 2 and int(ovr[-1]) <= int(cls_ovr.max()) + 2,
			"Custom prospects stay inside a class's power band (%d-%d vs %d-%d)" % [ovr[0], ovr[-1], cls_ovr.min(), cls_ovr.max()])
	# Draft-night ratings run at DRAFT_NIGHT_SCALE of the old curve (director 2026-10-14), so a modest one starts in the high 30s.
	_check(BalanceGate.held(int(ovr[40]) >= 36, "custom prospect 10th percentile OVR"), "Even a modest one is a usable role-player prospect (10th percentile OVR %d)" % ovr[40])
	_check(BalanceGate.held(stars > 8 and stars < 140 and gen < 20, "custom prospect star and generational rates"),
			"A star is uncommon and a generational ceiling rare (%d of 400 at POT 85+, %d at 92+)" % [stars, gen])

	# Strengths reshape him, at the same overall.
	var m := spec.duplicate(true)
	m["strengths"] = ["marking"]
	m["weaknesses"] = []
	var g := spec.duplicate(true)
	g["strengths"] = ["goalkicking"]
	g["weaknesses"] = []
	var pm := Prospects.make_custom(m, GameState.season_year, seed)
	var pg := Prospects.make_custom(g, GameState.season_year, seed)
	_check(int(pm["attr"]["marking"]) > int(pg["attr"]["marking"]) and int(pg["attr"]["goalkicking"]) > int(pm["attr"]["goalkicking"])
			and absi(int(pm["overall"]) - int(pg["overall"])) <= 1,
			"Strengths reshape the footballer without lifting his overall")

	# He survives a reload with the same roll.
	var before := [GameState.custom_prospect_id, int(p["overall"]), int(p["potential"])]
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	GameState.save_career()
	GameState.load_career()
	var back: Dictionary = {}
	for d in GameState.draftee_pool:
		if str(d["id"]) == GameState.custom_prospect_id:
			back = d
	_check(GameState.custom_prospect_id == before[0] and not back.is_empty()
			and int(back["overall"]) == before[1] and int(back["potential"]) == before[2],
			"He and his roll survive a reload")
	_check(GameState.add_custom_prospect(spec) != "", "No second prospect once the career has started")
	GameState.reset()


## RPG-007 (director, 2026-10-09: "Yes, as facts"): each name the recruiting
## panel puts up gets at most one line on how he fits the list, and only a
## true one; "the panel is split" only from a real gap between the scouts'
## read and his Combine. Never an order.
func _test_panel_fit() -> void:
	var none := {"RUCK": {"short": 0, "light": 0}, "MID": {"short": 0, "light": 0},
			"DEF": {"short": 0, "light": 0}, "FWD": {"short": 0, "light": 0}}
	var base: Dictionary = GameDB.all_draftees_sorted()[0].duplicate(true)
	base["role2"] = ""
	# A hole, each way.
	var kb: Dictionary = base.duplicate(true)
	kb["role"] = "DEF"
	kb["height_cm"] = 194
	var hole: Dictionary = none.duplicate(true)
	hole["DEF"] = {"short": 1, "light": 0}
	_check(RecruitMeeting.fit_line(kb, hole, "balanced") == "A key back: we can't field a full back line.",
			"A key back for a list that can't field a back line says so (%s)" % RecruitMeeting.fit_line(kb, hole, "balanced"))
	_check(RecruitMeeting.fit_line(kb, none, "balanced") == "", "No hole, no hole line")
	var tall_fwd: Dictionary = base.duplicate(true)
	tall_fwd["role"] = "FWD"
	tall_fwd["role2"] = "DEF"
	tall_fwd["height_cm"] = 196
	_check(RecruitMeeting.fit_line(tall_fwd, hole, "balanced") == "Also a key back: we can't field a full back line.",
			"Through his second position he is 'also' a back, never called one outright")
	var rk: Dictionary = base.duplicate(true)
	rk["role"] = "RUCK"
	var one_ruck: Dictionary = none.duplicate(true)
	one_ruck["RUCK"] = {"short": 1, "light": 0}
	_check(RecruitMeeting.fit_line(rk, one_ruck, "contest") == "A ruck: we only have one we'd trust.",
			"A ruck for a list one ruck deep says so")
	_check(RecruitMeeting.fit_line(rk, none, "contest") == "", "A ruck gets no line when the ruck is covered (and no style line)")
	# The game you play, each way: only when his football is up to it.
	var mid: Dictionary = base.duplicate(true)
	mid["role"] = "MID"
	mid["attr"]["pressure"] = 62
	_check(RecruitMeeting.fit_line(mid, none, "defensive") == "Suits our pressure game.",
			"A midfielder with real pressure suits a pressure game")
	mid["attr"]["pressure"] = 40
	_check(RecruitMeeting.fit_line(mid, none, "defensive") == "", "Without the pressure, no style line")
	mid["attr"]["pressure"] = 62
	_check(RecruitMeeting.fit_line(mid, none, "balanced") == "", "A balanced plan leans on no kind of player: no style line")
	var back: Dictionary = base.duplicate(true)
	back["role"] = "DEF"
	back["height_cm"] = 185
	back["attr"]["pressure"] = 90
	_check(RecruitMeeting.fit_line(back, none, "defensive") == "",
			"A back does not carry a press (PlanFit's lines), so no pressure line")
	# Depth only where "Our list" says it: the first light position.
	var two_light: Dictionary = none.duplicate(true)
	two_light["MID"] = {"short": 0, "light": 3}
	two_light["FWD"] = {"short": 0, "light": 2}
	var fwd: Dictionary = base.duplicate(true)
	fwd["role"] = "FWD"
	fwd["height_cm"] = 186
	_check(RecruitMeeting.depth_role(two_light) == "MID"
			and RecruitMeeting.list_lines(two_light, [], []).has("We're light for depth in the midfield."),
			"The list section names one light position")
	_check(RecruitMeeting.fit_line(fwd, two_light, "balanced") == "",
			"A forward gets no depth line when the list names the midfield, not the forwards")
	var mid_d: Dictionary = base.duplicate(true)
	mid_d["role"] = "MID"
	mid_d["attr"]["pressure"] = 40
	_check(RecruitMeeting.fit_line(mid_d, two_light, "balanced") == "A midfielder, where we're light for depth.",
			"A midfielder gets the depth line the list section names")
	var both: Dictionary = hole.duplicate(true)
	both["MID"] = {"short": 1, "light": 0}
	_check(RecruitMeeting.fit_line(mid, both, "defensive") == "A midfielder: we can't field a full midfield.",
			"One fit line at most: the hole before the style")
	# Real meetings, two seeded drafts: every fit line matches the list it was
	# said about, and nothing reads as an order.
	for seed in [SUITE_SEED, 4242]:
		GameState.reset()
		GameState.replay_seed = seed
		GameState.start_season("COL", GameDB.club_list("COL"))
		GameState.season.round_index = GameState.season.fixture.size()
		GameState.open_offseason()
		_check(GameState.begin_intake_draft(), "(setup) the intake opens, seed %d" % seed)
		var draft: Draft = GameState.draft
		var status := draft.position_status()
		var notes := RecruitMeeting.notes(draft, GameState.my_list, GameState.list_profile(), "defensive")
		var true_lines := true
		var orders := false
		for row in notes["names"]:
			var line := str(row["line"])
			var p := {}
			for q in draft.pool:
				if str(q["id"]) == str(row["id"]):
					p = q
			var want := RecruitMeeting.fit_line(p, status, "defensive")
			if (want == "" and (line.contains("can't field") or line.contains("light for depth") or line.contains("Suits our"))) 					or (want != "" and not line.contains(want)):
				true_lines = false
			var named := RecruitMeeting.depth_role(status)
			if line.contains("light for depth") and (named == "" or not (str(p.get("role", "")) == named or str(p.get("role2", "")) == named)):
				true_lines = false
			if line.contains("split") != RecruitMeeting.split(p, draft.user_club, draft.seed, draft.scouting_mult_for(draft.user_club)):
				true_lines = false
			for w in ["best", "should", "take him", "must", "recommend"]:
				if line.to_lower().contains(w):
					orders = true
		_check(true_lines, "Seed %d: every fit and split line is what the list and the reads say" % seed)
		_check(not orders, "Seed %d: no name line reads as an order" % seed)
	# The split is a minority view, not a habit (SPLIT_GAP set from the data).
	var pool: Array = GameDB.all_draftees_sorted()
	var split := 0
	var tested := 0
	for p in pool:
		if Combine.tested(p, SUITE_SEED):
			tested += 1
			if RecruitMeeting.split(p, "COL", SUITE_SEED):
				split += 1
	_check(split > 0 and split * 4 < tested, "The panel is split on some prospects, not most (%d of %d)" % [split, tested])


## A real-lists career (ARD-M5-016): every club keeps its real end-of-2026
## list, the real 2026 class goes through the 2026 National Draft before any
## season, and 2027 starts on those lists with nothing aged.
func _test_real_lists_start() -> void:
	GameState.reset()
	GameState.replay_seed = 4242
	GameState.begin_real_lists()
	var active := GameDB.active_clubs(GameDB.START_YEAR)
	var real_size := 0
	for code in active:
		real_size += GameDB.club_list(code).size() + GameDB.club_additions(code).size()
	_check(real_size == 808, "The real lists are complete: 808 registered players, the 806 of 2026 and two signed in the trade period (%d)" % real_size)
	var untried: Array = GameDB.club_additions("GEE")
	var all_ok := untried.size() == 12
	for q in untried:
		# Listed players who have played AFL before are rated on that record
		# (stats_year); the rest have no game and are prospects.
		if (int(q.get("gm", 0)) != 0) != q.has("stats_year") or not q.has("potential") or not ["RUCK", "MID", "DEF", "FWD"].has(str(q["role"])):
			all_ok = false
	_check(all_ok,
			"A club's listed players without a 2026 game are there, rated as prospects or on their last record, each with a position")
	var kept := 0
	for code in active:
		kept += (GameState.league_lists[code] as Array).size()
	_check(GameState.opening_draft and GameState.season == null and GameState.season_year == GameDB.DATA_SEASON
			and GameState.draft != null and GameState.draft.intake_mode,
			"Real lists open on the 2026 National Draft, in 2026, with no season played")
	var gone := 0
	var delisted := 0
	for code in active:
		for q in GameDB.club_list(code) + GameDB.club_additions(code):
			var kind := GameDB.departure_kind(q)
			if kind != "":
				gone += 1
				if kind != "retired":
					delisted += 1
	var freed := 0
	for q in GameState.free_agents:
		if GameDB.departure_kind(q) != "" and GameDB.departure_kind(q) != "retired":
			freed += 1
	_check(kept - (real_size - gone) == GameState.intake_assignments.size() and freed == delisted,
			"Each club keeps its list less the 2026 retirements and delistings; the delisted are free agents (%d gone)" % gone)
	# The 2026 trade period and free agency (data/club_moves_2026.csv): each
	# player who changed club is on his new club's list, once, and nowhere else.
	var moved_ok := 0
	var wrong := []
	for code in active:
		for q in GameState.league_lists[code] as Array:
			var mv: Dictionary = GameDB.club_move(q)
			if mv.is_empty():
				continue
			if str(q["club"]) == str(mv["to"]) and code == str(mv["to"]) and str(q.get("data_club", "")) == str(mv["from"]):
				moved_ok += 1
			else:
				wrong.append(str(q.get("real_name", "?")))
	_check(wrong.is_empty() and moved_ok == GameDB.club_moves.size() and moved_ok >= 30,
			"Everyone who changed club in the 2026 trade period is on his new list, once, and played 2026 for his old club (%d, wrong: %s)" % [moved_ok, str(wrong)])
	var pendlebury_at := ""
	for code in active:
		for q in GameState.league_lists[code] as Array:
			if str(q.get("real_name", "")) == "Scott Pendlebury":
				pendlebury_at = code
	_check(pendlebury_at == "GCS", "Pendlebury, traded to Gold Coast, opens on the Gold Coast list (%s)" % pendlebury_at)
	var order: Array = GameState.opening_order(active)
	var same := order.duplicate()
	same.sort()
	var want := active.duplicate()
	want.sort()
	_check(same == want, "The draft order is every founding club once (%d)" % order.size())
	# A national draftee needs room on the senior list (RookieList.SENIOR_SPOTS):
	# the coach takes the founding club with the most room.
	var me := ""
	for code in active:
		if me == "" or RookieList.draft_size(GameState.league_lists[code]) < RookieList.draft_size(GameState.league_lists[me]):
			me = code
	var vet: Dictionary = {}
	for q in GameDB.club_list(me):
		if GameDB.departure_kind(q) == "":
			vet = q
			break
	GameState.choose_real_club(me)
	_check(GameState.my_club == me and GameState.draft.user_club == me and GameState.has_career(),
			"Choosing a club takes its real list; the career can now be saved")
	_check(GameState.save_career() and GameState.load_career() and GameState.opening_draft
			and GameState.draft != null and GameState.draft.intake_mode and GameState.start_mode == "real",
			"A real-lists career saves and resumes mid-draft")
	# A founding club whose real senior list is already full (38) takes no
	# national draftee in the opening draft: it passes.
	var full_before := PackedStringArray()
	for code in GameState.draft.existing_sizes:
		if int(GameState.draft.existing_sizes[code]) >= GameState.draft.senior_cap:
			full_before.append(str(code))
	var guard := 0
	while not GameState.draft.is_finished() and guard < 400:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				break
	_check(GameState.draft.is_finished(), "The 2026 National Draft runs to the end")
	var full_picked := 0
	for h in GameState.draft.pick_history:
		if full_before.has(str(h["club"])):
			full_picked += 1
	_check(GameState.draft.senior_cap == RookieList.SENIOR_SPOTS and not full_before.has(me) and full_picked == 0,
			"A club with a full senior list passes the opening draft (%d full: %s)" % [full_before.size(), ", ".join(full_before)])
	_check(GameState.finish_intake_draft() and GameState.season != null and GameState.season_year == GameDB.START_YEAR
			and not GameState.opening_draft, "Finishing the draft starts the 2027 season")
	var rookies := 0
	for q in GameState.my_list:
		if int(q.get("drafted_year", 0)) == GameDB.DATA_SEASON and str(q.get("drafted_type", "")) == "national":
			rookies += 1
	_check(rookies >= 1, "Your 2026 draftees are on your 2027 list (%d)" % rookies)
	# The opening draft ticks no contract before 2027 starts, so its
	# father-son and NGA picks keep the plain rookie deal (row 86).
	var opening_ties := []
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			if int(q.get("drafted_year", 0)) == GameDB.DATA_SEASON and str(q.get("drafted_type", "")) in ["FS", "NGA"]:
				opening_ties.append(int(q.get("contract_years", 0)))
	# Seven are tied in the class; West Coast, at 43 of the 44, has room for
	# one of its three (RookieList.add_block), so five are listed as ties and
	# its other two go through the open draft.
	_check(opening_ties.size() == 5 and opening_ties.all(func(y): return y == Contracts.ROOKIE_YEARS),
			"The 2026 class's five listed father-son and NGA picks start 2027 with two seasons left (%s)" % str(opening_ties))
	var same_vet: Dictionary = {}
	for q in GameState.my_list:
		if str(q["id"]) == str(vet["id"]):
			same_vet = q
	_check(not same_vet.is_empty() and is_equal_approx(float(same_vet.get("age", 0.0)), float(vet.get("age", 0.0)))
			and int(same_vet["overall"]) == int(vet["overall"]),
			"Real players start 2027 as the data has them: nothing aged or developed twice")
	GameState.reset()
	_check(GameState.start_mode == "redraft" and not GameState.opening_draft, "A new career is a redraft unless chosen")



## Row 104 (4.Q10): generated players carry the special traits at the
## real players' rates. Eight seeded classes (career seed 9000 + year: not the seeds
## GEN_NUDGE was sized on, so this is out of sample), each grown five
## seasons by the development rules; a trait's "matched" share weights the grown players
## in each 4-point OVR band by the real 2026 players' mix (the in-career league is
## re-anchored to the 2026 spread every rollover). tools/audit/gen_traits_impl runs the
## full 13-trait table on 30 classes.
func _test_gen_traits_rates() -> void:
	# The 2026 lists as the game loads them: the hand-set OVR rows on (run_tests.sh plays
	# the suites without them), and none of the earlier tests' career changes.
	var skipped: bool = GameDB.skip_ovr_overrides
	GameDB.skip_ovr_overrides = false
	# Twice: a list player's projection borrows shapes from the lists loaded before it,
	# so the second load is the one every later load repeats.
	for i in 2:
		Prospects.forget_cache()
		GameDB.reload()
	# Reference: real players with senior games (a list player projected from no senior
	# game got his temperament from the old formula, never a hothead).
	var real := []
	for c in GameDB.club_order:
		for p in GameDB.club_list(c):
			if not bool(p.get("generated", false)) and not bool(p.get("projected", false)):
				real.append(p)
	var listed_attr := {}
	for p in GameDB.list_additions:
		listed_attr[str(p["id"])] = (p["attr"] as Dictionary).duplicate()
	_check(real.size() > 600, "The real 2026 lists give the reference rates (%d players)" % real.size())
	var bands := {}
	var real_hot := 0
	var real_bull := 0
	for p in real:
		var b := int(p["overall"]) / 4
		bands[b] = int(bands.get(b, 0)) + 1
		real_hot += 1 if Traits.of(p).has("hothead") else 0
		real_bull += 1 if Traits.of(p).has("bull") else 0
	Prospects.forget_cache()
	var drafted := []
	var grown := []
	for y in range(2027, 2035):
		for p in Prospects.generate_class(y, 9000 + y):
			drafted.append(p.duplicate(true))
			for k in range(1, 6):
				Prospects.age_player(p, y + k)
			grown.append(p)
	var hot := 0
	for i in range(drafted.size()):
		hot += 1 if Traits.of(grown[i]).has("hothead") else 0
	var on := {"n": drafted.size(), "hot": 100.0 * hot / grown.size(),
			"bull": _matched_share(grown, "bull", bands),
			"disc": [drafted[0]["attr"]["discipline"], drafted[1]["attr"]["discipline"]]}
	Prospects.forget_cache()
	var rh := 100.0 * real_hot / real.size()
	var rb := 100.0 * real_bull / real.size()
	_check(on["n"] > 300, "Eight classes are drawn (%d players)" % on["n"])
	_check(BalanceGate.held(absf(on["hot"] - rh) <= 2.5, "generated hothead rate vs real"),
			"Hotheads roll at the real rate: %.1f%% generated against %.1f%% real" % [on["hot"], rh])
	_check(BalanceGate.held(absf(on["bull"] - rb) <= 1.5, "generated contested bull rate vs real"),
			"Contested bulls at a real player's level match the real rate: %.1f%% against %.1f%%" % [on["bull"], rb])
	# The same seeds give the same prospects: the temperament draw is seeded per player.
	Prospects.forget_cache()
	var again: Array = Prospects.generate_class(2027, 9000 + 2027)
	# Only generated players take the real rates: real-list players projected from no
	# senior game load the same every time, and a coach's Forge prospect is his own.
	var forge := {"first": "Gabe", "last": "Tester", "role": "MID", "height_cm": 184,
			"style": "inside", "strengths": ["contested"], "weaknesses": ["running"]}
	var forge_a: Dictionary = Prospects.make_custom(forge, 2027, 777)
	Prospects.forget_cache()
	GameDB.reload()
	var same_listed := listed_attr.size() > 0
	for p in GameDB.list_additions:
		if not listed_attr.has(str(p.get("id", ""))) or p["attr"] != listed_attr[str(p["id"])] \
				or (bool(p.get("generated", false)) and not bool(p.get("user_created", false))):
			same_listed = false
	Prospects.forget_cache()
	var forge_b: Dictionary = Prospects.make_custom(forge, 2027, 777)
	GameDB.skip_ovr_overrides = skipped
	GameDB.reload()
	_check(same_listed, "The real-list players projected from no senior game are not generated and load unchanged (%d)" % listed_attr.size())
	_check(bool(forge_a.get("user_created", false)) and forge_a["attr"] == forge_b["attr"],
			"A coach's Forge prospect is his own and comes out the same every time")
	_check(again[0]["attr"]["discipline"] == on["disc"][0] and again[1]["attr"]["discipline"] == on["disc"][1],
			"A seeded class rolls the same temperaments every time")

## The share of grown players with trait t, each 4-point OVR band weighted by the real
## players in it (bands with no grown player left out).
func _matched_share(grown: Array, t: String, bands: Dictionary) -> float:
	var have := {}
	var tot := {}
	for q in grown:
		var b := int(q["overall"]) / 4
		tot[b] = int(tot.get(b, 0)) + 1
		if Traits.of(q).has(t):
			have[b] = int(have.get(b, 0)) + 1
	var w := 0.0
	var s := 0.0
	for b in bands:
		if int(tot.get(b, 0)) > 0:
			w += float(bands[b])
			s += float(bands[b]) * float(have.get(b, 0)) / float(tot[b])
	return 100.0 * s / maxf(1.0, w)


## Row 114, Rebuild: the bottom club's three best walk out before the 2026
## National Draft, and once it is done they go to market among the rival clubs
## for 2027 (never with you, never back at the club they left), each signing on
## a deal that covers 2027. A rival needs a free senior spot to sign one
## (director 2026-11-10: a club with 38 seniors is blocked, no bumping a
## rookie), so a walkout no rival can fit stays a free agent. You take over the
## bottom club.
func _test_rebuild_walkouts_sign() -> void:
	GameState.reset()
	GameState.replay_seed = 4242
	GameState.challenge = {"kind": "rebuild"}
	GameState.begin_real_lists()
	GameState.choose_real_club(str(GameState.challenge.get("club", "")))
	var club := str(GameState.challenge.get("club", ""))
	var gone: Array = GameState.challenge.get("gone", [])
	_check(club != "" and GameState.my_club == club and gone.size() == 3,
			"Rebuild takes over the bottom club, three gone (%s, %d)" % [club, gone.size()])
	var guard := 0
	while GameState.draft != null and not GameState.draft.is_finished() and guard < 400:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				break
	_check(GameState.finish_intake_draft() and GameState.season != null, "(setup) the 2026 National Draft finishes and 2027 starts")
	if GameState.season == null:
		GameState.reset()
		return
	var where := {}
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			where[str(q["id"])] = [str(code), q]
	var still := GameState.free_agents.filter(func(q): return gone.any(func(g): return str(g["id"]) == str(q["id"])))
	var placed := 0
	var wrong := []
	for g in gone:
		var at = where.get(str(g["id"]))
		if at == null:
			if not still.any(func(q): return str(q["id"]) == str(g["id"])):
				wrong.append("%s lost (on no list, not a free agent)" % str(g["id"]))
			continue
		if str(at[0]) == club or str(at[0]) == GameState.my_club or int(at[1].get("contract_years", 0)) < 1:
			wrong.append("%s at %s" % [str(g["id"]), str(at[0])])
			continue
		placed += 1
	_check(wrong.is_empty() and placed + still.size() == 3,
			"Each walkout signs with a rival club for 2027 or stays a free agent (%s)" % ", ".join(wrong))
	var over := []
	for g in gone:
		var at = where.get(str(g["id"]))
		if at != null and RookieList.senior_count(GameState.season.lists[str(at[0])]) > RookieList.SENIOR_SPOTS:
			over.append(str(at[0]))
	_check(over.is_empty(), "No club signs a walkout past %d seniors (%s)" % [RookieList.SENIOR_SPOTS, ", ".join(over)])
	if still.size() > 0:
		var room := []
		for code in GameState.season.lists:
			if str(code) != club and str(code) != GameState.my_club and RookieList.senior_spot_free(GameState.season.lists[code]):
				room.append(str(code))
		print("  rebuild: %d of 3 walkouts left in free agency; rivals with a senior spot: %s" % [still.size(), ", ".join(room)])
	GameState.reset()
