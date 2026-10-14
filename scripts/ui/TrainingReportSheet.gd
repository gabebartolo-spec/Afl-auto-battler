class_name TrainingReportSheet
extends RefCounted
## The monthly training report (TrainingReport.gd), opened from the hub card
## or the line on Training. A sheet on a phone, a narrower pane on a PC. Tap a
## name for his profile; tap someone who can learn a position to go to his
## choice in Training. Facts only: nothing here says what to do.

const WIDE := 760.0


## The hub's card: the report's name, one tap to open, Hide to dismiss.
static func hub_card(host: Control, on_retrain: Callable) -> Control:
	var r := TrainingReport.current(GameState)
	var card := UiKit.hbox(8)
	card.name = "TrainingReportCard"
	var open_b := UiKit.text_action("", UiKit.NAME)
	open_b.name = "TrainingReportOpen"
	open_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_b.custom_minimum_size = Vector2(0, 56)
	var v := UiKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_b.add_child(v)
	var ink := UiKit.readable_ink(UiKit.team_colour())
	var head := UiKit.ellipsis("Training report: %s" % str(r.get("label", "")).to_lower(), UiKit.NAME, ink, true)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var sub := UiKit.ellipsis(_headline(r), UiKit.SMALL, UiKit.TEXT)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	open_b.pressed.connect(func(): open(host, on_retrain))
	card.add_child(open_b)
	var hide := UiKit.btn("Hide", 14)
	hide.name = "TrainingReportHide"
	hide.custom_minimum_size = Vector2(72, 44)
	hide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hide.pressed.connect(func():
		TrainingReport.dismiss(GameState)
		card.queue_free())
	card.add_child(hide)
	return card


## The one line under the card's name.
static func _headline(r: Dictionary) -> String:
	var n := (r.get("risers", []) as Array).size()
	if n == 0:
		return "No ratings changed."
	return "%d %s improved." % [n, "player" if n == 1 else "players"]


## The Training screen's one-line link.
static func link(host: Control, on_retrain: Callable) -> Control:
	var r := TrainingReport.current(GameState)
	if r.is_empty():
		return null
	var b := UiKit.text_action(TrainingReport.link_text(r), UiKit.SECONDARY)
	b.name = "TrainingReportLink"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var flat := UiKit.style(Color.TRANSPARENT, 0, 0)
	flat.set_border_width_all(0)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, flat)
	b.add_theme_color_override("font_color", UiKit.readable_ink(UiKit.team_colour()))
	b.pressed.connect(func(): open(host, on_retrain))
	return b


## Back / Close: the profile over the report first, then the report. True when
## something closed.
static func close_top(host: Node) -> bool:
	for nm in ["PlayerProfile", "TrainingReportSheet"]:
		var n := host.get_node_or_null(nm)
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion():
			n.queue_free()
			return true
	return false


