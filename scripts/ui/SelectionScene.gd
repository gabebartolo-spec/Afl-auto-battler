extends Control
## Team selection: your match-day 22. Auto-pick fields a sensible side
## every week; My selection lets you name the ruck, 5 midfielders, 6
## defenders, 6 forwards and 4 on the bench - a 6-6-6 shape with the ruck
## counted in midfield, and anyone in any position. A gap (an injured player,
## a short slot) is filled automatically on match day.

## The midfield is the centre square (3) and the two wings (Roles).
const SLOTS := [["RUCK", "Ruck", 1], ["MID", "Midfield", 3], ["WING", "Wings", 2],
		["DEF", "Defence", 6], ["FWD", "Forwards", 6], ["BENCH", "Interchange", 4]]
const CHOICES := [["RUCK", "Ruck"], ["MID", "Mid"], ["WING", "Wing"], ["DEF", "Def"],
		["FWD", "Fwd"], ["BENCH", "Bench"], ["OUT", "Out"]]

var _root: VBoxContainer
var _notice := ""
var _synergy_overlay: Control
var _plan_overlay: Control      # the game plan chooser
var _matchup_overlay: Control   # who goes to their key forward
var _sheet: Control             # a player's profile, open over the list
var _open_move := ""            # the one player whose move choices are open
var _scroll_box: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null or GameState.my_list.is_empty():
		Router.replace("main")
		return
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(8)
	margin.add_child(_root)
	get_viewport().size_changed.connect(func():
		if is_inside_tree():
			_build())
	_build()


func _build() -> void:
	# A move or a resize rebuilds the list: keep your place in it.
	var keep := _scroll_box.scroll_vertical if is_instance_valid(_scroll_box) else 0
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Team selection", true))
	var auto := GameState.my_selection().is_empty()
	# A side named before the wings existed: split its midfield once.
	if not auto and not GameState.my_selection().has("WING"):
		GameState.set_selection(GameState.current_side())

	var head := UiKit.panel(UiKit.PANEL, 10, 8)
	_root.add_child(head)
	var hv := UiKit.vbox(6)
	head.add_child(hv)
	var modes := UiKit.hbox(6)
	hv.add_child(modes)
	var auto_btn := UiKit.tab("Auto-pick", auto)
	auto_btn.name = "AutoPick"
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.pressed.connect(func():
		GameState.set_selection({})
		_notice = "Auto-pick: a sensible side is picked each week."
		_build())
	modes.add_child(auto_btn)
	var mine_btn := UiKit.tab("My selection", not auto)
	mine_btn.name = "MySelection"
	mine_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine_btn.pressed.connect(func():
		if GameState.my_selection().is_empty():
			GameState.set_selection(GameState.current_side())
			_notice = "Starting from the auto-picked 22. Tap a player's position to move him."
		_build())
	modes.add_child(mine_btn)
	var help := "Auto-pick fields a sensible side by position and rating each week." if auto \
			else "Your side plays every match. Injured players are replaced automatically."
	hv.add_child(_para(help, 13, UiKit.MUTED))
	if _notice != "":
		hv.add_child(_para(_notice, 13, UiKit.GOOD))
	hv.add_child(_synergy_view())


	var body := UiKit.vbox(6)
	_scroll_box = UiKit.scroll(body)
	_scroll_box.name = "SelectionScroll"
	_root.add_child(_scroll_box)
	_restore_scroll.call_deferred(keep)
	body.add_child(_this_week())
	var side := GameState.current_side()
	var placed := {}
	var sel := GameState.my_selection()
	for slot in SLOTS:
		var role: String = slot[0]
		var ids: Array = side[role]
		var named: Array = sel.get(role, []) if not auto else ids
		var title := "%s  %d/%d" % [str(slot[1]), ids.size(), int(slot[2])]
		var colour := UiKit.EMPH
		if not auto and named.size() != int(slot[2]):
			title += "  ·  %d named" % named.size()
			colour = UiKit.BAD if named.size() > int(slot[2]) else UiKit.EMPH
		body.add_child(UiKit.spacer(6))
		body.add_child(UiKit.lbl(title, UiKit.H2, colour, true))
		for id in ids:
			placed[str(id)] = true
			body.add_child(_row(GameState.list_player(str(id)), role, auto))
	var out: Array = []
	for p in GameState.my_list:
		if not placed.has(str(p["id"])):
			out.append(p)
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	body.add_child(UiKit.spacer(6))
	body.add_child(UiKit.lbl("Not selected  (%d)" % out.size(), UiKit.H2, UiKit.MUTED, true))
	for p in out:
		body.add_child(_row(p, "", auto))


