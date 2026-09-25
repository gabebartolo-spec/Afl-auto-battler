class_name MatchDirector
extends RefCounted
## Visual interpretation of a MatchSim event log.
##
## MatchSim decides everything that happens. Its log says who had the ball,
## where along the ground (fp, metres, side 0 attacking +x) and what they did.
## The director decides only how that looks: where across the ground the
## ball goes, how long it is in the air, who leads to it and who chases, how
## the teams hold their shape, and how stoppages and restarts are staged. It
## never reads or changes MatchSim, never writes to an event, and draws from
## its own random stream, so replaying a match cannot change it.
##
## Each event becomes a beat: a short list of phases (a kick in flight, a
## receiver collecting, the event itself, the carrier running on). The event
## is released to the match screen at the phase where it visibly happens: a
## mark when the ball is caught, a goal when it crosses the line.
##
## Shapes follow what real footage shows (see docs/MATCH_VIEW.md): most of the
## ground holds a structure and barely moves while six to ten players work
## around the ball; every player pairs with an opponent and one defender
## sits loose; centre bounces set up 6-6-6; kick-ins face a zone.

const DISPOSALS := ["handball", "kick", "mark"]
const META := ["sub", "moment"]
const SUBSTEP := 1.0 / 60.0
const STRUCTURE_EVERY := 0.45
## Presentation time runs this much faster than the movement model's own
## clock: a broadcast pace, so a match fits a few minutes at the default 4x.
const TEMPO := 1.65

## Positions in the attacking frame of a side: x toward the goal it attacks.
## Paired names (FB/FF, BPL/FPL, ...) sit on the same ground, so every player
## has a direct opponent.
const SLOTS := {
	"RUCK": [["R", Vector2(-2, 3)]],
	"MID": [["C", Vector2(3, -5)], ["RR", Vector2(-6, 9)], ["RV", Vector2(-9, -9)],
			["WL", Vector2(0, -40)], ["WR", Vector2(0, 40)]],
	"DEF": [["FB", Vector2(-68, 0)], ["BPL", Vector2(-62, -20)], ["BPR", Vector2(-62, 20)],
			["CHB", Vector2(-44, 0)], ["HBL", Vector2(-40, -30)], ["HBR", Vector2(-40, 30)]],
	"FWD": [["FF", Vector2(66, 0)], ["FPL", Vector2(60, -20)], ["FPR", Vector2(60, 20)],
			["CHF", Vector2(42, 0)], ["HFL", Vector2(38, -30)], ["HFR", Vector2(38, 30)]],
}
const EXTRA_SLOTS := [Vector2(-20, -16), Vector2(20, 16), Vector2(-20, 16),
		Vector2(20, -16), Vector2(-28, 0), Vector2(28, 0), Vector2(0, -24), Vector2(0, 24)]
const OPPOSITE := {"FB": "FF", "BPL": "FPL", "BPR": "FPR", "CHB": "CHF", "HBL": "HFL",
		"HBR": "HFR", "FF": "FB", "FPL": "BPL", "FPR": "BPR", "CHF": "CHB", "HFL": "HBL",
		"HFR": "HBR", "C": "C", "RR": "RR", "RV": "RV", "WL": "WL", "WR": "WR", "R": "R"}

## Centre-bounce set-up (attacking frame): at most four per side in the
## centre square, wingers on the wings, six in each 50 m arc. Defenders stand
## goal-side of their forward.
const CENTRE := {
	"R": Vector2(-1.2, 0), "C": Vector2(-5, -5), "RR": Vector2(-5, 5), "RV": Vector2(-9, 0),
	"WL": Vector2(-1, -36), "WR": Vector2(-1, 36),
	"FB": Vector2(-72, 0), "BPL": Vector2(-68, -15), "BPR": Vector2(-68, 15),
	"CHB": Vector2(-47, 0), "HBL": Vector2(-51, -22), "HBR": Vector2(-51, 22),
	"FF": Vector2(70, 0), "FPL": Vector2(66, -15), "FPR": Vector2(66, 15),
	"CHF": Vector2(45, 0), "HFL": Vector2(49, -22), "HFR": Vector2(49, 22),
}
const SQUARE := ["R", "C", "RR", "RV"]

## The zone a side sets against a kick-in (attacking frame of the zoning side,
## so these lines sit in the kicking side's back half).
const ZONE := {
	"FWD": [Vector2(50, -30), Vector2(50, -10), Vector2(50, 10), Vector2(50, 30),
			Vector2(64, -12), Vector2(64, 12)],
	"MID": [Vector2(24, -38), Vector2(24, -22), Vector2(24, -7), Vector2(24, 7),
			Vector2(24, 22), Vector2(24, 38)],
	"DEF": [Vector2(-2, -30), Vector2(-2, -10), Vector2(-2, 10), Vector2(-2, 30),
			Vector2(-22, -8), Vector2(-22, 8)],
}

var events: Array = []
var tokens: Array = []          # every token; ids index this array
var ball := {}
var cursor := 0                 # next event to stage
var emitted := 0                # events released so far
var time := 0.0
var mode := "centre"            # camera hint: centre, stoppage, open, shot, kickin, break
var actor := -1                 # token id the feed is talking about
var flash := {}                 # {pos, left, goal}
## Every time the ball reaches an event's location: {idx, kind, pos, want_x}.
## Kept for the tests and the capture tool; bounded.
var arrivals: Array = []

var _rng := RandomNumberGenerator.new()
var _ids := [{}, {}]            # side -> {num: token id}
var _beat := {}
var _phases: Array = []
var _pi := 0
var _pt := 0.0
var _locs := {}                 # event index -> planned ball location
var _busy := {}                 # token ids a phase is steering this beat
var _struct_ball := Vector2.ZERO
var _poss := 0
var _struct_timer := 0.0
var _out: Array = []


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(result: Dictionary, p_events: Array) -> void:
	events = p_events
	cursor = 0
	emitted = 0
	time = 0.0
	actor = -1
	flash = {}
	arrivals = []
	_locs = {}
	_busy = {}
	_beat = {}
	_phases = []
	_out = []
	# Presentation stream: seeded from the fixture, never from MatchSim.
	_rng.seed = hash("%s|%s|%s|view" % [result.get("home", ""), result.get("away", ""),
			result.get("label", "")])
	_build_tokens(result.get("roster", []))
	ball = {"pos": Vector2.ZERO, "h": 0.0, "mode": "dead", "holder": -1,
			"from": Vector2.ZERO, "to": Vector2.ZERO, "h0": 0.0, "h1": 0.0,
			"apex": 0.0, "dur": 1.0, "t": 0.0, "vel": Vector2.ZERO, "kind": ""}
	for id in range(tokens.size()):
		var t: Dictionary = tokens[id]
		var p := _centre_spot(t, -1)
		t["pos"] = p
		MatchMotion.set_goal(t, p, 0.0, true)
	mode = "centre"
	_struct_ball = Vector2.ZERO


