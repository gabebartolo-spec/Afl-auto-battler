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
	_test_stoppage_location()
	_test_legs_and_rotations()
	_test_moments()
	_test_set_shot()
	_test_live_determinism()
	_test_impact_and_ai()
	_test_pep_talks()
	_test_hothead()
	_test_lockdown_midfielder()
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


## Restarts: a goal or a quarter break -> centre bounce; a behind -> the
## other side kicks in from its goal square, uncontested; any other stoppage
## is balled up where play stopped, and logged there.
func _test_stoppage_location() -> void:
	var sim := _sim(42)
	var evs: Array = sim.run()["events"]
	var ballups := 0
	var on_ground := true
	var centre_ok := true
	var last := ""
	var last_fp := 0.0
	for ev in evs:
		var kind := str(ev["kind"])
		if kind == "ballup":
			ballups += 1
			on_ground = on_ground and absf(float(ev["fp"])) <= 85.0
		elif ["handball", "kick", "mark"].has(kind) and float(ev["fp"]) == 0.0 \
				and last_fp != 0.0:
			# The ball came back to the centre: only a goal or a break does that.
			centre_ok = centre_ok and ["", "goal", "quarter"].has(last)
		if not ["sub", "moment", "clanger", "free"].has(kind):
			last = kind
			last_fp = 0.0 if ["goal", "quarter"].has(kind) else float(ev["fp"])
	_check(ballups > 20, "Around-the-ground ball-ups are logged (%d)" % ballups)
	_check(on_ground, "Every ball-up is on the ground")
	_check(centre_ok, "A centre bounce only follows a goal or a quarter break")
	# Every behind is followed by a kick-in: the other side, from its goal
	# square, with a kick (never a ball-up or a handball).
	var behinds := 0
	var kick_ins_ok := true
	for i in range(evs.size()):
		var ev: Dictionary = evs[i]
		if str(ev["kind"]) != "behind":
			continue
		var j := i + 1
		while j < evs.size() and ["sub", "moment", "clanger", "free"].has(str(evs[j]["kind"])):
			j += 1
		if j >= evs.size() or ["quarter", "final"].has(str(evs[j]["kind"])):
			continue
		behinds += 1
		var nx: Dictionary = evs[j]
		kick_ins_ok = kick_ins_ok and ["kick", "mark"].has(str(nx["kind"])) \
				and int(nx["side"]) == 1 - int(ev["side"]) \
				and is_equal_approx(float(nx["fp"]), sim.kick_in_fp(int(ev["side"])))
	_check(behinds > 5 and kick_ins_ok, "Every behind is followed by a kick-in from the goal square (%d)" % behinds)
	# A kick-in has no ruck contest: no hit-out, no clearance, no ball-up. Five
	# seeds, so a stoppage roll sneaking back in (half of chains) shows up.
	var uncontested := true
	for seed in [7, 8, 9, 10, 11]:
		var k := _sim(seed)
		k.fp = k.kick_in_fp(0)
		k.kick_in = true
		k.next_side = 1
		k.at_centre = false
		var before := [(k.team_stats[0] as Dictionary).duplicate(), (k.team_stats[1] as Dictionary).duplicate()]
		var n := k.events.size()
		k._play_one_chain(Ratings.T)
		for side in range(2):
			for key in ["hitouts", "clearances"]:
				uncontested = uncontested and int((k.team_stats[side] as Dictionary).get(key, 0)) \
						== int((before[side] as Dictionary).get(key, 0))
		var first: Dictionary = k.events[n] if k.events.size() > n else {}
		uncontested = uncontested and ["kick", "mark"].has(str(first.get("kind", ""))) \
				and int(first.get("side", -1)) == 1
	_check(uncontested, "A kick-in is uncontested: the defending side kicks, no hit-out or clearance")


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
	# The impact ledger must credit a gameplan with the expected points it is
	# worth, to the side that runs it, and nothing when nobody runs one. Checked
	# per match over five seeds. "Controlled" is used for the size check
	# because every effect it credits helps the side running it (fewer
	# turnovers, fewer clangers, a slightly better shot), so its credit has a
	# known sign in every match. "Attacking" trades a better shot for more
	# clangers and a more exposed defence, so its net swings either way and
	# says nothing about whether the ledger works.
	var zero_ok := true
	var credited_ok := true
	var owner_ok := true
	var imp: Array = []
	for seed in [900, 901, 902, 903, 904]:
		var even := _sim(seed).run()["impact"] as Array
		for side in range(2):
			zero_ok = zero_ok and float((even[side] as Dictionary).get("gameplan", 0.0)) == 0.0
		var sim := _sim(seed)
		sim.set_tactics(0, {"gameplan": "controlled"})
		imp = sim.run()["impact"]
		credited_ok = credited_ok and float((imp[0] as Dictionary).get("gameplan", 0.0)) > 0.5
		owner_ok = owner_ok and float((imp[1] as Dictionary).get("gameplan", 0.0)) == 0.0
	_check(zero_ok, "No gameplan, no gameplan points (balanced v balanced, every match)")
	_check(credited_ok, "A gameplan's effect is measured in expected points (every match)")
	_check(owner_ok, "Gameplan points go to the side that runs the plan")
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


