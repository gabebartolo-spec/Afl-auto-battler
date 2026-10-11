class_name ClubBackdrop
extends Control
## Behind a screen of yours (director, 2026-10-08: club colour as the
## atmosphere, the ground's texture instead of flat charcoal): the page
## colour, broad mown-turf bands barely lighter than it, and a wash of your
## club's colour from the top that fades away before the content needs the
## contrast. Drawn once; never takes a tap.

## Wide diagonal guernsey stripes of the club's own colours (director,
## 2026-10-11: "Sweep"). Each stripe is an opaque colour built in OKLCH: the
## club colour's hue and as much of its chroma as fits, with only its
## lightness capped so the muted grey type (a39e93) keeps 4.5:1 wherever it
## sits (see stripe_top, tools/visual/measure_backdrop.gd). Blending a light
## colour over the dark page shifted its hue (gold went olive); this doesn't.
const FOOT_MIX := 0.30        # how much of the stripe is left at the foot of the page
const TOP_LUM := 0.034        # brightest a stripe may be (relative luminance): MUTED >= 4.5
const SLIDE_SECS := 0.6       # the stripes sweep in from off-screen, eased out
const GOLD_EDGE := 6.0        # a yellow club's stripes are full-brightness gold this far down from the top, above any text

## Set by a capture tool to record the slide's value at every drawn frame.
static var trace := false
static var trail: Array = []

var _club := ""
var _settle := 1.0   # 0 arriving -> 1 at rest: the slide (live())
var _raw: Array = []   # the club colours as they are, under the stripes (the gold edge)


func setup(club: String) -> ClubBackdrop:
	_club = club
	name = "ClubBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	return self


## Living (director, 2026-10-11): on arrival the stripes sweep in from fully
## off screen over SLIDE_SECS, a pure ease-out (the biggest step on the first
## frame), every frame, then hold still and draw nothing more. (A slow creep
## after it was tried and dropped: at 2-6 px/s the edges step a whole pixel at a
## time, which is a flicker, not life.)
func live() -> ClubBackdrop:
	if not UiKit.motion_on():
		_settle = 1.0
		return self
	_settle = 0.0
	tree_entered.connect(func() -> void:
		Feel.moved.append("slide")
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			_settle = t
			queue_redraw(), 0.0, 1.0, SLIDE_SECS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT),
		CONNECT_ONE_SHOT)
	if is_inside_tree():
		tree_entered.emit()
	return self


func _draw() -> void:
	if trace:
		trail.append(snappedf(_settle, 0.001))
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


## The club's own colours, primary first (the home colour in the club data),
## then its second, each as the stripe it makes at the top of the page.
func _colours() -> Array:
	var out: Array = []
	_raw = []
	for c in GameDB.club_colours(_club):
		var col := stripe_top(c)
		var dup := false
		for o in out:
			if ClubDuel._diff(col, o) < 0.12:
				dup = true
		if not dup:
			out.append(col)
			_raw.append(c)
		if out.size() == 2:
			break
	return out


## OKLCH <-> sRGB (Ottosson's OKLab).
static func _to_oklab(c: Color) -> Vector3:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = f.call(c.r)
	var g: float = f.call(c.g)
	var b: float = f.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
			1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


## The colour for an OKLab triple, or alpha 0 if it is outside sRGB.
static func _from_oklab(v: Vector3) -> Color:
	var l := pow(v.x + 0.3963377774 * v.y + 0.2158037573 * v.z, 3.0)
	var m := pow(v.x - 0.1055613458 * v.y - 0.0638541728 * v.z, 3.0)
	var s := pow(v.x - 0.0894841775 * v.y - 1.2914855480 * v.z, 3.0)
	var lin := [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
			-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
			-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s]
	var out := []
	for x in lin:
		if x < -0.0005 or x > 1.0005:
			return Color(0, 0, 0, 0)
		var xc := clampf(x, 0.0, 1.0)
		out.append(12.92 * xc if xc <= 0.0031308 else 1.055 * pow(xc, 1.0 / 2.4) - 0.055)
	return Color(out[0], out[1], out[2])


static func _rel_lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


## The club colour at its brightest the page can carry: its OKLCH hue and
## chroma kept (chroma only shrinks to stay inside sRGB; yellow leans to amber),
## lightness lowered
## until the stripe's luminance is TOP_LUM or less. A colour already darker
## than that keeps its own lightness, but never darker than the page itself.
static func stripe_top(c: Color) -> Color:
	var lab := _to_oklab(c)
	var chroma := Vector2(lab.y, lab.z).length()
	var hue := atan2(lab.z, lab.y)
	# A yellow this dark can only be olive; leaning it to amber (OKLCH 75 deg)
	# keeps it reading as gold (Suns, Tigers, Crows' second colour).
	if chroma > 0.08 and hue > deg_to_rad(80.0) and hue < deg_to_rad(120.0):
		hue = deg_to_rad(75.0)
	var floor_l := _to_oklab(UiKit.BG).x + 0.02
	var l := lab.x
	var guard := 0
	while guard < 60:
		var cc := chroma
		var col := Color(0, 0, 0, 0)
		while cc >= 0.0:
			col = _from_oklab(Vector3(l, cc * cos(hue), cc * sin(hue)))
			if col.a > 0.0:
				break
			cc -= 0.004
		if col.a > 0.0 and _rel_lum(col) <= TOP_LUM:
			return col
		l -= 0.01
		guard += 1
		if l < floor_l:
			break
	return UiKit.BG.lightened(0.04)


## Wide diagonal stripes of the club's colours across the whole page, sliding
## in from the right; the stripe fades toward the page at the foot, in OKLab so
## it stays the same colour. Never so bright that body type loses contrast.
func _draw_sweep(w: float, h: float, cols: Array) -> void:
	var sw := 150.0
	var run := h * 0.55   # how far a stripe leans across
	var n := int((w + run) / sw) + 8
	# Off to the right at the start (a whole page-width and the lean away).
	var slide := (1.0 - _settle) * (w + run + sw * 3.0)
	var bg := _to_oklab(UiKit.BG)
	for k in range(-2, n):
		var c: Color = cols[posmod(k, mini(cols.size(), 2))]
		var x := float(k) * sw + slide
		var foot := _from_oklab(bg.lerp(_to_oklab(c), FOOT_MIX))
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + sw, 0),
				Vector2(x + sw - run, h), Vector2(x - run, h)]),
				PackedColorArray([c, c, foot, foot]))
		if _is_gold(_raw[posmod(k, cols.size())]):
			# Yellow IS the club: full brightness along the top edge, where no
			# text sits (the page's own inset keeps type below it).
			var e := GOLD_EDGE
			var xe := x - run * e / h
			draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + sw, 0),
					Vector2(xe + sw, e), Vector2(xe, e)]), PackedColorArray([_raw[posmod(k, cols.size())]]))


static func _is_gold(c: Color) -> bool:
	var lab := _to_oklab(c)
	var chroma := Vector2(lab.y, lab.z).length()
	var hue := atan2(lab.z, lab.y)
	return chroma > 0.08 and hue > deg_to_rad(80.0) and hue < deg_to_rad(120.0) and lab.x > 0.7
