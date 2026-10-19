extends RefCounted
## The finals and Grand Final cards (open requirements 35 and 36, slice 1): each
## trigger is true when it fires, each choice does what its lines say, nothing
## comes up outside its week, and the same save gives the same September. Part of
## the story suite (tests/test_story.gd calls run()).

var s   # the story suite: _check()

const NEW_IDS := ["finals_in", "finals_gone", "finals_last_season", "finals_first_final", "finals_week_off",
		"finals_second_chance", "finals_fitness_test", "finals_family_tickets", "finals_club_greats",
		"finals_captain_last_word", "gf_the_opponent", "gf_last_game", "gf_debut_year", "gf_racing_the_clock",
		"gf_milestone", "gf_week"]


func run(suite) -> void:
	s = suite
	_t("_test_deck")
	_t("_test_finals_math")
	_t("_test_facts")
	_t("_test_weeks")
	_t("_test_text_cases")
	_t("_test_effects")
	_t("_test_risks")
	_t("_test_bye_week")
	_t("_test_determinism_and_no_finals")
	_t("_test_old_save")
	_t("_test_copy")
	_t("_test_director_fixes")


func _check(c: bool, m: String) -> void:
	s._check(c, m)


## Geelong, ranked `rank` + 1 on a fabricated ladder with the regular season done and the
## finals just drawn: the real bracket, the real lists, nothing yet played.

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args, s)
func _finals_game(seed: int, rank := 0) -> void:
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var sea: Season = GameState.season
	var codes: Array = sea.ladder.keys()
	codes.sort()
	codes.erase("GEE")
	codes.insert(rank, "GEE")
	for i in range(codes.size()):
		var row: Dictionary = sea.ladder[codes[i]]
		row["w"] = 20 - i
		row["l"] = 4 + i
		row["d"] = 0
		row["p"] = 24
		row["pf"] = 2400 - i * 20
		row["pa"] = 2000
	sea.round_index = sea.fixture.size()
	sea.recalc_ladder()
	sea.start_finals()
	GameState._next_week_event()


func _deck_card(id: String) -> Dictionary:
	return StoryDeck.by_id(StoryDeck.all(), id)


func _test_deck() -> void:
	for id in NEW_IDS:
		_check(not _deck_card(id).is_empty(), "%s is in the deck" % id)
	var errs := StoryDeck.validate(StoryDeck.all())
	_check(errs.is_empty(), "The deck with the finals cards passes its checks: %s" % "; ".join(PackedStringArray(errs.slice(0, 4))))
	# The checks bite: a chance over the small bound, a missing news line, an unknown case fact.
	var t := _deck_card("finals_week_off").duplicate(true)
	t["id"] = "x"
	t["choices"][0]["effects"][1]["chance"] = 60
	_check(not StoryDeck.validate([t]).is_empty(), "A 'small chance' over the bound is refused")
	t = _deck_card("gf_the_opponent").duplicate(true)
	t["id"] = "x"
	(t["text"][0] as Dictionary)["when"] = {"nonsense": 1}
	_check(not StoryDeck.validate([t]).is_empty(), "A case that tests an unknown fact is refused")
	t = _deck_card("finals_last_season").duplicate(true)
	t["id"] = "x"
	(t["choices"][0]["effects"][4] as Dictionary).erase("text")
	_check(not StoryDeck.validate([t]).is_empty(), "A news line without its words is refused")


# --- The ten -----------------------------------------------------------------

## The least and most a club can finish on, then what the maths says, restated apart
## from Season.finals_math: it loses every game left while every other club wins all of
## theirs (in), or the reverse (out).
func _brute(sea: Season, code: String) -> String:
	var left := {}
	for c in sea.ladder:
		left[c] = 0
	for r in range(sea.round_index, sea.fixture.size()):
		for m in sea.fixture[r]:
			left[m["home"]] += 1
			left[m["away"]] += 1
	var mine := int(sea.ladder[code]["pts"])
	var at_least_level := 0
	var strictly_ahead := 0
	for c in sea.ladder:
		if c == code:
			continue
		if int(sea.ladder[c]["pts"]) + 4 * int(left[c]) >= mine:
			at_least_level += 1
		if int(sea.ladder[c]["pts"]) > mine + 4 * int(left[code]):
			strictly_ahead += 1
	if at_least_level <= 9:
		return "in"
	if strictly_ahead >= 10:
		return "out"
	return "live"


func _test_finals_math() -> void:
	GameState.reset()
	GameState.replay_seed = s.SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var sea: Season = GameState.season
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var codes: Array = sea.ladder.keys()
	var bad := 0
	var kinds := {}
	for trial in range(60):
		sea.round_index = rng.randi_range(12, 24)
		for c in codes:
			var row: Dictionary = sea.ladder[c]
			row["w"] = rng.randi_range(0, sea.round_index)
			row["d"] = 0
			row["l"] = sea.round_index - int(row["w"])
		sea.recalc_ladder()
		for c in codes:
			var got := sea.finals_math(str(c))
			kinds[got] = int(kinds.get(got, 0)) + 1
			if sea.round_index < sea.fixture.size() and got != _brute(sea, str(c)):
				bad += 1
	_check(bad == 0, "The ten's maths matches an independent count over 60 ladders (%d differ)" % bad)
	_check(kinds.has("in") and kinds.has("out") and kinds.has("live"), "...and the ladders reach all three answers (%s)" % str(kinds))
	# The proof: play whole seasons (random scores on the real fixture) and ask every round.
	var wrong_in := 0
	var wrong_out := 0
	var said_in := 0
	var said_out := 0
	for season_i in range(12):
		GameState.reset()
		GameState.replay_seed = 100 + season_i
		GameState.start_season("GEE", GameDB.club_list("GEE"))
		var sc: Season = GameState.season
		var strength := {}
		for c in sc.ladder:
			strength[c] = rng.randf_range(-1.0, 1.0)
		var asked := []
		for r in range(sc.fixture.size()):
			for c in sc.ladder:
				asked.append([sc.round_index, str(c), sc.finals_math(str(c))])
			for m in sc.fixture[r]:
				var a := maxi(20, 90 + int(rng.randfn(0.0, 22.0) + 25.0 * (float(strength[m["home"]]) - float(strength[m["away"]]))))
				var b := maxi(20, 90 + int(rng.randfn(0.0, 22.0)))
				var res := {"home": m["home"], "away": m["away"], "score": [a, b]}
				sc.record_regular(res)
			sc.round_index += 1
			sc.recalc_ladder()
		var top := []
		for row in sc.ladder_sorted().slice(0, Season.FINALISTS):
			top.append(str(row["code"]))
		for q in asked:
			if q[2] == "in":
				said_in += 1
				if not top.has(q[1]):
					wrong_in += 1
			elif q[2] == "out":
				said_out += 1
				if top.has(q[1]):
					wrong_out += 1
	_check(said_in > 50 and said_out > 50, "Twelve seasons give plenty of 'in' and 'out' to check (%d, %d)" % [said_in, said_out])
	_check(wrong_in == 0 and wrong_out == 0, "'In' always made the ten and 'out' never did (%d and %d wrong)" % [wrong_in, wrong_out])


