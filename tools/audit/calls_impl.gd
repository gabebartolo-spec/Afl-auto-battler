extends RefCounted
## Live-match calls: how much the coach's plan calls swing a match between
## evenly matched drafted sides. Side 0 is "you"; side 1 is an AI club picking
## its own plans. Same seeds and sides for every policy.
##   default  - you stay Balanced all match (no calls)
##   counter  - at each break you counter the plan they ran last quarter
##              (what the break shows you; no psychic read)
##   fixed:X  - plan X all match
## "best fixed" is, per match, the best of the fixed plans in hindsight:
## an upper bound on one plan choice.

var last_ai_plan := ""
var by_ai := {}   # AI's Q1 plan -> policy -> [wins, n]

const PLAN_KEYS := ["balanced", "attacking", "defensive", "contest", "controlled", "through_stars"]
const COUNTER := {"controlled": "attacking", "defensive": "controlled", "press": "controlled",
		"attacking": "defensive", "fast": "defensive"}

func _play(home: Array, away: Array, hcode: String, acode: String, seed: int, policy: String) -> int:
	var a := Squad.new(hcode, home, true, hcode)
	var b := Squad.new(acode, away, false, acode)
	b.ai_plans = true
	var sim := MatchSim.new(a, b, seed)
	var plan := "balanced"
	if policy.begins_with("fixed:"):
		plan = policy.substr(6)
	for q in range(4):
		if policy == "counter" and q > 0:
			var hist: Array = sim.tactics_history
			var theirs := str(((hist[hist.size() - 1]["plans"] as Array)[1] as Dictionary).get("gameplan", "balanced"))
			plan = str(COUNTER.get(theirs, "balanced"))
		sim.set_tactics(0, {"gameplan": plan})
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		sim.end_quarter()
	last_ai_plan = str(((sim.tactics_history[0]["plans"] as Array)[1] as Dictionary).get("gameplan", "balanced"))
	var res := sim.result()
	var sc: Array = res["score"]
	return int(sc[0]) - int(sc[1])

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var policies := ["default", "counter"]
	for k in PLAN_KEYS:
		if k != "balanced":
			policies.append("fixed:" + k)
	var stats := {}
	for p in policies + ["best fixed"]:
		stats[p] = [0.0, 0.0, 0]   # wins (draw 0.5), margin sum, n
	var games := 0
	for draft_seed in [21, 22, 23, 24]:
		var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		# Neighbours in strength play each other: evenly matched.
		for i in range(0, codes.size() - 1, 2):
			var h := str(codes[i])
			var w := str(codes[i + 1])
			for rep in range(int(OS.get_environment("CALLS_REPS")) if OS.get_environment("CALLS_REPS") != "" else 6):
				var seed: int = int(draft_seed) * 1000 + i * 10 + rep
				var best := -9999
				for pol in policies:
					var m := _play(lists[h], lists[w], h, w, seed, pol)
					if pol in ["default", "fixed:defensive", "counter"]:
						var row: Dictionary = by_ai.get(last_ai_plan, {})
						var c: Array = row.get(pol, [0.0, 0])
						c[0] += 1.0 if m > 0 else (0.5 if m == 0 else 0.0)
						c[1] += 1
						row[pol] = c
						by_ai[last_ai_plan] = row
					var st: Array = stats[pol]
					st[0] += 1.0 if m > 0 else (0.5 if m == 0 else 0.0)
					st[1] += float(m)
					st[2] += 1
					if pol.begins_with("fixed:") or pol == "default":
						best = maxi(best, m)
				var bs: Array = stats["best fixed"]
				bs[0] += 1.0 if best > 0 else (0.5 if best == 0 else 0.0)
				bs[1] += float(best)
				bs[2] += 1
				games += 1
	print("CALLS over %d paired matches (evenly matched drafted sides, you at home):" % games)
	for p in policies + ["best fixed"]:
		var st: Array = stats[p]
		print("    %-22s win %.1f%%  mean margin %+.1f" % [p, 100.0 * st[0] / st[2], st[1] / st[2]])
	print("BY AI OPENING PLAN (win %):")
	for k in by_ai:
		var line := "    AI %-14s" % k
		for pol in ["default", "counter", "fixed:defensive"]:
			var c: Array = (by_ai[k] as Dictionary).get(pol, [0.0, 0])
			line += "  %s %.1f%% (n=%d)" % [pol, 100.0 * float(c[0]) / maxf(1, int(c[1])), int(c[1])]
		print(line)
