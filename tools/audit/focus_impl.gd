extends RefCounted
## What "Play through him" does for the player it is set on, by his job
## (measurement only, #508). Paired seeds: every match is played once with no
## focus, and once more per arm with the same seed and one player played through
## on side 0. The comparison is that player's own line, and side 0's team line,
## with and without the call.
##   fwd_key    the best-kicking key forward on the ground (192 cm and up)
##   mid_inside the best contested-ball midfielder who is not on a wing
##   def_small  the best user of the ball among defenders 183 cm and under
##   def_key    the best user of the ball among defenders 190 cm and over
## Env: FOCUS_N matches per arm (default 240), FOCUS_SEED seed base (default 9000).
## Real 2026 club lists, home side rotating through the 18 clubs.
##
## Back half: own-half disposals, counted by an AuditSim that watches the carrier
## pick (a kick-in is always from the back half). Bookkeeping only; it draws no
## dice and changes no rule.

const ARMS := ["fwd_key", "mid_inside", "def_small", "def_key"]
const PLAYER_KEYS := ["shots", "goals", "disposals", "back_half", "effective", "clangers", "inside50", "metres_gained"]
const TEAM_KEYS := ["score", "metres_gained", "clangers", "ineffective", "inside50"]


class AuditSim extends MatchSim:
	var back_half := {}   # player id -> own-half disposals
	var _last_id := ""
	var _last_own := false

	func _init(home: Squad, away: Squad, seed: int = 0) -> void:
		super(home, away, seed)

	func pick_carrier(side: int, fp: float):
		var c = super.pick_carrier(side, fp)
		_last_id = "" if c == null else str(c["id"])
		_last_own = (fp if side == 0 else -fp) < 0.0
		return c

	func _p(player, key: String, n := 1.0) -> void:
		super._p(player, key, n)
		if key == "disposals" and player != null:
			var id := str(player["id"])
			# A kick-in has no carrier pick: it is from the goal square.
			if id != _last_id or _last_own:
				back_half[id] = float(back_half.get(id, 0.0)) + 1.0


func _pick(sim: MatchSim, arm: String) -> Dictionary:
	var best: Dictionary = {}
	var best_v := -INF
	for p in (sim.squads[0] as Squad).ground:
		var role := str(p["role"])
		var h := float(p.get("height_cm", 0.0))
		var v := 0.0
		match arm:
			"fwd_key":
				if role != "FWD" or h < MatchSim.FWD_KEY_CM:
					continue
				v = sim._a(p, "goalkicking")
			"mid_inside":
				if role != "MID" or Roles.on_wing(p):
					continue
				v = sim._a(p, "contested")
			"def_small":
				if role != "DEF" or h <= 0.0 or h > 183.0:
					continue
				v = sim._a(p, "disposal") + sim._a(p, "carry")
			"def_key":
				if role != "DEF" or h < 190.0:
					continue
				v = sim._a(p, "disposal") + sim._a(p, "carry")
		if v > best_v:
			best_v = v
			best = p
	return best


func _line(sim: AuditSim, res: Dictionary, id: String) -> Dictionary:
	var st: Dictionary = (res["players"] as Dictionary).get(id, {})
	var team: Dictionary = (res["team"] as Array)[0]
	return {
		"player": {
			"shots": float(st.get("goals", 0.0)) + float(st.get("behinds", 0.0)),
			"goals": float(st.get("goals", 0.0)),
			"disposals": float(st.get("disposals", 0.0)),
			"back_half": float(sim.back_half.get(id, 0.0)),
			"effective": float(st.get("effective_disposals", 0.0)),
			"clangers": float(st.get("clangers", 0.0)),
			"inside50": float(st.get("inside50", 0.0)),
			"metres_gained": float(st.get("metres_gained", 0.0)),
		},
		"team": {
			"score": float((res["score"] as Array)[0]),
			"metres_gained": float(team.get("metres_gained", 0.0)),
			"clangers": float(team.get("clangers", 0.0)),
			"ineffective": float(team.get("disposals", 0.0)) - float(team.get("effective_disposals", 0.0)),
			"inside50": float(team.get("inside50", 0.0)),
		},
	}


