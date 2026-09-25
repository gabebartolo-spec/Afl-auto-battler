class_name PitchView
extends Control
## Top-down animated AFL oval.
##
## MatchSim produces a deterministic event log up front; this view replays it.
## It only draws: MatchDirector turns the log into movement (who leads, who
## chases, how the ball travels, how stoppages set up) and MatchMotion moves
## the players. The log stays the truth - the view decides how an event looks,
## never whether it happens - and each event is released through
## event_played at the moment it visibly happens.

signal event_played(ev: Dictionary)
signal finished

const GOAL_LINE_M := 85.0
const ASPECT := 1.28            # oval length : width, close to a real AFL ground

var result := {}
var home_code := ""
var away_code := ""
var events: Array = []

var playing := false
## A full match is ~1,200 events; 4x plays it in a few minutes. 1x-8x offered.
var speed := 4.0
## A broadcast-style camera that follows play. Off, the whole oval shows.
var camera_enabled := true

var director := MatchDirector.new()
var _cam := Vector2.ZERO
var _zoom := 1.0
var _drawn_cam := Vector2.INF
var _drawn_zoom := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(p_result: Dictionary) -> void:
	result = p_result
	# Our own list, so appended segments never touch the caller's result.
	events = (p_result.get("events", []) as Array).duplicate()
	home_code = str(p_result.get("home", ""))
	away_code = str(p_result.get("away", ""))
	playing = false
	director = MatchDirector.new()
	director.setup(p_result, events)
	_cam = Vector2.ZERO
	_zoom = _target_zoom()
	set_process(true)
	queue_redraw()


func append_events(new_events: Array) -> void:
	events.append_array(new_events)
	queue_redraw()


# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------
func play() -> void:
	if director.idle():
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


## Jump to the end of what has been logged: the rest of the events are applied
## without animation (the scene reads the final result itself) and the view
## settles.
func skip_to_end() -> void:
	playing = false
	director.flush()
	queue_redraw()
	finished.emit()


## Events released to the match screen so far.
func current_index() -> int:
	return director.emitted


func progress() -> float:
	return float(director.emitted) / float(maxi(1, events.size()))


func _process(delta: float) -> void:
	if playing:
		var out := director.advance(delta * speed)
		for ev in out:
			event_played.emit(ev)
			if str((ev as Dictionary).get("kind", "")) == "final":
				playing = false
				finished.emit()
				break
		if playing and director.idle():
			playing = false
			finished.emit()
	_update_camera(delta)
	if playing or _cam.distance_to(_drawn_cam) > 0.05 or absf(_zoom - _drawn_zoom) > 0.002 \
			or not director.flash.is_empty():
		queue_redraw()


func _target_zoom() -> float:
	if not camera_enabled or director.tokens.is_empty() or events.is_empty():
		return 1.0
	return director.zoom_hint()


func _update_camera(delta: float) -> void:
	var tz := _target_zoom()
	var target := director.focus() if tz > 1.0 else Vector2.ZERO
	# Smooth follow in real time, a little quicker at high speed so the
	# camera keeps up with the play.
	var k := 1.0 - exp(-delta * 2.0 * clampf(sqrt(speed), 1.0, 2.5))
	_zoom = lerpf(_zoom, tz, 1.0 - exp(-delta * 1.4))
	_cam = _cam.lerp(target, k)
	_cam = _clamp_cam(_cam)


func _clamp_cam(c: Vector2) -> Vector2:
	var s := _scale()
	if s <= 0.0:
		return Vector2.ZERO
	var half := size * 0.5 / s
	var lx := maxf(0.0, MatchMotion.HALF_LEN + 4.0 - half.x)
	var ly := maxf(0.0, MatchMotion.HALF_WID + 4.0 - half.y)
	return Vector2(clampf(c.x, -lx, lx), clampf(c.y, -ly, ly))


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------
## The rect the whole oval fills at zoom 1.
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


## Pixels per metre at the current zoom.
func _scale() -> float:
	return pitch_rect().size.x / (2.0 * MatchMotion.HALF_LEN) * _zoom


