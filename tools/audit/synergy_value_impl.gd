extends RefCounted
## What a synergy is worth in a match (#383-era item 11, medium). The same
## match - same squads, same seed - played with every synergy off, then with
## one synergy switched on for the home side only, for each of the six; and
## once with each side's real synergies. Prints the home margin's change per
## synergy, mean +/- SE over the matches, so a synergy's power can be read in
## points rather than percentages. Measurement only: nothing here changes play.
##   SV_DRAFTS=21,22 SV_ROUNDS=6 (env)

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("SV_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("SV_DRAFTS").split(","):
			drafts.append(int(s))
	var rounds := int(OS.get_environment("SV_ROUNDS")) if OS.get_environment("SV_ROUNDS") != "" else 6
	var keys: Array = Traits.SYNERGIES.keys()
	var diffs := {"real": []}
	for k in keys:
		diffs[k] = []
	var natural := {}
	var n := 0
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		for ri in range(mini(rounds, season.fixture.size())):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var seed := int(d) * 100000 + ri * 100 + mi
				var base := _margin(season, m, seed, "off")
				for k in keys:
					(diffs[k] as Array).append(_margin(season, m, seed, k) - base)
				(diffs["real"] as Array).append(_margin(season, m, seed, "real") - base)
				var sim: MatchSim = season.match_sim(str(m["home"]), str(m["away"]), seed)
				for side in range(2):
					for k in sim.synergies[side]:
						natural[k] = int(natural.get(k, 0)) + 1
				n += 1
		print("draft %d done, %d matches" % [d, n])
	for k in diffs:
		var a: Array = diffs[k]
		var mean := 0.0
		for x in a:
			mean += float(x)
		mean /= maxf(1.0, a.size())
		var v := 0.0
		for x in a:
			v += pow(float(x) - mean, 2.0)
		var se := sqrt(v / maxf(1.0, a.size() - 1)) / sqrt(maxf(1.0, a.size()))
		print("VALUE %s home margin %+.2f +/- %.2f points (n=%d)%s" % [k, mean, se, a.size(),
				"" if k == "real" else ", on naturally in %d side-matches of %d" % [int(natural.get(k, 0)), 2 * n]])


## The home margin of one match: "off" (no synergies), "real" (as picked), or
## one synergy key on for the home side only.
func _margin(season: Season, m: Dictionary, seed: int, mode: String) -> int:
	var sim: MatchSim = season.match_sim(str(m["home"]), str(m["away"]), seed)
	if mode != "real":
		sim.synergies = [[], []]
		if mode != "off":
			sim.synergies[0] = [mode]
	var res := sim.run()
	var s: Array = res["score"]
	return int(s[0]) - int(s[1])
