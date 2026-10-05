extends RefCounted
## "How we get beaten" on career-style drafted leagues (tools/balance): which
## clubs get a line at rounds 6/12/18/24, and the real club-to-club spread per
## stat against GameState.STYLE_MIN.

func _spread(rnd: int) -> void:
	var out := "  R%d spread (SD of per-game club values) vs STYLE_MIN:" % rnd
	for k in GameState.STYLE_MIN:
		var vals := []
		for c in GameState.season_team:
			var row: Dictionary = GameState.season_team[c]
			vals.append(float(row.get(k, 0.0)) / maxf(1.0, float(row.get("games", 1))))
		var m := 0.0
		for v in vals: m += v
		m /= vals.size()
		var sd := 0.0
		for v in vals: sd += (v - m) * (v - m)
		sd = sqrt(sd / vals.size())
		out += "\n      %-18s SD %5.2f  MIN %5.2f  MIN/SD %.2f" % [k, sd, float(GameState.STYLE_MIN[k]), float(GameState.STYLE_MIN[k]) / maxf(0.01, sd)]
	print(out)

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var totals := {}
	for draft_seed in [7, 8, 9, 10]:
		var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
		var codes: Array = lb.clubs()
		var season := Season.new(codes, lists, draft_seed * 101)
		GameState.reset()
		GameState.season_team = {}
		var rnd := 0
		while not season.is_regular_done():
			for res in season.play_round():
				GameState._note_form_and_team(res)
			season.recalc_ladder()
			rnd += 1
			if rnd in [6, 12, 18, 24]:
				var table: Array = season.ladder_sorted()
				for i in range(table.size()):
					var code := str(table[i]["code"])
					var hp: Dictionary = GameState.how_we_play(code)
					var b := "top6" if i < 6 else ("bottom6" if i >= table.size() - 6 else "mid")
					var key := "R%d %s" % [rnd, b]
					var t: Array = totals.get(key, [0, 0, 0])
					t[0] += 1
					if not (hp["beaten"] as Array).is_empty(): t[1] += 1
					if not (hp["win"] as Array).is_empty(): t[2] += 1
					totals[key] = t
			if rnd == 12 and draft_seed == 7:
				_spread(rnd)
	for rnd in [6, 12, 18, 24]:
		var line := "R%d:" % rnd
		for b in ["top6", "mid", "bottom6"]:
			var t: Array = totals.get("R%d %s" % [rnd, b], [0, 0, 0])
			line += "  %s beaten %d/%d win %d/%d" % [b, t[1], t[0], t[2], t[0]]
		print(line)
	GameState.reset()
