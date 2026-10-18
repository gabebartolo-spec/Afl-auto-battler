extends Control
## One draft, two layouts: pool + activity side by side in landscape; four
## focused tabs in portrait. The model owns every pick, never the view tree.

const ROLES := ["DEF", "MID", "RUCK", "FWD"]
const SORTS := [["overall", "Best rated"], ["potential", "Highest potential"], ["value", "Lowest cost"],
	["goals", "Most goals"], ["disposals", "Most disposals"], ["name", "Name A–Z"]]
const INTAKE_SORTS := [["overall", "Best scouted"], ["potential", "Highest upside"],
	["goals", "Junior goals"], ["disposals", "Junior disposals"], ["name", "Name A–Z"]]
const PAGE_SIZE := 60
# Opening League Draft only. The 2027 pool splits cleanly at these natural
# career stages (252 rookies, 248 prime-age players, 169 veterans).
const CAREER_STAGES := [["", "All"], ["rookie", "Rookies"], ["prime", "Prime"], ["veteran", "Veterans"]]
const ROOKIE_MAX_AGE := 24.0
const PRIME_MAX_AGE := 29.0

var _draft: Draft
var _meeting: Control = null    # the recruiting meeting, while it is open
var _club := ""
var _phase := "club"
var _role := ""
var _club_filter := ""
var _search := ""
var _sort := "overall"
var _career_stage := ""
## Playing style (PlayerProfile.player_type: Interceptor, Crumber, Wing...)
## and trait (Tagger, Contested bull...) filters: the director's PC playtest,
## 2026-10-07. "" is any.
var _style := ""
var _trait := ""
var _available_only := true
var _advanced_open := false
var _combine := ""          # the Combine test the pool is sorted on, or ""
var _combine_open := false
var _combine_field: Array = []
var _history_club := ""
var _shown := PAGE_SIZE
var _history_shown := PAGE_SIZE
var _tab := "pool"
var _side_tab := "picks"
var _wide := false
var _short := false
var _layout_key := ""
var _resize_queued := false
var _built_width := 0.0
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
var _all_button: Button
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
## Draft night (P-15): the live board under the header, the stage beat on
## your pick, and the board's replay of the rival picks that followed it.
var _board: PanelContainer
var _your_pick: Label
var _recent_box: VBoxContainer
var _stage_pick := -1          # while the stage reads your pick, the board holds on it
var _pool_rows_n := 0         # rows the pool shows (its filter line's count)
var _shown_upto := -1        # pick_history entries the board shows; -1 is all of them
var _replay_timer: Timer
var _beat: Control
var _beat_timer: Timer
var _why_box: VBoxContainer   # one line: why a rival took or passed on a prospect you opened
var _next_picks: Label
var _finish_btn: Button
var _pass_btn: Button
var _pick_me_btn: Button
## The player being inspected ("" when none) and his detail overlay.
var _name_index := {}       # player name -> club, for the ink in a pick's story
var _detail_id := ""
var _detail: Control
var _detail_all := false


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
	_replay_timer = Timer.new()
	_replay_timer.one_shot = true
	_replay_timer.timeout.connect(_replay_step)
	add_child(_replay_timer)
	_beat_timer = Timer.new()
	_beat_timer.one_shot = true
	_beat_timer.timeout.connect(_end_beat)
	add_child(_beat_timer)
	get_viewport().size_changed.connect(_on_resize)
	_build_layout()
	# The recruiting panel meets once before each National Draft.
	if _draft.intake_mode and _phase == "board" and not _draft.is_finished() \
			and GameState.draft_meeting_year != GameState.season_year:
		GameState.draft_meeting_year = GameState.season_year
		_show_meeting()


func _on_resize() -> void:
	if not _resize_queued:
		_resize_queued = true
		_reflow.call_deferred()


func _reflow() -> void:
	_resize_queued = false
	if not is_inside_tree():
		return
	_apply_margins()
	# The phone keyboard shrinks the window's height only: leave the screen
	# (and the focused search field) alone until it goes away.
	if UiKit.keyboard_resize(self, _built_width):
		return
	if _layout_signature() != _layout_key:
		var scrolls := _scroll_positions()
		var search_focus := is_instance_valid(_search_field) and _search_field.has_focus()
		var caret := _search_field.caret_column if search_focus else 0
		_build_layout()
		_restore_scrolls(scrolls)
		if search_focus and is_instance_valid(_search_field):
			_search_field.grab_focus()
			_search_field.caret_column = caret


func _usable_size() -> Vector2:
	var safe := ScreenLayout.safe_insets()
	return Vector2(UiKit.view_width(self) - safe.x - safe.z,
			UiKit.view_height(self) - safe.y - safe.w)


func _layout_signature() -> String:
	var area := _usable_size()
	return "%s/%s/%s/%d" % [ScreenLayout.wide_view(area.x, area.y, 760.0),
			area.y < 680.0, area.y < RECENT_TALL, _grid_columns()]


func _build_layout() -> void:
	# A rebuild (rotation, a resize) never leaves draft night half-shown.
	_finish_night()
	_club_backdrop()
	var area := _usable_size()
	_wide = ScreenLayout.wide_view(area.x, area.y, 760.0)
	_short = area.y < 680.0
	_layout_key = _layout_signature()
	_built_width = UiKit.view_width(self)
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
		values.append(UiKit.scroll_place(sc) if is_instance_valid(sc) else 0)
	return values


func _restore_scrolls(values: Array) -> void:
	var scrolls := [_board_scroll, _history_scroll, _mine_scroll, _order_scroll]
	for i in range(scrolls.size()):
		if is_instance_valid(scrolls[i]):
			UiKit.restore_scroll(scrolls[i], int(values[i]))


# ---------------------------------------------------------------------------
# Club selection
# ---------------------------------------------------------------------------
func _show_club_select() -> void:
	UiKit.clear(_root)
	# A career starts with the clubs active in its first season - the
	# founding eighteen in the first season, more once expansion clubs arrive.
	var real := GameState.opening_draft
	var active := GameDB.active_clubs(GameDB.START_YEAR if real else GameState.season_year)
	if real:
		_root.add_child(_header("Choose your club",
				"Real 2026 lists  /  the 2026 National Draft, then 2027"))
		_root.add_child(UiKit.lbl(
				"Every club starts with its real list, less the players who retired or were delisted after 2026; the delisted are free agents. The 2026 National Draft comes first, worst club on the ladder picking first; then the 2027 season.",
				16, UiKit.MUTED))
	else:
		_root.add_child(_header("Choose your club",
				"%d  /  A fresh start for all %d clubs" % [GameState.season_year, active.size()]))
		_root.add_child(UiKit.lbl(
				"One player pool. One salary cap. The whole league re-drafts in a random snake order.",
				16, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.name = "ClubGrid"
	grid.columns = _grid_columns()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_root.add_child(UiKit.scroll(grid))
	for code in active:
		var b := UiKit.btn("", UiKit.NAME)
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
		var pick_label := UiKit.lbl("Pick %d" % (_draft.draft_order.find(code) + 1), UiKit.SMALL, UiKit.EMPH)
		pick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pick_label)
		v.add_child(UiKit.lbl(GameDB.club_name(code), UiKit.HEADING, UiKit.TEXT, true))
		v.add_child(UiKit.ellipsis(str(GameDB.club(code).get("ground", "")), UiKit.SMALL, UiKit.MUTED))
		_ignore_mouse(inner)
		b.pressed.connect(_on_club_chosen.bind(code))
		grid.add_child(b)
	if real:
		_root.add_child(UiKit.subtitle("Your first pick in the 2026 National Draft is shown on each card."))
	else:
		_root.add_child(UiKit.subtitle("Every club drafts %d players. Your first pick is shown on each card." % _draft.target_size))



func _sort_options() -> Array:
	return INTAKE_SORTS if _draft != null and _draft.intake_mode else SORTS


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
	if GameState.opening_draft:
		GameState.choose_real_club(code)
	else:
		_draft.start_for_user(code)
	GameState.mark_dirty()
	_club_backdrop()
	_show_board()


## Your club's colour behind the board once you have one (director,
## 2026-10-10: every screen in the gameday style); none on club choice.
func _club_backdrop() -> void:
	if _club == "" or get_node_or_null("ClubBackdrop") != null:
		return
	var bd := ClubBackdrop.new().setup(_club)
	add_child(bd)
	move_child(bd, 0)


func _header(title_text: String, sub: String) -> Control:
	var h := UiKit.hbox(10)
	var back := UiKit.btn("‹", UiKit.GLYPH)
	back.name = "BackToMenu"
	back.custom_minimum_size = Vector2(44, 44)
	back.tooltip_text = "Back to menu. Your draft stays available to resume."
	back.pressed.connect(back_to_menu)
	h.add_child(back)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiKit.heading(title_text, UiKit.H1 if _short else 30))
	if not _short:
		# Whole, never cut off: it wraps on a phone.
		var sub_l := UiKit.lbl(sub, UiKit.SECONDARY, UiKit.MUTED)
		sub_l.name = "DraftSubtitle"
		sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sub_l)
	return h


## Draft night's hero (director, 2026-10-14): the guernsey of the club on the
## clock, on its own - the club's own guernsey, as everywhere else in the
## game. No hanger ("remove the coat hanger from the guernsey") and no lectern.
## Decoration: it takes no tap.
const STAGE_NARROW := 60.0
const STAGE_WIDE := 72.0
## The guernsey's square against the stage's height: the size and the place it
## had under the hanger, standing on the stage's foot.
const GUERNSEY_SHARE := 0.89
var _hung: Control
var _hung_code := ""


func _stage_h() -> float:
	return STAGE_WIDE if _wide else STAGE_NARROW


func _crest_size() -> float:
	return floor(_stage_h() * GUERNSEY_SHARE)


func _stage() -> Control:
	var h := UiKit.hbox(8)
	h.name = "DraftStage"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hung = Control.new()
	_hung.name = "DraftGuernsey"
	_hung.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hung.custom_minimum_size = Vector2(round(_crest_size() * 0.82), _stage_h())
	h.add_child(_hung)
	_hung_code = ""
	_hang(_club)
	return h


## Show `code`'s guernsey on the stage.
func _hang(code: String) -> void:
	if not is_instance_valid(_hung) or code == "" or code == _hung_code:
		return
	_hung_code = code
	UiKit.clear(_hung)
	var s := _crest_size()
	var w := _hung.custom_minimum_size.x
	var crest := UiKit.club_marker(code, s + 2.0)
	crest.size = Vector2(s, s)
	crest.position = Vector2(round((w - s) / 2.0), _stage_h() - s)
	_hung.add_child(crest)


