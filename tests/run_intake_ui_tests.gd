extends SceneTree
## godot --headless --path . --script tests/run_intake_ui_tests.gd
## Intake-draft presentation regressions on the shared DraftScene: it must
## open straight to the board in intake mode, keep every control on-viewport
## and touch-sized across ten viewports, survive filters and rotation, and
## hand off to a fresh season when finished.

const VIEWPORTS := [
	Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568),
	Vector2i(360, 800), Vector2i(430, 932), Vector2i(768, 1024),
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
	_state.start_season("COL", _db.club_list("COL"))
	var season = _state.season
	season.round_index = season.fixture.size()  # The H&A is done; draft time.
	var opened: bool = _state.begin_intake_draft()
	_check(opened, "begin_intake_draft opens after the home-and-away")
	var draft = _state.draft
	_check(bool(draft.intake_mode), "GameState built an intake draft")

	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	_check(ui.get("_phase") == "board", "The intake draft resumes straight to the board")
	var cap: Label = ui.find_child("SalaryCap", true, false)
	_check(cap != null and cap.text.contains("ROUNDS"), "Intake swaps the cap line for rounds")

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
	if draft.is_user_turn():
		var signed = draft.board("", "", "", "overall", true)[0]
		ui.call("_on_pick", signed)
		await _settle()
		_check(draft.count() >= 1, "Signing through the UI records the pick")

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
	_check(finish.text.contains("FINISH"), "The action button is 'Finish draft' in intake mode")
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
	_check(int(_state.season_year) == 2027, "The career advanced to 2027")
	var new_ids := {}
	for p in (_state.league_lists["COL"] as Array):
		new_ids[str(p["id"])] = true
	var all_landed := true
	for id in signed_ids:
		if not new_ids.has(id):
			all_landed = false
	_check(all_landed, "Every intake signing is on the new list")
	ui.queue_free()
	print("Intake UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


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


func _settle() -> void:
	for i in range(5):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
