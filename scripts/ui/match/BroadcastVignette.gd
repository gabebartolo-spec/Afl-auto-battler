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
	GOAL_LINE: 4.0,
	BOUNDARY_SNAP: 4.1,
}

var kind := ""
var event := {}
var scene := {}
var result := {}
var _t := 0.0
var _done := false
var _colours := [[], []]
var _kits := []               # each side's guernsey
var _look := Appearance.UNCURATED   # the featured player's look
var _build := "average"             # and his build, from his real height (build_for)
var _view := Transform2D.IDENTITY   # the camera this frame (VignetteCamera)

## The figures are the vignettes' pre-rendered footballers (VignetteFigures,
## figure.gdshader), sized as the old drawn figures were: about this many
## pixels from boots to crown at scale 1.
const FIGURE_PX := 119.5
## Pixels per metre at scale 1, for the 1.88 m average build.
const PX_PER_M := FIGURE_PX / 1.88
const BODY := "average"
## Extras (the pack, a defender) aren't named by MatchSim: one neutral look, so
## no real player is implied; their club's kit still shows whose they are.
const EXTRA_LOOK := Appearance.UNCURATED
## Under this height a player is drawn on the small build (1.78 m): the league's
## shortest fifth - the crumbers and small forwards.
const SMALL_CM := 182.0


## Which build a player is drawn on, from his real height. The small build only has
## the moves a small man plays, so a move it lacks falls back to the average build.
static func build_for(p: Dictionary) -> String:
	var cm := float(p.get("height_cm", 0.0))
	return "small" if cm > 0.0 and cm < SMALL_CM else "average"


## Jog strides per second, matching the centre-bounce scene.
const STRIDES := 13.0 / TAU
## When the set shot's kick begins: the ball leaves the boot at 3.02 s.
const KICK_START := 2.80
## Where the kicking boot meets the ball, metres right of and above his feet, on the
## contact frame (3) of the figures' kick and snap (measured off the rendered frames).
const KICK_BOOT := Vector2(0.70, 0.73)
const SNAP_BOOT := Vector2(0.62, 0.63)
## Heights in metres, so a leap is a footballer's leap on any screen: a speccy's
## knees in the pack's backs, a one-on-one contest.
const SPECCY_PEAK := 1.05
const SPECCY_SETTLE := 0.45
const CONTEST_PEAK := 0.55
## The crumber's scale: nearer the camera than the marking contest, so a little larger
## on screen - but a small forward, not a giant (he's drawn on his own build too).
const CRUMB_SCALE := 1.08
## The crumb: the snap's boot meets the ball (the ball's flight starts) at this time.
const SNAP_AT := 2.25
## The stage the close-ups draw, in screens either side of the screen itself: wide enough
## for the camera to pan with the play (the crumber breaking into space) without running
## out of stand and turf.
const STAGE_SIDE := 0.4


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
	_dress([home, away])
	var p = GameDB.player_by_id(str(event.get("player_id", "")))
	_look = GameDB.player_looks(p) if p is Dictionary else Appearance.UNCURATED
	_build = build_for(p if p is Dictionary else {})
	queue_redraw()


## Both sides' guernseys on the figure material (an unknown club wears its colours plain).
func _dress(codes: Array) -> void:
	_kits = []
	for side in range(2):
		var code := str(codes[side]) if side < codes.size() else ""
		var cols: Array = _colours[side]
		var trim: Color = cols[1] if cols.size() > 1 else Color.DIM_GRAY
		_kits.append(GameDB.club_guernsey(code) if code != "" else {
				"design": "plain", "base": cols[0] if cols.size() > 0 else Color.WHITE,
				"pattern": trim, "pattern2": Color.WHITE, "shorts": trim.darkened(0.1)})
	material = StoppageVignette.figure_material(_kits, material as ShaderMaterial)


static func duration_for(p_kind: String) -> float:
	return float(DURATIONS.get(p_kind, 3.5))


