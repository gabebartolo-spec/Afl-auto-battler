extends RefCounted
## Free kicks (ARD-M3-007 "Contextual free kicks", BALANCE-GATED): measurement
## only. Drafted leagues, one home-and-away season each through
## Season.play_round (Sim round). Compares against real 2026 AFL from the
## shipped player data (ff = frees for, fa = frees against, per player-game):
##  - league rate: frees per team per match;
##  - the cause mix (team stats "free_<cause>", and the boundary frees);
##  - per player-game by role, for and against;
##  - does a player's real frees-against rate carry into the sim (Spearman),
##    and how much does the discipline attribute drive it.
## Env: FK_DRAFTS (default 21..28).
## godot --headless --path . --script tools/audit/run_audit.gd -- freekick_impl


static func _env_ints(key: String, fallback: Array) -> Array:
	var v := OS.get_environment(key)
	if v == "":
		return fallback
	var out := []
	for part in v.split(","):
		out.append(int(part))
	return out


func _ranks(xs: Array) -> Array:
	var idx := range(xs.size())
	idx.sort_custom(func(a, b): return xs[a] < xs[b])
	var r := []
	r.resize(xs.size())
	for k in range(idx.size()):
		r[idx[k]] = float(k)
	return r


func _pearson(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 3:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in range(n):
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(n):
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(1e-9, sxx * syy))


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var drafts := _env_ints("FK_DRAFTS", [21, 22, 23, 24, 25, 26, 27, 28])
	var codes: Array = lb.clubs()
	# Real 2026: per role, from the shipped data (role as the game derives it).
	var real := {}
	var real_team_ff := 0.0
	var real_team_games := 0.0
	for c in codes:
		for p in GameDB.club_list(str(c)):
			var gm := float(p.get("gm", 0.0))
			if gm <= 0:
				continue
			var role := str(p.get("role", ""))
			if not real.has(role):
				real[role] = [0.0, 0.0, 0.0]   # ff, fa, games
			real[role][0] += float(p.get("ff", 0.0))
			real[role][1] += float(p.get("fa", 0.0))
			real[role][2] += gm
			real_team_ff += float(p.get("ff", 0.0))
	# Real team-games: each club's games = its most-played player's games
	# (about 23-26), summed over clubs.
	for c in codes:
		var mx := 0.0
		for p in GameDB.club_list(str(c)):
			mx = maxf(mx, float(p.get("gm", 0.0)))
		real_team_games += mx
	var sim := {}
	var causes := {}
	var team_games := 0
	var team_ff := 0.0
	var by_player := {}   # id -> [fa, games]
	var info := {}        # id -> player
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		for c in codes:
			for p in lists[c]:
				info[str(p["id"])] = p
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		while not season.is_regular_done():
			for res in season.play_round():
				var team: Array = res.get("team", [])
				for side in range(2):
					team_games += 1
					var t: Dictionary = team[side]
					team_ff += float(t.get("frees_for", 0.0))
					for k in t:
						if str(k).begins_with("free_"):
							causes[str(k).trim_prefix("free_")] = float(causes.get(str(k).trim_prefix("free_"), 0.0)) + float(t[k])
				var stats: Dictionary = res.get("players", {})
				var roster: Array = res.get("roster", [])
				for side in range(mini(2, roster.size())):
					for r in roster[side]:
						var id := str(r["id"])
						var p = info.get(id)
						if p == null:
							continue
						var role := str(p.get("role", ""))
						var ps: Dictionary = stats.get(id, {})
						if not sim.has(role):
							sim[role] = [0.0, 0.0, 0.0]
						sim[role][0] += float(ps.get("frees_for", 0.0))
						sim[role][1] += float(ps.get("frees_against", 0.0))
						sim[role][2] += 1.0
						if not by_player.has(id):
							by_player[id] = [0.0, 0]
						by_player[id][0] += float(ps.get("frees_against", 0.0))
						by_player[id][1] += 1
		print("league %d done" % int(d))
	print("")
	print("## Frees per team per match: sim %.2f (%d team-games), real 2026 %.2f" % [
			team_ff / maxf(1, team_games), team_games, real_team_ff / maxf(1.0, real_team_games)])
	var total := 0.0
	for k in causes:
		total += float(causes[k])
	var keys := causes.keys()
	keys.sort_custom(func(a, b): return float(causes[a]) > float(causes[b]))
	print("cause mix (share of recorded causes, per team per match):")
	for k in keys:
		print("  %s: %.1f%% (%.2f)" % [k, 100.0 * float(causes[k]) / maxf(1.0, total), float(causes[k]) / maxf(1, team_games)])
	print("recorded causes cover %.0f%% of frees for (the rest are boundary frees and any uncaused)" % (100.0 * total / maxf(1.0, team_ff)))
	print("")
	print("| role | sim for / against a player-game | real for / against a player-game |")
	print("|---|---|---|")
	for role in ["MID", "FWD", "DEF", "RUCK"]:
		var s: Array = sim.get(role, [0.0, 0.0, 1.0])
		var r: Array = real.get(role, [0.0, 0.0, 1.0])
		print("| %s | %.2f / %.2f | %.2f / %.2f |" % [role, s[0] / s[2], s[1] / s[2], r[0] / r[2], r[1] / r[2]])
	# Who gives frees away: sim against real, per player (10+ sim games, 8+ real).
	var sim_fa := []
	var real_fa := []
	var disc := []
	for id in by_player:
		var g := int(by_player[id][1])
		var p: Dictionary = info[id]
		var rg := float(p.get("gm", 0.0))
		if g < 10 or rg < 8:
			continue
		sim_fa.append(float(by_player[id][0]) / g)
		real_fa.append(float(p.get("fa", 0.0)) / rg)
		disc.append(float((p.get("attr", {}) as Dictionary).get("discipline", 50.0)))
	print("")
	print("frees against per game, sim vs real 2026 (n=%d players): Spearman %.2f, Pearson %.2f" % [
			sim_fa.size(), _pearson(_ranks(sim_fa), _ranks(real_fa)), _pearson(sim_fa, real_fa)])
	print("frees against per game vs discipline attribute (sim): Spearman %.2f" % _pearson(_ranks(sim_fa), _ranks(disc)))
