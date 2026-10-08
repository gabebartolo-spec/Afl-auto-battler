class_name TeamBuilder
extends BoxContainer
## The one team viewer (director's PC playtest, 2026-10-07): your side on the
## oval with the interchange under it, and everyone else in a compact grid
## beside it (under it on a phone). Tap one player, then another, to swap
## them - field, bench or grid; on a PC drag one onto another. Every move is
## your selection at once: the match uses it, and the screen's lines and
## synergies follow (`changed`). A player who can't play (injured, suspended)
## can't be put in the side; the screen says why.

signal changed(note: String)
signal inspect(id: String)

## Selection lines -> the oval's spots, in order (FormationView.SLOTS). The
## centre square is MID (centre, two inside mids); the wings are WING.
const SPOTS := {
	"RUCK": ["RUCK"], "MID": ["C", "IL", "IR"], "WING": ["WL", "WR"],
	"DEF": ["FB", "HBFL", "HBFR", "BPL", "BPR", "CB"],
	"FWD": ["FF", "HFFL", "HFFR", "FPL", "FPR", "HFF"],
}
const LINES := ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH"]
const PHONE_MIDS := {"IL": Vector2(0.0, -0.48), "IR": Vector2(0.0, 0.48), "WL": Vector2(0.18, -0.90),
		"WR": Vector2(0.18, 0.90), "CB": Vector2(-0.42, 0.0), "HFF": Vector2(0.42, 0.0)}
const SPINE := {"CB": Vector2(-0.50, 0.0), "C": Vector2(-0.18, 0.0), "RUCK": Vector2(0.16, 0.0),
		"HFF": Vector2(0.48, 0.0)}
const ROLE_TABS := [["", "All"], ["DEF", "DEF"], ["MID", "MID"], ["RUCK", "RUCK"], ["FWD", "FWD"]]

var _side := {}
var _picked := ""
var _role := ""
var _search := ""
var _wide := false
var _pitch: Control
var _spot_at := {}        # spot key -> Vector2 (FormationView.SLOTS "at")
var _grid: GridContainer
var _search_field: LineEdit
## Another club's side to look at, not edit (the opposition view): taps open
## a profile, nothing moves, and the oval is mirrored - they kick the other way.
var _list: Array = []
var _read_only := false
## Just the oval and the interchange, the right way round: a team that isn't
## anyone's opponent (the projected All-Australian team). Set before setup().
var field_only := false
## With field_only: a line under each name in place of position and OVR
## (id -> text; the All-Australian team shows each player's club).
var notes := {}


func setup(side: Dictionary, wide: bool, list: Array = [], read_only := false) -> void:
	_list = list if not list.is_empty() else GameState.my_list
	_read_only = read_only
	_side = side.duplicate(true)
	for line in LINES:
		if not _side.has(line):
			_side[line] = []
	_wide = wide
	vertical = not wide
	add_theme_constant_override("separation", 14)
	for s in FormationView.SLOTS:
		_spot_at[str(s["key"])] = s["at"]
	# The spine (centre half-back, centre, ruck, centre half-forward) is
	# spread wider than the formation view so its cards never touch.
	_spot_at.merge(SPINE, true)
	if not wide:
		# On a phone the midfield runs across a narrow screen: the inside mids
		# and wings spread to its edges.
		_spot_at.merge(PHONE_MIDS, true)
	_build()


func side() -> Dictionary:
	return _side.duplicate(true)


func picked() -> String:
	return _picked


