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
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_SB = load("res://scripts/sim/StatBook.gd")
	_CA = load("res://scripts/sim/Career.gd")
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
	await _players_section()
	_club_per_game()
	_season_book()
	_book_rates()
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


## Player stats: every player's season, sortable, grouped, per game,
## filtered, and a tap away from his season and career.
func _players_section() -> void:
	var SP = load("res://scripts/ui/stats/StatsPlayers.gd")
	var Hub = load("res://scripts/ui/StatsHubScene.gd")
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		root.size = sz
		SP.reset_view()
		Hub.current = "players"
		var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
		root.add_child(s)
		await _settle()
		var table: Node = s.find_child("PlayersTable", true, false)
		var rows := s.find_children("PlayerRow_*", "Button", true, false)
		_check(table != null and rows.size() == mini(SP.PAGE, (SP.rows() as Array).size()),
				"Player stats lists the competition's players, a page at a time (%s, %d rows)" % [tag, rows.size()])
		# The list is the season book, most disposals first.
		var cells := _column(s, "disposals")
		_check(_descending(cells) and not cells.is_empty(), "Sorted by disposals, most first (%s)" % tag)
		var top: Dictionary = SP.sorted_rows()[0]
		_check(not cells.is_empty() and int(cells[0]) == int(_SB.total(_state.season_stats[top["id"]], "disposals")),
				"The top row's disposals are his season total (%s)" % tag)
		# A real tap on the heading reverses it.
		var head: Button = s.find_child("Sort_disposals", true, false)
		_check(head != null and (await Tap.tap(head)) == "", "The disposals heading takes a tap (%s)" % tag)
		await _settle()
		cells = _column(s, "disposals")
		_check(_ascending(cells), "A second tap sorts fewest first (%s)" % tag)
		# Per game.
		var pg: Button = s.find_child("StatMode_per_game", true, false)
		_check(pg != null and (await Tap.tap(pg)) == "", "Per game takes a tap (%s)" % tag)
		await _settle()
		var one: Node = s.find_child("Cell_disposals", true, false)
		_check(one != null and str(one.text).contains("."), "Per game shows a figure a game (%s: %s)" % [tag, one.text if one else "-"])
		# Another group, a rate: only those with enough shots rank.
		SP.pick_group("goals")
		SP.sort_by("accuracy")
		s.call("refresh")
		await _settle()
		_check(s.find_child("Sort_goals", true, false) != null and s.find_child("PlayersQualify", true, false) != null,
				"Goals shows its columns, and says who a rate ranks (%s)" % tag)
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
		# Filters: one club, then reset.
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
		# Wide screens carry more than one group.
		if sz.x >= 1280:
			_check(s.find_child("Sort_metres_gained", true, false) != null, "A wide screen shows the next groups too (%s)" % tag)
		else:
			_check(s.find_child("Sort_metres_gained", true, false) == null, "A phone shows one group at a time (%s)" % tag)
		# Nothing runs off the screen.
		var spill := ""
		for c in s.find_children("*", "Label", true, false):
			if c.is_visible_in_tree() and c.get_global_rect().end.x > sz.x + 1:
				spill = str(c.name)
				break
		_check(spill == "", "Player stats fit the screen (%s%s)" % [tag, (": " + spill) if spill != "" else ""])
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
		_check(s.find_child("PlayerStatsSheet", true, false) == null and s.find_child("PlayersTable", true, false) != null,
				"...and leaves the table as it was (%s)" % tag)
		s.queue_free()
		await _settle()


func _column(s: Node, key: String) -> Array:
	var out := []
	for row in s.find_children("PlayerRow_*", "Button", true, false):
		var c: Node = row.find_child("Cell_" + key, true, false)
		if c != null and str(c.text) != "–":
			out.append(float(str(c.text)))
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
		for res in week:
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
	var res0: Dictionary = (_state.season.results[0] as Array)[0]
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


func _settle() -> void:
	for i in range(4):
		await process_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		push_error(what)
