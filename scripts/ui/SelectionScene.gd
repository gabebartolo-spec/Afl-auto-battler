extends Control
## Team selection: your match-day 23, built on the field (TeamBuilder; the
## director's PC playtest, 2026-10-07). Until you move someone the best side
## is picked for you each week; your first move makes the side yours, and it
## stays yours until you choose an Auto-pick strategy again. A gap (an
## injured player) is filled automatically on match day.
##
## No scrolling (director, 2026-10-13: "team selection being scrollable doesnt
## feel good"): "The side" is the oval, the interchange and the players not
## picked; "This week" is what the choice rests on. A phone shows one at a
## time with a tap between them; a PC shows both, side by side. Match-ups,
## game plan and tags are not asked here: they are set in the pre-bounce menu
## (director, 2026-10-13).

const WEEK_W_MIN := 460.0
const WEEK_W_MAX := 600.0

var _name_index := {}
var _name_key := ""
var _root: VBoxContainer
var _notice := ""
var _synergy_overlay: Control
var _sheet: Control             # a player's profile, open over the list
var _undo := {}            # the side before the last Auto-pick, for Undo
var _view := "mine"        # "mine" or "opp": the oval shows them, read-only
var _line_cache := {}      # the other clubs' lines, built once a visit
var _week_overlay: Control      # a phone: the week, open over the side
var _wide := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null or GameState.my_list.is_empty():
		Router.replace("main")
		return
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
		if is_inside_tree() and not UiKit.keyboard_resize(self):
			_build())
	_build()


func _build() -> void:
	# A move or a resize rebuilds the page: keep your place in the list.
	var places := UiKit.scroll_places(_root)
	UiKit.clear(_root)
	_wide = ScreenLayout.wide_view(UiKit.view_width(self), UiKit.view_height(self), 900.0)
	# Auto-pick is an action, never a mode: choose a strategy and it sets the
	# side; your moves after that stay yours (director, 2026-10-07). It is
	# the top bar's right control (audit §8 Phase 1.4): the board comes first.
	var pick := MenuButton.new()
	pick.name = "AutoPick"
	pick.text = "Auto-pick"
	pick.flat = false
	UiKit.style_button(pick, UiKit.BODY)
	pick.custom_minimum_size = Vector2(0, 44)
	var menu := pick.get_popup()
	menu.add_theme_font_override("font", UiKit.FONT)
	menu.add_theme_font_size_override("font_size", UiKit.NAME)
	var strategies := [["best", "Best side"], ["rest", "Rest tired players"], ["youth", "Blood the youth"],
			["mine", "My Selected Best 23"]]
	for i in range(strategies.size()):
		menu.add_item(str(strategies[i][1]), i)
	# One ruck or two only changes who Auto-pick names on the bench, so it sits
	# in this menu, ticked when on.
	menu.add_separator()
	menu.add_check_item("Dual ruck", 100)
	menu.set_item_checked(menu.get_item_index(100), GameState.dual_ruck())
	menu.id_pressed.connect(func(idx: int):
		if idx == 100:
			var on := not GameState.dual_ruck()
			GameState.set_dual_ruck(on)
			_notice = "Dual ruck on: Auto-pick names a second ruck on the bench." if on else "One ruck: Auto-pick fills the bench with the best of the rest."
			_build()
			return
		_apply_strategy(str(strategies[idx][0])))
	var bar := UiKit.top_bar("Team selection", true, pick)
	_root.add_child(bar)
	var auto := GameState.my_selection().is_empty()
	# A side named before the wings existed: split its midfield once.
	if not auto and not GameState.my_selection().has("WING"):
		GameState.set_selection(GameState.current_side())
	if _wide:
		var cols := UiKit.hbox(14)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.add_child(cols)
		cols.add_child(_scroller(_side_page(auto), "SelectionScroll"))
		# The week keeps a readable measure: it does not stretch with the window.
		var right := _scroller(_week_page(), "WeekScroll")
		right.size_flags_horizontal = Control.SIZE_FILL
		right.custom_minimum_size.x = clampf(UiKit.view_width(self) * 0.4, WEEK_W_MIN, WEEK_W_MAX)
		cols.add_child(right)
	else:
		_root.add_child(_scroller(_side_page(auto), "SelectionScroll"))
	UiKit.restore_places(_root, places)