func _sim(codes: Array, i: int, seed: int) -> AuditSim:
	var h := str(codes[i % codes.size()])
	var o := str(codes[(i * 5 + 1 + i / codes.size()) % codes.size()])
	if o == h:
		o = str(codes[(i + 1) % codes.size()])
	return AuditSim.new(Squad.new(h, GameDB.club_list(h), true, h), Squad.new(o, GameDB.club_list(o), false, o), seed)


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var n := int(OS.get_environment("FOCUS_N")) if OS.get_environment("FOCUS_N") != "" else 240
	var base := int(OS.get_environment("FOCUS_SEED")) if OS.get_environment("FOCUS_SEED") != "" else 9000
	# arm -> {"on": {key: [sum, sumsq...]}} ... kept as sums of the paired difference
	var agg := {}
	for arm in ARMS:
		agg[arm] = {"n": 0, "on": {}, "off": {}, "d": {}, "d2": {}, "ovr": 0.0, "h": 0.0}
	for i in range(n):
		var seed := base + i
		var plain := _sim(codes, i, seed)
		var chosen := {}
		for arm in ARMS:
			chosen[arm] = _pick(plain, arm)
		var res0 := plain.run()
		for arm in ARMS:
			var who: Dictionary = chosen[arm]
			if who.is_empty():
				continue
			var id := str(who["id"])
			var on := _sim(codes, i, seed)
			on.set_tactics(0, {"focus_id": id})
			var res1 := on.run()
			var a: Dictionary = agg[arm]
			a["n"] = int(a["n"]) + 1
			a["h"] = float(a["h"]) + float(who.get("height_cm", 0.0))
			var l0 := _line(plain, res0, id)
			var l1 := _line(on, res1, id)
			for grp in ["player", "team"]:
				for k in (l1[grp] as Dictionary):
					var key := "%s.%s" % [grp, k]
					var v1: float = float(l1[grp][k])
					var v0: float = float(l0[grp][k])
					(a["on"] as Dictionary)[key] = float((a["on"] as Dictionary).get(key, 0.0)) + v1
					(a["off"] as Dictionary)[key] = float((a["off"] as Dictionary).get(key, 0.0)) + v0
					(a["d"] as Dictionary)[key] = float((a["d"] as Dictionary).get(key, 0.0)) + (v1 - v0)
					(a["d2"] as Dictionary)[key] = float((a["d2"] as Dictionary).get(key, 0.0)) + (v1 - v0) * (v1 - v0)
		if i % 20 == 19:
			print("done %d of %d" % [i + 1, n])
	print("FOCUS paired matches per arm: up to %d (a match is skipped for an arm with no such player on the ground)" % n)
	for arm in ARMS:
		var a: Dictionary = agg[arm]
		var m := int(a["n"])
		if m == 0:
			print("ARM %s: no matches" % arm)
			continue
		print("ARM %s  n=%d  mean height %.1f cm" % [arm, m, float(a["h"]) / m])
		for grp in ["player", "team"]:
			var keys: Array = PLAYER_KEYS if grp == "player" else TEAM_KEYS
			for k in keys:
				var key := "%s.%s" % [grp, k]
				var d: float = float((a["d"] as Dictionary).get(key, 0.0)) / m
				var var_d: float = maxf(0.0, float((a["d2"] as Dictionary).get(key, 0.0)) / m - d * d)
				var se := sqrt(var_d / m)
				print("    %-22s no focus %7.2f   focus %7.2f   diff %+6.2f  (se %.2f)" % [key,
						float((a["off"] as Dictionary).get(key, 0.0)) / m, float((a["on"] as Dictionary).get(key, 0.0)) / m, d, se])
		print("SUMMARY arm=%s n=%d seed=%d %s" % [arm, m, base, _flat(a, m)])


## key=off/on/se(diff), so batches pool: n-weighted means, se by quadrature.
func _flat(a: Dictionary, m: int) -> String:
	var bits := []
	for key in (a["d"] as Dictionary):
		var d: float = float((a["d"] as Dictionary)[key]) / m
		var se := sqrt(maxf(0.0, float((a["d2"] as Dictionary)[key]) / m - d * d) / m)
		bits.append("%s=%.4f/%.4f/%.4f" % [key, float((a["off"] as Dictionary)[key]) / m, float((a["on"] as Dictionary)[key]) / m, se])
	return " ".join(bits)
