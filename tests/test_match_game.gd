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
	_test_hot_player_moment()
	_test_matchups()
	_test_in_match_injuries()
	_test_run_call_once_a_run()
	_test_late_bounce_reachable()
	_test_current_club_identity()
	_test_tag_ends_with_injury()
	_test_match_story()
	_test_traits_surfaced()
	_test_momentum()
	_test_moment_calls_matter()
	_test_tag_tradeoff()
	_test_through_stars()
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
					var worded := opts.size() >= 2
					for o in opts:
						var d := str(o["detail"])
						worded = worded and d != "" and not d.contains("%")
					var t := str(m["text"])
					for ch in t:
						if ch >= "0" and ch <= "9":
							worded = false
					_check(worded, "A set shot offers choices described in words, not odds: %s / %s" % [t, str(opts[0]["detail"])])
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
	var their_tagger = MatchSim.tagger_for((live.squads[1] as Squad).ground)
	if their_tagger != null and Roles.is_tagger(their_tagger):
		_check(tagged != "" and tagged_mid, "After half time the rival coach tags one of your midfielders with its tagger")
	else:
		_check(tagged == "", "Without a specialist tagger the rival coach does not waste a good midfielder on a tag")
	# The same rule both ways: a side with a tagger tags, one without does not.
	var with_tagger := ""
	var without := ""
	for code in GameDB.active_clubs(2027):
		var t = MatchSim.tagger_for(Squad.new(code, GameDB.club_list(code), false, code).ground)
		if t != null and Roles.is_tagger(t):
			with_tagger = code if with_tagger == "" else with_tagger
		elif without == "":
			without = code
	for pair in [[with_tagger, true], [without, false]]:
		if str(pair[0]) == "":
			_check(false, "The league has clubs with and without a specialist tagger")
			continue
		var s2 := _sim(903, "GEE" if str(pair[0]) != "GEE" else "COL", str(pair[0]))
		for q in range(3):
			s2.run_quarter()
		# Who is on the ground now: rotations can take the tagger off.
		var now_t = MatchSim.tagger_for((s2.squads[1] as Squad).ground)
		var has_now: bool = now_t != null and Roles.is_tagger(now_t)
		_check((str(s2.ai_tactics(1).get("tag_id", "")) != "") == has_now,
				"%s %s a tag in the second half" % [str(pair[0]), "calls" if has_now else "does not call"])
	# A tired star: under Normal rotations the rotations handle him, with no
	# call; riding the stars brings one call a match, and resting him works.
	for policy in ["normal", "stars"]:
		var tired := _sim(902)
		tired.moment_side = 0
		tired.set_rotation_policy(0, policy)
		var star: Dictionary = {}
		for p in tired.squads[0].ground:
			if int(p["overall"]) >= MatchSim.STAR_OVR:
				star = p
		if star.is_empty():
			_check(false, "Club 902 fields a star")
			continue
		tired.begin_quarter()
		tired.energy[str(star["id"])] = 40.0      # after the break's recovery
		var calls := 0
		var guard := 0
		while guard < 40:
			tired.continue_quarter()
			var m := tired.pending_moment
			if m.is_empty():
				break
			if str(m.get("kind", "")) == "tired":
				calls += 1
				if calls == 1:
					tired.resolve_moment(0)
					var still_on := false
					for p in tired.squads[0].ground:
						if str(p["id"]) == str(star["id"]):
							still_on = true
					_check(not still_on, "Resting him takes him off the ground")
					# Cooked again later: still only the one call.
					for p in tired.squads[0].ground:
						if int(p["overall"]) >= MatchSim.STAR_OVR:
							tired.energy[str(p["id"])] = 30.0
					continue
			tired.resolve_moment(int(m.get("default", 0)))
			guard += 1
		if policy == "normal":
			var subbed := false
			for ev in tired.events:
				if str(ev["kind"]) == "sub" and int(ev["side"]) == 0 and int(ev.get("off_num", -1)) == int(star["num"]):
					subbed = true
			_check(calls == 0, "Normal rotations: no running-on-empty call")
			_check(subbed, "Normal rotations take the cooked star off by themselves")
		else:
			_check(calls == 1, "Riding the stars: one tired call a match, not one a quarter (%d)" % calls)


