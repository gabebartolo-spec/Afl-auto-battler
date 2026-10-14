extends RefCounted
## The pre-season papers (director, 2026-10-13: "Predict, and you answer"): the
## ladder they print in week 8, the one story they ask you, and the three ways
## to answer (back it, deflect, talk it up). Talking the club up lifts the
## board's mood now and puts a finish on the record; the board's goal never
## moves; a card comes mid-season if the club is behind its own words.
## Every season here is seeded.

const Tap := preload("res://tests/tap.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 4127
const CLUB := "FRE"


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	Features.set_on("preseason", true)
	_test_rules()
	_test_deck()
	_test_flow()
	_test_answers()
	_test_reckoning()
	_test_silence_and_sim()
	_test_saves()
	await _test_screen()
	await _test_switch_off()
	PreSeason.reload()
	Features.clear("preseason")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Papers tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _career(club := CLUB) -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season(club, GameDB.club_list(club))
	GameState.open_preseason()


## Press on until the papers are waiting (the intra-club match is simmed on
## the way, as pressing on does).
func _to_papers() -> bool:
	var guard := 0
	while GameState.preseason_active() and GameState.preseason_stop() != "papers" and guard < 12:
		guard += 1
		GameState.preseason_advance()
	return GameState.preseason_stop() == "papers"


## Put the papers' story on a chosen kind, as if they had run it.
func _force(kind: String, pred := 13) -> void:
	var rec: Dictionary = GameState.papers_record()
	rec["kind"] = kind
	rec["pred"] = pred
	rec["claim"] = 0
	rec["answered"] = false
	rec["result"] = ""
	rec["pid"] = GameState._papers_breakout() if kind == "breakout" else ""


# ---------------------------------------------------------------------------
func _test_rules() -> void:
	PreSeason.reload()
	var ratings := {"AAA": 70, "BBB": 70, "CCC": 70, "DDD": 72}
	var last := {"AAA": 9, "BBB": 3, "CCC": 0}
	var expect := {"AAA": 1, "BBB": 2, "CCC": 3, "DDD": 4}
	var order := PreSeason.predicted_order(ratings, last, expect)
	_check(order == ["DDD", "BBB", "AAA", "CCC"],
			"The paper's ladder is the better side first; level sides go to last year's finish, an unknown finish last (%s)" % str(order))
	var again := PreSeason.predicted_order({"X": 60, "Y": 60}, {}, {})
	_check(again == ["X", "Y"], "Level in everything, the club code settles it, so the same lists print the same ladder")
	_check(PreSeason.claim_rank(13) == 9 and PreSeason.claim_rank(3) == 1 and PreSeason.claim_rank(1) == 1,
			"Talking the club up names a few places better than the paper, never above first")
	_check(PreSeason.places_behind(12, 9) == 3 and PreSeason.places_behind(7, 9) == 0 and PreSeason.places_behind(5, 0) == 0,
			"Behind your words is places below the finish you named; ahead of it, or nothing named, is none")
	_check(PreSeason.reckoning_due(10, 9) and not PreSeason.reckoning_due(9, 9) and not PreSeason.reckoning_due(18, 0),
			"The papers come back only when the club is below its own words")
	_check(PreSeason.finishes_short({"key": "top4", "pos": 4}, 6) and not PreSeason.finishes_short({"key": "finals", "pos": 10}, 10)
			and PreSeason.finishes_short({"key": "wins7", "wins": 7}, 16) and not PreSeason.finishes_short({"key": "wins7", "wins": 7}, 14),
			"The papers doubt a goal when they have the club finishing below it")
	_check(PreSeason.ordinal(1) == "1st" and PreSeason.ordinal(12) == "12th" and PreSeason.ordinal(13) == "13th" and PreSeason.ordinal(22) == "22nd",
			"A finish is said as a coach says it")
	var s := PreSeason.papers_seed(SUITE_SEED, 2027, CLUB)
	_check(PreSeason.pick_paper(["finish", "breakout"], s) == PreSeason.pick_paper(["finish", "breakout"], s)
			and PreSeason.pick_paper([], s) == "finish",
			"Which story runs is the pre-season's own seeded draw")


func _test_deck() -> void:
	_check(StoryDeck.validate(StoryDeck.all()).is_empty(), "The deck, with the papers' four cards, validates: %s" % str(StoryDeck.validate(StoryDeck.all())))
	var nf := 0
	for id in ["media_papers_finish", "media_papers_pressure", "media_papers_breakout", "media_papers_reckoning"]:
		var t := StoryDeck.by_id(StoryDeck.all(), id)
		nf += 1 if not t.is_empty() else 0
	_check(nf == 4, "All four cards exist")
	var finish := StoryDeck.by_id(StoryDeck.all(), "media_papers_finish")
	var pressure := StoryDeck.by_id(StoryDeck.all(), "media_papers_pressure")
	var breakout := StoryDeck.by_id(StoryDeck.all(), "media_papers_breakout")
	_check(bool(finish.get("scripted", false)) and bool(pressure.get("scripted", false)) and bool(breakout.get("scripted", false))
			and not bool(StoryDeck.by_id(StoryDeck.all(), "media_papers_reckoning").get("scripted", false)),
			"The three questions are asked by the pre-season, never drawn in a round; the reckoning is drawn like any card")


func _test_flow() -> void:
	_career()
	_check(_to_papers() and GameState.preseason_week() == 8,
			"Pressing on stops at the papers in week 8, after the intra-club match")
	var rec: Dictionary = GameState.papers_record()
	_check((rec["order"] as Array).size() == GameState.season.clubs.size() and (rec["order"] as Array).has(CLUB)
			and int(rec["pred"]) == (rec["order"] as Array).find(CLUB) + 1,
			"The paper prints every club once, and yours at the place it says")
	_check(["finish", "breakout", "pressure", ""].has(str(rec["kind"])), "One story, of the three kinds, or none")
	var order1: Array = (rec["order"] as Array).duplicate()
	var kind1 := str(rec["kind"])
	_career()
	_to_papers()
	_check(GameState.papers_record()["order"] == order1 and str(GameState.papers_record()["kind"]) == kind1,
			"The same career prints the same ladder and runs the same story")
	var goal_before := (GameState.board["goal"] as Dictionary).duplicate()
	GameState.preseason_advance()
	_check(not GameState.preseason_active() and GameState.board["goal"] == goal_before,
			"Pressing on without an answer goes to Round 1, and the board's goal is as it was")
	# The papers never touch the match: the same pre-season, with and without
	# the papers' answer, plays the same first round.
	_career()
	_to_papers()
	GameState.preseason_advance()
	GameState.advance()
	var sig_a := str(GameState.season_log.back()["score"])
	_career()
	_to_papers()
	_force("finish")
	GameState.papers_answer(2)
	GameState.preseason_advance()
	GameState.advance()
	_check(str(GameState.season_log.back()["score"]) == sig_a,
			"What you tell the papers does not change the first match's result")


func _lines(card: Dictionary, i: int) -> PackedStringArray:
	return StoryEngine.stakes_lines((card["options"][i] as Dictionary).get("effects", []), card["facts"])


func _test_answers() -> void:
	for kind in ["finish", "pressure", "breakout"]:
		_career()
		_to_papers()
		_force(kind)
		var card := GameState.papers_card()
		_check(not card.is_empty() and (card["options"] as Array).size() == 3,
				"%s: the story has three answers" % kind)
		var every := true
		for i in range(3):
			var lines := _lines(card, i)
			var gain := false
			var cost := false
			for l in lines:
				gain = gain or l.begins_with("Gain: ")
				cost = cost or l.begins_with("Cost: ")
			every = every and gain and cost
		_check(every, "%s: every answer says what it gains and what it costs" % kind)
		var text: String = str(card["title"]) + " " + str(card["text"])
		for i in range(3):
			text += " " + str(card["options"][i]["label"]) + " " + " ".join(_lines(card, i))
		_check(not text.contains("{") and not text.contains("}") and not text.contains("  "),
				"%s: no token is left unfilled (%s)" % [kind, text])
		if kind == "breakout":
			var p: Dictionary = GameState.list_player(str(GameState.papers_record()["pid"]))
			_check(not p.is_empty() and text.contains(GameDB.player_display_name(p)) and float(p["age"]) <= 22.0,
					"The breakout story names a young player on the list")
	# Talking the club up.
	_career()
	_to_papers()
	_force("finish")
	var board0 := GameState.board_confidence()
	var goal0 := (GameState.board["goal"] as Dictionary).duplicate()
	var card := GameState.papers_card()
	_check(str(card["options"][2]["label"]).contains("9th"),
			"Talking it up names the finish: 13th tipped, 9th claimed")
	var out := GameState.papers_answer(2)
	_check(out != "" and GameState.board_confidence() > board0 and int(GameState.papers_record()["claim"]) == 9,
			"Talking the club up lifts the board's mood now and puts 9th on the record")
	_check(GameState.board["goal"] == goal0, "...and the board's goal does not move")
	_check(GameState.story["flags"].get("club", {}).has("talked_up"), "...and the talk is remembered for the season")
	_check(GameState.papers_answer(0) == "" and int(GameState.papers_record()["claim"]) == 9,
			"A story is answered once")
	var cost_line := ""
	for l in _lines(card, 2):
		if l.begins_with("Cost: "):
			cost_line = l
	_check(cost_line.contains("on the record") and cost_line.contains("season is well on") and cost_line.contains("target stays where it is"),
			"The cost of talking up says what is held against you, and that the target does not move (%s)" % cost_line)
	# Backing it, deflecting: nothing on the record.
	for pair in [[0], [1]]:
		_career()
		_to_papers()
		_force("finish")
		var b0 := GameState.board_confidence()
		GameState.papers_answer(int(pair[0]))
		_check(int(GameState.papers_record()["claim"]) == 0 and not GameState.story["flags"].has("club"),
				"Answer %d puts nothing on the record" % int(pair[0]))
		_check(GameState.board_confidence() == b0 + (2 if int(pair[0]) == 0 else -2),
				"Answer %d moves the board by what its Gain and Cost say" % int(pair[0]))
	# The breakout: talking him up is a promised run, with its sting if broken.
	_career()
	_to_papers()
	_force("breakout")
	var pid := str(GameState.papers_record()["pid"])
	var kid: Dictionary = GameState.list_player(pid)
	GameState.papers_answer(2)
	_check(Backing.is_active(kid), "Promising the tipped kid a run puts the run on him")


func _test_reckoning() -> void:
	_career()
	_to_papers()
	_force("finish")
	GameState.papers_answer(2)
	GameState.preseason_advance()
	_check(not GameState.preseason_active(), "Into the season")
	var deck := StoryDeck.all()
	var t := StoryDeck.by_id(deck, "media_papers_reckoning")
	# Claim 1st: any other place is behind it.
	GameState.preseason["papers"]["claim"] = 1
	for i in range(9):
		GameState.advance()
	var ctx := ClubStories.context(GameState)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var behind := GameState.my_position() > 1
	_check(behind and int(ctx["club"]["words_behind"]) == GameState.my_position() - 1
			and str(ctx["club"]["words_word"]) == "1st",
			"Behind the 1st that was named, the club knows how far behind")
	# Nine rounds on, the game has already dealt it by itself (the card is drawn like any other).
	_check(GameState.story["last"].has("media_papers_reckoning"),
			"Behind its words, the club is reminded of them in the weeks that follow, without being asked")
	GameState.story["last"].erase("media_papers_reckoning")
	GameState.story["season"].erase("media_papers_reckoning")
	GameState.story["cats"] = []
	# Eligible only once the flag is old enough; the flag was set before Round 1.
	var wk := StoryEngine.week_abs(GameState.season_year, ClubStories.week_in_season(GameState))
	var subj := StoryEngine.eligible_subject(t, ctx, GameState.story, wk, rng)
	_check(subj.get("kind", "") == "club", "Behind its own words by mid-season, the papers' card can come")
	var card := GameState.story_card("media_papers_reckoning")
	var txt := str(card["title"]) + " " + str(card["text"])
	_check(txt.contains("1st") and txt.contains(PreSeason.ordinal(GameState.my_position())) and not txt.contains("{"),
			"The card quotes the coach's words and where the club sits (%s)" % txt)
	_check((card["options"] as Array).size() == 2 and not _lines(card, 0).is_empty() and not _lines(card, 1).is_empty(),
			"It asks for an answer, and each answer says what it gains and costs")
	# Not behind: nothing.
	GameState.preseason["papers"]["claim"] = 18
	var ctx2 := ClubStories.context(GameState)
	_check(StoryEngine.eligible_subject(t, ctx2, GameState.story, wk, rng).is_empty(),
			"Ahead of its words, no card")
	# Never talked up: nothing.
	GameState.preseason["papers"]["claim"] = 1
	GameState.story["flags"] = {}
	_check(StoryEngine.eligible_subject(t, ClubStories.context(GameState), GameState.story, wk, rng).is_empty(),
			"The club that never talked itself up is never reminded of it")
	# The goal never moved through all of it.
	_check(not (GameState.board["goal"] as Dictionary).is_empty(), "The board still has its own goal")


func _test_silence_and_sim() -> void:
	_career()
	_to_papers()
	_force("finish")
	var b0 := GameState.board_confidence()
	GameState.preseason_advance()
	_check(GameState.board_confidence() == b0 - 3 and str(GameState.papers_record()["result"]).begins_with("You say nothing"),
			"Saying nothing costs the board three, as on any card, and the result says so")
	# A hands-off run goes through the papers on silence.
	_career()
	var board_a := GameState.board_confidence()
	GameState.preseason_sim_to_round1()
	_check(not GameState.preseason_active() and bool(GameState.papers_record().get("seen", false))
			and bool(GameState.papers_record().get("answered", false)),
			"Sim to Round 1 passes the papers, and the story goes unanswered")
	var kind := str(GameState.papers_record()["kind"])
	var cost := -3 if kind == "finish" else (-4 if kind == "pressure" else 0)
	_check(GameState.board_confidence() == board_a + cost,
			"...at the cost silence has on that card (%s)" % kind)


func _test_saves() -> void:
	_career()
	_to_papers()
	_force("pressure")
	GameState.papers_answer(2)
	var order: Array = (GameState.papers_record()["order"] as Array).duplicate()
	_check(GameState.save_career(), "A career saves at the papers")
	GameState.reset()
	_check(GameState.load_career() and GameState.preseason_stop() == "papers"
			and GameState.papers_record()["order"] == order and int(GameState.papers_record()["claim"]) > 0
			and bool(GameState.papers_record()["answered"]),
			"...and loads back to the same papers, the same answer, the same claim")
	GameState.preseason_advance()
	_check(not GameState.preseason_active(), "...and goes on to Round 1")
	# A pre-season saved before the papers existed (it stood at the intra-club match) plays on to them.
	_career()
	var guard := 0
	while GameState.preseason_week() < 5 and guard < 12:
		guard += 1
		GameState.preseason_advance()
	GameState.preseason.erase("papers")
	GameState.save_career()
	GameState.reset()
	_check(GameState.load_career() and GameState.preseason_active(), "An older save mid pre-season loads")
	_check(_to_papers() and not GameState.papers_record().is_empty(), "...and meets the papers in week 8")
	GameState.delete_saved_career()


func _test_screen() -> void:
	PreSeason.reload()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	_career("STK")
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.set_setting("seen_training_intro", true)
	_to_papers()
	_force("finish")
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	var scene := tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "PreSeasonHero") == "The papers",
			"With the papers waiting, the game opens on the papers")
	_check(scene.find_child("PapersTitle", true, false) != null and _label(scene, "PapersTitle").contains("13th"),
			"The story's headline is on the page")
	var rows := scene.find_children("PapersRow_*", "HBoxContainer", true, false)
	_check(rows.size() == GameState.season.clubs.size(), "The ladder lists every club")
	var all := true
	for i in range(3):
		all = all and scene.find_child("Papers_%d" % i, true, false) != null \
				and scene.find_child("PapersGain_%d" % i, true, false) != null \
				and scene.find_child("PapersCost_%d" % i, true, false) != null
	_check(all, "Each of the three answers shows a Gain line and a Cost line")
	_check(scene.find_child("PapersSilence", true, false) != null and _label(scene, "PapersSilence").contains("Say nothing"),
			"Saying nothing says what it costs")
	var board0 := GameState.board_confidence()
	_check(await _tap(scene.find_child("Papers_2", true, false), "Talk the club up"),
			"A finger's tap answers the papers")
	_check(int(GameState.papers_record()["claim"]) > 0 and GameState.board_confidence() > board0,
			"...and the answer lands")
	scene = tree.current_scene as Control
	_check(scene.find_child("Papers_0", true, false) == null and _label(scene, "PapersResult").begins_with("You tell the press"),
			"Once answered, the buttons give way to what you said")
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "On to Round 1"),
			"A finger's tap goes on to Round 1")
	await _frames(tree, 6)
	_check(not GameState.preseason_active() and Router.current() == "hub", "...and the hub is next")
	# The tipped player's name wears his club's colour.
	_career("STK")
	_to_papers()
	_force("breakout")
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	var who: Dictionary = GameState.list_player(str(GameState.papers_record()["pid"]))
	var head := scene.find_child("PapersTitle", true, false) as Control
	_check(head is RichTextLabel and NameInk.plain(head).contains(GameDB.player_display_name(who))
			and (head as RichTextLabel).text.contains("[color="),
			"The breakout's name in the headline is in his club's colour")
	# Wide.
	_career("STK")
	_to_papers()
	_force("finish")
	tree.root.size = Vector2i(1280, 720)
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(scene.find_child("PapersTitle", true, false) != null and scene.find_child("PapersLadder", true, false) != null,
			"A wide screen shows the story and the ladder together")
	var last_row := scene.find_child("PapersRow_17", true, false) as Control
	var foot := scene.find_child("PreSeasonGo", true, false) as Control
	_check(last_row != null and foot != null and last_row.get_global_rect().end.y <= foot.global_position.y,
			"On a PC all 18 clubs of the ladder are in view above the footer, no scrolling")
	tree.root.size = Vector2i(390, 844)


func _test_switch_off() -> void:
	Features.set_on("preseason", false)
	_career()
	_check(GameState.preseason.is_empty() and GameState.papers_record().is_empty() and GameState.preseason_stop() == "",
			"With the pre-season off there are no papers")
	var f := ClubStories.club_facts(GameState, 1, "regular")
	_check(int(f["words_behind"]) == 0 and str(f["paper"]) == "", "...and the stories know nothing of them")
	Features.set_on("preseason", true)


func _frames(tree: SceneTree, n: int) -> void:
	for i in range(n):
		await tree.process_frame


func _tap(b: Control, what: String) -> bool:
	var why: String = await Tap.tap(b)
	if why != "":
		_check(false, "A finger's tap reaches %s (%s)" % [what, why])
		if is_instance_valid(b) and b is BaseButton:
			(b as BaseButton).emit_signal("pressed")
	return why == ""


func _label(scene: Node, node_name: String) -> String:
	var l := scene.find_child(node_name, true, false) as Control if scene != null else null
	return NameInk.plain(l) if l != null else ""
