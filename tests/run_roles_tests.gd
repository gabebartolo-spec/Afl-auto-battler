extends SceneTree
const Tap := preload("res://tests/tap.gd")
## godot --headless --path . --script tests/run_roles_tests.gd
## Roles (tests/test_roles.gd), then the Selection screen on a phone: the
## wings as their own group, a football identity on every row, fit notes
## where they matter, a Wing move, and old sides split into wings.

var _state: Node
var _checks := 0
var _failures: Array[String] = []

## Every season in this suite starts from a fixed seed (C15), never the clock.
const SUITE_SEED := 2027


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = SUITE_SEED
	var script = load("res://tests/test_roles.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_roles.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks += suite.checks
	_failures.append_array(suite.failures)
	await _selection_tests()
	await _selection_pages_tests()
	await _skip_match_tests()
	await _week_ink_tests()
	await _team_changes_tests()
	await _backing_ui_tests()
	await _captaincy_ui_tests()
	await _culture_ui_tests()
	await _captain_card_ui_tests()
	print("Roles + selection tests: %d checks, %d failures" % [_checks, _failures.size()])
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


func _selection_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	# A PC window: the side and the week are both in view (a phone's two pages
	# are tested in run_selection_pages_tests.gd).
	root.size = Vector2i(1280, 720)
	var ui := await _open()
	var text := _screen_text(ui)
	# The side on the field: 18 spots in their lines, five on the interchange,
	# everyone else in the grid (director's PC playtest, 2026-10-07).
	var spots := ui.find_children("Spot_*", "Button", true, false)
	var bench_spots := ui.find_children("BenchSpot_*", "Button", true, false)
	_check(spots.size() == 18 and bench_spots.size() == 5, "The side is on the field: 18 spots and a five-man interchange (%d, %d)" % [spots.size(), bench_spots.size()])
	_check(ui.find_child("Spot_C", true, false) != null and ui.find_child("Spot_WL", true, false) != null
			and ui.find_child("Spot_RUCK", true, false) != null and ui.find_child("Spot_FF", true, false) != null,
			"The midfield reads as centre square and wings, with ruck and full forward placed")
	var grid: Node = ui.find_child("NotSelected", true, false)
	_check(grid != null and grid.get_child_count() == _state.my_list.size() - 23,
			"Everyone not in the 23 is in the grid beside the field")
	_check(ui.find_child("MySelection", true, false) == null and ui.find_child("AutoPick", true, false) is MenuButton,
			"One team viewer: no My selection mode, Auto-pick is a dropdown action")
	# This week, line against line: both sides in the same words, no numbers.
	var h2h: Node = ui.find_child("HeadToHead", true, false)
	var digits := RegEx.new()
	digits.compile("\\d")
	var h2h_lines: Array = h2h.get_children() if h2h != null else []
	var h2h_ok := h2h_lines.size() == 4
	for l in h2h_lines:
		if digits.search(str(l.text)) != null or not (str(l.text).contains("yours") or str(l.text).contains(" v ")):
			h2h_ok = false
	_check(h2h_ok, "The matchup reads line against line, in words (%s)" %
			" | ".join(h2h_lines.map(func(l): return str(l.text))))
	var mid_line: Control = ui.find_child("H2H_midfield", true, false)
	_check(mid_line != null and _plain(mid_line).begins_with("Midfield: yours "), "Midfield sets yours against theirs")
	# Their key forwards are facts here; who goes to them and the game plan are
	# asked only in the pre-bounce menu (director, 2026-10-13).
	var km: Node = ui.find_child("KeyMatchups", true, false)
	_check(km != null and not km.find_children("KeyForward_*", "Control", true, false).is_empty(),
			"Selection names their key forwards")
	_check(ui.find_child("ChangeMatchup", true, false) == null and ui.find_child("ChangePlan", true, false) == null
			and ui.find_child("PlanLine", true, false) == null and km != null
			and not str(_screen_text(km)).contains(" is on "),
			"Selection no longer asks for the match-ups or the game plan")
	var later: Label = ui.find_child("SetLater", true, false)
	_check(later != null and later.text == "Match-ups, game plan and tags are set before the first ball-up.",
			"One quiet line says where those calls are made")
	var rows := ui.find_children("RoleLabel", "Label", true, false)
	var field: Node = ui.find_child("BuilderField", true, false)
	var formation_players := field.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("id") and str(b.get_meta("id")) != "") if field != null else []
	_check(formation_players.size() == 23, "Every picked player appears on the field or the interchange (%d)" % formation_players.size())
	var rx := RegEx.new()
	rx.compile("%")
	var leak := false
	for l in rows + ui.find_children("Fit", "Label", true, false):
		if rx.search(str(l.text)) != null:
			leak = true
	_check(not leak, "No percentages on the rows")
	_check(ui.find_child("WeekPage", true, false) != null and ui.find_child("HeadToHead", true, false) != null, "Selection shows this week's opponent")
	# The synergy rules are one tap away, in full, without progress counts.
	var rules_btn: Button = ui.find_child("SynergyRules", true, false)
	_check(rules_btn != null and rules_btn.size.y >= 44, "A Synergies button opens the rules")
	# The nearest synergy the side doesn't have, as a fact (director: "Build it").
	var short_l: Label = ui.find_child("SynergyShort", true, false)
	var short_want := Traits.short_text(_state.my_squad().ground)
	_check((short_l == null and short_want == "") or (short_l != null and short_l.text == short_want),
			"Selection says the nearest synergy and what it's short (%s)" % short_want)
	var lock := func(n: int) -> Array:
		var out := []
		for i in range(n):
			out.append({"id": "lk%d" % i, "role": "MID", "attr": {"pressure": 70, "discipline": 50}})
		return out
	_check(Traits.short_text(lock.call(2)) == "Lockdown unit: 1 lockdown player short.",
			"One traited player missing says which synergy and what it's short: %s" % Traits.short_text(lock.call(2)))
	_check(Traits.short_text(lock.call(3)) == "", "A synergy that's on isn't short")
	_check(Traits.short_text(lock.call(1)) == "" and Traits.short_text([]) == "",
			"Two or more short says nothing")
	var guide_copy := ""
	for t in load("res://scripts/ui/StatGuide.gd").TOPICS:
		if str(t[0]) == "Traits and synergies":
			guide_copy = str(t[1])
	_check(guide_copy.contains("a single player short") and guide_copy.contains(Traits.short_text(lock.call(2)).trim_suffix(".")),
			"The Stat Guide says what Selection shows, in the same words")
	if rules_btn != null:
		rules_btn.emit_signal("pressed")
		await _settle()
		var guide: Node = ui.find_child("SynergyGuide", true, false)
		var all_rules := guide != null
		if guide != null:
			for key in Traits.SYNERGIES:
				var row: Node = guide.find_child("Synergy_" + str(key), true, false)
				var req: Label = row.find_child("Requires", true, false) if row != null else null
				if req == null or not req.text.begins_with("Requires "):
					all_rules = false
		_check(all_rules, "Every synergy states exactly what it requires")
		var carriers_ok := guide != null
		if guide != null:
			for key in Traits.SYNERGIES:
				var row2: Node = guide.find_child("Synergy_" + str(key), true, false)
				var cl: Control = row2.find_child("Carriers", true, false) if row2 != null else null
				if cl == null or not _plain(cl).contains("in your side:"):
					carriers_ok = false
				else:
					for c in Traits.carriers(str(key), _state.my_squad().ground):
						for p in c[1]:
							if not _plain(cl).contains(str(root.get_node("GameDB").player_display_name(p))):
								carriers_ok = false
		_check(carriers_ok, "Each synergy names who in your side carries what it needs")
		var gtext := _screen_text(guide) if guide != null else ""
		var prog := RegEx.new()
		prog.compile("\\d/\\d")
		_check(prog.search(gtext) == null and not gtext.to_lower().contains("one more") and not gtext.contains("%"),
				"The rules carry no progress counts, advice or percentages")
		_check(gtext.contains("Requires 4 Contested bulls on the ground.")
				and gtext.contains("Requires 2 Aerial threats and 2 Crumbers in the forward line."),
				"Requirements read in plain words")
		_check(ui.call("handle_back") == true and not is_instance_valid(ui.get("_synergy_overlay")),
				"Back closes the synergy guide first")
		await _settle()
	# Complete synergy: one tap switches it on, says who came in, and can be
	# undone (director, 2026-10-07). Collingwood can complete its Lockdown unit.
	(ui.find_child("SynergyRules", true, false) as Button).emit_signal("pressed")
	await _settle()
	var complete: Button = ui.find_child("Complete_lockdown_unit", true, false)
	var blocked: Node = ui.find_child("CompleteWhy_engine_room", true, false)
	_check(complete != null and not complete.disabled and blocked != null,
			"The guide offers Complete where the list can, and says why where it can't")
	if complete != null:
		complete.emit_signal("pressed")
		await _settle()
		_check(_screen_text(ui).contains("Lockdown unit on:") and ui.find_child("UndoPick", true, false) != null,
				"Completing it changes the side, says who came in, and offers Undo")
		(ui.find_child("UndoPick", true, false) as Button).emit_signal("pressed")
		await _settle()
		_state.set_selection({})
		ui.queue_free()
		await _settle()
		ui = await _open()
	# The opposition on the same oval, read-only, and the assistant's report.
	var mine_side: Dictionary = _state.current_side()
	var view_opp: Button = null
	for b in ui.find_child("OvalView", true, false).get_children():
		if b is Button and str(b.name) != "OvalView_mine":
			view_opp = b
	_check(view_opp != null, "You can flip the oval to this week's opponent")
	if view_opp != null:
		view_opp.emit_signal("pressed")
		await _settle()
		_check(ui.find_child("OppProjected", true, false) != null and ui.find_child("ReadOnlyHint", true, false) != null,
				"Their side is marked projected and read-only")
		var their_card: Button = ui.find_child("Spot_C", true, false)
		their_card.emit_signal("pressed")
		await _settle()
		_check(ui.find_child("PlayerProfile", true, false) != null and _state.current_side() == mine_side,
				"Tapping their player opens his profile and changes nothing of yours")
		ui.call("handle_back")
		await _settle()
		(ui.find_child("OvalView_mine", true, false) as Button).emit_signal("pressed")
		await _settle()
		_check(ui.find_child("OppProjected", true, false) == null and _state.current_side() == mine_side,
				"Back to your team, as you left it")
	var rep_btn: Button = ui.find_child("AssistantReport", true, false)
	_check(rep_btn != null, "The assistant's report is one tap away")
	if rep_btn != null:
		_check((await Tap.tap(rep_btn)) == "", "The report button takes a tap")
		await _settle()
		var sheet_r: Node = ui.find_child("AssistantReportSheet", true, false)
		var rtext := _screen_text(sheet_r) if sheet_r != null else ""
		_check(sheet_r != null and rtext.contains("Assistant's report") and not rtext.to_lower().contains("you should")
				and not rtext.to_lower().contains("to beat them"), "The assistant's report describes them, never how to beat them")
		# Each fact once: not twice in the report, not again on the screen.
		var week_text := _screen_text(ui.find_child("WeekPage", true, false))
		var once := true
		var said := {}
		for part in _state.opponent_report(str(_state.my_next_opponent()["code"])):
			for t in part[1]:
				if said.has(str(t)) or week_text.contains(str(t)):
					once = false
				said[str(t)] = true
		_check(once, "Every fact in the report is said once, and not again under This week")
		ui.call("handle_back")
		await _settle()
	var recipe := RegEx.new()
	recipe.compile("\\d/\\d [A-Z][a-z]")
	_check(recipe.search(text) == null, "Synergies are not a recipe: no 'one more X' counts")
	_check(not text.to_lower().contains("best available") and not text.contains("best 23"),
			"Auto-pick is described as sensible, not best")
	_check(ui.find_child("SelectionHint", true, false) == null and not text.contains("could tag")
			and not text.contains("coach box"), "Selection surfaces the problem, not the answer")

	# Tap one player, then another: they swap. A real tap, the way a finger
	# (or a mouse) reaches the card.
	var side0: Dictionary = _state.current_side()
	var centre := str(side0["MID"][0])
	var wing := str(side0["WING"][0])
	var c_card: Button = ui.find_child("Spot_C", true, false)
	_check((await Tap.tap(c_card)) == "", "The centre's card takes a tap")
	await _settle()
	_check(ui.find_child("PickedBar", true, false) != null, "Picking a player says what happens next")
	var wl_card: Button = ui.find_child("Spot_WL", true, false)
	_check((await Tap.tap(wl_card)) == "", "The wing's card takes a tap")
	await _settle()
	var sel: Dictionary = _state.my_selection()
	_check(str(sel["MID"][0]) == wing and str(sel["WING"][0]) == centre,
			"Tapping the centre then a wing swaps them, and the side is yours from then on")
	_check(_screen_text(ui).contains("swap"), "The screen says what changed")
	# A grid player comes in for a field player.
	var out_card: Button = null
	for c in ui.find_child("NotSelected", true, false).get_children():
		if c is Button and load("res://scripts/sim/Ratings.gd").available(_state.list_player(str(c.get_meta("id")))):
			out_card = c
			break
	var in_id := str(out_card.get_meta("id")) if out_card != null else ""
	var ff_id := str(_state.my_selection()["FWD"][0])
	if out_card != null:
		out_card.emit_signal("pressed")
		await _settle()
		(ui.find_child("Spot_FF", true, false) as Button).emit_signal("pressed")
		await _settle()
	sel = _state.my_selection()
	_check(str(sel["FWD"][0]) == in_id and not _state.current_side()["FWD"].has(ff_id),
			"A player from the grid comes in for the full forward")
	# An injured player can't be put in the side.
	var hurt: Dictionary = {}
	for p in _state.my_list:
		if not _state.current_side()["DEF"].has(str(p["id"])) and not _state.current_side()["BENCH"].has(str(p["id"])):
			hurt = p
			break
	hurt["injury_weeks"] = 3
	ui.queue_free()
	await _settle()
	ui = await _open()
	var hurt_card: Button = _card_of(ui, str(hurt["id"]))
	var fb_before := str(_state.my_selection()["DEF"][0])
	if hurt_card != null:
		hurt_card.emit_signal("pressed")
		await _settle()
		(ui.find_child("Spot_FB", true, false) as Button).emit_signal("pressed")
		await _settle()
	_check(str(_state.my_selection()["DEF"][0]) == fb_before and _screen_text(ui).contains("can't play"),
			"An injured player can't come into the side, and the screen says why")
	hurt["injury_weeks"] = 0
	# Drag one card onto another (a PC): the same swap.
	var builder: Node = ui.find_child("TeamBuilder", true, false)
	var a_id := str(_state.my_selection()["DEF"][0])
	var b_id := str(_state.my_selection()["DEF"][1])
	builder.call("_swap", a_id, b_id, "")
	await _settle()
	_check(str(_state.my_selection()["DEF"][0]) == b_id and str(_state.my_selection()["DEF"][1]) == a_id,
			"Dropping one player on another swaps them")
	# Auto-pick strategies set the side; Undo puts yours back.
	var mine_before: Dictionary = _state.my_selection()
	ui.call("_apply_strategy", "best")
	await _settle()
	_check(_state.my_selection() != mine_before and ui.find_child("UndoPick", true, false) != null,
			"Auto-pick Best side sets the side, and offers Undo")
	(ui.find_child("UndoPick", true, false) as Button).emit_signal("pressed")
	await _settle()
	_check(_state.my_selection() == mine_before, "Undo puts your side back")
	for strat in ["rest", "youth"]:
		ui.call("_apply_strategy", strat)
		await _settle()
		var s2: Dictionary = _state.my_selection()
		var n := 0
		for k in s2:
			n += (s2[k] as Array).size()
		_check(n == 23 and str(ui.find_child("BuilderHint", true, false).text) != "",
				"Auto-pick %s fields 23 and says what it did" % strat)
	# Save your Best 23, change the side, choose it again.
	(ui.find_child("SaveBest23", true, false) as Button).emit_signal("pressed")
	await _settle()
	var saved: Dictionary = _state.best23.duplicate(true)
	ui.call("_apply_strategy", "best")
	await _settle()
	ui.call("_apply_strategy", "mine")
	await _settle()
	var back23: Dictionary = _state.my_selection()
	_check(not saved.is_empty() and back23["DEF"] == saved["DEF"] and back23["FWD"] == saved["FWD"],
			"My Selected Best 23 brings your saved side back")
	_state.set_selection({})
	ui.queue_free()
	await _settle()

	# A side saved before wings existed is split on first open.
	var old: Dictionary = _state.current_side()
	old["MID"] = (old["MID"] as Array) + (old["WING"] as Array)
	old.erase("WING")
	_state.set_selection(old)
	ui = await _open()
	var fixed: Dictionary = _state.my_selection()
	_check((fixed.get("WING", []) as Array).size() == 2 and (fixed.get("MID", []) as Array).size() == 3,
			"An old five-man midfield is split into three and two wings")
	ui.queue_free()
	await _settle()
	await _list_tests()
	await _selection_profile_tests()