# --- Facts -------------------------------------------------------------------

func _fact(p: Dictionary) -> Dictionary:
	return ClubStories.player_fact(GameState, p, false, {}, 99, 0)


func _test_facts() -> void:
	_finals_game(3001)
	var mine: Array = GameState.my_list
	# last_season is the ageing rule at the coming rollover, read, not guessed.
	var year := GameState.season_year + 1
	var agree := 0
	var said := 0
	for i in range(mine.size()):
		var p: Dictionary = mine[i]
		p["age"] = 31.0 + float(i % 8)
		p["overall"] = 30 + (i * 7) % 50
	var predicted := {}
	for p in mine:
		predicted[str(p["id"])] = bool(_fact(p)["last_season"])
		said += 1 if predicted[str(p["id"])] else 0
	GameState._decide_retirements()
	for p in mine:
		var retires := int(p.get("retiring", 0)) == year
		agree += 1 if retires == bool(predicted[str(p["id"])]) else 0
	_check(said >= 3 and said < mine.size(), "Some players, not all, are in their last season by the ageing rule (%d of %d)" % [said, mine.size()])
	_check(agree == mine.size(), "'Last season' agrees with who the rollover retires, for all %d" % mine.size())
	# His finals: counted for everyone who takes the field, at any club, and no other game.
	_finals_game(3002)
	var seen := {}
	for week in range(3):
		GameState.advance()
	for res in GameState.season_log:
		if not res.has("tag"):
			continue
		for side in 2:
			for r in (res["roster"] as Array)[side]:
				seen[str(r["id"])] = int(seen.get(str(r["id"]), 0)) + 1
	var wrong := 0
	var counted := 0
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			var n := int(p.get("finals_games", 0))
			counted += n
			if n != int(seen.get(str(p["id"]), 0)):
				wrong += 1
	_check(counted > 100 and wrong == 0, "Every final each player took the field in is counted, and no other (%d games, %d wrong)" % [counted, wrong])
	# 'Every game he has played is in this save': a real veteran no, a rookie with no career yes.
	_finals_game(3003)
	var vet := {"id": "v", "career": {"games": 150, "goals": 20, "stints": [["GEE", 2016, 2025, 150, 20]], "through": 2025, "unknown": []}}
	var rookie := {"id": "r", "career": {"games": 0, "goals": 0, "stints": [], "through": 2025, "unknown": []}}
	var unknown := {"id": "u", "career": {"games": 0, "goals": 0, "stints": [], "through": 2025, "unknown": [[0, 2025]]}}
	var made_here := {"id": "m", "career": {"games": 30, "goals": 2, "stints": [["GEE", 2026, 2027, 30, 2]], "through": 2027, "unknown": []}}
	_check(not GameState.save_saw_every_game(vet), "A player with games before the save has not played all his games in it")
	_check(GameState.save_saw_every_game(rookie), "A player with no career before the save has")
	_check(not GameState.save_saw_every_game(unknown), "A career with unknown seasons can't say so")
	_check(GameState.save_saw_every_game(made_here), "A career begun in the save has")
	GameState.finals_counted_since = 2028
	_check(not GameState.save_saw_every_game(made_here), "...unless the finals count began after he started")
	GameState.finals_counted_since = 0
	# A debut year: nothing before this season, a game or more in it.
	var kid: Dictionary = mine[5]
	kid["career"] = {"games": 0, "goals": 0, "stints": [], "through": 2025, "unknown": []}
	GameState.season_tally[str(kid["id"])] = {"games": 0}
	_check(not bool(_fact(kid)["debut_year"]), "No game yet this season: not a debut year")
	GameState.season_tally[str(kid["id"])] = {"games": 5}
	_check(bool(_fact(kid)["debut_year"]), "Five games and none before: a debut year")
	kid["career"] = {"games": 12, "goals": 1, "stints": [["GEE", 2026, 2026, 12, 1]], "through": 2026, "unknown": []}
	_check(not bool(_fact(kid)["debut_year"]) or GameState.season_year == 2026,
			"Games in an earlier season: not a debut year")
	# The milestone: the banner's rule (GameState.milestone_notes), 100th and up.
	var vet2: Dictionary = mine[6]
	vet2["career"] = {"games": 99, "goals": 4, "stints": [["GEE", 2018, 2025, 99, 4]], "through": 2026, "unknown": []}
	GameState.season_tally[str(vet2["id"])] = {"games": 0}
	_check(int(_fact(vet2)["milestone_next"]) == 100, "99 games: the next is his 100th")
	vet2["career"]["games"] = 60
	_check(int(_fact(vet2)["milestone_next"]) == 0, "61st: nothing worth a banner")
	vet2["career"]["games"] = 49
	_check(int(_fact(vet2)["milestone_next"]) == 0, "50th is a banner for the home and away, not for a Grand Final card")
	vet2["career"]["games"] = 249
	_check(int(_fact(vet2)["milestone_next"]) == 250, "249 games: the next is his 250th")
	vet2["career"]["unknown"] = [[2010, 2012]]
	_check(int(_fact(vet2)["milestone_next"]) == 0, "...and nothing for a career that can't be counted")
	# Rating rank on the whole list, injured included; a concussion can't be rushed.
	var facts := ClubStories.player_facts(GameState)
	var top := {}
	for f in facts:
		if int(f["overall_rank"]) == 1:
			top = f
	_check(not top.is_empty(), "One player is ranked first on the list")
	var star: Dictionary = GameState.list_player(str(top["id"]))
	star["injury_weeks"] = 2
	star["injury_kind"] = "hamstring"
	var f2 := _fact(star)
	_check(int(f2["injured_weeks"]) == 2 and bool(f2["rushable"]), "An injured player has weeks to run and can be rushed")
	star["injury_kind"] = "concussion"
	_check(not bool(_fact(star)["rushable"]), "A concussion can't be rushed")
	star["injury_weeks"] = 0
	star.erase("injury_kind")
	# The bracket.
	_finals_game(3004)
	_check(GameState.my_finals_status() == "bye" and bool(ClubStories.context(GameState)["club"]["finals_bye"]),
			"A top-two finish has a week off in the wildcard round")
	GameState.season.finals["week"] = 3
	GameState.season.finals["slots"] = {"L_QF1": "GEE", "W_QF2": "ESS"}
	GameState.season.finals["weeks"] = [[], []]
	var cf: Dictionary = ClubStories.context(GameState)["club"]
	_check(not bool(cf["finals_bye"]) and bool(cf["lost_last_final"]) and int(cf["finals_week"]) == 3,
			"Beaten in a qualifying final and playing the semi: not a week off, and 'beaten last week'")
	GameState.season.finals["slots"] = {"W_QF1": "GEE"}
	cf = ClubStories.context(GameState)["club"]
	_check(bool(cf["finals_bye"]) and not bool(cf["lost_last_final"]), "Won the qualifying final: a week off, not 'beaten'")
	# The Grand Final against this opponent, from the honour roll.
	var rival := ""
	var pair: Array = (Rivalries.ESTABLISHED[2] as Array).slice(0, 2)
	_check(Rivalries.are_rivals(str(pair[0]), str(pair[1])), "The pair used for the rival check are established rivals")
	if not pair.is_empty():
		GameState.my_club = str(pair[0])
		rival = str(pair[1])
		var sea: Season = GameState.season
		sea.finals["week"] = 5
		sea.finals["slots"] = {"W_PF1": str(pair[0]), "W_PF2": rival}
		var y := GameState.season_year
		GameState.honour_roll = [{"year": y - 3, "premier": "XXX", "runner_up": "YYY"},
				{"year": y - 2, "premier": rival, "runner_up": str(pair[0])},
				{"year": y - 1, "premier": str(pair[0]), "runner_up": rival}]
		var gf: Dictionary = ClubStories._grand_final_story(GameState)
		_check(int(gf["gf_run"]) == 3 and gf["gf_again"] == "won" and gf["gf_run_word"] == "third" and bool(gf["rival"]),
				"Three Grand Finals running with them, last year won, an established rival (%s)" % str(gf))
		GameState.honour_roll = [{"year": y - 1, "premier": rival, "runner_up": str(pair[0])}]
		gf = ClubStories._grand_final_story(GameState)
		_check(int(gf["gf_run"]) == 2 and gf["gf_again"] == "lost", "Last year's Grand Final lost to them again: two running, 'lost'")
		GameState.honour_roll = [{"year": y - 1, "premier": rival, "runner_up": "ZZZ"}]
		gf = ClubStories._grand_final_story(GameState)
		_check(int(gf["gf_run"]) == 1 and gf["gf_again"] == "", "Last year's was against someone else: the first running")
		GameState.honour_roll = [{"year": y - 2, "premier": str(pair[0]), "runner_up": rival}]
		gf = ClubStories._grand_final_story(GameState)
		_check(int(gf["gf_run"]) == 1, "A gap year breaks the run")
		GameState.honour_roll = []
		GameState.my_club = "GEE"
	# A flag set by the card is the fact the next card reads, this season only.
	var cap_id := str(mine[0]["id"])
	GameState.story["flags"][cap_id] = {"farewell_told": StoryEngine.week_abs(GameState.season_year, 26)}
	_check(GameState.story_flag_set(cap_id, "farewell_told"), "A flag set this season is read")
	GameState.story["flags"][cap_id] = {"farewell_told": StoryEngine.week_abs(GameState.season_year - 1, 26)}
	_check(not GameState.story_flag_set(cap_id, "farewell_told"), "...and one from last season is not")


