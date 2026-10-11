extends RefCounted
## The week's story cards: the deck (data/stories), the engine that picks and
## remembers them, player trust, and the save. Run through
## tests/run_story_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2031
## Every card that is not one of the folded originals may come up at most this
## often in ten seasons (director brief, 2026-10-11: a long save stays fresh).
const REPEAT_MAX_TEN_SEASONS := 8
## The cards folded in from the old ClubLife code keep short cooldowns until the
## pool is big enough to replace them (phase 1 content PR); they are held to
## their own cooldowns instead of the ten-season bound.
const FOLDED := ["health_pulled_up_sore", "training_extra_session", "training_kid_pushing",
		"members_open_training", "media_in_the_papers", "contracts_wants_to_extend",
		"board_wants_answers", "selection_talk_dropped", "selection_talk_back",
		"selection_talk_waiting", "selection_unhappy"]


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	StoryDeck.reload()
	_test_deck_is_valid()
	_test_validator_catches()
	_test_folded_sizes()
	_test_hints_in_words()
	_test_trust_rules()
	_test_engine_rules()
	_test_arcs()
	_test_finals_and_big_weeks()
	_test_private_cards()
	_test_ten_seasons()
	_test_trust_in_play()
	_test_stories_never_move_the_dice()
	_test_save_round_trip()
	_test_old_save()
	_test_leadership()
	_test_captaincy()
	_test_culture()
	_test_culture_news()
	_test_culture_reasons_read_cleanly()
	_test_culture_settles()
	_test_culture_signs_match_words()
	_test_culture_headline()
	_test_culture_order_and_tails()
	_test_culture_sentences()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	GameState.stories_on = true
	print("Story tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _start() -> void:
	GameState.reset()
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))


# --- The deck -----------------------------------------------------------------

func _test_deck_is_valid() -> void:
	var deck := StoryDeck.all()
	_check(deck.size() >= FOLDED.size(), "The deck loads (%d cards)" % deck.size())
	var errs := StoryDeck.validate(deck)
	_check(errs.is_empty(), "Every card passes the deck checks: %s" % "; ".join(PackedStringArray(errs)))
	for id in FOLDED:
		_check(not StoryDeck.by_id(deck, id).is_empty(), "The old %s card lives in the deck" % id)
	for cat in StoryDeck.CATEGORIES:
		var path := "%s%s.json" % [StoryDeck.DIR, cat]
		if FileAccess.file_exists(path):
			_check(JSON.parse_string(FileAccess.get_file_as_string(path)) is Array, "%s parses" % path)


func _bad(card: Dictionary) -> Array:
	var base := {"id": "t", "category": "training", "subject": {"kind": "player"},
			"title": ["{name}"], "text": ["x"],
			"choices": [{"key": "a", "label": "A", "effects": [{"op": "morale", "d": 3}]},
				{"key": "b", "label": "B", "effects": []}]}
	base.merge(card, true)
	return StoryDeck.validate([StoryDeck.normalise(base)])


## Each check is shown failing on a card built to break it.
func _test_validator_catches() -> void:
	_check(_bad({}).is_empty(), "A plain card is valid (%s)" % str(_bad({})))
	var big := {"choices": [{"key": "a", "label": "A", "effects": [{"op": "morale", "d": 40}]},
			{"key": "b", "label": "B", "effects": []}]}
	_check(not _bad(big).is_empty(), "A morale swing over the cap is refused")
	var board := {"choices": [{"key": "a", "label": "A", "effects": [{"op": "board", "d": 9}]},
			{"key": "b", "label": "B", "effects": []}]}
	_check(not _bad(board).is_empty(), "A board swing over the cap is refused")
	var why := {"choices": [{"key": "a", "label": "A", "effects": [{"op": "trust", "d": 5}]},
			{"key": "b", "label": "B", "effects": []}]}
	_check(not _bad(why).is_empty(), "A trust change without its reason is refused")
	var op := {"choices": [{"key": "a", "label": "A", "effects": [{"op": "win_flag"}]},
			{"key": "b", "label": "B", "effects": []}]}
	_check(not _bad(op).is_empty(), "An effect the game does not have is refused")
	_check(not _bad({"text": ["{nickname} again"]}).is_empty(), "A placeholder the game cannot fill is refused")
	_check(not _bad({"subject": {"kind": "club"}}).is_empty(), "{name} on a club card is refused")
	var club_rest := {"subject": {"kind": "club"}, "title": ["x"],
			"choices": [{"key": "a", "label": "A", "effects": [{"op": "rest"}]}, {"key": "b", "label": "B", "effects": []}]}
	_check(not _bad(club_rest).is_empty(), "A player-only effect on a club card is refused")
	_check(not _bad({"category": "weather"}).is_empty(), "An unknown category is refused")
	_check(not _bad({"subject": {"kind": "player", "where": {"height_min": 190}}}).is_empty(),
			"A condition on a fact the game does not supply is refused")
	_check(not _bad({"choices": [{"key": "a", "label": "A", "effects": []}]}).is_empty(), "One choice is no choice")
	var arc := _arc_deck()
	_check(StoryDeck.validate(arc).is_empty(), "The test arc is valid (%s)" % str(StoryDeck.validate(arc)))
	_check(not StoryDeck.validate([arc[0]]).is_empty(), "An arc with no ending is refused")
	_check(not StoryDeck.validate([arc[1]]).is_empty(), "A follow-up on a flag nobody sets is refused")


func _choice(id: String, key: String) -> Dictionary:
	for c in StoryDeck.by_id(StoryDeck.all(), id)["choices"]:
		if str(c["key"]) == key:
			return c
	return {}


func _effect(c: Dictionary, op: String) -> Dictionary:
	for e in c.get("effects", []):
		if str(e["op"]) == op:
			return e
	return {}


## The cards' sizes match the rules the rest of the game reads.
func _test_folded_sizes() -> void:
	_check(int(_effect(_choice("training_extra_session", "heavy"), "xp")["d"]) == ClubLife.HEAVY_XP,
			"The heavy session gives the heavy week's development")
	_check(int(_effect(_choice("members_open_training", "closed"), "xp")["d"]) == ClubLife.CLOSED_XP,
			"The closed session gives a closed session's development")
	_check(int(_effect(_choice("training_kid_pushing", "develop"), "xp")["d"]) == ClubLife.DEV_WEEK_XP,
			"The development week gives a development week")
	_check(int(_effect(_choice("selection_talk_dropped", "explain"), "morale")["d"]) == ClubLife.EXPLAIN_LIFT,
			"Talking him through it lifts him as much as it always did")


## A choice's hint is made from its effects, in words: no "+12 XP", no "morale +3".
func _test_hints_in_words() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var numbers := RegEx.create_from_string("(XP|morale|confidence) ?[+-]?[0-9]|[+-][0-9]+")
	var bad := []
	for t in StoryDeck.all():
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		for o in card["options"]:
			var d := str(o["detail"])
			if d == "" or numbers.search(d) != null or d.contains("{"):
				bad.append("%s/%s: %s" % [t["id"], o["key"], d])
		if str(card["title"]).contains("{") or str(card["text"]).contains("{"):
			bad.append("%s: %s" % [t["id"], card["title"]])
	_check(bad.is_empty(), "Every choice says what it does, in words, fully filled in: %s" % " | ".join(PackedStringArray(bad)))
	var heavy := GameState.story_card("training_extra_session")
	_check(str(heavy["options"][0]["detail"]).contains("development") and str(heavy["options"][0]["detail"]).contains("Heavy legs"),
			"The heavy session's hint names both sides of it (%s)" % heavy["options"][0]["detail"])


# --- Trust ---------------------------------------------------------------------

