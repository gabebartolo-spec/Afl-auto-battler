extends SceneTree
## godot --headless --path . --script tests/run_draft_ui_tests.gd
## Layout/state regressions using actual Godot containers. Browser/device touch
## smoke tests are documented separately in tests/README.md.

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
	_db = root.get_node("GameDB")
	_state.reset()
	_state.draft = Draft.new(_db.all_players_sorted(), _db.CLUB_ORDER.duplicate(), 12345)
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	ui.call("_on_club_chosen", "COL")
	await _settle()

	var defender := {}
	for candidate in _state.draft.board("DEF", "", "", "overall", true):
		if str(candidate["role"]) == "DEF":
			defender = candidate
			break
	ui.call("_on_pick", defender)
	_check(_state.draft.role_counts()["DEF"] == 1, "Pick updates the user's position count")
	_check(_state.draft.position_needs()["DEF"] == 4, "Pick updates position needs")
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

	# No-results recovery resets controls as well as their backing values.
	ui.call("_clear_filters")
	await _settle()
	_check(ui.get("_search") == "", "Clear filters resets search")
	_check(ui.get("_role") == "", "Clear filters resets position")
	_check(ui.get("_available_only") == true, "Clear filters restores availability")
	var finish: Button = ui.find_child("StartSeason", true, false)
	_check(finish.disabled, "Season cannot start before a valid draft is complete")

	# Reopening uses the same draft; it must not replay AI turns.
	var history: Array = _state.draft.pick_history.duplicate(true)
	root.remove_child(ui)
	ui.queue_free()
	ui = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	_check(ui.get("_phase") == "board", "Reopening resumes the board, not club selection")
	_check(_state.draft.pick_history == history, "Reopening never makes additional picks")
	_check(_state.draft.count() == 1, "Reopening preserves the user's roster")
	ui.queue_free()
	print("Draft UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _snapshot(ui: Control) -> Dictionary:
	var draft: Draft = _state.draft
	var out := {
		"history": draft.pick_history.duplicate(true),
		"count": draft.count(),
		"counts": draft.role_counts(),
		"remaining": draft.remaining(),
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


func _settle() -> void:
	# Resize, deferred rebuild, container sorting, and scroll restoration.
	for i in range(5):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
