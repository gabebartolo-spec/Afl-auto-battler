extends SceneTree
## Reproducible workload measurement using the shipped MatchSim and career.
## godot --headless --path . --script tools/workload_probe.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var suite = load("res://tests/test_workload.gd").new()
	var total := 0.0
	var squared := 0.0
	const PAIRS := 128
	var pairs := 0 if OS.get_cmdline_user_args().has("--season-only") else PAIRS
	for i in range(pairs):
		var fresh: Dictionary = suite._sim(42000 + i, 0.0).run()
		var loaded: Dictionary = suite._sim(42000 + i, 50.0).run()
		var delta := float(loaded["score"][0] - loaded["score"][1] - fresh["score"][0] + fresh["score"][1])
		total += delta
		squared += delta * delta
	if pairs > 0:
		var mean := total / pairs
		var se := sqrt(maxf(0.0, (squared - pairs * mean * mean) / (pairs - 1)) / pairs)
		print("Paired seeds: %d; all GEE players at 50 load versus fresh; margin delta %.2f points; SE %.2f" % [pairs, mean, se])
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	seed(43000)
	gs.reset()
	gs.start_season("GEE", root.get_node("GameDB").club_list("GEE"))
	# start_season uses wall-clock time in ordinary careers; fix the fixture
	# and match seeds, then regenerate its opening event for this experiment.
	gs.season = load("res://scripts/sim/Season.gd").new(gs.season.clubs, gs.season.lists, 43000)
	gs._open_board_season()
	while not gs.season.is_regular_done():
		gs.advance()
	var states := {"Fresh": 0, "Carrying a load": 0, "Needs a break": 0}
	var peak := 0.0
	var by_role := {}
	for list in gs.season.lists.values():
		for p in list:
			states[Workload.label(p)] += 1
			peak = maxf(peak, Workload.value(p))
			var role := str(p["role"])
			if not by_role.has(role):
				by_role[role] = {"players": 0, "carrying_or_more": 0, "peak": 0.0}
			by_role[role]["players"] += 1
			by_role[role]["carrying_or_more"] += int(Workload.value(p) >= Workload.CARRYING)
			by_role[role]["peak"] = maxf(float(by_role[role]["peak"]), Workload.value(p))
	print("Season seed 43000, automatic selection: %s; peak load %.2f" % [str(states), peak])
	print("By primary role: %s" % str(by_role))
	quit()
