extends Control
## Your list: how the side stacks up, the best 22 on an oval, and every
## player in one line each - who he is, whether he is available, how good.
## Tap a player for his profile: role, state, development, strengths,
## season and the attributes behind his rating.

const ATTR_ROWS := [
	["disposal", "Disposal"], ["contested", "Contested"], ["marking", "Marking"],
	["pressure", "Pressure"], ["intercept", "Intercept"], ["carry", "Carry"],
	["goalkicking", "Goalkicking"], ["accuracy", "Accuracy"],
	["creating", "Creating"], ["ruck", "Ruck"], ["discipline", "Discipline"],
	["durability", "Durability"], ["star", "Star power"],
]

var _root: VBoxContainer
var _squad: Squad = null
var _pane := "shape"
var _profile: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.my_club == "" or GameState.my_list.is_empty():
		Router.replace("main")
		return
	_squad = GameState.my_squad()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)

	_root = UiKit.vbox(9)
	margin.add_child(_root)
	get_viewport().size_changed.connect(func():
		if is_inside_tree():
			_build())
	if not GameState.player_names_changed.is_connected(_on_names):
		GameState.player_names_changed.connect(_on_names)
	_build()


func _on_names() -> void:
	if is_inside_tree():
		_squad = GameState.my_squad()
		_build()


func _narrow() -> bool:
	return UiKit.view_width(self) < 760.0


func _build() -> void:
	UiKit.clear(_root)
	var train := UiKit.btn("Train", 14)
	train.custom_minimum_size = Vector2(72, 44)
	train.pressed.connect(func(): Router.go("training"))
	_root.add_child(UiKit.top_bar("My list", true, train))

	# How the side stacks up, in words, and who is available.
	var injured := 0
	for p in GameState.my_list:
		if int(p.get("injury_weeks", 0)) > 0:
			injured += 1
	var head := UiKit.lbl(GameState.my_line_standing_text(), UiKit.SMALL, UiKit.TEXT)
	head.name = "LineStanding"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(head)
	var count := "%d players" % GameState.my_list.size()
	if injured > 0:
		count += "  ·  %d injured" % injured
	_root.add_child(UiKit.lbl(count, UiKit.SMALL, UiKit.MUTED))

	if _narrow():
		var tabs := UiKit.hbox(2)
		_root.add_child(tabs)
		var shape_tab := UiKit.tab("Shape", _pane == "shape")
		shape_tab.pressed.connect(func():
			_pane = "shape"
			_build())
		tabs.add_child(shape_tab)
		var list_tab := UiKit.tab("Full list", _pane == "list")
		list_tab.pressed.connect(func():
			_pane = "list"
			_build())
		tabs.add_child(list_tab)

	var body: BoxContainer
	if _narrow():
		body = UiKit.vbox(10)
	else:
		body = UiKit.hbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(body)

	if not _narrow() or _pane == "shape":
		body.add_child(_shape_panel())
	if not _narrow() or _pane == "list":
		body.add_child(_full_list_panel())


func _shape_panel() -> Control:
	var left := UiKit.panel(UiKit.PANEL, 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(0, 220)
	var lv := UiKit.vbox(5)
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lv)
	lv.add_child(UiKit.lbl("Best 22", UiKit.H2, UiKit.EMPH, true))
	var shape_note := UiKit.lbl("Six defenders, six midfielders (ruck included), six forwards and four on the bench. Tap a guernsey.",
			UiKit.SMALL, UiKit.MUTED)
	shape_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(shape_note)
	var oval := FormationView.new()
	oval.name = "Best22Oval"
	oval.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	oval.custom_minimum_size = Vector2(0, 180)
	oval.setup(_squad.ground, _squad.bench, GameState.my_club)
	lv.add_child(oval)
	return left


func _full_list_panel() -> Control:
	var right := UiKit.panel(UiKit.PANEL, 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rv := UiKit.vbox(5)
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rv)
	rv.add_child(UiKit.lbl("Full list", UiKit.H2, UiKit.EMPH, true))
	var lbox := UiKit.vbox(0)
	lbox.name = "ListRows"
	rv.add_child(UiKit.scroll(lbox))

	var grouped := {}
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		grouped[r] = []
	for p in GameState.my_list:
		grouped[str(p["role"])].append(p)
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		var g: Array = grouped[r]
		g.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		lbox.add_child(UiKit.spacer(4))
		lbox.add_child(UiKit.lbl("%s  (%d)" % [UiKit.ROLE_LABEL[r], g.size()],
				UiKit.SMALL, UiKit.MUTED, true))
		for p in g:
			lbox.add_child(_list_row(p))
		lbox.add_child(UiKit.spacer(6))
	return right


