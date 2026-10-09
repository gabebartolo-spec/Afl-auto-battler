class_name GuernseyCrest
extends Control
## Club marker A: the club's own guernsey, front on, with its code on the
## chest (director approved; the art agent's spec, ard-asset-pipeline
## docs/forge_marker_singlet.md, drawn after tools/forge_markers.py
## guernsey_crest). A sleeveless AFL guernsey, never a T-shirt. All points are
## in a 100 x 100 box, y down, scaled by size / 100.

var primary := Color.WHITE
var secondary := Color.DIM_GRAY
var accent := Color.GOLD
var design := "plain"
var code := ""

static var _shapes := {}
## Club Forge paints the guernsey a part at a time: the part under the
## pointer is outlined ("body", "pattern", "trim" or "").
var highlight := ""


static func make(p: Color, s: Color, a: Color, p_design := "plain", p_code := "", size := 22.0) -> GuernseyCrest:
	var c := GuernseyCrest.new()
	c.primary = p
	c.secondary = s
	c.accent = a
	c.design = p_design
	c.code = p_code
	c.name = "ClubMarker"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


# --- the shapes, built once ----------------------------------------------

static func _quad(p0: Vector2, c: Vector2, p1: Vector2, n := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, n + 1):
		var t := float(i) / n
		out.append((1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * c + t * t * p1)
	return out


static func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n + 1):
		var a := a0 + (a1 - a0) * i / n
		out.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return out


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _mirror(shape: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(shape.size() - 1, -1, -1):
		out.append(Vector2(100.0 - shape[i].x, shape[i].y))
	return out


## A V band, apex on x = 50, `depth` deep, arms rising `slope` per unit across.
static func _vband(top: float, depth: float, slope := 0.9) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, top - 50 * slope), Vector2(50, top), Vector2(100, top - 50 * slope),
			Vector2(100, top - 50 * slope + depth), Vector2(50, top + depth), Vector2(0, top - 50 * slope + depth)])


