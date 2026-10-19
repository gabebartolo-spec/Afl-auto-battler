extends RefCounted
## Plan familiarity (PreSeason.gd, GameState "plan_known"): a side knows each
## game plan well, partly or barely. Drilling a plan in the pre-season moves it
## up a step, the off-season slips every plan a step, an unplayed plan fades
## slowly, and a plan known less than well gives less of its upside in the
## match. All of it behind the pre-season switch: off, nothing changes.

const Tap := preload("res://tests/tap.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 5311
const CLUB := "FRE"


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	_test_switch_off()
	Features.set_on("preseason", true)
	_test_rules()
	_test_words()
	_test_match_effect()
	_test_drilling()
	_test_ai()
	_test_off_season_and_fade()
	_test_old_saves()
	await _test_screens()
	PreSeason.reload()
	Features.clear("preseason")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Plan familiarity tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _career(open := true, club := CLUB) -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season(club, GameDB.club_list(club))
	if open:
		GameState.open_preseason()


## Every level and idle count, in a fixed order, to compare a record with itself.
func _levels() -> String:
	var rows := []
	var codes: Array = GameState.plan_known.keys()
	codes.sort()
	for c in codes:
		for plan in ["balanced"] + PreSeason.DRILL_PLANS:
			rows.append("%s/%s/%d" % [c, plan, int(GameState.plan_known[c].get(plan, -1))])
	return ",".join(rows)


func _idles() -> String:
	var rows := []
	var codes: Array = GameState.plan_idle.keys()
	codes.sort()
	for c in codes:
		for plan in PreSeason.DRILL_PLANS:
			rows.append("%s/%s/%d" % [c, plan, int(GameState.plan_idle[c].get(plan, -1))])
	return ",".join(rows)


func _press_on() -> void:
	var guard := 0
	while GameState.preseason_active() and guard < 12:
		guard += 1
		GameState.preseason_advance()


func _roll() -> void:
	if GameState.begin_intake_draft():
		var d: Draft = GameState.draft
		var guard := 0
		while not d.is_finished() and guard < 5000:
			guard += 1
			var c: Dictionary = d._best_ai_pick(d.current_club())
			if c.is_empty() or not d._draft_pick(d.current_club(), c):
				d._skip_current_pick()
		GameState.finish_intake_draft()
	else:
		GameState.start_next_season()


func _finish_season() -> void:
	while not GameState.season.is_season_over():
		GameState.advance()
	GameState.open_offseason()


## Two real sides with the squads' familiarity as given ({} = plain).
func _sim(known0: Dictionary, known1: Dictionary, plan0: String, plan1: String, seed_ := 77) -> MatchSim:
	var a := Squad.new("A", GameDB.club_list("FRE"), true, "FRE")
	var b := Squad.new("B", GameDB.club_list("MEL"), false, "MEL")
	a.plan_know = known0
	b.plan_know = known1
	var sim := MatchSim.new(a, b, seed_)
	sim.set_tactics(0, {"gameplan": plan0})
	sim.set_tactics(1, {"gameplan": plan1})
	return sim


# ---------------------------------------------------------------------------
func _test_switch_off() -> void:
	PreSeason.reload()
	_career(false)
	# The switch ships ON since 1.0.1; this test forces it off to prove the game
	# without the pre-season is the game as it was.
	Features.set_on("preseason", false)
	_check(not Features.on("preseason"), "The pre-season switch can be turned off for a run")
	GameState.set_club_plan("attacking")
	GameState._refresh_coach_tactics()
	_check(GameState.plan_known.is_empty() and CoachEffects.known.is_empty()
			and GameState.plan_known_line("attacking") == "" and not GameState.plan_known_shown()
			and GameState.plan_level(CLUB, "attacking") == PreSeason.WELL,
			"Switched off, no plan has a familiarity record and none is shown")
	var sq := Squad.new("A", GameDB.club_list("FRE"), true, "FRE")
	CoachEffects.apply(sq)
	_check(sq.plan_know.is_empty(), "...so the side's plans work as written")
	var plain := _sim({}, {}, "attacking", "defensive").run()
	var again := _sim({}, {}, "attacking", "defensive").run()
	_check(plain["score"] == again["score"] and str(plain["goals"]) == str(again["goals"]),
			"...and a same-seed match is the match it always was")
	var well := PreSeason.familiar_mult(PreSeason.WELL)
	var ok := _sim({"attacking": well, "defensive": well}, {}, "attacking", "defensive").run()
	_check(plain["score"] == ok["score"] and str(plain["goals"]) == str(ok["goals"]),
			"A plan known well plays exactly as today")
	GameState.save_career()
	var saved := CareerSave.read(GameState.save_path)
	_check(not saved.has("plan_known") and not saved.has("plan_idle"), "...and the save holds no familiarity")
	for i in range(3):
		GameState.advance()
	_check(GameState.plan_known.is_empty() and GameState.plan_idle.is_empty(),
			"Three rounds on, still nothing kept: the game is as it was")
	Features.set_on("preseason", true)


func _test_rules() -> void:
	PreSeason.reload()
	_check(PreSeason.LEVELS == ["barely", "partly", "well"] and PreSeason.WELL == 2, "Three levels, well on top")
	var start := PreSeason.start_levels("defensive")
	_check(int(start["defensive"]) == 2 and int(start["balanced"]) == 2 and int(start["attacking"]) == 1
			and int(start["contest"]) == 1 and int(start["through_stars"]) == 1,
			"A club starts knowing its usual plan and Balanced well, the others partly")
	var slipped := PreSeason.slip_levels(start)
	_check(int(slipped["defensive"]) == 1 and int(slipped["attacking"]) == 0 and int(slipped["balanced"]) == 2,
			"The off-season slips every plan a step but Balanced")
	var twice := PreSeason.slip_levels(slipped)
	_check(int(twice["attacking"]) == 0 and int(twice["defensive"]) == 0 and int(twice["balanced"]) == 2,
			"...and nothing slips below barely")
	_check(PreSeason.clean_drills(["contest", "bogus", "contest", "attacking", "defensive"]) == ["contest", "attacking"],
			"Drills are real plans, once each, at most two")
	_check(PreSeason.clean_drills(["balanced"]).is_empty() and PreSeason.clean_drills("x").is_empty(),
			"Balanced is not drilled, and bad input is nothing")
	var one := PreSeason.drill_credit([["solid", "running"], ["solid", "plan", ["contest"]], ["solid", "skills"]])
	_check(is_equal_approx(float(one["contest"]), 2.0) and PreSeason.drill_steps(2.0) == 1 and PreSeason.drill_steps(1.99) == 0,
			"Two weeks drilling one plan is one step")
	var two := PreSeason.drill_credit([["solid", "plan", ["contest", "attacking"]], ["solid", "skills"], ["solid", "skills"]])
	_check(is_equal_approx(float(two["contest"]), 1.5) and PreSeason.drilled_level(0, 1.5) == 0,
			"Two plans in a three-week block share it: neither moves up")
	var both := PreSeason.drill_credit([["solid", "plan", ["contest", "attacking"]], ["solid", "plan", ["contest", "attacking"]],
			["solid", "skills"]])
	_check(PreSeason.drilled_level(0, float(both["contest"])) == 1 and PreSeason.drilled_level(1, 3.0) == 2
			and PreSeason.drilled_level(2, 9.0) == 2,
			"Two blocks on a pair add up, and well is the top")
	_check(PreSeason.valid_block("solid", "plan") and PreSeason.focuses().has("plan"), "Game plan is a block focus")
	var norm := PreSeason._blocks([["heavy", "plan", ["defensive", "zzz"]], ["light", "skills"], ["solid", "plan"]])
	_check(norm[0] == ["heavy", "plan", ["defensive"]] and norm[1] == ["light", "skills"]
			and norm[2] == ["solid", "plan", []],
			"A block keeps the plans it drills and a block of anything else is two words as before")
	_check(is_equal_approx(PreSeason.work("solid", "plan", "running"), 0.5)
			and is_equal_approx(PreSeason.work("solid", "plan", "skills"), 0.5),
			"A Game plan block gives running and skills the half-share a block not on them gives")
	var ai := PreSeason.with_plan_block(PreSeason.ai_blocks("contending"), "contending", "defensive")
	_check(ai[2] == ["solid", "plan", ["defensive"]] and ai[0] == ["heavy", "running"],
			"An AI club drills its usual plan in the block its phase sets aside")
	_check(PreSeason.with_plan_block(PreSeason.ai_blocks("building"), "building", "balanced") == PreSeason.ai_blocks("building"),
			"...and one with no usual plan trains as it did")
	_check(PreSeason.familiar_mult(2) == 1.0 and PreSeason.familiar_mult(1) < 1.0
			and PreSeason.familiar_mult(0) < PreSeason.familiar_mult(1) and PreSeason.familiar_mult(0) > 0.0,
			"Knowing a plan less gives less of it, never nothing")


func _test_words() -> void:
	PreSeason.reload()
	_check(PreSeason.known_line(2) == "Plan fluency: high" and PreSeason.known_line(1) == "Plan fluency: medium"
			and PreSeason.known_line(0) == "Plan fluency: low", "The three lines, in the director's words")
	var g := PreSeason.gain_line("solid", "plan", 1, ["defensive"])
	var c := PreSeason.cost_line("solid", "plan", 1)
	_check(g.begins_with("Fluency in Defensive press") and "step" in g, "A Game plan block says what it drills and what that gains")
	_check(c == "Running and Skills work both get half the time.",
			"...and costs the time its running and skills would have had")
	var pair := PreSeason.gain_line("solid", "plan", 0, ["contest", "attacking"])
	_check("Win contest" in pair and "Attack corridor" in pair and "sharing" in pair, "Two plans: both named, the weeks shared")
	_check(PreSeason.cost_line("heavy", "plan", 2).begins_with("A risk of soft-tissue injuries")
			and "half the time" in PreSeason.cost_line("heavy", "plan", 2),
			"A Heavy Game plan block still costs its injury risk, and the time")
	_check(PreSeason.cost_line("solid", "running", 0) == "" and PreSeason.cost_line("light", "skills", 0) == "Half the Running and half the Skills work of a Solid block."
			and PreSeason.cost_line("light", "plan", 0) == "Half the Running and Skills work of a Solid block on the plan.",
			"The other blocks cost what they did")
	_check(PreSeason.gain_line("light", "plan", 2, ["contest"]).begins_with("Fresh legs"),
			"A Light Game plan block keeps the fresh legs it gains")


func _test_match_effect() -> void:
	PreSeason.reload()
	var partly := PreSeason.familiar_mult(1)
	var barely := PreSeason.familiar_mult(0)
	var known := _sim({}, {}, "attacking", "balanced")
	var part := _sim({"attacking": partly}, {}, "attacking", "balanced")
	var bare := _sim({"attacking": barely}, {}, "attacking", "balanced")
	var g0 := known._pv(0, "goal")
	var g1 := part._pv(0, "goal")
	var g2 := bare._pv(0, "goal")
	_check(g0 > g1 and g1 > g2 and g2 > 1.0 - 0.1,
			"A plan known less gives less of its upside, step by step (goal %.4f > %.4f > %.4f)" % [g0, g1, g2])
	_check(is_equal_approx(known._pv(0, "pace"), bare._pv(0, "pace"))
			and is_equal_approx(known._pv(0, "clangers"), bare._pv(0, "clangers")),
			"...but what the plan gives up (legs, clangers) does not move")
	var other := _sim({"defensive": barely}, {}, "attacking", "balanced")
	_check(is_equal_approx(other._pv(0, "goal"), g0), "Knowing another plan badly does not touch the one being run")
	var opp := _sim({}, {"defensive": barely}, "attacking", "defensive")
	var opp0 := _sim({}, {}, "attacking", "defensive")
	_check(opp._pv(1, "press") < opp0._pv(1, "press") and is_equal_approx(opp._pv(0, "goal"), opp0._pv(0, "goal")),
			"The press known barely presses less, and leaves the other side alone")
	_check(is_equal_approx(_sim({"balanced": barely}, {}, "balanced", "balanced")._pv(0, "goal"), 1.0),
			"Balanced has no upside to lose")
	var diff := 0.0
	var n := 24
	for s in range(n):
		var ra := _sim({}, {}, "contest", "balanced", 900 + s).run()
		var rb := _sim({"contest": barely}, {}, "contest", "balanced", 900 + s).run()
		diff += float(int(ra["score"][0]) - int(ra["score"][1])) - float(int(rb["score"][0]) - int(rb["score"][1]))
	_check(diff / float(n) > -3.0, "Over %d matches, knowing a plan well is not worse than barely (margin %+.1f)" % [n, diff / float(n)])


func _test_drilling() -> void:
	PreSeason.reload()
	_career(false)
	GameState.set_club_plan("attacking")
	GameState.open_preseason()
	_check(GameState.plan_known.size() == GameState.season.clubs.size(), "Every club has a record from the first pre-season")
	_check(GameState.plan_level(CLUB, "attacking") == 2 and GameState.plan_level(CLUB, "contest") == 1
			and GameState.plan_level(CLUB, "balanced") == 2,
			"A new career: the plan you play and Balanced known well, the others partly")
	_check(GameState.preseason_blocks()[2] == ["solid", "skills"], "The first year has nothing to slip, so no default drill")
	_check(GameState.set_preseason_block(0, "solid", "plan"), "A block can be set to Game plan")
	_check(GameState.preseason_drills(0) == ["attacking"], "...drilling your usual plan until you say otherwise")
	_check(GameState.set_preseason_drills(0, ["contest", "controlled", "defensive"])
			and GameState.preseason_drills(0) == ["contest", "controlled"], "...and no more than two plans")
	_check(not GameState.set_preseason_drills(1, ["contest"]), "A block not on Game plan drills nothing")
	_check(not GameState.set_preseason_drills(0, ["balanced"]) and GameState.preseason_drills(0) == ["contest", "controlled"],
			"...and Balanced cannot be drilled")
	_check(GameState.plan_level_after_drills("contest") == 1 and GameState.plan_level_after_drills("through_stars") == 1,
			"Three weeks shared by two plans moves neither (the page says so before it is trained)")
	_check(GameState.set_preseason_drills(0, ["contest"]) and GameState.plan_level_after_drills("contest") == 2,
			"...but three weeks on one plan lifts it to well")
	GameState.set_preseason_block(1, "solid", "plan")
	GameState.set_preseason_drills(1, ["through_stars"])
	_check(GameState.plan_level_after_drills("through_stars") == 2, "Two weeks on a plan lifts it a step")
	GameState.preseason_step_week()
	_check(GameState.plan_level(CLUB, "contest") == 1, "A plan is not known better until the pre-season is done")
	_check(not GameState.set_preseason_drills(0, ["controlled"]) and GameState.preseason_drills(0) == ["contest"],
			"...and a block that has started cannot be changed")
	_press_on()
	_check(GameState.plan_level(CLUB, "contest") == 2 and GameState.plan_level(CLUB, "through_stars") == 2
			and GameState.plan_level(CLUB, "controlled") == 1 and GameState.plan_level(CLUB, "attacking") == 2,
			"Drilled plans are known well by Round 1; the rest are as they were")
	var news := ""
	for n in GameState.news:
		news += str(n).to_lower() + " "
	_check("fluency in win contest is now high" in news, "...and the club's news says which")
	GameState._refresh_coach_tactics()
	var sq := Squad.new("A", GameDB.club_list(CLUB), true, CLUB)
	CoachEffects.apply(sq)
	_check(CoachEffects.table.is_empty() or not sq.plan_know.is_empty(), "A match squad carries what its club knows")


func _test_ai() -> void:
	PreSeason.reload()
	_career(false)
	GameState.open_preseason()
	var drills := 0
	var well := 0
	var clubs := 0
	for club in GameState.season.clubs:
		var code := str(club)
		if code == CLUB:
			continue
		clubs += 1
		var usual := GameState._usual_plan(code)
		var has := false
		for b in GameState.preseason_blocks(code):
			if str(b[1]) == "plan":
				has = true
				drills += 1
		if usual == "balanced":
			well += 1 if not has else 0
		else:
			well += 1 if has and GameState.plan_level(code, usual) == 2 else 0
	_check(well == clubs, "Every AI club that has a usual plan drills it, and knows it well; the rest train as before")
	_check(drills > 0, "...and some do")
	# The usual plan each club opened its first pre-season on, and the plan it
	# drills in the second.
	var before := {}
	for club in GameState.season.clubs:
		before[str(club)] = GameState._usual_plan(str(club))
	_press_on()
	_finish_season()
	# What the season did to each record is the fade test's business: here every
	# club is known well on the plan it opened on, so the off-season is on its own.
	for code in before:
		if PreSeason.DRILL_PLANS.has(str(before[code])):
			GameState.plan_known[code][before[code]] = PreSeason.WELL
	_roll()
	var drilled := {}
	for club in GameState.season.clubs:
		for b in GameState.preseason_blocks(str(club)):
			if str(b[1]) == "plan" and str(club) != CLUB:
				drilled[str(club)] = str((b[2] as Array)[0])
	_press_on()
	var back := 0
	var kept := 0
	for code in drilled:
		if str(before.get(code, "")) != str(drilled[code]):
			continue
		kept += 1
		back += 1 if GameState.plan_level(code, str(drilled[code])) == 2 else 0
	_check(kept > 0 and back == kept,
			"A year on, an AI club that still plays the same usual plan has slipped and drilled it back to well (%d of %d)" % [back, kept])


func _test_off_season_and_fade() -> void:
	PreSeason.reload()
	_career(false)
	GameState.set_club_plan("attacking")
	GameState.open_preseason()
	GameState.plan_known[CLUB]["contest"] = 1
	_press_on()
	PreSeason.data()["fade_rounds"] = 3
	for i in range(2):
		GameState.advance()
	_check(GameState.plan_level(CLUB, "contest") == 1, "Two rounds unplayed: a plan has not faded yet")
	GameState.advance()
	_check(GameState.plan_level(CLUB, "contest") == 0, "...but after the third it knows it a step less")
	_check(GameState.plan_level(CLUB, "attacking") == 2, "...while the plan played every week stays well")
	for i in range(4):
		GameState.advance()
	_check(GameState.plan_level(CLUB, "contest") == 0, "...and nothing fades below barely")
	GameState.plan_known[CLUB]["defensive"] = 2
	GameState.plan_idle[CLUB]["defensive"] = 0
	GameState.set_club_plan("defensive")
	for i in range(4):
		GameState.advance()
	_check(GameState.plan_level(CLUB, "defensive") == 2, "A plan played in matches keeps its place")
	_check(GameState.plan_level(CLUB, "attacking") <= 1, "...and the one put down fades")
	var snapshot := _levels()
	var idle := _idles()
	GameState.save_career()
	var saved := CareerSave.read(GameState.save_path)
	_check(saved.has("plan_known") and saved.has("plan_idle"), "With the switch on, the save holds the record")
	GameState.load_career()
	_check(_levels() == snapshot and _idles() == idle, "...and it comes back as saved")
	PreSeason.reload()
	GameState.set_club_plan("controlled")
	_finish_season()
	GameState.plan_known[CLUB]["controlled"] = 2
	GameState.plan_known[CLUB]["through_stars"] = 1
	GameState.plan_known[CLUB]["defensive"] = 2
	_roll()
	_check(GameState.plan_level(CLUB, "through_stars") == 0 and GameState.plan_level(CLUB, "defensive") == 1
			and GameState.plan_level(CLUB, "balanced") == 2,
			"Over the off-season every plan slips a step, and nothing but Balanced is safe")
	_check(GameState.preseason_blocks()[2] == ["solid", "plan", ["controlled"]],
			"...and the plan you play is drilled in the last block unless you say otherwise")
	_press_on()
	_check(GameState.plan_level(CLUB, "controlled") == 2, "...which brings it back to well")


func _test_old_saves() -> void:
	PreSeason.reload()
	_career(false)
	GameState.set_club_plan("contest")
	for i in range(2):
		GameState.advance()
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("plan_known")
	state.erase("plan_idle")
	CareerSave.write(state, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career() and GameState.plan_known.is_empty(), "A save from before familiarity loads, with no record")
	GameState.replay_seed = SUITE_SEED
	GameState.advance()
	_check(GameState.plan_known.size() == GameState.season.clubs.size(), "...and the next round gives every club one")
	_check(GameState.plan_level(CLUB, "contest") == 2 and GameState.plan_level(CLUB, "attacking") == 1
			and GameState.plan_level(CLUB, "balanced") == 2,
			"...with the plan you play known well and the rest partly")
	var sane := true
	for club in GameState.plan_known:
		for plan in GameState.plan_known[club]:
			var l := int(GameState.plan_known[club][plan])
			sane = sane and l >= 0 and l <= 2
	_check(sane, "...every level in range")
	GameState.save_career()
	var bad := CareerSave.read(GameState.save_path)
	bad["plan_known"] = {CLUB: {"contest": 9, "attacking": -4, "junk": "x"}, "BAD": 5}
	bad["plan_idle"] = {CLUB: "x"}
	CareerSave.write(bad, GameState._save_meta(), GameState.save_path)
	GameState.load_career()
	_check(GameState.plan_level(CLUB, "contest") == 2 and GameState.plan_level(CLUB, "attacking") == 0,
			"A damaged record is clamped, not trusted")
	Features.set_on("preseason", false)
	GameState.load_career()
	GameState._refresh_coach_tactics()
	_check(CoachEffects.known.is_empty() and GameState.plan_level(CLUB, "attacking") == PreSeason.WELL,
			"Switched off again, the record is left alone and unread")
	Features.set_on("preseason", true)


func _test_screens() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	PreSeason.reload()
	_career(false)
	GameState.set_club_plan("attacking")
	GameState.open_preseason()
	GameState.set_setting("seen_weekly_loop_intro", true)
	var scene: Control = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene", "The pre-season opens")
	var drill_row := scene.find_child("Drill0", true, false) as Control
	_check(drill_row != null and not drill_row.visible, "The drill choice stays out of the way until a block is set to Game plan")
	var focus := scene.find_child("Focus0_plan", true, false) as Button
	_check(focus != null and focus.text == "Game plan", "A block's focus offers Game plan")
	_check(await _tap(focus, "Game plan on block 1"), "A finger sets block 1 to Game plan")
	_check(GameState.preseason_blocks()[0][1] == "plan" and drill_row.visible, "...and the drill choice appears")
	_check(_label(scene, "BlockGain_0").begins_with("Fluency in Attack corridor"), "...the gain says what it drills")
	_check("half the time" in _label(scene, "BlockCost_0"), "...and the cost, the time")
	var contest := scene.find_child("Drill0_contest", true, false) as Button
	_check(contest != null and contest.text == "Win contest\nmedium", "Each plan says how well the side knows it")
	_check(await _tap(contest, "Win contest to drill"), "A finger adds a plan to drill")
	_check(GameState.preseason_drills(0) == ["attacking", "contest"], "...two at most")
	var through := scene.find_child("Drill0_through_stars", true, false) as Button
	_check(await _tap(through, "a third plan"), "A third takes the first's place")
	_check(GameState.preseason_drills(0) == ["contest", "through_stars"], "...so the block drills the last two chosen")
	_check(contest.text == "Win contest\nmedium", "Three weeks shared by two plans: neither is lifted")
	await _tap(scene.find_child("Drill0_through_stars", true, false) as Button, "let a plan go")
	_check(GameState.preseason_drills(0) == ["contest"], "A tap on a chosen plan lets it go")
	_check(contest.text == "Win contest\nmedium, high by Round 1", "...and with one plan drilled the button says where it ends up")
	_check((scene.find_child("Drill0_attacking", true, false) as Button).text == "Attack corridor\nhigh",
			"The plan you play has high fluency")
	_check(_fits(scene, 390.0), "...and nothing runs off a phone's width")
	GameState.preseason_sim_to_round1()
	GameState.plan_known["FRE"]["controlled"] = 0
	var tiles := PlanTiles.grid(2, [], [])
	tree.root.add_child(tiles)
	await _frames(tree, 2)
	var t_c := tiles.find_child("ClubPlan_controlled", true, false)
	var t_a := tiles.find_child("ClubPlan_attacking", true, false)
	_check(t_c != null and (t_c.find_child("Known", true, false) as Label).text == "Plan fluency: low"
			and (t_a.find_child("Known", true, false) as Label).text == "Plan fluency: high",
			"The pre-match plan tiles carry the same line, in the same words")
	tiles.queue_free()
	Features.set_on("preseason", false)
	var off := PlanTiles.grid(2, [], [])
	tree.root.add_child(off)
	await _frames(tree, 2)
	_check(off.find_child("Known", true, false) == null, "Switched off, no tile mentions it")
	off.queue_free()
	Features.set_on("preseason", true)
	# The first break of a coached match: the plan call says it, in full ink.
	GameState.plan_known[CLUB]["through_stars"] = 0
	GameState.plan_known[CLUB]["defensive"] = 1
	_check(GameState.prepare_interactive_match(), "A match is ready to coach")
	Router.stack = ["main"]
	Router.go("match")
	await _frames(tree, 40)
	var match_scene := tree.current_scene as Control
	var note := match_scene.find_child("PlanKnown", true, false) as Label if match_scene != null else null
	var pick_stars := match_scene.find_child("PlanPicker_through_stars", true, false) as Button if match_scene != null else null
	_check(note != null and pick_stars != null, "The break has the plan call and a line for how well the side knows it")
	if note != null and pick_stars != null:
		_check(note.text == "Plan fluency: high", "...on the plan the side opens on: " + note.text)
		_check(await _tap(pick_stars, "Through stars at the break"), "A finger picks another plan")
		_check(note.text == "Plan fluency: low" and note.visible and note.get_theme_color("font_color") == UiKit.TEXT,
				"...and the line follows it, at full strength: " + note.text)
		await _tap(match_scene.find_child("PlanPicker_defensive", true, false) as Button, "Defensive press at the break")
		_check(note.text == "Plan fluency: medium", "...in the same three words: " + note.text)


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


func _open(tree: SceneTree) -> Control:
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	return tree.current_scene as Control


func _label(scene: Node, node_name: String) -> String:
	var l := scene.find_child(node_name, true, false) as Label if scene != null else null
	return l.text if l != null else ""


func _fits(scene: Control, width: float) -> bool:
	var ok := true
	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text == "":
			continue
		var r := l.get_global_rect()
		if r.position.x < -0.5 or r.end.x > width + 0.5:
			ok = false
			push_error("Off the screen: %s (%s)" % [l.text, str(r)])
	return ok
