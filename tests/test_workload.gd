extends RefCounted

var failures: Array[String] = []
var checks := 0


func run() -> void:
	_test_budget_model()
	_test_recovery()
	_test_match()
	_test_selection()
	_test_career()
	_test_finals()
	await _test_ui()
	GameState.delete_saved_career()
	print("Workload tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _test_budget_model() -> void:
	var standard := ClubBudget.defaults()
	_check(is_equal_approx(ClubBudget.total_m(standard), ClubBudget.ANNUAL_M),
			"Standard funding in all four departments exactly fills the annual budget")
	var rebuild := {
		"recruiting": 2, "development": 2,
		"high_performance": 0, "football": 0,
	}
	_check(is_equal_approx(ClubBudget.total_m(rebuild), ClubBudget.ANNUAL_M),
			"A rebuild can fund Recruiting and Development strongly by cutting the other two")
	_check(ClubBudget.development_mult(3) > ClubBudget.development_mult(2)
			and ClubBudget.development_mult(2) > ClubBudget.development_mult(1)
			and ClubBudget.development_mult(1) > ClubBudget.development_mult(0),
			"More Development funding always has a larger, diminishing XP benefit")
	_check(ClubBudget.benefit_text("recruiting", 2).contains("20% narrower")
			and ClubBudget.benefit_text("high_performance", 3).contains("20% higher"),
			"Funding benefits are stated as exact effects, not hidden scores")

	var normal := {"id": "normal", "age": 25, "attr": {"durability": 70}, "workload": 50.0}
	var funded := {"id": "funded", "age": 25, "attr": {"durability": 70}, "workload": 50.0}
	Workload.advance_week({"A": [normal], "B": [funded]}, [], "budget",
			{"B": ClubBudget.recovery_mult(3)})
	_check(Workload.value(funded) < Workload.value(normal),
			"Elite High performance produces more weekly recovery than Standard")


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


func _test_career() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
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
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(360, 800)
	var p: Dictionary = GameState.my_list[0]
	p["workload"] = 60.0
	var screen := Control.new()
	screen.set_script(load("res://scripts/ui/SelectionScene.gd"))
	tree.root.add_child(screen)
	for i in range(4):
		await tree.process_frame
	var readiness := screen.find_child("Readiness_" + str(p["id"]), true, false) as Label
	_check(readiness != null and readiness.text == "Needs a break", "Selection shows the player's readiness")
	_check(readiness != null and readiness.size.x <= 360.0 and readiness.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"Readiness wraps within a narrow portrait viewport")
	var sheet := PlayerSheet.open(screen, p)
	for i in range(4):
		await tree.process_frame
	var explanation := sheet.find_child("ProfileReadiness", true, false) as Label
	_check(explanation != null and explanation.text.contains("week out of seniors"),
			"The profile explains how the coach can help a tired player recover")
	screen.queue_free()
	await tree.process_frame
