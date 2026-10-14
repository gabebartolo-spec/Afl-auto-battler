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
## The sides have changed ends: `period` is the one now being played.
signal ends_changed(period: int)

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
## The ground runs top to bottom (director, 2026-10-14: "turn the oval upright" on
## a phone in portrait), goals at the top and the bottom, the whole ground in
## view. It is the same picture turned a quarter turn: the home side kicks up
## the screen in the first quarter where it kicked to the right. Everything is
## worked out as it is for the ground lying flat (the "flat" frame: _flat_size,
## _w2s_flat) and turned at the end (_to_screen); names, numbers and the ball's
## height stay upright. The match screen sets it; PC and landscape leave it off.
var upright := false:
	set(v):
		if v != upright:
			upright = v
			_nudge = PackedVector2Array()
			_disc = PackedVector2Array()
			_cam = _clamp_cam(_cam)
			queue_redraw()

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
## A break has been played and the sides have not yet changed ends: they swap when
## the next period restarts (the players walking to the centre), not at the siren,
## when the clock still shows the quarter just ended. Never after the last siren.
var _flip_pending := false
## Your people on the oval. `rings` are the players of yours with a call on them
## or a run promised (MatchRings): a thin ring on their token. A name goes over
## whoever has just kicked a goal, and over one of the ringed players when he has
## the ball. The name is kept in real seconds, not match time, so it can be read
## at any playback speed; the screen sets the rings, the view only draws.
var rings := {}
var _caption := {}             # {tok, text, left, goal, turnover, side}
var _poss_side := -1           # who had the ball at the last possession event
var _restarted := true         # the next possession comes from a restart
var _shake := 0.0              # seconds of goal shake left
var shake_share := SHAKE_SHARE # the shake's size (captures compare strengths)
var _last_actor := -1
const CAPTION_GOAL := 1.8
const CAPTION_TOUCH := 1.0
## A change of possession in open play is said in words over the player who won
## it (ROADMAP §1.11: a clear turnover cue; tackles where the ball is kept or
## held in are not turnovers and carry no label).
const CAPTION_TURNOVER := 1.1
## The goal's shake, the only one in the game: short, gone in under a fifth of a
## second. Its size is a share of the oval's height, so it reads the same on a phone
## and a PC. Director, 2026-10-13: "reduce screenshake" - about 40% of the old size
## (0.025), 60% of the old time (0.3), never more than the share below as a hard cap
## (about 4 px on a phone), and a new goal restarts the shake, it never adds to it.
## This is the one place to change its strength.
const SHAKE_TIME := 0.18
const SHAKE_SHARE := 0.01
const SHAKE_MAX_PX := 4.0   # and never more than this, on any screen
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
## True when the two home kits looked alike on a disc and the away side wears its
## clash strip, its own kit's two colours changed over (kits_for).
var clash := false
## Two disc bases this close (UiKit.colour_distance, the measure the club inks
## use) are alike on the turf. A little wider than UiKit.INK_CLASH (25): a disc is
## an 18 px dot on green, where two dark bases merge sooner than two names side by
## side do (Fremantle's purple and Melbourne's navy are 26.6 apart and read as one
## side in a pack: audit frame fre_mel_phone 005).
const DISC_CLASH := 40.0
## Two sides of one club whose strips are this close in base colour (Gold Coast's two reds) take the club's farthest colour instead.
const SIDE_CLASH := 30.0
## Discs that would overlap are drawn apart, so both numbers show. Drawing only:
## the players stay where the match has them. NUDGE_GAP is the distance two drawn
## centres are pushed toward, in disc diameters; each frame the nudge eases back
## by NUDGE_EASE and is pushed out again only as far as it must be, starting from
## where the discs were drawn last, so a pair keeps its sides and does not jitter.
## The view stays truthful: a disc is never drawn more than NUDGE_CAP (in disc
## diameters: half a disc's width) from where its player is, so in a thick pack
## discs still overlap, and the draw order keeps the ball carrier and the two
## opponents nearest him on top (lead, 2026-10-14, provisional until the director
## looks). nudge_full lifts the cap, for the comparison capture only: every disc
## fully apart, at the cost of a disc sitting up to 17 m from its player on a phone.
const NUDGE_GAP := 1.0
const NUDGE_CAP := 0.5
static var nudge_full := false
const NUDGE_EASE := 0.85
const NUDGE_PASSES := 24
var _nudge := PackedVector2Array()
var _disc := PackedVector2Array()   # where each token is drawn, in pixels
## The bench: each side's five as small discs, along the bottom of the view (the
## stand's dark band on a phone) or down the sides of the ground when the window
## is wider than the oval (a PC). BENCH_SHARE is a bench disc's size in token radii.
## Full size on a phone, where a smaller disc's number was too small to read
## (lead, 2026-10-14).
const BENCH_SHARE := 1.0
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
	_kits = kits_for(home_code, away_code)
	clash = bool((_kits[1] as Dictionary).get("clash", false))
	_nudge = PackedVector2Array()
	_disc = PackedVector2Array()
	_flip_pending = false
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
	_press_said = [false, false]
	_press_banner = {}
	_zone_fade = [0.0, 0.0]
	_ev_idx = 0
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
			_press_cue(ev)
			event_played.emit(ev)
			if str((ev as Dictionary).get("kind", "")) == "final":
				playing = false
				finished.emit()
				break
		if playing and director.idle():
			playing = false
			finished.emit()
		if _flip_pending and director.mode != "break":
			# The next period is setting up: now the sides change ends.
			_change_ends()
		_follow_ball()
	_name_the_ball_carrier()
	_age_caption(delta)
	_step_zone_fade(delta)
	if not _press_banner.is_empty():
		_press_banner["left"] = float(_press_banner["left"]) - delta
		if float(_press_banner["left"]) <= 0.0:
			_press_banner = {}
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()
	_update_camera(delta)
	if playing or _cam.distance_to(_drawn_cam) > 0.05 or absf(_zoom - _drawn_zoom) > 0.002 \
			or not director.flash.is_empty() or not _caption.is_empty() or not _press_banner.is_empty() \
			or float(_zone_fade[0]) > 0.0 or float(_zone_fade[1]) > 0.0 \
			or director.press_zone_on(0) or director.press_zone_on(1):
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
	if GameState.screen_shake_on() and not Feel.reduced:
		_shake = SHAKE_TIME


