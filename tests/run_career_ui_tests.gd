extends SceneTree
## godot --headless --path . --script tests/run_career_ui_tests.gd
## Main menu save flow (Continue Career, New Career confirmation) and the
## Android back button / Escape routing, driven through the real scenes.
## Classes are reached through load() and autoload nodes: a --script runner
## compiles before the autoloads exist.

const Tap := preload("res://tests/tap.gd")

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []

## Every season in this suite starts from a fixed seed (C15), never the clock.
const SUITE_SEED := 2027


func _initialize() -> void:
	_run.call_deferred()


func _test_rivalry_catalogue() -> void:
	_check(Rivalries.are_rivals("COL", "CAR") and Rivalries.are_rivals("CAR", "COL"),
			"Established rivalries work in either fixture direction")
	_check(Rivalries.label("ADE", "PAD") == "The Showdown", "Named rivalry context is preserved")
	_check(Rivalries.label("WCE", "FRE") == "The Western Derby", "WA meetings are always The Western Derby")
	_check(Rivalries.label("GCS", "BRL") == "The Pineapple Grapple", "Queensland meetings are always The Pineapple Grapple")
	_check(Rivalries.label("TAS", "CANB") == "Expansion Cup", "Expansion clubs contest the Expansion Cup")
	_check(Rivalries.are_rivals("GWS", "WBD"), "Giants and Bulldogs are established rivals")
	_check(not Rivalries.are_rivals("ADE", "GEE"), "Ordinary opponents are not labelled rivals")
	var dynamic := {}
	for i in range(4):
		Rivalries.record_match(dynamic, {"home": "ADE", "away": "GEE",
				"score": [80, 75], "label": "Round %d" % (i + 1)}, 2027 + i)
	_check(Rivalries.state(dynamic, "ADE", "GEE") == "brewing",
			"Repeated close games can make a new rivalry brew")
	Rivalries.record_match(dynamic, {"home": "ADE", "away": "GEE",
			"score": [91, 88], "label": "Preliminary Final", "is_final": true}, 2031)
	Rivalries.record_match(dynamic, {"home": "GEE", "away": "ADE",
			"score": [77, 73], "label": "Grand Final", "is_final": true}, 2032)
	_check(Rivalries.state(dynamic, "ADE", "GEE") == "rivals",
			"Repeated high-stakes meetings can create a full dynamic rivalry")
	_check(Rivalries.context(dynamic, "ADE", "GEE") == "A rivalry forged over 2 finals meetings and 4 close games.",
			"Close finals count as finals meetings, not twice: " + Rivalries.context(dynamic, "ADE", "GEE"))
	var no_finals := {}
	for i in range(8):
		Rivalries.record_match(no_finals, {"home": "BRL", "away": "SYD",
				"score": [80, 75], "label": "Round %d" % (i + 1)}, 2027 + i)
	_check(Rivalries.context(no_finals, "BRL", "SYD") == "A rivalry forged over 8 close games.",
			"No finals: the line leaves the finals out: " + Rivalries.context(no_finals, "BRL", "SYD"))
	var old_rec: Dictionary = (Rivalries.dynamic(dynamic, "ADE", "GEE") as Dictionary).duplicate(true)
	old_rec.erase("close_finals")
	_check(Rivalries.context({Rivalries.pair_key("ADE", "GEE"): old_rec}, "ADE", "GEE") == Rivalries.context(dynamic, "ADE", "GEE"),
			"An older save's rivalry reads its close finals from the meetings it kept")
	var before := int((Rivalries.dynamic(dynamic, "ADE", "GEE") as Dictionary)["score"])
	Rivalries.record_match(dynamic, {"home": "GEE", "away": "ADE",
			"score": [77, 73], "label": "Grand Final", "is_final": true}, 2032)
	_check(int((Rivalries.dynamic(dynamic, "ADE", "GEE") as Dictionary)["score"]) == before,
			"Reprocessing a saved match cannot inflate rivalry history")
	var quiet := {}
	for i in range(8):
		Rivalries.record_match(quiet, {"home": "NTH", "away": "STK",
				"score": [110, 70], "label": "Round %d" % (i + 1)}, 2027 + i)
	_check(Rivalries.state(quiet, "NTH", "STK") == "",
			"Routine meetings alone do not manufacture a rivalry")

func _test_media_conference_rules() -> void:
	var MediaConferenceScript = load("res://scripts/sim/MediaConference.gd")
	var VignetteScript = load("res://scripts/ui/MediaConferenceVignette.gd")
	var recent := {}
	var heavy: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 8,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, recent)
	_check(str(heavy.get("key", "")) == "heavy_loss", "Heavy loss earns a factual media question")
	_check((heavy.get("options", []) as Array).size() == 3, "Media question offers three responses")
	recent["heavy_loss"] = 8
	var repeat: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 10,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, recent)
	_check(repeat.is_empty(), "Same media angle respects its cooldown")
	var ordinary: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15,
			"result": {"home": "COL", "away": "CAR", "score": [88, 72]}}, {})
	_check(ordinary.is_empty(), "Ordinary matches do not force a press conference")
	var close: Dictionary = MediaConferenceScript.pick({"club": "CAR", "opponent_name": "Collingwood", "round": 16,
			"result": {"home": "COL", "away": "CAR", "score": [84, 86]}}, {})
	_check(str(close.get("key", "")) == "close_game", "Close finishes can drive the press conference")
	var drawn: Dictionary = MediaConferenceScript.pick({"club": "CAR", "opponent_name": "Collingwood", "round": 16,
			"result": {"home": "COL", "away": "CAR", "score": [80, 80], "goals": [12, 12], "behinds": [8, 8]}}, {})
	_check(str(drawn.get("key", "")) == "close_game" and not str(drawn.get("question", "")).contains("What decided it"),
			"A draw is never asked what decided it (%s)" % str(drawn.get("question", "")))
	# Recurring journalists (RPG-002): each question has its own asker, and what
	# you say can come back.
	_check(str(heavy.get("journalist", "")) == "muckraker" and str(heavy.get("by", "")) == "Gary Haddon, The Siren"
			and str(close.get("journalist", "")) == "stats", "Each question comes from its own journalist")
	var said := {"said|big_win": {"year": 2027, "option": 1, "opp": "Carlton"}}
	var back: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Essendon", "round": 12, "year": 2027,
			"result": {"home": "COL", "away": "ESS", "score": [40, 100]}}, said)
	var fresh: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Essendon", "round": 12, "year": 2028,
			"result": {"home": "COL", "away": "ESS", "score": [40, 100]}}, said)
	_check(str(back.get("question", "")).begins_with("After beating Carlton you said your method was the standard")
			and not str(fresh.get("question", "")).contains("you said"),
			"Claim your method after a big win and the Muckraker quotes it after the next thrashing, that season only")
	var geek: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 16,
			"result": {"home": "COL", "away": "CAR", "score": [80, 83],
			"team": [{"inside50": 54, "clearances": 36}, {"inside50": 41, "clearances": 38}]}}, {})
	_check(str(geek.get("question", "")) == "You won the inside 50s 54 to 41 and still lost by 3. What went wrong?",
			"The Stats Geek quotes a number that was true of the match (%s)" % str(geek.get("question", "")))
	var kids: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15, "young": 6,
			"result": {"home": "COL", "away": "CAR", "score": [88, 72]}}, {})
	_check(str(kids.get("key", "")) == "young_side" and str(kids.get("journalist", "")) == "philosopher",
			"A young side brings the Philosopher")
	# She waits longer than the others between questions (director 2026-11-07:
	# about one conference in six), and "21 or younger" counts to his 22nd birthday.
	var MCY = load("res://scripts/sim/MediaConference.gd")
	var kid_ctx := {"club": "COL", "opponent_name": "Carlton", "young": 6, "year": 2027,
			"result": {"home": "COL", "away": "CAR", "score": [88, 72]}}
	var asked := []
	for r in [15 + MCY.COOLDOWN_ROUNDS + 1, 15 + MCY.YOUNG_SIDE_COOLDOWN, 15 + MCY.YOUNG_SIDE_COOLDOWN + 1]:
		var c := kid_ctx.duplicate(true)
		c["round"] = r
		asked.append(not MCY.pick(c, {"young_side": {"year": 2027, "round": 15}}).is_empty())
	_check(asked == [false, false, true] and MCY.YOUNG_SIDE_COOLDOWN > MCY.COOLDOWN_ROUNDS,
			"The Philosopher waits %d rounds between questions (%s)" % [MCY.YOUNG_SIDE_COOLDOWN, str(asked)])
	_check(MCY.is_young(21.9) and MCY.is_young(19.0) and not MCY.is_young(22.0),
			"A player counts as 21 or younger until his 22nd birthday")
	_check(int(kids.get("margin", 0)) == 16, "The question keeps the margin it came from")
	# An injury in a win never gets the answer that the injury cost the game.
	var hurt_win: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15,
			"injuries": [{"name": "Jack Smith"}], "result": {"home": "COL", "away": "CAR", "score": [88, 72]}}, {})
	var hurt_loss: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15,
			"injuries": [{"name": "Jack Smith"}], "result": {"home": "COL", "away": "CAR", "score": [72, 88]}}, {})
	var win_lines := str((hurt_win.get("options", []) as Array).map(func(o): return str(o["label"])))
	_check(str(hurt_win.get("key", "")) != "injury" and not win_lines.contains("cost us the game")
			and str(hurt_loss.get("key", "")) == "injury"
			and str((hurt_loss["options"] as Array)[2]["label"]).contains("cost us the game"),
			"The injury question, whose answers blame a loss, is asked after a loss only (%s)" % win_lines)
	# More questions for variety (director 2026-11-07): written versions take
	# turns, and the day's other stories each have a journalist of their own.
	var hl_ctx := {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101], "goals": [8, 15], "behinds": [7, 11]}}
	var v0: Dictionary = MCY.pick(hl_ctx, {"asked": {"heavy_loss": 3}})
	var v1: Dictionary = MCY.pick(hl_ctx, {"asked": {"heavy_loss": 1}})
	var v2: Dictionary = MCY.pick(hl_ctx, {"asked": {"heavy_loss": 2}})
	_check(str(v0.get("qid", "")) == "heavy_loss.0" and str(v1.get("qid", "")) == "heavy_loss.1"
			and str(v2.get("qid", "")) == "heavy_loss.2"
			and str(v1.get("question", "")) == "Carlton kicked 15 goals to your 8. Where do you even start?"
			and str(v2.get("question", "")).begins_with("That's a 46-point hiding from Carlton."),
			"A question's three versions take turns (%s / %s / %s)" % [str(v0.get("question", "")),
			str(v1.get("question", "")), str(v2.get("question", ""))])
	# Audit 19/60: the most-asked questions each have three versions, every
	# one different, with the same four kinds of answer.
	var third_ctx := {
		"big_win": {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027,
				"result": {"home": "COL", "away": "CAR", "score": [122, 42]}},
		"injury": {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027, "injuries": [{"name": "Jack Smith"}],
				"result": {"home": "COL", "away": "CAR", "score": [72, 88]}},
		"young_side": {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027, "young": 6,
				"result": {"home": "COL", "away": "CAR", "score": [80, 70]}},
		"milestone": {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027,
				"milestone": {"name": "Jack Smith", "games": 200}, "result": {"home": "COL", "away": "CAR", "score": [80, 70]}},
		"close_game": {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027,
				"result": {"home": "COL", "away": "CAR", "score": [80, 79], "goals": [11, 11], "behinds": [14, 13]}},
	}
	for k in third_ctx:
		var texts := {}
		var kinds_ok := true
		for n in range(3):
			var q: Dictionary = MCY.pick(third_ctx[k], {"asked": {k: n}})
			texts[str(q.get("question", ""))] = true
			var ks := (q.get("options", []) as Array).slice(0, 3).map(func(o): return str(o["kind"]))
			kinds_ok = kinds_ok and str(q.get("key", "")) == k and ks == ["criticise", "method", "back"]
		_check(texts.size() == 3 and kinds_ok, "%s has three different versions (%s)" % [k, str(texts.keys())])
	var c1: Dictionary = MCY.pick(third_ctx["close_game"], {"asked": {"close_game": 1}})
	var c2: Dictionary = MCY.pick(third_ctx["close_game"], {"asked": {"close_game": 2}})
	_check(str(c1.get("question", "")).begins_with("11.14 to 11.13 against Carlton")
			and str(c2.get("question", "")).begins_with("1 point in it against Carlton")
			and str(c2.get("qid", "")) == "close_game.shots.2",
			"The close-game shots question's versions read the scores (%s / %s)" % [str(c1.get("question", "")), str(c2.get("question", ""))])
	# The Muckraker quotes a claim back once only.
	var said_cb := {"year": 2027, "option": 1, "opp": "Essendon", "round": 5}
	var cb1: Dictionary = MCY.pick(hl_ctx, {"said|big_win": said_cb})
	var cb2: Dictionary = MCY.pick(hl_ctx, {"said|big_win": said_cb.merged({"quoted": true})})
	_check(str(cb1.get("qid", "")) == "heavy_loss.said" and str(cb2.get("qid", "")) == "heavy_loss.0",
			"A claim is quoted back once, then the heavy-loss questions return (%s / %s)" % [str(cb1.get("qid", "")), str(cb2.get("qid", ""))])
	var bw_ctx := {"club": "COL", "opponent_name": "Carlton", "round": 8, "year": 2027,
			"result": {"home": "COL", "away": "CAR", "score": [122, 42]}}
	var bw: Dictionary = MCY.pick(bw_ctx, {"asked": {"big_win": 1}})
	_check(str(bw.get("question", "")).begins_with("An 80-point win over Carlton"),
			"The big-win question says 'An 80-point win' (%s)" % str(bw.get("question", "")))
	var run_ctx := {"club": "COL", "opponent_name": "Carlton", "round": 12, "year": 2027, "losing_run": 3,
			"result": {"home": "COL", "away": "CAR", "score": [70, 85]}}
	var run_q: Dictionary = MCY.pick(run_ctx, {})
	var held: Dictionary = MCY.pick(run_ctx, {"star": {"year": 2027, "round": 11}})
	_check(str(run_q.get("key", "")) == "losing_run" and str(run_q.get("journalist", "")) == "muckraker"
			and str(run_q.get("question", "")).begins_with("That's three losses in a row") and held.is_empty(),
			"A losing run brings the Muckraker, but not the week after a conference")
	var upset: Dictionary = MCY.pick({"club": "COL", "opponent_name": "Carlton", "round": 10, "year": 2027,
			"my_pos": 15, "opp_pos": 2, "result": {"home": "COL", "away": "CAR", "score": [85, 70]}}, {})
	_check(str(upset.get("key", "")) == "upset_win" and str(upset.get("question", "")).contains("You're 15th, Carlton are 2nd"),
			"An upset win quotes the ladder (%s)" % str(upset.get("question", "")))
	var back_from: Dictionary = MCY.pick({"club": "COL", "opponent_name": "Carlton", "round": 10, "year": 2027,
			"result": {"home": "COL", "away": "CAR", "score": [90, 78], "quarters": [[10, 20], [5, 18], [40, 20], [35, 20]]}}, {})
	_check(str(back_from.get("key", "")) == "comeback"
			and str(back_from.get("question", "")) == "You trailed by 23 at half-time and won by 12. What changed?",
			"A comeback from a break is asked with the real deficit (%s)" % str(back_from.get("question", "")))
	var out_of_it: Dictionary = MCY.pick({"club": "COL", "opponent_name": "Carlton", "round": 25, "year": 2027,
			"final": {"label": "semi final", "status": "eliminated"},
			"result": {"home": "COL", "away": "CAR", "score": [70, 75]}}, {})
	_check(str(out_of_it.get("key", "")) == "final_loss" and str(out_of_it.get("question", "")).contains("semi final"),
			"A finals exit is asked about first")
	var stage = VignetteScript.new()
	stage.size = Vector2(390, 300)
	stage.club = "COL"
	_check(not stage._ready, "Media vignette begins as a staged scene before the question")
	stage.finish_now()
	_check(stage._ready, "Media vignette can skip its play-in to the question")


## Press answers are seeded rolls with their odds shown (bible §4 and "an
## answer is a dice roll based on logic"; director 2026-10-18, ch. 30 row 33).
func _test_press_rolls() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	# A seeded career: answering differs from skipping, the same seed lands the
	# same way, and the same answer can land either way across careers.
	_state.reset()
	_state.start_season("FRE", _db.club_list("FRE"))
	var snap := []
	for p in _state.my_list:
		snap.append(int(p.get("morale", 70)))
	var conf: Dictionary = MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 8, "year": int(_state.season_year),
			"result": {"home": "FRE", "away": "CAR", "score": [55, 101]}}, {})
	var run := func(seed: int, answer: bool) -> Array:
		for i in range(_state.my_list.size()):
			_state.my_list[i]["morale"] = snap[i]
			_state.my_list[i].erase("press_lift")
		_state.board["confidence"] = 50
		_state.media_memory = {}
		_state.career_seed = seed
		_state.media_conference = conf.duplicate(true)
		# Untyped, so the same check runs (and fails) against the old fixed answers.
		var landed = _state.resolve_media_conference(0) if answer else {}
		if not answer:
			_state.skip_media_conference()
		if not (landed is Dictionary):
			landed = {}
		var total := 0
		for p in _state.my_list:
			total += int(p.get("morale", 70))
		return [total, _state.board_confidence(), str(landed.get("landed", ""))]
	var on: Array = run.call(2027, true)
	var off: Array = run.call(2027, false)
	var again: Array = run.call(2027, true)
	_check(on[0] != off[0] and on[1] != off[1], "A seeded run with the press answer differs from one that skips it (morale %d vs %d, board %d vs %d)" % [on[0], off[0], on[1], off[1]])
	_check(on == again, "The same career seed lands the same answer the same way (%s)" % str(on))
	var ways := {}
	var moves := {}
	for seed in range(1, 41):
		var r: Array = run.call(seed, true)
		ways[r[2]] = true
		moves[signi(int(r[0]) - int(off[0]))] = true
	_check(ways.has("a") and ways.has("b") and moves.has(1) and moves.has(-1),
			"Criticising the players is no fixed transaction: across careers their morale both rises and falls (%s)" % str(moves.keys()))
	_state.media_conference = {}
	# Every number on the gate comes from the constants: no digits in a template.
	var digit := RegEx.create_from_string("[0-9]")
	var words: Array = [MC.ODDS_TEMPLATE, MC.MORALE_SIZE, MC.BOARD_SIZE, MC.AFTER_MORALE, MC.AFTER_BOARD,
			MC.HIS_SIZE, MC.AFTER_HIS, MC.OPINION_SIZE, MC.NO_BOARD, MC.LIKES, MC.DISLIKES, MC.STANDING_EFFECT,
			MC.REASON, MC.FADE_NOTE, MC.EITHER_WAY, MC.SEP]
	words.append_array(MC.RECORD_CLAUSE.values())
	words.append_array(MC.RECORD_REASON.values())
	for j in MC.PERSONA.values():
		for k in ["odds_note", "board_note", "named_note", "rule"]:
			if (j as Dictionary).has(k):
				words.append(j[k])
	words.append_array(MC.STANDING_WORDS.values())
	for pair in MC.LEAD_INS.values():
		words.append_array(pair)
	for kind in MC.KINDS + MC.NAMED_KINDS:
		var s: Dictionary = MC.ANSWERS[kind]
		words.append_array((s["both"] as Dictionary).values())
		words.append_array([s["a"]["odds"], s["a"]["after"], s["b"]["odds"], s["b"]["after"]])
	var bare := true
	for w in words:
		bare = bare and digit.search(str(w)) == null
	_check(bare, "No press template carries a literal number; the odds and sizes come from the constants")
	# Each line carries both percentages and both outcomes' effects.
	var carries := true
	var sample := ""
	for kind in MC.KINDS:
		var s: Dictionary = MC.ANSWERS[kind]
		var a: Dictionary = s["a"]
		var b: Dictionary = s["b"]
		for c in [MC.ODDS_MIN, 35, 50, 65, MC.ODDS_MAX]:
			var line: String = MC.odds_line(kind, c)
			var ok := line.contains("%d%% %s" % [c, a["odds"]]) and line.contains("%d%% %s" % [100 - c, b["odds"]]) 					and line.contains(str(MC.effects(kind)["both"]))
			for lever in [["morale", MC.MORALE_SIZE], ["board", MC.BOARD_SIZE]]:
				for o in [a, b]:
					if int(o[lever[0]]) != 0:
						ok = ok and line.to_lower().contains(str(lever[1]) % int(o[lever[0]]))
			if not ok:
				sample = line
			carries = carries and ok
	_check(carries, "Every press answer's line carries its two odds and both outcomes' effects (%s)" % sample)
	# The outcome frequency over 2000 seeded rolls matches the stated odds within 3 points.
	var worst := 0.0
	for kind in MC.KINDS:
		for c in [MC.ODDS_MIN, MC.chance(kind, {}), MC.ODDS_MAX]:
			var hits := 0
			for seed in range(1, 2001):
				if MC.roll(seed, 2027, 8, "heavy_loss", MC.KINDS.find(kind)) <= c:
					hits += 1
			worst = maxf(worst, absf(float(hits) / 20.0 - float(c)))
	_check(worst <= 3.0, "Over 2000 seeded rolls every answer lands its first way as often as its odds say (worst %.1f points off)" % worst)
	# The odds follow the logic.
	var calm := {"morale": 70.0, "journalist": "", "key": "close_game"}
	_check(MC.chance("criticise", {"morale": 70.0, "young": MC.YOUNG_SIDE, "journalist": "", "key": ""}) < MC.chance("criticise", calm)
			and MC.chance("criticise", {"morale": 70.0, "journalist": "muckraker", "key": ""}) < MC.chance("criticise", calm)
			and MC.chance("criticise", {"morale": 90.0}) > MC.chance("criticise", calm),
			"Criticism lands worse on a young side and in the Muckraker's paper, better with a settled group")
	_check(MC.chance("method", {"key": "big_win"}) > MC.chance("method", calm) and MC.chance("method", {"key": "heavy_loss"}) < MC.chance("method", calm),
			"The board buys talk of the method after a big win more than after a thrashing")
	_check(MC.chance("back", {"morale": 50.0}) > MC.chance("back", {"morale": 90.0}),
			"Backing the players lifts a flat group more often than one already flying")


## A fresh FRE career with every press trace cleared and morale at the line.
func _press_reset() -> void:
	_state.reset()
	_state.start_season("FRE", _db.club_list("FRE"))
	_state.career_seed = 2027
	_state.media_memory = {}
	_state.last_injuries = []
	_state.board["confidence"] = 50
	_state.board["why"] = ""
	for p in _state.my_list:
		p["morale"] = 70
		p.erase("press_lift")


func _press_conf(key_result: Array) -> Dictionary:
	return load("res://scripts/sim/MediaConference.gd").pick({"club": "FRE", "opponent_name": "Carlton", "round": 8,
			"year": int(_state.season_year), "result": {"home": "FRE", "away": "CAR", "score": key_result}}, {})


## (g) Caps: no answer, journalist or record check takes a size past list 2,
## named 3, board 3; stacked answers never pass the cap, and the lift fades
## back a point every second round whoever asked, the board's a point a round.
func _test_press_caps_and_fade() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var worst := [0, 0, 0]
	for kind in MC.KINDS + MC.NAMED_KINDS:
		for j in MC.JOURNALISTS.keys() + [""]:
			for verdict in ["", "early", "neutral", "supported", "contradicted"]:
				var fx: Dictionary = MC.effects(kind, {"journalist": j, "verdict": verdict, "name": "Jack"})
				for w in ["a", "b"]:
					worst[0] = maxi(worst[0], absi(int(fx[w]["morale"])))
					worst[1] = maxi(worst[1], absi(int(fx[w]["his"])))
					worst[2] = maxi(worst[2], absi(int(fx[w]["board"])))
	_check(worst[0] <= MC.LIST_CAP and worst[1] <= MC.NAMED_CAP and worst[2] <= MC.BOARD_CAP
			and MC.LIST_CAP == 2 and MC.NAMED_CAP == 3 and MC.BOARD_CAP == 3,
			"Every press size stays inside its cap: list 2, named 3, board 3 (largest %s)" % str(worst))
	var p := {"morale": 70}
	for i in range(5):
		MC.apply_lift(p, 2, MC.LIST_CAP)
	_check(int(p["morale"]) == 72 and int(p["press_lift"]) == 2,
			"Five list-wide lifts in a row stop at the list cap (morale %d)" % int(p["morale"]))
	MC.apply_lift(p, 3, MC.NAMED_CAP)
	_check(int(p["morale"]) == 73 and int(p["press_lift"]) == 3,
			"A named lift on top stops at the named cap, never list plus named (morale %d)" % int(p["morale"]))
	var trail := []
	for r in range(1, 8):
		MC.fade_lift(p, r)
		trail.append(int(p["morale"]))
	_check(trail == [73, 72, 72, 71, 71, 70, 70] and not p.has("press_lift") and not p.has("press_wait"),
			"The lift fades a point every second round back to where he was, then the trace is gone (%s)" % str(trail))
	# Director 2026-11-07: +1 lasts 2 rounds, -2 lasts 4.
	var one := {"morale": 70}
	MC.apply_lift(one, 1, MC.LIST_CAP)
	var one_trail := []
	for r in range(1, 4):
		MC.fade_lift(one, r)
		one_trail.append(int(one["morale"]))
	var two := {"morale": 70}
	MC.apply_lift(two, -2, MC.LIST_CAP)
	var two_trail := []
	for r in range(1, 6):
		MC.fade_lift(two, r)
		two_trail.append(int(two["morale"]))
	_check(one_trail == [71, 70, 70] and two_trail == [68, 69, 69, 70, 70]
			and MC.fade_rounds(1) == 2 and MC.fade_rounds(-2) == 4,
			"A morale +1 lasts 2 rounds and a -2 lasts 4 (%s, %s)" % [str(one_trail), str(two_trail)])
	# Director 2026-11-07: no journalist slows the fade. An old save's lift that
	# still carries the Philosopher's slow flag fades at the one pace, flag gone.
	var old := {"morale": 72, "press_lift": 2, "press_slow": true}
	var old_trail := []
	for r in range(1, 6):
		MC.fade_lift(old, r)
		old_trail.append(int(old["morale"]))
	_check(old_trail == [72, 71, 71, 70, 70] and not old.has("press_slow") and not old.has("press_lift"),
			"An old save's Philosopher lift fades a point every second round like any other, its flag dropped (%s)" % str(old_trail))
	# Counted from the presser, not the round number: set on an odd round it
	# still takes exactly fade_rounds rounds.
	var odd := {"morale": 70}
	MC.apply_lift(odd, 2, MC.LIST_CAP)
	var odd_trail := []
	for r in range(5, 10):
		MC.fade_lift(odd, r)
		odd_trail.append(int(odd["morale"]))
	_check(odd_trail == [72, 71, 71, 70, 70] and MC.fade_rounds(2) == 4 and not odd.has("press_lift") and not odd.has("press_wait"),
			"A lift takes exactly fade_rounds rounds whichever round it starts (%s)" % str(odd_trail))
	var low := {"morale": 6}
	var moved: int = MC.apply_lift(low, -2, MC.LIST_CAP)
	MC.fade_lift(low, 1)
	MC.fade_lift(low, 2)
	_check(moved == -1 and int(low["morale"]) == 6 and not low.has("press_lift"),
			"At the morale floor only what really moved is kept, so the fade never overshoots (%d)" % int(low["morale"]))
	# The round's fade runs in GameState before the next question forms.
	_press_reset()
	var q: Dictionary = _state.my_list[0]
	MC.apply_lift(q, 2, MC.LIST_CAP)
	_state._fade_press_lifts()
	var held := int(q["morale"])
	_state._fade_press_lifts()
	_check(held == 72 and int(q["morale"]) == 71 and int(q["press_lift"]) == 1,
			"GameState fades every listed player's press lift a point every second round (%d, %d)" % [held, int(q["morale"])])
	# Bug-bash 3 (2026-11-10): a player who leaves your list keeps fading his
	# press lift at the same pace: traded, signed elsewhere or released.
	for way in ["trade", "free_agent"]:
		_press_reset()
		var gone: Dictionary = _state.my_list[0]
		MC.apply_lift(gone, 2, MC.LIST_CAP)
		_state.my_list.erase(gone)
		if way == "trade":
			_state._join("MEL", gone)
		else:
			gone["club"] = ""
			_state.free_agents.append(gone)
		# A move can shift his morale on arrival: the fade runs from there.
		var m0 := int(gone["morale"])
		var gone_trail := []
		for r in range(4):
			_state._fade_press_lifts()
			gone_trail.append(int(gone["morale"]) - m0)
		_check(gone_trail == [0, -1, -1, -2] and not gone.has("press_lift"),
				"A %s's press lift fades after he leaves your list (%s)" % [way, str(gone_trail)])
	# The board's press move fades too, and stacking never passes its cap.
	_press_reset()
	var up: int = _state._press_board(2)
	var more: int = _state._press_board(2)
	_check(up == 2 and more == 1 and _state.board_confidence() == 53 and int(_state.media_memory.get("board_lift", 0)) == 3,
			"Two press answers in a row move the board no further than its cap (%d)" % _state.board_confidence())
	# Director 2026-11-07: the press can move the board further than the match
	# did. A win moves it +2 (ClubLife.after_match); the press lift is not held
	# under that.
	var win_move := int(load("res://scripts/sim/ClubLife.gd").after_match(50, 10)["delta"])
	_check(win_move == 2 and int(_state.media_memory.get("board_lift", 0)) > win_move,
			"The press can move the board further than the match result did (press %d, win %d)" % [
			int(_state.media_memory.get("board_lift", 0)), win_move])
	var board_trail := []
	for r in range(4):
		_state._fade_press_lifts()
		board_trail.append(_state.board_confidence())
	_check(board_trail == [52, 51, 50, 50] and not _state.media_memory.has("board_lift"),
			"The board's press move wears off a point a round, then the trace is gone (%s)" % str(board_trail))
	_press_reset()
	_state.media_conference = {"key": "heavy_loss", "journalist": "muckraker", "round": 8, "question": "q",
			"options": [{"label": "x", "kind": "method"}]}
	var res: Dictionary = _state.resolve_media_conference(0)
	var b_moved: int = _state.board_confidence() - 50
	_check(absi(b_moved) == 2 and int(_state.media_memory.get("board_lift", 0)) == b_moved and int(res["fade_rounds"]) == 2
			and int(res["fade_board"]) == 2 and int(res["fade_morale"]) == 0,
			"An answer's board move is kept to fade, and the outcome says how long (%d, %s rounds)" % [b_moved, str(res.get("fade_rounds"))])


## (a) Standing -2..+2 with each journalist: answers move it, it moves the odds
## 5 a step, fades a step a season, and changes how he asks, never the question.
func _test_press_standing() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_press_reset()
	var conf := _press_conf([55, 101])
	_state.media_conference = conf.duplicate(true)
	var landed: Dictionary = _state.resolve_media_conference(0)
	_check(_state.press_standing("muckraker") == 1 and landed["standing"] == [0, 1],
			"Criticising the players to the Muckraker warms him a step (%s)" % str(landed.get("standing")))
	_state.media_conference = conf.duplicate(true)
	_state.resolve_media_conference(2)
	_check(_state.press_standing("muckraker") == 0, "Backing them to him cools him again")
	_check(MC.standing_after(2, 1) == 2 and MC.standing_after(-2, -1) == -2, "Standing stays inside -2..+2")
	var base: int = MC.chance("method", {"key": "close_game"})
	_check(MC.chance("method", {"key": "close_game", "standing": 2}) == base + 10
			and MC.chance("method", {"key": "close_game", "standing": -1}) == base - 5,
			"Each step of standing moves every answer's odds by 5")
	_state.media_memory = {"standing": {"muckraker": 2, "bogan": -1}, "standing_year": int(_state.season_year) - 1}
	_check(_state.press_standing("muckraker") == 1 and _state.press_standing("bogan") == 0
			and not (_state.media_memory["standing"] as Dictionary).has("bogan")
			and int(_state.media_memory["standing_year"]) == int(_state.season_year),
			"Standing fades a step toward even each new season, once (%s)" % str(_state.media_memory))
	_check(_state.press_standing("muckraker") == 1, "Reading it again the same season does not fade it twice")
	_state.media_memory = {"standing": {"muckraker": 2}, "standing_year": int(_state.season_year) - 3}
	_check(_state.press_standing("muckraker") == 0, "Three seasons away and he is even again")
	_state.media_memory = {"standing": {"muckraker": -1}, "standing_year": int(_state.season_year)}
	_state.media_conference = conf.duplicate(true)
	_state.media_conference["lead"] = MC.lead_in("muckraker", -1)
	var asked: String = _state.press_question_text()
	_check(asked.begins_with(str(MC.LEAD_INS["muckraker"][0])) and asked.ends_with(str(conf["question"]))
			and MC.lead_in("muckraker", 0) == "",
			"A cool journalist adds a lead-in; the question itself is unchanged (%s)" % asked)
	var st_line: String = _state.press_standing_line()
	_check(st_line == "Gary's opinion of you is Wary: every answer is 5% less likely to land well.",
			"The sheet says how he stands with you and what it does to the odds (%s)" % st_line)
	_check(MC.standing_effect("muckraker", 0) == "" and MC.standing_word(0) == "Neutral"
			and [-2, -1, 0, 1, 2].map(func(v): return MC.standing_word(v)) == ["Hostile", "Wary", "Neutral", "Warm", "Firm fan"],
			"His opinion of you reads Hostile / Wary / Neutral / Warm / Firm fan; Neutral adds no line")
	var PS = load("res://scripts/ui/PressScene.gd")
	var rows: Array = PS.press_outcome_rows({"journalist": "muckraker", "standing": [0, 1],
			"fade_rounds": 4, "fade_morale": 4, "fade_board": 2}, "")
	var texts := rows.map(func(r): return str(r[1]))
	_check(texts.has("Gary Haddon's opinion of you: Neutral → Warm") and texts.has("Morale wears off over 4 rounds, the board over 2.")
			and PS.OPINION % MC.standing_word(0) == "Opinion of you: Neutral",
			"The gate and the result say his opinion of you, and both fade lengths when they differ (%s)" % str(texts))
	var one_fade: Array = PS.press_outcome_rows({"fade_rounds": 2, "fade_morale": 2, "fade_board": 0}, "")
	_check(str(one_fade[0][1]) == "It wears off over 2 rounds.", "One fade length is said once (%s)" % str(one_fade))
	_check(_state.press_odds_line(0).contains("Gary warms to you (+5% next time)")
			and _state.press_odds_line(2).contains("Gary cools on you (-5% next time)"),
			"Each answer says how it moves your standing with him, as odds (%s)" % _state.press_odds_line(0))
	_state.media_memory = {"standing": {"muckraker": 2}, "standing_year": int(_state.season_year)}
	_check(not _state.press_odds_line(0).contains("warms to you"),
			"In his corner already, an answer he likes says nothing it cannot do")
	_state.media_conference = {}


## (b) Personality changes what an answer does, shown on the gate.
func _test_press_personas() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var muck: Dictionary = MC.effects("criticise", {"journalist": "muckraker"})
	var plain: Dictionary = MC.effects("criticise", {})
	var muck_m: Dictionary = MC.effects("method", {"journalist": "muckraker"})
	_check(int(muck["a"]["board"]) == int(plain["a"]["board"]) and int(muck["b"]["board"]) == int(plain["b"]["board"])
			and not str(muck["notes"]).contains("Siren")
			and int(muck_m["a"]["board"]) == 2 and int(muck_m["b"]["board"]) == -2 and str(muck_m["notes"]).contains("The Siren gets read upstairs")
			and MC.chance("criticise", {"journalist": "muckraker"}) == MC.chance("criticise", {}) - 10,
			"The Muckraker: a board move that depends on how it lands grows by one, a sure one never does")
	var m_ctx := {"journalist": "muckraker", "facts": {"journalist": "muckraker"}}
	_check(MC.odds_line("criticise", 40, MC.effects("criticise", m_ctx), m_ctx).contains("His headline: 10% less likely"),
			"The Muckraker's odds twist is named on the gate with its size")
	var y_ctx := {"journalist": "sycophant", "facts": {"journalist": "sycophant"}}
	_check(MC.chance("back", {"journalist": "sycophant"}) == MC.chance("back", {}) - 5
			and MC.odds_line("back", 55, MC.effects("back", y_ctx), y_ctx).contains("Praise is expected: 5% less likely"),
			"The Sycophant: backing the players lands 5 worse, and the gate says so")
	var heavy := {"key": "heavy_loss", "young": MC.YOUNG_SIDE, "morale": 50.0, "verdict": "contradicted"}
	var why := ""
	for kind in ["method", "back"]:
		var ctx := {"facts": heavy, "verdict": "contradicted"}
		why += MC.odds_line(kind, 50, MC.effects(kind, ctx), ctx)
	_check(why.contains("Heavy loss: 15% less likely") and why.contains("Young side: 10% more likely")
			and why.contains("The group is flat: 10% more likely") and why.contains("Record says otherwise: 10% less likely"),
			"Every odds twist is named on the gate with its size (%s)" % why)
	var bogan: Dictionary = MC.effects("back_named", {"journalist": "bogan", "name": "Jack"})
	_check(int(bogan["a"]["his"]) == 3 and int(bogan["b"]["his"]) == -2 and str(bogan["notes"]).contains("listen to his show"),
			"The Bogan: a named player's sizes grow by one (%d / %d)" % [int(bogan["a"]["his"]), int(bogan["b"]["his"])])
	var p_line: String = MC.rules_line("philosopher")
	_check(p_line == MC.FADE_NOTE and not (MC.PERSONA["philosopher"] as Dictionary).has("slow")
			and MC.rules_line("sycophant") == MC.FADE_NOTE and MC.rules_line("muckraker").begins_with("The Siren gets read upstairs")
			and MC.rules_line("muckraker").ends_with(MC.FADE_NOTE),
			"The gate says once how long the moves last, the same pace for every journalist (%s)" % p_line)
	# Trimmed (director 2026-11-07): the fade and his personality are said once
	# on the screen, never under each answer, and the line keeps every number.
	var m_line: String = MC.odds_line("criticise", 40, MC.effects("criticise", m_ctx), m_ctx)
	_check(m_line.begins_with("40% resolve tightens, morale +1% · 60% hung out to dry, morale -2% · Board +1% either way")
			and not m_line.contains("wear") and not m_line.contains("Siren"),
			"One answer's line: both outcomes with their odds and sizes, then what moves either way (%s)" % m_line)
	_check(MC.standing_move("stats", "back", "supported") == 1 and MC.standing_move("stats", "back", "contradicted") == -1
			and MC.standing_move("stats", "back", "neutral") == 0 and MC.standing_move("bogan", "method") == -1,
			"The Stats Geek's standing follows the record, the others' their likes")


## (c) A named answer moves one player only.
func _test_press_named() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_press_reset()
	var him: Dictionary = _state.my_list[0]
	var conf: Dictionary = MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 8, "year": int(_state.season_year),
			"named": {"heavy_loss": {"id": str(him["id"]), "name": "Jack Smith"}},
			"result": {"home": "FRE", "away": "CAR", "score": [55, 101]}}, {})
	var opts: Array = conf.get("options", [])
	_check(opts.size() == 4 and str(opts[3]["kind"]) == "criticise_named" and str(opts[3]["player"]) == str(him["id"])
			and str(opts[3]["label"]).contains("Jack Smith"),
			"After a heavy loss a fourth answer names one player (%s)" % str(opts.back() if not opts.is_empty() else {}))
	var close: Dictionary = MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 8,
			"named": {"heavy_loss": {"id": "x", "name": "X"}, "big_win": {"id": "x", "name": "X"}},
			"result": {"home": "FRE", "away": "CAR", "score": [80, 83]}}, {})
	_check((close["options"] as Array).size() == 3, "A close game has no named answer")
	var others := 0
	for p in _state.my_list:
		others += int(p["morale"])
	_state.media_conference = conf.duplicate(true)
	var landed: Dictionary = _state.resolve_media_conference(3)
	var after := 0
	for p in _state.my_list:
		after += int(p["morale"])
	var his_move := int(him["morale"]) - 70
	# Up a point whichever way it lands (director 2026-11-08).
	_check(his_move == 1 and after - others == his_move,
			"Only the named player's morale moves, up a point (%+d, list total %+d)" % [his_move, after - others])
	_check(str(landed["line"]).contains(str(_db.player_display_name(him))), "The outcome line names him (%s)" % str(landed["line"]))


## Calling a player out by name (director 2026-11-08): his morale goes up a
## point whichever way it lands; if he takes it personally his opinion of you
## also falls CALLOUT_OPINION_DROP points, the result says so, and backing him
## by name later gives it back. Skipping the question moves nothing.
func _test_press_opinion() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var PS = load("res://scripts/ui/PressScene.gd")
	_press_reset()
	var him: Dictionary = _state.my_list[0]
	var pid := str(him["id"])
	var key := Trust.player_key(pid)
	var name := str(_db.player_display_name(him))
	var drop: int = MC.CALLOUT_OPINION_DROP
	var call_out: Dictionary = MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 8, "year": int(_state.season_year),
			"named": {"heavy_loss": {"id": pid, "name": name}},
			"result": {"home": "FRE", "away": "CAR", "score": [55, 101]}}, {})
	var at := (call_out["options"] as Array).size() - 1
	_check(str(call_out["options"][at]["kind"]) == "criticise_named", "The heavy loss names him")
	_state.relations.erase(key)
	_state.media_conference = call_out.duplicate(true)
	var gate: String = _state.press_odds_line(at)
	_check(gate.contains("resolve tightens, his morale +1%") and gate.contains(
			"he takes it personally, his morale +1%%, his opinion of you -%d" % drop) and not gate.contains("either way")
			and not gate.contains("+0"),
			"The call-out's gate shows both outcomes with every size (%s)" % gate)
	var seen := {}
	var bad: Array = []
	var took: Dictionary = {}
	var took_news := ""
	for seed in range(1, 41):
		_state.relations.erase(key)
		_state.media_memory = {}
		him["morale"] = 70
		him.erase("press_lift")
		_state.career_seed = seed
		_state.media_conference = call_out.duplicate(true)
		var landed: Dictionary = _state.resolve_media_conference(at)
		var w := str(landed.get("landed", ""))
		seen[w] = true
		var t := Trust.value(_state.relations, key)
		var owed: Array = (_state.media_memory.get("callouts", {}) as Dictionary).get(pid, [])
		var ok := int(him["morale"]) == 71
		if w == "b":
			ok = (ok and t == -drop * Trust.PER_POINT and _state.opinion_of_you(pid) == 50 - drop
					and landed["opinion"] == {"name": name, "from": 50, "to": 50 - drop} and owed == [t])
			took = landed
			took_news = str(_state.news[0].get("text", ""))
		else:
			ok = ok and t == 0 and (landed["opinion"] as Dictionary).is_empty() and owed.is_empty()
		if not ok:
			bad.append("seed %d %s: morale %d, trust %d, %s" % [seed, w, int(him["morale"]), t, str(landed.get("opinion"))])
	_check(seen.has("a") and seen.has("b") and bad.is_empty(),
			"Called out: his morale +1 either way; taking it personally also costs %d of his opinion of you (%s)" % [drop, str(bad)])
	# The result screen and the news say what it did to his opinion of you.
	var rows: Array = PS.press_outcome_rows(took, "")
	var opinion_row := ""
	for r in rows:
		if str(r[0]) == "MediaOutcomeOpinion":
			opinion_row = str(r[1])
	# Last, after "it wears off": his opinion of you never does.
	_check(opinion_row == "%s's opinion of you: 50 → %d/100" % [name, 50 - drop]
			and str(rows[rows.size() - 1][0]) == "MediaOutcomeOpinion",
			"The press result shows his opinion of you moving, on its last line (%s)" % opinion_row)
	_check(took_news.ends_with("%s's opinion of you: 50 → %d/100." % [name, 50 - drop]),
			"The news line says it too (%s)" % took_news)
	# Backing him by name gives it back, whichever way the backing lands.
	var backing: Dictionary = MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 12, "year": int(_state.season_year),
			"named": {"big_win": {"id": pid, "name": name}},
			"result": {"home": "FRE", "away": "CAR", "score": [101, 55]}}, {})
	var bat := (backing["options"] as Array).size() - 1
	_check(str(backing["options"][bat]["kind"]) == "back_named", "The big win can back him by name")
	var owed_now: Dictionary = {pid: [-drop * Trust.PER_POINT]}
	var back_bad: Array = []
	for seed in range(1, 21):
		_state.relations.erase(key)
		Trust.change(_state.relations, key, -drop * Trust.PER_POINT, "You called him out in the press", _state.season_year, "Round 8")
		_state.media_memory = {"callouts": owed_now.duplicate(true)}
		_state.career_seed = seed
		_state.media_conference = backing.duplicate(true)
		var bgate: String = _state.press_odds_line(bat)
		var landed: Dictionary = _state.resolve_media_conference(bat)
		if not (bgate.contains("his opinion of you +%d" % drop) and Trust.value(_state.relations, key) == 0
				and landed["opinion"] == {"name": name, "from": 50 - drop, "to": 50} and not _state.media_memory.has("callouts")):
			back_bad.append("seed %d: %s / %s" % [seed, bgate, str(landed.get("opinion"))])
	_check(back_bad.is_empty(), "Backing him by name cancels the call-out's cost, and the gate says so (%s)" % str(back_bad))
	# Nothing to cancel: backing him moves no opinion and the gate names none.
	_state.relations.erase(key)
	_state.media_memory = {}
	_state.media_conference = backing.duplicate(true)
	var plain: String = _state.press_odds_line(bat)
	var none: Dictionary = _state.resolve_media_conference(bat)
	_check(not plain.contains("opinion of you") and Trust.value(_state.relations, key) == 0
			and (none["opinion"] as Dictionary).is_empty() and not _state.relations.has(key),
			"Backing a player you never called out moves no opinion (%s)" % plain)
	# Skipping the question moves nothing at all.
	_press_reset()
	Trust.change(_state.relations, key, -drop * Trust.PER_POINT, "You called him out in the press", _state.season_year, "Round 8")
	_state.media_memory = {"callouts": {pid: [-drop * Trust.PER_POINT]}}
	var morale := []
	for p in _state.my_list:
		morale.append([int(p["morale"]), p.get("press_lift")])
	var rel: Dictionary = _state.relations.duplicate(true)
	var board_before: int = _state.board_confidence()
	var standing: Dictionary = {}
	for j in MC.JOURNALISTS:
		standing[j] = _state.press_standing(j)
	_state.media_conference = backing.duplicate(true)
	_state.skip_media_conference()
	var morale_after := []
	for p in _state.my_list:
		morale_after.append([int(p["morale"]), p.get("press_lift")])
	var standing_after: Dictionary = {}
	for j in MC.JOURNALISTS:
		standing_after[j] = _state.press_standing(j)
	_check(morale_after == morale and _state.relations == rel and _state.board_confidence() == board_before
			and standing_after == standing and _state.media_memory["callouts"] == {pid: [-drop * Trust.PER_POINT]}
			and _state.media_conference.is_empty(),
			"Skipping the press conference moves no morale, opinion, board or standing")
	_state.media_conference = {}
	_state.relations.erase(key)
	_state.media_memory = {}

## (d) The Stats Geek reads the record: supported lands better and harder,
## contradicted worse and costs the board either way.
func _test_press_record() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_check(MC.record_verdict("back", {"w": 2, "l": 1}) == "early"
			and MC.record_verdict("back", {"w": 7, "l": 2}) == "supported"
			and MC.record_verdict("back", {"w": 2, "l": 7}) == "contradicted"
			and MC.record_verdict("method", {"w": 5, "l": 3, "pct": 100.0, "form": 0.0}) == "neutral"
			and MC.record_verdict("criticise", {"w": 3, "l": 3, "streak": 3, "form": -0.5}) == "supported",
			"The record check reads wins, losses, percentage and form, and stays out under four games")
	var base: int = MC.chance("back", {})
	_check(MC.chance("back", {"verdict": "supported"}) == base + 10 and MC.chance("back", {"verdict": "contradicted"}) == base - 10,
			"A claim the record backs lands 10 better; one it contradicts 10 worse")
	var c: Dictionary = MC.effects("method", {"journalist": "stats", "verdict": "contradicted"})
	var s: Dictionary = MC.effects("criticise", {"journalist": "stats", "verdict": "supported"})
	_check(int(c["a"]["board"]) == 0 and int(c["b"]["board"]) == -2 and str(c["notes"]).contains("Ladder Watch")
			and int(s["a"]["morale"]) == 2,
			"Contradicted costs the board a point both ways; supported adds one to the lead size")
	_check(MC.record_line({"w": 7, "l": 3, "pct": 118.4, "pos": 4, "last": "WWLWW"}) == "Your record: 7-3, 4th, 118%, form WWLWW.",
			"The record is shown as it stands")
	_press_reset()
	_state.media_conference = {"key": "close_game", "journalist": "stats", "options": [{"label": "x", "kind": "back"}]}
	_check(_state.press_verdict("back") == "early" and _state.press_record_line() == str(MC.RECORD_CLAUSE["early"]),
			"Before four games the Stats Geek says it is too early")
	_state.media_conference = {"key": "heavy_loss", "journalist": "muckraker", "options": [{"label": "x", "kind": "back"}]}
	_check(_state.press_verdict("back") == "" and _state.press_record_line() == "", "Only the Stats Geek reads the record")
	_state.media_conference = {}


## (e) The press answer adds to the board's match reason, never replaces it.
func _test_press_board_reason() -> void:
	_press_reset()
	_state.board["why"] = "Beat Carlton by 46."
	_state.media_conference = _press_conf([55, 101]).duplicate(true)
	_state.resolve_media_conference(0)
	var why := str(_state.board["why"])
	_check(why.begins_with("Beat Carlton by 46.") and why.contains("Gary Haddon") and why.contains("confidence"),
			"The board's reason keeps the match and adds what you told the press (%s)" % why)


## (h) Morale after a loss (director 2026-11-07): a press answer can lift a
## player up to just below what a win would have given him, never level with it.
func _test_press_loss_lift() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	var CL = load("res://scripts/sim/ClubLife.gd")
	var gap: int = CL.MATCH_MORALE_WIN - CL.MATCH_MORALE_LOSS
	_check(MC.LOSS_LIFT_CAP == gap - 1 and MC.LOSS_LIFT_CAP == 2,
			"After a loss a press lift stops one below a win's extra morale (%d, gap %d)" % [MC.LOSS_LIFT_CAP, gap])
	var p := {"id": "x", "morale": 70}
	CL.morale_after_match([p], {"x": true}, false)
	var w := {"id": "y", "morale": 70}
	CL.morale_after_match([w], {"y": true}, true)
	_check(int(p["morale"]) == 70 + CL.MATCH_MORALE_LOSS and int(w["morale"]) == 70 + CL.MATCH_MORALE_WIN,
			"A player who played gets +%d for a loss, +%d for a win" % [CL.MATCH_MORALE_LOSS, CL.MATCH_MORALE_WIN])
	for i in range(3):
		MC.apply_lift(p, 3, MC.NAMED_CAP, MC.LOSS_LIFT_CAP)
	_check(int(p["morale"]) < int(w["morale"]) and int(p["morale"]) == int(w["morale"]) - 1,
			"Stacked lifts after a loss stop just below the win (%d vs %d)" % [int(p["morale"]), int(w["morale"])])
	var down := {"morale": 70}
	MC.apply_lift(down, -3, MC.NAMED_CAP, MC.LOSS_LIFT_CAP)
	_check(int(down["morale"]) == 67, "The loss cap only holds lifts; a drop keeps its full size (%d)" % int(down["morale"]))
	# The gate shows the held size: the Bogan's named answer is +3, +2 after a loss.
	var won: Dictionary = MC.effects("back_named", {"journalist": "bogan", "name": "Jack"})
	var lost: Dictionary = MC.effects("back_named", {"journalist": "bogan", "name": "Jack", "lost": true})
	_check(int(won["a"]["his"]) == 3 and int(lost["a"]["his"]) == MC.LOSS_LIFT_CAP and int(lost["b"]["his"]) == int(won["b"]["his"]),
			"The gate shows a lift after a loss held under a win's (%d, was %d)" % [int(lost["a"]["his"]), int(won["a"]["his"])])
	_check(MC.after_loss({"margin": -3}) and not MC.after_loss({"margin": 0}) and MC.after_loss({"key": "heavy_loss"})
			and not MC.after_loss({"key": "big_win"}), "A conference knows whether it followed a loss")
	# Through GameState: an answer after a loss never lifts a player past a win's.
	_press_reset()
	_state.media_conference = _press_conf([55, 101]).duplicate(true)
	_check(int(_state.media_conference.get("margin", 0)) == -46, "The conference keeps the result's margin")
	var before := {}
	for q in _state.my_list:
		before[str(q["id"])] = int(q["morale"])
	_state.resolve_media_conference(2)
	var most := 0
	for q in _state.my_list:
		most = maxi(most, int(q["morale"]) - int(before[str(q["id"])]))
	_check(most <= MC.LOSS_LIFT_CAP, "After a loss no answer lifts a player past %d (%d)" % [MC.LOSS_LIFT_CAP, most])


## Every outcome reads true to the result just played (director 2026-11-12:
## "i won the game, why would the board hear excuses?"): after a win no line
## says excuses or a loss, after a loss none says a win; odds and sizes stay.
func _test_press_result_words() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_press_reset()
	# His case: a debut after a win, the method answer.
	var debut := func(score: Array) -> Dictionary:
		return MC.pick({"club": "FRE", "opponent_name": "Carlton", "round": 8, "year": int(_state.season_year),
				"result": {"home": "FRE", "away": "CAR", "score": score},
				"debut": {"id": "d1", "name": "Sam Lee"}}, {})
	_state.media_conference = debut.call([80, 70])
	var won_line: String = _state.press_odds_line(1)
	var won_chance: int = _state.press_chance(1)
	_check(str(_state.media_conference.get("key", "")) == "debut" and not won_line.contains("excuses")
			and won_line.contains("the board isn't convinced, board -1%"),
			"After a win the method answer's downside is no excuse (%s)" % won_line)
	_state.media_conference = debut.call([70, 80])
	var lost_line: String = _state.press_odds_line(1)
	_check(lost_line.contains("the board hears excuses, board -1%") and _state.press_chance(1) == won_chance,
			"After a loss it still hears excuses, at the same odds (%s)" % lost_line)
	_state.media_conference = {}
	var w: Dictionary = MC.effects("method", {"won": true})
	var l: Dictionary = MC.effects("method", {"lost": true})
	var same := true
	for o in ["a", "b"]:
		for k in ["board", "morale", "his"]:
			same = same and int(w[o][k]) == int(l[o][k])
	_check(same, "A win's words never change an answer's sizes")
	_check(MC.after_win({"margin": 4}) and not MC.after_win({"margin": 0}) and not MC.after_win({"margin": -4})
			and MC.after_win({"key": "big_win"}) and not MC.after_win({"key": "debut"}),
			"A conference knows whether it followed a win")
	# Every question over wins and losses: no outcome or answer in the other result's words.
	var loss_words := ["excuse", "the loss", " lost", "losing", "beat you", "bounce back", "let him down",
			"let us down", "cost us", "fell short"]
	var win_words := ["the win", " won", "winning", "isn't convinced"]
	var bad := []
	var asked := 0
	var who := {"id": "p1", "name": "Jack Smith"}
	for margin in [-60, -45, -20, -10, -3, 3, 10, 20, 45, 60]:
		for extra in [{}, {"debut": {"id": "d1", "name": "Sam Lee"}}, {"star": {"id": "p1", "name": "Jack Smith", "line": "kicked six"}},
				{"milestone": {"id": "p1", "name": "Jack Smith", "games": 100}}, {"young": 6},
				{"injuries": [who]}, {"my_pos": 2, "opp_pos": 16}, {"my_pos": 16, "opp_pos": 2},
				{"losing_run": 3, "winning_run": 4}, {"final": {"label": "semi-final", "status": "alive"}},
				{"final": {"label": "semi-final", "status": "eliminated"}}]:
			var ctx := {"club": "FRE", "opponent_name": "Carlton", "round": 12, "year": 2027,
					"result": {"home": "FRE", "away": "CAR", "score": [70 + maxi(0, margin), 70 + maxi(0, -margin)],
					"goals": [10, 10], "behinds": [10, 10]},
					"named": {"heavy_loss": who, "big_win": who, "young_side": who}}
			ctx.merge(extra)
			var q: Dictionary = MC.pick(ctx, {})
			if q.is_empty():
				continue
			asked += 1
			var words: Array = loss_words if margin > 0 else win_words
			for i in range(q["options"].size()):
				var o: Dictionary = q["options"][i]
				var kind: String = MC.kind_of(o, i)
				var c := {"journalist": str(q["journalist"]), "name": str(o.get("name", "him")),
						"lost": MC.after_loss(q), "won": MC.after_win(q)}
				var fx: Dictionary = MC.effects(kind, c)
				var text := " ".join([MC.odds_line(kind, 50, fx, c), MC.after_line(kind, "a", fx),
						MC.after_line(kind, "b", fx), str(o["label"]) if margin > 0 else ""]).to_lower()
				for word in words:
					if (" " + text).contains(word):
						bad.append("%+d %s: %s" % [margin, q["key"], word])
	_check(asked >= 60 and bad.is_empty(),
			"No press outcome reads against the result (%d questions): %s" % [asked, str(bad)])


## (f) Only a real standout (6 goals or 40 disposals) is a star question.
func _test_press_standout_only() -> void:
	var MC = load("res://scripts/sim/MediaConference.gd")
	_press_reset()
	var ids := []
	for p in _state.my_list:
		if not MC.is_young(float(p.get("age", 30.0))) and ids.size() < 3:
			ids.append(str(p["id"]))
	var make := func(goals: int) -> Dictionary:
		var players := {}
		for i in range(ids.size()):
			players[ids[i]] = {"goals": goals if i == 0 else 1, "disposals": 25 - i * 5, "kicks": 15, "marks": 5, "tackles": 3}
		return {"home": "FRE", "away": "CAR", "score": [80, 70], "goals": [12, 10], "behinds": [8, 10],
				"roster": [ids.map(func(id): return {"id": id}), []], "players": players}
	_state._prepare_media_conference([make.call(3)])
	_check(_state.media_conference.is_empty(),
			"An ordinary 10-point win with no standout asks nothing (%s)" % str(_state.media_conference.get("question", "")))
	_state.media_memory = {"standing": {"bogan": 1}, "standing_year": int(_state.season_year)}
	_state._prepare_media_conference([make.call(6)])
	var opts: Array = _state.media_conference.get("options", [])
	_check(str(_state.media_conference.get("key", "")) == "star" and opts.size() == 4
			and str(opts[3]["kind"]) == "back_named" and str(opts[3]["player"]) == str(ids[0]),
			"Six goals make a star question, with a fourth answer backing him (%s)" % str(_state.media_conference.get("question", "")))
	_check(_state.press_question_text().begins_with(str(MC.LEAD_INS["bogan"][1])),
			"A journalist warm to you asks with his warm lead-in (%s)" % _state.press_question_text())
	_state.media_conference = {}


## An old save (no standing, no press lift, a pending question from before the
## answer kinds) loads, plays and keeps working.
func _test_press_old_save() -> void:
	_press_reset()
	_state.media_memory = {"heavy_loss": 3, "said|big_win": {"year": int(_state.season_year), "option": 1, "opp": "Carlton"}}
	var conf := _press_conf([55, 101])
	for o in conf["options"]:
		(o as Dictionary).erase("kind")
	_state.media_conference = conf
	_check(_state.save_career(), "The old-shaped career saves")
	_state.reset()
	_check(_state.load_career(), "The old-shaped career loads")
	_check(_state.media_conference_pending() and _state.press_standing("muckraker") == 0
			and not _state.my_list[0].has("press_lift"), "An old save loads with every journalist even and no press lift")
	var line: String = _state.press_odds_line(0)
	var landed: Dictionary = _state.resolve_media_conference(0)
	_check(line != "" and str(landed.get("kind", "")) == "criticise" and _state.press_standing("muckraker") == 1,
			"Its pending question plays by place in the list, and standing starts from there (%s)" % str(landed.get("kind", "")))
	_check(_state.save_career() and _state.load_career() and _state.press_standing("muckraker") == 1,
			"The new standing survives a save and reload")
	_state.delete_saved_career()


func _test_player_goal_milestones() -> void:
	var p := {"id": "milestone_test", "name": "Milestone Test", "club": "MEL",
			"career": {"games": 12, "goals": 0, "stints": [], "through": _state.season_year - 1, "unknown": []}}
	var old_season = _state.season
	var old_tally = _state.season_tally
	var old_news = _state.news
	var SeasonScript = load("res://scripts/sim/Season.gd")
	_state.season = SeasonScript.new(["MEL", "CAR"], {"MEL": [p], "CAR": []})
	_state.season_tally = {"milestone_test": {"club": "MEL", "games": 1, "goals": 1, "goals_ha": 1}}
	_state.news = []
	_state._player_milestone_news({"home": "MEL", "away": "CAR",
			"roster": [[{"id": "milestone_test"}], []],
			"players": {"milestone_test": {"goals": 1}}})
	_check(_state.news.size() == 1 and str(_state.news[0].get("text", "")).contains("first AFL goal"),
			"A provable first AFL goal is recorded as a milestone")
	p["career"]["unknown"] = [[2020, 2021]]
	_state.news = []
	_state._player_milestone_news({"home": "MEL", "away": "CAR",
			"roster": [[{"id": "milestone_test"}], []],
			"players": {"milestone_test": {"goals": 1}}})
	_check(_state.news.is_empty(), "Unknown historical seasons never fabricate a first-goal milestone")
	_state.season = old_season
	_state.season_tally = old_tally
	_state.news = old_news

func _test_history_records_are_stored_facts() -> void:
	var old_records = _state.records
	var old_roll = _state.honour_roll
	_state.records = {"highest_score": {"value": 151, "club": "MEL", "opp": "CAR", "year": 2028},
			"biggest_win": {"value": 72, "club": "MEL", "opp": "CAR", "year": 2029}}
	_state.honour_roll = [{"year": 2028, "premier": "COL"}, {"year": 2029, "premier": "MEL"}]
	var lines: Array = _state.history_record_lines()
	_check(lines.size() == 2 and str(lines[0]).contains("151") and str(lines[1]).contains("72"),
			"History surface reads the stored league records")
	var honours: Array = _state.recent_honours(1)
	_check(honours.size() == 1 and int(honours[0]["year"]) == 2029,
			"History surface reads the stored honour roll newest first")
	_state.records = old_records
	_state.honour_roll = old_roll

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")


## Game rules loaded when the test runs, not when this runner compiles (they
## reach autoloads a --script runner can't name yet).
func _rules(name: String):
	return load("res://scripts/sim/%s.gd" % name)
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## A pending press conference opens as its own screen when the hub comes up
## (row 105): skip it so a flow about something else carries on from the hub.
func _past_press() -> void:
	if _router.current() == "press":
		_router.handle_back(true)
		await _settle()
		await _settle()


## These cards have already opened over the hub once (HubScene's card sheet):
## the hub shows them first, with no sheet over them.
func _shown_over_hub() -> void:
	for c in _state.week_events:
		(c as Dictionary)["popped"] = true


## A new card opens over the hub on arrival (director, 2026-11-08): real taps
## on Later close it and the card leads the hub until it is answered; it opens
## once, not on every visit; Back closes it like Later; answered in the sheet,
## it shows what happened and Done closes it.
func _test_event_sheet() -> void:
	_state.reset()
	_state.career_seed = 4402
	_state.replay_seed = 4402
	_state.start_season("FRE", _db.club_list("FRE"))
	var size_before := root.size
	root.size = Vector2i(390, 844)
	_router.stack = ["main"]
	_state.week_events = [_state.story_card("members_open_training")]
	_router.go("hub")
	await _settle()
	var sheet: Control = current_scene.find_child("EventSheet", true, false)
	var later: Button = sheet.find_child("EventLater", true, false) if sheet != null else null
	_check(sheet != null and later != null and sheet.find_child("SheetEvent", true, false) != null
			and bool(_state.week_events[0].get("popped", false)),
			"A new card opens over the hub on its own")
	var later_tap: String = (await Tap.tap(later)) if later != null else "missing"
	await _settle()
	var waiting: Control = current_scene.find_child("WaitingEvents", true, false)
	var week: Control = current_scene.find_child("ThisWeek", true, false)
	_check(later_tap == "" and current_scene.find_child("EventSheet", true, false) == null
			and not bool(_state.week_events[0].get("resolved", false)),
			"A real tap on Later closes the card unanswered (%s)" % later_tap)
	_check(waiting != null and waiting.get_index() == 0 and waiting.find_child("WeekEvent", true, false) != null
			and week != null and week.find_child("WeekEvent", true, false) == null
			and waiting.get_global_rect().position.y < week.get_global_rect().position.y,
			"After Later the card leads the hub, above the week")
	_router.go("hub")
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) == null
			and current_scene.find_child("WaitingEvents", true, false) != null,
			"It opens once: back on the hub it waits first, with no sheet")
	# A second new card opens on arrival; Android Back closes it like Later.
	_state.week_events = [_state.story_card("training_extra_session")]
	_router.go("hub")
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) != null, "Each new card opens on arrival")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("EventSheet", true, false) == null
			and current_scene.find_child("WaitingEvents", true, false) != null
			and not bool(_state.week_events[0].get("resolved", false)),
			"Back closes the card like Later and stays on the hub")
	# Answered in the sheet: what happened shows there, Done closes it, and the
	# answered card sits in the week, not first.
	_state.week_events = [_state.story_card("members_open_training")]
	_router.go("hub")
	await _settle()
	sheet = current_scene.find_child("EventSheet", true, false)
	var answer: Button = sheet.find_child("Event_0", true, false) if sheet != null else null
	var answer_tap: String = (await Tap.tap(answer)) if answer != null else "missing"
	await _settle()
	var done: Button = sheet.find_child("EventDone", true, false) if is_instance_valid(sheet) else null
	var sheet_text := ""
	if is_instance_valid(sheet):
		var out := []
		_texts(sheet, out)
		sheet_text = " | ".join(out)
	_check(answer_tap == "" and bool(_state.week_events[0].get("resolved", false)) and done != null
			and sheet_text.contains(str(_state.week_events[0].get("outcome", "-"))) and sheet.find_child("EventLater", true, false) == null,
			"A real tap on an answer in the sheet answers the card and shows what happened (%s)" % answer_tap)
	var done_tap: String = (await Tap.tap(done)) if done != null else "missing"
	await _settle()
	week = current_scene.find_child("ThisWeek", true, false)
	_check(done_tap == "" and current_scene.find_child("EventSheet", true, false) == null
			and current_scene.find_child("WaitingEvents", true, false) == null
			and week != null and week.find_child("WeekEvent", true, false) != null,
			"Done closes the sheet; the answered card shows in the week (%s)" % done_tap)
	_state.week_events = []
	root.size = size_before


## A Tribunal hearing's result opens over the hub the moment it is decided
## (director, 2026-11-10: "too difficult to tell currently"): won or lost,
## the ban before and after, the cost, our club's colours. Real taps at a
## phone's size: Challenge at Tribunal opens it, Done closes it.
func _test_tribunal_verdict() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	for arm in [["won", 0.0, 1], ["lost", 0.99, 2]]:
		_state.reset()
		_state.career_seed = 4403
		_state.replay_seed = 4403
		_state.start_season("FRE", _db.club_list("FRE"))
		# No week card over the hub: the Tribunal card is what this shows.
		_state.week_events = []
		_state.set_setting("seen_weekly_loop_intro", true)
		var p: Dictionary = _state.my_list[0]
		_state._process_discipline([{"home": "FRE", "away": "MEL", "reports": [{"side": 0,
				"id": str(p["id"]), "name": _db.player_display_name(p), "victim_id": "v1",
				"victim_name": "Victim", "reason": "rough conduct", "outcome": "suspension",
				"weeks": int(arm[2]), "tribunal_roll": float(arm[1]), "appeal_roll": 0.99,
				"challenged": false, "appealed": false}]}])
		_router.stack = ["main"]
		_router.go("hub")
		await _settle()
		var card: Control = current_scene.find_child("TribunalCard", true, false)
		var challenge: Button = null
		if card != null:
			for b in card.find_children("*", "Button", true, false):
				if (b as Button).text == "Challenge at Tribunal":
					challenge = b
		var why: String = (await Tap.tap(challenge)) if challenge != null else "missing"
		await _settle()
		var sheet: Control = current_scene.find_child("TribunalVerdict", true, false)
		var text := ""
		if sheet != null:
			var out := []
			_texts(sheet, out)
			text = " | ".join(out)
		var name := str(_db.player_display_name(p))
		if str(arm[0]) == "won":
			_check(why == "" and sheet != null and text.contains("Challenge won") and text.contains("1 match")
					and text.contains("Cleared") and text.contains("34%") and text.contains("Brownlow: eligible again")
					and text.contains("Risked:") and text.contains("Paid:") and text.contains("Fremantle"),
					"A real tap on Challenge at Tribunal opens the verdict: won, 1 match to cleared, 34%%, the cost (%s; %s)" % [why, text])
		else:
			_check(why == "" and sheet != null and text.contains("Challenge lost") and text.count("2 matches") == 2
					and text.contains("We can still appeal: 10%") and text.contains("Brownlow: ineligible")
					and text.contains("Risked:") and text.contains("Paid:") and text.contains("Fremantle"),
					"A lost challenge opens the verdict: lost, 2 matches before and now, the appeal's odds, the cost (%s; %s)" % [why, text])
		var hearing: Control = sheet.find_child("VerdictHearing", true, false) if sheet != null else null
		_check(hearing != null and hearing.size.y < 40.0 and hearing.size.x > 40.0,
				"The hearing's name sits on one line beside the club (%s)" % (str(hearing.size) if hearing != null else "missing"))
		var who: Node = sheet.find_child("VerdictPlayer", true, false) if sheet != null else null
		var who_text := str(who.get("text")) if who != null else ""
		_check(who_text.contains(name.split(" ")[-1]), "The verdict names the player (%s: %s)" % [name, who_text])
		var done: Button = sheet.find_child("TribunalVerdictDone", true, false) if sheet != null else null
		var done_tap: String = (await Tap.tap(done)) if done != null else "missing"
		await _settle()
		_check(done_tap == "" and current_scene.find_child("TribunalVerdict", true, false) == null
				and _router.current() == "hub",
				"A real tap on Done closes the %s verdict at 390x844 (%s)" % [str(arm[0]), done_tap])
	_state.reset()
	root.size = size_before


func _settle() -> void:
	for i in range(4):
		await process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)


func _screen_text() -> String:
	var out := []
	_texts(current_scene, out)
	return " | ".join(out)


## The sheet's other ways through, by finger: a second new card waits behind
## Later and opens next; See the rule and a name lay over the card and Back
## takes them off one at a time; Back on the round's results brings a new card
## as Continue does; "popped" is kept in the save.
func _test_event_sheet_flows() -> void:
	_state.reset()
	_state.career_seed = 4403
	_state.replay_seed = 4403
	_state.start_season("FRE", _db.club_list("FRE"))
	var size_before := root.size
	root.size = Vector2i(390, 844)
	_router.stack = ["main"]
	_state.media_conference = {}

	# Two new cards: Later on the first opens the second, then the hub.
	_state.week_events = [_state.story_card("members_open_training"), _state.story_card("training_extra_session")]
	_router.go("hub")
	await _settle()
	var later: Button = current_scene.find_child("EventLater", true, false)
	var why: String = (await Tap.tap(later)) if later != null else "missing"
	await _settle()
	var sheet: Control = current_scene.find_child("EventSheet", true, false)
	var shown: Array = []
	if sheet != null:
		_texts(sheet, shown)
	_check(why == "" and sheet != null and bool(_state.week_events[1].get("popped", false))
			and " | ".join(shown).contains(str(_state.week_events[1].get("title", "-"))),
			"Later on one new card opens the next (%s)" % why)
	later = current_scene.find_child("EventLater", true, false)
	why = (await Tap.tap(later)) if later != null else "missing"
	await _settle()
	var waiting: Control = current_scene.find_child("WaitingEvents", true, false)
	_check(why == "" and current_scene.find_child("EventSheet", true, false) == null
			and waiting != null and waiting.find_child("WeekEvent", true, false) != null
			and waiting.find_child("WeekEvent_1", true, false) != null,
			"Later on the last one leaves both waiting first on the hub (%s)" % why)

	# Kept in the save: it opens once across a reload too.
	var kept: bool = _state.save_career() and _state.load_career()
	_check(kept and _state.week_events.size() == 2 and bool(_state.week_events[0].get("popped", false))
			and bool(_state.week_events[1].get("popped", false)), "A card that has opened is still marked after a reload")
	_router.go("hub")
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) == null, "After a reload it waits on the hub, no sheet")

	# See the rule lies over the card; closing it leaves the card open.
	var ruled: Dictionary = _state.story_card("members_open_training")
	ruled["options"][0]["rule"] = "The rule behind this answer."
	_state.week_events = [ruled]
	_router.go("hub")
	await _settle()
	# The card is on the hub under the sheet as well: the sheet's own button.
	var rule_btn: Button = current_scene.find_child("EventSheet", true, false).find_child("EventRule_0", true, false)
	_check(rule_btn != null, "(setup) a card with a rule is on the sheet")
	why = (await Tap.tap(rule_btn)) if rule_btn != null else "missing"
	await _settle()
	var close_rule: Button = current_scene.find_child("RuleClose", true, false)
	_check(why == "" and close_rule != null, "A finger on See the rule opens it over the card (%s)" % why)
	why = (await Tap.tap(close_rule)) if close_rule != null else "missing"
	await _settle()
	_check(why == "" and current_scene.find_child("RuleSheet", true, false) == null
			and current_scene.find_child("EventSheet", true, false) != null,
			"A finger on Close takes off the rule and leaves the card open (%s)" % why)
	rule_btn = current_scene.find_child("EventSheet", true, false).find_child("EventRule_0", true, false)
	why = (await Tap.tap(rule_btn)) if rule_btn != null else "missing"
	await _settle()
	_router.handle_back(true)
	await _settle()
	_check(why == "" and current_scene.find_child("RuleSheet", true, false) == null
			and current_scene.find_child("EventSheet", true, false) != null,
			"Back takes off the rule first, the card stays (%s)" % why)
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) == null and _router.current() == "hub",
			"Back again closes the card")

	# A name in the card opens his profile over it; Back takes the profile off.
	var named: Dictionary = _state.story_card("members_open_training")
	var him: Dictionary = _state.season.lists["FRE"][0]
	named["text"] = "%s wants a word." % _db.player_display_name(him)
	_state.week_events = [named]
	_router.go("hub")
	await _settle()
	sheet = current_scene.find_child("EventSheet", true, false)
	var line: Control = null
	if sheet != null:
		for r in sheet.find_children("*", "RichTextLabel", true, false):
			if (r as RichTextLabel).text.contains("[url="):
				line = r
				break
	_check(line != null, "(setup) the card's line names him")
	var opened := false
	if line != null:
		var x := 4.0
		while x < line.size.x and not opened:
			await Tap.tap_at(line, Vector2(x, 10.0), false)
			await _settle()
			opened = current_scene.get_node_or_null("PlayerProfile") != null
			x += 12.0
	var profile: Control = current_scene.get_node_or_null("PlayerProfile")
	_check(opened and sheet != null and profile.get_index() > sheet.get_index(),
			"A finger on a name opens his profile over the card")
	_router.handle_back(true)
	await _settle()
	_check(current_scene.get_node_or_null("PlayerProfile") == null
			and current_scene.find_child("EventSheet", true, false) != null,
			"Back takes off the profile first, the card stays")
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) == null, "Back again closes the card")

	# Back on the round's results brings a new card, the way Continue does.
	_state.week_events = []
	_router.go("hub")
	await _settle()
	current_scene.call("_show_results", [])
	await _settle()
	_check(current_scene.find_child("RoundResults", true, false) != null, "(setup) the round's results are up")
	_state.week_events = [_state.story_card("members_open_training")]
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("RoundResults", true, false) == null
			and current_scene.find_child("EventSheet", true, false) != null,
			"Back on the results opens a new card, as Continue does")
	_state.week_events = []
	root.size = size_before


## Every card in the deck fits its sheet on a small phone, a phone and a PC
## window: the sheet stays on screen, no answer runs past its edge, and Later
## is in reach.
func _test_event_sheet_fits_every_card() -> void:
	_state.reset()
	_state.career_seed = 4404
	_state.replay_seed = 4404
	_state.start_season("FRE", _db.club_list("FRE"))
	var size_before := root.size
	var him: Dictionary = _state.season.lists["FRE"][0]
	var bad := []
	var shown := 0
	_router.stack = ["main"]
	_state.week_events = []
	_state.media_conference = {}
	for dims in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = dims
		_router.go("hub")
		await _settle()
		var hub: Node = current_scene
		var win := Rect2(Vector2.ZERO, Vector2(dims))
		for t in _rules("StoryDeck").all():
			var player: bool = str((t["subject"] as Dictionary).get("kind", "club")) != "club"
			var card: Dictionary = _state.story_card(str(t["id"]), him if player else {})
			if card.is_empty():
				continue
			_state.week_events = [card]
			hub.call("_open_event_sheet", 0)
			await process_frame
			await process_frame
			var sheet: Control = hub.find_child("EventSheet", true, false)
			var body: Control = sheet.find_child("SheetEvent", true, false)
			var later: Control = sheet.find_child("EventLater", true, false)
			var edge: float = body.get_parent().get_global_rect().end.x + 0.5
			var wrong := ""
			if not win.encloses(later.get_global_rect()):
				wrong = "Later off screen"
			for b in sheet.find_children("Event_*", "Button", true, false):
				if (b as Control).get_global_rect().end.x > edge:
					wrong = "%s runs %.0f past" % [b.name, (b as Control).get_global_rect().end.x - edge]
			if body.get_global_rect().end.x > edge:
				wrong = "body wider than its sheet by %.0f" % (body.get_global_rect().end.x - edge)
			if not win.encloses(sheet.get_global_rect()) or body.get_parent().get_global_rect().end.x > dims.x:
				wrong = "sheet off screen"
			if wrong != "":
				bad.append("%dx%d %s: %s" % [dims.x, dims.y, t["id"], wrong])
			shown += 1
			sheet.free()
	_state.week_events = []
	_check(shown >= 300, "The deck was walked at each size (%d sheets)" % shown)
	_check(bad.is_empty(), "Every card fits its sheet at each size (%d out: %s)" % [bad.size(), str(bad.slice(0, 8))])
	root.size = size_before


## A short sheet is as tall as what it holds, its buttons right under the
## words; a long one fills the screen and scrolls (the director's PC
## playtest, 2026-10-07: the "Your week" sheet was mostly empty, flagged 4-5
## times). Desktop and phone sizes.
func _test_sheets_fit_their_content() -> void:
	var kit = load("res://scripts/ui/UiKit.gd")
	var before := root.size
	for dims in [Vector2i(1280, 720), Vector2i(390, 844)]:
		root.size = dims
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		await process_frame
		var short: Dictionary = kit.modal_box(host, 520.0, 0.0)
		for i in range(3):
			var l: Label = kit.lbl("A short line of help, the kind a first visit shows.", 14, kit.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(short["body"] as VBoxContainer).add_child(l)
		(short["footer"] as VBoxContainer).add_child(kit.btn("Got it", 17, true))
		var long: Dictionary = kit.modal_box(host, 520.0, 0.0)
		for i in range(80):
			(long["body"] as VBoxContainer).add_child(kit.lbl("Line %d" % i, 14, kit.TEXT))
		for i in range(6):
			await process_frame
		var view := host.get_viewport_rect().size
		var sh: Control = short["shell"]
		var lh: Control = long["shell"]
		_check(sh.size.y < view.y * 0.5, "%dx%d: a short sheet is as tall as its words (%d of %d px)" % [dims.x, dims.y, int(sh.size.y), int(view.y)])
		_check(lh.size.y > view.y * 0.8 and lh.size.y <= view.y, "%dx%d: a long sheet fills the screen and scrolls (%d of %d px)" % [dims.x, dims.y, int(lh.size.y), int(view.y)])
		host.queue_free()
		await process_frame
	root.size = before
	await process_frame


# ---------------------------------------------------------------------------
# Sound settings (row 98, T7.O16): moved from matchday so the PR gate runs them
# ---------------------------------------------------------------------------
func _sheet_at(options, sz: Vector2i) -> Array:
	root.size = sz
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.size = Vector2(sz)
	var sheet: Control = options.open(host, true)
	await _settle()
	return [host, sheet]


## Sound is Mute and one Volume slider (row 98); Vibration and Reduced motion
## keep their own Off. Real taps at a phone's size and a PC's, saved with the
## settings. Vibration shows only on a phone.
func _test_game_feel_settings() -> void:
	var before := root.size
	var options = load("res://scripts/ui/OptionsSheet.gd")
	var feel = load("res://scripts/ui/Feel.gd")
	var uk = load("res://scripts/ui/UiKit.gd")
	_check(not _state.sounds_muted() and _state.volume() == 100 and _state.haptics_on() and not _state.reduced_motion(),
			"Sound starts on at full volume, Vibration on, Reduced motion off")
	feel.force_phone = false
	var pc: Array = await _sheet_at(options, Vector2i(1280, 720))
	_check(pc[1].find_child("SettingsMuteSounds_on", true, false) != null
			and pc[1].find_child("SettingsVolume", true, false) is HSlider
			and pc[1].find_child("SettingsReducedMotion_on", true, false) != null,
			"Settings has Mute, a Volume slider and Reduced motion on a PC")
	for gone in ["SettingsMusic", "SettingsCrowd", "SettingsButtonSounds"]:
		_check(pc[1].find_child(gone, true, false) == null, "No %s row: one Volume does it" % gone)
	_check(pc[1].find_child("SettingsVibration_off", true, false) == null,
			"No Vibration row on a PC, which has nothing to buzz")
	pc[0].queue_free()
	await _settle()
	feel.force_phone = true
	var master := AudioServer.get_bus_index("Master")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		var hs: Array = await _sheet_at(options, sz)
		var sheet: Control = hs[1]
		for pair in [["SettingsMuteSounds_on", "Mute On"], ["SettingsVibration_off", "Vibration Off"],
				["SettingsReducedMotion_on", "Reduced motion On"]]:
			var b: Button = sheet.find_child(str(pair[0]), true, false)
			var why: String = await Tap.tap(b) if b != null else "missing"
			_check(why == "", "%s takes a real tap (%s: %s)" % [pair[1], tag, why])
			await _settle()
		# A finger a quarter of the way along the slider sets 25%.
		var vol: HSlider = sheet.find_child("SettingsVolume", true, false)
		var why_v: String = await Tap.tap_at(vol, _slider_spot(vol, 0.25)) if vol != null else "missing"
		await _settle()
		var shown: Label = sheet.find_child("SettingsVolumeValue", true, false)
		_check(why_v == "" and _state.volume() == 25 and shown != null and shown.text == "25%",
				"A tap a quarter along Volume sets 25%% and says so (%s: %s, %d, %s)"
				% [tag, why_v, _state.volume(), shown.text if shown != null else "no label"])
		_check(_state.sounds_muted() and AudioServer.is_bus_mute(master)
				and is_equal_approx(AudioServer.get_bus_volume_db(master), linear_to_db(0.25))
				and not _state.haptics_on() and _state.reduced_motion()
				and not feel.haptics and feel.reduced and not uk.motion_on(),
				"The taps mute every sound, set Master to 25%%, stop the buzz and still the screen (%s)" % tag)
		var cfg := ConfigFile.new()
		_check(cfg.load(_state.settings_path) == OK and cfg.get_value("ui", "mute_sounds", false) == true
				and int(cfg.get_value("ui", "volume", -1)) == 25
				and cfg.get_value("ui", "haptics", true) == false and cfg.get_value("ui", "reduced_motion", false) == true,
				"All four are saved with the settings (%s)" % tag)
		for pair in [["SettingsMuteSounds_off", "Mute Off"], ["SettingsVibration_on", "Vibration On"],
				["SettingsReducedMotion_off", "Reduced motion Off"]]:
			var b: Button = sheet.find_child(str(pair[0]), true, false)
			var why: String = await Tap.tap(b) if b != null else "missing"
			_check(why == "", "%s takes a real tap (%s: %s)" % [pair[1], tag, why])
			await _settle()
		why_v = await Tap.tap_at(vol, _slider_spot(vol, 1.0)) if vol != null else "missing"
		await _settle()
		_check(why_v == "" and _state.volume() == 100 and not _state.sounds_muted() and not AudioServer.is_bus_mute(master)
				and is_equal_approx(AudioServer.get_bus_volume_db(master), 0.0)
				and _state.haptics_on() and not _state.reduced_motion(),
				"And back: sound on at full, buzz and motion back (%s: %s)" % [tag, why_v])
		hs[0].queue_free()
		await _settle()
	feel.force_phone = false
	root.size = before
	await _settle()


## Where along a slider a finger sets `ratio`: Godot centres the thumb on the
## touch, so the ends sit half a thumb in from the edges.
func _slider_spot(s: HSlider, ratio: float) -> Vector2:
	var thumb := float(s.get_theme_icon("grabber").get_width())
	return Vector2(thumb / 2.0 + ratio * (s.size.x - thumb), s.size.y / 2.0)


## Report a problem (T3.R43): one real tap in Settings copies a plain note -
## build, seed, round, screen, the last twenty match-feed lines - says
## "Copied", and sends nothing.
func _test_report_a_problem() -> void:
	var before := root.size
	var options = load("res://scripts/ui/OptionsSheet.gd")
	var report = load("res://scripts/core/ProblemReport.gd")
	report.start_feed("Round 3, Carlton v Collingwood")
	for i in range(25):
		report.note_feed("Q1 %d'  Line %d" % [i, i])
	var lines: PackedStringArray = report.text("hub").split("\n")
	_check(lines[0] == "Aussie Rules Dynasties: problem report" and lines[1].begins_with("What happened:"),
			"The note opens with its title and a line for what happened")
	var want := ["Build: %s" % BuildInfo.label(), "Seed: ", "Round: ", "Screen: hub",
			"Match feed (last 20 lines, Round 3, Carlton v Collingwood):"]
	var at := 3
	for w in want:
		_check(lines[at].begins_with(str(w)), "Note line %d starts '%s' (%s)" % [at, w, lines[at]])
		at += 1
	_check(lines.size() == at + 20 + 1 and lines[at] == "Q1 5'  Line 5" and lines[at + 19] == "Q1 24'  Line 24",
			"The last twenty feed lines, oldest first, then nothing more (%d lines)" % lines.size())
	report.start_feed("x")
	_check(report.text("").contains("Match feed: no match watched this session")
			and report.text("").contains("Screen: main menu"),
			"With no match watched it says so, and an empty screen reads as the main menu")
	report.start_feed("Round 3, Carlton v Collingwood")
	report.note_feed("Q2 4'  A line")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		var hs: Array = await _sheet_at(options, sz)
		var sheet: Control = hs[1]
		var b: Button = sheet.find_child("ReportProblem", true, false)
		_check(b != null and b.size.y >= 44.0 and b.text == "Report a problem",
				"Settings has a thumb-sized Report a problem (%s)" % tag)
		if b == null:
			hs[0].queue_free()
			continue
		var sc := b.get_parent()
		while sc != null and not sc is ScrollContainer:
			sc = sc.get_parent()
		if sc != null:
			(sc as ScrollContainer).ensure_control_visible(b)
		await _settle()
		DisplayServer.clipboard_set("")
		var why: String = await Tap.tap(b)
		await _settle()
		var toast: Control = sheet.find_child("Toast", true, false)
		_check(why == "" and toast != null and toast.visible
				and (toast.find_children("*", "Label", true, false)[0] as Label).text == "Copied",
				"A real tap says Copied (%s: %s)" % [tag, why])
		if DisplayServer.get_name() != "headless":
			_check(DisplayServer.clipboard_get().contains("Q2 4'  A line"),
					"The clipboard holds the note (%s)" % tag)
		hs[0].queue_free()
		await _settle()
	root.size = before
	await _settle()


## An old settings file (a level each for music, crowd and button sounds)
## comes over as Mute and Volume, once, and the old keys go.
func _test_old_sound_levels_carry_over() -> void:
	var keep: String = _state.settings_path
	_state.settings_path = "user://test_old_sound.cfg"
	var cases := [
		[{"music_level": "normal", "crowd_level": "quiet", "button_sounds": "off"}, false, 100, false,
				"the loudest one he still heard sets Volume"],
		[{"music_level": "quiet", "crowd_level": "quiet", "button_sounds": "quiet"}, false, 30, false,
				"all quiet is 30% (-10 dB)"],
		[{"music_level": "off", "crowd_level": "off", "button_sounds": "off"}, false, 100, true,
				"all off is Mute on, Volume full for later"],
		[{"crowd_level": "quiet"}, true, 100, true,
				"Mute already on stays on; button sounds he never changed were at normal"],
		[{"crowd_level": "nonsense"}, false, 100, false, "a level it doesn't know counts as normal"],
		[{"crowd_level": "off"}, false, 100, false,
				"Crowd alone off keeps the button sounds he never changed: Mute stays off"],
		[{"button_sounds": "off"}, false, 100, false,
				"Button sounds alone off keeps the crowd he never changed: Mute stays off"],
		[{"crowd_level": "off", "button_sounds": "off"}, false, 100, true,
				"Crowd and button sounds off is silence (no music ever played): Mute on"],
		[{"music_level": "quiet"}, false, 100, false,
				"Music alone quiet leaves crowd and button sounds at normal"],
	]
	_check(cases.size() == 9, "Nine old settings files to carry over")
	for c in cases:
		var cfg := ConfigFile.new()
		for k in c[0]:
			cfg.set_value("ui", k, c[0][k])
		cfg.set_value("ui", "mute_sounds", c[1])
		cfg.save(_state.settings_path)
		_state._carry_old_sound_levels(cfg)
		var back := ConfigFile.new()
		back.load(_state.settings_path)
		var left := false
		for k in ["music_level", "crowd_level", "button_sounds"]:
			left = left or back.has_section_key("ui", k)
		_check(_state.volume() == int(c[2]) and _state.sounds_muted() == bool(c[3]) and not left,
				"Old settings: %s (Volume %d, Mute %s)" % [c[4], _state.volume(), str(_state.sounds_muted())])
	# A file with nothing old is left alone.
	var plain := ConfigFile.new()
	plain.set_value("ui", "volume", 55)
	plain.save(_state.settings_path)
	_state._carry_old_sound_levels(plain)
	_check(_state.volume() == 55, "A new settings file is left as it is")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_state.settings_path))
	_state.settings_path = keep
	_state.set_sounds_muted(false)
	_state.set_volume(100)


func _run() -> void:
	_t("_test_rivalry_catalogue")
	await process_frame
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_t("_test_history_records_are_stored_facts")
	await _t("_test_sheets_fit_their_content")
	_t("_test_player_goal_milestones")
	_t("_test_media_conference_rules")
	# Never touch a real career save or settings file from a test run.
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.replay_seed = SUITE_SEED
	_state.delete_saved_career()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	# Return visits: the first-visit intros (FirstVisitIntro.gd) have their own suite.
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		_state.set_setting("seen_%s_intro" % key, true)
	_t("_test_press_rolls")
	_t("_test_press_caps_and_fade")
	_t("_test_press_loss_lift")
	_t("_test_press_result_words")
	_t("_test_press_standing")
	_t("_test_press_personas")
	_t("_test_press_named")
	_t("_test_press_opinion")
	_t("_test_press_record")
	_t("_test_press_board_reason")
	_t("_test_press_standout_only")
	_t("_test_press_old_save")
	await _t("_test_game_feel_settings")
	_t("_test_old_sound_levels_carry_over")
	await _t("_test_report_a_problem")

	await _t("_test_menu_and_career")
	await _t("_test_season_awards")
	await _t("_test_back_arrow_taps")
	await _t("_test_finals_card_taps")
	await _t("_test_event_sheet")
	await _t("_test_tribunal_verdict")
	await _t("_test_event_sheet_flows")
	await _t("_test_event_sheet_fits_every_card")
	await _t("_test_sacked_job_choice_taps")
	await _t("_test_rival_letter_taps")
	await _t("_test_sim_asks_only_before_your_match")
	await _t("_test_skip_long_press")
	await _t("_test_skip_hold_wide")
	await _t("_test_skip_season")
	await _t("_test_skip_home_away")
	await _t("_test_skip_home_away_kids")
	await _t("_test_skip_orders")
	await _t("_test_list_tabs_kept")
	await _t("_test_remembered")
	await _t("_test_list_problem_and_ask_around")
	await _t("_test_ask_around_red_club_ink")
	await _t("_test_ask_price_tap")
	await _t("_test_names_fit")
	_state.delete_saved_career()
	await _t("_test_new_career_keeps_the_save")
	await _t("_test_new_career_canberra_choice")
	await _t("_test_new_career_forged_row_redraft_only")
	await _t("_test_new_career_challenge_taps")
	await _t("_test_canberra_2030_warning")
	await _t("_test_every_start_reaches_interview")
	await _t("_test_year_step_taps")
	await _t("_test_year_step_new_clubs")
	await _t("_test_pc_hub_and_list_layout")
	for sz in [Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		await _t("_test_hub_ladder_fills_right", [sz])
	await _t("_test_list_shape_fits_phones")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _t("_test_list_words_fit", [sz])
	await _t("_test_restore_earlier_save_tap")
	await _t("_test_top_up_sheet_taps")
	print(Ran.line("Career UI", self))
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


## The menu, a new career and the screens a coach meets, in order (the checks written in _run).
func _test_menu_and_career() -> void:
	_check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)),
			"Android back does not quit the app by default")

	# --- a fresh install: no Continue button --------------------------------
	_state.reset()
	_router.to_main_menu(false)
	await _settle()
	_check(current_scene.find_child("ContinueCareer", true, false) == null,
			"No Continue Career without a save")

	# --- the menu is the title and a few actions, no setup -------------------
	_check(current_scene.find_child("BoardPatience_ruthless", true, false) == null,
			"The menu itself carries no setup controls")
	_check(not _screen_text().contains("players ·") and not _screen_text().contains("Quit"),
			"No data line or Quit on the menu (the button is Exit game)")
	# Exit game (director, 2026-10-12): on desktop, a real click saves and quits.
	var size_pre := root.size
	root.size = Vector2i(1280, 720)   # a desktop window, so the tap lands on screen
	await _settle()
	var exit_btn: Button = current_scene.find_child("ExitGame", true, false)
	_check(exit_btn != null and exit_btn.text == "Exit game", "The menu has an Exit game button on desktop")
	var quits := [0]
	_router.quit_hook = func() -> void: quits[0] += 1
	_state.mark_dirty()
	var exit_tap: String = await Tap.tap(exit_btn) if exit_btn != null else "missing"
	_check(exit_tap == "" and quits[0] == 1, "A real click on Exit game leaves the game once (%s, %d)" % [exit_tap, quits[0]])
	_router.handle_back(false)
	_check(quits[0] == 1, "Escape on the menu still does not quit")
	_router.quit_hook = Callable()
	root.size = size_pre
	_check(exit_btn != null and exit_btn.custom_minimum_size.y >= 48.0
			and exit_btn.get_parent().get_child(exit_btn.get_parent().get_child_count() - 1) == exit_btn,
			"Exit game is last in the How to play / Settings row, at least 48 px tall")
	# The gate is the platform, not the window width: a phone has no Exit game,
	# a narrow desktop window still has it.
	var sl = load("res://scripts/core/ScreenLayout.gd")
	var wide := root.size
	root.size = Vector2i(390, 844)
	_router.to_main_menu(false)
	await _settle()
	var narrow_has: bool = current_scene.find_child("ExitGame", true, false) != null
	sl.force_web_phone = true
	_router.to_main_menu(false)
	await _settle()
	var phone_has: bool = current_scene.find_child("ExitGame", true, false) != null
	sl.force_web_phone = false
	root.size = wide
	_router.to_main_menu(false)
	await _settle()
	_check(sl.desktop_for(["windows"]) and sl.desktop_for(["linuxbsd"]) and sl.desktop_for(["macos"])
			and not sl.desktop_for(["web"]) and not sl.desktop_for(["android"]) and not sl.desktop_for(["ios"])
			and not sl.desktop_for(["web", "wasm32"]),
			"Exit game, Display and Alt+Enter follow is_desktop: false on a web export, Android and iOS")
	_check(narrow_has and not phone_has, "Exit game: shown in a narrow desktop window, hidden on a phone (is_desktop false)")
	# Fit to the screen (director, 2026-10-12): a desktop opens fullscreen unless
	# the player chose Window, in which case the window opens maximised.
	var screen_layout = load("res://scripts/core/ScreenLayout.gd")
	var cfg_default := ConfigFile.new()
	var cfg_window := ConfigFile.new()
	cfg_window.set_value("ui", "fullscreen", false)
	_check(screen_layout.start_mode(cfg_default) == DisplayServer.WINDOW_MODE_FULLSCREEN
			and screen_layout.start_mode(cfg_window) == DisplayServer.WINDOW_MODE_MAXIMIZED,
			"The window mode on start is fullscreen, or maximised when Window was chosen")
	var was_full: bool = _state.fullscreen()
	var alt_enter := InputEventKey.new()
	alt_enter.keycode = KEY_ENTER
	alt_enter.alt_pressed = true
	alt_enter.pressed = true
	root.get_node("ScreenLayout")._input(alt_enter)
	_check(_state.fullscreen() == (not was_full), "Alt+Enter switches between fullscreen and window")
	root.get_node("ScreenLayout")._input(alt_enter)
	_check(_state.fullscreen() == was_full, "and back again")
	_check(current_scene.find_child("MenuHelp", true, false) != null
			and current_scene.find_child("MenuSettings", true, false) != null,
			"How to play and Settings are on the menu")
	var tagline: Label = current_scene.find_child("Tagline", true, false)
	_check(tagline != null and tagline.text == "Build your dynasty.",
			"The minimal menu uses the approved tagline")

	# --- the offline promise and the browser's storage line (P-70, P-71) -----------
	var promise: Label = current_scene.find_child("OfflinePromise", true, false)
	_check(promise != null and promise.text == "Plays offline. No ads, no account.\nYour career stays on this device.",
			"The menu prints the offline promise, saying the career stays on this device")
	var main_script = load("res://scripts/ui/Main.gd")
	_check(main_script.promise_text(true).ends_with("Your career stays in this browser.")
			and main_script.promise_text(false).ends_with("Your career stays on this device.")
			and not main_script.promise_text(true).contains("phone")
			and not main_script.promise_text(false).contains("phone"),
			"The promise names the browser on the web and the device elsewhere, never a phone")
	_check(promise != null and promise.visible and promise.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"The promise is on screen as two deliberate lines")
	_check(not WebStorage.should_ask(false, false) and WebStorage.should_ask(true, false)
			and not WebStorage.should_ask(true, true),
			"The browser is asked to keep the save only on the web, and only until it has answered")
	_check(WebStorage.is_final("granted") and WebStorage.is_final("refused")
			and not WebStorage.is_final("pending") and not WebStorage.is_final(""),
			"A pending or empty answer keeps the question open")
	_check(WebStorage.notice_due("refused", false) and not WebStorage.notice_due("refused", true)
			and not WebStorage.notice_due("granted", false) and not WebStorage.notice_due("unsupported", false),
			"The line is due only when the browser refused and it has not been shown before")
	_check(current_scene.find_child("StorageNotice", true, false) == null,
			"No storage line on a desktop or phone menu, nor before the browser answers")
	_state.set_setting(WebStorage.SHOWN_KEY, false)
	current_scene.call("_on_storage_answer", "granted")
	await _settle()
	_check(current_scene.find_child("StorageNotice", true, false) == null,
			"A granted request shows no line")
	current_scene.call("_on_storage_answer", "refused")
	await _settle()
	var notice: Label = current_scene.find_child("StorageNotice", true, false)
	_check(notice != null and notice.text == "Your browser may clear this save when space is short."
			and bool(_state.get_setting(WebStorage.SHOWN_KEY, false)),
			"A refusal shows the one plain line and remembers it was shown")
	_router.to_main_menu(false)
	await _settle()
	current_scene.call("_on_storage_answer", "refused")
	await _settle()
	_check(current_scene.find_child("StorageNotice", true, false) == null,
			"The line is not shown again on a later visit")
	# The Android save backup preset (user_data_backup/allow=true) is a static lint: tools/lint/boundaries.py.

	# --- settings: appearance and player names apply at once -----------------
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	var light_setting: Button = current_scene.find_child("SettingsAppearance_light", true, false)
	var dark_setting: Button = current_scene.find_child("SettingsAppearance_dark", true, false)
	_check(light_setting != null and dark_setting != null, "Settings offers Dark and Light appearance")
	if light_setting != null:
		light_setting.emit_signal("pressed")
		await _settle()
	var kit = load("res://scripts/ui/UiKit.gd")
	_check(_state.appearance() == "light" and kit.appearance() == "light"
			and kit.BG.r > 0.8 and _router.current() == "main",
			"Light appearance applies immediately and rebuilds the current screen")
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	dark_setting = current_scene.find_child("SettingsAppearance_dark", true, false)
	if dark_setting != null:
		dark_setting.emit_signal("pressed")
		await _settle()
	_check(_state.appearance() == "dark" and kit.appearance() == "dark"
			and kit.BG.r < 0.2, "Dark appearance restores the original palette")
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	_check(current_scene.find_child("SettingsNames_real", true, false) == null
			and current_scene.find_child("SettingsNames_generated", true, false) == null
			and not _screen_text().contains("Player names"),
			"Settings has no player names choice: real names are the only names")
	var mute_on: Button = current_scene.find_child("SettingsMuteSounds_on", true, false)
	var mute_off: Button = current_scene.find_child("SettingsMuteSounds_off", true, false)
	_check(mute_on != null and mute_off != null, "Settings offers Mute")
	if mute_on != null:
		mute_on.emit_signal("pressed")
	var master_bus := AudioServer.get_bus_index("Master")
	_check(_state.sounds_muted()
			and (master_bus < 0 or AudioServer.is_bus_mute(master_bus)),
			"Mute immediately mutes the Master audio bus")
	if mute_off != null:
		mute_off.emit_signal("pressed")
	_check(not _state.sounds_muted()
			and (master_bus < 0 or not AudioServer.is_bus_mute(master_bus)),
			"Sounds can be switched back on")
	_check(OS.has_feature("web") or current_scene.find_child("QuitGame", true, false) != null,
			"Quit lives in Settings")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("Settings", true, false) == null,
			"Back closes Settings")

	# --- Club Forge: make a player, bring him into a career ------------------
	_state.set_forge_player({})
	_state.set_forge_club({})
	var size_before := root.size
	root.size = Vector2i(390, 844)
	await _settle()
	var forge_btn: Button = current_scene.find_child("ClubForge", true, false)
	_check(forge_btn != null, "The main menu has Club Forge")
	var forge_tap: String = await Tap.tap(forge_btn) if forge_btn != null else "missing"
	await _settle()
	_check(forge_tap == "" and _router.current() == "forge", "A tap opens Club Forge (%s)" % forge_tap)
	# On a PC window, your player and your club sit side by side, and a real
	# tap on Create a club opens its form (director: no full-width bars on PC).
	root.size = Vector2i(1280, 720)
	await _settle()
	var mk_p: Control = current_scene.find_child("ForgeCreatePlayer", true, false)
	var mk_c: Control = current_scene.find_child("ForgeCreateClub", true, false)
	_check(mk_p != null and mk_c != null and mk_p.get_global_rect().end.x <= mk_c.get_global_rect().position.x
			and mk_c.size.x <= root.size.x * 0.55
			and absf(mk_p.get_global_rect().position.y - mk_c.get_global_rect().position.y) < 1.0,
			"PC: the Forge puts your player and your club side by side, level")
	var club_tap: String = await Tap.tap(mk_c) if mk_c != null else "missing"
	await _settle()
	_check(club_tap == "" and current_scene.find_child("ForgeSaveClub", true, false) != null,
			"PC: a tap on Create a club opens its form (%s)" % club_tap)
	_router.handle_back(false)
	await _settle()
	root.size = Vector2i(390, 844)
	await _settle()
	_press("ForgeCreatePlayer")
	await _settle()
	# T8.Q12: one weakness is compulsory, a second optional, never a third.
	var save_b: Button = current_scene.find_child("ForgeSavePlayer", true, false)
	_check(save_b != null and save_b.disabled and current_scene.find_child("ForgeNeedWeakness", true, false) != null,
			"Save is blocked, and says why, until he has a weakness")
	_press("ForgeWeakness_pressure")
	await _settle()
	save_b = current_scene.find_child("ForgeSavePlayer", true, false)
	_check(save_b != null and not save_b.disabled and current_scene.find_child("ForgeNeedWeakness", true, false) == null,
			"One weakness unblocks Save")
	_press("ForgeWeakness_kicking")
	await _settle()
	_press("ForgeWeakness_marking")
	await _settle()
	_check(_forge_weaknesses() == 2, "A third weakness can't be picked (%d)" % _forge_weaknesses())
	# Ruckwork leaves with the ruck: change the position (or the second one)
	# and a hidden Ruckwork pick no longer fills a slot.
	_press("ForgeWeakness_kicking")
	await _settle()
	_press("ForgeRole_RUCK")
	await _settle()
	_press("ForgeWeakness_ruckwork")
	await _settle()
	var had_ruck := (current_scene.get("_spec")["weaknesses"] as Array).has("ruckwork")
	_press("ForgeRole_MID")
	await _settle()
	var role_drop := not (current_scene.get("_spec")["weaknesses"] as Array).has("ruckwork")
	_press("ForgeRole2_RUCK")
	await _settle()
	_press("ForgeWeakness_ruckwork")
	await _settle()
	var had_ruck2 := (current_scene.get("_spec")["weaknesses"] as Array).has("ruckwork")
	_press("ForgeRole2_")
	await _settle()
	var role2_drop := not (current_scene.get("_spec")["weaknesses"] as Array).has("ruckwork")
	_check(had_ruck and role_drop and had_ruck2 and role2_drop and _forge_weaknesses() == 1
			and current_scene.find_child("ForgeWeakness_ruckwork", true, false) == null,
			"Ruckwork is dropped when neither position is a ruck (%s)" % str(current_scene.get("_spec")["weaknesses"]))
	_press("ForgeWeakness_kicking")
	await _settle()
	_press("ForgeSavePlayer")
	await _settle()
	var problem: Label = current_scene.find_child("ForgeProblem", true, false)
	_check(problem != null and problem.visible and _state.forge_player().is_empty(),
			"A player without a name isn't saved, and the screen says why")
	_type("ForgeFirst", "Gabe")
	_type("ForgeLast", "Forge")
	_press("ForgeRole_FWD")
	await _settle()
	_press("ForgeStyle_small_forward")
	_press("ForgeStrength_goalkicking")
	await _settle()
	_press("ForgeHair_mullet")
	_press("ForgeFoot_L")
	_press("ForgeSavePlayer")
	await _settle()
	var fp: Dictionary = _state.forge_player()
	_check(str(fp.get("last", "")) == "Forge" and str(fp.get("role", "")) == "FWD" and str(fp.get("style", "")) == "small_forward"
			and (fp.get("strengths", []) as Array) == ["goalkicking"] and str(fp["look"]["hair_style"]) == "mullet"
			and str(fp.get("foot", "")) == "L",
			"The Forge saves the player as made")
	_check(current_scene.find_child("ForgePlayerName", true, false) != null, "The Forge shows your player")
	var small := []
	for b in current_scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			small.append(b.name)
	_check(small.is_empty(), "Every Forge button is thumb-sized (%s)" % str(small))

	# Create a club: a refusal, a place's name and tradition, a save.
	_press("ForgeCreateClub")
	await _settle()
	_press("ForgeSaveClub")
	await _settle()
	problem = current_scene.find_child("ForgeProblem", true, false)
	_check(problem != null and problem.visible and _state.forge_club().is_empty(),
			"A club without a name isn't saved, and the screen says why")
	_choose("ForgePlace", "port-melbourne")
	await _settle()
	var club_name: LineEdit = current_scene.find_child("ForgeClubName", true, false)
	var club_code: LineEdit = current_scene.find_child("ForgeClubCode", true, false)
	_check(club_name != null and club_name.text == "Port Melbourne" and club_code != null and club_code.text == "PM",
			"Picking a place fills in the club's name and an abbreviation")
	# Phone (390 px): Save club sits under the club's name, inside the name
	# column, so "Port Melbourne" keeps the strip's width and stays one line.
	var pv_name: Label = current_scene.find_child("ForgePreviewName", true, false)
	var save_club: Control = current_scene.find_child("ForgeSaveClub", true, false)
	var name_col: Control = pv_name.get_parent() if pv_name != null else null
	var save_in_col: bool = save_club != null and name_col != null and save_club.get_parent() == name_col \
			and name_col.get_global_rect().grow(0.5).encloses(save_club.get_global_rect())
	_check(root.size.x == 390 and save_in_col
			and save_club.get_global_rect().position.y >= pv_name.get_global_rect().end.y - 0.5,
			"Phone: Save club sits inside the name column, under the club's name")
	_check(pv_name != null and pv_name.text == "Port Melbourne" and pv_name.get_line_count() == 1,
			"Phone: the club's name \"Port Melbourne\" is one line (%d)" % (pv_name.get_line_count() if pv_name != null else -1))
	_type("ForgeClubNickname", "Borough")
	_type("ForgeClubCode", "pmb")
	_check(club_code != null and club_code.text == "PMB", "The abbreviation is written in capitals")
	# The director's flow (2026-10-07): the design first, then pick a colour
	# and click the part of the guernsey to paint.
	_press("ForgeDesign_hoops")
	await _settle()
	_check(current_scene.find_child("ForgeSlot_primary", true, false) == null
			and current_scene.find_child("ForgeBase_p", true, false) == null,
			"No colour slots or guernsey/pattern rows: you paint the guernsey")
	_press("ForgePart_body")
	await _settle()
	var problem_l: Label = current_scene.find_child("ForgeProblem", true, false)
	_check(problem_l != null and problem_l.visible, "Clicking the guernsey before picking a colour says what to do")
	for c in [["body", "green", "#1E6B3A"], ["body", "red", "#C8102E"], ["pattern", "gold", "#F2B231"],
			["pattern", "blue", "#1F4FA8"], ["trim", "white", "#F5F5F5"], ["trim", "gold", "#F2B231"]]:
		_press("ForgeColour_" + str(c[1]))
		await _settle()
		_press("ForgePart_" + str(c[0]))
		await _settle()
		var key: String = {"body": "primary", "pattern": "secondary", "trim": "accent"}[c[0]]
		var preview: Control = current_scene.find_child("ForgePreview", true, false)
		_check(str(current_scene.get("_club")[key]).to_upper() == str(c[2]) and preview != null
				and str(preview.get("design")) == "hoops",
				"Painting the %s %s works again and again on the same design" % [c[0], c[1]])
	var preview_now: Control = current_scene.find_child("ForgePreview", true, false)
	_check(preview_now != null and (preview_now.get("primary") as Color).is_equal_approx(Color.html("#C8102E"))
			and (preview_now.get("secondary") as Color).is_equal_approx(Color.html("#1F4FA8"))
			and (preview_now.get("accent") as Color).is_equal_approx(Color.html("#F2B231")),
			"The guernsey wears what was painted: red, blue hoops, gold trim")
	_check(_screen_text().contains("Main colour") and _screen_text().contains("Pattern colour")
			and _screen_text().contains("Trim colour"), "Each part is named with its colour")
	# The wider palette (director 2026-11-11), by finger on a phone: all of it
	# on screen at thumb size, and a new colour paints the trim.
	var palette: Control = current_scene.find_child("ForgePalette", true, false)
	var swatches := palette.get_children() if palette != null else []
	var small_sw := []
	for s in swatches:
		if (s as Control).size.x < 44 or (s as Control).size.y < 44:
			small_sw.append(s.name)
	# Loaded, not named: naming ClubForge here compiles it before GameDB exists.
	var palette_size: int = load("res://scripts/sim/ClubForge.gd").PALETTE.size()
	_check(swatches.size() == palette_size and palette_size >= 27 and small_sw.is_empty(),
			"Every Forge colour is a thumb-sized swatch on a phone (%d, small %s)" % [swatches.size(), str(small_sw)])
	var bottle_sw: Control = current_scene.find_child("ForgeColour_bottle", true, false)
	var bottle_tap: String = await Tap.tap(bottle_sw) if bottle_sw != null else "missing"
	await _settle()
	_check(bottle_tap == "" and _screen_text().contains("Painting with Bottle green"),
			"A finger picks a new colour, and the screen names it (%s)" % bottle_tap)
	var trim_part: Control = current_scene.find_child("ForgePart_trim", true, false)
	var trim_tap: String = await Tap.tap(trim_part) if trim_part != null else "missing"
	await _settle()
	_check(trim_tap == "" and str(current_scene.get("_club")["accent"]).to_upper() == "#0C4A2F"
			and _screen_text().contains("Bottle green"),
			"A finger paints the trim bottle green (%s)" % trim_tap)
	# Where you click on the guernsey decides what you paint.
	var crest = load("res://scripts/ui/GuernseyCrest.gd").make(Color.RED, Color.BLUE, Color.WHITE, "hoops", "", 100.0)
	crest.size = Vector2(100, 100)
	_check(crest.part_at(Vector2(50, 30)) == "body" and crest.part_at(Vector2(50, 22)) == "pattern"
			and crest.part_at(Vector2(50, 6)) == "trim" and crest.part_at(Vector2(2, 95)) == "",
			"A click lands on the body, a hoop, the collar or off the guernsey")
	crest.design = "plain"
	_check(crest.part_at(Vector2(50, 22)) == "body", "A plain guernsey has no pattern to paint")
	crest.free()
	var club_small := []
	for b in current_scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			club_small.append(b.name)
	_check(club_small.is_empty(), "Every Create a club button is thumb-sized (%s)" % str(club_small))
	_press("ForgeSaveClub")
	await _settle()
	var fc: Dictionary = _state.forge_club()
	_check(str(fc.get("name", "")) == "Port Melbourne" and str(fc.get("short", "")) == "Borough"
			and str(fc.get("code", "")) == "PMB" and str(fc.get("location", "")) == "port-melbourne"
			and str(fc.get("ground", "")) == "North Port Oval" and str(fc.get("primary", "")).to_upper() == "#C8102E"
			and str(fc.get("design", "")) == "hoops",
			"The Forge saves the club as made (%s)" % str(fc))
	_check(current_scene.find_child("ForgeClubTitle", true, false) != null, "The Forge shows your club")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main", "Back leaves the Forge")
	root.size = size_before
	await _settle()
	# --- desktop scale (STYLE-07): the PC shows the game bigger, not emptier ---
	var layout = root.get_node("ScreenLayout")
	var dens := func(w: float, h: float, os_scale: float, dpi: int) -> float:
		return float(layout.desktop_density(Vector2(w, h), os_scale, dpi))
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 288), 3.0),
			"4K at Windows 300% (DPI 288, scale reported as 1) lays out on 1280 x 720")
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 96), 3.0),
			"4K at 100% still fits the 1280 x 720 canvas, not 3840 x 2160")
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 144), 3.0),
			"4K at 150% is not scaled twice (3, not 4.5)")
	_check(is_equal_approx(dens.call(1920, 1080, 1.0, 96), 1.5) and is_equal_approx(dens.call(2560, 1440, 1.0, 96), 2.0),
			"1080p and 1440p fit the same canvas")
	_check(is_equal_approx(dens.call(3440, 1440, 1.0, 96), 2.0),
			"Ultrawide fits by height and widens the canvas (1720 x 720)")
	_check(is_equal_approx(dens.call(1280, 720, 1.0, 96), 1.0) and is_equal_approx(dens.call(900, 600, 1.0, 96), 1.0),
			"A window at or under 1280 x 720 at 100% is drawn 1:1")
	_check(is_equal_approx(dens.call(1280, 720, 1.0, 288), 3.0),
			"A small window at 300% follows the OS scaling (the small-window floor then applies)")
	_check(is_equal_approx(dens.call(2880, 1800, 2.0, 0), 2.25),
			"A Mac reporting its own scale still fills the screen")
	# --- the web canvas scales like the desktop window (director, 2026-10-18: "Yes, scale it") ---
	# A browser at 1440p and ratio 1 drew 2560 units: 13-unit text. The window is
	# the canvas in physical pixels (css size x the page's pixel ratio).
	var web_layout_script = load("res://scripts/core/ScreenLayout.gd")
	var web_bad := []
	for row in [[1280, 720, 1.0, 1280], [1920, 1080, 1.0, 1280], [2560, 1440, 1.0, 1280],
			[3840, 2160, 1.0, 1280], [3840, 2160, 2.0, 1280], [3840, 2160, 3.0, 1280], [1280, 720, 2.0, 1280]]:
		var px := Vector2(float(row[0]) * float(row[2]), float(row[1]) * float(row[2]))
		var units: float = px.x / float(web_layout_script.web_density(px, float(row[2])))
		if absf(units - float(row[3])) > 1.0:
			web_bad.append("%sx%s at %s -> %.0f units wide" % [row[0], row[1], row[2], units])
	_check(web_bad.is_empty(), "A browser window at 720p, 1080p, 1440p and 4K draws a ~1280-unit canvas (%s)" % [web_bad])
	web_bad = []
	for row in [[390, 844, 1.0], [390, 844, 3.0], [412, 915, 1.0], [412, 915, 3.0], [360, 800, 2.0], [440, 956, 2.0]]:
		var px := Vector2(float(row[0]) * float(row[2]), float(row[1]) * float(row[2]))
		var units: float = px.x / float(web_layout_script.web_density(px, float(row[2])))
		if absf(units - float(row[0])) > 0.5:
			web_bad.append("%sx%s at %s -> %.1f units wide" % [row[0], row[1], row[2], units])
	_check(web_bad.is_empty(), "A phone's browser keeps its 360-440 unit canvas at its own pixel ratio (%s)" % [web_bad])
	var web_wide: float = 800.0 / float(web_layout_script.web_density(Vector2(800, 1100), 1.0))
	_check(web_wide <= 480.5 and float(web_layout_script.web_density(Vector2(1280, 720), 0.5)) == 1.0,
			"A portrait window wider than a phone is zoomed to 480 units; a ratio under 1 counts as 1 (%.0f)" % web_wide)
	# The real node, on the web path: the same sizes end to end through _update_scale.
	var web_window_before: Vector2i = root.size
	var web_ends := []
	for row in [[2560, 1440, 1.0, 1280, 720], [3840, 2160, 3.0, 1280, 720], [1170, 2532, 3.0, 390, 844], [1080, 1920, 1.0, 480, 853]]:
		web_layout_script.web_ratio_test = float(row[2])
		root.size = Vector2i(int(row[0]), int(row[1]))
		await _settle()
		layout._update_scale()
		if root.content_scale_size != Vector2i(int(row[3]), int(row[4])):
			web_ends.append("%s at %s -> %s" % [Vector2i(row[0], row[1]), row[2], root.content_scale_size])
	web_layout_script.web_ratio_test = 0.0
	root.size = web_window_before
	await _settle()
	layout._update_scale()
	_check(web_ends.is_empty(), "ScreenLayout on the web path sets the canvas the rule gives (%s)" % [web_ends])
	# Screen size (director, 2026-10-08: the game on a 4K TV from the couch):
	# TV draws everything 1.6x bigger; Standard puts it back.
	# In a PC-sized window: the small-window floor stops a 320-wide one.
	var window_before: Vector2i = root.size
	root.size = Vector2i(1280, 720)
	layout.set_screen_size("standard")
	await _settle()
	var canvas_before: Vector2i = root.content_scale_size
	layout.set_screen_size("tv")
	await _settle()
	var canvas_tv: Vector2i = root.content_scale_size
	_check(is_equal_approx(float(layout.ui_scale), 1.6) and canvas_tv.x > 0
			and absf(float(canvas_before.x) / float(canvas_tv.x) - 1.6) < 0.05,
			"TV screen size draws the game 1.6x bigger (%s -> %s)" % [canvas_before, canvas_tv])
	layout.set_screen_size("standard")
	await _settle()
	_check(root.content_scale_size == canvas_before, "Standard puts it back")
	root.size = window_before
	await _settle()

	# --- new career setup: the two dials, applied only on start --------------
	current_scene.find_child("NewCareer", true, false).emit_signal("pressed")
	await _settle()
	await _pick_year()
	var ruthless_btn: Button = current_scene.find_child("BoardPatience_ruthless", true, false)
	var cutthroat_btn: Button = current_scene.find_child("RivalRecruiting_cutthroat", true, false)
	_check(ruthless_btn != null and cutthroat_btn != null, "New career asks for the two difficulty dials")
	_check(current_scene.find_child("NameMode_real", true, false) == null
			and current_scene.find_child("NameMode_generated", true, false) == null
			and not _screen_text().contains("Player names") and not _screen_text().to_lower().contains("generated names"),
			"New career has no player names choice: real names are the only names")
	var note: Label = current_scene.find_child("BoardPatienceNote", true, false)
	var rival_note: Label = current_scene.find_child("RivalRecruitingNote", true, false)
	_check(note != null and note.visible and note.text == DifficultyDials.text("board_patience", "fair")
			and rival_note != null and rival_note.visible and rival_note.text == DifficultyDials.text("rival_recruiting", "shrewd"),
			"Each dial starts on its middle step and says what it means in one sentence")
	var every_trade := true
	for key in DifficultyDials.order("rival_recruiting"):
		every_trade = every_trade and DifficultyDials.text("rival_recruiting", key).contains("trade")
	_check(every_trade, "Every rival recruiting sentence says it is about trades")
	if ruthless_btn != null:
		ruthless_btn.emit_signal("pressed")
		await _settle()
	_check(_state.new_career_dial("board_patience") == "fair" and _state.new_career_dial("rival_recruiting") == "shrewd",
			"A pick changes nothing before the career starts")
	_check(note != null and note.text == DifficultyDials.text("board_patience", "ruthless"),
			"The sentence follows the picked step")
	# No percentage or multiplier ever reaches the screen: every step is a name and a sentence.
	var plain := true
	for dial in DifficultyDials.DIALS:
		for key in DifficultyDials.order(dial):
			plain = plain and not DifficultyDials.text(dial, key).contains("%") \
					and not DifficultyDials.label(dial, key).contains("%")
	_check(plain, "No step shows a percentage")
	_router.handle_back(false)
	await _settle()
	# Setup -> the year step -> the title screen.
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("NewCareerSetup", true, false) == null
			and _state.new_career_dial("board_patience") == "fair", "Back leaves the setup without changing anything")
	current_scene.find_child("NewCareer", true, false).emit_signal("pressed")
	await _settle()
	await _pick_year()
	current_scene.find_child("BoardPatience_ruthless", true, false).emit_signal("pressed")
	current_scene.find_child("RivalRecruiting_cutthroat", true, false).emit_signal("pressed")
	_check(current_scene.find_child("ForgedClub_in", true, false) != null, "New career offers your Forge club")
	# On a phone, where the setup form scrolls.
	var win_was := root.size
	root.size = Vector2i(390, 844)
	await _settle()
	var tut_off = current_scene.find_child("Tutorials_off", true, false)
	var tut_tap: String = await Tap.tap(tut_off) if tut_off != null else "missing"
	var con_off = current_scene.find_child("Controversies_off", true, false)
	var con_tap: String = await Tap.tap(con_off) if con_off != null else "missing"
	# The supplements saga is its own switch: on, with Controversies off.
	var sup_on = current_scene.find_child("Supplements_on", true, false)
	var sup_tap: String = await Tap.tap(sup_on) if sup_on != null else "missing"
	var board_btn = current_scene.find_child("BoardPatience_ruthless", true, false)
	var rival_btn = current_scene.find_child("RivalRecruiting_cutthroat", true, false)
	var board_tap: String = await Tap.tap(board_btn) if board_btn != null else "missing"
	var rival_tap: String = await Tap.tap(rival_btn) if rival_btn != null else "missing"
	root.size = win_was
	await _settle()
	_check(tut_tap == "", "New career offers Tutorials On/Off, and Off takes a real tap (%s)" % tut_tap)
	_check(con_tap == "", "New career offers Controversies On/Off, and Off takes a real tap (%s)" % con_tap)
	_check(sup_tap == "", "New career offers Supplements saga On/Off, and On takes a real tap (%s)" % sup_tap)
	_check(board_tap == "" and rival_tap == "", "Both difficulty dials take a real tap on a phone (%s %s)" % [board_tap, rival_tap])
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	_check(_router.current() == "draft", "Starting the career goes on to choosing a club")
	_check(_state.new_career_dial("board_patience") == "ruthless" and _state.board_patience == "ruthless"
			and _state.rival_recruiting == "cutthroat", "The career starts with the picks made")
	_check(not _state.controversies, "The career starts with Controversies off")
	_check(_state.supplements, "The supplements saga stays on with Controversies off")
	_state.set_setting("controversies", true)   # the next setup starts on again
	_state.set_setting("supplements", true)
	var brought := false
	for d in _state.draftee_pool:
		brought = brought or (str(d["id"]) == _state.custom_prospect_id and str(d.get("last", "")) == "Forge")
	_check(brought, "Your Forge player is in this career's first National Draft class")
	_state.set_setting("seen_weekly_loop_intro", false)
	_check(not _state.tutorials_on() and not _state.intro_due("weekly_loop"),
			"With Tutorials off, an unseen intro does not open by itself")
	_check(_state.draft != null and _state.draft.clubs.has("PMB") and _db.club_name("PMB") == "Port Melbourne",
			"Your Forge club is in this career's League Draft")
	_state.set_forge_player({})
	_state.set_forge_club({})
	_state.set_new_career_dial("board_patience", "fair")
	_state.set_new_career_dial("rival_recruiting", "shrewd")
	_state.reset()
	# Tutorials belong to the career: kept through save and load, changed in Settings.
	_state.start_season("SYD", _db.club_list("SYD"))
	_state.set_tutorials_on(false)
	_state.save_career()
	_state.set_setting("tutorials", true)
	_state.reset()
	_check(_state.load_career() and not _state.tutorials_on(), "A career's Tutorials choice survives save and load")
	_state.set_tutorials_on(true)
	_check(_state.intro_due("weekly_loop") and _state.new_career_tutorials(),
			"Turning Tutorials back on in Settings lets unseen intros open again")
	_state.set_setting("seen_weekly_loop_intro", true)
	_check(not _state.intro_due("weekly_loop"), "...but an intro already read stays closed")
	_state.set_setting("seen_weekly_loop_intro", false)
	_state.reset()

	# The Grand Final line names the premiers first, at either end.
	var review = load("res://scripts/ui/SeasonReviewScene.gd")
	var gf_line: String = review.gf_text({"home": "BRL", "away": "FRE", "score": [61, 126],
			"goals": [8, 19], "behinds": [13, 12]}, "FRE")
	_check(gf_line.begins_with(_db.club_name("FRE")) and gf_line.contains("d.  " + _db.club_name("BRL")),
			"Season review: the Grand Final winner comes first, home or away (%s)" % gf_line)
	_check(review.summary_text("", false, "7th") == "You finished 7th.",
			"Season review: no premiers gives only your finish, no blank club name")
	_check(review.summary_text("FRE", false, "7th") == "%s take the flag. You finished 7th." % _db.club_name("FRE"),
			"Season review: another club's flag names them and your finish")
	_check(review.summary_text("FRE", true, "1st") == "PREMIERSHIP!", "Season review: your flag says PREMIERSHIP!")
	# Bug-bash 4 (2026-11-10): every season fact is home-and-away, like the
	# ladder's points for and against: a final's big win, goals and streak
	# are left out.
	var ha_rows := [
		{"home": "FRE", "away": "BRL", "score": [80, 70], "goals": [12, 10]},
		{"home": "GEE", "away": "FRE", "score": [90, 60], "goals": [14, 9]},
		{"home": "FRE", "away": "SYD", "score": [150, 50], "goals": [23, 7]},
		{"home": "FRE", "away": "MEL", "score": [100, 40], "goals": [15, 6]},
	]
	var st: Dictionary = review.season_stats(ha_rows, {"p": 3, "pf": 290, "pa": 210, "pct": 138.1}, "FRE")
	_check(int(st["best_margin"]) == 100 and int(st["goals"]) == 44 and int(st["streak"]) == 1
			and int(st["worst_margin"]) == 30 and int(st["pf"]) == 290,
			"Season review: best win, goals and streak leave the finals out, as points for does (%s)" % str(st))
	_check(review.finals_line(st) == "Finals: 1-0 (100 for, 40 against)",
			"Season review: the finals get their own short line (%s)" % review.finals_line(st))
	_check(review.finals_line(review.season_stats(ha_rows.slice(0, 3), {"p": 3}, "FRE")) == "",
			"Season review: no finals, no finals line")

	# --- a saved career shows Continue, and it loads -------------------------
	_state.start_season("SYD", _db.club_list("SYD"))
	_state.advance()
	_state.advance()
	_check(_state.save_career(), "The career saves")
	_state.reset()
	_router.to_main_menu(false)
	await _settle()
	var cont: Button = current_scene.find_child("ContinueCareer", true, false)
	_check(cont != null, "Continue Career appears when a save exists")
	_check(_screen_text().contains("Round 3"), "The menu shows where the save is up to")
	if cont != null:
		cont.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub", "Continue Career opens the season hub (%s)" % _router.current())
	_check(_state.season != null and _state.season.round_index == 2, "The saved round is loaded")
	_check(_state.my_club == "SYD", "The saved club is loaded")
	var intro: Control = current_scene.find_child("WeeklyLoopIntro", true, false)
	var skip_intro: Button = current_scene.find_child("SkipOnboarding", true, false)
	_check(intro != null and skip_intro != null
			and _screen_text().contains("This is home base")
			and _screen_text().contains("Play match")
			and _screen_text().contains("never a gate"),
			"The first Hub visit explains the weekly loop in context and can be skipped")
	if skip_intro != null:
		skip_intro.emit_signal("pressed")
		await _settle()
	_check(current_scene.find_child("WeeklyLoopIntro", true, false) == null
			and bool(_state.get_setting("seen_weekly_loop_intro", false)),
			"Skipping onboarding closes it and remembers the choice")
	# A pending press conference follows the intro as its own screen; skip it.
	await _past_press()
	_check(_router.current() == "hub", "After the intro (and any press conference) the hub is up")
	current_scene.call("_show_weekly_loop_intro")
	await _settle()
	_check(current_scene.find_child("WeeklyLoopIntro", true, false) == null,
			"Contextual onboarding does not nag after it has been dismissed")
	# A press conference left from the saved round follows the intro.
	var media_skip = current_scene.find_child("MediaSkip", true, false)
	if media_skip != null:
		media_skip.emit_signal("pressed")
		await _settle()
	# One player well above his season, one well below (GameState.player_form).
	var hot_id := str(_state.my_list[0]["id"])
	var cold_id := str(_state.my_list[1]["id"])
	_state.form_log[hot_id] = {"last": [95, 95, 95], "n": 10, "sum": 500}
	_state.form_log[cold_id] = {"last": [15, 15, 15], "n": 10, "sum": 600}
	var coaching: Button = current_scene.find_child("HubCoaching", true, false)
	_check(coaching != null, "Coaching is on the hub's bottom row")
	if coaching != null:
		coaching.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "coaching" and current_scene.find_child("BoardConfidence", true, false) != null
			and current_scene.find_child("HowWePlay", true, false) != null
			and current_scene.find_child("StaffLine_SA", true, false) != null,
			"Coaching shows how we play, the board and the staff")
	# List profile: each game plan carries the strength it runs on, as a word; the two
	# strengths no plan runs on are listed under them, and a tap says who leads one.
	var hwp: Node = current_scene.find_child("HowWePlay", true, false)
	var press_tile: Node = hwp.find_child("ClubPlan_defensive", true, false) if hwp != null else null
	var press_word: Label = press_tile.find_child("Strength", true, false) if press_tile != null else null
	_check(press_word != null and press_word.text.begins_with("Pressure · "),
			"High Press shows the list's Pressure beside it (%s)" % (press_word.text if press_word else "-"))
	var lp: Node = current_scene.find_child("ListProfile", true, false)
	var lp_rows: Array = lp.find_children("Profile_*", "Button", true, false) if lp != null else []
	_check(lp_rows.size() == 2 and lp.find_child("Profile_finishing", true, false) != null
			and lp.find_child("Profile_aerial", true, false) != null,
			"Aerial power and Finishing, which no plan runs on, are listed under the plans (%d)" % lp_rows.size())
	var lp_text := ""
	for l in (hwp.find_children("*", "Label", true, false) if hwp != null else []):
		if (l as Label).is_visible_in_tree():
			lp_text += (l as Label).text + " "
	_check(not lp_text.to_lower().contains("recommend") and not lp_text.to_lower().contains("should")
			and not lp_text.to_lower().contains("best choice") and not lp_text.to_lower().contains("suits you"),
			"The plans and strengths carry no advice")
	var trade_line: Label = hwp.find_child("PlanTradeOff", true, false) if hwp != null else null
	_check(trade_line != null and trade_line.is_visible_in_tree() and trade_line.text.contains("gives something up"),
			"How we play says in a line that a plan costs something and buys an edge (P-63)")
	_check(lp_rows.all(func(b): return (b as Button).size.y >= 44), "Each strength is a thumb-sized tap")
	if not lp_rows.is_empty():
		var detail: Label = (lp_rows[0] as Node).get_parent().find_child("Detail", false, false)
		(lp_rows[0] as Button).emit_signal("pressed")
		await _settle()
		_check(detail != null and detail.visible and detail.text.contains("Leading it: "),
				"A tap says what the strength is and who leads it")
	# Recent games: who is in and out of form, by name - no "his".
	var form_box: Node = current_scene.find_child("Form", true, false)
	var form_text := ""
	for l in (form_box.find_children("*", "Label", true, false) if form_box != null else []):
		form_text += (l as Label).text + "\n"
	_check(form_text.contains("In good form") and form_text.contains("In poor form")
			and form_box.find_child("Form_hot_" + hot_id, true, false) != null
			and form_box.find_child("Form_cold_" + cold_id, true, false) != null,
			"Recent games says who is in good and poor form, by name")
	_check(not form_text.contains(" his ") and not form_text.contains("his season"),
			"Recent games has no dangling 'his' (%s)" % form_text.replace("\n", " / "))
	var plan: Button = current_scene.find_child("ClubPlan_contest", true, false)
	var size_plan: Vector2i = root.size
	root.size = Vector2i(390, 844)   # a phone window, so the finger lands on screen
	await _settle()
	plan = current_scene.find_child("ClubPlan_contest", true, false)
	var why_plan: String = (await Tap.tap(plan)) if plan != null else "no tile"
	await _settle()
	_check(_state.club_plan == "contest" and _state.season.plans.get("SYD", "") == "contest",
			"Choosing a game plan makes it the club's plan (a real tap: %s)" % why_plan)
	# Readability: the chosen plan is bold, the others regular.
	var chosen_l: Label = plan.find_child("Plan", true, false) if plan != null else null
	var other_tile: Node = current_scene.find_child("ClubPlan_attacking", true, false)
	var other_l: Label = other_tile.find_child("Plan", true, false) if other_tile != null else null
	_check(chosen_l != null and other_l != null and chosen_l.get_theme_font("font") == load("res://scripts/ui/UiKit.gd").BOLD
			and other_l.get_theme_font("font") != load("res://scripts/ui/UiKit.gd").BOLD, "The chosen plan is bold, the others are regular")
	# Your own plan (director 2026-11-12): a real tap picks a strength and a cost;
	# a cost on the strength's own lever cannot be picked; once both are set the
	# plan's tile can be tapped, and it carries the plan's name.
	_state.custom_plan = {}
	_state._sync_club_plan()
	_router.handle_back(true)
	await _settle()
	_router.go("coaching")
	await _settle()
	var own_tile: Button = current_scene.find_child("ClubPlan_custom", true, false)
	_check(own_tile != null and own_tile.disabled, "Your own plan cannot be picked before it is built")
	var s_btn: Button = current_scene.find_child("OwnPlanStrength_clean", true, false)
	_check(s_btn != null and s_btn.size.y >= 44, "Each strength is a thumb-sized tap")
	var why_s: String = (await Tap.tap(s_btn)) if s_btn != null else "no button"
	await _settle()
	var loose: Button = current_scene.find_child("OwnPlanCost_loose", true, false)
	_check(_state.custom_plan.get("s", "") == "clean" and loose != null and loose.disabled,
			"A tap picks the strength, and a cost on the same lever is greyed out (a real tap: %s)" % why_s)
	var c_btn: Button = current_scene.find_child("OwnPlanCost_slow", true, false)
	var why_c: String = (await Tap.tap(c_btn)) if c_btn != null else "no button"
	await _settle()
	var s_row: Node = current_scene.find_child("OwnPlanStrengthLine", true, false)
	var c_row: Node = current_scene.find_child("OwnPlanCostLine", true, false)
	var s_text: Label = s_row.find_child("Text", false, false) if s_row != null else null
	var c_text: Label = c_row.find_child("Text", false, false) if c_row != null else null
	_check(_state.custom_plan.get("c", "") == "slow" and s_text != null and c_text != null
			and s_text.text.contains("%") and s_text.text.contains("clangers") and c_text.text.contains("6%"),
			"A tap picks the cost, and each pick says what it does with its size (a real tap: %s; %s / %s)"
			% [why_c, s_text.text if s_text != null else "-", c_text.text if c_text != null else "-"])
	own_tile = current_scene.find_child("ClubPlan_custom", true, false)
	var why_own: String = (await Tap.tap(own_tile)) if own_tile != null else "no tile"
	await _settle()
	var own_l: Label = own_tile.find_child("Plan", true, false) if own_tile != null else null
	_check(_state.club_plan == "custom" and own_l != null and own_l.text == str(load("res://scripts/sim/CustomPlan.gd").DEFAULT_NAME),
			"Once built, a tap makes your own plan the club's, under its name (a real tap: %s)" % why_own)
	root.size = size_plan
	_state.custom_plan = {}
	_state._sync_club_plan()
	_state.set_club_plan("balanced")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "Back returns to the hub")
	_state.week_event = _state.story_card("members_open_training")
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	var ev_btn: Button = current_scene.find_child("Event_0", true, false)
	_check(ev_btn != null, "This week's decision shows on the hub")
	if ev_btn != null:
		ev_btn.emit_signal("pressed")
		await _settle()
	_check(not _state.week_event_pending() and _screen_text().contains("members loved it"),
			"Answering it shows what happened")
	# A big week's two cards: both show, and a finger on the second card's
	# answer settles that card only.
	_state.week_events = [_state.story_card("members_open_training"), _state.story_card("training_extra_session")]
	_shown_over_hub()
	var two_cards_size := root.size
	root.size = Vector2i(390, 844)
	_router.go("hub")
	await _settle()
	var second_card: Control = current_scene.find_child("WeekEvent_1", true, false)
	var second_btn: Button = second_card.find_child("Event_1", true, false) if second_card != null else null
	var second_tap: String = await Tap.tap(second_btn) if second_btn != null else "missing"
	await _settle()
	_check(second_tap == "" and bool(_state.week_events[1].get("resolved", false))
			and not bool(_state.week_events[0].get("resolved", false)),
			"Two cards in a big week, each answered on its own by a tap (%s)" % second_tap)
	# What each answer does sits under its own button, worded from its effects,
	# gains first then costs, in the same full-strength text for every answer:
	# backing him names the promise, leaving him out names the missed game, and
	# a finger on a button with lines under it still answers the card. The card
	# does not repeat these lines under its heading.
	# A card that settles itself when the week is played says so on its face, with that choice's cost.
	_state.week_events = [_state.story_card("health_pulled_up_sore", _state.my_list[0])]
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	var sore_node: Control = current_scene.find_child("EventSilence_0", true, false)
	var sore_text := ""
	if sore_node != null:
		sore_text = str(sore_node.get_meta("plain")) if sore_node.has_meta("plain") else str(sore_node.get("text"))
	# The choice carries his name, never a bare "him" (director, 2026-11-11).
	_check(sore_text.begins_with("If you leave this, it goes as \"Play ") and sore_text.ends_with("\".")
			and not sore_text.contains("Play him"),
			"A card with a silent default names the choice it settles as, once (%s)" % sore_text)
	# A finger on the line answers nothing; a finger on "Play him" below it answers the card.
	var line_tap: String = await Tap.tap(sore_node) if sore_node != null else "missing"
	await _settle()
	var still_open := not bool(_state.week_events[0].get("resolved", false))
	var play_btn: Button = current_scene.find_child("Event_1", true, false)
	var play_tap: String = await Tap.tap(play_btn) if play_btn != null else "missing"
	await _settle()
	_check(line_tap == "" and still_open and play_tap == "" and bool(_state.week_events[0].get("resolved", false))
			and int(_state.week_events[0].get("choice", -1)) == 1,
			"A real tap on the default line answers nothing; a real tap on Play him answers it (%s / %s)" % [line_tap, play_tap])
	_state.week_events = [_state.story_card("training_kid_pushing", _state.my_list[0])]
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	var kid_card: Control = current_scene.find_child("WeekEvent", true, false)
	var back_gain: Label = kid_card.find_child("EventGain_0_0", true, false) if kid_card != null else null
	var back_cost: Label = kid_card.find_child("EventCost_0_0", true, false) if kid_card != null else null
	var rest_gain: Label = kid_card.find_child("EventGain_0_1", true, false) if kid_card != null else null
	var rest_cost: Label = kid_card.find_child("EventCost_0_1", true, false) if kid_card != null else null
	var back_mark: Label = kid_card.find_child("EventGainMark_0_0", true, false) if kid_card != null else null
	var cost_mark: Label = kid_card.find_child("EventCostMark_0_1", true, false) if kid_card != null else null
	var rest_btn: Button = kid_card.find_child("Event_1", true, false) if kid_card != null else null
	var same_style := true
	for l in [back_gain, back_cost, rest_gain, rest_cost]:
		if l == null or (l as Label).get_theme_font_size("font_size") < 14 or (l as Label).get_theme_color("font_color") != (back_gain as Label).get_theme_color("font_color") 				or (l as Label).get_theme_color("font_color").a < 0.99:
			same_style = false
	_check(kid_card != null and kid_card.find_child("EventStakes_0", true, false) == null
			and back_mark != null and back_mark.text == "Gain:" and cost_mark != null and cost_mark.text == "Cost:"
			and cost_mark.get_theme_font("font") != rest_cost.get_theme_font("font") and cost_mark.get_theme_color("font_color") == load("res://scripts/ui/UiKit.gd").label_ink()
			and back_gain != null and back_cost != null and back_cost.text.contains("promise breaks")
			and rest_gain != null and rest_cost != null and rest_cost.text.contains("'s opinion of you down") and not rest_cost.text.begins_with("His ") and rest_cost.text.contains("re-sign with you")
			and same_style and rest_btn != null and rest_cost.get_global_rect().position.y >= rest_gain.get_global_rect().end.y - 1.0
			and rest_gain.get_global_rect().position.y >= rest_btn.get_global_rect().end.y - 1.0,
			"Each answer says its gains then its costs under its own button, in the same full-strength text (%s / %s)" % [back_cost.text if back_cost != null else "none", rest_cost.text if rest_cost != null else "none"])
	var first_btn: Button = kid_card.find_child("Event_0", true, false) if kid_card != null else null
	_check(first_btn != null and rest_btn != null and back_gain != null and back_cost != null
			and rest_btn.get_global_rect().position.y - back_cost.get_global_rect().end.y
			> back_gain.get_global_rect().position.y - first_btn.get_global_rect().end.y + 4.0,
			"The gap to the next button is larger than the gap from a button to its own lines")
	var cost_tap: String = await Tap.tap(rest_btn) if rest_btn != null else "missing"
	await _settle()
	_check(cost_tap == "" and bool(_state.week_events[0].get("resolved", false)),
			"A real tap on the answer that costs a game answers the card (%s)" % cost_tap)
	_state.week_events = []
	# His opinion of you on the profile, at phone size: the number, and a finger
	# on Why shows the rule and his reasons, newest first. A player you've had
	# nothing to do with is at 50/100.
	var trusted: Dictionary = _state.my_list[0]
	var stranger: Dictionary = _state.my_list[1]
	var saved_rel: Dictionary = _state.relations.duplicate(true)
	_state.relations.erase(Trust.player_key(str(stranger["id"])))
	_state.relations.erase(Trust.player_key(str(trusted["id"])))
	Trust.change(_state.relations, Trust.player_key(str(trusted["id"])), 12, "You gave him his chance", _state.season_year, "Round 2")
	Trust.change(_state.relations, Trust.player_key(str(trusted["id"])), 10, "You promised him his spot back", _state.season_year, "Round 5")
	var tsheet: Control = load("res://scripts/ui/PlayerSheet.gd").open(current_scene, trusted)
	await _settle()
	var twords: Label = tsheet.find_child("TrustWords", true, false)
	var twhy: Button = tsheet.find_child("TrustWhy", true, false)
	var treasons: Control = tsheet.find_child("TrustReasons", true, false)
	_check(twords != null and twords.text == "Opinion of you 61/100." and treasons != null and not treasons.visible,
			"The profile shows his opinion of you out of 100, with the reasons folded away (%s)" % (twords.text if twords != null else "missing"))
	var why_tap: String = await Tap.tap(twhy) if twhy != null else "missing"
	await _settle()
	var first_reason: Label = treasons.get_child(1) if treasons != null and treasons.get_child_count() > 2 else null
	_check(why_tap == "" and treasons.visible and twhy.size.y >= 44 and first_reason != null
			and first_reason.text.begins_with("Round 5, ") and first_reason.text.ends_with("Opinion of you +5.")
			and (treasons.get_child(0) as Label).text.contains("he may refuse to re-sign with you"),
			"A tap on Why shows the rule, then his reasons newest first with their size (%s, %s)" % [why_tap,
					first_reason.text if first_reason != null else "missing"])
	tsheet.queue_free()
	var ssheet: Control = load("res://scripts/ui/PlayerSheet.gd").open(current_scene, stranger)
	await _settle()
	var swords: Label = ssheet.find_child("TrustWords", true, false)
	_check(swords != null and swords.text == "Opinion of you 50/100.",
			"A player you've had nothing to do with is at 50/100 (%s)" % (swords.text if swords != null else "missing"))
	ssheet.queue_free()
	_state.relations = saved_rel
	await _settle()
	root.size = two_cards_size

	# --- Sim round asks first: it plays your match without you --------------
	_state.set_confirm_sim_round(true)
	_router.go("hub")
	await _settle()
	var r0: int = _state.season.round_index
	var press_sim := func() -> void:
		var b: Button = current_scene.find_child("SimRound", true, false)
		if b != null:
			b.emit_signal("pressed")
	press_sim.call()
	await _settle()
	_check(current_scene.find_child("SimConfirm", true, false) != null and _state.season.round_index == r0,
			"Sim round asks before playing your match")
	# The round's own name: a themed round (Gather Round, Sir Doug Nicholls
	# Round) is named as such.
	var up_label := str(current_scene.call("_upcoming_match").get("label", ""))
	_check(up_label != "" and _screen_text().contains("Sim %s?" % up_label),
			"The question names the round (%s)" % up_label)
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("SimConfirm", true, false) == null
			and _state.season.round_index == r0, "Back closes the question and sims nothing")
	press_sim.call()
	await _settle()
	current_scene.find_child("SimConfirmCancel", true, false).emit_signal("pressed")
	await _settle()
	_check(_state.season.round_index == r0, "Cancel sims nothing")
	press_sim.call()
	await _settle()
	current_scene.find_child("SimConfirmNever", true, false).emit_signal("pressed")
	await _settle()
	var cfg := ConfigFile.new()
	cfg.load(_state.settings_path)
	_check(_state.season.round_index == r0 + 1 and not _state.confirm_sim_round()
			and cfg.get_value("ui", "confirm_sim_round", true) == false,
			"Don't ask again sims the round and remembers the choice")
	_router.handle_back(true)
	await _settle()
	press_sim.call()
	await _settle()
	_check(current_scene.find_child("SimConfirm", true, false) == null and _state.season.round_index == r0 + 2,
			"After Don't ask again, Sim round goes straight ahead")
	_router.handle_back(true)
	await _settle()
	_state.set_confirm_sim_round(true)

	# --- a simmed match: headlined, and reviewable at full time -------------
	# The rounds just simmed can leave a press conference waiting, depending on the
	# results: leave it, as a coach would, and come back to the hub.
	for _i in range(10):
		if current_scene.has_method("_on_sim_round"):
			break
		_router.handle_back(true)
		await _settle()
	current_scene.call("_on_sim_round")
	await _settle()
	var popup = current_scene.get("_results_overlay")
	_check(popup != null and popup.find_child("MyVerdict", true, false) != null,
			"Your result leads the round popup")
	var round_before: int = _state.season.round_index
	var xp_before := 0
	for p in _state.my_list:
		xp_before += int(p.get("xp", 0))
	var injuries_before := str(_state.last_injuries)
	var log_before: int = _state.season_log.size()
	var rv: Button = popup.find_child("ReviewMatch", true, false) if popup != null else null
	_check(rv != null and rv.size.y >= 44, "Review match is one thumb-sized tap")
	# A first this match settled, as the round would have kept it (Firsts.gd):
	# full time says so, now and after a reload.
	var mine_side := 0 if str(_state.last_match["home"]) == _state.my_club else 1
	# The debutant is chosen, not left to the seed: a player in the side whose
	# debut is on record from no earlier match (Firsts.note writes a first once)
	# and who is not in fact on debut, which the milestone line says instead.
	var firsts = load("res://scripts/sim/Firsts.gd")
	var debutant := {}
	for r in (_state.last_match["roster"][mine_side] as Array):
		var q: Dictionary = _state.list_player(str(r["id"]))
		if not q.is_empty() and not firsts.has(q, "debut") and _state.games_played(q) != 1:
			debutant = q
			break
	_check(not debutant.is_empty(), "A player in the side to give a debut at full time")
	firsts.note(debutant, "debut", _state.season_year, str(_state.last_match["label"]))
	var debutant_name: String = _db.player_display_name(debutant)
	if rv != null:
		rv.emit_signal("pressed")
		await _settle()
	var ft = current_scene.find_child("FullTime", true, false)
	_check(_router.current() == "match" and ft != null, "Review match opens the full-time summary")
	var payoff = ft.find_child("PayoffLines", true, false) if ft != null else null
	var payoff_text := ""
	if payoff != null:
		for l in payoff.find_children("*", "Label", true, false):
			payoff_text += str(l.text) + "\n"
	_check(payoff != null and payoff_text.contains(debutant_name) and payoff_text.contains("debut"),
			"Full time says what the match settled: a debut (%s)" % payoff_text.strip_edges())
	for n in ["Verdict", "MatchFactors", "BestPlayers", "YourWeek", "ReviewTab_stats"]:
		_check(ft != null and ft.find_child(n, true, false) != null, "The review shows %s" % n)
	var ft_text := ""
	if ft != null:
		for l in ft.find_children("*", "Label", true, false):
			ft_text += str(l.text) + "\n"
	_check(not ft_text.contains("rose in OVR") and not ft_text.contains("in the reserves"),
			"Full time does not repeat the training result; Training has it")
	var sb = ft.find_child("ReviewTab_stats", true, false) if ft != null else null
	if sb != null:
		sb.emit_signal("pressed")
		await _settle()
		var me := 0 if str(_state.last_match["home"]) == _state.my_club else 1
		var ptab = current_scene.find_child("StatsView_players", true, false)
		if ptab != null:
			ptab.emit_signal("pressed")
			await _settle()
		var rows := current_scene.find_children("PlayerRow_*", "Button", true, false)
		_check(rows.size() == (_state.last_match["roster"][me] as Array).size(),
				"Match stats lists every player who played (%d)" % rows.size())
		_router.handle_back(true)
		await _settle()
	var ft_cont = current_scene.find_child("FullTimeContinue", true, false)
	if ft_cont != null:
		ft_cont.emit_signal("pressed")
		await _settle()
	# A press conference still pending opens over the hub as its own screen.
	await _past_press()
	var xp_after := 0
	for p in _state.my_list:
		xp_after += int(p.get("xp", 0))
	_check(_router.current() == "hub", "Continue from the review returns to the hub")
	_check(_state.season.round_index == round_before and xp_after == xp_before
			and str(_state.last_injuries) == injuries_before and _state.season_log.size() == log_before,
			"Reviewing plays nothing again: same round, XP, injuries and results")
	var again: Button = current_scene.find_child("ReviewLastMatch", true, false)
	_check(again != null, "The hub keeps a way back to your last match")
	# It survives a save and reload.
	_state.save_career()
	_state.load_career()
	_router.replace("hub")
	await _settle()
	await _past_press()
	again = current_scene.find_child("ReviewLastMatch", true, false)
	_check(again != null and _state.last_match.has("players"), "Your last match can still be reviewed after a reload")
	if again != null:
		again.emit_signal("pressed")
		await _settle()
		_check(current_scene.find_child("BestPlayers", true, false) != null, "...and opens at full time")
		_check(current_scene.find_child("PayoffLines", true, false) != null,
				"...with what the match settled, kept with the career")
		_router.handle_back(true)
		await _settle()
		if _router.current() == "match":
			current_scene.find_child("FullTimeContinue", true, false).emit_signal("pressed")
			await _settle()

	# --- back on the hub: results popup first, then the menu ----------------
	current_scene.call("_on_sim_round")
	await _settle()
	var overlay = current_scene.get("_results_overlay")
	_check(overlay != null and is_instance_valid(overlay), "Sim Round shows the results popup")
	_router.handle_back(true)
	await _settle()
	overlay = current_scene.get("_results_overlay")
	_check(_router.current() == "hub" and (overlay == null or not is_instance_valid(overlay)),
			"Back closes the results popup and stays on the hub")
	# The round may have raised a press conference: Back skips it. One check
	# either way, so the floor does not move with the round's result.
	var had_conference: bool = current_scene.find_child("MediaConference", true, false) != null
	if had_conference:
		_router.handle_back(true)
		await _settle()
	_check(not had_conference or (_router.current() == "hub" and not _state.media_conference_pending()),
			"A press conference, if the round raised one, is skipped by Back and the hub stays")
	# Back on the results brought the week's new card or ask on; each closes on
	# its own Back, then Back leaves the hub.
	var backs := 0
	while _router.current() == "hub" and backs < 10:
		_router.handle_back(true)
		await _settle()
		backs += 1
	_check(_router.current() == "main", "Back from the hub goes to the main menu")
	_check(_state.season != null, "Leaving by back keeps the career in memory")
	_check(current_scene.find_child("ResumeCareer", true, false) != null,
			"The menu offers Resume Season after backing out")
	# Settings can turn the Sim round question off and back on.
	current_scene.call("_show_settings")
	await _settle()
	var off_btn: Button = current_scene.find_child("SettingsSimConfirm_off", true, false)
	var on_btn: Button = current_scene.find_child("SettingsSimConfirm_on", true, false)
	_check(off_btn != null and on_btn != null, "Settings has Confirm before simming round")
	if off_btn != null and on_btn != null:
		off_btn.emit_signal("pressed")
		_check(not _state.confirm_sim_round(), "...which can be switched off")
		on_btn.emit_signal("pressed")
		_check(_state.confirm_sim_round(), "...and back on")
	current_scene.call("_close_settings")
	await _settle()

	# --- back on other screens ------------------------------------------------
	_router.go("hub")
	await _settle()
	await _past_press()
	# Its first-visit sheet would take the first Back; it has been read.
	_state.set_setting("seen_season_stats_intro", true)
	_router.go("stats")
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "hub", "Escape on Season stats returns to the hub")

	# --- team selection --------------------------------------------------------
	var sel_size_before := root.size
	root.size = Vector2i(390, 844)
	_router.go("selection")
	await _settle()
	_check(current_scene.find_child("AutoPick", true, false) != null, "The team screen opens")
	_check(_state.my_selection().is_empty(), "Until you move someone, the side is picked for you")
	var first_mid := str(_state.current_side()["MID"][0])
	var grid_card: Button = null
	for c in current_scene.find_child("NotSelected", true, false).get_children():
		if c is Button and load("res://scripts/sim/Ratings.gd").available(_state.list_player(str(c.get_meta("id")))):
			grid_card = c
			break
	var tap_in: String = await Tap.tap(grid_card) if grid_card != null else "missing"
	await _settle()
	var tap_c: String = await Tap.tap(current_scene.find_child("Spot_C", true, false))
	await _settle()
	_check(tap_in == "" and tap_c == "" and not _state.my_selection().is_empty()
			and not (_state.my_selection()["MID"] as Array).has(first_mid),
			"Two taps bring a player in for the centre, and the side is yours (%s, %s)" % [tap_in, tap_c])
	current_scene.call("_apply_strategy", "best")
	await _settle()
	_check(not _state.my_selection().is_empty() and current_scene.find_child("UndoPick", true, false) != null,
			"Auto-pick sets a side you can undo")
	root.size = sel_size_before
	_router.handle_back(true)
	await _settle()
	await _past_press()

	# --- training: one-time intro, stat guide, plan picker -------------------
	_router.go("training")
	await _settle()
	_check(current_scene.find_child("TrainingIntro", true, false) != null,
			"The training intro shows on the first visit (%s)" % _router.current())
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training"
			and current_scene.find_child("TrainingIntro", true, false) == null,
			"Back closes the intro and stays on Training")
	var guide_btn: Button = current_scene.find_child("StatGuideButton", true, false)
	var guide_size := root.size
	root.size = Vector2i(390, 844)   # a phone, so every tap lands on screen
	await _settle()
	guide_btn = current_scene.find_child("StatGuideButton", true, false)
	guide_btn.emit_signal("pressed")
	# The guide's sheet lays out (and may rise) over a few frames before a finger can hit a tile.
	for i in range(20):
		await process_frame
	var guide = current_scene.find_child("StatGuide", true, false)
	var sg: GDScript = load("res://scripts/ui/StatGuide.gd")
	_check(guide != null and guide.find_child("GuideGrid", true, false) != null
			and guide.find_child("GuideGrid", true, false).get_child_count() == sg.tiles().size(),
			"The stat guide opens on a grid with one tile per topic")
	# Every tile opens its page with a real tap; Back steps the page to the grid.
	var stats_seen := {}
	var pages_ok := true
	var lost_at := ""
	for t in sg.tiles():
		if not is_instance_valid(guide):
			pages_ok = false
			break
		var tile: Control = guide.find_child("Tile_" + str(t[0]), true, false)
		if tile == null:
			pages_ok = false
			continue
		var why: String = await Tap.tap(tile)
		await _settle()
		if why != "":
			lost_at = "tap on %s: %s" % [t[0], why]
			pages_ok = false
			break
		if not is_instance_valid(guide):
			lost_at = "tap on " + str(t[0])
			pages_ok = false
			break
		var page: Node = guide.find_child("GuidePage_" + str(t[0]), true, false)
		if page == null or guide.find_child("GuideGrid", true, false) != null:
			pages_ok = false
		else:
			for key in sg.STATS:
				if page.find_child("Guide_" + str(key), true, false) != null:
					stats_seen[key] = true
		_router.handle_back(true)
		await _settle()
		if not is_instance_valid(guide):
			lost_at = "Back from " + str(t[0])
			pages_ok = false
			break
		if guide.find_child("GuideGrid", true, false) == null:
			pages_ok = false
	_check(pages_ok, "A tap on every topic tile opens its page, and Back returns to the tiles (guide lost at: %s)" % lost_at)
	_check(stats_seen.size() == sg.STATS.size(),
			"Every stat, star power and discipline included, sits on a topic page (%d of %d)" % [stats_seen.size(), sg.STATS.size()])
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training" and current_scene.find_child("StatGuide", true, false) == null,
			"Back closes the stat guide")
	root.size = guide_size
	await _settle()
	var first: Dictionary = _state.my_list[0]
	current_scene.call("_open_player", str(first["id"]))
	await _settle()
	var picker: Node = current_scene.find_child("PlayerPlan", true, false)
	_check(picker != null and current_scene.find_children("*", "OptionButton", true, false).is_empty(),
			"Plans are taps, not a dropdown")
	var plan_btns := picker.find_children("PlayerPlan_*", "Button", false, false) if picker != null else []
	# Positions he could learn sit in their own group under the plans.
	var learn_grid: Node = current_scene.find_child("PlayerLearn", true, false)
	var learn_btns: Array = learn_grid.find_children("PlayerLearn_*", "Button", false, false) if learn_grid != null else []
	_check(plan_btns.size() + learn_btns.size() == _state.plans_for(first).size(),
			"Every plan he can follow is shown (%d)" % (plan_btns.size() + learn_btns.size()))
	var small_plan := false
	for b in plan_btns:
		if b.size.y < 44:
			small_plan = true
	_check(not small_plan, "Every plan is a thumb-sized tap")
	_check(picker != null and picker.find_child("PlayerPlan_manual", false, false) == null,
			"There is no Manual plan to pick")
	var other_key := ""
	for k in _state.plans_for(first):
		if str(k) != _state.plan_for(first) and not str(k).begins_with(_state.LEARN_PREFIX):
			other_key = str(k)
			break
	var other_btn: Button = picker.find_child("PlayerPlan_" + other_key, false, false) if picker != null and other_key != "" else null
	if other_btn != null:
		other_btn.emit_signal("pressed")
	await _settle()
	_check(_state.plan_for(first) == other_key, "Tapping a plan sets his plan")
	var adv: Button = current_scene.find_child("AdvancedToggle", true, false)
	_check(adv != null and adv.text == "Stats" and current_scene.find_child("ManualWarning", true, false) == null,
			"His stats sit behind one button; there is no hand training")
	if adv != null:
		adv.emit_signal("pressed")
		await _settle()
	var adv2: Button = current_scene.find_child("AdvancedToggle", true, false)
	_check(adv2 != null and adv2.text.begins_with("Hide"), "The button opens his stats")
	# Back inside a player detail steps out to the list, not out of Training.
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training",
			"Back on a player detail stays on Training")
	_check(current_scene.find_child("PlayerPlan", true, false) == null
			and current_scene.find_child("TrainingRows", true, false) != null,
			"Back on a player detail returns to the list view")
	# The top-bar back steps out of the detail the same way.
	current_scene.call("_open_player", str(first["id"]))
	await _settle()
	var top_back: Button = current_scene.find_child("TopBarBack", true, false)
	_check(top_back != null, "The training top bar has a back button")
	if top_back != null:
		top_back.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "training"
			and current_scene.find_child("TrainingRows", true, false) != null,
			"The top-bar back steps out of the detail, not out of Training")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub",
			"Once the detail is closed, back leaves Training for the previous screen")
	_router.go("training")
	await _settle()
	_check(current_scene.find_child("TrainingIntro", true, false) == null,
			"The intro does not show again")
	# Position tabs list everyone who can play there (Ratings.plays_role, the
	# draft's and selection's rule); All lists each player once.
	var dual := {}
	for p in _state.my_list:
		var r2 := str(p.get("role2", ""))
		if r2 != "" and r2 != str(p["role"]):
			dual = p
			break
	_check(not dual.is_empty(), "The list has a dual-position player to test with")
	if not dual.is_empty():
		var tid := "Trainee_" + str(dual["id"])
		for role in [str(dual["role"]), str(dual["role2"])]:
			current_scene.call("_set_role", role)
			await _settle()
			_check(current_scene.find_child(tid, true, false) != null,
					"A %s/%s player is under the %s tab" % [dual["role"], dual["role2"], role])
		current_scene.call("_set_role", "")
		await _settle()
		var seen := 0
		for n in current_scene.find_children(tid, "", true, false):
			seen += 1
		_check(seen == 1, "All lists him once")
	# A press that turns into a scroll is neither a tap nor a long press: a
	# slow swipe through the list opens and group-selects nobody, while a
	# still hold and a still tap work as before.
	var ls: ScrollContainer = current_scene.get("_list_scroll")
	var trainees: Array = current_scene.find_children("Trainee_*", "Button", true, false)
	_check(ls != null and trainees.size() >= 2, "The training list has rows to swipe")
	# The training grid scrolls as one page with no scrollbar, and its cards
	# are checked in the training suite (the old list's scrollbar and row
	# checks went with the list).
	if ls != null and trainees.size() >= 2:
		var row: Button = trainees[1]
		var pid := str(row.name).trim_prefix("Trainee_")
		row.emit_signal("button_down")
		ls.scroll_vertical += 120
		await create_timer(0.6).timeout
		# A long press that fired would have rebuilt the list and freed the row.
		if is_instance_valid(row):
			row.emit_signal("button_up")
			row.emit_signal("pressed")
		await _settle()
		_check(ls.scroll_vertical > 0 and (current_scene.get("_bulk_selected") as Dictionary).is_empty()
				and not bool(current_scene.get("_showing_detail")),
				"A slow swipe through the training list selects nobody")
		row = current_scene.find_child("Trainee_" + pid, true, false)
		if row != null:
			row.emit_signal("button_down")
			await create_timer(0.6).timeout
			if is_instance_valid(row):
				row.emit_signal("button_up")
		await _settle()
		_check((current_scene.get("_bulk_selected") as Dictionary).has(pid), "A still long press starts a group")
		current_scene.set("_bulk_selected", {})
		current_scene.call("_build")
		await _settle()
		var row2: Button = current_scene.find_child("Trainee_" + pid, true, false)
		if row2 != null:
			row2.emit_signal("button_down")
			row2.emit_signal("button_up")
			row2.emit_signal("pressed")
			await _settle()
		_check(bool(current_scene.get("_showing_detail")), "A still tap still opens the player")
		current_scene.set("_showing_detail", false)
		current_scene.call("_build")
		await _settle()
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "Back from a plain Training list leaves the screen")

	# --- back after coming back: hub -> My list -> Training -> back -> back ----
	# Router.back() used to leave the screen it returned to on the stack twice,
	# so the next back stayed put (My list's back arrow "did nothing").
	_state.my_list[0]["club"] = "COL" if _state.my_club != "COL" else "GEE"
	_router.go("list")
	await _settle()
	_router.go("training")
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "list" and _router.stack.count("list") == 1,
			"Back returns to My list without stacking it twice")
	# Everyone on My list wears your club's colours, whatever club he came
	# from (a league re-draft leaves his source club in p["club"]).
	current_scene.set("_pane", "list")
	current_scene.call("_build")
	await _settle()
	# STYLE-05: the guernsey is his number in your club's ink.
	var mine_col: Color = load("res://scripts/ui/UiKit.gd").club_ink(_state.my_club)
	var guernseys: Array = current_scene.find_children("Guernsey", "Label", true, false)
	var all_ours := not guernseys.is_empty()
	for g in guernseys:
		all_ours = all_ours and (g as Label).get_theme_color("font_color").is_equal_approx(mine_col)
	_check(all_ours, "My list: every guernsey is your club's (%d rows)" % guernseys.size())
	var list_back: Button = current_scene.find_child("TopBarBack", true, false)
	_check(list_back != null, "My list has a back arrow")
	if list_back != null:
		list_back.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub", "Its back arrow then returns to the hub")

	# --- a live match swallows back until full time --------------------------
	_check(_state.prepare_interactive_match(), "A live match is prepared")
	_router.go("match")
	await _settle()
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "match", "Back cannot abandon a live match")
	_check(current_scene.find_child("RotationPicker", true, false) == null
			and current_scene.find_child("LegsView", true, false) != null
			and current_scene.find_child("PlanPicker", true, false) != null,
			"The coach box offers gameplan and a legs report; rotations are automatic")
	# Play quarters until the match stops for a coach's call, then answer it.
	var sim = _state.pending_sim
	var start_btn: Button = current_scene.find_child("StartQuarter", true, false)
	start_btn.emit_signal("pressed")
	await _settle()
	var guard := 0
	while sim.pending_moment.is_empty() and sim.current_quarter <= 4 and guard < 6:
		guard += 1
		if not sim.quarter_in_progress():
			current_scene.call("_simulate_next_quarter", {"gameplan": "balanced"})
			await _settle()
	var had_moment: bool = not sim.pending_moment.is_empty()
	_check(had_moment, "A live match stops for a coach's call")
	if had_moment:
		current_scene.call("_show_moment")
		await _settle()
		var card = current_scene.find_child("MomentCard", true, false)
		var pick: Button = card.find_child("Moment_0", true, false) if card != null else null
		_check(pick != null, "The call shows as a card with its options")
		var before: int = sim.moments.size()
		if pick != null:
			pick.emit_signal("pressed")
			await _settle()
		_check(sim.moments.size() == before + 1 and current_scene.find_child("MomentCard", true, false) == null,
				"Choosing an option resolves the call and play goes on")
	current_scene.call("_on_skip")
	for i in range(30):
		await process_frame
	_check(_state.pending_match.is_empty(), "Skip still finishes the match")
	_router.handle_back(true)
	await _settle()
	# A conference the match raised opens over the hub as its own screen.
	await _past_press()
	_check(_router.current() == "hub", "After full time, back returns to the hub")
	_check(not (_state.last_match.get("moments", []) as Array).is_empty(),
			"The played match keeps its calls for the readout")

	# --- off-season: trades & contracts ----------------------------------------
	var season = _state.season
	season.round_index = season.fixture.size()
	_state.ensure_finals()
	while not season.is_season_over():
		_state.advance()
	# A strong season ends with a rival board's letter that holds the
	# off-season (ClubMoves, its own test below); this part is about the
	# off-season at his club, so he stays put.
	var moves = load("res://scripts/state/ClubMoves.gd")
	if moves.letter_open(_state):
		moves.decline_letter(_state)
	# Nor is it about a sacking: the seeded season's results move whenever the
	# match does (rival clubs' game-plan traits did), so he keeps his job here.
	var was_sacked: bool = _state.is_sacked()
	_state.board.erase("sacked")
	# The first postseason's sheet has its own suite (first_visit_intro).
	_state.postseason_intro_seen = true
	# A card the season's end raised (a Grand Final loss has one) has its own
	# sheet test; here it sits on the hub without opening over it.
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	# A season that ends in a final can raise a press conference over the hub.
	await _past_press()
	_check(_screen_text().contains("Trades & Contracts"), "The hub offers Trades & Contracts after the season (sacked at the end: %s, letter open: %s; %s)"
			% [was_sacked, moves.letter_open(_state), _screen_text().left(200)])
	var more: Button = current_scene.find_child("NewsMore", true, false)
	_check(more != null, "The hub shows the league news")
	if more != null:
		more.emit_signal("pressed")
		await _settle()
	_check(current_scene.find_child("NewsFeed", true, false) != null
			and _screen_text().contains("premiers"), "More opens the full news feed")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("NewsFeed", true, false) == null,
			"Back closes the news feed and stays on the hub (on %s, feed open: %s, stack %s; %s)" % [_router.current(),
			current_scene.find_child("NewsFeed", true, false) != null, _router.stack, _screen_text().left(160)])
	var offseason_size_before := root.size
	root.size = Vector2i(360, 800)
	_router.go("offseason")
	await _settle()
	_check(_screen_text().contains("Out of contract"), "The contracts tab lists who is out of contract")
	var phone_view := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	for tab_name in ["Tab_contracts", "Tab_agents", "Tab_trade"]:
		var phone_tab: Control = current_scene.find_child(tab_name, true, false)
		_check(phone_tab != null and phone_view.encloses(phone_tab.get_global_rect())
				and phone_tab.size.y >= 40,
				"Off-season " + tab_name.trim_prefix("Tab_") + " tab fits a 360px phone")
	_check(current_scene.find_children("Resign_*", "Button", true, false).is_empty(),
			"No one-tap re-signing: contracts go through talks")
	var talk = current_scene.find_child("Negotiate", true, false)
	_check(talk != null, "An out-of-contract player can be talked to")
	if talk != null:
		var payroll_before: int = _state.my_payroll()
		talk.emit_signal("pressed")
		await _settle()
		_check(current_scene.find_child("ContractTalks", true, false) != null
				and current_scene.find_child("MakeOffer", true, false) != null
				and _screen_text().contains("Cap room after this deal"),
				"Talks open a sheet with salary, term and the cap consequence")
		_check(_state.my_payroll() == payroll_before, "Opening talks signs nothing")
		_router.handle_back(true)
		await _settle()
		_check(_router.current() == "offseason" and current_scene.find_child("ContractTalks", true, false) == null,
				"Back closes the talks and stays on Trades & Contracts")
		# Under 50/100 the talks say the chance he won't re-sign before any offer;
		# at 50 they say nothing about it.
		var trow: Node = talk.get_parent()
		while trow != null and not str(trow.name).begins_with("Contract_"):
			trow = trow.get_parent()
		var tid := str(trow.name).trim_prefix("Contract_") if trow != null else ""
		var tkey := Trust.player_key(tid)
		var rel_before: Dictionary = _state.relations.duplicate(true)
		_state.relations.erase(tkey)
		current_scene.call("_open_talks", tid)
		await _settle()
		var at_fifty: bool = current_scene.find_child("TalksRefuse", true, false) == null
		_router.handle_back(true)
		await _settle()
		Trust.change(_state.relations, tkey, -12, "You dropped him", _state.season_year, "Round 3")
		current_scene.call("_open_talks", tid)
		await _settle()
		var refuse: Control = current_scene.find_child("TalksRefuse", true, false)
		var refuse_text := ""
		if refuse is RichTextLabel:
			refuse_text = (refuse as RichTextLabel).get_parsed_text()
		elif refuse != null:
			refuse_text = str(refuse.get("text"))
		_check(tid != "" and at_fifty and refuse != null and refuse.is_visible_in_tree()
				and refuse_text == "His opinion of you: 44/100. 6% he won't re-sign with you.",
				"Talks at 44/100 say the chance he won't re-sign before you offer, and at 50 say nothing (%s)" % refuse_text)
		_router.handle_back(true)
		await _settle()
		_state.relations = rel_before
	for tab in ["Tab_agents", "Tab_trade"]:
		var tb: Button = current_scene.find_child(tab, true, false)
		tb.emit_signal("pressed")
		await _settle()
		if tab == "Tab_agents" and not _state.free_agents.is_empty():
			_check(current_scene.find_children("Sign_*", "Button", true, false).is_empty(),
					"No one-tap free-agent signing")
			var fa_talk = current_scene.find_child("FreeAgentTalks", true, false)
			# Prefer a free agent with rival offers, to see the offers table.
			for fa in _state.free_agents:
				if not (_state.fa_offers(str(fa["id"])) as Array).is_empty():
					var row = current_scene.find_child("Agent_" + str(fa["id"]), true, false)
					if row != null and row.find_child("FreeAgentTalks", true, false) != null:
						fa_talk = row.find_child("FreeAgentTalks", true, false)
						break
			_check(fa_talk != null, "A free agent can be talked to")
			if fa_talk != null:
				var list_before: int = _state.my_list.size()
				fa_talk.emit_signal("pressed")
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) != null
						and _screen_text().contains("Cap room after this deal")
						and _state.my_list.size() == list_before,
						"Free-agent talks open the same sheet and sign nothing")
				var table = current_scene.find_child("OffersTable", true, false)
				var view_w: float = current_scene.get_viewport_rect().size.x
				_check(table != null and (table as Control).get_global_rect().end.x <= view_w + 0.5
						and _screen_text().contains("His view"),
						"Rival offers show as a table that fits the screen (%s of %d)" % [
						str((table as Control).get_global_rect().end.x) if table != null else "none", int(view_w)])
				_router.handle_back(true)
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) == null, "Back closes free-agent talks")
	# The trade builder: one list at a time, what you give and get on top.
	var theirs_btn = null
	for n in current_scene.find_children("Their_*", "Button", true, false):
		theirs_btn = n
		break
	_check(theirs_btn != null and current_scene.find_child("TradeSide_mine", true, false) != null
			and current_scene.find_children("Mine_*", "Button", true, false).is_empty(),
			"The trade builder shows one list at a time: theirs, with yours a tap away")
	var phone_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	var builder_fits := true
	for nm in ["TradeClub", "MakeTrade", "TradeSide_theirs", "TradeSide_mine"]:
		var c: Control = current_scene.find_child(nm, true, false)
		builder_fits = builder_fits and c != null and c.get_global_rect().end.x <= phone_rect.end.x and c.size.y >= 40
	_check(builder_fits, "The trade builder's controls fit a 360px phone at thumb size")
	root.size = offseason_size_before
	await _settle()
	var theirs_now := current_scene.find_children("Their_*", "Button", true, false)
	if not theirs_now.is_empty():
		theirs_now[0].emit_signal("pressed")
		await _settle()
	current_scene.find_child("TradeSide_mine", true, false).emit_signal("pressed")
	await _settle()
	for n in current_scene.find_children("Mine_*", "Button", true, false):
		if not str(n.name).begins_with("Mine_pick_"):
			n.emit_signal("pressed")
			await _settle()
			break
	_check(current_scene.find_children("GiveRow_*", "", true, false).size() == 1
			and current_scene.find_children("GetRow_*", "", true, false).size() == 1,
			"What you give and what you get each show in their own section")
	var verdict = current_scene.find_child("TradeVerdict", true, false)
	_check(verdict != null and str(verdict.text) != "" and not str(verdict.text).contains("Put something on each side"),
			"With something on each side, their answer shows")
	var decimal := RegEx.create_from_string("\\d\\.\\d|%")
	# Money is real AFL money ("$18.44m"); anything else with a decimal or a
	# percentage would be a model value leaking out.
	# The familiarity line states its percentages on purpose (row 125): a gate's numbers.
	var fam_line: String = load("res://scripts/sim/TeamFamiliarity.gd").signing_line()
	# So does the team rating: the ladder's number, to one decimal (row 177).
	var rated := RegEx.create_from_string("Team rating [0-9.]+[.] On this list, [0-9.]+ in three years[.]").sub(_screen_text().replace(fam_line, ""), "", true)
	var no_money := RegEx.create_from_string("\\$[0-9][0-9.,]*[mk]?").sub(rated, "", true)
	var leak := decimal.search(no_money)
	_check(leak == null, "The trade screen shows no internal values (%s)" % (no_money.substr(maxi(0, leak.get_start() - 40), 80) if leak else ""))
	_check(current_scene.find_child("TradeClubPhase", true, false) != null,
			"The trade tab says where the other club is in its cycle")
	var pick_btns := current_scene.find_children("Mine_pick_*", "Button", true, false)
	_check(pick_btns.size() >= 2 and str((pick_btns[0] as Button).text).contains("first round"),
			"Your draft picks, this year's and next, can go in a trade")
	if not pick_btns.is_empty():
		pick_btns[0].emit_signal("pressed")
		await _settle()
		var pick_row = current_scene.find_child("GiveRow_pick_*", true, false)
		_check(pick_row != null and current_scene.find_children("GiveRow_*", "", true, false).size() == 2,
				"A pick joins what you give")
		if pick_row != null:
			pick_row.find_child("Remove", true, false).emit_signal("pressed")
			await _settle()
			_check(current_scene.find_children("GiveRow_*", "", true, false).size() == 1, "Remove takes it out")
	# Changing club: every other club, two to a row; Back closes it.
	current_scene.find_child("TradeClub", true, false).emit_signal("pressed")
	await _settle()
	var club_grid = current_scene.find_child("TradeClubChoice", true, false)
	_check(club_grid != null and club_grid.get_child_count() == _db.active_clubs(_state.season_year).size() - 1
			and int(club_grid.columns) == 2, "Change club lists every other club, two to a row")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "offseason" and current_scene.find_child("TradeClubChoice", true, false) == null
			and current_scene.find_children("GiveRow_*", "", true, false).size() == 1,
			"Back closes the club list and keeps the trade")
	current_scene.find_child("TradeClub", true, false).emit_signal("pressed")
	await _settle()
	var other_club = null
	for n in current_scene.find_child("TradeClubChoice", true, false).get_children():
		if str(n.name) != "TradeClubChoice_" + str(current_scene.get("_trade_club")):
			other_club = n
			break
	other_club.emit_signal("pressed")
	await _settle()
	_check(current_scene.find_children("GetRow_*", "", true, false).is_empty()
			and current_scene.find_children("GiveRow_*", "", true, false).size() == 1,
			"A new club clears what you'd get from the old one and keeps what you give")
	# One thing on your side and nothing on theirs: put it on the trade table.
	var table_btn = current_scene.find_child("TradeTable", true, false)
	_check(table_btn != null and not (table_btn as Button).disabled, "With one of yours and nothing back, it can go on the trade table")
	if table_btn != null:
		table_btn.emit_signal("pressed")
		await _settle()
		var said = current_scene.find_child("OffseasonNotice", true, false)
		var said_text := ""
		if said is RichTextLabel:
			said_text = (said as RichTextLabel).get_parsed_text()
		elif said is Label:
			said_text = (said as Label).text
		_check(said_text.contains("offer") and current_scene.find_children("GiveRow_*", "", true, false).is_empty(),
				"The trade table says who came, and clears what you give (%s; %d left)" % [current_scene.get("_notice"), current_scene.find_children("GiveRow_*", "", true, false).size()])
	# A player elsewhere who asked to be traded and named your club: a line
	# under Asked to be traded, and one tap starts the trade for him.
	var rival_code := ""
	for code in _state.season.lists:
		if str(code) != _state.my_club:
			rival_code = str(code)
			break
	var asker: Dictionary = _state.season.lists[rival_code][0]
	var keep_requests: Dictionary = (_state.trade_requests as Dictionary).duplicate(true)
	_state.trade_requests = {str(asker["id"]): {"club": rival_code, "why": "home", "to": [_state.my_club]}}
	current_scene.call("_build")
	await _settle()
	var req_btn = current_scene.find_child("RequestTrade", true, false)
	_check(current_scene.find_child("Request_" + str(asker["id"]), true, false) != null and req_btn != null,
			"A player who named your club shows under Asked to be traded")
	if req_btn != null:
		req_btn.emit_signal("pressed")
		await _settle()
	_check(str(current_scene.get("_trade_club")) == rival_code and str(current_scene.get("_theirs")) == str([str(asker["id"])]),
			"Trade for him opens the trade with his club, him on their side")
	_state.trade_requests = keep_requests
	current_scene.call("_build")
	await _settle()
	# Picking a player rebuilds the tab but keeps your place in a long list.
	var box: ScrollContainer = current_scene.get("_scroll_box")
	box.scroll_vertical = 600
	await _settle()
	var held := box.scroll_vertical
	var deep = null
	for n in current_scene.find_children("Mine_*", "Button", true, false):
		deep = n
	var found: bool = deep != null
	if found:
		deep.emit_signal("pressed")
		await _settle()
		await _settle()
	var after: ScrollContainer = current_scene.get("_scroll_box")
	_check(held > 0 and found and absi(after.scroll_vertical - held) <= 4,
			"Picking a player keeps the trade list where it was (%d then %d)" % [held, after.scroll_vertical])
	_router.handle_back(true)
	await _settle()

	# --- New Career asks before replacing a career ---------------------------
	_router.to_main_menu(false)
	await _settle()
	var new_btn: Button = current_scene.find_child("NewCareer", true, false)
	new_btn.emit_signal("pressed")
	await _settle()
	await _pick_year()
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	var confirm = current_scene.find_child("ConfirmNewCareer", true, false)
	_check(confirm != null, "New Career asks for confirmation over an existing career")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "main"
			and current_scene.find_child("ConfirmNewCareer", true, false) == null
			and current_scene.find_child("NewCareerSetup", true, false) != null,
			"Back cancels the confirmation and stays on the setup")
	_check(_state.season != null and _state.has_saved_career(),
			"Cancelling keeps the career and the save")
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	confirm = current_scene.find_child("ConfirmNewCareer", true, false)
	if confirm != null:
		confirm.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "draft", "Confirming starts a new career at the draft")
	_check(_state.has_saved_career(), "The old save is kept until the new career has a club (Back must not lose it)")
	_check(_state.season == null and _state.draft != null, "The new career starts empty")

	# --- Escape on the main menu never quits ---------------------------------
	_router.to_main_menu(false)
	await _settle()
	current_scene.call("_show_help")
	await _settle()
	var menu_guide: Button = current_scene.find_child("MenuStatGuide", true, false)
	menu_guide.emit_signal("pressed")
	await _settle()
	_check(current_scene.find_child("StatGuide", true, false) != null,
			"How It Works opens the stat guide")
	_router.handle_back(false)
	await _settle()
	_check(current_scene.find_child("StatGuide", true, false) == null and _router.current() == "main",
			"Escape closes the guide on the menu")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main", "Escape on the main menu does nothing")

	# --- Hub rating lines --------------------------------------------------
	_state.reset()
	_state.start_season("SYD", _db.club_list("SYD"))
	var ask_before: bool = _state.confirm_sim_round()
	_state.set_confirm_sim_round(false)
	_router.go("hub")
	await _settle()
	# The line under each club on the hub says the same numbers the game holds (TeamRating).
	var own_line: Label = current_scene.find_child("MyTeamOutlook", true, false)
	var opp_line: Label = current_scene.find_child("OppTeamOutlook", true, false)
	var own_o: Dictionary = _state.team_outlook(_state.my_club)
	var opp_o: Dictionary = _state.team_outlook(str(_state.my_next_opponent().get("code", "")))
	var rating_tail := "%s. Team rating %.1f. On this list, %.1f in three years."
	_check(own_line != null and opp_line != null
			and own_line.text == rating_tail % [own_o["category"], own_o["rating"], own_o["forecast"]]
			and opp_line.text.ends_with(rating_tail % [opp_o["category"], opp_o["rating"], opp_o["forecast"]])
			and own_line.autowrap_mode != TextServer.AUTOWRAP_OFF and opp_line.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"The hub's two rating lines read as the game's numbers and wrap rather than cut off (%s | %s)" % [own_line.text if own_line else "-", opp_line.text if opp_line else "-"])
	_state.set_confirm_sim_round(true)

	# --- Settings from the hub: speed, the menu, and deleting the career ----
	_router.go("hub")
	await _settle()
	var hub_settings: Button = current_scene.find_child("HubSettings", true, false)
	_check(hub_settings != null and hub_settings.size.y >= 44, "Settings is on the hub's top bar")
	var board_was: String = _state.board_patience
	var rivals_was: String = _state.rival_recruiting
	# The hub's board warning fires under the poor line (ClubLife.POOR_LINE, 40) on every
	# board type: at 39 all three warn, at 40 none does.
	var conf_was: int = _state.board_confidence()
	var warned_was: bool = bool(_state.board.get("warned", false))
	var seen := {}
	for conf in [39, 40]:
		for step in ["patient", "fair", "ruthless"]:
			_state.board["confidence"] = conf
			_state.board["warned"] = false
			_state.board_patience = step
			_router.go("hub")
			await _settle()
			var warn_l: Label = current_scene.find_child("BoardWarning", true, false)
			var line_l: Label = current_scene.find_child("BoardLine", true, false)
			seen["%s_%d" % [step, conf]] = [warn_l.text if warn_l != null else "", line_l != null]
	var all_warn := true
	var none_at_40 := true
	for step in ["patient", "fair", "ruthless"]:
		var at39: Array = seen["%s_39" % step]
		var at40: Array = seen["%s_40" % step]
		all_warn = all_warn and str(at39[0]).begins_with("Board confidence is poor (39%). ") and bool(at39[1])
		none_at_40 = none_at_40 and str(at40[0]) == "" and not bool(at40[1])
	_check(all_warn and none_at_40, "On every board type the hub warns at 39 and not at 40 (%s)" % str(seen))
	_state.board["confidence"] = conf_was
	_state.board["warned"] = warned_was
	hub_settings = current_scene.find_child("HubSettings", true, false)
	_state.board_patience = "patient"
	_state.rival_recruiting = "cutthroat"
	if hub_settings != null:
		hub_settings.emit_signal("pressed")
		await _settle()
	var eight: Button = current_scene.find_child("SettingsSpeed_8", true, false)
	_check(eight != null and current_scene.find_child("OptionsMainMenu", true, false) != null
			and current_scene.find_child("OptionsNewCareer", true, false) != null
			and current_scene.find_child("OptionsVersion", true, false) != null,
			"Settings in a career has speed, main menu, New career and version")
	var ver_label: Label = current_scene.find_child("OptionsVersion", true, false) as Label
	var project_version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(ver_label != null and project_version != ""
			and ver_label.text.begins_with("Version " + project_version),
			"Settings shows the version read from project.godot config/version (%s)" % project_version)
	var dials_line: Label = current_scene.find_child("OptionsCareerDials", true, false)
	_check(dials_line != null and dials_line.visible
			and dials_line.text == "This career: Patient board · Cut-throat rivals.",
			"Settings shows the career's two dial steps in one read-only line")
	_state.board_patience = board_was
	_state.rival_recruiting = rivals_was
	if eight != null:
		eight.emit_signal("pressed")
		await _settle()
	_check(is_equal_approx(_state.match_speed(), 8.0), "Match speed is remembered")
	_state.set_match_speed(4.0)
	_check(_state.save_career(), "The career is saved before the destructive-action tests")
	var new_from_settings: Button = current_scene.find_child("OptionsNewCareer", true, false)
	if new_from_settings != null:
		new_from_settings.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "main"
			and current_scene.find_child("NewCareerSetup", true, false) != null
			and _state.has_saved_career(),
			"New career opens setup without deleting the current save")
	_router.handle_back(false)
	await _settle()
	if str(current_scene.get("_mode")) == "year":
		# Setup -> the year step -> the title screen.
		_router.handle_back(false)
		await _settle()
	var saved_continue: Button = current_scene.find_child("ContinueCareer", true, false)
	if saved_continue != null:
		saved_continue.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub" and _state.season != null,
			"Backing out of New career can still resume the saved career")
	hub_settings = current_scene.find_child("HubSettings", true, false)
	if hub_settings != null:
		hub_settings.emit_signal("pressed")
		await _settle()
	current_scene.find_child("OptionsDelete", true, false).emit_signal("pressed")
	await _settle()
	current_scene.find_child("OptionsDeleteCancel", true, false).emit_signal("pressed")
	await _settle()
	_check(_state.has_saved_career() and _state.season != null, "Keep it cancels the delete")
	current_scene.find_child("OptionsDelete", true, false).emit_signal("pressed")
	await _settle()
	var sure: Button = current_scene.find_child("OptionsDeleteConfirm", true, false)
	_check(sure != null and sure.is_visible_in_tree(), "Deleting asks first")
	if sure != null:
		sure.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "main" and not _state.has_saved_career() and _state.season == null,
			"Delete this career removes the save and returns to the menu")


## The top bar's back arrow, tapped as a finger taps it, leaves every screen -
## first closing a first-visit help sheet over it, as Android's Back does
## (director, 2026-10-09: "back doesn't always work, I need to swipe": the
## Training and Season stats intros took the tap and did nothing).
func _test_back_arrow_taps() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_state.set_setting("seen_season_stats_intro", false)
	for key in ["training", "stats", "selection", "list"]:
		_router.stack = ["main", "hub"]
		_router.go(key)
		await _settle()
		var b: Control = current_scene.find_child("TopBarBack", true, false)
		var why: String = await Tap.tap(b) if b != null else "no back arrow"
		await _settle()
		if _router.current() == key and is_instance_valid(b):
			why = await Tap.tap(b)
			await _settle()
		_check(_router.current() == "hub", "Tapping back on %s gets you out (%s)" % [key, why if why != "" else "ok"])


## P-37, the club remembers him (director, 2026-10-18). A seeded Fremantle list:
## one player with a premiership, a best and fairest, a debut with a goal in it
## and an injury he came back from; another with only the injury; a third with
## nothing. The sheet shows the three that matter most, newest first, and the
## injury waits; the release confirm says the one biggest fact, and a real tap on
## Release then Cancel leaves him and every fact where they were.
func _test_remembered() -> void:
	var sheet_script = load("res://scripts/ui/PlayerSheet.gd")
	var facts_script = load("res://scripts/sim/CareerFacts.gd")
	var kit = load("res://scripts/ui/UiKit.gd")
	_state.reset()
	_state.career_seed = 7737
	_state.replay_seed = 7737
	_state.start_season("FRE", _db.club_list("FRE"))
	var year: int = _state.season_year
	var young: Array = _state.my_list.filter(func(q): return float(q.get("age", 30.0)) < 26.0)
	var star: Dictionary = young[0]
	var hurt: Dictionary = young[1]
	var blank: Dictionary = young[2]
	var star_id := str(star["id"])
	star["career"] = {"games": 12, "goals": 14, "through": year - 1, "unknown": [],
			"stints": [["FRE", year - 2, year - 1, 12, 14]]}
	star["firsts"] = {"debut": {"year": year - 2, "label": "Round 7"}, "goal": {"year": year - 2, "label": "Round 7"}}
	_state.honour_roll = [{"year": year - 1, "my_club": "FRE", "premier": "", "my_bf": [{"id": star_id}]},
			{"year": year - 2, "my_club": "FRE", "premier": "FRE", "my_bf": []}]
	facts_script.add(_state.career_facts, star_id, facts_script.row(year - 1, "Round 3", "injury", "FRE", "", "hamstring"))
	hurt["career"] = {"games": 5, "goals": 0, "through": year - 1, "unknown": [],
			"stints": [["FRE", year - 1, year - 1, 5, 0]]}
	facts_script.add(_state.career_facts, str(hurt["id"]), facts_script.row(year - 1, "Round 3", "injury", "FRE", "", "knee"))
	blank["career"] = {"games": 0, "goals": 0, "through": year - 1, "unknown": [], "stints": []}
	blank.erase("firsts")
	blank.erase("backed")
	_state.career_facts.erase(str(blank["id"]))
	_state.season_tally.erase(str(blank["id"]))
	for q in [star, hurt, blank]:
		for key in ["injury_weeks", "injury_kind", "suspension_weeks"]:
			q.erase(key)
	root.size = Vector2i(390, 844)

	# The sheet: three lines, newest first; the injury does not make the cut.
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var sheet: Control = sheet_script.open(host, star)
	await _settle()
	var lines := []
	for i in range(5):
		var l := sheet.find_child("Remembered_%d" % i, true, false) as Label
		if l != null:
			lines.append(l.text)
	_check(lines == ["Doig Medal, %d." % (year - 1), "Premiership, %d." % (year - 2),
			"Debuted in Round 7, %d, and kicked his first goal." % (year - 2)],
			"His sheet has three remembered facts, newest first, and not the injury (%s)" % str(lines))
	var title := sheet.find_child("WithUsTitle", true, false) as Label
	var name_l := sheet.find_child("ProfileName", true, false) as Label
	var ink: Color = kit.club_name_colour(kit.club_ink("FRE"))
	_check(title != null and title.text == "With us" and title.get_theme_color("font_color").is_equal_approx(ink)
			and name_l != null and name_l.get_theme_color("font_color").is_equal_approx(ink),
			"The block and his name are in Fremantle's ink, not grey")
	sheet.queue_free()
	var sheet2: Control = sheet_script.open(host, hurt)
	await _settle()
	var l2 := sheet2.find_child("Remembered_0", true, false) as Label
	_check(l2 != null and l2.text == "Knee injury in Round 3, %d; he came back." % (year - 1),
			"With nothing bigger, the injury he came back from is on his sheet (%s)" % (l2.text if l2 != null else "none"))
	sheet2.queue_free()
	var sheet3: Control = sheet_script.open(host, blank)
	await _settle()
	_check(sheet3.find_child("WithUsTitle", true, false) == null,
			"Someone yet to play for you has no With us block")
	sheet3.queue_free()
	host.queue_free()
	await _settle()

	# The release confirm, by a finger.
	_state.season.round_index = _state.season.fixture.size()
	_state.open_offseason()
	for q in [star, hurt, blank]:
		q["contract_years"] = 1
		q.erase("retiring")
		q.erase("resigned")
	# Room to let one go: a list at its minimum cannot release anyone.
	for i in range(3):
		var extra: Dictionary = blank.duplicate(true)
		extra["id"] = "rem_extra_%d" % i
		_state.my_list.append(extra)
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	var facts_before := (_state.career_facts.get(star_id, []) as Array).size()
	var list_before: int = _state.my_list.size()
	var row := scene.find_child("Contract_" + star_id, true, false)
	var release: Button = row.find_child("Release", true, false) if row != null else null
	var why: String = await Tap.tap(release) if release != null else "no Release button"
	await _settle()
	var said := scene.find_child("ReleaseRemembered", true, false) as Control
	_check(why == "" and said != null and scene.find_child("ReleaseConfirmation", true, false) != null,
			"A finger on Release opens the confirm (%s)" % why)
	var said_text: String = (said as Label).text if said is Label else ""
	_check(said_text == "He was with you for the %d premiership." % (year - 2),
			"The confirm says the biggest remembered fact (%s)" % said_text)
	var cancel: Button = scene.find_child("CancelRelease", true, false)
	var why_c: String = await Tap.tap(cancel) if cancel != null else "no Cancel"
	await _settle()
	_check(why_c == "" and scene.find_child("ReleaseConfirmation", true, false) == null
			and _state.my_list.size() == list_before
			and (_state.career_facts.get(star_id, []) as Array).size() == facts_before,
			"A finger on Cancel leaves him on the list and every fact kept (%s)" % why_c)
	# A player with no past with you gets the same two buttons and no line.
	var brow := scene.find_child("Contract_" + str(blank["id"]), true, false)
	var brel: Button = brow.find_child("Release", true, false) if brow != null else null
	var why_b: String = await Tap.tap(brel) if brel != null else "no Release button"
	await _settle()
	_check(why_b == "" and scene.find_child("ConfirmRelease", true, false) != null
			and scene.find_child("ReleaseRemembered", true, false) == null,
			"With nothing to remember the confirm is quiet (%s)" % why_b)
	# He was also in the trade builder: releasing him takes him out of it.
	scene._mine = [str(blank["id"]), str(star_id)]
	var go: Button = scene.find_child("ConfirmRelease", true, false)
	var why_g: String = await Tap.tap(go) if go != null else "no confirm"
	await _settle()
	_check(why_g == "" and _state.list_player(str(blank["id"])).is_empty() and _state.my_list.size() == list_before - 1,
			"A finger on Release player lets him go (%s)" % why_g)
	_check(scene._mine == [str(star_id)], "A released player leaves the trade builder; the rest stay (%s)" % str(scene._mine))
	# Free-agent talks never start from the last player's term.
	_check(not _state.free_agents.is_empty(), "The off-season has free agents (%d)" % _state.free_agents.size())
	if not _state.free_agents.is_empty():
		var fa_id := str(_state.free_agents[0]["id"])
		scene._offer_years = 0
		scene._open_talks(fa_id, true)
		var own_years := int(scene._offer_years)
		scene._close_talks()
		scene._offer_years = 7
		scene._open_talks(fa_id, true)
		_check(own_years > 0 and int(scene._offer_years) == own_years,
				"Free-agent talks start from his own term (%d), not the last player's (%d)" % [own_years, int(scene._offer_years)])
		scene._close_talks()
	scene.queue_free()
	await _settle()


## The off-season brief and Ask around on a phone (P-48, P-50): three lines of
## facts open the screen; a finger asks around about a player, every rival
## answers once, nothing is offered or saved, and a keen club's answer opens
## the trade sheet filled in.
func _test_list_problem_and_ask_around() -> void:
	_state.reset()
	_state.career_seed = 5508
	_state.replay_seed = 5508
	_state.start_season("MEL", _db.club_list("MEL"))
	_state.season.round_index = _state.season.fixture.size()
	_state.open_offseason()
	var lines: Array = _state.list_problem()
	_check(lines.size() == 3 and str(lines[0]).contains("out of contract")
			and str(lines[1]).begins_with("Your best six average") and str(lines[2]).contains("draft"),
			"The list problem is three lines of fact (%s)" % " | ".join(lines))
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	var shown := []
	for i in 3:
		var l := scene.find_child("ListProblem_%d" % i, true, false) as Label
		shown.append(l.text if l != null else "")
	_check(shown == lines, "The screen opens with the three lines (%s)" % " | ".join(shown))
	var why_tab: String = await Tap.tap(scene.find_child("Tab_trade", true, false))
	await _settle()
	var why_side: String = await Tap.tap(scene.find_child("TradeSide_mine", true, false))
	await _settle()
	var side: Array = _state.my_list.duplicate()
	side.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var pid := str(side[3]["id"])
	var why_pick: String = await Tap.tap(scene.find_child("Mine_" + pid, true, false))
	await _settle()
	var offers_before: int = _state.trade_offers.size()
	var table_before: int = _state.trade_table.size()
	var dirty_list := str(_state.my_list.map(func(q): return q["id"]))
	var why_ask: String = await Tap.tap(scene.find_child("AskAround", true, false))
	await _settle()
	var rivals: int = _db.active_clubs(_state.season_year).size() - 1
	var answers := scene.find_children("Answer_*", "", true, false)
	_check(why_tab == "" and why_side == "" and why_pick == "" and why_ask == ""
			and scene.find_child("AskAnswers", true, false) != null and answers.size() == rivals,
			"A finger on Ask around gets one answer from each of %d rivals (%d; %s %s %s %s)" % [
			rivals, answers.size(), why_tab, why_side, why_pick, why_ask])
	_check(_state.trade_offers.size() == offers_before and _state.trade_table.size() == table_before
			and str(_state.my_list.map(func(q): return q["id"])) == dirty_list,
			"Asking around offers, tables and moves nothing")
	var again: Array = _state.ask_around(pid)
	var first: Array = _state.ask_around(pid)
	_check(str(again) == str(first), "Asking twice gets the same answers")
	var keen := first.filter(func(r): return str(r["kind"]) != "no")
	for r in first:
		_check(str(r["line"]).begins_with(_db.club_name(str(r["club"])) + ": "),
				"Each answer names its club first (%s)" % str(r["line"]))
	if not keen.is_empty():
		var club := str(keen[0]["club"])
		var why_go: String = await Tap.tap(scene.find_child("AskTrade_" + club, true, false))
		await _settle()
		_check(why_go == "" and scene.find_child("AskAnswers", true, false) == null,
				"A finger on Trade with them closes the answers (%s)" % why_go)
		_check(str(scene.get("_trade_club")) == club and str(scene.get("_mine")) == str(keen[0]["mine"])
				and str(scene.get("_theirs")) == str(keen[0]["theirs"]),
				"The trade sheet opens with that club and its answer filled in (%s %s)" % [scene.get("_trade_club"), scene.get("_mine")])
		_check(scene.find_children("GiveRow_*", "", true, false).size() == (keen[0]["mine"] as Array).size()
				and scene.find_child("TradeVerdict", true, false) != null,
				"What you give shows with a verdict (%d give rows)" % scene.find_children("GiveRow_*", "", true, false).size())
	else:
		_check(scene.find_children("AskTrade_*", "", true, false).is_empty(),
				"With nobody keen there is no way into a trade from the answers")
	scene.queue_free()
	root.size = size_before
	# Ask their price by a finger, in this same off-season (opening one costs
	# seconds), on a fresh screen: asking around offered, tabled and moved nothing.
	await _ask_price_tap_in_offseason()
	await _settle()


## Ask around names in their club's ink when the club is red (row 174; director
## 2026-11-12, "sanders uncoloured?"). The state that dropped it: Ryley Sanders
## at Essendon (his save had traded him there), whose red was turned to plain
## white for a player's name. Asked about from Essendon's list, his name in the
## heading is in Essendon's ink, never white, and every player an answer names
## is in his own club's ink (the red rivals' too).
func _test_ask_around_red_club_ink() -> void:
	_state.reset()
	_state.career_seed = 5508
	_state.replay_seed = 5508
	_state.start_season("ESS", _db.club_list("ESS"))
	var wbd: Array = _state.season.lists["WBD"]
	var sanders := {}
	for p in wbd:
		if _db.player_display_name(p) == "Ryley Sanders":
			sanders = p
	_check(not sanders.is_empty(), "Ryley Sanders is on the Bulldogs' list to start")
	if sanders.is_empty():
		return
	wbd.erase(sanders)
	sanders["club"] = "ESS"
	_state.season.lists["ESS"].append(sanders)
	_check(_state.list_player(str(sanders["id"])) == sanders, "He is on your Essendon list now")
	_state.season.round_index = _state.season.fixture.size()
	_state.open_offseason()
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	await Tap.tap(scene.find_child("Tab_trade", true, false))
	await _settle()
	await Tap.tap(scene.find_child("TradeSide_mine", true, false))
	await _settle()
	var why_pick: String = await Tap.tap(scene.find_child("Mine_" + str(sanders["id"]), true, false))
	await _settle()
	var why_ask: String = await Tap.tap(scene.find_child("AskAround", true, false))
	await _settle()
	var uk = load("res://scripts/ui/UiKit.gd")
	var ni = load("res://scripts/ui/NameInk.gd")
	var ink := "[color=#%s]Ryley%sSanders" % [uk.club_ink("ESS").to_html(false), ni.NBSP]
	var head := scene.find_child("AskHead", true, false)
	_check(why_pick == "" and why_ask == "" and head is RichTextLabel and (head as RichTextLabel).text.contains(ink),
			"A finger on Ask around heads the answers with his name in Essendon's red (%s %s %s)" % [why_pick, why_ask,
			(head as RichTextLabel).text if head is RichTextLabel else str(head)])
	# Every name in every answer: Sanders in Essendon's ink, each player offered
	# in his own club's (Gold Coast, Melbourne, St Kilda and Sydney are red too).
	var named := 0
	var reds := 0
	var bad := []
	var rows := {}
	for r in scene.get("_asked"):
		rows[str(r["club"])] = r
	for a in scene.find_children("Answer_*", "", true, false):
		var club := str(a.name).trim_prefix("Answer_")
		var bb := (a as RichTextLabel).text if a is RichTextLabel else ""
		var r: Dictionary = rows.get(club, {})
		for id in (r.get("mine", []) as Array) + (r.get("theirs", []) as Array):
			if str(id).begins_with("pick:"):
				continue
			var who: String = _state._ask_name(str(id))
			if not str(ni.plain(a)).contains(who):
				continue
			var owner := "ESS" if str(id) == str(sanders["id"]) else club
			named += 1
			reds += 1 if uk.club_name_colour(uk.club_ink(owner)) == uk.TEXT else 0
			if not bb.contains("[color=#%s]%s" % [uk.club_ink(owner).to_html(false), who.replace(" ", ni.NBSP)]):
				bad.append("%s: %s" % [club, ni.plain(a)])
	_check(named > 0 and reds > 0 and bad.is_empty(),
			"Every player named in the answers (%d, %d at red clubs) is in his club's ink, never white (%s)" % [named, reds, " | ".join(bad)])
	scene.queue_free()
	root.size = size_before
	await _settle()


## Ask their price on a phone (row 67): with one of their players on the sheet
## and nothing of yours, a finger on Ask their price fills what you give with
## their ask, shows it in a line under the sheet, and the verdict is yes.
func _test_ask_price_tap() -> void:
	# The search behind the tap: a club that turns down the forty cheapest
	# packages is still asked about the next ones near its price.
	var packs := []
	for i in range(500):
		packs.append([[i], 10.0 + 0.004 * i])
	var asked := []
	var pick: int = _state.ask_price_pick(packs, 10.0, func(x):
		asked.append(int(x[0][0]))
		return int(x[0][0]) == 60)
	_check(pick == 60 and asked.size() == 61,
			"The 61st cheapest package is found when the first sixty are turned down (found %d after %d)" % [pick, asked.size()])
	_check(_state.ask_price_pick(packs, 10.0, func(_x): return false) == -1, "No package they'd take: none named")
	asked = []
	_state.ask_price_pick(packs, 10.0, func(x):
		asked.append(int(x[0][0]))
		return false)
	_check(asked.size() == int(_state.ASK_PRICE_MOST), "The search stops after %d packages (%d weighed)" % [int(_state.ASK_PRICE_MOST), asked.size()])
	var dear := []
	for i in range(100):
		dear.append([[i], 20.0 + i])
	asked = []
	_state.ask_price_pick(dear, 10.0, func(x):
		asked.append(int(x[0][0]))
		return false)
	_check(asked.size() == int(_state.ASK_PRICE_TRIES),
			"Packages well over the price are weighed only among the first %d (%d weighed)" % [int(_state.ASK_PRICE_TRIES), asked.size()])
	# The tap runs in _test_list_problem_and_ask_around, on its off-season.


## The tap behind Ask their price, on the off-season already open.
func _ask_price_tap_in_offseason() -> void:
	_check(_state.offseason_year == _state.season_year and _state.my_club == "MEL", "(setup) Melbourne's off-season is open")
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	var club := str(scene.get("_trade_club"))
	var theirs: Array = (_state.season.lists[club] as Array).duplicate()
	theirs.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	var pid := ""
	var expect := {}
	for q in theirs.slice(0, 8):
		var r: Dictionary = _state.ask_price(club, str(q["id"]))
		if bool(r["ok"]):
			pid = str(q["id"])
			expect = r
			break
	_check(pid != "", "%s name a price for one of their best eight players" % _db.club_name(club))
	if pid == "":
		scene.queue_free()
		root.size = size_before
		await _settle()
		return
	var why_tab: String = await Tap.tap(scene.find_child("Tab_trade", true, false))
	await _settle()
	var why_side: String = await Tap.tap(scene.find_child("TradeSide_theirs", true, false))
	await _settle()
	var why_pick: String = await Tap.tap(scene.find_child("Their_" + pid, true, false))
	await _settle()
	var verdict := scene.find_child("TradeVerdict", true, false) as Control
	_check(why_tab == "" and why_side == "" and why_pick == "" and scene.find_child("AskPrice", true, false) != null,
			"With one of theirs and nothing of yours, Ask their price is there (%s %s %s)" % [why_tab, why_side, why_pick])
	var list_before := str(_state.my_list.map(func(q): return q["id"]))
	var why_ask: String = await Tap.tap(scene.find_child("AskPrice", true, false))
	await _settle()
	var said := scene.find_child("TradePrice", true, false)
	verdict = scene.find_child("TradeVerdict", true, false) as Control
	_check(why_ask == "" and str(scene.get("_mine")) == str(expect["mine"])
			and scene.find_children("GiveRow_*", "", true, false).size() == (expect["mine"] as Array).size(),
			"A finger on Ask their price fills what you give with their ask (%s; %s)" % [why_ask, str(scene.get("_mine"))])
	_check(said != null and str(said.get("text")).contains(" would take ") and verdict != null
			and str(verdict.get_meta("code", "")) == "trade_accept",
			"Their price shows in a line and the verdict is yes (%s)" % (str(said.get("text")) if said != null else "none"))
	_check(str(_state.my_list.map(func(q): return q["id"])) == list_before and scene.find_child("AskPrice", true, false) == null,
			"Asking moves nobody, and the button goes once you have something to give")
	scene.queue_free()
	root.size = size_before
	await _settle()


## The finals cards on a phone: a club on its week off (no match, so no Play match) is shown the
## week-off card and a finger on "Rest them" answers it; in the semi week the same card has a third
## choice, and a finger on it answers it too; a Grand Final card with the rule under "See the rule".
func _test_finals_card_taps() -> void:
	_state.reset()
	_state.career_seed = 4401
	_state.replay_seed = 4401
	_state.start_season("FRE", _db.club_list("FRE"))
	var sea = _state.season
	var codes: Array = sea.ladder.keys()
	codes.sort()
	codes.erase("FRE")
	codes.insert(0, "FRE")
	for i in range(codes.size()):
		var row: Dictionary = sea.ladder[codes[i]]
		row["w"] = 20 - i
		row["l"] = 4 + i
		row["d"] = 0
		row["p"] = 24
		row["pf"] = 2400 - i * 20
		row["pa"] = 2000
	sea.round_index = sea.fixture.size()
	sea.recalc_ladder()
	sea.start_finals()
	_state._next_week_event()
	_shown_over_hub()
	root.size = Vector2i(390, 844)
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var card: Control = current_scene.find_child("WeekEvent", true, false)
	var ids: Array = _state.week_events.map(func(c): return str(c["tid"]))
	_check(card != null and ids == ["finals_week_off"], "A club on its week off sees the week-off card on the hub (%s)" % str(ids))
	var play_btn: Button = null
	for b in current_scene.find_children("*", "Button", true, false):
		if (b as Button).text == "Play the wildcard":
			play_btn = b
	_check(play_btn != null and play_btn.get_combined_minimum_size().x <= play_btn.size.x + 0.5,
			"The wildcard week's Play button reads whole on a 390 phone (%s)" % (str(play_btn.size) if play_btn != null else "missing"))
	var rest: Button = card.find_child("Event_0", true, false) if card != null else null
	_check(card != null and card.find_child("Event_2", true, false) == null, "Week one of the finals: two choices, no semi to watch")
	var tap_why: String = await Tap.tap(rest) if rest != null else "missing"
	await _settle()
	var all_fresh := true
	for q in _state.my_list:
		all_fresh = all_fresh and bool(q.get("fresh", false))
	_check(tap_why == "" and bool(_state.week_events[0].get("resolved", false)) and all_fresh,
			"A finger on Rest them answers the week-off card and the whole list is fresh (%s)" % tap_why)
	# The semi week: the same card with a third choice.
	sea.finals["week"] = 3
	sea.finals["weeks"] = [[], []]
	sea.finals["slots"] = {"W_QF1": "FRE"}
	_state._next_week_event()
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	card = current_scene.find_child("WeekEvent", true, false)
	var semi: Button = card.find_child("Event_2", true, false) if card != null else null
	_check(semi != null and semi.text.contains("Watch the semi together"), "The semi week's card has a third choice: Watch the semi together")
	var semi_why: String = await Tap.tap(semi) if semi != null else "missing"
	await _settle()
	_check(semi_why == "" and bool(_state.week_events[0].get("resolved", false)), "A finger on it answers the card (%s)" % semi_why)
	# A captain card in the Grand Final: the rule is one tap away.
	sea.finals["week"] = 5
	sea.finals["weeks"] = [[], [], [], []]
	sea.finals["slots"] = {"W_PF1": "FRE", "W_PF2": "ESS"}
	var captaincy = load("res://scripts/sim/Captaincy.gd")
	var cap: Dictionary = {}
	for q in _state.my_list:
		if captaincy.role_of(_state.captaincy_record("FRE"), str(q["id"])) == "captain":
			cap = q
	_state.week_events = [_state.story_card("finals_second_chance", cap)]
	_shown_over_hub()
	_router.go("hub")
	await _settle()
	card = current_scene.find_child("WeekEvent", true, false)
	var rule_btn: Control = null
	if card != null:
		for n in card.find_children("*", "Button", true, false):
			if (n as Button).text.contains("See the rule"):
				rule_btn = n
	_check(rule_btn != null, "A card that leaves it to the captain offers See the rule")
	_state.week_events = []


## Row 102: "Ask before simming" asks only when Sim the week would play a match
## the coach could play (your round, your final). A bye, a finals week off, a
## finals week you are out of and the off-season go straight ahead. Real taps
## on a 390 phone.
## The season already on is reused (a new career costs a second): every ladder
## row is written again and the finals start afresh.
func _fre_in_finals_at(rank: int) -> void:
	var sea = _state.season
	var codes: Array = sea.ladder.keys()
	codes.sort()
	codes.erase("FRE")
	codes.insert(rank - 1, "FRE")
	for i in range(codes.size()):
		var row: Dictionary = sea.ladder[codes[i]]
		row["w"] = 20 - i
		row["l"] = 3 + i
		row["d"] = 0
		row["p"] = 23
		row["pf"] = 2400 - i * 20
		row["pa"] = 2000
	sea.round_index = sea.fixture.size()
	sea.recalc_ladder()
	sea.start_finals()
	_state.week_events = []
	# The bye round played earlier named a carnival squad: its sheet was seen then.
	_state.midseason["carnival_seen"] = true


func _hub_tap(button_name: String) -> Array:
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var b: Button = current_scene.find_child(button_name, true, false)
	var why: String = await Tap.tap(b) if b != null else "missing"
	await _settle()
	return [why, current_scene.find_child("SimConfirm", true, false) != null]


func _test_sim_asks_only_before_your_match() -> void:
	var ask_size_before := root.size
	root.size = Vector2i(390, 844)
	_state.set_confirm_sim_round(true)
	_state.reset()
	_state.career_seed = 4402
	_state.replay_seed = 4402
	_state.start_season("FRE", _db.club_list("FRE"))
	var sea = _state.season
	var bye_round := -1
	for r in range(sea.fixture.size()):
		var plays := false
		for m in sea.fixture[r]:
			plays = plays or m["home"] == "FRE" or m["away"] == "FRE"
		if not plays and bye_round < 0:
			bye_round = r
	_check(bye_round > 0, "Fremantle has a bye in the home-and-away season (round %d)" % (bye_round + 1))
	_state.week_events = []

	# A playable round: the question comes up, and nothing is simmed yet.
	sea.round_index = bye_round - 1
	var r0: int = sea.round_index
	var got: Array = await _hub_tap("SimRound")
	_check(got[0] == "" and got[1] and sea.round_index == r0,
			"Before a round Fremantle plays, a finger on Sim the week gets the question first (%s)" % got[0])
	var cancel: Button = current_scene.find_child("SimConfirmCancel", true, false)
	var cancel_why: String = await Tap.tap(cancel) if cancel != null else "missing"
	await _settle()
	_check(cancel_why == "" and sea.round_index == r0 and current_scene.find_child("SimConfirm", true, false) == null,
			"A finger on Cancel closes it and sims nothing (%s)" % cancel_why)

	# The bye: no match of his to play, so no question; the round goes ahead.
	sea.round_index = bye_round
	_state.week_events = []
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	_check(current_scene.find_child("SimRound", true, false) == null, "A bye week has no Sim the week to ask about")
	var hub = current_scene
	_check(not bool(hub.call("_sim_asks_first")), "A bye week never asks before simming")
	got = await _hub_tap("SimByeRound")
	_check(got[0] == "" and not got[1] and sea.round_index == bye_round + 1,
			"A finger on Play Round %d during the bye sims it with no question (%s)" % [bye_round + 1, got[0]])

	# Finals: his own final asks; a week off and a week he is out of do not.
	# This season again, each time with the ladder written for the case.
	_fre_in_finals_at(8)
	got = await _hub_tap("SimRound")
	_check(got[0] == "" and got[1] and int(_state.season.finals["week"]) == 1,
			"Eighth plays a wildcard final, so Sim the week asks first (%s)" % got[0])
	_fre_in_finals_at(1)
	_check(_state.my_finals_status() == "bye", "Minor premiers sit out the wildcard week")
	got = await _hub_tap("SimFinalsWeekOff")
	_check(got[0] == "" and not got[1] and int(_state.season.finals["week"]) == 2,
			"The finals week off sims with no question (%s)" % got[0])
	_fre_in_finals_at(14)
	got = await _hub_tap("SimFinalsWeek")
	_check(got[0] == "" and not got[1] and int(_state.season.finals["week"]) == 2,
			"A finals week Fremantle is out of sims with no question (%s)" % got[0])

	# The off-season: nothing to sim, nothing to ask.
	_state.season.finals["done"] = true
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	hub = current_scene
	_check(hub.find_child("SimRound", true, false) == null and not bool(hub.call("_sim_asks_first")),
			"The off-season has no Sim the week and never asks")
	_router.stack = ["main"]
	_router.go("main")
	await _settle()
	root.size = ask_size_before


## My List on a phone: switching between Shape and Full list shows the pane
## already built instead of building the page again (a perf guard: Android
## stalled on every switch).
func _test_list_tabs_kept() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	_state.reset()
	_state.start_season("FRE", _db.club_list("FRE"))
	_router.stack = ["main", "hub"]
	_router.go("list")
	await _settle()
	var list := current_scene
	var full := list.find_child("ListTabFull", true, false) as Control
	var why: String = await Tap.tap(full)
	await _settle()
	var added := [0]
	var count := func(_n): added[0] += 1
	node_added.connect(count)
	var shape: Control = null
	for t in list.find_children("ListTabShape", "", true, false):
		if (t as Control).is_visible_in_tree():
			shape = t
	why += await Tap.tap(shape)
	await _settle()
	full = null
	for t in list.find_children("ListTabFull", "", true, false):
		if (t as Control).is_visible_in_tree():
			full = t
	why += await Tap.tap(full)
	await _settle()
	node_added.disconnect(count)
	_check(why == "" and added[0] < 10 and list.find_child("ShapeScroll", true, false) != null,
			"A tab switched back and forth on My List builds the page again for neither (%d nodes added; %s)" % [added[0], why])
	_router.stack = ["main"]
	_router.go("main")
	await _settle()
	root.size = size_before


func _test_season_awards() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	var player: Dictionary = _state.my_list[0]
	var row := {"id": str(player["id"]), "club": "COL", "votes": 24, "goals": 71, "bf": 118, "slot": "MID"}
	_state.season_awards = {"year": 2027, "brownlow": [row], "coleman": [row],
		"all_australian": [row], "best_and_fairest": {"COL": [row]}}
	var before := var_to_str(_state.season_awards)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	root.size = Vector2i(360, 800)
	var ceremony: Control = load("res://scripts/ui/SeasonAwards.gd").open(host)
	await _settle()
	var next: Button = ceremony.find_child("AwardsNext", true, false)
	_check(next != null and next.size.y >= 44, "Awards actions remain thumb sized")
	next.emit_signal("pressed")
	await _settle()
	var scene: Control = ceremony.find_child("AwardWinner", true, false)
	_check(scene != null and scene.club == "COL", "The stored winner supplies the vignette club")
	_check(scene.number == int(player["num"]), "The winner retains his actual jumper number")
	for width in [320, 360, 430]:
		root.size = Vector2i(width, 800)
		await _settle()
		var button_rect := next.get_global_rect()
		_check(button_rect.position.x >= 0 and button_rect.end.x <= width and button_rect.end.y <= 800,
			"Awards footer remains reachable at %d portrait width" % width)

	next.emit_signal("pressed")
	_check(scene._done, "A tap completes the winner animation without advancing the award")
	_check(var_to_str(_state.season_awards) == before, "Revealing awards does not mutate votes or results")
	var seen := ""
	for i in range(20):
		if not is_instance_valid(ceremony):
			break
		for l in ceremony.find_children("*", "Label", true, false):
			seen += (l as Label).text + " | "
		next.emit_signal("pressed")
		await _settle()
	# Collingwood's best and fairest is the Copeland Trophy, named where the award is presented (P-54).
	_check(seen.contains("Copeland Trophy") and not seen.contains("Best and fairest"),
			"The awards screen presents Collingwood's best and fairest as the Copeland Trophy (%s)" % seen.substr(0, 400))
	_check(not is_instance_valid(ceremony) and _state.season_awards.get("presentation_seen", false),
		"Completing awards records viewing and returns to review")
	_check(_state.save_career(), "Awards viewed state saves")
	_check(_state.load_career() and _state.season_awards.get("presentation_seen", false), "Awards viewed state survives reload")
	ceremony = load("res://scripts/ui/SeasonAwards.gd").open(host)
	await _settle()
	ceremony.find_child("AwardsSkip", true, false).emit_signal("pressed")
	await _settle()
	_check(not is_instance_valid(ceremony), "Replay can skip straight to review")
	# A suspended top vote-getter: the medal goes to the first eligible player,
	# the one every other screen names, and he is listed as ineligible.
	var p2: Dictionary = _state.my_list[1]
	var banned := {"id": str(p2["id"]), "club": "COL", "votes": 30, "slot": "MID", "brownlow_eligible": false}
	_state.season_awards = {"year": 2027, "brownlow": [banned, row], "brownlow_winner": row,
		"coleman": [row], "all_australian": [row],
		"best_and_fairest": {"COL": [row, banned.merged({"bf": 20})]}}
	ceremony = load("res://scripts/ui/SeasonAwards.gd").open(host)
	await _settle()
	next = ceremony.find_child("AwardsNext", true, false)
	next.emit_signal("pressed")
	await _settle()
	var medal := ""
	for l in ceremony.find_children("*", "Label", true, false):
		medal += (l as Label).text + " | "
	var crowned: Control = ceremony.find_child("AwardWinner", true, false)
	_check(medal.contains(_state.award_name(row) + " | ") and medal.contains("(ineligible)")
			and (crowned == null or crowned.number == int(player["num"])),
			"The Brownlow is presented to the eligible winner, the suspended player marked ineligible (%s)" % medal.substr(0, 300))
	# The club best and fairest has nothing to do with Brownlow eligibility: the same
	# suspended player sits in its placings with no "(ineligible)".
	var club_bf := ""
	for i in range(12):
		if not is_instance_valid(ceremony):
			break
		var page := ""
		for l in ceremony.find_children("*", "Label", true, false):
			page += (l as Label).text + " | "
		if page.contains("Final placings") and page.contains("Copeland Trophy"):
			club_bf = page
		next.emit_signal("pressed")
		await _settle()
	_check(club_bf.contains(_state.award_name(banned)) and not club_bf.contains("(ineligible)"),
			"The club best and fairest lists a suspended player without the Brownlow's ineligible mark (%s)" % club_bf.substr(0, 300))
	if is_instance_valid(ceremony):
		ceremony.find_child("AwardsSkip", true, false).emit_signal("pressed")
	await _settle()
	for code in _db.CLUB_ORDER:
		var winner: Control = load("res://scripts/ui/match/AwardWinnerVignette.gd").new()
		host.add_child(winner)
		winner.setup_winner(code, 7)
		winner.finish_now()
		_check(winner._colours[0] == _db.club_marker_colours(code), "%s uses genuine club colours" % code)
		winner.queue_free()
	host.queue_free()
	await _settle()


## Press a named button in the current scene, or fail the check if it is missing.
## How many weaknesses the open Forge form holds.
func _forge_weaknesses() -> int:
	return (current_scene.get("_spec")["weaknesses"] as Array).size()


func _press(node_name: String) -> void:
	var b = current_scene.find_child(node_name, true, false)
	_check(b != null, "%s is on screen" % node_name)
	if b != null:
		b.emit_signal("pressed")


## Pick the option whose metadata is `value` in an OptionButton.
func _choose(node_name: String, value: String) -> void:
	var o = current_scene.find_child(node_name, true, false)
	_check(o != null, "%s is on screen" % node_name)
	if o == null:
		return
	for i in (o as OptionButton).item_count:
		if str((o as OptionButton).get_item_metadata(i)) == value:
			(o as OptionButton).select(i)
			(o as OptionButton).item_selected.emit(i)
			return
	_check(false, "%s offers %s" % [node_name, value])


func _type(node_name: String, text: String) -> void:
	var f = current_scene.find_child(node_name, true, false)
	_check(f != null, "%s is on screen" % node_name)
	if f != null:
		(f as LineEdit).text = text
		(f as LineEdit).text_changed.emit(text)


## A name never truncates (guide §4.2): every row's name label is a UiKit
## name_label (wraps to two lines) and, at 360 wide, none needs a third. Checked
## on Training and the League Draft, the two lists that cut names before.
func _test_names_fit() -> void:
	_state.reset()
	_state.start_season("WBD", _db.club_list("WBD"))
	_state.set_setting("seen_training_intro", true)
	var was := root.size
	root.size = Vector2i(360, 800)
	_router.stack = ["main", "hub"]
	_router.go("training")
	await _settle()
	await _settle()
	var names: Array = []
	_find_named(current_scene, "Name", names)
	_check(names.size() >= 10, "Training rows lead with name labels (%d found at 360 wide)" % names.size())
	var cut: Array[String] = []
	for l in names:
		var lab := l as Label
		if lab.get_line_count() > 2:
			cut.append(lab.text)
		if lab.get_line_count() > lab.get_visible_line_count():
			cut.append(lab.text + " (clipped)")
	_check(cut.is_empty(), "No Training name needs a third line or is clipped at 360 wide: %s" % str(cut))
	root.size = was


func _find_named(n: Node, named: String, out: Array) -> void:
	if n.name == named and n is Label and (n as Label).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_find_named(c, named, out)


## The Canberra question on New career (director, 2026-11-08): "Canberra
## joins?" answers No by default; a real tap on Yes keeps Canberra for 2030.
## The 2027 League redraft is the founding eighteen either way: Tasmania join
## in 2028 (director, 2026-11-12: "Join in 2028").
func _test_new_career_canberra_choice() -> void:
	_state.delete_saved_career()
	for pick_it in [false, true]:
		_state.reset()
		_router.stack = []
		_router.go("main")
		await _settle()
		await Tap.tap(current_scene.find_child("NewCareer", true, false))
		await _settle()
		await _pick_year()
		var yes := current_scene.find_child("Canberra_yes", true, false)
		var no := current_scene.find_child("Canberra_no", true, false)
		var both_there: bool = yes != null and no != null  # gone once the draft opens
		var t1 := ""
		if pick_it:
			t1 = await Tap.tap(yes)
			await _settle()
		var t2: String = await Tap.tap(current_scene.find_child("StartCareer", true, false))
		await _settle()
		await _settle()
		var clubs: Array = _state.draft.clubs if _state.draft != null else []
		_check(both_there and t1 == "" and t2 == "" and _router.current() == "draft"
				and bool(_state.canberra_on) == pick_it and not clubs.has("CANB") and not clubs.has("TAS")
				and clubs.size() == 18
				and _db.enter_year("CANB") == (2030 if pick_it else 9999)
				and _db.enter_year("TAS") == 2028,
				("A tap on Yes keeps Canberra for 2030; the 2027 League redraft is 18 clubs (%s %s, %d clubs)" if pick_it
				else "Left at No, the 2027 League redraft is 18 clubs and Canberra never join (%s %s, %d clubs)") % [
					t1, t2, clubs.size()])
	_state.reset()
	_router.stack = []


## Canberra on the real lists starts the career in 2030 (director, 2026-11-10:
## "if you click YES to canberra joining, you should be warned that the game
## will sim to 2030"). A real tap on Yes opens the warning; Back takes Canberra
## out again; Start in 2030 keeps it. A setup that comes back to the 2030 start
## after the warning was read is warned again at Choose your club.
func _test_canberra_2030_warning() -> void:
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year()
	# A League redraft with Canberra is no 2030 start: no warning.
	var t0: String = await Tap.tap(current_scene.find_child("Canberra_yes", true, false))
	await _settle()
	_check(t0 == "" and current_scene.find_child("SimAheadWarning", true, false) == null
			and bool(current_scene.get("_pick_canberra")),
			"Yes on a League redraft takes Canberra in with no 2030 warning (%s)" % t0)
	await Tap.tap(current_scene.find_child("Canberra_no", true, false))
	await _settle()
	await Tap.tap(current_scene.find_child("StartMode_real", true, false))
	await _settle()
	var t1: String = await Tap.tap(current_scene.find_child("Canberra_yes", true, false))
	await _settle()
	var sheet := current_scene.find_child("SimAheadWarning", true, false)
	var said := _all_text(sheet) if sheet != null else ""
	_check(t1 == "" and sheet != null and said.contains("Your first season is 2030")
			and said.contains("2027 to 2029 play out without you") and said.contains("face the press"),
			"Yes on the real lists warns that 2027 to 2029 play out without you (%s): %s" % [t1, said])
	var t2: String = await Tap.tap(current_scene.find_child("SimAheadBack", true, false))
	await _settle()
	_check(t2 == "" and current_scene.find_child("SimAheadWarning", true, false) == null
			and not bool(current_scene.get("_pick_canberra")) and _router.current() == "main",
			"Back closes the warning and Canberra stay out (%s)" % t2)
	# Yes again, confirmed: the pick holds and nothing starts yet.
	await Tap.tap(current_scene.find_child("Canberra_yes", true, false))
	await _settle()
	var t3: String = await Tap.tap(current_scene.find_child("SimAheadConfirm", true, false))
	await _settle()
	_check(t3 == "" and current_scene.find_child("SimAheadWarning", true, false) == null
			and bool(current_scene.get("_pick_canberra")) and bool(current_scene.get("_sim_ahead_ok"))
			and _router.current() == "main" and _state.season == null,
			"Start in 2030 keeps Canberra in and starts nothing until Choose your club (%s)" % t3)
	# The start changed and came back: Choose your club warns again; Back stops it.
	await Tap.tap(current_scene.find_child("StartMode_redraft", true, false))
	await _settle()
	await Tap.tap(current_scene.find_child("StartMode_real", true, false))
	await _settle()
	var t4: String = await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	# Kept as a bool: Back frees the sheet, and a freed node compares equal to null.
	var again: bool = current_scene.find_child("SimAheadWarning", true, false) != null
	var t5: String = "no sheet"
	if again:
		t5 = await Tap.tap(current_scene.find_child("SimAheadBack", true, false))
	await _settle()
	_check(t4 == "" and again and t5 == "" and _state.season == null and _router.current() == "main"
			and not bool(current_scene.get("_pick_canberra")),
			"Back from the warning at Choose your club starts no career (%s %s; sheet %s, season %s, route %s, Canberra %s)" % [
				t4, t5, again, _state.season != null, _router.current(), current_scene.get("_pick_canberra")])
	_state.reset()
	_router.stack = []


func _all_text(n: Node) -> String:
	var out: Array = []
	_texts(n, out)
	return " ".join(PackedStringArray(out))


## Every start mode opens with the press interview that sets your coaching style (director, 2026-11-10:
## "interview should happen in every game mode"), its answers scored as in any
## start. Each start is set on New career and begun as Choose your club begins
## it; the club is taken by a real tap, and the interview comes before the
## first pick (director, 2026-11-11: "its meant to go before the draft"). The 2030 start (Canberra on the real lists) and Tasmania's 2028
## start load a shipped history, which used to bring its own coach with it.
func _test_every_start_reaches_interview() -> void:
	var seed_was: int = _state.replay_seed
	# [name, start, challenge, canberra, wait for Tasmania]
	var starts := [
		["League redraft", "redraft", "none", false, false],
		["League redraft with Canberra", "redraft", "none", true, false],
		["Real 2026 lists", "real", "none", false, false],
		["Real 2026 lists, Tasmania in 2028", "real", "none", false, true],
		["Real 2026 lists with Canberra, 2030", "real", "none", true, false],
		["Rebuild", "real", "rebuild", false, false],
		["Rebuild with Canberra", "real", "rebuild", true, false],
		["Youth only", "redraft", "youth", false, false],
		["Your goal", "real", "goal", false, false],
		["The 1990 season", "real", "none", false, false, "1990"],
		["The 1990 League redraft", "redraft", "none", false, false, "1990"],
	]
	var picks := [1, 0, 2, 1, 3, 0, 1]
	for st in starts:
		var label := str(st[0])
		var history: bool = (bool(st[3]) and str(st[1]) == "real" and str(st[2]) != "rebuild") or bool(st[4])
		# The shipped histories serve an unseeded career only (begin_from_history).
		_state.replay_seed = 0 if history else seed_was
		_state.delete_saved_career()
		_state.reset()
		_router.stack = []
		_router.go("main")
		await _settle()
		await Tap.tap(current_scene.find_child("NewCareer", true, false))
		await _settle()
		await _pick_year(str(st[5]) if st.size() > 5 else "2026")
		var menu := current_scene
		menu.set("_pick_start", str(st[1]))
		menu.set("_pick_challenge", str(st[2]))
		menu.set("_pick_goal", "coach_300" if str(st[2]) == "goal" else "")
		menu.set("_pick_canberra", bool(st[3]))
		menu.call("_start_new_career")
		for i in range(900):
			if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
				break
			await process_frame
		await _settle()
		var draft_scene := current_scene
		# The club, by a real tap: Tasmania by waiting for them, else the first
		# club offered (a Rebuild may already hold its club).
		var tap := ""
		if bool(st[4]):
			tap = await Tap.tap(draft_scene.find_child("Choose_TAS", true, false))
			await _settle()
			tap += await Tap.tap(draft_scene.find_child("WaitGo", true, false))
			for i in range(900):
				if _state.my_club != "" and not bool(root.get_node("ScreenTransition").busy):
					break
				await process_frame
			await _settle()
		elif _state.my_club == "":
			var tile := _first_named(draft_scene, "Choose_")
			tap = await Tap.tap(tile) if tile != null else "no club tile"
			await _settle()
		# Straight from the club tap to the press interview, before any pick of
		# yours (director, 2026-11-11: "its meant to go before the draft").
		for i in range(300):
			if _router.current() != "draft" and not bool(root.get_node("ScreenTransition").busy):
				break
			await process_frame
		await _settle()
		var d = _state.draft
		var mine_before := 0
		if d != null:
			for pk in d.pick_history:
				mine_before += 1 if str(pk["club"]) == _state.coach_club() else 0
		var due: bool = bool(_state.interview_due)
		var clean: bool = (_state.coach_arch as Dictionary).is_empty() and str(_state.coach_name) == ""
		_check(tap == "" and _state.coach_club() != "" and due and clean and mine_before == 0
				and d != null and _router.current() == "interview"
				and current_scene.find_child("CoachName", true, false) != null,
				"%s: the new coach of %s faces the press interview before the draft, name first (tap %s, due %s, clean %s, his picks %d, draft finished %s, at %s)" % [
					label, _state.coach_club(), tap, due, clean, mine_before,
					str(d != null and d.is_finished()), _router.current()])
		if _router.current() != "interview":
			continue
		# The answers score exactly as in the standard start.
		var name_field := current_scene.find_child("CoachName", true, false) as LineEdit
		name_field.text = "Pat Reid"
		name_field.text_changed.emit(name_field.text)
		await Tap.tap(current_scene.find_child("InterviewStart", true, false))
		await _settle()
		# The coach you beat is named as every screen names him: a real one by
		# his real name, never an invented label (real names only, 2026-11-12).
		var asked := current_scene.find_child("InterviewQuestion", true, false) as Label
		var labels := 0
		var real_named := 0
		for cid in _state.coaches:
			var co: Dictionary = _state.coaches[cid]
			var lab := str(co.get("generic_name", ""))
			var rn := str(co.get("real_name", ""))
			if asked != null and rn != "" and lab != "" and lab != rn:
				labels += 1 if asked.text.contains(lab) else 0
				real_named += 1 if asked.text.contains(rn) else 0
		_check(asked != null and labels == 0 and (real_named == 1 or asked.text.contains("a long list of names")),
				"%s: the first question names the beaten coach by his real name (%s)" % [label, asked.text if asked != null else "no question"])
		var answered := ""
		for a in picks:
			answered += await Tap.tap(current_scene.find_child("InterviewAnswer%d" % int(a), true, false))
			await _settle()
		var want: Dictionary = load("res://scripts/sim/Archetypes.gd").score_interview(picks)
		_check(answered == "" and not _state.interview_due and _state.coach_name == "Pat Reid"
				and _state.coach_arch == want and load("res://scripts/sim/CoachEffects.gd").my_arch == want
				and current_scene.find_child("InterviewDone", true, false) != null,
				"%s: seven tapped answers set the coaching style as the standard start's (%s)" % [label, answered])
		# Continue, by a real tap, goes back to the draft board for the first pick.
		var cont: String = await Tap.tap(current_scene.find_child("InterviewDone", true, false))
		for i in range(300):
			if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
				break
			await process_frame
		await _settle()
		if st.size() > 5 and str(st[1]) == "real":
			# A past season on its real lists has no draft before it: Continue starts the season.
			_check(cont == "" and _router.current() in ["hub", "preseason"] and _state.season != null and _state.season_year == 1990,
					"%s: Continue starts the 1990 season, no empty draft board (tap %s, at %s)" % [label, cont, _router.current()])
			continue
		_check(cont == "" and _router.current() == "draft" and str(current_scene.get("_phase")) == "board",
				"%s: Continue goes back to the draft board (tap %s, at %s, phase %s)" % [
					label, cont, _router.current(), current_scene.get("_phase")])
		# The draft to its end; the hub never asks again. The interview is due
		# only from New career (Main), so one League redraft carries the proof
		# for the redraft starts: every club drafts its whole list there, the
		# cost of this test, and the 1990 one (14 clubs) is the shortest.
		if str(st[1]) == "redraft" and label != "The 1990 League redraft":
			continue
		var ds := current_scene
		var guard := 0
		while d != null and not d.is_finished() and guard < 200:
			guard += 1
			var board: Array = d.board("", "", "", "overall", true).filter(func(p): return d.can_pick_player(p))
			if board.is_empty():
				break
			ds.call("_on_pick", board[0])
			await process_frame
		if is_instance_valid(ds) and ds.has_method("_on_finish"):
			ds.call("_on_finish")
		for i in range(300):
			if _router.current() != "draft" and not bool(root.get_node("ScreenTransition").busy):
				break
			await process_frame
		await _settle()
		_check(_router.current() != "interview" and _router.current() != "draft" and not _state.interview_due,
				"%s: after the draft the career goes on without a second interview (at %s)" % [label, _router.current()])
	_state.replay_seed = seed_was
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []


func _first_named(n: Node, prefix: String) -> Control:
	if n is Control and str(n.name).begins_with(prefix) and (n as Control).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _first_named(c, prefix)
		if f != null:
			return f
	return null


## The Forge club joins League redraft careers only (director, 2026-11-08):
## Real 2026 lists or Rebuild hide its row and say why; a League redraft
## brings it back with the pick as it was.
func _test_new_career_forged_row_redraft_only() -> void:
	_state.delete_saved_career()
	_state.reset()
	_state.set_forge_club({"name": "Port Melbourne", "short": "Borough", "code": "PMB",
			"location": "port-melbourne", "primary": "#1B3A8C", "secondary": "#C8102E",
			"accent": "#FFFFFF", "design": "hoops", "kit": "p/s/a"})
	_router.stack = []
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year()
	var row := current_scene.find_child("ForgedClub", true, false) as Control
	var note := current_scene.find_child("ForgedClubOnlyNote", true, false) as Label
	_check(row != null and note != null and row.is_visible_in_tree() and not note.is_visible_in_tree(),
			"A League redraft shows the Your club row")
	if row == null or note == null:
		return
	await Tap.tap(current_scene.find_child("ForgedClub_in", true, false))
	await _settle()
	await Tap.tap(current_scene.find_child("StartMode_real", true, false))
	await _settle()
	_check(not row.is_visible_in_tree() and note.is_visible_in_tree()
			and note.text == "Your club joins League redraft careers only.",
			"Real 2026 lists hide the Your club row and show the note")
	await Tap.tap(current_scene.find_child("StartMode_redraft", true, false))
	await _settle()
	_check(row.is_visible_in_tree() and not note.is_visible_in_tree() and bool(current_scene.get("_pick_club")),
			"Back on a League redraft, the row returns with your club still brought")
	await Tap.tap(current_scene.find_child("Challenge_rebuild", true, false))
	await _settle()
	_check(not row.is_visible_in_tree() and note.is_visible_in_tree(), "Rebuild hides the Your club row too")
	_state.set_forge_club({})
	_state.reset()
	_router.stack = []


## Row 114: the challenge starts on New career, by real taps. Your goal holds
## Start until a goal is picked (none is chosen for you); Rebuild switches the
## start to the real 2026 lists and starts at the bottom club, its three best
## gone, with the rule stated on the draft board.
func _test_new_career_challenge_taps() -> void:
	# By path: a runner naming a class whose load chain reaches an autoload
	# does not compile before the autoloads exist.
	var CH = load("res://scripts/state/Challenge.gd")
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year()
	var start := current_scene.find_child("StartCareer", true, false) as Button
	var note := current_scene.find_child("ChallengeNote", true, false) as Label
	_check(current_scene.find_child("Challenge_none", true, false) != null and note != null
			and note.text == CH.rule_line("none"), "New career offers the challenge starts, None by default")
	_check(current_scene.find_child("Goal_coach_300", true, false) == null
			or not (current_scene.find_child("Goal_coach_300", true, false) as Control).is_visible_in_tree(),
			"The goals are hidden until Your goal is picked")
	var t1: String = await Tap.tap(current_scene.find_child("Challenge_goal", true, false))
	await _settle()
	start = current_scene.find_child("StartCareer", true, false) as Button
	note = current_scene.find_child("ChallengeNote", true, false) as Label
	_check(t1 == "" and start != null and start.disabled and note != null and note.text == CH.rule_line("goal"),
			"Your goal: Start waits until a goal is picked, and the rule is said (%s)" % t1)
	var t2: String = await Tap.tap(current_scene.find_child("Goal_coach_300", true, false))
	await _settle()
	start = current_scene.find_child("StartCareer", true, false) as Button
	_check(t2 == "" and start != null and not start.disabled, "Picking a goal frees Start (%s)" % t2)
	var t3: String = await Tap.tap(current_scene.find_child("Challenge_youth", true, false))
	await _settle()
	note = current_scene.find_child("ChallengeNote", true, false) as Label
	_check(t3 == "" and note != null and note.text == CH.rule_line("youth"), "Youth only states its rule (%s)" % t3)
	var t4: String = await Tap.tap(current_scene.find_child("Challenge_rebuild", true, false))
	await _settle()
	_check(t4 == "" and str(current_scene.get("_pick_start")) == "real",
			"Rebuild switches the start to the real 2026 lists (%s, %s)" % [t4, str(current_scene.get("_pick_start"))])
	var t5: String = await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	await _settle()
	# Row T5.Q25: Choose your rebuild offers the bottom club or Tasmania.
	var tas_tile := current_scene.find_child("Choose_TAS", true, false)
	_check(_state.my_club == "" and tas_tile != null and current_scene.find_child("Choose_COL", true, false) == null,
			"Choose your rebuild offers the bottom club and Tasmania, no other club")
	# The press interview has its own test (_test_every_start_reaches_interview).
	_state.interview_due = false
	var t6: String = await Tap.tap(current_scene.find_child("Choose_ESS", true, false))
	await _settle()
	t5 += t6
	var ch: Dictionary = _state.challenge
	var gone: Array = ch.get("gone", [])
	var club := str(ch.get("club", ""))
	_check(t5 == "" and str(ch.get("kind", "")) == "rebuild" and club == "ESS" and _state.my_club == club and gone.size() == 3,
			"Start on Rebuild takes over the bottom club with three gone (%s %s %s)" % [t5, club, str(_state.my_club)])
	var listed := {}
	for q in _state.league_lists.get(club, []):
		listed[str(q["id"])] = true
	var freed := {}
	for q in _state.free_agents:
		freed[str(q["id"])] = q
	var all_gone := true
	for g in gone:
		if listed.has(str(g["id"])) or not freed.has(str(g["id"])):
			all_gone = false
	_check(all_gone, "The three are off the list and in free agency")
	var best_left := 0
	for q in _state.league_lists.get(club, []):
		best_left = maxi(best_left, int(q.get("overall", 0)))
	var worst_gone := 999
	for g in gone:
		worst_gone = mini(worst_gone, int(freed.get(str(g["id"]), {}).get("overall", 0)))
	_check(worst_gone >= best_left, "They were the club's three best (%d gone, %d left)" % [worst_gone, best_left])
	var back: Dictionary = freed.get(str(gone[0]["id"]), {}) if not gone.is_empty() else {}
	_check(not back.is_empty() and CH.block_reason(_state, back).begins_with("Rebuild:"),
			"You can never sign one of them back")
	_check(_router.current() == "draft" and current_scene.find_child("ChallengeRule", true, false) != null,
			"The draft board states the Rebuild (at %s)" % _router.current())
	_state.reset()
	_router.stack = []


## qa web pass, 2026-10-12: starting a new career must not cost the player the
## one they have. The old save stays until the new career has a club; Back on
## Choose your club steps back to the New career options, and Continue still
## offers the old career. Real taps at each step.
func _test_new_career_keeps_the_save() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_check(_state.save_career(), "(setup) the old career is saved")
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	var old_club := str(_state.saved_career_meta().get("club", ""))
	_check(old_club == "COL" and current_scene.find_child("ContinueCareer", true, false) != null,
			"The title offers Continue for the saved career")
	var t1: String = await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year()
	var t2: String = await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	var t3: String = await Tap.tap(current_scene.find_child("ConfirmNewCareer", true, false))
	await _settle()
	await _settle()
	_check(t1 == "" and t2 == "" and t3 == "" and _router.current() == "draft",
			"New career > Choose your club > Start new career reaches Choose your club (%s %s %s, at %s)" % [t1, t2, t3, _router.current()])
	_check(str(_state.saved_career_meta().get("club", "")) == "COL",
			"The old career is still saved while the club is being chosen")
	# One step back: the New career options, not the title.
	var back_tap: String = await Tap.tap(current_scene.find_child("BackToMenu", true, false))
	await _settle()
	await _settle()
	_check(back_tap == "" and _router.current() == "main" and str(current_scene.get("_mode")) == "setup",
			"Back on Choose your club steps back to the New career options (%s; now %s, mode %s)" % [back_tap, _router.current(), str(current_scene.get("_mode"))])
	_check(str(_state.saved_career_meta().get("club", "")) == "COL", "...and the old career is still saved")
	# And back to the title (through the year step), where Continue still offers it.
	_router.handle_back(false)
	await _settle()
	_router.handle_back(false)
	await _settle()
	var meta: Node = current_scene.find_child("CareerMeta", true, false)
	_check(current_scene.find_child("ContinueCareer", true, false) != null and meta != null
			and (meta as Label).text.contains(_db.club_name("COL")),
			"The title still offers Continue for the old career")
	# Escape on Choose your club does the same.
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year()
	await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	await Tap.tap(current_scene.find_child("ConfirmNewCareer", true, false))
	await _settle()
	await _settle()
	_router.handle_back(false)
	await _settle()
	await _settle()
	_check(_router.current() == "main" and str(current_scene.get("_mode")) == "setup"
			and str(_state.saved_career_meta().get("club", "")) == "COL",
			"Escape on Choose your club also steps back to the options with the old career kept")
	_state.delete_saved_career()


## web's PC pass (2026-10-12): at 1280x720 the hub shows Play match and Play
## round together without scrolling, and My list's Captaincy row is a row of
## text, not a bar across the window.
func _test_pc_hub_and_list_layout() -> void:
	root.size = Vector2i(1280, 720)
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	await _settle()
	var play: Control = current_scene.find_child("WeekActions", true, false)
	var play_btn: Button = null
	if play != null:
		for b in play.find_children("*", "Button", true, false):
			if (b as Button).text == "Play match":
				play_btn = b
	var sim: Button = current_scene.find_child("SimRound", true, false)
	var win := Rect2(Vector2.ZERO, Vector2(root.size))
	var in_scroll := func(c: Control) -> bool:
		var p := c.get_parent()
		while p != null:
			if p is ScrollContainer:
				return true
			p = p.get_parent()
		return false
	_check(play_btn != null and sim != null, "The hub has Play match and Play round at 1280x720")
	if play_btn != null and sim != null:
		_check(win.encloses(play_btn.get_global_rect()) and win.encloses(sim.get_global_rect())
				and not in_scroll.call(play_btn) and not in_scroll.call(sim),
				"Play match and Play round are both on screen without scrolling at 1280x720 (%s, %s)" % [str(play_btn.get_global_rect()), str(sim.get_global_rect())])
	_check(play_btn != null and sim != null and play_btn.get_parent() == sim.get_parent(),
			"On a PC bar the match choices sit together: Play round beside Pick the side and Play match")
	_router.go("list")
	await _settle()
	await _settle()
	var cap: Control = current_scene.find_child("CaptaincyOpen", true, false)
	var cap_title: Control = cap.find_child("SectionTitle", true, false) if cap != null else null
	_check(cap_title != null and cap_title.size.x >= 60.0, "The Captaincy label is visible beside the names (%.0f wide)" % (cap_title.size.x if cap_title != null else -1.0))
	_check(cap != null and cap.size.x < 640.0 and cap.size.y >= 44.0, "My list's Captaincy row is not a bar across the PC window and is thumb high (%.0f x %.0f)" % [cap.size.x if cap != null else -1.0, cap.size.y if cap != null else -1.0])


## The hub's ladder leaves no dead space beside it on a wide window (row 109,
## 6.Q18: at 2560 the table ended a third of the way across its column). The
## ladder table ends within a column gap of whatever is right of it: the front
## page when there is news, the window's edge when there is none.
func _test_hub_ladder_fills_right(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	root.size = sz
	var news := [
		{"year": 2027, "when": "Round 1", "kind": "game", "text": "Shannon Neale kicked 6 goals for Geelong against Sydney."},
		{"year": 2027, "when": "Round 1", "kind": "injury", "text": "Josh Battle (Hawthorn) is out for 8 weeks with a hand."},
	]
	for with_news in [false, true]:
		var case := "%s, %s" % [tag, "news" if with_news else "no news"]
		_state.reset()
		_state.start_season("COL", _db.club_list("COL"))
		_state.news = news.duplicate(true) if with_news else []
		_router.stack = []
		_router.go("main")
		await _settle()
		_router.go("hub")
		await _settle()
		await _settle()
		var section: Control = current_scene.find_child("LadderSection", true, false)
		var cols: Control = current_scene.find_child("HubColumns", true, false)
		_check(section != null and cols != null, "The wide hub has its columns and the ladder (%s)" % case)
		if section == null or cols == null:
			continue
		# The table: the section's widest child below its heading.
		var table_end := 0.0
		for c in section.get_children():
			if c is Control and (c as Control).visible:
				table_end = maxf(table_end, (c as Control).get_global_rect().end.x)
		var right_of: float = cols.get_global_rect().end.x
		var host := section.get_parent()
		var at := section.get_index()
		if at + 1 < host.get_child_count():
			right_of = (host.get_child(at + 1) as Control).get_global_rect().position.x
		var gap := right_of - table_end
		_check(gap <= 30.0, "The ladder leaves no dead space to its right (%s: %.0f px to %s)" % [
				case, gap, "the front page" if at + 1 < host.get_child_count() else "the edge"])
		if with_news:
			var front: Control = host.get_child(at + 1) as Control if at + 1 < host.get_child_count() else null
			_check(front != null and front.size.x > section.size.x,
					"With news, the front page takes the room the ladder leaves (%s: %.0f vs %.0f)" % [
					case, front.size.x if front != null else -1.0, section.size.x])
	_state.news = []


## The Shape pane on My list is reachable on a phone (the screen sweep,
## 2026-10-18: the board ran to y 1005 on an 844 px screen and the tree had no
## scroll). Every control in the pane is on screen, or inside a scroll that
## brings it on screen; a finger's tap on a guernsey at the foot of the oval
## opens his profile; a swipe that starts on a guernsey scrolls the pane.
## My list's Captaincy row keeps its word whole (critic 2026-11-04: "Captain…"
## on a phone): the label is as wide as its text, and the row stays on screen.
func _captaincy_whole(tag: String) -> void:
	var cap: Control = current_scene.find_child("CaptaincyOpen", true, false)
	var t: Label = cap.find_child("SectionTitle", true, false) if cap != null else null
	if t == null:
		_check(false, "My list has a Captaincy row (%s)" % tag)
		return
	var need: float = t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			t.get_theme_font_size("font_size")).x
	_check(t.size.x + 0.5 >= need and t.text == "Captaincy",
			"The Captaincy label is whole, not cut (%s: %.0f wide for %.0f of text)" % [tag, t.size.x, need])
	var end := 0.0
	for c in cap.find_children("*", "Label", true, false):
		end = maxf(end, (c as Control).get_global_rect().end.x)
	_check(end <= float(root.size.x) + 0.5, "The Captaincy row ends on screen (%s: %.0f)" % [tag, end])


## Collingwood's My list, the critics' case (2026-11-04): the Captaincy word
## whole beside Moore, Maynard and Daicos on a phone, and on a PC the Best 23
## oval's centre line (Frampton, Daicos, Cameron, Anderson) with no two names
## within 8 px.
func _test_list_words_fit(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	root.size = sz
	_state.reset()
	# Real names, as the critics saw them (the made-up ones are shorter).
	_state.start_season("COL", _db.club_list("COL"))
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	_router.go("list")
	for i in range(6):
		await _settle()
	_captaincy_whole(tag)
	if sz.x < 760:
		return
	var ovals := current_scene.find_children("*", "FormationView", true, false)
	_check(not ovals.is_empty(), "My list shows the Best 23 oval (%s)" % tag)
	for ov in ovals:
		var rects: Array = ov.call("name_rects")
		var touching := []
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if (rects[i] as Rect2).grow_individual(4, 0, 4, 0).intersects((rects[j] as Rect2).grow_individual(4, 0, 4, 0)):
					touching.append("%s/%s" % [str(rects[i]), str(rects[j])])
		_check(rects.size() >= 18 and touching.is_empty(),
				"No two names on the Best 23 oval come within 8 px (%s, %d names: %s)" % [tag, rects.size(), str(touching.slice(0, 3))])


func _test_list_shape_fits_phones() -> void:
	for sz in [Vector2i(360, 740), Vector2i(390, 844), Vector2i(412, 915)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		_state.reset()
		_state.start_season("MEL", _db.club_list("MEL"))
		_router.stack = []
		_router.go("main")
		await _settle()
		_router.go("hub")
		await _settle()
		_router.go("list")
		for i in range(6):
			await _settle()
		var win := Rect2(Vector2.ZERO, Vector2(sz))
		var board: Control = current_scene.find_child("Best22Board", true, false)
		_check(board != null, "My list's Shape pane shows the board (%s)" % tag)
		if board == null:
			continue
		var stray := []
		var count := 0
		for c in board.find_children("*", "Control", true, false):
			var ctl := c as Control
			# The boxes that hold the oval and the bench, and the grid of cards for
			# the rest of the list, are as tall as their contents (the grid taller
			# than a short phone now each card carries its top three); what a
			# finger meets is the controls inside them.
			if not ctl.is_visible_in_tree() or ctl.size.x <= 0.0 or ctl.size.y <= 0.0 or ctl is BoxContainer or ctl is GridContainer:
				continue
			count += 1
			if win.encloses(ctl.get_global_rect()):
				continue
			var sc: ScrollContainer = null
			var p := ctl.get_parent()
			while p != null and sc == null:
				if p is ScrollContainer:
					sc = p
				p = p.get_parent()
			if sc == null:
				stray.append("%s %s" % [ctl.name, str(ctl.get_global_rect())])
				continue
			sc.ensure_control_visible(ctl)
			await process_frame
			if not win.encloses(ctl.get_global_rect()):
				stray.append("%s %s after scrolling" % [ctl.name, str(ctl.get_global_rect())])
		_check(count > 20 and stray.is_empty(), "Every control in the Shape pane is on screen or a scroll away (%s: %d controls, %d stray, first %s)" % [tag, count, stray.size(), stray.slice(0, 2)])
		# The foot of the oval and the last bench spot take a finger.
		var sc2: ScrollContainer = current_scene.find_child("ShapeScroll", true, false)
		_check(sc2 != null and sc2.get_v_scroll_bar().max_value > sc2.size.y, "The Shape pane scrolls (%s)" % tag)
		var spot: Control = board.find_child("Spot_FF", true, false)
		var bench: Control = board.find_child("BenchSpot_4", true, false)
		_check(spot != null and bench != null, "The full forward and the last bench spot are there (%s)" % tag)
		if spot == null or bench == null:
			continue
		var shown := [""]
		board.inspect.connect(func(id: String): shown[0] = id)
		var why: String = await Tap.tap(spot)
		_check(why == "" and shown[0] != "", "A finger on the full forward at the foot of the oval opens his profile (%s: %s)" % [tag, why])
		current_scene.call("_close_profile")
		await _settle()
		if sz.x != 390:
			continue
		# A swipe that begins on a guernsey scrolls the pane and opens nobody.
		sc2 = current_scene.find_child("ShapeScroll", true, false)
		board = current_scene.find_child("Best22Board", true, false)
		var from: Control = board.find_child("Spot_C", true, false)
		sc2.scroll_vertical = 0
		await process_frame
		var opened := [false]
		board.inspect.connect(func(_id: String): opened[0] = true)
		var a := from.get_global_rect().get_center()
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = a
		t.pressed = true
		Input.parse_input_event(t)
		Input.flush_buffered_events()
		for step in range(1, 9):
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = a + Vector2(0, -30.0 * step)
			d.relative = Vector2(0, -30.0)
			Input.parse_input_event(d)
			Input.flush_buffered_events()
			await process_frame
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = a + Vector2(0, -240.0)
		up.pressed = false
		Input.parse_input_event(up)
		Input.flush_buffered_events()
		await _settle()
		_check(sc2.scroll_vertical > 100 and not opened[0], "A swipe starting on a guernsey scrolls the Shape pane and opens nobody (%s: scrolled %d)" % [tag, sc2.scroll_vertical])



## Row 57: the hub's settings list the earlier saves, and a real tap on
## Restore opens that point of the career. (Back up and Load a backup open the
## system's file dialog, which a test cannot drive; their logic is covered by
## the save suite's export and import tests.)
func _test_restore_earlier_save_tap() -> void:
	_state.delete_saved_career()
	_state.reset()
	_state.start_season("STK", _db.club_list("STK"))
	_check(_state.save_career(), "Round 1 is saved")
	# On to round 2 without playing round 1's matches (seconds the restore does not read).
	_state.season.round_index = 1
	_check(_state.save_career(), "Round 2 is saved")
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	await _past_press()
	var hub_settings: Button = current_scene.find_child("HubSettings", true, false)
	if hub_settings != null:
		hub_settings.emit_signal("pressed")
		await _settle()
	_check(current_scene.find_child("SavesExport", true, false) != null
			and current_scene.find_child("SavesImport", true, false) != null,
			"Back up career and Load a backup are in Settings")
	var row := current_scene.find_child("EarlierSave1", true, false)
	_check(row != null, "The round 1 save is listed")
	if row == null:
		return
	var why: String = await Tap.tap(row.find_child("Restore", true, false))
	await _settle()
	_check(why == "", "A finger's tap reaches Restore: %s" % why)
	_check(_router.current() == "hub" and _state.season != null and _state.season.round_index == 0,
			"Restore opens the career at round 1 again")
	_state.delete_saved_career()


## Row 111: a sacked coach chooses from the clubs with a job open, or retires
## with his record read out. Real taps on a 390 phone.
func _sacked_with_offers() -> void:
	_state.reset()
	_state.career_seed = 4403
	_state.replay_seed = 4403
	_state.start_season("FRE", _db.club_list("FRE"))
	var arcs = load("res://scripts/sim/CoachArcs.gd")
	var moves = load("res://scripts/state/ClubMoves.gd")
	_state.coach_arcs = arcs.ensure(_state.coach_arcs)
	var st: Dictionary = _state.coach_arcs
	_state.board["sacked"] = true
	st["sack"] = {"from": "FRE", "year": int(_state.season_year), "heir": ""}
	st["offers"] = moves._jobs_after_sack(_state, st)
	_state.week_events = []


## A finished career's hub: the season title, Settings and the record, with
## no club standing, pick or board above it.
func _check_record_only(why: String) -> void:
	for gone in ["SeasonBlock", "LadderPosition", "DraftPickLine", "HubAlmanac", "BoardLine", "BoardWarning", "ReprieveLine"]:
		_check(current_scene.find_child(gone, true, false) == null, "%s: the hub shows no %s" % [why, gone])
	_check(current_scene.find_child("HubSettings", true, false) != null and current_scene.find_child("SackedCard", true, false) != null,
			"%s: Settings and the card stay" % why)


func _test_sacked_job_choice_taps() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var moves = load("res://scripts/state/ClubMoves.gd")
	_sacked_with_offers()
	var jobs: Array = moves.offers(_state)
	_check(jobs.size() == 3, "A sacked coach is offered three clubs with a job open (%d)" % jobs.size())
	# The board's verdict is in: its old warning and the club's pick are stale.
	_state.board["warned"] = true
	_state.board["confidence"] = 25
	# The carnival week's sheet is the club's business, not a sacked coach's.
	_state.midseason["year"] = _state.season_year
	_state.midseason["carnival"] = [{"name": "Riley Bowman", "pos": "midfielder", "state": "Vic Metro"}]
	_state.midseason["carnival_seen"] = false
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	_check(root.find_child("CarnivalWeek", true, false) == null and current_scene.find_child("CarnivalWeek", true, false) == null,
			"A sacked coach is not shown the carnival week's sheet")
	for stale in ["BoardLine", "BoardWarning", "DraftPickLine"]:
		_check(current_scene.find_child(stale, true, false) == null, "While he chooses, the hub shows no stale %s" % stale)
	_check(current_scene.find_child("SackedCard", true, false) != null, "The hub leads with the sacked card")
	_check(current_scene.find_child("SackedSeasonReview", true, false) != null and current_scene.find_child("SackedMainMenu", true, false) != null,
			"While he chooses, the season review and the main menu are still on the card")
	for o in jobs:
		var nm: Label = current_scene.find_child("JobOfferName_%s" % str(o["code"]), true, false)
		_check(nm != null and nm.get_line_count() == 1 and nm.size.x > 100,
				"%s's name reads on one line across the card, not a letter at a time" % str(o["name"]))
	var code: String = str(jobs[-1]["code"]) if not jobs.is_empty() else ""
	var take: Button = current_scene.find_child("TakeJob_%s" % code, true, false)
	_check(take != null and take.get_combined_minimum_size().x <= take.size.x + 0.5,
			"Each club with a job open has a Take button that reads whole on a 390 phone")
	# Taking a job opens the new club's off-season market (seconds of rival
	# trading this test does not read): marked open already, so the tap
	# proves the move alone.
	_state.offseason_year = _state.season_year
	var why: String = await Tap.tap(take) if take != null else "missing"
	await _settle()
	# Row 179: he is that club's coach from the tap, so every off-season call is theirs.
	_check(why == "" and not _state.is_sacked() and str(_state.my_club) == code and _state.my_list == _state.season.lists.get(code, []),
			"A finger on Take the job ends the sacking and he coaches %s from that day, not Fremantle (%s; club %s)" % [code, why, str(_state.my_club)])
	_check(current_scene.find_child("SackedCard", true, false) == null, "The hub rebuilds without the sacked card")
	# Row T5.Q25: Tasmania join the league next season, so their job is one of
	# the three, with no ladder finish; a finger on it sets the move, which is
	# made at their first National Draft.
	_sacked_with_offers()
	_router.go("hub")
	await _settle()
	var tas_why: Label = current_scene.find_child("JobOfferFrom_TAS", true, false)
	_check(moves.offers(_state).any(func(o): return str(o["code"]) == "TAS" and int(o.get("joins", 0)) == int(_state.season_year) + 1)
			and tas_why != null and tas_why.text.begins_with("Tasmania join the league in %d." % (int(_state.season_year) + 1)),
			"A club joining next season offers its job, saying when it joins (%s)" % (tas_why.text if tas_why != null else "missing"))
	take = current_scene.find_child("TakeJob_TAS", true, false)
	_check(take != null and take.get_combined_minimum_size().x <= take.size.x + 0.5, "Tasmania's Take button reads whole on a 390 phone")
	# The sacking comes at the season's close: the home-and-away rounds are done.
	_state.season.round_index = _state.season.fixture.size()
	why = await Tap.tap(take) if take != null else "missing"
	for i in range(900):
		if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	# Row 189: Fremantle play out the off-season under their own staff and he
	# goes straight to Tasmania's first National Draft as their coach.
	_check(why == "" and not _state.is_sacked() and _router.current() == "draft" and _state.my_club == "TAS"
			and _state.draft != null and _state.draft.user_club == "TAS",
			"A finger on Take the job at Tasmania opens their first National Draft with him as their coach (%s; screen %s, club %s)" % [
			why, _router.current(), _state.my_club])
	# A fresh sacking: retire instead, and the record is read out.
	_sacked_with_offers()
	_router.go("hub")
	await _settle()
	var retire: Button = current_scene.find_child("RetireCoach", true, false)
	why = await Tap.tap(retire) if retire != null else "missing"
	await _settle()
	var sheet: Control = current_scene.find_child("RetireSheet", true, false)
	if sheet == null:
		sheet = root.find_child("RetireSheet", true, false)
	_check(why == "" and sheet != null, "A finger on Retire from coaching asks first (%s)" % why)
	var yes: Button = sheet.find_child("RetireConfirm", true, false) if sheet != null else null
	why = await Tap.tap(yes) if yes != null else "missing"
	await _settle()
	_check(why == "" and moves.retired(_state) and _state.is_sacked(), "A finger on the confirm retires the coach (%s)" % why)
	var rec: Control = current_scene.find_child("CoachRecord", true, false)
	var parts := []
	if rec != null:
		_texts(rec, parts)
	var text := " | ".join(parts)
	_check(rec != null and text.contains("Your record") and text.contains(str(_db.club_name("FRE"))) and text.contains("season"),
			"The retired card reads out his record (%s)" % text.replace("\n", " | "))
	_check(not _state.start_next_season(), "A retired coach's season does not roll on")
	_check_record_only("retired")
	# Sacked with no second chance left: the same, the record alone.
	_sacked_with_offers()
	_state.coach_arcs["offers"] = []
	_state.coach_arcs["coach"]["reprieves"] = 0
	_state.board["warned"] = true
	_state.board["confidence"] = 25
	_router.go("hub")
	await _settle()
	_check(moves.career_over(_state) and current_scene.find_child("CoachRecord", true, false) != null,
			"A career that is over reads out the record")
	_check_record_only("career over")
	_state.board["sacked"] = false
	_state.coach_arcs = {}
	root.size = size_before


## A strong season's real close at Fremantle (row 112): the home-and-away
## rounds skipped with Fremantle top of the ladder, so they play the finals
## and meet the board's goal, and the close writes a rival board's letter that
## holds the off-season until he answers.
func _season_with_letter(tas_joins := true) -> void:
	_state.reset()
	_state.career_seed = 4411
	_state.replay_seed = 4411
	_state.start_season("FRE", _db.club_list("FRE"))
	# A club joining next season writes first (row T5.Q25); without one, the
	# letter comes from a club on the ladder. reset() puts the year back.
	if not tas_joins:
		_db.set_enter_year("TAS", 9999)
	var arcs = load("res://scripts/sim/CoachArcs.gd")
	_state.coach_arcs = arcs.ensure(_state.coach_arcs)
	var season = _state.season
	season.round_index = season.fixture.size()
	season.ladder["FRE"]["w"] = 20
	season.recalc_ladder()
	_state.ensure_finals()
	while not season.is_season_over():
		_state.advance()
	# The hub's other first-visit and weekly asks come before the letter; this
	# test is about the letter.
	_state.week_events = []
	_state.media_conference = {}
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.postseason_intro_seen = true


func _test_rival_letter_taps() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var moves = load("res://scripts/state/ClubMoves.gd")
	_season_with_letter(false)
	_check(moves.letter_open(_state) and not _state.offseason_open(),
			"A strong season ends with a rival board's letter, and the off-season waits for the answer")
	# The same letter is answered twice (Stay, then Take): the career is saved
	# here and loaded for the second answer instead of playing its finals again.
	var letter_was: Dictionary = moves.letter(_state).duplicate(true)
	_check(_state.save_career(), "The career with the letter saves")
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var card: Control = current_scene.find_child("RivalLetter", true, false)
	_check(card != null and current_scene.find_child("RivalLetterRisk", true, false) != null,
			"The hub shows the letter and its risk")
	_check(not _screen_text().contains("National Draft") and not _screen_text().contains("Trades & Contracts"),
			"While the letter is open, trades, contracts and the draft wait for his answer")
	var stay: Button = current_scene.find_child("RivalLetterStay", true, false)
	var take: Button = current_scene.find_child("RivalLetterTake", true, false)
	_check(stay != null and take != null and stay.get_combined_minimum_size().x <= stay.size.x + 0.5
			and take.get_combined_minimum_size().x <= take.size.x + 0.5,
			"Stay and Take read whole on a 390 phone")
	var why: String = await Tap.tap(stay) if stay != null else "missing"
	await _settle()
	_check(why == "" and str(moves.letter(_state).get("answer", "")) == "declined" and _state.my_club == "FRE"
			and (_state.coach_arcs["move"] as Dictionary).is_empty() and _state.offseason_open(),
			"A finger on Stay turns the job down: he stays and the off-season opens at Fremantle (%s)" % why)
	_check(current_scene.find_child("RivalLetterAnswered", true, false) != null and _screen_text().contains("National Draft")
			and _screen_text().contains("Trades & Contracts"),
			"After the answer the hub says so, and trades, contracts and the draft are back")
	# A ladder club's letter, taken.
	_check(_state.load_career() and moves.letter(_state) == letter_was and moves.letter_open(_state)
			and _state.my_club == "FRE" and not _state.offseason_open(),
			"The saved career loads with its letter still unanswered (%s)" % str(moves.letter(_state)))
	_db.set_enter_year("TAS", 9999)
	_state.week_events = []
	_state.media_conference = {}
	_state.postseason_intro_seen = true
	var code := str(moves.letter(_state).get("code", ""))
	_router.go("hub")
	await _settle()
	take = current_scene.find_child("RivalLetterTake", true, false)
	why = await Tap.tap(take) if take != null else "missing"
	await _settle()
	_check(why == "" and code != "" and _state.my_club == code and (_state.coach_arcs["move"] as Dictionary).is_empty()
			and _state.offseason_open(),
			"A finger on Take moves him to %s at once and the off-season opens there (%s)" % [code, why])
	var answered: Label = current_scene.find_child("RivalLetterAnswered", true, false)
	_check(answered != null and answered.text.contains("senior coach now") and answered.text.contains("Fremantle have ")
			and answered.text.contains(_db.club_name(code)) and _screen_text().contains("National Draft")
			and _screen_text().contains("Trades & Contracts"),
			"After taking it the hub says so, who replaced him at Fremantle and where from, and his new club's trades, contracts and draft are open (%s)"
			% (answered.text if answered != null else "missing"))
	# Row T5.Q25: Tasmania, joining next season, write first. Taken, he
	# takes over at their first National Draft, which opens at once:
	# Fremantle play out the off-season under their own staff (row 189).
	_season_with_letter()
	_check(str(moves.letter(_state).get("code", "")) == "TAS", "A strong season before Tasmania join brings their letter")
	_router.go("hub")
	await _settle()
	var start: Label = current_scene.find_child("RivalLetterStart", true, false)
	_check(start != null and start.text.contains("National Draft"),
			"The letter says he would take over at their first National Draft (%s)" % (start.text if start != null else "missing"))
	take = current_scene.find_child("RivalLetterTake", true, false)
	why = await Tap.tap(take) if take != null else "missing"
	for i in range(900):
		if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	_check(why == "" and _router.current() == "draft" and _state.my_club == "TAS"
			and _state.draft != null and _state.draft.user_club == "TAS",
			"A finger on Take signs him with Tasmania and opens their first National Draft with him as their coach (%s; screen %s, club %s)" % [
			why, _router.current(), _state.my_club])
	_check(_state.trade_offers.is_empty() and _state.trade_requests.is_empty() and _state.staff_vacancies.is_empty(),
			"Fremantle's trades, contracts and staff jobs were their own staff's: none is left for him")
	root.size = size_before


## Skip to the end of the season (director, 2026-11-07; 2026-11-08: "It's just
## skipping games, no off season skipping"): a finger on the quiet button asks
## first, Cancel skips nothing, and the skip lands on the same finished season
## Sim the week reaches, before the off-season, which survives a save and a reload.
func _skip_shape() -> Dictionary:
	return {"year": _state.season_year, "over": _state.season.is_season_over(), "off": _state.offseason_year,
			"pre": _state.preseason_active(), "wrap": _state.needs_season_wrap(),
			"round": _state.season.round_index, "premier": _state.premier(),
			"ladder": _state.my_position(), "record": _state.my_record(), "list": _state.my_list.size()}


func _skip_start(seed: int) -> void:
	_state.reset()
	_state.career_seed = seed
	_state.replay_seed = seed
	_state.start_season("FRE", _db.club_list("FRE"))
	_state.week_events = []
	_state.season.round_index = _state.season.fixture.size() - 1


## The last home-and-away round played, its card settled: the finals are next.
func _skip_start_finals(seed: int) -> void:
	_skip_start(seed)
	_state.advance()
	_state._settle_week_event()
	_state.week_events = []
	_state.media_conference = {}


## The finals' first training report opens over the hub: closed, as a coach would.
func _close_hub_report() -> void:
	load("res://scripts/ui/TrainingReportSheet.gd").close_top(current_scene)
	await _settle()


## How long a test finger stays down for a long press: past HoldPress.SECONDS.
const HOLD_HELD := 0.75


## The week's main button, which carries the season skip on a long press.
func _bulk_skip_button() -> Button:
	for n in current_scene.find_children("*", "Button", true, false):
		if (n as Button).has_meta("bulk_skip") and (n as Button).is_visible_in_tree():
			return n as Button
	return null


func _touch(at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = at
	t.pressed = down
	Input.parse_input_event(t)
	Input.flush_buffered_events()


func _drag(from: Vector2, to: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = to
	d.relative = to - from
	Input.parse_input_event(d)
	Input.flush_buffered_events()


## The season skips are long presses of the week's button at the bottom right
## (director, 2026-11-12), not lines on the hub: by finger, a tap does what the
## button always did, a hold fills the cue and opens the skip (Skip the home and
## away in the home and away, the season in the finals), a drag off the button
## stops it, a mouse hold works too, and Android Back closes what it opened.
func _test_skip_long_press() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var way_before: String = _state.match_way()
	_state.set_match_way("watch")
	_skip_start(5513)
	_state.season.round_index = _state.season.fixture.size() - 3
	var start_round: int = _state.season.round_index
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var words := []
	_texts(current_scene, words)
	var on_hub := " | ".join(words)
	_check(current_scene.find_child("SkipHomeAway", true, false) == null and current_scene.find_child("SkipSeason", true, false) == null
			and not on_hub.contains("Skip the rest of the home and away") and not on_hub.contains("Skip to the end of the"),
			"The hub shows neither season skip as a line of its own")
	var b := _bulk_skip_button()
	_check(b != null and b.name == "SimRound" and str(b.get_meta("bulk_skip")) == "choice", "Sim the week holds the skips")
	var play_btn: Node = current_scene.find_child("PlayMatch", true, false)
	_check(play_btn != null and play_btn.get_node_or_null("HoldCue") == null, "Play match is a plain button")
	if b == null:
		return
	var r := b.get_global_rect()
	_check(r.end.x > 300.0 and r.position.y > 600.0, "It is the button at the bottom right (%s)" % r)
	_check(b.size.y >= 44.0, "A thumb-sized target (%.0f)" % b.size.y)
	var cue = b.get_node("HoldCue")
	var words_was := b.text
	var mid := Tap.pixel_point(b, b.size * 0.5)

	# Halfway through a hold: the cue is filling, the words say what it does, nothing has opened.
	_touch(mid, true)
	await create_timer(0.3).timeout
	_check(cue.progress > 0.2 and cue.progress < 0.95 and b.text == "Skip ahead"
			and current_scene.find_child("SkipChoice", true, false) == null,
			"Mid-hold the cue fills (%.2f) and says %s, and nothing opens yet" % [cue.progress, b.text])
	await create_timer(0.4).timeout
	_check(current_scene.find_child("SkipChoice", true, false) != null,
			"Held to the end, it opens the choice of skips while the finger is still down")
	_touch(mid, false)
	await _settle()
	_check(current_scene.scene_file_path.ends_with("HubScene.tscn") and _state.season.round_index == start_round
			and b.text == words_was and cue.progress == 0.0,
			"Lifting the finger after it does not play the match too (round %d, %s)" % [_state.season.round_index, b.text])
	# The choice offers both skips, thumb-sized, and each opens its own survey.
	for pick in [["SkipChoiceHomeAway", "home_away", "Skip the home and away"], ["SkipChoiceSeason", "season", "Skip the season"]]:
		var choice: Button = current_scene.find_child(str(pick[0]), true, false)
		_check(choice != null and choice.size.y >= 48.0 and choice.size.x >= 280.0,
				"The choice offers %s, thumb-sized (%s)" % [pick[2], choice.size if choice != null else "none"])
		var said := []
		if choice != null:
			_texts(choice.get_parent(), said)
		_check(said.has(str(pick[2])), "It is called %s (%s)" % [pick[2], said])
		var why0: String = await Tap.tap(choice) if choice != null else "missing"
		await _settle()
		_check(why0 == "" and current_scene.find_child("SkipChoice", true, false) == null
				and current_scene.find_child("SkipSeasonSurvey", true, false) != null and current_scene._skip_to == str(pick[1])
				and _state.season.round_index == start_round,
				"A finger on %s opens its survey and skips nothing yet (%s, %s)" % [pick[2], why0, current_scene._skip_to])
		_router.handle_back(true)
		await _settle()
		_check(current_scene.find_child("SkipSeasonSurvey", true, false) == null, "Android Back closes the survey")
		if pick[1] == "home_away":
			b = _bulk_skip_button()
			await Tap.hold_at(b, b.size * 0.5, HOLD_HELD)
			await _settle()
	b = _bulk_skip_button()
	await Tap.hold_at(b, b.size * 0.5, HOLD_HELD)
	await _settle()
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("SkipChoice", true, false) == null and current_scene.scene_file_path.ends_with("HubScene.tscn"),
			"Android Back closes the choice, back to the hub")

	# A hold let go once its cue shows, or a finger that slips, is neither a skip nor a tap.
	b = _bulk_skip_button()
	var seen_taps := [0]
	var hold_cue = b.get_node("HoldCue")
	var tap_was: Array = hold_cue._taps.duplicate()
	hold_cue._taps = [func(): seen_taps[0] += 1]
	mid = Tap.pixel_point(b, b.size * 0.5)
	_touch(mid, true)
	await create_timer(0.3).timeout
	_touch(mid, false)
	await _settle()
	_check(seen_taps[0] == 0 and current_scene.find_child("SkipChoice", true, false) == null and _state.season.round_index == start_round,
			"A hold let go after its cue showed does nothing (taps %d, round %d)" % [seen_taps[0], _state.season.round_index])
	var slip := mid + Vector2(minf(30.0, b.size.x * 0.3), 0)
	_touch(mid, true)
	await create_timer(0.05).timeout
	_drag(mid, slip)
	await create_timer(0.05).timeout
	_touch(slip, false)
	await _settle()
	_check(seen_taps[0] == 0 and _state.season.round_index == start_round,
			"A finger that slips on the button and lifts there does nothing (taps %d)" % seen_taps[0])
	var why_t: String = await Tap.tap(b)
	await _settle()
	_check(why_t == "" and seen_taps[0] == 1, "A quick still tap after them still taps (taps %d)" % seen_taps[0])
	hold_cue._taps = tap_was

	# A finger that drags off the button: no skip, no tap.
	b = _bulk_skip_button()
	cue = b.get_node("HoldCue")
	var taps := [0]
	var on_tap := func(): taps[0] += 1
	b.pressed.connect(on_tap)
	mid = Tap.pixel_point(b, b.size * 0.5)
	var off := mid - Vector2(0, b.size.y + 40.0)
	_touch(mid, true)
	await create_timer(0.15).timeout
	_drag(mid, off)
	await create_timer(0.6).timeout
	_touch(off, false)
	await _settle()
	_check(current_scene.find_child("SkipChoice", true, false) == null and taps[0] == 0 and cue.progress == 0.0
			and _state.season.round_index == start_round, "A drag off the button stops the hold, and nothing is tapped (%d)" % taps[0])

	# A mouse held on it does the same as a finger.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = mid
	mb.global_position = mid
	mb.pressed = true
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
	await create_timer(HOLD_HELD).timeout
	var up := mb.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _settle()
	_check(current_scene.find_child("SkipChoice", true, false) != null and current_scene.scene_file_path.ends_with("HubScene.tscn")
			and _state.season.round_index == start_round, "A mouse held on it opens the skips too, and plays nothing")
	b.pressed.disconnect(on_tap)
	_router.handle_back(true)
	await _settle()

	# A tap is the old Sim the week: it asks first or sims the round, no skip.
	b = _bulk_skip_button()
	var why: String = await Tap.tap(b)
	await _settle()
	_check(why == "" and current_scene.find_child("SkipSeasonSurvey", true, false) == null
			and current_scene.find_child("SkipChoice", true, false) == null
			and (current_scene.find_child("SimConfirm", true, false) != null or _state.season.round_index == start_round + 1),
			"A tap sims the week as before (%s, round %d)" % [why, _state.season.round_index])

	# In the finals the same hold skips to the end of them.
	_skip_start_finals(5513)
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	await _close_hub_report()
	b = _bulk_skip_button()
	_check(b != null and str(b.get_meta("bulk_skip")) == "season", "In the finals the week's button holds the rest of the season (%s)" % (b.name if b != null else "none"))
	why = await Tap.hold_at(b, b.size * 0.5, HOLD_HELD) if b != null else "missing"
	await _settle()
	_check(why == "" and current_scene.find_child("SkipSeasonSurvey", true, false) != null and current_scene._skip_to == "season"
			and not _state.season.is_season_over(), "A hold in the finals opens the skip to the end of them (%s)" % why)
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("SkipSeasonSurvey", true, false) == null, "Android Back closes it")
	_state.set_match_way(way_before)
	_state.week_events = []
	_state.media_conference = {}
	_router.stack = ["main"]
	root.size = size_before


## On a wide screen (PC) the week's bottom-right button is Sim the week too:
## the hold goes on whichever week button sits at the bottom right.
func _test_skip_hold_wide() -> void:
	var size_before := root.size
	root.size = Vector2i(1280, 720)
	_skip_start(5514)
	_state.season.round_index = _state.season.fixture.size() - 3
	var start_round: int = _state.season.round_index
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var b := _bulk_skip_button()
	var play: Control = current_scene.find_child("PlayMatch", true, false)
	_check(current_scene.find_child("HubFooterWide", true, false) != null, "The hub is in its wide layout")
	_check(b != null and b.name == "SimRound" and play != null
			and b.get_global_rect().end.x > play.get_global_rect().end.x and b.get_global_rect().position.y >= play.get_global_rect().position.y - 1.0,
			"On a wide screen the hold is on the week's bottom-right button, Sim the week (%s at %s, Play match at %s)" % [
			b.name if b != null else "none", b.get_global_rect() if b != null else "", play.get_global_rect() if play != null else ""])
	_check(play != null and play.get_node_or_null("HoldCue") == null, "Play match is a plain button there")
	if b == null:
		root.size = size_before
		return
	_check(b.get_global_rect().position.y > 720.0 * 0.6, "It sits at the bottom (%s)" % b.get_global_rect())
	var why: String = await Tap.hold_at(b, b.size * 0.5, HOLD_HELD)
	await _settle()
	_check(why == "" and current_scene.find_child("SkipChoice", true, false) != null and _state.season.round_index == start_round,
			"A hold on it opens the choice of skips and sims nothing (%s, round %d)" % [why, _state.season.round_index])
	_router.handle_back(true)
	await _settle()
	_check(current_scene.find_child("SkipChoice", true, false) == null, "Android Back closes it")
	_router.stack = ["main"]
	root.size = size_before


func _test_skip_season() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var ask_before: bool = _state.confirm_sim_round()
	_state.set_confirm_sim_round(false)

	# Played out the long way: Sim the week until the season is over. Both
	# runs start in the finals, where the long press skips to the end of them.
	# The start is saved and loaded for the second run rather than played again.
	_skip_start_finals(5511)
	_check(_state.save_career(), "The finals start saves")
	var year: int = _state.season_year
	var guard := 0
	while not _state.season.is_season_over() and guard < 80:
		_state.advance()
		guard += 1
	var played := _skip_shape()

	# Skipped: a long press of the week's button asks first.
	_check(_state.load_career() and _state.season_year == year and not _state.season.is_season_over(),
			"The finals start loads, the season not over")
	_state.week_events = []
	_state.media_conference = {}
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	await _close_hub_report()
	var b := _bulk_skip_button()
	_check(b != null and str(b.get_meta("bulk_skip")) == "season", "In the finals the week's button holds the skip to the end of the %d season" % year)
	var why: String = await Tap.hold_at(b, b.size * 0.5, HOLD_HELD) if b != null else "missing"
	await _settle()
	var sheet: Node = current_scene.find_child("SkipSeasonSurvey", true, false)
	_check(why == "" and sheet != null and _state.season_year == year,
			"A finger held on it opens the survey and skips nothing yet (%s)" % why)
	var cancel: Button = current_scene.find_child("SkipSeasonCancel", true, false)
	why = await Tap.tap(cancel) if cancel != null else "missing"
	await _settle()
	_check(why == "" and current_scene.find_child("SkipSeasonSurvey", true, false) == null
			and _state.season_year == year and not _state.season.is_season_over(),
			"A finger on Cancel closes it and skips nothing (%s)" % why)

	# The survey by finger: each question opens on the club's answer; a tap
	# chooses another, Back steps back with it kept, Next walks on.
	b = _bulk_skip_button()
	why = await Tap.hold_at(b, b.size * 0.5, HOLD_HELD) if b != null else "missing"
	await _settle()
	var plan_before: String = _state.club_plan
	var steps := []
	var keys := _skip_keys("season")
	var want_steps := []
	for i in range(keys.size()):
		want_steps.append("Before you skip · %d of %d" % [i + 1, keys.size()])
	for q in keys:
		var count: Label = current_scene.find_child("SkipStepCount", true, false)
		steps.append(count.text if count != null else "")
		var chosen: Button = current_scene.find_child("SkipOption_%s_%s" % [q, str(_rules("SkipOrders").defaults(plan_before)[q])], true, false)
		_check(chosen != null and current_scene.find_child("SkipOptions_" + q, true, false) != null,
				"The survey asks %s, opened on the club's answer" % q)
		var nx: Button = current_scene.find_child("SkipNext", true, false)
		why = await Tap.tap(nx) if nx != null else "missing"
		await _settle()
		_check(why == "", "A finger on Next walks on from %s (%s)" % [q, why])
	_check(steps == want_steps, "The survey counts its steps (%s)" % [steps])
	_check(current_scene.find_child("SkipSeasonConfirm", true, false) != null, "After the last question the sheet asks")
	var said := ["SkipLeft", "SkipStop"]
	for k in keys:
		said.append("SkipAnswer_" + str(k))
	for n in said:
		_check(current_scene.find_child(n, true, false) != null, "The sheet says what is decided: %s" % n)
	var left0: Label = current_scene.find_child("SkipLeft", true, false)
	_check(left0 != null and left0.text.ends_with("the rest of the finals."), "The sheet says the finals are what is left (%s)" % (left0.text if left0 != null else ""))
	for n in ["SkipAnswer_contracts", "SkipAnswer_draft", "SkipTrades"]:
		_check(current_scene.find_child(n, true, false) == null, "The sheet asks nothing of the off-season: no %s" % n)
	# Android Back steps back a question; a finger picks another answer there.
	current_scene.handle_back()
	await _settle()
	var other: Button = current_scene.find_child("SkipOption_questions_players", true, false)
	_check(current_scene.find_child("SkipSeasonSurvey", true, false) != null and other != null,
			"Back from the sheet returns to the last question")
	why = await Tap.tap(other) if other != null else "missing"
	await _settle()
	_check(why == "" and current_scene._skip_answers.get("questions") == "players", "A finger on Back the players chooses it (%s)" % why)
	var best: Button = current_scene.find_child("SkipOption_questions_usual", true, false)
	why = await Tap.tap(best) if best != null else "missing"
	await _settle()
	_check(why == "" and current_scene._skip_answers.get("questions") == "usual", "A finger on the club's usual answer chooses it again (%s)" % why)
	var nx2: Button = current_scene.find_child("SkipNext", true, false)
	why = await Tap.tap(nx2) if nx2 != null else "missing"
	await _settle()
	var go: Button = current_scene.find_child("SkipSeasonGo", true, false)
	why = await Tap.tap(go) if go != null else "missing"
	guard = 0
	while not _state.season.is_season_over() and guard < 600:
		await process_frame
		guard += 1
	for i in range(30):
		await process_frame
	_check(why == "" and _state.season.is_season_over() and _state.season_year == year,
			"A finger on Skip the season plays out the %d season (%s)" % [year, why])
	# The last match opens the off-season as it does after Sim the week (rivals
	# settle their contracts); nothing of the coach's own is done for him.
	# A strong season can end in a rival board's letter (row 112), which holds
	# the off-season until he answers, as it does after Sim the week.
	var held: bool = load("res://scripts/state/ClubMoves.gd").letter_open(_state)
	_check((_state.offseason_open() or held) and not _state.needs_season_wrap() and _state.draft == null,
			"It stops where the last Sim the week does: re-signings, trades and the draft are still the coach's")
	var skipped := _skip_shape()
	_check(skipped == played, "A skipped season lands where a played one does (%s vs %s)" % [skipped, played])
	_check(_bulk_skip_button() == null and current_scene.find_child("SeasonWrap", true, false) == null,
			"The hub shows the season over, with nothing more to skip and no off-season wrap")

	# A save and a reload keep it.
	_check(_state.save_career(), "The skipped career saves")
	_check(_state.load_career(), "The skipped career loads")
	_check(_skip_shape() == skipped, "A reload keeps the skipped season")

	# The last week's card opens at the end of the skip, as after Sim the week.
	_state.media_conference = {}
	_state.week_events = []
	_router.go("hub")
	await _settle()
	_state.week_events = [_state.story_card("members_open_training")]
	current_scene.call("_skip_season", {})
	await _settle()
	_check(current_scene.find_child("EventSheet", true, false) != null,
			"A new card at the end of the skip opens over the hub, as after Sim the week")
	_router.handle_back(true)
	await _settle()
	_state.week_events = []
	_state.set_confirm_sim_round(ask_before)
	root.size = size_before


## Skip just the home and away (director, 2026-11-09): by finger, it stops after
## the last round with the finals drawn and his to coach, lands where Sim the
## week does, survives a reload, and the finals then skip as ever. The label
## fits a phone at the largest text, and the survey asks only what it can act on.
func _test_skip_home_away() -> void:
	var size_before := root.size
	root.size = Vector2i(390, 844)
	var ask_before: bool = _state.confirm_sim_round()
	_state.set_confirm_sim_round(false)

	# Played out the long way: Sim the week to the last home-and-away round.
	_skip_start(5512)
	_state.season.round_index = _state.season.fixture.size() - 3
	var year: int = _state.season_year
	var guard := 0
	while not _state.season.is_regular_done() and guard < 80:
		_state.advance()
		guard += 1
	var played := _skip_shape()

	_skip_start(5512)
	var start_round: int = _state.season.fixture.size() - 3
	_state.season.round_index = start_round
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var b := _bulk_skip_button()
	_check(b != null and str(b.get_meta("bulk_skip")) == "choice",
			"In the home and away the week's button holds the choice of skips")
	var why: String = await Tap.hold_at(b, b.size * 0.5, HOLD_HELD) if b != null else "missing"
	await _settle()
	var ha: Button = current_scene.find_child("SkipChoiceHomeAway", true, false)
	why = await Tap.tap(ha) if ha != null else "missing"
	await _settle()
	_check(why == "" and current_scene.find_child("SkipSeasonSurvey", true, false) != null and _state.season.round_index == start_round,
			"A finger held on it opens the survey and skips nothing yet (%s)" % why)
	var lead: Label = current_scene.find_child("SkipLead", true, false)
	_check(lead != null and lead.text.contains("home and away"), "The first question says the home and away (%s)" % (lead.text if lead != null else ""))
	for q in _rules("SkipOrders").KEYS:
		var nx: Button = current_scene.find_child("SkipNext", true, false)
		why = await Tap.tap(nx) if nx != null else "missing"
		await _settle()
		_check(why == "", "A finger on Next walks on from %s (%s)" % [q, why])
	var left: Label = current_scene.find_child("SkipLeft", true, false)
	_check(left != null and left.text == "The rest of the %d home and away season is played out without you: 3 rounds." % year,
			"The sheet says only the rounds go (%s)" % (left.text if left != null else ""))
	var stop: Label = current_scene.find_child("SkipStop", true, false)
	_check(stop != null and stop.text.contains("if you make the finals, you coach them"), "The sheet says the finals are his (%s)" % (stop.text if stop != null else ""))
	_check(stop != null and not stop.text.contains("sacks"), "It warns of no sacking: the board only sacks after the finals")
	var go: Button = current_scene.find_child("SkipSeasonGo", true, false)
	_check(go != null and go.text == "Skip the home and away", "The button says what it skips")
	why = await Tap.tap(go) if go != null else "missing"
	guard = 0
	while not _state.season.is_regular_done() and guard < 600:
		await process_frame
		guard += 1
	for i in range(30):
		await process_frame
	await _settle()
	_check(why == "" and _state.season.is_regular_done() and not _state.season.is_season_over() and _state.season_year == year,
			"A finger on Skip the home and away plays every round and no final (%s)" % why)
	_check(not _state.season.finals.is_empty() and int(_state.season.finals.get("week", 0)) == 1,
			"The finals are drawn and none has been played")
	var skipped := _skip_shape()
	_check(skipped == played, "It lands where Sim the week does (%s vs %s)" % [skipped, played])
	# The last round's press conference comes first, as after Sim the week; then the hub.
	_state.media_conference = {}
	_state.week_events = []
	_router.stack = ["main"]
	_router.go("hub")
	await _settle()
	var held_after := _bulk_skip_button()
	_check(held_after != null and str(held_after.get_meta("bulk_skip")) == "season",
			"With the home and away done, the hold skips to the end of the finals (%s)" % current_scene.name)
	# Only what the finals skip can act on: no kids' run can start now.
	var keys := _skip_keys("season")
	var finals_on: bool = _state.my_finals_status() != ""
	_check(keys == (["game_plan", "questions"] if finals_on else ["questions"]),
			"Past the home and away the survey drops the kids (%s, status %s)" % [keys, _state.my_finals_status()])
	var finals_top: Array = _state.season.finals.get("top", [])
	_state.season.finals["top"] = finals_top.filter(func(c): return c != _state.my_club)
	_check(_skip_keys("season") == ["questions"], "Out of the finals, it asks only about the week's cards")
	_state.season.finals["top"] = finals_top

	# A reload keeps it, and the finals are still there to play.
	_check(_state.save_career(), "The skipped home and away saves")
	_check(_state.load_career(), "It loads")
	_check(_skip_shape() == skipped, "A reload keeps it")
	var res: Dictionary = _state.skip_season({}, "home_away")
	_check(not bool(res["ok"]) and str(res["reason"]) == "none" and int(res["weeks"]) == 0, "Skipping the home and away again does nothing (%s)" % [res])
	res = _state.skip_season({}, "season")
	_check(bool(res["ok"]) and _state.season.is_season_over() and _state.season_year == year, "The finals then skip to the end of the season (%s)" % [res])
	_state.week_events = []
	_state.set_confirm_sim_round(ask_before)
	root.size = size_before


func _skip_keys(to: String) -> Array:
	var out := []
	for q in _state.skip_questions(to):
		out.append(str(q["key"]))
	return out


## A skip to the end of the home and away starts no run it cannot finish, and
## does not ask about the kids when none can start (director's finals stay his).
func _test_skip_home_away_kids() -> void:
	var backing = _rules("Backing")
	_skip_start(5512)
	_state.season.round_index = _state.season.fixture.size() - 2
	_check(_skip_keys("home_away") == ["game_plan", "questions"], "With two rounds left the kids' run is not offered (%s)" % [_skip_keys("home_away")])
	var res: Dictionary = _state.skip_season({"youth": "kids"}, "home_away")
	var on := 0
	for p in _state.my_list:
		if backing.is_active(p):
			on += 1
	_check(bool(res["ok"]) and on == 0, "Two rounds left: no promise is made (%d on, %s)" % [on, res])
	_skip_start(5512)
	_state.season.round_index = _state.season.fixture.size() - 6
	_check(_skip_keys("home_away").has("youth"), "With six rounds left it is")
	res = _state.skip_season({"youth": "kids"}, "home_away")
	var promised := 0
	on = 0
	for p in _state.my_list:
		promised += backing.ledger(p).size()
		# A run waits for a kid who is hurt or suspended (Backing.after_match), so
		# one can outlast the season through no fault of the skip.
		if backing.is_active(p) and backing.fit(p):
			on += 1
	_check(bool(res["ok"]) and promised >= 2, "Six rounds left: the kids get runs (%d)" % promised)
	_check(on == 0, "None of them who can play is still going when it stops (%d)" % on)
	_state.week_events = []
	_state.media_conference = {}


## The survey's answers reach the skip (row 70): the same seed skipped with
## two sets of answers ends in a different place for each answer.
func _skip_orders_run(orders: Dictionary) -> Dictionary:
	_state.reset()
	_state.career_seed = 7301
	_state.replay_seed = 7301
	_state.start_season("HAW", _db.club_list("HAW"))
	_state.week_events = []
	# One home-and-away round is enough for the kids' answer to promise runs;
	# the finals after it are played out as ever.
	_state.season.round_index = _state.season.fixture.size() - 1
	var year: int = _state.season_year
	var res: Dictionary = _state.skip_season(orders)
	var runs := 0
	for p in _state.my_list:
		for r in _rules("Backing").ledger(p):
			if int(r.get("year", 0)) == year:
				runs += 1
	# A strong season can end in a rival board's letter (row 112), which holds
	# the off-season until he answers, as it does after Sim the week.
	var held: bool = load("res://scripts/state/ClubMoves.gd").letter_open(_state)
	return {"ok": bool(res["ok"]), "runs": runs, "plan": _state.club_plan,
			"over": _state.season.is_season_over(), "off": _state.offseason_open() or held, "draft": _state.draft != null}


func _test_skip_orders() -> void:
	var a := _skip_orders_run({})
	var b := _skip_orders_run({"game_plan": "attacking", "youth": "kids", "questions": "players"})
	_check(a["ok"] and b["ok"] and a["over"] and b["over"] and a["off"] and b["off"] and not a["draft"] and not b["draft"],
			"Both skips play out the season and stop where the last Sim the week does, the draft not begun (%s / %s)" % [a, b])
	_check(a["plan"] == "balanced" and b["plan"] == "attacking", "The game plan answer is the plan the skip played (%s, %s)" % [a["plan"], b["plan"]])
	_check(int(a["runs"]) == 0 and int(b["runs"]) >= 2, "Give the kids a run promises runs; best side on form none (%d vs %d)" % [a["runs"], b["runs"]])
	# The week's questions: the answer the survey gave picks the card's option.
	var card := {"title": "t", "options": [
			{"label": "Promise a win", "effects": [{"op": "board", "d": 3}], "result": "a"},
			{"label": "Back the group", "effects": [{"op": "morale", "d": 5, "who": "all"}], "result": "b"}],
			"default": -1, "facts": {}}
	var picked := {}
	for pol in ["usual", "players", "board"]:
		_state.week_events = [card.duplicate(true)]
		_state._skip_orders = {"questions": pol}
		_state._settle_week_event()
		picked[pol] = int((_state.week_events[0] as Dictionary).get("choice", -2))
	_state._skip_orders = {}
	_state.week_events = []
	_check(picked == {"usual": -1, "players": 1, "board": 0},
			"Questions during the week: unanswered, the players' answer, the board's answer (%s)" % picked)


## New career opens the year step first (Legacy mode, row 142 L2): a real tap
## on today's league reaches the options these checks read. No step, no tap.
func _pick_year(id := "2026") -> String:
	var b := current_scene.find_child("StartYear_" + id, true, false) as Control
	if b == null:
		return ""
	var why: String = await Tap.tap(b)
	await _settle()
	return why


## The year step (Legacy mode, TODO row 142 L2; director 2026-11-13, "Year step
## in setup"), by real taps: New career asks the season first, today's league on
## top; 1990 leaves out what belongs to today's league (the start, a challenge,
## Canberra) and goes straight to Choose your club on the 14 clubs' real lists;
## Back walks the same way home.
func _test_year_step_taps() -> void:
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	var t1: String = await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	var menu := current_scene
	var y26 := menu.find_child("StartYear_2026", true, false) as Control
	var y90 := menu.find_child("StartYear_1990", true, false) as Control
	_check(t1 == "" and str(menu.get("_mode")) == "year" and y26 != null and y90 != null
			and y26.is_visible_in_tree() and y90.is_visible_in_tree() and y26.get_index() < y90.get_index()
			and y26.size.y >= 88.0 and y90.size.y >= 88.0,
			"New career asks the season first, today's league on top, each a thumb-sized tap (tap %s, mode %s)" % [t1, menu.get("_mode")])
	_router.handle_back(false)
	await _settle()
	_check(str(current_scene.get("_mode")) == "home", "Back from the year step is the title screen (%s)" % current_scene.get("_mode"))
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	var t2: String = await _pick_year("1990")
	menu = current_scene
	var said := menu.find_child("SetupYear", true, false) as Label
	var real_btn := menu.find_child("StartMode_real", true, false) as Button
	var start_row := menu.get("_start_row") as Control
	var challenge_row := menu.get("_challenge_row") as Control
	var canberra_row := menu.get("_canberra_row") as Control
	_check(t2 == "" and str(menu.get("_mode")) == "setup" and said != null and said.text == "Starting in 1990"
			and start_row != null and start_row.is_visible_in_tree() and str(menu.get("_pick_start")) == "real"
			and real_btn != null and real_btn.text == "Real 1990 lists"
			and challenge_row != null and not challenge_row.is_visible_in_tree()
			and canberra_row != null and not canberra_row.is_visible_in_tree(),
			"1990 is set up on its real lists by default, without today's challenge or Canberra (tap %s, %s)" % [t2, said.text if said != null else "no year line"])
	# A League redraft of 1990 by a real tap (director 2026-11-13), and back.
	var t_rd: String = await Tap.tap(menu.find_child("StartMode_redraft", true, false))
	await _settle()
	var start_note := menu.find_child("StartModeNote", true, false) as Label
	_check(t_rd == "" and str(menu.get("_pick_start")) == "redraft" and start_note != null
			and start_note.text.contains("before 1990") and start_note.text.contains("senior coach"),
			"A tap on League redraft re-drafts the 1990 clubs, and you still replace the senior coach (tap %s: %s)" % [
				t_rd, start_note.text if start_note != null else "no note"])
	await Tap.tap(menu.find_child("StartMode_real", true, false))
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(str(current_scene.get("_mode")) == "year", "Back from the setup is the year step (%s)" % current_scene.get("_mode"))
	await _pick_year("1990")
	var t3: String = await Tap.tap(current_scene.find_child("StartCareer", true, false))
	for i in range(900):
		if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	var tiles := [0]
	_count_named(current_scene, "Choose_", func(): tiles[0] += 1)
	_check(t3 == "" and _router.current() == "draft" and _state.dataset == "1990" and str(root.get_node("GameDB").dataset_id) == "1990"
			and _state.opening_draft and int(tiles[0]) == 14 and current_scene.find_child("Choose_MEL", true, false) != null,
			"Start career opens Choose your club on the 14 clubs of 1990 (tap %s, at %s, set %s, %d clubs)" % [
				t3, _router.current(), _state.dataset, int(tiles[0])])
	var t4: String = await Tap.tap(current_scene.find_child("Choose_MEL", true, false))
	for i in range(300):
		if _router.current() != "draft" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	_check(t4 == "" and _state.my_club == "MEL" and _router.current() == "interview",
			"Melbourne by a tap: you face the press first (tap %s, at %s)" % [t4, _router.current()])
	# Seven answers and Continue start the 1990 season; the coaching world is
	# seeded then, with John Northey out of Melbourne's top job and free.
	var name_field := current_scene.find_child("CoachName", true, false) as LineEdit
	name_field.text = "Pat Reid"
	name_field.text_changed.emit(name_field.text)
	await Tap.tap(current_scene.find_child("InterviewStart", true, false))
	await _settle()
	var answered := ""
	for i in range(12):
		if current_scene.find_child("InterviewDone", true, false) != null:
			break
		answered += await Tap.tap(current_scene.find_child("InterviewAnswer0", true, false))
		await _settle()
	var t5: String = await Tap.tap(current_scene.find_child("InterviewDone", true, false))
	for i in range(600):
		if _router.current() != "interview" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	var northey := ""
	for cid in _state.coaches:
		if str(_state.coaches[cid].get("real_name", "")) == "John Northey":
			northey = str(_state.coaches[cid].get("status", ""))
	_check(answered == "" and t5 == "" and _router.current() in ["hub", "preseason"] and _state.season_year == 1990
			and northey == "free",
			"Continue starts Melbourne's 1990 season with John Northey a free coach (tap %s, at %s, %s)" % [
				t5, _router.current(), northey])
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []


## The new clubs' starts on the year step (TODO row 142; director 2026-11-11:
## "2028 (tassie), 2030 (canberra)"), by real taps on a phone: each is its own
## card after today's league; 2028 is the Tasmania start (2027 without you,
## then Tasmania are yours), 2030 Canberra's (2027 to 2029 without you, then
## any of the 20 clubs). Each warns before anything plays, Back on the warning
## keeps the start, and seven starts still fit a phone by scrolling.
func _test_year_step_new_clubs() -> void:
	var seed_was: int = _state.replay_seed
	var size_was := root.size
	root.size = Vector2i(390, 844)
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	var cards := {}
	for id in ["2026", "2028", "2030", "1990"]:
		cards[id] = current_scene.find_child("StartYear_" + id, true, false) as Control
	var shown := true
	for id in cards:
		shown = shown and cards[id] != null and (cards[id] as Control).is_visible_in_tree() and (cards[id] as Control).size.y >= 88.0
	_check(shown and cards["2026"].get_index() < cards["2028"].get_index()
			and cards["2028"].get_index() < cards["2030"].get_index() and cards["2030"].get_index() < cards["1990"].get_index()
			and _all_text(cards["2028"]).contains("Tasmania join") and _all_text(cards["2030"]).contains("Canberra join"),
			"The year step offers 2028 (Tasmania) and 2030 (Canberra) after today's league, each a thumb-sized card")
	# 2028 by a real tap: Tasmania's start, set up on the real 2026 lists.
	var t1: String = await _pick_year("2028")
	var menu := current_scene
	var said := menu.find_child("SetupYear", true, false) as Label
	var note := menu.find_child("SetupYearNote", true, false) as Label
	var go := menu.find_child("StartCareer", true, false) as Button
	_check(t1 == "" and str(menu.get("_mode")) == "setup" and said != null and said.text == "Starting in 2028"
			and note != null and note.is_visible_in_tree() and note.text.contains("2027 plays out without you")
			and note.text.contains("Tasmania") and go != null and go.text == "Take Tasmania"
			and not (menu.get("_start_row") as Control).is_visible_in_tree()
			and not (menu.get("_challenge_row") as Control).is_visible_in_tree()
			and not (menu.get("_canberra_row") as Control).is_visible_in_tree()
			and str(menu.get("_pick_start")) == "real" and not bool(menu.get("_pick_canberra")),
			"2028 is the Tasmania start on the real lists, said in one line (tap %s: %s / %s)" % [
				t1, said.text if said != null else "no year", note.text if note != null else "no note"])
	var t2: String = await Tap.tap(go)
	await _settle()
	var sheet := menu.find_child("SimAheadWarning", true, false)
	var words := _all_text(sheet) if sheet != null else ""
	_check(t2 == "" and words.contains("Your first season is 2028") and words.contains("2027 plays out without you")
			and words.contains("2027 National Draft"),
			"Take Tasmania warns first that 2027 plays out without you (%s): %s" % [t2, words])
	var t3: String = await Tap.tap(menu.find_child("SimAheadBack", true, false))
	await _settle()
	_check(t3 == "" and menu.find_child("SimAheadWarning", true, false) == null and _state.season == null
			and int(menu.get("_pick_future")) == 2028 and str(menu.get("_mode")) == "setup",
			"Back on the warning keeps the 2028 start and plays nothing (%s)" % t3)
	# Back to the year step; 2030 by a real tap.
	_router.handle_back(false)
	await _settle()
	var t4: String = await _pick_year("2030")
	menu = current_scene
	said = menu.find_child("SetupYear", true, false) as Label
	note = menu.find_child("SetupYearNote", true, false) as Label
	go = menu.find_child("StartCareer", true, false) as Button
	_check(t4 == "" and said != null and said.text == "Starting in 2030" and note != null
			and note.text.contains("2027 to 2029 play out without you") and note.text.contains("Canberra included")
			and go != null and go.text == "Choose your club" and bool(menu.get("_pick_canberra")),
			"2030 is Canberra's start: three seasons without you, then any club (tap %s: %s)" % [
				t4, note.text if note != null else "no note"])
	# Today's league again: Canberra is asked afresh, not carried over.
	_router.handle_back(false)
	await _settle()
	await _pick_year("2026")
	_check(not bool(current_scene.get("_pick_canberra")) and int(current_scene.get("_pick_future")) == 0
			and (current_scene.get("_canberra_row") as Control).is_visible_in_tree()
			and current_scene.find_child("SetupYearNote", true, false) == null,
			"Today's league after 2030 starts with Canberra unpicked and its question back")
	# 2030 for real: warned, confirmed, and the shipped history opens Choose
	# your club at the 2029 National Draft with all 20 clubs.
	_state.replay_seed = 0
	_router.handle_back(false)
	await _settle()
	await _pick_year("2030")
	await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	var t5: String = await Tap.tap(current_scene.find_child("SimAheadConfirm", true, false))
	for i in range(900):
		if _router.current() == "draft" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	var tiles := [0]
	_count_named(current_scene, "Choose_", func(): tiles[0] += 1)
	_check(t5 == "" and _router.current() == "draft" and _state.choosing_club() and _state.season_year == 2029
			and int(tiles[0]) == 20 and current_scene.find_child("Choose_CANB", true, false) != null,
			"Start in 2030 plays to the 2029 National Draft and offers all 20 clubs (tap %s, at %s, %d, %d clubs)" % [
				t5, _router.current(), _state.season_year, int(tiles[0])])
	var t6: String = await Tap.tap(current_scene.find_child("Choose_CANB", true, false))
	await _settle()
	_check(t6 == "" and _state.my_club == "CANB" and not _state.sim_ahead,
			"Canberra by a real tap: the 2030 career is yours (tap %s, %s)" % [t6, _state.my_club])
	# 2028 for real: Take Tasmania, confirmed; Tasmania are yours at the 2027 draft.
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	await _pick_year("2028")
	await Tap.tap(current_scene.find_child("StartCareer", true, false))
	await _settle()
	var t7: String = await Tap.tap(current_scene.find_child("SimAheadConfirm", true, false))
	for i in range(900):
		if _router.current() != "main" and not bool(root.get_node("ScreenTransition").busy):
			break
		await process_frame
	await _settle()
	_check(t7 == "" and _state.my_club == "TAS" and _state.season_year == 2027 and _state.club_yet_to_play()
			and _router.current() in ["draft", "interview"],
			"Start in 2028 plays 2027 without you and hands you Tasmania at the 2027 draft (tap %s, %s, %d, at %s)" % [
				t7, _state.my_club, _state.season_year, _router.current()])
	# Seven starts (2000, 2010 and 2020 added as stand-ins) on a phone: the
	# starts scroll, and the last is reached and started by a real tap.
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []
	var stand_ins := ["2000", "2010", "2020"]
	for id in stand_ins:
		if not Datasets.ready(id):
			var row: Dictionary = Datasets.get_set(Datasets.DEFAULT).duplicate()
			row["data_season"] = int(id) - 1
			row["start_year"] = int(id)
			Datasets.add(id, row)
	_router.go("main")
	await _settle()
	await Tap.tap(current_scene.find_child("NewCareer", true, false))
	await _settle()
	var sc := current_scene.find_child("StartsScroll", true, false) as ScrollContainer
	var last := current_scene.find_child("StartYear_1990", true, false) as Control
	var fits := sc != null and sc.get_global_rect().end.y <= float(root.size.y)
	if sc != null and last != null:
		sc.ensure_control_visible(last)
		await _settle()
	var t8: String = await _pick_year("1990")
	_check(fits and t8 == "" and str(current_scene.get("_mode")) == "setup" and str(current_scene.get("_pick_dataset")) == "1990",
			"Seven starts on a 390 x 844 phone scroll on screen, and 1990 at the bottom takes a real tap (scroll %s, fits %s, tap %s)" % [
				sc != null, fits, t8])
	for id in stand_ins:
		Datasets.remove(id)
	_state.replay_seed = seed_was
	root.size = size_was
	_state.delete_saved_career()
	_state.reset()
	_router.stack = []


func _count_named(n: Node, prefix: String, hit: Callable) -> void:
	if n is Control and str(n.name).begins_with(prefix) and (n as Control).is_visible_in_tree():
		hit.call()
	for c in n.get_children():
		_count_named(c, prefix, hit)


## Essendon's 2016 top-ups, when you coach them (director, 2026-11-13: "You
## pick them"): the sheet opens over the hub, a real tap on Sign signs the
## player and the sheet comes back for the next spot; Back leaves the spot
## open; Done leaves the rest empty.
func _test_top_up_sheet_taps() -> void:
	var ye = load("res://scripts/sim/YearEvents.gd")
	var md = load("res://scripts/state/MidseasonDraft.gd")
	_state.reset()
	_state.career_seed = 4402
	_state.replay_seed = 4402
	_state.start_season("ESS", _db.club_list("ESS"))
	var size_before := root.size
	root.size = Vector2i(390, 844)
	_router.stack = ["main"]
	_state.week_events = []
	# A fresh career has nobody unsigned yet: pass over a few of this year's class.
	for p in (_state.draftee_pool as Array).slice(0, 4):
		p["draft_year"] = _state.season_year - 1
	ye.state(_state)["top_up"] = {"year": _state.season_year, "club": "ESS", "left": 2, "most": 2, "signed": []}
	var pool: Array = md.pool(_state)
	_check(not pool.is_empty(), "Someone is left to sign (%d)" % pool.size())
	if pool.is_empty():
		root.size = size_before
		return
	var list_before: int = (_state.my_list as Array).size()
	_router.go("hub")
	await _settle()
	var sheet: Control = current_scene.find_child("TopUpSheet", true, false)
	var count: Label = sheet.find_child("TopUpCount", true, false) if sheet != null else null
	_check(count != null and count.text == "Signed 0 of 2", "The top-up sheet opens over the hub (%s)" % (count.text if count != null else "none"))
	var pid := str(pool[0]["id"])
	var sign: Button = sheet.find_child("TopUpSign_" + pid, true, false) if sheet != null else null
	var why: String = (await Tap.tap(sign)) if sign != null else "missing"
	await _settle()
	var signed := (_state.my_list as Array).filter(func(q): return str(q["id"]) == pid)
	_check(why == "" and signed.size() == 1 and int(signed[0].get("top_up", 0)) == _state.season_year,
			"A real tap on Sign signs the best player left (%s)" % why)
	var again: Control = current_scene.find_child("TopUpSheet", true, false)
	var count2: Label = again.find_child("TopUpCount", true, false) if again != null else null
	_check(count2 != null and count2.text == "Signed 1 of 2" and again.find_child("TopUpSign_" + pid, true, false) == null,
			"The sheet comes back for the second spot, without him")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("TopUpSheet", true, false) == null
			and int(ye.top_up_pending(_state).get("left", 0)) == 1, "Back closes the sheet; the spot stays open")
	_router.go("hub")
	await _settle()
	var last: Control = current_scene.find_child("TopUpSheet", true, false)
	var done: Button = last.find_child("TopUpDone", true, false) if last != null else null
	var done_tap: String = (await Tap.tap(done)) if done != null else "missing"
	await _settle()
	_check(done_tap == "" and ye.top_up_pending(_state).is_empty()
			and current_scene.find_child("TopUpSheet", true, false) == null
			and (_state.my_list as Array).size() == list_before + 1,
			"A real tap on Done leaves the last spot empty (%s)" % done_tap)
	root.size = size_before
