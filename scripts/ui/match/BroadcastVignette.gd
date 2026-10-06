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
	GOAL_LINE: 4.6,
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
var _board := {}                    # the match's score, for the big screen (if the shot sees it)
var weather := ""                   # the day's (VignetteWeather): the ground, the air, the shadows

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
## The speccy: the ball between his palms, this far under his fingertips (the leap frame's
## reach), and when he has it in to his chest.
const SPECCY_PALMS := 0.14
## He hangs at the top with it until SPECCY_DOWN, then drops, landing at SPECCY_LAND.
const SPECCY_DOWN := 1.78
const SPECCY_LAND := 2.2
const CONTEST_PEAK := 0.55
## The crumber's scale: nearer the camera than the marking contest, so a little larger
## on screen - but a small forward, not a giant (he's drawn on his own build too).
const CRUMB_SCALE := 1.08
## The crumb: the snap's boot meets the ball (the ball's flight starts) at this time.
const SNAP_AT := 2.85
## The stage the close-ups draw, in screens either side of the screen itself: wide enough
## for the camera to pan with the play (the crumber breaking into space) without running
## out of stand and turf.
const STAGE_SIDE := 1.0


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
	# The match's weather, when it has one; more players wear long sleeves in the wet.
	weather = str(result.get("weather", ""))
	_look = GameDB.figure_look(p, weather == "wet") if p is Dictionary else Appearance.UNCURATED
	_build = build_for(p if p is Dictionary else {})
	_board = {}
	if event.has("goals") and event.has("behinds") and home != "" and away != "":
		_board = {"codes": [home, away], "goals": event["goals"], "behinds": event["behinds"],
				"q": int(event.get("q", 0))}
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
	material = StoppageVignette.figure_material(_kits + [StoppageVignette.UMPIRE_GEAR], material as ShaderMaterial)


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

	if (ek == "goal" or ek == "behind") and bool(ev.get("set_shot", false)) \
			and int(ev.get("q", 0)) >= 4 and str(next_ev.get("kind", "")) == "final" \
			and _pre_score_margin(ev) <= 6:
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
	_ground = _scene_cam()
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
	VignetteWeather.draw_air(self, Rect2(Vector2.ZERO, size), _t, weather)
	_draw_letterbox()


## The drawn stage: the screen and STAGE_SIDE screens either side.
func _stage() -> Rect2:
	return Rect2(-size.x * STAGE_SIDE, 0.0, size.x * (1.0 + 2.0 * STAGE_SIDE), size.y)


# ---------------------------------------------------------------------------
# Where each scene is on the ground, in metres (VignetteGround's oval coordinates: x
# across, y towards the goals at +GOAL_Y), and the camera that shoots it: standing on
# the ground behind the play, its lens level, sized so the featured player is the size
# he's always been on screen. Everything - players, ball, posts, lines - is placed in
# metres and seen through it.
# ---------------------------------------------------------------------------
## The speccy: the marker 34 m out in front; on a flank; or from the other end.
const SPECCY_AT := {SPECCY_FRONT: Vector2(0.0, 46.0), SPECCY_SIDE: Vector2(22.0, 50.0),
		SPECCY_DEFENSIVE: Vector2(-12.0, 52.0)}
## After the siren: the mark 40 m out on a slight angle; he walks back 6 m and runs in.
const SIREN_MARK := Vector2(-7.0, 39.0)
const SIREN_RUN := 6.0
## He kicks this far behind his mark: well clear of the man standing on it.
const KICK_BEHIND := 5.0
## The crumb: the marking contest just outside the goal square, the crumber in front of
## it, gathering, then breaking away from the pack on a diagonal - left and on towards
## the goal end - to snap from 11 m on a better angle (director).
const CONTEST_AT := Vector2(2.5, 68.5)
const CRUMB_WAIT := Vector2(-0.5, 64.2)
const CRUMB_GATHER := Vector2(-1.6, 63.6)
const CRUMB_SNAP := Vector2(-5.0, 69.0)
## The boundary snap: tight in the left forward pocket, 4.5 m in from the boundary line.
const POCKET_AT := Vector2(-40.5, 60.0)
var _ground: VignetteGround.Cam
## Everyone else in the forward 50 the close-ups share, so a shot is never an empty
## field: forwards (backs to us, "F") and their opponents (facing us, "D") paired up round
## the goal square, leading up the ground and on the wings, a man still jogging back;
## the umpires ("U"): the goal umpire on the goal line, the field umpire, a boundary
## umpire on each side. [x, y, who, anim, facing, mirror]. Scenes leave out anyone
## standing where their own players are.
const EXTRAS := [
	[-5.5, 68.5, "F", "ready_turn", "back", false], [-4.0, 69.6, "D", "ready_b", "front", false],
	[7.5, 63.0, "F", "ready", "back", false], [8.8, 64.4, "D", "ready_turn", "front", true],
	[-14.0, 55.0, "F", "ready_b", "back", true], [-12.5, 56.6, "D", "ready", "front", false],
	[16.0, 48.0, "F", "ready_turn", "back", true], [17.6, 49.6, "D", "ready_b", "front", true],
	[3.0, 54.0, "D", "ready_turn", "front", false], [-22.0, 42.0, "D", "ready", "front", true],
	[25.0, 58.0, "D", "ready_turn", "front", true], [26.5, 57.0, "F", "ready", "back", false],
	[-27.0, 66.0, "F", "ready_turn", "back", false], [-9.0, 40.0, "F", "jog", "front", false],
	[0.0, 80.0, "U", "ready", "front", false], [10.0, 43.0, "U", "ready_b", "front", true],
	[-49.0, 50.0, "U", "ready", "front", true], [49.0, 50.0, "U", "ready", "front", false],
]


