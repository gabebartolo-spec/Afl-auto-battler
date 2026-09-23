extends SceneTree
## godot --headless --path . --script tests/run_career_ui_tests.gd
## Main menu save flow (Continue Career, New Career confirmation) and the
## Android back button / Escape routing, driven through the real scenes.
## Classes are reached through load() and autoload nodes: a --script runner
## compiles before the autoloads exist.

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _settle() -> void:
	for i in range(4):
		await process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)


func _screen_text() -> String:
	var out := []
	_texts(current_scene, out)
	return " | ".join(out)


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	# Never touch a real career save or settings file from a test run.
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_state.delete_saved_career()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))

	_check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)),
			"Android back does not quit the app by default")

	# --- a fresh install: no Continue button --------------------------------
	_state.reset()
	_router.to_main_menu(false)
	await _settle()
	_check(current_scene.find_child("ContinueCareer", true, false) == null,
			"No Continue Career without a save")

	# --- a saved career shows Continue, and it loads -------------------------
	_state.start_season("SYD", _db.club_list("SYD"))
	_state.advance()
	_state.advance()
	_check(_state.save_career(), "The career saves")
	_state.reset()
	_router.to_main_menu(false)
	await _settle()
	var cont: Button = current_scene.find_child("ContinueCareer", true, false)
	_check(cont != null, "Continue Career appears when a save exists")
	_check(_screen_text().contains("Round 3"), "The menu shows where the save is up to")
	if cont != null:
		cont.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub", "Continue Career opens the season hub")
	_check(_state.season != null and _state.season.round_index == 2, "The saved round is loaded")
	_check(_state.my_club == "SYD", "The saved club is loaded")

	# --- back on the hub: results popup first, then the menu ----------------
	current_scene.call("_on_sim_round")
	await _settle()
	var overlay = current_scene.get("_results_overlay")
	_check(overlay != null and is_instance_valid(overlay), "Sim Round shows the results popup")
	_router.handle_back(true)
	await _settle()
	overlay = current_scene.get("_results_overlay")
	_check(_router.current() == "hub" and (overlay == null or not is_instance_valid(overlay)),
			"Back closes the results popup and stays on the hub")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "main", "Back from the hub goes to the main menu")
	_check(_state.season != null, "Leaving by back keeps the career in memory")
	_check(current_scene.find_child("ResumeCareer", true, false) != null,
			"The menu offers Resume Season after backing out")

	# --- back on other screens ------------------------------------------------
	_router.go("hub")
	await _settle()
	_router.go("ladder")
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "hub", "Escape on the ladder returns to the hub")

	# --- team selection --------------------------------------------------------
	_router.go("selection")
	await _settle()
	_check(current_scene.find_child("AutoPick", true, false) != null, "The team screen opens")
	var mine: Button = current_scene.find_child("MySelection", true, false)
	mine.emit_signal("pressed")
	await _settle()
	_check(not _state.my_selection().is_empty(), "My selection starts from this week's side")
	var first_mid := str(_state.my_selection()["MID"][0])
	var out_btn = current_scene.find_child("Move_" + first_mid, true, false)
	out_btn = out_btn.find_child("To_OUT", true, false) if out_btn != null else null
	_check(out_btn != null, "Each player has move buttons")
	if out_btn != null:
		out_btn.emit_signal("pressed")
		await _settle()
	_check(not (_state.my_selection()["MID"] as Array).has(first_mid), "Out removes him from the side")
	var auto_btn: Button = current_scene.find_child("AutoPick", true, false)
	auto_btn.emit_signal("pressed")
	await _settle()
	_check(_state.my_selection().is_empty(), "Auto-pick switches selection back to automatic")
	_router.handle_back(true)
	await _settle()

	# --- training: one-time intro, stat guide, plan picker -------------------
	_router.go("training")
	await _settle()
	_check(current_scene.find_child("TrainingIntro", true, false) != null,
			"The training intro shows on the first visit")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training"
			and current_scene.find_child("TrainingIntro", true, false) == null,
			"Back closes the intro and stays on Training")
	var guide_btn: Button = current_scene.find_child("StatGuideButton", true, false)
	guide_btn.emit_signal("pressed")
	await _settle()
	var guide = current_scene.find_child("StatGuide", true, false)
	_check(guide != null and guide.find_child("Guide_star", true, false) != null
			and guide.find_child("Guide_discipline", true, false) != null,
			"The stat guide opens with every stat, star power and discipline included")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training" and current_scene.find_child("StatGuide", true, false) == null,
			"Back closes the stat guide")
	var first: Dictionary = _state.my_list[0]
	current_scene.call("_open_player", str(first["id"]))
	await _settle()
	var picker: OptionButton = current_scene.find_child("PlayerPlan", true, false)
	var target := -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i)) == "focus_marking":
			target = i
	picker.select(target)
	picker.emit_signal("item_selected", target)
	await _settle()
	_check(_state.plan_for(first) == "focus_marking", "The player plan picker sets his plan")
	_router.handle_back(true)
	await _settle()
	_router.go("training")
	await _settle()
	_check(current_scene.find_child("TrainingIntro", true, false) == null,
			"The intro does not show again")
	_router.handle_back(true)
	await _settle()

	# --- a live match swallows back until full time --------------------------
	_check(_state.prepare_interactive_match(), "A live match is prepared")
	_router.go("match")
	await _settle()
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "match", "Back cannot abandon a live match")
	current_scene.call("_on_skip")
	for i in range(30):
		await process_frame
	_check(_state.pending_match.is_empty(), "Skip still finishes the match")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "After full time, back returns to the hub")

	# --- New Career asks before replacing a career ---------------------------
	_router.to_main_menu(false)
	await _settle()
	var new_btn: Button = current_scene.find_child("NewCareer", true, false)
	new_btn.emit_signal("pressed")
	await _settle()
	var confirm = current_scene.find_child("ConfirmNewCareer", true, false)
	_check(confirm != null, "New Career asks for confirmation over an existing career")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "main"
			and current_scene.find_child("ConfirmNewCareer", true, false) == null,
			"Back cancels the confirmation and stays on the menu")
	_check(_state.season != null and _state.has_saved_career(),
			"Cancelling keeps the career and the save")
	new_btn = current_scene.find_child("NewCareer", true, false)
	new_btn.emit_signal("pressed")
	await _settle()
	confirm = current_scene.find_child("ConfirmNewCareer", true, false)
	if confirm != null:
		confirm.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "draft", "Confirming starts a new career at the draft")
	_check(not _state.has_saved_career(), "The replaced save is removed")
	_check(_state.season == null and _state.draft != null, "The new career starts empty")

	# --- Escape on the main menu never quits ---------------------------------
	_router.to_main_menu(false)
	await _settle()
	current_scene.call("_show_help")
	await _settle()
	var menu_guide: Button = current_scene.find_child("MenuStatGuide", true, false)
	menu_guide.emit_signal("pressed")
	await _settle()
	_check(current_scene.find_child("StatGuide", true, false) != null,
			"How It Works opens the stat guide")
	_router.handle_back(false)
	await _settle()
	_check(current_scene.find_child("StatGuide", true, false) == null and _router.current() == "main",
			"Escape closes the guide on the menu")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main", "Escape on the main menu does nothing")

	_state.delete_saved_career()
	print("Career UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