## Calm the group is a live option: a milder, quarter-long Slow it down,
## distinct from Fire them up and from the default Stay composed.
func _test_pep_talks() -> void:
	var sim := _sim(55)
	sim.set_tactics(0, {"pep": "calm"})
	sim.set_tactics(1, {"pep": "fire_up"})
	_check(sim._pep_mult(0, "clangers") < 1.0 and sim._pep_mult(0, "taken") < 1.0
			and sim._pep_mult(0, "gain") < 1.0 and sim._pep_mult(0, "pace") < 1.0,
			"Calm the group cuts clangers, pressure felt and running, for less ground gained")
	_check(sim._contest_pep(0) == 0.0 and sim._pep_mult(1, "taken") == 1.0
			and sim._pep_mult(1, "clangers") > 1.0 and sim._pep_mult(1, "pace") > 1.0,
			"Calm the group and Fire them up do different things: fired up, tempers fray and legs go quicker")
	# Fire them up lifts a side only while it is chasing the game; the costs stay.
	_check(sim._contest_pep(1) == 0.0, "Level on the scoreboard, a fired-up side gets no lift at the contest")
	(sim.team_stats[0] as Dictionary)["goals"] = 2.0
	_check(sim._contest_pep(1) > 0.0, "Two goals down, it does")
	(sim.team_stats[0] as Dictionary)["goals"] = 0.0
	(sim.team_stats[1] as Dictionary)["goals"] = 2.0
	_check(sim._contest_pep(1) == 0.0 and sim._pep_mult(1, "clangers") > 1.0,
			"In front, the lift is gone but the costs are not")
	(sim.team_stats[1] as Dictionary)["goals"] = 0.0
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
	# 60 matches: crumbed goals are rare (about one a match), and a 30-match
	# sample swings a few points either side of the forwards' 58% share.
	for i in range(60):
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


## A tag is a midfield job: a forward kicking a bag never gets a tag card
## (that would be a choice with no effect); a midfielder does, and the card
## names the midfielder who would go to him.
func _test_hot_player_moment() -> void:
	var sim := _sim(77)
	sim.moment_side = 0
	sim.current_quarter = 2
	sim._chain_no = 100
	var fwd: Dictionary = {}
	var mid: Dictionary = {}
	for p in (sim.squads[1] as Squad).ground:
		if str(p["role"]) == "FWD" and fwd.is_empty():
			fwd = p
		if str(p["role"]) == "MID" and mid.is_empty():
			mid = p
	sim.player_stats[str(fwd["id"])] = {"goals": 4.0}
	sim._boundary_moment()
	_check(sim.pending_moment.is_empty() or str(sim.pending_moment.get("kind", "")) != "hot",
			"A forward kicking a bag is never answered with a tag")
	sim.pending_moment = {}
	sim._chain_no = 200
	sim.player_stats[str(mid["id"])] = {"goals": 3.0}
	sim._boundary_moment()
	var m: Dictionary = sim.pending_moment
	var tagger = MatchSim.tagger_for((sim.squads[0] as Squad).ground)
	_check(str(m.get("kind", "")) == "hot" and tagger != null
			and str(m["options"][0]["label"]).contains(GameDB.player_display_name(tagger)),
			"A midfielder kicking a bag can be tagged, by the midfielder who would go to him")