func _build_tokens(roster: Array) -> void:
	tokens = []
	_ids = [{}, {}]
	if roster.size() < 2:
		return
	for side in range(2):
		var groups := {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
		for p in (roster[side] as Array).slice(0, 18):
			var r := str(p.get("role", "MID"))
			groups[r if groups.has(r) else "MID"].append(p)
		var extra := 0
		for role in ["RUCK", "MID", "DEF", "FWD"]:
			var slots: Array = SLOTS[role]
			var list: Array = groups[role]
			for i in range(list.size()):
				var p: Dictionary = list[i]
				var slot := ""
				var base: Vector2
				if i < slots.size():
					slot = str(slots[i][0])
					base = slots[i][1]
				else:
					slot = "X%d" % extra
					base = EXTRA_SLOTS[extra % EXTRA_SLOTS.size()]
					extra += 1
				tokens.append(_make_token(p, side, role, slot, base))
	for id in range(tokens.size()):
		var t: Dictionary = tokens[id]
		t["id"] = id
		(_ids[int(t["side"])] as Dictionary)[int(t["num"])] = id
	# Direct opponents by paired slot.
	for t in tokens:
		t["match"] = -1
		var want := str(OPPOSITE.get(str(t["slot"]), ""))
		if want == "":
			continue
		for o in tokens:
			if int(o["side"]) != int(t["side"]) and str(o["slot"]) == want:
				t["match"] = int(o["id"])
				break


func _make_token(p: Dictionary, side: int, role: String, slot: String, base: Vector2) -> Dictionary:
	var carry := 50.0
	var pl = GameDB.player_by_id(str(p.get("id", "")))
	if pl != null and pl.has("attr"):
		carry = float((pl["attr"] as Dictionary).get("carry", 50.0))
	# Speed from the carry rating (run-and-carry players are the quick ones);
	# presentation only, it never feeds back into the match.
	var top := 11.6 + 2.6 * clampf((carry - 50.0) / 50.0, -1.0, 1.0) + _rng.randf_range(-0.4, 0.4)
	if role == "RUCK":
		top *= 0.88
	var t := MatchMotion.make_token(Vector2.ZERO, top, _rng.randf_range(0.10, 0.30))
	t["side"] = side
	t["num"] = int(p.get("num", 0))
	t["name"] = GameDB.player_display_name_by_id(str(p.get("id", "")), str(p.get("name", "Player")))
	t["role"] = role
	t["slot"] = slot
	t["base"] = base
	# A player's own habits: where he likes to stand relative to his slot, and
	# a slow wander so a held structure still breathes.
	t["jitter"] = Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, 4))
	t["phase"] = _rng.randf_range(0.0, TAU)
	return t


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------
## Advance presentation time by `dt` seconds (already scaled by playback
## speed). Returns the events released during the step, in log order.
func advance(dt: float) -> Array:
	_out = []
	dt *= TEMPO
	var n := maxi(1, ceili(dt / SUBSTEP))
	var h := dt / float(n)
	for i in range(n):
		_tick(h)
		# Stop at the final siren so the caller can close playback.
		if not _out.is_empty() and str((_out[-1] as Dictionary).get("kind", "")) == "final":
			break
	return _out


func idle() -> bool:
	return _beat.is_empty() and cursor >= events.size()


func _tick(h: float) -> void:
	time += h
	var guard := 0
	while guard < 64:
		guard += 1
		if _beat.is_empty():
			if cursor >= events.size():
				break
			_start_beat(cursor)
			cursor += 1
		if not _run_phases(h if guard == 1 else 0.0):
			break
	_struct_timer -= h
	if _struct_timer <= 0.0:
		_struct_timer = STRUCTURE_EVERY
		_refresh_structure()
	for t in tokens:
		MatchMotion.step(t, h)
	MatchMotion.separate(tokens)
	_update_ball(h)
	if not flash.is_empty():
		flash["left"] = float(flash["left"]) - h
		if float(flash["left"]) <= 0.0:
			flash = {}


## Run the current beat. Returns true when the beat finished (so the next one
## may start in the same tick), false while a phase is still running.
func _run_phases(h: float) -> bool:
	var guard := 0
	while _pi < _phases.size() and guard < 32:
		guard += 1
		var p: Dictionary = _phases[_pi]
		if not p.get("_entered", false):
			p["_entered"] = true
			_pt = 0.0
			_enter(p)
		else:
			_pt += h
			h = 0.0
		if not _done(p):
			return false
		_pi += 1
	_beat = {}
	return true


# ---------------------------------------------------------------------------
# Beats
# ---------------------------------------------------------------------------
func _start_beat(k: int) -> void:
	var ev: Dictionary = events[k]
	var kind := str(ev.get("kind", ""))
	_beat = {"k": k, "kind": kind}
	_phases = []
	_pi = 0
	_busy = {}
	var side := int(ev.get("side", -1))
	if side >= 0 and kind != "sub" and kind != "moment":
		_poss = side
	match kind:
		"sub", "final":
			_phases = [{"t": "emit"}]
		"moment":
			_phases = [{"t": "emit"}, {"t": "wait", "dur": 0.5, "ease": true}]
		"quarter":
			mode = "break"
			_phases = [{"t": "emit"}, {"t": "wait", "dur": 1.6, "ease": true}]
		"free":
			_phases = [{"t": "emit"}, {"t": "wait", "dur": 0.5, "ease": true}]
		"tackle":
			_phases = _tackle_phases(k)
		"inside50":
			_phases = _inside50_phases(k)
		"goal", "behind":
			_phases = _shot_phases(k)
		"rebound":
			_phases = _rebound_phases(k)
		"clanger":
			_phases = _clanger_phases(k)
		"ballup":
			_phases = _ballup_phases(k)
		_:
			if DISPOSALS.has(kind):
				_phases = _possession_phases(k)
			else:
				_phases = [{"t": "emit"}]
	_anticipate(k)
	_refresh_structure()
	# Who works around the ball is settled once a beat, so the role does not
	# flick between neighbours (and send them back and forth) mid-play.
	var bp := _struct_ball
	if _phases.size() > 0 and str((_phases[0] as Dictionary).get("t", "")) == "flight":
		bp = (_phases[0] as Dictionary)["to"]
	_ball_zone(bp)


