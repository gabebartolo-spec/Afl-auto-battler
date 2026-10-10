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
## Smooth the edges of the lines and outlines drawn here (the oval, arcs,
## rings, token outlines). Fills stay as they are.
var antialias := true

var director := MatchDirector.new()
var _cam := Vector2.ZERO
var _zoom := 1.0
var _drawn_cam := Vector2.INF
var _drawn_zoom := -1.0
## Teams change ends every quarter. The director plays the match in its own
## frame (the home side always kicks toward +x); the view mirrors that frame
## in the 2nd and 4th quarters so the home side attacks the other end.
## Counts periods of play: every break (quarter time, half time, three
## quarter time, and the extra-time breaks) is a change of ends.
var period := 1
## Your people on the oval. `rings` are the players of yours with a call on them
## or a run promised (MatchRings): a thin ring on their token. A name goes over
## whoever has just kicked a goal, and over one of the ringed players when he has
## the ball. The name is kept in real seconds, not match time, so it can be read
## at any playback speed; the screen sets the rings, the view only draws.
var rings := {}
var _caption := {}             # {tok, text, left, goal, turnover, side}
var _poss_side := -1           # who had the ball at the last possession event
var _restarted := true         # the next possession comes from a restart
var _last_actor := -1
const CAPTION_GOAL := 1.8
const CAPTION_TOUCH := 1.0
## A change of possession in open play is said in words over the player who won
## it (ROADMAP §1.11: a clear turnover cue; tackles where the ball is kept or
## held in are not turnovers and carry no label).
const CAPTION_TURNOVER := 1.1
## What restarts play: whoever wins the ball after one of these has not turned
## it over.
const RESTARTS := ["goal", "behind", "quarter", "ballup", "throwin", "free", "fifty",
		"last_disposal", "out_on_full"]
## The turf is green in both appearances, so the ring is the dark theme's text
## colour fixed, not UiKit.TEXT, which turns dark in light mode.
const RING_COLOUR := Color(0.945, 0.933, 0.902)
## A player's token is never smaller than a thumb can tell apart (audit §8
## Phase 3.1): a radius of 9 px is an 18 px disc, the number's floor too.
const TOKEN_MIN := 9.0
## The ball's last few positions on the turf, for a short trail behind it.
const TRAIL_N := 14
var _trail: Array = []
## Each side's home kit (GameDB.club_guernsey): the token wears the club's
## design, not just its colours, so the two sides read apart at a glance.
var _kits: Array = [{}, {}]
## The stand beyond the fence and the turf's edge in shadow, so the oval sits
## in a ground rather than floating on black (audit §8 Phase 3.2).
const STAND_COLOUR := Color(0.125, 0.11, 0.095)
const FENCE_COLOUR := Color(0.36, 0.33, 0.29)
## PROTOTYPE, gated by the director's phone (audit §8 Phase 3.3): the few
## players nearest the ball drawn as small footballers from the vignette
## sheets, over their tokens. Settings > Match view; off by default. If it
## reads and holds 60 fps on the phone it becomes the view; otherwise it goes.
var mini_figures := false
const FIGURES_NEAR_BALL := 6
const FIGURE_HEIGHT := 2.7        # figure height in token radii (tr 9 = 24 px)
var _figs: MiniFigures
var _looks := {}


## The figures' own layer: the figure shader is a material on a CanvasItem,
## so they cannot share the oval's drawing.
class MiniFigures extends Control:
	var slots: Array = []

	func _draw() -> void:
		for s in slots:
			StoppageVignette.draw_frame(self, s["feet"], s["info"], int(s["frame"]), float(s["k"]),
					s["colour"], bool(s["mirror"]), s["number"], Transform2D.IDENTITY, str(s["hair"]))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_figs = MiniFigures.new()
	_figs.name = "MiniFigures"
	_figs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_figs)


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(p_result: Dictionary) -> void:
	result = p_result
	# Our own list, so appended segments never touch the caller's result.
	events = (p_result.get("events", []) as Array).duplicate()
	home_code = str(p_result.get("home", ""))
	away_code = str(p_result.get("away", ""))
	_kits = [GameDB.club_guernsey(home_code), GameDB.club_guernsey(away_code)]
	_trail = []
	mini_figures = GameState.match_figures_on()
	_looks = {}
	if _figs != null:
		_figs.material = StoppageVignette.figure_material(_kits, _figs.material as ShaderMaterial)
		_figs.slots = []
	playing = false
	director = MatchDirector.new()
	director.setup(p_result, events)
	period = 1
	_caption = {}
	_last_actor = -1
	_poss_side = -1
	_restarted = true
	_cam = Vector2.ZERO
	_zoom = _target_zoom()
	set_process(true)
	queue_redraw()


