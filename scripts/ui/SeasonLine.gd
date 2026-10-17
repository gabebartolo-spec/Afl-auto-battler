class_name SeasonLine
extends Control
## The season line (season fitness): your planned legs against the legs your
## high-performance department delivers, week by week, over the whole year.
## Words, not numbers: Fresh above, Heavy below, the months along the bottom,
## the finals shaded, and a marker where the season is now.
## Dotted is the plan; solid is what you get; the dot is where the season is.

const GUTTER := 44.0       # the Fresh / Heavy words
const TOP := 8.0
const BOTTOM := 22.0       # the months
const LOW := -0.65
const HIGH := 1.1

var _rec := {}
var _hp := 2
var _now := 0


func setup(rec: Dictionary, hp_level: int, now_week: int) -> SeasonLine:
	_rec = rec
	_hp = hp_level
	_now = now_week
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _x(w: float) -> float:
	return GUTTER + (size.x - GUTTER) * w / float(Conditioning.LAST_WEEK)


func _y(c: float) -> float:
	var plot := size.y - TOP - BOTTOM
	return TOP + plot * (HIGH - c) / (HIGH - LOW)


func _draw() -> void:
	if size.x < 80.0 or _rec.is_empty():
		return
	var fine := 12
	# The finals, shaded.
	var fx := _x(Conditioning.FINALS_FIRST - 0.5)
	draw_rect(Rect2(fx, TOP, size.x - fx, size.y - TOP - BOTTOM), Color(UiKit.TEXT, 0.06))
	# Level legs: the line Steady runs along.
	draw_line(Vector2(GUTTER, _y(0.0)), Vector2(size.x, _y(0.0)), UiKit.LINE, 1.0)
	draw_string(UiKit.FONT, Vector2(0, TOP + float(fine)), "Fresh",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fine, UiKit.MUTED)
	draw_string(UiKit.FONT, Vector2(0, size.y - BOTTOM - 2.0), "Heavy",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fine, UiKit.MUTED)
	# The months, each where it starts; one that would run into the last is left out.
	var free_at := 0.0
	for m in Conditioning.MONTH_STARTS:
		var mx := _x(float(m[0]) - 0.5) + 2.0 if int(m[0]) > 0 else GUTTER
		var label := str(m[1]).substr(0, 3)
		var wide := UiKit.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fine).x
		if mx < free_at:
			continue
		draw_string(UiKit.FONT, Vector2(mx, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fine, UiKit.MUTED)
		free_at = mx + wide + 3.0
	# The plan, dotted.
	var planned := PackedVector2Array()
	var actual := PackedVector2Array()
	for w in range(Conditioning.LAST_WEEK + 1):
		planned.append(Vector2(_x(w), _y(Conditioning.planned(_rec, w))))
		actual.append(Vector2(_x(w), _y(Conditioning.legs(_rec, w, _hp))))
	_dotted(planned, UiKit.MUTED)
	draw_polyline(actual, UiKit.TEXT, 3.0, true)
	# Now.
	var nx := _x(_now)
	draw_line(Vector2(nx, TOP), Vector2(nx, size.y - BOTTOM), Color(UiKit.TEXT, 0.35), 1.0)
	draw_circle(actual[clampi(_now, 0, actual.size() - 1)], 5.0, UiKit.TEXT)


func _dotted(points: PackedVector2Array, colour: Color) -> void:
	# Dashes by distance along the whole line, so a short week-to-week step
	# does not draw as solid.
	var run := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var at := 0.0
		while at < length:
			var piece := minf(2.0, length - at)
			if int(run / 5.0) % 2 == 0:
				draw_line(a.lerp(b, at / length), a.lerp(b, (at + piece) / length), colour, 2.0)
			at += piece
			run += piece
