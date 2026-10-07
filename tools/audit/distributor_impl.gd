extends RefCounted
## Playing through a defender: does a good user of the ball lift the side, and
## a poor one cost it? Measurement only. Plays N matches (arg 1, default 1000)
## for one arm (env DIST_ARM) on paired seeds (AUDIT_SEED, default 9000):
##   none          no Play through
##   best, worst   Play through the home side's best / worst user of the ball
##                 among its defenders (disposal and creating, as the engine
##                 weighs them)
##   best0, worst0 the same, with the distributor's kicking off
##                 (MatchSim.dist_skill = 0: Play through as before)
## Prints the league's defenders' kicking (the pivot to set), then one DIST
## line per measure, a match on average with its standard error: the home
## side's, then the defender played through (FOCUS): his disposals, kicks,
## metres, clangers, the kicks that found a teammate up the ground and the
## kicks intercepted.
## godot --headless --path . --script tools/audit/run_audit.gd -- distributor_impl 1000

const CLUBS := ["GEE", "COL", "CAR", "SYD", "MEL", "BRL", "HAW", "ESS", "GWS", "FRE", "ADE", "PAD"]


func _skill(p: Dictionary) -> float:
	var a: Dictionary = p.get("attr", {})
	return 0.6 * float(a.get("disposal", 50.0)) + 0.4 * float(a.get("creating", 50.0))


## Every club's selected defenders, on the engine's measure.
func _league() -> void:
	var all := []
	for code in GameDB.CLUB_ORDER:
		var sq := Squad.new(code, GameDB.club_list(code), true, code)
		for p in sq.ground:
			if str(p["role"]) == "DEF":
				all.append(_skill(p))
	all.sort()
	var n := all.size()
	if n == 0:
		return
	var mean := 0.0
	for v in all:
		mean += float(v)
	mean /= float(n)
	print("DIST league defenders %d mean %.1f p10 %.1f median %.1f p90 %.1f min %.1f max %.1f" % [
		n, mean, all[int(n * 0.1)], all[n / 2], all[int(n * 0.9)], all[0], all[n - 1]])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 1000
	var env := OS.get_environment("AUDIT_SEED")
	var base := int(env) if env != "" else 9000
	var arm := OS.get_environment("DIST_ARM")
	if arm == "":
		arm = "none"
	MatchSim.dist_skill = 0.0 if arm.ends_with("0") else MatchSim.DIST_SKILL
	_league()
	var keys := ["metres", "score_for", "score_against", "inside50", "clangers", "ineffective", "skill",
		"focus_disposals", "focus_kicks", "focus_metres", "focus_clangers", "focus_found", "focus_intercepted"]
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
		var focus := ""
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
				focus = str(pick["id"])
		var r: Dictionary = sim.run()
		var team: Dictionary = r["team"][0]
		var me: Dictionary = (r["players"] as Dictionary).get(focus, {}) if focus != "" else {}
		var found := 0
		var intercepted := 0
		if focus != "":
			for e in r["events"]:
				if bool(e.get("free_man", false)) and str(e.get("player_id", "")) == focus:
					found += 1
				if str(e.get("from_id", "")) == focus:
					intercepted += 1
		var v := {
			"metres": float(team.get("metres_gained", 0.0)),
			"score_for": float(r["score"][0]), "score_against": float(r["score"][1]),
			"inside50": float(team.get("inside50", 0.0)), "clangers": float(team.get("clangers", 0.0)),
			"ineffective": float(team.get("disposals", 0.0)) - float(team.get("effective_disposals", 0.0)),
			"skill": skill,
			"focus_disposals": float(me.get("disposals", 0.0)), "focus_kicks": float(me.get("kicks", 0.0)),
			"focus_metres": float(me.get("metres_gained", 0.0)), "focus_clangers": float(me.get("clangers", 0.0)),
			"focus_found": float(found), "focus_intercepted": float(intercepted),
		}
		for k in keys:
			sums[k] += float(v[k])
			sq[k] += float(v[k]) * float(v[k])
	print("DIST arm %s matches %d" % [arm, n])
	for k in keys:
		var mean: float = float(sums[k]) / float(n)
		var sd := sqrt(maxf(0.0, float(sq[k]) / float(n) - mean * mean))
		print("DIST %s %.2f se %.2f" % [k, mean, sd / sqrt(float(n))])
