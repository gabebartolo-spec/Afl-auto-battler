extends RefCounted
## Playing through a defender: does a good user of the ball lift the side, and
## a poor one cost it? Measurement only. Plays N matches (arg 1, default 1000)
## for one arm (env DIST_ARM) on paired seeds (AUDIT_SEED, default 9000):
##   none          no Play through
##   best, worst   Play through the home side's best / worst user of the ball
##                 among its defenders (disposal and creating, as the engine
##                 weighs them)
##   best0, worst0 the same, with the distributor's skill edge off
##                 (MatchSim.dist_skill = 0: Play through as before)
## Prints one DIST line per measure for the home side, a match on average,
## with its standard error.
## godot --headless --path . --script tools/audit/run_audit.gd -- distributor_impl 1000

const CLUBS := ["GEE", "COL", "CAR", "SYD", "MEL", "BRL", "HAW", "ESS", "GWS", "FRE", "ADE", "PAD"]


func _skill(p: Dictionary) -> float:
	var a: Dictionary = p.get("attr", {})
	return 0.6 * float(a.get("disposal", 50.0)) + 0.4 * float(a.get("creating", 50.0))


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 1000
	var env := OS.get_environment("AUDIT_SEED")
	var base := int(env) if env != "" else 9000
	var arm := OS.get_environment("DIST_ARM")
	if arm == "":
		arm = "none"
	MatchSim.dist_skill = 0.0 if arm.ends_with("0") else MatchSim.DIST_SKILL
	var keys := ["metres", "score_for", "score_against", "inside50", "clangers", "ineffective", "skill"]
	var sums := {}
	var sq := {}
	for k in keys:
		sums[k] = 0.0
		sq[k] = 0.0
	for i in range(n):
		var h: String = CLUBS[i % CLUBS.size()]
		var a: String = CLUBS[(i * 7 + 5) % CLUBS.size()]
		if a == h:
			a = CLUBS[(i + 1) % CLUBS.size()]
		var sim := MatchSim.new(Squad.new(h, GameDB.club_list(h), true, h),
				Squad.new(a, GameDB.club_list(a), false, a), base + i)
		var skill := 0.0
		if arm != "none":
			var pick = null
			for p in (sim.squads[0] as Squad).ground:
				if str(p["role"]) != "DEF":
					continue
				if pick == null or (arm.begins_with("best") and _skill(p) > _skill(pick)) \
						or (arm.begins_with("worst") and _skill(p) < _skill(pick)):
					pick = p
			if pick != null:
				var t: Dictionary = (sim.tactics[0] as Dictionary).duplicate()
				t["focus_id"] = str(pick["id"])
				sim.set_tactics(0, t)
				skill = _skill(pick)
		var r: Dictionary = sim.run()
		var team: Dictionary = r["team"][0]
		var v := {
			"metres": float(team.get("metres_gained", 0.0)),
			"score_for": float(r["score"][0]), "score_against": float(r["score"][1]),
			"inside50": float(team.get("inside50", 0.0)), "clangers": float(team.get("clangers", 0.0)),
			"ineffective": float(team.get("disposals", 0.0)) - float(team.get("effective_disposals", 0.0)),
			"skill": skill,
		}
		for k in keys:
			sums[k] += float(v[k])
			sq[k] += float(v[k]) * float(v[k])
	print("DIST arm %s matches %d" % [arm, n])
	for k in keys:
		var mean: float = float(sums[k]) / float(n)
		var sd := sqrt(maxf(0.0, float(sq[k]) / float(n) - mean * mean))
		print("DIST %s %.2f se %.2f" % [k, mean, sd / sqrt(float(n))])