## The extras, farthest first, leaving room round the scene's own players (keep).
func _draw_extras(keep: Array) -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var list := []
	for i in range(EXTRAS.size()):
		var e: Array = EXTRAS[i]
		var p := Vector2(e[0], e[1])
		if str(e[2]) == "U" and i == 14:
			p = Vector2(0.0, VignetteGround.GOAL_Y + 0.4)            # on the goal line
		var clear := true
		for k in keep:
			clear = clear and p.distance_to(k) > 2.8
		var l := _ground.local(p)
		if clear and l.y > 2.0:
			list.append([l.y, p, e, i])
	list.sort_custom(func(a, b): return a[0] > b[0])
	for x in list:
		var e: Array = x[2]
		var i: int = x[3]
		var who := str(e[2])
		var kit := side if who == "F" else (1 - side if who == "D" else StoppageVignette.UMPIRE_KIT)
		var look: Dictionary = StoppageVignette.UMPIRE_LOOK if who == "U" else Appearance.generated("extra%d" % i)
		var anim := str(e[3])
		var frame := int(_t * 15.0) % 8 if anim == "jog" else int(_t * (2.4 + 0.25 * float(i % 5)) + i * 0.61) % 3
		var p: Vector2 = x[1]
		if anim == "jog":
			p += _ground.fwd * -_t * 2.5                      # jogging back towards us
		_player(p, 0.0, kit, anim, str(e[4]), frame, 0 if who == "U" else 2 + (i * 7) % 40, look, bool(e[5]))


## The featured player's spot for this kind (the camera is built round him).
func _subject() -> Vector2:
	match kind:
		SPECCY_FRONT, SPECCY_SIDE, SPECCY_DEFENSIVE:
			return SPECCY_AT[kind]
		AFTER_SIREN:
			return SIREN_MARK - _to_goal(SIREN_MARK) * (KICK_BEHIND + SIREN_RUN)
		GOAL_LINE:
			return CRUMB_GATHER
		BOUNDARY_SNAP:
			return POCKET_AT
	return Vector2(0.0, 40.0)


func _to_goal(p: Vector2) -> Vector2:
	return (Vector2(0.0, VignetteGround.GOAL_Y) - p).normalized()


func _scene_cam() -> VignetteGround.Cam:
	var subject := _subject()
	var goal := Vector2(0.0, VignetteGround.GOAL_Y)
	var target := goal
	var lens := 0.9                # focal length, screen heights
	var scale := 1.3               # the featured player's scale at his feet
	var feet := 0.73               # where his feet sit, screen heights
	var aside := 0.0               # metres the camera stands to the right of his line
	match kind:
		AFTER_SIREN:
			lens = 1.5
			scale = 1.32
			feet = 0.76
			aside = 2.5
		GOAL_LINE:
			lens = 1.5
			scale = CRUMB_SCALE
			feet = 0.80
			target = Vector2(-1.0, VignetteGround.GOAL_Y)
		BOUNDARY_SNAP:
			# From the boundary side, looking along the line towards the goals: the
			# boundary running away on his left, the posts across to the right.
			lens = 1.25
			scale = 1.28
			feet = 0.78
			target = subject.lerp(goal, 0.3)
			aside = -3.0
	var f := lens * size.y
	var depth := f / (PX_PER_M * scale)
	var dir := (target - subject).normalized()
	var at := subject - dir * depth + Vector2(dir.y, -dir.x) * aside
	var hor := size.y * 0.31
	var height := (feet * size.y - hor) * depth / f
	return VignetteGround.looking(at, height, target, f, size.x * 0.5, hor)


## A footballer at a spot on the ground (metres), lift metres in the air: draws him
## through the scene's camera at the size the camera sees him there.
func _player(p: Vector2, lift: float, side: int, anim: String, facing: String, frame: int,
		number := 0, look: Dictionary = EXTRA_LOOK, mirror := false, build := BODY) -> void:
	var s := _ground.project(p)
	if s.z <= 0.0:
		return
	var scale := s.z / PX_PER_M
	var ground := Vector2(s.x, s.y) - Vector2(0, 38.0 * scale)
	_figure(ground - Vector2(0, lift * s.z), scale, side, anim, facing, frame, number, look, ground, mirror, build)


func _ready_player(p: Vector2, side: int, facing: String, seed: int, turn := false, mirror := false,
		number := 0, look: Dictionary = EXTRA_LOOK, build := BODY, low := false) -> void:
	var rate := 2.4 + 0.25 * float(seed % 5)
	var frame := int(_t * rate + seed * 0.61) % 3
	var anim := "ready_b" if low else ("ready_turn" if turn else "ready")
	_player(p, 0.0, side, anim, facing, frame, number, look, mirror, build)


