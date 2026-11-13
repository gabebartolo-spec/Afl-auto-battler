extends RefCounted
## Legacy mode money (row 142, phase L3; director 2026-11-12, "Dollars of the
## time"): an era season shows salaries, the cap and every money figure in
## its own dollars (data/legacy/era_rules.csv); today's seasons are untouched.
## Run through tests/run_era_money_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 1990


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	GameState.replay_seed = SUITE_SEED
	_t("_test_era_rule_reader")
	_t("_test_era_caps")
	_t("_test_today_is_untouched")
	_t("_test_1990_cap_shows")
	_t("_test_1990_contracts")
	_t("_test_1990_talks_and_budget")
	_t("_test_2027_career_unchanged")
	_t("_test_campaign_rolls_through_the_eras")
	GameState.reset()
	GameDB.reload()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Era money", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## A career whose first season is `year`: 1990 on the real 1990 lists (L1),
## today's years on today's.
## `year` 0 is the default set's own first season (read after the reset: a
## 1990 test before it leaves START_YEAR at 1990).
func _career(year: int, club := "GEE") -> void:
	GameState.reset("1990" if year == 1990 else Datasets.DEFAULT)
	GameState.season_year = year if year > 0 else GameDB.START_YEAR
	GameState.start_season(club, GameDB.club_list(club))


func _scaled(amount: int, cap: int) -> int:
	return int(round(float(amount) * float(cap) / float(Contracts.CAP_2027) / 1000.0)) * 1000


## GameDB.era_rule reads any rule by year; a year the file lacks is the fallback.
func _test_era_rule_reader() -> void:
	_check(GameDB.era_rule("salary_cap", 1990) == 1500000.0, "The 1990 cap is $1.5m")
	_check(GameDB.era_rule("interchange", 1990) == 2.0 and GameDB.era_rule("interchange", 1999) == 4.0,
			"Interchange: 2 in 1990, 4 in 1999 (the reader is general, for L4)")
	_check(GameDB.era_rule("salary_cap", 2031, -1.0) == -1.0, "A year with no row gives the fallback")
	_check(EraRules.span("salary_cap") == [1987, 2025],
			"The cap record runs 1987-2025: %s" % str(EraRules.span("salary_cap")))


## Every season 1990-2025 has a cap of its own; 2026 on is unchanged.
func _test_era_caps() -> void:
	var years := range(1990, 2026)
	_check(years.size() == 36, "36 seasons from 1990 to 2025")
	for y in years:
		_check(EraRules.has("salary_cap", y)
				and Contracts.salary_cap_for_year(y) == int(GameDB.era_rule("salary_cap", y)),
				"%d uses its own cap (%d)" % [y, Contracts.salary_cap_for_year(y)])
	_check(Contracts.salary_cap_for_year(2024) == 15788222 and Contracts.salary_cap_for_year(2025) == 17761999,
			"2024 and 2025 caps from the CBA's Schedule 2A")
	_check(Contracts.salary_cap_for_year(2026) == Contracts.CAP_2027
			and Contracts.salary_cap_for_year(2027) == Contracts.CAP_2027
			and Contracts.salary_cap_for_year(2028) == int(round(float(Contracts.CAP_2027) * Contracts.FUTURE_GROWTH / 1000.0)) * 1000,
			"2026, 2027 and later unchanged")


## Outside the era record every money rule is the identity: nothing moves.
func _test_today_is_untouched() -> void:
	var saved := Contracts.money_year
	for y in [0, 2026, 2027, 2030]:
		Contracts.money_year = y
		_check(Contracts.era_scale(y) == 1.0, "%d scales by exactly 1" % y)
		_check(Contracts.dollars(1234567) == 1234567 and Contracts.senior_min() == Contracts.SENIOR_MIN_2027
				and Contracts.salary_step() == Contracts.SALARY_STEP,
				"%d: dollars, the minimum and the offer step unchanged" % y)
		_check(Contracts.salary_score(525000) == clampf(1.0 + 9.0 * (525000.0 - 155000.0) / (1250000.0 - 155000.0), 1.0, 12.0)
				and Contracts.points_money(1.0) == int(round(Contracts.POINT_DOLLARS / 10000.0)) * 10000,
				"%d: offer weights unchanged" % y)
		_check(ClubBudget.money_m(10.5) == "$10.5m", "%d: the club budget reads $10.5m" % y)
	Contracts.money_year = saved