static func open(host: Control, on_retrain: Callable) -> Control:
	var r := TrainingReport.current(GameState)
	if r.is_empty():
		return null
	var wide := UiKit.view_width(host) >= WIDE
	var box := UiKit.modal_box(host, 980.0 if wide else 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "TrainingReportSheet"
	UiKit.close_on_outside_tap(box)
	var body: VBoxContainer = box["body"]
	var ink := UiKit.readable_ink(UiKit.team_colour())
	body.add_child(UiKit.lbl("Training report", 22, UiKit.TEXT, true))
	body.add_child(UiKit.lbl(str(r.get("label", "")), UiKit.NAME, ink, true))

	# A PC: who moved on the left, who can learn a position on the right.
	var left: VBoxContainer = body
	var right: VBoxContainer = body
	if wide:
		var cols := UiKit.hbox(32)
		body.add_child(cols)
		left = UiKit.vbox(8)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right = UiKit.vbox(8)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(left)
		cols.add_child(right)
	var risers: Array = r.get("risers", [])
	var fallers: Array = r.get("fallers", [])
	if risers.is_empty() and fallers.is_empty():
		var none := UiKit.lbl("Nobody's ratings changed this month.", UiKit.BODY, UiKit.TEXT)
		none.name = "ReportNothing"
		left.add_child(none)
	if not risers.is_empty():
		left.add_child(UiKit.section("Most improved"))
		for e in risers:
			_player_row(host, left, e, true)
	if not fallers.is_empty():
		left.add_child(UiKit.section("Went backwards"))
		for e in fallers:
			_player_row(host, left, e, false)
	var res: Dictionary = r.get("reserves", {})
	if not res.is_empty():
		var n := int(res["count"])
		var rl := UiKit.lbl("In the reserves, %d %s developed: +%d XP each over the month." % [
				n, "player" if n == 1 else "players", int(res["each"])], UiKit.BODY, UiKit.TEXT)
		rl.name = "ReportReserves"
		left.add_child(rl)

	var rt := TrainingReport.retrain_list(GameState, r)
	var entries: Array = rt["entries"]
	if not entries.is_empty():
		right.add_child(UiKit.section("Can learn a new position"))
		if bool(rt["full"]):
			var full := UiKit.lbl("Two players are already learning a position. A new one can start when one of them finishes.",
					UiKit.SECONDARY, UiKit.TEXT)
			full.name = "ReportRetrainFull"
			right.add_child(full)
		var any_new := false
		for e in entries:
			any_new = any_new or bool(e["new"])
		var shown := ""
		for e in entries:
			var group := "new" if bool(e["new"]) else "old"
			if any_new and group != shown:
				right.add_child(UiKit.lbl("Became available this month" if group == "new" else "Available before",
						UiKit.SECONDARY, UiKit.TEXT, true))
			shown = group
			_retrain_row(host, right, e, on_retrain, overlay)

	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.name = "TrainingReportClose"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(close)
	return overlay


static func _name_button(host: Control, id: String, text: String, tap: Callable) -> Button:
	var b := UiKit.text_action(text, UiKit.NAME)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var flat := UiKit.style(Color.TRANSPARENT, 0, 0)
	flat.set_border_width_all(0)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, flat)
	b.name = "Name_" + id
	b.add_theme_color_override("font_color", UiKit.readable_ink(UiKit.team_colour()))
	b.add_theme_color_override("font_hover_color", UiKit.readable_ink(UiKit.team_colour()))
	b.pressed.connect(tap)
	return b


static func _player_row(host: Control, body: VBoxContainer, e: Dictionary, rose: bool) -> void:
	var p := GameState.list_player(str(e["id"]))
	if p.is_empty():
		return
	var v := UiKit.vbox(0)
	v.name = "Row_" + str(e["id"])
	body.add_child(v)
	var o0 := int(e["ovr0"])
	var o1 := int(e["ovr1"])
	var head := GameDB.player_display_name(p)
	if o0 != o1:
		head += "  OVR %d to %d" % [o0, o1]
	v.add_child(_name_button(host, str(e["id"]), head, func():
		PlayerSheet.open(host, GameState.list_player(str(e["id"])))))
	var parts := []
	for s in e["stats"]:
		parts.append("%s %d to %d" % [str(s[0]), int(s[1]), int(s[2])])
	if not parts.is_empty():
		var l := UiKit.lbl(", ".join(parts), UiKit.SECONDARY, UiKit.TEXT)
		l.name = "Stats"
		v.add_child(l)


static func _retrain_row(host: Control, body: VBoxContainer, e: Dictionary, on_retrain: Callable, overlay: Control) -> void:
	var p := GameState.list_player(str(e["id"]))
	if p.is_empty():
		return
	var v := UiKit.vbox(0)
	v.name = "Retrain_" + str(e["id"])
	body.add_child(v)
	var id := str(e["id"])
	v.add_child(_name_button(host, id, GameDB.player_display_name(p), func():
		overlay.queue_free()
		on_retrain.call(id)))
	var l := UiKit.lbl("Can learn " + " or ".join(e["jobs"]), UiKit.SECONDARY, UiKit.TEXT)
	l.name = "Jobs"
	v.add_child(l)
