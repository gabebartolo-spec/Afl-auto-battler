extends SceneTree
## godot --headless --path . --script tests/run_intake_ui_tests.gd
## Intake-draft presentation regressions on the shared DraftScene: it must
## open straight to the board in intake mode, keep every control on-viewport
## and touch-sized across ten viewports, survive filters and rotation, and
## hand off to a fresh season when finished.

const Tap := preload("res://tests/tap.gd")
const VIEWPORTS := [
	Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568),
	Vector2i(360, 800), Vector2i(430, 932), Vector2i(768, 1024),
	Vector2i(1024, 768), Vector2i(667, 375), Vector2i(915, 412), Vector2i(1280, 800),
]

var _state: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []

## Every season in this suite starts from a fixed seed (C15), never the clock.
const SUITE_SEED := 2027


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
	_state.replay_seed = SUITE_SEED
	_db = root.get_node("GameDB")
	_state.reset()
	await _t("_test_intake_by_taps")
	await _t("_test_pass_and_pick_for_me", [Vector2i(390, 844)])
	await _t("_test_pass_and_pick_for_me", [Vector2i(1280, 720)])
	await _t("_test_pick_order_and_untouchable_ui")
	print(Ran.line("Intake UI", self))
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


## The National Draft on the shared screen, driven by taps, through to the new list (the checks written in _run).
func _test_intake_by_taps() -> void:
	var first_year := int(_state.season_year)
	_state.start_season("COL", _db.club_list("COL"))
	var season = _state.season
	season.round_index = season.fixture.size()  # The H&A is done; draft time.
	# A compensation pick for losing a free agent, so the order shows one.
	_state.open_offseason()
	_state.compensation.append({"club": "COL", "player": "comp_test", "name": "Sam Example",
			"to": "CAR", "salary": 8, "years": 3, "value": 10.0, "after": 1})
	# A first-round pick bought from Carlton for a player: the order and your
	# picks must say where it came from (P-46).
	_state.pick_owner = {}
	_state.pick_got = {}
	var bought_pick: Dictionary = _state.pick_asset(_state.pick_id(first_year, 1, "CAR"))
	var paid_player: Dictionary = (_state.season.lists["COL"] as Array)[-1]
	var paid_name: String = _db.player_display_name(paid_player)
	_state._execute_trade("CAR", "COL", [bought_pick], [paid_player])
	var opened: bool = _state.begin_intake_draft()
	_check(opened, "begin_intake_draft opens after the home-and-away")
	var draft = _state.draft
	_check(bool(draft.intake_mode), "GameState built an intake draft")

	# A phone in portrait, so the taps below land the way a player's would.
	root.size = Vector2i(390, 844)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	_check(ui.get("_phase") == "board", "The intake draft resumes straight to the board")
	# The recruiting panel meets first: a few lines on the list, a few names,
	# no order of preference and no "best pick".
	var meeting: Control = ui.find_child("DraftMeeting", true, false)
	_check(meeting != null, "The recruiting panel meets before the National Draft")
	var names := ui.find_children("MeetingName_*", "Button", true, false)
	_check(names.size() >= 1 and names.size() <= int(load("res://scripts/sim/RecruitMeeting.gd").NAMES), "It names a few prospects (%d)" % names.size())
	var said := ""
	if meeting != null:
		for l in meeting.find_children("*", "Label", true, false):
			said += str(l.text).to_lower() + " "
	for b in names:
		said += str((b as Button).text).to_lower() + " "
	var pushy := false
	for w in ["best pick", "must take", "you should", "recommend", "top pick"]:
		if said.contains(w):
			pushy = true
	_check(not pushy, "The meeting never tells you who to take (%s)" % said.left(200))
	var names_said := ""
	for b in names:
		names_said += str((b as Button).text).to_lower() + " "
	var ordered := false
	for w in ["best", "should", "take him", "must"]:
		if names_said.contains(w):
			ordered = true
	_check(not ordered, "No name line says best, should, must or take him (%s)" % names_said.left(200))
	var done: Button = ui.find_child("MeetingDone", true, false)
	if done != null:
		await _press(done, "Done in the recruiting meeting")
	await _settle()
	_check(ui.find_child("DraftMeeting", true, false) == null, "One tap and it is the draft")
	# The order is a tab on a phone and a side panel when wide.
	var order_tab: Button = ui.find_child("Tab_order", true, false)
	if order_tab == null:
		order_tab = ui.find_child("SideTab_order", true, false)
	if order_tab != null:
		await _press(order_tab, "the draft order")
		await _settle()
	var comp_rows := ui.find_children("CompPick", "Label", true, false)
	_check(comp_rows.size() == 1
			and str((comp_rows[0] as Label).text).contains("Compensation for losing Sam Example"),
			"The draft order shows a compensation pick as compensation, with the player it replaces")
	var want_via := "From %s, for %s, %d trade period" % [_db.club_name("CAR"), paid_name, first_year]
	var via_node: Control = ui.find_child("ViaPick", true, false)
	_check(via_node != null and _line_text(via_node) == want_via,
			"The draft order says where a bought pick came from: %s" % (_line_text(via_node) if via_node else "-"))
	_check(via_node is RichTextLabel and str((via_node as RichTextLabel).text).contains("[color=#"),
			"The player in that line wears his club's ink")
	var own_node: Control = null
	for c in ui.find_children("OwnPick", "Control", true, false):
		if own_node == null and _line_text(c).begins_with("Your own, "):
			own_node = c
	_check(own_node != null and _line_text(own_node).begins_with("Your own, ")
			and _line_text(own_node).ends_with("on the ladder"),
			"Your own pick says so and where the club finished: %s" % (_line_text(own_node) if own_node else "-"))
	# One ink for every provenance line (lead review): own and traded alike, and a
	# rival's own pick says so too, so no row of the order is left without one.
	_check(_ink(via_node) == _text_ink() and _ink(own_node) == _text_ink(),
			"Own and traded picks read in the same ink, not quieter for being your own")
	var round_picks: int = (draft.pick_rounds as Array).count(draft.current_round())
	var story_rows := ui.find_children("ViaPick", "Control", true, false).size()
	story_rows += ui.find_children("OwnPick", "Control", true, false).size()
	story_rows += ui.find_children("CompPick", "Control", true, false).size()
	_check(round_picks > 0 and story_rows == round_picks,
			"Every row of the draft order says whose pick it is and where it came from (%d lines, %d rows)" % [story_rows, round_picks])
	var rival_own := ui.find_children("OwnPick", "Control", true, false).filter(func(c): return _line_text(c).contains("'s own"))
	_check(not rival_own.is_empty(), "A rival's own pick reads \"Club's own\" (%d rows)" % rival_own.size())
	var squad_tab: Button = ui.find_child("Tab_squad", true, false)
	if squad_tab == null:
		squad_tab = ui.find_child("SideTab_squad", true, false)
	if squad_tab != null:
		await _press(squad_tab, "My list")
		await _settle()
	var stories := ui.find_children("MyPickStory_*", "Control", true, false)
	var told := stories.filter(func(c): return _line_text(c) == want_via)
	_check(ui.find_child("MyPicks", true, false) != null and not told.is_empty()
			and stories.any(func(c): return _line_text(c).begins_with("Your own, ")),
			"Your picks list each one with how you got it (%d lines)" % stories.size())
	if order_tab != null:
		await _press(order_tab, "the draft order")
		await _settle()
	var tab_pool: Button = ui.find_child("Tab_pool", true, false)
	if tab_pool != null:
		await _press(tab_pool, "the pool tab")
		await _settle()
	var again: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(again)
	await _settle()
	_check(again.find_child("DraftMeeting", true, false) == null, "The panel meets once a draft, not every visit")
	again.queue_free()
	await _settle()
	var cap: Label = ui.find_child("SalaryCap", true, false)
	_check(cap != null and cap.text.contains("prospects left"), "Intake swaps the cap line for prospects left")

	var board0 = draft.board("", "", "", "overall", true)
	if not draft.is_user_turn():
		_check(not draft.pick(board0[0]), "Picks outside your turn are rejected")
	while not draft.is_finished():
		var candidate = draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
		if draft.is_user_turn():
			break
	await _settle()
	ui.call("_refresh")
	# Inspect a prospect first: projected rating, U18 / state-league season,
	# pedigree - and only the Sign button signs him.
	var board1: Array = draft.board("", "", "", "overall", true)
	var prospect: Dictionary = board1[0]
	for q in board1:
		if float(q.get("u18_di", 0.0)) > 0.0 and int(q.get("u18_gm", 0)) > 0:
			prospect = q
			break
	var count_before: int = draft.count()
	var hist_before: Array = draft.pick_history.duplicate(true)
	var inspect: Button = ui.find_child("Inspect_" + str(prospect["id"]), true, false)
	if inspect == null:
		ui.call("_open_player", str(prospect["id"]))
	else:
		await _press(inspect, "a prospect's row")
	await _settle()
	_check(ui.find_child("PlayerDetail", true, false) != null, "A prospect's details open")
	_check(draft.count() == count_before and draft.pick_history == hist_before, "Inspecting a prospect signs nobody")
	var ovr: Control = ui.find_child("DetailOVR", true, false)
	# Loaded here, not named: DraftScouting reaches GameDB, which does not exist yet
	# when this script compiles (an autoload class named at compile time hangs the suite).
	var scouting: GDScript = load("res://scripts/sim/DraftScouting.gd")
	var scout: Dictionary = scouting.projection(prospect, draft.user_club, draft.seed,
			draft.scouting_mult_for(draft.user_club))
	_check(ovr != null and (ovr.get_child(0) as Label).text == scouting.range_text(scout["overall"])
			and (ovr.get_child(1) as Label).text == "Projected OVR",
			"His projected OVR is shown as a scouting range")
	_check(ui.find_child("DetailAllRatings", true, false) == null,
			"A National Draft prospect cannot reveal the hidden exact attribute sheet")
	var prod: Label = ui.find_child("DetailProduction", true, false)
	_check(prod != null and prod.text.contains("%.1f disposals" % float(prospect["u18_di"])),
			"His U18 / state-league production is shown (%s)" % (prod.text if prod else "-"))
	var found_ped := false
	for l in ui.find_children("*", "Label", true, false):
		if str(l.text).begins_with("Ranked #%d" % int(prospect["draft_rank"])):
			found_ped = true
	_check(found_ped, "His draft ranking and pathway are shown")
	var type_l: Label = ui.find_child("DetailType", true, false)
	_check(type_l != null and type_l.text != "", "A prospect has a football identity (%s)" % (type_l.text if type_l else "-"))
	var act: Button = ui.find_child("DetailDraft", true, false)
	_check(act != null and act.text.begins_with("Sign "), "The intake action reads Sign")
	if draft.is_user_turn():
		_check(not act.disabled, "Sign is live on your turn")
		await _press(act, "Sign")
		await _settle()
		_check(draft.count() == count_before + 1 and draft.has(str(prospect["id"])),
				"Sign from the details signs that prospect")
	else:
		var why: Label = ui.find_child("DetailBlocked", true, false)
		_check(act.disabled and why != null and why.text.begins_with("Not your pick"),
				"Off your turn, Sign is off and says why")
		ui.call("_close_player")

	ui.set("_role", "RUCK")
	ui.set("_search", "a")
	ui.set("_sort", "overall")
	ui.set("_club_filter", "Sandringham Dragons" if _has_sandringham(draft) else "")
	ui.set("_advanced_open", true)
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

	# The recruiting-club filter uses junior clubs, not the 18 AFL codes.
	var filter: OptionButton = ui.find_child("OriginClubFilter", true, false)
	var saw_junior := false
	for i in range(filter.item_count):
		if str(filter.get_item_text(i)).contains("Dragons"):
			saw_junior = true
	_check(_junior_filter_ok(saw_junior), "The origin filter lists recruiting clubs in intake mode")

	ui.call("_clear_filters")
	await _settle()
	var finish: Button = ui.find_child("StartSeason", true, false)
	_check(finish.text == "Finish draft", "The action button is 'Finish draft' in intake mode")
	_check(not finish.disabled or draft.is_user_turn(),
			"Finish unlocks when the board is closed or it is your turn")

	# Finishing through the model must roll the career a year forward.
	while not draft.is_finished():
		var candidate2 = draft._best_ai_pick(draft.current_club())
		if candidate2.is_empty() or not draft._draft_pick(draft.current_club(), candidate2):
			draft._skip_current_pick()
	# Retirements run in the same rollover, so an old list can end up shorter
	# than it started. Check the signings landed rather than the raw length.
	var signed_ids := []
	for p in (draft.club_lists.get("COL", []) as Array):
		signed_ids.append(str(p["id"]))
	var ok: bool = _state.finish_intake_draft()
	_check(ok, "The intake commits from a UI-driven draft")
	_check(int(_state.season_year) == first_year + 1, "The career advanced a year")
	var new_ids := {}
	for p in (_state.league_lists["COL"] as Array):
		new_ids[str(p["id"])] = true
	var all_landed := true
	for id in signed_ids:
		if not new_ids.has(id):
			all_landed = false
	_check(all_landed, "Every intake signing is on the new list")
	ui.queue_free()
	await _settle()


