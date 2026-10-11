class_name ClubBackdrop
extends Control
## Behind a screen of yours (director, 2026-10-08: club colour as the
## atmosphere, the ground's texture instead of flat charcoal): the page
## colour, broad mown-turf bands barely lighter than it, and a wash of your
## club's colour from the top that fades away before the content needs the
## contrast. Drawn once; never takes a tap.

## Looks under review (director, 2026-10-11: "more club colours in there"):
## "sweep" diagonal guernsey stripes, "glow" two lights, "yoke" a bold top block
## with a stripe edge. One is chosen; the others go.
static var variant := "sweep"
static var _soft: GradientTexture2D
const YOKE_A := 0.34
const YOKE_B := 0.34
const SWEEP_TOP := 0.30
const SWEEP_FOOT := 0.07
const GLOW_A := 0.62
const GLOW_B := 0.5

var _club := ""
var _settle := 1.0   # 0 arriving -> 1 at rest (live())


func setup(club: String) -> ClubBackdrop:
	_club = club
	name = "ClubBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	return self


## Living (director, 2026-10-11): on arrival the club's colour floods in a
## little deeper and the turf bands roll into place over a few seconds, then
## it all holds still and draws nothing more (UiKit.drift).
func live() -> ClubBackdrop:
	UiKit.drift(self, func(t: float) -> void:
		_settle = t
		queue_redraw())
	return self


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	# Mown turf: wide bands across the page, a breath lighter in turn.
	var band := 64.0
	var roll := (1.0 - _settle) * band * 2.0
	var i := -2
	while float(i) * band + roll < h:
		if i % 2 == 0:
			draw_rect(Rect2(0, float(i) * band + roll, w, band), Color(1, 1, 1, 0.018))
		i += 1
	if _club == "":
		return
	var cols := _colours()
	match variant:
		"glow":
			_draw_glow(w, h, cols)
		"yoke":
			_draw_yoke(w, h, cols)
		_:
			_draw_sweep(w, h, cols)


## The club's colours as they show on the page, most vivid first: its
## colours, lifted when too dark, a near-white kept (a guernsey's white stripe).
func _colours() -> Array:
	var out: Array = []
	var vivid := _warm(UiKit.club_vivid(_club, UiKit.BG))
	out.append(vivid)
	for c in GameDB.club_colours(_club):
		var col: Color = _warm(ClubDuel._show(c))
		var dup := false
		for o in out:
			if ClubDuel._diff(col, o) < 0.3:
				dup = true
		if not dup:
			out.append(col)
	return out


## A yellow dimmed over a dark page turns olive. Leaning it toward amber keeps
## it reading as gold (Suns, Tigers) at the strength a backdrop can have.
static func _warm(c: Color) -> Color:
	if c.s > 0.6 and c.h > 0.10 and c.h < 0.19:
		return Color.from_hsv(0.105, 0.95, 1.0)
	return c


func _alpha(c: Color, a: float) -> Color:
	# A near-white stripe is brighter than a colour: half the strength.
	return Color(c, a * (0.55 if c.get_luminance() > 0.7 else 1.0))


## Wide diagonal stripes of the club's colours across the whole page, sliding
## into place; heavier at the top, never so strong that body type loses contrast.
func _draw_sweep(w: float, h: float, cols: Array) -> void:
	var sw := 150.0
	var run := h * 0.55   # how far a stripe leans across
	var slide := (1.0 - _settle) * sw * 5.0
	var n := int((w + run) / sw) + 8
	for k in range(-2, n):
		var c: Color = cols[posmod(k, mini(cols.size(), 2))]
		var x := float(k) * sw - slide
		var top := _alpha(c, SWEEP_TOP)
		var foot := _alpha(c, SWEEP_FOOT)
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + sw, 0),
				Vector2(x + sw - run, h), Vector2(x - run, h)]),
				PackedColorArray([top, top, foot, foot]))


## Two lights, the club's two colours, drifting in from opposite corners.
func _draw_glow(w: float, h: float, cols: Array) -> void:
	var a: Color = cols[0]
	var b: Color = cols[1] if cols.size() > 1 else cols[0]
	var gs := maxf(w, h) * 1.25
	var move := (1.0 - _settle)
	_light(Vector2(w * 0.1 - move * w * 0.5, h * 0.12 - move * h * 0.1), gs, _alpha(a, GLOW_A))
	_light(Vector2(w * 0.95 + move * w * 0.5, h * 0.82 + move * h * 0.1), gs * 0.9, _alpha(b, GLOW_B))


func _light(at: Vector2, d: float, c: Color) -> void:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1.0))
		g.set_color(1, Color(1, 1, 1, 0.0))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 256
		_soft.height = 256
	draw_texture_rect(_soft, Rect2(at - Vector2(d, d) / 2.0, Vector2(d, d)), false, c)


## The club's colour from the top, fading out down the page, with a soft band
## of its second colour that glides down into rest. Gradients only: nothing
## hard ever crosses a line of type.
func _draw_yoke(w: float, h: float, cols: Array) -> void:
	var a: Color = cols[0]
	var b: Color = cols[1] if cols.size() > 1 else cols[0]
	var block := h * 0.46
	var top := _alpha(a, YOKE_A + 0.10 * (1.0 - _settle))
	var none := Color(a, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, block), Vector2(0, block)]),
			PackedColorArray([top, top, none, none]))
	# The second colour: a slanted soft band, up in the hero at rest (it starts higher).
	var mid := h * 0.16 * (0.55 + 0.45 * _settle)
	var lean := 40.0
	var th := h * 0.12
	var peak := _alpha(b, YOKE_B)
	var zero := Color(b, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, mid - th), Vector2(w, mid - th - lean), Vector2(w, mid - lean), Vector2(0, mid)]),
			PackedColorArray([zero, zero, peak, peak]))
	draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(w, mid - lean), Vector2(w, mid - lean + th), Vector2(0, mid + th)]),
			PackedColorArray([peak, peak, zero, zero]))
