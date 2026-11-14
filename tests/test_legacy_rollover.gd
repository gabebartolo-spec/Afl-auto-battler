extends RefCounted
## A Legacy career's rollovers (TODO row 142, phase L8; LegacyRollover): a
## seeded 1990 career, coached at Fitzroy, drafts the real 1990 class in the
## open draft, rolls into 1991 with 15 clubs and Adelaide on a list built by
## the expansion rules, and on across 1995
## (Fremantle), 1996-97 (the merger talks, the Brisbane Lions, Port Adelaide),
## 2011 (Gold Coast) and 2012 (GWS). A 2026 career never meets any of it.
## Run through tests/run_legacy_rollover_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 1990


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_t("_test_2026_unchanged")
	_t("_test_class_rows")
	_t("_test_fitzroy_odds")
	_t("_test_fitzroy_stays")
	_t("_test_departed_club_picks")
	_t("_test_fitzroy_draft")
	_t("_test_seventeen_clubs")
	_t("_test_brand_choice", [0])
	_t("_test_brand_choice", [1])
	_t("_test_brand_sim_bears")
	_t("_test_colours_apart")
	_t("_test_new_club_from_the_save")
	_t("_test_concessions_by_entry")
	_t("_test_canon_move", ["ablett_gcs", "rival"])
	_t("_test_canon_move", ["ablett_gcs", "let_go"])
	_t("_test_canon_move", ["ablett_gcs", "fight"])
	_t("_test_canon_move", ["franklin_syd", "rival"])
	_t("_test_canon_move", ["franklin_syd", "fight"])
	_t("_test_canon_move", ["merrett_flag", "rival"])
	_t("_test_canon_move", ["scully_gws", "let_go"])
	_t("_test_canon_chain")
	_t("_test_canon_retire", ["rioli_home", "rival"])
	_t("_test_canon_retire", ["rioli_home", "let_go"])
	_t("_test_canon_retire", ["jurrah_home", "fight"])
	_t("_test_campaign")
	GameState.replay_seed = 0
	GameDB.reload()
	print(Ran.line("Legacy rollover", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## A 2026 career: generated classes, no real lists, nothing recorded.
func _test_2026_unchanged() -> void:
	GameDB.reload()
	GameState.reset()
	GameState.start_season("MEL", GameDB.club_list("MEL"))
	_check(not LegacyRollover.on() and not LegacyRollover.has_class(2026) and not LegacyRollover.has_foundation("ADE", 1991),
			"A 2026 career has no real classes or foundations")
	var real := GameState.draftee_pool.filter(func(p): return str(p.get("id", "")).begins_with("R"))
	_check(real.is_empty() and not GameState.draftee_pool.is_empty(), "A 2026 career's first class is generated")
	_skip_season()
	_check(GameState.start_next_season(), "A 2026 career rolls over")
	_check(GameState.legacy.is_empty() and not GameState._save_state().has("legacy"),
			"A 2026 career records nothing for Legacy and saves no key for it")


## The real classes: each year's class, ranked without gaps, a real name each.
func _test_class_rows() -> void:
	GameDB.reload("1990")
	for year in [1990, 1996, 2010, 2025, 2026]:
		_check(LegacyRollover.has_class(year), "%d has a real class" % year)
	var cls := LegacyRollover.real_class(1990)
	_check(cls.size() >= 50, "The 1990 class is the National and Rookie drafts (%d)" % cls.size())
	var ranks_ok := true
	var named := true
	for i in range(cls.size()):
		var p: Dictionary = cls[i]
		ranks_ok = ranks_ok and int(p["draft_rank"]) == i + 1 and str(p["id"]) == "R1990_%03d" % (i + 1)
		named = named and str(p["real_name"]).strip_edges() != "" and str(p["generic_name"]) != ""
	_check(ranks_ok and named, "Every 1990 prospect has his class rank, a stable id and a real name")
	var hooper := cls.filter(func(p): return str(p["real_name"]) == "Stephen Hooper")
	_check(hooper.size() == 1 and int(hooper[0]["draft_rank"]) == 1, "Stephen Hooper is the first of the 1990 class")
	var aged := Prospects.age_pool(cls.duplicate(true), 1990, {})
	_check(aged.size() == cls.size(), "No real 1990 draftee is too old for his own draft (%d of %d)" % [aged.size(), cls.size()])
	var peaked := cls.filter(func(p): return int(p.get("real_peak", 0)) > 0)
	_check(not peaked.is_empty() and peaked.all(func(p): return int(p["potential"]) >= int(p["overall"])),
			"A draftee with a real best season has his ceiling from it (%d)" % peaked.size())


## The talks give the odds for each of Fitzroy's records.
func _test_fitzroy_odds() -> void:
	GameState.reset("1990")
	GameState.legacy = {"finals": {"1994": ["FIT"], "1995": ["FIT"]}}
	var both := LegacyRollover.talks_line(GameState)
	_check("90% they play on, 10% they merge" in both, "Finals in 1994 and 1995: 90%% they play on (%s)" % both)
	GameState.legacy = {"finals": {"1995": ["FIT"]}}
	var one := LegacyRollover.talks_line(GameState)
	_check("finals in 1995 only" in one and "(100%)" in one, "Finals in 1995 only: finals in 1996 or merge (%s)" % one)
	GameState.legacy = {"finals": {}}
	var none := LegacyRollover.talks_line(GameState)
	_check("no way out" in none and "(100%)" in none, "No finals: the merger goes ahead (%s)" % none)


## A pick traded to Fitzroy for a year after its last season goes back to
## the club it came from: the draft never seats a club that left (a 1990
## career's 1997 draft threw "Invalid access to key 'FIT'").
func _test_departed_club_picks() -> void:
	GameState.reset("1990")
	GameState.pick_owner = {"1997:1:CAR": "FIT", "1997:2:GEE": "ESS"}
	var owners := GameState.draft_pick_owners(1997)
	_check(not owners.has("1:CAR"), "Fitzroy's 1997 pick goes back to Carlton (%s)" % str(owners))
	_check(str(owners.get("2:GEE", "")) == "ESS", "A pick held by a club still playing stays held (%s)" % str(owners))
	GameState.pick_owner = {}


## Coaching a rival, the merger is settled as the 1996 off-season opens: the
## Lions take Fitzroy's best eight and the rest go into the 1996 National
## Draft, as in real life (Legacy lead, 2026-11-13). Fitzroy has no seat and
## no pick there, and a leftover nobody drafts who would age out of the pool
## ends his career on the record, never silently.
func _test_fitzroy_draft() -> void:
	GameState.reset("1990")
	GameState.start_season("HAW", GameDB.club_list("HAW"))
	GameState.season_year = 1996
	GameState.legacy = {"finals": {"1994": [], "1995": [], "1996": []}}
	GameState.pick_owner = {"1996:1:CAR": "FIT"}
	# The off-season works on league_lists (open_offseason fills it).
	GameState._ensure_league_lists()
	var fit: Array = (GameState.league_lists.get("FIT", []) as Array).duplicate()
	var lions_before: int = (GameState.league_lists["BRL"] as Array).size()
	var pool_before := GameState.draftee_pool.size()
	_check(fit.size() > LegacyRollover.LIONS_TAKE, "(setup) Fitzroy has a list (%d)" % fit.size())
	LegacyRollover.settle_merger(GameState)
	_check(str(GameState.legacy.get("fitzroy", "")) == "merged", "Out of the finals, Fitzroy merge (%s)" % str(GameState.legacy.get("fitzroy", "")))
	_check(not GameState.league_lists.has("FIT") and not GameState.season.lists.has("FIT"), "Fitzroy's list is gone before anyone re-signs")
	_check((GameState.league_lists["BRL"] as Array).size() == lions_before + LegacyRollover.LIONS_TAKE,
			"The Lions take Fitzroy's best %d (%d -> %d)" % [LegacyRollover.LIONS_TAKE, lions_before, (GameState.league_lists["BRL"] as Array).size()])
	var left := GameState.draftee_pool.filter(func(q): return bool(q.get("fitzroy_left", false)))
	_check(left.size() == fit.size() - LegacyRollover.LIONS_TAKE and GameState.draftee_pool.size() == pool_before + left.size(),
			"The other %d go into the draft pool (%d)" % [fit.size() - LegacyRollover.LIONS_TAKE, left.size()])
	_check(left.all(func(q): return int(q.get("draft_year", 0)) == 1996 and str(q.get("club", "x")) == ""),
			"...in the 1996 National Draft, on no club")
	_check(not GameState.intake_order().has("FIT") and GameState.intake_order().size() == GameDB.active_clubs(1996).size() - 1,
			"Fitzroy has no seat at the 1996 draft (%s)" % str(GameState.intake_order()))
	_check(not GameState.draft_pick_owners(1996).has("1:CAR"), "A pick Fitzroy held goes back to its club (%s)" % str(GameState.draft_pick_owners(1996)))
	_check(GameState.news.any(func(n): return "go into the 1996 National Draft" in str(n.get("text", ""))), "The news says where the rest go")
	# Nobody drafted them: the old end their careers, the young stay in the
	# pool, and one who really played on waits for the Rookie Draft first.
	var ahead := left.filter(func(q): return float(q.get("age", 30.0)) + 1.0 >= 22.0 			and LegacyRollover.career_ahead(q, 1996))
	var old := left.filter(func(q): return float(q.get("age", 30.0)) + 1.0 >= 22.0 and not ahead.has(q))
	LegacyRollover._sweep_leftovers(GameState)
	_check(old.all(func(q): return not GameState.draftee_pool.has(q) and GameState.departed_names.has(str(q["id"]))),
			"An undrafted leftover who would age out ends his career on the record (%d)" % old.size())
	_check(GameState.draftee_pool.filter(func(q): return bool(q.get("fitzroy_left", false))).size() == left.size() - old.size(),
			"A young one, or one with a real career ahead, stays in the pool for the drafts")
	_check(ahead.all(func(q): return int(q.get("relisted", 0)) == 1996),
			"One with a real career ahead is relisted for the Rookie Draft (%d)" % ahead.size())
	GameState.relisted_unpicked()
	_check(ahead.all(func(q): return not GameState.draftee_pool.has(q) and GameState.departed_names.has(str(q["id"]))),
			"Passed over in the Rookie Draft too, his career ends on the record")
	GameState.pick_owner = {}


## A Fitzroy that played finals regularly and won the 90% plays on in 1997
## beside the Bears, and a loaded career keeps it so.
func _test_fitzroy_stays() -> void:
	GameState.reset("1990")
	GameState.start_season("HAW", GameDB.club_list("HAW"))
	var seed := -1
	for s in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("fitzroy-merger|%d" % s)
		if rng.randi_range(1, 100) > LegacyRollover.MERGE_ANYWAY_PCT:
			seed = s
			break
	GameState.career_seed = seed
	GameState.legacy = {"finals": {"1994": ["FIT"], "1995": ["FIT"], "1996": []}}
	LegacyRollover.before_moves(GameState, 1997)
	_check(str(GameState.legacy.get("fitzroy", "")) == "stays", "Fitzroy, regular finalists, win the 90% and play on")
	_check(GameDB.active_clubs(1997).has("FIT") and GameDB.active_clubs(1997).has("BRL"),
			"Fitzroy and Brisbane both play in 1997")
	GameDB.apply_era(1997)
	_check(GameDB.club_short("BRL") == "Bears", "Without the merger the Bears stay the Bears (%s)" % GameDB.club_short("BRL"))
	_check(GameState.news.any(func(n): return "fought off the merger" in str(n.get("text", ""))), "The news says Fitzroy play on")
	var saved: Dictionary = GameState.legacy.duplicate(true)
	GameDB.reload("1990")
	_check(not GameDB.active_clubs(1997).has("FIT"), "A reload puts the data's Fitzroy back")
	GameState.legacy = saved
	LegacyRollover.restore(GameState)
	GameDB.apply_era(1997)
	_check(GameDB.active_clubs(1997).has("FIT") and GameDB.club_short("BRL") == "Bears",
			"A loaded career keeps Fitzroy and the Bears")


## "bears coaches should be given the choice to rebrand to lions or stay as
## bears" (director, 2026-11-13). Fitzroy play on and you coach the Bears: one
## card, asked once, and either answer holds through a save. Only the look
## changes: the list and every rating stay as they were.
func _test_brand_choice(choice: int) -> void:
	GameState.reset("1990")
	GameState.start_season("BRL", GameDB.club_list("BRL"))
	GameState.legacy = {"fitzroy": "stays"}
	LegacyRollover.keep_fitzroy()
	GameDB.apply_era(1997)
	GameState.week_events = []
	LegacyRollover.week(GameState)
	_check(GameState.week_events.size() == 1 and str(GameState.week_events[0].get("tid", "")) == LegacyRollover.BRAND_TID,
			"The Bears' coach gets the Bears-or-Lions card (%d cards)" % GameState.week_events.size())
	if GameState.week_events.is_empty():
		return
	var card: Dictionary = GameState.week_events[0]
	_check((card["options"] as Array).all(func(o): return (o.get("effects", []) as Array).is_empty())
			and "never how the side plays" in str(card.get("text", "")),
			"The card says it changes the look only, and carries no effect on play")
	var before := _list_sum(GameState.my_list)
	GameState.resolve_card(0, choice)
	GameDB.apply_era(1997)
	var want := "Lions" if choice == 0 else "Bears"
	_check(GameDB.club_short("BRL") == want, "Answer %d: the club is the %s (%s)" % [choice, want, GameDB.club_short("BRL")])
	if choice == 0:
		_check(GameDB.club_colours("BRL")[1].b > 0.4, "The Lions wear blue (%s)" % str(GameDB.club_colours("BRL")))
	_check(_list_sum(GameState.my_list) == before, "The answer changes no player (%s, %s)" % [str(before), str(_list_sum(GameState.my_list))])
	_check(LegacyRollover.kit_gap() >= PitchView.DISC_CLASH,
			"Fitzroy and the %s look apart on the ground (gap %.1f)" % [want, LegacyRollover.kit_gap()])
	GameState.week_events = []
	LegacyRollover.week(GameState)
	_check(GameState.week_events.is_empty(), "The card comes once")
	var saved: Dictionary = GameState.legacy.duplicate(true)
	GameDB.reload("1990")
	GameState.legacy = saved
	LegacyRollover.restore(GameState)
	GameDB.apply_era(1997)
	_check(GameDB.club_short("BRL") == want and GameDB.active_clubs(1997).has("FIT"),
			"A loaded career keeps the %s beside Fitzroy (%s)" % [want, GameDB.club_short("BRL")])
	GameDB.reload("1990")


## A Bears side the sim runs stays the Bears: no card for a coach elsewhere.
func _test_brand_sim_bears() -> void:
	GameState.reset("1990")
	GameState.start_season("HAW", GameDB.club_list("HAW"))
	GameState.legacy = {"fitzroy": "stays"}
	LegacyRollover.keep_fitzroy()
	GameState.week_events = []
	LegacyRollover.week(GameState)
	GameDB.apply_era(1997)
	_check(GameState.week_events.is_empty() and GameDB.club_short("BRL") == "Bears",
			"Hawthorn's coach gets no card and the sim's Bears stay the Bears")
	GameDB.reload("1990")


## "if the lions/bears and fitzroy guernseys clash you can slightly change the
## colours of each" (director, 2026-11-13): checked with the match's own clash
## test, each reshaded a little (hue kept), never past SHADE_MAX.
func _test_colours_apart() -> void:
	for lions in [false, true]:
		GameState.reset("1990")
		GameDB.apply_era(1997)
		if lions:
			GameDB.unpin_era("BRL")
		GameDB.keep_club("FIT")
		if not lions:
			GameDB.pin_era("BRL", 1996)
		var raw_fit := GameDB.club_colours("FIT")
		var raw_bri := GameDB.club_colours("BRL")
		var raw_gap := LegacyRollover.kit_gap()
		LegacyRollover.separate_colours()
		var gap := LegacyRollover.kit_gap()
		var name := "Lions" if lions else "Bears"
		_check(gap >= PitchView.DISC_CLASH, "Fitzroy v the %s: no clash after (gap %.1f, was %.1f)" % [name, gap, raw_gap])
		var fit := GameDB.club_colours("FIT")
		var bri := GameDB.club_colours("BRL")
		var most := 0.0
		for i in range(3):
			most = maxf(most, maxf(absf(fit[i].v - raw_fit[i].v), absf(bri[i].v - raw_bri[i].v)))
			_check(absf(fit[i].h - raw_fit[i].h) < 0.01 or raw_fit[i].s < 0.05, "Fitzroy colour %d keeps its hue" % i)
			_check(absf(bri[i].h - raw_bri[i].h) < 0.01 or raw_bri[i].s < 0.05, "The %s colour %d keeps its hue" % [name, i])
		_check(most <= LegacyRollover.SHADE_MAX + 0.001, "A slight reshade only (%.2f)" % most)
		if raw_gap >= PitchView.DISC_CLASH:
			_check(most == 0.0, "No clash, no reshade (%s)" % name)
		print("Fitzroy v %s: gap %.1f -> %.1f, reshade %.2f" % [name, raw_gap, gap, most])
	GameDB.reload("1990")


func _list_sum(list: Array) -> Array:
	var ovr := 0
	for p in list:
		ovr += int(p.get("overall", 0))
	return [list.size(), ovr]


## A career whose Fitzroy fought off the merger has 17 clubs in 1997 (Port
## enter, the Bears carry on: director 2026-11-13). 1997's 22 rounds cannot
## hold 22 games each for 17 (187 matches, 176 places), so the season adds
## rounds (director: "Add rounds"): 24 rounds, 22 games each, two byes each,
## every club meets every other, and the final eight plays out to a premier.
func _test_seventeen_clubs() -> void:
	GameState.reset("1990")
	LegacyRollover.keep_fitzroy()
	var codes: Array = GameDB.active_clubs(1997)
	_check(codes.size() == 17 and codes.has("FIT") and codes.has("BRL") and codes.has("PAD"),
			"Fitzroy, the Bears and Port make 17 clubs in 1997 (%d)" % codes.size())
	# Lists: the 1990 clubs' own, and the new clubs borrow one each (only the
	# fixture and the finals are under test here).
	var lists := {}
	var donors: Array = GameDB.active_clubs(1990)
	for i in range(codes.size()):
		var c: String = codes[i]
		var src: String = c if donors.has(c) else str(donors[i % donors.size()])
		lists[c] = GameState._career_copies(GameDB.club_list(src))
	var season := Season.new(codes, lists, 1997, 1997)
	_check(season.fixture.size() == season.regular_rounds() and season.regular_rounds() == 24,
			"1997 with 17 clubs runs to 24 rounds (%d)" % season.fixture.size())
	_check(season.games_per_club() == 22, "Each of the 17 plays the year's 22 games (%d)" % season.games_per_club())
	var real_1997 := Season.new(GameDB.active_clubs(1997).filter(func(c): return c != "FIT"), lists, 1997, 1997)
	_check(real_1997.regular_rounds() == 22 and real_1997.games_per_club() == 22,
			"The real 16-club 1997 keeps 22 rounds and 22 games (%d, %d)" % [real_1997.regular_rounds(), real_1997.games_per_club()])
	var games := {}
	var pairs := {}
	var byes := {}
	var twice_in_a_round := 0
	for ri in range(season.fixture.size()):
		var seen := {}
		for m in season.fixture[ri]:
			for c in [str(m["home"]), str(m["away"])]:
				if seen.has(c):
					twice_in_a_round += 1
				seen[c] = true
				games[c] = int(games.get(c, 0)) + 1
			var a := str(m["home"])
			var b := str(m["away"])
			pairs[a + "|" + b if a < b else b + "|" + a] = true
		for c in codes:
			if not seen.has(c):
				byes[c] = int(byes.get(c, 0)) + 1
	_check(twice_in_a_round == 0, "No club plays twice in a round (%d)" % twice_in_a_round)
	_check(codes.all(func(c): return int(games.get(c, 0)) == 22), "Every club plays 22 games (%s)" % str(games))
	_check(pairs.size() == 17 * 16 / 2, "Every club meets every other (%d of 136 pairs)" % pairs.size())
	_check(codes.all(func(c): return int(byes.get(c, 0)) == 2), "Every club has two byes (%s)" % str(byes))
	var guard := 0
	while not season.is_regular_done() and guard < 40:
		season.play_round()
		guard += 1
	season.start_finals()
	while not season.is_season_over() and guard < 60:
		season.play_finals_week()
		guard += 1
	_check(season.is_season_over() and (season.finals["top"] as Array).size() == 8 and str(season.finals["premier"]) != "",
			"The 17-club 1997 season plays its final eight to a premier (%s)" % str(season.finals.get("premier", "")))
	GameDB.reload("1990")


## The campaign: 1990 to 2012 at Fitzroy, then Brisbane.
func _test_campaign() -> void:
	GameState.reset("1990")
	GameState.start_season("FIT", GameDB.club_list("FIT"))
	var real_1990 := GameState.draftee_pool.filter(func(p): return str(p.get("id", "")).begins_with("R1990_"))
	_check(real_1990.size() == LegacyRollover.real_class(1990).size(),
			"The 1990 career's draft pool is the real 1990 class (%d)" % real_1990.size())
	# 1991 is before the expansion concessions (from Gold Coast, 2011):
	# Adelaide enters on a state-league list and approaches nobody.
	_check(ExpansionBuild.entering(GameState) == ["ADE"] and ExpansionBuild.building(GameState).is_empty(),
			"Adelaide enters for 1991 without the expansion package (entering %s, building %s)" % [
			str(ExpansionBuild.entering(GameState)), str(ExpansionBuild.building(GameState))])
	# 1990 -> 1991: the clubs draft the real class.
	_skip_season()
	var offered := {}
	_check(_draft_year(offered), "The 1990 intake draft runs and the season rolls over")
	_check(GameState.season_year == 1991 and GameDB.active_clubs(1991).size() == 15,
			"1991 has 15 clubs (%d in %d)" % [GameDB.active_clubs(GameState.season_year).size(), GameState.season_year])
	var drafted := 0
	for code in GameState.league_lists:
		for p in GameState.league_lists[code]:
			if str(p.get("id", "")).begins_with("R1990_"):
				drafted += 1
	_check(drafted >= 30, "The clubs took the real 1990 class (%d listed)" % drafted)
	_entered("ADE", 1991, offered)
	_no_package("ADE", 1991)
	# "there must be 0 missing players" (director, 2026-11-13): every real
	# player of each class reaches the game, in his own year's draft. Who
	# takes him is the save's (director, 2026-11-13: "its not possible unless
	# we rig every draft? its an absurd thing").
	_check(_not_offered(offered, 1990).is_empty(), "Every player of the real 1990 class is in the 1990 draft (missing: %s)" % str(_not_offered(offered, 1990)))
	# On to 2012.
	var lions_checked := false
	while GameState.season_year < 2012:
		var year := GameState.season_year
		_skip_season()
		if not _draft_year(offered):
			_check(false, "%d's draft runs and the season rolls over" % year)
			return
		var now := GameState.season_year
		var missing := _not_offered(offered, year)
		var twice := _twice()
		_check(twice.is_empty(), "No real man is in the %d save twice (%s)" % [now, str(twice.slice(0, 6))])
		_check(missing.is_empty(), "Every player of the real %d class is in the %d draft (%d missing: %s)" % [year, year, missing.size(), str(missing.slice(0, 8).map(func(n): return "%s (%s)" % [n, _where(n)]))])
		if now == 1996:
			_check(GameState.news.any(func(n): return "merger talks" in str(n.get("text", ""))),
					"The merger talks open before 1996")
		if now == 1995 or now == 1997 or now == 2011 or now == 2012:
			var code: String = {1995: "FRE", 1997: "PAD", 2011: "GCS", 2012: "GWS"}[now]
			_entered(code, now, offered)
			if now < 2011:
				_no_package(code, now)
			else:
				_package(code, now)
		if now == 1997:
			lions_checked = true
			_check(str(GameState.legacy.get("fitzroy", "")) == "merged", "Fitzroy, out of the finals, merge (%s)" % str(GameState.legacy))
			_check(not GameDB.active_clubs(1997).has("FIT") and GameDB.active_clubs(1997).size() == 16,
					"1997 has 16 clubs and no Fitzroy (%d)" % GameDB.active_clubs(1997).size())
			_check(GameDB.club_short("BRL") == "Lions", "The Bears are the Brisbane Lions (%s)" % GameDB.club_short("BRL"))
			var left: Array = GameState.league_lists.get("FIT", [])
			_check(left.is_empty(), "Fitzroy's list is empty (%d: %s)" % [left.size(),
					str(left.slice(0, 3).map(func(p): return [p.get("id"), p.get("joined"), p.get("club"), p.get("released_by")]))])
			var lions: Array = GameState.league_lists["BRL"]
			var from_fitzroy := lions.filter(func(p): return int(p.get("joined", 0)) == 1997 and not str(p.get("id", "")).begins_with("E"))
			_check(from_fitzroy.size() >= 1 and from_fitzroy.size() <= LegacyRollover.LIONS_TAKE,
					"The Lions take Fitzroy's best (%d)" % from_fitzroy.size())
			_check(GameState.my_club == "BRL", "Fitzroy's coach goes to the Brisbane Lions (%s)" % GameState.my_club)
			var stray := 0
			for cid in GameState.coaches:
				var c: Dictionary = GameState.coaches[cid]
				if str(c.get("status", "")) == "club" and str(c.get("club", "")) == "FIT":
					stray += 1
			_check(stray == 0, "No coach is left at Fitzroy (%d)" % stray)
			_check(GameState.news.any(func(n): return "have merged" in str(n.get("text", ""))), "The news tells of the merger")
			var real_1996 := 0
			for code in GameState.league_lists:
				for p in GameState.league_lists[code]:
					if str(p.get("id", "")).begins_with("R"):
						real_1996 += 1
			_check(real_1996 > 0, "Real draftees are on the lists")
	_check(lions_checked and GameState.season_year == 2012 and GameDB.active_clubs(2012).size() == 18,
			"2012 has 18 clubs (%d)" % GameDB.active_clubs(GameState.season_year).size())
	var loaded := GameState._save_state()
	_check(loaded.has("legacy") and (loaded["legacy"] as Dictionary).has("finals"), "The save keeps the Legacy record")


## Notes every real class player (id R<year>_) now on a list.
func _draft_year(offered: Dictionary) -> bool:
	if not GameState.begin_intake_draft():
		return false
	var d: Draft = GameState.draft
	for p in d.pool:
		offered[str(p.get("id", ""))] = true
		offered[str(p.get("real_name", ""))] = true
		offered[_person(p)] = true
	# A man the save already has on a list is that man, not a second
	# prospect (a new club's state-league signing later drafted in real
	# life, Maverick Weller): he is in the game, and drafted only if delisted.
	for code in GameState.league_lists:
		for p in GameState.league_lists[code]:
			offered[_person(p)] = true
	var listed := 0
	while d != null and not d.is_finished():
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()
	var year := GameState.season_year
	var ok := GameState.finish_intake_draft()
	for code in GameState.league_lists:
		for p in GameState.league_lists[code]:
			if str(p.get("id", "")).begins_with("R%d_" % year):
				listed += 1
				# A father-son pick is matched before the open pool is drawn.
				offered[str(p.get("id", ""))] = true
	print("  %d class: %d of %d listed by the save's clubs" % [year, listed, LegacyRollover.real_class(year).size()])
	return ok


## The real class of `year` that was not in its own draft, by name.
func _not_offered(offered: Dictionary, year: int) -> Array:
	return LegacyRollover.real_class(year).filter(func(p): return not offered.has(str(p["id"])) and not offered.has(_person(p))) 			.map(func(p): return str(p["real_name"]))


## A real man by name and date of birth, whatever id the save gives him.
func _person(p: Dictionary) -> String:
	return "%s|%s" % [str(p.get("real_name", "")), str(p.get("dob", ""))]


## Real men the save holds twice (director, 2026-11-14: "duplicate players
## are absolutely not acceptable"): same name and date of birth on the lists,
## among the free agents or in the draft pool.
func _twice() -> Array:
	var seen := {}
	var out := []
	var arrs: Array = GameState.league_lists.values()
	arrs.append(GameState.free_agents)
	arrs.append(GameState.draftee_pool.filter(func(p): return not GameState.drafted_draftees.has(str(p.get("id", "")))))
	for arr in arrs:
		for p in arr:
			var dob := str(p.get("dob", ""))
			if str(p.get("real_name", "")) == "" or dob.length() < 10:
				continue
			var k := "%s|%s" % [str(p["real_name"]), dob]
			if seen.has(k) and seen[k] != str(p.get("id", "")):
				out.append("%s (%s, %s)" % [k, seen[k], str(p.get("id", ""))])
			seen[k] = str(p.get("id", ""))
	return out


## Where the save has a real man now, for a failure message: his list, the
## free agents, the draft pool, or his career's end.
func _where(real_name: String) -> String:
	var at := []
	for code in GameState.league_lists:
		for p in GameState.league_lists[code]:
			if str(p.get("real_name", "")) == real_name:
				at.append("%s list, %s" % [code, str(p.get("id", ""))])
	for p in GameState.free_agents:
		if str(p.get("real_name", "")) == real_name:
			at.append("free agent, %s" % str(p.get("id", "")))
	for p in GameState.draftee_pool:
		if str(p.get("real_name", "")) == real_name:
			at.append("pool, %s, draft_year %s%s" % [str(p.get("id", "")), str(p.get("draft_year", "")),
					", drafted" if GameState.drafted_draftees.has(str(p.get("id", ""))) else ""])
	for id in GameState.departed_names:
		var card: Dictionary = GameState.departed_names[id]
		if "%s %s" % [str(card.get("first", "")), str(card.get("last", ""))] == real_name or str(card.get("real_name", "")) == real_name:
			at.append("gone %s in %s from %s" % [str(id), str(card.get("year", "")), str(card.get("club", ""))])
	return "; ".join(at) if not at.is_empty() else "nowhere"


## `code` enters `year` on a list built by the expansion rules, from the
## save: no player the save had elsewhere joins it because he really did
## (director, 2026-11-13). Its real state-league players are all in the game.
func _entered(code: String, year: int, offered: Dictionary) -> void:
	var list: Array = GameState.league_lists.get(code, [])
	_check(GameDB.active_clubs(year).has(code), "%s plays in %d" % [code, year])
	_check(list.size() >= 30 and list.all(func(p): return str(p.get("club", code)) == code),
			"%s enter %d on a full list (%d)" % [code, year, list.size()])
	var rated := list.filter(func(p): return int(p.get("overall", 0)) > 30)
	_check(rated.size() == list.size(), "Every %s player is rated" % code)
	var everywhere := {}
	for c in GameState.league_lists:
		for p in GameState.league_lists[c]:
			everywhere[str(p.get("real_name", ""))] = true
	for p in GameState.draftee_pool:
		everywhere[str(p.get("real_name", ""))] = true
	for k in offered:
		everywhere[k] = true
	var lost := []
	for r in GameDB._read_dicts(LegacyRollover.ENTRY_CSV):
		if str(r["club"]) == code and int(r["year"]) == year:
			var nm := "%s %s" % [str(r["first"]), str(r["last"])]
			if not everywhere.has(nm):
				lost.append(nm)
	_check(lost.is_empty(), "%s's real state-league players are all on a list or in the draft (lost: %s)" % [code, ", ".join(lost.map(func(n): return "%s (%s)" % [n, _where(n)]))])
	_check(GameState.news.any(func(n): return "from the state leagues" in str(n.get("text", "")) and GameDB.club_name(code) in str(n.get("text", ""))),
			"The news tells of %s's entry" % code)


## Entered before the expansion concessions: nobody approached, no rival lost
## a player to it, no compensation or traded pick, no sign-on money, and a
## list inside the season's limits built from the state leagues.
func _no_package(code: String, year: int) -> void:
	var st: Dictionary = GameState.expansion.get(code, {})
	_check(not ExpansionBuild.has_package(GameState, code) and (st.get("targets", []) as Array).is_empty()
			and (st.get("signings", []) as Array).is_empty() and (st.get("lost", []) as Array).is_empty()
			and (st.get("traded_picks", []) as Array).is_empty(),
			"%s approach and sign nobody's players and trade no pick before %d (%s)" % [code, year, str(st.keys())])
	var list: Array = GameState.league_lists.get(code, [])
	var from_rivals := list.filter(func(p): return p.has("joined") or str(p.get("released_by", "")) != "")
	_check(from_rivals.is_empty(), "No rival loses a player to %s for %d (%s)" % [code, year, ", ".join(from_rivals.map(func(p):
			return "%s joined %s released_by %s drafted %s" % [str(p.get("real_name", p["id"])), str(p.get("joined", "-")),
					str(p.get("released_by", "-")), str(p.get("drafted_year", "-"))]))])
	var comp := GameState.news.filter(func(n): return "compensation" in str(n.get("text", "")).to_lower() 			and GameDB.club_name(code) in str(n.get("text", "")))
	_check(comp.is_empty(), "No compensation pick for a player lost to %s (%s)" % [code, str(comp.slice(0, 1))])
	_check(list.size() <= EraRules.list_max(year) and list.size() >= EraRules.list_min(year)
			and RookieList.senior_count(list) <= EraRules.senior_spots(year),
			"%s field a legal %d list (%d; %d to %d)" % [code, year, list.size(), EraRules.list_min(year), EraRules.list_max(year)])
	_check(ExpansionBuild.relief(GameState, code) == 0, "%s have no sign-on money in %d" % [code, year])


## Entered with the expansion concessions (2011 on): it approached rivals'
## out-of-contract players and held its extra picks.
func _package(code: String, year: int) -> void:
	var st: Dictionary = GameState.expansion.get(code, {})
	_check(ExpansionBuild.has_package(GameState, code) and not (st.get("targets", []) as Array).is_empty()
			and not (st.get("traded_picks", []) as Array).is_empty(),
			"%s enter %d with the expansion package (%d approaches, picks traded %s)" % [code, year,
			(st.get("targets", []) as Array).size(), str(st.get("traded_picks", []))])


## The expansion concessions follow each club's entry season (era_rules.csv).
func _test_concessions_by_entry() -> void:
	GameDB.reload("1990")
	var want := {"ADE": false, "FRE": false, "PAD": false, "GCS": true, "GWS": true}
	for code in want:
		_check(ExpansionBuild.concessions(code) == want[code],
				"%s (entering %d): concessions %s" % [code, GameDB.enter_year(code), str(want[code])])
	var y_of := {}
	for code in ["GCS", "TAS"]:
		y_of[code] = GameDB.enter_year(code)
	GameDB.set_enter_year("GCS", 2010)
	GameDB.set_enter_year("TAS", 2028)
	_check(not ExpansionBuild.concessions("GCS"), "A club entering in 2010 would have no concessions")
	_check(ExpansionBuild.concessions("TAS"), "Tasmania, entering in 2028, has them")
	GameDB.set_enter_year("GCS", int(y_of["GCS"]))
	GameDB.set_enter_year("TAS", int(y_of["TAS"]))
	_check(Expansion.foundation_size("ADE") == EraRules.senior_spots(1991) and Expansion.foundation_size("GCS") == Expansion.FOUNDATION_SIZE,
			"Adelaide sign a whole senior list (%d), Gold Coast %d" % [Expansion.foundation_size("ADE"), Expansion.FOUNDATION_SIZE])
	GameDB.reload("1990")


func _skip_season() -> void:
	GameState.season.round_index = GameState.season.fixture.size()


## start_season fills season.lists; a real career's league_lists is the same
## arrays (begin_real_lists), which the canon stories search.
func _start(code: String) -> void:
	GameState.start_season(code, GameDB.club_list(code))
	for c in GameState.season.lists:
		GameState.league_lists[c] = GameState.season.lists[c]


## "the sim will not replicate historical draftee clubs" (director,
## 2026-11-13): a new club's foundation is only its real state-league players
## no class brings in; nobody on a list moves to it. Adelaide, entering before
## the expansion concessions, signs a whole 1991 senior list: every real one
## and state-league signings for the rest.
func _test_new_club_from_the_save() -> void:
	GameState.reset("1990")
	_start("GEE")
	var before := 0
	for c in GameState.league_lists:
		before += (GameState.league_lists[c] as Array).size()
	var rows := 0
	for r in GameDB._read_dicts(LegacyRollover.ENTRY_CSV):
		if str(r["club"]) == "ADE" and int(r["year"]) == 1991:
			rows += 1
	var got: Dictionary = LegacyRollover.foundation(GameState, "ADE", 1991)
	var list: Array = got["list"]
	var pool: Array = got["pool"]
	var after := 0
	for c in GameState.league_lists:
		after += (GameState.league_lists[c] as Array).size()
	_check(after == before, "No player leaves a club for Adelaide (%d listed, then %d)" % [before, after])
	var size := EraRules.senior_spots(1991)
	_check(list.size() == size, "Adelaide sign %d from the state leagues (%d)" % [size, list.size()])
	_check(list.size() + pool.size() == maxi(rows, size),
			"Every real one signs or goes into the draft (%d + %d of %d)" % [list.size(), pool.size(), rows])
	var home := list.filter(func(p): return not str(p["id"]).begins_with("FND_ADE_L1991_") and str(p.get("draft_league", "")) != "SANFL")
	_check(home.is_empty(), "Adelaide's other signings come from the SANFL (%d do not)" % home.size())
	_check(list.all(func(p): return str(p["id"]).begins_with("FND_") and str(p["club"]) == "ADE"), "They are Adelaide's state-league signings")
	_check(pool.all(func(p): return str(p["club"]) == "" and int(p["draft_year"]) == 1990), "The rest are in the 1990 draft")
	var low := 99
	for p in list:
		low = mini(low, int(p["overall"]))
	_check(pool.all(func(p): return int(p["overall"]) <= low), "Adelaide sign the best of them")
	GameDB.reload("1990")


## Puts the canon story's player on `from`'s list; returns him.
func _plant(m: Dictionary, from: String) -> Dictionary:
	var star: Dictionary = (GameState.league_lists[from] as Array)[0]
	star["real_name"] = "%s %s" % [str(m["first"]), str(m["last"])]
	star["dob"] = str(m["dob"])
	return star


## Round CANON_ROUND of the season before the story's year: his coach's cards.
func _canon_cards(m: Dictionary) -> Array:
	GameState.season_year = int(m["year"]) - 1
	GameState.season.round_index = LegacyRollover.CANON_ROUND
	GameState.week_events = []
	LegacyRollover.week(GameState)
	return GameState.week_events.filter(func(e): return str(e.get("tid", "")) == LegacyRollover.CANON_TID)


## A canon move: "His coach, with odds" (director, 2026-11-13). `how`: "rival"
## (he is at a rival club: no card, he goes), "let_go" (your card, you let him
## go) or "fight" (your card, you fight: he stays exactly when the seeded roll
## is within KEEP_PCT). "just have a story no matter where he is": he starts at
## Hawthorn, wherever he really was.
func _test_canon_move(id: String, how: String) -> void:
	var m := LegacyRollover.canon(id)
	var from := "HAW"
	var seen := {}
	for seed in range(1, 40):
		GameState.reset("1990")
		GameState.career_seed = seed
		_start("CAR" if how == "rival" else from)
		var star := _plant(m, from)
		var cards := _canon_cards(m)
		var e: Dictionary = LegacyRollover._canon_st(GameState).get(id, {})
		var to := str(e.get("to", ""))
		_check(to != "" and to != from, "%s: he has somewhere to go (%s)" % [id, to])
		if str(m["to"]) != "":
			_check(to == str(m["to"]), "%s: to the club he really joined" % id)
		else:
			_check(to == str(GameState.season.ladder_sorted()[0]["code"]), "%s: to the ladder's leader" % id)
		if how == "rival":
			_check(cards.is_empty(), "%s: no card when he is at a rival club" % id)
		else:
			_check(cards.size() == 1, "%s: his coach gets the card (%d)" % [id, cards.size()])
			if cards.is_empty():
				return
			var rule := str(cards[0]["options"][0]["rule"])
			_check(("%d%% he stays" % LegacyRollover.KEEP_PCT) in rule and ("%d%% he goes anyway" % (100 - LegacyRollover.KEEP_PCT)) in rule,
					"%s: the gate states the odds (%s)" % [id, rule])
			LegacyRollover.answered(GameState, cards[0], 0 if how == "fight" else 1)
			LegacyRollover.week(GameState)
			_check(GameState.week_events.size() == 1, "%s: the card comes once" % id)
		LegacyRollover.canon_moves(GameState, int(m["year"]))
		var moved := false
		if GameDB.enter_year(to) == int(m["year"]):
			moved = ExpansionBuild.list_of(GameState, to).has(star)
		else:
			moved = (GameState.league_lists.get(to, []) as Array).has(star)
		var at_home := (GameState.league_lists[from] as Array).has(star)
		_check(moved != at_home, "%s: he is at exactly one club (moved %s, home %s)" % [id, moved, at_home])
		if how != "fight":
			_check(moved, "%s (%s): he goes, as he really did" % [id, how])
			break
		var kept := int(e.get("roll", 101)) <= LegacyRollover.KEEP_PCT
		_check(at_home == kept, "%s: fought for, he stays exactly on a roll within %d (roll %d, home %s)" % [
				id, LegacyRollover.KEEP_PCT, int(e.get("roll", -1)), at_home])
		if kept:
			_check(int(star.get("contract_years", 0)) == LegacyRollover.KEEP_YEARS, "%s: kept on %d more seasons" % [id, LegacyRollover.KEEP_YEARS])
		seen[kept] = true
		if seen.size() == 2:
			break
	if how == "fight":
		_check(seen.size() == 2, "%s: over the seeds, fighting both keeps and loses him (%s)" % [id, str(seen.keys())])
	GameDB.reload("1990")


## Grundy's two moves, from wherever the sim has him: Melbourne, then Sydney.
func _test_canon_chain() -> void:
	GameState.reset("1990")
	_start("CAR")
	var star := _plant(LegacyRollover.canon("grundy_mel"), "HAW")
	for id in ["grundy_mel", "grundy_syd"]:
		var m := LegacyRollover.canon(id)
		_canon_cards(m)
		LegacyRollover.canon_moves(GameState, int(m["year"]))
		_check((GameState.league_lists[str(m["to"])] as Array).has(star), "%s: Grundy plays for %s" % [id, str(m["to"])])
	_check(not (GameState.league_lists["HAW"] as Array).has(star) and not (GameState.league_lists["MEL"] as Array).has(star),
			"Grundy is on one list only")
	GameDB.reload("1990")


## An early retirement (Jurrah, Rioli): "either make an early retirement or be
## convinced to play on" (director, 2026-11-13). The rollover retires him
## unless the club talked him round.
func _test_canon_retire(id: String, how: String) -> void:
	var m := LegacyRollover.canon(id)
	var from := "HAW"
	var seen := {}
	for seed in range(1, 40):
		GameState.reset("1990")
		GameState.career_seed = seed
		_start("CAR" if how == "rival" else from)
		var star := _plant(m, from)
		var cards := _canon_cards(m)
		_check(GameState.retiring_now(star), "%s: he is set to retire" % id)
		if how == "rival":
			_check(cards.is_empty(), "%s: no card when he is at a rival club" % id)
			break
		_check(cards.size() == 1, "%s: his coach gets the card (%d)" % [id, cards.size()])
		if cards.is_empty():
			return
		var rule := str(cards[0]["options"][0]["rule"])
		_check(("%d%% he plays on" % LegacyRollover.KEEP_PCT) in rule, "%s: the gate states the odds (%s)" % [id, rule])
		LegacyRollover.answered(GameState, cards[0], 0 if how == "fight" else 1)
		if how != "fight":
			_check(GameState.retiring_now(star), "%s: let go, he retires" % id)
			break
		var e: Dictionary = LegacyRollover._canon_st(GameState).get(id, {})
		var kept := int(e.get("roll", 101)) <= LegacyRollover.KEEP_PCT
		_check(GameState.retiring_now(star) != kept, "%s: talked to, he plays on exactly on a roll within %d (roll %d)" % [
				id, LegacyRollover.KEEP_PCT, int(e.get("roll", -1))])
		LegacyRollover.canon_moves(GameState, int(m["year"]))
		var news := GameState.news.filter(func(n): return str(m["last"]) in str(n.get("text", "")))
		_check(news.size() == 1 and (("playing on" in str(news[0]["text"])) == kept), "%s: the news says what he chose" % id)
		seen[kept] = true
		if seen.size() == 2:
			break
	if how == "fight":
		_check(seen.size() == 2, "%s: over the seeds, talking to him both keeps and loses him (%s)" % [id, str(seen.keys())])
	GameDB.reload("1990")
