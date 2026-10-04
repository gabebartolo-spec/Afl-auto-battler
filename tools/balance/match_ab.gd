extends SceneTree
## Paired match probe for docs/COMPETITIVE_BALANCE.md: your club's matches
## against every rival, home and away, replayed on the same seeds under two
## or more settings of one thing, so the difference between rows is that
## thing alone. Measurement only.
##
##   godot --headless --path . --script tools/balance/match_ab.gd -- \
##       --mode morale --seed 301 --reps 10
##
##   --mode morale   your whole list at morale 70 (settled), 85 and 100
##   --mode coach    your side left on Balanced with no match-ups, then
##                   coached as MatchSim coaches a rival club (a plan picked
##                   each quarter, match-ups at the breaks, a loose
##                   interceptor), both at morale 70
##   --mode moments  your side coached as a rival club, without and then
##                   with the live match's moment cards (each taking its
##                   default call), both at morale 70
##   --seed          the career draft (league_balance.gd "board" policy)
##   --reps          matches per opponent per setting, alternating home/away


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode := "morale"
	var seed := 301
	var reps := 10
	for i in range(args.size() - 1):
		match str(args[i]):
			"--mode":
				mode = str(args[i + 1])
			"--seed":
				seed = int(args[i + 1])
			"--reps":
				reps = int(args[i + 1])
	var db = root.get_node("GameDB")
	db.reload()
	var lb = load("res://tools/balance/league_balance.gd").new()
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	var d = lb.make_draft(seed, "board", 5)
	var user: String = d.user_club
	gs.draft = d
	gs.start_season(user, [])
	gs._refresh_coach_tactics()
	var coach_effects = load("res://scripts/sim/CoachEffects.gd")
	var opps: Array = db.active_clubs(gs.season_year).filter(func(c): return c != user)
	var settings := [70, 85, 100] if mode == "morale" else [false, true]
	for setting in settings:
		var morale: int = int(setting) if mode == "morale" else 70
		for p in gs.season.lists[user]:
			p["morale"] = morale
		if mode == "coach":
			coach_effects.table[user]["ai"] = bool(setting)
		elif mode == "moments":
			coach_effects.table[user]["ai"] = true
		var total := 0.0
		var wins := 0.0
		var n := 0
		for o in opps:
			for r in range(reps):
				var home: String = user if r % 2 == 0 else str(o)
				var away: String = str(o) if r % 2 == 0 else user
				var side := 0 if home == user else 1
				var sim = gs.season.match_sim(home, away, 7000 + r * 131 + opps.find(o) * 17)
				if mode == "moments" and bool(setting):
					sim.moment_side = side
				var res: Dictionary = sim.run()
				var margin := int(res["score"][side]) - int(res["score"][1 - side])
				total += float(margin)
				wins += 1.0 if margin > 0 else (0.5 if margin == 0 else 0.0)
				n += 1
		print("%s seed %d (%s) %s: mean margin %+.2f, win share %.3f (n=%d)" % [
				mode, seed, user, str(setting), total / float(n), wins / float(n), n])
	quit(0)
