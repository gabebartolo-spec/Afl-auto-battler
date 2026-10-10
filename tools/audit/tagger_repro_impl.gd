extends RefCounted
## QA reproduction (not for commit): does a chosen tagger keep the job through a
## quarter, or does the job go back to tagger_for's pick while he is rotated off?

func run() -> void:
	GameState.replay_seed = 2027
	var tot_chains := 0
	var chosen_off := 0
	var handed := 0
	var handed_to_default := 0
	for seed in [11, 12, 13, 14, 15, 16, 17, 18]:
		var sq := Squad.new("GEE", GameDB.club_list("GEE"), false, "GEE")
		var sq2 := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
		var sim := MatchSim.new(sq, sq2, seed)
		sim.moment_side = -1
		var ground: Array = sq.ground
		var dflt = MatchSim.tagger_for(ground)
		# Choose the lowest-pressure midfielder on the ground other than the default.
		var pick = null
		for p in ground:
			if MatchSim.midfielder_on_ground(p) and str(p["id"]) != str(dflt["id"]):
				if pick == null or float(p["attr"]["pressure"]) < float(pick["attr"]["pressure"]):
					pick = p
		var opp = MatchSim.tagger_for(sq2.ground)
		var opp_mid = null
		for p in sq2.ground:
			if MatchSim.midfielder_on_ground(p):
				opp_mid = p
				break
		var want := str(pick["id"])
		var dflt_name := GameDB.player_display_name(dflt)
		sim.set_tactics(0, {"gameplan": "balanced", "tag_id": str(opp_mid["id"]), "tagger_id": want})
		sim.begin_quarter()
		var total: int = sim._q_count
		var who_counts := {}
		while sim._q_i < total:
			sim._q_count = sim._q_i + 1
			while not sim.continue_quarter():
				sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
			tot_chains += 1
			var t = sim.tagger_of(0)
			var on := false
			for p in sq.ground:
				if str(p["id"]) == want:
					on = true
			if not on:
				chosen_off += 1
			if t != null and str(t["id"]) != want:
				handed += 1
				var nm := GameDB.player_display_name(t)
				who_counts[nm] = int(who_counts.get(nm, 0)) + 1
				if str(t["id"]) == str(dflt["id"]):
					handed_to_default += 1
		sim._q_count = total
		sim.end_quarter()
		print("seed %d: chosen %s (pressure %s), default %s; chains %d; job elsewhere: %s; tag still on: %s" % [seed,
				GameDB.player_display_name(pick), str(pick["attr"]["pressure"]), dflt_name, total, str(who_counts),
				str(sim.tactics[0].get("tag_id", ""))])
	print("QA REPRO: chains %d, chosen tagger off the ground %d, job with someone else %d (with the assistant's default man %d)" % [
			tot_chains, chosen_off, handed, handed_to_default])
	GameState.replay_seed = 0
