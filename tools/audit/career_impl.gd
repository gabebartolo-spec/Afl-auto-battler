extends RefCounted
## Autopilot careers: a real League Draft, then seasons, National Drafts and
## rollovers with every default left alone. Per season: your list's strength
## rank and ladder finish against the AI, your List Profile words, margins,
## and contract-extension cards. Args after the impl name: policy seed club seasons
##   policy "ai"     - you draft exactly as an AI club would (parity)
##   policy "greedy" - you take the best-rated player you can (a typical human)
##   policy "light"  - greedy, and you accept every early-extension card
##   policy "trader" - AI-style draft; each off-season a trade bot takes any
##                     deal an AI club accepts that lifts your best 22
##   policy "fa"     - AI-style draft; each off-season you bid the asking price
##                     for the best free agents the cap allows

var policy := "ai"
var club := "MEL"

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

func _rank_of(code: String, lists: Dictionary) -> int:
	var mine := _strength(lists[code])
	var r := 1
	for c in lists:
		if str(c) != code and _strength(lists[c]) > mine:
			r += 1
	return r

## Your best-22 mean if `out_ids` leave and `in_players` arrive.
func _strength_after(out_ids: Dictionary, in_players: Array) -> float:
	var l := []
	for p in GameState.my_list:
		if not out_ids.has(str(p["id"])):
			l.append(p)
	l.append_array(in_players)
	return _next_strength(l)

## Next season's best-22 mean, ageing in: a year older, past 29 he slips.
func _next_strength(list: Array) -> float:
	var ovr := []
	for p in list:
		ovr.append(float(p["overall"]) - 1.5 * maxf(0.0, float(p.get("age", 25.0)) + 1.0 - 29.0))
	ovr.sort()
	ovr.reverse()
	var t := 0.0
	for i in range(mini(22, ovr.size())):
		t += ovr[i]
	return t / 22.0

var trades_done := 0

func _trade_bot() -> void:
	var made := 0
	for code in GameState.season.lists.keys():
		if str(code) == club or made >= 4:
			continue
		var theirs: Array = (GameState.season.lists[code] as Array).duplicate()
		theirs.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		var mine: Array = GameState.my_list.duplicate()
		mine.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		var gives := []
		for i in range(10, mini(40, mine.size())):
			gives.append([mine[i]])
		for i in range(12, mini(34, mine.size() - 1), 2):
			gives.append([mine[i], mine[i + 1]])
		var base := _next_strength(GameState.my_list)
		var best := {}
		var best_gain := 0.2
		for t in theirs.filter(func(x): return float(x.get("age", 25.0)) <= 30.0).slice(0, 8):
			for g in gives:
				var out_ids := {}
				for p in g:
					out_ids[str(p["id"])] = true
				var gain := _strength_after(out_ids, [t]) - base
				if gain <= best_gain:
					continue
				var v: Dictionary = GameState.evaluate_trade(str(code), out_ids.keys(), [str(t["id"])])
				if bool(v.get("ok", false)):
					best_gain = gain
					best = {"mine": out_ids.keys(), "theirs": [str(t["id"])], "gain": gain,
						"desc": "%s (%d, age %d) for %s" % [GameDB.player_display_name(t), int(t["overall"]), int(t.get("age", 0)),
							", ".join(g.map(func(p): return "%d/age %d" % [int(p["overall"]), int(p.get("age", 0))]))]}
		if not best.is_empty():
			var r := GameState.make_trade(str(code), best["mine"], best["theirs"])
			if bool(r.get("ok", false)):
				made += 1
				trades_done += 1
				print("%s seed %d      trade with %s: %s (+%.2f best-22)" % [policy, seed_n, code, best["desc"], float(best["gain"])])

func _fa_bot() -> void:
	var fas: Array = GameState.free_agents.duplicate()
	fas.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var bids := 0
	for p in fas.slice(0, 12):
		if bids >= 4:
			break
		if int(p["overall"]) <= int(_weakest_22()):
			continue
		var terms: Dictionary = GameState.free_agent_terms(str(p["id"]))
		if bool(terms.get("refuse", false)):
			continue
		var want: Dictionary = Contracts.wants(p)
		var r: Dictionary = GameState.offer_free_agent(str(p["id"]), int(want["salary"]) + int(terms.get("premium", 0)), int(want["years"]))
		if bool(r.get("ok", false)):
			bids += 1
			print("%s seed %d      FA bid: %s (%d, age %d) %s" % [policy, seed_n, GameDB.player_display_name(p), int(p["overall"]), int(p.get("age", 0)), str(r.get("reason", ""))])