func _team_row(p: Dictionary, ground: bool) -> Control:
	var h := UiKit.hbox(6)
	var cols: Array = GameDB.club_colours(str(p["club"]))
	h.add_child(UiKit.chip(str(p["num"]), cols[0]))
	var nm := UiKit.lbl(GameDB.player_display_name(p), 13, UiKit.TEXT if ground else UiKit.MUTED)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	h.add_child(UiKit.role_chip(_player_tag(p)))
	if int(p.get("injury_weeks", 0)) > 0:
		h.add_child(UiKit.line("INJ", 11, UiKit.BAD, true))
	h.add_child(UiKit.line(str(int(p["overall"])), 14, UiKit.EMPH, true))
	h.add_child(UiKit.line("/%d" % int(p.get("potential", p["overall"])), 11,
			UiKit.GOOD if bool(p.get("rehab", false)) else UiKit.MUTED))
	return h


## One player in one line: guernsey, name, who he is (type, age, height),
## anything that stops him playing, and how good he is. Tap for his profile.
func _list_row(p: Dictionary) -> Control:
	var row := Button.new()
	row.name = "Row_" + str(p["id"])
	row.custom_minimum_size = Vector2(0, 56)
	row.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04) if state == "hover" or state == "pressed" else Color.TRANSPARENT
		sb.border_color = UiKit.LINE
		sb.border_width_bottom = 1
		row.add_theme_stylebox_override(state, sb)
	row.pressed.connect(_open_profile.bind(str(p["id"])))
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 2
	h.offset_right = -2
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var cols: Array = GameDB.club_colours(str(p["club"]))
	var num := UiKit.chip(str(p["num"]), cols[0])
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# One width for every guernsey, so the names line up.
	num.custom_minimum_size = Vector2(30, 0)
	h.add_child(num)
	var who := UiKit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(who)
	who.add_child(UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT, true))
	var bits := PackedStringArray([Roles.label(p)])
	if float(p.get("age", 0.0)) > 0.0:
		bits.append("%d" % int(p["age"]))
	if float(p.get("height_cm", 0.0)) > 0.0:
		bits.append("%d cm" % int(p["height_cm"]))
	var sub := UiKit.ellipsis("  ·  ".join(bits), UiKit.SMALL, UiKit.MUTED)
	sub.name = "RowIdentity"
	who.add_child(sub)
	var status := _status(p)
	if str(status[0]) != "":
		var st := UiKit.line(str(status[0]), UiKit.SMALL, status[1], true)
		st.name = "RowStatus"
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(st)
	var nums := UiKit.vbox(0)
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nums)
	var ov := UiKit.line(str(int(p["overall"])), 20, UiKit.TEXT, true)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ov.custom_minimum_size = Vector2(40, 0)
	nums.add_child(ov)
	var pot := UiKit.line("POT %d" % int(p.get("potential", p["overall"])), UiKit.TINY, UiKit.MUTED)
	pot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nums.add_child(pot)
	return row


## The one thing that matters most about his availability: [text, colour].
func _status(p: Dictionary) -> Array:
	var weeks := int(p.get("injury_weeks", 0))
	if weeks > 0:
		return ["Out %s" % ("1 week" if weeks == 1 else "%d weeks" % weeks), UiKit.BAD]
	if bool(p.get("rested", false)):
		return ["Rested", UiKit.MUTED]
	if ClubLife.morale(p) < 40:
		return ["Unhappy", UiKit.BAD]
	return ["", UiKit.TEXT]


