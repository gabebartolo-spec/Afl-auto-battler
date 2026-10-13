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
	SPECCY_FRONT: 2.5,    # (round 15: the mark at 1.5 s, then the picture holds on it)
	SPECCY_SIDE: 2.5,
	SPECCY_DEFENSIVE: 2.6,
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
## contact frame (3) of the figures' kick and snap. The kick's is the ball sitting on the
## laces of the drop punt's pointed foot, about 40 cm up (measured off the pose with
## ard-asset-pipeline's tools/blender/pose_probe.py); the snap's off the rendered frames.
const KICK_BOOT := Vector2(0.49, 0.54)
const SNAP_BOOT := Vector2(0.62, 0.63)
## Heights in metres, so a leap is a footballer's leap on any screen: a speccy's
## knees in the pack's backs, a one-on-one contest.
## His height at the top comes from the climb: the speccy knee (~0.53 m above his lowest boot,
## pose_probe) resting on the braced man's upper back (~1.2 m, the brace move) - 0.7 m by the
## numbers; 1.0 m measured on screen (at 0.7 the knee landed on his lower back, round 8b crop);
## 1.2 m in round 9 so his hips clear the braced man's head (the knee now sits below the hips).
const SPECCY_PEAK := 1.03   # (round 12: his hips sit on the braced man's shoulders, not a head above)
## Where the braced man stands relative to the marker's spot at the top: x to the marker's right, y
## upfield (metres). Round 13: square from behind and 0.3 m to the right, so his left shoulder is under
## the marker's right thigh and his head, turned up to the ball, is beside the marker's hip, not under
## it (fitted with the two posed together in 3D).
const SPECCY_KNEE := Vector2(0.38, -0.05)   # (round 14: 0.30 pressed his face into the marker's shorts)
## The marker's run at the pack (round 14): metres he covers in his strides before he plants and
## crouches (he used to wait on the spot and slide in), and the time he plants, just before take-off.
const SPECCY_RUN := 1.7
const SPECCY_PLANT := 0.84
## The marker waits and takes off this far behind that spot (nearer us, metres) and his leap carries
## him on to the man (round 13: standing level, the braced man was nearer us but drawn behind him).
const SPECCY_RUNUP := 0.6
## At the top of the speccy the marker's right thigh lies across the braced man's left shoulder and
## his shin hangs down in front of the man's chest, so from behind the man's back hides it. The
## braced man is drawn under the marker, so his figure below this height (metres on screen above his
## boots: his shoulder line) is drawn again over the marker while the thigh is on the shoulder.
const SPECCY_COVER := 1.53
## Metres the marker slides to his left off the braced man's shoulder as he comes down (round 12).
const SPECCY_SLIDE := 0.3
## The top pose, with the cover, holds while he is at least this share of the peak (round 13); then
## his right leg swings off the shoulder to his own side over three frames.
const SPECCY_HOLD := 0.9
## The braced man's facing: square from behind (round 13: his face turned up to the ball reads in
## profile; turned to his right, as round 12, it read as the back of his head).
const BRACE_FACING := "back"
## A man carried on another casts no shadow of his own: the pack's is the one anchor.
var _no_shadow := false
## The speccy: the ball between his palms, this far under his fingertips (the leap frame's
## reach), and when he has it in to his chest.
const SPECCY_PALMS := 0.14
## He hangs at the top with it until SPECCY_DOWN, then drops, landing at SPECCY_LAND.
## Off the turf at SPECCY_UP, at the top (the ball arriving) at SPECCY_TOP, starting down at
## SPECCY_DOWN, on the turf at SPECCY_LAND: about 0.9 s in the air, like a real speccy.
const SPECCY_UP := 0.95
const SPECCY_TOP := 1.42
const SPECCY_DOWN := 1.5
const SPECCY_LAND := 1.85
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
	# The speccy from the front freezes on the grab like a replay still (round 15): the scene's clock
	# stops at SF_FREEZE and only the lens keeps moving (_hold: seconds into the still).
	var real_t := _t
	_hold = 0.0
	if kind == SPECCY_FRONT and _sf_ready():
		_hold = maxf(0.0, _t - SF_FREEZE)
		_t = minf(_t, SF_FREEZE)
	_ground = _scene_cam()
	var cam := _camera()
	_view = VignetteCamera.view(size, cam[0] + VignetteCamera.breathe(_t, size), cam[1], _stage())
	draw_set_transform_matrix(_view)
	_draw_stadium()
	match kind:
		SPECCY_FRONT, SPECCY_SIDE, SPECCY_DEFENSIVE:
			if kind == SPECCY_FRONT and _sf_ready():
				_draw_speccy_front()
			else:
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
	_t = real_t


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
	var low_hor := -1.0            # the horizon's screen y for a camera that isn't up in the stand
	match kind:
		SPECCY_FRONT:
			if _sf_ready():
				# Low and tight from the ball's side (round 15): a camera at knee height on a long lens,
				# the pack from the thighs up across the frame, the goals and the stand behind them.
				lens = SF_LENS
				scale = minf(size.x / (PX_PER_M * SF_ACROSS), size.y / (PX_PER_M * SF_TALL))
				low_hor = size.y + PX_PER_M * scale * (SF_CUT - SF_CAM_H)
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
	if low_hor >= 0.0:
		hor = low_hor
		feet = (hor + PX_PER_M * scale * SF_CAM_H) / size.y
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
	if kind == SPECCY_FRONT and _sf_ready():
		return _sf_camera()
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
			# One move, in and out, no stop-start while he comes down. The lens keeps pushing in through
			# the grab and turns as he drops to the turf (round 14: it and the tilt both turned at the
			# top, so the picture stood still for the frames of the mark).
			var z: float = G.glide(G.glide(1.0, 1.3, _t, 0.4, SPECCY_LAND - 0.1), 1.15, _t, SPECCY_LAND - 0.1, 2.6)
			var fy: float = G.glide(G.glide(h * 0.52, h * 0.42, _t, 0.4, SPECCY_TOP), h * 0.5, _t, SPECCY_TOP, 2.6)
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
	# The speccy's tight shot would cut the big screen in half ("RE" and "EL"): it is left out there.
	var board: Dictionary = {"off": true} if kind == SPECCY_FRONT and _sf_ready() else _board
	VignetteGround.draw_ground(self, _ground, _stage(), _colours, 11, board, weather, _t)
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
	# Ballistic: up to the top as the ball arrives, straight back down (a 2-3 frame apex, not a hang).
	var lift := 0.0                                   # metres
	if _t >= SPECCY_UP and _t < SPECCY_LAND:
		var u := (_t - SPECCY_TOP) / ((SPECCY_TOP - SPECCY_UP) if _t < SPECCY_TOP else (SPECCY_LAND - SPECCY_TOP))
		lift = SPECCY_PEAK * (1.0 - u * u)

	# The pack: everyone faces the ball coming in, so their backs are to us, just upfield
	# of the marker. Each contests his own way: the man he climbs goes up with both
	# hands; one punches with a fist (a spoil); one stays down, body-on, bracing.
	# The man he climbs is close in front of him (half a metre: the marker's knee goes into
	# his back) and still in the air as the marker comes over the top, so the marker is
	# carried on him, not floating over an empty space (realism pass, 2026-10-11).
	var pack := [
		# Under the marker's right thigh (round 13): the braced man stands to his right, his left
		# shoulder under the thigh at the top, his head beside the marker's hip. The marker comes from
		# nearer us (drawn last); SPECCY_COVER hides the shin that hangs in front of the man's chest.
		{"at": m + fwd * SPECCY_KNEE.y + right * SPECCY_KNEE.x, "how": "brace", "delay": 0.0, "lift": 0.0},
		# (Round 14: both are back down by the time the marker is, their arms up for a moment, not a second.)
		{"at": m + fwd * 0.6 - right * 0.75, "how": "tap_b", "delay": 0.42, "lift": 0.22, "dur": 0.9},
		# The third leans in and reaches for it too, not standing flat-footed.
		{"at": m + fwd * 1.4 + right * 0.85, "how": "leap", "delay": 0.66, "lift": 0.18, "dur": 0.68},
	]
	_draw_extras([m, pack[0]["at"], pack[1]["at"], pack[2]["at"]])
	# Far to near (we look up the ground, fwd), so a nearer man is drawn over a further one.
	var order := range(2 if kind == SPECCY_DEFENSIVE else 3)
	order.sort_custom(func(a_, b_): return (pack[a_]["at"] as Vector2).dot(fwd) > (pack[b_]["at"] as Vector2).dot(fwd))
	for i in order:
		var p: Dictionary = pack[i]
		var k := clampf((_t - 0.42 - float(p["delay"])) / float(p.get("dur", 0.9)), 0.0, 1.0)
		var up := sin(k * PI) * float(p["lift"])
		if str(p["how"]) == "brace":
			# The man he climbs (round 12, the director: near upright like the pack-mark photo, the
			# marker riding his shoulders): standing, he braces as the marker crouches to go, his right
			# arm going up (0-1-2); once the marker has landed the arm comes down (3-4), then he stands
			# up again (5, 0). Round 13: a frame between each pose, nothing popped.
			if VignetteFigures.has(BODY, "brace", BRACE_FACING):
				_player(p["at"], 0.0, other, "brace", BRACE_FACING, _brace_frame(), 0, EXTRA_LOOK, false)
			elif _t > 0.35 and _t < SPECCY_LAND + 0.1:
				_player(p["at"], 0.0, other, "tap_b", "back", 0, 0, EXTRA_LOOK, false)
			else:
				_ready_player(p["at"], other, "back", 13, true, true)     # turned to the ball
		elif k <= 0.0 or k >= 1.0:
			# Waiting on it or back down after the contest: turned towards the ball (the marker),
			# shifting his weight at his own rhythm - not square-on statues.
			_ready_player(p["at"], other, "back", 13 + i * 5, true, i == 1)
		else:
			# Up through the move and back down through it (no snap from the top frame to
			# standing when the contest is over).
			# Round 14: evenly through the frames (a sine sat on the top frame for a third of a second:
			# mannequins), and a body in the air drifts a little.
			var frames := 6 if str(p["how"]) == "leap" else 4
			var f := int(roundf((1.0 - absf(2.0 * k - 1.0)) * float(frames - 1)))
			var how := str(p["how"])
			if how == "tap_b" and VignetteFigures.has(BODY, "contest", "back"):
				how = "contest"          # the same leap with the hand open for the ball (round 12)
			var sway := right * (0.025 * sin(k * PI) * sin(_t * 7.0 + float(i) * 2.1))
			_player((p["at"] as Vector2) + sway, up, other, how, "back", f, 0, EXTRA_LOOK, i == 1)

	# The marker, back to us so his number shows, comes over the pack from behind
	# (drawn last, nearest): crouch on the turf, spring, arms up for the ball and the
	# knee in a back, then down with it held to his chest.
	var num := int(event.get("num", 0))
	# The speccy move (knee in the man's back, legs splayed) where the sheets have it.
	var anim := "speccy" if VignetteFigures.has(_build, "speccy", "back") or VignetteFigures.has(BODY, "speccy", "back") else "leap"
	var leap_frame := 0                      # crouched, ready to go
	# Round 14: he runs at the pack (three strides), plants, a short crouch (speccy frame 0), and goes.
	var standing := anim == "speccy" and _t < SPECCY_PLANT
	# The top pose holds until he has fallen to SPECCY_HOLD of the peak (lift = peak (1 - u^2)).
	var t_hold := SPECCY_TOP + sqrt(1.0 - SPECCY_HOLD) * (SPECCY_LAND - SPECCY_TOP)
	if anim == "speccy" and _t >= SPECCY_UP - 0.08:
		# 10 frames (round 13): rising 0-4 with the hands closing on the ball gradually, the top 5-6,
		# then the right leg swinging back off the man's shoulder to his own side, knee bent, 7-9.
		if _t < SPECCY_TOP - 0.07:
			leap_frame = clampi(int((_t - (SPECCY_UP - 0.08)) / (SPECCY_TOP - 0.07 - SPECCY_UP + 0.08) * 5.0), 0, 4)
		elif _t < t_hold:
			leap_frame = 5 if _t < SPECCY_TOP else 6                # the top, held
		else:
			leap_frame = 7 + clampi(int((_t - t_hold) / 0.034), 0, 2)
		if _t >= SPECCY_LAND - 0.16:
			# Down from overhead to his chest (round 14, 8 frames): in the air with the ball overhead (0),
			# it comes down in front of his face (1) to his chest, elbows by his ribs, legs reaching (2);
			# the boots meet the turf (3) and the knees give in the next two frames (4, 5: low over it);
			# then up (6, 7). He turns his shoulders to his left, so the ball shows past his side.
			anim = "speccy_land" if VignetteFigures.has(_build, "speccy_land", "back") or VignetteFigures.has(BODY, "speccy_land", "back") else "leap"
			var a2 := _t - (SPECCY_LAND - 0.16)
			leap_frame = 0 if a2 < 0.06 else (1 if a2 < 0.1 else (2 if a2 < 0.16 else (3 if a2 < 0.19 else (4 if a2 < 0.225 else (5 if a2 < 0.325 else (6 if a2 < 0.42 else 7))))))
	if anim in ["speccy", "speccy_land"] and _t >= SPECCY_TOP and _t < SPECCY_LAND:
		# Coming down, his hips fall on one arc (round 13): the frames are grounded on their lowest
		# boot, so a leg swinging down moved his body in the frame (a 30 px pop). From the hips at the
		# top to the hips of the frame that meets the turf; his boots are where that leaves them.
		var bb := _build if VignetteFigures.has(_build, "speccy", "back") else BODY
		var bl := _build if VignetteFigures.has(_build, "speccy_land", "back") else BODY
		var top_hips := VignetteFigures.hips(VignetteFigures.strip(bb, "speccy", "back"), 6)
		var cur := VignetteFigures.strip(bb if anim == "speccy" else bl, anim, "back")
		var hips := VignetteFigures.hips(cur, leap_frame)
		if top_hips > 0.0 and hips > 0.0 and VignetteFigures.has(bl, "speccy_land", "back"):
			var touch := VignetteFigures.hips(VignetteFigures.strip(bl, "speccy_land", "back"), 3)
			var u := (_t - SPECCY_TOP) / (SPECCY_LAND - SPECCY_TOP)
			var arc := SPECCY_PEAK + top_hips - (SPECCY_PEAK + top_hips - touch) * u * u
			lift = maxf(0.0, arc - hips)
	elif anim == "speccy_land":
		lift = 0.0
	var held_in := anim != "speccy_land" and _t >= SPECCY_LAND + 0.07   # at his chest (sheets without the landing)
	# The ball comes down out of the night at a kick's pace (no easing to a stop above
	# him) into his hands - between his palms, a hand's width under his fingertips (the
	# frame's reach: the top of the figure) - and stays there. It is just beyond him all
	# the way (we're behind him), so it's drawn before him: his hands close round it and
	# his head and shoulders hide it as he brings it down to his chest (director: the ball
	# hung above his head, not caught).
	var build := _build if VignetteFigures.has(_build, anim, "back") else BODY
	# Coming down (round 12) he slides off the man's shoulder to his left, away from him, so his
	# leg comes down beside the man, not down his back.
	# (Round 13: eased, from just after the top, so it is under way as his leg leaves the shoulder.)
	# Before that he waits SPECCY_RUNUP behind his spot, nearer us, and the leap carries him on to the man.
	var slide := smoothstep(SPECCY_TOP + 0.07, SPECCY_LAND, _t)
	# Round 14: the run covers SPECCY_RUN at a jog's pace up to the plant; off the turf he keeps that
	# pace and loses it into the man (a leap carries on, it doesn't ease in from a standstill).
	var air := clampf((_t - SPECCY_UP) / (SPECCY_TOP - 0.07 - SPECCY_UP), 0.0, 1.0)
	var run_in := 1.0 - (1.0 - air) * (1.0 - air)
	var run_up := clampf(_t / SPECCY_PLANT, 0.0, 1.0)
	var mm := m - right * SPECCY_SLIDE * slide - fwd * (SPECCY_RUNUP * (1.0 - run_in) + SPECCY_RUN * (1.0 - run_up))
	var held := m - right * SPECCY_SLIDE * slide + fwd * 0.18
	var from := Vector3(held.x, held.y, 0.0) + Vector3(fwd.x, fwd.y, 0.0) * 34.0 + Vector3(0, 0, 16.0)
	var k := clampf((_t - 0.35) / (SPECCY_TOP - 0.35), 0.0, 1.0)
	# In his hands from the moment it arrives until it's at his chest: between his palms in
	# the frame he shows (the sheet's per-frame palms), so it moves with them, never left
	# floating over his head.
	var la := _palm(mm, anim, "back", leap_frame, 0, build)
	var ra := _palm(mm, anim, "back", leap_frame, 1, build)
	var s0 := _ground.project(mm)
	var in_hands := Vector2.INF
	if la != Vector2.INF and ra != Vector2.INF and s0.z > 0.0:
		in_hands = (la + ra) * 0.5 - Vector2(0, lift * s0.z)
	var behind := anim == "speccy_land" and leap_frame >= 1 and in_hands != Vector2.INF
	if behind:
		# In front of his face, then at his chest (round 14): the ball is beyond his head and shoulders
		# from here, between his palms, and shows past his left side as he turns with it.
		_draw_ball(in_hands, s0.z / 64.0, false)
	elif held_in or in_hands == Vector2.INF:
		var chest := Vector3(held.x, held.y, lift + (0.85 if leap_frame == 0 else 1.0))   # at his chest: hidden by him
		_ball3(Vector2(chest.x, chest.y), chest.z)
	elif _t < SPECCY_TOP - 0.02:
		# Coming in out of the night, onto his palms as he tops out.
		var hp := _ground.project(held)
		var target_h := (hp.y - in_hands.y) / maxf(hp.z, 0.001)
		var b := from.lerp(Vector3(held.x, held.y, target_h), k)
		_ball3(Vector2(b.x, b.y), b.z)
	var in_front := false
	if not held_in and not behind and in_hands != Vector2.INF and _t >= SPECCY_TOP - 0.02:
		in_front = true          # between his palms, over his hands (drawn after him, below)
	_no_shadow = lift > 0.25          # on the man's back: the pack's shadow is the anchor
	if standing:
		var jb := _build if VignetteFigures.has(_build, "jog", "back") else BODY
		_player(mm, 0.0, side, "jog", "back", int(_t * 11.0) % 8, num, _look, false, jb)
	else:
		_player(mm, lift, side, anim, "back", leap_frame, num, _look, false, _build if VignetteFigures.has(_build, anim, "back") else BODY)
	_no_shadow = false
	# At the top (frames 4-6) his thigh is on the braced man's shoulder and his shin hangs in front of
	# the man's chest: the man's body hides it. Climbing (0-3) the knee is in his back and the shin
	# behind it, nearer us. Coming down (round 13) the cover stays until he is on the turf, so the leg
	# swinging off the shoulder (7-9) never jumps from in front of the man's chest to over his back;
	# by then he has slid to his left, beside the man (on his spot, a little beyond him).
	if not standing and ((anim == "speccy" and leap_frame >= 4) or (anim == "speccy_land" and _t < SPECCY_LAND)) \
			and VignetteFigures.has(BODY, "brace", BRACE_FACING):
		_figure_below(pack[0]["at"], other, "brace", BRACE_FACING, _brace_frame(), SPECCY_COVER)
	if in_front:
		_draw_ball(in_hands, s0.z / 64.0, false)


