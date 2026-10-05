extends RefCounted
## Key forward v key defender (roadmap §1.11, "Key-forward vs key-defender
## balance audit"). Drafted leagues, strength neighbours paired, autosim with
## the default match-ups (a coach's best key defender on their best key
## forward). Reads MatchSim.duel_log: every named marking contest, who was
## on whom, whether the forward marked, and whether a goal came of it.
##
## Tiers are by the engine's own aerial scores (Matchups.forward_air /
## defender_air), split into thirds over everyone who appeared in a duel:
## elite (top third), good, average.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- kf_kd_impl

const DRAFTS := [61, 62, 63, 64]
const SEEDS_PER_PAIR := 12

var duels := []        # [fwd id, def id, marked, goal]
var games := []        # per key forward per match: [fwd id, def id, goals, marks, contests]
var players := {}      # id -> player dict
var named_share := []  # per side per match: named contests / inside 50s


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var t0 := Time.get_ticks_msec()
	for d in DRAFTS:
		var lists: Dictionary = lb.drafted_lists(d)["lists"]
		var codes: Array = lb.clubs()
		for c in codes:
			for p in lists[c]:
				players[str(p["id"])] = p
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			var h := str(codes[i])
			var w := str(codes[i + 1])
			for k in range(SEEDS_PER_PAIR):
				var seed: int = int(d) * 100003 + i * 1009 + k * 7919 + 29
				for flip in [false, true]:
					var a := h if not flip else w
					var b := w if not flip else h
					var sa := Squad.new(a, lists[a], true, a)
					var sb := Squad.new(b, lists[b], false, b)
					sa.ai_plans = true
					sb.ai_plans = true
					var sim := MatchSim.new(sa, sb, seed + (1 if flip else 0))
					var res := sim.run()
					_tally(sim, res)
		print("draft %d done (%d s)" % [d, (Time.get_ticks_msec() - t0) / 1000])
	_report()


func _tally(sim: MatchSim, res: Dictionary) -> void:
	var per_side_named := [0, 0]
	var by_pair := {}
	for fid in sim.duel_log:
		var e: Dictionary = sim.duel_log[fid]
		for c in e["contests"]:
			duels.append([str(fid), str(c[1]), bool(c[2]), bool(c[3])])
			per_side_named[int(e["side"])] += 1
			var key := "%s|%s" % [fid, c[1]]
			if not by_pair.has(key):
				by_pair[key] = [str(fid), str(c[1]), 0, 0, 0]
			by_pair[key][4] += 1
			if bool(c[2]):
				by_pair[key][3] += 1
	var stats: Dictionary = res.get("players", {})
	for key in by_pair:
		var row: Array = by_pair[key]
		row[2] = int(float((stats.get(row[0], {}) as Dictionary).get("goals", 0.0)))
		games.append(row)
	var team: Array = res.get("team", [{}, {}])
	for side in range(2):
		var i50 := float((team[side] as Dictionary).get("inside50", 0.0)) if side < team.size() else 0.0
		if i50 > 0:
			named_share.append(per_side_named[side] / i50)


func _tiers(ids: Array, score: Callable) -> Dictionary:
	var vals := []
	for id in ids:
		vals.append([float(score.call(players[id])), id])
	vals.sort_custom(func(x, y): return x[0] > y[0])
	var out := {}
	for i in range(vals.size()):
		out[vals[i][1]] = "elite" if i < vals.size() / 3 else ("good" if i < 2 * vals.size() / 3 else "average")
	return out


