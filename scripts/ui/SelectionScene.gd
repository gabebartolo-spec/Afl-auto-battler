extends Control
## Team selection: your match-day 23, built on the field (TeamBuilder; the
## director's PC playtest, 2026-10-07). Until you move someone the best side
## is picked for you each week; your first move makes the side yours, and it
## stays yours until you choose an Auto-pick strategy again. A gap (an
## injured player) is filled automatically on match day.

var _root: VBoxContainer
var _notice := ""
var _synergy_overlay: Control
var _plan_overlay: Control      # the game plan chooser
var _matchup_overlay: Control   # who goes to their key forward
var _sheet: Control             # a player's profile, open over the list
var _scroll_box: ScrollContainer
var _undo := {}            # the side before the last Auto-pick, for Undo
var _view := "mine"        # "mine" or "opp": the oval shows them, read-only
var _line_cache := {}      # the other clubs' lines, built once a visit


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

	var wide := UiKit.view_width(self) >= 900.0 and UiKit.view_width(self) > UiKit.view_height(self)
	# Until you move someone the side is picked for you each week; the first
	# move makes it yours (TeamBuilder sets the selection).
	var head := UiKit.panel(UiKit.PANEL, 10, 8)
	head.name = "BuilderHead"
	_root.add_child(head)
	var hv := UiKit.vbox(6)
	head.add_child(hv)
	# Wraps on a phone rather than pushing the screen wider.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	hv.add_child(actions)
	# Auto-pick is an action, never a mode: choose a strategy and it sets the
	# side; your moves after that stay yours (director, 2026-10-07).
	var pick := MenuButton.new()
	pick.name = "AutoPick"
	pick.text = "Auto-pick"
	pick.flat = false
	UiKit.style_button(pick, 15)
	pick.custom_minimum_size = Vector2(150, 44)
	var menu := pick.get_popup()
	menu.add_theme_font_override("font", UiKit.FONT)
	menu.add_theme_font_size_override("font_size", 16)
	var strategies := [["best", "Best side"], ["rest", "Rest tired players"], ["youth", "Blood the youth"],
			["mine", "My Selected Best 23"]]
	for i in range(strategies.size()):
		menu.add_item(str(strategies[i][1]), i)
	menu.id_pressed.connect(func(idx: int):
		_apply_strategy(str(strategies[idx][0])))
	actions.add_child(pick)
	var save := UiKit.btn("Save as my Best 23", 14)
	save.name = "SaveBest23"
	save.custom_minimum_size = Vector2(0, 44)
	save.pressed.connect(func():
		GameState.set_best23(GameState.current_side())
		_notice = "Saved as your Best 23. Choose it any week from Auto-pick."
		_build())
	actions.add_child(save)
	if not _undo.is_empty():
		var undo := UiKit.btn("Undo", 14)
		undo.name = "UndoPick"
		undo.flat = true
		undo.custom_minimum_size = Vector2(72, 44)
		undo.pressed.connect(func():
			GameState.set_selection(_undo)
			_undo = {}
			_notice = "Back to your side before the auto-pick."
			_build())
		actions.add_child(undo)
	var dual := UiKit.choice_grid("DualRuck", [["off", "One ruck"], ["on", "Dual ruck"]],
			"on" if GameState.dual_ruck() else "off", 2, func(k):
				GameState.set_dual_ruck(k == "on")
				_notice = "Dual ruck on: Auto-pick names a second ruck on the bench." if k == "on" else "One ruck: Auto-pick fills the bench with the best of the rest."
				_build())
	dual.custom_minimum_size.x = 200
	actions.add_child(dual)
	var nxt := GameState.my_next_opponent()
	if not nxt.is_empty():
		# Look at them on the same oval (director, 2026-10-07), and what your
		# assistant has seen of them - said there, and only there.
		var opp_name := GameDB.club_short(str(nxt["code"]))
		var flip := UiKit.choice_grid("OvalView", [["mine", "Your team"], ["opp", opp_name]], _view, 2, func(k):
			_view = k
			_build())
		flip.custom_minimum_size.x = 220
		actions.add_child(flip)
		var report := UiKit.btn("Assistant's report", 14)
		report.name = "AssistantReport"
		report.custom_minimum_size = Vector2(0, 44)
		report.pressed.connect(_show_report.bind(str(nxt["code"])))
		actions.add_child(report)
	hv.add_child(_lines_view())
	if _notice != "":
		var nl := _para(_notice, 13, UiKit.GOOD)
		nl.name = "BuilderNote"
		hv.add_child(nl)
	hv.add_child(_synergy_view())

	var body := UiKit.vbox(10)
	_scroll_box = UiKit.scroll(body)
	_scroll_box.name = "SelectionScroll"
	_root.add_child(_scroll_box)
	_restore_scroll.call_deferred(keep)
	var builder := TeamBuilder.new()
	builder.name = "TeamBuilder"
	builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opp_code := str(GameState.my_next_opponent().get("code", ""))
	if _view == "opp" and opp_code != "":
		var proj := _para("%s as they would take the field this week (projected: they name their side on match day). They kick the other way." % GameDB.club_name(opp_code), 13, UiKit.MUTED)
		proj.name = "OppProjected"
		body.add_child(proj)
		body.add_child(builder)
		var their: Dictionary = GameState.opponent_side(opp_code)
		builder.setup(their["side"], wide, their["list"], true)
		builder.inspect.connect(_open_opponent.bind(their["list"]))
	else:
		body.add_child(builder)
		builder.setup(GameState.current_side(), wide)
	builder.inspect.connect(_open_profile)
	builder.changed.connect(func(note: String):
		_notice = note
		_undo = {}
		_refresh_head())
	if auto:
		var a := _para("Picked for you each week until you move someone.", 12, UiKit.MUTED)
		a.name = "AutoNote"
		hv.add_child(a)
	# The team sheet: who is in and out since your last match, and why.
	var changes := GameState.week_changes_text()
	if changes != "":
		var ch := _para(changes, 14, UiKit.TEXT)
		ch.name = "TeamChanges"
		body.add_child(ch)
	body.add_child(_this_week())


