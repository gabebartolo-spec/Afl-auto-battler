extends RefCounted
## Draft bust audit (director, 2026-10-14): how often does a National Draft pick
## turn into a star, fall short of his POT, or leave the league? Measured in FULL
## simulated careers with the game's own ageing, training, list management and
## drafts (no approximation), by pick band 1-10 / 11-30 / 31+.
## Autopilot careers from the real 2026 lists: the user's own club is left
## unmanaged, so its picks are dropped (the aggregator skips club USER).
## Output lines (pipe-separated, read by tools/audit/draft_bust_agg.py):
##   BP|seed|draft_year|pick|id|club|src|age0|ovr0|pot0     one per pick
##   BT|seed|draft_year|k|id|on_list|ovr|best_so_far       each season end
## godot --headless --path . --script tools/audit/run_audit.gd -- draft_bust_impl 11,12 9

var cohort := {}      # id -> {year, best}


func _on_lists() -> Dictionary:
	var out := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			out[str(p["id"])] = p
	return out


func _draft(d: Draft, year: int, seed_n: int, user: String) -> void:
	var guard := 0
	while not d.is_finished() and guard < 400:
		guard += 1
		if d.is_user_turn():
			var choice := {}
			for cand in d.board("", "", "", "overall", true):
				if d.can_pick_player(cand):
					choice = cand
					break
			if choice.is_empty() or not d.pick(choice):
				d._skip_current_pick()
				d.auto_until_user_turn()
		else:
			d.auto_until_user_turn()
	for e in d.pick_history:
		var p: Dictionary = d.picked.get(str(e["player_id"]), {})
		if p.is_empty():
			continue
		var club := "USER" if str(e["club"]) == user else str(e["club"])
		print("BP|%d|%d|%d|%s|%s|%s|%.1f|%d|%d" % [seed_n, year, int(e["pick"]), str(p["id"]), club,
				"real" if not bool(p.get("generated", false)) else "gen", float(p.get("age", 0)),
				int(p["overall"]), maxi(int(p["overall"]), int(p.get("potential", p["overall"])))])
		if club != "USER":
			cohort[str(p["id"])] = {"year": year, "best": int(p["overall"])}


func _track(year: int, seed_n: int) -> void:
	var on := _on_lists()
	for id in cohort:
		var c: Dictionary = cohort[id]
		var k: int = year - int(c["year"])
		if k < 1:
			continue
		var p = on.get(id)
		var ovr := 0
		if p != null:
			ovr = int(p["overall"])
			c["best"] = maxi(int(c["best"]), ovr)
		print("BT|%d|%d|%d|%s|%d|%d|%d" % [seed_n, int(c["year"]), k, id, 1 if p != null else 0, ovr, int(c["best"])])


func _career(seed_n: int, seasons: int) -> void:
	var clubs := ["MEL", "COL", "ADE", "CAR", "FRE", "SYD", "GEE", "HAW"]
	var user: String = clubs[seed_n % clubs.size()]
	cohort = {}
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = seed_n
	GameState.replay_seed = seed_n
	print("BA|%d|user %s|seasons %d" % [seed_n, user, seasons])
	GameState.begin_real_lists()
	GameState.choose_real_club(user)
	_draft(GameState.draft, GameDB.DATA_SEASON, seed_n, user)
	GameState.finish_intake_draft()
	for s in range(seasons):
		var year := GameState.season_year
		while not GameState.season.is_season_over():
			GameState.advance()
		_track(year, seed_n)
		print("BS|%d|%d|done" % [seed_n, year])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_draft(GameState.draft, year, seed_n, user)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]).split(",") if args.size() > 1 else PackedStringArray(["11"])
	var seasons := int(args[2]) if args.size() > 2 else 9
	for s in seeds:
		_career(int(s), seasons)
