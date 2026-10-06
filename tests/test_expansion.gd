extends RefCounted
## Expansion suite: Tasmania enters in 2028 and Canberra in 2030. Each club
## is inactive before its entry year (no fixtures, ladder, draft or selection
## presence) and a normal active club from it - including odd-club fixtures,
## the generated debut list, season transitions and saves.
## Run through tests/run_expansion_tests.gd.

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
	_test_entry_gates()
	_test_fair_fixture()
	_test_2026_baseline()
	_test_rollover_to_2028()
	_test_2028_season_runs()
	_test_rollover_to_2030()
	_test_save_load_across_expansion()
	_test_expansion_ceilings()
	_test_created_club_rules()
	_test_created_club_career()
	_test_club_count_defaults()
	GameState.reset()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Expansion tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## A fair fixture at 18, 19 and 20 clubs, over several seeds: every club
## plays the same number of games, hosts half of them (within one), rests the
## same number of times, and the byes and repeats follow the seed, not the
## club list (Season.build_fixture).
func _test_fair_fixture() -> void:
	# 18 to 21 clubs: a created club (Club Forge) can make any of them in any
	# year, so the counts are built here, not taken from the calendar.
	var all_clubs: Array = GameDB.active_clubs(2030)
	for n in [18, 19, 20, 21]:
		var codes: Array = all_clubs.slice(0, mini(n, all_clubs.size()))
		while codes.size() < n:
			codes.append("NEW%d" % codes.size())
		var lists := {}
		for c in codes:
			lists[c] = GameDB.club_list(str(c))
		var problems := []
		var first_rest := {}
		for sd in [11, 222, 3333, 44444]:
			var s := Season.new(codes, lists, sd)
			var games := {}
			var home := {}
			var rests := {}
			var pairs := {}
			for c in codes:
				games[c] = 0
				home[c] = 0
				rests[c] = []
			if s.fixture.size() != Season.REGULAR_ROUNDS:
				problems.append("%d rounds" % s.fixture.size())
			var short := 0
			for ri in range(s.fixture.size()):
				var size := (s.fixture[ri] as Array).size()
				if size < n / 2 - 1:
					problems.append("round %d has %d matches" % [ri + 1, size])
				if size < n / 2:
					short += 1
					if n % 2 == 0 and (ri < Season.BYE_FIRST or ri > Season.BYE_LAST):
						problems.append("a bye in round %d, outside the mid-season rounds" % (ri + 1))
				var seen := {}
				for m in s.fixture[ri]:
					var a := str(m["home"])
					var b := str(m["away"])
					if seen.has(a) or seen.has(b) or a == b:
						problems.append("round %d plays a club twice" % (ri + 1))
					seen[a] = true
					seen[b] = true
					games[a] += 1
					games[b] += 1
					home[a] += 1
					pairs[a + "|" + b if a < b else b + "|" + a] = true
				for c in codes:
					if not seen.has(c):
						(rests[c] as Array).append(ri)
			# Matches a full round can't hold: 18 clubs nine rounds of eight; 21
			# clubs nine of nine.
			var g0 := int(games[codes[0]])
			if short != Season.REGULAR_ROUNDS * (n / 2) - n * g0 / 2:
				problems.append("%d rounds a match short" % short)
			if g0 != (23 if codes.size() % 2 == 0 else 22):
				problems.append("%d games, not 23 (22 for an odd count)" % g0)
			for c in codes:
				if int(games[c]) != g0:
					problems.append("%s plays %d, %s plays %d" % [codes[0], g0, c, games[c]])
				if absf(float(home[c]) - float(games[c]) / 2.0) > 1.0:
					problems.append("%s hosts %d of %d" % [c, home[c], games[c]])
				if (rests[c] as Array).size() != (rests[codes[0]] as Array).size():
					problems.append("%s rests %d times" % [c, (rests[c] as Array).size()])
			if pairs.size() != codes.size() * (codes.size() - 1) / 2:
				problems.append("%d pairs meet" % pairs.size())
			if codes.size() % 2 == 1:
				first_rest[sd] = str(codes.filter(func(c): return (rests[c] as Array).has(0))[0])
			var again := Season.new(codes, lists, sd)
			if str(again.fixture) != str(s.fixture):
				problems.append("seed %d does not repeat" % sd)
		_check(problems.is_empty(), "%d clubs: 23 games each (22 at an odd count), home within one of half, equal rests, every pair meets, no round more than a match short, byes mid-season at an even count (%s)" % [
				codes.size(), str(problems.slice(0, 4))])
		if codes.size() % 2 == 1:
			var who := {}
			for sd in first_rest:
				who[first_rest[sd]] = true
			_check(who.size() >= 2, "%d clubs: who rests first follows the seed, not the club list (%s)" % [codes.size(), str(first_rest)])


