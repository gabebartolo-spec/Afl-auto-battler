class_name SeasonPlanSheet
extends RefCounted
## Your season plan (Conditioning.gd), reached from the hub and Training by
## one line of words: "Building, peak due in August". The sheet shows the
## season line (your plan against the legs your department delivers), the four
## plans with what each does, and, at a revision point, lets you change it.
## Between revision points the plans stay on view, locked, with when the next
## chance comes. Nothing is recommended: every plan says what it costs.

const WIDE := 760.0


## The line that opens the sheet: the headline in words, the plan under it,
## and whether it can be changed this week. One tap.
static func line(host: Control, on_close: Callable = Callable()) -> Control:
	var words: String = GameState.fitness_status_line()
	if words == "":
		return null
	var b := UiKit.text_action("", UiKit.NAME)
	b.name = "SeasonPlanLine"
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var head := UiKit.ellipsis(words, UiKit.NAME, UiKit.TEXT, true)
	head.name = "SeasonPlanWords"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var sub: String = Conditioning.PLAN_LABEL[GameState.fitness_plan(GameState.my_club)]
	if GameState.can_revise_fitness():
		sub += " · " + ("set it before round 1" if GameState.fitness_week() == 0 else "you can change it this week")
	var second := UiKit.ellipsis(sub, UiKit.SMALL, UiKit.MUTED)
	second.name = "SeasonPlanSub"
	second.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(second)
	var more := UiKit.lbl("›", UiKit.NAME, UiKit.MUTED)
	more.autowrap_mode = TextServer.AUTOWRAP_OFF
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(more)
	b.pressed.connect(func(): open(host, on_close))
	return b


