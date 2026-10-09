extends Control
## Training. Every listed player is here. XP is personal and earned every
## game; each player's training plan spends it automatically after the game
## (or banks it, on Manual), and any stat can still be trained by hand.

const ROLES := ["", "DEF", "MID", "RUCK", "FWD"]
const ROLE_NOUN := {"RUCK": "ruck", "MID": "midfielder", "DEF": "defender", "FWD": "forward"}
# As Team selection names them: the positions' own short forms.
const ROLE_TABS := [["", "All"], ["DEF", "DEF"], ["MID", "MID"], ["RUCK", "RUCK"], ["FWD", "FWD"]]
const LONG_PRESS_SECONDS := 0.45

var _role := ""
var _query := ""
var _selected := ""
var _showing_detail := false
var _notice := ""
var _advanced := false
var _wide := false
## Long-press one player to enter group selection. Once active, ordinary
## taps add/remove players; the group picker only offers plans valid for all.
var _bulk_selected := {}
var _hold_tokens := {}
var _suppress_open := {}
var _hold_serial := 0
## Where the finger went down: a press that turns into a scroll is neither
## a tap nor a long press.
var _press_scroll := 0
var _press_pos := Vector2.ZERO
const DRAG_SLOP := 12.0   # the list's scroll deadzone
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
	# Your club's colour behind the page, as on the hub and match day
	# (director, 2026-10-10: every screen in the gameday style).
	add_child(ClubBackdrop.new().setup(GameState.my_club))
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


