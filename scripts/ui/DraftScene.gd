extends Control
## One draft, two layouts: pool + activity side by side in landscape; four
## focused tabs in portrait. The model owns every pick, never the view tree.

const ROLES := ["DEF", "MID", "RUCK", "FWD"]
const ROLE_TABS := [["", "ALL"], ["DEF", "DEFS"], ["MID", "MIDS"], ["RUCK", "RUCKS"], ["FWD", "FWDS"]]
const SORTS := [["overall", "Best rated"], ["value", "Lowest cost"],
	["goals", "Most goals"], ["disposals", "Most disposals"], ["name", "Name A–Z"]]
const PAGE_SIZE := 60

var _draft: Draft
var _club := ""
var _phase := "club"
var _role := ""
var _club_filter := ""
var _search := ""
var _sort := "overall"
var _available_only := true
var _advanced_open := false
var _history_club := ""
var _shown := PAGE_SIZE
var _history_shown := PAGE_SIZE
var _tab := "pool"
var _side_tab := "picks"
var _wide := false
var _short := false
var _layout_key := ""
var _resize_queued := false
var _last_batch_start := 0

var _margin: MarginContainer
var _root: VBoxContainer
var _status: Label
var _round_info: Label
var _cap: Label
var _role_labels := {}
var _role_buttons := {}
var _need_labels := {}
var _main_tabs: HBoxContainer
var _side_tabs: HBoxContainer
var _pool_panel: PanelContainer
var _activity_panel: PanelContainer
var _history_view: VBoxContainer
var _squad_view: VBoxContainer
var _order_view: VBoxContainer
var _role_tabs: HBoxContainer
var _advanced: VBoxContainer
var _search_field: LineEdit
var _search_timer: Timer
var _board_info: Label
var _pool_total: Label
var _board_box: VBoxContainer
var _history_box: VBoxContainer
var _history_info: Label
var _mine_box: VBoxContainer
var _order_box: VBoxContainer
var _board_scroll: ScrollContainer
var _history_scroll: ScrollContainer
var _mine_scroll: ScrollContainer
var _order_scroll: ScrollContainer
var _ticker: Button
var _next_picks: Label
var _finish_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.draft == null:
		GameState.begin_draft()
	_draft = GameState.draft
	_club = _draft.user_club
	_phase = "club" if _club.is_empty() else "board"
	for i in range(_draft.pick_history.size() - 1, -1, -1):
		if str(_draft.pick_history[i]["club"]) == _club:
			_last_batch_start = int(_draft.pick_history[i]["pick"])
			break

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_root = UiKit.vbox(8)
	_margin.add_child(_root)
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.12
	_search_timer.timeout.connect(func(): _refresh_board(true))
	add_child(_search_timer)
	get_viewport().size_changed.connect(_on_resize)
	_build_layout()


func _on_resize() -> void:
	if not _resize_queued:
		_resize_queued = true
		_reflow.call_deferred()


func _reflow() -> void:
	_resize_queued = false
	if not is_inside_tree():
		return
	_apply_margins()
	if _layout_signature() != _layout_key:
		var scrolls := _scroll_positions()
		var search_focus := is_instance_valid(_search_field) and _search_field.has_focus()
		var caret := _search_field.caret_column if search_focus else 0
		_build_layout()
		_restore_scrolls.call_deferred(scrolls)
		if search_focus and is_instance_valid(_search_field):
			_search_field.grab_focus()
			_search_field.caret_column = caret


func _usable_size() -> Vector2:
	var safe := ScreenLayout.safe_insets()
	return Vector2(UiKit.view_width(self) - safe.x - safe.z,
			UiKit.view_height(self) - safe.y - safe.w)


func _layout_signature() -> String:
	var area := _usable_size()
	return "%s/%s/%d" % [area.x >= 760.0 and area.x > area.y,
			area.y < 680.0, _grid_columns()]


func _build_layout() -> void:
	var area := _usable_size()
	_wide = area.x >= 760.0 and area.x > area.y
	_short = area.y < 680.0
	_layout_key = _layout_signature()
	_apply_margins()
	_root.add_theme_constant_override("separation", 6 if _short else 10)
	if _phase == "club":
		_show_club_select()
	else:
		_show_board()


