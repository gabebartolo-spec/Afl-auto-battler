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
