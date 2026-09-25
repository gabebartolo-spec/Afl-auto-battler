class_name FormationView
extends Control
## Match-day shape for one club: the best 18 placed on an oval, interchange below.
##
## Positions follow the engine's 6-6-6 shape: 6 defenders, 6 midfielders
## (the ruck counted in midfield) and 6 forwards. The best player in each
## line takes the spine spot (full back, centre, ruck, full forward) so the
## shape reads at a glance. Tap a guernsey for the rating.

const ASPECT := 1.28
const GOAL_LINE_M := 85.0

## Assignment order is rating order. Draw positions are the `at` coordinates.
const SLOTS := [
	{"key": "FB", "role": "DEF", "abbr": "FB", "title": "Full back", "at": Vector2(-0.80, 0.00)},
	{"key": "BPL", "role": "DEF", "abbr": "BP", "title": "Back pocket", "at": Vector2(-0.62, -0.38)},
	{"key": "BPR", "role": "DEF", "abbr": "BP", "title": "Back pocket", "at": Vector2(-0.62, 0.38)},
	{"key": "HBFL", "role": "DEF", "abbr": "HBF", "title": "Half-back flank", "at": Vector2(-0.44, -0.72)},
	{"key": "HBFR", "role": "DEF", "abbr": "HBF", "title": "Half-back flank", "at": Vector2(-0.44, 0.72)},
	{"key": "CB", "role": "DEF", "abbr": "CB", "title": "Centre back", "at": Vector2(-0.30, 0.00)},
	{"key": "C", "role": "MID", "abbr": "C", "title": "Centre", "at": Vector2(-0.10, 0.00)},
	{"key": "IL", "role": "MID", "abbr": "IM", "title": "Inside mid", "at": Vector2(0.04, -0.40)},
	{"key": "IR", "role": "MID", "abbr": "IM", "title": "Inside mid", "at": Vector2(0.04, 0.40)},
	{"key": "WL", "role": "MID", "abbr": "W", "title": "Wing", "at": Vector2(0.10, -0.78)},
	{"key": "WR", "role": "MID", "abbr": "W", "title": "Wing", "at": Vector2(0.10, 0.78)},
	{"key": "RUCK", "role": "RUCK", "abbr": "RUC", "title": "Ruck", "at": Vector2(0.16, 0.00)},
	{"key": "HFF", "role": "FWD", "abbr": "HFF", "title": "Half forward", "at": Vector2(0.34, 0.00)},
	{"key": "HFFL", "role": "FWD", "abbr": "HFF", "title": "Half-forward flank", "at": Vector2(0.44, -0.70)},
	{"key": "HFFR", "role": "FWD", "abbr": "HFF", "title": "Half-forward flank", "at": Vector2(0.44, 0.70)},
	{"key": "FPL", "role": "FWD", "abbr": "FP", "title": "Forward pocket", "at": Vector2(0.62, -0.36)},
	{"key": "FPR", "role": "FWD", "abbr": "FP", "title": "Forward pocket", "at": Vector2(0.62, 0.36)},
	{"key": "FF", "role": "FWD", "abbr": "FF", "title": "Full forward", "at": Vector2(0.80, 0.00)},
]
const ASSIGN := {
	"DEF": ["FB", "HBFL", "HBFR", "BPL", "BPR", "CB"],
	"MID": ["C", "WL", "WR", "IL", "IR"],
	"FWD": ["FF", "HFFL", "HFFR", "FPL", "FPR", "HFF"],
	"RUCK": ["RUCK"],
}
const CALLOUT_ATTRS := {
	"DEF": [["intercept", "Intercept"], ["pressure", "Pressure"], ["disposal", "Disposal"]],
	"MID": [["disposal", "Disposal"], ["contested", "Contested"], ["carry", "Carry"]],
	"FWD": [["goalkicking", "Goalkicking"], ["marking", "Marking"], ["accuracy", "Accuracy"]],
	"RUCK": [["ruck", "Ruck"], ["contested", "Contested"], ["marking", "Marking"]],
}

var _ground: Array = []
var _bench: Array = []
var _club := ""
var _placed: Array = []
var _selected := -1
var _callout: PanelContainer
var _callout_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(180, 160)
	if not GameState.player_names_changed.is_connected(_on_names):
		GameState.player_names_changed.connect(_on_names)
	_ensure_callout()


func setup(ground: Array, bench: Array, club: String) -> void:
	_ground = ground
	_bench = bench
	_club = club
	_selected = -1
	_placed = _assign(ground, bench)
	_hide_callout()
	queue_redraw()