func _apply_margins() -> void:
	var safe := ScreenLayout.safe_insets()
	var pad := 10 if UiKit.view_width(self) < 600.0 or UiKit.view_height(self) < 680.0 else 18
	_margin.add_theme_constant_override("margin_left", pad + ceili(safe.x))
	_margin.add_theme_constant_override("margin_top", 8 + ceili(safe.y))
	_margin.add_theme_constant_override("margin_right", pad + ceili(safe.z))
	_margin.add_theme_constant_override("margin_bottom", 8 + ceili(safe.w))


func _scroll_positions() -> Array:
	var values := []
	for sc in [_board_scroll, _history_scroll, _mine_scroll, _order_scroll]:
		values.append(sc.scroll_vertical if is_instance_valid(sc) else 0)
	return values


func _restore_scrolls(values: Array) -> void:
	var scrolls := [_board_scroll, _history_scroll, _mine_scroll, _order_scroll]
	for i in range(scrolls.size()):
		if is_instance_valid(scrolls[i]):
			scrolls[i].scroll_vertical = int(values[i])


# ---------------------------------------------------------------------------
# Club selection
# ---------------------------------------------------------------------------
func _show_club_select() -> void:
	UiKit.clear(_root)
	_root.add_child(_header("CHOOSE YOUR CLUB", "2026  /  A fresh start for all 18 clubs"))
	_root.add_child(UiKit.lbl(
			"One player pool. One salary cap. The whole league re-drafts in a random snake order.",
			16, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.name = "ClubGrid"
	grid.columns = _grid_columns()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_root.add_child(UiKit.scroll(grid))
	for code in GameDB.CLUB_ORDER:
		var b := UiKit.btn("", 16)
		b.name = "Choose_" + code
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := MarginContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]:
			inner.add_theme_constant_override("margin_" + edge, 12)
		b.add_child(inner)
		var v := UiKit.vbox(5)
		inner.add_child(v)
		var row := UiKit.hbox(8)
		v.add_child(row)
		row.add_child(UiKit.club_badge(code, 13, true))
		var pick_label := UiKit.lbl("PICK #%d" % (_draft.draft_order.find(code) + 1), 12, UiKit.GOLD)
		pick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pick_label)
		v.add_child(UiKit.lbl(GameDB.club_name(code), 18, UiKit.TEXT, true))
		v.add_child(UiKit.ellipsis(str(GameDB.club(code).get("ground", "")), 12, UiKit.MUTED))
		_ignore_mouse(inner)
		b.pressed.connect(_on_club_chosen.bind(code))
		grid.add_child(b)
	_root.add_child(UiKit.subtitle("Every club drafts %d players. Your first pick is shown on each card." % _draft.target_size))


func _grid_columns() -> int:
	var w := _usable_size().x
	if w < 360.0:
		return 1
	if w < 760.0:
		return 2
	return 3 if w < 1060.0 else 4


func _on_club_chosen(code: String) -> void:
	_club = code
	_phase = "board"
	_last_batch_start = _draft.pick_history.size()
	_draft.start_for_user(code)
	_show_board()


func _header(title_text: String, sub: String) -> Control:
	var h := UiKit.hbox(10)
	var back := UiKit.btn("‹", 26)
	back.name = "BackToMenu"
	back.custom_minimum_size = Vector2(44, 44)
	back.tooltip_text = "Back to menu. Your draft stays available to resume."
	back.pressed.connect(func(): Router.replace("main"))
	h.add_child(back)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiKit.heading(title_text, 26 if _short else 30))
	if not _short:
		v.add_child(UiKit.ellipsis(sub, 12, UiKit.MUTED))
	if not _club.is_empty():
		h.add_child(UiKit.club_badge(_club, 14, true))
	return h


# ---------------------------------------------------------------------------
# Persistent summary and responsive workspace
# ---------------------------------------------------------------------------
func _show_board() -> void:
	_search_timer.stop()
	UiKit.clear(_root)
	_role_labels.clear()
	_role_buttons.clear()
	_need_labels.clear()
	if _short:
		_root.add_child(_compact_header())
	else:
		_root.add_child(_header("LEAGUE DRAFT", "2026  /  18 clubs  /  Snake draft"))
		_root.add_child(_summary())
	_root.add_child(_position_counts())

	_ticker = UiKit.btn("", 13)
	_ticker.name = "LatestRivalPick"
	_ticker.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ticker.clip_text = true
	_ticker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ticker.custom_minimum_size.y = 44
	_ticker.add_theme_stylebox_override("normal", UiKit.style(UiKit.INK, 8, 6))
	_ticker.pressed.connect(func(): _select_tab("picks"))
	_root.add_child(_ticker)
	# On short landscape displays, show the ticker inside the activity pane
	# instead of spending an entire row above the player pool.
	_ticker.visible = not _short

	_main_tabs = UiKit.hbox(3)
	_main_tabs.visible = not _wide
	_root.add_child(_main_tabs)
	var body := UiKit.hbox(12)
	body.name = "DraftWorkspace"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(body)
	_pool_panel = _build_pool()
	_pool_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_pool_panel)
	_activity_panel = _build_activity()
	_activity_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _wide:
		_activity_panel.custom_minimum_size.x = clampf(UiKit.view_width(self) * 0.29, 276, 360)
	else:
		_activity_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_activity_panel)
	_root.add_child(_footer())
	_refresh()
	_update_visibility()