# ---------------------------------------------------------------------------
# The speccy from the front (round 15, the director's restaging, 2026-10-13): the camera is on the
# ball's side, at knee height and tight on the pack; the marker comes from BEHIND the pack, climbs
# the man in front of him - his knee on the man's shoulder, beside his head - and takes it above
# them; the picture freezes on the grab like a replay still. The pack's bodies hide his run-in legs,
# the frame hides every boot, and nothing after the grab is shown.
# ---------------------------------------------------------------------------
const SF_LENS := 2.2             # focal length, screen heights (a long lens: 10 m back)
const SF_ACROSS := 2.1           # metres of the pack across the screen
const SF_TALL := 3.6             # at least this much of the scene top to bottom (a wide screen)
const SF_CUT := 0.55             # the bottom of the frame cuts the pack this far above the turf
const SF_CAM_H := 0.75           # the camera's height
const SF_PLANT := 1.0            # he plants behind the man and loads
const SF_SPRING := 1.10         # (pass c: the loaded plant held three frames)
const SF_SINK := 0.20            # the spring frame starts this much lower and rises into the jump (no pop)
const SF_UP := 1.17              # off the turf
const SF_CONTACT := 1.48         # his knee on the man's shoulder
const SF_CATCH := 1.50           # the ball in his hands
const SF_FREEZE := 1.66          # the picture holds from here
const SF_PUSH := 0.035           # how far the lens creeps in on the still
const SF_RUN := Vector2(-1.95, 8.0)       # where his run starts: left of and beyond the man, metres
const SF_GAP := Vector2(-1.0, 3.4)       # he comes at the gap on the man's right (our left of him)
const SF_PLANT_AT := Vector2(-0.36, 0.95)   # in that gap, where we see him load and spring
const SF_BEHIND := 0.32          # at the top he is this far beyond the man
const SF_IN := 0.04              # the knee sits this far in from the shoulder joint, on the trapezius
const SF_PAD := 0.14             # his knee joint above the man's shoulder joint (thigh on shoulder)
## The braced man's right shoulder joint in each brace_f frame and the marker's right knee joint in each
## mark_f frame: metres right of and above the strip's feet (measured in Blender on the poses the strips
## were rendered from: ard-asset-pipeline poses.brace_f / mark_f, level camera). The knee is pinned to
## the shoulder from SF_CONTACT, so it rides the man as he buckles and can never float.
const SF_SHOULDER := [Vector2(-0.217, 1.510), Vector2(-0.197, 1.519), Vector2(-0.234, 1.499), Vector2(-0.219, 1.497), Vector2(-0.216, 1.556),
		Vector2(-0.212, 1.595), Vector2(-0.205, 1.558), Vector2(-0.200, 1.488), Vector2(-0.199, 1.427), Vector2(-0.198, 1.367)]
