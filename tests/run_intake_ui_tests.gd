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
	# These tests drive the hub for other things: no club card opens over it.
	_state.event_sheets = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	# Return visits: the first-visit intros (FirstVisitIntro.gd) have their own suite.
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		_state.set_setting("seen_%s_intro" % key, true)
	_state.replay_seed = SUITE_SEED
	_db = root.get_node("GameDB")
	_state.reset()
	await _t("_test_intake_by_taps")
	await _t("_test_pass_and_pick_for_me", [Vector2i(390, 844)])
	await _t("_test_pass_and_pick_for_me", [Vector2i(1280, 720)])
	await _t("_test_pick_order_and_untouchable_ui")
	await _t("_test_draft_night_words")
	await _t("_test_draft_night_screen", [Vector2i(390, 844)])
	await _t("_test_draft_night_screen", [Vector2i(1280, 720)])
	await _t("_test_trade_picks_sheet", [Vector2i(390, 844)])
	await _t("_test_trade_picks_sheet", [Vector2i(1280, 720)])
	await _t("_test_full_list_before_and_during_draft")
	print(Ran.line("Intake UI", self))
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


## Opening the off-season (retirements, delistings, trades and free agency for
## every club) is most of what a draft test costs, and no test here is about
## it. The first test at a club opens it and saves the career to that club's
## own file; the next ones load that save. Everything a test sets up (picks,
## trades, list sizes, the draft itself) comes after the opening.
var _open_saved := {}


## A seeded career at `club`, its first home-and-away done and the off-season open.
func _offseason_open(club: String) -> void:
	var keep: String = _state.save_path
	_state.save_path = "user://test_intake_ui_open_%s.save" % club
	var loaded: bool = bool(_open_saved.get(club, false)) and _state.load_career()
	if not loaded:
		_state.reset()
		_state.replay_seed = SUITE_SEED
		_state.start_season(club, _db.club_list(club))
		_state.season.round_index = _state.season.fixture.size()
		_state.open_offseason()
		_open_saved[club] = _state.save_career()
	_state.save_path = keep
	_state.replay_seed = SUITE_SEED
	_check(_state.my_club == club and _state.offseason_year == _state.season_year
			and _state.season.round_index == _state.season.fixture.size(),
			"(setup) %s's off-season is open at the end of the home-and-away (%s)" % [club, "loaded" if loaded else "opened"])