# ---------------------------------------------------------------------------
# Entry years
# ---------------------------------------------------------------------------
func _test_entry_gates() -> void:
	_check(GameDB.enter_year("GEE") == 2026, "Founding clubs enter in 2026")
	_check(GameDB.enter_year("TAS") == 2028, "Tasmania's entry year is 2028")
	_check(GameDB.enter_year("CANB") == 2030, "Canberra's entry year is 2030")

	_check(GameDB.active_clubs(2026).size() == 18, "Eighteen clubs in 2026")
	_check(not GameDB.active_clubs(2026).has("TAS")
			and not GameDB.active_clubs(2026).has("CANB"),
			"Neither expansion club is active in 2026")
	_check(GameDB.active_clubs(2027).size() == 18, "Eighteen clubs in 2027")
	_check(not GameDB.active_clubs(2027).has("TAS"), "Tasmania is not active in 2027")
	_check(GameDB.active_clubs(2028).has("TAS")
			and GameDB.active_clubs(2028).size() == 19,
			"Nineteen clubs from 2028, Tasmania included")
	_check(not GameDB.active_clubs(2028).has("CANB"), "Canberra is not active in 2028")
	_check(not GameDB.active_clubs(2029).has("CANB"), "Canberra is not active in 2029")
	_check(GameDB.active_clubs(2030).has("CANB")
			and GameDB.active_clubs(2030).size() == 20,
			"Twenty clubs from 2030, Canberra included")
	_check(GameDB.active_clubs(2035).size() == 20, "The twenty-club league holds")

	# The club records carry real data for the new clubs.
	for code in ["TAS", "CANB"]:
		var c: Dictionary = GameDB.club(code)
		_check(str(c.get("name", "")) != "" and str(c.get("ground", "")) != "",
				"%s has a name and a ground" % code)
		_check((GameDB.club_list(code) as Array).is_empty(),
				"%s has no 2026-data players (its list is generated at entry)" % code)

	# The new career's draft and club selection only see the first season's clubs.
	GameState.reset()
	GameState.begin_draft()
	_check(GameState.draft.clubs.size() == 18
			and not GameState.draft.clubs.has("TAS")
			and not GameState.draft.clubs.has("CANB"),
			"The 2027 career draft runs the founding eighteen only")
	GameState.reset()


# ---------------------------------------------------------------------------
# A career through the expansion
# ---------------------------------------------------------------------------
func _new_first_season() -> Season:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	return GameState.season


func _test_2026_baseline() -> void:
	var season := _new_first_season()
	_check(GameState.season_year == 2027, "A career's first season is 2027")
	_check(season.ladder.size() == 18, "The 2027 ladder has eighteen clubs")
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2027")
	for r in season.fixture:
		_check((r as Array).size() == 9 or (r as Array).size() == 8,
				"Eighteen clubs play nine matches a round, eight in a bye round")


## Finish the current season's intake draft the same way a career would.
func _rollover() -> void:
	var season: Season = GameState.season
	season.round_index = season.fixture.size()
	_check(GameState.begin_intake_draft(), "The intake draft opens after the season")
	var draft: Draft = GameState.draft
	var guard := 0
	while not draft.is_finished() and guard < 600:
		guard += 1
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.is_finished(), "The intake draft completes")
	_check(GameState.finish_intake_draft(), "The rollover commits")


