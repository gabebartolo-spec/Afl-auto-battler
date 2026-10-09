extends RefCounted
## Who intercepts, and where (ARD-M4-012, measurement only). Drafted leagues,
## one home-and-away season each. Per role, per player-game: intercept
## possessions and intercept marks, each role's share of all intercepts, and
## where on the ground they happen (from the intercepting side's view: its
## defensive 50, defensive midfield, attacking midfield, forward 50), beside
## Champion Data's 2025 numbers (docs/research/INTERCEPT_EVIDENCE.md). The
## named loose defender (MatchSim.interceptor) is shown on his own line.
## Env: IC_DRAFTS (default 21,22); IC_OLD=1 plays the old contest
## (MatchSim.zone_intercepts off) on the same seeds, for a before/after;
## IC_NOLOOSE=1 (or the arg "noloose") names no loose man (every reader plays his own man).
## Also the league's leaders, as Champion Data ranks them: each player's
## intercepts a game over a season (10 games or more), the best and the top
## ten's average (2025: Sam Taylor 8.4, top ten 7.7).

const ROLES := ["DEF", "MID", "FWD", "RUCK"]
## Champion Data 2025 (Wheelo): intercepts a game and share of all intercepts.
const REAL := {"DEF": [4.9, 57.0], "MID": [2.5, 23.0], "FWD": [1.1, 15.0], "RUCK": [2.2, 4.0]}
const ZONES := ["D50", "DMID", "AMID", "F50"]


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("IC_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("IC_DRAFTS").split(","):
			drafts.append(int(s))
	MatchSim.zone_intercepts = OS.get_environment("IC_OLD") != "1"
	print("zone_intercepts ", MatchSim.zone_intercepts)
	var ic := {}
	var imk := {}
	var team := {"score": 0.0, "marks": 0.0, "intercepts": 0.0, "inside50": 0.0, "clangers": 0.0}
	var games := {}
	var zones := {}
	var loose_ic := 0.0
	# Where the loose man's intercepts come from (events he is named on).
	var loose_src := {"rebound": 0, "pressure": 0, "mark": 0}
	var loose_games := 0
	var total := 0.0
	var matches := 0
	var no_loose := OS.get_environment("IC_NOLOOSE") == "1" or OS.get_cmdline_user_args().has("noloose")
	var leaders := []
	for r in ROLES:
		ic[r] = 0.0
		imk[r] = 0.0
		games[r] = 0
		zones[r] = {}
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var role_of := {}
		for c in codes:
			for p in lists[c]:
				role_of[str(p["id"])] = str(p.get("role", ""))
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		var by_player := {}
		for ri in range(season.fixture.size()):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var sim: MatchSim = season.match_sim(str(m["home"]), str(m["away"]), int(d) * 100000 + ri * 100 + mi)
				# Outside a career no club plays a loose man (CoachEffects sets
				# ai_plans); in one, every AI side with a good enough reader does.
				for side in range(2):
					if no_loose:
						sim.set_interceptor(side, "", false)
						continue
					if str(sim.interceptor[side]) == "":
						var best := Matchups.best_interceptor((sim.squads[side] as Squad).ground)
						if not best.is_empty():
							sim.set_interceptor(side, str(best["id"]), false)
				var loose := [str(sim.interceptor[0]), str(sim.interceptor[1])]
				var res := sim.run()
				matches += 1
				for side in range(2):
					for k in team:
						team[k] = float(team[k]) + (float(res["score"][side]) if k == "score" else float((res["team"][side] as Dictionary).get(k, 0.0)))
				var stats: Dictionary = res["players"]
				for side in range(2):
					for p in (res["roster"][side] as Array):
						var id := str(p["id"])
						var r := str(role_of.get(id, p.get("role", "")))
						if not ic.has(r):
							continue
						var st: Dictionary = stats.get(id, {})
						if st.is_empty():
							continue
						var n := float(st.get("intercepts", 0.0))
						var bp: Array = by_player.get(id, [0.0, 0, r])
						bp[0] = float(bp[0]) + n
						bp[1] = int(bp[1]) + 1
						by_player[id] = bp
						ic[r] = float(ic[r]) + n
						imk[r] = float(imk[r]) + float(st.get("intercept_marks", 0.0))
						games[r] = int(games[r]) + 1
						total += n
						if id == loose[side]:
							loose_ic += n
							loose_games += 1
				# Where: the intercept events' field position, in the
				# intercepting side's frame.
				for ev in res["events"]:
					var kind := str(ev.get("kind", ""))
					var pid := str(ev.get("player_id", ""))
					var es := int(ev.get("side", -1))
					if es >= 0 and es <= 1 and pid != "" and pid == str(loose[es]):
						if kind == "rebound" or kind == "pressure":
							loose_src[kind] = int(loose_src[kind]) + 1
						elif kind == "mark" and bool(ev.get("intercept", false)):
							loose_src["mark"] = int(loose_src["mark"]) + 1
					if kind != "rebound" and kind != "pressure" and not (kind == "mark" and bool(ev.get("intercept", false))):
						continue
					var side := int(ev.get("side", 0))
					var x := float(ev.get("fp", 0.0)) * (1.0 if side == 0 else -1.0)
					var z := "D50" if x < -35.0 else ("DMID" if x < 0.0 else ("AMID" if x < 35.0 else "F50"))
					var r2 := str(role_of.get(str(ev.get("player_id", "")), ""))
					if zones.has(r2):
						(zones[r2] as Dictionary)[z] = int((zones[r2] as Dictionary).get(z, 0)) + 1
		for id in by_player:
			var bp2: Array = by_player[id]
			if int(bp2[1]) >= 10:
				leaders.append([float(bp2[0]) / float(bp2[1]), str(bp2[2])])
	print("intercept_impl: %d matches (drafts %s)%s" % [matches, str(drafts), " no loose men" if no_loose else ""])
	print("%-6s %10s %10s %10s %10s %12s" % ["role", "a game", "real", "share", "real", "int. marks"])
	for r in ROLES:
		var pg := float(ic[r]) / float(maxi(1, int(games[r])))
		print("%-6s %10.2f %10.1f %9.0f%% %9.0f%% %12.2f" % [r, pg, float(REAL[r][0]),
				100.0 * float(ic[r]) / maxf(1.0, total), float(REAL[r][1]),
				float(imk[r]) / float(maxi(1, int(games[r])))])
	var tl := "per team a game:"
	for k in team:
		tl += "  %s %.1f" % [k, float(team[k]) / float(maxi(1, matches * 2))]
	print(tl)
	print("loose defender: %.2f a game over %d games (real best ~8)" % [loose_ic / float(maxi(1, loose_games)), loose_games])
	var lg := float(maxi(1, loose_games))
	var named := int(loose_src["rebound"]) + int(loose_src["pressure"]) + int(loose_src["mark"])
	print("  from: rebounds %.2f, pressure %.2f, intercept marks %.2f, ball won at a chain's start %.2f a game" % [
			float(loose_src["rebound"]) / lg, float(loose_src["pressure"]) / lg, float(loose_src["mark"]) / lg,
			(loose_ic - float(named)) / lg])
	print("per team a game: %.1f (real 2025: 63.4, 2026: 65.4)" % (total / float(maxi(1, matches * 2))))
	leaders.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var top10 := 0.0
	for i in range(mini(10, leaders.size())):
		top10 += float(leaders[i][0])
	top10 /= float(maxi(1, mini(10, leaders.size())))
	print("leaders (a season each, 10+ games): best %.2f (%s), top ten %.2f a game (real 2025: best 8.4, top ten 7.7)" % [
			float(leaders[0][0]) if not leaders.is_empty() else 0.0, str(leaders[0][1]) if not leaders.is_empty() else "-", top10])
	MatchSim.zone_intercepts = true   # a static: don't leak the old contest
	print("where (intercept events by role, share of that role's):")
	for r in ROLES:
		var zs: Dictionary = zones[r]
		var sum := 0
		for z in ZONES:
			sum += int(zs.get(z, 0))
		var line := "%-6s" % r
		for z in ZONES:
			line += "  %s %3.0f%%" % [z, 100.0 * float(zs.get(z, 0)) / float(maxi(1, sum))]
		print(line)