## Choose only from facts the current presentation already knows. There is no
## extra simulation roll here: the same replay produces the same vignette.
static func pick_kind(ev: Dictionary, prev_ev: Dictionary, next_ev: Dictionary, snap: Dictionary) -> String:
	var ek := str(ev.get("kind", ""))
	var side := clampi(int(ev.get("side", 0)), 0, 1)
	var actor: Vector2 = snap.get("actor_pos", Vector2.ZERO)
	var nearby := int(snap.get("nearby", 0))
	var direction := 1.0 if side == 0 else -1.0
	var attack_x := actor.x * direction

	if (ek == "goal" or ek == "behind") and bool(ev.get("set_shot", false)) 			and int(ev.get("q", 0)) >= 4 and str(next_ev.get("kind", "")) == "final" 			and _pre_score_margin(ev) <= 6:
		return AFTER_SIREN

	if ek == "mark" and bool(ev.get("speccy", false)) and nearby >= 3:
		if attack_x < -20.0:
			return SPECCY_DEFENSIVE
		if absf(actor.y) > 20.0:
			return SPECCY_SIDE
		return SPECCY_FRONT

	if ek == "goal" or ek == "behind":
		# The goal-line scene is the sim's own crumb: a spoil spills to the
		# ground and a small forward snaps it off the deck. Where the ball
		# finished says nothing (every score ends at the goals).
		if bool(ev.get("crumb", false)):
			return GOAL_LINE
		if not bool(ev.get("set_shot", false)) and attack_x > 32.0 and absf(actor.y) > 30.0:
			return BOUNDARY_SNAP

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
	var cam := _camera()
	_view = VignetteCamera.view(size, cam[0] + VignetteCamera.breathe(_t, size), cam[1], _stage())
	draw_set_transform_matrix(_view)
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
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_letterbox()


## The drawn stage: the screen and STAGE_SIDE screens either side.
func _stage() -> Rect2:
	return Rect2(-size.x * STAGE_SIDE, 0.0, size.x * (1.0 + 2.0 * STAGE_SIDE), size.y)


## Where the camera looks and how far it has zoomed, for each kind and moment: a TV
## camera on a long lens, following the play (VignetteCamera: the lens zooms, the camera
## pans; nothing changes shape).
func _camera() -> Array:
	var w := size.x
	var h := size.y
	var G := VignetteCamera
	match kind:
		SPECCY_FRONT, SPECCY_SIDE, SPECCY_DEFENSIVE:
			# The pack and the ball's flight, in tight on his hands for the grab, then
			# easing back as he comes down with it.
			var cx := _speccy_x()
			var z: float = G.glide(G.glide(1.0, 1.3, _t, 0.4, 1.45), 1.12, _t, 1.85, 2.9)
			var fy: float = G.glide(G.glide(h * 0.52, h * 0.42, _t, 0.4, 1.45), h * 0.5, _t, 1.85, 2.9)
			return [Vector2(cx, fy), z]
		AFTER_SIREN:
			# On him lining it up, then wider as he runs in, and with the ball to the posts.
			var k := _kicker_after_siren()
			var on: Vector2 = G.glide(k + Vector2(0, -h * 0.08), Vector2(w * 0.5, h * 0.45), _t, 2.4, 3.8)
			return [on, G.glide(G.glide(1.22, 1.1, _t, 0.6, 2.4), 1.0, _t, 2.6, 3.8)]
		GOAL_LINE:
			# The contest, then the fall of the ball, then running with the crumber as he
			# breaks into space (room ahead of him), then wide for the snap at goal.
			var c := _crumber()
			var follow := Vector2(c.x - w * 0.08, h * 0.66)
			var on: Vector2 = G.glide(Vector2(w * 0.6, h * 0.58), follow, _t, 0.9, 1.6)
			on = G.glide(on, Vector2(w * 0.38, h * 0.5), _t, SNAP_AT - 0.1, SNAP_AT + 0.7)
			var z: float = G.glide(G.glide(1.18, 1.25, _t, 0.9, 1.6), 1.0, _t, SNAP_AT - 0.1, SNAP_AT + 0.7)
			return [on, z]
		BOUNDARY_SNAP:
			var k := Vector2(w * 0.25 + clampf((_t - 0.75) / 1.15, 0.0, 1.0) * 25.0, h * 0.7)
			var on: Vector2 = G.glide(k, Vector2(w * 0.5, h * 0.48), _t, 1.3, 2.6)
			return [on, G.glide(1.22, 1.0, _t, 1.3, 2.6)]
	return [size * 0.5, 1.0]


