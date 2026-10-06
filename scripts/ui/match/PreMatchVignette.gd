class_name PreMatchVignette
extends StoppageVignette
## The minutes before the first bounce, played over the seconds after Play
## match while the round is prepared (playtest for ARD-M8-007). A low camera
## behind your side: your players warm up, gather for final instructions,
## then run through the banner - the run starts when the match is ready, not
## on a timer, so it hides the wait instead of adding one. The opposition
## warms up beyond the banner. Real clubs, colours and numbers; nothing about
## the match itself. Same drawing as the centre-bounce scene.

signal done

enum { WARM, HUDDLE, RUN }
## The gathering: each man finishes what he's doing (up to GATHER_LAG s), then jogs
## easy into his place in the huddle at his own pace (GATHER_PACE m/s on average), from
## his own side of it - nearest in first, nobody sprinting or cutting across, and in
## and still before they go (director: no bunching up right before the run).
const GATHER_LAG := 0.4
const GATHER_PACE := Vector2(3.0, 3.6)
## Progress at which they gather in (set_progress): HubScene's PRE_MATCH_SECONDS gives
## the furthest man time to get there and the huddle a moment together.
const HUDDLE_FROM := 0.2
## Through the banner: they run, the camera follows them through, then black.
const RUN_TIME := 2.4
const BANNER_Y := 16.0
## Half the banner's width: a run-through is a great sheet of crepe paper, 18 m by 6.5 m.
const BANNER_W := 9.0
## The whole team runs out: the 18 on the ground and the interchange (director).
const SQUAD := 23
## Where the huddle gathers (metres across, ahead of the camera's ground point).
const HUDDLE_AT := Vector2(0.0, 5.5)
## The camera: low behind the warm-up, and where it follows them to, through the banner.
const CAM_START := 6.5
const CAM_THROUGH := BANNER_Y + 3.5

## The words under the scene, in the order they appear. Atmosphere only: none
## of them says anything about the match. A final opens with its own line.
const WORDS_WARM := "Warming up"
const WORDS_FINALS := "Finals footy. Here we go."
const WORDS_HUDDLE := "Final instructions"
const WORDS_RUN := "Through the banner"

var copy := WORDS_WARM
var banner := ""
var _phase := WARM
var _prev := WARM
var _since := 0.0          # time the phase began
var _huddle_since := -1.0  # when they began to gather in (-1: not yet)
var _slots := []           # each of yours: his place in the huddle (Vector2, metres)
var _progress := 0.0
var _left_at := -1.0       # when the scene went black, waiting for the match
var _scene_then: Node = null
var _auto := -1.0          # play_through: seconds until the run (-1: off)
var _mine := 0             # how many of the tokens are yours (they come first)
var _cross_cache := []     # where and when each of yours goes through the banner


## The scene on its own layer over whatever is showing, so it stays up while
## the match screen replaces the hub underneath it.
static func open(host: Node, my_code: String, opp_code: String, my_ground: Array,
		opp_ground: Array, heading: String, final := false, banner_ctx := {}) -> PreMatchVignette:
	var layer := CanvasLayer.new()
	layer.name = "PreMatch"
	layer.layer = 90
	host.add_child(layer)
	var v := PreMatchVignette.new()
	v.name = "PreMatchVignette"
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.setup_prematch(my_code, opp_code, my_ground, opp_ground, heading, final, banner_ctx)
	return v


## Finals footy: the fixture is a final. Every final's label says so ("Semi
## Final 1", "Grand Final"); a home-and-away round's ("Round 24") never does,
## and a missing label is not a final.
static func is_final(label: String) -> bool:
	return label.contains("Final")


func setup_prematch(my_code: String, opp_code: String, my_ground: Array, opp_ground: Array,
		heading: String, final := false, banner_ctx := {}) -> void:
	title = heading
	copy = WORDS_FINALS if final else WORDS_WARM
	banner = banner_text(my_code, opp_code, heading, banner_ctx)
	_colours = [GameDB.club_colours(my_code), GameDB.club_colours(opp_code)]
	_codes = [my_code, opp_code]
	tokens.clear()
	_mine = mini(SQUAD, my_ground.size())
	for p in my_ground.slice(0, SQUAD):
		tokens.append({"side": 0, "mine": true, "slot": "", "tired": false, "num": int(p["num"]),
				"look": GameDB.player_looks(p), "i": tokens.size(), "id": str(p.get("id", tokens.size()))})
	for p in opp_ground.slice(0, SQUAD):
		tokens.append({"side": 1, "mine": false, "slot": "", "tired": false, "num": int(p["num"]),
				"look": GameDB.player_looks(p), "i": tokens.size(), "id": str(p.get("id", tokens.size()))})
	_t = 0.0
	_phase = WARM
	_prev = WARM
	_since = 0.0
	_huddle_since = -1.0
	_slots = _huddle_slots()
	_frozen = false
	_dress()
	queue_redraw()


