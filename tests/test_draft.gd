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
	_test_complete_small_draft()
	_test_real_pool()
	_test_player_name_modes()
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
	_check(draft.position_targets() == {"DEF": 5, "MID": 7, "RUCK": 2, "FWD": 5},
			"Coverage agrees with the actual ground slots and two-ruck rule")
	_check(draft.position_needs() == draft.position_targets(), "An empty list needs every target slot")
	var defender: Dictionary = draft.board("DEF", "", "", "overall", true)[0]
	_check(draft.pick(defender), "Can select a defender")
	_check(draft.role_counts()["DEF"] == 1, "Position totals count only the user's players")
	_check(draft.position_needs()["DEF"] == 4, "Position needs decrease immediately")
	_check(draft.role_counts()["MID"] == 0, "Rival midfield picks do not affect user totals")
	# Coverage is advisory, never a cap on how many players may play a role.
	var list: Array = draft.club_lists[draft.user_club]
	for i in range(8):
		list.append({"role": "DEF"})
	_check(draft.role_counts()["DEF"] == 9, "Counts do not stop at the coverage target")
	_check(draft.position_needs()["DEF"] == 0, "Needs never become negative")


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
	var draft := Draft.new(GameDB.all_players_sorted(), GameDB.CLUB_ORDER.duplicate(), 12345)
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