# --- When each card can come up -----------------------------------------------

## A fact set that satisfies a card's conditions (the edge of each bound).
func _satisfy(cond: Dictionary, into: Dictionary) -> void:
	for k in cond:
		var key := str(k)
		for suffix in ["_min", "_max"]:
			if key.ends_with(suffix):
				into[key.trim_suffix(suffix)] = cond[k]
				key = ""
				break
		if key != "":
			into[key] = cond[k]


## The scenarios a card is eligible in, with every other fact at its ideal.
func _weeks_of(id: String) -> Array:
	var t := _deck_card(id)
	var out := []
	for finals in [false, true]:
		for fw in range(0, 6):
			if not finals and fw > 0 or finals and fw == 0:
				continue
			for bye in [false, true]:
				var club := {"club": "Geelong", "opp": "Essendon", "year": 2027, "finals_math": "", "lost_last_final": false,
						"gf_run": 0, "gf_run_word": "", "gf_again": "", "rival": false,
						"fit_count": 30, "losing_run": 0, "winning_run": 0, "ladder": 5, "board": 50}
				_satisfy(t.get("when", {}), club)
				club["round"] = 10 if not finals else 24 + fw
				club["finals_week"] = fw
				club["finals_bye"] = bye
				var p := {"id": "p1", "name": "Sam Test", "first": "Sam", "age": 20.0, "games": 250, "fit": true, "selected": true,
						"overall": 70, "potential": 80, "pot_gap": 10, "morale": 50, "trust": 0, "fit_rank": 2, "captain": true,
						"real_named": false}
				_satisfy((t.get("subject", {}) as Dictionary).get("where", {}), p)
				if p.has("selected") and (t["subject"].get("where", {}) as Dictionary).get("selected", true) == false:
					p["selected"] = false
				var ctx := {"seed": 1, "year": 2027, "week": club["round"], "phase": "finals" if finals else "regular",
						"big": true, "club": club, "players": [p]}
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				if not StoryEngine.eligible_subject(t, ctx, StoryEngine.new_state(), 100, rng).is_empty():
					out.append("%s%d%s" % ["F" if finals else "R", fw, "b" if bye else ""])
	return out


