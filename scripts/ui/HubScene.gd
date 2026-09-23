extends Control
## Season hub: your next match, the ladder snapshot, and the round controls.

var _root: VBoxContainer
var _results_overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)

	_root = UiKit.vbox(10)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_on_resize)
	_build()


func _on_resize() -> void:
	if not is_inside_tree() or GameState.season == null:
		return
	_build()


func _content_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


func _narrow() -> bool:
	return _content_width() < 680.0


func _build() -> void:
	UiKit.clear(_root)
	GameState.ensure_finals()

	var season: Season = GameState.season
	_root.add_child(UiKit.top_bar("Season Hub  ·  %d" % GameState.season_year, false))

	var cards: BoxContainer
	if _narrow():
		cards = UiKit.vbox(8)
	else:
		cards = UiKit.hbox(10)
	_root.add_child(cards)
	cards.add_child(_standing_card())
	cards.add_child(_next_card(season))

	var lp := UiKit.panel(UiKit.PANEL, 12)
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(lp)
	var lv := UiKit.vbox(4)
	lp.add_child(lv)
	lv.add_child(UiKit.lbl("Ladder", 17, UiKit.GOLD, true))
	var grid := UiKit.ladder_table(season.ladder_sorted(), GameState.my_club,
			_content_width() - 24.0, 8, false)
	lv.add_child(UiKit.scroll(grid))

	_root.add_child(_controls(season))


func _standing_card() -> Control:
	var card := UiKit.panel(UiKit.PANEL, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := UiKit.vbox(4)
	card.add_child(cv)
	cv.add_child(UiKit.club_badge(GameState.my_club, 18, false, true))
	var title := UiKit.lbl("Position %d of %d" % [GameState.my_position(),
			GameDB.CLUB_ORDER.size()], 22 if _narrow() else 26, UiKit.GOLD, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	cv.add_child(title)
	var lr := GameState.my_ladder_row()
	cv.add_child(UiKit.lbl("%s   -   %d pts" % [GameState.my_record(),
			int(lr.get("pts", 0))], 14, UiKit.TEXT))
	cv.add_child(UiKit.lbl("%d for, %d against   -   %.1f%%" % [
			int(lr.get("pf", 0)), int(lr.get("pa", 0)),
			float(lr.get("pct", 0.0))], 13, UiKit.MUTED))
	var injured := Injuries.injured(GameState.my_list)
	if not injured.is_empty():
		cv.add_child(UiKit.lbl("Injury list: %d  -  check your Team" % injured.size(), 13, UiKit.BAD))
	return card


func _next_card(season: Season) -> Control:
	var nxt := UiKit.panel(UiKit.PANEL, 14)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nv := UiKit.vbox(4)
	nxt.add_child(nv)
	if season.is_season_over():
		nv.add_child(UiKit.lbl("Season Complete", 20, UiKit.GOLD, true))
		nv.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(GameState.premier()),
				16, UiKit.TEXT))
		var ru: String = str(season.finals.get("runner_up", ""))
		nv.add_child(UiKit.ellipsis("Runners-up: %s" % GameDB.club_name(ru),
				13, UiKit.MUTED))
		var medal: Array = GameState.season_awards.get("brownlow", [])
		if not medal.is_empty():
			nv.add_child(UiKit.ellipsis("Brownlow: %s (%d votes)" % [
					GameState.award_name(medal[0]), int(medal[0]["votes"])], 13, UiKit.GOLD))
	elif _upcoming_match().is_empty():
		match GameState.my_finals_status():
			"bye":
				nv.add_child(UiKit.lbl("Week Off", 20, UiKit.GOOD, true))
				nv.add_child(UiKit.lbl(
						"You won your qualifying final. Sim the semi finals, then host a preliminary final.",
						13, UiKit.MUTED))
			"eliminated":
				nv.add_child(UiKit.lbl("Knocked Out", 20, UiKit.BAD, true))
				nv.add_child(UiKit.lbl(
						"Your finals campaign is over. Sim the rest of the series to see who lifts the cup.",
						13, UiKit.MUTED))
			_:
				nv.add_child(UiKit.lbl("Season Over For You", 20, UiKit.BAD, true))
				nv.add_child(UiKit.lbl(
						"You missed the eight. Sim the finals series to see who lifts the cup.",
						13, UiKit.MUTED))
	else:
		var phase := "Round %d of %d" % [season.round_index + 1, Season.REGULAR_ROUNDS] \
				if not season.is_regular_done() else _finals_label()
		nv.add_child(UiKit.ellipsis(phase, 18, UiKit.TEXT, true))
		var mine: Dictionary = _upcoming_match()
		var opp: String = mine["away"] if mine["home"] == GameState.my_club else mine["home"]
		var is_home: bool = mine["home"] == GameState.my_club
		nv.add_child(UiKit.ellipsis("%s %s" % ["vs" if is_home else "at",
				GameDB.club_name(opp)], 22 if _narrow() else 26, UiKit.GOLD, true))
		var ground: String = str(GameDB.club(str(mine["home"])).get("ground", ""))
		var note := "%s  -  %s" % [mine.get("label", "Match"), ground]
		if mine.get("neutral", false):
			note = "%s  -  neutral venue" % mine.get("label", "Match")
		nv.add_child(UiKit.ellipsis(note, 13, UiKit.MUTED))
	return nxt


