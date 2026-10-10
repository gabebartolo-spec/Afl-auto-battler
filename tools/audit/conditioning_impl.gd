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