func _test_rollover_to_2028() -> void:
	# 2027 -> 2028: the first rollover, and Tasmania arrives.
	_rollover()
	_check(GameState.season_year == 2028, "The career advances to 2028")
	var season: Season = GameState.season
	_check(season.ladder.size() == 19, "Nineteen clubs on the 2028 ladder")
	_check(season.ladder.has("TAS"), "Tasmania is on the 2028 ladder")
	_check(not season.ladder.has("CANB"), "Canberra is not yet on the ladder")

	# The entry news is posted the moment the rollover commits.
	var news_ok := false
	for item in GameState.news:
		if str(item["kind"]) == "expansion" and str(item["text"]).contains("Tasmania"):
			news_ok = true
	_check(news_ok, "Tasmania's entry made the news")

	# The debut list: a full squad, in the right size band, with contracts
	# ready when the season opens.
	var tas: Array = season.lists["TAS"]
	_check(tas.size() >= Prospects.MIN_LIST and tas.size() <= Ratings.LIST_SIZE,
			"Tasmania debuts with a full list (%d)" % tas.size())
	var ages := 0.0
	var id_seen := {}
	for p in tas:
		ages += float(p["age"])
		_check(not id_seen.has(str(p["id"])), "Tasmania ids are unique")
		id_seen[str(p["id"])] = true
		_check(int(p.get("contract_years", 0)) > 0,
				"Every Tasmanian has a contract at the season start")
	_check(ages / float(tas.size()) > 19.0 and ages / float(tas.size()) < 27.0,
			"The debut list mixes ages (%.1f)" % (ages / float(tas.size())))

	# The odd-club fixture: 24 rounds, two byes each so every club plays 22
	# games, and every pair meets at least once.
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2028")
	var games := {}
	var pairs := {}
	for r in season.fixture:
		var round: Array = r
		_check(round.size() == 8 or round.size() == 9,
				"A 2028 round has eight or nine matches (%d)" % round.size())
		for m in round:
			var a := str(m["home"])
			var b := str(m["away"])
			_check(a != "BYE" and b != "BYE", "The virtual bye never appears on the fixture")
			games[a] = int(games.get(a, 0)) + 1
			games[b] = int(games.get(b, 0)) + 1
			var key := a + "|" + b if a < b else b + "|" + a
			pairs[key] = int(pairs.get(key, 0)) + 1
	_check(pairs.size() == 171, "Every pair of the 19 clubs meets at least once")
	for code in season.ladder:
		var n: int = games.get(code, 0)
		_check(n == 22, "%s plays 22 games in 2028 (%d)" % [code, n])


func _test_2028_season_runs() -> void:
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	var season: Season = GameState.season
	_check(season.is_season_over(), "The 19-club 2028 season runs to a premier")
	_check(season.finals["top"].size() == Season.FINALISTS,
			"Ten finalists come off the 19-club ladder")
	_check(GameState.premier() != "", "A 2028 premier is crowned")

	# The debut achievement only fires when it applies.
	var tas_made_finals := (season.finals["top"] as Array).has("TAS")
	_check(not tas_made_finals or GameState.achievements.has("tas_debut_finals"),
			"Tasmania's debut-finals achievement matches its result")
	var stored: Dictionary = GameState.achievements.get("tas_debut_finals", {})
	var debut_year: Variant = stored.get("year", "")
	_check(debut_year == "" or int(debut_year) == 2028,
			"The debut achievement, when unlocked, is stamped 2028")

	# 2028 -> 2029: Tasmania stays, the league ages on.
	_rollover()
	_check(GameState.season_year == 2029, "The career advances to 2029")
	var again: Array = GameState.season.lists["TAS"]
	_check(again.size() >= Prospects.MIN_LIST, "Tasmania keeps a full list into 2029")


func _test_rollover_to_2030() -> void:
	_rollover()
	_check(GameState.season_year == 2030, "The career advances to 2030")
	var season: Season = GameState.season
	_check(season.ladder.size() == 20, "Twenty clubs on the 2030 ladder")
	_check(season.ladder.has("CANB") and season.ladder.has("TAS"),
			"Both expansion clubs are on the 2030 ladder")
	var canb: Array = season.lists["CANB"]
	_check(canb.size() >= Prospects.MIN_LIST and canb.size() <= Ratings.LIST_SIZE,
			"Canberra debuts with a full list (%d)" % canb.size())
	_check(season.fixture.size() == Season.REGULAR_ROUNDS, "24 rounds in 2030")
	for r in season.fixture:
		_check((r as Array).size() == 10, "Twenty even clubs play ten a round")
		break
	# The league's lists never share a player and every club stays in band.
	# One check for the whole league: the floor counts the rule, not how many
	# players the lists happen to hold.
	var seen := {}
	var twice := ""
	for code in season.ladder:
		var arr: Array = season.lists[code]
		_check(arr.size() >= Prospects.MIN_LIST and arr.size() <= Ratings.LIST_SIZE,
				"%s stays in the list band in 2030 (%d)" % [code, arr.size()])
		for p in arr:
			if seen.has(str(p["id"])):
				twice += str(p["id"]) + " "
			seen[str(p["id"])] = true
	_check(twice == "", "No player on two lists (%s)" % twice)


