class_name CaptaincySheet
extends RefCounted
## Your captain and up to two vice-captains (Captaincy.gd), over My list.
## The spots scroll; what your pick would cost, Confirm and Close stay pinned
## below them (on a wide screen the cost sits beside the spots). The general
## rules are one tap away ("How captaincy works"). The picker lists the whole
## list by name with Leadership shown plainly: nothing is recommended.
## Close or Back returns to My list.

const WIDE := 760.0


static func open(host: Control, on_close: Callable = Callable()) -> Control:
	var box := UiKit.modal_box(host, 900.0 if UiKit.view_width(host) >= WIDE else 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CaptaincySheet"
	var state := {"draft": _current_slots(), "wide": UiKit.view_width(host) >= WIDE}
	var done := func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	UiKit.close_on_outside_tap(box, done)
	_build(host, box, state, done)
	return overlay


static func _current_slots() -> Array:
	var rec := GameState.captaincy_record(GameState.my_club)
	var out := []
	for s in Captaincy.slots(rec):
		out.append((s as Dictionary).duplicate())
	return out


static func _player(id: String) -> Dictionary:
	for p in GameState.my_list:
		if str((p as Dictionary).get("id", "")) == id:
			return p
	return {}


static func _build(host: Control, box: Dictionary, state: Dictionary, done: Callable) -> void:
	var body: VBoxContainer = box["body"]
	var footer: VBoxContainer = box["footer"]
	UiKit.clear(body)
	UiKit.clear(footer)
	var wide: bool = state["wide"]
	var draft: Array = state["draft"]
	body.add_child(UiKit.lbl("Captaincy", 22, UiKit.TEXT, true))
	var rec := GameState.captaincy_record(GameState.my_club)
	var pv := GameState.captaincy_preview(draft)
	var changed := JSON.stringify(draft) != JSON.stringify(Captaincy.slots(rec))

	# What your pick would cost, in football words.
	var notes := UiKit.vbox(6)
	notes.name = "CaptaincyCosts"
	if changed:
		if not bool(pv["ok"]):
			pass  # the reason sits right above Confirm, once
		elif (pv["lines"] as Array).is_empty():
			var free := UiKit.lbl("No cost.", UiKit.BODY, UiKit.TEXT)
			free.name = "CaptaincyNoCost"
			notes.add_child(free)
		else:
			for line in pv["lines"]:
				var cl := UiKit.lbl(str(line), UiKit.BODY, UiKit.TEXT)
				cl.name = "CaptaincyCost"
				cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				notes.add_child(cl)
	var how := _secondary("How captaincy works", UiKit.SMALL)
	how.name = "CaptaincyHow"
	how.custom_minimum_size = Vector2(0, 48)
	how.pressed.connect(func(): _open_rules(host))

	var spots := UiKit.vbox(0)
	spots.name = "CaptaincySpots"
	for i in range(Captaincy.MAX_LEADERS):
		spots.add_child(_slot_row(host, box, state, done, i))

	var confirm := UiKit.btn("Confirm", UiKit.NAME, true)
	confirm.name = "CaptaincyConfirm"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.disabled = not changed or not bool(pv["ok"])
	confirm.pressed.connect(func():
		var res := GameState.set_captaincy((state["draft"] as Array).duplicate(true))
		if bool(res.get("ok", false)):
			_build(host, box, state, done))
	var close := _secondary("Close", UiKit.NAME)
	close.name = "CaptaincyClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(done)
	# Why Confirm is off, once, right above it, saying what to do.
	var off_why := ""
	var off_bad := false
	if confirm.disabled:
		if changed:
			off_why = str(pv["why_not"])
			off_bad = true
		elif draft.is_empty():
			off_why = "Pick a captain to continue"
		elif draft.size() < Captaincy.MAX_LEADERS:
			off_why = "Pick a vice-captain to continue"
		else:
			off_why = "Change a spot to continue"
	if wide:
		var cols := UiKit.hbox(18)
		spots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(spots)
		var side := UiKit.vbox(10)
		side.custom_minimum_size = Vector2(300, 0)
		side.add_child(notes)
		side.add_child(how)
		cols.add_child(side)
		body.add_child(cols)
	else:
		body.add_child(spots)
		footer.add_child(how)
		footer.add_child(notes)
	if off_why != "":
		var ol := UiKit.lbl(off_why, UiKit.BODY if off_bad else UiKit.SMALL, UiKit.BAD if off_bad else UiKit.MUTED)
		ol.name = "CaptaincyWhyNot" if off_bad else "CaptaincyConfirmWhy"
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.add_child(ol)
	footer.add_child(confirm)
	footer.add_child(close)


## One of the three spots: what it is, who is in it, his Leadership, one tap to
## change, and a Captain / Vice-captain switch for him.
static func _slot_row(host: Control, box: Dictionary, state: Dictionary, done: Callable, i: int) -> Control:
	var draft: Array = state["draft"]
	var named: Dictionary = draft[i] if i < draft.size() else {}
	var p: Dictionary = _player(str(named.get("id", ""))) if not named.is_empty() else {}
	var has_captain := false
	for s in draft:
		if str((s as Dictionary)["role"]) == "captain":
			has_captain = true
	var h := UiKit.hbox(8)
	var pick := Button.new()
	pick.name = "CaptaincySlot_%d" % i
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(0, 64)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04) if st == "hover" or st == "pressed" else Color.TRANSPARENT
		if p.is_empty():
			# An empty spot is an outlined row you can see is a tap.
			sb.border_color = UiKit.MUTED
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(UiKit.RADIUS)
			sb.content_margin_left = 12
		else:
			sb.border_color = UiKit.LINE
			sb.border_width_bottom = 1
		pick.add_theme_stylebox_override(st, sb)
	var inner := UiKit.hbox(8)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick.add_child(inner)
	var who := UiKit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(who)
	if p.is_empty():
		var want := "Choose a captain" if not has_captain else "Choose a vice-captain"
		var wl := UiKit.ellipsis(want, UiKit.BODY, UiKit.TEXT, true)
		wl.add_theme_constant_override("outline_size", 0)
		who.add_child(wl)
		inner.offset_left = 12
	else:
		var is_cap := str(named.get("role", "")) == "captain"
		who.add_child(UiKit.ellipsis("Captain" if is_cap else "Vice-captain", UiKit.SMALL, UiKit.MUTED))
		who.add_child(UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT, true))
		# Never ends in an ellipsis: the phone drops games, the wide screen has room.
		var text := "Leadership %d  ·  Age %d" % [Leadership.of(p), int(p.get("age", 0))]
		if bool(state["wide"]):
			text += "  ·  %d games" % Leadership.games(p)
		var sub := UiKit.lbl(text, UiKit.SMALL, UiKit.MUTED)
		sub.name = "SlotLeadership"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		who.add_child(sub)
	pick.pressed.connect(func(): _open_picker(host, box, state, done, i))
	h.add_child(pick)
	if not p.is_empty():
		var is_cap2 := str(named.get("role", "")) == "captain"
		var role := _secondary("Make vice-captain" if is_cap2 else "Make captain", UiKit.SMALL)
		role.name = "CaptaincyRole_%d" % i
		role.custom_minimum_size = Vector2(124, 48)
		role.pressed.connect(func():
			(state["draft"] as Array)[i]["role"] = "vice" if is_cap2 else "captain"
			_build(host, box, state, done))
		h.add_child(role)
	return h


