extends Control
## Coaching: the club from the coach's box. What the list is good at against
## this league, how we play (the standing game
## plan, then how we win and how we get beaten), who is in and out of form,
## the list and the cap, the board, and the staff. Plain football first;
## the supporting number comes after it. Facts, never advice.

var _root: VBoxContainer
var _sheet: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(10)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_build)
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Coaching", true))
	var body := UiKit.vbox(UiKit.SECTION)
	body.name = "CoachingBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_list_profile())
	body.add_child(_how_we_play())
	body.add_child(_form())
	body.add_child(_list_and_cap())
	var board := _board()
	if board != null:
		body.add_child(board)
	body.add_child(_staff())
	_root.add_child(UiKit.scroll(body))


func _narrow() -> bool:
	return UiKit.view_width(self) < 560.0


func _wrapped(text: String, fs := UiKit.BODY, col := UiKit.AUTO_COLOUR) -> Label:
	if col == UiKit.AUTO_COLOUR:
		col = UiKit.TEXT
	var l := UiKit.lbl(text, fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ---------------------------------------------------------------------------
# List profile: six strengths, a word each, against this league. A tap on
# one says what it is and who leads it; nothing says what to do about it.
# ---------------------------------------------------------------------------
func _list_profile() -> Control:
	var v := UiKit.vbox(0)
	v.name = "ListProfile"
	v.add_child(UiKit.section("List profile"))
	v.add_child(_wrapped("Your side as picked, against every list in the league.", UiKit.SMALL, UiKit.MUTED))
	v.add_child(UiKit.spacer(4))
	var ground: Array = GameState.my_squad().ground
	for row in GameState.list_profile():
		v.add_child(_profile_row(row, ground))
	return v


func _profile_row(row: Dictionary, ground: Array) -> Control:
	var dim := str(row["dim"])
	var box := UiKit.vbox(2)
	var b := Button.new()
	b.name = "Profile_%s" % dim
	b.flat = true
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var h := UiKit.hbox(8)
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_l := UiKit.line(str(row["label"]), UiKit.BODY, UiKit.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_l)
	var word := UiKit.line(str(row["word"]), UiKit.BODY, UiKit.TEXT, true)
	word.name = "Word"
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(word)
	var pad := Control.new()
	pad.custom_minimum_size.x = 10    # clear of the scroll bar
	h.add_child(pad)
	for n in h.find_children("*", "Control", true, false) + [h]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(b)
	var names := PackedStringArray()
	for p in ListProfile.leaders(ground, dim):
		names.append(GameDB.player_display_name(p))
	var detail := _wrapped("%s Leading it: %s." % [str(ListProfile.MEANS[dim]), ", ".join(names)],
			UiKit.SMALL, UiKit.MUTED)
	detail.name = "Detail"
	detail.visible = false
	box.add_child(detail)
	b.pressed.connect(func(): detail.visible = not detail.visible)
	return box


# ---------------------------------------------------------------------------
# How we play
# ---------------------------------------------------------------------------
func _how_we_play() -> Control:
	var v := UiKit.vbox(6)
	v.name = "HowWePlay"
	v.add_child(UiKit.section("How we play"))
	var opts := []
	for key in GameState.CLUB_PLANS:
		opts.append([key, CoachReport.plan_label(key)])
	var note := _wrapped(CoachReport.plan_summary(GameState.club_plan), UiKit.SMALL, UiKit.MUTED)
	note.name = "PlanNote"
	var ground: Array = GameState.my_squad().ground
	var fit := _wrapped(GameState.plan_fit_line(ground, GameState.club_plan), UiKit.SMALL, UiKit.TEXT)
	fit.name = "PlanFit"
	fit.visible = fit.text != ""
	v.add_child(UiKit.choice_grid("ClubPlan", opts, GameState.club_plan, 2 if _narrow() else 3,
			func(key):
				GameState.set_club_plan(str(key))
				note.text = CoachReport.plan_summary(str(key))
				fit.text = GameState.plan_fit_line(ground, str(key))
				fit.visible = fit.text != ""))
	v.add_child(note)
	v.add_child(fit)
	v.add_child(_wrapped("Every match starts on this plan. Change it at any break.",
			UiKit.SMALL, UiKit.MUTED))

	var style := GameState.how_we_play()
	if int(style["games"]) < 3:
		v.add_child(UiKit.spacer(4))
		v.add_child(_wrapped("After three games, how your side wins and gets beaten shows here.",
				UiKit.BODY, UiKit.MUTED))
		return v
	for part in [["How we win", "win", "WinLine"], ["How we get beaten", "beaten", "BeatenLine"]]:
		var lines: Array = style[part[1]]
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl(str(part[0]), UiKit.BODY, UiKit.TEXT, true))
		if lines.is_empty():
			v.add_child(_wrapped("Nothing stands out yet.", UiKit.BODY, UiKit.MUTED))
		for i in range(lines.size()):
			var l := _wrapped(str(lines[i]))
			l.name = "%s_%d" % [part[2], i]
			v.add_child(l)
	return v