static func _possession(kind: String) -> bool:
	return DISPOSALS.has(kind) or kind == "clanger"


func _prev_real(k: int) -> int:
	var i := k - 1
	while i >= 0 and META.has(str((events[i] as Dictionary).get("kind", ""))):
		i -= 1
	return i


func _next_real(k: int) -> int:
	var i := k + 1
	while i < events.size() and META.has(str((events[i] as Dictionary).get("kind", ""))):
		i += 1
	return i if i < events.size() else -1


## How a possession event starts: from open play, a centre bounce, a kick-in,
## a ball-up, a free kick or a loose ball. Read straight from the event before
## it: MatchSim logs every ball-up ("ballup") and every centre restart follows
## a goal, a behind or a quarter break.
func _restart(k: int) -> String:
	var ev: Dictionary = events[k]
	var pk := _prev_real(k)
	var pkind := "" if pk < 0 else str((events[pk] as Dictionary).get("kind", ""))
	match pkind:
		"", "goal", "quarter":
			return "centre"
		"behind":
			return "kickin"
		"ballup":
			return "ballup"
		"free":
			return "free"
		"clanger", "tackle":
			# No stoppage logged: the ball is won where it fell.
			return "loose"
	return "open"


func _possession_phases(k: int) -> Array:
	var ev: Dictionary = events[k]
	var a := _actor_id(ev)
	var kind := str(ev.get("kind", ""))
	var loc := _loc(k)
	var tail := _receive(k, a)
	match _restart(k):
		"centre":
			return _centre_phases(k, a, loc) + tail
		"kickin":
			return _kickin_phases(k, a, loc) + tail
		"ballup":
			# The ruck's tap to the player who wins it, out of the ball-up beat.
			return [{"t": "flight", "to": loc, "dur": 0.3, "apex": 0.8, "h0": 3.0, "recv": a}] + tail
		"free":
			return [{"t": "wait", "dur": 0.3, "ease": true},
					{"t": "flight", "to": loc, "dur": 0.4, "apex": 1.5, "recv": a}] + tail
		"loose":
			return tail
	var pk := _prev_real(k)
	var prev: Dictionary = events[pk] if pk >= 0 else {}
	var hb := str(prev.get("kind", "")) == "handball"
	var d := (ball["pos"] as Vector2).distance_to(loc)
	if hb and d > 18.0:
		hb = false
	var shape := _flight_shape("handball" if hb else "kick", d)
	var flight := {"t": "flight", "to": loc, "dur": shape.x, "apex": shape.y, "recv": a,
			"adapt": true, "h1": 2.4 if kind == "mark" else 1.0}
	if not prev.is_empty() and int(prev.get("side", -1)) != int(ev.get("side", -1)):
		# Possession changed hands without an event (the chain broke down):
		# show the ball won in a contest.
		flight["contest"] = true
	return [flight] + tail


## The receiver takes the ball at its logged spot. The event is released when
## he gets there, or once the ball has sat there a moment (a bobble he is still
## running onto), so a late arrival never holds up the log.
func _receive(k: int, a: int) -> Array:
	# About to be tackled: he runs onto it where it lies, and is caught there.
	var nk := _next_real(k)
	var roll := not (nk >= 0 and str((events[nk] as Dictionary).get("kind", "")) == "tackle")
	return [{"t": "collect", "who": a, "max": 0.25}, {"t": "emit", "log": true},
			{"t": "collect", "who": a, "roll": roll}, {"t": "possess", "who": a}, _hold(k, a)]


func _hold(k: int, who: int) -> Dictionary:
	var kind := str((events[k] as Dictionary).get("kind", ""))
	var dur := 0.07 + _rng.randf_range(0.0, 0.06)
	if kind == "mark":
		dur = 0.32
	elif kind == "kick":
		dur = 0.12 + _rng.randf_range(0.0, 0.08)
	var nk := _next_real(k)
	var carry := Vector2.INF
	if nk >= 0 and who >= 0:
		var nev: Dictionary = events[nk]
		var nkind := str(nev.get("kind", ""))
		if nkind == "tackle":
			return {"t": "hold", "who": who, "dur": 0.05}
		if (DISPOSALS.has(nkind) or nkind == "inside50" or nkind == "clanger") \
				and _restart(nk) == "open" and int(nev.get("side", -1)) == int((events[k] as Dictionary).get("side", -2)):
			# The carrier runs on toward the next contest before disposing,
			# which is where most metres come from in real ball movement.
			var here := _loc(k)
			var there := _loc(nk)
			carry = here + (there - here).limit_length(minf(10.0, here.distance_to(there) * 0.3))
	return {"t": "hold", "who": who, "dur": dur, "carry": carry}


func _centre_phases(k: int, a: int, loc: Vector2) -> Array:
	var pk := _prev_real(k)
	var after_goal := pk >= 0 and str((events[pk] as Dictionary).get("kind", "")) == "goal"
	var layout := {}
	for t in tokens:
		layout[int(t["id"])] = _centre_spot(t, a)
	return [
		{"t": "setup", "layout": layout, "ball_to": Vector2.ZERO, "mode": "centre",
			"min": 1.1 if after_goal else 0.8, "max": 2.6 if after_goal else 2.0},
		{"t": "wait", "dur": 0.3},
		{"t": "bounce", "at": Vector2.ZERO, "recv": a, "loc": loc},
		{"t": "flight", "to": loc, "dur": 0.3, "apex": 0.6, "h0": 3.5, "recv": a},
	]


