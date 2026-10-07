extends SceneTree
## godot --headless --path . --script tests/run_stats_tests.gd
## Season stats (the Stats patch, ROADMAP §1.11): the hub's Season stats
## button, every section, and the numbers behind them.
const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2031

var _state: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_stats.save"
	_state.settings_path = "user://test_stats_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = SUITE_SEED
	var ev = load("res://tests/test_stats_events.gd").new()
	ev.run()
	_checks += ev.checks
	_failures.append_array(ev.failures)
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	# Before any round: no press conference sits over the hub.
	await _hub_button()
	for i in range(4):
		_state.advance()
	await _sections()
	await _trophies()
	print("Stats tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The hub's Season stats button takes a tap and opens the hub.
func _hub_button() -> void:
	root.size = Vector2i(1280, 720)
	_state.set_setting("seen_weekly_loop_intro", true)
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	var b: Button = hub.find_child("SeasonStats", true, false)
	_check(b != null and hub.find_child("FullLadder", true, false) == null,
			"The hub offers Season stats in place of Full ladder")
	if b != null:
		var got := await Tap.tap(b)
		_check(got == "", "Season stats takes a tap (%s)" % got)
	hub.queue_free()
	await _settle()


## Every section opens, at a phone's width and a PC's.
func _sections() -> void:
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = sz
		var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
		root.add_child(s)
		await _settle()
		for key in ["ladder", "players", "awards", "fixture", "trophies"]:
			var t: Button = s.find_child("Section_" + key, true, false)
			_check(t != null, "Season stats has a %s section (%dx%d)" % [key, sz.x, sz.y])
			if t == null:
				continue
			_check((await Tap.tap(t)) == "", "The %s tab takes a tap (%dx%d)" % [key, sz.x, sz.y])
			await _settle()
			var body: Node = s.find_child("SectionBody", true, false)
			_check(body != null and body.get_child_count() == 1, "The %s section builds (%dx%d)" % [key, sz.x, sz.y])
		s.queue_free()
		await _settle()


# ---------------------------------------------------------------------------
# Trophy room
# ---------------------------------------------------------------------------
func _open_trophies(sz: Vector2i) -> Control:
	root.size = sz
	load("res://scripts/ui/StatsHubScene.gd").current = "trophies"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	return s


## The trophy room through a first season and into a seeded second: empty
## and honest at first, then a premiership on the shelf, only your club's
## seasons counted, older entries said plainly, taps and Back, save and load.
func _trophies() -> void:
	var year: int = _state.season_year
	var s := await _open_trophies(Vector2i(390, 844))
	var none: Label = s.find_child("NoPremierships", true, false)
	_check(none != null and none.text == "No premierships yet.", "An empty trophy room says so: no premierships yet")
	_check(s.find_child("NoPlayerHonours", true, false) != null, "No player honours yet, said plainly")
	var intro: Label = s.find_child("TrophiesTenure", true, false)
	_check(intro != null and intro.text == "Your time at %s: 1 season, from %d." % [root.get_node("GameDB").club_name("COL"), year],
			"The tenure line counts the season in progress (%s)" % (intro.text if intro else "none"))
	var now: Node = s.find_child("Season_%d" % year, true, false)
	_check(now != null and _row_text(now).contains("In progress"), "This season is in the table, in progress")
	s.queue_free()
	await _settle()
	# Play the season out: its honour roll entry records your season.
	var guard := 0
	while not _state.season_is_over() and guard < 40:
		_state.advance()
		guard += 1
	var entry: Dictionary = _state.honour_roll.back() if not _state.honour_roll.is_empty() else {}
	_check(int(entry.get("year", 0)) == year and str(entry.get("my_club", "")) == "COL",
			"The finished season is on the honour roll")
	_check(str(entry.get("my_record", "")) == _state.my_record() and str(entry.get("my_record", "")).split("-").size() == 3,
			"The season's record is kept (%s)" % str(entry.get("my_record", "")))
	var tags := {}
	for week in _state.season.finals.get("weeks", []):
		for res in week:
			if _state.is_my_match(res):
				tags[str(res["tag"])] = true
	_check(entry.has("my_finals") and (str(entry["my_finals"]) == "" if tags.is_empty() else tags.has(str(entry["my_finals"]))),
			"How far the finals went is kept (%s)" % str(entry.get("my_finals", "missing")))
	var aa_ok: bool = entry.has("my_aa")
	for r in _state.season_awards.get("all_australian", []):
		if (str(r["club"]) == "COL") != (entry.get("my_aa", []) as Array).has(str(r["id"])):
			aa_ok = false
	_check(aa_ok, "Your club's All-Australians are kept, and only yours")
	# Seed the rest: a season coaching elsewhere (never yours to count), an
	# older entry without the new keys, and this season as a premiership.
	var ids := []
	for p in _state.season.lists["COL"]:
		ids.append(str(p["id"]))
	entry["premier"] = "COL"
	entry["runner_up"] = "CAR"
	entry["my_position"] = 1
	entry["my_aa"] = [ids[2]]
	entry["brownlow"] = [{"id": ids[0], "club": "COL", "votes": 31}]
	for key in ["coleman", "rising_star", "coaches_award", "my_bf"]:
		entry[key] = []
	var old := {"year": year - 1, "my_club": "COL", "premier": "GEE", "runner_up": "COL", "my_position": 3,
		"brownlow": [], "coleman": [{"id": "far_away", "club": "CAR", "goals": 70}], "rising_star": [],
		"coaches_award": [], "my_bf": [{"id": ids[1], "club": "COL", "bf": 120}]}
	var elsewhere := {"year": year - 2, "my_club": "CAR", "premier": "COL", "runner_up": "GEE", "my_position": 1,
		"brownlow": [{"id": ids[3], "club": "COL", "votes": 40}], "coleman": [], "rising_star": [],
		"coaches_award": [], "my_bf": [], "my_record": "20-3-0", "my_finals": "GF1", "my_aa": []}
	_state.honour_roll = [elsewhere, old, entry]
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		s = await _open_trophies(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		intro = s.find_child("TrophiesTenure", true, false)
		_check(intro != null and intro.text.ends_with("2 seasons, from %d." % (year - 1)),
				"Only seasons at your club count (%s: %s)" % [tag, intro.text if intro else "none"])
		var flag: Button = s.find_child("Club_premiership_%d" % year, true, false)
		_check(flag != null and s.find_child("Club_minor_premiership_%d" % year, true, false) != null,
				"The premiership and minor premiership are on the shelf (%s)" % tag)
		_check(s.find_child("Club_premiership_%d" % (year - 2), true, false) == null
				and s.find_child("NoPremierships", true, false) == null,
				"A flag from before your time isn't yours (%s)" % tag)
		_check(flag != null and (flag.find_child("Honour_premiership_cup", true, false) != null
				or flag.find_child("StandIn_premiership_cup", true, false) != null),
				"The cup shows: its art, or its name standing in (%s)" % tag)
		var shelf: Node = s.find_child("PlayerShelf", true, false)
		var names := []
		if shelf != null:
			for b in shelf.get_children():
				names.append(str((b.find_child("Bottom", true, false) as Label).text))
		_check(names == ["Brownlow Medal %d" % year, "All-Australian %d" % year, "Best and fairest %d" % (year - 1)],
				"Your players' honours, newest first, none from elsewhere (%s: %s)" % [tag, str(names)])
		var gap: Label = s.find_child("AAUnrecorded", true, false)
		_check(gap != null and gap.text == "All-Australian selections weren't kept for %d in this save." % (year - 1),
				"An older season's missing All-Australians are said plainly (%s)" % tag)
		var rec: Label = s.find_child("RecordUnrecorded", true, false)
		_check(rec != null and rec.text.contains(str(year - 1)) and s.find_child("FinalsUnrecorded", true, false) == null,
				"A missing record is said plainly; a known Grand Final needs no such line (%s)" % tag)
		var row: Node = s.find_child("Season_%d" % year, true, false)
		_check(row != null and _row_text(row).contains("Premiers") and _row_text(row).contains("1st"),
				"Your premiership season reads 1st and Premiers (%s)" % tag)
		var old_row: Node = s.find_child("Season_%d" % (year - 1), true, false)
		_check(old_row != null and _row_text(old_row).contains("Runners-up"), "The older season reads Runners-up (%s)" % tag)
		# Everything fits the screen across.
		var fits := true
		for c in s.find_child("StatsTrophies", true, false).find_children("*", "Control", true, false):
			if (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().end.x > sz.x + 1:
				fits = false
		_check(fits, "The trophy room fits across the screen (%s)" % tag)
		# A finger on the flag opens it; Back closes it first, then leaves.
		if flag != null:
			_check((await Tap.tap(flag)) == "", "The premiership takes a tap (%s)" % tag)
			await _settle()
			var sheet: Node = s.find_child("ClubHonourSheet", true, false)
			var title: Label = sheet.find_child("SheetTitle", true, false) if sheet != null else null
			_check(title != null and title.text == "Premiers %d" % year, "Its sheet opens on the premiership (%s)" % tag)
			_check(s.call("handle_back"), "Back closes the sheet first (%s)" % tag)
			await _settle()
			_check(s.find_child("ClubHonourSheet", true, false) == null and not s.call("handle_back"),
					"The sheet is gone, and the next Back leaves (%s)" % tag)
		var medal: Button = s.find_child("Player_0", true, false)
		if medal != null:
			_check((await Tap.tap(medal)) == "", "The Brownlow takes a tap (%s)" % tag)
			await _settle()
			var line: Label = s.find_child("SheetLine_1", true, false)
			_check(line != null and line.text == "31 votes.", "The sheet gives the count with its unit (%s)" % tag)
			s.call("handle_back")
			await _settle()
		s.queue_free()
		await _settle()
	# The room survives a save and load.
	var before := JSON.stringify(_state.honour_roll)
	_check(_state.save_career() and _state.load_career(), "The career saves and loads")
	_check(JSON.stringify(_state.honour_roll) == before, "The honour roll, new keys and all, survives a save and load")
	s = await _open_trophies(Vector2i(390, 844))
	_check(s.find_child("Club_premiership_%d" % year, true, false) != null, "The premiership is still on the shelf after loading")
	s.queue_free()
	await _settle()


func _row_text(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " "
	return out


func _settle() -> void:
	for i in range(4):
		await process_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		push_error(what)