## Gate 1.12: key forward v key defender. Every link: a default set-up, a
## controllable assignment, contests fought against the named defender, a
## measurable effect, the forward's card answered with a defender (never a
## tag), and full-time lines that say only what the contests show.
func _test_matchups() -> void:
	var sim := _sim(501, "ADE", "SYD")
	var theirs: Dictionary = sim.duels[1]      # SYD's defenders on ADE's key forwards
	_check(not theirs.is_empty() and not (sim.duels[0] as Dictionary).is_empty(),
			"Both sides start with a defender on the other's key forwards")
	var fid := str(theirs.keys()[0])
	var defs := Matchups.defenders((sim.squads[1] as Squad).ground)
	var other := ""
	for p in defs:
		if str(p["id"]) != str(theirs[fid]):
			other = str(p["id"])
			break
	var had := str(theirs[fid])
	_check(sim.set_matchup(1, fid, other, false) and str(sim.duels[1][fid]) == other,
			"A defender can be put on a key forward")
	var swapped := true
	for k in theirs:
		if str(k) != fid and str(theirs[k]) == other:
			swapped = false
	_check(swapped, "A defender is only ever on one forward (the old job is swapped, %s)" % had)
	_check(not sim.set_matchup(1, fid, "NOPE", false), "An unknown defender is refused")
	var res := sim.run()
	var log: Dictionary = res["duels"].get(fid, {})
	var against_other := true
	for c in log.get("contests", []):
		if str(c[1]) != other:
			against_other = false
	_check(not log.is_empty() and against_other,
			"Every contest the forward played was against the defender put on him (%d)" % (log.get("contests", []) as Array).size())
	var tagged_events := 0
	for ev in res["events"]:
		if ev.has("duel"):
			tagged_events += 1
	_check(tagged_events > 0, "The contests reach the match log for the feed (%d)" % tagged_events)
	# Leverage: the same forward on a strong v a small, poor-in-the-air defender.
	var rates := []
	for want_strong in [true, false]:
		var n := 0
		var won := 0
		for seed in range(600, 630):
			var m := _sim(seed, "ADE", "SYD")
			var ds := Matchups.defenders((m.squads[1] as Squad).ground)
			ds.sort_custom(func(a, b): return Matchups.defender_air(a) > Matchups.defender_air(b))
			var f := str((m.duels[1] as Dictionary).keys()[0])
			m.set_matchup(1, f, str((ds[0] if want_strong else ds[ds.size() - 1])["id"]), false)
			for c in (m.run()["duels"].get(f, {}) as Dictionary).get("contests", []):
				n += 1
				if bool(c[2]):
					won += 1
		rates.append(float(won) / float(maxi(1, n)))
	_check(rates[1] - rates[0] >= 0.12 and rates[0] >= 0.35,
			"The defender on him changes the contests, but never shuts him out (%.2f strong v %.2f small)" % [rates[0], rates[1]])
	# The forward's card: a defender, never a tag.
	var live := _sim(88, "SYD", "ADE")
	live.moment_side = 0
	live.current_quarter = 2
	live._chain_no = 100
	var hot := str((live.duels[0] as Dictionary).keys()[0])
	live.player_stats[hot] = {"goals": 3.0}
	live._boundary_moment()
	var m2: Dictionary = live.pending_moment
	var has_tag := false
	for o in m2.get("options", []):
		if str(o["key"]) == "tag":
			has_tag = true
	_check(str(m2.get("kind", "")) == "duel" and not has_tag and str(m2["options"][0]["key"]).begins_with("def:"),
			"A forward kicking a bag is answered with a defender, never a tag")
	live.resolve_moment(0)
	_check(str(live.duels[0][hot]) == str(m2["options"][0]["key"]).trim_prefix("def:")
			and not live.duel_changes.is_empty(), "Choosing a defender puts him on the forward, from now")
	# Full time says only what the contests show.
	var fake := {"duels": {"F": {"side": 1, "contests": [
			[1, "A", true, true], [1, "A", true, false], [1, "A", true, true], [2, "A", true, false],
			[3, "B", false, false], [3, "B", false, false], [3, "B", true, false], [4, "B", false, false]]}}}
	var story := MatchNotes.duel_story(fake, 0)
	_check(story.size() == 1 and str(story[0]).contains("had the better of") and str(story[0]).contains("held him once he took over"),
			"A change that swung the contests is told in order: on top early, held after (%s)" % str(story))
	# A side's move onto him is called a move; a rotation is not.
	fake["duel_changes"] = [{"q": 3, "from": 3, "side": 0, "fwd": "F", "def": "B"}]
	story = MatchNotes.duel_story(fake, 0)
	_check(str(story[0]).contains("held him after the move") and not str(story[0]).contains("turned"),
			"A real move is named as the move, and the early part is kept (%s)" % str(story))
	# One man all day, on top of him in one quarter (the live call), held
	# overall: full time keeps both halves instead of contradicting the call.
	var one := {"duels": {"F": {"side": 1, "contests": [
			[1, "A", false, false], [1, "A", false, false], [1, "A", false, false],
			[2, "A", true, false], [2, "A", true, true], [2, "A", true, false],
			[3, "A", false, false], [3, "A", false, false], [4, "A", false, false], [4, "A", false, false]]}}}
	var s1 := str(MatchNotes.duel_story(one, 0)[0])
	_check(s1.contains("got on top of") and s1.contains("the second") and s1.contains("held him over the match"),
			"On top in one quarter, held overall: both halves at full time (%s)" % s1)
	var thin := {"duels": {"F": {"side": 1, "contests": [[1, "A", true, false], [1, "A", true, false],
			[1, "A", true, false], [2, "B", false, false]]}}}
	_check(str(MatchNotes.duel_story(thin, 0)[0]).contains("too few"),
			"Too few contests after a change is said as such, not dressed up")


