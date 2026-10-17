class_name FinalsBracket
extends VBoxContainer
## The finals series as an event (director, 2026-10-07: a bespoke Finals hub,
## wildcard included): the ten finalists' road from the Wildcard Round to the
## Grand Final, read from the season's own bracket (Season.finals) - results
## where played, this week's matches, and later matches named by the slot
## they wait on ("Winner of Wildcard Final 1"), never a simulated outcome.
## A wide screen shows every stage side by side, the cup at the end; a phone
## shows one stage at a time. A tap on a match calls `on_match` with it.
## Reads; changes nothing.

## Each week's matches: [tag, label, home slot, away slot]. A slot is a seed
## ("S1".."S10") or a bracket result ("W_WC1", "L_QF1"), as Season fills them.
const WEEKS := [
	["Wildcard Round", "Wildcard", [["WC1", "Wildcard Final 1", "S7", "S10"], ["WC2", "Wildcard Final 2", "S8", "S9"]]],
	["Qualifying and Elimination Finals", "Qualifying", [["QF1", "Qualifying Final 1", "S1", "S4"],
			["QF2", "Qualifying Final 2", "S2", "S3"], ["EF1", "Elimination Final 1", "S5", "W_WC2"],
			["EF2", "Elimination Final 2", "S6", "W_WC1"]]],
	["Semi Finals", "Semis", [["SF1", "Semi Final 1", "L_QF1", "W_EF1"], ["SF2", "Semi Final 2", "L_QF2", "W_EF2"]]],
	["Preliminary Finals", "Prelims", [["PF1", "Preliminary Final 1", "W_QF1", "W_SF1"],
			["PF2", "Preliminary Final 2", "W_QF2", "W_SF2"]]],
	["Grand Final", "Grand Final", [["GF", "Grand Final", "W_PF1", "W_PF2"]]],
]
const WIDE := 900.0
const NODE_W := 168.0
const NODE_H := 70.0

var _season: Season
var _me := ""
var _on_match: Callable
var _stage := -1          # the stage shown on a phone; -1 = this week


func setup(season: Season, my_club: String, on_match: Callable = Callable()) -> FinalsBracket:
	_season = season
	_me = my_club
	_on_match = on_match
	name = "FinalsBracket"
	add_theme_constant_override("separation", UiKit.GAP)
	if is_inside_tree():
		_build()
	return self


func _ready() -> void:
	if _season != null and get_child_count() == 0:
		_build()


func _week() -> int:
	return int(_season.finals.get("week", 1)) if not _season.finals.is_empty() else 1


func _build() -> void:
	UiKit.clear(self)
	if _season == null or _season.finals.is_empty():
		add_child(UiKit.lbl("The finals start after the last home-and-away round.", UiKit.BODY, UiKit.MUTED))
		return
	add_child(_status())
	if UiKit.view_width(self) >= WIDE:
		add_child(_wide())
	else:
		add_child(_narrow())


## Where you stand, in a line; the premiers once it's decided.
func _status() -> Control:
	var v := UiKit.vbox(4)
	v.name = "FinalsStatus"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var f: Dictionary = _season.finals
	if bool(f.get("done", false)):
		v.add_child(_premiers(str(f.get("premier", ""))))
	var top: Array = f.get("top", [])
	var words := ""
	var done := bool(f.get("done", false))
	if not top.has(_me):
		words = "You missed the top %d." % Season.FINALISTS + ("" if done else " The series plays on week by week.")
	else:
		var out_in := ""
		for w in range(WEEKS.size()):
			for m in WEEKS[w][2]:
				# A qualifying final's loser plays on (the double chance): only the others end a season.
				if str(m[0]).begins_with("QF"):
					continue
				if str(f["slots"].get("L_" + str(m[0]), "")) == _me:
					out_in = str(m[1])
		if bool(f.get("done", false)) and str(f.get("premier", "")) == _me:
			words = ""   # the cup over this line already says it
		elif out_in != "":
			words = "Your season ended in the %s." % out_in + ("" if done else " The series plays on.")
		else:
			words = "You finished %s. Still alive." % _ordinal(top.find(_me) + 1)
	if words == "":
		return v
	var l := UiKit.lbl(words, UiKit.BODY, UiKit.TEXT)
	l.name = "FinalsYou"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