## The ball changed hands in open play: "Turnover" over the player who won it.
## A forced turnover, a rebound and an intercept mark always are; otherwise
## the side with the ball changed without a restart in between. A goal's name
## is never covered.
## The first time a pressing side defends after setting its plan: its line, on
## the oval for a moment ("<Club> push up to press."), once a side a match.
func _press_cue(ev: Dictionary) -> void:
	var idx := _ev_idx
	_ev_idx += 1
	var presser := MatchNotes.press_trigger(result.get("timeline", []), idx, ev, _press_said)
	if presser < 0:
		return
	_press_said[presser] = true
	var code := str(result.get("home") if presser == 0 else result.get("away"))
	_press_banner = {"text": MatchNotes.press_line(code), "left": PRESS_BANNER_SECS, "side": presser}


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


## Whether the oval is shaking for a goal right now.
func shaking() -> bool:
	return _shake > 0.0


## The shake as an offset in pixels now: never longer than the share of the oval's
## height, whatever the screen size; zero with the shake off.
func shake_offset() -> Vector2:
	if _shake <= 0.0 or not GameState.screen_shake_on() or Feel.reduced:
		return Vector2.ZERO
	var k := _shake / SHAKE_TIME
	var t := SHAKE_TIME - _shake
	var amp := minf(pitch_rect().size.y * shake_share, SHAKE_MAX_PX)
	return (Vector2(sin(t * 83.0), cos(t * 61.0)) * amp * k).limit_length(amp)


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


