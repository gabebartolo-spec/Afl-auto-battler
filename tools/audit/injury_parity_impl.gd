extends RefCounted
## Autosim vs played-match injuries (roadmap §1.11, "Autosim vs played-match
## injury-rate parity audit"). Drafted leagues; neighbours in strength play
## each other. Side 0 is "you". Every match is played from the same lists,
## selections and seed in each mode:
##   auto  - Season.simulate's path: run(), no coach (moment_side -1)
##   live  - the watched path: moments offered to side 0 and answered with
##           their default call, quarter by quarter, as MatchScene steps it
## and, for live, under each rotation policy the coach box offers. "live
## other seed" replays live with the seed a watched match really gets
## (Season.next_seed(99) instead of the fixture's), so it is the same fixture
## but not the same dice: it shows the rate, not the replay.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- injury_parity_impl

const DRAFTS := [31, 32, 33, 34]
const SEEDS_PER_PAIR := 25
const MODES := ["auto", "live normal", "live hard", "live stars", "live other seed"]

var stats := {}


func _new_stats() -> Dictionary:
	return {"team_games": 0, "player_games": 0, "injuries": 0, "start_inj": 0,
			"bench_inj": 0, "bench_games": 0, "start_games": 0, "concussions": 0,
			"weeks": 0, "planned": 0, "sev": {}, "per_side": [0, 0], "side_games": [0, 0]}


func _play(home: Array, away: Array, hcode: String, acode: String, seed: int, mode: String) -> Dictionary:
	var a := Squad.new(hcode, home, true, hcode)
	var b := Squad.new(acode, away, false, acode)
	b.ai_plans = true
	var s := seed
	if mode == "live other seed":
		s = seed * 31 + 99
	var sim := MatchSim.new(a, b, s)
	var starters := [{}, {}]
	for side in range(2):
		for p in (sim.squads[side] as Squad).ground:
			starters[side][str(p["id"])] = true
	var planned := sim._injury_plan.size()
	if mode == "auto":
		sim.run()
	else:
		sim.moment_side = 0
		var rot := "normal"
		if mode == "live hard":
			rot = "hard"
		elif mode == "live stars":
			rot = "stars"
		sim.set_rotation_policy(0, rot)
		while sim.current_quarter <= 4:
			sim.begin_quarter()
			while not sim.continue_quarter():
				sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
			sim.end_quarter()
		if sim.needs_extra_time():
			sim.run_extra_time()
	return {"sim": sim, "starters": starters, "planned": planned}


func _tally(st: Dictionary, out: Dictionary) -> void:
	var sim: MatchSim = out["sim"]
	st["planned"] += int(out["planned"])
	for side in range(2):
		st["team_games"] += 1
		st["side_games"][side] += 1
		var played: Dictionary = sim._played[side]
		st["player_games"] += played.size()
		for id in played:
			if (out["starters"][side] as Dictionary).has(id):
				st["start_games"] += 1
			else:
				st["bench_games"] += 1
	for inj in sim.injuries:
		var side := int(inj["side"])
		st["injuries"] += 1
		st["per_side"][side] += 1
		st["weeks"] += int(inj["weeks"])
		if str(inj["kind"]) == "concussion":
			st["concussions"] += 1
		if (out["starters"][side] as Dictionary).has(str(inj["id"])):
			st["start_inj"] += 1
		else:
			st["bench_inj"] += 1
		var w := int(inj["weeks"])
		var band := "1" if w <= 1 else ("2" if w == 2 else ("3-4" if w <= 4 else ("5-8" if w <= 8 else "9+")))
		st["sev"][band] = int(st["sev"].get(band, 0)) + 1


func _key(sim: MatchSim) -> String:
	var ids := []
	for inj in sim.injuries:
		ids.append("%d:%s:%d" % [int(inj["side"]), str(inj["id"]), int(inj["weeks"])])
	ids.sort()
	return ",".join(ids)


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	for m in MODES:
		stats[m] = _new_stats()
	var same_set := 0
	var pairs := 0
	var t0 := Time.get_ticks_msec()
	for draft_seed in DRAFTS:
		var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			var h := str(codes[i])
			var w := str(codes[i + 1])
			for k in range(SEEDS_PER_PAIR):
				var seed: int = int(draft_seed) * 100003 + i * 1009 + k * 7919 + 17
				var keys := {}
				for m in MODES:
					var out := _play(lists[h], lists[w], h, w, seed, m)
					_tally(stats[m], out)
					keys[m] = _key(out["sim"])
				pairs += 1
				if keys["auto"] == keys["live normal"]:
					same_set += 1
		print("draft %d done (%d s)" % [draft_seed, (Time.get_ticks_msec() - t0) / 1000])
	print("")
	print("matches per mode: %d (%d team-games)" % [pairs, pairs * 2])
	print("auto and live (normal, same seed) had the identical injury list in %d of %d matches (%.1f%%)"
			% [same_set, pairs, 100.0 * same_set / pairs])
	print("")
	print("| mode | inj/team-game | inj/player-game | starter inj/game | bench inj/game | you / them per game | mean weeks | concussion share | planned that happened | severity 1/2/3-4/5-8/9+ |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for m in MODES:
		var st: Dictionary = stats[m]
		var sev := []
		for band in ["1", "2", "3-4", "5-8", "9+"]:
			sev.append("%.0f%%" % (100.0 * int(st["sev"].get(band, 0)) / maxi(1, int(st["injuries"]))))
		print("| %s | %.3f | %.4f | %.4f | %.4f | %.3f / %.3f | %.2f | %.1f%% | %.1f%% | %s |" % [m,
				float(st["injuries"]) / st["team_games"],
				float(st["injuries"]) / st["player_games"],
				float(st["start_inj"]) / maxi(1, int(st["start_games"])),
				float(st["bench_inj"]) / maxi(1, int(st["bench_games"])),
				float(st["per_side"][0]) / st["side_games"][0], float(st["per_side"][1]) / st["side_games"][1],
				float(st["weeks"]) / maxi(1, int(st["injuries"])),
				100.0 * st["concussions"] / maxi(1, int(st["injuries"])),
				100.0 * st["injuries"] / maxi(1, int(st["planned"])),
				" / ".join(sev)])
	print("")
	for m in MODES:
		var st: Dictionary = stats[m]
		print("%s: %d injuries, %d player-games (%d starters, %d off the bench), %d planned" % [m,
				st["injuries"], st["player_games"], st["start_games"], st["bench_games"], st["planned"]])
