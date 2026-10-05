extends RefCounted
## Development projects (learning another position) on autopilot: a League
## Draft drafted as an AI club would, then seasons in which you keep both
## project places busy. Per season: projects started, learned and not taken;
## the cost to his own rating against eligible team-mates on the club plan;
## Unicorns on your list; weeks a Unicorn completed a synergy on the ground.
## Args after the impl name: seed club seasons policy
##   policy "eager"   - the highest-POT eligible player, any job
##   policy "unicorn" - prefer a job in a line he does not have yet (FWD/MID/DEF)

var club := "MEL"
var policy := "eager"


func _eligible() -> Array:
	var out := []
	for p in GameState.my_list:
		var jobs: Array = GameState.learnable_jobs(p)
		if not jobs.is_empty():
			out.append([p, jobs])
	return out


func _pick_job(p: Dictionary, jobs: Array) -> String:
	if policy == "unicorn":
		var have := Ratings.positions(p)
		for j in jobs:
			var role := str(GameState.LEARN_JOBS[j]["role"])
			if role in ["FWD", "MID", "DEF"] and not have.has(role):
				return str(j)
	return str(jobs[0])


func _fill_projects(started: Dictionary) -> void:
	while GameState.active_projects() < GameState.PROJECT_MAX:
		var cands := _eligible()
		if cands.is_empty():
			return
		cands.sort_custom(func(a, b): return int(a[0].get("potential", 0)) > int(b[0].get("potential", 0)))
		var p: Dictionary = cands[0][0]
		var job := _pick_job(p, cands[0][1])
		GameState.set_player_plan(str(p["id"]), GameState.LEARN_PREFIX + job)
		started[str(p["id"])] = {"job": job, "own": int(p["overall"]), "age": float(p.get("age", 25.0)),
				"pot": int(p.get("potential", 0)), "gap": int(p["overall"]) - int(p["project"]["start_there"])}


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	club = str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 3
	policy = str(args[4]) if args.size() > 4 else "eager"
	GameState.reset()
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	for s in range(seasons):
		var year := GameState.season_year
		# Who could try at the start, and everyone's rating then (the control).
		var start_ovr := {}
		var eligible_start := {}
		for p in GameState.my_list:
			start_ovr[str(p["id"])] = int(p["overall"])
			if int(p.get("potential", 0)) >= GameState.PROJECT_POT[1] and not (p.get("attr", {}) as Dictionary).is_empty():
				eligible_start[str(p["id"])] = true
		var ai_pos := {}
		for c in GameState.season.lists:
			if str(c) != club:
				for p in GameState.season.lists[c]:
					ai_pos[str(p["id"])] = Ratings.positions(p).size()
		var started := {}
		var results := []
		var seen := {}
		var wild_weeks := 0
		var wild_keys := {}
		var weeks := 0
		_fill_projects(started)
		while not GameState.season.is_season_over():
			var ground: Array = GameState.my_squad().ground
			var wild := Traits.wildcards(ground)
			weeks += 1
			if not wild.is_empty():
				wild_weeks += 1
				for k in wild:
					wild_keys[k] = int(wild_keys.get(k, 0)) + 1
			GameState.advance()
			for r in (GameState.last_training_report.get("projects", []) as Array):
				if not seen.has(str(r["id"])):  # a bye week leaves last week's report
					seen[str(r["id"])] = true
					results.append(r)
			_fill_projects(started)
		var learned := 0
		var by_job := {}
		var gaps := {}
		for r in results:
			var g := str(started[str(r["id"])]["gap"]) if started.has(str(r["id"])) else "carried"
			var grow: Array = gaps.get(g, [0, 0])
			grow[1] += 1
			if bool(r["learned"]):
				grow[0] += 1
			gaps[g] = grow
			var j := str(r["job"])
			var row: Array = by_job.get(j, [0, 0])
			row[1] += 1
			if bool(r["learned"]):
				learned += 1
				row[0] += 1
			by_job[j] = row
		var proj_d := []
		var ctrl_d := []
		for p in GameState.my_list:
			var id := str(p["id"])
			if not start_ovr.has(id):
				continue
			var d := int(p["overall"]) - int(start_ovr[id])
			if started.has(id):
				proj_d.append(d)
			elif eligible_start.has(id) and float(p.get("age", 25.0)) <= 27.0:
				ctrl_d.append(d)
		var unicorns := []
		var multi := 0
		for p in GameState.my_list:
			if Traits.is_unicorn(p):
				unicorns.append("%s (%s)" % [GameDB.player_display_name(p), "/".join(Ratings.positions(p))])
			if Ratings.positions(p).size() >= 3:
				multi += 1
		var ai_started := 0
		var ai_learned := 0
		for c in GameState.season.lists:
			if str(c) == club:
				continue
			for p in GameState.season.lists[c]:
				if int(p.get("project_year", 0)) == year:
					ai_started += 1
				if ai_pos.has(str(p["id"])) and Ratings.positions(p).size() > int(ai_pos[str(p["id"])]):
					ai_learned += 1
		var league_unicorns := 0
		for c in GameState.season.lists:
			for p in GameState.season.lists[c]:
				if Traits.is_unicorn(p):
					league_unicorns += 1
		print("%s seed %d %s %d | started %d, finished %d, learned %d (%s; by start gap %s) | own OVR over the season: projects %+.2f (n=%d) vs eligible on club plan, age<=27 %+.2f (n=%d) | 3-position players %d, Unicorns yours %d %s, league %d (AI projects %d, learned %d) | Unicorn completed a synergy %d of %d weeks %s | finished %d" % [
				policy, seed, club, year, started.size(), results.size(), learned, str(by_job), str(gaps),
				_mean(proj_d), proj_d.size(), _mean(ctrl_d), ctrl_d.size(), multi, unicorns.size(), str(unicorns),
				league_unicorns, ai_started, ai_learned, wild_weeks, weeks, str(wild_keys), GameState.club_position(club)])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for x in a:
		t += float(x)
	return t / float(a.size())
