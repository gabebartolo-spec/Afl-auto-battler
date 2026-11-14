extends RefCounted

const Tap := preload("res://tests/tap.gd")
var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	_t("_test_budget_model")
	_t("_test_budget_allocation_state")
	_t("_test_budget_fold_rule")
	_t("_test_budget_old_save_both_keys")
	_t("_test_budget_old_save_only_football")
	_t("_test_budget_one_spend_drives_plan")
	_t("_test_recovery")
	_t("_test_match")
	_t("_test_selection")
	_t("_test_career")
	_t("_test_finals")
	await _t("_test_ui")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Workload", self))


## A finger's tap on b where it sits on screen (tests/tap.gd), checked; if
## something else takes the tap, the press goes through the handler so the
## rest of the flow is still tested.
func _press(b: Button, what: String) -> void:
	var why: String = await Tap.tap(b)
	_check(why == "", "A finger's tap reaches %s (%s)" % [what, why if why != "" else "it did"])
	if why != "" and is_instance_valid(b):
		b.emit_signal("pressed")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _test_budget_model() -> void:
	var standard := ClubBudget.defaults()
	_check(is_equal_approx(ClubBudget.total_m(standard), 9.0)
			and is_equal_approx(ClubBudget.remaining_m(standard), 1.5),
			"Standard funding in all three departments costs $9.0m and leaves one $1.5m step to spend")
	_check(ClubBudget.AREA_ORDER.size() == 3 and not ClubBudget.AREA_ORDER.has("football")
			and not ClubBudget.AREA_LABEL.values().has("Football department")
			and is_equal_approx(ClubBudget.ANNUAL_M, 10.5),
			"One spend: Recruiting, Development and High performance, $10.5m in all (row 99, director 2026-11-06)")
	var rebuild := {"recruiting": 2, "development": 2, "high_performance": 0}
	_check(is_equal_approx(ClubBudget.total_m(rebuild), ClubBudget.ANNUAL_M),
			"A rebuild can fund Recruiting and Development strongly by cutting High performance")
	# Every three-line allocation: legal exactly when it fits $10.5m, which is
	# any two lines Strong with the third Minimal, never Elite beside Strong.
	var fits := 0
	var sweep_ok := true
	for r in range(4):
		for d in range(4):
			for h in range(4):
				var a := {"recruiting": r, "development": d, "high_performance": h}
				var legal := ClubBudget.total_m(a) <= ClubBudget.ANNUAL_M + 0.001
				if legal:
					fits += 1
				var levels := [r, d, h]
				levels.sort()
				if levels == [0, 2, 2] and not legal:
					sweep_ok = false
				if levels.has(3) and levels.has(2) and legal:
					sweep_ok = false
	_check(sweep_ok and fits == 32,
			"%d of 64 allocations fit $10.5m: any two lines Strong with the third Minimal, never Elite beside Strong" % fits)
	_check(ClubBudget.development_mult(3) > ClubBudget.development_mult(2)
			and ClubBudget.development_mult(2) > ClubBudget.development_mult(1)
			and ClubBudget.development_mult(1) > ClubBudget.development_mult(0),
			"More Development funding always has a larger, diminishing XP benefit")
	_check(ClubBudget.benefit_text("recruiting", 2).contains("20% narrower")
			and ClubBudget.benefit_text("recruiting", 0).contains("1 read in 7 misses his true rating, by up to 7")
			and ClubBudget.benefit_text("recruiting", 3).contains("by up to 4")
			and ClubBudget.benefit_text("high_performance", 3).contains("Legs recover 20% faster")
			and ClubBudget.benefit_text("high_performance", 3).contains("gives 8% more of what it is built for")
			and ClubBudget.benefit_text("high_performance", 0).contains("gives 5% less of what it is built for")
			and ClubBudget.benefit_text("high_performance", 1).contains("Game plans give what they are built for"),
			"Funding benefits are stated as exact effects, not hidden scores, the game plan's edge with them")

	var normal := {"id": "normal", "age": 25, "attr": {"durability": 70}, "workload": 50.0}
	var funded := {"id": "funded", "age": 25, "attr": {"durability": 70}, "workload": 50.0}
	Workload.advance_week({"A": [normal], "B": [funded]}, [], "budget",
			{"B": ClubBudget.recovery_mult(3)})
	_check(Workload.value(funded) < Workload.value(normal),
			"Elite High performance produces more weekly recovery than Standard")


