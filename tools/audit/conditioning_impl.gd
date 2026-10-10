extends RefCounted
## Season conditioning (season fitness spec, 2026-10-11).
## Args after the impl name: mode, then the mode's own arguments.
##
##   sens [seeds]     Step 0, lever sensitivity. The same matches, the same
##                    seeds, played with the home side unstamped and then with
##                    one conditioning lever set on every home player: tiring
##                    rate (cond_drain), legs off the cap (cond_cap) and
##                    soft-tissue risk (cond_injury). Prints the paired home
##                    margin difference and injuries per arm, mean ± SE.
##   checksum         Plays one seeded home-and-away season (all clubs on
##                    autopilot) and prints one hash of every result. Run on main and on
##                    the branch: equal hashes prove an unstamped league plays
##                    byte-identical matches.
##   league PLAN TIER [seeds]  Paired whole seasons, finals included. Each
##                    seed plays the season twice: every club Steady at
##                    Standard, then a seeded half of the clubs on PLAN with
##                    a TIER department (0 Minimal .. 3 Elite). Prints the
##                    treated clubs' change, mean ± SE over clubs x seeds:
##                    wins by third of the season, finals reached and won,
##                    finals margin, injuries, young players' rating growth,
##                    and where the actual peak fell.
##   phase [seeds]    AI plans by phase (as the game runs them) against an
##                    all-Steady season on the same seed: by phase, the plan,
##                    the peak week and the change in wins and finals.

const PAIRS := [["MEL", "CAR"], ["GEE", "COL"], ["SYD", "WCE"], ["BRL", "ADE"], ["HAW", "ESS"], ["FRE", "STK"]]
const ARMS := [
	["drain 0.90", {"cond_drain": 0.90}],
	["drain 0.95", {"cond_drain": 0.95}],
	["drain 1.05", {"cond_drain": 1.05}],
	["drain 1.10", {"cond_drain": 1.10}],
	["cap -4", {"cond_cap": 4.0}],
	["cap -8", {"cond_cap": 8.0}],
	["injury x0.75", {"cond_injury": 0.75}],
	["injury x1.25", {"cond_injury": 1.25}],
]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1]) if args.size() > 1 else "sens"
	if mode == "checksum":
		_checksum()
	elif mode == "league":
		_league(str(args[2]), int(args[3]), int(args[4]) if args.size() > 4 else 6)
	elif mode == "phase":
		_phase(int(args[2]) if args.size() > 2 else 6)
	else:
		_sens(int(args[2]) if args.size() > 2 else 40)


func _match(h: String, a: String, seed: int, stamp: Dictionary) -> Dictionary:
	# Copies: club_list hands back the shared database rows.
	var hl := []
	for p in GameDB.club_list(h):
		var q: Dictionary = (p as Dictionary).duplicate(true)
		for k in stamp:
			q[k] = stamp[k]
		hl.append(q)
	var al := []
	for p in GameDB.club_list(a):
		al.append((p as Dictionary).duplicate(true))
	var home := Squad.new(h, hl, true, h)
	var away := Squad.new(a, al, false, a)
	home.ai_plans = true
	away.ai_plans = true
	var res: Dictionary = MatchSim.new(home, away, seed).run()
	var sc: Array = res["score"]
	var inj := 0
	for i in res.get("injuries", []):
		if int(i["side"]) == 0:
			inj += 1
	return {"margin": int(sc[0]) - int(sc[1]), "inj": inj}


func _sens(seeds: int) -> void:
	var base := {}
	for pr in PAIRS:
		for s in range(seeds):
			base["%s|%d" % [pr[0], s]] = _match(pr[0], pr[1], 7000 + s, {})
	for arm in ARMS:
		var diffs := []
		var inj_d := []
		for pr in PAIRS:
			for s in range(seeds):
				var b: Dictionary = base["%s|%d" % [pr[0], s]]
				var r := _match(pr[0], pr[1], 7000 + s, arm[1])
				diffs.append(float(int(r["margin"]) - int(b["margin"])))
				inj_d.append(float(int(r["inj"]) - int(b["inj"])))
		print("SENS %-13s | margin %s pts a match | home injuries %s a match | n=%d" % [
				arm[0], _mean_se(diffs), _mean_se(inj_d), diffs.size()])


