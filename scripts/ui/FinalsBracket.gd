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
		var prem := str(f.get("premier", ""))
		var h := UiKit.hbox(14)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(HonoursArt.view("premiership_cup", 96.0, prem, 0, ""))
		var t := UiKit.vbox(2)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.add_child(UiKit.line("Premiers", UiKit.SMALL, UiKit.MUTED))
		var who := UiKit.figure(GameDB.club_short(prem), UiKit.RATING, UiKit.score_colour(prem))
		who.name = "FinalsPremier"
		t.add_child(who)
		h.add_child(t)
		v.add_child(h)
	var top: Array = f.get("top", [])
	var words := ""
	var done := bool(f.get("done", false))
	if not top.has(_me):
		words = "You missed the top %d." % Season.FINALISTS + ("" if done else " The series plays on week by week.")
	else:
		var out_in := ""
		for w in range(WEEKS.size()):
			for m in WEEKS[w][2]:
				if str(f["slots"].get("L_" + str(m[0]), "")) == _me:
					out_in = str(m[1])
		if bool(f.get("done", false)) and str(f.get("premier", "")) == _me:
			words = "Premiers."
		elif out_in != "":
			words = "Your season ended in the %s." % out_in + ("" if done else " The series plays on.")
		else:
			words = "You finished %s. Still alive." % _ordinal(top.find(_me) + 1)
	var l := UiKit.lbl(words, UiKit.BODY, UiKit.TEXT)
	l.name = "FinalsYou"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


## Where each result goes: [from tag, to tag, "W" winner / "L" loser].
const ROUTES := [
	["WC1", "EF2", "W"], ["WC2", "EF1", "W"], ["QF1", "PF1", "W"], ["QF1", "SF1", "L"],
	["QF2", "PF2", "W"], ["QF2", "SF2", "L"], ["EF1", "SF1", "W"], ["EF2", "SF2", "W"],
	["SF1", "PF1", "W"], ["SF2", "PF2", "W"], ["PF1", "GF", "W"], ["PF2", "GF", "W"],
]
const GF_H := 92.0
const CUP_H := 110.0


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
			var cup := HonoursArt.view("premiership_cup", FinalsBracket.CUP_H, "", 0, "")
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
	var pick := UiKit.choice_grid("FinalsStage", opts, str(shown), 3, func(k):
		_stage = int(k)
		_build.call_deferred())
	v.add_child(pick)
	v.add_child(UiKit.lbl(str(WEEKS[shown - 1][0]), UiKit.NAME, UiKit.TEXT, true))
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
