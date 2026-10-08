class_name StoppageVignette
extends Control
## A staged close-up of a centre bounce, for the late-game centre-bounce call
## (ARD-M8-007 prototype). The match cuts to a low camera behind your end,
## tight on the centre square. The real rucks and centre-square midfielders
## jog into their set-up, a tired one lagging behind the rest, the umpire walks
## in with the ball, bounces it, the rucks go up - and it freezes at the top of
## the contest for the call.
##
## Presentation only: it reads MatchSim's state (who is on the ground, their
## legs, how the stoppages have gone) and changes nothing. What the call does
## is decided by MatchSim when it is made.

signal ready_for_call

## Only the stoppage: the ruck and the three centre-square midfielders a side.
const SLOTS := ["R", "C", "RR", "RV"]
## Beats of the scene, in seconds.
const CUT_IN := 0.35
const UMP_IN := [1.0, 2.2]
const BALL_UP := 2.9       # the umpire bounces it
const RUN_IN := [2.9, 3.45]
const FREEZE := 3.8
## Legs below this are running on empty (MatchNotes.EMPTY).
const EMPTY := 50.0
## Players are drawn larger than life so a phone can read them.
const FIGURE := 1.6
## The camera sits a little to one side of the corridor, over a shoulder.
const CAM_X := -3.0
## The field umpire's fluoro shirt: saturated, so it never reads as skin at a distance.
const UMPIRE := Color(0.66, 0.96, 0.08)
## The footballers are pre-rendered figures recoloured for each club
## (VignetteFigures.gd has the sheet's layout, figure.gdshader the recolouring).
const FIGURE_SHADE := preload("res://assets/vignette/figures_shade.png")
const FIGURE_MASK := preload("res://assets/vignette/figures_mask.png")
const FIGURE_DESIGN := preload("res://assets/vignette/figures_design.png")
const FIGURE_SHADER := preload("res://assets/vignette/figure.gdshader")
## Digits the shader prints players' numbers with, on the guernsey itself.
const FIGURE_DIGITS := preload("res://assets/vignette/figures_digits.png")
## Kits in the shader's palette: the two sides, then the umpire.
const UMPIRE_KIT := 2

## Tests switch this on to see which figure frames the vignettes ask for. A
## frame past the end of a move would otherwise freeze on its last frame
## without a word. Off in play.
static var log_frames := false
static var frame_log: Array = []  # {anim, facing, frames, wanted}
## ... and which hair they draw over the figures: {style, texture}.
static var hair_log: Array = []

var tokens: Array = []      # {side, mine, slot, id, tall, look, name, num, tired, from, to, delay, dur}
var facts: Array = []       # one or two lines of commentary, no numbers
var title := ""
var _colours := [[], []]
var _codes := ["", ""]
var _board := {}           # the match's score, for the big screen at the end of the ground
var _kits := []            # both sides' guernseys, as dressed
## The day's weather (MatchSim.weather; VignetteWeather): how the ground and air look.
var weather := ""
var _t := 0.0
var _frozen := false
var _hold := 0.0            # time since the freeze, for the last push-in