## The Recruiting line's odds on other clubs' players are the reads' own.
## The "1 in N", and the "1 in N under 50 games", are the measured shares
## (tools/balance/rival_reads_measured.json: six seeded careers, every club reading every other list each off-season).
## The "by up to" is the most DraftScouting.pot_read can miss by, its noise
## held to ERROR_CLAMP. And this career's opening lists, read here by every
## club at every level, miss no further and about as often: a little more
## often than over a career, because the reads sharpen as games are played.
func _rival_pot_odds() -> void:
	var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tools/balance/rival_reads_measured.json"))
	var measured: Array = data["pot"]
	var young: Array = data["young"]
	var lists: Dictionary = GameState.season.lists
	var ok := measured.size() == ClubBudget.SCOUT_UNCERTAINTY.size()
	var shown := []
	for level in range(ClubBudget.SCOUT_UNCERTAINTY.size()):
		var stated := int(ClubBudget.RIVAL_POT_MISS_IN[level])
		var stated_worst := int(ClubBudget.RIVAL_POT_WORST_MISS[level])
		var row: Dictionary = measured[level] if level < measured.size() else {}
		if int(round(float(row.get("reads", 0)) / maxf(1.0, float(row.get("misses", 0))))) != stated 				or int(row.get("worst", -1)) != stated_worst:
			ok = false
		var young_row: Dictionary = young[level] if level < young.size() else {}
		if int(round(float(young_row.get("reads", 0)) / maxf(1.0, float(young_row.get("misses", 0))))) 				!= int(ClubBudget.RIVAL_POT_YOUNG_MISS_IN[level]) or int(young_row.get("reads", 0)) < 100000:
			ok = false
		var mult := ClubBudget.scouting_mult(level)
		var most := 0
		for games in range(151):
			var sd := DraftScouting.POT_SD * clampf(1.0 - float(games) / 150.0, 0.3, 1.0) * mult
			most = maxi(most, int(round(DraftScouting.ERROR_CLAMP * sd)) - maxi(1, int(round(sd * 0.8))))
		var reads := 0
		var misses := 0
		var worst := 0
		for reader in lists:
			for code in lists:
				if code == reader:
					continue
				for p in lists[code]:
					var rg: Array = DraftScouting.pot_read(p, str(reader), GameState.career_seed, mult)["range"]
					var pot := maxi(int(p["overall"]), int(p.get("potential", p["overall"])))
					var miss := maxi(maxi(int(rg[0]) - pot, pot - int(rg[1])), 0)
					reads += 1
					misses += int(miss > 0)
					worst = maxi(worst, miss)
		var one_in := int(round(float(reads) / float(maxi(1, misses))))
		shown.append("1 in %d, worst %d, of %d" % [one_in, worst, reads])
		if most != stated_worst or worst > stated_worst or reads < 5000 				or one_in > stated or one_in < stated - 3 				or not ClubBudget.benefit_text("recruiting", level).contains(
						"Other clubs' players: about 1 POT read in %d misses (1\u00a0in\u00a0%d under 50 games), by up to %d."
						% [stated, int(ClubBudget.RIVAL_POT_YOUNG_MISS_IN[level]), stated_worst]):
			ok = false
	_check(ok, "The Recruiting line's odds on other clubs' players are the measured ones, and this career's reads agree (%s)"
			% " / ".join(shown))


