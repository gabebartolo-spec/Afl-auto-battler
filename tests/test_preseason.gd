extends RefCounted
## The pre-season (PreSeason.gd): the rules, the hand-over to the season
## fitness plan, development inside the season's limit, the same rules for AI
## clubs, its own dice, saves old and new, and the screens by real taps.
## Every season here is seeded.

const Tap := preload("res://tests/tap.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 4127
const CLUB := "FRE"


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	_test_switch_default()
	# Everything below is the feature itself: switched on for this suite.
	Features.set_on("preseason", true)
	_test_rules()
	_test_words()
	_test_hand_over()
	_test_flow()
	_test_determinism()
	_test_own_dice()
	_test_sim_to_round_one()
	_test_ai_parity()
	_test_training_injuries()
	_test_intra_club()
	_test_old_saves()
	await _test_screens()
	await _test_story_stop()
	await _test_draft_card()
	await _test_switch_off()
	PreSeason.reload()
	Features.clear("preseason")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Preseason tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


## A seeded career at `club`; with `open`, its first season starts with a
## pre-season, as a new career does in the game.
func _career(open := true, club := CLUB) -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season(club, GameDB.club_list(club))
	if open:
		GameState.open_preseason()


## Press on through every stop to Round 1 (the intra-club match is simmed on
## the sides and invitations as they stand, as pressing on does).
func _press_on() -> bool:
	var guard := 0
	while GameState.preseason_active() and guard < 12:
		guard += 1
		GameState.preseason_advance()
	return not GameState.preseason_active()


func _set_blocks(blocks: Array) -> bool:
	var ok := true
	for i in range(blocks.size()):
		ok = GameState.set_preseason_block(i, str(blocks[i][0]), str(blocks[i][1])) and ok
	return ok


## Everything a season leaves behind that a player could see: results, every
## listed player's rating, XP and injury, each club's plan and base.
func _sig() -> String:
	var parts := []
	for res in GameState.season_log:
		parts.append("%s-%s:%d-%d" % [str(res["home"]), str(res["away"]),
				int(res["score"][0]), int(res["score"][1])])
	for code in GameState.season.clubs:
		var rows := []
		for p in GameState.season.lists[code]:
			rows.append("%s/%d/%d/%d/%d" % [str(p["id"]), int(p["overall"]), int(p.get("xp", 0)),
					int(p.get("injury_weeks", 0)), int(round(float(p.get("workload", 0.0)) * 10.0))])
		rows.sort()
		var rec: Dictionary = GameState.conditioning.get(code, {})
		parts.append("%s[%s|%s]%s" % [str(code), Conditioning.plan_at(rec, 0),
				Conditioning.base_of(rec), ",".join(rows)])
	for inj in GameState.preseason_injuries():
		parts.append("hurt:%s/%s/%d/%d/%s" % [str(inj["club"]), str(inj["id"]), int(inj["week"]),
				int(inj["weeks"]), str(inj["kind"])])
	return str(hash("\n".join(parts)))


func _play(rounds: int) -> void:
	for i in range(rounds):
		GameState.advance()


func _mean_rating() -> float:
	var total := 0.0
	var n := 0
	for code in GameState.season.clubs:
		for p in GameState.season.lists[code]:
			total += float(p["overall"])
			n += 1
	return total / float(maxi(1, n))


func _injured() -> int:
	var n := 0
	for code in GameState.season.clubs:
		n += Injuries.injured(GameState.season.lists[code]).size()
	return n


# ---------------------------------------------------------------------------
func _test_rules() -> void:
	PreSeason.reload()
	_check(PreSeason.weeks() == 8 and PreSeason.block_count() == 3
			and PreSeason.block_of_week(1) == 0 and PreSeason.block_of_week(3) == 0
			and PreSeason.block_of_week(4) == 1 and PreSeason.block_of_week(5) == 1
			and PreSeason.block_of_week(6) == 2 and PreSeason.block_of_week(7) == 2
			and PreSeason.block_of_week(8) == -1,
			"Eight weeks: blocks are weeks 1-3, 4-5 and 6-7, and week 8 is a quiet week")
	_check(PreSeason.work("solid", "running", "running") == 1.0
			and PreSeason.work("solid", "running", "skills") == 0.5
			and PreSeason.work("heavy", "skills", "skills") == 1.5
			and PreSeason.work("light", "skills", "running") == 0.25,
			"The focus gets the full week and the other area half; Heavy is half as much again, Light half")
	_check(PreSeason.week_xp("solid", "skills") == int(PreSeason.tune("skills_week_xp"))
			and PreSeason.week_xp("solid", "running") * 2 == PreSeason.week_xp("solid", "skills")
			and PreSeason.week_xp("heavy", "skills") > PreSeason.week_xp("solid", "skills"),
			"A skills week pays its development in full, a running week half of it")
	var all_run := [["solid", "running"], ["solid", "running"], ["solid", "running"]]
	var all_skill := [["solid", "skills"], ["solid", "skills"], ["solid", "skills"]]
	_check(PreSeason.base_band(PreSeason.planned_run(all_run)) == "strong"
			and PreSeason.base_band(PreSeason.planned_run(all_skill)) == "thin"
			and PreSeason.base_band(PreSeason.planned_run(PreSeason.default_blocks())) == "sound",
			"All running is a strong base, none a thin one, and the plan a coach opens on is sound")
	_check(PreSeason.base_band(PreSeason.planned_run([["light", "running"], ["light", "running"], ["light", "running"]])) == "thin",
			"A Light pre-season leaves the base thin even with running as the focus")
	var lean := PreSeason.planned_run(PreSeason.ai_blocks("contending")) > PreSeason.planned_run(PreSeason.ai_blocks("building")) \
			and PreSeason.planned_run(PreSeason.ai_blocks("building")) > PreSeason.planned_run(PreSeason.ai_blocks("rebuilding"))
	_check(lean, "AI contenders lean to running and rebuilders to skills, with the rest between")
	_check(PreSeason.round_one_flag(all_run) == ""
			and PreSeason.round_one_flag([["heavy", "running"], ["heavy", "running"], ["solid", "running"]]) == ""
			and PreSeason.round_one_flag([["solid", "running"], ["solid", "running"], ["heavy", "skills"]]) == "heavy_legs"
			and PreSeason.round_one_flag([["solid", "running"], ["solid", "running"], ["light", "skills"]]) == "fresh",
			"Only the last block's load is still in the legs at Round 1")
	_check(not PreSeason.valid_block("brutal", "running") and not PreSeason.valid_block("solid", "yoga"),
			"A load or focus that is not on offer is refused")
	# The time trial.
	var list := []
	for i in range(12):
		list.append({"id": "t%02d" % i, "attr": {"durability": 40 + i * 4}})
	list[11]["injury_weeks"] = 3
	var a := PreSeason.trial(list, 7, 2027, CLUB)
	var b := PreSeason.trial(list, 7, 2027, CLUB)
	var both := false
	for id in a["best"]:
		both = both or (a["worst"] as Array).has(id)
	_check(a == b and (a["best"] as Array).size() == 5 and (a["worst"] as Array).size() == 3 and not both,
			"The time trial names the first five and the last three, nobody twice, the same on a replay")
	_check(not (a["best"] as Array).has("t11") and not (a["worst"] as Array).has("t11"),
			"An injured player sits the time trial out")
	_check(PreSeason.trial(list, 8, 2027, CLUB) != a or PreSeason.trial(list, 7, 2028, CLUB) != a,
			"Another career or another year runs a different time trial")
	var few := PreSeason.trial(list.slice(0, 6), 7, 2027, CLUB)
	_check((few["best"] as Array).size() == 5 and (few["worst"] as Array).size() == 1,
			"A short list still names nobody in both groups")


func _test_words() -> void:
	var clean := true
	var said := {}
	for load in PreSeason.loads():
		for focus in PreSeason.focuses():
			for i in range(PreSeason.block_count()):
				var gain := PreSeason.gain_line(str(load), str(focus), i)
				var cost := PreSeason.cost_line(str(load), str(focus), i)
				clean = clean and gain != "" and (cost != "") == (str(load) != "solid" or str(focus) == "plan")
				for line in [gain, cost]:
					var low: String = line.to_lower()
					clean = clean and not line.contains("%") and not line.contains("{") \
							and not line.contains("XP") and not line.contains("x1") \
							and not low.contains("ticks over") and not low.contains("of work") \
							and not low.contains("sessions") and not low.contains("quarter") \
							and not low.begins_with("three weeks") and not low.begins_with("two weeks") \
							and not low.begins_with("the last")
				said["%s|%s|%d" % [load, focus, i]] = gain + " / " + cost
	_check(clean, "Every load and focus says what it gains in a coach's words: no sums, no engine terms, the block's weeks not said again, and a cost only when there is one")
	_check(said["heavy|running|2"] != said["heavy|running|0"]
			and said["heavy|running|2"].contains("Round 1")
			and said["heavy|running|0"].contains("risk of soft-tissue injuries in these weeks")
			and not said["heavy|running|0"].contains("Round 1")
			and said["light|skills|2"] != said["light|skills|0"]
			and said["light|skills|2"].contains("Round 1"),
			"A Heavy block says its risk of soft-tissue injuries; a heavy or light last block also says what it does to Round 1")
	_check(said["solid|running|0"] != said["solid|skills|0"]
			and said["solid|running|0"].contains("fitness base")
			and said["solid|skills|0"].contains("develop")
			and PreSeason.cost_line("solid", "running", 0) == "",
			"Running says it builds the fitness base, skills that players develop, and a Solid block has no cost to show")
	# The words are true to the sizes in the data.
	_check(is_equal_approx(PreSeason.work("solid", "running", "skills"), 0.5 * PreSeason.work("solid", "running", "running"))
			and said["solid|running|0"].contains("half the time")
			and PreSeason.work("heavy", "running", "running") > PreSeason.work("solid", "running", "running")
			and PreSeason.work("heavy", "running", "skills") > PreSeason.work("solid", "running", "skills")
			and said["heavy|running|0"].contains("more skills work too")
			and is_equal_approx(PreSeason.work("light", "skills", "skills"), 0.5 * PreSeason.work("solid", "skills", "skills"))
			and is_equal_approx(PreSeason.work("light", "skills", "running"), 0.5 * PreSeason.work("solid", "skills", "running"))
			and said["light|skills|0"].contains("Half the running and half the skills work of a Solid block"),
			"The words match the data: the other area gets half, Heavy is more of both than Solid, Light half of both")
	_check(PreSeason.block_title(0) == "Weeks 1 to 3" and PreSeason.block_title(2) == "Weeks 6 to 7",
			"A block is named by its weeks")


func _rec(plan: String, base := "") -> Dictionary:
	var r := {"year": 2027, "changes": [[0, plan]], "offset": 0}
	if base != "":
		r["base"] = base
	return r


func _test_hand_over() -> void:
	PreSeason.reload()
	var level := ClubBudget.STANDARD
	# Sound is exactly the game without a base.
	var same := true
	for plan in Conditioning.PLANS:
		for w in range(Conditioning.LAST_WEEK + 1):
			same = same and Conditioning.actual(_rec(plan), w, level) == Conditioning.actual(_rec(plan, "sound"), w, level) \
					and Conditioning.legs(_rec(plan, "sound"), w, level) == Conditioning.actual(_rec(plan), w, level) \
					and Conditioning.base_curve(_rec(plan, "sound"), w) == 0.0 \
					and Conditioning.base_curve(_rec(plan), w) == 0.0
	_check(same, "A sound base, or none on the record, is the season fitness plan exactly as it was")
	_check(Conditioning.stamps(0.0, "steady", Conditioning.base_curve(_rec("steady"), 0)).is_empty(),
			"A steady club on a sound base still stamps nothing on a player")
	# Thin: underdone early, fading out, and a lower peak.
	var thin := _rec("steady", "thin")
	var fades := Conditioning.base_curve(thin, 0) < Conditioning.base_curve(thin, 3) \
			and Conditioning.base_curve(thin, 3) < 0.0 \
			and Conditioning.base_curve(thin, int(PreSeason.tune("thin_weeks"))) == 0.0 \
			and Conditioning.base_curve(thin, 20) == 0.0
	_check(fades and is_equal_approx(Conditioning.base_curve(thin, 0), -float(PreSeason.tune("thin_early"))),
			"A thin base leaves the side underdone in Round 1, less each week, and level again by round 7")
	var st_thin := Conditioning.stamps(0.0, "steady", Conditioning.base_curve(thin, 0))
	_check(float(st_thin.get("cond_drain", 1.0)) > 1.0 and float(st_thin.get("cond_cap", 0.0)) > 0.0
			and float(st_thin.get("cond_injury", 1.0)) > 1.0,
			"On a thin base a player tires sooner, has less in his legs and carries more soft-tissue risk in Round 1")
	var pw := int(Conditioning.PEAK_WEEK["peak"])
	_check(Conditioning.planned(_rec("peak", "thin"), pw) < Conditioning.planned(_rec("peak"), pw)
			and is_equal_approx(Conditioning.planned(_rec("peak", "thin"), pw), float(PreSeason.tune("thin_peak_share")))
			and Conditioning.planned(_rec("peak", "thin"), 5) < 0.0
			and Conditioning.planned(_rec("peak", "thin"), 5) == Conditioning.planned(_rec("peak"), 5),
			"A thin base lowers a planned peak and leaves the build before it as it was")
	# Strong: fresher early, the peak at its full height.
	var strong := _rec("steady", "strong")
	_check(Conditioning.base_curve(strong, 0) > Conditioning.base_curve(strong, 2)
			and Conditioning.base_curve(strong, 2) > 0.0
			and Conditioning.base_curve(strong, int(PreSeason.tune("strong_weeks"))) == 0.0,
			"A strong base holds the legs through the first month, then is level")
	var st_strong := Conditioning.stamps(0.0, "steady", Conditioning.base_curve(strong, 0))
	_check(float(st_strong.get("cond_drain", 1.0)) < 1.0 and float(st_strong.get("cond_injury", 1.0)) < 1.0
			and float(st_strong.get("cond_cap", 0.0)) <= 0.0,
			"On a strong base a player tires later and carries less soft-tissue risk in Round 1")
	_check(Conditioning.planned(_rec("peak", "strong"), pw) == Conditioning.planned(_rec("peak"), pw) * float(PreSeason.tune("strong_peak_share")),
			"A strong base reaches the planned peak's height")
	# Develop and manage lowers risk through managed loads; an underdone side
	# is still at more risk than a sound one on the same plan.
	var dev_sound := Conditioning.stamps(Conditioning.DEVELOP_LEVEL, "develop")
	var dev_thin := Conditioning.stamps(Conditioning.DEVELOP_LEVEL, "develop", Conditioning.base_curve(_rec("develop", "thin"), 0))
	_check(float(dev_thin["cond_injury"]) > float(dev_sound["cond_injury"])
			and float(dev_thin["cond_drain"]) > float(dev_sound["cond_drain"]),
			"A thin base costs a Develop and manage side too: more risk and heavier legs than the same plan on a sound base")
	_check(Conditioning.status_line(_rec("peak"), 0) == Conditioning.status_words(_rec("peak"), 0)
			and Conditioning.status_line(_rec("peak", "thin"), 0).ends_with("on a thin base")
			and Conditioning.status_line(_rec("steady", "strong"), 0).ends_with("on a strong base"),
			"The season plan's line names a thin or strong base in the same sentence, and says nothing new on a sound one")
	var span := int(PreSeason.tune("strong_weeks"))
	_check(Conditioning.status_line(_rec("steady", "strong"), span - 1).ends_with("on a strong base")
			and Conditioning.status_line(_rec("steady", "strong"), span) == Conditioning.status_words(_rec("steady"), span)
			and Conditioning.status_line(_rec("steady", "thin"), 20).ends_with("on a thin base"),
			"A strong base is named only while it holds the legs; a thin one all season, for the lower peak it leaves")
	_check(str(PreSeason.BASE_EFFECT["thin"]).contains("soft-tissue risk") and str(PreSeason.BASE_EFFECT["strong"]).contains("soft-tissue risk"),
			"Both a thin and a strong base say what they do to soft-tissue risk")
	_check(Conditioning.base_of({"base": "enormous"}) == "sound"
			and Conditioning.base_of(Conditioning.revise(_rec("steady", "strong"), 0, "peak")) == "strong",
			"An unknown base reads as sound, and changing the season plan keeps the base")


func _test_flow() -> void:
	PreSeason.reload()
	_career(false)
	_check(not GameState.preseason_active() and GameState.preseason_stop() == "",
			"Building a season by itself opens no pre-season (tools and tests start at Round 1)")
	_career()
	_check(GameState.preseason_active() and GameState.preseason_stop() == "plan" and GameState.preseason_week() == 0,
			"A new career starts at the pre-season plan, before week 1")
	_check(GameState.preseason_blocks() == PreSeason.default_blocks() and GameState.preseason_base() == "sound",
			"It opens on the default plan, heading for a sound base")
	var by_phase := true
	for code in GameState.season.clubs:
		if str(code) != CLUB:
			by_phase = by_phase and GameState.preseason_blocks(str(code)) == PreSeason.with_plan_block(
					PreSeason.ai_blocks(GameState._club_phase(str(code)), GameState._best22_age(str(code))),
					GameState._club_phase(str(code)), GameState._usual_plan(str(code)))
	_check(by_phase, "Every AI club runs the blocks its own situation calls for: its phase, and its age")
	var before := {}
	var ceilings := {}
	for p in GameState.my_list:
		before[str(p["id"])] = int(p["overall"])
		ceilings[str(p["id"])] = GameState.season_ceiling(p)
	_check(_set_blocks([["heavy", "running"], ["solid", "running"], ["heavy", "skills"]])
			and GameState.preseason_base() == "strong",
			"You set a load and a focus for each block, and the plan says the base it is heading for")
	_check(not GameState.set_preseason_block(0, "brutal", "running") and not GameState.set_preseason_block(5, "solid", "running"),
			"A load that does not exist, or a fourth block, is refused")
	_check(GameState.can_revise_fitness() and GameState.set_fitness_plan("peak"),
			"The season fitness plan is still yours to set in the pre-season")
	_check(GameState.preseason_advance() == "trial" and GameState.preseason_week() == 3
			and GameState.preseason_stop() == "trial",
			"Pressing on trains weeks 1 to 3 and stops at the time trial")
	var trial := GameState.preseason_trial()
	var named := true
	for id in (trial.get("best", []) as Array) + (trial.get("worst", []) as Array):
		named = named and not GameState.list_player(str(id)).is_empty()
	_check((trial.get("best", []) as Array).size() == 5 and (trial.get("worst", []) as Array).size() == 3 and named,
			"The time trial names five of your players at the front and three at the back")
	_check(not GameState.set_preseason_block(0, "light", "skills")
			and GameState.set_preseason_block(1, "solid", "skills")
			and GameState.set_preseason_block(1, "solid", "running"),
			"At the time trial the block already trained is closed and the ones to come can still change")
	_check(GameState.preseason_advance() == "intra" and GameState.preseason_week() == 5
			and GameState.preseason_stop() == "intra" and not GameState.intra_played(),
			"Pressing on from the time trial trains weeks 4 and 5 and stops at the intra-club match")
	_check(_press_on() and GameState.preseason_week() == 8 and GameState.season.round_index == 0,
			"Pressing on from there plays it, trains to week 8 and leaves Round 1 to play")
	_check(Conditioning.base_of(GameState.fitness_record(CLUB)) == "strong"
			and GameState.fitness_plan(CLUB) == "peak"
			and GameState.fitness_status_line().ends_with("on a strong base"),
			"The running work lands as one word on the season fitness record: a strong base")
	var heavy := true
	for p in GameState.my_list:
		heavy = heavy and bool(p.get("heavy_legs", false)) and not p.has("fresh")
	_check(heavy, "A Heavy last block leaves heavy legs for Round 1")
	var rose := 0
	var inside := true
	for p in GameState.my_list:
		var id := str(p["id"])
		rose += 1 if int(p["overall"]) > int(before[id]) else 0
		inside = inside and int(p["overall"]) <= maxi(int(before[id]), int(ceilings[id]))
	_check(rose > 0 and inside,
			"Skills work develops players (%d rose) and nobody passes the season's training limit" % rose)
	var ai_inside := true
	var bases := {}
	for code in GameState.season.clubs:
		if str(code) == CLUB:
			continue
		bases[Conditioning.base_of(GameState.fitness_record(str(code)))] = true
		_check_ai_base(str(code))
		for p in GameState.season.lists[code]:
			ai_inside = ai_inside and int(p["overall"]) <= GameState.season_ceiling(p) \
					and not p.has("heavy_legs") and not p.has("fresh")
	_check(ai_inside, "AI players stay inside the same training limit and carry no load from a Solid last block")
	_check(GameState.news.size() > 0 and str(GameState.news[0]["text"]).contains("strong fitness base"),
			"The news says the base the club takes into Round 1")
	GameState.advance()
	var cleared := true
	for code in GameState.season.clubs:
		for p in GameState.season.lists[code]:
			cleared = cleared and not p.has("heavy_legs") and not p.has("fresh")
	_check(cleared and GameState.season.round_index == 1, "After Round 1 the pre-season's heavy legs are spent")
	_check(GameState.preseason_advance() == "done" and not GameState.set_preseason_block(2, "solid", "skills"),
			"Once the season is under way the pre-season is closed")

	# A Light last block is the fresh week.
	_career()
	_set_blocks([["solid", "skills"], ["solid", "skills"], ["light", "skills"]])
	GameState.preseason_sim_to_round1()
	var fresh := true
	for p in GameState.my_list:
		fresh = fresh and bool(p.get("fresh", false)) and not p.has("heavy_legs")
	_check(fresh and Conditioning.base_of(GameState.fitness_record(CLUB)) == "thin"
			and GameState.fitness_status_line().ends_with("on a thin base"),
			"A Light last block is a fresh week for Round 1, and a pre-season without running is a thin base")
	var st: Dictionary = {}
	GameState._stamp_conditioning()
	st = GameState.my_list[0]
	_check(float(st.get("cond_drain", 1.0)) > 1.0 and float(st.get("cond_injury", 1.0)) > 1.0,
			"Your players carry the thin base into Round 1 through the season fitness stamps")

	# An injured player does no pre-season.
	_career()
	var hurt: Dictionary = GameState.my_list[0]
	hurt["injury_weeks"] = 12
	var xp0 := int(hurt.get("xp", 0))
	var ov0 := int(hurt["overall"])
	_set_blocks([["heavy", "skills"], ["heavy", "skills"], ["heavy", "skills"]])
	GameState.preseason_sim_to_round1()
	_check(int(hurt.get("xp", 0)) == xp0 and int(hurt["overall"]) == ov0,
			"An injured player gets no pre-season development")


func _check_ai_base(code: String) -> void:
	var want := PreSeason.base_band(PreSeason.planned_run(GameState.preseason_blocks(code)))
	if Conditioning.base_of(GameState.fitness_record(code)) != want:
		_check(false, "%s trained for a %s base and did not get it" % [code, want])


func _run_preseason(reload_at := -1) -> String:
	_career()
	_set_blocks([["heavy", "running"], ["solid", "skills"], ["light", "running"]])
	GameState.set_fitness_plan("fast")
	if reload_at < 0:
		GameState.preseason_advance()
		GameState.set_preseason_block(2, "solid", "skills")
		_press_on()
	else:
		var changed := false
		while GameState.preseason_active():
			if GameState.preseason_stop() == "trial":
				GameState.preseason["trial_seen"] = true
				if not changed:
					GameState.set_preseason_block(2, "solid", "skills")
					changed = true
			if GameState.preseason_stop() == "intra":
				GameState.sim_intra_match()
				GameState.preseason["intra"]["seen"] = true
			if GameState.preseason_stop() == "practice":
				GameState.sim_practice_match()
				GameState.preseason["practice"]["seen"] = true
			GameState.preseason_step_week()
			if GameState.preseason_week() == reload_at:
				GameState.save_career()
				GameState.load_career()
				GameState.replay_seed = SUITE_SEED
	return _sig()


func _test_determinism() -> void:
	PreSeason.reload()
	# A size big enough that the Heavy block here is sure to hurt someone, so
	# the injuries are part of what must replay.
	PreSeason.data()["heavy_week_injury"] = 0.1
	var a := _run_preseason()
	var trial_a := GameState.preseason_trial().duplicate(true)
	_play(3)
	var a_season := _sig()
	var b := _run_preseason()
	_check(a == b and GameState.preseason_trial() == trial_a,
			"The same seed and the same choices give the same pre-season")
	_check(GameState.preseason_injuries().size() > 0,
			"...training injuries among it (%d across the league)" % GameState.preseason_injuries().size())
	_play(3)
	_check(_sig() == a_season, "...and the same three rounds after it")
	# Saved and loaded in the middle of block 1 (after week 2) and of block 2
	# (after week 4): the rest replays identically.
	for at in [2, 4]:
		var c := _run_preseason(at)
		_check(c == a and GameState.preseason_trial() == trial_a,
				"Saved and loaded after week %d, mid-block, the pre-season finishes the same" % at)
		if at == 2:
			_play(3)
			_check(_sig() == a_season, "...and so do the three rounds after it")
	# Different choices are a different pre-season.
	_career()
	_set_blocks([["solid", "skills"], ["solid", "skills"], ["solid", "skills"]])
	GameState.preseason_sim_to_round1()
	_check(_sig() != a, "Different choices give a different pre-season")
	# A stop is neither skipped nor repeated by a reload.
	_career()
	GameState.preseason_advance()
	GameState.save_career()
	GameState.load_career()
	_check(GameState.preseason_stop() == "trial" and GameState.preseason_week() == 3
			and GameState.preseason_trial() == GameState.preseason.get("trial", {})
			and (GameState.preseason_trial().get("best", []) as Array).size() == 5,
			"Loaded at the time trial, the career is still at the time trial with the same names")
	_press_on()
	GameState.save_career()
	GameState.load_career()
	_check(not GameState.preseason_active() and GameState.preseason_stop() == "" and GameState.preseason_week() == 8,
			"Loaded after week 8, the pre-season is not run again")
	PreSeason.reload()


## The pre-season's draws are its own: with it on or off, the season's seed,
## fixture, first story card and next draft class are the same, and with its
## sizes at nothing the first rounds play out identically.
func _test_own_dice() -> void:
	PreSeason.reload()
	_career(false)
	var off := _dice()
	_career()
	GameState.preseason_sim_to_round1()
	var on := _dice()
	_check(on == off, "A pre-season moves no match, draft or story dice (season seed, fixture, card, class)")
	# Sizes at nothing: every base sound, no development.
	_career(false)
	_play(2)
	var plain := _sig()
	var data := PreSeason.data()
	data["skills_week_xp"] = 0
	data["base_thin_below"] = 0.0
	data["base_strong_from"] = 99.0
	data["heavy_week_injury"] = 0.0
	data["intra_xp_games"] = 0.0
	data["intra_injury_rate"] = 0.0
	data["practice_xp_games"] = 0.0
	data["practice_injury_rate"] = 0.0
	_career()
	GameState.preseason_sim_to_round1()
	_play(2)
	_check(_sig() == plain, "With its sizes at nothing, a pre-season leaves the first two rounds exactly as they were")
	PreSeason.reload()
	_career()
	GameState.preseason_sim_to_round1()
	_play(2)
	_check(_sig() != plain, "With its real sizes it changes them: the pre-season matters")


func _dice() -> String:
	var cards := []
	for c in GameState.week_events:
		cards.append(str((c as Dictionary).get("tid", "")))
	var klass := Prospects.generate_class(GameState.season_year + 1, GameState.career_seed)
	var ids := []
	for p in klass:
		ids.append("%s/%d" % [str(p["id"]), int(p.get("overall", 0))])
	return str(hash([GameState.season.seed, str(GameState.season.fixture), cards,
			GameState.season.next_seed(3), ids]))


func _test_sim_to_round_one() -> void:
	PreSeason.reload()
	_career()
	_set_blocks([["solid", "running"], ["heavy", "running"], ["solid", "skills"]])
	GameState.preseason_sim_to_round1()
	_check(not GameState.preseason_active() and GameState.preseason_week() == 8
			and GameState.preseason_stop() == "" and GameState.season.round_index == 0
			and (GameState.preseason_trial().get("best", []) as Array).size() == 5,
			"Sim to Round 1 runs all eight weeks on the settings in force and stops for nothing")
	_check(Conditioning.base_of(GameState.fitness_record(CLUB)) == PreSeason.base_band(
			PreSeason.planned_run([["solid", "running"], ["heavy", "running"], ["solid", "skills"]])),
			"...and the base is the one those settings train for")
	var simmed := _sig()
	_play(1)
	var simmed_r1 := _sig()
	# Playing a round with the pre-season still waiting does the same first.
	_career()
	_set_blocks([["solid", "running"], ["heavy", "running"], ["solid", "skills"]])
	_play(1)
	_check(_sig() == simmed_r1 and not GameState.preseason_active() and simmed != simmed_r1,
			"A round played with the pre-season still waiting runs it hands-off first: nothing is skipped")
	# From the time trial it finishes the rest.
	_career()
	_set_blocks([["solid", "running"], ["heavy", "running"], ["solid", "skills"]])
	GameState.preseason_advance()
	GameState.preseason_sim_to_round1()
	_check(_sig() == simmed, "Sim to Round 1 from the time trial ends where the whole sim does")


## AI clubs by the same rules, and the league's rating and injuries at Round 1
## with a pre-season and without. The numbers are printed for the director;
## the checks only hold the rules (inside the limit, no injuries from training).
func _test_ai_parity() -> void:
	PreSeason.reload()
	_career(false)
	var off_mean := _mean_rating()
	var off_inj := _injured()
	_play(1)
	var off_inj_r1 := _injured()
	_career()
	var start := {}
	for code in GameState.season.clubs:
		for p in GameState.season.lists[code]:
			start[str(p["id"])] = int(p["overall"])
	var open_mean := _mean_rating()
	GameState.preseason_sim_to_round1()
	var on_mean := _mean_rating()
	var on_inj := _injured()
	var most := 0
	var counts := {"thin": 0, "sound": 0, "strong": 0}
	var mine := 0.0
	var theirs := 0.0
	var their_n := 0
	for code in GameState.season.clubs:
		var gain := 0.0
		for p in GameState.season.lists[code]:
			var d := int(p["overall"]) - int(start[str(p["id"])])
			most = maxi(most, d)
			gain += float(d)
		gain /= float(maxi(1, (GameState.season.lists[code] as Array).size()))
		if str(code) == CLUB:
			mine = gain
		else:
			theirs += gain
			their_n += 1
			counts[Conditioning.base_of(GameState.fitness_record(str(code)))] += 1
	theirs /= float(maxi(1, their_n))
	_play(1)
	var on_inj_r1 := _injured()
	print("Pre-season parity (seed %d): league mean rating at Round 1 %.2f without, %.2f with (opened at %.2f); injured at Round 1 %d without, %d with; injured after Round 1 %d without, %d with; AI bases thin %d sound %d strong %d; mean rise a player: you %.2f, AI %.2f; biggest rise %d" % [
			SUITE_SEED, off_mean, on_mean, open_mean, off_inj, on_inj, off_inj_r1, on_inj_r1,
			int(counts["thin"]), int(counts["sound"]), int(counts["strong"]), mine, theirs, most])
	_check(is_equal_approx(open_mean, off_mean), "The league is rated the same when a pre-season opens as when none does")
	var soft: Array = PreSeason.tune("soft_tissue_kinds")
	var fair := true
	var in_training := 0
	var in_match := 0
	for inj in GameState.preseason_injuries():
		if str(inj.get("how", "")) == "intra":
			in_match += 1
			fair = fair and int(inj["week"]) == PreSeason.intra_week()
			continue
		if str(inj.get("how", "")) == "practice":
			in_match += 1
			fair = fair and int(inj["week"]) == PreSeason.practice_week()
			continue
		in_training += 1
		var blocks: Array = GameState.preseason_blocks(str(inj["club"]))
		fair = fair and soft.has(str(inj["kind"])) \
				and str(blocks[PreSeason.block_of_week(int(inj["week"]))][0]) == "heavy"
	_check(off_inj == 0 and fair and on_inj <= GameState.preseason_injuries().size(),
			"In training only a Heavy week hurts anyone, at any club, and only with a soft-tissue injury; the rest come from the intra-club and practice matches (%d in training, %d in the match, %d still out at Round 1)" % [
			in_training, in_match, on_inj])
	_check(on_mean >= off_mean and on_mean - off_mean < 1.0 and most <= GameState.SEASON_TRAIN_GAIN + 2,
			"A pre-season lifts the league's mean rating by under a point (%.2f to %.2f), nobody by more than the season limit" % [off_mean, on_mean])
	_check(theirs > 0.0 and absf(mine - theirs) < 0.5,
			"On the default plan your list develops like an AI club's (%.2f against %.2f a player)" % [mine, theirs])
	_check(int(counts["sound"]) > 0 and int(counts["strong"]) > 0,
			"AI clubs take different bases into the season by phase (thin %d, sound %d, strong %d)" % [
			int(counts["thin"]), int(counts["sound"]), int(counts["strong"])])


## A Heavy week is a gamble: each fit player's own roll for a soft-tissue
## injury, at every club alike, on the pre-season's own dice.
func _test_training_injuries() -> void:
	PreSeason.reload()
	var soft: Array = PreSeason.tune("soft_tissue_kinds")
	var p := {"id": "x1", "attr": {"durability": 50}}
	var data := PreSeason.data()
	_check(float(PreSeason.tune("heavy_week_injury")) > 0.0 and float(PreSeason.tune("heavy_week_injury")) < Injuries.BASE_CHANCE,
			"A Heavy week's risk is a size in the data, smaller than a match's")
	data["heavy_week_injury"] = 1.0
	var inj := PreSeason.training_injury(p, "heavy", 7, 2027, CLUB, 2)
	_check(not inj.is_empty() and soft.has(str(inj["kind"])) and int(inj["weeks"]) >= 1
			and inj == PreSeason.training_injury(p, "heavy", 7, 2027, CLUB, 2),
			"A training injury is a soft-tissue injury of the usual lengths, and the same roll on a replay")
	_check(PreSeason.training_injury(p, "solid", 7, 2027, CLUB, 2).is_empty()
			and PreSeason.training_injury(p, "light", 7, 2027, CLUB, 2).is_empty()
			and PreSeason.training_injury({"id": "x1", "injury_weeks": 2}, "heavy", 7, 2027, CLUB, 2).is_empty(),
			"Solid and Light weeks carry no risk, and a player already hurt is not hurt again")
	var hits := [0, 0]
	data["heavy_week_injury"] = 0.2
	for i in range(400):
		hits[0] += 0 if PreSeason.training_injury({"id": "s%d" % i, "attr": {"durability": 95}}, "heavy", 7, 2027, CLUB, 1).is_empty() else 1
		hits[1] += 0 if PreSeason.training_injury({"id": "s%d" % i, "attr": {"durability": 30}}, "heavy", 7, 2027, CLUB, 1).is_empty() else 1
	_check(hits[0] > 0 and hits[1] > hits[0] * 3 / 2,
			"A durable player is hurt less often in training than a fragile one (%d against %d in 400)" % [hits[0], hits[1]])
	var old := PreSeason.ai_blocks("contending", 30.0)
	var young := PreSeason.ai_blocks("contending", 24.0)
	var old_heavy := false
	for b in old:
		old_heavy = old_heavy or str(b[0]) == "heavy"
	_check(not old_heavy and str(young[0][0]) == "heavy" and str(PreSeason.ai_blocks("building", 24.0)[1][0]) == "heavy"
			and str(PreSeason.ai_blocks("rebuilding", 24.0)[0][0]) == "heavy",
			"AI clubs push by their situation: contenders, middle clubs and rebuilders each have a Heavy block, an older list none")

	# In a career, at a size big enough to be sure of some.
	_career()
	_set_blocks([["heavy", "skills"], ["solid", "skills"], ["solid", "skills"]])
	var news_before := GameState.news.size()
	GameState.preseason_step_week()
	var mine := 0
	var recorded := true
	var ai_heavy := 0
	var ai_solid := 0
	for row in GameState.preseason_injuries():
		var club := str(row["club"])
		var who: Dictionary = {}
		for q in GameState.season.lists[club]:
			if str(q["id"]) == str(row["id"]):
				who = q
		recorded = recorded and not who.is_empty() and int(who.get("injury_weeks", 0)) == int(row["weeks"]) \
				and str(who.get("injury_kind", "")) == str(row["kind"]) and soft.has(str(row["kind"])) and int(row["week"]) == 1
		if club == CLUB:
			mine += 1
		elif str(GameState.preseason_blocks(club)[0][0]) == "heavy":
			ai_heavy += 1
		else:
			ai_solid += 1
	_check(mine > 0 and recorded, "A Heavy week hurts some of your players, each recorded on him as a match injury is (%d)" % mine)
	_check(ai_heavy > 0 and ai_solid == 0,
			"AI clubs on a Heavy block run the same risk, and clubs on Solid none (%d, %d)" % [ai_heavy, ai_solid])
	var lines: Array = GameState.preseason_injury_lines()
	var first: Dictionary = {}
	for row in GameState.preseason_injuries():
		if str(row["club"]) == CLUB and first.is_empty():
			first = row
	var hurt: Dictionary = GameState.list_player(str(first.get("id", "")))
	_check(lines.size() == mine and str(lines[0]).contains(GameDB.player_display_name(hurt))
			and str(lines[0]).contains(str(first["kind"])) and GameState.news.size() >= news_before + mine
			and str(GameState.news[0]["text"]).contains("hurt in pre-season training")
			and not Ratings.available(hurt),
			"Each of yours is named in the usual injury words, is in the news, and is unavailable (%s)" % str(lines[0]))
	var was := int(first["weeks"])
	var xp_then := int(hurt.get("xp", 0))
	GameState.preseason_step_week()
	_check(int(hurt.get("injury_weeks", 0)) == was - 1 or (was == 1 and not hurt.has("injury_kind")),
			"A week of the pre-season is a week of his recovery")
	_check(was == 1 or int(hurt.get("xp", 0)) == xp_then, "While he is out he does no training")
	GameState.preseason["trial_seen"] = true
	GameState.preseason_sim_to_round1()
	var late: Dictionary = {}
	for row in GameState.preseason_injuries():
		if int(row["week"]) + int(row["weeks"]) > PreSeason.weeks() + 1:
			late = row
	if not late.is_empty():
		var out: Dictionary = {}
		for q in GameState.season.lists[str(late["club"])]:
			if str(q["id"]) == str(late["id"]):
				out = q
		_check(int(out.get("injury_weeks", 0)) > 0, "An injury longer than the weeks left keeps him out of Round 1")
	else:
		_check(true, "(no injury this seed ran past week 8)")
	# Solid all the way: nobody of yours is hurt.
	_career()
	GameState.preseason_sim_to_round1()
	_check(GameState.preseason_injury_lines().is_empty() and Injuries.injured(GameState.my_list).is_empty(),
			"A pre-season without a Heavy block hurts none of your players")
	PreSeason.reload()


func _pool_sig() -> String:
	var rows := []
	for p in GameState.draftee_pool:
		rows.append("%s/%d/%d/%d/%d/%s/%d" % [str(p["id"]), int(p["overall"]), int(p.get("potential", 0)), int(p.get("num", 0)),
				int(p.get("injury_weeks", 0)), str(hash(str(p.get("attr", {})))), int(p.get("xp", 0))])
	return str(hash(str(rows)))


func _to_intra() -> void:
	_career()
	GameState.preseason_advance()
	GameState.preseason_advance()


## The intra-club match: two sides of the club's own list, prospects from the
## coming National Draft filling the spots; what it leaves and what it never
## touches; the same rules for AI clubs; its own dice; reloads.
func _test_intra_club() -> void:
	PreSeason.reload()
	# The rules.
	_check(PreSeason.invites_needed(32, 49) == 14 and PreSeason.invites_needed(46, 49) == 0
			and PreSeason.invites_needed(44, 49) == 2 and PreSeason.invites_needed(20, 10) == 10,
			"Two sides of 23 need the gap filled, and never more prospects than there are")
	var listed := []
	for i in range(30):
		listed.append({"id": "L%02d" % i, "overall": 90 - i})
	var guests := []
	for i in range(16):
		guests.append({"id": "G%02d" % i, "overall": 60 - i})
	var even := PreSeason.intra_sides(listed, guests, "even")
	var best := PreSeason.intra_sides(listed, guests, "best")
	var best_first_listed := true
	for q in best[0]:
		best_first_listed = best_first_listed and str(q["id"]).begins_with("L")
	var even_guests := 0
	for q in even[0]:
		even_guests += 1 if str(q["id"]).begins_with("G") else 0
	_check((even[0] as Array).size() == 23 and (even[1] as Array).size() == 23 and even_guests == 8
			and str(even[0][0]["id"]) == "L00" and str(even[1][0]["id"]) == "L01",
			"Even sides deal the list and the prospects alternately, 23 a side")
	_check((best[0] as Array).size() == 23 and (best[1] as Array).size() == 23 and best_first_listed
			and str(best[1][0]["id"]) == "L23",
			"Best side v the rest: the best 23 listed players are one side, the rest and every prospect the other")
	var src := {"id": "D1", "num": 0, "overall": 60, "attr": {"durability": 50}, "injury_weeks": 0}
	var copy := PreSeason.intra_guest(src, 61, CLUB)
	copy["attr"]["durability"] = 1
	_check(int(copy["num"]) == 61 and bool(copy["guest"]) and Injuries.chance(copy) == 0.0
			and int(src["num"]) == 0 and int(src["attr"]["durability"]) == 50 and not src.has("guest"),
			"A prospect plays as a copy with a spare number who cannot be hurt, and nothing done to the copy reaches him")
	_check(PreSeason.prospect_line({"goals": 3, "disposals": 9}).contains("3 goals")
			and PreSeason.prospect_line({"disposals": 25}).contains("25 disposals")
			and PreSeason.prospect_line({"disposals": 4}).contains("quiet day")
			and PreSeason.prospect_line({}) == "Saw almost nothing of the ball.",
			"The line on a prospect says what he did, from his own numbers")
	var half := {"id": "h", "attr": {"durability": 50}, "cond_injury": float(PreSeason.tune("intra_injury_rate"))}
	_check(is_equal_approx(Injuries.chance(half), 0.5 * Injuries.chance({"id": "h", "attr": {"durability": 50}})),
			"A listed player carries half a normal match's injury risk in it")

	# In a career.
	_to_intra()
	_check(GameState.preseason_stop() == "intra" and GameState.preseason_week() == PreSeason.intra_week()
			and not GameState.intra_played() and GameState.intra_invites().is_empty()
			and str(GameState.preseason_intra()["mode"]) == "even",
			"After week 5 the pre-season waits at the intra-club match, with nobody invited yet")
	var fit := 0
	for q in GameState.my_list:
		fit += 1 if Ratings.available(q) else 0
	var need: int = GameState.intra_needed()
	var pool: Array = GameState.intra_prospects()
	_check(need == PreSeason.invites_needed(fit, pool.size()) and need > 0 and pool.size() >= need,
			"The sides need 46 less the fit listed players (%d for a list with %d fit)" % [need, fit])
	var ai_seen := {}
	for q in pool:
		for c in (q.get("seen", {}) as Dictionary):
			ai_seen[c] = int(ai_seen.get(c, 0)) + 1
	var ai_ok := not ai_seen.has(CLUB)
	for code in GameState.season.clubs:
		if str(code) == CLUB:
			continue
		var fit_ai := 0
		for q in GameState.season.lists[code]:
			fit_ai += 1 if Ratings.available(q) or int(q.get("injury_weeks", 0)) > 0 else 0
		ai_ok = ai_ok and int(ai_seen.get(str(code), 0)) > 0 and int(ai_seen.get(str(code), 0)) <= 46
	_check(ai_ok, "Every AI club has played its own that week and seen the prospects it invited; yours waits for you")
	var pool_before := _pool_sig()
	_check(GameState.set_intra_mode("best") and not GameState.set_intra_mode("random")
			and str(GameState.preseason_intra()["mode"]) == "best" and GameState.set_intra_mode("even"),
			"The coach picks how the sides are made, from the two ways on offer")
	var picked := []
	for i in range(need):
		picked.append(str(pool[pool.size() - 1 - i]["id"]))
	var all_in := true
	for id in picked:
		all_in = GameState.toggle_intra_invite(str(id)) and all_in
	_check(all_in and GameState.intra_invites().size() == need
			and not GameState.toggle_intra_invite(str(pool[0]["id"])) and not GameState.toggle_intra_invite("nobody"),
			"The coach invites whoever he likes from the class, as many as the sides need and no more")
	_check(GameState.toggle_intra_invite(str(picked[0])) and GameState.intra_invites().size() == need - 1
			and GameState.toggle_intra_invite(str(picked[0])),
			"An invitation can be taken back and given again")
	var xp_before := {}
	var ov_before := {}
	for q in GameState.my_list:
		xp_before[str(q["id"])] = int(q.get("xp", 0))
		ov_before[str(q["id"])] = int(q["overall"])
	var hurt_before := GameState.preseason_injuries().size()
	var board_before := GameState.board_confidence()
	var news_before := GameState.news.size()
	_check(GameState.sim_intra_match() and GameState.intra_played() and GameState.preseason_stop() == "intra"
			and not GameState.sim_intra_match(),
			"Simmed, the match is played once and the pre-season waits at its report")
	var rep: Dictionary = GameState.preseason_intra()["report"]
	var seen_ids := (rep["prospects"] as Array).map(func(r): return str(r["id"]))
	seen_ids.sort()
	var want := picked.duplicate()
	want.sort()
	var lines_ok := true
	for r in rep["prospects"]:
		lines_ok = lines_ok and str(r["line"]) != ""
	var overlap := false
	for id in rep["stood"]:
		overlap = overlap or (rep["struggled"] as Array).has(id) or GameState.list_player(str(id)).is_empty()
	_check(rep["names"] == ["Fremantle Purple", "Fremantle White"] and (rep["stood"] as Array).size() == 3
			and (rep["struggled"] as Array).size() == 2 and not overlap and seen_ids == want and lines_ok,
			"The report names the two sides by their strips, three who stood out, two who struggled, and a line on each prospect he invited")
	# What it leaves on the prospects: the note, and nothing else.
	var noted := true
	for q in GameState.draftee_pool:
		var mine_seen: Dictionary = (q.get("seen", {}) as Dictionary).get(CLUB, {})
		noted = noted and (picked.has(str(q["id"])) == (not mine_seen.is_empty())) \
				and (mine_seen.is_empty() or (int(mine_seen["year"]) == GameState.season_year and str(mine_seen["line"]) != ""))
	_check(noted and _pool_sig() == pool_before,
			"Each prospect he saw carries the club's note; nothing else about anyone in the draft pool has changed")
	var one: Dictionary = {}
	for q in GameState.draftee_pool:
		if str(q["id"]) == str(picked[0]):
			one = q
	var unseen := one.duplicate(true)
	unseen.erase("seen")
	var tight: Dictionary = DraftScouting.projection(one, CLUB, GameState.career_seed)
	var loose: Dictionary = DraftScouting.projection(unseen, CLUB, GameState.career_seed)
	var other_club := ""
	for c in GameState.season.clubs:
		if str(c) != CLUB and not (one["seen"] as Dictionary).has(str(c)) and other_club == "":
			other_club = str(c)
	_check(int(tight["potential"][1]) - int(tight["potential"][0]) < int(loose["potential"][1]) - int(loose["potential"][0])
			and absi(int(tight["overall_mid"]) - int(one["overall"])) <= absi(int(loose["overall_mid"]) - int(one["overall"]))
			and is_equal_approx(PreSeason.seen_mult(one, CLUB), float(PreSeason.tune("intra_seen_uncertainty")))
			and (other_club == "" or PreSeason.seen_mult(one, other_club) == 1.0),
			"His club's read of a prospect it saw is narrower and no further from the truth; a club that did not see him reads him as before")
	_check(PreSeason.seen_line(one, CLUB) == "Seen in your %d intra-club match. %s" % [GameState.season_year, str(one["seen"][CLUB]["line"])]
			and PreSeason.seen_line(unseen, CLUB) == "",
			"His draft card line says he was seen in the intra-club match and what he did")
	var ai_tight := true
	for q in GameState.draftee_pool:
		for c in (q.get("seen", {}) as Dictionary):
			ai_tight = ai_tight and is_equal_approx(PreSeason.seen_mult(q, str(c)), float(PreSeason.tune("intra_seen_uncertainty")))
	_check(ai_tight, "An AI club's read of the prospects it saw tightens by the same rule")
	# What it leaves on the list.
	var grew := 0
	var inside := true
	var stamped := false
	for q in GameState.my_list:
		var id := str(q["id"])
		grew += 1 if int(q.get("xp", 0)) != int(xp_before[id]) or int(q["overall"]) != int(ov_before[id]) else 0
		inside = inside and int(q["overall"]) <= maxi(int(ov_before[id]), GameState.season_ceiling(q))
		stamped = stamped or q.has("cond_injury") or q.has("guest")
	_check(grew >= 30 and inside and not stamped,
			"The listed players who played get a reserves game's development inside the season limit, and no stamp of the day is left on them (%d developed)" % grew)
	var new_hurt: Array = GameState.preseason_injuries().slice(hurt_before)
	var hurt_ok := true
	for r in new_hurt:
		hurt_ok = hurt_ok and str(r.get("how", "")) == "intra" and str(r["club"]) == CLUB \
				and int(GameState.list_player(str(r["id"])).get("injury_weeks", 0)) == int(r["weeks"])
	_check(hurt_ok and (rep["hurt"] as Array).size() == new_hurt.size() and GameState.my_new_injuries().size() == new_hurt.size(),
			"Anyone hurt in it is a listed player, recorded as a match injury is and named in the report (%d this seed)" % new_hurt.size())
	# What it never touches.
	var no_games := true
	for code in GameState.season.ladder:
		no_games = no_games and int((GameState.season.ladder[code] as Dictionary).get("p", 0)) == 0
	_check(GameState.season.round_index == 0 and GameState.season_log.is_empty() and GameState.season_tally.is_empty()
			and GameState.season_stats.is_empty() and GameState.season_team.is_empty() and no_games
			and GameState.board_confidence() == board_before and GameState.last_results.is_empty()
			and GameState.pending_match.is_empty() and not GameDB.is_side("FRE_H") and not GameDB.is_side("FRE_A")
			and GameState.news.size() == news_before + new_hurt.size(),
			"Nothing of it is on the ladder, the season's statistics, the votes, the board or the news (but an injury), and its two sides are gone")
	var games_ok := true
	for q in GameState.my_list:
		games_ok = games_ok and int(q.get("xp_games", 0)) == 0
	_check(games_ok, "It is nobody's senior game")
	var sig_played := _sig() + _pool_sig() + str(rep)
	# The same choices again: the same match.
	_to_intra()
	for id in picked:
		GameState.toggle_intra_invite(str(id))
	GameState.sim_intra_match()
	_check(_sig() + _pool_sig() + str(GameState.preseason_intra()["report"]) == sig_played,
			"The same seed, sides and invitations give the same intra-club match")
	# Saved and loaded at the stop, before and after it is played.
	_to_intra()
	for id in picked:
		GameState.toggle_intra_invite(str(id))
	GameState.save_career()
	GameState.load_career()
	GameState.replay_seed = SUITE_SEED
	var kept: Array = GameState.intra_invites().map(func(x): return str(x))
	_check(GameState.preseason_stop() == "intra" and not GameState.intra_played() and kept == picked,
			"Loaded at the intra-club stop, the invitations are as he left them and the match is still to play")
	GameState.sim_intra_match()
	_check(_sig() + _pool_sig() + str(GameState.preseason_intra()["report"]) == sig_played,
			"...and played after the reload it is the same match")
	GameState.save_career()
	GameState.load_career()
	GameState.replay_seed = SUITE_SEED
	_check(GameState.preseason_stop() == "intra" and GameState.intra_played()
			and str(GameState.preseason_intra()["report"]["stood"]) == str(rep["stood"])
			and not GameState.sim_intra_match() and not GameState.toggle_intra_invite(str(pool[0]["id"])),
			"Loaded after it is played, the report is still there and the match cannot be played again")
	# A story card may stop it at the end of a block; pressing on leaves it unanswered.
	var at_stop: String = GameState.preseason_advance()
	var stops := 0
	while at_stop == "story" and stops < 4:
		stops += 1
		at_stop = GameState.preseason_advance()
	_check(at_stop == "practice" and _press_on(),
			"From the report, pressing on trains weeks 6 and 7, plays the practice match, and leaves Round 1 to play")
	# Best side v the rest plays out differently, and one-sidedly.
	_to_intra()
	GameState.set_intra_mode("best")
	for id in picked:
		GameState.toggle_intra_invite(str(id))
	GameState.sim_intra_match()
	var brep: Dictionary = GameState.preseason_intra()["report"]
	_check(int(brep["score"][0]) > int(brep["score"][1]) and str(brep) != str(rep),
			"Best side v the rest is a different match, and the best side wins it (%d to %d this seed)" % [int(brep["score"][0]), int(brep["score"][1])])
	# Hands off: Sim to Round 1 plays it, the recruiters invite, sides even.
	_career()
	GameState.preseason_sim_to_round1()
	var auto: Dictionary = GameState.preseason_intra()
	_check(bool(auto.get("played", false)) and bool(auto.get("seen", false)) and str(auto.get("mode", "")) == "even"
			and (auto.get("invites", []) as Array).size() == (auto["report"]["prospects"] as Array).size()
			and (auto.get("invites", []) as Array).size() > 0,
			"Sim to Round 1 plays the intra-club match too: even sides, the recruiters' invitations")
	# The switch off: no match, no notes read.
	Features.set_on("preseason", false)
	_check(PreSeason.seen_mult(one, CLUB) == 1.0 and DraftScouting.projection(one, CLUB, GameState.career_seed) == loose
			and not GameState.sim_intra_match() and not GameState.prepare_intra_match(),
			"Switched off, there is no intra-club match and a note already on a prospect changes no club's read of him")
	Features.set_on("preseason", true)
	PreSeason.reload()


## Write the current career as a save from before pre-seasons: no `preseason`
## key, no base on any season fitness record.
func _save_as_old() -> void:
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("preseason")
	for code in (state.get("conditioning", {}) as Dictionary):
		(state["conditioning"][code] as Dictionary).erase("base")
	CareerSave.write(state, GameState._save_meta(), GameState.save_path)


func _test_old_saves() -> void:
	PreSeason.reload()
	# Mid-season.
	_career(false)
	_play(2)
	_save_as_old()
	_play(2)
	var straight := _sig()
	_check(GameState.load_career(), "A save from before pre-seasons loads mid-season")
	GameState.replay_seed = SUITE_SEED
	_check(GameState.preseason.is_empty() and not GameState.preseason_active() and GameState.preseason_stop() == "",
			"...with no pre-season running")
	_play(2)
	_check(_sig() == straight, "...and plays on exactly as the career it was saved from")
	# On to the end of the season: still no pre-season, until the rollover.
	while not GameState.season.is_season_over():
		GameState.advance()
	_check(GameState.preseason.is_empty(), "It finishes its season without one")
	GameState.open_offseason()
	_save_as_old()
	# In the off-season: the rollover opens the first pre-season.
	_check(GameState.load_career() and GameState.preseason.is_empty(), "A save from before pre-seasons loads in the off-season")
	GameState.replay_seed = SUITE_SEED
	var year := GameState.season_year
	_roll()
	_check(GameState.season_year == year + 1 and GameState.preseason_active() and GameState.preseason_stop() == "plan"
			and GameState.needs_season_wrap(),
			"Its next season starts with the off-season wrap and then its first pre-season")
	var legal := true
	for code in GameState.season.clubs:
		legal = legal and GameState.preseason_blocks(str(code)).size() == PreSeason.block_count()
	_check(legal, "...with blocks for every club in that season")
	GameState.preseason_sim_to_round1()
	_play(1)
	_check(GameState.season.round_index == 1 and not GameState.preseason_active(),
			"...and Round 1 follows it")
	# At the wrap: a save made at the rollover before pre-seasons existed goes
	# to Round 1 as it always did.
	GameState.load_career()
	GameState.replay_seed = SUITE_SEED
	Features.set_on("preseason", false)
	_roll()
	_save_as_old()
	_play(1)
	var wrap_straight := _sig()
	Features.set_on("preseason", true)
	_check(GameState.load_career() and GameState.needs_season_wrap() and not GameState.preseason_active(),
			"A save from before pre-seasons loads at the off-season wrap, with no pre-season waiting")
	GameState.replay_seed = SUITE_SEED
	# Plan familiarity is its own feature (its own suite): none of it here.
	PreSeason.data()["familiar_mult"] = {"well": 1.0, "partly": 1.0, "barely": 1.0}
	_play(1)
	PreSeason.reload()
	_check(_sig() == wrap_straight and GameState.preseason.is_empty(),
			"...and goes to Round 1 as it always did")
	# A new save keeps the pre-season.
	_career()
	_set_blocks([["heavy", "running"], ["solid", "running"], ["solid", "skills"]])
	GameState.preseason_advance()
	var snap: Dictionary = GameState.preseason.duplicate(true)
	GameState.save_career()
	GameState.load_career()
	_check(str(GameState.preseason_blocks()) == str(snap["clubs"][CLUB]["blocks"])
			and GameState.preseason_week() == int(snap["week"])
			and is_equal_approx(float(GameState.preseason["clubs"][CLUB]["run"]), float(snap["clubs"][CLUB]["run"])),
			"The pre-season survives save and load: the blocks, the week and the running done")


## The rollover, without an intake draft to sit through.
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


## A story card at the end of a block, on the screen, by real taps: the stop
## says where it is, the card answers, the outcome shows, and the way on works.
func _test_story_stop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	PreSeason.reload()
	var found := false
	for seed in range(SUITE_SEED, SUITE_SEED + 30):
		GameState.reset()
		GameState.career_seed = seed
		GameState.replay_seed = seed
		GameState.start_season(CLUB, GameDB.club_list(CLUB))
		GameState.open_preseason()
		GameState.set_setting("seen_weekly_loop_intro", true)
		GameState.set_setting("seen_training_intro", true)
		var guard := 0
		while GameState.preseason_active() and GameState.preseason_stop() != "story" and guard < 10:
			guard += 1
			if GameState.preseason_stop() == "intra" and not GameState.intra_played():
				GameState.sim_intra_match()
			GameState.preseason_advance()
		if GameState.preseason_stop() == "story":
			found = true
			break
	_check(found, "A card stop turns up in thirty careers, to see on the screen")
	if not found:
		return
	var week := GameState.preseason_week()
	var scene: Control = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "PreSeasonHero") == "After week %d of 8" % week,
			"A career saved at a card stop opens on that stop, saying which week it is")
	var card := scene.find_child("WeekEvent", true, false)
	var first_choice := scene.find_child("Event_0", true, false) as Button
	_check(card != null and first_choice != null and scene.find_child("PreSeasonCards", true, false) != null,
			"The card is on the pre-season screen with its answers")
	_check(scene.find_child("EventGain_0_0", true, false) != null or scene.find_child("EventCost_0_0", true, false) != null,
			"...and a choice shows its Gain or Cost line under it")
	_check(_fits(scene, 390.0), "Nothing on the card stop runs off a phone's screen")
	var id := str(GameState.week_events[0]["tid"])
	_check(await _tap(first_choice, "the card's first answer"), "A finger's tap answers the card")
	_check(bool(GameState.week_events[0].get("resolved", false)) and int(GameState.week_events[0].get("choice", -1)) == 0
			and str(GameState.week_events[0].get("tid", "")) == id,
			"...and the answer is recorded")
	var scene2 := tree.current_scene as Control
	_check(scene2.find_child("Event_0", true, false) == null, "...and the card then shows what happened, not its buttons")
	var go := scene2.find_child("PreSeasonGo", true, false) as Button
	_check(await _tap(go, "the way on from the card"), "A finger's tap presses on from the card")
	await _frames(tree, 4)
	_check(GameState.preseason_stop() != "story" and not bool(GameState.preseason.get("story_pending", false)),
			"...and the pre-season is no longer waiting on it")
	GameState.delete_saved_career()


