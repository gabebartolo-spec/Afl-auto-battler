extends RefCounted
## Coleman / goalkicker plausibility (roadmap §1.11). Drafted leagues, one
## home-and-away season each (the Coleman counts the home-and-away season
## only), through Season.play_round -> MatchSim like Sim round. Who leads
## the goalkicking, and does a credible scoring profile or a clear
## opportunity explain it?
##
## "Source" is the player's real 2026 season in the shipped data (gl / gm).
## godot --headless --path . --script tools/audit/run_audit.gd -- coleman_impl

const DRAFTS := [41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52]
const MIN_GAMES := 10

var rows := []          # every player-season with >= MIN_GAMES
var leaders := []       # per season: the top 5


func _name(p: Dictionary) -> String:
	return "%s %s" % [str(p.get("first", "")), str(p.get("last", ""))]


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


func _ranks(xs: Array) -> Array:
	var idx := range(xs.size())
	idx.sort_custom(func(a, b): return xs[a] < xs[b])
	var r := []
	r.resize(xs.size())
	for k in range(idx.size()):
		r[idx[k]] = float(k)
	return r


func _spearman(xs: Array, ys: Array) -> float:
	return _pearson(_ranks(xs), _ranks(ys))


func _season(draft_seed: int, lb) -> void:
	var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
	var codes: Array = lb.clubs()
	var season := Season.new(codes, lists, draft_seed * 7 + 1)
	var by_id := {}
	for c in codes:
		for p in lists[c]:
			by_id[str(p["id"])] = {"p": p, "club": str(c)}
	var goals := {}
	var games := {}
	var team_goals := {}
	while not season.is_regular_done():
		for res in season.play_round():
			var roster: Array = res.get("roster", [])
			var stats: Dictionary = res.get("players", {})
			var sides := [str(res["home"]), str(res["away"])]
			for side in range(2):
				team_goals[sides[side]] = int(team_goals.get(sides[side], 0)) + int(res["goals"][side])
				if side >= roster.size():
					continue
				for r in roster[side]:
					var id := str(r["id"]) if r is Dictionary else str(r)
					games[id] = int(games.get(id, 0)) + 1
					goals[id] = int(goals.get(id, 0)) + int(float((stats.get(id, {}) as Dictionary).get("goals", 0.0)))
	var season_rows := []
	for id in goals:
		if not by_id.has(id) or int(games[id]) < MIN_GAMES:
			continue
		var p: Dictionary = by_id[id]["p"]
		var club := str(by_id[id]["club"])
		var src_gm := float(p.get("gm", 0.0))
		var row := {
			"draft": draft_seed, "name": _name(p), "club": club, "role": str(p.get("role", "")),
			"goals": int(goals[id]), "games": int(games[id]),
			"gpg": float(goals[id]) / float(games[id]),
			"src_gpg": float(p.get("gl", 0.0)) / src_gm if src_gm > 0 else -1.0,
			"src_gm": src_gm,
			"gk": float(p["attr"].get("goalkicking", 0.0)), "acc": float(p["attr"].get("accuracy", 0.0)),
			"mk": float(p["attr"].get("marking", 0.0)), "ovr": int(p.get("overall", 0)),
			"share": float(goals[id]) / maxf(1.0, float(team_goals.get(club, 0))),
		}
		season_rows.append(row)
		rows.append(row)
	season_rows.sort_custom(func(a, b): return int(a["goals"]) > int(b["goals"]))
	leaders.append(season_rows.slice(0, 5))


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var t0 := Time.get_ticks_msec()
	for d in DRAFTS:
		_season(d, lb)
		print("draft %d done (%d s)" % [d, (Time.get_ticks_msec() - t0) / 1000])
	print("")
	print("## Coleman (home and away) by season")
	print("| league | leader | club | role | goals | games | per game | source per game (games) | goalkicking / accuracy / marking | OVR | share of club goals | 2nd | 3rd |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var win_goals := []
	for top in leaders:
		var w: Dictionary = top[0]
		win_goals.append(int(w["goals"]))
		print("| %d | %s | %s | %s | %d | %d | %.2f | %s | %.0f / %.0f / %.0f | %d | %.0f%% | %s %d | %s %d |" % [
				w["draft"], w["name"], w["club"], w["role"], w["goals"], w["games"], w["gpg"],
				("%.2f (%d)" % [w["src_gpg"], int(w["src_gm"])]) if float(w["src_gpg"]) >= 0 else "no 2026 games",
				w["gk"], w["acc"], w["mk"], w["ovr"], 100.0 * float(w["share"]),
				top[1]["name"], top[1]["goals"], top[2]["name"], top[2]["goals"]])
	win_goals.sort()
	var tot := 0
	for g in win_goals:
		tot += g
	print("")
	print("Coleman tally: mean %.1f, min %d, median %d, max %d" % [float(tot) / win_goals.size(),
			win_goals[0], win_goals[win_goals.size() / 2], win_goals[win_goals.size() - 1]])

	# Top-5 finishers' profiles against all forwards.
	var top_src := []
	var top_gk := []
	for top in leaders:
		for r in top:
			if float(r["src_gpg"]) >= 0:
				top_src.append(float(r["src_gpg"]))
			top_gk.append(float(r["gk"]))
	var fwd_src := []
	var fwd_gk := []
	var fwd_gpg := []
	var fwd_gpg_s := []
	for r in rows:
		if str(r["role"]) != "FWD":
			continue
		fwd_gk.append(float(r["gk"]))
		fwd_gpg.append(float(r["gpg"]))
		if float(r["src_gpg"]) >= 0 and float(r["src_gm"]) >= 8:
			fwd_src.append(float(r["src_gpg"]))
			fwd_gpg_s.append(float(r["gpg"]))
	print("")
	print("Forwards with %d+ games: %d player-seasons" % [MIN_GAMES, fwd_gk.size()])
	print("  goals per game vs goalkicking attribute: Spearman %.2f" % _spearman(fwd_gk, fwd_gpg))
	print("  goals per game vs real 2026 goals per game (8+ real games, n=%d): Spearman %.2f, Pearson %.2f" % [
			fwd_src.size(), _spearman(fwd_src, fwd_gpg_s), _pearson(fwd_src, fwd_gpg_s)])
	var mean := func(a: Array) -> float:
		var s := 0.0
		for x in a:
			s += x
		return s / maxf(1.0, a.size())
	print("  top-5 finishers: real goals per game %.2f (all forwards %.2f); goalkicking %.1f (all forwards %.1f)" % [
			mean.call(top_src), mean.call(fwd_src), mean.call(top_gk), mean.call(fwd_gk)])

	# Middling forwards becoming spearheads, and strong source scorers held back.
	var middling_60 := []
	var strong_held := 0
	var strong := 0
	for r in rows:
		if float(r["src_gpg"]) >= 0 and float(r["src_gpg"]) < 1.0 and float(r["src_gm"]) >= 8 and int(r["goals"]) >= 50:
			middling_60.append("%s (%d: %d goals, real %.2f/g)" % [r["name"], r["draft"], r["goals"], r["src_gpg"]])
		if float(r["src_gpg"]) >= 2.0 and float(r["src_gm"]) >= 8:
			strong += 1
			if float(r["gpg"]) < 1.0:
				strong_held += 1
	print("")
	print("50+ goal seasons from players under 1.0 real goals a game (8+ real games): %d" % middling_60.size())
	for s in middling_60:
		print("  - %s" % s)
	print("Real 2.0+ goals-a-game scorers kicking under 1.0 a game: %d of %d player-seasons" % [strong_held, strong])

	# Distribution of season goal tallies.
	var bands := {"60+": 0, "50-59": 0, "40-49": 0, "30-39": 0}
	for r in rows:
		var g := int(r["goals"])
		if g >= 60: bands["60+"] += 1
		elif g >= 50: bands["50-59"] += 1
		elif g >= 40: bands["40-49"] += 1
		elif g >= 30: bands["30-39"] += 1
	print("")
	print("Season tallies per league season: 60+ %.2f, 50-59 %.2f, 40-49 %.2f, 30-39 %.2f" % [
			float(bands["60+"]) / DRAFTS.size(), float(bands["50-59"]) / DRAFTS.size(),
			float(bands["40-49"]) / DRAFTS.size(), float(bands["30-39"]) / DRAFTS.size()])
