class_name BroadcastVignette
extends Control
## Short, presentation-only close-ups for dramatic match events.
##
## MatchSim remains the source of truth. This control receives an event plus
## a snapshot of the already-staged PitchView and only draws a cinematic beat
## over the paused match. It never changes Engine.time_scale or match state.

signal finished

const SPECCY_FRONT := "speccy_front"
const SPECCY_SIDE := "speccy_side"
const SPECCY_DEFENSIVE := "speccy_defensive"
const AFTER_SIREN := "after_siren"
const GOAL_LINE := "goal_line"
const BOUNDARY_SNAP := "boundary_snap"

const DURATIONS := {
	SPECCY_FRONT: 3.8,
	SPECCY_SIDE: 3.6,
	SPECCY_DEFENSIVE: 3.7,
	AFTER_SIREN: 5.4,
	GOAL_LINE: 3.5,
	BOUNDARY_SNAP: 4.1,
}

var kind := ""
var event := {}
var scene := {}
var result := {}
var _t := 0.0
var _done := false
var _colours := [[], []]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)


func setup(p_kind: String, p_event: Dictionary, p_scene: Dictionary, p_result: Dictionary) -> void:
	kind = p_kind
	event = p_event.duplicate(true)
	scene = p_scene.duplicate(true)
	result = p_result
	_t = 0.0
	_done = false
	var home := str(result.get("home", ""))
	var away := str(result.get("away", ""))
	_colours[0] = GameDB.club_colours(home) if home != "" else [Color(0.2, 0.2, 0.2), Color.WHITE, Color.WHITE]
	_colours[1] = GameDB.club_colours(away) if away != "" else [Color(0.5, 0.5, 0.5), Color.BLACK, Color.WHITE]
	queue_redraw()


static func duration_for(p_kind: String) -> float:
	return float(DURATIONS.get(p_kind, 3.5))


## Choose only from facts the current presentation already knows. There is no
## extra simulation roll here: the same replay produces the same vignette.
static func pick_kind(ev: Dictionary, prev_ev: Dictionary, next_ev: Dictionary, snap: Dictionary) -> String:
	var ek := str(ev.get("kind", ""))
	var side := clampi(int(ev.get("side", 0)), 0, 1)
	var actor: Vector2 = snap.get("actor_pos", Vector2.ZERO)
	var ball: Vector2 = snap.get("ball_pos", Vector2.ZERO)
	var nearby := int(snap.get("nearby", 0))
	var direction := 1.0 if side == 0 else -1.0
	var attack_x := actor.x * direction

	if (ek == "goal" or ek == "behind") and bool(ev.get("set_shot", false)) 			and int(ev.get("q", 0)) >= 4 and str(next_ev.get("kind", "")) == "final" 			and _pre_score_margin(ev) <= 6:
		return AFTER_SIREN

	if ek == "mark" and nearby >= 3:
		if attack_x < -20.0:
			return SPECCY_DEFENSIVE
		if absf(actor.y) > 20.0:
			return SPECCY_SIDE
		return SPECCY_FRONT

	if ek == "goal" or ek == "behind":
		if not bool(ev.get("set_shot", false)) and attack_x > 32.0 and absf(actor.y) > 30.0:
			return BOUNDARY_SNAP
		var ball_attack := ball.x * direction
		if not bool(ev.get("set_shot", false)) and ball_attack > 78.0 and nearby >= 3:
			return GOAL_LINE

	return ""


static func category(p_kind: String) -> String:
	return "speccy" if p_kind.begins_with("speccy_") else p_kind


static func _pre_score_margin(ev: Dictionary) -> int:
	var goals: Array = (ev.get("goals", [0, 0]) as Array).duplicate()
	var behinds: Array = (ev.get("behinds", [0, 0]) as Array).duplicate()
	if goals.size() < 2 or behinds.size() < 2:
		return 999
	var side := clampi(int(ev.get("side", 0)), 0, 1)
	if str(ev.get("kind", "")) == "goal":
		goals[side] = maxi(0, int(goals[side]) - 1)
	else:
		behinds[side] = maxi(0, int(behinds[side]) - 1)
	var a := int(goals[0]) * 6 + int(behinds[0])
	var b := int(goals[1]) * 6 + int(behinds[1])
	return absi(a - b)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var dur := duration_for(kind)
	var fade_in := clampf(_t / 0.12, 0.0, 1.0)
	var fade_out := clampf((dur - _t) / 0.18, 0.0, 1.0)
	modulate.a = minf(fade_in, fade_out)
	if _t >= dur:
		_finish()
		return
	queue_redraw()


