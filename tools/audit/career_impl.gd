extends RefCounted
## Autopilot careers: a real League Draft, then seasons, National Drafts and
## rollovers with every default left alone. Per season: your list's strength
## rank and ladder finish against the AI, your List Profile words, margins,
## and contract-extension cards. Args after the impl name: policy seed club seasons
##   policy "ai"     - you draft exactly as an AI club would (parity)
##   policy "greedy" - you take the best-rated player you can (a typical human)
##   policy "light"  - greedy, and you accept every early-extension card

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