func _draw_stadium() -> void:
	var w := size.x
	var h := size.y
	var stage := _stage()
	var x0 := stage.position.x
	var sw := stage.size.x
	draw_rect(stage, Color(0.025, 0.03, 0.035), true)
	var horizon := h * 0.31
	# The stand behind the play under its roof, both clubs' supporters in it (one
	# cached texture), and the fence and its boards at the boundary.
	var top := maxf(h * 0.06, horizon - h * 0.2)
	draw_rect(Rect2(x0, top - 3.0, sw, 3.0), Color(0.16, 0.16, 0.18), true)      # the roof's edge
	VignetteCrowd.draw(self, Rect2(x0, top, sw, horizon - top - 6.0), _colours, _t, 11)
	draw_rect(Rect2(x0, horizon - 6.0, sw, 6.0), Color(0.1, 0.1, 0.11), true)
	var boards := maxi(4, int(sw / 46.0))
	for i in range(boards):
		var bc: Color = (_colours[i % 2] as Array)[0] if not (_colours[i % 2] as Array).is_empty() else Color.DIM_GRAY
		draw_rect(Rect2(x0 + sw * float(i) / boards + 1.0, horizon - 5.0, sw / boards - 2.0, 4.0), bc.darkened(0.25), true)
	draw_rect(Rect2(x0, horizon, sw, h - horizon), Color(0.10, 0.27, 0.115), true)
	# Mown broadcast stripes, a seventh of a screen wide.
	var stripe := w / 7.0
	var i := int(floor(x0 / stripe))
	while i * stripe < stage.end.x:
		if posmod(i, 2) == 0:
			draw_rect(Rect2(i * stripe, horizon, stripe, h - horizon), Color(0.115, 0.30, 0.125), true)
		i += 1
	# Perspective field lines.
	var van := Vector2(w * 0.5, horizon)
	for x in [-w * 0.5, w * 0.08, w * 0.28, w * 0.72, w * 0.92, w * 1.5]:
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
	var cx := _speccy_x()

	var jump_t := clampf((_t - 0.42) / 1.75, 0.0, 1.0)
	var peak := SPECCY_PEAK * PX_PER_M * 1.30
	var lift := 0.0
	if jump_t < 0.62:
		lift = ease(jump_t / 0.62, -2.0) * peak
	else:
		lift = lerpf(peak, SPECCY_SETTLE * PX_PER_M * 1.30, (jump_t - 0.62) / 0.38)
	var contact_hold := _t >= 1.45 and _t <= 1.78
	if contact_hold:
		lift = peak

	# The pack: everyone faces the ball coming in, so their backs are to us, just upfield
	# of the marker. Each contests his own way: the man he climbs goes up with both
	# hands; one punches with a fist (a spoil); one stays down, body-on, bracing.
	# Further away, they're drawn first, a touch smaller.
	var pack := [
		{"at": Vector2(cx + 6, ground - 16), "scale": 1.18, "how": "leap", "delay": 0.0, "lift": 0.45},
		{"at": Vector2(cx - 46, ground - 6), "scale": 1.22, "how": "tap_b", "delay": 0.12, "lift": 0.3},
		{"at": Vector2(cx + 44, ground - 24), "scale": 1.12, "how": "ready_turn", "delay": 0.0, "lift": 0.0},
	]
	for i in range(2 if kind == SPECCY_DEFENSIVE else 3):
		var m: Dictionary = pack[i]
		var at: Vector2 = m["at"]
		var k := clampf((_t - 0.42 - float(m["delay"])) / 0.9, 0.0, 1.0)
		var up := sin(k * PI) * float(m["lift"]) * peak
		if str(m["how"]) == "ready_turn" or k <= 0.0:
			# Waiting on it, or holding his ground body-on: watching the ball, his own rhythm.
			_ready_figure(at, float(m["scale"]), other, "back", 13 + i * 5, i == 2, i == 2)
		else:
			var frames := 6 if str(m["how"]) == "leap" else 4
			_figure(at - Vector2(0, up), float(m["scale"]), other, str(m["how"]), "back",
					mini(frames - 1, int(k * frames * 1.4)), 0, EXTRA_LOOK, at, i == 1)

	# The marker, back to us so his number shows, comes over the pack from behind
	# (drawn last, nearest): crouch on the turf, spring, arms up for the ball and the
	# knee in a back, then down with it held to his chest.
	var num := int(event.get("num", 0))
	var mark_pos := Vector2(cx, ground - lift)
	var leap_frame := 0
	if _t >= 0.42:
		if jump_t < 0.08:
			leap_frame = 1                                         # the take-off crouch
		else:
			leap_frame = 2 + int(roundf(clampf((jump_t - 0.08) / 0.4, 0.0, 1.0) * 3.0))
		if _t > 1.78:
			leap_frame = 2                                         # ball in to the chest
	# The ball comes down into his hands - where the frame's hands are (VignetteFigures
	# reach: the top of the figure) - and stays in them. Once he brings it down to his
	# chest it's in front of him, so from behind his body hides it: drawn before him.
	var strip := VignetteFigures.strip(_build if VignetteFigures.has(_build, "leap", "back") else BODY, "leap", "back")
	var hands := _at(mark_pos, 1.30, Vector2(0.0, VignetteFigures.reach(strip, leap_frame) - 0.09))
	var ball := hands
	var held := _t >= 1.45
	if not held:
		var k := clampf((_t - 0.35) / 1.1, 0.0, 1.0)
		ball = Vector2(hands.x, lerpf(h * 0.30, hands.y, k * k * (3.0 - 2.0 * k)))
	var ball_scale := lerpf(0.75, 1.15, clampf((_t - 0.35) / 1.1, 0.0, 1.0))
	if _t > 1.78:
		_draw_ball(ball, ball_scale)
	_figure(mark_pos, 1.30, side, "leap", "back", leap_frame, num, _look, Vector2(cx, ground), false, _build)
	if _t <= 1.78:
		_draw_ball(ball, ball_scale)

	# Brief contact halo reads as the slow-motion/freeze beat without touching
	# Engine.time_scale, which would affect the whole game.
	if contact_hold:
		draw_arc(hands, 34, 0, TAU, 30, Color(1, 1, 1, 0.72), 2.2)


