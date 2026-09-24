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
# Assistant-coach audit trail. Snapshots never touch the RNG, so calibration
# is unaffected. tactics_history[q] records the plans in force for that
# quarter; quarter_teams[q] records the cumulative team totals afterwards.
var tactics_history: Array = []
var quarter_teams: Array = []
## Finals cannot be drawn. With finals_mode on, a level score at the end of
## Q4 leads to extra time instead of the full-time siren.
var finals_mode := false
var extra_time_played := false

## Legs. Every player has energy (0-100): on-ground players tire each chain,
## the bench recovers, and coaches rotate tired players off. Energy scales a
## player's effective attributes (fit()), centred so an average match reads
## the same as before - a fresh player is a touch better, a cooked one worse.
var energy := {}
var rotation_policy := ["normal", "normal"]
var interchanges := [0, 0]
var _chain_no := 0
var _played := [{}, {}]      # side -> id -> true: everyone who took the field

## Where the result came from: expected points each cause added (positive
## helps that side). Pure arithmetic on the probabilities already rolled -
## no RNG draws - so it costs the calibration nothing.
var impact := [{}, {}]

## Match moments: live matches pause for the coach's call. Only the side in
## moment_side gets them, and they draw from their own RNG, so simulated
## matches (moment_side -1) never see one.
var moment_side := -1
var moment_rng := RandomNumberGenerator.new()
var pending_moment := {}
var moments: Array = []      # resolved moments, for the readouts
var bursts := [{}, {}]       # side -> {kind: chains left}: short-term calls
var _q_active := false
var _q_i := 0
var _q_count := 0
var _moments_this_q := 0
var _last_moment_chain := -100
var _run := [0, 0]           # unanswered goals
var _asked := {}             # one-off moment keys already offered
var _traits := {}            # player id -> Traits.of(), cached
var synergies := [[], []]    # side -> active synergy keys (the starting 18)


func _init(home: Squad, away: Squad, seed: int = 0) -> void:
	squads = [home, away]
	rng.seed = seed
	moment_rng.seed = seed * 7 + 13
	for side in range(2):
		synergies[side] = Traits.active((squads[side] as Squad).ground)
		for p in (squads[side] as Squad).ground:
			energy[str(p["id"])] = 100.0
			_played[side][str(p["id"])] = true
		for p in (squads[side] as Squad).bench:
			energy[str(p["id"])] = 100.0


func set_tactics(side: int, t: Dictionary) -> void:
	if side < 0 or side > 1:
		return
	tactics[side] = t.duplicate()


## Gameplan trade-offs. Every plan gives something up, and the main three
## counter each other: Attack corridor beats Controlled tempo (no pressure to
## punish it), Controlled tempo beats the Defensive press (it plays through
## the pressure), and the press beats Attack corridor (it squeezes the
## corridor into turnovers). Keys: goal (own conversion), opp_goal (theirs),
## exposed (their conversion when you turn it over), gain (metres),
## clangers, press (pressure you apply), taken (pressure you take),
## contest (stoppage win), pace (how fast legs go).
const PLANS := {
	"attacking": {"goal": 1.10, "gain": 1.12, "clangers": 1.12, "pace": 1.12, "exposed": 1.07},
	"fast": {"goal": 1.10, "gain": 1.12, "clangers": 1.12, "pace": 1.12, "exposed": 1.07},
	"defensive": {"press": 1.18, "opp_goal": 0.93, "goal": 0.96, "gain": 0.95, "pace": 1.12},
	"press": {"press": 1.18, "opp_goal": 0.93, "goal": 0.96, "gain": 0.95, "pace": 1.12},
	"contest": {"contest": 0.035, "gain": 0.95, "exposed": 1.04},
	"controlled": {"taken": 0.92, "gain": 0.94, "goal": 1.02, "clangers": 0.86, "pace": 0.9},
}


func _pv(side: int, key: String, fallback := 1.0) -> float:
	return float((PLANS.get(_plan(side), {}) as Dictionary).get(key, fallback))


## Pressure multiplier `side` faces from the opposition's plan, counters in.
func _press_on(side: int) -> float:
	var m := _pv(1 - side, "press")
	if m > 1.0 and _plan(side) == "controlled":
		m = 1.0
	elif m > 1.0 and (_plan(side) == "attacking" or _plan(side) == "fast"):
		m *= 1.10
	return m


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
		"name": "" if actor == null else GameDB.player_display_name(actor),
		"player_id": "" if actor == null else str(actor.get("id", "")),
		"num": 0 if actor == null else int(actor["num"]),
		"club": "" if actor == null else str(actor["club"]),
		"text": text,
		"score": [score(0), score(1)],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
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
		var w: float = pow(maxf(1.0, _a(p, key)), power)
		if side >= 0:
			w *= _tactic_player_mult(side, p, purpose)
		weights.append(w)
	return _pick(group, weights)


func _tactic_player_mult(side: int, p: Dictionary, purpose: String) -> float:
	var out := 1.0
	var id := str(p["id"])
	var focused := id == _focus_id(side)
	# A "run it through him" plan should make him the clear ball-winner, not
	# give him half the team's possessions. A small early boost, then the
	# usage curve fades him back toward a low-30s disposal game instead of 80.
	if focused and (purpose == "carrier" or purpose == "shooter"):
		out *= 1.14
	if purpose == "carrier" and _trait(p, "ball_magnet"):
		out *= 1.10
	if purpose == "clearance" and _trait(p, "bull"):
		out *= 1.15
	if id == _tag_id(1 - side) and (purpose == "carrier" or purpose == "shooter"):
		out *= 0.55
	if _plan(side) == "through_stars" and int(p["overall"]) >= 82:
		out *= 1.2
	if _pep(side) == "fire_up":
		out *= 1.05
	if purpose == "carrier":
		out *= _usage_mult(p, focused)
	return out