## A page fills the space and scrolls only if something abnormal (a very long
## week) outgrows it; a normal side and week never show a scroll bar.
func _scroller(page: Control, node_name: String) -> ScrollContainer:
	var sc := UiKit.scroll(page)
	sc.name = node_name
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sc


## The side: the oval you can look at theirs on, your 18 and the bench, and
## the players not picked, with what acts on the side beside the interchange.
func _side_page(auto: bool) -> Control:
	var page := UiKit.vbox(8)
	page.name = "SidePage"
	var nxt := GameState.my_next_opponent()
	if not nxt.is_empty():
		# Look at them on the same oval (director, 2026-10-07).
		var opp_name := GameDB.club_short(str(nxt["code"]))
		page.add_child(UiKit.segmented("OvalView", [["mine", "Your team"], ["opp", opp_name]], _view, func(k):
			_view = k
			_build()))
	var builder := TeamBuilder.new()
	builder.name = "TeamBuilder"
	builder.stacked = true
	builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builder.start_note = _notice
	var opp_code := str(nxt.get("code", ""))
	if _view == "opp" and opp_code != "":
		var proj := _para("%s as they would take the field this week (projected: they name their side on match day). They kick the other way." % GameDB.club_name(opp_code), 13, UiKit.MUTED)
		proj.name = "OppProjected"
		page.add_child(proj)
		page.add_child(builder)
		var their: Dictionary = GameState.opponent_side(opp_code)
		builder.setup(their["side"], _wide, their["list"], true)
		builder.inspect.connect(_open_opponent.bind(their["list"]))
	else:
		var actions := HBoxContainer.new()
		actions.name = "SideActions"
		actions.add_theme_constant_override("separation", 8)
		_fill_actions(actions)
		builder.interchange_actions = actions
		builder.hint_extra = "Picked for you each week until you move someone." if auto else ""
		if not _wide and not nxt.is_empty():
			# A phone: the week is one tap away, in the club's ink, under the bench.
			var row := UiKit.text_action("This week %s %s ›" % ["v" if str(nxt["venue"]) == "home" else "at",
					GameDB.club_name(str(nxt["code"]))], UiKit.NAME)
			row.name = "WeekRow"
			row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			row.add_theme_color_override("font_color", UiKit.club_name_colour(UiKit.club_ink(GameState.my_club)))
			row.pressed.connect(_open_week)
			builder.after_bench = row
		page.add_child(builder)
		builder.setup(GameState.current_side(), _wide)
	builder.inspect.connect(_open_profile)
	builder.changed.connect(func(note: String):
		_notice = note
		builder.start_note = note
		_undo = {}
		var hint: Label = builder.find_child("BuilderHint", true, false)
		if hint != null:
			hint.text = note
			hint.add_theme_color_override("font_color", UiKit.GOOD)
		_refresh_facts())
	return page


## A phone: the week opens as a sheet over the side. Synergies and the report
## open over it and give it back on Close.
func _open_week() -> void:
	_close_week()
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_week_overlay = box["overlay"]
	_week_overlay.name = "WeekSheet"
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 10)
	_fill_week(v)
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.name = "WeekClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(_close_week)
	box["footer"].add_child(close)


func _close_week() -> void:
	if _week_overlay != null and is_instance_valid(_week_overlay):
		_week_overlay.queue_free()
	_week_overlay = null