func setup(sim: MatchSim, my_side: int, heading := "") -> void:
	title = heading
	tokens.clear()
	# The day's weather, when MatchSim has one.
	weather = str(sim.get("weather")) if sim.get("weather") != null else ""
	_board = {"codes": [str((sim.squads[0] as Squad).code), str((sim.squads[1] as Squad).code)],
			"goals": [sim.goals(0), sim.goals(1)], "behinds": [sim.behinds(0), sim.behinds(1)],
			"q": sim.current_quarter}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [str((sim.squads[0] as Squad).code), sim.current_minute])
	for side in range(2):
		var code := str((sim.squads[side] as Squad).code)
		_colours[side] = GameDB.club_colours(code)
		_codes[side] = code
		# MatchSim's own bounce: the ruck who goes up (a ruckman resting from the
		# ruck spot still goes up; a midfielder standing in it does not) and the
		# inside mids who attend. The scene never picks its own.
		var at: Dictionary = sim.bounce_attendees(side)
		var ruck: Dictionary = at["ruck"]
		var mids: Array = at["mids"]
		var picks := {"R": [] if ruck.is_empty() else [ruck],
				"C": mids.slice(0, 1), "RR": mids.slice(1, 2), "RV": mids.slice(2, 3)}
		var mine := side == my_side
		# Your side attacks up the screen, away from the camera; theirs faces it.
		var sgn := 1.0 if mine else -1.0
		for slot in SLOTS:
			for p in picks[slot]:
				var home: Vector2 = MatchDirector.CENTRE[slot]
				# World: x across the ground, y towards your goal.
				var to := Vector2(home.y, home.x) * sgn
				if slot == "R":
					to = Vector2(-0.9 * sgn, -7.0 * sgn)    # backed off for the run at it
				var from := to + Vector2(rng.randf_range(-9.0, 9.0), -sgn * rng.randf_range(14.0, 20.0))
				var tired := float(sim.energy.get(str(p["id"]), 100.0)) < EMPTY
				tokens.append({"side": side, "mine": mine, "slot": slot, "id": str(p["id"]),
						"tall": MatchSim._is_ruckman(p), "look": GameDB.figure_look(p),
						"height_cm": float(p.get("height_cm", 0.0)),
						"name": _surname(GameDB.player_display_name(p)), "num": int(p["num"]),
						"tired": tired, "from": from, "to": to,
						"delay": rng.randf_range(0.0, 0.45),
						"dur": rng.randf_range(1.3, 1.7) * (1.6 if tired else 1.0)})
	_style_rucks()
	facts = _commentary(sim, my_side)
	_t = 0.0
	_hold = 0.0
	_frozen = false
	_dress()
	queue_redraw()


## The two ruckmen contest differently, so they never go up as twins: one taps
## with an open hand, running straight at it; the other goes body-on, punching
## with the other fist, a beat later, lower, and from wider. Which is which
## follows the players (stable), not the side.
const RUCK_STYLES := [
	{"anim": "tap", "delay": 0.0, "peak": 1.1, "approach": -0.6},
	{"anim": "tap_b", "delay": 0.07, "peak": 0.85, "approach": 0.4},
]

func _style_rucks() -> void:
	var rucks := tokens.filter(func(t): return str(t["slot"]) == "R")
	rucks.sort_custom(func(a, b): return hash(str(a["id"])) < hash(str(b["id"])))
	for i in range(rucks.size()):
		(rucks[i] as Dictionary)["ruck"] = RUCK_STYLES[i % RUCK_STYLES.size()]


## The figure material, with both clubs' guernseys and the umpire's. Everything
## this Control draws goes through it; only the figures are recoloured.
func _dress() -> void:
	var kits := []
	for side in range(2):
		var code := str(_codes[side])
		var cols: Array = _colours[side]
		var trim: Color = cols[1] if cols.size() > 1 else Color.DIM_GRAY
		var kit: Dictionary = GameDB.club_guernsey(code) if code != "" else {
				"design": "plain", "base": cols[0] if cols.size() > 0 else Color.WHITE,
				"pattern": trim, "pattern2": Color.WHITE, "shorts": trim.darkened(0.1)}
		kits.append(kit)
	_kits = kits
	material = figure_material(kits + [UMPIRE_GEAR], material as ShaderMaterial)


## The umpire has no player behind him: one fixed look.
const UMPIRE_LOOK := {"skin": 1, "hair": 1}


static func _eight(palette: Array) -> Array:
	var out := palette.duplicate()
	while out.size() < 8:
		out.append(palette[palette.size() - 1])
	return out


## The umpire's kit, in the figures' palette.
const UMPIRE_GEAR := {"design": "plain", "base": UMPIRE, "pattern": Color(0.42, 0.62, 0.05),
		"pattern2": Color(0.42, 0.62, 0.05), "shorts": Color(0.1, 0.1, 0.12)}


