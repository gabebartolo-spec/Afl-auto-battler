extends RefCounted
## The long-save proof for club culture (stories P2-3): do all clubs' three
## strands stay spread over ten seasons, none pinned at an extreme, none all
## the same? Args after the impl name: seed club seasons (`culture_impl 1 MEL 10`).
##
## Plays an autopilot career (every card answered with its first choice, the
## off-season run through) and, after each season's rollover, prints one
## CULTURE line per strand: the lowest, highest and mean value across all
## clubs, how many clubs sit in each named band, and how many are pinned
## (|value| >= 90). SUMMARY gives the worst season for pinning and the count of
## distinct (standards, together, ambition) triples among the clubs at the end.


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _snapshot(year: int, seed: int) -> Dictionary:
	var out := {"pinned": 0, "clubs": 0}
	var codes: Array = GameState.season.lists.keys()
	out["clubs"] = codes.size()
	for s in Culture.STRANDS:
		var strand := str(s[0])
		var lo := 999
		var hi := -999
		var sum := 0
		var named := 0
		var pinned := 0
		for code in codes:
			var t := Culture.value(GameState.relations, str(code), strand)
			lo = mini(lo, t)
			hi = maxi(hi, t)
			sum += t
			if Culture.words(strand, t) != "":
				named += 1
			if absi(t) >= 90:
				pinned += 1
		out["pinned"] = int(out["pinned"]) + pinned
		print("CULTURE seed %d %d %s | min %d | max %d | mean %.1f | named %d of %d | pinned %d" % [
				seed, year, strand, lo, hi, float(sum) / float(maxi(1, codes.size())), named, codes.size(), pinned])
	return out


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 10
	GameState.reset()
	GameState.show_real_names = false
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var worst_pinned := 0
	var news_lines := 0
	for s in range(seasons):
		var year := GameState.season_year
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			if GameState.week_event_pending():
				GameState.resolve_week_event(0)
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
			GameState.advance()
		var snap := _snapshot(year, seed)
		worst_pinned = maxi(worst_pinned, int(snap["pinned"]))
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	for n in GameState.news:
		if str(n.get("kind", "")) == "culture":
			news_lines += 1
	var triples := {}
	for code in GameState.season.lists:
		var key := []
		for s in Culture.STRANDS:
			key.append(Culture.value(GameState.relations, str(code), str(s[0])))
		triples[str(key)] = true
	print("SUMMARY seed %d %s | seasons %d | clubs %d | distinct culture triples %d | worst pinned strands in a season %d | culture news lines kept %d" % [
			seed, club, seasons, GameState.season.lists.size(), triples.size(), worst_pinned, news_lines])
