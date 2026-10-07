class_name StatsLadder
extends RefCounted
## Season stats > Ladder: the full ladder in its true order (Season.ladder_sorted,
## the real tiebreaks), a second view of each club's per-game team numbers, a
## tap on a header to sort and a few simple filters. Tap a club for its side on
## the field view, read-only. The sort, the filter and the view are kept for
## the visit back from a club's side (STATS patch, ROADMAP §1.11).

## Rows are 32 px on a wide screen, 40 px (thumb-sized) on a narrow one, with no
## rules between them; every other row has a very faint
## band (PANEL, flat). Numbers and their headers are right-aligned.
const ROW_H := 32
const ROW_H_NARROW := 40
const COL_GAP := 4

## The ladder's columns, phone first; a wide screen adds the rest.
## {key, title, w}; on a phone the club column takes what is left (0). On a
## wide screen the table is as wide as its columns and sits at the left, the
## club right beside its numbers (WIDE_CLUB).
const WIDE_CLUB := 190
const LADDER_PHONE := [["pos", "#", 24], ["club", "Club", 0], ["p", "P", 26], ["w", "W", 26],
		["l", "L", 26], ["d", "D", 24], ["pct", "%", 42], ["pts", "Pts", 34]]
const LADDER_WIDE := [["pos", "#", 28], ["club", "Club", WIDE_CLUB], ["p", "P", 32], ["w", "W", 32],
		["l", "L", 32], ["d", "D", 30], ["pf", "PF", 50], ["pa", "PA", 50], ["pct", "%", 50],
		["pts", "Pts", 40], ["home", "Home", 68], ["away", "Away", 68], ["form", "Form", 76]]
## Team stats: a per-game value for each, from GameState.season_team (only
## what is recorded there). One list, so a newly recorded stat joins with one
## line: {season_team key, column title, width on a phone, width on a wide
## screen, on a phone}.
const TEAM_STATS := [
	["for", "PF", 32, 52, true], ["against", "PA", 32, 52, true],
	["disposals", "D", 32, 52, true], ["marks", "MK", 32, 52, true],
	["tackles", "TK", 32, 52, true], ["inside50", "I50", 32, 52, true],
	["clearances", "CL", 32, 52, true], ["hitouts", "HO", 32, 52, true],
	["rebounds", "R50", 32, 52, false], ["clangers", "CG", 32, 52, false],
	["metres_gained", "MG", 32, 60, false],
]
## Metres gained reads well rounded; every other figure is one decimal.
const WHOLE_STATS := ["metres_gained"]

const FILTERS := [["all", "All"], ["top8", "Top 8"], ["near", "Near you"]]
const VIEWS := [["ladder", "Ladder"], ["team", "Team stats"]]

## Kept across a rebuild and a visit to a club's side. "" sorts nothing: the
## true ladder order.
static var _view := "ladder"
static var _sort := ""
static var _desc := true
static var _filter := "all"


static func reset() -> void:
	_view = "ladder"
	_sort = ""
	_desc = true
	_filter = "all"