static func open(host: Control, on_close: Callable = Callable()) -> Control:
	var wide := UiKit.view_width(host) >= WIDE
	var box := UiKit.modal_box(host, 760.0 if wide else 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "SeasonPlanSheet"
	var state := {"draft": GameState.fitness_plan(GameState.my_club), "wide": wide}
	var done := func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	UiKit.close_on_outside_tap(box, done)
	_build(host, box, state, done)
	return overlay


static func _secondary(text: String, fs: int) -> Button:
	var b := UiKit.btn(text, fs)
	var sb := UiKit.style(Color.TRANSPARENT, 8, UiKit.RADIUS, UiKit.MUTED)
	sb.set_border_width_all(1)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	return b


static func _build(host: Control, box: Dictionary, state: Dictionary, done: Callable) -> void:
	var body: VBoxContainer = box["body"]
	var footer: VBoxContainer = box["footer"]
	UiKit.clear(body)
	UiKit.clear(footer)
	var me: String = GameState.my_club
	var week: int = GameState.fitness_week()
	var bye: int = GameState.fitness_bye_week(me)
	var open_now: bool = GameState.can_revise_fitness()
	var current: String = GameState.fitness_plan(me)
	var draft: String = str(state["draft"])
	var changed := draft != current
	var rec: Dictionary = GameState.fitness_record(me)
	# The line you would be on if you confirmed: what the chart and words show.
	var shown: Dictionary = Conditioning.revise(rec, week, draft) if changed else rec
	var level: int = GameState.fitness_hp_level(me)

	body.add_child(UiKit.lbl("Season plan", 22, UiKit.TEXT, true))
	var words := UiKit.lbl(Conditioning.status_words(shown, week), UiKit.NAME, UiKit.TEXT, true)
	words.name = "SeasonPlanSheetWords"
	body.add_child(words)
	var chart := SeasonLine.new().setup(shown, level, week)
	chart.name = "SeasonLineChart"
	chart.custom_minimum_size = Vector2(0, 190 if bool(state["wide"]) else 128)
	var cap := UiKit.lbl("Dotted is your plan. Solid is the legs you get.", UiKit.SMALL, UiKit.MUTED)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dept := UiKit.lbl("Your high-performance department (%s) sets how high the peak goes and how close to time it lands." % 			ClubBudget.level_label(level), UiKit.SMALL, UiKit.MUTED)
	dept.name = "SeasonPlanDepartment"
	dept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var plans := UiKit.vbox(8)
	plans.name = "SeasonPlans"
	for key in Conditioning.PLANS:
		plans.add_child(_plan_row(host, box, state, done, str(key), draft, open_now))
	if bool(state["wide"]):
		# A PC: the line and its words on the left, the four plans beside it.
		var cols := UiKit.hbox(20)
		var left := UiKit.vbox(8)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(chart)
		left.add_child(cap)
		left.add_child(dept)
		cols.add_child(left)
		plans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(plans)
		body.add_child(cols)
	else:
		body.add_child(chart)
		body.add_child(cap)
		body.add_child(plans)
		body.add_child(dept)

	var note := ""
	if open_now:
		if changed:
			note = Conditioning.late_cost(draft, week, bye)
	else:
		var next := Conditioning.next_revision_name(week, bye)
		if next != "":
			note = "The plan is locked in. You can change it again at %s." % next
		else:
			note = "The plan is locked in for the rest of the year."
	# The note sits above the buttons, in view whatever the body is scrolled to.
	var nl := UiKit.lbl(note, UiKit.BODY if open_now else UiKit.SMALL, UiKit.TEXT if open_now else UiKit.MUTED)
	nl.name = "SeasonPlanNote"
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.visible = note != ""
	footer.add_child(nl)

	var close := _secondary("Close", UiKit.NAME)
	close.name = "SeasonPlanClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(done)
	if open_now:
		var confirm := UiKit.btn("Confirm", UiKit.NAME, true)
		confirm.name = "SeasonPlanConfirm"
		confirm.custom_minimum_size = Vector2(0, 48)
		confirm.disabled = not changed
		confirm.pressed.connect(func():
			if GameState.set_fitness_plan(draft):
				state["draft"] = GameState.fitness_plan(me)
				_build(host, box, state, done))
		if not changed:
			var why := UiKit.lbl("Pick another plan to change it", UiKit.SMALL, UiKit.MUTED)
			why.name = "SeasonPlanConfirmWhy"
			footer.add_child(why)
		if bool(state["wide"]):
			# A PC: the two actions side by side at the right, sized to their words.
			var row := UiKit.hbox(8)
			row.alignment = BoxContainer.ALIGNMENT_END
			confirm.custom_minimum_size = Vector2(200, 48)
			close.custom_minimum_size = Vector2(140, 48)
			row.add_child(close)
			row.add_child(confirm)
			footer.add_child(row)
			return
		footer.add_child(confirm)
	footer.add_child(close)


## One plan: its name, what it does, one tap to pick it. The chosen one is
## outlined. Locked, it is read-only and the plan in force is marked.
static func _plan_row(host: Control, box: Dictionary, state: Dictionary, done: Callable,
		key: String, draft: String, open_now: bool) -> Control:
	var on := key == draft
	var row := PanelContainer.new()
	row.name = "PlanRow_" + key
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.style(UiKit.SURFACE, 12, UiKit.RADIUS, UiKit.TEXT if on else Color.TRANSPARENT)
	sb.set_border_width_all(2 if on else 0)
	row.add_theme_stylebox_override("panel", sb)
	var v := UiKit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var title: String = Conditioning.PLAN_LABEL[key]
	if not open_now and on:
		title += " · in force"
	var t := UiKit.lbl(title, UiKit.BODY, UiKit.TEXT if on or open_now else UiKit.MUTED, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var e := UiKit.lbl(str(Conditioning.PLAN_EFFECT[key]), UiKit.SMALL, UiKit.MUTED)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(e)
	if open_now:
		var tap := Button.new()
		tap.name = "Plan_" + key
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		tap.mouse_filter = Control.MOUSE_FILTER_PASS
		tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			tap.add_theme_stylebox_override(st, none)
		tap.custom_minimum_size = Vector2(0, 44)
		tap.pressed.connect(func():
			state["draft"] = key
			_build(host, box, state, done))
		row.add_child(tap)
	return row