# ---------------------------------------------------------------------------
# Persistent summary and responsive workspace
# ---------------------------------------------------------------------------
func _show_board() -> void:
	_search_timer.stop()
	UiKit.clear(_root)
	_board = null
	_your_pick = null
	_recent_box = null
	_why_box = null
	_role_labels.clear()
	_role_buttons.clear()
	_need_labels.clear()
	if _short:
		_root.add_child(_compact_header())
	else:
		if _draft.intake_mode:
			_root.add_child(_header("%d National Draft" % GameState.season_year,
					"Lowest on the ladder picks first."))
		else:
			var sub := "%d  /  %d clubs  /  Snake draft" % [
					GameState.season_year, _draft.clubs.size()]
			_root.add_child(_header("League draft", sub))
		_board = _live_board()
		_root.add_child(_board)
	_why_box = UiKit.vbox(0)
	_why_box.name = "RivalWhy"
	_root.add_child(_why_box)

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
	var back := UiKit.btn("‹", UiKit.GLYPH)
	back.custom_minimum_size.x = 44
	back.pressed.connect(back_to_menu)
	h.add_child(back)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_status = UiKit.lbl("", UiKit.NAME, UiKit.EMPH, true)
	_status.name = "DraftStatus"
	v.add_child(_status)
	_round_info = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	v.add_child(_round_info)
	_cap = UiKit.line("", UiKit.SECONDARY, UiKit.TEXT, true)
	_cap.name = "SalaryCap"
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_cap)
	return h


## The live board (P-15): the club on the clock in its guernsey and in words
## ("Pick 12: Fremantle"), your next pick ("Your pick: 14, two away"), and the
## last three picks under it. A tap opens the pick log (and finishes a replay).
func _live_board() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, 9, 7)
	p.name = "LiveBoard"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = "Tap to see every club's selections."
	p.gui_input.connect(_on_board_input)
	var col := UiKit.vbox(6)
	p.add_child(col)
	var top := UiKit.hbox(10)
	top.name = "OnTheClock"
	col.add_child(top)
	top.add_child(_stage())
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(v)
	_status = UiKit.lbl("", UiKit.NAME, UiKit.TEXT, true)
	_status.name = "DraftStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _wide and _usable_size().y >= RECENT_TALL:
		# Phone: room for two lines ("Pick 27: Greater Western Sydney"), so the
		# board and the pool under it never jump as the clubs change (a short
		# phone keeps the line for the pool instead).
		var fnt := _status.get_theme_font("font")
		var fs := _status.get_theme_font_size("font_size")
		_status.custom_minimum_size.y = ceilf(fnt.get_height(fs) * 2.0 + _status.get_theme_constant("line_spacing"))
		_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(_status)
	_round_info = UiKit.lbl("", UiKit.SECONDARY, UiKit.MUTED)
	_round_info.name = "ClockRound"
	_round_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_round_info)
	_your_pick = UiKit.lbl("", UiKit.SECONDARY, UiKit.EMPH, true)
	_your_pick.name = "YourNextPick"
	_your_pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_your_pick)
	_recent_box = UiKit.vbox(2)
	_recent_box.name = "RecentPicks"
	if _wide:
		# PC: the last three picks beside the club on the clock, in the same row,
		# so the board uses the width rather than adding height.
		v.size_flags_stretch_ratio = 0.8
		_recent_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_recent_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_recent_box)
	else:
		col.add_child(_recent_box)
	_cap = UiKit.line("", UiKit.SECONDARY, UiKit.TEXT, true)
	_cap.name = "SalaryCap"
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_cap)
	_ignore_mouse(col)
	return p


func _on_board_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and not event.is_pressed()) or (event is InputEventScreenTouch and not event.is_pressed()):
		_finish_replay()
		_select_tab("picks")
		accept_event()


# One row answers both "what does my list need?" and "show me those players":
# a compact All, then a card per position with the count and the need.
func _position_filters() -> Control:
	var h := UiKit.hbox(5)
	h.name = "PositionFilters"
	var narrow := _usable_size().x < 400.0
	var height := 52 if _short else 58
	_all_button = UiKit.btn("All", 14)
	_all_button.name = "Filter_ALL"
	_all_button.custom_minimum_size = Vector2(40 if narrow else 48, height)
	_all_button.tooltip_text = "Show every position."
	_all_button.pressed.connect(_set_role.bind(""))
	h.add_child(_all_button)
	for role in ROLES:
		var b := UiKit.btn("", 14)
		b.name = "Position_" + role
		_role_buttons[role] = b
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, height)
		var v := UiKit.vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 2
		v.offset_right = -2
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var count_label := UiKit.line("", 14 if narrow else 16, UiKit.ROLE_COLOUR[role], true)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(count_label)
		_role_labels[role] = count_label
		# One answer per position: short of the match-day side, light on a
		# full list's depth, or covered. Each player fills one spot only.
		var need := UiKit.line("", UiKit.FINE, UiKit.MUTED, true)
		need.name = "Need_" + role
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(need)
		_need_labels[role] = need
		b.tooltip_text = "Tap to show only %s; tap again for all." % str(UiKit.ROLE_LABEL[role]).to_lower()
		_ignore_mouse(v)
		b.pressed.connect(func(): _set_role("" if _role == role else role))
		h.add_child(b)
	return h


func _footer() -> Control:
	var p := UiKit.panel(UiKit.INK, 8, 6)
	var col := UiKit.vbox(6)
	p.add_child(col)
	var h := UiKit.hbox(10)
	col.add_child(h)
	_next_picks = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	_next_picks.name = "UpcomingPicks"
	_next_picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_next_picks)
	_finish_btn = UiKit.btn("Finish draft" if _draft.intake_mode else "Start season", 14, true)
	_finish_btn.name = "StartSeason"
	_finish_btn.pressed.connect(_on_finish)
	UiKit.feel(_finish_btn, "end")     # the end of the draft: the siren
	h.add_child(_finish_btn)
	# Two plain buttons for your own pick; neither is the recommended one.
	var acts := UiKit.hbox(8)
	acts.name = "PickActions"
	col.add_child(acts)
	_pick_me_btn = UiKit.btn("Pick for me", UiKit.SECONDARY)
	_pick_me_btn.name = "PickForMe"
	_pick_me_btn.custom_minimum_size = Vector2(0, 44)
	_pick_me_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_me_btn.pressed.connect(_on_pick_for_me)
	acts.add_child(_pick_me_btn)
	if _draft.intake_mode:
		_pass_btn = UiKit.btn("Pass", UiKit.SECONDARY)
		_pass_btn.name = "PassPick"
		_pass_btn.custom_minimum_size = Vector2(0, 44)
		_pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pass_btn.pressed.connect(_on_pass)
		acts.add_child(_pass_btn)
	return p


func _on_pick_for_me() -> void:
	_finish_night()
	var before := _draft.pick_history.size()
	if _draft.pick_for_me():
		GameState.mark_dirty()
		_last_batch_start = before
		_refresh()
		_after_my_pick(before)


func _on_pass() -> void:
	_finish_night()
	var before := _draft.pick_history.size()
	if _draft.user_pass():
		_last_batch_start = before
		_refresh()
		_start_replay(before)


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
	# The pick log is only rebuilt while in view during a replay: catch it up.
	if replaying() and _history_view.visible:
		_refresh_history()
	if is_instance_valid(_recent_box):
		_recent_box.visible = _recent_wanted()


func _refresh_tabs() -> void:
	UiKit.clear(_main_tabs)
	UiKit.clear(_side_tabs)
	for item in [["pool", "Pool"], ["picks", "Picks"], ["squad", "My list"], ["order", "Order"]]:
		var key: String = item[0]
		var label := str(item[1])
		if key == "picks" and _shown_picks() > 0:
			label += " (%d)" % _shown_picks()
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
	title_row.visible = _wide and not _short
	var title_label := UiKit.heading("Draft pool", UiKit.H1)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	# The count is said once on the board ("N prospects left") and once in the
	# pool's filter line; the title row does not repeat it.
	_pool_total = UiKit.line("", 12, UiKit.MUTED)
	_pool_total.visible = false
	title_row.add_child(_pool_total)
	v.add_child(_position_filters())
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
	var filters := UiKit.btn("Filters", UiKit.SECONDARY)
	filters.name = "MoreFilters"
	filters.toggle_mode = true
	filters.button_pressed = _advanced_open
	filters.toggled.connect(func(on: bool):
		_advanced_open = on
		_advanced.visible = on)
	search_row.add_child(filters)
	if _draft.intake_mode:
		# The Combine: the class's testing results, one test at a time.
		var combine := UiKit.btn("Combine", UiKit.SECONDARY)
		combine.name = "CombineOpen"
		combine.toggle_mode = true
		combine.button_pressed = _combine_open
		search_row.add_child(combine)
		var crow := UiKit.vbox(4)
		crow.name = "CombineRow"
		crow.visible = _combine_open
		v.add_child(crow)
		var opts_c := [["", "Off"]]
		for t in Combine.TESTS:
			opts_c.append([str(t[0]), {"sprint": "Sprint", "trial": "2 km", "leap": "Leap", "kick": "Kicking"}[str(t[0])]])
		crow.add_child(UiKit.choice_grid("CombineTest", opts_c, _combine, 5, func(k):
			_combine = str(k)
			_shown = PAGE_SIZE
			_show_board()))
		if _combine != "":
			var what := UiKit.lbl("%s. %s" % [str(Combine.test(_combine)[1]), str(Combine.test(_combine)[4])],
					UiKit.SECONDARY, UiKit.MUTED)
			what.name = "CombineWhat"
			what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			crow.add_child(what)
		combine.toggled.connect(func(on: bool):
			_combine_open = on
			crow.visible = on
			if not on and _combine != "":
				_combine = ""
				_show_board())

	_advanced = UiKit.vbox(6)
	_advanced.visible = _advanced_open
	v.add_child(_advanced)
	var opts := UiKit.hbox(6)
	_advanced.add_child(opts)
	var clubs := UiKit.option()
	clubs.name = "OriginClubFilter"
	var origin_values := []
	if _draft.intake_mode:
		for p in _draft.pool:
			var team := str(p["club"])
			if not origin_values.has(team):
				origin_values.append(team)
		origin_values.sort()
		clubs.add_item("All recruiting clubs")
	else:
		# The clubs that actually have players in this draft's pool - the
		# founding eighteen in the first season, not every club that will ever exist.
		var present := {}
		for p in _draft.pool:
			present[str(p.get("club", ""))] = true
		for code in GameDB.club_order:
			if present.has(code):
				origin_values.append(code)
		clubs.add_item("All original clubs")
	for value in origin_values:
		clubs.add_item(GameDB.club_name(str(value)))
	clubs.select(0 if _club_filter.is_empty() else origin_values.find(_club_filter) + 1)
	clubs.item_selected.connect(func(idx: int):
		_club_filter = "" if idx == 0 else str(origin_values[idx - 1])
		_shown = PAGE_SIZE
		_refresh_board(true))
	opts.add_child(clubs)
	var sort_option := UiKit.option()
	sort_option.name = "SortPlayers"
	var sort_options := _sort_options()
	for i in range(sort_options.size()):
		sort_option.add_item(str(sort_options[i][1]))
		if str(sort_options[i][0]) == _sort:
			sort_option.select(i)
	sort_option.item_selected.connect(func(idx: int):
		_sort = str(sort_options[idx][0])
		_shown = PAGE_SIZE
		_refresh_board(true))
	opts.add_child(sort_option)
	if _draft.league_mode and not _draft.intake_mode:
		var stage_row := UiKit.hbox(6)
		_advanced.add_child(stage_row)
		var stage_label := UiKit.lbl("Career stage", UiKit.SECONDARY, UiKit.MUTED)
		stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage_row.add_child(stage_label)
		var stage_option := UiKit.option()
		stage_option.name = "CareerStageFilter"
		for i in range(CAREER_STAGES.size()):
			stage_option.add_item(str(CAREER_STAGES[i][1]))
			if str(CAREER_STAGES[i][0]) == _career_stage:
				stage_option.select(i)
		stage_option.item_selected.connect(func(idx: int):
			_career_stage = str(CAREER_STAGES[idx][0])
			_shown = PAGE_SIZE
			_refresh_board(true))
		stage_row.add_child(stage_option)
	var kinds := UiKit.hbox(6)
	_advanced.add_child(kinds)
	var styles := []
	var traits := []
	for p in _draft.pool:
		var st := PlayerProfile.player_type(p)
		if st != "" and not styles.has(st):
			styles.append(st)
		for t in _traits_of(p):
			if not traits.has(str(t)):
				traits.append(str(t))
	styles.sort()
	traits.sort_custom(func(a, b): return _trait_label(a) < _trait_label(b))
	var style_option := UiKit.option()
	style_option.name = "StyleFilter"
	style_option.add_item("Any playing style")
	for st in styles:
		style_option.add_item(str(st))
	style_option.select(0 if _style.is_empty() else styles.find(_style) + 1)
	style_option.item_selected.connect(func(idx: int):
		_style = "" if idx == 0 else str(styles[idx - 1])
		_shown = PAGE_SIZE
		_refresh_board(true))
	kinds.add_child(style_option)
	var trait_option := UiKit.option()
	trait_option.name = "TraitFilter"
	trait_option.add_item("Any trait")
	for t in traits:
		trait_option.add_item(_trait_label(str(t)))
	trait_option.select(0 if _trait.is_empty() else traits.find(_trait) + 1)
	trait_option.item_selected.connect(func(idx: int):
		_trait = "" if idx == 0 else str(traits[idx - 1])
		_shown = PAGE_SIZE
		_refresh_board(true))
	kinds.add_child(trait_option)
	var avail := UiKit.btn("Available only", 14)
	avail.name = "AvailableOnly"
	avail.toggle_mode = true
	avail.button_pressed = _available_only
	avail.toggled.connect(func(on: bool):
		_available_only = on
		_shown = PAGE_SIZE
		_refresh_board(true))
	_advanced.add_child(avail)
	_board_info = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	v.add_child(_board_info)
	return v


