class_name CoachSheet
extends RefCounted
## A coach's profile over the Staff screen, built like the player sheet:
## who he is and where he is, what kind of coach he is in words, then his
## coaching career. No numbers: skills show as grades. Read-only.


static func open(host: Control, c: Dictionary, on_close: Callable = Callable()) -> Control:
	var box := UiKit.modal_box(host, 520.0, 640.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CoachProfile"
	var v: VBoxContainer = box["body"]
	# A former player's two careers can run past one screen: keep the grades
	# clear of the scroll bar.
	var sc := v.get_parent()
	sc.remove_child(v)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(v)
	sc.add_child(gutter)

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
	var what := UiKit.lbl("Teaching develops his players. Tactics sharpen the game plan. Man-management softens being left out.",
			UiKit.SMALL, UiKit.MUTED)
	what.name = "CoachSkillsMeaning"
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var job := str(c.get("job", ""))
	if str(c.get("status", "")) == "club" and job != "":
		var fit := _row("Fit for this job", Coaches.grade(Coaches.role_fit(c, job)))
		fit.name = "CoachFit"
		skills.add_child(fit)

	v.add_child(what)

	# A former player: his playing days first, from the snapshot kept when
	# he retired - the same person, whichever name the game is showing.
	var played: Dictionary = c.get("played", {})
	if not played.is_empty():
		v.add_child(UiKit.spacer(6))
		v.add_child(UiKit.section("Playing career"))
		var pc := UiKit.vbox(2)
		pc.name = "CoachPlaying"
		v.add_child(pc)
		for line in playing_lines(played):
			pc.add_child(_wrapped(str(line)))

	# His coaching career, as far as this game knows it.
	var stints: Array = c.get("stints", [])
	if not stints.is_empty():
		v.add_child(UiKit.spacer(6))
		v.add_child(UiKit.section("Coaching career"))
		var list := UiKit.vbox(2)
		list.name = "CoachCareer"
		v.add_child(list)
		for s in stints:
			list.add_child(_wrapped(_stint_line(s)))
		if str(c.get("origin", "")) == "seed":
			v.add_child(UiKit.lbl("Records begin at Round 1, 2026.", UiKit.SMALL, UiKit.MUTED))

	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call())
	box["footer"].add_child(close)
	return overlay


## "Adelaide 2028–2043 · 263 games, 187 goals" per club, the career total
## when he played for more than one, how he was drafted and the awards he
## won in this save.
static func playing_lines(played: Dictionary) -> Array:
	var out := Career.club_lines({"career": played}, func(code): return GameDB.club_name(code))
	if (played.get("stints", []) as Array).size() > 1:
		var tot := Career.totals_text({"career": played})
		if tot != "":
			out.append(tot)
	var draft := CoachPathway.draft_line(played)
	if draft != "":
		out.append(draft)
	var h: Dictionary = played.get("honours", {})
	for pair in [["brownlow", "Brownlow Medal", "Brownlow Medals"], ["coleman", "Coleman Medal", "Coleman Medals"],
			["coaches", "Coaches Award", "Coaches Awards"], ["rising_star", "Rising Star", ""]]:
		var n := int(h.get(pair[0], 0))
		if n > 0:
			out.append(str(pair[1]) if n == 1 or str(pair[2]) == "" else "%d %s" % [n, pair[2]])
	var bnf: Dictionary = h.get("bnf", {})
	for club in bnf:
		var n := int(bnf[club])
		out.append(("%s best and fairest" if n == 1 else "%d %s best and fairests") % (
				[GameDB.club_name(str(club))] if n == 1 else [n, GameDB.club_name(str(club))]))
	return out


## A career line that wraps on a narrow phone instead of widening the sheet.
static func _wrapped(text: String) -> Label:
	var l := UiKit.lbl(text, UiKit.BODY, UiKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


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
