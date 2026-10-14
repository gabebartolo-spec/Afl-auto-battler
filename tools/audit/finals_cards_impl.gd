extends RefCounted
## Finals and Grand Final cards (rows 35 and 36): what a coach sees each
## September over a long career. Args after the impl name: seed club seasons
## (`finals_cards_impl 41 FRE 20`). Starts from the club's real list.
##
## The autopilot answers every card with a seeded random choice and plays on.
## Prints, per September: SEPT <year> <club> <finals weeks played> | <week>:<card ids> ...
## and at the end: FINALS <card id> <Septembers it came up in> for the new cards,
## REPEAT <card id> <year> for any card with a long cooldown (40 weeks or more) that came
## up in two Septembers running, and SUMMARY. Measurement only: it never changes a rule.

const NEW_PREFIXES := ["finals_", "gf_"]


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _is_new(id: String) -> bool:
	for p in NEW_PREFIXES:
		if id.begins_with(p):
			return true
	return false


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var club := str(args[2]) if args.size() > 2 else "FRE"
	var seasons := int(args[3]) if args.size() > 3 else 20
	GameState.reset()
	GameState.show_real_names = false
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	GameState.start_season(club, GameDB.club_list(club))
	var answer := RandomNumberGenerator.new()
	answer.seed = hash("finals-audit|%d" % seed)
	var deck := StoryDeck.all()
	var per_sept := {}      # year -> {card id: true} (every card that came up in finals weeks)
	var times := {}         # new card id -> Septembers
	var per_week := {}      # finals week -> cards shown
	var counts: Array = []  # new finals cards per September
	var played_finals := 0
	var by_year := {}
	for s in range(seasons):
		var year := GameState.season_year
		var line: PackedStringArray = []
		var shown := 0
		var seen_here := {}
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			if ClubStories.phase(GameState) == "finals":
				var fw := ClubStories.week_in_season(GameState) - Season.REGULAR_ROUNDS
				var ids: PackedStringArray = []
				for i in range(GameState.week_events.size()):
					var c: Dictionary = GameState.week_events[i]
					var tid := str(c.get("tid", c.get("key", "")))
					ids.append(tid)
					seen_here[tid] = true
					if _is_new(tid):
						shown += 1
						per_week[fw] = int(per_week.get(fw, 0)) + 1
					var opts: Array = c.get("options", [])
					GameState.resolve_card(i, answer.randi_range(0, opts.size() - 1))
				if not ids.is_empty():
					line.append("%d:%s" % [fw, "+".join(ids)])
			else:
				for i in range(GameState.week_events.size()):
					var c2: Dictionary = GameState.week_events[i]
					# The two cards of the run to September (we're in, no finals this year).
					if _is_new(str(c2.get("tid", ""))):
						seen_here[str(c2["tid"])] = true
						shown += 1
						line.append("R%d:%s" % [ClubStories.week_in_season(GameState), str(c2["tid"])])
					var opts2: Array = c2.get("options", [])
					GameState.resolve_card(i, answer.randi_range(0, opts2.size() - 1))
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
			GameState.advance()
		if GameState.my_finals_status() != "":
			played_finals += 1
		by_year[year] = seen_here
		for tid in seen_here:
			if _is_new(tid):
				times[tid] = int(times.get(tid, 0)) + 1
		counts.append(shown)
		print("SEPT %d %s status %s | new finals cards %d | %s" % [year, club, GameState.my_finals_status(), shown, " ".join(line)])
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	# A card with a long cooldown must not come up in two Septembers running.
	var repeats := 0
	for t in deck:
		if int(t.get("cooldown", 0)) < 40 or not (t.get("phase", []) as Array).has("finals"):
			continue
		var id := str(t["id"])
		for y in by_year:
			if by_year.has(y + 1) and (by_year[y] as Dictionary).has(id) and (by_year[y + 1] as Dictionary).has(id):
				repeats += 1
				print("REPEAT %s %d" % [id, y])
	for t in deck:
		if _is_new(str(t["id"])):
			print("FINALS %s %d" % [str(t["id"]), int(times.get(str(t["id"]), 0))])
	for fw in per_week:
		print("WEEK %d new cards %d" % [fw, int(per_week[fw])])
	var total := 0
	for n in counts:
		total += int(n)
	print("SUMMARY seed %d %s | seasons %d | Septembers with finals %d | new finals cards %d | per September %.1f | repeats %d" % [
			seed, club, counts.size(), played_finals, total, float(total) / float(maxi(1, played_finals)), repeats])
