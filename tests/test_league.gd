extends RefCounted
## Difficulty, the league news feed and the player-name preference. Run through
## tests/run_league_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_menu("fair", "shrewd")
	_test_difficulty()
	_test_trade_margin()
	_test_news()
	_test_marquee_games()
	_test_banner_context()
	_test_real_names_default()
	_menu("fair", "shrewd")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("League tests: %d checks, %d failures" % [checks, failures.size()])


## The banner's occasion comes from what anyone at the ground knows: the
## fixture, the ladder and the record books (GameState.banner_context).
func _test_banner_context() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var s: Season = GameState.season
	var yr := GameState.season_year
	var m0: Dictionary = {}
	for m in s.fixture[0]:
		if str(m["home"]) == "GEE" or str(m["away"]) == "GEE":
			m0 = m
	var ctx := GameState.banner_context(m0)
	_check(str(ctx["us"]) == "GEE" and str(ctx["final"]) == "" and not bool(ctx["must_win"]) and not bool(ctx["spoon"]),
			"A round-one match is an ordinary banner (%s)" % str(ctx))
	_check(int(ctx["seed"]) == int(GameState.banner_context(m0)["seed"]), "The same match gives the same seed")
	# FL-008: pennants for your flags of this career, newest first, at your own ground.
	_check((ctx["flags"] as Array).is_empty(), "No flags yet, no pennants")
	GameState.honour_roll = [{"year": yr - 3, "premier": "GEE"}, {"year": yr - 2, "premier": "CAR"},
			{"year": yr - 1, "premier": "GEE"}]
	var home := str(m0["home"]) == "GEE"
	var fl: Array = GameState.banner_context(m0)["flags"]
	_check(GameState.premiership_years("GEE") == [yr - 1, yr - 3] and GameState.premiership_years("CAR") == [yr - 2],
			"A club's premierships of this career, newest first (%s)" % str(GameState.premiership_years("GEE")))
	_check(fl == ([yr - 1, yr - 3] if home else []), "Pennants hang at your home games only (%s, home %s)" % [str(fl), str(home)])
	var vig := PreMatchVignette.new()
	vig.setup_prematch("GEE", "CAR", [], [], "Round 1", false, {"flags": range(2020, 2030)})
	_check(vig.flags.size() == PreMatchVignette.PENNANTS, "A dynasty doesn't wallpaper the stand: %d pennants at most" % PreMatchVignette.PENNANTS)
	vig.free()
	GameState.honour_roll = []
	_check(str(GameState.banner_context({"home": "GEE", "away": "COL", "tag": "GF", "label": "Grand Final"})["final"]) == "grand"
			and str(GameState.banner_context({"home": "GEE", "away": "COL", "tag": "SF1"})["final"]) == "semi",
			"A final carries its week")
	# Must win: last round, a loss leaves you out whatever else happens, a win
	# can still get you in.
	s.round_index = s.fixture.size() - 1
	var last: Dictionary = {}
	for m in s.fixture[s.round_index]:
		if str(m["home"]) == "GEE" or str(m["away"]) == "GEE":
			last = m
	var opp := str(last["away"]) if str(last["home"]) == "GEE" else str(last["home"])
	var above := 0
	for code in s.ladder:
		var row: Dictionary = s.ladder[code]
		row["pct"] = 100.0
		if code == "GEE" or code == opp:
			row["pts"] = 48
		elif above < 9:
			row["pts"] = 60
			above += 1
		else:
			row["pts"] = 40
	(s.ladder["GEE"] as Dictionary)["pct"] = 110.0
	_check(bool(GameState.banner_context(last)["must_win"]), "Win and you're in, lose and you're out: a must-win game")
	(s.ladder["GEE"] as Dictionary)["pts"] = 64
	_check(not bool(GameState.banner_context(last)["must_win"]), "A side safe in the ten has no must-win game")
	(s.ladder["GEE"] as Dictionary)["pts"] = 48
	s.round_index = s.fixture.size() - 2
	var earlier: Dictionary = {}
	for m in s.fixture[s.round_index]:
		if str(m["home"]) == "GEE" or str(m["away"]) == "GEE":
			earlier = m
	_check(not bool(GameState.banner_context(earlier)["must_win"]), "No must-win call before the last round")
	# Spoon: both sides in the bottom three late in the season.
	var pair: Dictionary = s.fixture[s.round_index][0]
	for code in s.ladder:
		(s.ladder[code] as Dictionary)["pts"] = 0 if (code == str(pair["home"]) or code == str(pair["away"])) else 40
	_check(bool(GameState.banner_context(pair)["spoon"]), "Bottom two meeting late in the season: the spoon match")
	s.round_index = 0
	_check(not bool(GameState.banner_context(pair)["spoon"]), "No spoon match in round one")
	# First game: an expansion club's first ever match.
	var tas_year := GameDB.enter_year("TAS")
	GameState.season_year = tas_year
	s.ladder["TAS"] = {"code": "TAS", "p": 0, "w": 0, "l": 0, "d": 0, "pf": 0, "pa": 0, "pts": 0, "pct": 0.0}
	_check(str(GameState.banner_context({"home": "TAS", "away": "GEE"})["first_game"]) == "TAS", "Tasmania's first ever game")
	(s.ladder["TAS"] as Dictionary)["p"] = 1
	_check(str(GameState.banner_context({"home": "TAS", "away": "GEE"})["first_game"]) == "", "Only the first")
	s.ladder.erase("TAS")
	GameState.season_year = yr
	# Premiers: last year's premier in its first game.
	GameState.honour_roll.append({"year": yr - 1, "premier": "COL"})
	(s.ladder["COL"] as Dictionary)["p"] = 0
	_check(str(GameState.banner_context({"home": "COL", "away": "GEE"})["premiers"]) == "COL", "The premiers' flag game")
	(s.ladder["COL"] as Dictionary)["p"] = 3
	_check(str(GameState.banner_context({"home": "COL", "away": "GEE"})["premiers"]) == "", "Not every week")
	GameState.honour_roll.pop_back()
	# Milestone: his next game is a milestone; else a farewell in the last round.
	var squad := GameState.my_squad()
	var side: Array = squad.ground + squad.bench
	for p in side:
		var c := Career.of(p)
		c["games"] = 10
		c["through"] = yr
		c["unknown"] = []
		c["stints"] = []
	var star: Dictionary = side[0]
	Career.of(star)["games"] = 349
	var ms: Dictionary = GameState.banner_context(m0)["milestone"]
	_check(int(ms.get("games", 0)) == 350 and str(GameDB.player_display_name(star)).ends_with(str(ms.get("player", "?"))),
			"A 350th game is the banner's milestone (%s)" % str(ms))
	# FL-002: the director's 200-game line, with his full displayed name.
	Career.of(star)["games"] = 199
	var ctx200 := GameState.banner_context(m0)
	# The texts are placeholders (the director's order, 2026-10-18): his 200th still gets the
	# milestone set, here the club's name, until his own words are in the file.
	_check(str(Banners.texts_for(ctx200)[0]) == "milestone" and Banners.pick(ctx200) == Banners.fill("{us}", ctx200),
			"His 200th picks the milestone set (%s)" % Banners.pick(ctx200).replace("\n", " / "))
	# A player who came from another club: his 100th game in these colours,
	# not a career milestone.
	Career.of(star)["games"] = 140
	Career.of(star)["stints"] = [["XXX", yr - 10, yr - 6, 41, 0], [GameState.my_club, yr - 5, yr, 99, 0]]
	var ctxc := GameState.banner_context(m0)
	var msc: Dictionary = ctxc["milestone"]
	_check(bool(msc.get("club", false)) and int(msc.get("games", 0)) == 100
			and str(Banners.texts_for(ctxc)[0]) == "milestone" and Banners.pick(ctxc) == Banners.fill("{us}", ctxc),
			"His 100th for the club, not his career, is the club's banner (%s)" % str(msc))
	# Out of the side: no message for him.
	var on_list := GameState.list_player(str(star["id"]))
	on_list["injury_weeks"] = 3
	var msx: Dictionary = GameState.banner_context(m0)["milestone"]
	_check(str(msx.get("name", "")) != GameDB.player_display_name(star), "Left out, his banner goes with him")
	on_list["injury_weeks"] = 0
	Career.of(star)["stints"] = []
	Career.of(star)["games"] = 10
	# The squad holds copies of the list's players: mark the list player.
	for p in GameState.my_list:
		if str(p["id"]) == str(star["id"]):
			p["retiring"] = yr + 1
	_check((GameState.banner_context(m0)["milestone"] as Dictionary).is_empty(), "A farewell waits for his last game")
	s.round_index = s.fixture.size() - 1
	_check(str((GameState.banner_context(last)["milestone"] as Dictionary).get("games", "")) == "farewell",
			"His last home-and-away game is a farewell banner (%s)" % str(GameState.banner_context(last)["milestone"]))
	GameState.reset()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## The New career menu's two dials, as the setup screen sets them.