func _build() -> void:
	UiKit.clear(self)
	var field := UiKit.vbox(8)
	field.name = "BuilderField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.15
	add_child(field)
	_pitch = Control.new()
	_pitch.name = "Pitch"
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.custom_minimum_size = Vector2(0, 430 if _wide else 600)
	_pitch.mouse_filter = Control.MOUSE_FILTER_PASS
	_pitch.draw.connect(_draw_pitch)
	_pitch.resized.connect(_place_spots)
	field.add_child(_pitch)
	for line in ["RUCK", "MID", "WING", "DEF", "FWD"]:
		var ids: Array = _side[line]
		var keys: Array = SPOTS[line]
		for i in range(keys.size()):
			var id := str(ids[i]) if i < ids.size() else ""
			var card := _card(id, true, "%s:%d" % [line, i])
			card.name = "Spot_" + str(keys[i])
			card.set_meta("spot", str(keys[i]))
			_pitch.add_child(card)
	field.add_child(UiKit.lbl("Interchange", UiKit.SMALL, UiKit.MUTED, true))
	# A row of five on a PC; on a phone it wraps rather than widen the screen.
	var bench := GridContainer.new()
	bench.name = "Bench"
	bench.columns = 5 if _wide else 3
	bench.add_theme_constant_override("h_separation", 6)
	bench.add_theme_constant_override("v_separation", 6)
	field.add_child(bench)
	var bench_ids: Array = _side["BENCH"]
	for i in range(maxi(Ratings.INTERCHANGE, bench_ids.size())):
		var bid := str(bench_ids[i]) if i < bench_ids.size() else ""
		var bc := _card(bid, true, "BENCH:%d" % i)
		bc.name = "BenchSpot_%d" % i
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench.add_child(bc)
	_place_spots.call_deferred()
	if field_only:
		return

	var rest := UiKit.vbox(6)
	rest.name = "BuilderRest"
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rest)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	rest.add_child(tabs)
	for t in ROLE_TABS:
		var tb := UiKit.btn(str(t[1]), 13)
		tb.name = "BuilderRole_" + (str(t[0]) if str(t[0]) != "" else "ALL")
		tb.custom_minimum_size = Vector2(0, 44)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.paint_choice(tb, _role == str(t[0]))
		var key := str(t[0])
		tb.pressed.connect(func():
			_role = key
			_build())
		tabs.add_child(tb)
	_search_field = UiKit.search_field(_search, "Search your list...")
	_search_field.name = "BuilderSearch"
	_search_field.text_changed.connect(func(t: String):
		_search = t
		_fill_grid())
	rest.add_child(_search_field)
	if _read_only:
		var ro := UiKit.lbl("Their side as it would take the field: tap a player to see him.", UiKit.SMALL, UiKit.MUTED)
		ro.name = "ReadOnlyHint"
		ro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rest.add_child(ro)
	elif _picked != "":
		# The player you picked: swap him by tapping another, or look at him.
		var bar := UiKit.hbox(6)
		bar.name = "PickedBar"
		var who := UiKit.ellipsis("%s picked: tap who he swaps with." % GameDB.player_display_name(_player(_picked)),
				UiKit.SMALL, UiKit.TEXT, true)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(who)
		var prof := UiKit.btn("Profile", 13)
		prof.name = "PickedProfile"
		prof.custom_minimum_size = Vector2(80, 44)
		var pid := _picked
		prof.pressed.connect(func():
			_picked = ""
			_build()
			inspect.emit(pid))
		bar.add_child(prof)
		var cancel := UiKit.btn("Cancel", 13)
		cancel.name = "PickedCancel"
		cancel.flat = true
		cancel.custom_minimum_size = Vector2(72, 44)
		cancel.pressed.connect(func():
			_picked = ""
			_build())
		bar.add_child(cancel)
		rest.add_child(bar)
	else:
		var hint := UiKit.lbl("Tap a player, then another (or drag one onto another) to swap them.",
				UiKit.SMALL, UiKit.MUTED)
		hint.name = "BuilderHint"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rest.add_child(hint)
	_grid = GridContainer.new()
	_grid.name = "NotSelected"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.add_child(_grid)
	_fill_grid()


func _fill_grid() -> void:
	if not is_instance_valid(_grid):
		return
	UiKit.clear(_grid)
	var in_side := {}
	for line in LINES:
		for id in _side[line]:
			in_side[str(id)] = true
	var out: Array = []
	var q := _search.strip_edges().to_lower()
	for p in _list:
		if in_side.has(str(p["id"])):
			continue
		if _role != "" and not Ratings.plays_role(p, _role):
			continue
		if q != "" and not GameDB.player_display_name(p).to_lower().contains(q):
			continue
		out.append(p)
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	for p in out:
		var c := _card(str(p["id"]), false, "")
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(c)
	if out.is_empty():
		_grid.add_child(UiKit.lbl("Nobody else here.", UiKit.SMALL, UiKit.MUTED))


