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
	_test_rules()
	_test_words()
	_test_hand_over()
	_test_flow()
	_test_determinism()
	_test_own_dice()
	_test_sim_to_round_one()
	_test_ai_parity()
	_test_old_saves()
	await _test_screens()
	PreSeason.reload()
	GameState.preseason_on = true
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
	_check(not PreSeason.valid_block("brutal", "running") and not PreSeason.valid_block("solid", "plan"),
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
				clean = clean and gain != "" and (cost != "") == (str(load) != "solid")
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
			and said["heavy|running|0"].contains("gone by Round 1")
			and said["light|skills|2"] != said["light|skills|0"]
			and said["light|skills|2"].contains("Round 1"),
			"A heavy or light last block says what it does to Round 1; an earlier one says it is gone by then")
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
			by_phase = by_phase and GameState.preseason_blocks(str(code)) == PreSeason.ai_blocks(GameState._club_phase(str(code)))
	_check(by_phase, "Every AI club runs the blocks its phase calls for")
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
	_check(GameState.preseason_advance() == "done" and not GameState.preseason_active()
			and GameState.preseason_week() == 8 and GameState.season.round_index == 0,
			"Pressing on from the time trial trains to week 8 and leaves Round 1 to play")
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
		GameState.preseason_advance()
	else:
		var changed := false
		while GameState.preseason_active():
			if GameState.preseason_stop() == "trial":
				GameState.preseason["trial_seen"] = true
				if not changed:
					GameState.set_preseason_block(2, "solid", "skills")
					changed = true
			GameState.preseason_step_week()
			if GameState.preseason_week() == reload_at:
				GameState.save_career()
				GameState.load_career()
				GameState.replay_seed = SUITE_SEED
	return _sig()


func _test_determinism() -> void:
	PreSeason.reload()
	var a := _run_preseason()
	var trial_a := GameState.preseason_trial().duplicate(true)
	_play(3)
	var a_season := _sig()
	var b := _run_preseason()
	_check(a == b and GameState.preseason_trial() == trial_a,
			"The same seed and the same choices give the same pre-season")
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
	GameState.preseason_advance()
	GameState.save_career()
	GameState.load_career()
	_check(not GameState.preseason_active() and GameState.preseason_stop() == "" and GameState.preseason_week() == 8,
			"Loaded after week 8, the pre-season is not run again")


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
	_check(on_inj == off_inj, "Training injures nobody: the league has the same injury list at Round 1 either way (%d, %d)" % [off_inj, on_inj])
	_check(on_mean >= off_mean and on_mean - off_mean < 1.0 and most <= GameState.SEASON_TRAIN_GAIN + 2,
			"A pre-season lifts the league's mean rating by under a point (%.2f to %.2f), nobody by more than the season limit" % [off_mean, on_mean])
	_check(theirs > 0.0 and absf(mine - theirs) < 0.5,
			"On the default plan your list develops like an AI club's (%.2f against %.2f a player)" % [mine, theirs])
	_check(int(counts["sound"]) > 0 and int(counts["strong"]) > 0,
			"AI clubs take different bases into the season by phase (thin %d, sound %d, strong %d)" % [
			int(counts["thin"]), int(counts["sound"]), int(counts["strong"])])


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
	GameState.preseason_on = false
	_roll()
	_save_as_old()
	_play(1)
	var wrap_straight := _sig()
	GameState.preseason_on = true
	_check(GameState.load_career() and GameState.needs_season_wrap() and not GameState.preseason_active(),
			"A save from before pre-seasons loads at the off-season wrap, with no pre-season waiting")
	GameState.replay_seed = SUITE_SEED
	_play(1)
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
	var scene: Control = await _open(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and Router.current() == "preseason",
			"With a pre-season running, the game opens on the pre-season plan, not the hub")
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
			and _label(scene, "BlockCost_0").contains("gone by Round 1"),
			"The block's cost line changes with the load: an early Heavy block is gone by Round 1")
	_check(await _tap(scene.find_child("Focus1_running", true, false), "Running for weeks 4 to 5"),
			"A finger's tap sets the focus for weeks 4 to 5")
	_check(str(GameState.preseason_blocks()[1][1]) == "running"
			and _label(scene, "BlockGain_1").contains("fitness base")
			and _label(scene, "PreSeasonBaseWord").contains("strong fitness base"),
			"The focus changes what the block gains, and the plan says the base it now builds")
	_check(await _tap(scene.find_child("Load2_heavy", true, false), "Heavy for weeks 6 to 7"),
			"A finger's tap sets a Heavy last block")
	_check(_label(scene, "BlockCost_2").contains("Round 1") and not _label(scene, "BlockCost_2").contains("gone"),
			"A Heavy last block says it costs heavy legs in Round 1")
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
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "BlockCost_0").contains("gone by Round 1"),
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
	var named := true
	for i in range(5):
		named = named and _label(scene, "TrialBest_%d" % i) != ""
	for i in range(3):
		named = named and _label(scene, "TrialWorst_%d" % i) != ""
	var first: Dictionary = GameState.list_player(str(GameState.preseason_trial()["best"][0]))
	_check(named and _label(scene, "TrialBest_0") == GameDB.player_display_name(first),
			"The time trial names the first five and the last three home")
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
