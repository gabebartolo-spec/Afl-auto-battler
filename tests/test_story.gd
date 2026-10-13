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
	_test_choice_stakes_are_stated()
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
	_test_captain_cards()
	_test_group_words_are_sentence_case()
	_test_captain_cards_in_play()
	_test_captain_from_the_start()
	_test_time_trial_names()
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


## Copy truth for the lines under a choice: every mechanical effect of every
## choice appears in them, a gain on the Gain line and a cost on the Cost line,
## gains first; and no line names an effect the choice lacks. What each effect
## is worth to the coach is read straight off the effects here, apart from the
## engine's own wording, so the lines cannot drift from what the choice does.
const GAIN_WORDS := {
	"morale": "(?i)morale", "xp": "development", "board": "(?i)board confidence", "trust": "trusts you (a lot |a little )?more",
	"fresh": "legs", "promise_win": "Win and", "extend_early": "signs on", "captaincy_swap": "takes the armband",
}
const COST_WORDS := {
	"morale": "(?i)morale", "board": "(?i)board confidence", "trust": "trusts you (a lot |a little )?less",
	"rest": "misses", "heavy_legs": "Heavy legs", "sore": "breaks down", "expects_game": "expects a game",
	"start_backing": "expects to be picked", "back_kid": "is promised", "promise_win": "Lose and", "extend_early": "Locked in", "captaincy_swap": "mid-season",
}
const SAMPLE_FACTS := {"sore_odds": "about 1 in 6", "run_games": 3, "early_price": "$1m", "more_seasons": "two more seasons"}


## [gains, costs]: the kinds of effect a choice really has (a flag, a note or an
## explanation moves nothing the coach feels and is in neither).
func _stakes_in(effects: Array) -> Array:
	var gains := []
	var costs := []
	for e in effects:
		var op := str(e.get("op", ""))
		var d := int(e.get("d", 0))
		if op == "delegate":
			for side in ["held", "failed"]:
				var inner := _stakes_in(e.get(side, []))
				for k in inner[0]:
					if not gains.has(k):
						gains.append(k)
				for k in inner[1]:
					if not costs.has(k):
						costs.append(k)
			continue
		if op == "captaincy_swap":
			gains.append(op)
			costs.append_array([op, "morale", "trust"])
			continue
		if op in ["morale", "board", "trust"]:
			if d > 0 and not gains.has(op):
				gains.append(op)
			elif d < 0 and not costs.has(op):
				costs.append(op)
		elif op in ["xp", "fresh", "promise_win", "extend_early"] and not gains.has(op):
			gains.append(op)
		if op in ["rest", "heavy_legs", "sore", "expects_game", "start_backing", "back_kid", "promise_win", "extend_early"] and not costs.has(op):
			costs.append(op)
	return [gains, costs]


## What is wrong with these lines for these effects ([] when they are true).
func _stakes_problems(effects: Array, lines: PackedStringArray) -> Array:
	var problems := []
	var want := _stakes_in(effects)
	var gain_line := ""
	var cost_line := ""
	var order := []
	for l in lines:
		if l.begins_with("Gain: "):
			gain_line = l
			order.append("gain")
		elif l.begins_with("Cost: "):
			cost_line = l
			order.append("cost")
		elif l.begins_with("As it stands the group"):
			pass
		else:
			problems.append("a line without its marker (%s)" % l)
	if order == ["cost", "gain"]:
		problems.append("costs before gains")
	for side in 2:
		var table: Dictionary = GAIN_WORDS if side == 0 else COST_WORDS
		var line := gain_line if side == 0 else cost_line
		var label := "gain" if side == 0 else "cost"
		for kind in table:
			var named := RegEx.create_from_string(str(table[kind])).search(line) != null
			var has: bool = (want[side] as Array).has(kind)
			if named and not has and not (kind == "board" and (want[side] as Array).has("promise_win")):
				problems.append("%s line names %s which the effects do not contain" % [label, kind])
			if has and not named:
				problems.append("%s line leaves out %s" % [label, kind])
	for l in lines:
		if l.contains("{") or l.contains("}") or RegEx.create_from_string("[+-][0-9]|XP").search(l) != null:
			problems.append("leaves a brace or a coefficient in the words")
	if (want[0] as Array).is_empty() and (want[1] as Array).is_empty() and not lines.is_empty():
		problems.append("states something where the choice does nothing")
	return problems


