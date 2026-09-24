extends Control
## Your drafted list: the best 22 the engine will field, then the whole list
## grouped by position with the attributes they were rated on.

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
	_root.add_child(UiKit.top_bar("%s - My List" % GameDB.club_name(GameState.my_club), true, train))

	var summary := GridContainer.new()
	summary.columns = 2 if UiKit.view_width(self) < 520.0 else 5
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	_root.add_child(summary)
	summary.add_child(_stat_card("Strength", "%.1f" % _squad.strength()))
	summary.add_child(_stat_card("Contest", "%.1f" % _squad.contest))
	summary.add_child(_stat_card("Attack", "%.1f" % _squad.attack))
	summary.add_child(_stat_card("Defence", "%.1f" % _squad.defence))
	summary.add_child(_stat_card("List", str(GameState.my_list.size())))

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
	lv.add_child(UiKit.lbl("Best 22", 17, UiKit.GOLD, true))
	lv.add_child(UiKit.lbl(
			"Match-day shape: 1 ruck, 7 mids, 5 defenders, 5 forwards. Four more wait on the interchange. Tap a guernsey.",
			11, UiKit.MUTED))
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
	rv.add_child(UiKit.lbl("Full List", 17, UiKit.GOLD, true))
	var lbox := UiKit.vbox(2)
	rv.add_child(UiKit.scroll(lbox))

	var grouped := {}
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		grouped[r] = []
	for p in GameState.my_list:
		grouped[str(p["role"])].append(p)
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		var g: Array = grouped[r]
		g.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		lbox.add_child(UiKit.lbl("%s  (%d)" % [UiKit.ROLE_LABEL[r], g.size()],
				13, UiKit.MUTED, true))
		for p in g:
			lbox.add_child(_list_row(p))
		lbox.add_child(UiKit.spacer(6))
	return right


func _stat_card(label: String, value: String) -> Control:
	var p := UiKit.panel(UiKit.PANEL_ALT, 10, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(2)
	p.add_child(v)
	var val := UiKit.lbl(value, 22, UiKit.GOLD, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	var lab := UiKit.lbl(label, 11, UiKit.MUTED)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lab)
	return p


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
	h.add_child(UiKit.line(str(int(p["overall"])), 14, UiKit.GOLD, true))
	h.add_child(UiKit.line("/%d" % int(p.get("potential", p["overall"])), 11,
			UiKit.GOOD if bool(p.get("rehab", false)) else UiKit.MUTED))
	return h


func _list_row(p: Dictionary) -> Control:
	var panel := UiKit.panel(UiKit.PANEL_ALT, 8, 7)
	var v := UiKit.vbox(4)
	panel.add_child(v)

	var h := UiKit.hbox(6)
	v.add_child(h)
	var cols: Array = GameDB.club_colours(str(p["club"]))
	h.add_child(UiKit.chip(str(p["num"]), cols[0]))
	var nm := UiKit.lbl(GameDB.player_display_name(p), 15, UiKit.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	if int(p.get("injury_weeks", 0)) > 0:
		h.add_child(UiKit.line("INJ %dw %s" % [int(p["injury_weeks"]), str(p.get("injury_kind", ""))],
				12, UiKit.BAD, true))
	var xp := UiKit.line("%d XP" % int(p.get("xp", 0)), 12, UiKit.GOLD, true)
	h.add_child(xp)
	var ov := UiKit.lbl(str(int(p["overall"])), 18, UiKit.GOLD, true)
	ov.custom_minimum_size = Vector2(38, 0)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ov)
	var pot := UiKit.line("POT %d" % int(p.get("potential", p["overall"])), 12,
			UiKit.GOOD if bool(p.get("rehab", false)) else UiKit.MUTED, true)
	pot.tooltip_text = "Potential: the rating he can grow into."
	h.add_child(pot)

	# Season line - the real numbers the rating was built from. Prospects
	# instead show the U18/state-league line the projection was built on.
	var season := ""
	if bool(p.get("projected", false)):
		season = "U18: %.1f disp  -  %.1f marks  -  %.1f goals  -  %.1f tk  -  %.1f ho per game" % [
				float(p.get("u18_di", 0.0)), float(p.get("u18_mk", 0.0)),
				float(p.get("u18_gl", 0.0)), float(p.get("u18_tk", 0.0)),
				float(p.get("u18_ho", 0.0))]
		if int(p.get("draft_pick", 0)) > 0:
			season += "   ·   drafted #%d in %d" % [int(p["draft_pick"]), int(p.get("draft_year", 0))]
	else:
		season = "%d gm  -  %.1f disp  -  %d gl  -  %d bh  -  %d tk  -  %d i50  -  %d ho  -  %d br" % [
				int(p["gm"]), float(p["di"]) / maxf(1.0, float(p["gm"])), int(p["gl"]),
				int(p["bh"]), int(p["tk"]), int(p["if50"]), int(p["ho"]), int(p["br"])]
		if str(p.get("src", "2026")) != "2026":
			season += "   (%s stats)" % str(p["src"])
	var sl := UiKit.lbl(season, 11, UiKit.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)

	# Attribute bars
	var grid := GridContainer.new()
	grid.columns = _attr_columns()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	var attr: Dictionary = p["attr"]
	for row in ATTR_ROWS:
		grid.add_child(_attr_bar(str(row[0]), str(row[1]), float(attr.get(row[0], 0.0))))
	return panel


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
	var l := UiKit.ellipsis(label, 10, UiKit.MUTED)
	l.custom_minimum_size = Vector2(74, 0)
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
	var n := UiKit.lbl(str(int(round(value))), 10, _attr_colour(value))
	n.custom_minimum_size = Vector2(20, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


func _attr_colour(v: float) -> Color:
	if v >= 75.0:
		return UiKit.GOOD
	if v >= 55.0:
		return UiKit.GOLD
	if v >= 40.0:
		return Color(0.80, 0.76, 0.55)
	return UiKit.BAD