## Real taps on "Pick for me" and "Pass" at one screen size.
func _test_pass_and_pick_for_me(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", _db.club_list("COL"))
	_state.season.round_index = _state.season.fixture.size()
	_state.open_offseason()
	if not _state.begin_intake_draft():
		_check(false, "The draft opens for the pick buttons test (%s)" % tag)
		return
	var draft = _state.draft
	root.size = size
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var meeting: Control = ui.find_child("DraftMeeting", true, false)
	if meeting != null:
		var skip: Button = ui.find_child("MeetingDone", true, false)
		if skip != null:
			await _press(skip, "the recruiting panel")
	# Get to the coach's own turn.
	var guard := 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	var pick_me: Button = ui.find_child("PickForMe", true, false)
	var pass_b: Button = ui.find_child("PassPick", true, false)
	_check(pick_me != null and pass_b != null, "Both buttons are on the draft screen (%s)" % tag)
	if pick_me == null or pass_b == null:
		ui.queue_free()
		return
	_check(pick_me.text == "Pick for me" and pass_b.text == "Pass", "The buttons read Pick for me and Pass (%s)" % tag)
	_check(not pick_me.disabled and not pass_b.disabled, "Both buttons are live on your turn (%s)" % tag)
	var expect: String = str(draft._best_ai_pick(draft.user_club)["id"])
	var before: int = draft.count()
	await _press(pick_me, "Pick for me (%s)" % tag)
	await _settle()
	_check(draft.count() == before + 1 and str(draft.list()[-1]["id"]) == expect,
			"A tap on Pick for me signs the assistant's choice, once (%s)" % tag)
	guard = 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	if draft.is_user_turn():
		var taken: int = draft.count()
		await _press(pass_b, "Pass (%s)" % tag)
		await _settle()
		_check(draft.count() == taken and draft.passed_clubs.has(draft.user_club),
				"A tap on Pass signs nobody and leaves the draft (%s)" % tag)
		_check(draft.is_finished() or not draft.is_user_turn(), "A passed coach is not asked again (%s)" % tag)
	ui.queue_free()
	await _settle()


## The hub's draft line in the last rounds (P-47) and the untouchable mark on
## My list, by a real tap (P-49), on a phone.
func _test_pick_order_and_untouchable_ui() -> void:
	_state.reset()
	_state.replay_seed = SUITE_SEED
	_state.start_season("COL", _db.club_list("COL"))
	root.size = Vector2i(390, 844)
	var s = _state.season
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	_check(hub.find_child("DraftPickLine", true, false) == null, "Early in the season the hub says nothing about the draft")
	hub.queue_free()
	await _settle()
	s.round_index = s.fixture.size() - _state.PICK_LINE_ROUNDS
	hub = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	var line: Control = hub.find_child("DraftPickLine", true, false)
	_check(line != null and (line as Label).text == _state.pick_order_line()
			and (line as Label).text.begins_with("Your first pick today: No. "),
			"In the last rounds the hub says where your first pick would fall: %s" % ((line as Label).text if line else "-"))
	hub.queue_free()
	await _settle()
	# One line, never an orphaned "No. 11." on the next, at 360, 390 and 412.
	for width in [360, 390, 412]:
		root.size = Vector2i(width, 844)
		hub = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		await _settle()
		line = hub.find_child("DraftPickLine", true, false)
		_check(line is Label and (line as Label).get_line_count() == 1,
				"The hub's pick line is one line at %d wide: %s" % [width,
				"%d lines" % (line as Label).get_line_count() if line is Label else "-"])
		hub.queue_free()
		await _settle()
	root.size = Vector2i(390, 844)

	# My list: open a player, tap the mark, see it on his row, tap it off.
	var player: Dictionary = (_state.my_list as Array)[3]
	var id := str(player["id"])
	var ls: Control = load("res://scenes/ListScene.tscn").instantiate()
	root.add_child(ls)
	await _settle()
	var full: Button = null
	for t in ls.find_children("*", "Button", true, false):
		if (t as Button).text == "Full list":
			full = t
	_check(full != null, "My list has its Full list tab on a phone")
	if full != null:
		await _press(full, "Full list")
		await _settle()
	var row: Button = ls.find_child("Row_" + id, true, false)
	_check(row != null and ls.find_child("RowUntouchable", true, false) == null, "No one is marked to begin with")
	if row == null:
		ls.queue_free()
		return
	await _press(row, "a player's row")
	await _settle()
	var mark: Button = ls.find_child("Untouchable", true, false)
	_check(mark != null and mark.text == "Mark untouchable", "His profile offers Mark untouchable")
	var what: Control = ls.find_child("Detail_Untouchable", true, false)
	_check(what != null and _ink(what) == _text_ink() and what.get_parent() == mark.get_parent(),
			"What the mark does is a fact in full ink, in the block with the button, not under Ratings")
	if mark != null:
		await _press(mark, "Mark untouchable")
		await _settle()
	_check(_state.is_untouchable(id), "A tap marks him untouchable")
	var on_row: Control = ls.find_child("Row_" + id, true, false)
	_check(on_row != null and on_row.find_child("RowUntouchable", true, false) != null,
			"His row on My list carries the mark")
	var off: Button = ls.find_child("Untouchable", true, false)
	_check(off != null and off.text == "Remove untouchable mark", "The profile now offers to remove the mark")
	if off != null:
		await _press(off, "Remove untouchable mark")
		await _settle()
	_check(not _state.is_untouchable(id) and ls.find_child("RowUntouchable", true, false) == null,
			"A second tap takes the mark off, and the row loses it")
	ls.queue_free()
	await _settle()


## UiKit's body ink (loaded when asked: UiKit needs the GameDB autoload).
func _text_ink() -> Color:
	return load("res://scripts/ui/UiKit.gd").TEXT


## The ink a line is set in, plain or with names in ink.
func _ink(c: Control) -> Color:
	if c is RichTextLabel:
		return (c as RichTextLabel).get_theme_color("default_color")
	return c.get_theme_color("font_color")


## The words of a line, whether a plain label or one with names in ink.
func _line_text(c: Control) -> String:
	if c == null:
		return ""
	if c.has_meta("plain"):
		return str(c.get_meta("plain"))
	return str(c.get("text"))


func _has_sandringham(draft) -> bool:
	for p in draft.pool:
		if str(p["club"]) == "Sandringham Dragons":
			return true
	return false


func _junior_filter_ok(found: bool) -> bool:
	# The 2026 class always contains Sandringham Dragons kids; generated-only
	# pools (no CSV) legitimately lack that name.
	return found or _db.draftees.is_empty()


func _snapshot(ui: Control) -> Dictionary:
	var draft = _state.draft
	var out := {
		"history": draft.pick_history.duplicate(true),
		"count": draft.count(),
		"counts": draft.role_counts(),
		"pick_index": draft.pick_index,
	}
	for key in ["_role", "_search", "_sort", "_club_filter", "_available_only",
			"_advanced_open", "_history_club"]:
		out[key] = ui.get(key)
	return out


func _check_layout(ui: Control, label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var margin: Control = ui.get("_margin")
	_check(viewport.grow(1).encloses(margin.get_global_rect()), label + " has no page overflow")
	for node_name in ["DraftWorkspace", "StartSeason", "DraftPool", "DraftActivity",
			"LatestRivalPick"]:
		var node: Control = ui.find_child(node_name, true, false)
		if node != null and node.is_visible_in_tree():
			_check(viewport.grow(1).encloses(node.get_global_rect()), label + ": " + node_name + " fits")
	for prefix in ["Position_", "Tab_", "SideTab_", "Filter_"]:
		for node in ui.find_children(prefix + "*", "Button", true, false):
			if node.is_visible_in_tree():
				_check(node.size.y >= 44, label + ": " + str(node.name) + " is touch-sized")


## A finger's tap on b where it sits on screen (tests/tap.gd), checked; if
## something else takes the tap, the press goes through the handler so the
## rest of the flow is still tested.
func _press(b: Button, what: String) -> void:
	var why: String = await Tap.tap(b)
	_check(why == "", "A finger's tap reaches %s (%s)" % [what, why if why != "" else "it did"])
	if why != "" and is_instance_valid(b):
		b.emit_signal("pressed")


func _settle() -> void:
	for i in range(5):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)
