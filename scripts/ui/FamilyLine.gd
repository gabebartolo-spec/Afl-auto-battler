class_name FamilyLine
extends RefCounted
## The bio's family line as a control: "Brother of **Jacob van Rooyen** (Melbourne)".
## A relative who is in the game is a tap away from his own profile.


## Returns null when he has no family tie to show. `host` is where the
## relative's profile opens.
static func make(p: Dictionary, host: Control) -> Control:
	var ties := PlayerRelations.ties(p)
	if ties.is_empty():
		return null
	var flow := HFlowContainer.new()
	flow.name = "FamilyTies"
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 0)
	for i in range(ties.size()):
		var t: Dictionary = ties[i]
		if i > 0:
			flow.add_child(_text("·", UiKit.MUTED, false))
		flow.add_child(_text(str(t["phrase"]), UiKit.MUTED, false))
		if bool(t["found"]):
			var b := UiKit.text_action(str(t["name"]), UiKit.SECONDARY)
			b.name = "FamilyTie_%d" % i
			b.custom_minimum_size = Vector2(0, 40)
			for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				var sb := b.get_theme_stylebox(state) as StyleBoxFlat
				if sb != null:
					sb.content_margin_left = 0.0
					sb.content_margin_right = 0.0
			b.add_theme_font_override("font", UiKit.BOLD)
			var other: Dictionary = t["player"]
			b.pressed.connect(func(): PlayerSheet.open(host, other, Callable(), []))
			flow.add_child(b)
		else:
			flow.add_child(_text(str(t["name"]), UiKit.TEXT, true))
		var note := PlayerRelations.note_text(t)
		if note != "":
			var col: Color = UiKit.MUTED
			if GameDB.clubs.has(str(t["club"])) and note == GameDB.club_name(str(t["club"])):
				col = UiKit.club_vivid(str(t["club"]))
			flow.add_child(_text("(" + note + ")", col, false))
	return flow


static func _text(s: String, col: Color, bold: bool) -> Label:
	var l := UiKit.lbl(s, UiKit.SECONDARY, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l
