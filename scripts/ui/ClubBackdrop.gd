class_name ClubBackdrop
extends Control
## Behind a screen of yours (director, 2026-10-08: club colour as the
## atmosphere, the ground's texture instead of flat charcoal): the page
## colour, broad mown-turf bands barely lighter than it, and a wash of your
## club's colour from the top that fades away before the content needs the
## contrast. Drawn once; never takes a tap.

## Wide diagonal guernsey stripes of the club's colours (director, 2026-10-11:
## "Sweep"). Strength is capped so the muted grey type (a39e93) keeps 4.5:1
## wherever it sits: see tools/visual/measure_backdrop.gd. The top strength
## is fitted per colour (top_alpha); these two keep the foot-to-top ratio.
const SWEEP_TOP := 0.17
const SWEEP_FOOT := 0.05

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
	_draw_sweep(w, h, _colours())


## The club's own colours as they show on the page, its primary first (the
## home colour in the club data), then its second: Adelaide navy and red,
## Brisbane maroon and blue, Richmond yellow and black. Lifted when too dark to
## show, a near-white kept (a guernsey's white stripe).
func _colours() -> Array:
	var out: Array = []
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


## The strongest a stripe of this colour can be at the top of the page and
## still leave the muted grey type (a39e93) 4.5:1 or better: the page it makes
## may be no brighter than TOP_LUM. A dark colour (navy, maroon, red) can be
## far stronger than gold or white, so each is fitted on its own and every club
## reads equally "in colour" (director, 2026-10-11).
const TOP_LUM := 0.030


static func _rel_lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


static func top_alpha(c: Color) -> float:
	var lo := 0.0
	var hi := 0.6
	for _i in 14:
		var mid := (lo + hi) * 0.5
		if _rel_lum(UiKit.BG.lerp(c, mid)) <= TOP_LUM:
			lo = mid
		else:
			hi = mid
	return lo


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
		var a := top_alpha(c)
		var top := Color(c, a)
		var foot := Color(c, a * SWEEP_FOOT / SWEEP_TOP)
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + sw, 0),
				Vector2(x + sw - run, h), Vector2(x - run, h)]),
				PackedColorArray([top, top, foot, foot]))
