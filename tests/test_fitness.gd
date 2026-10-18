extends RefCounted
## Season conditioning: the curve each plan makes, what the department and a
## late change do to it, the stamps a match reads, AI plans by phase, and the
## save. Every season here is seeded.

const Tap := preload("res://tests/tap.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2031


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	_test_curves()
	_test_department()
	_test_late_change()
	_test_stamps()
	_test_match_effect()
	_test_career()
	_test_words()
	_test_plan_copy()
	await _test_screens()
	GameState.fitness_ai_by_phase = false
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Fitness tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _rec(plan: String, offset := 0) -> Dictionary:
	return {"year": 2026, "changes": [[0, plan]], "offset": offset}


func _peak_of(rec: Dictionary, level: int) -> Array:
	var best := -9.0
	var at := 0
	for w in range(Conditioning.LAST_WEEK + 1):
		var c := Conditioning.actual(rec, w, level)
		if c > best:
			best = c
			at = w
	return [best, at]


func _test_curves() -> void:
	var steady := _rec("steady")
	var flat := true
	for w in range(Conditioning.LAST_WEEK + 1):
		for level in range(4):
			flat = flat and Conditioning.actual(steady, w, level) == 0.0
		flat = flat and Conditioning.planned(steady, w) == 0.0
	_check(flat, "Steady all year is level every week, whatever the department")
	var peak := _rec("peak")
	_check(Conditioning.planned(peak, 5) < 0.0 and Conditioning.planned(peak, 10) < 0.0,
			"Peak for September is still building through the early rounds")
	var finals_top := true
	for w in range(Conditioning.FINALS_FIRST, Conditioning.LAST_WEEK + 1):
		finals_top = finals_top and Conditioning.planned(peak, w) == 1.0
	_check(finals_top, "Peak for September is planned to be at its best through every finals week")
	var fast := _rec("fast")
	_check(Conditioning.planned(fast, 3) == 1.0 and Conditioning.planned(fast, 18) < 0.0,
			"A fast start is at its best early and pays for it late")
	var dev := _rec("develop")
	_check(Conditioning.planned(dev, 0) < 0.0
			and Conditioning.planned(dev, 0) == Conditioning.planned(dev, 26),
			"Develop and manage runs a steady, managed load all year")
	_check(Conditioning.xp_mult("develop", {"age": 20}) > 1.0
			and Conditioning.xp_mult("develop", {"age": 27}) == 1.0
			and Conditioning.xp_mult("peak", {"age": 20}) == 1.0,
			"Develop and manage grows the young players only")
	_check(Conditioning.ai_plan("contending") == "peak" and Conditioning.ai_plan("rebuilding") == "develop"
			and Conditioning.ai_plan("building") == "steady",
			"AI clubs plan by where they are in their cycle")
	_check(Conditioning.revision_weeks(10) == [0, 10, 13, 20]
			and Conditioning.revision_weeks(13) == [0, 13, 20],
			"The plan can be revised in the pre-season, at the bye, at round 14 and in the last month")


func _test_department() -> void:
	var peak := _rec("peak")
	_check(float(_peak_of(peak, 3)[0]) > float(_peak_of(peak, 0)[0]),
			"An elite high-performance department peaks higher than a minimal one")
	var spread := [0.0, 0.0]
	for i in range(200):
		spread[0] += absf(float(Conditioning.timing_offset(2026 + i, "MEL", 0, 7)))
		spread[1] += absf(float(Conditioning.timing_offset(2026 + i, "MEL", 3, 7)))
	_check(spread[0] > spread[1] * 2.0,
			"A minimal department lands its peak early or late far more often than an elite one")
	var late := _rec("peak", 3)
	_check(int(_peak_of(late, 3)[1]) > int(_peak_of(peak, 3)[1]),
			"A late timing draw moves the actual peak, not the planned one")
	_check(Conditioning.timing_offset(2027, "GEE", 1, 99) == Conditioning.timing_offset(2027, "GEE", 1, 99),
			"The timing draw is seeded, so a reload replays it")


func _test_late_change() -> void:
	var early := _rec("peak")
	var mid := Conditioning.revise(_rec("steady"), 13, "peak")
	var last := Conditioning.revise(_rec("steady"), 20, "peak")
	var h0 := float(_peak_of(early, 3)[0])
	var h13 := float(_peak_of(mid, 3)[0])
	var h20 := float(_peak_of(last, 3)[0])
	_check(h0 > h13 and h13 > h20 and h20 > 0.0,
			"Switching to a September peak later builds less of it")
	_check(Conditioning.plan_at(mid, 5) == "steady" and Conditioning.plan_at(mid, 13) == "peak"
			and Conditioning.planned(mid, 5) == 0.0,
			"A revision keeps the weeks already played as they were")
	var twice := Conditioning.revise(mid, 13, "develop")
	_check((twice["changes"] as Array).size() == 2 and Conditioning.plan_at(twice, 13) == "develop",
			"Changing your mind in the same week replaces the choice")
	_check(Conditioning.revise(mid, 14, "nonsense") == mid, "An unknown plan changes nothing")


func _test_stamps() -> void:
	_check(Conditioning.stamps(0.0).is_empty(), "A level week stamps nothing on a player")
	var building := Conditioning.stamps(-0.5)
	var peaked := Conditioning.stamps(1.0)
	_check(float(building["cond_drain"]) > 1.0 and float(building["cond_cap"]) > 0.0
			and float(building["cond_injury"]) > 1.0,
			"Building hard tires players faster, takes legs off the top and raises soft-tissue risk")
	_check(float(peaked["cond_drain"]) < 1.0 and float(peaked["cond_cap"]) < 0.0
			and float(peaked["cond_injury"]) < 1.0,
			"At the peak players tire slower, carry their load better and break down less")
	var loaded := {"id": "l", "age": 25, "attr": {"durability": 70}, "workload": 40.0}
	var fresh_p := {"id": "f", "age": 25, "attr": {"durability": 70}}
	Conditioning.stamp_list([loaded, fresh_p], 1.0)
	_check(Workload.energy_cap(loaded) == 84.0 + Conditioning.RESTORE_K and Workload.energy_cap(fresh_p) == 100.0,
			"A peak gives a loaded player back some legs, and never lifts anyone above fresh")
	var managed := Conditioning.stamps(Conditioning.DEVELOP_LEVEL, "develop")
	_check(float(managed["cond_drain"]) > 1.0 and float(managed["cond_injury"]) < 1.0,
			"Develop and manage costs some legs but lowers soft-tissue risk")
	var dev := Conditioning.new_season("develop", 2026, "GEE", 1, 1)
	var pk := Conditioning.new_season("peak", 2026, "GEE", 1, 1)
	_check(Conditioning.ceiling_step(dev, 10, 12, {"age": 20}) == 1
			and Conditioning.ceiling_step(dev, 10, 12, {"age": 26}) == 0
			and Conditioning.ceiling_step(pk, 10, 12, {"age": 20}) == 0,
			"Develop and manage gives a young player a point more room this season")
	var at_bye := Conditioning.revise(pk, 12, "develop")
	var late := Conditioning.revise(Conditioning.new_season("steady", 2026, "GEE", 1, 1), 20, "develop")
	var r14 := Conditioning.revise(pk, 13, "develop")
	_check(Conditioning.ceiling_step(at_bye, 22, 12, {"age": 20}) == 1
			and Conditioning.ceiling_step(late, 22, 12, {"age": 20}) == 0
			and Conditioning.ceiling_step(r14, 22, 12, {"age": 20}) == 0,
			"Only Develop from the pre-season or the bye earns the extra room; a late switch does not")
	var p := {"id": "x", "age": 25, "attr": {"durability": 70}}
	var base_chance := Injuries.chance(p)
	_check(Workload.energy_cap(p) == 100.0 and Workload.drain_mult(p) == 1.0,
			"An unstamped player has exactly the old legs")
	var list := [p]
	Conditioning.stamp_list(list, -1.0)
	_check(Workload.energy_cap(p) == 100.0 - Conditioning.CAP_K and Injuries.chance(p) > base_chance,
			"The week's stamp reaches the energy cap and the injury chance")
	Conditioning.stamp_list(list, 0.0)
	_check(not p.has("cond_drain") and not p.has("cond_cap") and not p.has("cond_injury")
			and Injuries.chance(p) == base_chance,
			"A level week clears last week's stamp")


func _sim(seed: int, stamp: Dictionary) -> MatchSim:
	var home: Array = GameDB.club_list("GEE").duplicate(true)
	var away: Array = GameDB.club_list("COL").duplicate(true)
	for p in home:
		for k in stamp:
			p[k] = stamp[k]
	return MatchSim.new(Squad.new("GEE", home, true, "GEE"), Squad.new("COL", away, false, "COL"), seed)


## The player-effect fixture: the same match, a peaked side against the same
## side unstamped. A neutral stamp plays the identical match.
func _test_match_effect() -> void:
	var plain := _sim(314, {}).run()
	var neutral := _sim(314, Conditioning.stamps(0.0)).run()
	_check(plain["score"] == neutral["score"] and plain["exertion"] == neutral["exertion"],
			"A level week plays exactly the match it did before conditioning")
	var peaked_sim := _sim(314, Conditioning.stamps(1.0))
	peaked_sim.run()
	var plain_sim := _sim(314, {})
	plain_sim.run()
	var legs := [0.0, 0.0]
	for p in plain_sim.squads[0].ground:
		legs[0] += float(plain_sim.energy[str(p["id"])])
		legs[1] += float(peaked_sim.energy.get(str(p["id"]), 0.0))
	_check(legs[1] > legs[0], "A peaked side finishes the match with more in its legs")


func _test_career() -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.fitness_ai_by_phase = false
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.advance()
	_check(FileAccess.get_file_as_string("res://scripts/state/GameState.gd").contains("var fitness_ai_by_phase := true"),
			"AI clubs run the plan their phase calls for by default, now the plan screen is in")
	var stamped := false
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			stamped = stamped or p.has("cond_drain")
	_check(not stamped, "With every club steady, no player carries a conditioning stamp")

	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.fitness_ai_by_phase = true
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.can_revise_fitness() and GameState.set_fitness_plan("peak")
			and GameState.fitness_plan("GEE") == "peak",
			"You set your season plan in the pre-season")
	var matched := true
	var contenders := 0
	for code in GameState.season.lists:
		if str(code) == "GEE":
			continue
		var phase := GameState._club_phase(str(code))
		matched = matched and GameState.fitness_plan(str(code)) == Conditioning.ai_plan(phase)
		contenders += 1 if phase == "contending" else 0
	_check(matched and contenders > 0, "Every AI club runs the plan its phase calls for")
	GameState.advance()
	_check(not GameState.can_revise_fitness() and not GameState.set_fitness_plan("steady")
			and GameState.fitness_plan("GEE") == "peak",
			"Between revision points the plan is locked in")
	var gee_p: Dictionary = GameState.season.lists["GEE"][0]
	_check(gee_p.has("cond_cap") and float(gee_p["cond_drain"]) > 1.0,
			"Your players carry the build of a September peak in round 2")

	var snapshot: Dictionary = GameState.conditioning.duplicate(true)
	_check(GameState.save_career() and GameState.load_career()
			and GameState.conditioning == snapshot,
			"The season plans survive save and load")
	GameState.conditioning = {}
	_check(GameState.fitness_plan("GEE") == "steady"
			and GameState.fitness_plan(str(GameState.season.lists.keys()[1])) == "steady",
			"A save from before conditioning plays on as Steady")

	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var kid := {}
	for q in GameState.season.lists["GEE"]:
		if float(q.get("age", 30.0)) <= ClubBudget.YOUNG_AGE:
			kid = q
			break
	var room := GameState.season_ceiling(kid)
	GameState.set_fitness_plan("develop")
	_check(not kid.is_empty() and GameState.season_ceiling(kid) == room + 1,
			"Your develop plan lifts your young players' season ceiling")
	GameState.set_fitness_plan("peak")
	var before: Dictionary = GameState.season.lists["GEE"][0]
	_check(not before.has("cond_cap"), "Nothing is stamped before the week's first match is built")
	_check(GameState.prepare_interactive_match() and before.has("cond_cap")
			and GameState.pending_sim != null,
			"The match you coach live carries your conditioning, like every simulated one")