## Where the speccy's marker goes up, across the screen.
func _speccy_x() -> float:
	if kind == SPECCY_SIDE:
		return size.x * 0.60
	if kind == SPECCY_DEFENSIVE:
		return size.x * 0.46
	return size.x * 0.52


func _draw_after_siren() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var ground := h * 0.76
	_draw_posts(w * 0.50, h * 0.34, 0.72)

	# Square behind the ball lining up the goal, then the run in, away from us
	# towards the posts, and the drop punt. He plants for the kick, so he stops
	# where the kick starts.
	var run := clampf((minf(_t, KICK_START) - 1.75) / 1.45, 0.0, 1.0)
	var kicker := _kicker_after_siren()
	var scale := lerpf(1.32, 1.22, ease(run, -1.5))     # smaller as he runs away from us
	var boot := _at(kicker, scale, KICK_BOOT)
	if _t < 2.92:
		# Held at the waist in front of him (so behind him from here, peeking out).
		var bob := sin(_t * 8.0) * 2.5 if _t < 1.5 else 0.0
		_draw_ball(_at(kicker, scale, Vector2(0.2, 0.95)) + Vector2(0, bob), 1.20)
	if _t < 1.75:
		_ready_figure(kicker, scale, side, "back", 3, false, false, num, _look, _build)
	elif _t < KICK_START:
		_figure(kicker, scale, side, "jog", "back_r", _stride(_t - 1.75), num, _look, Vector2.INF, false, _build)
	elif _t < 3.45:
		_figure(kicker, scale, side, "kick", "back_r", _kick_frame(_t - KICK_START, 3.02 - KICK_START), num, _look, Vector2.INF, false, _build)
	else:
		_ready_figure(kicker, scale, side, "back", 3, false, false, num, _look, _build)     # leg down, watching it go

	if _t >= 2.92 and _t < 3.02:
		# Dropped onto the boot.
		_draw_ball(_at(kicker, scale, Vector2(0.2, 0.95)).lerp(boot, (_t - 2.92) / 0.1), 1.20)
	elif _t >= 3.02:
		var flight := clampf((_t - 3.02) / 1.85, 0.0, 1.0)
		var start := boot
		var finish_x := w * 0.50 if str(event.get("kind", "")) == "goal" else w * 0.60
		var finish := Vector2(finish_x, h * 0.31)
		var control := Vector2(w * 0.52, h * 0.08)
		var bp := _quad(start, control, finish, flight)
		_draw_ball(bp, lerpf(1.18, 0.62, flight))
		if flight > 0.92:
			draw_arc(finish, 24.0, 0, TAU, 28, Color(1, 1, 1, 0.65), 2.0)