func _test_trust_rules() -> void:
	var rel := {}
	var k := Trust.player_key("x")
	_check(Trust.value(rel, k) == 0 and Trust.words(0) == "", "Nobody has a view of you to begin with, and it says nothing")
	_check(Trust.change(rel, k, 40, "Big moment", 2027, "Round 3") == Trust.STEP_MAX,
			"One moment moves trust at most %d" % Trust.STEP_MAX)
	_check(Trust.words(Trust.value(rel, k)) == "Trusts you", "Twenty up: he trusts you")
	for i in range(12):
		Trust.change(rel, k, 10, "Moment %d" % i, 2027, "Round %d" % i)
	_check(Trust.value(rel, k) == Trust.HIGHEST and Trust.words(Trust.HIGHEST) == "Trusts you completely",
			"Trust tops out, in words")
	var r := Trust.reasons(rel, k)
	_check(r.size() == Trust.LOG_KEEP and str(r[0]["why"]) == "Moment 11",
			"The last %d reasons are kept, newest first" % Trust.LOG_KEEP)
	_check(Trust.words(-30) == "Wary of you" and Trust.words(-80) == "Stopped listening", "Low trust in words")
	_check(Trust.scaled(10, 60) > 10 and Trust.scaled(10, -60) < 10 and Trust.scaled(-5, 60) == -5,
			"A lift lands harder with trust and softer without; a cost is a cost")
	# The profile's words: nothing until something has passed between you.
	var p2 := Trust.player_key("y")
	var none := {}
	_check(Trust.profile_words(none, p2) == "", "The profile says nothing about a player you've had nothing to do with")
	Trust.change(none, p2, 8, "You gave him his chance", 2027, "Round 4")
	Trust.change(none, p2, -8, "You promised him a game and left him out", 2027, "Round 6")
	_check(Trust.profile_words(none, p2) == "Has no strong view of you",
			"Back in the middle after two moments, he has no strong view of you")
	_check(Trust.profile_words(rel, k) == "Trusts you completely", "Otherwise the profile uses his band's words")
	var rs := Trust.reasons(none, p2)
	_check(Trust.reason_text(rs[0]) == "Round 6, 2027. You promised him a game and left him out. Trust fell."
			and Trust.reason_text(rs[1]) == "Round 4, 2027. You gave him his chance. Trust rose.",
			"Each reason reads when, what you did, and which way it moved him")


# --- The engine ------------------------------------------------------------------

func _club_card(id: String, cat: String, extra := {}) -> Dictionary:
	var t := {"id": id, "category": cat, "subject": {"kind": "club"}, "title": ["T"], "text": ["x"],
			"choices": [{"key": "a", "label": "A", "effects": []}, {"key": "b", "label": "B", "effects": []}]}
	t.merge(extra, true)
	return StoryDeck.normalise(t)


func _test_engine_rules() -> void:
	var ctx := {"seed": 1, "year": 2027, "week": 1, "phase": "regular", "club": {}, "players": []}
	var rng := RandomNumberGenerator.new()
	# Cooldown: once seen, not again until it has run out.
	var t := _club_card("c1", "training", {"cooldown": 5})
	var story := StoryEngine.new_state()
	var w := StoryEngine.week_abs(2027, 3)
	story["last"]["c1"] = w
	_check(StoryEngine.eligible_subject(t, ctx, story, w + 4, rng).is_empty()
			and not StoryEngine.eligible_subject(t, ctx, story, w + 5, rng).is_empty(), "A card waits out its cooldown")
	_check(StoryEngine.week_abs(2028, 1) - StoryEngine.week_abs(2027, 29) == 2,
			"Cooldowns run on through the off-season")
	# Per season.
	var once := _club_card("c2", "board", {"per_season": 1})
	story["season"]["c2"] = 1
	_check(StoryEngine.eligible_subject(once, ctx, story, w, rng).is_empty(), "A once-a-season card waits for next season")
	StoryEngine.new_season(story)
	_check(not StoryEngine.eligible_subject(once, ctx, story, w, rng).is_empty(), "...and comes back then")
	# Diversity: two of a category in five weeks is the most.
	var div := StoryEngine.new_state()
	div["cats"] = [[w - 4, "media"], [w - 1, "media"]]
	_check(StoryEngine.eligible_subject(_club_card("c3", "media"), ctx, div, w, rng).is_empty()
			and not StoryEngine.eligible_subject(_club_card("c3", "media"), ctx, div, w + 1, rng).is_empty(),
			"No category more than twice in five weeks")
	# Subject cooldown and conditions.
	var pc := StoryDeck.normalise({"id": "p1", "category": "family", "subject_cooldown": 6,
			"subject": {"kind": "player", "where": {"age_max": 25, "fit": true}, "pick": "highest:games"},
			"title": ["{name}"], "text": ["x"],
			"choices": [{"key": "a", "label": "A", "effects": []}, {"key": "b", "label": "B", "effects": []}]})
	ctx["players"] = [{"id": "a", "name": "A", "age": 22.0, "fit": true, "games": 50},
			{"id": "b", "name": "B", "age": 30.0, "fit": true, "games": 200},
			{"id": "c", "name": "C", "age": 21.0, "fit": false, "games": 90},
			{"id": "d", "name": "D", "age": 20.0, "fit": true, "games": 80}]
	var s2 := StoryEngine.new_state()
	_check(str(StoryEngine.eligible_subject(pc, ctx, s2, w, rng).get("id", "")) == "d",
			"The card's player is the one its conditions and pick name")
	s2["subj"]["d"] = w - 2
	_check(str(StoryEngine.eligible_subject(pc, ctx, s2, w, rng).get("id", "")) == "a",
			"A player just on a card waits his turn")
	_check(StoryEngine.meets({"losing_run": 6}, {"losing_run_every": 3}, {})
			and not StoryEngine.meets({"losing_run": 4}, {"losing_run_every": 3}, {})
			and not StoryEngine.meets({"losing_run": 0}, {"losing_run_every": 3}, {}),
			"An 'every' condition fires on each multiple, never at zero")


## A two-beat arc for the tests: back the player (flag) or don't; the payoff
## comes two to six weeks later, only if you backed him.
func _arc_deck() -> Array:
	var start := StoryDeck.normalise({"id": "arc_start", "category": "family", "arc": "t_arc", "beat": "start",
			"cooldown": 0, "subject_cooldown": 0,
			"subject": {"kind": "player", "where": {"fit": true}},
			"title": ["{name} needs you"], "text": ["x"],
			"choices": [{"key": "back", "label": "Back him", "effects": [{"op": "flag", "name": "t_backed"},
					{"op": "trust", "d": 5, "why": "You backed him"}]},
				{"key": "no", "label": "Leave it", "effects": []}]})
	var end := StoryDeck.normalise({"id": "arc_end", "category": "family", "arc": "t_arc", "beat": "end",
			"cooldown": 0, "subject_cooldown": 0,
			"needs": {"flag": "t_backed", "after": 2, "within": 6},
			"subject": {"kind": "player", "where": {"fit": true}},
			"title": ["{name} repays you"], "text": ["x"],
			"choices": [{"key": "a", "label": "Good", "effects": []}, {"key": "b", "label": "Fine", "effects": []}]})
	return [start, end]


func _test_arcs() -> void:
	var deck := _arc_deck()
	var ctx := {"seed": 7, "year": 2027, "week": 1, "phase": "regular", "club": {},
			"players": [{"id": "k", "name": "Kid", "fit": true}]}
	var story := StoryEngine.new_state()
	var rng := RandomNumberGenerator.new()
	var w1 := StoryEngine.week_abs(2027, 1)
	var subj := StoryEngine.eligible_subject(deck[0], ctx, story, w1, rng)
	var card := StoryEngine.build(deck, deck[0], subj, {}, rng, w1)
	StoryEngine.record_choice(story, card, 0, w1)
	_check(str(story["arcs"]["t_arc|k"]["state"]) == "open" and story["flags"]["k"].has("t_backed"),
			"Backing him sets his flag and opens the arc")
	_check(StoryEngine.eligible_subject(deck[0], ctx, story, w1 + 1, rng).is_empty(), "The arc does not start twice")
	ctx["week"] = 2
	_check(StoryEngine.pick_week(deck, ctx, story).is_empty(), "The payoff waits its weeks")
	ctx["week"] = 3
	var due := StoryEngine.pick_week(deck, ctx, story)
	_check(due.size() == 1 and str(due[0]["tid"]) == "arc_end", "A due beat comes, quiet week or not")
	StoryEngine.record_choice(story, due[0], 0, StoryEngine.week_abs(2027, 3))
	_check(str(story["arcs"]["t_arc|k"]["state"]) == "done", "The end beat closes the arc")
	ctx["week"] = 5
	_check(StoryEngine.pick_week(deck, ctx, story).is_empty(), "A finished arc never loops")
	# Choosing not to back him starts nothing.
	var s2 := StoryEngine.new_state()
	StoryEngine.record_choice(s2, card, 1, w1)
	_check(not s2["arcs"].has("t_arc|k"), "A start whose choice sets nothing never begins")
	# Nobody comes back to it: it lapses, once, and stays closed.
	var s3 := StoryEngine.new_state()
	StoryEngine.record_choice(s3, card, 0, w1)
	ctx["week"] = 9
	var late := StoryEngine.pick_week(deck, ctx, s3)
	_check(late.is_empty() and str(s3["arcs"]["t_arc|k"]["state"]) == "lapsed",
			"An arc left past its window lapses (%s)" % str(s3["arcs"]))
	_check(StoryEngine.eligible_subject(deck[0], ctx, s3, StoryEngine.week_abs(2027, 9), rng).is_empty(),
			"...and never starts again for him")