## The general rules, one tap away.
static func _open_rules(host: Control) -> void:
	var box := UiKit.modal_box(host, 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CaptaincyRules"
	UiKit.close_on_outside_tap(box, func(): overlay.queue_free())
	var b: VBoxContainer = box["body"]
	b.add_child(UiKit.lbl("How captaincy works", 22, UiKit.TEXT, true))
	for line in Captaincy.rules_text():
		var rl := UiKit.lbl(str(line), UiKit.BODY, UiKit.TEXT)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(rl)
	var ok := _secondary("Close", UiKit.NAME)
	ok.name = "RulesClose"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(ok)


## Everyone on the list, by name, each with his Leadership: two or three to a
## row on a wide screen. A tap names him to this spot (and takes him out of
## another), or clears the spot.
static func _open_picker(host: Control, sheet: Dictionary, state: Dictionary, done: Callable, i: int) -> void:
	var wide := UiKit.view_width(host) >= WIDE
	var box := UiKit.modal_box(host, 1100.0 if wide else 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CaptaincyPicker"
	var close := func(): overlay.queue_free()
	UiKit.close_on_outside_tap(box, close)
	var pb: VBoxContainer = box["body"]
	var want_captain := (state["draft"] as Array).is_empty()
	if i < (state["draft"] as Array).size():
		want_captain = str((state["draft"] as Array)[i]["role"]) == "captain"
	else:
		want_captain = true
		for s in (state["draft"] as Array):
			if str((s as Dictionary)["role"]) == "captain":
				want_captain = false
	pb.add_child(UiKit.lbl("Choose a captain" if want_captain else "Choose a vice-captain", 22, UiKit.TEXT, true))
	var people := GameState.my_list.duplicate()
	people.sort_custom(func(a, b): return GameDB.player_display_name(a) < GameDB.player_display_name(b))
	var draft: Array = state["draft"]
	var here := {}
	for s in draft:
		here[str((s as Dictionary)["id"])] = str((s as Dictionary)["role"])
	var grid := GridContainer.new()
	grid.name = "PickerGrid"
	grid.columns = 3 if wide else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.add_child(grid)
	pb.add_child(UiKit.spacer(14))
	for p in people:
		var id := str(p["id"])
		var row := Button.new()
		row.name = "Pick_" + id
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 60)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.04) if st == "hover" or st == "pressed" else Color.TRANSPARENT
			sb.border_color = UiKit.LINE
			sb.border_width_bottom = 1
			row.add_theme_stylebox_override(st, sb)
		var h := UiKit.hbox(8)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var who := UiKit.vbox(0)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.alignment = BoxContainer.ALIGNMENT_CENTER
		who.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(who)
		who.add_child(UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT, true))
		var bits := PackedStringArray(["Leadership %d" % Leadership.of(p), "Age %d" % int(p.get("age", 0)),
				"%d games" % Leadership.games(p)])
		if here.has(id):
			bits.append("named %s" % str(Captaincy.ROLE_WORDS[here[id]]).to_lower())
		who.add_child(UiKit.ellipsis("  ·  ".join(bits), UiKit.SMALL, UiKit.MUTED))
		row.pressed.connect(func():
			var d: Array = state["draft"]
			# Into this spot, keeping its role (the first is the captain); out
			# of any other spot he held.
			var role := "captain" if d.is_empty() else "vice"
			if i < d.size():
				role = str(d[i]["role"])
			var next := d.duplicate(true)
			var target := mini(i, next.size())
			if i < next.size():
				next[i] = {"id": id, "role": role}
			else:
				next.append({"id": id, "role": role})
			var kept := []
			for k in range(next.size()):
				if str(next[k]["id"]) != id or k == target:
					kept.append(next[k])
			var has_captain := false
			for s in kept:
				if str((s as Dictionary)["role"]) == "captain":
					has_captain = true
			if not has_captain and not kept.is_empty():
				kept[0]["role"] = "captain"
			state["draft"] = kept
			overlay.queue_free()
			_build(host, sheet, state, done))
		grid.add_child(row)
	if i < draft.size():
		var clear := _secondary("Leave this spot empty", UiKit.NAME)
		clear.name = "PickerClear"
		clear.custom_minimum_size = Vector2(0, 48)
		clear.pressed.connect(func():
			var d: Array = state["draft"]
			d.remove_at(i)
			var has_captain := false
			for s in d:
				if str((s as Dictionary)["role"]) == "captain":
					has_captain = true
			if not has_captain and not d.is_empty():
				d[0]["role"] = "captain"
			overlay.queue_free()
			_build(host, sheet, state, done))
		box["footer"].add_child(clear)
	var back := _secondary("Back", UiKit.NAME)
	back.name = "PickerBack"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(close)
	box["footer"].add_child(back)


## A secondary button: an outline on the page, never a filled card; only
## Confirm takes the accent.
static func _secondary(text: String, fs: int) -> Button:
	var b := UiKit.btn(text, fs)
	var sb := UiKit.style(Color.TRANSPARENT, 8, UiKit.RADIUS, UiKit.MUTED)
	sb.set_border_width_all(1)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	return b