const SF_KNEE := [Vector2(-0.108, 0.556), Vector2(-0.112, 0.583), Vector2(-0.148, 0.858),
		Vector2(-0.089, 0.865), Vector2(-0.069, 0.799), Vector2(-0.066, 0.767), Vector2(-0.066, 0.754)]
## Players further back in the shot (it is never three men on an empty ground): [right, beyond, who
## ("F" his side, "D" theirs, "U" umpire), anim, mirror].
const SF_BACK := [[-2.3, 9.0, "D", "ready_turn", false], [2.6, 12.0, "F", "jog", false],
		[-4.5, 24.0, "U", "ready", false]]
const SF_HELD := 3                # the ball's frame in his hands: upright, its top tipped to our left
var _hold := 0.0


## Whether the sheets hold the front-on moves (a sheet without them plays the old staging).
static func _sf_ready() -> bool:
	return VignetteFigures.has(BODY, "mark_f", "front") and VignetteFigures.has(BODY, "brace_f", "front")


func _sf_camera() -> Array:
	var G := VignetteCamera
	# The lens eases in a touch as the ball comes, towards his hands, and keeps creeping on the still.
	var dur := duration_for(kind)
	var k := clampf(_hold / maxf(0.01, dur - SF_FREEZE), 0.0, 1.0)
	# (Pass d: the creep on the still starts from rest and is small; it began at full speed and lurched.)
	var z: float = G.glide(1.0, 1.04, _t, 0.3, SF_CATCH) + SF_PUSH * k * k * (3.0 - 2.0 * k)
	var grab := _ground.project(SPECCY_AT[kind], 2.5)
	var on: Vector2 = G.glide(size * 0.5, Vector2(grab.x, grab.y), _t, 0.3, SF_CATCH)
	return [on, z]