## Soft possession cap. Team disposal volume is unchanged — this only stops one
## player absorbing every chain once they have already had a huge game.
## Must match tools/sim_harness.py::usage_multiplier (the unfocused curve).
func _usage_mult(p: Dictionary, focused: bool) -> float:
	var d := 0.0
	var id := str(p["id"])
	if player_stats.has(id):
		d = float((player_stats[id] as Dictionary).get("disposals", 0.0))
	var start := 21.0 if focused else 18.0
	if d <= start:
		return 1.0
	var over := d - start
	var width := 5.4 if focused else 6.4
	return maxf(0.02, exp(-(over * over) / (width * width)))


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
	# Midfield legs scale the contest strength; the Legs line gets the credit.
	var c0: float = squads[0].contest * _mid_fit(0)
	var c1: float = squads[1].contest * _mid_fit(1)
	var legs_edge: float = ((c0 - c1) - (squads[0].contest - squads[1].contest)) / float(T["contest_swing"])
	_credit(0, "legs", legs_edge * POSSESSION_VALUE)
	_credit(1, "legs", -legs_edge * POSSESSION_VALUE)
	var p_home: float = (0.5
			+ (c0 - c1) / float(T["contest_swing"])
			+ float(T["home_ground_bonus"]))
	var b0 := _contest_bonus(0, not use_fp)
	var b1 := _contest_bonus(1, not use_fp)
	p_home += b0 - b1
	_credit_contest(0, not use_fp)
	_credit_contest(1, not use_fp)
	if use_fp:
		p_home += clampf(fp / 900.0, -0.07, 0.07)
	return 0 if rng.randf() < maxf(1.0 - lim, minf(lim, p_home)) else 1


func _contest_bonus(side: int, stoppage := false) -> float:
	return _contest_plan(side) + _contest_pep(side) + _contest_calls(side, stoppage) \
			+ _contest_traits(side)


func _contest_traits(side: int) -> float:
	return 0.025 if synergies[side].has("engine_room") else 0.0


func _contest_plan(side: int) -> float:
	return _pv(side, "contest", 0.0)


func _contest_pep(side: int) -> float:
	return 0.018 if _pep(side) == "fire_up" else 0.0


func _contest_calls(side: int, stoppage: bool) -> float:
	var b := 0.0
	if _burst(side, "stack") and stoppage:
		b += 0.10
	if _burst(side, "surge"):
		b += 0.06
	return b


## A won stoppage is worth about a possession chain's points.
const POSSESSION_VALUE := 1.0
const TURNOVER_VALUE := 0.5
const CLANGER_VALUE := 0.6


func _credit_contest(side: int, stoppage: bool) -> void:
	_credit(side, "gameplan", _contest_plan(side) * POSSESSION_VALUE)
	_credit(side, "pep", _contest_pep(side) * POSSESSION_VALUE)
	_credit(side, "calls", _contest_calls(side, stoppage) * POSSESSION_VALUE)
	_credit(side, "traits", _contest_traits(side) * POSSESSION_VALUE)


func _credit(side: int, cause: String, pts: float) -> void:
	if pts == 0.0:
		return
	var d: Dictionary = impact[side]
	d[cause] = float(d.get(cause, 0.0)) + pts


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
		var king := 0.0
		if not ruck_a.is_empty() and _trait(ruck_a[0], "ruck_king"):
			king += 0.05
		if not ruck_b.is_empty() and _trait(ruck_b[0], "ruck_king"):
			king -= 0.05
		var share := clampf(0.5 + (atk.ruck - dfn.ruck) / 260.0 + king, 0.15, 0.85)
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
				+ 0.30 * (100.0 - _a(carrier, "marking")) / 100.0)
		if rng.randf() < float(T["handball_share"]) * hb_bias:
			_t(side, "handballs")
			_p(carrier, "handballs")
			_emit("handball", side, fp, carrier, "%s handballs" % GameDB.player_display_name(carrier))
		else:
			_t(side, "kicks")
			_p(carrier, "kicks")
			var mark_p: float = (float(T["mark_share_of_kicks"])
					* (0.75 + 0.50 * _a(carrier, "marking") / 100.0))
			var marked := rng.randf() < mark_p
			if marked:
				_t(side, "marks")
				_p(carrier, "marks")
				_emit("mark", side, fp, carrier, "%s marks" % GameDB.player_display_name(carrier))
			else:
				_emit("kick", side, fp, carrier, "%s kicks" % GameDB.player_display_name(carrier))

		var pressure: float = (float(T["pressure_base"])
				* (0.72 + 0.56 * dfn.def_pressure / 100.0))
		atk_fp = fp if side == 0 else -fp
		pressure *= 1.10 if atk_fp < 0.0 else 0.95
		var p_base := pressure
		pressure *= _press_on(side)
		_credit(opp, "gameplan", (pressure - p_base) * TURNOVER_VALUE)
		if synergies[opp].has("lockdown_unit"):
			_credit(opp, "traits", pressure * 0.08 * TURNOVER_VALUE)
			pressure *= 1.08
		p_base = pressure
		pressure *= _pv(side, "taken")
		_credit(side, "gameplan", (p_base - pressure) * TURNOVER_VALUE)
		if _burst(side, "hold"):
			_credit(side, "calls", pressure * 0.15 * TURNOVER_VALUE)
			pressure *= 0.85

		if rng.randf() < pressure:
			_t(opp, "tackles")
			var tgroup := _by_roles(dfn.ground, ["MID", "DEF"])
			if tgroup.is_empty():
				tgroup = dfn.ground
			var tackler = _weighted(tgroup, "pressure", 2.0, opp, "tackler")
			_p(tackler, "tackles")
			var retain: float = (float(T["tackle_retention"])
					* (0.75 + 0.50 * _a(carrier, "contested") / 100.0))
			if _trait(carrier, "bull"):
				retain *= 1.10
			if rng.randf() < retain:
				fp += rng.randf_range(4.0, 12.0) * dir
				continue
			_emit("tackle", opp, fp, tackler,
					"%s tackles %s - ball up" % [GameDB.player_display_name(tackler), GameDB.player_display_name(carrier)])
			return {"outcome": "stoppage", "fp": fp, "actor": carrier}

		var prev_atk_fp := atk_fp
		var gain: float = (float(T["metres_gain_mean"])
				* (0.55 + 0.90 * _a(carrier, "carry") / 100.0))
		gain *= _pv(side, "gain")
		if synergies[side].has("supply_line"):
			gain *= 1.06
		if _burst(side, "flood") or _burst(side, "hold"):
			gain *= 0.85
		gain *= rng.randf_range(0.45, 1.75)
		fp += gain * dir
		fp = clampf(fp, -gline, gline)
		atk_fp = fp if side == 0 else -fp

		# Rebound 50: winning it out of your own defensive arc.
		if prev_atk_fp < float(T["rebound_from"]) and atk_fp > float(T["rebound_to"]):
			_t(side, "rebounds")
			_p(carrier, "rebounds")

		if atk_fp >= f50 and not touched_i50:
			touched_i50 = true
			_t(side, "inside50")
			_p(carrier, "inside50")
			_emit("inside50", side, fp, carrier,
					"%s sends it inside 50" % GameDB.player_display_name(carrier))
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
	var shooter = _weighted(sgroup, "goalkicking", float(T["shooter_power"]), side, "shooter")

	var dgroup := _by_roles(dfn.ground, ["DEF"])
	if dgroup.is_empty():
		dgroup = dfn.ground
	var defender = _weighted(dgroup, "intercept", 2.0, opp, "defender")

	var mark_edge := 0.06 if _trait(shooter, "aerial") else 0.0
	var marked := rng.randf() < clampf(
			0.5 + (atk.fwd_mark - dfn.def_intercept) / 240.0 + mark_edge, 0.10, 0.78)
	if marked:
		_t(side, "marks")
		_p(shooter, "marks")
	var spoil_edge := 0.05 if defender != null and _trait(defender, "interceptor") else 0.0
	var spoilt := rng.randf() < 0.30 + 0.35 * dfn.def_intercept / 100.0 + spoil_edge
	if rng.randf() < float(T["one_percenter_share"]):
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")

	var goal_p := shot_chance(side, shooter, marked, spoilt, true, feeder, defender)
	var behind_p: float = (float(T["inside50_behind"])
			* (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0))

	if side == moment_side and marked and _moment_ready():
		var close := current_quarter >= 4 and absi(score(side) - score(opp)) <= 18
		if moment_rng.randf() < (0.6 if close else 0.22):
			_offer_set_shot(side, fp, shooter, defender, goal_p, behind_p)
			return {"outcome": "moment", "fp": fp, "actor": shooter}

	var roll := rng.randf()
	if roll < goal_p:
		_t(side, "goals")
		_p(shooter, "goals")
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
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
			"%s rebounds it out of danger" % GameDB.player_display_name(defender))
	return {"outcome": "turnover", "fp": fp, "actor": defender}


