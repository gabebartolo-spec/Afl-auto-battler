extends RefCounted
## Matchday words: the feed keeps what a supporter talks about, in football
## language; a result word ("def", "defeated") only ever describes a final
## result; the breaks say what happened, never what to do.
## Run through tests/run_matchday_tests.gd.

var failures: Array[String] = []
var checks := 0

## Words that would make a line advice, not a fact.
const ADVICE := ["should", "try ", "switch", "recommend", "consider", "you need to", "lean ",
		"keep the", "protect", "tag him", "run play"]
## Engine words that must never reach the player.
const ENGINE := ["fp", "chain", "ballup", "ball-up", "inside50", "_", "|", "sim", "def "]


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	var res := _match(11)
	_test_feed(res)
	_test_lead_and_breaks()
	_test_quarter_facts(res)
	_test_half_time_keys()
	_test_legs_words()
	print("Matchday tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _match(seed: int, a := "COL", b := "CAR") -> Dictionary:
	var sim := MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)
	return sim.run()


func _lines(res: Dictionary) -> Array:
	var out := []
	for ev in res["events"]:
		var l := MatchNotes.feed_line(ev, str(res["home"]), str(res["away"]))
		if not l.is_empty():
			out.append(l)
	return out


func _test_feed(res: Dictionary) -> void:
	var lines := _lines(res)
	var goals := int(res["goals"][0]) + int(res["goals"][1])
	var behinds := int(res["behinds"][0]) + int(res["behinds"][1])
	_check(lines.size() <= goals + behinds + 12,
			"The feed is goals, behinds and the breaks, not play-by-play (%d lines, %d scores)" % [
			lines.size(), goals + behinds])
	var shown_goals := 0
	var leak := ""
	for l in lines:
		var t := str(l["text"])
		if str(l["tier"]) == "goal":
			shown_goals += 1
		var low := t.to_lower()
		for w in ENGINE:
			if low.contains(w):
				leak = t
		if (low.contains("def ") or low.contains("defeated")) and not t.begins_with("Full time"):
			leak = t
	_check(shown_goals == goals, "Every goal reaches the feed (%d of %d)" % [shown_goals, goals])
	_check(leak == "", "No engine words or live result words in the feed (%s)" % leak)
	var quarter_lines := []
	var final_line := ""
	for l in lines:
		if str(l["tier"]) == "break":
			if str(l["text"]).begins_with("Full time"):
				final_line = str(l["text"])
			else:
				quarter_lines.append(str(l["text"]))
	_check(quarter_lines.size() == 3 and str(quarter_lines[0]).begins_with("Quarter time: ")
			and str(quarter_lines[1]).begins_with("Half time: ")
			and str(quarter_lines[2]).begins_with("Three-quarter time: "),
			"The breaks read like a scoreboard call (%s)" % str(quarter_lines))
	var s: Array = res["score"]
	var want := "Full time: a draw" if int(s[0]) == int(s[1]) else "Full time: %s win by %d" % [
			GameDB.club_name(str(res["home"] if int(s[0]) > int(s[1]) else res["away"])), absi(int(s[0]) - int(s[1]))]
	_check(final_line == want, "Full time names the winner and the margin (%s)" % final_line)
	# Quiet kinds stay on the oval.
	for kind in ["kick", "handball", "mark", "tackle", "inside50", "rebound", "clanger", "free", "ballup", "sub"]:
		if not MatchNotes.feed_line({"kind": kind, "side": 0, "name": "X"}, "COL", "CAR").is_empty():
			_check(false, "A %s stays off the feed" % kind)
	_check(MatchNotes.feed_line({"kind": "behind", "side": 1, "name": "Sam Walsh",
			"score": [7, 13]}, "COL", "CAR")["text"] == "Behind: Sam Walsh (%s)" % GameDB.club_short("CAR"),
			"A behind names the kicker and his club")
	_check(str(MatchNotes.feed_line({"kind": "moment", "text": "Coach's call: Throw numbers at it - Throw numbers at it for the next few minutes."},
			"COL", "CAR")["text"]) == "Coach's call: Throw numbers at it for the next few minutes.",
			"A call is said once")
	_check(MatchNotes.moment_line({"title": "Set shot", "choice_label": "Take the shot", "outcome": "GOAL to X!"})
			== "Set shot: Take the shot. GOAL to X!", "A call and how it came off")
	_check(MatchNotes.run_line("CAR", 3) == "%s have kicked three in a row." % GameDB.club_name("CAR"),
			"A run of goals reads in words")


