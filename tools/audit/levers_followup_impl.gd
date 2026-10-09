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
##   fire_up  Fire them up. The copy: "A lift at the contest while you are
##            chasing the game". Reads quarters 2-4 that the home side began
##            behind in both arms, so the two sides of a pair are chasing.
##   seeds    per pairing (default 40); six pairings

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]


func _play(h: String, a: String, seed: int, arm: String) -> Dictionary:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
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
	if arm == "loose":
		sim.set_interceptor(0, loose, false)
	var res: Dictionary = sim.run()
	res["loose_id"] = loose
	return res


func _n(d: Dictionary, k: String) -> float:
	return float(d.get(k, 0))


func _loose_row(res: Dictionary) -> Dictionary:
	var me: Dictionary = (res["players"] as Dictionary).get(str(res["loose_id"]), {})
	var team: Dictionary = (res["team"] as Array)[0]
	var opp: Dictionary = (res["team"] as Array)[1]
	var sc: Array = res["score"]
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"set": 1.0 if str((res["interceptor"] as Array)[0]) == str(res["loose_id"]) else 0.0,
		"his_intercepts": _n(me, "intercepts") + _n(me, "intercept_marks"),
		"his_marks": _n(me, "marks"),
		"his_spoils": _n(me, "spoils"),
		"his_roam_contests": _n(me, "roam_contests"),
		"his_roam_wins": _n(me, "roam_wins"),
		"his_roam_losses": _n(me, "roam_losses"),
		"team_intercepts": _n(team, "intercepts") + _n(team, "intercept_marks"),
		"team_spoils": _n(team, "spoils"),
		"conceded": float(int(sc[1])),
		"their_goals": float(int((res["goals"] as Array)[1])),
		"their_marks": _n(opp, "marks")}


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
	var seeds := int(args[2]) if args.size() > 2 else 40
	var diffs := {}
	var arm_sums := {}
	var pairs := 0
	for pr in PAIRS:
		for s in range(seeds):
			var base := _play(pr[0], pr[1], 7000 + s, "base")
			var arm := _play(pr[0], pr[1], 7000 + s, mode)
			var rows := []
			if mode == "loose":
				rows.append([_loose_row(base), _loose_row(arm)])
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