## Injuries happen during the match: the player goes off for good, the bench
## covers him, and the list records the same injury afterwards.
## A player's club in a match is the side he plays for today, never the
## source club still on his record (a league re-draft, a trade): no club
## that is not playing can appear beside a name in the feed or box score.
func _test_current_club_identity() -> void:
	var moved := []
	for p in GameDB.club_list("MEL"):
		var q: Dictionary = p.duplicate(true)
		q["club"] = "WBD"
		moved.append(q)
	var stray := []
	var injuries := 0
	for i in range(12):
		var sim := MatchSim.new(Squad.new("MEL", moved, true, "MEL"),
				Squad.new("CAR", GameDB.club_list("CAR"), false, "CAR"), 3300 + i)
		var res := sim.run()
		for ev in res["events"]:
			var c := str(ev.get("club", ""))
			if c != "" and c != ["MEL", "CAR"][int(ev.get("side", 0))] and not ["MEL", "CAR"].has(c):
				stray.append("%s %s" % [str(ev["kind"]), c])
			if str(ev["kind"]) == "injury":
				injuries += 1
		for side in range(2):
			for r in res["roster"][side]:
				if str(r["club"]) != ["MEL", "CAR"][side]:
					stray.append("roster " + str(r["club"]))
	_check(stray.is_empty(), "Every name in the match carries the club he plays for today (%s)" % str(stray.slice(0, 3)))
	_check(injuries > 0, "The sample includes injuries, whose lines once named a stale club")
	var line := MatchNotes.story_feed_line({}, {"kind": "injury", "name": "Tim English", "club": "MEL", "on": ""})
	_check(line.contains("(%s)" % GameDB.club_short("MEL")), "The injury line reads the match club (%s)" % line)


## A tagged player hurt and gone off takes the tag with him: the tagging side
## keeps no hidden tag, and he cannot be tagged again.
func _test_tag_ends_with_injury() -> void:
	var sim := _sim(3200, "MEL", "CAR")
	sim.moment_side = 0
	var target: Dictionary = {}
	for p in (sim.squads[1] as Squad).ground:
		if MatchSim.taggable(p):
			target = p
			break
	var id := str(target["id"])
	sim.set_tactics(0, {"gameplan": "balanced", "tag_id": id})
	_check(str(sim.tactics[0].get("tag_id", "")) == id, "A tag goes on a midfielder in the match")
	sim._injury_plan = [{"side": 1, "id": id, "at": 3, "weeks": 2, "kind": "hamstring"}]
	sim.begin_quarter()
	var guard := 0
	while guard < 30:
		sim.continue_quarter()
		if sim.pending_moment.is_empty():
			break
		sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		guard += 1
	_check(not sim.taking_part(1, id), "He goes off hurt and takes no further part")
	_check(str(sim.tactics[0].get("tag_id", "")) == "", "The tag on him ends when he goes off")
	sim.set_tactics(0, {"gameplan": "balanced", "tag_id": id})
	_check(str(sim.tactics[0].get("tag_id", "")) == "", "He cannot be tagged at the next break")


## A run of goals against brings one call a run, not one a goal: the fourth
## and fifth goals of the same run ask nothing new; a new run can.
func _test_run_call_once_a_run() -> void:
	var sim := _sim(4500, "MEL", "CAR")
	sim.moment_side = 0
	sim.current_quarter = 2
	var ready := func() -> void:
		sim.pending_moment = {}
		sim._moments_this_q = 0
		sim._last_moment_chain = sim._chain_no - 100
	var calls := 0
	# Their goals 3, 4, 5 in a row: one run.
	for g in [3, 4, 5]:
		ready.call()
		(sim.team_stats[1] as Dictionary)["goals"] = float(g)
		sim._run = [0, g]
		if sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "momentum":
			calls += 1
	_check(calls == 1, "Three, four, five in a row: one call for the run (%d)" % calls)
	# You kick one; then they kick three more: a new run, a new call.
	ready.call()
	(sim.team_stats[1] as Dictionary)["goals"] = 8.0
	sim._run = [0, 3]
	_check(sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "momentum",
			"A new run after you score can bring the call again")


## A tight finish gets the centre-bounce call even when the last quarter's
## two calls went early: one more is kept for it, and only for it.
func _test_late_bounce_reachable() -> void:
	var sim := _sim(4400, "MEL", "CAR")
	sim.moment_side = 0
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim._chain_no = 200
	sim._last_moment_chain = 150
	sim._moments_this_q = MatchSim.MAX_MOMENTS_Q
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 10.0
	_check(sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "bounce",
			"Q4's calls spent, a tight centre bounce still brings the call")
	sim.pending_moment = {}
	_check(not sim._boundary_moment(), "...once: the kept call is not a third")
	sim._moments_this_q = MatchSim.MAX_MOMENTS_Q
	sim._asked.erase("bounce")
	sim.at_centre = false
	_check(not sim._boundary_moment(), "The kept call is only for a centre bounce")
	sim.at_centre = true
	sim.current_quarter = 3
	_check(not sim._boundary_moment(), "...and only in the last quarter")


