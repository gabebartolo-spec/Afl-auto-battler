extends RefCounted
## Expansion package suite: how a new club builds its list (director's
## ruling, 2026-10-14; Expansion and ExpansionBuild), behind the feature switch
## "expansion_package". With the switch off a new club arrives exactly as it
## always did and nothing of the build is written; with it on, the club brings
## state-league signings, early draft picks, a senior player for the pick it
## must trade, and out-of-contract players from rival clubs.
## Run through tests/run_expansion_package_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded: a clock seed plays a different league.
const SUITE_SEED := 2027
const FEATURE := "expansion_package"


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_test_switch_off_is_today()
	Features.set_on(FEATURE, true)
	_test_rules()
	_test_canberra_choice()
	_test_draft_seats()
	_test_build_and_entry()
	_test_second_year_and_end()
	_test_your_player_is_approached()
	_test_save_round_trip()
	_test_old_saves()
	Features.clear(FEATURE)
	GameState.reset()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Expansion package tests: %d checks, %d failures" % [checks, failures.size()])


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
func _new_career(club := "GEE") -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), SUITE_SEED)
	GameState.draft.start_for_user(club)
	_run_plain(GameState.draft)
	GameState.start_season(club, GameState.draft.list())


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
# The switch off: nothing changes, nothing is written
# ---------------------------------------------------------------------------
func _test_switch_off_is_today() -> void:
	_check(not Features.on(FEATURE), "The switch ships off")
	_new_career()
	_check(GameState.canberra_on and GameDB.active_clubs(2030).has("CANB"), "Off: Canberra joins in 2030, as it always did")
	var history := _rollover()
	_check(_picks_of(history, "TAS").is_empty(), "Off: Tasmania takes no part in the draft before its first season")
	var tas: Array = GameState.season.lists["TAS"]
	_check(_ids(tas) == _ids(Prospects.generate_expansion_list("TAS", 2028)),
			"Off: Tasmania arrives with the same 36 generated players as before")
	_check(GameState.expansion.is_empty(), "Off: the build keeps no state")
	_check(GameState.cap_for("TAS") == GameState.salary_cap, "Off: no club has sign-on money")
	var approach_news := false
	for item in GameState.news:
		if str(item["text"]).contains("approached") or str(item["text"]).contains("state leagues"):
			approach_news = true
	_check(not approach_news, "Off: no news of approaches or state-league signings")
	_check(GameState.save_career(), "Off: the career saves")
	var saved := CareerSave.read(GameState.save_path)
	_check(not saved.has("expansion") and not saved.has("canberra_on"), "Off: the save has none of the build's keys")
	_check(GameState.story_card("contracts_new_club_approach", GameState.my_list[0]).has("options"),
			"Off: the approach card still builds (it is in the deck) but is never dealt")
	_check(ExpansionBuild.card(GameState).is_empty(), "Off: no approach card is dealt")


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
	_check(afters == [0, 1, 2, 3, 18, 36], "The first draft: picks 1, 3, 5, 7 and the first pick of rounds two and three (%s)" % str(afters))
	var second: Array = Expansion.second_draft_picks("TAS")
	_check(second.size() == 1 and int(second[0]["after"]) == 4, "The second draft: pick 5 and nothing else")
	var cap := Contracts.indexed_money_2027(Expansion.SIGN_ON_SEASON_MAX, 2028)
	_check(Expansion.sign_on_relief(900000, 2028, 0) == 900000, "Sign-on money never exceeds what the signings are paid")
	_check(Expansion.sign_on_relief(9000000, 2028, 0) == cap, "Sign-on money stops at the season's limit")
	var pool := Contracts.indexed_money_2027(Expansion.SIGN_ON_POOL, 2029)
	_check(Expansion.sign_on_relief(9000000, 2029, cap) == pool - cap, "The second season gets what is left of the pool")
	_check(Expansion.sign_on_relief(9000000, 2029, pool + 1) == 0, "A spent pool gives nothing")


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
	picks[3]["club"] = str(clubs[5])   # the pick it must trade, traded
	d.add_compensation(picks)
	_check(str(d.pick_sequence[0]) == "TAS" and str(d.pick_sequence[2]) == "TAS" and str(d.pick_sequence[4]) == "TAS",
			"Tasmania holds picks 1, 3 and 5")
	_check(str(d.pick_sequence[1]) == str(clubs[0]) and str(d.pick_sequence[3]) == str(clubs[1]),
			"The club that would have picked first picks second, the next picks fourth")
	_check(str(d.pick_sequence[6]) == str(clubs[5]) and str(d.pick_origin[6]) == "TAS",
			"The traded pick is pick 7, held by the club that traded for it")
	_check(str(d.pick_sequence[clubs.size() + 4]) == "TAS" and int(d.pick_rounds[clubs.size() + 4]) == 2,
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
# A career with the switch on
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
	_check(from_state >= 24 and from_state <= Expansion.FOUNDATION_SIZE, "On: the list is built on state-league signings (%d)" % from_state)
	_check(tas.size() >= Prospects.MIN_LIST and tas.size() <= Contracts.MAX_LIST, "On: a full list (%d)" % tas.size())
	var mine := _picks_of(history, "TAS")
	_check(mine.has(1) and mine.has(3) and mine.has(5), "On: Tasmania drafted at picks 1, 3 and 5 (%s)" % str(mine))
	_check(bool(st.get("traded", false)) and not mine.has(7), "On: pick 7 was traded, as it must be (%s)" % str(mine))
	var trade_news := false
	var entry_news := false
	for item in GameState.news:
		if str(item["text"]).begins_with("Trade: Tasmania trade pick 7"):
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
	var relief := int((st.get("relief", {}) as Dictionary).get("2028", -1))
	_check(relief >= 0 and relief <= Contracts.indexed_money_2027(Expansion.SIGN_ON_SEASON_MAX, 2028),
			"On: this season's sign-on money is set, inside the limit (%d)" % relief)
	_check(GameState.cap_for("TAS") == GameState.salary_cap + relief, "On: Tasmania's cap carries its sign-on money")
	_check(GameState.cap_for("GEE") == GameState.salary_cap, "On: no other club's cap moves")
	_check(not GameState.expansion.has("CANB") and not GameState.season.ladder.has("CANB"),
			"On: Canberra, not chosen, builds nothing")
	_check(not signings.is_empty(), "On: Tasmania signed at least one out-of-contract player from a rival club (%d)" % signings.size())
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
	_check(extra.size() == 1 and str(extra[0][0]) == "TAS" and int(extra[0][1]) == 5,
			"The second draft: Tasmania holds pick 5 on top of its own (%s)" % str(extra))
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
	_check(later == 0, "The third draft: no extra pick")
	_run_draft()
	GameState.finish_intake_draft()
	_check(GameState.cap_for("TAS") == GameState.salary_cap, "From its third season Tasmania's cap is everyone's cap")
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
			_check(lines.size() == 2 and lines[0].begins_with("Gain: He stays") and lines[1].contains("against your cap"),
					"Re-signing says what it gains and what it costs (%s)" % " | ".join(lines))
			var go_lines := StoryEngine.stakes_lines(card["options"][1]["effects"], card["facts"])
			_check(" ".join(go_lines).contains("joins Tasmania when this season ends") and not " ".join(go_lines).contains("{"),
					"Letting him go says what happens (%s)" % " | ".join(go_lines))
			var out := GameState.resolve_card(index, 0)
			_check(out.contains("re-signs") and bool(target.get("resigned", false)) and int(target["contract_years"]) > 1,
					"Re-sign him now: he is signed (%s)" % out)
			_check(str(asked["status"]) == "kept", "Tasmania's approach is over")
			GameState.season.round_index = GameState.season.fixture.size()
			GameState.open_offseason()
			_check(GameState.my_list.has(target), "He is still yours when the season ends")
		elif answer == "go":
			var out := GameState.resolve_card(index, 1)
			_check(out.contains("will join Tasmania"), "Let him go: he will join them (%s)" % out)
			_check(GameState.my_list.has(target), "He stays until the season ends")
			GameState.season.round_index = GameState.season.fixture.size()
			GameState.open_offseason()
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
	_check(Features.on(FEATURE) and GameState.canberra_on and GameDB.active_clubs(2030).has("CANB"), "The loaded career keeps its Canberra choice")
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
	_check(GameState.draft != null and extra == 1, "The open draft keeps Tasmania's extra pick through a reload")
	_run_draft()
	_check(GameState.finish_intake_draft() and GameState.season_year == 2029, "The reloaded draft finishes")


## Ruling 9: a save that has not reached 2028 gets the package when Tasmania
## arrives; a save past 2028 keeps the Tasmania it has. Either way it keeps
## Canberra, because the choice did not exist when it was made.
func _test_old_saves() -> void:
	Features.set_on(FEATURE, false)
	_new_career()
	_check(GameState.save_career(), "An old career, before 2028, saves")
	Features.set_on(FEATURE, true)
	GameState.load_career()
	_check(GameState.canberra_on and GameDB.active_clubs(2030).has("CANB"), "An old save keeps Canberra")
	_rollover()
	_check(_count_prefix(GameState.season.lists["TAS"], "FND_") >= 24 and _count_prefix(GameState.season.lists["TAS"], "EXP_") == 0,
			"An old save that had not reached 2028 gets the package")
	Features.set_on(FEATURE, false)
	_new_career()
	_rollover()
	var old_ids := _ids(GameState.season.lists["TAS"])
	_check(GameState.save_career(), "An old career, in 2028, saves")
	Features.set_on(FEATURE, true)
	GameState.load_career()
	_check(_ids(GameState.season.lists["TAS"]) == old_ids, "A save past 2028 loads the Tasmania it had")
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
	# A save written with the switch on still loads with it off: it carries on as an ordinary career.
	_new_career()
	_rollover()
	_check(GameState.save_career(), "A career with the package saves")
	Features.set_on(FEATURE, false)
	GameState.load_career()
	_check(GameState.season_year == 2028 and _count_prefix(GameState.season.lists["TAS"], "FND_") >= 24,
			"A save made with the switch on loads with it off")
	_check(GameState.cap_for("TAS") == GameState.salary_cap, "With the switch off no sign-on money applies")
	_rollover()
	_check(GameState.season_year == 2029 and (GameState.season.lists["TAS"] as Array).size() >= Prospects.MIN_LIST,
			"And it plays on")
	Features.set_on(FEATURE, true)