## Gap between two controls' boxes across the page, 0 when they overlap in x.
func _gap_x(a: Control, b: Control) -> float:
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	return maxf(0.0, maxf(rb.position.x - ra.end.x, ra.position.x - rb.end.x))


func _gap_y(a: Control, b: Control) -> float:
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	return maxf(0.0, maxf(rb.position.y - ra.end.y, ra.position.y - rb.end.y))


## True when the scroller shows no bar and its page fits inside it.
func _no_scroll(sc: ScrollContainer) -> bool:
	if sc == null:
		return false
	var page: Control = null
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar):
			page = c
	return not sc.get_v_scroll_bar().visible and page != null and page.get_combined_minimum_size().y <= sc.size.y + 0.5


func _synergy_words() -> String:
	var on: PackedStringArray = []
	for r in Traits.progress(_state.my_squad().ground):
		if bool(r["active"]):
			on.append(Traits.with_effect(str(r["key"])))
	return "Your side has: " + ", ".join(on) + "." if not on.is_empty() else "No line synergies in this side."


## Team selection without scrolling (director, 2026-10-13): a phone has "The
## side" and "This week" a tap apart, a PC shows both; nothing scrolls for a
## normal side; every control sits beside the line it belongs to.
func _selection_pages_tests() -> void:
	var db = root.get_node("GameDB")
	for club in ["FRE", "WBD"]:
		_state.reset()
		_state.start_season(club, db.club_list(club))
		_state.set_selection({})
		var tag := "%s phone" % club
		# --- phone 390x844 ---
		root.size = Vector2i(390, 844)
		var ui := await _open(false)
		_check(ui.find_child("SelectionPage_side", true, false) == null and ui.find_child("SelectionPage_week", true, false) == null
				and ui.find_child("SidePage", true, false) != null and ui.find_child("WeekPage", true, false) == null
				and ui.find_child("WeekSheet", true, false) == null,
				"Phone: one page, no tabs; the week is not on it until the row is tapped (%s)" % tag)
		var row: Button = ui.find_child("WeekRow", true, false)
		_check(row != null and row.size.y >= 44 and row.text.begins_with("This week ") and row.text.ends_with("›"),
				"Phone: a thumb-sized This week row sits under the bench (%s)" % tag)
		var row_ink: Color = row.get_theme_color("font_color") if row != null else Color.BLACK
		var uk2 = load("res://scripts/ui/UiKit.gd")
		_check(row != null and uk2.contrast(row_ink, uk2.BG) >= 4.5, "Phone: the row is in readable club ink (%s)" % tag)
		_check(_no_scroll(ui.find_child("SelectionScroll", true, false)),
				"Phone: the page does not scroll for a 23-man side (%s)" % tag)
		_check(ui.find_child("NotSelectedScroll", true, false) != null,
				"Phone: the not-picked list scrolls inside its own area (%s)" % tag)
		_check(ui.find_children("Spot_*", "Button", true, false).size() == 18
				and ui.find_children("BenchSpot_*", "Button", true, false).size() == 5,
				"Phone: the 18 and the bench are all on the page (%s)" % tag)
		var phone_hint: Label = ui.find_child("BuilderHint", true, false)
		_check(phone_hint != null and phone_hint.text.contains("Tap a player, then another (or drag one onto another) to swap them.")
				and not phone_hint.text.contains("Click"), "Phone: the help line says Tap, not Click (%s)" % tag)
		var inter := ui.find_child("InterchangeRow", true, false)
		var save: Button = ui.find_child("SaveBest23", true, false)
		_check(inter != null and save != null and _gap_x(inter.get_child(0), save) < 48.0 and save.size.y >= 44,
				"Phone: Save as my Best 23 sits beside the interchange it saves (%s)" % tag)
		var list_h := (ui.find_child("NotSelectedScroll", true, false) as Control).size.y
		_check(list_h >= 70.0, "Phone: the not-picked list keeps at least %d px (%s)" % [int(list_h), tag])
		# A real tap swaps two players.
		var side0: Dictionary = _state.current_side()
		var centre := str(side0["MID"][0])
		var wing := str(side0["WING"][0])
		var why1: String = await Tap.tap(ui.find_child("Spot_C", true, false))
		await _settle()
		var why2: String = await Tap.tap(ui.find_child("Spot_WL", true, false))
		await _settle()
		_check(why1 == "" and why2 == "" and str(_state.my_selection()["MID"][0]) == wing
				and str(_state.my_selection()["WING"][0]) == centre,
				"Phone: two real taps swap a centre and a wing (%s, %s)" % [why1, why2])
		_check(ui.find_child("BuilderHint", true, false) != null
				and str(ui.find_child("BuilderHint", true, false).text).contains("swap"),
				"Phone: the swap is said under the interchange (%s)" % tag)
		# The week opens over the side from the row and carries the swap.
		var wk: String = await Tap.tap(ui.find_child("WeekRow", true, false))
		await _settle()
		_check(wk == "" and ui.find_child("WeekSheet", true, false) != null and ui.find_child("WeekPage", true, false) == null,
				"Phone: a real tap on the row opens the week over the side (%s %s)" % [tag, wk])
		var sl: Label = ui.find_child("SynergyLine", true, false)
		_check(sl != null and sl.text == _synergy_words(), "Phone: the synergies follow the swap (%s)" % tag)
		var rules: Button = ui.find_child("SynergyRules", true, false)
		_check(sl != null and rules != null and _gap_x(sl, rules) < 48.0 and _gap_y(sl, rules) < 24.0,
				"Phone: Synergies sits right under its own line (%s)" % tag)
		var rep: Button = ui.find_child("AssistantReport", true, false)
		var head: Control = ui.find_child("WeekHeading", true, false)
		_check(rep != null and head != null and _gap_x(head, rep) < 48.0 and _gap_y(head, rep) < 24.0,
				"Phone: the assistant's report sits right under This week (%s)" % tag)
		var why3: String = await Tap.tap(rules)
		await _settle()
		_check(why3 == "" and ui.find_child("SynergyGuide", true, false) != null and ui.find_child("WeekSheet", true, false) != null,
				"Phone: a real tap on Synergies opens the rules over the week, which stays (%s %s)" % [tag, why3])
		var back_ok: bool = ui.call("handle_back") == true
		await _settle()
		_check(back_ok and ui.find_child("SynergyGuide", true, false) == null, "Phone: Back closes the rules first (%s)" % tag)
		_check(ui.find_child("WeekSheet", true, false) != null, "Phone: the week is still open under the rules (%s)" % tag)
		# Close by a real tap, then reopen and close by Back.
		var why5: String = await Tap.tap(ui.find_child("WeekClose", true, false))
		await _settle()
		_check(why5 == "" and ui.find_child("WeekSheet", true, false) == null, "Phone: a real tap on Close shuts the week (%s %s)" % [tag, why5])
		await Tap.tap(ui.find_child("WeekRow", true, false))
		await _settle()
		_check(ui.call("handle_back") == true, "Phone: Back closes the week sheet (%s)" % tag)
		await _settle()
		_check(ui.find_child("WeekSheet", true, false) == null and ui.call("handle_back") == false,
				"Phone: the week is closed, and Back from the side leaves selection (%s)" % tag)
		ui.queue_free()
		await _settle()
		# --- PC: both in view, no toggle, no scroll ---
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			var ptag := "%s %dx%d" % [club, size.x, size.y]
			root.size = size
			_state.set_selection({})
			ui = await _open(false)
			_check(ui.find_child("SidePage", true, false) != null and ui.find_child("WeekPage", true, false) != null
					and ui.find_child("SelectionPage_side", true, false) == null,
					"PC: the side and the week are both in view, no toggle (%s)" % ptag)
			_check(_no_scroll(ui.find_child("SelectionScroll", true, false)) and _no_scroll(ui.find_child("WeekScroll", true, false)),
					"PC: neither column scrolls (%s)" % ptag)
			var pc_hint: Label = ui.find_child("BuilderHint", true, false)
			_check(pc_hint != null and pc_hint.text.contains("Click a player"), "PC: the help line says Click (%s)" % ptag)
			var week_w := (ui.find_child("WeekScroll", true, false) as Control).size.x
			_check(week_w >= 460.0 and week_w <= 600.5, "PC: the week keeps a readable column, %d wide (%s)" % [int(week_w), ptag])
			var sl2: Label = ui.find_child("SynergyLine", true, false)
			var rules2: Button = ui.find_child("SynergyRules", true, false)
			var rep2: Button = ui.find_child("AssistantReport", true, false)
			var head2: Control = ui.find_child("WeekHeading", true, false)
			_check(_gap_x(sl2, rules2) < 48.0 and _gap_y(sl2, rules2) < 24.0
					and _gap_x(head2, rep2) < 48.0 and _gap_y(head2, rep2) < 24.0,
					"PC: each button is beside or under its own line, under 48 px away (%s)" % ptag)
			var inter2 := ui.find_child("InterchangeRow", true, false)
			_check(_gap_x(inter2.get_child(0), ui.find_child("SaveBest23", true, false)) < 48.0,
					"PC: Save as my Best 23 is beside the interchange (%s)" % ptag)
			# A real swap on the left updates the right at once.
			var sline_before := ui.find_child("SynergyLine", true, false).get_instance_id()
			var s0: Dictionary = _state.current_side()
			var c0 := str(s0["MID"][0])
			var w0 := str(s0["WING"][0])
			var ta: String = await Tap.tap(ui.find_child("Spot_C", true, false))
			await _settle()
			var tb: String = await Tap.tap(ui.find_child("Spot_WL", true, false))
			await _settle()
			_check(ta == "" and tb == "" and str(_state.my_selection()["MID"][0]) == w0
					and str(_state.my_selection()["WING"][0]) == c0
					and ui.find_child("SynergyLine", true, false).get_instance_id() != sline_before
					and ui.find_child("SynergyLine", true, false).text == _synergy_words(),
					"PC: a real swap rebuilds the synergies and match facts at once (%s)" % ptag)
			var why4: String = await Tap.tap(ui.find_child("SynergyRules", true, false))
			await _settle()
			_check(why4 == "" and ui.find_child("SynergyGuide", true, false) != null, "PC: a real tap opens Synergies (%s)" % ptag)
			ui.call("handle_back")
			await _settle()
			_check(ui.call("handle_back") == false, "PC: Back leaves selection (%s)" % ptag)
			_check(ui.find_child("ChangeMatchup", true, false) == null and ui.find_child("ChangePlan", true, false) == null,
					"PC: no match-up or game plan control is left on selection (%s)" % ptag)
			ui.queue_free()
			await _settle()
	root.size = Vector2i(420, 860)
	_state.set_selection({})


