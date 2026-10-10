extends SceneTree
## godot --headless --path . --script tests/run_stats_tests.gd
## Season stats (the Stats patch, ROADMAP §1.11): the hub's Season stats
## button, every section, and the numbers behind them.
const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2031

var _state: Node
# Loaded, not named: a SceneTree script compiles before the autoloads exist.
var _SB
var _CA
## Loaded at run time: in --script mode a class that reads an autoload
## (GameDB) cannot compile into this script.
var _aw
var _cs
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_SB = load("res://scripts/sim/StatBook.gd")
	_CA = load("res://scripts/sim/Career.gd")
	_aw = load("res://scripts/sim/Awards.gd")
	_cs = load("res://scripts/state/CareerSave.gd")
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
	await _intro()
	await _hub_button()
	await _awards_early()
	await _trophies_unplayed()
	for i in range(4):
		_state.advance()
	await _sections()
	# The awards read the season after four rounds: before anything below
	# plays it on (the fixture's finals test plays it to the end).
	await _awards_races()
	await _awards_ties()
	_rising_star_rules()
	await _rising_star_saves()
	await _awards_awarded()
	await _players_section()
	_club_per_game()
	_season_book()
	_book_rates()
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _fixture(sz)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _ladder(sz)
	await _trophies_early()
	await _fixture_finals()
	await _trophies()
	print("Stats tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The first visit explains the hub in two lines, once; "Got it" closes it.
func _intro() -> void:
	root.size = Vector2i(390, 844)
	_state.set_setting("seen_season_stats_intro", false)
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	var intro: Node = s.find_child("SeasonStatsIntro", true, false)
	var ok: Button = s.find_child("SeasonStatsIntroOk", true, false)
	_check(intro != null and ok != null, "The first visit to Season stats explains it")
	if ok != null:
		_check((await Tap.tap(ok)) == "", "Got it takes a tap")
		await _settle()
	_check(s.find_child("SeasonStatsIntro", true, false) == null
			and bool(_state.get_setting("seen_season_stats_intro", false)), "...and closes it for good")
	s.queue_free()
	await _settle()
	var again: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(again)
	await _settle()
	_check(again.find_child("SeasonStatsIntro", true, false) == null, "The next visit goes straight to the stats")
	again.queue_free()
	await _settle()


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
		if sz.x < 900:
			var all_in := true
			for key in ["ladder", "players", "awards", "fixture", "trophies"]:
				var tb: Control = s.find_child("Section_" + key, true, false)
				if tb == null or tb.get_global_rect().end.x > sz.x + 1 or tb.get_global_rect().position.x < -1:
					all_in = false
			_check(all_in and s.find_child("SectionStrip", true, false) == null,
					"Five short tabs fit one row on a phone, none cut and no sideways scroll (%dx%d)" % [sz.x, sz.y])
			_check(s.find_child("Section_trophies", true, false).text == "Trophies"
					and s.find_child("Section_players", true, false).text == "Players",
					"...with short names: Players, Trophies (%dx%d)" % [sz.x, sz.y])
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


## Players: every player's season. A phone shows one stat at a time as a
## leaderboard (rank, guernsey, full name, one big figure); a wide screen the
## table with words in its headings. Per game, a rate's qualifiers, filters in
## a sheet, and a tap away from his season and career.
func _players_section() -> void:
	var SP = load("res://scripts/ui/stats/StatsPlayers.gd")
	var Hub = load("res://scripts/ui/StatsHubScene.gd")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		var wide: bool = sz.x >= 900
		var list_name := "PlayersTable" if wide else "PlayersBoard"
		root.size = sz
		SP.reset_view()
		Hub.current = "players"
		var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
		root.add_child(s)
		await _settle()
		var table: Node = s.find_child(list_name, true, false)
		var rows := s.find_children("PlayerRow_*", "Button", true, false)
		_check(table != null and rows.size() == mini(SP.PAGE, (SP.rows() as Array).size()),
				"Players lists the competition's players, a page at a time (%s, %d rows)" % [tag, rows.size()])
		_check((s.find_child("PlayersTable", true, false) == null) == (not wide),
				"A phone shows the leaderboard, a wide screen the table (%s)" % tag)
		# The list is the season book, most disposals first.
		var cells := _column(s, "disposals")
		_check(_descending(cells) and not cells.is_empty(), "Sorted by disposals, most first (%s)" % tag)
		var top: Dictionary = SP.sorted_rows()[0]
		_check(not cells.is_empty() and int(cells[0]) == int(_SB.total(_state.season_stats[top["id"]], "disposals")),
				"The top row's disposals are his season total (%s)" % tag)
		var pick: Button = s.find_child("StatPick", true, false)
		_check(pick != null and pick.text == "Disposals", "The stat is chosen by its name (%s: %s)" % [tag, pick.text if pick else "-"])
		# The stats open as a sheet that scrolls under a finger, with Player
		# rating in it; a real tap on it ranks by it and closes the sheet.
		_check(pick != null and (await Tap.tap(pick)) == "", "The stat picker takes a tap (%s)" % tag)
		await _settle()
		var stat_sheet: Control = s.find_child("StatSheet", true, false)
		var in_scroll := false
		var pr: Button = stat_sheet.find_child("Stat_rating", true, false) if stat_sheet else null
		var last_stat: Button = stat_sheet.find_child("Stat_clangers", true, false) if stat_sheet else null
		var above: Node = last_stat
		var sc: ScrollContainer = null
		while above != null and above != stat_sheet:
			if above is ScrollContainer:
				in_scroll = true
				sc = above
			above = above.get_parent()
		_check(stat_sheet != null and pr != null and last_stat != null and in_scroll,
				"Every stat is in a scrolling sheet, down to the last (%s)" % tag)
		# The list is longer than the screen: a finger's drag moves it.
		var moved := false
		if sc != null and sc.get_v_scroll_bar().max_value > sc.size.y + 1.0:
			var mid := sc.get_global_rect().get_center()
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.position = mid
			press.pressed = true
			Input.parse_input_event(press)
			Input.flush_buffered_events()
			await process_frame
			for step in range(6):
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = mid - Vector2(0, 40.0 * float(step + 1))
				drag.relative = Vector2(0, -40.0)
				Input.parse_input_event(drag)
				Input.flush_buffered_events()
				await process_frame
			var lift := InputEventScreenTouch.new()
			lift.index = 0
			lift.position = mid - Vector2(0, 240.0)
			lift.pressed = false
			Input.parse_input_event(lift)
			Input.flush_buffered_events()
			await _settle()
			moved = sc.scroll_vertical > 0
			_check(moved and s.find_child("StatSheet", true, false) != null and SP._sort == "disposals",
					"A finger's drag scrolls the stat list without picking a stat (%s: %d)" % [tag, sc.scroll_vertical])
		else:
			_check(sc != null and wide, "Only a wide screen fits the stat list without scrolling (%s)" % tag)
		_check(pr != null and (await Tap.tap(pr)) == "", "Player rating takes a tap (%s)" % tag)
		await _settle()
		pick = s.find_child("StatPick", true, false)
		var by_rating: Array = SP.sorted_rows()
		# Ranked by Player rating, the list opens on Per game (director, 2026-10-11).
		var mode_row: Node = s.find_child("StatMode", true, false)
		_check(SP._per_game and mode_row != null and mode_row.has_meta("current")
				and str((mode_row.get_meta("current") as Node).name) == "StatMode_per_game",
				"Ranked by Player rating, the list opens on Per game (%s)" % tag)
		var want := 0.0
		var points: Dictionary = load("res://scripts/ui/match/MatchNotes.gd").RATING_POINTS
		for k in points:
			want += float(points[k]) * float((by_rating[0]["s"] as Dictionary).get(k, 0.0))
		_check(s.find_child("StatSheet", true, false) == null and pick != null and pick.text == "Player rating"
				and by_rating.size() > 1 and is_equal_approx(SP.value(by_rating[0], "rating", false), maxf(0.0, want))
				and SP.value(by_rating[0], "rating", true) >= SP.value(by_rating[1], "rating", true)
				and SP.value(by_rating[0], "rating", false) > 0.0,
				"Player rating ranks the season by the match rating's points (%s: %s)" % [tag, pick.text if pick else "-"])
		SP.pick_stat("disposals")
		s.call("refresh")
		await _settle()
		await _settle()
		if wide:
			# Words in the headings, and a real tap on one reverses it.
			var head: Button = s.find_child("Sort_disposals", true, false)
			_check(head != null and head.text.begins_with("Disposals") and s.find_child("Sort_efficiency", true, false).text.begins_with("Disposal efficiency")
					and s.find_child("Sort_kh", true, false) == null,
					"The table's headings are words, not codes (%s)" % tag)
			# Each group's name spans its own columns, from the first to the last.
			var span: Control = s.find_child("PlayersGroup_Disposals", true, false)
			var first: Control = s.find_child("Sort_disposals", true, false)
			var last: Control = s.find_child("Sort_efficiency", true, false)
			_check(span != null and first != null and last != null
					and absf(span.global_position.x - first.global_position.x) <= 1.0
					and absf(span.get_global_rect().end.x - last.get_global_rect().end.x) <= 1.0,
					"A group's name and its rule span just its columns (%s)" % tag)
			_check(head != null and (await Tap.tap(head)) == "", "The disposals heading takes a tap (%s)" % tag)
			await _settle()
			cells = _column(s, "disposals")
			_check(_ascending(cells), "A second tap sorts fewest first (%s)" % tag)
		else:
			# His full name, never cut, with his club and games under it.
			var first_row: Node = s.find_children("PlayerRow_*", "Button", true, false)[0]
			var nm: Label = first_row.find_child("Name", true, false)
			_check(nm != null and nm.text == str(top["name"]) and nm.get_line_count() <= 2,
					"A row shows the player's full name (%s: %s)" % [tag, nm.text if nm else "-"])
			var meta := _text(first_row.find_child("Meta", true, false))
			_check(meta.contains(str(top["club"])) and meta.contains("game"), "...with his club and games under it (%s: %s)" % [tag, meta])
			_check(_text(first_row.find_child("Under", true, false)).ends_with("a game"),
					"...and the figure a game under his total (%s)" % tag)
		# Per game: one toggle, by finger.
		var pg: Button = s.find_child("StatMode_per_game", true, false)
		_check(pg != null and (await Tap.tap(pg)) == "", "Per game takes a tap (%s)" % tag)
		await _settle()
		var one: Node = s.find_child("Cell_disposals", true, false)
		_check(one != null and str(one.text).contains("."), "Per game shows a figure a game (%s: %s)" % [tag, one.text if one else "-"])
		pg = s.find_child("StatMode_per_game", true, false)
		var tot: Node = s.find_child("StatMode_total", true, false)
		_check(tot != null and pg != null and tot.get_parent() == pg.get_parent() and str(pg.get_parent().name) == "StatMode",
				"Totals and per game are one line of words (%s)" % tag)
		_check(tot != null and (await Tap.tap(tot)) == "", "Totals takes a tap back (%s)" % tag)
		await _settle()
		var back: Node = s.find_child("Cell_disposals", true, false)
		_check(back != null and not str(back.text).contains("."), "Totals shows whole numbers again (%s: %s)" % [tag, back.text if back else "-"])
		pg = s.find_child("StatMode_per_game", true, false)
		await Tap.tap(pg)
		await _settle()
		# A rate: only those with enough shots rank, and the list says so.
		SP.pick_stat("accuracy")
		s.call("refresh")
		await _settle()
		_check(s.find_child("PlayersQualify", true, false) != null, "A rate says who it ranks (%s)" % tag)
		if wide:
			_check(s.find_child("Sort_goals", true, false) != null, "The table shows the rate's group (%s)" % tag)
		var ranked: Array = SP.sorted_rows()
		var seen_unqualified := false
		var order_ok := true
		for r in ranked:
			var q: bool = SP.qualifies(r, "accuracy")
			if not q:
				seen_unqualified = true
			elif seen_unqualified:
				order_ok = false
		_check(order_ok, "Players without enough shots come after those ranked by accuracy (%s)" % tag)
		# Filters: a sheet, by finger; Done closes it.
		var fb: Button = s.find_child("FiltersToggle", true, false)
		_check(fb != null and (await Tap.tap(fb)) == "", "Filters takes a tap (%s)" % tag)
		await _settle()
		var fsheet: Node = s.find_child("FiltersSheet", true, false)
		_check(fsheet != null and fsheet.find_child("Filter_club", true, false) != null
				and fsheet.find_child("Filter_games", true, false) != null, "Filters open as a sheet (%s)" % tag)
		var done: Button = s.find_child("FiltersDone", true, false)
		_check(done != null and (await Tap.tap(done)) == "", "Done takes a tap (%s)" % tag)
		await _settle()
		_check(s.find_child("FiltersSheet", true, false) == null, "...and closes the sheet (%s)" % tag)
		# One club, then reset.
		SP.set_filter("club", "COL")
		s.call("refresh")
		await _settle()
		var clubs_ok := true
		for r in SP.rows():
			if str(r["club"]) != "COL":
				clubs_ok = false
		_check(clubs_ok and s.find_child("ActiveFilters", true, false) != null, "A club filter shows that club only, and says so (%s)" % tag)
		var reset: Button = s.find_child("FiltersReset", true, false)
		_check(reset != null and (await Tap.tap(reset)) == "", "Reset takes a tap (%s)" % tag)
		await _settle()
		_check(s.find_child("ActiveFilters", true, false) == null, "Reset clears the filters (%s)" % tag)
		# Every listed player includes those yet to play, shown as nothing.
		var played_count: int = (SP.rows() as Array).size()
		SP.set_filter("games", "0")
		var all_rows: Array = SP.rows()
		var zero := false
		for r in all_rows:
			if int(r["games"]) == 0:
				zero = true
				_check(SP.fmt(SP.value(r, "disposals", true), "disposals", true) == "–", "A player yet to play has no per-game figure (%s)" % tag)
				break
		_check(zero and all_rows.size() > played_count, "Every listed player includes those yet to play (%d of %d, %s)" % [all_rows.size(), played_count, tag])
		SP.reset_view()
		s.call("refresh")
		await _settle()
		# Nothing runs off the screen.
		var spill := ""
		for c in s.find_children("*", "Label", true, false):
			if c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
				spill = str(c.name)
				break
		_check(spill == "", "Players fit the screen (%s%s)" % [tag, (": " + spill) if spill != "" else ""])
		# A player's season and career, then back.
		var first: Button = s.find_children("PlayerRow_*", "Button", true, false)[0]
		_check((await Tap.tap(first)) == "", "A player's row takes a tap (%s)" % tag)
		await _settle()
		var sheet: Node = s.find_child("PlayerStatsSheet", true, false)
		_check(sheet != null and sheet.find_child("PlayerSeasonGrid", true, false) != null
				and sheet.find_child("PlayerCareer", true, false) != null,
				"The tap opens his season and his career (%s)" % tag)
		_check(s.call("handle_back") == true, "Back closes his sheet (%s)" % tag)
		await _settle()
		_check(s.find_child("PlayerStatsSheet", true, false) == null and s.find_child(list_name, true, false) != null,
				"...and leaves the list as it was (%s)" % tag)
		s.queue_free()
		await _settle()


func _column(s: Node, key: String) -> Array:
	var out := []
	for row in s.find_children("PlayerRow_*", "Button", true, false):
		var c: Node = row.find_child("Cell_" + key, true, false)
		if c != null and str(c.text) != "–":
			out.append(float(str(c.text).trim_suffix("%")))
	return out


func _descending(a: Array) -> bool:
	for i in range(1, a.size()):
		if float(a[i]) > float(a[i - 1]):
			return false
	return true


func _ascending(a: Array) -> bool:
	for i in range(1, a.size()):
		if float(a[i]) < float(a[i - 1]):
			return false
	return true


## The season book adds up to the season's matches, matches the awards tally,
## and survives a save and load with every match's stat lines.
func _season_book() -> void:
	var book: Dictionary = _state.season_stats
	var tally: Dictionary = _state.season_tally
	_check(not book.is_empty() and book.size() == tally.size(),
			"Every player who played has a season row (%d, tally %d)" % [book.size(), tally.size()])
	var bad := ""
	for id in tally:
		var row: Dictionary = book.get(id, {})
		if int(row.get("games", -1)) != int(tally[id]["games"]) \
				or int(_SB.total(row, "goals")) != int(tally[id]["goals"]) \
				or int(_SB.total(row, "disposals")) != int(tally[id]["disposals"]):
			bad = "%s: book %s, tally %s" % [id, str(row.get("games", -1)), str(tally[id]["games"])]
			break
	_check(bad == "", "The book agrees with the awards tally on games, goals, disposals (%s)" % bad)
	# The book is the sum of the season's matches, key by key.
	var sums := {}
	for week in _state.season.results:
		for packed in week:
			# A reload leaves the matches packed (StatBook): unpack them.
			var res: Dictionary = _SB.full(packed)
			for id in res.get("players", {}):
				var st: Dictionary = res["players"][id]
				for k in ["contested_possessions", "ground_ball_gets", "shots", "running_bounces", "hitouts", "ruck_contests"]:
					var key: String = id + "|" + k
					sums[key] = float(sums.get(key, 0.0)) + float(st.get(k, 0.0))
	bad = ""
	for key in sums:
		var parts: PackedStringArray = str(key).split("|")
		if int(round(_SB.total(book.get(parts[0], {}), parts[1]))) != int(round(float(sums[key]))):
			bad = key
			break
	_check(bad == "" and not sums.is_empty(), "The season totals are the matches added up (%s)" % bad)
	# Save, start again, load: the book and the match boxes come back.
	var before := book.duplicate(true)
	var res0: Dictionary = _SB.full((_state.season.results[0] as Array)[0])
	var some_id := str(((res0["roster"] as Array)[0] as Array)[0]["id"])
	var line0: Dictionary = (res0["players"] as Dictionary).get(some_id, {}).duplicate()
	var saved: bool = _state.save_career()
	var size := 0
	var f := FileAccess.open(_state.save_path, FileAccess.READ)
	if f != null:
		size = f.get_length()
		f.close()
	print("Stats: save after %d rounds is %d KB" % [_state.season.round_index, size / 1024])
	_state.reset()
	var loaded: bool = _state.load_career()
	_check(saved and loaded, "The career saves and loads")
	bad = ""
	for id in before:
		var a_row: Dictionary = before[id]
		var b_row: Dictionary = _state.season_stats.get(id, {})
		if int(b_row.get("games", -1)) != int(a_row["games"]):
			bad = id
			break
		for k in a_row["s"]:
			if int(round(float(a_row["s"][k]))) != int(round(_SB.total(b_row, k))):
				bad = "%s %s" % [id, k]
				break
	_check(bad == "" and _state.season_stats.size() == before.size(), "The season book survives a save and load (%s)" % bad)
	var back: Dictionary = (_state.season.results[0] as Array)[0]
	_check(back.has("box") and not back.has("players"), "A saved match keeps its stat lines packed, not whole")
	var full: Dictionary = _SB.full(back)
	var line1: Dictionary = (full.get("players", {}) as Dictionary).get(some_id, {})
	bad = ""
	for k in _SB.KEYS:
		if int(round(float(line0.get(k, 0.0)))) != int(round(float(line1.get(k, 0.0)))):
			bad = k
	_check(bad == "" and (full["roster"] as Array).size() == 2 and (full["team"] as Array).size() == 2,
			"A match opened again after a reload has every player's line and both teams (%s)" % bad)


## A club's new statistics a game, over the games it has counted them.
func _club_per_game() -> void:
	var code := str(_state.my_club)
	var row: Dictionary = _state.season_team.get(code, {})
	var g := int(row.get("book_games", 0))
	_check(g > 0 and g == int(row.get("games", 0)), "A new season counts the clubs' new statistics every game (%d of %d)" % [g, int(row.get("games", 0))])
	var cp: float = _state.club_per_game(code, "contested_possessions")
	_check(cp > 0.0 and is_equal_approx(cp, float(row["contested_possessions"]) / float(g)),
			"A club's contested possessions a game is its total over its games (%.1f)" % cp)
	_check(_state.club_per_game("NOPE", "disposals") == -1.0, "A club with no games has no figure")


## Rates come from their counts; nothing under a rate is no rate, not zero.
func _book_rates() -> void:
	_check(_SB.rate({}, "accuracy") == -1.0 and _SB.rate({"goals": 3.0, "shots": 4.0}, "accuracy") == 0.75,
			"Accuracy is goals over shots, and no shots is no rate")
	_check(_SB.rate({"hitouts": 10.0, "ruck_contests": 25.0}, "hitout_win") == 0.4
			and _SB.rate({"hitouts": 0.0}, "hitout_win") == -1.0,
			"Hit-out win rate is hit-outs over ruck contests")
	_check(is_equal_approx(_SB.rate({"contested_possessions": 3.0, "uncontested_possessions": 9.0}, "cp_rate"), 0.25),
			"Contested possession rate is contested over all possessions")
	_check(_SB.kick_ratio({"kicks": 6.0}) == -1.0 and _SB.kick_ratio({"kicks": 6.0, "handballs": 4.0}) == 1.5,
			"Kicks to handballs, none without a handball")
	_check(_SB.per_game({"games": 0}, "goals") == -1.0 and _SB.per_game({"games": 4, "s": {"goals": 6.0}}, "goals") == 1.5,
			"Per game is over the games he played, and nothing with no games")
	# Season rates come from season counts, not an average of match rates:
	# 1 from 1 then 0 from 3 is 1 from 4 (25%), not the 50% an average says.
	var season := {}
	for st in [{"goals": 1.0, "shots": 1.0}, {"goals": 0.0, "shots": 3.0}]:
		for k in st:
			season[k] = float(season.get(k, 0.0)) + float(st[k])
	_check(_SB.rate(season, "accuracy") == 0.25, "A season's accuracy is its goals over its shots")
	# A career line from a season row, from now on; seasons before it keep
	# games and goals only.
	var p := {"id": "t1", "career": _CA.fresh()}
	_CA.add_season(p, 2030, "COL", 20, 15, {"games": 20, "s": {"goals": 15.0, "disposals": 400.0}}, 0)
	var lines: Array = p["career"].get("lines", [])
	_check(lines.size() == 1 and int(lines[0][2]) == 20
			and int((lines[0][3] as PackedInt32Array)[_SB.KEYS.find("disposals")]) == 400,
			"A finished season adds his statistics line to his career")
	_CA.add_season(p, 2030, "COL", 20, 15, {"games": 20, "s": {}}, 0)
	_check((p["career"]["lines"] as Array).size() == 1, "A season is never added twice")
	# Traded in the off-season (the only time a player changes clubs): next
	# season's line is his new club's, the old one keeps its own.
	_CA.add_season(p, 2031, "CAR", 18, 9, {"games": 18, "s": {"goals": 9.0, "disposals": 300.0}}, 0)
	var two: Array = p["career"]["lines"]
	_check(two.size() == 2 and str(two[0][1]) == "COL" and str(two[1][1]) == "CAR"
			and int((two[1][3] as PackedInt32Array)[_SB.KEYS.find("disposals")]) == 300,
			"A player traded between seasons keeps each season with the club he played it for")

## Season stats > Fixture, by finger: it opens on the round to play, Previous,
## Next and the picker move about, a played match opens its box score and an
## upcoming one a preview, Back closes the sheet first, and nothing runs off
## the screen. A result with only what a save keeps says what was not kept.
func _fixture(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var season = _state.season
	var fix = load("res://scripts/ui/stats/StatsFixture.gd")
	var bold_font = load("res://scripts/ui/UiKit.gd").BOLD
	fix.reset()
	root.size = sz
	load("res://scripts/ui/StatsHubScene.gd").current = "fixture"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	var next_round := "Round %d" % (season.round_index + 1)
	var picker: Button = s.find_child("RoundPicker", true, false)
	_check(picker != null and picker.text == next_round, "The fixture opens on the round to play (%s: %s)" % [tag, picker.text if picker else "-"])
	var rows: Array = s.find_children("Match_*", "Button", true, false)
	_check(rows.size() == (season.fixture[season.round_index] as Array).size() and not rows.is_empty(),
			"Every match of the round is a row (%s)" % tag)
	var upcoming := true
	for r in rows:
		upcoming = upcoming and not bool(r.get_meta("done")) and not _text(r).contains("(") 				and not _text(r).contains("Upcoming")
	_check(upcoming, "A round all to come shows the ground, not a score and not Upcoming on every row (%s)" % tag)
	var grounds := true
	for i in range(rows.size()):
		grounds = grounds and _text(rows[i]).contains(season.home_ground(str(season.fixture[season.round_index][i]["home"])))
	_check(grounds, "Each match shows its ground (%s)" % tag)
	if sz.x >= 900:
		var widest := 0.0
		for r in rows:
			widest = maxf(widest, r.size.x)
		_check(widest <= 430.0, "On a wide screen a match row is compact, not a bar across the window (%s: %d)" % [tag, int(widest)])
		var nav_w: float = s.find_child("NextRound", true, false).get_global_rect().end.x - s.find_child("PrevRound", true, false).get_global_rect().position.x
		_check(nav_w <= 560.0, "Previous, round and Next are a compact group (%s: %d)" % [tag, int(nav_w)])
	var byes: Node = s.find_child("ByeLine", true, false)
	_check(byes == null or _text(byes).begins_with("Bye: "), "A round with byes names the clubs (%s)" % tag)
	_fits(s, sz, "the next round", tag)

	# Your club's match is set in bold, the others' are not.
	var mine_name: String = str(_state.my_club) if sz.x < 900 else str(db.club_short(str(_state.my_club)))
	var bold_mine := false
	var bold_other := false
	for r in rows:
		var yours: bool = _text(r).contains(mine_name)
		for l in r.find_children("*", "Label", true, false):
			var is_bold: bool = l.get_theme_font("font") == bold_font
			if yours:
				bold_mine = bold_mine or is_bold
			elif is_bold:
				bold_other = true
	_check(bold_mine and not bold_other, "Your club's match stands out by weight (%s)" % tag)

	# Previous, by finger: the round before, played, with both scores.
	var why: String = await Tap.tap(s.find_child("PrevRound", true, false))
	await _settle()
	_check(why == "", "A finger takes Previous (%s: %s)" % [tag, why])
	picker = s.find_child("RoundPicker", true, false)
	_check(picker.text == "Round %d" % season.round_index, "Previous goes to the round before (%s)" % tag)
	rows = s.find_children("Match_*", "Button", true, false)
	var played := not rows.is_empty()
	for r in rows:
		played = played and bool(r.get_meta("done")) and not _text(r).contains("Upcoming") and _text(r).contains("(") 				and _text(r).contains(season.home_ground(str(season.fixture[season.round_index - 1][r.get_index()]["home"])))
	_check(played, "Played matches show both scorelines (%s)" % tag)
	_fits(s, sz, "a played round", tag)

	# A played match opens its box score; Back closes it, and the next Back is the screen's.
	var why2: String = await Tap.tap(rows[0])
	await _settle()
	var sheet: Node = s.find_child("FixtureSheet", true, false)
	_check(why2 == "" and sheet != null and sheet.find_child("MatchBox", true, false) != null,
			"A finger on a played match opens it (%s: %s)" % [tag, why2])
	if sheet != null:
		var q: Node = sheet.find_child("QuarterStrip", true, false)
		var res: Dictionary = season.results[season.round_index - 1][0]
		_check(q != null and _text(q).contains("%d.%d" % [int(res["q_goals"][0][0]), int(res["q_behinds"][0][0])]),
				"The box score has the quarters (%s)" % tag)
		_check(not sheet.find_children("BoxPlayer_*", "Button", true, false).is_empty()
				and sheet.find_child("HeadToHead", true, false) != null and sheet.find_child("NotKept", true, false) == null,
				"A match with its players kept shows them, and the team numbers head to head (%s)" % tag)
		var box = sheet.find_child("BoxScore", true, false)
		_check(box != null and not (box.get("_scores") as Array).is_empty(),
				"The worm has the match's goals and behinds (%s)" % tag)
		_fits(sheet, sz, "the box score", tag)
	var backed: bool = s.call("handle_back")
	await _settle()
	_check(backed and s.find_child("FixtureSheet", true, false) == null, "Back closes the sheet first (%s)" % tag)
	_check(s.call("handle_back") == false, "...and the next Back is the screen's own (%s)" % tag)

	# What a save keeps is the score by quarter, nothing more: say so.
	var at: int = season.round_index - 1
	var kept: Array = season.results[at]
	season.results[at] = load("res://scripts/state/CareerSave.gd").slim_results(kept)
	s.call("refresh")
	await _settle()
	rows = s.find_children("Match_*", "Button", true, false)
	var why3: String = await Tap.tap(rows[0])
	await _settle()
	var slim_box = s.find_child("BoxScore", true, false)
	_check(why3 == "" and s.find_child("NotKept", true, false) != null and s.find_child("QuarterStrip", true, false) != null
			and slim_box != null and not (slim_box.get("_scores") as Array).is_empty(),
			"A match kept only as a score still shows its quarters and worm, and says the rest was not kept (%s)" % tag)
	var close: Button = s.find_child("CloseSheet", true, false)
	await Tap.tap(close)
	await _settle()
	season.results[at] = kept
	_check(s.find_child("FixtureSheet", true, false) == null, "Close closes the sheet (%s)" % tag)

	# Next, back to the round to play; an upcoming match opens its preview.
	await Tap.tap(s.find_child("NextRound", true, false))
	await _settle()
	picker = s.find_child("RoundPicker", true, false)
	_check(picker.text == next_round, "Next goes to the round to play (%s)" % tag)
	rows = s.find_children("Match_*", "Button", true, false)
	var why4: String = await Tap.tap(rows[0])
	await _settle()
	sheet = s.find_child("FixtureSheet", true, false)
	var pv: Node = sheet.find_child("PreviewBox", true, false) if sheet != null else null
	_check(why4 == "" and pv != null, "A finger on an upcoming match opens its preview (%s: %s)" % [tag, why4])
	if pv != null:
		var pt := _text(pv)
		var f0: Dictionary = season.fixture[season.round_index][0]
		_check(pt.contains(db.club_short(str(f0["home"]))) and pt.contains(db.club_short(str(f0["away"]))),
				"The preview names both clubs (%s)" % tag)
		_check(pt.contains(season.home_ground(str(f0["home"]))), "...and the ground (%s)" % tag)
		_check(pt.contains("st ·") or pt.contains("nd ·") or pt.contains("rd ·") or pt.contains("th ·"),
				"...and where each sits on the ladder (%s)" % tag)
		_check(pt.contains("Round %d:" % season.round_index) and (pt.contains("won by") or pt.contains("lost by") or pt.contains("drew")),
				"...and how each has gone lately (%s)" % tag)
		_fits(sheet, sz, "the preview", tag)
	s.call("handle_back")
	await _settle()

	# The round picker: a finger on a round takes you there.
	var why5: String = await Tap.tap(s.find_child("RoundPicker", true, false))
	await _settle()
	sheet = s.find_child("FixtureSheet", true, false)
	_check(why5 == "" and sheet != null and sheet.find_children("RoundPick_*", "Button", true, false).size() == _rounds(),
			"The picker offers every round (%s)" % tag)
	_fits(sheet, sz, "the picker", tag)
	var why6: String = await Tap.tap(s.find_child("RoundPick_0", true, false))
	await _settle()
	_check(why6 == "" and s.find_child("FixtureSheet", true, false) == null and s.find_child("RoundPicker", true, false).text == "Round 1",
			"A finger on round 1 goes there and closes the picker (%s: %s)" % [tag, why6])
# ---------------------------------------------------------------------------
# Awards
# ---------------------------------------------------------------------------
func _open_awards(sz: Vector2i) -> Control:
	root.size = sz
	load("res://scripts/ui/StatsHubScene.gd").current = "awards"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	return s


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


func _close(s: Control) -> void:
	s.queue_free()
	await _settle()


## Season stats > Ladder, by finger: the true order to start, a header sorts and
## sorts back, "Ladder order" and Reset restore it, the filters narrow it, the
## team view is per game from season_team, and a club opens its side on the field
## view with Back returning to the table as it was.
func _ladder(sz: Vector2i) -> void:
	var tag := "%dx%d" % [sz.x, sz.y]
	var db = root.get_node("GameDB")
	var season = _state.season
	var ladder = load("res://scripts/ui/stats/StatsLadder.gd")
	var bold_font = load("res://scripts/ui/UiKit.gd").BOLD
	ladder.reset()
	root.size = sz
	load("res://scripts/ui/StatsHubScene.gd").current = "ladder"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	var true_order := []
	for r in season.ladder_sorted():
		true_order.append(str(r["code"]))
	var mine := str(_state.my_club)
	_check(_row_codes(s) == true_order, "The ladder opens in the true order (%s)" % tag)
	_fits(s, sz, "the ladder", tag)
	_table_recipe(s, tag, true)

	# Phone columns, and the wide screen's extra ones.
	var heads := []
	for b in s.find_child("LadderHeader", true, false).get_children():
		heads.append(str(b.name))
	var phone: Array = ["Sort_pos", "Sort_club", "Sort_p", "Sort_w", "Sort_l", "Sort_d", "Sort_pct", "Sort_pts"]
	if sz.x < 900:
		_check(heads == phone, "Phone columns are # Club P W L D %% Pts (%s: %s)" % [tag, str(heads)])
	else:
		_check(heads.slice(0, 8).size() == 8 and heads.has("Sort_pf") and heads.has("Sort_home") and heads.has("Sort_away"),
				"A wide screen adds points for and against, home and away (%s: %s)" % [tag, str(heads)])
		var row_text := _text(s.find_child("Club_" + mine, true, false))
		_check(season.club_results(mine).size() == 0 or row_text.contains("".join(PackedStringArray((season.club_results(mine) as Array).slice(-5)))),
				"...and the last five results as letters (%s)" % tag)

	# A wide screen: the table is as wide as its columns, at the left beside the
	# toggles, and the toggles are compact groups rather than bars across the window.
	if sz.x >= 900:
		_table_fits_content(s, "ladder", tag)
		for n in ["Filter_all", "Filter_top8", "Filter_near"]:
			var tb: Control = s.find_child(n, true, false)
			_check(tb != null and tb.size.x >= 100 and tb.size.x <= 140,
					"%s is a compact button, not a bar (%s: %.0f px)" % [n, tag, tb.size.x if tb != null else -1.0])

	# Your club is set in bold, another is not.
	var other: String = true_order[0] if true_order[0] != mine else true_order[1]
	var mine_name := mine if sz.x < 900 else str(db.club_short(mine))
	var other_name := other if sz.x < 900 else str(db.club_short(other))
	_check(_label_bold(s.find_child("Club_" + mine, true, false), mine_name, bold_font)
			and not _label_bold(s.find_child("Club_" + other, true, false), other_name, bold_font),
			"Your club is in bold, another is not (%s)" % tag)

	# Sort by wins, by finger; again to reverse; Ladder order to restore.
	var why: String = await Tap.tap(s.find_child("Sort_w", true, false))
	await _settle()
	_check(why == "", "A finger on W sorts (%s: %s)" % [tag, why])
	var wins := _by(s, season, "w")
	_check(_non_increasing(wins), "W sorts most first (%s: %s)" % [tag, str(wins)])
	_check(_text(s.find_child("ActiveState", true, false)).contains("sorted by W, most first"), "The sort is named (%s)" % tag)
	await Tap.tap(s.find_child("Sort_w", true, false))
	await _settle()
	wins = _by(s, season, "w")
	_check(_non_decreasing(wins), "A second tap reverses it (%s: %s)" % [tag, str(wins)])
	await Tap.tap(s.find_child("LadderOrder", true, false))
	await _settle()
	_check(_row_codes(s) == true_order and s.find_child("LadderOrder", true, false) == null,
			"Ladder order restores the true order (%s)" % tag)
	await Tap.tap(s.find_child("Sort_club", true, false))
	await _settle()
	var names := []
	for c in _row_codes(s):
		names.append(str(db.club_short(c)))
	var az := names.duplicate()
	az.sort()
	_check(names == az, "The club column sorts A to Z first (%s)" % tag)

	# Filters, by finger: Top 8, Near you, and Reset.
	await Tap.tap(s.find_child("Filter_top8", true, false))
	await _settle()
	var top8 := _row_codes(s)
	var expect8 := []
	for c in true_order.slice(0, 8):
		expect8.append(c)
	top8.sort()
	expect8.sort()
	_check(top8 == expect8, "Top 8 shows the top eight (%s)" % tag)
	_check(_text(s.find_child("ActiveState", true, false)).contains("Top 8"), "The active filter is shown (%s)" % tag)
	await Tap.tap(s.find_child("Filter_near", true, false))
	await _settle()
	var near := _row_codes(s)
	var at := true_order.find(mine)
	var expect_near := []
	for i in range(maxi(0, at - 2), mini(true_order.size(), at + 3)):
		expect_near.append(true_order[i])
	near.sort()
	expect_near.sort()
	_check(near == expect_near and near.has(mine), "Near you is two places either side of your club (%s)" % tag)
	await Tap.tap(s.find_child("ResetLadder", true, false))
	await _settle()
	_check(_row_codes(s) == true_order and s.find_child("ResetLadder", true, false) == null,
			"Reset puts back every club in ladder order (%s)" % tag)

	# Team stats: a leaderboard, one fact at a time, a game.
	await Tap.tap(s.find_child("View_team", true, false))
	await _settle()
	var t: Dictionary = _state.season_team.get(mine, {})
	var games := int(t.get("games", 0))
	_check(games > 0, "(setup) your club has games to average (%s)" % tag)
	_check(s.find_child("TeamBoard", true, false) != null and s.find_child("TeamStat", true, false) != null
			and s.find_child("Filter_top8", true, false) == null,
			"Team stats is a leaderboard with its own picker (%s)" % tag)
	var mine_row: Node = s.find_child("Club_" + mine, true, false)
	var club_nm: Label = mine_row.find_child("Name", true, false) if mine_row else null
	_check(club_nm != null and club_nm.text == str(db.club_name(mine)), "Each club by its name (%s: %s)" % [tag, club_nm.text if club_nm else "-"])
	var want_pf: String = ladder.team_text(float(t["for"]) / float(games), "for")
	_check(_text(mine_row.find_child("Figure", true, false)) == want_pf,
			"Points for is a game over games played, whole: %s (%s)" % [want_pf, tag])
	var others := _text(mine_row.find_child("Others", true, false))
	_check(others.contains("inside 50s") and others.contains("goals"),
			"...with the view's other two facts beside it (%s: %s)" % [tag, others])
	var figs := []
	for c in _row_codes(s):
		figs.append(float(_text(s.find_child("Club_" + c, true, false).find_child("Figure", true, false))))
	_check(_non_increasing(figs), "Ranked on points for, most first (%s)" % tag)
	var first_bar: Node = s.find_child("Club_" + str(_row_codes(s)[0]), true, false).find_child("Bar", true, false)
	_check(first_bar != null and is_equal_approx(float(first_bar.get_meta("share")), 1.0),
			"The league's best fills the bar (%s)" % tag)
	var whole_rx := RegEx.new()
	whole_rx.compile("^[0-9]+$")
	_check(whole_rx.search(want_pf) != null, "No decimals where a whole number says it (%s: %s)" % [tag, want_pf])
	ladder.pick_team_fact("against")
	s.call("refresh")
	await _settle()
	figs = []
	for c in _row_codes(s):
		figs.append(float(_text(s.find_child("Club_" + c, true, false).find_child("Figure", true, false))))
	_check(_non_decreasing(figs), "Points against ranks the fewest first (%s)" % tag)
	ladder.pick_team_fact("goals")
	s.call("refresh")
	await _settle()
	var tenth_rx := RegEx.new()
	tenth_rx.compile("^[0-9]+[.][0-9]$")
	_check(tenth_rx.search(_text(s.find_child("Club_" + mine, true, false).find_child("Figure", true, false))) != null,
			"Goals a game keep their tenth (%s)" % tag)
	_fits(s, sz, "team stats", tag)
	ladder.pick_team_fact("for")
	await Tap.tap(s.find_child("View_ladder", true, false))
	await _settle()

	# A club opens its side, read-only; Back returns to the table as it was.
	await Tap.tap(s.find_child("Sort_pts", true, false))
	await _settle()
	await Tap.tap(s.find_child("Filter_top8", true, false))
	await _settle()
	var before := _row_codes(s)
	var tapped: String = before[1] if before[0] == mine else before[0]
	var why2: String = await Tap.tap(s.find_child("Club_" + tapped, true, false))
	await _settle()
	var side: Node = s.find_child("ClubSide", true, false)
	_check(why2 == "" and side != null and side.find_child("TeamBuilder", true, false) != null,
			"A finger on a club opens its side (%s: %s)" % [tag, why2])
	if side != null:
		var builder: Node = side.find_child("TeamBuilder", true, false)
		_check(bool(builder.get("_read_only")), "The side is read-only (%s)" % tag)
		var named: bool = not (season.selections.get(tapped, {}) as Dictionary).is_empty()
		var note := _text(side.find_child("SideNote", true, false)).strip_edges()
		_check(note == ("Side named for this round" if named else "Projected side: picked on match day"),
				"The side says whether it is projected (%s: %s)" % [tag, note])
		_fits(side, sz, "a club's side", tag)
		# A player opens his profile over the side; Back closes it first.
		var list: Array = _state.opponent_side(tapped)["list"]
		builder.emit_signal("inspect", str(list[0]["id"]))
		await _settle()
		_check(s.find_child("PlayerProfile", true, false) != null and s.find_child("ClubSide", true, false) != null,
				"A player opens over the side (%s)" % tag)
		_check(s.call("handle_back") == true, "Back closes the profile (%s)" % tag)
		await _settle()
		_check(s.find_child("PlayerProfile", true, false) == null and s.find_child("ClubSide", true, false) != null,
				"...and leaves the side (%s)" % tag)
	_check(s.call("handle_back") == true, "Back closes the side (%s)" % tag)
	await _settle()
	_check(s.find_child("ClubSide", true, false) == null and _row_codes(s) == before
			and _text(s.find_child("ActiveState", true, false)).contains("sorted by Pts"),
			"Back returns to the ladder as it was, sort and filter kept (%s)" % tag)
	s.queue_free()
	await _settle()


## On a wide screen the table is about as wide as its columns (760 to 900 px),
## starts where the toggles above it start, and its club column is no wider than
## about 200 px: the club and its numbers sit together.
func _table_fits_content(s: Node, what: String, tag: String) -> void:
	var table: Control = s.find_child("LadderTable", true, false)
	var panel: Control = table
	var w := panel.get_global_rect().size.x
	_check(w >= 700 and w <= 900, "The %s table is as wide as its columns (%s: %.0f px)" % [what, tag, w])
	var views: Control = s.find_child("Views", true, false)
	_check(absf(panel.get_global_rect().position.x - views.get_global_rect().position.x) <= 2.0,
			"...and starts at the left, level with the toggles (%s)" % tag)
	var club: Control = s.find_child("Sort_club", true, false)
	_check(club.size.x >= 170 and club.size.x <= 200, "...with a club column about 190 px (%s: %.0f px)" % [tag, club.size.x])
	var first: Control = s.find_child("Sort_" + ("p" if what == "ladder" else "for"), true, false)
	_check(absf(first.get_global_rect().position.x - club.get_global_rect().end.x) <= 4.0,
			"...and the first column right after it (%s)" % tag)


## The shared table recipe: rows 32 px, no panel around the table, every other
## row banded in PANEL, numbers and their headers right-aligned, the position
## muted, a zero muted, the sort key's header bold.
func _table_recipe(s: Node, tag: String, with_pos: bool) -> void:
	var table: Control = s.find_child("LadderTable", true, false)
	_check(table.get_parent().name == "StatsLadder", "The table sits in no panel or card (%s)" % tag)
	var rows := s.find_children("Club_*", "Button", true, false)
	var tall := true
	for b in rows:
		if int(b.size.y) != (32 if root.size.x >= 900 else 40):
			tall = false
	_check(tall and not rows.is_empty(), "Rows are 32 px on a wide screen and a thumb-sized 40 px on a phone (%s)" % tag)
	# Your club's row is in your colour instead of its band.
	var kit = load("res://scripts/ui/UiKit.gd")
	var mine := str(_state.my_club)
	var banded := rows.size() > 1
	var mine_tinted := false
	for i in range(rows.size()):
		var sb := (rows[i] as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if rows[i].name == "Club_" + mine:
			mine_tinted = sb != null and sb.bg_color.is_equal_approx(Color(kit.club_vivid(mine), 0.22))
			continue
		var want := (kit.PANEL as Color) if i % 2 == 1 else Color.TRANSPARENT
		if sb == null or not sb.bg_color.is_equal_approx(want):
			banded = false
	_check(banded, "Every other row is banded in the panel colour (%s)" % tag)
	_check(mine_tinted, "...and your club's row is in your colour (%s)" % tag)
	var right := true
	var zero_muted := true
	var muted: Color = load("res://scripts/ui/UiKit.gd").MUTED
	for b in rows:
		for l in (b as Node).find_children("*", "Label", true, false):
			var tx := str(l.text)
			if tx.is_valid_float() or tx == "-":
				if (l as Label).horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
					right = false
				if tx.is_valid_float() and float(tx) == 0.0 and (l as Label).get_theme_color("font_color") != muted:
					zero_muted = false
	_check(right, "Numbers are right-aligned (%s)" % tag)
	_check(zero_muted, "A zero is muted (%s)" % tag)
	var head_right := true
	for h in s.find_child("LadderHeader", true, false).get_children():
		if h is Button and str(h.name) != "Sort_club" and (h as Button).alignment != HORIZONTAL_ALIGNMENT_RIGHT:
			head_right = false
	_check(head_right, "Their headers are right-aligned to match (%s)" % tag)
	if with_pos:
		var pos: Label = null
		for l in (rows[0] as Node).find_children("*", "Label", true, false):
			if str(l.text) == "1":
				pos = l
				break
		_check(pos != null and pos.get_theme_color("font_color") == muted and pos.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
				"The position is its own muted, right-aligned column (%s)" % tag)


## The clubs in the table, top to bottom.
func _row_codes(s: Node) -> Array:
	var out := []
	for b in s.find_children("Club_*", "Button", true, false):
		out.append(str(b.name).trim_prefix("Club_"))
	return out


## A ladder column for the clubs in the table, top to bottom.
func _by(s: Node, season, key: String) -> Array:
	var out := []
	for c in _row_codes(s):
		out.append(int(season.ladder[c][key]))
	return out


func _non_increasing(a: Array) -> bool:
	for i in range(1, a.size()):
		if a[i] > a[i - 1]:
			return false
	return true


func _non_decreasing(a: Array) -> bool:
	for i in range(1, a.size()):
		if a[i] < a[i - 1]:
			return false
	return true


## The width the label reading `text` in `row` has been given.
func _label_width(row: Node, text: String) -> float:
	for l in row.find_children("*", "Label", true, false):
		if str(l.text) == text:
			return l.size.x
	return 0.0


## Whether the label reading `text` in `row` is in the bold face.
func _label_bold(row: Node, text: String, bold_font) -> bool:
	for l in row.find_children("*", "Label", true, false):
		if str(l.text) == text:
			return l.get_theme_font("font") == bold_font
	return false


## The finals weeks are in the fixture once the finals start, and not before.
func _fixture_finals() -> void:
	var season = _state.season
	var fix = load("res://scripts/ui/stats/StatsFixture.gd")
	_check(fix.pages(season).size() == _rounds() and season.finals.is_empty(),
			"Before the finals the fixture is the home-and-away rounds only")
	var guard := 0
	while season.finals.is_empty() and guard < 40:
		_state.advance()
		guard += 1
	var pgs: Array = fix.pages(season)
	_check(pgs.size() == _rounds() + 1 and bool(pgs.back()["finals"]) and str(pgs.back()["title"]) == "Wildcard finals",
			"The finals week to play joins the fixture once the finals start")
	root.size = Vector2i(390, 844)
	fix.reset()
	load("res://scripts/ui/StatsHubScene.gd").current = "fixture"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	var picker: Button = s.find_child("RoundPicker", true, false)
	_check(picker != null and picker.text == "Wildcard finals", "It opens on the finals week to play (%s)" % (picker.text if picker else "-"))
	var rows: Array = s.find_children("Match_*", "Button", true, false)
	_check(rows.size() == 2 and not bool(rows[0].get_meta("done")), "The wildcard finals are two matches to come")
	var why: String = await Tap.tap(s.find_child("RoundPicker", true, false))
	await _settle()
	var f: Button = s.find_child("RoundPick_%d" % _rounds(), true, false)
	_check(why == "" and f != null and f.text == "Wildcard finals", "The picker lists the finals under the rounds")
	s.call("handle_back")
	s.queue_free()
	await _settle()
	# Play the finals out: every week is there, and the last is the Grand Final.
	guard = 0
	while not season.is_season_over() and guard < 10:
		_state.advance()
		guard += 1
	pgs = fix.pages(season)
	_check(pgs.size() == _rounds() + 5 and str(pgs.back()["title"]) == "Grand Final" and bool(pgs.back()["played"]),
			"After the Grand Final all five finals weeks are in the fixture")
	_check(fix.current_page(pgs) == pgs.size() - 1, "A finished season opens on the Grand Final")


## No label in `node` runs off the screen at this size.
func _fits(node: Node, sz: Vector2i, what: String, tag: String) -> void:
	var off := []
	for c in node.find_children("*", "Label", true, false):
		if c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
			off.append(str(c.name))
	_check(off.is_empty(), "Nothing runs off the screen on %s (%s: %s)" % [what, tag, str(off)])


func _text(node: Node) -> String:
	if node == null:
		return ""
	var out := ""
	for n in node.find_children("*", "Label", true, false):
		out += str(n.text) + "\n"
	if node is Label or node is Button:
		out += str(node.text)
	return out


## Rounds in the home-and-away season. Loaded, not named as Season: the
## autoloads are not there when this script compiles.
func _rounds() -> int:
	return load("res://scripts/sim/Season.gd").REGULAR_ROUNDS
## Before a ball is bounced: every race says so, nothing is projected.
func _awards_early() -> void:
	var s := await _open_awards(Vector2i(390, 844))
	_check(s.find_child("AwardsProvisional", true, false) != null, "Awards before Round 1 are labelled provisional")
	var none: Label = s.find_child("ColemanEmpty", true, false)
	_check(none != null and none.text == "No goals kicked yet.", "The Coleman race before a goal says so")
	_check(s.find_child("Coleman_1", true, false) == null, "No Coleman leader before a goal")
	_check(s.find_child("CoachesAwardEmpty", true, false) != null, "The Coaches Award before a vote says so")
	_check(s.find_child("AATeam", true, false) == null, "No projected All-Australian team before Round 1")
	_check(s.find_child("BrownlowSealed", true, false) != null, "The Brownlow is sealed before Round 1")
	await _close(s)


## Four rounds in, at a phone's size and a PC's: the races, the sealed
## Brownlow, the projected team, and real taps on a player and the team.
func _awards_races() -> void:
	var min_games: int = _aw.aa_min_games(4)
	_check(min_games == 2, "The All-Australian minimum after 4 of 24 rounds is 2 games (%d)" % min_games)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var s := await _open_awards(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		var prov: Label = s.find_child("AwardsProvisional", true, false)
		_check(prov != null and prov.text.contains("After Round 4") and prov.text.contains("Nothing here is awarded"),
				"The races are labelled provisional (%s)" % tag)
		_check(s.find_child("AwardsHonours", true, false) == null, "No honours before they are awarded (%s)" % tag)
		var sealed: Node = s.find_child("BrownlowSealed", true, false)
		_check(sealed != null and sealed.find_children("*", "Button", true, false).is_empty(),
				"The Brownlow stays sealed: no names, no counts (%s)" % tag)
		var proj: Label = s.find_child("AAProjected", true, false)
		_check(proj != null and proj.text.begins_with("Projected") and proj.text.contains("2 or more games"),
				"The All-Australian team is labelled projected, with its games line (%s)" % tag)
		_check(s.find_child("AANamed", true, false) == null, "The projected team is never called named (%s)" % tag)
		# A finger on the Coleman leader opens his profile; Back shuts it first.
		var lead: Button = s.find_child("Coleman_1", true, false)
		_check(lead != null, "The Coleman race has a leader (%s)" % tag)
		if lead != null:
			_check((await Tap.tap(lead)) == "", "The Coleman leader takes a tap (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens his profile (%s)" % tag)
			_check(s.call("handle_back"), "Back closes the profile first (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) == null and not s.call("handle_back"),
					"The profile is gone, and the next Back leaves (%s)" % tag)
		# The projected team on the oval: 18 spots and five on the bench, filled.
		var team: Node = s.find_child("AATeam", true, false)
		var spots := []
		if team != null:
			for c in team.find_children("*Spot_*", "Button", true, false):
				if str(c.get_meta("id", "")) != "":
					spots.append(c)
		_check(spots.size() == 23, "The projected team fills 23 spots on the oval (%s: %d)" % [tag, spots.size()])
		_check(team != null and team.find_child("BuilderSearch", true, false) == null
				and team.find_child("NotSelected", true, false) == null, "The team shows just the oval (%s)" % tag)
		var ruck: Button = team.find_child("Spot_RUCK", true, false) if team != null else null
		_check(ruck != null, "The projected team has a ruckman (%s)" % tag)
		if ruck != null:
			_check((await Tap.tap(ruck)) == "", "The All-Australian ruckman takes a tap (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens the ruckman's profile (%s)" % tag)
			s.call("handle_back")
			await _settle()
		await _close(s)
	# The projected team by position, from the tally so far.
	var players := _players()
	var team: Array = _aw.projected_all_australian(_state.season_tally, players, min_games)
	var slots := {}
	var ok := true
	var ids := {}
	for r in team:
		slots[str(r["slot"])] = int(slots.get(str(r["slot"]), 0)) + 1
		ids[str(r["id"])] = true
		if int(r["games"]) < min_games:
			ok = false
		if str(r["slot"]) != "BENCH" and str(players[str(r["id"])]["role"]) != str(r["slot"]):
			ok = false
	_check(team.size() == 23 and ids.size() == 23, "The projected All-Australian team is 23 different players (%d)" % team.size())
	_check(slots == {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6, "BENCH": 5} and ok,
			"Every projected All-Australian plays his position and has the games (%s)" % str(slots))


## Level counts share a rank; a tie across the cut is summed up, never split.
func _awards_ties() -> void:
	var keep: Dictionary = _state.season_tally
	var ids := []
	for p in _state.season.lists["COL"]:
		ids.append(str(p["id"]))
	var tally := {}
	var goals := [9, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
	for i in range(goals.size()):
		tally[ids[i]] = _row(goals[i])
	_state.season_tally = tally
	var s := await _open_awards(Vector2i(390, 844))
	var ranks := []
	for i in range(1, 6):
		var b: Node = s.find_child("Coleman_%d" % i, true, false)
		ranks.append(_rank(b) if b != null else "-")
	_check(ranks == ["1", "2", "2", "2", "-"], "Level goals share a rank and a tie across the cut isn't split (%s)" % str(ranks))
	var more: Label = s.find_child("ColemanMore", true, false)
	_check(more != null and more.text == "10 more on 2 goals.", "The tie at the cut is summed up (%s)" % (more.text if more else "none"))
	await _close(s)
	# Twelve level on one goal: the leaders are shown, the rest counted.
	tally = {}
	for i in range(12):
		tally[ids[i]] = _row(1)
	_state.season_tally = tally
	s = await _open_awards(Vector2i(390, 844))
	var b10: Node = s.find_child("Coleman_10", true, false)
	more = s.find_child("ColemanMore", true, false)
	_check(b10 != null and _rank(b10) == "1" and more != null and more.text == "2 more on 1 goal.",
			"Twelve level leaders: ten shown at rank 1, two counted (%s)" % (more.text if more else "none"))
	await _close(s)
	_state.season_tally = keep


## One nominee a round: the most influential eligible player, once a season.
func _rising_star_rules() -> void:
	var res := {"home": "COL", "away": "CAR",
		"roster": [[{"id": "old"}, {"id": "kid"}], [{"id": "kid2"}]],
		"players": {"old": {"disposals": 40}, "kid": {"disposals": 20}, "kid2": {"disposals": 10}}}
	var ages := {"old": 22.0, "kid": 20.0, "kid2": 19.0}
	_check(str(_aw.rising_star_nominee([res], ages, {}).get("id", "")) == "kid",
			"The Rising Star nominee is the best player 21 and under, not the best overall")
	_check(str(_aw.rising_star_nominee([res], ages, {"kid": true}).get("id", "")) == "kid2",
			"A player is nominated once a season")
	var fin := res.duplicate()
	fin["tag"] = "GF"
	_check(_aw.rising_star_nominee([fin], ages, {}).is_empty(), "Finals bring no nomination")
	# The four rounds so far: one nominee each, all eligible, all different.
	var noms: Array = _state.rising_star_noms["rounds"]
	var players := _players()
	var rounds := []
	var seen := {}
	var young := true
	for n in noms:
		rounds.append(int(n["round"]))
		seen[str(n["id"])] = true
		if float(players[str(n["id"])]["age"]) > _aw.RISING_STAR_AGE:
			young = false
	_check(rounds == [1, 2, 3, 4] and seen.size() == 4 and young,
			"Four rounds, four different nominees, all 21 or under (%s)" % str(rounds))
	var before := {}
	for n in noms.slice(0, 3):
		before[str(n["id"])] = true
	var ages_now := {}
	for id in players:
		ages_now[id] = float(players[id]["age"])
	var pick: Dictionary = _aw.rising_star_nominee(_state.last_results, ages_now, before)
	_check(noms.size() == 4 and str(pick.get("id", "")) == str(noms[3]["id"]),
			"Round 4's nominee was that round's best eligible player")
	# The winner comes from the nominees, as in the AFL; a season without a
	# full record (an older save) keeps the old rule.
	var tally := {"a": _row(0, 10, 10), "b": _row(0, 5, 3)}
	var who := {"a": {"role": "MID", "age": 20.0}, "b": {"role": "MID", "age": 19.0}}
	var full: Dictionary = _aw.season_awards(tally, who, 2026, {"from": 1, "rounds": [{"round": 1, "id": "b", "club": "COL"}]})
	_check(str(full["rising_star"][0]["id"]) == "b", "With every round recorded, the Rising Star comes from the nominees")
	var old: Dictionary = _aw.season_awards(tally, who, 2026, {"from": 5, "rounds": [{"round": 5, "id": "b", "club": "COL"}]})
	_check(old["rising_star"].size() == 1 and str(old["rising_star"][0]["id"]) == "a",
			"Without a full record (an older save), the old Rising Star rule stands")


## Nominations survive a save and load; an older save says which rounds it
## never recorded, and records from the next round on.
func _rising_star_saves() -> void:
	var before := JSON.stringify(_state.rising_star_noms)
	_check(_state.save_career() and _state.load_career(), "The career saves and loads")
	_check(JSON.stringify(_state.rising_star_noms) == before, "The Rising Star nominations survive a save and load")
	var s := await _open_awards(Vector2i(390, 844))
	_check(s.find_child("RisingStar_4", true, false) != null and s.find_child("RisingStarUnrecorded", true, false) == null,
			"The nominations show by round, with no unrecorded rounds")
	await _close(s)
	var state: Dictionary = _cs.read(_state.save_path)
	var meta: Dictionary = _cs.read_meta(_state.save_path)
	state.erase("rising_star_noms")
	_cs.write(state, meta, _state.save_path)
	_check(_state.load_career(), "An older save, without nominations, loads")
	_check(int(_state.rising_star_noms["from"]) == 5 and (_state.rising_star_noms["rounds"] as Array).is_empty(),
			"An older save invents no nominations for the rounds played")
	s = await _open_awards(Vector2i(390, 844))
	var gap: Label = s.find_child("RisingStarUnrecorded", true, false)
	_check(gap != null and gap.text == "Nominations from Rounds 1 to 4 weren't recorded in this save."
			and s.find_child("RisingStar_1", true, false) == null, "An older save says plainly which rounds weren't recorded")
	await _close(s)
	_state.advance()
	var noms: Array = _state.rising_star_noms["rounds"]
	_check(noms.size() == 1 and int(noms[0]["round"]) == 5, "Recording starts with the next round")


## Once the season's awards are presented they lead, labelled awarded, and
## nothing is called projected.
func _awards_awarded() -> void:
	_state.season_awards = _aw.season_awards(_state.season_tally, _players(), _state.season_year,
			_state.rising_star_noms)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var s := await _open_awards(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		var awarded: Label = s.find_child("AwardsAwarded", true, false)
		_check(s.find_child("AwardsHonours", true, false) != null and awarded != null and awarded.text.begins_with("Awarded"),
				"Presented awards are labelled awarded (%s)" % tag)
		_check(s.find_child("AwardsProvisional", true, false) == null and s.find_child("AAProjected", true, false) == null,
				"Nothing presented is called provisional or projected (%s)" % tag)
		_check(s.find_child("AANamed", true, false) != null, "The All-Australian team is the one named (%s)" % tag)
		var medal: Button = s.find_child("Honour_BrownlowMedal", true, false)
		var fig: Label = medal.find_child("Figure", true, false) if medal != null else null
		_check(fig != null and (fig.text.ends_with(" votes") or fig.text.ends_with(" vote")),
				"The medallist's count carries its unit (%s: %s)" % [tag, fig.text if fig else "none"])
		var name_l: Label = medal.find_child("Name", true, false) if medal != null else null
		var club_l: Label = medal.find_child("Club", true, false) if medal != null else null
		_check(name_l != null and club_l != null and _label_fits(name_l),
				"The medallist's name fits in full, beside the count (%s, club %s)"
				% [tag, "under the name" if club_l != null and name_l != null and name_l.get_parent() == club_l.get_parent() else "beside it"])
		_check(medal != null and (await Tap.tap(medal)) == "", "The Brownlow medallist takes a tap (%s)" % tag)
		await _settle()
		_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens the medallist's profile (%s)" % tag)
		await _close(s)
	_state.season_awards = {}


func _players() -> Dictionary:
	var out := {}
	for code in _state.season.lists:
		for p in _state.season.lists[code]:
			out[str(p["id"])] = p
	return out


func _row(goals: int, votes := 0, games := 4) -> Dictionary:
	return {"club": "COL", "games": games, "goals": goals, "goals_ha": goals, "disposals": 0,
			"distance_run": 0.0, "influence": 10.0 * games, "votes": votes, "bf": 0, "polled": 0, "coaches": 0}


## Whether a label shows its whole text, without an ellipsis.
func _label_fits(l: Label) -> bool:
	var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			l.get_theme_font_size("font_size")).x
	return w <= l.size.x + 1.0


func _rank(row: Node) -> String:
	return str((row.get_child(0).get_child(0) as Label).text)


## The trophy room through a first season and into a seeded second: empty
## and honest at first, then a premiership on the shelf, only your club's
## seasons counted, older entries said plainly, taps and Back, save and load.
func _trophies_early() -> void:
	var year: int = _state.season_year
	var s := await _open_trophies(Vector2i(390, 844))
	var none: Label = s.find_child("NoPremierships", true, false)
	_check(none != null and none.text == "No premierships yet.", "An empty trophy room says so: no premierships yet")
	_check(s.find_child("NoPlayerHonours", true, false) != null, "No player honours yet, said plainly")
	_check(s.find_child("AwardFilter", true, false) == null, "With nothing won there is nothing to filter")
	var intro: Label = s.find_child("TrophiesTenure", true, false)
	_check(intro != null and intro.text == "Your time at %s: 1 season, from %d." % [root.get_node("GameDB").club_name("COL"), year],
			"The tenure line counts the season in progress (%s)" % (intro.text if intro else "none"))
	var now: Node = s.find_child("Season_%d" % year, true, false)
	_check(now != null and _row_text(now).contains("In progress"), "This season is in the table, in progress")
	_check(now != null and _finish(now) != "", "Mid-season it gives where you sit (%s)" % (_finish(now) if now else "none"))
	s.queue_free()
	await _settle()


## Before a game this season's row gives no ladder finish: there is no
## ladder to sit on yet.
func _trophies_unplayed() -> void:
	var s := await _open_trophies(Vector2i(390, 844))
	var now: Node = s.find_child("Season_%d" % _state.season_year, true, false)
	_check(now != null and _finish(now) == "" and _row_text(now).contains("0-0-0"),
			"Before a game, this season's row gives no finish (%s)" % (_row_text(now) if now else "none"))
	s.queue_free()
	await _settle()


## The Finish column of a row in Your seasons.
func _finish(row: Node) -> String:
	var cells := row.find_children("*", "Label", true, false)
	return str((cells[1] as Label).text) if cells.size() > 1 else "?"


## ...and once the season is over (the fixture's finals test plays it out).
func _trophies() -> void:
	var year: int = _state.season_year
	var s: Control
	var intro: Label
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
		"coaches_award": [], "my_bf": [{"id": ids[0], "club": "COL", "bf": 120}]}
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
		# By player: his name, then all his honours under it.
		var groups := []
		for g in s.find_children("PlayerGroup_*", "", true, false):
			var hon := []
			var gs: Node = g.find_child("PlayerShelf", true, false)
			for b in gs.get_children() if gs != null else []:
				hon.append("%s %s" % [(b.find_child("Top", true, false) as Label).text,
						(b.find_child("Bottom", true, false) as Label).text])
			var who: Label = g.find_child("PlayerName", true, false)
			groups.append([str(g.name).trim_prefix("PlayerGroup_"), who.text if who else "", hon])
		_check(groups.size() == 2 and groups[0][0] == ids[0] and groups[1][0] == ids[2],
				"Your players' honours by player, the most decorated first, none from elsewhere (%s: %s)" % [tag, str(groups)])
		_check(groups.size() == 2 and groups[0][2] == ["Brownlow Medal %d" % year, "Best and fairest %d" % (year - 1)]
				and groups[1][2] == ["All-Australian %d" % year],
				"Each player's honours sit under him, newest first (%s)" % tag)
		_check(groups.size() == 2 and groups[0][1] == str(_state.award_name({"id": ids[0]})),
				"Each group is headed by the player's name (%s)" % tag)
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
		var mine: Node = s.find_child("PlayerGroup_" + str(ids[0]), true, false)
		var shelf: Node = mine.find_child("PlayerShelf", true, false) if mine != null else null
		var rows := {}
		for b in shelf.get_children() if shelf != null else []:
			rows[int((b as Control).position.y)] = true
		_check(shelf != null and rows.size() == 1, "A player's honours sit side by side under his name (%s: %d rows)" % [tag, rows.size()])
		# A finger on the flag opens it; Back closes it first, then leaves.
		if flag != null:
			_check((await Tap.tap(flag)) == "", "The premiership takes a tap (%s)" % tag)
			await _settle()
			var sheet: Node = s.find_child("ClubHonourSheet", true, false)
			var title: Label = sheet.find_child("SheetTitle", true, false) if sheet != null else null
			_check(title != null and title.text == "Premiers %d" % year, "Its sheet opens on the premiership (%s)" % tag)
			var inside := sheet != null
			if sheet != null:
				for c in sheet.find_children("*", "Control", true, false):
					if (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().end.x > sz.x + 1:
						inside = false
			_check(inside, "The cup and flag fit the sheet across the screen (%s)" % tag)
			_check(s.call("handle_back"), "Back closes the sheet first (%s)" % tag)
			await _settle()
			_check(s.find_child("ClubHonourSheet", true, false) == null and not s.call("handle_back"),
					"The sheet is gone, and the next Back leaves (%s)" % tag)
		var medal: Button = s.find_child("Honour_brownlow_%d" % year, true, false)
		if medal != null:
			_check((await Tap.tap(medal)) == "", "The Brownlow takes a tap (%s)" % tag)
			await _settle()
			var line: Label = s.find_child("SheetLine_1", true, false)
			_check(line != null and line.text == "31 votes.", "The sheet gives the count with its unit (%s)" % tag)
			s.call("handle_back")
			await _settle()
		s.queue_free()
		await _settle()
	# The filter: the kinds won, one at a time; your seasons stay.
	s = await _open_trophies(Vector2i(390, 844))
	var opt: OptionButton = s.find_child("AwardFilter", true, false)
	var listed := []
	for i in range(opt.item_count if opt != null else 0):
		listed.append(opt.get_item_text(i))
	_check(listed == ["All honours", "Premierships", "Minor premierships", "Brownlow Medal", "All-Australian", "Best and fairest"],
			"The filter lists only the kinds of honour won (%s)" % str(listed))
	_check(opt != null and (await Tap.tap(opt)) == "", "The filter takes a tap")
	await _settle()
	if opt != null:
		opt.get_popup().hide()
	await _pick_filter(s, 3)
	_check(s.find_child("ClubHonours", true, false) == null and s.find_children("PlayerGroup_*", "", true, false).size() == 1
			and s.find_child("Honour_brownlow_%d" % year, true, false) != null
			and s.find_child("Honour_my_bf_%d" % (year - 1), true, false) == null,
			"Brownlow Medal shows the Brownlow alone, under its winner")
	_check(s.find_child("Tenure", true, false) != null, "Your seasons stay, whatever the filter")
	await _pick_filter(s, 1)
	_check(s.find_child("PlayerHonours", true, false) == null and s.find_child("Club_premiership_%d" % year, true, false) != null
			and s.find_child("Club_minor_premiership_%d" % year, true, false) == null,
			"Premierships shows the flags alone")
	await _pick_filter(s, 0)
	_check(s.find_child("ClubHonours", true, false) != null and s.find_child("PlayerHonours", true, false) != null,
			"All honours brings everything back")
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


## Choose the filter's option i, as its list would.
func _pick_filter(s: Node, i: int) -> void:
	var opt: OptionButton = s.find_child("AwardFilter", true, false)
	if opt == null:
		return
	opt.select(i)
	opt.item_selected.emit(i)
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
