extends RefCounted
## Game plan fingerprints for the match view (director, 2026-10-11: "the
## oval only shows what the match really does"). Before a plan gets a shape on
## the oval, measure what it changes in the play itself: how high up the
## ground the ball lives, where the side wins it back and loses it, how often
## and where it applies pressure, kick length, kicks against handballs, how
## long its possessions run, stoppages, and how much of the ball its stars
## get. The same matches and seeds, played twice: the home side on Balanced,
## then on one plan; the away side picks its own plans (AI rules).
## Measurement only: no rule changes.
##
## Args after the impl name: arms seeds
##   arms   comma list (default all): plan_attacking, plan_defensive,
##          plan_contest, plan_controlled, plan_through_stars
##   seeds  per pairing (default 40); six pairings
## Field position: metres from the centre, positive toward the home side's
## attacking goal (MatchSim.fp), so higher = further up the ground for home.

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]
const ALL := ["plan_attacking", "plan_defensive", "plan_contest", "plan_controlled", "plan_through_stars"]
## Events where a side has the ball in hand.
const POSS := ["kick", "handball", "mark", "receive", "pass", "rebound"]
## Events after which the next possession is a restart, not a turnover.
const RESET := ["goal", "behind", "quarter", "ballup", "throwin", "final"]
const KEYS := ["margin", "territory", "win_back_fp", "win_backs", "lose_fp", "pressure_n", "pressure_fp",
		"kick_share", "kick_gain", "chain_len", "stoppages", "star_share",
		# The press pilot (2026-10-11): where we win it back and lock it in, and
		# what it costs when they get out (their kicks out of their back third).
		"win_back_fwd_share", "stoppages_fwd", "their_escape_gain", "their_press_broken",
		# Per zone, from the carrier's end (0 = their back third, our forward half).
		"z0_rolls", "z1_rolls", "z2_rolls", "z0_base", "z1_base", "z2_base", "z0_final", "z1_final", "z2_final",
		"z0_tackles", "z1_tackles", "z2_tackles", "z0_rushed", "z1_rushed", "z2_rushed",
		"z0_win_backs", "z1_win_backs", "z2_win_backs"]


func _play(h: String, a: String, seed: int, arm: String) -> Dictionary:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	away.ai_plans = true
	var t := {"gameplan": "balanced", "pep": "steady"}
	if arm.begins_with("plan_"):
		t["gameplan"] = arm.trim_prefix("plan_")
	var sim := MatchSim.new(home, away, seed)
	sim.set_tactics(0, t)
	var res: Dictionary = sim.run()
	var out := _fingerprint(res["events"])
	var sc: Array = res["score"]
	out["margin"] = [float(int(sc[0]) - int(sc[1])), 1.0]
	var players: Dictionary = res["players"]
	var stars := _top3(home.ground + home.bench)
	var star_disp := 0.0
	var own_disp := 0.0
	for p in home.ground + home.bench:
		var d := float((players.get(str(p["id"]), {}) as Dictionary).get("disposals", 0))
		own_disp += d
		if stars.has(str(p["id"])):
			star_disp += d
	out["star_share"] = [star_disp / maxf(1.0, own_disp), 1.0]
	out["their_press_broken"] = [float(((res["team"] as Array)[1] as Dictionary).get("press_broken", 0.0)), 1.0]
	var tm: Dictionary = (res["team"] as Array)[0]
	for z in range(3):
		var n := float(tm.get("pz_roll%d" % z, 0.0))
		out["z%d_rolls" % z] = [n, 1.0]
		out["z%d_base" % z] = [float(tm.get("pz_base%d" % z, 0.0)) / maxf(1.0, n), 1.0 if n > 0.0 else 0.0]
		out["z%d_final" % z] = [float(tm.get("pz_final%d" % z, 0.0)) / maxf(1.0, n), 1.0 if n > 0.0 else 0.0]
		out["z%d_tackles" % z] = [float(tm.get("pz_tackle%d" % z, 0.0)), 1.0]
		out["z%d_rushed" % z] = [float(tm.get("pz_rush%d" % z, 0.0)), 1.0]
	return out