func _refresh_role_tabs() -> void:
	for role in _role_buttons:
		var colour: Color = UiKit.ROLE_COLOUR[role]
		_role_buttons[role].add_theme_stylebox_override("normal", UiKit.style(
				Color(colour, 0.14 if _role == role else 0.08), 6, 6,
				colour if _role == role else UiKit.LINE))
	_all_button.add_theme_stylebox_override("normal", UiKit.style(
			Color.TRANSPARENT, 6, 6, UiKit.TEXT if _role.is_empty() else UiKit.LINE))
	_all_button.add_theme_color_override("font_color", UiKit.TEXT if _role.is_empty() else UiKit.MUTED)


func _set_role(role: String) -> void:
	_role = role
	_shown = PAGE_SIZE
	_refresh_role_tabs()
	_refresh_board(true)


func _career_stage_for_age(age: float) -> String:
	if age <= 0.0:
		return ""
	if age < ROOKIE_MAX_AGE:
		return "rookie"
	if age < PRIME_MAX_AGE:
		return "prime"
	return "veteran"


func _career_stage_label(key: String) -> String:
	for stage in CAREER_STAGES:
		if str(stage[0]) == key:
			return str(stage[1])
	return ""


## His traits, and Tagger when he is one (Roles: a role, read like a trait
## when choosing players).
func _traits_of(p: Dictionary) -> Array:
	var out: Array = Traits.of(p).duplicate()
	if Roles.is_tagger(p):
		out.append("tagger")
	return out


func _trait_label(key: String) -> String:
	return "Tagger" if key == "tagger" else Traits.label(key)


func _board_rows(available := _available_only) -> Array:
	var rows := _draft.board(_role, _club_filter, _search.strip_edges(), _sort, available)
	if _combine != "":
		rows = Combine.sort_rows(rows, _combine, _draft.seed)
	if not _style.is_empty() or not _trait.is_empty():
		rows = rows.filter(func(p):
			return (_style.is_empty() or PlayerProfile.player_type(p) == _style) \
					and (_trait.is_empty() or _traits_of(p).has(_trait)))
	if not _draft.league_mode or _draft.intake_mode or _career_stage.is_empty():
		return rows
	var filtered := []
	for p in rows:
		if _career_stage_for_age(float(p.get("age", 0.0))) == _career_stage:
			filtered.append(p)
	return filtered


## The pool's filter line: "26 available · best scouted". During draft night's
## replay the count holds back with the board: a prospect whose pick has not
## been shown yet still counts as available.
func _refresh_pool_info() -> void:
	if not is_instance_valid(_board_info):
		return
	var n := _pool_rows_n + _hidden_in_filter()
	var sort_label := ""
	for sort_entry in _sort_options():
		if str(sort_entry[0]) == _sort:
			sort_label = str(sort_entry[1]).to_lower()
	var role_text := "" if _role.is_empty() else _role + " "
	_board_info.text = "%d %s%s · %s" % [n, role_text,
			"available" if _available_only else "players", sort_label]
	if _combine != "":
		_board_info.text = "%d %s%s · best %s first" % [n, role_text,
				"available" if _available_only else "players", str(Combine.test(_combine)[1]).to_lower()]
	if _draft.intake_mode and _available_only and _role.is_empty() and _club_filter.is_empty() and _combine == "" \
			and _search.strip_edges() == "" and _style.is_empty() and _trait.is_empty():
		# The board already says how many are left: the line keeps only the order.
		_board_info.text = sort_label.left(1).to_upper() + sort_label.substr(1)
	if not _club_filter.is_empty():
		_board_info.text += " · " + GameDB.club_short(_club_filter)
	if not _career_stage.is_empty() and _draft.league_mode:
		_board_info.text += " · " + _career_stage_label(_career_stage).to_lower()


## Prospects picked in the part of the night the board has not replayed yet
## that the pool's filters would show.
func _hidden_in_filter() -> int:
	if _shown_upto < 0 or not _available_only:
		return 0
	var hidden := {}
	for i in range(_shown_picks(), _draft.pick_history.size()):
		hidden[str(_draft.pick_history[i].get("player_id", ""))] = true
	if hidden.is_empty():
		return 0
	var n := 0
	for p in _board_rows(false):
		if hidden.has(str(p.get("id", ""))):
			n += 1
	return n


func _refresh_board(reset_scroll := false) -> void:
	if _phase != "board" or not is_instance_valid(_board_box):
		return
	UiKit.clear(_board_box)
	if _combine != "":
		_combine_field = Combine.field(_draft.pool, _combine, _draft.seed)
	var rows := _board_rows()
	_pool_total.text = "%d available" % (_draft.pool.size() - _draft.picked.size())
	_pool_rows_n = rows.size()
	_refresh_pool_info()
	var shown := mini(_shown, rows.size())
	for i in range(shown):
		_board_box.add_child(_player_row(rows[i]))
	if rows.is_empty():
		_board_box.add_child(UiKit.lbl("No players match these filters.", UiKit.NAME, UiKit.TEXT, true))
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
	_career_stage = ""
	_style = ""
	_trait = ""
	_available_only = true
	_shown = PAGE_SIZE
	_show_board()


func _player_row(p: Dictionary) -> Control:
	var row := _row_panel(false)
	row.name = "Player_" + str(p["id"])
	var h := UiKit.hbox(8)
	row.add_child(h)
	var role := str(p["role"])
	# Tapping the player (chip, name, line) inspects him; only the button on
	# the right drafts.
	var inspect := Button.new()
	inspect.name = "Inspect_" + str(p["id"])
	inspect.flat = true
	inspect.focus_mode = Control.FOCUS_NONE
	inspect.mouse_filter = Control.MOUSE_FILTER_PASS
	inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect.custom_minimum_size.y = 66
	inspect.tooltip_text = "Inspect %s" % GameDB.player_display_name(p)
	inspect.pressed.connect(_open_player.bind(str(p["id"])))
	h.add_child(inspect)
	# His role and name on top; under them, at the row's full width, the
	# facts that decide a pick and how he plays (they wrap, never cut).
	var face := UiKit.vbox(2)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspect.add_child(face)
	var top := UiKit.hbox(8)
	face.add_child(top)
	top.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(UiKit.name_label(GameDB.player_display_name(p)))
	var taken := _draft.has(str(p["id"]))
	# Line two: what decides a pick, first so a phone never cuts it off -
	# his age, the read of his OVR and POT, his price. Line three: where he
	# comes from and how he plays (director's PC playtest, 2026-10-07).
	var where := ""
	var read := ""
	if bool(p.get("projected", false)):
		where = str(p.get("draft_team", p["club"]))
		if InternationalProspects.is_international(p):
			where = "%s, %s" % [where, str(p.get("draft_state", ""))]
		if _draft.intake_mode:
			var scout := DraftScouting.projection(p, _club, _draft.seed,
					_draft.scouting_mult_for(_club))
			read = "scouted %s OVR · %s POT" % [DraftScouting.range_text(scout["overall"]),
					DraftScouting.range_text(scout["potential"])]
		else:
			# Your recruiters' read, as for every other League Draft player: a
			# range until he is yours.
			var proj_view := _draft.user_view(p)
			if bool(proj_view["scouted"]):
				read = "projected %s OVR · %s POT" % [DraftScouting.range_text(proj_view["overall"]),
						DraftScouting.range_text(proj_view["potential"])]
			else:
				read = "projected %d OVR · %d POT" % [int(p["overall"]), int(p.get("potential", p["overall"]))]
	else:
		where = GameDB.club_short(str(p["club"]))
		var view := _draft.user_view(p)
		if bool(view["scouted"]):
			read = "%s OVR · %s POT" % [DraftScouting.range_text(view["overall"]),
					DraftScouting.range_text(view["potential"])]
		else:
			read = "%d OVR · %d POT" % [int(p["overall"]), int(p.get("potential", p["overall"]))]
		read += " · " + Contracts.money(int(p["value"]))
	var facts := read
	if float(p.get("age", 0.0)) > 0.0:
		facts = "%d yo · %s" % [int(p["age"]), read]
	if taken:
		var entry := _draft.pick_details(str(p["id"]))
		facts = "Pick %d to %s" % [int(entry.get("pick", 0)),
				GameDB.club_short(_draft.drafted_by(str(p["id"])))]
		if not bool(_draft.user_view(p)["scouted"]):
			facts += " · %d OVR" % int(p["overall"])
	# Every fact on these lines decides a pick (his price is last): they wrap
	# rather than cut on a phone, and the row grows to fit them.
	face.add_child(_row_line(facts, UiKit.TEXT))
	var kind: PackedStringArray = [where, PlayerProfile.player_type(p)]
	for t in _traits_of(p):
		kind.append(_trait_label(str(t)))
	var kind_line := _row_line(" · ".join(kind), UiKit.MUTED)
	kind_line.name = "Kind_" + str(p["id"])
	if _combine != "":
		# On a Combine sort, his result in that test replaces how he plays.
		var r := Combine.result(p, _combine, _draft.seed)
		var said := Combine.text(_combine, r)
		var stand := Combine.standing(_combine, r, _combine_field)
		kind_line = _row_line(said + ("" if stand == "" else "  ·  " + stand),
				UiKit.TEXT if r >= 0.0 else UiKit.MUTED, r >= 0.0)
		kind_line.name = "CombineResult_" + str(p["id"])
	face.add_child(kind_line)
	top.add_child(UiKit.line("›", 20, UiKit.MUTED, true))
	_ignore_mouse(face)
	# The face is laid over the button, so the button takes its height.
	face.minimum_size_changed.connect(func():
		inspect.custom_minimum_size.y = maxf(66.0, face.get_combined_minimum_size().y))
	var can_pick := _draft.can_pick_player(p)
	var text := "+ " + role
	var reason := "Draft %s for %s" % [GameDB.player_display_name(p), Contracts.money(int(p["value"]))]
	if _draft.intake_mode:
		reason = "Select %s in the National Draft" % GameDB.player_display_name(p)
	if taken:
		text = "Taken"
		reason = "Drafted by %s at pick %d" % [GameDB.club_name(_draft.drafted_by(str(p["id"]))),
				int(_draft.pick_details(str(p["id"])).get("pick", 0))]
	elif not _draft.is_user_turn():
		text = "Closed" if _draft.is_finished() else "Wait"
		reason = "The draft is complete." if _draft.is_finished() else "Waiting for your next turn."
	elif not can_pick:
		reason = _draft.pick_block_reason(p)
		text = "Rucks" if reason.contains("rucks") else ("Full" if reason.contains("full") else ("Cap" if reason.contains("cap") else "No"))
	var b := UiKit.btn(text, UiKit.SECONDARY)
	b.name = "Pick_" + str(p["id"])
	b.custom_minimum_size = Vector2(66, 44)
	# Its own height, centred: a taller row (wrapped facts) does not stretch it.
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not can_pick
	b.tooltip_text = reason
	if can_pick:
		b.add_theme_color_override("font_color", UiKit.TEXT)
		b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL, 6, 5, Color("6c5142")))
	b.pressed.connect(_on_pick.bind(p))
	h.add_child(b)
	if bool(p.get("projected", false)) and _draft.intake_mode:
		var production := PlayerProfile.production(p)
		row.tooltip_text = "%s · %s\n%s\n%s" % [
				GameDB.player_display_name(p), str(p.get("draft_team", p["club"])),
				str(production.get("line", "")), reason]
	else:
		row.tooltip_text = "%s · %s\n%d games · %.1f disposals/game · %d goals\n%s" % [
			GameDB.player_display_name(p), GameDB.club_name(str(p["club"])), int(p["gm"]),
			float(p["di"]) / maxf(1.0, float(p["gm"])), int(p["gl"]), reason]
	return row