func _test_words() -> void:
	_check(Conditioning.status_words(_rec("steady"), 5) == "Steady, no peak planned"
			and Conditioning.status_words(_rec("develop"), 5).begins_with("Managing loads"),
			"Steady and Develop say what they are, with no peak to wait for")
	_check(Conditioning.status_words(_rec("peak"), 0) == "Building, peak due in September",
			"A September peak, in the pre-season: Building, peak due in September")
	_check(Conditioning.status_words(_rec("peak", -4), 0) == "Building, peak due in August",
			"A department that lands early says so: the peak is due in August")
	_check(Conditioning.status_words(_rec("peak"), 20) == "Coming into form, peak due in September"
			and Conditioning.status_words(_rec("peak"), 26) == "Peaking now"
			and Conditioning.status_words(_rec("peak", -6), 26) == "Peak is behind you",
			"The words follow the season: building, coming into form, peaking, behind you")
	_check(Conditioning.status_words(_rec("fast"), 0).contains("April")
			and Conditioning.status_words(_rec("fast"), 10) == "Peak is behind you",
			"A fast start is due in April and behind you by winter")
	var clean := true
	for plan in Conditioning.PLANS:
		for offset in [-8, -3, 0, 3, 8]:
			for w in range(Conditioning.LAST_WEEK + 1):
				var line := Conditioning.status_words(_rec(plan, offset), w)
				for ch in "0123456789%":
					clean = clean and not line.contains(ch)
	_check(clean, "No number or percentage anywhere in the season line's words")
	_check(Conditioning.month_of_week(0) == "March" and Conditioning.month_of_week(13) == "June"
			and Conditioning.month_of_week(20) == "August" and Conditioning.month_of_week(26) == "September",
			"Weeks are months: the first rounds are March, the finals September")
	var kept := Conditioning.revise(_rec("peak"), 13, "peak")
	_check(kept == _rec("peak"), "Keeping your plan at a revision point restarts nothing")
	var back := Conditioning.revise(Conditioning.revise(_rec("peak"), 13, "develop"), 13, "peak")
	_check(back == _rec("peak"), "Changing your mind back in the same week costs nothing")
	_check(Conditioning.next_revision_name(0, 10) == "the bye" and Conditioning.next_revision_name(10, 10) == "round 14"
			and Conditioning.next_revision_name(13, 10) == "the last month"
			and Conditioning.next_revision_name(20, 10) == "",
			"The plan screen says when the next chance to change comes")
	_check(Conditioning.late_cost("peak", 0, 10) == "" and Conditioning.late_cost("steady", 13, 10) == ""
			and Conditioning.late_cost("peak", 13, 10).contains("less time")
			and Conditioning.late_cost("fast", 13, 10).contains("Too late")
			and Conditioning.late_cost("develop", 13, 10).contains("extra room"),
			"A late change says what it costs; an early one costs nothing")