## The premiers, as the occasion it is (director, 2026-10-14: the cup big, in
## the winner's colours): the cup standing in the premier's colour under a
## soft light, the club's name in the scoreboard face. The cup stays silver;
## the colour is the room it stands in.
const HERO_CUP_NARROW := 150.0
const HERO_CUP_WIDE := 132.0
## The cup over the Grand Final on a phone, before it is decided.
const STAGE_CUP := 120.0


func _premiers(prem: String) -> Control:
	var wide := UiKit.view_width(self) >= WIDE
	var p := PanelContainer.new()
	p.name = "FinalsHero"
	p.add_theme_stylebox_override("panel", UiKit.style(Color(0, 0, 0, 0), 0, UiKit.RADIUS))
	p.clip_contents = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wash := Wash.new()
	wash.name = "FinalsWash"
	wash.colour = ClubDuel._banner(UiKit.club_ink(prem))
	p.add_child(wash)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + e, 14)
	p.add_child(m)
	var row: BoxContainer = UiKit.hbox(20) if wide else UiKit.vbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(row)
	var cup := _cup(HERO_CUP_WIDE if wide else HERO_CUP_NARROW)
	cup.name = "FinalsHeroCup"
	# The premiers' ribbons on the handles, in the club's two colours (director,
	# 2026-10-14: the silver cup with the premier's ribbon). Drawn in the cup
	# art's own square, so they lie straight over it.
	var ribbons := _ribbons(prem, HERO_CUP_WIDE if wide else HERO_CUP_NARROW)
	if ribbons != null:
		cup.add_child(ribbons)
	cup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(cup)
	var t := UiKit.vbox(0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var said := UiKit.line("Premiers", UiKit.BODY, Color.WHITE)
	ClubDuel.on_colour(said)
	# One name for the premiers on every screen: the name the bracket under it uses.
	var who := UiKit.figure(GameDB.club_short(prem), UiKit.HERO, Color.WHITE)
	who.name = "FinalsPremier"
	ClubDuel.on_colour(who)
	if not wide:
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_child(said)
	t.add_child(who)
	row.add_child(t)
	return p


## The cup art's own shadow runs to the picture's edge, which shows as a box
## on a colour: here it fades out before the edge. The cup itself is untouched.
const CUP_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float shadow = 1.0 - step(0.012, max(c.r, max(c.g, c.b)));
	float keep = smoothstep(0.0, 0.2, min(UV.x, 1.0 - UV.x)) * smoothstep(0.0, 0.05, 1.0 - UV.y);
	c.a *= mix(1.0, keep, shadow);
	COLOR = c * COLOR;
}
"""
static var _cup_mat: ShaderMaterial


## The premiership cup `height` tall, silver as drawn (never tinted).
func _cup(height: float) -> Control:
	var cup := HonoursArt.view("premiership_cup", height, "", 0, "Premiership cup")
	var art := cup.find_child("Art_premiership_cup", true, false) as TextureRect
	if art == null and cup.get_child_count() > 0:
		art = cup.get_child(0) as TextureRect
	if art != null:
		if _cup_mat == null:
			_cup_mat = ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = CUP_SHADER
			_cup_mat.shader = sh
		art.material = _cup_mat
	return cup


## The premiers' ribbons: not an honour, so not in honours.json. Drawn in the
## cup art's own 512 square (same foot line), coloured by the honours tint
## shader: R of the mask takes the club's first colour, G its second.
const RIBBONS := "res://assets/honours/premiership_ribbons.png"
const RIBBONS_MASK := "res://assets/honours/premiership_ribbons_mask.png"
const RIBBONS_SHADER := "res://assets/honours/honours_tint.gdshader"


## The ribbons at the cup's height in `club`'s colours, laid exactly over the
## cup's picture; null without the files.
func _ribbons(club: String, height: float) -> Control:
	if not (ResourceLoader.exists(RIBBONS) and ResourceLoader.exists(RIBBONS_MASK) and ResourceLoader.exists(RIBBONS_SHADER)):
		return null
	var tex: Texture2D = load(RIBBONS)
	var cup_tex := HonoursArt.texture("premiership_cup")
	var scale := height / float(maxi(1, tex.get_height()))
	var art := TextureRect.new()
	art.name = "Art_premiership_ribbons"
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = Vector2(round(tex.get_width() * scale), height)
	# The cup's picture sits with its foot on the slot's edge (HonoursArt's base_y).
	var base_y := float(HonoursArt.entry("premiership_cup").get("base_y", tex.get_height()))
	art.position.y = (float(tex.get_height()) - base_y) * scale if cup_tex != null else 0.0
	var colours := GameDB.club_colours(club)
	var m := ShaderMaterial.new()
	m.shader = load(RIBBONS_SHADER)
	m.set_shader_parameter("mask_tex", load(RIBBONS_MASK))
	m.set_shader_parameter("primary", colours[0])
	m.set_shader_parameter("secondary", colours[1])
	art.material = m
	var slot := Control.new()
	slot.name = "FinalsRibbons"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)
	return slot


## The premier's colour as the room the cup stands in: full at the head,
## deeper toward the foot, a soft light where the cup is.
class Wash extends Control:
	var colour := Color.BLACK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var top := colour.darkened(0.2)
		var foot := colour.darkened(0.68)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([top, top, foot, foot]))
		var gs := maxf(size.y * 1.7, 260.0)
		draw_texture_rect(ClubDuel._glow_tex(), Rect2(Vector2(size.x / 2.0 - gs / 2.0, -gs * 0.3), Vector2(gs, gs)), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.10), false, 1.0)


## The cup the two Grand Finalists play for, over their match on a phone:
## between both clubs' colours once both are known, on the page until then.
func _stage_cup() -> Control:
	var cup := _cup(STAGE_CUP)
	cup.name = "FinalsCup"
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cup)
	var home := _slot("W_PF1")
	var away := _slot("W_PF2")
	if home == "" or away == "":
		return c
	var band := ClubDuel.band(home, away, c, 10, 0.35)
	band.name = "FinalsCupBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


## Where each result goes: [from tag, to tag, "W" winner / "L" loser].
const ROUTES := [
	["WC1", "EF2", "W"], ["WC2", "EF1", "W"], ["QF1", "PF1", "W"], ["QF1", "SF1", "L"],
	["QF2", "PF2", "W"], ["QF2", "SF2", "L"], ["EF1", "SF1", "W"], ["EF2", "SF2", "W"],
	["SF1", "PF1", "W"], ["SF2", "PF2", "W"], ["PF1", "GF", "W"], ["PF2", "GF", "W"],
]
const GF_H := 92.0
const CUP_H := 130.0


## Every stage side by side, wildcard to the Grand Final, centred on the
## screen, joined by the routes results take; the premiers' road drawn in
## their colour.
func _wide() -> Control:
	var c := BracketCanvas.new()
	c.name = "FinalsColumns"
	c.call("setup", self)
	return c


class BracketCanvas extends Control:
	var _fb: FinalsBracket
	var _nodes := {}        # tag -> Button
	var _heads: Array = []  # stage headings

	func setup(fb: FinalsBracket) -> void:
		_fb = fb
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 4.0 * (FinalsBracket.NODE_H + 18.0) + 70.0)
		for w in range(FinalsBracket.WEEKS.size()):
			var cur := w + 1 == _fb._week()
			var h := UiKit.heading(str(FinalsBracket.WEEKS[w][0]), UiKit.H2 if w == 4 else UiKit.BODY)
			h.add_theme_color_override("font_color", UiKit.TEXT if cur or w == 4 else UiKit.MUTED)
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(h)
			_heads.append(h)
			for m in FinalsBracket.WEEKS[w][2]:
				var n := _fb._node(w + 1, m)
				_nodes[str(m[0])] = n
				add_child(n)
		if not bool(_fb._season.finals.get("done", false)):
			var cup := _fb._cup(FinalsBracket.CUP_H)
			cup.name = "FinalsCup"
			add_child(cup)
			_nodes["_cup"] = cup
		resized.connect(_place)

	func _ready() -> void:
		_place()

	func _cols() -> Array:
		var w := size.x
		var gap := 28.0
		var nw := clampf((w - 4.0 * gap) / 5.0, 150.0, 230.0)
		var total := 5.0 * nw + 4.0 * gap
		var left := maxf(0.0, (w - total) / 2.0)
		var out := []
		for i in range(5):
			out.append(left + float(i) * (nw + gap))
		return [out, nw]

	func _place() -> void:
		if _fb == null:
			return
		var cw: Array = _cols()
		var xs: Array = cw[0]
		var nw: float = cw[1]
		var top := 44.0
		var body := size.y - top
		for w in range(FinalsBracket.WEEKS.size()):
			var head: Control = _heads[w]
			head.position = Vector2(xs[w], 0)
			head.size = Vector2(nw, 40)
			var ms: Array = FinalsBracket.WEEKS[w][2]
			var nh := FinalsBracket.GF_H if w == 4 else FinalsBracket.NODE_H
			for i in range(ms.size()):
				var n: Control = _nodes[str(ms[i][0])]
				var cy := top + body * (float(i) + 0.5) / float(ms.size())
				n.position = Vector2(xs[w], cy - nh / 2.0)
				n.size = Vector2(nw, nh)
				n.custom_minimum_size = Vector2(nw, nh)
		if _nodes.has("_cup"):
			var cup: Control = _nodes["_cup"]
			var gf: Control = _nodes["GF"]
			cup.position = Vector2(xs[4] + (nw - cup.get_combined_minimum_size().x) / 2.0,
					gf.position.y - FinalsBracket.CUP_H - 10.0)
		queue_redraw()

	func _draw() -> void:
		var slots: Dictionary = _fb._season.finals.get("slots", {})
		var prem := str(_fb._season.finals.get("premier", ""))
		for r in FinalsBracket.ROUTES:
			var a: Control = _nodes.get(str(r[0]))
			var b: Control = _nodes.get(str(r[1]))
			if a == null or b == null:
				continue
			var who := str(slots.get(str(r[2]) + "_" + str(r[0]), ""))
			var p0 := Vector2(a.position.x + a.size.x, a.position.y + a.size.y / 2.0)
			var p1 := Vector2(b.position.x, b.position.y + b.size.y / 2.0)
			var mid := p1.x - 14.0
			var col := UiKit.LINE
			var wdt := 1.5
			if who != "" and who == prem:
				col = UiKit.score_colour(prem)
				wdt = 3.0
			elif who != "" and who == _fb._me:
				col = UiKit.TEXT
				wdt = 2.0
			elif str(r[2]) == "L":
				col = Color(UiKit.LINE, 0.6)
			var pts := PackedVector2Array([p0, Vector2(mid, p0.y), Vector2(mid, p1.y), p1])
			draw_polyline(pts, col, wdt, true)


## One stage at a time; the picker opens on this week.
func _narrow() -> Control:
	var v := UiKit.vbox(UiKit.GAP)
	var opts := []
	for w in range(WEEKS.size()):
		opts.append([str(w + 1), str(WEEKS[w][1])])
	var shown := _stage if _stage > 0 else mini(_week(), WEEKS.size())
	# The weeks as one line of underline tabs (audit §8 Phase 1.3); the week
	# shown is named in full underneath.
	var pick := UiKit.segmented("FinalsStage", opts, str(shown), func(k):
		_stage = int(k)
		_build.call_deferred())
	v.add_child(UiKit.strip(pick))
	v.add_child(UiKit.lbl(str(WEEKS[shown - 1][0]), UiKit.NAME, UiKit.TEXT, true))
	if shown == WEEKS.size() and not bool(_season.finals.get("done", false)):
		v.add_child(_stage_cup())
	for m in WEEKS[shown - 1][2]:
		var n := _node(shown, m)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(n)
	return v


## A match: its label and venue, then each club - a strip in its colours,
## its name, its score once played. The winner in weight with his score in
## his colour; the side that went out, muted. A slot still to be decided
## says what it waits on.
func _node(week: int, m: Array) -> Control:
	var tag := str(m[0])
	var res := _result(week, tag)
	var home := _slot(str(m[2]))
	var away := _slot(str(m[3]))
	var b := Button.new()
	b.name = "Final_" + tag
	b.custom_minimum_size = Vector2(NODE_W, NODE_H)
	b.clip_contents = true
	var mine := home == _me or away == _me
	var sb := UiKit.style(UiKit.PANEL_ALT if tag == "GF" else UiKit.PANEL, 8, UiKit.RADIUS,
			UiKit.TEXT if mine else UiKit.AUTO_COLOUR)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var v := UiKit.vbox(3)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var venue := _season.finals_venue({"tag": tag, "home": home}) if home != "" else ""
	v.add_child(UiKit.ellipsis(str(m[1]) + (("  ·  " + venue) if venue != "" else ""), UiKit.SMALL, UiKit.MUTED))
	var win := str(_season.finals["slots"].get("W_" + tag, ""))
	for side in [0, 1]:
		var code := home if side == 0 else away
		var h := UiKit.hbox(8)
		if code == "":
			h.add_child(UiKit.ellipsis(_waiting(str(m[2 + side])), UiKit.SMALL, UiKit.FAINT))
		else:
			var out := win != "" and win != code
			var strip := ColorRect.new()
			strip.color = Color(UiKit.score_colour(code), 0.45 if out else 1.0)
			strip.custom_minimum_size = Vector2(4, 0)
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(strip)
			var fs := UiKit.NAME if tag == "GF" else UiKit.BODY
			h.add_child(UiKit.ellipsis(GameDB.club_short(code), fs, UiKit.MUTED if out else UiKit.TEXT, win == code))
			if not res.is_empty():
				var sc := UiKit.line(UiKit.scoreline(int(res["goals"][side]), int(res["behinds"][side])),
						UiKit.SMALL, UiKit.score_colour(code) if win == code else UiKit.MUTED, win == code)
				h.add_child(sc)
		v.add_child(h)
	b.add_child(v)
	for n in b.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ready := home != "" and away != ""
	b.disabled = not ready
	if ready and _on_match.is_valid():
		var md := {"tag": tag, "label": str(m[1]), "home": home, "away": away, "week": week, "res": res}
		b.pressed.connect(func(): _on_match.call(md))
	return b


func _slot(slot: String) -> String:
	if slot.begins_with("S"):
		var top: Array = _season.finals.get("top", [])
		var i := int(slot.substr(1)) - 1
		return str(top[i]) if i >= 0 and i < top.size() else ""
	return str(_season.finals["slots"].get(slot, ""))


func _waiting(slot: String) -> String:
	var tag := slot.substr(2)
	for w in WEEKS:
		for m in w[2]:
			if str(m[0]) == tag:
				return ("Winner of " if slot.begins_with("W_") else "Loser of ") + str(m[1])
	return "To be decided"


func _result(week: int, tag: String) -> Dictionary:
	var weeks: Array = _season.finals.get("weeks", [])
	if week - 1 < weeks.size():
		for r in weeks[week - 1]:
			if str(r.get("tag", "")) == tag:
				return r
	return {}


static func _ordinal(n: int) -> String:
	var s := "th"
	if n % 100 < 11 or n % 100 > 13:
		s = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, s]
