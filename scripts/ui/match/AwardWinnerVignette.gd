class_name AwardWinnerVignette
extends BroadcastVignette
## One club-colour stage scene for every award winner. Presentation only.
## The winner, a pre-rendered footballer in his club's guernsey and his own look,
## walks on across the stage, turns to us, the medal settles on his chest and
## his arms go up. His number is worn on the back, so it isn't shown here: the
## caption names him.

const REVEAL_TIME := 2.4
## Walk-on, turn to face us, arms up.
const WALK_END := 1.4
const ARMS_UP := 1.8
## Walking pace: cycles of the walk per second.
const PACES := 0.9
var club := ""
var number := 0

func setup_winner(code: String, jumper := 0, player_id := "") -> void:
	club = code
	number = jumper
	_colours[0] = GameDB.club_marker_colours(code)
	_dress([code, ""])
	var p = GameDB.player_by_id(player_id) if player_id != "" else null
	_look = GameDB.figure_look(p) if p is Dictionary else Appearance.UNCURATED
	_t = 0.0
	_done = false
	set_process(true)
	queue_redraw()

func finish_now() -> void:
	_t = REVEAL_TIME
	_done = true
	set_process(false)
	queue_redraw()
	finished.emit()

func _process(delta: float) -> void:
	_t = minf(REVEAL_TIME, _t + delta)
	queue_redraw()
	if _t >= REVEAL_TIME:
		_done = true
		set_process(false)
		finished.emit()

func _gui_input(input: InputEvent) -> void:
	if (input is InputEventMouseButton or input is InputEventScreenTouch) and input.is_pressed():
		finish_now()
		accept_event()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var cols: Array = _colours[0]
	if cols.is_empty():
		return
	# The awards night: a dark ballroom, the stage dressed in the club's colours,
	# a spotlight on him, a lectern; the room's tables and guests in the foreground.
	var stage_y := h * 0.64          # the front edge of the stage, where he stands
	# Room above him for his arms up (about 1.25 of his height) under the letterbox.
	var scale := minf(w / 260.0, (stage_y - 16.0) / (FIGURE_PX * 1.25))
	var walk := smoothstep(0.0, WALK_END, _t)
	var x := lerpf(w * 0.23, w * 0.5, walk)
	# The camera from the back of the room: panning with him across the stage, in on him
	# as the medal goes on, easing out a touch for the arms going up (VignetteCamera).
	var G := VignetteCamera
	var zoom: float = G.glide(G.glide(1.15, 1.28, _t, WALK_END - 0.2, 1.9), 1.16, _t, ARMS_UP, REVEAL_TIME)
	var focus := Vector2(x, stage_y - 0.9 * PX_PER_M * scale)
	_view = G.view(size, focus + G.breathe(_t, size), zoom)
	draw_set_transform_matrix(_view)
	_draw_room(w, h, cols, stage_y)
	_draw_spotlight(Vector2(x, stage_y), w, h)
	_draw_lectern(Vector2(w * 0.74, stage_y - 0.02 * h), scale)
	var hip := Vector2(x, stage_y - 38.0 * scale)
	if _t < WALK_END:
		_figure(hip, scale, 0, "walk", "front_r", int(_t * PACES * 8.0) % 8, 0, _look)
	elif _t < ARMS_UP:
		_figure(hip, scale, 0, "idle", "front", 0, 0, _look)
	else:
		_figure(hip, scale, 0, "celebrate", "front", 0, 0, _look)
	# The medal settles onto his chest on its ribbon; no invented facial likeness.
	if _t >= WALK_END:
		var neck := _at(hip, scale, Vector2(0.0, 1.55))
		var chest := _at(hip, scale, Vector2(0.0, 1.28))
		var medal_y := lerpf(chest.y - 0.2 * PX_PER_M * scale, chest.y, smoothstep(WALK_END, 1.9, _t))
		var tie := Vector2(x, medal_y)
		var ribbon := Color(0.85, 0.82, 0.72)
		draw_line(neck + Vector2(-0.07, 0.0) * PX_PER_M * scale, tie, ribbon, maxf(1.5, scale))
		draw_line(neck + Vector2(0.07, 0.0) * PX_PER_M * scale, tie, ribbon, maxf(1.5, scale))
		draw_circle(tie + Vector2(0, 0.04 * PX_PER_M * scale), 0.06 * PX_PER_M * scale, Color(0.75, 0.61, 0.34))
	_draw_audience(w, h, stage_y)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Letterbox matches the existing cinematic close-ups.
	draw_rect(Rect2(0, 0, w, 10), Color.BLACK)
	draw_rect(Rect2(0, h - 10, w, 10), Color.BLACK)