func finish_now() -> void:
	if _done:
		return
	var dur := duration_for(kind)
	_t = maxf(_t, dur - 0.18)
	queue_redraw()


func _gui_input(input: InputEvent) -> void:
	if _t < 0.25:
		return
	if (input is InputEventMouseButton or input is InputEventScreenTouch) and input.is_pressed():
		finish_now()
		accept_event()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_draw_stadium()
	match kind:
		SPECCY_FRONT, SPECCY_SIDE, SPECCY_DEFENSIVE:
			_draw_speccy()
		AFTER_SIREN:
			_draw_after_siren()
		GOAL_LINE:
			_draw_goal_line()
		BOUNDARY_SNAP:
			_draw_boundary_snap()
	_draw_letterbox()


func _draw_stadium() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.035), true)
	var horizon := h * 0.31
	# Crowd as dim bands rather than thousands of expensive nodes.
	for i in range(5):
		var y := horizon - 46.0 + float(i) * 10.0
		var c := Color(0.16 + 0.02 * (i % 2), 0.16, 0.17, 1.0)
		draw_rect(Rect2(0, y, w, 8), c, true)
	draw_rect(Rect2(0, horizon, w, h - horizon), Color(0.10, 0.27, 0.115), true)
	# Mown broadcast stripes.
	for i in range(7):
		if i % 2 == 0:
			draw_rect(Rect2(float(i) * w / 7.0, horizon, w / 7.0, h - horizon),
					Color(0.115, 0.30, 0.125), true)
	# Perspective field lines.
	var van := Vector2(w * 0.5, horizon)
	for x in [w * 0.08, w * 0.28, w * 0.72, w * 0.92]:
		draw_line(van, Vector2(x, h), Color(1, 1, 1, 0.09), 1.4)


func _draw_letterbox() -> void:
	var bar := maxf(20.0, size.y * 0.045)
	draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.96), true)
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.96), true)


func _draw_speccy() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	var ground := h * 0.73
	var cx := w * 0.52
	if kind == SPECCY_SIDE:
		cx = w * 0.60
	elif kind == SPECCY_DEFENSIVE:
		cx = w * 0.46

	var jump_t := clampf((_t - 0.42) / 1.75, 0.0, 1.0)
	var lift := 0.0
	if jump_t < 0.62:
		lift = ease(jump_t / 0.62, -2.0) * h * 0.23
	else:
		lift = lerpf(h * 0.23, h * 0.08, (jump_t - 0.62) / 0.38)
	var contact_hold := _t >= 1.45 and _t <= 1.78
	if contact_hold:
		lift = h * 0.23

	# The pack is deliberately club-colour/silhouette based. We do not infer
	# skin tone from names or identity data the game does not have.
	var pack_scale := 1.05 if kind == SPECCY_FRONT else 1.15
	_draw_player(Vector2(cx - 46, ground + 7), pack_scale, _colours[other], 0, -0.08)
	_draw_player(Vector2(cx + 35, ground + 12), pack_scale, _colours[other], 0, 0.10)
	if kind != SPECCY_DEFENSIVE:
		_draw_player(Vector2(cx + 4, ground + 18), 0.98, _colours[other], 0, 0.02)

	var num := int(event.get("num", 0))
	var mark_pos := Vector2(cx, ground - lift)
	var lean := -0.18 if kind == SPECCY_DEFENSIVE else (0.16 if kind == SPECCY_SIDE else 0.0)
	_draw_player(mark_pos, 1.30, _colours[side], num, lean, true)

	var ball_y := lerpf(h * 0.31, mark_pos.y - 58.0, clampf((_t - 0.35) / 1.25, 0.0, 1.0))
	if _t > 1.7:
		ball_y = lerpf(mark_pos.y - 58.0, mark_pos.y - 36.0, clampf((_t - 1.7) / 0.5, 0.0, 1.0))
	_draw_ball(Vector2(mark_pos.x + (12.0 if kind == SPECCY_SIDE else 0.0), ball_y), 1.15)

	# Brief contact halo reads as the slow-motion/freeze beat without touching
	# Engine.time_scale, which would affect the whole game.
	if contact_hold:
		var p := Vector2(mark_pos.x, mark_pos.y - 54)
		draw_arc(p, 34, 0, TAU, 30, Color(1, 1, 1, 0.72), 2.2)


