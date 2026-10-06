extends RefCounted
## Set shots, general-play shots, crumbs and the set-shot call as the sim plays them
## (measurement only; the baseline for ARD-M4-013). Drafted leagues (SS_DRAFTS, default
## 21,22), one home-and-away season each, read from the shot events: a goal or a
## behind carries "set" (a shot from a mark) and fp (where it was kicked from), and a
## crumb carries "crumb". The call is measured separately, on the first SS_ROUNDS rounds
## (default 6), by playing each match live with every set-shot moment answered the same
## way (shoot, pass, bomb): how often a moment offers the call and what each choice scores.
## Each line prints the targets from docs/research/SET_SHOT_EVIDENCE.md beside it.
## Accuracy here is goals over goals plus behinds; the sim records no other shot outcome.
## godot --headless --path . --script tools/audit/run_audit.gd -- setshot_impl

const BANDS := [[0.0, 10.0], [10.0, 20.0], [20.0, 30.0], [30.0, 40.0], [40.0, 50.0], [50.0, 999.0]]
## ABC / Champion Data 2021-25, straight on: set shot, general-play shot.
const TARGET := [[100.0, 89.0], [96.0, 63.0], [85.0, 51.0], [71.0, 38.0], [54.0, 39.0], [33.0, 34.0]]
const SET_SHARE_TARGET := 55.0
## Wheelo / Champion Data 2026, per game: crumbing possessions (no goal target is published).
const CRUMB_TARGET := {"FWD": "general forwards 1.16, key forwards 0.66", "MID": "midfielders 1.09",
		"DEF": "general defenders 0.99, key defenders 0.71", "RUCK": "ruck 0.48"}


func _band(metres: float) -> int:
	for i in range(BANDS.size()):
		if metres >= float(BANDS[i][0]) and metres < float(BANDS[i][1]):
			return i
	return BANDS.size() - 1


func _live(sim: MatchSim, key_for: Callable) -> void:
	sim.moment_side = 0
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(key_for.call(sim.pending_moment)))
		sim.end_quarter()


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("SS_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("SS_DRAFTS").split(","):
			drafts.append(int(s))
	var rounds_for_calls := int(OS.get_environment("SS_ROUNDS")) if OS.get_environment("SS_ROUNDS") != "" else 6
	var goal_line := float(Ratings.T["goal_line"])
	# [set goals, set behinds, general goals, general behinds] by band.
	var counts := []
	for i in range(BANDS.size()):
		counts.append([0, 0, 0, 0])
	var crumb := {}
	var matches := 0
	var policies := {"shoot": 0, "pass": 1, "bomb": 99}
	var offers := {}
	var results := {}
	for k in policies:
		offers[k] = 0
		results[k] = {"goal": 0, "behind": 0, "none": 0}
	var live_matches := 0
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		for ri in range(season.fixture.size()):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var seed := int(d) * 100000 + ri * 100 + mi
				var sim := season.match_sim(str(m["home"]), str(m["away"]), seed)
				var res := sim.run()
				matches += 1
				var role := {}
				for side in range(2):
					for p in res["roster"][side]:
						role[str(p["id"])] = str(p.get("list_role", p.get("role", "")))
				for ev in res["events"]:
					var kind := str(ev["kind"])
					if kind != "goal" and kind != "behind":
						continue
					var metres := goal_line - absf(float(ev["fp"]))
					var b := _band(metres)
					var is_set := bool(ev.get("set_shot", false))
					var idx := (0 if kind == "goal" else 1) + (0 if is_set else 2)
					counts[b][idx] += 1
					if bool(ev.get("crumb", false)):
						var r := str(role.get(str(ev["player_id"]), "?"))
						if not crumb.has(r):
							crumb[r] = [0, 0]
						crumb[r][0 if kind == "goal" else 1] += 1
				if ri < rounds_for_calls:
					live_matches += 1
					for k in policies:
						var want: int = policies[k]
						var s2 := season.match_sim(str(m["home"]), str(m["away"]), seed)
						_live(s2, func(mom):
							if str(mom.get("kind", "")) != "set_shot":
								return int(mom.get("default", 0))
							return mini(want, (mom["options"] as Array).size() - 1))
						for mo in s2.moments:
							if str(mo.get("kind", "")) != "set_shot":
								continue
							offers[k] += 1
							var pts := int(mo.get("points", 0))
							results[k]["goal" if pts >= 6 else ("behind" if pts == 1 else "none")] += 1
	var set_all := 0
	var gen_all := 0
	print("setshot_impl: %d matches (drafts %s); calls measured on %d matches" % [matches, str(drafts), live_matches])
	print("SET vs GENERAL goals/(goals+behinds) by distance from goal (sim | target set, general):")
	for i in range(BANDS.size()):
		var c: Array = counts[i]
		var sg := float(c[0])
		var sb := float(c[1])
		var gg := float(c[2])
		var gb := float(c[3])
		set_all += int(sg + sb)
		gen_all += int(gg + gb)
		print("  %2d-%s m | set %5.1f%% of %5d | general %5.1f%% of %5d | target %.0f%%, %.0f%%" % [
				int(BANDS[i][0]), ("%d" % int(BANDS[i][1])) if float(BANDS[i][1]) < 999.0 else "+",
				100.0 * sg / maxf(1.0, sg + sb), int(sg + sb), 100.0 * gg / maxf(1.0, gg + gb), int(gb + gg),
				float(TARGET[i][0]), float(TARGET[i][1])])
	print("SET share of all shots: %.1f%% (target about %.0f%%)" % [100.0 * set_all / maxf(1.0, float(set_all + gen_all)), SET_SHARE_TARGET])
	print("CRUMB goals and behinds by role (target: no goal rate is published; crumbing possessions a game: %s)" % str(CRUMB_TARGET))
	for r in crumb:
		print("  %s | goals %d | behinds %d | per match %.2f goals" % [r, int(crumb[r][0]), int(crumb[r][1]), float(crumb[r][0]) / maxf(1.0, float(matches))])
	print("CALL: every set-shot moment answered the same way, %d matches, user side 0 only" % live_matches)
	for k in policies:
		var o := float(offers[k])
		print("  %-5s | offered %5d (%.2f a match) | goal %4.1f%% | behind %4.1f%% | no score %4.1f%% | target: none published (play-on and bomb rates not found)" % [
				k, int(o), o / maxf(1.0, float(live_matches)), 100.0 * float(results[k]["goal"]) / maxf(1.0, o),
				100.0 * float(results[k]["behind"]) / maxf(1.0, o), 100.0 * float(results[k]["none"]) / maxf(1.0, o)])