## A coach who skips the match: the plan he last used (set in the pre-bounce
## menu) is the plan the sim plays, and the match-ups are the assistant's
## until he changes one.
func _skip_match_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("FRE", db.club_list("FRE"))
	_state.set_club_plan("contest")
	_check(_state.season.plans.get("FRE", "") == "contest" and _state.my_matchups.is_empty() and not _state.season.matchups.has("FRE"),
			"The standing plan reaches the sim and the match-ups are left to the assistant")
	var rows: Array = _state.week_matchups(str(_state.my_next_opponent()["code"]))
	_check(rows.is_empty() or not bool(rows[0]["set"]), "Until he changes one, the match-ups shown are the assistant's")
	var out: String = _state.advance()
	_check(out != "none" and _state.club_plan == "contest" and _state.season.plans.get("FRE", "") == "contest",
			"Skipping the match plays the round and keeps the plan he last used")


## My list: one line per player, a profile a tap away, Back closes it.
func _list_tests() -> void:
	var ls: Control = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	for b in ls.find_children("*", "Button", true, false):
		if b.text == "Full list":
			b.emit_signal("pressed")
	await _settle()
	var rows := ls.find_children("Row_*", "Button", true, false)
	_check(rows.size() == _state.my_list.size(), "Every listed player has a row (%d)" % rows.size())
	var ids := ls.find_children("RowIdentity", "Label", true, false)
	_check(not ids.is_empty() and not str(ids[0].text).contains("XP"), "Rows say who a player is, not his XP")
	var tall := true
	for r in rows:
		if r.is_visible_in_tree() and r.size.y < 44:
			tall = false
	_check(tall, "Each row is a thumb-sized tap")
	_check(ls.find_children("*", "GridContainer", true, false).is_empty(),
			"No attribute grids on the list itself")
	if not rows.is_empty():
		rows[0].emit_signal("pressed")
		await _settle()
		var prof: Node = ls.find_child("PlayerProfile", true, false)
		_check(prof != null and prof.find_child("ProfileAttributes", true, false) != null
				and prof.find_child("ProfileDevelopment", true, false) != null,
				"A tap opens the profile, attributes and development included")
		_check(prof != null and prof.find_child("ProfileLeadership", true, false) != null
				and prof.find_child("ProfileLeadershipNote", true, false) != null,
				"The profile shows Leadership beside his other ratings, with what it comes from")
		_check(ls.call("handle_back") == true, "Back is handled on the profile")
		await _settle()
		_check(ls.find_child("PlayerProfile", true, false) == null, "Back closes the profile")
	ls.queue_free()
	await _settle()


