class_name CultureSheet
extends RefCounted
## Your club's culture, over My list: three strands in words, the reasons from
## the career behind them. Display only: no numbers, no meters, no effect on
## the sim. Back, or the back arrow, returns to My list.
##
## Three treatments of the same content for the director to choose from
## (2026-10-13: "ugly screen, rework"). `variant` is debug-only; the default
## is A. A: The club's wall. B: Three words about us. C: Inside the rooms.

static var variant := "A"

const WIDE := 760.0
## The autoload by node, as UiKit does: a script with static vars is compiled before
## the autoload names exist.
static func _gs():
	return Engine.get_main_loop().root.get_node("GameState")


static func _short(club: String) -> String:
	return str(Engine.get_main_loop().root.get_node("GameDB").club_short(club))


const PLATE := "res://assets/vignette/rooms/press_room_plate.png"


## The screen, full over `host`. Returns the overlay (named CultureSheet).
static func open(host: Control, on_close: Callable = Callable()) -> Control:
	if OS.is_debug_build() and OS.get_environment("AFL_CULTURE") != "":
		variant = OS.get_environment("AFL_CULTURE")
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
	# Android Back: a layer inside the screen (the reasons sheet) closes first.
	var layers: Array = []
	root.set_meta("back", func() -> bool:
		if not layers.is_empty() and is_instance_valid(layers[0]) and layers[0].visible:
			layers[0].visible = false
			return true
		return false)
	var club: String = _gs().my_club
	var data := strands(club)
	var wide := UiKit.view_width(host) >= WIDE
	match variant:
		"B":
			_build_b(root, club, data, wide, done)
		"C":
			_build_c(root, club, data, wide, done, layers)
		_:
			_build_a(root, club, data, wide, done, layers)
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
		out.append({"id": id, "label": label, "words": words, "reasons": reasons,
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
	bar.color = _lead(club)
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


static func _wash(root: Control, lead: Color, height: float, alpha: float) -> void:
	var w := Control.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(w)
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.draw.connect(func() -> void:
		var top := Color(lead, alpha)
		var none := Color(lead, 0.0)
		var sz := w.size.x
		w.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz, 0), Vector2(sz, height), Vector2(0, height)]),
				PackedColorArray([top, top, none, none])))


static func _rule(col: Color, h := 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
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


static func _hero(club: String, size: int) -> HBoxContainer:
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(UiKit.club_marker(club, 48.0))
	var col := UiKit.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := UiKit.heading(_short(club), size)
	name.name = "CultureClub"
	col.add_child(name)
	col.add_child(UiKit.lbl("Club culture", UiKit.NAME, UiKit.TEXT, true))
	row.add_child(col)
	return row


## Every strand's reasons, newest first, under its name in the club's ink.
static func _reason_rows(data: Array, ink: Color) -> VBoxContainer:
	var v := UiKit.vbox(20)
	v.name = "CultureReasons"
	for d in data:
		var reasons: Array = d["reasons"]
		if reasons.is_empty():
			continue
		var g := UiKit.vbox(8)
		g.add_child(UiKit.lbl(str(d["label"]), UiKit.NAME, ink, true))
		for r in reasons:
			g.add_child(UiKit.lbl(Culture.group_text(str(d["label"]), r), UiKit.BODY, UiKit.TEXT))
		v.add_child(g)
	if v.get_child_count() == 0:
		v.add_child(UiKit.lbl("Nothing has moved it yet.", UiKit.BODY, UiKit.TEXT))
	return v


## A reasons sheet from the bottom, over a dim; a tap on the dim closes it.
static func _reasons_sheet(root: Control, club: String, data: Array, wide: bool, layers: Array) -> Control:
	var layer := VBoxContainer.new()
	layer.name = "CultureReasonsSheet"
	layer.add_theme_constant_override("separation", 0)
	layer.visible = false
	root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and not ev.is_pressed():
			layer.visible = false)
	layer.add_child(dim)
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(holder)
	var sheet := UiKit.panel(UiKit.PANEL, 16)
	sheet.custom_minimum_size.x = 640.0 if wide else 0.0
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_EXPAND_FILL
	holder.add_child(sheet)
	var v := UiKit.vbox(10)
	sheet.add_child(v)
	v.add_child(UiKit.lbl("All reasons", UiKit.TITLE, UiKit.TEXT, true))
	v.add_child(_rule(_lead(club)))
	var sc := UiKit.scroll(_reason_rows(data, _ink(club)))
	sc.custom_minimum_size.y = minf(UiKit.view_height(root) * 0.5, 420.0)
	v.add_child(sc)
	var close := UiKit.text_action("Done", UiKit.NAME)
	close.name = "CultureReasonsDone"
	close.pressed.connect(func(): layer.visible = false)
	v.add_child(close)
	layers.append(layer)
	return layer


# --- A: the club's wall --------------------------------------------------