## The words on the banner: a rhyme or a taunt for the occasion from Banners.pick (the
## lead's banners data; ctx as Banners documents it, completed here with the clubs and
## the round), or the club's name until the picker is in the game. Lines split on newlines.
static func banner_text(my_code: String, opp_code: String, heading: String, ctx := {}) -> String:
	const PICKER := "res://scripts/core/Banners.gd"
	if ResourceLoader.exists(PICKER):
		var c := ctx.duplicate()
		c["us"] = c.get("us", my_code)
		if not c.has("home"):
			c["home"] = my_code
			c["away"] = opp_code
		c["round"] = c.get("round", heading)
		c["seed"] = c.get("seed", hash(heading + my_code))
		var text := str(load(PICKER).pick(c))
		if text != "":
			return text
	return GameDB.club_name(my_code)


## How far the preparation has got, 0..1: a third of the way, they gather in.
func set_progress(f: float) -> void:
	_progress = f
	if _phase == WARM and f >= HUDDLE_FROM:
		_go(HUDDLE, WORDS_HUDDLE)


## Warm-up, final words, then through the banner after `seconds` on its
## own; a tap sends them through at once.
func play_through(seconds: float) -> void:
	_auto = maxf(0.1, seconds)


## The match is ready: through the banner, then `done`.
func run_out() -> void:
	if _phase != RUN:
		_go(RUN, WORDS_RUN)


func phase() -> String:
	return ["warm", "huddle", "run"][_phase]


func _go(p: int, words: String) -> void:
	_prev = _phase
	_phase = p
	_since = _t
	if p == HUDDLE:
		_huddle_since = _t
	copy = words


func _process(delta: float) -> void:
	_t += delta
	if _auto > 0.0 and _phase != RUN:
		set_progress(_t / _auto)
		if _t >= _auto:
			run_out()
	if _phase == RUN and _left_at < 0.0 and _t - _since >= RUN_TIME:
		_left_at = _t
		_scene_then = get_tree().current_scene
		done.emit()
	# Black until the match screen is in, then fade it up and go.
	if _left_at >= 0.0 and get_tree().current_scene != _scene_then and get_tree().current_scene != null:
		set_process(false)
		var layer := get_parent()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(layer.queue_free)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	accept_event()     # nothing under the scene takes a tap while it plays
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap and _auto > 0.0:
		run_out()      # skip to the banner


# ---------------------------------------------------------------------------
# Where everyone is. Your side in front of the camera, backs to us; theirs
# beyond the banner. World: x across, y away from the camera, metres.
# ---------------------------------------------------------------------------
func _at(t: Dictionary, i: int, p: int) -> Vector2:
	if not bool(t["mine"]):
		# Theirs: short shuttles up the far end, the whole time, in five lines.
		return Vector2(-12.0 + (i % 5) * 6.0 + sin(_t * 1.1 + i) * 2.5, 46.0 + (i / 5) * 6.0)
	if p == RUN:
		# Through the banner and out the other side, spreading again; the front of
		# the huddle first, the back a few strides behind.
		var path := _run_path(t, i)
		var k := clampf((_t - _since - float(path[3])) / RUN_SPAN, 0.0, 1.0)
		return _bezier(path[0], path[1], path[2], k)
	return _mine_at(t, i, _t)


## One of yours before the run, at time `at`: at his drill, then on his way in to the
## huddle (_gather), then in his place, shifting his feet.
func _mine_at(t: Dictionary, i: int, at: float) -> Vector2:
	var g := _gather(t, i)
	if g.is_empty() or at < float(g[0]):
		return _warm_at(i, at)
	var k := clampf((at - float(g[0])) / float(g[1]), 0.0, 1.0)
	var to := _slot(i) + Vector2(sin(at * 0.6 + i) * 0.05, 0.0)
	return _warm_at(i, float(g[0])).lerp(to, k * k * (3.0 - 2.0 * k))