## Calm the group is a live option: a milder, quarter-long Slow it down,
## distinct from Fire them up and from the default Stay composed.
func _test_pep_talks() -> void:
	var sim := _sim(55)
	sim.set_tactics(0, {"pep": "calm"})
	sim.set_tactics(1, {"pep": "fire_up"})
	_check(sim._pep_mult(0, "clangers") < 1.0 and sim._pep_mult(0, "taken") < 1.0
			and sim._pep_mult(0, "gain") < 1.0 and sim._pep_mult(0, "pace") < 1.0,
			"Calm the group cuts clangers, pressure felt and running, for less ground gained")
	_check(sim._contest_pep(0) == 0.0 and sim._contest_pep(1) > 0.0
			and sim._pep_mult(1, "clangers") == 1.0 and sim._pep_mult(1, "taken") == 1.0,
			"Calm the group and Fire them up do different things")
	# Legs last longer: the same chain drains a calm side less than a steady one.
	var calm := _sim(56)
	var steady := _sim(56)
	calm.set_tactics(0, {"pep": "calm"})
	steady.set_tactics(0, {"pep": "steady"})
	calm._after_chain()
	steady._after_chain()
	var e_calm := 0.0
	var e_steady := 0.0
	for p in calm.squads[0].ground:
		e_calm += float(calm.energy[str(p["id"])])
	for p in steady.squads[0].ground:
		e_steady += float(steady.energy[str(p["id"])])
	_check(e_calm > e_steady, "Calm the group saves legs (%.2f v %.2f energy)" % [e_calm, e_steady])
	# Played for a quarter, it acts on the chains and the readout credits it.
	var q := _sim(57)
	q.set_tactics(0, {"pep": "calm"})
	q.set_tactics(1, {"pep": "steady"})
	q.run_quarter()
	var composed := _sim(57)
	composed.set_tactics(0, {"pep": "steady"})
	composed.set_tactics(1, {"pep": "steady"})
	composed.run_quarter()
	_check(float((q.impact[0] as Dictionary).get("pep", 0.0)) > 0.0,
			"A calmed quarter shows in the readout as pep-talk points")
	_check(float((composed.impact[0] as Dictionary).get("pep", 0.0)) == 0.0,
			"Stay composed changes nothing")
	_check(CoachReport.pep_effect("calm") != CoachReport.pep_effect("steady")
			and CoachReport.pep_effect("calm") != CoachReport.pep_effect("fire_up"),
			"The coach box describes what calming the group does")


## GEE v COL with every player at discipline 60, except four of GEE's
## on-ground players at `disc` (20 makes them Hotheads, 21 does not).
func _discipline_sim(seed: int, disc: int) -> MatchSim:
	var lists := []
	for code in ["GEE", "COL"]:
		var l: Array = []
		for p in GameDB.club_list(code):
			var q: Dictionary = p.duplicate(true)
			(q["attr"] as Dictionary)["discipline"] = 60
			l.append(q)
		lists.append(l)
	var home := Squad.new("GEE", lists[0], true, "GEE")
	var away := Squad.new("COL", lists[1], false, "COL")
	for i in range(4):
		(home.ground[i]["attr"] as Dictionary)["discipline"] = disc
	return MatchSim.new(home, away, seed)


## Hothead: he gives away 50% more clangers than his discipline alone would,
## on top of his teammates' share - so his side gives away more clangers and
## free kicks, not just him.
func _test_hothead() -> void:
	var hot := _discipline_sim(60, 20)
	var cool := _discipline_sim(60, 21)
	_check(hot._trait(hot.squads[0].ground[0], "hothead")
			and not cool._trait(cool.squads[0].ground[0], "hothead"),
			"Discipline 20 makes a Hothead, 21 does not")
	var hw: Array = hot._clanger_weights(0)
	var cw: Array = cool._clanger_weights(0)
	_check(float(hw[0][0]) / float(cw[0][0]) > 1.45,
			"A Hothead is half as likely again to be the one giving it away")
	_check(float(hw[1]) > 1.15 and is_equal_approx(float(cw[1]), 1.0),
			"Four Hotheads lift the side's clanger rate (x%.2f); none leave it alone" % float(hw[1]))
	# Played out: the side with the Hotheads gives away more clangers and
	# more free kicks, and its Hotheads more of them.
	var ids := []
	for i in range(4):
		ids.append(str(hot.squads[0].ground[i]["id"]))
	var team := {"hot": [0.0, 0.0, 0.0], "cool": [0.0, 0.0, 0.0]}
	for seed in range(61, 67):
		for k in ["hot", "cool"]:
			var res: Dictionary = _discipline_sim(seed, 20 if k == "hot" else 21).run()
			var t: Array = team[k]
			t[0] += float(res["team"][0].get("clangers", 0.0))
			t[1] += float(res["team"][0].get("frees_against", 0.0))
			for id in ids:
				t[2] += float((res["players"].get(id, {}) as Dictionary).get("clangers", 0.0))
	var h: Array = team["hot"]
	var c: Array = team["cool"]
	_check(h[0] > c[0] * 1.08, "Hotheads cost their side clangers (%d v %d over six games)" % [h[0], c[0]])
	_check(h[1] > c[1], "Hotheads give away more free kicks (%d v %d)" % [h[1], c[1]])
	_check(h[2] > c[2] * 1.2, "The Hotheads themselves give away far more (%d v %d)" % [h[2], c[2]])