func _checksum() -> void:
	var gs = Engine.get_main_loop().root.get_node("GameState")
	gs.reset()
	gs.autosave_enabled = false
	# On the branch, every club Steady: the model must then play main's matches.
	if "fitness_ai_by_phase" in gs:
		gs.fitness_ai_by_phase = false
	gs.career_seed = 4242
	gs.replay_seed = 4242
	gs.start_season("MEL", GameDB.club_list("MEL"))
	var h := 0
	var n := 0
	var guard := 0
	while not gs.season.is_regular_done() and guard < 40:
		gs.advance()
		guard += 1
		for res in gs.last_results:
			h = hash([h, str(res["home"]), str(res["away"]), res["score"], res.get("injuries", []), res.get("exertion", {})])
			n += 1
	print("CHECKSUM matches %d | hash %d" % [n, h])


func _mean_se(xs: Array) -> String:
	var n := float(xs.size())
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= n
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	var se := sqrt(v / maxf(1.0, n - 1.0) / n)
	return "%+.2f ± %.2f" % [m, se]


const SOFT := ["hamstring", "calf", "groin", "quad"]


## One whole season from `seed`, finals included. `plans`: club -> plan
## (missing = Steady); `tier`: the department level for the planned clubs.
## by_phase = the game's own AI choice instead. Returns club -> facts.
func _season(seed: int, plans: Dictionary, tier: int, by_phase := false) -> Dictionary:
	var gs = Engine.get_main_loop().root.get_node("GameState")
	gs.reset()
	gs.autosave_enabled = false
	gs.career_seed = seed
	gs.replay_seed = seed
	gs.fitness_ai_by_phase = by_phase
	gs.fitness_hp_override = {}
	gs.start_season("MEL", GameDB.club_list("MEL"))
	var out := {}
	var young := {}
	for code in gs.season.lists:
		var c := str(code)
		if not by_phase:
			if plans.has(c):
				gs.fitness_hp_override[c] = tier
			gs.conditioning[c] = Conditioning.new_season(str(plans.get(c, "steady")), gs.season_year, c,
					gs.fitness_hp_level(c), gs.career_seed)
		out[c] = {"w": [0, 0, 0], "hm": 0.0, "hg": 0, "fg": 0, "fw": 0, "fm": 0.0, "prem": 0,
			"inj": 0, "soft": 0, "young": 0.0, "nyoung": 0, "plan": gs.fitness_plan(c),
			"phase": gs._club_phase(c) if by_phase else "",
			"peak": int(_actual_peak(gs.fitness_record(c), gs.fitness_hp_level(c))[1])}
		for p in gs.season.lists[code]:
			if float(p.get("age", 30.0)) <= ClubBudget.YOUNG_AGE:
				young[str(p["id"])] = [c, int(p.get("overall", 0))]
	var guard := 0
	while not gs.season.is_season_over() and guard < 40:
		gs.advance()
		guard += 1
		for res in gs.last_results:
			var sc: Array = res["score"]
			for side in range(2):
				var c := str(res["home"] if side == 0 else res["away"])
				if not out.has(c):
					continue
				var m := int(sc[side]) - int(sc[1 - side])
				var o: Dictionary = out[c]
				if int(res.get("round", 1)) <= Season.REGULAR_ROUNDS:
					var third := mini(2, (int(res.get("round", 1)) - 1) / 8)
					o["w"][third] += 1 if m > 0 else 0
					o["hm"] += m
					o["hg"] += 1
				else:
					o["fg"] += 1
					o["fw"] += 1 if m > 0 else 0
					o["fm"] += m
		for r in gs.last_injuries:
			var c := str(r["club"])
			if out.has(c):
				out[c]["inj"] += 1
				out[c]["soft"] += 1 if SOFT.has(str(r.get("kind", ""))) else 0
	var premier := str(gs.season.finals.get("premier", ""))
	if out.has(premier):
		out[premier]["prem"] = 1
	for code in gs.season.lists:
		for p in gs.season.lists[code]:
			var y = young.get(str(p["id"]))
			if y != null and out.has(str(y[0])):
				out[y[0]]["young"] += float(int(p.get("overall", 0)) - int(y[1]))
				out[y[0]]["nyoung"] += 1
	return out