func _test_choice_stakes_are_stated() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var bad := []
	var mechanical := 0
	var shown := 0
	var choices := 0
	var both := 0
	var nothing := []
	for t in StoryDeck.all():
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		for o in card["options"]:
			choices += 1
			var effects: Array = o["effects"]
			var lines := StoryEngine.stakes_lines(effects, card["facts"])
			var want := _stakes_in(effects)
			if not (want[0] as Array).is_empty() or not (want[1] as Array).is_empty():
				mechanical += 1
			else:
				nothing.append("%s/%s" % [t["id"], o["key"]])
			if not lines.is_empty():
				shown += 1
			if lines.size() == 2:
				both += 1
			for problem in _stakes_problems(effects, lines):
				bad.append("%s/%s %s (%s)" % [t["id"], o["key"], problem, " ".join(lines)])
	_check(bad.is_empty(), "Every effect of every choice is in its lines, gains and costs, and no line names one it lacks: %s" % " | ".join(PackedStringArray(bad.slice(0, 8))))
	_check(mechanical >= 100 and shown == mechanical and both >= 20, "A line under every choice that does something, none under the rest (%d of %d choices, %d with a gain and a cost)" % [shown, choices, both])
	print("Choices that do nothing mechanical (%d): %s" % [nothing.size(), ", ".join(PackedStringArray(nothing))])
	# The check itself must bite: a missing line, a gain or cost on the wrong line, a false one and a leftover brace are caught.
	var heavy := [{"op": "heavy_legs", "who": "all"}, {"op": "xp", "d": 6}]
	var good := PackedStringArray(["Gain: Some extra development for everyone.", "Cost: Heavy legs on game day, and more soft-tissue risk."])
	_check(_stakes_problems(heavy, good).is_empty(), "The check passes the true lines for a gain and a cost")
	_check(not _stakes_problems(heavy, PackedStringArray([good[1]])).is_empty(), "The check catches a gain left out")
	_check(not _stakes_problems(heavy, PackedStringArray([good[0]])).is_empty(), "The check catches a cost left out")
	_check(not _stakes_problems(heavy, PackedStringArray(["Gain: Heavy legs on game day.", "Cost: Some extra development."])).is_empty(), "The check catches a gain and a cost on the wrong lines")
	_check(not _stakes_problems([{"op": "morale", "d": -5}], PackedStringArray([])).is_empty(), "The check catches a morale drop with no line")
	_check(not _stakes_problems([{"op": "morale", "d": 5}], PackedStringArray(["Gain: His morale goes up.", "Cost: He misses this week's game."])).is_empty(), "The check catches a cost the effects lack")
	_check(not _stakes_problems([{"op": "sore"}], PackedStringArray(["Cost: He breaks down: {sore_odds} chance."])).is_empty(), "The check catches an unfilled brace")
	_check(not _stakes_problems([{"op": "flag"}], PackedStringArray(["Gain: His morale goes up."])).is_empty(), "The check catches a line on a choice that does nothing")
	_check(not _stakes_problems(heavy, PackedStringArray([good[1], good[0]])).is_empty(), "The check catches costs before gains")
	# Every effect line names the thing that moves; no mood word stands in for it.
	var vague := RegEx.create_from_string("(?i)\\b(lift|lifts|flat|stings|sours|thrilled|a bit off|likes it|won't like)\\b")
	var nouns := {"morale": "orale", "xp": "development", "board": "Board confidence", "trust": "trusts you", "rest": "game",
			"sore": "sore", "fresh": "legs", "heavy_legs": "legs", "expects_game": "game", "start_backing": "games",
			"promise_win": "board confidence", "extend_early": "a season"}
	var unnamed := []
	for t in StoryDeck.all():
		for c in t["choices"]:
			for e in c.get("effects", []):
				var op := str(e.get("op", ""))
				if not nouns.has(op):
					continue
				var w := StoryEngine.describe({"effects": [e]}, SAMPLE_FACTS)
				if w == "" or not w.contains(str(nouns[op])) or vague.search(w) != null:
					unnamed.append("%s/%s %s: %s" % [t["id"], c["key"], op, w])
	_check(unnamed.is_empty(), "Every effect line names the thing that moves, with no vague mood word: %s" % " | ".join(PackedStringArray(unnamed.slice(0, 6))))
	# No card line, the captain's "leave it to him" lines included (standing either way), uses a mood word for an effect.
	var vague_lines := []
	for t in StoryDeck.all():
		for c in t["choices"]:
			for holds in [true, false]:
				var f := SAMPLE_FACTS.duplicate()
				f["delegate_holds"] = holds
				f["name"] = "Sam"
				f["vice_name"] = "Joe"
				f["kid_name"] = "Kid"
				var txt := " ".join(StoryEngine.stakes_lines(c.get("effects", []), f))
				if vague.search(txt) != null or txt.contains("{"):
					vague_lines.append("%s/%s: %s" % [t["id"], c["key"], txt])
	_check(vague_lines.is_empty(), "No card line uses lift or flat or a brace, delegate lines included: %s" % " | ".join(PackedStringArray(vague_lines.slice(0, 4))))
	# The lines read the effects and change none.
	var before := JSON.stringify(heavy)
	StoryEngine.stakes_lines(heavy, {})
	_check(JSON.stringify(heavy) == before, "Wording the stakes leaves the effects as they were")
	# No card repeats under its heading what the lines under its buttons say.
	var repeats := []
	for t in StoryDeck.all():
		var st := str(t.get("stakes", ""))
		if st == "":
			continue
		var all_lines := ""
		for c in t["choices"]:
			all_lines += " ".join(StoryEngine.stakes_lines(c.get("effects", []), SAMPLE_FACTS))
		for kw in ["breaks down", "heavy legs", "expects a game", "promise breaks", "lose and"]:
			if st.to_lower().contains(kw) and all_lines.to_lower().contains(kw):
				repeats.append("%s (%s)" % [t["id"], kw])
	_check(repeats.is_empty(), "A card's own stakes line never repeats the lines under its choices: %s" % " | ".join(PackedStringArray(repeats)))


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
	(ctx["club"] as Dictionary)["losing_run"] = 5  # so a card that waits on a losing run can be reached
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
			# A card that asks for a flag on its subject (a captain who found his form).
			var where_flag := str((t["subject"].get("where", {}) as Dictionary).get("flag", ""))
			if where_flag != "":
				for f in players:
					var pid2 := str(f["id"])
					if not st["flags"].has(pid2):
						st["flags"][pid2] = {}
					st["flags"][pid2][where_flag] = 5
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
	_check(hint.contains("He trusts you"), "The choice says what it does to his trust (%s)" % hint)
	_check(Trust.value(GameState.relations, key) == 10 and out.contains("He trusts you more"),
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
	_check(str(card["options"][0]["detail"]).contains("counts for more because he trusts you"),
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


# --- The captain's cards (P2-4) -----------------------------------------------

func _captain_cards() -> Array:
	return StoryDeck.all().filter(func(c): return str(c["id"]).begins_with("captain_"))


func _test_captain_cards() -> void:
	var cards := _captain_cards()
	_check(cards.size() == 18, "The captain's deck has its 18 cards (%d)" % cards.size())
	var bad_voice := []
	for c in cards:
		var text := JSON.stringify(c).to_lower()
		for stat_word in ["discipline", "i will ", "do not ", "will not ", "cannot "]:
			if text.contains(stat_word):
				bad_voice.append("%s: %s" % [c["id"], stat_word])
	_check(bad_voice.is_empty(), "The captain's cards talk like a coach, with no stat-speak (%s)" % ", ".join(PackedStringArray(bad_voice)))
	var wrong_subject := []
	for c in cards:
		var w: Dictionary = (c["subject"] as Dictionary).get("where", {})
		if not bool(w.get("captain", false)):
			wrong_subject.append(str(c["id"]))
	_check(wrong_subject.is_empty(), "Every captain card is about your captain (%s)" % ", ".join(PackedStringArray(wrong_subject)))
	var private_ids := []
	for c in cards:
		if bool(c.get("private", false)):
			private_ids.append(str(c["id"]))
	private_ids.sort()
	_check(private_ids == ["captain_slump_flat", "captain_slump_good", "captain_slump_mid", "captain_slump_start",
			"captain_succession_next", "captain_succession_start"],
			"Only the slump and succession cards are private (%s)" % ", ".join(PackedStringArray(private_ids)))
	for c in cards:
		if str(c["id"]).begins_with("captain_contract"):
			_check(not bool(c.get("private", false)), "The contract arc is about the contract, a football fact (%s)" % c["id"])
	var contract_end := ""
	for c in cards:
		if str(c["id"]) == "captain_contract_signed" or str(c["id"]) == "captain_contract_open":
			contract_end += JSON.stringify(c).to_lower()
	_check(not contract_end.contains("fall") and not contract_end.contains("angry") and not contract_end.contains("walk out"),
			"A contract's end is a club or contract fact, never a fall-out")
	var talk_slump := StoryDeck.by_id(StoryDeck.all(), "captain_slump_start")
	var flags_by_choice := {}
	for ch in talk_slump["choices"]:
		var names := []
		for e in ch["effects"]:
			if str(e.get("op", "")) == "flag":
				names.append(str(e["name"]))
		flags_by_choice[str(ch["key"])] = names
	_check(flags_by_choice["talk"].has("cs_good") and flags_by_choice["back"].has("cs_good") and not flags_by_choice["rest"].has("cs_good"),
			"The slump's good ending follows a word or a backed run, not a rest")
	var mid := StoryDeck.by_id(StoryDeck.all(), "captain_slump_mid")
	var mid_good := 0
	for ch in mid["choices"]:
		for e in ch["effects"]:
			if str(e.get("op", "")) == "flag" and str(e["name"]) == "cs_good":
				mid_good += 1
	_check(mid_good == 2 and int(mid["choices"].size()) == 3, "At the midpoint, keeping on backing him or another word leads to the good ending; leaving it does not")
	var succ := StoryDeck.by_id(StoryDeck.all(), "captain_succession_next")
	_check(succ["choices"].size() == 2, "Succession offers two answers, no free pick")
	var wait := StoryDeck.by_id(StoryDeck.all(), "captain_contract_start")
	_check(wait["choices"].size() == 2, "The contract question has one answer each way")

	# A dispute left to the captain follows the printed rule.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var cap: Dictionary = {}
	var rec := GameState.captaincy_record("GEE")
	for p in GameState.my_list:
		if Captaincy.role_of(rec, str(p["id"])) == "captain":
			cap = p
	_check(not cap.is_empty(), "Geelong has a captain to hold the card")
	if cap.is_empty():
		return
	var card := GameState.story_card("captain_selection_word", cap)
	var leave_opt: Dictionary = (card["options"] as Array)[1]
	var leave_detail := str(leave_opt["detail"])
	var leave_rule := str(leave_opt["rule"])
	var del_fx: Dictionary = {}
	for ch in StoryDeck.by_id(StoryDeck.all(), "captain_selection_word")["choices"]:
		if str(ch["key"]) == "leave":
			del_fx = ch["effects"][0]
	var held_words := StoryEngine.describe({"effects": del_fx["held"]}, card["facts"])
	var failed_words := StoryEngine.describe({"effects": del_fx["failed"]}, card["facts"])
	var stands: bool = bool(card["facts"]["delegate_holds"])
	_check(leave_detail.contains(held_words.substr(1)) and leave_detail.contains(failed_words.substr(1))
			and leave_detail.contains("would listen to" if stands else "wouldn't listen to")
			and not leave_detail.to_lower().contains("settle") and not leave_detail.contains("Leadership"),
			"The card line says what happens both ways, from the choice's own effects, and which way it stands (%s)" % leave_detail)
	_check(leave_rule.contains("Leadership %d" % Leadership.of(cap)) and leave_rule.contains("%d or more" % StoryDeck.HOLDS_AT)
			and leave_rule.contains("%d or more" % StoryDeck.HOLDS_WITH_TRUST) and not leave_rule.to_lower().contains("settle"),
			"The rule one tap away prints his Leadership and the thresholds from the constants (%s)" % leave_rule)
	_check(bool(card.get("choice_notes", false)), "A captain card shows what each choice does under its button")
	var holds := StoryDeck.HOLDS_AT
	for case in [[70, 0, true], [40, 80, false], [50, 40, true], [50, 0, false], [60, 0, true], [44, 90, false]]:
		var lead := int(case[0])
		var trust_value := int(case[1])
		var band := Trust.band(trust_value)
		var expect: bool = lead >= holds or (lead >= StoryDeck.HOLDS_WITH_TRUST and (band == "trusts" or band == "close"))
		_check(expect == bool(case[2]), "The rule: Leadership %d, trust %d holds = %s" % [lead, trust_value, str(case[2])])

	# Held and failed outcomes move the group, from the rule alone.
	for side in [true, false]:
		var facts: Dictionary = card["facts"]
		facts["delegate_holds"] = side
		var before := ClubLife.morale(GameState.my_list[0])
		var out := ClubStories.apply_choice(GameState, card, 1)
		var after := ClubLife.morale(GameState.my_list[0])
		_check((after - before == 2) if side else (after - before == -2),
				"Left to the captain, it %s: the group's mood moves %d (%s)" % ["holds" if side else "doesn't hold", after - before, out])

	# The young player a captain puts forward gets his run.
	var kid_card := GameState.story_card("captain_young_player", cap)
	var kid_id := str(kid_card["facts"].get("kid_id", ""))
	if kid_id != "":
		ClubStories.apply_choice(GameState, kid_card, 0)
		var kid := GameState.list_player(kid_id)
		_check(Backing.is_active(kid), "Giving the young player a run starts his promised run")
	else:
		_check(true, "(no young player under ten games on this list)")

	# Succession: the vice-captain takes the armband through the Captaincy rules.
	var swap := GameState.story_card("captain_succession_next", cap)
	var vice_id := str(swap["facts"].get("vice_id", ""))
	_check(vice_id != "" and bool(swap["facts"].get("has_vice", false)), "Geelong has a vice-captain to take over")
	if vice_id != "":
		var line := ClubStories.apply_choice(GameState, swap, 0)
		var after_rec := GameState.captaincy_record("GEE")
		_check(Captaincy.role_of(after_rec, vice_id) == "captain" and Captaincy.role_of(after_rec, str(cap["id"])) == "vice",
				"The vice-captain takes the armband and the old captain stays in the leadership group (%s)" % line)


func _test_group_words_are_sentence_case() -> void:
	var words := StoryEngine._morale_words(-3, "all") + " " + StoryEngine._morale_words(-8, "others") + " " + StoryEngine._morale_words(-3, "side")
	_check(words.contains("Morale down a little across the whole list.") and words.contains("Morale down in the rest of the group.")
			and words.contains("Morale down a little across the side."), "A group's mood line is in sentence case and names morale (%s)" % words)


## The paths a normal career rarely walks: a captain who can't settle a dispute, a stale
## succession card, and the slump arc in full.
func _test_captain_cards_in_play() -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rec := GameState.captaincy_record("GEE")
	var cap: Dictionary = {}
	for p in GameState.my_list:
		if Captaincy.role_of(rec, str(p["id"])) == "captain":
			cap = p
	if cap.is_empty():
		_check(false, "Geelong has a captain for the in-play checks")
		return
	# A young, unproven captain who doesn't trust you can't settle a dispute.
	cap["real_name"] = ""
	cap["age"] = 19.0
	cap["career"] = {"games": 0, "goals": 0, "stints": [], "through": 2026, "unknown": []}
	cap["gm"] = 0
	var weak := Leadership.of(cap)
	_check(weak < StoryDeck.HOLDS_WITH_TRUST, "The test captain's Leadership is low (%d)" % weak)
	var failed_copy := {"captain_selection_word": "It didn't land with the group.",
			"captain_group_flat": "The group stayed flat.", "captain_harder_session": "The session fell apart."}
	var delta := {"captain_selection_word": -2, "captain_group_flat": -2, "captain_harder_session": -2}
	var leave_index := {"captain_selection_word": 1, "captain_group_flat": 2, "captain_harder_session": 2}
	for id in failed_copy:
		var card := GameState.story_card(id, cap)
		_check(not bool(card["facts"].get("delegate_holds", true)), "%s: with this captain it wouldn't hold" % id)
		var detail := str(card["options"][int(leave_index[id])]["detail"])
		_check(detail.contains("wouldn't listen to"), "%s: the choice says the group wouldn't listen (%s)" % [id, detail])
		var before := ClubLife.morale(GameState.my_list[0])
		var out := ClubStories.apply_choice(GameState, card, int(leave_index[id]))
		_check(out.contains(str(failed_copy[id])) and ClubLife.morale(GameState.my_list[0]) - before == int(delta[id]),
				"%s: left to a captain who can't, it fails with its own words and cost (%s)" % [id, out])

	# A stale succession card does nothing, and never makes a co-captain.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	rec = GameState.captaincy_record("GEE")
	cap = {}
	for p in GameState.my_list:
		if Captaincy.role_of(rec, str(p["id"])) == "captain":
			cap = p
	var swap := GameState.story_card("captain_succession_next", cap)
	var other := {}
	for p in GameState.my_list:
		if not Captaincy.is_named(rec, str(p["id"])):
			other = p
			break
	GameState.set_captaincy([{"id": str(other["id"]), "role": "captain"}])
	var before_ids := Captaincy.ids(GameState.captaincy_record("GEE"))
	var line := ClubStories.apply_choice(GameState, swap, 0)
	_check(Captaincy.ids(GameState.captaincy_record("GEE")) == before_ids and line.contains("has changed"),
			"A succession card older than the captaincy changes nothing (%s)" % line)

	# The slump arc, in full, in both endings.
	for scenario in ["good", "flat", "rested_then_word"]:
		GameState.reset()
		GameState.career_seed = SUITE_SEED
		GameState.replay_seed = SUITE_SEED
		GameState.start_season("GEE", GameDB.club_list("GEE"))
		rec = GameState.captaincy_record("GEE")
		cap = {}
		for p in GameState.my_list:
			if Captaincy.role_of(rec, str(p["id"])) == "captain":
				cap = p
		cap["real_name"] = ""
		cap["morale"] = 40
		var ids := {}
		var deck := StoryDeck.all()
		for k in ["captain_slump_start", "captain_slump_mid", "captain_slump_good", "captain_slump_flat"]:
			ids[k] = StoryDeck.by_id(deck, k)
		GameState.losing_streak = 2  # a captain's form dips with the team's
		var ctx := ClubStories.context(GameState)
		var rng := RandomNumberGenerator.new()
		var w := GameState.story_week()
		var starts := not StoryEngine.eligible_subject(ids["captain_slump_start"], ctx, GameState.story, w, rng).is_empty()
		_check(starts, "%s: a low-spirited, selected captain triggers the slump" % scenario)
		var start_choice := 0 if scenario == "good" else 2
		GameState.week_events = [GameState.story_card("captain_slump_start", cap)]
		GameState.resolve_card(0, start_choice)
		_advance_quietly(4, cap, ids)
		cap["morale"] = 60
		ctx = ClubStories.context(GameState)
		w = GameState.story_week()
		var mid_ok := not StoryEngine.eligible_subject(ids["captain_slump_mid"], ctx, GameState.story, w, rng).is_empty()
		_check(mid_ok, "%s: a few weeks on, the midpoint card comes up" % scenario)
		var mid_choice := 0 if scenario == "good" else (2 if scenario == "flat" else 1)
		GameState.week_events = [GameState.story_card("captain_slump_mid", cap)]
		GameState.resolve_card(0, mid_choice)
		_advance_quietly(5, cap, ids)
		ctx = ClubStories.context(GameState)
		w = GameState.story_week()
		var good := not StoryEngine.eligible_subject(ids["captain_slump_good"], ctx, GameState.story, w, rng).is_empty()
		var flat := not StoryEngine.eligible_subject(ids["captain_slump_flat"], ctx, GameState.story, w, rng).is_empty()
		var want_good: bool = scenario != "flat"
		_check(good == want_good and flat == not want_good,
				"%s: the %s ending follows (good %s, flat %s)" % [scenario, "good" if want_good else "flat", str(good), str(flat)])


## Play rounds without answering anything the engine draws for itself, and forget
## that it drew the arc's cards, so the test decides what the arc sees.
func _advance_quietly(rounds: int, cap: Dictionary, ids: Dictionary) -> void:
	GameState.stories_on = false  # no cards drawn while time passes
	for r in range(rounds):
		GameState.advance()
		# The engine's own draws in the leadership category would crowd the arc out
		# (no category twice in five weeks); forget them too.
		for c in StoryDeck.all():
			if str(c.get("category", "")) == "leadership":
				(GameState.story["last"] as Dictionary).erase(str(c["id"]))
		(GameState.story["subj"] as Dictionary).erase(str(cap["id"]))
		var kept := []
		for row in GameState.story["cats"]:
			if str(row[1]) != "leadership":
				kept.append(row)
		GameState.story["cats"] = kept
	GameState.stories_on = true


## Director 2026-10-12: in a redraft or custom career your club starts with a captain
## named by the same rule as the rivals; a real-lists career keeps the real captain.
func _test_captain_from_the_start() -> void:
	# A redraft: a list with no 2026 record behind it (Collingwood's players at Geelong).
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("COL"))
	var rec := GameState.captaincy_record("GEE")
	var caps := Captaincy.ids(rec, "captain")
	var by_rule := Captaincy.by_rule(GameState.my_list)
	_check(caps.size() == 1 and not by_rule.is_empty() and caps[0] == str(by_rule[0]["id"]),
			"A redraft career starts with a captain named by the rule (top Leadership)")
	_check(Captaincy.ids(rec).size() == Captaincy.MAX_LEADERS, "...and two vice-captains")
	# His cards can come up from week one.
	GameState.losing_streak = 3
	var ctx := ClubStories.context(GameState)
	var flat := StoryDeck.by_id(StoryDeck.all(), "captain_group_flat")
	var who := StoryEngine.eligible_subject(flat, ctx, StoryEngine.new_state(), GameState.story_week(), RandomNumberGenerator.new())
	_check(not who.is_empty() and str(who.get("id", "")) == str(caps[0]), "The captain's cards can fire in a redraft career")
	# The coach can change him; nobody puts him back.
	GameState.set_captaincy([])
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE")).is_empty(), "A captain you took off stays off: nothing is added for you")

	# Real lists keep the real captain.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var real_cap: Dictionary = {}
	for p in GameState.my_list:
		if Captaincy.role_of(GameState.captaincy_record("GEE"), str(p["id"])) == "captain":
			real_cap = p
	_check(not real_cap.is_empty() and Leadership.role_2026(real_cap) == "captain", "A real-lists career keeps the real captain")

	# A save from before this: no captaincy at all.
	GameState.save_career()
	var old := CareerSave.read(GameState.save_path)
	old.erase("captaincy")
	CareerSave.write(old, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career() and GameState.captaincy.is_empty(), "An old save with no captaincy loads cleanly, empty")
	_run_on(1)
	_check(not Captaincy.ids(GameState.captaincy_record("GEE"), "captain").is_empty(),
			"...and your club is named once, by the rule, at the first round after loading")
	GameState.set_captaincy([])
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE")).is_empty(), "...and a spot you then leave open stays open")

	# A P2-2-era save: a record that is empty and was never seeded.
	GameState.captaincy["GEE"] = {"slots": [], "since": 2027, "changes": {}, "passed": {}, "log": []}
	_run_on(1)
	_check(not Captaincy.ids(GameState.captaincy_record("GEE"), "captain").is_empty(),
			"An empty, never-seeded record from an earlier build is named once, by the rule")


# --- A result that names players (the time trial) --------------------------------

func _by_durability(a: Dictionary, b: Dictionary) -> bool:
	var da := int(a["attr"]["durability"])
	var db := int(b["attr"]["durability"])
	return da > db or (da == db and str(a["id"]) < str(b["id"]))


func _test_time_trial_names() -> void:
	# The token rules, on a list we control.
	var rows := []
	for n in ["Ava", "Ben", "Cal", "Dan"]:
		rows.append({"name": n})
	_check(StoryEngine.fill_ranked("{best3} / {worst2}", rows) == "Ava, Ben and Cal / Dan",
			"Best and worst never name the same player: %s" % StoryEngine.fill_ranked("{best3} / {worst2}", rows))
	_check(StoryEngine.fill_ranked("{best1}", rows) == "Ava" and StoryEngine.fill_ranked("{worst2}", rows) == "Dan and Cal",
			"One name stands alone; the worst come slowest first")
	_check(StoryEngine.fill_ranked("{best2}", []) == "nobody" and StoryEngine.fill_ranked("plain", rows) == "plain",
			"No list says nobody; a plain line is untouched")
	var club_ok := {"subject": {"kind": "club"}, "title": ["t"],
			"choices": [{"key": "a", "label": "A", "result": "Best: {best3}.", "effects": []},
				{"key": "b", "label": "B", "effects": []}]}
	_check(_bad(club_ok).is_empty(), "A club card's result may name players (%s)" % str(_bad(club_ok)))
	var in_text := club_ok.duplicate(true)
	in_text["text"] = ["Best: {best3}"]
	_check(not _bad(in_text).is_empty(), "Names belong in a result, not the card's text")
	var in_player := club_ok.duplicate(true)
	in_player["subject"] = {"kind": "player"}
	_check(not _bad(in_player).is_empty(), "A player card cannot name a ranked list")
	var typo := club_ok.duplicate(true)
	typo["choices"][0]["result"] = "Best: {bestx}."
	_check(not _bad(typo).is_empty(), "A misspelt name token is refused")

	# In play: Run it names the real fittest and slowest, by the rating the match
	# uses for running fitness, once each, from the senior list.
	var names_before: bool = GameState.show_real_names
	for real in [false, true]:
		_start()
		GameState.show_real_names = real
		var list: Array = GameState.my_list
		var injured: Dictionary = list[0]
		injured["injury_weeks"] = 3
		var avail := list.filter(func(q): return int(q.get("injury_weeks", 0)) <= 0)
		avail.sort_custom(_by_durability)
		var morale_before := ClubLife.morale(avail[10])
		var card := GameState.story_card("training_time_trial")
		var want := "Best over the two k: %s. Off the pace: %s." % [
				StoryEngine.name_list([avail[0], avail[1], avail[2]].map(func(q): return GameDB.player_display_name(q))),
				StoryEngine.name_list([avail[-1], avail[-2]].map(func(q): return GameDB.player_display_name(q)))]
		_check(not str(card["options"][0]["result"]).is_empty() and str(card["options"][0]["result"]).contains("{best3}"),
				"The card keeps the names until it is answered (%s)" % str(card["options"][0]["result"]))
		GameState.week_event = card
		var out := GameState.resolve_week_event(0)
		_check(out == "The time trial's done. " + want, "Run it names who is fit (real names %s): %s" % [str(real), out])
		_check(not out.contains("{") and not out.contains(GameDB.player_display_name(injured)),
				"No braces left, and the injured player did not run (%s)" % out)
		var named := []
		for q in list:
			if out.contains(GameDB.player_display_name(q)):
				named.append(str(q["id"]))
		_check(named.size() == 5, "Exactly five distinct players are named (%d)" % named.size())
		var run := _choice("training_time_trial", "run")
		_check(ClubLife.morale(avail[10]) == clampi(morale_before - 3, 5, 100)
				and int(_effect(run, "xp")["d"]) == 5 and str(_effect(run, "xp")["who"]) == "all"
				and int(_effect(run, "morale")["d"]) == -3 and str(_effect(run, "morale")["who"]) == "all",
				"The effects are unchanged: morale -3 and 5 development for everyone")
	GameState.show_real_names = names_before
