extends RefCounted
## Expansion clubs: what does a new club get today, and how long is it poor?
## Measurement only (the director's ruling of 2026-10-14 asks for a concession
## package; this is the "before"). Autopilot careers as long_career_impl: a
## League Draft with every club drafting as the rival AI does, then every
## season and off-season with no user management.
## Lines:
##   ENTRY  seed year club | the list a new club arrives with, against the league
##   DRAFT  seed year club | the picks the club used in that year's National Draft
##   EXP    seed year club clubyear | ladder place, wins, strength rank
##   SUMMARY at the end: place by club year, first top 8 and first finals (top 10).
## Args after the impl name: seeds (comma list) club seasons (default 301 MEL 8).
## godot --headless --path . --script tools/audit/run_audit.gd -- expansion_impl 301,302 MEL 8

const NEW_CLUBS := ["TAS", "CANB"]

var rows := []   # {seed, code, cy, pos, n, w, l, pct, rank}


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _top(list: Array, n: int) -> Array:
	var ovr := []
	for p in list:
		ovr.append(p)
	ovr.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return ovr.slice(0, mini(n, ovr.size()))


func _strength(list: Array) -> float:
	var t := 0.0
	for p in _top(list, 22):
		t += float(p["overall"])
	return t / 22.0


func _mean_age(list: Array) -> float:
	var t := 0.0
	var top := _top(list, 22)
	for p in top:
		t += float(p.get("age", 0.0))
	return t / maxf(1.0, float(top.size()))


func _active_lists() -> Dictionary:
	var out := {}
	for code in GameDB.active_clubs(GameState.season_year):
		out[code] = GameState.season.lists.get(code, [])
	return out


func _rank_of(code: String, lists: Dictionary) -> int:
	var mine := _strength(lists[code])
	var r := 1
	for c in lists:
		if str(c) != code and _strength(lists[c]) > mine:
			r += 1
	return r


func _league_mean(lists: Dictionary, skip: String) -> float:
	var t := 0.0
	var n := 0
	for c in lists:
		if str(c) == skip:
			continue
		t += _strength(lists[c])
		n += 1
	return t / maxf(1.0, float(n))


func _entry(seed: int) -> void:
	var year := GameState.season_year
	var lists := _active_lists()
	for code in NEW_CLUBS:
		if GameDB.enter_year(code) != year or not lists.has(code):
			continue
		var arr: Array = lists[code]
		var n80 := 0
		var n75 := 0
		var n70 := 0
		var young := 0
		var pot85 := 0
		var best := 0
		for p in arr:
			var o := int(p["overall"])
			best = maxi(best, o)
			if o >= 80: n80 += 1
			if o >= 75: n75 += 1
			if o >= 70: n70 += 1
			if float(p.get("age", 0.0)) < 22.0: young += 1
			if int(p.get("potential", o)) >= 85: pot85 += 1
		var sizes := 0.0
		var l80 := 0.0
		var k := 0
		for c in lists:
			if str(c) == code:
				continue
			k += 1
			sizes += float((lists[c] as Array).size())
			for p in lists[c]:
				if int(p["overall"]) >= 80: l80 += 1.0
		print("ENTRY %d %d %s | list %d (rivals %.1f) | best 22 %.1f (rivals %.1f), rank %d of %d | best player %d | 80+ %d (rivals %.1f) | 75+ %d | 70+ %d | under 22 %d | POT 85+ %d | best-22 age %.1f" % [
				seed, year, code, arr.size(), sizes / maxf(1.0, k), _strength(arr), _league_mean(lists, code),
				_rank_of(code, lists), lists.size(), best, n80, l80 / maxf(1.0, k), n75, n70, young, pot85, _mean_age(arr)])


