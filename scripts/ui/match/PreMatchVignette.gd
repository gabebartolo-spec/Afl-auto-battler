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
const BLEND := 0.7
const RUN_TIME := 0.75
const BANNER_Y := 16.0
const BANNER_W := 7.5
const MINE := 9
const THEIRS := 6

var copy := "Warming up"
var banner := ""
var _phase := WARM
var _prev := WARM
var _since := 0.0          # time the phase began
var _progress := 0.0
var _left_at := -1.0       # when the scene went black, waiting for the match
var _scene_then: Node = null
var _auto := -1.0          # play_through: seconds until the run (-1: off)


## The scene on its own layer over whatever is showing, so it stays up while
## the match screen replaces the hub underneath it.
static func open(host: Node, my_code: String, opp_code: String, my_ground: Array,
		opp_ground: Array, heading: String) -> PreMatchVignette:
	var layer := CanvasLayer.new()
	layer.name = "PreMatch"
	layer.layer = 90
	host.add_child(layer)
	var v := PreMatchVignette.new()
	v.name = "PreMatchVignette"
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.setup_prematch(my_code, opp_code, my_ground, opp_ground, heading)
	return v


func setup_prematch(my_code: String, opp_code: String, my_ground: Array, opp_ground: Array,
		heading: String) -> void:
	title = heading
	banner = GameDB.club_name(my_code)
	_colours = [GameDB.club_colours(my_code), GameDB.club_colours(opp_code)]
	_codes = [my_code, opp_code]
	tokens.clear()
	for p in my_ground.slice(0, MINE):
		tokens.append({"side": 0, "mine": true, "slot": "", "tired": false, "num": int(p["num"])})
	for p in opp_ground.slice(0, THEIRS):
		tokens.append({"side": 1, "mine": false, "slot": "", "tired": false, "num": int(p["num"])})
	_t = 0.0
	_phase = WARM
	_prev = WARM
	_since = 0.0
	_frozen = false
	_dress()
	queue_redraw()


## How far the preparation has got, 0..1: past halfway, they gather in.
func set_progress(f: float) -> void:
	_progress = f
	if _phase == WARM and f >= 0.5:
		_go(HUDDLE, "Final instructions")


## Warm-up, final words, then through the banner after `seconds` on its
## own; a tap sends them through at once.
func play_through(seconds: float) -> void:
	_auto = maxf(0.1, seconds)


## The match is ready: through the banner, then `done`.
func run_out() -> void:
	if _phase != RUN:
		_go(RUN, "Running through the banner")


func phase() -> String:
	return ["warm", "huddle", "run"][_phase]


func _go(p: int, words: String) -> void:
	_prev = _phase
	_phase = p
	_since = _t
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
		# Theirs: short shuttles up the far end, the whole time.
		return Vector2(-7.0 + (i % 3) * 7.0 + sin(_t * 1.1 + i) * 3.0, 50.0 + (i / 3) * 8.0)
	match p:
		HUDDLE:
			var a := TAU * float(i) / float(MINE) + 0.3
			return Vector2(cos(a) * 1.7 + sin(_t * 1.7 + i) * 0.1, 5.5 + sin(a) * 1.2)
		RUN:
			var k := clampf((_t - _since) / RUN_TIME, 0.0, 1.0)
			var from := _at(t, i, _prev if _prev != RUN else HUDDLE)
			return from.lerp(Vector2(from.x * 1.4, BANNER_Y + 6.0 + (i % 3) * 1.5), k * k)
	# Warming up: three lines jogging across and back.
	return Vector2(sin(_t * 0.9 + i * 0.7) * 2.6 + ((i % 3) - 1) * 0.6, 2.5 + (i / 3) * 2.6)


func _pos_i(t: Dictionary, i: int) -> Vector2:
	var k := clampf((_t - _since) / BLEND, 0.0, 1.0)
	if _phase == RUN or k >= 1.0 or not bool(t["mine"]):
		return _at(t, i, _phase)
	return _at(t, i, _prev).lerp(_at(t, i, _phase), _ease(k))


func _moving(t: Dictionary) -> bool:
	return not bool(t["mine"]) or _phase != HUDDLE or _t - _since < BLEND


func _lift(_t_: Dictionary) -> float:
	return 0.0


func _set_camera() -> void:
	# Low, just behind the last line of the warm-up, easing in a little.
	_cam_d = lerpf(6.5, 5.0, _ease(clampf(_t / 4.0, 0.0, 1.0)))
	_cam_h = 6.5
	_cam_x = 0.0       # square on to the banner
	_focal = maxf(size.x * 1.3, size.y * 0.62)
	_horizon = size.y * 0.3


func _draw_markings() -> void:
	pass       # no centre square in this shot


func _draw() -> void:
	_set_camera()
	var fade := clampf(_t / CUT_IN, 0.0, 1.0)
	_draw_ground()
	# The fence and the boards along the boundary, under the crowd.
	var edge := _project(Vector2(0, 70.0)).y
	draw_rect(Rect2(0, edge - 5.0, size.x, 5.0), Color(0.24, 0.24, 0.26), true)
	var figs := []
	for i in range(tokens.size()):
		var idx := i if bool(tokens[i]["mine"]) else i - MINE
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


## The banner across the race in your colours, torn apart as they run through.
func _draw_banner() -> void:
	var cols: Array = _colours[0]
	var tear := 0.0
	if _phase == RUN:
		tear = _ease(clampf((_t - _since - 0.2) / 0.4, 0.0, 1.0))
	var pole := Color(0.85, 0.85, 0.85)
	for sx in [-1.0, 1.0]:
		var a := _project(Vector2(sx * (BANNER_W + 0.3), BANNER_Y), 0.0)
		var b := _project(Vector2(sx * (BANNER_W + 0.3), BANNER_Y), 3.9)
		draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), pole, maxf(2.0, 0.12 * a.z))
	# Two halves: whole until the tear, then hanging from the poles.
	for sx in [-1.0, 1.0]:
		var inner: float = lerpf(0.0, BANNER_W * 0.85, tear) * sx
		var outer: float = BANNER_W * sx
		var sag := 3.4 * tear
		var pts := PackedVector2Array()
		for q in [[outer, 3.4], [inner, 3.4 - sag * 0.2], [inner, 0.5 + sag * 0.6], [outer, 0.5]]:
			var s := _project(Vector2(q[0], BANNER_Y), q[1])
			pts.append(Vector2(s.x, s.y))
		draw_colored_polygon(pts, cols[0])
		var trim := PackedVector2Array()
		for q in [[outer, 1.0], [inner, 1.0 + sag * 0.5], [inner, 0.5 + sag * 0.6], [outer, 0.5]]:
			var s := _project(Vector2(q[0], BANNER_Y), q[1])
			trim.append(Vector2(s.x, s.y))
		draw_colored_polygon(trim, cols[1])
	if tear < 0.05 and banner != "":
		var mid := _project(Vector2(0, BANNER_Y), 2.2)
		var font: Font = UiKit.DISPLAY
		var fs := int(clampf(mid.z * 1.5, 14.0, 44.0))
		var room := mid.z * BANNER_W * 1.7
		var w := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > room:
			fs = int(fs * room / w)
			w = font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(mid.x - w * 0.5, mid.y + fs * 0.35), banner,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _readable_on(cols[0]))


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
