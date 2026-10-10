extends RefCounted
## Scratch measurement (not for merge): which event is released far from its
## logged spot on the suite's fixture (RIC v SYD). Args: seed (default 42).
## Prints every arrival over 10 m and the events around the worst one.


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var s := int(args[1]) if args.size() > 1 else 42
	GameState.replay_seed = 2027
	GameDB.reload()
	var sim := MatchSim.new(Squad.new("RIC", GameDB.club_list("RIC"), true, "RIC"),
			Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD"), s)
	var res := sim.run()
	res["home"] = "RIC"
	res["away"] = "SYD"
	res["label"] = "Round 1"
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var dt := 1.0 / 60.0 * 4.0
	var guard := 0
	while not d.idle() and guard < int(6000.0 / dt):
		guard += 1
		d.advance(dt)
	var worst := -1.0
	var wi := -1
	for i in range(d.arrivals.size()):
		var a: Dictionary = d.arrivals[i]
		var err := absf((a["pos"] as Vector2).x - float(a["want_x"]))
		if err > 10.0:
			print("FAR idx %d kind %s pos %s want_x %.1f err %.2f" % [int(a["idx"]), a["kind"], a["pos"], float(a["want_x"]), err])
		if err > worst:
			worst = err
			wi = i
	print("SUMMARY seed %d worst %.2f at arrival %d" % [s, worst, wi])
	if wi < 0:
		return
	var k := int(d.arrivals[wi]["idx"])
	for j in range(maxi(0, k - 5), mini(res["events"].size(), k + 3)):
		print("EV %d %s" % [j, JSON.stringify(res["events"][j])])
