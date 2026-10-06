extends RefCounted
## Set shots (ARD-M4-013). Evenly matched drafted sides; side 0 is "you" and
## gets the set-shot calls. Each policy forces one answer (shoot, pass, bomb)
## on the same seeds, so the three calls are compared on the same marks.
##   CALL  shoot|pass|bomb   per call: goal, behind, no-score rates
##   PACK  bomb               marked / spoiled / defence / through split
##   CRUMB role               who snaps off the pack
##   BAND  metres             every set shot by where it is kicked from:
##                            goals / scoring shots (accuracy), against the
##                            evidence's conversion by distance
##   SHARE                    set shots as a share of scoring shots
## SETSHOT_REPS sets matches per pairing (default 4).

func _play(home: Array, away: Array, hcode: String, acode: String, seed: int, call: String,
		tally: Dictionary, roles: Dictionary) -> void:
	var a := Squad.new(hcode, home, true, hcode)
	var b := Squad.new(acode, away, false, acode)
	b.ai_plans = true
	var sim := MatchSim.new(a, b, seed)
	sim.moment_side = 0
	for q in range(4):
		sim.begin_quarter()
		while not sim.continue_quarter():
			var m: Dictionary = sim.pending_moment
			var pick := int(m.get("default", 0))
			if str(m.get("kind", "")) == "set_shot":
				var opts: Array = m.get("options", [])
				for i in range(opts.size()):
					if str((opts[i] as Dictionary)["key"]) == call:
						pick = i
			var res := sim.resolve_moment(pick)
			if str(res.get("kind", "")) == "set_shot":
				var key := str((res["options"] as Array)[int(res["choice"])]["key"])
				var c: Array = tally["call"].get(key, [0, 0, 0, 0])
				c[0] += 1
				c[1] += 1 if int(res["points"]) == 6 else 0
				c[2] += 1 if int(res["points"]) == 1 else 0
				# The old bomb's goal rate (the offered odds), for the trade-off.
				c[3] += int(1000.0 * float((res["options"] as Array)[int(res["choice"])].get("goal", 0.0)))
				tally["call"][key] = c
		sim.end_quarter()
	var gl := float(Ratings.T["goal_line"])
	for ev in sim.events:
		var kind := str(ev["kind"])
		if kind == "pack":
			tally["pack"][str(ev["outcome"])] = int(tally["pack"].get(str(ev["outcome"]), 0)) + 1
		if kind != "goal" and kind != "behind":
			continue
		if bool(ev.get("crumb", false)):
			var role := str(roles.get(str(ev["player_id"]), "?"))
			tally["crumb"][role] = int(tally["crumb"].get(role, 0)) + 1
		var set := bool(ev.get("set", false))
		tally["shots"][0 if set else 1] += 1
		if set:
			var metres := snappedf(gl - absf(float(ev["fp"])), 5.0)
			var bd: Array = tally["band"].get(metres, [0, 0])
			bd[0] += 1 if kind == "goal" else 0
			bd[1] += 1
			tally["band"][metres] = bd

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var reps := int(OS.get_environment("SETSHOT_REPS")) if OS.get_environment("SETSHOT_REPS") != "" else 4
	for call in ["shoot", "pass", "bomb"]:
		var tally := {"call": {}, "pack": {}, "crumb": {}, "band": {}, "shots": [0, 0]}
		for draft_seed in [21, 22]:
			var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
			var codes: Array = lb.clubs()
			var ratings: Dictionary = lb.club_ratings(lists, codes)
			codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
			var roles := {}
			for code in codes:
				for p in lists[code]:
					roles[str(p["id"])] = str(p.get("role", "?"))
			for i in range(0, codes.size() - 1, 2):
				for rep in range(reps):
					_play(lists[codes[i]], lists[codes[i + 1]], str(codes[i]), str(codes[i + 1]),
							int(draft_seed) * 1000 + i * 10 + rep, call, tally, roles)
		for key in tally["call"]:
			var c: Array = tally["call"][key]
			print("CALL %-5s forced %-5s n %4d | goal %5.1f%% behind %5.1f%% no score %5.1f%% | offered goal %5.1f%%" % [key, call, c[0],
					100.0 * c[1] / maxf(1, c[0]), 100.0 * c[2] / maxf(1, c[0]),
					100.0 * (c[0] - c[1] - c[2]) / maxf(1, c[0]), 0.1 * c[3] / maxf(1, c[0])])
		if call == "bomb":
			var n := 0
			for k in tally["pack"]:
				n += int(tally["pack"][k])
			for k in tally["pack"]:
				print("PACK %-8s %5.1f%% (%d)" % [k, 100.0 * int(tally["pack"][k]) / maxf(1, n), int(tally["pack"][k])])
		print("CRUMB forced %-5s %s" % [call, JSON.stringify(tally["crumb"])])
		if call == "shoot":
			var keys: Array = tally["band"].keys()
			keys.sort()
			for metres in keys:
				var bd: Array = tally["band"][metres]
				print("BAND %2d m  accuracy %5.1f%%  (%d scoring shots)" % [int(metres), 100.0 * bd[0] / maxf(1, bd[1]), bd[1]])
			var sh: Array = tally["shots"]
			print("SHARE set shots %5.1f%% of scoring shots (%d of %d)" % [100.0 * sh[0] / maxf(1, sh[0] + sh[1]), sh[0], sh[0] + sh[1]])