## The hip and scale of a player at a spot, lift metres up (for points on his figure, _at).
func _hip(p: Vector2, lift := 0.0) -> Array:
	var s := _ground.project(p)
	var scale := s.z / PX_PER_M
	return [Vector2(s.x, s.y) - Vector2(0, 38.0 * scale + lift * s.z), scale]


## The ball at a point in the air (metres), its size by distance.
func _ball3(p: Vector2, h: float) -> void:
	var s := _ground.project(p, h)
	if s.z > 0.0:
		_draw_ball(Vector2(s.x, s.y), s.z / 64.0, true)


## A ball's flight in metres: from a to b (each [ground point, height]) over a peak.
func _flight(a: Vector3, b: Vector3, peak: float, t: float) -> Vector3:
	var p := a.lerp(b, t)
	p.z += 4.0 * t * (1.0 - t) * (peak - maxf(a.z, b.z) * 0.5)
	return p


## Where the camera looks and how far it has zoomed, for each kind and moment: a TV
## camera on a long lens, following the play (VignetteCamera: the lens zooms, the camera
## turns; nothing changes shape).
func _camera() -> Array:
	var aim := _camera_aim()
	return [_keep_in_frame(aim[0], aim[1], _subject_box()), aim[1]]


## The featured player's box on screen now (feet to raised hands, a little either side).
func _subject_box() -> Rect2:
	var at := _subject()
	match kind:
		AFTER_SIREN:
			at = _siren_kicker()
		GOAL_LINE:
			at = _crumber_spot(_t)
		BOUNDARY_SNAP:
			at = _pocket_kicker()
	var s := _ground.project(at)
	if s.z <= 0.0:
		return Rect2()
	var up := 2.6 if kind.begins_with("speccy") else 2.0      # a leap's hands
	return Rect2(s.x - 0.6 * s.z, s.y - up * s.z, 1.2 * s.z, (up + 0.15) * s.z)


## Where the camera looks, moved as little as it takes to keep box (the featured player)
## inside the shot: within the letterbox, with a margin. He never leaves the frame.
func _keep_in_frame(on: Vector2, zoom: float, box: Rect2) -> Vector2:
	if not box.has_area():
		return on
	var z := maxf(1.0, zoom)
	var half := size * 0.5 / z
	var bar := maxf(20.0, size.y * 0.045)
	var m := Vector2(size.x * 0.06, bar + size.y * 0.03) / z
	var lo := box.end - half + m                       # the least the focus can be
	var hi := box.position + half - m                  # the most
	var x := clampf(on.x, lo.x, hi.x) if lo.x <= hi.x else box.get_center().x
	var y := clampf(on.y, lo.y, hi.y) if lo.y <= hi.y else box.get_center().y
	return Vector2(x, y)


func _camera_aim() -> Array:
	var G := VignetteCamera
	var h := size.y
	match kind:
		SPECCY_FRONT, SPECCY_SIDE, SPECCY_DEFENSIVE:
			# The pack and the ball's flight, in tight on his hands for the grab, then
			# easing back as he comes down with it.
			var m: Vector2 = _hip(SPECCY_AT[kind])[0]
			var z: float = G.glide(G.glide(1.0, 1.3, _t, 0.4, 1.45), 1.12, _t, 1.85, 2.9)
			var fy: float = G.glide(G.glide(h * 0.52, h * 0.42, _t, 0.4, 1.45), h * 0.5, _t, 1.85, 2.9)
			return [Vector2(m.x, fy), z]
		AFTER_SIREN:
			# On him lining it up, wider as he runs in, then with the ball to the posts.
			var k: Vector2 = _hip(_siren_kicker())[0]
			var posts := _ground.project(Vector2(0.0, VignetteGround.GOAL_Y), 6.0)
			var on: Vector2 = G.glide(k + Vector2(0, -h * 0.08), Vector2(posts.x, h * 0.45), _t, 2.6, 4.0)
			return [on, G.glide(G.glide(1.22, 1.1, _t, 0.6, 2.4), 1.0, _t, 2.8, 4.0)]
		GOAL_LINE:
			# The contest, then the fall of the ball, then running with the crumber as he
			# breaks into space (room ahead of him), then wide for the snap at goal.
			var c: Vector2 = _hip(_crumber_spot(_t))[0]
			var contest: Vector2 = _hip(CONTEST_AT)[0]
			var follow := Vector2(c.x - size.x * 0.1, h * 0.62)
			var on: Vector2 = G.glide(Vector2(contest.x, h * 0.5), follow, _t, 0.9, 1.6)
			var posts := _ground.project(Vector2(0.0, VignetteGround.GOAL_Y), 6.0)
			on = G.glide(on, Vector2(lerpf(c.x, posts.x, 0.5), h * 0.45), _t, SNAP_AT - 0.1, SNAP_AT + 0.8)
			var z: float = G.glide(G.glide(1.15, 1.22, _t, 0.9, 1.6), 1.0, _t, SNAP_AT - 0.1, SNAP_AT + 0.8)
			return [on, z]
		BOUNDARY_SNAP:
			# Held on the middle of his run, so he crosses the shot left to right, then
			# with the ball to the posts.
			var k: Vector2 = _hip(_pocket_kicker())[0]
			var mid: Vector2 = _hip(POCKET_AT + _pocket_heading() * 0.4)[0]
			var posts := _ground.project(Vector2(0.0, VignetteGround.GOAL_Y), 6.0)
			var on: Vector2 = G.glide(mid, Vector2(lerpf(k.x, posts.x, 0.6), h * 0.45), _t, POCKET_CONTACT - 0.1, POCKET_CONTACT + 1.2)
			return [on, G.glide(1.2, 1.0, _t, POCKET_CONTACT - 0.1, POCKET_CONTACT + 1.2)]
	return [size * 0.5, 1.0]


