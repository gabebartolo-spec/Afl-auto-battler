extends RefCounted
## Training plans and the stat guide: plans spend a player's XP after every
## game, Manual banks it, single-stat focus touches only that stat, changing a
## plan spends banked XP at once, the club plan applies to anyone without his
## own, plans survive a save, and every stat has a full guide entry.
## Run through tests/run_training_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_default_plan_spends()
	_test_manual_and_focus()
	_test_changing_plans()
	_test_plans_survive_save()
	_test_reserves_development()
	_test_stat_guide_complete()
	GameState.delete_saved_career()
	print("Training tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))


func _snapshot() -> Dictionary:
	var out := {}
	for p in GameState.my_list:
		out[str(p["id"])] = (p["attr"] as Dictionary).duplicate()
	return out


func _test_default_plan_spends() -> void:
	_new_season()
	_check(GameState.default_train_plan == "position", "New careers start on the Position plan")
	var before := _snapshot()
	# Two games: a player left out of one earns less than a stat point costs.
	GameState.advance()
	var first_auto: Dictionary = GameState.last_training_report.get("auto", {})
	GameState.advance()
	var changed := 0
	for p in GameState.my_list:
		if p["attr"] != before[str(p["id"])]:
			changed += 1
	_check(changed > GameState.my_list.size() / 2,
			"The Position plan trains most of the list over two games (%d)" % changed)
	var auto: Dictionary = GameState.last_training_report.get("auto", {})
	_check(int(first_auto.get("points", 0)) > 0 and int(auto.get("points", 0)) > 0,
			"The report counts what the plans bought each game")
	_check(GameState.training_summary_line() != "", "The results screens get a summary line")
	# Position plan follows the role's priorities.
	var ruck := {}
	for p in GameState.my_list:
		if str(p["role"]) == "RUCK" and (auto["by_player"] as Dictionary).has(str(p["id"])):
			ruck = p
	if not ruck.is_empty():
		var gains: Dictionary = auto["by_player"][str(ruck["id"])]
		var allowed: Dictionary = GameState.AI_TRAIN_FOCUS["RUCK"]
		var only_ruck_stats := true
		for k in gains:
			if not allowed.has(k):
				only_ruck_stats = false
		_check(only_ruck_stats, "A ruck on the Position plan trains ruck stats")


func _test_manual_and_focus() -> void:
	_new_season()
	var manual: Dictionary = GameState.my_list[0]
	var focus: Dictionary = GameState.my_list[1]
	GameState.set_player_plan(str(manual["id"]), "manual")
	GameState.set_player_plan(str(focus["id"]), "focus_marking")
	var manual_attr: Dictionary = (manual["attr"] as Dictionary).duplicate()
	var focus_attr: Dictionary = (focus["attr"] as Dictionary).duplicate()
	for i in range(3):
		GameState.advance()
	_check(manual["attr"] == manual_attr, "Manual never auto-spends")
	_check(int(manual["xp"]) > 0, "Manual banks the XP")
	var only_marking := true
	for k in focus_attr:
		if k != "marking" and int(focus["attr"][k]) != int(focus_attr[k]):
			only_marking = false
	_check(only_marking, "A single-stat focus touches only that stat")
	_check(int(focus["attr"]["marking"]) > int(focus_attr["marking"]) or int(focus_attr["marking"]) >= 99,
			"A single-stat focus raises it")


func _test_changing_plans() -> void:
	_new_season()
	GameState.set_default_plan("manual")
	GameState.advance()
	GameState.advance()
	# The player with the most banked XP: one who sat out injured may not
	# have enough for a point yet.
	var p: Dictionary = GameState.my_list[0]
	for q in GameState.my_list:
		if int(q["xp"]) > int(p["xp"]):
			p = q
	var banked := int(p["xp"])
	_check(banked > 0, "The club plan on Manual banks everyone's XP")
	var gains := GameState.set_player_plan(str(p["id"]), "star")
	_check(not gains.is_empty() and int(p["xp"]) < banked,
			"Switching a player's plan spends his banked XP straight away")
	var other: Dictionary = {}
	for q in GameState.my_list:
		if q != p and (other.is_empty() or int(q["xp"]) > int(other["xp"])):
			other = q
	var other_xp := int(other["xp"])
	var result := GameState.set_default_plan("position")
	_check(int(other["xp"]) < other_xp and int(result.get("points", 0)) > 0,
			"Switching the club plan spends banked XP for everyone on it")
	_check(GameState.plan_for(p) == "star", "A player's own plan wins over the club plan")
	GameState.set_player_plan(str(p["id"]), "")
	_check(GameState.plan_for(p) == "position" and not p.has("train_plan"),
			"Choosing Club plan clears a player's own plan")


func _test_plans_survive_save() -> void:
	_new_season()
	var p: Dictionary = GameState.my_list[2]
	GameState.set_player_plan(str(p["id"]), "key_fwd")
	GameState.set_default_plan("inside_mid")
	GameState.save_career()
	GameState.load_career()
	_check(GameState.default_train_plan == "inside_mid", "The club plan survives a save")
	var q := GameState.list_player(str(p["id"]))
	_check(GameState.plan_for(q) == "key_fwd", "A player's own plan survives a save")


## One round with no week-event card in the way (a card can pay the whole
## list XP, which would blur the per-game figures).
func _round() -> void:
	GameState.week_event = {}
	GameState.advance()


## Pin `id` into the senior side (true) or leave him out (false).
func _pick(id: String, senior: bool) -> void:
	var side := GameState.current_side()
	var in_side := false
	for k in side:
		if (side[k] as Array).has(id):
			in_side = true
			if not senior:
				(side[k] as Array).erase(id)
	if senior and not in_side:
		var arr: Array = side[str(GameState.list_player(id)["role"])]
		arr[arr.size() - 1] = id
	side["OUT"] = [] if senior else [id]
	GameState.set_selection(side)


func _row(id: String) -> Dictionary:
	for row in GameState.last_training_report.get("rows", []):
		if str(row["id"]) == id:
			return row
	return {}


## Players left out of the senior side develop in the reserves at a reduced
## rate; injured and rested players do not; the award is paid once a round
## and survives a save.
func _test_reserves_development() -> void:
	_new_season()
	GameState.difficulty = "normal"
	var res_xp := GameState.reserves_xp()
	_check(res_xp == 19 and GameState.XP_SENIOR_GAME == 37,
			"A reserves game is half a full senior game (%d of %d)" % [res_xp, GameState.XP_SENIOR_GAME])
	var side := GameState.current_side()
	var senior := str(side["MID"][0])
	# A fit depth player outside the 22, and a second one we injure.
	var named := {}
	for k in side:
		for id in side[k]:
			named[str(id)] = true
	var spare := []
	for p in GameState.my_list:
		if not named.has(str(p["id"])) and Ratings.available(p):
			spare.append(str(p["id"]))
	var depth: String = spare[0]
	var hurt: String = spare[1]
	for id in [senior, depth, hurt]:
		GameState.set_player_plan(id, "manual")  # bank the XP so it can be counted
	GameState.list_player(hurt)["injury_weeks"] = 5

	# 1-3: one round.
	_pick(senior, true)
	var bank := {}
	for id in [senior, depth, hurt]:
		bank[id] = int(GameState.list_player(id)["xp"])
	_round()
	var s_gain := GameState.xp_gain_for(senior)
	_check(bool(_row(senior).get("on_ground", false)) and not bool(_row(senior).get("reserves", true)),
			"A selected player is on the ground, not in the reserves")
	_check(s_gain >= GameState.XP_SQUAD + GameState.XP_SELECTED + GameState.XP_NAMED and s_gain > res_xp,
			"A senior game pays the normal senior rate (%d)" % s_gain)
	_check(GameState.xp_gain_for(depth) == res_xp and bool(_row(depth)["reserves"]),
			"A fit player left out earns reserves development (%d)" % GameState.xp_gain_for(depth))
	_check(GameState.last_duty(depth) == "Reserves", "His duty reads Reserves")
	_check(GameState.xp_gain_for(hurt) == GameState.XP_SQUAD and not bool(_row(hurt)["reserves"]),
			"An injured player earns only the squad share (%d)" % GameState.xp_gain_for(hurt))
	_check(GameState.last_duty(hurt) == "Not selected", "An injured player is not in the reserves")
	_check(int(GameState.list_player(depth)["xp"]) - int(bank[depth]) == res_xp,
			"The reserves XP reaches his bank")
	var report := GameState.last_training_report
	var counted := 0
	for row in report["rows"]:
		if bool(row["reserves"]):
			counted += 1
	_check(counted > 0 and int(report["reserves_count"]) == counted
			and int(report["reserves_total"]) == counted * res_xp,
			"The report counts the reserves (%d at %d)" % [counted, res_xp])
	_check(GameState.reserves_summary_line().contains("+%d XP each" % res_xp),
			"The results screens get a reserves line")

	# 7: the same match cannot pay twice.
	var once := int(GameState.list_player(depth)["xp"])
	GameState._grant_match_xp(GameState.last_match)
	_check(int(GameState.list_player(depth)["xp"]) == once, "A round's XP is paid once only")

	# A rested (or suspended) player is not available either.
	var rested: String = spare[2]
	GameState.set_player_plan(rested, "manual")
	GameState.list_player(rested)["rested"] = true
	# 4: several rounds accumulate.
	var start := int(GameState.list_player(depth)["xp"])
	for i in range(3):
		_pick(depth, false)
		GameState.list_player(hurt)["injury_weeks"] = 5
		if i == 0:
			_round()
			_check(GameState.xp_gain_for(rested) == GameState.XP_SQUAD,
					"A rested player earns only the squad share")
		else:
			_round()
	_check(int(GameState.list_player(depth)["xp"]) - start == 3 * res_xp,
			"Three rounds in the reserves bank exactly %d XP (%d)" % [3 * res_xp,
			int(GameState.list_player(depth)["xp"]) - start])

	# 6: a save between rounds neither repeats nor loses the award.
	var before_save := int(GameState.list_player(depth)["xp"])
	GameState.save_career()
	GameState.load_career()
	_check(int(GameState.list_player(depth)["xp"]) == before_save, "Banked reserves XP survives a save")
	GameState._grant_match_xp(GameState.last_match)
	_check(int(GameState.list_player(depth)["xp"]) == before_save,
			"A reloaded save does not pay the last round again")
	_pick(depth, false)
	_round()
	_check(int(GameState.list_player(depth)["xp"]) - before_save == res_xp,
			"The next round after a load pays one reserves game")

	# 5: back in the senior side, the senior rate returns.
	_pick(depth, true)
	_round()
	_check(bool(_row(depth).get("on_ground", false)) and not bool(_row(depth)["reserves"])
			and GameState.xp_gain_for(depth) >= GameState.XP_SQUAD + GameState.XP_SELECTED + GameState.XP_NAMED,
			"Recalled, he earns senior XP again (%d)" % GameState.xp_gain_for(depth))

	# The difficulty multiplier applies to the reserves like any other XP.
	GameState.difficulty = "hard"
	_pick(depth, false)
	_round()
	_check(GameState.xp_gain_for(depth) == int(round(res_xp * 0.85)),
			"Hard scales reserves XP too (%d)" % GameState.xp_gain_for(depth))
	GameState.difficulty = "normal"


func _test_stat_guide_complete() -> void:
	var complete := true
	for row in GameState.TRAIN_STATS:
		var info: Array = StatGuide.STATS.get(str(row[0]), [])
		if info.size() != 4:
			complete = false
			continue
		for text in info:
			if str(text).length() < 10:
				complete = false
	_check(complete, "Every trainable stat has a full guide entry")
	var labels_ok := true
	for row in GameState.train_plan_options():
		if GameState.train_plan_label(str(row[0])) == "" or GameState.train_plan_description(str(row[0])) == "":
			labels_ok = false
	_check(labels_ok, "Every plan has a label and a description")