func _kickin_phases(k: int, a: int, loc: Vector2) -> Array:
	var pk := _prev_real(k)
	var kside := 1 - int((events[pk] as Dictionary).get("side", 0))
	var dir := _dir(kside)
	var g := Vector2(-80.0 * dir, 0.0)
	var kicker := -1
	var best := INF
	for t in tokens:
		if int(t["side"]) == kside and str(t["role"]) == "DEF":
			var d := (t["pos"] as Vector2).distance_to(g)
			if d < best:
				best = d
				kicker = int(t["id"])
	var layout := {}
	var zone_side := 1 - kside
	var used := {"FWD": 0, "MID": 0, "DEF": 0}
	for t in tokens:
		var id := int(t["id"])
		if id == kicker:
			layout[id] = g + Vector2(dir * 1.5, 0)
		elif int(t["side"]) == zone_side:
			var grp := "MID" if str(t["role"]) == "RUCK" else str(t["role"])
			var pts: Array = ZONE.get(grp, ZONE["MID"])
			var i := int(used.get(grp, 0))
			used[grp] = i + 1
			var p: Vector2 = pts[i] if i < pts.size() else Vector2(12, -20 + 10 * (i - pts.size()))
			layout[id] = Vector2(p.x * _dir(zone_side), p.y) + (t["jitter"] as Vector2) * 0.4
		else:
			layout[id] = _structure_spot(t, g, kside)
	return [
		{"t": "setup", "layout": layout, "ball_to": g, "mode": "kickin", "min": 0.9, "max": 2.2},
		{"t": "collect", "who": kicker},
		{"t": "possess", "who": kicker, "quiet": true},
		{"t": "wait", "dur": 0.35},
		{"t": "flight", "to": loc, "dur": _flight_shape("kick", g.distance_to(loc)).x,
			"apex": 17.0, "recv": a, "adapt": true, "contest": true},
	]


## A logged ball-up: the ball gets to where play stopped (the kick or scramble
## that ended the chain), a pack forms, the umpire throws it up. The tap to
## whoever wins it opens the next beat.
func _ballup_phases(k: int) -> Array:
	var at := _loc(k)
	var out := []
	var d := (ball["pos"] as Vector2).distance_to(at)
	if d > 3.0:
		var shape := _flight_shape("kick", d)
		out.append({"t": "flight", "to": at, "dur": shape.x, "apex": shape.y, "recv": -1,
				"mode": "stoppage"})
	var nk := _next_real(k)
	var winner := _actor_id(events[nk]) if nk >= 0 else -1
	var members := _nearest(at, 0, 3, [winner]) + _nearest(at, 1, 3, [winner])
	for t in tokens:
		if str(t["role"]) == "RUCK" and not members.has(int(t["id"])):
			members.append(int(t["id"]))
	if winner >= 0 and not members.has(winner):
		members.append(winner)
	out += [{"t": "pack", "at": at, "members": members, "min": 0.35, "max": 0.9, "mode": "stoppage"},
			{"t": "throwup", "at": at},
			{"t": "emit", "log": true}]
	return out


func _tackle_phases(k: int) -> Array:
	var ev: Dictionary = events[k]
	var tk := _actor_id(ev)
	var victim := int(ball["holder"])
	if victim >= 0 and int(tokens[victim]["side"]) == int(ev.get("side", -1)):
		victim = -1
	if victim < 0:
		var pk := _prev_real(k)
		if pk >= 0:
			victim = _actor_id(events[pk])
	if tk < 0 or victim < 0:
		return [{"t": "emit", "log": true}]
	return [{"t": "chase", "who": tk, "victim": victim, "max": 1.6},
			{"t": "emit", "log": true},
			{"t": "down", "who": tk, "victim": victim, "dur": 0.55}]


func _inside50_phases(k: int) -> Array:
	var ev: Dictionary = events[k]
	var a := _actor_id(ev)
	var out := []
	if a >= 0 and int(ball["holder"]) != a:
		out += [{"t": "collect", "who": a}, {"t": "possess", "who": a, "quiet": true}]
	var loc := _loc(k)
	var nk := _next_real(k)
	var recv := _actor_id(events[nk]) if nk >= 0 else -1
	var src: Vector2 = ball["pos"]
	var d := src.distance_to(loc)
	var shape := _flight_shape("kick", d)
	out += [{"t": "emit"},
			{"t": "flight", "to": loc, "dur": shape.x, "apex": shape.y + 3.0, "recv": recv,
				"adapt": true, "contest": true, "log_k": k, "mode": "shot"},
			{"t": "wait", "dur": 0.1}]
	return out


func _shot_phases(k: int) -> Array:
	var ev: Dictionary = events[k]
	var s := _actor_id(ev)
	var side := int(ev.get("side", 0))
	var goal := str(ev.get("kind", "")) == "goal"
	var gy := _rng.randf_range(-2.4, 2.4) if goal \
			else signf(_rng.randf() - 0.5) * _rng.randf_range(4.0, 8.5)
	var target := Vector2(MatchMotion.GOAL_X * _dir(side), gy)
	var out := []
	if s >= 0:
		out += [{"t": "collect", "who": s}, {"t": "possess", "who": s, "quiet": true},
				{"t": "hold", "who": s, "dur": 0.45, "carry": Vector2.INF, "back": true}]
	var d := (ball["pos"] as Vector2).distance_to(target)
	out += [{"t": "flight", "to": target, "dur": 0.3 + d / 48.0, "apex": 3.0 + d * 0.14,
				"recv": -1, "mode": "shot"},
			{"t": "emit", "log": true, "flash": "goal" if goal else "behind"},
			{"t": "celebrate", "who": s, "dur": 1.2 if goal else 0.45}]
	return out


func _rebound_phases(k: int) -> Array:
	return _receive(k, _actor_id(events[k]))


func _clanger_phases(k: int) -> Array:
	var ev: Dictionary = events[k]
	var e := _actor_id(ev)
	var loc := _loc(k)
	var out := []
	match _restart(k):
		"centre":
			out = _centre_phases(k, e, loc)
		"kickin":
			out = _kickin_phases(k, e, loc)
	var d := (ball["pos"] as Vector2).distance_to(loc)
	if out.is_empty() and d > 1.0:
		var pk := _prev_real(k)
		var hb := pk >= 0 and str((events[pk] as Dictionary).get("kind", "")) == "handball"
		var shape := _flight_shape("handball" if hb and d < 18.0 else "kick", d)
		out.append({"t": "flight", "to": loc, "dur": shape.x, "apex": shape.y, "recv": e})
	out += [{"t": "collect", "who": e, "max": 0.3}, {"t": "emit", "log": true},
			{"t": "fumble", "dur": 0.35}]
	return out


## Flight time and apex for a disposal over `d` metres.
func _flight_shape(kind: String, d: float) -> Vector2:
	if kind == "handball":
		return Vector2(0.1 + d / 45.0, 0.6 + d * 0.04)
	return Vector2(0.2 + d / 64.0, clampf(2.0 + d * 0.2, 2.5, 16.0))


