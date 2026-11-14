extends RefCounted
## Expansion package suite: how a new club builds its list (director's
## ruling, 2026-10-14; Expansion and ExpansionBuild): the club brings
## state-league signings, early draft picks, a senior player for the pick it
## must trade, and out-of-contract players from rival clubs.
## Run through tests/run_expansion_package_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded: a clock seed plays a different league.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_t("_test_premier_picks_last")
	_t("_test_rules")
	_t("_test_canberra_choice")
	_t("_test_draft_seats")
	_t("_test_build_and_entry")
	_t("_test_second_year_and_end")
	_t("_test_your_player_is_approached")
	_t("_test_who_a_rival_keeps")
	_t("_test_save_round_trip")
	_t("_test_old_saves")
	GameState.reset()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Expansion package", self))


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
## A League Draft career, every club drafting as a rival does: lists big
## enough to lose a player (a real 2026 list of players with games is at the
## list minimum, and nobody can leave one).
## The League Draft is the slow part (every club drafts the whole league) and
## no test here is about it: the first career is drafted, saved and kept, and
## every later one is that save restored, as Continue would load it.
func _new_career(club := "GEE") -> void:
	if _drafted.has(club):
		_check(GameState._restore_career((_drafted[club] as Dictionary).duplicate(true)),
				"The drafted %s career restores" % club)
		GameState.replay_seed = SUITE_SEED
		return
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), SUITE_SEED)
	GameState.draft.start_for_user(club)
	_run_plain(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	_check(GameState.save_career(), "The drafted %s career saves" % club)
	_drafted[club] = CareerSave.read(GameState.save_path)


## club -> the saved state of its freshly drafted career (_new_career).
var _drafted := {}


func _run_draft() -> void:
	var draft: Draft = GameState.draft
	var guard := 0
	while not draft.is_finished() and guard < 800:
		guard += 1
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()


## From the last _rollover: the numbers the bottom four clubs' own first-round
## picks were given before the draft (GameState.draft_spot, what a trade
## screen shows), then where those picks really fell.
var _numbered := ""


## The season is treated as played; the off-season and draft run as a career's do.
func _rollover() -> Array:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.open_offseason()
	var order: Array = GameState._draft_order().slice(0, 4)
	var said := PackedStringArray()
	for code in order:
		said.append(str(GameState.draft_spot(GameState.season_year, 1, str(code))))
	if not GameState.begin_intake_draft():
		GameState.start_next_season()
		return []
	var fell := PackedStringArray()
	for code in order:
		fell.append(str(GameState.draft.pick_origin.find(str(code)) + 1))
	_numbered = " ".join(said) + " / " + " ".join(fell)
	_run_draft()
	var history: Array = GameState.draft.pick_history.duplicate()
	GameState.finish_intake_draft()
	return history


## The season ends and a new club's approaches settle, first thing in the
## off-season (GameState.open_offseason: the off-season opens, last season's
## free agents leave the market, then ExpansionBuild.resolve). The rest of the
## off-season (every club's re-signings, trades and free agency) is not under
## test and is the slow part, so it is left out.
func _settle_approaches() -> void:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.offseason_year = GameState.season_year
	GameState.free_agents = []
	ExpansionBuild.resolve(GameState)


func _ids(list: Array) -> Array:
	var out := []
	for p in list:
		out.append(str(p["id"]))
	out.sort()
	return out


func _count_prefix(list: Array, prefix: String) -> int:
	var n := 0
	for p in list:
		if str(p["id"]).begins_with(prefix):
			n += 1
	return n


func _picks_of(history: Array, code: String) -> Array:
	var out := []
	for e in history:
		if str(e["club"]) == code:
			out.append(int(e["pick"]))
	return out


# ---------------------------------------------------------------------------
# The draft order
# ---------------------------------------------------------------------------
func _test_premier_picks_last() -> void:
	_new_career()
	# A pick's number before the draft follows the draft's own order: the
	# premier picks last even from the bottom of the ladder.
	var ladder: Array = GameState.season.ladder_sorted()
	var flag := str(ladder[ladder.size() - 1]["code"])
	var saved_finals: Dictionary = GameState.season.finals
	GameState.season.finals = {"premier": flag, "runner_up": str(ladder[ladder.size() - 2]["code"])}
	var clubs: int = GameState.intake_order().size()
	# A new club's extra picks come first, so the premier's number counts them.
	clubs += ExpansionBuild.picks_ahead(GameState, GameState.season_year, clubs, clubs)
	_check(GameState.draft_spot(GameState.season_year, 1, flag) == clubs
			and GameState._draft_order() == GameState.intake_order(),
			"The premier's first pick is numbered last, as it falls on draft night (%d of %d)" % [
				GameState.draft_spot(GameState.season_year, 1, flag), clubs])
	GameState.season.finals = saved_finals


# ---------------------------------------------------------------------------
# The rules
# ---------------------------------------------------------------------------
func _test_rules() -> void:
	var a: Array = Expansion.foundation_list("TAS", 2027, 11)
	var b: Array = Expansion.foundation_list("TAS", 2027, 12)
	_check(a.size() == Expansion.FOUNDATION_SIZE, "The state-league list has %d players" % Expansion.FOUNDATION_SIZE)
	_check(_ids(a) != _ids(b), "Two careers get different state-league players")
	var same: Array = Expansion.foundation_list("TAS", 2027, 11)
	_check(_ids(a) == _ids(same), "The same career gets the same state-league players")
	var roomy := ""
	var best := 0
	for p in a + b:
		var room := int(p["potential"]) - int(p["overall"])
		best = maxi(best, int(p["potential"]))
		if room < 0 or room > 4:
			roomy += "%s +%d " % [str(p["id"]), room]
	_check(roomy == "", "No state-league signing can improve more than four points (%s)" % roomy)
	_check(best < 80, "No state-league signing has a star's ceiling (best %d)" % best)
	var picks: Array = Expansion.first_draft_picks("TAS", 18, 3)
	var afters := []
	for e in picks:
		afters.append(int(e["after"]))
	_check(afters == [0, 1, 2, 3, 4, 5, 6, 18, 36], "The first draft: picks 1, 3, 5, 7, 9, 11, 13 and the first pick of rounds two and three (%s)" % str(afters))
	var second: Array = Expansion.later_draft_picks("TAS")
	_check(second.size() == 2 and int(second[0]["after"]) == 4 and int(second[1]["after"]) == 7, "The next two drafts: picks 5 and 9")
	var cap := Contracts.indexed_money_2027(Expansion.SIGN_ON_SEASON_MAX, 2028)
	_check(Expansion.sign_on_relief(900000, 2028, 0) == 900000, "Sign-on money never exceeds what the signings are paid")
	_check(Expansion.sign_on_relief(9000000, 2028, 0) == cap, "Sign-on money stops at the season's limit")
	var pool := Contracts.indexed_money_2027(Expansion.SIGN_ON_POOL, 2029)
	_check(Expansion.sign_on_relief(9000000, 2029, cap) == pool - cap, "The second season gets what is left of the pool")
	_check(Expansion.sign_on_relief(9000000, 2029, pool + 1) == 0, "A spent pool gives nothing")
	# The director (2026-11-11): the money steps down over the third and
	# fourth seasons instead of ending at once.
	_check(Expansion.tapered_relief(3000000, 3, 9000000) == 2000000, "The third season keeps two thirds of the second season's sign-on money")
	_check(Expansion.tapered_relief(3000000, 4, 9000000) == 1000000, "The fourth season keeps one third")
	_check(Expansion.tapered_relief(3000000, 5, 9000000) == 0 and Expansion.tapered_relief(3000000, 2, 9000000) == 0,
			"Nothing steps down before the third season or after the fourth")
	_check(Expansion.tapered_relief(3000000, 3, 500000) == 500000, "Stepping down, it still never exceeds what the signings are paid")


func _test_canberra_choice() -> void:
	GameState.reset()
	_check(not GameState.canberra_on, "On: a new career starts without Canberra")
	_check(not GameDB.active_clubs(2030).has("CANB") and not GameDB.active_clubs(2040).has("CANB"),
			"On: Canberra never joins unless the career chose it")
	_check(GameDB.active_clubs(2028).has("TAS"), "On: Tasmania still joins in 2028")
	GameState.set_canberra(true)
	_check(GameDB.active_clubs(2030).has("CANB") and not GameDB.active_clubs(2029).has("CANB"),
			"On: a career that chose Canberra gets it in 2030")
	GameState.reset()
	_check(not GameDB.active_clubs(2030).has("CANB"), "On: the choice does not leak into the next career")


## The draft itself: a club not yet playing has a seat and its extra picks.
func _test_draft_seats() -> void:
	var clubs := GameDB.active_clubs(2027)
	var pool := []
	for i in range(54):
		pool.append({"id": "T%02d" % i, "overall": 70 - i / 2, "potential": 80, "role": ["MID", "DEF", "FWD", "RUCK"][i % 4],
				"role2": "", "age": 18.0, "value": 3, "name": "T%02d" % i, "club": ""})
	var d := Draft.build_intake(pool, clubs.duplicate(), clubs.duplicate(), 7, {}, {}, {})
	d.add_guest("TAS", 30, {"RUCK": 3, "MID": 10, "DEF": 9, "FWD": 8}, [])
	var picks: Array = Expansion.first_draft_picks("TAS", clubs.size(), d.target_size)
	for i in [2, 3, 5, 6]:   # 5, 7, 11 and 13, the picks it must trade, traded
		picks[i]["club"] = str(clubs[5])
	d.add_compensation(picks)
	_check(str(d.pick_sequence[0]) == "TAS" and str(d.pick_sequence[2]) == "TAS" and str(d.pick_sequence[8]) == "TAS",
			"Tasmania holds picks 1, 3 and 9")
	_check(str(d.pick_sequence[1]) == str(clubs[0]) and str(d.pick_sequence[3]) == str(clubs[1]),
			"The club that would have picked first picks second, the next picks fourth")
	_check(str(d.pick_sequence[6]) == str(clubs[5]) and str(d.pick_origin[6]) == "TAS",
			"A traded pick is pick 7, held by the club that traded for it")
	_check(str(d.pick_sequence[clubs.size() + 7]) == "TAS" and int(d.pick_rounds[clubs.size() + 7]) == 2,
			"Tasmania holds the first pick of round two")
	_check(d.pick_limit("TAS") == 5, "Tasmania has five picks to make: three early ones and two later (%d)" % d.pick_limit("TAS"))
	_run_plain(d)
	_check(d.count_for("TAS") >= 5, "Tasmania makes its picks (%d)" % d.count_for("TAS"))


func _run_plain(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


# ---------------------------------------------------------------------------
# A career with the package
# ---------------------------------------------------------------------------
func _test_build_and_entry() -> void:
	_new_career()
	_check(GameState.expansion.is_empty(), "On: nothing is built before the season before entry ends")
	var rivals_before := 0
	for code in GameState.season.lists:
		rivals_before += (GameState.season.lists[code] as Array).size()
	var history := _rollover()
	_check(GameState.season_year == 2028 and GameState.season.ladder.has("TAS"), "On: Tasmania is on the 2028 ladder")
	_check(_numbered == "2 4 6 8 / 2 4 6 8", "On: the last four clubs' first picks are numbered 2, 4, 6, 8 before the draft and fall there (%s)" % _numbered)
	var tas: Array = GameState.season.lists["TAS"]
	var st: Dictionary = GameState.expansion.get("TAS", {})
	_check(bool(st.get("package", false)) and (st.get("list", [1]) as Array).is_empty(),
			"On: the list Tasmania built became its list")
	_check(_count_prefix(tas, "EXP_") == 0, "On: none of the old generated players")
	var from_state := _count_prefix(tas, "FND_")
	_check(from_state >= 10 and from_state <= Expansion.FOUNDATION_SIZE, "On: the list is built on state-league signings (%d)" % from_state)
	_check(tas.size() >= Contracts.min_list() and tas.size() <= Contracts.MAX_LIST, "On: a full list (%d)" % tas.size())
	var mine := _picks_of(history, "TAS")
	_check(mine.has(1) and mine.has(3) and mine.has(9), "On: Tasmania drafted at picks 1, 3 and 9 (%s)" % str(mine))
	_check((st.get("traded_picks", []) as Array).size() == 4 and not (mine.has(5) or mine.has(7) or mine.has(11) or mine.has(13)),
			"On: picks 5, 7, 11 and 13 were traded, as they must be (%s)" % str(mine))
	var trade_news := false
	var entry_news := false
	for item in GameState.news:
		if str(item["text"]).begins_with("Trade: Tasmania trade pick 5"):
			trade_news = true
		if str(item["kind"]) == "expansion" and str(item["text"]).contains("from the state leagues"):
			entry_news = true
	_check(trade_news, "On: the trade for a senior player is in the news")
	_check(entry_news, "On: the entry news says where the list came from")
	var senior := {}
	for p in tas:
		if p.has("joined") and not (st.get("signings", []) as Array).has(str(p["id"])):
			senior = p
	_check(not senior.is_empty() and float(senior.get("age", 0.0)) >= Expansion.SENIOR_AGE,
			"On: the traded pick brought a senior player")
	var signings: Array = st.get("signings", [])
	var lost: Array = st.get("lost", [])
	_check(signings.size() <= Expansion.FIRST_WINDOW, "On: no more than %d signings in the first off-season (%d)" % [Expansion.FIRST_WINDOW, signings.size()])
	var one_each := true
	for c in lost:
		if lost.count(c) > 1:
			one_each = false
	_check(one_each and lost.size() == signings.size(), "On: one player per rival club")
	var seen := {}
	var twice := ""
	var no_deal := ""
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if seen.has(str(p["id"])):
				twice += str(p["id"]) + " "
			seen[str(p["id"])] = true
	for p in tas:
		if int(p.get("contract_years", 0)) <= 0 or int(p.get("salary", 0)) <= 0:
			no_deal += str(p["id"]) + " "
	_check(twice == "", "On: no player is on two lists (%s)" % twice)
	_check(no_deal == "", "On: every Tasmanian has a contract (%s)" % no_deal)
	# Its draftees went into the list it was building, which the rollover's
	# contract tick never reaches: the plain two-year rookie deal, not three.
	var rookie_years := []
	for p in tas:
		if str(p.get("drafted_type", "")) == "national" and int(p.get("drafted_year", 0)) == 2027:
			rookie_years.append(int(p.get("contract_years", 0)))
	_check(not rookie_years.is_empty() and rookie_years.all(func(y): return y == Contracts.ROOKIE_YEARS),
			"On: Tasmania's draftees start 2028 with two seasons left (%s)" % str(rookie_years))
	var relief := int((st.get("relief", {}) as Dictionary).get("2028", -1))
	_check(relief >= 0 and relief <= Contracts.indexed_money_2027(Expansion.SIGN_ON_SEASON_MAX, 2028),
			"On: this season's sign-on money is set, inside the limit (%d)" % relief)
	_check(GameState.cap_for("TAS") == GameState.salary_cap + relief, "On: Tasmania's cap carries its sign-on money")
	_check(GameState.cap_for("GEE") == GameState.salary_cap, "On: no other club's cap moves")
	_check(not GameState.expansion.has("CANB") and not GameState.season.ladder.has("CANB"),
			"On: Canberra, not chosen, builds nothing")
	var comp_ok := true
	for c in GameState.compensation:
		if str(c["to"]) == "TAS" and not lost.has(str(c["club"])):
			comp_ok = false
	_check(comp_ok and rivals_before > 0, "On: a compensation pick only goes to a club that lost a player to Tasmania")


func _test_second_year_and_end() -> void:
	# 2028 -> 2029: the second draft carries one extra pick, pick 5.
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "The 2028 draft opens")
	var extra := []
	for c in GameState.draft.comp_picks:
		if bool(c.get("concession", false)):
			extra.append([str(c["club"]), int(c["index"]) + 1])
	_check(extra.size() == 2 and str(extra[0][0]) != "TAS" and int(extra[0][1]) == 5 and str(extra[1][0]) == "TAS" and int(extra[1][1]) == 9,
			"The second draft: Tasmania trades pick 5 and holds pick 9 on top of its own (%s)" % str(extra))
	_run_draft()
	GameState.finish_intake_draft()
	var st: Dictionary = GameState.expansion["TAS"]
	_check((st["signings"] as Array).size() <= Expansion.SIGNINGS, "No more than %d signings in all" % Expansion.SIGNINGS)
	_check((st["relief"] as Dictionary).has("2029"), "The second season has its sign-on money")
	var used := int(st["relief"].get("2028", 0)) + int(st["relief"].get("2029", 0))
	_check(used <= Contracts.indexed_money_2027(Expansion.SIGN_ON_POOL, 2029), "Two seasons never spend more than the pool (%d)" % used)
	# 2029 -> 2030: it is over.
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "The 2029 draft opens")
	var later := 0
	for c in GameState.draft.comp_picks:
		if bool(c.get("concession", false)):
			later += 1
	_check(later == 2, "The third draft: picks 5 and 9 again")
	_run_draft()
	GameState.finish_intake_draft()
	# 2030, its third season: the sign-on money steps down, it does not stop.
	var second := int(st["relief"].get("2029", 0))
	var third := Expansion.tapered_relief(second, 3, ExpansionBuild._signing_salaries(GameState, "TAS"))
	_check(GameState.season_year == 2030 and int((st["relief"] as Dictionary).get("2030", -1)) == third
			and GameState.cap_for("TAS") == GameState.salary_cap + third,
			"Its third season keeps two thirds of the second season's sign-on money (%d of %d)" % [third, second])
	_check(second == 0 or (third > 0 and third < second), "The third season's money is less than the second's, not nothing (%d, %d)" % [third, second])
	var tas_pay := Contracts.payroll(GameState.season.lists.get("TAS", [])) + GameState.dead_for("TAS")
	_check(tas_pay <= GameState.cap_for("TAS"),
			"Tasmania is not over its cap in 2030 (%d against %d, league cap %d)" % [tas_pay, GameState.cap_for("TAS"), GameState.salary_cap])
	var fourth := ExpansionBuild._relief_in(GameState, "TAS", 2031)
	# Each season's money stops at what the signings are still paid, so when
	# that limit holds both seasons the fourth equals the third.
	var paid := ExpansionBuild._signing_salaries(GameState, "TAS")
	_check(fourth == Expansion.tapered_relief(second, 4, paid)
			and (second == 0 or (fourth > 0 and (fourth < third or fourth == paid))),
			"Its fourth season keeps one third (%d; third %d, second %d, signings paid %d)" % [fourth, third, second, paid])
	_check(ExpansionBuild._relief_in(GameState, "TAS", 2032) == 0, "From its fifth season Tasmania's cap is everyone's cap")
	_check(GameState.cap_for("GEE") == GameState.salary_cap, "No other club's cap moves in 2030")
	# A save from before the money stepped down has no 2030 figure: same answer.
	(st["relief"] as Dictionary).erase("2030")
	_check(GameState.cap_for("TAS") == GameState.salary_cap + third, "A save without a third-season figure works it out the same")
	(st["relief"] as Dictionary)["2030"] = third
	_check(ExpansionBuild.building(GameState).is_empty() and ExpansionBuild.first_season(GameState).is_empty(),
			"From its third season Tasmania is treated like every other club")


