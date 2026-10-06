extends RefCounted
## Kick lanes (ARD-M4-014): each plan as the home side's, on drafted leagues,
## one home-and-away season each. Per plan: the home margin against the
## balanced plan's on the same matches, scoring, metres, intercepts, and the
## lane mix of its kicks. Env: LN_DRAFTS (default 21,22); LN_OFF=1 plays
## without lanes (MatchSim.kick_lanes off) on the same seeds.

const PLANS := ["balanced", "attacking", "controlled", "defensive", "contest", "through_stars"]


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("LN_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("LN_DRAFTS").split(","):
			drafts.append(int(s))
	MatchSim.kick_lanes = OS.get_environment("LN_OFF") != "1"
	print("kick_lanes ", MatchSim.kick_lanes)
	var rows := {}
	for plan in PLANS:
		rows[plan] = {"margin": 0.0, "score": 0.0, "metres": 0.0, "intercepts": 0.0, "inside50": 0.0,
				"n": 0, "lanes": {}}
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		for ri in range(season.fixture.size()):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var seed := int(d) * 100000 + ri * 100 + mi
				for plan in PLANS:
					var sim: MatchSim = season.match_sim(str(m["home"]), str(m["away"]), seed)
					sim.set_tactics(0, {"gameplan": plan})
					var res := sim.run()
					var r: Dictionary = rows[plan]
					var t0: Dictionary = res["team"][0]
					r["margin"] = float(r["margin"]) + float(res["score"][0]) - float(res["score"][1])
					r["score"] = float(r["score"]) + float(res["score"][0])
					r["metres"] = float(r["metres"]) + float(t0.get("metres_gained", 0.0))
					r["intercepts"] = float(r["intercepts"]) + float((res["team"][1] as Dictionary).get("intercepts", 0.0))
					r["inside50"] = float(r["inside50"]) + float(t0.get("inside50", 0.0))
					r["n"] = int(r["n"]) + 1
					var lanes: Dictionary = r["lanes"]
					for ev in res["events"]:
						if int(ev.get("side", -1)) == 0 and ev.has("lane"):
							lanes[str(ev["lane"])] = int(lanes.get(str(ev["lane"]), 0)) + 1
	MatchSim.kick_lanes = true   # a static: don't leak
	print("lanes_impl: %d matches per plan (drafts %s)" % [int(rows["balanced"]["n"]), str(drafts)])
	var base: Dictionary = rows["balanced"]
	var bn := float(maxi(1, int(base["n"])))
	print("%-14s %8s %8s %7s %8s %9s %8s   %s" % ["home plan", "margin", "vs bal", "score", "metres", "their ic", "i50", "corridor / switch / line"])
	for plan in PLANS:
		var r: Dictionary = rows[plan]
		var n := float(maxi(1, int(r["n"])))
		var lanes: Dictionary = r["lanes"]
		var tot := float(maxi(1, int(lanes.get("corridor", 0)) + int(lanes.get("switch", 0)) + int(lanes.get("line", 0))))
		print("%-14s %+8.2f %+8.2f %7.1f %8.0f %9.1f %8.1f   %.0f / %.0f / %.0f%%" % [plan,
				float(r["margin"]) / n, float(r["margin"]) / n - float(base["margin"]) / bn,
				float(r["score"]) / n, float(r["metres"]) / n, float(r["intercepts"]) / n, float(r["inside50"]) / n,
				100.0 * float(lanes.get("corridor", 0)) / tot, 100.0 * float(lanes.get("switch", 0)) / tot,
				100.0 * float(lanes.get("line", 0)) / tot])
