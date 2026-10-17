extends RefCounted
## Lever-truth audit follow-ups (docs/research/LEVER_TRUTH_AUDIT.md). Paired
## like levers_pair_impl: the same matches and seeds played twice, the home
## side's baseline (Balanced, Stay composed, no loose defender) against one
## call changed. Measurement only: no rule changes.
##
## Args after the impl name: mode seeds
##   loose    name the home side's best intercepting defender as the loose
##            man. The copy: "He leaves his direct man to attack aerial
##            balls. Another defender covers where possible; if he flies and
##            loses, space opens behind him." Reads his own game, the team's
##            and what the other side kicks.
##   loose_best / loose_median / loose_worst  the best, middle and worst
##            reader of the ball among the home defenders named loose (the
##            loose-man rework's three tiers; his_score is his interceptor
##            score).
##   loose_pinNN  the best reader named loose with his read of the ball pinned
##            to interceptor score NN in both arms (intercept, marking and
##            pressure set to it), to find where the call stops paying.
##   loose_free  the same call on the best intercepting defender who has no
##            key forward of his own (Matchups.defaults), so nobody is freed.
##   matchup  Key match-ups: their best key forward on your weakest aerial
##            defender, against the default (your best key defender on him).
##   fire_up  Fire them up. The copy: "A lift at the contest while you are
##            chasing the game". Reads quarters 2-4 that the home side began
##            behind in both arms, so the two sides of a pair are chasing.
##   dual     Dual ruck. The copy: "Auto-pick names a second ruck on the
##            bench." Both arms make the call explicitly (off, then on), so
##            the AI's own dual-ruck rule never decides the baseline.
##   seeds    per pairing (default 40); six pairings

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]


func _play(h: String, a: String, seed: int, arm: String) -> Dictionary:
	var sel := {}
	if arm.begins_with("dual"):
		sel = {"DUAL_RUCK": arm == "dual"}
	var home := Squad.new(h, GameDB.club_list(h), true, h, sel)
	# loose_pinNN: pin the best reader's game on the ground (the
	# ratings are shared with the club lists: put back after the match).
	var pinned := {}
	var pin_p: Dictionary = {}
	if _mode.begins_with("loose_pin"):
		var target := float(_mode.trim_prefix("loose_pin"))
		var top_s := -1.0
		for p in home.ground:
			if str(p.get("role", "")) == "DEF" and Matchups.interceptor_score(p) > top_s:
				top_s = Matchups.interceptor_score(p)
				pin_p = p
		pinned = (pin_p["attr"] as Dictionary).duplicate()
		var bonus := Matchups.interceptor_score(pin_p) - (0.55 * float(pinned.get("intercept", 0))
				+ 0.30 * float(pinned.get("marking", 0)) + 0.15 * float(pinned.get("pressure", 0)))
		for k in ["intercept", "marking", "pressure"]:
			(pin_p["attr"] as Dictionary)[k] = int(round(target - bonus))
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	away.ai_plans = true
	var t := {"gameplan": "balanced", "pep": "fire_up" if arm == "fire_up" else "steady"}
	var sim := MatchSim.new(home, away, seed)
	sim.set_tactics(0, t)
	# The same man in both arms: the best intercepting defender on the ground.
	var loose := ""
	var top := -1.0
	for p in home.ground:
		if str(p.get("role", "")) == "DEF" and Matchups.interceptor_score(p) > top:
			top = Matchups.interceptor_score(p)
			loose = str(p["id"])
	# The away forward he stands on by default (Matchups.defaults), if any.
	var freed := ""
	for fid in sim.duels[0]:
		if str(sim.duels[0][fid]) == loose:
			freed = str(fid)
	if arm == "loose_free":
		# The best reader of the ball among defenders with no key forward of
		# their own: the man a coach can free without leaving one alone.
		var minding := {}
		for fid in sim.duels[0]:
			minding[str(sim.duels[0][fid])] = true
		var best := -1.0
		for p in home.ground:
			if str(p.get("role", "")) == "DEF" and not minding.has(str(p["id"])) 					and Matchups.interceptor_score(p) > best:
				best = Matchups.interceptor_score(p)
				loose = str(p["id"])
		freed = ""
	if not pin_p.is_empty():
		loose = str(pin_p["id"])
		freed = ""
		for fid in sim.duels[0]:
			if str(sim.duels[0][fid]) == loose:
				freed = str(fid)
	if _mode in ["loose_best", "loose_median", "loose_worst"]:
		# Tiers: the best, middle and worst reader of the ball among the
		# defenders on the ground, named loose whatever his rating.
		var defs: Array = Matchups.interceptor_candidates(home.ground)
		var pick: Dictionary = defs[0] if _mode == "loose_best" else (defs[defs.size() / 2] if _mode == "loose_median" else defs[defs.size() - 1])
		loose = str(pick["id"])
		freed = ""
		for fid in sim.duels[0]:
			if str(sim.duels[0][fid]) == loose:
				freed = str(fid)
	# Their best key forward (Matchups.key_forwards, first) and who minds him.
	var kfs := Matchups.key_forwards(away.ground)
	var star := str((kfs[0] as Dictionary)["id"]) if not kfs.is_empty() else ""
	if arm == "matchup" and star != "":
		var weakest := ""
		var low := 999.0
		for p in Matchups.defenders(home.ground):
			if Matchups.defender_air(p) < low:
				low = Matchups.defender_air(p)
				weakest = str(p["id"])
		sim.set_matchup(0, star, weakest, false)
	matchup_star = star
	if arm.begins_with("loose"):
		sim.set_interceptor(0, loose, false)
	res_freed = freed
	freed_covered = freed != "" and (sim.duels[0] as Dictionary).has(freed)
	var rucks_before := (home.ground + home.bench).filter(func(p): return str(p.get("role", "")) == "RUCK").map(func(p): return str(p["id"]))
	# The ruck who starts in the ruck spot (the ground changes at interchanges).
	var ruck_first := ""
	for p in home.ground:
		if str(p.get("role", "")) == "RUCK":
			ruck_first = str(p["id"])
	var res: Dictionary = sim.run()
	res["rucks_before"] = rucks_before
	res["loose_id"] = loose
	res["loose_score"] = Matchups.interceptor_score(_find(home, loose)) if loose != "" else 0.0
	res["freed"] = res_freed
	res["freed_covered"] = freed_covered
	res["star"] = matchup_star
	res["home_rucks"] = (home.ground + home.bench).filter(func(p): return str(p.get("role", "")) == "RUCK").map(func(p): return str(p["id"]))
	res["home_ruck_first"] = ruck_first
	if not pin_p.is_empty():
		(pin_p["attr"] as Dictionary).merge(pinned, true)
	return res


