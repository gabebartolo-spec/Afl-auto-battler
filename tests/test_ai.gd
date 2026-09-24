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
	var d := Draft.new(GameDB.all_players_sorted(), GameDB.CLUB_ORDER.duplicate(), seed)
	d.start_for_user("")
	return d


func _test_league_draft_balance() -> void:
	for seed in [11, 23]:
		var d := _all_ai_draft(seed)
		_check(d.is_finished(), "An all-AI league draft completes (seed %d)" % seed)
		var two_rucks := true
		var hoarders := 0
		var with_good := 0
		for code in GameDB.CLUB_ORDER:
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
		_check(hoarders == 0 or with_good == GameDB.CLUB_ORDER.size(),
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


## A club that splashes on three $10 stars must still be able to fill its
## list: the cap reserve tracks what the remaining spots really cost (the
## pool has no $1 players).
func _test_no_cap_deadlock() -> void:
	var finished := 0
	for seed in range(1, 7):
		var d := Draft.new(GameDB.all_players_sorted(), GameDB.CLUB_ORDER.duplicate(), seed * 101)
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
