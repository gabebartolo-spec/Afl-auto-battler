extends SceneTree
## Collection pauses (ROADMAP §1.11, "repeated unresolved collection pauses"):
## step the match view (MatchDirector) through seeded matches, headless, and
## time every "collect" phase - the ball waiting for the player the log names.
## Report only; it changes nothing.
##   godot --headless --path . --script tools/visual/trace_collect.gd [-- --matches 4 --min 1.0]
## Prints one COLLECT line per collect longer than --min seconds (match time):
## its length, the event that started the beat, how far the named player was
## from the ball, and how far the nearest other player was. Then a summary.

const DT := 1.0 / 30.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var matches := 4
	var min_s := 1.0
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--matches": matches = int(a[i + 1])
			"--min": min_s = float(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var squad_script = load("res://scripts/sim/Squad.gd")
	var pairs := [["GEE", "COL"], ["SYD", "BRL"], ["MEL", "WCE"], ["ADE", "PAD"], ["CAR", "ESS"], ["HAW", "STK"]]
	var total := 0
	var long := 0
	var by_kind := {}
	var secs := []
	var far_with_near := 0
	for m in range(matches):
		var pr: Array = pairs[m % pairs.size()]
		var sim = load("res://scripts/sim/MatchSim.gd").new(
				squad_script.new(pr[0], db.club_list(pr[0]), true, pr[0]),
				squad_script.new(pr[1], db.club_list(pr[1]), false, pr[1]), 300 + m)
		var res: Dictionary = sim.run()
		var d = load("res://scripts/ui/match/MatchDirector.gd").new()
		d.setup(res, res["events"])
		var cur = null
		var info := {}
		var guard := 0
		while not d.idle() and guard < 400000:
			guard += 1
			d.advance(DT)
			var phases: Array = d.get("_phases")
			var pi: int = d.get("_pi")
			var p = phases[pi] if pi < phases.size() else null
			if p != cur:
				if cur != null and str(cur.get("t", "")) == "collect" and not info.is_empty():
					total += 1
					var dur: float = float(d.get("time")) - float(info["start"])
					if dur >= min_s:
						long += 1
						secs.append(dur)
						var k := str(info["kind"])
						by_kind[k] = int(by_kind.get(k, 0)) + 1
						if float(info["near"]) + 5.0 < float(info["dist"]):
							far_with_near += 1
						print("COLLECT %.1fs  after %-12s named %4.0fm off, nearest other %4.0fm%s%s" % [dur, k,
								float(info["dist"]), float(info["near"]), "  max" if info["max"] else "",
								"  roll" if info["roll"] else ""])
				cur = p
				info = {}
				if p != null and str(p.get("t", "")) == "collect" and int(p.get("who", -1)) >= 0:
					var tokens: Array = d.get("tokens")
					var ball: Dictionary = d.get("ball")
					var who := int(p["who"])
					var bp: Vector2 = ball["pos"]
					var near := INF
					for t in tokens:
						if int(t["id"]) != who:
							near = minf(near, (t["pos"] as Vector2).distance_to(bp))
					var evs: Array = d.get("events")
					var c: int = d.get("cursor")
					info = {"start": float(d.get("time")), "who": who,
							"dist": (tokens[who]["pos"] as Vector2).distance_to(bp), "near": near,
							"kind": str(evs[c - 1].get("kind", "")) if c > 0 and c <= evs.size() else "?",
							"max": p.has("max"), "roll": bool(p.get("roll", false))}
	secs.sort()
	print("SUMMARY %d matches: %d collects, %d of %.1fs or more (%s); %d with another player 5m+ nearer the ball" % [
			matches, total, long, min_s, str(by_kind), far_with_near])
	if not secs.is_empty():
		print("LONGEST %s" % str(secs.slice(maxi(0, secs.size() - 8))))
	quit()