# ---------------------------------------------------------------------------
# Where the ball goes (presentation only: x is always the logged fp)
# ---------------------------------------------------------------------------
func _loc(k: int) -> Vector2:
	if _locs.has(k):
		return _locs[k]
	var ev: Dictionary = events[k]
	var kind := str(ev.get("kind", ""))
	var x := clampf(float(ev.get("fp", 0.0)), -MatchMotion.GOAL_X, MatchMotion.GOAL_X)
	var pk := _prev_real(k)
	var src: Vector2 = _locs[pk] if pk >= 0 and _locs.has(pk) else (ball["pos"] as Vector2)
	var a := _actor_id(ev)
	var ry: float = (tokens[a]["pos"] as Vector2).y if a >= 0 else src.y
	var p: Vector2
	if kind in ["goal", "behind", "rebound", "tackle", "free", "ballup"]:
		p = Vector2(x, src.y)
	elif _possession(kind) and _restart(k) == "centre":
		p = Vector2(0.0, signf(ry if ry != 0.0 else 1.0) * 3.5)
	elif _possession(kind) and _restart(k) == "kickin":
		p = Vector2(0.0, signf(ry if ry != 0.0 else 1.0) * _rng.randf_range(12.0, 26.0))
	elif _possession(kind) and _restart(k) in ["ballup", "free", "loose"]:
		p = Vector2(x, src.y + _rng.randf_range(-6.0, 6.0))
	else:
		var hb := pk >= 0 and str((events[pk] as Dictionary).get("kind", "")) == "handball"
		var dy_raw := ry - src.y
		var dy: float
		if hb:
			dy = clampf(dy_raw * 0.6, -9.0, 9.0) + _rng.randf_range(-2.0, 2.0)
		else:
			dy = clampf(dy_raw * 0.7, -32.0, 32.0) + _rng.randf_range(-5.0, 5.0)
			if absf(x - src.x) < 12.0 and absf(dy) < 10.0:
				dy = (signf(dy_raw) if dy_raw != 0.0 else 1.0) * _rng.randf_range(10.0, 18.0)
			if absf(src.y) > 22.0 and _rng.randf() < 0.1:
				dy = -src.y * 1.3 + _rng.randf_range(-5.0, 5.0)   # a switch of play
		var y := src.y + dy
		var side := int(ev.get("side", 0))
		if x * _dir(side) < -45.0:
			y *= 1.15   # clearing from defence: toward the boundary, away from the corridor
		p = Vector2(x, y)
		if hb and p.distance_to(src) < 3.0:
			p.y += 4.0 * (1.0 if _rng.randf() < 0.5 else -1.0)
	if absf(p.x) > 62.0:
		p.y = clampf(p.y, -26.0, 26.0)
	var ymax := (MatchMotion.HALF_WID - 4.0) * sqrt(maxf(0.0,
			1.0 - pow(p.x / (MatchMotion.HALF_LEN - 1.0), 2.0)))
	p.y = clampf(p.y, -ymax, ymax)
	_locs[k] = p
	return p


# ---------------------------------------------------------------------------
# Anticipation: players read the next one or two events
# ---------------------------------------------------------------------------
func _anticipate(k: int) -> void:
	var ev: Dictionary = events[k]
	var cur := _actor_id(ev)
	var j := k
	for step in range(3):
		j = _next_real(j)
		if j < 0:
			return
		var nev: Dictionary = events[j]
		var kind := str(nev.get("kind", ""))
		var a := _actor_id(nev)
		var w := [1.0, 0.8, 0.6][step] as float
		if a < 0 or _busy.has(a):
			continue
		if kind == "tackle" and step == 0 and cur >= 0:
			# The tackler is already closing from behind as the ball arrives.
			var at := _loc(k) if DISPOSALS.has(str(ev.get("kind", ""))) else (tokens[cur]["pos"] as Vector2)
			var from: Vector2 = tokens[a]["pos"]
			MatchMotion.set_goal(tokens[a], at + (from - at).limit_length(2.5), 1.0)
			_busy[a] = true
		elif (DISPOSALS.has(kind) or kind == "clanger") and _restart(j) == "open":
			var loc := _loc(j)
			var goal := loc if step < 2 else (tokens[a]["pos"] as Vector2).lerp(loc, 0.7)
			MatchMotion.set_goal(tokens[a], goal, w)
			_busy[a] = true
			if step == 0:
				_trail(a, goal, 0.85 * w)
		elif kind == "inside50" and step == 0:
			var nk := _next_real(j)
			if nk >= 0:
				_contest(_loc(j), _actor_id(events[nk]), 0.95)
	if str(ev.get("kind", "")) == "inside50":
		var nk2 := _next_real(k)
		if nk2 >= 0:
			_contest(_loc(k), _actor_id(events[nk2]), 1.0)


## The receiver's direct opponent follows him a step behind, goal-side.
func _trail(a: int, goal: Vector2, urgency: float) -> void:
	var o := int(tokens[a]["match"])
	if o < 0 or _busy.has(o):
		return
	var t: Dictionary = tokens[o]
	var own := Vector2(-MatchMotion.GOAL_X * _dir(int(t["side"])), 0.0)
	if (t["pos"] as Vector2).distance_to(goal) > 40.0:
		return
	MatchMotion.set_goal(t, goal + (own - goal).normalized() * 2.2, urgency)
	_busy[o] = true


## A marking contest where a long kick lands: the winner, his opponent and
## the nearest player from each side fly for it.
func _contest(at: Vector2, winner: int, urgency: float) -> void:
	var members := []
	if winner >= 0:
		members.append(winner)
		var o := int(tokens[winner]["match"])
		if o >= 0:
			members.append(o)
	members += _nearest(at, 0, 1, members) + _nearest(at, 1, 1, members)
	for i in range(members.size()):
		var id: int = members[i]
		if _busy.has(id) and id != winner:
			continue
		var ang := TAU * float(i) / float(maxi(1, members.size())) + 0.4
		var off := Vector2.ZERO if id == winner else Vector2(cos(ang), sin(ang)) * 2.0
		MatchMotion.set_goal(tokens[id], at + off, urgency)
		_busy[id] = true