## The ground itself (VignetteGround): stands, fence, the oval and its markings, and the
## goals at this end.
func _draw_stadium() -> void:
	VignetteGround.draw_ground(self, _ground, _stage(), _colours, 11, _board, weather, _t)
	var pad: Color = (_colours[0] as Array)[0] if not (_colours[0] as Array).is_empty() else Color(0.7, 0.7, 0.72)
	VignetteGround.draw_goals(self, _ground, 1, pad)


func _draw_letterbox() -> void:
	var bar := maxf(20.0, size.y * 0.045)
	draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.96), true)
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.96), true)


# ---------------------------------------------------------------------------
# The speccy
# ---------------------------------------------------------------------------
func _draw_speccy() -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	var m: Vector2 = SPECCY_AT[kind]
	var fwd := _ground.fwd
	var right := Vector2(fwd.y, -fwd.x)
	var jump_t := clampf((_t - 0.42) / 1.75, 0.0, 1.0)
	var lift := 0.0                                   # metres
	if jump_t < 0.62:
		lift = ease(jump_t / 0.62, -2.0) * SPECCY_PEAK
	else:
		lift = SPECCY_PEAK
	if _t > SPECCY_DOWN:
		# Then straight down under gravity, square to us, and onto his feet.
		var u := clampf((_t - SPECCY_DOWN) / (SPECCY_LAND - SPECCY_DOWN), 0.0, 1.0)
		lift = SPECCY_PEAK * (1.0 - u * u)

	# The pack: everyone faces the ball coming in, so their backs are to us, just upfield
	# of the marker. Each contests his own way: the man he climbs goes up with both
	# hands; one punches with a fist (a spoil); one stays down, body-on, bracing.
	var pack := [
		{"at": m + fwd * 1.0 + right * 0.12, "how": "leap", "delay": 0.0, "lift": 0.45},
		{"at": m + fwd * 0.6 - right * 0.75, "how": "tap_b", "delay": 0.12, "lift": 0.3},
		{"at": m + fwd * 1.6 + right * 0.72, "how": "ready_turn", "delay": 0.0, "lift": 0.0},
	]
	_draw_extras([m, pack[0]["at"], pack[1]["at"], pack[2]["at"]])
	for i in range(2 if kind == SPECCY_DEFENSIVE else 3):
		var p: Dictionary = pack[i]
		var k := clampf((_t - 0.42 - float(p["delay"])) / 0.9, 0.0, 1.0)
		var up := sin(k * PI) * float(p["lift"]) * SPECCY_PEAK
		if str(p["how"]) == "ready_turn" or k <= 0.0 or k >= 1.0:
			# Waiting on it, holding his ground body-on, or back down after the contest:
			# watching the ball, his own rhythm (not frozen with his hands up).
			_ready_player(p["at"], other, "back", 13 + i * 5, i == 2, i == 2)
		else:
			var frames := 6 if str(p["how"]) == "leap" else 4
			_player(p["at"], up, other, str(p["how"]), "back", mini(frames - 1, int(k * frames * 1.4)),
					0, EXTRA_LOOK, i == 1)

	# The marker, back to us so his number shows, comes over the pack from behind
	# (drawn last, nearest): crouch on the turf, spring, arms up for the ball and the
	# knee in a back, then down with it held to his chest.
	var num := int(event.get("num", 0))
	var leap_frame := 0
	if _t >= 0.42:
		if jump_t < 0.08:
			leap_frame = 1                                         # the take-off crouch
		else:
			leap_frame = 2 + int(roundf(clampf((jump_t - 0.08) / 0.4, 0.0, 1.0) * 3.0))
		if _t > SPECCY_DOWN:
			leap_frame = 4                                         # both hands still on it
		# Bringing it in to his chest as he lands, then the landing crouch, then up out
		# of it: square to us the whole way, the ball held in front of him (director: not
		# landing on an angle as if he's about to run off).
		if _t > SPECCY_LAND - 0.12:
			leap_frame = 1
		if _t > SPECCY_LAND and _t < SPECCY_LAND + 0.35:
			leap_frame = 0
	var held_in := _t > SPECCY_LAND - 0.12
	# The ball comes down out of the night at a kick's pace (no easing to a stop above
	# him) into his hands - between his palms, a hand's width under his fingertips (the
	# frame's reach: the top of the figure) - and stays there. It is just beyond him all
	# the way (we're behind him), so it's drawn before him: his hands close round it and
	# his head and shoulders hide it as he brings it down to his chest (director: the ball
	# hung above his head, not caught).
	var strip := VignetteFigures.strip(_build if VignetteFigures.has(_build, "leap", "back") else BODY, "leap", "back")
	var hands_h := lift + VignetteFigures.reach(strip, leap_frame) - SPECCY_PALMS
	var held := Vector2(m.x, m.y) + fwd * 0.18
	var from := Vector3(held.x, held.y, 0.0) + Vector3(fwd.x, fwd.y, 0.0) * 34.0 + Vector3(0, 0, 16.0)
	var k := clampf((_t - 0.35) / 1.1, 0.0, 1.0)
	var ball := Vector3(held.x, held.y, hands_h)
	if _t < 1.45:
		ball = from.lerp(ball, k)
	if held_in:
		ball = Vector3(held.x, held.y, lift + (0.85 if leap_frame == 0 else 1.0))   # at his chest: hidden by him
	_ball3(Vector2(ball.x, ball.y), ball.z)
	_player(m, lift, side, "leap", "back", leap_frame, num, _look, false, _build)