## The goal chance for a shot. With `credit`, the tactical, fatigue and
## call multipliers are also logged as expected points in `impact`.
func shot_chance(side: int, shooter: Dictionary, marked: bool, spoilt: bool, credit := false,
		feeder = null, defender = null) -> float:
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var goal_p := float(T["inside50_goal"])
	goal_p *= 0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0
	goal_p *= 1.16 if marked else 0.74
	goal_p *= 0.82 + 0.36 * _a(shooter, "accuracy") / 100.0
	if spoilt and not marked:
		goal_p *= 0.58
	goal_p *= 0.90 + 0.20 * atk.attack / 100.0
	goal_p *= 1.06 - 0.12 * dfn.defence / 100.0
	if credit:
		# What fresh legs would have given, for the Legs line.
		var fresh := goal_p * (0.80 + 0.40 * float(shooter["attr"]["goalkicking"]) / 100.0) \
				/ (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0) \
				* (0.82 + 0.36 * float(shooter["attr"]["accuracy"]) / 100.0) \
				/ (0.82 + 0.36 * _a(shooter, "accuracy") / 100.0)
		_credit(side, "legs", 6.0 * (goal_p - fresh))
	var before := goal_p
	var own := _pv(side, "goal")
	# The press closes the corridor: half the attacking plan's edge.
	if own > 1.0 and _pv(opp, "press") > 1.0:
		own = 1.0 + (own - 1.0) * 0.5
	if _plan(side) == "through_stars" and int(shooter.get("overall", 0)) >= 82:
		own *= 1.08
	goal_p *= own
	if credit:
		_credit(side, "gameplan", 6.0 * (goal_p - before))
	before = goal_p
	# Controlled tempo picks the press apart and is too slow to punish an
	# attacking side on the rebound; everyone else meets both in full.
	if _plan(side) != "controlled":
		goal_p *= _pv(opp, "opp_goal")
		goal_p *= _pv(opp, "exposed")
	if credit:
		_credit(opp, "gameplan", 6.0 * (before - goal_p))
	before = goal_p
	var tr := 1.0
	if _trait(shooter, "sharpshooter"):
		tr *= 1.06
	if not marked and _trait(shooter, "crumber"):
		tr *= 1.12
	if feeder != null and _trait(feeder, "playmaker"):
		tr *= 1.05
	if synergies[side].has("tall_small"):
		tr *= 1.05
	goal_p *= tr
	if credit:
		_credit(side, "traits", 6.0 * (goal_p - before))
	before = goal_p
	var dtr := 1.0
	if defender != null and _trait(defender, "lockdown"):
		dtr *= 0.96
	if synergies[opp].has("intercept_wall"):
		dtr *= 0.95
	goal_p *= dtr
	if credit:
		_credit(opp, "traits", 6.0 * (before - goal_p))
	before = goal_p
	var call_mult := 1.0
	if _burst(side, "surge"):
		call_mult *= 1.08
	if _burst(side, "flood"):
		call_mult *= 0.90
	goal_p *= call_mult
	if credit:
		_credit(side, "calls", 6.0 * (goal_p - before))
	before = goal_p
	var opp_mult := 1.0
	if _burst(opp, "flood"):
		opp_mult *= 0.80
	if _burst(opp, "stack"):
		opp_mult *= 1.12
	if _burst(opp, "surge"):
		opp_mult *= 1.10
	goal_p *= opp_mult
	if credit:
		_credit(opp, "calls", 6.0 * (before - goal_p))
	return goal_p


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
	if needs_extra_time():
		run_extra_time()
	return result()