func _test_in_match_injuries() -> void:
	var n := 0
	var hurt := 0
	var sound := true
	var covered := true
	var duels_ok := true
	var sample := {}
	for i in range(40):
		var sim := _sim(3100 + i, "MEL", "CAR")
		var res := sim.run()
		n += 1
		for inj in res["injuries"]:
			hurt += 1
			var side := int(inj["side"])
			var id := str(inj["id"])
			for p in (sim.squads[side] as Squad).ground + (sim.squads[side] as Squad).bench:
				if str(p["id"]) == id:
					sound = false
			var in_roster := false
			for r in res["roster"][side]:
				if str(r["id"]) == id:
					in_roster = true
			var ev_ok := false
			for ev in res["events"]:
				if str(ev["kind"]) == "injury" and str(ev["player_id"]) == id and str(ev.get("on", "")) == str(inj["on"]):
					ev_ok = true
			covered = covered and in_roster and ev_ok
			if sample.is_empty():
				sample = {"res": res, "inj": inj}
		# Nobody gone off hurt is left in a match-up (a break would offer a
		# change the engine cannot make).
		for side in range(2):
			var here := {}
			for p in (sim.squads[side] as Squad).ground + (sim.squads[side] as Squad).bench:
				here[str(p["id"])] = true
			var there := {}
			for p in (sim.squads[1 - side] as Squad).ground + (sim.squads[1 - side] as Squad).bench:
				there[str(p["id"])] = true
			for fid in (sim.duels[side] as Dictionary):
				if not there.has(str(fid)) or not here.has(str(sim.duels[side][fid])):
					duels_ok = false
	var rate := float(hurt) / (2.0 * n)
	_check(rate > 0.4 and rate < 1.1, "In-match injuries run near the old rate (%.2f a side a match)" % rate)
	_check(sound, "A player hurt in a match takes no further part")
	_check(covered, "Each injury is in the log and the injured player is in the box score")
	_check(duels_ok, "A player gone off hurt is out of the match-ups")
	if not sample.is_empty():
		var res: Dictionary = sample["res"]
		var inj: Dictionary = sample["inj"]
		var code: String = [str(res["home"]), str(res["away"])][int(inj["side"])]
		var lists := {code: GameDB.club_list(code).duplicate(true)}
		var applied := Injuries.apply_match(res, lists, 1, 1)
		var p: Dictionary = {}
		for q in lists[code]:
			if str(q["id"]) == str(inj["id"]):
				p = q
		_check(not applied.is_empty() and int(p.get("injury_weeks", 0)) == int(inj["weeks"]),
				"The list records the injury the match had")


## The feed and full time tell the match's turning points from the log.
func _test_match_story() -> void:
	var mem := {}
	var inj := MatchNotes.story_feed_line(mem, {"kind": "injury", "q": 2, "min": 40,
			"name": "Ed Richards", "club": "WBD", "on": ""})
	_check(inj.begins_with("Ed Richards") and inj.contains("won't return"), "An injury always reaches the feed: " + inj)
	var intercepts := 0
	for m in range(5):
		var ev := {"kind": "goal", "q": 1, "min": 5 + m, "side": 0, "player_id": "a", "from_id": "b",
				"score": [6 * (m + 1), 6 * (m + 1)]}
		if MatchNotes.story_feed_line(mem, ev) != "":
			intercepts += 1
	_check(intercepts == 1, "At most one intercept line a quarter (%d)" % intercepts)
	var ahead := MatchNotes.story_feed_line({}, {"kind": "goal", "q": 2, "min": 40, "side": 0,
			"player_id": "a", "from_id": "b", "score": [40, 20]})
	_check(ahead == "", "A goal from an intercept that changes nothing stays off the feed")
	var res := {"home": "MEL", "away": "CAR", "score": [80, 75], "roster": [[], []], "events": [
		{"kind": "goal", "q": 1, "min": 5, "side": 1, "name": "X", "score": [0, 6]},
		{"kind": "goal", "q": 4, "min": 112, "side": 0, "name": "Jack Viney", "score": [7, 6]},
	]}
	var tp := MatchNotes.turning_points(res, 1)
	_check(not tp.is_empty() and str(tp[0]) == "Jack Viney's goal 22 minutes into the last quarter put Melbourne in front for good.",
			"Full time names the score that put the winners in front for good: %s" % str(tp))
	var calm := MatchNotes.turning_points({"home": "MEL", "away": "CAR", "score": [80, 20], "events": [
		{"kind": "goal", "q": 1, "min": 3, "side": 0, "name": "A", "score": [6, 0]}]}, 0)
	_check(calm.is_empty(), "A match led from the first goal has no turning point to invent")