func _kicker_after_siren() -> Vector2:
	var run := clampf((minf(_t, KICK_START) - 1.75) / 1.45, 0.0, 1.0)
	return Vector2(lerpf(size.x * 0.28, size.x * 0.46, ease(run, -1.5)), size.y * 0.76)


## The crumb, as MatchSim plays it: a marking contest in front of goal, the
## spoil spills to the ground, the small forward gathers at the fall of the
## ball and snaps. The ball goes between the goal posts for a goal, between a
## goal post and a behind post for a behind.
func _draw_goal_line() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	# Posts in the distance, standing on the goal line.
	var post_scale := 0.80
	var line_y := h * 0.47
	var cx := w * 0.50
	_draw_posts(cx, line_y - 78.0 * post_scale, post_scale)
	var stage := _stage()
	draw_line(Vector2(stage.position.x, line_y), Vector2(stage.end.x, line_y), Color(1, 1, 1, 0.85), 2.0)

	# The marking contest: a forward and a defender up together, the defender's
	# fist getting there first.
	var pack_ground := h * 0.70
	var rise := clampf(_t / 0.85, 0.0, 1.0)
	var fall := clampf((_t - 0.95) / 0.45, 0.0, 1.0)
	var lift := (ease(rise, -2.0) - ease(fall, 2.0)) * CONTEST_PEAK * PX_PER_M
	var contest := int(roundf(rise * 5.0)) if fall <= 0.0 else int(roundf((1.0 - fall) * 4.0))
	var landed := fall >= 1.0 and _t > 1.55      # back on their feet, standing
	# Once down they turn to the crumb, off to the screen's left: the forward (back to
	# us) to his left, the defender (facing us) to his right. Up, the defender's a beat behind.
	if landed:
		_ready_figure(Vector2(w * 0.57, pack_ground), 1.0, side, "back", 5, true, false)
		_ready_figure(Vector2(w * 0.64, pack_ground), 1.0, other, "front", 9, true, true)
	else:
		_figure(Vector2(w * 0.57, pack_ground - lift), 1.0, side, "leap", "back", contest, 0, EXTRA_LOOK,
				Vector2(w * 0.57, pack_ground))
		_figure(Vector2(w * 0.64, pack_ground - lift), 1.0, other, "leap", "front", maxi(0, contest - 1), 0, EXTRA_LOOK,
				Vector2(w * 0.64, pack_ground))

	# A third defender, off the contest, reads the spill and chases the crumber across
	# (heading left like him, a step behind), diving at his kick and missing.
	var chase := clampf((_t - 1.55) / (SNAP_AT - 0.3 - 1.55), 0.0, 1.0)
	var dive := clampf((_t - (SNAP_AT - 0.3)) / 0.45, 0.0, 1.0)
	var chaser := Vector2(lerpf(w * 0.72, w * 0.30, chase * 0.82 + dive * 0.18), lerpf(pack_ground + 6.0, h * 0.78, chase))
	if _t < 1.55:
		_ready_figure(chaser, 0.98, other, "front", 2, true, true)      # eyes on the fall of the ball
	elif dive <= 0.0:
		_figure(chaser, 0.98, other, "jog", "side_l", int((_t - 1.55) * 15.0) % 8)
	elif _t < SNAP_AT + 0.5:
		_figure(chaser, 0.98, other, "lunge", "side_l", mini(2, int(dive * 3.0)))
	else:
		_ready_figure(chaser, 0.98, other, "front", 2, false, true)

	# The crumber reads the contest, low and side-on, swoops on the fall of the ball,
	# then breaks away from the pack into space - right to left across the screen - and
	# snaps around his body at goal.
	var num := int(event.get("num", 0))
	var crumber := _crumber()
	var run_at := 1.65
	var snap_from := SNAP_AT - 0.12
	if _t < 1.35:
		_ready_figure(crumber, CRUMB_SCALE, side, "back", 4, true, true, num, _look, _build, true)
	elif _t < run_at:
		# Down over the ball as it reaches him, up with it into the chest.
		var g := 0 if _t < 1.45 else (1 if _t < 1.56 else 2)
		_figure(crumber, CRUMB_SCALE, side, "gather", "back_r", g, num, _look, Vector2.INF, true, _build)
	elif _t < snap_from:
		_figure(crumber, CRUMB_SCALE, side, "jog", "side_l", int((_t - run_at) * 15.0) % 8, num, _look, Vector2.INF, false, _build)
	elif _t < SNAP_AT + 0.45:
		# Snapped around the body: the boot meets the ball at SNAP_AT.
		_figure(crumber, CRUMB_SCALE, side, "snap", "back_r", mini(4, int((_t - snap_from) / 0.04)), num, _look, Vector2.INF, true, _build)
	else:
		_ready_figure(crumber, CRUMB_SCALE, side, "back", 4, true, true, num, _look, _build)     # watching it go

	var top := Vector2(w * 0.605, pack_ground - lift + 38.0 - 2.25 * PX_PER_M)
	var gather_at := _crumber_at(1.45)
	var deck := gather_at + Vector2(-0.34 * PX_PER_M * CRUMB_SCALE, 38.0 * CRUMB_SCALE - 4.0)
	var hands := _at(crumber, CRUMB_SCALE, Vector2(-0.3, 1.0))
	var boot := _at(crumber, CRUMB_SCALE, Vector2(-SNAP_BOOT.x, SNAP_BOOT.y))     # snapping heading left: mirrored
	var goal := str(event.get("kind", "")) == "goal"
	var target := Vector2(cx + (0.0 if goal else -28.0 * post_scale), line_y - 62.0 * post_scale)
	if _t < 0.95:
		_draw_ball(Vector2(top.x, lerpf(h * 0.18, top.y, clampf(_t / 0.95, 0.0, 1.0))), 1.0)
		return
	if _t < 1.45:
		# Off the spoil, forward off the pack, one bounce, into the crumber's path.
		var u := clampf((_t - 0.95) / 0.5, 0.0, 1.0)
		var bounce := Vector2((top.x + deck.x) * 0.5, deck.y - 28.0)
		var p := _quad(top, Vector2(top.x - 20.0, top.y + 30.0), bounce, minf(u / 0.7, 1.0)) if u < 0.7 \
				else bounce.lerp(deck, (u - 0.7) / 0.3)
		_draw_ball(p, 1.05)
		if _t < 1.05:
			draw_arc(top, 22, 0, TAU, 24, Color(1, 1, 1, 0.55), 2.0)
		return
	if _t < SNAP_AT:
		# Gathered into the hands, carried, then dropped onto the boot.
		var up := clampf((_t - 1.45) / 0.15, 0.0, 1.0)
		var drop := clampf((_t - (SNAP_AT - 0.08)) / 0.08, 0.0, 1.0)
		_draw_ball(deck.lerp(hands, up).lerp(boot, drop), 1.1)
		return
	var flight := clampf((_t - SNAP_AT) / 1.15, 0.0, 1.0)
	# Curling back from the pocket to the target, rising then dropping into it.
	var control := Vector2(lerpf(boot.x, target.x, 0.35), target.y - h * 0.12)
	_draw_ball(_quad(boot, control, target, flight), lerpf(1.1, 0.55, flight))
	if flight > 0.92:
		draw_arc(target, 20, 0, TAU, 26, Color(1, 1, 1, 0.6), 2.0)