## The man he climbs at t: [frame, metres right, metres beyond his spot, metres off the turf]. He is
## going for it himself: watching it in, backing under it, arms up and off his toes as it arrives;
## then the marker's knee lands on his shoulder and he buckles and is shunted forward.
func _sf_brace(t: float) -> Array:
	# Watching it in and shifting his weight (0-2), setting himself (3), arms going up (4), reaching (5);
	# from the knee landing, a frame at a time: buckling (6, 7) and folding under him (8, 9).
	var f := (int(t * 4.6) % 3) if t < 0.85 else (3 if t < 1.02 else (4 if t < 1.14 else 5))
	# (Pass c: he buckles from two frames AFTER the knee lands, not as it arrives.)
	# (Pass d: his arms start down as the knee lands and take four poses over eight frames.)
	if t >= SF_CONTACT:
		f = 6 + clampi(int((t - SF_CONTACT) / 0.067), 0, 3)
	var back := 0.34 * smoothstep(0.05, 1.15, t) - 0.10 * smoothstep(SF_CONTACT, SF_FREEZE, t)
	var hop := 0.10 * sin(PI * clampf((t - 1.18) / 0.55, 0.0, 1.0)) * (1.0 - smoothstep(SF_CONTACT, SF_CONTACT + 0.08, t))
	# Backing under it he shuffles, a little side to side (pass c: for a second he stood like a statue).
	return [f, 0.08 * sin(t * 3.4 + 1.0) * (1.0 - smoothstep(0.9, 1.3, t)), back, hop]


