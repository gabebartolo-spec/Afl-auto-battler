extends RefCounted
## Retirements over a career (evidence for the director's "Retirement
## persuasion" item). Measurement only. A real League Draft, then seasons with
## off-seasons and National Drafts, everyone drafting as an AI would (as
## career_impl's "ai" policy). Before each off-season every listed player is
## snapshotted - age, OVR, POT, career games, what injury state is recorded
## (injury_weeks, injury_kind, rehab), morale and the form it gives, whether he
## is in his club's best 22 and his position's selection bar
## (TradeValue.selection_bars: the weakest player his club picks there).
## The rollover's retirees (Prospects.age_league) are matched to those
## snapshots; the rule that retired him is read from Prospects.should_retire
## on his aged age and OVR.
## Args after the impl name: seed club seasons (default 1 MEL 5).
## godot --headless --path . --script tools/audit/run_audit.gd -- retirement_impl 1 MEL 5

var club := "MEL"


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _snapshot() -> Dictionary:
	var out := {}
	for code in GameState.season.lists:
		var list: Array = GameState.season.lists[code]
		var sq := Squad.new(str(code), list, true, str(code))
		var in22 := {}
		for p in sq.ground + sq.bench:
			in22[str(p["id"])] = true
		var bars: Dictionary = TradeValue.selection_bars(list)
		for p in list:
			var role := str(p.get("role", ""))
			out[str(p["id"])] = {
				"club": str(code), "role": role, "age": float(p.get("age", 0.0)),
				"ovr": int(p.get("overall", 0)), "pot": int(p.get("potential", p.get("overall", 0))),
				"games": int((p.get("career", {}) as Dictionary).get("games", 0)),
				"injury_weeks": int(p.get("injury_weeks", 0)), "injury_kind": str(p.get("injury_kind", "")),
				"rehab": bool(p.get("rehab", false)), "morale": ClubLife.morale(p),
				"form": ClubLife.form(p), "in22": in22.has(str(p["id"])),
				"bar": int(bars.get(role, 0)),
			}
	return out


func _rule(age: float, ovr: int) -> String:
	if ovr <= 32:
		return "low-OVR floor (<=32)"
	if age >= 37.0:
		return "age 37+"
	if age >= 35.0:
		return "age 35-36 (70% roll)"
	if age >= 33.0 and ovr < 42:
		return "age 33-34 and OVR<42 (30% roll)"
	return "other"


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	club = str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 5
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
		while not GameState.season.is_season_over():
			GameState.advance()
		if s == seasons - 1:
			break
		var snap := _snapshot()
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var retired: Array = GameState.intake_summary.get("retired", [])
		var clubs := {}
		for r in retired:
			var id := str(r["id"])
			var sn: Dictionary = snap.get(id, {})
			clubs[str(r["club"])] = true
			if sn.is_empty():
				print("RET seed %d %d | %s | no snapshot" % [seed, year, id])
				continue
			print("RET seed %d %d | club %s | %s | age %.0f | OVR %d (end of season %d) | POT %d | games %d | in best 22 %s | bar %d (OVR-bar %+d) | injury_weeks %d %s | rehab %s | morale %d form %+.3f | rule: %s" % [
					seed, year, str(r["club"]), sn["role"], float(r["age"]), int(r["overall"]), int(sn["ovr"]),
					int(sn["pot"]), int(sn["games"]), "yes" if bool(sn["in22"]) else "no", int(sn["bar"]),
					int(sn["ovr"]) - int(sn["bar"]), int(sn["injury_weeks"]), str(sn["injury_kind"]),
					"yes" if bool(sn["rehab"]) else "no", int(sn["morale"]), float(sn["form"]),
					_rule(float(r["age"]), int(r["overall"]))])
		print("RETSUM seed %d %d | retirements %d across %d clubs" % [seed, year, retired.size(), clubs.size()])
