extends RefCounted
## Extreme margins (roadmap §9.1 "Extreme-margin calibration -
## BALANCE-GATED"). Measurement only.
##
## A. Frequency: drafted leagues, one home-and-away season each, played as
##    Season.play_round plays it (Season.match_sim -> MatchSim, threads not
##    needed). Margins 80+/100+/120+/150+ overall, in the strongest list's
##    matches, and by strength-rank gap; plus extreme individual stat lines.
## B. Compounding: EXM_VARIANT switches one thing off in EVERY match, same
##    seeds: "syn" (both sides' synergies), "momentum" (momentum_edge 0),
##    "form" (both sides' club form 0), "all"; default "base". Compare the tail
##    frequencies across runs. (Replaying only the biggest margins with a
##    factor off is not used: any change re-rolls the match, so selected
##    blowouts regress to an ordinary margin whatever is switched off.)
## Env: EXM_DRAFTS (default 21..36), EXM_VARIANT.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- extreme_margins_impl

const BANDS := [80, 100, 120, 150]


static func _env_ints(key: String, fallback: Array) -> Array:
	var v := OS.get_environment(key)
	if v == "":
		return fallback
	var out := []
	for part in v.split(","):
		out.append(int(part))
	return out


func _default_drafts() -> Array:
	var out := []
	for d in range(21, 37):
		out.append(d)
	return out


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var drafts := _env_ints("EXM_DRAFTS", _default_drafts())
	var variant := OS.get_environment("EXM_VARIANT") if OS.get_environment("EXM_VARIANT") != "" else "base"
	var codes: Array = lb.clubs()
	var all := []          # every match: {d, h, a, seed, fh, fa, margin, gap, strongest}
	var counts := {}
	var strong_counts := {}
	var strong_n := 0
	for b in BANDS:
		counts[b] = 0
		strong_counts[b] = 0
	var stat_max := {"goals": [0, ""], "disposals": [0, ""], "score": [0, ""]}
	var t0 := Time.get_ticks_msec()
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		var order := codes.duplicate()
		order.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		var rank := {}
		for i in range(order.size()):
			rank[str(order[i])] = i + 1
		var strongest := str(order[0])
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		while not season.is_regular_done():
			var rnd: Array = season.fixture[season.round_index]
			var played := []
			for i in range(rnd.size()):
				var fx: Dictionary = rnd[i]
				var seed := season.next_seed(i)
				var sim: MatchSim = season.match_sim(str(fx["home"]), str(fx["away"]), seed)
				if variant in ["syn", "all"]:
					sim.synergies = [[], []]
				if variant in ["momentum", "all"]:
					sim.momentum_edge = 0.0
				if variant in ["form", "all"]:
					sim.form = [0.0, 0.0]
				var fh := float(sim.form[0])
				var fa := float(sim.form[1])
				var res := sim.run()
				played.append(res)
				var margin := int(res["score"][0]) - int(res["score"][1])
				var m := {"d": int(d), "h": str(fx["home"]), "a": str(fx["away"]), "seed": seed,
						"fh": fh, "fa": fa, "margin": margin,
						"gap": absi(int(rank[str(fx["home"])]) - int(rank[str(fx["away"])])),
						"strongest": strongest in [str(fx["home"]), str(fx["away"])]}
				all.append(m)
				for b in BANDS:
					if absi(margin) >= b:
						counts[b] += 1
						if m["strongest"]:
							strong_counts[b] += 1
				if m["strongest"]:
					strong_n += 1
				for side in range(2):
					var sc := int(res["score"][side])
					if sc > int(stat_max["score"][0]):
						stat_max["score"] = [sc, "%s %d (league %d)" % [[fx["home"], fx["away"]][side], sc, d]]
				for id in res.get("players", {}):
					var ps: Dictionary = res["players"][id]
					for k in ["goals", "disposals"]:
						var v := int(float(ps.get(k, 0.0)))
						if v > int(stat_max[k][0]):
							stat_max[k] = [v, "%d (%s, league %d)" % [v, GameDB.player_display_name_by_id(str(id), str(id)), d]]
			for res in played:
				res["round"] = season.round_index + 1
				season.record_regular(res)
			season.results.append(played)
			season.round_index += 1
			season.recalc_ladder()
		print("league %d done (%d s)" % [int(d), (Time.get_ticks_msec() - t0) / 1000])
	var n := all.size()
	print("")
	print("## Frequency (variant %s): %d home-and-away matches, %d leagues" % [variant, n, drafts.size()])
	var line := []
	for b in BANDS:
		line.append("%d+ %.2f%% (%d)" % [b, 100.0 * counts[b] / n, counts[b]])
	print("all matches: " + ", ".join(line))
	line = []
	for b in BANDS:
		line.append("%d+ %.2f%% (%d)" % [b, 100.0 * strong_counts[b] / maxf(1, strong_n), strong_counts[b]])
	print("strongest list's matches (%d): %s" % [strong_n, ", ".join(line)])
	for g in [[0, 4], [5, 9], [10, 17]]:
		var gn := 0
		var g80 := 0
		var g100 := 0
		for m in all:
			if int(m["gap"]) >= g[0] and int(m["gap"]) <= g[1]:
				gn += 1
				if absi(int(m["margin"])) >= 80:
					g80 += 1
				if absi(int(m["margin"])) >= 100:
					g100 += 1
		print("strength-rank gap %d-%d: %d matches, 80+ %.2f%%, 100+ %.2f%%" % [g[0], g[1], gn, 100.0 * g80 / maxf(1, gn), 100.0 * g100 / maxf(1, gn)])
	print("biggest team score %s; most goals %s; most disposals %s" % [stat_max["score"][1], stat_max["goals"][1], stat_max["disposals"][1]])
	var mags := []
	for m in all:
		mags.append(absi(int(m["margin"])))
	mags.sort()
	var tot := 0
	for x in mags:
		tot += x
	print("mean margin %.1f; p90 %d; p99 %d; max %d" % [float(tot) / n, mags[int(0.9 * n)], mags[int(0.99 * n)], mags[n - 1]])
