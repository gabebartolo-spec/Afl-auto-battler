class_name MatchSim
extends RefCounted
## The match engine. Simulates a game as a sequence of possession chains and
## emits a deterministic, seeded event log that the pitch view replays.
##
## Port of tools/sim_harness.py::MatchSim. The RNG call order below must match
## the Python harness exactly - that file is where the constants were tuned so
## simulated team totals reproduce real 2026 AFL numbers. Emitting events does
## not draw from the RNG, so the richer log costs nothing in calibration.

var squads: Array = []                 # [Squad home, Squad away]
var rng := RandomNumberGenerator.new()
var team_stats: Array = [{}, {}]
var player_stats := {}                 # player id -> {stat: float}
var events: Array = []
var q_goals: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]
var q_behinds: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]
var current_minute := 0
var current_quarter := 1
var fp := 0.0
var next_side := -1          # -1 => the stoppage is contested
var at_centre := true
var tactics := [{}, {}]      # per side: gameplan, focus_id, tag_id, pep


func _init(home: Squad, away: Squad, seed: int = 0) -> void:
	squads = [home, away]
	rng.seed = seed


func set_tactics(side: int, t: Dictionary) -> void:
	if side < 0 or side > 1:
		return
	tactics[side] = t.duplicate()


func _plan(side: int) -> String:
	return str((tactics[side] as Dictionary).get("gameplan", "balanced"))


func _pep(side: int) -> String:
	return str((tactics[side] as Dictionary).get("pep", "steady"))


func _focus_id(side: int) -> String:
	return str((tactics[side] as Dictionary).get("focus_id", ""))


func _tag_id(side: int) -> String:
	return str((tactics[side] as Dictionary).get("tag_id", ""))


# ---------------------------------------------------------------------------
# Stat bookkeeping
# ---------------------------------------------------------------------------
func _t(side: int, key: String, n := 1.0) -> void:
	var d: Dictionary = team_stats[side]
	d[key] = float(d.get(key, 0.0)) + n


func _p(player, key: String, n := 1.0) -> void:
	if player == null:
		return
	var id: String = player["id"]
	if not player_stats.has(id):
		player_stats[id] = {}
	var d: Dictionary = player_stats[id]
	d[key] = float(d.get(key, 0.0)) + n


func score(side: int) -> int:
	return int(goals(side) * 6 + behinds(side))


func goals(side: int) -> int:
	return int(float(team_stats[side].get("goals", 0.0)))


func behinds(side: int) -> int:
	return int(float(team_stats[side].get("behinds", 0.0)))


func _emit(kind: String, side: int, fp: float, actor, text: String) -> void:
	events.append({
		"q": current_quarter,
		"min": current_minute,
		"kind": kind,
		"side": side,
		"fp": fp,
		"name": "" if actor == null else str(actor["name"]),
		"num": 0 if actor == null else int(actor["num"]),
		"club": "" if actor == null else str(actor["club"]),
		"text": text,
		"score": [score(0), score(1)],
	})


# ---------------------------------------------------------------------------
# Selection helpers
# ---------------------------------------------------------------------------
static func _by_roles(group: Array, roles: Array) -> Array:
	var out := []
	for p in group:
		if roles.has(p["role"]):
			out.append(p)
	return out


## Weighted random pick. Better players at the relevant attribute get the ball
## more often, squared so the gap is meaningful but not deterministic.
func _weighted(group: Array, key: String, power := 2.0, side := -1, purpose := ""):
	if group.is_empty():
		return null
	var weights := []
	for p in group:
		var w: float = pow(maxf(1.0, float(p["attr"][key])), power)
		if side >= 0:
			w *= _tactic_player_mult(side, p, purpose)
		weights.append(w)
	return _pick(group, weights)


func _tactic_player_mult(side: int, p: Dictionary, purpose: String) -> float:
	var out := 1.0
	var id := str(p["id"])
	if id == _focus_id(side) and (purpose == "carrier" or purpose == "shooter"):
		out *= 1.55
	if id == _tag_id(1 - side) and (purpose == "carrier" or purpose == "shooter"):
		out *= 0.55
	if _plan(side) == "through_stars" and int(p["overall"]) >= 70:
		out *= 1.18
	if _pep(side) == "fire_up":
		out *= 1.05
	return out


func _pick(group: Array, weights: Array):
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return group[0]
	var r := rng.randf() * total
	var acc := 0.0
	for i in range(group.size()):
		acc += weights[i]
		if r <= acc:
			return group[i]
	return group[group.size() - 1]


