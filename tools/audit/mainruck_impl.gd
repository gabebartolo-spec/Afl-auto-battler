extends RefCounted
## Main ruck (director, 2026-10-07), measurement only: for every club that
## names two rucks in its team, the second ruck named main ruck against the
## same seeds without the call. Per game: each ruck's ruck contests and
## hit-outs, and the stoppages he was on the ground for both ways, so the
## size of the call can be read against how often both rucks are out there.
## Env: MR_N games a club (default 40).


func run() -> void:
	var n := int(OS.get_environment("MR_N")) if OS.get_environment("MR_N") != "" else 40
	var db = Engine.get_main_loop().root.get_node("GameDB")
	for c in load("res://tools/balance/league_balance.gd").new().clubs():
		var opp := "COL" if c != "COL" else "GEE"
		var probe := _sim(c, opp, 70)
		var found := []
		for q in probe.squads[0].ground + probe.squads[0].bench:
			if MatchSim._is_ruckman(q):
				found.append(q)
		if found.size() < 2:
			continue
		var first: Array = probe._contestant(probe.squads[0])
		var fid := str(first[0]["id"]) if not first.is_empty() else ""
		var oid := ""
		var o_start := "bench"
		for r in found:
			if str(r["id"]) != fid:
				oid = str(r["id"])
				break
		for q in probe.squads[0].ground:
			if str(q["id"]) == oid:
				o_start = str(q["role"])
		var acc := {"on": {}, "off": {}}
		for arm in ["on", "off"]:
			for k in ["o_rc", "o_ho", "f_rc", "f_ho", "side_rc", "side_ho"]:
				acc[arm][k] = 0.0
		for i in range(n):
			for arm in ["on", "off"]:
				var s := _sim(c, opp, 1100 + i)
				if arm == "on":
					s.set_tactics(0, {"main_ruck": oid})
				var r := s.run()
				var pl: Dictionary = r["players"]
				var a: Dictionary = acc[arm]
				a["o_rc"] += float((pl.get(oid, {}) as Dictionary).get("ruck_contests", 0.0))
				a["o_ho"] += float((pl.get(oid, {}) as Dictionary).get("hitouts", 0.0))
				a["f_rc"] += float((pl.get(fid, {}) as Dictionary).get("ruck_contests", 0.0))
				a["f_ho"] += float((pl.get(fid, {}) as Dictionary).get("hitouts", 0.0))
				a["side_ho"] += float(((r["team"] as Array)[0] as Dictionary).get("hitouts", 0.0))
				var rc := 0.0
				for id in pl:
					if probe.squads[0].ground.any(func(q): return str(q["id"]) == id) or probe.squads[0].bench.any(func(q): return str(q["id"]) == id):
						rc += float((pl[id] as Dictionary).get("ruck_contests", 0.0))
				a["side_rc"] += rc
		var on: Dictionary = acc["on"]
		var off: Dictionary = acc["off"]
		print("%s  first %s (%.0f ruck)  second %s (%.0f ruck, starts %s)" % [c,
				db.player_display_name_by_id(fid, "?"), float(first[0]["attr"]["ruck"]),
				db.player_display_name_by_id(oid, "?"), float(_by_id(found, oid)["attr"]["ruck"]), o_start])
		print("   second named: contests %.1f (v %.1f)  hit-outs %.1f (v %.1f)  | first: contests %.1f (v %.1f) hit-outs %.1f (v %.1f) | side contests %.1f (v %.1f) hit-outs %.1f (v %.1f)" % [
				on["o_rc"] / n, off["o_rc"] / n, on["o_ho"] / n, off["o_ho"] / n,
				on["f_rc"] / n, off["f_rc"] / n, on["f_ho"] / n, off["f_ho"] / n,
				on["side_rc"] / n, off["side_rc"] / n, on["side_ho"] / n, off["side_ho"] / n])


func _sim(a: String, b: String, seed: int) -> MatchSim:
	var db = Engine.get_main_loop().root.get_node("GameDB")
	return MatchSim.new(Squad.new(a, db.club_list(a), true, a), Squad.new(b, db.club_list(b), false, b), seed)


func _by_id(arr: Array, id: String) -> Dictionary:
	for p in arr:
		if str(p["id"]) == id:
			return p
	return {}
