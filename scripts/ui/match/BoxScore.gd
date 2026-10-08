class_name BoxScore
extends VBoxContainer
## The box score, one design for a played match wherever it opens: at the
## breaks, at full time and on Season stats > Fixture (director, 2026-10-08:
## not a table of text). Both scores; the worm - the margin across the match
## with each club's goals and behinds marked on the clock under it; a quarter
## or a goal tapped says what happened; the goalkickers and the best rated,
## each a tap from his line; and, where no team stats sit beside it, the key
## team numbers head to head. Reads a match result; changes nothing.

## Head to head: [stat key, label].
const BARS := [
	["disposals", "Disposals"], ["inside50", "Inside 50s"], ["clearances", "Clearances"],
	["marks", "Marks"], ["tackles", "Tackles"], ["hitouts", "Hit-outs"],
]
## A player's line when his row is opened: [stat key, words].
const LINE := [
	["disposals", "disposals"], ["kicks", "kicks"], ["handballs", "handballs"], ["marks", "marks"],
	["contested_possessions", "contested possessions"], ["tackles", "tackles"],
	["clearances", "clearances"], ["inside50", "inside 50s"], ["intercepts", "intercepts"],
	["goal_assists", "goal assists"], ["hitouts", "hit-outs"], ["dont_argues", "don't argues"],
	["evaded_tackles", "evaded tackles"],
]
const MOST_INVOLVED := 3
const KICKERS := 6

var _res: Dictionary
var _live := false
var _bars := false
var _codes := ["", ""]
var _scores: Array = []       # [{q, min, side, goal, id, name, set}] in match order
var _periods := 4
var _pick := {}               # {"q": n} or {"i": event index}; empty = nothing picked
var _open := ""               # the player whose line is open
var _worm: Control
var _says: Label
var _players: VBoxContainer


## `live`: at a break, the quarters played so far. `bars`: the team numbers
## head to head, for a sheet with no team stats of its own.
func setup(res: Dictionary, live := false, bars := false) -> BoxScore:
	_res = res
	_live = live
	_bars = bars
	name = "BoxScore"
	add_theme_constant_override("separation", UiKit.GAP)
	_codes = [str(res.get("home", "")), str(res.get("away", ""))]
	_scores = scoring(res)
	var qg: Array = res.get("q_goals", [])
	_periods = qg.size() if not live else mini(qg.size(), maxi(1, (res.get("quarter_teams", []) as Array).size()))
	if is_inside_tree():
		_build()
	return self


func _ready() -> void:
	if not _res.is_empty() and get_child_count() == 0:
		_build()


## Every goal and behind in the order kicked, from the match's own record:
## the result's compact scoring log (kept in a saved season), else its
## events (a match just played). [] when neither was kept.
static func scoring(res: Dictionary) -> Array:
	var out := []
	var names := {}
	for side_roster in res.get("roster", []):
		for p in side_roster:
			names[str(p.get("id", ""))] = str(p.get("name", ""))
	if res.has("scoring"):
		for s in res["scoring"]:
			var id := str(s[4])
			out.append({"q": int(s[0]), "min": int(s[1]), "side": int(s[2]), "goal": int(s[3]) == 1,
					"id": id, "name": GameDB.player_display_name_by_id(id, str(names.get(id, "Player"))),
					"set": int(s[5]) == 1})
		return out
	for e in res.get("events", []):
		var kind := str(e.get("kind", ""))
		if kind != "goal" and kind != "behind":
			continue
		out.append({"q": int(e.get("q", 1)), "min": int(e.get("min", 0)), "side": int(e.get("side", 0)),
				"goal": kind == "goal", "id": str(e.get("player_id", "")), "name": str(e.get("name", "")),
				"set": bool(e.get("setshot", false))})
	return out


func _build() -> void:
	UiKit.clear(self)
	add_child(_header())
	_worm = Worm.new()
	_worm.name = "Worm"
	_worm.call("setup", self)
	add_child(_worm)
	add_child(_quarter_strip())
	_says = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	_says.name = "WormSays"
	_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_says)
	_say()
	_players = UiKit.vbox(0)
	_players.name = "BoxPlayers"
	add_child(_players)
	_fill_players()
	if _bars:
		var team: Array = _res.get("team", [])
		if team.size() == 2 and not (team[0] as Dictionary).is_empty():
			add_child(UiKit.section("Head to head"))
			add_child(_head_to_head(team))


