extends RefCounted
## QA (W7 of #642, measurement only): the loose-man rule across the league,
## AI against AI (both sides name their own loose man as the AI does).
## Per club: its loose man's read (MatchSim._loose_read of the AI's pick at the
## first bounce), late and reached entries a game, points conceded. League: total
## points a game. Run on #642 and on its base with the same seeds.
## Env: LL_N matches (default 306 = 17 rounds of 18 clubs), LL_SEED (default 5000).

func run() -> void:
	var codes: Array = load("res://tools/balance/league_balance.gd").new().clubs()
	var n := int(OS.get_environment("LL_N")) if OS.get_environment("LL_N") != "" else 306
	var base := int(OS.get_environment("LL_SEED")) if OS.get_environment("LL_SEED") != "" else 5000
	var club := {}
	var total := 0.0
	var total2 := 0.0
	for i in range(n):
		var h := str(codes[i % codes.size()])
		var a := str(codes[(i * 7 + 3 + i / codes.size()) % codes.size()])
		if a == h:
			a = str(codes[(i + 1) % codes.size()])
		var hs := Squad.new(h, GameDB.club_list(h), true, h)
		var as_ := Squad.new(a, GameDB.club_list(a), false, a)
		hs.ai_plans = true
		as_.ai_plans = true
		var sim := MatchSim.new(hs, as_, base + i)
		var reads := []
		for side in range(2):
			var sp: Dictionary = Matchups.best_interceptor((sim.squads[side] as Squad).ground)
			reads.append(sim._loose_read(sp) if not sp.is_empty() else -1.0)
		var r := sim.run()
		var sc: Array = r["score"]
		var pts := float(sc[0]) + float(sc[1])
		total += pts
		total2 += pts * pts
		for side in range(2):
			var code := h if side == 0 else a
			var c: Dictionary = club.get(code, {"g": 0, "read": 0.0, "late": 0.0, "reach": 0.0, "against": 0.0})
			var team: Dictionary = (r["team"] as Array)[side]
			c["g"] += 1
			c["read"] += float(reads[side])
			c["late"] += float(team.get("roam_late", 0.0))
			c["reach"] += float(team.get("roam_contests", 0.0))
			c["against"] += float(sc[1 - side])
			club[code] = c
	var mean := total / n
	print("LOOSE LEAGUE n=%d seed=%d  points a game %.2f (se %.2f)" % [n, base, mean, sqrt(maxf(0.0, total2 / n - mean * mean) / n)])
	var keys := club.keys()
	keys.sort()
	for code in keys:
		var c: Dictionary = club[code]
		var g := float(c["g"])
		print("  %s  read %.2f  late %.1f  reached %.1f  conceded %.1f  (%d games)" % [code, c["read"] / g, c["late"] / g, c["reach"] / g, c["against"] / g, int(g)])