## The National Draft on the shared screen, driven by taps, through to the new list (the checks written in _run).
func _test_intake_by_taps() -> void:
	var first_year := int(_state.season_year)
	_offseason_open("COL")
	var season = _state.season
	# A compensation pick for losing a free agent, so the order shows one.
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
	# The meeting is written to the save as it opens (the test save only), so a
	# career loaded mid-draft does not hold it again.
	_state.delete_saved_career()
	_state.autosave_enabled = true
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	_state.autosave_enabled = false
	var on_disk: Dictionary = load("res://scripts/state/CareerSave.gd").read(_state.save_path)
	_check(int(on_disk.get("draft_meeting_year", 0)) == int(_state.season_year),
			"The meeting held is in the save, so a loaded career does not hold it again (saved %d, this draft %d)" % [
			int(on_disk.get("draft_meeting_year", 0)), int(_state.season_year)])
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
	# Free agency may award a real one too; the fixture's row must be there.
	_check(comp_rows.any(func(l): return str((l as Label).text).contains("Compensation for losing Sam Example")),
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
	_offseason_open("COL")
	# Spare men put the list above the minimum after retirements, so Pass is
	# allowed on the coach's turn (Draft.pass_block_reason).
	var min_list := int(load("res://scripts/sim/Contracts.gd").min_list())
	var staying: int = _state.my_list.filter(func(q): return not _state.retiring_now(q)).size()
	var base: Dictionary = _state.my_list[_state.my_list.size() - 1]
	for i in range(maxi(0, min_list + 1 - staying)):
		var extra: Dictionary = base.duplicate(true)
		extra["id"] = "pass_extra_%d" % i
		extra.erase("retiring")
		_state.my_list.append(extra)
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
	_check(not pick_me.disabled, "Pick for me is live on your turn (%s)" % tag)
	# Pass is live only once the list reaches the minimum (Draft.pass_block_reason).
	_check(pass_b.disabled == (draft.pass_block_reason() != ""),
			"Pass is live exactly when the list allows it (%s: %s)" % [tag, draft.pass_block_reason()])
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
	# Fill the list to the minimum so passing is allowed.
	guard = 0
	while draft.is_user_turn() and draft.pass_block_reason() != "" and guard < 60:
		guard += 1
		draft.pick_for_me()
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	if draft.is_user_turn():
		_check(not pass_b.disabled, "Pass is live once the list reaches the minimum (%s)" % tag)
		var taken: int = draft.count()
		_state.set("_dirty", false)
		await _press(pass_b, "Pass (%s)" % tag)
		await _settle()
		_check(draft.count() == taken and draft.passed_clubs.has(draft.user_club),
				"A tap on Pass signs nobody and leaves the draft (%s)" % tag)
		_check(bool(_state.get("_dirty")), "Passing is kept: the career is marked for saving (%s)" % tag)
		_check(draft.is_finished() or not draft.is_user_turn(), "A passed coach is not asked again (%s)" % tag)
	ui.queue_free()
	await _settle()


## Draft night's Trade picks (director 2026-10-25), by real taps: the button on
## the board, the sheet with the club and its picks, a pick on each side, the
## club's answer in words, and the way back to the draft.
func _test_trade_picks_sheet(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_offseason_open("FRE")
	if not _state.begin_intake_draft():
		_check(false, "The draft opens for the trade sheet test (%s)" % tag)
		return
	var draft = _state.draft
	root.size = size
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var skip: Button = ui.find_child("MeetingDone", true, false)
	if skip != null:
		await _press(skip, "the recruiting panel (%s)" % tag)
	var guard := 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	var trade: Button = ui.find_child("TradePicks", true, false)
	_check(trade != null and not trade.disabled and trade.text.begins_with("Trade picks"),
			"Trade picks sits with Pick for me and Pass (%s: %s)" % [tag, trade.text if trade else "-"])
	if trade == null:
		ui.queue_free()
		return
	var viewport := Rect2(Vector2.ZERO, Vector2(size))
	_check(viewport.grow(1).encloses(trade.get_global_rect()) and trade.size.y >= 44.0,
			"The button is on screen and thumb-sized (%s)" % tag)
	await _press(trade, "Trade picks (%s)" % tag)
	await _settle()
	var sheet: Control = ui.find_child("TradeSheet", true, false)
	var with_l: Label = ui.find_child("TradingWith", true, false)
	_check(sheet != null and with_l != null and with_l.text.begins_with("Trading with "),
			"The sheet opens on a club (%s: %s)" % [tag, with_l.text if with_l else "-"])
	var rule: Label = ui.find_child("TradeSheetRule", true, false)
	_check(rule != null and rule.text.begins_with("Only picks change hands tonight"),
			"The sheet says only picks trade tonight (%s)" % tag)
	if sheet == null:
		ui.queue_free()
		return
	# Their first pick, then yours, by taps; the club answers in words.
	var their_btn: Button = null
	for b in ui.find_children("Their_pick_*", "Button", true, false):
		their_btn = b
		break
	_check(their_btn != null, "Their picks are listed to add (%s)" % tag)
	if their_btn != null:
		await _press(their_btn, "one of their picks (%s)" % tag)
		await _settle()
	var mine_tab: Button = ui.find_child("TradeSide_mine", true, false)
	if mine_tab != null:
		await _press(mine_tab, "Your picks (%s)" % tag)
		await _settle()
	var my_btn: Button = null
	for b in ui.find_children("Mine_pick_*", "Button", true, false):
		my_btn = b
		break
	_check(my_btn != null and my_btn.text.begins_with("Pick %d tonight" % (draft.pick_index + 1)),
			"Your pick on the clock heads your picks, by its number tonight (%s: %s)" % [tag, my_btn.text if my_btn else "-"])
	if my_btn != null:
		await _press(my_btn, "your pick (%s)" % tag)
		await _settle()
	var verdict: Label = ui.find_child("TradeVerdict", true, false)
	_check(verdict != null and verdict.text != "Put a pick on each side." and verdict.text != "",
			"The club answers in words (%s: %s)" % [tag, verdict.text if verdict else "-"])
	var digits := verdict != null and RegEx.create_from_string("\\d").search(verdict.text) != null
	_check(not digits, "The answer carries no value (%s)" % tag)
	var give := ui.find_children("GiveRow_*", "Control", true, false)
	var take := ui.find_children("GetRow_*", "Control", true, false)
	_check(give.size() == 1 and take.size() == 1, "A pick on each side (%s: %d/%d)" % [tag, give.size(), take.size()])
	var close: Button = ui.find_child("TradeSheetClose", true, false)
	_check(close != null and viewport.grow(1).encloses(close.get_global_rect()), "Back to the draft is on screen (%s)" % tag)
	if close != null:
		await _press(close, "Back to the draft (%s)" % tag)
		await _settle()
	_check(ui.find_child("TradeSheet", true, false) == null and draft.is_user_turn(),
			"The sheet closes and you are still on the clock (%s)" % tag)
	# Android Back closes the sheet too, and stays on the draft.
	await _press(trade, "Trade picks again (%s)" % tag)
	await _settle()
	var reopened_sheet: Control = ui.find_child("TradeSheet", true, false)
	var reopened: bool = reopened_sheet != null
	# After an accepted offer, a pick that changed hands leaves the package.
	if reopened:
		var obj = reopened_sheet.get_meta("sheet")
		var own: Array = _state.club_picks(_state.my_club)
		var rival_pick := ""
		for pk in _state.club_picks(str(obj.get("_club"))):
			rival_pick = str(pk["id"])
			break
		_check(not own.is_empty() and rival_pick != "", "Both sides hold picks to test with (%s)" % tag)
		if not own.is_empty() and rival_pick != "":
			obj.set("_mine", [str(own[0]["id"]), rival_pick])
			obj.set("_theirs", [rival_pick, str(own[0]["id"])])
			obj.call("_prune")
			_check(obj.get("_mine") == [str(own[0]["id"])] and obj.get("_theirs") == [rival_pick],
					"Only picks each side still holds stay in its package (%s)" % tag)
	var handled: bool = ui.call("handle_back")
	await _settle()
	_check(reopened and handled and ui.find_child("TradeSheet", true, false) == null and draft.is_user_turn(),
			"Back closes the trade sheet and keeps you on the clock (%s)" % tag)
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


## Director report, 2026-11-07: "I had 4 picks in the draft but it only let
## me use two. Maybe my list was full, but I had no idea". With a nearly full
## senior list, the draft button first says which picks will pass, offers the
## off-season screen to delist, and the draft screen says a pass when it
## happens. Real taps at a phone size.
func _test_full_list_before_and_during_draft() -> void:
	_offseason_open("COL")
	var s = _state.season
	# The season is over (the hub offers the draft only then): finals done.
	s.finals = {"done": true, "premier": "CAR", "runner_up": "ESS"}
	var cap: int = load("res://scripts/state/RookieList.gd").SENIOR_SPOTS
	var rl = load("res://scripts/state/RookieList.gd")
	for p in _state.my_list:
		p["contract_years"] = 3
	# Three cheap players out of contract: the ones Delist lands on.
	var cheap: Array = _state.my_list.filter(func(q): return not _state.retiring_now(q))
	cheap.sort_custom(func(x, y): return int(x.get("salary", 0)) < int(y.get("salary", 0)))
	for q in cheap.slice(0, 3):
		q["contract_years"] = 1
	# Pad the list until one senior spot is open for next season, counted as the
	# draft counts it (after retirements and the free-agency close), whatever
	# size the club's list starts at (the year's minimum, Contracts.min_list()).
	var n := 0
	while int(_state.draft_list_spots()["held"]) < cap - 1 and n < 40:
		var copy: Dictionary = (_state.my_list[n % _state.my_list.size()] as Dictionary).duplicate(true)
		copy["id"] = "pad_%d" % n
		copy["rookie_list"] = ""
		copy["contract_years"] = 3
		copy.erase("retiring")
		_state.my_list.append(copy)
		n += 1
	var spots: Dictionary = _state.draft_list_spots()
	_check((spots["passing"] as Array).size() >= 1, "Some picks have no spot (%s)" % str(spots))
	# The reference phone (director, 2026-11-12 check: no scrolling to reach a Release button).
	root.size = Vector2i(360, 740)
	# A coach past his first week: the hub's one-off intro (a setting, so it
	# carries over from whichever suite ran before) would sit over the button.
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.postseason_intro_seen = true
	# Must make room (director, 2026-11-12): one open spot for three picks is
	# short of the rule, so the sheet is a gate with Delist and Trade, and no
	# start. Once the coach has delisted enough, the draft starts.
	var held: int = (spots["picks"] as Array).size()
	var short: int = _state.draft_room_short()
	_check(held >= 2 and short == mini(3, held) - int(spots["open"]),
			"The list is short of the rule by %d (%s)" % [short, str(spots)])
	var words := ["no", "one", "two", "three"]
	var want_gate := "Clubs must take at least three players. Delist %s to make room, or trade the picks." % words[mini(short, 3)]
	for round_trip in ["delist", "trade", "start"]:
		if round_trip == "start":
			# The coach delists the players the gate asked for.
			var gone := 0
			for p in _state.my_list.duplicate():
				if _state.draft_room_short() <= 0:
					break
				if str(p["id"]).begins_with("pad_") and bool(_state.release_player(str(p["id"]))["ok"]):
					gone += 1
			_check(gone == short and _state.draft_room_short() == 0 and _state.draft_room_line() == "",
					"Delisting %d meets the rule (%d delisted)" % [short, gone])
		var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		await _settle()
		var go: Button = null
		for b in hub.find_children("*", "Button", true, false):
			if (b as Button).text == "%d National Draft" % int(_state.season_year):
				go = b
		_check(go != null, "The hub offers the National Draft")
		if go == null:
			hub.queue_free()
			return
		await _press(go, "the National Draft button")
		await _settle()
		var sheet: Control = hub.find_child("DraftSpots", true, false)
		var vp := Rect2(Vector2.ZERO, Vector2(root.size))
		var tap: Button = null
		if round_trip != "start":
			_check(sheet != null, "The draft button first opens the list gate")
			_check(_state.draft == null or not _state.draft.intake_mode, "The draft has not started yet")
			var gate: Label = hub.find_child("DraftRoomGate", true, false)
			_check(gate != null and gate.text == want_gate, "The gate says the rule: %s" % (gate.text if gate else "-"))
			_check(hub.find_child("DraftSpotsStart", true, false) == null, "The gate has no start button")
			_check(hub.find_child("EventSheet", true, false) == null, "The gate is the only sheet open")
			for bn in ["DraftRoomDelist", "DraftRoomTrade"]:
				var b: Button = hub.find_child(bn, true, false)
				_check(b != null and vp.grow(1).encloses(b.get_global_rect()) and b.size.y >= 44,
						"%s is on screen and thumb-sized" % bn)
			tap = hub.find_child("DraftRoomDelist" if round_trip == "delist" else "DraftRoomTrade", true, false)
		elif sheet != null:
			# The rule is met; any picks over the open spots still pass, said first.
			_check(hub.find_child("DraftRoomGate", true, false) == null, "The gate is gone once the rule is met")
			var passing: Label = hub.find_child("DraftSpotsPassing", true, false)
			var left: Dictionary = _state.draft_list_spots()
			var want := "%s %s will pass." % ["Pick" if (left["passing"] as Array).size() == 1 else "Picks",
					load("res://scripts/sim/Draft.gd").picks_words(left["passing"])]
			_check(passing != null and passing.text == want,
					"The sheet names the picks that will pass: %s" % (passing.text if passing else "-"))
			var rule: Label = hub.find_child("DraftSpotsRule", true, false)
			_check(rule != null and rule.text.contains("delisted before the draft starts"), "The sheet states the rule")
			var said := ""
			for l in sheet.find_children("*", "Label", true, false):
				said += (l as Label).text.to_lower() + " "
			for w in ["you should", "recommend", "best"]:
				_check(not said.contains(w), "The sheet never tells the coach what to do (%s)" % w)
			tap = hub.find_child("DraftSpotsStart", true, false)
			_check(tap != null and vp.grow(1).encloses(tap.get_global_rect()) and tap.size.y >= 44,
					"Start the draft is on screen and thumb-sized")
		if tap != null:
			await _press(tap, tap.text)
		for i in range(20):
			await process_frame
		var cur := current_scene
		if round_trip != "start":
			_check(cur != null and cur.scene_file_path.ends_with("OffseasonScene.tscn"),
					"%s opens the off-season screen (%s)" % [round_trip, cur.scene_file_path if cur else "-"])
			var want_tab := "contracts" if round_trip == "delist" else "trade"
			_check(cur != null and str(cur.get("_tab")) == want_tab, "%s opens on the %s tab" % [round_trip, want_tab])
			if round_trip == "delist" and cur != null:
				# He lands on the players he can delist: a Release button is on screen.
				var rel: Button = cur.find_child("Release", true, false)
				_check(rel != null and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rel.get_global_rect()),
						"Delist lands with a Release button on screen (%s)" % (str(rel.get_global_rect()) if rel else "none"))
			_check(_state.offseason_open(), "Players can still be delisted: the off-season is open")
		else:
			_check(_state.draft != null and _state.draft.intake_mode, "Start the draft starts it")
			_check(cur != null and cur.scene_file_path.ends_with("DraftScene.tscn"), "The draft screen opens")
		hub.queue_free()
		if cur != null and cur != hub:
			cur.queue_free()
		await _settle()
	var draft = _state.draft
	if draft == null:
		return
	for i in range(400):
		if draft.is_finished() or not draft.user_passed.is_empty():
			break
		if draft.is_user_turn():
			draft.pick_for_me()
		else:
			draft.auto_until_user_turn()
	if held <= 3:
		_check(draft.user_passed.is_empty(), "With the rule met and no picks over, none passed")
		return
	_check(not draft.user_passed.is_empty(), "A pick passed for a full list")
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var done: Button = ui.find_child("MeetingDone", true, false)
	if done != null:
		await _press(done, "Done in the recruiting meeting")
		await _settle()
	var said_pass: Label = ui.find_child("YourPicksPassed", true, false)
	_check(said_pass != null and said_pass.is_visible_in_tree() and said_pass.text == draft.user_passed_line()
			or (said_pass != null and draft.is_finished() and said_pass.text != ""),
			"The draft screen says the pass when it happens: %s" % (said_pass.text if said_pass else "-"))
	ui.queue_free()
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


func _snapshot(ui: Control) -> Dictionary:
	var draft = _state.draft
	var out := {
		"history": draft.pick_history.duplicate(true),
		"count": draft.count(),
		"counts": draft.role_counts(),
		"pick_index": draft.pick_index,
	}
	for key in ["_role", "_search", "_sort", "_history_club"]:
		out[key] = ui.get(key)
	return out


func _check_layout(ui: Control, label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var margin: Control = ui.get("_margin")
	_check(viewport.grow(1).encloses(margin.get_global_rect()), label + " has no page overflow")
	for node_name in ["DraftWorkspace", "StartSeason", "DraftPool", "DraftActivity",
			"LiveBoard"]:
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

# ---------------------------------------------------------------------------
# Draft night (P-15): the live board, your pick on the stage, the recruiter's
# line. Words first (no hidden stat, no grade), then the screen with motion on
# at a phone and a PC size, with real taps.
# ---------------------------------------------------------------------------
## Words a draft-night line must never carry: a grade, a rank, a verdict on
## the pick or a percentage (bible: make the rules transparent, don't make the
## decision).
const NIGHT_FORBIDDEN := ["grade", "rank", "best available", "steal", "reach", "a+", "%",
		"potential", "ovr", "pot ", "rating", "should", "must", "recommend"]


func _night_forbidden(text: String) -> String:
	var low := text.to_lower()
	for w in NIGHT_FORBIDDEN:
		if low.contains(w):
			return w
	return ""


func _test_draft_night_words() -> void:
	var dn = load("res://scripts/ui/DraftNight.gd")
	_check(dn != null, "Draft night's words exist (scripts/ui/DraftNight.gd)")
	if dn == null:
		return
	var walter := {"id": "T_walter", "generic_name": "Jed Walter", "name": "Jed Walter", "role": "FWD",
			"height_cm": 195.0, "age": 18.4, "draft_team": "Sandringham Dragons", "club": "Sandringham Dragons",
			"u18_gm": 12.0, "u18_gl": 2.4, "u18_mk": 5.0, "u18_di": 12.0, "u18_tk": 2.0}
	var name: String = _db.player_display_name(walter)
	_check(dn.announcement(14, "FRE", walter) == "Pick 14: Fremantle. %s, from the Sandringham Dragons, key forward" % name,
			"The name is read in words: %s" % dn.announcement(14, "FRE", walter))
	_check(dn.from_words({"draft_team": "Claremont"}) == "from Claremont"
			and dn.from_words({"draft_team": "Swan Districts"}) == "from Swan Districts"
			and dn.from_words({"draft_team": "Suns Academy"}) == "from the Suns Academy",
			"A club by its place takes no \"the\"; a nickname or an academy does")
	_check(dn.your_pick_line(14, 12) == "Your pick: 14, two away" and dn.your_pick_line(14, 13) == "Your pick: 14, next"
			and dn.your_pick_line(14, 14) == "You're on the clock" and dn.your_pick_line(40, 12) == "Your pick: 40, 28 away",
			"Your next pick reads in words: %s" % dn.your_pick_line(14, 12))
	_check(dn.clock_line(12, "FRE") == "Pick 12: Fremantle", "The club on the clock reads \"Pick 12: Fremantle\"")
	_check(dn.recruiter_line(walter, "FRE") == "A key forward who kicks goals in bunches; key position players take time.",
			"The recruiter's line is football words: %s" % dn.recruiter_line(walter, "FRE"))
	# Every prospect in a real class: the line reads only what is public, so
	# scrambling every hidden figure leaves it as it was, and it never grades.
	_offseason_open("FRE")
	if not _state.begin_intake_draft():
		_check(false, "The draft opens for the words test")
		return
	var pool: Array = _state.draft.pool
	var hidden_free := true
	var clean := true
	var said_bad := ""
	for p in pool:
		var line: String = dn.recruiter_line(p, "FRE")
		var read: String = dn.announcement(1, "FRE", p)
		var scrambled: Dictionary = (p as Dictionary).duplicate(true)
		for key in ["overall", "potential", "class_shift", "class_ceiling", "value", "draft_rank"]:
			scrambled[key] = 1 if key != "potential" else 99
		var attr: Dictionary = scrambled.get("attr", {})
		for k in attr:
			attr[k] = 1.0
		if dn.recruiter_line(scrambled, "FRE") != line or dn.announcement(1, "FRE", scrambled) != read:
			hidden_free = false
			said_bad = line
		var bad := _night_forbidden(line + " " + dn.from_words(p) + " " + dn.position_words(p))
		if bad != "":
			clean = false
			said_bad = "%s (%s)" % [line, bad]
	_check(pool.size() > 20 and hidden_free,
			"The recruiter's line and the name read out use no hidden figure, across %d prospects (%s)" % [pool.size(), said_bad])
	_check(clean, "No line says grade, rank, best available, steal, reach, A+ or a percentage (%s)" % said_bad)


## The screen: the board, the beat on your pick only, a tap skips it, the
## replay of the rivals, Back and leaving the screen, at a phone and a PC size.
func _test_draft_night_screen(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	var dn = load("res://scripts/ui/DraftNight.gd")
	var feel = load("res://scripts/ui/Feel.gd")
	_offseason_open("FRE")
	# Room on the list for every pick Fremantle holds, so the coach is on the
	# clock again after Pick for me (Back below): delist the cheapest players
	# staying on until the picks all have a spot.
	var staying: Array = _state.my_list.filter(func(q): return not _state.retiring_now(q))
	staying.sort_custom(func(x, y): return int(x.get("salary", 0)) < int(y.get("salary", 0)))
	for q in staying:
		if (_state.draft_list_spots()["passing"] as Array).is_empty():
			break
		_state.release_player(str(q["id"]))
	_check((_state.draft_list_spots()["passing"] as Array).is_empty(),
			"Every Fremantle pick has a spot for the draft night test (%s: %s)" % [tag, str(_state.draft_list_spots())])
	if not _state.begin_intake_draft() or dn == null:
		_check(false, "The draft opens for the draft night test (%s)" % tag)
		return
	var draft = _state.draft
	# What the save holds before the night: the same keys after it (the show is
	# the screen's alone; the model and the save are untouched).
	_state.save_career()
	var saved_before: Dictionary = load("res://scripts/state/CareerSave.gd").read(_state.save_path)
	var draft_keys_before: Array = (saved_before.get("draft", {}) as Dictionary).keys()
	root.size = size
	feel.test_motion = true
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var skip: Button = ui.find_child("MeetingDone", true, false)
	if skip != null:
		await _press(skip, "the recruiting panel (%s)" % tag)
	var guard := 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	_check(ui.find_child("DraftNightStage", true, false) == null, "No stage before your pick (%s)" % tag)
	var status: Label = ui.find_child("DraftStatus", true, false)
	var yours: Label = ui.find_child("YourNextPick", true, false)
	var mine_no: int = draft.pick_index + 1
	_check(status != null and status.text == "Pick %d: Fremantle" % mine_no,
			"The board has Fremantle on the clock in words (%s: %s)" % [tag, status.text if status else "-"])
	_check(yours != null and yours.is_visible_in_tree() and yours.text == "You're on the clock",
			"The board shows your pick (%s: %s)" % [tag, yours.text if yours else "-"])
	# A rivals' trade struck on the night takes a row of the strip like a pick.
	var recent: Array = ui.find_children("RecentPick_*", "Control", true, false) \
			+ ui.find_children("RecentTrade_*", "Control", true, false)
	var events: int = draft.pick_history.size()
	for t in draft.night_trades:
		if int(t["at"]) <= draft.pick_index + 1:
			events += 1
	var rows_want := mini(3 if size.y >= 780 or size.x >= 760 else 2, events)
	_check(recent.size() == rows_want, "The last picks are under it: three, two on a shorter screen (%s: %d)" % [tag, recent.size()])
	var strip: Control = ui.find_child("RecentPicks", true, false)
	if size.x >= 760:
		# PC: the pick log beside the board already lists the picks; the strip shows
		# only when the log is not on screen.
		_check(strip != null and not strip.is_visible_in_tree(), "PC: no last-picks strip beside the pick log (%s)" % tag)
		await _press(ui.find_child("SideTab_squad", true, false), "My list beside the pool (%s)" % tag)
		_check(strip.is_visible_in_tree(), "PC: the strip shows when the pick log is not on screen (%s)" % tag)
		await _press(ui.find_child("SideTab_picks", true, false), "the pick log tab (%s)" % tag)
	else:
		_check(strip != null and strip.is_visible_in_tree(), "Phone: the last picks show on the board (%s)" % tag)
	# The pick numbers read one way on this screen: "42", never "#42".
	var hash_text := ""
	for l in ui.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and RegEx.create_from_string("#\\d").search((l as Label).text) != null:
			hash_text = (l as Label).text
	_check(hash_text == "", "Picks are written as numbers, never with # (%s: %s)" % [tag, hash_text])
	var pool_info_want: int = draft.remaining_pool()
	var board: Control = ui.find_child("LiveBoard", true, false)
	var viewport := Rect2(Vector2.ZERO, Vector2(size))
	_check(board != null and viewport.grow(1).encloses(board.get_global_rect()), "The board is whole on screen (%s)" % tag)
	if not size.x >= 760:
		# Phone: the pool is the tab under the board.
		var pool_tab: Button = ui.find_child("Tab_pool", true, false)
		if pool_tab != null:
			await _press(pool_tab, "the pool tab (%s)" % tag)
	# Your pick, with a finger on the pool's button.
	var target: Dictionary = {}
	for p in draft.board("", "", "", "overall", true):
		if draft.can_pick_player(p):
			target = p
			break
	var pick_btn: Button = ui.find_child("Pick_" + str(target.get("id", "")), true, false)
	_check(pick_btn != null, "A pick button for a prospect (%s)" % tag)
	if pick_btn == null:
		feel.test_motion = false
		ui.queue_free()
		await _settle()
		return
	var at: int = draft.pick_history.size()
	await _press(pick_btn, "a prospect's pick button (%s)" % tag)
	await _settle()
	var stage: Control = ui.find_child("DraftNightStage", true, false)
	_check(stage != null and str(draft.pick_history[at]["player_id"]) == str(target["id"]),
			"Your pick goes on the stage (%s)" % tag)
	if stage == null:
		feel.test_motion = false
		ui.queue_free()
		await _settle()
		return
	var want: String = dn.announcement(mine_no, "FRE", target)
	_check(str(stage.get_meta("announcement", "")) == want, "The stage reads the pick: %s" % want)
	var name_l: Label = stage.find_child("BeatName", true, false)
	var from_l: Label = stage.find_child("BeatFrom", true, false)
	var pick_l: Label = stage.find_child("BeatPick", true, false)
	var rec_l: Label = stage.find_child("BeatRecruiter", true, false)
	_check(pick_l != null and pick_l.text == "Pick %d: Fremantle" % mine_no and name_l != null
			and name_l.text == _db.player_display_name(target) and from_l != null
			and from_l.text == "%s, %s" % [dn.from_words(target), dn.position_words(target)],
			"It says his name, where he is from and his position (%s: %s / %s)" % [tag,
			name_l.text if name_l else "-", from_l.text if from_l else "-"])
	_check(rec_l != null and rec_l.text.begins_with("Recruiting note: ") and not rec_l.text.contains("“") and rec_l.text.contains(dn.recruiter_line(target, "FRE"))
			and _night_forbidden(rec_l.text) == "",
			"Then the recruiter's one line, with no grade in it (%s: %s)" % [tag, rec_l.text if rec_l else "-"])
	var vignette: Control = stage.find_child("DraftNightVignette", true, false)
	_check(vignette != null and vignette.get_script() == load("res://scripts/ui/match/AwardWinnerVignette.gd")
			and vignette.get("club") == "FRE" and vignette.get("medal") == false,
			"He is on the award stage in Fremantle's guernsey, with no medal (%s)" % tag)
	# Where the stage sits: PC beside the pick log; phone under the board.
	var sr := stage.get_global_rect()
	var activity: Control = ui.find_child("DraftActivity", true, false)
	if size.x >= 760:
		_check(activity != null and not sr.intersects(activity.get_global_rect().grow(-1)) and sr.end.y <= size.y + 1,
				"PC: the stage and the pick log share the width (%s)" % tag)
	else:
		_check(board != null and sr.position.y >= board.get_global_rect().end.y - 1 and viewport.grow(1).encloses(sr),
				"Phone: the stage sits under the board, on screen, no scrolling (%s)" % tag)
	_check(board != null and board.is_visible_in_tree(), "The board stays in view during the beat (%s)" % tag)
	_check(ui.call("replaying") and status.text == "Pick %d: Fremantle" % mine_no and not yours.is_visible_in_tree(),
			"While the stage reads your pick the board stays on it and holds the rivals' picks back (%s: %s)" % [tag, status.text])
	var strip_now: Control = ui.find_child("RecentPicks", true, false)
	_check(strip_now != null and not strip_now.is_visible_in_tree(),
			"The last-picks strip steps aside while the stage reads your pick (%s)" % tag)
	var cap_l: Label = ui.find_child("SalaryCap", true, false)
	_check(cap_l != null and cap_l.text == "%d prospects left" % pool_info_want,
			"The board's count stays at your pick during the beat (%s: %s, want %d)" % [tag, cap_l.text if cap_l else "-", pool_info_want])
	var pick_me_b: Button = ui.find_child("PickForMe", true, false)
	var pass_b: Button = ui.find_child("PassPick", true, false)
	_check(pick_me_b != null and pick_me_b.disabled and (pass_b == null or pass_b.disabled),
			"Pick for me and Pass wait while the stage plays (%s)" % tag)
	var signed_before: int = draft.count()
	var hist_before: int = draft.pick_history.size()
	if pick_me_b != null:
		await Tap.tap(pick_me_b)
		await _settle()
	_check(draft.count() == signed_before and draft.pick_history.size() == hist_before
			and ui.find_child("DraftNightStage", true, false) != null,
			"A tap on Pick for me during the stage picks no one (%s)" % tag)
	var kit_n = load("res://scripts/ui/UiKit.gd")
	var board_ink: Color = kit_n.club_name_colour(kit_n.club_ink("FRE"))
	_check(pick_l != null and pick_l.get_theme_color("font_color").is_equal_approx(board_ink),
			"The stage writes Fremantle in the same ink as the board (%s)" % tag)
	# A tap skips the beat; the board then replays the rival picks.
	var why: String = await Tap.tap(stage as Button)
	await _settle()
	_check(why == "" and ui.find_child("DraftNightStage", true, false) == null, "A tap ends the beat (%s: %s)" % [tag, why])
	# The stage fades out first; then the board moves on.
	await create_timer(float(ui.get_script().get_script_constant_map()["BEAT_FADE"]) + 0.06).timeout
	var rivals: int = draft.pick_history.size() - at - 1
	if rivals > 0:
		var first_rival: Dictionary = draft.pick_history[at + 1]
		_check(ui.call("replaying") and status.text == "Pick %d: %s" % [int(first_rival["pick"]), _db.club_name(str(first_rival["club"]))],
				"Then the board puts the next club on the clock (%s: %s)" % [tag, status.text])
		var next_mine: int = draft.pick_index + 1
		_check(yours.text == dn.your_pick_line(next_mine, int(first_rival["pick"])),
				"And says how far away your next pick is (%s: %s)" % [tag, yours.text])
		_check(ui.find_child("DraftNightStage", true, false) == null, "A rival's pick gets no stage (%s)" % tag)
		var cap_r: Label = ui.find_child("SalaryCap", true, false)
		_check(cap_r != null and cap_r.text == "%d prospects left" % (draft.remaining_pool() + draft.pick_history.size() - (at + 1)),
				"The prospects-left count holds back with the board (%s: %s)" % [tag, cap_r.text if cap_r else "-"])
		var info_r: Label = ui.get("_board_info")
		_check(info_r != null and info_r.text != "" and not info_r.text.left(1).is_valid_int(),
				"The pool's line does not repeat the count the board gives (%s: %s)" % [tag, info_r.text if info_r else "-"])
		var picks_tab: Button = ui.find_child("SideTab_picks" if size.x >= 760 else "Tab_picks", true, false)
		_check(picks_tab != null and picks_tab.text == "Picks (%d)" % (at + 1),
				"The pick log holds back the picks the board has not shown (%s: %s)" % [tag, picks_tab.text if picks_tab else "-"])
		await create_timer(0.75).timeout
		_check(ui.find_child("DraftNightStage", true, false) == null and status.text != "Pick %d: %s" % [int(first_rival["pick"]), _db.club_name(str(first_rival["club"]))],
				"The rival picks fill in one by one, with no stage (%s: %s)" % [tag, status.text])
		# A tap on the board finishes the replay at once.
		await Tap.tap(board)
		await _settle()
		_check(not ui.call("replaying") and status.text == "Pick %d: Fremantle" % next_mine
				and yours.text == "You're on the clock",
				"A tap on the board finishes the replay: you are on the clock again (%s: %s)" % [tag, status.text])
		picks_tab = ui.find_child("SideTab_picks" if size.x >= 760 else "Tab_picks", true, false)
		_check(picks_tab != null and picks_tab.text == "Picks (%d)" % draft.pick_history.size(),
				"Then the pick log has every pick (%s: %s)" % [tag, picks_tab.text if picks_tab else "-"])
	# Back cuts the show to the end, beat and replay alike.
	if draft.is_user_turn():
		var pick_me: Button = ui.find_child("PickForMe", true, false)
		await _press(pick_me, "Pick for me (%s)" % tag)
		await _settle()
		_check(ui.find_child("DraftNightStage", true, false) != null, "Pick for me goes on the stage too (%s)" % tag)
		_check(bool(ui.call("handle_back")) and not ui.call("replaying"), "Back skips the beat and the replay (%s)" % tag)
		await _settle()
		_check(ui.find_child("DraftNightStage", true, false) == null and status.text.ends_with(": Fremantle"),
				"After Back the board is at the end: you on the clock (%s: %s)" % [tag, status.text])
	# Back in the middle of the replay finishes it at once.
	if draft.is_user_turn():
		var mark: int = draft.pick_history.size()
		await _press(ui.find_child("PickForMe", true, false), "Pick for me, to replay (%s)" % tag)
		await _settle()
		var beat: Button = ui.find_child("DraftNightStage", true, false)
		if beat != null:
			await Tap.tap(beat)
		await _settle()
		if draft.pick_history.size() - mark > 1:
			_check(ui.call("replaying"), "The replay is running before Back (%s)" % tag)
			var backed := bool(ui.call("handle_back"))
			var end_clock: String = "Draft complete" if draft.is_finished() else dn.clock_line(draft.pick_index + 1, draft.current_club())
			_check(backed and not ui.call("replaying") and status.text == end_clock,
					"Back mid-replay finishes it: the board at the end (%s: %s)" % [tag, status.text])
	# The beat ends on its own; and leaving mid-replay never leaves it half-shown.
	if draft.is_user_turn():
		await _press(ui.find_child("PickForMe", true, false), "Pick for me again (%s)" % tag)
		await _settle()
		await create_timer(float(ui.get_script().get_script_constant_map()["BEAT_TIME"]) + 0.3).timeout
		_check(ui.find_child("DraftNightStage", true, false) == null, "The beat ends by itself after about two seconds (%s)" % tag)
		ui.queue_free()
		await _settle()
		ui = load("res://scenes/DraftScene.tscn").instantiate()
		root.add_child(ui)
		await _settle()
		status = ui.find_child("DraftStatus", true, false)
		var want_clock: String = "Draft complete" if draft.is_finished() else dn.clock_line(draft.pick_index + 1, draft.current_club())
		_check(not ui.call("replaying") and status != null and status.text == want_clock,
				"Back on the screen, the board is whole, not half-replayed (%s: %s)" % [tag, status.text if status else "-"])
	# A pass gets no stage.
	if draft.is_user_turn() and draft.pass_block_reason() == "":
		await _press(ui.find_child("PassPick", true, false), "Pass (%s)" % tag)
		await _settle()
		_check(ui.find_child("DraftNightStage", true, false) == null, "A pass goes on no stage (%s)" % tag)
	ui.queue_free()
	await _settle()
	# No new save key: the career saves the same fields after the night.
	_state.save_career()
	var saved_after: Dictionary = load("res://scripts/state/CareerSave.gd").read(_state.save_path)
	var top_before: Array = saved_before.keys()
	var top_after: Array = saved_after.keys()
	var draft_keys_after: Array = (saved_after.get("draft", {}) as Dictionary).keys()
	top_before.sort()
	top_after.sort()
	draft_keys_before.sort()
	draft_keys_after.sort()
	_check(not top_before.is_empty() and top_before == top_after and not draft_keys_before.is_empty()
			and draft_keys_before == draft_keys_after,
			"Draft night adds no save key (%s: %d top, %d draft keys)" % [tag, top_after.size(), draft_keys_after.size()])
	# With motion off (tests, captures, reduced motion) the pick lands as before.
	feel.test_motion = false
	if size.x >= 760:
		return
	_offseason_open("FRE")
	_state.begin_intake_draft()
	draft = _state.draft
	ui = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	var done_b: Button = ui.find_child("MeetingDone", true, false)
	if done_b != null:
		done_b.emit_signal("pressed")
	guard = 0
	while not draft.is_user_turn() and not draft.is_finished() and guard < 200:
		guard += 1
		draft.auto_until_user_turn()
	ui.call("_refresh")
	await _settle()
	ui.call("_on_pick_for_me")
	await _settle()
	_check(ui.find_child("DraftNightStage", true, false) == null and not ui.call("replaying"),
			"Without motion the pick lands with no stage and no replay (%s)" % tag)
	ui.queue_free()
	await _settle()