## The crumber's hip, now (his run into space, see _crumber_at).
func _crumber() -> Vector2:
	return _crumber_at(_t)


## Where the crumber is at time t: waiting just in front of the contest, a step to the
## fall of the ball, then away from the congestion to the left, into space, at a
## small forward's pace (matched to his stride, so his feet don't slide).
func _crumber_at(t: float) -> Vector2:
	var w := size.x
	var x := lerpf(w * 0.48, w * 0.45, smoothstep(0.9, 1.4, t))
	var run := clampf((t - 1.65) / (SNAP_AT - 0.12 - 1.65), 0.0, 1.0)
	x = lerpf(x, w * 0.06, run)
	x -= clampf((t - (SNAP_AT - 0.12)) / 0.3, 0.0, 1.0) * w * 0.03     # carried on through the kick
	return Vector2(x, size.y * 0.80)


func _draw_boundary_snap() -> void:
	var w := size.x
	var h := size.y
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var ground := h * 0.78
	# The boundary line just to his left, running away from us towards the goal line: a
	# straight painted line in perspective (it was a free-hand curve that read as a
	# stray stroke - director's playtest), the grass beyond it out of bounds and darker.
	var horizon := h * 0.31
	var van := Vector2(w * 0.5, horizon)
	var near := Vector2(-w * 0.2, h)
	var out := PackedVector2Array([van, near, Vector2(_stage().position.x, h), Vector2(_stage().position.x, horizon)])
	draw_colored_polygon(out, Color(0.06, 0.18, 0.08, 0.55))
	for i in range(8):
		# Thicker as it comes nearer, faded into the distance.
		var a := van.lerp(near, float(i) / 8.0)
		var b := van.lerp(near, float(i + 1) / 8.0)
		draw_line(a, b, Color(1, 1, 1, lerpf(0.35, 0.9, float(i) / 8.0)), lerpf(1.0, 4.0, float(i + 1) / 8.0))
	_draw_posts(w * 0.74, h * 0.34, 0.74)

	var kick := clampf((_t - 0.75) / 1.15, 0.0, 1.0)
	var kicker := Vector2(w * 0.25 + kick * 25.0, ground)
	var boot := _at(kicker, 1.28, SNAP_BOOT)
	var held := _at(kicker, 1.28, Vector2(0.2, 0.95))
	if _t < 1.25:
		_draw_ball(held, 1.10)        # in his hands in front of him: behind him from here
	# Steadying, a few steps at goal, then the snap around the body; the ball
	# leaves the boot at 1.35 s.
	if _t < 0.45:
		_ready_figure(kicker, 1.28, side, "back", 6, false, false, num, _look, _build)
	elif _t < 1.05:
		_figure(kicker, 1.28, side, "jog", "back_r", _stride(_t - 0.45), num, _look, Vector2.INF, false, _build)
	elif _t < 1.85:
		_figure(kicker, 1.28, side, "snap", "back_r", mini(4, int((_t - 1.05) / 0.1)), num, _look, Vector2.INF, false, _build)
	else:
		_ready_figure(kicker, 1.28, side, "back", 6, false, false, num, _look, _build)     # landed, watching it
	if _t >= 1.25 and _t < 1.35:
		_draw_ball(held.lerp(boot, (_t - 1.25) / 0.1), 1.10)      # dropped onto the boot
	elif _t >= 1.35:
		var flight := clampf((_t - 1.35) / 1.85, 0.0, 1.0)
		var start := boot
		var finish_x := w * 0.74 if str(event.get("kind", "")) == "goal" else w * 0.82
		var finish := Vector2(finish_x, h * 0.32)
		var control := Vector2(w * 0.43, h * 0.15)
		var bp := _quad(start, control, finish, flight)
		_draw_ball(bp, lerpf(1.10, 0.60, flight))
		if flight > 0.92:
			draw_arc(finish, 22, 0, TAU, 26, Color(1, 1, 1, 0.6), 2.0)


