extends RefCounted
## Scratch measurement (not for merge): the two match_visual metrics that failed
## on #606, over many seeds instead of the test's single seed 42, so a shift in
## their distribution can be told from one seed sitting at the edge.
##   worst   the largest distance between where the ball is when an event is
##           released and where the log says it is (test bar: under 15.0 m);
##   hb_kick handballs drawn as kicks, of hb_total (test bar: at most
##           hb_total / 50, with hb_total over 100).
## Same code as tests/test_match_visual.gd (_test_full_playback and
## _test_truth) on RIC v SYD with the suite's seed. Args after the impl name:
## first seed and how many (default 1 and 40). Measurement only.


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[1]) if args.size() > 1 else 1
	var count := int(args[2]) if args.size() > 2 else 40
	GameState.replay_seed = 2027
	GameDB.reload()
	var worsts := []
	var kicks := []
	var over_bar := 0
	for s in range(first, first + count):
		var sim := MatchSim.new(Squad.new("RIC", GameDB.club_list("RIC"), true, "RIC"),
				Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), s)
		var res := sim.run()
		res["home"] = "RIC"
		res["away"] = "SYD"
		res["label"] = "Round 1"
		var worst := _worst_release(res)
		var hb := _handballs(res)
		worsts.append(worst)
		kicks.append(float(hb[1]) / maxf(1.0, float(hb[0])))
		var fail_a := worst >= 15.0
		var fail_b := int(hb[0]) > 100 and int(hb[1]) > int(hb[0]) / 50
		if fail_a or fail_b:
			over_bar += 1
		print("SEED %d worst %.2f hb_total %d hb_kick %d bar_a_fail %d bar_b_fail %d" % [s, worst, int(hb[0]), int(hb[1]), 1 if fail_a else 0, 1 if fail_b else 0])
	worsts.sort()
	kicks.sort()
	print("SUMMARY seeds %d worst_median %.2f worst_p90 %.2f worst_max %.2f hb_kick_share_median %.4f hb_kick_share_max %.4f seeds_over_a_bar %d" % [
			count, worsts[worsts.size() / 2], worsts[int(worsts.size() * 0.9)], worsts[worsts.size() - 1],
			kicks[kicks.size() / 2], kicks[kicks.size() - 1], over_bar])


func _worst_release(res: Dictionary) -> float:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var dt := 1.0 / 60.0 * 4.0
	var guard := 0
	var limit := int(6000.0 / dt)
	while not d.idle() and guard < limit:
		guard += 1
		d.advance(dt)
	var worst := 0.0
	for a in d.arrivals:
		worst = maxf(worst, absf((a["pos"] as Vector2).x - float(a["want_x"])))
	return worst


func _handballs(res: Dictionary) -> Array:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var h := 1.0 / 30.0
	var hb_total := 0
	var hb_as_kick := 0
	var last_from := Vector2.INF
	var guard := 0
	while not d.idle() and guard < 400000:
		guard += 1
		d.advance(h)
		var mode := str(d.ball["mode"])
		if mode == "flight" and (d.ball["from"] as Vector2) != last_from:
			last_from = d.ball["from"]
			var k := int(d._beat.get("k", -1))
			var pk: int = d._prev_real(k) if k >= 0 else -1
			if pk >= 0 and str((d.events[pk] as Dictionary).get("kind", "")) == "handball" \
					and MatchDirector.DISPOSALS.has(str((d.events[k] as Dictionary).get("kind", ""))) \
					and d._restart(k) == "open":
				hb_total += 1
				if float(d.ball["apex"]) >= 2.5:
					hb_as_kick += 1
	return [hb_total, hb_as_kick]