# ---------------------------------------------------------------------------
# Phases
# ---------------------------------------------------------------------------
func _enter(p: Dictionary) -> void:
	match str(p["t"]):
		"setup":
			mode = str(p.get("mode", "centre"))
			var layout: Dictionary = p["layout"]
			for id in layout:
				MatchMotion.set_goal(tokens[id], layout[id], 0.45, true)
				_busy[id] = true
			_ball_carry(p["ball_to"])
			_struct_ball = p["ball_to"]
		"wait":
			if p.get("ease", false):
				for t in tokens:
					if not _busy.has(int(t["id"])):
						MatchMotion.set_goal(t, (t["pos"] as Vector2) + (t["vel"] as Vector2) * 0.25, 0.1)
						_busy[int(t["id"])] = true
		"bounce", "throwup":
			var at: Vector2 = p["at"]
			var up := 8.5 if p["t"] == "bounce" else 5.0
			_ball_flight(at, at, 0.4 if p["t"] == "bounce" else 1.8, 3.5, up,
					0.7 if p["t"] == "bounce" else 0.45)
			for t in tokens:
				if str(t["role"]) == "RUCK":
					var id := int(t["id"])
					MatchMotion.set_goal(t, at + Vector2(-0.8 * _dir(int(t["side"])), 0.0), 1.0, true)
					_busy[id] = true
			if p.has("recv") and int(p["recv"]) >= 0 and p.has("loc"):
				MatchMotion.set_goal(tokens[int(p["recv"])], p["loc"], 1.0, true)
		"flight":
			var to: Vector2 = p["to"]
			var from: Vector2 = ball["pos"]
			var dur := float(p.get("dur", 0.5))
			var recv := int(p.get("recv", -1))
			if recv >= 0:
				var r: Dictionary = tokens[recv]
				MatchMotion.set_goal(r, to, 1.0)
				_busy[recv] = true
				if p.get("adapt", false):
					# Hang the ball long enough for the receiver to get there,
					# within what a kick of that length can plausibly take.
					dur = clampf(MatchMotion.eta(r, to) * 0.9, dur, dur * 1.45)
				if p.get("contest", false):
					_contest(to, recv, 1.0)
			var h0 := float(p.get("h0", 1.0 if int(ball["holder"]) >= 0 else float(ball["h"])))
			_ball_flight(from, to, h0, float(p.get("h1", 1.0)), float(p.get("apex", 2.0)), dur)
			_struct_ball = to
			mode = str(p.get("mode", "open"))
			p["dur"] = dur
		"collect":
			var who := int(p.get("who", -1))
			if who >= 0:
				MatchMotion.set_goal(tokens[who], ball["pos"], 1.0, true)
				_busy[who] = true
		"possess":
			var who2 := int(p.get("who", -1))
			if who2 >= 0:
				ball["mode"] = "held"
				ball["holder"] = who2
				_busy[who2] = true
				_poss = int(tokens[who2]["side"])
				if not p.get("quiet", false):
					actor = who2
		"emit":
			_emit(p)
		"hold":
			var who3 := int(p.get("who", -1))
			if who3 >= 0:
				var t3: Dictionary = tokens[who3]
				var carry: Vector2 = p.get("carry", Vector2.INF)
				var goal: Vector2 = t3["pos"]
				if p.get("back", false):
					var att := Vector2(MatchMotion.GOAL_X * _dir(int(t3["side"])), 0.0)
					goal = goal + (goal - att).normalized() * 3.0
				elif carry.is_finite():
					goal = carry
				MatchMotion.set_goal(t3, goal, 0.8, true)
				_busy[who3] = true
		"chase":
			var vt: Dictionary = tokens[int(p["victim"])]
			MatchMotion.set_goal(vt, vt["pos"], 0.2, true)
			MatchMotion.set_goal(tokens[int(p["who"])], vt["pos"], 1.0, true)
			_busy[int(p["who"])] = true
			_busy[int(p["victim"])] = true
		"down":
			for id in [int(p["who"]), int(p["victim"])]:
				tokens[id]["down"] = float(p["dur"])
				tokens[id]["vel"] = (tokens[id]["vel"] as Vector2) * 0.3
			ball["mode"] = "dead"
			ball["holder"] = -1
			mode = "stoppage"
		"pack":
			mode = str(p.get("mode", "stoppage"))
			var at2: Vector2 = p["at"]
			var members: Array = p["members"]
			for i in range(members.size()):
				var ang := TAU * float(i) / float(maxi(1, members.size()))
				var r := 2.0 + 1.5 * float(i % 2)
				MatchMotion.set_goal(tokens[members[i]], at2 + Vector2(cos(ang), sin(ang)) * r, 0.95)
				_busy[int(members[i])] = true
			_struct_ball = at2
		"celebrate":
			var who4 := int(p.get("who", -1))
			mode = "shot"
			if who4 >= 0 and float(p["dur"]) > 1.0:
				var at3: Vector2 = tokens[who4]["pos"]
				for id in _nearest(at3, int(tokens[who4]["side"]), 3, [who4]):
					if (tokens[id]["pos"] as Vector2).distance_to(at3) < 30.0:
						MatchMotion.set_goal(tokens[id], at3, 0.7)
						_busy[id] = true
			for t in tokens:
				if not _busy.has(int(t["id"])):
					MatchMotion.set_goal(t, (t["pos"] as Vector2) + (t["vel"] as Vector2) * 0.3, 0.1)
					_busy[int(t["id"])] = true
		"fumble":
			ball["mode"] = "loose"
			ball["holder"] = -1
			var ang2 := _rng.randf_range(0.0, TAU)
			ball["vel"] = Vector2(cos(ang2), sin(ang2)) * _rng.randf_range(6.0, 10.0)


func _done(p: Dictionary) -> bool:
	match str(p["t"]):
		"setup":
			if _pt < float(p["min"]) or str(ball["mode"]) == "carry":
				return false
			if _pt >= float(p["max"]):
				return true
			var layout: Dictionary = p["layout"]
			for id in layout:
				if (tokens[id]["pos"] as Vector2).distance_to(layout[id]) > 3.0:
					return false
			return true
		"pack":
			if _pt < float(p["min"]):
				return false
			if _pt >= float(p["max"]):
				return true
			var n := 0
			for id in p["members"]:
				if (tokens[id]["pos"] as Vector2).distance_to(p["at"]) < 5.0:
					n += 1
			return n >= mini(4, (p["members"] as Array).size())
		"collect":
			var who := int(p.get("who", -1))
			if who < 0:
				return true
			var t: Dictionary = tokens[who]
			MatchMotion.set_goal(t, ball["pos"], 1.0, true)
			var d := (t["pos"] as Vector2).distance_to(ball["pos"])
			if d <= 1.4:
				return true
			if p.has("max") and _pt >= float(p["max"]):
				return true
			if p.get("roll", false) and _pt > 0.1 and str(ball["mode"]) != "flight":
				# Still short of it: the ball bobbles on toward him rather
				# than anyone jumping across the ground.
				ball["mode"] = "roll_to"
				ball["holder"] = who
			return false
		"chase":
			var tk: Dictionary = tokens[int(p["who"])]
			var v: Dictionary = tokens[int(p["victim"])]
			MatchMotion.set_goal(tk, v["pos"], 1.0, true)
			return (tk["pos"] as Vector2).distance_to(v["pos"]) <= 1.6 or _pt >= float(p["max"])
		"emit", "possess":
			return true
		"flight":
			return _pt >= float(p["dur"])
		"bounce":
			return _pt >= 0.7
		"throwup":
			return _pt >= 0.45
		_:
			return _pt >= float(p.get("dur", 0.0))


