extends RefCounted
## Legs and rotations, match moments, the impact readout and the rival
## coach. Run through tests/run_match_game_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_auto_sim_untouched()
	_test_legs_and_rotations()
	_test_moments()
	_test_set_shot()
	_test_live_determinism()
	_test_impact_and_ai()
	_test_traits()
	print("Match game tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _sim(seed: int, a := "GEE", b := "COL") -> MatchSim:
	return MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)


func _test_auto_sim_untouched() -> void:
	var r1 := _sim(42).run()
	var r2 := _sim(42).run()
	_check(r1["score"] == r2["score"] and r1["events"].size() == r2["events"].size(),
			"A simulated match is still deterministic")
	_check((r1["moments"] as Array).is_empty(), "Simulated matches never stop for moments")


func _test_legs_and_rotations() -> void:
	var sim := _sim(7)
	sim.begin_quarter()
	sim.continue_quarter()
	var mid_e := 0.0
	var n := 0
	for p in sim.squads[0].ground:
		if str(p["role"]) == "MID":
			mid_e += float(sim.energy[str(p["id"])])
			n += 1
	_check(n > 0 and mid_e / n < 90.0, "Midfielders tire during a quarter (%.0f%%)" % (mid_e / maxi(1, n)))
	sim.end_quarter()
	while sim.current_quarter <= 4:
		sim.run_quarter()
	var res := sim.result()
	_check(int(res["interchanges"][0]) > 5, "Coaches rotate players (%d interchanges)" % int(res["interchanges"][0]))
	_check((res["roster"][0] as Array).size() > 18, "Bench players who came on are in the match roster")
	var subs := 0
	for ev in res["events"]:
		if str(ev["kind"]) == "sub":
			subs += 1
	_check(subs == int(res["interchanges"][0]) + int(res["interchanges"][1]),
			"Every interchange is in the event log for the oval")
	var hard := 0
	var stars := 0
	for i in range(6):
		var a := _sim(100 + i)
		a.set_rotation_policy(0, "hard")
		hard += int(a.run()["interchanges"][0])
		var b := _sim(100 + i)
		b.set_rotation_policy(0, "stars")
		stars += int(b.run()["interchanges"][0])
	_check(hard > stars, "Rotating hard makes more interchanges than riding the stars (%d vs %d)" % [hard, stars])
	var tired := {"id": "x", "attr": {"goalkicking": 80}}
	sim.energy["x"] = 30.0
	var tired_fit := sim.fit(tired)
	sim.energy["x"] = 100.0
	_check(tired_fit < 0.9 and sim.fit(tired) > 1.0, "Tired players play below their rating, fresh ones above")


## Step a live match, answering every moment with `pick`. Returns the sim.
func _live(seed: int, pick: Callable) -> MatchSim:
	var sim := _sim(seed)
	sim.moment_side = 0
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(pick.call(sim.pending_moment)))
		sim.end_quarter()
	return sim


func _test_moments() -> void:
	var total := 0
	var kinds := {}
	var ok_log := true
	var consistent := true
	for i in range(6):
		var sim := _live(300 + i, func(m): return (m["options"] as Array).size() - 1)
		for m in sim.moments:
			total += 1
			kinds[str(m["kind"])] = true
			if not m.has("choice_label") or not m.has("outcome") or int(m["side"]) != 0:
				ok_log = false
		var res := sim.result()
		for side in range(2):
			var pg := 0
			for id in res["players"]:
				var belongs := false
				for r in res["roster"][side]:
					if str(r["id"]) == str(id):
						belongs = true
				if belongs:
					pg += int(res["players"][id].get("goals", 0))
			var qg := 0
			for q in res["q_goals"]:
				qg += int(q[side])
			if pg != int(res["goals"][side]) or qg != int(res["goals"][side]):
				consistent = false
	_check(total >= 12 and total <= 6 * 8, "Live matches stop for a handful of moments (%d in 6 games)" % total)
	_check(kinds.size() >= 3, "Several kinds of moment come up (%s)" % str(kinds.keys()))
	_check(ok_log, "Every moment is logged with the call and how it came off")
	_check(consistent, "Goals from moments add up: players, quarters and the scoreboard agree")
	# Skip: run_quarter takes the default call for anything pending.
	var sim := _sim(301)
	sim.moment_side = 0
	var res := sim.run()
	_check(not (res["moments"] as Array).is_empty() and sim.pending_moment.is_empty(),
			"Skipping to full time answers pending moments with the default call")


func _test_set_shot() -> void:
	var found := false
	var scored_right := true
	for i in range(12):
		var sim := _sim(500 + i)
		sim.moment_side = 0
		while sim.current_quarter <= 4 and not found:
			sim.begin_quarter()
			while not sim.continue_quarter():
				var m := sim.pending_moment
				if str(m["kind"]) == "set_shot" and not found:
					found = true
					var opts: Array = m["options"]
					_check(opts.size() >= 2 and str(opts[0]["detail"]).contains("%"),
							"A set shot offers choices with their odds")
					var before := sim.score(0)
					var done := sim.resolve_moment(0)
					var gained := sim.score(0) - before
					scored_right = gained == int(done["points"]) and [0, 1, 6].has(gained)
				else:
					sim.resolve_moment(int(m.get("default", 0)))
			sim.end_quarter()
		if found:
			break
	_check(found, "Set-shot moments come up in live matches")
	_check(scored_right, "A set shot's result goes on the scoreboard")