## Where the marker's feet line is on screen with his knee on the man's shoulder: [feet, pixels per metre].
func _sf_pinned(t: float, frame: int, m: Vector2, fwd: Vector2, right: Vector2) -> Array:
	var b := _sf_brace(t)
	var at: Vector2 = m + right * float(b[1]) + fwd * float(b[2])
	var sb := _ground.project(at)
	var sh: Vector2 = SF_SHOULDER[int(b[0])]
	var shoulder := Vector2(sb.x, sb.y) + Vector2(sh.x + SF_IN, -(sh.y + float(b[3]) + SF_PAD)) * sb.z
	var sm := _ground.project(at + fwd * SF_BEHIND)
	var kn: Vector2 = SF_KNEE[frame]
	return [shoulder - Vector2(kn.x, -kn.y) * sm.z, sm.z]


## The marker at t: [feet on screen, pixels per metre, anim, frame, in the air].
func _sf_marker(t: float, m: Vector2, fwd: Vector2, right: Vector2) -> Array:
	var plant: Vector2 = m + right * SF_PLANT_AT.x + fwd * SF_PLANT_AT.y
	if t < SF_UP:
		# Running at the pack from behind it (a jog's strides), then planted: loaded, and the spring.
		var k := clampf(t / SF_PLANT, 0.0, 1.0)
		var p: Vector2 = _quad(m + right * SF_RUN.x + fwd * SF_RUN.y, m + right * SF_GAP.x + fwd * SF_GAP.y, plant, k)
		var s := _ground.project(p)
		if t < SF_PLANT:
			# (Pass d: he comes across the left lane, bobbing with each stride.)
			return [Vector2(s.x, s.y - 0.05 * absf(sin(t * 12.5 * PI / 4.0)) * s.z), s.z, "jog", int(t * 12.5) % 8, false]
		if t < SF_SPRING:
			return [Vector2(s.x, s.y), s.z, "mark_f", 0, false]
		# The spring: straightening out of the load (his boots are below the frame, so the figure rises).
		var up := (t - SF_SPRING) / (SF_UP - SF_SPRING)
		return [Vector2(s.x, s.y + SF_SINK * (1.0 - up) * s.z), s.z, "mark_f", 1, false]
	var info := VignetteFigures.strip(BODY, "mark_f", "front")
	if t < SF_CONTACT:
		# Off the turf: his hips on one arc from where the spring left them to where the knee lands, the
		# top of the arc at the landing; he carries his run on to the man.
		var a := (t - SF_UP) / (SF_CONTACT - SF_UP)
		var frame := 2 + clampi(int(a * 3.0), 0, 2)
		var s0 := _ground.project(plant)
		var h0 := Vector2(s0.x, s0.y - VignetteFigures.hips(info, 1) * s0.z)
		var pin := _sf_pinned(SF_CONTACT, 4, m, fwd, right)
		var h1: Vector2 = (pin[0] as Vector2) - Vector2(0, VignetteFigures.hips(info, 4) * float(pin[1]))
		var e := 1.0 - (1.0 - a) * (1.0 - a)
		var z := lerpf(s0.z, float(pin[1]), a)
		# (Pass c: across at one speed and up on the jump's own curve, so he arrives on the shoulder moving
		# forward, on one line; eased both ways he rose beside the man and then slid over.)
		var hip := Vector2(lerpf(h0.x, h1.x, a), h1.y + (h0.y - h1.y) * (1.0 - a) * (1.0 - a))
		return [hip + Vector2(0, VignetteFigures.hips(info, frame) * z), z, "mark_f", frame, true]
	var top := 4 if t < SF_CATCH else 5      # (pass c: the picture holds on the cleaner two-hand frame)
	var on := _sf_pinned(t, top, m, fwd, right)
	return [on[0], on[1], "mark_f", top, true]


