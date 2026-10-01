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

	# --- the menu is the title and a few actions, no setup -------------------
	_check(current_scene.find_child("Difficulty_hard", true, false) == null
			and current_scene.find_child("NameMode_real", true, false) == null,
			"The menu itself carries no setup controls")
	_check(not _screen_text().contains("players ·") and not _screen_text().contains("Quit"),
			"No data line or Quit on the menu")
	_check(current_scene.find_child("MenuHelp", true, false) != null
			and current_scene.find_child("MenuSettings", true, false) != null,
			"How to play and Settings are on the menu")

	# --- settings: player names apply at once --------------------------------
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	var real_setting: Button = current_scene.find_child("SettingsNames_real", true, false)
	_check(real_setting != null, "Settings offers player names")
	if real_setting != null:
		real_setting.emit_signal("pressed")
		await _settle()
	_check(_state.show_real_names, "Choosing Real in Settings shows real names straight away")
	_check(OS.has_feature("web") or current_scene.find_child("QuitGame", true, false) != null,
			"Quit lives in Settings")
	current_scene.find_child("SettingsNames_generated", true, false).emit_signal("pressed")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("Settings", true, false) == null
			and not _state.show_real_names, "Back closes Settings")

	# --- new career setup: names and difficulty, applied only on start -------
	current_scene.find_child("NewCareer", true, false).emit_signal("pressed")
	await _settle()
	var hard_btn: Button = current_scene.find_child("Difficulty_hard", true, false)
	_check(hard_btn != null and current_scene.find_child("NameMode_real", true, false) != null,
			"New career asks for player names and difficulty")
	if hard_btn != null:
		hard_btn.emit_signal("pressed")
		await _settle()
	_check(_state.new_career_difficulty() == "normal", "A pick changes nothing before the career starts")
	current_scene.find_child("DifficultyInfo", true, false).emit_signal("pressed")
	await _settle()
	var note: Label = current_scene.find_child("DifficultyNote", true, false)
	_check(note != null and note.visible and note.text == str(_state.DIFFICULTIES["hard"]["text"]),
			"The ? explains the picked difficulty on request")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("NewCareerSetup", true, false) == null
			and _state.new_career_difficulty() == "normal", "Back leaves the setup without changing anything")
	current_scene.find_child("NewCareer", true, false).emit_signal("pressed")
	await _settle()
	current_scene.find_child("Difficulty_hard", true, false).emit_signal("pressed")
	current_scene.find_child("NameMode_real", true, false).emit_signal("pressed")
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	_check(_router.current() == "draft", "Starting the career goes on to choosing a club")
	_check(_state.new_career_difficulty() == "hard" and _state.difficulty == "hard"
			and _state.show_real_names, "The career starts with the picks made")
	_state.set_new_career_difficulty("normal")
	_state.set_show_real_names(false)
	_state.reset()

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
	# One player well above his season, one well below (GameState.player_form).
	var hot_id := str(_state.my_list[0]["id"])
	var cold_id := str(_state.my_list[1]["id"])
	_state.form_log[hot_id] = {"last": [95, 95, 95], "n": 10, "sum": 500}
	_state.form_log[cold_id] = {"last": [15, 15, 15], "n": 10, "sum": 600}
	var coaching: Button = current_scene.find_child("HubCoaching", true, false)
	_check(coaching != null, "Coaching is on the hub's bottom row")
	if coaching != null:
		coaching.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "coaching" and current_scene.find_child("BoardConfidence", true, false) != null
			and current_scene.find_child("HowWePlay", true, false) != null
			and current_scene.find_child("StaffLine_SA", true, false) != null,
			"Coaching shows how we play, the board and the staff")
	# List profile: six strengths as words; a tap says what one is and who leads it.
	var lp: Node = current_scene.find_child("ListProfile", true, false)
	var lp_rows: Array = lp.find_children("Profile_*", "Button", true, false) if lp != null else []
	_check(lp_rows.size() == 6 and lp.find_child("Profile_finishing", true, false) != null,
			"Coaching opens on the list profile, six strengths with Finishing (%d)" % lp_rows.size())
	var lp_text := ""
	for l in (lp.find_children("*", "Label", true, false) if lp != null else []):
		if (l as Label).is_visible_in_tree():
			lp_text += (l as Label).text + " "
	var digits := false
	for c in lp_text:
		digits = digits or (c >= "0" and c <= "9")
	_check(not digits and not lp_text.to_lower().contains("recommend") and not lp_text.to_lower().contains("should"),
			"The profile is words, with no scores and no advice")
	_check(lp_rows.all(func(b): return (b as Button).size.y >= 44), "Each strength is a thumb-sized tap")
	if lp_rows.size() == 6:
		var detail: Label = (lp_rows[0] as Node).get_parent().find_child("Detail", false, false)
		(lp_rows[0] as Button).emit_signal("pressed")
		await _settle()
		_check(detail != null and detail.visible and detail.text.contains("Leading it: "),
				"A tap says what the strength is and who leads it")
	# Recent games: who is in and out of form, by name - no ratings, no "his".
	var form_box: Node = current_scene.find_child("Form", true, false)
	var form_text := ""
	for l in (form_box.find_children("*", "Label", true, false) if form_box != null else []):
		form_text += (l as Label).text + "\n"
	var form_digits := false
	for c in form_text:
		form_digits = form_digits or (c >= "0" and c <= "9")
	_check(form_text.contains("In good form") and form_text.contains("In poor form")
			and form_box.find_child("Form_hot_" + hot_id, true, false) != null
			and form_box.find_child("Form_cold_" + cold_id, true, false) != null,
			"Recent games says who is in good and poor form, by name")
	_check(not form_digits and not form_text.contains(" his ") and not form_text.contains("his season"),
			"Recent games shows no rating numbers and no dangling 'his' (%s)" % form_text.replace("\n", " / "))
	var plan: Button = current_scene.find_child("ClubPlan_contest", true, false)
	if plan != null:
		plan.emit_signal("pressed")
		await _settle()
	_check(_state.club_plan == "contest" and _state.season.plans.get("SYD", "") == "contest",
			"Choosing a game plan makes it the club's plan")
	_state.set_club_plan("balanced")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "Back returns to the hub")
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

	# --- Sim round asks first: it plays your match without you --------------
	_state.set_confirm_sim_round(true)
	_router.go("hub")
	await _settle()
	var r0: int = _state.season.round_index
	var press_sim := func() -> void:
		var b: Button = current_scene.find_child("SimRound", true, false)
		if b != null:
			b.emit_signal("pressed")
	press_sim.call()
	await _settle()
	_check(current_scene.find_child("SimConfirm", true, false) != null and _state.season.round_index == r0,
			"Sim round asks before playing your match")
	_check(_screen_text().contains("Simulate Round %d?" % (r0 + 1)), "The question names the round")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub" and current_scene.find_child("SimConfirm", true, false) == null
			and _state.season.round_index == r0, "Back closes the question and sims nothing")
	press_sim.call()
	await _settle()
	current_scene.find_child("SimConfirmCancel", true, false).emit_signal("pressed")
	await _settle()
	_check(_state.season.round_index == r0, "Cancel sims nothing")
	press_sim.call()
	await _settle()
	current_scene.find_child("SimConfirmNever", true, false).emit_signal("pressed")
	await _settle()
	var cfg := ConfigFile.new()
	cfg.load(_state.settings_path)
	_check(_state.season.round_index == r0 + 1 and not _state.confirm_sim_round()
			and cfg.get_value("ui", "confirm_sim_round", true) == false,
			"Don't ask again sims the round and remembers the choice")
	_router.handle_back(true)
	await _settle()
	press_sim.call()
	await _settle()
	_check(current_scene.find_child("SimConfirm", true, false) == null and _state.season.round_index == r0 + 2,
			"After Don't ask again, Sim round goes straight ahead")
	_router.handle_back(true)
	await _settle()
	_state.set_confirm_sim_round(true)

	# --- a simmed match: headlined, and reviewable at full time -------------
	current_scene.call("_on_sim_round")
	await _settle()
	var popup = current_scene.get("_results_overlay")
	_check(popup != null and popup.find_child("MyVerdict", true, false) != null,
			"Your result leads the round popup")
	var round_before: int = _state.season.round_index
	var xp_before := 0
	for p in _state.my_list:
		xp_before += int(p.get("xp", 0))
	var injuries_before := str(_state.last_injuries)
	var log_before: int = _state.season_log.size()
	var rv: Button = popup.find_child("ReviewMatch", true, false) if popup != null else null
	_check(rv != null and rv.size.y >= 44, "Review match is one thumb-sized tap")
	if rv != null:
		rv.emit_signal("pressed")
		await _settle()
	var ft = current_scene.find_child("FullTime", true, false)
	_check(_router.current() == "match" and ft != null, "Review match opens the full-time summary")
	for n in ["Verdict", "MatchFactors", "BestPlayers", "YourWeek", "ReviewTab_stats"]:
		_check(ft != null and ft.find_child(n, true, false) != null, "The review shows %s" % n)
	var ft_text := ""
	if ft != null:
		for l in ft.find_children("*", "Label", true, false):
			ft_text += str(l.text) + "\n"
	_check(not ft_text.contains("rose in OVR") and not ft_text.contains("in the reserves"),
			"Full time does not repeat the training result; Training has it")
	var sb = ft.find_child("ReviewTab_stats", true, false) if ft != null else null
	if sb != null:
		sb.emit_signal("pressed")
		await _settle()
		var me := 0 if str(_state.last_match["home"]) == _state.my_club else 1
		var rows := current_scene.find_children("PlayerRow_*", "Button", true, false)
		_check(rows.size() == (_state.last_match["roster"][me] as Array).size(),
				"Match stats lists every player who played (%d)" % rows.size())
		_router.handle_back(true)
		await _settle()
	var ft_cont = current_scene.find_child("FullTimeContinue", true, false)
	if ft_cont != null:
		ft_cont.emit_signal("pressed")
		await _settle()
	var xp_after := 0
	for p in _state.my_list:
		xp_after += int(p.get("xp", 0))
	_check(_router.current() == "hub", "Continue from the review returns to the hub")
	_check(_state.season.round_index == round_before and xp_after == xp_before
			and str(_state.last_injuries) == injuries_before and _state.season_log.size() == log_before,
			"Reviewing plays nothing again: same round, XP, injuries and results")
	var again: Button = current_scene.find_child("ReviewLastMatch", true, false)
	_check(again != null, "The hub keeps a way back to your last match")
	# It survives a save and reload.
	_state.save_career()
	_state.load_career()
	_router.replace("hub")
	await _settle()
	again = current_scene.find_child("ReviewLastMatch", true, false)
	_check(again != null and _state.last_match.has("players"), "Your last match can still be reviewed after a reload")
	if again != null:
		again.emit_signal("pressed")
		await _settle()
		_check(current_scene.find_child("BestPlayers", true, false) != null, "...and opens at full time")
		_router.handle_back(true)
		await _settle()
		if _router.current() == "match":
			current_scene.find_child("FullTimeContinue", true, false).emit_signal("pressed")
			await _settle()

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
	# Settings can turn the Sim round question off and back on.
	current_scene.call("_show_settings")
	await _settle()
	var off_btn: Button = current_scene.find_child("SettingsSimConfirm_off", true, false)
	var on_btn: Button = current_scene.find_child("SettingsSimConfirm_on", true, false)
	_check(off_btn != null and on_btn != null, "Settings has Confirm before simming round")
	if off_btn != null and on_btn != null:
		off_btn.emit_signal("pressed")
		_check(not _state.confirm_sim_round(), "...which can be switched off")
		on_btn.emit_signal("pressed")
		_check(_state.confirm_sim_round(), "...and back on")
	current_scene.call("_close_settings")
	await _settle()

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
	var slot_btn = current_scene.find_child("Slot_" + first_mid, true, false)
	if slot_btn != null:
		slot_btn.emit_signal("pressed")
		await _settle()
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
	var picker: Node = current_scene.find_child("PlayerPlan", true, false)
	_check(picker != null and current_scene.find_children("*", "OptionButton", true, false).is_empty(),
			"Plans are taps, not a dropdown")
	var plan_btns := picker.find_children("PlayerPlan_*", "Button", false, false) if picker != null else []
	_check(plan_btns.size() == _state.plans_for(first).size(), "Every plan he can follow is shown (%d)" % plan_btns.size())
	var small_plan := false
	for b in plan_btns:
		if b.size.y < 44:
			small_plan = true
	_check(not small_plan, "Every plan is a thumb-sized tap")
	var manual_btn: Button = picker.find_child("PlayerPlan_manual", false, false) if picker != null else null
	if manual_btn != null:
		manual_btn.emit_signal("pressed")
	await _settle()
	_check(_state.plan_for(first) == "manual", "Tapping a plan sets his plan")
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
	# Position tabs list everyone who can play there (Ratings.plays_role, the
	# draft's and selection's rule); All lists each player once.
	var dual := {}
	for p in _state.my_list:
		var r2 := str(p.get("role2", ""))
		if r2 != "" and r2 != str(p["role"]):
			dual = p
			break
	_check(not dual.is_empty(), "The list has a dual-position player to test with")
	if not dual.is_empty():
		var tid := "Trainee_" + str(dual["id"])
		for role in [str(dual["role"]), str(dual["role2"])]:
			current_scene.call("_set_role", role)
			await _settle()
			_check(current_scene.find_child(tid, true, false) != null,
					"A %s/%s player is under the %s tab" % [dual["role"], dual["role2"], role])
		current_scene.call("_set_role", "")
		await _settle()
		var seen := 0
		for n in current_scene.find_children(tid, "", true, false):
			seen += 1
		_check(seen == 1, "All lists him once")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "hub", "Back from a plain Training list leaves the screen")

	# --- back after coming back: hub -> My list -> Training -> back -> back ----
	# Router.back() used to leave the screen it returned to on the stack twice,
	# so the next back stayed put (My list's back arrow "did nothing").
	_state.my_list[0]["club"] = "COL" if _state.my_club != "COL" else "GEE"
	_router.go("list")
	await _settle()
	_router.go("training")
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "list" and _router.stack.count("list") == 1,
			"Back returns to My list without stacking it twice")
	# Everyone on My list wears your club's colours, whatever club he came
	# from (a league re-draft leaves his source club in p["club"]).
	current_scene.set("_pane", "list")
	current_scene.call("_build")
	await _settle()
	var mine_col: Color = (root.get_node("GameDB").club_colours(_state.my_club) as Array)[0]
	var guernseys: Array = current_scene.find_children("Guernsey", "PanelContainer", true, false)
	var all_ours := not guernseys.is_empty()
	for g in guernseys:
		var g_sb := (g as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		all_ours = all_ours and g_sb != null and g_sb.bg_color.is_equal_approx(mine_col)
	_check(all_ours, "My list: every guernsey is your club's (%d rows)" % guernseys.size())
	var list_back: Button = current_scene.find_child("TopBarBack", true, false)
	_check(list_back != null, "My list has a back arrow")
	if list_back != null:
		list_back.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub", "Its back arrow then returns to the hub")

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
	_check(current_scene.find_children("Resign_*", "Button", true, false).is_empty(),
			"No one-tap re-signing: contracts go through talks")
	var talk = current_scene.find_child("Negotiate", true, false)
	_check(talk != null, "An out-of-contract player can be talked to")
	if talk != null:
		var payroll_before: int = _state.my_payroll()
		talk.emit_signal("pressed")
		await _settle()
		_check(current_scene.find_child("ContractTalks", true, false) != null
				and current_scene.find_child("MakeOffer", true, false) != null
				and _screen_text().contains("Cap room after this deal"),
				"Talks open a sheet with salary, term and the cap consequence")
		_check(_state.my_payroll() == payroll_before, "Opening talks signs nothing")
		_router.handle_back(true)
		await _settle()
		_check(_router.current() == "offseason" and current_scene.find_child("ContractTalks", true, false) == null,
				"Back closes the talks and stays on Trades & Contracts")
	for tab in ["Tab_agents", "Tab_trade"]:
		var tb: Button = current_scene.find_child(tab, true, false)
		tb.emit_signal("pressed")
		await _settle()
		if tab == "Tab_agents" and not _state.free_agents.is_empty():
			_check(current_scene.find_children("Sign_*", "Button", true, false).is_empty(),
					"No one-tap free-agent signing")
			var fa_talk = current_scene.find_child("FreeAgentTalks", true, false)
			_check(fa_talk != null, "A free agent can be talked to")
			if fa_talk != null:
				var list_before: int = _state.my_list.size()
				fa_talk.emit_signal("pressed")
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) != null
						and _screen_text().contains("Cap room after this deal")
						and _state.my_list.size() == list_before,
						"Free-agent talks open the same sheet and sign nothing")
				_router.handle_back(true)
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) == null, "Back closes free-agent talks")
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
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	var confirm = current_scene.find_child("ConfirmNewCareer", true, false)
	_check(confirm != null, "New Career asks for confirmation over an existing career")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "main"
			and current_scene.find_child("ConfirmNewCareer", true, false) == null
			and current_scene.find_child("NewCareerSetup", true, false) != null,
			"Back cancels the confirmation and stays on the setup")
	_check(_state.season != null and _state.has_saved_career(),
			"Cancelling keeps the career and the save")
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
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

	# --- Quick sim: hold Sim round -------------------------------------------
	_state.reset()
	_state.start_season("SYD", _db.club_list("SYD"))
	_state.set_confirm_sim_round(false)
	_router.go("hub")
	await _settle()
	var r_start: int = _state.season.round_index
	var sim_btn: Button = current_scene.find_child("SimRound", true, false)
	sim_btn.emit_signal("button_down")
	await create_timer(0.8).timeout
	await _settle()
	_check(current_scene.find_child("QuickSim", true, false) != null,
			"Holding Sim round opens the quick-sim menu, even with the question switched off")
	sim_btn.emit_signal("button_up")
	sim_btn.emit_signal("pressed")
	await _settle()
	_check(_state.season.round_index == r_start, "Letting go after a hold sims nothing")
	var qtext := _screen_text()
	_check(qtext.contains("Skip to Round %d" % (r_start + 5)) and qtext.contains("before the finals"),
			"Each option says where it lands, and that it stops before the finals")
	var four: Button = current_scene.find_child("QuickSimFour", true, false)
	if four != null:
		four.emit_signal("pressed")
		await _settle()
	_check(_state.season.round_index == r_start + 4, "Skip next 4 plays four rounds")
	_router.handle_back(true)
	await _settle()
	current_scene.call("_open_quick_sim")
	await _settle()
	var all_btn: Button = current_scene.find_child("QuickSimAll", true, false)
	if all_btn != null:
		all_btn.emit_signal("pressed")
		await _settle()
	_check(_state.season.is_regular_done() and _state.last_phase == "regular",
			"Skip to the end of the home and away stops before the finals")
	var qs_again: Dictionary = _state.quick_sim(4)
	_check(int(qs_again["played"]) == 0 and str(qs_again["reason"]) == "season_end",
			"Quick sim never plays a final")
	_router.handle_back(true)
	await _settle()
	current_scene.call("_open_quick_sim")
	await _settle()
	_check(current_scene.find_child("QuickSim", true, false) == null,
			"With the home and away done, there is nothing to quick sim")
	_state.set_confirm_sim_round(true)

	# --- Settings from the hub: speed, the menu, and deleting the career ----
	_router.go("hub")
	await _settle()
	var hub_settings: Button = current_scene.find_child("HubSettings", true, false)
	_check(hub_settings != null and hub_settings.size.y >= 44, "Settings is on the hub's top bar")
	if hub_settings != null:
		hub_settings.emit_signal("pressed")
		await _settle()
	var eight: Button = current_scene.find_child("SettingsSpeed_8", true, false)
	_check(eight != null and current_scene.find_child("OptionsMainMenu", true, false) != null
			and current_scene.find_child("OptionsVersion", true, false) != null,
			"Settings in a career has match speed, the main menu and the version")
	if eight != null:
		eight.emit_signal("pressed")
		await _settle()
	_check(is_equal_approx(_state.match_speed(), 8.0), "Match speed is remembered")
	_state.set_match_speed(4.0)
	_check(_state.save_career(), "The career is saved before the delete test")
	current_scene.find_child("OptionsDelete", true, false).emit_signal("pressed")
	await _settle()
	current_scene.find_child("OptionsDeleteCancel", true, false).emit_signal("pressed")
	await _settle()
	_check(_state.has_saved_career() and _state.season != null, "Keep it cancels the delete")
	current_scene.find_child("OptionsDelete", true, false).emit_signal("pressed")
	await _settle()
	var sure: Button = current_scene.find_child("OptionsDeleteConfirm", true, false)
	_check(sure != null and sure.is_visible_in_tree(), "Deleting asks first")
	if sure != null:
		sure.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "main" and not _state.has_saved_career() and _state.season == null,
			"Delete this career removes the save and returns to the menu")

	_state.delete_saved_career()
	print("Career UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
