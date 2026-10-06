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
	GameState.set_new_career_difficulty("normal")
	_test_difficulty()
	_test_trade_margin()
	_test_news()
	_test_marquee_games()
	_test_real_names_default()
	GameState.set_new_career_difficulty("normal")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("League tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_difficulty() -> void:
	GameState.reset()
	_check(GameState.difficulty == "normal", "A new career starts on Normal, the tuned league")
	GameState.set_new_career_difficulty("hard")
	GameState.reset()
	_check(GameState.difficulty == "hard", "The menu's difficulty applies to the next career")
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	# Difficulty never changes how players develop: the same rival gains the
	# same on Hard and Easy, and the same game pays your players the same XP.
	var rival: Dictionary = (GameState.season.lists["ADE"] as Array)[0]
	var gains := []
	for level in ["hard", "easy"]:
		GameState.difficulty = level
		var q := rival.duplicate(true)
		q["xp"] = 100000
		q["potential"] = int(q["overall"]) + 12
		q["season_start_ov"] = int(q["overall"])
		GameState.ai_spend_xp(q)
		gains.append(int(q["overall"]) - int(rival["overall"]))
	_check(gains[0] == gains[1], "Rivals develop the same on Hard and Easy (%s)" % str(gains))

	GameState.difficulty = "normal"
	GameState.advance()
	var res: Dictionary = GameState.last_match
	var normal_xp := int(GameState.grant_match_xp(res)["total"])
	GameState.difficulty = "easy"
	var easy_xp := int(GameState.grant_match_xp(res)["total"])
	_check(easy_xp == normal_xp, "Your players earn the same XP on any difficulty (%d vs %d)" % [easy_xp, normal_xp])

	# Saved with the career, not taken from the menu setting.
	GameState.difficulty = "hard"
	_check(GameState.save_career(), "The career saves")
	GameState.set_new_career_difficulty("easy")
	_check(GameState.load_career() and GameState.difficulty == "hard",
			"A loaded career keeps its own difficulty")
	GameState.set_new_career_difficulty("normal")


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
	var fair := Contracts.evaluate_trade(ai_list, [ai_list[0]], [my_list[0]], 999, my_list, 999, 0.0)
	var normal := Contracts.evaluate_trade(ai_list, [ai_list[0]], [my_list[0]], 999, my_list, 999,
			float(GameState.DIFFICULTIES["normal"]["trade_margin"]))
	_check(bool(fair["ok"]) and not bool(normal["ok"]),
			"An even swap is accepted on Easy but rivals want a margin on Normal")
	_check(float(GameState.DIFFICULTIES["hard"]["trade_margin"]) > float(GameState.DIFFICULTIES["normal"]["trade_margin"]),
			"Rivals drive harder bargains on Hard")



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
