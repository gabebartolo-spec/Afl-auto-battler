extends Control
## A club's coaching staff: six jobs, one row each. At your club the senior
## coach is you; the other five work for you. Tap a coach for his profile.
## Other clubs' staffs are one tap away. After the season your open jobs
## show a shortlist (appoint or auto-fill) and assistants can be released.

var _root: VBoxContainer
var _club := ""
var _sheet: Control
var _others_open := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	_club = GameState.my_club
	# Your club's colour behind the page, as on the hub and match day
	# (director, 2026-10-10: every screen in the gameday style).
	add_child(ClubBackdrop.new().setup(GameState.my_club))
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
	var mine := _club == GameState.my_club
	_root.add_child(UiKit.top_bar("Staff", true))
	var body := UiKit.vbox(0)
	body.name = "StaffRows"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UiKit.lbl(GameDB.club_name(_club), UiKit.H2, UiKit.TEXT, true)
	head.name = "StaffClub"
	body.add_child(head)
	body.add_child(UiKit.spacer(6))
	var staff := GameState.club_staff(_club)
	var open := {}
	if mine:
		for v in GameState.staff_vacancies:
			open[str(v["job"])] = v
	# A PC lays the staff out as cards across the screen, not one stretched
	# column (director, 2026-10-10: no phone UI on a PC).
	var w := UiKit.view_width(self)
	var wide := ScreenLayout.is_desktop() and w >= 760.0 and w > UiKit.view_height(self) * 1.2
	var grid: GridContainer = null
	if wide:
		grid = GridContainer.new()
		grid.name = "StaffGrid"
		grid.columns = 3 if w >= 1100.0 else 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		body.add_child(grid)
	for job in Coaches.JOBS:
		var row: Control
		if job == "SC" and mine:
			row = _you_row()
		elif open.has(job):
			row = _vacancy_card(job, open[job])
		elif staff.has(job):
			row = _coach_row(job, staff[job], mine and GameState.can_release_staff())
		else:
			row = _empty_row(job)
		if grid != null:
			var card := UiKit.panel(UiKit.PANEL, 14)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_child(row)
			grid.add_child(card)
		else:
			body.add_child(row)
			body.add_child(UiKit.rule())

	body.add_child(UiKit.spacer(14))
	var others := UiKit.btn("Your club" if not mine else "Another club's staff", UiKit.BODY)
	others.name = "OtherClubs"
	# On a PC it reads as a button (an outline), not a stray line of text.
	others.flat = not _others_open and not wide
	if wide:
		others.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		others.custom_minimum_size = Vector2(220, 44)
	others.pressed.connect(func():
		if not mine:
			_club = GameState.my_club
			_others_open = false
		else:
			_others_open = not _others_open
		_build())
	body.add_child(others)
	if _others_open and mine:
		var opts := []
		for code in GameDB.active_clubs(GameState.season_year):
			if code != GameState.my_club:
				opts.append([code, GameDB.club_short(code)])
		var cols := 3 if UiKit.view_width(self) < 520.0 else 6
		body.add_child(UiKit.choice_grid("StaffClubPick", opts, "", cols, func(code):
			_club = str(code)
			_others_open = false
			_build()))
	_root.add_child(UiKit.scroll(body))