## A player as a compact card: name and OVR, then position, playing style and
## age, then traits (or why he can't play). On the oval, the short version.
func _card(id: String, on_field: bool, place: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var p := _player(id) if id != "" else {}
	b.name = "Card_" + id if id != "" else "Empty"
	b.set_meta("id", id)
	b.set_meta("place", place)
	var on := id != "" and id == _picked
	UiKit.paint_choice(b, on)
	var face := UiKit.vbox(0)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 6
	face.offset_right = -6
	face.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(face)
	if p.is_empty():
		face.add_child(UiKit.lbl("Empty", 12, UiKit.MUTED))
		b.custom_minimum_size = Vector2(88, 44)
	elif on_field:
		var top := UiKit.ellipsis(str(p.get("last", GameDB.player_display_name(p))), 13, UiKit.TEXT, true)
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(top)
		var sub := UiKit.lbl(str(notes[id]) if field_only and notes.has(id)
				else "%s %d" % [Ratings.role_tag(p), int(p["overall"])], 11, UiKit.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(sub)
		b.custom_minimum_size = Vector2(84 if _wide else 70, 44)
		if not field_only and Workload.value(p) >= Workload.CARRYING:
			# How fresh he is, on the card: no profile needed to see it.
			var ready := UiKit.lbl(Workload.label(p), 10, UiKit.BAD if Workload.value(p) >= Workload.NEEDS_BREAK else UiKit.MUTED)
			ready.name = "Readiness_" + id
			ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ready.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			face.add_child(ready)
			b.custom_minimum_size.y = 58
		b.tooltip_text = GameDB.player_display_name(p)
	else:
		var row := UiKit.hbox(6)
		face.add_child(row)
		var n := UiKit.ellipsis(GameDB.player_display_name(p), 14, UiKit.TEXT, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var ovr := UiKit.lbl("%d" % int(p["overall"]), 14, UiKit.TEXT, true)
		ovr.autowrap_mode = TextServer.AUTOWRAP_OFF
		ovr.custom_minimum_size.x = 26
		ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(ovr)
		var age := int(p.get("age", 0))
		face.add_child(UiKit.ellipsis("%s · %s · %d yo" % [Ratings.role_tag(p), PlayerProfile.player_type(p), age],
				12, UiKit.MUTED))
		var third: PackedStringArray = []
		if not Ratings.available(p):
			third.append(_why_out(p))
		elif Workload.value(p) >= Workload.CARRYING:
			third.append(Workload.label(p))
		for t in Traits.of(p):
			third.append(Traits.label(str(t)))
		if Roles.is_tagger(p):
			third.append("Tagger")
		face.add_child(UiKit.ellipsis(" · ".join(third) if not third.is_empty() else " ", 12,
				UiKit.BAD if not Ratings.available(p) else UiKit.MUTED))
		b.custom_minimum_size = Vector2(160, 62)
	_ignore_mouse(face)
	if _read_only:
		if id != "":
			b.pressed.connect(func(): inspect.emit(id))
		return b
	b.pressed.connect(_tap.bind(id, place))
	if id != "":
		b.set_drag_forwarding(
				func(_at: Vector2):
					var preview := UiKit.lbl(GameDB.player_display_name(p), 14, UiKit.TEXT, true)
					b.set_drag_preview(preview)
					return {"team_builder": id},
				func(_at: Vector2, data) -> bool:
					return data is Dictionary and (data as Dictionary).has("team_builder"),
				func(_at: Vector2, data) -> void:
					_swap(str(data["team_builder"]), id, place))
	elif place != "":
		b.set_drag_forwarding(Callable(),
				func(_at: Vector2, data) -> bool:
					return data is Dictionary and (data as Dictionary).has("team_builder"),
				func(_at: Vector2, data) -> void:
					_swap(str(data["team_builder"]), "", place))
	return b


func _player(id: String) -> Dictionary:
	for p in _list:
		if str(p["id"]) == id:
			return p
	return {}


func _why_out(p: Dictionary) -> String:
	if int(p.get("injury_weeks", 0)) > 0:
		return "Injured, %d wk" % int(p["injury_weeks"])
	if int(p.get("suspension_weeks", 0)) > 0:
		return "Suspended"
	return "Unavailable"


## First tap picks a player; the second swaps him with that player or spot.
## Tapping him again lets him go.
func _tap(id: String, place: String) -> void:
	if _picked == "":
		if id == "":
			return
		_picked = id
		_build()
		return
	if id == _picked:
		_picked = ""
		_build()
		return
	var a := _picked
	_picked = ""
	_swap(a, id, place)


func _where(id: String) -> Array:
	for line in LINES:
		var i := (_side[line] as Array).find(id)
		if i >= 0:
			return [line, i]
	return []


## Swap a with b (b may be "" for an empty spot at `place`, "LINE:i").
func _swap(a: String, b: String, place: String) -> void:
	if a == b:
		_build()
		return
	var wa := _where(a)
	var wb := _where(b) if b != "" else []
	if b == "" and place != "":
		var parts := place.split(":")
		wb = [parts[0], int(parts[1])]
	var pa := _player(a)
	var pb := _player(b) if b != "" else {}
	# Coming into the side, a player must be able to play.
	if wa.is_empty() and not wb.is_empty() and not Ratings.available(pa):
		changed.emit("%s can't play this week: %s." % [GameDB.player_display_name(pa), _why_out(pa).to_lower()])
		_build()
		return
	if wb.is_empty() and not wa.is_empty() and b != "" and not Ratings.available(pb):
		changed.emit("%s can't play this week: %s." % [GameDB.player_display_name(pb), _why_out(pb).to_lower()])
		_build()
		return
	if wa.is_empty() and wb.is_empty():
		_picked = b
		_build()
		return
	var note := ""
	if not wa.is_empty() and not wb.is_empty():
		var la: Array = _side[wa[0]]
		var lb: Array = _side[wb[0]]
		while lb.size() <= int(wb[1]):
			lb.append("")
		la[int(wa[1])] = b
		lb[int(wb[1])] = a
		note = "%s and %s swap." % [GameDB.player_display_name(pa), GameDB.player_display_name(pb)] if b != "" \
				else "%s moves." % GameDB.player_display_name(pa)
	elif not wa.is_empty():
		(_side[wa[0]] as Array)[int(wa[1])] = b
		note = "%s comes in for %s." % [GameDB.player_display_name(pb), GameDB.player_display_name(pa)]
	else:
		var lb2: Array = _side[wb[0]]
		while lb2.size() <= int(wb[1]):
			lb2.append("")
		lb2[int(wb[1])] = a
		note = "%s comes in for %s." % [GameDB.player_display_name(pa), GameDB.player_display_name(pb)] if b != "" \
				else "%s comes in." % GameDB.player_display_name(pa)
	for line in LINES:
		_side[line] = (_side[line] as Array).filter(func(x): return str(x) != "")
	GameState.set_selection(_side)
	_build()
	changed.emit(note)


func _place_spots() -> void:
	if not is_instance_valid(_pitch):
		return
	var r := Rect2(Vector2.ZERO, _pitch.size).grow(-8.0)
	for c in _pitch.get_children():
		if not c.has_meta("spot"):
			continue
		var at: Vector2 = _spot_at.get(str(c.get_meta("spot")), Vector2.ZERO)
		# Wide: the ground runs left to right, our goal on the left. Phone: it
		# runs up the screen, attacking upward.
		if _read_only and not field_only:
			at = Vector2(-at.x, at.y)
		var u := Vector2(at.x, at.y) if _wide else Vector2(at.y, -at.x)
		var centre := r.get_center() + Vector2(u.x * r.size.x * 0.5, u.y * r.size.y * 0.5)
		var sz: Vector2 = (c as Control).get_combined_minimum_size()
		(c as Control).size = sz
		(c as Control).position = (centre - sz * 0.5).clamp(r.position, r.end - sz)
	_pitch.queue_redraw()


func _draw_pitch() -> void:
	var r := Rect2(Vector2.ZERO, _pitch.size).grow(-2.0)
	var line := Color(UiKit.TEXT, 0.16)
	var pts := PackedVector2Array()
	for i in range(65):
		var t := TAU * i / 64.0
		pts.append(r.get_center() + Vector2(cos(t) * r.size.x * 0.5, sin(t) * r.size.y * 0.5))
	_pitch.draw_colored_polygon(pts, Color(UiKit.GOOD, 0.06))
	_pitch.draw_polyline(pts, line, 2.0, true)
	var c := r.get_center()
	var sq := minf(r.size.x, r.size.y) * 0.22
	_pitch.draw_rect(Rect2(c - Vector2(sq, sq) * 0.5, Vector2(sq, sq)), line, false, 1.5)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_mouse(ch)
