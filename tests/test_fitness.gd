extends RefCounted
## Season conditioning: the curve each plan makes, what the department and a
## late change do to it, the stamps a match reads, AI plans by phase, and the
## save. Every season here is seeded.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2031


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	_test_curves()
	_test_department()
	_test_late_change()
	_test_stamps()
	_test_match_effect()
	_test_career()
	GameState.fitness_ai_by_phase = true
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Fitness tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _rec(plan: String, offset := 0) -> Dictionary:
	return {"year": 2026, "changes": [[0, plan]], "offset": offset}


func _peak_of(rec: Dictionary, level: int) -> Array:
	var best := -9.0
	var at := 0
	for w in range(Conditioning.LAST_WEEK + 1):
		var c := Conditioning.actual(rec, w, level)
		if c > best:
			best = c
			at = w
	return [best, at]


func _test_curves() -> void:
	var steady := _rec("steady")
	var flat := true
	for w in range(Conditioning.LAST_WEEK + 1):
		for level in range(4):
			flat = flat and Conditioning.actual(steady, w, level) == 0.0
		flat = flat and Conditioning.planned(steady, w) == 0.0
	_check(flat, "Steady all year is level every week, whatever the department")
	var peak := _rec("peak")
	_check(Conditioning.planned(peak, 5) < 0.0 and Conditioning.planned(peak, 10) < 0.0,
			"Peak for September is still building through the early rounds")
	var finals_top := true
	for w in range(Conditioning.FINALS_FIRST, Conditioning.LAST_WEEK + 1):
		finals_top = finals_top and Conditioning.planned(peak, w) == 1.0
	_check(finals_top, "Peak for September is planned to be at its best through every finals week")
	var fast := _rec("fast")
	_check(Conditioning.planned(fast, 3) == 1.0 and Conditioning.planned(fast, 18) < 0.0,
			"A fast start is at its best early and pays for it late")
	var dev := _rec("develop")
	_check(Conditioning.planned(dev, 0) < 0.0
			and Conditioning.planned(dev, 0) == Conditioning.planned(dev, 26),
			"Develop and manage runs a steady, managed load all year")
	_check(Conditioning.xp_mult("develop", {"age": 20}) > 1.0
			and Conditioning.xp_mult("develop", {"age": 27}) == 1.0
			and Conditioning.xp_mult("peak", {"age": 20}) == 1.0,
			"Develop and manage grows the young players only")
	_check(Conditioning.ai_plan("contending") == "peak" and Conditioning.ai_plan("rebuilding") == "develop"
			and Conditioning.ai_plan("building") == "steady",
			"AI clubs plan by where they are in their cycle")
	_check(Conditioning.revision_weeks(10) == [0, 10, 13, 20]
			and Conditioning.revision_weeks(13) == [0, 13, 20],
			"The plan can be revised in the pre-season, at the bye, at round 14 and in the last month")


func _test_department() -> void:
	var peak := _rec("peak")
	_check(float(_peak_of(peak, 3)[0]) > float(_peak_of(peak, 0)[0]),
			"An elite high-performance department peaks higher than a minimal one")
	var spread := [0.0, 0.0]
	for i in range(200):
		spread[0] += absf(float(Conditioning.timing_offset(2026 + i, "MEL", 0, 7)))
		spread[1] += absf(float(Conditioning.timing_offset(2026 + i, "MEL", 3, 7)))
	_check(spread[0] > spread[1] * 2.0,
			"A minimal department lands its peak early or late far more often than an elite one")
	var late := _rec("peak", 3)
	_check(int(_peak_of(late, 3)[1]) > int(_peak_of(peak, 3)[1]),
			"A late timing draw moves the actual peak, not the planned one")
	_check(Conditioning.timing_offset(2027, "GEE", 1, 99) == Conditioning.timing_offset(2027, "GEE", 1, 99),
			"The timing draw is seeded, so a reload replays it")


func _test_late_change() -> void:
	var early := _rec("peak")
	var mid := Conditioning.revise(_rec("steady"), 13, "peak")
	var last := Conditioning.revise(_rec("steady"), 20, "peak")
	var h0 := float(_peak_of(early, 3)[0])
	var h13 := float(_peak_of(mid, 3)[0])
	var h20 := float(_peak_of(last, 3)[0])
	_check(h0 > h13 and h13 > h20 and h20 > 0.0,
			"Switching to a September peak later builds less of it")
	_check(Conditioning.plan_at(mid, 5) == "steady" and Conditioning.plan_at(mid, 13) == "peak"
			and Conditioning.planned(mid, 5) == 0.0,
			"A revision keeps the weeks already played as they were")
	var twice := Conditioning.revise(mid, 13, "develop")
	_check((twice["changes"] as Array).size() == 2 and Conditioning.plan_at(twice, 13) == "develop",
			"Changing your mind in the same week replaces the choice")
	_check(Conditioning.revise(mid, 14, "nonsense") == mid, "An unknown plan changes nothing")