## The room behind him: dark walls, warm wall lights, the stage with its club-colour
## backdrop (every genuine marker colour, third bands included) and its front edge.
func _draw_room(w: float, h: float, cols: Array, stage_y: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.065, 0.08))
	# Haze: the room lighter towards the stage.
	for i in range(6):
		var y := h * (0.12 + 0.1 * i)
		draw_rect(Rect2(0, y, w, h * 0.1), Color(0.35, 0.3, 0.38, 0.025 * i))
	# Wall lights along the back of the room.
	for i in range(7):
		var lx := w * (0.06 + 0.148 * i)
		draw_circle(Vector2(lx, h * 0.17), 2.2, Color(1.0, 0.86, 0.6, 0.85))
		draw_circle(Vector2(lx, h * 0.17), 7.0, Color(1.0, 0.8, 0.5, 0.08))
	# The backdrop: club-colour drapes either side of a lit panel.
	var top := h * 0.22
	var panel := Rect2(w * 0.2, top, w * 0.6, stage_y - top)
	for i in range(cols.size()):
		var band := w * 0.18 / cols.size()
		var c: Color = (cols[i] as Color).darkened(0.25)
		draw_rect(Rect2(w * 0.02 + i * band, top, band, stage_y - top), c)
		draw_rect(Rect2(w * 0.98 - (i + 1) * band, top, band, stage_y - top), c)
		# Folds in the drapes.
		for f in range(3):
			var fx := w * 0.02 + i * band + band * (0.25 + 0.25 * f)
			draw_line(Vector2(fx, top), Vector2(fx, stage_y), c.darkened(0.25), 1.0)
			fx = w * 0.98 - (i + 1) * band + band * (0.25 + 0.25 * f)
			draw_line(Vector2(fx, top), Vector2(fx, stage_y), c.darkened(0.25), 1.0)
	draw_rect(panel, Color(0.16, 0.15, 0.19))
	draw_rect(Rect2(panel.position + Vector2(0, panel.size.y * 0.08), Vector2(panel.size.x, 2.0)),
			(cols[0] as Color).lightened(0.2))
	# The stage boards and their lit front edge.
	draw_rect(Rect2(0, stage_y - h * 0.02, w, h * 0.06), Color(0.2, 0.17, 0.15))
	draw_rect(Rect2(0, stage_y + h * 0.04, w, 2.0), Color(0.75, 0.62, 0.42, 0.7))


## A soft spotlight cone from the rig onto him, and its pool on the boards.
func _draw_spotlight(at: Vector2, w: float, h: float) -> void:
	var src := Vector2(at.x * 0.6 + w * 0.2, 0.0)
	var cone := PackedVector2Array([src - Vector2(4, 0), src + Vector2(4, 0),
			at + Vector2(w * 0.11, 0), at - Vector2(w * 0.11, 0)])
	draw_colored_polygon(cone, Color(1.0, 0.95, 0.82, 0.07))
	draw_set_transform_matrix(_view * Transform2D(0.0, Vector2(1.0, 0.22), 0.0, at))
	draw_circle(Vector2.ZERO, w * 0.11, Color(1.0, 0.95, 0.82, 0.16))
	draw_set_transform_matrix(_view)


