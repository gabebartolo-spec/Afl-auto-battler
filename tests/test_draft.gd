extends RefCounted
## Model regression suite. Uses the real GDScript implementation, not a mirror.
## Run through run_draft_tests.gd, or call run() in an in-engine test runner.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_history_and_snake_order()
	_test_position_guidance()
	_test_dual_position_coverage()
	_test_position_status()
	_test_complete_small_draft()
	_test_real_pool()
	_test_player_name_modes()
	_test_cap_guard()
	_test_stuck_draft_recovery()
	_test_asset_valuation()
	print("Draft tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _pool() -> Array:
	var out := []
	# Two clubs, ten players each, enough rucks for both. Source clubs are
	# deliberately different from the clubs doing the drafting.
	for i in range(20):
		out.append({
			"id": "player_%d" % i,
			"name": "Player %d" % i,
			"last": "Player %02d" % i,
			"club": "ORIGINAL",
			"role": ["DEF", "MID", "RUCK", "FWD", "MID"][i % 5],
			"overall": 80 - i,
			"value": 1,
			"gl": i,
			"di": 100 - i,
		})
	return out


func _test_history_and_snake_order() -> void:
	var draft := Draft.new(_pool(), ["A", "B"], 123)
	_check(draft.pick_history.is_empty(), "New drafts have an empty history")
	_check(draft.pick_details("unknown").is_empty(), "Unknown players have no pick details")
	_check(draft.drafted_by("unknown").is_empty(), "Unknown players have no destination club")
	var mine := str(draft.draft_order[1])
	draft.start_for_user(mine)
	_check(draft.pick_history.size() == 1, "Opening rival selections are recorded")
	_check(draft.upcoming_picks(mine) == [2, 3, 6], "Upcoming picks snake, including back-to-back turns")
	_check(draft.upcoming_picks(mine, 0).size() == draft.target_size, "All future user picks are accessible")
	var history_before := draft.pick_history.duplicate(true)
	var selected: Dictionary = draft.board("", "", "", "overall", true)[0]
	_check(draft.pick(selected), "A legal user selection succeeds")
	_check(draft.is_user_turn(), "Back-to-back snake turn stays with the user")
	_check(draft.pick_history.size() == 2, "The user pick is recorded exactly once")
	_check(draft.pick_history[0] == history_before[0], "Earlier entries never change")
	_check(draft.upcoming_picks(mine) == [3, 6, 7], "Upcoming picks advance after selection")
	_check(draft.drafted_by(str(selected["id"])) == mine, "Ownership uses the destination club")
	_check(str(selected["club"]) == "ORIGINAL", "Drafting does not overwrite the source club")
	_check(draft.pick_details(str(selected["id"]))["source_club"] == "ORIGINAL", "Log retains the source club")

	var size_before := draft.pick_history.size()
	var spend_before := draft.spent()
	_check(not draft.pick(selected), "A duplicate pick is rejected")
	_check(not draft.unpick(str(selected["id"])), "League selections cannot be rewound")
	var expensive := selected.duplicate()
	expensive["id"] = "too_expensive"
	expensive["value"] = draft.budget + 1
	_check(not draft.pick(expensive), "An unaffordable pick is rejected")
	_check(draft.pick_history.size() == size_before, "Rejected picks never add phantom log entries")
	_check(draft.spent() == spend_before, "Rejected picks do not change cap usage")
	_verify_log(draft)


func _test_position_guidance() -> void:
	var draft := Draft.new(_pool(), ["A", "B"], 42)
	draft.start_for_user(str(draft.draft_order[0]))
	_check(draft.position_targets() == {"RUCK": 2, "MID": 5, "DEF": 6, "FWD": 6},
			"Coverage agrees with the 6-6-6 ground slots and two-ruck rule")
	_check(draft.position_needs() == draft.position_targets(), "An empty list needs every target slot")
	var defender: Dictionary = draft.board("DEF", "", "", "overall", true)[0]
	_check(draft.pick(defender), "Can select a defender")
	_check(draft.role_counts()["DEF"] == 1, "Position totals count only the user's players")
	_check(draft.position_needs()["DEF"] == 5, "Position needs decrease immediately")
	_check(draft.role_counts()["MID"] == 0, "Rival midfield picks do not affect user totals")
	# Coverage is advisory, never a cap on how many players may play a role.
	var list: Array = draft.club_lists[draft.user_club]
	for i in range(8):
		list.append({"role": "DEF"})
	_check(draft.role_counts()["DEF"] == 9, "Counts do not stop at the coverage target")
	_check(draft.position_needs()["DEF"] == 0, "Needs never become negative")


func _dual(id: String, role: String, role2 := "") -> Dictionary:
	return {"id": id, "name": id, "last": id, "club": "ORIGINAL", "role": role, "role2": role2,
			"overall": 60, "value": 1, "gl": 0, "di": 0,
			"attr": {"ruck": 10, "contested": 50, "disposal": 50, "carry": 50, "intercept": 40,
				"pressure": 40, "goalkicking": 40, "marking": 40, "accuracy": 50, "creating": 40,
				"discipline": 50, "durability": 60, "star": 20}}


## Needs follow who can actually play a role (primary or secondary, the rule
## selection uses), one spot per player; the headline counts stay primary.
func _test_dual_position_coverage() -> void:
	var draft := Draft.new(_pool(), ["A", "B"], 42)
	draft.start_for_user(str(draft.draft_order[0]))
	var list: Array = draft.club_lists[draft.user_club]
	list.clear()
	for i in range(5):
		list.append(_dual("m%d" % i, "MID"))
	list.append(_dual("mf", "MID", "FWD"))
	_check(draft.role_coverage()["FWD"] == 1, "A MID/FWD counts as forward cover")
	_check(draft.position_needs()["FWD"] == 5 and draft.position_needs()["MID"] == 0,
			"With the midfield covered, a MID/FWD takes a forward need off (FWD need 5)")
	var prim := draft.role_counts()
	_check(int(prim["MID"]) + int(prim["FWD"]) + int(prim["DEF"]) + int(prim["RUCK"]) == list.size()
			and int(prim["FWD"]) == 0, "Primary counts still add up to the list size")
	list.append(_dual("mf2", "MID", "FWD"))
	_check(draft.position_needs()["FWD"] == 4, "Each extra MID/FWD takes one more forward need off")
	# One spot each: a DEF/MID covers the defence or the midfield, not both.
	list.clear()
	list.append(_dual("dm", "DEF", "MID"))
	var cov := draft.role_coverage()
	var needs := draft.position_needs()
	_check(cov["DEF"] == 1 and cov["MID"] == 1, "A DEF/MID counts as cover for both lines")
	_check(int(needs["DEF"]) + int(needs["MID"]) == 6 + 5 - 1,
			"...but fills only one spot between them")
	# A MID/RUCK is ruck cover, as the two-ruck rule already says.
	list.clear()
	for i in range(5):
		list.append(_dual("m%d" % i, "MID"))
	list.append(_dual("mr", "MID", "RUCK"))
	_check(draft.count_covering("RUCK") == 1 and draft.role_coverage()["RUCK"] == 1
			and draft.position_needs()["RUCK"] == 1, "A MID/RUCK counts toward the rucks")
	# Selection agrees: forwards the draft counts as cover take forward spots.
	var side: Array = []
	for i in range(6):
		side.append(_dual("d%d" % i, "DEF"))
	for i in range(6):
		var m := _dual("m%d" % i, "MID")
		m["overall"] = 70  # pure midfielders first, as select_22 fills lines greedily
		side.append(m)
	side.append(_dual("r0", "RUCK"))
	for i in range(6):
		side.append(_dual("x%d" % i, "MID", "FWD"))
	var sf := Draft.slot_shortfall(side.map(func(p): return [p["role"], p["role2"]]),
			{"RUCK": 1, "MID": 6, "DEF": 6, "FWD": 6})
	var fwd := 0
	for p in Ratings.select_22(side)["ground"]:
		if str(p["role"]) == "FWD":
			fwd += 1
			_check(Ratings.plays_role(side.filter(func(q): return q["id"] == p["id"])[0], "FWD"),
					"Selection only puts players the draft counts as forward cover in a forward spot")
	_check(int(sf["FWD"]) == 0 and fwd == 6, "Draft says the forwards are covered, and selection fields six")
	# The intake draft counts kept players' second positions too.
	var intake := Draft.build_intake(_pool(), ["A", "B"], ["A", "B"], 7, {"A": 1, "B": 0},
			{"A": {"RUCK": 0, "MID": 1, "DEF": 0, "FWD": 0}, "B": {}},
			{"A": [["MID", "FWD"]], "B": []})
	intake.start_for_user("A")
	_check(intake.role_coverage()["FWD"] == 1, "The intake draft counts a kept MID/FWD as forward cover")


func _test_complete_small_draft() -> void:
	var draft := Draft.new(_pool(), ["A", "B"], 789)
	draft.start_for_user(str(draft.draft_order[1]))
	_fill_user_list(draft)
	_check(draft.is_finished(), "Small snake draft reaches the final pick")
	_check(draft.is_valid(), "Completed user list is valid")
	_check(draft.pick_history.size() == draft.pick_sequence.size(), "The log contains every league pick")
	_check(draft.upcoming_picks(draft.user_club).is_empty(), "No next pick after completion")
	_check(draft.board("", "", "", "overall", true).is_empty(), "Picked players leave the available pool")
	_check(draft.board().size() == 20, "Turning off available-only includes taken players")
	_verify_log(draft)


func _test_real_pool() -> void:
	# The career draft is a 2026 event: the founding eighteen only.
	var draft := Draft.new(GameDB.all_players_sorted(),
			GameDB.active_clubs(2026).duplicate(), 12345)
	var mine := str(draft.draft_order[8])
	draft.start_for_user(mine)
	_check(draft.pick_history.size() == 8, "All eight opening real-data rival picks are visible")
	_check(draft.count() == 0, "Opening AI picks never fill the user's squad")
	_fill_user_list(draft)
	_check(draft.is_finished(), "Real 18-club draft can finish")
	_check(draft.is_valid(), "Real-data user roster can start the season")
	_check(draft.pick_history.size() == draft.target_size * draft.clubs.size(),
			"Real-data pick log covers the entire league")
	var counts := draft.role_counts()
	var total := 0
	for count in counts.values():
		total += int(count)
	_check(total == draft.count(), "All four position counts sum to the actual list size")
	for club in draft.clubs:
		_check(draft.count_for(club) == draft.target_size, "Every rival reaches the same list size")
		_check(draft.spent_for(club) <= draft.budget, "Every club stays under the existing cap")
	_verify_log(draft)


func _test_player_name_modes() -> void:
	var p: Dictionary = GameDB.players[0]
	var previous := GameState.show_real_names
	var overall := int(p["overall"])
	GameState.set_show_real_names(false)
	_check(GameDB.player_display_name(p) == str(p["generic_name"]),
			"Player labels default to fictional names")
	_check(not GameDB.player_display_name(p).contains("plays like"),
			"Fictional labels are the name itself")
	_check(str(p["name"]) == str(p["generic_name"]),
			"The loaded pool does not expose a real name as its default field")
	var seen := {}
	for person in GameDB.players:
		var label := str(person.get("generic_name", ""))
		_check(_is_generated_name(label), "Season pool uses a generated name (%s)" % label)
		_check(not seen.has(label), "Season aliases are unique (%s)" % label)
		seen[label] = true
		_check(GameDB.player_display_name(person) == label,
				"Fictional mode shows the generated name")
	GameState.set_show_real_names(true)
	for person in GameDB.players:
		var real := str(person.get("real_name", "")).strip_edges()
		_check(GameDB.player_display_name(person) == real,
				"Real-name mode shows only the AFL name (%s)" % real)
		_check(not GameDB.player_display_name(person).contains("plays like"),
				"Real-name mode does not add a comparison")
	for person in GameDB.draftees:
		var label := str(person.get("generic_name", ""))
		_check(_is_generated_name(label), "Draft class uses a generated name (%s)" % label)
		_check(not seen.has(label), "Draft aliases do not collide (%s)" % label)
		seen[label] = true
		var real := str(person.get("real_name", "")).strip_edges()
		if real != "":
			_check(GameDB.player_display_name(person) == real,
					"Real-name mode shows a prospect's AFL name on its own")
	var dawson := {}
	for person in GameDB.players:
		if str(person.get("real_name", "")) == "Jordan Dawson":
			dawson = person
			break
	_check(not dawson.is_empty(), "Jordan Dawson is in the loaded pool")
	_check(GameDB.player_display_name(dawson) == "Jordan Dawson",
			"Real-name mode writes Jordan Dawson, not a plays-like label")
	_check(GameDB.player_display_name_by_id(str(dawson["id"])) == "Jordan Dawson",
			"Pick/result lookups resolve the real name by stable player ID")
	_check(int(p["overall"]) == overall, "Name mode never changes the player rating")
	var generated := {"generic_name": "Ari Bramble", "name": "Ari Bramble", "real_name": ""}
	_check(GameDB.player_display_name(generated) == "Ari Bramble",
			"Players with no real AFL name keep the generated name in real-name mode")
	# Past the shuffled pool, names are still generated — never Squadmate 001.
	var saved_next: int = GameDB._alias_next
	GameDB._alias_next = GameDB._alias_candidates.size()
	var extra := []
	for i in range(24):
		extra.append({})
	GameDB.assign_aliases(extra)
	var extra_seen := {}
	for person in extra:
		var label := str(person["generic_name"])
		_check(_is_generated_name(label), "Overflow aliases are generated (%s)" % label)
		_check(not seen.has(label) and not extra_seen.has(label),
				"Overflow aliases do not collide (%s)" % label)
		extra_seen[label] = true
	GameDB._alias_next = saved_next
	GameState.set_show_real_names(previous)


func _is_generated_name(label: String) -> bool:
	if label == "" or label.contains("plays like"):
		return false
	var low := label.to_lower()
	if low.begins_with("squadmate") or low.begins_with("player "):
		return false
	var parts := label.split(" ", false)
	if parts.size() < 2:
		return false
	for part in parts:
		if str(part).is_valid_int():
			return false
	return true


func _fill_user_list(draft: Draft) -> void:
	var guard := 0
	while not draft.is_finished() and guard < draft.target_size + 1:
		guard += 1
		var candidate := {}
		# Secure the mandatory ruck cover, then use the same evaluation as AI.
		if draft.count_by_role("RUCK") < 2:
			for player in draft.board("RUCK", "", "", "overall", true):
				if draft.can_pick_player(player):
					candidate = player
					break
		if candidate.is_empty():
			candidate = draft._best_ai_pick(draft.user_club)
		if candidate.is_empty() or not draft.pick(candidate):
			_check(false, "Draft stalled before the next user selection")
			break


func _verify_log(draft: Draft) -> void:
	var ids := {}
	for i in range(draft.pick_history.size()):
		var entry: Dictionary = draft.pick_history[i]
		_check(int(entry["pick"]) == i + 1, "Overall pick numbers are contiguous")
		_check(int(entry["round"]) == floori(float(i) / draft.clubs.size()) + 1,
				"History rounds match the actual sequence")
		_check(str(entry["club"]) == str(draft.pick_sequence[i]), "History follows snake order")
		_check(not ids.has(entry["player_id"]), "No player appears twice in the league log")
		ids[entry["player_id"]] = true
		_check(draft.pick_details(str(entry["player_id"])) == entry, "Player lookup matches the log")
		var owner_list: Array = draft.club_lists[entry["club"]]
		var found := false
		for player in owner_list:
			if str(player["id"]) == str(entry["player_id"]):
				found = true
				break
		_check(found, "The logged player belongs to the drafting club's list")



## The career draft's pool: the 2026 league plus its draft class.
func _career_draft(seed: int) -> Draft:
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	return Draft.new(pool, GameDB.active_clubs(GameDB.START_YEAR).duplicate(), seed)


func _cheapest_legal(d: Draft) -> Dictionary:
	var best := {}
	for p in d.pool:
		if d.can_pick_player(p) and (best.is_empty() or int(p["value"]) < int(best["value"])):
			best = p
	return best


## ARD-M1-009: a pick must leave enough cap to fill the rest of the list.
func _test_cap_guard() -> void:
	var d := _career_draft(31)
	var me := str(d.draft_order[4])
	d.start_for_user(me)
	var p := _cheapest_legal(d)
	var real_spend := int(d.club_spend[me])
	# Exactly at the boundary: this pick leaves precisely the reserve.
	d.club_spend[me] = d.budget - d.reserve_for(me) - int(p["value"])
	_check(d.usable_cap_for(me) == int(p["value"]) and d.can_pick_player(p),
			"A pick that leaves exactly enough to fill the list is allowed")
	d.club_spend[me] = int(d.club_spend[me]) + 1
	_check(not d.can_pick_player(p) and d.pick_block_reason(p).begins_with("This selection would leave too little salary cap"),
			"A dollar over and it is refused, in plain words")
	_check(d.pick_block_reason(p).contains("$%d left" % d.remaining()), "The refusal shows the cap actually left")
	d.club_spend[me] = real_spend
	# The final place: nothing to keep back, every dollar left can be spent.
	var guard := 0
	while d.count() < d.target_size - 1 and not d.is_finished() and guard < 200:
		guard += 1
		d.pick(_cheapest_legal(d))
	_check(d.count() == d.target_size - 1 and d.reserve_for(me) == 0 and d.usable_cap_for(me) == d.remaining(),
			"On the last pick the whole remaining cap is usable")
	d.pick(_cheapest_legal(d))
	_check(d.is_finished() and d.is_valid(), "The list completes legally")
	var legal := true
	for club in d.clubs:
		if d.count_for(club) != d.target_size or d.spent_for(club) > d.budget:
			legal = false
	_check(legal, "Every rival finishes a full list within the cap")


## A pick that ignores the cap guard: how an older save could have spent.
func _force_pick(d: Draft, code: String, p: Dictionary) -> void:
	var id := str(p["id"])
	d.picked[id] = p
	(d.club_lists[code] as Array).append(p)
	d.club_spend[code] = int(d.club_spend[code]) + int(p["value"])
	if code == d.user_club:
		d.order.append(id)
	var entry := {"pick": d.pick_index + 1, "round": d.current_round(), "club": code, "player_id": id,
			"player_name": str(p.get("name", "")), "role": Ratings.role_tag(p), "overall": int(p["overall"]),
			"value": int(p["value"]), "source_club": str(p["club"])}
	d.pick_history.append(entry)
	d._pick_by_player[id] = entry
	d.pick_index += 1


## An older save where you spent your cap on stars: a legal way on, never a
## cap breach, and it survives a save and reload.
func _test_stuck_draft_recovery() -> void:
	var d := _career_draft(47)
	var me := str(d.draft_order[2])
	d.start_for_user(me)
	var guard := 0
	while not d.user_stuck() and not d.is_finished() and d.count() < 30 and guard < 60:
		guard += 1
		var star := {}
		for p in d.pool:
			if d.picked.has(str(p["id"])) or Ratings.plays_role(p, "RUCK"):
				continue
			if int(p["value"]) <= d.remaining() and (star.is_empty() or int(p["value"]) > int(star["value"])):
				star = p
		if star.is_empty():
			break
		_force_pick(d, me, star)
		d.auto_until_user_turn()
	# However the stars fell, the old save spent the rest too (older rules
	# let it): every dollar gone with places still to fill.
	if not d.user_stuck() and not d.is_finished() and d.is_user_turn():
		d.club_spend[me] = d.budget
	_check(d.user_stuck(), "An old save can leave you with no legal pick (%d signed, $%d left)" % [d.count(), d.remaining()])
	if not d.user_stuck():
		return
	_check(d.spent() <= d.budget, "Even stuck, the cap was never breached")
	var seq := d.pick_sequence.size()
	var dear: Dictionary = d.list()[0]
	for p in d.list():
		if int(p["value"]) > int(dear["value"]):
			dear = p
	_check(not d.release_for_room("nobody") and d.release_for_room(str(dear["id"])),
			"You can release one of your picks when stuck")
	_check(not d.picked.has(str(dear["id"])) and d.pick_sequence.size() == seq + 1 and d.drafted_by(str(dear["id"])) == "",
			"He goes back to the pool and you get an extra pick at the end")
	# Save and reload mid-recovery.
	GameState.draft = d
	GameState.my_club = me
	_check(GameState.save_career() and GameState.load_career(), "A stuck draft saves and loads")
	var r: Draft = GameState.draft
	_check(r.drafted_by(str(dear["id"])) == "" and not r.picked.has(str(dear["id"])),
			"After a reload the released player is still back in the pool")
	guard = 0
	while not r.is_finished() and guard < 200:
		guard += 1
		if r.user_stuck():
			var cheap: Dictionary = r.list()[0]
			for p in r.list():
				if int(p["value"]) > int(cheap["value"]):
					cheap = p
			r.release_for_room(str(cheap["id"]))
			continue
		var p := _cheapest_legal(r)
		if p.is_empty() or not r.pick(p):
			break
	_check(r.is_finished() and r.count() == r.target_size and r.spent() <= r.budget and r.is_valid(),
			"The draft then completes with a full, legal list (%d/%d, $%d of $%d)" % [r.count(), r.target_size, r.spent(), r.budget])
	GameState.draft = null
	GameState.delete_saved_career()


## ARD-M5-014: one answer per position. A dual-position player fills one
## spot only, so he never solves two shortages at once, and every pick moves
## the answer at once.
func _test_position_status() -> void:
	var d := Draft.new(_pool(), ["A", "B"], 5)
	d.start_for_user("A")
	var st := d.position_status()
	_check(int(st["FWD"]["short"]) == 6 and int(st["RUCK"]["short"]) == 2,
			"An empty list is short the whole match-day side")
	_check(Draft.need_word(st["RUCK"], "RUCK") == "need 2" and Draft.need_word(st["FWD"], "FWD") == "short 6",
			"Shortages read in a word: need 2, short 6")
	# Five MID/FWD players: they cover the midfield, so the forwards stay short.
	var pairs := []
	for i in range(5):
		pairs.append(["MID", "FWD"])
	var sf := Draft.slot_shortfall(pairs, Draft.match_day_targets())
	_check(int(sf["MID"]) + int(sf["FWD"]) == 11 - 5,
			"Five dual-position players fill five spots, never ten (%s)" % str(sf))
	var before := int(d.position_status()["FWD"]["short"])
	var fwd := {}
	for p in d.pool:
		if str(p["role"]) == "FWD":
			fwd = p
			break
	d.picked[str(fwd["id"])] = fwd
	(d.club_lists["A"] as Array).append(fwd)
	d.order.append(str(fwd["id"]))
	_check(int(d.position_status()["FWD"]["short"]) == before - 1, "A forward picked: the forwards are one less short")
	_check(Draft.need_word({"short": 0, "light": 3}, "MID") == "light 3"
			and Draft.need_word({"short": 0, "light": 0}, "MID") == "covered",
			"Depth below a full list reads light; otherwise covered")


## ARD-M5-012: the top of a draft goes to the best long-term assets. Need
## and scarcity steer close calls; they never bury a much better player.
func _test_asset_valuation() -> void:
	# National draft: every club already has its midfield covered, and the
	# class's best prospect is a midfielder. He goes in the first few picks.
	var pool := []
	for i in range(24):
		var role: String = ["MID", "DEF", "FWD", "RUCK"][i % 4]
		pool.append({"id": "pr_%d" % i, "name": "Prospect %d" % i, "club": "U18",
				"role": "MID" if i == 0 else role, "role2": "",
				"overall": 78 if i == 0 else 66 - i / 3, "potential": 92 if i == 0 else 74,
				"value": 1, "gl": 0, "di": 0})
	var clubs := ["A", "B", "C", "D"]
	var sizes := {}
	var counts := {}
	for c in clubs:
		sizes[c] = 36
		counts[c] = {"RUCK": 3, "MID": 16, "DEF": 9, "FWD": 8}
	var intake := Draft.build_intake(pool, clubs, clubs, 11, sizes, counts)
	_check(intake._need_weight("A", "MID") >= Draft.INTAKE_COVERED and intake._need_weight("A", "DEF") == 1.0,
			"In the national draft a covered position is marked down a little, never to a fifth")
	var at := -1
	var n := 0
	while not intake.is_finished() and at < 0:
		var c: Dictionary = intake._best_ai_pick(intake.current_club())
		if c.is_empty() or not intake._draft_pick(intake.current_club(), c):
			intake._skip_current_pick()
			continue
		n += 1
		if str(c["id"]) == "pr_0":
			at = n
	_check(at >= 1 and at <= 2, "A 78/92 prospect goes at the top even to clubs full of midfielders (pick %d)" % at)

	# Career draft: clubs agree on the proven best, and scarcity waits.
	var real := Draft.new(GameDB.all_players_sorted() + GameDB.all_draftees_sorted(),
			GameDB.active_clubs(2027).duplicate(), 4242)
	var by_worth: Array = real.pool.duplicate()
	by_worth.sort_custom(func(a, b): return real._worth(a) > real._worth(b))
	_check(is_equal_approx(real._eval_certainty(by_worth[0]), Draft.AI_EVAL_TOP_SHARE)
			and is_equal_approx(real._eval_certainty(by_worth[Draft.AI_EVAL_FULL_RANK + 5]), 1.0),
			"Scouting disagreement shrinks for the consensus best, in full further down")
	_check(is_zero_approx(real._vorp_weight()), "At the first pick scarcity counts for nothing")
	real.pick_index = real.clubs.size() * Draft.AI_VORP_FULL_ROUNDS
	_check(is_equal_approx(real._vorp_weight(), Draft.AI_VORP_WEIGHT), "From the third round it counts in full")
	var top := {}
	for i in range(8):
		top[str(by_worth[i]["id"])] = true
	var credible := 0
	for s in range(12):
		var d := Draft.new(real.pool, GameDB.active_clubs(2027).duplicate(), 9001 + s * 31)
		var first: Dictionary = d._best_ai_pick(d.current_club())
		if top.has(str(first["id"])):
			credible += 1
	_check(credible >= 11, "The first pick of a career draft is one of the consensus top eight (%d of 12)" % credible)