func _on_names() -> void:
	queue_redraw()
	if _selected >= 0:
		_show_callout(_selected)


func _assign(ground: Array, bench: Array) -> Array:
	var by_key := {}
	for slot in SLOTS:
		by_key[str(slot["key"])] = slot
	var buckets := {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
	var overflow: Array = []
	for p in ground:
		var role := str(p.get("role", "MID"))
		if buckets.has(role):
			buckets[role].append(p)
		else:
			overflow.append(p)
	for role in buckets:
		(buckets[role] as Array).sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var used := {}
	var out: Array = []
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		var keys: Array = ASSIGN[role]
		var players: Array = buckets[role]
		for i in range(mini(keys.size(), players.size())):
			var slot: Dictionary = by_key[str(keys[i])]
			used[str(slot["key"])] = true
			out.append({"player": players[i], "slot": slot, "bench": false})
		for i in range(keys.size(), players.size()):
			overflow.append(players[i])
	for slot in SLOTS:
		if used.has(str(slot["key"])) or overflow.is_empty():
			continue
		used[str(slot["key"])] = true
		out.append({"player": overflow.pop_front(), "slot": slot, "bench": false})
	for i in range(bench.size()):
		out.append({"player": bench[i], "slot": {"key": "INT%d" % i, "abbr": "INT",
				"title": "Interchange", "role": str(bench[i].get("role", "")), "at": Vector2.ZERO},
				"bench": true, "bench_index": i})
	return out


func _ensure_callout() -> void:
	if _callout != null:
		return
	_callout = UiKit.panel(UiKit.INK, 8, 8)
	_callout.visible = false
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.custom_minimum_size = Vector2(168, 0)
	add_child(_callout)
	_callout_box = UiKit.vbox(2)
	_callout.add_child(_callout_box)


func _hide_callout() -> void:
	_selected = -1
	if _callout != null:
		_callout.visible = false
	queue_redraw()


func _show_callout(index: int) -> void:
	_ensure_callout()
	if index < 0 or index >= _placed.size():
		_hide_callout()
		return
	_selected = index
	var entry: Dictionary = _placed[index]
	var p: Dictionary = entry["player"]
	var slot: Dictionary = entry["slot"]
	UiKit.clear(_callout_box)
	var title := "%s  %s" % [str(p.get("num", "")), _full_name(p)]
	_callout_box.add_child(UiKit.lbl(title, 14, UiKit.TEXT, true))
	var duty := str(slot.get("title", ""))
	if bool(entry.get("bench", false)):
		duty = "Interchange"
	_callout_box.add_child(UiKit.lbl("%s  ·  %d OVR  ·  %d XP" % [duty, int(p.get("overall", 0)),
			int(p.get("xp", 0))], 12, UiKit.GOLD, true))
	var role := str(slot.get("role", p.get("role", "MID")))
	var rows: Array = CALLOUT_ATTRS.get(role, CALLOUT_ATTRS["MID"])
	var attr: Dictionary = p.get("attr", {})
	var bits: PackedStringArray = []
	for row in rows:
		bits.append("%s %d" % [str(row[1]), int(attr.get(row[0], 0))])
	_callout_box.add_child(UiKit.lbl("  ·  ".join(bits), 11, UiKit.MUTED))
	_callout.visible = true
	_place_callout()
	queue_redraw()


func _place_callout() -> void:
	if _callout == null or _selected < 0:
		return
	var geo := _geometry()
	if _selected >= geo["tokens"].size():
		return
	var px: Vector2 = geo["tokens"][_selected]["px"]
	var w := 176.0
	var left := px.x > size.x * 0.58
	var x := px.x - w - 8.0 if left else px.x + 12.0
	var y := px.y - 36.0
	_callout.position = Vector2(clampf(x, 4.0, maxf(4.0, size.x - w - 4.0)),
			clampf(y, 4.0, maxf(4.0, size.y - 78.0)))
	_callout.size = Vector2(w, 0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit := _hit_index(mouse.position)
		if hit == _selected:
			_hide_callout()
		elif hit >= 0:
			_show_callout(hit)
		else:
			_hide_callout()
		accept_event()


func _hit_index(pos: Vector2) -> int:
	var geo := _geometry()
	var tokens: Array = geo["tokens"]
	var best := -1
	var best_d := 30.0
	var tr: float = geo["tr"]
	var reach := maxf(tr * 1.8, 24.0)
	for i in range(tokens.size()):
		var d: float = pos.distance_to(tokens[i]["px"])
		if d <= reach and d < best_d:
			best_d = d
			best = i
	return best


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_callout()
		queue_redraw()


func _geometry() -> Dictionary:
	var margin := 6.0
	var bench_h := clampf(size.y * 0.20, 54.0, 84.0)
	var avail := Rect2(margin, 4.0, maxf(8.0, size.x - margin * 2.0),
			maxf(8.0, size.y - bench_h - 8.0))
	var w := avail.size.x
	var h := w / ASPECT
	if h > avail.size.y:
		h = avail.size.y
		w = h * ASPECT
	var origin := avail.position + (avail.size - Vector2(w, h)) * 0.5
	var rect := Rect2(origin, Vector2(w, h))
	var centre := rect.get_center()
	var a := rect.size.x * 0.5
	var b := rect.size.y * 0.5
	var tr := clampf(minf(a, b) * 0.072, 8.0, 16.0)
	var tokens: Array = []
	var bench_count := 0
	for entry in _placed:
		if bool(entry.get("bench", false)):
			bench_count += 1
	var bench_rect := Rect2(margin, size.y - bench_h + 2.0, maxf(8.0, size.x - margin * 2.0), bench_h - 6.0)
	var bench_i := 0
	for i in range(_placed.size()):
		var entry: Dictionary = _placed[i]
		var px := Vector2.ZERO
		if bool(entry.get("bench", false)):
			var n := maxi(1, bench_count)
			var slot_w := bench_rect.size.x / float(n)
			px = Vector2(bench_rect.position.x + slot_w * (float(bench_i) + 0.5),
					bench_rect.position.y + bench_rect.size.y * 0.62)
			bench_i += 1
		else:
			var at: Vector2 = entry["slot"]["at"]
			px = centre + Vector2(at.x * a * 0.90, at.y * b * 0.86)
		tokens.append({"px": px, "index": i})
	return {
		"rect": rect, "c": centre, "a": a, "b": b, "tr": tr,
		"bench": bench_rect, "tokens": tokens,
		"labels": a >= 108.0,
	}


func _draw() -> void:
	var geo := _geometry()
	var rect: Rect2 = geo["rect"]
	if rect.size.x < 16.0 or rect.size.y < 16.0:
		return
	var c: Vector2 = geo["c"]
	var a: float = geo["a"]
	var b: float = geo["b"]
	var tr: float = geo["tr"]
	var colours: Array = GameDB.club_colours(_club)
	var primary: Color = colours[0]
	var secondary: Color = colours[1]

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.09, 0.047, 0.0), true)
	draw_colored_polygon(_ellipse_points(c, a, b, 96), Color(0.118, 0.333, 0.133))
	var stripes := 9
	for i in range(stripes):
		if i % 2 == 1:
			continue
		var x0 := c.x - a + (2.0 * a) * float(i) / float(stripes)
		var x1 := c.x - a + (2.0 * a) * float(i + 1) / float(stripes)
		draw_colored_polygon(_stripe(c, a, b, x0, x1), Color(0.133, 0.365, 0.149))
	draw_polyline(_ellipse_points(c, a, b, 96), Color(1, 1, 1, 0.85), 2.0)

	var line_col := Color(1, 1, 1, 0.5)
	var sq := (22.5 / GOAL_LINE_M) * a
	draw_rect(Rect2(c - Vector2(sq, sq), Vector2(sq, sq) * 2.0), line_col, false, 1.4)
	draw_arc(c, (3.0 / GOAL_LINE_M) * a, 0, TAU, 24, line_col, 1.4)
	for sgn in [-1.0, 1.0]:
		var goal := Vector2(c.x + sgn * a * 0.97, c.y)
		var rad := (50.0 / GOAL_LINE_M) * a
		var span := _arc_span(c, a, b, goal, rad)
		draw_arc(goal, rad, span.x, span.y, 40, line_col, 1.3)
		var depth := (9.0 / GOAL_LINE_M) * a
		var width := (6.44 / GOAL_LINE_M) * a
		var gx := goal.x - depth if sgn > 0.0 else goal.x
		draw_rect(Rect2(Vector2(gx, c.y - width * 0.5), Vector2(depth, width)), line_col, false, 1.3)
		for py in [-1.0, 1.0]:
			draw_circle(Vector2(goal.x, c.y + py * (3.22 / GOAL_LINE_M) * a),
					maxf(1.6, b * 0.012), Color(1, 1, 1, 0.9))
	# Attacking end is the right-hand goal. A chevron, not a word.
	var chev := Vector2(c.x + a * 0.93, c.y)
	draw_colored_polygon(PackedVector2Array([
		chev + Vector2(-8, -5), chev + Vector2(1, 0), chev + Vector2(-8, 5),
	]), Color(UiKit.GOLD, 0.9))

	var bench: Rect2 = geo["bench"]
	draw_rect(bench, Color(0.05, 0.08, 0.06, 0.72), true)
	draw_rect(bench, Color(1, 1, 1, 0.12), false, 1.0)
	_draw_label("INTERCHANGE", Vector2(bench.position.x + 8.0, bench.position.y + 14.0),
			10, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)

	var tokens: Array = geo["tokens"]
	var show_labels: bool = geo["labels"]
	for i in range(tokens.size()):
		var entry: Dictionary = _placed[i]
		var p: Dictionary = entry["player"]
		var slot: Dictionary = entry["slot"]
		var px: Vector2 = tokens[i]["px"]
		var selected := i == _selected
		if selected:
			draw_arc(px, tr * 1.85, 0, TAU, 24, UiKit.GOLD, 2.0)
		draw_circle(px + Vector2(0, tr * 0.18), tr, Color(0, 0, 0, 0.28))
		draw_circle(px, tr, primary)
		draw_circle(px, tr * 0.62, secondary)
		draw_arc(px, tr, 0, TAU, 20, Color(0, 0, 0, 0.4), 1.2)
		var num := str(int(p.get("num", 0)))
		var fs := int(clampf(tr * 0.95, 8.0, 14.0))
		var num_w := UiKit.BOLD.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UiKit.BOLD, px + Vector2(-num_w * 0.5, fs * 0.36), num,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _readable_on(primary))
		if show_labels:
			var abbr := str(slot.get("abbr", ""))
			_draw_label(abbr, px + Vector2(0, -tr - 3.0), 9, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			var name := _short_name(p)
			var below := float(slot.get("at", Vector2.ZERO).y) < 0.5 or bool(entry.get("bench", false))
			var name_y := px.y + tr + 12.0 if below else px.y - tr - 14.0
			_draw_label(name, Vector2(px.x, name_y), int(clampf(tr * 0.78, 8.0, 12.0)),
					UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_label(text: String, pos: Vector2, fs: int, col: Color, align: HorizontalAlignment) -> void:
	if text == "":
		return
	var width := UiKit.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= width * 0.5
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(UiKit.BOLD, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	draw_string(UiKit.BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _short_name(p: Dictionary) -> String:
	var raw := ""
	if GameState.show_real_names and str(p.get("last", "")) != "":
		raw = str(p["last"])
	else:
		var generic := str(p.get("generic_name", p.get("name", "Player")))
		var parts := generic.split(" ", false)
		raw = parts[parts.size() - 1] if not parts.is_empty() else "Player"
	if raw.length() > 10:
		raw = raw.substr(0, 9) + "."
	return raw


func _full_name(p: Dictionary) -> String:
	return GameDB.player_display_name(p)


func _readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


func _ellipse_points(c: Vector2, a: float, b: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var t := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(t) * a, sin(t) * b))
	return pts


func _stripe(c: Vector2, a: float, b: float, x0: float, x1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var x := lerpf(x0, x1, float(i) / float(steps))
		var t := clampf((x - c.x) / a, -1.0, 1.0)
		var yh := b * sqrt(1.0 - t * t)
		pts.append(Vector2(x, c.y - yh))
	for i in range(steps + 1):
		var x2 := lerpf(x1, x0, float(i) / float(steps))
		var t2 := clampf((x2 - c.x) / a, -1.0, 1.0)
		var yh2 := b * sqrt(1.0 - t2 * t2)
		pts.append(Vector2(x2, c.y + yh2))
	return pts


func _arc_span(c: Vector2, a: float, b: float, goal: Vector2, r: float) -> Vector2:
	var base := atan2(c.y - goal.y, c.x - goal.x)
	var lo := base - PI * 0.5
	var hi := base + PI * 0.5
	var a0 := lo
	var a1 := hi
	var steps := 48
	for i in range(steps + 1):
		var ang := lerpf(lo, hi, float(i) / float(steps))
		if _inside_oval(c, a, b, goal + Vector2(cos(ang), sin(ang)) * r):
			a0 = ang
			break
	for i in range(steps + 1):
		var ang := lerpf(hi, lo, float(i) / float(steps))
		if _inside_oval(c, a, b, goal + Vector2(cos(ang), sin(ang)) * r):
			a1 = ang
			break
	return Vector2(a0, a1)


func _inside_oval(c: Vector2, a: float, b: float, p: Vector2) -> bool:
	var dx := (p.x - c.x) / a
	var dy := (p.y - c.y) / b
	return dx * dx + dy * dy <= 1.0
