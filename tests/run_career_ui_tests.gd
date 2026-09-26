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

	# --- difficulty for new careers ---------------------------------------------
	var hard_btn: Button = current_scene.find_child("Difficulty_hard", true, false)
	_check(hard_btn != null, "The menu offers a difficulty choice")
	if hard_btn != null:
		hard_btn.emit_signal("pressed")
		await _settle()
	_check(_state.new_career_difficulty() == "hard", "Picking Hard sets the next career's difficulty")
	var normal_btn: Button = current_scene.find_child("Difficulty_normal", true, false)
	if normal_btn != null:
		normal_btn.emit_signal("pressed")
		await _settle()
	_check(_state.new_career_difficulty() == "normal" and not hard_btn.button_pressed,
			"Only the chosen difficulty shows as picked")

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
	_check(current_scene.find_child("BoardLine", true, false) != null, "The hub shows the board's goal")
	_state.week_event = load("res://scripts/sim/ClubLife.gd")._fans()
	_router.go("hub")
	await _settle()
	var ev_btn: Button = current_scene.find_child("Event_0", true, false)
	_check(ev_btn != null, "This week's decision shows on the hub")
	if ev_btn != null:
		ev_btn.emit_signal("pressed")
		await _settle()
	_check(not _state.week_event_pending() and _screen_text().contains("members loved it"),
			"Answering it shows what happened")

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
		if str(picker.get_item_metadata(i)) == "manual":
			target = i
	picker.select(target)
	picker.emit_signal("item_selected", target)
	await _settle()
	_check(_state.plan_for(first) == "manual", "The player plan picker sets his plan")
	_check(current_scene.find_child("ManualWarning", true, false) != null,
			"Manual is flagged as paused development in the player view")
	var adv: Button = current_scene.find_child("AdvancedToggle", true, false)
	_check(adv != null and adv.text.begins_with("Stats and hand training"),
			"Hand training sits behind one button in the player view")
	if adv != null:
		adv.emit_signal("pressed")
		await _settle()
	var adv2: Button = current_scene.find_child("AdvancedToggle", true, false)
	_check(adv2 != null and adv2.text.begins_with("Hide"), "The button opens the stats and hand training")
	# Back inside a player detail steps out to the list, not out of Training.
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "training",
			"Back on a player detail stays on Training")
	_check(current_scene.find_child("PlayerPlan", true, false) == null
			and current_scene.find_child("TrainingRows", true, false) != null,
			"Back on a player detail returns to the list view")
	# The top-bar back steps out of the detail the same way.
	current_scene.call("_open_player", str(first["id"]))
	await _settle()
	var top_back: Button = current_scene.find_child("TopBarBack", true, false)
	_check(top_back != null, "The training top bar has a back button")
	if top_back != null:
		top_back.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "training"
			and current_scene.find_child("TrainingRows", true, false) != null,
			"The top-bar back steps out of the detail, not out of Training")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub",
			"Once the detail is closed, back leaves Training for the previous screen")
	_router.go("training")
	await _settle()
	_check(current_scene.find_child("TrainingIntro", true, false) == null,
			"The intro does not show again")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "Back from a plain Training list leaves the screen")

	# --- a live match swallows back until full time --------------------------
	_check(_state.prepare_interactive_match(), "A live match is prepared")
	_router.go("match")
	await _settle()
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "match", "Back cannot abandon a live match")
	_check(current_scene.find_child("RotationPicker", true, false) != null
			and current_scene.find_child("LegsView", true, false) != null
			and current_scene.find_child("PlanPicker", true, false) != null,
			"The coach box offers gameplan, rotations and a legs report")
	# Play quarters until the match stops for a coach's call, then answer it.
	var sim = _state.pending_sim
	var start_btn: Button = current_scene.find_child("StartQuarter", true, false)
	start_btn.emit_signal("pressed")
	await _settle()
	var guard := 0
	while sim.pending_moment.is_empty() and sim.current_quarter <= 4 and guard < 6:
		guard += 1
		if not sim.quarter_in_progress():
			current_scene.call("_simulate_next_quarter", {"gameplan": "balanced"})
			await _settle()
	var had_moment: bool = not sim.pending_moment.is_empty()
	_check(had_moment, "A live match stops for a coach's call")
	if had_moment:
		current_scene.call("_show_moment")
		await _settle()
		var card = current_scene.find_child("MomentCard", true, false)
		var pick: Button = card.find_child("Moment_0", true, false) if card != null else null
		_check(pick != null, "The call shows as a card with its options")
		var before: int = sim.moments.size()
		if pick != null:
			pick.emit_signal("pressed")
			await _settle()
		_check(sim.moments.size() == before + 1 and current_scene.find_child("MomentCard", true, false) == null,
				"Choosing an option resolves the call and play goes on")
	current_scene.call("_on_skip")
	for i in range(30):
		await process_frame
	_check(_state.pending_match.is_empty(), "Skip still finishes the match")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "After full time, back returns to the hub")
	_check(not (_state.last_match.get("moments", []) as Array).is_empty(),
			"The played match keeps its calls for the readout")

	# --- off-season: trades & contracts ----------------------------------------
	var season = _state.season
	season.round_index = season.fixture.size()
	_state.ensure_finals()
	while not season.is_season_over():
		_state.advance()
	_router.go("hub")
	await _settle()
	_check(_screen_text().contains("Trades & Contracts"), "The hub offers Trades & Contracts after the season")
	var more: Button = current_scene.find_child("NewsMore", true, false)
	_check(more != null, "The hub shows the league news")
	if more != null:
		more.emit_signal("pressed")
		await _settle()
	_check(current_scene.find_child("NewsFeed", true, false) != null
			and _screen_text().contains("premiers"), "More opens the full news feed")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("NewsFeed", true, false) == null,
			"Back closes the news feed and stays on the hub")
	_router.go("offseason")
	await _settle()
	_check(_screen_text().contains("Out of contract"), "The contracts tab lists who is out of contract")
	for tab in ["Tab_agents", "Tab_trade"]:
		var tb: Button = current_scene.find_child(tab, true, false)
		tb.emit_signal("pressed")
		await _settle()
	var theirs = null
	var mine_pick = null
	for n in current_scene.find_children("Their_*", "Button", true, false):
		theirs = n
		break
	for n in current_scene.find_children("Mine_*", "Button", true, false):
		mine_pick = n
		break
	_check(theirs != null and mine_pick != null, "The trade tab lists both sides")
	if theirs != null and mine_pick != null:
		theirs.emit_signal("pressed")
		await _settle()
		mine_pick = current_scene.find_children("Mine_*", "Button", true, false)[0]
		mine_pick.emit_signal("pressed")
		await _settle()
	var verdict = current_scene.find_child("TradeVerdict", true, false)
	_check(verdict != null and not str(verdict.text).contains("You give: -"),
			"Picking players shows the other club's verdict")
	_router.handle_back(true)
	await _settle()

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