func _menu(board: String, rivals: String) -> void:
	GameState.set_new_career_dial("board_patience", board)
	GameState.set_new_career_dial("rival_recruiting", rivals)


func _test_difficulty() -> void:
	GameState.reset()
	_check(GameState.board_patience == "fair" and GameState.rival_recruiting == "shrewd",
			"A new career starts on the middle step of both dials, the tuned league")
	_menu("ruthless", "cutthroat")
	GameState.reset()
	_check(GameState.board_patience == "ruthless" and GameState.rival_recruiting == "cutthroat",
			"The menu's dials apply to the next career")
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	# Difficulty never changes how players develop: the same rival gains the
	# same on the hardest and easiest dials, and the same game pays your
	# players the same XP.
	var rival: Dictionary = (GameState.season.lists["ADE"] as Array)[0]
	var gains := []
	for pair in [["ruthless", "cutthroat"], ["patient", "easygoing"]]:
		GameState.board_patience = pair[0]
		GameState.rival_recruiting = pair[1]
		var q := rival.duplicate(true)
		q["xp"] = 100000
		q["potential"] = int(q["overall"]) + 12
		q["season_start_ov"] = int(q["overall"])
		GameState.ai_spend_xp(q)
		gains.append(int(q["overall"]) - int(rival["overall"]))
	_check(gains[0] == gains[1], "Rivals develop the same on the hardest and easiest dials (%s)" % str(gains))

	GameState.board_patience = "fair"
	GameState.rival_recruiting = "shrewd"
	GameState.advance()
	var res: Dictionary = GameState.last_match
	var normal_xp := int(GameState.grant_match_xp(res)["total"])
	GameState.board_patience = "patient"
	GameState.rival_recruiting = "easygoing"
	var easy_xp := int(GameState.grant_match_xp(res)["total"])
	_check(easy_xp == normal_xp, "Your players earn the same XP on any dial (%d vs %d)" % [easy_xp, normal_xp])

	# Saved with the career, not taken from the menu setting.
	GameState.board_patience = "ruthless"
	GameState.rival_recruiting = "easygoing"
	_check(GameState.save_career(), "The career saves")
	var saved := CareerSave.read(GameState.save_path)
	_check(str(saved.get("board_patience", "")) == "ruthless" and str(saved.get("rival_recruiting", "")) == "easygoing",
			"The save carries board_patience and rival_recruiting")
	_menu("patient", "cutthroat")
	_check(GameState.load_career() and GameState.board_patience == "ruthless"
			and GameState.rival_recruiting == "easygoing", "A loaded career keeps its own dials")
	# The dials are data (data/difficulty_dials.json): both have three named
	# steps, the middle one is today's game, and nothing but those sizes moves.
	for dial in DifficultyDials.DIALS:
		_check(DifficultyDials.order(dial).size() == 3 and DifficultyDials.order(dial)[1] == DifficultyDials.default_key(dial),
				"%s has three steps and starts on the middle one" % dial)
		for key in DifficultyDials.order(dial):
			var st := DifficultyDials.step(dial, key)
			_check(str(st.get("label", "")) != "" and str(st.get("text", "")) != "" and not str(st["text"]).contains("%"),
					"%s / %s is named and said in a plain sentence with no percentage" % [dial, key])
	_check(float(DifficultyDials.step("rival_recruiting", "shrewd")["trade_margin"]) == Contracts.TRADE_MARGIN
			and int(DifficultyDials.step("board_patience", "fair")["poor_seasons_before_warning"]) == 1
			and int(DifficultyDials.step("board_patience", "fair")["poor_season_below"]) == ClubLife.WARN_LINE,
			"The middle steps are what the game played before the dials")
	# An old career (saved with only easy / normal / hard) keeps its board: the
	# old difficulty never touched the board, so every old save gets the middle
	# step (Fair). Only the rivals follow the old difficulty.
	var expect := {"easy": ["fair", "easygoing"], "normal": ["fair", "shrewd"], "hard": ["fair", "cutthroat"]}
	var mapped := true
	for level in expect:
		var old := CareerSave.read(GameState.save_path)
		old.erase("board_patience")
		old.erase("rival_recruiting")
		old["difficulty"] = level
		CareerSave.write(old, CareerSave.read_meta(GameState.save_path), GameState.save_path)
		GameState.board_patience = "fair"
		GameState.rival_recruiting = "shrewd"
		mapped = mapped and GameState.load_career() and GameState.board_patience == expect[level][0] \
				and GameState.rival_recruiting == expect[level][1]
	_check(mapped, "An old Easy / Normal / Hard save keeps the Fair board and takes the matching rivals")
	var odd := CareerSave.read(GameState.save_path)
	odd["board_patience"] = "gone"
	odd["rival_recruiting"] = 7
	CareerSave.write(odd, CareerSave.read_meta(GameState.save_path), GameState.save_path)
	_check(GameState.load_career() and GameState.board_patience == "fair" and GameState.rival_recruiting == "shrewd",
			"A step this build does not know falls back to the middle one")
	# The menu setting of a device that only ever chose Easy / Normal / Hard.
	GameState.set_setting("board_patience", "")
	GameState.set_setting("rival_recruiting", "")
	GameState.set_setting("difficulty", "hard")
	_check(GameState.new_career_dial("board_patience") == "fair" and GameState.new_career_dial("rival_recruiting") == "cutthroat",
			"An old menu setting starts the next career on the Fair board and the matching rivals")
	GameState.set_setting("difficulty", "normal")
	_menu("fair", "shrewd")


