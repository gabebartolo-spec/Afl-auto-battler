extends RefCounted
## This week's opponent facts (Matchup): at most three, deterministic, drawn
## from the sides the engine fields, in football words with no internal
## numbers - and quiet when there is nothing worth saying.
## Run through tests/run_matchup_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_every_club()
	_test_deterministic()
	_test_line_extremes()
	_test_missing_player()
	_test_danger()
	_test_form()
	_test_unusual_data()
	_test_own_notes()
	_test_copy_helpers()
	print("Matchup tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _league() -> Dictionary:
	var lists := {}
	for code in GameDB.active_clubs(2026):
		lists[code] = GameDB.club_list(code).duplicate(true)
	return lists


## Player-facing copy must not leak the calculation.
func _clean(text: String) -> bool:
	var rx := RegEx.new()
	rx.compile("%|\\d+\\.\\d|rating|coefficient|\\+\\d|-\\d|OVR")
	return text != "" and rx.search(text) == null


func _test_every_club() -> void:
	var lists := _league()
	var total := 0
	var all_ok := true
	var clean := true
	for code in lists:
		var f := Matchup.facts(code, lists)
		total += f.size()
		if f.size() > Matchup.MAX_FACTS:
			all_ok = false
		for x in f:
			if not _clean(str(x["text"])):
				clean = false
				push_error("Leaky fact for %s: %s" % [code, x["text"]])
	_check(all_ok, "No club gets more than %d facts" % Matchup.MAX_FACTS)
	_check(clean, "Facts are football words: no percentages, decimals or ratings")
	_check(total > 0, "The league produces some facts (%d)" % total)


func _test_deterministic() -> void:
	var lists := _league()
	var a := Matchup.facts("CAR", lists)
	var b := Matchup.facts("CAR", lists)
	_check(a == b, "The same state gives the same facts")
	# Same clubs, inserted in the opposite order.
	var rev := {}
	var keys := lists.keys()
	keys.reverse()
	for k in keys:
		rev[k] = lists[k]
	_check(Matchup.facts("CAR", rev) == a, "The order clubs are stored in does not matter")


func _test_line_extremes() -> void:
	var lists := _league()
	var squads := {}
	for code in lists:
		squads[code] = Squad.new(code, lists[code], false, code)
	var best := ""
	var worst := ""
	for code in squads:
		var v: float = Matchup.line_values(squads[code])["midfield"]
		if best == "" or v > Matchup.line_values(squads[best])["midfield"]:
			best = code
		if worst == "" or v < Matchup.line_values(squads[worst])["midfield"]:
			worst = code
	var fb := Matchup._line_facts(best, squads)
	var fw := Matchup._line_facts(worst, squads)
	var has_best := false
	for x in fb:
		if x["key"] == "midfield" and str(x["text"]).begins_with("The best midfield"):
			has_best = true
	var has_worst := false
	for x in fw:
		if x["key"] == "midfield" and str(x["text"]).begins_with("The weakest midfield"):
			has_worst = true
	_check(has_best, "The league's best engine midfield is called the best (%s)" % best)
	_check(has_worst, "The league's weakest engine midfield is called the weakest (%s)" % worst)
	# A middling club says nothing about its midfield.
	var ranked := squads.keys()
	ranked.sort_custom(func(a, b): return Matchup.line_values(squads[a])["midfield"] > Matchup.line_values(squads[b])["midfield"])
	var mid_club: String = ranked[ranked.size() / 2]
	var quiet := true
	for x in Matchup._line_facts(mid_club, squads):
		if x["key"] == "midfield":
			quiet = false
	_check(quiet, "A mid-table midfield is not worth a line")


func _test_missing_player() -> void:
	var lists := _league()
	var list: Array = lists["GEE"]
	var best: Dictionary = list[0]
	for p in list:
		if int(p["overall"]) > int(best["overall"]):
			best = p
	best["injury_weeks"] = 3
	var f := Matchup.facts("GEE", lists)
	var found := false
	var danger_is_him := false
	for x in f:
		if x["key"] == "missing" and str(x.get("player_id", "")) == str(best["id"]):
			found = true
		if x["key"] == "danger" and str(x.get("player_id", "")) == str(best["id"]):
			danger_is_him = true
	_check(found, "Their best player injured: the facts say they are without him")
	_check(not danger_is_him, "An injured player is never 'the danger'")
	# A fringe player's injury is not news.
	var lists2 := _league()
	var list2: Array = lists2["GEE"]
	var by_ovr := list2.duplicate()
	by_ovr.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	by_ovr[0]["injury_weeks"] = 4
	var fringe := false
	for x in Matchup.facts("GEE", lists2):
		if x["key"] == "missing":
			fringe = true
	_check(not fringe, "A fringe player's injury is not a fact")


func _test_danger() -> void:
	var lists := _league()
	var top := {}
	var top_club := ""
	for code in lists:
		for p in lists[code]:
			if top.is_empty() or int(p["overall"]) > int(top["overall"]):
				top = p
				top_club = code
	var found := false
	for x in Matchup.facts(top_club, lists):
		if x["key"] == "danger" and str(x["text"]).contains("the best player in the competition"):
			found = true
	_check(found, "The league's best player is named as the danger (%s)" % top_club)


func _test_form() -> void:
	_check(Matchup._form(["L", "W", "W", "W"]).get("text", "") == "Won their last 3.", "Three straight wins is a fact")
	_check(Matchup._form(["W", "L", "L", "L", "L"]).get("text", "") == "Lost their last 4.", "Four straight losses is a fact")
	_check(Matchup._form(["W", "W", "L"]).is_empty(), "A short run is not")
	_check(Matchup._form(["W", "W", "D"]).is_empty(), "A draw breaks a run")
	_check(Matchup._form([]).is_empty(), "No games, no form fact")


func _test_unusual_data() -> void:
	var lists := _league()
	_check(Matchup.facts("ZZZ", lists).is_empty(), "An unknown club has no facts")
	lists["EMPTY"] = []
	_check(Matchup.facts("EMPTY", lists).is_empty(), "An empty list has no facts")
	var f_with_empty := Matchup.facts("CAR", lists)
	_check(f_with_empty.size() <= Matchup.MAX_FACTS, "An empty list elsewhere does not break the others")
	# A tiny league cannot rank lines, but still works.
	var tiny := {"CAR": lists["CAR"], "COL": lists["COL"], "GEE": lists["GEE"]}
	var ft := Matchup.facts("CAR", tiny)
	var line_fact := false
	for x in ft:
		if ["midfield", "ruck", "attack", "defence"].has(str(x["key"])):
			line_fact = true
	_check(not line_fact, "Three clubs are too few to call a line strong or weak")
	# Everyone injured: nobody to field, no crash.
	var hurt := _league()
	for p in hurt["RIC"]:
		p["injury_weeks"] = 2
	var fh := Matchup.facts("RIC", hurt)
	_check(fh.size() <= Matchup.MAX_FACTS, "A club with its whole list injured still gives a short answer")


func _test_own_notes() -> void:
	var list: Array = GameDB.club_list("COL").duplicate(true)
	_check(Matchup.own_notes(list).is_empty(), "A fit list has nothing to report")
	var best: Dictionary = list[0]
	for p in list:
		if int(p["overall"]) > int(best["overall"]):
			best = p
	best["injury_weeks"] = 1
	var notes := Matchup.own_notes(list)
	_check(notes.size() == 1 and str(notes[0]["text"]).ends_with("is out injured (1 week)."),
			"Your best player injured is this week's news (%s)" % (notes[0]["text"] if notes.size() > 0 else "-"))
	for p in list:
		p["injury_weeks"] = 5
	_check(Matchup.own_notes(list).size() <= 2, "Own notes stay short")


func _test_copy_helpers() -> void:
	_check(GameState.ordinal(1) == "1st" and GameState.ordinal(2) == "2nd" and GameState.ordinal(3) == "3rd"
			and GameState.ordinal(11) == "11th" and GameState.ordinal(12) == "12th"
			and GameState.ordinal(13) == "13th" and GameState.ordinal(21) == "21st"
			and GameState.ordinal(22) == "22nd", "Ladder positions read 1st, 2nd, 11th, 21st")
	var line := GameState.form_line({"value": 0.42, "label": "Good", "last": "WWLWW"})
	_check(line == "Form: Good  ·  WWLWW", "The form line has no internal number (%s)" % line)