## Every plan and the high-performance department say their upside, their
## downside and the odds, as percentages worked out from the constants the
## curve uses (bible §4, director 2026-10-18); the templates hold no figure.
func _test_plan_copy() -> void:
	var digits := RegEx.create_from_string("[0-9]")
	var templates := [Conditioning.PLAN_UP_PEAK, Conditioning.PLAN_DOWN_PEAK, Conditioning.PLAN_UP_FAST,
			Conditioning.PLAN_DOWN_FAST, Conditioning.PLAN_ODDS, Conditioning.PLAN_ODDS_SURE,
			Conditioning.PLAN_UP_STEADY, Conditioning.PLAN_DOWN_STEADY, Conditioning.PLAN_UP_DEVELOP,
			Conditioning.PLAN_DOWN_DEVELOP, Conditioning.HP_RECOVERY_UP, Conditioning.HP_RECOVERY_DOWN,
			Conditioning.HP_RECOVERY_EVEN, Conditioning.HP_PEAK, Conditioning.HP_ODDS, Conditioning.HP_ODDS_SURE,
			Conditioning.HP_COST_MORE, Conditioning.HP_COST_LESS, Conditioning.HP_COST_EVEN,
			Conditioning.PLAN_DEPARTMENT]
	var literal := templates.filter(func(t): return digits.search(str(t)) != null)
	_check(literal.is_empty(), "No plan or department line carries a number of its own (%s)" % str(literal))
	var b := -Conditioning.BUILD_FLOOR
	for level in range(ClubBudget.LEVELS.size()):
		var h := float(Conditioning.PEAK_HEIGHT[level])
		var peak := Conditioning.plan_effect("peak", level)
		_check(peak.contains("Upside:") and peak.contains("Downside:") and peak.contains("Odds:")
				and peak.contains(Conditioning.pct(Conditioning.DRAIN_K * h) + " slower")
				and peak.contains(Conditioning.pct(Conditioning.INJURY_K * h) + " fewer")
				and peak.contains(Conditioning.legs_pct(Conditioning.RESTORE_K * h) + " more in the legs")
				and peak.contains(Conditioning.pct(Conditioning.DRAIN_K * b) + " faster")
				and peak.contains(Conditioning.legs_pct(Conditioning.CAP_K * b) + " less in the legs")
				and peak.contains(Conditioning.pct(Conditioning.INJURY_K * b) + " more soft-tissue"),
				"Peak for September at %s: the edge and the cost from the curve's constants (%s)" % [ClubBudget.level_label(level), peak])
		var fast := Conditioning.plan_effect("fast", level)
		_check(fast.contains("Upside:") and fast.contains("Downside:") and fast.contains("Odds:")
				and fast.contains(Conditioning.pct(Conditioning.DRAIN_K * h) + " slower")
				and fast.contains("March and April"),
				"A fast start says its early edge and its winter cost (%s)" % fast)
		# The odds are the draw's own: sample timing_offset and compare.
		var hits := 0
		var n := 4000
		for i in range(n):
			if absi(Conditioning.timing_offset(2027 + i % 50, "C%d" % floori(i / 50.0), level, 99)) <= Conditioning.PLATEAU:
				hits += 1
		var share := Conditioning.on_time_share(level)
		_check(absf(float(hits) / float(n) - share) < 0.035,
				"%s: the stated timing odds (%.3f) match the draw (%d in %d)" % [ClubBudget.level_label(level), share, hits, n])
		var odds := Conditioning.on_time_pct(level)
		_check((odds == "" and peak.contains("every season")) or (odds != "" and peak.contains("about " + odds)),
				"%s: the plan says how often its peak lands on time (%s)" % [ClubBudget.level_label(level), odds])
		var dept := ClubBudget.benefit_text("high_performance", level)
		var r := ClubBudget.recovery_mult(level) - 1.0
		var diff := ClubBudget.cost_m(level) - ClubBudget.cost_m(ClubBudget.STANDARD)
		_check(dept == Conditioning.department_words(level)
				and (is_zero_approx(r) or dept.contains(Conditioning.pct(absf(r))))
				and dept.contains(Conditioning.pct(h) + " of its full height")
				and (odds == "" or dept.contains(odds))
				and (is_zero_approx(diff) or dept.contains("$%.1fm" % absf(diff))),
				"The %s high-performance budget says recovery, peak height, timing odds and cost (%s)" % [ClubBudget.level_label(level), dept])
	_check(Conditioning.on_time_share(3) >= 1.0 and Conditioning.on_time_share(0) < Conditioning.on_time_share(1)
			and Conditioning.on_time_share(1) < Conditioning.on_time_share(2),
			"A better department lands the peak on time more often; Elite always does")
	var dev := Conditioning.plan_effect("develop", 1)
	var d := -Conditioning.DEVELOP_LEVEL
	_check(dev.contains("Upside:") and dev.contains("Downside:")
			and dev.contains(Conditioning.pct(Conditioning.DEVELOP_XP) + " more development XP")
			and dev.contains("%d more point" % Conditioning.DEVELOP_CEILING)
			and dev.contains(Conditioning.pct(Conditioning.INJURY_K * d) + " fewer")
			and dev.contains(Conditioning.pct(Conditioning.DRAIN_K * d) + " faster"),
			"Develop and manage says what the young gain and what the side gives up (%s)" % dev)
	var steady := Conditioning.plan_effect("steady", 1)
	_check(steady.contains("Upside:") and steady.contains("Downside:"), "Steady all year has an upside and a downside too")