## Warming up: five lines, each man at his own drill (_warm_drill): the joggers run
## easy shuttles across and back, the rest work where they stand.
func _warm_at(i: int, at: float) -> Vector2:
	var spot := _warm_home(i)
	if _warm_drill(i) == 0:
		spot.x += sin(at * 0.7 + (i / 5) * 0.9) * 1.4
	return spot


static func _warm_home(i: int) -> Vector2:
	return Vector2(((i % 5) - 2) * 2.8, 2.5 + (i / 5) * 2.4)


func _slot(i: int) -> Vector2:
	return _slots[i] if i < _slots.size() else HUDDLE_AT


## One of yours gathering in: [when he sets off, how long he takes], or [] before they
## gather. He finishes his rep first (his own lag), then jogs in at his own pace,
## easing in and out of it.
func _gather(t: Dictionary, i: int) -> Array:
	if _huddle_since < 0.0:
		return []
	var start := _huddle_since + GATHER_LAG * _rate(t, 0.0, 1.0)
	var dist := _warm_at(i, start).distance_to(_slot(i))
	return [start, maxf(0.9, dist / _rate(t, GATHER_PACE.x, GATHER_PACE.y))]


## Places in the huddle: two rings, the inner nine shoulder to shoulder, the rest round
## them. The nearest nine take the inner ring; each ring is filled in order round the
## huddle from the side each man comes from, so nobody runs across another's path.
func _huddle_slots() -> Array:
	var out := []
	out.resize(_mine)
	var order := range(_mine)
	order.sort_custom(func(a, b): return _warm_home(a).distance_to(HUDDLE_AT) < _warm_home(b).distance_to(HUDDLE_AT))
	var rings := [order.slice(0, 9), order.slice(9)]
	for ring in range(2):
		var men: Array = rings[ring]
		if men.is_empty():
			continue
		men.sort_custom(func(a, b): return (_warm_home(a) - HUDDLE_AT).angle() < (_warm_home(b) - HUDDLE_AT).angle())
		var r := Vector2(1.7, 1.2) if ring == 0 else Vector2(3.1, 2.3)
		# The ring turned so the men have least ground to cover.
		var best := INF
		var a0 := 0.0
		for k in range(72):
			var cost := 0.0
			for j in range(men.size()):
				var a := TAU * (float(k) / 72.0 + float(j) / float(men.size()))
				cost += _warm_home(men[j]).distance_squared_to(HUDDLE_AT + Vector2(cos(a) * r.x, sin(a) * r.y))
			if cost < best:
				best = cost
				a0 = TAU * float(k) / 72.0
		for j in range(men.size()):
			var a := a0 + TAU * float(j) / float(men.size())
			out[men[j]] = HUDDLE_AT + Vector2(cos(a) * r.x, sin(a) * r.y)
	return out


## A runner's way through the banner: [from, through, out, start delay]. They break
## from the huddle together and run as a loose stream, each keeping his own line and
## his room (no funnelling into a bunch before the paper - director): the front of the
## huddle away first, those behind a stride or two later, crossing the banner across
## its width and fanning out beyond it.
const RUN_SPAN := 1.6

func _run_path(t: Dictionary, i: int) -> Array:
	var from := _mine_at(t, i, _since)
	var through := Vector2(from.x * 1.5, BANNER_Y)
	var out := Vector2(from.x * 2.0 + ((i % 3) - 1) * 1.0, BANNER_Y + 9.0 + (i % 4) * 1.4)
	var behind := (HUDDLE_AT.y + 2.5 - from.y) * 0.09          # the back of the huddle follows on
	return [from, through, out, maxf(0.0, behind) + float((i * 37) % 10) * 0.012]


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


func _pos_i(t: Dictionary, i: int) -> Vector2:
	return _at(t, i, _phase)


## One of yours on his way in to the huddle now.
func _gathering(t: Dictionary) -> bool:
	if not bool(t["mine"]) or _phase != HUDDLE:
		return false
	var g := _gather(t, int(t["i"]))
	return not g.is_empty() and _t >= float(g[0]) and _t < float(g[0]) + float(g[1])


