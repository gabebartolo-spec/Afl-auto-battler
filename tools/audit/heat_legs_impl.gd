extends RefCounted
## QA (W7 of #639, measurement only): what Bring the heat does to legs and
## distance through a whole match. Paired seeds; side 0 plays every quarter
## with pep "steady" or "heat", under the balanced plan and the defensive press.
## Per arm: distance run per player who played (mean, max), team distance,
## the share of on-ground player-chains at the energy floor (<= 6) and under 30,
## mean energy of the ground by quarter, interchanges, and the margin.
## Env: HL_N matches (default 200), HL_SEED (default 9000).

class LegSim extends MatchSim:
	var samples := 0
	var floor_n := 0
	var low_n := 0
	var by_q := [0.0, 0.0, 0.0, 0.0, 0.0]
	var by_q_n := [0, 0, 0, 0, 0]

	func _init(home: Squad, away: Squad, seed: int = 0) -> void:
		super(home, away, seed)

	func _after_chain() -> void:
		super._after_chain()
		for p in (squads[0] as Squad).ground:
			var e := float(energy.get(str(p["id"]), 100.0))
			samples += 1
			if e <= 6.0:
				floor_n += 1
			if e < 30.0:
				low_n += 1
			var q := clampi(current_quarter, 1, 4)
			by_q[q] += e
			by_q_n[q] += 1


func _sim(codes: Array, i: int, seed: int) -> LegSim:
	var h := str(codes[i % codes.size()])
	var o := str(codes[(i * 5 + 1 + i / codes.size()) % codes.size()])
	if o == h:
		o = str(codes[(i + 1) % codes.size()])
	return LegSim.new(Squad.new(h, GameDB.club_list(h), true, h), Squad.new(o, GameDB.club_list(o), false, o), seed)


func run() -> void:
	var codes: Array = load("res://tools/balance/league_balance.gd").new().clubs()
	var n := int(OS.get_environment("HL_N")) if OS.get_environment("HL_N") != "" else 200
	var base := int(OS.get_environment("HL_SEED")) if OS.get_environment("HL_SEED") != "" else 9000
	var arms := [["balanced", "steady"], ["balanced", "heat"], ["defensive", "steady"], ["defensive", "heat"]]
	var acc := {}
	for a in arms:
		acc["%s/%s" % a] = {"dist": 0.0, "dist_n": 0, "max": 0.0, "over16": 0, "team": 0.0, "samples": 0, "floor": 0, "low": 0,
				"q": [0.0, 0.0, 0.0, 0.0, 0.0], "qn": [0, 0, 0, 0, 0], "ic": 0.0, "ex": 0.0, "ex_n": 0, "wl": 0.0, "margin": 0.0, "m2": 0.0, "d_margin": [], "press": 0.0}
	for i in range(n):
		var margins := {}
		for a in arms:
			var key := "%s/%s" % a
			var s := _sim(codes, i, base + i)
			s.set_tactics(0, {"gameplan": a[0], "pep": a[1]})
			var r := s.run()
			var A: Dictionary = acc[key]
			var pl: Dictionary = r["players"]
			for p in (r["roster"] as Array)[0]:
				var st: Dictionary = pl.get(str(p["id"]), {})
				var d := float(st.get("distance_run", 0.0))
				if d <= 0.0:
					continue
				A["dist"] += d
				A["dist_n"] += 1
				A["max"] = maxf(float(A["max"]), d)
				if d > 16000.0:
					A["over16"] += 1
			for p in (r["roster"] as Array)[0]:
				var ex := float((r.get("exertion", {}) as Dictionary).get(str(p["id"]), 0.0))
				if ex > 0.0:
					A["ex"] += ex
					A["ex_n"] += 1
					# Steady state if he played like this every week (Workload: carry 0.75,
					# load 0.16 per effort, recovery about 17 for durability 70 aged 25).
					A["wl"] += clampf(4.0 * (0.16 * ex - 17.0), 0.0, 100.0)
			A["team"] += float(((r["team"] as Array)[0] as Dictionary).get("distance_run", 0.0))
			A["press"] += float(((r["team"] as Array)[0] as Dictionary).get("pressure_acts", 0.0))
			A["samples"] += s.samples
			A["floor"] += s.floor_n
			A["low"] += s.low_n
			for q in range(1, 5):
				A["q"][q] += s.by_q[q]
				A["qn"][q] += s.by_q_n[q]
			A["ic"] += float((r.get("interchanges", [0, 0]) as Array)[0])
			var m := float(r["score"][0]) - float(r["score"][1])
			A["margin"] += m
			margins[key] = m
		for base_key in ["balanced", "defensive"]:
			var dm: float = float(margins[base_key + "/heat"]) - float(margins[base_key + "/steady"])
			(acc[base_key + "/heat"]["d_margin"] as Array).append(dm)
		if i % 50 == 49:
			print("done %d of %d" % [i + 1, n])
	print("HEAT LEGS n=%d seed=%d (side 0 all four quarters)" % [n, base])
	for a in arms:
		var key := "%s/%s" % a
		var A: Dictionary = acc[key]
		var qs := []
		for q in range(1, 5):
			qs.append("%.1f" % (float(A["q"][q]) / maxf(1.0, float(A["qn"][q]))))
		var line := "%-17s dist/player %.0f m  max %.0f m  >16km %d  team %.1f km  floor(<=6) %.2f%%  <30 %.2f%%  energy by q %s  interchanges %.1f  exertion/player %.1f  weekly-load steady state %.1f  margin %.2f" % [
				key, float(A["dist"]) / maxf(1.0, float(A["dist_n"])), float(A["max"]), int(A["over16"]), float(A["team"]) / n / 1000.0,
				100.0 * float(A["floor"]) / maxf(1.0, float(A["samples"])), 100.0 * float(A["low"]) / maxf(1.0, float(A["samples"])),
				"/".join(qs), float(A["ic"]) / n, float(A["ex"]) / maxf(1.0, float(A["ex_n"])), float(A["wl"]) / maxf(1.0, float(A["ex_n"])), float(A["margin"]) / n]
		line += "  pressure acts %.1f" % (float(A["press"]) / n)
		var dm: Array = A["d_margin"]
		if not dm.is_empty():
			var mean := 0.0
			for v in dm:
				mean += float(v)
			mean /= dm.size()
			var var2 := 0.0
			for v in dm:
				var2 += (float(v) - mean) * (float(v) - mean)
			line += "  paired margin vs steady %+.2f ± %.2f" % [mean, sqrt(var2 / maxf(1.0, dm.size() - 1)) / sqrt(dm.size())]
		print(line)