func _controls(season: Season) -> Control:
	var buttons: Array = []
	if season.is_season_over():
		var resume := GameState.draft != null and GameState.draft.intake_mode
		buttons.append(_nav_button("Resume National Draft" if resume
				else "%d National Draft" % GameState.season_year, _on_intake_draft, true))
		buttons.append(_nav_button("Season Review", func(): Router.go("season_review")))
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("Main Menu", func(): Router.to_main_menu()))
	elif _upcoming_match().is_empty() and GameState.my_finals_status() == "bye":
		# Still alive: sim only this week, never past your own final.
		buttons.append(_nav_button("Sim %s" % _finals_label(), _on_sim_round, true))
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("Full Ladder", func(): Router.go("ladder")))
		buttons.append(_nav_button("My List", func(): Router.go("list")))
	elif _upcoming_match().is_empty():
		buttons.append(_nav_button("Sim to Grand Final", _on_sim_to_end, true))
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("Full Ladder", func(): Router.go("ladder")))
		buttons.append(_nav_button("My List", func(): Router.go("list")))
	else:
		buttons.append(_nav_button("Play Match", _on_play_match, true))
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("Sim Round", _on_sim_round))
		buttons.append(_nav_button("Full Ladder", func(): Router.go("ladder")))
		buttons.append(_nav_button("My List", func(): Router.go("list")))
	if _content_width() < 720.0:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for b in buttons:
			grid.add_child(b)
		return grid
	var row := UiKit.hbox(8)
	for b in buttons:
		row.add_child(b)
	return row


func _nav_button(text: String, cb: Callable, primary := false) -> Button:
	var b := UiKit.btn(text, 16, primary)
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(cb)
	return b


func _finals_label() -> String:
	var w := int(GameState.season.finals.get("week", 1))
	return ["Finals Week 1", "Semi Finals", "Preliminary Finals",
			"Grand Final"][clampi(w - 1, 0, 3)]


## The match you are about to play, or {} if you have none coming up
## (missed the eight, or already eliminated). Unified across the home and
## away season and the finals so the hub card and the buttons can share it.
func _upcoming_match() -> Dictionary:
	var season: Season = GameState.season
	if season == null or season.is_season_over():
		return {}
	if not season.is_regular_done():
		var round_matches: Array = season.fixture[season.round_index]
		for m in round_matches:
			if m["home"] == GameState.my_club or m["away"] == GameState.my_club:
				return {"home": m["home"], "away": m["away"],
						"label": "Round %d" % (season.round_index + 1),
						"tag": "", "neutral": false}
		return {}
	for m in season.finals_week_matches():
		if str(m["home"]) == "" or str(m["away"]) == "":
			continue
		if m["home"] == GameState.my_club or m["away"] == GameState.my_club:
			return {"home": m["home"], "away": m["away"],
					"label": str(m["label"]), "tag": str(m["tag"]),
					"neutral": str(m["tag"]) == "GF"}
	return {}


func _ladder_grid(_limit: int) -> Control:
	return UiKit.ladder_table(GameState.season.ladder_sorted(), GameState.my_club,
			_content_width() - 24.0, 8, false)


# ---------------------------------------------------------------------------
# Round control
# ---------------------------------------------------------------------------
func _on_play_match() -> void:
	if _upcoming_match().is_empty():
		_on_sim_round()
		return
	# Home-and-away rounds and finals both play live with the coach box.
	if GameState.prepare_interactive_match():
		Router.go("match")
		return
	_on_sim_round()


func _on_sim_round() -> void:
	GameState.advance()
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## You are out of the finals: run the remaining weeks out and show the winner.
func _on_sim_to_end() -> void:
	var guard := 0
	while not GameState.season.is_season_over() and guard < 8:
		GameState.advance()
		guard += 1
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## Router back hook: close the results popup before leaving the hub.
func handle_back() -> bool:
	if _results_overlay != null and is_instance_valid(_results_overlay):
		_results_overlay.queue_free()
		_results_overlay = null
		_build()
		return true
	return false