## One of yours still at his drill, the huddle called but not yet on his way.
func _drilling(t: Dictionary) -> bool:
	if _phase == WARM:
		return true
	var g := _gather(t, int(t["i"]))
	return _phase == HUDDLE and not g.is_empty() and _t < float(g[0])


func _moving(t: Dictionary) -> bool:
	return not bool(t["mine"]) or _phase != HUDDLE or _gathering(t)


## Each man's warm-up drill: 0 shuttles, 1 kick-to-kick, 2 marking practice, 3 a word
## with a teammate, loosening up. Spread so no line does the same thing.
func _warm_drill(i: int) -> int:
	return (i * 3 + i / 5) % 4


## What each man is doing, so a group never moves as one (director): in the warm-up,
## his own drill; in the huddle, listening (_ready_pick); through the banner, his own
## stride - mirrored for some - and the first few leap up through the paper.
func _frame(t: Dictionary, lift: float, at := Vector2.ZERO, back := false) -> Array:
	if t.is_empty() or not bool(t["mine"]):
		if not t.is_empty() and int(t["i"]) % 3 == 0:
			return ["ready_b", int(_t * 0.6 + int(t["i"])) % 3, int(t["i"]) % 2 == 0]      # stretching
		return super(t, lift, at, back)
	var i := int(t["i"])
	var r := _rate(t, 0.0, 1.0)
	if _phase == RUN and _t - _since >= 0.0:
		var cross: Array = _cross_cache[i] if i < _cross_cache.size() else []
		if not cross.is_empty() and i < 4 and absf(_t - float(cross[1])) < 0.22:
			return ["leap", 4 + int(_t * 10.0) % 2, r < 0.5]                          # up through it
		var strides := 13.0 / TAU * _rate(t, 0.85, 1.2)
		return ["jog", int(_t * strides * 8.0 + i * 2.7) % 8, r < 0.4]
	if _gathering(t):
		# Jogging in easy, facing the way he's going: side-on across the shot, his back
		# to us going away, his front coming towards us.
		var g := _gather(t, i)
		var way := _slot(i) - _warm_at(i, float(g[0]))
		var strides := 11.0 / TAU * _rate(t, 0.8, 1.0)
		var f := int(_t * strides * 8.0 + i * 2.7) % 8
		if absf(way.x) > absf(way.y) * 1.2:
			return ["jog", f, way.x > 0.0, "side_l"]
		return ["jog", f, r < 0.4, "back" if way.y > 0.0 else "front"]
	if _drilling(t) and _t - _since >= 0.0:
		# Facing where the drill has him facing - not all of them with their backs to us.
		var faces := "front" if i % 2 == 1 else "back"
		match _warm_drill(i):
			0:
				# Shuttles across and back: side-on, heading the way he's going.
				var heading_left := cos(_t * 0.7 + (i / 5) * 0.9) < 0.0
				var strides := 13.0 / TAU * _rate(t, 0.75, 1.0)
				return ["jog", int(_t * strides * 8.0 + i * 2.7) % 8, not heading_left, "side_l"]
			1:
				# Kick-to-kick in pairs: one kicks (from behind, three-quarters on), his
				# partner faces us waiting for it; between kicks they watch the ball.
				var p := fmod(_t + i * 0.37, 2.2 + r * 0.6)
				if p < 0.6 and faces == "back":
					return ["kick", mini(5, int(p / 0.1)), i % 4 == 2, "back_r"]
				return ["ready_turn", int(_t * 0.8 + i) % 3, i % 4 < 2, faces]
			2:
				# Marking practice: up for one now and then, hands out ready between.
				var p := fmod(_t + i * 0.53, 2.6 + r * 0.5)
				if p < 0.5:
					return ["leap", 2 + mini(3, int(p / 0.12)), r < 0.5, faces]
				return ["ready_b", int(_t * 0.7 + i) % 3, r < 0.3, faces]
			3:
				return ["idle", 0, r < 0.5, faces] if r < 0.5 else ["ready_turn", int(_t * 0.5 + i) % 3, r < 0.75, faces]
	return super(t, lift, at, back)


func _lift(_t_: Dictionary) -> float:
	return 0.0


