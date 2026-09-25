extends RefCounted
## Contracts, free agency and trades. Run through tests/run_contracts_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_initial_contracts()
	_test_offseason_flow()
	GameState.delete_saved_career()
	print("Contracts tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))


func _to_offseason() -> void:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	while not GameState.season.is_season_over():
		GameState.advance()


func _test_initial_contracts() -> void:
	_new_season()
	var all_have := true
	var under := true
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if not p.has("contract_years") or not p.has("salary"):
				all_have = false
		if Contracts.payroll(GameState.season.lists[code]) > GameState.salary_cap:
			under = false
	_check(all_have, "Every player starts on a contract")
	_check(GameState.salary_cap > 0 and under, "Every club starts under the cap")
	_check(not GameState.offseason_open(), "Trades are closed during the season")
	_check(not bool(GameState.release_player(str(GameState.my_list[0]["id"]))["ok"]),
			"Nobody can be released mid-season")


func _test_offseason_flow() -> void:
	_new_season()
	_to_offseason()
	_check(GameState.offseason_open(), "The off-season opens after the Grand Final")
	var ai_settled := true
	for code in GameState.season.lists:
		if code == GameState.my_club:
			continue
		for p in Contracts.expiring(GameState.season.lists[code]):
			if not bool(p.get("resigned", false)):
				ai_settled = false
	_check(ai_settled, "Rivals settle every expiring contract at once")
	_check(GameState.free_agents.size() > 0, "Rivals let some players go to free agency")

	# Re-sign one of yours, release another.
	var mine := Contracts.expiring(GameState.my_list)
	_check(mine.size() > 0, "Some of your players are out of contract")
	var keep: Dictionary = mine[0]
	var r := GameState.resign_player(str(keep["id"]), 3)
	_check(bool(r["ok"]) and int(keep["contract_years"]) == 4 and int(keep["salary"]) == Contracts.asking_salary(keep),
			"Re-signing sets the new term and price")
	var saved_cap := GameState.salary_cap
	GameState.salary_cap = GameState.my_payroll()
	var dear: Dictionary = mine[mine.size() - 1] if mine.size() > 1 else keep
	if not bool(dear.get("resigned", false)) and Contracts.asking_salary(dear) > int(dear.get("salary", 0)):
		_check(not bool(GameState.resign_player(str(dear["id"]), 2)["ok"]),
				"A raise past the cap is refused")
	GameState.salary_cap = saved_cap
	# Sign the best free agent we can afford.
	var signed := false
	GameState.salary_cap += 40
	for fa in GameState.free_agents.duplicate():
		if str(fa.get("released_by", "")) != GameState.my_club:
			var res := GameState.sign_free_agent(str(fa["id"]), 2)
			signed = bool(res["ok"]) and GameState.list_player(str(fa["id"])) == fa \
					and str(fa["club"]) == GameState.my_club
			break
	_check(signed, "A free agent can be signed onto your list")
	# (The 2026 Geelong list is at the 32 minimum, so release after signing.)
	var size_before := GameState.my_list.size()
	var gone: Dictionary = GameState.my_list[GameState.my_list.size() - 1]
	var rel := GameState.release_player(str(gone["id"]))
	_check(bool(rel["ok"]) and GameState.my_list.size() == size_before - 1
			and GameState.free_agents.has(gone), "A released player goes to free agency")


	# Trades: two middling players never buy a star; a fair swap does.
	var rival := "COL"
	var their_best: Dictionary = {}
	for p in GameState.season.lists[rival]:
		if their_best.is_empty() or int(p["overall"]) > int(their_best["overall"]):
			their_best = p
	var sorted_mine := GameState.my_list.duplicate()
	sorted_mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var two_weak := [str(sorted_mine[0]["id"]), str(sorted_mine[1]["id"])]
	_check(not bool(GameState.evaluate_trade(rival, two_weak, [str(their_best["id"])])["ok"]),
			"Two fringe players do not buy a star")
	var my_best: Dictionary = sorted_mine[sorted_mine.size() - 1]
	var their_weak: Dictionary = {}
	for p in GameState.season.lists[rival]:
		if their_weak.is_empty() or int(p["overall"]) < int(their_weak["overall"]):
			their_weak = p
	GameState.set_selection(GameState.current_side())
	var t := GameState.make_trade(rival, [str(my_best["id"])], [str(their_weak["id"])])
	_check(bool(t["ok"]), "Overpaying gets a trade done (%s)" % str(t["reason"]))
	_check(str(my_best["club"]) == rival and str(their_weak["club"]) == GameState.my_club
			and GameState.season.lists[rival].has(my_best) and GameState.my_list.has(their_weak),
			"Traded players change lists and clubs")
	var still_named := false
	for key in GameState.my_selection():
		if (GameState.my_selection()[key] as Array).has(str(my_best["id"])):
			still_named = true
	_check(not still_named, "A traded player leaves your selection")

	GameState.save_career()
	GameState.load_career()
	_check(GameState.offseason_open() and GameState.salary_cap > 0,
			"The off-season, cap and free agents survive a save")

	GameState.start_next_season()
	var ticked := true
	var sizes_ok := true
	for code in GameState.season.lists:
		if GameDB.enter_year(code) > GameState.season_year:
			# Not an active club yet - its debut list arrives at entry.
			continue
		var list: Array = GameState.season.lists[code]
		if list.size() < Contracts.MIN_LIST or list.size() > Contracts.MAX_LIST:
			sizes_ok = false
		for p in list:
			if int(p.get("contract_years", 0)) < 1 or p.has("resigned"):
				ticked = false
	_check(ticked, "Every contract ticks down at the rollover")
	_check(sizes_ok, "Every list stays between %d and %d" % [Contracts.MIN_LIST, Contracts.MAX_LIST])
	_check(GameState.free_agents.is_empty(), "Unsigned free agents leave at the rollover")
	_check(is_same(GameState.my_list, GameState.season.lists[GameState.my_club]),
			"Your list is the season's list after the rollover")
