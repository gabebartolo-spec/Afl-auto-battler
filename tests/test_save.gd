extends RefCounted
## Career save regression suite. A save must reload into the same career:
## same lists, ladder, fixture position and draft, with shared player dicts
## still shared, so the next round plays out identically either way.
## Run through tests/run_save_tests.gd (which points saves at a test file).

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_test_mid_season_round_trip()
	_test_reload_plays_like_straight()
	_test_market_opens_fresh()
	_test_second_offseason_after_reload()
	_test_second_career_plays_like_first()
	_test_reload_before_offseason()
	_test_review_after_reload()
	_test_training_survives()
	_test_adjusted_players_survive()
	_test_no_save_mid_match()
	_test_mid_draft_round_trip()
	_test_intake_and_second_season()
	_test_bad_file_is_ignored()
	_test_old_club_code_migrates()
	_test_safe_replacement()
	_test_fictional_identity()
	_test_apostrophe_names()
	_test_career_facts()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
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


## A career saved and reloaded after round 5 plays rounds 6-10 exactly as one
## played straight through (qa, 2026-10-11). Past rounds are compared by score
## only: the save keeps a slim copy of a played match on purpose (the box, not
## the timeline), so a whole-result hash of rounds 1-5 always differs.
func _test_reload_plays_like_straight() -> void:
	var straight := _ten_rounds(-1)
	var reloaded := _ten_rounds(5)
	_check(straight["rounds"] == reloaded["rounds"],
			"Every score in rounds 1-10 matches after a reload at round 5")
	_check(straight["ladder"] == reloaded["ladder"], "The round-10 ladder matches after a reload")
	_check(straight["players"] == reloaded["players"],
			"Every player (fitness, form, injuries, ratings) matches after a reload")
	_check(straight["teams"] == reloaded["teams"], "The clubs' season figures match after a reload")
	# Season stats: counts exact; metres gained and distance run are saved in
	# whole metres, so a reloaded total may differ by under one metre.
	var bad := ""
	var a: Dictionary = straight["stats"]
	var b: Dictionary = reloaded["stats"]
	for id in a:
		var sa: Dictionary = (a[id] as Dictionary).get("s", {})
		var sb: Dictionary = (b.get(id, {}) as Dictionary).get("s", {})
		if int(a[id].get("games", 0)) != int(b.get(id, {}).get("games", -1)):
			bad = "%s games" % id
		for k in sa:
			var tol := 0.51 if k in ["metres_gained", "distance_run"] else 0.001
			if absf(float(sa[k]) - float(sb.get(k, 0.0))) > tol:
				bad = "%s %s" % [id, k]
	_check(bad == "" and a.size() == b.size(), "Season stats match after a reload (%s)" % bad)


## The off-season market opens from the lists as they are, never from the last
## market's signings (qa, 2026-10-11: a second career in one process, or a
## career reloaded before the off-season, played a different off-season).
func _test_market_opens_fresh() -> void:
	_new_season("MEL")
	while not GameState.season.is_season_over():
		GameState.advance()
	_check(GameState.save_career(), "(setup) the finished season saves")
	# Stale signings from a market long closed, as a last career would leave.
	var stale := {}
	for code in GameState.season.lists:
		stale[str(code)] = 2
	GameState._targets_signed = stale.duplicate()
	GameState.open_offseason()
	var with_stale := _market_sig()
	GameState.load_career()
	# The save does not keep them: a career loaded in a fresh game has none.
	GameState._targets_signed = {}
	GameState.open_offseason()
	var reloaded := _market_sig()
	_check(with_stale != "" and with_stale == reloaded,
			"The market opens the same after a reload as with a last market's signings left over")
	GameState._targets_signed = stale.duplicate()
	GameState.market_stats = {"improve": 3}
	GameState._bars = {"MEL": {}}
	GameState.reset()
	_check(GameState._targets_signed.is_empty() and GameState.market_stats.is_empty() and GameState._bars.is_empty()
			and CoachEffects.table.is_empty(), "A new career starts with no market or coaching tables from the last")


## Every free agent's offers as the market opens: who, how much, how long.
func _market_sig() -> String:
	var parts := []
	for p in GameState.free_agents:
		var offers := []
		for o in p.get("offers", []):
			offers.append("%s %d %d" % [str(o["club"]), int(o["salary"]), int(o["years"])])
		parts.append("%s:%s" % [str(p.get("id", "")), ",".join(offers)])
	return "|".join(parts)
