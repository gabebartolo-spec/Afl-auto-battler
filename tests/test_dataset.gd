extends RefCounted
## The career's dataset (Legacy mode, TODO row 142, step P1): GameDB loads the
## set a career chose, a save keeps it, and the 2026 career behaves exactly as
## it did before the dataset became a choice. The golden fingerprints below
## were taken on main before the change (2026-11-11) and must not move.
## Run through tests/run_dataset_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 1990

## md5 of the 2026 load, of a seeded real-lists opening, and of a seeded
## three-round redraft season, as main produced them before P1. The load and
## real-lists prints moved with the 2026-11-12 real-list data (list types,
## departures, signings of delisted players and the list each joined); the
## season print did not. The real-lists print moved again that day with the
## 44 rule (RookieList.add_block): West Coast, at 43 of the 44, lists one of
## its three tied prospects and passes its picks, so the opening draft differs.
const GOLDEN_LOAD := "9baf6f36b146d2bfafd65e07b3235c55"
const GOLDEN_REAL := "6b9d20ef93eea2ce95f0a6d936f19727"
## A played match's floating point differs between Windows and Linux builds of
## Godot, so the season has one fingerprint per platform; each was taken on
## main before the change (Linux: run_on_github run 43024085570). The own
## plan (CustomPlan) redrew the season: Linux from Tests run 43083470206; the
## Windows print still predates it and is refreshed on the next local run.
## Result keys added after the golden was taken that record who earned a
## call's credit, not what happened (row 144). "impact" and "plan_traits" were
## already in main's results, so they stay in the hash. "breeze_side" (the
## match-day look, 2026-11-12) records which side had the breeze first, a
## number the match already drew from its seed before the first bounce, so the
## ground's flags can be drawn from a saved result: with it left out the
## season's print is the one taken before it was written down, which is the
## proof that writing it down changed no result and no draw.
const BOOKKEEPING_KEYS := ["impact_by", "breeze_side"]
## Team counts that record where something happened, not what happened: the
## pressure zones (pressure acts in the defensive half, tackles inside 50,
## 2026-11-14) are counted without a draw, so leaving them out keeps the print.
const TEAM_BOOKKEEPING_KEYS := ["pressure_acts_dhalf", "tackles_i50"]
const GOLDEN_SEASON := {"Windows": "947958fd809280ac302bee2c3dddb58d", "Linux": "2cdd3c9bceb79ab9c0c49b98727f1b7e"}

