class_name PitchView
extends Control
## Top-down animated AFL oval.
##
## MatchSim produces a deterministic event log up front; this view replays it.
## Tokens are the real 18 on-ground players from each side, shifting up and
## down the ground with the ball in role-based shape, and the ball travels to
## the field position recorded on each event.

signal event_played(ev: Dictionary)
signal finished

const GOAL_LINE_M := 85.0
const ASPECT := 1.28            # oval length : width, close to a real AFL ground

## Base shape for a side attacking toward +x. Mirrored for the other end.
const RUCK_SLOTS := [Vector2(0.0, 0.0)]
const MID_SLOTS := [
	Vector2(0.12, -0.46), Vector2(0.12, 0.46), Vector2(-0.04, -0.20),
	Vector2(-0.04, 0.20), Vector2(0.24, 0.02), Vector2(-0.20, -0.58),
	Vector2(-0.20, 0.58),
]
const DEF_SLOTS := [
	Vector2(-0.50, -0.52), Vector2(-0.50, 0.52), Vector2(-0.63, -0.22),
	Vector2(-0.63, 0.22), Vector2(-0.76, 0.0),
]
const FWD_SLOTS := [
	Vector2(0.54, -0.42), Vector2(0.54, 0.42), Vector2(0.67, -0.16),
	Vector2(0.67, 0.16), Vector2(0.80, 0.0),
]

var result := {}
var home_code := ""
var away_code := ""
var events: Array = []

var playing := false
## Matches log ~1,100 events, so the default is 4x; the scene offers 1x-8x.
var speed := 4.0

var _idx := 0
var _acc := 0.0
var _last_kind := "info"
var _home: Array = []
var _away: Array = []
var _ball := Vector2.ZERO
var _ball_target := Vector2.ZERO
var _actor := -1
var _actor_side := 0
var _flash := 0.0
var _flash_color := Color.WHITE
var _flash_pos := Vector2.ZERO
var _last_nx := 0.0
var _last_ny := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(p_result: Dictionary) -> void:
	result = p_result
	events = p_result.get("events", [])
	home_code = str(p_result.get("home", ""))
	away_code = str(p_result.get("away", ""))
	_idx = 0
	_acc = 0.0
	_last_kind = "info"
	_actor = -1
	_flash = 0.0
	_last_nx = 0.0
	_last_ny = 0.0
	playing = false
	_build_tokens()
	_ball = _px(0.0, 0.0)
	_ball_target = _ball
	queue_redraw()


func append_events(new_events: Array) -> void:
	events.append_array(new_events)
	queue_redraw()


func _build_tokens() -> void:
	_home = []
	_away = []
	var roster: Array = result.get("roster", [])
	if roster.size() < 2:
		return
	for side in range(2):
		var dir := 1.0 if side == 0 else -1.0
		var groups := {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
		for p in roster[side]:
			var r := str(p["role"])
			if not groups.has(r):
				r = "MID"
			groups[r].append(p)
		var out: Array = []
		out.append_array(_make_tokens(groups["RUCK"], RUCK_SLOTS, dir, side))
		out.append_array(_make_tokens(groups["MID"], MID_SLOTS, dir, side))
		out.append_array(_make_tokens(groups["DEF"], DEF_SLOTS, dir, side))
		out.append_array(_make_tokens(groups["FWD"], FWD_SLOTS, dir, side))
		if side == 0:
			_home = out
		else:
			_away = out


func _make_tokens(players: Array, slots: Array, dir: float, side: int) -> Array:
	var out := []
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var base: Vector2 = slots[i] if i < slots.size() else _spare_slot(i)
		base = Vector2(base.x * dir, base.y)
		out.append({
			"base": base, "pos": base, "target": base,
			"num": int(p["num"]), "name": str(p["name"]),
			"role": str(p["role"]), "side": side,
		})
	return out


## Backfill for lists short in a role: park them in the middle third. Returns
## the +x-attacking position; _make_tokens() mirrors it for the other end.
func _spare_slot(i: int) -> Vector2:
	var y := fmod(float(i) * 0.31, 1.2) - 0.6
	return Vector2(fmod(float(i) * 0.17, 0.5) - 0.25, y)


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------
func pitch_rect() -> Rect2:
	var margin := 10.0
	var avail := size - Vector2(margin, margin) * 2.0
	if avail.x <= 0.0 or avail.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var w := avail.x
	var h := w / ASPECT
	if h > avail.y:
		h = avail.y
		w = h * ASPECT
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))