## Traits and synergies say when they were at work, from the log.
func _test_traits_surfaced() -> void:
	var crumbs := 0
	var tagged := true
	var big := 0
	for i in range(30):
		var res := _sim(4200 + i, "COL", "GEE").run()
		for ev in res["events"]:
			if str(ev["kind"]) != "goal" or not ev.has("trait"):
				continue
			if str(ev["trait"]) == "crumber":
				crumbs += 1
				tagged = tagged and bool(ev.get("crumb", false))
			elif str(ev["trait"]) == "big_game":
				big += 1
				tagged = tagged and int(ev["q"]) >= 4
	_check(crumbs + big > 0 and tagged, "A Crumber's crumb and a Big-game player's late goal are marked (%d, %d)" % [crumbs, big])
	var mem := {}
	var ev := {"kind": "goal", "q": 4, "min": 100, "side": 0, "name": "Jack Viney", "trait": "big_game",
			"score": [60, 50]}
	_check(MatchNotes.story_feed_line(mem, ev) == "Jack Viney lifts when it matters.", "A Big-game player's lift reaches the feed")
	_check(MatchNotes.story_feed_line(mem, ev) == "", "Once a match a side")
	var res := {"synergies": [["engine_room", "intercept_wall"], []], "goals": [12, 9],
			"team": [{"clearances": 40, "inside50": 55}, {"clearances": 33, "inside50": 48}]}
	var lines := MatchNotes.synergy_lines(res, 0)
	_check(lines.size() == 2 and str(lines[0]) == "Engine room: clearances 40 to 33."
			and str(lines[1]) == "Intercept wall: they kicked 9 goals from 48 inside 50s.",
			"Full time shows the stat each of your synergies plays on: %s" % str(lines))
	_check(MatchNotes.synergy_lines(res, 1).is_empty(), "No synergies, no lines")


## Momentum is real, small, capped, fading and reversible, and it does not
## snowball.
func _test_momentum() -> void:
	# Real: the side with the run of play wins more of the ball, by about
	# MOMENTUM_EDGE at full momentum.
	var sim := _sim(9100)
	var wins := [0, 0]
	for mode in range(2):
		sim.momentum = 1.0 if mode == 1 else 0.0
		sim.rng.seed = 424242
		for i in range(20000):
			if sim.contest_winner(false, 0.0) == 0:
				wins[mode] += 1
	var lift := float(wins[1] - wins[0]) / 20000.0
	_check(lift > 0.025 and lift < 0.055, "Full momentum wins about 4%% more of the ball (%.3f)" % lift)
	# Capped: a string of goals cannot push it past full.
	sim.momentum = 0.0
	for i in range(20):
		sim._swing_momentum(0, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum <= 1.0 and sim.momentum > 0.9, "A run of goals fills it but never past full (%.2f)" % sim.momentum)
	var edge_at_full: float = sim.momentum_edge * sim.momentum
	_check(edge_at_full <= MatchSim.MOMENTUM_EDGE, "The edge is capped at MOMENTUM_EDGE")
	# Reversible: the other side's goals turn it, faster than it built.
	sim.momentum = 0.8
	sim._swing_momentum(1, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum < 0.2, "One goal the other way arrests a strong run (%.2f)" % sim.momentum)
	sim._swing_momentum(1, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum < 0.0, "Two goals the other way turn it (%.2f)" % sim.momentum)
	# Fades: ten passages without a score take most of it away.
	sim.momentum = 0.8
	for i in range(10):
		sim._after_chain()
	_check(sim.momentum < 0.4 and sim.momentum > 0.0, "It fades within a few minutes of play (%.2f)" % sim.momentum)
	# Every event carries it for the meter.
	var res := _sim(9101).run()
	var carried := true
	var moved := false
	for ev in res["events"]:
		if str(ev["kind"]) == "goal":
			carried = carried and ev.has("mom")
			if absf(float(ev.get("mom", 0.0))) > 0.3:
				moved = true
	_check(carried and moved, "Goals carry the engine's momentum, and it moves")
	# No snowball: after a goal the same side kicks the next only slightly
	# more often than without momentum (measured 51% without, 52% with).
	var pairs := 0
	var same := 0
	for i in range(80):
		var r := _sim(9200 + i, ["GEE", "COL", "MEL", "SYD"][i % 4], ["CAR", "BRL", "ADE", "HAW"][i % 4]).run()
		var last := -1
		for ev in r["events"]:
			if str(ev["kind"]) != "goal":
				continue
			if last >= 0:
				pairs += 1
				if int(ev["side"]) == last:
					same += 1
			last = int(ev["side"])
	var share := float(same) / float(maxi(1, pairs))
	_check(share < 0.56, "Momentum does not snowball: the scorers kick the next goal %.0f%% of the time" % (100.0 * share))