## Which side wins the ball at a stoppage. Field position nudges it (a centre
## bounce deep in your forward half slightly favours the home structure), and
## the result is clamped so no list is ever guaranteed the ball.
func contest_winner(use_fp: bool, fp: float) -> int:
	var T := Ratings.T
	var lim := float(T["contest_clamp"])
	var p_home: float = (0.5
			+ (squads[0].contest - squads[1].contest) / float(T["contest_swing"])
			+ float(T["home_ground_bonus"]))
	p_home += _contest_bonus(0) - _contest_bonus(1)
	if use_fp:
		p_home += clampf(fp / 900.0, -0.07, 0.07)
	return 0 if rng.randf() < maxf(1.0 - lim, minf(lim, p_home)) else 1


func _contest_bonus(side: int) -> float:
	var b := 0.0
	if _plan(side) == "contest":
		b += 0.035
	if _pep(side) == "fire_up":
		b += 0.018
	return b


func pick_carrier(side: int, fp: float):
	var T := Ratings.T
	var sq: Squad = squads[side]
	var atk_fp := fp if side == 0 else -fp
	var group: Array
	var key: String
	if atk_fp < -10.0:
		group = _by_roles(sq.ground, ["DEF", "MID"])
		key = "intercept"
	elif atk_fp > float(T["forward50_line"]):
		group = _by_roles(sq.ground, ["FWD", "MID"])
		key = "goalkicking"
	elif atk_fp > 5.0:
		group = _by_roles(sq.ground, ["MID", "FWD"])
		key = "carry"
	else:
		group = _by_roles(sq.ground, ["MID", "RUCK", "DEF"])
		key = "disposal"
	if group.is_empty():
		group = sq.ground
	return _weighted(group, key, 2.0, side, "carrier")


# ---------------------------------------------------------------------------
# Stoppage: ruck contest + clearance
# ---------------------------------------------------------------------------
func _stoppage(side: int, opp: int, from_bounce: bool) -> void:
	if not from_bounce:
		return
	var T := Ratings.T
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var ruck_a := _by_roles(atk.ground, ["RUCK"])
	var ruck_b := _by_roles(dfn.ground, ["RUCK"])

	# Three independent hit-out opportunities per bounce, so a game lands near
	# the real ~34 hit-outs per team rather than one lump per stoppage.
	var total_hits := 0
	for i in range(3):
		if rng.randf() < float(T["hitouts_per_stoppage"]) / 3.0:
			total_hits += 1
	if total_hits > 0:
		var share := clampf(0.5 + (atk.ruck - dfn.ruck) / 260.0, 0.15, 0.85)
		var ha := int(round(total_hits * share))
		var hb := total_hits - ha
		_t(side, "hitouts", ha)
		_t(opp, "hitouts", hb)
		_p(ruck_a[0] if not ruck_a.is_empty() else null, "hitouts", ha)
		_p(ruck_b[0] if not ruck_b.is_empty() else null, "hitouts", hb)

	if rng.randf() < float(T["clearance_per_stoppage"]):
		_t(side, "clearances")
		var group := _by_roles(atk.ground, ["MID", "RUCK"])
		if group.is_empty():
			group = atk.ground
		var mid = _weighted(group, "contested", 2.0, side, "clearance")
		_p(mid, "clearances")


