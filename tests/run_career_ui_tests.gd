extends SceneTree
## godot --headless --path . --script tests/run_career_ui_tests.gd
## Main menu save flow (Continue Career, New Career confirmation) and the
## Android back button / Escape routing, driven through the real scenes.
## Classes are reached through load() and autoload nodes: a --script runner
## compiles before the autoloads exist.

const Tap := preload("res://tests/tap.gd")

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []

## Every season in this suite starts from a fixed seed (C15), never the clock.
const SUITE_SEED := 2027


func _initialize() -> void:
	_run.call_deferred()


func _test_rivalry_catalogue() -> void:
	_check(Rivalries.are_rivals("COL", "CAR") and Rivalries.are_rivals("CAR", "COL"),
			"Established rivalries work in either fixture direction")
	_check(Rivalries.label("ADE", "PAD") == "The Showdown", "Named rivalry context is preserved")
	_check(Rivalries.label("WCE", "FRE") == "The Western Derby", "WA meetings are always The Western Derby")
	_check(Rivalries.label("GCS", "BRL") == "The Pineapple Grapple", "Queensland meetings are always The Pineapple Grapple")
	_check(Rivalries.label("TAS", "CANB") == "Expansion Cup", "Expansion clubs contest the Expansion Cup")
	_check(Rivalries.are_rivals("GWS", "WBD"), "Giants and Bulldogs are established rivals")
	_check(not Rivalries.are_rivals("ADE", "GEE"), "Ordinary opponents are not labelled rivals")
	var dynamic := {}
	for i in range(4):
		Rivalries.record_match(dynamic, {"home": "ADE", "away": "GEE",
				"score": [80, 75], "label": "Round %d" % (i + 1)}, 2027 + i)
	_check(Rivalries.state(dynamic, "ADE", "GEE") == "brewing",
			"Repeated close games can make a new rivalry brew")
	Rivalries.record_match(dynamic, {"home": "ADE", "away": "GEE",
			"score": [91, 88], "label": "Preliminary Final", "is_final": true}, 2031)
	Rivalries.record_match(dynamic, {"home": "GEE", "away": "ADE",
			"score": [77, 73], "label": "Grand Final", "is_final": true}, 2032)
	_check(Rivalries.state(dynamic, "ADE", "GEE") == "rivals",
			"Repeated high-stakes meetings can create a full dynamic rivalry")
	var before := int((Rivalries.dynamic(dynamic, "ADE", "GEE") as Dictionary)["score"])
	Rivalries.record_match(dynamic, {"home": "GEE", "away": "ADE",
			"score": [77, 73], "label": "Grand Final", "is_final": true}, 2032)
	_check(int((Rivalries.dynamic(dynamic, "ADE", "GEE") as Dictionary)["score"]) == before,
			"Reprocessing a saved match cannot inflate rivalry history")
	var quiet := {}
	for i in range(8):
		Rivalries.record_match(quiet, {"home": "NTH", "away": "STK",
				"score": [110, 70], "label": "Round %d" % (i + 1)}, 2027 + i)
	_check(Rivalries.state(quiet, "NTH", "STK") == "",
			"Routine meetings alone do not manufacture a rivalry")

func test_media_conference_rules() -> void:
	var MediaConferenceScript = load("res://scripts/sim/MediaConference.gd")
	var VignetteScript = load("res://scripts/ui/MediaConferenceVignette.gd")
	var recent := {}
	var heavy: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 8,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, recent)
	_check(str(heavy.get("key", "")) == "heavy_loss", "Heavy loss earns a factual media question")
	_check((heavy.get("options", []) as Array).size() == 3, "Media question offers three responses")
	recent["heavy_loss"] = 8
	var repeat: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 10,
			"result": {"home": "COL", "away": "CAR", "score": [55, 101]}}, recent)
	_check(repeat.is_empty(), "Same media angle respects its cooldown")
	var ordinary: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15,
			"result": {"home": "COL", "away": "CAR", "score": [88, 72]}}, {})
	_check(ordinary.is_empty(), "Ordinary matches do not force a press conference")
	var close: Dictionary = MediaConferenceScript.pick({"club": "CAR", "opponent_name": "Collingwood", "round": 16,
			"result": {"home": "COL", "away": "CAR", "score": [84, 86]}}, {})
	_check(str(close.get("key", "")) == "close_game", "Close finishes can drive the press conference")
	# Recurring journalists (RPG-002): each question has its own asker, and what
	# you say can come back.
	_check(str(heavy.get("journalist", "")) == "muckraker" and str(heavy.get("by", "")) == "Gary Haddon, The Siren"
			and str(close.get("journalist", "")) == "stats", "Each question comes from its own journalist")
	var said := {"said|big_win": {"year": 2027, "option": 1, "opp": "Carlton"}}
	var back: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Essendon", "round": 12, "year": 2027,
			"result": {"home": "COL", "away": "ESS", "score": [40, 100]}}, said)
	var fresh: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Essendon", "round": 12, "year": 2028,
			"result": {"home": "COL", "away": "ESS", "score": [40, 100]}}, said)
	_check(str(back.get("question", "")).begins_with("After beating Carlton you said your method was the standard")
			and not str(fresh.get("question", "")).contains("you said"),
			"Claim your method after a big win and the Muckraker quotes it after the next thrashing, that season only")
	var geek: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 16,
			"result": {"home": "COL", "away": "CAR", "score": [80, 83],
			"team": [{"inside50": 54, "clearances": 36}, {"inside50": 41, "clearances": 38}]}}, {})
	_check(str(geek.get("question", "")) == "You won the inside 50s 54 to 41 and still lost by 3. What went wrong?",
			"The Stats Geek quotes a number that was true of the match (%s)" % str(geek.get("question", "")))
	var kids: Dictionary = MediaConferenceScript.pick({"club": "COL", "opponent_name": "Carlton", "round": 15, "young": 6,
			"result": {"home": "COL", "away": "CAR", "score": [88, 72]}}, {})
	_check(str(kids.get("key", "")) == "young_side" and str(kids.get("journalist", "")) == "philosopher",
			"A young side brings the Philosopher")
	var stage = VignetteScript.new()
	stage.size = Vector2(390, 300)
	stage.club = "COL"
	_check(not stage._ready, "Media vignette begins as a staged scene before the question")
	stage.finish_now()
	_check(stage._ready, "Media vignette can skip its play-in to the question")