## Normalised field coords (-1..1 each axis) to pixels.
func _px(nx: float, ny: float) -> Vector2:
	var r := pitch_rect()
	return Vector2(r.position.x + (nx * 0.5 + 0.5) * r.size.x,
			r.position.y + (ny * 0.5 + 0.5) * r.size.y)


func _ellipse_points(c: Vector2, a: float, b: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var t := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(t) * a, sin(t) * b))
	return pts


## A mown stripe clipped exactly to the oval: sample the ellipse's half-height
## across the stripe's x-range and build the polygon from that.
func _stripe(c: Vector2, a: float, b: float, x0: float, x1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 10
	for i in range(steps + 1):
		var x := lerpf(x0, x1, float(i) / float(steps))
		var t := clampf((x - c.x) / a, -1.0, 1.0)
		var yh := b * sqrt(1.0 - t * t)
		pts.append(Vector2(x, c.y - yh))
	for i in range(steps + 1):
		var x2 := lerpf(x1, x0, float(i) / float(steps))
		var t2 := clampf((x2 - c.x) / a, -1.0, 1.0)
		var yh2 := b * sqrt(1.0 - t2 * t2)
		pts.append(Vector2(x2, c.y + yh2))
	return pts


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	var r := pitch_rect()
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var c := r.get_center()
	var a := r.size.x * 0.5
	var b := r.size.y * 0.5

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.09, 0.047), true)

	# Turf + mown stripes
	draw_colored_polygon(_ellipse_points(c, a, b, 96), Color(0.118, 0.333, 0.133))
	var stripes := 9
	for i in range(stripes):
		if i % 2 == 1:
			continue
		var x0 := c.x - a + (2.0 * a) * float(i) / float(stripes)
		var x1 := c.x - a + (2.0 * a) * float(i + 1) / float(stripes)
		draw_colored_polygon(_stripe(c, a, b, x0, x1), Color(0.133, 0.365, 0.149))

	# Boundary
	draw_polyline(_ellipse_points(c, a, b, 96), Color(1, 1, 1, 0.85), 2.5)

	var line_col := Color(1, 1, 1, 0.55)
	var lw := 1.6

	# Centre square (45m) and centre circle
	var sq := (22.5 / GOAL_LINE_M) * a
	draw_rect(Rect2(c - Vector2(sq, sq), Vector2(sq, sq) * 2.0), line_col, false, lw)
	draw_arc(c, (3.0 / GOAL_LINE_M) * a, 0, TAU, 24, line_col, lw)

	# 50m arcs and goal squares at each end
	for sgn in [-1.0, 1.0]:
		var goal := Vector2(c.x + sgn * a * 0.985, c.y)
		var rad := (50.0 / GOAL_LINE_M) * a
		var span := _arc_span(c, a, b, goal, rad)
		draw_arc(goal, rad, span.x, span.y, 48, line_col, lw)
		# Goal square: 9m deep, 6.44m wide across the goal line.
		var depth := (9.0 / GOAL_LINE_M) * a
		var width := (6.44 / GOAL_LINE_M) * a
		var gx := goal.x - depth if sgn > 0.0 else goal.x
		draw_rect(Rect2(Vector2(gx, c.y - width * 0.5), Vector2(depth, width)),
				line_col, false, lw)
		# Goal posts, 6.44m apart
		for py in [-1.0, 1.0]:
			draw_circle(Vector2(goal.x, c.y + py * (3.22 / GOAL_LINE_M) * a),
					maxf(2.0, b * 0.012), Color(1, 1, 1, 0.9))

	# Tokens
	var tr := maxf(4.0, minf(a, b) * 0.030)
	_draw_tokens(_home, GameDB.club_colours(home_code), tr)
	_draw_tokens(_away, GameDB.club_colours(away_code), tr)

	# Actor highlight
	if _actor >= 0:
		var tk = _token(_actor_side, _actor)
		if not tk.is_empty():
			var p := _px(tk["pos"].x, tk["pos"].y)
			draw_arc(p, tr * 1.9, 0, TAU, 28, Color(1, 1, 0.55, 0.95), 2.0)

	# Ball
	draw_colored_polygon(_ellipse_points(_ball, tr * 0.42, tr * 0.30, 12),
			Color(0.98, 0.93, 0.75))
	draw_polyline(_ellipse_points(_ball, tr * 0.42, tr * 0.30, 12),
			Color(0.25, 0.12, 0.08), 1.0)

	# Goal / behind flash
	if _flash > 0.0:
		var t := 1.0 - clampf(_flash / 0.7, 0.0, 1.0)
		var rad := lerpf(tr, minf(a, b) * 0.42, t)
		var col := _flash_color
		col.a = (1.0 - t) * 0.85
		draw_arc(_flash_pos, rad, 0, TAU, 48, col, 4.0)


