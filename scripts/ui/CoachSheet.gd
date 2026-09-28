class_name CoachSheet
extends RefCounted
## A coach's profile over the Staff screen, built like the player sheet:
## who he is and where he is, what kind of coach he is in words, then his
## coaching career. No numbers: skills show as grades. Read-only.


static func open(host: Control, c: Dictionary, on_close: Callable = Callable()) -> Control:
	var box := UiKit.modal_box(host, 520.0, 460.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CoachProfile"
	var v: VBoxContainer = box["body"]

	var name_l := UiKit.lbl(GameDB.player_display_name(c), 22, UiKit.TEXT, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var where := UiKit.lbl(Coaches.whereabouts(c), UiKit.H2, UiKit.TEXT, true)
	where.name = "CoachWhere"
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(where)
	var who := PackedStringArray(["Specialty: %s" % str(Coaches.SPEC_LABEL.get(str(c.get("spec", "")), "Whole game"))])
	if bool(c.get("former_sc", false)) and str(c.get("job", "")) != "SC":
		who.append("Former AFL senior coach")
	v.add_child(UiKit.lbl("  ·  ".join(who), UiKit.SMALL, UiKit.MUTED))

	# What kind of coach: each skill as a grade, then how he suits his job.
	v.add_child(UiKit.spacer(4))
	var skills := UiKit.vbox(2)
	skills.name = "CoachSkills"
	v.add_child(skills)
	for key in Coaches.SKILLS:
		skills.add_child(_row(str(Coaches.SKILL_LABEL[key]), Coaches.grade(Coaches.skill(c, key))))
	var job := str(c.get("job", ""))
	if str(c.get("status", "")) == "club" and job != "":
		var fit := _row("Fit for this job", Coaches.grade(Coaches.role_fit(c, job)))
		fit.name = "CoachFit"
		skills.add_child(fit)

	# His coaching career, as far as this game knows it.
	var stints: Array = c.get("stints", [])
	if not stints.is_empty():
		v.add_child(UiKit.spacer(6))
		v.add_child(UiKit.section("Coaching career"))
		var list := UiKit.vbox(2)
		list.name = "CoachCareer"
		v.add_child(list)
		for s in stints:
			list.add_child(UiKit.lbl(_stint_line(s), UiKit.BODY, UiKit.TEXT))
		v.add_child(UiKit.lbl("Records begin at Round 1, 2026.", UiKit.SMALL, UiKit.MUTED))

	# A coach who played for us: his playing days, from his career record.
	var played: Dictionary = c.get("played", {})
	if not played.is_empty():
		v.add_child(UiKit.spacer(6))
		v.add_child(UiKit.section("Playing career"))
		var tot := Career.totals_text({"career": played})
		if tot != "":
			v.add_child(UiKit.lbl(tot, UiKit.BODY, UiKit.TEXT))
		for line in Career.club_lines({"career": played}, func(code): return GameDB.club_name(code)):
			v.add_child(UiKit.lbl(str(line), UiKit.SMALL, UiKit.MUTED))

	var close := UiKit.btn("Close", 16, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call())
	box["footer"].add_child(close)
	return overlay


static func _row(label: String, value: String) -> Control:
	var row := UiKit.hbox(8)
	var l := UiKit.lbl(label, UiKit.BODY, UiKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.line(value, UiKit.BODY, UiKit.MUTED))
	return row


## "2026-  Forwards coach, Carlton" (still there) or "2026  Senior coach,
## Carlton" (a spell that has ended).
static func _stint_line(s: Array) -> String:
	var from := int(s[2])
	var to := int(s[3])
	var years := "%d–" % from if to == 0 else (str(from) if to == from else "%d–%d" % [from, to])
	var job := str(s[1])
	var label := str(Coaches.JOB_LABEL.get(job, job))
	if job != "SC" and job != "SA":
		label += " coach"
	return "%s  %s, %s" % [years, label, GameDB.club_name(str(s[0]))]