## Every break the match screen plays is a change of ends, made when play
## restarts: the siren only marks it as owed. Play that follows a break (seen
## here when events are skipped, not watched) makes the change if the restart
## has not; the final siren never does.
func _track_quarter(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if kind == "quarter":
		if _flip_pending:
			_change_ends()
		_flip_pending = true
	elif _flip_pending and not ["final", "sub", "moment", "injury"].has(kind):
		_change_ends()


func _change_ends() -> void:
	_flip_pending = false
	period += 1
	# The picture mirrors along the ground's length, and so does each disc's nudge.
	for i in range(_nudge.size()):
		_nudge[i] = Vector2(_nudge[i].x, -_nudge[i].y) if upright else Vector2(-_nudge[i].x, _nudge[i].y)
	ends_changed.emit(period)
	queue_redraw()


## The two kits the discs wear. The home side wears its own. The away side does
## too unless its base colour looks like the home side's on a disc (DISC_CLASH,
## UiKit.colour_distance between the two bases): then it wears its clash strip,
## its own kit with the two colours changed over (Melbourne red with a navy yoke,
## Richmond yellow with a black sash, West Coast gold), as the real clubs do.
## Only the club's own kit colours are ever used (lead, 2026-10-14: UiKit's
## second inks are lifted for text and on a disc were not the club's colours). A
## kit whose pattern colour is no farther from the home base than its base
## (a created club, say) is left as it is: no colour is invented.
static func kits_for(home: String, away: String) -> Array:
	if GameDB.is_side(home) or GameDB.is_side(away):
		dress_sides(GameDB.side_base(home))
		dress_sides(GameDB.side_base(away))
	var h: Dictionary = with_trim(home, GameDB.club_guernsey(home))
	var a: Dictionary = with_trim(away, GameDB.club_guernsey(away))
	if disc_distance(h, a) >= DISC_CLASH:
		return [h, a]
	# Too alike on the turf: the away side tries its clash strips (its own kit's
	# two colours changed over; for a three-colour club its third colour as the
	# body) and wears the one farthest from the home side's disc.
	var best: Dictionary = a
	var best_d := disc_distance(h, a)
	var options := clash_options(away, a)
	if GameDB.side_base(home) == GameDB.side_base(away):
		# A club against itself (an intra-club match): the strip is only its own
		# two colours changed over, so a side's ink matches the strip it wears.
		options = options.slice(0, 1) if UiKit.colour_distance(a.get("base", Color.WHITE), a.get("pattern", Color.WHITE)) > 12.0 else []
	for c in options:
		var d := disc_distance(h, c)
		if d > best_d + 0.01:
			best = c
			best_d = d
	if best != a:
		best["clash"] = true
	return [h, best]


## The away side's clash strips: the kit's base and pattern changed over, and
## (only for a club whose third colour is a real one) the third colour as the
## body with the base as the pattern. Only the club's own colours are used.
static func clash_options(code: String, kit: Dictionary) -> Array:
	var out := []
	var base: Color = kit.get("base", Color.WHITE)
	var pat: Color = kit.get("pattern", Color.DIM_GRAY)
	if UiKit.colour_distance(base, pat) > 12.0:
		var sw: Dictionary = kit.duplicate()
		sw["base"] = pat
		sw["pattern"] = base
		out.append(with_trim(code, sw, true))
	# A white clash strip, as the real clubs wear (Melbourne, Hawthorn, Essendon):
	# only for a club whose third colour is white.
	var white: Color = GameDB.club_colours(GameDB.side_base(code))[2]
	if white.is_equal_approx(Color.WHITE) and UiKit.colour_distance(base, white) > 25.0:
		var w1: Dictionary = kit.duplicate()
		w1["base"] = white
		w1["pattern"] = base
		w1.erase("ring")
		out.append(w1)
		var w2: Dictionary = kit.duplicate()
		w2["base"] = white
		w2["pattern"] = pat
		w2.erase("ring")
		out.append(w2)
	var ring = kit.get("ring", null)
	if ring != null:
		var third: Dictionary = kit.duplicate()
		third["base"] = ring
		third["pattern"] = base
		third["ring"] = pat
		out.append(third)
		var third2: Dictionary = kit.duplicate()
		third2["base"] = ring
		third2["pattern"] = pat
		third2["ring"] = base
		out.append(third2)
	return out


## The third colour of a club that has one (Adelaide's gold, the Bulldogs'
## white) as a ring round the rim of the disc: it survives an 18 px disc, leaves
## the number clear, and is the one thing that tells Adelaide's navy and red
## from Melbourne's. `ring` is left out when it is the same as the body or the
## pattern (a ring that adds nothing).
static func with_trim(code: String, kit: Dictionary, keep := false) -> Dictionary:
	var out: Dictionary = kit.duplicate()
	if keep and out.has("ring"):
		return out
	out.erase("ring")
	if not GameDB.THREE_COLOUR_CLUBS.has(GameDB.side_base(code)):
		return out
	var third: Color = kit.get("pattern2", Color.WHITE)
	if UiKit.colour_distance(third, kit.get("base", Color.WHITE)) < 25.0:
		return out
	if UiKit.colour_distance(third, kit.get("pattern", Color.WHITE)) < 12.0 and str(kit.get("design", "plain")) != "plain":
		return out
	out["ring"] = third
	return out


## What a disc looks like, as colours sampled over its face (a 13 x 13 grid
## inside the circle, the kit's own geometry from _draw_kit).
static func disc_samples(kit: Dictionary) -> Array:
	var out := []
	var n := 13
	for iy in range(n):
		for ix in range(n):
			var x := (float(ix) + 0.5) / float(n) * 2.0 - 1.0
			var y := (float(iy) + 0.5) / float(n) * 2.0 - 1.0
			if x * x + y * y <= 1.0:
				out.append(kit_colour_at(kit, x, y))
	return out


## The colour of the disc at (x, y) in the unit circle: the geometry _draw_kit
## draws.
static func kit_colour_at(kit: Dictionary, x: float, y: float) -> Color:
	var base: Color = kit.get("base", Color.WHITE)
	var pat: Color = kit.get("pattern", Color.DIM_GRAY)
	var ring = kit.get("ring", null)
	var design := str(kit.get("design", "plain"))
	var d := sqrt(x * x + y * y)
	var col := base
	if ring != null and d > 0.8:
		return ring
	var r := 0.94
	match design:
		"stripes":
			for cx in [-0.55, 0.0, 0.55]:
				if absf(x - float(cx) * r) < r * 0.13:
					col = pat
		"hoops", "lowhoops", "twohoops", "tiers":
			for cy in [-0.4, 0.3]:
				if absf(y - float(cy) * r) < r * 0.15:
					col = pat
		"sash":
			if absf(x) < r * 0.75 and y - x > -r * 0.42 and y - x < r * 0.42:
				col = pat
		"yoke", "shoulders":
			if y < -0.05 * r:
				col = pat
		"band":
			if absf(y) < r * 0.22:
				col = pat
		"chevron", "chevrons", "wings":
			if absf(x) < r * 0.7 and absf(y - (-0.35 + 0.75 * (1.0 - absf(x) / (r * 0.7))) * r) < r * 0.16:
				col = pat
		"panels", "sides", "giants", "map":
			if x < 0.0:
				col = pat
		_:
			if d < 0.55:
				col = pat
	return col


## The number's two inks on a kit: white with a dark edge, or (on a light body,
## Richmond's yellow) near-black with a white edge. Judged on the colours under
## the number (the middle of the disc).
static func number_inks(kit: Dictionary) -> Array:
	var lum := 0.0
	var cnt := 0
	for dy in [-0.3, 0.0, 0.3]:
		for dx in [-0.3, 0.0, 0.3]:
			var c := kit_colour_at(kit, float(dx), float(dy))
			lum += 0.2126 * c.srgb_to_linear().r + 0.7152 * c.srgb_to_linear().g + 0.0722 * c.srgb_to_linear().b
			cnt += 1
	if lum / float(cnt) > 0.30:
		return [Color(0.05, 0.05, 0.08), Color(1, 1, 1, 0.9)]
	return [Color(1, 1, 1), Color(0, 0, 0, 0.85)]


## How different two discs look on the turf, in CIELAB: half the distance
## between their palettes (each colour on one disc to the nearest colour on the
## other, by the share of the face it covers, both ways) and half the distance
## between their body colours. Layout does not count: Melbourne's red body and
## navy yoke against Adelaide's navy body and red hoops share their colours and
## score low; a third colour or a different body raises it.
static func disc_distance(a: Dictionary, b: Dictionary) -> float:
	var pa := _palette(a)
	var pb := _palette(b)
	var chamfer := 0.5 * (_palette_gap(pa, pb) + _palette_gap(pb, pa))
	return 0.5 * chamfer + 0.5 * UiKit.colour_distance(_dominant(_palette(_bodied(a))), _dominant(_palette(_bodied(b))))


## The colours on a disc and the share of its face each covers.
static func _palette(kit: Dictionary) -> Array:
	var counts := {}
	var cells := disc_samples(kit)
	for c in cells:
		var key := (c as Color).to_html(false)
		counts[key] = int(counts.get(key, 0)) + 1
	var out := []
	for key in counts:
		out.append([Color.html(str(key)), float(counts[key]) / float(cells.size())])
	return out


static func _palette_gap(from: Array, to: Array) -> float:
	var total := 0.0
	for f in from:
		var nearest := 1000.0
		for t in to:
			nearest = minf(nearest, UiKit.colour_distance(f[0], t[0]))
		total += nearest * float(f[1])
	return total


static func _bodied(kit: Dictionary) -> Dictionary:
	var k: Dictionary = kit.duplicate()
	k.erase("ring")
	return k


static func _dominant(p: Array) -> Color:
	var best: Array = p[0]
	for e in p:
		if float(e[1]) > float(best[1]):
			best = e
	return best[0]


## invented here. Harmless to call again.
static func dress_sides(base: String) -> void:
	var codes: Array = GameDB.side_codes(base)
	if not GameDB.is_side(str(codes[1])) or (GameDB.clubs[codes[1]] as Dictionary).has("kit"):
		return
	var home: Dictionary = GameDB.club_guernsey(base)
	var second: Dictionary = kits_for(base, base)[1]
	var hb: Color = home.get("base", Color.WHITE)
	if UiKit.colour_distance(hb, second.get("base", Color.WHITE)) < SIDE_CLASH:
		# The kit's two colours are too alike to tell two sides apart (Gold
		# Coast's two reds): the second side takes the club's own colour that
		# is farthest from the first side's, still one of the club's colours.
		var far: Color = hb
		for c in GameDB.club_colours(base):
			if UiKit.colour_distance(hb, c) > UiKit.colour_distance(hb, far):
				far = c
		second = home.duplicate()
		second["base"] = far
		second["pattern"] = hb
		second["clash"] = true
	# Each side wears its strip's colour plain, like training bibs: with the
	# design kept, a kit that is half one colour and half the other (Melbourne's
	# yoke) gives two sides that are mirror images of each other on a disc and
	# cannot be told apart at match size. The colours are still the club's own.
	for kit in [home, second]:
		kit["pattern"] = kit.get("base", Color.WHITE)
		kit["pattern2"] = kit.get("base", Color.WHITE)
	GameDB.set_side_kit(str(codes[0]), home)
	GameDB.set_side_kit(str(codes[1]), second)


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
	var half := _flat_size() * 0.5 / s
	var lx := maxf(0.0, MatchMotion.HALF_LEN + 4.0 - half.x)
	var ly := maxf(0.0, MatchMotion.HALF_WID + 4.0 - half.y)
	return Vector2(clampf(c.x, -lx, lx), clampf(c.y, -ly, ly))


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------
## The view's size with the ground lying flat (left to right): the control's own
## size, or that turned when the ground is upright.
func _flat_size() -> Vector2:
	return Vector2(size.y, size.x) if upright else size


## A point of the flat frame on the screen: itself, or turned a quarter turn
## about the view's centre (what was to the right is up).
func _to_screen(p: Vector2) -> Vector2:
	if not upright:
		return p
	var v := p - _flat_size() * 0.5
	return size * 0.5 + Vector2(v.y, -v.x)


## The rect the whole oval fills at zoom 1, with the ground lying flat.
func _flat_rect() -> Rect2:
	var fsz := _flat_size()
	var margin := 10.0
	var avail := fsz - Vector2(margin, margin) * 2.0
	if avail.x <= 0.0 or avail.y <= 0.0:
		return Rect2(Vector2.ZERO, fsz)
	var w := avail.x
	var h := w / ASPECT
	if h > avail.y:
		h = avail.y
		w = h * ASPECT
	return Rect2((fsz - Vector2(w, h)) * 0.5, Vector2(w, h))


## The rect the whole oval fills at zoom 1, on the screen.
func pitch_rect() -> Rect2:
	var r := _flat_rect()
	if not upright:
		return r
	var turned := Vector2(r.size.y, r.size.x)
	return Rect2((size - turned) * 0.5, turned)


## Pixels per metre at the current zoom.
func _scale() -> float:
	return _flat_rect().size.x / (2.0 * MatchMotion.HALF_LEN) * _zoom


## Ground metres to pixels on the screen.
func _w2s(p: Vector2) -> Vector2:
	return _to_screen(_w2s_flat(p))


## Ground metres to pixels with the ground lying flat (the ground's own lines are
## drawn in this frame and turned as one).
func _w2s_flat(p: Vector2) -> Vector2:
	var m := end_sign(period)
	return _flat_size() * 0.5 + Vector2((p.x - _cam.x) * m, p.y - _cam.y) * _scale()


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
	if _shake > 0.0:
		# Fades out as it ends; timed by the shake itself so a recording shows it as played.
		draw_set_transform(shake_offset())
	var r := pitch_rect()
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	_drawn_cam = _cam
	_drawn_zoom = _zoom
	var s := _scale()
	var c := _w2s_flat(Vector2.ZERO)
	var a := MatchMotion.HALF_LEN * s
	var b := MatchMotion.HALF_WID * s

	# The stand, dark, beyond the fence; the fence a band at the turf's edge.
	draw_rect(Rect2(Vector2.ZERO, size), STAND_COLOUR, true)
	# The ground itself (turf, lines, posts) is drawn lying flat and, upright,
	# turned as one piece: a quarter turn about the view's centre.
	var jolt := shake_offset() if _shake > 0.0 else Vector2.ZERO
	if upright:
		draw_set_transform_matrix(Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, size.y) + jolt))
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
	_draw_press_zone(c, a, b)
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
		var goal := _w2s_flat(Vector2(sgn * GOAL_LINE_M, 0.0))
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

	if upright:
		draw_set_transform(jolt)
	# Rain falls and wind blows over the ground, under the players and the ball.
	var now := float(Time.get_ticks_msec()) / 1000.0
	VignetteWeather.draw_air(self, r, now, weather)
	if weather == VignetteWeather.WINDY:
		VignetteWeather.draw_wind_flat(self, r, now)
	var tr := token_radius()
	_layout_discs(tr)
	_draw_bench(tr)
	_draw_tokens(tr)
	_draw_rings(tr)
	if _figs != null:
		_figs.slots = _figure_slots(tr) if mini_figures else []
		_figs.queue_redraw()

	# Actor highlight
	var act := director.actor
	if act >= 0 and act < director.tokens.size():
		var p := _disc_at(act)
		draw_arc(p, tr * 1.9, 0, TAU, 28, Color(1, 1, 0.55, 0.95), 2.0, antialias)

	_draw_ball(tr, s)

	# Goal / behind flash
	var fl := director.flash
	if not fl.is_empty():
		var t := 1.0 - clampf(float(fl["left"]) / 0.9, 0.0, 1.0)
		var rad2 := lerpf(tr, minf(a, b) * 0.42, t)
		var col := Color(1.0, 0.92, 0.35) if fl["goal"] else Color(0.85, 0.9, 1.0)
		col.a = (1.0 - t) * 0.85
		var at := _w2s(fl["pos"])
		rad2 = minf(rad2, flash_room(at, tr))
		draw_arc(at, rad2, 0, TAU, 48, col, 4.0, antialias)
	_draw_role_labels(tr)
	_draw_caption(tr)
	_draw_press_banner()