## A material that recolours the figure sheet: up to four kits ({design, base,
## pattern, pattern2, shorts}), addressed by index in a figure's draw colour.
## Reuses mat when given.
static func figure_material(kits: Array, mat: ShaderMaterial = null) -> ShaderMaterial:
	if mat == null or mat.shader != FIGURE_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FIGURE_SHADER
		mat.set_shader_parameter("mask_tex", FIGURE_MASK)
		mat.set_shader_parameter("design_tex", FIGURE_DESIGN)
		mat.set_shader_parameter("digits_tex", FIGURE_DIGITS)
		mat.set_shader_parameter("sheet_size", VignetteFigures.SHEET_SIZE)
		mat.set_shader_parameter("skin_tones", _eight(Appearance.SKIN))
		mat.set_shader_parameter("hair_tones", _eight(Appearance.HAIR))
		# The hair overlays' atlases, recognised by size as the figure sheet is.
		var sizes := []
		for tex in VignetteFigures.HAIR_TEXTURES:
			sizes.append(Vector2i((tex as Texture2D).get_size()))
		mat.set_shader_parameter("hair_count", sizes.size())
		while sizes.size() < 8:
			sizes.append(Vector2i(-1, -1))
		mat.set_shader_parameter("hair_sizes", sizes)
	var fields := {"base": [], "pattern": [], "pattern2": [], "shorts": [], "design": []}
	for i in range(4):
		var kit: Dictionary = kits[mini(i, kits.size() - 1)]
		for f in ["base", "pattern", "pattern2", "shorts"]:
			fields[f].append(kit[f])
		fields["design"].append(float(maxi(0, GameDB.GUERNSEY_DESIGNS.find(str(kit["design"])))))
	for f in fields:
		mat.set_shader_parameter("kit_" + f, fields[f])
	return mat


## Straight to the frozen contest (a tap skips the play-in; tests).
func finish_now() -> void:
	_t = FREEZE
	_freeze()


func is_frozen() -> bool:
	return _frozen


func _process(delta: float) -> void:
	if _frozen:
		if _hold < 0.4:
			_hold += delta
			queue_redraw()
		return
	_t += delta
	if _t >= FREEZE:
		_t = FREEZE
		_freeze()
	queue_redraw()


func _freeze() -> void:
	if _frozen:
		return
	_frozen = true
	queue_redraw()
	ready_for_call.emit()


func _gui_input(event: InputEvent) -> void:
	if not _frozen and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		finish_now()


# ---------------------------------------------------------------------------
# What the commentator says over the freeze: the story of the stoppages so
# far, in words. MatchSim's own counts decide it; none are shown.
# ---------------------------------------------------------------------------
func _commentary(sim: MatchSim, me: int) -> Array:
	return call_facts(sim, me)


## The same lines without the scene (Settings > Vignettes off): the call card
## carries them itself. MatchSim's bounce attendees, read the way setup() does.
static func call_facts(sim: MatchSim, me: int) -> Array:
	var at_bounce := []
	for side in range(2):
		var at: Dictionary = sim.bounce_attendees(side)
		var ruck: Dictionary = at["ruck"]
		var mids: Array = at["mids"]
		var picks := {"R": [] if ruck.is_empty() else [ruck],
				"C": mids.slice(0, 1), "RR": mids.slice(1, 2), "RV": mids.slice(2, 3)}
		for slot in SLOTS:
			for p in picks[slot]:
				at_bounce.append({"mine": side == me, "slot": slot,
						"name": _surname(GameDB.player_display_name(p)),
						"tired": float(sim.energy.get(str(p["id"]), 100.0)) < EMPTY})
	var out := []
	var them := 1 - me
	var gap := float((sim.team_stats[me] as Dictionary).get("clearances", 0.0)) \
			- float((sim.team_stats[them] as Dictionary).get("clearances", 0.0))
	var taps := _ruck_taps(sim, me) - _ruck_taps(sim, them)
	var rucks := {}
	for t in at_bounce:
		if str(t["slot"]) == "R":
			rucks[bool(t["mine"])] = str(t["name"])
	if gap <= -4:
		out.append("They have been winning it out of the middle all day.")
	elif gap >= 4:
		out.append("You have had the better of them out of the middle all day.")
	elif absi(taps) >= 5 and rucks.has(taps > 0):
		out.append("%s is on top in the ruck." % str(rucks[taps > 0]))
	else:
		out.append("Nothing between them at the stoppages.")
	for t in at_bounce:
		if bool(t["tired"]):
			out.append(("%s is running on empty." if bool(t["mine"]) else "Their %s is running on empty.")
					% str(t["name"]))
			break
	return out


static func _ruck_taps(sim: MatchSim, side: int) -> int:
	var n := 0.0
	for p in (sim.squads[side] as Squad).ground:
		if str(p["role"]) == "RUCK":
			n += _stat(sim, p, "hitouts")
	return int(n)


static func _stat(sim: MatchSim, p: Dictionary, key: String) -> float:
	return float((sim.player_stats.get(str(p["id"]), {}) as Dictionary).get(key, 0.0))