static func build(host: Control) -> Control:
	var season: Season = GameState.season
	var v := UiKit.vbox(10)
	v.name = "StatsLadder"
	var info := "Home and away complete" if season.is_regular_done() \
			else "After %d of %d rounds" % [season.round_index, Season.REGULAR_ROUNDS]
	v.add_child(UiKit.subtitle(info))
	var wide := bool(host.call("wide"))
	var width := float(host.call("content_width"))

	# The view, then the filters.
	var views := UiKit.hbox(6)
	views.name = "Views"
	for o in VIEWS:
		var key := str(o[0])
		var b := UiKit.btn(str(o[1]), UiKit.BODY)
		b.name = "View_" + key
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 44
		UiKit.set_selected(b, key == _view)
		b.pressed.connect(func():
			_view = key
			_sort = ""
			host.call("refresh"))
		views.add_child(b)
	var filters := UiKit.hbox(6)
	filters.name = "Filters"
	for o in FILTERS:
		var key := str(o[0])
		var b := UiKit.btn(str(o[1]), UiKit.BODY)
		b.name = "Filter_" + key
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 44
		UiKit.set_selected(b, key == _filter)
		b.pressed.connect(func():
			_filter = key
			host.call("refresh"))
		filters.add_child(b)
	if wide:
		# One compact row on a wide screen, not two bars across the window.
		for group in [views, filters]:
			for b in group.get_children():
				b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				b.custom_minimum_size.x = 120
		var both := UiKit.hbox(28)
		both.name = "Controls"
		both.add_child(views)
		both.add_child(filters)
		v.add_child(both)
	else:
		v.add_child(views)
		v.add_child(filters)

	var shown := visible_rows(season, GameState.my_club, _filter, _sort, _desc, _view)
	v.add_child(_status(host, shown.size()))

	# No panel around it: the bands do the work.
	var t := UiKit.vbox(0)
	t.name = "LadderTable"
	v.add_child(t)
	var specs := columns(_view, wide)
	if wide:
		# As wide as its columns, left-aligned: no gap between a club and its numbers.
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.add_child(_header(host, specs, width))
	var band := false
	for r in shown:
		t.add_child(_row(host, r, specs, width, band, ROW_H if wide else ROW_H_NARROW))
		band = not band
		# The cut for the finals, as the ladder has always drawn it.
		if _sort == "" and _filter == "all" and int(r["pos"]) == Season.FINALISTS 				and int(r["pos"]) < season.ladder.size():
			t.add_child(UiKit.rule())
	if shown.is_empty():
		t.add_child(UiKit.lbl("No clubs to show.", UiKit.BODY, UiKit.MUTED))
	return v


static func columns(view: String, wide: bool) -> Array:
	if view == "team":
		var out := [["club", "Club", WIDE_CLUB if wide else 0]]
		for c in TEAM_STATS:
			if wide or bool(c[4]):
				out.append([c[0], c[1], c[3] if wide else c[2]])
		return out
	return LADDER_WIDE if wide else LADDER_PHONE


## One line that says what is on show, with the way back to the plain ladder.
static func _status(host: Control, count: int) -> Control:
	var h := UiKit.hbox(8)
	h.name = "LadderStatus"
	var bits := PackedStringArray()
	for o in FILTERS:
		if str(o[0]) == _filter and _filter != "all":
			bits.append(str(o[1]))
	if _sort != "":
		bits.append("sorted by %s, %s first" % [_title_of(_sort), "most" if _desc else "fewest"])
	var text := "Showing " + (", ".join(bits) if not bits.is_empty() else "all %d clubs" % count)
	var l := UiKit.lbl(text, UiKit.SMALL, UiKit.MUTED)
	l.name = "ActiveState"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if _sort != "":
		var order := UiKit.btn("Ladder order", UiKit.SMALL)
		order.name = "LadderOrder"
		order.pressed.connect(func():
			_sort = ""
			host.call("refresh"))
		h.add_child(order)
	if _sort != "" or _filter != "all":
		var rs := UiKit.btn("Reset", UiKit.SMALL)
		rs.name = "ResetLadder"
		rs.pressed.connect(func():
			_sort = ""
			_desc = true
			_filter = "all"
			host.call("refresh"))
		h.add_child(rs)
	return h


static func _title_of(key: String) -> String:
	for set in [LADDER_WIDE, TEAM_STATS]:
		for c in set:
			if str(c[0]) == key:
				return str(c[1])
	return key


static func _header(host: Control, specs: Array, width: float) -> Control:
	var h := UiKit.hbox(COL_GAP)
	h.name = "LadderHeader"
	for c in specs:
		var key := str(c[0])
		if key == "form":
			h.add_child(_plain(str(c[1]), int(c[2]), UiKit.MUTED))
			continue
		var b := Button.new()
		b.name = "Sort_" + key
		b.text = str(c[1])
		b.flat = true
		b.clip_text = true
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", UiKit.BOLD if key == _sort else UiKit.FONT)
		b.add_theme_font_size_override("font_size", 12)
		var on: bool = key == _sort
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(col, UiKit.TEXT if on else UiKit.MUTED)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.border_width_bottom = 2 if on else 0
		sb.border_color = UiKit.TEXT
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		b.custom_minimum_size = Vector2(int(c[2]), 40)
		if int(c[2]) == 0:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if key == "club" else HORIZONTAL_ALIGNMENT_RIGHT
		b.pressed.connect(func(): _sort_by(host, key))
		h.add_child(b)
	return h


