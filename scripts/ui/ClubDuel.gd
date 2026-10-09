class_name ClubDuel
extends Control
## Two clubs meeting (director, 2026-10-08: club colour as the atmosphere):
## each club's colour fills its side, darker toward the foot, the two meeting
## on a diagonal under a soft light, mown-turf bands across both and a fade
## at the foot so white type reads on any club. The backdrop of the match
## poster on the hub and the scoreboard in a match. Never takes a tap.

var _cols := [Color.BLACK, Color.BLACK]
var _fade := 0.55

static var _glow: GradientTexture2D


## `left` and `right` are club codes. `fade` darkens the foot (0..1).
func setup(left: String, right: String, fade := 0.55) -> ClubDuel:
	_cols = duel_colours(left, right)
	_fade = fade
	name = "ClubDuel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	return self


## The two colours a pairing shows: each club's main colour, or its most
## vivid one when the main is near black; if the two still look alike (both
## red, say), the right-hand club takes whichever of its colours differs most.
## A colour too dark to show is lifted.
static func duel_colours(left: String, right: String) -> Array:
	var a := _pick(left)
	var b := _pick(right)
	if _diff(a, b) < 0.45:
		var best := b
		var best_d := _diff(a, b)
		for c in GameDB.club_colours(right):
			var cc := _show(c)
			if cc.get_luminance() > 0.75:
				continue  # never white: the type on it is white
			var d := _diff(a, cc)
			if d > best_d:
				best_d = d
				best = cc
		b = best
	return [a, b]


## A club's colour for its side: its main colour, shown; a grey or black main
## hands over to its most vivid colour (Essendon's red, not its black).
static func _pick(code: String) -> Color:
	var cols: Array = GameDB.club_colours(code)
	var main: Color = cols[0]
	if main.s < 0.2 and main.get_luminance() < 0.3:
		var vivid := main
		for c in cols:
			var cc: Color = c
			if cc.s > vivid.s + 0.2 and cc.get_luminance() < 0.75:
				vivid = cc
		return _show(vivid)
	return _show(main)


static func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## A colour dark enough to vanish on the page is lifted until it shows.
static func _show(c: Color) -> Color:
	var out := c
	var guard := 0
	while out.get_luminance() < 0.16 and guard < 6:
		out = out.lightened(0.18)
		guard += 1
	return out


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cut := w * 0.5
	var slant := minf(h * 0.28, 40.0)
	_half([Vector2(0, 0), Vector2(cut + slant, 0), Vector2(cut - slant, h), Vector2(0, h)], _cols[0])
	_half([Vector2(cut + slant, 0), Vector2(w, 0), Vector2(w, h), Vector2(cut - slant, h)], _cols[1])
	# Mown turf: broad diagonal bands, barely there.
	var band := 34.0
	var i := -int(h / band) - 2
	while float(i) * band < w + h:
		if i % 2 == 0:
			var x := float(i) * band
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0),
					Vector2(x + band - h * 0.6, h), Vector2(x - h * 0.6, h)]), Color(0, 0, 0, 0.07))
		i += 1
	draw_line(Vector2(cut + slant, 0), Vector2(cut - slant, h), Color(1, 1, 1, 0.55), 2.0, true)
	var gs := h * 1.6
	draw_texture_rect(_glow_tex(), Rect2(Vector2(cut - gs / 2.0, -gs * 0.45), Vector2(gs, gs)), false)
	if _fade > 0.0:
		var a := Color(0, 0, 0, 0.0)
		var b := Color(0, 0, 0, _fade)
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([a, a, b, b]))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.10), false, 1.0)


func _half(pts: Array, c: Color) -> void:
	var top := c.darkened(0.25)
	var foot := c.darkened(0.62)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(foot, clampf((p as Vector2).y / maxf(1.0, size.y), 0.0, 1.0)))
	draw_polygon(PackedVector2Array(pts), cols)


## A soft light, white at the centre fading to nothing.
static func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.22))
		g.set_color(1, Color(1, 1, 1, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	return _glow


## A panel with this backdrop filling it edge to edge and `content` padded
## inside it by `pad`.
static func band(left: String, right: String, content: Control, pad := 12, fade := 0.45) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(Color(0, 0, 0, 0), 0, UiKit.RADIUS))
	p.clip_contents = true
	p.add_child(ClubDuel.new().setup(left, right, fade))
	var m := MarginContainer.new()
	for e in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + e, pad)
	m.add_child(content)
	p.add_child(m)
	return p


## White type that reads on a club colour: a soft shadow under it.
static func on_colour(l: Label) -> void:
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