func _test_player_goal_milestones() -> void:
	var p := {"id": "milestone_test", "name": "Milestone Test", "club": "MEL",
			"career": {"games": 12, "goals": 0, "stints": [], "through": _state.season_year - 1, "unknown": []}}
	var old_season = _state.season
	var old_tally = _state.season_tally
	var old_news = _state.news
	var SeasonScript = load("res://scripts/sim/Season.gd")
	_state.season = SeasonScript.new(["MEL", "CAR"], {"MEL": [p], "CAR": []})
	_state.season_tally = {"milestone_test": {"club": "MEL", "games": 1, "goals": 1, "goals_ha": 1}}
	_state.news = []
	_state._player_milestone_news({"home": "MEL", "away": "CAR",
			"roster": [[{"id": "milestone_test"}], []],
			"players": {"milestone_test": {"goals": 1}}})
	_check(_state.news.size() == 1 and str(_state.news[0].get("text", "")).contains("first AFL goal"),
			"A provable first AFL goal is recorded as a milestone")
	p["career"]["unknown"] = [[2020, 2021]]
	_state.news = []
	_state._player_milestone_news({"home": "MEL", "away": "CAR",
			"roster": [[{"id": "milestone_test"}], []],
			"players": {"milestone_test": {"goals": 1}}})
	_check(_state.news.is_empty(), "Unknown historical seasons never fabricate a first-goal milestone")
	_state.season = old_season
	_state.season_tally = old_tally
	_state.news = old_news

func _test_history_records_are_stored_facts() -> void:
	var old_records = _state.records
	var old_roll = _state.honour_roll
	_state.records = {"highest_score": {"value": 151, "club": "MEL", "opp": "CAR", "year": 2028},
			"biggest_win": {"value": 72, "club": "MEL", "opp": "CAR", "year": 2029}}
	_state.honour_roll = [{"year": 2028, "premier": "COL"}, {"year": 2029, "premier": "MEL"}]
	var lines: Array = _state.history_record_lines()
	_check(lines.size() == 2 and str(lines[0]).contains("151") and str(lines[1]).contains("72"),
			"History surface reads the stored league records")
	var honours: Array = _state.recent_honours(1)
	_check(honours.size() == 1 and int(honours[0]["year"]) == 2029,
			"History surface reads the stored honour roll newest first")
	_state.records = old_records
	_state.honour_roll = old_roll

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


