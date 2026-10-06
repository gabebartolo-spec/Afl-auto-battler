extends RefCounted
## What a development project (learning a position) does to the one player
## (measurement only). The same career twice per seed: once keeping both of
## your project places busy (highest-POT eligible player, a new line where he
## can), once with none. Same seed, same League Draft, so each project player
## is paired with himself. Per project player: OVR and POT against his no-
## project self at the end of his project season and after three seasons,
## whether he learned the position, and the weeks he was then picked to play
## there.
## Args after the impl name: seeds (comma-separated) club seasons
## Prints a PAIR line per project player and a summary.

var club := "MEL"


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _fill_projects(log: Dictionary) -> void:
	while GameState.active_projects() < GameState.PROJECT_MAX:
		var best := {}
		var best_jobs := []
		for p in GameState.my_list:
			var jobs: Array = GameState.learnable_jobs(p)
			if not jobs.is_empty() and (best.is_empty() or int(p.get("potential", 0)) > int(best.get("potential", 0))):
				best = p
				best_jobs = jobs
		if best.is_empty():
			return
		var job := str(best_jobs[0])
		var have := Ratings.positions(best)
		for j in best_jobs:
			if str(GameState.LEARN_JOBS[j]["role"]) in ["FWD", "MID", "DEF"] and not have.has(str(GameState.LEARN_JOBS[j]["role"])):
				job = str(j)
				break
		GameState.set_player_plan(str(best["id"]), GameState.LEARN_PREFIX + job)
		if not log.has(str(best["id"])):
			log[str(best["id"])] = {"year": GameState.season_year, "job": job,
					"role": str(GameState.LEARN_JOBS[job]["role"]), "age": float(best.get("age", 0.0)),
					"ovr0": int(best["overall"]), "pot0": int(best.get("potential", 0))}


## One career. Returns {"snap": {year: {id: [ovr, pot]}}, "log": project log,
## "played": {id: weeks on the ground in a slot that is not his own line}}.
func _career(seed: int, seasons: int, projects: bool) -> Dictionary:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = seed
	GameState.replay_seed = seed
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var snap := {}
	var log := {}
	var played := {}
	for s in range(seasons):
		if projects:
			_fill_projects(log)
		while not GameState.season.is_season_over():
			for p in GameState.my_squad().ground:
				if str(p.get("role", "")) != str(p.get("own_role", p.get("role", ""))):
					played[str(p["id"])] = int(played.get(str(p["id"]), 0)) + 1
			GameState.advance()
			if projects:
				_fill_projects(log)
		var row := {}
		for p in GameState.my_list:
			row[str(p["id"])] = [int(p["overall"]), int(p.get("potential", 0)), Ratings.positions(p).size()]
		snap[GameState.season_year] = row
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	return {"snap": snap, "log": log, "played": played}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "301"
	club = str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 3
	var d1 := []
	var d3 := []
	var p1 := []
	var learned := 0
	var n := 0
	var played_new := []
	for sd in seeds.split(",", false):
		var a := _career(int(sd), seasons, true)
		var b := _career(int(sd), seasons, false)
		for id in a["log"]:
			var lg: Dictionary = a["log"][id]
			var y0 := int(lg["year"])
			var ya: Dictionary = a["snap"].get(y0, {})
			var yb: Dictionary = b["snap"].get(y0, {})
			if not ya.has(id) or not yb.has(id):
				continue
			n += 1
			var got := int(ya[id][2]) > int(yb[id][2])
			if got:
				learned += 1
			var o1 := int(ya[id][0]) - int(yb[id][0])
			var q1 := int(ya[id][1]) - int(yb[id][1])
			d1.append(o1)
			p1.append(q1)
			var y3 := y0 + 2
			var o3 = null
			if (a["snap"].get(y3, {}) as Dictionary).has(id) and (b["snap"].get(y3, {}) as Dictionary).has(id):
				o3 = int(a["snap"][y3][id][0]) - int(b["snap"][y3][id][0])
				d3.append(o3)
			var weeks := int((a["played"] as Dictionary).get(id, 0)) - int((b["played"] as Dictionary).get(id, 0))
			if got:
				played_new.append(weeks)
			print("PAIR seed %s %s age %.1f OVR %d POT %d -> %s (%s) | OVR vs no-project self: end of season %+d, two seasons on %s | POT %+d | extra weeks out of his line %d" % [
					sd, lg["job"], float(lg["age"]), int(lg["ovr0"]), int(lg["pot0"]), "learned" if got else "not taken", lg["role"],
					o1, "-" if o3 == null else "%+d" % int(o3), q1, weeks])
	print("SUMMARY projects %d, learned %d | OVR vs self: season %s (n=%d), two seasons on %s (n=%d) | POT %s | learned players' extra weeks out of their line %s" % [
			n, learned, _ms(d1), d1.size(), _ms(d3), d3.size(), _ms(p1), _ms(played_new)])


func _ms(a: Array) -> String:
	if a.is_empty():
		return "-"
	var t := 0.0
	for x in a:
		t += float(x)
	var m := t / a.size()
	var v := 0.0
	for x in a:
		v += pow(float(x) - m, 2.0)
	var se := sqrt(v / maxf(1.0, a.size() - 1.0)) / sqrt(float(a.size()))
	return "%+.2f +/- %.2f" % [m, se]