## A new club asks about your player: you are told, and can re-sign him.
func _test_your_player_is_approached() -> void:
	for answer in ["keep", "go", "silent"]:
		_new_career()
		GameState.season.round_index = Season.REGULAR_ROUNDS - Expansion.APPROACH_ROUNDS_LEFT
		var target := {}
		for p in GameState.my_list:
			p["contract_years"] = 3
		for p in GameState.my_list:
			if float(p.get("age", 30.0)) < 27.0 and (target.is_empty() or int(p["overall"]) > int(target["overall"])):
				target = p
		target["contract_years"] = 1
		GameState._next_week_event()
		var st: Dictionary = GameState.expansion.get("TAS", {})
		var asked := {}
		for t in st.get("targets", []):
			if str(t["club"]) == "GEE":
				asked = t
		if answer == "keep":
			_check(not asked.is_empty() and str(asked["id"]) == str(target["id"]), "Your out-of-contract player is the one Tasmania asks about")
			var said := false
			for item in GameState.news:
				if str(item["text"]).contains("Tasmania have approached") and str(item["text"]).contains(GameDB.player_display_name(target)):
					said = true
			_check(said, "The approach is in the news, by name")
		var card := {}
		var index := -1
		for i in range(GameState.week_events.size()):
			if str(GameState.week_events[i].get("tid", "")) == "contracts_new_club_approach":
				card = GameState.week_events[i]
				index = i
		if answer == "keep":
			_check(not card.is_empty() and str(card.get("player_id", "")) == str(target["id"]), "You are told with a card about him")
			_check(str(card.get("title", "")).contains("Tasmania") and not str(card.get("text", "")).contains("{"),
					"The card names the club and leaves no blank (%s)" % str(card.get("title", "")))
			var lines := StoryEngine.stakes_lines(card["options"][0]["effects"], card["facts"])
			_check(lines.size() == 2 and lines[0].begins_with("Gain: ") and lines[0].contains(" stays") and not lines[0].contains("He ") and lines[1].contains("against your cap"),
					"Re-signing says what it gains and what it costs (%s)" % " | ".join(lines))
			var go_lines := StoryEngine.stakes_lines(card["options"][1]["effects"], card["facts"])
			_check(" ".join(go_lines).contains("joins Tasmania when this season ends") and not " ".join(go_lines).contains("{"),
					"Letting him go says what happens (%s)" % " | ".join(go_lines))
			var out := GameState.resolve_card(index, 0)
			_check(out.contains("re-signs") and bool(target.get("resigned", false)) and int(target["contract_years"]) > 1,
					"Re-sign him now: he is signed (%s)" % out)
			_check(str(asked["status"]) == "kept", "Tasmania's approach is over")
			_settle_approaches()
			_check(GameState.my_list.has(target), "He is still yours when the season ends")
		elif answer == "go":
			var out := GameState.resolve_card(index, 1)
			_check(out.contains("will join Tasmania"), "Let him go: he will join them (%s)" % out)
			_check(GameState.my_list.has(target), "He stays until the season ends")
			_settle_approaches()
			_check(not GameState.my_list.has(target) and (ExpansionBuild.list_of(GameState, "TAS") as Array).has(target),
					"When the season ends he is on Tasmania's list")
			_check(str(target["club"]) == "TAS" and int(target["contract_years"]) >= 1 and not target.has("released_by"),
					"He has a Tasmanian contract")
			var paid := false
			for c in GameState.compensation:
				if str(c["player"]) == str(target["id"]) and str(c["club"]) == "GEE" and str(c["to"]) == "TAS":
					paid = true
			_check(paid == (int(card["facts"].get("comp_after", 0)) > 0), "You get the pick the card promised, or none if it promised none")
		else:
			# Unanswered, the card settles as "let him go" before the next round.
			GameState._settle_week_event()
			_check(str(asked.get("status", "")) == "joining", "Say nothing and he goes: the card settles that way")