func _header() -> Control:
	var v := UiKit.vbox(2)
	v.name = "BoxHeader"
	for side in [0, 1]:
		var h := UiKit.hbox(8)
		h.name = "BoxHeader_%d" % side
		h.add_child(UiKit.club_badge(_codes[side], UiKit.NAME, false, true))
		var fig := UiKit.figure(UiKit.scoreline(int(_res["goals"][side]), int(_res["behinds"][side])),
				UiKit.SCORE, UiKit.score_colour(_codes[side]))
		fig.size_flags_horizontal = Control.SIZE_SHRINK_END
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(fig)
		v.add_child(h)
	return v


## The quarter-by-quarter scoreboard, the AFL way: each club's goals and
## behinds at every break, running. Each quarter's column is one button;
## tapping it says that quarter's scores and goalkickers, again clears it.
func _quarter_strip() -> Control:
	var h := UiKit.hbox(4)
	h.name = "QuarterStrip"
	var marks := UiKit.vbox(0)
	marks.add_child(_strip_cell("", false, UiKit.MUTED))
	for side in [0, 1]:
		var m := CenterContainer.new()
		m.custom_minimum_size = Vector2(28, CELL_H)
		m.add_child(UiKit.club_marker(_codes[side], 18.0))
		marks.add_child(m)
	h.add_child(marks)
	var g := [0, 0]
	var bh := [0, 0]
	var qg: Array = _res.get("q_goals", [])
	var qb: Array = _res.get("q_behinds", [])
	for i in range(_periods):
		for side in [0, 1]:
			g[side] += int(qg[i][side])
			bh[side] += int(qb[i][side])
		var pts := [int(g[0]) * 6 + int(bh[0]), int(g[1]) * 6 + int(bh[1])]
		var b := Button.new()
		b.name = "BoxQuarter_%d" % (i + 1)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = CELL_H * 3.0 + 8.0
		UiKit.set_selected(b, int(_pick.get("q", 0)) == i + 1)
		var col := UiKit.vbox(0)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_strip_cell(_period(i), false, UiKit.MUTED))
		for side in [0, 1]:
			# The side ahead at the break in weight, as a scoreboard would.
			col.add_child(_strip_cell("%d.%d" % [int(g[side]), int(bh[side])],
					int(pts[side]) > int(pts[1 - side]), UiKit.TEXT))
		b.add_child(col)
		var q := i + 1
		b.pressed.connect(func(): pick_quarter(q))
		h.add_child(b)
	return h


const CELL_H := 22.0


func _strip_cell(text: String, bold: bool, colour: Color) -> Label:
	var l := UiKit.line(text, UiKit.BODY if text.contains(".") else UiKit.SMALL, colour, bold)
	l.custom_minimum_size.y = CELL_H
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func pick_quarter(q: int) -> void:
	_pick = {} if int(_pick.get("q", 0)) == q else {"q": q}
	_refresh()


func pick_score(i: int) -> void:
	_pick = {} if int(_pick.get("i", -1)) == i else {"i": i}
	_refresh()


func _refresh() -> void:
	var strip := find_child("QuarterStrip", false, false)
	if strip != null:
		for b in strip.get_children():
			if b is Button:
				UiKit.set_selected(b, str(b.name) == "BoxQuarter_%d" % int(_pick.get("q", 0)))
	_worm.queue_redraw()
	_say()