## You: the senior coach's calls are yours, so there are no grades to show.
func _you_row() -> Control:
	var v := UiKit.vbox(1)
	v.name = "StaffRow_SC"
	v.custom_minimum_size.y = 64
	v.add_child(UiKit.lbl("Senior coach", UiKit.SMALL, UiKit.MUTED))
	v.add_child(UiKit.lbl("You", UiKit.BODY, UiKit.TEXT, true))
	var l := UiKit.lbl("Selection, tactics and training are your calls.", UiKit.SMALL, UiKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return _padded(v)


func _coach_row(job: String, c: Dictionary, releasable := false) -> Control:
	var b := Button.new()
	b.name = "StaffRow_" + job
	b.flat = true
	b.custom_minimum_size.y = 68
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var v := UiKit.vbox(1)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UiKit.lbl(str(Coaches.JOB_LABEL[job]), UiKit.SMALL, UiKit.MUTED))
	v.add_child(UiKit.ellipsis(GameDB.player_display_name(c), UiKit.BODY, UiKit.TEXT, true))
	v.add_child(UiKit.lbl(Coaches.headline(c), UiKit.SMALL, UiKit.TEXT))
	for n in v.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func(): _sheet = CoachSheet.open(self, c))
	var expiring := releasable and GameState.expiring_staff().has(c)
	if expiring:
		var stance := CoachMarket.assistant_stance(c, GameState.season_year)
		var term := UiKit.lbl("Contract ends. " + str(stance["text"]), UiKit.SMALL, UiKit.EMPH)
		term.name = "ContractEnds_" + job
		term.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(term)
		b.custom_minimum_size.y = 92
	if not releasable:
		return b
	# The offseason: an assistant can be let go (no payout, no negotiation);
	# one whose term is up can also be kept, on his terms.
	var h := UiKit.hbox(8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(b)
	if expiring:
		var keep := UiKit.btn("Re-sign", 14)
		keep.name = "Resign_" + job
		keep.custom_minimum_size = Vector2(92, 44)
		keep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keep.pressed.connect(func():
			GameState.resign_staff(str(c["cid"]))
			_build())
		h.add_child(keep)
	var rel := UiKit.btn("Release", 14)
	rel.name = "Release_" + job
	rel.custom_minimum_size = Vector2(92, 44)
	rel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel.pressed.connect(func():
		GameState.release_staff(str(c["cid"]))
		_build())
	h.add_child(rel)
	return h


## One of your jobs is open: why, a short list to choose from, or let the
## club pick (the same judgement the AI clubs use).
func _vacancy_card(job: String, vac: Dictionary) -> Control:
	var v := UiKit.vbox(6)
	v.name = "Vacancy_" + job
	v.add_child(UiKit.lbl("%s vacancy" % _job_title(job), UiKit.BODY, UiKit.TEXT, true))
	if str(vac.get("reason", "")) != "":
		var why := UiKit.lbl(str(vac["reason"]), UiKit.SMALL, UiKit.MUTED)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(why)
	var list := GameState.staff_shortlist(job)
	for i in range(list.size()):
		v.add_child(_candidate_row(job, list[i], i))
	var auto := UiKit.btn("Auto-fill", UiKit.BODY)
	auto.name = "AutoFill_" + job
	auto.custom_minimum_size = Vector2(0, 44)
	auto.pressed.connect(func():
		GameState.auto_fill_staff(job)
		_build())
	v.add_child(auto)
	return _padded(v)


func _candidate_row(job: String, c: Dictionary, i: int) -> Control:
	var h := UiKit.hbox(8)
	h.name = "Candidate_%s_%d" % [job, i]
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var who := Button.new()
	who.flat = true
	who.text = GameDB.player_display_name(c)
	who.alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.add_theme_font_override("font", UiKit.BOLD)
	who.add_theme_font_size_override("font_size", UiKit.BODY)
	who.custom_minimum_size.y = 32
	who.pressed.connect(func(): _sheet = CoachSheet.open(self, c))
	info.add_child(who)
	info.add_child(UiKit.ellipsis(Coaches.whereabouts(c), UiKit.SMALL, UiKit.MUTED))
	var facts := UiKit.lbl("%s · %s · %s" % [Coaches.fit_word(c, job), Coaches.rep_word(c),
			Coaches.experience_word(c, job)], UiKit.SMALL, UiKit.TEXT)
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(facts)
	var grades := UiKit.lbl("Teaching %s · Tactics %s · Man-management %s" % [
			Coaches.grade(Coaches.skill(c, "teach")), Coaches.grade(Coaches.skill(c, "tactics")),
			Coaches.grade(Coaches.skill(c, "manage"))], UiKit.SMALL, UiKit.MUTED)
	grades.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(grades)
	var pick := UiKit.btn("Appoint", 14, i == 0)
	pick.name = "Appoint_%s_%d" % [job, i]
	pick.custom_minimum_size = Vector2(92, 44)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.pressed.connect(func():
		GameState.appoint_staff(job, str(c["cid"]))
		_build())
	h.add_child(pick)
	return h


func _job_title(job: String) -> String:
	var label := str(Coaches.JOB_LABEL[job])
	return label if job == "SC" or job == "SA" else label + " coach"


## A job nobody holds (an expansion club before it has hired).
func _empty_row(job: String) -> Control:
	var v := UiKit.vbox(1)
	v.name = "StaffRow_" + job
	v.custom_minimum_size.y = 52
	v.add_child(UiKit.lbl(str(Coaches.JOB_LABEL[job]), UiKit.SMALL, UiKit.MUTED))
	v.add_child(UiKit.lbl("Vacant", UiKit.BODY, UiKit.MUTED))
	return _padded(v)


func _padded(c: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_child(c)
	return m


## Router back hook: close a profile first, then return to your own staff,
## then leave.
func handle_back() -> bool:
	if is_instance_valid(_sheet):
		_sheet.queue_free()
		_sheet = null
		return true
	if _club != GameState.my_club:
		_club = GameState.my_club
		_build()
		return true
	return false