func _test_live_determinism() -> void:
	var a := _live(777, func(m): return 0)
	var b := _live(777, func(m): return 0)
	_check(a.result()["score"] == b.result()["score"], "Same match, same calls, same result")


func _test_impact_and_ai() -> void:
	var sim := _sim(900)
	sim.set_tactics(0, {"gameplan": "attacking"})
	var res := sim.run()
	var imp: Array = res["impact"]
	_check(absf(float((imp[0] as Dictionary).get("gameplan", 0.0))) > 0.5,
			"A gameplan's effect is measured in expected points")
	var lines := CoachReport.impact_lines(imp, [{}, {}], 0)
	_check(not lines.is_empty() and str(lines[0]["label"]).begins_with("Your")
			or str(lines[0]["label"]).begins_with("Their"), "The readout names what the points came from")
	# The rival coach reads a plan you keep running.
	var live := _sim(901)
	for q in range(2):
		live.set_tactics(0, {"gameplan": "attacking"})
		live.set_tactics(1, {"gameplan": "balanced"})
		live.run_quarter()
	_check(str(live.ai_tactics(1)["gameplan"]) == "defensive",
			"Run Attack corridor twice and the rival coach presses")
	live.set_tactics(0, {"gameplan": "controlled"})
	live.run_quarter()
	_check(live.ai_tactics(1).has("tag_id"), "After half time the rival coach tags your best player")
	# A tired star can be rested.
	var tired := _sim(902)
	tired.moment_side = 0
	var star: Dictionary = {}
	for p in tired.squads[0].ground:
		if int(p["overall"]) >= MatchSim.STAR_OVR:
			star = p
	if not star.is_empty():
		tired.energy[str(star["id"])] = 40.0
		tired.begin_quarter()
		tired.continue_quarter()
		var m := tired.pending_moment
		_check(str(m.get("kind", "")) == "tired", "A cooked star brings a rest-him call")
		tired.resolve_moment(0)
		var still_on := false
		for p in tired.squads[0].ground:
			if str(p["id"]) == str(star["id"]):
				still_on = true
		_check(not still_on, "Resting him takes him off the ground")


func _fake(id: String, role: String, attr: Dictionary) -> Dictionary:
	var base := {"disposal": 50, "contested": 50, "marking": 50, "pressure": 45, "intercept": 45,
			"carry": 50, "goalkicking": 40, "accuracy": 55, "creating": 45, "ruck": 10,
			"discipline": 50, "durability": 75, "star": 25}
	base.merge(attr, true)
	return {"id": id, "role": role, "attr": base, "overall": 70, "num": 1, "club": "GEE"}


func _test_traits() -> void:
	var shooter := _fake("t1", "FWD", {"accuracy": 80, "goalkicking": 70, "marking": 40})
	var t := Traits.of(shooter)
	_check(t.has("sharpshooter") and t.has("crumber"), "High stats earn traits (%s)" % str(t))
	var many := _fake("t2", "MID", {"disposal": 95, "contested": 95, "accuracy": 90, "durability": 96, "discipline": 10})
	var mt := Traits.of(many)
	var good := 0
	for k in mt:
		if not Traits.is_bad(k):
			good += 1
	_check(good == Traits.MAX_GOOD and mt.has("hothead"), "At most two good traits, plus Hothead for poor discipline")
	var close := _fake("t3", "FWD", {"accuracy": 68})
	var near: Array = Traits.near(close)
	_check(not near.is_empty() and str(near[0]["key"]) == "sharpshooter" and int(near[0]["gap"]) == 3,
			"Training shows how close a player is to a trait")
	var ground := [_fake("b1", "MID", {"contested": 90}), _fake("b2", "MID", {"contested": 88})]
	_check(Traits.active(ground).has("engine_room"), "Two contested bulls switch on the engine room")
	_check(not Traits.active([ground[0]]).has("engine_room"), "One is not enough")
	var rows := Traits.progress([ground[0]])
	var er := {}
	for r in rows:
		if str(r["key"]) == "engine_room":
			er = r
	_check(not er.is_empty() and int(er["missing"]) == 1, "Synergy progress counts what is missing")
	# In a match: synergies are live and credited.
	var credited := false
	var any_syn := false
	for code in GameDB.CLUB_ORDER:
		var sim := _sim(40, code, "COL" if code != "COL" else "GEE")
		if not (sim.synergies[0] as Array).is_empty():
			any_syn = true
			var res := sim.run()
			if absf(float((res["impact"][0] as Dictionary).get("traits", 0.0))) > 0.0:
				credited = true
			break
	_check(any_syn and credited, "A side's synergies play and show in the readout")