func _draw_after_siren() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var ground := h * 0.76
	_draw_posts(w * 0.50, h * 0.34, 0.72)

	var run := clampf((_t - 1.75) / 1.45, 0.0, 1.0)
	var kicker_x := lerpf(w * 0.28, w * 0.46, ease(run, -1.5))
	_draw_player(Vector2(kicker_x, ground), 1.32, _colours[side], num, 0.10 if run > 0.2 else 0.0)

	if _t < 3.02:
		var bob := sin(_t * 8.0) * 2.5 if _t < 1.5 else 0.0
		_draw_ball(Vector2(kicker_x + 14, ground - 74 + bob), 1.20)
	else:
		var flight := clampf((_t - 3.02) / 1.85, 0.0, 1.0)
		var start := Vector2(w * 0.49, ground - 24)
		var finish_x := w * 0.50 if str(event.get("kind", "")) == "goal" else w * 0.60
		var finish := Vector2(finish_x, h * 0.31)
		var control := Vector2(w * 0.52, h * 0.08)
		var bp := _quad(start, control, finish, flight)
		_draw_ball(bp, lerpf(1.18, 0.62, flight))
		if flight > 0.92:
			draw_arc(finish, 24.0, 0, TAU, 28, Color(1, 1, 1, 0.65), 2.0)


func _draw_goal_line() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	var line_y := h * 0.64
	_draw_posts(w * 0.50, line_y - h * 0.19, 1.15)
	draw_line(Vector2(w * 0.08, line_y), Vector2(w * 0.92, line_y),
			Color(1, 1, 1, 0.9), 3.0)

	var scramble := clampf((_t - 0.35) / 1.55, 0.0, 1.0)
	var sway := sin(scramble * PI * 3.0) * 10.0
	_draw_player(Vector2(w * 0.36 + sway, line_y + 84), 1.15, _colours[side], int(event.get("num", 0)), -0.20)
	_draw_player(Vector2(w * 0.49 - sway * 0.5, line_y + 92), 1.10, _colours[other], 0, 0.18)
	_draw_player(Vector2(w * 0.62 + sway * 0.3, line_y + 82), 1.06, _colours[other], 0, -0.05)
	_draw_player(Vector2(w * 0.25, line_y + 104), 0.96, _colours[side], 0, 0.08)

	var cross := clampf((_t - 1.05) / 1.35, 0.0, 1.0)
	var result_x := w * 0.50 if str(event.get("kind", "")) == "goal" else w * 0.68
	var bx := lerpf(w * 0.44, result_x, cross)
	var by := lerpf(line_y + 40, line_y - 18, cross)
	_draw_ball(Vector2(bx, by), 1.05)
	if _t > 2.25:
		draw_arc(Vector2(result_x, line_y - 14), 28, 0, TAU, 30, Color(1, 1, 1, 0.58), 2.0)