func _emit(p: Dictionary) -> void:
	var k := int(_beat["k"])
	var ev: Dictionary = events[k]
	var kind := str(ev.get("kind", ""))
	if kind == "sub":
		_sub(ev)
	var a := _actor_id(ev)
	if a >= 0 and kind != "sub":
		actor = a
	if p.get("log", false):
		_log_arrival(k)
	var fl := str(p.get("flash", ""))
	if fl != "":
		flash = {"pos": ball["pos"], "left": 0.9, "goal": fl == "goal"}
	# Anything drawn before this in the same beat was the lead-up.
	emitted = k + 1
	_out.append(ev)


func _log_arrival(k: int) -> void:
	var ev: Dictionary = events[k]
	var kind := str(ev.get("kind", ""))
	var want := float(ev.get("fp", 0.0))
	if kind == "goal" or kind == "behind":
		want = MatchMotion.GOAL_X * _dir(int(ev.get("side", 0)))
	if arrivals.size() >= 4000:
		arrivals.pop_front()
	arrivals.append({"idx": k, "kind": kind, "pos": ball["pos"], "want_x": want})


func _sub(ev: Dictionary) -> void:
	var side := int(ev.get("side", -1))
	if side < 0 or side > 1:
		return
	var ids: Dictionary = _ids[side]
	var off := int(ev.get("off_num", -1))
	if not ids.has(off):
		return
	var id: int = ids[off]
	ids.erase(off)
	var t: Dictionary = tokens[id]
	t["num"] = int(ev.get("num", t["num"]))
	t["name"] = str(ev.get("name", t["name"]))
	ids[int(t["num"])] = id


# ---------------------------------------------------------------------------
# Ball
# ---------------------------------------------------------------------------
func _ball_flight(from: Vector2, to: Vector2, h0: float, h1: float, apex: float, dur: float) -> void:
	ball["mode"] = "flight"
	ball["holder"] = -1
	ball["from"] = from
	ball["to"] = to
	ball["h0"] = h0
	ball["h1"] = h1
	ball["apex"] = apex
	ball["dur"] = maxf(0.05, dur)
	ball["t"] = 0.0


func _ball_carry(to: Vector2) -> void:
	if (ball["pos"] as Vector2).distance_to(to) < 0.5:
		ball["pos"] = to
		ball["mode"] = "dead"
		ball["holder"] = -1
		return
	ball["mode"] = "carry"
	ball["holder"] = -1
	ball["to"] = to


func _update_ball(h: float) -> void:
	match str(ball["mode"]):
		"held":
			var t: Dictionary = tokens[int(ball["holder"])]
			var v: Vector2 = t["vel"]
			var off := v.normalized() * 0.6 if v.length() > 0.5 else Vector2.ZERO
			ball["pos"] = (t["pos"] as Vector2) + off
			ball["h"] = 1.0
		"flight":
			ball["t"] = float(ball["t"]) + h
			var u := clampf(float(ball["t"]) / float(ball["dur"]), 0.0, 1.0)
			ball["pos"] = (ball["from"] as Vector2).lerp(ball["to"], u)
			ball["h"] = lerpf(float(ball["h0"]), float(ball["h1"]), u) \
					+ 4.0 * float(ball["apex"]) * u * (1.0 - u)
			if u >= 1.0:
				ball["mode"] = "dead"
		"carry":
			var to: Vector2 = ball["to"]
			var pos: Vector2 = ball["pos"]
			var step := 32.0 * h
			if pos.distance_to(to) <= step:
				ball["pos"] = to
				ball["mode"] = "dead"
			else:
				ball["pos"] = pos + (to - pos).normalized() * step
			ball["h"] = 1.2
		"roll_to":
			var who: Dictionary = tokens[int(ball["holder"])]
			var pos2: Vector2 = ball["pos"]
			var to2: Vector2 = who["pos"]
			var step2 := 22.0 * h
			ball["pos"] = to2 if pos2.distance_to(to2) <= step2 else pos2 + (to2 - pos2).normalized() * step2
			ball["h"] = maxf(0.0, float(ball["h"]) - 6.0 * h)
		"loose":
			ball["pos"] = MatchMotion.clamp_to_oval((ball["pos"] as Vector2) + (ball["vel"] as Vector2) * h, 1.0)
			ball["vel"] = (ball["vel"] as Vector2) * exp(-3.0 * h)
			ball["h"] = maxf(0.0, float(ball["h"]) - 6.0 * h)
		_:
			ball["h"] = maxf(0.0, float(ball["h"]) - 7.0 * h)


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------
func _refresh_structure() -> void:
	if tokens.is_empty():
		return
	var ball_p := _struct_ball
	# The side in possession first, so the other side can mark up on them.
	for side in [_poss, 1 - _poss]:
		for t in tokens:
			if int(t["side"]) != side or _busy.has(int(t["id"])):
				continue
			var g := _structure_spot(t, ball_p, _poss)
			var d := (t["pos"] as Vector2).distance_to(g)
			MatchMotion.set_goal(t, g, clampf(d / 45.0, 0.1, 0.6))


