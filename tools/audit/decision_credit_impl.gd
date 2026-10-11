extends RefCounted
## The full-time decision summary (director, 2026-10-11): what each of a
## coach's calls was worth over many matches. Measurement only.
##
## Args after the impl name: mode seeds
##   lines     per decision line (MatchSim.DECISION_CAUSES) for the home
##             coach: mean, spread and how often it is not 0; then the rest.
##   checksum  the scores of the same matches, one number, to show the
##             ledger changes no result (run on main and on the branch).
## Both clubs run their AI calls (plan, loose man, tags, defensive forward);
## the home coach also moves one defender onto their best key forward.
## Moments take their default call (no bursts, no set-shot calls).

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]
const CAUSES := ["moments", "gameplan", "loose", "matchups", "tag", "pep", "bursts", "minder"]


func _play(h: String, a: String, seed: int) -> MatchSim:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	home.ai_plans = true
	away.ai_plans = true
	var sim := MatchSim.new(home, away, seed)
	sim.moment_side = 0
	# The home coach's own match-up: his best defender in the air on their
	# best key forward, when that is not who the default put there.
	var d: Dictionary = sim.duels[0]
	var best_def := {}
	for p in home.ground:
		if str(p["role"]) == "DEF" and (best_def.is_empty() or Matchups.defender_air(p) > Matchups.defender_air(best_def)):
			best_def = p
	var best_fwd := ""
	var best_air := -1.0
	for fid in d:
		for p in away.ground:
			if str(p["id"]) == str(fid) and Matchups.forward_air(p) > best_air:
				best_air = Matchups.forward_air(p)
				best_fwd = str(fid)
	if best_fwd != "" and not best_def.is_empty() and str(d[best_fwd]) != str(best_def["id"]):
		sim.set_matchups(0, {best_fwd: str(best_def["id"])})
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		sim.end_quarter()
	return sim


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1]) if args.size() > 1 else "lines"
	var seeds := int(args[2]) if args.size() > 2 else 40
	var vals := {}
	var rest := []
	var check := 0
	for pr in PAIRS:
		for s in range(seeds):
			var sim := _play(pr[0], pr[1], 9100 + s)
			var margin := float(sim.score(0) - sim.score(1))
			check = (check * 31 + sim.score(0) * 1000 + sim.score(1)) % 1000000007
			if mode != "lines":
				continue
			var imp: Dictionary = sim.impact[0]
			var total := 0.0
			for c in CAUSES:
				var v := float(imp.get(c, 0.0))
				if not vals.has(c):
					vals[c] = []
				(vals[c] as Array).append(v)
				total += v
			rest.append(margin - total)
	print("DECISION checksum %d over %d matches" % [check, PAIRS.size() * seeds])
	if mode != "lines":
		return
	for c in CAUSES:
		var xs: Array = vals[c]
		var nz := 0
		for x in xs:
			if float(x) != 0.0:
				nz += 1
		print("DECISION %s | mean %s | sd %.2f | made in %d of %d" % [c, _mean_se(xs), _sd(xs), nz, xs.size()])
	print("DECISION rest | mean %s | sd %.2f" % [_mean_se(rest), _sd(rest)])


func _sd(xs: Array) -> float:
	var n := float(xs.size())
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= maxf(1.0, n)
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	return sqrt(v / maxf(1.0, n - 1.0))


func _mean_se(xs: Array) -> String:
	var n := float(xs.size())
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= maxf(1.0, n)
	return "%+.3f ± %.3f" % [m, _sd(xs) / sqrt(maxf(1.0, n))]
