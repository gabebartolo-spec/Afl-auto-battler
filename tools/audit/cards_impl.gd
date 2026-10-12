extends RefCounted
## Row 34 (event-card audit): how often every story card comes up, and which
## choice the answers take, over a long career. Args after the impl name:
## seed club seasons [lists] [real] (`cards_impl 41 MEL 10 lists real`). "lists"
## starts from the club's real list, otherwise a redraft start; "real" plays with
## real names on, where private cards only pick players shown under a fictional name.
##
## The autopilot answers every card with a seeded random choice, so each choice and
## each arc beat can come up. Each week it also asks every card, against the live
## state, whether its trigger could be met at all (ignoring cooldowns, per-season
## limits, the category rule and arcs), so a card that never comes up can be told
## apart: trigger never true, or true but never drawn.
##
## Prints per career: CARD <id> <times>, CHOICE <id> <key> <times>, COND <id>
## <weeks the trigger was met>, PRESS <question key> <times> (the post-match press
## questions, skipped), WEEKS <weeks in play>, SEASONS, then SUMMARY.
## Measurement only: it never changes a rule.

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
	var real := args.has("real")
	GameState.reset()
	GameState.show_real_names = real
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
	answer.seed = hash("cards-audit|%d" % seed)
	var probe := RandomNumberGenerator.new()
	probe.seed = hash("cards-probe|%d" % seed)
	var deck := StoryDeck.all()
	var seen := {}
	var took := {}
	var cond := {}
	var press := {}
	var weeks := 0
	var seasons_played := 0
	for s in range(seasons):
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			var ph := ClubStories.phase(GameState)
			if ph == "regular" or GameState.my_finals_status() == "alive":
				weeks += 1
				var ctx := ClubStories.context(GameState)
				var w := StoryEngine.week_abs(int(ctx["year"]), int(ctx["week"]))
				for t in deck:
					# The trigger alone: an empty memory, so no cooldown, limit,
					# category rule or flag decides it. A follow-up's own trigger
					# is its conditions with the flag taken as given.
					var bare: Dictionary = (t as Dictionary).duplicate(true)
					bare.erase("needs")
					bare.erase("arc")
					bare["cooldown"] = 0
					bare["subject_cooldown"] = 0
					bare["per_season"] = 0
					if not (bare.get("subject", {}) as Dictionary).is_empty():
						var sj: Dictionary = bare["subject"]
						var wh: Dictionary = (sj.get("where", {}) as Dictionary).duplicate()
						wh.erase("flag")
						sj["where"] = wh
					if not StoryEngine.eligible_subject(bare, ctx, StoryEngine.new_state(), w, probe).is_empty():
						cond[str(t["id"])] = int(cond.get(str(t["id"]), 0)) + 1
			for i in range(GameState.week_events.size()):
				var c: Dictionary = GameState.week_events[i]
				var tid := str(c.get("tid", c.get("key", "")))
				seen[tid] = int(seen.get(tid, 0)) + 1
				var opts: Array = c.get("options", [])
				var pick := answer.randi_range(0, opts.size() - 1)
				var ck := "%s %s" % [tid, str((opts[pick] as Dictionary).get("key", pick))]
				took[ck] = int(took.get(ck, 0)) + 1
				GameState.resolve_card(i, pick)
			if GameState.media_conference_pending():
				# The press question is counted, then skipped, so the career is the
				# same as one that never looked at it.
				var mk := str(GameState.media_conference.get("key", "?"))
				press[mk] = int(press.get(mk, 0)) + 1
				GameState.skip_media_conference()
			GameState.advance()
		seasons_played += 1
		print("CARDS seed %d %s season %d | cards so far %d | distinct so far %d" % [seed, club, GameState.season_year,
				_sum(seen), seen.size()])
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	for t in deck:
		var id := str(t["id"])
		print("CARD %s %d" % [id, int(seen.get(id, 0))])
		print("COND %s %d" % [id, int(cond.get(id, 0))])
	for k in press:
		print("PRESS %s %d" % [k, int(press[k])])
	for k in took:
		print("CHOICE %s %d" % [k, int(took[k])])
	print("WEEKS %d" % weeks)
	print("SEASONS %d" % seasons_played)
	print("SUMMARY seed %d %s %s names %s | seasons %d | weeks %d | cards %d | distinct %d of %d" % [seed, club,
			"lists" if args.has("lists") else "redraft", "real" if real else "fictional", seasons_played, weeks,
			_sum(seen), seen.size(), deck.size()])


func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n
