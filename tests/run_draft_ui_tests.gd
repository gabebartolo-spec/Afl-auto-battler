extends SceneTree
## godot --headless --path . --script tests/run_draft_ui_tests.gd
## Layout/state regressions using actual Godot containers. Browser/device touch
## smoke tests are documented separately in tests/README.md.
## Seeded by design: the Draft is built with an explicit seed (12345).

const Tap := preload("res://tests/tap.gd")
const VIEWPORTS := [
	Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568),
	Vector2i(360, 800), Vector2i(430, 932), Vector2i(420, 860), Vector2i(360, 740), Vector2i(768, 1024),
	Vector2i(1024, 768), Vector2i(667, 375), Vector2i(915, 412), Vector2i(1280, 800),
]

var _state: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	# Never touch a real career save or settings file from a test run.
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_db = root.get_node("GameDB")
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	await _settle()

	var defender := {}
	for candidate in _state.draft.board("DEF", "", "", "overall", true):
		# A pure defender: a second position would count toward another need.
		if str(candidate["role"]) == "DEF" and str(candidate.get("role2", "")) in ["", "DEF"]:
			defender = candidate
			break
	ui.call("_on_pick", defender)
	_check(_state.draft.role_counts()["DEF"] == 1, "Pick updates the user's position count")
	_check(_state.draft.position_needs()["DEF"] == 5, "Pick updates position needs")
	var player_row: Control = ui.find_child("Player_*", true, false)
	var pick_button: Control = ui.find_child("Pick_*", true, false)
	_check(player_row.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Player rows pass drags to the scroll container")
	_check(pick_button.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Draft buttons allow scrolling to cancel a pending press")
	var kit = load("res://scripts/ui/UiKit.gd")
	var badge: Control = kit.role_chip("RUCK")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Position badges do not block touch scrolling")
	badge.free()
	await _test_inspect(ui)
	await _test_projected_row(ui)
	ui.set("_role", "DEF")
	ui.set("_search", "Jack")
	ui.set("_sort", "value")
	ui.set("_club_filter", "ADE")
	ui.set("_available_only", false)
	ui.set("_advanced_open", true)
	ui.set("_history_club", "RIC")
	ui.call("_show_board")
	await _settle()
	var before := _snapshot(ui)

	for dimensions in VIEWPORTS:
		root.size = dimensions
		await _settle()
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		_check(root.get_visible_rect().size.is_equal_approx(Vector2(dimensions)),
				label + " uses the requested viewport size")
		_check(_snapshot(ui) == before, label + " preserves draft, filters and history")
		for tab in ["pool", "picks", "squad", "order"]:
			ui.call("_select_tab", tab)
			await _settle()
			_check_layout(ui, label + " / " + tab)
		ui.call("_select_tab", "pool")

	await _test_career_stage_filters(ui)
	await _test_style_and_trait_filters(ui)
	await _test_position_filters(ui)

	# No-results recovery resets controls as well as their backing values.
	ui.call("_clear_filters")
	await _settle()
	_check(ui.get("_search") == "", "Clear filters resets search")
	_check(ui.get("_role") == "", "Clear filters resets position")
	_check(ui.get("_available_only") == true, "Clear filters restores availability")
	var finish: Button = ui.find_child("StartSeason", true, false)
	_check(finish.disabled, "Season cannot start before a valid draft is complete")
	await _test_side_shape(ui)
	await _test_pick_keeps_scroll(ui)

	# Reopening uses the same draft; it must not replay AI turns.
	var history: Array = _state.draft.pick_history.duplicate(true)
	var roster_before: int = _state.draft.count()
	root.remove_child(ui)
	ui.queue_free()
	ui = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	_check(ui.get("_phase") == "board", "Reopening resumes the board, not club selection")
	_check(_state.draft.pick_history == history, "Reopening never makes additional picks")
	_check(_state.draft.count() == roster_before, "Reopening preserves the user's roster")
	ui.queue_free()
	await _settle()
	await _test_start_season_footer()
	await _test_intake_combine()
	await _test_search_keyboard()
	await _test_rotation()
	await _test_phone_browser_never_wide()
	await _test_stage()
	await _test_rival_why()
	print("Draft UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

## The draft's footer tells the truth about the finished list, and Start season
## does what the footer says: a list short at a position starts and says who
## fills in; a list the rules refuse stays on the draft and says why; a list
## with every position covered says it is ready. All by a real tap.
func _test_start_season_footer() -> void:
	var old_size := root.size
	root.size = Vector2i(390, 844)
	# Short at defence: cheapest players first, never a defender.
	var ui: Control = await _finished_draft(false)
	var d = _state.draft
	var footer: Label = ui.find_child("UpcomingPicks", true, false)
	var fin: Button = ui.find_child("StartSeason", true, false)
	var short_def := int((d.position_status()["DEF"] as Dictionary)["short"])
	_check(d.is_finished() and d.is_valid() and short_def > 0,
			"Setup: a full list within the cap with no defenders (short %d)" % short_def)
	_check(footer.text.begins_with("Short %d defenders" % short_def),
			"A list short at defence says so: " + footer.text.replace("
", " / "))
	_check(not footer.text.contains("ready"), "...and does not say the list is ready")
	_check(not fin.disabled, "The rules let a full list start short, so Start season is live")
	var why: String = await Tap.tap(fin)
	_check(why == "" and _state.season != null and _state.my_club == "COL",
			"A finger's tap on Start season starts the season (%s)" % why)
	ui.queue_free()
	_state.reset()
	await _settle()

	# A list the rules refuse: over the cap. Start season is off, the footer says why.
	ui = await _finished_draft(false)
	d = _state.draft
	d.budget = d.spent() - 1000
	ui.call("_refresh")
	await _settle()
	footer = ui.find_child("UpcomingPicks", true, false)
	fin = ui.find_child("StartSeason", true, false)
	_check(not d.is_valid() and fin.disabled, "Setup: over the cap, Start season is off")
	_check(footer.text.contains("over the salary cap") and not footer.text.contains("ready"),
			"An invalid list says why: " + footer.text.replace("
", " / "))
	await Tap.tap(fin)
	await _settle()
	_check(_state.season == null and ui.is_inside_tree() and ui.get("_phase") == "board",
			"A tap on Start season with an invalid list leaves you on the draft")
	# ...and the coach can fix it here: My list offers Release, a real tap
	# frees the player and reopens the draft for another pick.
	_check(footer.text.contains("Release a player") and d.finished_list_refused(),
			"The footer says how to fix it: " + footer.text.replace("
", " / "))
	ui.call("_select_tab", "squad")
	await _settle()
	var rel: Button = null
	for n in ui.find_children("Release_*", "Button", true, false):
		rel = n
		break
	_check(rel != null, "A refused list offers Release on My list")
	var count_before: int = d.count()
	var rel_why: String = await Tap.tap(rel)
	await _settle()
	_check(rel_why == "" and d.count() == count_before - 1 and not d.is_finished() and d.is_user_turn() and d.spent() <= d.budget,
			"A tap on Release returns him to the pool and reopens your pick, under the cap (%s)" % rel_why)
	_check(fin.disabled and not ui.find_child("UpcomingPicks", true, false).text.contains("over the salary cap"),
			"Start season stays off until the list is whole, and the cap reason is gone")
	d.budget += 1000
	_check(d.invalid_reason() == "You have %d of %d players." % [d.target_size - 1, d.target_size],
			"A short list says how many players it has: " + d.invalid_reason())
	ui.queue_free()
	_state.reset()
	await _settle()

	# Every position covered: ready, and it starts.
	ui = await _finished_draft(true)
	d = _state.draft
	footer = ui.find_child("UpcomingPicks", true, false)
	fin = ui.find_child("StartSeason", true, false)
	_check(d.short_positions() == "" and d.is_valid(), "Setup: a list with every position covered")
	_check(footer.text.begins_with("Your list is ready."), "A covered list says it is ready: " + footer.text.replace("
", " / "))
	why = await Tap.tap(fin)
	_check(why == "" and _state.season != null, "A finger's tap on Start season starts the season (%s)" % why)
	ui.queue_free()
	_state.reset()
	await _settle()
	var draft_class = load("res://scripts/sim/Draft.gd")
	_check(draft_class.role_noun("DEF", 1) == "defender" and draft_class.role_noun("FWD", 2) == "forwards",
			"Positions are named in the singular for one and the plural for more")
	root.size = old_size


## A phone's keyboard shrinks the window's height while "Search players" has
## focus. The draft must not rebuild, flip to its short layout, or lose the
## field: that loop (rebuild frees the field, keyboard hides, window grows,
## rebuild again) shifted the screen for a tester. Tap elsewhere = focus gone.
func _test_search_keyboard() -> void:
	var old_size := root.size
	root.size = Vector2i(390, 844)
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	await _settle()
	ui.call("_select_tab", "pool")
	await _settle()
	var field: LineEdit = ui.find_child("PlayerSearch", true, false)
	_check(field != null and field.is_visible_in_tree(), "Search players is on the pool")
	if field == null:
		return
	await Tap.tap(field)
	_check(field.has_focus(), "A real tap on Search players gives it focus")
	for ch in "van":
		for down in [true, false]:
			var ev := InputEventKey.new()
			ev.unicode = ch.unicode_at(0)
			ev.keycode = ch.unicode_at(0) - 32
			ev.pressed = down
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
			await process_frame
	await _settle()
	# The list follows the typing after a short pause (the search timer).
	await create_timer(0.4).timeout
	await _settle()
	_check(field.text == "van", "Typing van fills the field (%s)" % field.text)
	var all_n: int = _state.draft.board("", "", "", "overall", true).size()
	var want: int = _state.draft.board("", "", "van", "overall", true).size()
	_check(want < all_n and str(ui.get("_board_info").text).contains(str(want)),
			"Typing van filters the pool (%s)" % ui.get("_board_info").text)
	var key_before: String = ui.get("_layout_key")
	var short_before: bool = ui.get("_short")
	for cycle in range(3):
		root.size = Vector2i(390, 464)
		await _settle()
		_check(ui.find_child("PlayerSearch", true, false) == field and is_instance_valid(field),
				"Keyboard up %d: the search field is the same node" % cycle)
		_check(is_instance_valid(field) and field.has_focus() and field.text == "van",
				"Keyboard up %d: focus and text kept" % cycle)
		_check(ui.get("_layout_key") == key_before and ui.get("_short") == short_before,
				"Keyboard up %d: layout mode did not flip" % cycle)
		root.size = Vector2i(390, 844)
		await _settle()
		_check(is_instance_valid(field) and ui.find_child("PlayerSearch", true, false) == field and field.has_focus(),
				"Keyboard down %d: same field, still focused" % cycle)
	# Tap elsewhere: focus leaves, and the screen then follows the window.
	field = ui.find_child("PlayerSearch", true, false)
	field.release_focus()
	await _settle()
	_check(not field.has_focus(), "Focus leaves the field")
	root.size = Vector2i(390, 464)
	await _settle()
	_check(ui.get("_short") == true, "With no field focused, a short window still gets the short layout")
	root.size = old_size
	ui.queue_free()
	await _settle()


## Turning the phone swaps width and height: the draft follows the window each
## time (wide on its side, stacked upright) and rebuilds once per turn, with a
## search field focused or not. Height alone shrinking is a keyboard, not this.
func _test_rotation() -> void:
	var old_size := root.size
	root.size = Vector2i(390, 844)
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	await _settle()
	var sizes := [Vector2i(844, 390), Vector2i(390, 844), Vector2i(844, 390), Vector2i(390, 844)]
	var last_key: String = ui.get("_layout_key")
	for i in range(sizes.size()):
		var margin_before = ui.get("_margin")
		root.size = sizes[i]
		await _settle()
		var key: String = ui.get("_layout_key")
		var landscape: bool = sizes[i].x > sizes[i].y
		_check(key != last_key and ui.get("_short") == landscape,
				"Turn %d to %s: the layout follows (%s)" % [i, "landscape" if landscape else "portrait", key])
		_check(is_instance_valid(ui.get("_search_field")) or ui.get("_phase") == "board",
				"Turn %d: the board is still built" % i)
		last_key = key
	root.size = old_size
	ui.queue_free()
	await _settle()


## A phone's browser in a wide frame (itch's 1280x720 shown on a phone, seen
## at 900x700 or 1280x720 units) must keep the phone layout, not the PC one.
func _test_phone_browser_never_wide() -> void:
	var old_size := root.size
	var layout = load("res://scripts/core/ScreenLayout.gd")
	for sz in [Vector2i(900, 700), Vector2i(1280, 720)]:
		for phone in [true, false]:
			layout.force_web_phone = phone
			root.size = sz
			_state.reset()
			_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
					_db.active_clubs(2026).duplicate(), 12345)
			var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
			root.add_child(ui)
			ui.call("_on_club_chosen", "COL")
			await _settle()
			_check(bool(ui.get("_wide")) == (not phone),
					"%dx%d %s: the draft is %s" % [sz.x, sz.y, "phone browser" if phone else "PC browser",
					"the phone layout" if phone else "the wide layout"])
			ui.queue_free()
			await _settle()
	layout.force_web_phone = false
	root.size = old_size


## A League Draft for COL played to the end, cheapest players first. With
## `cover`, a position that is still short is filled before any other.
func _finished_draft(cover: bool) -> Control:
	_state.reset()
	_state.replay_seed = 4242
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	await _settle()
	var d = _state.draft
	var guard := 0
	while not d.is_finished() and guard < 80:
		guard += 1
		var want := ""
		if cover:
			var status: Dictionary = d.position_status()
			for role in ["RUCK", "DEF", "MID", "FWD"]:
				if int((status[role] as Dictionary)["short"]) > 0:
					want = role
					break
		var board: Array = d.board(want, "", "", "overall", true)
		board = board.filter(func(p): return d.can_pick_player(p))
		if not cover:
			board = board.filter(func(p): return str(p["role"]) != "DEF" and str(p.get("role2", "")) != "DEF")
		if board.is_empty():
			break
		board.sort_custom(func(a, b): return int(a["value"]) < int(b["value"]))
		ui.call("_on_pick", board[0])
	ui.call("_refresh")
	await _settle()
	return ui


## National Draft prospects show a compact Combine and scouting ranges on a
## narrow phone, without exposing the hidden attribute sheet.
func _test_intake_combine() -> void:
	var old_size := root.size
	root.size = Vector2i(360, 800)
	var clubs := ["COL", "CAR"]
	var sizes := {"COL": 34, "CAR": 34}
	var counts := {
		"COL": {"RUCK": 2, "MID": 13, "DEF": 9, "FWD": 10},
		"CAR": {"RUCK": 2, "MID": 13, "DEF": 9, "FWD": 10},
	}
	var prospects: Array = load("res://scripts/sim/Prospects.gd").generate_class(_state.season_year + 1, 7331)
	prospects = prospects.slice(0, 18)
	_state.draft = load("res://scripts/sim/Draft.gd").build_intake(
			prospects, clubs, clubs, 551, sizes, counts)
	_state.draft.start_for_user("COL")
	_state.my_club = "COL"
	# Suppress the separate pre-draft meeting; this test is only the Combine.
	_state.draft_meeting_year = _state.season_year

	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var sort: OptionButton = ui.find_child("SortPlayers", true, false)
	_check(ui.find_child("CareerStageFilter", true, false) == null,
			"Career-stage filtering stays out of the National Draft")
	_check(sort != null and sort.get_item_text(0) == "Best scouted"
			and sort.get_item_text(1) == "Highest upside",
			"National Draft sorting is phrased as scouting, not hidden truth")

	var p: Dictionary = _state.draft.board("", "", "", "overall", true)[0]
	ui.call("_open_player", str(p["id"]))
	await _settle()
	var combine: Label = ui.find_child("CombineHeading", true, false)
	_check(combine != null and combine.text == "What the scouts saw", "Prospect inspection includes the scouts' Combine read")
	_check(ui.find_children("Tested_*", "", true, false).size() in [1, 4],
			"...after his Combine results (all four tests, or a line saying he missed testing)")
	_check(ui.find_children("Combine_*", "", true, false).size() == 4,
			"The Combine stays compact at four scouting reads")
	var ovr: Control = ui.find_child("DetailOVR", true, false)
	var pot: Control = ui.find_child("DetailPOT", true, false)
	_check(ovr != null and pot != null
			and (ovr.get_child(0) as Label).text.contains("-")
			and (pot.get_child(0) as Label).text.contains("-"),
			"Prospect OVR and POT are shown as scouting ranges")
	_check(ui.find_child("DetailAllRatings", true, false) == null
			and ui.find_child("DetailAttributes", true, false) == null,
			"A prospect cannot reveal the hidden exact attribute sheet")
	var prod: Label = ui.find_child("DetailProduction", true, false)
	_check(prod != null and prod.text != "", "Junior production remains beside Combine evidence")
	var note: Label = ui.find_child("CombineNote", true, false)
	_check(note != null and note.text.contains("junior football"),
			"The screen says testing is evidence, not the whole projection")
	var act: Button = ui.find_child("DetailDraft", true, false)
	var close: Button = ui.find_child("DetailClose", true, false)
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	_check(act != null and close != null and act.size.y >= 44 and close.size.y >= 44
			and view.encloses(act.get_global_rect()) and view.encloses(close.get_global_rect()),
			"Combine inspection remains usable on a 360px portrait phone")
	# Selection must not make the hidden true rating suddenly appear elsewhere.
	act.emit_signal("pressed")
	await _settle()
	ui.call("_select_tab", "picks")
	await _settle()
	var picked_entry: Dictionary = _state.draft.pick_details(str(p["id"]))
	var hist: Control = ui.find_child("HistoryPick_%d" % int(picked_entry["pick"]), true, false)
	_check(hist != null and hist.tooltip_text.contains("Scouted") and not hist.tooltip_text.contains("$"),
			"Pick history keeps the selected prospect inside the scouting view")
	ui.call("_select_tab", "squad")
	await _settle()
	var list_is_scouted := false
	for label in ui.find_children("*", "Label", true, false):
		if (label as Label).text.contains("scouted") and (label as Label).text.contains("OVR"):
			list_is_scouted = true
			break
	_check(list_is_scouted, "The intake list keeps a scouted range instead of revealing exact OVR")
	ui.queue_free()
	await _settle()
	await _test_combine_pool()
	root.size = old_size


## The Combine as a menu (ARD-M5-014): a finger's tap opens the tests, a test
## sorts the class on its results best first, each row says the result and
## where it sits, a prospect shows all four, and Back returns to the same view.
func _test_combine_pool() -> void:
	root.size = Vector2i(360, 800)
	var Comb = load("res://scripts/sim/Combine.gd")
	var clubs := ["COL", "CAR"]
	var sizes := {"COL": 34, "CAR": 34}
	var counts := {"COL": {"RUCK": 2, "MID": 13, "DEF": 9, "FWD": 10}, "CAR": {"RUCK": 2, "MID": 13, "DEF": 9, "FWD": 10}}
	var prospects: Array = load("res://scripts/sim/Prospects.gd").generate_class(_state.season_year + 1, 7331)
	_state.draft = load("res://scripts/sim/Draft.gd").build_intake(prospects, clubs, clubs, 551, sizes, counts)
	_state.draft.start_for_user("COL")
	_state.my_club = "COL"
	_state.draft_meeting_year = _state.season_year
	var seed: int = _state.draft.seed
	# The results themselves: seeded, in units, and the same for every club.
	var p0: Dictionary = prospects[0]
	var units_ok := true
	var missed := 0
	for p in prospects:
		if not Comb.tested(p, seed):
			missed += 1
			units_ok = units_ok and Comb.result(p, "sprint", seed) < 0.0 and Comb.text("sprint", -1.0) == "Did not test"
			continue
		var s: float = Comb.result(p, "sprint", seed)
		var t: float = Comb.result(p, "trial", seed)
		var l: float = Comb.result(p, "leap", seed)
		var k: float = Comb.result(p, "kick", seed)
		units_ok = units_ok and s >= 2.78 and s <= 3.30 and t >= 335.0 and t <= 430.0 and l >= 48.0 and l <= 98.0 and k >= 8.0 and k <= 30.0
	_check(units_ok, "Combine results sit in real ranges (sprint seconds, time trial, cm, out of 30)")
	_check(missed < prospects.size() / 4, "Most of the class tests (%d of %d missed)" % [missed, prospects.size()])
	_check(Comb.result(p0, "sprint", seed) == Comb.result(p0, "sprint", seed)
			and Comb.text("trial", 372.0) == "6:12" and Comb.text("sprint", 2.9) == "2.90 s",
			"The same day every time, written as a coach would read it")
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var Tap = preload("res://tests/tap.gd")
	var open: Button = ui.find_child("CombineOpen", true, false)
	var why: String = await Tap.tap(open) if open != null else "no Combine button"
	await _settle()
	_check(why == "" and (ui.find_child("CombineRow", true, false) as Control).visible, "A tap on Combine shows the tests (%s)" % why)
	var sprint: Button = null
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Sprint":
			sprint = b
	why = await Tap.tap(sprint) if sprint != null else "no Sprint test"
	await _settle()
	var rows: Array = ui.call("_board_rows")
	var sorted_ok := rows.size() > 2
	for i in range(rows.size() - 1):
		var a: float = Comb.result(rows[i], "sprint", seed)
		var b: float = Comb.result(rows[i + 1], "sprint", seed)
		if b >= 0.0 and (a < 0.0 or a > b):
			sorted_ok = false
	_check(why == "" and sorted_ok, "Sprint sorts the class fastest first, the untested last (%s)" % why)
	var first: Label = ui.find_child("CombineResult_" + str(rows[0]["id"]), true, false) if not rows.is_empty() else null
	_check(first != null and first.text.contains(" s") and first.text.contains("Best in the class"),
			"The fastest row says his time and that it was the best (%s)" % (first.text if first else "-"))
	var what: Label = ui.find_child("CombineWhat", true, false)
	_check(what != null and what.text.contains("Acceleration"), "The test says what it tells you about his football")
	var inspect: Button = ui.find_child("Inspect_" + str(rows[0]["id"]), true, false)
	why = await Tap.tap(inspect) if inspect != null else "no row"
	await _settle()
	_check(why == "" and ui.find_children("Tested_*", "", true, false).size() == 4, "His sheet shows all four results (%s)" % why)
	ui.call("handle_back")
	await _settle()
	_check(ui.get("_detail") == null, "Back closes his sheet")
	_check(str(ui.get("_combine")) == "sprint" and ui.find_child("CombineResult_" + str(rows[0]["id"]), true, false) != null,
			"...back to the same Combine view")
	ui.queue_free()
	await _settle()


## From eight picks, My list shows your side so far against the league, line
## by line in words: no numbers, no suggested player.
func _test_side_shape(ui: Control) -> void:
	ui.call("_select_tab", "squad")
	await _settle()
	_check(_state.draft.count() >= 8 or ui.find_child("SideShape", true, false) == null,
			"No comparison while the side is too thin to compare")
	var guard := 0
	while _state.draft.count() < 8 and guard < 40:
		guard += 1
		var board: Array = _state.draft.board("", "", "", "overall", true)
		if board.is_empty():
			break
		ui.call("_on_pick", board[0])
	ui.call("_refresh")
	ui.call("_select_tab", "squad")
	await _settle()
	var shape: Node = ui.find_child("SideShape", true, false)
	_check(shape != null and shape.get_child_count() == 5,
			"My list shows the side so far against the league, line by line")
	if shape != null:
		var digits := false
		for c in shape.get_children():
			var t := str((c as Label).text)
			for ch in t:
				if ch >= "0" and ch <= "9":
					digits = true
		_check(not digits, "The comparison is in words, not numbers")
		_check(str((shape.get_child(1) as Label).text).begins_with("Midfield: "),
				"Lines read like selection's: " + str((shape.get_child(1) as Label).text))


## Inspecting a player is read-only; only the explicit Draft button picks.
## A League Draft row for a projected prospect shows your recruiters' range,
## as every other undrafted player does, never his exact stored OVR and POT.
func _test_projected_row(ui: Control) -> void:
	var draft = _state.draft
	var rows: Array = draft.board("MID", "", "", "overall", true)
	var p: Dictionary = rows[1]
	p["projected"] = true
	p["draft_team"] = "COL"
	ui.set("_search", "")
	ui.set("_role", "MID")
	ui.call("_show_board")
	await _settle()
	var row: Node = ui.find_child("Inspect_" + str(p["id"]), true, false)
	var texts := []
	if row != null:
		_collect_texts(row, texts)
	var line := " | ".join(texts)
	var view: Dictionary = draft.user_view(p)
	var scouting = load("res://scripts/sim/DraftScouting.gd")
	_check(row != null and bool(view["scouted"]) and line.contains("projected")
			and line.contains(scouting.range_text(view["potential"]) + " POT")
			and line.contains(scouting.range_text(view["overall"]) + " OVR"),
			"A League Draft projected prospect's row shows a scouted range (%s)" % line)
	p.erase("projected")
	p.erase("draft_team")
	ui.call("_show_board")
	await _settle()


func _collect_texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_texts(c, out)


func _test_inspect(ui: Control) -> void:
	var draft = _state.draft
	ui.set("_search", "")
	ui.set("_role", "MID")
	ui.set("_sort", "overall")
	ui.call("_show_board")
	await _settle()
	var rows: Array = draft.board("MID", "", "", "overall", true)
	var p: Dictionary = rows[0]
	var before := _snapshot(ui)
	var picked_before: int = draft.picked.size()
	var inspect: Button = ui.find_child("Inspect_" + str(p["id"]), true, false)
	_check(inspect != null and inspect.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Each board row has an inspect target that still lets the list scroll")
	inspect.emit_signal("pressed")
	await _settle()
	var detail: Control = ui.find_child("PlayerDetail", true, false)
	_check(detail != null, "Tapping a player row opens his details")
	var name_l: Label = ui.find_child("DetailName", true, false)
	_check(name_l != null and name_l.text == _db.player_display_name(p), "The details are that player's")
	_check(_snapshot(ui) == before and draft.picked.size() == picked_before,
			"Opening details drafts nobody and leaves filters, cap and order alone")
	# Identity, ratings and production.
	var profile = load("res://scripts/sim/PlayerProfile.gd")
	var type_l: Label = ui.find_child("DetailType", true, false)
	_check(type_l != null and type_l.text == profile.player_type(p) and type_l.text != "",
			"An established player shows his type (%s)" % (type_l.text if type_l else "-"))
	var ovr: Control = ui.find_child("DetailOVR", true, false)
	var pot: Control = ui.find_child("DetailPOT", true, false)
	# Undrafted in the League Draft: your recruiters' read, as a range.
	var read: Dictionary = draft.user_view(p)
	_check(ovr != null and bool(read["scouted"])
			and (ovr.get_child(0) as Label).text.contains(str(int(read["overall"][0])))
			and (ovr.get_child(1) as Label).text == "OVR"
			and pot != null and (pot.get_child(0) as Label).text.contains(str(int(read["potential"][0]))),
			"His OVR and POT are your recruiters' read")
	var prod: Label = ui.find_child("DetailProduction", true, false)
	_check(prod != null and prod.text == str(profile.production(p)["line"]) and prod.text.contains("disposals"),
			"His real season production is shown (%s)" % (prod.text if prod else "-"))
	var strengths := ui.find_children("Strength_*", "", true, false)
	var core: Dictionary = load("res://scripts/sim/Ratings.gd").ROLE_WEIGHTS["MID"]
	var core_only := true
	for s in strengths:
		if not core.has(str(s.name).trim_prefix("Strength_")):
			core_only = false
	_check(not strengths.is_empty() and strengths.size() <= 3 and core_only,
			"Strengths are a few of what the engine rewards a midfielder for")
	_check(ui.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and l.text.begins_with("Durability")).is_empty(),
			"The raw rating sheet stays folded away")
	# Android Back closes the details first.
	_check(bool(ui.call("handle_back")) and not is_instance_valid(ui.get("_detail")),
			"Back closes player details")
	await _settle()
	_check(not bool(ui.call("handle_back")), "With details closed, Back leaves it to the router")
	# Traits.
	var with_trait := {}
	for q in rows:
		if not load("res://scripts/sim/Traits.gd").of(q).is_empty():
			with_trait = q
			break
	if not with_trait.is_empty():
		ui.call("_open_player", str(with_trait["id"]))
		await _settle()
		var all_there := true
		for t in load("res://scripts/sim/Traits.gd").of(with_trait):
			var tl: Label = ui.find_child("Trait_" + str(t), true, false)
			# In football words: no simulation percentages when scouting.
			if tl == null or tl.text.contains("%"):
				all_there = false
		_check(all_there, "Each of his traits is shown and explained in football terms")
		ui.call("_close_player")
	# A rebuild (rotation) with details open keeps them open and drafts nobody.
	ui.call("_open_player", str(p["id"]))
	await _settle()
	var size_before := root.size
	root.size = Vector2i(844, 390)
	await _settle()
	root.size = Vector2i(420, 860)
	await _settle()
	_check(is_instance_valid(ui.get("_detail")) and draft.picked.size() == picked_before and _snapshot(ui) == before,
			"Rotating with details open keeps them, and the draft, intact")
	# Full ratings on a portrait phone: readable rows, not one letter a line.
	var shell_before: Vector2 = (ui.get("_detail") as Control).get_child(0).size
	ui.find_child("DetailAllRatings", true, false).emit_signal("pressed")
	await _settle()
	var attrs: Node = ui.find_child("DetailAttributes", true, false)
	var readable := attrs != null and attrs.get_child_count() == (load("res://scripts/ui/PlayerSheet.gd").ATTR_ROWS as Array).size()
	if attrs != null:
		for l in attrs.find_children("*", "Label", true, false):
			if (l as Label).size.y > 30.0 or (l as Label).size.x < 20.0:
				readable = false
	_check(readable, "Full ratings lists every attribute on one readable line each")
	ui.find_child("DetailAllRatings", true, false).emit_signal("pressed")
	await _settle()
	_check(is_instance_valid(ui.get("_detail")) and ui.find_child("DetailAttributes", true, false) == null
			and (ui.get("_detail") as Control).get_child(0).size == shell_before,
			"Hiding them again leaves the details as they were")
	var act: Button = ui.find_child("DetailDraft", true, false)
	var close: Button = ui.find_child("DetailClose", true, false)
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	_check(act != null and close != null and act.size.y >= 44 and close.size.y >= 44
			and view.encloses(act.get_global_rect()) and view.encloses(close.get_global_rect()),
			"On a portrait phone the Draft and Close buttons are touch-sized and on screen")
	# The explicit Draft button picks him.
	var had: int = draft.count()
	act.emit_signal("pressed")
	await _settle()
	_check(draft.has(str(p["id"])) and draft.drafted_by(str(p["id"])) == draft.user_club and draft.count() == had + 1,
			"Draft from the details picks that player")
	_check(not is_instance_valid(ui.get("_detail")), "Drafting closes the details")
	# He stays inspectable, but cannot be picked again.
	ui.call("_open_player", str(p["id"]))
	await _settle()
	var status: Label = ui.find_child("DetailStatus", true, false)
	_check(status != null and status.text.begins_with("On your list"), "A player you drafted says so")
	_check(ui.find_child("DetailDraft", true, false) == null, "A drafted player has no Draft button")
	ui.call("_close_player")
	var rival := {}
	for entry in draft.pick_history:
		if str(entry["club"]) != draft.user_club:
			rival = entry
			break
	ui.call("_open_player", str(rival["player_id"]))
	await _settle()
	status = ui.find_child("DetailStatus", true, false)
	var blocked: Label = ui.find_child("DetailBlocked", true, false)
	_check(status != null and status.text == "Pick %d, %s" % [int(rival["pick"]), _db.club_name(str(rival["club"]))],
			"A rival's pick stays inspectable and shows who took him (%s)" % (status.text if status else "-"))
	_check(blocked == null and ui.find_child("DetailDraft", true, false) == null,
			"...and cannot be drafted again, without repeating where he went")
	ui.call("_close_player")
	# The history opens the same details.
	ui.call("_select_tab", "picks")
	await _settle()
	var hist: Button = ui.find_child("HistoryInspect_%d" % int(rival["pick"]), true, false)
	_check(hist != null, "Pick history rows can be tapped")
	if hist != null:
		hist.emit_signal("pressed")
		await _settle()
		var hn: Label = ui.find_child("DetailName", true, false)
		_check(hn != null and hn.text == _db.player_display_name_by_id(str(rival["player_id"]), ""),
				"Tapping a pick opens that player")
		ui.call("_close_player")
	ui.call("_select_tab", "pool")
	# Cap: an expensive player you cannot afford says why.
	var spend: int = int(draft.club_spend[draft.user_club])
	draft.club_spend[draft.user_club] = draft.budget - 3
	# A dear player still in the pool (an early row may have gone to a rival).
	var dear: Dictionary = rows[3]
	for r in rows:
		if not draft.has(str(r["id"])) and int(r["value"]) > 3:
			dear = r
			break
	ui.call("_open_player", str(dear["id"]))
	await _settle()
	blocked = ui.find_child("DetailBlocked", true, false)
	act = ui.find_child("DetailDraft", true, false)
	_check(blocked != null and blocked.text.contains("salary cap") and act != null and act.disabled,
			"Out of cap: the Draft button is off and the reason is given")
	ui.call("_close_player")
	draft.club_spend[draft.user_club] = spend
	# Not your turn.
	var idx: int = draft.pick_index
	while draft.pick_sequence[draft.pick_index] == draft.user_club:
		draft.pick_index += 1
	# Any player still on the board (the early rows may be gone by now).
	var free: Dictionary = rows[5]
	for r in rows:
		if not draft.has(str(r["id"])):
			free = r
			break
	ui.call("_open_player", str(free["id"]))
	await _settle()
	blocked = ui.find_child("DetailBlocked", true, false)
	_check(blocked != null and blocked.text.begins_with("Not your pick"), "Between your picks, the details say so")
	ui.call("_close_player")
	draft.pick_index = idx
	# Ruck rule: with only two places left and no ruck, a midfielder is off
	# limits and the details say why.
	var mine: Array = draft.club_lists[draft.user_club]
	var saved := mine.duplicate()
	while mine.size() < draft.target_size - 2:
		var filler: Dictionary = rows[0].duplicate()
		filler["id"] = "filler_%d" % mine.size()
		filler["role"] = "MID"
		filler["role2"] = ""
		mine.append(filler)
	for i in range(mine.size()):
		if str(mine[i]["role"]) == "RUCK" or str(mine[i].get("role2", "")) == "RUCK":
			var f: Dictionary = mine[i].duplicate()
			f["role"] = "MID"
			f["role2"] = ""
			mine[i] = f
	var spend2: int = int(draft.club_spend[draft.user_club])
	draft.club_spend[draft.user_club] = 0
	# Pick an actual non-ruck candidate. Role allocation can legitimately make
	# a fixed row a MID/RUCK, which would satisfy the rule and make this test
	# accidentally test the wrong player.
	var non_ruck: Dictionary = {}
	for r in rows:
		if not draft.has(str(r["id"])) and str(r.get("role", "")) != "RUCK" \
				and str(r.get("role2", "")) != "RUCK":
			non_ruck = r
			break
	ui.call("_open_player", str(non_ruck["id"]))
	await _settle()
	blocked = ui.find_child("DetailBlocked", true, false)
	_check(blocked != null and blocked.text.contains("rucks"), "The two-ruck rule is given as the reason (%s)" % (blocked.text if blocked else "-"))
	ui.call("_close_player")
	draft.club_lists[draft.user_club] = saved
	draft.club_spend[draft.user_club] = spend2
	root.size = size_before
	ui.set("_role", "")
	ui.call("_show_board")
	await _settle()


func _snapshot(ui: Control) -> Dictionary:
	var draft = _state.draft
	var out := {
		"history": draft.pick_history.duplicate(true),
		"count": draft.count(),
		"counts": draft.role_counts(),
		"remaining": draft.remaining(),
		"pick_index": draft.pick_index,
	}
	for key in ["_role", "_search", "_sort", "_club_filter", "_career_stage",
			"_available_only", "_advanced_open", "_history_club"]:
		out[key] = ui.get(key)
	return out


# The opening League Draft can be narrowed by career stage without changing
# the draft itself. The cut-offs are based on the actual 2027 pool.
## Filter by how a player plays and by trait, with position, and every row
## shows his age and playing style (director's PC playtest, 2026-10-07:
## "Interceptor, Crumber", "Tagger", age on the row).
func _test_style_and_trait_filters(ui: Control) -> void:
	var profile = load("res://scripts/sim/PlayerProfile.gd")
	var traits_lib = load("res://scripts/sim/Traits.gd")
	var old_size := root.size
	root.size = Vector2i(390, 844)
	ui.set("_advanced_open", true)
	ui.set("_role", "")
	ui.set("_club_filter", "")
	ui.set("_search", "")
	ui.set("_career_stage", "")
	ui.set("_available_only", false)
	ui.call("_show_board")
	await _settle()
	var style_opt: OptionButton = ui.find_child("StyleFilter", true, false)
	var trait_opt: OptionButton = ui.find_child("TraitFilter", true, false)
	_check(style_opt != null and trait_opt != null, "The draft has playing-style and trait filters")
	if style_opt == null or trait_opt == null:
		root.size = old_size
		return
	var styles := []
	for i in range(style_opt.item_count):
		styles.append(style_opt.get_item_text(i))
	var trait_names := []
	for i in range(trait_opt.item_count):
		trait_names.append(trait_opt.get_item_text(i))
	_check(trait_names.has("Interceptor") and trait_names.has("Crumber") and trait_names.has("Tagger"),
			"Traits to filter by include the director's examples (%s)" % ", ".join(trait_names))
	_check(styles.has("Key forward") and styles.has("Wing"), "Playing styles are how a player plays (%s)" % ", ".join(styles))
	var si := styles.find("Key forward")
	style_opt.select(si)
	style_opt.item_selected.emit(si)
	await _settle()
	var rows: Array = ui.call("_board_rows")
	_check(not rows.is_empty() and rows.all(func(p): return profile.player_type(p) == "Key forward"),
			"Playing style Key forward shows only key forwards (%d)" % rows.size())
	ui.call("_set_role", "FWD")
	await _settle()
	rows = ui.call("_board_rows")
	var ratings_lib = load("res://scripts/sim/Ratings.gd")
	_check(rows.all(func(p): return profile.player_type(p) == "Key forward" and (str(p["role"]) == "FWD" or ratings_lib.second_positions(p).has("FWD"))),
			"Style and position combine")
	ui.call("_set_role", "")
	style_opt = ui.find_child("StyleFilter", true, false)
	style_opt.select(0)
	style_opt.item_selected.emit(0)
	await _settle()
	trait_opt = ui.find_child("TraitFilter", true, false)
	var ti := -1
	for i in range(trait_opt.item_count):
		if trait_opt.get_item_text(i) == "Tagger":
			ti = i
	_check(ti > 0, "Tagger is a trait to filter by")
	if ti > 0:
		trait_opt.select(ti)
		trait_opt.item_selected.emit(ti)
		await _settle()
		rows = ui.call("_board_rows")
		var roles_lib = load("res://scripts/sim/Roles.gd")
		_check(not rows.is_empty() and rows.all(func(p): return roles_lib.is_tagger(p)),
				"The Tagger filter finds players with the Tagger trait, not the word (%d)" % rows.size())
	# The row: his age on the facts line, how he plays on its own line, and
	# both fit a phone.
	var row: Control = ui.find_child("Player_*", true, false)
	var kind: Label = row.find_child("Kind_*", true, false) if row != null else null
	var texts := []
	_collect_texts(row, texts)
	_check(kind != null and kind.text != "" and " ".join(texts).contains(" yo · "),
			"A draft row shows his age and his playing style and traits")
	_check(kind != null and kind.get_global_rect().end.x <= float(root.size.x) + 1.0,
			"His playing style line fits a phone's width")
	# The facts that decide a pick wrap rather than cut (UI review check #590
	# found the price cut off on every pool row), and the row grows to hold them.
	var facts: Label = null
	for l in (row.find_children("*", "Label", true, false) if row != null else []):
		if str((l as Label).text).contains(" yo · "):
			facts = l
	var insp: Control = row.find_child("Inspect_*", true, false) if row != null else null
	_check(facts != null and facts.text.contains("$") and facts.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
			and facts.get_global_rect().end.x <= float(root.size.x) + 1.0
			and insp != null and facts.get_global_rect().end.y <= insp.get_global_rect().end.y + 1.0,
			"A pool row keeps his price on a phone, inside the row (%s)" % (facts.text if facts else "-"))
	ui.call("_clear_filters")
	await _settle()
	_check(str(ui.get("_style")) == "" and str(ui.get("_trait")) == "", "Clear filters resets style and trait")
	root.size = old_size
	await _settle()


func _test_career_stage_filters(ui: Control) -> void:
	var counts := {"rookie": 0, "prime": 0, "veteran": 0}
	var valid := true
	for p in _state.draft.pool:
		var stage := str(ui.call("_career_stage_for_age", float(p.get("age", 0.0))))
		if not counts.has(stage):
			valid = false
		else:
			counts[stage] = int(counts[stage]) + 1
	_check(valid and int(counts["rookie"]) + int(counts["prime"]) + int(counts["veteran"]) == _state.draft.pool.size(),
			"Every League Draft player belongs to exactly one career stage")
	_check(int(counts["rookie"]) > 100 and int(counts["prime"]) > 100 and int(counts["veteran"]) > 100,
			"The 2027 career-stage bands are all useful, populated groups")
	_check(str(ui.call("_career_stage_for_age", 23.99)) == "rookie"
			and str(ui.call("_career_stage_for_age", 24.0)) == "prime"
			and str(ui.call("_career_stage_for_age", 28.99)) == "prime"
			and str(ui.call("_career_stage_for_age", 29.0)) == "veteran",
			"Career-stage boundary ages route to the intended band")

	var old_size := root.size
	root.size = Vector2i(360, 800)
	var pool_size: int = int(_state.draft.pool.size())
	var history: Array = _state.draft.pick_history.duplicate(true)
	ui.set("_advanced_open", true)
	ui.set("_role", "MID")
	ui.set("_club_filter", "")
	ui.set("_search", "")
	ui.set("_career_stage", "rookie")
	ui.call("_show_board")
	await _settle()
	var stage_filter: OptionButton = ui.find_child("CareerStageFilter", true, false)
	_check(stage_filter != null and stage_filter.item_count == 4
			and stage_filter.get_item_text(0) == "All"
			and stage_filter.get_item_text(1) == "Rookies"
			and stage_filter.get_item_text(2) == "Prime"
			and stage_filter.get_item_text(3) == "Veterans",
			"League Draft exposes one compact All/Rookies/Prime/Veterans control")
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	_check(stage_filter != null and stage_filter.size.y >= 44
			and viewport.encloses(stage_filter.get_global_rect()),
			"Career-stage filter is touch-sized and fits a 360px portrait phone")

	var rows: Array = ui.call("_board_rows")
	var combined_ok := not rows.is_empty()
	for p in rows:
		combined_ok = combined_ok and (
				load("res://scripts/sim/Ratings.gd").plays_role(p, "MID")
				and str(ui.call("_career_stage_for_age", float(p.get("age", 0.0)))) == "rookie")
	_check(combined_ok, "Career stage combines with the existing position filter")

	if not rows.is_empty():
		var target: Dictionary = rows[0]
		var search_name := str(target.get("real_name", target.get("name", "")))
		var query := search_name.split(" ")[0] if not search_name.is_empty() else str(target["id"])
		ui.set("_search", query)
		var searched: Array = ui.call("_board_rows")
		var search_ok := not searched.is_empty()
		for p in searched:
			search_ok = search_ok and str(ui.call("_career_stage_for_age", float(p.get("age", 0.0)))) == "rookie"
		_check(search_ok, "Career stage combines with player search")

	if stage_filter != null:
		stage_filter.select(2)
		stage_filter.emit_signal("item_selected", 2)
		await _settle()
	_check(str(ui.get("_career_stage")) == "prime", "Switching the career-stage control changes only the view")
	_check(_state.draft.pool.size() == pool_size and _state.draft.pick_history == history,
			"Switching career stage never changes the underlying draft pool or picks")

	ui.set("_search", "")
	var prime_rows: Array = ui.call("_board_rows")
	if not prime_rows.is_empty():
		ui.call("_open_player", str(prime_rows[0]["id"]))
		await _settle()
		_check(str(ui.get("_career_stage")) == "prime", "Inspecting a player preserves the career-stage filter")
		ui.call("_close_player")
		await _settle()
		_check(str(ui.get("_career_stage")) == "prime", "Closing a player returns to the same career stage")

	ui.call("_clear_filters")
	await _settle()
	_check(str(ui.get("_career_stage")) == "", "Clear filters restores All career stages")
	root.size = old_size


# One row of position cards shows the list's needs and filters the pool; no
# second position row repeats it above the pool.
func _test_position_filters(ui: Control) -> void:
	var kit = load("res://scripts/ui/UiKit.gd")
	root.size = Vector2i(420, 860)
	ui.call("_select_tab", "pool")
	await _settle()
	var pool: Control = ui.find_child("DraftPool", true, false)
	for role in ["DEF", "MID", "RUCK", "FWD"]:
		_check(ui.find_children("Position_" + role, "Button", true, false).size() == 1,
				"One %s card, not two position rows" % role)
		_check(ui.find_children("Filter_" + role, "Button", true, false).is_empty(),
				"No separate %s filter tab" % role)
		var card: Button = ui.find_child("Position_" + role, true, false)
		_check(pool.is_ancestor_of(card), "The %s card sits in the draft pool" % role)
		var words := ""
		for l in card.find_children("*", "Label", true, false):
			words += str(l.text) + " "
		var one_state := ["short ", "need ", "light ", "covered"].filter(func(w): return words.contains(w)).size() == 1
		_check(words.contains(role + " ") and one_state and not words.contains("can play"),
				"The %s card shows the count and one state (%s)" % [role, words])
	var all: Button = ui.find_child("Filter_ALL", true, false)
	var mid: Button = ui.find_child("Position_MID", true, false)
	_check(all != null and all.size.x < mid.size.x, "All is compact beside the position cards")
	ui.call("_set_role", "")
	mid.emit_signal("pressed")
	await _settle()
	_check(ui.get("_role") == "MID", "Tapping a card filters the pool to that position")
	var info: Label = ui.get("_board_info")
	var want: int = _state.draft.board("MID", str(ui.get("_club_filter")), str(ui.get("_search")),
			str(ui.get("_sort")), bool(ui.get("_available_only"))).size()
	_check(info.text.begins_with("%d MID " % want), "The pool lists that position's players (%s)" % info.text)
	var sb: StyleBoxFlat = mid.get_theme_stylebox("normal")
	_check(sb.border_color == kit.ROLE_COLOUR["MID"], "The chosen card is outlined")
	_check((all.get_theme_stylebox("normal") as StyleBoxFlat).border_color != kit.TEXT, "All is not outlined while filtered")
	mid.emit_signal("pressed")
	await _settle()
	_check(ui.get("_role") == "", "Tapping the chosen card again shows everyone")
	ui.find_child("Position_FWD", true, false).emit_signal("pressed")
	await _settle()
	all.emit_signal("pressed")
	await _settle()
	_check(ui.get("_role") == "" and (all.get_theme_stylebox("normal") as StyleBoxFlat).border_color == kit.TEXT,
			"All shows everyone and is outlined")


func _check_layout(ui: Control, label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var margin: Control = ui.get("_margin")
	_check(viewport.grow(1).encloses(margin.get_global_rect()), label + " has no page overflow")
	for node_name in ["DraftWorkspace", "StartSeason", "DraftPool", "DraftActivity",
			"Position_DEF", "Position_MID", "Position_RUCK", "Position_FWD", "LatestRivalPick"]:
		var node: Control = ui.find_child(node_name, true, false)
		if node != null and node.is_visible_in_tree():
			_check(viewport.grow(1).encloses(node.get_global_rect()), label + ": " + node_name + " fits")
	for card in ui.find_children("Position_*", "Button", true, false):
		for text in card.find_children("*", "Label", true, false):
			_check(card.get_global_rect().grow(1).encloses(text.get_global_rect()),
					label + ": position text stays inside its card")
	for prefix in ["Position_", "Tab_", "SideTab_", "Filter_"]:
		for node in ui.find_children(prefix + "*", "Button", true, false):
			if node.is_visible_in_tree():
				_check(node.size.y >= 44, label + ": " + str(node.name) + " is touch-sized")


## Drafting a player with a real click rebuilds the rows under the pointer.
## The list must still hear that click end: if it doesn't, it stays mid-drag
## and the next mouse move drags the pool back to where the click began
## (director's PC playtest, 2026-10-07: "selecting a player breaks scrolling").
func _test_pick_keeps_scroll(ui: Control) -> void:
	ui.call("_select_tab", "pool")
	await _settle()
	var sc: ScrollContainer = ui.get("_board_scroll")
	sc.scroll_vertical = 300
	await _settle()
	var view: Rect2 = sc.get_global_rect()
	var pick: Button = null
	for b in ui.find_children("Pick_*", "Button", true, false):
		var r: Rect2 = (b as Control).get_global_rect()
		if not (b as Button).disabled and r.position.y > view.position.y + 20 and r.end.y < view.end.y - 20:
			pick = b
			break
	_check(pick != null, "A draftable player is on screen for the click")
	if pick == null:
		return
	var count_before: int = _state.draft.count()
	var at := pick.get_global_rect().get_center()
	await _mouse_move(at)
	await _mouse_button(at, MOUSE_BUTTON_LEFT, true)
	await _mouse_button(at, MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(_state.draft.count() == count_before + 1, "A real click on + drafts the player")
	sc = ui.get("_board_scroll")
	var mid := sc.get_global_rect().get_center()
	await _mouse_move(mid)
	for i in range(8):
		await _mouse_button(mid, MOUSE_BUTTON_WHEEL_DOWN, true)
		await _mouse_button(mid, MOUSE_BUTTON_WHEEL_DOWN, false)
	var scrolled := sc.scroll_vertical
	for i in range(4):
		await _mouse_move(mid + Vector2(i * 5, i * 2))
	await _settle()
	_check(scrolled > 300 and sc.scroll_vertical == scrolled,
			"After drafting, the pool scrolls and stays put when the mouse moves (%d, then %d)"
			% [scrolled, sc.scroll_vertical])


func _mouse_button(at: Vector2, button: MouseButton, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = at
	ev.global_position = at
	ev.button_index = button
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if (down and button == MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame
	await process_frame


func _mouse_move(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = Vector2(0, 3)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame
	await process_frame


## Draft night's hero (director, 2026-10-14): the guernsey of the club on the
## clock in the header, in that club's own kit, on its own (no hanger, no
## lectern), nothing in the header cut short, the back button still a real tap
## away. It needs no picture file.
func _test_stage() -> void:
	var art = load("res://scripts/ui/UiArt.gd")
	for club in ["FRE", "MEL"]:
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			var tag := "%s %dx%d" % [club, sz.x, sz.y]
			root.size = sz
			_state.reset()
			_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
					_db.active_clubs(2026).duplicate(), 12345)
			var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
			root.add_child(ui)
			ui.call("_on_club_chosen", club)
			await _settle()
			var stage: Control = ui.find_child("DraftStage", true, false)
			var hung: Control = stage.find_child("DraftGuernsey", true, false) if stage != null else null
			var marker: Control = hung.find_child("ClubMarker", true, false) if hung != null else null
			_check(marker != null and marker.size.x >= (64.0 if sz.x >= 760 else 53.0) and is_equal_approx(marker.size.x, marker.size.y),
					"%s: the draft's header shows a guernsey, as big as it was under the hanger (%d)" % [tag, int(marker.size.x) if marker != null else 0])
			if stage == null or marker == null:
				ui.queue_free()
				await _settle()
				continue
			_check(stage.find_children("*", "TextureRect", true, false).is_empty() and hung.get_child_count() == 1,
					"%s: the guernsey is on its own: no hanger and no lectern" % tag)
			var crest = hung.find_child("ClubMarker", true, false)
			var on_clock := str(_state.draft.current_club())
			var kit_cols: Dictionary = _db.club_guernsey(on_clock)
			_check(crest != null and str(crest.code) == on_clock and (crest.primary as Color).is_equal_approx(kit_cols["base"])
					and str(crest.design) == str(kit_cols["design"]),
					"%s: the guernsey is the club on the clock's own (%s)" % [tag, on_clock])
			var cr: Rect2 = (crest as Control).get_global_rect() if crest != null else Rect2()
			var sr := hung.get_global_rect()
			_check(crest != null and absf(cr.end.y - sr.end.y) <= 0.5 and absf(cr.get_center().x - sr.get_center().x) <= 1.0
					and cr.position.y >= sr.position.y,
					"%s: the guernsey stands on the stage's foot, on its centre line, where it hung" % tag)
			var header: Control = stage.get_parent()
			var whole := header.get_global_rect().grow(0.5).encloses(stage.get_global_rect()) \
					and Rect2(Vector2.ZERO, Vector2(sz)).encloses(stage.get_global_rect())
			var quiet := stage.mouse_filter == Control.MOUSE_FILTER_IGNORE
			for n in stage.find_children("*", "Control", true, false):
				quiet = quiet and (n as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
			for l in header.find_children("*", "Label", true, false):
				var lab := l as Label
				if lab.get_parent() is Button or not lab.is_visible_in_tree() or lab.text == "":
					continue
				if lab.size.y + 1.0 < lab.get_combined_minimum_size().y or lab.get_global_rect().intersects(stage.get_global_rect()):
					whole = false
				if lab.autowrap_mode == TextServer.AUTOWRAP_OFF and lab.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
						and lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x > lab.size.x + 0.5:
					whole = false
			_check(whole and quiet, "%s: the stage sits inside the header, takes no tap, and the title beside it is whole" % tag)
			var back: Button = ui.find_child("BackToMenu", true, false)
			_check(back != null and back.size.x >= 44.0 and back.size.y >= 44.0, "%s: the back button is still a thumb wide and tall" % tag)
			if sz.x < 600 and club == "FRE":
				for c in back.pressed.get_connections():
					back.pressed.disconnect(c["callable"])
				var why: String = await Tap.tap(back)
				_check(why == "", "%s: a real tap still reaches the back button beside the title (%s)" % [tag, why])
				var status: Label = ui.find_child("DraftStatus", true, false)
				var cap: Label = ui.find_child("SalaryCap", true, false)
				_check(status != null and status.text != "" and cap != null and cap.text.contains("Cap left"),
						"%s: who is on the clock and the cap left are still said under the header" % tag)
			ui.queue_free()
			await _settle()
	# No picture file is needed: with the art folder pointed nowhere the guernsey is still there.
	art.dir = "res://assets/ui/no_such_folder"
	root.size = Vector2i(390, 844)
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(), _db.active_clubs(2026).duplicate(), 12345)
	var plain: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(plain)
	plain.call("_on_club_chosen", "FRE")
	await _settle()
	var plain_stage: Control = plain.find_child("DraftStage", true, false)
	_check(plain_stage != null and plain_stage.find_child("ClubMarker", true, false) != null
			and not ResourceLoader.exists("res://assets/ui/models/hanger.png"),
			"The guernsey needs no picture file, and the hanger's picture is gone from the game")
	plain.queue_free()
	await _settle()
	art.dir = "res://assets/ui/models"
	_state.reset()


func _settle() -> void:
	# Resize, deferred rebuild, container sorting, and scroll restoration.
	for i in range(5):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## P-18: open a prospect's sheet with a real tap, draft someone else, and the
## rival picks that follow say, in one line under the ticker, why a club took
## or passed on him, with the club's name in its ink. Opening no one: no line.
func _test_rival_why() -> void:
	root.size = Vector2i(390, 844)
	_state.reset()
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 4242)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "FRE")
	await _settle()
	_check(ui.find_child("RivalWhyLine", true, false) == null, "No reason line before you have opened anyone")
	var rows: Array = _state.draft.board("", "", "", "overall", true)
	var wanted: Dictionary = rows[0]
	var inspect: Button = ui.find_child("Inspect_" + str(wanted["id"]), true, false)
	var why_tap: String = await Tap.tap(inspect)
	await _settle()
	_check(why_tap == "" and _state.draft.wanted().has(str(wanted["id"])),
			"A real tap on a prospect opens his sheet and he counts as wanted (%s)" % why_tap)
	ui.call("_close_player")
	await _settle()
	ui.call("_on_pick", rows[1])
	await _settle()
	var line: Control = ui.find_child("RivalWhyLine", true, false)
	var plain := str(line.get_meta("plain", "")) if line != null and line.has_meta("plain") else ""
	var rival_named := false
	for c in _state.draft.clubs:
		if plain.begins_with(str(_db.club_name(c)) + " "):
			rival_named = true
	_check(line is RichTextLabel and (line as RichTextLabel).text.contains("[color=") and rival_named
			and plain.contains(_db.player_display_name(wanted)) and not plain.contains("{"),
			"After the rival picks, one line says why a club took or passed on him, the club in its ink (%s)" % plain)
	_check(line != null and line.is_visible_in_tree() and line.get_global_rect().size.y < 80.0,
			"The reason is one short line on the phone, not a card")
	ui.queue_free()
	await _settle()