var res_freed := ""
var matchup_star := ""


func _find(sq: Squad, id: String) -> Dictionary:
	for p in sq.ground + sq.bench:
		if str(p["id"]) == id:
			return p
	return {}
var freed_covered := false


func _n(d: Dictionary, k: String) -> float:
	return float(d.get(k, 0))


var _his_score := 0.0
var _mode := ""


func _loose_row(res: Dictionary) -> Dictionary:
	var me: Dictionary = (res["players"] as Dictionary).get(str(res["loose_id"]), {})
	_his_score = float(res.get("loose_score", 0.0))
	var team: Dictionary = (res["team"] as Array)[0]
	var opp: Dictionary = (res["team"] as Array)[1]
	var sc: Array = res["score"]
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"set": 1.0 if str((res["interceptor"] as Array)[0]) == str(res["loose_id"]) else 0.0,
		"his_intercepts": _n(me, "intercepts"),
		"his_intercept_marks": _n(me, "intercept_marks"),
		"his_duels": _duels(res, str(res["loose_id"])),
		"his_marks": _n(me, "marks"),
		"his_rebounds": _n(me, "rebounds"),
		"his_disposals": _n(me, "disposals"),
		"his_one_pct": _n(me, "one_percenters"),
		"his_time": float((res["exertion"] as Dictionary).get(str(res["loose_id"]), 0.0)),
		"his_spoils": _n(me, "spoils"),
		"his_roam_contests": _n(me, "roam_contests"),
		"his_roam_wins": _n(me, "roam_wins"),
		"his_roam_losses": _n(me, "roam_losses"),
		# Went for an entry but got there late (the space behind, no contest).
		"his_roam_late": _n(me, "roam_late"),
		"freed_has_man": 1.0 if str(res["freed"]) != "" else 0.0,
		"freed_still_covered": 1.0 if bool(res["freed_covered"]) else 0.0,
		"freed_goals": _n((res["players"] as Dictionary).get(str(res["freed"]), {}), "goals"),
		"freed_marks": _n((res["players"] as Dictionary).get(str(res["freed"]), {}), "marks"),
		"team_intercepts": _n(team, "intercepts"),
		"team_spoils": _n(team, "spoils"),
		"conceded": float(int(sc[1])),
		"their_goals": float(int((res["goals"] as Array)[1])),
		"their_marks": _n(opp, "marks"),
		"his_score": _his_score,
		# The AI's own loose man against us: same rule, other side.
		"ai_loose_set": 1.0 if str((res["interceptor"] as Array)[1]) != "" else 0.0,
		"ai_loose_intercepts": _n((res["players"] as Dictionary).get(str((res["interceptor"] as Array)[1]), {}), "intercepts")}


## His one-on-one contests as a forward's direct opponent (the duel log).
func _duels(res: Dictionary, id: String) -> float:
	var n := 0
	for fid in res["duels"]:
		var row: Dictionary = res["duels"][fid]
		if int(row.get("side", -1)) != 1:
			continue
		for c in row["contests"]:
			if str(c[1]) == id:
				n += 1
	return float(n)