## Between his palms in the frame he shows (the sheet's per-frame hands).
func _sf_palms(mk: Array) -> Vector2:
	var info := VignetteFigures.strip(BODY, str(mk[2]), "front")
	var h := VignetteFigures.hands(info, int(mk[3]))
	if h.is_empty():
		return Vector2.INF
	var k := float(mk[1]) / VignetteFigures.PX_PER_M
	return (mk[0] as Vector2) + (((h[0] as Vector2) + (h[1] as Vector2)) * 0.5 - Vector2(info["pivot"][0], info["pivot"][1])) * k


func _draw_speccy_front() -> void:
	var side := clampi(int(event.get("side", 0)), 0, 1)
	var other := 1 - side
	var m: Vector2 = SPECCY_AT[kind]
	var fwd := _ground.fwd
	var right := Vector2(fwd.y, -fwd.x)
	var t := _t
	# Further back, far to near: men watching it come, one jogging up, the umpire.
	for i in range(SF_BACK.size() - 1, -1, -1):
		var e: Array = SF_BACK[i]
		var who := str(e[2])
		var kit := side if who == "F" else (other if who == "D" else StoppageVignette.UMPIRE_KIT)
		var look: Dictionary = StoppageVignette.UMPIRE_LOOK if who == "U" else Appearance.generated("back%d" % i)
		var anim := str(e[3])
		var p: Vector2 = m + right * float(e[0]) + fwd * float(e[1])
		var frame := int(t * 12.0) % 8 if anim == "jog" else int(t * (2.4 + 0.25 * float(i)) + i * 0.61) % 3
		if anim == "jog":
			p -= fwd * t * 3.0
		_player(p, 0.0, kit, anim, "front", frame, 0, look, bool(e[4]))
	# The marker, beyond the man he climbs: drawn before the pack, so their bodies hide his legs as he
	# runs in, and the man's shoulder hides everything below the knee that sits on it.
	var mk := _sf_marker(t, m, fwd, right)
	var sc := float(mk[1]) / PX_PER_M
	_no_shadow = bool(mk[4])
	# Once it is marked the ball is drawn BEFORE him: upright between his palms, a hand over each side of
	# it (round 16: drawn over him, it hid one hand whole and read as balanced on a wrist).
	if t >= SF_CATCH and _sf_palms(mk) != Vector2.INF:
		VignetteBall.draw(self, _sf_palms(mk), 0.28 * float(mk[1]), 0.0, false, SF_HELD)
	_figure((mk[0] as Vector2) - Vector2(0, 38.0 * sc), sc, side, str(mk[2]), "front", int(mk[3]), 0, _look, Vector2.INF, false, BODY)
	_no_shadow = false
	# The pack, far to near. On the marker's left a defender goes up late with both hands; the man he
	# climbs; on his right, nearer us, another flies for it with a fist. Before the ball comes they watch
	# it and shuffle under it, each at his own time.
	var b := _sf_brace(t)
	var late: Vector2 = m + right * (1.16 - 0.10 * smoothstep(0.2, 1.0, t)) + fwd * (0.30 - 0.20 * smoothstep(0.4, 1.1, t))
	var k1 := clampf((t - 1.02) / 0.62, 0.0, 1.0)
	if k1 <= 0.0:
		_player(late, 0.0, other, "ready_b", "front", int(t * 2.9 + 0.4) % 3, 0, Appearance.generated("pack1"), true)
	else:
		_player(late, 0.20 * sin(k1 * PI * 0.5), other, "leap", "front", clampi(int(k1 * 6.0), 0, 5), 0, Appearance.generated("pack1"), true)
	_player(m + right * float(b[1]) + fwd * float(b[2]), float(b[3]), other, "brace_f", "front", int(b[0]), 0, Appearance.generated("pack0"))
	var near: Vector2 = m - right * (1.36 - 0.06 * smoothstep(0.1, 0.9, t)) - fwd * (0.18 - 0.14 * smoothstep(0.3, 1.0, t))
	var k2 := clampf((t - 0.88) / 0.66, 0.0, 1.0)
	if k2 <= 0.0:
		_player(near, 0.0, other, "ready_turn", "front", int(t * 2.5) % 3, 0, Appearance.generated("pack2"))
	else:
		_player(near, 0.26 * sin(k2 * PI * 0.5), other, "leap", "front", clampi(int(k2 * 6.0), 0, 5), 0, Appearance.generated("pack2"))
	# The ball: kicked from behind the camera, it drops into the top of the frame and into his hands
	# (over the last quarter of a second in shot), then stays between his palms.
	var palms := _sf_palms(mk)
	if t >= SF_CATCH:
		return
	var target := _sf_palms(_sf_marker(SF_CATCH, m, fwd, right))
	if target == Vector2.INF:
		return
	var u := SF_CATCH - t
	if u > 0.42:
		return                                   # still above the shot
	var at: Vector2 = m + fwd * (float(_sf_brace(SF_CATCH)[2]) + SF_BEHIND)
	var s1 := _ground.project(at)
	var h1 := (s1.y - target.y) / s1.z
	# (Pass c: a steep, quickening drop - 9 m/s at his hands - in shot for a quarter of a second.)
	# (Pass d: it quickens into his hands, 7 m/s at the top of the shot to 11 at the catch.)
	var p: Vector2 = at + right * ((target.x - s1.x) / s1.z + 0.12 * u) - fwd * 4.0 * u
	var s := _ground.project(p, h1 + 11.0 * u - 12.0 * u * u)
	if s.z > 0.0:
		# End over end, slowly, arriving on the frame it is held on (one ball, one colour, all the way).
		VignetteBall.draw(self, Vector2(s.x, s.y), 0.28 * s.z, 0.0, false, posmod(SF_HELD - int(ceil(u * 14.0)), VignetteBall.FRAMES))