func append_events(new_events: Array, timeline: Array = []) -> void:
	events.append_array(new_events)
	if not timeline.is_empty() and director != null:
		director.set_timeline(timeline)
	queue_redraw()


# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------
func play() -> void:
	if director.idle():
		# Nothing new to show (a moment right where the last one left off):
		# say so, or the match screen waits for a finish that never comes
		# and the match freezes with the next call unasked.
		playing = false
		finished.emit()
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
	for ev in director.flush():
		_track_quarter(ev)
	_caption = {}
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
			_track_quarter(ev)
			_name_the_scorer(ev)
			_cue_turnover(ev)
			event_played.emit(ev)
			if str((ev as Dictionary).get("kind", "")) == "final":
				playing = false
				finished.emit()
				break
		if playing and director.idle():
			playing = false
			finished.emit()
		_follow_ball()
	_name_the_ball_carrier()
	_age_caption(delta)
	_update_camera(delta)
	if playing or _cam.distance_to(_drawn_cam) > 0.05 or absf(_zoom - _drawn_zoom) > 0.002 \
			or not director.flash.is_empty() or not _caption.is_empty():
		queue_redraw()


# ---------------------------------------------------------------------------
# Your people on the oval
# ---------------------------------------------------------------------------
## Ring these players (ids); [] clears them.
func set_rings(ids: Array) -> void:
	var next := {}
	for id in ids:
		next[str(id)] = true
	var a := rings.keys()
	var b := next.keys()
	a.sort()
	b.sort()
	if a == b:
		return
	rings = next
	queue_redraw()


func ringed(pid: String) -> bool:
	return rings.has(pid)


## The name over a player right now, "" for none.
func caption_text() -> String:
	return str(_caption.get("text", ""))


## A goal puts its scorer's name on the oval, either side's.
func _name_the_scorer(ev: Dictionary) -> void:
	if str(ev.get("kind", "")) != "goal":
		return
	var tok := director.token_of(ev)
	if tok < 0 or tok >= director.tokens.size():
		return
	_caption = {"tok": tok, "text": str(director.tokens[tok].get("surname", "")),
			"left": CAPTION_GOAL, "goal": true}