static func _surname(full: String) -> String:
	var parts := full.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else full


# ---------------------------------------------------------------------------
# The camera: the broadcast camera high behind your end, on a long lens, zooming in on
# the square and panning with the ruckmen. It stays where it is: only the lens moves, so
# the picture scales as one and nothing changes shape (it used to travel in from 34 m to
# 18 m, and the square and the players warped as it came - director).
# ---------------------------------------------------------------------------
const CAM_D := 46.0               # metres behind the centre
const CAM_H := 12.0               # and up (low enough that the stand stays in the zoom)
## The zoom: the square at the start's framing (as the old camera at 34 m) out to the
## ruck contest's (as at 17 m), then a last punch-in on the freeze.
const ZOOM := [46.0 / 34.0, 46.0 / 18.5, 46.0 / 17.0]
## The centre of the ground, as a share of the screen's height: while the play
## builds, and once the call is up (it takes the bottom of the screen).
const CENTRE_Y := [0.58, 0.46]
var _cam_d := CAM_D
var _cam_h := CAM_H
var _focal := 400.0
var _horizon := 0.0
var _cam_x := CAM_X
var _zoom := 1.0                  # how far the lens has zoomed since the start
var _pan := 0.0                   # pixels the camera has turned across, at this zoom


func _set_camera() -> void:
	var k := _ease(clampf(_t / FREEZE, 0.0, 1.0))
	var punch := _ease(clampf(_hold / 0.4, 0.0, 1.0))
	var base := maxf(size.x * 1.5, size.y * 0.7)
	var z: float = lerpf(lerpf(ZOOM[0], ZOOM[1], k), ZOOM[2], punch)
	_focal = base * z
	_zoom = z / ZOOM[0]
	# Panning across from where your players run in to the contest. A pan turns the
	# camera on its head, which moves the whole picture as one; the camera itself stays
	# at CAM_X (sliding it across would move the near turf more than the far, and the
	# painted lines would skew as it went - director).
	_cam_x = CAM_X
	_pan = _focal * (CAM_X * 0.35 - CAM_X) / (_cam_d + 5.0) * k
	# Where the centre of the ground sits: low enough to fill the screen while the
	# play builds, then lifted clear of the call as it slides up - the same push-in
	# as the freeze, so one move makes room for the call rather than empty turf
	# waiting for it all scene.
	_horizon = size.y * lerpf(CENTRE_Y[0], CENTRE_Y[1], punch) - _focal * _cam_h / _cam_d


## World (x across, y towards your goal, h up) to screen, and metres to pixels there.
func _project(p: Vector2, h := 0.0) -> Vector3:
	var z := maxf(0.5, p.y + _cam_d)
	return Vector3(size.x * 0.5 - _pan + _focal * (p.x - _cam_x) / z, _horizon + _focal * (_cam_h - h) / z, _focal / z)


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


# ---------------------------------------------------------------------------
# The scene, beat by beat.
# ---------------------------------------------------------------------------
func _pos(t: Dictionary) -> Vector2:
	var k := clampf((_t - float(t["delay"])) / float(t["dur"]), 0.0, 1.0)
	var p := (t["from"] as Vector2).lerp(t["to"], _ease(k))
	var sgn := 1.0 if bool(t["mine"]) else -1.0
	if str(t["slot"]) == "R":
		var style: Dictionary = t.get("ruck", RUCK_STYLES[0])
		var run := clampf((_t - RUN_IN[0] - float(style["delay"])) / (RUN_IN[1] - RUN_IN[0]), 0.0, 1.0)
		p = p.lerp(Vector2(float(style["approach"]) * sgn, -1.0 * sgn), run * run)
	elif k >= 1.0:
		# Settled in the square: jostling for the front spot.
		p.x += sin(_t * 3.1 + float(t["num"])) * 0.35
	return p


func _moving(t: Dictionary) -> bool:
	if str(t["slot"]) == "R" and _t >= RUN_IN[0] and _t < RUN_IN[1]:
		return true
	var k := (_t - float(t["delay"])) / float(t["dur"])
	return k > 0.0 and k < 0.95


