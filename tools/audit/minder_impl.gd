extends RefCounted
## Defensive-forward assignment, paired measurement (register item 5; measurement only).
## The home side sends one forward to the away side's loose defender
## ("spare_accountable" with "spare_minder_id", as the match screen does), against
## the same match with no call (same seed, same teams). Per match, for the
## forward sent and for the average of the home side's other forwards on the
## ground at the start:
##   shots, goals, marks, contested marks per match.
## Arms: none (no call), spec (a Defensive forward sent, when the side has one),
## plain (the best-Pressure forward without the trait sent). The ground is the
## starting side; a forward who is off the ground at a chain still counts his
## match totals.
## Args after the impl name: first seed and how many (default 1 and 60).

const STATS := ["shots", "goals", "marks", "contested_marks", "score_involvements"]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[1]) if args.size() > 1 else 1
	var count := int(args[2]) if args.size() > 2 else 60
	GameState.replay_seed = 2027
	GameDB.reload()
	# Clubs with a list (the expansion placeholders TAS and CANB have none).
	var codes: Array = GameDB.club_order.filter(func(c): return GameDB.club_list(c).size() >= 22)
	var n := codes.size()
	var acc := {}   # "<kind>_<who>" -> {stat: total}, plus counts
	var counts := {"spec": 0, "plain": 0}
	var scored := {"spec": 0, "plain": 0}
	for s in range(first, first + count):
		var hi := s % n
		var ai := (s * 7 + 3) % n
		if ai == hi:
			ai = (ai + 1) % n
		var base := _play(codes[hi], codes[ai], s, "", "")
		var ground0: Array = base["ground"]
		var fwds := Matchups.minder_candidates(ground0)
		var spec := {}
		var plain := {}
		for p in fwds:
			if Traits.has(p, "def_forward") and spec.is_empty():
				spec = p
			if not Traits.has(p, "def_forward") and plain.is_empty():
				plain = p
		for kind in ["spec", "plain"]:
			var who: Dictionary = spec if kind == "spec" else plain
			if who.is_empty():
				continue
			var sent := _play(codes[hi], codes[ai], s, str(who["id"]), "go")
			counts[kind] += 1
			var id := str(who["id"])
			# Him, with the call and without it; the other forwards, with and without.
			_add(acc, kind + "_him_call", (sent["players"] as Dictionary).get(id, {}))
			_add(acc, kind + "_him_nocall", (base["players"] as Dictionary).get(id, {}))
			if float(((sent["players"] as Dictionary).get(id, {}) as Dictionary).get("goals", 0.0)) > 0.0:
				scored[kind] += 1
			var others := 0
			for p in ground0:
				if str(p["role"]) == "FWD" and str(p["id"]) != id:
					others += 1
					_add(acc, kind + "_oth_call", (sent["players"] as Dictionary).get(str(p["id"]), {}))
					_add(acc, kind + "_oth_nocall", (base["players"] as Dictionary).get(str(p["id"]), {}))
			acc[kind + "_oth_n"] = int(acc.get(kind + "_oth_n", 0)) + others
		print("SEED %d %s v %s spec=%s plain=%s" % [s, codes[hi], codes[ai], str(spec.get("id", "-")), str(plain.get("id", "-"))])
	for kind in ["spec", "plain"]:
		var c := maxi(1, int(counts[kind]))
		print("ARM %s matches %d (forward scored in %d of them with the call)" % [kind, counts[kind], scored[kind]])
		for k in STATS:
			var on := maxf(1.0, float(acc.get(kind + "_oth_n", 0)))
			print("  %s: him with call %.2f, him no call %.2f; other forwards (each) with call %.2f, no call %.2f" % [
					k, _mean(acc, kind + "_him_call", k, c), _mean(acc, kind + "_him_nocall", k, c),
					float(((acc.get(kind + "_oth_call", {}) as Dictionary).get(k, 0.0))) / on,
					float(((acc.get(kind + "_oth_nocall", {}) as Dictionary).get(k, 0.0))) / on])
	print("SUMMARY seeds %d spec_matches %d plain_matches %d" % [count, counts["spec"], counts["plain"]])


func _play(home: String, away: String, seed: int, minder_id: String, mode: String) -> Dictionary:
	var m := MatchSim.new(Squad.new(home, GameDB.club_list(home).duplicate(true), true, home),
			Squad.new(away, GameDB.club_list(away).duplicate(true), false, away), seed)
	var sp := Matchups.best_interceptor((m.squads[1] as Squad).ground, 0.0)
	m.set_interceptor(1, str(sp.get("id", "")), false)
	var ground: Array = (m.squads[0] as Squad).ground.duplicate()
	if minder_id != "":
		m.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true, "spare_minder_id": minder_id})
	var res := m.run()
	return {"players": res.get("players", {}), "ground": ground}


func _add(acc: Dictionary, key: String, st: Dictionary) -> void:
	var d: Dictionary = acc.get(key, {})
	for k in STATS:
		d[k] = float(d.get(k, 0.0)) + float(st.get(k, 0.0))
	acc[key] = d


func _mean(acc: Dictionary, key: String, stat: String, c: int) -> float:
	return float((acc.get(key, {}) as Dictionary).get(stat, 0.0)) / float(c)