func _test_stamps() -> void:
	_check(Conditioning.stamps(0.0).is_empty(), "A level week stamps nothing on a player")
	var building := Conditioning.stamps(-0.5)
	var peaked := Conditioning.stamps(1.0)
	_check(float(building["cond_drain"]) > 1.0 and float(building["cond_cap"]) > 0.0
			and float(building["cond_injury"]) > 1.0,
			"Building hard tires players faster, takes legs off the top and raises soft-tissue risk")
	_check(float(peaked["cond_drain"]) < 1.0 and float(peaked["cond_cap"]) == 0.0
			and float(peaked["cond_injury"]) < 1.0,
			"At the peak players tire slower and break down less")
	var p := {"id": "x", "age": 25, "attr": {"durability": 70}}
	var base_chance := Injuries.chance(p)
	_check(Workload.energy_cap(p) == 100.0 and Workload.drain_mult(p) == 1.0,
			"An unstamped player has exactly the old legs")
	var list := [p]
	Conditioning.stamp_list(list, -1.0)
	_check(Workload.energy_cap(p) == 100.0 - Conditioning.CAP_K and Injuries.chance(p) > base_chance,
			"The week's stamp reaches the energy cap and the injury chance")
	Conditioning.stamp_list(list, 0.0)
	_check(not p.has("cond_drain") and not p.has("cond_cap") and not p.has("cond_injury")
			and Injuries.chance(p) == base_chance,
			"A level week clears last week's stamp")


func _sim(seed: int, stamp: Dictionary) -> MatchSim:
	var home: Array = GameDB.club_list("GEE").duplicate(true)
	var away: Array = GameDB.club_list("COL").duplicate(true)
	for p in home:
		for k in stamp:
			p[k] = stamp[k]
	return MatchSim.new(Squad.new("GEE", home, true, "GEE"), Squad.new("COL", away, false, "COL"), seed)


## The player-effect fixture: the same match, a peaked side against the same
## side unstamped. A neutral stamp plays the identical match.
func _test_match_effect() -> void:
	var plain := _sim(314, {}).run()
	var neutral := _sim(314, Conditioning.stamps(0.0)).run()
	_check(plain["score"] == neutral["score"] and plain["exertion"] == neutral["exertion"],
			"A level week plays exactly the match it did before conditioning")
	var peaked_sim := _sim(314, Conditioning.stamps(1.0))
	peaked_sim.run()
	var plain_sim := _sim(314, {})
	plain_sim.run()
	var legs := [0.0, 0.0]
	for p in plain_sim.squads[0].ground:
		legs[0] += float(plain_sim.energy[str(p["id"])])
		legs[1] += float(peaked_sim.energy.get(str(p["id"]), 0.0))
	_check(legs[1] > legs[0], "A peaked side finishes the match with more in its legs")


func _test_career() -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.fitness_ai_by_phase = false
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.advance()
	var stamped := false
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			stamped = stamped or p.has("cond_drain")
	_check(not stamped, "With every club steady, no player carries a conditioning stamp")

	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.fitness_ai_by_phase = true
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.can_revise_fitness() and GameState.set_fitness_plan("peak")
			and GameState.fitness_plan("GEE") == "peak",
			"You set your season plan in the pre-season")
	var matched := true
	var contenders := 0
	for code in GameState.season.lists:
		if str(code) == "GEE":
			continue
		var phase := GameState._club_phase(str(code))
		matched = matched and GameState.fitness_plan(str(code)) == Conditioning.ai_plan(phase)
		contenders += 1 if phase == "contending" else 0
	_check(matched and contenders > 0, "Every AI club runs the plan its phase calls for")
	GameState.advance()
	_check(not GameState.can_revise_fitness() and not GameState.set_fitness_plan("steady")
			and GameState.fitness_plan("GEE") == "peak",
			"Between revision points the plan is locked in")
	var gee_p: Dictionary = GameState.season.lists["GEE"][0]
	_check(gee_p.has("cond_cap") and float(gee_p["cond_drain"]) > 1.0,
			"Your players carry the build of a September peak in round 2")

	var snapshot: Dictionary = GameState.conditioning.duplicate(true)
	_check(GameState.save_career() and GameState.load_career()
			and GameState.conditioning == snapshot,
			"The season plans survive save and load")
	GameState.conditioning = {}
	_check(GameState.fitness_plan("GEE") == "steady"
			and GameState.fitness_plan(str(GameState.season.lists.keys()[1])) == "steady",
			"A save from before conditioning plays on as Steady")

	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.set_fitness_plan("peak")
	var before: Dictionary = GameState.season.lists["GEE"][0]
	_check(not before.has("cond_cap"), "Nothing is stamped before the week's first match is built")
	_check(GameState.prepare_interactive_match() and before.has("cond_cap")
			and GameState.pending_sim != null,
			"The match you coach live carries your conditioning, like every simulated one")
