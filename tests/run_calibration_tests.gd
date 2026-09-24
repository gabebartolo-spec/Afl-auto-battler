extends SceneTree
## godot --headless --path . --script tests/run_calibration_tests.gd
## Engine calibration guard. Plays MATCHES seeded games of the shipped
## MatchSim between the real 2026 lists and compares per-team-per-game totals
## with the real 2026 averages (the same benchmark tools/sim_harness.py uses).
## Fails if any stat drifts outside TOLERANCE, so an engine change that
## quietly breaks realism turns CI red. Classes are reached through load():
## a --script runner compiles before the autoloads exist.

const MATCHES := 400
const SEED := 1234
const TOLERANCE := 0.07

## [label, sim team-stat key, benchmark key]. "score" and "hb" are derived.
const ROWS := [
	["Score (pts)", "score", "score"], ["Goals", "goals", "gl"],
	["Behinds", "behinds", "bh"], ["Disposals", "disposals", "di"],
	["Kicks", "kicks", "ki"], ["Handballs", "handballs", "hb"],
	["Marks", "marks", "mk"], ["Tackles", "tackles", "tk"],
	["Inside 50s", "inside50", "if50"], ["Clearances", "clearances", "cl"],
	["Hit-outs", "hitouts", "ho"], ["Rebound 50s", "rebounds", "rb"],
	["One percenters", "one_percenters", "onepct"], ["Clangers", "clangers", "cg"],
	["Free kicks for", "frees_for", "ff"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var db = root.get_node("GameDB")
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim_script = load("res://scripts/sim/MatchSim.gd")
	var codes: Array = db.CLUB_ORDER
	var bench := _benchmarks(db)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var totals := {}
	var team_games := 0
	var player_goals := {}   # id -> goals over the sample
	var club_goals := {}     # code -> goals over the sample
	var player_club := {}
	for i in range(MATCHES):
		var a: String = codes[rng.randi_range(0, codes.size() - 1)]
		var b: String = a
		while b == a:
			b = codes[rng.randi_range(0, codes.size() - 1)]
		var home = squad_script.new(a, db.club_list(a), true, a)
		var away = squad_script.new(b, db.club_list(b), false, b)
		var res: Dictionary = sim_script.new(home, away, SEED + i).run()
		for id in res["players"]:
			player_goals[id] = float(player_goals.get(id, 0.0)) + float(res["players"][id].get("goals", 0.0))
		for side in range(2):
			var code: String = a if side == 0 else b
			for r in res["roster"][side]:
				player_club[str(r["id"])] = code
			club_goals[code] = float(club_goals.get(code, 0.0)) + float(res["goals"][side])
			var team: Dictionary = res["team"][side]
			for key in team:
				totals[key] = float(totals.get(key, 0.0)) + float(team[key])
			totals["score"] = float(totals.get("score", 0.0)) + float(res["score"][side])
		team_games += 2

	print("%-16s %9s %8s %6s" % ["Stat/team/game", "REAL 2026", "SIM", "ratio"])
	var failures := []
	for row in ROWS:
		var sim := float(totals.get(str(row[1]), 0.0)) / float(team_games)
		var real := float(bench[str(row[2])])
		var ratio := sim / real if real > 0.0 else 0.0
		var flag := ""
		if absf(ratio - 1.0) > TOLERANCE:
			flag = "  <-- off"
			failures.append("%s ratio %.2f" % [str(row[0]), ratio])
		print("%-16s %9.1f %8.1f %6.2f%s" % [str(row[0]), real, sim, ratio, flag])
	# How goals spread across a side: real 2026 clubs' top goalkicker kicks
	# 16% of their goals and their top three 38%.
	var by_club := {}
	for id in player_goals:
		var code := str(player_club.get(id, ""))
		if code == "":
			continue
		if not by_club.has(code):
			by_club[code] = []
		(by_club[code] as Array).append(float(player_goals[id]))
	var top1 := 0.0
	var top3 := 0.0
	for code in by_club:
		var arr: Array = by_club[code]
		arr.sort()
		arr.reverse()
		var total := float(club_goals.get(code, 1.0))
		top1 += float(arr[0]) / total
		top3 += (float(arr[0]) + float(arr[1]) + float(arr[2])) / total
	top1 /= float(by_club.size())
	top3 /= float(by_club.size())
	for row in [["Top kicker share", top1, 0.16], ["Top-3 share", top3, 0.38]]:
		var ratio := float(row[1]) / float(row[2])
		var flag := ""
		if absf(ratio - 1.0) > 0.15:
			flag = "  <-- off"
			failures.append("%s %.2f (real %.2f)" % [str(row[0]), float(row[1]), float(row[2])])
		print("%-16s %9.2f %8.2f %6.2f%s" % [str(row[0]), float(row[2]), float(row[1]), ratio, flag])
	for f in failures:
		push_error("Calibration: " + f)
	print("Calibration tests: %d checks, %d failures" % [ROWS.size() + 2, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Per-team-per-game real averages: every club's season totals over its games
## played (the most games any of its players played), as in sim_harness.py.
func _benchmarks(db) -> Dictionary:
	var keys := ["gl", "bh", "di", "ki", "mk", "tk", "if50", "cl", "ho", "rb", "onepct", "cg", "ff"]
	var tot := {}
	var games := 0.0
	for code in db.CLUB_ORDER:
		var most := 0.0
		for p in db.club_list(code):
			most = maxf(most, float(p["gm"]))
			for k in keys:
				tot[k] = float(tot.get(k, 0.0)) + float(p[k])
		games += most
	var out := {}
	for k in keys:
		out[k] = float(tot[k]) / games
	out["hb"] = float(out["di"]) - float(out["ki"])
	out["score"] = float(out["gl"]) * 6.0 + float(out["bh"])
	return out