func _lift(t: Dictionary) -> float:
	if str(t["slot"]) != "R":
		return 0.0
	var style: Dictionary = t.get("ruck", RUCK_STYLES[0])
	var start := RUN_IN[1] - 0.1 + float(style["delay"])
	if _t < start:
		return 0.0
	return float(style["peak"]) * _ease(clampf((_t - start) / 0.35, 0.0, 1.0))


func _umpire() -> Vector2:
	var k := clampf((_t - UMP_IN[0]) / (UMP_IN[1] - UMP_IN[0]), 0.0, 1.0)
	var at := Vector2(11.0, 3.0).lerp(Vector2(1.2, 0.4), _ease(k))
	# Out of the way once it is bounced.
	return at.lerp(Vector2(4.5, 2.5), _ease(clampf((_t - BALL_UP) / 0.6, 0.0, 1.0)))


func _ball() -> Vector3:
	# x, y on the ground and height: in the umpire's hand, raised, down, then up.
	var u := Vector2(1.2, 0.4) if _t >= BALL_UP else _umpire()
	if _t < BALL_UP - 0.5:
		return Vector3(u.x - 0.4, u.y, 1.1)
	if _t < BALL_UP - 0.15:
		return Vector3(u.x - 0.4, u.y, lerpf(1.1, 2.1, (_t - (BALL_UP - 0.5)) / 0.35))
	if _t < BALL_UP:
		var k := (_t - (BALL_UP - 0.15)) / 0.15
		return Vector3(lerpf(u.x - 0.4, 0.0, k), lerpf(u.y, 0.0, k), lerpf(2.1, 0.0, k))
	var up := _ease(clampf((_t - BALL_UP) / (FREEZE - BALL_UP), 0.0, 1.0))
	return Vector3(0.0, 0.0, 5.5 * up)


func _draw() -> void:
	_set_camera()
	var fade := clampf(_t / CUT_IN, 0.0, 1.0) if not _frozen else 1.0
	_draw_ground()
	# Far to near, so the nearer players stand in front.
	var figures := []
	for t in tokens:
		figures.append({"at": _pos(t), "t": t})
	figures.append({"at": _umpire(), "t": {}})
	figures.sort_custom(func(a, b): return (a["at"] as Vector2).y > (b["at"] as Vector2).y)
	var b := _ball()
	var ball_drawn := false
	for f in figures:
		if not ball_drawn and (f["at"] as Vector2).y < b.y:
			_draw_ball(b)
			ball_drawn = true
		_draw_figure(f["at"], f["t"])
	if not ball_drawn:
		_draw_ball(b)
	VignetteWeather.draw_air(self, Rect2(Vector2.ZERO, size), _t, weather)
	if _frozen:
		# The freeze: a flash on the cut, then the frame held a shade darker.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18), true)
		if _hold < 0.15:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5 * (1.0 - _hold / 0.15)), true)
		_draw_names()
	_draw_bars(fade)
	if fade < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - fade), true)


## The ground (VignetteGround, to the AFL's dimensions) through this scene's camera: the
## stands and the crowd, the fence, the boundary, the centre square and circles, the arcs
## and the far goals - all seen in perspective, so they hold their shape as it zooms.
func _draw_ground() -> void:
	var cam := ground_cam()
	VignetteGround.draw_ground(self, cam, Rect2(Vector2.ZERO, size), _colours, 7, _board, weather, _t)
	VignetteGround.draw_goals(self, cam, 1, _pad_colour())
	VignetteGround.draw_goals(self, cam, -1, _pad_colour())


## This scene's camera, as the ground sees it.
func ground_cam() -> VignetteGround.Cam:
	var cam := VignetteGround.Cam.new()
	cam.pos = Vector2(_cam_x, -_cam_d)
	cam.height = _cam_h
	cam.f = _focal
	cam.cx = size.x * 0.5 - _pan
	cam.hor = _horizon
	cam.to_scene = _ground_to_scene()
	return cam


## Where the scene stands on the ground: oval coordinates to the scene's. The centre
## bounce is at the centre of the ground, the length running away from the camera.
func _ground_to_scene() -> Transform2D:
	return Transform2D.IDENTITY


## The padding round the goal posts: the home club's colour.
func _pad_colour() -> Color:
	var c: Array = _colours[0] if not _colours.is_empty() else []
	return (c[0] as Color) if not c.is_empty() else Color(0.7, 0.7, 0.72)