## Save as my Best 23 and Undo, beside the interchange they act on.
func _fill_actions(actions: HBoxContainer) -> void:
	var save := UiKit.text_action("Save as my Best 23", UiKit.SECONDARY)
	save.name = "SaveBest23"
	save.pressed.connect(func():
		GameState.set_best23(GameState.current_side())
		_notice = "Saved as your Best 23. Choose it any week from Auto-pick."
		_build())
	actions.add_child(save)
	if not _undo.is_empty():
		var undo := UiKit.text_action("Undo", UiKit.SECONDARY)
		undo.name = "UndoPick"
		undo.pressed.connect(func():
			GameState.set_selection(_undo)
			_undo = {}
			_notice = "Back to your side before the auto-pick."
			_build())
		actions.add_child(undo)


## After a move: the week and the actions beside the interchange, without
## rebuilding the builder (or losing your place in it).
func _refresh_facts() -> void:
	var v: VBoxContainer = _root.find_child("WeekPage", true, false)
	if v != null:
		UiKit.clear(v)
		_fill_week(v)
	var actions: HBoxContainer = _root.find_child("SideActions", true, false)
	if actions != null:
		UiKit.clear(actions)
		_fill_actions(actions)


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


## This week: what the choice rests on, from the side as arranged now.
func _week_page() -> Control:
	var v := UiKit.vbox(10)
	v.name = "WeekPage"
	_fill_week(v)
	return v


## Line against line (your half moves with your selection), your lines, the
## synergies your side has, your own news, their key forwards. Facts, never a
## verdict. How they play is in the assistant's report.
func _fill_week(v: VBoxContainer) -> void:
	var nxt := GameState.my_next_opponent()
	if nxt.is_empty():
		v.add_child(_strength_line())
	else:
		var code := str(nxt["code"])
		var heading := UiKit.hbox(6)
		heading.name = "WeekHeading"
		heading.add_child(UiKit.line("This week %s" % ["v" if str(nxt["venue"]) == "home" else "at"], UiKit.BODY, UiKit.TEXT, true))
		heading.add_child(_side_name(code, UiKit.BODY, 20.0))
		v.add_child(heading)
		# What your assistant has seen of them - said there, and only there.
		var report := UiKit.text_action("Assistant's report ›", UiKit.SECONDARY)
		report.name = "AssistantReport"
		report.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		report.pressed.connect(_show_report.bind(code))
		v.add_child(report)
		var lines := UiKit.vbox(3)
		lines.name = "HeadToHead"
		v.add_child(lines)
		for row in GameState.my_head_to_head(code):
			var l := _para(str(row["text"]), 14, UiKit.TEXT)
			l.name = "H2H_" + str(row["key"])
			lines.add_child(l)
	v.add_child(_synergy_view())
	var own := GameState.my_week_notes()
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
	# The team sheet: who is in and out since your last match, and why.
	var changes := GameState.week_changes_text()
	if changes != "":
		var ch := _para(changes, 14, UiKit.TEXT)
		ch.name = "TeamChanges"
		v.add_child(ch)
	if not nxt.is_empty():
		# Their key forwards, as facts. Who goes to each is set before the
		# first ball-up, not here.
		var mus := GameState.week_matchups(str(nxt["code"]))
		if not mus.is_empty():
			var mv := UiKit.vbox(2)
			mv.name = "KeyMatchups"
			v.add_child(mv)
			var kf := UiKit.hbox(6)
			kf.add_child(UiKit.club_marker(str(nxt["code"]), 18.0))
			kf.add_child(UiKit.line("Their key forwards", UiKit.BODY, _side_ink(str(nxt["code"])), true))
			mv.add_child(kf)
			for m in mus:
				var f: Dictionary = m["fwd"]
				var fl := _para("%s. %s" % [GameDB.player_display_name(f), Matchups.describe(f)], 14, UiKit.TEXT)
				fl.name = "KeyForward_" + str(f["id"])
				mv.add_child(fl)
	var later := _para("Match-ups, game plan and tags are set before the first ball-up.", UiKit.SMALL, UiKit.MUTED)
	later.name = "SetLater"
	v.add_child(later)


