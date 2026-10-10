extends RefCounted
## Dual-ruck baseline on main (measurement only; register item 4, "Main ruck").
## For sides with two rucks (Ratings.select_22 dual = 1: the second ruck takes
## the first bench spot), how the work is split today, over paired seeds. A
## second arm plays the same matches with one ruck (dual = 0) for comparison.
## Per side-match with a spare ruck (R1 starts in the ruck spot, R2 on the
## bench):
##  - ruck-spot time: share of chains each is the player in the ruck spot;
##  - who goes up: share of chains each is the contestant _contestant picks
##    (the ruck-spot player if a ruckman, else the best ruckman on the ground);
##  - centre bounces attended (cba), hit-outs and ruck contests per ruck.
## Args after the impl name: first seed and how many (default 1 and 40).
## Clubs are paired from the seed so every club plays dual and single alike.
## Every match gets its own copy of both lists: a match writes to its players
## (injuries), which would otherwise carry into the next arm and seed.


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[1]) if args.size() > 1 else 1
	var count := int(args[2]) if args.size() > 2 else 40
	GameState.replay_seed = 2027
	GameDB.reload()
	var codes: Array = GameDB.club_order.duplicate()
	var n := codes.size()
	var acc := {"dual": _blank(), "single": _blank()}
	var skipped := 0
	for s in range(first, first + count):
		var hi := s % n
		var ai := (s * 7 + 3) % n
		if ai == hi:
			ai = (ai + 1) % n
		var spare_ok := [false, false]
		for arm in ["dual", "single"]:
			var flag: bool = arm == "dual"
			var sq0 := Squad.new(codes[hi], GameDB.club_list(codes[hi]).duplicate(true), true, codes[hi], {"DUAL_RUCK": flag})
			var sq1 := Squad.new(codes[ai], GameDB.club_list(codes[ai]).duplicate(true), false, codes[ai], {"DUAL_RUCK": flag})
			var sim := MatchSim.new(sq0, sq1, s)
			var slot := [{}, {}]      # side -> ruck id -> chains in the ruck spot
			var goes := [{}, {}]      # side -> ruck id -> chains as the contestant
			var onfield := [{}, {}]   # side -> ruck id -> chains on the ground
			var chains := 0
			var rucks := [[], []]     # side -> [R1 id, R2 id or ""]
			for side in range(2):
				var sq: Squad = sim.squads[side]
				var r1 := ""
				for p in sq.ground:
					if str(p["role"]) == "RUCK":
						r1 = str(p["id"])
						break
				var r2 := ""
				for p in sq.bench:
					if str(p.get("role", "")) == "RUCK":
						r2 = str(p["id"])
						break
				rucks[side] = [r1, r2]
				if arm == "dual":
					spare_ok[side] = r2 != ""
			var T := Ratings.T
			for q in range(4):
				sim.begin_quarter()
				while sim._q_i < sim._q_count:
					if not sim.pending_moment.is_empty():
						sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
						continue
					chains += 1
					for side in range(2):
						var sq2: Squad = sim.squads[side]
						for p3 in sq2.ground:
							var pid := str(p3["id"])
							if pid == rucks[side][0] or pid == rucks[side][1]:
								onfield[side][pid] = int(onfield[side].get(pid, 0)) + 1
						var in_slot := sim._by_roles(sq2.ground, ["RUCK"])
						var sid := str(in_slot[0]["id"]) if not in_slot.is_empty() else "-"
						slot[side][sid] = int(slot[side].get(sid, 0)) + 1
						var c := sim._contestant(sq2)
						var cid := str(c[0]["id"]) if not c.is_empty() else "-"
						goes[side][cid] = int(goes[side].get(cid, 0)) + 1
					sim._q_i += 1
					sim._play_one_chain(T)
				sim.end_quarter()
			var res := sim.result()
			var players: Dictionary = res.get("players", {})
			for side in range(2):
				var r1: String = rucks[side][0]
				var r2: String = rucks[side][1]
				if not spare_ok[side]:
					if arm == "dual":
						skipped += 1
					continue
				var a: Dictionary = acc[arm]
				a["sides"] += 1
				a["chains"] += chains
				for pair in [[r1, "r1"], [r2, "r2"]]:
					var id: String = pair[0]
					var k: String = pair[1]
					if id == "":
						continue
					var st: Dictionary = players.get(id, {})
					a[k + "_slot"] += int(slot[side].get(id, 0))
					a[k + "_goes"] += int(goes[side].get(id, 0))
					a[k + "_on"] += int(onfield[side].get(id, 0))
					a[k + "_cba"] += float(st.get("cba", 0.0))
					a[k + "_hit"] += float(st.get("hitouts", 0.0))
					a[k + "_con"] += float(st.get("ruck_contests", 0.0))
				var team: Dictionary = (res.get("team", [{}, {}]) as Array)[side]
				a["bounces"] += float(team.get("centre_bounces", 0.0))
				a["team_hit"] += float(team.get("hitouts", 0.0))
				if arm == "dual":
					# The better ruck by the ruck attribute, whichever slot he starts in.
					var best_id := ""
					var best_v := -1.0
					var worst_v := 1000.0
					for id2 in [r1, r2]:
						var v := _ruck_attr(sim, side, id2)
						if v > best_v:
							best_v = v
							best_id = id2
						worst_v = minf(worst_v, v)
					a["better_goes"] += int(goes[side].get(best_id, 0))
					a["better_cba"] += float((players.get(best_id, {}) as Dictionary).get("cba", 0.0))
					a["gap"] += best_v - worst_v
					if best_id == r1:
						a["r1_better"] += 1
			print("SEED %d %s v %s" % [s, codes[hi], codes[ai]])
	for arm in ["dual", "single"]:
		var a: Dictionary = acc[arm]
		var sd := maxf(1.0, float(a["sides"]))
		var ch := maxf(1.0, float(a["chains"]))
		print("ARM %s side-matches %d chains/match %.0f" % [arm, a["sides"], ch / sd])
		for k in ["r1", "r2"]:
			print("  %s: on the ground %.1f%%, in the ruck spot %.1f%%, goes up %.1f%% of chains; cba %.2f, hit-outs %.1f, ruck contests %.1f per match" % [
					k, 100.0 * float(a[k + "_on"]) / ch, 100.0 * float(a[k + "_slot"]) / ch, 100.0 * float(a[k + "_goes"]) / ch,
					float(a[k + "_cba"]) / sd, float(a[k + "_hit"]) / sd, float(a[k + "_con"]) / sd])
		print("  centre bounces %.1f, side hit-outs %.1f per match" % [float(a["bounces"]) / sd, float(a["team_hit"]) / sd])
		if arm == "dual":
			print("  better ruck (by ruck attr): goes up %.1f%% of chains, R1 is the better one in %.0f%% of sides, gap %.1f points" % [
					100.0 * float(a["better_goes"]) / ch, 100.0 * float(a["r1_better"]) / sd, float(a["gap"]) / sd])
	print("SUMMARY seeds %d skipped_no_spare %d" % [count, skipped])


func _ruck_attr(sim: MatchSim, side: int, id: String) -> float:
	var sq: Squad = sim.squads[side]
	for p in sq.ground + sq.bench:
		if str(p["id"]) == id:
			return float((p["attr"] as Dictionary).get("ruck", 0.0))
	return 0.0


func _blank() -> Dictionary:
	var d := {"sides": 0, "chains": 0, "bounces": 0.0, "team_hit": 0.0, "better_goes": 0, "better_cba": 0.0, "gap": 0.0, "r1_better": 0}
	for k in ["r1", "r2"]:
		d[k + "_slot"] = 0
		d[k + "_goes"] = 0
		d[k + "_on"] = 0
		d[k + "_cba"] = 0.0
		d[k + "_hit"] = 0.0
		d[k + "_con"] = 0.0
	return d
