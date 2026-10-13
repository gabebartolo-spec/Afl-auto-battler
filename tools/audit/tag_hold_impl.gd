extends RefCounted
## Tag hold audit (#633, director 2026-10-11: the hold scales with the
## tagger's Pressure and legs). The same matches and seeds played with no tag
## and with the home side tagging the away side's best midfielder, sent by:
##   hi    the home midfielder on the ground with the most Pressure
##   lo    the one with the least
## Paired against no tag: the star's disposals, the tagger's own disposals,
## and the margin. Run on the PR and on its base to show a high-Pressure
## tagger holds no tighter than before (no new power at the top).
## Args after the impl name: seeds (per pairing, default 40).

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]


func _play(h: String, a: String, seed: int, arm: String) -> Dictionary:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	var sim := MatchSim.new(home, away, seed)
	var star := ""
	var best := -1
	for p in away.ground:
		if MatchSim.midfielder_on_ground(p) and int(p["overall"]) > best:
			best = int(p["overall"])
			star = str(p["id"])
	var who := ""
	var pick := -1.0 if arm == "hi" else 999.0
	for p in home.ground:
		if not MatchSim.midfielder_on_ground(p):
			continue
		var pr := float((p["attr"] as Dictionary).get("pressure", 0))
		if (arm == "hi" and pr > pick) or (arm == "lo" and pr < pick):
			pick = pr
			who = str(p["id"])
	var t := {"gameplan": "balanced", "pep": "steady"}
	if arm != "base":
		t["tag_id"] = star
		t["tagger_id"] = who
	sim.set_tactics(0, t)
	var res: Dictionary = sim.run()
	var sc: Array = res["score"]
	var pl: Dictionary = res["players"]
	return {"margin": float(int(sc[0]) - int(sc[1])),
		"star_disposals": float((pl.get(star, {}) as Dictionary).get("disposals", 0)),
		"tagger_disposals": float((pl.get(who, {}) as Dictionary).get("disposals", 0)) if who != "" else 0.0,
		"tagger_pressure": pick if arm != "base" else 0.0}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[1]) if args.size() > 1 else 40
	for arm in ["hi", "lo"]:
		var diffs := {}
		var sums := {}
		for pr in PAIRS:
			for s in range(seeds):
				var b := _play(pr[0], pr[1], 7000 + s, "base")
				var r := _play(pr[0], pr[1], 7000 + s, arm)
				for k in r:
					if not diffs.has(k):
						diffs[k] = []
						sums[k] = 0.0
					(diffs[k] as Array).append(float(r[k]) - float(b[k]))
					sums[k] = float(sums[k]) + float(r[k])
		for k in diffs:
			print("TAGHOLD %s | %s | arm mean %.3f | paired diff %s" % [arm, k, float(sums[k]) / float((diffs[k] as Array).size()), _mean_se(diffs[k])])


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
