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
const ENGINE := ["fp", "chain", "ballup", "ball-up", "inside50", "_", "|", "def "]


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
	_test_full_time()
	_test_report_roles(res)
	_test_rating()
	_test_report_glance()
	_test_no_green_decoration()
	_test_club_markers()
	_test_palette_snapshot()
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
		# "sim" is an engine token only as a word. A real surname such as Sims
		# must not trip the presentation-language guard.
		var sim_word := RegEx.new()
		sim_word.compile("(^|[^a-z])sim([^a-z]|$)")
		if sim_word.search(low) != null:
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
	# Playtest: the break replayed every call already seen in the feed. Only
	# the ones that carry into the next quarter come back.
	var played := {"moments": [
		{"kind": "set_shot", "q": 1, "title": "Set shot", "choice_label": "Take the shot", "outcome": "GOAL to X!"},
		{"kind": "tired", "q": 1, "title": "X is running on empty", "choice_label": "Rest him now", "outcome": "He comes off."},
		{"kind": "momentum", "q": 1, "title": "They have kicked 3 in a row", "choice_label": "Ride it out", "outcome": "No change."},
		{"kind": "hot", "q": 2, "title": "Y has kicked 3", "choice_label": "Tag him", "outcome": "Z goes to him."}]}
	_check(MatchNotes.lasting_moment_lines(played, 1) == ["X is running on empty: Rest him now. He comes off."],
			"At the break, only the calls that carry on come back (%s)" % [MatchNotes.lasting_moment_lines(played, 1)])
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


func _test_full_time() -> void:
	var bad := ""
	var total := 0
	for seed in [1, 6, 12, 19, 27, 33]:
		var r := _match(seed, "MEL", "ESS")
		for side in [0, 1]:
			var f: Array = MatchNotes.match_factors(r, side)
			_check(f.size() >= 1 and f.size() <= MatchNotes.MAX_FACTORS, "Two to four reasons, never none")
			total += f.size()
			for t in f:
				var low := str(t).to_lower()
				for w in ADVICE:
					if low.contains(w):
						bad = str(t)
				if low.contains("%") or low.contains("pts") or low.contains("expected"):
					bad = str(t)
		var best := MatchNotes.standouts(r, 0, 3)
		_check(best.size() == 3 and str(best[0]["line"]) != "", "Standouts come with their game in words")
		for p in best:
			if str(p["line"]).contains("CLR") or str(p["line"]).contains("disp "):
				bad = str(p["line"])
	_check(total > 12, "Matches produce reasons (%d)" % total)
	_check(bad == "", "Full-time reasons are football, not a stat sheet or advice (%s)" % bad)
	_check(MatchNotes.game_line({"disposals": 31.0, "clearances": 8.0, "goals": 0.0}) == "31 disposals, 8 clearances",
			"A midfielder's game in a few words")
	_check(MatchNotes.game_line({"disposals": 12.0, "goals": 4.0}) == "4 goals", "A forward's game is his goals")
	var ks := MatchNotes.key_stats(_match(3), 0)
	_check(ks.size() == 4 and str(ks[0][0]) == "Disposals" and str(ks[3][0]) == "Pressure rating",
			"Four key stats at full time, pressure rating last")
	var top := MatchNotes.standouts(_match(5), 0, 3)
	_check(float(top[0]["rating"]) >= float(top[2]["rating"]), "Standouts come best rated first")


## The report names a player's own position, never the slot rotations left
## him in: a midfielder who filled the ruck is still a MID.
func _test_report_roles(res: Dictionary) -> void:
	var bad := ""
	for side in [0, 1]:
		for r in (res["roster"] as Array)[side]:
			var own = GameDB.player_by_id(str(r["id"]))
			if own is Dictionary and str(r["list_role"]) != str(own["role"]):
				bad = str(r["name"])
	_check(bad == "", "The roster carries each player's own position (%s)" % bad)
	# Fill a vacant ruck with a midfielder: the report keeps him a MID.
	var list := GameDB.club_list("NTH").duplicate(true)
	var mid := {}
	for p in list:
		if str(p["role"]) == "RUCK":
			p["injury_weeks"] = 3
		elif mid.is_empty() and str(p["role"]) == "MID":
			mid = p
	var sel := {"RUCK": [str(mid["id"])]}
	var sim := MatchSim.new(Squad.new("NTH", list, true, "NTH", sel), Squad.new("CAR", GameDB.club_list("CAR"), false, "CAR"), 4)
	var r2 := sim.run()
	var ranked := CoachReport.rank_side((r2["roster"] as Array)[0], r2.get("players", {}), 4)
	var line := ""
	for e in ranked:
		if str(e["id"]) == str(mid["id"]):
			line = str(e["role"])
	_check(line == "MID", "A midfielder named in the ruck is still a MID in the report (%s)" % line)