## "Review match" after a reload shows what the player saw at full time
## (qa, 2026-10-11): the key match-ups, your synergies, the injuries and the
## coach's report, line for line, for several rounds.
func _test_review_after_reload() -> void:
	_new_season("MEL")
	var bad := []
	var checked := 0
	for i in range(4):
		GameState.advance()
		var before := _review_text(GameState.last_match)
		GameState.save_career()
		GameState.load_career()
		var after := _review_text(GameState.last_match)
		checked += 1
		for k in before:
			if str(before[k]) != str(after.get(k, "")):
				bad.append("round %d %s" % [i + 1, k])
	_check(bad.is_empty() and checked == 4, "Review match reads the same after a reload (%s)" % ", ".join(bad))


## Every block of the full-time review MatchScene builds from the result.
func _review_text(res: Dictionary) -> Dictionary:
	if res.is_empty():
		return {}
	var me := 0 if str(res.get("home", "")) == GameState.my_club else 1
	return {
		"factors": MatchNotes.match_factors(res, me),
		"ours": MatchNotes.standouts(res, me, 3),
		"theirs": MatchNotes.standouts(res, 1 - me, 1),
		"report": CoachReport.glance(CoachReport.match_report(res, me), true),
		"matchups": MatchNotes.interceptor_story(res, me) + MatchNotes.duel_story(res, me),
		"synergies": MatchNotes.synergy_lines(res, me),
		"stats": MatchNotes.key_stats(res, me),
		"payoffs": GameState.payoff_lines(res),
	}


## A career saved in season 2 and loaded in a fresh game plays the second
## off-season and season 3 as one played straight through (qa, 2026-10-11:
## the free-agency signings were never saved, and the second off-season
## opened from last year's).
func _test_second_offseason_after_reload() -> void:
	_new_season("MEL")
	_play_offseason()
	for i in range(5):
		GameState.advance()
	_check(GameState.save_career(), "(setup) a season-2 career saves")
	var straight := _through_second_offseason()
	_check(GameState.load_career(), "(setup) the season-2 save loads")
	# A fresh game: nothing the save does not keep.
	GameState._targets_signed = {}
	GameState.market_stats = {}
	GameState._bars = {}
	var reloaded := _through_second_offseason()
	var bad := []
	for k in straight:
		if str(straight[k]) != str(reloaded.get(k, "")):
			bad.append(k)
	_check(bad.is_empty(), "Saved in season 2 and loaded fresh, the second off-season and season 3 play the same (%s)" % ", ".join(bad))


func _play_offseason() -> void:
	while not GameState.season.is_season_over():
		GameState.advance()
	GameState.open_offseason()
	if GameState.begin_intake_draft():
		var d: Draft = GameState.draft
		var guard := 0
		while not d.is_finished() and guard < 5000:
			guard += 1
			var c: Dictionary = d._best_ai_pick(d.current_club())
			if c.is_empty() or not d._draft_pick(d.current_club(), c):
				d._skip_current_pick()
		GameState.finish_intake_draft()
	else:
		GameState.start_next_season()


func _through_second_offseason() -> Dictionary:
	_play_offseason()
	var rounds := []
	for i in range(2):
		GameState.advance()
		rounds.append(_round_sig(GameState.last_results))
	var lists := []
	for code in GameState.season.lists:
		var ids := []
		for p in GameState.season.lists[code]:
			ids.append(str(p.get("id", "")))
		ids.sort()
		lists.append("%s:%s" % [code, ",".join(ids)])
	return {"year": GameState.season_year, "rounds": rounds, "lists": lists,
			"offseason_log": str(GameState.offseason_log)}


## A second career in one process plays exactly like the first from the same
## seed, through season 2 round 3 (dev-sim, 2026-10-12: the second career's
## draft class and lists differed because caches built mid-career in the
## first were never cleared when a new career started, and the career seed
## is pinned here because reset() draws one from the clock).
func _test_second_career_plays_like_first() -> void:
	var first := _career_trace()
	# What a game that loaded a save mid-career leaves behind: the caches built
	# from the players as they stand now, not as the 2026 data has them.
	Prospects.forget_cache()
	Prospects.generate_class(GameState.season_year, 7)
	StoryDeck.all()
	var second := _career_trace()
	var bad := []
	for k in first:
		if str(first[k]) != str(second.get(k, "")):
			bad.append(k)
	_check(first.size() >= 11 and bad.is_empty(),
			"A second career with the same seed plays season 1 to season 2 round 3 as the first did (%s)" % ", ".join(bad))


