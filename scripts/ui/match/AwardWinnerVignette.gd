class_name AwardWinnerVignette
extends BroadcastVignette
## One club-colour stage scene for every award winner. Presentation only.

const REVEAL_TIME := 2.4
var club := ""
var number := 0

func setup_winner(code: String, jumper := 0) -> void:
	club = code
	number = jumper
	_colours[0] = GameDB.club_marker_colours(code)
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.43, 0.41, 0.38))
	# Club-colour curtains, all genuine marker colours including third bands.
	for i in range(cols.size()):
		var band := w * 0.18 / cols.size()
		draw_rect(Rect2(i * band, 12, band, h - 24), cols[i].darkened(0.18))
		draw_rect(Rect2(w - (i + 1) * band, 12, band, h - 24), cols[i].darkened(0.18))
	var floor_y := h * 0.84
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color(0.20, 0.18, 0.16))
	var walk := smoothstep(0.0, 1.4, _t)
	var x := lerpf(w * 0.23, w * 0.5, walk)
	var scale := minf(w / 260.0, h / 140.0)
	var stride := sin(_t * 10) * 2.0 * (1.0 - walk)
	_draw_player(Vector2(x, floor_y + stride), scale, cols, 0, 0.0, _t >= 1.8)
	# Keep the jumper number below the medal, where both remain readable.
	if number > 0:
		var font := ThemeDB.fallback_font
		var fs := maxi(8, int(10 * scale))
		var digits := str(number)
		var width := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(x - width / 2, floor_y - 25 * scale), digits,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _readable_on(cols[0]))
	# Medal settles onto the chest; no invented facial likeness or ethnicity.
	if _t >= 1.4:
		var chest := Vector2(x, floor_y - 43 * scale)
		var medal_y := lerpf(chest.y - 18 * scale, chest.y + 5 * scale, smoothstep(1.4, 1.9, _t))
		draw_line(chest + Vector2(-6, -8) * scale, Vector2(x, medal_y), Color(0.85, 0.82, 0.72), 2)
		draw_line(chest + Vector2(6, -8) * scale, Vector2(x, medal_y), Color(0.85, 0.82, 0.72), 2)
		draw_circle(Vector2(x, medal_y), 5 * scale, Color(0.75, 0.61, 0.34))
	# Letterbox matches the existing cinematic close-ups.
	draw_rect(Rect2(0, 0, w, 10), Color.BLACK)
	draw_rect(Rect2(0, h - 10, w, 10), Color.BLACK)