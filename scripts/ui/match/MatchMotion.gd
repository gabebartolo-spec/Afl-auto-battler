class_name MatchMotion
extends RefCounted
## Player and ball movement for the live match view. Presentation only: nothing
## here reads or writes MatchSim state.
##
## Units are metres and presentation seconds. Presentation time runs a little
## faster than real time (see MatchDirector.TEMPO), so speeds are a real
## player's scaled by that: a 30 km/h sprint (~8.5 m/s) is about 13 m/s here.
##
## Players are steered, not lerped: velocity changes are capped by acceleration
## and braking limits, so starts, stops and turns take time and paths curve.
## A token only reads a new goal after its own reaction delay, which keeps a
## team from moving as one rigid block.

## Oval half-axes. The goal line is at +-85 m, a little inside the boundary.
const HALF_LEN := 86.3
const HALF_WID := 67.4
const GOAL_X := 85.0

const JOG_SHARE := 0.52      # structural running is a jog, not a sprint
const ACCEL := 14.0          # m/s^2 speeding up
const BRAKE := 20.0          # m/s^2 slowing down or turning hard
const ARRIVE_STOP := 0.35    # inside this, a token settles
const MIN_SEP := 1.5         # bodies do not overlap more than this


## A new token at `pos`. `top` is its sprint speed; `reaction` its read delay.
static func make_token(pos: Vector2, top: float, reaction: float) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "goal": pos, "pending": pos,
		"react_left": 0.0, "reaction": reaction, "top": top,
		"urgency": 0.0, "pending_urgency": 0.0, "down": 0.0, "air": 0.0,
	}


## Ask a token to head for `goal`. The token keeps its current goal until its
## reaction delay has passed; `immediate` skips the delay (a set play the
## player already knows, such as walking back for a centre bounce).
static func set_goal(t: Dictionary, goal: Vector2, urgency: float, immediate := false) -> void:
	goal = clamp_to_oval(goal, 2.0)
	if immediate:
		t["goal"] = goal
		t["pending"] = goal
		t["urgency"] = urgency
		t["pending_urgency"] = urgency
		t["react_left"] = 0.0
		return
	t["pending"] = goal
	t["pending_urgency"] = urgency
	if float(t["react_left"]) > 0.0:
		return  # still reading the play; the latest goal applies when it ends
	if (t["goal"] as Vector2).distance_to(goal) > 1.5:
		# A real change of plan waits for the read; small corrections (tracking
		# a moving player) apply at once.
		t["react_left"] = float(t["reaction"])
	else:
		t["goal"] = goal
		t["urgency"] = urgency


## One integration step of `dt` seconds.
static func step(t: Dictionary, dt: float) -> void:
	if float(t["react_left"]) > 0.0:
		t["react_left"] = float(t["react_left"]) - dt
		if float(t["react_left"]) <= 0.0:
			t["goal"] = t["pending"]
			t["urgency"] = t["pending_urgency"]
	if float(t["air"]) > 0.0:
		t["air"] = maxf(0.0, float(t["air"]) - dt)
	var pos: Vector2 = t["pos"]
	var vel: Vector2 = t["vel"]
	var desired := Vector2.ZERO
	if float(t["down"]) > 0.0:
		t["down"] = maxf(0.0, float(t["down"]) - dt)
	else:
		var to: Vector2 = (t["goal"] as Vector2) - pos
		var d := to.length()
		var top: float = float(t["top"]) * lerpf(JOG_SHARE, 1.0, clampf(float(t["urgency"]), 0.0, 1.0))
		if d > ARRIVE_STOP:
			# Arrive: the fastest speed from which the token can still stop
			# at the goal, so it eases in instead of overshooting.
			var speed := minf(top, sqrt(2.0 * BRAKE * 0.55 * maxf(0.0, d - ARRIVE_STOP * 0.5)))
			desired = to / d * speed
	var dv := desired - vel
	var limit := (ACCEL if desired.length_squared() > vel.length_squared()
			and dv.dot(vel) >= 0.0 else BRAKE) * dt
	vel += dv.limit_length(limit)
	pos += vel * dt
	var clamped := clamp_to_oval(pos, 1.0)
	if clamped != pos:
		vel *= 0.5
		pos = clamped
	t["pos"] = pos
	t["vel"] = vel


## Push overlapping bodies apart (positions only, half each way).
static func separate(tokens: Array) -> void:
	var n := tokens.size()
	for i in range(n):
		var a: Dictionary = tokens[i]
		for j in range(i + 1, n):
			var b: Dictionary = tokens[j]
			var d: Vector2 = (b["pos"] as Vector2) - (a["pos"] as Vector2)
			var l := d.length()
			if l >= MIN_SEP:
				continue
			var push := (d / l if l > 0.001 else Vector2(1, 0)) * (MIN_SEP - l) * 0.5
			a["pos"] = (a["pos"] as Vector2) - push
			b["pos"] = (b["pos"] as Vector2) + push


## Seconds a token needs to reach `p` from rest-ish, for flight timing.
static func eta(t: Dictionary, p: Vector2) -> float:
	var d := maxf(0.0, (t["pos"] as Vector2).distance_to(p) - 1.0)
	var top := float(t["top"])
	# Time lost getting up to speed from the current velocity.
	var ramp := maxf(0.0, top - (t["vel"] as Vector2).length()) / ACCEL * 0.5
	return float(t["react_left"]) + ramp + d / top


static func inside_oval(p: Vector2, margin := 0.0) -> bool:
	var ax := HALF_LEN - margin
	var ay := HALF_WID - margin
	return (p.x * p.x) / (ax * ax) + (p.y * p.y) / (ay * ay) <= 1.0


## Pull `p` back inside the oval shrunk by `margin` metres.
static func clamp_to_oval(p: Vector2, margin := 0.0) -> Vector2:
	var ax := HALF_LEN - margin
	var ay := HALF_WID - margin
	var k := (p.x * p.x) / (ax * ax) + (p.y * p.y) / (ay * ay)
	if k <= 1.0:
		return p
	return p / sqrt(k)
