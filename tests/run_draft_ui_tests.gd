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
		if str(candidate["role"]) == "DEF":
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
	print("Draft UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## Inspecting a player is read-only; only the explicit Draft button picks.
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
	_check(ovr != null and (ovr.get_child(0) as Label).text == str(int(p["overall"]))
			and (ovr.get_child(1) as Label).text == "OVR"
			and pot != null and (pot.get_child(0) as Label).text == str(int(p.get("potential", p["overall"]))),
			"His OVR and POT are shown")
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
			if ui.find_child("Trait_" + str(t), true, false) == null:
				all_there = false
		_check(all_there, "Each of his traits is shown and explained")
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
	_check(status != null and status.text == "Drafted #%d - %s." % [int(rival["pick"]), _db.club_name(str(rival["club"]))],
			"A rival's pick stays inspectable and shows who took him (%s)" % (status.text if status else "-"))
	_check(blocked != null and blocked.text.begins_with("Drafted #") and ui.find_child("DetailDraft", true, false) == null,
			"...and cannot be drafted again")
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
	var dear: Dictionary = rows[3]
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
	ui.call("_open_player", str(rows[5]["id"]))
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
	ui.call("_open_player", str(rows[6]["id"]))
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