func _on_pick(player: Dictionary) -> void:
	_finish_night()
	var before := _draft.pick_history.size()
	_last_batch_start = before
	if _draft.pick(player):
		GameState.mark_dirty()
		_refresh()
		_after_my_pick(before)


## Your pick made (entry `at` of the pick history): at the National Draft, his
## name is read on the stage, then the board replays the rival picks that
## followed; elsewhere (and with motion off) it lands as before.
func _after_my_pick(at: int) -> void:
	if not _night_on() or at >= _draft.pick_history.size():
		_land_my_pick()
		return
	_shown_upto = at + 1
	_stage_pick = at
	_refresh_shown()
	_show_beat(_draft.pick_history[at])


# ---------------------------------------------------------------------------
# Draft night (P-15): the stage beat and the board's replay. Presentation only;
# the model has already made every pick. Tests and captures see the end state
# at once unless motion is on (UiKit.motion_on).
# ---------------------------------------------------------------------------
## Seconds the board shows each rival pick (lead, 2026-10-18: 0.3 s; the motion
## critic, same day: 0.45 s, so each name can be read before the next lands).
const REPLAY_STEP := 0.45
## Seconds his name stays on the stage: the walk-on, the turn, arms up.
const BEAT_TIME := 3.2
## Seconds the stage takes to fade back to the board, so the swap does not cut.
const BEAT_FADE := 0.18


func _night_on() -> bool:
	return _draft.intake_mode and UiKit.motion_on()


## Replay the picks from history entry `from` on, one at a time.
func _start_replay(from: int) -> void:
	if not _night_on() or from >= _draft.pick_history.size():
		_finish_replay()
		return
	_shown_upto = from
	_refresh_shown()
	_replay_timer.start(REPLAY_STEP)


func _replay_step() -> void:
	if _shown_upto < 0:
		return
	_shown_upto += 1
	if _shown_upto >= _draft.pick_history.size():
		_shown_upto = -1
	else:
		_replay_timer.start(REPLAY_STEP)
	_refresh_shown(true)


func replaying() -> bool:
	return _shown_upto >= 0


## How many picks the board and the pick log show: all of them, or during a
## replay the ones it has reached.
func _shown_picks() -> int:
	var all: int = _draft.pick_history.size()
	return all if _shown_upto < 0 else mini(_shown_upto, all)


## The live board, the pick log and its tab, as far as the replay has reached.
func _refresh_shown(settle := false) -> void:
	_refresh_live(settle)
	if is_instance_valid(_main_tabs):
		_refresh_tabs()
	if is_instance_valid(_history_box) and _history_box.is_visible_in_tree():
		_refresh_history()
	_refresh_pool_info()
	_refresh_why()


func _finish_replay() -> void:
	if is_instance_valid(_replay_timer):
		_replay_timer.stop()
	if _shown_upto >= 0:
		_shown_upto = -1
		_refresh_shown()
		if is_instance_valid(_history_box):
			_refresh_history()


## Cut straight to the end of the night's show: the stage and the replay.
func _finish_night() -> void:
	if is_instance_valid(_beat_timer):
		_beat_timer.stop()
	var leaving := get_node_or_null("DraftNightStageLeaving")
	if leaving != null:
		leaving.queue_free()
	var had := is_instance_valid(_beat) or leaving != null or _stage_pick >= 0
	if is_instance_valid(_beat):
		_beat.queue_free()
	_beat = null
	_stage_pick = -1
	if _shown_upto < 0 and had:
		_refresh_shown()
	_finish_replay()
	if had:
		_hold_pick_buttons(false)


