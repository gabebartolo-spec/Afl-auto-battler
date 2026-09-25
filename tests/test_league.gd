extends RefCounted
## Difficulty and the league news feed. Run through tests/run_league_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	GameState.set_new_career_difficulty("normal")
	_test_difficulty()
	_test_trade_margin()
	_test_news()
	GameState.set_new_career_difficulty("normal")
	GameState.delete_saved_career()
	print("League tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
		print("::error::league :: " + message)  # TEMP-CI-DIAG


func _test_difficulty() -> void:
	GameState.reset()
	_check(GameState.difficulty == "normal" and GameState.rival_season_gain() == GameState.AI_SEASON_GAIN,
			"A new career starts on Normal, the tuned league")
	GameState.set_new_career_difficulty("hard")
	GameState.reset()
	_check(GameState.difficulty == "hard", "The menu's difficulty applies to the next career")
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var rival: Dictionary = (GameState.season.lists["ADE"] as Array)[0]
	var hard := rival.duplicate(true)
	hard["xp"] = 100000
	hard["potential"] = int(hard["overall"]) + 12
	hard["season_start_ov"] = int(hard["overall"])
	GameState.ai_spend_xp(hard)
	var hard_gain := int(hard["overall"]) - int(rival["overall"])
	GameState.difficulty = "easy"
	var easy := rival.duplicate(true)
	easy["xp"] = 100000
	easy["potential"] = int(easy["overall"]) + 12
	easy["season_start_ov"] = int(easy["overall"])
	GameState.ai_spend_xp(easy)
	var easy_gain := int(easy["overall"]) - int(rival["overall"])
	_check(hard_gain >= 4 and easy_gain <= 2 and hard_gain > easy_gain,
			"Rivals develop further on Hard than on Easy (%d vs %d)" % [hard_gain, easy_gain])

	# Your XP: the same game pays more on Easy than on Normal.
	GameState.difficulty = "normal"
	GameState.advance()
	var res: Dictionary = GameState.last_match
	var normal_xp := int(GameState.grant_match_xp(res)["total"])
	GameState.difficulty = "easy"
	var easy_xp := int(GameState.grant_match_xp(res)["total"])
	_check(easy_xp > normal_xp, "Your players earn more XP on Easy (%d vs %d)" % [easy_xp, normal_xp])

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
