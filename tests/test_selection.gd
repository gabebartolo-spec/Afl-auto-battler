extends RefCounted
## Team selection: auto-pick is unchanged, a named side is what takes the
## field (out of position too), gaps and over-full slots are handled, a player
## you leave out really does not play, and the selection is saved.
## Run through tests/run_selection_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_auto_matches_select_22()
	_test_named_side()
	_test_gaps_and_overflow()
	_test_left_out_player_sits_out()
	_test_selection_saved()
	GameState.delete_saved_career()
	print("Selection tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _ids(arr: Array) -> Array:
	var out := []
	for p in arr:
		out.append(str(p["id"]))
	return out


func _new_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))


func _test_auto_matches_select_22() -> void:
	var list: Array = GameDB.club_list("COL")
	var a := Ratings.select_22(list)
	var b := Ratings.select_side(list, {})
	_check(_ids(a["ground"]) == _ids(b["ground"]) and _ids(a["bench"]) == _ids(b["bench"]),
			"With no selection the side is exactly the automatic best 22")


func _test_named_side() -> void:
	_new_season()
	var side := GameState.current_side()
	# Swap a forward into the midfield and a midfielder forward.
	var fwd := str(side["FWD"][0])
	var mid := str(side["MID"][0])
	side["FWD"][0] = mid
	side["MID"][0] = fwd
	GameState.set_selection(side)
	var squad := GameState.my_squad()
	var roles := {}
	for p in squad.ground:
		roles[str(p["id"])] = str(p["role"])
	_check(roles.get(fwd, "") == "MID" and roles.get(mid, "") == "FWD",
			"Named players play where you put them, out of position too")
	_check(squad.ground.size() == 18 and squad.bench.size() == 4, "It is still 18 plus 4")


func _test_gaps_and_overflow() -> void:
	_new_season()
	var side := GameState.current_side()
	var gone := str(side["DEF"][0])
	GameState.list_player(gone)["injury_weeks"] = 3
	# Overfill the forwards with two extra names from the bench.
	(side["FWD"] as Array).append(side["BENCH"][0])
	(side["FWD"] as Array).append(side["BENCH"][1])
	GameState.set_selection(side)
	var squad := GameState.my_squad()
	var ground := _ids(squad.ground)
	var counts := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	for p in squad.ground:
		counts[str(p["role"])] = int(counts[str(p["role"])]) + 1
	_check(not ground.has(gone) and not _ids(squad.bench).has(gone),
			"An unavailable named player sits out")
	_check(counts == {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6},
			"Every slot is filled exactly, gap filled and overflow capped (%s)" % str(counts))
	GameState.list_player(gone)["injury_weeks"] = 0


func _test_left_out_player_sits_out() -> void:
	_new_season()
	var side := GameState.current_side()
	var star := str(side["MID"][0])
	(side["MID"] as Array).erase(star)
	side["OUT"] = [star]
	GameState.set_selection(side)
	GameState.advance()
	var res: Dictionary = GameState.last_match
	_check(not (res.get("players", {}) as Dictionary).has(star),
			"A player you leave out records no stats")
	_check(GameState.last_duty(star) == "Reserves", "Left out fit, his XP report says reserves")


func _test_selection_saved() -> void:
	_new_season()
	var side := GameState.current_side()
	(side["MID"] as Array).remove_at(0)
	GameState.set_selection(side)
	GameState.save_career()
	GameState.load_career()
	_check(GameState.my_selection() == side, "The selection survives a save")
	GameState.set_selection({})
	_check(GameState.my_selection().is_empty(), "Auto-pick clears it")