## What the pick says, in a commentator's words.
func _say() -> void:
	if _pick.has("i"):
		var s: Dictionary = _scores[int(_pick["i"])]
		var run := _running(int(_pick["i"]))
		var lead := int(run[0]) - int(run[1])
		var where := "Scores level" if lead == 0 \
				else "%s lead by %d" % [GameDB.club_short(_codes[0 if lead > 0 else 1]), absi(lead)]
		_says.text = "%s, %s: %s %s%s. %s." % [_period(int(s["q"]) - 1), _minute_words(s),
				str(s["name"]), "goal" if bool(s["goal"]) else "behind",
				" from a set shot" if bool(s["set"]) else "", where]
		_says.add_theme_color_override("font_color", UiKit.TEXT)
	elif _pick.has("q"):
		var q := int(_pick["q"])
		var qg: Array = _res["q_goals"]
		var qb: Array = _res["q_behinds"]
		var bits: PackedStringArray = []
		for side in [0, 1]:
			bits.append("%s %d.%d" % [GameDB.club_short(_codes[side]), int(qg[q - 1][side]), int(qb[q - 1][side])])
		var kick := {}
		for s in _scores:
			if int(s["q"]) == q and bool(s["goal"]):
				kick[str(s["name"])] = int(kick.get(str(s["name"]), 0)) + 1
		var who: PackedStringArray = []
		for n in kick:
			who.append(n if int(kick[n]) == 1 else "%s %d" % [n, int(kick[n])])
		_says.text = "%s: %s. %s" % [_period(q - 1), ", ".join(bits),
				("Goals: %s." % ", ".join(who)) if not who.is_empty() else "No goals."]
		_says.add_theme_color_override("font_color", UiKit.TEXT)
	else:
		_says.text = "Tap a quarter, or a goal under the worm." if not _scores.is_empty() else ""
		_says.add_theme_color_override("font_color", UiKit.MUTED)


func _minute_words(s: Dictionary) -> String:
	var into := int(s["min"]) - (int(s["q"]) - 1) * 30
	return "%d minutes in" % maxi(1, into) if int(s["q"]) <= 4 else "extra time"


## The score after the `i`th scoring shot.
func _running(i: int) -> Array:
	var run := [0, 0]
	for j in range(i + 1):
		var s: Dictionary = _scores[j]
		run[int(s["side"])] += 6 if bool(s["goal"]) else 1
	return run


func _period(i: int) -> String:
	return "ET" if i >= 4 else "Q%d" % (i + 1)


# ---------------------------------------------------------------------------
# Players: the goalkickers, then the best rated; a tap opens his line
# ---------------------------------------------------------------------------
func _fill_players() -> void:
	UiKit.clear(_players)
	var players: Dictionary = _res.get("players", {})
	if players.is_empty():
		return
	for side in [0, 1]:
		var rows := []
		for p in (_res.get("roster", [[], []]) as Array)[side]:
			var id := str(p.get("id", ""))
			var st: Dictionary = players.get(id, {})
			if st.is_empty():
				continue
			rows.append({"id": id, "name": GameDB.player_display_name_by_id(id, str(p.get("name", "Player"))),
					"st": st, "goals": int(st.get("goals", 0.0)), "behinds": int(st.get("behinds", 0.0))})
		_players.add_child(UiKit.spacer(UiKit.GAP))
		var head := UiKit.club_badge(_codes[side], UiKit.SMALL, false, false)
		head.alignment = BoxContainer.ALIGNMENT_BEGIN
		_players.add_child(head)
		var kickers := rows.filter(func(r): return int(r["goals"]) > 0)
		kickers.sort_custom(func(a, b):
			if int(a["goals"]) != int(b["goals"]):
				return int(a["goals"]) > int(b["goals"])
			return int(a["behinds"]) < int(b["behinds"]))
		var shown := {}
		for r in kickers.slice(0, KICKERS):
			_players.add_child(_player_row(r, "%d.%d" % [int(r["goals"]), int(r["behinds"])]))
			shown[str(r["id"])] = true
		if kickers.is_empty():
			_players.add_child(UiKit.lbl("No goalkickers.", UiKit.SMALL, UiKit.MUTED))
		# The best of the rest by match rating (director, 2026-10-08), the
		# same figure as the player stats' Rating column.
		var best := 0
		for rp in MatchNotes.rated_players(_res, side):
			if best >= MOST_INVOLVED:
				break
			if shown.has(str(rp["id"])) or (rp["stats"] as Dictionary).is_empty():
				continue
			_players.add_child(_player_row({"id": rp["id"], "name": rp["name"], "st": rp["stats"]},
					"Rating %s" % MatchNotes.rating_text(rp["rating"])))
			best += 1


