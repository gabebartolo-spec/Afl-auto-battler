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
	_t("_test_rules")
	_t("_test_practice_nudge")
	_t("_test_power_rankings")
	_t("_test_copy_grammar")
	_t("_test_blurb_matches_rank")
	_t("_test_move_lines_true")
	_t("_test_deck")
	_t("_test_flow")
	_t("_test_answers")
	_t("_test_reckoning")
	_t("_test_silence_and_sim")
	_t("_test_saves")
	await _t("_test_screen")
	PreSeason.reload()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Papers", self))


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _career(club := CLUB) -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season(club, GameDB.club_list(club))
	GameState.open_preseason()


## Press on until the papers are waiting (the pre-season match is simmed on
## the way, as pressing on does).
func _to_papers() -> bool:
	var guard := 0
	while GameState.preseason_active() and GameState.preseason_stop() != "papers" and guard < 12:
		guard += 1
		GameState.preseason_advance()
	return GameState.preseason_stop() == "papers"


## The career as it stands, kept in memory, and put back: a career at the papers
## is played to once and restored from here (a reload, not eight pre-season weeks
## and a practice match again).
func _snap() -> Dictionary:
	return GameState._save_state().duplicate(true)


func _restore(state: Dictionary) -> void:
	_check(GameState._restore_career(state.duplicate(true)) and GameState.preseason_stop() == "papers",
			"(setup) the career at the papers is put back")


## The suite's own career at the papers (CLUB, seeded), played there once and
## put back from memory for each test that starts from it.
var _papers_at: Dictionary = {}


func _at_papers() -> void:
	if _papers_at.is_empty():
		_career()
		_check(_to_papers(), "(setup) the career reaches the papers")
		_papers_at = _snap()
	else:
		_restore(_papers_at)


## Put the papers' story on a chosen kind, as if they had run it.
func _force(kind: String, pred := 13) -> void:
	var rec: Dictionary = GameState.papers_record()
	rec["kind"] = kind
	rec["pred"] = pred
	rec["claim"] = 0
	rec["answered"] = false
	rec["result"] = ""
	rec["pid"] = _breakout_kid() if kind == "breakout" else ""


## The kid the breakout story is set up on: the papers' own pick
## (GameState._papers_breakout: young, fit, few games, best potential), taken
## from those outside this week's side, so the card offers all three answers
## (promising a run is for a player not already picked). Chosen here, not left
## to which kids the seeded side happens to leave out.
func _breakout_kid() -> String:
	var side := {}
	var sel: Dictionary = GameState.current_side()
	for k in sel:
		for id in sel[k]:
			side[str(id)] = true
	var best := {}
	for p in GameState.my_list:
		if side.has(str(p["id"])) or float(p.get("age", 30.0)) > float(PreSeason.tune("papers_breakout_age")):
			continue
		if int(p.get("injury_weeks", 0)) > 0 or not Backing.can_back(p, GameState.games_played(p)):
			continue
		var pot := int(p.get("potential", p.get("overall", 0)))
		var best_pot := int(best.get("potential", best.get("overall", 0)))
		if best.is_empty() or pot > best_pot or (pot == best_pot and str(p["id"]) < str(best["id"])):
			best = p
	return str(best.get("id", ""))


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


## The papers' power rankings (director, 2026-11-12): every club gets its own
## blurb, no two alike, each naming a player on that club's list or its
## practice result, and a club the practice moved keeps the paper's line on it.
func _test_power_rankings() -> void:
	PreSeason.reload()
	_at_papers()
	_check(not GameState.papers_record().is_empty(), "The papers print")
	var order: Array = GameState.papers_record().get("order", [])
	var blurbs := GameState.papers_blurbs()
	var facts := GameState.papers_facts()
	var all := true
	var true_fact := true
	var sentences := {}
	var repeats := []
	var moved := true
	for code in order:
		var b := str(blurbs.get(code, ""))
		all = all and b != ""
		var named := false
		for p in GameState.season.lists[code]:
			if b.contains(GameDB.player_display_name(p)):
				named = true
				break
		var m := int((facts[code] as Dictionary).get("margin", 0))
		if m != 0 and b.contains("%d-point practice" % absi(m)):
			named = true
		true_fact = true_fact and named
		if not named:
			print("  no fact in: ", b)
		var mv := GameState.papers_move_line(str(code))
		moved = moved and (mv == "" or b.ends_with(mv + "."))
		# The same sentence frame twice: each sentence with the club's and its
		# players' names taken out (the paper's move lines are checked above).
		var body := b.trim_suffix(mv + ".") if mv != "" else b
		for sentence in body.split(". ", false):
			var frame := sentence.replace(GameDB.club_name(str(code)), "C")
			for p in GameState.season.lists[code]:
				frame = frame.replace(GameDB.player_display_name(p), "P")
			if sentences.has(frame):
				repeats.append(frame)
			sentences[frame] = true
		print("  ", code, ": ", b)
	_check(order.size() == 18 and all, "Every club on the papers' ladder has a blurb")
	_check(repeats.is_empty(), "No two blurbs share a sentence (%s)" % str(repeats))
	_check(true_fact, "Each blurb names a player on that club's list or its practice result")
	_check(moved, "A club the practice moved ends its blurb with the paper's line on the move")
	var text := str(blurbs.values()).to_lower()
	_check(not text.contains("overall") and not text.contains("rating") and not text.contains("potential"),
			"No engine words in the blurbs")
	# The rule reads facts, not the club.
	var f := {"name": "Ascot", "pos": 1, "clubs": 18, "star": "Sam Smith", "second": "Tom Brown",
			"line": {"word": "midfield", "rank": 1, "lead": "Sam Smith"}}
	var top := PowerRankings.blurb("AAA", f, {})
	_check(top.contains("Sam Smith") and top.contains("Ascot"), "A blurb names the club and its player (%s)" % top)
	var hurt := f.duplicate(true)
	hurt["pos"] = 9
	hurt["line"] = {"word": "midfield", "rank": 12, "lead": "Sam Smith"}
	hurt["hurt"] = {"name": "Jack Jones", "kind": "a hamstring injury"}
	_check(PowerRankings.blurb("AAA", hurt, {}).contains("Jack Jones"), "A club missing a good player says so")
	var rec := hurt.duplicate(true)
	rec.erase("hurt")
	rec["recruit"] = {"name": "Ned Kelly", "from": "Glenrowan"}
	var r := PowerRankings.blurb("AAA", rec, {})
	_check(r.contains("Ned Kelly") and r.contains("Glenrowan"), "A club's best recruit leads its blurb, with his old club (%s)" % r)
	var used := {}
	var texts := {}
	for k in range(12):
		texts[PowerRankings.blurb("C%d" % k, hurt, used)] = true
	_check(texts.size() == 12, "Twelve mid-table clubs with the same facts still read twelve ways (%d)" % texts.size())


