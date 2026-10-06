extends RefCounted
## Chronology: the completed 2026 season is history, a career starts in
## 2027, and every system agrees - drafts, ages, careers, coaches, saves.
## Run through tests/run_chronology_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_test_start_year()
	_test_league_draft_pool()
	_test_first_class()
	_test_ages()
	_test_coaches()
	_test_save_year()
	_test_old_2026_career()
	_test_home_states()
	GameState.replay_seed = 0
	print("Chronology tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_start_year() -> void:
	_check(GameDB.DATA_SEASON == 2026 and GameDB.START_YEAR == 2027,
			"The data is the 2026 season; careers start in 2027")
	GameState.reset()
	_check(GameState.season_year == 2027, "A new career's first season is 2027")
	_check(GameDB.active_clubs(2027).size() == 18 and not GameDB.active_clubs(2027).has("TAS"),
			"2027 is the founding eighteen")
	_check(GameDB.enter_year("TAS") == 2028 and GameDB.enter_year("CANB") == 2030,
			"Tasmania still enters in 2028, Canberra in 2030")


## The 2027 League Draft takes the whole 2026 league: every player and every
## prospect of the 2026 class, each once.
func _test_league_draft_pool() -> void:
	GameState.reset()
	GameState.begin_draft()
	var d: Draft = GameState.draft
	var ids := {}
	var dup := false
	for p in d.pool:
		if ids.has(str(p["id"])):
			dup = true
		ids[str(p["id"])] = true
	var players_in := true
	for p in GameDB.players:
		if not ids.has(str(p["id"])):
			players_in = false
	var class_in := 0
	for p in GameDB.draftees:
		if ids.has(str(p["id"])):
			class_in += 1
	_check(players_in and not dup, "Every 2026 player is in the League Draft pool once")
	_check(class_in == GameDB.draftees.size() and class_in > 40,
			"The 2026 draft class is in the 2027 League Draft (%d prospects)" % class_in)
	_check(d.clubs.size() == 18 and d.target_size == mini(Ratings.LIST_SIZE, d.pool.size() / 18),
			"Eighteen clubs draft %d-player lists" % d.target_size)
	var later := false
	for p in d.pool:
		if int(p.get("draft_year", GameDB.DATA_SEASON)) > GameDB.DATA_SEASON:
			later = true
	_check(not later, "No later class leaks into the League Draft")
	GameState.reset()


## The first class a career drafts is 2027's, drafted after the 2027 season.
func _test_first_class() -> void:
	GameState.reset()
	var pool: Array = GameState.draftee_pool
	var only_2027 := not pool.is_empty()
	for p in pool:
		if int(p.get("draft_year", 0)) != 2027 or str(p["id"]).begins_with("D2026_"):
			only_2027 = false
	_check(only_2027, "The first in-career draft class is the 2027 class, not 2026's (%d)" % pool.size())
	_check(GameState.class_tiers.has("2027"), "Its class quality is recorded for 2027")
	# Same career seed, same class: no reroll on reload or restart.
	GameState.career_seed = 4242
	var a := GameState._first_class(2027)
	GameState.career_seed = 4242
	var b := GameState._first_class(2027)
	var same := a.size() == b.size()
	for i in range(mini(a.size(), b.size())):
		if str(a[i]["id"]) != str(b[i]["id"]) or int(a[i]["overall"]) != int(b[i]["overall"]) \
				or not is_equal_approx(float(a[i]["age"]), float(b[i]["age"])):
			same = false
	_check(same, "The first class is deterministic for a career seed")
	# It is drafted when the 2027 season ends.
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "The first national draft opens after 2027")
	var d: Draft = GameState.draft
	var open_2027 := true
	for p in d.pool:
		if int(p.get("draft_year", 0)) != 2027:
			open_2027 = false
	_check(open_2027, "...and drafts the 2027 class")
	GameState.reset()


