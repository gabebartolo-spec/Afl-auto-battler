extends Control
## Training. Every listed player is here. XP is personal and earned every
## game; each player's training plan spends it automatically after the game
## (or banks it, on Manual), and any stat can still be trained by hand.

const ROLES := ["", "DEF", "MID", "RUCK", "FWD"]
const ROLE_TABS := [["", "ALL"], ["DEF", "DEFS"], ["MID", "MIDS"], ["RUCK", "RUCKS"], ["FWD", "FWDS"]]

var _role := ""
var _query := ""
var _selected := ""
var _showing_detail := false
var _notice := ""
var _wide := false
var _root: VBoxContainer
var _list_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.my_club == "" or GameState.my_list.is_empty():
		Router.replace("main")
		return
	if not GameState.player_names_changed.is_connected(_on_names):
		GameState.player_names_changed.connect(_on_names)
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
	if not bool(GameState.get_setting("seen_training_intro", false)):
		GameState.set_setting("seen_training_intro", true)
		_show_intro()


## Router back hook: close the stat guide or intro before leaving.
func handle_back() -> bool:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
		return true
	return false


func _open_guide() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = StatGuide.show(self)


## Shown once, the first time Training is opened.
func _show_intro() -> void:
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_overlay = box["overlay"]
	_overlay.name = "TrainingIntro"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("HOW TRAINING WORKS", 24))
	for line in [
		"Every player on your list earns XP after every game - more for playing, more for a big game.",
		"Training plans spend it for you. The club plan (Position plan to start) trains what each position needs. Give any player his own plan - inside midfielder, key forward, a single stat - or Manual to bank his XP.",
		"Change a plan whenever you like; banked XP is spent under the new plan straight away. You can still buy any stat by hand.",
		"Points are cheaper while a player is below his potential (POT) and dearer once he is past it.",
		"Not sure what a stat does? The Stat guide explains every one - what it is built from and exactly what it does in a match.",
	]:
		var l := UiKit.lbl(line, 14, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var guide := UiKit.btn("Open stat guide", 16)
	guide.custom_minimum_size = Vector2(0, 44)
	guide.pressed.connect(func():
		_overlay.queue_free()
		_open_guide())
	box["footer"].add_child(guide)
	var ok := UiKit.btn("Got it", 17, true)
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func():
		_overlay.queue_free()
		_overlay = null)
	box["footer"].add_child(ok)


func _on_names() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	_wide = UiKit.view_width(self) >= 760.0
	var list_y := _list_scroll.scroll_vertical if is_instance_valid(_list_scroll) else 0
	var detail_y := _detail_scroll.scroll_vertical if is_instance_valid(_detail_scroll) else 0
	UiKit.clear(_root)
	_list_scroll = null
	_detail_scroll = null
	var guide := UiKit.btn("Stat guide", 13)
	guide.name = "StatGuideButton"
	guide.custom_minimum_size = Vector2(96, 44)
	guide.pressed.connect(_open_guide)
	_root.add_child(UiKit.top_bar("Training", true, guide))
	_root.add_child(_summary())
	if _wide:
		var body := UiKit.hbox(10)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.add_child(body)
		body.add_child(_list_panel())
		body.add_child(_detail_panel())
	elif _showing_detail and _selected != "":
		_root.add_child(_detail_panel())
	else:
		_root.add_child(_list_panel())
	_restore_scroll.call_deferred(list_y, detail_y)


func _restore_scroll(list_y: int, detail_y: int) -> void:
	if is_instance_valid(_list_scroll):
		_list_scroll.scroll_vertical = list_y
	if is_instance_valid(_detail_scroll):
		_detail_scroll.scroll_vertical = detail_y


