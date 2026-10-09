class_name FarewellVignette
extends StoppageVignette
## After the siren of a milestone game (FL-007, director approved 2026-10-09): both
## sides form a guard of honour and clap him off, he walks through it with a hand up
## to the crowd, then two teammates chair him off on their shoulders. About six
## seconds; a tap skips it. Decoration only: it reads who played and changes nothing.
## The occasion is GameState's banner milestone (the same man the run-through banner
## honours): a career or club milestone of 200 games or more (200, 250, 300...), or his
## last game (director, 2026-10-09).

signal done

## The beats, in seconds: the guard of honour, then chaired off.
const GUARD := 3.2
const CHAIRED := 3.0
const END := GUARD + CHAIRED
## A dip to black between the two shots.
const CUT := 0.18
## The milestones that get the guard and the chair: from 200 games (director,
## 2026-10-09). A debut, 50th, 100th or 150th has its banner, not this.
const FROM_GAMES := 200
## Each line of the guard: men a side, metres off the middle and apart along it
## (the figures are drawn larger than life, so the spacing is too).
const LINE := 6
const LINE_X := 2.2
const LINE_GAP := 1.9
const LINE_FROM := 4.2          # the nearest men in frame (at 3.0 only a boot and a shadow showed)
## Chaired off: each carrier's centre off the middle (the board's 0.235 m, at the
## figures' scale) and the walk: from the far end of the guard towards the camera.
const CARRIER_X := 0.235
const WALK := [Vector2(0.0, 12.0), Vector2(0.0, 6.6)]
const CHAIR := [Vector2(0.0, 10.2), Vector2(0.0, 7.2)]
## Strides: a walk's cycle (eight frames) takes this long; carriers, under the load, longer.
const WALK_CYCLE := 1.05
const CARRY_CYCLE := 1.3
## The clap: four frames a beat, each man at his own pace.
const CLAP_RATE := 9.0
## Where it stands: the same wing as the pre-match scene, the stand behind them.
const BOUNDARY_AT := 72.0

var copy := ""
var _left := false
var _man := {}              # the milestone man's token
var _carriers := []         # two teammates' tokens


## The words for the occasion, or "" when it isn't one: ms is GameState's banner
## milestone ({player, name, games: int or "farewell", club}).
static func caption(ms: Dictionary) -> String:
	if ms.is_empty():
		return ""
	var who := str(ms.get("player", ""))
	if str(ms.get("games", "")) == "farewell":
		return "A farewell for %s" % who
	var games := int(ms.get("games", 0))
	if games < FROM_GAMES:
		return ""
	if bool(ms.get("club", false)):
		return "%s's %s game for the club" % [who, _ordinal(games)]
	return "%s's %s game" % [who, _ordinal(games)]


static func _ordinal(n: int) -> String:
	var tail := "th"
	if n % 100 < 11 or n % 100 > 13:
		tail = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, tail]


## The scene on its own layer over the match screen.
static func open(host: Node, ms: Dictionary, man: Dictionary, my_code: String, opp_code: String,
		mine: Array, theirs: Array, heading := "", wet := false) -> FarewellVignette:
	var layer := CanvasLayer.new()
	layer.name = "Farewell"
	layer.layer = 90
	host.add_child(layer)
	var v := FarewellVignette.new()
	v.name = "FarewellVignette"
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.setup_farewell(ms, man, my_code, opp_code, mine, theirs, heading, wet)
	return v


func setup_farewell(ms: Dictionary, man: Dictionary, my_code: String, opp_code: String,
		mine: Array, theirs: Array, heading := "", wet := false) -> void:
	title = heading
	copy = caption(ms)
	weather = "wet" if wet else ""
	_colours = [GameDB.club_colours(my_code), GameDB.club_colours(opp_code)]
	_codes = [my_code, opp_code]
	tokens.clear()
	_man = _token(man, 0, wet)
	var others := mine.filter(func(p): return str(p.get("id", "")) != str(man.get("id", "")))
	# The guard: your side on the left, theirs on the right, facing in across his path.
	for i in range(LINE):
		if i < others.size():
			tokens.append(_token(others[i], 0, wet, {"line": -1, "k": i}))
		if i < theirs.size():
			tokens.append(_token(theirs[i], 1, wet, {"line": 1, "k": i}))
	# Two more of yours chair him off.
	_carriers = []
	for i in range(LINE, mini(LINE + 2, others.size())):
		_carriers.append(_token(others[i], 0, wet))
	while _carriers.size() < 2:
		_carriers.append(_man.duplicate())
	_t = 0.0
	_left = false
	_dress()
	queue_redraw()


func _token(p: Dictionary, side: int, wet: bool, extra := {}) -> Dictionary:
	var t := {"side": side, "mine": side == 0, "slot": "", "tired": false, "num": int(p.get("num", 0)),
			"look": GameDB.figure_look(p, wet), "i": tokens.size(), "id": str(p.get("id", "")),
			"height_cm": float(p.get("height_cm", 0.0))}
	t.merge(extra)
	return t


## Straight to the end (a tap; tests).
func finish_now() -> void:
	if _left:
		return
	_left = true
	set_process(false)
	done.emit()
	var layer := get_parent()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	if layer is CanvasLayer:
		tw.tween_callback(layer.queue_free)


func phase() -> String:
	return "guard" if _t < GUARD else "chaired"


func _process(delta: float) -> void:
	_t += delta
	if _t >= END:
		finish_now()
		return
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	accept_event()     # nothing under the scene takes a tap while it plays
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		finish_now()


