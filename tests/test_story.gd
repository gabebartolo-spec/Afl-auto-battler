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
	_t("_test_deck_is_valid")
	_t("_test_validator_catches")
	_t("_test_folded_sizes")
	_t("_test_hints_in_words")
	_t("_test_choice_stakes_are_stated")
	_t("_test_every_option_has_a_cost")
	_t("_test_silent_defaults_announced")
	_t("_test_every_line_has_a_size")
	_t("_test_line_numbers_match_effects")
	_t("_test_trust_rules")
	_t("_test_engine_rules")
	_t("_test_arcs")
	_t("_test_finals_and_big_weeks")
	_t("_test_private_cards")
	_t("_test_papers_cards_are_football")
	_t("_test_role_trial")
	_t("_test_trial_injury")
	_t("_test_trial_result")
	_t("_test_role_card_shape")
	_t("_test_role_trial_save")
	_t("_test_ten_seasons")
	_t("_test_trust_in_play")
	_t("_test_stories_never_move_the_dice")
	_t("_test_save_round_trip")
	_t("_test_old_save")
	_t("_test_leadership")
	_t("_test_captaincy")
	_t("_test_culture")
	_t("_test_culture_news")
	_t("_test_culture_reasons_read_cleanly")
	_t("_test_culture_settles")
	_t("_test_culture_signs_match_words")
	_t("_test_culture_headline")
	_t("_test_culture_order_and_tails")
	_t("_test_culture_sentences")
	_t("_test_culture_runs_once")
	_t("_test_culture_copy_is_true")
	_t("_test_culture_effects")
	_t("_test_culture_effects_fixture")
	_t("_test_captain_cards")
	_t("_test_group_words_are_sentence_case")
	_t("_test_captain_cards_in_play")
	_t("_test_captain_from_the_start")
	_t("_test_time_trial_names")
	_t("_test_vacancy_is_filled")
	var finals_cards = load("res://tests/test_finals_cards.gd").new()
	finals_cards.run(self)
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	GameState.stories_on = true
	print(Ran.line("Story", self, [finals_cards]))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


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
			# A scripted result card has one button and no effects to describe.
			if (d == "" and not bool(t.get("scripted", false))) or numbers.search(d) != null or d.contains("{"):
				bad.append("%s/%s: %s" % [t["id"], o["key"], d])
		if str(card["title"]).contains("{") or str(card["text"]).contains("{"):
			bad.append("%s: %s" % [t["id"], card["title"]])
	_check(bad.is_empty(), "Every choice says what it does, in words, fully filled in: %s" % " | ".join(PackedStringArray(bad)))
	var heavy := GameState.story_card("training_extra_session")
	_check(str(heavy["options"][0]["detail"]).to_lower().contains("development") and str(heavy["options"][0]["detail"]).contains("Heavy legs"),
			"The heavy session's hint names both sides of it (%s)" % heavy["options"][0]["detail"])