## Play a whole quarter. A live match can instead step through it with
## begin_quarter() / continue_quarter() / end_quarter(), stopping for moments;
## anything still pending here takes the default call.
func run_quarter() -> Dictionary:
	if not _q_active:
		begin_quarter()
	while not continue_quarter():
		resolve_moment(int(pending_moment.get("default", 0)))
	return end_quarter()


func quarter_in_progress() -> bool:
	return _q_active


func begin_quarter() -> void:
	var T := Ratings.T
	# Snapshot the plans before any rolls so the half-time report can say
	# what each side actually used in Q1/Q2. Duplicates only, no RNG draws.
	tactics_history.append({
		"quarter": current_quarter,
		"plans": [(tactics[0] as Dictionary).duplicate(), (tactics[1] as Dictionary).duplicate()],
	})
	if current_quarter > 1:
		for id in energy:
			energy[id] = minf(100.0, float(energy[id]) + ENERGY_BREAK_RECOVER)
	_q_active = true
	_q_i = 0
	_q_count = floori(float(T["chains_per_game"]) / 4.0)
	_moments_this_q = 0


## Play on until the quarter's chains are done (true) or a moment needs the
## coach (false: see pending_moment, then resolve_moment()).
func continue_quarter() -> bool:
	var T := Ratings.T
	while _q_i < _q_count:
		if not pending_moment.is_empty():
			return false
		current_minute = (current_quarter - 1) * 30 + int(30 * _q_i / maxi(1, _q_count)) + 1
		if moment_side >= 0 and _boundary_moment():
			return false
		_q_i += 1
		_play_one_chain(T)
		if not pending_moment.is_empty():
			return false
	return pending_moment.is_empty()


func end_quarter() -> Dictionary:
	var quarter := current_quarter
	_q_active = false
	quarter_teams.append({
		"quarter": quarter,
		"team": [team_stats[0].duplicate(), team_stats[1].duplicate()],
		"players": player_stats.duplicate(true),
		"score": [score(0), score(1)],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"impact": impact.duplicate(true),
	})
	_emit("quarter", -1, fp, null, "End of quarter %d - %s %d.%d (%d) | %s %d.%d (%d)" % [
		quarter, squads[0].name, goals(0), behinds(0), score(0),
		squads[1].name, goals(1), behinds(1), score(1)])
	current_quarter += 1
	if quarter == 4:
		if needs_extra_time():
			# No siren: the pitch keeps going into extra time.
			_emit("quarter", -1, 0.0, null,
					"Scores level at full time - we are going to extra time!")
		else:
			_emit_full_time("Full time")
	return result()


## True once a finals match is level after four quarters and extra time has
## not been played yet.
func needs_extra_time() -> bool:
	return finals_mode and not extra_time_played and current_quarter > 4 \
			and score(0) == score(1)


## AFL finals extra time: two short halves (three minutes plus time on),
## then, if still level, the next score wins. Only ever runs after Q4 of a
## level final, so home-and-away matches and calibration are untouched.
func run_extra_time() -> Dictionary:
	if not needs_extra_time():
		return result()
	extra_time_played = true
	current_quarter = 5
	q_goals.append([0, 0])
	q_behinds.append([0, 0])
	var T := Ratings.T
	var per_half: int = maxi(4, roundi(float(T["chains_per_game"]) / 4.0 * 0.15))
	at_centre = true
	_play_chains(per_half, 120, 4)
	_emit("quarter", -1, fp, null, "Extra time, half time - %s %d | %s %d" % [
			squads[0].name, score(0), squads[1].name, score(1)])
	at_centre = true
	_play_chains(per_half, 124, 4)
	if score(0) == score(1):
		_emit("quarter", -1, fp, null, "Still level - next score wins!")
		var guard := 0
		while score(0) == score(1) and guard < GOLDEN_POINT_CHAINS:
			current_minute = 128 + int(guard / 4)
			_play_one_chain(T)
			guard += 1
	_emit_full_time("Full time (after extra time)")
	return result()


const GOLDEN_POINT_CHAINS := 60


func _emit_full_time(prefix: String) -> void:
	_emit("final", -1, 0.0, null, "%s - %s %d.%d (%d) | %s %d.%d (%d)" % [
			prefix, squads[0].name, goals(0), behinds(0), score(0),
			squads[1].name, goals(1), behinds(1), score(1)])


## Play `count` possession chains, stamping minutes across `span` minutes
## from `minute_base`. Shared by the four quarters and extra time; the RNG
## call order is exactly the original quarter loop's.
func _play_chains(count: int, minute_base: int, span: int) -> void:
	var T := Ratings.T
	for i in range(count):
		current_minute = minute_base + int(span * i / maxi(1, count)) + 1
		_play_one_chain(T)


func _play_one_chain(T: Dictionary) -> void:
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
	if outcome == "moment":
		# The chain ends on the coach's call: resolve_moment() finishes it.
		return

	at_centre = (outcome == "score")
	next_side = (1 - side) if outcome == "turnover" else -1
	if outcome == "score":
		fp = 0.0

	# End-of-chain error: a clanger, sometimes a free kick against.
	var clanger_p := float(T["clanger_per_chain"])
	var cl_mult := _pv(side, "clangers")
	_credit(side, "gameplan", clanger_p * (1.0 - cl_mult) * CLANGER_VALUE)
	clanger_p *= cl_mult
	if _burst(side, "hold"):
		_credit(side, "calls", clanger_p * 0.25 * CLANGER_VALUE)
		clanger_p *= 0.75
	if rng.randf() < clanger_p:
		var ground: Array = squads[side].ground
		var weights := []
		for p in ground:
			weights.append(float(pow(maxf(1.0, 101.0
					- _a(p, "discipline")), 1.6)) * (1.5 if _trait(p, "hothead") else 1.0))
		var err = _pick(ground, weights)
		_t(side, "clangers")
		_p(err, "clangers")
		_emit("clanger", side, fp, err,
				"%s gives away a clanger" % GameDB.player_display_name(err))
		if rng.randf() < float(T["clanger_is_free"]):
			_t(1 - side, "frees_for")
			_t(side, "frees_against")
			_p(err, "frees_against")
			next_side = 1 - side
			_emit("free", 1 - side, fp, err,
					"Free kick against %s" % GameDB.player_display_name(err))
	_after_chain()


