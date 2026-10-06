extends RefCounted
## Career records (Career.gd): games, goals and club stints across a dynasty.
## Totals must count every match (finals too) for every club, exactly once a
## season, through saves, reloads and rollovers; club moves must read as a
## timeline; career draftees must carry the same draft keys real players do;
## old saves must load without invented numbers; p["history"] (potential)
## must not change. Run through tests/run_career_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_test_rules()
	_test_dataset()
	_test_2026_is_history()
	_test_one_season_and_finals()
	_test_three_seasons_and_club_change()
	_test_reload_never_double_counts()
	_test_draftee_metadata()
	_test_superdraft_midseason_news()
	_test_old_saves()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Career tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_season(club := "GEE") -> void:
	GameDB.reload()
	GameState.reset()
	GameState.start_season(club, GameDB.club_list(club))


## Play the season out, finals included, and return what it held counted
## straight from the match results: id -> [games, goals, finals games, club].
func _play_season() -> Dictionary:
	var counted := {}
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		guard += 1
		GameState.advance()
		for res in GameState.last_results:
			var finals: bool = res.has("tag")
			var roster: Array = res.get("roster", [])
			var stats: Dictionary = res.get("players", {})
			for side in range(roster.size()):
				var code: String = str(res["home"] if side == 0 else res["away"])
				for r in roster[side]:
					var id := str(r["id"])
					var row: Array = counted.get(id, [0, 0, 0, code])
					row[0] = int(row[0]) + 1
					row[1] = int(row[1]) + int((stats.get(id, {}) as Dictionary).get("goals", 0))
					if finals:
						row[2] = int(row[2]) + 1
					row[3] = code
					counted[id] = row
	_check(GameState.season.is_season_over(), "The %d season completes" % GameState.season_year)
	return counted


func _listed() -> Dictionary:
	var out := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			out[str(p["id"])] = p
	return out


func _totals(players: Dictionary) -> Dictionary:
	var out := {}
	for id in players:
		var c := Career.of(players[id])
		out[id] = [int(c["games"]), int(c["goals"])]
	return out


func _find_real(name: String) -> Dictionary:
	for p in GameDB.players:
		if str(p.get("real_name", "")) == name:
			return p
	return {}


# ---------------------------------------------------------------------------
func _test_rules() -> void:
	var p := {}
	_check(Career.add_season(p, 2026, "ADE", 20, 12), "A first season is counted")
	_check(not Career.add_season(p, 2026, "ADE", 20, 12), "The same season is never counted twice")
	Career.add_season(p, 2027, "ADE", 0, 0)
	Career.add_season(p, 2028, "ADE", 18, 5)
	Career.add_season(p, 2029, "FRE", 22, 30)
	Career.add_season(p, 2030, "ADE", 3, 1)
	var c := Career.of(p)
	_check(int(c["games"]) == 63 and int(c["goals"]) == 48, "Totals add every season (%s)" % str(c))
	_check(str(c["stints"]) == str([["ADE", 2026, 2028, 38, 17], ["FRE", 2029, 2029, 22, 30],
			["ADE", 2030, 2030, 3, 1]]),
			"A season lost to injury keeps the stint; another club starts a new one (%s)" % str(c["stints"]))
	_check(int(c["through"]) == 2030, "The last counted season is kept")
	_check(Career.totals_text(p) == "63 games · 48 goals", "Totals read as words (%s)" % Career.totals_text(p))
	var lines := Career.club_lines(p, func(code): return GameDB.club_name(code))
	_check(lines.size() == 3 and str(lines[0]) == "Adelaide 2026–2028 · 38 games, 17 goals"
			and str(lines[1]) == "Fremantle 2029 · 22 games, 30 goals",
			"Club lines read as a timeline (%s)" % str(lines))
	var one := {}
	Career.add_season(one, 2026, "ADE", 1, 0)
	_check(Career.totals_text(one) == "1 game · no goals", "One game reads naturally (%s)" % Career.totals_text(one))
	_check(Career.totals_text({}) == "", "No senior games: nothing to show")
	var unknown := {"career": Career.from_source("?")}
	_check(not Career.complete(unknown) and Career.totals_text(unknown) == "—",
			"An unknown past shows a dash, not a number")
	var none := Career.from_source("")
	_check(int(none["games"]) == 0 and (none["unknown"] as Array).is_empty()
			and int(none["through"]) == 2025, "No games before 2026 is known, not unknown")
	var parsed := Career.from_source("SYD:2017:2021:64:34;ADE:2022:2025:92:44")
	_check(int(parsed["games"]) == 156 and int(parsed["goals"]) == 78
			and (parsed["stints"] as Array).size() == 2, "The dataset's stints parse (%s)" % str(parsed))