## The stage beat: the new man on the award stage in your club's guernsey, the
## pick read out in words and the recruiter's one line. Over the pool (PC:
## beside the pick log; phone: under the board). A tap ends it.
func _show_beat(entry: Dictionary) -> void:
	var p := _player_by_id(str(entry.get("player_id", "")))
	if p.is_empty() or not is_instance_valid(_pool_panel):
		_end_beat()
		return
	# PC: over the pool, beside the pick log. Phone: the whole workspace under
	# the board, tabs included.
	var area := _pool_panel.get_global_rect()
	if not _wide:
		area = (_pool_panel.get_parent() as Control).get_global_rect()
		if is_instance_valid(_main_tabs) and _main_tabs.is_visible_in_tree():
			area = area.merge(_main_tabs.get_global_rect())
	var stage := Button.new()
	stage.name = "DraftNightStage"
	stage.flat = true
	stage.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		stage.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	stage.tooltip_text = "Tap to carry on."
	stage.position = area.position - get_global_rect().position
	stage.size = area.size
	stage.set_meta("announcement", DraftNight.announcement(int(entry["pick"]), _club, p))
	stage.set_meta("recruiter", DraftNight.recruiter_line(p, _club))
	add_child(stage)
	_beat = stage
	# While his name is read, Pick for me and Pass wait (disabled look, no tap).
	_hold_pick_buttons(true)
	if is_instance_valid(_recent_box):
		_recent_box.visible = _recent_wanted()
	var panel := UiKit.panel(UiKit.BG, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(panel)
	var v := UiKit.vbox(0)
	panel.add_child(v)
	if GameState.vignettes_on():
		var scene := AwardWinnerVignette.new()
		scene.name = "DraftNightVignette"
		scene.medal = false
		scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scene.custom_minimum_size = Vector2(0, 160)
		v.add_child(scene)
		scene.setup_winner(_club, 0, str(p.get("id", "")))
	var words := MarginContainer.new()
	for edge in ["left", "right"]:
		words.add_theme_constant_override("margin_" + edge, 14)
	words.add_theme_constant_override("margin_top", 10)
	words.add_theme_constant_override("margin_bottom", 12)
	if not GameState.vignettes_on():
		words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(words)
	var say := UiKit.vbox(3)
	say.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(say)
	# The pick in the club's ink, his name big, where from and what he plays,
	# then the recruiter's line in his own words.
	var pick_l := _beat_line(DraftNight.clock_line(int(entry["pick"]), _club),
			UiKit.HEADING, UiKit.club_ink(_club), true)
	pick_l.name = "BeatPick"
	say.add_child(pick_l)
	var name_l := _beat_line(GameDB.player_display_name(p), UiKit.TITLE, UiKit.TEXT, true)
	name_l.name = "BeatName"
	name_l.add_theme_font_override("font", UiKit.DISPLAY)
	say.add_child(name_l)
	var from := DraftNight.from_words(p)
	var where_l := _beat_line(((from + ", ") if from != "" else "") + DraftNight.position_words(p),
			UiKit.BODY, UiKit.TEXT)
	where_l.name = "BeatFrom"
	say.add_child(where_l)
	var rec := _beat_line("Recruiting note: %s" % DraftNight.recruiter_line(p, _club), UiKit.BODY, UiKit.TEXT)
	rec.name = "BeatRecruiter"
	say.add_child(rec)
	_ignore_mouse(panel)
	stage.pressed.connect(_end_beat)
	# His name lands with weight, as UiKit.land does, on the label's own tween so
	# a tap or Back that frees the stage first leaves nothing waiting on it.
	var tw := name_l.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		Feel.press("land")
		Feel.moved.append("land")
		name_l.pivot_offset = name_l.size / 2.0
		name_l.scale = Vector2(1.22, 1.22))
	tw.tween_property(name_l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_beat_timer.start(BEAT_TIME)


## Pick for me and Pass held while the stage plays; released to their own
## state (_refresh_status) when it ends.
func _hold_pick_buttons(hold: bool) -> void:
	if hold:
		for b in [_pick_me_btn, _pass_btn]:
			if is_instance_valid(b):
				b.disabled = true
	elif is_instance_valid(_status):
		_refresh_status()


func _beat_line(text: String, fs: int, colour: Color, bold := false) -> Label:
	var l := UiKit.lbl(text, fs, colour, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## The beat is over (its time, or a tap): back to the board, which replays
## the rival picks that came after yours.
func _end_beat() -> void:
	if is_instance_valid(_beat_timer):
		_beat_timer.stop()
	var had := is_instance_valid(_beat)
	if had:
		# The stage fades back to the board (BEAT_FADE) rather than cutting; it
		# takes no more taps and is no longer the stage while it goes.
		var leaving := _beat as Button
		leaving.name = "DraftNightStageLeaving"
		leaving.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leaving.disabled = true
		var tw := leaving.create_tween()
		tw.tween_property(leaving, "modulate:a", 0.0, BEAT_FADE).set_ease(Tween.EASE_IN)
		tw.tween_callback(leaving.queue_free)
		tw.tween_callback(_release_stage)
		_beat = null
		return
	_beat = null
	_release_stage()


## The stage has gone: the board moves on from your pick and replays the
## rival picks after it; Pick for me and Pass come back.
func _release_stage() -> void:
	var held := _stage_pick >= 0
	_stage_pick = -1
	if _shown_upto >= 0:
		_start_replay(_shown_upto)
	elif held:
		_refresh_shown()
	_hold_pick_buttons(false)


## Your pick lands with weight (director, 2026-10-11): the status line, and
## the pick's row when the picks are in view. Once, then still.
func _land_my_pick() -> void:
	UiKit.land(_status)
	for i in range(_draft.pick_history.size() - 1, _last_batch_start - 1, -1):
		var entry: Dictionary = _draft.pick_history[i]
		if str(entry["club"]) == _club:
			var row := _history_box.get_node_or_null("HistoryPick_%d" % int(entry["pick"])) as Control
			if row != null and row.is_visible_in_tree():
				UiKit.land(row, 0.0, false)
			return


# ---------------------------------------------------------------------------
# Inspecting a player: read-only. Only the Draft / Sign button picks.
# ---------------------------------------------------------------------------
## Android Back and the top-bar back close the player first.
func handle_back() -> bool:
	# Back first cuts draft night's show to the end: the stage and the replay.
	if is_instance_valid(_beat) or replaying():
		_finish_night()
		return true
	# The recruiting meeting closes before the draft is left.
	if is_instance_valid(_meeting):
		_meeting.queue_free()
		_meeting = null
		return true
	if is_instance_valid(_detail):
		_close_player()
		return true
	return false


## Back from the draft: from Choose your club, one step back is the New career
## options it came from; once a club is chosen it is the title, where the draft
## waits to be resumed.
func back_to_menu() -> void:
	_finish_night()
	if _phase == "club":
		GameState.new_career_setup_requested = true
	Router.replace("main")


func _player_by_id(id: String) -> Dictionary:
	if _draft.picked.has(id):
		return _draft.picked[id]
	for p in _draft.pool:
		if str(p["id"]) == id:
			return p
	return {}


## Before the National Draft: what the list does well, where it is short,
## and a few prospects recruiting liked - a starting point, not an answer.
func _show_meeting() -> void:
	var notes := RecruitMeeting.notes(_draft, GameState.my_list, GameState.list_profile(), GameState.club_plan)
	var box := UiKit.modal_box(self, 520.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "DraftMeeting"
	_meeting = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Before the draft", 20, UiKit.TEXT, true))
	if not (notes["list"] as Array).is_empty():
		v.add_child(UiKit.lbl("Our list", 14, UiKit.MUTED, true))
		for line in notes["list"]:
			var l := UiKit.lbl(str(line), 14, UiKit.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	if not (notes["names"] as Array).is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("Recruiting liked", 14, UiKit.MUTED, true))
		for row in notes["names"]:
			var id := str(row["id"])
			var b := UiKit.btn(str(row["line"]), 14)
			b.name = "MeetingName_" + id
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.y = 44
			b.pressed.connect(func():
				overlay.queue_free()
				_open_player(id))
			v.add_child(b)
	var go := UiKit.btn("To the draft", UiKit.BODY, true)
	go.name = "MeetingDone"
	go.custom_minimum_size.y = 48
	go.pressed.connect(func(): overlay.queue_free())
	(box["footer"] as VBoxContainer).add_child(go)


func _close_player() -> void:
	if is_instance_valid(_detail):
		_detail.queue_free()
	_detail = null
	_detail_id = ""
	_detail_all = false


func _open_player(id: String) -> void:
	var p := _player_by_id(id)
	if p.is_empty():
		return
	var keep_all := _detail_all and id == _detail_id
	_close_player()
	_detail_id = id
	if not _draft.has(id):
		_draft.wanted()[id] = true  # he's on your mind: a rival passing on him says why
	_detail_all = keep_all
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_detail = box["overlay"]
	_detail.name = "PlayerDetail"
	var v: VBoxContainer = box["body"]
	var projected := bool(p.get("projected", false))
	var scouted := projected and _draft.intake_mode
	# Your club's read: a range for anyone you have not drafted (League Draft
	# players too), exact once he is yours.
	var view := _draft.user_view(p)
	var read := bool(view["scouted"])

	# Who he is.
	var name_l := UiKit.lbl(GameDB.player_display_name(p), 22, UiKit.TEXT, true)
	name_l.name = "DetailName"
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var who: PackedStringArray = [Ratings.role_tag(p)]
	if float(p.get("age", 0.0)) > 0.0:
		who.append("%d yo" % int(p["age"]))
	if float(p.get("height_cm", 0.0)) > 0.0 and not projected:
		who.append("%d cm" % int(p["height_cm"]))
	if not projected:
		who.append(GameDB.club_name(str(p["club"])))
	v.add_child(UiKit.lbl("  ·  ".join(who), UiKit.SECONDARY, UiKit.MUTED))
	var ped := PlayerProfile.pedigree(p)
	if ped != "":
		var pl := UiKit.lbl(ped, UiKit.SECONDARY, UiKit.MUTED)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
	var intl_note := InternationalProspects.note(p)
	if intl_note != "":
		var il := UiKit.lbl(intl_note, UiKit.SECONDARY, UiKit.MUTED)
		il.name = "DetailInternational"
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(il)
	var family := FamilyLine.make(p, self)
	if family != null:
		v.add_child(family)
	var status := _draft_status(p)
	var st := UiKit.lbl(status[0], 14, status[1])
	st.name = "DetailStatus"
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)

	# How good, and how much room. National Draft prospects stay inside the
	# club's scouting view rather than revealing hidden true ratings.
	var nums := UiKit.hbox(18)
	v.add_child(nums)
	if read:
		nums.add_child(_big_range(view["overall"], "Projected OVR" if projected else "OVR", "DetailOVR"))
		nums.add_child(_big_range(view["potential"], "POT", "DetailPOT"))
	else:
		nums.add_child(_big_number(int(p["overall"]), "Projected OVR" if projected else "OVR", "DetailOVR"))
		nums.add_child(_big_number(int(p.get("potential", p["overall"])), "POT", "DetailPOT"))
	var room := UiKit.lbl("Scouting estimate" if read else GameState.development_state(p), 14,
			UiKit.MUTED if read else UiKit.TEXT)
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.size_flags_vertical = Control.SIZE_SHRINK_END
	room.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_child(room)
	# His price rides on the Draft button; the intake has none worth a line.

	# What kind of footballer: type, then what he is picked for. Flat, no box.
	v.add_child(UiKit.spacer(4))
	var kv := UiKit.vbox(3)
	v.add_child(kv)
	var type_l := UiKit.lbl(Roles.label(p), UiKit.HEADING, UiKit.TEXT, true)
	type_l.name = "DetailType"
	kv.add_child(type_l)
	var strengths := PlayerProfile.strengths(p)
	if strengths.is_empty():
		kv.add_child(UiKit.lbl("No standout strength yet for his position.", UiKit.SECONDARY, UiKit.MUTED))
	for s in strengths:
		var row := UiKit.hbox(8)
		row.name = "Strength_" + str(s["key"])
		kv.add_child(row)
		var sl := UiKit.lbl(str(s["label"]), 14, UiKit.TEXT)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sl)
		row.add_child(UiKit.line(str(s["grade"]), 14, UiKit.MUTED))
	var weak := PlayerProfile.weakness(p)
	if not weak.is_empty():
		kv.add_child(UiKit.lbl("Needs work: " + str(weak["label"]).to_lower(), UiKit.SECONDARY, UiKit.MUTED))
	var traits: Array = Traits.of(p)
	if not traits.is_empty():
		kv.add_child(UiKit.spacer(4))
		for t in traits:
			var tl := UiKit.lbl("%s. %s" % [Traits.label(str(t)), Traits.scout(str(t))], 13,
					UiKit.BAD if Traits.is_bad(str(t)) else UiKit.TEXT)
			tl.name = "Trait_" + str(t)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			kv.add_child(tl)

	# The Combine: his results on the day (measured, the same for every club),
	# then the scouts' read of what they say about his football.
	if _draft.intake_mode and bool(p.get("projected", false)):
		v.add_child(UiKit.spacer(4))
		var tested_head := UiKit.lbl("Combine testing", UiKit.SECONDARY, UiKit.MUTED, true)
		tested_head.name = "CombineTesting"
		v.add_child(tested_head)
		if not Combine.tested(p, _draft.seed):
			var missed := UiKit.lbl("He missed testing this year.", 14, UiKit.MUTED)
			missed.name = "Tested_none"
			v.add_child(missed)
		for t in (Combine.TESTS if Combine.tested(p, _draft.seed) else []):
			var key := str(t[0])
			var r := Combine.result(p, key, _draft.seed)
			var tr := UiKit.hbox(8)
			tr.name = "Tested_" + key
			var tn := UiKit.lbl(str(t[1]), 14, UiKit.TEXT)
			tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tr.add_child(tn)
			var stand := Combine.standing(key, r, Combine.field(_draft.pool, key, _draft.seed))
			if stand != "":
				tr.add_child(UiKit.line(stand, 13, UiKit.MUTED))
			tr.add_child(UiKit.line(Combine.text(key, r), 14, UiKit.TEXT if r >= 0.0 else UiKit.MUTED, r >= 0.0))
			v.add_child(tr)
	# Seen in your intra-club match (the pre-season): what he did that day.
	var seen_line := PreSeason.seen_line(p, _club) if Features.on("preseason") else ""
	if seen_line != "":
		v.add_child(UiKit.spacer(4))
		var seen_lbl := UiKit.lbl(seen_line, UiKit.SECONDARY, UiKit.TEXT, true)
		seen_lbl.name = "SeenIntraClub"
		seen_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(seen_lbl)
	if scouted:
		v.add_child(UiKit.spacer(4))
		var combine_head := UiKit.lbl("What the scouts saw", UiKit.SECONDARY, UiKit.MUTED, true)
		combine_head.name = "CombineHeading"
		v.add_child(combine_head)
		for result in DraftScouting.combine_lines(p, _club, _draft.seed,
				_draft.scouting_mult_for(_club)):
			var cr := UiKit.hbox(8)
			cr.name = "Combine_" + str(result["label"]).replace(" ", "_").replace("/", "_")
			var cl := UiKit.lbl(str(result["label"]), 14, UiKit.TEXT)
			cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cr.add_child(cl)
			cr.add_child(UiKit.line(str(result["grade"]), 14, UiKit.MUTED))
			v.add_child(cr)
		var combine_note := UiKit.lbl("Testing is one part of the projection; junior football still matters.", UiKit.SMALL, UiKit.MUTED)
		combine_note.name = "CombineNote"
		combine_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(combine_note)

	# What he has done.
	var prod := PlayerProfile.production(p)
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.lbl(str(prod["title"]), UiKit.SECONDARY, UiKit.MUTED))
	var pl2 := UiKit.lbl(str(prod["line"]) if str(prod["line"]) != "" else "No stats on record.",
			14, UiKit.TEXT if str(prod["line"]) != "" else UiKit.MUTED)
	pl2.name = "DetailProduction"
	pl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl2)
	if projected:
		var tie := str(p.get("tied_club", ""))
		if tie != "":
			var kind_word: String = {"FS": "Father-son", "NGA": "Next Generation Academy"}.get(
					str(p.get("tied_type", "")), "Club")
			v.add_child(UiKit.lbl("%s tie to %s" % [kind_word, GameDB.club_name(tie)], 13, UiKit.TEXT))
		var note := str(p.get("note", ""))
		if note != "":
			var nl := UiKit.lbl(note, UiKit.SECONDARY, UiKit.MUTED)
			nl.name = "DetailNote"
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(nl)

	# Established players can expose their exact sheet. A draft prospect cannot:
	# funding changes uncertainty only if hidden ratings remain hidden.
	if not scouted:
		var all := UiKit.btn("Hide full ratings" if _detail_all else "Full ratings", UiKit.SECONDARY)
		all.name = "DetailAllRatings"
		all.custom_minimum_size = Vector2(0, 44)
		all.pressed.connect(func():
			_detail_all = not _detail_all
			_open_player(id))
		v.add_child(all)
		if _detail_all:
			var grid := GridContainer.new()
			grid.name = "DetailAttributes"
			grid.columns = 1 if UiKit.view_width(self) < 520.0 else 2
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 6)
			v.add_child(grid)
			var attr: Dictionary = p["attr"]
			for r in PlayerSheet.ATTR_ROWS:
				grid.add_child(PlayerSheet.attr_bar(str(r[0]), str(r[1]), float(attr.get(r[0], 0.0))))

	# The decision.
	var footer: VBoxContainer = box["footer"]
	var can := _draft.can_pick_player(p)
	# A taken player's status already says where he went.
	if not can and not _draft.has(id):
		var why := _draft.pick_block_reason(p)
		var wl := UiKit.lbl(why if why != "" else "He cannot be picked right now.", UiKit.SECONDARY, UiKit.BAD)
		wl.name = "DetailBlocked"
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.add_child(wl)
	var buttons := UiKit.hbox(8)
	footer.add_child(buttons)
	var close := UiKit.btn("Close", UiKit.BODY)
	close.name = "DetailClose"
	close.custom_minimum_size = Vector2(96, 48)
	close.pressed.connect(_close_player)
	buttons.add_child(close)
	if not _draft.has(id):
		var who_name := GameDB.player_display_name(p)
		var act := UiKit.btn("Sign " + who_name if _draft.intake_mode
				else "Draft %s  ·  %s" % [who_name, Contracts.money(int(p["value"]))], 15, true)
		act.name = "DetailDraft"
		act.clip_text = true
		act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act.custom_minimum_size = Vector2(0, 48)
		act.disabled = not can
		act.pressed.connect(func():
			var target := _player_by_id(id)
			_close_player()
			_on_pick(target))
		buttons.add_child(act)


