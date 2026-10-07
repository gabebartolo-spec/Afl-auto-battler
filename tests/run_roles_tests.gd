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
	await _team_changes_tests()
	await _backing_ui_tests()
	print("Roles + selection tests: %d checks, %d failures" % [_checks, _failures.size()])
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


func _selection_tests() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(420, 860)
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
	var mid_line: Label = ui.find_child("H2H_midfield", true, false)
	_check(mid_line != null and mid_line.text.begins_with("Midfield: yours "), "Midfield sets yours against theirs")
	# Their key forwards, and who you put on them.
	var km: Node = ui.find_child("KeyMatchups", true, false)
	_check(km != null and km.find_child("MatchupLine", true, false) != null
			and str(km.find_child("MatchupLine", true, false).text).contains(" is on "),
			"Selection names their key forwards and who is on them")
	var chm: Button = km.find_child("ChangeMatchup", true, false) if km != null else null
	if chm != null:
		chm.emit_signal("pressed")
		await _settle()
		var mc: Node = ui.find_child("MatchupChooser", true, false)
		var defs_b := mc.find_children("Defender_*", "Button", true, false) if mc != null else []
		_check(defs_b.size() >= 2, "Your defenders are offered, each described (%d)" % defs_b.size())
		if defs_b.size() >= 2:
			var last: Button = defs_b[defs_b.size() - 1]
			var want := str(last.name).trim_prefix("Defender_")
			last.emit_signal("pressed")
			await _settle()
			_check(_state.my_matchups.values().has(want), "Your choice is kept for the match")
			var rows: Array = _state.week_matchups(str(_state.my_next_opponent()["code"]))
			var shown := false
			for r in rows:
				if str(r["def"]["id"]) == want:
					shown = true
			_check(shown, "The match-up line follows your choice")
		_state.my_matchups = {}
	# The game plan you take in is on show, and changed here.
	var plan_line: Label = ui.find_child("PlanLine", true, false)
	var plan_before: String = plan_line.text if plan_line != null else ""
	_check(plan_line != null and plan_line.text.begins_with("Game plan: ") and plan_line.text.length() > 11,
			"The game plan you take in is on show (%s)" % (plan_line.text if plan_line else "-"))
	var change: Button = ui.find_child("ChangePlan", true, false)
	_check(change != null and change.size.y >= 44, "The plan can be changed from selection")
	if change != null:
		change.emit_signal("pressed")
		await _settle()
		var chooser: Node = ui.find_child("PlanChooser", true, false)
		var contest: Button = chooser.find_child("ClubPlan_contest", true, false) if chooser != null else null
		_check(contest != null, "The chooser offers the plans")
		if contest != null:
			contest.emit_signal("pressed")
			await _settle()
			_check(_state.club_plan == "contest", "Picking a plan sets the standing plan")
			var note: Label = chooser.find_child("PlanNote", true, false)
			_check(note != null and note.text.contains("clearances"), "The plan says what it does (%s)" % (note.text if note else "-"))
			plan_line = ui.find_child("PlanLine", true, false)
			_check(plan_line != null and plan_line.text != plan_before and plan_line.text == "Game plan: " + contest.text,
					"The plan line follows the pick")
		_check(ui.call("handle_back") == true, "Back closes the plan chooser")
		await _settle()
		_state.set_club_plan("balanced")
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
	_check(ui.find_child("SelectionWeek", true, false) != null, "Selection shows this week's opponent")
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
				var cl: Label = row2.find_child("Carriers", true, false) if row2 != null else null
				if cl == null or not cl.text.contains("in your side:"):
					carriers_ok = false
				else:
					for c in Traits.carriers(str(key), _state.my_squad().ground):
						for p in c[1]:
							if not cl.text.contains(str(root.get_node("GameDB").player_display_name(p))):
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
		var week_text := _screen_text(ui.find_child("SelectionWeek", true, false))
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
		_check(n == 23 and str(ui.find_child("BuilderNote", true, false).text) != "",
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
	await _ladder_tests()


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
	sc.scroll_vertical = 600
	await _settle()
	var at: int = sc.scroll_vertical
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


## The ladder first, then the Coleman race one goalkicker to a row, all on
## a phone screen without scrolling.
func _ladder_tests() -> void:
	for i in range(3):
		_state.advance()
	for sz in [Vector2i(420, 860), Vector2i(360, 740)]:
		root.size = sz
		var lad: Control = load("res://scenes/LadderScene.tscn").instantiate()
		root.add_child(lad)
		await _settle()
		var box: Node = lad.find_child("ColemanLeaders", true, false)
		var rows := lad.find_children("Coleman_*", "HBoxContainer", true, false)
		var leaders: Array = _state.coleman_leaders(5)
		_check(box != null and rows.size() == leaders.size(), "The Coleman race has a row per leader (%d)" % rows.size())
		var view := Rect2(Vector2.ZERO, Vector2(sz)).grow(1)
		var fits := true
		for r in rows:
			if not view.encloses(r.get_global_rect()):
				fits = false
		_check(fits, "The Coleman race fits under the ladder without scrolling (%dx%d)" % [sz.x, sz.y])
		if not rows.is_empty():
			var words := ""
			for l in rows[0].find_children("*", "Label", true, false):
				words += str(l.text) + "|"
			_check(words.contains(str(int(leaders[0]["goals"]))), "A row shows his goals (%s)" % words)
		lad.queue_free()
		await _settle()
	root.size = Vector2i(420, 860)


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
	var line: Label = ui.find_child("TeamChanges", true, false)
	var name: String = db.player_display_name(hurt)
	_check(line != null and line.text.contains("Outs: ") and line.text.contains(name)
			and line.text.contains("for " + name), "Selection reads the team sheet (%s)" % (line.text if line else "-"))
	var said := 0
	for l in ui.find_children("*", "Label", true, false):
		if str(l.text).contains(name) and str(l.text).contains("injur"):
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
	var ui := await _open()
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
			var line: Label = ui.find_child("Backing_" + kid_id, true, false)
			_check(line != null and line.text == "You promised %s a run: game one of three." % db.player_display_name(kid)
					and digits.search(line.text) == null, "Selection reminds you of the run, in words (%s)" % (line.text if line else "-"))
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


func _open() -> Control:
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
