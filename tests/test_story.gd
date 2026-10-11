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