func _test_trade_margin() -> void:
	var template: Dictionary = (GameDB.club_list("GEE") as Array)[0].duplicate(true)
	template["role"] = "MID"
	template["salary"] = 1
	var ai_list := []
	var my_list := []
	for i in range(36):
		var a := template.duplicate(true)
		a["id"] = "ai_%d" % i
		ai_list.append(a)
		var b := template.duplicate(true)
		b["id"] = "me_%d" % i
		my_list.append(b)
	# The same even swap, offered at each step of the rival dial.
	var verdicts := {}
	for key in DifficultyDials.order("rival_recruiting"):
		_menu("fair", key)
		GameState.reset()
		verdicts[key] = bool(Contracts.evaluate_trade(ai_list, [ai_list[0]], [my_list[0]], 999, my_list, 999,
				float(GameState.difficulty_rules()["trade_margin"]))["ok"])
	_check(verdicts["easygoing"] and not verdicts["shrewd"] and not verdicts["cutthroat"],
			"An even swap is accepted by Easygoing rivals but refused by Shrewd and Cut-throat ones (%s)" % str(verdicts))
	var m := func(key: String) -> float:
		return float(DifficultyDials.step("rival_recruiting", key)["trade_margin"])
	_check(m.call("cutthroat") > m.call("shrewd") and m.call("shrewd") > m.call("easygoing"),
			"Rivals drive harder bargains step by step")
	_menu("fair", "shrewd")


