extends RefCounted
## Stat integrity (the Stats patch): the match averages before and after the
## mark credits come from the contest instead of a roll. Measurement only.
## Plays N matches (arg 1, default 400) between clubs in turn and prints one
## STATINT line per measure, a team's average a match (score: both sides').
## The match seeds start at AUDIT_SEED (default 7000), so two runs pair.
## godot --headless --path . --script tools/audit/run_audit.gd -- statint_impl 400

const CLUBS := ["GEE", "COL", "CAR", "SYD", "MEL", "BRL", "HAW", "ESS", "GWS", "FRE", "ADE", "PAD"]
const KEYS := ["goals", "behinds", "marks", "contested_marks", "intercept_marks", "inside50", "disposals",
		"contested_possessions", "uncontested_possessions", "ground_ball_gets", "shots", "intercepts",
		"spoils", "rebounds", "clearances", "tackles"]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 400
	var env := OS.get_environment("AUDIT_SEED")
	var base := int(env) if env != "" else 7000
	var sums := {}
	var score := 0.0
	var score_sq := 0.0
	for i in range(n):
		var h: String = CLUBS[i % CLUBS.size()]
		var a: String = CLUBS[(i * 5 + 3) % CLUBS.size()]
		if a == h:
			a = CLUBS[(i + 1) % CLUBS.size()]
		var sim := MatchSim.new(Squad.new(h, GameDB.club_list(h), true, h),
				Squad.new(a, GameDB.club_list(a), false, a), base + i)
		var r: Dictionary = sim.run()
		var total := float(int(r["score"][0]) + int(r["score"][1]))
		score += total
		score_sq += total * total
		for side in [0, 1]:
			for k in KEYS:
				sums[k] = float(sums.get(k, 0.0)) + float((r["team"][side] as Dictionary).get(k, 0.0))
	var mean := score / float(n)
	var sd := sqrt(maxf(0.0, score_sq / float(n) - mean * mean))
	print("STATINT matches %d" % n)
	print("STATINT total_score %.2f sd %.2f se %.2f" % [mean, sd, sd / sqrt(float(n))])
	for k in KEYS:
		print("STATINT %s %.2f" % [k, float(sums[k]) / float(n * 2)])
