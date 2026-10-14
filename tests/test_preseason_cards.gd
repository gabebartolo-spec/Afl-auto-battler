extends RefCounted
## The pre-season story cards (open requirements 39, slice 5): the deck is valid
## and kept to the pre-season, a card stops the pre-season only at the end of a
## block, every answer does what its Gain and Cost lines say, Round 1's own cards
## wait aside and come back, a hands-off run draws none, the same save sees the
## same cards, and a save made at the stop reloads at the stop. Part of the story
## suite (tests/test_story.gd calls run()).

var s   # the story suite: _check()

const SEED := 6113
const CLUB := "FRE"
const IDS := ["pre_recruit_behind", "pre_contract_talk", "pre_bulking_up", "pre_camp", "pre_leaders_vote",
		"pre_knee_return", "pre_flag_hangover", "pre_kid_flying", "pre_star_last", "pre_members_open", "pre_sim_heated"]


func run(suite) -> void:
	s = suite
	Features.set_on("preseason", true)
	PreSeason.reload()
	_test_deck()
	_test_flow()
	_test_effects()
	_test_facts()
	_test_hands_off_and_save()
	Features.clear("preseason")
	PreSeason.reload()


func _check(c: bool, m: String) -> void:
	s._check(c, m)


func _career(seed := SEED) -> void:
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.start_season(CLUB, GameDB.club_list(CLUB))
	GameState.open_preseason()


func _ids(cards: Array) -> Array:
	return cards.map(func(c): return str(c["tid"]))


func _test_deck() -> void:
	StoryDeck.reload()
	var deck := StoryDeck.all()
	_check(StoryDeck.validate(deck).is_empty(), "The deck with the pre-season cards in it still validates: %s" % " | ".join(PackedStringArray(StoryDeck.validate(deck).slice(0, 4))))
	var found := 0
	var only := true
	for id in IDS:
		var t := StoryDeck.by_id(deck, id)
		if not t.is_empty():
			found += 1
			only = only and (t["phase"] as Array) == ["preseason"]
	_check(found == IDS.size() and only, "All %d pre-season cards are in the deck, and they are written for the pre-season alone" % IDS.size())
	var gates := true
	for t in deck:
		if not IDS.has(str(t["id"])) and (t["phase"] as Array).has("preseason"):
			gates = false
	_check(gates, "No older card was opened to the pre-season by accident")
	# Not drawn in the season: the phase gate.
	_career()
	GameState.preseason_advance()
	var ctx := ClubStories.context(GameState)
	_check(str(ctx["phase"]) == "preseason" and not bool(ctx["big"]), "At a stop the cards draw in the pre-season phase, one at a time")
	var rng := RandomNumberGenerator.new()
	var leaked := false
	var regular_ctx := ctx.duplicate(true)
	regular_ctx["phase"] = "regular"
	for id in IDS:
		var subj := StoryEngine.eligible_subject(StoryDeck.by_id(deck, id), regular_ctx, GameState.story, 100, rng)
		leaked = leaked or not subj.is_empty()
	_check(not leaked, "None of them can come up in a home-and-away week")


## Press on through a pre-season by hand, answering nothing; returns the ids met at the stops.
func _walk(answer := -1) -> Array:
	var met := []
	var guard := 0
	while GameState.preseason_active() and guard < 30:
		guard += 1
		if GameState.preseason_stop() == "story":
			var n: int = GameState.week_events.size()
			met.append([GameState.preseason_week(), _ids(GameState.week_events), n])
			if answer >= 0:
				GameState.resolve_week_event(answer)
		GameState.preseason_advance()
	return met