## A point on a figure drawn at pos (its hip) and scale: metres right of and above
## its feet.
func _at(pos: Vector2, scale: float, metres: Vector2) -> Vector2:
	return pos + Vector2(metres.x * PX_PER_M * scale, 38.0 * scale - metres.y * PX_PER_M * scale)


## A frame of the jog, at the centre-bounce scene's stride rate.
func _stride(t: float) -> int:
	return int(t * STRIDES * 8.0) % 8


## Kick frames: back-swing up to the contact frame (3) at `contact` seconds in,
## then the follow-through, held.
func _kick_frame(t: float, contact: float) -> int:
	if t < contact:
		return mini(3, int(t / contact * 3.0))
	return mini(5, 3 + int((t - contact) / 0.08))


## One footballer. pos is the hip, where the old drawn figures were anchored (a
## figure stands 38 px * scale below it); ground is the hip of a man in the air
## standing on the turf, where his shadow falls (defaults to pos). Numbers show
## on back-facing frames.
func _figure(pos: Vector2, scale: float, side: int, anim: String, facing: String, frame: int,
		number := 0, look: Dictionary = EXTRA_LOOK, ground := Vector2.INF, mirror := false,
		build := BODY) -> void:
	if not VignetteFigures.has(build, anim, facing):
		build = BODY
	var feet := pos + Vector2(0, 38.0 * scale)
	var pm := PX_PER_M * scale
	var shadow_at := feet if ground == Vector2.INF else ground + Vector2(0, 38.0 * scale)
	draw_set_transform_matrix(_view * Transform2D(0.0, Vector2(1.0, 0.3), 0.0, shadow_at))
	draw_circle(Vector2.ZERO, 0.4 * pm, Color(0, 0, 0, 0.32))
	draw_set_transform_matrix(_view)
	var info := VignetteFigures.strip(build, anim, facing)
	var f := clampi(frame, 0, int(info["frames"]) - 1)
	var k := pm / VignetteFigures.PX_PER_M
	# The number, printed on the back of the guernsey by the shader.
	var num := StoppageVignette.number_colour(side, number, 1.0, mirror) 			if number > 0 and facing.begins_with("back") and pm >= 30.0 else Color(0, 0, 0, 0)
	StoppageVignette.draw_frame(self, feet, info, f, k, StoppageVignette.look_colour(side, look, mirror), mirror, num, _view)


## A man standing in the play: ready, not stiff - knees bent, bouncing at a rate
## of his own (seed), looking ahead or turned to what he's watching (turn: the
## ready_turn frames look to his left; mirror for his right). low: the other stance,
## side-on and low, arms out (ready_b), so a group never stands as one.
func _ready_figure(pos: Vector2, scale: float, side: int, facing: String, seed: int, turn := false,
		mirror := false, number := 0, look: Dictionary = EXTRA_LOOK, build := BODY, low := false) -> void:
	var rate := 2.4 + 0.25 * float(seed % 5)
	var frame := int(_t * rate + seed * 0.61) % 3
	var anim := "ready_b" if low else ("ready_turn" if turn else "ready")
	_figure(pos, scale, side, anim, facing, frame, number, look, Vector2.INF, mirror, build)


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