## Ground metres to pixels.
func _w2s(p: Vector2) -> Vector2:
	return size * 0.5 + (p - _cam) * _scale()


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
	_drawn_cam = _cam
	_drawn_zoom = _zoom
	var s := _scale()
	var c := _w2s(Vector2.ZERO)
	var a := MatchMotion.HALF_LEN * s
	var b := MatchMotion.HALF_WID * s

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.09, 0.047), true)

	# Turf + mown stripes
	draw_colored_polygon(_ellipse_points(c, a, b, 128), Color(0.118, 0.333, 0.133))
	var stripes := 9
	for i in range(stripes):
		if i % 2 == 1:
			continue
		var x0 := c.x - a + (2.0 * a) * float(i) / float(stripes)
		var x1 := c.x - a + (2.0 * a) * float(i + 1) / float(stripes)
		draw_colored_polygon(_stripe(c, a, b, x0, x1), Color(0.133, 0.365, 0.149))

	# Boundary
	draw_polyline(_ellipse_points(c, a, b, 128), Color(1, 1, 1, 0.85), 2.5)

	var line_col := Color(1, 1, 1, 0.55)
	var lw := 1.6

	# Centre square (50m) and centre circle (10m across)
	var sq := 25.0 * s
	draw_rect(Rect2(c - Vector2(sq, sq), Vector2(sq, sq) * 2.0), line_col, false, lw)
	draw_arc(c, 5.0 * s, 0, TAU, 32, line_col, lw)

	# 50m arcs and goal squares at each end
	for sgn in [-1.0, 1.0]:
		var goal := _w2s(Vector2(sgn * GOAL_LINE_M, 0.0))
		var rad := 50.0 * s
		var span := _arc_span(c, a, b, goal, rad)
		draw_arc(goal, rad, span.x, span.y, 48, line_col, lw)
		# Goal square: 9m deep, 6.4m wide across the goal line.
		var depth := 9.0 * s
		var width := 6.4 * s
		var gx := goal.x - depth if sgn > 0.0 else goal.x
		draw_rect(Rect2(Vector2(gx, goal.y - width * 0.5), Vector2(depth, width)),
				line_col, false, lw)
		# Goal posts 6.4m apart, behind posts a further 6.4m out.
		for py in [-1.0, 1.0]:
			draw_circle(goal + Vector2(0, py * 3.2 * s), maxf(2.0, 0.55 * s), Color(1, 1, 1, 0.95))
			draw_circle(goal + Vector2(0, py * 9.6 * s), maxf(1.5, 0.4 * s), Color(1, 1, 1, 0.7))

	var tr := maxf(4.0, minf(r.size.x, r.size.y) * 0.5 * 0.030) * sqrt(_zoom)
	_draw_tokens(0, GameDB.club_colours(home_code), tr)
	_draw_tokens(1, GameDB.club_colours(away_code), tr)

	# Actor highlight
	var act := director.actor
	if act >= 0 and act < director.tokens.size():
		var p := _w2s(director.tokens[act]["pos"])
		draw_arc(p, tr * 1.9, 0, TAU, 28, Color(1, 1, 0.55, 0.95), 2.0)

	_draw_ball(tr, s)

	# Goal / behind flash
	var fl := director.flash
	if not fl.is_empty():
		var t := 1.0 - clampf(float(fl["left"]) / 0.9, 0.0, 1.0)
		var rad2 := lerpf(tr, minf(a, b) * 0.42, t)
		var col := Color(1.0, 0.92, 0.35) if fl["goal"] else Color(0.85, 0.9, 1.0)
		col.a = (1.0 - t) * 0.85
		draw_arc(_w2s(fl["pos"]), rad2, 0, TAU, 48, col, 4.0)


func _draw_ball(tr: float, s: float) -> void:
	if director.ball.is_empty():
		return
	var ground := _w2s(director.ball["pos"])
	var h := float(director.ball["h"])
	# Shadow on the turf, the ball lifted by its height: a kick visibly climbs
	# and drops, a handball stays flat.
	var sh := 1.0 / (1.0 + h / 12.0)
	draw_colored_polygon(_ellipse_points(ground, tr * 0.42 * sh, tr * 0.24 * sh, 12),
			Color(0, 0, 0, 0.35 * sh))
	var lift := ground - Vector2(0, h * s * 0.55)
	var grow := 1.0 + h / 26.0
	draw_colored_polygon(_ellipse_points(lift, tr * 0.42 * grow, tr * 0.30 * grow, 12),
			Color(0.98, 0.93, 0.75))
	draw_polyline(_ellipse_points(lift, tr * 0.42 * grow, tr * 0.30 * grow, 12),
			Color(0.25, 0.12, 0.08), 1.0)


func _draw_tokens(side: int, colours: Array, tr: float) -> void:
	var primary: Color = colours[0]
	var secondary: Color = colours[1]
	var font := ThemeDB.fallback_font
	var fs := int(clampf(tr * 1.15, 6.0, 15.0))
	var text_col := _readable_on(primary)
	for t in director.tokens:
		if int(t["side"]) != side:
			continue
		var p := _w2s(t["pos"])
		if p.x < -tr * 3.0 or p.y < -tr * 3.0 or p.x > size.x + tr * 3.0 or p.y > size.y + tr * 3.0:
			continue
		if float(t["down"]) > 0.0:
			# On the ground after a tackle.
			draw_colored_polygon(_ellipse_points(p, tr * 1.15, tr * 0.62, 16), primary.darkened(0.25))
			draw_polyline(_ellipse_points(p, tr * 1.15, tr * 0.62, 16), Color(0, 0, 0, 0.4), 1.2)
			continue
		# Drop shadow keeps tokens readable on the stripes.
		draw_circle(p + Vector2(0, tr * 0.22), tr, Color(0, 0, 0, 0.28))
		draw_circle(p, tr, primary)
		# An inner disc in the secondary colour so the two sides read apart at a glance.
		draw_circle(p, tr * 0.62, secondary)
		draw_circle(p, tr, Color(0, 0, 0, 0.35), false, 1.2)
		var label := str(t["num"])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
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


## Positions in metres and on screen, for the capture tool and tests.
func debug_snapshot() -> Dictionary:
	var snap := director.snapshot()
	var screen := []
	for t in director.tokens:
		screen.append(_w2s(t["pos"]))
	snap["screen"] = screen
	snap["ball_screen"] = _w2s(director.ball.get("pos", Vector2.ZERO))
	return snap


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_cam = _clamp_cam(_cam)
		queue_redraw()