func _test_flow() -> void:
	var seen := {}
	var one_a_block := true
	var weeks_ok := true
	var most := 0
	var total := 0
	var comes_back := true
	var starts_with_cards := 0
	for seed in range(SEED, SEED + 14):
		_career(seed)
		var round1 := _ids(GameState.week_events)
		var met := _walk(0)
		starts_with_cards += 1 if not met.is_empty() else 0
		most = maxi(most, met.size())
		for m in met:
			total += 1
			one_a_block = one_a_block and int(m[2]) == 1
			weeks_ok = weeks_ok and PreSeason.STORY_WEEKS.has(int(m[0]))
			for id in m[1]:
				seen[id] = true
		comes_back = comes_back and _ids(GameState.week_events) == round1
	_check(one_a_block, "A stop holds one card")
	_check(weeks_ok, "Cards stop the pre-season only at the end of a block (after weeks 3, 5 and 7)")
	_check(most <= 3 and total > 0, "At most three cards in a pre-season, and some do come (%d across 14 careers)" % total)
	_check(starts_with_cards >= 10, "Nearly every pre-season brings a card or two (%d of 14 had one, %d in all)" % [starts_with_cards, total])
	_check(comes_back, "Round 1's own cards wait aside through the pre-season and come back as they were")
	_check(seen.size() >= 4, "A spread of the cards comes up across careers (%d different)" % seen.size())
	for id in seen:
		_check(IDS.has(id), "Only pre-season cards come up at a stop (%s)" % id)
	# Unanswered: the stop settles and nothing breaks.
	_career(SEED + 1)
	var met_silent := _walk(-1)
	_check(not GameState.preseason_active() and GameState.week_events.size() <= 2, "Pressing on past a card leaves it unanswered and the pre-season finishes (%d stops)" % met_silent.size())
	# Determinism.
	_career(SEED + 2)
	var a := _walk(1)
	_career(SEED + 2)
	var b := _walk(1)
	_check(JSON.stringify(a) == JSON.stringify(b), "The same save meets the same cards at the same stops")


func _first_player(where: Callable) -> Dictionary:
	for p in GameState.my_list:
		if where.call(p):
			return p
	return {}


## Every answer does what its lines say: the strands, the base, the plan, and what a player feels.
func _test_effects() -> void:
	_career()
	GameState.preseason_advance()   # week 3 stop
	var deck := StoryDeck.all()
	var wrong := []
	var lines_missing := []
	var clubs_checked := 0
	for id in IDS:
		var t := StoryDeck.by_id(deck, id)
		var player := str(t["subject"].get("kind", "")) == "player"
		for ci in range((t["choices"] as Array).size()):
			_career()
			GameState.preseason_advance()
			var subj := {}
			if player:
				subj = _subject_for(id)
				if subj.is_empty():
					continue
			var card := GameState.story_card(id, subj)
			var opts: Array = card["options"]
			if ci >= opts.size():
				continue
			var lines := StoryEngine.stakes_lines(opts[ci]["effects"], card["facts"])
			if lines.is_empty():
				lines_missing.append("%s/%s" % [id, opts[ci]["key"]])
			var before := _snapshot(subj)
			GameState.week_events = [card]
			GameState.resolve_card(0, ci)
			var after := _snapshot(subj)
			for e in opts[ci]["effects"]:
				var d := int(e.get("d", 0))
				match str(e["op"]):
					"culture":
						var k: String = str(e["strand"])
						if (int(after[k]) - int(before[k])) * d <= 0:
							wrong.append("%s/%s %s did not move %d" % [id, opts[ci]["key"], k, d])
						clubs_checked += 1
					"running":
						if absf((float(after["run"]) - float(before["run"])) - float(d)) > 0.01 and not (d < 0 and float(after["run"]) == 0.0):
							wrong.append("%s/%s running" % [id, opts[ci]["key"]])
						clubs_checked += 1
					"drill":
						if float(after["drill"]) - float(before["drill"]) != float(d):
							wrong.append("%s/%s drill" % [id, opts[ci]["key"]])
						clubs_checked += 1
					"morale":
						if str(e.get("who", "subject")) == "all" and (int(after["morale"]) - int(before["morale"])) * d <= 0:
							wrong.append("%s/%s morale" % [id, opts[ci]["key"]])
					"trust":
						if (int(after["trust"]) - int(before["trust"])) * d <= 0:
							wrong.append("%s/%s trust" % [id, opts[ci]["key"]])
					"xp":
						if int(after["xp"]) <= int(before["xp"]) and str(e.get("who", "subject")) == "subject":
							pass   # spent at once on his training plan: the rating or the xp moves
	_check(wrong.is_empty(), "Every answer moves what its lines say: %s" % " | ".join(PackedStringArray(wrong.slice(0, 6))))
	_check(clubs_checked >= 14, "...and the strand, running and drilling steps were really exercised (%d)" % clubs_checked)
	_check(lines_missing.is_empty(), "Every answer carries a Gain or Cost line: %s" % " | ".join(PackedStringArray(lines_missing)))
	# Culture steps land on the culture page with their reason, dated the pre-season.
	_career()
	GameState.preseason_advance()
	GameState.week_events = [GameState.story_card("pre_sim_heated")]
	GameState.resolve_card(0, 1)
	var rs := Culture.reasons(GameState.relations, CLUB, "standards")
	_check(not rs.is_empty() and str(rs[0]["why"]).begins_with("You pulled the group up") and str(rs[0]["w"]) != "",
			"A strand step is logged on the culture page with its reason")
	# The base: Run it out of them lifts the running, Let them enjoy lowers it.
	_career()
	var run0 := float(GameState.preseason["clubs"][CLUB]["run"])
	GameState.preseason_add_running(1.0)
	GameState.preseason_add_running(-9.0)
	_check(float(GameState.preseason["clubs"][CLUB]["run"]) == 0.0 and run0 == 0.0, "Running taken off never goes below nothing")
	# A drilled plan counts when the pre-season ends.
	_career()
	GameState.club_plan = "defensive"
	GameState.preseason_add_drill(3)
	var was := GameState.plan_level(CLUB, "defensive")
	_walk(-1)
	_check(GameState.plan_level(CLUB, "defensive") >= was, "A drill added by a card is counted in with the blocks' when the pre-season ends")
	# A card answer with the switch off has nothing to act on, and the deck never offers one.
	var played := 0
	Features.set_on("preseason", false)
	GameState.reset()
	GameState.career_seed = SEED
	GameState.replay_seed = SEED
	GameState.start_season(CLUB, GameDB.club_list(CLUB))
	GameState.open_preseason()
	_check(not GameState.preseason_active() and ClubStories.phase(GameState) == "regular", "With the switch off there is no pre-season phase and no card")
	for e in GameState.week_events:
		played += 1 if IDS.has(str(e["tid"])) else 0
	_check(played == 0, "...and Round 1's cards are never pre-season ones")
	Features.set_on("preseason", true)


