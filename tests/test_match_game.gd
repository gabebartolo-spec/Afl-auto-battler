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
	_test_play_through()
	_test_hothead()
	_test_lockdown_midfielder()
	_test_traits()
	_test_metres_and_efficiency()
	_test_ruck_integrity()
	_test_stat_credits()
	_test_m2_stats()
	_test_no_role_gates()
	_test_spoils_and_crumbs()
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
	# The rival coach plays its usual game and reacts to the scoreboard; it
	# does not read and counter the plan you keep running.
	var live := _sim(901)
	for q in range(2):
		live.set_tactics(0, {"gameplan": "attacking"})
		live.set_tactics(1, {"gameplan": "balanced"})
		live.run_quarter()
	var margin := live.score(1) - live.score(0)
	var expect := str(live.standing[1])
	var react := 18.0 - 8.0 * float((live.squads[1] as Squad).tactics_read)
	if margin >= react:
		expect = "controlled"
	elif margin <= -react:
		expect = "attacking"
	_check(str(live.ai_tactics(1)["gameplan"]) == expect,
			"Run Attack corridor twice: the rival coach keeps its usual game or plays the scoreboard (%s)" % expect)
	live.set_tactics(0, {"gameplan": "controlled"})
	live.run_quarter()
	var tagged := str(live.ai_tactics(1).get("tag_id", ""))
	var tagged_mid := false
	for p in (live.squads[0] as Squad).ground:
		if str(p["id"]) == tagged:
			tagged_mid = MatchSim.taggable(p)
	_check(tagged != "" and tagged_mid, "After half time the rival coach tags one of your midfielders")
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


