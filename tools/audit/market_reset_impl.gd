extends RefCounted
## Free agency from year 2: what the market's opening and its close look like,
## per seed, so a run on main and a run on the fix pair by seed (dev-sim,
## 2026-10-11, _targets_signed). Args: first_seed count [club]. Each career
## starts as a fresh process would (no market state from the last one).
var gs

func run() -> void:
	gs = Engine.get_main_loop().root.get_node("GameState")
	var args := OS.get_cmdline_user_args()
	var first := int(args[1]) if args.size() > 1 else 1
	var n := int(args[2]) if args.size() > 2 else 4
	var club := str(args[3]) if args.size() > 3 else "MEL"
	for s in range(first, first + n):
		_career(s, club)

func _fresh() -> void:
	gs._targets_signed = {}
	gs.market_stats = {}
	gs._bars = {}
	CoachEffects.table = {}

func _open_counts() -> Array:
	var targets := 0
	var fillers := 0
	var with_offer := 0
	for p in gs.free_agents:
		var any := false
		for o in p.get("offers", []):
			if str(o["club"]) == gs.my_club:
				continue
			any = true
			if bool(o.get("filler", false)):
				fillers += 1
			else:
				targets += 1
		if any:
			with_offer += 1
	return [targets, fillers, with_offer, gs.free_agents.size()]

func _signed(ids: Array) -> int:
	var n := 0
	var want := {}
	for i in ids:
		want[str(i)] = true
	for code in gs.season.lists:
		if str(code) == gs.my_club:
			continue
		for p in gs.season.lists[code]:
			if want.has(str(p.get("id", ""))):
				n += 1
	return n

func _run_draft(d) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c: Dictionary = d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()

func _offseason() -> Array:
	gs.open_offseason()
	var open := _open_counts()
	var ids := []
	for p in gs.free_agents:
		ids.append(str(p.get("id", "")))
	if gs.begin_intake_draft():
		_run_draft(gs.draft)
		gs.finish_intake_draft()
	else:
		gs.start_next_season()
	return open + [_signed(ids)]

func _career(sd: int, club: String) -> void:
	_fresh()
	gs.reset()
	gs.autosave_enabled = false
	gs.save_path = "user://market_reset.save"
	gs.career_seed = sd
	gs.replay_seed = sd
	gs.start_season(club, GameDB.club_list(club))
	var lines := []
	for y in range(2):
		while not gs.season.is_season_over():
			gs.advance()
		var r := _offseason()
		lines.append("y%d targets %d fillers %d with_offer %d fa %d signed %d" % [y + 1, r[0], r[1], r[2], r[3], r[4]])
	print("MKT seed %d | %s" % [sd, " | ".join(lines)])