## A career saved at the end of the season and loaded plays the off-season, the
## intake draft and season 2 round 3 as one played straight through.
func _test_reload_before_offseason() -> void:
	_new_season("MEL")
	while not GameState.season.is_season_over():
		GameState.advance()
	_check(GameState.save_career(), "(setup) the finished season saves")
	var straight := _offseason_trace()
	_check(GameState.load_career(), "(setup) the finished season loads")
	var reloaded := _offseason_trace()
	var bad := []
	for k in straight:
		if str(straight[k]) != str(reloaded.get(k, "")):
			bad.append(k)
	_check(straight.size() >= 10 and bad.is_empty(),
			"Saved before the off-season and loaded, the market, draft class, lists and season 2 round 3 play the same (%s)" % ", ".join(bad))


## One whole career from the seed: season 1, the off-season, season 2 round 3.
func _career_trace() -> Dictionary:
	GameState.reset()
	# reset() draws a fresh career seed from the clock; pin it before the
	# first draft class is made from it.
	GameState.career_seed = 4242
	GameState.start_season("MEL", GameDB.club_list("MEL"))
	var rounds := []
	while not GameState.season.is_season_over():
		GameState.advance()
		rounds.append(_round_sig(GameState.last_results))
	var out := _offseason_trace()
	out["s1_rounds"] = rounds
	return out


## From a finished season: the market as it opens, the draft class, the lists
## after the intake, and the first three rounds of the next season.
func _offseason_trace() -> Dictionary:
	GameState.open_offseason()
	var out := {"market": _market_sig()}
	if GameState.begin_intake_draft():
		var pool := []
		for p in GameState.draftee_pool:
			pool.append("%s:%s:%s" % [str(p.get("id", "")), str(p.get("overall", "")), str(p.get("potential", ""))])
		out["draft_class"] = pool
		var d: Draft = GameState.draft
		var guard := 0
		while not d.is_finished() and guard < 5000:
			guard += 1
			var c: Dictionary = d._best_ai_pick(d.current_club())
			if c.is_empty() or not d._draft_pick(d.current_club(), c):
				d._skip_current_pick()
		GameState.finish_intake_draft()
	else:
		GameState.start_next_season()
	var lists := []
	for code in GameState.season.lists:
		var ids := []
		for p in GameState.season.lists[code]:
			ids.append("%s:%s:%s" % [str(p.get("id", "")), str(p.get("overall", "")), str(p.get("potential", ""))])
		lists.append("%s:%s" % [code, ",".join(ids)])
	out["lists"] = lists
	# Everything else the next round reads, so a mismatch names its source.
	var players := []
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			var row: Dictionary = (q as Dictionary).duplicate()
			for k in CareerSave.SKIP_PLAYER_KEYS:
				row.erase(k)
			players.append(JSON.stringify(row, "", true))
	out["players_full"] = hash(players)
	out["coaches"] = hash(JSON.stringify(GameState.coaches, "", true))
	out["season_team"] = hash(JSON.stringify(GameState.season_team, "", true))
	out["form_log"] = hash(JSON.stringify(GameState.form_log, "", true))
	out["fixture"] = hash(str(GameState.season.fixture))
	out["offseason_log"] = str(GameState.offseason_log)
	var rounds := []
	for i in range(3):
		GameState.advance()
		rounds.append(_round_sig(GameState.last_results))
	out["s2_rounds"] = rounds
	out["ladder"] = _ladder_sig()
	return out


