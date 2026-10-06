class_name PlayerSheet
extends RefCounted
## A player's profile over whatever screen you are on: who he is, his state,
## how good and how much room, what he is picked for, his season, then the
## attributes behind the rating. Read-only apart from any action the host
## offers (Selection offers backing a young player); Close or Back returns you
## to the screen underneath exactly as it was. Used by My list and Team
## selection.

const ATTR_ROWS := [
	["disposal", "Disposal"], ["contested", "Contested"], ["marking", "Marking"],
	["pressure", "Pressure"], ["intercept", "Intercept"], ["carry", "Carry"],
	["goalkicking", "Goalkicking"], ["accuracy", "Accuracy"],
	["creating", "Creating"], ["ruck", "Ruck"], ["discipline", "Discipline"],
	["durability", "Durability"], ["star", "Star power"],
]


## Opens the sheet over `host` and returns its overlay (the host keeps it to
## close on Back). `on_close` runs when Close is pressed. `actions` are what the
## host offers for this player, each {"name", "label", "detail", "run"}: a line
## of what it does and an outline button above Close.
static func open(host: Control, p: Dictionary, on_close: Callable = Callable(),
		actions: Array = []) -> Control:
	var box := UiKit.modal_box(host, 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "PlayerProfile"
	var v: VBoxContainer = box["body"]

	var name_l := UiKit.lbl(GameDB.player_display_name(p), 22, UiKit.TEXT, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	_identity(v, p)
	var type_l := UiKit.lbl(Roles.label(p), UiKit.H2, UiKit.TEXT, true)
	type_l.name = "ProfileType"
	v.add_child(type_l)
	var who := PackedStringArray(["#%d" % int(p["num"]), UiKit.ROLE_LABEL.get(str(p["role"]), str(p["role"]))])
	if float(p.get("age", 0.0)) > 0.0:
		who.append("%d years old" % int(p["age"]))
	if float(p.get("height_cm", 0.0)) > 0.0:
		who.append("%d cm" % int(p["height_cm"]))
	v.add_child(UiKit.lbl("  ·  ".join(who), UiKit.SMALL, UiKit.MUTED))

	# Now: available or not, and how he is feeling.
	var state := PackedStringArray()
	var weeks := int(p.get("injury_weeks", 0))
	if Injuries.concussion_text(p) != "":
		state.append(Injuries.concussion_text(p) + ".")
	elif weeks > 0:
		state.append("Injured: out %s%s." % ["1 week" if weeks == 1 else "%d weeks" % weeks,
				" (%s)" % str(p["injury_kind"]) if str(p.get("injury_kind", "")) != "" else ""])
	elif bool(p.get("rested", false)):
		state.append("Rested this week.")
	else:
		state.append("Available.")
	state.append("Mood: %s." % ClubLife.mood(ClubLife.morale(p)).to_lower())
	if ClubLife.mood_effect(ClubLife.morale(p)) != "":
		state.append(ClubLife.mood_effect(ClubLife.morale(p)))
	var sl := UiKit.lbl(" ".join(state), UiKit.BODY, UiKit.BAD if weeks > 0 else UiKit.TEXT)
	sl.name = "ProfileState"
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	if Ratings.available(p):
		var readiness := UiKit.lbl(Workload.description(p), UiKit.SMALL, UiKit.MUTED)
		readiness.name = "ProfileReadiness"
		readiness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(readiness)
	# A run you have promised him (Backing): a fact, not advice.
	var promise := Backing.note(p)
	if promise != "":
		var pl := UiKit.lbl(promise, UiKit.BODY, UiKit.TEXT)
		pl.name = "ProfileBacking"
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)

	# How good, and how much room.
	v.add_child(UiKit.spacer(4))
	var nums := UiKit.hbox(18)
	v.add_child(nums)
	# POT as your club knows it: exact for yours, a recruiters' range for anyone else.
	for pair in [[str(int(p["overall"])), "OVR"], [str(GameState.pot_view(p)["text"]), "POT"]]:
		var nb := UiKit.vbox(0)
		nb.name = "Profile" + str(pair[1])
		nb.add_child(UiKit.figure(str(pair[0]), 30, UiKit.TEXT))
		nb.add_child(UiKit.lbl(str(pair[1]), UiKit.SMALL, UiKit.MUTED))
		nums.add_child(nb)
	var dev := UiKit.lbl(GameState.development_state(p), UiKit.BODY, UiKit.TEXT)
	dev.name = "ProfileDevelopment"
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev.size_flags_vertical = Control.SIZE_SHRINK_END
	dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_child(dev)
	var plan := GameState.train_plan_label(GameState.plan_for(p))
	if plan != "":
		v.add_child(UiKit.lbl("Training plan: %s" % plan, UiKit.SMALL, UiKit.MUTED))

	# What he is picked for.
	v.add_child(UiKit.spacer(4))
	for st in PlayerProfile.strengths(p):
		var row := UiKit.hbox(8)
		var sn := UiKit.lbl(str(st["label"]), UiKit.BODY, UiKit.TEXT)
		sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sn)
		row.add_child(UiKit.line(str(st["grade"]), UiKit.BODY, UiKit.MUTED))
		v.add_child(row)
	var weak := PlayerProfile.weakness(p)
	if not weak.is_empty():
		v.add_child(UiKit.lbl("Needs work: " + str(weak["label"]).to_lower(), UiKit.SMALL, UiKit.MUTED))
	for t in Traits.of(p):
		var tl := UiKit.lbl("%s. %s" % [Traits.label(str(t)), Traits.scout(str(t))], UiKit.SMALL,
				UiKit.BAD if Traits.is_bad(str(t)) else UiKit.TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)

	# What he has done.
	var prod := PlayerProfile.production(p)
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.lbl(str(prod["title"]), UiKit.SMALL, UiKit.MUTED))
	var pl := UiKit.lbl(str(prod["line"]) if str(prod["line"]) != "" else "No stats on record.",
			UiKit.BODY, UiKit.TEXT if str(prod["line"]) != "" else UiKit.MUTED)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl)
	var season_stats: Dictionary = GameState.season_tally.get(str(p.get("id", "")), {})
	var season_games := int(season_stats.get("games", 0))
	var season_distance := float(season_stats.get("distance_run", 0.0))
	if season_games > 0 and season_distance > 0.0:
		var gps := UiKit.lbl("This season: %.1f km covered per game" % [
				season_distance / 1000.0 / float(season_games)], UiKit.SMALL, UiKit.MUTED)
		gps.name = "ProfileGPS"
		v.add_child(gps)

	# His senior career (Career.gd): games and goals, and the clubs when he
	# has played for more than one.
	var tot := Career.totals_text(p)
	if tot != "":
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("Career", UiKit.SMALL, UiKit.MUTED))
		var cl := UiKit.lbl(tot, UiKit.BODY, UiKit.TEXT)
		cl.name = "ProfileCareer"
		v.add_child(cl)
		var clubs := Career.club_lines(p, func(code): return GameDB.club_name(code))
		if clubs.size() > 1:
			for line in clubs:
				v.add_child(UiKit.lbl(str(line), UiKit.SMALL, UiKit.MUTED))

	# What he has done for your club: games, goals, best and fairests, flags.
	if not GameState.list_player(str(p.get("id", ""))).is_empty():
		var wu := GameState.with_us_text(p)
		if wu != "":
			v.add_child(UiKit.spacer(4))
			var wl := UiKit.lbl(wu, UiKit.BODY, UiKit.TEXT)
			wl.name = "ProfileWithUs"
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(wl)

	# The attributes behind the rating: the deepest layer, last.
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.section("Attributes"))
	var grid := GridContainer.new()
	grid.name = "ProfileAttributes"
	grid.columns = 1 if UiKit.view_width(host) < 520.0 else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	var attr: Dictionary = p["attr"]
	for r in ATTR_ROWS:
		grid.add_child(attr_bar(str(r[0]), str(r[1]), float(attr.get(r[0], 0.0))))

	for a in actions:
		var action: Dictionary = a
		var detail := UiKit.lbl(str(action.get("detail", "")), UiKit.SMALL, UiKit.MUTED)
		detail.name = "Detail_" + str(action.get("name", ""))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box["footer"].add_child(detail)
		var act := UiKit.btn(str(action.get("label", "")), 16)
		act.name = str(action.get("name", "Action"))
		act.custom_minimum_size = Vector2(0, 48)
		act.pressed.connect(action["run"])
		box["footer"].add_child(act)
	var close := UiKit.btn("Close", 16, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func():
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call())
	box["footer"].add_child(close)
	return overlay


