extends RefCounted
## Quarter swings (measurement only; no balance is changed).
## godot --headless --path . --script tools/audit/run_audit.gd -- swing_impl <mode> <seed0> <n> [pep]
## Modes:
##   ai     AI v AI over random pairings of the 18 real lists; one Q| line per quarter.
##   coach  your side (no AI plans, balanced, steady) v an AI club; Q1-Q3 played, then Q4 skipped
##          the way MatchScene._simulate_remaining does it. Optional pep = the pep talk called in Q3
##          (skip repeats it in Q4; the break box would reset it to steady).
##   skip   Part 1 pair: same seed and state at three-quarter time, Q4 (a) after the break with the
##          pep reset to steady (the box default) and (b) skipped with Q3's pep carried. Prints
##          one P| line per match.
##   steps  Part 1 identity: Q4 by begin/continue/end (the live path, default moment calls) against
##          run_quarter (the skip path); prints whether the final score and events match.
## Output columns for Q|: mode seed home away weather q hb ab hq aq hgq agq he ae mom inj_h inj_a ph pa
## (hb/ab = scores before the quarter; hq/aq = points scored in it; hgq/agq goals; he/ae = mean
## energy of the players on the ground at the bounce; mom = momentum at the bounce).

const WEATHERS := ["perfect", "perfect", "perfect", "perfect", "wet", "windy", "hot"]


func _squad(code: String, home: bool, ai: bool) -> Squad:
	var s := Squad.new(code, GameDB.club_list(code), home, code)
	s.ai_plans = ai
	s.assistant = not ai
	return s


func _mean_energy(sim: MatchSim, side: int) -> float:
	var sum := 0.0
	var n := 0
	for p in (sim.squads[side] as Squad).ground:
		sum += float(sim.energy.get(str(p["id"]), 100.0))
		n += 1
	return sum / maxf(1, n)


func _pair(rng: RandomNumberGenerator, codes: Array) -> Array:
	var a: int = rng.randi() % codes.size()
	var b: int = rng.randi() % (codes.size() - 1)
	if b >= a:
		b += 1
	return [codes[a], codes[b]]


func _quarter_line(tag: String, seed: int, sim: MatchSim, q: int, hb: int, ab: int,
		he: float, ae: float, mom: float, inj0: Array, ph: String, pa: String) -> String:
	var hq := sim.score(0) - hb
	var aq := sim.score(1) - ab
	var ih := 0
	var ia := 0
	for i in range(inj0[0], sim.injuries.size()):
		if int(sim.injuries[i]["side"]) == 0:
			ih += 1
		else:
			ia += 1
	return "Q|%s|%d|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%.1f|%.1f|%.2f|%d|%d|%s|%s" % [
			tag, seed, sim.squads[0].code, sim.squads[1].code, sim.weather, q, hb, ab, hq, aq,
			int(sim.q_goals[q - 1][0]), int(sim.q_goals[q - 1][1]), he, ae, mom, ih, ia, ph, pa]


func _kept(pep: String) -> Dictionary:
	return {"gameplan": "balanced", "pep": pep, "rotation": "normal"}


func _apply(sim: MatchSim, t: Dictionary) -> void:
	# MatchScene._apply_quarter_tactics, side 0 being the coach.
	sim.set_tactics(0, t)
	sim.set_rotation_policy(0, str(t.get("rotation", "normal")))
	sim.set_tactics(1, sim.ai_tactics(1))


func _make(h: String, a: String, seed: int, weather: String, coach: bool) -> MatchSim:
	var sim := MatchSim.new(_squad(h, true, not coach), _squad(a, false, true), seed)
	sim.weather = weather
	if coach:
		sim.moment_side = 0
		sim.set_tactics(0, {"gameplan": "balanced"})
	return sim


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1])
	var seed0 := int(args[2])
	var n := int(args[3])
	var pep := str(args[4]) if args.size() > 4 else "steady"
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed0 * 7919 + 13
	for i in range(n):
		var seed := seed0 * 100000 + i
		var pr := _pair(rng, codes)
		var weather: String = WEATHERS[rng.randi() % WEATHERS.size()]
		match mode:
			"ai":
				_run_ai(seed, pr, weather)
			"coach":
				_run_coach(seed, pr, weather, pep)
			"skip":
				_run_skip(seed, pr, weather, pep)
			"steps":
				_run_steps(seed, pr, weather)