## In the huddle they're listening, not waiting on a ball: most stand easy (upright,
## some mirrored), the rest turned in to the middle, and each shifts his weight only
## every couple of seconds - the match stance's quick bounce read as jostling here
## (director). Elsewhere, as in the match.
func _ready_pick(t: Dictionary, at: Vector2, back: bool) -> Array:
	if not (bool(t["mine"]) and _phase == HUDDLE):
		return super(t, at, back)
	var r := _rate(t, 0.0, 1.0)
	var slow := int(_t * (0.3 + r * 0.3) + r * 3.0) % 3          # his own slow rhythm
	# Facing into the ring: the far side of it faces us, the near side has its back to us,
	# the ends turn their heads in.
	var to := _look_at(t) - at
	var faces := "front" if to.y < -0.35 * to.length() else "back"
	var across := -to.x if faces == "back" else to.x
	if absf(to.x) > 0.6 * to.length():
		return ["ready_turn", slow, across < 0.0, faces]
	if r < 0.4:
		return ["idle", 0, r < 0.2, faces]
	return ["ready", slow, r > 0.8, faces]


## Gathered in, they watch the middle of the huddle; otherwise the play ahead.
func _look_at(t: Dictionary) -> Vector2:
	if bool(t["mine"]) and _phase == HUDDLE:
		return HUDDLE_AT
	return Vector2(0.0, 60.0)


func _set_camera() -> void:
	# Low, just behind the last line of the warm-up, zooming in a little on the huddle -
	# the lens only, so nothing bends. Then, as they run, a steadicam goes with them:
	# down low behind them and through the banner on their heels (director).
	var follow := 0.0
	var cam_y := -CAM_START
	if _phase == RUN:
		follow = _ease(clampf((_t - _since - 0.15) / (RUN_TIME - 0.4), 0.0, 1.0))
		# On their heels, but never closer than 5 m to the last man out.
		var last := INF
		for i in range(_mine):
			last = minf(last, _pos_i(tokens[i], i).y)
		cam_y = minf(lerpf(-CAM_START, CAM_THROUGH, follow), last - 5.0)
		cam_y = maxf(cam_y, -CAM_START)
		follow = clampf((cam_y + CAM_START) / (CAM_THROUGH + CAM_START), 0.0, 1.0)
	_cam_d = -cam_y
	_cam_h = lerpf(6.5, 2.2, follow)
	_cam_x = 0.0       # square on to the banner
	var base := maxf(size.x * 1.3, size.y * 0.62)
	_zoom = lerpf(1.0, 1.15, _ease(clampf(_t / 4.0, 0.0, 1.0))) * (1.0 - 0.15 * follow)
	_focal = base * _zoom
	# Zooming about the huddle's chest, seen from where the camera started; as the
	# camera moves the lens stays level, so the horizon holds.
	var depth := HUDDLE_AT.y + CAM_START
	var pin := size.y * 0.3 + base * (6.5 - 1.0) / depth
	_horizon = pin - _focal * (6.5 - 1.0) / depth


## The warm-up is on a wing: the banner out on the ground, the opposition warming up
## beyond it, then the boundary, the fence and the stand, the length of the ground
## running across the shot. Oval coordinates to the scene's.
const BOUNDARY_AT := 72.0

func _ground_to_scene() -> Transform2D:
	return Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(0, BOUNDARY_AT - VignetteGround.A))


func _draw() -> void:
	_cross_cache = _crossings() if _phase == RUN else []
	_set_camera()
	var fade := clampf(_t / CUT_IN, 0.0, 1.0)
	_draw_ground()
	var figs := []
	for i in range(tokens.size()):
		var idx := i if bool(tokens[i]["mine"]) else i - _mine
		figs.append({"at": _pos_i(tokens[i], idx), "t": tokens[i]})
	figs.sort_custom(func(a, b): return (a["at"] as Vector2).y > (b["at"] as Vector2).y)
	var banner_drawn := false
	for f in figs:
		if not banner_drawn and (f["at"] as Vector2).y < BANNER_Y:
			_draw_banner()
			banner_drawn = true
		_draw_figure(f["at"], f["t"])
	if not banner_drawn:
		_draw_banner()
	_draw_bars(fade)
	_draw_copy(fade)
	var black := 1.0 - fade
	if _phase == RUN:
		black = maxf(black, clampf((_t - _since - (RUN_TIME - 0.25)) / 0.25, 0.0, 1.0))
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, black), true)