## A flat row: his name, and what he did that matters most here. A tap opens
## the rest of his match.
func _player_row(r: Dictionary, figure: String) -> Control:
	var v := UiKit.vbox(0)
	var id := str(r["id"])
	var b := Button.new()
	b.name = "BoxPlayer_" + id
	b.flat = true
	b.custom_minimum_size.y = 44
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func():
		_open = "" if _open == id else id
		_fill_players())
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	var who := UiKit.ellipsis(str(r["name"]), UiKit.BODY, UiKit.TEXT, _open == id)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	var fig := UiKit.line(figure, UiKit.BODY, UiKit.TEXT, true)
	fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(fig)
	for n in [h, who, fig]:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	v.add_child(b)
	if _open == id:
		var st: Dictionary = r["st"]
		var bits: PackedStringArray = []
		for d in LINE:
			var n := int(round(float(st.get(str(d[0]), 0.0))))
			if n > 0:
				bits.append("%d %s" % [n, _one(str(d[1])) if n == 1 else str(d[1])])
		var l := UiKit.lbl(", ".join(bits) + "." if not bits.is_empty() else "Quiet.", UiKit.SMALL, UiKit.MUTED)
		l.name = "BoxPlayerLine_" + id
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		v.add_child(UiKit.spacer(4))
	return v


## "disposals" -> "disposal", "inside 50s" -> "inside 50", "don't argues" ->
## "don't argue".
static func _one(words: String) -> String:
	return words.trim_suffix("s") if words.ends_with("s") else words


# ---------------------------------------------------------------------------
# Head to head
# ---------------------------------------------------------------------------
func _head_to_head(team: Array) -> Control:
	var v := UiKit.vbox(6)
	v.name = "HeadToHead"
	for row in BARS:
		var key := str(row[0])
		if not (team[0] as Dictionary).has(key):
			continue
		var a := int(round(float(team[0].get(key, 0.0))))
		var b := int(round(float(team[1].get(key, 0.0))))
		var box := UiKit.vbox(2)
		box.name = "H2H_" + key
		var h := UiKit.hbox(8)
		var la := UiKit.line(str(a), UiKit.BODY, UiKit.TEXT, a > b)
		la.custom_minimum_size.x = 44
		h.add_child(la)
		var mid := UiKit.line(str(row[1]), UiKit.SMALL, UiKit.MUTED)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(mid)
		var lb := UiKit.line(str(b), UiKit.BODY, UiKit.TEXT, b > a)
		lb.custom_minimum_size.x = 44
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(lb)
		box.add_child(h)
		var bar := Split.new()
		bar.call("setup", float(a), float(b), UiKit.score_colour(_codes[0]), UiKit.score_colour(_codes[1]))
		box.add_child(bar)
		v.add_child(box)
	return v


## Each club's share of a stat, one flat line split where they meet.
class Split extends Control:
	var _a := 0.0
	var _b := 0.0
	var _ca := Color.WHITE
	var _cb := Color.WHITE

	func setup(a: float, b: float, ca: Color, cb: Color) -> void:
		_a = a
		_b = b
		_ca = ca
		_cb = cb
		custom_minimum_size.y = 4
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var total := _a + _b
		var w := size.x
		var split := w * (_a / total if total > 0.0 else 0.5)
		draw_rect(Rect2(0, 0, maxf(0.0, split - 1.0), size.y), _ca)
		draw_rect(Rect2(split + 1.0, 0, maxf(0.0, w - split - 1.0), size.y), _cb)


