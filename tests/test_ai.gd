extends RefCounted
## Rival club AI regression suite: the career draft builds balanced lists
## (two rucks each, the good rucks spread around, elite players early), the
## national draft weighs potential, and rival clubs train their players after
## every game, never past potential and never with your players' XP.
## Run through tests/run_ai_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_league_draft_balance()
	_test_club_evaluation()
	_test_no_cap_deadlock()
	_test_intake_values_potential()
	_test_rivals_train()
	print("AI tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _all_ai_draft(seed: int) -> Draft:
	var d := Draft.new(GameDB.all_players_sorted(),
			GameDB.active_clubs(2026).duplicate(), seed)
	d.start_for_user("")
	return d


func _test_league_draft_balance() -> void:
	for seed in [11, 23]:
		var d := _all_ai_draft(seed)
		_check(d.is_finished(), "An all-AI league draft completes (seed %d)" % seed)
		var two_rucks := true
		var hoarders := 0
		var with_good := 0
		for code in GameDB.active_clubs(2026):
			var rucks := 0
			var good := 0
			for p in d.club_lists[code]:
				if str(p["role"]) == "RUCK":
					rucks += 1
					if int(p["overall"]) >= 65:
						good += 1
			if rucks < 2 or rucks > 3:
				two_rucks = false
			if good >= 2:
				hoarders += 1
			if good >= 1:
				with_good += 1
		_check(two_rucks, "Every club drafts two or three rucks (seed %d)" % seed)
		_check(hoarders == 0 or with_good == 18,
				"No club takes two good rucks while another has none (seed %d)" % seed)
		# The best rucks are not left to the end, and round one is not all rucks.
		var first_round_rucks := 0
		var gawn_pick := 999
		for e in d.pick_history:
			var p = GameDB.player_by_id(str(e["player_id"]))
			if int(e["pick"]) <= 18 and str(p["role"]) == "RUCK":
				first_round_rucks += 1
			if str(p["real_name"]) == "Max Gawn":
				gawn_pick = int(e["pick"])
		_check(first_round_rucks >= 1 and first_round_rucks <= 4,
				"Round one takes the elite rucks, not only rucks (%d)" % first_round_rucks)
		_check(gawn_pick <= 18, "The best ruck goes in round one (pick %d)" % gawn_pick)
		var first: Dictionary = GameDB.player_by_id(str(d.pick_history[0]["player_id"]))
		_check(int(first["overall"]) >= 88, "Pick one is an elite player (%d)" % int(first["overall"]))


## Rival clubs judge players through their own scouting opinion (Draft
## club-specific evaluation): seeded, stable, different between clubs, never
## a club-wide bias, and never applied to your club or to the players.
func _test_club_evaluation() -> void:
	var clubs: Array = GameDB.active_clubs(2026).duplicate()
	var a := Draft.new(GameDB.all_players_sorted(), clubs, 4242)
	var b := Draft.new(GameDB.all_players_sorted(), clubs, 4242)
	a.start_for_user("COL")
	b.start_for_user("COL")
	var pool: Array = a.pool
	var same := true
	for code in ["GEE", "SYD"]:
		for i in range(0, pool.size(), 7):
			if not is_equal_approx(a._eval_error(code, pool[i]), b._eval_error(code, pool[i])):
				same = false
		if not is_equal_approx(a.club_eval_sd(code), b.club_eval_sd(code)):
			same = false
	_check(same, "Club evaluation is deterministic from the draft seed")
	var c := Draft.new(GameDB.all_players_sorted(), clubs, 4243)
	_check(not is_equal_approx(a._eval_error("GEE", pool[0]), c._eval_error("GEE", pool[0])),
			"A different draft seed gives clubs different opinions")

	# Two clubs rank the same players differently.
	var differ := 0
	var top := pool.slice(0, 60)
	for p in top:
		if absf(a._eval_error("GEE", p) - a._eval_error("SYD", p)) > 0.5:
			differ += 1
	_check(differ >= 30, "Two clubs value many of the same players differently (%d/60)" % differ)
	var order_gee := top.duplicate()
	order_gee.sort_custom(func(x, y): return a._worth(x) + a._eval_error("GEE", x) > a._worth(y) + a._eval_error("GEE", y))
	var order_syd := top.duplicate()
	order_syd.sort_custom(func(x, y): return a._worth(x) + a._eval_error("SYD", x) > a._worth(y) + a._eval_error("SYD", y))
	_check(order_gee != order_syd, "Two clubs order the top of the pool differently")

	# No club rates everyone up or down: its errors average out, and every
	# club's scouting SD sits in the calibrated range.
	var bias_ok := true
	var sd_ok := true
	var sds := {}
	for code in clubs:
		if code == "COL":
			continue
		var total := 0.0
		for p in pool:
			total += a._eval_error(code, p)
		if absf(total / float(pool.size())) > 0.5:
			bias_ok = false
		var sd := a.club_eval_sd(code)
		sds[snappedf(sd, 0.01)] = true
		if sd < Draft.AI_EVAL_SD_MIN or sd > Draft.AI_EVAL_SD_MAX:
			sd_ok = false
	_check(bias_ok, "No club's evaluation is a universal up- or down-grade")
	_check(sd_ok and sds.size() >= 10, "Clubs differ in how sharp their scouting is, within range")
	var capped := true
	for p in pool:
		if absf(a._eval_error("GEE", p)) > Draft.AI_EVAL_CLAMP * a.club_eval_sd("GEE") + 0.001:
			capped = false
	_check(capped, "Evaluation errors are capped")

	# Your club, and the intake draft, keep the shared valuation.
	_check(a._eval_error("COL", pool[0]) == 0.0, "Your club's picks get no evaluation error")
	var intake := Draft.build_intake(pool.slice(0, 20), ["A", "B"], ["A", "B"], 5,
			{"A": 30, "B": 30}, {})
	_check(intake._eval_error("A", pool[0]) == 0.0, "The intake draft keeps the shared valuation")

	# The same seed replays the same draft; players are not changed by it.
	var before := {}
	for p in GameDB.all_players_sorted():
		before[str(p["id"])] = [int(p["overall"]), int(p.get("potential", 0)), str(p["attr"])]
	var d1 := _all_ai_draft(777)
	var d2 := _all_ai_draft(777)
	var h1 := []
	var h2 := []
	for e in d1.pick_history:
		h1.append([e["club"], e["player_id"]])
	for e in d2.pick_history:
		h2.append([e["club"], e["player_id"]])
	_check(h1 == h2 and h1.size() == 18 * d1.target_size, "The same seed replays an identical draft")
	var untouched := true
	for p in GameDB.all_players_sorted():
		if before[str(p["id"])] != [int(p["overall"]), int(p.get("potential", 0)), str(p["attr"])]:
			untouched = false
	_check(untouched, "Club evaluation never changes a player's ratings")
	# Every list still meets the draft's rules.
	var lists_ok := true
	for code in clubs:
		var list: Array = d1.club_lists[code]
		var rucks := 0
		for p in list:
			if Ratings.plays_role(p, "RUCK"):
				rucks += 1
		if list.size() != d1.target_size or rucks < 2 or d1.spent_for(code) > d1.budget:
			lists_ok = false
	_check(lists_ok, "Every club's list has the full size, two rucks and fits the cap")
	var d3 := _all_ai_draft(778)
	var h3 := []
	for e in d3.pick_history:
		h3.append(e["player_id"])
	var ids1 := []
	for e in d1.pick_history:
		ids1.append(e["player_id"])
	_check(h3 != ids1, "Different seeds give different drafts, not just relabelled ones")

	# Clubs' opinions must not strand the pool's rucks on a few lists: no
	# rival takes a fourth, so a human who leaves the second ruck to the
	# final pick can still finish (this seed stranded one before the guard).
	var r := Draft.new(GameDB.all_players_sorted(), clubs, 445908)
	r.start_for_user("COL")
	var guard := 0
	while not r.is_finished() and guard < 2000:
		guard += 1
		if not r.is_user_turn():
			r.auto_until_user_turn()
			continue
		var choice := {}
		for cand in r.board("", "", "", "overall", true):
			if r.can_pick_player(cand):
				choice = cand
				break
		if choice.is_empty() or not r.pick(choice):
			break
	var max_rucks := 0
	for code in clubs:
		if code == "COL":
			continue
		var n := 0
		for p in r.club_lists[code]:
			if str(p["role"]) == "RUCK":
				n += 1
		max_rucks = maxi(max_rucks, n)
	_check(r.is_finished(), "A ruck-light human club can still complete the draft")
	_check(max_rucks <= 3, "No rival club takes a fourth ruck (%d)" % max_rucks)


## A club that splashes on three $10 stars must still be able to fill its
## list: the cap reserve tracks what the remaining spots really cost (the
## pool has no $1 players).
func _test_no_cap_deadlock() -> void:
	var finished := 0
	for seed in range(1, 7):
		var d := Draft.new(GameDB.all_players_sorted(),
				GameDB.active_clubs(2026).duplicate(), seed * 101)
		d.start_for_user("COL")
		for i in range(3):
			var top: Array = d.board("", "", "", "overall", true)
			if d.is_user_turn():
				d.pick(top[0])
		var guard := 0
		while not d.is_finished() and guard < 200:
			guard += 1
			if not d.is_user_turn():
				d.auto_until_user_turn()
				continue
			var choice := {}
			for c in d.board("", "", "", "overall", true):
				if d.can_pick_player(c):
					choice = c
					break
			if choice.is_empty() or not d.pick(choice):
				break
		if d.is_finished() and d.spent() <= d.budget:
			finished += 1
	_check(finished == 6, "A big-spending club always completes the draft under the cap (%d/6)" % finished)


func _test_intake_values_potential() -> void:
	# Two prospects, same rating, one with far more potential.
	var a := {"id": "t_a", "name": "A", "generic_name": "A", "real_name": "A", "club": "X",
			"num": 1, "role": "MID", "role2": "", "overall": 60, "potential": 62,
			"value": 3, "gl": 0, "di": 0, "gm": 0.0}
	var b := a.duplicate(true)
	b["id"] = "t_b"
	b["potential"] = 88
	var d := Draft.build_intake([a, b], ["A", "B"], ["A", "B"], 5,
			{"A": 30, "B": 30}, {"A": {"RUCK": 2, "MID": 12, "DEF": 8, "FWD": 8},
			"B": {"RUCK": 2, "MID": 12, "DEF": 8, "FWD": 8}})
	var pick := d._best_ai_pick("A")
	_check(str(pick.get("id", "")) == "t_b", "The national draft AI takes the higher potential")


func _test_rivals_train() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	# Manual: your players bank XP, so any attribute change would be the AI's.
	GameState.default_train_plan = "manual"
	var rival: Array = GameState.season.lists["COL"]
	var before := {}
	for p in rival:
		before[str(p["id"])] = (p["attr"] as Dictionary).duplicate()
	var mine_attr := {}
	for p in GameState.my_list:
		mine_attr[str(p["id"])] = (p["attr"] as Dictionary).duplicate()
	for i in range(6):
		GameState.advance()
	var trained := 0
	var past_pot := 0
	for p in rival:
		if p["attr"] != before[str(p["id"])]:
			trained += 1
		# The last point bought can tip a player one over, never more.
		if p["attr"] != before[str(p["id"])] and int(p["overall"]) > int(p["potential"]) + 1:
			past_pot += 1
	_check(trained > rival.size() / 2, "Rival players train after games (%d of %d)" % [trained, rival.size()])
	_check(past_pot == 0, "Rivals never train a player well past his POT (%d)" % past_pot)
	var untouched := true
	var earned := false
	for p in GameState.my_list:
		if p["attr"] != mine_attr[str(p["id"])]:
			untouched = false
		if int(p.get("xp", 0)) > 0:
			earned = true
	_check(untouched, "The AI never spends your players' XP")
	_check(earned, "Your players still bank their XP")
	var p0: Dictionary = rival[0]
	var spent_to_pot := p0.duplicate(true)
	spent_to_pot["xp"] = 100000
	spent_to_pot["potential"] = int(spent_to_pot["overall"]) + 3
	# Started the season well below POT, so POT (not the season cap) binds.
	spent_to_pot["season_start_ov"] = int(spent_to_pot["overall"]) + 3 - GameState.AI_SEASON_GAIN
	GameState.ai_spend_xp(spent_to_pot)
	_check(int(spent_to_pot["overall"]) >= int(spent_to_pot["potential"])
			and int(spent_to_pot["overall"]) <= int(spent_to_pot["potential"]) + 1,
			"With XP to burn, a rival trains exactly up to his POT")
	var capped := p0.duplicate(true)
	capped["xp"] = 100000
	capped["potential"] = int(capped["overall"]) + 12
	capped["season_start_ov"] = int(capped["overall"])
	GameState.ai_spend_xp(capped)
	_check(int(capped["overall"]) <= int(p0["overall"]) + GameState.AI_SEASON_GAIN + 1,
			"A rival gains at most AI_SEASON_GAIN in a season, however much XP he has")