## [text, colour] for where he stands in this draft.
func _draft_status(p: Dictionary) -> Array:
	var id := str(p["id"])
	if _draft.has(id):
		var club := _draft.drafted_by(id)
		var pick := int(_draft.pick_details(id).get("pick", 0))
		if club == _club or club == "":
			return ["On your list" + (", pick %d" % pick if pick > 0 else ""), UiKit.GOOD]
		return ["Pick %d, %s" % [pick, GameDB.club_name(club)], UiKit.MUTED]
	if _draft.is_finished():
		return ["Not drafted", UiKit.MUTED]
	return ["Available", UiKit.MUTED]


func _big_number(value: int, label: String, node_name: String) -> Control:
	var col := UiKit.vbox(0)
	col.name = node_name
	col.add_child(UiKit.line(str(value), 30, UiKit.TEXT, true))
	col.add_child(UiKit.line(label, 12, UiKit.MUTED))
	return col


func _big_range(values: Array, label: String, node_name: String) -> Control:
	var col := UiKit.vbox(0)
	col.name = node_name
	col.add_child(UiKit.line(DraftScouting.range_text(values), UiKit.TITLE, UiKit.TEXT, true))
	col.add_child(UiKit.line(label, 12, UiKit.MUTED))
	return col


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
	var title_label := UiKit.heading("Pick log", UiKit.H1)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	# The tab already says how many picks: the log's header does not repeat it.
	_history_info = UiKit.line("", 12, UiKit.MUTED)
	_history_info.visible = false
	head.add_child(_history_info)
	var clubs := UiKit.option()
	clubs.name = "PickLogClubFilter"
	clubs.add_item("All clubs · newest first")
	for code in _draft.clubs:
		clubs.add_item(GameDB.club_name(code) + (" (you)" if code == _club else ""))
	clubs.select(0 if _history_club.is_empty() else _draft.clubs.find(_history_club) + 1)
	clubs.item_selected.connect(func(idx: int):
		_history_club = "" if idx == 0 else str(_draft.clubs[idx - 1])
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
	_squad_view.add_child(UiKit.heading("Your list", UiKit.H1))
	_mine_box = UiKit.vbox(5)
	_mine_scroll = UiKit.scroll(_mine_box)
	_squad_view.add_child(_mine_scroll)

	_order_view = UiKit.vbox(6)
	_order_view.name = "DraftOrder"
	_order_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_order_view)
	_order_view.add_child(UiKit.heading("Draft order", UiKit.H1))
	_order_box = UiKit.vbox(4)
	_order_scroll = UiKit.scroll(_order_box)
	_order_view.add_child(_order_scroll)
	return p


func _refresh_history() -> void:
	UiKit.clear(_history_box)
	var entries := []
	# During draft night's replay the log holds back the picks the board has not shown.
	for i in range(_shown_picks() - 1, -1, -1):
		var entry: Dictionary = _draft.pick_history[i]
		if _history_club.is_empty() or str(entry["club"]) == _history_club:
			entries.append(entry)
	_history_info.text = "%d %s" % [entries.size(), "pick" if entries.size() == 1 else "picks"]
	if entries.is_empty():
		_history_box.add_child(UiKit.lbl("No picks yet" if _history_club.is_empty() else "No picks for this club yet", UiKit.HEADING, UiKit.TEXT, true))
		_history_box.add_child(UiKit.lbl(
				"Every selection appears here, including all %d rival clubs. The most recent picks are first." % maxi(1, _draft.clubs.size() - 1), 15, UiKit.MUTED))
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
	# Tapping a pick inspects the player.
	var tap := Button.new()
	tap.name = "HistoryInspect_%d" % int(entry["pick"])
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.mouse_filter = Control.MOUSE_FILTER_PASS
	tap.custom_minimum_size.y = 54
	tap.pressed.connect(_open_player.bind(str(entry.get("player_id", ""))))
	p.add_child(tap)
	var h := UiKit.hbox(7)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.add_child(h)
	var number := UiKit.line("%d" % int(entry["pick"]), UiKit.SECONDARY, UiKit.EMPH if mine else UiKit.MUTED)
	number.custom_minimum_size.x = 32
	h.add_child(number)
	var info := UiKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiKit.ellipsis(_entry_player_name(entry), UiKit.NAME, UiKit.TEXT, true))
	var club_row := UiKit.hbox(6)
	info.add_child(club_row)
	club_row.add_child(UiKit.club_badge(str(entry["club"]), UiKit.SMALL, true))
	# The club code says who picked him; only your own pick and a release say more.
	var tag := "Your pick" if mine else ""
	if bool(entry.get("released", false)):
		tag = "released"
	if tag != "":
		club_row.add_child(UiKit.ellipsis(tag, UiKit.SMALL, UiKit.EMPH if mine else UiKit.MUTED))
	h.add_child(UiKit.role_chip(str(entry["role"])))
	if _draft.intake_mode:
		var picked_player := _player_by_id(str(entry.get("player_id", "")))
		var scout := DraftScouting.projection(picked_player, _club, _draft.seed,
				_draft.scouting_mult_for(_club)) if not picked_player.is_empty() else {}
		var rating := DraftScouting.range_text(scout.get("overall", [])) if not scout.is_empty() else "-"
		p.tooltip_text = "Pick %d · Round %d\n%s selected %s from %s\nScouted %s OVR" % [
				entry["pick"], entry["round"], GameDB.club_name(str(entry["club"])), _entry_player_name(entry),
				str(entry.get("source_club", "")), rating]
	else:
		# Another club's pick is still your recruiters' read of him.
		var seen := str(entry["overall"])
		var who := _player_by_id(str(entry.get("player_id", "")))
		if not who.is_empty() and bool(_draft.user_view(who)["scouted"]):
			seen = DraftScouting.range_text(_draft.user_view(who)["overall"])
		p.tooltip_text = "Pick %d · Round %d\n%s drafted %s from %s\n%s OVR · %s" % [
			entry["pick"], entry["round"], GameDB.club_name(str(entry["club"])), _entry_player_name(entry),
			GameDB.club_name(str(entry["source_club"])), seen, Contracts.money(int(entry["value"]))]
	_ignore_mouse(h)
	return p