func _draw_figure(at: Vector2, t: Dictionary) -> void:
	if at.y + _cam_d < 1.2:
		return               # beside or behind the camera
	var ump := t.is_empty()
	var lift := 0.0 if ump else _lift(t)
	var base := _project(at, lift)
	var ground := _project(at)
	var m := base.z * FIGURE           # pixels per (larger than life) metre
	var tired := not ump and bool(t["tired"])
	# Shadow on the ground, smaller as they leave it.
	var sh := 0.38 * m * (1.0 - lift * 0.35)
	draw_set_transform(Vector2(ground.x, ground.y), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, sh, Color(0, 0, 0, VignetteWeather.shadow_alpha(weather) + 0.03))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Your players have their backs to us; theirs and the umpire face the camera.
	var back := not ump and bool(t["mine"])
	var pick := _frame(t, lift, at, back)
	# A move can name its own side (a fourth entry: the kick is only drawn from behind,
	# three-quarters on).
	var facing: String = str(pick[3]) if pick.size() > 3 else ("back" if back else "front")
	var build := _body(t)
	if not VignetteFigures.has(build, pick[0], facing):
		build = "average"
	var info := VignetteFigures.strip(build, pick[0], facing)
	var frame := figure_frame(info, int(pick[1]), pick[0], facing)
	var src := VignetteFigures.source(info, frame)
	# Out on their feet: a touch smaller, stooped.
	var k := m / VignetteFigures.PX_PER_M * (0.96 if tired else 1.0)
	var mirror := bool(pick[2])
	var kit := UMPIRE_KIT if ump else int(t["side"])
	var look: Dictionary = t.get("look", UMPIRE_LOOK)
	draw_frame(self, Vector2(base.x, base.y), info, frame, k, look_colour(kit, look, mirror), mirror,
			number_colour(kit, int(t["num"]), 1.0, mirror) if facing.begins_with("back") and m > 18.0 else Color(0, 0, 0, 0),
			Transform2D.IDENTITY, str(look.get("hair_style", VignetteFigures.HAIR_BASE)))


## Draws frame f of a strip with its feet at feet, k screen pixels per frame pixel,
## on ci (whose material must be the figure material). Mirrored, it faces the other
## way: flipped about the feet by a draw transform (a negative-size rect isn't drawn).
## number: a second pass that prints the number (number_colour), or alpha 0 for none.
## view: the vignette's camera (VignetteCamera) that ci is drawing through.
## hair_style: his hair (Appearance.HAIR_STYLES), drawn over the bald figure
## straight after it (VignetteFigures.hair_for: a style with no art yet draws
## the base look), so a man in front still covers the hair of one behind.
static func draw_frame(ci: CanvasItem, feet: Vector2, info: Dictionary, f: int, k: float, colour: Color,
		mirror := false, number := Color(0, 0, 0, 0), view := Transform2D.IDENTITY,
		hair_style := VignetteFigures.HAIR_BASE) -> void:
	var pivot := Vector2(info["pivot"][0], info["pivot"][1])
	var dest := Rect2(feet - pivot * k, VignetteFigures.frame_size(info) * k)
	var src := VignetteFigures.source(info, f)
	if mirror:
		ci.draw_set_transform_matrix(view * Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, Vector2(2.0 * feet.x, 0.0)))
	ci.draw_texture_rect_region(FIGURE_SHADE, dest, src, colour)
	if number.a > 0.0:
		ci.draw_texture_rect_region(FIGURE_SHADE, dest, src, number)
	draw_hair(ci, dest.position, info, f, k, colour, hair_style)
	if mirror:
		ci.draw_set_transform_matrix(view)


## A figure's hair overlay: frame f of its style's hair strip over the figure drawn
## at origin (its dest rect's top-left), in his hair colour (or his skin, for a bare
## scalp: VignetteFigures.HAIR_TINT_SKIN). colour is the figure's look_colour.
static func draw_hair(ci: CanvasItem, origin: Vector2, info: Dictionary, f: int, k: float, colour: Color,
		hair_style: String) -> void:
	var h := VignetteFigures.hair_for(info, hair_style)
	if h.is_empty():
		return
	if log_frames:
		hair_log.append({"style": hair_style, "texture": VignetteFigures.hair_texture(h)})
	var skin := 1.0 if hair_style in VignetteFigures.HAIR_TINT_SKIN else 0.0
	ci.draw_texture_rect_region(VignetteFigures.hair_texture(h),
			Rect2(origin + VignetteFigures.hair_offset(h) * k, Vector2(h["size"][0], h["size"][1]) * k),
			VignetteFigures.hair_source(h, f), Color(skin, colour.g, colour.b, colour.a))


