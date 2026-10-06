extends RefCounted
## Collection pauses (director's PC playtest, 2026-10-07): how often does the
## match log move the ball further between two consecutive events than the
## first event could carry it? Counts jumps in field position (fp, metres
## along the ground) over 30 m, by the pair of event kinds, over FJ_MATCHES
## seeded matches (default 20).

const DISPOSALS := ["kick", "handball", "mark"]


func run() -> void:
	var n := int(OS.get_environment("FJ_MATCHES")) if OS.get_environment("FJ_MATCHES") != "" else 20
	var codes := ["MEL", "CAR", "COL", "GEE", "SYD", "BRL"]
	var pairs := {}
	var total := 0
	var jumps := 0
	for i in range(n):
		var home: String = codes[i % codes.size()]
		var away: String = codes[(i + 1) % codes.size()]
		var sim := MatchSim.new(Squad.new(home, GameDB.club_list(home), true, home),
				Squad.new(away, GameDB.club_list(away), false, away), 9000 + i)
		var res := sim.run()
		var prev := {}
		for ev in res["events"]:
			if not (ev as Dictionary).has("fp"):
				continue
			if not prev.is_empty():
				total += 1
				var d := absf(float(ev["fp"]) - float(prev["fp"]))
				var pk := str(prev.get("kind", ""))
				if d > 30.0 and pk != "goal" and pk != "behind" and str(ev.get("kind", "")) != "ballup" and str(ev.get("kind", "")) != "quarter":
					jumps += 1
					var key := "%s -> %s" % [pk, str(ev.get("kind", ""))]
					pairs[key] = int(pairs.get(key, 0)) + 1
			prev = ev
	print("fpjump: %d matches, %d consecutive events, %d jumps over 30 m (%.1f a match)" % [n, total, jumps, float(jumps) / n])
	var keys := pairs.keys()
	keys.sort_custom(func(a, b): return int(pairs[a]) > int(pairs[b]))
	for k in keys.slice(0, 15):
		print("fpjump: %-28s %d" % [k, int(pairs[k])])