func _season_end(seed: int) -> void:
	var year := GameState.season_year
	var table := GameState.season.ladder_sorted()
	var lists := _active_lists()
	var premier := str(GameState.season.finals.get("premier", ""))
	for i in range(table.size()):
		var code := str(table[i]["code"])
		if not NEW_CLUBS.has(code):
			continue
		var cy := year - GameDB.enter_year(code) + 1
		var row: Dictionary = table[i]
		var rank := _rank_of(code, lists)
		rows.append({"seed": seed, "code": code, "cy": cy, "pos": i + 1, "n": table.size(),
				"w": int(row["w"]), "l": int(row["l"]), "pct": float(row["pct"]), "rank": rank,
				"flag": premier == code})
		print("EXP %d %d %s year %d | ladder %d of %d | %d-%d, %.0f%% | strength rank %d | best 22 %.1f (rivals %.1f) | best-22 age %.1f | list %d%s" % [
				seed, year, code, cy, i + 1, table.size(), int(row["w"]), int(row["l"]), float(row["pct"]),
				rank, _strength(lists[code]), _league_mean(lists, code), _mean_age(lists[code]),
				(lists[code] as Array).size(), " | PREMIERS" if premier == code else ""])


func _draft_lines(seed: int, year: int, history: Array) -> void:
	for code in NEW_CLUBS:
		var picks := []
		for e in history:
			if str(e.get("club", "")) == code:
				picks.append(int(e.get("pick", 0)))
		if picks.is_empty():
			continue
		print("DRAFT %d %d %s | picks %s" % [seed, year, code, str(picks)])


func _career(seed: int, club: String, seasons: int) -> void:
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
	for s in range(seasons):
		_entry(seed)
		while not GameState.season.is_season_over():
			GameState.advance()
		_season_end(seed)
		if s == seasons - 1:
			break
		var year := GameState.season_year
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			var history: Array = GameState.draft.pick_history.duplicate()
			GameState.finish_intake_draft()
			_draft_lines(seed, year, history)
		else:
			GameState.start_next_season()


func _summary() -> void:
	for code in NEW_CLUBS:
		var by_cy := {}
		var first8 := {}
		var first10 := {}
		var seeds := {}
		var last_cy := 0
		for r in rows:
			if str(r["code"]) != code:
				continue
			seeds[r["seed"]] = true
			last_cy = maxi(last_cy, int(r["cy"]))
			if not by_cy.has(r["cy"]):
				by_cy[r["cy"]] = []
			(by_cy[r["cy"]] as Array).append(r)
			if int(r["pos"]) <= 8 and not first8.has(r["seed"]):
				first8[r["seed"]] = int(r["cy"])
			if int(r["pos"]) <= 10 and not first10.has(r["seed"]):
				first10[r["seed"]] = int(r["cy"])
		if seeds.is_empty():
			continue
		print("SUMMARY %s | careers %d | club years measured %d" % [code, seeds.size(), last_cy])
		var cys := by_cy.keys()
		cys.sort()
		for cy in cys:
			var arr: Array = by_cy[cy]
			var pos := []
			var wins := 0.0
			var rank := 0.0
			var top8 := 0
			var top10 := 0
			var bottom4 := 0
			var flags := 0
			for r in arr:
				pos.append(int(r["pos"]))
				wins += float(r["w"])
				rank += float(r["rank"])
				if int(r["pos"]) <= 8: top8 += 1
				if int(r["pos"]) <= 10: top10 += 1
				if int(r["pos"]) > int(r["n"]) - 4: bottom4 += 1
				if bool(r["flag"]): flags += 1
			pos.sort()
			var mean := 0.0
			for p in pos:
				mean += float(p)
			mean /= float(pos.size())
			print("SUMMARY %s year %d | n %d | ladder mean %.1f, median %d, best %d, worst %d | wins %.1f | strength rank %.1f | top 8 %d | finals (top 10) %d | bottom four %d | flags %d | places %s" % [
					code, int(cy), arr.size(), mean, int(pos[pos.size() / 2]), int(pos[0]), int(pos[pos.size() - 1]),
					wins / float(arr.size()), rank / float(arr.size()), top8, top10, bottom4, flags, str(pos)])
		var f8 := []
		var f10 := []
		for s in seeds:
			f8.append(int(first8.get(s, 0)))
			f10.append(int(first10.get(s, 0)))
		print("SUMMARY %s | first top 8, club year per career (0 = never in the run) %s | first finals (top 10) %s" % [
				code, str(f8), str(f10)])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := (str(args[1]) if args.size() > 1 else "301").split(",")
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 8
	for s in seeds:
		_career(int(s), club, seasons)
	_summary()