func _run_ai(seed: int, pr: Array, weather: String) -> void:
	var sim := _make(pr[0], pr[1], seed, weather, false)
	for q in range(1, 5):
		var hb := sim.score(0)
		var ab := sim.score(1)
		var he := _mean_energy(sim, 0)
		var ae := _mean_energy(sim, 1)
		var mom := sim.momentum
		var inj0 := [sim.injuries.size()]
		sim.run_quarter()
		var plans: Array = (sim.tactics_history[q - 1]["plans"])
		print(_quarter_line("ai", seed, sim, q, hb, ab, he, ae, mom, inj0,
				str(plans[0].get("gameplan", "")) + "/" + str(plans[0].get("pep", "")),
				str(plans[1].get("gameplan", "")) + "/" + str(plans[1].get("pep", ""))))


func _run_coach(seed: int, pr: Array, weather: String, pep: String) -> void:
	var sim := _make(pr[0], pr[1], seed, weather, true)
	for q in range(1, 5):
		var t := _kept("steady")
		if q == 3 and false:
			t = _kept(pep)
		if q >= 3:
			t = _kept(pep)   # Q3 call; Q4 is the kept call (skip)
		_apply(sim, t)
		var hb := sim.score(0)
		var ab := sim.score(1)
		var he := _mean_energy(sim, 0)
		var ae := _mean_energy(sim, 1)
		var mom := sim.momentum
		var inj0 := [sim.injuries.size()]
		sim.run_quarter()
		var plans: Array = (sim.tactics_history[q - 1]["plans"])
		print(_quarter_line("coach", seed, sim, q, hb, ab, he, ae, mom, inj0,
				str(plans[0].get("gameplan", "")) + "/" + str(plans[0].get("pep", "")),
				str(plans[1].get("gameplan", "")) + "/" + str(plans[1].get("pep", ""))))


## Play Q1-Q3 the same way, then Q4 two ways. Needs the sim built twice (no clone), so Q1-Q3 are
## replayed from the same seed: the dice are the same, so the state at three-quarter time matches.
func _to_three_quarter(seed: int, pr: Array, weather: String, pep: String) -> MatchSim:
	var sim := _make(pr[0], pr[1], seed, weather, true)
	for q in range(1, 4):
		_apply(sim, _kept(pep if q == 3 else "steady"))
		sim.run_quarter()
	return sim


func _run_skip(seed: int, pr: Array, weather: String, pep: String) -> void:
	# (a) the break: the box resets the pep talk to steady, Start quarter.
	var a := _to_three_quarter(seed, pr, weather, pep)
	var a_h := a.score(0)
	var a_a := a.score(1)
	_apply(a, _kept("steady"))
	a.run_quarter()
	# (b) Skip to full time: _last_tactics (Q3's calls, pep included) apply to Q4.
	var b := _to_three_quarter(seed, pr, weather, pep)
	var b_h := b.score(0)
	var b_a := b.score(1)
	_apply(b, _kept(pep))
	b.run_quarter()
	print("P|%d|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d" % [seed, pr[0], pr[1], weather, pep,
			a_h, a_a, a.score(0) - a_h - (a.score(1) - a_a) if false else (a.score(0) - a_h) - (a.score(1) - a_a),
			(b.score(0) - b_h) - (b.score(1) - b_a), a_h - a_a, b_h - b_a])


func _run_steps(seed: int, pr: Array, weather: String) -> void:
	var a := _to_three_quarter(seed, pr, weather, "steady")
	_apply(a, _kept("steady"))
	a.begin_quarter()
	while not a.continue_quarter():
		a.resolve_moment(int(a.pending_moment.get("default", 0)))
	a.end_quarter()
	var b := _to_three_quarter(seed, pr, weather, "steady")
	_apply(b, _kept("steady"))
	b.run_quarter()
	var same := a.score(0) == b.score(0) and a.score(1) == b.score(1) and a.events.size() == b.events.size()
	print("S|%d|%s|%s|%s|%d-%d|%d-%d|%s" % [seed, pr[0], pr[1], weather, a.score(0), a.score(1), b.score(0), b.score(1), "SAME" if same else "DIFF"])