## A small league standing in for a legacy set until the 1990 files ship:
## 42 real players re-dated to a 1989 data season, a 1990 first season, and
## no draft class, history, origin, additions, moves or overrides.
const FIXTURE := "test_1989"
const FIXTURE_ROW := {"data_season": 1989, "start_year": 1990, "start_date": "1990-03-01",
		"players": "res://tests/fixtures/dataset_1989_players.csv"}


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_t("_test_golden_load")
	_t("_test_golden_real_lists")
	_t("_test_golden_season")
	_t("_test_the_2026_row")
	_t("_test_ladder_of")
	_t("_test_record_weights")
	_t("_test_club_years_today")
	_t("_test_real_1990")
	_t("_test_legacy_start_1990")
	_t("_test_legacy_rolls_into_1991")
	_t("_test_legacy_redraft_1990")
	_t("_test_era_coach_ratings")
	Datasets.add(FIXTURE, FIXTURE_ROW)
	_t("_test_fixture_load")
	_t("_test_back_to_2026")
	_t("_test_save_keeps_dataset")
	_t("_test_old_and_unknown_saves")
	_t("_test_club_years_1990")
	_t("_test_ground_names_1990")
	_t("_test_guernseys_by_year")
	Datasets.remove(FIXTURE)
	GameState.replay_seed = 0
	GameState.reset()
	print(Ran.line("Dataset", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


# ---------------------------------------------------------------------------
# Fingerprints
# ---------------------------------------------------------------------------
static func _player_line(p: Dictionary) -> String:
	var attr: Dictionary = p.get("attr", {})
	var keys := attr.keys()
	keys.sort()
	var a := PackedStringArray()
	for k in keys:
		a.append("%s=%.4f" % [k, float(attr[k])])
	return "%s|%s|%s|%d|%.4f|%d|%d|%s|%s|%d|%s|%s|%s|%s|%s" % [str(p.get("id", "")), str(p.get("real_name", "")),
			str(p.get("club", "")), int(p.get("num", 0)), float(p.get("age", 0.0)), int(p.get("overall", 0)),
			int(p.get("potential", 0)), str(p.get("role", "")), str(p.get("role2", "")), int(p.get("draft_year", 0)),
			str(p.get("rated_on_record", false)), str(p.get("generic_name", "")), str(p.get("home_state", "")),
			str(p.get("career", "")), ",".join(a)]


static func _lists_line(lists: Dictionary) -> String:
	var codes := lists.keys()
	codes.sort()
	var out := PackedStringArray()
	for code in codes:
		for p in lists[code] as Array:
			out.append("%s:%s|%d|%d|%d|%s" % [str(code), _player_line(p), int(p.get("contract_years", 0)),
					int(p.get("drafted_year", 0)), int(p.get("draft_pick", 0)), str(p.get("drafted_type", ""))])
	return "\n".join(out)


func _load_print() -> String:
	var out := PackedStringArray()
	out.append("%d|%d|%s|%.6f|%.6f" % [GameDB.DATA_SEASON, GameDB.START_YEAR, GameDB.START_DATE,
			GameDB.baseline_overall, GameDB.baseline_spread])
	for p in GameDB.players + GameDB.list_additions + GameDB.draftees:
		out.append(_player_line(p))
	var codes: Array = GameDB.clubs.keys()
	codes.sort()
	for code in codes:
		var c: Dictionary = GameDB.clubs[code]
		# pattern3 (L9's anchor colour) came after this golden; today's kits repeat
		# pattern2 in it, which _test_guernseys_by_year checks.
		var g := GameDB.club_guernsey(code)
		g.erase("pattern3")
		out.append("%s|%s|%s|%s|%d|%s" % [code, str(c.get("name", "")), str(c.get("short", "")),
				str(c.get("ground", "")), int(c.get("enter", 0)), str(g)])
	out.append(str(GameDB.club_order))
	out.append(str(GameDB.active_clubs(GameDB.START_YEAR)))
	var dk: Array = GameDB.departures.keys()
	dk.sort()
	for k in dk:
		out.append("dep|%s|%s" % [k, str(GameDB.departures[k])])
	var mk: Array = GameDB.club_moves.keys()
	mk.sort()
	for k in mk:
		out.append("move|%s|%s" % [k, str(GameDB.club_moves[k])])
	out.append(str(_ladder_2026()))
	return "\n".join(out)


func _ladder_2026() -> Array:
	return GameDB.ladder_of(2026)


func _real_print() -> String:
	GameState.reset()
	GameState.replay_seed = 4242
	GameState.career_seed = 4242
	GameState.begin_real_lists()
	GameState.choose_real_club("GEE")
	var guard := 0
	while not GameState.draft.is_finished() and guard < 400:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				break
	var picks := PackedStringArray()
	for h in GameState.draft.pick_history:
		picks.append("%s|%s|%d" % [str(h.get("club", "")), str(h.get("player_id", "")), int(h.get("pick", 0))])
	GameState.finish_intake_draft()
	var out := PackedStringArray()
	out.append("%d|%s|%d" % [GameState.season_year, GameState.my_club, GameState.free_agents.size()])
	out.append("\n".join(picks))
	out.append(_lists_line(GameState.season.lists))
	return "\n".join(out)


## Team counts are copied into snapshots too (half-time, quarter breaks), so
## leave them out at any depth.
func _strip_team_bookkeeping(v) -> void:
	if v is Dictionary:
		for k in TEAM_BOOKKEEPING_KEYS:
			(v as Dictionary).erase(k)
		for k in (v as Dictionary).keys():
			_strip_team_bookkeeping((v as Dictionary)[k])
	elif v is Array:
		for x in v:
			_strip_team_bookkeeping(x)


## The seeded season's print after each of its first `rounds` rounds.
func _season_prints(rounds: int) -> Array:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var out := []
	for i in range(rounds):
		GameState.advance()
		out.append(_season_print())
	return out


func _season_print() -> String:
	var out := PackedStringArray()
	out.append("%d|%d" % [GameState.season_year, GameState.season.round_index])
	for row in GameState.season.ladder_sorted():
		out.append(JSON.stringify(row, "", true))
	# Who earned each call's credit is bookkeeping, not play: leave it out so
	# the hash still proves the season plays the same. Results are one array
	# of match results per round.
	var played: Array = []
	for rnd in GameState.season.results:
		var games: Array = []
		for r in rnd:
			var c = r.duplicate(true) if r is Dictionary else r
			if c is Dictionary:
				for k in BOOKKEEPING_KEYS:
					(c as Dictionary).erase(k)
				_strip_team_bookkeeping(c)
			games.append(c)
		played.append(games)
	out.append(JSON.stringify(played, "", true))
	return "\n".join(out)


func _golden(name: String, text: String, want: String) -> void:
	var got := text.md5_text()
	print("GOLDEN %s=%s (%d chars)" % [name, got, text.length()])
	_check(want != "" and got == want, "The 2026 %s is exactly as before the dataset choice (%s, want %s)" % [name, got, want])


# ---------------------------------------------------------------------------
# Golden: the 2026 career is unchanged
# ---------------------------------------------------------------------------
func _test_golden_load() -> void:
	GameDB.reload()
	var a := _load_print()
	GameDB.reload()
	_check(_load_print() == a, "Two 2026 loads in a row are identical")
	_golden("load", a, GOLDEN_LOAD)


func _test_golden_real_lists() -> void:
	var a := _real_print()
	var b := _real_print()
	_check(a == b, "A seeded real-lists opening plays the same twice")
	_golden("real lists opening", a, GOLDEN_REAL)


## The golden is the first three rounds. The second career plays one round:
## a reset that leaked anything into play shows from the first round on, and
## the golden itself proves the three rounds play the same from run to run.
func _test_golden_season() -> void:
	var a := _season_prints(3)
	var b := _season_prints(1)
	_check(a.size() == 3 and b.size() == 1 and a[0] == b[0],
			"A seeded season's first round plays the same twice")
	_golden("seeded season", a[2], str(GOLDEN_SEASON.get(OS.get_name(), "")))


# ---------------------------------------------------------------------------
# The dataset is the career's choice
# ---------------------------------------------------------------------------
func _test_the_2026_row() -> void:
	GameDB.reload()
	_check(GameDB.dataset_id == "2026" and Datasets.DEFAULT == "2026" and GameDB.DATA_SEASON == 2026
			and GameDB.START_YEAR == 2027 and GameDB.START_DATE == "2027-03-01",
			"Today's start is the 2026 set: 2026 data, a 2027 first season")
	var row := Datasets.get_set("2026")
	var missing := PackedStringArray()
	for key in Datasets.FILE_KEYS:
		if not FileAccess.file_exists(str(row.get(key, ""))):
			missing.append(key)
	_check(missing.is_empty(), "The 2026 set names a shipped file for every key (missing: %s)" % ", ".join(missing))
	_check(Datasets.ready("2026") and Datasets.ready_ids().has("2026") and not Datasets.ready("nope")
			and Datasets.get_set("nope").is_empty(), "Only a known set with its players file can start a career")
	# The 1990 set is declared for the legacy start; it starts nothing until its players ship.
	_check(int(Datasets.get_set("1990").get("data_season", 0)) == 1989
			and int(Datasets.get_set("1990").get("start_year", 0)) == 1990
			and Datasets.ready("1990") == FileAccess.file_exists(Datasets.file("1990", "players")),
			"The 1990 start rates its lists on 1989 and plays 1990, once its players file ships")
	var reloads := GameDB.reloads
	var players := GameDB.players.size()
	GameDB.reload("nope")
	_check(GameDB.reloads == reloads and GameDB.dataset_id == "2026" and GameDB.players.size() == players,
			"An unknown set loads nothing and the last load stays (%d to %d loads, %d to %d players)"
			% [reloads, GameDB.reloads, players, GameDB.players.size()])


func _test_ladder_of() -> void:
	var l26 := GameDB.ladder_of(2026)
	_check(l26.size() == 18, "2026 reads the dataset's own ladder (%d rows)" % l26.size())
	# Any other season reads its decade's file, filtered to the year.
	var l15 := GameDB.ladder_of(2015)
	var premier := ""
	for r in l15:
		if str(r.get("finals", "")) == "premiers":
			premier = str(r["club"])
	_check(l15.size() == 18 and premier == "HAW",
			"2015 reads the 2010s file: 18 clubs, Hawthorn premiers (%d rows, %s)" % [l15.size(), premier])
	_check(GameDB.ladder_of(1789).is_empty(), "A season with no data has no ladder")


## The record weights count back from the data season: the same three
## seasons weigh the same in 1989 as in 2026.
func _test_record_weights() -> void:
	var p26 := {"gm": 6.0, "overall": 60, "history": [[2025, 80, 20], [2024, 78, 18], [2023, 90, 22]]}
	var p89 := {"gm": 6.0, "overall": 60, "history": [[1988, 80, 20], [1987, 78, 18], [1986, 90, 22]]}
	var a := Ratings.record_level(p26, 2026)
	var b := Ratings.record_level(p89, 1989)
	_check(a > 0.0 and is_equal_approx(a, b),
			"The same three seasons weigh the same counted back from 1989 as from 2026 (%.3f, %.3f)" % [a, b])
	_check(is_equal_approx(Ratings.record_level(p26), a), "Without a season named, the record counts back from 2026")
	_check(not is_equal_approx(Ratings.record_level(p89, 2026), a),
			"Seasons from another era weigh nothing in his record")


func _test_fixture_load() -> void:
	GameDB.reload(FIXTURE)
	_check(GameDB.dataset_id == FIXTURE and GameDB.DATA_SEASON == 1989 and GameDB.START_YEAR == 1990
			and GameDB.START_DATE == "1990-03-01", "A legacy set sets the data season, first year and start date")
	_check(GameDB.loaded and GameDB.players.size() == 42,
			"The set's players load and nobody else's (%d)" % GameDB.players.size())
	_check(GameDB.draftees.is_empty() and GameDB.list_additions.is_empty() and GameDB.departures.is_empty()
			and GameDB.club_moves.is_empty(), "Files the era has none of are empty, never 2026's")
	_check(GameDB.players.size() == 42, "The fixture's 42 players are there to rate")
	var rated_ok := true
	var off := 0
	for p in GameDB.players:
		if int(p.get("overall", 0)) <= 0 or not p.has("potential"):
			rated_ok = false
		var want := float(Prospects.days_between(str(p["dob"]), "1990-03-01")) / 365.25
		if not is_equal_approx(float(p["age"]), want) or want < 17.0 or want > 40.0:
			off += 1
	_check(rated_ok, "Every player is rated and has a potential")
	_check(off == 0, "Ages are taken at the set's own start date, 1 March 1990 (%d off)" % off)
	_check(GameDB.club_list("GEE").size() == 3 and GameDB.club_list("ADE").is_empty(),
			"Lists are the set's own")


func _test_back_to_2026() -> void:
	GameDB.reload(FIXTURE)
	GameDB.reload()
	_check(GameDB.dataset_id == "2026" and GameDB.DATA_SEASON == 2026, "Reloading the 2026 set after a legacy one")
	_golden("load after a legacy set", _load_print(), GOLDEN_LOAD)


func _test_save_keeps_dataset() -> void:
	GameState.reset(FIXTURE)
	_check(GameState.dataset == FIXTURE and GameDB.dataset_id == FIXTURE,
			"A career started from a legacy set holds it")
	var state: Dictionary = GameState._save_state()
	_check(str(state.get("dataset", "")) == FIXTURE, "The save names its set")
	GameState.reset()
	_check(GameDB.dataset_id == "2026" and GameState.dataset == "2026", "A new career is the 2026 set again")
	var reloads := GameDB.reloads
	_check(GameState._restore_career(state.duplicate(true)) and GameState.dataset == FIXTURE
			and GameDB.dataset_id == FIXTURE and GameDB.DATA_SEASON == 1989 and GameDB.players.size() == 42,
			"Loading the save loads its set again")
	_check(GameDB.reloads == reloads + 1, "The load reloads the set from its files")


func _test_old_and_unknown_saves() -> void:
	GameState.reset(FIXTURE)
	var state: Dictionary = GameState._save_state()
	state.erase("dataset")
	_check(GameState._restore_career(state.duplicate(true)) and GameState.dataset == "2026"
			and GameDB.dataset_id == "2026", "A save from before the choice is a 2026 career")
	state["dataset"] = "1066"
	_check(not GameState._restore_career(state.duplicate(true)) and GameDB.dataset_id == "2026",
			"A save whose set this build lacks is refused, not loaded onto other players")


# ---------------------------------------------------------------------------
# Clubs by year (P2): one club code across eras
# ---------------------------------------------------------------------------
func _test_club_years_today() -> void:
	GameDB.reload()
	_check(GameDB.active_clubs(2027).size() == 18 and not GameDB.clubs.has("FIT") and not GameDB.club_order.has("FIT"),
			"Today's league is the eighteen clubs; Fitzroy is not loaded (%d)" % GameDB.active_clubs(2027).size())
	_check(GameDB.club_name("BRL") == "Brisbane" and GameDB.club_short("BRL") == "Lions"
			and GameDB.club_name("WBD") == "Western Bulldogs" and GameDB.club_name("NTH") == "North Melbourne",
			"Today's names are clubs.csv's")
	_check(str(GameDB.club_era("BRL", 1995)["short"]) == "Bears" and str(GameDB.club_era("BRL", 1997)["short"]) == "Lions",
			"Brisbane are the Bears until 1996 and the Lions from 1997")
	_check(str(GameDB.club_era("WBD", 1990)["name"]) == "Footscray" and str(GameDB.club_era("WBD", 1997)["name"]) == "Western Bulldogs",
			"The Bulldogs are Footscray until 1996")
	_check(str(GameDB.club_era("NTH", 2003)["name"]) == "Kangaroos" and str(GameDB.club_era("NTH", 2008)["name"]) == "North Melbourne",
			"North are the Kangaroos from 1999 to 2007")
	_check(str(GameDB.club_era("STK", 1990)["ground"]) == "Moorabbin Oval" and str(GameDB.club_era("HAW", 1995)["ground"]) == "Waverley Park"
			and str(GameDB.club_era("COL", 1999)["ground"]) == "Victoria Park" and str(GameDB.club_era("COL", 2000)["ground"]) == "MCG",
			"Each club's home ground is its era's")
	_check(GameDB.ground_name("Marvel Stadium", 2005) == "Telstra Dome" and GameDB.ground_name("Marvel Stadium", 2027) == "Marvel Stadium"
			and GameDB.ground_name("GMHBA Stadium", 1990) == "Kardinia Park", "A ground carries its name of the year")
	_check(GameDB.club_era("BRL", 1995)["primary"] is Color and GameDB.club_era("BRL", 2027)["primary"] == GameDB.club_colours("BRL")[0],
			"Era colours are colours, and today's are clubs.csv's")
	_check(GameDB.club_code("BRB") == "BRL" and GameDB.club_code("FOO") == "WBD" and GameDB.club_code("FIT") == "FIT",
			"The Bears and Footscray carry today's codes")
	var l90 := GameDB.ladder_of(1990)
	var codes := []
	for r in l90:
		codes.append(str(r["club"]))
	_check(l90.size() == 14 and codes.has("BRL") and codes.has("WBD") and codes.has("FIT")
			and not codes.has("BRB") and not codes.has("FOO"), "The 1990 ladder reads in today's codes (%s)" % str(codes))


func _test_club_years_1990() -> void:
	GameDB.reload(FIXTURE)
	var want := {1990: 14, 1991: 15, 1995: 16, 1997: 16, 2026: 18}
	var got := {}
	for y in want:
		got[y] = GameDB.active_clubs(y).size()
	_check(got == want, "Clubs in the league: 14 in 1990, 15 in 1991, 16 in 1995 and 1997, 18 in 2026 (%s)" % str(got))
	var c90 := GameDB.active_clubs(1990)
	var c97 := GameDB.active_clubs(1997)
	_check(c90.has("FIT") and not c90.has("ADE") and not c97.has("FIT") and c97.has("PAD") and c97.has("FRE"),
			"Fitzroy play to 1996; Port Adelaide join in 1997")
	_check(GameDB.enter_year("ADE") == 1991 and GameDB.enter_year("FRE") == 1995 and GameDB.enter_year("PAD") == 1997
			and GameDB.enter_year("GCS") == 2011 and GameDB.enter_year("GWS") == 2012 and GameDB.enter_year("CAR") == 1989
			and GameDB.leave_year("FIT") == 1996 and GameDB.leave_year("CAR") == 0,
			"Entry and last years follow the clubs' history")
	_check(GameDB.club_order.find("FIT") == GameDB.club_order.find("FRE") - 1, "Fitzroy sit in club order before Fremantle")
	_check(GameDB.era_year == 1990 and GameDB.club_name("WBD") == "Footscray" and GameDB.club_short("BRL") == "Bears"
			and GameDB.club_name("FIT") == "Fitzroy" and str(GameDB.club("STK")["ground"]) == "Moorabbin Oval",
			"A 1990 start shows the clubs as they were in 1990")
	GameDB.apply_era(1997)
	_check(GameDB.club_name("WBD") == "Western Bulldogs" and GameDB.club_short("BRL") == "Lions"
			and str(GameDB.club("STK")["ground"]) == "Waverley Park", "A new season shows that year's clubs")
	GameDB.reload()


## Legacy grounds (plan L9): one key per ground whatever it was called, its
## name of the year on every screen, and one story the season it changes.
func _test_ground_names_1990() -> void:
	GameDB.reload(FIXTURE)
	_check(GameDB.ground_key("Princes Park") == "Ikon Park" and GameDB.ground_key("princes_park") == "Ikon Park"
			and GameDB.ground_key("Optus Oval") == "Ikon Park" and GameDB.ground_key("Carrara") == "People First Stadium"
			and GameDB.ground_key("MCG") == "MCG", "Every name a ground has had is the one ground")
	_check(str(GameDB.club_era("CAR", 1990)["ground"]) == "Ikon Park" and str(GameDB.club_era("WBD", 1990)["ground"]) == "Whitten Oval"
			and str(GameDB.club_era("BRL", 1990)["ground"]) == "People First Stadium",
			"The clubs' era grounds are the grounds' keys")
	_check(GameDB.ground_name("Ikon Park", 1990) == "Princes Park" and GameDB.ground_name("Ikon Park", 1994) == "Optus Oval"
			and GameDB.ground_name("Waverley Park", 1991) == "AFL Park" and GameDB.ground_name("People First Stadium", 1990) == "Carrara Stadium"
			and GameDB.ground_name("Whitten Oval", 1994) == "Western Oval" and GameDB.ground_name("MCG", 1990) == "MCG",
			"Each ground carries its name of the year; the MCG keeps its own")
	_check(GameDB.ground_name("GMHBA Stadium", 2017) == "Simonds Stadium" and GameDB.ground_name("GMHBA Stadium", 2018) == "GMHBA Stadium",
			"Kardinia Park was Simonds Stadium to 2017 (ground_names.csv, the sourced table)")
	_check(GameDB.ground_renamed_from("Ikon Park", 1994) == "Princes Park" and GameDB.ground_renamed_from("Ikon Park", 1995) == ""
			and GameDB.ground_renamed_from("Marvel Stadium", 2000) == "" and GameDB.ground_renamed_from("MCG", 1994) == "",
			"A rename is a dated name giving way to another; a ground opening is not one")
	_check(GameDB.ground_shown("Ikon Park") == "Princes Park" and GameDB.ground_shown("Ikon Park", 2000) == "Optus Oval",
			"The screens show the ground's name in the season shown (%s)" % GameDB.ground_shown("Ikon Park"))
	# The club page, the fixture and the next-match line show the year's name.
	var host := Control.new()
	ClubPage.open(host, "CAR")
	var fact: Node = host.find_child("Ground", true, false)
	var said := str((fact as RichTextLabel).text) if fact is RichTextLabel else ""
	_check(said.contains("Princes Park") and not said.contains("Ikon Park"),
			"Carlton's page names its 1990 home ground Princes Park (%s)" % said)
	host.free()
	var lists := {}
	for c in GameDB.active_clubs(1994):
		lists[c] = []
	var s94 := Season.new(GameDB.active_clubs(1994), lists, SUITE_SEED, 1994)
	GameDB.apply_era(1994)
	var venues := {}
	for page in StatsFixture.pages(s94):
		for m in page["matches"]:
			venues[str(m["venue"])] = true
	_check(venues.has("Optus Oval") and venues.has("AFL Park") and not venues.has("Ikon Park") and not venues.has("Waverley Park"),
			"The 1994 fixture names Optus Oval and AFL Park (%s)" % str(venues.keys()))
	# The rename story: once, the season it happens, with the clubs at home there.
	var old_season = GameState.season
	var old_year: int = GameState.season_year
	GameState.news = []
	GameState.milestone_log = {}
	for y in [1994, 1995]:
		GameState.season_year = y
		GameDB.apply_era(y)
		GameState.season = Season.new(GameDB.active_clubs(y), lists, SUITE_SEED, y)
		GameState._ground_rename_news()
	GameState._ground_rename_news()
	var told := GameState.news.filter(func(n): return str(n.get("kind", "")) == "ground")
	var lines := told.map(func(n): return str(n["text"]))
	_check(told.size() == 2 and lines.has("Western Oval takes a new name this season: from Round 1 it is Whitten Oval, home of Fitzroy and Footscray.")
			and lines.has("Princes Park takes a new name this season: from Round 1 it is Optus Oval, home of Carlton."),
			"1994 and 1995 each tell their ground's new name once (%s)" % str(lines))
	var story := NewsFront.story(told[0] if told.size() > 0 else {}, "CAR")
	_check(str(story["headline"]) == "Western Oval becomes Whitten Oval" and str(story["club"]) in ["FIT", "WBD"],
			"The story's headline is the old and new name, in the home club's colours (%s)" % str(story["headline"]))
	GameState.news = []
	GameState.season_year = 2027
	GameDB.reload()
	GameDB.apply_era(2027)
	GameState.season = Season.new(GameDB.active_clubs(2027), {}, SUITE_SEED, 2027)
	GameState._ground_rename_news()
	_check(GameState.news.is_empty(), "Today's grounds keep their names: a 2027 season tells no rename")
	GameState.season = old_season
	GameState.season_year = old_year
	GameState.news = []
	GameState.milestone_log = {}


## Legacy guernseys (TODO row 142, L9): each club wears the guernsey of the
## season being played, 1990 to 2026, and today's kits are clubs.csv's untouched.
func _test_guernseys_by_year() -> void:
	GameDB.reload()
	var raw := {}
	for r in GameDB._read_dicts("res://data/clubs.csv"):
		raw[str(r["code"])] = str(r["guernsey"])
	var today_ok := true
	for y in [2026, 2027]:
		GameDB.apply_era(y)
		for code in raw:
			if GameDB.clubs.has(code) and str(GameDB.clubs[code]["guernsey"]) != raw[code]:
				today_ok = false
			var g := GameDB.club_guernsey(code)
			if g["pattern3"] != g["pattern2"]:
				today_ok = false
	_check(today_ok and GameDB.club_colours("WCE")[0] == Color("#003087"),
			"A 2026 career's clubs wear clubs.csv's guernseys and colours, unchanged")
	GameDB.reload(FIXTURE)
	# Every design the year rows name is drawn by the figures, the crest and the discs.
	var named := {}
	for r in GameDB._read_dicts(GameDB.CLUBS_BY_YEAR_CSV):
		var g := str(r.get("guernsey", ""))
		if g != "":
			named[g.split(":")[0]] = true
	var drawn := true
	for d in named:
		drawn = drawn and GameDB.GUERNSEY_DESIGNS.has(d) and GuernseyCrest.BADGE_DESIGNS.has(d)
	var sheet := GuernseyCrest.BADGE_DESIGN_SHEET.get_size()
	_check(drawn and int(sheet.y / 256.0) * 4 >= GuernseyCrest.BADGE_DESIGNS.size(),
			"Every era design is in the figures' list and on the crest's sheet (%s)" % str(named.keys()))
	# Season by season, as the rollover applies each new year.
	var want := {
		1990: {"WBD": "dogs90", "SYD": "swans90", "WCE": "wings", "BRL": "yoke", "STK": "panels"},
		1995: {"FRE": "anchor", "WCE": "wings", "BRL": "chevron"},
		1997: {"PAD": "power97", "STK": "saints97", "WBD": "dogs97", "BRL": "yoke", "SYD": "yoke"},
		2002: {"STK": "panels", "WCE": "eagles00"},
		2007: {"ADE": "crows06", "PAD": "power97"},
		2010: {"FRE": "anchor", "BRL": "lions10", "ADE": "lowhoops", "PAD": "chevron"},
		2011: {"FRE": "chevrons", "GCS": "sides", "WBD": "dogs97"},
		2012: {"GWS": "giants12", "WBD": "twohoops"},
		2014: {"BRL": "yoke"},
		2016: {"WCE": "wings"},
		2021: {"GWS": "giants"},
		2026: {"GCS": "sides", "WCE": "wings", "FRE": "chevrons"},
	}
	var wrong := []
	for y in want:
		GameDB.apply_era(y)
		for code in want[y]:
			var g := GameDB.club_guernsey(code)
			if str(g["design"]) != str(want[y][code]):
				wrong.append("%s %d: %s" % [code, y, g["design"]])
	_check(wrong.is_empty(), "Each season's clubs wear that season's guernsey (%s)" % str(wrong))
	# Every season 1990-2025, every club playing wears its real guernsey, a picture in the kit
	# atlas (tools/kits/kits.txt); 2026 on, clubs.csv's own.
	var atlas := GameDB.kit_atlas()
	var cells := 0
	if atlas != null:
		cells = GameDB.KIT_PER_ROW * int(atlas.get_height()) / GameDB.KIT_SIDE
	var bare := []
	var outside := false
	for y in range(1990, 2027):
		GameDB.apply_era(y)
		for code in GameDB.active_clubs(y):
			var c := int(GameDB.club_guernsey(code).get("kit_cell", -1))
			if (c < 0) != (y >= 2026):
				bare.append("%s %d" % [code, y])
			outside = outside or c >= cells
	_check(atlas != null and bare.is_empty() and not outside,
			"Every club wears its season's guernsey picture 1990-2025 and clubs.csv's from 2026 (%s)" % str(bare))
	GameDB.apply_era(1997)
	var navy97: Color = GameDB.club_colours("WCE")[0]
	GameDB.apply_era(2005)
	var navy05: Color = GameDB.club_colours("WCE")[0]
	GameDB.apply_era(2018)
	_check(navy97 == Color("#021A31") and navy05 == Color("#05173F") and GameDB.club_colours("WCE")[0] == Color("#003087"),
			"West Coast are navy 1995-2017 and royal blue again from 2018")
	GameDB.apply_era(2024)
	var gold_sides: Color = GameDB.club_guernsey("GCS")["pattern"]
	GameDB.apply_era(2025)
	_check(gold_sides == Color("#FFDD00") and GameDB.club_guernsey("GCS")["pattern"] == Color("#9E140C"),
			"Gold Coast's side panels are gold to 2024 and red from 2025")
	# Fremantle's anchor: four colours, all the way to the figures and the crest.
	GameDB.apply_era(2000)
	var fre := GameDB.club_guernsey("FRE")
	_check(fre["pattern"] == Color.WHITE and fre["pattern2"] == Color("#065D1E") and fre["pattern3"] == Color("#DC0000"),
			"The anchor is white, with green on the wearer's right and red on his left")
	var mat := StoppageVignette.figure_material([fre, GameDB.club_guernsey("WCE")])
	var p3 = mat.get_shader_parameter("kit_pattern3")
	var designs = mat.get_shader_parameter("kit_design")
	_check(p3[0] == Color("#DC0000") and p3[1] == GameDB.club_guernsey("WCE")["pattern2"]
			and int(designs[0]) == 100 + int(fre.get("kit_cell", -100)),
			"The figures wear Fremantle's 2000 picture and get the anchor's red; a kit without a third colour repeats its second")
	var crest := UiKit.club_marker("FRE") as GuernseyCrest
	_check(crest != null and crest.design == "anchor" and crest.third == Color("#DC0000")
			and crest.kit_cell == int(fre.get("kit_cell", -1)),
			"Fremantle's 2000 marker is the anchor picture, its red included")
	if crest:
		crest.free()
	_check(PitchView.disc_design(fre) == "yoke" and PitchView.disc_design(GameDB.club_guernsey("WCE")) == "panels",
			"On the oval the era guernseys draw as the discs' own shapes")
	GameDB.reload()


## The real 1990 start (TODO row 142, L1): the 14 clubs' lists rated on 1989,
## each position scaled on its own season (director 2026-11-13), and a real
## player's ceiling set by his real peak, give or take luck.
func _test_real_1990() -> void:
	_check(Datasets.ready("1990"), "The 1990 start's files ship")
	GameDB.reload("1990")
	_check(GameDB.dataset_id == "1990" and GameDB.DATA_SEASON == 1989 and GameDB.START_YEAR == 1990,
			"The 1990 set loads on 1989's season")
	var per_club := {}
	var ovr := []
	var top := 0
	var stars := 0
	var peaked := 0
	var peak_ok := true
	for p in GameDB.players:
		var c := str(p.get("club", ""))
		per_club[c] = int(per_club.get(c, 0)) + 1
		var o := int(p.get("overall", 0))
		ovr.append(o)
		top = maxi(top, o)
		if o >= 80:
			stars += 1
		if int(p.get("real_peak", 0)) > 0:
			peaked += 1
			var pot := int(p.get("potential", 0))
			if pot < o or abs(pot - clampi(int(p["real_peak"]), o, Potential.MAX_POT)) > int(Potential.REAL_PEAK_LUCK) + 1:
				peak_ok = false
	_check(per_club.size() == 14 and not per_club.has("ADE") and per_club.has("FIT"),
			"Fourteen clubs carry a list, Fitzroy's among them and no Adelaide (%s)" % str(per_club.keys()))
	# A list is its played men plus those yet to play a senior game (list_additions).
	var listed := per_club.duplicate()
	for q in GameDB.list_additions:
		var c := str(q.get("club", ""))
		listed[c] = int(listed.get(c, 0)) + 1
	var thin := 0
	for c in listed:
		if int(listed[c]) < 42:
			thin += 1
	_check(thin == 0 and listed.size() == 14, "Every 1990 club has a full list (%s)" % str(listed))
	# A height no source records is his position's average (director 2026-11-13), so none is blank.
	var no_height := []
	for q in GameDB.list_additions:
		if float(q.get("height_cm", 0.0)) < 150.0:
			no_height.append(str(q.get("real_name", "")))
	_check(no_height.is_empty() and not GameDB.list_additions.is_empty(),
			"Every 1990 list addition has a height (missing: %s)" % str(no_height))
	ovr.sort()
	var median := int(ovr[ovr.size() / 2])
	_check(median >= 57 and median <= 65, "The 1990 median sits where 2026's does (%d)" % median)
	var share := float(stars) / float(ovr.size())
	_check(share >= 0.04 and share <= 0.12 and top < 99,
			"About 7%% of the 1990 lists rate 80 or more and nobody tops out (%d of %d, best %d)" % [stars, ovr.size(), top])
	_check(peaked > 200 and peak_ok, "A real peak sets each ceiling, give or take luck (%d players)" % peaked)
	_check(Potential.peak_from_year == 1986, "Recent seasons count from the 1990 set's own data season")
	# Honours lift the decorated to a floor (director 2026-11-13, "Add honours").
	var by_id := {}
	var honoured := 0
	var floor_ok := true
	for p in GameDB.players:
		by_id[str(p.get("id", ""))] = p
		if float(p.get("honours", 0.0)) > 0.0:
			honoured += 1
			if int(p["overall"]) < Ratings.honours_floor(float(p["honours"])):
				floor_ok = false
	_check(honoured >= 60 and floor_ok, "Every honoured 1990 player rates at least his honours floor (%d honoured)" % honoured)
	var roos: Dictionary = by_id.get("FIT_1", {})   # Paul Roos
	_check(not roos.is_empty() and int(roos["overall"]) >= 78 and bool(roos.get("rated_on_honours", false)),
			"Paul Roos, twice All-Australian, rates on his honours (%d)" % int(roos.get("overall", 0)))
	var platten: Dictionary = by_id.get("HAW_44", {})   # John Platten
	_check(not platten.is_empty() and not bool(platten.get("rated_on_honours", false)),
			"A star already above his floor keeps his own rating (Platten %d)" % int(platten.get("overall", 0)))
	GameDB.reload()
	var none := true
	for p in GameDB.players:
		if p.has("honours") or bool(p.get("rated_on_honours", false)):
			none = false
	_check(none, "Today's set carries no honours: a 2026 start is untouched")
	_check(Ratings.era_anchors.is_empty() and Potential.peak_from_year == 2023,
			"Back on 2026, positions scale on 2026's anchors again")
	_golden("load after the 1990 set", _load_print(), GOLDEN_LOAD)


## A 1990 career (TODO row 142, L2): you take Melbourne on its real 1990 list
## and replace its real senior coach, John Northey, who joins the coach pool
## any club may hire from (director 2026-11-13, "You replace him", "Joins the
## coach pool"). Every other club keeps its real 1990 senior coach, and the
## clubs' real 1990 captains lead them.
func _test_legacy_start_1990() -> void:
	var want := _start_1990("MEL")
	_check(GameState.season != null and GameState.season_year == 1990 and GameState.my_club == "MEL",
			"A 1990 career starts in 1990 at the club chosen (%d, %s)" % [GameState.season_year, GameState.my_club])
	var mine := {}
	for p in GameState.my_list:
		mine[str(p["id"])] = true
	var missing := 0
	for id in want:
		if not mine.has(id):
			missing += 1
	_check(not want.is_empty() and missing <= 3,
			"Melbourne start on their real 1990 list (%d of %d on it)" % [want.size() - missing, want.size()])
	_check(GameState.season.clubs.size() == 14, "Fourteen clubs play 1990 (%d)" % GameState.season.clubs.size())
	var by_id := {}
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("real_name", "")) != "":
			by_id[str(c["real_name"])] = c
	var northey: Dictionary = by_id.get("John Northey", {})
	_check(not northey.is_empty() and str(northey.get("status", "")) == "free" and str(northey.get("club", "")) == ""
			and bool(northey.get("former_sc", false)),
			"You replace John Northey, and he is in the coach pool (%s)" % str(northey.get("status", "missing")))
	_check(not northey.is_empty() and CoachMarket.would_take(northey, "STK", "SA", 1990),
			"Another club can hire him")
	var mel := Coaches.staff(GameState.coaches, "MEL")
	_check(not mel.has("SC") and mel.size() == 5, "Melbourne's senior job is yours; its five assistants are hired (%s)" % str(mel.keys()))
	var real_sc := 0
	for club in GameState.season.clubs:
		if club == "MEL":
			continue
		var cid := str(Coaches.staff(GameState.coaches, club).get("SC", ""))
		if cid != "" and str(GameState.coaches[cid].get("real_name", "")) != "":
			real_sc += 1
	_check(real_sc == 13, "The other 13 clubs keep their real 1990 senior coach (%d)" % real_sc)
	var wce := str(Coaches.staff(GameState.coaches, "WCE").get("SC", ""))
	_check(wce != "" and str(GameState.coaches[wce].get("real_name", "")) == "Michael Malthouse",
			"West Coast's is Michael Malthouse")
	var lions := str(Coaches.staff(GameState.coaches, "BRL").get("SC", ""))
	_check(lions != "" and str(GameState.coaches[lions].get("real_name", "")) == "Norm Dare",
			"The Bears' code reads as Brisbane's: Norm Dare")
	# The real 1990 captains: Melbourne's Garry Lyon was not captain until 1993.
	var caps := 0
	for club in GameState.season.clubs:
		for p in (GameState.season.lists[club] as Array):
			if Leadership.role_2026(p) == "captain":
				caps += 1
	_check(caps >= 12, "The clubs' real 1990 captains carry the armband's record (%d)" % caps)
	GameState.reset()
	_check(GameDB.dataset_id == "2026" and Leadership.path == Leadership.PATH and Leadership.shown_through == 2027,
			"A new career is the 2026 set, its captains and coaches again")
	var c26 := Coaches.seed("GEE")
	_check(c26.has("C_chris_scott") and str(c26["C_chris_scott"].get("status", "")) == "free",
			"A 2026 career still seeds 2026's coaches, Chris Scott making way at Geelong")


## A 1990 career at `club`, as Choose your club starts it; returns the ids of
## the club's real 1990 list.
func _start_1990(club: String) -> Dictionary:
	GameState.reset("1990")
	GameState.replay_seed = SUITE_SEED
	GameState.career_seed = SUITE_SEED
	GameState.begin_real_lists()
	var want := {}
	for p in GameDB.club_list(club) + GameDB.club_additions(club):
		want[str(p["id"])] = true
	GameState.choose_real_club(club)
	var guard := 0
	while GameState.draft != null and not GameState.draft.is_finished() and guard < 400:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				break
	GameState.finish_intake_draft()
	return want


## 1990 is the start of a campaign that plays on to 2026 and beyond (director
## 2026-11-13: "its simply the start of a 36+ year campaign"), not a one-year
## task: the career rolls into 1991 on the same set, the coach you replaced is
## still in the coaching world (where the sim took him: "Sim decides"), every
## other club still has a senior coach, and the 1990 captains' record is not
## shown as current in 1991.
func _test_legacy_rolls_into_1991() -> void:
	_start_1990("MEL")
	var northey_id := ""
	for cid in GameState.coaches:
		if str(GameState.coaches[cid].get("real_name", "")) == "John Northey":
			northey_id = str(cid)
	# The rollover is under test, not 200 home and away games: skip to the
	# finals and play those. The Grand Final week closes the season (awards,
	# the coaching market that fills every senior job), so they stay played.
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	var guard := 0
	while not GameState.season.is_season_over() and guard < 60:
		guard += 1
		GameState.advance()
	_check(GameState.season.is_season_over(), "The 1990 season ends with its finals (%d weeks)" % guard)
	_check(GameState.start_next_season(), "The 1990 career rolls on")
	_check(GameState.season_year == 1991 and GameState.my_club == "MEL" and GameDB.dataset_id == "1990"
			and GameState.dataset == "1990",
			"It is 1991 at Melbourne, still the career begun in 1990 (%d, %s, set %s)" % [
				GameState.season_year, GameState.my_club, GameDB.dataset_id])
	var northey: Dictionary = GameState.coaches.get(northey_id, {})
	_check(northey_id != "" and str(northey.get("real_name", "")) == "John Northey"
			and ["free", "club", "away", "out"].has(str(northey.get("status", ""))),
			"John Northey is still in the coaching world in 1991 (%s%s)" % [
				str(northey.get("status", "missing")), "" if str(northey.get("club", "")) == "" else " at " + str(northey.get("club", ""))])
	_check(Coaches.staff(GameState.coaches, "MEL").get("SC", "") == "",
			"Melbourne's senior job is still yours")
	var no_sc := []
	for club in GameState.season.clubs:
		if club != "MEL" and str(Coaches.staff(GameState.coaches, club).get("SC", "")) == "":
			no_sc.append(club)
	_check(no_sc.is_empty(), "Every other club has a senior coach in 1991 (%s)" % str(no_sc))
	var shown := 0
	for club in GameState.season.clubs:
		for p in (GameState.season.lists[club] as Array):
			if Leadership.role_line(p, GameState.season_year) != "":
				shown += 1
	_check(shown == 0, "The 1990 captains' record is not shown as current in 1991 (%d)" % shown)
	GameState.reset()


## A 1990 League redraft (director 2026-11-13: "make a 1990 redraft campaign
## possible too"): the 14 clubs of 1990 re-draft from one pool of their
## players, no club that joined later is in it, and you still take over from
## your club's real senior coach, who joins the coach pool. The season is 1990
## and rolls into 1991 on the same set.
func _test_legacy_redraft_1990() -> void:
	GameState.reset("1990")
	GameState.replay_seed = SUITE_SEED
	GameState.career_seed = SUITE_SEED
	GameState.begin_draft()
	var draft: Draft = GameState.draft
	var late := []
	for code in ["ADE", "PA", "PTA", "FRE", "GC", "GCS", "GWS", "TAS", "CANB"]:
		if draft.clubs.has(code):
			late.append(code)
	_check(draft.clubs.size() == 14 and draft.clubs.has("MEL") and late.is_empty() and GameState.expansion_from == 0,
			"The 1990 League redraft has the 14 clubs of 1990 and no later club (%d clubs, %s)" % [draft.clubs.size(), str(late)])
	var real_ids := {}
	for p in GameDB.all_players_sorted():
		real_ids[str(p["id"])] = true
	draft.start_for_user("MEL")
	var guard := 0
	draft.auto_until_user_turn()
	while not draft.is_finished() and guard < 8000:
		guard += 1
		var cand := draft._best_ai_pick(draft.current_club())
		if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
			draft._skip_current_pick()
		draft.auto_until_user_turn()
	_check(draft.is_finished(), "The 1990 League redraft completes")
	var mine: Array = draft.list()
	var from_1990 := 0
	for p in mine:
		from_1990 += 1 if real_ids.has(str(p.get("id", ""))) else 0
	GameState.start_season("MEL", mine)
	var by_id := {}
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("real_name", "")) != "":
			by_id[str(c["real_name"])] = c
	var northey: Dictionary = by_id.get("John Northey", {})
	_check(GameState.season_year == 1990 and GameState.my_club == "MEL" and GameState.season.ladder.size() == 14,
			"You coach Melbourne in 1990 on a 14-club ladder (%d, %s, %d clubs)" % [
				GameState.season_year, GameState.my_club, GameState.season.ladder.size()])
	_check(str(northey.get("status", "")) == "free" and str(northey.get("club", "")) == ""
			and not Coaches.staff(GameState.coaches, "MEL").has("SC")
			and str(GameState.coaches.get(str(Coaches.staff(GameState.coaches, "WCE").get("SC", "")), {}).get("real_name", "")) == "Michael Malthouse",
			"A redraft still replaces John Northey, who is a free coach; West Coast keep Mick Malthouse (%s)" % str(northey.get("status", "missing")))
	_check(mine.size() >= 30 and from_1990 > 0,
			"Your redrafted list is drawn from the 1990 pool (%d players, %d real)" % [mine.size(), from_1990])
	GameState.reset()