## Selection: a tap on a player opens his profile over the list, and closing
## it leaves the side, the mode and your place in the list as they were.
func _selection_profile_tests() -> void:
	_state.set_selection(_state.current_side())
	var before: Dictionary = _state.my_selection().duplicate(true)
	var ui := await _open()
	var sc: ScrollContainer = ui.find_child("SelectionScroll", true, false)
	var card: Button = ui.find_child("Spot_C", true, false)
	card.emit_signal("pressed")
	await _settle()
	var prof_btn: Button = ui.find_child("PickedProfile", true, false)
	_check(prof_btn != null and prof_btn.size.y >= 44, "A picked player's profile is a thumb-sized tap away")
	if prof_btn != null:
		prof_btn.emit_signal("pressed")
		await _settle()
		var prof: Node = ui.find_child("PlayerProfile", true, false)
		_check(prof != null and prof.find_child("ProfileAttributes", true, false) != null,
				"The tap opens his profile over Selection")
		_check(ui.call("handle_back") == true, "Back is handled on the profile")
		await _settle()
		_check(ui.find_child("PlayerProfile", true, false) == null and _state.my_selection() == before
				and is_instance_valid(sc), "Back returns to Selection as it was: same side")
	# On a small phone every spot sits on the field and no two overlap.
	root.size = Vector2i(360, 740)
	await _settle()
	await _settle()
	var cards := ui.find_children("Spot_*", "Button", true, false)
	var pitch: Control = ui.find_child("Pitch", true, false)
	var clash := ""
	for x in range(cards.size()):
		var rx: Rect2 = cards[x].get_global_rect()
		if pitch != null and not pitch.get_global_rect().grow(1.0).encloses(rx):
			clash = "%s off the field" % cards[x].name
		for y in range(x + 1, cards.size()):
			if rx.grow(-1.0).intersects(cards[y].get_global_rect().grow(-1.0)):
				clash = "%s on %s" % [cards[x].name, cards[y].name]
	_check(clash == "", "At 360 wide every spot is on the field, none on another (%s)" % clash)
	root.size = Vector2i(420, 860)
	ui.queue_free()
	await _settle()
	_state.set_selection({})