## Your lines as they stand in the competition, from the side as arranged now.
func _lines_view() -> Control:
	var words: Dictionary = Matchup.line_standings(GameState.my_club, GameState.season.lists,
			GameState.season.selections, GameState.my_squad(), _line_cache)
	var text := "Midfield %s · Ruck %s · Forwards %s · Defence %s" % [words["midfield"], words["ruck"],
			words["attack"], words["defence"]]
	var l := _para(text, 13, UiKit.TEXT)
	l.name = "LineStandings"
	return l


## After a move: the lines, the note and the synergies, without rebuilding
## the builder (or losing your place in it).
func _refresh_head() -> void:
	var head: Control = _root.find_child("BuilderHead", true, false)
	if head == null:
		return
	var hv: VBoxContainer = head.get_child(0)
	var old_lines: Control = hv.find_child("LineStandings", false, false)
	if old_lines != null:
		var at := old_lines.get_index()
		hv.remove_child(old_lines)
		old_lines.queue_free()
		var fresh := _lines_view()
		hv.add_child(fresh)
		hv.move_child(fresh, at)
	var old_note: Control = hv.find_child("BuilderNote", false, false)
	if old_note != null:
		hv.remove_child(old_note)
		old_note.queue_free()
	var syn: Control = hv.find_child("Synergies", false, false)
	if syn != null:
		hv.remove_child(syn)
		syn.queue_free()
	if _notice != "":
		var nl := _para(_notice, 13, UiKit.GOOD)
		nl.name = "BuilderNote"
		hv.add_child(nl)
	hv.add_child(_synergy_view())


## Their player's profile: who he is and how he plays, nothing to change.
func _open_opponent(id: String, list: Array) -> void:
	for p in list:
		if str(p["id"]) == id:
			_close_profile()
			_sheet = PlayerSheet.open(self, p, func(): _sheet = null, [])
			return


## The Assistant's report (director, 2026-10-07): how this week's opponent
## plays and who matters, each fact once (GameState.opponent_report). The
## line against line stays on the screen, where it moves with your side.
func _show_report(code: String) -> void:
	_close_synergies()
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_synergy_overlay = box["overlay"]
	_synergy_overlay.name = "AssistantReportSheet"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Assistant's report: %s" % GameDB.club_name(code), UiKit.H1, UiKit.TEXT, true))
	var parts := GameState.opponent_report(code)
	for part in parts:
		v.add_child(UiKit.spacer(6))
		v.add_child(UiKit.lbl(str(part[0]), UiKit.BODY, UiKit.TEXT, true))
		for t in part[1]:
			v.add_child(_para(str(t), 14, UiKit.TEXT))
	if parts.is_empty():
		v.add_child(_para("Too early to say much about them: they have barely played.", 14, UiKit.MUTED))
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_synergies)
	box["footer"].add_child(close)


func _apply_strategy(key: String) -> void:
	var r: Dictionary = GameState.auto_pick(key)
	if (r["side"] as Dictionary).is_empty():
		_notice = str(r["note"])
		_build()
		return
	_undo = GameState.my_selection()
	GameState.set_selection(r["side"])
	_notice = str(r["note"])
	_build()


## The line synergies your 18 switch on - what the side is good at - any
## one it is a single player short of (a fact, never a suggested swap: the
## choice is yours), and the full rules one tap away.
func _synergy_view() -> Control:
	var h := UiKit.hbox(8)
	h.name = "Synergies"
	var on: PackedStringArray = []
	for r in Traits.progress(GameState.my_squad().ground):
		if bool(r["active"]):
			on.append(Traits.with_effect(str(r["key"])))
	var l := _para("Your side has: " + ", ".join(on) + "." if not on.is_empty()
			else "No line synergies in this side.", 13, UiKit.GOOD if not on.is_empty() else UiKit.MUTED)
	var lines := UiKit.vbox(2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(l)
	var short := Traits.short_text(GameState.my_squad().ground)
	if short != "":
		var s := _para(short, 13, UiKit.MUTED)
		s.name = "SynergyShort"
		lines.add_child(s)
	h.add_child(lines)
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
			head.add_child(UiKit.line("On", UiKit.SECONDARY, UiKit.GOOD, true))
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
		if not bool(active.get(key, false)):
			row.add_child(_complete_button(str(key)))
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_synergies)
	box["footer"].add_child(close)