func _compact_header() -> Control:
	var h := UiKit.hbox(10)
	var back := UiKit.btn("‹", 26)
	back.custom_minimum_size.x = 44
	back.pressed.connect(func(): Router.replace("main"))
	h.add_child(back)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_status = UiKit.lbl("", 17, UiKit.GOLD, true)
	_status.name = "DraftStatus"
	v.add_child(_status)
	_round_info = UiKit.lbl("", 12, UiKit.MUTED)
	v.add_child(_round_info)
	_cap = UiKit.line("", 13, UiKit.TEXT, true)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_cap)
	return h


func _summary() -> Control:
	var p := UiKit.panel(UiKit.PANEL, 9, 7)
	var h := UiKit.hbox(12)
	p.add_child(h)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_status = UiKit.lbl("", 17, UiKit.GOLD, true)
	_status.name = "DraftStatus"
	v.add_child(_status)
	_round_info = UiKit.lbl("", 12, UiKit.MUTED)
	v.add_child(_round_info)
	_cap = UiKit.line("", 14, UiKit.TEXT, true)
	_cap.name = "SalaryCap"
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_cap)
	return p


func _position_counts() -> Control:
	var h := UiKit.hbox(6)
	var targets := _draft.position_targets()
	for role in ROLES:
		var b := UiKit.btn("", 14)
		b.name = "Position_" + role
		_role_buttons[role] = b
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52 if _short else 62)
		var colour: Color = UiKit.ROLE_COLOUR[role]
		b.add_theme_stylebox_override("normal", UiKit.style(Color(colour, 0.08), 6, 6))
		var v := UiKit.vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 6
		v.offset_right = -6
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var count_label := UiKit.line("", 15 if _usable_size().x < 360 else 17, colour, true)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(count_label)
		_role_labels[role] = count_label
		var need := UiKit.line("", 11, UiKit.MUTED, true)
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(need)
		_need_labels[role] = need
		b.tooltip_text = "%s: aim for %d. Tap to filter the pool.\n" % [UiKit.ROLE_LABEL[role], targets[role]] \
				+ "Coverage targets follow the match-day positions; only 2 rucks are mandatory."
		_ignore_mouse(v)
		b.pressed.connect(func():
			_select_tab("pool")
			_set_role("" if _role == role else role))
		h.add_child(b)
	return h


func _footer() -> Control:
	var p := UiKit.panel(UiKit.INK, 8, 6)
	var h := UiKit.hbox(10)
	p.add_child(h)
	_next_picks = UiKit.lbl("", 12, UiKit.MUTED)
	_next_picks.name = "UpcomingPicks"
	_next_picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_next_picks)
	_finish_btn = UiKit.btn("START SEASON", 14, true)
	_finish_btn.name = "StartSeason"
	_finish_btn.pressed.connect(_on_finish)
	h.add_child(_finish_btn)
	return p


func _select_tab(key: String) -> void:
	_tab = key
	if key != "pool":
		_side_tab = key
	_update_visibility()


func _update_visibility() -> void:
	_pool_panel.visible = _wide or _tab == "pool"
	_activity_panel.visible = _wide or _tab != "pool"
	var active := _side_tab if _wide else _tab
	_history_view.visible = active == "picks"
	_squad_view.visible = active == "squad"
	_order_view.visible = active == "order"
	_refresh_tabs()


func _refresh_tabs() -> void:
	UiKit.clear(_main_tabs)
	UiKit.clear(_side_tabs)
	for item in [["pool", "Pool"], ["picks", "Picks"], ["squad", "My list"], ["order", "Order"]]:
		var key: String = item[0]
		var label := str(item[1])
		if key == "picks" and not _draft.pick_history.is_empty():
			label += " (%d)" % _draft.pick_history.size()
		var b := UiKit.tab(label, _tab == key)
		b.name = "Tab_" + key
		b.pressed.connect(_select_tab.bind(key))
		_main_tabs.add_child(b)
		if key != "pool":
			var side := UiKit.tab(label, _side_tab == key)
			side.name = "SideTab_" + key
			side.pressed.connect(_select_tab.bind(key))
			_side_tabs.add_child(side)


