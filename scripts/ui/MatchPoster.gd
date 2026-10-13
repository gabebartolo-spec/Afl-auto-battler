class_name MatchPoster
extends Control
## Your next match as a match-day poster (director, 2026-10-08: "dark mode
## doesn't need to be boring mode"): the two clubs' colours meet on a
## diagonal under a soft light, mown-turf bands across it, both guernseys big
## and the club names in the scoreboard face; the round, home or away, the
## ground and the forecast underneath. The hub's hero. Reads; changes nothing.

const H_NARROW := 196.0
const H_WIDE := 220.0
## The match ball between the two clubs, where the "v" was (director,
## 2026-10-14): this tall on a phone and on a wide screen.
const BALL_NARROW := 44.0
const BALL_WIDE := 56.0

var _mine := ""
var _opp := ""
var _home := true
var _cols := [Color.BLACK, Color.BLACK]
var _ball: TextureRect
var _ball_shadow: TextureRect
var _versus: Label
var _crest_box: Control

static var _shadow_tex: GradientTexture2D


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
	add_child(ClubDuel.new().setup(my_club, opp))
	var v := UiKit.vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var crest := 64.0 if narrow else 76.0
	var mine := _side(my_club, crest, narrow)
	_crest_box = mine.get_child(0)
	row.add_child(mine)
	var vs := UiKit.figure("v", UiKit.RATING, Color(1, 1, 1, 0.85))
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.name = "Versus"
	_versus = vs
	row.add_child(vs)
	# The ball takes the "v"'s place and none of the names' room: the "v"
	# keeps its slot, unseen, and the ball sits over it at the guernseys'
	# height. Without the picture the "v" shows, as before.
	_ball = UiArt.view("match_ball", BALL_NARROW if narrow else BALL_WIDE)
	if _ball != null:
		vs.self_modulate.a = 0.0
		_ball.name = "MatchBall"
		_ball_shadow = TextureRect.new()
		_ball_shadow.name = "MatchBallShadow"
		_ball_shadow.texture = _shadow()
		_ball_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ball_shadow.stretch_mode = TextureRect.STRETCH_SCALE
		_ball_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ball_shadow)
		add_child(_ball)
		row.sort_children.connect(_place_ball)
		v.sort_children.connect(_place_ball)
		resized.connect(_place_ball)
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


## The ball centred on the "v"'s slot, level with the guernseys, its shadow
## under it.
func _place_ball() -> void:
	if _ball == null or _versus == null or _crest_box == null:
		return
	var bs := _ball.custom_minimum_size
	var centre := Vector2(_versus.global_position.x + _versus.size.x / 2.0,
			_crest_box.global_position.y + _crest_box.size.y / 2.0) - global_position
	_ball.size = bs
	_ball.position = (centre - bs / 2.0).round()
	_ball_shadow.size = Vector2(bs.x * 0.9, bs.y * 0.34)
	_ball_shadow.position = Vector2(centre.x - bs.x * 0.42, centre.y + bs.y * 0.34).round()


## A soft shadow, dark at the centre fading to nothing.
static func _shadow() -> GradientTexture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.42))
		g.set_color(1, Color(0, 0, 0, 0.0))
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 64
		_shadow_tex.height = 64
	return _shadow_tex


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