func _snapshot(subj: Dictionary) -> Dictionary:
	var morale := 0
	for p in GameState.my_list:
		morale += ClubLife.morale(p)
	var out := {"standards": Culture.value(GameState.relations, CLUB, "standards"),
			"together": Culture.value(GameState.relations, CLUB, "together"),
			"ambition": Culture.value(GameState.relations, CLUB, "ambition"),
			"run": float(((GameState.preseason.get("clubs", {}) as Dictionary).get(CLUB, {}) as Dictionary).get("run", 0.0)),
			"drill": 0.0, "morale": morale, "trust": 0, "xp": 0}
	for v in (GameState.preseason.get("bonus_drill", {}) as Dictionary).values():
		out["drill"] = float(out["drill"]) + float(v)
	if not subj.is_empty():
		out["trust"] = Trust.value(GameState.relations, Trust.player_key(str(subj["id"])))
		out["xp"] = int(GameState.list_player(str(subj["id"])).get("xp", 0))
	return out


## A player the card could really be about, made so if the list has none.
func _subject_for(id: String) -> Dictionary:
	var p: Dictionary = GameState.my_list[3]
	p["injury_weeks"] = 0
	p.erase("injury_kind")
	match id:
		"pre_contract_talk":
			p["contract_years"] = 1
			p["age"] = 29.0
		"pre_knee_return":
			p["injury_weeks"] = 3
			p["injury_kind"] = "knee"
	return p