## The draft card at the National Draft that follows the pre-season.
func _test_draft_card() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	# The draft card, at the National Draft that follows: the line on a prospect
	# the club saw, and none on one it did not.
	PreSeason.reload()
	_to_intra()
	var seen_id := str(GameState.intra_prospects()[3]["id"])
	GameState.toggle_intra_invite(seen_id)
	GameState.sim_intra_match()
	_press_on()
	var unseen_id := ""
	for q in GameState.draftee_pool:
		if unseen_id == "" and not ((q.get("seen", {}) as Dictionary).has(CLUB)):
			unseen_id = str(q["id"])
	GameState.season.round_index = GameState.season.fixture.size()
	var drafting: bool = GameState.begin_intake_draft()
	var draft_scene: Control = load("res://scenes/DraftScene.tscn").instantiate()
	tree.root.add_child(draft_scene)
	await _frames(tree, 8)
	draft_scene.call("_open_player", seen_id)
	await _frames(tree, 4)
	var card_line := draft_scene.find_child("SeenIntraClub", true, false) as Label
	var seen_p: Dictionary = {}
	for q in GameState.draftee_pool:
		if str(q["id"]) == seen_id:
			seen_p = q
	_check(drafting and card_line != null and card_line.is_visible_in_tree()
			and card_line.text == PreSeason.seen_line(seen_p, CLUB) and card_line.text.begins_with("Seen in your"),
			"At the National Draft the card of a prospect he saw says so, and what he did that day (%s)" % (card_line.text if card_line != null else "no line"))
	draft_scene.queue_free()
	await _frames(tree, 3)
	draft_scene = load("res://scenes/DraftScene.tscn").instantiate()
	tree.root.add_child(draft_scene)
	await _frames(tree, 8)
	draft_scene.call("_open_player", unseen_id)
	await _frames(tree, 4)
	_check(unseen_id != "" and draft_scene.find_child("SeenIntraClub", true, false) == null,
			"A prospect he did not see has no such line")
	draft_scene.queue_free()
	await _frames(tree, 3)


