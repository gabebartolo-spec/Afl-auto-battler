extends SceneTree
## One match's simulation cost, single-threaded (ARD-M1-007 season skip): the same
## ten fixtures and seeds every run, so two builds compare like for like.
##   godot --headless --path . --script tools/perf/match_bench.gd -- [--n 10]
## Prints PERF lines: mean and median ms a match, events a match, and a checksum of
## every score so a speed change that alters a result shows up.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 10
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--n":
			n = int(a[i + 1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.replay_seed = 4242
	gs.start_season("GEE", db.club_list("GEE"))
	var season = gs.season
	var fixtures: Array = season.fixture[0] + season.fixture[1]
	var times := []
	var events := 0
	var check := 0
	for i in range(n):
		var m: Dictionary = fixtures[i % fixtures.size()]
		var sim = season.match_sim(m["home"], m["away"], 1000 + i)
		var t := Time.get_ticks_usec()
		var res: Dictionary = sim.run()
		times.append((Time.get_ticks_usec() - t) / 1000.0)
		events += (res.get("events", []) as Array).size()
		var s: Array = res["score"]
		check = (check * 31 + int(s[0]) * 1000 + int(s[1])) % 1000000007
	times.sort()
	var sum := 0.0
	for x in times:
		sum += x
	print("PERF match mean %.1f ms, median %.1f ms, %d events a match, checksum %d" % [
			sum / n, times[n / 2], events / n, check])
	quit(0)