## Where a player stands when the ball is at `ball_p` and `poss` has it.
func _structure_spot(t: Dictionary, ball_p: Vector2, poss: int) -> Vector2:
	var side := int(t["side"])
	var dir := _dir(side)
	var bx := ball_p.x * dir
	var base: Vector2 = t["base"]
	var role := str(t["role"])
	var slot := str(t["slot"])
	var has := poss == side
	var x := base.x
	match role:
		"DEF":
			x += 0.5 * bx if bx > 0.0 else 0.22 * bx
		"FWD":
			x += 0.15 * bx if bx > 0.0 else 0.5 * bx
		_:
			x += (0.7 if slot.begins_with("W") else 0.78) * bx
	var width := 1.08 if has else 0.86
	var pull := 0.12 if slot.begins_with("W") else (0.3 if role == "MID" or role == "RUCK" else 0.2)
	var y := lerpf(base.y * width, ball_p.y, pull)
	if not has:
		x -= 3.0
	var drift := Vector2(sin(time * 0.31 + float(t["phase"])), cos(time * 0.23 + float(t["phase"]) * 1.7)) * 2.0
	var world := Vector2(x * dir, y) + (t["jitter"] as Vector2) + drift
	var own_goal := Vector2(-MatchMotion.GOAL_X * dir, 0.0)
	if not has:
		var o := int(t["match"])
		if _is_loose(t, ball_p):
			# The spare defender sits in the hole between the ball and goal.
			world = ball_p.lerp(own_goal, 0.5)
			world.y *= 0.6
		elif o >= 0:
			var og: Vector2 = tokens[o]["goal"]
			if og.distance_to(world) < 35.0:
				var mark := og + (own_goal - og).normalized() * 2.5
				var w := 0.65 if role == "DEF" else (0.45 if role == "MID" else 0.3)
				world = world.lerp(mark, w)
	return MatchMotion.clamp_to_oval(world, 3.0)


## One defender (the half-back whose forward is further from the ball) plays
## loose while his side defends.
func _is_loose(t: Dictionary, ball_p: Vector2) -> bool:
	var slot := str(t["slot"])
	if slot != "HBL" and slot != "HBR":
		return false
	var other := "HBR" if slot == "HBL" else "HBL"
	for o in tokens:
		if int(o["side"]) == int(t["side"]) and str(o["slot"]) == other:
			var mine := int(t["match"])
			var theirs := int(o["match"])
			if mine < 0 or theirs < 0:
				return false
			return (tokens[mine]["pos"] as Vector2).distance_to(ball_p) \
					> (tokens[theirs]["pos"] as Vector2).distance_to(ball_p)
	return false


## Around the ball: the nearest two defenders press (one on the ball, one
## goal-side), the nearest two attackers give options.
func _ball_zone(ball_p: Vector2) -> void:
	var def_side := 1 - _poss
	var own := Vector2(-MatchMotion.GOAL_X * _dir(def_side), 0.0)
	var to_goal := (own - ball_p).normalized()
	var press := _nearest(ball_p, def_side, 2, _busy.keys())
	for i in range(press.size()):
		var g := ball_p + to_goal * (3.0 if i == 0 else 9.0) \
				+ to_goal.orthogonal() * (1.0 if i == 0 else 6.0 * signf(ball_p.y + 0.1))
		MatchMotion.set_goal(tokens[press[i]], g, 0.8 if i == 0 else 0.6)
		_busy[press[i]] = true
	var dir := _dir(_poss)
	var sup := _nearest(ball_p, _poss, 2, _busy.keys())
	for i in range(sup.size()):
		var g2 := ball_p + (Vector2(dir * 9.0, -9.0) if i == 0 else Vector2(-dir * 5.0, 10.0))
		MatchMotion.set_goal(tokens[sup[i]], g2, 0.6)
		_busy[sup[i]] = true


## Centre-bounce position for a token; `carrier` is moved into the square.
func _centre_spot(t: Dictionary, carrier: int) -> Vector2:
	var side := int(t["side"])
	var slot := str(t["slot"])
	var spot: Vector2 = CENTRE.get(slot, Vector2(-25, 15 if int(t["id"]) % 2 == 0 else -15))
	if carrier >= 0 and int(tokens[carrier]["side"]) == side:
		var cslot := str(tokens[carrier]["slot"])
		var swap := "C" if not SQUARE.has(cslot) else ""
		if int(t["id"]) == carrier:
			spot = Vector2(-3, 5 if spot.y >= 0.0 else -5) if SQUARE.has(cslot) else Vector2(-3, -5)
		elif swap != "" and slot == swap:
			spot = CENTRE.get(cslot, spot)
	return Vector2(spot.x * _dir(side), spot.y)


# ---------------------------------------------------------------------------
# Skip and helpers
# ---------------------------------------------------------------------------
## Release every event not yet released, without animating, and leave the
## view in a settled end state. Returns the released events in order.
func flush() -> Array:
	var out := events.slice(emitted)
	for ev in out:
		if str((ev as Dictionary).get("kind", "")) == "sub":
			_sub(ev)
	emitted = events.size()
	cursor = events.size()
	_beat = {}
	_phases = []
	_busy = {}
	var last := Vector2.ZERO
	for i in range(events.size() - 1, -1, -1):
		var ev2: Dictionary = events[i]
		if not ["quarter", "final", "sub", "moment"].has(str(ev2.get("kind", ""))):
			last = Vector2(clampf(float(ev2.get("fp", 0.0)), -MatchMotion.GOAL_X, MatchMotion.GOAL_X), 0.0)
			break
	ball["mode"] = "dead"
	ball["holder"] = -1
	ball["pos"] = last
	ball["h"] = 0.0
	_struct_ball = last
	for t in tokens:
		var g := _structure_spot(t, last, _poss)
		t["pos"] = g
		t["vel"] = Vector2.ZERO
		t["down"] = 0.0
		MatchMotion.set_goal(t, g, 0.0, true)
	flash = {}
	mode = "break"
	return out


func _actor_id(ev: Dictionary) -> int:
	var side := int(ev.get("side", -1))
	if side < 0 or side > 1:
		return -1
	return int((_ids[side] as Dictionary).get(int(ev.get("num", -1)), -1))


func _nearest(at: Vector2, side: int, n: int, exclude: Array) -> Array:
	var cands := []
	for t in tokens:
		var id := int(t["id"])
		if int(t["side"]) == side and not exclude.has(id):
			cands.append([(t["pos"] as Vector2).distance_squared_to(at), id])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in range(mini(n, cands.size())):
		out.append(cands[i][1])
	return out


static func _dir(side: int) -> float:
	return 1.0 if side == 0 else -1.0


## Focus point and zoom hint for the camera.
func focus() -> Vector2:
	var p: Vector2 = ball["pos"]
	if str(ball["mode"]) == "flight":
		p = p.lerp(ball["to"], 0.45)
	return p


func zoom_hint() -> float:
	match mode:
		"centre":
			return 1.5
		"stoppage":
			return 1.5
		"shot":
			return 1.35
		"kickin":
			return 1.2
		"break":
			return 1.0
	return 1.3


## Positions for tools and tests.
func snapshot() -> Dictionary:
	var ps := []
	for t in tokens:
		ps.append({"side": t["side"], "num": t["num"], "pos": t["pos"], "down": t["down"]})
	return {"tokens": ps, "ball": ball["pos"], "h": ball["h"], "mode": mode}