# ---------------------------------------------------------------------------
# After the siren
# ---------------------------------------------------------------------------
## The kicker: he kicks from a couple of metres behind his mark (the man on the mark
## stands on it), having walked back SIREN_RUN further to start his run.
func _siren_kicker() -> Vector2:
	var run := clampf((minf(_t, KICK_START) - 1.75) / 1.45, 0.0, 1.0)
	var d := _to_goal(SIREN_MARK)
	return SIREN_MARK - d * (KICK_BEHIND + SIREN_RUN * (1.0 - ease(run, -1.5)))


func _draw_after_siren() -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var at := _siren_kicker()
	var hip: Array = _hip(at)
	var kicker: Vector2 = hip[0]
	var scale: float = hip[1]
	var boot := _at(kicker, scale, KICK_BOOT)
	# The man on the mark: an opponent where the mark was taken, facing the kicker, arms
	# out to make himself big.
	var mark := SIREN_MARK
	_draw_extras([SIREN_MARK, mark, at])
	_ready_player(mark, 1 - side, "front", 17, false, false, 0, Appearance.generated("onthemark"), BODY, true)
	# Square behind the ball lining up the goal, then the run in, away from us towards
	# the posts, and the drop punt. He plants for the kick, so he stops where it starts.
	if _t < 2.92:
		# Held at the waist in front of him (so behind him from here, peeking out).
		var bob := sin(_t * 8.0) * 2.5 if _t < 1.5 else 0.0
		_draw_ball(_at(kicker, scale, Vector2(0.06, 0.95)) + Vector2(0, bob), scale * 0.9)   # in front of him: hidden by him
	if _t < 1.75:
		_ready_player(at, side, "back", 3, false, false, num, _look, _build)
	elif _t < KICK_START:
		_player(at, 0.0, side, "jog", "back_r", _stride(_t - 1.75), num, _look, false, _build)
	elif _t < 3.45:
		_player(at, 0.0, side, "kick", "back_r", _kick_frame(_t - KICK_START, 3.02 - KICK_START), num, _look, false, _build)
	else:
		_ready_player(at, side, "back", 3, false, false, num, _look, _build)     # leg down, watching it go
	if _t >= 2.92 and _t < 3.02:
		_draw_ball(_at(kicker, scale, Vector2(0.06, 0.95)).lerp(boot, (_t - 2.92) / 0.1), scale * 0.9)
	elif _t >= 3.02:
		var flight := clampf((_t - 3.02) / 1.85, 0.0, 1.0)
		var goal := str(event.get("kind", "")) == "goal"
		var start := Vector3(at.x, at.y, 0.7) + Vector3(_ground.fwd.x, _ground.fwd.y, 0.0) * 0.6
		var end := Vector3(0.0 if goal else 4.8, VignetteGround.GOAL_Y + 1.0, 7.0)
		_ball_flight(boot, start, end, 18.0, flight)


## A kicked ball: from the boot on screen into its flight in metres, the first moments
## blended from the boot so it leaves the foot exactly.
func _ball_flight(boot: Vector2, start: Vector3, end: Vector3, peak: float, t: float) -> void:
	var p := _flight(start, end, peak, t)
	var s := _ground.project(Vector2(p.x, p.y), p.z)
	if s.z <= 0.0:
		return
	var s0 := _ground.project(Vector2(start.x, start.y), start.z)
	var fix := (boot - Vector2(s0.x, s0.y)) * pow(1.0 - minf(t * 4.0, 1.0), 2.0)
	_draw_ball(Vector2(s.x, s.y) + fix, s.z / 64.0, true)