## The line synergies your 18 switch on - what the side is good at - any
## one it is a single player short of (a fact, never a suggested swap: the
## choice is yours), and the full rules one tap away, under the line they explain.
func _synergy_view() -> Control:
	var h := UiKit.vbox(2)
	h.name = "Synergies"
	var on: PackedStringArray = []
	for r in Traits.progress(GameState.my_squad().ground):
		if bool(r["active"]):
			on.append(Traits.with_effect(str(r["key"])))
	var l := _para("Your side has: " + ", ".join(on) + "." if not on.is_empty()
			else "No line synergies in this side.", 13, UiKit.GOOD if not on.is_empty() else UiKit.MUTED)
	l.name = "SynergyLine"
	h.add_child(l)
	var short := Traits.short_text(GameState.my_squad().ground)
	if short != "":
		var s := _para(short, 13, UiKit.MUTED)
		s.name = "SynergyShort"
		h.add_child(s)
	var rules := UiKit.btn("Synergies", 14)
	rules.name = "SynergyRules"
	rules.custom_minimum_size = Vector2(104, 44)
	rules.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
		_close_week()
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


## Android Back closes a profile or the synergy guide, then the week sheet
## (a phone), then leaves.
func handle_back() -> bool:
	if _sheet != null and is_instance_valid(_sheet):
		_close_profile()
		return true
	if _synergy_overlay != null and is_instance_valid(_synergy_overlay):
		_close_synergies()
		return true
	if _week_overlay != null and is_instance_valid(_week_overlay):
		_close_week()
		return true
	return false


## The club's readable ink on the dark page (4.5:1 or better, UiKit.club_ink):
## the heading text must always read, and the guernsey beside it carries
## whose side it is (director, 2026-10-14).
func _side_ink(code: String) -> Color:
	return UiKit.club_name_colour(UiKit.club_ink(code))


func _side_name(code: String, fs: int, marker := 18.0) -> Control:
	var h := UiKit.hbox(6)
	h.add_child(UiKit.club_marker(code, marker))
	h.add_child(UiKit.line(GameDB.club_name(code), fs, _side_ink(code), true))
	return h


## What you have promised: one line for each run you have given a player,
## said as a fact (Backing). Not part of the team sheet's outs: a promise to a
## player who is out still stands, and the line says it waits.
func _backing_lines(v: VBoxContainer) -> void:
	for f in GameState.backing_notes():
		var l := _para(str(f["text"]), 13, UiKit.TEXT)
		l.name = "Backing_" + str(f["player_id"])
		v.add_child(l)


## Your lines against the league, in words, when there is no opponent to
## set them against (a bye, the season over).
func _strength_line() -> Control:
	var l := _para(GameState.my_line_standing_text(), 14, UiKit.TEXT)
	l.name = "LineStanding"
	return l


func _para(text: String, size: int, colour: Color) -> Control:
	var l := NameInk.label(text, _names(), size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Your players and this week's opponent's, by name, so a name in a sentence
## wears his club's colour (NameInk). Built from the lists, never from the text.
func _names() -> Dictionary:
	var nxt := GameState.my_next_opponent()
	var opp := str(nxt.get("code", ""))
	var key := "%s|%s|%d|%s" % [GameState.my_club, opp, GameState.my_list.size(), str(GameState.show_real_names)]
	if key != _name_key:
		_name_key = key
		var codes := [GameState.my_club]
		if opp != "" and opp != GameState.my_club:
			codes.append(opp)
		if GameState.season != null and GameState.season.lists.has(GameState.my_club):
			_name_index = NameInk.from_lists(GameState.season.lists, codes)
		else:
			_name_index = NameInk.from_squads([GameState.my_list], [GameState.my_club])
	return _name_index
