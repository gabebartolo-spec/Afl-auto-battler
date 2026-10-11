class_name CultureSheet
extends RefCounted
## Your club's culture over My list: three strands in words, each with the
## reasons behind it one tap away. No numbers, no meters. A strand with nothing
## to say reads "Nothing stands out yet". Close or Back returns to My list.


static func open(host: Control, on_close: Callable = Callable()) -> Control:
	var box := UiKit.modal_box(host, 480.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CultureSheet"
	var done := func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	UiKit.close_on_outside_tap(box, done)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Club culture", 22, UiKit.TEXT, true))
	var club := GameState.my_club
	for s in Culture.STRANDS:
		v.add_child(_strand(str(s[0]), str(s[1]), club))
	v.add_child(UiKit.spacer(10))
	v.add_child(UiKit.spacer(20))
	var close := _secondary("Close", UiKit.NAME)
	close.name = "CultureClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(done)
	box["footer"].add_child(close)
	# On a PC the sheet's buttons grow to 240; Close is sized to its word.
	close.custom_minimum_size.x = 0
	close.size_flags_horizontal = Control.SIZE_SHRINK_END if UiKit.view_width(host) >= 760.0 else Control.SIZE_FILL
	return overlay


static func _strand(strand: String, label: String, club: String) -> Control:
	var t := Culture.value(GameState.relations, club, strand)
	var words := Culture.words(strand, t)
	var col := UiKit.vbox(4)
	col.name = "Strand_" + strand
	col.add_child(UiKit.spacer(24))
	col.add_child(UiKit.lbl(label, UiKit.BODY, UiKit.MUTED, true))
	var row := UiKit.hbox(8)
	col.add_child(row)
	var reasons := Culture.grouped(GameState.relations, club, strand)
	var latest := int(reasons[0]["latest"]) if not reasons.is_empty() else 0
	var wl := UiKit.lbl(words if words != "" else Culture.quiet_words(latest, not reasons.is_empty()), UiKit.BODY,
			UiKit.TEXT)
	wl.name = "StrandWords"
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(wl)
	var list := UiKit.vbox(12)
	list.name = "StrandReasons"
	list.visible = false
	if reasons.is_empty():
		col.add_child(list)
		return col  # nothing to explain: no Why, no empty list
	var intro := UiKit.lbl("These lifted %s. Any that cost it say so." % label, UiKit.SMALL, UiKit.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(intro)
	for r in reasons:
		var rl := UiKit.lbl(Culture.group_text(label, r), UiKit.BODY, UiKit.TEXT)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(rl)
	var why := UiKit.text_action("Why", UiKit.SMALL)
	why.name = "StrandWhy"
	why.custom_minimum_size = Vector2(72, 48)
	why.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	why.set_meta("culture_why", true)
	why.pressed.connect(func():
		var open := not list.visible
		# One strand's reasons at a time, so the sheet never grows past the screen.
		for other in col.get_parent().find_children("StrandReasons", "VBoxContainer", true, false):
			other.visible = false
		for other_why in col.get_parent().find_children("StrandWhy", "Button", true, false):
			other_why.text = "Why"
		list.visible = open
		why.text = "Hide" if open else "Why")
	row.add_child(why)
	col.add_child(list)
	return col


## A secondary button: an outline, never a filled card.
static func _secondary(text: String, fs: int) -> Button:
	var b := UiKit.btn(text, fs)
	var sb := UiKit.style(Color.TRANSPARENT, 8, UiKit.RADIUS, UiKit.MUTED)
	sb.set_border_width_all(1)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	return b