func _summary() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 10, 8)
	var v := UiKit.vbox(3)
	panel.add_child(v)
	var report: Dictionary = GameState.last_training_report
	if int(report.get("count", 0)) > 0:
		v.add_child(UiKit.lbl("%s  ·  %d players gained %d XP" % [
				str(report.get("label", "Last game")), int(report["count"]), int(report["total"])],
				15, UiKit.GOLD, true))
		var auto: Dictionary = report.get("auto", {})
		if int(auto.get("points", 0)) > 0:
			v.add_child(UiKit.lbl("Training plans bought %d stat points across %d players." % [
					int(auto["points"]), int(auto["players"])], 13, UiKit.GOOD))
	else:
		v.add_child(UiKit.lbl("No game played yet. XP arrives after every match.", 15, UiKit.GOLD, true))
	var plan_row := UiKit.hbox(8)
	v.add_child(plan_row)
	plan_row.add_child(UiKit.line("Club plan", 14, UiKit.TEXT, true))
	var pick := _plan_picker(GameState.default_train_plan, false)
	pick.name = "ClubPlan"
	pick.item_selected.connect(func(i: int):
		var result := GameState.set_default_plan(str(pick.get_item_metadata(i)))
		_notice = _spend_notice(int(result.get("points", 0)))
		_build())
	plan_row.add_child(pick)
	var desc := UiKit.lbl(GameState.train_plan_description(GameState.default_train_plan)
			+ " Anyone without his own plan follows it.", 12, UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	return panel


## A plan dropdown. With `with_club`, the first entry follows the club plan.
func _plan_picker(current: String, with_club: bool) -> OptionButton:
	var pick := UiKit.option()
	pick.custom_minimum_size = Vector2(0, 44)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if with_club:
		pick.add_item("Club plan (%s)" % GameState.train_plan_label(GameState.default_train_plan))
		pick.set_item_metadata(0, "")
	for row in GameState.train_plan_options():
		pick.add_item(str(row[1]))
		pick.set_item_metadata(pick.item_count - 1, str(row[0]))
	for i in range(pick.item_count):
		if str(pick.get_item_metadata(i)) == current:
			pick.select(i)
	return pick


func _spend_notice(points: int) -> String:
	return "Plan updated. Banked XP bought %d stat points." % points if points > 0 \
			else "Plan updated. It will spend XP after the next game."


func _list_panel() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 10, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _wide:
		panel.custom_minimum_size.x = 280
	var v := UiKit.vbox(6)
	panel.add_child(v)
	v.add_child(UiKit.heading("YOUR LIST", 24))
	var tabs := UiKit.hbox(2)
	v.add_child(tabs)
	for item in ROLE_TABS:
		var key := str(item[0])
		var b := UiKit.tab(str(item[1]), _role == key)
		b.pressed.connect(_set_role.bind(key))
		tabs.add_child(b)
	var search := UiKit.search_field(_query)
	search.text_changed.connect(func(text: String):
		_query = text
		_refresh_rows())
	v.add_child(search)
	var rows := UiKit.vbox(4)
	rows.name = "TrainingRows"
	_list_scroll = UiKit.scroll(rows)
	v.add_child(_list_scroll)
	_fill_rows(rows)
	return panel


func _set_role(role: String) -> void:
	_role = role
	_build()


func _refresh_rows() -> void:
	if not is_instance_valid(_list_scroll):
		_build()
		return
	var rows := _list_scroll.get_child(0)
	_fill_rows(rows)


func _fill_rows(rows: Node) -> void:
	UiKit.clear(rows)
	var shown := 0
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		if _role != "" and _role != role:
			continue
		var group: Array = []
		for p in GameState.my_list:
			if str(p.get("role", "")) != role:
				continue
			if not _matches(p):
				continue
			group.append(p)
		if group.is_empty():
			continue
		group.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		rows.add_child(UiKit.lbl("%s  (%d)" % [UiKit.ROLE_LABEL[role], group.size()],
				12, UiKit.ROLE_COLOUR[role], true))
		for p in group:
			rows.add_child(_player_row(p))
			shown += 1
	if shown == 0:
		rows.add_child(UiKit.lbl("No players match.", 16, UiKit.TEXT, true))


func _matches(p: Dictionary) -> bool:
	var q := _query.strip_edges().to_lower()
	if q == "":
		return true
	return GameDB.player_search_text(p).to_lower().contains(q)


func _player_row(p: Dictionary) -> Control:
	var id := str(p["id"])
	var selected := id == _selected
	var b := UiKit.btn("", 14)
	b.name = "Trainee_" + id
	b.custom_minimum_size.y = 58
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		b.add_theme_stylebox_override("normal", UiKit.style(Color("263025"), 8, 6, UiKit.GOLD))
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	b.add_child(h)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiKit.ellipsis(GameDB.player_display_name(p), 15, UiKit.TEXT, true))
	var gain := GameState.xp_gain_for(id)
	var meta := "%d OVR  ·  %d POT  ·  %d XP  ·  %s" % [int(p["overall"]),
			int(p.get("potential", p["overall"])), int(p.get("xp", 0)),
			GameState.train_plan_label(GameState.plan_for(p))]
	if gain > 0:
		meta += "  ·  +%d last game" % gain
	info.add_child(UiKit.ellipsis(meta, 12, UiKit.GOLD if gain > 0 else UiKit.MUTED))
	var duty := GameState.last_duty(id)
	if duty == "Interchange":
		h.add_child(UiKit.line("INT", 11, UiKit.MUTED))
	elif duty == "Not selected":
		h.add_child(UiKit.line("OUT", 11, UiKit.MUTED))
	_ignore_mouse(h)
	b.pressed.connect(_open_player.bind(id))
	return b