## Per match: each key -> [value, weight]; weight 0 means no observation, and
## that match is left out of the key's paired mean.
func _fingerprint(events: Array) -> Dictionary:
	var terr := _Acc.new()
	var win_fp := _Acc.new()
	var lose_fp := _Acc.new()
	var press := _Acc.new()
	var gain := _Acc.new()
	var chains := _Acc.new()
	var kicks := 0.0
	var handballs := 0.0
	var stoppages := 0.0
	var stoppages_fwd := 0.0
	var wins_fwd := 0.0
	var win_z := [0.0, 0.0, 0.0]
	var esc := _Acc.new()
	var prev_side := -1
	var prev_kind := ""
	var prev_fp := 0.0
	var run := 0
	for e in events:
		var kind := str(e.get("kind", ""))
		var side := int(e.get("side", -1))
		var f := float(e.get("fp", 0.0))
		if kind in ["ballup", "throwin"]:
			stoppages += 1.0
			if f > 0.0:
				stoppages_fwd += 1.0
		if kind in ["pressure", "tackle"] and side == 0:
			press.add(f)
		if RESET.has(kind):
			if run > 0:
				chains.add(float(run))
			run = 0
			prev_side = -1
			prev_kind = ""
			continue
		if not POSS.has(kind) or side < 0:
			continue
		if side == 0:
			terr.add(f)
			if kind == "kick":
				kicks += 1.0
			elif kind == "handball":
				handballs += 1.0
			if prev_side == 1:
				win_fp.add(f)
				if f > 0.0:
					wins_fwd += 1.0
				win_z[0 if f > MatchSim.PRESS_ZONE_EDGE else (2 if f < -MatchSim.PRESS_ZONE_EDGE else 1)] += 1.0
			if prev_side == 0 and prev_kind == "kick":
				gain.add(f - prev_fp)
			run += 1
		else:
			# Their kick out of their back third (home fp above the zone edge).
			if prev_side == 1 and prev_kind == "kick" and prev_fp > MatchSim.PRESS_ZONE_EDGE:
				esc.add(prev_fp - f)
			if prev_side == 0:
				lose_fp.add(f)
				chains.add(float(run))
				run = 0
		prev_side = side
		prev_kind = kind
		prev_fp = f
	return {"territory": terr.out(), "win_back_fp": win_fp.out(), "win_backs": [float(win_fp.n), 1.0],
		"lose_fp": lose_fp.out(), "pressure_n": [float(press.n), 1.0], "pressure_fp": press.out(),
		"kick_share": [kicks / maxf(1.0, kicks + handballs), 1.0 if kicks + handballs > 0.0 else 0.0],
		"kick_gain": gain.out(), "chain_len": chains.out(), "stoppages": [stoppages, 1.0],
		"win_back_fwd_share": [wins_fwd / maxf(1.0, float(win_fp.n)), 1.0 if win_fp.n > 0 else 0.0],
		"stoppages_fwd": [stoppages_fwd, 1.0], "their_escape_gain": esc.out(),
		"z0_win_backs": [win_z[0], 1.0], "z1_win_backs": [win_z[1], 1.0], "z2_win_backs": [win_z[2], 1.0]}


class _Acc:
	var n := 0
	var sum := 0.0

	func add(x: float) -> void:
		n += 1
		sum += x

	func out() -> Array:
		return [sum / maxf(1.0, float(n)), 1.0 if n > 0 else 0.0]


func _top3(ps: Array) -> Dictionary:
	var s := ps.duplicate()
	s.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var out := {}
	for p in s.slice(0, 3):
		out[str(p["id"])] = true
	return out


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var arms: Array = ALL if args.size() <= 1 or str(args[1]) == "" or str(args[1]) == "all" else str(args[1]).split(",")
	var seeds := int(args[2]) if args.size() > 2 else 40
	# The baseline once per match, shared by every arm.
	var base := {}
	for pr in PAIRS:
		for s in range(seeds):
			base["%s|%d" % [pr[0], s]] = _play(pr[0], pr[1], 7000 + s, "base")
	var base_sum := {}
	for k in KEYS:
		var xs := []
		for key in base:
			var v: Array = (base[key] as Dictionary)[k]
			if float(v[1]) > 0.0:
				xs.append(float(v[0]))
		base_sum[k] = _mean_se(xs)
	print("PLAN base | balanced | " + " | ".join(KEYS.map(func(k): return "%s %s" % [k, base_sum[k]])))
	for arm in arms:
		var diffs := {}
		for k in KEYS:
			diffs[k] = []
		for pr in PAIRS:
			for s in range(seeds):
				var b: Dictionary = base["%s|%d" % [pr[0], s]]
				var r := _play(pr[0], pr[1], 7000 + s, str(arm))
				for k in KEYS:
					if float((b[k] as Array)[1]) > 0.0 and float((r[k] as Array)[1]) > 0.0:
						(diffs[k] as Array).append(float((r[k] as Array)[0]) - float((b[k] as Array)[0]))
		for k in KEYS:
			print("PLAN %s | %s | paired diff %s | n %d" % [arm, k, _mean_se(diffs[k]), (diffs[k] as Array).size()])


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
