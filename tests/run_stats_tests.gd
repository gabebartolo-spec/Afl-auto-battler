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
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	# Before any round: no press conference sits over the hub.
	await _hub_button()
	for i in range(4):
		_state.advance()
	await _sections()
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _fixture(sz)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		await _ladder(sz)
	await _fixture_finals()
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

	# The team view: per game, from season_team.
	await Tap.tap(s.find_child("View_team", true, false))
	await _settle()
	var t: Dictionary = _state.season_team.get(mine, {})
	var games := int(t.get("games", 0))
	_check(games > 0, "(setup) your club has games to average (%s)" % tag)
	var mine_row := _text(s.find_child("Club_" + mine, true, false))
	_check(_label_width(s.find_child("Club_" + mine, true, false), mine_name) >= 24.0,
			"The club's name still shows in the team view (%s)" % tag)
	var want_pf: String = ladder.per_game_text(float(t["for"]) / float(games))
	var want_d: String = ladder.per_game_text(float(t["disposals"]) / float(games))
	_check(mine_row.contains(want_pf) and mine_row.contains(want_d),
			"Team stats are per game over games played: %s a game, %s disposals (%s)" % [want_pf, want_d, tag])
	var team_heads := []
	for b in s.find_child("LadderHeader", true, false).get_children():
		team_heads.append(str(b.name))
	_check(team_heads.has("Sort_disposals") and team_heads.has("Sort_inside50") and team_heads.has("Sort_hitouts")
			and not team_heads.has("Sort_contested"), "Team stats list what season_team records (%s)" % tag)
	_fits(s, sz, "team stats", tag)
	await Tap.tap(s.find_child("Sort_disposals", true, false))
	await _settle()
	var per := []
	for c in _row_codes(s):
		var row: Dictionary = _state.season_team[c]
		per.append(float(row["disposals"]) / float(row["games"]))
	_check(_non_increasing(per), "Team stats sort on the per-game figure (%s)" % tag)
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


func _settle() -> void:
	for i in range(4):
		await process_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		push_error(what)