## A 1990 career: the cap is $1.5m, and the cap line says so.
func _test_1990_cap_shows() -> void:
	_career(1990)
	_check(Contracts.money_year == 1990, "The season sets the money year")
	_check(GameState.salary_cap == 1500000, "The 1990 cap is $1.5m (%d)" % GameState.salary_cap)
	_check(Contracts.money(GameState.salary_cap) == "$1.5m",
			"It shows as $1.5m: %s" % Contracts.money(GameState.salary_cap))


## A 1990 contract is in 1990 dollars: today's model scaled by $1.5m / $18.44m.
func _test_1990_contracts() -> void:
	_career(1990)
	var list: Array = GameState.my_list
	_check(list.size() > 30, "Geelong has a list (%d)" % list.size())
	var bad := []
	for p in list:
		var model := Ratings.salary_value(int(p["overall"]))
		# A player on a real contract carries only its term; payroll counts his
		# worth in the season's dollars (Contracts.payroll).
		var salary := int(p["salary"]) if p.has("salary") else Contracts.payroll([p])
		if int(p["value"]) == model and salary != _scaled(model, 1500000):
			bad.append("%s salary %d" % [str(p["id"]), salary])
		if Contracts.asking_salary(p) < _scaled(model, 1500000):
			bad.append("%s ask %d" % [str(p["id"]), Contracts.asking_salary(p)])
	_check(bad.is_empty(), "Every 1990 contract and asking price is in 1990 dollars: %s" % str(bad.slice(0, 5)))
	var payroll := GameState.my_payroll()
	_check(payroll > 0 and payroll <= int(GameState.salary_cap * 1.2),
			"A 1990 payroll sits near a 1990 cap: %s of %s" % [Contracts.money(payroll), Contracts.money(GameState.salary_cap)])
	var star := {"overall": 99, "age": 25.0}
	_check(Contracts.asking_salary(star) == _scaled(1250000, 1500000),
			"A 1990 star asks %s, not $1.25m" % Contracts.money(Contracts.asking_salary(star)))
	_check(Contracts.senior_min() == 13000 and Contracts.salary_step() == 8000,
			"1990 minimum %s and offer step %s" % [Contracts.money(Contracts.senior_min()), Contracts.money(Contracts.salary_step())])
	var d := {"draft_pick": 1}
	Contracts.draftee_deal(d, 1990)
	_check(int(d["salary"]) == 12000, "A 1990 pick 1 earns %s" % Contracts.money(int(d["salary"])))
	# The CBA's own minimum where the record has one, not a scaled guess.
	_check(Contracts.senior_min(2024) == 130000 and Contracts.senior_min(2025) == 145000,
			"2024 and 2025 minimums are the CBA base payments")


## Offers weigh the same in any era, and the club budget shows in 1990 dollars.
func _test_1990_talks_and_budget() -> void:
	_career(1990)
	var p := {"overall": 75, "age": 26.0}
	var ask := Contracts.asking_salary(p)
	var score_1990 := Contracts.salary_score(ask)
	Contracts.money_year = 2027
	var score_2027 := Contracts.salary_score(Contracts.asking_salary(p))
	Contracts.money_year = 1990
	_check(absf(score_1990 - score_2027) < 0.05,
			"A 1990 offer weighs as its 2027 twin (%.3f vs %.3f)" % [score_1990, score_2027])
	_check(ClubBudget.money_m(10.5) == Contracts.money(Contracts.dollars(10500000)) and ClubBudget.money_m(10.5) != "$10.5m",
			"The club budget shows in 1990 dollars: %s" % ClubBudget.money_m(10.5))
	var lowest := Contracts.lowest(p, 3)
	_check(lowest >= Contracts.senior_min() and lowest <= ask,
			"His lowest (%s) sits between the minimum and his ask (%s)" % [Contracts.money(lowest), Contracts.money(ask)])


## A seeded career in today's years: every contract is today's model.
func _test_2027_career_unchanged() -> void:
	_career(0)
	_check(GameState.season_year == 2027 and Contracts.era_scale(Contracts.money_year) == 1.0, "Today's career scales by 1")
	_check(GameState.salary_cap == Contracts.CAP_2027, "The 2027 cap is $18.44m")
	var bad := []
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if Contracts.asking_salary(p) < Ratings.salary_value(int(p["overall"])):
				bad.append(str(p["id"]))
	_check(bad.is_empty(), "Every 2027 asking price is today's model: %s" % str(bad.slice(0, 5)))


func _to_offseason() -> void:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	while not GameState.season.is_season_over():
		GameState.advance()


