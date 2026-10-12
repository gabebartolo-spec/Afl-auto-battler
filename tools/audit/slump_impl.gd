extends RefCounted
## Measures what a captain's slump trigger would see (stories P2-4 follow-up): the
## distribution of the captain's morale and of the team's losing run, how often each
## condition is met alone and together, and how many slump episodes each candidate
## trigger would give a career. Args after the impl name: seed club seasons [lists]
## (`slump_impl 1 MEL 10 lists`; "lists" starts from the club's real list, otherwise
## a redraft start, where the captain is named by the rule).
##
## An autopilot career that answers every card with a seeded choice. Each week it
## reads the state the next week's cards will see: the named captain's morale, the
## losing run, whether he is fit and in the side. Prints MORALE and LOSING
## histograms, JOINT (weeks each trigger is met), EPISODE (per candidate trigger, a
## new episode needs 80 weeks since the last, the card's cooldown) and SUMMARY.

const MORALE_CUTS := [45, 58, 70, 75, 105]  # 105 = any morale (the losing run alone)
const RUN_CUTS := [0, 1, 2, 3, 4]


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
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 10
	GameState.reset()
	GameState.show_real_names = false
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	if args.has("lists"):
		GameState.start_season(club, GameDB.club_list(club))
	else:
		var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
		pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
		GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
		GameState.draft.start_for_user(club)
		_run_draft(GameState.draft)
		GameState.start_season(club, GameState.draft.list())
	var answer := RandomNumberGenerator.new()
	answer.seed = hash("slump-audit|%d" % seed)
	var weeks := 0
	var eligible := 0
	var no_captain := 0
	var morale_hist := {}
	var run_hist := {}
	var met_morale := {}
	var met_run := {}
	var met_both := {}
	var last_episode := {}
	var episodes := {}
	var last_episode60 := {}
	var episodes60 := {}
	var first_no_captain := -1
	var captain_weeks_by_season := {}
	for t in MORALE_CUTS:
		for k in RUN_CUTS:
			var key := "%d|%d" % [t, k]
			met_both[key] = 0
			episodes[key] = 0
			last_episode[key] = -9999
			episodes60[key] = 0
			last_episode60[key] = -9999
		met_morale[t] = 0
	for k in RUN_CUTS:
		met_run[k] = 0
	var captain_morale_sum := 0
	for s in range(seasons):
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			weeks += 1
			var rec := GameState.captaincy_record(GameState.my_club)
			var cap := {}
			for p in GameState.my_list:
				if Captaincy.role_of(rec, str(p["id"])) == "captain":
					cap = p
			var in_side := {}
			var side: Dictionary = GameState.current_side()
			for k in side:
				for id in side[k]:
					in_side[str(id)] = true
			if cap.is_empty():
				no_captain += 1
				if first_no_captain < 0:
					first_no_captain = weeks
			else:
				captain_weeks_by_season[GameState.season_year] = int(captain_weeks_by_season.get(GameState.season_year, 0)) + 1
			elif int(cap.get("injury_weeks", 0)) <= 0 and in_side.has(str(cap["id"])):
				eligible += 1
				var m := ClubLife.morale(cap)
				var run := int(GameState.losing_streak)
				captain_morale_sum += m
				var bucket := (m / 5) * 5
				morale_hist[bucket] = int(morale_hist.get(bucket, 0)) + 1
				run_hist[mini(run, 8)] = int(run_hist.get(mini(run, 8), 0)) + 1
				for t in MORALE_CUTS:
					if m <= t:
						met_morale[t] += 1
				for k in RUN_CUTS:
					if run >= k:
						met_run[k] += 1
				for t in MORALE_CUTS:
					for k in RUN_CUTS:
						if m <= t and run >= k:
							var key := "%d|%d" % [t, k]
							met_both[key] += 1
							if weeks - int(last_episode[key]) >= 80:
								episodes[key] += 1
								last_episode[key] = weeks
							if weeks - int(last_episode60[key]) >= 60:
								episodes60[key] += 1
								last_episode60[key] = weeks
			for i in range(GameState.week_events.size()):
				var c: Dictionary = GameState.week_events[i]
				var opts: Array = c.get("options", [])
				GameState.resolve_card(i, answer.randi_range(0, opts.size() - 1))
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
			GameState.advance()
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	var mb := morale_hist.keys()
	mb.sort()
	for b in mb:
		print("MORALE seed %d bucket %d-%d weeks %d" % [seed, b, b + 4, morale_hist[b]])
	var rb := run_hist.keys()
	rb.sort()
	for r in rb:
		print("LOSING seed %d run %d%s weeks %d" % [seed, r, "+" if r == 8 else "", run_hist[r]])
	for t in MORALE_CUTS:
		print("JOINT seed %d morale<=%d alone %d weeks (%.1f%%)" % [seed, t, met_morale[t], 100.0 * met_morale[t] / maxf(1.0, eligible)])
	for k in RUN_CUTS:
		print("JOINT seed %d losing_run>=%d alone %d weeks (%.1f%%)" % [seed, k, met_run[k], 100.0 * met_run[k] / maxf(1.0, eligible)])
	for t in MORALE_CUTS:
		for k in RUN_CUTS:
			var key := "%d|%d" % [t, k]
			print("EPISODE seed %d morale<=%d run>=%d weeks_met %d episodes %d episodes60 %d" % [seed, t, k, met_both[key], episodes[key], episodes60[key]])
	var cw := captain_weeks_by_season.keys()
	cw.sort()
	var cw_text := PackedStringArray()
	for y in cw:
		cw_text.append("%d:%d" % [y, captain_weeks_by_season[y]])
	print("CAPTAIN seed %d first week with no captain %d | weeks with a captain by season %s" % [seed, first_no_captain, " ".join(cw_text)])
	print("SUMMARY seed %d %s %s | seasons %d | weeks %d | weeks with the captain fit and in the side %d | no captain named %d | mean captain morale %.1f" % [
			seed, club, "lists" if args.has("lists") else "redraft", seasons, weeks, eligible, no_captain,
			float(captain_morale_sum) / maxf(1.0, eligible)])