## The braced man's frame at this moment (round 13, see the brace move): standing (0), half (1),
## braced with his arm up (2) from as the marker crouches; after the marker lands the arm comes
## down (3, 4); half up (5), standing (0).
func _brace_frame() -> int:
	var t_in := SPECCY_UP - 0.25
	var t_down := SPECCY_LAND + 0.04
	var t_out := SPECCY_LAND + 0.32
	if _t < t_in or _t >= t_out + 0.07:
		return 0
	if _t < t_in + 0.07:
		return 1
	if _t < t_down:
		# Round 14: under the marker's weight (his thigh on the shoulder until he swings off) the knees
		# and hips give a little: frame 6, the same pose a few cm lower.
		var t_off := SPECCY_TOP + sqrt(1.0 - SPECCY_HOLD) * (SPECCY_LAND - SPECCY_TOP) + 0.07
		var loaded := _t >= SPECCY_TOP - 0.22 and _t < t_off and int(VignetteFigures.strip(BODY, "brace", BRACE_FACING)["frames"]) > 6
		return 6 if loaded else 2
	if _t < t_down + 0.07:
		return 3
	return 4 if _t < t_out else 5


## Part of a standing figure drawn again: only below height h (metres on screen above his boots),
## over whatever was drawn since (the speccy's braced man hiding the marker's shin).
func _figure_below(p: Vector2, side: int, anim: String, facing: String, frame: int, h: float,
		look: Dictionary = EXTRA_LOOK) -> void:
	var s := _ground.project(p)
	if s.z <= 0.0 or not VignetteFigures.has(BODY, anim, facing):
		return
	var feet := Vector2(s.x, s.y)
	var k := s.z / VignetteFigures.PX_PER_M
	var info := VignetteFigures.strip(BODY, anim, facing)
	var src := VignetteFigures.source(info, StoppageVignette.figure_frame(info, frame, anim, facing))
	var pivot := Vector2(info["pivot"][0], info["pivot"][1])
	var cut := clampf(pivot.y - h * VignetteFigures.PX_PER_M, 0.0, src.size.y)
	var part := Rect2(src.position + Vector2(0, cut), Vector2(src.size.x, src.size.y - cut))
	draw_texture_rect_region(StoppageVignette.FIGURE_SHADE, Rect2(feet - pivot * k + Vector2(0, cut * k), part.size * k),
			part, StoppageVignette.look_colour(side, look, false))


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
	# The ball is always on the far side of him from here (in front of him as he lines up
	# and kicks, then flying away towards the posts), so it's drawn before him.
	_siren_ball(at, kicker, scale, boot)
	# Square behind the ball lining up the goal, then the run in, away from us towards
	# the posts, and the drop punt. He plants for the kick, so he stops where it starts.
	if _t < 1.75:
		_ready_player(at, side, "back", 3, false, false, num, _look, _build)
	elif _t < KICK_START:
		_player(at, 0.0, side, "jog", "back_r", _stride(_t - 1.75), num, _look, false, _build)
	elif _t < 3.45:
		_player(at, 0.0, side, "kick", "back_r", _kick_frame(_t - KICK_START, 3.02 - KICK_START), num, _look, false, _build)
	else:
		_ready_player(at, side, "back", 3, false, false, num, _look, _build)     # leg down, watching it go