## The team sheet: after a match, a player who is injured is out, and the
## player who comes in is named in for him.
func _team_changes_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.autosave_enabled = false
	_state.start_season("COL", db.club_list("COL"))
	var before := await _open()
	_check(before.find_child("TeamChanges", true, false) == null, "No team changes before the first match")
	before.queue_free()
	_state.advance()
	_check(not _state.last_side.is_empty(), "Your last match's side is remembered (%d)" % _state.last_side.size())
	var hurt: Dictionary = _state.list_player(str(_state.last_side[0]))
	hurt["injury_weeks"] = 2
	var ch: Dictionary = _state.week_changes()
	var out_ok := false
	for o in ch["outs"]:
		if str(o["id"]) == str(hurt["id"]) and str(o["why"]) == "injured, 2 wks":
			out_ok = true
	_check(out_ok, "An injured player is out, with how long (%s)" % str(ch["outs"]))
	var for_ok := false
	for i in ch["ins"]:
		if str(i["for"]) == str(hurt["id"]):
			for_ok = true
	_check(for_ok, "Someone comes in for him (%s)" % str(ch["ins"]))
	var ui := await _open()
	var line: Control = ui.find_child("TeamChanges", true, false)
	var name: String = db.player_display_name(hurt)
	_check(line != null and _plain(line).contains("Outs: ") and _plain(line).contains(name)
			and _plain(line).contains("for " + name), "Selection reads the team sheet (%s)" % (_plain(line) if line else "-"))
	var said := 0
	for l in ui.find_children("*", "Control", true, false):
		if not (l is Label or l is RichTextLabel):
			continue
		if _plain(l).contains(name) and _plain(l).contains("injur"):
			said += 1
	_check(said == 1, "His injury is said once, on the team sheet (%d)" % said)
	ui.queue_free()
	var kid := {"id": "KID", "career": {"games": 0, "goals": 0, "stints": [], "through": 2026, "unknown": []}}
	_check(_state.games_note(kid) == "debut", "A player yet to play a senior game is on debut")
	await _settle()