func _test_lead_and_breaks() -> void:
	var nm := func(c): return str(c)
	_check(MatchNotes.lead_text("COL", "CAR", [20, 13], nm) == "COL by 7", "The leader and the margin")
	_check(MatchNotes.lead_text("COL", "CAR", [13, 20], nm) == "CAR by 7", "Either side can lead")
	_check(MatchNotes.lead_text("COL", "CAR", [9, 9], nm) == "Scores level", "Level is level")
	var b := MatchNotes.break_score("COL", "CAR", [2, 4], [1, 2])
	_check(b == "%s 4.2 (26) lead %s 2.1 (13) by 13." % [GameDB.club_name("CAR"), GameDB.club_name("COL")],
			"A break states the score and the lead (%s)" % b)
	_check(not b.to_lower().contains("def"), "A break never says defeated")
	_check(MatchNotes.break_score("COL", "CAR", [2, 2], [1, 1]).ends_with("scores level."), "A level break")
	var qt := MatchNotes.feed_line({"kind": "quarter", "q": 2, "text": "End of quarter 2 - ...",
			"score": [30, 30]}, "COL", "CAR")
	_check(str(qt["text"]) == "Half time: scores level", "A level half time (%s)" % str(qt["text"]))
	var et := MatchNotes.feed_line({"kind": "quarter", "q": 5, "text": "Scores level at full time - we are going to extra time!",
			"score": [60, 60]}, "COL", "CAR")
	_check(str(et["text"]) == "Scores level at full time: extra time", "Extra time is called plainly")


func _test_quarter_facts(res: Dictionary) -> void:
	var all := []
	for seed in [3, 5, 9, 14, 21]:
		var r := _match(seed, "SYD", "GEE")
		for q in range(1, 5):
			for side in [0, 1]:
				var f: Array = MatchNotes.quarter_facts(r, side, q)
				_check(f.size() <= MatchNotes.MAX_FACTS, "At most three facts a quarter")
				all.append_array(f)
	_check(all.size() > 5, "Quarters produce facts (%d)" % all.size())
	var bad := ""
	for t in all:
		var low := str(t).to_lower()
		for w in ADVICE:
			if low.contains(w):
				bad = str(t)
		for key in CoachReport.PLAN_NAMES:
			if str(t).contains(str(CoachReport.PLAN_NAMES[key])) and key != "balanced":
				bad = str(t)
		if low.contains("%") or low.contains("pts") or low.contains("expected"):
			bad = str(t)
	_check(bad == "", "Break facts state what happened, never what to do (%s)" % bad)
	_check(MatchNotes.quarter_facts(res, 0, 0).is_empty() and MatchNotes.quarter_facts({}, 0, 2).is_empty(),
			"No quarter played, no facts")


func _test_half_time_keys() -> void:
	var bad := ""
	var n := 0
	for seed in [2, 4, 8, 16, 32, 64]:
		var sim := MatchSim.new(Squad.new("HAW", GameDB.club_list("HAW"), true, "HAW"),
				Squad.new("BRL", GameDB.club_list("BRL"), false, "BRL"), seed)
		sim.run_quarter()
		var res := sim.run_quarter()
		res["home"] = "HAW"
		res["away"] = "BRL"
		for side in [0, 1]:
			var keys: Array = CoachReport.half_time_report(res, side).get("keys", [])
			n += keys.size()
			for k in keys:
				var low := str(k).to_lower()
				for w in ADVICE:
					if low.contains(w):
						bad = str(k)
				for key in CoachReport.PLAN_NAMES:
					if key != "balanced" and str(k).contains(str(CoachReport.PLAN_NAMES[key])):
						bad = str(k)
				for key in CoachReport.PEP_NAMES:
					if key != "steady" and str(k).contains(str(CoachReport.PEP_NAMES[key])):
						bad = str(k)
	_check(n > 0, "The assistant's report still says what stands out (%d lines)" % n)
	_check(bad == "", "The half-time report names problems, not calls (%s)" % bad)


func _test_legs_words() -> void:
	_check(MatchNotes.legs_word(90.0) == "fresh" and MatchNotes.legs_word(60.0) == "tiring"
			and MatchNotes.legs_word(40.0) == "running on empty", "Legs read in words")
	var rows := [{"name": "A", "on": true, "energy": 30.0}, {"name": "B", "on": false, "energy": 20.0},
			{"name": "C", "on": true, "energy": 45.0}, {"name": "D", "on": true, "energy": 80.0}]
	_check(MatchNotes.cooked(rows) == ["A", "C"], "Only the tired players on the ground are named, most tired first")
	_check(not CoachReport.plan_summary("attacking").contains("%") and not CoachReport.pep_summary("calm").contains("%"),
			"The break describes calls without percentages")
	_check(CoachReport.plan_summary("attacking").contains("Controlled tempo"),
			"A plan's summary still says what it beats")