## The switch as it ships: off, unless the command line or the project says so.
func _test_switch_default() -> void:
	Features.clear("preseason")
	_check(not bool(ProjectSettings.get_setting("features/preseason", false))
			and FileAccess.get_file_as_string("res://project.godot").contains("preseason=false")
			and not Features.on("preseason"),
			"The pre-season switch ships off: an exported build, and any run that does not ask for it, has no pre-season")
	Features.set_on("preseason", true)
	_check(Features.on("preseason"), "A test or tool turns the switch on for itself")
	Features.set_on("preseason", false)
	_check(not Features.on("preseason"), "...and off again")
	Features.clear("preseason")


## Switched off, the game is the game without a pre-season: none opens, no
## state is written, a save made with it on loads and plays with its
## pre-season left alone, and turning it back on finds that state intact.
func _test_switch_off() -> void:
	PreSeason.reload()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	# The reference: a season that never had a pre-season (plan familiarity is
	# its own feature, tested in its own suite: none of it here).
	PreSeason.data()["familiar_mult"] = {"well": 1.0, "partly": 1.0, "barely": 1.0}
	_career(false)
	_play(2)
	var plain := _sig()
	PreSeason.reload()
	Features.set_on("preseason", false)
	_career()
	_check(GameState.preseason.is_empty() and not GameState.preseason_active() and GameState.preseason_stop() == "",
			"Switched off, a new career opens no pre-season and writes none of its state")
	_check(not GameState.set_preseason_block(0, "heavy", "running") and GameState.preseason_advance() == "done"
			and GameState.preseason.is_empty(),
			"...and none of its controls does anything")
	GameState.save_career()
	var saved := CareerSave.read(GameState.save_path)
	_check((saved.get("preseason", {}) as Dictionary).is_empty(), "...nor does its save hold any")
	_play(2)
	_check(_sig() == plain, "Switched off, the first two rounds are exactly the game's without a pre-season")
	# The screens: straight to the hub, and the wrap begins the season.
	_career()
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.season_wrap = {"year": GameState.season_year, "seen": false, "ins": [], "outs": [],
			"staff": [], "goal": "Make the finals", "reason": "The board sees a list good enough to play finals."}
	var scene: Control = await _open(tree)
	var begin := scene.find_child("BeginSeason", true, false) as Button if scene != null else null
	_check(scene != null and scene.name == "HubScene" and begin != null and begin.text == "Begin season",
			"Switched off, the game opens on the hub and the off-season wrap says Begin season")
	_check(await _tap(begin, "Begin season"), "A finger's tap begins the season")
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "HubScene" and scene.find_child("WeekActions", true, false) != null,
			"...and Round 1 is there to play, with no pre-season screen in between")

	# A save made with it ON, at the time trial after a Heavy block.
	Features.set_on("preseason", true)
	PreSeason.data()["heavy_week_injury"] = 0.1
	_career()
	_set_blocks([["heavy", "running"], ["heavy", "running"], ["solid", "running"]])
	GameState.preseason_advance()
	var kept: Dictionary = GameState.preseason.duplicate(true)
	GameState.save_career()
	Features.set_on("preseason", false)
	_check(GameState.load_career(), "A save made with the pre-season on loads with it off")
	GameState.replay_seed = SUITE_SEED
	_check(not GameState.preseason_active() and GameState.preseason_stop() == ""
			and int(GameState.preseason.get("week", -1)) == int(kept["week"])
			and str(GameState.preseason_blocks()) == str(kept["clubs"][CLUB]["blocks"]),
			"...its pre-season is not running, and its saved state is still there, untouched")
	scene = await _open(tree)
	_check(scene != null and scene.name == "HubScene", "...and the game opens on the hub at Round 1")
	_play(1)
	_check(GameState.season.round_index == 1 and int(GameState.preseason.get("week", -1)) == int(kept["week"])
			and not bool(GameState.preseason.get("done", false)),
			"...Round 1 plays, and the pre-season was neither finished nor wiped")
	# A finished one with a strong base: the base is on the record, unread.
	Features.set_on("preseason", true)
	_career()
	_set_blocks([["solid", "running"], ["solid", "running"], ["solid", "running"]])
	GameState.preseason_sim_to_round1()
	_check(Conditioning.base_of(GameState.fitness_record(CLUB)) == "strong", "(setup) a strong base with it on")
	GameState.save_career()
	Features.set_on("preseason", false)
	GameState.load_career()
	GameState.replay_seed = SUITE_SEED
	var rec: Dictionary = GameState.fitness_record(CLUB)
	_check(str(rec.get("base", "")) == "strong" and Conditioning.base_of(rec) == "sound"
			and Conditioning.base_curve(rec, 0) == 0.0 and not GameState.fitness_status_line().contains("base"),
			"Switched off, a base already saved stays on the record and is not read: the season plan is as it was before bases")
	Features.set_on("preseason", true)
	GameState.load_career()
	_check(Conditioning.base_of(GameState.fitness_record(CLUB)) == "strong",
			"Switched back on, the same save has its strong base again: nothing was lost")
	PreSeason.reload()
	Router.stack = []
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await _frames(tree, 3)