## Router back hook: close the stat guide or intro, or step out of the
## player detail back to the list, before leaving Training. Returning false
## lets the router take the scene back to whatever was viewed before.
func handle_back() -> bool:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
		return true
	if not _bulk_selected.is_empty():
		_bulk_selected.clear()
		_notice = ""
		_build()
		return true
	if _showing_detail:
		_showing_detail = false
		_build()
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
	UiKit.close_on_outside_tap(box)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("How training works", UiKit.TITLE))
	for line in [
		"Pick what kind of footballer each player should become. His plan spends the XP he earns after every game on exactly that - an inside midfielder on winning the ball, a key forward on marking and goals.",
		"Position plan is the safe default: it trains what his position is judged on. Change a plan whenever you like; banked XP is spent straight away.",
		"Playing senior football develops a player fastest. Fit players you leave out develop in the reserves at about half the rate; injured and rested players barely at all.",
		"Young players with room below their potential improve quickest. Manual pauses a player's development until you spend his XP by hand.",
	]:
		var l := UiKit.lbl(line, 14, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var guide := UiKit.btn("Open stat guide", UiKit.NAME)
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
	var guide := UiKit.btn("Stat guide", UiKit.SECONDARY)
	guide.name = "StatGuideButton"
	guide.custom_minimum_size = Vector2(96, 44)
	guide.pressed.connect(_open_guide)
	# The top-bar back steps out of the player detail first, then leaves.
	_root.add_child(UiKit.top_bar("Training", true, guide,
			Callable(self, "handle_back")))
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
		v.add_child(UiKit.lbl(str(report.get("label", "Last game")), 15, UiKit.EMPH, true))
		var line := GameState.training_summary_line()
		var what := UiKit.lbl(line if line != "" else "Training: no rating changes from the last game.", UiKit.SECONDARY,
				UiKit.GOOD if line != "" else UiKit.MUTED)
		what.name = "TrainingNews"
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(what)
		var reserves := GameState.reserves_summary_line()
		if reserves != "":
			v.add_child(UiKit.lbl(reserves, UiKit.SECONDARY, UiKit.MUTED))
	else:
		v.add_child(UiKit.lbl("No game played yet. Players develop after every match.", UiKit.BODY, UiKit.EMPH, true))
	var paused := 0
	for p in GameState.my_list:
		if GameState.plan_for(p) == "manual":
			paused += 1
	if paused > 0:
		var warn := UiKit.lbl("%d %s on Manual: development paused until you spend by hand." % [
				paused, "player" if paused == 1 else "players"], 13, UiKit.BAD, true)
		warn.name = "PausedWarning"
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(warn)
	return panel


## This player's plans as taps: Position plan, his roles' archetypes,
## Manual last. The chosen one is outlined.
func _plan_picker(p: Dictionary, on_pick: Callable) -> Control:
	# A dual-role player's Position plan trains his first role: say which.
	var first := str(p.get("role", ""))
	var dual := str(p.get("role2", "")) != "" and str(p.get("role2", "")) != first
	var options := []
	for key in GameState.plans_for(p):
		var label := GameState.train_plan_label(key)
		if key == "position" and dual:
			label = "Position plan (%s)" % PlayerProfile.role_word(first).to_lower()
		elif key == "manual":
			label = "Manual"
		elif key.begins_with(GameState.LEARN_PREFIX):
			label = "Learn " + str(GameState.LEARN_JOBS[key.trim_prefix(GameState.LEARN_PREFIX)]["word"])
		options.append([key, label])
	return UiKit.choice_grid("PlayerPlan", options, GameState.plan_for(p), 2, on_pick)


func _spend_notice(gains: Dictionary, ov_before: int, ov_after: int) -> String:
	if ov_after > ov_before:
		return "Plan updated. Banked XP lifted him from %d to %d." % [ov_before, ov_after]
	if not gains.is_empty():
		return "Plan updated. Banked XP went straight into it."
	return "Plan updated. It takes effect after the next game."


func _list_panel() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 10, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _wide:
		panel.custom_minimum_size.x = 280
	var v := UiKit.vbox(6)
	panel.add_child(v)
	v.add_child(UiKit.heading("Your list", UiKit.TITLE))
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
	if _bulk_selected.is_empty():
		v.add_child(UiKit.lbl("Click and hold a player to select several." if ScreenLayout.is_desktop()
				else "Long-press a player to select several.", 12, UiKit.MUTED))
	else:
		v.add_child(_bulk_panel())
	var rows := UiKit.vbox(4)
	rows.name = "TrainingRows"
	_list_scroll = UiKit.scroll(rows)
	v.add_child(_list_scroll)
	_fill_rows(rows)
	return panel


func _set_role(role: String) -> void:
	_role = role
	_build()


## Group training stays deliberately small: select players, then choose one
## plan that makes sense for every player in the group. A mixed-position
## group therefore gets Position plan / Manual rather than nonsense such as
## putting a ruck on a key-forward plan.
func _bulk_panel() -> Control:
	var panel := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
	panel.name = "BulkTraining"
	var v := UiKit.vbox(4)
	panel.add_child(v)
	var h := UiKit.hbox(8)
	v.add_child(h)
	var count := _bulk_selected.size()
	var head := UiKit.lbl("%d %s selected" % [count, "player" if count == 1 else "players"],
			14, UiKit.TEXT, true)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(head)
	var clear := UiKit.btn("Clear", UiKit.SECONDARY)
	clear.name = "ClearBulk"
	clear.custom_minimum_size = Vector2(72, 44)
	clear.pressed.connect(func():
		_bulk_selected.clear()
		_notice = ""
		_build())
	h.add_child(clear)
	v.add_child(UiKit.lbl("Apply one development focus to the group.", 12, UiKit.MUTED))
	var options := []
	for key in _bulk_plans():
		var label := GameState.train_plan_label(str(key))
		if str(key) == "manual":
			label = "Manual"
		options.append([str(key), label])
	var picker := UiKit.choice_grid("GroupPlan", options, "", 2, _apply_bulk_plan)
	v.add_child(picker)
	if _notice != "":
		var note := UiKit.lbl(_notice, 12, UiKit.GOOD)
		note.name = "BulkNotice"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(note)
	return panel


func _bulk_plans() -> Array:
	var ids: Array = _bulk_selected.keys()
	if ids.is_empty():
		return []
	var first := GameState.list_player(str(ids[0]))
	if first.is_empty():
		return []
	var common: Array = GameState.plans_for(first).duplicate()
	for raw_id in ids.slice(1):
		var p := GameState.list_player(str(raw_id))
		if p.is_empty():
			continue
		var valid: Array = GameState.plans_for(p)
		common = common.filter(func(key): return valid.has(key))
	return common


func _apply_bulk_plan(key: String) -> void:
	var changed := 0
	var spent := 0
	for raw_id in _bulk_selected.keys():
		var id := str(raw_id)
		var p := GameState.list_player(id)
		if p.is_empty() or not GameState.plan_valid_for(p, key):
			continue
		var before_xp := int(p.get("xp", 0))
		GameState.set_player_plan(id, key)
		spent += maxi(0, before_xp - int(GameState.list_player(id).get("xp", 0)))
		changed += 1
	var label := GameState.train_plan_label(key)
	_notice = "%s applied to %d %s." % [label, changed, "player" if changed == 1 else "players"]
	if spent > 0:
		_notice += " Banked XP was spent under the new focus."
	if is_inside_tree():
		_build()


func _toggle_bulk(id: String) -> void:
	if _bulk_selected.has(id):
		_bulk_selected.erase(id)
	else:
		_bulk_selected[id] = true
	_showing_detail = false
	_notice = ""
	if is_inside_tree():
		_build()


## The held button may be rebuilt as soon as the long press fires. A
## suppression flag prevents its eventual pressed signal from immediately
## undoing the selection; the next fresh button-down clears that flag.
func _begin_player_hold(id: String) -> void:
	_suppress_open.erase(id)
	_hold_serial += 1
	var token := _hold_serial
	_hold_tokens[id] = token
	_press_scroll = _list_scroll.scroll_vertical if is_instance_valid(_list_scroll) else 0
	_press_pos = get_global_mouse_position()
	await get_tree().create_timer(LONG_PRESS_SECONDS).timeout
	if int(_hold_tokens.get(id, -1)) != token:
		return
	_hold_tokens.erase(id)
	if _moved_since_press():
		return
	_suppress_open[id] = true
	_toggle_bulk(id)


func _end_player_hold(id: String) -> void:
	_hold_tokens.erase(id)


func _press_player(id: String) -> void:
	if _suppress_open.has(id):
		_suppress_open.erase(id)
		return
	if _moved_since_press():
		return
	if not _bulk_selected.is_empty():
		_toggle_bulk(id)
		return
	_open_player(id)


## The list scrolled, or the finger travelled, since it went down.
func _moved_since_press() -> bool:
	if is_instance_valid(_list_scroll) and absi(_list_scroll.scroll_vertical - _press_scroll) > 2:
		return true
	return get_global_mouse_position().distance_to(_press_pos) > DRAG_SLOP


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
			# All: each player once, under his own position. A position tab:
			# everyone who can play there (Ratings.plays_role, the rule the
			# draft and selection use), so a MID/FWD is in both.
			if _role == "" and str(p.get("role", "")) != role:
				continue
			if _role != "" and not Ratings.plays_role(p, role):
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
		rows.add_child(UiKit.lbl("No players match.", UiKit.NAME, UiKit.TEXT, true))


func _matches(p: Dictionary) -> bool:
	var q := _query.strip_edges().to_lower()
	if q == "":
		return true
	return GameDB.player_search_text(p).to_lower().contains(q)


func _player_row(p: Dictionary) -> Control:
	var id := str(p["id"])
	var selected := _bulk_selected.has(id) or (_bulk_selected.is_empty() and id == _selected)
	var b := UiKit.btn("", 14)
	b.name = "Trainee_" + id
	b.custom_minimum_size.y = 58
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		UiKit.set_selected(b, true)
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	b.add_child(h)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The name and plan stack is as tall as the row; centre it on the role and
	# rating rather than leaving it hugging the top.
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)
	info.add_child(UiKit.ellipsis(GameDB.player_display_name(p), UiKit.BODY, UiKit.TEXT, true))
	var plan := GameState.plan_for(p)
	if plan == "manual":
		info.add_child(UiKit.ellipsis("Manual  ·  development paused", 12, UiKit.BAD))
	else:
		info.add_child(UiKit.ellipsis("%s  ·  %s" % [_row_plan(plan),
				GameState.development_state(p)], 12, UiKit.MUTED))
	var duty := GameState.last_duty(id)
	if int(p.get("injury_weeks", 0)) > 0:
		h.add_child(UiKit.line("INJ %dw" % int(p["injury_weeks"]), UiKit.FINE, UiKit.BAD, true))
	elif duty == "Interchange":
		h.add_child(UiKit.line("INT", UiKit.FINE, UiKit.MUTED))
	elif duty == "Reserves":
		h.add_child(UiKit.line("RES", UiKit.FINE, UiKit.MUTED))
	elif duty == "Not selected":
		h.add_child(UiKit.line("OUT", UiKit.FINE, UiKit.MUTED))
	var rise := _last_rise(id)
	var ov := UiKit.line(("▲ " if rise.size() > 0 else "") + str(int(p["overall"])), 17,
			UiKit.GOOD if rise.size() > 0 else UiKit.TEXT, true)
	ov.custom_minimum_size.x = 48
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ov)
	_ignore_mouse(h)
	b.button_down.connect(_begin_player_hold.bind(id))
	b.button_up.connect(_end_player_hold.bind(id))
	b.pressed.connect(_press_player.bind(id))
	return b


