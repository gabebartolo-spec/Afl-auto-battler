extends RefCounted
## Coaching gameplay effects (CoachEffects.gd, Coaching Phase 5): teaching
## and match XP, tactics and game-plan execution, man-management and the
## morale cost of being left out. Run through tests/run_coach_effects_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_teaching()
	_test_tactics()
	_test_man_management()
	_test_in_career()
	GameState.delete_saved_career()
	CoachEffects.table = {}
	print("Coach effects tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _coach(job: String, v: int, spec := "") -> Dictionary:
	return {"cid": "T_" + job, "job": job, "status": "club", "club": "GEE",
			"skills": {"teach": v, "tactics": v, "manage": v},
			"spec": spec if spec != "" else {"MID": "MID", "FWD": "FWD", "DEF": "DEF", "DEV": "DEV"}.get(job, "")}


func _staff(v: int) -> Dictionary:
	var out := {}
	for job in ["SC", "SA", "MID", "FWD", "DEF", "DEV"]:
		out[job] = _coach(job, v)
	return out


func _test_teaching() -> void:
	var fwd := {"id": "F", "role": "FWD", "age": 26.0}
	var kid := {"id": "K", "role": "DEF", "age": 19.0}
	var weak := CoachEffects.xp_mult(_staff(60), fwd, true)
	var avg := CoachEffects.xp_mult(_staff(70), fwd, true)
	var elite := CoachEffects.xp_mult(_staff(92), fwd, true)
	_check(is_equal_approx(avg, 1.0), "Good teachers leave development as it was (%.3f)" % avg)
	_check(weak < avg and avg < elite, "Better teaching, more development (%.3f < %.3f < %.3f)" % [weak, avg, elite])
	_check(elite <= 1.10 + 0.0001 and CoachEffects.xp_mult(_staff(55), fwd, true) >= 0.95 - 0.0001,
			"Capped: never more than +10%, never worse than -5%")
	# The forwards coach teaches the forwards, not the defenders.
	var s := _staff(70)
	s["FWD"] = _coach("FWD", 92)
	var back := {"id": "B", "role": "DEF", "age": 26.0}
	_check(CoachEffects.xp_mult(s, fwd, true) > 1.0 and is_equal_approx(CoachEffects.xp_mult(s, back, true), 1.0),
			"An elite forwards coach lifts the forwards only")
	# Role fit beats a generic number: a defence specialist in the forwards job.
	var wrong := _staff(70)
	wrong["FWD"] = _coach("FWD", 92, "DEF")
	_check(CoachEffects.xp_mult(wrong, fwd, true) < CoachEffects.xp_mult(s, fwd, true),
			"A coach out of his line teaches it less well")
	# The development coach matters most to the kids and the reserves.
	var dev := _staff(70)
	dev["DEV"] = _coach("DEV", 92)
	_check(CoachEffects.xp_mult(dev, kid, true) > CoachEffects.xp_mult(dev, fwd, true)
			and CoachEffects.xp_mult(dev, fwd, false) > CoachEffects.xp_mult(dev, fwd, true),
			"The development coach helps the young and the reserves most")
	_check(CoachEffects.xp_mult({}, fwd, true) < 1.0, "Empty jobs teach nobody (a weak staff, not an error)")


func _test_tactics() -> void:
	var sq := Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE")
	var sq2 := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
	var sim := MatchSim.new(sq, sq2, 11)
	sim.set_tactics(0, {"gameplan": "attacking"})
	# An average list for the plan, so only the coaching moves it (PlanFit).
	sim.plan_fit[0]["attacking"] = 1.0
	var base := sim._pv(0, "goal")
	sq.tactics_exec = 1.15
	var sharp := sim._pv(0, "goal")
	sq.tactics_exec = 0.89
	var blunt := sim._pv(0, "goal")
	_check(is_equal_approx(base, 1.10) and sharp > base and blunt < base and sharp <= 1.10 + 0.10 * 0.15 + 0.0001,
			"A plan is executed better or worse, within 15%% of how it is written (%.3f / %.3f / %.3f)" % [blunt, base, sharp])
	sq.tactics_exec = 1.15
	_check(is_equal_approx(sim._pv(0, "clangers"), 1.0 + 0.12 * 1.15), "Its costs bite harder too: no free lunch")
	sim.set_tactics(0, {"gameplan": "balanced"})
	_check(is_equal_approx(sim._pv(0, "goal"), 1.0), "No plan, nothing to execute: tactics do not touch the score")
	# No plans in play: tactics change nothing at all.
	var a := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"), Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), 501).run()
	var sa := Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE")
	sa.tactics_exec = 1.15
	sa.tactics_read = 1.0
	var b := MatchSim.new(sa, Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), 501).run()
	_check(str(a["score"]) == str(b["score"]), "Without a plan to execute, tactics never change a result")
	# AI clubs pick valid plans from what a coach can see, the same way twice.
	var runs := []
	for i in range(2):
		var x := Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE")
		var y := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
		x.ai_plans = true
		y.ai_plans = true
		x.tactics_read = 1.0
		y.tactics_read = -0.75
		var m := MatchSim.new(x, y, 777)
		var r := m.run()
		runs.append([str(r["score"]), str(m.tactics_history)])
	_check(runs[0] == runs[1], "Plans chosen by AI clubs replay identically from the same seed")
	var valid := true
	var m2 := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"), Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), 9)
	(m2.squads[0] as Squad).ai_plans = true
	(m2.squads[1] as Squad).ai_plans = true
	m2.run()
	for h in m2.tactics_history:
		for t in h["plans"]:
			var plan := str((t as Dictionary).get("gameplan", "balanced"))
			if plan != "balanced" and not MatchSim.PLANS.has(plan):
				valid = false
	_check(valid and m2.tactics_history.size() >= 4, "AI clubs only ever pick real plans")
	# A sharp tactician reacts to a smaller margin than a poor one.
	var r3 := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"), Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), 5)
	r3.team_stats[0]["goals"] = 2.0
	(r3.squads[0] as Squad).tactics_read = 1.0
	var sharp_plan := str(r3.ai_tactics(0)["gameplan"])
	(r3.squads[0] as Squad).tactics_read = -0.75
	var slow_plan := str(r3.ai_tactics(0)["gameplan"])
	_check(sharp_plan == "controlled" and slow_plan == str(r3.standing[0]),
			"Two goals up: a sharp coach shuts it down, a poor one has not noticed (%s / %s)" % [sharp_plan, slow_plan])