func _test_weeks() -> void:
	var finals_play := ["F1", "F2", "F3", "F4"]
	var expect := {
		"finals_in": ["R0"], "finals_gone": ["R0"],
		"finals_last_season": finals_play, "finals_first_final": finals_play, "finals_fitness_test": finals_play,
		"finals_family_tickets": finals_play, "finals_club_greats": finals_play, "finals_captain_last_word": finals_play,
		"finals_second_chance": ["F3"],
		"finals_week_off": ["F1b", "F2b", "F3b", "F4b", "F5b"],
		"gf_the_opponent": ["F5"], "gf_last_game": ["F5"], "gf_debut_year": ["F5"], "gf_racing_the_clock": ["F5"],
		"gf_milestone": ["F5"], "gf_week": ["F5"],
	}
	for id in expect:
		var got := _weeks_of(id)
		_check(got == expect[id], "%s comes up only in %s (%s)" % [id, str(expect[id]), str(got)])
	# The week off exists only where the bracket gives one: weeks 1 and 3, the top six and the qualifying winners.
	_finals_game(3010)
	var top: Array = GameState.season.finals["top"]
	var byes := {}
	for week in range(1, 6):
		var sl := {}
		if week >= 2:
			sl.merge({"W_WC1": top[6], "L_WC1": top[9], "W_WC2": top[7], "L_WC2": top[8]})
		if week >= 3:
			sl.merge({"W_QF1": top[0], "L_QF1": top[3], "W_QF2": top[1], "L_QF2": top[2],
					"W_EF1": top[4], "L_EF1": top[7], "W_EF2": top[5], "L_EF2": top[6]})
		if week >= 4:
			sl.merge({"W_SF1": top[3], "L_SF1": top[4], "W_SF2": top[2], "L_SF2": top[5]})
		if week >= 5:
			sl.merge({"W_PF1": top[0], "L_PF1": top[3], "W_PF2": top[1], "L_PF2": top[2]})
		GameState.season.finals["week"] = week
		GameState.season.finals["slots"] = sl
		for code in top:
			GameState.my_club = str(code)
			if GameState.my_finals_status() == "bye":
				byes[week] = int(byes.get(week, 0)) + 1
	GameState.my_club = "GEE"
	_check(byes.keys() == [1, 3] and int(byes[1]) == 6 and int(byes[3]) == 2,
			"Six clubs have a week off in week 1, two in week 3, nobody else (%s)" % str(byes))


# --- The words that change with the week ----------------------------------------