## The plan under his name, said as a plan: "Training as a key defender",
## never a bare "Key defender" that reads as what he is.
static func _row_plan(plan: String) -> String:
	var label := GameState.train_plan_label(plan)
	if plan == "position":
		return label
	if plan.begins_with(GameState.LEARN_PREFIX):
		return "Learning to play %s" % str(GameState.LEARN_JOBS[plan.trim_prefix(GameState.LEARN_PREFIX)]["word"])
	var noun := label.to_lower()
	return "Training as %s %s" % ["an" if noun.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a", noun]


## [from, to] if training lifted his OVR after the last game, else [].
func _last_rise(id: String) -> Array:
	for r in (GameState.last_training_report.get("auto", {}) as Dictionary).get("rises", []):
		if str(r[0]) == id:
			return [int(r[1]), int(r[2])]
	return []


## A full senior game at this career's difficulty, to set the reserves
## figure against.
func _senior_game_xp() -> int:
	return GameState.XP_SENIOR_GAME


func _open_player(id: String) -> void:
	_selected = id
	_showing_detail = true
	_notice = ""
	_advanced = false
	_build()


func _detail_panel() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 10, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 280
	var outer := UiKit.vbox(6)
	panel.add_child(outer)
	var p := GameState.list_player(_selected)
	if p.is_empty() and _wide and not GameState.my_list.is_empty():
		# A wide screen opens your best player rather than an empty panel
		# (director, 2026-10-10: no empty space on a PC).
		var best: Dictionary = GameState.my_list[0]
		for q in GameState.my_list:
			if int(q.get("overall", 0)) > int(best.get("overall", 0)):
				best = q
		_selected = str(best["id"])
		p = best
	if p.is_empty():
		outer.add_child(UiKit.lbl("Choose a player from the list.", UiKit.NAME, UiKit.TEXT, true))
		outer.add_child(UiKit.lbl("Open a player to choose what kind of footballer he develops into.", UiKit.SECONDARY, UiKit.MUTED))
		return panel
	if not _wide:
		var back := UiKit.btn("‹ All players", UiKit.BODY)
		back.pressed.connect(func():
			_showing_detail = false
			_build())
		outer.add_child(back)
	var body := UiKit.vbox(6)
	_detail_scroll = UiKit.scroll(body)
	outer.add_child(_detail_scroll)
	# Who he is and where he stands.
	body.add_child(UiKit.ellipsis(GameDB.player_display_name(p), 20, UiKit.TEXT, true))
	var duty := GameState.last_duty(_selected)
	body.add_child(UiKit.lbl("%s  ·  %s" % [Ratings.role_tag(p), duty if duty != "" else "Not yet played"],
			13, UiKit.MUTED))
	var standing := UiKit.hbox(10)
	body.add_child(standing)
	standing.add_child(UiKit.line("OVR %d" % int(p["overall"]), 22, UiKit.EMPH, true))
	var rise := _last_rise(_selected)
	var state := GameState.development_state(p)
	var state_l := UiKit.lbl(state + ("  ·  up from %d last game" % int(rise[0]) if rise.size() > 0 else ""), 14,
			UiKit.GOOD if rise.size() > 0 else UiKit.TEXT)
	state_l.name = "DevState"
	state_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	standing.add_child(state_l)
	if not Traits.of(p).is_empty():
		body.add_child(UiKit.trait_chips(p))
	# The decision: what kind of footballer he becomes.
	var focus := UiKit.panel(UiKit.PANEL_ALT, 10, 8)
	body.add_child(focus)
	var fv := UiKit.vbox(4)
	focus.add_child(fv)
	fv.add_child(UiKit.lbl("Development focus", 12, UiKit.MUTED, true))
	var plan := GameState.plan_for(p)
	var plan_name := UiKit.lbl(GameState.train_plan_label(plan), UiKit.HEADING, UiKit.BAD if plan == "manual" else UiKit.EMPH, true)
	plan_name.name = "FocusName"
	fv.add_child(plan_name)
	var meaning := UiKit.lbl(GameState.train_plan_description(plan, str(p.get("role", "MID"))), 13, UiKit.TEXT)
	meaning.name = "FocusMeaning"
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fv.add_child(meaning)
	var progress := _project_line(p)
	if progress != "":
		var pl := UiKit.lbl(progress, UiKit.SECONDARY, UiKit.TEXT, true)
		pl.name = "ProjectProgress"
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fv.add_child(pl)
	if plan != "manual":
		var working := _working_on(p)
		if working != "":
			fv.add_child(UiKit.lbl("Working on: " + working, 12, UiKit.MUTED))
	else:
		var paused := UiKit.lbl("%d XP banked and unused." % int(p.get("xp", 0)), 13, UiKit.BAD, true)
		paused.name = "ManualWarning"
		paused.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fv.add_child(paused)
	var pid := _selected
	var pick := _plan_picker(p, func(key: String):
		var q := GameState.list_player(pid)
		var before := int(q.get("overall", 0))
		var gains := GameState.set_player_plan(pid, key)
		_notice = _spend_notice(gains, before, int(GameState.list_player(pid).get("overall", 0)))
		_build())
	fv.add_child(pick)
	if _notice != "":
		fv.add_child(UiKit.lbl(_notice, UiKit.SECONDARY, UiKit.GOOD, true))
	# What is close, and what happened.
	var close: Array = Traits.near(p)
	if not close.is_empty():
		var n: Dictionary = close[0]
		# "4 more durability and he's an Engine: tires 25% slower."
		var t_text := Traits.text(str(n["key"]))
		var hint := UiKit.lbl("%d more %s and he's %s %s: %s" % [int(n["gap"]), GameState.train_stat_label(str(n["stat"])).to_lower(),
				"an" if "AEIOU".contains(Traits.label(str(n["key"])).left(1)) else "a", Traits.label(str(n["key"])),
				t_text.left(1).to_lower() + t_text.substr(1)], 12, UiKit.EMPH)
		hint.name = "TraitHint"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(hint)
	if duty == "Reserves":
		var res_line := UiKit.lbl("Developing in the reserves: +%d XP last game (a senior game is worth up to %d)." % [
				GameState.xp_gain_for(_selected), _senior_game_xp()], 13, UiKit.MUTED)
		res_line.name = "ReservesLine"
		res_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(res_line)
	# Everything else sits behind one button.
	var adv := UiKit.btn("Hide stats and hand training" if _advanced
			else "Stats and hand training  ·  %d XP banked" % int(p.get("xp", 0)), 13)
	adv.name = "AdvancedToggle"
	adv.custom_minimum_size = Vector2(0, 44)
	adv.pressed.connect(func():
		_advanced = not _advanced
		_build())
	body.add_child(adv)
	if _advanced:
		var pot := UiKit.lbl("Potential %d  ·  %s" % [int(p.get("potential", p["overall"])), _potential_note(p)],
				12, UiKit.MUTED)
		pot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(pot)
		var background := _background_line(p)
		if background != "":
			var bl := UiKit.lbl(background, 12, UiKit.MUTED)
			bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(bl)
		body.add_child(UiKit.lbl("Buy points by hand. A point costs more as the stat rises; 99 is the cap.",
				12, UiKit.MUTED))
		var rows := []
		for row in GameState.TRAIN_STATS:
			rows.append([str(row[0]), str(row[1]), GameState.stat_useful_for(p, str(row[0]))])
		rows.sort_custom(func(a, b): return bool(a[2]) and not bool(b[2]))
		for r in rows:
			body.add_child(_stat_row(p, str(r[0]), str(r[1]), bool(r[2])))
	return panel


## "Week 3 of 8. As a key forward he rates 66, his own game 71: within 3 by
## week 8 and he can be picked there." The standard he is chasing, plainly.
static func _project_line(p: Dictionary) -> String:
	var job := GameState.project_job(p)
	if job == "":
		return ""
	var role := GameState.project_role(p)
	var there := GameState.rating_as(p, role)
	var own := int(p.get("overall", 0))
	var head := "%s. As a %s he rates %d, his own game %d: " % [
		GameState.project_progress(p), str(GameState.LEARN_JOBS[job]["word"]), there, own]
	if there >= own - GameState.PROJECT_PASS:
		return head + "up to the standard, so he can be picked there after week %d." % GameState.PROJECT_WEEKS
	return head + "within %d by week %d and he can be picked there." % [GameState.PROJECT_PASS, GameState.PROJECT_WEEKS]


## "Contested 72 · Disposal 64": what his plan is spending on.
func _working_on(p: Dictionary) -> String:
	var w: Dictionary = GameState.plan_weights(p)
	var keys := w.keys()
	keys.sort_custom(func(a, b): return float(w[a]) > float(w[b]))
	var bits: PackedStringArray = []
	for k in keys.slice(0, 3):
		bits.append("%s %d" % [GameState.train_stat_label(str(k)), int((p["attr"] as Dictionary).get(k, 0))])
	return "  ·  ".join(bits)


func _stat_row(p: Dictionary, key: String, label: String, useful := true) -> Control:
	var card := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
	var v := UiKit.vbox(4)
	card.add_child(v)
	var cur := int((p["attr"] as Dictionary).get(key, 1))
	var cost := GameState.train_cost(p, key)
	var h := UiKit.hbox(8)
	v.add_child(h)
	var name := UiKit.ellipsis(label, UiKit.BODY, UiKit.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name)
	var value := UiKit.line(str(cur), UiKit.HEADING, _attr_colour(float(cur)), true)
	value.custom_minimum_size.x = 32
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	var what := UiKit.lbl(StatGuide.short(key) if useful
			else "Does little for a %s in a match." % ROLE_NOUN.get(str(p.get("role", "MID")), "player"),
			12, UiKit.MUTED if useful else UiKit.BAD)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(what)
	v.add_child(_bar(cur))
	var actions := UiKit.hbox(6)
	v.add_child(actions)
	var one := UiKit.btn("Maxed" if cost < 0 else "+1  ·  %d XP" % cost, UiKit.SECONDARY)
	one.clip_text = true
	one.custom_minimum_size = Vector2(0, 44)
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.disabled = cost < 0 or int(p.get("xp", 0)) < cost
	one.pressed.connect(_train.bind(_selected, key, 1))
	actions.add_child(one)
	var batch := GameState.affordable_points(_selected, key, 5)
	if batch >= 2:
		var many := UiKit.btn("+%d" % batch, UiKit.SECONDARY)
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
		return UiKit.EMPH
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
	var gap := int(p.get("potential", p["overall"])) - int(p["overall"])
	if gap < 0:
		return "Past his projected peak: every point costs far more."
	if mult > 1.0:
		return "Close to his projected peak: training costs more."
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
