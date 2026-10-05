extends RefCounted
## The tired-star call end to end (roadmap M4-001's smallest slice): when it
## fires, what each answer applies, how long it lasts and what follows.
## Side 0 is "you", riding the stars (the only policy the call fires under);
## side 1 is an AI club. Every match is played twice from the same seed and
## sides, identical until the call: once resting him, once keeping him on.
## Other moments take their default. Evidence only.
##   godot --headless --path . --script tools/audit/run_audit.gd -- tired_impl
## TIRED_REPS (default 6) matches per pairing.

func _play(home: Array, away: Array, hcode: String, acode: String, seed: int, answer: String) -> Dictionary:
	var a := Squad.new(hcode, home, true, hcode)
	var b := Squad.new(acode, away, false, acode)
	b.ai_plans = true
	var sim := MatchSim.new(a, b, seed)
	sim.set_rotation_policy(0, "stars")
	sim.moment_side = 0
	var out := {"fired": false}
	var star := ""
	for q in range(4):
		sim.begin_quarter()
		if star != "" and sim.current_quarter == int(out["q"]) + 1:
			out["energy_next"] = float(sim.energy.get(star, 100.0))
		while not sim.continue_quarter():
			var m: Dictionary = sim.pending_moment
			var choice := int(m.get("default", 0))
			if str(m.get("kind", "")) == "tired" and int(m.get("side", 0)) == 0:
				star = str(m["player_id"])
				var st: Dictionary = sim.player_stats.get(star, {})
				out["fired"] = true
				out["q"] = sim.current_quarter
				out["energy"] = float(sim.energy.get(star, 100.0))
				out["disp_at"] = float(st.get("disposals", 0.0))
				out["goals_at"] = float(st.get("goals", 0.0))
				out["margin_at"] = sim.score(0) - sim.score(1)
				out["bench"] = (sim.squads[0] as Squad).bench.size()
				choice = 0 if answer == "rest" else 1
				var r := sim.resolve_moment(choice)
				out["outcome"] = str(r.get("outcome", ""))
				out["on_after"] = not sim._on_ground(0, star).is_empty()
				continue
			sim.resolve_moment(choice)
		if star != "" and sim.current_quarter == int(out["q"]):
			# To the break: the span both answers hold for.
			out["margin_qend"] = sim.score(0) - sim.score(1)
			out["disp_qend"] = float((sim.player_stats.get(star, {}) as Dictionary).get("disposals", 0.0)) - float(out["disp_at"])
			out["energy_qend"] = float(sim.energy.get(star, 100.0))
		if star != "":
			# Is he out there at the end of each quarter after the call?
			var key := "on_q%d" % sim.current_quarter
			out[key] = not sim._on_ground(0, star).is_empty()
		sim.end_quarter()
	var res := sim.result()
	var sc: Array = res["score"]
	out["margin"] = int(sc[0]) - int(sc[1])
	if star != "":
		var st2: Dictionary = (res["players"] as Dictionary).get(star, {})
		out["disp_after"] = float(st2.get("disposals", 0.0)) - float(out["disp_at"])
		out["goals_after"] = float(st2.get("goals", 0.0)) - float(out["goals_at"])
		out["energy_end"] = float(sim.energy.get(star, 100.0))
	return out


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var reps := int(OS.get_environment("TIRED_REPS")) if OS.get_environment("TIRED_REPS") != "" else 6
	var games := 0
	var fired := 0
	var by_q := {}
	var energy_sum := 0.0
	var no_bench := 0
	var agree := true
	var t := {"rest": [0.0, 0.0, 0.0, 0.0, 0.0, 0], "keep": [0.0, 0.0, 0.0, 0.0, 0.0, 0]}  # wins, margin after, disp after, goals after, on at end, n
	var deterministic := true
	var by_cq := {}   # call quarter -> answer -> [wins, margin to siren, margin to break, his disp to break, energy next q, n]
	for draft_seed in [31, 32, 33, 34]:
		var lists: Dictionary = lb.drafted_lists(draft_seed)["lists"]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			var h := str(codes[i])
			var w := str(codes[i + 1])
			for rep in range(reps):
				var seed: int = int(draft_seed) * 1000 + i * 10 + rep
				games += 1
				var rest := _play(lists[h], lists[w], h, w, seed, "rest")
				var keep := _play(lists[h], lists[w], h, w, seed, "keep")
				if games <= 3:
					var again := _play(lists[h], lists[w], h, w, seed, "rest")
					deterministic = deterministic and again.hash() == rest.hash()
				if not bool(rest["fired"]):
					continue
				# Identical until the call: the same star, quarter and energy.
				agree = agree and bool(keep["fired"]) and int(keep["q"]) == int(rest["q"]) \
						and is_equal_approx(float(keep["energy"]), float(rest["energy"]))
				fired += 1
				by_q[int(rest["q"])] = int(by_q.get(int(rest["q"]), 0)) + 1
				energy_sum += float(rest["energy"])
				if str(rest["outcome"]).begins_with("No one"):
					no_bench += 1
				for k in ["rest", "keep"]:
					var r: Dictionary = rest if k == "rest" else keep
					var row: Array = t[k]
					row[0] += 1.0 if int(r["margin"]) > 0 else (0.5 if int(r["margin"]) == 0 else 0.0)
					row[1] += float(int(r["margin"]) - int(r["margin_at"]))
					row[2] += float(r["disp_after"])
					row[3] += float(r["goals_after"])
					row[4] += 1.0 if bool(r.get("on_q4", false)) else 0.0
					row[5] += 1
					var cq: Dictionary = by_cq.get(int(r["q"]), {})
					var c: Array = cq.get(k, [0.0, 0.0, 0.0, 0.0, 0.0, 0])
					c[0] += 1.0 if int(r["margin"]) > 0 else (0.5 if int(r["margin"]) == 0 else 0.0)
					c[1] += float(int(r["margin"]) - int(r["margin_at"]))
					c[2] += float(int(r.get("margin_qend", r["margin_at"])) - int(r["margin_at"]))
					c[3] += float(r.get("disp_qend", 0.0))
					c[4] += float(r.get("energy_next", r.get("energy_qend", 0.0)))
					c[5] += 1
					cq[k] = c
					by_cq[int(r["q"])] = cq
	print("TIRED CALL over %d matches riding the stars (evenly matched drafted sides, you at home):" % games)
	print("    fired in %d (%.0f%%), by quarter %s, his energy when asked %.0f on average" % [
			fired, 100.0 * fired / maxf(1, games), str(by_q), energy_sum / maxf(1, fired)])
	print("    rest offered with nobody on the bench: %d" % no_bench)
	print("    paired runs identical up to the call: %s; same seed and answer replays exactly: %s" % [agree, deterministic])
	for k in ["rest", "keep"]:
		var row: Array = t[k]
		var n := maxf(1, row[5])
		print("    %-4s  win %.1f%%  margin from the call %+.1f  his disposals after %.1f  goals after %.2f  on at the final siren %.0f%%" % [
				k, 100.0 * row[0] / n, row[1] / n, row[2] / n, row[3] / n, 100.0 * row[4] / n])
	print("BY THE QUARTER OF THE CALL (margin to the break / to the siren; his disposals to the break; his energy at the next bounce):")
	var qs := by_cq.keys()
	qs.sort()
	for cqk in qs:
		for k in ["rest", "keep"]:
			var c: Array = (by_cq[cqk] as Dictionary).get(k, [0.0, 0.0, 0.0, 0.0, 0.0, 0])
			var n := maxf(1, c[5])
			print("    Q%d %-4s n=%d  win %.1f%%  to break %+.1f  to siren %+.1f  his disposals %.1f  energy next %s" % [
					int(cqk), k, int(c[5]), 100.0 * c[0] / n, c[2] / n, c[1] / n, c[3] / n,
					"-" if int(cqk) == 4 else "%.0f" % (c[4] / n)])