## Selection: a player with few senior games can be backed from his profile;
## the screen then says what was promised, and the profile says so too. A
## player with a long record is not offered it.
func _backing_ui_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	var kid: Dictionary = {}
	var best: Dictionary = {}
	for p in _state.my_list:
		if str(p["role"]) != "RUCK" and (kid.is_empty() or int(p["overall"]) < int(kid["overall"])):
			kid = p
		if best.is_empty() or int(p["overall"]) > int(best["overall"]):
			best = p
	var through: int = _state.season_year - 1
	kid["career"] = {"games": 2, "goals": 0, "stints": [], "through": through, "unknown": []}
	best["career"] = {"games": 150, "goals": 0, "stints": [], "through": through, "unknown": []}
	var kid_id := str(kid["id"])
	var digits := RegEx.new()
	digits.compile("\\d")
	root.size = Vector2i(420, 860)
	var ui := await _open(false)
	var tile: Node = _card_of(ui, str(best["id"]))
	_check(tile != null, "The best player is on the field")
	if tile != null:
		await _profile_of(ui, str(best["id"]))
		var sheet: Node = ui.find_child("PlayerProfile", true, false)
		_check(sheet != null and sheet.find_child("BackRun", true, false) == null,
				"A player with a long record is not offered a run")
		ui.call("handle_back")
		await _settle()
	var row: Node = _card_of(ui, kid_id)
	_check(row != null and ui.find_child("Backing_" + kid_id, true, false) == null,
			"The kid is in the list, with nothing promised yet")
	if row != null:
		await _profile_of(ui, kid_id)
		var sheet2: Node = ui.find_child("PlayerProfile", true, false)
		var act: Node = sheet2.find_child("BackRun", true, false) if sheet2 != null else null
		var detail: Node = sheet2.find_child("Detail_BackRun", true, false) if sheet2 != null else null
		_check(act != null and str(act.text) == "Back for three games" and act.size.y >= 44,
				"A player with few senior games is offered a run, as a thumb-sized outline button")
		_check(detail != null and digits.search(str(detail.text)) == null and str(detail.text).contains("breaks"),
				"The action says what it costs, in words")
		if act != null:
			# On a small phone the action and Close both still sit on screen.
			root.size = Vector2i(360, 740)
			await _settle()
			var screen := Rect2(Vector2.ZERO, Vector2(360, 740))
			var close: Node = null
			for b in sheet2.find_children("*", "Button", true, false):
				if str(b.text) == "Close":
					close = b
			_check(close != null and screen.encloses(act.get_global_rect()) and screen.encloses(close.get_global_rect()),
					"The run and Close both sit on screen at 360 wide")
			root.size = Vector2i(420, 860)
			await _settle()
			act.emit_signal("pressed")
			await _settle()
			_check(ui.find_child("PlayerProfile", true, false) == null, "Backing him closes his profile")
			# (No direct class reference here: this runner compiles before the
			# autoloads exist, so it reads the ledger as data.)
			var ledger: Array = kid.get("backed", [])
			_check(ledger.size() == 1 and str(ledger[0]["state"]) == "active", "He is on a run")
			_check(_screen_text(ui).contains("has your word for three games"), "Selection says what changed")
			root.size = Vector2i(1280, 720)  # the week is in view beside the side
			await _settle()
			var line: Control = ui.find_child("Backing_" + kid_id, true, false)
			_check(line != null and _plain(line) == "You promised %s a run: game one of three." % db.player_display_name(kid)
					and digits.search(_plain(line)) == null, "Selection reminds you of the run, in words (%s)" % (_plain(line) if line else "-"))
			var tile2: Node = _card_of(ui.find_child("BuilderField", true, false), kid_id)
			_check(tile2 != null, "Auto-pick now names him")
			if tile2 != null:
				await _profile_of(ui, kid_id)
				var sheet3: Node = ui.find_child("PlayerProfile", true, false)
				_check(sheet3 != null and sheet3.find_child("ProfileBacking", true, false) != null
						and sheet3.find_child("BackRun", true, false) == null,
						"His profile says what you promised and offers no second run")
				ui.call("handle_back")
				await _settle()
	ui.queue_free()
	await _settle()
	# With no next opponent (the finals), a run still on is said all the same.
	_state.season.round_index = _state.season.fixture.size()
	var fin := await _open()
	_check(fin.find_child("Backing_" + kid_id, true, false) != null, "A run still on is said in the finals too")
	fin.queue_free()
	await _settle()


## A player's card on the team builder, wherever he is (field, bench, grid).
func _card_of(ui: Node, id: String) -> Node:
	if ui == null:
		return null
	var found: Node = null
	for b in ui.find_children("*", "Button", true, false):
		if b.has_meta("id") and str(b.get_meta("id")) == id and not b.is_queued_for_deletion():
			if b.is_visible_in_tree():
				return b
			found = b
	return found


## A player's profile on the team builder: pick his card, then Profile.
func _profile_of(ui: Node, id: String) -> void:
	var card: Node = _card_of(ui, id)
	if card == null:
		return
	card.emit_signal("pressed")
	await _settle()
	var prof: Node = ui.find_child("PickedProfile", true, false)
	if prof != null:
		prof.emit_signal("pressed")
		await _settle()


## Captaincy over My list, by real taps: the way in, the rules and costs on the
## page, a pick from the list, Confirm, and the record afterwards.
func _captaincy_ui_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	var ls: Control = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	var open_btn: Button = ls.find_child("CaptaincyOpen", true, false)
	_check(open_btn != null and open_btn.size.y >= 44, "My list has a thumb-sized way into Captaincy")
	if open_btn == null:
		ls.queue_free()
		return
	var why: String = await Tap.tap(open_btn)
	await _settle()
	_check(why == "", "A tap opens Captaincy (%s)" % why)
	var sheet: Node = ls.find_child("CaptaincySheet", true, false)
	_check(sheet != null and not _screen_text(sheet).contains("only get one change a season")
			and sheet.find_child("CaptaincyHow", true, false) != null,
			"The rules sit behind one tap, not on the page")
	var how: Button = sheet.find_child("CaptaincyHow", true, false) if sheet != null else null
	why = await Tap.tap(how)
	await _settle()
	var rules: Node = ls.find_child("CaptaincyRules", true, false)
	_check(why == "" and rules != null and _screen_text(rules).contains("Overlooking a senior player")
			and _screen_text(rules).contains("only get one change a season"),
			"How captaincy works says what a pick can cost (%s)" % why)
	if rules != null:
		why = await Tap.tap(rules.find_child("RulesClose", true, false))
		await _settle()
	_check(sheet != null and sheet.find_child("CaptaincyConfirmWhy", true, false) != null
			and (sheet.find_child("CaptaincyConfirm", true, false) as Button).disabled,
			"Confirm waits until something changes, and says so")
	var slot: Button = sheet.find_child("CaptaincySlot_0", true, false) if sheet != null else null
	why = await Tap.tap(slot)
	await _settle()
	var picker: Node = ls.find_child("CaptaincyPicker", true, false)
	_check(why == "" and picker != null, "A tap on a spot opens the list to pick from (%s)" % why)
	var rows: Array = picker.find_children("Pick_*", "Button", true, false) if picker != null else []
	var shows_lead := picker != null and _screen_text(picker).contains("Leadership")
	_check(rows.size() == _state.my_list.size() and shows_lead, "Everyone on the list is there with his Leadership (%d rows)" % rows.size())
	var target: Button = null
	var current := Captaincy.ids(_state.captaincy_record("COL"), "captain")
	for r in rows:
		if current.is_empty() or str(r.name) != "Pick_" + str(current[0]):
			target = r
			break
	var picked := str(target.name).trim_prefix("Pick_") if target != null else ""
	why = await Tap.tap(target)
	await _settle()
	_check(why == "" and ls.find_child("CaptaincyPicker", true, false) == null, "A tap on a player names him to the spot (%s)" % why)
	var confirm: Button = ls.find_child("CaptaincyConfirm", true, false)
	_check(confirm != null and not confirm.disabled, "Confirm is ready once a pick changes something")
	why = await Tap.tap(confirm)
	await _settle()
	_check(why == "" and Captaincy.ids(_state.captaincy_record("COL"), "captain").has(picked),
			"Confirm names him captain (%s)" % why)
	# A second mid-season change is refused, and the page says why.
	_state.advance()
	_state.captaincy[ "COL" ]["changes"][str(_state.season_year)] = Captaincy.MID_SEASON_CHANGES
	ls.queue_free()
	await _settle()
	ls = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	await Tap.tap(ls.find_child("CaptaincyOpen", true, false))
	await _settle()
	await Tap.tap(ls.find_child("CaptaincySlot_0", true, false))
	await _settle()
	var other: Button = null
	for r2 in ls.find_children("Pick_*", "Button", true, false):
		if str(r2.name) != "Pick_" + picked:
			other = r2
			break
	await Tap.tap(other)
	await _settle()
	var refused: Node = ls.find_child("CaptaincyWhyNot", true, false)
	_check(refused != null and str(refused.text).contains("already taken the armband")
			and (ls.find_child("CaptaincyConfirm", true, false) as Button).disabled,
			"A second mid-season change is refused on the page, with the reason")
	ls.queue_free()
	await _settle()