func _test_finals_and_big_weeks() -> void:
	_start()
	var ctx := ClubStories.context(GameState)
	ctx["phase"] = "finals"
	ctx["big"] = true
	var story := StoryEngine.new_state()
	var wrong := []
	var two := 0
	var clash := 0
	for wk in range(25, 30):
		for y in range(2027, 2037):
			ctx["year"] = y
			ctx["week"] = wk
			for c in StoryEngine.pick_week(StoryDeck.all(), ctx, story):
				if not (StoryDeck.by_id(StoryDeck.all(), str(c["tid"]))["phase"] as Array).has("finals"):
					wrong.append(str(c["tid"]))
	_check(wrong.is_empty(), "A finals week only brings finals cards (%s)" % str(wrong))
	# A big week of the home and away (round 1, the last round): up to two.
	ctx["phase"] = "regular"
	for wk in [1, Season.REGULAR_ROUNDS]:
		for y in range(2027, 2047):
			ctx["year"] = y
			ctx["week"] = wk
			var cards := StoryEngine.pick_week(StoryDeck.all(), ctx, StoryEngine.new_state())
			if cards.size() == 2:
				two += 1
				if str(cards[0]["category"]) == str(cards[1]["category"]) \
						or (str(cards[0].get("player_id", "")) != "" and str(cards[0].get("player_id", "")) == str(cards[1].get("player_id", ""))):
					clash += 1
	_check(two > 0 and clash == 0, "A big week can bring a second card, from another category and about another player (%d)" % two)
	ctx["phase"] = "regular"
	ctx["big"] = false
	var max_cards := 0
	for wk in range(2, 24):
		ctx["week"] = wk
		max_cards = maxi(max_cards, StoryEngine.pick_week(StoryDeck.all(), ctx, story).size())
	_check(max_cards <= 1, "An ordinary week brings one card at most")
	# A season's weeks, finals included, fit inside the week count cooldowns run
	# on, so a card's cooldown never wraps into the next season early.
	var s = GameState.season
	s.start_finals()
	var finals_weeks := 0
	while not s.finals_week_matches().is_empty() and finals_weeks < 20:
		finals_weeks += 1
		s.finals["week"] = int(s.finals["week"]) + 1
	_check(finals_weeks > 0 and Season.REGULAR_ROUNDS + finals_weeks < StoryEngine.SEASON_WEEKS,
			"%d rounds and %d finals weeks fit inside a story season of %d weeks"
			% [Season.REGULAR_ROUNDS, finals_weeks, StoryEngine.SEASON_WEEKS])


## No card that invents a private life or misconduct can be about a player
## shown under his real name, whatever else is true of him.
func _test_private_cards() -> void:
	_start()
	var private := StoryDeck.all().filter(func(t): return bool(t.get("private", false)))
	_check(not StoryDeck.by_id(StoryDeck.all(), "media_in_the_papers").is_empty()
			and bool(StoryDeck.by_id(StoryDeck.all(), "media_in_the_papers").get("private", false)),
			"The papers card is marked private")
	var ctx := ClubStories.context(GameState)
	var leaks := []
	var reachable := 0
	for t in private:
		for named in [true, false]:
			var players := []
			for f in ctx["players"]:
				var g: Dictionary = (f as Dictionary).duplicate()
				g["real_named"] = named
				players.append(g)
			ctx["players"] = players
			# Every player fits every condition he could: only the name rule is left.
			for f in players:
				for k in (t["subject"].get("where", {}) as Dictionary):
					var key := str(k)
					if not (key.ends_with("_min") or key.ends_with("_max") or key.ends_with("_every") or key == "flag" or key == "no_flag"):
						f[key] = t["subject"]["where"][k]
					elif key.ends_with("_max"):
						f[key.trim_suffix("_max")] = float(t["subject"]["where"][k])
					elif key.ends_with("_min"):
						f[key.trim_suffix("_min")] = float(t["subject"]["where"][k])
			# An arc follow-up needs his flag and an open arc: give every player both.
			var st := StoryEngine.new_state()
			var needs: Dictionary = t.get("needs", {})
			if not needs.is_empty():
				for f in players:
					var pid := str(f["id"])
					st["flags"][pid] = {str(needs["flag"]): 10 - int(needs.get("after", 1))}
					if str(t.get("arc", "")) != "":
						st["arcs"][str(t["arc"]) + "|" + pid] = {"state": "open"}
			var who := StoryEngine.eligible_subject(t, ctx, st, 10, RandomNumberGenerator.new())
			if named and not who.is_empty():
				leaks.append(str(t["id"]))
			if not named and not who.is_empty():
				reachable += 1
	_check(leaks.is_empty() and reachable == private.size(),
			"A private card never picks a real-named player, and still picks the rest (%s, %d of %d)" % [
			str(leaks), reachable, private.size()])
	GameState.show_real_names = true
	var named_fact := ClubStories.player_fact(GameState, {"id": "r", "real_name": "Real Person", "name": "Fake Name",
			"overall": 60}, false, {}, 1, 0)
	GameState.show_real_names = false
	var fake_fact := ClubStories.player_fact(GameState, {"id": "r", "real_name": "Real Person", "name": "Fake Name",
			"overall": 60}, false, {}, 1, 0)
	_check(bool(named_fact["real_named"]) and not bool(fake_fact["real_named"]),
			"A player is real-named only while real names are on and he has one")


## Ten seasons of weeks through the engine, every card answered: nothing
## repeats beyond its bound, and no category crowds the others out.
func _test_ten_seasons() -> void:
	_start()
	var deck := StoryDeck.all()
	var ctx := ClubStories.context(GameState)
	var story := StoryEngine.new_state()
	var seen := {}
	var crowded := 0
	var weeks := 0
	for y in range(10):
		StoryEngine.new_season(story)
		for wk in range(1, 30):
			ctx["year"] = 2027 + y
			ctx["week"] = wk
			ctx["phase"] = "finals" if wk > Season.REGULAR_ROUNDS else "regular"
			ctx["big"] = wk == 1 or wk >= Season.REGULAR_ROUNDS
			ctx["club"]["losing_run"] = wk % 7
			var w := StoryEngine.week_abs(2027 + y, wk)
			weeks += 1
			for c in StoryEngine.pick_week(deck, ctx, story):
				seen[str(c["tid"])] = int(seen.get(str(c["tid"]), 0)) + 1
				StoryEngine.record_choice(story, c, maxi(0, int(c["default"])), w)
			for cat in StoryDeck.CATEGORIES:
				if StoryEngine.category_count(story, cat, w) > StoryEngine.DIVERSITY_MAX:
					crowded += 1
	_check(crowded == 0, "No category comes up more than twice in five weeks (%d breaches)" % crowded)
	var over := []
	for t in deck:
		var id := str(t["id"])
		var n := int(seen.get(id, 0))
		var by_cooldown := weeks / maxi(1, int(t["cooldown"])) + 1
		if n > by_cooldown:
			over.append("%s %d > %d (cooldown)" % [id, n, by_cooldown])
		if int(t["per_season"]) > 0 and n > 10 * int(t["per_season"]):
			over.append("%s %d > %d (per season)" % [id, n, 10 * int(t["per_season"])])
		if not FOLDED.has(id) and n > REPEAT_MAX_TEN_SEASONS:
			over.append("%s %d > %d in ten seasons" % [id, n, REPEAT_MAX_TEN_SEASONS])
	_check(over.is_empty(), "No card repeats beyond its bound over ten seasons: %s" % ", ".join(PackedStringArray(over)))
	print("  ten seasons, engine only: %d cards, %d distinct of %d" % [_sum(seen), seen.size(), deck.size()])