func _weakest_22() -> int:
	var ovr := []
	for p in GameState.my_list:
		ovr.append(int(p["overall"]))
	ovr.sort()
	ovr.reverse()
	return int(ovr[mini(21, ovr.size() - 1)])

var seed_n := 0

func _user_pick(d: Draft) -> void:
	var c := {}
	if policy == "greedy" or policy == "light":
		for p in d.board("", "", "", "overall", true):
			if d.can_pick_player(p):
				c = p
				break
	if c.is_empty():
		c = d._best_ai_pick(d.current_club())
	if c.is_empty() or not d._draft_pick(d.current_club(), c):
		d._skip_current_pick()

func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		if d.current_club() == club:
			_user_pick(d)
		else:
			var c := d._best_ai_pick(d.current_club())
			if c.is_empty() or not d._draft_pick(d.current_club(), c):
				d._skip_current_pick()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	policy = str(args[1]) if args.size() > 1 else "ai"
	var seed := int(args[2]) if args.size() > 2 else 1
	seed_n = seed
	club = str(args[3]) if args.size() > 3 else "MEL"
	var seasons := int(args[4]) if args.size() > 4 else 5
	GameState.reset()
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var margins := {"0-39": 0, "40-59": 0, "60-79": 0, "80-99": 0, "100-119": 0, "120-149": 0, "150+": 0}
	var mine_m := margins.duplicate()
	var biggest := 0
	var matches := 0
	for s in range(seasons):
		var year := GameState.season_year
		var lists: Dictionary = GameState.season.lists
		var rank_start := _rank_of(club, lists)
		var str_start := _strength(lists[club])
		var top_ai := 0.0
		var ai_start := 0.0
		for c in lists:
			if str(c) != club:
				top_ai = maxf(top_ai, _strength(lists[c]))
				ai_start += _strength(lists[c]) / float(lists.size() - 1)
		var prof := ListProfile.profile(GameState.league_grounds(), club)
		var words := {}
		for row in prof:
			words[str(row["word"])] = int(words.get(str(row["word"]), 0)) + 1
		var ext := {}
		while not GameState.season.is_season_over():
			GameState.advance()
			for res in GameState.last_results:
				var sc: Array = res["score"]
				var m := absi(int(sc[0]) - int(sc[1]))
				biggest = maxi(biggest, m)
				matches += 1
				var b := "0-39" if m < 40 else ("40-59" if m < 60 else ("60-79" if m < 80 else ("80-99" if m < 100 else ("100-119" if m < 120 else ("120-149" if m < 150 else "150+")))))
				margins[b] += 1
				if club in [str(res["home"]), str(res["away"])]:
					mine_m[b] += 1
			if str(GameState.week_event.get("key", "")) == "extension":
				ext[str(GameState.week_event.get("player_id", ""))] = true
				if policy == "light":
					GameState.resolve_week_event(0)
		var pos := GameState.club_position(club)
		var premier := GameState.premier() == club
		var str_end := _strength(GameState.season.lists[club])
		var ai_end := 0.0
		for c in GameState.season.lists:
			if str(c) != club:
				ai_end += _strength(GameState.season.lists[c]) / float(GameState.season.lists.size() - 1)
		print("%s seed %d %s %d | list rank %d (strength %.1f, best AI %.1f) | profile %s | finished %d%s | extension cards %d | in-season rise yours %+.1f, AI mean %+.1f" % [
			policy, seed, club, year, rank_start, str_start, top_ai, str(words), pos, " PREMIERS" if premier else "", ext.size(), str_end - str_start, ai_end - ai_start])
		if s == seasons - 1:
			break
		var before_off := _strength(GameState.season.lists[club])
		var ai_before := 0.0
		for c in GameState.season.lists:
			if str(c) != club:
				ai_before += _strength(GameState.season.lists[c]) / float(GameState.season.lists.size() - 1)
		GameState.open_offseason()
		if policy == "trader":
			_trade_bot()
		elif policy == "fa":
			_fa_bot()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var ai_after := 0.0
		var n_ai := 0
		for c in GameState.season.lists:
			if str(c) != club:
				ai_after += _strength(GameState.season.lists[c])
				n_ai += 1
		print("%s seed %d    off-season %d: your strength %+.1f, AI mean %+.1f" % [policy, seed, year,
			_strength(GameState.season.lists[club]) - before_off, ai_after / float(maxi(1, n_ai)) - ai_before])
	print("%s seed %d MARGINS all %d matches: %s | biggest %d" % [policy, seed, matches, str(margins), biggest])
	print("%s seed %d MARGINS yours: %s" % [policy, seed, str(mine_m)])