# ---------------------------------------------------------------------------
# Form
# ---------------------------------------------------------------------------
func _form() -> Control:
	var v := UiKit.vbox(4)
	v.name = "Form"
	v.add_child(UiKit.section("Recent games"))
	var form := GameState.player_form()
	if (form["hot"] as Array).is_empty() and (form["cold"] as Array).is_empty():
		v.add_child(_wrapped("Nobody is playing well above or below their usual level.",
				UiKit.BODY, UiKit.MUTED))
		return v
	# Who is in and out of form, by name. The comparison (last three games
	# against the season, GameState.player_form) stays behind the words.
	for part in [["In good form", "hot"], ["In poor form", "cold"]]:
		var rows: Array = form[part[1]]
		if rows.is_empty():
			continue
		var head := UiKit.lbl(str(part[0]), UiKit.BODY, UiKit.TEXT, true)
		head.name = "FormHead_%s" % part[1]
		v.add_child(head)
		for row in rows:
			v.add_child(_form_row(row, str(part[1])))
		v.add_child(UiKit.spacer(4))
	return v


func _form_row(row: Dictionary, kind: String) -> Control:
	var p := GameState.list_player(str(row["id"]))
	var b := Button.new()
	b.name = "Form_%s_%s" % [kind, str(row["id"])]
	b.flat = true
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var name_l := UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(name_l)
	name_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): _sheet = PlayerSheet.open(self, p, func(): _sheet = null))
	return b


# ---------------------------------------------------------------------------
# List and cap
# ---------------------------------------------------------------------------
func _list_and_cap() -> Control:
	var v := UiKit.vbox(4)
	v.name = "ListAndCap"
	v.add_child(UiKit.section("List and cap"))
	var line := "%d players on the list" % GameState.my_list.size()
	if GameState.salary_cap > 0:
		var room := GameState.cap_room()
		line += "  ·  payroll %d of %d  ·  %s" % [GameState.my_payroll(), GameState.salary_cap,
				("%d under the cap" % room) if room >= 0 else ("%d over the cap" % -room)]
	var l := _wrapped(line)
	l.name = "CapLine"
	v.add_child(l)
	var b := UiKit.btn("My list", 15)
	b.name = "OpenList"
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func(): Router.go("list"))
	v.add_child(b)
	return v


# ---------------------------------------------------------------------------
# Board
# ---------------------------------------------------------------------------
func _board() -> Control:
	if GameState.board_goal_text() == "":
		return null
	var v := UiKit.vbox(4)
	v.name = "Board"
	v.add_child(UiKit.section("The board"))
	var state := GameState.board_state()
	var col := UiKit.GOOD if state in ["Very secure", "Secure"] \
			else (UiKit.TEXT if state == "Stable" else UiKit.BAD)
	var l := UiKit.lbl(state, UiKit.H2, col, true)
	l.name = "BoardConfidence"
	v.add_child(l)
	v.add_child(_wrapped("Their goal: %s" % GameState.board_goal_text()))
	if GameState.board_why() != "":
		var why := _wrapped(GameState.board_why(), UiKit.BODY, UiKit.MUTED)
		why.name = "BoardWhy"
		v.add_child(why)
	if bool(GameState.board.get("warned", false)):
		v.add_child(_wrapped("You are on a final warning.", UiKit.BODY, UiKit.BAD))
	return v


# ---------------------------------------------------------------------------
# Staff
# ---------------------------------------------------------------------------
func _staff() -> Control:
	var v := UiKit.vbox(0)
	v.name = "Staff"
	v.add_child(UiKit.section("Staff"))
	v.add_child(UiKit.spacer(4))
	var staff := GameState.club_staff(GameState.my_club)
	var open := {}
	for vac in GameState.staff_vacancies:
		open[str(vac["job"])] = true
	for job in Coaches.JOBS:
		if job == "SC":
			continue
		if open.has(job) or not staff.has(job):
			v.add_child(_staff_row(job, {}))
		else:
			v.add_child(_staff_row(job, staff[job]))
	v.add_child(UiKit.spacer(6))
	var jobs := GameState.staff_vacancies.size()
	var b := UiKit.btn("Staff" if jobs == 0 else "Staff  ·  %d to fill" % jobs, 15, jobs > 0)
	b.name = "OpenStaff"
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func(): Router.go("staff"))
	v.add_child(b)
	return v


func _staff_row(job: String, c: Dictionary) -> Control:
	var b := Button.new()
	b.name = "StaffLine_" + job
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_NONE
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", UiKit.BODY)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var label := str(Coaches.JOB_LABEL[job])
	if c.is_empty():
		b.text = "%s  ·  vacant" % label
		b.add_theme_color_override("font_color", UiKit.MUTED)
		b.pressed.connect(func(): Router.go("staff"))
	else:
		b.text = "%s  ·  %s" % [label, GameDB.player_display_name(c)]
		b.add_theme_color_override("font_color", UiKit.TEXT)
		b.pressed.connect(func(): _sheet = CoachSheet.open(self, c, func(): _sheet = null))
	return b


## Router back hook: close a profile first.
func handle_back() -> bool:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
		_sheet = null
		return true
	return false