# ---------------------------------------------------------------------------
# The camera: low at the near end of the guard, looking down it.
# ---------------------------------------------------------------------------
func _set_camera() -> void:
	_cam_d = 4.0
	_cam_h = 1.4      # low: the stand fills the top of the screen behind them (AFL BOSS, #540)
	_cam_x = 0.0
	_pan = 0.0
	# Tight on the guard: at 1.25 the top ~40% of a phone was empty night sky.
	var base := maxf(size.x * 1.25, size.y * 0.6) * 1.5
	var push := _ease(clampf(fmod(_t, GUARD) / GUARD, 0.0, 1.0)) if _t < GUARD else _ease(clampf((_t - GUARD) / CHAIRED, 0.0, 1.0))
	_zoom = 1.0 + 0.08 * push
	_focal = base * _zoom
	# The far end of the guard sits a little above the middle of the screen.
	var depth := 12.0 + _cam_d
	_horizon = size.y * 0.42 - _focal * _cam_h / depth


func _ground_to_scene() -> Transform2D:
	return Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(0, BOUNDARY_AT - VignetteGround.A))


# ---------------------------------------------------------------------------
# Who stands where, and what each is doing.
# ---------------------------------------------------------------------------
func _line_at(t: Dictionary) -> Vector2:
	return Vector2(float(t["line"]) * LINE_X, LINE_FROM + float(t["k"]) * LINE_GAP)


func _walker_at() -> Vector2:
	return (WALK[0] as Vector2).lerp(WALK[1], clampf(_t / GUARD, 0.0, 1.0))


func _chair_at() -> Vector2:
	return (CHAIR[0] as Vector2).lerp(CHAIR[1], clampf((_t - GUARD) / CHAIRED, 0.0, 1.0))


func _frame(t: Dictionary, _lift_: float, _at := Vector2.ZERO, _back := false) -> Array:
	var role := str(t.get("role", ""))
	var i := int(t.get("i", 0))
	match role:
		"walker":
			return ["walk_wave", int(_t * 8.0 / WALK_CYCLE) % 8, false, "front"]
		"carrier":
			var f := int((_t - GUARD) * 8.0 / CARRY_CYCLE) % 8
			# The one on his right is the mirror of the one on his left, half a stride on,
			# so the pair walk in step.
			return ["carrier", (f + 4) % 8 if bool(t["mirror"]) else f, bool(t["mirror"]), "front"]
		"rider":
			return ["chaired", int((_t - GUARD) * 8.0 / CARRY_CYCLE) % 8, false, "front"]
	# In the guard: clapping, each at his own rate; the left line faces right (mirrored).
	var rate := CLAP_RATE * _rate(t, 0.85, 1.15)
	return ["clap", int(_t * rate + i * 1.7) % 4, float(t.get("line", 1)) < 0.0, "side_l"]


func _draw() -> void:
	_set_camera()
	var fade := clampf(_t / CUT_IN, 0.0, 1.0)
	_draw_ground()
	var figs := []
	for t in tokens:
		figs.append({"at": _line_at(t), "t": t})
	if _t < GUARD:
		figs.append({"at": _walker_at(), "t": _role(_man, "walker")})
	else:
		var c := _chair_at()
		var dx := CARRIER_X * FIGURE
		# Drawn as one: the carriers, then him (his sprite already lacks what their
		# heads and hands hide), at the pair's middle on the turf.
		figs.append({"at": c, "group": [
			{"at": c + Vector2(dx, 0.0), "t": _role(_carriers[0], "carrier", {"mirror": false})},
			{"at": c - Vector2(dx, 0.0), "t": _role(_carriers[1], "carrier", {"mirror": true})},
			{"at": c, "t": _role(_man, "rider")}]})
	figs.sort_custom(func(a, b): return (a["at"] as Vector2).y > (b["at"] as Vector2).y)
	for f in figs:
		if f.has("group"):
			for g in f["group"]:
				_draw_figure(g["at"], g["t"])
		else:
			_draw_figure(f["at"], f["t"])
	VignetteWeather.draw_air(self, Rect2(Vector2.ZERO, size), _t, weather)
	_draw_bars(fade)
	_draw_copy(fade)
	var black := 1.0 - fade
	# The cut to chaired off: a moment of black either side of it.
	black = maxf(black, 1.0 - clampf(absf(_t - GUARD) / CUT, 0.0, 1.0))
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, black), true)


func _role(t: Dictionary, role: String, extra := {}) -> Dictionary:
	var out := t.duplicate()
	out["role"] = role
	out.merge(extra, true)
	return out


## A figure as the base draws one, except the man in the chair: no shadow of his own
## (the carriers' are his), and his sprite's pivot is the turf under the pair.
func _draw_figure(at: Vector2, t: Dictionary) -> void:
	if str(t.get("role", "")) != "rider":
		super(at, t)
		return
	var base := _project(at)
	var m := base.z * FIGURE
	var pick := _frame(t, 0.0, at, false)
	var info := VignetteFigures.strip("average", pick[0], pick[3])
	if info.is_empty():
		return
	var frame := figure_frame(info, int(pick[1]), pick[0], pick[3])
	var look: Dictionary = t["look"]
	draw_frame(self, Vector2(base.x, base.y), info, frame, m / VignetteFigures.PX_PER_M,
			look_colour(int(t["side"]), look, false), false, Color(0, 0, 0, 0), Transform2D.IDENTITY,
			str(look.get("hair_style", VignetteFigures.HAIR_BASE)))


func _draw_copy(fade: float) -> void:
	if fade < 1.0 or copy == "":
		return
	var words := copy if _t < GUARD else "Chaired off"
	var bar := size.y * 0.075
	var font: Font = UiKit.BOLD
	var fs := int(clampf(size.x / 24.0, 13.0, 18.0))
	var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y - bar * 0.5 + fs * 0.36), words,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
