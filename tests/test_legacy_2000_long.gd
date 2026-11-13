extends RefCounted
## A 2000 career never ends (director 2026-11-13: "campaigns can go for
## eternity"). A seeded career begun at Essendon in 2000 rolls season after
## season past 2027: Gold Coast enter in 2011 and GWS in 2012 as the sim's own
## expansion, every club keeps a full list, and the career is still the one
## begun in 2000. About 28 seasons (some 11 minutes), so it runs nightly
## (tools/ci_long_suites.txt). Run through tests/run_legacy_2000_long_tests.gd.

const Ran := preload("res://tests/functions_ran.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2000
const CLUB := "ESS"
const PAST := 2028


func run() -> void:
	failures.clear()
	checks = 0
	_t("_test_rolls_past_2027")
	GameState.reset()
	print(Ran.line("Legacy 2000 long", self))


func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
		push_error(what)


func _start() -> void:
	GameState.reset("2000")
	GameState.replay_seed = SUITE_SEED
	GameState.career_seed = SUITE_SEED
	GameState.begin_real_lists()
	GameState.choose_real_club(CLUB)
	var guard := 0
	while GameState.draft != null and not GameState.draft.is_finished() and guard < 400:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				break
	GameState.finish_intake_draft()


func _to_offseason() -> void:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	while not GameState.season.is_season_over():
		GameState.advance()


## The rollover goes through the National Draft, as the game's does (Hub,
## SeasonReview): retirees leave every list each year, and the draft is where
## each club, yours included, fills their places.
func _roll_through_draft() -> bool:
	if not GameState.begin_intake_draft():
		return GameState.start_next_season()
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
	return GameState.finish_intake_draft()


func _test_rolls_past_2027() -> void:
	_start()
	_check(GameState.season_year == 2000 and GameDB.dataset_id == "2000",
			"The career begins in 2000 (%d, set %s)" % [GameState.season_year, GameDB.dataset_id])
	var originals := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			originals[str(p["id"])] = true
	var sackings := []
	while GameState.season_year < PAST:
		var from := GameState.season_year
		_to_offseason()
		# The roll is under test, not the coach: a board may sack him with no
		# job to go to (that ends a career), so keep him on and say so.
		if GameState.is_sacked():
			sackings.append(from)
			GameState.board["sacked"] = false
			GameState.board["warned"] = false
		if not _roll_through_draft():
			_check(false, "%d rolls into %d" % [from, from + 1])
			return
		var y := GameState.season_year
		var want_clubs := 16 if y < 2011 else (17 if y == 2011 else (18 if y < 2028 else 19))  # Tasmania enters in 2028 (data/clubs.csv)
		var short := []
		for code in GameState.season.clubs:
			if GameState.season.lists.get(code, []).size() < Contracts.min_list():
				short.append("%s %d" % [code, GameState.season.lists.get(code, []).size()])
		_check(y == from + 1 and GameDB.dataset_id == "2000" and GameState.my_club == CLUB,
				"%d rolls into %d at Essendon, still the 2000 career (%d, %s, set %s)" % [
					from, from + 1, y, GameState.my_club, GameDB.dataset_id])
		_check(GameState.season.clubs.size() == want_clubs and short.is_empty(),
				"%d: %d clubs with full lists (%d clubs; short: %s)" % [
					y, want_clubs, GameState.season.clubs.size(), ", ".join(short)])
	var left := 0
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if originals.has(str(p["id"])):
				left += 1
	print("Legacy 2000 long: reached %d; %d of the 2000 players still listed; board sackings waved off in %s"
			% [GameState.season_year, left, str(sackings)])
	_check(GameState.season_year >= PAST, "The 2000 career reaches %d (%d)" % [PAST, GameState.season_year])
	_check(GameState.season.clubs.has("GCS") and GameState.season.clubs.has("GWS"),
			"Gold Coast and GWS are in the league by %d" % GameState.season_year)