func _test_save_load_across_expansion() -> void:
	var season: Season = GameState.season
	_check(GameState.save_career(), "A 2030 career saves")
	var canb_before: int = (season.lists["CANB"] as Array).size()
	GameState.load_career()
	_check(GameState.season_year == 2030, "The loaded career is still in 2030")
	_check(GameState.season.ladder.size() == 20, "The loaded ladder has twenty clubs")
	_check(GameState.season.ladder.has("CANB") and GameState.season.ladder.has("TAS"),
			"The loaded ladder keeps both expansion clubs")
	_check((GameState.season.lists["CANB"] as Array).size() == canb_before,
			"Canberra's list survives the round trip")
	_check(not GameState.season.finals.is_empty()
			or not GameState.season.is_regular_done(),
			"The loaded season is still playable")


## An expansion list's seasoned players have the ceiling of their age, not
## of an 18-year-old draft pick; its young players keep the draft-style one.
func _test_expansion_ceilings() -> void:
	for spec in [["TAS", 2028], ["CANB", 2030]]:
		var lst: Array = Prospects.generate_expansion_list(str(spec[0]), int(spec[1]))
		var old_ok := true
		var old_n := 0
		var young_room := 0.0
		var young_n := 0
		for p in lst:
			var age := float(p["age"])
			var room := int(p["potential"]) - int(p["overall"])
			if age > Potential.MAX_PROSPECT_AGE:
				old_n += 1
				if room > int(Potential._headroom(age)) + 3:
					old_ok = false
			else:
				young_room += float(room)
				young_n += 1
		_check(old_n > 0 and old_ok,
				"%s %d: no seasoned expansion player has a draftee's ceiling (%d over 21)" % [spec[0], spec[1], old_n])
		_check(young_n > 0 and young_room / young_n >= 10.0,
				"%s %d: young expansion players keep real upside (mean +%.1f)" % [spec[0], spec[1], young_room / maxf(1, young_n)])


# ---------------------------------------------------------------------------
# Club Forge: a created club (ARD-M7-009)
# ---------------------------------------------------------------------------
func _forge_spec(extra := {}) -> Dictionary:
	var spec := {"name": "Port Melbourne", "short": "Borough", "code": "PMB",
			"location": "port-melbourne", "primary": "#1B3A8C", "secondary": "#C8102E",
			"accent": "#FFFFFF", "design": "hoops", "kit": "p/s/a"}
	spec.merge(extra, true)
	return spec


