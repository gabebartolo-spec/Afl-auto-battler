extends RefCounted
## Long careers: do lists and retirements stay healthy for a decade? (ARD-M8-005,
## raised by the low agent: retirements seem to stop once lists sit on the
## 32-player floor, Prospects.MIN_LIST.) Measurement only.
## Autopilot as career_impl's "ai" policy: League Draft, then every season,
## off-season (open_offseason, intake draft or start_next_season) with no user
## management. After each rollover, per club: list size; league: lists at the
## floor, retirements taken, retirements the floor blocked (should_retire was
## true but the player stayed), the intake and releases, and the age profile.
## Args after the impl name: seed club seasons (default 1 MEL 12).
## godot --headless --path . --script tools/audit/run_audit.gd -- long_career_impl 1 MEL 12


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _profile(year: int, retired: int, intake: int, released: int) -> void:
	var lists: Dictionary = GameState.season.lists
	var sizes := []
	var at_floor := 0
	var blocked := 0
	var ages := []
	for code in lists:
		var arr: Array = lists[code]
		sizes.append(arr.size())
		if arr.size() <= Prospects.MIN_LIST:
			at_floor += 1
		for p in arr:
			ages.append(float(p.get("age", 0.0)))
			# Would retire now by the rule, at this age and OVR (the next
			# rollover's aged values are one year older; this is a floor).
			if Prospects.should_retire(p, year):
				blocked += 1
	sizes.sort()
	ages.sort()
	var n34 := ages.filter(func(a): return a >= 34.0).size()
	var n36 := ages.filter(func(a): return a >= 36.0).size()
	var mean_size := 0.0
	for s in sizes:
		mean_size += float(s)
	mean_size /= maxf(1.0, sizes.size())
	print("LONG %d | clubs %d | list size min %d mean %.1f max %d | at the %d floor %d | retired %d | intake %d | released %d | players %d, 34+ %d, 36+ %d, oldest %.0f | listed players the rule would retire now %d" % [
			year, sizes.size(), sizes[0], mean_size, sizes[sizes.size() - 1], Prospects.MIN_LIST, at_floor,
			retired, intake, released, ages.size(), n34, n36, ages[ages.size() - 1], blocked])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 12
	GameState.reset()
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	_profile(GameState.season_year, 0, 0, 0)
	for s in range(seasons):
		while not GameState.season.is_season_over():
			GameState.advance()
		if s == seasons - 1:
			break
		GameState.open_offseason()
		var intake := 0
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			intake = GameState.draft.pick_history.size()
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var released := 0
		for e in GameState.offseason_log:
			if str(e.get("kind", "")) in ["released", "delisted", "release"]:
				released += 1
		_profile(GameState.season_year, (GameState.intake_summary.get("retired", []) as Array).size(), intake, released)