func _draw_tokens(tokens: Array, colours: Array, tr: float) -> void:
	var primary: Color = colours[0]
	var secondary: Color = colours[1]
	var font := ThemeDB.fallback_font
	var fs := int(clampf(tr * 1.15, 6.0, 14.0))
	for t in tokens:
		var p := _px(t["pos"].x, t["pos"].y)
		# Drop shadow keeps tokens readable on the stripes.
		draw_circle(p + Vector2(0, tr * 0.22), tr, Color(0, 0, 0, 0.28))
		draw_circle(p, tr, primary)
		# A chevron in the secondary colour so the two ends read apart at a glance.
		draw_circle(p, tr * 0.62, secondary)
		draw_circle(p, tr, Color(0, 0, 0, 0.35), false, 1.2)
		var label := str(t["num"])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var text_col := _readable_on(primary)
		draw_string(font, p + Vector2(-w * 0.5, fs * 0.36), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)


func _readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


## The real 50m arc dies where it meets the boundary, so walk in from each end
## of the inward-facing half circle and keep only the span inside the oval.
func _arc_span(c: Vector2, a: float, b: float, goal: Vector2, r: float) -> Vector2:
	var base := atan2(c.y - goal.y, c.x - goal.x)
	var lo := base - PI * 0.5
	var hi := base + PI * 0.5
	var a0 := lo
	var a1 := hi
	var steps := 64
	for i in range(steps + 1):
		var ang := lerpf(lo, hi, float(i) / float(steps))
		if _inside_oval(c, a, b, goal + Vector2(cos(ang), sin(ang)) * r):
			a0 = ang
			break
	for i in range(steps + 1):
		var ang := lerpf(hi, lo, float(i) / float(steps))
		if _inside_oval(c, a, b, goal + Vector2(cos(ang), sin(ang)) * r):
			a1 = ang
			break
	return Vector2(a0, a1)


func _inside_oval(c: Vector2, a: float, b: float, p: Vector2) -> bool:
	var dx := (p.x - c.x) / a
	var dy := (p.y - c.y) / b
	return dx * dx + dy * dy <= 1.0


func _token(side: int, index: int) -> Dictionary:
	var arr: Array = _home if side == 0 else _away
	if index < 0 or index >= arr.size():
		return {}
	return arr[index]


# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------
func play() -> void:
	if _idx >= events.size():
		return
	playing = true
	set_process(true)


func pause() -> void:
	playing = false


func toggle() -> void:
	if playing:
		pause()
	else:
		play()


func restart() -> void:
	setup(result)
	play()


func set_speed(s: float) -> void:
	speed = clampf(s, 0.25, 8.0)


func skip_to_end() -> void:
	playing = false
	while _idx < events.size():
		_apply(events[_idx])
		_idx += 1
	_snap()
	finished.emit()


func current_index() -> int:
	return _idx


func progress() -> float:
	return float(_idx) / float(maxi(1, events.size()))