## The 18 on-ground players per side, so the pitch view can draw real
## guernseys and the match stats screen can show a real box score.
func rosters() -> Array:
	var out := []
	for sq in squads:
		var r := []
		var side := out.size()
		var on: Array = (sq as Squad).ground.duplicate()
		for p in (sq as Squad).bench:
			if _played[side].has(str(p["id"])):
				on.append(p)
		for p in on:
			r.append({
				"id": str(p["id"]), "num": int(p["num"]),
				"name": GameDB.player_display_name(p), "role": str(p["role"]),
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
		"tactics_history": tactics_history.duplicate(true),
		"quarter_teams": quarter_teams.duplicate(true),
		"extra_time": extra_time_played,
		"impact": impact.duplicate(true),
		"moments": moments.duplicate(true),
		"interchanges": interchanges.duplicate(),
	}


# ---------------------------------------------------------------------------
# Legs: fatigue and rotations
# ---------------------------------------------------------------------------
const ENERGY_DRAIN := 0.9            # per chain on the ground, before modifiers
const ENERGY_BENCH_RECOVER := 4.0    # per chain on the bench
const ENERGY_BREAK_RECOVER := 20.0   # at each quarter break
const ROTATE_EVERY := 3              # chains between rotation checks
const ROLE_DRAIN := {"MID": 1.25, "RUCK": 1.15, "DEF": 0.85, "FWD": 0.9}
const STAR_OVR := 80
## Energy below which a player is rotated off: stars are ridden harder.
const ROTATION_POLICIES := {
	"hard": {"label": "Rotate hard", "role": 80.0, "star": 68.0,
			"text": "Fresh legs all day: everyone comes off early, stars included."},
	"normal": {"label": "Normal rotations", "role": 70.0, "star": 50.0,
			"text": "Rotate the group, ride the stars a little longer."},
	"stars": {"label": "Ride the stars", "role": 68.0, "star": 25.0,
			"text": "Your 80+ players stay on until they are cooked."},
}
## fit(): effective-attribute multiplier. 0.80 + 0.25 x energy puts an
## average match (~80 energy) at 1.0: fresh 1.05, cooked (30) 0.875.
const FIT_BASE := 0.80
const FIT_SLOPE := 0.25


func fit(p: Dictionary) -> float:
	var f := FIT_BASE + FIT_SLOPE * float(energy.get(str(p["id"]), 100.0)) / 100.0
	if (current_quarter >= 4 or finals_mode) and _trait(p, "big_game"):
		f += 0.05
	return f


func _trait(p: Dictionary, key: String) -> bool:
	var id := str(p.get("id", ""))
	if not _traits.has(id):
		_traits[id] = Traits.of(p)
	return (_traits[id] as Array).has(key)


## A player's attribute as he is playing right now.
func _a(p: Dictionary, key: String) -> float:
	return float(p["attr"][key]) * fit(p)


## Mean fit of the on-ground midfielders and rucks: who wins the stoppages.
func _mid_fit(side: int) -> float:
	var total := 0.0
	var n := 0
	for p in (squads[side] as Squad).ground:
		if str(p["role"]) == "MID" or str(p["role"]) == "RUCK":
			total += fit(p)
			n += 1
	return total / float(n) if n > 0 else 1.0


func set_rotation_policy(side: int, key: String) -> void:
	if side >= 0 and side <= 1 and ROTATION_POLICIES.has(key):
		rotation_policy[side] = key


func _after_chain() -> void:
	for side in range(2):
		var sq: Squad = squads[side]
		var pace := _pv(side, "pace")
		if _pep(side) == "fire_up":
			pace *= 1.05
		if _burst(side, "surge"):
			pace *= 1.3
		if synergies[side].has("running_machine"):
			pace *= 0.85
		for p in sq.ground:
			var id := str(p["id"])
			var dur := float((p["attr"] as Dictionary).get("durability", 70.0))
			var d := ENERGY_DRAIN * float(ROLE_DRAIN.get(str(p["role"]), 1.0)) \
					* (1.2 - 0.4 * dur / 100.0) * pace
			if _trait(p, "engine"):
				d *= 0.75
			energy[id] = maxf(5.0, float(energy.get(id, 100.0)) - d)
		for p in sq.bench:
			var id := str(p["id"])
			energy[id] = minf(100.0, float(energy.get(id, 100.0)) + ENERGY_BENCH_RECOVER)
		var b: Dictionary = bursts[side]
		for k in b.keys():
			b[k] = int(b[k]) - 1
			if int(b[k]) <= 0:
				b.erase(k)
	_chain_no += 1
	if _chain_no % ROTATE_EVERY == 0:
		for side in range(2):
			_auto_rotate(side)


## One interchange per check: the most tired player past his policy's line
## comes off for the freshest bench player who can play the spot.
func _auto_rotate(side: int) -> void:
	var sq: Squad = squads[side]
	var policy: Dictionary = ROTATION_POLICIES.get(rotation_policy[side], ROTATION_POLICIES["normal"])
	var worst := -1
	var worst_e := 101.0
	for i in range(sq.ground.size()):
		var p: Dictionary = sq.ground[i]
		var e := float(energy.get(str(p["id"]), 100.0))
		var line := float(policy["star"]) if int(p["overall"]) >= STAR_OVR else float(policy["role"])
		if e < line and e < worst_e:
			worst = i
			worst_e = e
	if worst < 0:
		return
	var bi := _bench_for(side, str((sq.ground[worst] as Dictionary)["role"]), 85.0)
	if bi >= 0:
		_swap(side, worst, bi)


## The freshest bench player (at or above `min_energy`) for a ground role,
## or -1. Natural or secondary role first; any bench player as a fallback.
func _bench_for(side: int, role: String, min_energy: float) -> int:
	var sq: Squad = squads[side]
	var best := -1
	var best_score := -1.0
	for i in range(sq.bench.size()):
		var p: Dictionary = sq.bench[i]
		var e := float(energy.get(str(p["id"]), 100.0))
		if e < min_energy:
			continue
		var fits := str(p.get("role", "")) == role or str(p.get("role2", "")) == role \
				or str(p.get("list_tag", "")) == role
		var score := e + (100.0 if fits else 0.0)
		if score > best_score:
			best = i
			best_score = score
	return best


func _swap(side: int, gi: int, bi: int) -> void:
	var sq: Squad = squads[side]
	var off: Dictionary = sq.ground[gi]
	var on: Dictionary = sq.bench[bi]
	var slot := str(off["role"])
	var on_slot: Dictionary = on if str(on["role"]) == slot else Ratings._for_slot(on, slot)
	sq.ground[gi] = on_slot
	sq.bench[bi] = off
	interchanges[side] += 1
	_played[side][str(on["id"])] = true
	events.append({
		"q": current_quarter, "min": current_minute, "kind": "sub", "side": side, "fp": fp,
		"name": GameDB.player_display_name(on_slot), "player_id": str(on["id"]),
		"num": int(on["num"]), "off_num": int(off["num"]), "club": str(on.get("club", "")),
		"text": "Interchange: %s on for %s" % [GameDB.player_display_name(on_slot),
				GameDB.player_display_name(off)],
		"score": [score(0), score(1)], "goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
	})


## Energy for one side, most tired first: [{id, name, num, role, overall,
## energy, on}] with the bench after the ground.
func legs(side: int) -> Array:
	var sq: Squad = squads[side]
	var out := []
	for group in [[sq.ground, true], [sq.bench, false]]:
		var rows := []
		for p in group[0]:
			rows.append({"id": str(p["id"]), "name": GameDB.player_display_name(p),
					"num": int(p["num"]), "role": str(p["role"]), "overall": int(p["overall"]),
					"energy": float(energy.get(str(p["id"]), 100.0)), "on": bool(group[1])})
		rows.sort_custom(func(a, b): return float(a["energy"]) < float(b["energy"]))
		out.append_array(rows)
	return out


func average_energy(side: int) -> float:
	var sq: Squad = squads[side]
	var total := 0.0
	for p in sq.ground:
		total += float(energy.get(str(p["id"]), 100.0))
	return total / float(maxi(1, sq.ground.size()))


# ---------------------------------------------------------------------------
# Match moments
# ---------------------------------------------------------------------------
const MAX_MOMENTS_Q := 2
const MOMENT_GAP := 8                # chains between moments
const BURSTS := {
	"stack": {"label": "Stack the stoppage", "chains": 4},
	"flood": {"label": "Flood behind the ball", "chains": 5},
	"surge": {"label": "Throw numbers at it", "chains": 8},
	"hold": {"label": "Slow it down", "chains": 8},
}


func _burst(side: int, kind: String) -> bool:
	return (bursts[side] as Dictionary).has(kind)


func _moment_ready() -> bool:
	return moment_side >= 0 and _moments_this_q < MAX_MOMENTS_Q \
			and _chain_no - _last_moment_chain >= MOMENT_GAP and current_quarter <= 4


func _fire(m: Dictionary) -> void:
	m["q"] = current_quarter
	m["min"] = current_minute
	m["side"] = moment_side
	pending_moment = m
	_moments_this_q += 1
	_last_moment_chain = _chain_no


## Situations spotted between chains: a tired star, a hot opposition
## forward, a run of goals against, a tight last-quarter centre bounce.
func _boundary_moment() -> bool:
	if not _moment_ready():
		return false
	var me := moment_side
	var opp := 1 - me
	var margin := score(me) - score(opp)
	# A star running on empty.
	for p in (squads[me] as Squad).ground:
		var id := str(p["id"])
		var e := float(energy.get(id, 100.0))
		var key := "tired|%s|%d" % [id, current_quarter]
		if int(p["overall"]) >= STAR_OVR and e < 58.0 and not _asked.has(key):
			_asked[key] = true
			_fire({"kind": "tired", "player_id": id, "default": 1,
				"title": "%s is running on empty" % GameDB.player_display_name(p),
				"text": "Your star is down to %d%% legs. Tired players win less of the ball and kick fewer goals." % int(e),
				"options": [
					{"key": "rest", "label": "Rest him now",
						"detail": "The freshest bench player takes his spot; he recovers on the bench."},
					{"key": "keep", "label": "Keep him out there",
						"detail": "He stays on and keeps tiring (%d%% legs)." % int(e)},
				]})
			return true
	# An opposition forward kicking a bag.
	for id in player_stats:
		var st: Dictionary = player_stats[id]
		if int(st.get("goals", 0.0)) < 3 or _asked.has("hot|" + str(id)):
			continue
		var hot := _on_ground(opp, str(id))
		if hot.is_empty() or _tag_id(me) == str(id):
			continue
		_asked["hot|" + str(id)] = true
		var stopper := _best_stopper(me)
		_fire({"kind": "hot", "player_id": str(id), "default": 1,
			"title": "%s has kicked %d" % [GameDB.player_display_name(hot), int(st["goals"])],
			"text": "Their forward is on fire. A tag takes a good chunk of the ball off him, but your stopper stops playing his own game.",
			"options": [
				{"key": "tag", "label": "Tag him with %s" % stopper,
					"detail": "For the rest of the quarter he gets about half as much of the ball."},
				{"key": "leave", "label": "Back your defenders",
					"detail": "Keep the structure as it is."},
			]})
		return true
	# Three goals in a row against.
	if _run[opp] >= 3 and not _asked.has("run|%d|%d" % [current_quarter, goals(opp)]):
		_asked["run|%d|%d" % [current_quarter, goals(opp)]] = true
		_fire({"kind": "momentum", "default": 2,
			"title": "They have kicked %d in a row" % _run[opp],
			"text": "The game is getting away from you. Make a call for the next few minutes.",
			"options": [
				{"key": "surge", "label": "Throw numbers at it",
					"detail": "Win more of the ball and kick straighter, but leave the back door open and burn legs."},
				{"key": "hold", "label": "Slow it down",
					"detail": "Chip it around: fewer turnovers and clangers, less ground gained."},
				{"key": "none", "label": "Ride it out",
					"detail": "Trust the plan. No change."},
			]})
		return true
	# A tight last-quarter centre bounce.
	if current_quarter == 4 and at_centre and current_minute >= 100 and absi(margin) <= 12 \
			and int(_asked.get("bounce", 0)) < 2:
		_asked["bounce"] = int(_asked.get("bounce", 0)) + 1
		var state := "level" if margin == 0 else ("%d up" % margin if margin > 0 else "%d down" % -margin)
		_fire({"kind": "bounce", "default": 2,
			"title": "Centre bounce - %s with %d minutes left" % [state, 120 - current_minute],
			"text": "Set up for the next few minutes of the game.",
			"options": [
				{"key": "stack", "label": "Stack the stoppage",
					"detail": "Extra numbers at the bounce: win far more clearances, but they score more easily if they get out."},
				{"key": "flood", "label": "Flood behind the ball",
					"detail": "Protect the lead: they score far less, and so do you."},
				{"key": "none", "label": "Play it straight",
					"detail": "No change."},
			]})
		return true
	return false


func _on_ground(side: int, id: String) -> Dictionary:
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) == id:
			return p
	return {}