## A short sheet is as tall as what it holds, its buttons right under the
## words; a long one fills the screen and scrolls (the director's PC
## playtest, 2026-10-07: the "Your week" sheet was mostly empty, flagged 4-5
## times). Desktop and phone sizes.
func _test_sheets_fit_their_content() -> void:
	var kit = load("res://scripts/ui/UiKit.gd")
	var before := root.size
	for dims in [Vector2i(1280, 720), Vector2i(390, 844)]:
		root.size = dims
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		await process_frame
		var short: Dictionary = kit.modal_box(host, 520.0, 0.0)
		for i in range(3):
			var l: Label = kit.lbl("A short line of help, the kind a first visit shows.", 14, kit.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(short["body"] as VBoxContainer).add_child(l)
		(short["footer"] as VBoxContainer).add_child(kit.btn("Got it", 17, true))
		var long: Dictionary = kit.modal_box(host, 520.0, 0.0)
		for i in range(80):
			(long["body"] as VBoxContainer).add_child(kit.lbl("Line %d" % i, 14, kit.TEXT))
		for i in range(6):
			await process_frame
		var view := host.get_viewport_rect().size
		var sh: Control = short["shell"]
		var lh: Control = long["shell"]
		_check(sh.size.y < view.y * 0.5, "%dx%d: a short sheet is as tall as its words (%d of %d px)" % [dims.x, dims.y, int(sh.size.y), int(view.y)])
		_check(lh.size.y > view.y * 0.8 and lh.size.y <= view.y, "%dx%d: a long sheet fills the screen and scrolls (%d of %d px)" % [dims.x, dims.y, int(lh.size.y), int(view.y)])
		host.queue_free()
		await process_frame
	root.size = before
	await process_frame


func _run() -> void:
	_test_rivalry_catalogue()
	await process_frame
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_test_history_records_are_stored_facts()
	await _test_sheets_fit_their_content()
	_test_player_goal_milestones()
	test_media_conference_rules()
	# Never touch a real career save or settings file from a test run.
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = SUITE_SEED
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
	var tagline: Label = current_scene.find_child("Tagline", true, false)
	_check(tagline != null and tagline.text == "Build your dynasty.",
			"The minimal menu uses the approved tagline")

	# --- settings: appearance and player names apply at once -----------------
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	var light_setting: Button = current_scene.find_child("SettingsAppearance_light", true, false)
	var dark_setting: Button = current_scene.find_child("SettingsAppearance_dark", true, false)
	_check(light_setting != null and dark_setting != null, "Settings offers Dark and Light appearance")
	if light_setting != null:
		light_setting.emit_signal("pressed")
		await _settle()
	var kit = load("res://scripts/ui/UiKit.gd")
	_check(_state.appearance() == "light" and kit.appearance() == "light"
			and kit.BG.r > 0.8 and _router.current() == "main",
			"Light appearance applies immediately and rebuilds the current screen")
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	dark_setting = current_scene.find_child("SettingsAppearance_dark", true, false)
	if dark_setting != null:
		dark_setting.emit_signal("pressed")
		await _settle()
	_check(_state.appearance() == "dark" and kit.appearance() == "dark"
			and kit.BG.r < 0.2, "Dark appearance restores the original palette")
	current_scene.find_child("MenuSettings", true, false).emit_signal("pressed")
	await _settle()
	var real_setting: Button = current_scene.find_child("SettingsNames_real", true, false)
	_check(real_setting != null, "Settings offers player names")
	if real_setting != null:
		real_setting.emit_signal("pressed")
		await _settle()
	_check(_state.show_real_names, "Choosing Real in Settings shows real names straight away")
	var mute_on: Button = current_scene.find_child("SettingsMuteSounds_on", true, false)
	var mute_off: Button = current_scene.find_child("SettingsMuteSounds_off", true, false)
	_check(mute_on != null and mute_off != null, "Settings offers Mute sounds")
	if mute_on != null:
		mute_on.emit_signal("pressed")
	var master_bus := AudioServer.get_bus_index("Master")
	_check(_state.sounds_muted()
			and (master_bus < 0 or AudioServer.is_bus_mute(master_bus)),
			"Mute sounds immediately mutes the Master audio bus")
	if mute_off != null:
		mute_off.emit_signal("pressed")
	_check(not _state.sounds_muted()
			and (master_bus < 0 or not AudioServer.is_bus_mute(master_bus)),
			"Sounds can be switched back on")
	_check(OS.has_feature("web") or current_scene.find_child("QuitGame", true, false) != null,
			"Quit lives in Settings")
	current_scene.find_child("SettingsNames_generated", true, false).emit_signal("pressed")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("Settings", true, false) == null
			and not _state.show_real_names, "Back closes Settings")

	# --- Club Forge: make a player, bring him into a career ------------------
	_state.set_forge_player({})
	_state.set_forge_club({})
	var size_before := root.size
	root.size = Vector2i(390, 844)
	await _settle()
	var forge_btn: Button = current_scene.find_child("ClubForge", true, false)
	_check(forge_btn != null, "The main menu has Club Forge")
	var forge_tap: String = await Tap.tap(forge_btn) if forge_btn != null else "missing"
	await _settle()
	_check(forge_tap == "" and _router.current() == "forge", "A tap opens Club Forge (%s)" % forge_tap)
	# Club Forge is opened from the menu, which was never pushed on the history:
	# its back arrow still has to leave (it did nothing).
	var forge_back: Button = current_scene.find_child("TopBarBack", true, false)
	_check(forge_back != null, "Club Forge has a back arrow")
	if forge_back != null:
		var back_tap: String = await Tap.tap(forge_back)
		await _settle()
		_check(back_tap == "" and _router.current() == "main", "A tap on Club Forge's back leaves it (%s, on %s)" % [back_tap, _router.current()])
		forge_btn = current_scene.find_child("ClubForge", true, false)
		await Tap.tap(forge_btn)
		await _settle()
	# On a PC window, your player and your club sit side by side, and a real
	# tap on Create a club opens its form (director: no full-width bars on PC).
	root.size = Vector2i(1280, 720)
	await _settle()
	var mk_p: Control = current_scene.find_child("ForgeCreatePlayer", true, false)
	var mk_c: Control = current_scene.find_child("ForgeCreateClub", true, false)
	_check(mk_p != null and mk_c != null and mk_p.get_global_rect().end.x <= mk_c.get_global_rect().position.x
			and mk_c.size.x <= root.size.x * 0.55
			and absf(mk_p.get_global_rect().position.y - mk_c.get_global_rect().position.y) < 1.0,
			"PC: the Forge puts your player and your club side by side, level")
	var club_tap: String = await Tap.tap(mk_c) if mk_c != null else "missing"
	await _settle()
	_check(club_tap == "" and current_scene.find_child("ForgeSaveClub", true, false) != null,
			"PC: a tap on Create a club opens its form (%s)" % club_tap)
	_router.handle_back(false)
	await _settle()
	root.size = Vector2i(390, 844)
	await _settle()
	_press("ForgeCreatePlayer")
	await _settle()
	_press("ForgeSavePlayer")
	await _settle()
	var problem: Label = current_scene.find_child("ForgeProblem", true, false)
	_check(problem != null and problem.visible and _state.forge_player().is_empty(),
			"A player without a name isn't saved, and the screen says why")
	_type("ForgeFirst", "Gabe")
	_type("ForgeLast", "Forge")
	_press("ForgeRole_FWD")
	await _settle()
	_press("ForgeStyle_small_forward")
	_press("ForgeStrength_goalkicking")
	await _settle()
	_press("ForgeHair_mullet")
	_press("ForgeFoot_L")
	_press("ForgeSavePlayer")
	await _settle()
	var fp: Dictionary = _state.forge_player()
	_check(str(fp.get("last", "")) == "Forge" and str(fp.get("role", "")) == "FWD" and str(fp.get("style", "")) == "small_forward"
			and (fp.get("strengths", []) as Array) == ["goalkicking"] and str(fp["look"]["hair_style"]) == "mullet"
			and str(fp.get("foot", "")) == "L",
			"The Forge saves the player as made")
	_check(current_scene.find_child("ForgePlayerName", true, false) != null, "The Forge shows your player")
	var small := []
	for b in current_scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			small.append(b.name)
	_check(small.is_empty(), "Every Forge button is thumb-sized (%s)" % str(small))

	# Create a club: a refusal, a place's name and tradition, a save.
	_press("ForgeCreateClub")
	await _settle()
	_press("ForgeSaveClub")
	await _settle()
	problem = current_scene.find_child("ForgeProblem", true, false)
	_check(problem != null and problem.visible and _state.forge_club().is_empty(),
			"A club without a name isn't saved, and the screen says why")
	_choose("ForgePlace", "port-melbourne")
	await _settle()
	var club_name: LineEdit = current_scene.find_child("ForgeClubName", true, false)
	var club_code: LineEdit = current_scene.find_child("ForgeClubCode", true, false)
	_check(club_name != null and club_name.text == "Port Melbourne" and club_code != null and club_code.text == "PM",
			"Picking a place fills in the club's name and an abbreviation")
	_type("ForgeClubNickname", "Borough")
	_type("ForgeClubCode", "pmb")
	_check(club_code != null and club_code.text == "PMB", "The abbreviation is written in capitals")
	# The director's flow (2026-10-07): the design first, then pick a colour
	# and click the part of the guernsey to paint.
	_press("ForgeDesign_hoops")
	await _settle()
	_check(current_scene.find_child("ForgeSlot_primary", true, false) == null
			and current_scene.find_child("ForgeBase_p", true, false) == null,
			"No colour slots or guernsey/pattern rows: you paint the guernsey")
	_press("ForgePart_body")
	await _settle()
	var problem_l: Label = current_scene.find_child("ForgeProblem", true, false)
	_check(problem_l != null and problem_l.visible, "Clicking the guernsey before picking a colour says what to do")
	for c in [["body", "green", "#1E6B3A"], ["body", "red", "#C8102E"], ["pattern", "gold", "#F2B231"],
			["pattern", "blue", "#1F4FA8"], ["trim", "white", "#F5F5F5"], ["trim", "gold", "#F2B231"]]:
		_press("ForgeColour_" + str(c[1]))
		await _settle()
		_press("ForgePart_" + str(c[0]))
		await _settle()
		var key: String = {"body": "primary", "pattern": "secondary", "trim": "accent"}[c[0]]
		var preview: Control = current_scene.find_child("ForgePreview", true, false)
		_check(str(current_scene.get("_club")[key]).to_upper() == str(c[2]) and preview != null
				and str(preview.get("design")) == "hoops",
				"Painting the %s %s works again and again on the same design" % [c[0], c[1]])
	var preview_now: Control = current_scene.find_child("ForgePreview", true, false)
	_check(preview_now != null and (preview_now.get("primary") as Color).is_equal_approx(Color.html("#C8102E"))
			and (preview_now.get("secondary") as Color).is_equal_approx(Color.html("#1F4FA8"))
			and (preview_now.get("accent") as Color).is_equal_approx(Color.html("#F2B231")),
			"The guernsey wears what was painted: red, blue hoops, gold trim")
	_check(_screen_text().contains("Main colour") and _screen_text().contains("Pattern colour")
			and _screen_text().contains("Trim colour"), "Each part is named with its colour")
	# Where you click on the guernsey decides what you paint.
	var crest = load("res://scripts/ui/GuernseyCrest.gd").make(Color.RED, Color.BLUE, Color.WHITE, "hoops", "", 100.0)
	crest.size = Vector2(100, 100)
	_check(crest.part_at(Vector2(50, 30)) == "body" and crest.part_at(Vector2(50, 22)) == "pattern"
			and crest.part_at(Vector2(50, 6)) == "trim" and crest.part_at(Vector2(2, 95)) == "",
			"A click lands on the body, a hoop, the collar or off the guernsey")
	crest.design = "plain"
	_check(crest.part_at(Vector2(50, 22)) == "body", "A plain guernsey has no pattern to paint")
	crest.free()
	var club_small := []
	for b in current_scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.size.y < 44:
			club_small.append(b.name)
	_check(club_small.is_empty(), "Every Create a club button is thumb-sized (%s)" % str(club_small))
	_press("ForgeSaveClub")
	await _settle()
	var fc: Dictionary = _state.forge_club()
	_check(str(fc.get("name", "")) == "Port Melbourne" and str(fc.get("short", "")) == "Borough"
			and str(fc.get("code", "")) == "PMB" and str(fc.get("location", "")) == "port-melbourne"
			and str(fc.get("ground", "")) == "North Port Oval" and str(fc.get("primary", "")).to_upper() == "#C8102E"
			and str(fc.get("design", "")) == "hoops",
			"The Forge saves the club as made (%s)" % str(fc))
	_check(current_scene.find_child("ForgeClubTitle", true, false) != null, "The Forge shows your club")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main", "Back leaves the Forge")
	root.size = size_before
	await _settle()
	# --- desktop scale (STYLE-07): the PC shows the game bigger, not emptier ---
	var layout = root.get_node("ScreenLayout")
	var dens := func(w: float, h: float, os_scale: float, dpi: int) -> float:
		return float(layout.desktop_density(Vector2(w, h), os_scale, dpi))
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 288), 3.0),
			"4K at Windows 300% (DPI 288, scale reported as 1) lays out on 1280 x 720")
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 96), 3.0),
			"4K at 100% still fits the 1280 x 720 canvas, not 3840 x 2160")
	_check(is_equal_approx(dens.call(3840, 2160, 1.0, 144), 3.0),
			"4K at 150% is not scaled twice (3, not 4.5)")
	_check(is_equal_approx(dens.call(1920, 1080, 1.0, 96), 1.5) and is_equal_approx(dens.call(2560, 1440, 1.0, 96), 2.0),
			"1080p and 1440p fit the same canvas")
	_check(is_equal_approx(dens.call(3440, 1440, 1.0, 96), 2.0),
			"Ultrawide fits by height and widens the canvas (1720 x 720)")
	_check(is_equal_approx(dens.call(1280, 720, 1.0, 96), 1.0) and is_equal_approx(dens.call(900, 600, 1.0, 96), 1.0),
			"A window at or under 1280 x 720 at 100% is drawn 1:1")
	_check(is_equal_approx(dens.call(1280, 720, 1.0, 288), 3.0),
			"A small window at 300% follows the OS scaling (the small-window floor then applies)")
	_check(is_equal_approx(dens.call(2880, 1800, 2.0, 0), 2.25),
			"A Mac reporting its own scale still fills the screen")
	# Screen size (director, 2026-10-08: the game on a 4K TV from the couch):
	# TV draws everything 1.6x bigger; Standard puts it back.
	# In a PC-sized window: the small-window floor stops a 320-wide one.
	var window_before: Vector2i = root.size
	root.size = Vector2i(1280, 720)
	layout.set_screen_size("standard")
	await _settle()
	var canvas_before: Vector2i = root.content_scale_size
	layout.set_screen_size("tv")
	await _settle()
	var canvas_tv: Vector2i = root.content_scale_size
	_check(is_equal_approx(float(layout.ui_scale), 1.6) and canvas_tv.x > 0
			and absf(float(canvas_before.x) / float(canvas_tv.x) - 1.6) < 0.05,
			"TV screen size draws the game 1.6x bigger (%s -> %s)" % [canvas_before, canvas_tv])
	layout.set_screen_size("standard")
	await _settle()
	_check(root.content_scale_size == canvas_before, "Standard puts it back")
	root.size = window_before
	await _settle()

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
	# Difficulty changes one rule, the trade margin, so every difficulty says
	# it in trade terms and nothing else (the lever-truth audit: the help once
	# promised rival development and XP that no difficulty changes).
	var only_trades := true
	for key in _state.DIFFICULTY_ORDER:
		var rules: Dictionary = _state.DIFFICULTIES[key]
		only_trades = only_trades and rules.keys().size() == 3 and rules.has("trade_margin") \
				and str(rules["text"]).contains("trade")
	_check(only_trades, "Each difficulty changes only the trade margin, and its text says so")
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "main" and current_scene.find_child("NewCareerSetup", true, false) == null
			and _state.new_career_difficulty() == "normal", "Back leaves the setup without changing anything")
	current_scene.find_child("NewCareer", true, false).emit_signal("pressed")
	await _settle()
	current_scene.find_child("Difficulty_hard", true, false).emit_signal("pressed")
	current_scene.find_child("NameMode_real", true, false).emit_signal("pressed")
	_check(current_scene.find_child("ForgedClub_in", true, false) != null, "New career offers your Forge club")
	# On a phone, where the setup form scrolls.
	var win_was := root.size
	root.size = Vector2i(390, 844)
	await _settle()
	var tut_off = current_scene.find_child("Tutorials_off", true, false)
	var tut_tap: String = await Tap.tap(tut_off) if tut_off != null else "missing"
	root.size = win_was
	await _settle()
	_check(tut_tap == "", "New career offers Tutorials On/Off, and Off takes a real tap (%s)" % tut_tap)
	current_scene.find_child("StartCareer", true, false).emit_signal("pressed")
	await _settle()
	_check(_router.current() == "draft", "Starting the career goes on to choosing a club")
	_check(_state.new_career_difficulty() == "hard" and _state.difficulty == "hard"
			and _state.show_real_names, "The career starts with the picks made")
	var brought := false
	for d in _state.draftee_pool:
		brought = brought or (str(d["id"]) == _state.custom_prospect_id and str(d.get("last", "")) == "Forge")
	_check(brought, "Your Forge player is in this career's first National Draft class")
	_state.set_setting("seen_weekly_loop_intro", false)
	_check(not _state.tutorials_on() and not _state.intro_due("weekly_loop"),
			"With Tutorials off, an unseen intro does not open by itself")
	_check(_state.draft != null and _state.draft.clubs.has("PMB") and _db.club_name("PMB") == "Port Melbourne",
			"Your Forge club is in this career's League Draft")
	_state.set_forge_player({})
	_state.set_forge_club({})
	_state.set_new_career_difficulty("normal")
	_state.set_show_real_names(false)
	_state.reset()
	# Tutorials belong to the career: kept through save and load, changed in Settings.
	_state.start_season("SYD", _db.club_list("SYD"))
	_state.set_tutorials_on(false)
	_state.save_career()
	_state.set_setting("tutorials", true)
	_state.reset()
	_check(_state.load_career() and not _state.tutorials_on(), "A career's Tutorials choice survives save and load")
	_state.set_tutorials_on(true)
	_check(_state.intro_due("weekly_loop") and _state.new_career_tutorials(),
			"Turning Tutorials back on in Settings lets unseen intros open again")
	_state.set_setting("seen_weekly_loop_intro", true)
	_check(not _state.intro_due("weekly_loop"), "...but an intro already read stays closed")
	_state.set_setting("seen_weekly_loop_intro", false)
	_state.reset()

	# The Grand Final line names the premiers first, at either end.
	var review = load("res://scripts/ui/SeasonReviewScene.gd")
	var gf_line: String = review.gf_text({"home": "BRL", "away": "FRE", "score": [61, 126],
			"goals": [8, 19], "behinds": [13, 12]}, "FRE")
	_check(gf_line.begins_with(_db.club_name("FRE")) and gf_line.contains("d.  " + _db.club_name("BRL")),
			"Season review: the Grand Final winner comes first, home or away (%s)" % gf_line)

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
	var intro: Control = current_scene.find_child("WeeklyLoopIntro", true, false)
	var skip_intro: Button = current_scene.find_child("SkipOnboarding", true, false)
	_check(intro != null and skip_intro != null
			and _screen_text().contains("This is home base")
			and _screen_text().contains("Play match")
			and _screen_text().contains("After the game"),
			"The first Hub visit explains the weekly loop in context and can be skipped")
	if skip_intro != null:
		skip_intro.emit_signal("pressed")
		await _settle()
	_check(current_scene.find_child("WeeklyLoopIntro", true, false) == null
			and bool(_state.get_setting("seen_weekly_loop_intro", false)),
			"Skipping onboarding closes it and remembers the choice")
	current_scene.call("_show_weekly_loop_intro")
	await _settle()
	_check(current_scene.find_child("WeeklyLoopIntro", true, false) == null,
			"Contextual onboarding does not nag after it has been dismissed")
	# A press conference left from the saved round follows the intro.
	var media_skip = current_scene.find_child("MediaSkip", true, false)
	if media_skip != null:
		media_skip.emit_signal("pressed")
		await _settle()
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
	# List profile: each game plan carries the strength it runs on, as a word; the two
	# strengths no plan runs on are listed under them, and a tap says who leads one.
	var hwp: Node = current_scene.find_child("HowWePlay", true, false)
	var press_tile: Node = hwp.find_child("ClubPlan_defensive", true, false) if hwp != null else null
	var press_word: Label = press_tile.find_child("Strength", true, false) if press_tile != null else null
	_check(press_word != null and press_word.text.begins_with("Pressure · "),
			"Defensive press shows the list's Pressure beside it (%s)" % (press_word.text if press_word else "-"))
	var lp: Node = current_scene.find_child("ListProfile", true, false)
	var lp_rows: Array = lp.find_children("Profile_*", "Button", true, false) if lp != null else []
	_check(lp_rows.size() == 2 and lp.find_child("Profile_finishing", true, false) != null
			and lp.find_child("Profile_aerial", true, false) != null,
			"Aerial power and Finishing, which no plan runs on, are listed under the plans (%d)" % lp_rows.size())
	var lp_text := ""
	for l in (hwp.find_children("*", "Label", true, false) if hwp != null else []):
		if (l as Label).is_visible_in_tree():
			lp_text += (l as Label).text + " "
	var digits := false
	for c in lp_text:
		digits = digits or (c >= "0" and c <= "9")
	_check(not digits and not lp_text.to_lower().contains("recommend") and not lp_text.to_lower().contains("should")
			and not lp_text.to_lower().contains("best choice") and not lp_text.to_lower().contains("suits you"),
			"The plans and strengths are words, with no advice")
	_check(lp_rows.all(func(b): return (b as Button).size.y >= 44), "Each strength is a thumb-sized tap")
	if not lp_rows.is_empty():
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
	_check(_screen_text().contains("Play Round %d?" % (r0 + 1)), "The question names the round")
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
	# A first this match settled, as the round would have kept it (Firsts.gd):
	# full time says so, now and after a reload.
	var mine_side := 0 if str(_state.last_match["home"]) == _state.my_club else 1
	var debutant: Dictionary = _state.list_player(str((_state.last_match["roster"][mine_side] as Array)[0]["id"]))
	load("res://scripts/sim/Firsts.gd").note(debutant, "debut", _state.season_year, str(_state.last_match["label"]))
	var debutant_name: String = _db.player_display_name(debutant)
	if rv != null:
		rv.emit_signal("pressed")
		await _settle()
	var ft = current_scene.find_child("FullTime", true, false)
	_check(_router.current() == "match" and ft != null, "Review match opens the full-time summary")
	var payoff = ft.find_child("PayoffLines", true, false) if ft != null else null
	var payoff_text := ""
	if payoff != null:
		for l in payoff.find_children("*", "Label", true, false):
			payoff_text += str(l.text) + "\n"
	_check(payoff != null and payoff_text.contains(debutant_name) and payoff_text.contains("debut"),
			"Full time says what the match settled: a debut (%s)" % payoff_text.strip_edges())
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
		var ptab = current_scene.find_child("StatsView_players", true, false)
		if ptab != null:
			ptab.emit_signal("pressed")
			await _settle()
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
		_check(current_scene.find_child("PayoffLines", true, false) != null,
				"...with what the match settled, kept with the career")
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
	# The round may have raised a press conference: Back skips it. One check
	# either way, so the floor does not move with the round's result.
	var had_conference: bool = current_scene.find_child("MediaConference", true, false) != null
	if had_conference:
		_router.handle_back(true)
		await _settle()
	_check(not had_conference or (_router.current() == "hub" and not _state.media_conference_pending()),
			"A press conference, if the round raised one, is skipped by Back and the hub stays")
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
	# Its first-visit sheet would take the first Back; it has been read.
	_state.set_setting("seen_season_stats_intro", true)
	_router.go("stats")
	await _settle()
	_router.handle_back(false)
	await _settle()
	_check(_router.current() == "hub", "Escape on Season stats returns to the hub")

	# --- team selection --------------------------------------------------------
	var sel_size_before := root.size
	root.size = Vector2i(390, 844)
	_router.go("selection")
	await _settle()
	_check(current_scene.find_child("AutoPick", true, false) != null, "The team screen opens")
	_check(_state.my_selection().is_empty(), "Until you move someone, the side is picked for you")
	var first_mid := str(_state.current_side()["MID"][0])
	var grid_card: Button = null
	for c in current_scene.find_child("NotSelected", true, false).get_children():
		if c is Button and load("res://scripts/sim/Ratings.gd").available(_state.list_player(str(c.get_meta("id")))):
			grid_card = c
			break
	var tap_in: String = await Tap.tap(grid_card) if grid_card != null else "missing"
	await _settle()
	var tap_c: String = await Tap.tap(current_scene.find_child("Spot_C", true, false))
	await _settle()
	_check(tap_in == "" and tap_c == "" and not _state.my_selection().is_empty()
			and not (_state.my_selection()["MID"] as Array).has(first_mid),
			"Two taps bring a player in for the centre, and the side is yours (%s, %s)" % [tap_in, tap_c])
	current_scene.call("_apply_strategy", "best")
	await _settle()
	_check(not _state.my_selection().is_empty() and current_scene.find_child("UndoPick", true, false) != null,
			"Auto-pick sets a side you can undo")
	root.size = sel_size_before
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
	# A press that turns into a scroll is neither a tap nor a long press: a
	# slow swipe through the list opens and group-selects nobody, while a
	# still hold and a still tap work as before.
	var ls: ScrollContainer = current_scene.get("_list_scroll")
	var trainees: Array = current_scene.find_children("Trainee_*", "Button", true, false)
	_check(ls != null and trainees.size() >= 2, "The training list has rows to swipe")
	# The scrollbar is a thumb you can grab: a touch area wider than the
	# engine's 8 units, a thumb never shorter than a fingertip, and the rows
	# set clear of it rather than running underneath.
	if ls != null:
		var bar := ls.get_v_scroll_bar()
		_check(bar.visible and bar.size.x >= 20.0 and bar.get_combined_minimum_size().y >= 48.0,
				"The training list's scrollbar is a finger wide and never shorter than a fingertip (%s)" % str(bar.size))
		var rows_box := ls.get_child(0) as Control
		_check(rows_box != null and rows_box.size.x <= ls.size.x - bar.size.x + 0.5,
				"The training rows stop short of the scrollbar (%.0f of %.0f)" % [rows_box.size.x if rows_box else -1.0, ls.size.x])
	# The name and plan lines sit level with the role and the rating, not
	# hugging the top of the row.
	if not trainees.is_empty():
		var first_row: Button = trainees[0]
		var stacks := first_row.find_children("*", "VBoxContainer", true, false)
		var stack: Control = stacks[0] if not stacks.is_empty() else null
		var rating: Control = stack.get_parent().get_child(-1) if stack != null else null
		if stack != null and rating != null and stack.get_child_count() > 0:
			var top := (stack.get_child(0) as Control).global_position.y
			var last := stack.get_child(-1) as Control
			var stack_mid := (top + last.global_position.y + last.size.y) * 0.5
			var rating_mid := rating.global_position.y + rating.size.y * 0.5
			_check(absf(stack_mid - rating_mid) <= 2.0,
					"A training row's name lines sit level with its rating (%.1f against %.1f)" % [stack_mid, rating_mid])
		else:
			_check(false, "A training row has its name lines and its rating to compare")
	if ls != null and trainees.size() >= 2:
		var row: Button = trainees[1]
		var pid := str(row.name).trim_prefix("Trainee_")
		row.emit_signal("button_down")
		ls.scroll_vertical += 120
		await create_timer(0.6).timeout
		# A long press that fired would have rebuilt the list and freed the row.
		if is_instance_valid(row):
			row.emit_signal("button_up")
			row.emit_signal("pressed")
		await _settle()
		_check(ls.scroll_vertical > 0 and (current_scene.get("_bulk_selected") as Dictionary).is_empty()
				and not bool(current_scene.get("_showing_detail")),
				"A slow swipe through the training list selects nobody")
		row = current_scene.find_child("Trainee_" + pid, true, false)
		if row != null:
			row.emit_signal("button_down")
			await create_timer(0.6).timeout
			if is_instance_valid(row):
				row.emit_signal("button_up")
		await _settle()
		_check((current_scene.get("_bulk_selected") as Dictionary).has(pid), "A still long press starts a group")
		current_scene.set("_bulk_selected", {})
		current_scene.call("_build")
		await _settle()
		var row2: Button = current_scene.find_child("Trainee_" + pid, true, false)
		if row2 != null:
			row2.emit_signal("button_down")
			row2.emit_signal("button_up")
			row2.emit_signal("pressed")
			await _settle()
		_check(bool(current_scene.get("_showing_detail")), "A still tap still opens the player")
		current_scene.set("_showing_detail", false)
		current_scene.call("_build")
		await _settle()
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
	var offseason_size_before := root.size
	root.size = Vector2i(360, 800)
	_router.go("offseason")
	await _settle()
	_check(_screen_text().contains("Out of contract"), "The contracts tab lists who is out of contract")
	var phone_view := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	for tab_name in ["Tab_contracts", "Tab_agents", "Tab_trade"]:
		var phone_tab: Control = current_scene.find_child(tab_name, true, false)
		_check(phone_tab != null and phone_view.encloses(phone_tab.get_global_rect())
				and phone_tab.size.y >= 40,
				"Off-season " + tab_name.trim_prefix("Tab_") + " tab fits a 360px phone")
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
			# Prefer a free agent with rival offers, to see the offers table.
			for fa in _state.free_agents:
				if not (_state.fa_offers(str(fa["id"])) as Array).is_empty():
					var row = current_scene.find_child("Agent_" + str(fa["id"]), true, false)
					if row != null and row.find_child("FreeAgentTalks", true, false) != null:
						fa_talk = row.find_child("FreeAgentTalks", true, false)
						break
			_check(fa_talk != null, "A free agent can be talked to")
			if fa_talk != null:
				var list_before: int = _state.my_list.size()
				fa_talk.emit_signal("pressed")
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) != null
						and _screen_text().contains("Cap room after this deal")
						and _state.my_list.size() == list_before,
						"Free-agent talks open the same sheet and sign nothing")
				var table = current_scene.find_child("OffersTable", true, false)
				var view_w: float = current_scene.get_viewport_rect().size.x
				_check(table != null and (table as Control).get_global_rect().end.x <= view_w + 0.5
						and _screen_text().contains("His view"),
						"Rival offers show as a table that fits the screen (%s of %d)" % [
						str((table as Control).get_global_rect().end.x) if table != null else "none", int(view_w)])
				_router.handle_back(true)
				await _settle()
				_check(current_scene.find_child("ContractTalks", true, false) == null, "Back closes free-agent talks")
	# The trade builder: one list at a time, what you give and get on top.
	var theirs_btn = null
	for n in current_scene.find_children("Their_*", "Button", true, false):
		theirs_btn = n
		break
	_check(theirs_btn != null and current_scene.find_child("TradeSide_mine", true, false) != null
			and current_scene.find_children("Mine_*", "Button", true, false).is_empty(),
			"The trade builder shows one list at a time: theirs, with yours a tap away")
	var phone_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	var builder_fits := true
	for nm in ["TradeClub", "MakeTrade", "TradeSide_theirs", "TradeSide_mine"]:
		var c: Control = current_scene.find_child(nm, true, false)
		builder_fits = builder_fits and c != null and c.get_global_rect().end.x <= phone_rect.end.x and c.size.y >= 40
	_check(builder_fits, "The trade builder's controls fit a 360px phone at thumb size")
	root.size = offseason_size_before
	await _settle()
	var theirs_now := current_scene.find_children("Their_*", "Button", true, false)
	if not theirs_now.is_empty():
		theirs_now[0].emit_signal("pressed")
		await _settle()
	current_scene.find_child("TradeSide_mine", true, false).emit_signal("pressed")
	await _settle()
	for n in current_scene.find_children("Mine_*", "Button", true, false):
		if not str(n.name).begins_with("Mine_pick_"):
			n.emit_signal("pressed")
			await _settle()
			break
	_check(current_scene.find_children("GiveRow_*", "", true, false).size() == 1
			and current_scene.find_children("GetRow_*", "", true, false).size() == 1,
			"What you give and what you get each show in their own section")
	var verdict = current_scene.find_child("TradeVerdict", true, false)
	_check(verdict != null and str(verdict.text) != "" and not str(verdict.text).contains("Put something on each side"),
			"With something on each side, their answer shows")
	var decimal := RegEx.create_from_string("\\d\\.\\d|%")
	# Money is real AFL money ("$18.44m"); anything else with a decimal or a
	# percentage would be a model value leaking out.
	var no_money := RegEx.create_from_string("\\$[0-9][0-9.,]*[mk]?").sub(_screen_text(), "", true)
	_check(decimal.search(no_money) == null, "The trade screen shows no internal values")
	_check(current_scene.find_child("TradeClubPhase", true, false) != null,
			"The trade tab says where the other club is in its cycle")
	var pick_btns := current_scene.find_children("Mine_pick_*", "Button", true, false)
	_check(pick_btns.size() >= 2 and str((pick_btns[0] as Button).text).contains("first round"),
			"Your draft picks, this year's and next, can go in a trade")
	if not pick_btns.is_empty():
		pick_btns[0].emit_signal("pressed")
		await _settle()
		var pick_row = current_scene.find_child("GiveRow_pick_*", true, false)
		_check(pick_row != null and current_scene.find_children("GiveRow_*", "", true, false).size() == 2,
				"A pick joins what you give")
		if pick_row != null:
			pick_row.find_child("Remove", true, false).emit_signal("pressed")
			await _settle()
			_check(current_scene.find_children("GiveRow_*", "", true, false).size() == 1, "Remove takes it out")
	# Changing club: every other club, two to a row; Back closes it.
	current_scene.find_child("TradeClub", true, false).emit_signal("pressed")
	await _settle()
	var club_grid = current_scene.find_child("TradeClubChoice", true, false)
	_check(club_grid != null and club_grid.get_child_count() == _db.active_clubs(_state.season_year).size() - 1
			and int(club_grid.columns) == 2, "Change club lists every other club, two to a row")
	_router.handle_back(true)
	await _settle()
	_check(_router.current() == "offseason" and current_scene.find_child("TradeClubChoice", true, false) == null
			and current_scene.find_children("GiveRow_*", "", true, false).size() == 1,
			"Back closes the club list and keeps the trade")
	current_scene.find_child("TradeClub", true, false).emit_signal("pressed")
	await _settle()
	var other_club = null
	for n in current_scene.find_child("TradeClubChoice", true, false).get_children():
		if str(n.name) != "TradeClubChoice_" + str(current_scene.get("_trade_club")):
			other_club = n
			break
	other_club.emit_signal("pressed")
	await _settle()
	_check(current_scene.find_children("GetRow_*", "", true, false).is_empty()
			and current_scene.find_children("GiveRow_*", "", true, false).size() == 1,
			"A new club clears what you'd get from the old one and keeps what you give")
	# One thing on your side and nothing on theirs: put it on the trade table.
	var table_btn = current_scene.find_child("TradeTable", true, false)
	_check(table_btn != null and not (table_btn as Button).disabled, "With one of yours and nothing back, it can go on the trade table")
	if table_btn != null:
		table_btn.emit_signal("pressed")
		await _settle()
		_check(_screen_text().contains("offer") and current_scene.find_children("GiveRow_*", "", true, false).is_empty(),
				"The trade table says who came, and clears what you give")
	# A player elsewhere who asked to be traded and named your club: a line
	# under Asked to be traded, and one tap starts the trade for him.
	var rival_code := ""
	for code in _state.season.lists:
		if str(code) != _state.my_club:
			rival_code = str(code)
			break
	var asker: Dictionary = _state.season.lists[rival_code][0]
	var keep_requests: Dictionary = (_state.trade_requests as Dictionary).duplicate(true)
	_state.trade_requests = {str(asker["id"]): {"club": rival_code, "why": "home", "to": [_state.my_club]}}
	current_scene.call("_build")
	await _settle()
	var req_btn = current_scene.find_child("RequestTrade", true, false)
	_check(current_scene.find_child("Request_" + str(asker["id"]), true, false) != null and req_btn != null,
			"A player who named your club shows under Asked to be traded")
	if req_btn != null:
		req_btn.emit_signal("pressed")
		await _settle()
	_check(str(current_scene.get("_trade_club")) == rival_code and str(current_scene.get("_theirs")) == str([str(asker["id"])]),
			"Trade for him opens the trade with his club, him on their side")
	_state.trade_requests = keep_requests
	current_scene.call("_build")
	await _settle()
	# Picking a player rebuilds the tab but keeps your place in a long list.
	var box: ScrollContainer = current_scene.get("_scroll_box")
	box.scroll_vertical = 600
	await _settle()
	var held := box.scroll_vertical
	var deep = null
	for n in current_scene.find_children("Mine_*", "Button", true, false):
		deep = n
	var found: bool = deep != null
	if found:
		deep.emit_signal("pressed")
		await _settle()
		await _settle()
	var after: ScrollContainer = current_scene.get("_scroll_box")
	_check(held > 0 and found and absi(after.scroll_vertical - held) <= 4,
			"Picking a player keeps the trade list where it was (%d then %d)" % [held, after.scroll_vertical])
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
			and current_scene.find_child("OptionsNewCareer", true, false) != null
			and current_scene.find_child("OptionsVersion", true, false) != null,
			"Settings in a career has speed, main menu, New career and version")
	if eight != null:
		eight.emit_signal("pressed")
		await _settle()
	_check(is_equal_approx(_state.match_speed(), 8.0), "Match speed is remembered")
	_state.set_match_speed(4.0)
	_check(_state.save_career(), "The career is saved before the destructive-action tests")
	var new_from_settings: Button = current_scene.find_child("OptionsNewCareer", true, false)
	if new_from_settings != null:
		new_from_settings.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "main"
			and current_scene.find_child("NewCareerSetup", true, false) != null
			and _state.has_saved_career(),
			"New career opens setup without deleting the current save")
	_router.handle_back(false)
	await _settle()
	var saved_continue: Button = current_scene.find_child("ContinueCareer", true, false)
	if saved_continue != null:
		saved_continue.emit_signal("pressed")
		await _settle()
	_check(_router.current() == "hub" and _state.season != null,
			"Backing out of New career can still resume the saved career")
	hub_settings = current_scene.find_child("HubSettings", true, false)
	if hub_settings != null:
		hub_settings.emit_signal("pressed")
		await _settle()
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

	await _test_season_awards()
	await _test_back_arrow_taps()
	_test_type_roles()
	await _test_names_fit()
	_state.delete_saved_career()
	print("Career UI tests: %d checks, %d failures" % [_checks, _failures.size()])
	_state.replay_seed = 0
	quit(0 if _failures.is_empty() else 1)