func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


# --- In a career -----------------------------------------------------------------

func _test_trust_in_play() -> void:
	_start()
	var p: Dictionary = GameState.my_list[2]
	var key := Trust.player_key(str(p["id"]))
	GameState.week_event = GameState.story_card("media_in_the_papers", p)
	var hint := str(GameState.week_event["options"][1]["detail"])
	var out := GameState.resolve_week_event(1)
	_check(hint.contains("His trust in you rises"), "The choice says what it does to his trust (%s)" % hint)
	_check(Trust.value(GameState.relations, key) == 10 and out.contains("His trust in you rose"),
			"Backing him in the papers: his trust rises, and the result says so (%s)" % out)
	_check(str(Trust.reasons(GameState.relations, key)[0]["why"]) == "You backed him when he was in the papers",
			"The reason is kept in plain words")
	# A promise broken after the match costs trust, with its reason.
	var sulk: Dictionary = GameState.my_list[25]
	sulk["morale"] = 30
	GameState.week_event = GameState.story_card("selection_unhappy", sulk)
	GameState.resolve_week_event(0)
	var side: Dictionary = GameState.current_side()
	for k in side:
		(side[k] as Array).erase(str(sulk["id"]))
	side["OUT"] = [str(sulk["id"])]
	GameState.set_selection(side)
	var before := Trust.value(GameState.relations, Trust.player_key(str(sulk["id"])))
	GameState.advance()
	GameState.set_selection({})
	if int(sulk.get("injury_weeks", 0)) <= 0:
		var r := Trust.reasons(GameState.relations, Trust.player_key(str(sulk["id"])))
		_check(Trust.value(GameState.relations, Trust.player_key(str(sulk["id"]))) == before + ClubStories.BROKEN_PROMISE_TRUST
				and str(r[0]["why"]) == "You promised him a game and left him out",
				"Left out after a promise, his trust falls, and he says why")
	# Trust changes what a talk does, and the card says so before you choose.
	var fan: Dictionary = GameState.my_list[26]
	Trust.change(GameState.relations, Trust.player_key(str(fan["id"])), 20, "t", 2027, "Round 1")
	Trust.change(GameState.relations, Trust.player_key(str(fan["id"])), 20, "t", 2027, "Round 1")
	Trust.change(GameState.relations, Trust.player_key(str(fan["id"])), 15, "t", 2027, "Round 1")
	fan["morale"] = 30
	var card := GameState.story_card("selection_unhappy", fan)
	_check(str(card["options"][0]["detail"]).contains("It means more coming from you"),
			"A talk with a player who trusts you says it lands harder")
	GameState.week_event = card
	GameState.resolve_week_event(0)
	_check(ClubLife.morale(fan) == 30 + Trust.scaled(15, 55), "...and it does (%d)" % ClubLife.morale(fan))
	# Rival clubs are untouched: trust is yours alone, and nothing else reads it.
	for k in GameState.relations:
		if str(k).begins_with("k:"):
			continue  # a club's culture strands, not a person's trust
		_check(GameState.list_player(str(k).trim_prefix("p:")).size() > 0, "Only your players hold trust (%s)" % k)


## A season's results with the cards drawn but never answered match a season
## with no cards at all: drawing them uses its own random stream.
func _checksum(on: bool) -> String:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.stories_on = on
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var out: PackedStringArray = []
	var drawn := 0
	for r in range(8):
		if on:
			drawn += GameState.week_events.size()
			# Extra draws too: however often the engine is asked, the dice hold.
			for i in range(5):
				StoryEngine.pick_week(StoryDeck.all(), ClubStories.context(GameState), StoryEngine.new_state())
		GameState.week_events = []
		GameState.advance()
		for res in GameState.last_results:
			out.append("%s%s%s" % [res["home"], str(res["score"]), res["away"]])
	GameState.stories_on = true
	return "%s|%d" % [",".join(out).md5_text(), drawn]


func _test_stories_never_move_the_dice() -> void:
	var off := _checksum(false)
	var on := _checksum(true)
	_check(on.split("|")[0] == off.split("|")[0] and int(on.split("|")[1]) > 0 and int(off.split("|")[1]) == 0,
			"Eight rounds play out the same with the cards drawn or switched off (%s v %s)" % [on, off])