func _test_budget_allocation_state() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.open_offseason()
	_check(GameState.department_budget_year == GameState.season_year + 1
			and GameState.department_budget == ClubBudget.defaults()
			and is_equal_approx(GameState.department_budget_spent_m(), 9.0)
			and is_equal_approx(GameState.department_budget_remaining_m(), 1.5),
			"The off-season opens a fresh Standard allocation for the coming year, $1.5m of the $10.5m left")
	_rival_pot_odds()
	var blocked := GameState.set_department_budget("recruiting", 3)
	_check(not bool(blocked.get("ok", true)),
			"You cannot raise a department above the fixed annual budget")
	var spare := GameState.set_department_budget("recruiting", 2)
	var full := GameState.set_department_budget("development", 2)
	_check(bool(spare.get("ok", false)) and not bool(full.get("ok", true))
			and is_equal_approx(GameState.department_budget_remaining_m(), 0.0),
			"The spare $1.5m lifts one line to Strong; a second needs money from elsewhere")
	var cut := GameState.set_department_budget("high_performance", 0)
	var raised := GameState.set_department_budget("development", 2)
	_check(bool(cut.get("ok", false)) and bool(raised.get("ok", false))
			and is_equal_approx(GameState.department_budget_remaining_m(), 0.0),
			"Cutting one department creates room to fund another: two Strong, one Minimal")
	var snapshot: Dictionary = GameState.department_budget.duplicate()
	_check(GameState.save_career() and GameState.load_career()
			and GameState.department_budget == snapshot,
			"The annual department allocation survives save/load")


## The fold of an old save's Football department into High performance
## (ClubBudget.fold_football), over every allocation an old save could hold.
func _test_budget_fold_rule() -> void:
	var legal := 0
	for r in range(4):
		for d in range(4):
			for h in range(4):
				for f in range(4):
					var old := {"recruiting": r, "development": d, "high_performance": h, "football": f}
					var old_m := ClubBudget.cost_m(r) + ClubBudget.cost_m(d) + ClubBudget.cost_m(h) + ClubBudget.cost_m(f)
					if old_m > 12.001:
						continue
					legal += 1
					var got := ClubBudget.fold_football(old)
					var want_h := clampi(h + f - ClubBudget.STANDARD, 0, 3)
					var ok: bool = not got.has("football") and got.size() == 3 \
							and ClubBudget.total_m(got) <= ClubBudget.ANNUAL_M + 0.001 \
							and int(got["high_performance"]) == want_h
					# Every legal old save fits $10.5m (at most $9m, or $10.5m when
					# both were Minimal): the other two lines keep their exact funding.
					ok = ok and int(got["recruiting"]) == r and int(got["development"]) == d
					if not ok:
						_check(false, "Fold of %s gave %s" % [old, got])
						return
	_check(legal == 66,
			"Every allocation an old save could hold (%d of 256 fit $12m) folds into a legal three-line one, High performance at its level plus the Football department's steps from Standard" % legal)
	var both_min := ClubBudget.fold_football({"recruiting": 3, "development": 1, "high_performance": 0, "football": 0})
	_check(int(both_min["recruiting"]) == 3 and int(both_min["development"]) == 1
			and int(both_min["high_performance"]) == 0
			and is_equal_approx(ClubBudget.total_m(both_min), ClubBudget.ANNUAL_M),
			"Both at Minimal with Recruiting Elite: High performance Minimal, Recruiting keeps Elite, exactly $10.5m")
	var no_old := {"recruiting": 2, "development": 1, "high_performance": 0}
	_check(ClubBudget.fold_football(no_old) == no_old, "A new save is left exactly as it is")


## Saves an off-season career, rewrites its budget to `old` in the file, reloads it.
## The Geelong off-season the test before left is reused (a new career costs a
## league reload); only the saved budget lines are under test, and the file's
## are replaced whole.
func _reload_with_old_budget(old: Dictionary) -> bool:
	if GameState.season == null or GameState.my_club != "GEE" or not GameState.offseason_open():
		GameState.reset()
		GameState.start_season("GEE", GameDB.club_list("GEE"))
		GameState.season.round_index = GameState.season.fixture.size()
		GameState.open_offseason()
	if not GameState.save_career():
		return false
	var state := CareerSave.read(GameState.save_path)
	if not state.has("department_budget"):
		return false
	state["department_budget"] = old
	return CareerSave.write(state, CareerSave.read_meta(GameState.save_path), GameState.save_path) \
			and GameState.load_career()