func _best_stopper(side: int) -> String:
	var best := {}
	for p in (squads[side] as Squad).ground:
		if str(p["role"]) == "DEF" and (best.is_empty() or _a(p, "pressure") > _a(best, "pressure")):
			best = p
	return GameDB.player_display_name(best) if not best.is_empty() else "a defender"


## A marked shot inside 50: take it, play on to a teammate, or bomb it long.
func _offer_set_shot(side: int, p_fp: float, shooter: Dictionary, defender, goal_p: float, behind_p: float) -> void:
	var r := moment_rng.randf()
	var spot := "from 45 metres on a slight angle"
	var angle := 1.0
	if r < 0.4:
		spot = "from 30 metres, straight in front"
		angle = 1.18
	elif r >= 0.8:
		spot = "from the pocket, on a tight angle"
		angle = 0.72
	var dfn: Squad = squads[1 - side]
	var shot_goal := clampf(goal_p * angle, 0.05, 0.92)
	var shot_behind := minf(behind_p * (1.3 if angle < 1.0 else 1.0), (1.0 - shot_goal) * 0.85)
	var mate := {}
	for p in _by_roles((squads[side] as Squad).ground, ["FWD", "MID"]):
		if str(p["id"]) != str(shooter["id"]) and (mate.is_empty() or _a(p, "goalkicking") > _a(mate, "goalkicking")):
			mate = p
	var pass_p := clampf(0.50 + 0.35 * _a(shooter, "disposal") / 100.0
			- 0.25 * dfn.def_intercept / 100.0, 0.35, 0.85)
	var mate_goal := clampf(shot_chance(side, mate, true, false) * 1.3, 0.05, 0.9) if not mate.is_empty() else 0.0
	var bomb_goal := clampf(0.26 + 0.20 * (squads[side] as Squad).fwd_mark / 100.0
			- 0.12 * dfn.def_intercept / 100.0, 0.1, 0.5)
	var options := [
		{"key": "shoot", "label": "Take the shot",
			"detail": "Goal %d%%  -  behind %d%%" % [roundi(shot_goal * 100), roundi(shot_behind * 100)],
			"goal": shot_goal, "behind": shot_behind},
	]
	if not mate.is_empty():
		options.append({"key": "pass", "label": "Play on to %s" % GameDB.player_display_name(mate),
			"detail": "Pass sticks %d%%, then he shoots from closer (%d%%)  -  goal %d%% overall" % [
				roundi(pass_p * 100), roundi(mate_goal * 100), roundi(pass_p * mate_goal * 100)],
			"goal": pass_p * mate_goal, "pass": pass_p, "mate_goal": mate_goal,
			"mate_id": str(mate["id"])})
	options.append({"key": "bomb", "label": "Bomb it to the goal square",
		"detail": "Goal %d%%  -  behind 30%%  -  else they rebound" % roundi(bomb_goal * 100),
		"goal": bomb_goal, "behind": 0.30})
	_fire({"kind": "set_shot", "default": 0, "player_id": str(shooter["id"]),
		"defender_id": "" if defender == null else str(defender["id"]), "fp": p_fp,
		"title": "%s marks %s" % [GameDB.player_display_name(shooter), spot],
		"text": "Your call. %s: goalkicking %d, accuracy %d, legs %d%%." % [
			GameDB.player_display_name(shooter), int(shooter["attr"]["goalkicking"]),
			int(shooter["attr"]["accuracy"]), int(energy.get(str(shooter["id"]), 100.0))],
		"options": options})