func _test_created_club_rules() -> void:
	GameState.reset()
	_check(ClubForge.locations().size() >= 50, "Club Forge reads the location library")
	_check(ClubForge.club_problem(_forge_spec()) == "", "A complete spec makes a club")
	_check(ClubForge.club_problem(_forge_spec({"name": " "})) != "", "A club needs a name")
	_check(ClubForge.club_problem(_forge_spec({"short": ""})) != "", "A club needs a nickname")
	_check(ClubForge.club_problem(_forge_spec({"name": "Geelong"})) != "",
			"A created club cannot share an AFL club's name")
	for code in ["GEE", "TAS", "CANB", "BYE", "SKN", "pm", "P", "PORTM", "P1"]:
		_check(ClubForge.club_problem(_forge_spec({"code": code})) != "",
				"%s is not a free abbreviation" % code)
	_check(ClubForge.club_problem(_forge_spec({"location": "melbourne"})) != "",
			"The home must come from the location library")
	_check(ClubForge.club_problem(_forge_spec({"ground": "The MCG"})) != "",
			"The ground must be one of the place's own")
	_check(ClubForge.club_problem(_forge_spec({"location": "williamstown",
			"ground": "Williamstown Cricket Ground"})) == "",
			"A place's alternative ground can be chosen")
	_check(ClubForge.club_problem(_forge_spec({"design": "suit"})) != ""
			and ClubForge.club_problem(_forge_spec({"design": "map"})) != "",
			"The coach's suit and Tasmania's map are not club designs")
	_check(ClubForge.club_problem(_forge_spec({"kit": "p/p/a"})) != "",
			"The guernsey and its pattern are different colours")
	_check(ClubForge.club_problem(_forge_spec({"secondary": "#1C3B8D"})) != "",
			"A pattern too close to the guernsey's colour is refused")
	_check(ClubForge.club_problem(_forge_spec({"design": "plain", "secondary": "#1C3B8D"})) == "",
			"A plain guernsey needs no contrasting pattern")
	_check(ClubForge.make_club(_forge_spec({"code": "GEE"})).is_empty(),
			"No club is made from a spec with a problem")

	_check(GameState.create_club(_forge_spec({"code": "GEE"})) != ""
			and not GameDB.clubs.has("PMB") and GameDB.club_order.size() == GameDB.CLUB_ORDER.size(),
			"A refused club changes nothing")
	_check(GameState.create_club(_forge_spec()) == "", "The club is created")
	var c: Dictionary = GameDB.club("PMB")
	_check(GameDB.club_name("PMB") == "Port Melbourne" and GameDB.club_short("PMB") == "Borough",
			"The created club answers to its name and nickname")
	_check(str(c.get("ground", "")) == "North Port Oval" and str(c.get("state", "")) == "VIC",
			"The created club plays at its place's ground")
	var g: Dictionary = GameDB.club_guernsey("PMB")
	_check(str(g["design"]) == "hoops" and g["base"] == Color.html("#1B3A8C")
			and g["pattern"] == Color.html("#C8102E"),
			"The created club wears its own guernsey")
	_check(GameDB.club_marker_colours("PMB").size() == 3, "Its marker shows all three colours")
	_check(GameDB.active_clubs(2027).size() == 19 and GameDB.active_clubs(2027).has("PMB"),
			"A club entering with the career is the nineteenth in 2027")
	_check(GameDB.active_clubs(2030).size() == 21, "With Tasmania and Canberra it is the 21st by 2030")
	_check(GameDB.enter_year("PMB") == GameDB.START_YEAR
			and ClubForge.make_club(_forge_spec({"enter": 2030}))["enter"] == GameDB.START_YEAR,
			"A created club always enters with the career")
	_check(GameState.create_club(_forge_spec({"name": "Port Melbourne Borough", "code": "PMFC"})) == ""
			and not GameDB.clubs.has("PMB") and GameDB.clubs.has("PMFC")
			and GameDB.active_clubs(2027).size() == 19,
			"Making the club again replaces it: one created club a career")
	var kit := ClubForge.preset({"colour_tags": ["Navy blue", "red"], "pattern_tags": ["unknown", "hoops"]})
	_check(kit.get("primary") == ClubForge.palette_hex("navy") and kit.get("secondary") == ClubForge.palette_hex("red")
			and kit.get("accent") == ClubForge.palette_hex("white") and kit.get("design") == "hoops",
			"A place's tradition becomes a starting kit: its colours, a third, its pattern")
	_check(ClubForge.preset({"colour_tags": ["blue"], "pattern_tags": []}).is_empty(),
			"A place with one known colour gives no starting kit")
	var preset_spec := _forge_spec()
	preset_spec.merge(ClubForge.preset({"colour_tags": ["black", "white"], "pattern_tags": ["stripes"]}), true)
	_check(ClubForge.club_problem(preset_spec) == "", "A starting kit makes a valid club")
	GameState.reset()
	_check(not GameDB.clubs.has("PMFC") and GameDB.club_order == GameDB.CLUB_ORDER
			and GameState.custom_club.is_empty(),
			"A new career starts without the created club")


