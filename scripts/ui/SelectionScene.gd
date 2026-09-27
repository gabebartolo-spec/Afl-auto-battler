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
			_notice = "Starting from the auto-picked 22. Move anyone with the buttons."
		_build())
	modes.add_child(mine_btn)
	var help := "Auto-pick fields a sensible side by position and rating each week." if auto \
			else "Your side plays every match. Injured players are replaced automatically."
	hv.add_child(_para(help, 13, UiKit.MUTED))
	if _notice != "":
		hv.add_child(_para(_notice, 13, UiKit.GOOD))
	hv.add_child(_strength_line())
	hv.add_child(_synergy_view())


	var body := UiKit.vbox(6)
	_root.add_child(UiKit.scroll(body))
	var week := _this_week()
	if week != null:
		body.add_child(week)
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
			on.append(Traits.label(str(r["key"])))
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
	var close := UiKit.btn("Close", 16, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_synergies)
	box["footer"].add_child(close)


func _close_synergies() -> void:
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_synergy_overlay.queue_free()
	_synergy_overlay = null


## Android Back closes the synergy guide before leaving Selection.
func handle_back() -> bool:
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_close_synergies()
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
	var h := UiKit.hbox(6)
	v.add_child(h)
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
	if weeks > 0:
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
	h.add_child(UiKit.line("%d" % int(p["overall"]), 16, UiKit.TEXT, true))
	# Who he is, then his traits: one quiet line.
	var about := UiKit.trait_chips(p)
	var who := UiKit.line(Roles.label(p), 13, UiKit.TEXT)
	who.name = "RoleLabel"
	about.add_child(who)
	about.move_child(who, 0)
	v.add_child(about)
	if auto:
		return card
	var choices := UiKit.hbox(3)
	choices.name = "Move_" + str(p["id"])
	v.add_child(choices)
	var current := _named_role(str(p["id"]))
	for c in CHOICES:
		var key: String = c[0]
		var b := UiKit.tab(str(c[1]), key == current)
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "To_" + key
		b.pressed.connect(_move.bind(str(p["id"]), "" if key == "OUT" else key))
		choices.add_child(b)
	return card


## Where the player is named in your selection ("" = not named).
func _named_role(id: String) -> String:
	var sel := GameState.my_selection()
	for slot in SLOTS + [["OUT"]]:
		if (sel.get(str(slot[0]), []) as Array).has(id):
			return str(slot[0])
	return ""


func _move(id: String, to_role: String) -> void:
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


## This week's opponent and what they bring. The problem, not the answer:
## the rows say who your players are; what to do about it is your call.
func _this_week() -> Control:
	var nxt := GameState.my_next_opponent()
	if nxt.is_empty():
		return null
	var code := str(nxt["code"])
	var v := UiKit.vbox(3)
	v.name = "SelectionWeek"
	v.add_child(UiKit.lbl("This week %s %s" % ["v" if str(nxt["venue"]) == "home" else "at",
			GameDB.club_name(code)], UiKit.BODY, UiKit.TEXT, true))
	for f in GameState.opponent_facts(code):
		v.add_child(_para(str(f["text"]), 13, UiKit.MUTED))
	return v


## How this side's lines stack up against the league, in words: a change
## of selection shows here, without engine numbers to decode.
func _strength_line() -> Control:
	var l := _para(GameState.my_line_standing_text(), 14, UiKit.TEXT)
	l.name = "LineStanding"
	return l


func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
