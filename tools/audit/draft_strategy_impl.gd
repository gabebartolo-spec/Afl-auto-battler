extends RefCounted
## Draft strategy audit (roadmap row 37, director 2026-10-12). Measurement only:
## do AI clubs that build their list from scratch end up weaker than the real
## 2026 lists? Autopilot careers (no user management; the user's own club is
## left out of every table by the aggregator), two ways to start:
##   redraft  the League Draft: every club builds from scratch, all by the AI
##   real     the real 2026 lists plus the 2026 National Draft, then play on
## and, in both, every later National Draft is run by the AI.
## Output (pipe-separated, parsed by tools/audit/draft_strategy_agg.py):
##   LIST  per club per snapshot: size, best-23 mean OVR, depth (players 24-38),
##         age brackets, under-23 POT, the engine's squad strength
##   POOL  the players the start draws on (the redraft pool differs from the
##         real lists: it holds no untried listed players)
##   DP    one line per AI draft pick: the pick against the best still available
##   DC    each draft pick followed one and three seasons on
## Args after the impl name: mode seed club seasons (default redraft 1 MEL 10).
## godot --headless --path . --script tools/audit/run_audit.gd -- draft_strategy_impl real 11 MEL 10

var mode := "redraft"
var seed_n := 1
var club := "MEL"
var cohort: Array = []   # {id, year, pick, age0, ovr0, pot0}


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / xs.size()


static func _pot(p: Dictionary) -> float:
	return maxf(float(p.get("overall", 0)), float(p.get("potential", p.get("overall", 0))))


## Worth as the National Draft AI sees it before scouting noise: 35% OVR, 65% POT.
static func _worth(p: Dictionary) -> float:
	return float(p.get("overall", 0)) * 0.35 + _pot(p) * 0.65


func _measures(list: Array, code: String, tag: String, year: int) -> void:
	var ovr: Array = []
	for p in list:
		ovr.append(float(p["overall"]))
	ovr.sort()
	ovr.reverse()
	var best := _mean(ovr.slice(0, mini(23, ovr.size())))
	var depth := _mean(ovr.slice(23, mini(38, ovr.size())))
	var u23: Array = []
	var mid := 0
	var old := 0
	for p in list:
		var a := float(p.get("age", 25.0))
		if a < 23.0:
			u23.append(p)
		elif a < 30.0:
			mid += 1
		else:
			old += 1
	var pots: Array = []
	var ovs: Array = []
	for p in u23:
		pots.append(_pot(p))
		ovs.append(float(p["overall"]))
	var sq := Squad.new(code, list, true, code)
	print("LIST|%s|%d|%s|%d|%s|%d|%.2f|%.2f|%d|%d|%d|%.2f|%.2f|%.2f" % [mode, seed_n, tag, year, code,
			list.size(), best, depth, u23.size(), mid, old, _mean(pots), _mean(ovs), sq.strength()])


func _snapshot(tag: String, year: int, lists: Dictionary) -> void:
	for code in GameDB.active_clubs(GameState.season_year):
		if lists.has(code):
			_measures(lists[code], str(code), tag, year)


func _pool_line(players: Array) -> void:
	var ovr: Array = []
	for p in players:
		ovr.append(float(p["overall"]))
	ovr.sort()
	ovr.reverse()
	print("POOL|%s|%d|%d|%.2f|%.2f" % [mode, seed_n, ovr.size(), _mean(ovr.slice(0, mini(414, ovr.size()))), _mean(ovr)])


## One pick against the best player still on the board (`gone` = ids already taken).
func _log_pick(d: Draft, c: Dictionary, code: String, pick_no: int, rnd: int, gone: Dictionary, tag: String, year: int) -> void:
	var bw := -INF
	var bo := -INF
	var bp := -INF
	var better := 0
	var cw := d._worth(c) if tag == "league" else _worth(c)
	for p in d.pool:
		if gone.has(str(p["id"])):
			continue
		var w := d._worth(p) if tag == "league" else _worth(p)
		bw = maxf(bw, w)
		bo = maxf(bo, float(p["overall"]))
		bp = maxf(bp, _pot(p))
		if w > cw + 0.001:
			better += 1
	print("DP|%s|%d|%s|%d|%d|%d|%s|%.0f|%d|%d|%.2f|%.2f|%d|%d|%d|%s" % [mode, seed_n, tag, year, pick_no,
			rnd, code, float(c.get("age", 0)), int(c["overall"]), int(_pot(c)), cw, bw,
			int(bo), int(bp), better, str(c.get("role", ""))])
	if tag != "league":
		cohort.append({"id": str(c["id"]), "year": year, "pick": pick_no, "age0": float(c.get("age", 0)),
				"ovr0": int(c["overall"]), "pot0": int(_pot(c))})