## Ages are as of the start of 2027, from date of birth: one year on from
## 2026, never two.
func _test_ages() -> void:
	var ok := true
	var bad := ""
	for p in GameDB.players:
		var dob := str(p.get("dob", ""))
		if dob.length() < 10:
			continue
		var want := float(Prospects.days_between(dob, GameDB.START_DATE)) / 365.25
		if not is_equal_approx(float(p["age"]), want):
			ok = false
			bad = "%s %.2f v %.2f" % [p.get("real_name", ""), float(p["age"]), want]
	_check(ok, "Every player's age is his age at the start of 2027 %s" % bad)
	var dawson := {}
	for p in GameDB.players:
		if str(p.get("real_name", "")) == "Jordan Dawson":
			dawson = p
	_check(not dawson.is_empty() and float(dawson["age"]) > 29.5 and float(dawson["age"]) < 30.8,
			"Jordan Dawson starts 2027 aged 30 (he was 29 in 2026)")
	var young := true
	for p in GameDB.draftees:
		if float(p["age"]) < 17.5 or float(p["age"]) > 20.5:
			young = false
	_check(young, "The 2026 class starts 2027 aged 17.5 to 20.5")
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var carried := true
	for p in GameState.my_list:
		var src = GameDB.player_by_id(str(p["id"]))
		if src is Dictionary and not is_equal_approx(float(p["age"]), float((src as Dictionary)["age"])):
			carried = false
	_check(carried, "Starting a career does not age anyone again")


## Coaches: the Round 1 2026 research is the source; the career's world is
## that one carried into 2027, with you in your club's top job.
func _test_coaches() -> void:
	_check(Coaches.SEED_CSV.ends_with("coaches_2026.csv") and Coaches.SEED_YEAR == 2026,
			"The coaching source stays the researched Round 1 2026 seed")
	GameState.reset()
	GameState.start_season("CAR", GameDB.club_list("CAR"))
	var cont := true
	var future := false
	var displaced := {}
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		for st in c.get("stints", []):
			if int(st[2]) > 2026 or (int(st[3]) != 0 and int(st[3]) > 2026):
				future = true
		if str(c.get("status", "")) == "club":
			var st: Array = (c["stints"] as Array)[-1]
			if int(st[2]) != 2026 or int(st[3]) != 0:
				cont = false
		elif (c.get("stints", []) as Array).size() == 1 and str(c["stints"][0][0]) == "CAR" \
				and str(c["stints"][0][1]) == "SC":
			displaced = c
	_check(cont, "Every coach in a job has been there since the 2026 the research records")
	_check(not future, "No coaching appointment is claimed for 2027 or later")
	_check(not displaced.is_empty() and str(displaced["stints"][0]) == str(["CAR", "SC", 2026, 2026])
			and str(displaced.get("status", "")) == "free",
			"Your club's senior coach coached 2026 and makes way for you in 2027")
	_check(not GameState.club_staff("CAR").has("SC"), "You are the senior coach")
	GameState.reset()


func _test_save_year() -> void:
	GameState.reset()
	GameState.start_season("SYD", GameDB.club_list("SYD"))
	_check(GameState.save_career(), "A new career saves")
	var meta := CareerSave.read_meta(GameState.save_path)
	_check(int(meta.get("year", 0)) == 2027, "Its save says 2027 (%s)" % str(meta.get("year", "")))
	_check(GameState.load_career() and GameState.season_year == 2027, "It loads in 2027")
	GameState.delete_saved_career()
	GameState.reset()


## A career an older build began in 2026 keeps its own timeline: no 2026
## season added to careers (it plays 2026), and it drafts the real 2026 class.
func _test_old_2026_career() -> void:
	GameState.reset()
	GameState.season_year = GameDB.DATA_SEASON
	GameState.draftee_pool = []
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	var through_ok := true
	for p in GameState.my_list:
		if int(Career.of(p).get("through", 0)) > GameDB.DATA_SEASON - 1:
			through_ok = false
	_check(through_ok, "A 2026 career's records stop at 2025: it plays 2026 itself")
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "Its first national draft opens")
	var real_class := true
	for p in GameState.draft.pool:
		if not str(p["id"]).begins_with("D2026_"):
			real_class = false
	_check(real_class, "...and drafts the real 2026 class, as before")
	GameState.reset()


## Players load with a home state from data/player_origin_2026.csv, and a
## player whose state is blank has none.
func _test_home_states() -> void:
	GameDB.reload()
	var dawson: Dictionary = {}
	var with_state := 0
	var blank_has_one := false
	var blanks := 0
	for p in GameDB.players:
		if str(p["club"]) == "ADE" and int(p["num"]) == 12 and str(p["last"]) == "Dawson":
			dawson = p
		if p.has("home_state"):
			with_state += 1
		else:
			blanks += 1
		if p.has("home_state") and str(p["home_state"]) == "":
			blank_has_one = true
	_check(not dawson.is_empty() and str(dawson.get("home_state", "")) == "SA", "A known row loads: Jordan Dawson's home state is SA")
	_check(with_state > 600 and blanks > 0, "Most 2026 players load with a home state, and some have none (%d with, %d without)" % [with_state, blanks])
	_check(not blank_has_one, "A player with no state in the data has no home_state, not an empty one")
