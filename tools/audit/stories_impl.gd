extends RefCounted
## The long-save proof for the week's story cards (club-life stories phase 1).
## An autopilot career that answers every card with a seeded choice, for ten
## seasons by default. Args after the impl name: seed club seasons [real]
## (`stories_impl 1 MEL 10`; `stories_impl 1 MEL 10 real` plays with real names
## on, where private cards only pick players shown under a fictional name).
##
## Prints one STORY line a season, then SUMMARY: cards seen, distinct cards,
## the most-repeated cards, cards by category, arcs started / finished /
## lapsed (by arc), the total of each lever the answers moved, and players
## by trust band at the end. REPEAT lines list every card with its count.

var club := "MEL"


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	club = str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 10
	# "real" as a fourth argument plays with real names on: private cards then
	# only pick players shown under a fictional name, and variety must hold.
	var real := args.size() > 4 and str(args[4]) == "real"
	GameState.reset()
	GameState.show_real_names = real
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var answer := RandomNumberGenerator.new()
	answer.seed = hash("stories-audit|%d" % seed)
	var seen := {}
	var cats := {}
	var levers := {}
	var weeks_total := 0
	var cards_total := 0
	var two_card_weeks := 0
	# Private cards (family, the papers) shown about a real-named player: must stay 0.
	var private_real := 0
	var private_seen := 0
	for s in range(seasons):
		var year := GameState.season_year
		var weeks := 0
		var cards_season := 0
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			weeks += 1
			if GameState.week_events.size() == 2:
				two_card_weeks += 1
			for i in range(GameState.week_events.size()):
				var c: Dictionary = GameState.week_events[i]
				var tid := str(c.get("tid", c.get("key", "")))
				seen[tid] = int(seen.get(tid, 0)) + 1
				cats[str(c.get("category", "?"))] = int(cats.get(str(c.get("category", "?")), 0)) + 1
				cards_season += 1
				if bool(StoryDeck.by_id(StoryDeck.all(), tid).get("private", false)):
					private_seen += 1
					if bool((c.get("facts", {}) as Dictionary).get("real_named", false)):
						private_real += 1
				var opts: Array = c.get("options", [])
				var pick := answer.randi_range(0, opts.size() - 1)
				for e in (opts[pick] as Dictionary).get("effects", []):
					var op := str(e.get("op", ""))
					if e.has("d"):
						levers[op] = int(levers.get(op, 0)) + StoryEngine.effect_d(e, c.get("facts", {}))
					else:
						levers[op] = int(levers.get(op, 0)) + 1
				GameState.resolve_card(i, pick)
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
			GameState.advance()
		weeks_total += weeks
		cards_total += cards_season
		print("STORY seed %d %s %d | weeks %d | cards %d | distinct so far %d | finished %d" % [seed, club, year,
				weeks, cards_season, seen.size(), GameState.club_position(club)])
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	var arcs := {}
	for key in GameState.story.get("arcs", {}):
		var arc := str(key).split("|")[0]
		var rec: Dictionary = GameState.story["arcs"][key]
		if not arcs.has(arc):
			arcs[arc] = {"started": 0, "done": 0, "lapsed": 0, "open": 0}
		arcs[arc]["started"] += 1
		arcs[arc][str(rec.get("state", "open"))] = int(arcs[arc].get(str(rec.get("state", "open")), 0)) + 1
	var bands := {}
	for k in GameState.relations:
		var b := Trust.band(Trust.value(GameState.relations, str(k)))
		bands[b] = int(bands.get(b, 0)) + 1
	var ranked := seen.keys()
	ranked.sort_custom(func(a, b): return int(seen[a]) > int(seen[b]))
	print("PRIVATE seen %d | about a real-named player %d" % [private_seen, private_real])
	for tid in ranked:
		print("REPEAT %s %d" % [tid, int(seen[tid])])
	var top: PackedStringArray = []
	for tid in ranked.slice(0, 5):
		top.append("%s x%d" % [tid, int(seen[tid])])
	print("SUMMARY seed %d %s real-names %s | seasons %d | weeks %d | cards %d (%.2f a week, %d two-card weeks) | distinct %d of %d | most repeated %s | by category %s | arcs %s | levers %s | trust bands %s" % [
			seed, club, "on" if real else "off", seasons, weeks_total, cards_total, float(cards_total) / float(maxi(1, weeks_total)),
			two_card_weeks, seen.size(), StoryDeck.all().size(), ", ".join(top), str(cats), str(arcs),
			str(levers), str(bands)])
