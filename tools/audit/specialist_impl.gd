extends RefCounted
## Specialists among generated players (backlog Medium 15): ten draft classes
## aged five seasons by the development rules (no matches), their synergy
## traits against the real 2026 lists' share, and the classes' OVR and
## position mix - before and after a change to how prospects are made.
const TRAITS := ["ball_magnet", "bull", "aerial", "crumber", "sharpshooter", "playmaker",
		"interceptor", "lockdown", "engine", "big_game", "ruck_king"]

var _grown_all := []

func run() -> void:
	seed(2026)
	var real := {}
	var nr := 0
	for c in GameDB.club_order:
		for p in GameDB.club_list(c):
			nr += 1
			for t in Traits.of(p):
				real[t] = int(real.get(t, 0)) + 1
	var at_draft := {}
	var grown := {}
	var n := 0
	var ovr0 := 0.0
	var ovr5 := 0.0
	var roles := {}
	for y in range(2027, 2037):
		for p in Prospects.age_pool(Prospects.generate_class(y, 4242 + y), y, {}):
			n += 1
			ovr0 += float(p["overall"])
			roles[str(p["role"])] = int(roles.get(str(p["role"]), 0)) + 1
			for t in Traits.of(p):
				at_draft[t] = int(at_draft.get(t, 0)) + 1
			var q: Dictionary = p.duplicate(true)
			for k in range(1, 6):
				Prospects.age_player(q, y + k)
			ovr5 += float(q["overall"])
			_grown_all.append(q)
			for t in Traits.of(q):
				grown[t] = int(grown.get(t, 0)) + 1
	# Like for like: the share in OVR bands, real against grown.
	var bands := [[0, 60], [60, 66], [66, 72], [72, 78], [78, 100]]
	for t in TRAITS:
		var line := "BAND %-12s" % t
		for b in bands:
			var rn := 0
			var rt := 0
			for c in GameDB.club_order:
				for p in GameDB.club_list(c):
					if int(p["overall"]) >= int(b[0]) and int(p["overall"]) < int(b[1]):
						rn += 1
						rt += 1 if Traits.of(p).has(t) else 0
			var gn := 0
			var gt := 0
			for q in _grown_all:
				if int(q["overall"]) >= int(b[0]) and int(q["overall"]) < int(b[1]):
					gn += 1
					gt += 1 if Traits.of(q).has(t) else 0
			line += " | %d-%d real %4.1f%% (%d) gen %4.1f%% (%d)" % [b[0], b[1], 100.0 * rt / maxi(1, rn), rn, 100.0 * gt / maxi(1, gn), gn]
		print(line)
	print("SPEC generated %d players: mean OVR at draft %.1f, five seasons on %.1f; roles %s" % [n, ovr0 / n, ovr5 / n, str(roles)])
	for t in TRAITS:
		print("SPEC %-12s real %4.1f%%  draft %4.1f%%  five seasons on %4.1f%%" % [t,
				100.0 * int(real.get(t, 0)) / nr, 100.0 * int(at_draft.get(t, 0)) / n, 100.0 * int(grown.get(t, 0)) / n])
