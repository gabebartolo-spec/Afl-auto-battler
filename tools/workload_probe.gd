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
	for i in range(PAIRS):
		var fresh: Dictionary = suite._sim(42000 + i, 0.0).run()
		var loaded: Dictionary = suite._sim(42000 + i, 50.0).run()
		var delta := float(loaded["score"][0] - loaded["score"][1] - fresh["score"][0] + fresh["score"][1])
		total += delta
		squared += delta * delta
	var mean := total / PAIRS
	var se := sqrt(maxf(0.0, (squared - PAIRS * mean * mean) / (PAIRS - 1)) / PAIRS)
	print("Paired seeds: %d; all GEE players at 50 load versus fresh; margin delta %.2f points; SE %.2f" % [PAIRS, mean, se])
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	gs.start_season("GEE", root.get_node("GameDB").club_list("GEE"))
	while not gs.season.is_regular_done():
		gs.advance()
	var states := {"Fresh": 0, "Carrying a load": 0, "Needs a break": 0}
	var peak := 0.0
	for list in gs.season.lists.values():
		for p in list:
			states[Workload.label(p)] += 1
			peak = maxf(peak, Workload.value(p))
	print("After a regular season with automatic selection: %s; peak load %.2f" % [str(states), peak])
	quit()