## GEE v COL, every COL player at pressure 50 (no Lockdowns), except COL's
## first on-ground midfielder at `minder_pressure` (64+ makes him a Lockdown).
func _lockdown_sim(minder_pressure: int) -> MatchSim:
	var lists := []
	for code in ["GEE", "COL"]:
		var l: Array = []
		for p in GameDB.club_list(code):
			l.append(p.duplicate(true))
		lists.append(l)
	var home := Squad.new("GEE", lists[0], true, "GEE")
	var away := Squad.new("COL", lists[1], false, "COL")
	for p in away.ground + away.bench:
		(p["attr"] as Dictionary)["pressure"] = 50
	for p in away.ground:
		if str(p["role"]) == "MID":
			(p["attr"] as Dictionary)["pressure"] = minder_pressure
			break
	return MatchSim.new(home, away, 5)


## GEE's on-ground players of `role`, best rated first.
func _ranked(sim: MatchSim, role: String) -> Array:
	var out: Array = []
	for p in sim.squads[0].ground:
		if str(p["role"]) == role:
			out.append(p)
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return out


## Lockdown on a midfielder: he picks up their best midfielder, whose shots
## are 4% less likely to be goals. Before, only the forward-50 defender (a
## defender) could ever be the Lockdown on a shot.
func _test_lockdown_midfielder() -> void:
	var lock := _lockdown_sim(80)
	var none := _lockdown_sim(63)
	var minder: Dictionary = lock.squads[1].ground.filter(func(p): return str(p["role"]) == "MID")[0]
	_check(lock._trait(minder, "lockdown")
			and not none._trait(none.squads[1].ground.filter(func(p): return str(p["role"]) == "MID")[0], "lockdown"),
			"Pressure 64 makes a midfielder a Lockdown, 63 does not")
	var fwd := _fake("lk_fwd", "FWD", {"pressure": 95})
	_check(not Traits.of(fwd).has("lockdown"), "A forward cannot be a Lockdown, however hard he presses")
	var best_lock: Dictionary = _ranked(lock, "MID")[0]
	var best_none: Dictionary = _ranked(none, "MID")[0]
	_check(str(lock._midfield_minder(0, best_lock).get("id", "")) == str(minder["id"]),
			"The Lockdown midfielder picks up their best midfielder")
	var p_lock := lock.shot_chance(0, best_lock, true, false)
	var p_none := none.shot_chance(0, best_none, true, false)
	_check(is_equal_approx(p_lock, p_none * 0.96),
			"His opponent's shots are 4%% less likely to be goals (%.4f v %.4f)" % [p_lock, p_none])
	# Only his opponent: their other midfielders and their forwards shoot as before.
	var second_lock: Dictionary = _ranked(lock, "MID")[1]
	var second_none: Dictionary = _ranked(none, "MID")[1]
	_check(is_equal_approx(lock.shot_chance(0, second_lock, true, false),
			none.shot_chance(0, second_none, true, false)),
			"A midfielder he is not on shoots as before")
	var f_lock: Dictionary = _ranked(lock, "FWD")[0]
	var f_none: Dictionary = _ranked(none, "FWD")[0]
	_check(lock._midfield_minder(0, f_lock).is_empty() and is_equal_approx(
			lock.shot_chance(0, f_lock, true, false), none.shot_chance(0, f_none, true, false)),
			"A Lockdown midfielder does not mind their forwards")


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
		if (GameDB.club_list(code) as Array).is_empty():
			continue  # expansion clubs have no 2026 data
		var sim := _sim(40, code, "COL" if code != "COL" else "GEE")
		if not (sim.synergies[0] as Array).is_empty():
			any_syn = true
			var res := sim.run()
			if absf(float((res["impact"][0] as Dictionary).get("traits", 0.0))) > 0.0:
				credited = true
			break
	_check(any_syn and credited, "A side's synergies play and show in the readout")