static func shapes() -> Dictionary:
	if not _shapes.is_empty():
		return _shapes
	var neck_front := _arc(50, 6, 12, 10, PI, 0)
	var arm_r := _quad(Vector2(79, 12), Vector2(71.5, 25), Vector2(82, 35))
	var arm_l := PackedVector2Array()
	for v in arm_r:
		arm_l.append(Vector2(100.0 - v.x, v.y))
	var body := PackedVector2Array([Vector2(38, 6)])
	var back := _arc(50, 6, 12, 1.5, PI, 0)
	for i in range(1, back.size()):
		body.append(Vector2(back[i].x, 6.0 - (back[i].y - 6.0)))
	body.append(Vector2(79, 12))
	body.append_array(arm_r)
	body.append_array(PackedVector2Array([Vector2(81.4, 50), Vector2(80.2, 66), Vector2(80.6, 82), Vector2(81.6, 92.5)]))
	body.append_array(_quad(Vector2(81.6, 92.5), Vector2(81.6, 95.5), Vector2(78.5, 95.5), 3))
	body.append_array(_quad(Vector2(78.5, 95.5), Vector2(50, 96.5), Vector2(21.5, 95.5), 6))
	body.append_array(_quad(Vector2(21.5, 95.5), Vector2(18.4, 95.5), Vector2(18.4, 92.5), 3))
	body.append_array(PackedVector2Array([Vector2(19.4, 82), Vector2(19.8, 66), Vector2(18.6, 50), Vector2(18, 35)]))
	body.append_array(_quad(Vector2(18, 35), Vector2(28.5, 25), Vector2(21, 12)))
	# The inside of the back, seen through the neck.
	var inside := PackedVector2Array()
	for v in back:
		inside.append(Vector2(v.x, 6.0 - (v.y - 6.0)))
	for i in range(neck_front.size() - 1, -1, -1):
		inside.append(neck_front[i])
	var sides := PackedVector2Array([Vector2(0, 35), Vector2(28, 35), Vector2(30, 100), Vector2(0, 100)])
	var shoulders := PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(18, 37), Vector2(0, 37)])
	# The Giants' G: a ring open at the upper right, with its bar.
	var g_ring := _arc(50, 71.7, 16.6, 18, 0.17, TAU - 0.70, 24)
	var g_in := _arc(50, 71.7, 16.6 * 0.55, 18 * 0.55, 0.17, TAU - 0.70, 24)
	g_in.reverse()
	g_ring.append_array(g_in)
	var patterns := {
		"plain": [],
		"stripes": [["s", _rect(24, 0, 30, 100)], ["s", _rect(36, 0, 42, 100)], ["s", _rect(47, 0, 53, 100)],
				["s", _rect(58, 0, 64, 100)], ["s", _rect(70, 0, 76, 100)]],
		"hoops": [["s", _rect(0, 18, 100, 26)], ["s", _rect(0, 34, 100, 42)], ["s", _rect(0, 50, 100, 58)],
				["s", _rect(0, 66, 100, 74)], ["s", _rect(0, 82, 100, 90)]],
		"sash": [["s", PackedVector2Array([Vector2(68, 3), Vector2(80, 9), Vector2(30, 99), Vector2(18, 93)])]],
		"yoke": [["s", PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 26), Vector2(50, 42), Vector2(0, 26)])]],
		"band": [["s", _rect(0, 50, 100, 62)], ["a", _rect(0, 54.5, 100, 57.5)]],
		"chevrons": [["s", _vband(34, 5)], ["s", _vband(46, 5)], ["s", _vband(58, 5)]],
		"panels": [["s", _rect(36, 0, 64, 100)], ["a", _rect(0, 0, 36, 100)]],
		# As figure.gdshader draws it: a deep V from the shoulders, the second colour inside.
		"chevron": [["s", _vband(42, 14.4, 2.81)], ["a", _vband(27.6, 14.4, 2.81)]],
		"sides": [["s", sides], ["s", _mirror(sides)]],
		"tiers": [["s", _rect(0, 0, 100, 40)], ["a", _rect(0, 40, 100, 48)]],
		"shoulders": [["s", shoulders], ["s", _mirror(shoulders)]],
		"map": [["s", PackedVector2Array([Vector2(38, 40), Vector2(62, 40), Vector2(60, 50), Vector2(54, 64),
				Vector2(50, 70), Vector2(46, 62), Vector2(40, 50)])],
				["a", _rect(43, 44, 57, 48)], ["a", _rect(48.5, 44, 51.5, 60)]],
		# Real clubs' own designs, matching figure.gdshader's (box y = 96 - 90 x its height up).
		"lowhoops": [["s", _rect(0, 44.7, 100, 51.1)], ["a", _rect(0, 51.1, 100, 57.5)],
				["s", _rect(0, 63.9, 100, 70.3)], ["a", _rect(0, 70.3, 100, 76.7)],
				["s", _rect(0, 83.1, 100, 89.5)], ["a", _rect(0, 89.5, 100, 100)]],
		"giants": [["s", _rect(0, 0, 100, 45.6)], ["a", g_ring], ["a", _rect(50, 70.8, 66.6, 76.2)]],
		"wings": [["s", PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 60), Vector2(73.0, 60.0), Vector2(72.2, 52.5), Vector2(69.9, 45.6), Vector2(66.3, 39.6), Vector2(61.5, 35.1), Vector2(56.0, 32.2), Vector2(50.0, 31.2), Vector2(44.0, 32.2), Vector2(38.5, 35.1), Vector2(33.7, 39.6), Vector2(30.1, 45.6), Vector2(27.8, 52.5), Vector2(27.0, 60.0), Vector2(0, 60)])]],
		"twohoops": [["s", _rect(0, 53.7, 100, 61.8)], ["a", _rect(0, 65.4, 100, 73.5)]],
	}
	# Patterns clipped to the body once, in box units.
	var clipped := {}
	for key in patterns:
		var parts := []
		for item in patterns[key]:
			for poly in Geometry2D.intersect_polygons(item[1], body):
				parts.append([item[0], poly])
		clipped[key] = parts
	_shapes = {"body": body, "neck_front": neck_front, "arm_r": arm_r, "arm_l": arm_l,
			"inside": inside, "patterns": clipped}
	return _shapes


