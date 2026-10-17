extends SceneTree
## Plan familiarity audit: what knowing a plan "partly" or "barely" costs in a match.
##   godot --headless --path . --script tools/audit/plan_know_impl.gd -- [--n 200] [--partly 0.85] [--barely 0.65]
## For each plan that takes drilling, the same N seeded matches (a rotating pair
## of clubs, the plan's side at home, the other side on Balanced) are played with
## the side knowing the plan well, partly and barely. Prints the average margin
## and the win rate at each level, and the difference against well with its
## standard error. The sizes are the director's call (data/preseason.json).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	load("res://scripts/core/Features.gd").set_on("preseason", true)
	var n := 200
	var partly := -1.0
	var barely := -1.0
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--n": n = int(a[i + 1])
			"--partly": partly = float(a[i + 1])
			"--barely": barely = float(a[i + 1])
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var pre = load("res://scripts/sim/PreSeason.gd")
	gs.autosave_enabled = false
	gs.save_path = "user://audit_plan_know.save"
	gs.settings_path = "user://audit_plan_know.cfg"
	gs.reset()
	gs.career_seed = 4242
	gs.replay_seed = 4242
	gs.start_season("FRE", db.club_list("FRE"))
	var clubs: Array = gs.season.clubs
	var mult: Dictionary = pre.tune("familiar_mult").duplicate()
	if partly > 0.0:
		mult["partly"] = partly
	if barely > 0.0:
		mult["barely"] = barely
	print("plan familiarity audit: %d matches a plan and level; kept share of the plan's upside: well %.2f, partly %.2f, barely %.2f"
			% [n, float(mult["well"]), float(mult["partly"]), float(mult["barely"])])
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim_script = load("res://scripts/sim/MatchSim.gd")
	var season_script = load("res://scripts/sim/Season.gd")
	for plan in pre.DRILL_PLANS:
		var rows := {}
		for level in ["well", "partly", "barely"]:
			var sims := []
			for k in range(n):
				var home: String = clubs[(k * 7) % clubs.size()]
				var away: String = clubs[(k * 7 + 1 + (k / clubs.size()) % (clubs.size() - 1)) % clubs.size()]
				if home == away:
					away = clubs[(k * 7 + 1) % clubs.size()]
				var sa = squad_script.new(db.club_name(home), gs.season.lists[home], true, home)
				var sb = squad_script.new(db.club_name(away), gs.season.lists[away], false, away)
				sa.plan_know = {plan: float(mult[level])}
				var sim = sim_script.new(sa, sb, 31000 + k)
				sim.set_tactics(0, {"gameplan": plan})
				sims.append(sim)
			var margins := []
			for res in season_script.run_all(sims):
				margins.append(float(int(res["score"][0]) - int(res["score"][1])))
			rows[level] = margins
		var line := "%-14s" % plan
		for level in ["well", "partly", "barely"]:
			var m: Array = rows[level]
			var wins := 0
			var sum := 0.0
			for x in m:
				sum += float(x)
				wins += 1 if float(x) > 0.0 else 0
			line += "  %s: margin %+.1f, wins %2d%%" % [level, sum / float(n), int(round(100.0 * wins / float(n)))]
		for level in ["partly", "barely"]:
			var d := []
			for k in range(n):
				d.append(float(rows["well"][k]) - float(rows[level][k]))
			var mean := 0.0
			for x in d:
				mean += float(x)
			mean /= float(n)
			var v := 0.0
			for x in d:
				v += (float(x) - mean) * (float(x) - mean)
			var se := sqrt(v / float(n - 1) / float(n))
			line += "  | %s costs %.1f +- %.1f pts" % [level, mean, se]
		print(line)
	quit(0)
