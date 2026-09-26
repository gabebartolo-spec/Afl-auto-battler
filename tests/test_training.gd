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
	_test_plans_match_the_engine()
	_test_archetypes_differ()
	_test_traits_through_training()
	_test_old_plans_migrate()
	_test_training_news()
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
		var allowed: Dictionary = Ratings.ROLE_WEIGHTS["RUCK"]
		var only_ruck_stats := true
		for k in gains:
			if not allowed.has(k):
				only_ruck_stats = false
		_check(only_ruck_stats, "A ruck on the Position plan trains ruck stats")


func _test_manual_and_focus() -> void:
	_new_season()
	var manual := _first_of("DEF")
	var mid := _first_of("MID")
	GameState.set_player_plan(str(manual["id"]), "manual")
	GameState.set_player_plan(str(mid["id"]), "outside_mid")
	var manual_attr: Dictionary = (manual["attr"] as Dictionary).duplicate()
	var mid_attr: Dictionary = (mid["attr"] as Dictionary).duplicate()
	for i in range(3):
		GameState.advance()
	_check(manual["attr"] == manual_attr, "Manual never auto-spends")
	_check(int(manual["xp"]) > 0, "Manual banks the XP")
	# Injuries (seeded from the clock) or a week's card can leave him short
	# of a point after three games, so spend a known amount under his plan.
	mid["xp"] = int(mid["xp"]) + 400
	GameState.apply_plan_to(mid)
	var allowed: Dictionary = GameState.plan_weights(mid, "outside_mid")
	var only_plan := true
	var moved := false
	for k in mid_attr:
		if int(mid["attr"][k]) != int(mid_attr[k]):
			moved = true
			if not allowed.has(k):
				only_plan = false
	_check(moved and only_plan, "An archetype plan trains only its own attributes")


func _first_of(role: String) -> Dictionary:
	for p in GameState.my_list:
		if str(p["role"]) == role:
			return p
	return {}


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
	var own := "inside_mid" if str(p["role"]) == "MID" else ("key_def" if str(p["role"]) == "DEF" \
			else ("key_fwd" if str(p["role"]) == "FWD" else "position"))
	var gains := GameState.set_player_plan(str(p["id"]), own)
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
	_check(GameState.plan_for(p) == own or own == "position", "A player's own plan wins over the club plan")
	GameState.set_player_plan(str(p["id"]), "")
	_check(GameState.plan_for(p) == "position" and not p.has("train_plan"),
			"Choosing Club plan clears a player's own plan")


func _test_plans_survive_save() -> void:
	_new_season()
	var fwd := _first_of("FWD")
	var mid := _first_of("MID")
	GameState.set_player_plan(str(fwd["id"]), "key_fwd")
	GameState.set_player_plan(str(mid["id"]), "manual")
	GameState.advance()
	var fwd_state := [int(fwd["xp"]), int(fwd["overall"]), int(fwd["potential"]), (fwd["attr"] as Dictionary).duplicate()]
	var mid_xp := int(mid["xp"])
	GameState.save_career()
	GameState.load_career()
	var q := GameState.list_player(str(fwd["id"]))
	_check(GameState.plan_for(q) == "key_fwd", "A player's own plan survives a save")
	_check(GameState.plan_for(GameState.list_player(str(mid["id"]))) == "manual"
			and int(GameState.list_player(str(mid["id"]))["xp"]) == mid_xp, "Manual and its banked XP survive a save")
	_check([int(q["xp"]), int(q["overall"]), int(q["potential"]), q["attr"]] == fwd_state,
			"XP, rating, potential and attributes survive a save unchanged")
	GameState.set_default_plan("inside_mid")
	_check(GameState.default_train_plan == "position", "Only Position plan or Manual can be the club plan")


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
	GameState.list_player(depth)["injury_weeks"] = 0  # he may have been hurt in his senior game
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



## Every plan spends only on what the engine uses for the role it is offered
## to: the role core behind OVR, or a stat behind a trait that role can earn.
func _test_plans_match_the_engine() -> void:
	_new_season()
	var ok := true
	var bad := []
	for row in GameState.TRAIN_PLANS:
		if not row.has("weights"):
			continue
		for role in row["roles"]:
			for k in row["weights"]:
				if k == "star" or k == "durability" or not GameState.stat_useful_for_role(str(role), str(k)):
					ok = false
					bad.append("%s/%s/%s" % [row["key"], role, k])
	_check(ok, "Every archetype trains only attributes its role uses in a match %s" % str(bad))
	var pos_ok := true
	for role in ["MID", "DEF", "FWD", "RUCK"]:
		var p := _first_of(role)
		if p.is_empty():
			continue
		var w: Dictionary = GameState.plan_weights(p, "position")
		if w != Ratings.ROLE_WEIGHTS[role]:
			pos_ok = false
		for key in GameState.plans_for(p):
			for k in GameState.plan_weights(p, key):
				if not (p["attr"] as Dictionary).has(k):
					pos_ok = false
	_check(pos_ok, "Position plan trains each role's OVR core, and no plan names an attribute a player lacks")
	var d := _first_of("DEF")
	var offered: Array = GameState.plans_for(d)
	_check(offered.has("position") and offered.has("key_def") and offered.has("manual")
			and not offered.has("key_fwd") and not offered.has("inside_mid"),
			"A defender is offered defender plans, not forward or midfield ones (%s)" % str(offered))
	d["train_plan"] = "key_fwd"
	_check(GameState.plan_for(d) == "position", "A plan for another role falls back to Position plan")
	d.erase("train_plan")