# ---------------------------------------------------------------------------
# The worm
# ---------------------------------------------------------------------------
## The margin across the match (home above the line, away below), the
## quarter breaks, and under it each club's goals (ticks) and behinds (dots)
## on the same clock. A tap on a mark picks that score; anywhere else on the
## chart picks the quarter.
class Worm extends Control:
	const CHART_H := 112.0
	const LANE_H := 18.0
	const PAD := 6.0
	const QUARTER := 30.0
	var _box: BoxScore

	func setup(box: BoxScore) -> void:
		_box = box
		custom_minimum_size = Vector2(0, CHART_H + 2.0 * LANE_H + PAD * 2.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _span() -> float:
		var last := float(_box._periods) * QUARTER
		for s in _box._scores:
			last = maxf(last, float(s["min"]))
		return maxf(QUARTER, last)

	func _x(minute: float) -> float:
		return PAD + (size.x - 2.0 * PAD) * clampf(minute / _span(), 0.0, 1.0)

	func _reach() -> float:
		var most := 12.0
		var run := [0, 0]
		for s in _box._scores:
			run[int(s["side"])] += 6 if bool(s["goal"]) else 1
			most = maxf(most, absf(float(run[0] - run[1])))
		return most * 1.15

	func _y(margin: float) -> float:
		var mid := PAD + CHART_H / 2.0
		return mid - (CHART_H / 2.0 - 4.0) * clampf(margin / _reach(), -1.0, 1.0)

	func _lane_y(side: int) -> float:
		return PAD + CHART_H + LANE_H * (float(side) + 0.5)

	func _draw() -> void:
		var top := PAD
		var bottom := PAD + CHART_H
		var q_pick := int(_box._pick.get("q", 0))
		var periods := maxi(1, int(ceil(_span() / QUARTER)))
		if q_pick > 0:
			var x0 := _x(float(q_pick - 1) * QUARTER)
			var x1 := _x(float(q_pick) * QUARTER)
			draw_rect(Rect2(x0, top, x1 - x0, CHART_H + 2.0 * LANE_H), UiKit.PANEL_ALT)
		for i in range(1, periods):
			var x := _x(float(i) * QUARTER)
			draw_line(Vector2(x, top), Vector2(x, bottom + 2.0 * LANE_H), UiKit.LINE, 1.0)
		var mid := _y(0.0)
		draw_line(Vector2(PAD, mid), Vector2(size.x - PAD, mid), UiKit.LINE, 1.0)
		for side in [0, 1]:
			draw_line(Vector2(PAD, _lane_y(side) + LANE_H / 2.0), Vector2(size.x - PAD, _lane_y(side) + LANE_H / 2.0),
					Color(UiKit.LINE, 0.5), 1.0)
		# The margin, scoring shot by scoring shot, coloured by who leads.
		var col := [UiKit.score_colour(_box._codes[0]), UiKit.score_colour(_box._codes[1])]
		var prev := Vector2(_x(0.0), mid)
		var margin := 0
		for s in _box._scores:
			var at := Vector2(_x(float(s["min"])), _y(float(margin)))
			_seg(prev, at, margin, col)
			margin += (6 if bool(s["goal"]) else 1) * (1 if int(s["side"]) == 0 else -1)
			var to := Vector2(at.x, _y(float(margin)))
			_seg(at, to, margin, col)
			prev = to
		_seg(prev, Vector2(_x(_span()), prev.y), margin, col)
		# The marks: goals as ticks, behinds as dots, the picked one ringed.
		var pick := int(_box._pick.get("i", -1))
		for i in range(_box._scores.size()):
			var s: Dictionary = _box._scores[i]
			var side := int(s["side"])
			var c: Color = col[side]
			var p := Vector2(_x(float(s["min"])), _lane_y(side))
			if bool(s["goal"]):
				draw_line(p - Vector2(0, 6), p + Vector2(0, 6), c, 3.0)
			else:
				draw_circle(p, 2.0, Color(c, 0.75))
			if i == pick:
				draw_arc(p, 9.0, 0.0, TAU, 24, UiKit.TEXT, 1.5)
				draw_line(Vector2(p.x, top), Vector2(p.x, bottom), Color(UiKit.TEXT, 0.35), 1.0)

	func _seg(a: Vector2, b: Vector2, margin: int, col: Array) -> void:
		var c: Color = UiKit.MUTED if margin == 0 else (col[0] if margin > 0 else col[1])
		draw_line(a, b, c, 2.0, true)

	func _gui_input(event: InputEvent) -> void:
		var at := Vector2.ZERO
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			at = event.position
		elif event is InputEventScreenTouch and event.pressed:
			at = event.position
		else:
			return
		accept_event()
		# Near the lanes, the closest mark on that side (a fingertip wide).
		if at.y >= PAD + CHART_H - 4.0:
			var side := 0 if at.y < PAD + CHART_H + LANE_H else 1
			var best := -1
			var best_d := 22.0
			for i in range(_box._scores.size()):
				var s: Dictionary = _box._scores[i]
				if int(s["side"]) != side:
					continue
				var d := absf(_x(float(s["min"])) - at.x)
				if d < best_d:
					best_d = d
					best = i
			if best >= 0:
				_box.pick_score(best)
				return
		var q := clampi(int((at.x - PAD) / maxf(1.0, size.x - 2.0 * PAD) * _span() / QUARTER) + 1, 1, _box._periods)
		_box.pick_quarter(q)
