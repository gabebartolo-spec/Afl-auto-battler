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
	await _intro()
	await _hub_button()
	for i in range(4):
		_state.advance()
	await _sections()
	await _players_section()
	_club_per_game()
	_season_book()
	_book_rates()
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _fixture(sz)
	await _fixture_finals()
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
		var q: Node = sheet.find_child("Quarters", true, false)
		var res: Dictionary = season.results[season.round_index - 1][0]
		_check(q != null and _text(q).contains("%d.%d" % [int(res["q_goals"][0][0]), int(res["q_behinds"][0][0])]),
				"The box score has the quarters (%s)" % tag)
		_check(_text(sheet).contains("Goals:") and sheet.find_child("NotKept", true, false) == null,
				"A match with its players kept shows them (%s)" % tag)
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
	_check(why3 == "" and s.find_child("NotKept", true, false) != null and s.find_child("Quarters", true, false) != null,
			"A match kept only as a score still shows its quarters and says the rest was not kept (%s)" % tag)
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
	s.queue_free()
	await _settle()


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
	if node is Button:
		out += str(node.text)
	return out


## Rounds in the home-and-away season. Loaded, not named as Season: the
## autoloads are not there when this script compiles.
func _rounds() -> int:
	return load("res://scripts/sim/Season.gd").REGULAR_ROUNDS


func _settle() -> void:
	for i in range(4):
		await process_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		push_error(what)
