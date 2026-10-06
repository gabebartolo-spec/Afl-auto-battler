extends RefCounted
## Where flags come from, against real AFL (2000-2025: premiers finished 1st
## 36%, top three 92%, mean ladder 2.2, never below 7th; the higher-placed side
## wins about 73% of home-and-away games). Every club drafts and lists as the AI
## does (your club too: parity), through real rollovers and National Drafts.
## Per season it prints the premier's ladder finish and preseason strength rank,
## how often the side finishing higher won (home and away, and finals), and the
## spread of season wins. Args after the impl name: seed seasons
##   FLAGS_SUMMARY=1 prints only the closing summary line.

const CLUB := "MEL"

var _prem_pos := []
var _prem_rank := []
var _ha := [0.0, 0]
var _fin := [0.0, 0]
var _win_sd := []


func _strength(list: Array) -> float:
	var ovr := []
	for p in list:
		ovr.append(int(p["overall"]))
	ovr.sort()
	ovr.reverse()
	var t := 0.0
	for i in range(mini(22, ovr.size())):
		t += float(ovr[i])
	return t / 22.0


func _ranks(lists: Dictionary) -> Dictionary:
	var codes := lists.keys()
	codes.sort_custom(func(a, b): return _strength(lists[a]) > _strength(lists[b]))
	var out := {}
	for i in codes.size():
		out[str(codes[i])] = i + 1
	return out


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


## [higher-placed wins (draws half), games] over results, by final ladder.
func _higher_wins(results: Array, pos: Dictionary) -> Array:
	var w := 0.0
	var n := 0
	for r in results:
		var h := str(r["home"])
		var a := str(r["away"])
		if not pos.has(h) or not pos.has(a):
			continue
		var sc: Array = r["score"]
		n += 1
		if int(sc[0]) == int(sc[1]):
			w += 0.5
		elif (int(sc[0]) > int(sc[1])) == (int(pos[h]) < int(pos[a])):
			w += 1.0
	return [w, n]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var seasons := int(args[2]) if args.size() > 2 else 8
	var quiet := OS.get_environment("FLAGS_SUMMARY") == "1"
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.replay_seed = seed
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(CLUB)
	_run_draft(GameState.draft)
	GameState.start_season(CLUB, GameState.draft.list())
	for s in range(seasons):
		var year := GameState.season_year
		var ranks := _ranks(GameState.season.lists)
		var ha := []
		var fin := []
		while not GameState.season.is_season_over():
			GameState.advance()
			for r in GameState.last_results:
				if int(r.get("round", 0)) > Season.REGULAR_ROUNDS:
					fin.append(r)
				else:
					ha.append(r)
		var rows: Array = GameState.season.ladder_sorted()
		var pos := {}
		var wins := []
		for i in rows.size():
			pos[str(rows[i]["code"])] = i + 1
			wins.append(float(rows[i]["w"]) + 0.5 * float(rows[i]["d"]))
		var premier := GameState.premier()
		var hw := _higher_wins(ha, pos)
		var fw := _higher_wins(fin, pos)
		_ha[0] += hw[0]
		_ha[1] += hw[1]
		_fin[0] += fw[0]
		_fin[1] += fw[1]
		var mean := 0.0
		for w in wins:
			mean += w / wins.size()
		var var_w := 0.0
		for w in wins:
			var_w += (w - mean) * (w - mean) / wins.size()
		_win_sd.append(sqrt(var_w))
		_prem_pos.append(int(pos.get(premier, 0)))
		_prem_rank.append(int(ranks.get(premier, 0)))
		if not quiet:
			print("seed %d %d | premier %s ladder %d strength rank %d | higher-placed wins H&A %.1f%% finals %d/%d | win SD %.2f" % [
				seed, year, premier, pos.get(premier, 0), ranks.get(premier, 0),
				100.0 * hw[0] / maxi(1, hw[1]), int(fw[0]), fw[1], sqrt(var_w)])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	var top1 := _prem_pos.filter(func(x): return x == 1).size()
	var top3 := _prem_pos.filter(func(x): return x >= 1 and x <= 3).size()
	var str3 := _prem_rank.filter(func(x): return x >= 1 and x <= 3).size()
	var mean_pos := 0.0
	for x in _prem_pos:
		mean_pos += float(x) / _prem_pos.size()
	var sd := 0.0
	for x in _win_sd:
		sd += x / _win_sd.size()
	print("SUMMARY seed %d seasons %d | premier ladder 1st %d top3 %d mean %.2f worst %d | premier strength top3 %d | higher-placed wins H&A %.1f/%d finals %.1f/%d | mean win SD %.2f | positions %s" % [
		seed, _prem_pos.size(), top1, top3, mean_pos, _prem_pos.max(), str3,
		_ha[0], _ha[1], _fin[0], _fin[1], sd, str(_prem_pos)])
