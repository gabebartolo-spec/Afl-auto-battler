extends RefCounted
## Rival coach tendencies (MatchSim.COACH_STYLES, director 2026-10-11).
## Measurement only. The same matches and seeds, both sides AI clubs.
##
## Args after the impl name: mode seeds
##   style    (a) for each style: the home club's coach with that tendency
##            against the same home club with a balanced coach, the away club
##            a balanced AI coach throughout. A style should be no free win
##            or free loss (home margin within about +-3).
##   exploit  (b) for each style, the home coach with that tendency throughout;
##            the away coach plays its normal calls, or reads him: each
##            quarter it answers the plan he has just picked with its counter
##            (Attack corridor beats Controlled tempo, the press beats Attack
##            corridor, Controlled tempo plays through the press), everything
##            else as its normal calls. Reported: the away margin gained by
##            reading him, against the same for a balanced coach.
##   seeds    per pairing (default 40); six pairings
##   styles   comma list (default all)

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]
const STYLES := ["balanced", "stubborn", "reactive", "gambler", "cautious"]
const COUNTER := {"controlled": "attacking", "attacking": "defensive", "defensive": "controlled"}


func _play(h: String, a: String, seed: int, home_style: String, read_him: bool) -> Dictionary:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	home.ai_plans = true
	away.ai_plans = true
	home.coach_style = home_style
	var sim := MatchSim.new(home, away, seed)
	sim.moment_side = -1
	var plans := {}
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		var his := str((sim.tactics[0] as Dictionary).get("gameplan", "balanced"))
		plans[his] = int(plans.get(his, 0)) + 1
		if read_him and COUNTER.has(his):
			var t: Dictionary = (sim.tactics[1] as Dictionary).duplicate()
			t["gameplan"] = COUNTER[his]
			sim.set_tactics(1, t)
		while not sim.continue_quarter():
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		sim.end_quarter()
	var res: Dictionary = sim.result()
	var sc: Array = res["score"]
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"q_controlled": float(int(plans.get("controlled", 0))),
		"q_attacking": float(int(plans.get("attacking", 0)))}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1]) if args.size() > 1 else "style"
	var seeds := int(args[2]) if args.size() > 2 else 40
	var which: Array = STYLES if args.size() <= 3 else str(args[3]).split(",")
	for style in which:
		var diffs := {}
		var sums := {}
		for pr in PAIRS:
			for s in range(seeds):
				var b: Dictionary
				var r: Dictionary
				if mode == "exploit":
					b = _play(pr[0], pr[1], 7000 + s, style, false)
					r = _play(pr[0], pr[1], 7000 + s, style, true)
				else:
					b = _play(pr[0], pr[1], 7000 + s, "balanced", false)
					r = _play(pr[0], pr[1], 7000 + s, style, false)
				for k in r:
					if not diffs.has(k):
						diffs[k] = []
						sums[k] = 0.0
					# exploit: the away side's gain, so the home margin's sign flips.
					var d := float(r[k]) - float(b[k])
					if mode == "exploit" and k == "margin":
						d = -d
					(diffs[k] as Array).append(d)
					sums[k] = float(sums[k]) + float(r[k])
		for k in diffs:
			print("COACH %s %s | %s | arm mean %.3f | paired diff %s" % [mode, style, k,
					float(sums[k]) / float((diffs[k] as Array).size()), _mean_se(diffs[k])])


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