func _ten_rounds(save_after: int) -> Dictionary:
	_new_season("MEL")
	while GameState.season.results.size() < 10:
		if GameState.season.results.size() == save_after:
			GameState.save_career()
			GameState.load_career()
		GameState.advance()
	var rounds := []
	for r in GameState.season.results:
		rounds.append(_round_sig(r))
	var players := []
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			# Less the derived caches the save skips on purpose (rebuilt on use).
			var row: Dictionary = (p as Dictionary).duplicate()
			for k in CareerSave.SKIP_PLAYER_KEYS:
				row.erase(k)
			players.append(JSON.stringify(row, "", true))
	return {"rounds": rounds, "ladder": _ladder_sig(), "players": players,
			"teams": JSON.stringify(GameState.season_team, "", true),
			"stats": GameState.season_stats.duplicate(true)}


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
	# A look chosen in Club Forge is part of the player and comes back as set.
	# "freckles" is from an older save (freckles are gone): it loads and is
	# ignored.
	var look := {"skin": 4, "hair": 0, "hair_style": "mullet", "beard": "full_beard", "headband": true,
			"tattoos": [{"place": "calf_l", "design": "design_3"}], "freckles": 1}
	GameState.list_player(id)["look"] = look.duplicate(true)
	GameState.save_career()
	GameState.load_career()
	var full := GameDB.player_appearance(GameState.list_player(id))
	_check(full["hair_style"] == "mullet" and full["beard"] == "full_beard" and bool(full["headband"])
			and int(full["skin"]) == 4 and (full["tattoos"] as Array).size() == 1,
			"A chosen look survives a reload")
	_check(not full.has("freckles"), "An old save's freckles load cleanly and are dropped")


## The director's named-player corrections (Ratings.ATTR_ADJUSTMENTS) are in the
## attributes a career saves, so a reload gives back exactly what was saved: the
## correction is not applied again, and an older career keeps what it saved.
func _test_adjusted_players_survive() -> void:
	_new_season()
	GameState.advance()
	var names := {}
	for key in Ratings.ATTR_ADJUSTMENTS:
		names[str(key).split("|")[1]] = true
	var before := {}
	for p in GameDB.players:
		var who := "%s %s" % [p["first"], p["last"]]
		if names.has(who):
			var live: Dictionary = GameState._find_player(str(p["id"]))
			if not live.is_empty():
				before[who] = {"id": str(p["id"]), "attr": (live["attr"] as Dictionary).duplicate(),
						"overall": int(live["overall"]), "potential": int(live["potential"])}
	GameState.save_career()
	GameState.load_career()
	for who in names:
		var was: Dictionary = before.get(who, {})
		var q: Dictionary = GameState._find_player(str(was.get("id", "")))
		_check(not was.is_empty() and not q.is_empty() and q["attr"] == was["attr"]
				and int(q["overall"]) == int(was["overall"]) and int(q["potential"]) == int(was["potential"]),
				"%s's corrected attributes and POT survive a reload exactly" % who)


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
			# The best player the cap allows (the top of the board can be
			# unaffordable late in the draft).
			var choice := {}
			for cand in d2.board("", "", "", "overall", true):
				if d2.can_pick_player(cand):
					choice = cand
					break
			if choice.is_empty() or not d2.pick(choice):
				break
		else:
			d2.auto_until_user_turn()
	_check(d2.is_finished(), "A loaded draft can be completed")
	GameState.start_season("COL", d2.list())
	_check(GameState.season != null and GameState.season.lists["COL"].size() == d2.list().size(),
			"The season starts from the loaded draft")