## The banner across the race in your colours: crepe paper on two poles, torn apart by
## the players as they burst through it (director: not two halves swinging open like a
## doorway). It is a sheet of small pieces with the printed face (BANNER_COLS x
## BANNER_ROWS): each piece rips when a runner reaches it - those in his path first, the
## paper above them a moment later, the ragged edges round the hole after - then is
## carried on by him, flutters down and lies on the turf. What nobody touches stays
## hanging from the poles.
const BANNER_COLS := 36
const BANNER_ROWS := 14
const BANNER_LOW := 0.5            # metres: the bottom edge
const BANNER_TOP := 7.0
var _face: SubViewport = null


func _draw_banner() -> void:
	if BANNER_Y + _cam_d < 1.0:
		return               # the camera has gone through it
	var pole := Color(0.85, 0.85, 0.85)
	for sx in [-1.0, 1.0]:
		var a := _project(Vector2(sx * (BANNER_W + 0.3), BANNER_Y), 0.0)
		var b := _project(Vector2(sx * (BANNER_W + 0.3), BANNER_Y), BANNER_TOP + 0.5)
		draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), pole, maxf(2.0, 0.12 * a.z))
	var crossings := _cross_cache
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var cw := 2.0 * BANNER_W / BANNER_COLS
	var ch := (BANNER_TOP - BANNER_LOW) / BANNER_ROWS
	for c in range(BANNER_COLS):
		for r in range(BANNER_ROWS):
			var x := -BANNER_W + (c + 0.5) * cw
			var h := BANNER_LOW + (r + 0.5) * ch
			var uv := Rect2(float(c) / BANNER_COLS, 1.0 - float(r + 1) / BANNER_ROWS, 1.0 / BANNER_COLS, 1.0 / BANNER_ROWS)
			var torn := _tear_time(x, h, c * 31 + r * 7, crossings)
			var corners := []
			if _t < torn:
				# Still hanging: the paper bellies a touch between the poles.
				var y := BANNER_Y + 0.12 * (1.0 - pow(x / BANNER_W, 2.0))
				corners = [[x - cw * 0.5, y, h - ch * 0.5], [x + cw * 0.5, y, h - ch * 0.5],
						[x + cw * 0.5, y, h + ch * 0.5], [x - cw * 0.5, y, h + ch * 0.5]]
			else:
				corners = _piece(x, h, cw, ch, _t - torn, c * 13 + r * 29)
			var s := []
			for q in corners:
				if float(q[1]) + _cam_d < 4.0:
					break                # too near the lens: let it go by
				s.append(_project(Vector2(q[0], q[1]), q[2]))
			if s.size() < 4:
				continue
			var base := pts.size()
			for k in range(4):
				pts.append(Vector2(s[k].x, s[k].y))
				cols.append(Color(1, 1, 1, 1))
			uvs.append_array([Vector2(uv.position.x, uv.end.y), Vector2(uv.end.x, uv.end.y),
					Vector2(uv.end.x, uv.position.y), uv.position])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs,
				PackedInt32Array(), PackedFloat32Array(), _banner_face().get_rid())


## Where and when each runner goes through the banner: [x, time].
func _crossings() -> Array:
	var out := []
	for i in range(_mine):
		var path := _run_path(tokens[i], i)
		var lo := 0.0
		var hi := 1.0
		for n in range(16):
			var mid := (lo + hi) * 0.5
			if _bezier(path[0], path[1], path[2], mid).y < BANNER_Y:
				lo = mid
			else:
				hi = mid
		out.append([_bezier(path[0], path[1], path[2], hi).x, _since + float(path[3]) + hi * RUN_SPAN])
	return out


## When a piece of the banner at (x, h) rips: when the first runner to reach it goes
## through (a shoulder's width either side of him), the paper above his head a moment
## later as the rip runs up, the ragged edge round the hole after that. INF: never.
func _tear_time(x: float, h: float, seed: int, crossings: Array) -> float:
	var best := INF
	var rag := 0.35 * (float((seed * 7919) % 100) / 100.0 - 0.5)
	for c in crossings:
		var dx := absf(x - float(c[0]))
		var t := INF
		if dx < 0.7 + rag:
			t = float(c[1]) + maxf(0.0, h - 2.1) * 0.15
		elif dx < 1.5 + rag:
			t = float(c[1]) + 0.12 + (dx - 0.7) * 0.4 + absf(h - 1.6) * 0.06
		best = minf(best, t)
	return best


