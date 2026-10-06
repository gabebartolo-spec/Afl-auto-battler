extends RefCounted
## 18 + 4 against 18 + 5 (ARD-M5-001): the same careers on the same seeds with
## a four- or five-player bench (Ratings.bench_size, env BENCH=4|5; RULES=0
## is the old bench - best of the rest, no line cover or dual ruck - for the
## main-like baseline). Every club
## drafts and manages as the AI does. Per season it prints, per team-match:
## goals, disposals, tackles, inside 50s, interchanges, players who took part
## and distance run per player; per season: injuries, the league's in-season
## rating rise (training and XP) and, after a rollover, its development.
## Args after the impl name: seeds (comma-separated) seasons.

const CLUB := "MEL"


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _mean_ovr() -> float:
	var t := 0.0
	var n := 0
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			t += float(p["overall"])
			n += 1
	return t / maxi(1, n)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "1"
	var seasons := int(args[2]) if args.size() > 2 else 2
	var bench := int(OS.get_environment("BENCH")) if OS.get_environment("BENCH") != "" else Ratings.INTERCHANGE
	Ratings.bench_size = bench
	Ratings.bench_rules = OS.get_environment("RULES") != "0"
	for sd in seeds.split(",", false):
		_career(int(sd), seasons, bench)


func _career(seed: int, seasons: int, bench: int) -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.replay_seed = seed
	GameState.career_seed = seed
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(CLUB)
	_run_draft(GameState.draft)
	GameState.start_season(CLUB, GameState.draft.list())
	for s in range(seasons):
		var year := GameState.season_year
		var start_ovr := _mean_ovr()
		var tm := 0
		var tot := {"goals": 0.0, "disposals": 0.0, "tackles": 0.0, "inside50": 0.0, "interchanges": 0.0,
				"played": 0.0, "distance": 0.0, "injuries": 0.0}
		var players := 0
		while not GameState.season.is_season_over():
			GameState.advance()
			for res in GameState.last_results:
				if not res.has("players"):
					continue
				var g: Array = res.get("goals", [0, 0])
				var ic: Array = res.get("interchanges", [0, 0])
				for side in 2:
					tm += 1
					tot["goals"] += float(g[side])
					tot["interchanges"] += float(ic[side]) if ic.size() > side else 0.0
				var roster: Array = res.get("roster", [[], []])
				for side in 2:
					for r in (roster[side] if roster.size() > side else []):
						var st: Dictionary = (res["players"] as Dictionary).get(str(r["id"]), {})
						if st.is_empty():
							continue
						tot["played"] += 1.0
						players += 1
						tot["disposals"] += float(st.get("disposals", 0))
						tot["tackles"] += float(st.get("tackles", 0))
						tot["inside50"] += float(st.get("inside50", 0))
						tot["distance"] += float(st.get("distance_run", 0))
				for ev in res.get("events", []):
					if str(ev.get("kind", "")) == "injury":
						tot["injuries"] += 1.0
		var rise := _mean_ovr() - start_ovr
		print("bench %d seed %d %d | per team-match: goals %.2f disposals %.1f tackles %.1f i50 %.1f interchanges %.1f played %.2f | km per player %.2f | injuries per team-match %.3f | in-season OVR rise %+.2f" % [
				bench, seed, year, tot["goals"] / tm, tot["disposals"] / tm, tot["tackles"] / tm, tot["inside50"] / tm,
				tot["interchanges"] / tm, tot["played"] / tm, tot["distance"] / maxi(1, players) / 1000.0,
				tot["injuries"] / tm, rise])
		if s == seasons - 1:
			break
		var before := _mean_ovr()
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		print("bench %d seed %d %d | rollover mean OVR %+.2f" % [bench, seed, year, _mean_ovr() - before])