static func _build_a(root: Control, club: String, data: Array, wide: bool, done: Callable, layers: Array) -> void:
	var lead := _lead(club)
	var ink := _ink(club)
	_wash(root, lead, 340.0, 0.55)
	var m := _margin(root, wide)
	var page := UiKit.vbox(10)
	m.add_child(page)
	var top := UiKit.hbox(8)
	top.add_child(_back(done))
	page.add_child(top)
	page.add_child(_hero(club, 30))
	page.add_child(UiKit.spacer(36 if wide else 22))
	var strands_box: BoxContainer = UiKit.hbox(36) if wide else UiKit.vbox(30)
	strands_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for d in data:
		var col := UiKit.vbox(8)
		col.name = "Strand_" + str(d["id"])
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.lbl(str(d["label"]), UiKit.NAME, ink, true))
		col.add_child(_rule(lead))
		col.add_child(UiKit.spacer(2))
		var words := UiKit.lbl(str(d["words"]), 34 if wide else 28, UiKit.TEXT, true)
		words.name = "StrandWords"
		col.add_child(words)
		if str(d["recent"]) != "":
			var why := UiKit.lbl(str(d["recent"]), UiKit.BODY, UiKit.TEXT)
			why.name = "StrandRecent"
			col.add_child(why)
		strands_box.add_child(col)
	if wide:
		page.add_child(strands_box)
	else:
		page.add_child(UiKit.scroll(strands_box))
	var all := UiKit.text_action("All reasons ›", UiKit.NAME)
	all.name = "CultureAllReasons"
	all.custom_minimum_size = Vector2(160, 52)
	all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(all)
	var sheet := _reasons_sheet(root, club, data, wide, layers)
	all.pressed.connect(func(): sheet.visible = true)


# --- B: three words about us ---------------------------------------------

static func _build_b(root: Control, club: String, data: Array, wide: bool, done: Callable) -> void:
	var lead := _lead(club)
	var ink := _ink(club)
	var m := _margin(root, wide)
	var page := UiKit.vbox(0)
	m.add_child(page)
	var top := UiKit.hbox(8)
	top.add_child(_back(done))
	var mark := UiKit.hbox(8)
	mark.alignment = BoxContainer.ALIGNMENT_BEGIN
	mark.add_child(UiKit.club_marker(club, 32.0))
	mark.add_child(UiKit.lbl("%s culture" % _short(club), UiKit.NAME, UiKit.TEXT, true))
	top.add_child(mark)
	page.add_child(top)
	page.add_child(UiKit.spacer(14))
	# The statement: three phrases as one, the strand's name small beside each.
	var statement := UiKit.vbox(22)
	for d in data:
		var row := UiKit.hbox(14)
		row.name = "Strand_" + str(d["id"])
		var name := UiKit.lbl(str(d["label"]), UiKit.SECONDARY, ink, true)
		name.custom_minimum_size.x = 104.0
		name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(name)
		var words := UiKit.heading(str(d["words"]), 30)
		words.name = "StrandWords"
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		statement.add_child(row)
	# The dated list, newest first, each marked with the strand it touched.
	var sc := UiKit.scroll(_dated_list(data, ink, lead))
	if wide:
		var cols := UiKit.hbox(56)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var left := UiKit.vbox(0)
		left.custom_minimum_size.x = 520.0
		left.add_child(UiKit.spacer(18))
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
		for r in d["reasons"]:
			items.append({"y": int(r["y1"]), "label": str(d["label"]), "text": Culture.group_text(str(d["label"]), r)})
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
		tick.color = lead
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


# --- C: inside the rooms -------------------------------------------------

static func _build_c(root: Control, club: String, data: Array, wide: bool, done: Callable, layers: Array) -> void:
	var lead := _lead(club)
	var ink := _ink(club)
	var tex: Texture2D = null
	if ResourceLoader.exists(PLATE):
		tex = load(PLATE)
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(PLATE))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		var plate := TextureRect.new()
		plate.name = "CulturePlate"
		plate.texture = tex
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(plate)
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0.07, 0.065, 0.06, 0.80)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash(root, lead, 300.0, 0.50)
	var m := _margin(root, wide)
	var page := UiKit.vbox(10)
	m.add_child(page)
	var top := UiKit.hbox(8)
	top.add_child(_back(done))
	page.add_child(top)
	page.add_child(_hero(club, 30))
	page.add_child(UiKit.spacer(18))
	var col := UiKit.vbox(26)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if wide:
		col.custom_minimum_size.x = 640.0
		col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for d in data:
		var s := UiKit.vbox(4)
		s.name = "Strand_" + str(d["id"])
		s.add_child(UiKit.lbl(str(d["label"]), UiKit.NAME, ink, true))
		var words := UiKit.heading(str(d["words"]), 30)
		words.name = "StrandWords"
		s.add_child(words)
		col.add_child(s)
	page.add_child(col)
	# The reasons: a sheet that rises from the bottom.
	var sheet := UiKit.panel(UiKit.PANEL, 14)
	sheet.name = "CultureReasonsSheet"
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_EXPAND_FILL
	sheet.custom_minimum_size.x = 640.0 if wide else 0.0
	var v := UiKit.vbox(8)
	sheet.add_child(v)
	var all := UiKit.text_action("All reasons ⌃", UiKit.NAME)
	all.name = "CultureAllReasons"
	all.custom_minimum_size = Vector2(0, 48)
	all.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(all)
	var sc := UiKit.scroll(_reason_rows(data, ink))
	sc.custom_minimum_size.y = minf(UiKit.view_height(root) * 0.42, 360.0)
	sc.visible = false
	v.add_child(sc)
	all.pressed.connect(func():
		sc.visible = not sc.visible
		all.text = "All reasons ⌄" if sc.visible else "All reasons ⌃")
	page.add_child(sheet)
	layers.append(sc)  # Back folds the sheet away before it leaves