# ---------------------------------------------------------------------------
# The crumb, as MatchSim plays it: a marking contest in front of goal, the spoil spills
# to the ground, the small forward gathers at the fall of the ball and breaks away from
# the pack into space, and snaps. The ball goes between the goal posts for a goal,
# between a goal post and a behind post for a behind.
# ---------------------------------------------------------------------------
func _draw_goal_line() -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	var fwd := _ground.fwd
	var right := Vector2(fwd.y, -fwd.x)

	# The contest: the defender goes up to mark it, facing us; our forward comes from
	# behind him, flies and punches it on, forward, into his crumber's path (director).
	var rise := clampf(_t / 0.85, 0.0, 1.0)
	var fall := clampf((_t - 0.95) / 0.45, 0.0, 1.0)
	var lift := (ease(rise, -2.0) - ease(fall, 2.0)) * CONTEST_PEAK
	var contest := int(roundf(rise * 5.0)) if fall <= 0.0 else int(roundf((1.0 - fall) * 4.0))
	var landed := fall >= 1.0 and _t > 1.55      # back on their feet, standing
	var def_at := CONTEST_AT
	# The forward: running in from the goal side, then up from behind the defender's back.
	var fly_from := CONTEST_AT + fwd * 4.2 + right * 0.9
	var fly_at := CONTEST_AT + fwd * 0.7 + right * 0.35
	var run_in := clampf(_t / 0.55, 0.0, 1.0)
	var fwd_at := fly_from.lerp(fly_at, run_in)
	var punch_rise := clampf((_t - 0.5) / 0.4, 0.0, 1.0)
	var punch_lift := (ease(punch_rise, -2.0) - ease(fall, 2.0)) * CONTEST_PEAK * 1.25
	_draw_extras([CONTEST_AT, CRUMB_WAIT, CRUMB_GATHER, CRUMB_SNAP, CONTEST_AT + right * 2.6 - fwd * 1.2,
			CRUMB_SNAP.lerp(CONTEST_AT, 0.5), fly_from])
	# Once down they turn to the crumb, off to the screen's left (both facing us now: to
	# their right).
	if landed:
		_ready_player(fwd_at, side, "front", 5, true, true)
		_ready_player(def_at, other, "front", 9, true, true)
	else:
		if _t < 0.5:
			_player(fwd_at, 0.0, side, "jog", "front", int(_t * 15.0) % 8)
		else:
			_player(fwd_at, maxf(0.0, punch_lift), side, "tap_b", "front", mini(3, int(punch_rise * 4.0)))
		_player(def_at, lift, other, "leap", "front", contest)

	# A third defender, off the contest, reads the spill and chases the crumber across
	# (heading left like him, a step behind), diving at his kick and missing.
	var chase_from := CONTEST_AT + right * 2.6 - fwd * 1.2
	var chase_to := CRUMB_SNAP + right * 2.0 + fwd * 0.6
	var chase := clampf((_t - 1.55) / (SNAP_AT - 0.3 - 1.55), 0.0, 1.0)
	var dive := clampf((_t - (SNAP_AT - 0.3)) / 0.45, 0.0, 1.0)
	var chaser := chase_from.lerp(chase_to, chase).lerp(CRUMB_SNAP + right * 0.9 + fwd * 0.4, dive)
	if _t < 1.55:
		_ready_player(chaser, other, "front", 2, true, true)      # eyes on the fall of the ball
	elif dive <= 0.0:
		_player(chaser, 0.0, other, "jog", "side_l", int((_t - 1.55) * 15.0) % 8)
	elif _t < SNAP_AT + 0.5:
		_player(chaser, 0.0, other, "lunge", "side_l", mini(2, int(dive * 3.0)))
	else:
		_ready_player(chaser, other, "front", 2, false, true)

	# The crumber reads the contest, low and side-on, swoops on the fall of the ball,
	# then breaks away from the pack into space - diagonally, left and on towards the
	# goal end - and snaps around his body at goal.
	var num := int(event.get("num", 0))
	var at := _crumber_spot(_t)
	var run_at := 1.65
	var snap_from := SNAP_AT - 0.12
	if _t < 1.35:
		_ready_player(at, side, "back", 4, true, true, num, _look, _build, true)
	elif _t < run_at:
		# Down over the ball as it reaches him, up with it into the chest.
		var g := 0 if _t < 1.45 else (1 if _t < 1.56 else 2)
		_player(at, 0.0, side, "gather", "back_r", g, num, _look, true, _build)
	elif _t < snap_from:
		# Away from us and to the left: three-quarters from behind, heading left.
		_player(at, 0.0, side, "jog", "back_r", int((_t - run_at) * 15.0) % 8, num, _look, true, _build)
	elif _t < SNAP_AT + 0.45:
		# Snapped around the body: the boot meets the ball at SNAP_AT.
		_player(at, 0.0, side, "snap", "back_r", mini(4, int((_t - snap_from) / 0.04)), num, _look, true, _build)
	else:
		_ready_player(at, side, "back", 4, true, true, num, _look, _build)     # watching it go

	var hip: Array = _hip(at)
	var crumber: Vector2 = hip[0]
	var scale: float = hip[1]
	var hands := _at(crumber, scale, Vector2(-0.3, 1.0))
	var boot := _at(crumber, scale, Vector2(-SNAP_BOOT.x, SNAP_BOOT.y))     # snapping heading left: mirrored
	var deck := CRUMB_GATHER - right * 0.34
	# Kicked in from upfield (over the camera) to the contest, where the fist meets it.
	var hit := CONTEST_AT + fwd * 0.4
	var top := Vector3(hit.x, hit.y, CONTEST_PEAK * 1.25 + 2.4)
	if _t < 0.95:
		var k := clampf(_t / 0.95, 0.0, 1.0)
		var p := Vector3(top.x, top.y - 14.0, 14.0).lerp(top, k)
		_ball3(Vector2(p.x, p.y), p.z)
		return
	if _t < 1.45:
		# Off the spoil, forward off the pack, one bounce, into the crumber's path.
		var u := clampf((_t - 0.95) / 0.5, 0.0, 1.0)
		var bounce := Vector3(lerpf(top.x, deck.x, 0.6), lerpf(top.y, deck.y, 0.6), 0.0)
		var p := _flight(top, bounce, 3.0, minf(u / 0.7, 1.0)) if u < 0.7 \
				else _flight(bounce, Vector3(deck.x, deck.y, 0.15), 0.6, (u - 0.7) / 0.3)
		_ball3(Vector2(p.x, p.y), p.z)
		return
	if _t < SNAP_AT:
		# Gathered into the hands, carried, then dropped onto the boot.
		var d := _ground.project(deck, 0.15)
		var up := clampf((_t - 1.45) / 0.15, 0.0, 1.0)
		var drop := clampf((_t - (SNAP_AT - 0.08)) / 0.08, 0.0, 1.0)
		_draw_ball(Vector2(d.x, d.y).lerp(hands, up).lerp(boot, drop), scale * 0.9)
		return
	var flight := clampf((_t - SNAP_AT) / 1.15, 0.0, 1.0)
	var goal := str(event.get("kind", "")) == "goal"
	# Curling back from his left to the target, rising then dropping into it.
	var end := Vector3(0.0 if goal else -4.8, VignetteGround.GOAL_Y + 1.0, 6.0)
	_ball_flight(boot, Vector3(at.x, at.y, 0.6), end, 9.0, flight)