## Director 2026-11-13, "Rate from records": each 1990 coach is rated from his
## real senior record before 1990, not a flat era rating.
func _test_era_coach_ratings() -> void:
	GameState.reset("1990")
	var seeded := Coaches.seed("MEL")
	var by := {}
	for cid in seeded:
		by[str(seeded[cid].get("real_name", ""))] = seeded[cid]["skills"]
	var sk := func(n: String, k: String) -> int: return int((by.get(n, {}) as Dictionary).get(k, -1))
	_check(sk.call("Kevin Sheedy", "tactics") > sk.call("Ken Sheldon", "tactics")
			and sk.call("Allan Jeans", "tactics") > sk.call("Kevin Bartlett", "tactics"),
			"Proven coaches rate above unproven ones (Sheedy %d vs Sheldon %d, Jeans %d vs Bartlett %d)" % [
				sk.call("Kevin Sheedy", "tactics"), sk.call("Ken Sheldon", "tactics"),
				sk.call("Allan Jeans", "tactics"), sk.call("Kevin Bartlett", "tactics")])
	_check(sk.call("John Northey", "tactics") > 0 and sk.call("Ray Jordon", "tactics") == 62,
			"Your replaced coach is rated too; an under-19s coach with one senior game keeps 62 (%d, %d)" % [
				sk.call("John Northey", "tactics"), sk.call("Ray Jordon", "tactics")])
	_check(Coaches._era_ratings("res://data/coaches_2026.csv", 2026).is_empty(),
			"No ratings file beside the 2026 staff: the 2026 coaches are untouched")
	GameState.reset()