## Metres gained and disposal efficiency come from the chain itself: metres
## are the ball's real forward movement, an effective disposal is one his
## side kept.
func _test_metres_and_efficiency() -> void:
	var ok_sum := true
	var ok_bounds := true
	var fwd := [0.0, 0.0]
	var dfn := [0.0, 0.0]
	for i in range(12):
		var res := _sim(900 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			var m := 0.0
			var e := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				m += float(st.get("metres_gained", 0.0))
				e += float(st.get("effective_disposals", 0.0))
				if float(st.get("metres_gained", 0.0)) < 0.0 \
						or float(st.get("effective_disposals", 0.0)) > float(st.get("disposals", 0.0)):
					ok_bounds = false
				var role := str(r.get("list_role", r["role"]))
				if role == "FWD":
					fwd[0] += float(st.get("effective_disposals", 0.0))
					fwd[1] += float(st.get("disposals", 0.0))
				elif role == "DEF":
					dfn[0] += float(st.get("effective_disposals", 0.0))
					dfn[1] += float(st.get("disposals", 0.0))
			if absf(m - float(t.get("metres_gained", 0.0))) > 0.5 or absf(e - float(t.get("effective_disposals", 0.0))) > 0.5:
				ok_sum = false
			var de := MatchSim.disposal_efficiency(t)
			if de < 50 or de >= 100:
				ok_bounds = false
	_check(ok_sum, "Players' metres and effective disposals add up to the team's")
	_check(ok_bounds, "No negative metres, never more effective disposals than disposals")
	_check(fwd[0] / fwd[1] < dfn[0] / dfn[1],
			"Forwards, whose entries get rebounded, are less efficient than defenders (%.0f%% v %.0f%%)" % [
			100.0 * fwd[0] / fwd[1], 100.0 * dfn[0] / dfn[1]])
	_check(MatchSim.disposal_efficiency({"disposals": 20.0, "effective_disposals": 15.0}) == 75
			and MatchSim.disposal_efficiency({}) == 0, "Disposal efficiency is effective over total")


## The ruck contest is decided by, and credited to, the player actually at
## the bounce. With the ruck resting, the ruckman on the ground goes up, not
## whoever came off the bench, and an empty ruck spot is filled by the best
## ruckman available, not the best player.
func _test_ruck_integrity() -> void:
	var sim := _sim(77)
	var sq: Squad = sim.squads[0]
	var gi := -1
	for i in range(sq.ground.size()):
		if str(sq.ground[i]["role"]) == "RUCK":
			gi = i
	_check(gi >= 0, "The side starts with a ruck")
	var ruckman: Dictionary = sq.ground[gi]
	# A ruck-forward on the ground, and a bench player who is no ruckman.
	var fj := -1
	for i in range(sq.ground.size()):
		if str(sq.ground[i]["role"]) == "FWD":
			fj = i
			break
	sq.ground[fj]["role2"] = "RUCK"
	sq.ground[fj]["attr"]["ruck"] = 70
	var bj := -1
	for i in range(sq.bench.size()):
		if not Ratings.plays_role(sq.bench[i], "RUCK"):
			bj = i
			break
	var backup_id := str(sq.ground[fj]["id"])
	var bench_id := str(sq.bench[bj]["id"])
	sim._swap(0, gi, bj)
	_check(str(sq.ground[gi]["id"]) == bench_id, "The rested ruck's spot goes to the player off the bench")
	_check(str(sim._contestant(sq)[0]["id"]) == backup_id and MatchSim._ruck_of(sim._contestant(sq)) == 70.0,
			"...but the ruck-forward goes up at the bounce, and the contest is decided on him")
	for i in range(60):
		sim._stoppage(0, 1, true)
	var st: Dictionary = sim.player_stats
	_check(float(st.get(backup_id, {}).get("hitouts", 0.0)) > 0.0
			and float(st.get(str(ruckman["id"]), {}).get("hitouts", 0.0)) == 0.0,
			"Hit-outs go to the player who took them, not the rested ruck")
	# No ruck on the list at all: the best ruckman available goes up.
	var list: Array = []
	for p in GameDB.club_list("GEE"):
		if not Ratings.plays_role(p, "RUCK"):
			list.append(p)
	var side := Ratings.select_22(list)
	var in_ruck = null
	for g in side["ground"]:
		if str(g["role"]) == "RUCK":
			in_ruck = g
	var best_ruck := 0.0
	for p in list:
		best_ruck = maxf(best_ruck, float(p["attr"]["ruck"]))
	_check(in_ruck != null and float(in_ruck["attr"]["ruck"]) == best_ruck,
			"With no ruckman listed, the best tap man goes into the ruck")
	# Over whole matches, hit-outs go to ruckmen (before: half of them did not).
	var tot := 0.0
	var off := 0.0
	for i in range(30):
		var res := _sim(1200 + i).run()
		for sd in range(2):
			for r in res["roster"][sd]:
				var h := float(res["players"].get(str(r["id"]), {}).get("hitouts", 0.0))
				var p = GameDB.player_by_id(str(r["id"]))
				tot += h
				if not Ratings.plays_role(p, "RUCK") and float(p["attr"]["ruck"]) < 50.0:
					off += h
	_check(off / tot < 0.15, "Hit-outs mostly go to ruckmen (%.0f%% to others)" % (100.0 * off / tot))


## Play through a midfielder: he wins more of the ball in the chain, but the
## call does not turn him into the side's shooter.
func _test_play_through() -> void:
	var probe := _sim(60)
	var mid: Dictionary = {}
	for p in probe.squads[0].ground:
		if str(p["role"]) == "MID":
			mid = p
			break
	var plain := probe._tactic_player_mult(0, mid, "shooter")
	var plain_carry := probe._tactic_player_mult(0, mid, "carrier")
	probe.set_tactics(0, {"focus_id": str(mid["id"])})
	_check(probe._tactic_player_mult(0, mid, "shooter") == plain,
			"Play through does not favour him for the shot")
	_check(probe._tactic_player_mult(0, mid, "carrier") > plain_carry,
			"Play through favours him in the chain")
	var d_on := 0.0
	var d_off := 0.0
	var g_on := 0.0
	var g_off := 0.0
	var n := 30
	for i in range(n):
		var on := _sim(700 + i)
		on.set_tactics(0, {"focus_id": str(mid["id"])})
		var r_on := on.run()
		var r_off := _sim(700 + i).run()
		var s_on: Dictionary = r_on["players"].get(str(mid["id"]), {})
		var s_off: Dictionary = r_off["players"].get(str(mid["id"]), {})
		d_on += float(s_on.get("disposals", 0.0))
		d_off += float(s_off.get("disposals", 0.0))
		g_on += float(s_on.get("goals", 0.0))
		g_off += float(s_off.get("goals", 0.0))
	_check(d_on > d_off, "Played through, he gets more of the ball (%.1f v %.1f a game)" % [d_on / n, d_off / n])
	_check(d_on / n < 40.0, "...but not an absurd share (%.1f a game)" % (d_on / n))
	_check(g_on / n <= g_off / n + 0.35,
			"...and he does not become the goalkicker (%.2f v %.2f goals a game)" % [g_on / n, g_off / n])



## ARD-M1-001 stat credits: a goal assist only when a goal is kicked (never
## the goalkicker himself), and every free kick paid to a player.
func _test_stat_credits() -> void:
	var goals := 0.0
	var assists := 0.0
	var i50 := 0.0
	var sums_ok := true
	var frees_ok := true
	var self_assist := false
	for i in range(20):
		var res := _sim(1200 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			goals += float(t.get("goals", 0.0))
			assists += float(t.get("goal_assists", 0.0))
			i50 += float(t.get("inside50", 0.0))
			var pa := 0.0
			var pf := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				pa += float(st.get("goal_assists", 0.0))
				pf += float(st.get("frees_for", 0.0))
			if absf(pa - float(t.get("goal_assists", 0.0))) > 0.01:
				sums_ok = false
			if absf(pf - float(t.get("frees_for", 0.0))) > 0.01:
				frees_ok = false
	_check(assists > 0.4 * goals and assists < goals and assists < 0.5 * i50,
			"Goal assists are credited on goals, not on every entry (%d assists, %d goals, %d inside 50s)" % [assists, goals, i50])
	_check(sums_ok, "Players' goal assists add up to the team's")
	_check(frees_ok, "Every free kick is paid to a player: players' frees for add up to the team's")


## M2 stats: centre bounce attendances, intercepts, contested marks, score
## involvements and score sources all reconcile with the team numbers.
func _test_m2_stats() -> void:
	var cba_ok := true
	var sums_ok := true
	var sources_ok := true
	var involved_ok := true
	var marks_ok := true
	var cbs := 0.0
	for i in range(12):
		var res := _sim(1400 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			var cb := float(t.get("centre_bounces", 0.0))
			cbs += cb
			var src := 0.0
			for k in t:
				if str(k).begins_with("score_from_"):
					src += float(t[k])
			if absf(src - (6.0 * float(t.get("goals", 0.0)) + float(t.get("behinds", 0.0)))) > 0.01:
				sources_ok = false
			var cba := 0.0
			var ints := 0.0
			var cm := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				cba += float(st.get("cba", 0.0))
				ints += float(st.get("intercepts", 0.0))
				cm += float(st.get("contested_marks", 0.0))
				if float(st.get("contested_marks", 0.0)) > float(st.get("marks", 0.0)):
					marks_ok = false
				if float(st.get("score_involvements", 0.0)) < float(st.get("goals", 0.0)) + float(st.get("behinds", 0.0)):
					involved_ok = false
			if cba > 4.0 * cb + 0.01 or cba < 2.0 * cb:
				cba_ok = false
			if absf(ints - float(t.get("intercepts", 0.0))) > 0.01 or absf(cm - float(t.get("contested_marks", 0.0))) > 0.01:
				sums_ok = false
	_check(cbs > 0.0 and cba_ok, "A ruck and up to three midfielders attend each centre bounce")
	_check(sums_ok, "Players' intercepts and contested marks add up to the team's")
	_check(marks_ok, "A contested mark is always a mark")
	_check(sources_ok, "Every point scored has a source: score sources add up to the score")
	_check(involved_ok, "Every scorer is involved in his own scores")


## ARD-M1-001: no ordinary play is impossible for a line. Across matches a
## defender carries it inside 50 and kicks a goal, a ruck kicks goals and
## spoils, forwards and defenders win the odd clearance, mids and forwards
## take one-percenters - while each line still leans where it belongs.
func _test_no_role_gates() -> void:
	var by := {}
	for i in range(30):
		var res := _sim(1500 + i).run()
		for side in range(2):
			for r in res["roster"][side]:
				var role := str(r.get("list_role", r["role"]))
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				if not by.has(role):
					by[role] = {}
				for k in ["inside50", "goals", "one_percenters", "clearances"]:
					by[role][k] = float(by[role].get(k, 0.0)) + float(st.get(k, 0.0))
	var g := func(role: String, k: String) -> float: return float((by.get(role, {}) as Dictionary).get(k, 0.0))
	_check(g.call("DEF", "inside50") > 0.0 and g.call("DEF", "goals") > 0.0, "Defenders carry it inside 50 and kick the odd goal")
	_check(g.call("RUCK", "goals") > 0.0 and g.call("RUCK", "one_percenters") > 0.0, "Rucks kick goals and spoil")
	_check(g.call("FWD", "clearances") > 0.0 and g.call("DEF", "clearances") > 0.0, "Forwards and defenders win the odd clearance")
	_check(g.call("MID", "one_percenters") > 0.0 and g.call("FWD", "one_percenters") > 0.0, "Mids and forwards take one-percenters")
	_check(g.call("DEF", "one_percenters") > g.call("MID", "one_percenters") and g.call("FWD", "goals") > g.call("DEF", "goals") * 5.0
			and g.call("MID", "clearances") > g.call("FWD", "clearances") * 3.0, "Each line still leans where it belongs")


## ARD-M3-003: a spoil is credited to the defender who made it, and the
## ball it knocks loose inside 50 is sometimes crumbed and snapped - mostly
## by forwards - rather than always going back to the defence.
func _test_spoils_and_crumbs() -> void:
	var sums_ok := true
	var spoils := 0.0
	var crumbs := 0
	var crumbs_fwd := 0
	var by_def := 0.0
	for i in range(30):
		var res := _sim(1600 + i).run()
		for side in range(2):
			var team_sp := float((res["team"][side] as Dictionary).get("spoils", 0.0))
			spoils += team_sp
			var ps := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				ps += float(st.get("spoils", 0.0))
				if str(r["role"]) == "DEF":
					by_def += float(st.get("spoils", 0.0))
			if absf(ps - team_sp) > 0.01:
				sums_ok = false
		var role := {}
		for side in range(2):
			for r in res["roster"][side]:
				role[str(r["id"])] = str(r["role"])
		for e in res["events"]:
			if str(e.get("kind", "")) == "goal" and bool(e.get("crumb", false)):
				crumbs += 1
				if str(role.get(str(e.get("player_id", "")), "")) == "FWD":
					crumbs_fwd += 1
	_check(sums_ok and spoils > 0.0, "Spoils are credited, and players' spoils add up to the team's")
	_check(by_def >= 0.7 * spoils, "Spoils are made by defenders (rotations aside) (%d of %d)" % [by_def, spoils])
	_check(crumbs > 0 and float(crumbs_fwd) >= 0.55 * float(crumbs),
			"Goals are crumbed off spoils, mostly by forwards (%d of %d)" % [crumbs_fwd, crumbs])
