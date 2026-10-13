	var conf_before := GameState.board_confidence()
	var paper_man: Dictionary = GameState.my_list[2]
	var paper_morale := ClubLife.morale(paper_man)
	GameState.week_event = GameState.story_card("media_in_the_papers", paper_man)
	var silence: Dictionary = {}
	if GameState.week_event is Dictionary:
		var candidate = GameState.week_event.get("unanswered")
		if candidate is Dictionary:
			silence = candidate
	var board_cost := int(silence.get("board", 0))
	var hint := str(silence.get("hint", ""))
	_check(board_cost == -4 and hint.contains("board"),
			"The card says what saying nothing costs: %s" % hint)
	GameState._settle_week_event()
	_check(GameState.board_confidence() == clampi(conf_before - 4, 0, 100) and ClubLife.morale(paper_man) == paper_morale,
			"Saying nothing about an incident costs the board, and lifts nobody")
	GameState.advance()
	var heavy := GameState.story_card("training_extra_session")
	GameState.week_event = heavy
	GameState.resolve_week_event(0)
	var p3: Dictionary = GameState.my_list[3]
