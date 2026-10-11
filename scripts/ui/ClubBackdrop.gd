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

## Set by a capture tool to record the stripes' slide value at every update.
static var trace := false
static var trail: Array = []

const SW := 150.0             # a stripe's width across the page
const DRIFT_PX_PER_SEC := 8.0 # the slow drift after the slide: this fast at first, easing to a stop
const DRIFT_SECS := 12.0      # (so 48 px in all; a stripe is 150 px wide)

const SHADER := """
shader_type canvas_item;
// Antialiased guernsey stripes, so they move by fractions of a pixel. Two
// stripe colours, each fading at the foot; a yellow club's get a full-
// brightness edge along the very top (above any text).
uniform vec2 area = vec2(390.0, 844.0);
uniform float offset = 0.0;
uniform float sw = 150.0;
uniform float run = 464.0;
uniform float edge = 6.0;
uniform vec4 top_a : source_color;
uniform vec4 top_b : source_color;
uniform vec4 foot_a : source_color;
uniform vec4 foot_b : source_color;
uniform vec4 raw_a : source_color;
uniform vec4 raw_b : source_color;
uniform vec2 gold = vec2(0.0, 0.0);

vec4 stripe(bool a, float y) {
	float g = clamp(y / area.y, 0.0, 1.0);
	vec4 c = a ? mix(top_a, foot_a, g) : mix(top_b, foot_b, g);
	float on = a ? gold.x : gold.y;
	vec4 r = a ? raw_a : raw_b;
	float e = 1.0 - smoothstep(edge - 0.5, edge + 0.5, y);
	return mix(c, r, on * e);
}

void fragment() {
	vec2 p = UV * area;
	float u = (p.x + run * p.y / area.y - offset) / sw;
	float k = floor(u);
	float f = fract(u);
	float cosine = area.y / sqrt(area.y * area.y + run * run);
	float t = min(f, 1.0 - f) * sw * cosine;   // pixels from the nearest stripe edge
	bool even = mod(k, 2.0) < 1.0;
	vec4 here = stripe(even, p.y);
	vec4 other = stripe(!even, p.y);
	// Only stripes from the page's left onward exist, so the slide enters from
	// off screen instead of shifting a pattern that already covers it.
	float cover = clamp(0.5 + (u + 2.0) * sw * cosine, 0.0, 1.0);
	COLOR = vec4(mix(other, here, clamp(0.5 + t, 0.0, 1.0)).rgb, cover);
}
"""

var _club := ""
var _settle := 1.0:        # 0 arriving -> 1 at rest: the slide (live())
	set(v):
		_settle = v
		_sync()
var _drift := 0.0:         # px the slow drift has carried the stripes
	set(v):
		_drift = v
		_sync()
var _raw: Array = []       # the club colours as they are, under the stripes (the gold edge)
var _stripes: ColorRect = null
var _rolling := false


func setup(club: String) -> ClubBackdrop:
	_club = club
	name = "ClubBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resized)
	if club != "":
		_stripes = ColorRect.new()
		_stripes.name = "Stripes"
		_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sh := Shader.new()
		sh.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_stripes.material = mat
		add_child(_stripes)
		var cols := _colours()
		var lab := func(c: Color) -> Color:
			return _from_oklab(_to_oklab(UiKit.BG).lerp(_to_oklab(c), FOOT_MIX))
		var b: Color = cols[1] if cols.size() > 1 else cols[0]
		var rb: Color = _raw[1] if _raw.size() > 1 else _raw[0]
		mat.set_shader_parameter("top_a", cols[0])
		mat.set_shader_parameter("top_b", b)
		mat.set_shader_parameter("foot_a", lab.call(cols[0]))
		mat.set_shader_parameter("foot_b", lab.call(b))
		mat.set_shader_parameter("raw_a", _raw[0])
		mat.set_shader_parameter("raw_b", rb)
		mat.set_shader_parameter("gold", Vector2(1.0 if _is_gold(_raw[0]) else 0.0, 1.0 if _is_gold(rb) else 0.0))
		_resized()
	return self


func _resized() -> void:
	queue_redraw()
	_sync()


## Hand the stripes' place to the shader: a float, so any fraction of a pixel.
func _sync() -> void:
	if _stripes == null:
		return
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	var run := h * 0.55   # how far a stripe leans across
	# Off to the right at the start (a page-width and the lean away), in place
	# once the slide is done, then drifting on left.
	var offset := (1.0 - _settle) * (w + run + SW * 3.0) - _drift
	var mat := _stripes.material as ShaderMaterial
	mat.set_shader_parameter("area", Vector2(w, h))
	mat.set_shader_parameter("run", run)
	mat.set_shader_parameter("offset", offset)
	# The turf bands roll into place with the slide (redrawn only while it runs).
	if _settle < 1.0 or _rolling:
		_rolling = _settle < 1.0
		queue_redraw()


## Living (director, 2026-10-11; "keep a slow drift"): the stripes sweep in from
## fully off screen over SLIDE_SECS, a pure ease-out, then keep drifting left
## at DRIFT_PX_PER_SEC, easing to a stop over DRIFT_SECS, and hold still. It is
## one tween that sets a shader offset: no _draw, antialiased edges (sub-pixel
## smooth), and once it ends nothing runs. Off under Reduced motion.
func live() -> ClubBackdrop:
	if not UiKit.motion_on():
		_settle = 1.0
		return self
	_settle = 0.0
	tree_entered.connect(func() -> void:
		Feel.moved.append("slide")
		Feel.moved.append("drift")
		var tw := create_tween()
		tw.tween_method(_at, 0.0, SLIDE_SECS + DRIFT_SECS, SLIDE_SECS + DRIFT_SECS),
		CONNECT_ONE_SHOT)
	if is_inside_tree():
		tree_entered.emit()
	return self


## The stripes at `t` seconds after arriving.
func _at(t: float) -> void:
	var k := clampf(t / SLIDE_SECS, 0.0, 1.0)
	var d := clampf((t - SLIDE_SECS) / DRIFT_SECS, 0.0, 1.0)
	_drift = DRIFT_PX_PER_SEC * DRIFT_SECS * 0.5 * (1.0 - (1.0 - d) * (1.0 - d))
	_settle = 1.0 - pow(1.0 - k, 3.0)
	if trace:
		trail.append(snappedf(_settle, 0.001))


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


static func _is_gold(c: Color) -> bool:
	var lab := _to_oklab(c)
	var chroma := Vector2(lab.y, lab.z).length()
	var hue := atan2(lab.z, lab.y)
	return chroma > 0.08 and hue > deg_to_rad(80.0) and hue < deg_to_rad(120.0) and lab.x > 0.7