## A full match logs roughly 1,100 events (every real disposal, mark, tackle and
## shot is one), so these are tuned to keep a game watchable: routine handballs
## tick by, scores and quarter breaks get room to land. At the default 4x a
## match plays out in about ninety seconds.
func _event_delay(kind: String) -> float:
	match kind:
		"goal":
			return 1.00
		"behind":
			return 0.60
		"quarter":
			return 1.10
		"final":
			return 1.10
		"inside50":
			return 0.42
		"tackle":
			return 0.34
		"mark":
			return 0.30
		"rebound":
			return 0.36
		"free", "clanger":
			return 0.38
		"kick", "handball":
			return 0.13
		_:
			return 0.18


func _process(delta: float) -> void:
	var k := clampf(delta * 5.5 * speed, 0.0, 1.0)
	var dirty := false

	if _ball.distance_to(_ball_target) > 0.4:
		_ball = _ball.lerp(_ball_target, k)
		dirty = true
	for t in _home:
		if _nudge(t, k):
			dirty = true
	for t in _away:
		if _nudge(t, k):
			dirty = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		dirty = true

	if playing:
		_acc += delta * speed
		if _acc >= _event_delay(_last_kind):
			_acc = 0.0
			_step()
			dirty = true

	if dirty:
		queue_redraw()
	elif not playing and _idx >= events.size():
		set_process(false)


func _nudge(t: Dictionary, k: float) -> bool:
	var pos: Vector2 = t["pos"]
	var target: Vector2 = t["target"]
	if pos.distance_to(target) < 0.002:
		return false
	t["pos"] = pos.lerp(target, k)
	return true


func _step() -> void:
	if _idx >= events.size():
		playing = false
		finished.emit()
		return
	var ev: Dictionary = events[_idx]
	_idx += 1
	_last_kind = str(ev.get("kind", "info"))
	_apply(ev)
	event_played.emit(ev)
	if _last_kind == "final":
		playing = false
		finished.emit()


func _apply(ev: Dictionary) -> void:
	var fp := float(ev.get("fp", 0.0))
	_last_nx = clampf(fp / GOAL_LINE_M, -1.0, 1.0)
	# Slight lateral drift so the ball does not ride the centre line all game.
	_last_ny = clampf(sin(float(_idx) * 1.7) * 0.22, -0.6, 0.6)
	_ball_target = _px(_last_nx, _last_ny)

	_shift(_home)
	_shift(_away)

	_actor = -1
	var side := int(ev.get("side", -1))
	var num := int(ev.get("num", -1))
	if side >= 0 and num >= 0:
		var arr: Array = _home if side == 0 else _away
		for i in range(arr.size()):
			if int(arr[i]["num"]) == num:
				_actor = i
				_actor_side = side
				# The carrier steps onto the ball.
				arr[i]["target"] = Vector2(_last_nx, _last_ny)
				break

	var kind := str(ev.get("kind", ""))
	if kind == "goal" or kind == "behind":
		_flash = 0.7
		_flash_pos = _ball_target
		_flash_color = Color(1.0, 0.92, 0.35) if kind == "goal" \
				else Color(0.85, 0.9, 1.0)


## The whole side moves with the ball, holding its role-based shape. Defenders
## lead out from goal and forwards push up, so a chain that travels 40m visibly
## drags both structures with it.
func _shift(tokens: Array) -> void:
	for t in tokens:
		t["target"] = _shift_target(t["base"])


func _shift_target(base: Vector2) -> Vector2:
	var tx := clampf(base.x + 0.45 * _last_nx, -0.94, 0.94)
	var ty := clampf(base.y * (0.88 + 0.10 * absf(_last_nx)), -0.90, 0.90)
	return Vector2(tx, ty)


func _snap() -> void:
	_ball = _ball_target
	for t in _home:
		t["pos"] = t["target"]
	for t in _away:
		t["pos"] = t["target"]
	queue_redraw()


## Pixel positions depend on the control's size, so a phone rotation means
## re-deriving every target from the last field position we saw.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_ball_target = _px(_last_nx, _last_ny)
		if not playing:
			_ball = _ball_target
		for tokens in [_home, _away]:
			for t in tokens:
				t["target"] = _shift_target(t["base"])
				if not playing:
					t["pos"] = t["target"]
		queue_redraw()