# ---------------------------------------------------------------------------
# One possession chain
# ---------------------------------------------------------------------------
func play_chain(side: int, fp: float, from_bounce: bool) -> Dictionary:
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var dir := 1.0 if side == 0 else -1.0
	var f50 := float(T["forward50_line"])
	var gline := float(T["goal_line"])

	_t(side, "chains")
	_stoppage(side, opp, from_bounce)

	var atk_fp := fp if side == 0 else -fp
	var touched_i50 := atk_fp >= f50
	if touched_i50:
		_t(side, "inside50")

	var touches := 0
	var max_touches := int(T["max_touches_per_chain"])
	while touches < max_touches:
		touches += 1
		var carrier = pick_carrier(side, fp)
		_t(side, "disposals")
		_p(carrier, "disposals")

		var hb_bias: float = (0.85
				+ 0.30 * (100.0 - float(carrier["attr"]["marking"])) / 100.0)
		if rng.randf() < float(T["handball_share"]) * hb_bias:
			_t(side, "handballs")
			_p(carrier, "handballs")
			_emit("handball", side, fp, carrier, "%s handballs" % carrier["name"])
		else:
			_t(side, "kicks")
			_p(carrier, "kicks")
			var mark_p: float = (float(T["mark_share_of_kicks"])
					* (0.75 + 0.50 * float(carrier["attr"]["marking"]) / 100.0))
			var marked := rng.randf() < mark_p
			if marked:
				_t(side, "marks")
				_p(carrier, "marks")
				_emit("mark", side, fp, carrier, "%s marks" % carrier["name"])
			else:
				_emit("kick", side, fp, carrier, "%s kicks" % carrier["name"])

		var pressure: float = (float(T["pressure_base"])
				* (0.72 + 0.56 * dfn.def_pressure / 100.0))
		if _plan(opp) == "defensive" or _plan(opp) == "press":
			pressure *= 1.18
		if _plan(side) == "controlled":
			pressure *= 0.92
		atk_fp = fp if side == 0 else -fp
		pressure *= 1.10 if atk_fp < 0.0 else 0.95

		if rng.randf() < pressure:
			_t(opp, "tackles")
			var tgroup := _by_roles(dfn.ground, ["MID", "DEF"])
			if tgroup.is_empty():
				tgroup = dfn.ground
			var tackler = _weighted(tgroup, "pressure", 2.0, opp, "tackler")
			_p(tackler, "tackles")
			var retain: float = (float(T["tackle_retention"])
					* (0.75 + 0.50 * float(carrier["attr"]["contested"]) / 100.0))
			if rng.randf() < retain:
				fp += rng.randf_range(4.0, 12.0) * dir
				continue
			_emit("tackle", opp, fp, tackler,
					"%s tackles %s - ball up" % [tackler["name"], carrier["name"]])
			return {"outcome": "stoppage", "fp": fp, "actor": carrier}

		var prev_atk_fp := atk_fp
		var gain: float = (float(T["metres_gain_mean"])
				* (0.55 + 0.90 * float(carrier["attr"]["carry"]) / 100.0))
		if _plan(side) == "fast" or _plan(side) == "attacking":
			gain *= 1.14
		elif _plan(side) == "controlled":
			gain *= 0.88
		gain *= rng.randf_range(0.45, 1.75)
		fp += gain * dir
		fp = clampf(fp, -gline, gline)
		atk_fp = fp if side == 0 else -fp

		# Rebound 50: winning it out of your own defensive arc.
		if prev_atk_fp < -20.0 and atk_fp > -12.0:
			_t(side, "rebounds")
			_p(carrier, "rebounds")

		if atk_fp >= f50 and not touched_i50:
			touched_i50 = true
			_t(side, "inside50")
			_p(carrier, "inside50")
			_emit("inside50", side, fp, carrier,
					"%s sends it inside 50" % carrier["name"])
			return resolve_forward50(side, fp, carrier)

		# A clean exit from your own defensive 50 is a rebound.
		if atk_fp > 5.0 and atk_fp - gain <= -f50:
			_t(opp, "rebounds")
			_p(carrier, "rebounds")

	return {"outcome": "stoppage", "fp": fp, "actor": null}


## Forward-50 entry resolution: contest the mark, then roll for goal / behind /
## rebound. This is where almost all of the scoring variance lives.
func resolve_forward50(side: int, fp: float, feeder) -> Dictionary:
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	_p(feeder, "goal_assists")

	var sgroup := _by_roles(atk.ground, ["FWD", "MID"])
	if sgroup.is_empty():
		sgroup = atk.ground
	var shooter = _weighted(sgroup, "goalkicking", 2.4, side, "shooter")

	var dgroup := _by_roles(dfn.ground, ["DEF"])
	if dgroup.is_empty():
		dgroup = dfn.ground
	var defender = _weighted(dgroup, "intercept", 2.0, opp, "defender")

	var marked := rng.randf() < clampf(
			0.5 + (atk.fwd_mark - dfn.def_intercept) / 240.0, 0.10, 0.72)
	if marked:
		_t(side, "marks")
		_p(shooter, "marks")
	var spoilt := rng.randf() < 0.30 + 0.35 * dfn.def_intercept / 100.0
	if rng.randf() < float(T["one_percenter_share"]):
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")

	var goal_p := float(T["inside50_goal"])
	goal_p *= 0.80 + 0.40 * float(shooter["attr"]["goalkicking"]) / 100.0
	goal_p *= 1.16 if marked else 0.74
	goal_p *= 0.82 + 0.36 * float(shooter["attr"]["accuracy"]) / 100.0
	if spoilt and not marked:
		goal_p *= 0.58
	goal_p *= 0.90 + 0.20 * atk.attack / 100.0
	goal_p *= 1.06 - 0.12 * dfn.defence / 100.0
	if _plan(side) == "attacking":
		goal_p *= 1.12
	elif _plan(side) == "controlled":
		goal_p *= 0.96
	if _plan(opp) == "defensive":
		goal_p *= 0.90
	var behind_p: float = (float(T["inside50_behind"])
			* (0.80 + 0.40 * float(shooter["attr"]["goalkicking"]) / 100.0))

	var roll := rng.randf()
	if roll < goal_p:
		_t(side, "goals")
		_p(shooter, "goals")
		q_goals[current_quarter - 1][side] += 1
		_emit("goal", side, fp, shooter, _scoreline(side, "GOAL"))
		return {"outcome": "score", "fp": 0.0, "actor": shooter}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(shooter, "behinds")
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, shooter, _scoreline(side, "Behind"))
		return {"outcome": "score", "fp": 0.0, "actor": shooter}

	_t(opp, "rebounds")
	_p(defender, "rebounds")
	_emit("rebound", opp, fp, defender,
			"%s rebounds it out of danger" % defender["name"])
	return {"outcome": "turnover", "fp": fp, "actor": defender}