func _test_man_management() -> void:
	var p := {"id": "P", "role": "MID", "overall": 70}
	_check(is_zero_approx(CoachEffects.soften(_staff(60), p)) and is_zero_approx(CoachEffects.soften(_staff(65), p)),
			"A poor man-manager spares nothing")
	var elite := CoachEffects.soften(_staff(92), p)
	_check(elite > 0.3 and elite <= CoachEffects.SOFTEN_MAX, "An elite one spares up to 40%% (%.2f)" % elite)
	for staff_v in [60, 92]:
		var soft := CoachEffects.soften(_staff(staff_v), p)
		var q := {"id": "P", "role": "MID", "overall": 80, "morale": 70}
		var path := []
		for i in range(8):
			ClubLife.morale_after_match([q], {}, false, {"P": soft})
			path.append(ClubLife.morale(q))
		if staff_v == 60:
			_check(int(path[-1]) < 70 and int(path[0]) == 64, "Left out eight weeks with a poor man-manager: the usual slide (%s)" % str(path))
		else:
			_check(int(path[-1]) < 70 and int(path[0]) > 64, "With an elite one he still slides, just more slowly (%s)" % str(path))
			_check(ClubLife.morale(q) >= 0, "Morale stays in bounds")
	var played := {"id": "P", "role": "MID", "overall": 70, "morale": 50}
	ClubLife.morale_after_match([played], {"P": true}, true, {"P": 0.4})
	_check(ClubLife.morale(played) == 54, "Softening never touches what playing is worth")


func _test_in_career() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.advance()
	_check(not CoachEffects.table.is_empty() and CoachEffects.table.has("SYD") and bool(CoachEffects.table["SYD"]["ai"])
			and not bool(CoachEffects.table["GEE"]["ai"]), "Every club's tactics are read from its staff; yours are your calls")
	var res: Dictionary = GameState.my_last_result()
	var before := 0
	for p in GameState.my_list:
		before += int(p.get("xp", 0))
	GameState._grant_match_xp(res)
	var after := 0
	for p in GameState.my_list:
		after += int(p.get("xp", 0))
	_check(before == after, "A round's XP is paid once, however often it is asked")
	_check(GameState.save_career() and GameState.load_career(), "The career saves and loads")
	var saved := FileAccess.get_file_as_string(GameState.save_path)
	_check(not saved.contains("tactics_exec") and not saved.contains("tactics_read"), "Nothing derived is saved: effects are read from the coaches")