## The press zone: a wash of the press club's own colour over the part of the
## ground it is hunting, under the lines, the players and the ball. Its
## strength is the sim's own zone table (MatchDirector.press_zone_field,
## soft-edged); it eases in and out over PRESS_FADE_SECS of real time; the
## oval's edge is untouched. At the full strength of the opponents' back
## third it has to read on a phone without the unpressed ground beside it
## (director, 2026-10-13: the first 0.12 moved a channel by 8-11 of 255 and
## read as a darker turf stripe), so it was a 40% mix of the colour; the
## director then judged that too heavy ("right colour, about half as strong"),
## so the grass and its mowing stripes now show through. Half (0.2) was tried
## and lost the colours: through the green only the strength is halved, the hue
## goes slate (Fremantle), teal (Bulldogs, Melbourne, Carlton) and olive (St
## Kilda, Hawthorn). 0.3 is the least that still reads as each club's colour.
const PRESS_ZONE_ALPHA := 0.3
## The strength the colour is worked out at (what the club colour would be at
## a 40% mix), so the colour is the same hue and the strength the one above.
const PRESS_COLOUR_ALPHA := 0.4
const PRESS_FADE_SECS := 0.9
var _zone_fade := [0.0, 0.0]
var _press_said := [false, false]
var _caption_rect = null       # where the caption was drawn last (the press line steps clear of it)
var _press_banner := {}        # {text, left}: "<Club> push up to press."
var _ev_idx := 0
const PRESS_BANNER_SECS := 3.5


