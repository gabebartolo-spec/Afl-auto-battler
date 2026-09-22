extends Control
## Club selection + the serpentine league salary-cap draft.

const BOARD_CAP := 400

var _draft: Draft = null
var _club := ""
var _phase := "club"

var _role := ""
var _club_filter := ""
var _search := ""
var _sort := "overall"

var _root: VBoxContainer
var _status: Label
var _board_box: VBoxContainer
var _mine_box: VBoxContainer
var _board_info: Label
var _role_labels := {}
var _finish_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.draft == null:
		GameState.begin_draft()
	_draft = GameState.draft

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_root = UiKit.vbox(10)
	margin.add_child(_root)
	_show_club_select()


# ---------------------------------------------------------------------------
# Phase 1: pick the club you take over
# ---------------------------------------------------------------------------
func _show_club_select() -> void:
	_phase = "club"
	for c in _root.get_children():
		c.queue_free()

	_root.add_child(UiKit.top_bar("Choose Your Club", true))
	_root.add_child(UiKit.subtitle(
			"Every club starts empty. The draft order is random, then snakes each round."))

	var grid := GridContainer.new()
	grid.columns = _grid_columns()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sc := UiKit.scroll(grid)
	_root.add_child(sc)

	for code in GameDB.CLUB_ORDER:
		var cols: Array = GameDB.club_colours(code)
		var b := Button.new()
		b.custom_minimum_size = Vector2(210, 92)
		var sb := StyleBoxFlat.new()
		sb.bg_color = cols[0]
		sb.set_corner_radius_all(9)
		sb.set_content_margin_all(10)
		sb.border_color = cols[2]
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = cols[0].lightened(0.16)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sb.duplicate())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var inner := UiKit.vbox(3)
		b.add_child(inner)
		var nm := UiKit.lbl(GameDB.club_name(code), 16, UiKit.readable_on(cols[0]), true)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		inner.add_child(nm)
		var draft_pos := _draft.draft_order.find(code) + 1
		var st := UiKit.lbl("0 players   -   pick %d in the random order" % draft_pos,
				12, Color(1, 1, 1, 0.78))
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		inner.add_child(st)
		var gnd := UiKit.lbl(GameDB.club(code).get("ground", ""), 11,
				Color(1, 1, 1, 0.62))
		gnd.autowrap_mode = TextServer.AUTOWRAP_OFF
		inner.add_child(gnd)

		b.pressed.connect(_on_club_chosen.bind(code))
		grid.add_child(b)


func _grid_columns() -> int:
	var w := UiKit.view_width(self)
	if w < 700.0:
		return 2
	if w < 1050.0:
		return 3
	return 4


func _club_strengths() -> Dictionary:
	var out := {}
	for code in GameDB.CLUB_ORDER:
		var sq := Squad.new(GameDB.club_name(code), GameDB.club_list(code), false, code)
		out[code] = sq.strength()
	return out


func _on_club_chosen(code: String) -> void:
	_club = code
	_draft.start_for_user(code)
	_show_board()