func _scoreline(side: int, prefix: String) -> String:
	var opp := 1 - side
	return "%s - %s %d.%d (%d) def %s %d.%d (%d)" % [
			prefix, squads[side].name,
			goals(side), behinds(side), score(side),
			squads[opp].name, goals(opp), behinds(opp), score(opp)]


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
func run() -> Dictionary:
	while current_quarter <= 4:
		run_quarter()
	return result()


func run_quarter() -> Dictionary:
	var T := Ratings.T
	var per_quarter: int = floori(float(T["chains_per_game"]) / 4.0)
	var quarter := current_quarter
	for i in range(per_quarter):
		current_minute = (quarter - 1) * 30 + int(30 * i / maxi(1, per_quarter)) + 1
		var stoppage := at_centre or rng.randf() < float(T["stoppage_share"])
		var side: int
		var start_fp: float
		if stoppage:
			start_fp = 0.0
			side = contest_winner(false, 0.0)
		else:
			start_fp = fp
			side = next_side if next_side >= 0 else contest_winner(true, fp)

		var res := play_chain(side, start_fp, stoppage)
		var outcome: String = res["outcome"]
		fp = res["fp"]

		at_centre = (outcome == "score")
		next_side = (1 - side) if outcome == "turnover" else -1
		if outcome == "score":
			fp = 0.0

		# End-of-chain error: a clanger, sometimes a free kick against.
		var clanger_p := float(T["clanger_per_chain"])
		if _plan(side) == "fast" or _plan(side) == "attacking":
			clanger_p *= 1.12
		elif _plan(side) == "controlled":
			clanger_p *= 0.86
		if rng.randf() < clanger_p:
			var ground: Array = squads[side].ground
			var weights := []
			for p in ground:
				weights.append(float(pow(maxf(1.0, 101.0
						- float(p["attr"]["discipline"])), 1.6)))
			var err = _pick(ground, weights)
			_t(side, "clangers")
			_p(err, "clangers")
			_emit("clanger", side, fp, err,
					"%s gives away a clanger" % err["name"])
			if rng.randf() < float(T["clanger_is_free"]):
				_t(1 - side, "frees_for")
				_t(side, "frees_against")
				_p(err, "frees_against")
				next_side = 1 - side
				_emit("free", 1 - side, fp, err,
						"Free kick against %s" % err["name"])

	_emit("quarter", -1, fp, null, "End of quarter %d - %s %d.%d (%d) | %s %d.%d (%d)" % [
			quarter, squads[0].name, goals(0), behinds(0), score(0),
			squads[1].name, goals(1), behinds(1), score(1)])
	current_quarter += 1
	if quarter == 4:
		_emit("final", -1, 0.0, null, "Full time - %s %d.%d (%d) | %s %d.%d (%d)" % [
				squads[0].name, goals(0), behinds(0), score(0),
				squads[1].name, goals(1), behinds(1), score(1)])
	return result()


## The 18 on-ground players per side, so the pitch view can draw real
## guernseys and the match stats screen can show a real box score.
func rosters() -> Array:
	var out := []
	for sq in squads:
		var r := []
		for p in (sq as Squad).ground:
			r.append({
				"id": str(p["id"]), "num": int(p["num"]),
				"name": str(p["name"]), "role": str(p["role"]),
				"club": str(p["club"]), "overall": int(p["overall"]),
			})
		out.append(r)
	return out


func result() -> Dictionary:
	var s0 := score(0)
	var s1 := score(1)
	var winner := 0 if s0 > s1 else (1 if s1 > s0 else -1)
	var qsc := []
	for q in range(4):
		qsc.append([q_goals[q][0] * 6 + q_behinds[q][0],
				q_goals[q][1] * 6 + q_behinds[q][1]])
	return {
		"roster": rosters(),
		"score": [s0, s1],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"quarters": qsc,
		"q_goals": q_goals.duplicate(true),
		"q_behinds": q_behinds.duplicate(true),
		"team": [team_stats[0].duplicate(), team_stats[1].duplicate()],
		"players": player_stats.duplicate(true),
		"events": events,
		"winner": winner,
		"margin": absi(s0 - s1),
		"home": squads[0].code,
		"away": squads[1].code,
	}