## Where the crumber is at time t: waiting just in front of the contest, a step to the
## fall of the ball, then away from the congestion to his left, into space, at a small
## forward's pace (matched to his stride, so his feet don't slide).
func _crumber_spot(t: float) -> Vector2:
	var p := CRUMB_WAIT.lerp(CRUMB_GATHER, smoothstep(0.9, 1.4, t))
	var run := clampf((t - 1.65) / (SNAP_AT - 0.12 - 1.65), 0.0, 1.0)
	p = p.lerp(CRUMB_SNAP, run)
	var on := clampf((t - (SNAP_AT - 0.12)) / 0.3, 0.0, 1.0)     # carried on through the kick
	return p + (CRUMB_SNAP - CRUMB_GATHER).normalized() * 0.6 * on


# ---------------------------------------------------------------------------
# The snap from the boundary
# ---------------------------------------------------------------------------
## The boundary snap's run: across the shot, left to right and a little away (infield, to
## open the angle), from RUN_FROM to RUN_TO seconds, carrying on a stride into the snap.
const POCKET_RUN := [0.35, 1.1]
## The snap's boot meets the ball (frame 3, a frame every 0.1 s from the run's end).
const POCKET_CONTACT := 1.4


## Screen-right on the ground for the scene's camera, turned a little away from it.
func _pocket_heading() -> Vector2:
	var goal := Vector2(0.0, VignetteGround.GOAL_Y)
	var dir := (POCKET_AT.lerp(goal, 0.3) - POCKET_AT).normalized()
	return (Vector2(dir.y, -dir.x) + dir * 0.3).normalized()


## The defenders waiting on his kick, clear of the protected area (director): that is
## the corridor from the mark to him, 5 m either side, and 5 m round each end. He took
## the mark at POCKET_MARK and stepped back from it; they stand off beyond it, goal-side,
## on his angle to the posts - one a little infield, one deeper, near the goal square -
## shuffle in as he runs and stop at the area's edge. Their pressure is what gets to his
## kick: on a miss they've come right up to that edge.
const POCKET_MARK := 2.0        # metres goal-side of POCKET_AT
const PROTECT := 5.0

func _pocket_defenders() -> Array:
	var goal := Vector2(0.0, VignetteGround.GOAL_Y)
	var k := _pocket_kicker()
	var to_goal := (goal - POCKET_AT).normalized()
	var infield := Vector2(to_goal.y, -to_goal.x)
	if infield.x < 0.0:
		infield = -infield
	var mark := POCKET_AT + to_goal * POCKET_MARK
	var miss := str(event.get("kind", "")) != "goal"
	var close := clampf((_t - 0.2) / (POCKET_CONTACT - 0.2), 0.0, 1.0)
	close = close * close * (3.0 - 2.0 * close) * (1.0 if miss else 0.55)
	var out := []
	for spot in [POCKET_AT + to_goal * 11.0 + infield * 3.5, POCKET_AT + to_goal * 18.0 + infield * 0.3]:
		var p: Vector2 = spot
		p = p + (k - p).normalized() * 3.0 * close
		# Never inside the area: at least PROTECT + 0.6 from the mark-to-him corridor.
		var seg := Geometry2D.get_closest_point_to_segment(p, k, mark)
		if p.distance_to(seg) < PROTECT + 0.6:
			p = seg + (p - seg).normalized() * (PROTECT + 0.6)
		out.append(p)
	return out


