extends RefCounted
## What a club's tactical coaching is worth in one match (RPG-006), with the
## career's chaos taken out: the same matches, the same seeds, played twice,
## the home side's tactics at the top of their range (an elite tactician:
## exec 1.25, read 1.0) and at the bottom (a vacant job: exec 0.81, read -0.75).
## Both sides pick their own plans (AI rules), so the plan's upside is what
## moves. Args after the impl name: seeds (per pairing, default 40)
## Prints the mean home margin each way and the paired difference with its
## standard error, overall and per pairing.

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]


func _margin(h: String, a: String, seed: int, exec: float, read: float) -> int:
	var home := Squad.new(h, GameDB.club_list(h), true, h)
	var away := Squad.new(a, GameDB.club_list(a), false, a)
	home.ai_plans = true
	away.ai_plans = true
	home.tactics_exec = exec
	home.tactics_read = read
	var sim := MatchSim.new(home, away, seed)
	var res: Dictionary = sim.run()
	var sc: Array = res["score"]
	return int(sc[0]) - int(sc[1])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[1]) if args.size() > 1 else 40
	var all := []
	for pr in PAIRS:
		var diffs := []
		var hi_sum := 0.0
		var lo_sum := 0.0
		for s in range(seeds):
			var seed := 9000 + s
			var hi := _margin(pr[0], pr[1], seed, 1.25, 1.0)
			var lo := _margin(pr[0], pr[1], seed, 0.81, -0.75)
			hi_sum += hi
			lo_sum += lo
			diffs.append(float(hi - lo))
		all.append_array(diffs)
		print("%s v %s | elite %+.1f | vacant %+.1f | paired %s" % [pr[0], pr[1], hi_sum / seeds, lo_sum / seeds, _mean_se(diffs)])
	print("SUMMARY tactics elite minus vacant, %d paired matches: %s points a match" % [all.size(), _mean_se(all)])


func _mean_se(xs: Array) -> String:
	var n := float(xs.size())
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= n
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	var se := sqrt(v / maxf(1.0, n - 1.0) / n)
	return "%+.2f ± %.2f" % [m, se]