## A torn piece, age seconds after it ripped: carried on through, crumpling, fluttering
## down, then lying on the turf. Corners [x, y, height].
func _piece(x: float, h: float, cw: float, ch: float, age: float, seed: int) -> Array:
	var rnd := func(k: int) -> float: return float(((seed + k) * 2654435761) % 1000) / 1000.0
	var drift: float = (rnd.call(1) - 0.5) * 1.2
	var carry: float = 0.4 + rnd.call(2) * 0.9
	var y := BANNER_Y + carry * (1.0 - exp(-2.2 * age))
	var px: float = x + drift * age + sin(age * 6.0 + seed) * 0.1
	var fall := 1.4 * age + 2.2 * age * age
	var ph := maxf(0.0, h - fall)
	var shrink := lerpf(1.0, 0.55, clampf(age * 1.5, 0.0, 1.0))
	var w := cw * shrink * 0.5
	var hh := ch * shrink * 0.5
	if ph <= 0.0:
		# On the ground: lying flat.
		return [[px - w, y - hh, 0.01], [px + w, y - hh, 0.01], [px + w, y + hh, 0.01], [px - w, y + hh, 0.01]]
	var tilt: float = sin(age * (5.0 + rnd.call(3) * 4.0) + seed) * 0.8
	var c := Vector2(cos(tilt), sin(tilt))
	var lean: float = sin(age * 4.0 + seed * 0.3) * hh
	return [[px - w * c.x, y - lean, ph - w * c.y - hh], [px + w * c.x, y + lean, ph + w * c.y - hh],
			[px + w * c.x, y + lean, ph + w * c.y + hh], [px - w * c.x, y - lean, ph - w * c.y + hh]]


## The banner's printed face, painted once: your colours, bands of the second along the
## top and bottom, its words (one string, lines split on newlines - a rhyme or a taunt) as big as they'll
## fit, the crinkle of crepe paper.
const FACE := Vector2i(1024, 370)

func _banner_face() -> Texture2D:
	if _face == null:
		_face = SubViewport.new()
		_face.size = FACE
		_face.render_target_update_mode = SubViewport.UPDATE_ONCE
		var c := Control.new()
		c.size = Vector2(FACE)
		c.draw.connect(_paint_face.bind(c))
		_face.add_child(c)
		add_child(_face)
	return _face.get_texture()


func _paint_face(c: Control) -> void:
	var cols: Array = _colours[0]
	var main: Color = cols[0] if not cols.is_empty() else Color(0.3, 0.3, 0.32)
	var second: Color = cols[1] if cols.size() > 1 else main.lightened(0.4)
	var w := float(FACE.x)
	var h := float(FACE.y)
	c.draw_rect(Rect2(0, 0, w, h), main, true)
	c.draw_rect(Rect2(0, 0, w, h * 0.06), second, true)
	c.draw_rect(Rect2(0, h * 0.9, w, h * 0.1), second, true)
	for x in range(0, FACE.x, 7):
		c.draw_line(Vector2(x, 0), Vector2(x, h), Color(0, 0, 0, 0.05), 2.0)
	var lines := banner.split("\n", false)
	if lines.is_empty():
		return
	var font: Font = UiKit.DISPLAY
	# The middle of the sheet: the banner is wider than a phone sees it from the huddle.
	var room := Vector2(w * 0.55, h * 0.78)
	var fs := int(room.y / lines.size() * 0.8)
	for line in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lw > room.x:
			fs = int(fs * room.x / lw)
	var ink := _readable_on(main)
	var step := fs * 1.12
	var y0 := h * 0.48 - step * (lines.size() - 1) * 0.5
	for i in range(lines.size()):
		var lw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(font, Vector2((w - lw) * 0.5, y0 + i * step + fs * 0.35), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## A few words in the bottom bar: where the side is up to.
func _draw_copy(fade: float) -> void:
	if fade < 1.0:
		return
	var bar := size.y * 0.075
	var font: Font = UiKit.BOLD
	var fs := int(clampf(size.x / 24.0, 13.0, 18.0))
	var w := font.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y - bar * 0.5 + fs * 0.36), copy,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