# ---------------------------------------------------------------------------
# Draft pool. Short screens scroll the filters with the rows, rather than
# leaving only a few pixels for players below a fixed filter toolbar.
# ---------------------------------------------------------------------------
func _build_pool() -> PanelContainer:
	var panel := UiKit.panel(UiKit.PANEL, 10, 10)
	panel.name = "DraftPool"
	var v := UiKit.vbox(8)
	panel.add_child(v)
	var filters := _filters()
	_board_box = UiKit.vbox(0)
	_board_box.name = "PlayerRows"
	if _short:
		var content := UiKit.vbox(8)
		content.add_child(filters)
		content.add_child(_board_box)
		_board_scroll = UiKit.scroll(content)
		v.add_child(_board_scroll)
	else:
		v.add_child(filters)
		_board_scroll = UiKit.scroll(_board_box)
		v.add_child(_board_scroll)
	_board_scroll.name = "PoolScroll"
	return panel


func _filters() -> Control:
	var v := UiKit.vbox(6)
	var title_row := UiKit.hbox(8)
	v.add_child(title_row)
	title_row.visible = not _short
	var title_label := UiKit.heading("DRAFT POOL", 25)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	_pool_total = UiKit.line("", 12, UiKit.MUTED)
	title_row.add_child(_pool_total)
	_role_tabs = UiKit.hbox(2)
	_role_tabs.visible = not _short
	v.add_child(_role_tabs)
	_refresh_role_tabs()

	var search_row := UiKit.hbox(6)
	v.add_child(search_row)
	_search_field = UiKit.search_field(_search)
	_search_field.name = "PlayerSearch"
	_search_field.text_changed.connect(func(text: String):
		_search = text
		_shown = PAGE_SIZE
		_search_timer.start())
	search_row.add_child(_search_field)
	var filters := UiKit.btn("Filters", 13)
	filters.name = "MoreFilters"
	filters.toggle_mode = true
	filters.button_pressed = _advanced_open
	filters.toggled.connect(func(on: bool):
		_advanced_open = on
		_advanced.visible = on)
	search_row.add_child(filters)

	_advanced = UiKit.vbox(6)
	_advanced.visible = _advanced_open
	v.add_child(_advanced)
	var opts := UiKit.hbox(6)
	_advanced.add_child(opts)
	var clubs := UiKit.option()
	clubs.name = "OriginClubFilter"
	clubs.add_item("All original clubs")
	for code in GameDB.CLUB_ORDER:
		clubs.add_item(GameDB.club_name(code))
	clubs.select(0 if _club_filter.is_empty() else GameDB.CLUB_ORDER.find(_club_filter) + 1)
	clubs.item_selected.connect(func(idx: int):
		_club_filter = "" if idx == 0 else GameDB.CLUB_ORDER[idx - 1]
		_shown = PAGE_SIZE
		_refresh_board(true))
	opts.add_child(clubs)
	var sort_option := UiKit.option()
	sort_option.name = "SortPlayers"
	for i in range(SORTS.size()):
		sort_option.add_item(str(SORTS[i][1]))
		if str(SORTS[i][0]) == _sort:
			sort_option.select(i)
	sort_option.item_selected.connect(func(idx: int):
		_sort = str(SORTS[idx][0])
		_shown = PAGE_SIZE
		_refresh_board(true))
	opts.add_child(sort_option)
	var avail := UiKit.btn("Available only", 14)
	avail.name = "AvailableOnly"
	avail.toggle_mode = true
	avail.button_pressed = _available_only
	avail.toggled.connect(func(on: bool):
		_available_only = on
		_shown = PAGE_SIZE
		_refresh_board(true))
	_advanced.add_child(avail)
	_board_info = UiKit.lbl("", 12, UiKit.MUTED)
	v.add_child(_board_info)
	return v


func _refresh_role_tabs() -> void:
	for role in _role_buttons:
		var colour: Color = UiKit.ROLE_COLOUR[role]
		_role_buttons[role].add_theme_stylebox_override("normal", UiKit.style(
				Color(colour, 0.14 if _role == role else 0.08), 6, 6,
				colour if _role == role else UiKit.LINE))
	UiKit.clear(_role_tabs)
	for item in ROLE_TABS:
		var key: String = item[0]
		var b := UiKit.tab(str(item[1]), _role == key)
		b.name = "Filter_" + ("ALL" if key.is_empty() else key)
		b.pressed.connect(_set_role.bind(key))
		_role_tabs.add_child(b)