func _test_marquee_games() -> void:
	_check(MarqueeGames.label("ESS", "COL") == "ANZAC Day",
			"Essendon-Collingwood carries the ANZAC Day tradition")
	_check(MarqueeGames.label("COL", "ESS") == "ANZAC Day",
			"Marquee identity is independent of generated home/away order")
	_check(MarqueeGames.label("MEL", "COL") == "King's Birthday",
			"Melbourne-Collingwood carries King's Birthday")
	_check(MarqueeGames.label("HAW", "GEE") == "Easter Monday",
			"Hawthorn-Geelong carries Easter Monday")
	_check(MarqueeGames.label("ADE", "GEE").is_empty(),
			"An ordinary fixture is not labelled marquee")

func _test_news() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	_check(GameState.news.is_empty(), "A new career has no news yet")
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	var kinds := {}
	for item in GameState.news:
		kinds[str(item["kind"])] = true
	_check(not GameState.news.is_empty() and GameState.news.size() <= GameState.MAX_NEWS,
			"A season fills the news feed, within its limit (%d items)" % GameState.news.size())
	_check(kinds.has("award") and kinds.has("premiers"), "The awards and the premiers make the news")
	_check(kinds.has("game") or kinds.has("injury") or kinds.has("development"),
			"Big games, injuries or rival development make the news (%s)" % str(kinds.keys()))
	var newest: Dictionary = GameState.news[0]
	_check(str(newest["text"]).contains("premiers"), "Newest first: the premiers top the feed")
	_check(GameState.save_career() and GameState.load_career() and not GameState.news.is_empty(),
			"The news survives a save and load")


