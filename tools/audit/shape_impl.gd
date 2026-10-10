extends RefCounted
## The match's shape against real AFL (match-flow work, director 2026-10-10:
## "Step 1 and then Step 2", docs/research/MATCH_SHAPE_AUDIT_2026-10-10.md).
## Plays the calibration suite's sample (real 2026 lists, SHAPE_MATCHES games,
## seed 1234) and prints, per team a game: the stats the calibration suite
## guards, the contest and turnover stats it doesn't, stoppages, where the
## points came from, and how chains started (MatchSim.audit_chains).
## Measurement only. Env: SHAPE_MATCHES (default 400).

## Real 2026 per team a game, Champion Data via Wheelo
## (docs/research/wheelo/afl_player_stats_2026.json, 436 team-games).
const REAL := {
	"contested_possessions": 129.3, "uncontested_possessions": 226.6, "spoils": 30.8,
	"intercepts": 65.4, "intercept_marks": 14.4, "ground_ball_gets": 86.5,
	"contested_marks": 9.0, "tackles": 57.4, "frees_for": 18.7, "clangers": 55.9,
	"marks": 91.7, "disposals": 367.5, "inside50": 53.1, "clearances": 36.2,
	"hitouts": 35.8, "goals": 12.9, "behinds": 9.5,
}
const SHOW := ["disposals", "kicks", "handballs", "marks", "tackles", "inside50", "clearances",
	"hitouts", "rebounds", "one_percenters", "clangers", "frees_for", "goals", "behinds",
	"contested_possessions", "uncontested_possessions", "ground_ball_gets", "spoils",
	"intercepts", "intercept_marks", "contested_marks", "pressure_wins", "centre_bounces"]


func run() -> void:
	var n := 400
	if OS.get_environment("SHAPE_MATCHES") != "":
		n = int(OS.get_environment("SHAPE_MATCHES"))
	var codes: Array = GameDB.active_clubs(2026)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	MatchSim.audit_chains_on = true
	MatchSim.audit_chains = {}
	var tot := {}
	var score := 0.0
	var tg := 0
	for i in range(n):
		var a: String = codes[rng.randi_range(0, codes.size() - 1)]
		var b: String = a
		while b == a:
			b = codes[rng.randi_range(0, codes.size() - 1)]
		var sim := MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
				Squad.new(b, GameDB.club_list(b), false, b), 1234 + i)
		var res := sim.run()
		for side in range(2):
			var td: Dictionary = res["team"][side]
			for k in td:
				if typeof(td[k]) == TYPE_INT or typeof(td[k]) == TYPE_FLOAT:
					tot[k] = float(tot.get(k, 0.0)) + float(td[k])
			score += float(res["score"][side])
		tg += 2
	MatchSim.audit_chains_on = false
	print("shape_impl: %d matches" % n)
	print("SHAPE %-26s %8s %8s %6s" % ["stat (team a game)", "sim", "real", "ratio"])
	print("SHAPE %-26s %8.1f" % ["score", score / float(tg)])
	for k in SHOW:
		var v := float(tot.get(k, 0.0)) / float(tg)
		if REAL.has(k):
			print("SHAPE %-26s %8.1f %8.1f %6.2f" % [k, v, float(REAL[k]), v / float(REAL[k])])
		else:
			print("SHAPE %-26s %8.1f" % [k, v])
	var src := 0.0
	for k in tot:
		if str(k).begins_with("score_from_"):
			src += float(tot[k])
	for k in ["centre", "stoppage", "turnover", "general", "free", "kick_in"]:
		var v2 := float(tot.get("score_from_" + k, 0.0))
		print("SOURCE %-10s %6.1f pts  %4.0f%%" % [k, v2 / float(tg), 100.0 * v2 / maxf(1.0, src)])
	# Stoppages a game (both sides): chains that began at one.
	var stop := {"centre": 0.0, "stoppage": 0.0}
	for k in MatchSim.audit_chains:
		var origin := str(k).split(" ")[0]
		if stop.has(origin):
			stop[origin] = float(stop[origin]) + float(MatchSim.audit_chains[k])
	var games := float(tg) / 2.0
	print("STOPPAGES a game: centre %.1f, ball-ups/throw-ins %.1f, all %.1f (real ruck contests ~91)" % [
			float(stop["centre"]) / games, float(stop["stoppage"]) / games,
			(float(stop["centre"]) + float(stop["stoppage"])) / games])
	var ck: Array = MatchSim.audit_chains.keys()
	ck.sort()
	for k in ck:
		print("CHAIN %-34s %6.2f" % [k, float(MatchSim.audit_chains[k]) / float(tg)])