func _test_budget_old_save_both_keys() -> void:
	# An old save: High performance Elite, Football department Minimal,
	# Recruiting Minimal, Development Standard ($6m + $1.5m + $1.5m + $3m).
	var loaded := _reload_with_old_budget(
			{"recruiting": 0, "development": 1, "high_performance": 3, "football": 0})
	_check(loaded, "A save holding both High performance and Football department loads")
	_check(GameState.department_budget == {"recruiting": 0, "development": 1, "high_performance": 2},
			"Football department Minimal folds into High performance: Elite becomes Strong, the rest as saved (%s)"
			% GameState.department_budget)
	_check(is_equal_approx(GameState.department_budget_spent_m(), 9.0)
			and is_equal_approx(GameState.department_budget_remaining_m(), 1.5)
			and GameState.fitness_hp_level(GameState.my_club) == 2,
			"The folded allocation keeps its $9.0m, leaves $1.5m of the $10.5m and drives the season plan's department level")
	_check(GameState.save_career() and GameState.load_career()
			and GameState.department_budget == {"recruiting": 0, "development": 1, "high_performance": 2},
			"Saved again, the career holds only the three lines")


func _test_budget_old_save_only_football() -> void:
	# Only the old key: Football department Minimal, nothing else saved.
	var loaded := _reload_with_old_budget({"football": 0})
	_check(loaded, "A save holding only the Football department line loads")
	_check(GameState.department_budget == {"recruiting": 1, "development": 1, "high_performance": 0},
			"Football department Minimal folds into High performance Minimal; missing lines read Standard (%s)"
			% GameState.department_budget)
	_check(is_equal_approx(GameState.department_budget_remaining_m(), 3.0),
			"The $1.5m it freed and the board's extra $1.5m are there to spend")
	var raised := GameState.set_department_budget("high_performance", 1)
	_check(bool(raised.get("ok", false)) and GameState.department_budget_level("high_performance") == 1,
			"The folded line can be changed like any other in the off-season")
	# Held by no legal old save, but a hand-edited one still lands inside the budget.
	var odd := ClubBudget.fold_football({"football": 3})
	_check(odd == {"recruiting": 0, "development": 1, "high_performance": 3},
			"An over-budget old allocation is trimmed to fit, Recruiting first (%s)" % odd)


func _test_budget_one_spend_drives_plan() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var execs := []
	for level in range(4):
		GameState.department_budget["high_performance"] = level
		GameState._refresh_coach_tactics()
		var t: Dictionary = CoachEffects.table.get(GameState.my_club, {})
		execs.append(float(t.get("exec", 0.0)))
	GameState.department_budget["high_performance"] = ClubBudget.STANDARD
	GameState._refresh_coach_tactics()
	var base := float((CoachEffects.table.get(GameState.my_club, {}) as Dictionary).get("exec", 0.0))
	var ok := base > 0.0
	for level in range(4):
		ok = ok and is_equal_approx(float(execs[level]),
				clampf(base * ClubBudget.tactics_mult(level), 0.75, 1.35))
	_check(ok and float(execs[3]) > float(execs[0]),
			"High performance funding sets how sharply the game plan is carried out (%s)" % [execs])


func _test_recovery() -> void:
	var p := {"id": "test", "age": 25, "attr": {"durability": 70}}
	var lists := {"GEE": [p]}
	_check(Workload.label(p) == "Fresh" and Workload.energy_cap(p) == 100.0,
			"Older players without workload fields start fresh")
	for week in range(8):
		Workload.advance_week(lists, [{"exertion": {"test": 190.0}}], str(week))
	var loaded := Workload.value(p)
	_check(Workload.label(p) == "Needs a break", "Repeated heavy games accumulate workload")
	Workload.advance_week(lists, [{"exertion": {"test": 190.0}}], "7")
	_check(Workload.value(p) == loaded, "A completed week cannot apply workload twice")
	Workload.advance_week(lists, [], "rest")
	_check(Workload.label(p) == "Fresh", "A week without senior football restores readiness")
	var veteran := {"id": "old", "age": 34, "attr": {"durability": 50}, "workload": 50.0}
	var young := {"id": "young", "age": 24, "attr": {"durability": 95}, "workload": 50.0}
	Workload.advance_week({"A": [veteran], "B": [young]}, [], "bye")
	_check(Workload.value(veteran) < 50.0 and Workload.value(young) < Workload.value(veteran),
			"Byes recover everyone; durable younger players recover faster")
	for week in range(100):
		Workload.advance_week(lists, [{"exertion": {"test": 190.0}}], "long%d" % week)
	_check(Workload.value(p) < 60.0, "Repeated heavy games reach a bounded load")
	for week in range(10):
		Workload.advance_week(lists, [], "rest%d" % week)
	_check(Workload.value(p) == 0.0, "A prolonged absence fully clears workload")
	Workload.reset(lists)
	_check(not p.has("workload") and not p.has("workload_week"), "Offseason reset removes load and week marker")