## The line synergies your 18 switch on - what the side is good at - and
## the full rules one tap away. No "one more X" counts here: the rules are
## open, the choice is yours.
func _synergy_view() -> Control:
	var h := UiKit.hbox(8)
	h.name = "Synergies"
	var on: PackedStringArray = []
	for r in Traits.progress(GameState.my_squad().ground):
		if bool(r["active"]):
			on.append(Traits.with_effect(str(r["key"])))
	var l := _para("Your side has: " + ", ".join(on) + "." if not on.is_empty()
			else "No line synergies in this side.", 13, UiKit.GOOD if not on.is_empty() else UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var rules := UiKit.btn("Synergies", 14)
	rules.name = "SynergyRules"
	rules.custom_minimum_size = Vector2(104, 44)
	rules.pressed.connect(_show_synergies)
	h.add_child(rules)
	return h


## Every synergy: what it is, what it does and exactly what it needs, with
## the ones this side has marked On.
func _show_synergies() -> void:
	_close_synergies()
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_synergy_overlay = box["overlay"]
	_synergy_overlay.name = "SynergyGuide"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Line synergies", UiKit.H1, UiKit.TEXT, true))
	v.add_child(_para("Players' traits combine when the right mix takes the field together.", 13, UiKit.MUTED))
	var active := {}
	for r in Traits.progress(GameState.my_squad().ground):
		active[str(r["key"])] = bool(r["active"])
	for key in Traits.SYNERGIES:
		var s: Dictionary = Traits.SYNERGIES[key]
		var row := UiKit.vbox(2)
		row.name = "Synergy_" + str(key)
		v.add_child(UiKit.spacer(6))
		v.add_child(row)
		var head := UiKit.hbox(8)
		row.add_child(head)
		var name_l := UiKit.lbl(str(s["label"]), UiKit.BODY, UiKit.TEXT, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		if bool(active.get(key, false)):
			head.add_child(UiKit.line("On", 13, UiKit.GOOD, true))
		row.add_child(_para("%s %s" % [str(s.get("about", "")), str(s.get("does", ""))], 13, UiKit.TEXT))
		var req := _para(Traits.requirement_text(str(key)), 13, UiKit.MUTED)
		req.name = "Requires"
		row.add_child(req)
		# Who in your 18 carries each trait it needs: the facts behind On.
		var who := PackedStringArray()
		for c in Traits.carriers(str(key), GameState.my_squad().ground):
			var names: Array = []
			for p in c[1]:
				names.append(GameDB.player_display_name(p))
			var plural := str(Traits.PLURALS.get(str(c[0]), Traits.label(str(c[0])) + "s"))
			who.append("%s in your side: %s." % [plural, ", ".join(names) if not names.is_empty() else "none"])
		var wl := _para("\n".join(who), 13, UiKit.TEXT)
		wl.name = "Carriers"
		row.add_child(wl)
	var close := UiKit.btn("Close", 16, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_synergies)
	box["footer"].add_child(close)


func _close_synergies() -> void:
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_synergy_overlay.queue_free()
	_synergy_overlay = null


func _restore_scroll(value: int) -> void:
	# After the rebuilt list has its height, or the offset is clamped to 0.
	await get_tree().process_frame
	if is_instance_valid(_scroll_box):
		_scroll_box.scroll_vertical = value


## A player's profile over the list; closing it leaves the list untouched.
func _open_profile(id: String) -> void:
	var p := GameState.list_player(id)
	if p.is_empty():
		return
	_close_profile()
	_sheet = PlayerSheet.open(self, p, func(): _sheet = null)


func _close_profile() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


## Android Back closes a profile, then the synergy guide or the plan
## chooser, before leaving.
func handle_back() -> bool:
	if _sheet != null and is_instance_valid(_sheet):
		_close_profile()
		return true
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_close_synergies()
		return true
	if _matchup_overlay != null and is_instance_valid(_matchup_overlay):
		_close_matchup()
		return true
	if _plan_overlay != null and is_instance_valid(_plan_overlay):
		_close_plan()
		return true
	return false


## One player: a line in the list with a rule under it, not a card.
func _row(p: Dictionary, placed_as: String, auto: bool) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = UiKit.LINE
	sb.border_width_bottom = 1
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	card.add_theme_stylebox_override("panel", sb)
	var v := UiKit.vbox(4)
	card.add_child(v)
	var top := UiKit.hbox(8)
	v.add_child(top)
	# Who he is: a tap opens his profile over the list.
	var who_btn := Button.new()
	who_btn.name = "Profile_" + str(p["id"])
	who_btn.flat = true
	who_btn.focus_mode = Control.FOCUS_NONE
	who_btn.custom_minimum_size = Vector2(0, 46)
	who_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	who_btn.tooltip_text = "Open his profile"
	who_btn.pressed.connect(_open_profile.bind(str(p["id"])))
	who_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_btn.clip_contents = true
	top.add_child(who_btn)
	var who_box := UiKit.vbox(4)
	who_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	who_btn.add_child(who_box)
	var h := UiKit.hbox(6)
	who_box.add_child(h)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var nm := UiKit.ellipsis(GameDB.player_display_name(p), 15, UiKit.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var weeks := int(p.get("injury_weeks", 0))
	var m := ClubLife.morale(p)
	if m < 40:
		h.add_child(UiKit.line("Unhappy", 11, UiKit.BAD))
	if bool(p.get("rested", false)):
		h.add_child(UiKit.line("Rested", 12, UiKit.MUTED))
	if Injuries.concussion_text(p) != "":
		h.add_child(UiKit.line(Injuries.concussion_text(p), 12, UiKit.BAD, true))
	elif weeks > 0:
		h.add_child(UiKit.line("Out %d wk%s" % [weeks, "" if weeks == 1 else "s"], 12, UiKit.BAD, true))
	elif placed_as == "MID" or placed_as == "WING":
		var fit := Roles.fit_note(p, placed_as)
		if not Roles.is_mid(p):
			fit = "Out of position"
		if fit != "":
			var fl := UiKit.line(fit, 12, UiKit.MUTED)
			fl.name = "Fit"
			h.add_child(fl)
	elif placed_as != "" and placed_as != "BENCH" and str(p["role"]) != placed_as \
			and str(p.get("role2", "")) != placed_as:
		h.add_child(UiKit.line("Out of position", 12, UiKit.MUTED))
	# His rating sits outside the tap area, beside the position button, so a
	# long trait line never runs under either.
	var ovr := UiKit.line("%d" % int(p["overall"]), 16, UiKit.TEXT, true)
	ovr.name = "Ovr"
	ovr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ovr.custom_minimum_size.x = 28
	ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(ovr)
	# Who he is, then his traits: one quiet line.
	var about := UiKit.trait_chips(p)
	var who := UiKit.line(Roles.label(p), 13, UiKit.TEXT)
	who.name = "RoleLabel"
	about.add_child(who)
	about.move_child(who, 0)
	who_box.add_child(about)
	_ignore_mouse(who_box)
	who_btn.custom_minimum_size.y = maxf(46.0, who_box.get_combined_minimum_size().y)
	if auto:
		return card
	# Where he is now, as a button: a tap opens his move choices under the
	# row (one row at a time), a second tap closes them.
	var id := str(p["id"])
	var current := _named_role(id)
	var slot_btn := UiKit.btn("%s  ▾" % _short_label(current), 14)
	slot_btn.name = "Slot_" + id
	slot_btn.custom_minimum_size = Vector2(92, 44)
	slot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot_btn.tooltip_text = "Move him"
	UiKit.paint_choice(slot_btn, _open_move == id)
	slot_btn.pressed.connect(func():
		_open_move = "" if _open_move == id else id
		_build())
	top.add_child(slot_btn)
	if _open_move == id:
		var move := UiKit.vbox(0)
		move.name = "Move_" + id
		var cols := 4 if UiKit.view_width(self) < 560.0 else CHOICES.size()
		move.add_child(UiKit.choice_grid("To", CHOICES, current if current != "" else "OUT", cols,
				func(key: String): _move(id, "" if key == "OUT" else key)))
		v.add_child(move)
	return card


## "Wing", "Bench", "Out"... for the position button.
func _short_label(role: String) -> String:
	for c in CHOICES:
		if str(c[0]) == role:
			return str(c[1])
	return "Not picked"


## Where the player is named in your selection ("" = not named).
func _named_role(id: String) -> String:
	var sel := GameState.my_selection()
	for slot in SLOTS + [["OUT"]]:
		if (sel.get(str(slot[0]), []) as Array).has(id):
			return str(slot[0])
	return ""


func _move(id: String, to_role: String) -> void:
	_open_move = ""
	var sel := GameState.my_selection().duplicate(true)
	for slot in SLOTS + [["OUT"]]:
		var arr: Array = sel.get(str(slot[0]), [])
		arr.erase(id)
		sel[str(slot[0])] = arr
	# "Out" means out: the match-day gap filler skips him unless nobody else
	# can play.
	var target: Array = sel[to_role if to_role != "" else "OUT"]
	target.append(id)
	GameState.set_selection(sel)
	var p := GameState.list_player(id)
	_notice = "%s moved to %s." % [GameDB.player_display_name(p),
			_label_for(to_role)] if to_role != "" else "%s left out." % GameDB.player_display_name(p)
	for slot in SLOTS:
		if str(slot[0]) == to_role and (sel[to_role] as Array).size() > int(slot[2]):
			_notice += " %s is over by %d - move someone out." % [str(slot[1]),
					(sel[to_role] as Array).size() - int(slot[2])]
	_build()


func _label_for(role: String) -> String:
	for slot in SLOTS:
		if str(slot[0]) == role:
			return str(slot[1]).to_lower()
	return role


## This week, what the choice rests on: line against line (your half moves
## with your selection), the people who matter, how they play, then the game
## plan you take in. Facts, never a verdict: what to do about it is your call.
func _this_week() -> Control:
	var v := UiKit.vbox(3)
	v.name = "SelectionWeek"
	var nxt := GameState.my_next_opponent()
	if nxt.is_empty():
		v.add_child(_strength_line())
		v.add_child(UiKit.spacer(4))
		v.add_child(_plan_row())
		return v
	var code := str(nxt["code"])
	v.add_child(UiKit.lbl("This week %s %s" % ["v" if str(nxt["venue"]) == "home" else "at",
			GameDB.club_name(code)], UiKit.BODY, UiKit.TEXT, true))
	var lines := UiKit.vbox(3)
	lines.name = "HeadToHead"
	v.add_child(lines)
	for row in GameState.my_head_to_head(code):
		var l := _para(str(row["text"]), 14, UiKit.TEXT)
		l.name = "H2H_" + str(row["key"])
		lines.add_child(l)
	var people := GameState.opponent_people(code)
	var own := GameState.my_week_notes()
	if not people.is_empty() or not own.is_empty():
		v.add_child(UiKit.spacer(4))
	for f in people:
		v.add_child(_para(str(f["text"]), 13, UiKit.MUTED))
	for f in own:
		v.add_child(_para(str(f["text"]), 13, UiKit.BAD))
	# Their key forwards and who goes to them: your call, in names.
	var mus := GameState.week_matchups(code)
	if not mus.is_empty():
		v.add_child(UiKit.spacer(6))
		var mv := UiKit.vbox(2)
		mv.name = "KeyMatchups"
		v.add_child(mv)
		mv.add_child(UiKit.lbl("Their key forwards", UiKit.BODY, UiKit.TEXT, true))
		for m in mus:
			mv.add_child(_matchup_row(m))
	var style := GameState.their_style(code)
	var usual := GameState.usual_plan(code)
	if usual != "balanced":
		v.add_child(UiKit.spacer(4))
		var up := _para("Their usual game: %s." % CoachReport.plan_label(usual), 13, UiKit.MUTED)
		up.name = "TheirPlan"
		v.add_child(up)
	if not style.is_empty():
		v.add_child(UiKit.spacer(4))
		var st := _para("How they play: " + " ".join(style), 13, UiKit.MUTED)
		st.name = "TheirStyle"
		v.add_child(st)
	v.add_child(UiKit.spacer(6))
	v.add_child(_plan_row())
	return v


## "Curnow: Moore on him" with the way to change it.
func _matchup_row(m: Dictionary) -> Control:
	var f: Dictionary = m["fwd"]
	var h := UiKit.hbox(8)
	h.name = "Matchup_" + str(f["id"])
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var who := _para("%s: %s on him" % [GameDB.player_display_name(f),
			GameDB.player_display_name(m["def"])], 14, UiKit.TEXT)
	who.name = "MatchupLine"
	t.add_child(who)
	t.add_child(_para(Matchups.describe(f), 12, UiKit.MUTED))
	var b := UiKit.btn("Change", 14)
	b.name = "ChangeMatchup"
	b.custom_minimum_size = Vector2(104, 44)
	b.pressed.connect(func(): _show_matchup(f, m["def"]))
	h.add_child(b)
	return h


## Who goes to their forward: your defenders on the ground, each as a coach
## would describe him. Tap one and he has the job.
func _show_matchup(fwd: Dictionary, current: Dictionary) -> void:
	_close_matchup()
	var box := UiKit.modal_box(self, 480.0, 0.0)
	_matchup_overlay = box["overlay"]
	_matchup_overlay.name = "MatchupChooser"
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiKit.lbl("Who goes to %s?" % GameDB.player_display_name(fwd), UiKit.H1, UiKit.TEXT, true))
	v.add_child(_para(Matchups.describe(fwd), 13, UiKit.MUTED))
	for p in Matchups.defenders(GameState.my_squad().ground):
		var b := UiKit.btn("", 15)
		b.name = "Defender_" + str(p["id"])
		b.custom_minimum_size = Vector2(0, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s" % [GameDB.player_display_name(p), Matchups.describe(p)]
		UiKit.paint_choice(b, str(p["id"]) == str(current.get("id", "")))
		var pid := str(p["id"])
		b.pressed.connect(func():
			GameState.set_my_matchup(str(fwd["id"]), pid)
			_close_matchup()
			_build())
		v.add_child(b)
	var done := UiKit.btn("Close", 16)
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(_close_matchup)
	box["footer"].add_child(done)


func _close_matchup() -> void:
	if _matchup_overlay != null and is_instance_valid(_matchup_overlay):
		_matchup_overlay.queue_free()
	_matchup_overlay = null


## The game plan you take into the match, and the way to change it.
func _plan_row() -> Control:
	var h := UiKit.hbox(8)
	h.name = "PlanRow"
	var l := UiKit.lbl("Game plan: %s" % CoachReport.plan_label(GameState.club_plan), UiKit.BODY, UiKit.TEXT, true)
	l.name = "PlanLine"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := UiKit.btn("Change", 14)
	b.name = "ChangePlan"
	b.custom_minimum_size = Vector2(104, 44)
	b.pressed.connect(_show_plan)
	h.add_child(b)
	return h


## The same six plans as Coaching and the breaks, each with what it does.
func _show_plan() -> void:
	_close_plan()
	var box := UiKit.modal_box(self, 480.0, 0.0)
	_plan_overlay = box["overlay"]
	_plan_overlay.name = "PlanChooser"
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiKit.lbl("Game plan", UiKit.H1, UiKit.TEXT, true))
	var opts := []
	for key in GameState.CLUB_PLANS:
		opts.append([key, CoachReport.plan_label(key)])
	var ground: Array = GameState.my_squad().ground
	var fit := _para(GameState.plan_fit_line(ground, GameState.club_plan), 13, UiKit.TEXT)
	fit.name = "PlanFit"
	fit.visible = fit.text != ""
	var note := _para(CoachReport.plan_summary(GameState.club_plan), 13, UiKit.MUTED)
	note.name = "PlanNote"
	v.add_child(UiKit.choice_grid("ClubPlan", opts, GameState.club_plan, 2, func(key):
		GameState.set_club_plan(str(key))
		note.text = CoachReport.plan_summary(str(key))
		fit.text = GameState.plan_fit_line(ground, str(key))
		fit.visible = fit.text != ""
		var line: Label = find_child("PlanLine", true, false)
		if line != null:
			line.text = "Game plan: %s" % CoachReport.plan_label(str(key))))
	v.add_child(note)
	v.add_child(fit)
	v.add_child(_para("Every match starts on this plan. Change it at any break.", 13, UiKit.MUTED))
	var done := UiKit.btn("Done", 16, true)
	done.name = "PlanDone"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(_close_plan)
	box["footer"].add_child(done)


func _close_plan() -> void:
	if _plan_overlay != null and is_instance_valid(_plan_overlay):
		_plan_overlay.queue_free()
	_plan_overlay = null


## Your lines against the league, in words, when there is no opponent to
## set them against (a bye, the season over).
func _strength_line() -> Control:
	var l := _para(GameState.my_line_standing_text(), 14, UiKit.TEXT)
	l.name = "LineStanding"
	return l


func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		if c is Control:
			_ignore_mouse(c)
