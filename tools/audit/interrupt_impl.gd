extends RefCounted
## How often the game asks the coach for something, week by week (ROADMAP §9.4
## G1, one interruption budget). An autopilot career, every default left alone:
## per round, what is waiting for him before the next match (the week's card, a
## press question, a tribunal challenge) and how many news items the round added.
## Args after the impl name: seed club seasons
## Prints one line per season and a summary: weeks with 0/1/2/3 asks, which
## asks collide, and the same for losing streaks (three or more straight).

var club := "MEL"

func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()

## News items the last round added: everything in front of what was first.
func _new_news(before) -> int:
	var n := 0
	for item in GameState.news:
		if before != null and is_same(item, before):
			break
		n += 1
	return n

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	club = str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 3
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var asks_hist := {0: 0, 1: 0, 2: 0, 3: 0}
	var slump_hist := {0: 0, 1: 0, 2: 0, 3: 0}
	var pairs := {}
	var kinds := {}
	var cards := {}
	var news_total := 0
	var weeks_total := 0
	var max_news := 0
	for s in range(seasons):
		var year := GameState.season_year
		var weeks := 0
		var asks_season := 0
		while not GameState.season.is_season_over():
			var front = GameState.news[0] if not GameState.news.is_empty() else null
			GameState.advance()
			var nn := _new_news(front)
			news_total += nn
			max_news = maxi(max_news, nn)
			weeks += 1
			var asks := []
			if GameState.week_event_pending():
				asks.append("card")
				var k := str(GameState.week_event.get("key", ""))
				cards[k] = int(cards.get(k, 0)) + 1
			if GameState.media_conference_pending():
				asks.append("press")
			if not GameState.pending_mro_challenges().is_empty():
				asks.append("tribunal")
			for a in asks:
				kinds[a] = int(kinds.get(a, 0)) + 1
			if asks.size() >= 2:
				var key := "+".join(PackedStringArray(asks))
				pairs[key] = int(pairs.get(key, 0)) + 1
			var b := mini(asks.size(), 3)
			asks_hist[b] += 1
			if GameState.losing_streak >= 3:
				slump_hist[b] += 1
			asks_season += asks.size()
			# Leave every ask unanswered, as a coach who skips them would.
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
		weeks_total += weeks
		print("seed %d %s %d | weeks %d | asks %d | finished %d" % [seed, club, year, weeks, asks_season,
				GameState.club_position(club)])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	print("SUMMARY seed %d %s | weeks %d | weeks by asks %s | in a 3+ losing streak %s | asks %s | collisions %s | cards %s | news per week %.1f (max %d)" % [
			seed, club, weeks_total, str(asks_hist), str(slump_hist), str(kinds), str(pairs), str(cards),
			float(news_total) / float(maxi(1, weeks_total)), max_news])