func _draw_boundary_snap() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var ground := h * 0.78
	# Boundary pocket in the foreground.
	var pts := PackedVector2Array()
	for i in range(25):
		var u := float(i) / 24.0
		pts.append(Vector2(lerpf(-20.0, w * 0.70, u), ground - 150.0 * sin(u * PI * 0.55)))
	draw_polyline(pts, Color(1, 1, 1, 0.92), 3.0)
	_draw_posts(w * 0.74, h * 0.34, 0.74)

	var kick := clampf((_t - 0.75) / 1.15, 0.0, 1.0)
	_draw_player(Vector2(w * 0.25 + kick * 25.0, ground), 1.28, _colours[side], num, -0.16)
	if _t < 1.35:
		_draw_ball(Vector2(w * 0.30, ground - 72 + 26 * kick), 1.10)
	else:
		var flight := clampf((_t - 1.35) / 1.85, 0.0, 1.0)
		var start := Vector2(w * 0.31, ground - 35)
		var finish_x := w * 0.74 if str(event.get("kind", "")) == "goal" else w * 0.82
		var finish := Vector2(finish_x, h * 0.32)
		var control := Vector2(w * 0.43, h * 0.15)
		var bp := _quad(start, control, finish, flight)
		_draw_ball(bp, lerpf(1.10, 0.60, flight))
		if flight > 0.92:
			draw_arc(finish, 22, 0, TAU, 26, Color(1, 1, 1, 0.6), 2.0)


func _draw_player(pos: Vector2, scale: float, cols: Array, number: int,
		lean := 0.0, arms_up := false) -> void:
	var primary: Color = cols[0] if cols.size() > 0 else Color(0.25, 0.25, 0.28)
	var secondary: Color = cols[1] if cols.size() > 1 else Color.WHITE
	var body := pos + Vector2(lean * 22.0 * scale, -44.0 * scale)
	var hip := pos + Vector2.ZERO
	var shoulder_l := body + Vector2(-14, -12) * scale
	var shoulder_r := body + Vector2(14, -12) * scale
	var hand_y := -42.0 if arms_up else 18.0
	draw_line(hip + Vector2(-6, 0) * scale, hip + Vector2(-15, 38) * scale,
			Color(0.055, 0.06, 0.07), 7.0 * scale, true)
	draw_line(hip + Vector2(6, 0) * scale, hip + Vector2(15, 38) * scale,
			Color(0.055, 0.06, 0.07), 7.0 * scale, true)
	var torso := PackedVector2Array([
		body + Vector2(-16, -16) * scale,
		body + Vector2(16, -16) * scale,
		body + Vector2(13, 24) * scale,
		body + Vector2(-13, 24) * scale,
	])
	draw_colored_polygon(torso, primary)
	draw_line(body + Vector2(-13, 7) * scale, body + Vector2(13, 7) * scale, secondary, 5.0 * scale)
	var hand_l := shoulder_l + Vector2(-16, hand_y) * scale
	var hand_r := shoulder_r + Vector2(16, hand_y) * scale
	draw_line(shoulder_l, hand_l, primary.darkened(0.18), 6.0 * scale, true)
	draw_line(shoulder_r, hand_r, primary.darkened(0.18), 6.0 * scale, true)
	# Neutral silhouette head: no invented ethnicity or skin tone.
	draw_circle(body + Vector2(0, -29) * scale, 8.5 * scale, Color(0.10, 0.095, 0.09))
	if number > 0 and scale >= 0.9:
		var font := ThemeDB.fallback_font
		var fs := maxi(8, int(12.0 * scale))
		var label := str(number)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, body + Vector2(-tw * 0.5, 5 * scale), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _readable_on(primary))


func _draw_ball(pos: Vector2, scale: float) -> void:
	var a := 9.0 * scale
	var b := 6.0 * scale
	draw_colored_polygon(_ellipse(pos, a, b, 16), Color(0.79, 0.12, 0.10))
	draw_polyline(_ellipse(pos, a, b, 16), Color(0.18, 0.05, 0.04), maxf(1.0, scale))


func _draw_posts(cx: float, base_y: float, scale: float) -> void:
	for dx in [-42.0, -14.0, 14.0, 42.0]:
		var inner := absf(dx) < 20.0
		var top := base_y - (115.0 if inner else 82.0) * scale
		draw_line(Vector2(cx + dx * scale, base_y + 78 * scale),
				Vector2(cx + dx * scale, top), Color(0.96, 0.96, 0.94), 5.0 * scale, true)


func _ellipse(c: Vector2, a: float, b: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n + 1):
		var ang := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(ang) * a, sin(ang) * b))
	return out


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


func _readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.06, 0.06, 0.07) if lum > 0.58 else Color.WHITE