## A moment card's call changes the football, and which call is right
## depends on the situation.
func _test_moment_calls_matter() -> void:
	# The calls last a passage of play and end at the break.
	var sim := _sim(8800)
	sim.moment_side = 0
	_check(int(MatchSim.BURSTS["surge"]["chains"]) >= 12 and int(MatchSim.BURSTS["hold"]["chains"]) >= 12,
			"'The next ten minutes' is a passage of play, not two minutes")
	sim.begin_quarter()
	(sim.bursts[0] as Dictionary)["surge"] = 15
	sim.run_quarter()
	_check((sim.bursts[0] as Dictionary).is_empty(), "A call ends at the break")
	# Throw numbers at it: more scoring at both ends. Slow it down: less.
	var totals := {"none": 0.0, "surge": 0.0, "hold": 0.0}
	for key in totals:
		for i in range(40):
			var s2 := _sim(8900 + i, ["GEE", "MEL", "SYD", "ADE"][i % 4], ["COL", "CAR", "BRL", "HAW"][i % 4])
			while s2.current_quarter <= 4:
				s2.begin_quarter()
				if key != "none":
					(s2.bursts[0] as Dictionary)[key] = 999
				s2.run_quarter()
			totals[key] += float(s2.score(0) + s2.score(1))
	_check(totals["surge"] > totals["none"] * 1.03 and totals["hold"] < totals["none"] * 0.97,
			"Throwing numbers at it opens the game up and slowing it down closes it (%.0f / %.0f / %.0f a match)" % [
			totals["surge"] / 40.0, totals["none"] / 40.0, totals["hold"] / 40.0])
	# Set shots: the best call depends on the shot.
	var best := {}
	for i in range(30):
		var s3 := _sim(9300 + i)
		s3.moment_side = 0
		while s3.current_quarter <= 4:
			s3.begin_quarter()
			while not s3.continue_quarter():
				var m := s3.pending_moment
				if str(m["kind"]) == "set_shot":
					var top := ""
					var top_ev := -1.0
					for o in m["options"]:
						var ev := 6.0 * float(o.get("goal", 0.0)) + float(o.get("behind", 0.0) if o.has("behind") else (1.0 - float(o.get("goal", 0.0))) * 0.3)
						if ev > top_ev:
							top_ev = ev
							top = str(o["key"])
					best[top] = int(best.get(top, 0)) + 1
				s3.resolve_moment(int(m.get("default", 0)))
			s3.end_quarter()
	_check(best.size() >= 2, "No set-shot call is always right: the best one changes with the shot (%s)" % str(best))