## Wrong "a"/"an" before a number in `text` ("a 8-point", "an 12-point"), as a list.
func _bad_articles(text: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("(?i)\\b(an?) (\\d+)")
	for m in re.search_all(text):
		if m.get_string(1).to_lower() != CopyRules.article(int(m.get_string(2))):
			out.append(m.get_string(0))
	return out


## Possessives and a/an (the 2026-11-12 capture printed "Western Bulldogs's
## slide" and "A 8-point practice win"): one shared rule each, in CopyRules.
func _test_copy_grammar() -> void:
	PreSeason.reload()
	_check(CopyRules.possessive("Western Bulldogs") == "Western Bulldogs'" and CopyRules.possessive("Carlton") == "Carlton's"
			and CopyRules.possessive("St Kilda") == "St Kilda's" and CopyRules.possessive("Brisbane Lions") == "Brisbane Lions'",
			"A name ending in s takes an apostrophe alone; any other takes 's")
	var an := true
	for n in [8, 11, 18, 80, 81, 85, 89, 800, 888, 8000, 11000, 18500, 80000]:
		an = an and CopyRules.article(n) == "an"
	var a := true
	for n in [0, 1, 2, 7, 9, 10, 12, 13, 17, 19, 20, 42, 79, 90, 100, 108, 110, 111, 118, 180, 181, 1000, 1100, 1800, 110000]:
		a = a and CopyRules.article(n) == "a"
	_check(an, "an 8, an 11, an 18, an 80-something, an 800, an 11,000: the number as it is said")
	_check(a, "a 1 (a one-point), a 10, a 12, a 100, a 110, a 180, a 1,100: the number as it is said")
	_check(CopyRules.a_number(8) == "an 8" and CopyRules.a_number(-42) == "a 42", "The number comes with its article, a margin without its sign")
	# The paper's move line, at every margin and with a club ending in s beside it.
	var bad: Array = []
	var wrong_s: Array = []
	for m in range(1, 151):
		for sign in [1, -1]:
			for line in [PreSeason.practice_move_line(sign, sign * m, sign), PreSeason.practice_move_line(0, sign * m, sign, "Western Bulldogs", m),
					PreSeason.practice_move_line(0, sign * m, sign, "Western Bulldogs", -m), PreSeason.practice_move_line(0, sign * m, sign, "top")]:
				bad.append_array(_bad_articles(line))
				if line.contains("s's"):
					wrong_s.append(line)
	_check(PreSeason.practice_move_line(1, 30, 1) != "" and bad.is_empty(), "The move line's a/an follows the margin, 1 to 150 points (%s)" % str(bad.slice(0, 5)))
	_check(wrong_s.is_empty(), "No move line writes s's (%s)" % str(wrong_s.slice(0, 3)))
	_check(PreSeason.practice_move_line(1, 45, 2, "Western Bulldogs", -30).ends_with("; Western Bulldogs' loss still leaves them just ahead")
			and PreSeason.practice_move_line(1, 38, 1) == "Up a spot on the back of a 38-point practice win"
			and PreSeason.practice_move_line(-2, -80, -2) == "Down two after an 80-point practice hiding"
			and PreSeason.practice_move_line(2, 118, 2) == "Up two after a 118-point practice thumping",
			"Western Bulldogs' loss, an 80-point hiding, a 118-point thumping")
	# The power rankings' practice sentences, at every margin and through every frame.
	var f := {"name": "Ascot", "pos": 9, "clubs": 18, "star": "Sam Smith", "has_margin": true,
			"line": {"word": "midfield", "rank": 12, "lead": "Sam Smith"}}
	bad = []
	var said := {}
	for m in range(1, 121):
		for sign in [1, -1]:
			f["margin"] = sign * m
			var used := {}
			for k in range(4):
				var b := PowerRankings.blurb("C%d" % k, f, used)
				bad.append_array(_bad_articles(b))
				if b.contains("%d-point practice" % m):
					var key := "%d-point %s" % [m, "win" if sign > 0 else "loss"]
					said[key] = str(said.get(key, "")) + " / " + b
	_check(bad.is_empty(), "A blurb's a/an follows the practice margin, 1 to 120 points (%s)" % str(bad.slice(0, 5)))
	_check(str(said.get("8-point win", "")).contains("An 8-point practice win") and str(said.get("11-point loss", "")).contains("An 11-point practice loss")
			and str(said.get("18-point win", "")).contains("An 18-point practice win") and str(said.get("80-point loss", "")).contains("An 80-point practice loss")
			and str(said.get("42-point win", "")).contains("A 42-point practice win") and str(said.get("1-point loss", "")).contains("A 1-point practice loss"),
			"An 8-point, an 11-point, an 18-point and an 80-point result; a 42-point and a 1-point one (%s)" % str(said.get("8-point win", "")))

	# Last year's finish in a lead, at every place: no "a 8th-place finish".
	bad = []
	for last in range(1, 19):
		for pos in range(1, 19):
			var g := {"name": "Ascot", "pos": pos, "clubs": 18, "last": last, "star": "Sam Smith",
					"line": {"word": "midfield", "rank": 12, "lead": "Sam Smith"}}
			var used := {}
			for k in range(4):
				for hit in RegEx.create_from_string("(?i)\\b(an?) (\\d+)(st|nd|rd|th)").search_all(PowerRankings.blurb("C%d" % k, g, used)):
					if hit.get_string(1).to_lower() != CopyRules.article(int(hit.get_string(2))):
						bad.append(hit.get_string(0))
	_check(bad.is_empty(), "A lead's a/an follows last year's finish, 1st to 18th (%s)" % str(bad.slice(0, 5)))


## The blurb agrees with the ladder printed beside it (an independent read of
## 540 blurbs, 2026-11-12): only the club printed first is the side to beat, and
## a lead on last year's climb or slide never sits before a practice move the
## other way.
func _test_blurb_matches_rank() -> void:
	var first_words := ["side to beat", "Hard to look past", "head of most tipsters"]
	var wrong: Array = []
	var seconds := {}
	for k in range(40):
		for pos in range(1, 19):
			var f := {"name": "Ascot", "pos": pos, "clubs": 18, "star": "Sam Smith", "second": "Tom Brown",
					"line": {"word": "midfield", "rank": 1 + (pos + k) % 18, "lead": "Sam Smith"}}
			var b := PowerRankings.blurb("C%d" % k, f, {})
			var claims := false
			for w in first_words:
				claims = claims or b.contains(w)
			if claims != (pos == 1):
				wrong.append("%d: %s" % [pos, b])
			if pos == 2:
				seconds[b] = true
	_check(wrong.is_empty(), "Only the club printed 1st is called the side to beat (%s)" % str(wrong.slice(0, 3)))
	_check(seconds.size() >= 2, "The club printed 2nd has its own leads (%s)" % str(seconds.keys()))
	var one_ladder := PowerRankings.blurbs(["AAA", "BBB"], {
			"AAA": {"name": "Ascot", "pos": 1, "clubs": 18, "star": "Sam Smith"},
			"BBB": {"name": "Benalla", "pos": 2, "clubs": 18, "star": "Tom Brown"}})
	_check(str(one_ladder["BBB"]).contains("Benalla") and not str(one_ladder["BBB"]).contains("side to beat")
			and not str(one_ladder["BBB"]).contains("Hard to look past") and not str(one_ladder["BBB"]).contains("head of most"),
			"On one ladder the 2nd club reads as the challenger (%s)" % str(one_ladder["BBB"]))
	# Climb and slide leads against the practice move, every pair of places.
	var climb_words := ["pushing well higher", "big jump", "tipped to climb"]
	var slide_words := ["slide is coming", "Questions hang over", "A drop is tipped"]
	var clash: Array = []
	var kept := 0
	for last in range(1, 19):
		for pos in range(1, 19):
			for mv in ["", "Up two after a 56-point practice thumping", "Down two after a 46-point practice hiding",
					"Holds its place after a 30-point practice win"]:
				for k in range(3):
					var f := {"name": "Ascot", "pos": pos, "clubs": 18, "last": last, "star": "Sam Smith", "move": mv,
							"line": {"word": "midfield", "rank": 12, "lead": "Sam Smith"}}
					var b := PowerRankings.blurb("C%d" % k, f, {})
					var climbs := false
					for w in climb_words:
						climbs = climbs or b.contains(w)
					var slides := false
					for w in slide_words:
						slides = slides or b.contains(w)
					kept += 1 if (climbs or slides) else 0
					if (climbs and mv.begins_with("Down ")) or (slides and mv.begins_with("Up ")):
						clash.append(b)
					if (climbs and last - pos < 4) or (slides and pos - last < 4):
						clash.append("untrue: " + b)
	_check(clash.is_empty(), "No climb lead before a practice fall, no slide lead before a practice rise (%s)" % str(clash.slice(0, 3)))
	_check(kept >= 200, "...and climb and slide leads still print when the practice move agrees or is absent (%d)" % kept)
	# Whole ladders as the papers print them (60 ladders, 1,080 blurbs, the frames
	# shared across the 18 clubs): every club has a last-season finish and a
	# third of them a practice move.
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED
	var faults: Array = []
	var ord_re := RegEx.create_from_string("(?i)\\b(an?) (\\d+)")
	var read := 0
	for ladder in range(60):
		var codes: Array = []
		for i in range(18):
			codes.append("L%02d" % i)
		var lasts := _shuffled(codes, rng)
		var facts := {}
		for i in range(18):
			var mv := ""
			var roll := rng.randi_range(0, 5)
			var pts := rng.randi_range(1, 90)
			if roll == 0 and i > 0:
				mv = PreSeason.practice_move_line(rng.randi_range(1, 3), pts, 3)
			elif roll == 1 and i < 17:
				mv = PreSeason.practice_move_line(-rng.randi_range(1, 3), -pts, -3)
			facts[codes[i]] = {"name": "Club %d" % i, "pos": i + 1, "clubs": 18, "last": lasts.find(codes[i]) + 1,
					"star": "Sam Smith", "second": "Tom Brown", "move": mv,
					"line": {"word": "midfield", "rank": rng.randi_range(1, 18), "lead": "Jack Jones"}}
		var printed := PowerRankings.blurbs(codes, facts)
		for i in range(18):
			var b := str(printed[codes[i]])
			var mv := str(facts[codes[i]]["move"])
			read += 1
			for hit in ord_re.search_all(b):
				if hit.get_string(1).to_lower() != CopyRules.article(int(hit.get_string(2))):
					faults.append("a/an: " + b)
			for w in first_words:
				if b.contains(w) and i != 0:
					faults.append("%d called first: %s" % [i + 1, b])
			for w in climb_words:
				if b.contains(w) and mv.begins_with("Down "):
					faults.append("climb then down: " + b)
			for w in slide_words:
				if b.contains(w) and mv.begins_with("Up "):
					faults.append("slide then up: " + b)
	_check(read == 1080 and faults.is_empty(), "1,080 blurbs on whole ladders with last year's finishes: right a/an, one side to beat, no lead against its move line (%s)" % str(faults.slice(0, 3)))


## Every move line says something true (the 2026-11-12 capture printed "Holds
## its place after a 42-point practice hiding; North Melbourne's climb took that
## place"): over 240 seeded rounds of practice matches, a line's first words
## match the way the club moved, and a club that fell short of what it earned
## is told only which club is printed beside it and how that club went.
func _test_move_lines_true() -> void:
	PreSeason.reload()
	var clubs: Array = GameDB.CLUB_ORDER.slice(0, 18)
	var wrong: Array = []
	var held := 0
	var short := 0
	var lines := 0
	for sd in range(240):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + sd
		var listed := _shuffled(clubs, rng)
		# Nine practice matches: each club's margin is its opponent's, reversed.
		var pairs := _shuffled(clubs, rng)
		var margins := {}
		for k in range(0, pairs.size() - 1, 2):
			var m := rng.randi_range(0, 99)
			margins[pairs[k]] = m
			margins[pairs[k + 1]] = -m
		var order := PreSeason.practice_nudge(listed, margins)
		var moves := PreSeason.practice_moves(listed, order, margins)
		for code in moves:
			var mv: Dictionary = moves[code]
			var by := str(mv["by"])
			var by_name := by if by == "" or by == "top" or by == "bottom" else GameDB.club_name(by)
			var line := PreSeason.practice_move_line(int(mv["places"]), int(mv["margin"]), int(mv["earned"]), by_name, int(margins.get(by, 0)))
			lines += 1
			var places := int(mv["places"])
			var at := order.find(code)
			var stays := line.begins_with("Holds its place") or line.begins_with("Stays ")
			held += 1 if stays else 0
			var why := ""
			if line == "":
				why = "a club that earned a move has no line"
			elif stays != (places == 0) or line.begins_with("Up ") != (places > 0) or line.begins_with("Down ") != (places < 0):
				why = "the first words do not match a move of %d" % places
			elif line.contains("took that place") or line.contains("took its place") or line.contains("s's"):
				why = "holds and loses its place, or s's"
			elif not _bad_articles(line).is_empty():
				why = "a/an"
			elif (line.contains(" top ") and at != 0) or (line.contains(" last ") or line.contains(" bottom ")) and at != order.size() - 1:
				why = "top or bottom said of a club that is not there"
			elif line.contains("; "):
				short += 1
				var tail := line.get_slice("; ", 1)
				var ahead := tail.ends_with("just ahead")
				var beside := ""
				if ahead and at > 0:
					beside = str(order[at - 1])
				elif not ahead and at < order.size() - 1:
					beside = str(order[at + 1])
				var bm := int(margins.get(beside, 0))
				if not (ahead or tail.ends_with("just behind")) or beside == "" or beside != by:
					why = "the club named is not the one printed beside it"
				elif ahead != (int(mv["earned"]) > 0):
					why = "a winner is stopped by the club ahead, a loser by the club behind"
				elif not tail.begins_with(CopyRules.possessive(GameDB.club_name(beside)) + " ") and not tail.begins_with(GameDB.club_name(beside) + " sit "):
					why = "the ending does not open with the club beside it"
				elif (tail.contains(" win ") and bm <= 0) or (tail.contains(" loss ") and bm >= 0) or (tail.contains(" sit ") and bm != 0):
					why = "the club beside it did not have that result (%d)" % bm
			if why != "":
				wrong.append("seed %d %s: %s [%s]" % [9000 + sd, code, line, why])
	print("  move lines read: %d, held %d, short of the move earned %d" % [lines, held, short])
	_check(wrong.is_empty(), "Every move line is true of the ladder printed, over 240 seeded rounds (%d wrong: %s)" % [wrong.size(), str(wrong.slice(0, 4))])
	_check(lines >= 1500 and held >= 40 and short >= 40,
			"...and the rounds held clubs in place and stopped clubs short often enough to read those lines (%d lines, %d held, %d short)" % [lines, held, short])


func _shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var out := list.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The practice match nudges the paper's ladder (director, 2026-11-12, "Nudge
## it"): four goals moves a club a place, seven goals two; every club the same.
func _test_practice_nudge() -> void:
	PreSeason.reload()
	_check(PreSeason.practice_shift(24) == 1 and PreSeason.practice_shift(41) == 1 and PreSeason.practice_shift(42) == 2
			and PreSeason.practice_shift(23) == 0 and PreSeason.practice_shift(0) == 0
			and PreSeason.practice_shift(-24) == -1 and PreSeason.practice_shift(-60) == -2,
			"A win by four goals lifts a club one, by seven goals two; a loss the same down; closer or a draw, none")
	var base := ["A", "B", "C", "D", "E", "F", "G", "H"]
	var win := PreSeason.practice_nudge(base, {"E": 30, "F": -10})
	_check(win == ["A", "B", "C", "E", "D", "F", "G", "H"],
			"A comfortable win lifts the club one place and the club it passed drops one (%s)" % str(win))
	var heavy := PreSeason.practice_nudge(base, {"E": 45})
	_check(heavy == ["A", "B", "E", "C", "D", "F", "G", "H"], "A heavy win lifts the club two; the two it passed drop one each (%s)" % str(heavy))
	var loss := PreSeason.practice_nudge(base, {"C": -30, "D": 30})
	_check(loss == ["A", "B", "D", "C", "E", "F", "G", "H"],
			"A comfortable loss drops the club one; its opponent's win lifts that club one (%s)" % str(loss))
	var hiding := PreSeason.practice_nudge(base, {"B": -45})
	_check(hiding == ["A", "C", "D", "B", "E", "F", "G", "H"], "A heavy loss drops the club two (%s)" % str(hiding))
	_check(PreSeason.practice_nudge(base, {"C": 0, "D": 0}) == base, "A draw moves nobody")
	_check(PreSeason.practice_nudge(base, {}) == base, "A club with no practice match does not move")
	var ends := PreSeason.practice_nudge(base, {"A": 60, "B": 30, "H": -60, "G": -30})
	_check(ends == base, "First cannot go higher and last cannot go lower; the ladder stays whole (%s)" % str(ends))
	var crowd := PreSeason.practice_nudge(base, {"A": -50, "B": 50, "C": 30, "D": -30, "E": 45, "F": -45})
	var sorted := crowd.duplicate()
	sorted.sort()
	var fair := true
	for code in ["A", "B", "C", "D", "E", "F"]:
		var shift := PreSeason.practice_shift(int({"A": -50, "B": 50, "C": 30, "D": -30, "E": 45, "F": -45}[code]))
		var moved := base.find(code) - crowd.find(code)
		fair = fair and absi(moved) <= 2 and moved * shift >= 0
	_check(fair, "No club with a result moves further than it earned, no winner goes down and no loser goes up (%s)" % str(crowd))
	# Two heavy losers side by side both still drop (neither blocks the other).
	var pair := PreSeason.practice_nudge(base, {"C": -50, "D": -50})
	_check(pair == ["A", "B", "E", "F", "C", "D", "G", "H"], "Two heavy losers side by side both drop two (%s)" % str(pair))
	_check(sorted == base and crowd == PreSeason.practice_nudge(base, {"A": -50, "B": 50, "C": 30, "D": -30, "E": 45, "F": -45}),
			"However the results fall, every club is printed once and the same results print the same ladder (%s)" % str(crowd))
	# A loser ahead of a club that did not play does not hold back a heavy
	# winner below it: the winner still climbs both places it earned.
	var past := PreSeason.practice_nudge(["L", "N", "W"], {"L": -30, "W": 50})
	_check(past == ["W", "L", "N"], "A heavy winner climbs two past a loser and a club that did not move (%s)" % str(past))
	var tight := PreSeason.practice_nudge(base, {"D": 30, "E": 45})
	_check(tight == ["A", "B", "D", "E", "C", "F", "G", "H"],
			"Two winners after the same place: the higher-listed one gets it, the other comes up one behind it (%s)" % str(tight))
	_check(PreSeason.practice_move_line(1, 30, 1) == "Up a spot on the back of a 30-point practice win"
			and PreSeason.practice_move_line(-2, -45, -2) == "Down two after a 45-point practice hiding"
			and PreSeason.practice_move_line(-1, -30, -1) == "Down a spot after a 30-point practice loss"
			and PreSeason.practice_move_line(2, 56, 2) == "Up two after a 56-point practice thumping"
			and PreSeason.practice_move_line(0, 30, 0) == "" and PreSeason.practice_move_line(0, 0, 0) == "",
			"The paper says why a club moved, in points, the word following the margin; nothing for a club its result did not move")
	_check(PreSeason.practice_move_line(1, 56, 2, "Hawthorn", 30)
			== "Up a spot on the back of a 56-point practice thumping; Hawthorn's own win leaves them just ahead"
			and PreSeason.practice_move_line(1, 56, 2, "top") == "Up a spot to the top after a 56-point practice thumping"
			and PreSeason.practice_move_line(0, 30, 1, "top") == "Stays top after a 30-point practice win"
			and PreSeason.practice_move_line(-1, -45, -2, "bottom") == "Down a spot to the bottom after a 45-point practice hiding"
			and PreSeason.practice_move_line(-1, -50, -2, "Hawthorn", 30) == "Down a spot after a 50-point practice hiding; Hawthorn's win still leaves them just behind",
			"A club that moved less than it earned is told why: the top, the bottom, or the club printed beside it and that club's result")
	_check(PreSeason.practice_move_line(0, -42, -2, "North Melbourne", 43)
			== "Holds its place after a 42-point practice hiding; North Melbourne's win still leaves them just behind"
			and PreSeason.practice_move_line(0, -42, -2, "Carlton", -30)
			== "Holds its place after a 42-point practice hiding; Carlton's own loss leaves them just behind"
			and PreSeason.practice_move_line(0, -42, -2, "Carlton", 0) == "Holds its place after a 42-point practice hiding; Carlton sit just behind"
			and PreSeason.practice_move_line(0, 30, 1, "Carlton", -30) == "Holds its place after a 30-point practice win; Carlton's loss still leaves them just ahead"
			and PreSeason.practice_move_line(0, 30, 1, "Carlton", 0) == "Holds its place after a 30-point practice win; Carlton sit just ahead",
			"A club that held its place is never told its place was taken: the line names the club beside it and that club's own result")
	# In a career: every club's practice margin is kept, and the ladder printed is the nudged one.
	_career("MEL")
	_to_papers()
	var margins: Dictionary = GameState.preseason.get("practice_margins", {})
	var rec: Dictionary = GameState.papers_record()
	var played := margins.size()
	_check(played >= GameState.season.clubs.size() - 1 and margins.has("MEL"),
			"Every club that played a practice match has its margin kept, yours too (%d)" % played)
	var moves: Dictionary = rec.get("moves", {})
	print("  papers' ladder %s" % str(rec["order"]))
	print("  moves %s" % str(moves))
	var ok := true
	var full := true
	var named := 0
	for code in margins:
		var shift := PreSeason.practice_shift(int(margins[code]))
		if shift == 0:
			continue
		named += 1 if moves.has(code) else 0
		var m: Dictionary = moves.get(code, {"places": 0, "earned": 0, "by": ""})
		var places := int(m["places"])
		ok = ok and int(m["earned"]) == shift and places * shift >= 0 and absi(places) <= absi(shift)
		# Short of what it earned only when the ladder's end stopped it or
		# another club's own result took the place it was after.
		if absi(places) < absi(shift):
			var by := str(m["by"])
			full = full and (["top", "bottom"].has(by) or PreSeason.practice_shift(int(margins.get(by, 0))) != 0)
			print("  short: %s earned %d moved %d by %s" % [code, shift, places, by])
	_check(ok and (rec["order"] as Array).size() == GameState.season.clubs.size()
			and int(rec["pred"]) == (rec["order"] as Array).find("MEL") + 1,
			"The printed ladder is whole, each named move is the way its result points and no further, and your place is read from it")
	_check(full and named > 0, "Every club the practice match earned a move gets all of it unless the ladder's end or another club's result stops it (%d named)" % named)


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
			"Pressing on stops at the papers in week 8, after the pre-season match")
	var rec: Dictionary = GameState.papers_record()
	_check((rec["order"] as Array).size() == GameState.season.clubs.size() and (rec["order"] as Array).has(CLUB)
			and int(rec["pred"]) == (rec["order"] as Array).find(CLUB) + 1,
			"The paper prints every club once, and yours at the place it says")
	_check(["finish", "breakout", "pressure", ""].has(str(rec["kind"])), "One story, of the three kinds, or none")
	var order1: Array = (rec["order"] as Array).duplicate()
	var kind1 := str(rec["kind"])
	var at_papers := _snap()
	_career()
	_to_papers()
	_check(GameState.papers_record()["order"] == order1 and str(GameState.papers_record()["kind"]) == kind1,
			"The same career prints the same ladder and runs the same story")
	var goal_before := (GameState.board["goal"] as Dictionary).duplicate()
	GameState.preseason_advance()
	_check(not GameState.preseason_active() and GameState.board["goal"] == goal_before,
			"Pressing on without an answer goes to Round 1, and the board's goal is as it was")
	# The papers never touch the match: the same pre-season, with and without
	# the papers' answer, plays the same first round (this career, unanswered,
	# against the first one put back at the papers and answered).
	GameState.advance()
	var sig_a := str(GameState.season_log.back()["score"])
	_restore(at_papers)
	_force("finish")
	GameState.papers_answer(2)
	GameState.preseason_advance()
	GameState.advance()
	_check(str(GameState.season_log.back()["score"]) == sig_a,
			"What you tell the papers does not change the first match's result")