func _refresh_mine() -> void:
	UiKit.clear(_mine_box)
	if _draft.intake_mode:
		_mine_box.add_child(UiKit.lbl("%d rookies signed · list %d / %d" % [
			_draft.count(),
			int(GameState.league_lists.get(_club, []).size()), Ratings.LIST_SIZE],
			15, UiKit.EMPH, true))
		_mine_box.add_child(UiKit.lbl(
			"Rookies join the list you kept. There is no cap here; the draft runs until every list is full or the prospects run out.",
			13, UiKit.MUTED))
	else:
		_mine_box.add_child(UiKit.lbl("%d / %d signed · %s of %s spent" % [
			_draft.count(), _draft.target_size, Contracts.money(_draft.spent()), Contracts.money(_draft.budget)], 15, UiKit.EMPH, true))
		_mine_box.add_child(UiKit.lbl(
			"Cover 6 DEF, 6 MID and 6 FWD for the ground. Carry at least 2 RUCK. The bench is flexible; other needs are guidance, not limits.",
			13, UiKit.MUTED))
	var stuck := _draft.can_release()
	if _draft.finished_list_refused():
		var fix := UiKit.lbl("%s Release a player: he goes back into the pool and you pick another." % _draft.invalid_reason(),
				14, UiKit.BAD)
		fix.name = "DraftFix"
		fix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mine_box.add_child(UiKit.spacer(6))
		_mine_box.add_child(fix)
	elif _draft.user_stuck():
		# Only an older save can get here: say so plainly and offer the one
		# legal way on - never a cap breach.
		var why := UiKit.lbl("No player left fits your cap and your list's needs. Release one of your picks to make room: he goes back into the pool and you get an extra pick at the end of the draft.",
				14, UiKit.BAD)
		why.name = "DraftStuck"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mine_box.add_child(UiKit.spacer(6))
		_mine_box.add_child(why)
	_my_picks()
	if _draft.count() == 0:
		_mine_box.add_child(UiKit.spacer(8))
		_mine_box.add_child(UiKit.lbl("Your list starts here.", 20, UiKit.TEXT, true))
		_mine_box.add_child(UiKit.lbl("Select a player from the pool. Tap a position in the pool to find the cover you need.", UiKit.BODY, UiKit.MUTED))
		var pool := UiKit.btn("Explore the player pool", UiKit.BODY, true)
		pool.pressed.connect(func(): _select_tab("pool"))
		_mine_box.add_child(pool)
		return
	_side_shape()
	var counts := _draft.role_counts()
	for role in ROLES:
		_mine_box.add_child(UiKit.spacer(6))
		_mine_box.add_child(UiKit.lbl("%s  /  %d" % [str(UiKit.ROLE_LABEL[role]), counts[role]],
				13, UiKit.ROLE_COLOUR[role], true))
		for player in _draft.list():
			if str(player["role"]) == role:
				var entry := _draft.pick_details(str(player["id"]))
				var p := _row_panel(false)
				var v := UiKit.vbox(2)
				p.add_child(v)
				var picked_name := UiKit.ellipsis(GameDB.player_display_name(player), UiKit.NAME, UiKit.TEXT, true)
				picked_name.name = "PickedName_" + str(player["id"])
				v.add_child(NameLink.tappable(picked_name, str(player["id"])))
				if _draft.intake_mode:
					var scout := DraftScouting.projection(player, _club, _draft.seed,
							_draft.scouting_mult_for(_club))
					v.add_child(UiKit.lbl("Pick %d · scouted %s OVR" % [
							int(entry.get("pick", 0)), DraftScouting.range_text(scout["overall"])],
							12, UiKit.MUTED))
				else:
					v.add_child(UiKit.lbl("Pick %d · %d OVR · %s" % [
							int(entry.get("pick", 0)), int(player["overall"]), Contracts.money(int(player["value"]))],
							12, UiKit.MUTED))
				if stuck:
					var row := UiKit.hbox(8)
					v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					p.remove_child(v)
					row.add_child(v)
					var rel := UiKit.btn("Release", 14)
					rel.name = "Release_" + str(player["id"])
					rel.custom_minimum_size = Vector2(92, 44)
					rel.pressed.connect(_on_release.bind(str(player["id"])))
					row.add_child(rel)
					p.add_child(row)
				_mine_box.add_child(p)


## Your side so far against every club's, line by line, in the words the
## selection screen uses ("Ruck: among the weakest."). Facts only: which
## player would fix it is the coach's call. From SHAPE_FROM picks, when a
## side is enough of a side to compare; not at the intake draft.
const SHAPE_FROM := 8

func _side_shape() -> void:
	if _draft.intake_mode or _draft.count() < SHAPE_FROM:
		return
	var own := Squad.new(_club, _draft.club_lists[_club], false, _club)
	var box := UiKit.vbox(2)
	box.name = "SideShape"
	_mine_box.add_child(UiKit.spacer(8))
	box.add_child(UiKit.lbl("Your side so far, against the league", UiKit.BODY, UiKit.TEXT, true))
	for row in Matchup.standing(_club, _draft.club_lists, {}, own):
		box.add_child(UiKit.lbl("%s: %s." % [str(row[0]), str(row[1])], UiKit.BODY, UiKit.TEXT))
	_mine_box.add_child(box)


func _on_release(id: String) -> void:
	if _draft.release_for_room(id):
		_refresh()


func _refresh_order() -> void:
	UiKit.clear(_order_box)
	var by_pick := {}
	for e in _draft.pick_history:
		by_pick[int(e["pick"])] = e
	var round_no := _draft.current_round() if _draft.intake_mode else mini(_draft.current_round(), _draft.target_size)
	var going_back := round_no % 2 == 0 and not _draft.intake_mode
	_order_box.add_child(UiKit.lbl(("Round %d" % round_no) if _draft.intake_mode
			else ("Round %d of %d" % [round_no, _draft.target_size]), UiKit.SMALL, UiKit.MUTED, true))
	var direction := UiKit.heading("‹ Order" if going_back else "Order ›", UiKit.H1)
	direction.add_theme_color_override("font_color", UiKit.EMPH)
	_order_box.add_child(direction)
	_order_box.add_child(UiKit.lbl(
			("Every round runs in the same order, worst club first. Highlighted club = you." if _draft.intake_mode
			else "The arrow is the way this round's order runs. It flips every round. Highlighted club = you."),
			13, UiKit.MUTED))
	var start := (round_no - 1) * _draft.clubs.size()
	var end := mini(start + _draft.clubs.size(), _draft.pick_sequence.size())
	if _draft.pick_rounds.size() == _draft.pick_sequence.size() and not _draft.pick_rounds.is_empty():
		# Compensation picks sit inside their round: list the round as drafted.
		start = _draft.pick_rounds.find(round_no)
		end = start
		while end < _draft.pick_rounds.size() and int(_draft.pick_rounds[end]) == round_no:
			end += 1
	for index in range(maxi(0, start), end):
		var code := str(_draft.pick_sequence[index])
		var mine := code == _club
		var p := _row_panel(mine)
		var h := UiKit.hbox(7)
		p.add_child(h)
		var arrow := UiKit.line("‹" if going_back else "›", UiKit.NAME, UiKit.EMPH, true)
		arrow.custom_minimum_size.x = 16
		h.add_child(arrow)
		var number := UiKit.line("%d" % (index + 1), UiKit.SECONDARY, UiKit.MUTED)
		number.custom_minimum_size.x = 34
		h.add_child(number)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		# The club by its guernsey and name, as the ladder shows it.
		var badge := UiKit.club_badge(code, 14, false, true)
		badge.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.add_child(badge)
		var description := "Up next"
		if index == _draft.pick_index and not _draft.is_finished():
			description = "On the clock"
		elif index < _draft.pick_index:
			var entry: Dictionary = by_pick.get(index + 1, {})
			description = _entry_player_name(entry) if not entry.is_empty() \
					else "passed"
		v.add_child(UiKit.ellipsis(description, UiKit.SMALL, UiKit.MUTED))
		# Where the club is in its cycle and its list today (TeamRating).
		var outlook := GameState.team_outlook(code)
		if not outlook.is_empty():
			var tl := UiKit.ellipsis("%s · %d" % [str(outlook["category"]), int(outlook["rating"])], UiKit.SMALL, UiKit.MUTED)
			tl.name = "OrderOutlook_%d" % index
			v.add_child(tl)
		var comp := _draft.comp_at(index)
		if not comp.is_empty():
			var why := UiKit.ellipsis("Compensation for losing %s" % str(comp.get("name", "a free agent")), UiKit.SMALL, UiKit.TEXT)
			why.name = "CompPick"
			v.add_child(why)
		elif _draft.intake_mode and index < _draft.pick_origin.size():
			# How the club got this pick, on every row: its own, or from whom and for what.
			var traded := str(_draft.pick_origin[index]) != code
			var story := _story_line(GameState.pick_story(GameState.season_year,
					int(_draft.pick_rounds[index]), str(_draft.pick_origin[index])))
			story.name = "ViaPick" if traded else "OwnPick"
			v.add_child(story)
		elif index < _draft.pick_origin.size() and str(_draft.pick_origin[index]) != code:
			var via := UiKit.ellipsis("Via %s" % GameDB.club_name(str(_draft.pick_origin[index])), UiKit.SMALL, UiKit.TEXT)
			via.name = "ViaPick"
			v.add_child(via)
		var made_text := ("%d signed" % _draft.count_for(code)) if _draft.intake_mode \
				else ("%d/%d" % [_draft.count_for(code), _draft.pick_limit(code)])
		h.add_child(UiKit.line(made_text, 12, UiKit.EMPH if mine else UiKit.MUTED))
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
	if _draft.intake_mode:
		pass   # "N prospects left" is the live board's (_refresh_live)
	else:
		# The cap you have, and what you can actually spend on this pick once
		# enough is kept to fill the rest of your list.
		var usable := maxi(0, _draft.usable_cap_for(_club))
		if _draft.count() >= _draft.target_size:
			_cap.text = "Cap left %s\nList complete" % Contracts.money(_draft.remaining())
		elif usable < _draft.remaining():
			_cap.text = "Cap left %s\nUp to %s this pick" % [Contracts.money(_draft.remaining()), Contracts.money(usable)]
		else:
			_cap.text = "Cap left %s\n%s spent" % [Contracts.money(_draft.remaining()), Contracts.money(_draft.spent())]
	var status := _draft.position_status()
	for role in ROLES:
		var st: Dictionary = status[role]
		_role_labels[role].text = "%s %d" % [role, int(st["count"])]
		_need_labels[role].text = Draft.need_word(st, role)
		_need_labels[role].add_theme_color_override("font_color",
				UiKit.BAD if int(st["short"]) > 0 else UiKit.MUTED)
	var upcoming := _draft.upcoming_picks(_club, 3)
	var pick_labels := []
	for number in upcoming:
		pick_labels.append("%d" % int(number))
	if _draft.intake_mode:
		# The board says the next pick; the footer the ones after it.
		var later := pick_labels.slice(1)
		_next_picks.text = "%d signed" % _draft.count()
		if not later.is_empty():
			_next_picks.text += "\n%s: %s" % ["Your next pick" if later.size() == 1 else "Your next picks", ", ".join(later)]
	else:
		_next_picks.text = "%d left to sign\nYour picks: %s" % [_draft.target_size - _draft.count(), ", ".join(pick_labels)]
	var my_turn := _draft.is_user_turn()
	_pick_me_btn.disabled = not my_turn
	_pick_me_btn.tooltip_text = "The assistant takes the best available player for this one pick." if my_turn else "Waiting for your turn."
	if _pass_btn != null:
		var pass_why := _draft.pass_block_reason()
		_pass_btn.disabled = pass_why != ""
		_pass_btn.tooltip_text = "You take no more players in this draft." if pass_why == "" else pass_why
		if my_turn and pass_why != "":
			_next_picks.text += "\n" + pass_why
	_finish_btn.disabled = not (done and _draft.is_valid())
	if _draft.intake_mode:
		_finish_btn.tooltip_text = \
				"The draft concludes when every pick is made or the pool runs dry."
	else:
		_finish_btn.tooltip_text = "Complete your list within the cap, including at least 2 rucks."
	if _draft.user_stuck():
		_next_picks.text = "No player fits your cap and list.\nRelease a pick on My list."
	if done:
		# The footer says what is true of this list. The rules let a full list
		# within the cap start even when a position is short, so the button is
		# live then and the footer says who will have to fill in.
		var invalid := _draft.invalid_reason()
		var short := _draft.short_positions()
		if invalid != "":
			_next_picks.text = invalid + ("\nRelease a player on My list to fix it."
					if _draft.finished_list_refused() else "\nStart season waits until that is fixed.")
		elif short != "":
			_next_picks.text = "Short %s.\nOthers will have to fill in." % short
		else:
			_next_picks.text = "Your list is ready.\nTime for round one."

	_refresh_live()
	_refresh_why()


