extends Control
## Full ladder, plus the finals bracket once the season proper is done.

var _root: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_root = UiKit.vbox(9)
	margin.add_child(_root)
	_build()


func _build() -> void:
	var season: Season = GameState.season

	_root.add_child(UiKit.top_bar("Ladder", true))

	var info := "Home and away complete" if season.is_regular_done() \
			else "After %d of %d rounds" % [season.round_index, Season.REGULAR_ROUNDS]
	_root.add_child(UiKit.subtitle(info))

	var p := UiKit.panel(UiKit.PANEL, 12)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(p)
	var v := UiKit.vbox(2)
	p.add_child(v)
	v.add_child(_header())
	v.add_child(UiKit.scroll(_rows(season.ladder_sorted())))

	if not season.finals.is_empty():
		_root.add_child(UiKit.lbl("Finals Series", 18, UiKit.GOLD, true))
		var fp := UiKit.panel(UiKit.PANEL, 12)
		_root.add_child(fp)
		var fv := UiKit.vbox(4)
		fp.add_child(fv)
		for week in season.finals.get("weeks", []):
			fv.add_child(_week_block(week))
		if season.is_season_over():
			fv.add_child(UiKit.lbl("Premiers: %s" % GameDB.club_name(
					str(season.finals["premier"])), 17, UiKit.GOOD, true))
		else:
			var nxt := UiKit.lbl("Next: %s" % _next_finals_label(), 13, UiKit.MUTED)
			fv.add_child(nxt)


func _next_finals_label() -> String:
	var ms: Array = GameState.season.finals_week_matches()
	var parts := []
	for m in ms:
		if str(m["home"]) != "" and str(m["away"]) != "":
			parts.append("%s: %s v %s" % [m["tag"], GameDB.club_short(str(m["home"])),
					GameDB.club_short(str(m["away"]))])
	return "   ".join(parts)


func _week_block(week: Array) -> Control:
	var v := UiKit.vbox(2)
	for res in week:
		var h := UiKit.hbox(6)
		var s: Array = res["score"]
		var tag := UiKit.lbl("%-4s" % str(res.get("tag", "")), 12, UiKit.MUTED)
		tag.custom_minimum_size = Vector2(46, 0)
		h.add_child(tag)
		var b1 := UiKit.club_badge(str(res["home"]), 13)
		b1.custom_minimum_size = Vector2(120, 0)
		h.add_child(b1)
		h.add_child(_cell(UiKit.scoreline(int(res["goals"][0]), int(res["behinds"][0])),
				86, UiKit.TEXT, 13))
		h.add_child(_cell("d.", 26, UiKit.MUTED, 12))
		h.add_child(_cell(UiKit.scoreline(int(res["goals"][1]), int(res["behinds"][1])),
				86, UiKit.TEXT, 13))
		var b2 := UiKit.club_badge(str(res["away"]), 13)
		b2.custom_minimum_size = Vector2(120, 0)
		h.add_child(b2)
		if bool(res.get("decided_on_ladder", false)):
			h.add_child(UiKit.lbl("(level - higher seed advances)", 11, UiKit.MUTED))
		v.add_child(h)
	return v


func _header() -> Control:
	var h := UiKit.hbox(6)
	h.add_child(_cell("#", 34, UiKit.MUTED, 12))
	var c := UiKit.lbl("Club", 12, UiKit.MUTED)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(c)
	for t in [["P", 32], ["W", 32], ["L", 32], ["D", 32], ["PF", 52],
			["PA", 52], ["%", 58], ["Pts", 46]]:
		h.add_child(_cell(str(t[0]), int(t[1]), UiKit.MUTED, 12))
	return h


func _rows(rows: Array) -> Control:
	var v := UiKit.vbox(2)
	for i in rows.size():
		v.add_child(_row(rows[i], i + 1))
	return v


func _row(r: Dictionary, pos: int) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var mine: bool = str(r["code"]) == GameState.my_club
	sb.bg_color = Color(0.98, 0.82, 0.32, 0.13) if mine else \
			(Color(1, 1, 1, 0.045) if pos <= Season.FINALISTS else Color(0, 0, 0, 0))
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	sb.border_width_left = 3
	sb.border_color = UiKit.GOLD if mine else Color(0.45, 0.85, 0.48, 0.65)
	if pos > Season.FINALISTS and not mine:
		sb.border_width_left = 0
	p.add_theme_stylebox_override("panel", sb)

	var h := UiKit.hbox(6)
	p.add_child(h)
	var col := UiKit.GOLD if mine else UiKit.TEXT
	h.add_child(_cell(str(pos), 34, col, 14, mine))
	var badge := UiKit.club_badge(str(r["code"]), 14)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(badge)
	h.add_child(_cell(str(int(r["p"])), 32, col, 14))
	h.add_child(_cell(str(int(r["w"])), 32, col, 14))
	h.add_child(_cell(str(int(r["l"])), 32, col, 14))
	h.add_child(_cell(str(int(r["d"])), 32, col, 14))
	h.add_child(_cell(str(int(r["pf"])), 52, UiKit.MUTED, 13))
	h.add_child(_cell(str(int(r["pa"])), 52, UiKit.MUTED, 13))
	h.add_child(_cell("%.1f" % float(r["pct"]), 58, col, 13))
	h.add_child(_cell(str(int(r["pts"])), 46, col, 15, true))
	return p


func _cell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.lbl(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l