## A captain's card on the hub: what each choice does sits under its button, the
## buttons are thumb-sized, and a real tap answers it.
func _captain_card_ui_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
	var cap: Dictionary = {}
	var rec: Dictionary = _state.captaincy_record("COL")
	for p in _state.my_list:
		if Captaincy.role_of(rec, str(p["id"])) == "captain":
			cap = p
	_check(not cap.is_empty(), "Collingwood has a captain for the card")
	if cap.is_empty():
		return
	_state.set_setting("seen_weekly_loop_intro", true)
	var card: Dictionary = _state.story_card("captain_group_flat", cap)
	_state.week_events = [card]
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	for i in range(60):
		await process_frame
	var tall := true
	var notes := 0
	for i in range((card["options"] as Array).size()):
		var b: Button = hub.find_child("Event_%d" % i, true, false)
		if b == null or b.size.y < 47.5:
			tall = false
		if hub.find_child("EventNote_0_%d" % i, true, false) != null or hub.find_child("EventGain_0_%d" % i, true, false) != null or hub.find_child("EventCost_0_%d" % i, true, false) != null:
			notes += 1
	_check(tall, "Every choice on a captain's card is a thumb-sized tap (48 px)")
	_check(notes == (card["options"] as Array).size(), "Every choice says what it does, under its button (%d lines)" % notes)
	var rule: Control = hub.find_child("EventNote_0_2", true, false)
	_check(rule != null and _plain(rule).contains("would listen to") and not _plain(rule).to_lower().contains("settle"),
			"The choice left to the captain says what happens now, without the rule")
	var see: Button = hub.find_child("EventRule_2", true, false)
	_check(see != null and see.size.y >= 43.5, "The rule is one tap away, thumb-high")
	var tapped: String = await Tap.tap(see)
	for i in range(6):
		await process_frame
	var sheet: Control = hub.get("_rule_overlay")
	var shown: Label = hub.find_child("RuleText", true, false)
	_check(tapped == "" and sheet != null and is_instance_valid(sheet) and shown != null and shown.text.contains("Leadership"),
			"A real tap opens the rule (%s)" % tapped)
	var close_btn: Button = hub.find_child("RuleClose", true, false)
	var closed: String = await Tap.tap(close_btn)
	for i in range(6):
		await process_frame
	_check(closed == "" and hub.find_child("RuleText", true, false) == null, "A real tap on Close shuts the rule (%s)" % closed)
	await Tap.tap(see)
	for i in range(6):
		await process_frame
	var back_ok: bool = hub.call("handle_back") == true
	for i in range(4):
		await process_frame
	_check(back_ok and hub.find_child("RuleText", true, false) == null, "Android Back closes the rule")
	var ev0: Button = hub.find_child("Event_0", true, false)
	var why: String = await Tap.tap(hub.find_child("Event_0", true, false))
	for i in range(10):
		await process_frame
	_check(why == "" and bool((_state.week_events[0] as Dictionary).get("resolved", false)), "A real tap answers the card (%s)" % why)
	hub.queue_free()
	await _settle()


