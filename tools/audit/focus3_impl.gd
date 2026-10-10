extends RefCounted
## QA (W7 of #634, measurement only): what the three play-through calls do to
## the side that makes them. Paired seeds: every match once with no call and
## once with all three (best contested midfielder, best goalkicking forward,
## best ball-using defender on side 0). Reports side 0's margin and score and
## each man's own line, as paired differences with standard errors. Also checks
## that a single older focus_id plays exactly as the new call for his slot.
## Env: F3_N matches (default 400), F3_SEED seed base (default 9000).

func _pick(sim: MatchSim, role: String, key: String) -> Dictionary:
	var best: Dictionary = {}
	var best_v := -INF
	for p in (sim.squads[0] as Squad).ground:
		if str(p["role"]) != role:
			continue
		var v := sim._a(p, key) if key != "use" else sim._a(p, "disposal") + sim._a(p, "carry")
		if v > best_v:
			best_v = v
			best = p
	return best


func _sim(codes: Array, i: int, seed: int) -> MatchSim:
	var h := str(codes[i % codes.size()])
	var o := str(codes[(i * 5 + 1 + i / codes.size()) % codes.size()])
	if o == h:
		o = str(codes[(i + 1) % codes.size()])
	return MatchSim.new(Squad.new(h, GameDB.club_list(h), true, h), Squad.new(o, GameDB.club_list(o), false, o), seed)


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var n := int(OS.get_environment("F3_N")) if OS.get_environment("F3_N") != "" else 400
	var base := int(OS.get_environment("F3_SEED")) if OS.get_environment("F3_SEED") != "" else 9000
	var keys := ["margin", "score", "team_disp", "mid_disp", "fwd_shots", "fwd_goals", "def_disp", "opp_score"]
	var d := {}
	var d2 := {}
	var off := {}
	var on := {}
	for k in keys:
		d[k] = 0.0; d2[k] = 0.0; off[k] = 0.0; on[k] = 0.0
	var m := 0
	var wins_off := 0.0
	var wins_on := 0.0
	var legacy_checked := 0
	var legacy_diff := 0
	for i in range(n):
		var seed := base + i
		var plain := _sim(codes, i, seed)
		var mid := _pick(plain, "MID", "contested")
		var fwd := _pick(plain, "FWD", "goalkicking")
		var def := _pick(plain, "DEF", "use")
		if mid.is_empty() or fwd.is_empty() or def.is_empty():
			continue
		var r0 := plain.run()
		var three := _sim(codes, i, seed)
		three.set_tactics(0, {"focus_mid": str(mid["id"]), "focus_fwd": str(fwd["id"]), "focus_def": str(def["id"])})
		var r1 := three.run()
		m += 1
		var lines := []
		for r in [r0, r1]:
			var pl: Dictionary = r["players"]
			var sc: Array = r["score"]
			var fs: Dictionary = pl.get(str(fwd["id"]), {})
			lines.append({"margin": float(sc[0]) - float(sc[1]), "score": float(sc[0]), "opp_score": float(sc[1]),
					"team_disp": float(((r["team"] as Array)[0] as Dictionary).get("disposals", 0.0)),
					"mid_disp": float((pl.get(str(mid["id"]), {}) as Dictionary).get("disposals", 0.0)),
					"fwd_shots": float(fs.get("goals", 0.0)) + float(fs.get("behinds", 0.0)),
					"fwd_goals": float(fs.get("goals", 0.0)),
					"def_disp": float((pl.get(str(def["id"]), {}) as Dictionary).get("disposals", 0.0))})
		for k in keys:
			var a: float = lines[0][k]
			var b: float = lines[1][k]
			off[k] += a; on[k] += b; d[k] += b - a; d2[k] += (b - a) * (b - a)
		wins_off += 1.0 if lines[0]["margin"] > 0 else (0.5 if lines[0]["margin"] == 0 else 0.0)
		wins_on += 1.0 if lines[1]["margin"] > 0 else (0.5 if lines[1]["margin"] == 0 else 0.0)
		# Legacy parity: focus_id on the forward plays as focus_fwd on him.
		if i % 10 == 0:
			var la := _sim(codes, i, seed)
			la.set_tactics(0, {"focus_id": str(fwd["id"])})
			var lb2 := _sim(codes, i, seed)
			lb2.set_tactics(0, {"focus_fwd": str(fwd["id"])})
			var ra := la.run()
			var rb := lb2.run()
			legacy_checked += 1
			if ra["score"] != rb["score"] or (ra["events"] as Array).size() != (rb["events"] as Array).size():
				legacy_diff += 1
		if i % 50 == 49:
			print("done %d of %d" % [i + 1, n])
	print("FOCUS3 paired matches n=%d seed=%d" % [m, base])
	for k in keys:
		var mean: float = d[k] / m
		var se := sqrt(maxf(0.0, d2[k] / m - mean * mean) / m)
		print("  %-10s none %7.2f  three %7.2f  diff %+6.2f (se %.2f)" % [k, off[k] / m, on[k] / m, mean, se])
	print("  win share  none %.3f  three %.3f" % [wins_off / m, wins_on / m])
	print("  legacy focus_id == focus_fwd: %d of %d identical" % [legacy_checked - legacy_diff, legacy_checked])
