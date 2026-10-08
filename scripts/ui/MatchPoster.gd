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
	add_child(ClubDuel.new().setup(my_club, opp))
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