## Complete a synergy in one tap (director, 2026-10-07): the fewest swaps
## from your available list, then Undo if you want your side back. Disabled,
## with the reason, when your list can't do it.
func _complete_button(key: String) -> Control:
	var v := UiKit.vbox(2)
	var r: Dictionary = GameState.complete_synergy(key, GameState.current_side())
	var b := UiKit.btn("Complete %s" % str(Traits.SYNERGIES[key]["label"]).to_lower(), 14)
	b.name = "Complete_" + key
	b.custom_minimum_size = Vector2(0, 44)
	b.disabled = str(r["problem"]) != ""
	b.pressed.connect(func():
		_undo = GameState.current_side()
		var fresh: Dictionary = GameState.complete_synergy(key, GameState.current_side())
		if str(fresh["problem"]) == "":
			GameState.set_selection(fresh["side"])
			_notice = str(fresh["note"])
		_close_synergies()
		_build())
	v.add_child(b)
	if str(r["problem"]) != "":
		var why := _para(str(r["problem"]), 12, UiKit.MUTED)
		why.name = "CompleteWhy_" + key
		v.add_child(why)
	return v


func _close_synergies() -> void:
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_synergy_overlay.queue_free()
	_synergy_overlay = null


func _restore_scroll(value: int) -> void:
	# After the rebuilt list has its height, or the offset is clamped to 0.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll_box):
		_scroll_box.scroll_vertical = value


## A player's profile over the list; closing it leaves the list untouched. A
## player with few senior games can be backed from here (Backing).
func _open_profile(id: String) -> void:
	var p := GameState.list_player(id)
	if p.is_empty():
		return
	_close_profile()
	var actions := []
	if GameState.can_back(p):
		var run := MatchNotes.count_word(Backing.RUN_GAMES)
		actions.append({"name": "BackRun", "label": "Back for %s games" % run,
				"detail": "A run of %s senior games, starting with the next. Leave a fit player out and the promise breaks, and it stings." % run,
				"run": _back.bind(id)})
	_sheet = PlayerSheet.open(self, p, func(): _sheet = null, actions)


## Promise a player a run: the profile closes and the screen says what changed.
func _back(id: String) -> void:
	var out := GameState.back_player(id)
	_close_profile()
	if out != "":
		_notice = out
	_build()


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


## This week, what the choice rests on: line against line (your half moves
## with your selection), your own news, their key forwards, then the game
## plan you take in. How they play and who matters are in the assistant's
## report, not repeated here. Facts, never a verdict.
func _this_week() -> Control:
	var v := UiKit.vbox(3)
	v.name = "SelectionWeek"
	var nxt := GameState.my_next_opponent()
	if nxt.is_empty():
		v.add_child(_strength_line())
		_backing_lines(v)
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
	var own := GameState.my_week_notes()
	if not own.is_empty() or not GameState.backing_notes().is_empty():
		v.add_child(UiKit.spacer(4))
	# A key player already on the team sheet's outs is said there, once.
	var sheet_outs := {}
	for o in GameState.week_changes()["outs"]:
		sheet_outs[str(o["id"])] = true
	for f in own:
		if sheet_outs.has(str(f.get("player_id", ""))):
			continue
		# Only an injury is bad news; a milestone is just marked.
		v.add_child(_para(str(f["text"]), 13, UiKit.BAD if str(f.get("key", "")) == "own_injury" else UiKit.TEXT))
	_backing_lines(v)
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
	v.add_child(UiKit.spacer(6))
	v.add_child(_plan_row())
	return v


## What you have promised: one line for each run you have given a player,
## said as a fact (Backing). Not part of the team sheet's outs: a promise to a
## player who is out still stands, and the line says it waits.
func _backing_lines(v: VBoxContainer) -> void:
	for f in GameState.backing_notes():
		var l := _para(str(f["text"]), 13, UiKit.TEXT)
		l.name = "Backing_" + str(f["player_id"])
		v.add_child(l)


## "Moore is on Curnow." with the way to change it.
func _matchup_row(m: Dictionary) -> Control:
	var f: Dictionary = m["fwd"]
	var h := UiKit.hbox(8)
	h.name = "Matchup_" + str(f["id"])
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var who := _para(MatchNotes.matchup_line(GameDB.player_display_name(f),
			GameDB.player_display_name(m.get("def", {}))), 14, UiKit.TEXT)
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
		var b := UiKit.btn("", UiKit.BODY)
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
	var done := UiKit.btn("Close", UiKit.NAME)
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
	var done := UiKit.btn("Done", UiKit.NAME, true)
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
