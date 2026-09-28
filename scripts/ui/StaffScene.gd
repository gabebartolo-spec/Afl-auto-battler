extends Control
## A club's coaching staff: six jobs, one row each. At your club the senior
## coach is you; the other five are the people you inherited. Tap a coach
## for his profile. Other clubs' staffs are one tap away. Read-only.

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
	for job in Coaches.JOBS:
		if job == "SC" and mine:
			body.add_child(_you_row())
		elif staff.has(job):
			body.add_child(_coach_row(job, staff[job]))
		else:
			body.add_child(_empty_row(job))
		body.add_child(UiKit.rule())

	body.add_child(UiKit.spacer(14))
	var others := UiKit.btn("Your club" if not mine else "Another club's staff", 15)
	others.name = "OtherClubs"
	others.flat = not _others_open
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


func _coach_row(job: String, c: Dictionary) -> Control:
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
	return b


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