## The live board from the pick history: everything, or during a replay the
## first `_shown_upto` picks with the next one's club on the clock. `settle`
## eases the newest pick in.
func _refresh_live(settle := false) -> void:
	if not is_instance_valid(_status):
		return
	var hist: Array = _draft.pick_history
	var upto := hist.size() if _shown_upto < 0 else mini(_shown_upto, hist.size())
	if _stage_pick >= 0:
		# The stage is reading your pick: the board stays on it until the stage has gone.
		upto = mini(_stage_pick, hist.size())
	var clock_club := ""
	var clock_pick := 0
	var clock_round := 0
	if upto < hist.size():
		clock_club = str(hist[upto]["club"])
		clock_pick = int(hist[upto]["pick"])
		clock_round = int(hist[upto]["round"])
	elif not _draft.is_finished():
		clock_club = _draft.current_club()
		clock_pick = _draft.pick_index + 1
		clock_round = _draft.current_round()
	var done := clock_club == ""
	_hang(_club if done else clock_club)
	if _draft.intake_mode:
		# Each pick not yet replayed still has its prospect in the pool.
		_cap.text = "%d prospects left" % (_draft.remaining_pool() + hist.size() - upto)
	if done:
		_status.text = "Draft complete"
		_status.add_theme_color_override("font_color", UiKit.GOOD if _draft.is_valid() else UiKit.BAD)
	else:
		_status.text = DraftNight.clock_line(clock_pick, clock_club)
		_status.add_theme_color_override("font_color", UiKit.club_ink(clock_club))
	if _short:
		_round_info.text = "%s · %d signed · R%d" % [_club, _draft.count(), _draft.current_round()]
		if not _draft.intake_mode:
			_round_info.text = "%s · %d/%d signed · R%d/%d" % [_club, _draft.count(),
					_draft.target_size, mini(_draft.current_round(), _draft.target_size), _draft.target_size]
	elif done:
		_round_info.text = "%d picks made" % hist.size()
	elif _draft.intake_mode:
		# Rounds run until lists are full, so there is no fixed total to show.
		_round_info.text = "Round %d" % clock_round
	else:
		_round_info.text = "Round %d of %d" % [mini(clock_round, _draft.target_size), _draft.target_size]
	if is_instance_valid(_your_pick):
		_your_pick.text = "" if _stage_pick >= 0 else _your_pick_words(clock_pick, done)
		_your_pick.visible = _your_pick.text != ""
	if is_instance_valid(_recent_box):
		_recent_rows(hist, upto, settle)
		_recent_box.visible = _recent_wanted()


## "Your pick: 14, two away", or why there is none.
func _your_pick_words(clock_pick: int, done: bool) -> String:
	if done:
		return ""
	if _draft.passed_clubs.has(_club):
		return "You have passed: no more picks"
	if _draft._list_full(_club):
		return "Your list is full"
	var upcoming := _draft.upcoming_picks(_club, 1)
	if upcoming.is_empty():
		return "No picks left"
	return DraftNight.your_pick_line(int(upcoming[0]), clock_pick)


## The last three picks the board shows, newest first: number, guernsey, name
## and club; two on a phone shorter than RECENT_TALL, so the pool keeps its room
## (on PC they sit beside the club on the clock and take no height).
const RECENT := 3
const RECENT_TALL := 780.0


## The last-three strip only where nothing else says the same picks: not beside
## the pick log (PC), and not while the stage reads your pick (phone).
func _recent_wanted() -> bool:
	if _wide and _side_tab == "picks":
		return false
	return not is_instance_valid(_beat)


func _recent_rows(hist: Array, upto: int, settle: bool) -> void:
	UiKit.clear(_recent_box)
	if upto == 0:
		var none := UiKit.lbl("No picks yet.", UiKit.SECONDARY, UiKit.MUTED)
		none.name = "RecentNone"
		_recent_box.add_child(none)
		return
	var shown := RECENT if _wide or _usable_size().y >= RECENT_TALL else RECENT - 1
	for i in range(upto - 1, maxi(-1, upto - 1 - shown), -1):
		var entry: Dictionary = hist[i]
		var code := str(entry["club"])
		var mine := code == _club
		var row := UiKit.hbox(8)
		row.name = "RecentPick_%d" % int(entry["pick"])
		var number := UiKit.line("%d" % int(entry["pick"]), UiKit.SECONDARY, UiKit.TEXT if mine else UiKit.MUTED, mine)
		number.custom_minimum_size.x = 26
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number)
		var marker := UiKit.club_marker(code, 20.0)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(marker)
		# Phone: the name takes the row and the club sits at its end. PC: the club
		# straight after the name, so the eye does not cross an empty row.
		var who := UiKit.line(_entry_player_name(entry), UiKit.SECONDARY, UiKit.TEXT, mine) if _wide \
				else UiKit.ellipsis(_entry_player_name(entry), UiKit.SECONDARY, UiKit.TEXT, mine)
		if not _wide:
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		row.add_child(UiKit.line(GameDB.club_short(code), UiKit.SECONDARY, UiKit.club_ink(code), mine))
		_ignore_mouse(row)
		_recent_box.add_child(row)
		if settle and i == upto - 1 and UiKit.motion_on():
			# The newest pick fades in while the older rows slide down a row.
			row.modulate.a = 0.0
			row.create_tween().tween_property(row, "modulate:a", 1.0, RECENT_SETTLE) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if settle and UiKit.motion_on():
		_slide_recent.call_deferred()


## Seconds the newest pick takes to fade in, and the older ones to slide down.
const RECENT_SETTLE := 0.12


## After the board's layout: each older row starts one row higher (where it
## was) and slides down into its place.
func _slide_recent() -> void:
	if not is_instance_valid(_recent_box):
		return
	var rows: Array = _recent_box.get_children().filter(func(c): return c is Control and c.visible \
			and str(c.name).begins_with("RecentPick_"))
	if rows.size() < 2:
		return
	var step: float = (rows[1] as Control).position.y - (rows[0] as Control).position.y
	for k in range(1, rows.size()):
		var row := rows[k] as Control
		var home := row.position.y
		row.position.y = home - step
		row.create_tween().tween_property(row, "position:y", home, RECENT_SETTLE) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Since your last pick, why a rival took a prospect you had opened (or, if
## none was taken, why the latest club passed on one): one line, the club in
## its ink, nothing when you opened no one (P-18).
func _refresh_why() -> void:
	if not is_instance_valid(_why_box):
		return
	UiKit.clear(_why_box)
	# During draft night's stage and replay the rival picks are not all shown yet:
	# the reason waits for the board to catch up.
	if replaying() or _stage_pick >= 0:
		return
	var e := _why_entry()
	if e.is_empty():
		return
	var club := str(e["club"])
	var index := {GameDB.club_name(club): club}
	var line := NameInk.label(_draft.wanted_line(e, func(q: Dictionary) -> String:
			return GameDB.player_display_name(q) if not q.is_empty() else "another player"), index, UiKit.SMALL, UiKit.TEXT)
	line.name = "RivalWhyLine"
	if line is Label:
		(line as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why_box.add_child(line)


func _why_entry() -> Dictionary:
	var since := 0
	for i in range(_draft.pick_history.size() - 1, -1, -1):
		if str(_draft.pick_history[i]["club"]) == _club:
			since = int(_draft.pick_history[i]["pick"])
			break
	var pass_entry := {}
	for i in range(_draft.wanted_news().size() - 1, -1, -1):
		var e: Dictionary = _draft.wanted_news()[i]
		if int(e["pick"]) <= since:
			break
		if str(e["code"]).begins_with("draft_took"):
			return e
		if pass_entry.is_empty() and not _draft.picked.has(str(e["player_id"])):
			pass_entry = e
	return pass_entry


func _on_finish() -> void:
	if _draft.intake_mode:
		if GameState.finish_intake_draft():
			Router.replace("hub")
		return
	if not _draft.is_finished() or not _draft.is_valid():
		return
	GameState.start_season(_club, _draft.list())
	# A new career's first season starts with a pre-season, like every other.
	GameState.open_preseason()
	Router.go("hub")


## How a pick was got, in a line that wraps; the players it names wear their
## club's ink. One ink for every line, own or traded: both are facts to read.
func _story_line(text: String) -> Control:
	if _name_index.is_empty() and GameState.season != null:
		_name_index = NameInk.from_lists(GameState.season.lists)
	var l := NameInk.label(text, _name_index, UiKit.SMALL, UiKit.TEXT)
	if l is Label:
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Your picks in this draft, each with how you got it and who you took with
## it. National Draft only.
func _my_picks() -> void:
	if not _draft.intake_mode:
		return
	var by_pick := {}
	for e in _draft.pick_history:
		by_pick[int(e["pick"])] = e
	var box := UiKit.vbox(3)
	box.name = "MyPicks"
	box.add_child(UiKit.lbl("Your picks", 13, UiKit.EMPH, true))
	var shown := 0
	for index in range(_draft.pick_sequence.size()):
		if str(_draft.pick_sequence[index]) != _club:
			continue
		var comp := _draft.comp_at(index)
		var story := ("Compensation for losing %s" % str(comp.get("name", "a free agent"))) if not comp.is_empty() else GameState.pick_story(GameState.season_year, int(_draft.pick_rounds[index]), str(_draft.pick_origin[index]))
		var taken := ""
		if index < _draft.pick_index:
			var entry: Dictionary = by_pick.get(index + 1, {})
			taken = _entry_player_name(entry) if not entry.is_empty() else "passed"
		var row := UiKit.vbox(1)
		row.name = "MyPick_%d" % (index + 1)
		row.add_child(UiKit.lbl("No. %d  ·  Round %d%s" % [index + 1, int(_draft.pick_rounds[index]),
				("  ·  " + taken) if taken != "" else ""], UiKit.BODY, UiKit.TEXT, true))
		var line := _story_line(story)
		line.name = "MyPickStory_%d" % (index + 1)
		row.add_child(line)
		box.add_child(row)
		shown += 1
		if shown >= 8:
			break
	if shown > 0:
		_mine_box.add_child(box)
		_mine_box.add_child(UiKit.spacer(6))


func _row_panel(mine: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := UiKit.style(UiKit.PANEL_ALT if mine else Color.TRANSPARENT, 7, 4)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 1
	if mine:
		sb.border_width_left = 2
		sb.border_color = UiKit.EMPH
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.y = 62
	return p


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child)


## A secondary line of a pool row: wraps, never cut (style guide: names and
## the facts that decide never truncate).
func _row_line(text: String, colour: Color, bold := false) -> Label:
	var l := UiKit.lbl(text, UiKit.SECONDARY, colour, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
