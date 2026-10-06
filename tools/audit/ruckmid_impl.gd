extends RefCounted
## Where rucks' and midfielders' disposals go (measurement only, 18 + 5).
## Drafted leagues, one home-and-away season each, every match stepped chain by
## chain so time on ground can be sampled. Per role, per player-game:
##  - the box score against real 2026 (tools/balance/afl_role_rates.json);
##  - share of chains on the ground (time on ground);
##  - stoppage chains: who wins the clearance, who has the first disposal, and
##    how often the clearance winner is the one who disposes of it;
##  - holding-the-ball frees against, a game and per 100 disposals.
## Env: RM_DRAFTS (default 21,22); CLEARANCE_KEEPS=0 runs the old rule as a
## baseline (the first carrier from the whole ground; MatchSim.clearance_keeps).

const ROLES := ["DEF", "MID", "FWD", "RUCK"]
const STATS := ["disposals", "kicks", "handballs", "clearances", "hitouts", "marks", "goals",
		"contested_marks", "tackles", "inside50", "rebounds", "cba"]


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("RM_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("RM_DRAFTS").split(","):
			drafts.append(int(s))
	MatchSim.clearance_keeps = OS.get_environment("CLEARANCE_KEEPS") != "0"
	print("clearance_keeps ", MatchSim.clearance_keeps)
	var T := Ratings.T
	var sums := {}      # role -> {stat: total}
	var pg := {}        # role -> player-games
	var on := {}        # role -> chains on ground (summed over players)
	var avail := {}     # role -> chains available (player-games x chains)
	var clr_role := {}  # role -> clearances credited on stoppage chains
	var first_role := {}  # role -> first disposals of stoppage chains
	var clr_self := 0   # clearance winner also had the first disposal
	var clr_n := 0
	var htb := {}       # role -> holding-the-ball frees against
	var team := {}      # team totals over every side-match
	var sides := 0
	for r in ROLES:
		sums[r] = {}
		pg[r] = 0
		on[r] = 0
		avail[r] = 0
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var role_of := {}
		for c in codes:
			for p in lists[c]:
				role_of[str(p["id"])] = str(p.get("role", ""))
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		for ri in range(season.fixture.size()):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var sim: MatchSim = season.match_sim(str(m["home"]), str(m["away"]), int(d) * 100000 + ri * 100 + mi)
				var chains := 0
				var on_count := {}
				for q in range(4):
					sim.begin_quarter()
					while sim._q_i < sim._q_count:
						if not sim.pending_moment.is_empty():
							sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
							continue
						for side in range(2):
							for p in (sim.squads[side] as Squad).ground:
								on_count[str(p["id"])] = int(on_count.get(str(p["id"]), 0)) + 1
						chains += 1
						var before := sim.events.size()
						var clr_before := {}
						for side in range(2):
							for p in (sim.squads[side] as Squad).ground:
								clr_before[str(p["id"])] = float((sim.player_stats.get(str(p["id"]), {}) as Dictionary).get("clearances", 0.0))
						var stop_flag := sim.at_centre or sim.boundary_throw_in
						sim._q_i += 1
						sim._play_one_chain(T)
						var stoppage := stop_flag
						var first := ""
						for k in range(before, sim.events.size()):
							var e: Dictionary = sim.events[k]
							var kind := str(e.get("kind", ""))
							if kind == "ballup":
								stoppage = true
							if first == "" and (kind == "kick" or kind == "handball"):
								first = str(e.get("player_id", ""))
						if not stoppage:
							continue
						var winner := ""
						for id in clr_before:
							var now := float((sim.player_stats.get(id, {}) as Dictionary).get("clearances", 0.0))
							if now > float(clr_before[id]):
								winner = id
						if winner != "":
							clr_n += 1
							var wr := str(role_of.get(winner, ""))
							clr_role[wr] = int(clr_role.get(wr, 0)) + 1
							if winner == first:
								clr_self += 1
						if first != "":
							var fr := str(role_of.get(first, ""))
							first_role[fr] = int(first_role.get(fr, 0)) + 1
					sim.end_quarter()
				for e in sim.events:
					if str(e.get("kind", "")) == "free" and str(e.get("free_cause", "")) == "holding_ball":
						var hr := str(role_of.get(str(e.get("against_id", "")), ""))
						htb[hr] = int(htb.get(hr, 0)) + 1
				var res := sim.result()
				for side in range(2):
					sides += 1
					var ts: Dictionary = (res.get("team", [{}, {}]) as Array)[side]
					for k in ["disposals", "inside50", "clearances"]:
						team[k] = float(team.get(k, 0.0)) + float(ts.get(k, 0.0))
					team["goals"] = float(team.get("goals", 0.0)) + float(res["goals"][side])
					team["score"] = float(team.get("score", 0.0)) + float(res["score"][side])
					team["behinds"] = float(team.get("behinds", 0.0)) + float(res["score"][side]) - 6.0 * float(res["goals"][side])
				for side_r in sim.rosters():
					for p in side_r:
						var id := str(p["id"])
						var role := str(role_of.get(id, ""))
						if not pg.has(role):
							continue
						pg[role] += 1
						on[role] += int(on_count.get(id, 0))
						avail[role] += chains
						var st: Dictionary = (res.get("players", {}) as Dictionary).get(id, {})
						for s in STATS:
							sums[role][s] = float(sums[role].get(s, 0.0)) + float(st.get(s, 0.0))
		print("league %d done" % int(d))
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/balance/afl_role_rates.json"))["roles"]
	print("## Per player-game, sim (real 2026)")
	print("| stat | " + " | ".join(ROLES) + " |")
	print("|---|---|---|---|---|")
	for s in STATS:
		var cells := PackedStringArray()
		for r in ROLES:
			var v := float(sums[r].get(s, 0.0)) / maxf(1.0, float(pg[r]))
			var rk: String = "inside_50s" if s == "inside50" else ("rebound_50s" if s == "rebounds" else s)
			var rv = (real[r]["per_game"] as Dictionary).get(rk)
			cells.append("%.2f (%s)" % [v, "-" if rv == null else "%.2f" % float(rv)])
		print("| %s | %s |" % [s, " | ".join(cells)])
	var cells2 := PackedStringArray()
	for r in ROLES:
		cells2.append("%.0f%%" % (100.0 * float(on[r]) / maxf(1.0, float(avail[r]))))
	print("| time on ground (chains) | %s |" % " | ".join(cells2))
	var cells3 := PackedStringArray()
	for r in ROLES:
		cells3.append("%.2f a game, %.2f per 100 disposals" % [float(htb.get(r, 0)) / maxf(1.0, float(pg[r])),
				100.0 * float(htb.get(r, 0)) / maxf(1.0, float(sums[r].get("disposals", 0.0)))])
	print("| holding the ball against | %s |" % " | ".join(cells3))
	print("")
	print("TEAM per side-match: disposals %.1f | inside 50s %.1f | clearances %.1f | score %.1f | goals %.2f | accuracy %.1f%% (sides %d)" % [
			float(team.get("disposals", 0.0)) / maxf(1, sides), float(team.get("inside50", 0.0)) / maxf(1, sides),
			float(team.get("clearances", 0.0)) / maxf(1, sides), float(team.get("score", 0.0)) / maxf(1, sides),
			float(team.get("goals", 0.0)) / maxf(1, sides),
			100.0 * float(team.get("goals", 0.0)) / maxf(1.0, float(team.get("goals", 0.0)) + float(team.get("behinds", 0.0))), sides])
	print("## Stoppage chains")
	print("clearances %d; the clearance winner also had the chain's first disposal %.0f%%" % [clr_n, 100.0 * clr_self / maxf(1, clr_n)])
	var tot_f := 0
	for r in first_role:
		tot_f += int(first_role[r])
	for r in ROLES:
		print("| %s | clearances %.0f%% | first disposal %.0f%% |" % [r, 100.0 * int(clr_role.get(r, 0)) / maxf(1, clr_n), 100.0 * int(first_role.get(r, 0)) / maxf(1, tot_f)])
