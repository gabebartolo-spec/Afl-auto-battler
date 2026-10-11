class_name CaptaincySheet
extends RefCounted
## Your captain and up to two vice-captains (Captaincy.gd), over My list.
## The rules and every cost are on the page before any pick, and the cost of
## the pick you are making is listed above Confirm, in football words. The
## picker lists the whole list by name with Leadership shown plainly: nothing
## is recommended. Close or Back returns to My list.


## Opens the sheet over `host`; returns its overlay. `on_close` runs on close.
static func open(host: Control, on_close: Callable = Callable()) -> Control:
	var box := UiKit.modal_box(host, 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CaptaincySheet"
	var state := {"draft": _current_slots()}
	var body: VBoxContainer = box["body"]
	var footer: VBoxContainer = box["footer"]
	var done := func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	UiKit.close_on_outside_tap(box, done)
	_build(host, overlay, body, footer, state, done)
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


static func _build(host: Control, overlay: Control, body: VBoxContainer, footer: VBoxContainer,
		state: Dictionary, done: Callable) -> void:
	UiKit.clear(body)
	UiKit.clear(footer)
	var draft: Array = state["draft"]
	body.add_child(UiKit.lbl("Captaincy", 22, UiKit.TEXT, true))
	for i in range(Captaincy.MAX_LEADERS):
		body.add_child(_slot_row(host, overlay, body, footer, state, done, i))
	var rec := GameState.captaincy_record(GameState.my_club)
	var pv := GameState.captaincy_preview(draft)
	var changed := JSON.stringify(draft) != JSON.stringify(Captaincy.slots(rec))
	var notes := UiKit.vbox(4)
	notes.name = "CaptaincyCosts"
	body.add_child(notes)
	if changed:
		if not bool(pv["ok"]):
			var why := UiKit.lbl(str(pv["why_not"]), UiKit.BODY, UiKit.BAD)
			why.name = "CaptaincyWhyNot"
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			notes.add_child(why)
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
	# The rules, below the picks and above Confirm's reach: always on the page.
	var rules := UiKit.vbox(4)
	rules.name = "CaptaincyRules"
	body.add_child(UiKit.spacer(4))
	body.add_child(rules)
	for line in Captaincy.rules_text():
		var rl := UiKit.lbl(str(line), UiKit.SMALL, UiKit.MUTED)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rules.add_child(rl)
	var confirm := UiKit.btn("Confirm", UiKit.NAME, true)
	confirm.name = "CaptaincyConfirm"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.disabled = not changed or not bool(pv["ok"])
	confirm.pressed.connect(func():
		var res := GameState.set_captaincy((state["draft"] as Array).duplicate(true))
		if bool(res.get("ok", false)):
			_build(host, overlay, body, footer, state, done))
	footer.add_child(confirm)
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.name = "CaptaincyClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(done)
	footer.add_child(close)


## One of the three spots: who is in it and his Leadership, one tap to change,
## and a Captain / Vice-captain switch for him.
static func _slot_row(host: Control, overlay: Control, body: VBoxContainer, footer: VBoxContainer,
		state: Dictionary, done: Callable, i: int) -> Control:
	var draft: Array = state["draft"]
	var named: Dictionary = draft[i] if i < draft.size() else {}
	var p: Dictionary = _player(str(named.get("id", ""))) if not named.is_empty() else {}
	var h := UiKit.hbox(8)
	var pick := Button.new()
	pick.name = "CaptaincySlot_%d" % i
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(0, 56)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04) if st == "hover" or st == "pressed" else Color.TRANSPARENT
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
		who.add_child(UiKit.ellipsis("Name a leader" if i > 0 or not draft.is_empty() else "Name a captain",
				UiKit.BODY, UiKit.MUTED, true))
	else:
		who.add_child(UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT, true))
		var sub := UiKit.ellipsis("Leadership %d  ·  %d  ·  %d games" % [Leadership.of(p), int(p.get("age", 0)),
				Leadership.games(p)], UiKit.SMALL, UiKit.MUTED)
		sub.name = "SlotLeadership"
		who.add_child(sub)
	pick.pressed.connect(func(): _open_picker(host, overlay, body, footer, state, done, i))
	h.add_child(pick)
	if not p.is_empty():
		var is_cap := str(named.get("role", "")) == "captain"
		var role := UiKit.btn("Captain" if is_cap else "Vice-captain", UiKit.SMALL)
		role.name = "CaptaincyRole_%d" % i
		role.custom_minimum_size = Vector2(96, 48)
		role.pressed.connect(func():
			(state["draft"] as Array)[i]["role"] = "vice" if is_cap else "captain"
			_build(host, overlay, body, footer, state, done))
		h.add_child(role)
	return h


## Everyone on the list, by name, each with his Leadership. A tap names him
## to this spot (and takes him out of another), or clears the spot.
static func _open_picker(host: Control, sheet: Control, body: VBoxContainer, footer: VBoxContainer,
		state: Dictionary, done: Callable, i: int) -> void:
	var box := UiKit.modal_box(host, 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CaptaincyPicker"
	var close := func(): overlay.queue_free()
	UiKit.close_on_outside_tap(box, close)
	var pb: VBoxContainer = box["body"]
	pb.add_child(UiKit.lbl("Name a leader", 22, UiKit.TEXT, true))
	var people := GameState.my_list.duplicate()
	people.sort_custom(func(a, b): return GameDB.player_display_name(a) < GameDB.player_display_name(b))
	var draft: Array = state["draft"]
	var here := {}
	for s in draft:
		here[str((s as Dictionary)["id"])] = str((s as Dictionary)["role"])
	for p in people:
		var id := str(p["id"])
		var row := Button.new()
		row.name = "Pick_" + id
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 56)
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
		var bits := PackedStringArray(["%d" % int(p.get("age", 0)), "%d games" % Leadership.games(p)])
		if here.has(id):
			bits.append("named %s" % str(Captaincy.ROLE_WORDS[here[id]]).to_lower())
		who.add_child(UiKit.ellipsis("Leadership %d  ·  %s" % [Leadership.of(p), "  ·  ".join(bits)], UiKit.SMALL, UiKit.MUTED))
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
			_build(host, sheet, body, footer, state, done))
		pb.add_child(row)
	if i < draft.size():
		var clear := UiKit.btn("Leave this spot empty", UiKit.NAME, true)
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
			_build(host, sheet, body, footer, state, done))
		box["footer"].add_child(clear)
	var back := UiKit.btn("Back", UiKit.NAME, true)
	back.name = "PickerBack"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(close)
	box["footer"].add_child(back)