## The set shot's ball. Lining up and running in it's at his waist in front of him (behind
## him from here, peeking out), moving to his right hand in the last strides. The drop punt
## (director, 2026-10-07): carried in the right hand (kick frames 0-1), the arm extends and
## lets it go (frame 2), it falls onto the top of the boot (accelerating) and sits on the
## laces at contact (frame 3, KICK_BOOT); then it flies at the posts.
func _siren_ball(at: Vector2, kicker: Vector2, scale: float, boot: Vector2) -> void:
	var held := _at(kicker, scale, Vector2(0.06, 0.95))
	var contact := 3.02 - KICK_START
	var kt := _t - KICK_START
	if _t < KICK_START:
		var bob := sin(_t * 8.0) * 2.5 if _t < 1.5 else 0.0
		var pos := held + Vector2(0, bob)
		var hand := _palm(at, "kick", "back_r", 0, 1, _build)
		if hand != Vector2.INF:
			pos = pos.lerp(hand, clampf((_t - (KICK_START - 0.25)) / 0.25, 0.0, 1.0))
		_draw_ball(pos, scale * 0.9)
	elif _t < 3.02:
		var release := contact * 2.0 / 3.0                # the start of kick frame 2
		var hand := _palm(at, "kick", "back_r", _kick_frame(kt, contact), 1, _build)
		if hand == Vector2.INF:
			hand = held
		var pos := hand
		if kt >= release:
			var u := (kt - release) / (contact - release)
			pos = hand.lerp(boot, u * u)
		_draw_ball(pos, scale * 0.9)
	else:
		var flight := clampf((_t - 3.02) / 1.85, 0.0, 1.0)
		var goal := str(event.get("kind", "")) == "goal"
		var start := Vector3(at.x, at.y, 0.7) + Vector3(_ground.fwd.x, _ground.fwd.y, 0.0) * 0.6
		var end := Vector3(0.0 if goal else 4.8, VignetteGround.GOAL_Y + 1.0, 7.0)
		_ball_flight(boot, start, end, 18.0, flight)


## A figure's palm on screen in a frame (hand 0 his left, 1 his right), from the palms
## recorded per frame with the figures (VignetteFigures.hands): where a held ball sits.
## Vector2.INF when the strip has none.
func _palm(p: Vector2, anim: String, facing: String, frame: int, hand: int, build := BODY) -> Vector2:
	var s := _ground.project(p)
	if s.z <= 0.0:
		return Vector2.INF
	if not VignetteFigures.has(build, anim, facing):
		build = BODY
	var info := VignetteFigures.strip(build, anim, facing)
	var h := VignetteFigures.hands(info, StoppageVignette.figure_frame(info, frame, anim, facing))
	if h.is_empty():
		return Vector2.INF
	var k := s.z / VignetteFigures.PX_PER_M
	return Vector2(s.x, s.y) + ((h[hand] as Vector2) - Vector2(info["pivot"][0], info["pivot"][1])) * k


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
	var info := VignetteFigures.strip(build, anim, facing)
	var f := StoppageVignette.figure_frame(info, frame, anim, facing)
	var k := pm / VignetteFigures.PX_PER_M
	# His shadow, under his boots (the strip's contact), not his ankles.
	var under := VignetteFigures.contact(info) * k
	if mirror:
		under.x = -under.x
	var shadow_at := (feet if ground == Vector2.INF else ground + Vector2(0, 38.0 * scale)) + under
	# A man in the air casts a smaller, fainter shadow on the turf below him (as the centre
	# bounce draws it): full-size and full-dark, a leaper's shadow read as nobody's.
	var air := 0.0 if ground == Vector2.INF else maxf(0.0, (ground.y - pos.y) / pm)
	if not _no_shadow:
		draw_set_transform_matrix(_view * Transform2D(0.0, Vector2(1.0, 0.3), 0.0, shadow_at))
		draw_circle(Vector2.ZERO, 0.4 * pm * (1.0 - 0.35 * minf(air, 1.5)),
				Color(0, 0, 0, VignetteWeather.shadow_alpha(weather) * (1.0 - 0.4 * minf(air, 1.5))))
		draw_set_transform_matrix(_view)
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