func _set_role(role: String) -> void:
	_role = role
	_shown = PAGE_SIZE
	_refresh_role_tabs()
	_refresh_board(true)


func _refresh_board(reset_scroll := false) -> void:
	if _phase != "board" or not is_instance_valid(_board_box):
		return
	UiKit.clear(_board_box)
	var rows := _draft.board(_role, _club_filter, _search.strip_edges(), _sort, _available_only)
	_pool_total.text = "%d AVAILABLE" % (_draft.pool.size() - _draft.picked.size())
	var sort_label := ""
	for sort_entry in SORTS:
		if str(sort_entry[0]) == _sort:
			sort_label = str(sort_entry[1]).to_lower()
	var role_text := "" if _role.is_empty() else _role + " "
	_board_info.text = "%d %s%s · %s" % [rows.size(), role_text,
			"available" if _available_only else "players", sort_label]
	if not _club_filter.is_empty():
		_board_info.text += " · " + GameDB.club_short(_club_filter)
	var shown := mini(_shown, rows.size())
	for i in range(shown):
		_board_box.add_child(_player_row(rows[i]))
	if rows.is_empty():
		_board_box.add_child(UiKit.lbl("No players match these filters.", 17, UiKit.TEXT, true))
		_board_box.add_child(UiKit.lbl("Try another position, club or player name.", 14, UiKit.MUTED))
		var reset := UiKit.btn("Clear filters", 14)
		reset.pressed.connect(_clear_filters)
		_board_box.add_child(reset)
	elif shown < rows.size():
		var more := UiKit.btn("Show more  ·  %d of %d" % [shown, rows.size()], 14)
		more.name = "MorePlayers"
		more.pressed.connect(func():
			_shown += PAGE_SIZE
			_refresh_board())
		_board_box.add_child(more)
	if reset_scroll:
		_board_scroll.set_deferred("scroll_vertical", 0)


func _clear_filters() -> void:
	_role = ""
	_club_filter = ""
	_search = ""
	_sort = "overall"
	_available_only = true
	_shown = PAGE_SIZE
	_show_board()


func _player_row(p: Dictionary) -> Control:
	var row := _row_panel(false)
	row.name = "Player_" + str(p["id"])
	var h := UiKit.hbox(8)
	row.add_child(h)
	var role := str(p["role"])
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiKit.ellipsis(GameDB.player_display_name(p), 17, UiKit.TEXT, true))
	var taken := _draft.has(str(p["id"]))
	var detail := "%s · $%d · %d OVR" % [GameDB.club_short(str(p["club"])), int(p["value"]), int(p["overall"])]
	if taken:
		var entry := _draft.pick_details(str(p["id"]))
		detail = "#%d to %s · %d OVR" % [int(entry.get("pick", 0)),
				GameDB.club_short(_draft.drafted_by(str(p["id"]))), int(p["overall"])]
	info.add_child(UiKit.ellipsis(detail, 13, UiKit.MUTED))
	var can_pick := _draft.can_pick_player(p)
	var text := "+ " + role
	var reason := "Draft %s for $%d" % [GameDB.player_display_name(p), int(p["value"])]
	if taken:
		text = "TAKEN"
		reason = "Drafted by %s at pick #%d" % [GameDB.club_name(_draft.drafted_by(str(p["id"]))),
				int(_draft.pick_details(str(p["id"])).get("pick", 0))]
	elif not _draft.is_user_turn():
		text = "CLOSED" if _draft.is_finished() else "WAIT"
		reason = "The draft is complete." if _draft.is_finished() else "Waiting for your next turn."
	elif not can_pick:
		text = "CAP" if int(p["value"]) > _draft.remaining() - (_draft.target_size - _draft.count() - 1) else "RUCK"
		reason = "Not enough cap after reserving $1 for each remaining place." if text == "CAP" \
				else "Your remaining places must be rucks to meet the two-ruck requirement."
	var b := UiKit.btn(text, 13)
	b.name = "Pick_" + str(p["id"])
	b.custom_minimum_size = Vector2(66, 44)
	b.disabled = not can_pick
	b.tooltip_text = reason
	if can_pick:
		b.add_theme_color_override("font_color", UiKit.TEXT)
		b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL, 6, 5, Color("6c5142")))
	b.pressed.connect(_on_pick.bind(p))
	h.add_child(b)
	row.tooltip_text = "%s · %s\n%d games · %.1f disposals/game · %d goals\n%s" % [
		GameDB.player_display_name(p), GameDB.club_name(str(p["club"])), int(p["gm"]),
		float(p["di"]) / maxf(1.0, float(p["gm"])), int(p["gl"]), reason]
	return row