func _draw_pressure(press: Array, side: int) -> void:
	var opp := 1 - side
	var miss := str(event.get("kind", "")) != "goal"
	for i in range(2):
		var p: Vector2 = press[i]
		var shuffling := _t > 0.2 and _t < POCKET_CONTACT - 0.15
		if i == 0 and _t >= POCKET_CONTACT - 0.15 and _t < POCKET_CONTACT + 0.45:
			# Up at it: arms high to put him off (higher and nearer on a miss).
			var u := clampf((_t - (POCKET_CONTACT - 0.15)) / 0.6, 0.0, 1.0)
			var lift := sin(u * PI) * (0.35 if miss else 0.2)
			_player(p, lift, opp, "leap", "front", 2 + mini(3, int(u * 6.0)), 0, Appearance.generated("pocket_d%d" % i), false)
		elif shuffling:
			_player(p, 0.0, opp, "jog", "front", int(_t * 11.0 + i * 3) % 8, 0, Appearance.generated("pocket_d%d" % i), i == 1)
		else:
			_ready_player(p, opp, "front", 21 + i * 4, i == 1, i == 1, 0, Appearance.generated("pocket_d%d" % i), BODY, i == 0)


func _pocket_kicker() -> Vector2:
	var head := _pocket_heading()
	var run := clampf((_t - POCKET_RUN[0]) / (POCKET_RUN[1] - POCKET_RUN[0]), 0.0, 1.0)
	var on := clampf((_t - POCKET_RUN[1]) / 0.35, 0.0, 1.0)
	# Three steps or so (director): gets going, runs through, carries on into the kick.
	var d := -1.2 + 2.2 * (run * run * (1.5 - 0.5 * run)) + 0.4 * on * (2.0 - on)
	return POCKET_AT + head * d


func _draw_boundary_snap() -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var num := int(event.get("num", 0))
	var at := _pocket_kicker()
	var hip: Array = _hip(at)
	var kicker: Vector2 = hip[0]
	var scale: float = hip[1]
	var boot := _at(kicker, scale, SNAP_BOOT)
	var held := _at(kicker, scale, Vector2(0.06, 0.95))     # in front of him: hidden by him
	var carried := _at(kicker, scale, Vector2(0.2, 1.08))   # side-on: in his hands in front of him
	var snap_from := POCKET_CONTACT - 0.3
	var press := _pocket_defenders()
	_draw_extras([POCKET_AT, at, press[0], press[1]])
	_draw_pressure(press, side)
	# Drawn before him: held into his body, the ball only shows past it.
	if _t < POCKET_RUN[0]:
		_draw_ball(held, scale * 0.9)
	elif _t >= snap_from and _t < POCKET_CONTACT - 0.1:
		_draw_ball(held, scale * 0.9)
	# Steadying, then a run across the shot, left to right (side-on, heading right:
	# the left-heading frames mirrored), then he turns in and snaps around his body.
	if _t < POCKET_RUN[0]:
		_ready_player(at, side, "back", 6, false, false, num, _look, _build)
	elif _t < snap_from:
		_player(at, 0.0, side, "jog", "side_l", int((_t - POCKET_RUN[0]) * 15.0) % 8, num, _look, true, _build)
	elif _t < snap_from + 0.8:
		_player(at, 0.0, side, "snap", "back_r", mini(4, int((_t - snap_from) / 0.1)), num, _look, false, _build)
	else:
		_ready_player(at, side, "back", 6, false, false, num, _look, _build)     # landed, watching it
	if _t >= POCKET_RUN[0] and _t < snap_from:
		# Running with it: carried in front of his chest, in plain sight (director).
		_draw_ball(carried + Vector2(0, sin(_t * 23.0) * 1.5 * scale), scale * 0.9)
	if _t >= POCKET_CONTACT - 0.1 and _t < POCKET_CONTACT:
		_draw_ball(held.lerp(boot, (_t - (POCKET_CONTACT - 0.1)) / 0.1), scale * 0.9)      # dropped onto the boot
	elif _t >= POCKET_CONTACT:
		var flight := clampf((_t - POCKET_CONTACT) / 1.85, 0.0, 1.0)
		var goal := str(event.get("kind", "")) == "goal"
		var end := Vector3(0.0 if goal else -4.8, VignetteGround.GOAL_Y + 1.0, 7.0)
		_ball_flight(boot, Vector3(at.x + 0.6, at.y, 0.6), end, 16.0, flight)


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
	draw_circle(Vector2.ZERO, 0.4 * pm, Color(0, 0, 0, VignetteWeather.shadow_alpha(weather)))
	draw_set_transform_matrix(_view)
	var info := VignetteFigures.strip(build, anim, facing)
	var f := StoppageVignette.figure_frame(info, frame, anim, facing)
	var k := pm / VignetteFigures.PX_PER_M
	# The number, printed on the back of the guernsey by the shader.
	var num := StoppageVignette.number_colour(side, number, 1.0, mirror) 			if number > 0 and facing.begins_with("back") and pm >= 30.0 else Color(0, 0, 0, 0)
	StoppageVignette.draw_frame(self, feet, info, f, k, StoppageVignette.look_colour(side, look, mirror), mirror, num, _view,
			str(look.get("hair_style", VignetteFigures.HAIR_BASE)))


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


## The ball (VignetteBall, the Sherrin) at pos, at a figure's scale; spinning in flight,
## held or carried it doesn't.
func _draw_ball(pos: Vector2, scale: float, spinning := false) -> void:
	VignetteBall.draw(self, pos, 18.0 * scale, _t, spinning)


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t