## The player rating: a fantasy-style score for one match, many ways to a
## big game, and a real path to best on ground for every position.
func _test_rating() -> void:
	var r := func(st: Dictionary) -> int: return MatchNotes.rating(st)
	var key_fwd: int = r.call({"goals": 5.0, "behinds": 2.0, "marks": 9.0, "kicks": 9.0, "handballs": 2.0, "inside50": 1.0})
	var mid: int = r.call({"kicks": 16.0, "handballs": 14.0, "clearances": 9.0, "tackles": 7.0, "pressure_acts": 18.0, "inside50": 6.0, "marks": 4.0, "goals": 1.0})
	var back: int = r.call({"kicks": 15.0, "handballs": 5.0, "marks": 9.0, "rebounds": 8.0, "one_percenters": 9.0, "tackles": 3.0, "pressure_acts": 8.0})
	# A ruck's big game is taps and the ball: around the ground, a mark, a goal.
	var ruck: int = r.call({"hitouts": 32.0, "clearances": 6.0, "kicks": 8.0, "handballs": 6.0, "marks": 4.0, "tackles": 3.0, "pressure_acts": 10.0, "goals": 1.0})
	for x in [["key forward", key_fwd], ["midfielder", mid], ["defender", back], ["ruck", ruck]]:
		_check(int(x[1]) >= 95, "A big game rates as one for a %s (%d)" % x)
	# Taps alone are not a best-on-ground game: in the engine a hit-out
	# decides little, and a ruck with no opposite number can take 60.
	var taps_only: int = r.call({"hitouts": 60.0, "kicks": 5.0, "handballs": 4.0, "marks": 2.0, "tackles": 2.0, "pressure_acts": 6.0})
	_check(taps_only < mid and taps_only < 110, "Sixty taps and little else is not best on ground (%d v %d)" % [taps_only, mid])
	var empty: int = r.call({"kicks": 6.0, "handballs": 20.0, "clangers": 4.0})
	_check(empty < 50, "Twenty-six touches and little else is a quiet game (%d)" % empty)
	_check(int(r.call({})) == 0 and int(r.call({"clangers": 10.0, "frees_against": 6.0})) == 0,
			"No contribution rates 0; the floor is 0")
	_check(r.call({"kicks": 1.0}) is int, "The rating is a whole number")
	_check(int(r.call({"goals": 1.0})) < int(r.call({"goals": 1.0, "tackles": 5.0})), "More contribution, higher rating")
	_check(int(r.call({"marks": 5.0, "frees_against": 1.0, "clangers": 1.0})) == 12,
			"A free against costs 3 in all (it is also a clanger)")
	_check(MatchNotes.rating_text(118) == "118", "Shown as a whole number")
	# Parity: across real simulated matches, each position's better games
	# reach similar ratings, and forwards and defenders are sometimes a
	# side's best (midfielders are not the only way to top a side).
	var by := {"DEF": [], "MID": [], "FWD": [], "RUCK": []}
	var best := {}
	var clubs := ["COL", "CAR", "GEE", "SYD", "BRL", "MEL", "HAW", "ESS", "FRE", "ADE", "GWS", "PAD"]
	for i in range(8):
		var res := _match(40 + i, clubs[i], clubs[i + 4])
		for side in [0, 1]:
			var rated := MatchNotes.rated_players(res, side)
			for p in rated:
				(by[str(p["role"])] as Array).append(int(p["rating"]))
			for p in rated.slice(0, 3):
				best[str(p["role"])] = int(best.get(str(p["role"]), 0)) + 1
	var p90 := {}
	for role in by:
		var v: Array = by[role]
		v.sort()
		if v.size() >= 5:
			p90[role] = int(v[int(v.size() * 0.9)])
	var lo := 999
	var hi := 0
	for role in ["DEF", "MID", "FWD"]:
		lo = mini(lo, int(p90.get(role, 0)))
		hi = maxi(hi, int(p90.get(role, 0)))
	_check(p90.size() >= 3 and hi - lo <= 30, "No position is shut out of big ratings (%s)" % str(p90))
	_check(int(best.get("FWD", 0)) >= 1 and int(best.get("DEF", 0)) >= 1,
			"Forwards and defenders make their side's top three (%s)" % str(best))