## Two plans for the same player make different footballers.
func _test_archetypes_differ() -> void:
	_new_season()
	var mid := _first_of("MID")
	var built := {}
	for plan in ["inside_mid", "outside_mid"]:
		var p: Dictionary = mid.duplicate(true)
		p["train_plan"] = plan
		p["xp"] = 4000
		built[plan] = GameState._spend_with_weights(p, GameState.plan_weights(p, plan), false)
	var inside: Dictionary = built["inside_mid"]
	var outside: Dictionary = built["outside_mid"]
	_check(int(inside.get("contested", 0)) > int(outside.get("contested", 0)) + 5
			and int(outside.get("carry", 0)) > int(inside.get("carry", 0)) + 5,
			"Inside midfielders build contested ball, outside runners build carry (%s / %s)" % [str(inside), str(outside)])
	var fwd := _first_of("FWD")
	var small: Dictionary = fwd.duplicate(true)
	small["xp"] = 4000
	var sg := GameState._spend_with_weights(small, GameState.plan_weights(small, "small_fwd"), false)
	_check(not sg.has("marking"), "A small forward never trains marking (it would stop him crumbing)")


## Traits are still reached through the plan that suits them.
func _test_traits_through_training() -> void:
	_new_season()
	var fwd: Dictionary = _first_of("FWD").duplicate(true)
	fwd["attr"]["marking"] = 40
	fwd["attr"]["goalkicking"] = 50
	fwd["role2"] = ""
	fwd["xp"] = 2500
	_check(not Traits.has(fwd, "crumber"), "(setup) no Crumber yet")
	GameState._spend_with_weights(fwd, GameState.plan_weights(fwd, "small_fwd"), false)
	_check(Traits.has(fwd, "crumber"), "Small forward training unlocks Crumber")
	var d: Dictionary = _first_of("DEF").duplicate(true)
	d["attr"]["intercept"] = 74
	d["xp"] = 3000
	GameState._spend_with_weights(d, GameState.plan_weights(d, "key_def"), false)
	_check(int(d["attr"]["intercept"]) >= 80 and Traits.of(d).has("interceptor") or Traits.of(d).size() >= 2,
			"Key defender training reaches Interceptor (%d)" % int(d["attr"]["intercept"]))


## Saves from before the overhaul: removed plans and off-role plans fall
## back to Position plan, and a Manual club plan stays Manual per player.
func _test_old_plans_migrate() -> void:
	_new_season()
	var a: Dictionary = GameState.my_list[0]
	var b: Dictionary = GameState.my_list[1]
	var c: Dictionary = GameState.my_list[2]
	a["train_plan"] = "focus_marking"
	b["train_plan"] = "star"
	c.erase("train_plan")
	GameState.default_train_plan = "manual"
	GameState.save_career()
	GameState.load_career()
	var a2 := GameState.list_player(str(a["id"]))
	var b2 := GameState.list_player(str(b["id"]))
	var c2 := GameState.list_player(str(c["id"]))
	_check(GameState.default_train_plan == "position", "The club plan loads as Position plan")
	_check(GameState.plan_for(c2) == "manual", "A player who followed a Manual club plan stays on Manual")
	_check(not a2.has("train_plan") and not b2.has("train_plan")
			and GameState.plan_for(a2) == "position" and GameState.plan_for(b2) == "position",
			"Removed plans (single-stat focus, Star power) fall back to Position plan")


## After a game the report says what training changed, in a line.
func _test_training_news() -> void:
	_new_season()
	var p := _first_of("MID")
	p["xp"] = 3000
	var ov := int(p["overall"])
	var out := GameState.apply_train_plans()
	var rose := false
	for r in out["rises"]:
		if str(r[0]) == str(p["id"]) and int(r[1]) == ov and int(r[2]) > ov:
			rose = true
	_check(rose, "A rating rise is reported with before and after")
	GameState.last_training_report = {"auto": out}
	var line := GameState.training_summary_line()
	_check(line.begins_with("Training:") and line.contains("OVR"), "The summary line reports it (%s)" % line)
	GameState.last_training_report = {"auto": {"points": 5, "rises": [], "traits": []}}
	_check(GameState.training_summary_line() == "", "Stat points alone are not news")