## The wash eases (smoothstep) rather than moving linearly.
static func ease_fade(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


func _step_zone_fade(delta: float) -> void:
	for side in [0, 1]:
		var on: bool = director.press_zone_on(side)
		_zone_fade[side] = move_toward(float(_zone_fade[side]), 1.0 if on else 0.0, delta / PRESS_FADE_SECS)


func _draw_press_zone(c: Vector2, a: float, b: float) -> void:
	for side in [0, 1]:
		var fade := ease_fade(float(_zone_fade[side]))
		if fade <= 0.003:
			continue
		var base := press_zone_colour(home_code if side == 0 else away_code)
		var dir := MatchDirector._dir(side)
		# Slices across the oval, each a quad with a colour at both ends, so the
		# strength varies smoothly with no seam and no snap to a turf stripe.
		var n := 56
		var lo := -MatchMotion.HALF_LEN
		var hi := MatchMotion.HALF_LEN
		for i in range(n):
			var wx0 := lerpf(lo, hi, float(i) / float(n))
			var wx1 := lerpf(lo, hi, float(i + 1) / float(n))
			var k0 := MatchDirector.press_zone_field(wx0 * dir)
			var k1 := MatchDirector.press_zone_field(wx1 * dir)
			if k0 <= 0.002 and k1 <= 0.002:
				continue
			var x0 := _w2s_flat(Vector2(wx0, 0.0)).x
			var x1 := _w2s_flat(Vector2(wx1, 0.0)).x
			var xl := minf(x0, x1)
			var xr := maxf(x0, x1)
			var left_k := k0 if x0 <= x1 else k1
			var right_k := k1 if x0 <= x1 else k0
			var q := _stripe(c, a, b, xl, xr)
			var cols := PackedColorArray()
			for p in q:
				var t := 0.0 if xr <= xl else clampf((p.x - xl) / (xr - xl), 0.0, 1.0)
				cols.append(Color(base.r, base.g, base.b, PRESS_ZONE_ALPHA * fade * lerpf(left_k, right_k, t)))
			draw_polygon(q, cols)


## The turf the wash sits on, for working out what colour to lay over it.
const PRESS_TURF := Color(0.118, 0.333, 0.133)
## Which of a club's colours it is known by, as UiKit.club_ink chooses it
## (INK_SLOT on claude/break-best-so-far, PR #666): the first, except the
## Bulldogs and Essendon, whose second is the one a supporter names; -1 is a
## club with no hue (Collingwood). Kept here so the two can be unified once
## #666 is on main; this file does not touch UiKit.
const PRESS_INK_SLOT := {"WBD": 1, "ESS": 1, "COL": -1}
## What the wash should look like once mixed with the turf: the club's hue,
## saturated, at about the turf's own lightness, so the grass is still grass
## and the colour still the club's.
const PRESS_TARGET_V := 0.64
## A club with no hue (Collingwood, or a custom club in black and white): a
## dark, cool wash, the zone's shape carrying the rest.
const PRESS_NO_HUE := Color(0.02, 0.03, 0.07)


## The colour to lay over the turf at PRESS_COLOUR_ALPHA so the mix lands on the
## club's colour at turf lightness: the plain colour of a dark club (navy,
## brown, deep purple) would only darken the grass, and a plain blue or red
## drifts to teal or brown through the green beneath it. Worked back from the
## mix, kept in range.
static func press_zone_colour(code: String) -> Color:
	var cols: Array = GameDB.club_colours(code)
	var slot := int(PRESS_INK_SLOT.get(GameDB.side_base(code), 0))
	if slot < 0:
		return PRESS_NO_HUE
	var pick: Color = cols[slot]
	if pick.s < 0.25:
		# A custom club whose first colour is black or white: its most saturated.
		pick = Color(0, 0, 0, 0)
		var best := 0.25
		for c in cols:
			var col: Color = c
			if col.s > best:
				best = col.s
				pick = col
		if pick.a == 0.0:
			return PRESS_NO_HUE
	var target := Color.from_hsv(pick.h, clampf(pick.s, 0.6, 0.85), PRESS_TARGET_V)
	var w := (Vector3(target.r, target.g, target.b) - Vector3(PRESS_TURF.r, PRESS_TURF.g, PRESS_TURF.b) * (1.0 - PRESS_COLOUR_ALPHA)) / PRESS_COLOUR_ALPHA
	return Color(clampf(w.x, 0.0, 1.0), clampf(w.y, 0.0, 1.0), clampf(w.z, 0.0, 1.0))


## A thin light ring on each of your players with a call on him or a run
## promised. Quieter than the actor's ring, which stays the one that moves.
func _draw_rings(tr: float) -> void:
	if rings.is_empty():
		return
	for t in director.tokens:
		if float(t["down"]) > 0.0 or not rings.has(str(t.get("pid", ""))):
			continue
		var p := _disc_at(int(t["id"]))
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
	for l in role_label_layout(tr, fs):
		var text := str(l["text"])
		var origin: Vector2 = l["origin"]
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(UiKit.BOLD, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(UiKit.BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))


## Where each surname goes: [{id, text, origin, rect}]. Under its disc first;
## when that would sit on another name or on another player's disc (and its
## number) it moves to above, beside, or further below; a name with no clear
## place is left out, except the ball carrier's, which is always written (the
## nearest clear place, else under his disc).
func role_label_layout(tr: float, fs: int) -> Array:
	var named := {}
	for id in director.role_labels():
		named[int(id)] = 1
	var holder := int(director.ball.get("holder", -1)) if not director.ball.is_empty() else -1
	if holder >= 0:
		named[holder] = -1
	if not rings.is_empty():
		for i in range(director.tokens.size()):
			if rings.has(str(director.tokens[i].get("pid", ""))):
				named[i] = 0 if not named.has(i) else mini(int(named[i]), 0)
	var ids := named.keys()
	# The ball carrier first, then ringed players, then the rest, so the
	# important names claim their place before the others.
	ids.sort_custom(func(x, y): return int(named[x]) < int(named[y]) or (int(named[x]) == int(named[y]) and int(x) < int(y)))
	var discs := []
	for i in range(director.tokens.size()):
		discs.append(_disc_at(i))
	var placed := []
	var out := []
	for id in ids:
		if id < 0 or id >= director.tokens.size():
			continue
		var t: Dictionary = director.tokens[id]
		if float(t.get("down", 0.0)) > 0.0:
			continue
		var text := str(t.get("surname", ""))
		if text == "":
			continue
		var width := UiKit.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = discs[id]
		if p.x < -width or p.y < 0.0 or p.x > size.x + width or p.y > size.y + float(fs) * 2.0:
			continue
		var h := float(fs)
		var spots := [
			Vector2(-width * 0.5, tr * 1.25 + h),
			Vector2(-width * 0.5, -tr * 1.25 - 3.0),
			Vector2(tr * 1.3, h * 0.35),
			Vector2(-tr * 1.3 - width, h * 0.35),
			Vector2(-width * 0.5, tr * 1.25 + h * 2.1),
			Vector2(-width * 0.5, -tr * 1.25 - h - 3.0),
			Vector2(tr * 1.3, h * 1.5),
			Vector2(-tr * 1.3 - width, h * 1.5),
			Vector2(tr * 1.3, -h * 0.7),
			Vector2(-tr * 1.3 - width, -h * 0.7),
			Vector2(-width * 0.5, tr * 1.25 + h * 3.3),
			Vector2(-width * 0.5, -tr * 1.25 - h * 2.3),
		]
		var chosen = null
		for off in spots:
			var origin: Vector2 = p + off
			origin.x = clampf(origin.x, 2.0, maxf(2.0, size.x - width - 2.0))
			var rect := Rect2(origin + Vector2(-1, -h), Vector2(width + 2.0, h + 3.0))
			if _label_clear(rect, id, placed, discs, tr):
				chosen = [origin, rect]
				break
		if chosen == null:
			if int(id) != holder:
				continue
			var origin0: Vector2 = p + spots[0]
			origin0.x = clampf(origin0.x, 2.0, maxf(2.0, size.x - width - 2.0))
			chosen = [origin0, Rect2(origin0 + Vector2(-1, -h), Vector2(width + 2.0, h + 3.0))]
		placed.append(chosen[1])
		out.append({"id": id, "text": text, "origin": chosen[0], "rect": chosen[1]})
	return out


## A name's box clear of every name already placed and of every other player's
## disc (so no name runs over a number).
func _label_clear(rect: Rect2, id: int, placed: Array, discs: Array, tr: float) -> bool:
	for r in placed:
		if rect.intersects(r as Rect2):
			return false
	for i in range(discs.size()):
		if i == id or float(director.tokens[i].get("down", 0.0)) > 0.0:
			continue
		var c: Vector2 = discs[i]
		var nx := clampf(c.x, rect.position.x, rect.end.x)
		var ny := clampf(c.y, rect.position.y, rect.end.y)
		if Vector2(nx, ny).distance_to(c) < tr:
			return false
	return true


func _draw_press_banner() -> void:
	if _press_banner.is_empty():
		return
	var text := str(_press_banner["text"])
	var fs := 20
	var font := UiKit.BOLD
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := Vector2(clampf((size.x - width) * 0.5, 4.0, maxf(4.0, size.x - width - 4.0)), float(fs) + 10.0)
	# Never over the "Turnover" / name caption: if they would meet, the line
	# steps below it.
	if _caption_rect != null:
		var mine := Rect2(origin - Vector2(4, float(fs)), Vector2(width + 8.0, float(fs) + 8.0))
		if mine.intersects(_caption_rect as Rect2):
			origin.y = (_caption_rect as Rect2).end.y + float(fs) + 6.0
	var fade := clampf(float(_press_banner["left"]) / 0.4, 0.0, 1.0)
	# Plain text with a soft dark shadow and an outline: no pill.
	for off in [Vector2(0, 2), Vector2(1, 2), Vector2(-1, 2)]:
		draw_string(font, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * fade))
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		draw_string(font, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * fade))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade))