static func _plain(text: String, w: int, col: Color) -> Label:
	var l := UiKit.line(text, 12, col)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## Tap a header: that column, biggest first (names A to Z); tap it again to
## reverse. The position column is the way back to the true order.
static func _sort_by(host: Control, key: String) -> void:
	if key == "pos":
		_sort = ""
		_desc = true
	elif key == _sort:
		_desc = not _desc
	else:
		_sort = key
		_desc = key != "club"
	host.call("refresh")


## One club as a tappable row.
static func _row(host: Control, r: Dictionary, specs: Array, width: float, band := false, height := ROW_H) -> Control:
	var code := str(r["code"])
	var mine: bool = code == GameState.my_club
	var b := Button.new()
	b.name = "Club_" + code
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# A button does not take its child row's width: a table of fixed columns says so.
	var fixed := 0
	var all_fixed := true
	for c in specs:
		if int(c[2]) == 0:
			all_fixed = false
		fixed += int(c[2]) + COL_GAP
	b.custom_minimum_size = Vector2(fixed if all_fixed else 0, height)
	b.clip_contents = true
	var flat := StyleBoxFlat.new()
	flat.bg_color = UiKit.PANEL if band else Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiKit.TEXT, 0.05)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, flat)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	var row := UiKit.hbox(COL_GAP)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in specs:
		var key := str(c[0])
		var w := int(c[2])
		if key == "club":
			var badge := UiKit.club_badge(code, 13, width < 460.0, true)
			if w > 0:
				badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				badge.alignment = BoxContainer.ALIGNMENT_BEGIN
				badge.custom_minimum_size.x = w
			if mine:
				_bold(badge)
			row.add_child(badge)
			continue
		var text := cell_text(r, key)
		# The position is muted, so is a zero; the rest is plain text.
		var ink := UiKit.MUTED if key == "pos" or _is_zero(text) else UiKit.TEXT
		var l := UiKit.line(text, 13 if key == "pts" or key == "pos" else 12, ink, mine or key == "pts")
		l.custom_minimum_size = Vector2(w, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	_ignore(row)
	b.pressed.connect(func(): _side_sheet(host, code))
	return b


## "0", "0.0": nothing to read.
static func _is_zero(text: String) -> bool:
	return text.is_valid_float() and float(text) == 0.0


static func _bold(n: Node) -> void:
	if n is Label:
		(n as Label).add_theme_font_override("font", UiKit.BOLD)
	for c in n.get_children():
		_bold(c)


static func _ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore(c)


# ---------------------------------------------------------------------------
# The numbers
# ---------------------------------------------------------------------------
## Every club in the true ladder order, with what the table shows: the
## ladder's own columns, a home and an away record, the last five results, and
## each team stat per game (games are the denominator; no games, no number).
static func rows(season: Season) -> Array:
	var out := []
	var home := {}
	var away := {}
	for rnd in season.results:
		for res in rnd:
			var s: Array = res["score"]
			_tally(home, str(res["home"]), int(s[0]) - int(s[1]))
			_tally(away, str(res["away"]), int(s[1]) - int(s[0]))
	var sorted: Array = season.ladder_sorted()
	for i in range(sorted.size()):
		var l: Dictionary = sorted[i]
		var code := str(l["code"])
		var row := {"pos": i + 1, "code": code, "p": int(l["p"]), "w": int(l["w"]), "l": int(l["l"]),
				"d": int(l["d"]), "pf": int(l["pf"]), "pa": int(l["pa"]), "pct": float(l["pct"]),
				"pts": int(l["pts"]), "home": home.get(code, [0, 0, 0]), "away": away.get(code, [0, 0, 0]),
				"form": "".join(PackedStringArray((season.club_results(code) as Array).slice(-5)))}
		var t: Dictionary = GameState.season_team.get(code, {})
		var games := int(t.get("games", 0))
		row["games"] = games
		for c in TEAM_STATS:
			var k := str(c[0])
			row["t_" + k] = (float(t.get(k, 0.0)) / float(games)) if games > 0 else -1.0
		out.append(row)
	return out


static func _tally(into: Dictionary, code: String, diff: int) -> void:
	var rec: Array = into.get(code, [0, 0, 0])
	if diff > 0:
		rec[0] += 1
	elif diff < 0:
		rec[1] += 1
	else:
		rec[2] += 1
	into[code] = rec


## What the table shows for one cell: the ladder's own columns as they are,
## a team stat per game.
static func cell_text(r: Dictionary, key: String) -> String:
	match key:
		"pos", "p", "w", "l", "d", "pf", "pa", "pts":
			return str(int(r[key]))
		"pct":
			return "%.0f" % float(r["pct"])
		"home", "away":
			var rec: Array = r[key]
			return "%d-%d" % [rec[0], rec[1]] + ("-%d" % rec[2] if int(rec[2]) > 0 else "")
		"form":
			return str(r["form"])
	return per_game_text(float(r.get("t_" + key, -1.0)), WHOLE_STATS.has(key))


## A per-game number: one decimal for every figure (106.0, 392.3 and 9.4 line
## up), whole for the few that read better rounded; "-" with no games to divide by.
static func per_game_text(x: float, whole := false) -> String:
	if x < 0.0:
		return "-"
	return "%.0f" % x if whole else "%.1f" % x


## The value a column sorts on.
static func sort_value(r: Dictionary, key: String) -> Variant:
	match key:
		"club":
			return GameDB.club_short(str(r["code"]))
		"home", "away":
			var rec: Array = r[key]
			return int(rec[0]) * 1000 + int(rec[2]) * 10 - int(rec[1])
		"pct":
			return float(r["pct"])
		"for", "against", "disposals", "marks", "tackles", "inside50", "clearances", "hitouts", \
		"rebounds", "clangers", "metres_gained":
			return float(r["t_" + key])
	return float(int(r.get(key, 0)))


## The clubs on show: filtered from the true ladder, then sorted ("" keeps
## the true order). Ties keep their ladder order.
static func visible_rows(season: Season, mine: String, filter: String, sort: String, desc: bool,
		view := "ladder") -> Array:
	var all := rows(season)
	var out := []
	var my_pos := 0
	for r in all:
		if str(r["code"]) == mine:
			my_pos = int(r["pos"])
	for r in all:
		var pos := int(r["pos"])
		match filter:
			"top8":
				if pos > 8:
					continue
			"near":
				if my_pos <= 0 or absi(pos - my_pos) > 2:
					continue
		out.append(r)
	if sort != "":
		var key := sort
		out.sort_custom(func(a, b):
			var x = sort_value(a, key)
			var y = sort_value(b, key)
			if x == y:
				return int(a["pos"]) < int(b["pos"])
			return (x > y) if desc else (x < y))
	return out


# ---------------------------------------------------------------------------
# A club's side
# ---------------------------------------------------------------------------
## The side as it would take the field, on the shared field view and read-only.
## A sheet over the ladder, so Back returns to it as it was; a player opens his
## profile over the side.
static func _side_sheet(host: Control, code: String) -> void:
	var season: Season = GameState.season
	var box := UiKit.modal_box(host, 900.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "ClubSide"
	host.call("open_sheet", overlay)
	var body: VBoxContainer = box["body"]
	body.add_child(UiKit.ellipsis(GameDB.club_name(code), UiKit.H2, UiKit.TEXT, true))
	var mine: bool = code == GameState.my_club
	var named: bool = mine or not (season.selections.get(code, {}) as Dictionary).is_empty()
	var note := "Your side as it stands" if mine else \
			("Side named for this round" if named else "Projected side: picked on match day")
	var n := UiKit.lbl(note, UiKit.SMALL, UiKit.MUTED)
	n.name = "SideNote"
	body.add_child(n)
	var builder := TeamBuilder.new()
	builder.name = "TeamBuilder"
	builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(builder)
	var their: Dictionary
	if mine:
		their = {"side": GameState.current_side(), "list": GameState.my_list}
	else:
		their = GameState.opponent_side(code)
	builder.setup(their["side"], bool(host.call("wide")), their["list"], true)
	builder.inspect.connect(func(id: String):
		for p in their["list"]:
			if str(p["id"]) == id:
				host.call("open_sheet", PlayerSheet.open(host, p, Callable(), []))
				return)
	var close := UiKit.btn("Close", UiKit.BODY)
	close.name = "CloseSide"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func(): host.call("close_sheet"))
	(box["footer"] as Control).add_child(close)