## Club culture over My list, by real taps: the way in, the words, the reasons
## one tap away.
func _culture_ui_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.career_seed = SUITE_SEED
	_state.start_season("FRE", db.club_list("FRE"))
	root.size = Vector2i(420, 860)
	Culture.change(_state.relations, "FRE", "together", 6, "A run of four losses", _state.season_year, "Round 6")
	for i in range(3):
		Culture.change(_state.relations, "FRE", "together", 6, "Played finals", _state.season_year, "Round 24")
	# The way in is a real tap, the screen says the strands in words and what moves
	# each, the dated reasons are football words, Android Back closes it.
	var ls: Control = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	var open_btn: Button = ls.find_child("CultureOpen", true, false)
	_check(open_btn != null and open_btn.size.y >= 44, "My list has a thumb-sized way into Club culture")
	var culture_sheet = load("res://scripts/ui/CultureSheet.gd")
	var quiet := {"words": "Nothing stands out yet"}
	var loud := {"words": "A tight group"}
	_check(culture_sheet.entry_phrases([quiet, quiet, quiet]) == PackedStringArray(["Nothing stands out yet"]),
			"When all three strands have nothing to say, the block says so once")
	_check(culture_sheet.entry_phrases([loud, quiet, quiet]) == PackedStringArray(["A tight group"])
			and culture_sheet.entry_phrases([loud, quiet, loud]).size() == 2
			and culture_sheet.entry_phrases([loud, loud, loud]).size() == 3,
			"Otherwise the row names only the strands that stand out, never Nothing stands out yet beside them")
	_check(open_btn != null and _screen_text(open_btn).count("Nothing stands out yet") <= 1,
			"The way in never repeats Nothing stands out yet")
	_check(open_btn != null and _screen_text(open_btn).contains("A tight group"), "The way in says the strands in bold words")
	var why: String = await Tap.tap(open_btn)
	await _settle()
	var sheet: Node = ls.find_child("CultureSheet", true, false)
	_check(why == "" and sheet != null and _screen_text(sheet).contains("A tight group")
			and _screen_text(sheet).contains("Nothing stands out yet"),
			"The screen says the strands in words, and what has nothing to say (%s)" % why)
	var effect_of := func(id: String) -> String:
		var row: Node = sheet.find_child("Strand_" + id, true, false) if sheet != null else null
		var e: Label = row.find_child("StrandEffect", true, false) if row != null else null
		return e.text if e != null and e.is_visible_in_tree() else ""
	_check(effect_of.call("together") == "Players take a missed game a little better.",
			"An active band says what it does for you, in one football line (%s)" % effect_of.call("together"))
	_check(effect_of.call("standards") == "" and effect_of.call("ambition") == "",
			"A band in the middle says nothing it does not do")
	var trade: Label = sheet.find_child("CultureTradeOff", true, false) if sheet != null else null
	_check(trade != null and trade.is_visible_in_tree() and not trade.text.contains("no effect")
			and trade.text.contains("costs you") and not trade.text.contains("%"),
			"The header names what culture touches and what it costs, with no number (P-63)")
	_check(trade != null and trade.get_global_rect().position.y < sheet.find_child("Strand_standards", true, false).get_global_rect().position.y,
			"That line sits above the strands, in the header")
	_check(sheet != null and _screen_text(sheet).contains(Culture.moves_line("ambition")), "Each strand says what moves it")
	var reasons: Node = sheet.find_child("CultureReasons", true, false) if sheet != null else null
	_check(reasons != null and reasons.is_visible_in_tree() and _screen_text(reasons).contains("layed finals. Togetherness rose."),
			"Each reason is one event in football words")
	# The strand emblems: the real art with each strand's name, tinted by the club,
	# never moving the words; and the screen still stands without the files.
	# Loaded here, not named: the screen's script needs the autoloads to compile.
	var sheet_script = load("res://scripts/ui/CultureSheet.gd")
	var icon_px := float(sheet_script.ICON)
	var words_x := {}
	for st in Culture.STRANDS:
		var id := str(st[0])
		var path := "res://assets/ui/culture/%s.png" % id
		var row: Node = sheet.find_child("Strand_" + id, true, false) if sheet != null else null
		var icon: TextureRect = row.find_child("StrandIcon", true, false) if row != null else null
		var tex: Texture2D = icon.texture if icon != null else null
		_check(ResourceLoader.exists(path) and tex != null and tex.resource_path == path
				and tex.get_width() >= int(icon_px) * 2 and tex.get_width() == tex.get_height(),
				"The %s emblem is its own art, big enough for a sharp phone (%s)" % [id, tex.resource_path if tex != null else "missing"])
		var img: Image = tex.get_image() if tex != null else null
		_check(img != null and img.get_pixel(0, 0).a < 0.05 and _emblem_cover(img) > 0.12,
				"The %s emblem is a shape on a clear background, not a blank or a block" % id)
		var name_lbl: Control = _label_with(row, str(st[1]))
		_check(icon != null and icon.is_visible_in_tree() and icon.size.is_equal_approx(Vector2(icon_px, icon_px))
				and name_lbl != null and (name_lbl as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
				and absf(icon.get_global_rect().get_center().x - name_lbl.get_global_rect().get_center().x) < 1.0
				and absf(name_lbl.get_global_rect().position.y - icon.get_global_rect().end.y) < 8.0,
				"The %s emblem is drawn at its size, its name centred right under it" % id)
		var words: Control = row.find_child("StrandWords", true, false) if row != null else null
		words_x[id] = words.get_global_rect() if words != null else Rect2()
	var tint: Color = sheet_script.emblem_tint("FRE")
	_check(tint.s > 0.08 and tint.s < 0.5 and tint.v > 0.75, "Fremantle's emblems carry a light wash of purple (%s)" % tint.to_html(false))
	var dogs: Color = sheet_script.emblem_tint("WBD")
	var dees: Color = sheet_script.emblem_tint("MEL")
	_check(dogs.s > 0.08 and dogs.h > 0.5 and dogs.h < 0.72, "The Bulldogs' emblems carry their blue (%s)" % dogs.to_html(false))
	_check(dees.s > 0.08 and dees.h > 0.5 and dees.h < 0.72, "Melbourne's emblems carry the navy, not the red (%s)" % dees.to_html(false))
	for red in ["ESS", "SYD", "STK"]:
		var rt: Color = sheet_script.emblem_tint(red)
		_check(rt.s < 0.08, "%s's emblems stay plain, so none reads as a warning (%s)" % [red, rt.to_html(false)])
	var all_icons: Array = sheet.find_children("StrandIcon", "TextureRect", true, false) if sheet != null else []
	_check(all_icons.size() == 3 and (all_icons[0] as TextureRect).modulate.is_equal_approx(tint), "Each strand has one emblem, in the club's wash")
	ls.handle_back()
	await _settle()
	_check(ls.find_child("CultureSheet", true, false) == null, "Android Back closes the culture screen")
	# Without the files: no emblem, the same words in the same place.
	sheet_script.icon_dir = "res://assets/ui/no_such_folder"
	why = await Tap.tap(ls.find_child("CultureOpen", true, false))
	await _settle()
	sheet = ls.find_child("CultureSheet", true, false)
	_check(why == "" and sheet != null and sheet.find_child("StrandIcon", true, false) == null
			and _screen_text(sheet).contains("A tight group"), "Without the emblem files the screen still says the strands (%s)" % why)
	for st in Culture.STRANDS:
		var row2: Node = sheet.find_child("Strand_" + str(st[0]), true, false) if sheet != null else null
		var words2: Control = row2.find_child("StrandWords", true, false) if row2 != null else null
		var was: Rect2 = words_x[str(st[0])]
		_check(words2 != null and is_equal_approx(words2.get_global_rect().position.x, was.position.x)
				and is_equal_approx(words2.get_global_rect().size.x, was.size.x),
				"The %s emblem takes no width from the strand's words" % str(st[0]))
	sheet_script.icon_dir = "res://assets/ui/culture"
	ls.handle_back()
	await _settle()
	ls.queue_free()
	await _settle()


## The share of an emblem's pixels that are drawn.
func _emblem_cover(img: Image) -> float:
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float((img.get_width() / 2) * (img.get_height() / 2))


func _label_with(under: Node, text: String) -> Control:
	if under == null:
		return null
	for l in under.find_children("*", "Label", true, false):
		if (l as Label).text == text:
			return l
	return null


## `pc`: open it in a PC window, where the side and the week are both in view.
func _open(pc := true) -> Control:
	if pc:
		root.size = Vector2i(1280, 720)
	var ui: Control = load("res://scenes/SelectionScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	return ui


func _screen_text(node: Node) -> String:
	var out := ""
	for n in node.find_children("*", "Label", true, false):
		out += str(n.text) + "\n"
	return out


func _settle() -> void:
	for i in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## The week's headings are the club's readable ink on the dark page, for every
## club (the raw club colour was dark purple on dark purple), and the week
## says each fact once.
func _week_ink_tests() -> void:
	var db = root.get_node("GameDB")
	var uk = load("res://scripts/ui/UiKit.gd")
	var bad := []
	var codes: Array = db.clubs.keys()
	for code in codes:
		_state.reset()
		_state.start_season(str(code), db.club_list(str(code)))
		var ui := await _open()
		var opp := str(_state.my_next_opponent().get("code", ""))
		var h: Label = null
		var kf: Label = null
		for l in ui.find_children("*", "Label", true, false):
			if str(l.text) == db.club_name(opp) and h == null and ui.find_child("WeekHeading", true, false).is_ancestor_of(l):
				h = l
			if str(l.text) == "Their key forwards":
				kf = l
		_check(h != null or opp == "", "The week heading names the opponent beside its guernsey (%s)" % str(code))
		for lab in [h, kf]:
			if lab == null:
				continue
			# The club's readable ink: 4.5:1 on the dark page, for every club.
			var ratio: float = uk.contrast(lab.get_theme_color("font_color"), uk.BG)
			if ratio < 4.5:
				bad.append("%s %s %.1f" % [code, lab.text, ratio])
		if str(code) == "FRE":
			_check(ui.find_child("LineStandings", true, false) == null and ui.find_child("H2H_midfield", true, false) != null,
					"The week says line against line once, not twice")
			var long_tag := false
			for c in ui.find_children("Spot_*", "Button", true, false):
				for l in c.find_children("*", "Label", true, false):
					if str(l.text).count("/") >= 2:
						long_tag = true
			_check(not long_tag, "No oval tile lists three positions")
		ui.queue_free()
		await _settle()
	_check(bad.is_empty(), "Every club's week headings read at 4.5:1 or better on the dark page (%s)" % str(bad))
	_check(codes.size() >= 18, "All the clubs were checked (%d)" % codes.size())


## The words a line shows, whether a Label or a tinted RichTextLabel carries them.
func _plain(c: Control) -> String:
	if c.has_meta("plain"):
		return str(c.get_meta("plain"))
	if c is Label:
		return (c as Label).text
	return (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else ""