func _sim(seed: int, load_value: float) -> MatchSim:
	var home: Array = GameDB.club_list("GEE").duplicate(true)
	var away: Array = GameDB.club_list("COL").duplicate(true)
	for p in home:
		p["workload"] = load_value
	return MatchSim.new(Squad.new("GEE", home, true, "GEE"), Squad.new("COL", away, false, "COL"), seed)


func _test_match() -> void:
	var sim := _sim(82, 60.0)
	var p: Dictionary = sim.squads[0].ground[0]
	var id := str(p["id"])
	var bench_id := str(sim.squads[0].bench[0]["id"])
	_check(float(sim.energy[id]) <= Workload.energy_cap(p), "Carried load reduces starting energy")
	sim._injury_plan.clear()
	sim._after_chain()
	_check(float(sim.exertion.get(id, 0.0)) > 0.0, "On-ground play records effort")
	_check(not sim.exertion.has(bench_id), "An unused bench player records no effort")
	_check(float(sim.energy[bench_id]) <= 76.0, "Bench recovery respects carried workload")
	sim.energy[id] = 75.0
	sim.current_quarter = 2
	sim.begin_quarter()
	_check(float(sim.energy[id]) == 76.0, "Quarter breaks do not erase carried workload")
	var previous := float(sim.exertion[id])
	sim.squads[0].ground.erase(p)
	sim._after_chain()
	_check(float(sim.exertion[id]) == previous, "Players removed from the ground stop accumulating effort")
	var whole_sim := _sim(99, 50.0)
	whole_sim.moment_side = 0
	var whole := whole_sim.run()
	var live := _sim(99, 50.0)
	live.moment_side = 0
	while live.current_quarter <= 4:
		live.begin_quarter()
		while not live.continue_quarter():
			live.resolve_moment(int(live.pending_moment.get("default", 0)))
		live.end_quarter()
	var stepped := live.result()
	_check(whole["score"] == stepped["score"] and whole["players"] == stepped["players"],
			"Whole and stepped matches retain identical football outcomes")
	_check(whole["exertion"] == stepped["exertion"], "Whole and stepped matches record identical workload")
	stepped["exertion"].clear()
	_check(not live.exertion.is_empty(), "Results cannot mutate the match effort ledger")
	_check(Ratings.available(p), "Workload does not prohibit manual selection")


func _test_selection() -> void:
	var list: Array = GameDB.club_list("GEE").duplicate(true)
	var rucks := list.filter(func(p): return str(p["role"]) == "RUCK")
	var tired: Dictionary = rucks[0]
	var fresh: Dictionary = rucks[1]
	for p in rucks:
		p["overall"] = 50.0
		p.erase("expects_game")
	tired["overall"] = 74.0
	tired["workload"] = 100.0
	fresh["overall"] = 72.0
	var automatic := Ratings.select_22(list)
	var starting_ruck: Dictionary = automatic["ground"].filter(func(p): return str(p["role"]) == "RUCK")[0]
	_check(str(starting_ruck["id"]) == str(fresh["id"]), "Auto-pick weighs freshness when ability is comparable")
	var manual := Ratings.select_side(list, {"RUCK": [str(tired["id"])]})
	starting_ruck = manual["ground"].filter(func(p): return str(p["role"]) == "RUCK")[0]
	_check(str(starting_ruck["id"]) == str(tired["id"]), "The coach can still select a loaded player")


func _loads() -> Dictionary:
	var out := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			out[str(p["id"])] = [Workload.value(p), str(p.get("workload_week", ""))]
	return out


## Geelong before Round 1, the career the test before left reused when it is
## exactly that (a new career costs a league reload).
func _season_start() -> void:
	if GameState.season == null or GameState.my_club != "GEE" or GameState.season.round_index != 0 \
			or GameState.offseason_open() or GameState.season.is_season_over():
		GameState.reset()
		GameState.start_season("GEE", GameDB.club_list("GEE"))