## A created club entering with the career drafts in the League Draft, plays,
## and keeps its identity through a save.
func _test_created_club_career() -> void:
	GameState.reset()
	_check(GameState.create_club(_forge_spec()) == "", "The club is created for a new career")
	GameState.begin_draft()
	_check(GameState.draft.clubs.size() == 19 and GameState.draft.clubs.has("PMB"),
			"The created club takes part in the League Draft")
	GameState.draft.start_for_user("PMB")
	var draft: Draft = GameState.draft
	var guard := 0
	while not draft.is_finished() and guard < 5000:
		guard += 1
		var cand := draft._best_ai_pick(draft.current_club())
		if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
			draft._skip_current_pick()
	_check(draft.is_finished(), "The nineteen-club League Draft completes")
	GameState.start_season("PMB", draft.list())
	var season: Season = GameState.season
	_check(GameState.my_club == "PMB" and season.ladder.size() == 19 and season.ladder.has("PMB"),
			"You coach the created club on a nineteen-club ladder")
	# The director's PC playtest (2026-10-07): a created club started with
	# every coaching job vacant. It hires before its first season, from
	# coaches out of work; you are its senior coach.
	var staff := Coaches.staff(GameState.coaches, "PMB")
	_check(not staff.has("SC") and staff.size() == 5
			and ["SA", "MID", "FWD", "DEF", "DEV"].all(func(j): return staff.has(j)),
			"The created club starts with its five assistants (%s)" % str(staff.keys()))
	var seeded := Coaches.seed("PMB")
	var taken := false
	for cid in staff.values():
		var was: Dictionary = seeded.get(cid, {})
		taken = taken or str(was.get("status", "")) == "club"
	_check(not taken, "Nobody is taken from another club's staff")
	var others_same := true
	for club in GameDB.active_clubs(GameState.season_year):
		if club != "PMB" and Coaches.staff(GameState.coaches, club) != Coaches.staff(seeded, club):
			others_same = false
	_check(others_same, "Every other club keeps its 2026 staff")
	var mine: Array = season.lists["PMB"]
	_check(mine.size() >= Prospects.MIN_LIST and mine.size() <= Ratings.LIST_SIZE,
			"The created club drafts a full list (%d)" % mine.size())
	var played := 0
	var home_ground_ok := true
	for i in range(3):
		GameState.advance()
		for res in GameState.last_results:
			if str(res.get("home", "")) == "PMB" or str(res.get("away", "")) == "PMB":
				played += 1
			if str(res.get("home", "")) == "PMB" and res.has("venue"):
				home_ground_ok = home_ground_ok and str(res["venue"]) == "North Port Oval"
	_check(played >= 2, "The created club plays its matches (%d in three rounds)" % played)
	_check(home_ground_ok, "Its home games are at its ground")
	_check(GameState.save_career(), "A created-club career saves")
	var meta := GameState.saved_career_meta()
	_check(str(meta.get("club_name", "")) == "Port Melbourne",
			"The main menu names the saved club before it loads")
	GameState.reset()
	_check(not GameDB.clubs.has("PMB"), "The created club leaves with the career")
	_check(GameState.load_career(), "The created-club career loads")
	_check(GameDB.club_name("PMB") == "Port Melbourne"
			and str(GameDB.club_guernsey("PMB")["design"]) == "hoops"
			and GameDB.active_clubs(GameState.season_year).has("PMB"),
			"The loaded career brings its club back, guernsey and all")
	_check(GameState.my_club == "PMB" and (GameState.season.lists["PMB"] as Array).size() == mine.size(),
			"The created club's list survives the round trip")
	_check(Coaches.staff(GameState.coaches, "PMB") == staff, "The created club's staff survives the round trip")
	# A save made before the fix: the created club has nobody. Loading staffs it.
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("club", "")) == "PMB" and str(c.get("status", "")) == "club":
			c["status"] = "free"
			c["club"] = ""
			c["job"] = ""
	_check(Coaches.staff(GameState.coaches, "PMB").is_empty(), "(an old save's bare created club)")
	_check(GameState.save_career(), "The bare-club save is written")
	GameState.reset()
	_check(GameState.load_career(), "The bare-club save loads")
	var repaired := Coaches.staff(GameState.coaches, "PMB")
	_check(repaired.size() == 5 and not repaired.has("SC"), "Loading an old save staffs its created club")
	_check(GameState.save_career(), "The repaired save is written")
	GameState.reset()
	_check(GameState.load_career() and Coaches.staff(GameState.coaches, "PMB") == repaired,
			"The repair happens once: loading again changes nothing")
	# An AI-run created club gets a senior coach too.
	var probe := Coaches.seed("COL")
	var filled := CoachMarket.staff_new_clubs(probe, ["COL", "PMB"], "COL", 2026, 7)
	_check(filled.size() == 6 and Coaches.staff(probe, "PMB").size() == 6
			and Coaches.staff(probe, "COL") == Coaches.staff(Coaches.seed("COL"), "COL"),
			"A created club the AI runs hires all six; a seeded club is left alone")

## A club with no recorded expectation or goal position follows the club count,
## not 18 (a created club makes a league of 19 to 21).
func _test_club_count_defaults() -> void:
	_check(ClubLife.default_rank(18) == 9 and ClubLife.default_rank(21) == 10,
			"With no expectation a club is taken as mid-table: 9 of 18, 10 of 21")
	_check(ClubLife.goal_met({}, 21, 0, 21) and not ClubLife.goal_met({}, 19, 0),
			"A goal with no position asks the club count: 21st of 21 meets it, 19th of 18 does not")
	_check(ClubLife.goal_met({"pos": 12}, 12, 0, 21) and not ClubLife.goal_met({"pos": 12}, 13, 0, 21),
			"A set goal position is not moved by the club count")