## The ball changed hands in open play: "Turnover" over the player who won it.
## A forced turnover, a rebound and an intercept mark always are; otherwise
## the side with the ball changed without a restart in between. A goal's name
## is never covered.
func _cue_turnover(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if RESTARTS.has(kind):
		_restarted = true
		return
	var side := int(ev.get("side", -1))
	var won := kind == "pressure" or kind == "rebound" \
			or (kind == "mark" and bool(ev.get("intercept", false)))
	if side < 0 or not (won or MatchDirector.DISPOSALS.has(kind)):
		return
	var flipped := _poss_side >= 0 and side != _poss_side and not _restarted
	_poss_side = side
	_restarted = false
	if not (won or flipped):
		return
	if not _caption.is_empty() and bool(_caption["goal"]):
		return
	var tok := director.token_of(ev)
	if tok < 0 or tok >= director.tokens.size():
		return
	_caption = {"tok": tok, "text": "Turnover", "left": CAPTION_TURNOVER, "goal": false,
			"turnover": true, "side": side}


## A ringed player of yours who gets the ball is named for a moment. A goal's
## name outranks that, and a name already showing is not restarted.
func _name_the_ball_carrier() -> void:
	var act := director.actor
	if act == _last_actor:
		return
	_last_actor = act
	if act < 0 or act >= director.tokens.size():
		return
	var t: Dictionary = director.tokens[act]
	if not rings.has(str(t.get("pid", ""))):
		return
	if not _caption.is_empty() and (bool(_caption["goal"]) or bool(_caption.get("turnover", false))
			or int(_caption["tok"]) == act):
		return
	_caption = {"tok": act, "text": str(t.get("surname", "")), "left": CAPTION_TOUCH, "goal": false}


func _age_caption(delta: float) -> void:
	if _caption.is_empty():
		return
	_caption["left"] = float(_caption["left"]) - delta
	if float(_caption["left"]) <= 0.0:
		_caption = {}
		queue_redraw()


## The ball's path over the last fraction of a second, in ground metres. A
## dead ball leaves no trail; a ball that has not moved adds nothing.
func _follow_ball() -> void:
	if director.ball.is_empty() or str(director.ball.get("mode", "dead")) == "dead":
		_trail.clear()
		return
	var pos: Vector2 = director.ball["pos"]
	if not _trail.is_empty() and (_trail[-1] as Vector2).distance_to(pos) < 0.05:
		return
	_trail.append(pos)
	while _trail.size() > TRAIL_N:
		_trail.pop_front()


## Every break the match screen plays is a change of ends.
func _track_quarter(ev: Dictionary) -> void:
	if str(ev.get("kind", "")) == "quarter":
		period += 1
		queue_redraw()


## +1 when the home side kicks to the right of the screen, -1 when it kicks
## to the left: periods 1 and 3 one way, 2 and 4 the other.
static func end_sign(p: int) -> float:
	return 1.0 if p % 2 == 1 else -1.0


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
	var m := end_sign(period)
	return size * 0.5 + Vector2((p.x - _cam.x) * m, p.y - _cam.y) * _scale()


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

	# The stand, dark, beyond the fence; the fence a band at the turf's edge.
	draw_rect(Rect2(Vector2.ZERO, size), STAND_COLOUR, true)
	var fence := maxf(3.0, 2.0 * s)
	draw_colored_polygon(_ellipse_points(c, a + fence, b + fence, 128), FENCE_COLOUR)

	# Turf + mown stripes, as the day's weather leaves them (VignetteWeather).
	var weather := str(result.get("weather", ""))
	var grass := VignetteWeather.grass(weather, [Color(0.118, 0.333, 0.133), Color(0.133, 0.365, 0.149)])
	draw_colored_polygon(_ellipse_points(c, a, b, 128), grass[0])
	var stripes := 9
	for i in range(stripes):
		if i % 2 == 1:
			continue
		var x0 := c.x - a + (2.0 * a) * float(i) / float(stripes)
		var x1 := c.x - a + (2.0 * a) * float(i + 1) / float(stripes)
		draw_colored_polygon(_stripe(c, a, b, x0, x1), grass[1])
	# The turf's edge in the stand's shadow: a few soft rings fading inward.
	var shade := maxf(6.0, 7.0 * s)
	for i in range(4):
		var inset := shade * float(i) / 4.0
		draw_polyline(_ellipse_points(c, a - inset, b - inset, 96),
				Color(0, 0, 0, 0.16 - 0.035 * float(i)), shade / 4.0 + 1.0, antialias)

	# Boundary
	draw_polyline(_ellipse_points(c, a, b, 128), Color(1, 1, 1, 0.85), 2.5, antialias)

	var line_col := Color(1, 1, 1, 0.55)
	var lw := 1.6

	# Centre square (50m) and centre circle (10m across)
	var sq := 25.0 * s
	draw_rect(Rect2(c - Vector2(sq, sq), Vector2(sq, sq) * 2.0), line_col, false, lw, antialias)
	draw_arc(c, 5.0 * s, 0, TAU, 32, line_col, lw, antialias)

	# 50m arcs and goal squares at each end
	for sgn in [-1.0, 1.0]:
		var goal := _w2s(Vector2(sgn * GOAL_LINE_M, 0.0))
		var rad := 50.0 * s
		var span := _arc_span(c, a, b, goal, rad)
		draw_arc(goal, rad, span.x, span.y, 48, line_col, lw, antialias)
		# Goal square: 9m deep, 6.4m wide across the goal line.
		var depth := 9.0 * s
		var width := 6.4 * s
		var gx := goal.x - depth if goal.x > c.x else goal.x
		draw_rect(Rect2(Vector2(gx, goal.y - width * 0.5), Vector2(depth, width)),
				line_col, false, lw, antialias)
		# Goal posts 6.4m apart, behind posts a further 6.4m out.
		for py in [-1.0, 1.0]:
			draw_circle(goal + Vector2(0, py * 3.2 * s), maxf(2.0, 0.55 * s), Color(1, 1, 1, 0.95))
			draw_circle(goal + Vector2(0, py * 9.6 * s), maxf(1.5, 0.4 * s), Color(1, 1, 1, 0.7))

	# Rain falls and wind blows over the ground, under the players and the ball.
	var now := float(Time.get_ticks_msec()) / 1000.0
	VignetteWeather.draw_air(self, r, now, weather)
	if weather == VignetteWeather.WINDY:
		VignetteWeather.draw_wind_flat(self, r, now)
	var tr := maxf(TOKEN_MIN, minf(r.size.x, r.size.y) * 0.5 * 0.030 * sqrt(_zoom))
	_draw_tokens(0, tr)
	_draw_tokens(1, tr)
	_draw_rings(tr)
	if _figs != null:
		_figs.slots = _figure_slots(tr) if mini_figures else []
		_figs.queue_redraw()

	# Actor highlight
	var act := director.actor
	if act >= 0 and act < director.tokens.size():
		var p := _w2s(director.tokens[act]["pos"])
		draw_arc(p, tr * 1.9, 0, TAU, 28, Color(1, 1, 0.55, 0.95), 2.0, antialias)

	_draw_ball(tr, s)

	# Goal / behind flash
	var fl := director.flash
	if not fl.is_empty():
		var t := 1.0 - clampf(float(fl["left"]) / 0.9, 0.0, 1.0)
		var rad2 := lerpf(tr, minf(a, b) * 0.42, t)
		var col := Color(1.0, 0.92, 0.35) if fl["goal"] else Color(0.85, 0.9, 1.0)
		col.a = (1.0 - t) * 0.85
		draw_arc(_w2s(fl["pos"]), rad2, 0, TAU, 48, col, 4.0, antialias)
	_draw_role_labels(tr)
	_draw_caption(tr)


## A thin light ring on each of your players with a call on him or a run
## promised. Quieter than the actor's ring, which stays the one that moves.
func _draw_rings(tr: float) -> void:
	if rings.is_empty():
		return
	for t in director.tokens:
		if float(t["down"]) > 0.0 or not rings.has(str(t.get("pid", ""))):
			continue
		var p := _w2s(t["pos"])
		if p.x < -tr * 3.0 or p.y < -tr * 3.0 or p.x > size.x + tr * 3.0 or p.y > size.y + tr * 3.0:
			continue
		draw_arc(p, tr * 1.5, 0, TAU, 28, Color(RING_COLOUR, 0.9), 1.6, antialias)


## The name over a player, in the type the team shape uses: bold, outlined so it
## reads on the turf, never smaller than a phone can read, and kept inside the
## view.
## The players with a recorded job (MatchDirector.role_labels) carry their
## surname under the token, small and quiet, so the viewer can follow the
## tagger, the loose man and his minder without a coaching overlay. The
## passing caption (a goal, a ringed player's touch) still sits above.
func _draw_role_labels(tr: float) -> void:
	var fs := clampi(int(tr * 1.15), 9, 12)
	# Named under the token: the players with a job, whoever has the ball, and
	# your ringed players (audit §8 Phase 3.1), each once.
	var named := {}
	for id in director.role_labels():
		named[int(id)] = true
	var holder := int(director.ball.get("holder", -1)) if not director.ball.is_empty() else -1
	if holder >= 0:
		named[holder] = true
	if not rings.is_empty():
		for i in range(director.tokens.size()):
			if rings.has(str(director.tokens[i].get("pid", ""))):
				named[i] = true
	for id in named:
		if id < 0 or id >= director.tokens.size():
			continue
		var t: Dictionary = director.tokens[id]
		if float(t.get("down", 0.0)) > 0.0:
			continue
		var text := str(t.get("surname", ""))
		if text == "":
			continue
		var width := UiKit.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := _w2s(t["pos"])
		if p.x < -width or p.y < 0.0 or p.x > size.x + width or p.y > size.y + float(fs) * 2.0:
			continue
		var origin := p + Vector2(-width * 0.5, tr * 1.25 + float(fs))
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(UiKit.BOLD, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(UiKit.BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))


func _draw_caption(tr: float) -> void:
	if _caption.is_empty():
		return
	var tok := int(_caption["tok"])
	var text := str(_caption["text"])
	if text == "" or tok < 0 or tok >= director.tokens.size():
		return
	var turnover := bool(_caption.get("turnover", false))
	# A turnover is a cue, not a name: a size up, so it reads at a glance.
	var fs := clampi(int(tr * (2.1 if turnover else 1.6)), 15 if turnover else 11, 20 if turnover else 15)
	var width := UiKit.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := _w2s(director.tokens[tok]["pos"])
	var origin := p + Vector2(-width * 0.5, -tr * 2.4)
	origin.x = clampf(origin.x, 4.0, maxf(4.0, size.x - width - 4.0))
	origin.y = maxf(origin.y, float(fs) + 2.0)
	# It fades over its last third of a second.
	var fade := clampf(float(_caption["left"]) / 0.3, 0.0, 1.0)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(UiKit.BOLD, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0, 0, 0, 0.8 * fade))
	draw_string(UiKit.BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(RING_COLOUR, fade))
	if turnover:
		# Underlined in the winning club's colour: whose ball it is now, at a glance.
		var kit: Dictionary = _kits[clampi(int(_caption.get("side", 0)), 0, 1)]
		var bar: Color = kit.get("base", RING_COLOUR)
		# A light edge round the club bar so a dark kit colour still shows on the grass.
		draw_rect(Rect2(origin + Vector2(-2, 3), Vector2(width + 4, 6)), Color(RING_COLOUR, 0.85 * fade))
		draw_rect(Rect2(origin + Vector2(-1, 4), Vector2(width + 2, 4)), Color(bar, fade))