func _open_player(id: String) -> void:
	_selected = id
	_showing_detail = true
	_notice = ""
	_build()


func _detail_panel() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 10, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 280
	var outer := UiKit.vbox(6)
	panel.add_child(outer)
	var p := GameState.list_player(_selected)
	if p.is_empty():
		outer.add_child(UiKit.lbl("Choose a player from the list.", 16, UiKit.TEXT, true))
		outer.add_child(UiKit.lbl("Each row is one player. Open them to spend the XP they earned.", 13, UiKit.MUTED))
		return panel
	if not _wide:
		var back := UiKit.btn("‹ All players", 15)
		back.pressed.connect(func():
			_showing_detail = false
			_build())
		outer.add_child(back)
	var head := UiKit.vbox(2)
	outer.add_child(head)
	head.add_child(UiKit.ellipsis(GameDB.player_display_name(p), 20, UiKit.TEXT, true))
	var duty := GameState.last_duty(_selected)
	var duty_text := duty if duty != "" else "Not yet played"
	head.add_child(UiKit.lbl("%s  ·  %s  ·  %d OVR  ·  %d POT" % [Ratings.role_tag(p), duty_text,
			int(p["overall"]), int(p.get("potential", p["overall"]))], 13, UiKit.MUTED))
	var background := _background_line(p)
	if background != "":
		var bl := UiKit.lbl(background, 12, UiKit.MUTED)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(bl)
	var pot_note := _potential_note(p)
	if pot_note != "":
		head.add_child(UiKit.lbl(pot_note, 13, UiKit.GOOD))
	head.add_child(UiKit.lbl("%d XP to spend  ·  %d games on the list" % [int(p.get("xp", 0)),
			int(p.get("xp_games", 0))], 15, UiKit.GOLD, true))
	if _notice != "":
		head.add_child(UiKit.lbl(_notice, 13, UiKit.GOOD, true))
	var plan_row := UiKit.hbox(8)
	head.add_child(plan_row)
	plan_row.add_child(UiKit.line("Plan", 14, UiKit.TEXT, true))
	var pick := _plan_picker(str(p.get("train_plan", "")), true)
	pick.name = "PlayerPlan"
	var pid := _selected
	pick.item_selected.connect(func(i: int):
		var gains := GameState.set_player_plan(pid, str(pick.get_item_metadata(i)))
		var pts := 0
		for k in gains:
			pts += int(gains[k])
		_notice = _spend_notice(pts)
		_build())
	plan_row.add_child(pick)
	var plan_desc := UiKit.lbl(GameState.train_plan_description(GameState.plan_for(p)), 12, UiKit.MUTED)
	plan_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(plan_desc)
	var last_gains := _last_auto_gains(_selected)
	if last_gains != "":
		head.add_child(UiKit.lbl("Last game his plan bought: " + last_gains, 12, UiKit.GOOD))
	head.add_child(UiKit.lbl(
			"Or buy points by hand below. A point costs more as the stat rises; 99 is the cap.",
			12, UiKit.MUTED))
	var body := UiKit.vbox(6)
	_detail_scroll = UiKit.scroll(body)
	outer.add_child(_detail_scroll)
	for row in GameState.TRAIN_STATS:
		body.add_child(_stat_row(p, str(row[0]), str(row[1])))
	return panel