## The rule for a rival's player, case by case: his club keeps a player it
## would have re-signed anyway; one it would let go, who would get a game at
## the new club, joins it; one it wants but cannot fit under its cap joins it
## only while the new club has first call on such players; and a club that
## loses a player it wanted gets a draft pick.
func _test_who_a_rival_keeps() -> void:
	var was := Expansion.FIRST_CALL_CAP_SQUEEZED
	for case: String in ["kept", "let go", "cap", "cap, no first call"]:
		Expansion.FIRST_CALL_CAP_SQUEEZED = case != "cap, no first call"
		_new_career()
		var club := "SYD"
		var list: Array = GameState.season.lists[club]
		for q in list:
			q["contract_years"] = 3
		list.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
		# The 13th-best player, but never a recognised ruck: the one ruck slot
		# picks by tap work, not overall (Ratings.select_22), so lifting his
		# teammates' ratings could never make his club willing to let a sole
		# ruck go, and the "let go" case would test the career's luck instead.
		var p: Dictionary = {}
		# Kept: a best-23 regular, so he would rather stay than go (a matched
		# player decides, Expansion.MATCHED_PLAYER_DECIDES), whatever this
		# seed's draft left around him (row T1.R26 L1 moved your club's picks).
		for i in range(4 if case == "kept" else 12, list.size()):
			if not Ratings.plays_role(list[i], "RUCK"):
				p = list[i]
				break
		_check(not p.is_empty(), "A non-ruck to test the %s case with" % case)
		p["contract_years"] = 1
		p["age"] = 26.0
		p.erase("retiring")
		p.erase("rehab")   # rehab lifts his rating to his potential (TradeValue.rating): he would be needed
		if not case.begins_with("cap"):
			# Room under his club's cap, so neither case rests on how close
			# this seed's drafted list sits to it (row T1.R26 L1 moved your
			# club's draft picks, and with them every list after).
			var room := int((GameState.salary_cap - Contracts.asking_salary(p) - 1500000) / maxi(1, list.size() - 1))
			for q in list:
				if q != p:
					q["salary"] = mini(int(q.get("salary", 0)), room)
		if case == "let go":
			for q in list:
				if q != p:
					q["overall"] = maxi(int(q["overall"]), int(p["overall"]) + 8)
					q["potential"] = maxi(int(q.get("potential", 0)), int(q["overall"]))
			# A competent club delists him only for someone better (#888): a free
			# agent at his position who beats him.
			var fa: Dictionary = p.duplicate(true)
			fa["id"] = "FA_" + str(p["id"])
			fa["overall"] = int(p["overall"]) + 6
			fa["potential"] = maxi(int(fa.get("potential", 0)), int(fa["overall"]))
			GameState.free_agents.append(fa)
			# Last season's free agents leave the market before the new club's
			# approaches settle, so in the off-season the one who beats him is
			# his club's draft pick. Make every prospect at his position beat
			# him too, so the case does not rest on how strong this seed's
			# generated class happens to be (row 65 drafts it at its made
			# rating, without the pool year's growth that used to lift it).
			var role := str(p.get("role", ""))
			for d in GameState._open_class(GameState.season_year):
				# Every prospect can play his spot, so whichever pick his club
				# holds reaches one who beats him (row T1.R26 L1 moved the
				# seed's ladder, and with it his club's pick).
				if str(d.get("role", "")) != role and str(d.get("role2", "")) != role:
					d["role2"] = role
				if str(d.get("role", "")) == role or str(d.get("role2", "")) == role:
					d["overall"] = maxi(int(d["overall"]), int(p["overall"]) + 6)
					d["potential"] = maxi(int(d.get("potential", 0)), maxi(int(d["overall"]), int(p.get("potential", 0)) + 6))
		elif case.begins_with("cap"):
			p["overall"] = maxi(int(p["overall"]), 84)
			p["potential"] = maxi(int(p.get("potential", 0)), 86)
			var others := 0
			for q in list:
				if q != p:
					others += int(q.get("salary", 0))
			var share := int((GameState.salary_cap - Contracts.asking_salary(p) + 400000) / maxi(1, list.size() - 1))
			for q in list:
				if q != p:
					q["salary"] = share + 100000
		var why := GameState.ai_release_reason(club, p)
		var expect_why: String = {"kept": "", "let go": "delist", "cap": "cap", "cap, no first call": "cap"}[case]
		ExpansionBuild.ensure_foundation(GameState, "TAS")
		var st := ExpansionBuild.state(GameState, "TAS")
		(st["approached"] as Array).append(2027)
		var t := {"id": str(p["id"]), "club": club, "year": 2027, "name": "x", "status": "asked"}
		(st["targets"] as Array).append(t)
		_settle_approaches()
		var joined: bool = (ExpansionBuild.list_of(GameState, "TAS") as Array).has(p)
		var paid := false
		for c in GameState.compensation:
			if str(c["player"]) == str(p["id"]):
				paid = true
		# The off-season decision itself let him go (he was not wanted): his
		# club's draft pick beats him even after last season's free agents
		# leave the market, so this does not rest on him choosing to go.
		var let_go := false
		for e in GameState.offseason_log:
			if str(e.get("kind", "")) == "released" and str(e.get("id", "")) == str(p["id"]):
				let_go = not bool(e.get("wanted", true))
		var want_join: bool = case == "let go" or case == "cap"
		_check(why == expect_why and joined == want_join and str(t["status"]) == ("joined" if want_join else "stayed")
				and (case != "cap" or paid or not GameState.comp_tenure_ok(p)) and (case != "let go" or (not paid and let_go)),
				"A rival's player, %s: %s (his club's reason '%s', joined %s, pick to his club %s, let go in the off-season %s)" % [case,
				"he joins the new club" if want_join else "he stays", why, str(joined), str(paid), str(let_go)])
	Expansion.FIRST_CALL_CAP_SQUEEZED = was


