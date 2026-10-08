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
	var f: Dictionary = _season.finals
	if bool(f.get("done", false)):
		var prem := str(f.get("premier", ""))
		var h := UiKit.hbox(10)
		h.add_child(HonoursArt.view("premiership_cup", 64.0, prem, 0, ""))
		var t := UiKit.vbox(2)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	v.add_child(l)
	return v


## Every stage side by side, wildcard to the Grand Final.
func _wide() -> Control:
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 4.0 * 82.0 + 60.0
	var h := UiKit.hbox(14)
	h.name = "FinalsColumns"
	sc.add_child(h)
	for w in range(WEEKS.size()):
		# The stage's name on top, level across; its matches centred under it,
		# so each stage sits between the two that feed it.
		var outer := UiKit.vbox(8)
		outer.name = "Stage_%d" % (w + 1)
		outer.custom_minimum_size.x = NODE_W
		outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var head := UiKit.lbl(str(WEEKS[w][0]), UiKit.SMALL, UiKit.TEXT if w + 1 == _week() else UiKit.MUTED, w + 1 == _week())
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.custom_minimum_size.y = 34
		outer.add_child(head)
		var col := UiKit.vbox(10)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for m in WEEKS[w][2]:
			col.add_child(_node(w + 1, m))
		if w == WEEKS.size() - 1 and not bool(_season.finals.get("done", false)):
			col.add_child(HonoursArt.view("premiership_cup", 72.0, "", 0, ""))
		outer.add_child(col)
		h.add_child(outer)
	return sc


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


## A match: its label and venue, then each club with its score once played.
## The winner in weight; the side that went out, muted. A slot still to be
## decided says what it waits on.
func _node(week: int, m: Array) -> Control:
	var tag := str(m[0])
	var res := _result(week, tag)
	var home := _slot(str(m[2]))
	var away := _slot(str(m[3]))
	var b := Button.new()
	b.name = "Final_" + tag
	b.custom_minimum_size = Vector2(NODE_W, 72)
	UiKit.set_selected(b, home == _me or away == _me)
	var v := UiKit.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var venue := _season.finals_venue({"tag": tag, "home": home}) if home != "" else ""
	var head := UiKit.ellipsis(str(m[1]) + (("  ·  " + venue) if venue != "" else ""), UiKit.SMALL, UiKit.MUTED)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var win := str(_season.finals["slots"].get("W_" + tag, ""))
	for side in [0, 1]:
		var code := home if side == 0 else away
		var h := UiKit.hbox(6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if code == "":
			var wait := UiKit.ellipsis(_waiting(str(m[2 + side])), UiKit.SMALL, UiKit.FAINT)
			wait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(wait)
		else:
			var out := win != "" and win != code
			h.add_child(UiKit.club_marker(code, 16.0))
			var nm := UiKit.ellipsis(GameDB.club_short(code), UiKit.BODY, UiKit.MUTED if out else UiKit.TEXT, win == code)
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(nm)
			if not res.is_empty():
				var sc := UiKit.line(UiKit.scoreline(int(res["goals"][side]), int(res["behinds"][side])),
						UiKit.SMALL, UiKit.MUTED if out else UiKit.TEXT, win == code)
				sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