func _test_career() -> void:
	_season_start()
	GameState.advance()
	var before := _loads()
	var all_applied := true
	var some_loaded := false
	for state in before.values():
		all_applied = all_applied and not str(state[1]).is_empty()
		some_loaded = some_loaded or float(state[0]) > 0.0
	_check(all_applied and some_loaded, "A career week applies recovery and effort to human and AI lists")
	_check(GameState.save_career(), "A career with workload saves")
	GameState.advance()
	var next := _loads()
	_check(GameState.load_career() and _loads() == before, "Save/load preserves workload and week markers")
	GameState.advance()
	_check(_loads() == next, "The next week's workload replays identically after loading")
	Workload.reset(GameState.season.lists)
	GameState.save_career()
	GameState.load_career()
	var fresh := true
	for state in _loads().values():
		fresh = fresh and float(state[0]) == 0.0
	_check(fresh, "A save without workload fields loads as fresh")


func _test_finals() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.season.ladder["GEE"]["pts"] = 100
	GameState.ensure_finals()
	for p in GameState.my_list:
		p["workload"] = 50.0
	GameState.advance()
	var rested := true
	for p in GameState.my_list:
		rested = rested and Workload.value(p) < 50.0
	_check(GameState.last_match.is_empty() and rested, "A top seed recovers during the wildcard bye")
	while not GameState.season.is_season_over():
		GameState.advance()
	var last_week := true
	for state in _loads().values():
		last_week = last_week and str(state[1]).ends_with("|F|5")
	_check(last_week, "Grand Final recovery applies after preliminary final recovery")
	for p in GameState.my_list:
		p["workload"] = 80.0
	_check(GameState.start_next_season(), "The next season starts")
	var fresh := true
	for state in _loads().values():
		fresh = fresh and float(state[0]) == 0.0
	_check(fresh, "The actual offseason clears workload across all clubs")