func _on_pick(player: Dictionary) -> void:
	_last_batch_start = _draft.pick_history.size()
	if _draft.pick(player):
		_refresh()


# ---------------------------------------------------------------------------
# League activity: every selection, your list, and the current snake round.
# ---------------------------------------------------------------------------
func _build_activity() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, 10, 10)
	p.name = "DraftActivity"
	var v := UiKit.vbox(8)
	p.add_child(v)
	_side_tabs = UiKit.hbox(2)
	_side_tabs.visible = _wide
	v.add_child(_side_tabs)

	_history_view = UiKit.vbox(6)
	_history_view.name = "PickLog"
	_history_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_history_view)
	var head := UiKit.hbox(8)
	_history_view.add_child(head)
	var title_label := UiKit.heading("PICK LOG", 25)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	_history_info = UiKit.line("", 12, UiKit.MUTED)
	head.add_child(_history_info)
	var clubs := UiKit.option()
	clubs.name = "PickLogClubFilter"
	clubs.add_item("All clubs · newest first")
	for code in GameDB.CLUB_ORDER:
		clubs.add_item(GameDB.club_name(code) + (" (you)" if code == _club else ""))
	clubs.select(0 if _history_club.is_empty() else GameDB.CLUB_ORDER.find(_history_club) + 1)
	clubs.item_selected.connect(func(idx: int):
		_history_club = "" if idx == 0 else GameDB.CLUB_ORDER[idx - 1]
		_history_shown = PAGE_SIZE
		_refresh_history()
		_history_scroll.set_deferred("scroll_vertical", 0))
	_history_view.add_child(clubs)
	_history_box = UiKit.vbox(4)
	_history_box.name = "PickLogRows"
	if _short:
		# Filters scroll with the log on low-height screens as well.
		_history_view.remove_child(head)
		_history_view.remove_child(clubs)
		var content := UiKit.vbox(6)
		head.visible = false
		content.add_child(head)
		content.add_child(clubs)
		content.add_child(_history_box)
		_history_scroll = UiKit.scroll(content)
	else:
		_history_scroll = UiKit.scroll(_history_box)
	_history_view.add_child(_history_scroll)

	_squad_view = UiKit.vbox(6)
	_squad_view.name = "MySquad"
	_squad_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_squad_view)
	_squad_view.add_child(UiKit.heading("YOUR LIST", 25))
	_mine_box = UiKit.vbox(5)
	_mine_scroll = UiKit.scroll(_mine_box)
	_squad_view.add_child(_mine_scroll)

	_order_view = UiKit.vbox(6)
	_order_view.name = "DraftOrder"
	_order_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_order_view)
	_order_view.add_child(UiKit.heading("DRAFT ORDER", 25))
	_order_box = UiKit.vbox(4)
	_order_scroll = UiKit.scroll(_order_box)
	_order_view.add_child(_order_scroll)
	return p


func _refresh_history() -> void:
	UiKit.clear(_history_box)
	var entries := []
	for i in range(_draft.pick_history.size() - 1, -1, -1):
		var entry: Dictionary = _draft.pick_history[i]
		if _history_club.is_empty() or str(entry["club"]) == _history_club:
			entries.append(entry)
	_history_info.text = "%d %s" % [entries.size(), "PICK" if entries.size() == 1 else "PICKS"]
	if entries.is_empty():
		_history_box.add_child(UiKit.lbl("No picks yet" if _history_club.is_empty() else "No picks for this club yet", 18, UiKit.TEXT, true))
		_history_box.add_child(UiKit.lbl(
				"Every selection appears here, including all 17 rivals. The most recent picks are first.", 15, UiKit.MUTED))
	for i in range(mini(_history_shown, entries.size())):
		_history_box.add_child(_history_row(entries[i]))
	if _history_shown < entries.size():
		var more := UiKit.btn("Earlier picks  ·  %d more" % (entries.size() - _history_shown), 14)
		more.name = "EarlierPicks"
		more.pressed.connect(func():
			_history_shown += PAGE_SIZE
			_refresh_history())
		_history_box.add_child(more)