func _draw_ball(tr: float, s: float) -> void:
	if director.ball.is_empty():
		return
	# A short trail on the turf, brightest at the ball, gone a moment later.
	if _trail.size() >= 2:
		for i in range(1, _trail.size()):
			var k := float(i) / float(_trail.size() - 1)
			draw_line(_w2s(_trail[i - 1]), _w2s(_trail[i]), Color(0.98, 0.93, 0.75, 0.55 * k),
					maxf(1.0, tr * 0.22 * k), antialias)
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
			Color(0.25, 0.12, 0.08), 1.0, antialias)


## A side's tokens: a disc in the club's home kit (its base colour and its
## design in the pattern colour), the number on it in white with a dark edge
## so it reads on any kit, dropped when the disc is under 18 px.
func _draw_tokens(side: int, tr: float) -> void:
	var kit: Dictionary = _kits[side]
	var base: Color = kit.get("base", Color.WHITE)
	var font := UiKit.BOLD
	var fs := int(clampf(tr * 1.1, 9.0, 15.0))
	for t in director.tokens:
		if int(t["side"]) != side:
			continue
		var p := _w2s(t["pos"])
		if p.x < -tr * 3.0 or p.y < -tr * 3.0 or p.x > size.x + tr * 3.0 or p.y > size.y + tr * 3.0:
			continue
		if float(t["down"]) > 0.0:
			# On the ground after a tackle.
			draw_colored_polygon(_ellipse_points(p, tr * 1.15, tr * 0.62, 16), base.darkened(0.25))
			draw_polyline(_ellipse_points(p, tr * 1.15, tr * 0.62, 16), Color(0, 0, 0, 0.4), 1.2, antialias)
			continue
		# Drop shadow keeps tokens readable on the stripes.
		draw_circle(p + Vector2(0, tr * 0.22), tr, Color(0, 0, 0, 0.28))
		_draw_kit(p, tr, kit)
		draw_circle(p, tr, Color(0, 0, 0, 0.45), false, 1.2, antialias)
		if tr < TOKEN_MIN:
			continue
		var label := str(t["num"])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var origin := p + Vector2(-w * 0.5, fs * 0.36)
		# A full dark edge (eight directions) so the white figure reads on a
		# white stripe as well as on navy.
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
				Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_string(font, origin + off, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))