## The draw colour that recolours a figure: its kit, skin and hair, and whether
## the frame is mirrored (figure.gdshader).
static func look_colour(kit: int, look: Dictionary, mirror := false, alpha := 1.0) -> Color:
	return Color((kit * 2 + (1 if mirror else 0)) / 8.0, int(look["skin"]) / 8.0, int(look["hair"]) / 8.0, alpha)


## The draw colour that prints a number (0-99) on a figure's back instead of
## drawing the figure (figure.gdshader): draw the same frame again with it.
static func number_colour(kit: int, number: int, alpha := 1.0, mirror := false) -> Color:
	return Color((kit * 2 + (1 if mirror else 0)) / 8.0, 1.0, (clampi(number, 0, 99) + 1) / 128.0, alpha)


## Ruckmen are the tall figures; small men (BroadcastVignette.SMALL_CM) the small
## build; everyone else - an emergency ruck from the midfield included, and the
## umpire - the average build.
static func _body(t: Dictionary) -> String:
	if bool(t.get("tall", false)):
		return "ruck"
	var cm := float(t.get("height_cm", 0.0))
	return "small" if cm > 0.0 and cm < BroadcastVignette.SMALL_CM else "average"


## Which animation and frame a figure shows now, and whether it's mirrored:
## [anim, frame, mirror]. at: where he stands; back: his back is to us.
func _frame(t: Dictionary, lift: float, at := Vector2.ZERO, back := false) -> Array:
	if t.is_empty():
		# The umpire walks in, raises the ball, bounces it and follows through.
		if _t >= BALL_UP - 0.5 and _t < BALL_UP - 0.15:
			return ["bounce", 1, false]
		if _t >= BALL_UP - 0.15 and _t < BALL_UP:
			return ["bounce", 2, false]
		if _t >= BALL_UP and _t < BALL_UP + 0.4:
			return ["bounce", 3, false]
		if _t >= UMP_IN[0] and _t < UMP_IN[1]:
			return ["jog", int(_t * 10.0) % 8, false]
		return _ready_pick({"num": 0, "id": "umpire"}, at, false)
	if lift > 0.0:
		# The ruck contest, one-handed, each ruckman his own way (RUCK_STYLES).
		var style: Dictionary = t.get("ruck", RUCK_STYLES[0])
		var frames := 6 if str(style["anim"]) == "tap" else 4
		var k := clampf(lift / float(style["peak"]), 0.0, 1.0)
		return [style["anim"], int(roundf(k * (frames - 1))), false]
	if _moving(t):
		# Each man at his own stride; slower when they're out on their feet.
		var strides := (9.0 if bool(t["tired"]) else 13.0) / TAU * _rate(t, 0.9, 1.1)
		return ["jog", int(_t * strides * 8.0 + float(t["num"])) % 8, false]
	return _ready_pick(t, at, back)


## Standing, he's ready, not stiff: knees bent and bouncing at his own rate, his
## head and shoulders turned to what he's watching when it's off to one side
## (mirrored for his right). Two men side by side never move as one.
func _ready_pick(t: Dictionary, at: Vector2, back: bool) -> Array:
	var cycle := int(_t * 3.0 * _rate(t, 0.7, 1.15) + float(t["num"]) * 0.37 + _rate(t, 0.0, 3.0)) % 3
	var to := _look_at(t) - at
	# Across his line of sight: his back to us, his left is the screen's left.
	var across := -to.x if back else to.x
	if absf(to.x) < 0.35 * absf(to.y) + 1.0:
		# Looking ahead, in one of two stances of his own (a third of men side-on and low,
		# arms out), mirrored on a whim so a row isn't a row of clones.
		var stance := "ready_b" if _rate(t, 0.0, 1.0) < 0.35 and VignetteFigures.has(_body(t), "ready_b", "back" if back else "front") \
				else "ready"
		return [stance, cycle, _rate(t, 0.0, 1.0) > 0.5 if stance == "ready" else _rate(t, 0.0, 1.0) < 0.17]
	return ["ready_turn", cycle, across < 0.0]