## Save mid-season, reload, carry on: the same cards and the same results as
## a career that never stopped.
func _run_on(rounds: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in range(rounds):
		for c in GameState.week_events:
			out.append(str(c.get("tid", "")) + "@" + str(c.get("player_id", "")))
		if GameState.week_event_pending():
			GameState.resolve_week_event(0)
		GameState.advance()
		out.append(str(GameState.last_match.get("score", [])))
	return out


func _test_save_round_trip() -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_run_on(4)
	var p: Dictionary = GameState.my_list[3]
	Trust.change(GameState.relations, Trust.player_key(str(p["id"])), 12, "You gave him the week off", 2027, "Round 4")
	GameState.story["flags"]["club"] = {"test_flag": 100}
	_check(GameState.save_career(), "The career saves")
	var rel_before := GameState.relations.duplicate(true)
	var story_before := JSON.stringify(GameState.story)
	var cards_before := JSON.stringify(GameState.week_events)
	var straight := _run_on(6)
	_check(GameState.load_career(), "The career loads")
	_check(JSON.stringify(GameState.relations) == JSON.stringify(rel_before), "Trust and its reasons survive a reload")
	_check(JSON.stringify(GameState.story) == story_before, "The story's memory survives a reload")
	_check(JSON.stringify(GameState.week_events) == cards_before, "This week's cards survive a reload")
	var reloaded := _run_on(6)
	_check(straight == reloaded, "Reload and carry on: the same cards and results as never stopping\n%s\n%s" % [
			",".join(straight), ",".join(reloaded)])


## A save from before the story deck: everyone neutral, an old card redrawn.
func _test_old_save() -> void:
	GameState.reset()
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("relations")
	state.erase("story")
	state.erase("week_events")
	state["week_event"] = {"key": "fans", "default": -1, "title": "Members want an open training day",
			"text": "The fans would love it.", "options": [{"key": "open", "label": "Open the doors", "detail": ""},
				{"key": "closed", "label": "Closed session", "detail": ""}]}
	state["event_memory"] = {"extension|x": true}
	_check(CareerSave.write(state, GameState._save_meta(), GameState.save_path), "An old-style save is written")
	_check(GameState.load_career(), "An old-style save loads")
	_check(GameState.relations.is_empty(), "Everyone starts neutral")
	_check(GameState.story.has("arcs") and GameState.story.has("last"), "The story's memory starts empty")
	var tid_ok := true
	for c in GameState.week_events:
		tid_ok = tid_ok and str(c.get("tid", "")) != ""
	_check(tid_ok, "The old card is redrawn from the deck (%s)" % str(GameState.week_events.map(func(c): return c.get("key", ""))))
	GameState.advance()
	_check(GameState.season.round_index >= 1, "...and the season plays on")


# --- Leadership (P2-1) --------------------------------------------------------

## The rating is a derived number: public facts for a real player, a fixed
## spread for an invented one, never his playing quality, never stored.
func _test_leadership() -> void:
	Leadership.reload()
	var everyone := GameDB.all_players_sorted()
	var by_real := {}
	for p in everyone:
		var rn := str((p as Dictionary).get("real_name", "")).strip_edges().to_lower()
		if rn != "":
			var rk := "%s|%s" % [str(p.get("club", "")), rn]
			by_real[rk] = int(by_real.get(rk, 0)) + 1
	var lines := FileAccess.get_file_as_string(Leadership.PATH).split("
", false)
	var bad := []
	for i in range(lines.size()):
		var row := lines[i].strip_edges()
		if row.begins_with("#") or row.begins_with("club,"):
			continue
		var c := row.split(",")
		var key := "%s|%s" % [c[0], ("%s %s" % [c[1], c[2]]).to_lower()]
		if int(by_real.get(key, 0)) != 1 or not Leadership.ROLE_BONUS.has(c[3]):
			bad.append(key)
	_check(bad.is_empty() and lines.size() > 80,
			"Every leadership-record row is one real player with a known role (%s)" % ", ".join(PackedStringArray(bad)))

	var twin := {"real_name": "Pat Example", "id": "x1", "age": 27.0, "club": "GEE", "gm": 20,
			"career": {"games": 150, "stints": [["GEE", 2019, 2025, 150, 10]]}, "overall": 70,
			"attr": {"disposal": 80}}
	var higher := twin.duplicate(true)
	higher["overall"] = 95
	higher["attr"] = {"disposal": 99, "star": 99}
	_check(Leadership.of(twin) == Leadership.of(higher),
			"Leadership ignores his playing quality (OVR and attributes)")
	var veteran := twin.duplicate(true)
	veteran["career"]["games"] = 300
	veteran["age"] = 31.0
	_check(Leadership.of(veteran) > Leadership.of(twin), "More games and years raise it")
	var real_cap: Dictionary = {}
	for p in everyone:
		if Leadership.role_2026(p) == "captain":
			real_cap = p
			break
	_check(not real_cap.is_empty(), "A real captain is found in the pool")
	if not real_cap.is_empty():
		var same := (real_cap as Dictionary).duplicate(true)
		same["real_name"] = "Not A Captain"
		_check(Leadership.of(real_cap) - Leadership.of(same) == int(Leadership.ROLE_BONUS["captain"]),
				"A captain's 2026 role adds the captain bonus and nothing else")
		var traded := (real_cap as Dictionary).duplicate(true)
		traded["club"] = "ZZZ"
		_check(Leadership.role_2026(traded) == "captain" and Leadership.role_club(traded) == str(real_cap["club"]),
				"A traded captain keeps his role, still named for the club that gave it")
		_check(Leadership.role_line(traded, 2027, func(code): return "Club " + code) == "Club %s captain" % real_cap["club"]
				and Leadership.role_line(real_cap, 2027, func(code): return "Club " + code) == "Captain",
				"A traded captain reads with his old club; at his own club it is plain Captain")
		var namesake := (real_cap as Dictionary).duplicate(true)
		namesake["club"] = "ZZZ"
		namesake["career"] = {"games": 5, "stints": [["ZZZ", 2026, 2026, 5, 0]]}
		_check(Leadership.role_2026(namesake) == "", "A namesake at another club does not inherit the role")
		_check(Leadership.role_line(real_cap, 2027) == "Captain" and Leadership.role_line(real_cap, 2028) == "",
				"The role reads \"Captain\" through the first season, then the rating carries it")

	var a := twin.duplicate(true)
	var b := twin.duplicate(true)
	b["real_name"] = "Other Real"
	b["id"] = "x2"
	_check(Leadership.of(a) == Leadership.of(b), "A real player's number is facts only: no per-player jitter")
	var spread := {}
	for i in range(40):
		var f := twin.duplicate(true)
		f["real_name"] = ""
		f["id"] = "G%d" % i
		spread[Leadership.of(f)] = true
		_check(absi(Leadership.of(f) - Leadership.of(a)) <= Leadership.SPREAD, "An invented player stays within the spread")
	_check(spread.size() >= 5, "Invented players with the same games and age are not clones (%d values)" % spread.size())

	var fixed := twin.duplicate(true)
	fixed["real_name"] = ""
	_check(Leadership.of(fixed) == Leadership.of(fixed.duplicate(true)), "The same player always gets the same number")
	var before := JSON.stringify(twin)
	Leadership.of(twin)
	_check(JSON.stringify(twin) == before, "Reading Leadership stores nothing on the player")

	var bare := {"id": "old"}
	var n := Leadership.of(bare)
	_check(n >= Leadership.FLOOR and n <= Leadership.CEILING, "A player an older save left bare still rates (%d)" % n)

	var lo := 99
	var hi := 1
	var xs := []
	var ys := []
	for p in everyone:
		var v := Leadership.of(p)
		lo = mini(lo, v)
		hi = maxi(hi, v)
		xs.append(float(v))
		ys.append(float(p.get("overall", 0)))
	_check(lo >= 1 and hi <= 99 and hi - lo >= 30, "Across the league it spans a real range (%d-%d)" % [lo, hi])
	_check(absf(_corr(xs, ys)) < 0.6, "It is not just OVR in disguise (r = %.2f)" % _corr(xs, ys))
	var trainable := false
	for t in GameState.TRAIN_STATS:
		if str(t[0]) == "leadership":
			trainable = true
	_check(not trainable, "Leadership cannot be trained")


func _corr(xs: Array, ys: Array) -> float:
	var n := float(xs.size())
	if n < 2.0:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in range(xs.size()):
		mx += float(xs[i])
		my += float(ys[i])
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(xs.size()):
		sxy += (float(xs[i]) - mx) * (float(ys[i]) - my)
		sxx += pow(float(xs[i]) - mx, 2.0)
		syy += pow(float(ys[i]) - my, 2.0)
	if sxx <= 0.0 or syy <= 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)


# --- Captaincy (P2-2) ---------------------------------------------------------

func _lp(id: String, age: float, games: int, club := "GEE", real := "") -> Dictionary:
	return {"id": id, "age": age, "club": club, "real_name": real, "career": {"games": games, "stints": []}, "gm": 0}


func _test_captaincy() -> void:
	# The pure rules.
	var roster := [_lp("a", 24.0, 20), _lp("b", 31.0, 250), _lp("c", 29.0, 180), _lp("d", 33.0, 300), _lp("e", 22.0, 5)]
	var rule := Captaincy.by_rule(roster)
	var order := roster.duplicate()
	order.sort_custom(func(x, y): return Leadership.of(x) > Leadership.of(y) or (Leadership.of(x) == Leadership.of(y) and Leadership.games(x) > Leadership.games(y)))
	_check(rule.size() == 3 and str(rule[0]["role"]) == "captain" and str(rule[1]["role"]) == "vice"
			and str(rule[0]["id"]) == str(order[0]["id"]) and str(rule[2]["id"]) == str(order[2]["id"]),
			"The rule names the highest Leadership captain, then two vice-captains")
	_check(JSON.stringify(Captaincy.by_rule(roster)) == JSON.stringify(rule), "The rule gives the same answer every time")
	var rec := Captaincy.fresh(2027)
	rec["slots"] = [{"id": "x", "role": "captain"}, {"id": "b", "role": "vice"}]
	var gone := Captaincy.prune(rec, roster)
	_check(gone == ["x"] and Captaincy.ids(rec) == ["b"], "A captain who left the list leaves the spot open")
	var made := Captaincy.fill(rec, roster)
	_check(made == "b" and Captaincy.role_of(rec, "b") == "captain", "With no captain, the best-rated vice takes over")
	var empty := Captaincy.fresh(2027)
	Captaincy.fill(empty, roster)
	_check(Captaincy.slots(empty).size() == 3, "A club with no one named is appointed by the rule")

	# Costs, said before the pick.
	var nm := func(id): return "P" + str(id)
	var cur := Captaincy.fresh(2027)
	cur["slots"] = [{"id": "a", "role": "captain"}]
	var pre := Captaincy.preview(cur, [{"id": "e", "role": "captain"}], roster, 2027, false, nm)
	_check(bool(pre["ok"]) and not bool(pre["used_change"]) and pre["morale"].has("d") and pre["trust"].has("d"),
			"Passing over a senior player with higher Leadership costs him a little, even before round 1")
	_check(not pre["morale"].has("a"), "Before round 1 taking the armband off costs nothing")
	var texts := " ".join(PackedStringArray(pre["lines"]))
	_check(texts.contains("Overlooking") and texts.contains("once") and texts.contains("Pd"), "The cost is said in words before the pick (%s)" % texts)
	var mid := Captaincy.preview(cur, [{"id": "d", "role": "captain"}], roster, 2027, true, nm)
	_check(bool(mid["used_change"]) and int(mid["morale"]["a"]) == Captaincy.STRIPPED_MORALE
			and " ".join(PackedStringArray(mid["lines"])).contains("one change this season"),
			"Mid-season, taking the armband off costs him and uses the one change, and says so")
	cur["changes"]["2027"] = 1
	var blocked := Captaincy.preview(cur, [{"id": "d", "role": "captain"}], roster, 2027, true, nm)
	_check(not bool(blocked["ok"]) and str(blocked["why_not"]) != "", "A second mid-season change is refused, with the reason")
	cur["passed"] = {"d": 2027}
	var again := Captaincy.preview(cur, [{"id": "e", "role": "captain"}], roster, 2027, false, nm)
	_check(not again["morale"].has("d"), "A player already passed over is not stung twice")
	var no_cap := Captaincy.preview(cur, [{"id": "a", "role": "vice"}], roster, 2027, false, nm)
	_check(not bool(no_cap["ok"]), "Leaders without a captain are refused")

	# In the game.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var all_named := true
	var max_leaders := 0
	for code in GameState.season.lists:
		var r := GameState.captaincy_record(str(code))
		if str(code) != GameState.my_club and Captaincy.ids(r, "captain").is_empty():
			all_named = false
		max_leaders = maxi(max_leaders, Captaincy.ids(r).size())
	_check(all_named and max_leaders <= Captaincy.MAX_LEADERS, "Every rival has a captain from the start, at most three leaders each")
	var mine := GameState.captaincy_record("GEE")
	var geelong_cap: Dictionary = {}
	for p in GameState.my_list:
		if Captaincy.role_word(mine, str(p["id"])) == "Captain":
			geelong_cap = p
	_check(not geelong_cap.is_empty() and Leadership.role_2026(geelong_cap) == "captain",
			"A real-lists career starts from the 2026 record: the Geelong captain is named")
	_check(GameState.captaincy_word(geelong_cap) == "Captain", "His profile word comes from the record")

	# Naming leaders applies exactly what the preview said.
	var senior := {}
	for p in GameState.my_list:
		if float(p.get("age", 0.0)) >= 28.0 and Leadership.games(p) >= 150 and str(p["id"]) != str(geelong_cap.get("id", "")):
			senior = p
			break
	var kid := {}
	for p in GameState.my_list:
		if str(p["id"]) != str(geelong_cap.get("id", "")) and not senior.is_empty() \
				and Leadership.of(p) < Leadership.of(senior) and not Captaincy.is_named(mine, str(p["id"])):
			kid = p
	_check(not senior.is_empty() and not kid.is_empty(), "The test list has a senior player and a lower-rated player to name")
	if not senior.is_empty() and not kid.is_empty():
		var slots := [{"id": str(kid["id"]), "role": "captain"}]
		var pv := GameState.captaincy_preview(slots)
		var morale_before := ClubLife.morale(senior)
		var res := GameState.set_captaincy(slots)
		_check(bool(res["ok"]) and Captaincy.ids(GameState.captaincy_record("GEE"), "captain") == [str(kid["id"])],
				"Naming a captain before round 1 takes effect")
		_check(ClubLife.morale(senior) - morale_before == int(pv["morale"].get(str(senior["id"]), 0)),
				"The cost applied is the cost the preview listed")
		var cid := str(kid["id"])
		for i in range(GameState.my_list.size()):
			if str(GameState.my_list[i]["id"]) == cid:
				GameState.my_list.remove_at(i)
				break
		_check(Captaincy.ids(GameState.captaincy_record("GEE"), "captain").is_empty()
				and not Captaincy.ids(GameState.captaincy_record("GEE")).has(cid),
				"A leader who has left is out of the record the moment you look, not at the next round")
		var after := GameState.set_captaincy([])
		_check(bool(after["ok"]) and not JSON.stringify(GameState.captaincy["GEE"]).contains(cid),
				"Confirming an edit never saves a leader who has gone")
		_run_on(1)
		_check(Captaincy.ids(GameState.captaincy_record("GEE"), "captain").is_empty(),
				"A captain who has left your list leaves the captaincy open")

	# A rival's captain: neutral facts for anyone, scandal or form only for an invented one.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rival := ""
	for code in GameState.season.lists:
		if str(code) != "GEE" and rival == "":
			rival = str(code)
	var rcap_id := str(Captaincy.ids(GameState.captaincy_record(rival), "captain")[0])
	for p in GameState.season.lists[rival]:
		if str(p["id"]) == rcap_id:
			p["injury_weeks"] = Captaincy.LONG_INJURY_WEEKS + 2
	var news_before := GameState.news.size()
	GameState._captaincy_week()
	var line := str(GameState.news[0]["text"]) if GameState.news.size() > news_before else ""
	_check(line.contains("stood down") and not line.contains("stripped") and not line.contains("incident")
			and Captaincy.ids(GameState.captaincy_record(rival), "captain") != [rcap_id],
			"A long injury replaces a rival's captain as a plain fact (%s)" % line)
	# With the roll forced to hit: real-named captains are untouched, an invented one is stripped as news.
	var invented_club := ""
	for code in GameState.season.lists:
		if str(code) != "GEE" and str(code) != rival and invented_club == "":
			invented_club = str(code)
	var inv_id := str(Captaincy.ids(GameState.captaincy_record(invented_club), "captain")[0])
	for p in GameState.season.lists[invented_club]:
		if str(p["id"]) == inv_id:
			p["real_name"] = ""
	var caps_before := {}
	for code in GameState.season.lists:
		caps_before[str(code)] = Captaincy.ids(GameState.captaincy_record(str(code)), "captain")
	Captaincy.strip_chance = 1.0
	GameState.last_phase = "regular"
	var n0 := GameState.news.size()
	GameState._captaincy_week()
	Captaincy.strip_chance = Captaincy.AI_STRIP_CHANCE
	var changed_real := 0
	for code in GameState.season.lists:
		if str(code) != invented_club and str(code) != "GEE" \
				and Captaincy.ids(GameState.captaincy_record(str(code)), "captain") != caps_before[str(code)]:
			changed_real += 1
	var stripped := 0
	for i in range(GameState.news.size() - n0):
		if str(GameState.news[i]["text"]).contains("stripped"):
			stripped += 1
	_check(changed_real == 0, "A real-named captain is never replaced for a scandal or a bad run (%d changed)" % changed_real)
	_check(stripped == 1 and Captaincy.ids(GameState.captaincy_record(invented_club), "captain") != caps_before[invented_club],
			"An invented captain can be stripped, as league news (%d lines)" % stripped)

	# The save.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rec_before := JSON.stringify(GameState.captaincy)
	_check(GameState.save_career() and GameState.load_career() and JSON.stringify(GameState.captaincy) == rec_before,
			"Captaincy survives a reload")
	GameState.save_career()
	var old := CareerSave.read(GameState.save_path)
	old.erase("captaincy")
	CareerSave.write(old, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career() and GameState.captaincy.is_empty(), "An older save loads with no one named")
	_run_on(1)
	_check(not GameState.captaincy_record("COL").is_empty(), "Rivals appoint on the next round of an older save")


# --- Club culture (P2-3) ------------------------------------------------------

func _test_culture() -> void:
	# Words: nothing stands out in the middle; named bands at the edges.
	_check(Culture.words("together", 0) == "" and Culture.words("together", 20) == "A tight group"
			and Culture.words("together", -50) == "A divided group"
			and Culture.words("ambition", 60) == "All in on winning now"
			and Culture.words("standards", -25) == "A relaxed group",
			"Each strand is in words, and the middle says nothing")
	# Steps are capped, clamped and keep their reason.
	var rel := {}
	var moved := Culture.change(rel, "GEE", "together", 99, "A run of four losses", 2027, "Round 6")
	_check(moved == Culture.STEP_MAX and Culture.value(rel, "GEE", "together") == Culture.STEP_MAX,
			"One moment moves a strand by at most %d" % Culture.STEP_MAX)
	for i in range(40):
		Culture.change(rel, "GEE", "together", 6, "x", 2027, "Round 7")
	_check(Culture.value(rel, "GEE", "together") == 100, "A strand stops at the top of its range")
	var one := {}
	Culture.change(one, "GEE", "together", 3, "A run of five wins", 2027, "Round 6")
	Culture.change(one, "GEE", "together", -2, "A run of four losses", 2027, "Round 9")
	var rs := Culture.reasons(one, "GEE", "together")
	_check(rs.size() == 2 and str(rs[0]["why"]) == "A run of four losses"
			and Culture.reason_text("Togetherness", rs[0]) == "Round 9, 2027. A run of four losses. Togetherness fell."
			and Culture.reason_text("Togetherness", rs[1]).ends_with("Togetherness rose."),
			"Every move keeps its reason, newest first, as a line")
	_check(Culture.value(rel, "COL", "together") == 0 and Culture.summary(rel, "COL") == "",
			"A club with no entry is neutral")
	# The movers.
	_check(Culture.run_step(4, 0)[1] == -3 and Culture.run_step(0, 5)[1] == 3 and Culture.run_step(3, 0).is_empty()
			and Culture.run_step(5, 0).is_empty(), "A run of losses or wins moves Togetherness only when it reaches its mark")
	var steps := Culture.season_steps(1, 18, true, 2.0, 5.0)
	var by := {}
	for st in steps:
		by[str(st["strand"])] = int(st["d"])
	_check(by.get("together", 0) > 0 and by.get("ambition", 0) > 0 and by.get("standards", 0) > 0,
			"Premiers with an old, disciplined side lift every strand")
	var bad := Culture.season_steps(17, 18, false, -2.0, -6.0)
	var by2 := {}
	for st in bad:
		by2[str(st["strand"])] = int(st["d"])
	_check(by2.get("together", 0) < 0 and by2.get("ambition", 0) < 0 and by2.get("standards", 0) < 0,
			"A bottom finish with a young, loose side lowers every strand")
	_check(Culture.season_steps(10, 18, false, 0.0, 0.0).is_empty(), "A mid-table, mid-age season moves nothing")
	_check(Culture.new_faces_step(12, 6.0)[0]["d"] < 0 and Culture.new_faces_step(2, 6.0)[0]["d"] > 0 and Culture.new_faces_step(7, 6.0).is_empty() and Culture.new_faces_step(8, 8.0).is_empty(),
			"Well more new faces than the league median costs Togetherness; well fewer helps; normal churn does nothing")
	for strand in Culture.STRANDS:
		for t in [-100, -60, -30, 0, 30, 60, 100]:
			var w := Culture.words(str(strand[0]), t)
			_check(not w.to_lower().contains("bad influence") and not w.to_lower().contains("toxic"),
					"No band is a verdict on a person (%s %d)" % [str(strand[0]), t])

	# In the game: a season through, every club on the same rules.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		if GameState.week_event_pending():
			GameState.resolve_week_event(0)
		GameState.advance()
		guard += 1
	var rel2: Dictionary = GameState.relations
	_check(int(rel2.get("k:done", {}).get("season", 0)) == GameState.season_year, "The season's close is counted once")
	var moved_clubs := 0
	var values := {}
	for code in GameState.season.lists:
		var any := false
		for s in Culture.STRANDS:
			var t := Culture.value(rel2, str(code), str(s[0]))
			values[t] = true
			if t != 0:
				any = true
		if any:
			moved_clubs += 1
	_check(moved_clubs >= 12 and values.size() >= 4, "Most clubs have a culture after a season, and they differ (%d clubs, %d values)" % [moved_clubs, values.size()])
	var again := JSON.stringify(rel2)
	GameState._culture_season()
	_check(JSON.stringify(GameState.relations) == again, "Closing the season twice moves nothing")
	var told := {}
	var bad_lines := 0
	for n in GameState.news:
		if str(n.get("kind", "")) == "culture":
			var txt := str(n["text"])
			for code in GameState.season.lists:
				if txt.begins_with(GameDB.club_name(str(code))):
					told[str(code)] = int(told.get(str(code), 0)) + 1
			if txt.contains(GameDB.club_name(GameState.my_club)):
				bad_lines += 1
	var most := 0
	for c in told:
		most = maxi(most, int(told[c]))
	_check(most <= 1 and bad_lines == 0, "Rival culture is in the news at most once a club a season, never for your own club")

	# New faces at the rollover.
	var rival := ""
	for code in GameState.season.lists:
		if str(code) != GameState.my_club and rival == "":
			rival = str(code)
	var before := Culture.value(GameState.relations, rival, "together")
	var n := 0
	for p in GameState.season.lists[rival]:
		if n < 16:
			p["career"] = {"games": 50, "goals": 0, "stints": [["ZZZ", 2025, 2025, 20, 0]], "through": 2026, "unknown": []}
			n += 1
	GameState._culture_marks()["roll"] = 0
	GameState._culture_rollover()
	var rs2 := Culture.reasons(GameState.relations, rival, "together")
	_check(Culture.value(GameState.relations, rival, "together") == before - 4 and str(rs2[0]["why"]).contains("new faces"),
			"Sixteen new faces from other clubs cost Togetherness at the rollover, with the reason")

	# A promise you broke is a fact about your club.
	GameState._culture_move(GameState.my_club, "together", -2, "You broke your word on a player's run of games")
	var mine := Culture.reasons(GameState.relations, GameState.my_club, "together")
	_check(not mine.is_empty() and str(mine[0]["why"]).begins_with("You broke your word"), "Your own reasons are facts in football words")

	# An older save has no strands: everyone neutral, nothing breaks.
	GameState.reset()
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.save_career()
	var old := CareerSave.read(GameState.save_path)
	old.erase("relations")
	CareerSave.write(old, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career() and Culture.summary(GameState.relations, "GEE") == "", "An older save loads with every club neutral")
	_run_on(2)
	_check(not GameState.relations.has("k:done") or int(GameState.relations["k:done"].get("season", 0)) == 0,
			"…and carries on without closing a season")


## League news about a real club is never a negative claim: the negative bands
## stay on your own page.
func _test_culture_news() -> void:
	var neg_ok := true
	var pos_ok := true
	for s in Culture.STRANDS:
		for t in [-100, -60, -40, -25]:
			# Patient and rebuilding are not a claim against a club; the rest are.
			if str(s[0]) != "ambition" and Culture.news_ok(str(s[0]), t):
				neg_ok = false
			if str(s[0]) == "ambition" and not Culture.news_ok("ambition", t):
				pos_ok = false
		for t in [15, 30, 60]:
			if not Culture.news_ok(str(s[0]), t):
				pos_ok = false
	_check(neg_ok and pos_ok, "Only positive bands make the news (negative ok %s, positive ok %s)" % [neg_ok, pos_ok])
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rival_a := ""
	var rival_b := ""
	for code in GameState.season.lists:
		if str(code) == GameState.my_club:
			continue
		if rival_a == "":
			rival_a = str(code)
		elif rival_b == "":
			rival_b = str(code)
	for i in range(8):
		GameState._culture_move(rival_a, "together", -6, "A run of losses")
	var bad_lines := 0
	for n in GameState.news:
		if str(n.get("kind", "")) == "culture" and str(n["text"]).begins_with(GameDB.club_name(rival_a)):
			bad_lines += 1
	_check(Culture.words("together", Culture.value(GameState.relations, rival_a, "together")) == "A divided group" and bad_lines == 0,
			"A rival that turns into a divided group is not in the news")
	for i in range(4):
		GameState._culture_move(rival_b, "together", 6, "Played finals")
	var good_lines := 0
	for n in GameState.news:
		if str(n.get("kind", "")) == "culture" and str(n["text"]).begins_with(GameDB.club_name(rival_b)):
			good_lines += 1
	_check(good_lines == 1, "A rival that becomes a tight group is, once (%d lines)" % good_lines)
	for i in range(8):
		GameState._culture_move(GameState.my_club, "together", -6, "A run of losses")
	_check(Culture.words("together", Culture.value(GameState.relations, GameState.my_club, "together")) == "A divided group",
			"The negative bands still show on your own club's page")


func _test_culture_reasons_read_cleanly() -> void:
	var rel := {}
	Culture.change(rel, "GEE", "together", -3, "A run of four losses", 2027, "Round 4")
	Culture.change(rel, "GEE", "together", -3, "A run of four losses", 2027, "Round 12")
	Culture.change(rel, "GEE", "together", 3, "Played finals", 2027, "Off-season")
	var g := Culture.grouped(rel, "GEE", "together")
	_check(g.size() == 2 and int(g[1]["n"]) == 2
			and Culture.group_text("Togetherness", g[1]) == "A run of four losses, twice, in rounds 4 and 12, 2027. It cost Togetherness.",
			"The same reason twice in a season is one line: %s" % Culture.group_text("Togetherness", g[1]))
	var yrs := {}
	for y in [2025, 2026, 2027]:
		Culture.change(yrs, "GEE", "standards", 4, "The list holds itself to a higher standard than most clubs", y, "Off-season")
	var gy := Culture.grouped(yrs, "GEE", "standards")
	_check(gy.size() == 1 and Culture.group_text("Standards", gy[0]) == "The list has held itself to a higher standard than most clubs for three off-seasons.",
			"The same reason in three off-seasons is one line: %s" % Culture.group_text("Standards", gy[0]))
	_check(Culture.quiet_words(0, false) == "Nothing stands out yet" and Culture.quiet_words(3, true) == "Starting to build"
			and Culture.quiet_words(-3, true) == "Starting to slip" and not Culture.quiet_words(3, true).contains("normal"),
			"A strand with no named band follows its latest move and never contradicts it")
	var ages := Culture.season_steps(10, 18, false, 1.5, 0.0)
	_check(not str(ages[0]["why"]).contains("28"), "An age reason carries no number")


func _test_culture_settles() -> void:
	var rel := {}
	for i in range(5):
		Culture.change(rel, "GEE", "together", 6, "Played finals", 2027, "Off-season")
	var before := Culture.value(rel, "GEE", "together")
	Culture.settle(rel, "GEE", "together")
	var after := Culture.value(rel, "GEE", "together")
	_check(after < before and after > 0 and Culture.reasons(rel, "GEE", "together").size() == 5,
			"A strand settles back a little each season without adding a reason (%d to %d)" % [before, after])
	var quiet := {}
	Culture.change(quiet, "GEE", "standards", 2, "x", 2027, "Round 1")
	Culture.settle(quiet, "GEE", "standards")
	_check(Culture.value(quiet, "GEE", "standards") == 2, "A strand near neutral does not settle further")


## Every mover's sign matches its words: a loss fell, a win rose, a bottom finish
## fell, premiers rose; the reasons the director reads never contradict.
func _test_culture_signs_match_words() -> void:
	var ok := true
	var losses := Culture.run_step(4, 0)
	var wins := Culture.run_step(0, 5)
	ok = ok and int(losses[1]) < 0 and str(losses[2]).contains("loss") and int(wins[1]) > 0 and str(wins[2]).contains("win")
	_check(ok, "A run of losses lowers Togetherness and a run of wins lifts it")
	var by_why := {}
	for args in [[1, 18, true, 0.0, 0.0], [6, 18, false, 0.0, 0.0], [17, 18, false, 0.0, 0.0],
			[10, 18, false, 2.0, 5.0], [10, 18, false, -2.0, -5.0]]:
		for st in Culture.season_steps(args[0], args[1], args[2], args[3], args[4]):
			by_why[str(st["why"])] = int(st["d"])
	var want := {"Premiers": 1, "Played finals": 1, "Finished near the bottom of the ladder": -1,
			"An experienced side": 1, "A young side": -1,
			"The list holds itself to a higher standard than most clubs": 1, "The list lets its standards slip more than most clubs": -1}
	var wrong := []
	for w in want:
		if not by_why.has(w) or (int(by_why[w]) > 0) != (int(want[w]) > 0):
			wrong.append(w)
	_check(wrong.is_empty(), "Every season mover's sign matches its words (%s)" % ", ".join(PackedStringArray(wrong)))
	var more := Culture.new_faces_step(12, 6.0)
	var fewer := Culture.new_faces_step(1, 6.0)
	_check(int(more[0]["d"]) < 0 and str(more[0]["why"]).contains("more") and int(fewer[0]["d"]) > 0 and str(fewer[0]["why"]).contains("fewer"),
			"New faces: more than most lowers Togetherness, fewer lifts it")
	# One season never says both premiers and a bottom finish.
	var both := 0
	for pos in range(1, 19):
		var whys := PackedStringArray()
		for st in Culture.season_steps(pos, 18, pos == 1, 0.0, 0.0):
			whys.append(str(st["why"]))
		if "Premiers" in whys and "Finished near the bottom of the ladder" in whys:
			both += 1
	_check(both == 0, "No season is both premiers and a bottom finish")


func _test_culture_headline() -> void:
	var rel := {}
	_check(Culture.headline(rel, "GEE") == "Nothing stands out yet", "The row says when nothing stands out")
	for i in range(3):
		Culture.change(rel, "GEE", "together", 6, "Played finals", 2027, "Off-season")
	_check(Culture.headline(rel, "GEE") == "Togetherness", "One strand reads by its name")
	for i in range(3):
		Culture.change(rel, "GEE", "standards", 6, "x", 2027, "Off-season")
	_check(Culture.headline(rel, "GEE") == "Standards, togetherness", "Several read by name: %s" % Culture.headline(rel, "GEE"))


func _test_culture_order_and_tails() -> void:
	var rel := {}
	Culture.change(rel, "GEE", "together", 3, "Premiers", 2025, "Off-season")
	Culture.change(rel, "GEE", "together", -3, "A run of four losses", 2026, "Round 10")
	Culture.change(rel, "GEE", "together", 3, "Played finals", 2027, "Off-season")
	var g := Culture.grouped(rel, "GEE", "together")
	_check(g.size() == 3 and str(g[0]["why"]) == "Played finals" and str(g[1]["why"]) == "A run of four losses" and str(g[2]["why"]) == "Premiers",
			"Reasons run newest season first")
	_check(Culture.group_text("Togetherness", g[0]) == "Played finals in 2027." and Culture.group_text("Togetherness", g[2]) == "Premiers in 2025."
			and Culture.group_text("Togetherness", g[1]) == "A run of four losses in round 10, 2026. It cost Togetherness.",
			"A rise carries no tail (the page says it once); only a fall says it cost the strand")


func _test_culture_sentences() -> void:
	var rel := {}
	Culture.change(rel, "GEE", "together", 3, "A settled list: far fewer new faces from other clubs than most", 2027, "Off-season")
	Culture.change(rel, "GEE", "together", 3, "Played finals", 2026, "Off-season")
	Culture.change(rel, "GEE", "together", 3, "Played finals", 2027, "Off-season")
	Culture.change(rel, "GEE", "together", 3, "Five wins in a row", 2025, "Round 14")
	Culture.change(rel, "GEE", "together", 3, "Five wins in a row", 2026, "Round 6")
	var g := Culture.grouped(rel, "GEE", "together")
	var texts := PackedStringArray()
	for x in g:
		texts.append(Culture.group_text("Togetherness", x))
	_check("A settled list in 2027: far fewer new faces from other clubs than most." in texts
			and "Played finals in 2026 and 2027." in texts and "Five wins in a row in 2025 and 2026." in texts,
			"Reasons read as football sentences with the time at the end (%s)" % " | ".join(texts))
	_check(Culture.group_text("Togetherness", g[0]).contains("2027"), "The newest year leads (%s)" % texts[0])