## The plan on its screens, with a finger's taps: the line on the hub and
## Training, the sheet, picking a plan, Confirm, and the lock between revision
## points.
func _test_screens() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.set_setting("seen_training_intro", true)
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	tree.root.add_child(hub)
	await _frames(tree, 6)
	var line := hub.find_child("SeasonPlanLine", true, false) as Button
	var words := hub.find_child("SeasonPlanWords", true, false) as Label
	_check(line != null and words != null and words.text == "Steady, no peak planned",
			"The hub says where the legs are at in words")
	_check(line != null and (hub.find_child("SeasonPlanSub", true, false) as Label).text.contains("set it before round 1"),
			"In the pre-season the hub line says the plan is yours to set")
	_check(await _tap(line, "the season plan line"), "A finger's tap on the line opens the plan")
	await _frames(tree, 4)
	var sheet := hub.find_child("SeasonPlanSheet", true, false)
	_check(sheet != null and sheet.find_child("SeasonLineChart", true, false) != null
			and sheet.find_child("SeasonPlans", true, false).get_child_count() == 4,
			"The sheet shows the season line and all four plans")
	var confirm := sheet.find_child("SeasonPlanConfirm", true, false) as Button if sheet != null else null
	_check(confirm != null and confirm.disabled, "Confirm waits until you pick a different plan")
	var peak := sheet.find_child("Plan_peak", true, false) as Button if sheet != null else null
	_check(await _tap(peak, "Peak for September"), "A finger's tap picks Peak for September")
	await _frames(tree, 3)
	confirm = sheet.find_child("SeasonPlanConfirm", true, false) as Button
	var shown := sheet.find_child("SeasonPlanSheetWords", true, false) as Label
	_check(confirm != null and not confirm.disabled and GameState.fitness_plan("GEE") == "steady"
			and shown != null and shown.text.begins_with("Building, peak due in"),
			"The choice shows its season line before it is confirmed; nothing is saved yet")
	_check(await _tap(confirm, "Confirm"), "A finger's tap confirms the plan")
	await _frames(tree, 3)
	_check(GameState.fitness_plan("GEE") == "peak", "Confirm sets your season plan")
	var close := sheet.find_child("SeasonPlanClose", true, false) as Button
	_check(await _tap(close, "Close"), "A finger's tap closes the sheet")
	await _frames(tree, 4)
	words = hub.find_child("SeasonPlanWords", true, false) as Label
	_check(hub.find_child("SeasonPlanSheet", true, false) == null
			and words != null and words.text.begins_with("Building, peak due in"),
			"Back on the hub the line has the new plan")
	hub.queue_free()
	await _frames(tree, 2)

	# Between revision points: on view, locked, with when the next chance is.
	GameState.advance()
	var week := GameState.fitness_week()
	var bye := GameState.fitness_bye_week("GEE")
	_check(not GameState.can_revise_fitness() and week > 0 and week != bye,
			"Round 2 is not a revision point")
	var host := Control.new()
	tree.root.add_child(host)
	var locked := SeasonPlanSheet.open(host)
	await _frames(tree, 4)
	_check(locked.find_child("Plan_steady", true, false) == null
			and locked.find_child("SeasonPlanConfirm", true, false) == null
			and locked.find_child("PlanRow_develop", true, false) != null,
			"Locked, the plans stay on view but nothing can be picked")
	var lvl: int = GameState.fitness_hp_level("GEE")
	var peak_e := locked.find_child("PlanEffect_peak", true, false) as Label
	var dept_l := locked.find_child("SeasonPlanDepartment", true, false) as Label
	_check(peak_e != null and peak_e.text == Conditioning.plan_effect("peak", lvl)
			and dept_l != null and dept_l.text == Conditioning.department_line(lvl),
			"The sheet shows each plan's upside, downside and odds at your department's level")
	var note := locked.find_child("SeasonPlanNote", true, false) as Label
	_check(note != null and note.text.contains("You can change it again at"),
			"Locked, the sheet says when the next chance comes")
	host.queue_free()
	await _frames(tree, 2)

	# Training carries the same line, and its tap opens the same sheet.
	var training: Control = load("res://scenes/TrainingScene.tscn").instantiate()
	tree.root.add_child(training)
	await _frames(tree, 6)
	var tline := training.find_child("SeasonPlanLine", true, false) as Button
	_check(tline != null and (training.find_child("SeasonPlanWords", true, false) as Label).text.begins_with("Building"),
			"Training says the same, in the same words")
	_check(await _tap(tline, "the season plan line on Training"), "A finger's tap opens the plan from Training")
	await _frames(tree, 4)
	_check(training.find_child("SeasonPlanSheet", true, false) != null, "Training opens the plan sheet")
	var backed: bool = training.call("handle_back")
	var gone := training.find_child("SeasonPlanSheet", true, false)
	_check(backed and (gone == null or gone.is_queued_for_deletion()),
			"Back closes the plan sheet before leaving Training")
	training.queue_free()
	await _frames(tree, 2)


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