func _frames(tree: SceneTree, n: int) -> void:
	for i in range(n):
		await tree.process_frame


## A finger's tap on a control (tests/tap.gd), checked.
func _tap(b: Control, what: String) -> bool:
	var why: String = await Tap.tap(b)
	if why != "":
		_check(false, "A finger's tap reaches %s (%s)" % [what, why])
		if is_instance_valid(b) and b is BaseButton:
			(b as BaseButton).emit_signal("pressed")
	return why == ""


## Open the game at the hub, as Continue does, and return the screen it lands on.
func _open(tree: SceneTree) -> Control:
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	return tree.current_scene as Control


func _label(scene: Node, node_name: String) -> String:
	var l := scene.find_child(node_name, true, false) as Label if scene != null else null
	return l.text if l != null else ""


## Every label on the page is inside the screen's width (nothing clipped).
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


## The stops with a finger's taps, as the game routes them: the plan, the
## blocks, the time trial, Round 1; Sim to Round 1; Android Back at each stop;
## the wrap leading in; a PC's width.
func _test_screens() -> void:
	PreSeason.reload()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	_career()
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.set_setting("seen_training_intro", true)
	# A risky size for this walk-through, so a Heavy block is sure to hurt someone.
	PreSeason.data()["heavy_week_injury"] = 0.3
	var scene: Control = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and Router.current() == "preseason",
			"With a pre-season running, the game opens on the pre-season plan, not the hub")
	_check(scene.find_child("TrialStopwatch", true, false) == null, "The plan has no stopwatch: it belongs to the time trial")
	_check(_label(scene, "PreSeasonHero") == "Eight weeks to Round 1"
			and _label(scene, "PreSeasonClub") == GameDB.club_name(CLUB),
			"The plan screen says whose pre-season it is and how long it runs")
	var all_blocks := true
	for i in range(3):
		all_blocks = all_blocks and scene.find_child("Block_%d" % i, true, false) != null \
				and _label(scene, "BlockGain_%d" % i) != ""
	var cost0 := scene.find_child("BlockCost_0", true, false) as Label
	_check(all_blocks and cost0 != null and not cost0.is_visible_in_tree(),
			"All three blocks are on the plan, each saying what its training gains; a Solid block shows no Cost line")
	_check(_fits(scene, 390.0), "Nothing on the plan runs off a phone's screen")
	_check(_label(scene, "PreSeasonQuietWeek").contains("weeks 6 to 7")
			and not _label(scene, "PreSeasonBaseEffect").contains("level")
			and _label(scene, "PreSeasonBaseEffect").contains("usual fitness"),
			"Week 8's line names the weeks whose legs last into Round 1, and a sound base says what the side starts with")
	var plan_sub := scene.find_child("SeasonPlanSub", true, false) as Label
	_check(plan_sub != null and not plan_sub.text.contains("Steady") and plan_sub.text.contains("Round 1")
			and not _label(scene, "PreSeasonSub").contains("pre-season"),
			"The season plan row says its plan once and what the tap is for, and the header does not say pre-season twice")
	# The coach's choices are never grey, and the chosen one is marked.
	var light0 := scene.find_child("Load0_light", true, false) as Button
	var solid0 := scene.find_child("Load0_solid", true, false) as Button
	_check(light0 != null and solid0 != null
			and UiKit.contrast(light0.get_theme_color("font_color"), UiKit.SURFACE) >= 4.5
			and bool(solid0.get_meta("chosen", false)) and not bool(light0.get_meta("chosen", false))
			and solid0.get_theme_font("font") == UiKit.BOLD and light0.get_theme_font("font") == UiKit.FONT,
			"Every load is in readable ink, and the chosen one is bold and outlined")
	# The result of the choices is pinned above the way on, in view.
	var base_word := scene.find_child("PreSeasonBaseWord", true, false) as Label
	var go_btn := scene.find_child("PreSeasonGo", true, false) as Control
	_check(base_word != null and go_btn != null and base_word.text.contains("sound fitness base")
			and base_word.get_global_rect().end.y <= go_btn.global_position.y + 1.0
			and go_btn.get_global_rect().end.y <= 844.0 and base_word.global_position.y > 422.0,
			"The fitness base the training builds is pinned above the way on, in view without scrolling")
	_check(UiKit.contrast((go_btn as Button).get_theme_stylebox("normal").bg_color, UiKit.BG) >= 4.5,
			"The way on stands off the page in Fremantle's colours")
	_check(await _tap(scene.find_child("Load0_heavy", true, false), "Heavy for weeks 1 to 3"),
			"A finger's tap sets a Heavy load for weeks 1 to 3")
	_check(bool((scene.find_child("Load0_heavy", true, false) as Button).get_meta("chosen", false))
			and not bool(solid0.get_meta("chosen", false)),
			"The outline moves to the load just picked")
	_check(str(GameState.preseason_blocks()[0][0]) == "heavy"
			and _label(scene, "BlockCost_0") == PreSeason.cost_line("heavy", "running", 0)
			and _label(scene, "BlockCost_0").contains("risk of soft-tissue injuries"),
			"The block's cost line changes with the load: a Heavy block says its risk of soft-tissue injuries")
	_check(await _tap(scene.find_child("Focus1_running", true, false), "Running for weeks 4 to 5"),
			"A finger's tap sets the focus for weeks 4 to 5")
	_check(str(GameState.preseason_blocks()[1][1]) == "running"
			and _label(scene, "BlockGain_1").contains("fitness base")
			and _label(scene, "PreSeasonBaseWord").contains("strong fitness base"),
			"The focus changes what the block gains, and the plan says the base it now builds")
	_check(await _tap(scene.find_child("Load2_heavy", true, false), "Heavy for weeks 6 to 7"),
			"A finger's tap sets a Heavy last block")
	_check(_label(scene, "BlockCost_2").contains("Round 1") and _label(scene, "BlockCost_2").contains("risk of soft-tissue injuries"),
			"A Heavy last block says its risk and that it costs sore legs in Round 1")
	# The season fitness plan opens from here, and Back closes it first.
	_check(await _tap(scene.find_child("SeasonPlanLine", true, false), "the season fitness plan"),
			"A finger's tap opens the season fitness plan from the pre-season")
	await _frames(tree, 4)
	_check(scene.find_child("SeasonPlanSheet", true, false) != null, "The season fitness plan sheet is open")
	Router.handle_back()
	await _frames(tree, 4)
	var sheet := scene.find_child("SeasonPlanSheet", true, false)
	_check((sheet == null or sheet.is_queued_for_deletion()) and tree.current_scene == scene,
			"Back closes the sheet and stays on the plan")
	# Back at the plan: the main menu, and the career is where it was.
	Router.handle_back()
	await _frames(tree, 8)
	_check(Router.current() == "main" and GameState.preseason_stop() == "plan"
			and str(GameState.preseason_blocks()[0][0]) == "heavy",
			"Back at the plan goes to the main menu and keeps the plan as set")
	scene = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "BlockCost_0").contains("risk of soft-tissue injuries"),
			"Continuing returns to the plan with its choices")
	var start := scene.find_child("PreSeasonGo", true, false) as Button
	_check(start != null and start.text == "Start training"
			and not _label(scene, "PreSeasonQuietWeek").contains("freshens"),
			"The plan's button says what it does, in its own words, and week 8 promises no freshening")
	_check(await _tap(start, "Start training"), "A finger's tap starts the training")
	await _frames(tree, 6)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "trial"
			and _label(scene, "PreSeasonHero") == "The time trial",
			"Weeks 1 to 3 are trained and the game stops at the time trial")
	# The stopwatch at the time trial: the real picture in its own steel and
	# white, big enough to read, inside the header, clear of every word, taking
	# no tap; the names and the way on are still on a phone's screen.
	var watch := scene.find_child("TrialStopwatch", true, false) as TextureRect
	var watch_tex: Texture2D = watch.texture if watch != null else null
	_check(watch_tex != null and watch_tex.resource_path == "res://assets/ui/models/stopwatch.png"
			and float(watch_tex.get_height()) >= 2.0 * watch.size.y and watch.size.y >= 56.0,
			"The time trial stop shows the stopwatch's own picture, big and sharp (%s)" % (watch_tex.resource_path if watch_tex != null else "missing"))
	# The dial is white: most of a ring of points on it (the hand and the ticks take a few).
	var white := 0
	if watch_tex != null:
		var wimg := watch_tex.get_image()
		for at in [Vector2(0.38, 0.52), Vector2(0.62, 0.52), Vector2(0.5, 0.74), Vector2(0.4, 0.7), Vector2(0.62, 0.7), Vector2(0.5, 0.5)]:
			var px := wimg.get_pixel(int(wimg.get_width() * at.x), int(wimg.get_height() * at.y))
			if px.a > 0.9 and px.v > 0.8 and px.s < 0.15:
				white += 1
	var watch_ok := watch != null and watch.mouse_filter == Control.MOUSE_FILTER_IGNORE and watch.modulate == Color.WHITE and white >= 4
	if not watch_ok:
		print("stopwatch: white points ", white)
	var head := scene.find_child("PreSeasonHeader", true, false) as Control
	if watch != null and head != null:
		watch_ok = watch_ok and head.get_global_rect().grow(0.5).encloses(watch.get_global_rect())
		for l in head.find_children("*", "Label", true, false):
			var lab := l as Label
			if lab.text == "":
				continue
			# The words as drawn (a label's box runs the row's width; its words do not).
			var need := lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x
			var drawn := Rect2(lab.global_position, Vector2(minf(need, lab.size.x), lab.size.y))
			if drawn.grow(4.0).intersects(watch.get_global_rect()) or lab.size.y + 1.0 < lab.get_combined_minimum_size().y:
				watch_ok = false
				print("stopwatch touches or cuts: ", lab.text.left(30), " ", drawn, " watch ", watch.get_global_rect())
	_check(watch_ok, "The stopwatch is steel with a white dial, in no club's colour, takes no tap, and no word in the header is covered or cut short")
	# Nothing the coach uses moves: every name and every choice is where it is without the picture.
	var marks := ["PreSeasonHero", "PreSeasonSub", "TrialBest_0", "TrialWorst_0", "Load1_light", "Focus1_running", "Load2_heavy", "PreSeasonGo"]
	var with_art := {}
	for m in marks:
		var n := scene.find_child(m, true, false) as Control
		with_art[m] = n.get_global_rect() if n != null else Rect2()
	UiArt.dir = "res://assets/ui/no_such_folder"
	scene.call("_build")
	await _frames(tree, 4)
	_check(scene.find_child("TrialStopwatch", true, false) == null and _label(scene, "PreSeasonHero") == "The time trial",
			"Without the picture the time trial stop reads as it did")
	var moved := []
	for m in marks:
		var n := scene.find_child(m, true, false) as Control
		if n == null or not n.get_global_rect().is_equal_approx(with_art[m]):
			moved.append(m)
	_check(moved.is_empty(), "The stopwatch moves nothing: the words, the names home and every choice are where they are without it (%s)" % str(moved))
	UiArt.dir = "res://assets/ui/models"
	scene.call("_build")
	await _frames(tree, 4)
	var named := true
	for i in range(5):
		named = named and _label(scene, "TrialBest_%d" % i) != ""
	for i in range(3):
		named = named and _label(scene, "TrialWorst_%d" % i) != ""
	var first: Dictionary = GameState.list_player(str(GameState.preseason_trial()["best"][0]))
	_check(named and _label(scene, "TrialBest_0") == GameDB.player_display_name(first),
			"The time trial names the first five and the last three home")
	var hurt_lines: Array = GameState.preseason_injury_lines(1, 3)
	_check(not hurt_lines.is_empty() and _label(scene, "TrialHurt_0") == str(hurt_lines[0])
			and str(hurt_lines[0]).contains("(") and str(hurt_lines[0]).contains("week"),
			"The time trial stop names who the Heavy block hurt, in the usual injury words (%s)" % str(hurt_lines.slice(0, 2)))
	var pinned := scene.find_child("PreSeasonActions", true, false)
	var base_at_trial := scene.find_child("PreSeasonBaseWord", true, false)
	_check(pinned != null and base_at_trial != null and not pinned.is_ancestor_of(base_at_trial),
			"At the time trial the fitness base line sits with the blocks, not pinned over the names")
	_check(scene.find_child("Block_0", true, false) == null and scene.find_child("Block_1", true, false) != null
			and scene.find_child("Block_2", true, false) != null and scene.find_child("PreSeasonSim", true, false) == null,
			"At the time trial only the weeks to come can still be changed")
	_check(_fits(scene, 390.0), "Nothing at the time trial runs off a phone's screen")
	Router.handle_back()
	await _frames(tree, 8)
	_check(Router.current() == "main" and GameState.preseason_stop() == "trial",
			"Back at the time trial goes to the main menu and keeps the stop")
	scene = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "PreSeasonHero") == "The time trial",
			"Continuing returns to the time trial, neither skipped nor run again")
	_check(await _tap(scene.find_child("Load1_light", true, false), "Light for weeks 4 to 5"),
			"A finger's tap changes a block still to come")
	_check(str(GameState.preseason_blocks()[1][0]) == "light", "Weeks 4 to 5 are now Light")
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Back to training"),
			"A finger's tap goes back to training")
	await _frames(tree, 10)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "intra"
			and _label(scene, "PreSeasonHero") == "The intra-club match"
			and _label(scene, "IntraStrips").contains("Fremantle Purple v Fremantle White")
			and _label(scene, "IntraStrips").contains("You coach Purple"),
			"Weeks 4 and 5 are trained and the game stops at the intra-club match, naming the two sides by their strips")
	var need: int = GameState.intra_needed()
	_check(need > 0 and _label(scene, "IntraCount") == "0 of %d invited" % need
			and _label(scene, "IntraGain") == str(PreSeason.INTRA_GAIN["even"]) and _label(scene, "IntraCost") == str(PreSeason.INTRA_COST["even"])
			and _fits(scene, 390.0),
			"The stop says how many prospects the sides need and what even sides gain and cost")
	_check(await _tap(scene.find_child("IntraMode_best", true, false), "Best side v the rest"),
			"A finger's tap picks best side v the rest")
	_check(str(GameState.preseason_intra()["mode"]) == "best" and _label(scene, "IntraGain") == str(PreSeason.INTRA_GAIN["best"])
			and _label(scene, "IntraCost") == str(PreSeason.INTRA_COST["best"]),
			"The sides choice is taken and its gain and cost change with it")
	var first_two: Array = GameState.intra_prospects().slice(0, 2)
	for q in first_two:
		_check(await _tap(scene.find_child("Invite_" + str(q["id"]), true, false), "a prospect"),
				"A finger's tap invites a prospect")
	_check(GameState.intra_invites().size() == 2 and _label(scene, "IntraCount") == "2 of %d invited" % need
			and bool((scene.find_child("Invite_" + str(first_two[0]["id"]), true, false) as Button).get_meta("chosen", false)),
			"The two he tapped are invited, marked, and counted")
	_check(await _tap(scene.find_child("Invite_" + str(first_two[1]["id"]), true, false), "the same prospect again"),
			"A second tap takes an invitation back")
	_check(GameState.intra_invites().size() == 1, "...and he is no longer invited")
	_check(await _tap(scene.find_child("IntraFill", true, false), "Recruiters fill the rest"),
			"A finger's tap lets the recruiters fill the rest")
	_check(GameState.intra_invites().size() == need and GameState.intra_invites().has(str(first_two[0]["id"]))
			and _label(scene, "IntraCount") == "%d of %d invited" % [need, need],
			"The sides are full, and the prospect the coach picked is still among them")
	Router.handle_back()
	await _frames(tree, 8)
	_check(Router.current() == "main" and GameState.preseason_stop() == "intra" and GameState.intra_invites().size() == need,
			"Back at the intra-club stop goes to the main menu and keeps the sides and the invitations")
	scene = await _open(tree)
	# Coached from the box: the match scene, the two sides in their strips.
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Coach the match"),
			"A finger's tap goes to coach the match")
	await _frames(tree, 30)
	var m := tree.current_scene as Control
	_check(m != null and m.name == "MatchScene" and str(GameState.pending_phase) == "intra"
			and GameDB.club_name(str(GameState.pending_match["home"])) == "Fremantle Purple"
			and GameDB.club_name(str(GameState.pending_match["away"])) == "Fremantle White"
			and int(m.get("_my_side")) == 0,
			"The match opens in the match view as Fremantle Purple v Fremantle White, the coach in charge of Purple")
	var pitch := m.get("_pitch") as PitchView
	_check(pitch != null and UiKit.colour_distance(pitch._kits[0]["base"], pitch._kits[1]["base"]) >= PitchView.DISC_CLASH
			and (pitch._kits[0]["base"] as Color).is_equal_approx(GameDB.club_guernsey("FRE")["base"]),
			"On the oval the two sides wear the home strip and the clash strip")
	var ladder_before := str(GameState.season.ladder)
	var board_before := GameState.board_confidence()
	m.call("_on_skip")
	await _frames(tree, 40)
	var cont := m.find_child("FullTimeContinue", true, false) as Button
	_check(cont != null and GameState.intra_played() and m.find_child("LadderMove", true, false) == null
			and m.find_child("NextFixture", true, false) == null,
			"At full time the match is over and nothing is said of the ladder or the next round")
	_check(await _tap(cont, "Continue at full time"), "A finger's tap leaves full time")
	await _frames(tree, 12)
	scene = tree.current_scene as Control
	var rep: Dictionary = GameState.preseason_intra().get("report", {})
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "intra"
			and _label(scene, "IntraSide_0") == "Fremantle Purple" and _label(scene, "IntraSide_1") == "Fremantle White"
			and _label(scene, "IntraStood_0") != "" and _label(scene, "IntraSeen_0") != "" and _label(scene, "IntraSeenLine_0") != ""
			and (rep.get("prospects", []) as Array).size() == need and not GameDB.is_side("FRE_H"),
			"Back on the pre-season screen is the report: the score, who stood out, and a line on every prospect seen")
	_check(GameState.season.round_index == 0 and GameState.season_log.is_empty() and str(GameState.season.ladder) == ladder_before
			and GameState.board_confidence() == board_before and GameState.season_tally.is_empty(),
			"The coached match left nothing on the ladder, the season's record, the votes or the board")
	_check(scene.find_child("Block_2", true, false) != null and scene.find_child("Block_1", true, false) == null
			and _fits(scene, 390.0),
			"With the report, only weeks 6 to 7 can still be changed")
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Back to training after the match"),
			"A finger's tap goes back to training")
	await _frames(tree, 10)
	scene = tree.current_scene as Control
	# A card at the end of a block stops it on the way; the way on is the same button.
	var card_stops := 0
	while scene != null and scene.find_child("PreSeasonCards", true, false) != null and card_stops < 4:
		card_stops += 1
		await _tap(scene.find_child("PreSeasonGo", true, false), "the way on past a card")
		await _frames(tree, 10)
		scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "practice"
			and _label(scene, "PreSeasonHero") == "The practice match",
			"Weeks 6 and 7 are trained and the game stops at the practice match (its own suite plays it)")
	GameState.sim_practice_match()
	GameState.preseason["practice"]["seen"] = true
	var after: String = GameState.preseason_advance()
	var more := 0
	while after == "story" and more < 4:
		more += 1
		after = GameState.preseason_advance()
	_check(after == "done", "...and from there the last week passes")
	scene = await _open(tree)
	_check(scene != null and scene.name == "HubScene" and not GameState.preseason_active()
			and GameState.preseason_week() == 8 and GameState.season.round_index == 0,
			"The rest of the pre-season is trained and the hub opens at Round 1")
	_check(scene.find_child("WeekActions", true, false) != null
			and _label(scene, "SeasonPlanWords").ends_with("base") == (Conditioning.base_of(GameState.fitness_record(CLUB)) != "sound"),
			"Round 1 is there to play, and the season plan's line carries the base")
	var heavy := true
	for p in GameState.my_list:
		heavy = heavy and bool(p.get("heavy_legs", false))
	_check(heavy, "The Heavy last block set on the screen is in the legs at Round 1")

	# Sim to Round 1, from the plan.
	PreSeason.reload()
	_career()
	scene = await _open(tree)
	_check(await _tap(scene.find_child("PreSeasonSim", true, false), "Sim to Round 1"),
			"A finger's tap sims to Round 1")
	await _frames(tree, 10)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "HubScene" and not GameState.preseason_active()
			and GameState.preseason_week() == 8 and GameState.season.round_index == 0
			and Conditioning.base_of(GameState.fitness_record(CLUB)) == "sound",
			"Sim to Round 1 runs the whole pre-season on the plan as it stood and opens the hub at Round 1")

	# The off-season wrap leads into the pre-season.
	_career()
	GameState.season_wrap = {"year": GameState.season_year, "seen": false, "ins": [], "outs": [],
			"staff": [], "goal": "Make the finals", "reason": "The board sees a list good enough to play finals."}
	scene = await _open(tree)
	var begin := scene.find_child("BeginSeason", true, false) as Button if scene != null else null
	_check(scene != null and scene.name == "HubScene" and begin != null and begin.text == "Start the pre-season",
			"The off-season wrap is read first, and leads into the pre-season")
	_check(await _tap(begin, "Start the pre-season on the wrap"), "A finger's tap leaves the wrap")
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and not GameState.needs_season_wrap()
			and GameState.preseason_stop() == "plan",
			"From the wrap the coach is at the pre-season plan")

	# A PC: the three blocks side by side, the way on sized to its words. A
	# 1280x720 window is laid out on the game's 960x540 canvas, so that is the
	# size everything has to fit.
	tree.root.size = Vector2i(960, 540)
	await _frames(tree, 6)
	scene = tree.current_scene as Control
	var b0 := scene.find_child("Block_0", true, false) as Control
	var b1 := scene.find_child("Block_1", true, false) as Control
	var b2 := scene.find_child("Block_2", true, false) as Control
	_check(b0 != null and b1 != null and b2 != null
			and absf(b0.global_position.y - b1.global_position.y) < 1.0
			and b1.global_position.x > b0.global_position.x + 200.0
			and b2.global_position.x > b1.global_position.x + 200.0,
			"On a PC the three blocks sit side by side")
	var go := scene.find_child("PreSeasonGo", true, false) as Control
	_check(go != null and go.size.x < 500.0 and _fits(scene, 960.0),
			"On a PC the way on is sized to its words, and nothing runs off the screen")
	var pc_foot := scene.find_child("PreSeasonActions", true, false) as Control
	var pc_cost := scene.find_child("BlockCost_2", true, false) as Control
	var pc_quiet := scene.find_child("PreSeasonQuietWeek", true, false) as Control
	_check(pc_foot != null and pc_cost != null and pc_quiet != null
			and pc_cost.get_global_rect().end.y <= pc_foot.global_position.y
			and pc_quiet.get_global_rect().end.y <= pc_foot.global_position.y
			and pc_foot.get_global_rect().end.y <= 540.0,
			"On a PC the whole plan is in view above the buttons, nothing cut by them")
	var plan_line := scene.find_child("SeasonPlanLine", true, false) as Control
	var nav := scene.find_child("PreSeasonNav", true, false) as Control
	var page_scroll := (scene.find_child("PreSeasonPage", true, false) as Control).get_parent() as ScrollContainer
	_check(plan_line != null and plan_line.size.x < 520.0
			and nav != null and go.global_position.x - nav.get_global_rect().end.x < 20.0
			and page_scroll != null and not page_scroll.get_v_scroll_bar().visible
			and b0.size.y <= b1.size.y + 60.0 and (b0.get_child(0) as Control).size.y <= b0.get_child(1).size.y + 1.0,
			"On a PC the season plan row is as wide as its words, the quiet buttons sit with the way on, nothing needs a scrollbar, and each block's bar is as tall as its own words")
	_check(await _tap(scene.find_child("Focus0_skills", true, false), "Skills on a PC"),
			"A click reaches a block's focus on a PC")
	_check(str(GameState.preseason_blocks()[0][1]) == "skills", "Weeks 1 to 3 are now on skills")
	_check(await _tap(go, "Start the pre-season on a PC"), "A click starts the pre-season on a PC")
	await _frames(tree, 6)
	scene = tree.current_scene as Control
	var trial := scene.find_child("TimeTrial", true, false) as Control
	var to_come := scene.find_child("PreSeasonBlocks", true, false) as Control
	_check(trial != null and to_come != null and to_come.global_position.x > trial.global_position.x + 200.0
			and _fits(scene, 960.0),
			"On a PC the time trial sits beside the weeks to come")
	var last_runner := scene.find_child("TrialWorst_2", true, false) as Control
	var foot := scene.find_child("PreSeasonActions", true, false) as Control
	_check(last_runner != null and foot != null
			and last_runner.get_global_rect().end.y <= foot.global_position.y
			and foot.get_global_rect().end.y <= 540.0,
			"On a PC the whole time trial is in view above the buttons, nothing cut by them")
	tree.root.size = Vector2i(390, 844)
	Router.stack = []
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await _frames(tree, 3)