## PROTOTYPE: the six nearest the ball as figures, each a slot for the
## MiniFigures layer: feet on the token, the jog strip when he moves (side-on
## across the screen, back or front along it), idle when he stands, the
## number on his back when he shows it and the figure is tall enough.
func _figure_slots(tr: float) -> Array:
	var out := []
	if director.ball.is_empty():
		return out
	var ball_pos: Vector2 = director.ball["pos"]
	var order := []
	for i in range(director.tokens.size()):
		var t: Dictionary = director.tokens[i]
		if float(t.get("down", 0.0)) > 0.0:
			continue
		order.append([(t["pos"] as Vector2).distance_squared_to(ball_pos), i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var height_px := float(VignetteFigures.BODIES["average"]["height_m"]) * VignetteFigures.PX_PER_M
	var k := FIGURE_HEIGHT * tr / height_px
	var m := end_sign(period)
	for j in range(mini(FIGURES_NEAR_BALL, order.size())):
		var i: int = order[j][1]
		var t: Dictionary = director.tokens[i]
		var p := _w2s(t["pos"])
		if p.x < -tr * 4.0 or p.y < -tr * 4.0 or p.x > size.x + tr * 4.0 or p.y > size.y + tr * 4.0:
			continue
		var vel: Vector2 = t.get("vel", Vector2.ZERO)
		var moving := vel.length() > 0.6
		var anim := "jog" if moving else "idle"
		var facing := "front"
		var mirror := false
		if moving:
			var sx := vel.x * m
			if absf(sx) > absf(vel.y):
				facing = "side_l"
				mirror = sx > 0.0
			else:
				facing = "back" if vel.y < 0.0 else "front"
		if not VignetteFigures.has("average", anim, facing):
			anim = "idle"
			facing = "front"
		var info := VignetteFigures.strip("average", anim, facing)
		var frames := int(info["frames"])
		var frame := (int(Time.get_ticks_msec() / 90) + i * 3) % frames if moving else 0
		var look := _look_for(str(t.get("pid", "")))
		var kit := int(t["side"])
		var number := Color(0, 0, 0, 0)
		if facing.begins_with("back") and FIGURE_HEIGHT * tr > 18.0:
			number = StoppageVignette.number_colour(kit, int(t["num"]), 1.0, mirror)
		out.append({"feet": p + Vector2(0, tr * 0.3), "info": info, "frame": frame, "k": k,
				"colour": StoppageVignette.look_colour(kit, look, mirror), "mirror": mirror,
				"number": number, "hair": str(look.get("hair_style", VignetteFigures.HAIR_BASE))})
	# The man lower on the screen stands in front.
	out.sort_custom(func(a, b): return (a["feet"] as Vector2).y < (b["feet"] as Vector2).y)
	return out


## His skin, hair and sleeves (GameDB.figure_look), found once per player.
func _look_for(pid: String) -> Dictionary:
	if not _looks.has(pid):
		var p = GameDB.player_by_id(pid)
		_looks[pid] = GameDB.figure_look(p, str(result.get("weather", "")) == "wet") if p != null \
				else StoppageVignette.UMPIRE_LOOK
	return _looks[pid]


## The club's design on a disc: stripes, hoops, a sash, a yoke, a band, a
## chevron or side panels in the pattern colour over the base; anything else
## is the base with an inner disc of the pattern colour. Shapes are drawn
## within the disc's chord so nothing pokes out of the circle.
func _draw_kit(p: Vector2, tr: float, kit: Dictionary) -> void:
	var base: Color = kit.get("base", Color.WHITE)
	var pat: Color = kit.get("pattern", Color.DIM_GRAY)
	var design := str(kit.get("design", "plain"))
	draw_circle(p, tr, base)
	var r := tr * 0.94
	match design:
		"stripes":
			for x in [-0.55, 0.0, 0.55]:
				var cx := float(x) * r
				var half := sqrt(maxf(0.0, r * r - cx * cx)) * 0.98
				draw_rect(Rect2(p + Vector2(cx - r * 0.13, -half), Vector2(r * 0.26, half * 2.0)), pat)
		"hoops", "lowhoops", "twohoops", "tiers":
			for y in [-0.4, 0.3]:
				var cy := float(y) * r
				var half := sqrt(maxf(0.0, r * r - cy * cy)) * 0.98
				draw_rect(Rect2(p + Vector2(-half, cy - r * 0.15), Vector2(half * 2.0, r * 0.3)), pat)
		"sash":
			var w := r * 0.42
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.75, -r * 0.75 + w), p + Vector2(-r * 0.75, -r * 0.75),
					p + Vector2(r * 0.75, r * 0.75 - w), p + Vector2(r * 0.75, r * 0.75)]), pat)
		"yoke", "shoulders":
			# The top near-half, so the two colours read at 18 px: the arc from
			# chord end to chord end (the chord closes it), never a bow-tie.
			var pts := PackedVector2Array()
			var lift := asin(0.05)
			for i in range(15):
				var ang := lerpf(PI + lift, TAU - lift, float(i) / 14.0)
				pts.append(p + Vector2(cos(ang) * r, sin(ang) * r))
			draw_colored_polygon(pts, pat)
		"band":
			draw_rect(Rect2(p + Vector2(-r * 0.98, -r * 0.22), Vector2(r * 1.96, r * 0.44)), pat)
		"chevron", "chevrons", "wings":
			draw_polyline(PackedVector2Array([p + Vector2(-r * 0.7, -r * 0.35), p + Vector2(0, r * 0.4),
					p + Vector2(r * 0.7, -r * 0.35)]), pat, maxf(2.0, r * 0.32), antialias)
		"panels", "sides", "giants", "map":
			var pts := PackedVector2Array()
			for i in range(17):
				var ang := PI * 0.5 + PI * float(i) / 16.0
				pts.append(p + Vector2(cos(ang) * r, sin(ang) * r))
			draw_colored_polygon(pts, pat)
		_:
			draw_circle(p, tr * 0.55, pat)


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
