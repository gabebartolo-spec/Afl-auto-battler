extends RefCounted
func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var lists: Dictionary = lb.drafted_lists(21)["lists"]
	var codes: Array = lb.clubs()
	var f50 := float(Ratings.T["forward50_line"])
	var gl := float(Ratings.T["goal_line"])
	var c := {"games": 0, "free_i50": 0, "shots": 0, "set": 0, "crumb": 0, "goals": 0, "gmarks_i50": 0}
	var dist := {}
	for i in range(0, codes.size() - 1, 2):
		for rep in range(6):
			var a := Squad.new(codes[i], lists[codes[i]], true, codes[i])
			var b := Squad.new(codes[i + 1], lists[codes[i + 1]], false, codes[i + 1])
			var r: Dictionary = MatchSim.new(a, b, 7000 + i * 10 + rep).run()
			c["games"] += 1
			for e in r["events"]:
				var k := str(e["kind"])
				var s := int(e["side"])
				var afp := float(e["fp"]) * (1.0 if s == 0 else -1.0)
				if k == "free" and afp >= f50:
					c["free_i50"] += 1
					var m := snappedf(gl - afp, 10.0)
					dist[m] = int(dist.get(m, 0)) + 1
				if k == "mark" and bool(e.get("general_play", false)) and afp >= f50:
					c["gmarks_i50"] += 1
				if k == "goal" or k == "behind":
					c["shots"] += 1
					if k == "goal":
						c["goals"] += 1
					if bool(e.get("set", false)):
						c["set"] += 1
					if bool(e.get("crumb", false)):
						c["crumb"] += 1
	var g := float(c["games"])
	print("PROBE per match | scoring shots %.1f, set %.1f (%.1f%%), crumbs %.1f, goals %.1f | frees in 50 %.2f | general-play marks in 50 %.2f" % [
		c["shots"] / g, c["set"] / g, 100.0 * c["set"] / maxf(1, c["shots"]), c["crumb"] / g, c["goals"] / g, c["free_i50"] / g, c["gmarks_i50"] / g])
	print("PROBE free-in-50 distance (m from goal, per match): ", JSON.stringify(dist))