## The half-time report at a glance: a few lines and a few players, in words.
func _test_report_glance() -> void:
	var bad := ""
	for seed in [2, 4, 8, 16]:
		var sim := MatchSim.new(Squad.new("HAW", GameDB.club_list("HAW"), true, "HAW"),
				Squad.new("BRL", GameDB.club_list("BRL"), false, "BRL"), seed)
		sim.run_quarter()
		var res := sim.run_quarter()
		res["home"] = "HAW"
		res["away"] = "BRL"
		var g := CoachReport.glance(CoachReport.half_time_report(res, 0))
		_check(not (g["read"] as Array).is_empty() and (g["read"] as Array).size() <= 3, "A few lines on the match")
		_check((g["best"] as Array).size() <= 2 and (g["lift"] as Array).size() <= 2
				and (g["danger"] as Array).size() <= 2 and (g["notes"] as Array).size() <= 3, "A few players, a few notes")
		# Needs a lift follows the Player Rating on screen: half a game below
		# an ordinary one, never a busy player.
		var ht := CoachReport.half_time_report(res, 0)
		var by_name := {}
		for e in ht.get("my_ranked", []):
			by_name[str(e["name"])] = MatchNotes.rating(e.get("stats", {}))
		for p in g["lift"]:
			_check(int(by_name.get(str(p["name"]), 999)) < CoachReport.LIFT_BELOW / 2.0,
					"Needs a lift is a quiet game by the rating shown (%s %d)" % [str(p["name"]), int(by_name.get(str(p["name"]), -1))])
		for n in g["notes"]:
			var t := str(n)
			for ch in "0123456789":
				if t.contains(ch):
					bad = t
			for w in ADVICE:
				if t.to_lower().contains(w):
					bad = t
		for group in ["best", "lift", "danger"]:
			for p in g[group]:
				if str(p["line"]).contains("disp (") or str(p["line"]).contains("CLR") or str(p["line"]).contains("vs par"):
					bad = str(p["line"])
	_check(bad == "", "Notes and players read as football, not a stat sheet or advice (%s)" % bad)


## Green is a state (won, met, rising), not the game's accent: no screen
## paints a selection or a highlight with a green surface.
func _test_no_green_decoration() -> void:
	var found := ""
	var dir := DirAccess.open("res://scripts/ui")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/ui/" + f)
		if src.contains("263025"):
			found = f
	_check(found == "", "No green highlight surfaces in the UI (%s)" % found)


## A club is marked by its real colours: two for most, three where the
## third is a club colour (the Bulldogs' white, Adelaide's gold).
func _test_club_markers() -> void:
	var ok := true
	for code in GameDB.CLUB_ORDER:
		var m := UiKit.club_marker(code)
		var bands: Node = m.get_child(0)
		var want := 3 if GameDB.THREE_COLOUR_CLUBS.has(code) else 2
		if bands.get_child_count() != want:
			ok = false
		m.free()
	_check(ok, "Every club's marker shows its two or three colours")
	var mel := UiKit.club_marker("MEL")
	var cols := []
	for b in mel.get_child(0).get_children():
		cols.append((b as ColorRect).color)
	_check(cols == GameDB.club_colours("MEL").slice(0, 2), "Melbourne is navy and red")
	mel.free()
	var badge := UiKit.club_badge("WBD")
	_check(badge.find_child("ClubMarker", true, false) != null
			and badge.find_child("ClubMarker", true, false).get_child(0).get_child_count() == 3,
			"The club badge uses the marker (the Bulldogs in three colours)")
	badge.free()


## Club colours are a director-approved palette (2026-10-05, sourced to the
## clubs' Pantone references; Carlton and Melbourne keep a navy lifted off
## black so they don't read as Collingwood and Essendon). Any change to
## data/clubs.csv's colours must update this snapshot deliberately.
const PALETTE := {
	"ADE": ["#002B5C", "#E21937", "#FFD200"],
	"BRL": ["#A30046", "#0055A3", "#FDBE57"],
	"CAR": ["#0B1F4B", "#FFFFFF", "#7FA7E0"],
	"COL": ["#141414", "#FFFFFF", "#BFBFBF"],
	"ESS": ["#1A1A1A", "#CC2031", "#FFFFFF"],
	"FRE": ["#2A0D54", "#FFFFFF", "#A67FC1"],
	"GEE": ["#002B5C", "#FFFFFF", "#8FB4E3"],
	"GCS": ["#E02112", "#FFDD00", "#0079C1"],
	"GWS": ["#F47920", "#3C3C3B", "#FFFFFF"],
	"HAW": ["#4D2004", "#FBBF15", "#FFFFFF"],
	"MEL": ["#0A1F44", "#CC2031", "#FFFFFF"],
	"NTH": ["#1A3B8E", "#FFFFFF", "#C4D1E5"],
	"PAD": ["#008AAB", "#1A1A1A", "#C0C0C0"],
	"RIC": ["#FFD200", "#1A1A1A", "#FFFFFF"],
	"STK": ["#ED1B2F", "#1A1A1A", "#FFFFFF"],
	"SYD": ["#E1251B", "#FFFFFF", "#1A1A1A"],
	"WCE": ["#003087", "#F2A900", "#FFFFFF"],
	"WBD": ["#BD002B", "#20539D", "#FFFFFF"],
	"TAS": ["#2C5530", "#E8D44D", "#C2274D"],
	"CANB": ["#1B3B6F", "#FFFFFF", "#F5B301"],
}


func _test_palette_snapshot() -> void:
	var off := []
	for code in PALETTE:
		var want: Array = PALETTE[code]
		var got: Array = GameDB.club_colours(code)
		for i in range(3):
			if ("#" + (got[i] as Color).to_html(false)).to_upper() != str(want[i]):
				off.append("%s %d" % [code, i])
	_check(off.is_empty() and PALETTE.size() == GameDB.CLUB_ORDER.size(),
			"Every club's colours match the approved palette (%s)" % ", ".join(off))