func _draw_caption(tr: float) -> void:
	_caption_rect = null
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
	var p := _disc_at(tok)
	var origin := caption_origin(p, width, fs, tr)
	_caption_rect = Rect2(origin - Vector2(4, float(fs)), Vector2(width + 8.0, float(fs) + 10.0))
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


## Where a caption (a scorer's name, "Turnover") is written for the player at
## `p`: above him, and above every disc it would otherwise cover, with a clear
## gap, so the call never hides the players round the ball (lead, 2026-10-14). If
## the pack reaches the top of the view it goes below the pack instead. Returns
## the text's baseline origin; the caption's box is CAPTION_BOX_BELOW deeper
## (the underline) and its own height taller.
const CAPTION_GAP := 4.0
const CAPTION_BOX_BELOW := 10.0
func caption_origin(p: Vector2, width: float, fs: int, tr: float) -> Vector2:
	var x := clampf(p.x - width * 0.5, 4.0, maxf(4.0, size.x - width - 4.0))
	var up := _caption_clear(Vector2(x, p.y - tr * 2.4), width, fs, tr, -1.0)
	if up.y >= float(fs) + 2.0:
		return up
	var down := _caption_clear(Vector2(x, p.y + tr * 2.4 + float(fs)), width, fs, tr, 1.0)
	if down.y + CAPTION_BOX_BELOW <= size.y - 2.0:
		return down
	return Vector2(x, maxf(up.y, float(fs) + 2.0))


## Move a caption up (dir -1) or down (dir 1) until its box touches no disc.
func _caption_clear(origin: Vector2, width: float, fs: int, tr: float, dir: float) -> Vector2:
	for pass_no in range(12):
		var box := Rect2(origin.x - 4.0, origin.y - float(fs), width + 8.0, float(fs) + CAPTION_BOX_BELOW)
		var grown := box.grow(tr + CAPTION_GAP)
		var moved := false
		for d in _disc:
			if not grown.has_point(d):
				continue
			if dir < 0.0:
				origin.y = minf(origin.y, d.y - tr - CAPTION_GAP - CAPTION_BOX_BELOW - 0.5)
			else:
				origin.y = maxf(origin.y, d.y + tr + CAPTION_GAP + float(fs) + 0.5)
			moved = true
		if not moved:
			break
	return origin


## The caption's box as it would be drawn now, or an empty rect: for tests.
func caption_box() -> Rect2:
	if _caption.is_empty():
		return Rect2()
	var tok := int(_caption["tok"])
	var text := str(_caption["text"])
	if text == "" or tok < 0 or tok >= director.tokens.size():
		return Rect2()
	var tr := token_radius()
	var turnover := bool(_caption.get("turnover", false))
	var fs := clampi(int(tr * (2.1 if turnover else 1.6)), 15 if turnover else 11, 20 if turnover else 15)
	var width := UiKit.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := caption_origin(_disc_at(tok), width, fs, tr)
	return Rect2(origin - Vector2(4, float(fs)), Vector2(width + 8.0, float(fs) + CAPTION_BOX_BELOW))


func _draw_ball(tr: float, s: float) -> void:
	if director.ball.is_empty():
		return
	# A short trail on the turf, brightest at the ball, gone a moment later.
	if _trail.size() >= 2:
		for i in range(1, _trail.size()):
			var k := float(i) / float(_trail.size() - 1)
			draw_line(_w2s(_trail[i - 1]), _w2s(_trail[i]), Color(0.98, 0.93, 0.75, 0.55 * k),
					maxf(1.0, tr * 0.22 * k), antialias)
	var ground := ball_point()
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


## How big the goal's ring may grow at `at` and stay in the view and off the
## bench: upright, a goal is a few pixels from the top or bottom edge, and a ring
## sized for the ground ran off the screen and over the bench in the corners.
func flash_room(at: Vector2, tr: float) -> float:
	var room := minf(minf(at.x, size.x - at.x), minf(at.y, size.y - at.y)) - 3.0
	for sp in bench_spots(tr):
		var r: float = sp["r"]
		room = minf(room, (sp["pos"] as Vector2).distance_to(at) - r - 6.0)
	return maxf(tr, room)