func _entry_player_name(entry: Dictionary) -> String:
	return GameDB.player_display_name_by_id(str(entry.get("player_id", "")),
			str(entry.get("player_name", "Player")))


func _history_row(entry: Dictionary) -> Control:
	var mine := str(entry["club"]) == _club
	var p := _row_panel(mine)
	p.name = "HistoryPick_%d" % int(entry["pick"])
	var h := UiKit.hbox(7)
	p.add_child(h)
	var number := UiKit.line("#%d" % int(entry["pick"]), 13, UiKit.GOLD if mine else UiKit.MUTED)
	number.custom_minimum_size.x = 32
	h.add_child(number)
	var info := UiKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiKit.ellipsis(_entry_player_name(entry), 16, UiKit.TEXT, true))
	var club_row := UiKit.hbox(6)
	info.add_child(club_row)
	club_row.add_child(UiKit.club_badge(str(entry["club"]), 12, true))
	club_row.add_child(UiKit.ellipsis("YOUR PICK" if mine else "selected", 11, UiKit.GOLD if mine else UiKit.MUTED))
	h.add_child(UiKit.role_chip(str(entry["role"])))
	p.tooltip_text = "Pick #%d · Round %d\n%s drafted %s from %s\n%d OVR · $%d" % [
		entry["pick"], entry["round"], GameDB.club_name(str(entry["club"])), _entry_player_name(entry),
		GameDB.club_name(str(entry["source_club"])), entry["overall"], entry["value"]]
	return p


func _refresh_mine() -> void:
	UiKit.clear(_mine_box)
	_mine_box.add_child(UiKit.lbl("%d / %d signed · $%d of $%d spent" % [
		_draft.count(), _draft.target_size, _draft.spent(), _draft.budget], 15, UiKit.GOLD, true))
	_mine_box.add_child(UiKit.lbl(
			"Cover 5 DEF, 7 MID and 5 FWD for the ground. Carry at least 2 RUCK. The bench is flexible; other needs are guidance, not limits.",
			13, UiKit.MUTED))
	if _draft.count() == 0:
		_mine_box.add_child(UiKit.spacer(8))
		_mine_box.add_child(UiKit.lbl("Your list starts here.", 20, UiKit.TEXT, true))
		_mine_box.add_child(UiKit.lbl("Select a player from the pool. Tap a position counter above to find the cover you need.", 15, UiKit.MUTED))
		var pool := UiKit.btn("Explore the player pool", 15, true)
		pool.pressed.connect(func(): _select_tab("pool"))
		_mine_box.add_child(pool)
		return
	var counts := _draft.role_counts()
	for role in ROLES:
		_mine_box.add_child(UiKit.spacer(6))
		_mine_box.add_child(UiKit.lbl("%s  /  %d" % [str(UiKit.ROLE_LABEL[role]).to_upper(), counts[role]],
				13, UiKit.ROLE_COLOUR[role], true))
		for player in _draft.list():
			if str(player["role"]) == role:
				var entry := _draft.pick_details(str(player["id"]))
				var p := _row_panel(false)
				var v := UiKit.vbox(2)
				p.add_child(v)
				v.add_child(UiKit.ellipsis(GameDB.player_display_name(player), 16, UiKit.TEXT, true))
				v.add_child(UiKit.lbl("Pick #%d · %d OVR · $%d" % [
					int(entry.get("pick", 0)), int(player["overall"]), int(player["value"])], 12, UiKit.MUTED))
				_mine_box.add_child(p)


func _refresh_order() -> void:
	UiKit.clear(_order_box)
	var round_no := mini(_draft.current_round(), _draft.target_size)
	_order_box.add_child(UiKit.lbl("ROUND %d / %d · %s" % [round_no, _draft.target_size,
			"REVERSE" if round_no % 2 == 0 else "FORWARD"], 13, UiKit.GOLD, true))
	_order_box.add_child(UiKit.lbl("The order reverses each round. Highlighted club = you.", 13, UiKit.MUTED))
	var start := (round_no - 1) * _draft.clubs.size()
	for i in range(_draft.clubs.size()):
		var index := start + i
		var code := str(_draft.pick_sequence[index])
		var mine := code == _club
		var p := _row_panel(mine)
		var h := UiKit.hbox(7)
		p.add_child(h)
		var number := UiKit.line("#%d" % (index + 1), 13, UiKit.MUTED)
		number.custom_minimum_size.x = 34
		h.add_child(number)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var badge := UiKit.club_badge(code, 14, true)
		badge.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.add_child(badge)
		var description := "Up next" if index > _draft.pick_index else "ON THE CLOCK"
		if index < _draft.pick_history.size():
			description = _entry_player_name(_draft.pick_history[index])
		v.add_child(UiKit.ellipsis(description, 12, UiKit.MUTED))
		h.add_child(UiKit.line("%d/%d" % [_draft.count_for(code), _draft.target_size], 12, UiKit.GOLD if mine else UiKit.MUTED))
		_order_box.add_child(p)