func _test_save_round_trip() -> void:
	_new_career()
	GameState.set_canberra(true)
	GameState.season.round_index = Season.REGULAR_ROUNDS - Expansion.APPROACH_ROUNDS_LEFT
	GameState._next_week_event()
	var before: Dictionary = GameState.expansion["TAS"]
	var n_list: int = (before["list"] as Array).size()
	var n_targets: int = (before["targets"] as Array).size()
	_check(n_list == Expansion.FOUNDATION_SIZE and n_targets > 0, "Mid-build: a list and approaches to save (%d, %d)" % [n_list, n_targets])
	var list_ids := _ids(before["list"])
	_check(GameState.save_career(), "A career saves mid-build")
	GameState.load_career()
	_check(GameState.canberra_on and GameDB.active_clubs(2030).has("CANB"), "The loaded career keeps its Canberra choice")
	var after: Dictionary = GameState.expansion.get("TAS", {})
	_check(_ids(after.get("list", [])) == list_ids, "The list being built survives the round trip")
	_check((after.get("targets", []) as Array).size() == n_targets and ExpansionBuild._approached(after, 2027),
			"The approaches survive the round trip")
	var history := _rollover()
	_check(GameState.season_year == 2028 and _count_prefix(GameState.season.lists["TAS"], "FND_") >= 24
			and _picks_of(history, "TAS").has(1), "The loaded career finishes the build and enters")
	# And a save taken with the draft open.
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.begin_intake_draft()
	_check(GameState.save_career(), "A career saves with the second draft open")
	GameState.load_career()
	var extra := 0
	for c in GameState.draft.comp_picks:
		if bool(c.get("concession", false)):
			extra += 1
	_check(GameState.draft != null and extra == 2, "The open draft keeps Tasmania's extra pick through a reload")
	_run_draft()
	_check(GameState.finish_intake_draft() and GameState.season_year == 2029, "The reloaded draft finishes")