func _built(id: String, club: Dictionary, subj := {"kind": "club"}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	return StoryEngine.build(StoryDeck.all(), _deck_card(id), subj, club, rng, 100)


func _test_text_cases() -> void:
	var base := {"opp": "Essendon", "finals_week": 5, "gf_run": 1, "gf_run_word": "", "gf_again": "", "rival": false, "finals_bye": false}
	var one := func(over: Dictionary) -> String:
		var c := base.duplicate()
		c.merge(over, true)
		return str(_built("gf_the_opponent", c)["text"])
	_check(one.call({"gf_run": 3, "gf_run_word": "third", "gf_again": "won", "rival": true}) == "Essendon again, for the third year running. Nobody knows you better.",
			"Three running with them beats every other line")
	_check(one.call({"gf_run": 2, "gf_again": "won", "rival": true}).contains("twelve months to think about last year's Grand Final"), "A rematch of one you won")
	_check(one.call({"gf_run": 2, "gf_again": "lost", "rival": true}).contains("a second go at them"), "A rematch of one you lost")
	_check(one.call({"rival": true}).contains("Of all the clubs"), "An established rival")
	_check(one.call({}).contains("counts for nothing now"), "Anyone else")
	# The farewell reads what the coach did on the earlier card.
	var cap := {"kind": "player", "id": "c", "name": "Sam Test", "first": "Sam", "told_players": true}
	_check(str(_built("gf_last_game", base, cap)["text"]).contains("everyone knows it"), "Told the players: the card says everyone knows")
	cap["told_players"] = false
	_check(str(_built("gf_last_game", base, cap)["text"]).contains("Only you and Sam Test know"), "Not told: only the two of them know")
	# The week off: the wildcard week's words, then the semi's with its third choice.
	var w1 := _built("finals_week_off", {"finals_week": 1, "finals_bye": true})
	var w3 := _built("finals_week_off", {"finals_week": 3, "finals_bye": true})
	_check(str(w1["title"]) == "A week off while the wildcards play" and (w1["options"] as Array).size() == 2,
			"Week 1: the wildcard week's title and two choices")
	_check(str(w3["title"]) == "Straight through to a preliminary final" and (w3["options"] as Array).size() == 3
			and str(w3["options"][2]["label"]) == "Watch the semi together", "Week 3: the straight-through title and a third choice")


# --- What each choice does ----------------------------------------------------

func _group(kind: String, side_ids: Dictionary, p: Dictionary) -> Array:
	var out := []
	for q in GameState.my_list:
		if kind == "all" or (kind == "side" and side_ids.has(str(q["id"]))) or (kind == "subject" and q == p):
			out.append(q)
	return out


func _side_ids() -> Dictionary:
	var ids := {}
	var side: Dictionary = GameState.current_side()
	for k in side:
		for id in side[k]:
			ids[str(id)] = true
	return ids


## Every plain effect of every choice of every new card, applied: the morale, the board, the
## trust and the one-week flags move exactly as its lines say.
func _test_effects() -> void:
	var tried := 0
	var bad := []
	for id in NEW_IDS:
		_finals_game(3020)
		GameState.season.seed = 424242   # fixed: the chances below are tested in _test_risks
		var t := _deck_card(id)
		var is_player: bool = str((t["subject"] as Dictionary).get("kind", "")) == "player"
		for ci in range((t["choices"] as Array).size()):
			var p: Dictionary = GameState.my_list[3]
			for q in GameState.my_list:
				for flag in ["fresh", "heavy_legs", "rested", "sore", "slow_start", "loss_sting"]:
					q.erase(flag)
			var side_ids := _side_ids()
			# A captain whose group listens, so a delegated choice takes its first outcome.
			var card := GameState.story_card(id, p if is_player else {})
			if (card["options"] as Array).size() <= ci:
				continue   # a choice that only some weeks show
			card["facts"]["delegate_holds"] = true
			card["facts"]["finals_week"] = 3
			for q in GameState.my_list:
				q["morale"] = 50
				q.erase("fresh")
				q.erase("heavy_legs")
			var conf0 := GameState.board_confidence()
			var trust0 := Trust.value(GameState.relations, Trust.player_key(str(p["id"])))
			var opt: Dictionary = card["options"][ci]
			var effects: Array = (opt["effects"] as Array).duplicate()
			for e in effects.duplicate():
				if str(e.get("op", "")) == "delegate":
					effects.append_array(e["held"])
			ClubStories.apply_choice(GameState, card, ci)
			tried += 1
			for e in effects:
				var op := str(e.get("op", ""))
				var who := str(e.get("who", "subject"))
				var grp := _group(who, side_ids, p)
				var d := int(e.get("d", 0))
				match op:
					"morale":
						for q in grp:
							var net := 0
							for e2 in effects:
								if str(e2.get("op", "")) == "morale" and _group(str(e2.get("who", "subject")), side_ids, p).has(q):
									net += int(e2["d"])
							if ClubLife.morale(q) != clampi(50 + net, 5, 100):
								bad.append("%s/%d morale %s" % [id, ci, str(q["name"])])
								break
					"board":
						if GameState.board_confidence() != clampi(conf0 + d, 0, 100):
							bad.append("%s/%d board" % [id, ci])
					"trust":
						var t1 := Trust.value(GameState.relations, Trust.player_key(str(p["id"])))
						if (d > 0 and t1 <= trust0) or (d < 0 and t1 >= trust0):
							bad.append("%s/%d trust" % [id, ci])
					"fresh", "heavy_legs":
						for q in grp:
							if not bool(q.get(op, false)):
								bad.append("%s/%d %s" % [id, ci, op])
								break
					"rest", "sore":
						if not bool(p.get("rested" if op == "rest" else "sore", false)):
							bad.append("%s/%d %s" % [id, ci, op])
					"start_backing":
						if not Backing.is_active(p):
							bad.append("%s/%d backing" % [id, ci])
	_check(tried >= 30, "Choices applied (%d)" % tried)
	_check(bad.is_empty(), "Every plain effect of the finals cards does what it says: %s" % " | ".join(PackedStringArray(bad.slice(0, 8))))
	# The two captain cards: the group listens or it doesn't, by the printed rule.
	for id in ["finals_second_chance", "finals_captain_last_word"]:
		_finals_game(3021)
		var cap: Dictionary = {}
		var rec := GameState.captaincy_record("GEE")
		for q in GameState.my_list:
			if Captaincy.role_of(rec, str(q["id"])) == "captain":
				cap = q
		var card := GameState.story_card(id, cap)
		var leave: int = (card["options"] as Array).size() - 1 if id == "finals_second_chance" else 0
		var o: Dictionary = card["options"][leave]
		_check(str(o["rule"]).contains("Leadership") and not str(o["rule"]).contains("{"), "%s: the choice prints the rule it follows (%s)" % [id, o["rule"]])
		var lines := " ".join(StoryEngine.stakes_lines(o["effects"], card["facts"]))
		_check(lines.contains("As it stands the group"), "%s: and says where the group stands now" % id)
		for holds in [true, false]:
			_finals_game(3021)
			for q in GameState.my_list:
				if Captaincy.role_of(GameState.captaincy_record("GEE"), str(q["id"])) == "captain":
					cap = q
			for q in GameState.my_list:
				q["morale"] = 50
			var c2 := GameState.story_card(id, cap)
			c2["facts"]["delegate_holds"] = holds
			ClubStories.apply_choice(GameState, c2, leave)
			var side_ids := _side_ids()
			var q0: Dictionary = {}
			for q in GameState.my_list:
				if side_ids.has(str(q["id"])):
					q0 = q
					break
			var up := ClubLife.morale(q0) - 50
			if id == "finals_second_chance":
				_check(up == (0 if holds else -2), "%s: the group %s, the side's morale moves %d" % [id, "listens" if holds else "doesn't", up])
			else:
				_check(up == (5 if holds else 0), "%s: the group %s, the side's morale rises by %d" % [id, "listens" if holds else "doesn't", up])


## The small chances: one roll from the save's seed; the same save rolls the same; the rate is the card's.
func _test_risks() -> void:
	var hits := 0
	for sd in range(2000):
		if StoryEngine.risk_hit(sd, 2027, 25, "finals_week_off|slow", 20):
			hits += 1
	_check(hits > 300 and hits < 500, "A 20 percent chance comes up about one time in five (%d of 2000)" % hits)
	_check(StoryEngine.risk_hit(5, 2027, 25, "k", 20) == StoryEngine.risk_hit(5, 2027, 25, "k", 20), "The same save rolls the same answer")
	# Slow start through the card: all of the side or none; the one player or no one.
	_finals_game(3030)
	var yr := GameState.season_year
	var hit_seed := -1
	var miss_seed := -1
	for sd in range(200):
		var h := StoryEngine.risk_hit(sd, yr, 25, "finals_week_off|slow|side|", 20)
		if h and hit_seed < 0:
			hit_seed = sd
		if not h and miss_seed < 0:
			miss_seed = sd
	for pair in [[hit_seed, true], [miss_seed, false]]:
		_finals_game(3030)
		GameState.season.seed = int(pair[0])
		var card := GameState.story_card("finals_week_off")
		card["facts"]["round"] = 25
		card["facts"]["year"] = yr
		ClubStories.apply_choice(GameState, card, 0)
		var n := 0
		for q in _group("side", _side_ids(), {}):
			n += 1 if bool(q.get("slow_start", false)) else 0
		_check(n == (_group("side", _side_ids(), {}).size() if pair[1] else 0),
				"Resting the side, the chance %s: %s of the side start slowly" % ["hit" if pair[1] else "missed", "all" if pair[1] else "none"])
	# The flag costs the first quarter only: his legs at the first bounce.
	var q := {"id": "z", "attr": {"durability": 70}, "slow_start": true}
	_check(MatchSim._start_energy(q) == ClubLife.SLOW_LEGS, "A slow start takes the first bounce on %d legs" % int(ClubLife.SLOW_LEGS))
	q.erase("slow_start")
	_check(MatchSim._start_energy(q) == 100.0, "...and is gone the next week")
	# The A4 sting: the side's morale falls instead only when the final is lost, and only on the roll.
	var roll_hit := -1
	var roll_miss := -1
	for sd in range(200):
		var h := StoryEngine.risk_hit(sd, yr, 30, "loss_sting", 20)
		if h and roll_hit < 0:
			roll_hit = sd
		if not h and roll_miss < 0:
			roll_miss = sd
	var lines := []
	for case in [[roll_hit, true, true], [roll_hit, false, false], [roll_miss, true, false]]:
		_finals_game(3031)
		GameState.season.seed = int(case[0])
		var cap: Dictionary = GameState.my_list[0]
		var card := GameState.story_card("finals_last_season", cap)
		for p2 in GameState.my_list:
			p2["morale"] = 50
		ClubStories.apply_choice(GameState, card, 0)
		var side_ids := _side_ids()
		var some: Dictionary = {}
		for p2 in GameState.my_list:
			if side_ids.has(str(p2["id"])):
				some = p2
				break
		_check(ClubLife.morale(some) == 55 and bool(some.has("loss_sting")), "The side hears it: morale 55, and the chance is waiting")
		var lost: bool = bool(case[1])
		var res := {"home": "GEE", "away": "ESS", "tag": "QF1", "score": [60, 90] if lost else [90, 60], "round": 30}
		GameState.season.finals["slots"]["W_QF1"] = "ESS" if lost else "GEE"
		GameState._settle_loss_sting(res)
		var after := ClubLife.morale(some)
		var expect_fall: bool = bool(case[2])
		lines.append("%s %s -> %d" % ["lost" if lost else "won", "rolled" if bool(case[2]) else "no roll", after])
		_check((after == 47) == expect_fall and (expect_fall or after == 55),
				"Told the players, %s, the roll %s: morale %d (%s)" % ["lost" if lost else "won", "hit" if expect_fall else "didn't", after,
				"net 47: it fell instead" if expect_fall else "stays 55"])
	# Rushed back: available, and at a sore player's risk; a concussion is refused.
	_finals_game(3032)
	var star: Dictionary = GameState.my_list[1]
	star["injury_weeks"] = 2
	star["injury_kind"] = "hamstring"
	var rc := GameState.story_card("gf_racing_the_clock", star)
	var out := ClubStories.apply_choice(GameState, rc, 0)
	_check(int(star["injury_weeks"]) == 0 and bool(star.get("sore", false)) and out.contains("cleared to play"),
			"Rushed back: no weeks to run, playing sore, and the card says he's cleared (%s)" % out)
	_check(Injuries.chance(star) > Injuries.chance({"attr": star["attr"]}) * 3.0, "...at a much higher chance of breaking down")
	star["injury_weeks"] = 2
	star["injury_kind"] = "concussion"
	star.erase("sore")
	out = ClubStories.apply_choice(GameState, rc, 0)
	_check(int(star["injury_weeks"]) == 2 and not bool(star.get("sore", false)), "A concussion stays out under the protocols (%s)" % out)
	# The news line and the flag, through the real resolve path.
	_finals_game(3033)
	var vet: Dictionary = GameState.my_list[2]
	var fc := GameState.story_card("finals_last_season", vet)
	GameState.week_events = [fc]
	var news0 := GameState.news.size()
	GameState.resolve_card(0, 0)
	_check(GameState.news.size() == news0 + 1 and str(GameState.news[0]["text"]).contains("could be his last"), "Telling the players puts a line in the club news")
	_check(GameState.story_flag_set(str(vet["id"]), "farewell_told"), "...and sets the flag the Grand Final card reads")
	_check(not str(GameState.news[0]["text"]).contains("will retire"), "...and never says he will retire")


# --- The week off --------------------------------------------------------------

func _test_bye_week() -> void:
	_finals_game(3040)
	var ids := GameState.week_events.map(func(c): return str(c["tid"]))
	_check(ids == ["finals_week_off"], "A club with a week off is shown the week-off card and nothing else (%s)" % str(ids))
	GameState.season.seed = 7
	for sd in range(200):
		if StoryEngine.risk_hit(sd, GameState.season_year, 25, "finals_week_off|slow|side|", 20):
			GameState.season.seed = sd
			break
	GameState.week_events[0]["facts"]["round"] = 25
	GameState.resolve_card(0, 0)
	var any_fresh := true
	var any_slow := false
	for q in GameState.my_list:
		any_fresh = any_fresh and bool(q.get("fresh", false))
	for q in GameState.my_list:
		any_slow = any_slow or bool(q.get("slow_start", false))
	_check(any_fresh, "Rested: everyone is fresh")
	GameState.advance()   # the wildcard round: no match for Geelong
	_check(GameState.last_match.is_empty(), "The wildcard round has no match for a top-two side")
	var kept := true
	for q in GameState.my_list:
		kept = kept and bool(q.get("fresh", false))
	_check(kept, "The week off keeps 'fresh' for the next match")
	var slow_kept := false
	for q in GameState.my_list:
		slow_kept = slow_kept or bool(q.get("slow_start", false))
	_check(slow_kept == any_slow, "...and a slow start that was rolled")
	GameState.advance()   # a qualifying final: Geelong play, and the flags end with it
	_check(not GameState.last_match.is_empty(), "A qualifying final is a match")
	var left := 0
	for q in GameState.my_list:
		left += (1 if bool(q.get("fresh", false)) else 0) + (1 if bool(q.get("slow_start", false)) else 0)
	_check(left == 0, "...and 'fresh' and a slow start end with that match (%d left)" % left)
	# In the home-and-away the same flags still end at once.
	GameState.reset()
	GameState.replay_seed = s.SUITE_SEED
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	for q in GameState.my_list:
		q["fresh"] = true
		q["slow_start"] = true
		q["loss_sting"] = [20, -8]
	GameState.advance()
	var still := 0
	for q in GameState.my_list:
		still += 1 if (q.has("fresh") or q.has("slow_start") or q.has("loss_sting")) else 0
	_check(still == 0, "A round of the home and away ends the week's flags")
	# A bye in the finals: only a week-off card; and the cards written for the week off don't come up in a match week.
	_finals_game(3041, 7)
	var ids2 := GameState.week_events.map(func(c): return str(c["tid"]))
	_check(not ids2.has("finals_week_off"), "A club that plays the wildcard round gets no week-off card (%s)" % str(ids2))


# --- Same save, same September; no finals, no cards -----------------------------

func _september(seed: int, rank: int, weeks: int) -> PackedStringArray:
	_finals_game(seed, rank)
	var out: PackedStringArray = []
	var guard := 0
	while not GameState.season.is_season_over() and guard < weeks:
		guard += 1
		for c in GameState.week_events:
			out.append("%d %s %s" % [ClubStories.week_in_season(GameState), str(c["tid"]), str(c["text"])])
		for i in range(GameState.week_events.size()):
			GameState.resolve_card(i, 0)
		GameState.advance()
	return out


func _test_determinism_and_no_finals() -> void:
	var a := _september(3050, 2, 3)
	var b := _september(3050, 2, 3)
	_check(a.size() >= 3 and a == b, "The same save gives the same September, card for card and word for word (%d cards)" % a.size())
	var c := _september(3051, 2, 3)
	_check(a != c or a.is_empty(), "A different save does not")
	var cards := 0
	for line in a:
		cards += 1
	var fresh_ids := {}
	for line in a:
		var tid := str(line).split(" ")[1]
		fresh_ids[tid] = true
	_check(fresh_ids.size() >= 2, "A September shows different finals cards in different weeks (%s)" % str(fresh_ids.keys()))
	# A season with no finals for you: none of the finals-week cards, in any week of them.
	var none := _september(3052, 12, 2)
	_check(none.is_empty(), "A club that missed the finals sees no card in September (%s)" % str(none.slice(0, 2)))
	# Two Grand Finals in a row, the same club and opponent, a win then a loss: the words differ.
	_finals_game(3053, 0)
	var sea: Season = GameState.season
	sea.finals["week"] = 5
	sea.finals["weeks"] = [[], [], [], []]
	sea.finals["slots"] = {"W_PF1": "GEE", "W_PF2": "ESS"}
	var first := ClubStories._grand_final_story(GameState)
	GameState.honour_roll = [{"year": GameState.season_year, "premier": "GEE", "runner_up": "ESS"}]
	GameState.season_year += 1
	var second := ClubStories._grand_final_story(GameState)
	GameState.season_year -= 1
	GameState.honour_roll = []
	var cf := {"opp": "Essendon", "finals_week": 5, "finals_bye": false}
	cf.merge(first, true)
	var t1 := str(_built("gf_the_opponent", cf)["text"])
	cf.merge(second, true)
	var t2 := str(_built("gf_the_opponent", cf)["text"])
	_check(t1 != t2, "Two Grand Finals in a row against the same side read differently (%s | %s)" % [t1, t2])


func _test_old_save() -> void:
	_finals_game(3060)
	GameState.my_list[3]["finals_games"] = 2
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("finals_counted_since")
	CareerSave.write(state, GameState._save_meta(), GameState.save_path)
	_check(GameState.load_career(), "A save from before the finals count loads")
	_check(GameState.finals_counted_since == GameState.season_year + 1, "...and counts finals from the next ones (%d)" % GameState.finals_counted_since)
	var facts := ClubStories.player_facts(GameState)
	_check(facts.size() == GameState.my_list.size(), "...and its players have facts")
	var man: Dictionary = GameState.my_list[3]
	man["career"] = {"games": 20, "goals": 1, "stints": [["GEE", GameState.season_year, GameState.season_year, 20, 1]], "through": GameState.season_year, "unknown": []}
	_check(not GameState.save_saw_every_game(man), "...but 'his first final' is not said for a player it did not count")
	var picked := GameState.week_events.size()
	_check(picked >= 0, "...and the week's cards are drawn")


# --- Words ----------------------------------------------------------------------

func _test_copy() -> void:
	var words := RegEx.create_from_string("(?i)\\b(wife|girlfriend|boyfriend|depress|mental|drunk|arrest|police|gambl|drugs?|divorce|funeral|cancer|retire[sd]?)\\b")
	var bad := []
	for id in NEW_IDS:
		var t := _deck_card(id)
		_check(not bool(t.get("private", false)), "%s is not a private card" % id)
		var all := []
		for v in t["title"] + t["text"]:
			all.append(str(v["text"]) if v is Dictionary else str(v))
		for c in t["choices"]:
			all.append(str(c["label"]))
			all.append(str(c.get("result", "")))
		for line in all:
			if words.search(line) != null:
				bad.append("%s: %s" % [id, line])
			if RegEx.create_from_string("\\b(lift|lifts|flat|gets them up)\\b").search(str(line)) != null:
				bad.append("%s: %s" % [id, line])
	_check(bad.is_empty(), "No finals card says a private thing, says he retires as a fact, or uses a vague mood word: %s" % " | ".join(PackedStringArray(bad.slice(0, 4))))
	for id in ["finals_last_season", "gf_last_game"]:
		var t := _deck_card(id)
		var txt := str(t["title"][0]) + " " + str(t["text"][-1] if not (t["text"][-1] is Dictionary) else t["text"][0]["text"])
		_check(txt.contains("could be") or txt.contains("may be"), "%s says 'could be' or 'may be', never a certainty (%s)" % [id, txt])
	# A phrase of four words that two cards share is a writer's warning (printed below). It fails the
	# check only when the two cards can be dealt in the same week (director 2026-10-18, ch. 30 row 36).
	# The 'leave it to' label is the captain cards' own.
	var grams := {}
	var dup := []
	var clash := []
	for t in StoryDeck.all():
		var seen_here := {}
		var texts := []
		for v in t["title"] + t["text"]:
			texts.append(str(v["text"]) if v is Dictionary else str(v))
		for c in t["choices"]:
			texts.append(str(c.get("label", "")))
			texts.append(str(c.get("result", "")))
		for tx in texts:
			var w := RegEx.create_from_string("[a-z']+").search_all(str(tx).to_lower())
			for i in range(w.size() - 3):
				var g := "%s %s %s %s" % [w[i].get_string(), w[i + 1].get_string(), w[i + 2].get_string(), w[i + 3].get_string()]
				if g == "leave it to name":
					continue
				seen_here[g] = true
		for g in seen_here:
			if grams.has(g) and (NEW_IDS.has(str(t["id"])) or NEW_IDS.has(str(grams[g]))):
				var other := _deck_card(str(grams[g]))
				var same_week := _share_a_finals_week(t, other)
				print("writer: %s and %s share '%s'%s" % [grams[g], t["id"], g,
						" (can be dealt in the same week)" if same_week else ""])
				dup.append("%s/%s: %s" % [t["id"], grams[g], g])
				if same_week:
					clash.append("%s/%s: %s" % [t["id"], grams[g], g])
			grams[g] = str(t["id"])
	_check(clash.is_empty(), "No two cards that can be dealt in the same week share a four-word phrase (%d shared phrases in all, printed as writer warnings): %s" % [dup.size(), " | ".join(PackedStringArray(clash.slice(0, 4)))])


## The finals weeks (1 to 5, the Grand Final) a card can be dealt in, from its phase and its
## finals_week, finals_week_min and finals_week_max conditions; lo > hi when it is never a finals card.
func _finals_weeks(t: Dictionary) -> Vector2i:
	var phases: Array = t.get("phase", [])
	if not phases.is_empty() and not phases.has("finals"):
		return Vector2i(1, 0)
	var when: Dictionary = t.get("when", {})
	var lo := 1
	var hi := 5
	if when.has("finals_week"):
		lo = int(when["finals_week"])
		hi = lo
	if when.has("finals_week_min"):
		lo = maxi(lo, int(when["finals_week_min"]))
	if when.has("finals_week_max"):
		hi = mini(hi, int(when["finals_week_max"]))
	return Vector2i(lo, hi)


func _share_a_finals_week(a: Dictionary, b: Dictionary) -> bool:
	var wa := _finals_weeks(a)
	var wb := _finals_weeks(b)
	return wa.x <= wa.y and wb.x <= wb.y and maxi(wa.x, wb.x) <= mini(wa.y, wb.y)


## The director's fixes (2026-10-14): a captain the group would not listen to changes no morale; a
## Grand Final card says Saturday, and the flag is on the side when the Grand Final is played; the
## Grand Final card names the club you actually meet.
func _test_director_fixes() -> void:
	_finals_game(3070)
	var cap: Dictionary = {}
	for q in GameState.my_list:
		if Captaincy.role_of(GameState.captaincy_record("GEE"), str(q["id"])) == "captain":
			cap = q
	var card := GameState.story_card("finals_captain_last_word", cap)
	var give: Dictionary = card["options"][0]
	card["facts"]["delegate_holds"] = false
	var lines := " ".join(StoryEngine.stakes_lines(give["effects"], card["facts"]))
	_check(not lines.contains("If it doesn't"), "Last word, group not listening: no line promises a morale change (%s)" % lines)
	for q in GameState.my_list:
		q["morale"] = 50
	ClubStories.apply_choice(GameState, card, 0)
	var moved := 0
	for q in GameState.my_list:
		moved += absi(ClubLife.morale(q) - 50)
	_check(moved == 0, "Last word, group not listening: nobody's morale moves (%d)" % moved)
	# Saturday, not "next final".
	for id in ["gf_the_opponent", "gf_debut_year"]:
		var c2 := GameState.story_card(id, GameState.my_list[3])
		var text := ""
		for o in c2["options"]:
			text += " ".join(StoryEngine.stakes_lines(o["effects"], c2["facts"]))
		_check(text.contains("starts Saturday slowly") and not text.contains("next final"), "%s: the cost says Saturday (%s)" % [id, text])
	var wk := GameState.story_card("finals_week_off")
	var wtext := " ".join(StoryEngine.stakes_lines(wk["options"][0]["effects"], wk["facts"]))
	_check(wtext.contains("next final"), "The week off still says 'next final' (%s)" % wtext)
	# The Grand Final: the club you meet, named; the flag is on the side when it is played.
	var sea: Season = GameState.season
	sea.finals["week"] = 5
	sea.finals["weeks"] = [[], [], [], []]
	sea.finals["slots"] = {"W_PF1": "GEE", "W_PF2": "ESS"}
	var club: Dictionary = ClubStories.context(GameState)["club"]
	_check(str(club["opp"]) == GameDB.club_name("ESS") and int(club["finals_week"]) == 5, "The Grand Final week's opponent is the club in the other slot (%s)" % str(club["opp"]))
	var gf := GameState.story_card("gf_the_opponent")
	_check(str(gf["title"]).begins_with(GameDB.club_name("ESS")) and not str(gf["text"]).contains("Collingwood"),
			"The Grand Final card names Essendon, the club you meet (%s)" % gf["title"])
	var hit := -1
	for sd in range(300):
		if StoryEngine.risk_hit(sd, GameState.season_year, 29, "gf_the_opponent|slow|side|", 20):
			hit = sd
			break
	GameState.season.seed = hit
	gf["facts"]["round"] = 29
	ClubStories.apply_choice(GameState, gf, 0)
	var slow := 0
	var squad := GameState.my_squad()
	for p in squad.ground:
		if bool(p.get("slow_start", false)) and MatchSim._start_energy(p) == ClubLife.SLOW_LEGS:
			slow += 1
	_check(slow == squad.ground.size() and slow > 0, "Make it about them (rolled): the side that runs out in the Grand Final starts on slow legs (%d of %d)" % [slow, squad.ground.size()])