func _stat_row(p: Dictionary, key: String, label: String) -> Control:
	var card := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
	var v := UiKit.vbox(4)
	card.add_child(v)
	var cur := int((p["attr"] as Dictionary).get(key, 1))
	var cost := GameState.train_cost(p, key)
	var h := UiKit.hbox(8)
	v.add_child(h)
	var name := UiKit.ellipsis(label, 15, UiKit.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name)
	var value := UiKit.line(str(cur), 18, _attr_colour(float(cur)), true)
	value.custom_minimum_size.x = 32
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	var what := UiKit.lbl(StatGuide.short(key), 12, UiKit.MUTED)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(what)
	v.add_child(_bar(cur))
	var actions := UiKit.hbox(6)
	v.add_child(actions)
	var one := UiKit.btn("MAX" if cost < 0 else "+1  ·  %d XP" % cost, 13)
	one.clip_text = true
	one.custom_minimum_size = Vector2(0, 44)
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.disabled = cost < 0 or int(p.get("xp", 0)) < cost
	one.pressed.connect(_train.bind(_selected, key, 1))
	actions.add_child(one)
	var batch := GameState.affordable_points(_selected, key, 5)
	if batch >= 2:
		var many := UiKit.btn("+%d" % batch, 13)
		many.custom_minimum_size = Vector2(64, 44)
		many.pressed.connect(_train.bind(_selected, key, batch))
		actions.add_child(many)
	return card


func _train(player_id: String, key: String, points: int) -> void:
	var result := GameState.train_stat(player_id, key, points)
	if not bool(result.get("ok", false)):
		_notice = str(result.get("reason", "Could not train that stat."))
	else:
		var label := GameState.train_stat_label(key)
		var ov := int(result["overall_after"]) - int(result["overall_before"])
		var ov_text := "Overall unchanged" if ov == 0 else "Overall %d to %d" % [
				int(result["overall_before"]), int(result["overall_after"])]
		_notice = "%s %d to %d. %s. %d XP left." % [label, int(result["stat_before"]),
				int(result["stat_after"]), ov_text, int(result["xp"])]
	_build()


func _bar(value: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 8)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.10)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(track)
	var fill := ColorRect.new()
	fill.color = _attr_colour(float(value))
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(float(value) / 99.0, 0.0, 1.0)
	holder.add_child(fill)
	return holder


func _attr_colour(v: float) -> Color:
	if v >= 75.0:
		return UiKit.GOOD
	if v >= 55.0:
		return UiKit.GOLD
	if v >= 40.0:
		return Color(0.80, 0.76, 0.55)
	return UiKit.BAD


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child)


## Why this player trains cheap (or dear): potential sets the price.
func _potential_note(p: Dictionary) -> String:
	var mult := Potential.training_multiplier(p)
	if bool(p.get("rehab", false)):
		return "Rehab: back near his %d POT after this season. Training %d%% off until then." % [
				int(p["potential"]), int(round((1.0 - mult) * 100.0))]
	if mult < 0.95:
		return "Room to grow: training %d%% off below his potential." % int(round((1.0 - mult) * 100.0))
	if mult > 1.0:
		return "At his ceiling: training costs 50% more."
	return ""


## Where his POT comes from: draft pedigree and recent rated seasons.
func _background_line(p: Dictionary) -> String:
	var bits: PackedStringArray = []
	if p.has("drafted_pick"):
		var kind := str(p.get("drafted_type", "national"))
		bits.append("Pick %d, %d %s draft" % [int(p["drafted_pick"]), int(p.get("drafted_year", 0)),
				"national" if kind == "national" else kind])
	var seasons: PackedStringArray = []
	for season in p.get("history", []):
		if int(season[0]) >= 2023:
			seasons.append("%d  %d" % [int(season[0]), int(season[1])])
	if not seasons.is_empty():
		bits.append("Rated " + " · ".join(seasons))
	return "  ·  ".join(bits)


## "Marking +2, Pressure +1" from the last game's plan spending.
func _last_auto_gains(player_id: String) -> String:
	var auto: Dictionary = GameState.last_training_report.get("auto", {})
	var gains: Dictionary = (auto.get("by_player", {}) as Dictionary).get(player_id, {})
	var bits: PackedStringArray = []
	for key in gains:
		bits.append("%s +%d" % [GameState.train_stat_label(key), int(gains[key])])
	return ", ".join(bits)