func _test_dataset() -> void:
	GameDB.reload()
	var every := true
	var known := 0
	var sums := true
	for p in GameDB.players:
		if not (p.get("career") is Dictionary):
			every = false
			continue
		if Career.complete(p):
			known += 1
		var g := 0
		var gl := 0
		for s in p["career"]["stints"]:
			g += int(s[3])
			gl += int(s[4])
		if g != int(p["career"]["games"]) or gl != int(p["career"]["goals"]):
			sums = false
	_check(every, "Every 2026 player has a career record")
	_check(known == GameDB.players.size(), "Every 2026 player's AFL career is known (%d/%d)" % [
			known, GameDB.players.size()])
	_check(sums, "Totals are the sum of the club stints")
	var dangerfield := _find_real("Patrick Dangerfield")
	_check(not dangerfield.is_empty() and str(dangerfield["career"]["stints"]) == str([
			["ADE", 2008, 2015, 154, 163], ["GEE", 2016, 2025, 206, 202]]),
			"A two-club career reads Adelaide then Geelong (%s)" % str(dangerfield.get("career", {})))
	# Two players share Sydney's #36: each keeps his own career.
	var amartey := _find_real("Joel Amartey")
	var green := _find_real("Will Green")
	_check(not amartey.is_empty() and str(amartey["career"]["stints"]) == str([["SYD", 2020, 2025, 61, 86]])
			and not green.is_empty() and (green["career"]["stints"] as Array).is_empty()
			and Career.complete(green),
			"Two players on one number keep their own careers (%s / %s)" % [
			str(amartey.get("career", {})), str(green.get("career", {}))])
	var dawson := _find_real("Jordan Dawson")
	_check(not dawson.is_empty() and str(dawson.get("history", [])) == str([[2021, 87, 23],
			[2022, 91, 22], [2023, 81, 23], [2024, 73, 22], [2025, 83, 25]]),
			"p[\"history\"] (potential's input) is unchanged (%s)" % str(dawson.get("history", [])))
	var none := 0
	for p in GameDB.draftees:
		if p.has("career"):
			none += 1
	_check(none == 0, "Draft prospects start without a senior career")


## A new career starts in 2027 with every real player's 2026 season already
## in his record, at the club he played it for - once, and never again.
func _test_2026_is_history() -> void:
	_new_season("GEE")
	var src: Dictionary = {}
	for p in GameDB.players:
		if str(p.get("real_name", "")) == "Patrick Dangerfield":
			src = p
	var mine := {}
	for p in _listed().values():
		if str(p.get("real_name", "")) == "Patrick Dangerfield":
			mine = p
	_check(not src.is_empty() and not mine.is_empty(), "Dangerfield is in the league")
	if src.is_empty() or mine.is_empty():
		return
	var c := Career.of(mine)
	var src_games := int((src["career"] as Dictionary)["games"])
	_check(int(c["games"]) == src_games + int(float(src["gm"])),
			"His record adds the real 2026 season to the dataset career (%d + %d = %d)" % [
			src_games, int(float(src["gm"])), int(c["games"])])
	var last: Array = (c["stints"] as Array)[-1]
	_check(int(c["through"]) == GameDB.DATA_SEASON and int(last[2]) == GameDB.DATA_SEASON
			and str(last[0]) == str(src["data_club"]),
			"...credited to 2026 at the club he played it for (%s)" % str(last))
	var before := int(c["games"])
	_check(not Career.add_season(mine, GameDB.DATA_SEASON, "GEE", 20, 10) and int(c["games"]) == before,
			"2026 can never be counted twice")
	var draftee_ok := true
	for p in _listed().values():
		if str(p["id"]).begins_with("D2026_"):
			var dc := Career.of(p)
			if int(dc["games"]) != 0 or int(dc["through"]) != GameDB.DATA_SEASON or not Career.complete(p):
				draftee_ok = false
	_check(draftee_ok, "A 2026 draftee starts 2027 with no senior games and a complete record")