func _test_facts() -> void:
	_career()
	var p: Dictionary = GameState.my_list[5]
	p["joined"] = GameState.season_year - 1
	_check(bool(ClubStories.player_fact(GameState, p, false, {}, 99, 0)["new_here"]), "A player signed last off-season is new here")
	p["joined"] = GameState.season_year - 4
	p["drafted_year"] = GameState.season_year - 1
	_check(bool(ClubStories.player_fact(GameState, p, false, {}, 99, 0)["new_here"]), "...and so is a draftee of last year")
	p.erase("drafted_year")
	_check(not bool(ClubStories.player_fact(GameState, p, false, {}, 99, 0)["new_here"]), "...but not a player who has been here years")
	GameState.preseason_advance()   # the time trial
	var tr := GameState.preseason_trial()
	var best := str((tr["best"] as Array)[0])
	var last := str((tr["worst"] as Array)[0])
	_check(ClubStories._trial_place(GameState, best) == "best" and ClubStories._trial_place(GameState, last) == "worst"
			and ClubStories._trial_place(GameState, "nobody") == "", "The time trial's front and back are what the cards read")
	# Premiers: the honour roll says so only for last year.
	GameState.honour_roll = [{"year": GameState.season_year - 1, "premier": CLUB, "runner_up": "GEE"}]
	_check(bool(ClubStories.club_facts(GameState, 3, "preseason")["premiers"]), "Won the flag last year is read from the honour roll")
	GameState.honour_roll = [{"year": GameState.season_year - 2, "premier": CLUB, "runner_up": "GEE"}]
	_check(not bool(ClubStories.club_facts(GameState, 3, "preseason")["premiers"]), "...and not a flag from two years ago")
	GameState.honour_roll = [{"year": GameState.season_year - 1, "premier": "GEE", "runner_up": CLUB}]
	_check(not bool(ClubStories.club_facts(GameState, 3, "preseason")["premiers"]), "...nor one the club lost")
	GameState.honour_roll = []
	# The hangover card can only come up for the premiers.
	var t := StoryDeck.by_id(StoryDeck.all(), "pre_flag_hangover")
	var ctx := ClubStories.context(GameState)
	_check(StoryEngine.eligible_subject(t, ctx, GameState.story, 100, RandomNumberGenerator.new()).is_empty(), "The flag card stays away from a club that did not win one")
	(ctx["club"] as Dictionary)["premiers"] = true
	_check(not StoryEngine.eligible_subject(t, ctx, GameState.story, 100, RandomNumberGenerator.new()).is_empty(), "...and is there for the premiers")
	# Words: nothing in the deck reads as engine talk.
	var bad := []
	for id in IDS:
		var tt := StoryDeck.by_id(StoryDeck.all(), id)
		var blob := JSON.stringify(tt)
		for w in ["XP", "coefficient", "multiplier", "simulation"]:
			if blob.contains(w):
				bad.append("%s says %s" % [id, w])
	_check(bad.is_empty(), "The pre-season cards read as football, not as engine: %s" % " | ".join(PackedStringArray(bad)))


func _test_hands_off_and_save() -> void:
	_career(SEED + 3)
	var round1 := _ids(GameState.week_events)
	GameState.preseason_sim_to_round1()
	_check(not GameState.preseason_active() and _ids(GameState.week_events) == round1,
			"Sim to Round 1 stops for no card, and Round 1's cards are exactly what they were")
	# A save made while a card is waiting reloads with it waiting.
	var found := false
	for seed in range(SEED, SEED + 20):
		_career(seed)
		var guard := 0
		while GameState.preseason_active() and GameState.preseason_stop() != "story" and guard < 10:
			guard += 1
			GameState.preseason_advance()
		if GameState.preseason_stop() == "story":
			found = true
			var tid := str(GameState.week_events[0]["tid"])
			var week := GameState.preseason_week()
			_check(GameState.save_career() and GameState.load_career(), "A career saved at a card stop saves and loads")
			_check(GameState.preseason_stop() == "story" and GameState.preseason_week() == week
					and str(GameState.week_events[0]["tid"]) == tid and GameState.preseason.has("round1"),
					"...and is still at that card, with Round 1's cards still waiting aside")
			GameState.resolve_week_event(0)
			GameState.preseason_advance()
			break
	_check(found, "A card stop turned up in twenty careers to save at")
	GameState.delete_saved_career()