## What a standing man watches: the ball (the pre-match scene overrides it).
func _look_at(_t_: Dictionary) -> Vector2:
	var b := _ball()
	return Vector2(b.x, b.y)


## A number of his own between lo and hi, stable for the man.
static func _rate(t: Dictionary, lo: float, hi: float) -> float:
	var h := hash(str(t.get("id", t.get("num", 0))) + "|rate")
	return lo + (hi - lo) * float(absi(h) % 1000) / 999.0


## Height of a figure's head (or raised hands) above its feet, world metres.
func _figure_top(t: Dictionary) -> float:
	var tall := float(VignetteFigures.BODIES[_body(t)]["height_m"])
	return (tall + (0.75 if _lift(t) > 0.0 else 0.1)) * FIGURE


func _draw_ball(b: Vector3) -> void:
	var g := _project(Vector2(b.x, b.y))
	var s := _project(Vector2(b.x, b.y), b.z)
	var r := maxf(3.0, 0.2 * s.z * FIGURE)
	draw_set_transform(Vector2(g.x, g.y), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, r * (1.0 - clampf(b.z / 10.0, 0.0, 0.6)), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The Sherrin (VignetteBall), spinning once it's up off the umpire's bounce.
	VignetteBall.draw(self, Vector2(s.x, s.y), 2.0 * r, _t, b.z > 0.6)


## At the freeze: who is who, for the rucks, the first midfielder each side and
## anyone out on their feet. Not a roll call.
func _draw_names() -> void:
	var font: Font = UiKit.BOLD
	var fs := int(clampf(size.x / 26.0, 12.0, 17.0))
	var placed: Array[Rect2] = []
	# The ball is the point of the frame: no name sits on it.
	var b := _ball()
	var bs := _project(Vector2(b.x, b.y), b.z)
	var br := maxf(3.0, 0.2 * bs.z * FIGURE) + 4.0
	placed.append(Rect2(bs.x - br, bs.y - br, br * 2.0, br * 2.0))
	for t in tokens:
		if not (str(t["slot"]) in ["R", "C"] or bool(t["tired"])):
			continue
		var at := _pos(t)
		var head := _project(at, _lift(t) + _figure_top(t))
		var name := str(t["name"])
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(clampf(head.x - nw * 0.5, 4.0, size.x - nw - 4.0), head.y - 6.0)
		# Over his head; failing that beside it, left or right, then stacked
		# upward - never over another name or the ball.
		var box := Rect2(p - Vector2(0, fs), Vector2(nw, fs + 2))
		var free := func(r: Rect2) -> bool: return not placed.any(func(q): return q.intersects(r))
		if not free.call(box):
			var side := box
			for dx in [-(nw * 0.5 + 10.0), nw * 0.5 + 10.0]:
				var c := Rect2(Vector2(clampf(head.x - nw * 0.5 + dx, 4.0, size.x - nw - 4.0), box.position.y + fs * 0.6), box.size)
				if free.call(c):
					side = c
					break
			box = side
		var tries := 0
		while tries < 4 and not free.call(box):
			box.position.y -= fs + 3
			tries += 1
		p = Vector2(box.position.x, box.position.y + fs)
		placed.append(box)
		draw_string(font, p + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
		draw_string(font, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1, 1, 1, 0.6) if bool(t["tired"]) and not (str(t["slot"]) in ["R", "C"]) else Color(1, 1, 1))


## Letterbox bars slide in on the cut; the call's heading rides the top one.
func _draw_bars(fade: float) -> void:
	var bar := size.y * 0.075 * _ease(fade)
	draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0), true)
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0), true)
	if title != "" and fade >= 1.0:
		var font: Font = UiKit.BOLD
		var fs := int(clampf(size.x / 24.0, 13.0, 18.0))
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(maxf(12.0, (size.x - tw) * 0.5), bar * 0.5 + fs * 0.36), title,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, fs, Color(1, 1, 1, 0.92))


func _readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


## The frame of a figure's move to draw: the one asked for, held on the last
## when a move runs out (logged for tests; see log_frames).
static func figure_frame(info: Dictionary, wanted: int, anim: String, facing: String) -> int:
	var frames := int(info["frames"])
	if log_frames:
		frame_log.append({"anim": anim, "facing": facing, "frames": frames, "wanted": wanted})
	return clampi(wanted, 0, frames - 1)