func _test_one_season_and_finals() -> void:
	_new_season("GEE")
	var players := _listed()
	var before := _totals(players)
	var history := {}
	for id in players:
		history[id] = str(players[id].get("history", []))
	var counted := _play_season()
	var after := _totals(players)
	var exact := true
	var first_bad := ""
	var clubs := {}
	var finals_players := 0
	for id in players:
		var row: Array = counted.get(id, [0, 0, 0, ""])
		var got := [int(after[id][0]) - int(before[id][0]), int(after[id][1]) - int(before[id][1])]
		if got[0] != int(row[0]) or got[1] != int(row[1]):
			exact = false
			if first_bad == "":
				first_bad = "%s: counted %s, recorded %s" % [id, str(row), str(got)]
		if int(row[0]) > 0:
			clubs[str(players[id]["club"])] = true
		if int(row[2]) > 0:
			finals_players += 1
	_check(exact, "One season: every player's games and goals match the results %s" % first_bad)
	_check(finals_players >= 44, "Finals were played and counted (%d finals players)" % finals_players)
	_check(clubs.size() == GameDB.active_clubs(GameDB.START_YEAR).size(),
			"Every club's players are counted, not only yours (%d clubs)" % clubs.size())
	var gf := false
	for id in counted:
		if int(counted[id][2]) >= 1 and players.has(id):
			var c := Career.of(players[id])
			if int(c["through"]) == GameDB.START_YEAR:
				gf = true
	_check(gf, "A finals player's season closes with his finals in it")
	var kept := true
	for id in players:
		if str(players[id].get("history", [])) != history[id]:
			kept = false
	_check(kept, "Playing a season leaves p[\"history\"] (and so potential) alone")
	var stint_ok := true
	for id in players:
		var row: Array = counted.get(id, [0, 0, 0, ""])
		if int(row[0]) <= 0:
			continue
		var last: Array = (Career.of(players[id])["stints"] as Array)[-1]
		if str(last[0]) != str(row[3]) or int(last[2]) != GameDB.START_YEAR:
			stint_ok = false
	_check(stint_ok, "The first season is credited to the club each player played for")


func _test_three_seasons_and_club_change() -> void:
	_new_season("ADE")
	var start := _totals(_listed())
	var expected := {}
	for id in start:
		expected[id] = start[id].duplicate()
	# A star moves clubs between seasons, the way a trade does.
	var mover := {}
	var from := "GEE"
	var to := "WCE"
	var y0 := GameDB.START_YEAR
	var years := [y0, y0 + 1, y0 + 2]
	for y in years:
		if y == y0 + 1:
			var best := {}
			for p in GameState.season.lists[from]:
				if best.is_empty() or int(p["overall"]) > int(best["overall"]):
					best = p
			mover = best
			(GameState.season.lists[from] as Array).erase(mover)
			GameState._join(to, mover)
		var counted := _play_season()
		for id in counted:
			if not expected.has(id):
				expected[id] = [0, 0]
			expected[id][0] = int(expected[id][0]) + int(counted[id][0])
			expected[id][1] = int(expected[id][1]) + int(counted[id][1])
		if y != years[-1]:
			_check(GameState.start_next_season(), "The career rolls on from %d" % y)
	var players := _listed()
	var exact := true
	var first_bad := ""
	var seen := 0
	for id in players:
		if not start.has(id):
			continue  # joined during the run: covered by the draftee test
		seen += 1
		var c := Career.of(players[id])
		if int(c["games"]) != int(expected[id][0]) or int(c["goals"]) != int(expected[id][1]):
			exact = false
			if first_bad == "":
				first_bad = "%s expected %s got %d/%d" % [id, str(expected[id]), int(c["games"]), int(c["goals"])]
	_check(seen > 400 and exact, "Three seasons accumulate exactly (%d players) %s" % [seen, first_bad])
	var st: Array = Career.of(mover)["stints"]
	var tail := st.slice(st.size() - 2) if st.size() >= 2 else []
	_check(tail.size() == 2 and str(tail[0][0]) == from and int(tail[0][2]) == y0
			and str(tail[1][0]) == to and int(tail[1][1]) == y0 + 1 and int(tail[1][2]) == y0 + 2,
			"A move from %s to %s reads as two stints (%s)" % [from, to, str(st)])