static func attr_bar(key: String, label: String, value: float) -> Control:
	var h := UiKit.hbox(4)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UiKit.ellipsis(label, UiKit.SMALL, UiKit.MUTED)
	l.custom_minimum_size = Vector2(96, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(70, 9)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := ColorRect.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(70, 7)
	bar.color = Color(1, 1, 1, 0.10)
	holder.add_child(bar)
	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(70.0 * clampf(value / 99.0, 0.0, 1.0), 7)
	fill.color = attr_colour(value)
	holder.add_child(fill)
	h.add_child(holder)
	var n := UiKit.lbl(str(int(round(value))), UiKit.SMALL, UiKit.TEXT)
	n.custom_minimum_size = Vector2(26, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


static func attr_colour(v: float) -> Color:
	if v >= 75.0:
		return UiKit.GOOD
	if v >= 55.0:
		return UiKit.EMPH
	if v >= 40.0:
		return Color(0.80, 0.76, 0.55)
	return UiKit.BAD


## FL-005: his nickname beside the full name, and one thing he does outside
## footy - quiet text, never a rating, never read by the game. Your own player's
## nickname can be changed or removed here.
static func _identity(v: VBoxContainer, p: Dictionary) -> void:
	var nick := FictionalIdentity.nickname(p)
	var row := UiKit.hbox(8)
	row.name = "ProfileNickname"
	var nl := UiKit.lbl("\"%s\"" % nick if nick != "" else "", UiKit.BODY, UiKit.MUTED)
	nl.name = "NicknameText"
	row.add_child(nl)
	var mine := not GameState.list_player(str(p.get("id", ""))).is_empty()
	if mine:
		var edit := UiKit.btn("Nickname" if nick == "" else "Change", UiKit.SMALL)
		edit.name = "NicknameEdit"
		var field := UiKit.search_field(nick, "Nickname (blank for none)")
		field.name = "NicknameField"
		field.max_length = GameState.NICKNAME_MAX
		field.visible = false
		field.custom_minimum_size = Vector2(180, 0)
		row.add_child(field)
		row.add_child(edit)
		edit.pressed.connect(func():
			if not field.visible:
				field.visible = true
				field.text = FictionalIdentity.nickname(p)
				edit.text = "Save"
				field.grab_focus()
				return
			var now := GameState.set_player_nickname(str(p["id"]), field.text)
			nl.text = "\"%s\"" % now if now != "" else ""
			field.visible = false
			edit.text = "Nickname" if now == "" else "Change")
		field.text_submitted.connect(func(_t): edit.emit_signal("pressed"))
	if nick != "" or mine:
		v.add_child(row)
	var what := FictionalIdentity.interest(p)
	if what != "":
		var il := UiKit.lbl("Outside footy: %s." % what, UiKit.SMALL, UiKit.MUTED)
		il.name = "ProfileInterest"
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(il)
