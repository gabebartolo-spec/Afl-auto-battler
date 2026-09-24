extends Control
## Team selection: your match-day 22. Auto-pick takes the best available side
## every week; My selection lets you name the ruck, 7 midfielders, 5
## defenders, 5 forwards and 4 on the bench - anyone in any position. A gap
## (an injured player, a short slot) is filled automatically on match day.

const SLOTS := [["RUCK", "Ruck", 1], ["MID", "Midfield", 7], ["DEF", "Defence", 5],
		["FWD", "Forwards", 5], ["BENCH", "Interchange", 4]]
const CHOICES := [["RUCK", "Ruck"], ["MID", "Mid"], ["DEF", "Def"], ["FWD", "Fwd"],
		["BENCH", "Bench"], ["OUT", "Out"]]

var _root: VBoxContainer
var _notice := ""


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
	_root.add_child(UiKit.top_bar("Team Selection", true))
	var auto := GameState.my_selection().is_empty()

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
		_notice = "Auto-pick: the best available side is chosen every week."
		_build())
	modes.add_child(auto_btn)
	var mine_btn := UiKit.tab("My selection", not auto)
	mine_btn.name = "MySelection"
	mine_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine_btn.pressed.connect(func():
		if GameState.my_selection().is_empty():
			GameState.set_selection(GameState.current_side())
			_notice = "Starting from this week's best 22. Move anyone with the buttons."
		_build())
	modes.add_child(mine_btn)
	var help := "Auto-pick fields the best available side by position every week." if auto \
			else "Your side plays every match. Injured players are replaced automatically."
	hv.add_child(_para(help, 13, UiKit.MUTED))
	if _notice != "":
		hv.add_child(_para(_notice, 13, UiKit.GOOD))
	hv.add_child(_strength_line())

	var body := UiKit.vbox(6)
	_root.add_child(UiKit.scroll(body))
	var side := GameState.current_side()
	var placed := {}
	var sel := GameState.my_selection()
	for slot in SLOTS:
		var role: String = slot[0]
		var ids: Array = side[role]
		var named: Array = sel.get(role, []) if not auto else ids
		var title := "%s  %d/%d" % [str(slot[1]), ids.size(), int(slot[2])]
		var colour := UiKit.GOLD
		if not auto and named.size() != int(slot[2]):
			title += "  ·  %d named" % named.size()
			colour = UiKit.BAD if named.size() > int(slot[2]) else UiKit.GOLD
		body.add_child(UiKit.lbl(title, 15, colour, true))
		for id in ids:
			placed[str(id)] = true
			body.add_child(_row(GameState.list_player(str(id)), role, auto))
	var out: Array = []
	for p in GameState.my_list:
		if not placed.has(str(p["id"])):
			out.append(p)
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	body.add_child(UiKit.lbl("Not selected  (%d)" % out.size(), 15, UiKit.MUTED, true))
	for p in out:
		body.add_child(_row(p, "", auto))


func _row(p: Dictionary, placed_as: String, auto: bool) -> Control:
	var card := UiKit.panel(UiKit.PANEL_ALT, 8, 5)
	var v := UiKit.vbox(4)
	card.add_child(v)
	var h := UiKit.hbox(6)
	v.add_child(h)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var nm := UiKit.ellipsis(GameDB.player_display_name(p), 14, UiKit.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var weeks := int(p.get("injury_weeks", 0))
	if weeks > 0:
		h.add_child(UiKit.line("INJ %dw" % weeks, 12, UiKit.BAD, true))
	elif placed_as != "" and placed_as != "BENCH" and str(p["role"]) != placed_as \
			and str(p.get("role2", "")) != placed_as:
		h.add_child(UiKit.line("out of position", 11, UiKit.MUTED))
	h.add_child(UiKit.line("%d" % int(p["overall"]), 15, UiKit.GOLD, true))
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


## The three numbers the engine rolls against, for this side.
func _strength_line() -> Control:
	var sq := GameState.my_squad()
	return _para("Contest %.0f  ·  Attack %.0f  ·  Defence %.0f" % [sq.contest, sq.attack, sq.defence],
			14, UiKit.TEXT)


func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