# ---------------------------------------------------------------------------
# Phase 2: the draft board
# ---------------------------------------------------------------------------
func _show_board() -> void:
	_phase = "board"
	for c in _root.get_children():
		c.queue_free()

	var cols: Array = GameDB.club_colours(_club)
	var bar := UiKit.top_bar("%s - Build Your List" % GameDB.club_name(_club), true)
	_root.add_child(bar)

	_status = UiKit.lbl("", 15, UiKit.GOLD, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_status)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(split)

	# --- left: your list ----------------------------------------------------
	var left := UiKit.panel(UiKit.PANEL, 12)
	left.custom_minimum_size = Vector2(330, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var lv := UiKit.vbox(8)
	left.add_child(lv)

	lv.add_child(UiKit.lbl("Your List", 18, UiKit.GOLD, true))
	var role_row := UiKit.hbox(6)
	lv.add_child(role_row)
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		var l := UiKit.lbl("", 12, UiKit.MUTED)
		role_row.add_child(l)
		_role_labels[r] = l

	_mine_box = UiKit.vbox(4)
	lv.add_child(UiKit.scroll(_mine_box))

	_finish_btn = UiKit.btn("Start Season", 17, true)
	_finish_btn.pressed.connect(_on_finish)
	lv.add_child(_finish_btn)

	# --- right: board -------------------------------------------------------
	var right := UiKit.panel(UiKit.PANEL, 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var rv := UiKit.vbox(8)
	right.add_child(rv)

	rv.add_child(_filter_row())
	_board_info = UiKit.lbl("", 12, UiKit.MUTED)
	rv.add_child(_board_info)
	_board_box = UiKit.vbox(3)
	rv.add_child(UiKit.scroll(_board_box))

	_refresh()


func _filter_row() -> Control:
	var h := UiKit.hbox(8)

	var role_opt := OptionButton.new()
	role_opt.add_item("All positions", 0)
	var i := 1
	for r in ["RUCK", "MID", "DEF", "FWD"]:
		role_opt.add_item(UiKit.ROLE_LABEL[r], i)
		i += 1
	role_opt.item_selected.connect(func(idx: int):
		_role = "" if idx == 0 else ["RUCK", "MID", "DEF", "FWD"][idx - 1]
		_refresh())
	h.add_child(role_opt)

	var club_opt := OptionButton.new()
	club_opt.add_item("All clubs", 0)
	var j := 1
	for code in GameDB.CLUB_ORDER:
		club_opt.add_item(GameDB.club_short(code), j)
		j += 1
	club_opt.item_selected.connect(func(idx: int):
		_club_filter = "" if idx == 0 else GameDB.CLUB_ORDER[idx - 1]
		_refresh())
	h.add_child(club_opt)

	var sort_opt := OptionButton.new()
	var sorts := [["overall", "Best first"], ["value", "Cheapest first"],
			["goals", "Most goals"], ["disposals", "Most disposals"], ["name", "Name"]]
	for k in range(sorts.size()):
		sort_opt.add_item(sorts[k][1], k)
	sort_opt.item_selected.connect(func(idx: int):
		_sort = sorts[idx][0]
		_refresh())
	h.add_child(sort_opt)

	var se := LineEdit.new()
	se.placeholder_text = "Search player..."
	se.custom_minimum_size = Vector2(190, 40)
	se.text_changed.connect(func(t: String):
		_search = t
		_refresh())
	h.add_child(se)

	var avail := UiKit.btn("Available only", 13)
	avail.toggle_mode = true
	avail.button_pressed = true
	avail.custom_minimum_size = Vector2(0, 40)
	avail.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	avail.toggled.connect(func(_on: bool): _refresh())
	avail.name = "AvailToggle"
	h.add_child(avail)

	h.add_child(UiKit.lbl("", 12))
	return h


func _avail_only() -> bool:
	var t := _find_toggle()
	return t != null and t.button_pressed


func _find_toggle() -> Button:
	var row := _root.find_child("AvailToggle", true, false)
	return row as Button


func _refresh() -> void:
	if _phase != "board":
		return
	_refresh_status()
	_refresh_mine()
	_refresh_board()


func _refresh_status() -> void:
	var rc := _draft.role_counts()
	var prefix := "Draft complete"
	if not _draft.is_finished():
		prefix = "Round %d/%d, pick %d/%d - %s to choose" % [
				_draft.current_round(), _draft.target_size, _draft.pick_number_in_round(),
				_draft.clubs.size(), GameDB.club_short(_draft.current_club())]
	_status.text = "%s   -   Cap %d / %d spent   -   %d of %d signed   -   %d left" % [
			prefix, _draft.spent(), _draft.budget, _draft.count(), _draft.target_size,
			_draft.remaining()]
	for r in _role_labels:
		_role_labels[r].text = "%s %d" % [UiKit.ROLE_SHORT[r], rc[r]]
	var ok := _draft.is_valid() and _draft.is_finished()
	if _finish_btn != null:
		_finish_btn.disabled = not ok
	_status.add_theme_color_override("font_color",
			UiKit.GOOD if ok else UiKit.GOLD)


func _refresh_mine() -> void:
	for c in _mine_box.get_children():
		c.queue_free()
	for id in _draft.order:
		_mine_box.add_child(_picked_row(_draft.picked[id]))
	if _draft.count() == 0:
		var empty := UiKit.lbl("No one signed yet. Pick from the board.",
				13, UiKit.MUTED)
		_mine_box.add_child(empty)


func _picked_row(p: Dictionary) -> Control:
	var h := UiKit.hbox(6)
	var cols: Array = GameDB.club_colours(str(p["club"]))
	h.add_child(UiKit.chip(str(p["num"]), cols[0]))
	var nm := UiKit.lbl(str(p["name"]), 13)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	h.add_child(UiKit.lbl(UiKit.ROLE_SHORT[str(p["role"])], 11, UiKit.MUTED))
	h.add_child(UiKit.lbl(str(int(p["overall"])), 13, UiKit.GOLD, true))
	h.add_child(UiKit.lbl("$%d" % int(p["value"]), 12, UiKit.MUTED))
	var pick_no := UiKit.lbl("#%d" % (_draft.order.find(str(p["id"])) + 1), 11, UiKit.MUTED)
	pick_no.custom_minimum_size = Vector2(34, 0)
	pick_no.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pick_no)
	return h


func _refresh_board() -> void:
	for c in _board_box.get_children():
		c.queue_free()
	var rows := _draft.board(_role, _club_filter, _search, _sort, _avail_only())
	_board_info.text = "%d players match   -   %d drafted league-wide" % [rows.size(), _draft.picked.size()]
	var shown := mini(BOARD_CAP, rows.size())
	if shown < rows.size():
		_board_info.text += "  -  showing first %d (use filters to narrow)" % shown
	for i in range(shown):
		_board_box.add_child(_board_row(rows[i]))


func _board_row(p: Dictionary) -> Control:
	var h := UiKit.hbox(6)
	var cols: Array = GameDB.club_colours(str(p["club"]))
	h.add_child(UiKit.chip(str(p["num"]), cols[0]))

	var info := UiKit.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var nm := UiKit.lbl(str(p["name"]), 14)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(nm)

	var detail := "%s  -  %d gm  -  %.1f disp  -  %d gl  -  src %d" % [
			GameDB.club_short(str(p["club"])), int(p["gm"]),
			(p["di"] / maxf(1.0, p["gm"])), int(p["gl"]), int(p["src"])]
	var dl := UiKit.lbl(detail, 11, UiKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_OFF
	dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(dl)

	h.add_child(UiKit.lbl(UiKit.ROLE_SHORT[str(p["role"])], 12, UiKit.MUTED))
	var ov := UiKit.lbl(str(int(p["overall"])), 16, UiKit.GOLD, true)
	ov.custom_minimum_size = Vector2(34, 0)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(ov)
	var cost := UiKit.lbl("$%d" % int(p["value"]), 13, UiKit.TEXT)
	cost.custom_minimum_size = Vector2(34, 0)
	h.add_child(cost)

	var signed: bool = _draft.has(str(p["id"]))
	var can_pick := _draft.can_pick_player(p)
	var label := "Pick"
	if signed:
		label = "Drafted"
	elif not _draft.is_user_turn():
		label = "Waiting"
	var b := UiKit.btn(label, 13, can_pick)
	b.custom_minimum_size = Vector2(88, 38)
	b.disabled = not can_pick
	b.pressed.connect(func():
		if _draft.has(str(p["id"])):
			_draft.unpick(str(p["id"]))
		else:
			_draft.pick(p)
		_refresh())
	h.add_child(b)
	return h


func _on_finish() -> void:
	if not _draft.is_finished():
		_status.text = "The league draft is still running. Make your next pick to continue."
		_status.add_theme_color_override("font_color", UiKit.BAD)
		return
	if _draft.count() < _draft.target_size:
		_status.text = "Sign %d more player(s) to fill the list of %d." % [
				_draft.target_size - _draft.count(), _draft.target_size]
		_status.add_theme_color_override("font_color", UiKit.BAD)
		return
	if _draft.spent() > _draft.budget:
		_status.text = "Over the cap."
		_status.add_theme_color_override("font_color", UiKit.BAD)
		return
	if _draft.count_by_role("RUCK") < 2:
		_status.text = "Sign at least 2 ruckmen - you need someone to contest centre bounces."
		_status.add_theme_color_override("font_color", UiKit.BAD)
		return
	GameState.start_season(_club, _draft.list())
	Router.go("hub")