## Run a draft with the AI picking for every club, logging each pick against
## the best player still on the board. start_for_user has already run the AI
## picks before the user club's first turn; those are logged from the history.
func _run_draft(d: Draft, tag: String, year: int) -> void:
	var gone := {}
	for e in d.pick_history:
		var pid := str(e["player_id"])
		_log_pick(d, d.picked[pid], str(e["club"]), int(e["pick"]), int(e["round"]), gone, tag, year)
		gone[pid] = true
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var code := d.current_club()
		var c := d._best_ai_pick(code)
		if c.is_empty():
			d._skip_current_pick()
			continue
		var n_before := d.pick_history.size()
		var rnd := d.current_round()
		var snapshot_gone := gone.duplicate()
		if d._draft_pick(code, c):
			_log_pick(d, c, code, n_before + 1, rnd, snapshot_gone, tag, year)
			gone[str(c["id"])] = true
		else:
			d._skip_current_pick()


func _track(lists: Dictionary, year: int) -> void:
	var by_id := {}
	for code in lists:
		for p in lists[code]:
			by_id[str(p["id"])] = [p, str(code)]
	for p in GameState.free_agents:
		by_id[str(p["id"])] = [p, "FA"]
	for e in cohort:
		var off: int = year - int(e["year"])
		if off != 1 and off != 3:
			continue
		var f = by_id.get(str(e["id"]))
		if f == null:
			print("DC|%s|%d|%d|%d|%s|0|0|0|%.0f|%d|%d|%d|gone" % [mode, seed_n, int(e["year"]), off, str(e["id"]), float(e["age0"]),
					int(e["ovr0"]), int(e["pot0"]), int(e["pick"])])
		else:
			var p: Dictionary = f[0]
			print("DC|%s|%d|%d|%d|%s|1|%.0f|%d|%.0f|%d|%d|%d|%s" % [mode, seed_n, int(e["year"]), off, str(e["id"]),
					float(p.get("age", 0)), int(p["overall"]), float(e["age0"]), int(e["ovr0"]), int(e["pot0"]), int(e["pick"]), str(f[1])])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = str(args[1]) if args.size() > 1 else "redraft"
	seed_n = int(args[2]) if args.size() > 2 else 1
	club = str(args[3]) if args.size() > 3 else "MEL"
	var seasons := int(args[4]) if args.size() > 4 else 10
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = seed_n
	GameState.replay_seed = seed_n
	print("DA|%s|%d|user %s|seasons %d" % [mode, seed_n, club, seasons])
	if mode == "real":
		GameState.begin_real_lists()
		GameState.choose_real_club(club)
		_run_draft(GameState.draft, "open", GameDB.DATA_SEASON)
		GameState.finish_intake_draft()
		var all_now: Array = []
		for code in GameState.season.lists:
			all_now.append_array(GameState.season.lists[code])
		_pool_line(all_now)
	else:
		var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
		pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
		_pool_line(pool)
		GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed_n)
		GameState.draft.start_for_user(club)
		_run_draft(GameState.draft, "league", GameState.season_year)
		GameState.start_season(club, GameState.draft.list())
	_snapshot("start", GameState.season_year, GameState.season.lists)
	for s in range(seasons):
		var year := GameState.season_year
		while not GameState.season.is_season_over():
			GameState.advance()
		_snapshot("end", year, GameState.season.lists)
		_track(GameState.season.lists, year)
		print("SEASON|%s|%d|%d|done" % [mode, seed_n, year])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft, "national", year)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