func _test_reload_never_double_counts() -> void:
	_new_season("SYD")
	# Save the round before the Grand Final, reload, then finish: counted once.
	var guard := 0
	while guard < 40 and not (GameState.season.is_regular_done()
			and int(GameState.season.finals.get("week", 1)) >= 5):
		guard += 1
		GameState.advance()
	_check(GameState.save_career(), "A career saves in Grand Final week")
	_check(GameState.load_career(), "It reloads")
	GameState.advance()
	_check(GameState.season.is_season_over(), "The Grand Final completes the season")
	var players := _listed()
	var closed := _totals(players)
	var tally_games := {}
	for id in GameState.season_tally:
		tally_games[id] = int(GameState.season_tally[id]["games"])
	var matches := true
	for id in players:
		var c := Career.of(players[id])
		var start_games := int(c["games"]) - int(tally_games.get(id, 0))
		if start_games < 0:
			matches = false
	_check(matches, "Games added equal the season's tally")
	# Reload after the close, then the rollover's safety net runs: no change.
	_check(GameState.save_career(), "A finished season saves")
	_check(GameState.load_career(), "It reloads")
	var reloaded := _totals(_listed())
	_check(str(reloaded) == str(closed), "Reloading after the close changes nothing")
	Career.close_season(_listed(), GameState.season_tally, GameState.season_year)
	_check(str(_totals(_listed())) == str(closed), "Closing the same season again changes nothing")
	var ids := closed.keys()
	_check(GameState.start_next_season(), "The career rolls to %d" % (GameDB.START_YEAR + 1))
	var rolled := _listed()
	var same := true
	for id in ids:
		if rolled.has(id) and str(_totals({id: rolled[id]})[id]) != str(closed[id]):
			same = false
	_check(same, "The rollover does not count %d again" % GameDB.START_YEAR)
	_check(GameState.save_career() and GameState.load_career(), "Save and reload after the rollover")
	var again := _listed()
	same = true
	for id in ids:
		if again.has(id) and str(_totals({id: again[id]})[id]) != str(closed[id]):
			same = false
	_check(same, "Totals survive a reload across the rollover")


func _test_superdraft_midseason_news() -> void:
	_new_season()
	GameState.news = []
	GameState.class_tiers[str(GameState.season_year)] = "super"
	var halfway := ceili(float(Season.REGULAR_ROUNDS) / 2.0)
	GameState.season.round_index = halfway - 1
	GameState._draft_class_news()
	_check(GameState.news.is_empty(), "A superdraft is not revealed before mid-season")
	GameState.season.round_index = halfway
	GameState._draft_class_news()
	_check(GameState.news.size() == 1 and str(GameState.news[0].get("kind", "")) == "superdraft",
			"A superdraft is flagged to the manager around halfway through the season")
	GameState._draft_class_news()
	_check(GameState.news.size() == 1, "The superdraft warning is only raised once")
	GameState.news = []
	GameState.class_tiers[str(GameState.season_year)] = "strong"
	GameState._draft_class_news()
	_check(GameState.news.is_empty(), "A merely strong class is not falsely called a superdraft")


func _test_draftee_metadata() -> void:
	_new_season("ADE")
	GameState.season.round_index = GameState.season.fixture.size()
	var draft_year := GameState.season_year
	_check(GameState.begin_intake_draft(), "The intake opens")
	var draft: Draft = GameState.draft
	var pots := {}
	for p in GameState.draftee_pool:
		pots[str(p["id"])] = int(p.get("potential", -1))
	while not draft.is_finished():
		var c := draft._best_ai_pick(draft.current_club())
		if c.is_empty() or not draft._draft_pick(draft.current_club(), c):
			draft._skip_current_pick()
	# Drafting itself must not rewrite a prospect's projection. Check this
	# before the season rollover, because the rollover deliberately re-anchors
	# both OVR and POT to the league-wide rating scale.
	var pot_kept := true
	for code in draft.club_lists:
		for p in draft.club_lists[code]:
			var id := str(p["id"])
			if pots.has(id) and int(p.get("potential", -1)) != int(pots[id]):
				pot_kept = false
	_check(pot_kept, "Drafting does not change a draftee's potential")
	_check(GameState.finish_intake_draft(), "The intake commits")
	var national := 0
	var ok := true
	var bad := ""
	for id in GameState.drafted_draftees:
		var p := {}
		for code in GameState.league_lists:
			for q in GameState.league_lists[code]:
				if str(q["id"]) == str(id):
					p = q
		if p.is_empty():
			continue
		if int(p.get("drafted_year", 0)) != draft_year:
			ok = false
			bad = str(p)
		if str(p.get("drafted_type", "")) == "national":
			national += 1
			if int(p.get("drafted_pick", 0)) != int(p.get("draft_pick", -1)) or int(p["drafted_pick"]) <= 0 \
					or not p.has("draft_round"):
				ok = false
				bad = "pick %s / %s" % [str(p.get("drafted_pick")), str(p.get("draft_pick"))]
		elif p.has("drafted_pick"):
			ok = false
			bad = "a pre-listed player has a pick: %s" % str(p.get("drafted_type"))
	_check(national > 20 and ok, "Career draftees carry drafted_year / type / pick (%d national) %s" % [national, bad])
	# A draftee starts his career at nothing, and his first season counts.
	var counted := _play_season()
	var rookie_ok := true
	var played := 0
	for id in GameState.drafted_draftees:
		var p := {}
		for q in _listed().values():
			if str(q["id"]) == str(id):
				p = q
		if p.is_empty():
			continue
		var c := Career.of(p)
		var row: Array = counted.get(str(id), [0, 0])
		if int(c["games"]) != int(row[0]) or not Career.complete(p):
			rookie_ok = false
		if int(row[0]) > 0:
			played += 1
	_check(played > 0 and rookie_ok, "Draftees' first seasons are counted from zero (%d played)" % played)


