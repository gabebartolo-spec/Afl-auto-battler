class_name CultureSheet
extends RefCounted
## Your club's culture, over My list: three strands in words, the reasons from
## the career behind them, and what each does for you now. No numbers, no
## meters: each effect is one football line (Culture.effect_line). Back, or the back arrow, returns to My list.
##
## Layout: three words about us, and how we got here (director, 2026-10-13).

const WIDE := 760.0
## Under the title, what culture touches and what it costs (P-63), true to the
## effects in data/culture_effects.json: Standards and Togetherness cut both ways.
const TRADE_OFF_LINE := "Culture tilts your list: how quickly legs recover, how players take a missed game, who stays and joins, and how fast young players come on. Let standards slip or the group split and it costs you."
## The strand emblems: a square this size, tinted this far towards the club's colour.
const ICON := 48.0
const ICON_TINT := 0.55
## Where the emblems live: <id>.png per strand (a test points this elsewhere).
static var icon_dir := "res://assets/ui/culture"

## The autoloads by node, as UiKit does (their names are not known when this compiles).
static func _gs():
	return Engine.get_main_loop().root.get_node("GameState")


static func _short(club: String) -> String:
	return str(Engine.get_main_loop().root.get_node("GameDB").club_short(club))


## The screen, full over `host`. Returns the overlay (named CultureSheet).
static func open(host: Control, on_close: Callable = Callable()) -> Control:
	var root := ColorRect.new()
	root.name = "CultureSheet"
	root.color = UiKit.BG
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var done := func():
		if is_instance_valid(root) and not root.is_queued_for_deletion():
			root.queue_free()
			if on_close.is_valid():
				on_close.call()
	var club: String = _gs().my_club
	var data := strands(club)
	var wide := UiKit.view_width(host) >= WIDE
	_build(root, club, data, wide, done)
	return root


## The strands as the screen shows them: id, label, words, the reasons
## (grouped, newest first) and the newest one as a sentence.
static func strands(club: String) -> Array:
	var out := []
	for s in Culture.STRANDS:
		var id := str(s[0])
		var label := str(s[1])
		var t := Culture.value(_gs().relations, club, id)
		var reasons := Culture.grouped(_gs().relations, club, id)
		var words := Culture.words(id, t)
		if words == "":
			var latest := int(reasons[0]["latest"]) if not reasons.is_empty() else 0
			words = Culture.quiet_words(latest, not reasons.is_empty())
		out.append({"id": id, "label": label, "t": t, "words": words, "reasons": reasons,
				"recent": Culture.group_text(label, reasons[0]) if not reasons.is_empty() else ""})
	return out


## The row on My list that opens it: an invitation, the three phrases in bold.
static func entry_row() -> Button:
	var club: String = _gs().my_club
	var b := UiKit.text_action("", UiKit.NAME)
	b.name = "CultureOpen"
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var phrases := PackedStringArray()
	for d in strands(club):
		phrases.append(str(d["words"]))
	b.tooltip_text = "Club culture"
	var h := UiKit.hbox(12)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = _lift(_lead(club))
	bar.custom_minimum_size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	var col := UiKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UiKit.lbl("Club culture", UiKit.NAME, _ink(club), true)
	head.name = "SectionTitle"
	var body := UiKit.lbl(" · ".join(phrases), UiKit.SECONDARY, UiKit.TEXT, true)
	body.name = "SectionLeadsTo"
	for n in [head, body]:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	col.add_child(body)
	h.add_child(col)
	var chev := UiKit.line("›", 30, UiKit.TEXT, true)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(chev)
	b.add_child(h)
	return b


# --- colour --------------------------------------------------------------

## The club's colour as type on the dark page: lifted until it reads at 4.5:1,
## and plain TEXT for a red club, so it can never be mistaken for BAD.
static func _ink(club: String) -> Color:
	var c := UiKit.club_vivid(club)
	var n := 0
	while UiKit.contrast(c, UiKit.BG) < 4.5 and n < 14:
		c = c.lerp(UiKit.TEXT, 0.12)
		n += 1
	if c.s > 0.35 and (c.h < 0.07 or c.h > 0.96):
		return UiKit.TEXT
	return c


## The club's colour as atmosphere: a rule, a wash.
static func _lead(_club: String) -> Color:
	return UiKit.team_colour()


## A club colour lifted until it reads against the page at `ratio`.
static func _lift(c: Color, ratio := 3.0) -> Color:
	var n := 0
	while UiKit.contrast(c, UiKit.BG) < ratio and n < 14:
		c = c.lerp(UiKit.TEXT, 0.12)
		n += 1
	return c