## A 1990 start is the first season of a campaign (director 2026-11-13: "its
## simply the start of a 36+ year campaign"). On the real 1990 lists, roll
## season after season into the 2000s: each new season brings its own cap,
## minimum and asking prices, and a contract signed earlier runs on at the
## figure it was signed at. ERA_MONEY_TO=2026 rolls the whole campaign
## (about 13 minutes; the suite stops at 2000, about 4).
func _test_campaign_rolls_through_the_eras() -> void:
	var last := int(OS.get_environment("ERA_MONEY_TO")) if OS.get_environment("ERA_MONEY_TO") != "" else 2000
	GameState.reset("1990")
	_check(GameDB.START_YEAR == 1990, "The real 1990 lists load")
	GameState.season_year = GameDB.START_YEAR
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.season.lists.size() == 14 and GameState.salary_cap == 1500000,
			"1990: fourteen clubs work to a $1.5m cap (%d clubs, %s)"
			% [GameState.season.lists.size(), Contracts.money(GameState.salary_cap)])
	var rolled := 0
	var carried := 0
	var sackings := []
	while GameState.season_year < last:
		var from := GameState.season_year
		# Everyone on a list signed beyond this season, what he is paid and by
		# whom. A contract runs on at the club that signed it; a player a
		# merger releases, a story moves or a club delists and signs again starts a
		# new one (Legacy L8): same club and same join year, or it is a new deal.
		var signed := {}
		var signed_by := {}
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				if p.has("salary") and int(p.get("contract_years", 0)) >= 2:
					signed[str(p["id"])] = int(p["salary"])
					signed_by[str(p["id"])] = "%s|%s" % [code, p.get("joined", "")]
		_to_offseason()
		# Nobody coaches this side, and a board may sack him with no job to go
		# to (that ends a career). The money is under test, not the coach: keep
		# him on and say so.
		if GameState.is_sacked():
			sackings.append(from)
			GameState.board["sacked"] = false
			GameState.board["warned"] = false
		_check(Contracts.money_year == from, "%d's off-season is in %d dollars" % [from, from])
		if not GameState.start_next_season():
			_check(false, "%d rolls into %d" % [from, from + 1])
			break
		var y := GameState.season_year
		rolled += 1
		var cap := Contracts.salary_cap_for_year(y)
		_check(y == from + 1 and Contracts.money_year == y and GameState.salary_cap == cap,
				"%d: the cap is %s and money is in %d dollars" % [y, Contracts.money(GameState.salary_cap), Contracts.money_year])
		if y < 2026:
			_check(EraRules.has("salary_cap", y) and cap == int(GameDB.era_rule("salary_cap", y)),
					"%d has its own cap on record" % y)
			var want_min: int = int(GameDB.era_rule("senior_min", y)) if EraRules.has("senior_min", y) 					else _scaled(Contracts.SENIOR_MIN_2027, cap)
			_check(Contracts.senior_min() == want_min, "%d minimum %s" % [y, Contracts.money(Contracts.senior_min())])
			var star := {"overall": 99, "age": 25.0}
			_check(Contracts.asking_salary(star) == _scaled(1250000, cap),
					"%d: a star asks %s" % [y, Contracts.money(Contracts.asking_salary(star))])
		else:
			_check(cap == Contracts.CAP_2027 and Contracts.era_scale(y) == 1.0
					and Contracts.senior_min() == Contracts.SENIOR_MIN_2027,
					"%d is today's money: cap %s, minimum unchanged" % [y, Contracts.money(cap)])
		var kept := 0
		var moved := []
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				var id := str(p["id"])
				if signed.has(id) and p.has("salary") and str(signed_by[id]) == "%s|%s" % [code, p.get("joined", "")]:
					kept += 1
					if int(p["salary"]) != int(signed[id]):
						moved.append("%s %d->%d" % [id, int(signed[id]), int(p["salary"])])
		carried += kept
		_check(moved.is_empty(), "%d: contracts signed by %d run on at their figure (%d carried): %s"
				% [y, from, kept, str(moved.slice(0, 3))])
		var payroll := GameState.my_payroll()
		var salaried := GameState.my_list.filter(func(q): return q.has("salary")).size()
		print("  %d: cap %s, %s payroll %s (%d listed, %d paid), minimum %s, %d contracts carried"
				% [y, Contracts.money(cap), GameState.my_club, Contracts.money(payroll), GameState.my_list.size(),
				salaried, Contracts.money(Contracts.senior_min()), kept])
		_check(payroll > 0, "%d: a payroll (%s)" % [y, Contracts.money(payroll)])
	print("  boards that sacked the unattended coach (kept on): %s" % str(sackings))
	_check(rolled == last - 1990 and carried > 0,
			"%d seasons rolled from 1990 to %d, %d contracts carried across" % [rolled, last, carried])
	GameState.reset()
	GameDB.reload()
