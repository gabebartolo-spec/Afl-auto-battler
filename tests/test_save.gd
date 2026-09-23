extends RefCounted
## Career save regression suite. A save must reload into the same career:
## same lists, ladder, fixture position and draft, with shared player dicts
## still shared, so the next round plays out identically either way.
## Run through tests/run_save_tests.gd (which points saves at a test file).

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	_test_mid_season_round_trip()
	_test_training_survives()
	_test_no_save_mid_match()
	_test_mid_draft_round_trip()
	_test_intake_and_second_season()
	_test_bad_file_is_ignored()
	GameState.delete_saved_career()
	print("Save tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_season(club := "GEE") -> void:
	GameState.reset()
	GameState.start_season(club, GameDB.club_list(club))


## A compact fingerprint of a round's results.
func _round_sig(results: Array) -> String:
	var parts := []
	for r in results:
		parts.append("%s-%s:%d-%d" % [r["home"], r["away"], int(r["score"][0]), int(r["score"][1])])
	return ",".join(parts)


func _ladder_sig() -> String:
	var parts := []
	for row in GameState.season.ladder_sorted():
		parts.append("%s %d %d %d" % [row["code"], int(row["pts"]), int(row["pf"]), int(row["pa"])])
	return "|".join(parts)


func _test_mid_season_round_trip() -> void:
	_new_season()
	for i in range(3):
		GameState.advance()
	var ladder_before := _ladder_sig()
	var round_before: int = GameState.season.round_index
	var log_before: int = GameState.season_log.size()
	_check(GameState.save_career(), "A mid-season career saves")
	_check(GameState.has_saved_career(), "The save file exists")
	var meta := GameState.saved_career_meta()
	_check(str(meta.get("club", "")) == "GEE" and str(meta.get("stage", "")) == "Round 4",
			"The save header names the club and round (%s)" % str(meta))

	GameState.advance()
	var played_live := _round_sig(GameState.last_results)
	var ladder_live := _ladder_sig()

	_check(GameState.load_career(), "The save loads")
	_check(GameState.season.round_index == round_before, "The round pointer is restored")
	_check(_ladder_sig() == ladder_before, "The ladder is restored")
	_check(GameState.season_log.size() == log_before, "The season log is restored")
	_check(is_same(GameState.my_list, GameState.season.lists["GEE"]),
			"Your list is the season's list again, not a copy")
	GameState.advance()
	_check(_round_sig(GameState.last_results) == played_live,
			"The next round replays identically after loading")
	_check(_ladder_sig() == ladder_live, "The ladder after that round matches too")


func _test_training_survives() -> void:
	_new_season()
	GameState.advance()
	var p: Dictionary = GameState.my_list[0]
	var id := str(p["id"])
	p["xp"] = 500
	var r := GameState.train_stat(id, "marking", 3)
	_check(bool(r.get("ok", false)), "Training spends XP")
	var marking := int(p["attr"]["marking"])
	var xp := int(p["xp"])
	GameState.save_career()
	GameState.load_career()
	var q := GameState.list_player(id)
	_check(int(q["attr"]["marking"]) == marking, "Trained attributes survive a reload")
	_check(int(q["xp"]) == xp, "Banked XP survives a reload")
	var in_season := {}
	for sp in GameState.season.lists["GEE"]:
		if str(sp["id"]) == id:
			in_season = sp
	_check(is_same(in_season, q), "The trained player is one shared dict after loading")


func _test_no_save_mid_match() -> void:
	_new_season()
	GameState.advance()
	GameState.save_career()
	var saved_round := str(GameState.saved_career_meta().get("stage", ""))
	GameState.autosave_enabled = true
	_check(GameState.prepare_interactive_match(), "A live match is prepared")
	_check(not GameState.autosave(), "Autosave refuses while a live match is half played")
	GameState.autosave_enabled = false
	_check(str(GameState.saved_career_meta().get("stage", "")) == saved_round,
			"The pre-match save is kept")
	GameState.load_career()
	_check(GameState.pending_match.is_empty(), "Loading never restores a half-played match")
	_check(GameState.prepare_interactive_match(), "The round can be played again after loading")


func _test_mid_draft_round_trip() -> void:
	GameState.reset()
	GameState.begin_draft()
	var draft: Draft = GameState.draft
	draft.start_for_user("COL")
	for i in range(3):
		var board: Array = draft.board("", "", "", "overall", true)
		if not board.is_empty() and draft.is_user_turn():
			draft.pick(board[0])
	var history := draft.pick_history.size()
	var pick_index := draft.pick_index
	var mine := draft.list().size()
	var spend: int = draft.spent()
	_check(GameState.save_career(), "A draft in progress saves")
	_check(GameState.load_career(), "The draft loads")
	var d2: Draft = GameState.draft
	_check(d2 != null and d2.league_mode, "The league draft is restored")
	_check(d2.user_club == "COL", "Your club is restored")
	_check(d2.pick_history.size() == history and d2.pick_index == pick_index,
			"Pick history and pick pointer are restored")
	_check(d2.list().size() == mine and d2.spent() == spend, "Your picks and spend are restored")
	var first: Dictionary = d2.pick_history[0]
	_check(not d2.pick_details(str(first["player_id"])).is_empty(),
			"Pick details resolve after loading")
	var picked_ok := true
	for code in d2.club_lists:
		for p in d2.club_lists[code]:
			if not is_same(d2.picked.get(str(p["id"])), p):
				picked_ok = false
	_check(picked_ok, "Drafted players are the same dicts in lists and the picked table")
	# Finish the draft from the loaded state and start the season.
	while not d2.is_finished():
		if d2.is_user_turn():
			var board2: Array = d2.board("", "", "", "overall", true)
			if board2.is_empty() or not d2.pick(board2[0]):
				break
		else:
			d2.auto_until_user_turn()
	_check(d2.is_finished(), "A loaded draft can be completed")
	GameState.start_season("COL", d2.list())
	_check(GameState.season != null and GameState.season.lists["COL"].size() == d2.list().size(),
			"The season starts from the loaded draft")


func _test_intake_and_second_season() -> void:
	_new_season("ADE")
	GameState.season.round_index = GameState.season.fixture.size()
	_check(GameState.begin_intake_draft(), "The intake opens")
	var draft: Draft = GameState.draft
	var logged := draft.pick_history.size()
	_check(GameState.save_career(), "An intake draft in progress saves")
	_check(GameState.load_career(), "The intake draft loads")
	draft = GameState.draft
	_check(draft != null and draft.intake_mode, "Intake mode is restored")
	_check(draft.pick_history.size() == logged, "Intake picks are restored")
	var linked := true
	for code in GameDB.CLUB_ORDER:
		if not is_same(GameState.league_lists[code], GameState.season.lists[code]):
			linked = false
	_check(linked, "League lists are the season's lists again after loading")
	while not draft.is_finished():
		var c := draft._best_ai_pick(draft.current_club())
		if c.is_empty() or not draft._draft_pick(draft.current_club(), c):
			draft._skip_current_pick()
	_check(GameState.finish_intake_draft(), "The loaded intake commits")
	_check(GameState.season_year == 2027, "The career rolls to 2027")

	var late := GameDB.late_draftees.size()
	var alias_next: int = GameDB._alias_next
	var pool := GameState.draftee_pool.size()
	GameState.advance()
	GameState.advance()
	var ladder := _ladder_sig()
	_check(GameState.save_career(), "A second-season career saves")
	_check(GameState.load_career(), "The second season loads")
	_check(GameState.season_year == 2027, "The year is restored")
	_check(_ladder_sig() == ladder, "The 2027 ladder is restored")
	_check(GameDB.late_draftees.size() == late, "Generated draft classes are restored")
	_check(GameDB._alias_next == alias_next, "The fictional-name cursor is restored")
	_check(GameState.draftee_pool.size() == pool, "The prospect pool is restored")
	var shared := true
	for p in GameState.draftee_pool:
		var in_db := false
		for q in GameDB.late_draftees:
			if is_same(p, q):
				in_db = true
		for q in GameDB.draftees:
			if is_same(p, q):
				in_db = true
		if not in_db:
			shared = false
	_check(shared, "Prospects are shared between the pool and GameDB after loading")
	var mine_linked := false
	for code in GameState.league_lists:
		if is_same(GameState.my_list, GameState.league_lists[code]):
			mine_linked = true
	_check(mine_linked, "Your list is linked to the league lists after a rollover reload")
	GameState.advance()
	_check(GameState.season.round_index == 3, "The loaded second season keeps playing")


func _test_bad_file_is_ignored() -> void:
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_var({"version": 999, "state": {}})
	f.close()
	_check(not GameState.load_career(), "A save from another version is not loaded")
	_check(GameState.saved_career_meta().is_empty(), "Its header is ignored too")