## Copy truth for the lines under a choice: every mechanical effect of every
## choice appears in them, a gain on the Gain line and a cost on the Cost line,
## gains first; and no line names an effect the choice lacks. What each effect
## is worth to the coach is read straight off the effects here, apart from the
## engine's own wording, so the lines cannot drift from what the choice does.
const GAIN_WORDS := {
	"morale": "(?i)morale", "xp": "(?i)development", "board": "(?i)board confidence", "trust": "trusts you ([0-9]+% )?more",
	"fresh": "legs", "promise_win": "Win and", "extend_early": "signs on", "captaincy_swap": "takes the armband",
	"rush_back": "cleared to play", "role_trial": "plays as a",
}
const COST_WORDS := {
	"morale": "(?i)morale", "board": "(?i)board confidence", "trust": "trusts you ([0-9]+% )?less",
	"rest": "misses", "heavy_legs": "Heavy legs", "sore": "chance he is injured", "expects_game": "expects a game",
	"start_backing": "expects to be picked", "back_kid": "is promised", "promise_win": "Lose or draw and", "extend_early": "Locked in", "captaincy_swap": "mid-season",
	"rush_back": "hurt again", "slow_start": "slowly", "loss_sting": "also falls", "role_trial": "away from his usual spot",
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
		if op == "rush_back" or op == "role_trial":
			gains.append(op)
			costs.append(op)
			continue
		# A promise lifts him now (a run thrills him; an early deal pleases him) and
		# names what breaking it costs: his morale and his trust.
		if op in ["start_backing", "back_kid", "extend_early"] and not gains.has("morale"):
			gains.append("morale")
		if op in ["expects_game", "start_backing", "back_kid"]:
			for k in ["morale", "trust"]:
				if not costs.has(k):
					costs.append(k)
		if op == "slow_start":
			costs.append(op)
			continue
		if op == "loss_sting":
			costs.append_array([op, "morale"])
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
	var good := StoryEngine.stakes_lines(heavy, {})
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
	var nouns := {"morale": "orale", "xp": "evelopment", "board": "Board confidence", "trust": "trusts you", "rest": "game",
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
				f["trial_word"] = "midfielder"
				f["trial_home"] = "defender"
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
		for kw in ["breaks down", "heavy legs", "expects a game", "promise breaks", "lose or draw"]:
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
			and not bool(StoryDeck.by_id(StoryDeck.all(), "media_in_the_papers").get("private", false)),
			"The papers card is about his football, so it is not private")
	var ctx := ClubStories.context(GameState)
	(ctx["club"] as Dictionary)["losing_run"] = 5  # so a card that waits on a losing run can be reached
	var leaks := []
	var reachable := 0
	for t in private:
		# Fit the club to the card's own timing (a round window), so only the name rule is left.
		for k in (t.get("when", {}) as Dictionary):
			var wk := str(k)
			if wk.ends_with("_min"):
				(ctx["club"] as Dictionary)[wk.trim_suffix("_min")] = float(t["when"][k])
			elif wk.ends_with("_max"):
				(ctx["club"] as Dictionary)[wk.trim_suffix("_max")] = float(t["when"][k])
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
	_check(str(Trust.reasons(GameState.relations, key)[0]["why"]) == "You kept him in when the papers wanted him out",
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


# --- The papers arc as football (2026-10-13) --------------------------------------

## A starter with a second position he is not already picked in, fit.
func _trial_candidate() -> Dictionary:
	for f in ClubStories.player_facts(GameState):
		if bool(f["starting"]) and bool(f["fit"]) and bool(f["has_role2"]):
			return GameState.list_player(str(f["id"]))
	return {}


func _test_papers_cards_are_football() -> void:
	_start()
	GameState.show_real_names = true
	_run_on(4)
	var ctx := ClubStories.context(GameState)
	var real_named := 0
	for f in ctx["players"]:
		if bool(f["real_named"]):
			real_named += 1
	_check(real_named > 10, "The test list is shown under real names (%d)" % real_named)
	for id in ["media_in_the_papers", "media_papers_again", "media_papers_fronts_group"]:
		var t := StoryDeck.by_id(StoryDeck.all(), id)
		_check(not bool(t.get("private", false)), "%s is not private" % id)
		var st := StoryEngine.new_state()
		var needs: Dictionary = t.get("needs", {})
		if not needs.is_empty():
			for f in ctx["players"]:
				var pid := str(f["id"])
				st["flags"][pid] = {str(needs["flag"]): 100 - int(needs.get("after", 1))}
				st["arcs"][str(t["arc"]) + "|" + pid] = {"state": "open", "until": 200}
		var ctx_id := ctx
		if id == "media_papers_again":
			# The form rule has its own test; here only that real names are not shut out.
			ctx_id = ctx.duplicate(true)
			for f in ctx_id["players"]:
				f["form_low"] = true
		var who := StoryEngine.eligible_subject(t, ctx_id, st, 100, RandomNumberGenerator.new())
		_check(not who.is_empty() and bool(who["real_named"]),
				"%s can come up for a player shown under his real name" % id)
		if id == "media_in_the_papers" and not who.is_empty():
			# The one asked about has the poorest recent form among the fit players picked.
			var lowest := 9999
			for f in ctx["players"]:
				if bool(f["fit"]) and bool(f["selected"]) and int(f["form_games"]) >= 3:
					lowest = mini(lowest, int(f["form"]))
			_check(int(who["form"]) == lowest and int(who["form_games"]) >= 3,
					"The papers go after the poorest recent form (%d, lowest %d)" % [int(who["form"]), lowest])
		if id == "media_papers_again" and not who.is_empty():
			_check(bool(who["has_role2"]) and bool(who["starting"]),
					"The role card only picks a starter who has a second position")
	# No second position, no role card.
	var none := ClubStories.player_fact(GameState, {"id": "x", "role": "MID", "role2": "", "overall": 60}, true, {}, 1, 0)
	_check(not bool(none["has_role2"]), "A player with no second position is not offered the role card")
	# The cards' own effects.
	# Each effect follows from the story (director, 2026-10-14): he asked about the move,
	# so trying it earns his trust and refusing costs it; nothing about the board or his mood.
	# The dropped card: no board in it either (director, 2026-10-14); resting him costs trust and morale,
	# keeping him in earns trust, silence costs trust.
	var rest := _choice("media_in_the_papers", "suspend")
	var keep := _choice("media_in_the_papers", "back")
	var drop := StoryDeck.by_id(StoryDeck.all(), "media_in_the_papers")
	_check(_effect(rest, "board").is_empty() and _effect(keep, "board").is_empty()
			and int(_effect(rest, "trust").get("d", 0)) < 0 and int(_effect(rest, "morale").get("d", 0)) < 0
			and int(_effect(keep, "trust").get("d", 0)) > 0 and not str(drop["text"][0]).contains("board"),
			"The dropped card has no board effect or board line: resting him costs trust and morale, keeping him earns trust")
	_check(int((drop["unanswered"] as Dictionary).get("trust", 0)) < 0 and int((drop["unanswered"] as Dictionary).get("board", 0)) == 0,
			"Silence on the dropped card costs his trust, not the board's confidence")
	_check(_effect(keep, "flag").get("name", "") == "backed_in_papers", "Keeping him in still opens the follow-up")
	var down := _choice("media_papers_again", "down")
	var stand := _choice("media_papers_again", "stand")
	_check(int(_effect(down, "role_trial").get("weeks", 0)) == 3 and int(_effect(down, "trust").get("d", 0)) > 0
			and _effect(down, "morale").is_empty() and _effect(down, "board").is_empty(),
			"Trying him in the role he asked about: a three-game trial and more trust, no morale or board effect")
	_check(int(_effect(stand, "trust").get("d", 0)) < 0 and _effect(stand, "board").is_empty() and _effect(stand, "morale").is_empty(),
			"Leaving him where he is costs his trust and nothing else")
	var again := StoryDeck.by_id(StoryDeck.all(), "media_papers_again")
	_check(int((again["unanswered"] as Dictionary).get("trust", 0)) < 0 and int((again["unanswered"] as Dictionary).get("board", 0)) == 0,
			"Saying nothing on the role card costs his trust, not the board's confidence")
	var front := _choice("media_papers_fronts_group", "front")
	var priv := _choice("media_papers_fronts_group", "private")
	_check(_effect(front, "board").is_empty() and _effect(priv, "board").is_empty()
			and int(_effect(front, "trust").get("d", 0)) > 0 and int(_effect(priv, "trust").get("d", 0)) < 0
			and _effect(priv, "morale").is_empty() and not _effect(front, "delegate").is_empty(),
			"Fronting the group is a risk on the room (it depends on whether the group listens to him); keeping it private gains nothing and costs his trust")
	var dg := _effect(front, "delegate")
	_check(int(((dg["held"] as Array)[0] as Dictionary)["d"]) > 0 and int(((dg["failed"] as Array)[0] as Dictionary)["d"]) < 0,
			"...the room's morale rises if the group listens and falls if it does not")
	GameState.show_real_names = false


func _line_in(sel: Dictionary, id: String) -> String:
	for k in ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH"]:
		if (sel.get(k, []) as Array).has(id):
			return k
	return ""


func _role_on_ground(id: String) -> String:
	for g in GameState.my_squad().ground:
		if str(g["id"]) == id:
			return str(g["role"])
	return ""


## The trial: three games he plays in the new position, then home (director,
## 2026-10-13). Only moving HIM by hand ends it early; other swaps do not.
func _test_role_trial() -> void:
	_start()
	var p := _trial_candidate()
	_check(not p.is_empty(), "A starter with a second position exists on the test list")
	if p.is_empty():
		return
	var id := str(p["id"])
	var role2 := ClubStories.trial_role(p)
	var home_line := _line_in(GameState.current_side(), id)
	# Auto-pick: he plays his second position for three games, then goes back.
	var said := GameState.start_role_trial(p, 3)
	_check(said.contains("plays as a") and said.contains("three games") and said.contains("then goes back"),
			"The trial says where and for how long: %s" % said)
	_check(GameState.my_selection().is_empty() and (GameState.season.selections[GameState.my_club] as Dictionary).has("TRIAL"),
			"Under the auto-pick the trial rides with the selection, and the side is still the auto-pick")
	_check(_role_on_ground(id) == role2, "The auto-pick plays him in %s" % role2)
	var left: Array = []
	for r in range(3):
		left.append(int(GameState.role_trial.get("left", -1)))
		GameState.advance()
	_check(left == [3, 2, 1] and GameState.role_trial.is_empty(),
			"The trial runs exactly three games, then it is over (%s)" % str(left))
	_check(not (GameState.season.selections[GameState.my_club] as Dictionary).has("TRIAL"),
			"...and nothing is left on the selection")
	_check(_line_in(GameState.current_side(), id) == home_line, "...and the auto-pick has him back in %s" % home_line)
	# Moving HIM by hand ends it, auto case: he stays where your side puts him.
	_start()
	p = _trial_candidate()
	id = str(p["id"])
	role2 = ClubStories.trial_role(p)
	GameState.start_role_trial(p, 3)
	var side: Dictionary = GameState.current_side()
	var line := _line_in(side, id)
	_check(line == role2 or (line == "WING" and role2 == "MID"), "The team sheet shows him in %s (%s)" % [role2, line])
	var moved_him := _bench_him(side, id)
	GameState.set_selection(moved_him)
	_check(GameState.role_trial.is_empty(), "Moving him by hand ends the trial")
	_check(_line_in(GameState.my_selection(), id) == "BENCH", "...and he stays where your side puts him")
	# Swapping two OTHER players keeps the trial on, auto case (qa T9); at the end he is home.
	_start()
	p = _trial_candidate()
	id = str(p["id"])
	role2 = ClubStories.trial_role(p)
	home_line = _line_in(GameState.current_side(), id)
	GameState.start_role_trial(p, 3)
	side = GameState.current_side()
	var bench: Array = side["BENCH"]
	var other_line := "FWD" if _line_in(side, id) != "FWD" else "DEF"
	var a := str((side[other_line] as Array)[0])
	var b := str(bench[0])
	(side[other_line] as Array)[0] = b
	bench[0] = a
	GameState.set_selection(side)
	_check(not GameState.role_trial.is_empty() and int(GameState.role_trial["left"]) == 3,
			"Swapping two other players does not end the trial (auto)")
	for r in range(3):
		GameState.advance()
	_check(GameState.role_trial.is_empty() and _line_in(GameState.my_selection(), id) == home_line,
			"...and after three games he is back in %s, not stuck in the new role (%s)" % [home_line, _line_in(GameState.my_selection(), id)])
	# Named side: other swaps keep it on and he goes home after three (qa T10).
	_start()
	GameState.set_selection(GameState.current_side())
	p = _trial_candidate()
	id = str(p["id"])
	role2 = ClubStories.trial_role(p)
	home_line = _line_in(GameState.my_selection(), id)
	GameState.start_role_trial(p, 3)
	var moved := _line_in(GameState.my_selection(), id)
	_check(moved == role2 or (moved == "WING" and role2 == "MID"), "A named side moves him into %s (%s)" % [role2, moved])
	_check(_role_on_ground(id) == role2, "...and the match side has him there")
	side = GameState.my_selection()
	other_line = "FWD" if _line_in(side, id) != "FWD" else "DEF"
	a = str((side[other_line] as Array)[0])
	b = str((side["BENCH"] as Array)[0])
	(side[other_line] as Array)[0] = b
	(side["BENCH"] as Array)[0] = a
	GameState.set_selection(side)
	_check(not GameState.role_trial.is_empty(), "Swapping other players does not end it (named)")
	for r in range(3):
		GameState.advance()
	_check(GameState.role_trial.is_empty() and _line_in(GameState.my_selection(), id) == home_line,
			"Named: three games later he is home in %s (%s)" % [home_line, _line_in(GameState.my_selection(), id)])
	# Named side, you move him yourself: it ends and your side stays as you made it.
	_start()
	GameState.set_selection(GameState.current_side())
	p = _trial_candidate()
	id = str(p["id"])
	GameState.start_role_trial(p, 3)
	GameState.set_selection(_bench_him(GameState.my_selection(), id))
	_check(GameState.role_trial.is_empty(), "Moving him yourself ends the trial (named)")
	var mine_json := JSON.stringify(GameState.my_selection(), "", true)
	GameState.advance()
	GameState.advance()
	GameState.advance()
	_check(JSON.stringify(GameState.my_selection(), "", true) == mine_json, "Your side is never rewritten after you picked it")
	# A player with no second position gets no trial and no change.
	_start()
	var plain: Dictionary = GameState.my_list[0].duplicate()
	plain["role2"] = ""
	plain["learned"] = []
	plain["unicorn"] = false
	if ClubStories.trial_role(plain) == "":
		_check(GameState.start_role_trial(plain, 3) == "" and GameState.role_trial.is_empty(),
				"No second position, no trial")


## Take him off the ground and put him on the bench of a side.
func _bench_him(side: Dictionary, id: String) -> Dictionary:
	var s := side.duplicate(true)
	for k in ["RUCK", "MID", "WING", "DEF", "FWD"]:
		s[k] = (s.get(k, []) as Array).filter(func(x): return str(x) != id)
	(s["BENCH"] as Array).append(id)
	return s


## Games he misses injured do not count (qa T4).
func _test_trial_injury() -> void:
	_start()
	var p := _trial_candidate()
	var id := str(p["id"])
	GameState.start_role_trial(p, 3)
	GameState.advance()
	_check(int(GameState.role_trial["left"]) == 2, "One game played, two left")
	p["injury_weeks"] = 2
	GameState.advance()
	GameState.advance()
	var inj := GameState.list_player(id)
	_check(not GameState.role_trial.is_empty() and int(GameState.role_trial["left"]) == 2,
			"Two games missed injured do not count (left %s)" % str(GameState.role_trial.get("left", "none")))
	_check((GameState.role_trial.get("ratings", []) as Array).size() == 1, "...and only the game he played has a rating")
	inj["injury_weeks"] = 0
	GameState.advance()
	GameState.advance()
	_check(GameState.role_trial.is_empty(), "Back fit, two more games end it")


## The result: his average against the league's for the position, then a card
## (director, 2026-10-13); a pass starts his training with three weeks done.
func _test_trial_result() -> void:
	for pass_it in [true, false]:
		_start()
		_run_on(3)
		var p := _trial_candidate()
		var id := str(p["id"])
		var role2 := ClubStories.trial_role(p)
		GameState.start_role_trial(p, 3)
		GameState.advance()
		GameState.advance()
		GameState.pos_ratings[role2] = [0, 1] if pass_it else [9999, 1]
		GameState.advance()
		_check(not GameState.week_events.is_empty()
				and str(GameState.week_events[0]["tid"]) == ("media_trial_worked" if pass_it else "media_trial_not_yet"),
				"The result comes as the first card of the next week (%s)" % (str(GameState.week_events[0]["tid"]) if not GameState.week_events.is_empty() else "none"))
		if GameState.week_events.is_empty():
			continue
		var card: Dictionary = GameState.week_events[0]
		var f: Dictionary = card["facts"]
		_check(GameState.trial_result.is_empty(), "The result is dealt once")
		_check((int(f["trial_avg"]) >= int(f["trial_par"])) == pass_it, "Passing means at or above the position average")
		var job := GameState.learn_job_for(p, role2)
		var player := GameState.list_player(id)
		var started := GameState.project_job(player) == job and job != ""
		if pass_it:
			_check(started == (job != ""), "A pass starts training when the position has a job")
			if started:
				_check(int(player["project"]["weeks"]) == 3 and str(player["train_plan"]) == "learn_" + job,
						"...three weeks banked, in the learning project")
		else:
			_check(GameState.project_job(player) == "", "A fail starts no training")
		var t := str(card["text"])
		_check(t.contains("averaged a Player rating of %d as a %s" % [int(f["trial_avg"]), str(f["trial_word"])])
				and t.contains("who started as a %s this year average a Player rating of %d" % [str(f["trial_word"]), int(f["trial_par"])]),
				"The card shows both numbers in words: %s" % t)
		_check(t.contains("three weeks already banked") == started, "...and says whether training starts: %s" % t)
	# The league's position averages fill from every club's starters.
	_start()
	_run_on(3)
	for role in ["MID", "DEF", "FWD", "RUCK"]:
		_check(GameState.position_average(role) > 20, "The league has an average rating for %s (%d)" % [role, GameState.position_average(role)])


## Card 2 shape (director, 2026-10-13): a fit starter with a second position
## whose form is in the bottom half of the side; the position is named on the
## card and on the button. Never offered for a player already picked there.
func _test_role_card_shape() -> void:
	_start()
	_run_on(5)
	_t("_test_front_group_words")
	# The dropped card shows what his form has been and what a starter in his position averages.
	var pc := GameState.story_card("media_in_the_papers", _trial_candidate())
	var pf: Dictionary = pc["facts"]
	_check(int(pf["role_avg"]) > 0 and str(pc["text"]).contains("averaged a Player rating of %d over his last three games" % int(pf["form"]))
			and str(pc["text"]).contains("this year average a Player rating of %d" % int(pf["role_avg"])),
			"The dropped card states his form and the position average: %s" % str(pc["text"]))
	var ctx := ClubStories.context(GameState)
	var t := StoryDeck.by_id(StoryDeck.all(), "media_papers_again")
	var starters := []
	for f in ctx["players"]:
		if bool(f["starting"]) and int(f["form_games"]) >= 3:
			starters.append(f)
	var low := 0
	for f in starters:
		if bool(f["form_low"]):
			low += 1
	_check(low >= starters.size() / 2 - 1 and low <= starters.size() / 2 + 1,
			"About half the starters are in the bottom half of the form (%d of %d)" % [low, starters.size()])
	var who := StoryEngine.eligible_subject(t, ctx, StoryEngine.new_state(), 100, RandomNumberGenerator.new())
	_check(who.is_empty() or (bool(who["form_low"]) and bool(who["has_role2"]) and bool(who["starting"])),
			"The role card only comes up for a role-two starter in the bottom half of the form")
	var high := ctx.duplicate(true)
	for f in high["players"]:
		f["form_low"] = false
	_check(StoryEngine.eligible_subject(t, high, StoryEngine.new_state(), 100, RandomNumberGenerator.new()).is_empty(),
			"Nobody in the bottom half: the card does not appear")
	# Named on the card and the button; he is named too.
	var p := _trial_candidate()
	var word := CoachPathway.position_word({"pos": ClubStories.trial_role(p)})
	var card := GameState.story_card("media_papers_again", p)
	_check(str(card["text"]).contains("playing as a " + word) and str(card["text"]).contains(GameDB.player_display_name(p).split(" ")[0] + " wants to know"),
			"The body names the position and who wants to know: %s" % str(card["text"]))
	_check(not str(card["text"]).contains("He wants to know"), "...not 'He'")
	_check(str((card["options"] as Array)[1]["label"]) == "Try him as a " + word, "The button reads 'Try him as a %s'" % word)
	var detail := str((card["options"] as Array)[1]["detail"])
	_check(detail.contains("plays as a " + word) and detail.contains("goes back to being a "), "...and so does its Gain line, naming where he goes back to: %s" % detail)
	# Already picked in his second position (qa T12): no card, no trial.
	_start()
	GameState.set_selection(GameState.current_side())
	p = _trial_candidate()
	var id := str(p["id"])
	var role2 := ClubStories.trial_role(p)
	var sel := GameState.my_selection()
	GameState._move_in_sel(sel, id, role2)
	GameState.set_selection(sel)
	var fx := {}
	for f in ClubStories.player_facts(GameState):
		if str(f["id"]) == id:
			fx = f
	_check(not fx.is_empty() and not bool(fx["has_role2"]), "A player already picked in his second position is not offered the card")
	_check(GameState.start_role_trial(GameState.list_player(id), 3) == "", "...and a trial there does nothing")
	# Benched between the card and the answer (qa T14): nothing changes, no cost.
	_start()
	GameState.set_selection(GameState.current_side())
	p = _trial_candidate()
	id = str(p["id"])
	var e := GameState.story_card("media_papers_again", p)
	GameState.week_events = [e]
	GameState.set_selection(_bench_him(GameState.my_selection(), id))
	var board0 := GameState.board_confidence()
	var morale0 := ClubLife.morale(GameState.list_player(id))
	var key := Trust.player_key(id)
	var trust0 := Trust.value(GameState.relations, key)
	var out := GameState.resolve_card(0, 1)
	_check(GameState.role_trial.is_empty() and out.contains("nothing changes") and GameState.board_confidence() == board0
			and ClubLife.morale(GameState.list_player(id)) == morale0 and Trust.value(GameState.relations, key) == trust0,
			"Benched before the answer: no trial and no trust, morale or board cost (%s)" % out)
	# Saying nothing costs his trust (not the board), and the card says so.
	_start()
	p = _trial_candidate()
	id = str(p["id"])
	var quiet := GameState.story_card("media_papers_again", p)
	_check(str((quiet["unanswered"] as Dictionary)["hint"]).contains("trusts you 2% less"), "The silence hint names the trust cost: %s" % str(quiet["unanswered"]["hint"]))
	GameState.week_events = [quiet]
	var b2 := GameState.board_confidence()
	var t2 := Trust.value(GameState.relations, Trust.player_key(id))
	GameState._settle_week_event()
	_check(Trust.value(GameState.relations, Trust.player_key(id)) < t2 and GameState.board_confidence() == b2,
			"Unanswered, the role card costs his trust and leaves the board alone")
	# He leaves the list mid-trial (qa T5): the trial clears, no stale note.
	_start()
	p = _trial_candidate()
	id = str(p["id"])
	GameState.start_role_trial(p, 3)
	GameState.my_list = GameState.my_list.filter(func(q): return str(q["id"]) != id)
	GameState.advance()
	_check(GameState.role_trial.is_empty() and not (GameState.season.selections[GameState.my_club] as Dictionary).has("TRIAL"),
			"A player who leaves the list mid-trial clears the trial and its note")


## Card 3's two sizes of trust read differently (qa 11).
func _test_front_group_words() -> void:
	var card := GameState.story_card("media_papers_fronts_group", GameState.my_list[0] if GameState.season != null else {})
	if card.is_empty():
		return
	var d0 := str((card["options"] as Array)[0]["detail"])
	var d1 := str((card["options"] as Array)[1]["detail"])
	_check(d0.contains("trusts you 4% more") and d0.contains("morale up 3%") and d0.contains("morale down 3%") and d0.contains("the group") and d1.contains("2% less"),
			"Card 3's trust lines differ in size: '%s' / '%s'" % [d0, d1])


## Save in the middle of a trial and reload: the same trial, the same games.
func _test_role_trial_save() -> void:
	for named in [false, true]:
		GameState.reset()
		GameState.career_seed = SUITE_SEED
		GameState.replay_seed = SUITE_SEED
		GameState.start_season("GEE", GameDB.club_list("GEE"))
		_run_on(2)
		if named:
			GameState.set_selection(GameState.current_side())
		var p := _trial_candidate()
		if p.is_empty():
			_check(false, "A trial candidate exists for the save test")
			continue
		GameState.start_role_trial(p, 3)
		GameState.advance()
		_check(GameState.save_career(), "Mid-trial save (%s)" % ("named" if named else "auto"))
		var trial_before := JSON.stringify(GameState.role_trial, "", true)
		var sel_before := JSON.stringify(GameState.season.selections[GameState.my_club], "", true)
		var straight := _trial_run(4, str(p["id"]))
		_check(GameState.load_career(), "Mid-trial load")
		_check(JSON.stringify(GameState.role_trial, "", true) == trial_before and GameState.role_trial.size() > 0,
				"The trial survives a reload (%s)" % trial_before)
		_check(JSON.stringify(GameState.season.selections[GameState.my_club], "", true) == sel_before,
				"...and so does the side it wrote")
		var reloaded := _trial_run(4, str(p["id"]))
		_check(straight == reloaded, "Reload and carry on equals playing straight through\n%s\n%s" % [
				",".join(straight), ",".join(reloaded)])
		_check(GameState.role_trial.is_empty(), "...and the trial has ended")
	# An older save has no trial key at all.
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("role_trial")
	state.erase("trial_result")
	state.erase("pos_ratings")
	CareerSave.write(state, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career() and GameState.role_trial.is_empty(), "A save without the trial key loads with none")


func _trial_run(rounds: int, id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in range(rounds):
		out.append("%d/%s/%s" % [int(GameState.role_trial.get("left", 0)), _role_on_ground(id),
				str(GameState.last_match.get("score", []))])
		GameState.advance()
	return out


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
				"A spot the coach emptied stays empty, even when the man he had named has since left")

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
	_check(words.contains("Morale down 3% across the whole list.") and words.contains("Morale down 8% in the rest of the group.")
			and words.contains("Morale down 3% across the side."), "A group's mood line is in sentence case and names morale (%s)" % words)


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
	var repeats := PackedStringArray()
	for code in GameState.season.lists:
		var raw: Array = (rel2.get(Culture.key(str(code), "together"), {}) as Dictionary).get("log", [])
		if Culture.reasons(rel2, str(code), "together").size() != raw.size():
			repeats.append(str(code))
	_check(repeats.is_empty(), "Through a whole season no club's run is logged twice (%s)" % ", ".join(repeats))
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


## The screen's effect lines match what is applied, and each "what moves it" line matches the movers.
func _test_culture_copy_is_true() -> void:
	var files := []
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				files.append(d + "/" + f)
	var readers := []
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		if text.contains("Culture.value(") or text.contains("Culture.words("):
			readers.append(f.get_file())
	readers.sort()
	_check(readers == ["CultureSheet.gd", "GameState.gd"], "Only the screen and the news mover read a strand directly (%s)" % ", ".join(readers))
	var gs := FileAccess.get_file_as_string("res://scripts/state/GameState.gd")
	var at := gs.find("func _culture_move")
	var body := gs.substr(at, gs.find("
func ", at + 5) - at)
	_check(gs.count("Culture.value(") == body.count("Culture.value("), "In GameState a strand is read directly only to make news")
	# Play reads a strand in one place, by kind; each kind is applied where the screen says.
	var effect_readers := []
	for f in files:
		if FileAccess.get_file_as_string(f).contains("Culture.club_effect("):
			effect_readers.append(f.get_file())
	_check(effect_readers == ["GameState.gd"], "Only GameState applies a culture effect (%s)" % ", ".join(effect_readers))
	for kind in ["recovery", "sting", "resign_floor", "free_agent_score", "young_growth", "young_ceiling"]:
		_check(gs.contains("culture_effect(") and gs.contains("\"%s\")" % kind), "Culture's %s effect is applied" % kind)
	for st in ["standards", "together", "ambition"]:
		_check(Culture.moves_line(st) != "", "%s says what moves it" % st)
	var tg := Culture.moves_line("together")
	for n in [Culture.FINALS_PLACES, Culture.BOTTOM_PLACES, Culture.WINNING_RUNS[0], Culture.WINNING_RUNS[1], Culture.LOSING_RUNS[0], Culture.LOSING_RUNS[1]]:
		_check(tg.contains(str(n)), "Togetherness line names %d" % n)
	var top_step := Culture.season_steps(Culture.FINALS_PLACES, 18, false, 0.0, 0.0)
	var low_step := Culture.season_steps(18, 18, false, 0.0, 0.0)
	_check(top_step.size() == 1 and top_step[0]["d"] > 0 and low_step[0]["d"] < 0, "Finals raise Togetherness, a bottom finish lowers it")
	_check(Culture.run_step(0, 5)[1] > 0 and Culture.run_step(4, 0)[1] < 0, "Win runs raise it, loss runs lower it")
	var older := Culture.season_steps(9, 18, false, 1.0, 0.0)
	var younger := Culture.season_steps(9, 18, false, -1.0, 0.0)
	_check(older.size() == 1 and older[0]["strand"] == "ambition" and older[0]["d"] > 0 and younger[0]["d"] < 0, "An older best 22 pushes Ambition towards now, a younger one towards later")
	var tidy := Culture.season_steps(9, 18, false, 0.0, 2.5)
	var loose := Culture.season_steps(9, 18, false, 0.0, -2.5)
	_check(tidy[0]["strand"] == "standards" and tidy[0]["d"] > 0 and loose[0]["d"] < 0, "Discipline moves Standards the way the line says")
	_check(Culture.event_text("Togetherness", {"w": "Round 10", "why": "A run of four losses", "d": -3}) == "Round 10: a run of four losses. Togetherness fell.", "An event reads as one line")


func _test_culture_effects() -> void:
	var fx := Culture.effects()
	# The table names real bands, and a middle band does nothing.
	for kind in Culture.KIND_STRAND:
		var strand: String = Culture.KIND_STRAND[kind]
		var bands: Dictionary = (fx[kind] as Dictionary)[strand]
		var keys := []
		for b in Culture.BANDS[strand]:
			keys.append(b[1])
		for k in bands:
			_check(keys.has(k), "%s %s: %s is a real band" % [kind, strand, k])
		_check(not bands.has("mid"), "%s: the middle band does nothing" % kind)
		for k in bands:
			_check(absf(float(bands[k])) <= float(fx["little_max"][kind]) * 2.0, "%s %s is small" % [kind, k])
	# The screen's line says exactly the applied size and direction, and nothing
	# where nothing is applied.
	for strand in ["standards", "together", "ambition"]:
		for t in [-60, -20, 0, 20, 60]:
			var line := Culture.effect_line(strand, t)
			var band := Culture.band_key(strand, t)
			var x := 0.0
			for kind in Culture.KIND_STRAND:
				if Culture.KIND_STRAND[kind] == strand:
					x += absf(Culture.effect_of(kind, strand, band))
			if x == 0.0:
				_check(line == "", "%s %d: no line when it does nothing" % [strand, t])
			else:
				_check(line.contains("a little") or line.contains("keen") or line.contains("quicker"), "%s %d: size in words (%s)" % [strand, t, line])
				_check(not line.contains("%") and not line.contains("0."), "%s %d: no number on the line (%s)" % [strand, t, line])
				if strand != "ambition":
					var kind := "recovery" if strand == "standards" else "sting"
					var up := Culture.effect_of(kind, strand, band) > 0.0
					_check(line.contains("faster") or line.contains("better") if up else line.contains("slower") or line.contains("worse"),
							"%s %d: direction matches (%s)" % [strand, t, line])
	_check(Culture.effect_line("standards", 20) == "Players recover a little faster between games.", "Standards, good band")
	_check(Culture.effect_line("standards", -50) == "Players recover a little slower between games.", "Standards, slack band")
	_check(Culture.effect_line("together", -50) == "Players take a missed game a little worse.", "Togetherness, divided band")
	_check(Culture.effect_line("ambition", 20) == "Players are a little more willing to stay and to join.", "Ambition, pushing to win now")
	# Director, 2026-10-18: a patient club brings its young on; veterans' asks are not lower there.
	_check(Culture.effect_line("ambition", -20) == "Young players come on a little quicker here."
			and Culture.effect_line("ambition", -50) == "Young players come on a little quicker here.", "Ambition, patient and rebuilding")
	_check(Culture.effect_of("young_ceiling", "ambition", "patient") == 1.0 and Culture.effect_of("young_ceiling", "ambition", "rebuild") == 1.0
			and Culture.effect_of("young_ceiling", "ambition", "now") == 0.0, "Young players: a point more season ceiling at a patient club only")
	for band in ["patient", "rebuild"]:
		_check(Culture.effect_of("resign_floor", "ambition", band) == 0.0 and Culture.effect_of("free_agent_score", "ambition", band) == 0.0,
				"A %s club gets no re-sign or free-agent tilt" % band)
	_check(Culture.effect_of("young_growth", "ambition", "patient") == 0.03 and Culture.effect_of("young_growth", "ambition", "rebuild") == 0.05
			and Culture.effect_of("young_growth", "ambition", "now") == 0.0, "Young players: 3% patient, 5% rebuild, nothing winning now")
	# Who counts as young: under 22, or a draftee in his first season on a list.
	_check(Culture.young_for_growth({"age": 21.5}, 2028) and not Culture.young_for_growth({"age": 22.0}, 2028), "Under-22s, not 22-year-olds")
	_check(Culture.young_for_growth({"age": 24.0, "drafted_year": 2027}, 2028) and not Culture.young_for_growth({"age": 24.0, "drafted_year": 2026}, 2028),
			"A mature-age draftee in his first season counts; in his second he does not")
	# Standards: legs recover by the applied share.
	var a := {"id": "x1", "age": 25.0, "attr": {"durability": 70.0}, "workload": 60.0}
	var b := a.duplicate(true)
	Workload.advance_week({"AAA": [a]}, [], "w1", {"AAA": 1.0})
	Workload.advance_week({"AAA": [b]}, [], "w1", {"AAA": 1.05})
	_check(absf((float(a["workload"]) - float(b["workload"])) - Workload.recovery(a) * 0.05) < 0.001, "Standards 5% more recovery is exactly 5% of a week's recovery")
	# Togetherness: the sting of a missed game.
	var star := {"id": "s", "overall": 80, "morale": 70}
	var role := {"id": "r", "overall": 60, "morale": 70}
	ClubLife.morale_after_match([star, role], {}, false, {}, 0.2)
	_check(int(star["morale"]) == 70 - CoachEffects.softened(6, 0.2) and int(role["morale"]) == 70 - CoachEffects.softened(3, 0.2), "A very tight group softens the sting by a fifth")
	var star2 := {"id": "s", "overall": 80, "morale": 70}
	ClubLife.morale_after_match([star2], {}, false, {}, -0.2)
	_check(int(star2["morale"]) == 70 - CoachEffects.softened(6, -0.2) and int(star2["morale"]) < 64, "A divided group sharpens it")
	var played := {"id": "p", "overall": 60, "morale": 70}
	ClubLife.morale_after_match([played], {"p": true}, false, {}, 0.2)
	_check(int(played["morale"]) == 71, "Culture does not touch a player who played")
	# Ambition: the re-sign floor and the free agent's weighing.
	var pl: Dictionary = GameDB.all_players_sorted()[30]
	var low := Contracts.lowest(pl, 2)
	var cut := -int(round(float(low) * 0.02))
	_check(Contracts.respond(pl, low + cut, 2, 0, cut)["answer"] == "accept" and Contracts.respond(pl, low + cut - 5000, 2, 0, cut)["answer"] != "accept",
			"All in on winning now: he re-signs for 2% less, not 3%")
	var o1 := {"salary": 800000, "years": 2, "role": "ground", "finish_t": 0.5}
	var o2 := o1.duplicate()
	o2["amb"] = 0.10
	_check(absf(Contracts.offer_score(pl, o2) - Contracts.offer_score(pl, o1) - 0.10) < 0.0001, "The club's push adds exactly its size to a free agent's weighing")
	# The same rule for every club, and an old save is neutral.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.culture_effect("GEE", "recovery") == 0.0 and GameState.culture_effect("COL", "sting") == 0.0, "A club with nothing recorded is neutral")
	for code in ["GEE", "COL"]:
		Culture.change(GameState.relations, code, "standards", 6, "x", GameState.season_year, "Round 1")
		Culture.change(GameState.relations, code, "standards", 6, "x", GameState.season_year, "Round 2")
		Culture.change(GameState.relations, code, "standards", 6, "x", GameState.season_year, "Round 3")
	_check(GameState.culture_effect("GEE", "recovery") == 0.03 and GameState.culture_effect("COL", "recovery") == 0.03, "Every club gets the same size for the same band")
	# Re-signing: a rival pushing to win now keeps him cheaper by the same rule as yours.
	for code in ["GEE", "COL"]:
		GameState.relations[Culture.key(code, "ambition")] = {"t": 60, "log": []}
	var vet: Dictionary = GameState.season.lists["COL"][0]
	var cut2 := int(round(float(Contracts.lowest(vet, 2)) * 0.02))
	_check(GameState.culture_resign_discount("COL", vet, 2) == cut2 and GameState.culture_resign_discount("GEE", vet, 2) == cut2 and cut2 > 0,
			"All in: the same re-sign discount at your club and a rival's (%d)" % cut2)
	_check(FileAccess.get_file_as_string("res://scripts/state/GameState.gd").contains("Contracts.lowest(p, years) - culture_resign_discount(code, p, years)"),
			"Rivals re-sign at the culture floor too")
	# Development: a rebuilding club's young players earn 5% more XP on the same game; a veteran does not.
	GameState.relations[Culture.key("GEE", "ambition")] = {"t": -60, "log": []}
	var kid := {"id": "k", "age": 19.0, "overall": 60}
	var old := {"id": "o", "age": 29.0, "overall": 70}
	var on_kid: int = GameState._club_xp("GEE", kid, 40, {}, true)
	var on_old: int = GameState._club_xp("GEE", old, 40, {}, true)
	GameState.culture_effects_on = false
	var off_kid: int = GameState._club_xp("GEE", kid, 40, {}, true)
	var off_old: int = GameState._club_xp("GEE", old, 40, {}, true)
	GameState.culture_effects_on = true
	_check(on_kid == int(round(float(off_kid) * 1.05)) and on_kid > off_kid and on_old == off_old,
			"Rebuilding: a 19-year-old earns 5%% more from the same game, a 29-year-old the same (%d v %d; %d v %d)" % [on_kid, off_kid, on_old, off_old])
	# ...and has a point more room this season, inside POT; a veteran does not.
	var kid2 := {"id": "k2", "age": 19.0, "overall": 60, "potential": 80, "club": "GEE", "season_start_ov": 60}
	var capped := {"id": "k3", "age": 19.0, "overall": 62, "potential": 63, "club": "GEE", "season_start_ov": 60}
	var vet2 := {"id": "o2", "age": 29.0, "overall": 70, "potential": 80, "club": "GEE", "season_start_ov": 70}
	var c_on := [GameState.season_ceiling(kid2), GameState.season_ceiling(capped), GameState.season_ceiling(vet2)]
	GameState.culture_effects_on = false
	var c_off := [GameState.season_ceiling(kid2), GameState.season_ceiling(capped), GameState.season_ceiling(vet2)]
	GameState.culture_effects_on = true
	_check(int(c_on[0]) == int(c_off[0]) + 1 and int(c_on[1]) == maxi(int(c_off[1]), mini(int(c_off[1]) + 1, 63)) and int(c_on[2]) == int(c_off[2]),
			"Rebuilding: a 19-year-old's season ceiling is a point higher (inside POT), a 29-year-old's the same (%s v %s)" % [str(c_on), str(c_off)])
	GameState.culture_effects_on = false
	_check(GameState.culture_effect("GEE", "recovery") == 0.0, "Off means off")
	GameState.culture_effects_on = true


## The player-effect fixture: Melbourne's home-and-away season played twice,
## culture's effects on and off (legs, morale and XP read over the first
## FIXTURE_ROUNDS), with Melbourne's culture set to a
## well-run, very tight, rebuilding group. Everything else is the same seed. The
## sheet predicts fresher legs, players who take being left out better, and
## young players earning more development; each shows, and the size is printed.
const FIXTURE_ROUNDS := 8


func _culture_fixture_run(on: bool) -> Dictionary:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.culture_effects_on = on
	GameState.start_season("MEL", GameDB.club_list("MEL"))
	GameState.relations[Culture.key("MEL", "standards")] = {"t": 70, "log": []}
	GameState.relations[Culture.key("MEL", "together")] = {"t": 70, "log": []}
	GameState.relations[Culture.key("MEL", "ambition")] = {"t": -70, "log": []}
	var load_sum := 0.0
	var young_xp := 0
	var young_ids := {}
	for p in GameState.my_list:
		if Culture.young_for_growth(p, GameState.season_year):
			young_ids[str(p["id"])] = int(p.get("overall", 0))
	var morale := 0.0
	var r := 0
	while not GameState.season.is_regular_done() and r < 30:
		if GameState.week_event_pending():
			GameState.resolve_week_event(0)
		if GameState.media_conference_pending():
			GameState.skip_media_conference()
		GameState.advance()
		r += 1
		if r > FIXTURE_ROUNDS:
			continue
		var w := 0.0
		for p in GameState.my_list:
			w += Workload.value(p)
		load_sum += w / float(GameState.my_list.size())
		for row in GameState.last_training_report.get("rows", []):
			if young_ids.has(str(row["id"])):
				young_xp += int(row["xp"])
		if r == FIXTURE_ROUNDS:
			for p in GameState.my_list:
				morale += float(ClubLife.morale(p))
	var young_gain := 0.0
	var young_n := 0
	for p in GameState.my_list:
		if young_ids.has(str(p["id"])):
			young_gain += float(int(p.get("overall", 0)) - int(young_ids[str(p["id"])]))
			young_n += 1
	var bands := "%s/%s/%s" % [Culture.band_key("standards", Culture.value(GameState.relations, "MEL", "standards")),
			Culture.band_key("together", Culture.value(GameState.relations, "MEL", "together")),
			Culture.band_key("ambition", Culture.value(GameState.relations, "MEL", "ambition"))]
	GameState.culture_effects_on = true
	return {"load": load_sum / float(FIXTURE_ROUNDS), "morale": morale / float(GameState.my_list.size()),
			"young_xp": young_xp, "young": young_ids.size(), "bands": bands,
			"young_gain": young_gain / float(maxi(1, young_n)), "rounds": r}


func _test_culture_effects_fixture() -> void:
	var off := _culture_fixture_run(false)
	var on := _culture_fixture_run(true)
	print("Culture fixture (Melbourne, seed %d; first %d rounds): load %.2f v %.2f off | morale %.2f v %.2f off | young XP %d v %d off (%d young players) | bands %s | young OVR gain over the %d-round season %.2f v %.2f off" % [
			SUITE_SEED, FIXTURE_ROUNDS, float(on["load"]), float(off["load"]), float(on["morale"]), float(off["morale"]),
			int(on["young_xp"]), int(off["young_xp"]), int(on["young"]), str(on["bands"]), int(on["rounds"]),
			float(on["young_gain"]), float(off["young_gain"])])
	_check(str(on["bands"]) == "elite/very/rebuild" and str(off["bands"]) == "elite/very/rebuild",
			"The fixture's culture holds for the stretch (%s, %s)" % [on["bands"], off["bands"]])
	_check(float(on["load"]) < float(off["load"]), "A well-run group carries less load in its legs (%.2f v %.2f)" % [on["load"], off["load"]])
	_check(float(on["morale"]) > float(off["morale"]), "A very tight group ends the stretch happier (%.2f v %.2f)" % [on["morale"], off["morale"]])
	_check(float(on["young_xp"]) > float(off["young_xp"]) * 1.02,
			"A rebuilding club's young players earn more development (%d v %d)" % [on["young_xp"], off["young_xp"]])
	_check(float(on["young_gain"]) > float(off["young_gain"]),
			"...and end the home-and-away season rated higher (%.2f v %.2f OVR gained)" % [on["young_gain"], off["young_gain"]])


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


## A run of losses or wins is one row: logged the week it reaches its mark, by
## the club that played; an older save's repeats read as one.
func _test_culture_runs_once() -> void:
	var four := str(Culture.run_step(4, 0)[2])
	var five := str(Culture.run_step(0, 5)[2])
	var rel := {}
	for w in ["Round 24", "Wildcard Round", "Qualifying & Elimination Finals", "Semi Finals", "Grand Final"]:
		Culture.change(rel, "GEE", "together", -3, four, 2027, w)
	var told := Culture.reasons(rel, "GEE", "together")
	_check(told.size() == 1 and str(told[0]["w"]) == "Round 24", "A run logged again through the finals reads as one row (%d)" % told.size())
	_check(((rel[Culture.key("GEE", "together")] as Dictionary)["log"] as Array).size() == 5, "The save keeps what it holds")
	rel = {}
	Culture.change(rel, "GEE", "together", 3, five, 2027, "Round 9")
	Culture.change(rel, "GEE", "together", 3, five, 2027, "Round 10")
	Culture.change(rel, "GEE", "together", -3, four, 2027, "Round 3")
	Culture.change(rel, "GEE", "together", -3, four, 2027, "Round 15")
	Culture.change(rel, "GEE", "together", -3, four, 2027, "Semi Finals")
	Culture.change(rel, "GEE", "together", -3, four, 2028, "Round 4")
	var rows := PackedStringArray()
	for r in Culture.reasons(rel, "GEE", "together"):
		rows.append("%d %s %s" % [int(r["y"]), str(r["w"]), str(r["why"])])
	_check(" | ".join(rows) == "2028 Round 4 %s | 2027 Semi Finals %s | 2027 Round 15 %s | 2027 Round 3 %s | 2027 Round 9 %s" % [four, four, four, four, five],
			"A bye week's repeat goes; a second run later in the year, a run that ends in a final and next year's all stay (%s)" % " | ".join(rows))
	_check(Culture.event_text("Togetherness", {"w": "Semi Finals", "why": four, "d": -3}) == "Semi Finals: a run of four losses. Togetherness fell."
			and Culture.event_text("Togetherness", {"w": "Off-season", "why": "Played finals", "d": 3}) == "Played finals. Togetherness rose.",
			"A run that reaches its mark in a final names the final; an off-season reason names no week")
	_check(Culture.run_length(four) == 4 and Culture.run_length(str(Culture.run_step(8, 0)[2])) == 8 and Culture.run_length(five) == 5
			and Culture.run_length("Played finals") == 0, "Only a run's reason counts as a run")
	# In the game: the club that played reaches the mark once; a week it sits out adds nothing.
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rivals := []
	for code in GameState.season.lists:
		if str(code) != "GEE":
			rivals.append(str(code))
	var rounds := []
	for i in range(8):
		rounds.append([{"home": "GEE", "away": rivals[i], "score": [50, 80]}])
	var key := Culture.key("GEE", "together")
	var count := func() -> int:
		return ((GameState.relations.get(key, {}) as Dictionary).get("log", []) as Array).size()
	GameState.season.results = rounds.slice(0, 4)
	GameState.last_label = "Round 4"
	GameState._culture_week(rounds[3])
	var first: int = count.call()
	GameState.last_label = "Round 5"
	GameState._culture_week([{"home": rivals[9], "away": rivals[10], "score": [70, 60]}])
	GameState.last_label = "Round 6"
	GameState._culture_week([])
	var after_idle: int = count.call()
	var shown := Culture.reasons(GameState.relations, "GEE", "together")
	_check(first == 1 and after_idle == 1 and shown.size() == 1 and str(shown[0]["w"]) == "Round 4" and str(shown[0]["why"]) == four,
			"Four losses in a row is logged once, in its round; a bye and a week out add nothing (%d, %d)" % [first, after_idle])
	GameState.season.results = rounds.slice(0, 5)
	GameState.last_label = "Round 7"
	GameState._culture_week(rounds[4])
	_check(count.call() == 1, "A fifth loss in a row is the same run")
	GameState.season.results = rounds
	GameState.last_label = "Round 10"
	GameState._culture_week(rounds[7])
	shown = Culture.reasons(GameState.relations, "GEE", "together")
	_check(count.call() == 2 and shown.size() == 2 and str(shown[0]["why"]) == str(Culture.run_step(8, 0)[2]) and str(shown[0]["w"]) == "Round 10",
			"The run is told again only when it reaches eight")
	GameState.reset()


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


## Director 2026-10-12: when your captain retires or leaves, a vice-captain steps up by
## the same rule as the AI clubs, with a note to the coach; a spot the coach emptied
## himself stays empty.
func _vacancy_career() -> Dictionary:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rec := GameState.captaincy_record("GEE")
	var cap := {}
	for p in GameState.my_list:
		if Captaincy.role_of(rec, str(p["id"])) == "captain":
			cap = p
	return cap


func _remove_from_my_list(id: String) -> Dictionary:
	for i in range(GameState.my_list.size()):
		if str(GameState.my_list[i]["id"]) == id:
			var gone: Dictionary = GameState.my_list[i]
			GameState.my_list.remove_at(i)
			return gone
	return {}


func _test_vacancy_is_filled() -> void:
	# Retirement: he is gone from every list. The best-rated vice takes over, with a note.
	var cap := _vacancy_career()
	var rec := GameState.captaincy_record("GEE")
	var vices := Captaincy.ids(rec, "vice")
	var best_vice := ""
	for p in GameState.my_list:
		if vices.has(str(p["id"])) and (best_vice == "" or Leadership.of(p) > Leadership.of(GameState.list_player(best_vice))):
			best_vice = str(p["id"])
	_check(not cap.is_empty() and best_vice != "", "Geelong has a captain and a vice-captain to start from")
	var news_before := GameState.news.size()
	_remove_from_my_list(str(cap["id"]))
	_run_on(1)
	var now := GameState.captaincy_record("GEE")
	_check(Captaincy.ids(now, "captain") == [best_vice], "A retired captain is replaced by the best-rated vice-captain")
	var noted := false
	for i in range(GameState.news.size() - news_before):
		if str(GameState.news[i]["text"]).begins_with("Your captain has left the club, so"):
			noted = true
	_check(noted, "The coach gets a short note when the vice takes over")
	_check(not Captaincy.ids(now).has(str(cap["id"])), "The man who left is not in the record")

	# Traded away: he is on a rival's list, not ours. Same result.
	cap = _vacancy_career()
	rec = GameState.captaincy_record("GEE")
	var gone := _remove_from_my_list(str(cap["id"]))
	for code in GameState.season.lists:
		if str(code) != "GEE":
			gone["club"] = str(code)
			(GameState.season.lists[code] as Array).append(gone)
			break
	_run_on(1)
	now = GameState.captaincy_record("GEE")
	_check(Captaincy.ids(now, "captain").size() == 1 and Captaincy.ids(now, "captain")[0] != str(cap["id"]),
			"A captain traded away is replaced the same way")

	# No vice-captains left: the highest Leadership on the list takes over, by the rule.
	cap = _vacancy_career()
	GameState.set_captaincy([{"id": str(cap["id"]), "role": "captain"}])
	_remove_from_my_list(str(cap["id"]))
	_run_on(1)
	now = GameState.captaincy_record("GEE")
	var by_rule := Captaincy.by_rule(GameState.my_list)
	_check(Captaincy.ids(now, "captain") == [str(by_rule[0]["id"])], "With no vice-captain left, the rule picks (the highest Leadership)")

	# A spot the coach emptied himself stays empty, whoever leaves.
	cap = _vacancy_career()
	GameState.set_captaincy([])
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE")).is_empty(), "A spot the coach emptied stays empty")
	_remove_from_my_list(str(cap["id"]))
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE")).is_empty(), "...even after a player leaves: there was no captain to lose")

	# A coach who named only a captain gets only a captain back, not a full group of three.
	cap = _vacancy_career()
	GameState.set_captaincy([{"id": str(cap["id"]), "role": "captain"}])
	_remove_from_my_list(str(cap["id"]))
	_run_on(1)
	now = GameState.captaincy_record("GEE")
	_check(Captaincy.ids(now).size() == 1 and Captaincy.ids(now, "captain").size() == 1,
			"A captain named alone is replaced by one captain, with no vice-captains added")
	_check(Captaincy.ids(now, "vice").is_empty(), "...the vice-captain spots the coach left empty stay empty")
	var alone := JSON.stringify(GameState.captaincy)
	_check(GameState.save_career() and GameState.load_career() and JSON.stringify(GameState.captaincy) == alone,
			"...across a reload")
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE"), "vice").is_empty() and Captaincy.ids(GameState.captaincy_record("GEE")).size() == 1,
			"...and on the rounds that follow")
	var alone_note := false
	for item in GameState.news:
		if str(item["kind"]) == "captaincy" and str(item["text"]).begins_with("Your captain has left the club, so"):
			alone_note = true
	_check(alone_note, "...and the coach still gets the note")

	# A retired captain is told as retired; before Round 1 the note is dated to the off-season.
	cap = _vacancy_career()
	GameState.intake_summary = {"retired": [{"id": str(cap["id"])}]}
	_remove_from_my_list(str(cap["id"]))
	GameState._captaincy_refresh()
	var top: Dictionary = GameState.news[0]
	_check(str(top["kind"]) == "captaincy" and str(top["text"]).begins_with("Your captain has retired, so ")
			and str(top["text"]).contains(" takes over as captain. You can change it on the Captaincy page."),
			"A captain who retired is told so: 'has retired', not 'has left the club'")
	_check(str(top["when"]) == "Off-season", "A step-up before Round 1 is dated to the off-season, not Round 1")
	var log: Array = GameState.captaincy_record("GEE")["log"]
	_check(str(log[log.size() - 1]["w"]) == "Pre-season", "...and the captaincy page dates it Pre-season")
	GameState.intake_summary = {}

	# The save: the new captain and the empty spot both survive a reload.
	cap = _vacancy_career()
	_remove_from_my_list(str(cap["id"]))
	_run_on(1)
	var after_vacancy := JSON.stringify(GameState.captaincy)
	_check(GameState.save_career() and GameState.load_career() and JSON.stringify(GameState.captaincy) == after_vacancy,
			"A vice who stepped up survives a reload")
	_run_on(2)
	_check(Captaincy.ids(GameState.captaincy_record("GEE"), "captain").size() == 1, "...and nothing changes on the rounds that follow")


# --- Decision gates (director, 2026-10-18: every option states its upside and
# downside with the size and the odds; an option with no downside is a design fault) ---

## The 17 cards whose kind option used to win every number: every option now costs something.
const GATED := ["board_billboards", "contracts_rivals_circling", "contracts_kid_wants_clarity",
		"contracts_waited_manager_calls", "family_partner_job_offer", "family_newborn_no_sleep",
		"family_partner_graduation", "family_house_settlement", "health_veteran_rehab_mentor",
		"leadership_senior_runs_session", "captain_leaders_meeting", "captain_slump_start",
		"captain_slump_mid", "captain_contract_start", "media_in_the_papers", "media_papers_again",
		"members_cheer_squad"]
## Options that still gain without a cost (2026-10-18). Their costs are a later sheet; this
## list may only shrink: an entry that gains a cost must come off it, and no new one may join.
const GAIN_ONLY_LEFT := ["community_hospital_visit/go", "finals_club_greats/in", "health_finals_light_week/light",
		"captain_selection_word/talk", "captain_group_flat/dayoff", "captain_big_week/speak",
		"captain_holding_group/noticed", "captain_slump_good/noticed", "captain_contract_signed/good",
		"captain_succession_start/handover", "captain_succession_start/asks", "finals_last_season/quiet",
		"finals_second_chance/burn", "finals_captain_last_word/him", "gf_last_game/him", "gf_last_game/calm",
		"members_open_training/open", "members_open_training/closed", "finals_in/enjoy", "gf_milestone/banner",
		"gf_milestone/club", "rivals_spy_at_training/let", "rivals_mouthing_off/calm", "gf_the_opponent/us",
		"selection_talk_dropped/explain", "selection_talk_back/explain", "selection_talk_waiting/explain",
		"finals_first_final/minder", "finals_first_final/alone", "gf_debut_year/away", "training_extra_session/recover",
		"training_seniors_day_off/give", "training_time_trial/skip", "training_new_stoppage_setup/hold",
		"training_backed_kid_flying/earned", "finals_week_off/semi"]
const GAIN_ONLY_FLOOR := 36


func _test_every_option_has_a_cost() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var gain_only := []
	var gated_bad := []
	for t in StoryDeck.all():
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		# Every choice the card is written with, whether or not this week's facts show it.
		for o in t["choices"]:
			var lines := StoryEngine.stakes_lines(o.get("effects", []), card["facts"])
			var gain := false
			var cost := false
			for l in lines:
				gain = gain or l.begins_with(StoryEngine.GAIN_MARK)
				cost = cost or l.begins_with(StoryEngine.COST_MARK)
			var key := "%s/%s" % [t["id"], o["key"]]
			if gain and not cost:
				gain_only.append(key)
			if GATED.has(str(t["id"])) and not cost:
				gated_bad.append(key)
	_check(gated_bad.is_empty(), "Every option on the 17 gated cards states a cost: %s" % ", ".join(PackedStringArray(gated_bad)))
	var new_ones := gain_only.filter(func(k): return not GAIN_ONLY_LEFT.has(k))
	var gone := GAIN_ONLY_LEFT.filter(func(k): return not gain_only.has(k))
	_check(new_ones.is_empty(), "No option joins the gain-only list (a new card states a cost): %s" % ", ".join(PackedStringArray(new_ones)))
	_check(gone.is_empty() and GAIN_ONLY_LEFT.size() <= GAIN_ONLY_FLOOR,
			"The gain-only list only shrinks: take off the ones that now cost something (%s)" % ", ".join(PackedStringArray(gone)))
	# The check bites: a gain-only option on a gated card is caught.
	var bite := StoryEngine.stakes_lines([{"op": "morale", "d": 4}], {})
	_check(bite.size() == 1 and bite[0].begins_with(StoryEngine.GAIN_MARK), "A gain-only option shows no Cost line, so the check would catch it")


## A card that settles itself if the coach sims past it says so on its face, in
## the engine's one line, with that choice's cost.
func _test_silent_defaults_announced() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var bad := []
	var n := 0
	var want := 0
	for t in StoryDeck.all():
		if int(t.get("default", -1)) >= 0:
			want += 1
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		var line := StoryEngine.silence_line(card)
		var d := int(card.get("default", -1))
		if d >= 0 and d < (card["options"] as Array).size():
			n += 1
			var o: Dictionary = card["options"][d]
			var cost := ""
			for l in StoryEngine.stakes_lines(o["effects"], card["facts"]):
				if l.begins_with(StoryEngine.COST_MARK):
					cost = l.substr(StoryEngine.COST_MARK.length())
			if not line.begins_with("If you leave this, it goes as \"%s\"" % str(o["label"])) \
					or (cost != "" and not line.contains(cost.substr(1))) or line.contains("{"):
				bad.append("%s: %s" % [t["id"], line])
		elif (t.get("unanswered", {}) as Dictionary).is_empty() and line != "":
			bad.append("%s says something where leaving it changes nothing: %s" % [t["id"], line])
	# The international cards join the deck only with their switch on, so the count is the deck's own.
	_check(n == want and n >= 6 and bad.is_empty(), "Every card with a silent default names it and its cost (%d of %d cards): %s" % [n, want, " | ".join(PackedStringArray(bad.slice(0, 4)))])
	var sore := GameState.story_card("health_pulled_up_sore", p)
	var sl := StoryEngine.silence_line(sore)
	_check(sl.contains("Play him") and sl.contains("%") and sl.contains("chance"),
			"The sore star's card says leaving it plays him, with the odds (%s)" % sl)
	# Saying nothing's own price still reads as before, now with its size.
	var quiet := GameState.story_card("media_in_the_papers", p)
	_check(StoryEngine.silence_line(quiet) == "Say nothing: he trusts you 2% less.", "Saying nothing names its trust cost and size (%s)" % StoryEngine.silence_line(quiet))


## Every Gain and Cost line carries its size: a percentage, a chance or a count of games.
func _test_every_line_has_a_size() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var sized := RegEx.create_from_string("[0-9]+%|this week's game|takes the armband|cleared to play|next (one|two|three|four|five|six) game|games? away from his usual spot")
	var bad := []
	var parts_seen := 0
	for t in StoryDeck.all():
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		for o in card["options"]:
			for e in o["effects"]:
				for part in StoryEngine._effect_parts(e, card["facts"]):
					if str(part[0]) == "note":
						continue
					parts_seen += 1
					var s := StoryEngine.fill(str(part[1]), card["facts"])
					if sized.search(s) == null or s.contains("{"):
						bad.append("%s/%s %s: %s" % [t["id"], o["key"], e.get("op", ""), s])
	_check(parts_seen >= 300 and bad.is_empty(), "Every gain and cost carries its size (%d phrases): %s" % [parts_seen, " | ".join(PackedStringArray(bad.slice(0, 5)))])
	var sore := GameState.story_card("health_pulled_up_sore", p)
	var play := " ".join(StoryEngine.stakes_lines(sore["options"][1]["effects"], sore["facts"]))
	var pct := roundi(Injuries.chance(_with(p, "sore")) * 100.0)
	_check(play.contains("about a %d%% chance he is injured" % pct), "Playing him sore states his own chance of injury (%d%%: %s)" % [pct, play])


func _with(p: Dictionary, flag: String) -> Dictionary:
	var q := p.duplicate()
	q[flag] = true
	return q


## The numbers in the lines are the effects' own, and the rules' constants the
## lines quote are the ones the game plays by.
func _test_line_numbers_match_effects() -> void:
	_start()
	var p: Dictionary = GameState.my_list[4]
	var bad := []
	var checked := 0
	for t in StoryDeck.all():
		var card := GameState.story_card(str(t["id"]), p if str(t["subject"].get("kind", "")) == "player" else {})
		for o in card["options"]:
			for e in o["effects"]:
				var op := str(e.get("op", ""))
				var s := StoryEngine.fill(" ".join(PackedStringArray((StoryEngine._effect_parts(e, card["facts"]) as Array).map(func(x): return str(x[1])))), card["facts"])
				var want := ""
				match op:
					"morale", "board", "trust":
						want = "%d%%" % absi(StoryEngine.effect_d(e, card["facts"]))
					"xp":
						want = "%d%% of a senior game" % maxi(1, roundi(float(e["d"]) * 100.0 / float(GameState.XP_SENIOR_GAME)))
					"slow_start":
						want = "About a %d%% chance" % int(e["chance"])
					"loss_sting":
						want = "about a %d%% chance the side's morale also falls %d%%" % [int(e["chance"]), absi(int(e["d"]))]
					"expects_game":
						want = "morale falls up to %d%%, he trusts you %d%% less" % [int(e.get("sting", 12)), absi(ClubStories.BROKEN_PROMISE_TRUST)]
				if want == "":
					continue
				checked += 1
				if not s.contains(want):
					bad.append("%s/%s %s wants '%s': %s" % [t["id"], o["key"], op, want, s])
	_check(checked >= 300 and bad.is_empty(), "Every size in the lines is the effect's own (%d effects): %s" % [checked, " | ".join(PackedStringArray(bad.slice(0, 4)))])
	_check(StoryEngine.SENIOR_GAME_XP == GameState.XP_SENIOR_GAME, "Development is quoted against the game's own senior-game XP")
	_check(is_equal_approx(MatchSim._start_energy({"heavy_legs": true}), float(StoryEngine.HEAVY_LEGS_START))
			and is_equal_approx(MatchSim._start_energy({"slow_start": true}), ClubLife.SLOW_LEGS)
			and is_equal_approx(MatchSim._start_energy({"sore": true}), ClubLife.SORE_LEGS),
			"The legs the lines quote are the legs the match starts them on")
	var q: Dictionary = GameState.my_list[0]
	var ask := Contracts.asking_salary(q)
	_check(ClubLife.early_price(q) == ask + maxi(1, roundi(float(ask) * StoryEngine.EARLY_PREMIUM_PCT / 100.0)),
			"An early deal's premium is the one the line quotes")
	var heavy := " ".join(StoryEngine.stakes_lines([{"op": "heavy_legs", "who": "all"}], {}))
	var fresh := " ".join(StoryEngine.stakes_lines([{"op": "fresh"}], {}))
	_check(heavy.contains("%d%% more likely to be injured" % roundi((ClubLife.HEAVY_RISK - 1.0) * 100.0)) and not heavy.contains("soft-tissue")
			and fresh.contains("%d%% less likely" % roundi((1.0 - ClubLife.FRESH_RISK) * 100.0)),
			"Heavy and fresh legs quote the injury rule's own sizes, for every injury (%s / %s)" % [heavy, fresh])
	var sting := " ".join(StoryEngine.stakes_lines([{"op": "loss_sting", "chance": 20, "d": -8}], {}))
	_check(not sting.contains("instead") and sting.contains("also falls 8%"), "The finals sting says the fall comes on top of the lift (%s)" % sting)
	var slow := " ".join(StoryEngine.stakes_lines([{"op": "slow_start", "who": "subject", "chance": 15, "on": "week"}], {}))
	_check(slow.contains("this week's game") and slow.contains("15%") and slow.contains("for the first quarter"), "A slow start in the season names this week's game and its chance (%s)" % slow)
