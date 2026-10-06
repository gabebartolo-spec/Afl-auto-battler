extends RefCounted
## Rating parity by role over many simulated matches (measurement only): the check
## in tests/test_matchday.gd ("No position is shut out of big ratings") made bigger.
## Plays N matches (arg 1, default 64), each between two clubs as the matchday test
## pairs them, and prints one PARITY line per measure:
##   rating p50 and p90 by role, and the DEF/MID/FWD p90 spread (the test allows 30);
##   how many times each role is in a side's top three by rating;
##   per player-game by role: mean disposals and mean clearances.
## The match seeds start at AUDIT_SEED (default 2026), so runs with the same seed pair.
## Args after the impl name: matches
## godot --headless --path . --script tools/audit/run_audit.gd -- parity_impl 64

const CLUBS := ["COL", "CAR", "GEE", "SYD", "BRL", "MEL", "HAW", "ESS", "FRE", "ADE", "GWS", "PAD"]
const ROLES := ["DEF", "MID", "FWD", "RUCK"]


func _match(seed: int, a: String, b: String) -> Dictionary:
	var sim := MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)
	return sim.run()


func _pct(v: Array, q: float) -> int:
	if v.is_empty():
		return 0
	return int(v[mini(v.size() - 1, int(v.size() * q))])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 64
	var env := OS.get_environment("AUDIT_SEED")
	var base := int(env) if env != "" else 2026
	var ratings := {}
	var top3 := {}
	var disposals := {}
	var clearances := {}
	for r in ROLES:
		ratings[r] = []
		top3[r] = 0
		disposals[r] = 0.0
		clearances[r] = 0.0
	var games := {"DEF": 0, "MID": 0, "FWD": 0, "RUCK": 0}
	for i in range(n):
		var res := _match(base + i, CLUBS[i % 8], CLUBS[i % 8 + 4])
		for side in [0, 1]:
			var rated := MatchNotes.rated_players(res, side)
			for p in rated:
				var role := str(p["role"])
				if not ratings.has(role):
					continue
				(ratings[role] as Array).append(int(p["rating"]))
				games[role] += 1
				disposals[role] += float((p["stats"] as Dictionary).get("disposals", 0.0))
				clearances[role] += float((p["stats"] as Dictionary).get("clearances", 0.0))
			for p in rated.slice(0, 3):
				if top3.has(str(p["role"])):
					top3[str(p["role"])] += 1
	var lo := 999
	var hi := 0
	for r in ROLES:
		var v: Array = ratings[r]
		v.sort()
		var p90 := _pct(v, 0.9)
		print("PARITY rating %s | p50 %d | p90 %d | player-games %d" % [r, _pct(v, 0.5), p90, v.size()])
		if r != "RUCK":
			lo = mini(lo, p90)
			hi = maxi(hi, p90)
	print("PARITY spread DEF/MID/FWD p90: %d (the matchday check allows 30), matches %d, seed base %d" % [hi - lo, n, base])
	print("PARITY top three by role (counts over %d sides): %s" % [n * 2, str(top3)])
	for r in ROLES:
		var g := maxi(1, int(games[r]))
		print("PARITY per player-game %s | disposals %.1f | clearances %.2f" % [r, disposals[r] / g, clearances[r] / g])