func _actual_peak(rec: Dictionary, level: int) -> Array:
	var best := -9.0
	var at := 0
	for w in range(Conditioning.LAST_WEEK + 1):
		var c := Conditioning.actual(rec, w, level)
		if c > best + 0.0001:
			best = c
			at = w
	return [best, at]


func _treated(seed: int, clubs: Array) -> Array:
	var order := clubs.duplicate()
	order.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["treated", seed])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	return order.slice(0, order.size() / 2)


func _league(plan: String, tier: int, seeds: int) -> void:
	var d := {}
	for k in ["w0", "w1", "w2", "hm", "fg", "fw", "prem", "inj", "soft", "young", "young_base", "peak"]:
		d[k] = []
	var fm := []
	for s in range(seeds):
		var seed := 5100 + s
		var base := _season(seed, {}, 1)
		var plans := {}
		for c in _treated(seed, base.keys()):
			plans[c] = plan
		var arm := _season(seed, plans, tier)
		for c in plans:
			var a: Dictionary = arm[c]
			var b: Dictionary = base[c]
			for i in range(3):
				d["w%d" % i].append(float(a["w"][i] - b["w"][i]))
			d["hm"].append(float(a["hm"]) / maxf(1.0, a["hg"]) - float(b["hm"]) / maxf(1.0, b["hg"]))
			for k in ["fg", "fw", "prem", "inj", "soft"]:
				d[k].append(float(a[k]) - float(b[k]))
			d["young"].append(float(a["young"]) / maxf(1.0, a["nyoung"]) - float(b["young"]) / maxf(1.0, b["nyoung"]))
			d["young_base"].append(float(b["young"]) / maxf(1.0, b["nyoung"]))
			d["peak"].append(float(a["peak"]))
			if int(a["fg"]) > 0 and int(b["fg"]) > 0:
				fm.append(float(a["fm"]) / float(a["fg"]) - float(b["fm"]) / float(b["fg"]))
		print("SEED %d done" % seed)
	print("LEAGUE plan %s tier %d | %d treated club-seasons over %d seeds" % [plan, tier, d["hm"].size(), seeds])
	print("  H&A wins by third (R1-8, R9-16, R17-24): %s | %s | %s" % [_mean_se(d["w0"]), _mean_se(d["w1"]), _mean_se(d["w2"])])
	print("  H&A margin a game: %s" % _mean_se(d["hm"]))
	print("  finals games: %s | finals wins: %s | flags: %s" % [_mean_se(d["fg"]), _mean_se(d["fw"]), _mean_se(d["prem"])])
	if not fm.is_empty():
		print("  finals margin a game, clubs in finals both runs (n=%d): %s" % [fm.size(), _mean_se(fm)])
	print("  injuries: %s | soft-tissue: %s" % [_mean_se(d["inj"]), _mean_se(d["soft"])])
	print("  young players' rating growth a player: %s (Steady season: %s)" % [_mean_se(d["young"]), _mean_se(d["young_base"])])
	print("  actual peak week: %s" % _mean_se(d["peak"]))


func _phase(seeds: int) -> void:
	var by := {}
	for s in range(seeds):
		var seed := 5300 + s
		var base := _season(seed, {}, 1)
		var arm := _season(seed, {}, 1, true)
		for c in arm:
			var a: Dictionary = arm[c]
			var b: Dictionary = base[c]
			var ph := str(a["phase"])
			if not by.has(ph):
				by[ph] = {"plans": {}, "peak": [], "wins": [], "fw": [], "soft": []}
			by[ph]["plans"][a["plan"]] = int(by[ph]["plans"].get(a["plan"], 0)) + 1
			by[ph]["peak"].append(float(a["peak"]))
			by[ph]["wins"].append(float(a["w"][0] + a["w"][1] + a["w"][2] - b["w"][0] - b["w"][1] - b["w"][2]))
			by[ph]["fw"].append(float(a["fw"] - b["fw"]))
			by[ph]["soft"].append(float(a["soft"] - b["soft"]))
		print("SEED %d done" % seed)
	for ph in by:
		var r: Dictionary = by[ph]
		print("PHASE %s | plans %s | peak week %s | H&A wins %s | finals wins %s | soft-tissue %s" % [
				ph, r["plans"], _mean_se(r["peak"]), _mean_se(r["wins"]), _mean_se(r["fw"]), _mean_se(r["soft"])])
