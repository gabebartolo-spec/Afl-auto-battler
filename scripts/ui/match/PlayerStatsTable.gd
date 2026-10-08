class_name PlayerStatsTable
extends VBoxContainer
## Every player's match, both clubs: a tab per club (yours first), a row per
## player with his rating and the headline numbers, sortable by any column.
## On a wide screen more columns sit in the row (the director's PC playtest:
## sparse rows meant scrolling); a key under the table spells out every
## heading, since a phone has no hover. Tap a row for the rest of his line.
## Reads a match result (finished or at a break); changes nothing.

## Headline columns: [stat key ("rating" is the match rating), header, width].
const COLUMNS := [
	["rating", "Rating", 48], ["disposals", "D", 30], ["goals", "G", 26],
	["marks", "M", 28], ["tackles", "T", 28], ["clearances", "CL", 30],
]
## A wide screen's columns: the phone's, then the rest of a line worth
## comparing down the table. Disposals stays the second column.
const WIDE_COLUMNS := [
	["rating", "Rating", 52], ["disposals", "D", 34], ["kicks", "K", 32], ["handballs", "H", 32],
	["marks", "M", 32], ["contested_marks", "CM", 36], ["tackles", "T", 32], ["clearances", "CL", 34],
	["inside50", "I50", 36], ["intercepts", "INT", 36], ["pressure_acts", "PA", 34],
	["goals", "G", 30], ["behinds", "B", 30],
]
const NAMES := {
	"rating": "match rating", "disposals": "disposals", "kicks": "kicks", "handballs": "handballs",
	"marks": "marks", "contested_marks": "contested marks", "tackles": "tackles",
	"clearances": "clearances", "inside50": "inside 50s", "intercepts": "intercepts",
	"pressure_acts": "pressure acts", "goals": "goals", "behinds": "behinds",
}
## The rest of the line, shown when a row is opened.
const DETAIL := [
	["distance_run", "distance covered"], ["pressure_acts", "pressure acts"], ["kicks", "kicks"], ["handballs", "handballs"], ["metres_gained", "metres gained"],
	["behinds", "behinds"], ["score_involvements", "score involvements"],
	["goal_assists", "goal assists"], ["contested_marks", "contested marks"],
	["dont_argues", "don't argues"], ["evaded_tackles", "evaded tackles"], ["intercepts", "intercepts"],
	["cba", "centre ball-up attendances"], ["inside50", "inside 50s"], ["rebounds", "rebound 50s"],
	["one_percenters", "one percenters"], ["spoils", "spoils"], ["hitouts", "hit-outs"], ["hitouts_adv", "hit-outs to advantage"],
	["clangers", "clangers"], ["frees_against", "frees against"],
]

var _res: Dictionary
var _me := 0
var _wide := false
var _side := 0
var _sort := "rating"
var _open := ""
var _tabs: HBoxContainer
var _rows: VBoxContainer


func setup(res: Dictionary, first_side: int, wide := false) -> PlayerStatsTable:
	_res = res
	_me = first_side
	_side = first_side
	_wide = wide
	name = "PlayerStats"
	add_theme_constant_override("separation", 4)
	_tabs = UiKit.hbox(2)
	add_child(_tabs)
	_rows = UiKit.vbox(0)
	add_child(_rows)
	_rebuild()
	return self


func _rebuild() -> void:
	UiKit.clear(_tabs)
	for side in [_me, 1 - _me]:
		var code := str(_res["home"] if side == 0 else _res["away"])
		var t := UiKit.tab(GameDB.club_name(code), side == _side)
		t.name = "StatsTab_%d" % side
		t.custom_minimum_size.y = 44
		t.pressed.connect(func():
			_side = side
			_open = ""
			_rebuild())
		_tabs.add_child(t)
	UiKit.clear(_rows)
	var head := UiKit.hbox(2)
	head.name = "StatsHeader"
	var who := UiKit.line("Player", UiKit.SMALL, UiKit.MUTED)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	for c in _columns():
		var key := str(c[0])
		var b := Button.new()
		b.name = "Sort_" + key
		b.text = str(c[1])
		b.flat = true
		b.custom_minimum_size = Vector2(int(c[2]), 44)
		b.add_theme_font_size_override("font_size", UiKit.SMALL)
		b.add_theme_color_override("font_color", UiKit.TEXT if key == _sort else UiKit.MUTED)
		b.tooltip_text = "Sort by %s" % str(NAMES.get(key, key))
		b.pressed.connect(func():
			_sort = key
			_rebuild())
		head.add_child(b)
	_rows.add_child(head)
	_rows.add_child(UiKit.rule())
	for p in _sorted():
		_rows.add_child(_row(p))
	var key_bits: PackedStringArray = []
	for c in _columns():
		if str(c[0]) != "rating":
			key_bits.append("%s %s" % [str(c[1]), str(NAMES.get(str(c[0]), ""))])
	var legend := UiKit.lbl("  ·  ".join(key_bits), UiKit.SMALL, UiKit.MUTED)
	legend.name = "StatsKey"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(UiKit.spacer(4))
	_rows.add_child(legend)


func _columns() -> Array:
	return WIDE_COLUMNS if _wide else COLUMNS


func _sorted() -> Array:
	var rows := MatchNotes.rated_players(_res, _side)
	if _sort != "rating":
		rows.sort_custom(func(a, b):
			var x := float((a["stats"] as Dictionary).get(_sort, 0.0))
			var y := float((b["stats"] as Dictionary).get(_sort, 0.0))
			if x != y:
				return x > y
			return float(a["rating"]) > float(b["rating"]))
	return rows


func _row(p: Dictionary) -> Control:
	var v := UiKit.vbox(0)
	var id := str(p["id"])
	var b := Button.new()
	b.name = "PlayerRow_" + id
	b.flat = true
	b.custom_minimum_size.y = 34 if _wide else 40
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func():
		_open = "" if _open == id else id
		_rebuild())
	v.add_child(b)
	var h := UiKit.hbox(2)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var st: Dictionary = p["stats"]
	var who := UiKit.ellipsis("%d  %s" % [int(p["num"]), str(p["name"])], UiKit.SMALL, UiKit.TEXT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	for c in _columns():
		var key := str(c[0])
		var text := MatchNotes.rating_text(float(p["rating"])) if key == "rating" \
				else str(int(float(st.get(key, 0.0))))
		var cell := UiKit.line(text, UiKit.BODY if key == "rating" else UiKit.SMALL,
				UiKit.TEXT, key == "rating")
		cell.custom_minimum_size.x = int(c[2])
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(cell)
	for n in h.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _open == id:
		var bits: PackedStringArray = []
		for d in DETAIL:
			var key := str(d[0])
			if key == "distance_run":
				var metres := float(st.get(key, 0.0))
				if metres > 0.0:
					bits.append("%.1f km %s" % [metres / 1000.0, str(d[1])])
				continue
			var n := int(round(float(st.get(key, 0.0))))
			if n > 0:
				bits.append("%d %s" % [n, str(d[1])])
			if key == "handballs" and st.has("effective_disposals") \
					and float(st.get("disposals", 0.0)) > 0.0:
				bits.append("%d%% disposal efficiency" % MatchSim.disposal_efficiency(st))
		var more := UiKit.lbl(", ".join(bits) if not bits.is_empty() else "No other stats.",
				UiKit.SMALL, UiKit.MUTED)
		more.name = "PlayerDetail"
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(more)
		v.add_child(UiKit.spacer(4))
	return v