## A stake with its size: a percentage, or his opinion of you in points out of
## 100 ("down 1, to 49/100", director 2026-11-08).
func _sized(line: String) -> bool:
	return line.contains("%") or line.contains("/100")


func _lines(card: Dictionary, i: int) -> PackedStringArray:
	return StoryEngine.stakes_lines((card["options"][i] as Dictionary).get("effects", []), card["facts"])


func _test_answers() -> void:
	# Reading a story's card answers nothing: one career at the papers reads all three.
	_at_papers()
	var at_papers := _papers_at
	for kind in ["finish", "pressure", "breakout"]:
		_force(kind)
		var card := GameState.papers_card()
		# A tipped player already in the side is not promised a run (the third
		# answer asks "selected": false): which side the seeded career picks can
		# differ between platforms, so the count follows the rule.
		var want := 3
		if kind == "breakout" and GameState.in_current_side(GameState.list_player(str(GameState.papers_record()["pid"]))):
			want = 2
		var n := (card.get("options", []) as Array).size()
		_check(not card.is_empty() and n == want, "%s: the story has %d answers (got %d)" % [kind, want, n])
		var every := true
		var sized := true
		for i in range(n):
			var lines := _lines(card, i)
			var gain := false
			var cost := false
			for l in lines:
				gain = gain or l.begins_with("Gain: ")
				cost = cost or l.begins_with("Cost: ")
				sized = sized and _sized(l)
			every = every and gain and cost
		_check(every, "%s: every answer says what it gains and what it costs" % kind)
		# Bible section 4 (director, 2026-10-18): every side carries its size, saying nothing too.
		var quiet := StoryEngine.silence_line(card)
		_check(sized and quiet.begins_with("Say nothing") and _sized(quiet),
				"%s: every Gain and Cost line and the silence line carry a size (%s)" % [kind, quiet])
		var text: String = str(card["title"]) + " " + str(card["text"])
		for i in range(n):
			text += " " + str(card["options"][i]["label"]) + " " + " ".join(_lines(card, i))
		_check(not text.contains("{") and not text.contains("}") and not text.contains("  "),
				"%s: no token is left unfilled (%s)" % [kind, text])
		if kind == "breakout":
			var p: Dictionary = GameState.list_player(str(GameState.papers_record()["pid"]))
			_check(not p.is_empty() and text.contains(GameDB.player_display_name(p)) and float(p["age"]) <= 22.0,
					"The breakout story names a young player on the list")
	# Talking the club up.
	_restore(at_papers)
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
	var reck := StoryDeck.by_id(StoryDeck.all(), "media_papers_reckoning")
	var reck_board := []
	for c in reck["choices"]:
		for ce in c["effects"]:
			if str(ce["op"]) == "board":
				reck_board.append(absi(int(ce["d"])))
	reck_board.sort()
	_check(cost_line.contains("on the record") and cost_line.contains("the papers can come back for it once")
			and cost_line.contains("board confidence %d%% to %d%%" % [int(reck_board[0]), int(reck_board[-1])])
			and cost_line.contains("%d%% if you say nothing" % absi(int(reck["unanswered"]["board"])))
			and cost_line.contains("target stays where it is"),
			"The cost of talking up says when the papers come back, what answering them costs, and that the target does not move (%s)" % cost_line)
	# Backing it, deflecting: nothing on the record.
	for pair in [[0], [1]]:
		_restore(at_papers)
		_force("finish")
		var b0 := GameState.board_confidence()
		GameState.papers_answer(int(pair[0]))
		_check(int(GameState.papers_record()["claim"]) == 0 and not GameState.story["flags"].has("club"),
				"Answer %d puts nothing on the record" % int(pair[0]))
		_check(GameState.board_confidence() == b0 + (-1 if int(pair[0]) == 0 else -2),
				"Answer %d moves the board by what its Gain and Cost say" % int(pair[0]))
	# The breakout: talking him up is a promised run, with its sting if broken.
	_restore(at_papers)
	_force("breakout")
	var pid := str(GameState.papers_record()["pid"])
	var kid: Dictionary = GameState.list_player(pid)
	GameState.papers_answer(2)
	_check(Backing.is_active(kid), "Promising the tipped kid a run puts the run on him")