## The radius a player's disc is drawn at, in pixels.
func token_radius() -> float:
	var r := pitch_rect()
	return maxf(TOKEN_MIN, minf(r.size.x, r.size.y) * 0.5 * 0.030 * sqrt(_zoom))


## Where token `id` is drawn: his place on the ground, nudged clear of a disc
## he would overlap (_layout_discs).
func _disc_at(id: int) -> Vector2:
	if id >= 0 and id < _disc.size():
		return _disc[id]
	return _w2s(director.tokens[id]["pos"])


## Work out where every disc is drawn this frame. Two discs closer than a
## diameter are moved apart along the line between them, half each, until none
## overlap; the move is kept from frame to frame and eases away once the players
## part. The match's own positions are never touched.
func _layout_discs(tr: float) -> void:
	var n := director.tokens.size()
	if _nudge.size() != n:
		_nudge.resize(n)
		_nudge.fill(Vector2.ZERO)
	var real := PackedVector2Array()
	real.resize(n)
	var pos := PackedVector2Array()
	pos.resize(n)
	for i in range(n):
		real[i] = _w2s(director.tokens[i]["pos"])
		_nudge[i] *= NUDGE_EASE
		pos[i] = real[i] + _nudge[i]
	var want := tr * 2.0 * NUDGE_GAP
	var cap := INF if nudge_full else tr * 2.0 * NUDGE_CAP
	for pass_no in range(NUDGE_PASSES):
		var moved := false
		for i in range(n):
			for j in range(i + 1, n):
				var d := pos[j] - pos[i]
				if absf(d.x) >= want or absf(d.y) >= want:
					continue
				var dist := d.length()
				if dist >= want:
					continue
				# Two on the very same spot part along a line of their own, the
				# same one every frame.
				var dir := d / dist if dist > 0.01 else Vector2.RIGHT.rotated(float(i * 7 + j))
				var push := (want - dist) * 0.5 + 0.02
				pos[i] -= dir * push
				pos[j] += dir * push
				moved = true
		if not moved:
			break
		if cap < INF:
			for i in range(n):
				var off := pos[i] - real[i]
				if off.length() > cap:
					pos[i] = real[i] + off.limit_length(cap)
	for i in range(n):
		_nudge[i] = pos[i] - real[i]
	_disc = pos


## The order the discs are drawn in, last on top: the farthest from the ball
## first, and last of all the two opponents nearest the man with the ball, then
## the man himself, so where discs still overlap the ones that matter show whole.
func draw_order() -> Array:
	var n := director.tokens.size()
	var ball_pos: Vector2 = director.ball.get("pos", Vector2.ZERO)
	var carrier := int(director.ball.get("holder", -1))
	if carrier < 0 or carrier >= n:
		carrier = director.actor if director.actor >= 0 and director.actor < n else -1
	var rows := []
	for i in range(n):
		rows.append([(director.tokens[i]["pos"] as Vector2).distance_squared_to(ball_pos), i])
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var out := []
	for r in rows:
		out.append(int(r[1]))
	if carrier >= 0:
		var side := int(director.tokens[carrier]["side"])
		var at: Vector2 = director.tokens[carrier]["pos"]
		var opp := []
		for i in range(n):
			if int(director.tokens[i]["side"]) != side:
				opp.append([(director.tokens[i]["pos"] as Vector2).distance_squared_to(at), i])
		opp.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
		var top := []
		for k in range(mini(2, opp.size()) - 1, -1, -1):
			top.append(int(opp[k][1]))
		top.append(carrier)
		for id in top:
			out.erase(id)
			out.append(id)
	return out


## The player whose disc is drawn at `p` (a point in this view), -1 for none: the
## one drawn on top where discs overlap. For a tap on the oval.
func disc_at_point(p: Vector2) -> int:
	var tr := token_radius()
	var order := draw_order()
	for k in range(order.size() - 1, -1, -1):
		var id := int(order[k])
		if _disc_at(id).distance_to(p) <= tr * 1.25:
			return id
	return -1


## Where the discs are drawn now, for tests and the capture tool: a layout
## step exactly as a drawn frame makes it.
func disc_positions() -> PackedVector2Array:
	_layout_discs(token_radius())
	return _disc


## The bench as it is drawn: [{side, num, pid, pos, r, column}], five a side while
## the match says who they are (an old result without its bench shows none). The
## home side's are on the left, the away side's on the right, whichever end they
## kick to. Down the sides of the ground when the view is wider than the oval,
## otherwise along the bottom of the view.
func bench_spots(tr: float) -> Array:
	var out := []
	if director == null or director.bench.size() < 2:
		return out
	var br := maxf(7.0, tr * BENCH_SHARE)
	var s := _scale()
	var fence := maxf(3.0, 2.0 * s)
	var side_band := size.x * 0.5 - (MatchMotion.HALF_WID if upright else MatchMotion.HALF_LEN) * s - fence
	var column := side_band >= br * 2.0 + 10.0
	var step := br * 2.0 + 4.0
	for side in range(2):
		var list: Array = director.bench[side]
		for i in range(list.size()):
			var p: Vector2
			if column:
				var x := side_band * 0.5 if side == 0 else size.x - side_band * 0.5
				p = Vector2(x, size.y * 0.5 + (float(i) - float(list.size() - 1) * 0.5) * step)
			else:
				var x2 := 6.0 + br + float(i) * step
				p = Vector2(x2 if side == 0 else size.x - x2, size.y - br - 5.0)
			out.append({"side": side, "num": int(list[i]["num"]), "pid": str(list[i].get("pid", "")),
					"pos": p, "r": br, "column": column})
	return out


func _draw_bench(tr: float) -> void:
	var spots := bench_spots(tr)
	if spots.is_empty():
		return
	var br: float = spots[0]["r"]
	var fs := int(clampf(br * 1.1, 9.0, 13.0))
	var word := "Bench"
	var ww := UiKit.BOLD.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if not bool(spots[0]["column"]):
		# In the bottom corners, where the oval's curve leaves the stand showing: a
		# dark backing under each five so they read over whatever is under them,
		# and the word above each.
		var wide := 6.0 + 5.0 * (br * 2.0 + 4.0)
		var tall := br * 2.0 + 24.0
		draw_rect(Rect2(0.0, size.y - tall, wide, tall), Color(STAND_COLOUR, 0.82))
		draw_rect(Rect2(size.x - wide, size.y - tall, wide, tall), Color(STAND_COLOUR, 0.82))
		draw_string(UiKit.BOLD, Vector2(6.0, size.y - br * 2.0 - 10.0), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(RING_COLOUR, 0.6))
		draw_string(UiKit.BOLD, Vector2(size.x - 6.0 - ww, size.y - br * 2.0 - 10.0), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(RING_COLOUR, 0.6))
	else:
		for side in range(2):
			var top := INF
			var x := 0.0
			for sp in spots:
				if int(sp["side"]) == side:
					top = minf(top, (sp["pos"] as Vector2).y)
					x = (sp["pos"] as Vector2).x
			if top < INF:
				draw_string(UiKit.BOLD, Vector2(x - ww * 0.5, top - br - 6.0), word,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(RING_COLOUR, 0.6))
	for sp in spots:
		_draw_disc(sp["pos"], br, _kits[int(sp["side"])], str(sp["num"]), fs)


