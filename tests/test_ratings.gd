extends RefCounted
## The overall rating (Ratings.rate_overall) describes what the match engine
## rewards: each role's core is built from the attributes Squad and MatchSim
## use for that role, the scale stays bounded and position-fair, a list's
## mean OVR tracks its engine strength, and a loaded save re-derives OVR from
## the attributes. Run through tests/run_ratings_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_weights()
	_test_role_attributes()
	_test_archetypes()
	_test_scale()
	_test_ovr_tracks_strength()
	_test_save_recomputes()
	GameState.delete_saved_career()
	print("Ratings tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## A flat 50 in every attribute.
func _base() -> Dictionary:
	var a := {}
	for k in ["disposal", "contested", "marking", "pressure", "intercept", "carry", "goalkicking",
			"accuracy", "creating", "ruck", "discipline", "durability", "star"]:
		a[k] = 50
	return a


func _ov(a: Dictionary, role: String) -> int:
	return Ratings.rate_overall(a, role, 20.0)


func _with(role: String, changes: Dictionary) -> int:
	var a := _base()
	for k in changes:
		a[k] = changes[k]
	return _ov(a, role)


func _test_weights() -> void:
	var ok := true
	for role in Ratings.ROLE_WEIGHTS:
		var total := 0.0
		for k in Ratings.ROLE_WEIGHTS[role]:
			total += float(Ratings.ROLE_WEIGHTS[role][k])
			if not _base().has(k):
				ok = false
		if not is_equal_approx(total, 1.0):
			ok = false
	_check(ok, "Every role core is a weighting of real attributes that adds to 1")


## Each role's rating moves with what the engine uses it for, and not with
## what the engine ignores for that role.
func _test_role_attributes() -> void:
	var cases := [
		["MID", "contested", "The engine's stoppage attribute lifts a midfielder"],
		["MID", "carry", "Carry lifts a midfielder"],
		["DEF", "pressure", "Pressure lifts a defender"],
		["DEF", "intercept", "Intercept lifts a defender"],
		["FWD", "goalkicking", "Goalkicking lifts a forward"],
		["FWD", "marking", "Marking lifts a forward"],
		["RUCK", "ruck", "Ruck work lifts a ruck"],
	]
	var flat := {}
	for role in ["MID", "DEF", "FWD", "RUCK"]:
		flat[role] = _with(role, {})
	for c in cases:
		_check(_with(c[0], {c[1]: 80}) >= int(flat[c[0]]) + 2, "%s (%d -> %d)" % [c[2], int(flat[c[0]]), _with(c[0], {c[1]: 80})])
	var unused := [["DEF", "disposal"], ["DEF", "goalkicking"], ["FWD", "disposal"], ["FWD", "pressure"],
			["RUCK", "intercept"], ["RUCK", "disposal"], ["MID", "pressure"], ["MID", "intercept"]]
	var still := true
	for c in unused:
		if _with(c[0], {c[1]: 90}) != int(flat[c[0]]):
			still = false
	_check(still, "Attributes the engine does not use for a role leave that role's rating alone")
	# Star power and durability count for everyone.
	_check(_with("DEF", {"star": 80}) > int(flat["DEF"]) and _with("FWD", {"durability": 90}) > int(flat["FWD"]),
			"Star power and durability count in every role")


## Players the engine would pick first rate higher within their role.
func _test_archetypes() -> void:
	var stopper := _with("DEF", {"pressure": 78, "intercept": 78})
	var kicker := _with("DEF", {"disposal": 85, "goalkicking": 70, "pressure": 42, "intercept": 45})
	_check(stopper > kicker + 8, "A tackling, intercepting defender outrates a ball-using one who cannot stop (%d v %d)" % [stopper, kicker])
	var bull := _with("MID", {"contested": 85, "carry": 65})
	var pretty := _with("MID", {"disposal": 85, "pressure": 80, "contested": 40})
	_check(bull > pretty, "An inside midfielder who wins the stoppages outrates an outside one who does not (%d v %d)" % [bull, pretty])
	var target := _with("FWD", {"goalkicking": 80, "marking": 80, "accuracy": 70})
	var runner := _with("FWD", {"disposal": 80, "carry": 80, "pressure": 80})
	_check(target > runner + 8, "A marking, goalkicking forward outrates a running one who does not score (%d v %d)" % [target, runner])
	var tapper := _with("RUCK", {"ruck": 85})
	var mobile := _with("RUCK", {"ruck": 45, "disposal": 80, "intercept": 80})
	_check(tapper > mobile + 8, "A ruck who wins the tap outrates one who does not (%d v %d)" % [tapper, mobile])


## The real 2026 pool on the new scale: bounded, no crowd of 90s, every
## position able to reach the high 80s, nobody near the retirement floor.
func _test_scale() -> void:
	var by_role := {"MID": [], "DEF": [], "FWD": [], "RUCK": []}
	var nineties := 0
	var lo := 99
	var hi := 1
	for p in GameDB.players:
		var ov := int(p["overall"])
		(by_role[str(p["role"])] as Array).append(ov)
		nineties += 1 if ov >= 90 else 0
		lo = mini(lo, ov)
		hi = maxi(hi, ov)
	_check(lo >= 36 and hi <= 97, "2026 ratings stay on the scale, clear of the retirement floor (%d-%d)" % [lo, hi])
	_check(nineties >= 1 and nineties <= 8, "Only a handful of 90+ players (%d)" % nineties)
	var fair := true
	var meds := []
	for role in by_role:
		var v: Array = by_role[role]
		v.sort()
		meds.append(int(v[v.size() / 2]))
		if int(v[-1]) < 84:
			fair = false
	_check(fair, "Every position's best reach the mid 80s or better")
	_check(meds.max() - meds.min() <= 6, "Position medians stay close together (%s)" % str(meds))
	var mono := true
	for role in Ratings.STRETCH_ANCHORS:
		var last := -INF
		for x in range(20, 100):
			var y := Ratings.position_stretch(float(x), role)
			if y < last:
				mono = false
			last = y
	_check(mono, "The position scale never reverses an order")


## Across the 18 real lists, a higher mean selected-22 OVR means a higher
## engine strength - the point of the rating.
func _test_ovr_tracks_strength() -> void:
	var xs := []
	var ys := []
	for code in GameDB.CLUB_ORDER:
		var list: Array = GameDB.club_list(code)
		if list.is_empty():
			continue
		var sq := Squad.new(code, list, false, code)
		var total := 0.0
		for p in sq.ground + sq.bench:
			total += float(p["overall"])
		xs.append(total / float(sq.ground.size() + sq.bench.size()))
		ys.append(sq.strength())
	var r := _pearson(xs, ys)
	_check(r >= 0.80, "Selected-22 OVR tracks engine strength across the real lists (r = %.2f)" % r)


func _pearson(xs: Array, ys: Array) -> float:
	var n := float(xs.size())
	var mx := 0.0
	var my := 0.0
	for i in range(xs.size()):
		mx += float(xs[i]) / n
		my += float(ys[i]) / n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(xs.size()):
		sxy += (float(xs[i]) - mx) * (float(ys[i]) - my)
		sxx += pow(float(xs[i]) - mx, 2)
		syy += pow(float(ys[i]) - my, 2)
	return sxy / sqrt(sxx * syy) if sxx > 0.0 and syy > 0.0 else 0.0


## OVR is derived data: a save carrying an out-of-date rating is corrected
## on load (with POT moved by the same amount), and a current one is not
## touched.
func _test_save_recomputes() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var p: Dictionary = GameState.my_list[0]
	var id := str(p["id"])
	var right := int(p["overall"])
	var pot := int(p["potential"])
	var other: Dictionary = GameState.my_list[1]
	var other_ov := int(other["overall"])
	var other_pot := int(other["potential"])
	p["overall"] = right - 7          # as an older formula might have rated him
	p["value"] = Ratings.salary_value(right - 7)
	p["potential"] = pot - 7
	GameState.save_career()
	GameState.load_career()
	var q := GameState.list_player(id)
	_check(int(q["overall"]) == right and int(q["overall"]) == Ratings.rate_overall(q["attr"], str(q["role"]), Ratings.effective_games(q)),
			"A stale saved OVR is re-derived from the attributes on load (%d)" % int(q["overall"]))
	_check(int(q["value"]) == Ratings.salary_value(right), "Its salary value follows")
	_check(int(q["potential"]) == pot, "POT moves with it, keeping his headroom (%d)" % int(q["potential"]))
	var o := GameState.list_player(str(other["id"]))
	_check(int(o["overall"]) == other_ov and int(o["potential"]) == other_pot, "A current rating is left exactly as it was")
	# Every player on every list agrees with the formula after a load.
	var agree := true
	for code in GameState.season.lists:
		for x in GameState.season.lists[code]:
			if int(x["overall"]) != Ratings.rate_overall(x["attr"], str(x["role"]), Ratings.effective_games(x)):
				agree = false
	_check(agree, "Every loaded rating matches the current formula")