static func _rule(col: Color, h := 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = _lift(col)
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _margin(root: Control, wide: bool) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(m, 40 if wide else 16)
	return m


static func _back(done: Callable) -> Button:
	var b := UiKit.btn("‹", UiKit.GLYPH)
	b.name = "CultureBack"
	b.flat = true
	b.custom_minimum_size = Vector2(48, 48)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(done)
	return b


## The strand's emblem (a whistle, a handshake, a cup): a grey render the club's
## colour tints, over the strand's name. Null when the art is not there.
static func _icon(id: String, club: String) -> TextureRect:
	var path := "%s/%s.png" % [icon_dir, id]
	if not ResourceLoader.exists(path):
		return null
	var t := TextureRect.new()
	t.name = "StrandIcon"
	t.texture = load(path)
	t.custom_minimum_size = Vector2(ICON, ICON)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = emblem_tint(club)
	return t


## A light wash of the club's colour over the grey emblem, so the three carry
## the club: its hand-picked ink (UiKit.club_ink: the Bulldogs' blue), or its
## second ink when the first is red (Melbourne's navy), because a red emblem
## beside the words could read as a warning. A club with no ink but red and
## white stays plain.
static func emblem_tint(club: String) -> Color:
	var ink := UiKit.club_name_colour(UiKit.club_ink(club))
	if ink == UiKit.TEXT:
		ink = UiKit.club_name_colour(UiKit.club_ink_second(club))
	return Color.WHITE.lerp(ink, ICON_TINT)


## Under a strand's headline: what it does now (bold, only while its band does
## something) and what moves it.
static func _what_it_does(d: Dictionary, parent: Control, size := 0) -> void:
	var fs := size if size > 0 else UiKit.SECONDARY
	var effect := Culture.effect_line(str(d["id"]), int(d["t"]))
	if effect != "":
		var does := UiKit.lbl(effect, fs, UiKit.TEXT, true)
		does.name = "StrandEffect"
		parent.add_child(does)
	var moves := UiKit.lbl(Culture.moves_line(str(d["id"])), fs, UiKit.TEXT)
	moves.name = "StrandMoves"
	parent.add_child(moves)


# --- the screen ----------------------------------------------------------

static func _build(root: Control, club: String, data: Array, wide: bool, done: Callable) -> void:
	var lead := _lead(club)
	var ink := _ink(club)
	var m := _margin(root, wide)
	var page := UiKit.vbox(0)
	m.add_child(page)
	var top := UiKit.hbox(8)
	top.add_child(_back(done))
	var mark := UiKit.hbox(8)
	mark.alignment = BoxContainer.ALIGNMENT_BEGIN
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.add_child(UiKit.club_marker(club, 32.0))
	var mark_name := UiKit.lbl("%s culture" % _short(club), UiKit.NAME, UiKit.TEXT, true)
	mark_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.add_child(mark_name)
	top.add_child(mark)
	page.add_child(top)
	# What it costs and what it buys, in one line (P-63).
	var plain := UiKit.lbl(TRADE_OFF_LINE, UiKit.SECONDARY, UiKit.TEXT)
	plain.name = "CultureTradeOff"
	plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(plain)
	page.add_child(UiKit.spacer(14))
	# The statement: three phrases as one, the strand's name small beside each.
	var statement := UiKit.vbox(88 if wide else 22)
	for d in data:
		var row := UiKit.hbox(14)
		row.name = "Strand_" + str(d["id"])
		var icon := _icon(str(d["id"]), club)
		var name := UiKit.lbl(str(d["label"]), UiKit.NAME if wide else UiKit.SECONDARY, ink, true)
		name.custom_minimum_size.x = 130.0 if wide else 104.0
		name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if icon != null:
			# The emblem sits over the name, in the name's own column, so the
			# words keep the width and the place they have without it. The name is
			# centred under it (director, 2026-10-14: "centre the text beneath the
			# emblem so it doesnt look odd"): one centre line for the two.
			var tag := UiKit.vbox(4)
			tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.add_child(icon)
			tag.add_child(name)
			row.add_child(tag)
		else:
			row.add_child(name)
		var cell := UiKit.vbox(8 if wide else 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var words := UiKit.heading(str(d["words"]), 30)
		words.name = "StrandWords"
		cell.add_child(words)
		_what_it_does(d, cell, UiKit.H2 if wide else 0)
		row.add_child(cell)
		statement.add_child(row)
	# The dated list, newest first, each marked with the strand it touched.
	var sc := UiKit.scroll(_dated_list(data, ink, lead))
	if wide:
		var cols := UiKit.hbox(56)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var left := UiKit.vbox(0)
		left.custom_minimum_size.x = 600.0
		left.add_child(UiKit.spacer(28))
		left.add_child(statement)
		cols.add_child(left)
		var right := UiKit.vbox(10)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(UiKit.lbl("How we got here", UiKit.HEADING, UiKit.TEXT, true))
		right.add_child(_rule(lead))
		right.add_child(sc)
		cols.add_child(right)
		page.add_child(cols)
	else:
		page.add_child(statement)
		page.add_child(UiKit.spacer(22))
		page.add_child(UiKit.lbl("How we got here", UiKit.HEADING, UiKit.TEXT, true))
		page.add_child(UiKit.spacer(4))
		page.add_child(_rule(lead))
		page.add_child(UiKit.spacer(8))
		page.add_child(sc)


static func _dated_list(data: Array, ink: Color, lead: Color) -> VBoxContainer:
	var items := []
	for d in data:
		# One row per event, in its own year (not a repeat folded into the newest).
		for r in Culture.reasons(_gs().relations, _gs().my_club, str(d["id"])):
			items.append({"y": int(r.get("y", 0)), "label": str(d["label"]), "text": Culture.event_text(str(d["label"]), r)})
	var order := range(items.size())
	order.sort_custom(func(a, b): return int(items[a]["y"]) > int(items[b]["y"]) \
			or (int(items[a]["y"]) == int(items[b]["y"]) and a < b))
	var v := UiKit.vbox(16)
	v.name = "CultureReasons"
	if items.is_empty():
		v.add_child(UiKit.lbl("Nothing has moved it yet.", UiKit.BODY, UiKit.TEXT))
	for i in order:
		var it: Dictionary = items[i]
		var row := UiKit.hbox(12)
		var tick := ColorRect.new()
		tick.color = _lift(lead)
		tick.custom_minimum_size = Vector2(3, 0)
		row.add_child(tick)
		var yr := UiKit.lbl(str(it["y"]), UiKit.NAME, UiKit.TEXT, true)
		yr.custom_minimum_size.x = 48.0
		yr.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(yr)
		var col := UiKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.lbl(str(it["label"]), UiKit.SECONDARY, ink, true))
		col.add_child(UiKit.lbl(str(it["text"]), UiKit.BODY, UiKit.TEXT))
		row.add_child(col)
		v.add_child(row)
	return v