func _show_results(results: Array) -> void:
	if _results_overlay != null and is_instance_valid(_results_overlay):
		_results_overlay.queue_free()

	var box := UiKit.modal_box(self, 660.0, 560.0)
	var overlay: Control = box["overlay"]
	_results_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis(GameState.last_label, 22, UiKit.GOLD, true))
	v.add_child(_results_list(results))
	var report: Dictionary = GameState.last_training_report
	if not GameState.last_match.is_empty() and int(report.get("count", 0)) > 0:
		v.add_child(UiKit.lbl("Your list gained %d XP across %d players." % [
				int(report["total"]), int(report["count"])], 14, UiKit.TEXT, true))
		var spent := GameState.training_summary_line()
		if spent != "":
			v.add_child(UiKit.lbl(spent, 13, UiKit.GOOD))
	var hurt := GameState.my_new_injuries()
	if not hurt.is_empty():
		var inj := UiKit.lbl("Injured: " + ", ".join(hurt), 13, UiKit.BAD, true)
		inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(inj)
	var outlook := GameState.finals_outcome_line(GameState.last_match)
	if outlook != "":
		v.add_child(UiKit.lbl(outlook, 15, UiKit.GOLD, true))
	if GameState.season.is_season_over():
		v.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(GameState.premier()),
				18, UiKit.TEXT, true))
	if not GameState.last_match.is_empty():
		var train := UiKit.btn("Training", 16)
		train.pressed.connect(func():
			overlay.queue_free()
			Router.go("training"))
		box["footer"].add_child(train)
	var ok := UiKit.btn("Continue", 17, true)
	ok.pressed.connect(func():
		overlay.queue_free()
		_results_overlay = null
		_build())
	box["footer"].add_child(ok)


func _results_list(results: Array) -> Control:
	var v := UiKit.vbox(6)
	var narrow := _content_width() < 520.0
	for res in results:
		var mine: bool = GameState.is_my_match(res)
		var col := UiKit.GOLD if mine else UiKit.TEXT
		var s: Array = res["score"]
		var home_is_me: bool = str(res["home"]) == GameState.my_club
		var won: bool = (s[0] > s[1] and home_is_me) or (s[1] > s[0] and not home_is_me)
		var drew: bool = s[0] == s[1]
		var verdict := ""
		if mine:
			verdict = "DRAW" if drew else ("WON" if won else "LOST")
		if narrow:
			var block := UiKit.vbox(2)
			block.add_child(_result_side(str(res["home"]), int(res["goals"][0]),
					int(res["behinds"][0]), col, verdict if home_is_me else ""))
			block.add_child(_result_side(str(res["away"]), int(res["goals"][1]),
					int(res["behinds"][1]), col, verdict if not home_is_me else ""))
			v.add_child(block)
		else:
			var h := UiKit.hbox(6)
			h.add_child(UiKit.club_badge(str(res["home"]), 13, true, true))
			var hs := UiKit.line(UiKit.scoreline(int(res["goals"][0]), int(res["behinds"][0])),
					14, col, true)
			hs.custom_minimum_size = Vector2(78, 0)
			h.add_child(hs)
			h.add_child(UiKit.line("def", 12, UiKit.MUTED))
			var asc := UiKit.line(UiKit.scoreline(int(res["goals"][1]), int(res["behinds"][1])),
					14, col, true)
			asc.custom_minimum_size = Vector2(78, 0)
			h.add_child(asc)
			h.add_child(UiKit.club_badge(str(res["away"]), 13, true, true))
			if verdict != "":
				var tag := UiKit.line(verdict, 13,
						UiKit.MUTED if drew else UiKit.margin_colour(won), true)
				tag.custom_minimum_size = Vector2(48, 0)
				h.add_child(tag)
			v.add_child(h)
	return v


func _result_side(code: String, goals: int, behinds: int, col: Color, verdict: String) -> Control:
	var h := UiKit.hbox(6)
	h.add_child(UiKit.club_badge(code, 13, true, true))
	var score := UiKit.line(UiKit.scoreline(goals, behinds), 14, col, true)
	score.custom_minimum_size = Vector2(78, 0)
	h.add_child(score)
	if verdict != "":
		var tag := UiKit.line(verdict, 13, col, true)
		h.add_child(tag)
	return h


func _on_intake_draft() -> void:
	if GameState.begin_intake_draft():
		Router.go("draft")
		return
	if GameState.start_next_season():
		_build()