## A save made before the package (expansion_package was off on main until
## 2026-11-06): no "expansion" or "canberra_on" key, and a Tasmania past 2028
## that arrived as 36 generated players.
func _as_old_save(tas: Array = []) -> void:
	var saved := CareerSave.read(GameState.save_path)
	saved.erase("expansion")
	saved.erase("canberra_on")
	if not tas.is_empty():
		saved["season"]["lists"]["TAS"] = tas
	_check(CareerSave.write(saved, CareerSave.read_meta(GameState.save_path), GameState.save_path),
			"The save is rewritten as an old one")


## Ruling 9: a save that has not reached 2028 gets the package when Tasmania
## arrives; a save past 2028 keeps the Tasmania it has. Either way it keeps
## Canberra, because the choice did not exist when it was made.
func _test_old_saves() -> void:
	_new_career()
	_check(GameState.save_career(), "An old career, before 2028, saves")
	_as_old_save()
	GameState.load_career()
	_check(GameState.canberra_on and GameDB.active_clubs(2030).has("CANB"), "An old save keeps Canberra")
	_rollover()
	_check(_count_prefix(GameState.season.lists["TAS"], "FND_") >= 24 and _count_prefix(GameState.season.lists["TAS"], "EXP_") == 0,
			"An old save that had not reached 2028 gets the package")
	_new_career()
	_rollover()
	_check(GameState.season_year == 2028 and GameState.save_career(), "An old career, in 2028, saves")
	var old_tas: Array = Prospects.generate_expansion_list("TAS", 2028)
	_as_old_save(old_tas)
	GameState.load_career()
	_check(_ids(GameState.season.lists["TAS"]) == _ids(old_tas), "A save past 2028 loads the Tasmania it had")
	_check(GameState.canberra_on and GameState.cap_for("TAS") == GameState.salary_cap,
			"It keeps Canberra and Tasmania has no sign-on money")
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.begin_intake_draft()
	var extra := 0
	for c in GameState.draft.comp_picks:
		if bool(c.get("concession", false)):
			extra += 1
	_run_draft()
	GameState.finish_intake_draft()
	_check(extra == 0 and not GameState.expansion.has("TAS"), "A save past 2028 gets no extra pick and no approaches")
	_check(_count_prefix(GameState.season.lists["TAS"], "EXP_") >= 20, "It keeps the Tasmania it has into 2029")