## Apply the coach's call for the pending moment. Returns the resolved
## moment (with "choice" and "outcome"), and play can continue.
func resolve_moment(choice: int) -> Dictionary:
	if pending_moment.is_empty():
		return {}
	var m := pending_moment
	pending_moment = {}
	var options: Array = m.get("options", [])
	choice = clampi(choice, 0, maxi(0, options.size() - 1))
	var opt: Dictionary = options[choice] if not options.is_empty() else {}
	var side := int(m.get("side", moment_side))
	var key := str(opt.get("key", ""))
	var outcome := ""
	var points := 0
	match str(m.get("kind", "")):
		"set_shot":
			var res := _resolve_shot(side, m, opt)
			outcome = str(res["text"])
			points = int(res["points"])
		"tired":
			if key == "rest":
				var gi := -1
				var sq: Squad = squads[side]
				for i in range(sq.ground.size()):
					if str((sq.ground[i] as Dictionary)["id"]) == str(m["player_id"]):
						gi = i
				var bi := _bench_for(side, str((sq.ground[gi] as Dictionary)["role"]) if gi >= 0 else "MID", 0.0)
				if gi >= 0 and bi >= 0:
					_swap(side, gi, bi)
					outcome = "Rested. He will be back fresher."
				else:
					outcome = "No one on the bench to bring on."
			else:
				outcome = "He stays on."
		"hot":
			if key == "tag":
				var t: Dictionary = (tactics[side] as Dictionary).duplicate()
				t["tag_id"] = str(m["player_id"])
				tactics[side] = t
				outcome = "Tag on for the rest of the quarter."
			else:
				outcome = "Structure unchanged."
		"momentum", "bounce":
			if BURSTS.has(key):
				(bursts[side] as Dictionary)[key] = int(BURSTS[key]["chains"])
				outcome = "%s for the next few minutes." % str(BURSTS[key]["label"])
			else:
				outcome = "No change."
	m["choice"] = choice
	m["choice_label"] = str(opt.get("label", ""))
	m["outcome"] = outcome
	m["points"] = points
	moments.append(m)
	_emit("moment", side, fp, null, "Coach's call: %s - %s" % [m["choice_label"], outcome])
	return m