func _matchup_row(res: Dictionary) -> Dictionary:
	var sc: Array = res["score"]
	var st: Dictionary = (res["players"] as Dictionary).get(str(res["star"]), {})
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"star_goals": _n(st, "goals"),
		"star_marks": _n(st, "marks"),
		"star_contested_marks": _n(st, "contested_marks"),
		"conceded": float(int(sc[1]))}


## Clearances and contested possessions in each quarter 2-4, with the score
## at its start: {q: {"behind": bool, "clearances": x, "contested": y}}.
func _dual_row(res: Dictionary) -> Dictionary:
	var team: Dictionary = (res["team"] as Array)[0]
	var sc: Array = res["score"]
	var first := str(res["home_ruck_first"])
	var players: Dictionary = res["players"]
	var others := 0.0
	for id in res["rucks_before"]:
		if str(id) != first:
			others += _n(players.get(str(id), {}), "hitouts")
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"rucks_in_23": float((res["rucks_before"] as Array).size()),
		"rucks_after_match": float((res["home_rucks"] as Array).size()),
		"hitouts": _n(team, "hitouts"),
		"first_ruck_hitouts": _n(players.get(first, {}), "hitouts"),
		"other_rucks_hitouts": others,
		"first_ruck_exertion": float((res["exertion"] as Dictionary).get(first, 0.0)),
		"clearances": _n(team, "clearances"),
		"contested": _n(team, "contested_possessions"),
		"scored": float(int(sc[0]))}


## Clearances and contested possessions in each quarter 2-4, with the score
## at its start: {q: {"behind": bool, "clearances": x, "contested": y}}.
func _quarters(res: Dictionary) -> Dictionary:
	var qt: Array = res["quarter_teams"]
	var out := {}
	for i in range(1, mini(4, qt.size())):
		var before: Dictionary = qt[i - 1]
		var after: Dictionary = qt[i]
		var s: Array = before["score"]
		var b: Dictionary = (before["team"] as Array)[0]
		var a: Dictionary = (after["team"] as Array)[0]
		var ob: Dictionary = (before["team"] as Array)[1]
		var oa: Dictionary = (after["team"] as Array)[1]
		var cl := _n(a, "clearances") - _n(b, "clearances")
		var ocl := _n(oa, "clearances") - _n(ob, "clearances")
		out[i + 1] = {"behind": int(s[0]) < int(s[1]),
			"clearances": cl,
			"clearance_share": cl / maxf(1.0, cl + ocl),
			"contested": _n(a, "contested_possessions") - _n(b, "contested_possessions"),
			"clangers": _n(a, "clangers") - _n(b, "clangers"),
			"points": float(int((after["score"] as Array)[0]) - int(s[0]))}
	return out


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1]) if args.size() > 1 else "loose"
	_mode = mode
	var seeds := int(args[2]) if args.size() > 2 else 40
	var diffs := {}
	var arm_sums := {}
	var pairs := 0
	for pr in PAIRS:
		for s in range(seeds):
			var base := _play(pr[0], pr[1], 7000 + s, "dual_base" if mode == "dual" else "base")
			var arm := _play(pr[0], pr[1], 7000 + s, mode)
			var rows := []
			if mode.begins_with("loose"):
				rows.append([_loose_row(base), _loose_row(arm)])
			elif mode == "dual":
				rows.append([_dual_row(base), _dual_row(arm)])
			elif mode == "matchup":
				rows.append([_matchup_row(base), _matchup_row(arm)])
			else:
				var qb := _quarters(base)
				var qa := _quarters(arm)
				for q in qb:
					if qa.has(q) and bool(qb[q]["behind"]) and bool(qa[q]["behind"]):
						rows.append([qb[q], qa[q]])
			for r in rows:
				pairs += 1
				for k in r[1]:
					if k == "behind":
						continue
					if not diffs.has(k):
						diffs[k] = []
						arm_sums[k] = 0.0
					(diffs[k] as Array).append(float(r[1][k]) - float(r[0][k]))
					arm_sums[k] = float(arm_sums[k]) + float(r[1][k])
	print("FOLLOWUP %s | %d pairs" % [mode, pairs])
	for k in diffs:
		print("FOLLOWUP %s | %s | arm mean %.3f | paired diff %s" % [mode, k,
				float(arm_sums[k]) / maxf(1.0, float((diffs[k] as Array).size())), _mean_se(diffs[k])])


func _mean_se(xs: Array) -> String:
	var n := float(xs.size())
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= maxf(1.0, n)
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	var se := sqrt(v / maxf(1.0, n - 1.0) / maxf(1.0, n))
	return "%+.3f ± %.3f" % [m, se]