func _report() -> void:
	var fids := {}
	var dids := {}
	for d in duels:
		fids[d[0]] = true
		dids[d[1]] = true
	var ft := _tiers(fids.keys(), Matchups.forward_air)
	var dt := _tiers(dids.keys(), Matchups.defender_air)
	var tiers := ["elite", "good", "average"]
	var cell := {}
	for a in tiers:
		for b in tiers:
			cell[a + "|" + b] = [0, 0, 0]   # contests, marks, goals
	for d in duels:
		var c: Array = cell[ft[d[0]] + "|" + dt[d[1]]]
		c[0] += 1
		if d[2]:
			c[1] += 1
		if d[3]:
			c[2] += 1
	var total := [0, 0, 0]
	for k in cell:
		for j in range(3):
			total[j] += cell[k][j]
	print("")
	print("named contests: %d; forwards %d, defenders %d" % [duels.size(), fids.size(), dids.size()])
	var s := 0.0
	for x in named_share:
		s += x
	print("named contests per side per match as a share of inside 50s: %.1f%%" % (100.0 * s / maxf(1.0, named_share.size())))
	print("overall forward mark rate %.1f%%, goal from a contest %.1f%%" % [
			100.0 * total[1] / maxf(1, total[0]), 100.0 * total[2] / maxf(1, total[0])])
	print("")
	print("## Forward mark rate in the named contest (contests): forward tier down, defender tier across")
	print("| forward \\ defender | elite | good | average |")
	print("|---|---|---|---|")
	for a in tiers:
		var line := "| %s |" % a
		for b in tiers:
			var c: Array = cell[a + "|" + b]
			line += " %.1f%% (%d) |" % [100.0 * c[1] / maxf(1, c[0]), c[0]]
		print(line)
	print("")
	print("## Goal from the contest")
	print("| forward \\ defender | elite | good | average |")
	print("|---|---|---|---|")
	for a in tiers:
		var line := "| %s |" % a
		for b in tiers:
			var c: Array = cell[a + "|" + b]
			line += " %.1f%% |" % (100.0 * c[2] / maxf(1, c[0]))
		print(line)
	# Whole-match output of a key forward by the tier of the man on him.
	var g := {}
	for a in tiers:
		for b in tiers:
			g[a + "|" + b] = [0, 0, 0, 0]   # matches, goals, marks, contests
	for row in games:
		if not ft.has(row[0]) or not dt.has(row[1]):
			continue
		var c: Array = g[ft[row[0]] + "|" + dt[row[1]]]
		c[0] += 1
		c[1] += row[2]
		c[2] += row[3]
		c[3] += row[4]
	print("")
	print("## A key forward's whole match by the defender on him: goals a match (named contests a match)")
	print("| forward \\ defender | elite | good | average |")
	print("|---|---|---|---|")
	for a in tiers:
		var line := "| %s |" % a
		for b in tiers:
			var c: Array = g[a + "|" + b]
			line += " %.2f (%.1f) n=%d |" % [float(c[1]) / maxf(1, c[0]), float(c[3]) / maxf(1, c[0]), c[0]]
		print(line)
	# What the full-time match-up line says (MatchNotes._duel_line, one
	# defender all match): >= 60% marked "beat", <= 40% "held", else even.
	var v := {}
	for a in tiers:
		for b in tiers:
			v[a + "|" + b] = [0, 0, 0, 0]   # beat, even, held, n
	for row in games:
		if not ft.has(row[0]) or not dt.has(row[1]) or int(row[4]) == 0:
			continue
		var c: Array = v[ft[row[0]] + "|" + dt[row[1]]]
		var r := float(row[3]) / float(row[4])
		c[0 if r >= 0.60 else (2 if r <= 0.40 else 1)] += 1
		c[3] += 1
	print("")
	print("## Full-time verdict: forward beat / even / defender held")
	print("| forward \\ defender | elite | good | average |")
	print("|---|---|---|---|")
	for a in tiers:
		var line := "| %s |" % a
		for b in tiers:
			var c: Array = v[a + "|" + b]
			var n := maxf(1, c[3])
			line += " %.0f / %.0f / %.0f |" % [100.0 * c[0] / n, 100.0 * c[1] / n, 100.0 * c[2] / n]
		print(line)
	# Who the elite are.
	var top_f := []
	for id in ft:
		if ft[id] == "elite":
			top_f.append([Matchups.forward_air(players[id]), id])
	top_f.sort_custom(func(x, y): return x[0] > y[0])
	var top_d := []
	for id in dt:
		if dt[id] == "elite":
			top_d.append([Matchups.defender_air(players[id]), id])
	top_d.sort_custom(func(x, y): return x[0] > y[0])
	var nm := func(id): return "%s %s %.0f" % [players[id].get("first", ""), players[id].get("last", ""), 0.0]
	var fl := []
	for x in top_f.slice(0, 6):
		fl.append("%s %s (%.0f)" % [players[x[1]].get("first", ""), players[x[1]].get("last", ""), x[0]])
	var dl := []
	for x in top_d.slice(0, 6):
		dl.append("%s %s (%.0f)" % [players[x[1]].get("first", ""), players[x[1]].get("last", ""), x[0]])
	print("")
	print("top forwards by air score: %s" % ", ".join(fl))
	print("top defenders by air score: %s" % ", ".join(dl))
	var fa := []
	var da := []
	for id in fids:
		fa.append(Matchups.forward_air(players[id]))
	for id in dids:
		da.append(Matchups.defender_air(players[id]))
	fa.sort()
	da.sort()
	print("forward air: median %.1f, top-third cut %.1f; defender air: median %.1f, top-third cut %.1f (DUEL_CENTRE %.0f)" % [
			fa[fa.size() / 2], fa[2 * fa.size() / 3], da[da.size() / 2], da[2 * da.size() / 3], Matchups.DUEL_CENTRE])