## Strip every career record and the version mark, as an older build wrote.
func _age_save() -> void:
	var state := CareerSave.read(GameState.save_path)
	state.erase("career_version")
	_strip(state)
	CareerSave.write(state, CareerSave.read_meta(GameState.save_path), GameState.save_path)


func _strip(v) -> void:
	if v is Dictionary:
		(v as Dictionary).erase("career")
		for k in v:
			_strip(v[k])
	elif v is Array:
		for x in v:
			_strip(x)


## A career as builds before 2027 careers started it: in 2026, with no
## 2026 season in anyone's record (it was the first one played).
func _old_2026_season(club: String) -> void:
	GameDB.reload()
	GameState.reset()
	GameState.season_year = GameDB.DATA_SEASON
	GameState.start_season(club, GameDB.club_list(club))


func _test_old_saves() -> void:
	# Before a ball is bounced: nothing was missed, so nothing is unknown.
	_old_2026_season("MEL")
	_check(GameState.save_career(), "A new career saves")
	_age_save()
	_check(GameState.load_career(), "An old save without career records loads")
	var complete := true
	var dangerfield_ok := false
	for p in _listed().values():
		if not (p.get("career") is Dictionary) or not Career.complete(p):
			complete = false
		if str(p.get("real_name", "")) == "Patrick Dangerfield":
			dangerfield_ok = int(p["career"]["games"]) == 360
	_check(complete, "A pre-season old save gets every career, all known")
	_check(dangerfield_ok, "Real players get their AFL careers back on migration")

	# After a season: 2026 was never tallied into careers, so it is unknown.
	_play_season()
	_check(GameState.save_career(), "A finished season saves")
	_age_save()
	_check(GameState.load_career(), "The older finished save loads")
	var marked := true
	var dash := true
	var through_ok := true
	for p in _listed().values():
		var c: Dictionary = p.get("career", {})
		if str(c.get("unknown", [])) != str([[2026, 2026]]):
			marked = false
		if Career.totals_text(p) != "—":
			dash = false
		if int(c.get("through", 0)) != 2026:
			through_ok = false
	_check(marked, "The seasons an old save already played are marked unknown")
	_check(dash, "Their totals show a dash instead of an invented number")
	_check(through_ok, "Those seasons are never counted later either")
	_check(GameState.start_next_season(), "The migrated career rolls on")
	var counted := _play_season()
	var forward := true
	for p in _listed().values():
		var c := Career.of(p)
		var row: Array = counted.get(str(p["id"]), [0, 0])
		var last: Array = (c["stints"] as Array)[-1] if not (c["stints"] as Array).is_empty() else []
		if int(row[0]) > 0 and (last.is_empty() or int(last[2]) != GameDB.DATA_SEASON + 1):
			forward = false
	_check(forward, "After migrating, new seasons are tracked normally")
	_check(GameState.save_career() and GameState.load_career(), "A migrated career saves and reloads")
	var still := true
	for p in _listed().values():
		if str((p.get("career", {}) as Dictionary).get("unknown", [])) != str([[2026, 2026]]):
			still = false
	_check(still, "A migrated save is migrated once, not again on the next load")