func _test_ui() -> void:
	_season_start()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(360, 800)
	var p: Dictionary = GameState.my_list[0]
	p["workload"] = 60.0
	var screen := Control.new()
	screen.set_script(load("res://scripts/ui/SelectionScene.gd"))
	tree.root.add_child(screen)
	for i in range(4):
		await tree.process_frame
	# Selection shows his load as a number (row 183), red at Needs a break; the words are the tooltip.
	var readiness := screen.find_child("Fatigue_" + str(p["id"]), true, false) as Label
	_check(readiness != null and readiness.text == "60", "Selection shows the player's fatigue as a number")
	_check(readiness != null and readiness.get_theme_color("font_color") == UiKit.BAD,
			"A player who needs a break shows it in the bad colour")
	_check(readiness != null and readiness.get_global_rect().end.x <= 360.0, "The number fits a narrow portrait viewport")
	var sheet := PlayerSheet.open(screen, p)
	for i in range(4):
		await tree.process_frame
	var explanation := sheet.find_child("ProfileReadiness", true, false) as Label
	_check(explanation != null and explanation.text.contains("week out of seniors"),
			"The profile explains how the coach can help a tired player recover")
	sheet.queue_free()
	# A rival's load, mood and promises are private: never on his card or profile.
	var other_code := "ADE"
	var theirs: Array = GameDB.club_list(other_code)
	var rp: Dictionary = theirs[0]
	rp["workload"] = 60.0
	rp["club"] = other_code
	var tb := TeamBuilder.new()
	tb.setup({"mid": [rp["id"]]}, false, theirs, true)
	tree.root.add_child(tb)
	for i in range(3):
		await tree.process_frame
	_check(tb.find_child("Readiness_" + str(rp["id"]), true, false) == null,
			"A rival's card never shows his load")
	var rsheet := PlayerSheet.open(screen, rp)
	for i in range(3):
		await tree.process_frame
	_check(rsheet.find_child("ProfileReadiness", true, false) == null,
			"A rival's profile never shows his load")
	var rstate := rsheet.find_child("ProfileState", true, false) as Label
	_check(rstate != null and not rstate.text.contains("Mood"), "A rival's profile never shows his mood")
	var plan_leak := false
	for lb in rsheet.find_children("*", "Label", true, false):
		if (lb as Label).text.begins_with("Development:"):
			plan_leak = true
	_check(not plan_leak, "A rival's profile never shows his training plan")
	rsheet.queue_free()
	tb.queue_free()
	screen.queue_free()
	await tree.process_frame

	# The annual allocation must remain readable and tappable on the same
	# narrow portrait viewport used for the Android playtest.
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.open_offseason()
	# Return visit: the first-visit intros (FirstVisitIntro.gd) have their own suite.
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		GameState.set_setting("seen_%s_intro" % key, true)
	var offseason: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	tree.root.add_child(offseason)
	for i in range(4):
		await tree.process_frame
	var budget_tab := offseason.find_child("Tab_budget", true, false) as Button
	_check(budget_tab != null, "The off-season exposes the annual Budget tab")
	if budget_tab != null:
		await _press(budget_tab, "the Budget tab")
		for i in range(4):
			await tree.process_frame
	var budget_summary := offseason.find_child("BudgetSummary", true, false) as Label
	var benefit := offseason.find_child("BudgetBenefit_recruiting", true, false) as Label
	var next_benefit := offseason.find_child("BudgetNext_recruiting", true, false) as Label
	var lower := offseason.find_child("BudgetLower_recruiting", true, false) as Button
	var raise := offseason.find_child("BudgetRaise_recruiting", true, false) as Button
	_check(budget_summary != null and budget_summary.text.contains("$9.0m allocated")
			and budget_summary.text.contains("$1.5m remaining"),
			"The Budget tab states exactly how much is allocated and what is left of the $10.5m")
	_check(benefit != null and benefit.text.contains("standard")
			and next_benefit != null and next_benefit.text.contains("20% narrower"),
			"Current and next Recruiting effects are visible before spending")
	_check(next_benefit != null and next_benefit.autowrap_mode != TextServer.AUTOWRAP_OFF
			and lower != null and raise != null
			and lower.custom_minimum_size.y >= 44 and raise.custom_minimum_size.y >= 44,
			"Budget choices wrap cleanly and keep phone-sized touch targets")
	# Row 99: the one spend line. A finger lowers Recruiting, then raises High performance.
	_check(offseason.find_child("Budget_football", true, false) == null
			and offseason.find_child("Budget_high_performance", true, false) != null,
			"The Budget tab has one High performance line and no Football department")
	if lower != null:
		await _press(lower, "Lower Recruiting")
		for i in range(4):
			await tree.process_frame
	var hp_raise := offseason.find_child("BudgetRaise_high_performance", true, false) as Button
	_check(hp_raise != null and not hp_raise.disabled, "With Recruiting cut, High performance can be raised")
	if hp_raise != null:
		await _press(hp_raise, "Raise High performance")
		for i in range(4):
			await tree.process_frame
	var hp_benefit := offseason.find_child("BudgetBenefit_high_performance", true, false) as Label
	_check(GameState.department_budget_level("high_performance") == 2
			and hp_benefit != null and hp_benefit.text.contains("gives 5% more of what it is built for"),
			"Tapped to Strong, High performance states the game plan's edge it now carries")
	# The director's $10.5m: with Recruiting at Minimal, a finger lifts
	# Development to Strong too, and the budget is full.
	var dev_raise := offseason.find_child("BudgetRaise_development", true, false) as Button
	_check(dev_raise != null and not dev_raise.disabled,
			"With $1.5m left, Development can be raised as well")
	if dev_raise != null:
		await _press(dev_raise, "Raise Development")
		for i in range(4):
			await tree.process_frame
	budget_summary = offseason.find_child("BudgetSummary", true, false) as Label
	hp_raise = offseason.find_child("BudgetRaise_high_performance", true, false) as Button
	_check(GameState.department_budget_level("development") == 2
			and GameState.department_budget_level("recruiting") == 0
			and budget_summary != null and budget_summary.text.contains("$10.5m allocated")
			and budget_summary.text.contains("$0.0m remaining")
			and hp_raise != null and hp_raise.disabled,
			"Two lines Strong and Recruiting Minimal fill the $10.5m; nothing more can be raised")
	offseason.queue_free()
	await tree.process_frame