func _resolve_shot(side: int, m: Dictionary, opt: Dictionary) -> Dictionary:
	var opp := 1 - side
	var shooter := _on_ground(side, str(m["player_id"]))
	if shooter.is_empty():
		shooter = (squads[side] as Squad).ground[0]
	var defender := _on_ground(opp, str(m.get("defender_id", "")))
	var key := str(opt.get("key", "shoot"))
	fp = float(m.get("fp", fp))
	var kicker := shooter
	var goal_p := float(opt.get("goal", 0.3))
	var behind_p := float(opt.get("behind", 0.2))
	if key == "pass":
		_t(side, "disposals")
		_t(side, "kicks")
		_p(shooter, "disposals")
		_p(shooter, "kicks")
		if rng.randf() >= float(opt.get("pass", 0.6)):
			return _shot_turnover(side, defender, "%s's pass is intercepted" % GameDB.player_display_name(shooter))
		kicker = _on_ground(side, str(opt.get("mate_id", "")))
		if kicker.is_empty():
			kicker = shooter
		_p(shooter, "goal_assists")
		goal_p = float(opt.get("mate_goal", 0.5))
		behind_p = (1.0 - goal_p) * 0.6
	var roll := rng.randf()
	if roll < goal_p:
		_t(side, "goals")
		_p(kicker, "goals")
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, fp, kicker, _scoreline(side, "GOAL"))
		_end_moment_chain("score", 0.0, side)
		return {"points": 6, "text": "GOAL to %s!" % GameDB.player_display_name(kicker)}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(kicker, "behinds")
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, kicker, _scoreline(side, "Behind"))
		_end_moment_chain("score", 0.0, side)
		return {"points": 1, "text": "Just a behind from %s." % GameDB.player_display_name(kicker)}
	return _shot_turnover(side, defender, "%s's shot is rebounded" % GameDB.player_display_name(kicker))


func _shot_turnover(side: int, defender: Dictionary, text: String) -> Dictionary:
	var opp := 1 - side
	_t(opp, "rebounds")
	if not defender.is_empty():
		_p(defender, "rebounds")
		_emit("rebound", opp, fp, defender, "%s rebounds it out of danger" % GameDB.player_display_name(defender))
	_end_moment_chain("turnover", fp, side)
	return {"points": 0, "text": text + " - no score."}


func _end_moment_chain(outcome: String, new_fp: float, side: int) -> void:
	fp = new_fp
	at_centre = outcome == "score"
	next_side = (1 - side) if outcome == "turnover" else -1
	_after_chain()


func _score_run(side: int) -> void:
	_run[side] += 1
	_run[1 - side] = 0



# ---------------------------------------------------------------------------
# The rival coach (live matches)
# ---------------------------------------------------------------------------
## What beats what (see PLANS).
const COUNTERS := {"attacking": "defensive", "fast": "defensive", "defensive": "controlled",
		"press": "controlled", "controlled": "attacking", "contest": "attacking",
		"through_stars": "defensive"}


## The opposition's plan for the coming quarter: protect a big lead, chase a
## big deficit, and counter a plan you have run two quarters in a row. From
## half time it tags your most influential player.
func ai_tactics(side: int) -> Dictionary:
	var opp := 1 - side
	var margin := score(side) - score(opp)
	var plan := "balanced"
	if margin >= 18:
		plan = "controlled"
	elif margin <= -18:
		plan = "attacking"
	var n := tactics_history.size()
	if n >= 2:
		var last := str(((tactics_history[n - 1]["plans"] as Array)[opp] as Dictionary).get("gameplan", "balanced"))
		var prev := str(((tactics_history[n - 2]["plans"] as Array)[opp] as Dictionary).get("gameplan", "balanced"))
		if last == prev and COUNTERS.has(last):
			plan = str(COUNTERS[last])
	var t := {"gameplan": plan, "pep": "fire_up" if margin <= -12 and current_quarter >= 3 else "steady"}
	if current_quarter >= 3:
		var best := ""
		var best_inf := -1.0
		for p in (squads[opp] as Squad).ground:
			var inf := CoachReport.influence(player_stats.get(str(p["id"]), {}))
			if inf > best_inf:
				best_inf = inf
				best = str(p["id"])
		t["tag_id"] = best
	return t


## The counter to a plan, for the coach box hint ("" when there is none).
static func counter_to(plan: String) -> String:
	return str(COUNTERS.get(plan, ""))