## The top bar's back arrow, tapped as a finger taps it, leaves every screen -
## first closing a first-visit help sheet over it, as Android's Back does
## (director, 2026-10-09: "back doesn't always work, I need to swipe": the
## Training and Season stats intros took the tap and did nothing).
func _test_back_arrow_taps() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_state.set_setting("seen_season_stats_intro", false)
	for key in ["training", "stats", "selection", "list"]:
		_router.stack = ["main", "hub"]
		_router.go(key)
		await _settle()
		var b: Control = current_scene.find_child("TopBarBack", true, false)
		var why: String = await Tap.tap(b) if b != null else "no back arrow"
		await _settle()
		if _router.current() == key and is_instance_valid(b):
			why = await Tap.tap(b)
			await _settle()
		_check(_router.current() == "hub", "Tapping back on %s gets you out (%s)" % [key, why if why != "" else "ok"])


func _test_season_awards() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	var player: Dictionary = _state.my_list[0]
	var row := {"id": str(player["id"]), "club": "COL", "votes": 24, "goals": 71, "bf": 118, "slot": "MID"}
	_state.season_awards = {"year": 2027, "brownlow": [row], "coleman": [row],
		"all_australian": [row], "best_and_fairest": {"COL": [row]}}
	var before := var_to_str(_state.season_awards)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	root.size = Vector2i(360, 800)
	var ceremony: Control = load("res://scripts/ui/SeasonAwards.gd").open(host)
	await _settle()
	var next: Button = ceremony.find_child("AwardsNext", true, false)
	_check(next != null and next.size.y >= 44, "Awards actions remain thumb sized")
	next.emit_signal("pressed")
	await _settle()
	var scene: Control = ceremony.find_child("AwardWinner", true, false)
	_check(scene != null and scene.club == "COL", "The stored winner supplies the vignette club")
	_check(scene.number == int(player["num"]), "The winner retains his actual jumper number")
	for width in [320, 360, 430]:
		root.size = Vector2i(width, 800)
		await _settle()
		var button_rect := next.get_global_rect()
		_check(button_rect.position.x >= 0 and button_rect.end.x <= width and button_rect.end.y <= 800,
			"Awards footer remains reachable at %d portrait width" % width)

	next.emit_signal("pressed")
	_check(scene._done, "A tap completes the winner animation without advancing the award")
	_check(var_to_str(_state.season_awards) == before, "Revealing awards does not mutate votes or results")
	for i in range(20):
		if not is_instance_valid(ceremony):
			break
		next.emit_signal("pressed")
		await _settle()
	_check(not is_instance_valid(ceremony) and _state.season_awards.get("presentation_seen", false),
		"Completing awards records viewing and returns to review")
	_check(_state.save_career(), "Awards viewed state saves")
	_check(_state.load_career() and _state.season_awards.get("presentation_seen", false), "Awards viewed state survives reload")
	ceremony = load("res://scripts/ui/SeasonAwards.gd").open(host)
	await _settle()
	ceremony.find_child("AwardsSkip", true, false).emit_signal("pressed")
	await _settle()
	_check(not is_instance_valid(ceremony), "Replay can skip straight to review")
	for code in _db.CLUB_ORDER:
		var winner: Control = load("res://scripts/ui/match/AwardWinnerVignette.gd").new()
		host.add_child(winner)
		winner.setup_winner(code, 7)
		winner.finish_now()
		_check(winner._colours[0] == _db.club_marker_colours(code), "%s uses genuine club colours" % code)
		winner.queue_free()
	host.queue_free()
	await _settle()


