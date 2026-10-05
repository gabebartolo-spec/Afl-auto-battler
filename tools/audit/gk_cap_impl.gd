extends RefCounted
## How many players sit at the goalkicking cap, and what real scoring they had.
func run() -> void:
	var rows := []
	for c in GameDB.CLUB_ORDER:
		for p in GameDB.club_list(c):
			var gm := float(p.get("gm", 0.0))
			if gm < 8:
				continue
			rows.append([float(p["attr"].get("goalkicking", 0)), float(p.get("gl", 0)) / gm, "%s %s" % [p.get("first", ""), p.get("last", "")], float(p["attr"].get("marking", 0)), int(p.get("overall", 0)), str(p.get("role", ""))])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var capped := 0
	for r in rows:
		if r[0] >= 99:
			capped += 1
	print("players (8+ real games) at goalkicking 99: %d" % capped)
	for b in [[99, 100], [95, 99], [90, 95], [85, 90]]:
		var n := 0
		for r in rows:
			if r[0] >= b[0] and r[0] < b[1]:
				n += 1
		print("goalkicking %d-%d: %d" % [b[0], b[1] - 1, n])
	print("top 15 real goals per game: goalkicking / marking / OVR")
	for r in rows.slice(0, 15):
		print("  %s %s %.2f/g  gk %.0f  mk %.0f  ovr %d" % [r[2], r[5], r[1], r[0], r[3], r[4]])
