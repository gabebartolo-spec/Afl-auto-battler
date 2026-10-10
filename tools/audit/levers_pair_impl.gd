extends RefCounted
## Lever-truth audit (ROADMAP §0.4.1, "every gameplay lever must work and its
## copy must tell the truth"): does a match call do what its copy says? The
## same matches, the same seeds, played twice: the home side as a baseline
## (Balanced, Stay composed, Normal rotations, no tag, no loose defender) and
## with exactly one call changed. The away side picks its own plans (AI
## rules). Measurement only: no rule changes.
##
## Args after the impl name: arms seeds
##   arms   comma list (default all): plan_attacking, plan_defensive,
##          plan_contest, plan_controlled, plan_through_stars, pep_fire_up,
##          pep_calm, pep_heat, rot_hard, rot_stars, tag, loose
##   seeds  per pairing (default 40); six pairings
## One line per arm: the paired home margin and the process the copy names,
## each as mean ± standard error of the paired difference.

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]
const ALL := ["plan_attacking", "plan_defensive", "plan_contest", "plan_controlled", "plan_through_stars",
		"pep_fire_up", "pep_calm", "pep_heat", "rot_hard", "rot_stars", "tag", "loose"]


## One match. Returns the numbers every arm reads.
func _play(h: String, a: String, seed: int, arm: String) -> Dictionary:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	away.ai_plans = true
	var t := {"gameplan": "balanced", "pep": "steady"}
	if arm.begins_with("plan_"):
		t["gameplan"] = arm.trim_prefix("plan_")
	if arm.begins_with("pep_"):
		t["pep"] = arm.trim_prefix("pep_")
	# Their best midfielder: the tag arm tags him; every arm records his
	# disposals, so the baseline has the same man to compare.
	var target := _best(away.ground, "MID")
	if arm == "tag":
		t["tag_id"] = target
	var sim := MatchSim.new(home, away, seed)
	sim.set_tactics(0, t)
	if arm.begins_with("rot_"):
		sim.set_rotation_policy(0, arm.trim_prefix("rot_"))
	if arm == "loose":
		var best := ""
		var top := -1.0
		for p in home.ground:
			if str(p.get("role", "")) == "DEF" and float((p.get("attr", {}) as Dictionary).get("intercept", 0)) > top:
				top = float(p["attr"]["intercept"])
				best = str(p["id"])
		sim.set_interceptor(0, best, false)
	var res: Dictionary = sim.run()
	var sc: Array = res["score"]
	var team: Dictionary = (res["team"] as Array)[0]
	var players: Dictionary = res["players"]
	var stars := _top3(home.ground + home.bench)
	var star_disp := 0.0
	var star_time := 0.0
	var exertion := 0.0
	var own_disp := 0.0
	for p in home.ground + home.bench:
		var d := float((players.get(str(p["id"]), {}) as Dictionary).get("disposals", 0))
		own_disp += d
		exertion += float((res["exertion"] as Dictionary).get(str(p["id"]), 0.0))
		if stars.has(str(p["id"])):
			star_disp += d
			star_time += float((res["exertion"] as Dictionary).get(str(p["id"]), 0.0))
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"clangers": float(team.get("clangers", 0)),
		"contested": float(team.get("contested_possessions", 0)),
		"pressure": float(team.get("pressure_acts", 0)),
		"pressure_wins": float(team.get("pressure_wins", 0)),
		"exertion": exertion,
		"clearances": float(team.get("clearances", 0)),
		"intercepts": float(team.get("intercept_marks", 0)) + float(team.get("intercepts", 0)),
		"star_share": star_disp / maxf(1.0, own_disp),
		"star_time": star_time,
		"target_disp": float((players.get(target, {}) as Dictionary).get("disposals", 0)) if target != "" else 0.0}


## The id of the highest-rated player in `role` among `ps`.
func _best(ps: Array, role: String) -> String:
	var best := ""
	var top := -1
	for p in ps:
		if str(p.get("role", "")) == role and int(p.get("overall", 0)) > top:
			top = int(p["overall"])
			best = str(p["id"])
	return best


func _top3(ps: Array) -> Dictionary:
	var s := ps.duplicate()
	s.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var out := {}
	for p in s.slice(0, 3):
		out[str(p["id"])] = true
	return out


## What each arm's copy says it changes, read from the paired matches.
const PROCESS := {
	"plan_attacking": ["margin", "clangers"],
	"plan_defensive": ["margin", "pressure"],
	"plan_contest": ["margin", "clearances"],
	"plan_controlled": ["margin", "clangers"],
	"plan_through_stars": ["margin", "star_share"],
	"pep_fire_up": ["margin", "contested", "clangers"],
	"pep_calm": ["margin", "clangers"],
	# "Harder pressure on their ball carriers forces more turnovers; legs go quicker."
	"pep_heat": ["margin", "pressure", "pressure_wins", "exertion"],
	"rot_hard": ["margin", "star_time"],
	"rot_stars": ["margin", "star_time"],
	"tag": ["margin", "target_disp"],
	"loose": ["margin", "intercepts"],
}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var arms: Array = ALL if args.size() <= 1 or str(args[1]) == "" or str(args[1]) == "all" else str(args[1]).split(",")
	var seeds := int(args[2]) if args.size() > 2 else 40
	# The baseline once per match, shared by every arm.
	var base := {}
	for pr in PAIRS:
		for s in range(seeds):
			base["%s|%d" % [pr[0], s]] = _play(pr[0], pr[1], 7000 + s, "base")
	for arm in arms:
		var diffs := {}
		for k in PROCESS[arm]:
			diffs[k] = []
		for pr in PAIRS:
			for s in range(seeds):
				var b: Dictionary = base["%s|%d" % [pr[0], s]]
				var r := _play(pr[0], pr[1], 7000 + s, str(arm))
				for k in PROCESS[arm]:
					(diffs[k] as Array).append(float(r[k]) - float(b[k]))
		var parts := []
		for k in PROCESS[arm]:
			parts.append("%s %s" % [k, _mean_se(diffs[k])])
		print("LEVER %s | %d paired matches | %s" % [arm, (diffs["margin"] as Array).size(), " | ".join(parts)])


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