func _test_intake_and_second_season() -> void:
	_new_season("ADE")
	var first_year := int(GameState.season_year)
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.rising_star_noms = {"from": 1, "rounds": [{"round": 3, "id": "last_year", "club": "ADE"}]}
	var vet := str(GameState.my_list[0]["id"])
	CareerFacts.add(GameState.career_facts, vet, CareerFacts.row(first_year, "Round 9", "injury", "ADE", "", "calf"))
	var vet_facts := str(CareerFacts.of(GameState.career_facts, vet))
	_check(GameState.begin_intake_draft(), "The intake opens")
	var draft: Draft = GameState.draft
	var logged := draft.pick_history.size()
	_check(GameState.save_career(), "An intake draft in progress saves")
	_check(GameState.load_career(), "The intake draft loads")
	draft = GameState.draft
	_check(draft != null and draft.intake_mode, "Intake mode is restored")
	_check(draft.pick_history.size() == logged, "Intake picks are restored")
	var linked := true
	for code in GameState.season.lists:
		if not is_same(GameState.league_lists.get(code), GameState.season.lists[code]):
			linked = false
	_check(linked, "League lists are the season's lists again after loading")
	while not draft.is_finished():
		var c := draft._best_ai_pick(draft.current_club())
		if c.is_empty() or not draft._draft_pick(draft.current_club(), c):
			draft._skip_current_pick()
	_check(GameState.finish_intake_draft(), "The loaded intake commits")
	_check(GameState.season_year == first_year + 1, "The career rolls into the next season")
	_check(str(CareerFacts.of(GameState.career_facts, vet)) == vet_facts,
			"Career facts carry through the rollover unchanged")
	_check(int(GameState.rising_star_noms.get("from", 0)) == 1 and (GameState.rising_star_noms["rounds"] as Array).is_empty(),
			"Last season's Rising Star nominations stay behind at the rollover")

	var late := GameDB.late_draftees.size()
	var alias_next: int = GameDB._alias_next
	var pool := GameState.draftee_pool.size()
	GameState.advance()
	GameState.advance()
	var ladder := _ladder_sig()
	_check(GameState.save_career(), "A second-season career saves")
	_check(GameState.load_career(), "The second season loads")
	_check(GameState.season_year == first_year + 1, "The year is restored")
	var noms: Array = GameState.rising_star_noms["rounds"]
	_check(noms.size() == 2 and int(noms[0]["round"]) == 1 and int(noms[1]["round"]) == 2,
			"The second season's Rising Star nominations are recorded and restored")
	_check(_ladder_sig() == ladder, "The second season's ladder is restored")
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
	GameState.delete_saved_career()  # no backup to recover from
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_var({"version": 999, "state": {}})
	f.close()
	_check(not GameState.load_career(), "A save from another version is not loaded")
	_check(GameState.saved_career_meta().is_empty(), "Its header is ignored too")


## St Kilda was saved as SKN before it became STK: an old career loads into
## the same St Kilda - list, ids, ladder and header - under STK.
func _test_old_club_code_migrates() -> void:
	GameState.reset()
	GameState.start_season("STK", GameDB.club_list("STK"))
	GameState.advance()
	GameState.advance()
	var ladder := _ladder_sig()
	var ids := GameState.my_list.map(func(p): return str(p["id"]))
	_check(GameState.save_career(), "A St Kilda career saves")
	# Write it back the way an older build did: every STK as SKN.
	var old_state = _to_old(CareerSave.read(GameState.save_path))
	var old_meta = _to_old(CareerSave.read_meta(GameState.save_path))
	_check(var_to_str(old_state).contains("SKN_") and not var_to_str(old_state).contains("STK"),
			"The test save really is an old SKN save")
	CareerSave.write(old_state, old_meta, GameState.save_path)
	_check(str(GameState.saved_career_meta().get("club", "")) == "STK", "The menu header reads St Kilda's new code")
	_check(GameState.load_career(), "The old save loads")
	_check(GameState.my_club == "STK" and GameState.season.lists.has("STK") and not GameState.season.lists.has("SKN"),
			"It is St Kilda under STK")
	_check(GameState.my_list.map(func(p): return str(p["id"])) == ids.map(func(i): return str(i)),
			"The same players, with the same ids")
	_check(_ladder_sig() == ladder and not _ladder_sig().contains("SKN"), "The ladder is the same")
	var found := true
	for p in GameState.my_list:
		if not bool(p.get("projected", false)) and GameDB.player_by_id(str(p["id"])) == null:
			found = false
	_check(found, "Every listed player still resolves to his source data")


static func _to_old(v: Variant) -> Variant:
	if v is String:
		var re := RegEx.new()
		re.compile("(?<![A-Za-z])STK(?![A-Za-z])")
		return re.sub(v, "SKN", true)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[_to_old(k)] = _to_old(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x): return _to_old(x))
	if v is PackedStringArray:
		var out := PackedStringArray()
		for x in v:
			out.append(_to_old(x))
		return out
	return v