static func _scaled(pts: PackedVector2Array, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = pts[i] * u
	return out


## The letters' colour: whichever of accent, secondary, near-black or white
## stands furthest from the primary in luminance.
static func code_colour(p: Color, s: Color, a: Color) -> Color:
	var best := a
	var best_d := -1.0
	for c in [a, s, Color("#16110E"), Color("#F2F2F2")]:
		var d := absf(c.get_luminance() - p.get_luminance())
		if d > best_d:
			best_d = d
			best = c
	return best


func _draw() -> void:
	var sz := minf(size.x, size.y)
	if sz <= 0.0:
		return
	var u := sz / 100.0
	var sh := shapes()
	draw_colored_polygon(_scaled(sh["body"], u), primary)
	for part in (sh["patterns"] as Dictionary).get(design, []):
		draw_colored_polygon(_scaled(part[1], u), secondary if part[0] == "s" else accent)
	draw_colored_polygon(_scaled(sh["inside"], u), Color(primary.r * 0.45, primary.g * 0.45, primary.b * 0.45))
	var body := _scaled(sh["body"], u)
	body.append(body[0])
	draw_polyline(body, accent, maxf(1.0, 2.5 * u), true)
	draw_polyline(_scaled(sh["arm_r"], u), accent, maxf(1.0, 4.0 * u), true)
	draw_polyline(_scaled(sh["arm_l"], u), accent, maxf(1.0, 4.0 * u), true)
	draw_polyline(_scaled(sh["neck_front"], u), accent, maxf(2.0, 4.5 * u), true)
	if highlight != "":
		_draw_highlight(sh, u)
	# Under 32 px the code doesn't read: the guernsey alone.
	if code == "" or sz < 32.0:
		return
	var box := Rect2(28 * u, 42 * u, 44 * u, 44 * u)
	var font: Font = UiKit.DISPLAY
	var fs := int(box.size.y * (0.62 if code.length() <= 2 else (0.5 if code.length() == 3 else 0.4)))
	while fs > 6 and font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > box.size.x * 0.86:
		fs -= 1
	var tw := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var pos := Vector2(box.position.x + (box.size.x - tw) / 2.0,
			box.position.y + (box.size.y - asc) / 2.0 + asc - fs * 0.06)
	draw_string_outline(font, pos, code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, int(sz / 14.0)), primary)
	draw_string(font, pos, code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, code_colour(primary, secondary, accent))


## Which part of the guernsey is under `at` (local pixels): "trim" (the
## collar, armholes and edge, and a design's thin second stripe), "pattern",
## "body", or "" off the guernsey.
func part_at(at: Vector2) -> String:
	var sz := minf(size.x, size.y)
	if sz <= 0.0:
		return ""
	var q := at / (sz / 100.0)
	var sh := shapes()
	var near := func(line: PackedVector2Array, reach: float, closed: bool) -> bool:
		var n := line.size()
		for i in range(n - 1 + (1 if closed else 0)):
			var a: Vector2 = line[i]
			var b: Vector2 = line[(i + 1) % n]
			if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) <= reach:
				return true
		return false
	if near.call(sh["neck_front"], 4.0, false) or near.call(sh["arm_r"], 3.5, false) 			or near.call(sh["arm_l"], 3.5, false) or near.call(sh["body"], 2.5, true):
		return "trim"
	if not Geometry2D.is_point_in_polygon(q, sh["body"]):
		return ""
	for part in (sh["patterns"] as Dictionary).get(design, []):
		if Geometry2D.is_point_in_polygon(q, part[1]):
			return "pattern" if part[0] == "s" else "trim"
	return "body"


func _draw_highlight(sh: Dictionary, u: float) -> void:
	var ink := Color(1, 1, 1, 0.95)
	var w := maxf(1.5, 1.2 * u)
	var outline := func(poly: PackedVector2Array) -> void:
		var pts := _scaled(poly, u)
		pts.append(pts[0])
		draw_polyline(pts, ink, w, true)
	match highlight:
		"body":
			outline.call(sh["body"])
		"pattern", "trim":
			var tag := "s" if highlight == "pattern" else "a"
			for part in (sh["patterns"] as Dictionary).get(design, []):
				if part[0] == tag:
					outline.call(part[1])
			if highlight == "trim":
				draw_polyline(_scaled(sh["arm_r"], u), ink, maxf(1.0, 1.5 * u), true)
				draw_polyline(_scaled(sh["arm_l"], u), ink, maxf(1.0, 1.5 * u), true)
				draw_polyline(_scaled(sh["neck_front"], u), ink, maxf(1.0, 1.5 * u), true)