## His profile: who he is, his state, how good and how much room, what he
## is picked for, his season, then the attributes behind the rating.
func _open_profile(id: String) -> void:
	var p := GameState.list_player(id)
	if p.is_empty():
		return
	_close_profile()
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_profile = box["overlay"]
	_profile.name = "PlayerProfile"
	var v: VBoxContainer = box["body"]

	var name_l := UiKit.lbl(GameDB.player_display_name(p), 22, UiKit.TEXT, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var type_l := UiKit.lbl(Roles.label(p), UiKit.H2, UiKit.TEXT, true)
	type_l.name = "ProfileType"
	v.add_child(type_l)
	var who := PackedStringArray(["#%d" % int(p["num"]), UiKit.ROLE_LABEL.get(str(p["role"]), str(p["role"]))])
	if float(p.get("age", 0.0)) > 0.0:
		who.append("%d years old" % int(p["age"]))
	if float(p.get("height_cm", 0.0)) > 0.0:
		who.append("%d cm" % int(p["height_cm"]))
	v.add_child(UiKit.lbl("  ·  ".join(who), UiKit.SMALL, UiKit.MUTED))

	# Now: available or not, and how he is feeling.
	var state := PackedStringArray()
	var weeks := int(p.get("injury_weeks", 0))
	if weeks > 0:
		state.append("Injured: out %s%s." % ["1 week" if weeks == 1 else "%d weeks" % weeks,
				" (%s)" % str(p["injury_kind"]) if str(p.get("injury_kind", "")) != "" else ""])
	elif bool(p.get("rested", false)):
		state.append("Rested this week.")
	else:
		state.append("Available.")
	state.append("Mood: %s." % ClubLife.mood(ClubLife.morale(p)).to_lower())
	var sl := UiKit.lbl(" ".join(state), UiKit.BODY, UiKit.BAD if weeks > 0 else UiKit.TEXT)
	sl.name = "ProfileState"
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)

	# How good, and how much room.
	v.add_child(UiKit.spacer(4))
	var nums := UiKit.hbox(18)
	v.add_child(nums)
	for pair in [[int(p["overall"]), "OVR"], [int(p.get("potential", p["overall"])), "POT"]]:
		var nb := UiKit.vbox(0)
		nb.add_child(UiKit.figure(str(pair[0]), 30, UiKit.TEXT))
		nb.add_child(UiKit.lbl(str(pair[1]), UiKit.SMALL, UiKit.MUTED))
		nums.add_child(nb)
	var dev := UiKit.lbl(GameState.development_state(p), UiKit.BODY, UiKit.TEXT)
	dev.name = "ProfileDevelopment"
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev.size_flags_vertical = Control.SIZE_SHRINK_END
	dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_child(dev)
	var plan := GameState.train_plan_label(GameState.plan_for(p))
	if plan != "":
		v.add_child(UiKit.lbl("Training plan: %s" % plan, UiKit.SMALL, UiKit.MUTED))

	# What he is picked for.
	v.add_child(UiKit.spacer(4))
	for st in PlayerProfile.strengths(p):
		var row := UiKit.hbox(8)
		var sn := UiKit.lbl(str(st["label"]), UiKit.BODY, UiKit.TEXT)
		sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sn)
		row.add_child(UiKit.line(str(st["grade"]), UiKit.BODY, UiKit.MUTED))
		v.add_child(row)
	var weak := PlayerProfile.weakness(p)
	if not weak.is_empty():
		v.add_child(UiKit.lbl("Needs work: " + str(weak["label"]).to_lower(), UiKit.SMALL, UiKit.MUTED))
	for t in Traits.of(p):
		var tl := UiKit.lbl("%s. %s" % [Traits.label(str(t)), Traits.scout(str(t))], UiKit.SMALL,
				UiKit.BAD if Traits.is_bad(str(t)) else UiKit.TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)

	# What he has done.
	var prod := PlayerProfile.production(p)
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.lbl(str(prod["title"]), UiKit.SMALL, UiKit.MUTED))
	var pl := UiKit.lbl(str(prod["line"]) if str(prod["line"]) != "" else "No stats on record.",
			UiKit.BODY, UiKit.TEXT if str(prod["line"]) != "" else UiKit.MUTED)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl)

	# The attributes behind the rating: the deepest layer, last.
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.section("Attributes"))
	var grid := GridContainer.new()
	grid.name = "ProfileAttributes"
	grid.columns = 1 if UiKit.view_width(self) < 520.0 else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	var attr: Dictionary = p["attr"]
	for r in ATTR_ROWS:
		grid.add_child(_attr_bar(str(r[0]), str(r[1]), float(attr.get(r[0], 0.0))))

	var close := UiKit.btn("Close", 16, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_profile)
	box["footer"].add_child(close)


func _close_profile() -> void:
	if _profile != null and is_instance_valid(_profile):
		_profile.queue_free()
	_profile = null


## Android Back closes a profile before leaving the list.
func handle_back() -> bool:
	if _profile != null and is_instance_valid(_profile):
		_close_profile()
		return true
	return false


func _player_tag(p: Dictionary) -> String:
	var saved := str(p.get("list_tag", ""))
	if saved != "":
		return saved
	return Ratings.role_tag(p)


func _attr_columns() -> int:
	var w := UiKit.view_width(self)
	if w < 520.0:
		return 1
	return 2 if w < 1000.0 else 3


func _attr_bar(key: String, label: String, value: float) -> Control:
	var h := UiKit.hbox(4)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UiKit.ellipsis(label, UiKit.SMALL, UiKit.MUTED)
	l.custom_minimum_size = Vector2(96, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(70, 9)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := ColorRect.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(70, 7)
	bar.color = Color(1, 1, 1, 0.10)
	holder.add_child(bar)
	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(70.0 * clampf(value / 99.0, 0.0, 1.0), 7)
	fill.color = _attr_colour(value)
	holder.add_child(fill)
	h.add_child(holder)
	var n := UiKit.lbl(str(int(round(value))), UiKit.SMALL, UiKit.TEXT)
	n.custom_minimum_size = Vector2(26, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


func _attr_colour(v: float) -> Color:
	if v >= 75.0:
		return UiKit.GOOD
	if v >= 55.0:
		return UiKit.EMPH
	if v >= 40.0:
		return Color(0.80, 0.76, 0.55)
	return UiKit.BAD