## A tag is a trade: it takes the target out of the midfield battle and costs
## you your tagger's own game. Worth it on their star with a specialist; a
## loss when a good midfielder has to do the job.
func _test_tag_tradeoff() -> void:
	var with_spec := ""
	var without := ""
	for code in GameDB.active_clubs(2027):
		var t = MatchSim.tagger_for(Squad.new(code, GameDB.club_list(code), true, code).ground)
		if t != null and Roles.is_tagger(t):
			with_spec = code if with_spec == "" else with_spec
		elif without == "":
			without = code
	_check(with_spec != "" and without != "", "Clubs with and without a specialist tagger (%s, %s)" % [with_spec, without])
	if with_spec == "" or without == "":
		return
	var opp := "SYD" if with_spec != "SYD" and without != "SYD" else "BRL"
	var mids := []
	for p in (_sim(5, with_spec, opp).squads[1] as Squad).ground:
		if str(p["role"]) == "MID":
			mids.append(p)
	mids.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	var star: Dictionary = mids[0]
	var plain: Dictionary = mids[mids.size() - 1]
	# The midfield battle, as the stoppages see it (positive: ours).
	var edge := func(code: String, target: Dictionary) -> float:
		var sim := _sim(5, code, opp)
		sim.set_tactics(0, {"tag_id": str(target["id"])})
		return sim._tag_drag(1) - sim._tag_drag(0)
	var spec_star: float = edge.call(with_spec, star)
	var spec_plain: float = edge.call(with_spec, plain)
	var mid_star: float = edge.call(without, star)
	var mid_plain: float = edge.call(without, plain)
	_check(spec_star > 0.0, "A specialist tagger on their best midfielder wins us the midfield battle (%+.2f)" % spec_star)
	_check(spec_star > 2.0 * spec_plain, "...by far more than the same tag on an ordinary one (%+.2f)" % spec_plain)
	_check(mid_plain < 0.0 and mid_star < spec_star,
			"Without a specialist, a good midfielder gives up his own game: a loss on an ordinary one (%+.2f), less on their star (%+.2f)" % [mid_plain, mid_star])
	# Over paired matches: the target sees less of the ball, and a good
	# midfielder sent to tag sees less of it too.
	var tagger: Dictionary = MatchSim.tagger_for((_sim(5, without, opp).squads[0] as Squad).ground)
	var t_on := 0.0
	var t_off := 0.0
	var g_on := 0.0
	var g_off := 0.0
	var n := 20
	for i in range(n):
		var on := _sim(900 + i, without, opp)
		on.set_tactics(0, {"tag_id": str(star["id"])})
		var r_on := on.run()
		var r_off := _sim(900 + i, without, opp).run()
		t_on += float((r_on["players"] as Dictionary).get(str(star["id"]), {}).get("disposals", 0.0))
		t_off += float((r_off["players"] as Dictionary).get(str(star["id"]), {}).get("disposals", 0.0))
		g_on += float((r_on["players"] as Dictionary).get(str(tagger["id"]), {}).get("disposals", 0.0))
		g_off += float((r_off["players"] as Dictionary).get(str(tagger["id"]), {}).get("disposals", 0.0))
	_check(t_on < t_off - 2.0 * n, "Tagged, their star sees much less of it (%.1f v %.1f a game)" % [t_on / n, t_off / n])
	_check(g_on < g_off - 1.0 * n, "...and so does the midfielder who tags him (%.1f v %.1f a game)" % [g_on / n, g_off / n])


## Through stars goes through the side's best three: they see more of the
## ball and kick more goals, and how much it gives follows how far they
## stand above the rest (PlanFit), not a fixed rating line.
func _test_through_stars() -> void:
	var probe := _sim(40)
	var stars: Array = (probe.stars[0] as Dictionary).keys()
	var best := PlanFit.carriers((probe.squads[0] as Squad).ground, "through_stars")
	_check(stars.size() == 3 and best.size() == 3 and stars.has(str(best[0]["id"])),
			"Through stars goes through the side's best three")
	var d_on := 0.0
	var d_off := 0.0
	var g_on := 0.0
	var g_off := 0.0
	var n := 20
	for i in range(n):
		var on := _sim(760 + i)
		on.set_tactics(0, {"gameplan": "through_stars"})
		var r_on := on.run()
		var r_off := _sim(760 + i).run()
		for id in stars:
			d_on += float((r_on["players"] as Dictionary).get(str(id), {}).get("disposals", 0.0))
			d_off += float((r_off["players"] as Dictionary).get(str(id), {}).get("disposals", 0.0))
			g_on += float((r_on["players"] as Dictionary).get(str(id), {}).get("goals", 0.0))
			g_off += float((r_off["players"] as Dictionary).get(str(id), {}).get("goals", 0.0))
	_check(d_on > d_off + 2.0 * n, "Through stars: the best three see more of the ball (%.1f v %.1f a game)" % [d_on / n, d_off / n])
	_check(g_on > g_off, "...and kick more goals (%.2f v %.2f a game)" % [g_on / n, g_off / n])
	# The further the best three stand above the rest, the more it gives.
	var rows := []
	for code in GameDB.active_clubs(2027):
		var g: Array = Squad.new(code, GameDB.club_list(code), false, code).ground
		rows.append([PlanFit.score(g, "through_stars"), PlanFit.fit(g, "through_stars")])
	rows.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var ordered := true
	for i in range(1, rows.size()):
		ordered = ordered and float(rows[i][1]) >= float(rows[i - 1][1])
	_check(ordered and float(rows[rows.size() - 1][1]) > 1.1 and float(rows[0][1]) < 0.9,
			"Through stars suits a side whose stars stand out (fit %.2f to %.2f)" % [float(rows[0][1]), float(rows[rows.size() - 1][1])])