## One disc: the kit, a dark edge, and the number in white with a full dark edge
## (eight directions) so it reads on a white stripe as well as on navy.
func _draw_disc(p: Vector2, r: float, kit: Dictionary, label: String, fs: int) -> void:
	paint_disc(self, p, r, kit, label, fs, antialias)


static func paint_disc(ci: CanvasItem, p: Vector2, r: float, kit: Dictionary, label: String, fs: int, aa: bool) -> void:
	ci.draw_circle(p + Vector2(0, r * 0.22), r, Color(0, 0, 0, 0.28))
	paint_kit(ci, p, r, kit, aa)
	ci.draw_circle(p, r, Color(0, 0, 0, 0.45), false, 1.2, aa)
	if label == "":
		return
	var font := UiKit.BOLD
	var inks := number_inks(kit)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var origin := p + Vector2(-w * 0.5, fs * 0.36)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
			Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		ci.draw_string(font, origin + off, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, inks[1])
	ci.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, inks[0])


## Where the ball is drawn on the turf, in pixels: in a player's hands it goes
## where his disc is drawn.
func ball_point() -> Vector2:
	var ground := _w2s(director.ball.get("pos", Vector2.ZERO))
	var holder := int(director.ball.get("holder", -1))
	if str(director.ball.get("mode", "")) == "held" and holder >= 0 and holder < _nudge.size():
		ground += _nudge[holder]
	return ground


## A side's tokens: a disc in the club's home kit (its base colour and its
## design in the pattern colour), the number on it in white with a dark edge
## so it reads on any kit, dropped when the disc is under 18 px.
func _draw_tokens(tr: float) -> void:
	var font := UiKit.BOLD
	var fs := int(clampf(tr * 1.1, 9.0, 15.0))
	for id in draw_order():
		var t: Dictionary = director.tokens[id]
		var kit: Dictionary = _kits[int(t["side"])]
		var base: Color = kit.get("base", Color.WHITE)
		var p := _disc_at(int(t["id"]))
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
		var inks := number_inks(kit)
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
				Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_string(font, origin + off, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, inks[1])
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, inks[0])


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
		var p := _disc_at(i)
		if p.x < -tr * 4.0 or p.y < -tr * 4.0 or p.x > size.x + tr * 4.0 or p.y > size.y + tr * 4.0:
			continue
		var vel: Vector2 = t.get("vel", Vector2.ZERO)
		var moving := vel.length() > 0.6
		var anim := "jog" if moving else "idle"
		var facing := "front"
		var mirror := false
		if moving:
			# Which way he runs on the screen (turned with the ground).
			var sv := Vector2(vel.x * m, vel.y)
			if upright:
				sv = Vector2(sv.y, -sv.x)
			if absf(sv.x) > absf(sv.y):
				facing = "side_l"
				mirror = sv.x > 0.0
			else:
				facing = "back" if sv.y < 0.0 else "front"
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
	paint_kit(self, p, tr, kit, antialias)


## The kit on any canvas item (the oval's discs, the audit board).
static func paint_kit(ci: CanvasItem, p: Vector2, tr: float, kit: Dictionary, aa: bool) -> void:
	var base: Color = kit.get("base", Color.WHITE)
	var pat: Color = kit.get("pattern", Color.DIM_GRAY)
	var design := str(kit.get("design", "plain"))
	ci.draw_circle(p, tr, base)
	var r := tr * 0.94
	match design:
		"stripes":
			for x in [-0.55, 0.0, 0.55]:
				var cx := float(x) * r
				var half := sqrt(maxf(0.0, r * r - cx * cx)) * 0.98
				ci.draw_rect(Rect2(p + Vector2(cx - r * 0.13, -half), Vector2(r * 0.26, half * 2.0)), pat)
		"hoops", "lowhoops", "twohoops", "tiers":
			for y in [-0.4, 0.3]:
				var cy := float(y) * r
				var half := sqrt(maxf(0.0, r * r - cy * cy)) * 0.98
				ci.draw_rect(Rect2(p + Vector2(-half, cy - r * 0.15), Vector2(half * 2.0, r * 0.3)), pat)
		"sash":
			var w := r * 0.42
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.75, -r * 0.75 + w), p + Vector2(-r * 0.75, -r * 0.75),
					p + Vector2(r * 0.75, r * 0.75 - w), p + Vector2(r * 0.75, r * 0.75)]), pat)
		"yoke", "shoulders":
			# The top near-half, so the two colours read at 18 px: the arc from
			# chord end to chord end (the chord closes it), never a bow-tie.
			var pts := PackedVector2Array()
			var lift := asin(0.05)
			for i in range(15):
				var ang := lerpf(PI + lift, TAU - lift, float(i) / 14.0)
				pts.append(p + Vector2(cos(ang) * r, sin(ang) * r))
			ci.draw_colored_polygon(pts, pat)
		"band":
			ci.draw_rect(Rect2(p + Vector2(-r * 0.98, -r * 0.22), Vector2(r * 1.96, r * 0.44)), pat)
		"chevron", "chevrons", "wings":
			ci.draw_polyline(PackedVector2Array([p + Vector2(-r * 0.7, -r * 0.35), p + Vector2(0, r * 0.4),
					p + Vector2(r * 0.7, -r * 0.35)]), pat, maxf(2.0, r * 0.32), aa)
		"panels", "sides", "giants", "map":
			var pts := PackedVector2Array()
			for i in range(17):
				var ang := PI * 0.5 + PI * float(i) / 16.0
				pts.append(p + Vector2(cos(ang) * r, sin(ang) * r))
			ci.draw_colored_polygon(pts, pat)
		_:
			ci.draw_circle(p, tr * 0.55, pat)
	var ring = kit.get("ring", null)
	if ring != null:
		# The club's third colour round the rim, clear of the number.
		ci.draw_arc(p, tr * 0.88, 0.0, TAU, 28, ring, maxf(2.0, tr * 0.2), aa)


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
	snap["drawn"] = _disc
	snap["bench"] = director.bench
	snap["ball_screen"] = _w2s(director.ball.get("pos", Vector2.ZERO))
	return snap


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_cam = _clamp_cam(_cam)
		queue_redraw()
