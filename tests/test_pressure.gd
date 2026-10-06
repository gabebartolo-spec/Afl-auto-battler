extends RefCounted
## Pressure: who applies it (by zone, so forwards tackle), pressure acts
## (tackles plus rushed disposals and forced turnovers), the team Pressure
## Rating and pressure in the Player Rating. Run through
## tests/run_pressure_tests.gd.
## Seeded by design: every MatchSim takes an explicit seed.

var failures: Array[String] = []
var checks := 0
const MATCHES := 16


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_zones()
	_test_acts_and_reconcile()
	_test_role_pressure_matters()
	_test_high_pressure_forward()
	_test_rating_formula()
	_test_player_rating()
	_test_creating()
	_test_live_path()
	print("Pressure tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _lists() -> Array:
	var out := []
	for code in ["GEE", "COL"]:
		var l: Array = []
		for p in GameDB.club_list(code):
			l.append(p.duplicate(true))
		out.append(l)
	return out


## GEE v COL with `edit` applied to COL's squad after selection.
func _sim(seed: int, edit := Callable()) -> MatchSim:
	var lists := _lists()
	var home := Squad.new("GEE", lists[0], true, "GEE")
	var away := Squad.new("COL", lists[1], false, "COL")
	if edit.is_valid():
		edit.call(away)
		away._aggregate()
	return MatchSim.new(home, away, seed)


func _test_zones() -> void:
	_check(MatchSim._press_zone(-60.0) == 0 and MatchSim._press_zone(0.0) == 1
			and MatchSim._press_zone(60.0) == 2, "The ball's position picks the pressing zone")
	var z0: Dictionary = MatchSim.PRESS_ZONES[0]
	var z2: Dictionary = MatchSim.PRESS_ZONES[2]
	_check(float(z0["FWD"]) > float(z0["DEF"]) and float(z2["DEF"]) > float(z2["FWD"]),
			"Forwards press when the opposition comes out of defence, defenders when it goes forward")


## Tackles are pressure acts; most pressure acts are not tackles; every
## team total is the sum of its players'.
func _test_acts_and_reconcile() -> void:
	var fwd_tackles := 0.0
	var acts := 0.0
	var tackles := 0.0
	var reconciled := true
	var forced := false
	for i in range(MATCHES):
		var sim := _sim(300 + i)
		var res := sim.run()
		for side in range(2):
			var team: Dictionary = res["team"][side]
			var sum_pa := 0.0
			var sum_tk := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				sum_pa += float(st.get("pressure_acts", 0.0))
				sum_tk += float(st.get("tackles", 0.0))
				if str(r["role"]) == "FWD":
					fwd_tackles += float(st.get("tackles", 0.0))
			reconciled = reconciled and is_equal_approx(sum_pa, float(team.get("pressure_acts", 0.0))) \
					and is_equal_approx(sum_tk, float(team.get("tackles", 0.0)))
			acts += float(team.get("pressure_acts", 0.0))
			tackles += float(team.get("tackles", 0.0))
		for ev in res["events"]:
			if str(ev.get("kind", "")) == "pressure":
				forced = true
	_check(fwd_tackles > 0.0, "Forwards record tackles (%d in %d matches)" % [fwd_tackles, MATCHES])
	_check(reconciled, "Every team's pressure acts and tackles are the sum of its players'")
	_check(acts > tackles * 2.0, "Most pressure acts are not tackles (%d acts, %d tackles)" % [acts, tackles])
	_check(forced, "Pressure can force a turnover without a tackle")


## Lifting one line's Pressure lifts the side's pressure: midfield and
## defence both matter now, not just the defenders.
func _test_role_pressure_matters() -> void:
	for role in ["MID", "DEF", "FWD"]:
		var base := _pressure_per_opp_disposal(Callable())
		var lifted := _pressure_per_opp_disposal(func(sq: Squad):
			for p in sq.ground:
				if str(p["role"]) == role:
					p["attr"]["pressure"] = minf(99.0, float(p["attr"]["pressure"]) + 30.0))
		_check(lifted > base, "%s Pressure raises the side's pressure (%.3f -> %.3f acts per opposition disposal)" % [role, base, lifted])


func _pressure_per_opp_disposal(edit: Callable) -> float:
	var acts := 0.0
	var opp_disp := 0.0
	for i in range(MATCHES):
		var res := _sim(700 + i, edit).run()
		acts += float(res["team"][1].get("pressure_acts", 0.0))
		opp_disp += float(res["team"][0].get("disposals", 0.0))
	return acts / opp_disp


## A forward with elite Pressure produces more pressure acts than he did at
## ordinary Pressure - without producing all of them.
func _test_high_pressure_forward() -> void:
	var target := ""
	var probe := _sim(1)
	for p in probe.squads[1].ground:
		if str(p["role"]) == "FWD":
			target = str(p["id"])
			break
	var ordinary := _player_acts(target, 40.0)
	var elite := _player_acts(target, 95.0)
	_check(elite > ordinary * 1.5,
			"A high-Pressure forward generates far more pressure acts (%.1f -> %.1f a game)" % [ordinary, elite])
	_check(elite < 40.0, "...but not every one on the ground (%.1f a game)" % elite)


func _player_acts(id: String, pressure: float) -> float:
	var total := 0.0
	for i in range(MATCHES):
		var res := _sim(900 + i, func(sq: Squad):
			for p in sq.ground:
				if str(p["id"]) == id:
					p["attr"]["pressure"] = pressure).run()
		total += float((res["players"].get(id, {}) as Dictionary).get("pressure_acts", 0.0))
	return total / MATCHES


func _test_rating_formula() -> void:
	var a := {"pressure_acts": 180.0, "pressure_wins": 40.0, "disposals": 350.0}
	var b := {"pressure_acts": 160.0, "pressure_wins": 30.0, "disposals": 380.0}
	_check(MatchSim.pressure_rating(a, b) == roundi(100.0 * 220.0 / 380.0),
			"Pressure rating: acts plus stopped moves per 100 opposition disposals")
	# The same acts against fewer opposition disposals is a better rating.
	var fewer := b.duplicate()
	fewer["disposals"] = 300.0
	_check(MatchSim.pressure_rating(a, fewer) > MatchSim.pressure_rating(a, b),
			"More pressure per opposition disposal rates higher, not just more acts")
	_check(MatchSim.pressure_rating(a, {"disposals": 0.0}) == 0, "No opposition ball, no rating")
	# Across real matches the rating tracks the side's pressure personnel.
	var base := _mean_rating(Callable())
	var lifted := _mean_rating(func(sq: Squad):
		for p in sq.ground:
			p["attr"]["pressure"] = minf(99.0, float(p["attr"]["pressure"]) + 25.0))
	_check(lifted > base + 2.0, "A harder-pressing side earns a better pressure rating (%.1f -> %.1f)" % [base, lifted])


func _mean_rating(edit: Callable) -> float:
	var total := 0.0
	for i in range(MATCHES):
		var res := _sim(1100 + i, edit).run()
		total += MatchSim.pressure_rating(res["team"][1], res["team"][0])
	return total / MATCHES


## A tackle is also a pressure act: 2 + 1 = 3 in all, as before. Pressure
## without a tackle is worth 1.
func _test_player_rating() -> void:
	_check(MatchNotes.rating({"tackles": 1, "pressure_acts": 1}) == 3, "A tackle is worth 3 in all, not 4")
	_check(MatchNotes.rating({"pressure_acts": 1}) == 1, "A pressure act without a tackle is worth 1")
	_check(MatchNotes.rating({"pressure_acts": 25}) < 30,
			"Pressure alone does not make a big game (%d for 25 acts)" % MatchNotes.rating({"pressure_acts": 25}))


## The inside-50 kick's Creating lifts the shot, within a narrow band
## (below the Playmaker threshold, which adds its own 5%).
func _test_creating() -> void:
	var sim := _sim(5)
	var shooter: Dictionary = sim.squads[0].ground.filter(func(p): return str(p["role"]) == "FWD")[0]
	var low := {"id": "f_low", "role": "MID", "attr": {"creating": 30.0}}
	var high := {"id": "f_high", "role": "MID", "attr": {"creating": 70.0}}
	var p_low := sim.shot_chance(0, shooter, true, false, false, low)
	var p_high := sim.shot_chance(0, shooter, true, false, false, high)
	_check(p_high > p_low, "A creative inside-50 kick makes a better shot")
	_check(p_high / p_low < 1.10, "...by a restrained amount (%.3f x)" % (p_high / p_low))


## Watched matches (quarter by quarter, with moments) run the same pressure.
func _test_live_path() -> void:
	var sim := _sim(21)
	sim.moment_side = 0
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		sim.end_quarter()
	var res := sim.result()
	var fwd_tackles := 0.0
	for side in range(2):
		for r in res["roster"][side]:
			if str(r["role"]) == "FWD":
				fwd_tackles += float((res["players"].get(str(r["id"]), {}) as Dictionary).get("tackles", 0.0))
	_check(float(res["team"][0].get("pressure_acts", 0.0)) > float(res["team"][0].get("tackles", 0.0))
			and fwd_tackles > 0.0, "A watched match credits pressure acts and forward tackles the same way")