## Real names are the default. With no settings file, or one that never recorded
## a name choice, a fresh game shows them; generated labels are opt-in, a saved
## choice is kept on the next start either way, and generated players keep the
## name they were given.
func _test_real_names_default() -> void:
	var gs_script = load("res://scripts/state/GameState.gd")
	var path := "user://test_names_settings.cfg"
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	var fresh = gs_script.new()
	fresh.settings_path = path
	_check(fresh.show_real_names, "A fresh game with no settings file shows real names")
	fresh.free()
	# A settings file that only records an appearance, never a name choice.
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "appearance", "dark")
	cfg.save(path)
	var no_choice = gs_script.new()
	no_choice.settings_path = path
	no_choice._ready()
	_check(no_choice.show_real_names, "Settings that never recorded a name choice still show real names")
	# Generated names are opt-in, and the choice is kept on the next start.
	no_choice.set_show_real_names(false)
	var later = gs_script.new()
	later.settings_path = path
	later._ready()
	_check(not later.show_real_names, "Choosing generated names is kept for the next start")
	later.set_show_real_names(true)
	var again = gs_script.new()
	again.settings_path = path
	again._ready()
	_check(again.show_real_names, "Choosing real names again is kept too")
	# A choice saved before the default changed is not overridden by it.
	var old := ConfigFile.new()
	old.set_value("display", "real_names", false)
	old.save(path)
	var kept = gs_script.new()
	kept.settings_path = path
	kept._ready()
	_check(not kept.show_real_names, "A saved choice of generated names is not overridden by the new default")
	for g in [no_choice, later, again, kept]:
		g.free()
	DirAccess.remove_absolute(abs_path)
	# Real names change real players only: a generated prospect keeps his name.
	var was: bool = GameState.show_real_names
	GameState.show_real_names = true
	var generated := {"id": "GEN_9", "generic_name": "Zed Quill", "name": "Zed Quill"}
	var real := {"id": "R_1", "generic_name": "Ari Bramble", "name": "Ari Bramble", "real_name": "Jordan Dawson"}
	_check(GameDB.player_display_name(generated) == "Zed Quill" and GameDB.player_display_name(real) == "Jordan Dawson",
			"Real names show for real players; a generated player keeps his own name")
	GameState.show_real_names = was
