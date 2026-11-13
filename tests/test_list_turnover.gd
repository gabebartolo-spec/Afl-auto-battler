extends RefCounted
## Every list turns over, the coach's included: ten seasons of a career whose
## coach passes every National Draft the moment the minimum allows, on today's
## lists and on the 1990 lists. Run through tests/run_list_turnover_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_t("_test_passing_list_turns_over", ["2026", "GEE"])
	_t("_test_passing_list_turns_over", ["1990", "GEE"])
	GameState.replay_seed = 0
	print(Ran.line("List turnover", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## A coach who passes every draft the moment the minimum allows still sees
## his list turn over like a rival's: his veterans retire when their time
## comes (Prospects.should_retire, not the list size), and the draft makes
## him fill the places they leave (Draft.pass_block_reason counts only the
## players staying). Found 2026-11-13: Geelong kept the same 32 from 1990
## to 2026, aged 40-50 by 2010.
func _test_passing_list_turns_over(dataset: String, me: String) -> void:
	GameState.reset(dataset)
	GameState.replay_seed = SUITE_SEED
	GameState.career_seed = SUITE_SEED
	if GameDB.club_list(me).is_empty():
		_check(dataset != "2026", "%s lists have %s" % [dataset, me])
		return
	GameState.start_season(me, GameDB.club_list(me))
	var first := GameState.season_year
	var start_ids := {}
	for p in GameState.my_list:
		start_ids[str(p["id"])] = true
	# Each real player's last real season (data/legacy/<year>/history and
	# list_additions, last_season), and the season each one retires before.
	var real_last := {}
	for p in GameDB.all_players_sorted():
		if int(p.get("real_last", 0)) > 0:
			real_last[str(p["id"])] = int(p["real_last"])
	var retired_at := {}
	var stayer := {}
	var seasons := 0
	var smallest := 999
	var smallest_min := 0
	var smallest_year := 0
	var short_by := 999
	for _i in range(10):
		var season: Season = GameState.season
		season.round_index = season.fixture.size()
		if not GameState.begin_intake_draft():
			break
		if dataset == "1990" and stayer.is_empty():
			# The usual talk-round (Retirement): one of yours, due to retire
			# at his real time, says yes and goes around once more.
			for q in GameState.my_list:
				if real_last.has(str(q["id"])) and GameState.retiring_now(q):
					stayer = q
					break
			if not stayer.is_empty():
				Retirement.apply(stayer, {"stays": true, "reason": "test"}, GameState.season_year + 1)
		var draft: Draft = GameState.draft
		var guard := 0
		draft.auto_until_user_turn()
		while not draft.is_finished() and guard < 4000:
			guard += 1
			if draft.is_user_turn() and draft.pass_block_reason() == "":
				draft.user_pass()
				continue
			var cand := draft._best_ai_pick(draft.current_club())
			if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
				draft._skip_current_pick()
			draft.auto_until_user_turn()
		if not GameState.finish_intake_draft():
			break
		seasons += 1
		# Each season against its own minimum (48 to 1993, 38 from 1994).
		if GameState.my_list.size() - Contracts.min_list() < short_by:
			short_by = GameState.my_list.size() - Contracts.min_list()
			smallest = GameState.my_list.size()
			smallest_min = Contracts.min_list()
			smallest_year = GameState.season_year
		for r in GameState.intake_summary.get("retired", []):
			retired_at[str(r["id"])] = GameState.season_year
	var oldest := 0.0
	var drafted := 0
	var stayed := 0
	for p in GameState.my_list:
		oldest = maxf(oldest, float(p.get("age", 0.0)))
		drafted += 1 if int(p.get("drafted_year", 0)) >= first else 0
		stayed += 1 if start_ids.has(str(p["id"])) else 0
	_check(seasons == 10, "%s: ten seasons pass (%d)" % [dataset, seasons])
	_check(oldest <= 38.0, "%s: nobody on %s's list is older than 38 after ten seasons of passing (oldest %.0f)" % [dataset, me, oldest])
	_check(drafted >= 8, "%s: %s's list holds the draftees it was made to take (%d)" % [dataset, me, drafted])
	_check(stayed < GameState.my_list.size() / 2,
			"%s: most of %s's list has turned over (%d of %d from the start)" % [dataset, me, stayed, GameState.my_list.size()])
	# The draft counts every player retiring at the rollover (Draft.leaving),
	# so a coach who passes at the minimum still starts each season on it.
	_check(short_by >= 0,
			"%s: %s's list never starts a season under the minimum (closest %d in %d, minimum %d)" % [
				dataset, me, smallest, smallest_year, smallest_min])
	if dataset == "1990":
		_real_retirements(real_last, retired_at, stayer, first + seasons)
	GameState.reset()


## Director, 2026-11-13: "make all historical players retirement start
## roughly when it did irl (playhers can still convince them to play on with
## the usual mechanics)". Real players due well inside the run retire within
## a couple of seasons of their real time, and the one talked round played on.
func _real_retirements(real_last: Dictionary, retired_at: Dictionary, stayer: Dictionary, end: int) -> void:
	_check(real_last.size() > 400, "1990: the real players carry their last real season (%d)" % real_last.size())
	var due := 0
	var gone := 0
	var on_time := 0
	for id in real_last:
		var real_go := int(real_last[id]) + 1   # the first season he no longer played
		if real_go > end - 3:
			continue
		due += 1
		if not retired_at.has(id):
			continue
		gone += 1
		on_time += 1 if absi(int(retired_at[id]) - real_go) <= 2 else 0
	_check(due > 300 and gone >= due * 0.6,
			"1990: most real players due by %d retired in the career (%d of %d; the rest were delisted)" % [end - 3, gone, due])
	_check(on_time >= gone * 0.9,
			"1990: they retired within two seasons of their real time (%d of %d)" % [on_time, gone])
	_check(not stayer.is_empty(), "1990: a player of yours was due to retire after the first season")
	if stayer.is_empty():
		return
	var sid := str(stayer["id"])
	var due_go := int(real_last[sid]) + 1 + Prospects.real_slack(stayer)
	_check(int(retired_at.get(sid, 0)) > due_go,
			"1990: talked round, %s played on past his time (due %d, retired before %d)" % [
				GameDB.player_display_name(stayer), due_go, int(retired_at.get(sid, 0))])