func _test_reckoning() -> void:
	# A club that is not on top after nine rounds, so it can be behind the 1st it named
	# (Fremantle's start depends on every rating in the league, draftees included: next year's
	# draft prospects play the pre-season practice matches as trial guests, so their draft-night
	# scale moves practice xp and a few seniors by a point, and the ladder after nine rounds).
	_career("WCE")
	_to_papers()
	_force("finish")
	GameState.papers_answer(2)
	GameState.preseason_advance()
	_check(not GameState.preseason_active(), "Into the season")
	var deck := StoryDeck.all()
	var t := StoryDeck.by_id(deck, "media_papers_reckoning")
	# Claim 1st: any other place is behind it.
	GameState.preseason["papers"]["claim"] = 1
	# Up to nine rounds, stopping once the card has been dealt (it needs the
	# talk six weeks old first: data/stories/media.json "after": 6).
	for i in range(9):
		GameState.advance()
		if GameState.story["last"].has("media_papers_reckoning"):
			break
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
	_at_papers()
	_force("finish")
	var b0 := GameState.board_confidence()
	GameState.preseason_advance()
	_check(GameState.board_confidence() == b0 - 3 and str(GameState.papers_record()["result"]).begins_with("You say nothing"),
			"Saying nothing costs the board three, as on any card, and the result says so")
	# A hands-off run goes through the papers on silence (from the papers as
	# they ran, unforced and unanswered).
	_at_papers()
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
	# One career: kept at week 5 on its way to the papers (the older save below).
	_career()
	var guard := 0
	while GameState.preseason_week() < 5 and guard < 12:
		guard += 1
		GameState.preseason_advance()
	var week5 := _snap()
	var w5 := GameState.preseason_week()
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
	# A pre-season saved before the papers existed (it stood mid pre-season) plays on to them.
	_check(GameState._restore_career(week5.duplicate(true)) and GameState.preseason_week() == w5,
			"(setup) the career is put back at week %d" % w5)
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
	var stk := _snap()
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
	_restore(stk)
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
	# Wide. (The breakout above was only read, never answered: forcing the
	# finish story puts the papers back to an unanswered finish.)
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
	# Every club's power-ranking blurb, whole, on a phone and on a PC of either
	# size (the 2026-11-12 capture: a PC printed only the practice move, so eight
	# clubs had no words), and on a PC all of it in view without scrolling.
	# One career per club, at its papers as they ran, shown at each size.
	for club in ["STK", CLUB]:
		if club == "STK":
			_restore(stk)
		else:
			_career(club)
			_to_papers()
		for size in [Vector2i(390, 844), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			tree.root.size = size
			Router.stack = ["main"]
			Router.go("hub")
			await _frames(tree, 8)
			scene = tree.current_scene as Control
			var what := "%s at %dx%d" % [club, size.x, size.y]
			var order: Array = GameState.papers_record().get("order", [])
			var blurbs := GameState.papers_blurbs()
			var page := scene.find_child("PreSeasonPage", true, false) as Control
			var view := (page.get_parent() as Control).get_global_rect()
			var missing: Array = []
			var hidden: Array = []
			for i in range(order.size()):
				var note := scene.find_child("PapersBlurb_%d" % i, true, false) as Label
				var want := str(blurbs.get(str(order[i]), ""))
				if note == null or want == "" or note.text != want or note.clip_text or note.max_lines_visible >= 0:
					missing.append(str(order[i]))
				elif size.x >= 900 and (note.get_global_rect().end.y > view.end.y + 0.5 or note.get_global_rect().position.y < view.position.y
						or note.get_global_rect().end.x > view.end.x + 0.5):
					hidden.append(str(order[i]))
			_check(order.size() == 18 and missing.is_empty(), "Every club's whole blurb is under its name, %s (missing: %s)" % [what, str(missing)])
			if size.x < 900:
				continue
			_check(hidden.is_empty(), "On a PC every blurb is in view without scrolling, %s (out of view: %s)" % [what, str(hidden)])
			# 1920x1080 holds the whole page. At 1280x720 the story's column (the
			# story, the fitness plan and the weeks to come) can run a line past
			# the window for some stories; it ran 12 to 24 px past before the
			# blurbs were added, and must not run further than that.
			var slack := 0.5 if size.y >= 1000 else 16.0
			var over := int(page.get_global_rect().end.y - view.end.y)
			print("  %s: page ends %d px past the window (negative: inside it)" % [what, over])
			_check(page.get_global_rect().end.y <= view.end.y + slack,
					"On a PC the papers page fits the window (within %d px at 1280x720), %s (page ends %d, window %d)"
					% [int(slack), what, int(page.get_global_rect().end.y), int(view.end.y)])
			var cols := scene.find_child("PapersLadderColumns", true, false) as Control
			var widths_ok := cols != null and cols.get_child_count() == 3
			for c in (cols.get_children() if cols != null else []):
				widths_ok = widths_ok and (c as Control).get_child_count() > 0 and (c as Control).size.x >= 180.0
			_check(widths_ok, "On a PC the ladder's columns each hold clubs and are wide enough to read, %s" % what)
	tree.root.size = Vector2i(390, 844)


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