# ---------------------------------------------------------------------------
# Refresh derived values after a real selection (the AI batch is synchronous).
# ---------------------------------------------------------------------------
func _refresh() -> void:
	_refresh_tabs()
	_refresh_status()
	_refresh_board()
	_refresh_history()
	_refresh_mine()
	_refresh_order()


func _refresh_status() -> void:
	var done := _draft.is_finished()
	_status.text = "DRAFT COMPLETE" if done else "YOUR PICK #%d" % (_draft.pick_index + 1)
	if not done and not _draft.is_user_turn():
		_status.text = "%s ON THE CLOCK" % GameDB.club_short(_draft.current_club()).to_upper()
	_round_info.text = "%d / %d signed · Round %d of %d" % [_draft.count(), _draft.target_size,
		mini(_draft.current_round(), _draft.target_size), _draft.target_size]
	if _short:
		_round_info.text = "%s · %d/%d signed · R%d/%d" % [_club, _draft.count(),
				_draft.target_size, mini(_draft.current_round(), _draft.target_size), _draft.target_size]
	_cap.text = "CAP LEFT  $%d\n$%d spent / $%d" % [_draft.remaining(), _draft.spent(), _draft.budget]
	var counts := _draft.role_counts()
	var needs := _draft.position_needs()
	for role in ROLES:
		_role_labels[role].text = "%s %d" % [role, counts[role]]
		_need_labels[role].text = "NEED +%d" % int(needs[role]) if int(needs[role]) > 0 else "COVERED"
		_need_labels[role].add_theme_color_override("font_color", UiKit.BAD if int(needs[role]) > 0 else UiKit.GOOD)
	var upcoming := _draft.upcoming_picks(_club, 3)
	var pick_labels := []
	for number in upcoming:
		pick_labels.append("#%d" % int(number))
	_next_picks.text = "%d left to sign\nYour picks: %s" % [_draft.target_size - _draft.count(), ", ".join(pick_labels)]
	_finish_btn.disabled = not (done and _draft.is_valid())
	_finish_btn.tooltip_text = "Complete your list within the cap, including at least 2 rucks."
	if done:
		_next_picks.text = "Your list is ready.\nTime for round one." if _draft.is_valid() \
				else "List incomplete: at least 2 rucks\nand a full list within the cap required."
		_status.add_theme_color_override("font_color", UiKit.GOOD if _draft.is_valid() else UiKit.BAD)

	var latest := {}
	var new_rivals := 0
	for i in range(_draft.pick_history.size() - 1, -1, -1):
		var entry: Dictionary = _draft.pick_history[i]
		if str(entry["club"]) != _club:
			if latest.is_empty():
				latest = entry
			if i >= _last_batch_start:
				new_rivals += 1
	if done:
		_ticker.text = "LEAGUE DRAFT COMPLETE · View all %d picks ›" % _draft.pick_history.size()
	elif new_rivals == 0 and not _draft.pick_history.is_empty() and _draft.is_user_turn():
		_ticker.text = "BACK-TO-BACK PICKS · You're up again. View the pick log ›"
	elif latest.is_empty():
		_ticker.text = "LEAGUE PICKS  ·  You're first on the clock. View the pick log ›"
	else:
		_ticker.text = "RIVAL #%d · %s: %s · +%d picks ›" % [
			latest["pick"], str(latest["club"]), _entry_player_name(latest), new_rivals]
	_ticker.tooltip_text = _ticker.text + "\nTap to see every club's selections."


func _on_finish() -> void:
	if not _draft.is_finished() or not _draft.is_valid():
		return
	GameState.start_season(_club, _draft.list())
	Router.go("hub")


func _row_panel(mine: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := UiKit.style(Color("263025") if mine else Color.TRANSPARENT, 7, 4)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 1
	if mine:
		sb.border_width_left = 2
		sb.border_color = UiKit.GOLD
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.y = 62
	return p


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child)