## Press a named button in the current scene, or fail the check if it is missing.
func _press(node_name: String) -> void:
	var b = current_scene.find_child(node_name, true, false)
	_check(b != null, "%s is on screen" % node_name)
	if b != null:
		b.emit_signal("pressed")


## Pick the option whose metadata is `value` in an OptionButton.
func _choose(node_name: String, value: String) -> void:
	var o = current_scene.find_child(node_name, true, false)
	_check(o != null, "%s is on screen" % node_name)
	if o == null:
		return
	for i in (o as OptionButton).item_count:
		if str((o as OptionButton).get_item_metadata(i)) == value:
			(o as OptionButton).select(i)
			(o as OptionButton).item_selected.emit(i)
			return
	_check(false, "%s offers %s" % [node_name, value])


func _type(node_name: String, text: String) -> void:
	var f = current_scene.find_child(node_name, true, false)
	_check(f != null, "%s is on screen" % node_name)
	if f != null:
		(f as LineEdit).text = text
		(f as LineEdit).text_changed.emit(text)


## Type roles (docs/VISUAL_STYLE_GUIDE.md §2.3): a screen never sets a font size
## that is not one of UiKit's roles. A literal outside UiKit.SIZES in any UiKit
## text call, or in a font_size override, fails here with the file and line.
func _test_type_roles() -> void:
	var sizes: Array = load("res://scripts/ui/UiKit.gd").SIZES
	var call := RegEx.new()
	call.compile("UiKit\\.(lbl|line|ellipsis|figure|heading|btn|name_label)\\(")
	var num := RegEx.new()
	num.compile("[,(]\\s*(\\d{1,2})\\s*[,)]")
	var override := RegEx.new()
	override.compile("font_size\", (\\d{1,2})")
	var bad: Array[String] = []
	var files := _gd_files("res://scripts/ui")
	for path in files:
		if path.ends_with("UiKit.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		var n := 0
		for line in text.split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"):
				continue
			var hits: Array = []
			if call.search(line) != null:
				for m in num.search_all(line):
					hits.append(int(m.get_string(1)))
			for m in override.search_all(line):
				hits.append(int(m.get_string(1)))
			for h in hits:
				if h >= 6 and not sizes.has(h):
					bad.append("%s:%d size %d" % [path.get_file(), n, h])
	_check(files.size() > 20, "The type-role check saw the screens (%d files)" % files.size())
	_check(bad.is_empty(), "Every text size on every screen is a UiKit role: %s" % str(bad.slice(0, 8)))


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_gd_files(dir + "/" + f))
		elif f.ends_with(".gd"):
			out.append(dir + "/" + f)
		f = d.get_next()
	return out


## A name never truncates (guide §4.2): every row's name label is a UiKit
## name_label (wraps to two lines) and, at 360 wide, none needs a third. Checked
## on Training and the League Draft, the two lists that cut names before.
func _test_names_fit() -> void:
	_state.reset()
	_state.start_season("WBD", _db.club_list("WBD"))
	_state.set_setting("seen_training_intro", true)
	var was := root.size
	root.size = Vector2i(360, 800)
	_router.stack = ["main", "hub"]
	_router.go("training")
	await _settle()
	await _settle()
	var names: Array = []
	_find_named(current_scene, "Name", names)
	_check(names.size() >= 10, "Training rows lead with name labels (%d found at 360 wide)" % names.size())
	var cut: Array[String] = []
	for l in names:
		var lab := l as Label
		if lab.get_line_count() > 2:
			cut.append(lab.text)
		if lab.get_line_count() > lab.get_visible_line_count():
			cut.append(lab.text + " (clipped)")
	_check(cut.is_empty(), "No Training name needs a third line or is clipped at 360 wide: %s" % str(cut))
	root.size = was


func _find_named(n: Node, named: String, out: Array) -> void:
	if n.name == named and n is Label and (n as Label).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_find_named(c, named, out)