## A save is never lost to a failed or interrupted write (research G10): the
## previous good save is set aside, not deleted, until the new one is in
## place, and reading recovers the newest good save that survives.
func _test_safe_replacement() -> void:
	var path := "user://test_safe_replacement.save"
	CareerSave.delete(path)
	CareerSave.fail_at = ""
	var a := {"which": "A"}
	var b := {"which": "B"}
	_check(CareerSave.write(a, {}, path) and CareerSave.write(b, {}, path)
			and str(CareerSave.read(path).get("which", "")) == "B", "A normal save replaces the last one")
	_check(FileAccess.file_exists(path + CareerSave.BACKUP_SUFFIX), "The previous good save is kept as a backup")
	# Killed after the new save was written and checked, before the swap.
	CareerSave.delete(path)
	CareerSave.write(a, {}, path)
	CareerSave.fail_at = "after_temp"
	CareerSave.write(b, {}, path)
	CareerSave.fail_at = ""
	_check(str(CareerSave.read(path).get("which", "")) == "B", "Killed before the swap: the checked new save is recovered")
	# Killed after the old save stepped aside: no file at the path at all.
	CareerSave.delete(path)
	CareerSave.write(a, {}, path)
	CareerSave.fail_at = "after_backup"
	CareerSave.write(b, {}, path)
	CareerSave.fail_at = ""
	_check(not FileAccess.file_exists(path) and CareerSave.exists(path)
			and str(CareerSave.read(path).get("which", "")) == "B", "Killed mid-swap: the career is still there")
	# Moving the new save into place fails: the previous one is put back.
	CareerSave.delete(path)
	CareerSave.write(a, {}, path)
	CareerSave.fail_at = "swap"
	var ok := CareerSave.write(b, {}, path)
	CareerSave.fail_at = ""
	DirAccess.remove_absolute(path + CareerSave.TEMP_SUFFIX)
	_check(not ok and str(CareerSave.read(path).get("which", "")) == "A", "A failed swap reports failure and keeps the previous save")
	# The same failure with the new save left in the temp file, as a real one
	# would: the newer save is still recovered, and the career still exists.
	CareerSave.delete(path)
	CareerSave.write(a, {}, path)
	CareerSave.fail_at = "swap"
	CareerSave.write(b, {}, path)
	CareerSave.fail_at = ""
	_check(CareerSave.exists(path) and str(CareerSave.read(path).get("which", "")) == "B",
			"A failed swap leaves the newer save in the temp file, and it is the one read")
	# The save itself is corrupt: the previous good one is read instead.
	CareerSave.delete(path)
	CareerSave.write(a, {}, path)
	CareerSave.write(b, {}, path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	_check(str(CareerSave.read(path).get("which", "")) == "A", "A corrupt save falls back to the previous good one")
	CareerSave.delete(path)
	_check(not CareerSave.exists(path) and not FileAccess.file_exists(path + CareerSave.BACKUP_SUFFIX),
			"Deleting a career removes its backup too")


## FL-005: a generated player's nickname and interest are cosmetic, the same
## every time from his id, none for real players, and a nickname you change or
## remove stays that way through a save.
## Real surnames keep their apostrophe in every data file that keys a player by
## name (O'Sullivan, D'Ambrosio), so his look and his home state find him.
func _test_apostrophe_names() -> void:
	var dashed := 0
	var lost := []
	var balyn := {}
	for code in GameDB.clubs:
		for p in GameDB.club_list(str(code)):
			var last := str(p.get("last", ""))
			if last.contains("'"):
				dashed += 1
			var rx := RegEx.create_from_string("^[OD][A-Z][a-z]+$")
			if rx.search(last) != null:
				lost.append("%s %s" % [p.get("first", ""), last])
			if str(p.get("first", "")) == "Balyn" and last == "O'Brien":
				balyn = p
	_check(dashed == 12, "Twelve real players carry an apostrophe in their surname (%d)" % dashed)
	_check(lost.is_empty(), "No real surname has lost its apostrophe (%s)" % str(lost))
	var was_real: bool = GameState.show_real_names
	GameState.show_real_names = true
	_check(not balyn.is_empty() and GameDB.player_display_name(balyn) == "Balyn O'Brien",
			"A real O' name is shown with its apostrophe (%s)" % GameDB.player_display_name(balyn))
	GameState.show_real_names = was_real
	_check(not balyn.is_empty() and GameDB.player_looks(balyn) != Appearance.UNCURATED
			and str(balyn.get("home_state", "")) == "SA",
			"His curated look and his home state still find him")
	var old_save: Dictionary = balyn.duplicate()
	old_save["last"] = "OBrien"
	_check(GameDB.player_looks(old_save) == GameDB.player_looks(balyn),
			"A career saved before the apostrophe still finds his look")
	var back = JSON.parse_string(JSON.stringify(balyn))
	_check(back is Dictionary and str(back.get("last", "")) == "O'Brien", "The apostrophe survives a save round trip")


func _test_fictional_identity() -> void:
	var gen := []
	for k in range(400):
		gen.append({"id": "fl5_%d" % k, "first": "Sam",
				"last": str(GameDB.FICTIONAL_LAST_NAMES[k % GameDB.FICTIONAL_LAST_NAMES.size()]), "generated": true})
	var nicks := 0
	var interests := 0
	var stable := true
	for p in gen:
		var before := str(p)
		var n := FictionalIdentity.nickname(p)
		if n != "":
			nicks += 1
		if FictionalIdentity.interest(p) != "":
			interests += 1
		var moved: Dictionary = p.duplicate()
		moved["club"] = "COL"
		if FictionalIdentity.nickname(moved) != n or str(p) != before:
			stable = false
	_check(nicks > 60 and nicks < 160 and interests > 150 and interests < 290,
			"Some generated players have a nickname or an interest, not all (%d and %d of 400)" % [nicks, interests])
	_check(stable, "They come from his id alone: the same after a move, and reading them changes nothing")
	var real: Dictionary = GameDB.club_list("GEE")[0]
	_check(FictionalIdentity.nickname(real) == "" and FictionalIdentity.interest(real) == "",
			"A real player is given no invented nickname or interest")
	# Favourite club growing up: every generated kid has one, mostly from his own
	# state, the same after a move; a real player's is only ever a sourced fact.
	var fav_ok := true
	var home := 0
	var vics := 0
	for p in gen:
		var q: Dictionary = p.duplicate()
		q["state"] = "WA" if int(str(p["id"]).trim_prefix("fl5_")) % 2 == 0 else "VIC"
		var fc := FictionalIdentity.favourite_club(q)
		var moved: Dictionary = q.duplicate()
		moved["club"] = "ESS"
		if fc == "" or not TradeRequests.CLUB_STATES.has(fc) or FictionalIdentity.favourite_club(moved) != fc:
			fav_ok = false
		if q["state"] == "WA":
			if str(TradeRequests.CLUB_STATES.get(fc, "")) == "WA":
				home += 1
		else:
			vics += 1
	_check(fav_ok, "Every generated player has a favourite club, the same after a move")
	_check(home > 100 and home < 190, "Most WA kids grew up following a WA club, not all (%d of 200)" % home)
	var unsourced: Dictionary = real.duplicate()
	unsourced["dob"] = "1900-01-01"   # no row in the sourced file matches him
	_check(FictionalIdentity.favourite_club(unsourced) == "",
			"A real player's favourite club is never guessed (Not recorded without a source)")
	var moore := {}
	for p in GameDB.club_list("COL"):
		if str(p.get("first", "")) == "Darcy" and str(p.get("last", "")) == "Moore":
			moore = p
	_check(not moore.is_empty() and FictionalIdentity.favourite_club(moore) == "COL",
			"A sourced real player shows the club he grew up following (Darcy Moore: Collingwood)")
	var made: Dictionary = gen[0].duplicate()
	made["user_created"] = true
	_check(FictionalIdentity.favourite_club(made) == "",
			"A player created in an older save, who never chose one, shows Not recorded")
	_new_season()
	var mine: Dictionary = GameState.my_list[0]
	var name_before := GameDB.player_display_name(mine)
	_check(GameState.set_player_nickname(str(mine["id"]), "  Moz ") == "Moz"
			and GameDB.player_display_name(mine) == name_before,
			"A nickname can be set; the full name stays his name")
	GameState.save_career()
	GameState.load_career()
	mine = GameState.list_player(str(mine["id"]))
	_check(FictionalIdentity.nickname(mine) == "Moz", "The nickname survives a save")
	GameState.set_player_nickname(str(mine["id"]), "")
	GameState.save_career()
	GameState.load_career()
	_check(FictionalIdentity.nickname(GameState.list_player(str(mine["id"]))) == "",
			"Removing it costs nothing and it stays removed")


## G7: career facts (CareerFacts) are written when they happen and kept by
## player id, so a save, an old save, a nickname, a club move and leaving the
## game all leave them as they were - and a player who has gone is still named.
func _test_career_facts() -> void:
	_new_season()
	GameState.advance()
	GameState.advance()
	var logged := 0
	var shaped := true
	for id in GameState.career_facts:
		for f in CareerFacts.of(GameState.career_facts, str(id), "injury"):
			logged += 1
			if int(f["y"]) != GameState.season_year or not str(f["at"]).begins_with("Round") 					or str(f["club"]) == "" or str(f["out"]) == "":
				shaped = false
	_check(logged > 0 and shaped,
			"Injuries become career facts with the season, the round, his club and what it was (%d)" % logged)
	# An older save kept bare years on the player: they move across once, as
	# they were, with nothing invented.
	var p: Dictionary = GameState.my_list[0]
	var pid := str(p["id"])
	var had := CareerFacts.of(GameState.career_facts, pid).size()
	p["injury_log"] = [GameState.season_year - 1, GameState.season_year - 1]
	_check(GameState.save_career() and GameState.load_career(), "A career with an old injury record saves and loads")
	p = GameState.list_player(pid)
	var mine := CareerFacts.of(GameState.career_facts, pid)
	_check(mine.size() == had + 2 and not p.has("injury_log")
			and str(mine[-1]["at"]) == "" and str(mine[-1]["club"]) == "" and str(mine[-1]["out"]) == "",
			"An old save's injury years become facts once, with no round, club or kind made up")
	GameState._migrate_injury_logs()
	_check(CareerFacts.of(GameState.career_facts, pid).size() == had + 2, "Moving them is done once")
	# An unlinked list can hold a separate copy of the same player: his years
	# still move once, never twice (the retirement talk would double-count).
	var twin_id := str(GameState.my_list[1]["id"])
	var twin_had := CareerFacts.of(GameState.career_facts, twin_id).size()
	var twin: Dictionary = GameState.my_list[1]
	var copy: Dictionary = twin.duplicate(true)
	twin["injury_log"] = [GameState.season_year]
	copy["injury_log"] = [GameState.season_year]
	GameState.free_agents.append(copy)
	GameState._migrate_injury_logs()
	GameState.free_agents.erase(copy)
	_check(CareerFacts.of(GameState.career_facts, twin_id).size() == twin_had + 1
			and not twin.has("injury_log") and not copy.has("injury_log"),
			"A player held twice as separate copies has his old injuries moved once")
	_check(Retirement.recent_injuries(p, GameState.season_year, GameState.career_facts) >= 2,
			"The retirement talk still counts his recent injuries")
	var sig := str(GameState.career_facts)
	_check(GameState.save_career() and GameState.load_career() and str(GameState.career_facts) == sig,
			"Career facts come back from a save exactly")
	p = GameState.list_player(pid)
	GameState.set_player_nickname(pid, "Gus")
	_check(str(GameState.career_facts) == sig, "A nickname changes no fact")
	# A club move: the facts stay his, each with the club he was at.
	GameState.my_list.erase(p)
	GameState._join("ESS", p)
	_check(str(GameState.career_facts) == sig and str(p["club"]) == "ESS",
			"A move to another club leaves his facts as they were")
	# Leaving the game: a player the database never knew is still named, and
	# his facts stay with his id (a former player who coaches keeps it: C_P_<id>).
	var kid: Dictionary = p.duplicate(true)
	kid["id"] = "g7_kid"
	kid["generic_name"] = "Tom Gone"
	kid["real_name"] = ""
	CareerFacts.add(GameState.career_facts, "g7_kid", CareerFacts.row(GameState.season_year, "Round 2", "injury", "ESS", "", "knee"))
	_check(GameDB.player_display_name_by_id("g7_kid", "nobody") == "nobody", "Before he leaves, an unlisted id has no name")
	GameState._career_over(kid)
	_check(GameDB.player_display_name_by_id("g7_kid", "nobody") == "Tom Gone"
			and CareerFacts.of(GameState.career_facts, "g7_kid").size() == 1,
			"A player who has left the game keeps his name and his facts")
	_check(CoachPathway.cid_for("g7_kid").trim_prefix("C_P_") == "g7_kid",
			"A former player's coach record leads back to his facts by id")
	_check(GameState.save_career() and GameState.load_career()
			and GameDB.player_display_name_by_id("g7_kid", "nobody") == "Tom Gone",
			"His name comes back from a save")
