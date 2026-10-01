extends RefCounted
## Roles: wings and taggers are real jobs the engine rewards, not labels.
## Two of the five midfield spots are wings; the centre square alone wins
## the stoppage; a tagger makes a tag bite; vocabulary is one set of words.
## Run through tests/run_roles_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_identity()
	_test_vocabulary()
	_test_wing_marking()
	_test_named_wings()
	_test_engine_rewards_wings()
	_test_tagger()
	_test_no_prescriptions()
	_test_corrections()
	_test_forward_types()
	_test_every_club_fields_wings()
	_test_listed_second_positions()
	_test_identities()
	_test_formation_wings()
	_test_list_profile()
	print("Roles tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _mid(id: String, carry: int, disposal: int, contested: int, pressure := 50) -> Dictionary:
	var attr := {}
	for k in PlayerProfile.ATTR_LABELS:
		attr[k] = 50
	attr["carry"] = carry
	attr["disposal"] = disposal
	attr["contested"] = contested
	attr["pressure"] = pressure
	return {"id": id, "role": "MID", "role2": "", "overall": 70, "attr": attr,
			"name": "Player " + ["Ash", "Birch", "Cedar", "Dune", "Elm"][id.length() % 5] + id.substr(0, 1),
			"real_name": "Player " + id.substr(0, 1)}


func _test_identity() -> void:
	var runner := _mid("R", 90, 88, 30, 20)
	var bull := _mid("B", 45, 60, 92)
	_check(Roles.is_wing(runner) and Roles.label(runner) == "Wing", "A runner who uses it is a wing")
	_check(not Roles.is_wing(bull) and Roles.label(bull) == "Inside midfielder", "A ball-winner is an inside midfielder")
	var fwd := runner.duplicate(true)
	fwd["role"] = "FWD"
	_check(not Roles.is_wing(fwd), "A forward is never a wing")
	_check(Roles.label({}) == "" and Roles.label({"role": "MID"}) == "", "Missing data gives no label, not a crash")
	_check(Roles.label(runner) == Roles.label(runner.duplicate(true)), "Labels are deterministic")
	_check(Roles.fit_note(bull, "WING") == "Not a natural wing" and Roles.fit_note(runner, "WING") == "",
			"The wing flags a ball-winner, not a runner")
	_check(Roles.fit_note(runner, "MID") == "" and Roles.fit_note(bull, "MID") == "",
			"The centre square gives no advice")


func _test_vocabulary() -> void:
	var labels := []
	for row in GameState.TRAIN_PLANS:
		labels.append(str(row["label"]))
	_check(labels.has("Wing") and not str(labels).to_lower().contains("outside"),
			"Training says Wing, never 'outside runner' (%s)" % str(labels))
	var runner := _mid("R", 90, 88, 30, 20)
	_check(PlayerProfile.player_type(runner) == "Wing", "Draft profile and Selection agree: Wing")
	var seen := {}
	for p in GameDB.players:
		seen[Roles.label(p)] = true
	var allowed := ["Wing", "Tagger", "Inside midfielder", "Key defender", "Rebounding defender", "Defender",
			"Key forward", "Small forward", "Forward", "Ruck"]
	var clean := true
	for l in seen:
		if not allowed.has(l):
			clean = false
			push_error("Unexpected label: %s" % l)
	_check(clean, "Every player reads as one of nine football identities")


func _test_wing_marking() -> void:
	var list: Array = GameDB.club_list("COL")
	var side := Ratings.select_22(list)
	var wings := 0
	var mids := 0
	for p in side["ground"]:
		if str(p["role"]) == "MID":
			mids += 1
			if Roles.on_wing(p):
				wings += 1
	_check(mids == 5 and wings == Roles.WING_SLOTS, "Auto-pick names two of the five midfielders as wings")
	var leaked := false
	for p in list:
		if p.has("line"):
			leaked = true
	_check(not leaked, "Marking wings never writes onto the list players")


func _test_named_wings() -> void:
	var list: Array = GameDB.club_list("GEE")
	var auto := Ratings.select_22(list)
	var ids := {"RUCK": [], "MID": [], "WING": [], "DEF": [], "FWD": [], "BENCH": []}
	var mid_ids := []
	for p in auto["ground"]:
		if str(p["role"]) == "MID":
			mid_ids.append(str(p["id"]))
		else:
			(ids[str(p["role"])] as Array).append(str(p["id"]))
	# Name the two most contested midfielders as the wings.
	var by_contest := []
	for id in mid_ids:
		for p in list:
			if str(p["id"]) == id:
				by_contest.append(p)
	by_contest.sort_custom(func(a, b): return int(a["attr"]["contested"]) > int(b["attr"]["contested"]))
	ids["WING"] = [str(by_contest[0]["id"]), str(by_contest[1]["id"])]
	for p in by_contest.slice(2):
		ids["MID"].append(str(p["id"]))
	var side := Ratings.select_side(list, ids)
	var named_ok := 0
	var mids := 0
	for p in side["ground"]:
		if str(p["role"]) == "MID":
			mids += 1
		if Roles.on_wing(p) and (ids["WING"] as Array).has(str(p["id"])):
			named_ok += 1
	_check(named_ok == 2 and mids == 5, "Named wings play the wings, and the midfield stays five")


## The engine: the centre square wins the stoppage ball, so ball-winners on
## the wings lower the side's contest.
func _test_engine_rewards_wings() -> void:
	var list: Array = GameDB.club_list("SYD")
	var good := Squad.new("SYD", list, true, "SYD")
	var sel := {"RUCK": [], "MID": [], "WING": [], "DEF": [], "FWD": [], "BENCH": []}
	var mids := []
	for p in good.ground:
		if str(p["role"]) == "MID":
			mids.append(p)
		else:
			(sel[str(p["role"])] as Array).append(str(p["id"]))
	mids.sort_custom(func(a, b): return Roles.centre_fit(a) > Roles.centre_fit(b))
	sel["WING"] = [str(mids[0]["id"]), str(mids[1]["id"])]
	for p in mids.slice(2):
		sel["MID"].append(str(p["id"]))
	var bad := Squad.new("SYD", list, true, "SYD", sel)
	_check(good.contest > bad.contest + 1.0,
			"Ball-winners on the wings cost the side at the stoppage (%.1f vs %.1f)" % [good.contest, bad.contest])
	var centre := []
	for p in good.ground:
		if str(p["role"]) == "MID" and not Roles.on_wing(p):
			centre.append(float(p["attr"]["contested"]))
	var mean := 0.0
	for v in centre:
		mean += v
	mean /= maxf(1.0, centre.size())
	_check(is_equal_approx(good.mid_contest, mean) and centre.size() == 3,
			"Midfield contest is the three centre-square midfielders")


func _test_tagger() -> void:
	var stopper := _mid("T", 40, 45, 25, 95)
	var star := _mid("S", 70, 80, 95, 95)
	_check(Roles.is_tagger(stopper) and Roles.label(stopper) == "Tagger", "A stopper is a tagger")
	_check(not Roles.is_tagger(star), "A star ball-winner who tackles is not a tagger")
	var n := 0
	for p in GameDB.players:
		if Roles.is_tagger(p):
			n += 1
	_check(n >= 8 and n <= 40, "Taggers are a specialist few (%d)" % n)
	# In a match, a tagger on the ground makes the tag bite harder.
	var list: Array = GameDB.club_list("COL").duplicate(true)
	var home := Squad.new("COL", list, true, "COL")
	var away := Squad.new("CAR", GameDB.club_list("CAR"), false, "CAR")
	var sim := MatchSim.new(home, away, 7)
	var has := false
	for p in home.ground:
		if Roles.is_tagger(p):
			has = true
	_check(sim._tag_share(0) == (Roles.TAG_WITH_TAGGER if has else Roles.TAG_PLAIN),
			"The tag share follows whether a tagger is on the ground")
	_check(Roles.TAG_WITH_TAGGER < Roles.TAG_PLAIN, "A tagger takes more of the ball off his man")
	# A tag is a midfield job: a tag on a defender or forward does nothing,
	# and the player who goes to the tagged man is a midfielder.
	var t = MatchSim.tagger_for(home.ground)
	_check(t != null and str(t["role"]) == "MID", "The player who takes the tag is a midfielder")
	var back: Dictionary = {}
	var mid: Dictionary = {}
	for p in away.ground:
		if str(p["role"]) == "DEF" and back.is_empty():
			back = p
		if str(p["role"]) == "MID" and mid.is_empty():
			mid = p
	sim.set_tactics(0, {"gameplan": "balanced", "tag_id": str(back["id"])})
	_check(not MatchSim.taggable(back) and MatchSim.taggable(mid), "Only midfielders can be tagged")
	# Game plans suit a list: the upside grows with the players who carry
	# it, the cost does not.
	var ok_fit := true
	for code in GameDB.active_clubs(2027):
		var g: Array = Squad.new(code, GameDB.club_list(code), false, code).ground
		for plan in PlanFit.NEEDS:
			var f := PlanFit.fit(g, plan)
			if f < PlanFit.FIT_MIN or f > PlanFit.FIT_MAX or PlanFit.carriers(g, plan).is_empty():
				ok_fit = false
		if not (["balanced"] + PlanFit.NEEDS.keys()).has(PlanFit.standing_plan(g)):
			ok_fit = false
	_check(ok_fit, "Every club has a fit and named carriers for every plan, and a real usual game")
	sim.set_tactics(0, {"gameplan": "defensive"})
	sim.plan_fit[0]["defensive"] = 1.4
	var strong_press := sim._pv(0, "press")
	var strong_cost := sim._pv(0, "goal")
	sim.plan_fit[0]["defensive"] = 0.6
	_check(sim._pv(0, "press") < strong_press and is_equal_approx(sim._pv(0, "goal"), strong_cost),
			"A press gets more from pressure players; what it gives up stays the same")
	var usual := {}
	for code in GameDB.active_clubs(2027):
		usual[PlanFit.standing_plan(Squad.new(code, GameDB.club_list(code), false, code).ground)] = true
	_check(usual.size() >= 3, "Clubs play different usual games (%s)" % str(usual.keys()))
	# Controlled tempo now needs clean ball users: good lists get more from it,
	# poor ones only blunt a press part-way. It stays a situational protection
	# plan, never a club's usual game.
	var controlled_ok := true
	var lo := INF
	var hi := -INF
	for code in GameDB.active_clubs(2027):
		var g2: Array = Squad.new(code, GameDB.club_list(code), false, code).ground
		var f := PlanFit.fit(g2, "controlled")
		lo = minf(lo, f)
		hi = maxf(hi, f)
		controlled_ok = controlled_ok and not PlanFit.carriers(g2, "controlled").is_empty() \
				and PlanFit.standing_plan(g2) != "controlled"
	_check(controlled_ok and hi > lo,
			"Controlled tempo depends on ball users and is never a club's usual game")


## Selection surfaces the problem, never the answer: no hint names who to
## pick or who to tag.
func _test_no_prescriptions() -> void:
	var runner := _mid("R", 90, 88, 30, 20)
	_check(Roles.fit_note(runner, "MID") == "", "A natural wing in the centre square gets no advice")


func _test_corrections() -> void:
	for name in ["Maurice Rioli", "Cody Weightman"]:
		var found := {}
		for p in GameDB.players:
			if str(p.get("real_name", "")) == name:
				found = p
		_check(not found.is_empty() and str(found["role"]) == "FWD", "%s reads as a forward" % name)


## Key forward takes a tall, aerial focal point - never goals alone. Height
## is evidence, not a cut-off (~192 cm the rule of thumb); unclear cases read
## plain "Forward". Labels only: no rating changes.
func _test_forward_types() -> void:
	var fwd := func(h: float, marking: int, goals: int) -> Dictionary:
		var p := _mid("F", 50, 50, 40)
		p["role"] = "FWD"
		p["height_cm"] = h
		p["attr"]["marking"] = marking
		p["attr"]["goalkicking"] = goals
		return p
	_check(PlayerProfile.forward_type(fwd.call(198.0, 95, 70)) == "Key forward", "A tall aerial target is a key forward")
	_check(PlayerProfile.forward_type(fwd.call(176.0, 10, 60)) == "Small forward", "A small forward below the pack is a small forward")
	_check(PlayerProfile.forward_type(fwd.call(186.0, 50, 60)) == "Forward", "A medium forward is a Forward")
	_check(PlayerProfile.forward_type(fwd.call(182.0, 80, 99)) != "Key forward",
			"A prolific medium forward who marks well is not a key forward")
	_check(PlayerProfile.forward_type(fwd.call(200.0, 5, 40)) == "Forward",
			"Height alone does not make a key forward")
	_check(PlayerProfile.forward_type(fwd.call(190.0, 99, 80)) == "Key forward"
			and PlayerProfile.forward_type(fwd.call(193.0, 20, 80)) != "Key forward",
			"192 cm is not a cut-off: a great mark just under it is key, a weak one over it is not")
	_check(PlayerProfile.forward_type(fwd.call(0.0, 95, 95)) == "Forward", "No height on record: plain Forward")
	# Jamie Elliott is 178 cm (his height once came from a 1991 namesake).
	var want := {"Toby Greene": "Forward", "Charlie Cameron": "Forward", "Jamie Elliott": "Small forward",
			"Charlie Curnow": "Key forward", "Jeremy Cameron": "Key forward", "Harry McKay": "Key forward",
			"Maurice Rioli": "Small forward", "Cody Weightman": "Small forward",
			# Three games cannot make him a key defender or a rebounder.
			"Xavier Taylor": "Defender"}
	for p in GameDB.players:
		var n := str(p.get("real_name", ""))
		if want.has(n):
			_check(Roles.label(p) == str(want[n]), "%s reads %s (%s)" % [n, want[n], Roles.label(p)])


## AI sanity: every club still fields 18 with a full midfield and two wings.
func _test_every_club_fields_wings() -> void:
	var ok := true
	for code in GameDB.active_clubs(2026):
		var sq := Squad.new(code, GameDB.club_list(code), false, code)
		var wings := 0
		for p in sq.ground:
			if Roles.on_wing(p):
				wings += 1
		if sq.ground.size() != 18 or wings != 2:
			ok = false
			push_error("%s: %d on the ground, %d wings" % [code, sq.ground.size(), wings])
	_check(ok, "Every club fields 18 with two wings")


## Football identities for the cases the playtest exposed, and the rules
## behind them: a key defender has size, a wing seldom wins the stoppage.
func _test_identities() -> void:
	var by_name := {}
	for p in GameDB.players:
		by_name[str(p.get("real_name", ""))] = p
	var lab := func(n: String) -> String:
		return Roles.label(by_name[n]) if by_name.has(n) else "?"
	_check(lab.call("Bodhi Uwland") != "Key defender", "Bodhi Uwland (188 cm) is not a key defender (%s)" % lab.call("Bodhi Uwland"))
	for n in ["Harris Andrews", "Sam De Koning", "Jake Lever"]:
		_check(lab.call(n) == "Key defender", "%s is a key defender (%s)" % [n, lab.call(n)])
	_check(lab.call("Gryan Miers") == "Small forward", "Gryan Miers is a small forward (%s)" % lab.call("Gryan Miers"))
	for n in ["Harvey Langford", "Xavier Duursma", "Ed Langdon"]:
		_check(lab.call(n) == "Wing", "%s is a wing (%s)" % [n, lab.call(n)])
	for n in ["Clayton Oliver", "Patrick Cripps"]:
		_check(lab.call(n) == "Inside midfielder", "%s is an inside midfielder (%s)" % [n, lab.call(n)])
	var short_keys := []
	var keys := 0
	for p in GameDB.players:
		if PlayerProfile.player_type(p) == "Key defender":
			keys += 1
			if float(p.get("height_cm", 0.0)) < PlayerProfile.KEY_DEF_CM:
				short_keys.append(str(p.get("real_name", "")))
	_check(short_keys.is_empty() and keys >= 54,
			"Every key defender has key-position size, and every club has some (%d; %s)" % [keys, short_keys])
	var fwds := 0
	for p in GameDB.players:
		fwds += 1 if str(p["role"]) == "FWD" else 0
	_check(fwds >= 180, "Forwards are forwards first: enough for six a side and cover (%d)" % fwds)


## His club's listing is his first position unless the numbers show a
## midfielder in fact (clearances, with his listed game thinned out) or his
## listed game has gone; a listed line the numbers win keeps as a second
## position when his own numbers back it up.
func _test_listed_second_positions() -> void:
	var by_name := {}
	for p in GameDB.players:
		by_name[str(p.get("real_name", ""))] = p
	var tag := func(n: String) -> String:
		return Ratings.role_tag(by_name[n]) if by_name.has(n) else "?"
	for n in ["Joe Richards", "Connor Macdonald", "Murphy Reid"]:
		_check(tag.call(n) == "MID/FWD", "%s is a midfielder who plays forward (%s)" % [n, tag.call(n)])
	for n in ["Beau McCreery", "Milan Murdock", "Jack Ginnivan", "Kade Chandler", "Max King"]:
		_check(tag.call(n).begins_with("FWD"), "%s is a forward (%s)" % [n, tag.call(n)])
	_check(tag.call("Gryan Miers") == "FWD/MID", "Gryan Miers is a forward who can go through the middle (%s)" % tag.call("Gryan Miers"))
	for n in ["Zac Williams", "Liam Baker", "Jhye Clark", "Sam De Koning"]:
		_check(tag.call(n).begins_with("DEF"), "%s is a defender (%s)" % [n, tag.call(n)])
	for n in ["Colby McKercher", "Chris Scerri"]:
		_check(tag.call(n) == "MID", "%s stays a midfielder (%s)" % [n, tag.call(n)])
	var lp := func(listed: String, gm: float, cl: float, own: float, mid: float) -> String:
		return Ratings.listed_primary({"real_pos": listed, "gm": gm, "cl": cl * gm,
				"role_scores": {"FWD": own, "DEF": own, "MID": mid, "RUCK": -1.0}}, "MID")
	_check(lp.call("FWD", 20, 1.0, 0.33, 0.53) == "FWD", "Disposals alone never move a listed forward")
	_check(lp.call("FWD", 20, 2.5, 0.30, 0.53) == "MID", "A listed forward winning clearances with little forward game is a midfielder")
	_check(lp.call("FWD", 20, 2.5, 0.40, 0.53) == "FWD", "...unless his forward game holds up")
	_check(lp.call("FWD", 20, 0.8, 0.22, 0.53) == "MID", "A listed forward with no forward game left is a midfielder")
	_check(lp.call("DEF", 3, 3.0, 0.10, 0.60) == "DEF", "A few games never overrule the listing")
	_check(lp.call("", 20, 0.5, 0.40, 0.53) == "MID" and lp.call("MID", 20, 0.5, 0.40, 0.53) == "MID",
			"Without a forward or back listing, the numbers decide")
	var fwd := 0
	var def := 0
	var bad := ""
	for p in GameDB.players:
		if Ratings.plays_role(p, "FWD"):
			fwd += 1
		if Ratings.plays_role(p, "DEF"):
			def += 1
		if str(p.get("role2", "")) == str(p.get("role", "")):
			bad = str(p.get("real_name", ""))
	_check(fwd >= 210 and def >= 230, "The draft has forward and defensive depth (%d FWD, %d DEF)" % [fwd, def])
	_check(bad == "", "A second position is never the first (%s)" % bad)
	var mid := {"role": "MID", "real_pos": "FWD", "gm": 10.0, "gl": 5.0, "mi": 0.0, "rb": 0.0, "onepct": 0.0}
	_check(Ratings.listed_secondary(mid) == "FWD", "A goalkicking listed forward gets FWD")
	mid["gl"] = 1.0
	_check(Ratings.listed_secondary(mid) == "", "A listed forward who does not kick goals or mark inside 50 does not")
	_check(Ratings.listed_secondary({"role": "DEF", "real_pos": "FWD", "gm": 10.0, "gl": 9.0}) == "",
			"Only a midfielder on the numbers takes his listed line")

## The Best 22 oval shows the wings the match plays (Roles.mark_wings, the
## line "WING" on the match-day copies), never the next two by rating.
func _oval_slots(ground: Array, bench: Array = []) -> Dictionary:
	var fv := FormationView.new()
	var out := {}
	for e in fv._assign(ground, bench):
		out[str((e["player"] as Dictionary)["id"])] = str((e["slot"] as Dictionary)["abbr"])
	fv.free()
	return out


func _test_formation_wings() -> void:
	# A strong ball-winner rated second-best of the five is inside, not on a
	# wing: before, the oval filled C, W, W, IM, IM in rating order.
	var boss := _mid("boss", 50, 70, 95)
	boss["overall"] = 90
	var bull := _mid("bull", 50, 69, 90)       # Wardlaw-style: contested first
	bull["overall"] = 85
	var run1 := _mid("run1", 80, 75, 40)
	run1["overall"] = 60
	var run2 := _mid("run2", 78, 74, 42)
	run2["overall"] = 58
	var mid5 := _mid("mid5", 55, 60, 70)
	mid5["overall"] = 70
	var ruck := _mid("ruck", 30, 40, 60)
	ruck["role"] = "RUCK"
	var ground := [boss, bull, run1, run2, mid5, ruck]
	var slots := _oval_slots(ground)
	_check(slots["bull"] != "W", "A contested midfielder is not shown on a wing for his rating (%s)" % slots["bull"])
	_check(slots["run1"] == "W" and slots["run2"] == "W", "The runners the match would play on the wings are the Ws")
	var counts := {}
	for id in ["boss", "bull", "run1", "run2", "mid5"]:
		counts[slots[id]] = int(counts.get(slots[id], 0)) + 1
	_check(counts == {"C": 1, "W": 2, "IM": 2}, "Five midfielders fill C, W, W, IM, IM exactly (%s)" % str(counts))
	_check(slots["boss"] == "C", "The best centre-square player takes the centre")
	# Match-day marks win: whoever selection put on the wings is shown there.
	var copies := []
	for p in ground:
		copies.append(p.duplicate(true))
	for c in copies:
		if str(c["id"]) == "boss" or str(c["id"]) == "mid5":
			c["line"] = "WING"
	var named := _oval_slots(copies)
	_check(named["boss"] == "W" and named["mid5"] == "W" and named["run1"] != "W",
			"A named wing (line WING) is shown on the wing, whatever his fit")
	# Bench untouched.
	var bench := [_mid("b1", 60, 60, 60), _mid("b2", 60, 60, 60)]
	var with_bench := _oval_slots(ground, bench)
	_check(with_bench["b1"] == "INT" and with_bench["b2"] == "INT" and with_bench.size() == 8,
			"The bench stays on the interchange")
	# Every real club: the oval's wings are the match's wings.
	var agree := true
	var wardlaw_wing := false
	for code in GameDB.active_clubs(2026):
		var sel := Ratings.select_22(GameDB.club_list(code))
		var oval := _oval_slots(sel["ground"], sel["bench"])
		for p in sel["ground"]:
			if str(p["role"]) != "MID":
				continue
			if (oval[str(p["id"])] == "W") != Roles.on_wing(p):
				agree = false
			if str(p.get("last", "")) == "Wardlaw" and oval[str(p["id"])] == "W":
				wardlaw_wing = true
	_check(agree, "On every club's best 22 the oval's wings are the wings the match plays")
	_check(not wardlaw_wing, "Wardlaw is never shown on a wing")


## List profile (ARD-M6-006): six words, each where the side ranks in this
## league; they move with the list and with the league around it.
func _test_list_profile() -> void:
	var grounds := {}
	for code in GameDB.active_clubs(2027):
		grounds[str(code)] = Squad.new(code, GameDB.club_list(code), false, code).ground
	var n := grounds.size()
	var words := []
	for r in range(n):
		words.append(ListProfile.word(r, n))
	_check(words.count("Elite") >= 2 and words.count("Elite") <= 4 and words.count("Weak") >= 4
			and words[0] == "Elite" and words[n - 1] == "Weak",
			"The words spread across the league (%s)" % str(words))
	var mine := "COL"
	var prof := ListProfile.profile(grounds, mine)
	var labels := prof.map(func(r): return str(r["label"]))
	_check(labels == ["Contest", "Control", "Running power", "Pressure", "Aerial power", "Finishing"],
			"Six strengths in plain words (%s)" % str(labels))
	_check(prof.all(func(r): return ["Elite", "Strong", "Average", "Weak"].has(str(r["word"]))),
			"Every strength is a word, not a score")
	# Every club reads somewhere: the words are not all one thing.
	var seen := {}
	for code in grounds:
		for r in ListProfile.profile(grounds, code):
			seen[str(r["word"])] = true
	_check(seen.size() == 4, "Across the league, every word is used (%s)" % str(seen.keys()))
	# The list changes: better ball-winners lift Contest to the top.
	var better: Array = _boosted(grounds[mine], ["contested", "ruck"], 30)
	var g2 := grounds.duplicate()
	g2[mine] = better
	_check(_word(ListProfile.profile(g2, mine), "contest") == "Elite",
			"Better ball-winners make the Contest elite")
	# The league changes around the same list: its Aerial power drops as
	# everyone else's marks get better.
	var before := _rank(prof, "aerial")
	var g3 := {}
	for code in grounds:
		g3[code] = grounds[code] if code == mine else _boosted(grounds[code], ["marking"], 12)
	var after := _rank(ListProfile.profile(g3, mine), "aerial")
	_check(after > before and _word(ListProfile.profile(g3, mine), "aerial") == "Weak",
			"The same list reads weaker in the air when the league marks better (%d to %d)" % [before, after])
	# Aerial power is not Control: better marks move one and not the other.
	var markers: Array = _boosted(grounds[mine], ["marking"], 30)
	_check(is_equal_approx(ListProfile.score(markers, "control"), ListProfile.score(grounds[mine], "control"))
			and ListProfile.score(markers, "aerial") > ListProfile.score(grounds[mine], "aerial"),
			"Aerial power and Control are different things")
	# Finishing: the best five forwards' goalkicking, accuracy and marking.
	var fwds: Array = grounds[mine].filter(func(p): return str(p["role"]) == "FWD")
	var vals: Array = fwds.map(func(p):
		return 0.5 * float(p["attr"]["goalkicking"]) + 0.3 * float(p["attr"]["accuracy"]) + 0.2 * float(p["attr"]["marking"]))
	vals.sort()
	vals.reverse()
	var top: Array = vals.slice(0, 5)
	var want: float = top.reduce(func(a, b): return a + b, 0.0) / float(top.size())
	_check(is_equal_approx(ListProfile.score(grounds[mine], "finishing"), want),
			"Finishing is the best five forwards' goalkicking, accuracy and marking")
	_check(ListProfile.leaders(grounds[mine], "finishing").all(func(p): return str(p["role"]) == "FWD"),
			"Finishing is led by forwards")
	# Better kicks for goal lift it to the top; better defenders do not move it.
	var kickers: Array = _boosted(grounds[mine], ["goalkicking", "accuracy"], 30)
	var g4 := grounds.duplicate()
	g4[mine] = kickers
	_check(_word(ListProfile.profile(g4, mine), "finishing") == "Elite",
			"Better goalkickers make the Finishing elite")
	var backs: Array = grounds[mine].map(func(p):
		var q: Dictionary = p.duplicate(true)
		if str(q["role"]) == "DEF":
			q["attr"]["marking"] = float(q["attr"]["marking"]) + 30
			q["attr"]["goalkicking"] = float(q["attr"]["goalkicking"]) + 30
		return q)
	_check(is_equal_approx(ListProfile.score(backs, "finishing"), ListProfile.score(grounds[mine], "finishing")),
			"Finishing is the forwards' alone: the backs do not move it")
	# Three strengths are the plans' own definitions, not a parallel system.
	_check(is_equal_approx(ListProfile.score(grounds[mine], "contest"), PlanFit.score(grounds[mine], "contest"))
			and is_equal_approx(ListProfile.score(grounds[mine], "pressure"), PlanFit.score(grounds[mine], "defensive"))
			and is_equal_approx(ListProfile.score(grounds[mine], "running"), PlanFit.score(grounds[mine], "attacking")),
			"Contest, Pressure and Running power are what the game plans lean on")


func _boosted(ground: Array, keys: Array, by: int) -> Array:
	var out := []
	for p in ground:
		var q: Dictionary = p.duplicate(true)
		for k in keys:
			(q["attr"] as Dictionary)[k] = mini(99, int((q["attr"] as Dictionary).get(k, 0)) + by)
		out.append(q)
	return out


func _word(prof: Array, dim: String) -> String:
	for r in prof:
		if str(r["dim"]) == dim:
			return str(r["word"])
	return ""


func _rank(prof: Array, dim: String) -> int:
	for r in prof:
		if str(r["dim"]) == dim:
			return int(r["rank"])
	return -1