## The lectern stage right, a microphone on its gooseneck.
func _draw_lectern(base: Vector2, scale: float) -> void:
	var u := PX_PER_M * scale
	var body := PackedVector2Array([base + Vector2(-0.28, 0) * u, base + Vector2(0.28, 0) * u,
			base + Vector2(0.24, -1.05) * u, base + Vector2(-0.24, -1.05) * u])
	draw_colored_polygon(body, Color(0.24, 0.2, 0.17))
	draw_rect(Rect2(base + Vector2(-0.3, -1.12) * u, Vector2(0.6, 0.08) * u), Color(0.3, 0.25, 0.21))
	draw_line(base + Vector2(0.14, -1.12) * u, base + Vector2(0.02, -1.42) * u, Color(0.6, 0.6, 0.62), maxf(1.0, scale))
	draw_circle(base + Vector2(0.0, -1.45) * u, 0.045 * u, Color(0.12, 0.12, 0.13))


## The room in front of the stage: round tables, dimly lit, a candle on each, the guests
## seated at them watching the stage, and the nearest heads big in the foreground - all in
## silhouette against the stage light. They applaud once the medal is on.
func _draw_audience(w: float, h: float, stage_y: float) -> void:
	var clap := _t >= 1.6
	var guest := Color(0.05, 0.048, 0.058)
	var rim := Color(0.62, 0.55, 0.46, 0.6)
	var table_y := stage_y + h * 0.17
	var r := h * 0.03
	for i in range(4):
		var cx := w * (0.13 + 0.25 * i)
		# Guests on the stage side of the table, then the table, then the near side.
		for gx in [-0.06, 0.06]:
			_guest(Vector2(cx + gx * w, table_y - h * 0.045), r * 0.85, guest, rim, clap, i * 5)
		draw_set_transform_matrix(_view * Transform2D(0.0, Vector2(1.0, 0.3), 0.0, Vector2(cx, table_y)))
		draw_circle(Vector2.ZERO, w * 0.085, Color(0.36, 0.34, 0.33))
		draw_circle(Vector2(0, -w * 0.012), w * 0.08, Color(0.44, 0.42, 0.4))
		draw_set_transform_matrix(_view)
		draw_circle(Vector2(cx, table_y - h * 0.012), 1.6, Color(1.0, 0.84, 0.5))
		draw_circle(Vector2(cx, table_y - h * 0.012), 6.0, Color(1.0, 0.75, 0.4, 0.14))
		for gx in [-0.085, 0.0, 0.085]:
			_guest(Vector2(cx + gx * w, table_y + h * 0.035), r, guest, rim, clap, i * 5 + 2)
	# The nearest guests, big and dark, cut by the frame: the camera is among them.
	for i in range(5):
		_guest(Vector2(w * (0.04 + 0.235 * i), h * 0.9), r * 2.1, Color(0.025, 0.025, 0.03),
				Color(0.5, 0.45, 0.4, 0.45), clap, i * 3 + 1)


## One guest from behind or across a table: head and shoulders, rim-lit by the stage;
## hands up and together when applauding.
func _guest(at: Vector2, r: float, body: Color, rim: Color, clap: bool, seed: int) -> void:
	var bob := sin(_t * 9.0 + seed * 1.7) * r * 0.06 if clap else 0.0
	var shoulders := PackedVector2Array([at + Vector2(-r * 1.3, r * 2.4), at + Vector2(-r * 1.15, r * 0.9),
			at + Vector2(-r * 0.5, r * 0.55), at + Vector2(r * 0.5, r * 0.55), at + Vector2(r * 1.15, r * 0.9),
			at + Vector2(r * 1.3, r * 2.4)])
	draw_colored_polygon(shoulders, body)
	var head := at + Vector2(0, bob)
	draw_circle(head, r * 0.62, body)
	draw_arc(head, r * 0.62, PI * 1.15, PI * 1.85, 8, rim, maxf(1.0, r * 0.12))
	if clap:
		var hands := at + Vector2(0, r * 0.2 + absf(sin(_t * 9.0 + seed)) * r * 0.25)
		draw_circle(hands + Vector2(-r * 0.12, 0), r * 0.2, body)
		draw_circle(hands + Vector2(r * 0.12, 0), r * 0.2, body)
