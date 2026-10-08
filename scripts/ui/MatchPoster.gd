class_name MatchPoster
extends Control
## Your next match as a match-day poster (director, 2026-10-08: "dark mode
## doesn't need to be boring mode"): the two clubs' colours meet on a
## diagonal under a soft light, mown-turf bands across it, both guernseys big
## and the club names in the scoreboard face; the round, home or away, the
## ground and the forecast underneath. The hub's hero. Reads; changes nothing.

const H_NARROW := 196.0
const H_WIDE := 220.0

var _mine := ""
var _opp := ""
var _home := true
var _cols := [Color.BLACK, Color.BLACK]


## `line` is the fixture line under the clubs ("Round 1 · Away · Optus
## Stadium · Hot"). Your club sits on the left whoever is at home.
func setup(my_club: String, opp: String, is_home: bool, line: String, narrow: bool) -> MatchPoster:
	_mine = my_club
	_opp = opp
	_home = is_home
	_cols = [(GameDB.club_colours(my_club) as Array)[0], (GameDB.club_colours(opp) as Array)[0]]
	name = "MatchPoster"
	custom_minimum_size = Vector2(0, H_NARROW if narrow else H_WIDE)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var v := UiKit.vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var crest := 64.0 if narrow else 76.0
	row.add_child(_side(my_club, crest, narrow))
	var vs := UiKit.figure("v", UiKit.RATING, Color(1, 1, 1, 0.85))
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_side(opp, crest, narrow))
	# The opponent's full name for screen readers and tests, as before.
	var who := UiKit.lbl(GameDB.club_name(opp), UiKit.SMALL, Color(1, 1, 1, 0.0))
	who.name = "Opponent"
	who.visible = false
	v.add_child(who)
	var where := UiKit.lbl(line, UiKit.BODY, Color(1, 1, 1, 0.92), true)
	where.name = "MatchVenue"
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shade(where)
	v.add_child(where)
	return self


func _side(code: String, crest: float, narrow: bool) -> Control:
	var s := UiKit.vbox(4)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.alignment = BoxContainer.ALIGNMENT_CENTER
	var c := CenterContainer.new()
	c.add_child(UiKit.club_marker(code, crest))
	s.add_child(c)
	var n := UiKit.figure(GameDB.club_short(code), UiKit.SCORE if narrow else UiKit.RATING, Color.WHITE)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	s.add_child(n)
	return s


func _shade(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var r := Rect2(Vector2.ZERO, size)
	# Each club's half, darkened so white type reads on any colour, lighter at
	# the top: the light comes from above, as under a ground's towers.
	var mine: Color = _cols[0]
	var theirs: Color = _cols[1]
	var cut := w * 0.5
	var slant := h * 0.28
	_quad([Vector2(0, 0), Vector2(cut + slant, 0), Vector2(cut - slant, h), Vector2(0, h)], mine)
	_quad([Vector2(cut + slant, 0), Vector2(w, 0), Vector2(w, h), Vector2(cut - slant, h)], theirs)
	# Mown turf: broad diagonal bands, barely there.
	var band := 34.0
	var i := -int(h / band) - 2
	while float(i) * band < w + h:
		if i % 2 == 0:
			var x := float(i) * band
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0),
					Vector2(x + band - h * 0.6, h), Vector2(x - h * 0.6, h)]), Color(0, 0, 0, 0.07))
		i += 1
	# The seam where the clubs meet, and a light above it.
	draw_line(Vector2(cut + slant, 0), Vector2(cut - slant, h), Color(1, 1, 1, 0.55), 2.0, true)
	var glow := _glow_tex()
	var gs := h * 1.6
	draw_texture_rect(glow, Rect2(Vector2(cut - gs / 2.0, -gs * 0.45), Vector2(gs, gs)), false)
	# A fade at the foot so the fixture line sits on dark.
	_grad(Rect2(0, h * 0.55, w, h * 0.45), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(1, 1, 1, 0.10), false, 1.0)


static var _glow: GradientTexture2D


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


## A club's half: its colour, darker toward the foot.
func _quad(pts: Array, c: Color) -> void:
	var top := c.darkened(0.25)
	var foot := c.darkened(0.62)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(foot, clampf((p as Vector2).y / maxf(1.0, size.y), 0.0, 1.0)))
	draw_polygon(PackedVector2Array(pts), cols)


func _grad(r: Rect2, a: Color, b: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([a, a, b, b]))
