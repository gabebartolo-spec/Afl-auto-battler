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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_root = UiKit.vbox(10)
	margin.add_child(_root)
	_build()


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()

	var season: Season = GameState.season
	_root.add_child(UiKit.top_bar("Season Hub", false))

	# --- your standing ------------------------------------------------------
	var row := UiKit.hbox(10)
	_root.add_child(row)

	var card := UiKit.panel(UiKit.PANEL, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var cv := UiKit.vbox(4)
	card.add_child(cv)
	cv.add_child(UiKit.club_badge(GameState.my_club, 20))
	cv.add_child(UiKit.lbl("Position %d of %d" % [GameState.my_position(),
			GameDB.CLUB_ORDER.size()], 26, UiKit.GOLD, true))
	var lr := GameState.my_ladder_row()
	cv.add_child(UiKit.lbl("%s   -   %d pts" % [GameState.my_record(),
			int(lr.get("pts", 0))], 14, UiKit.TEXT))
	cv.add_child(UiKit.lbl("%d for, %d against   -   %.1f%%" % [
			int(lr.get("pf", 0)), int(lr.get("pa", 0)),
			float(lr.get("pct", 0.0))], 13, UiKit.MUTED))

	var nxt := UiKit.panel(UiKit.PANEL, 14)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nxt)
	var nv := UiKit.vbox(4)
	nxt.add_child(nv)

	if season.is_season_over():
		nv.add_child(UiKit.lbl("Season Complete", 20, UiKit.GOLD, true))
		nv.add_child(UiKit.lbl("Premiers: %s" % GameDB.club_name(GameState.premier()),
				16, UiKit.TEXT))
		var ru: String = str(season.finals.get("runner_up", ""))
		nv.add_child(UiKit.lbl("Runners-up: %s" % GameDB.club_name(ru),
				13, UiKit.MUTED))
	elif _upcoming_match().is_empty():
		nv.add_child(UiKit.lbl("Season Over For You", 20, UiKit.BAD, true))
		nv.add_child(UiKit.lbl(
				"You missed the eight. Sim the finals series to see who lifts the cup.",
				13, UiKit.MUTED))
	else:
		var phase := "Round %d of %d" % [season.round_index + 1, Season.REGULAR_ROUNDS] \
				if not season.is_regular_done() else _finals_label()
		nv.add_child(UiKit.lbl(phase, 20, UiKit.TEXT, true))
		var mine: Dictionary = _upcoming_match()
		var opp: String = mine["away"] if mine["home"] == GameState.my_club else mine["home"]
		var is_home: bool = mine["home"] == GameState.my_club
		nv.add_child(UiKit.lbl("%s %s" % ["vs" if is_home else "at",
				GameDB.club_name(opp)], 26, UiKit.GOLD, true))
		var ground: String = str(GameDB.club(str(mine["home"])).get("ground", ""))
		var note := "%s  -  %s" % [mine.get("label", "Match"), ground]
		if mine.get("neutral", false):
			note = "%s  -  neutral venue" % mine.get("label", "Match")
		nv.add_child(UiKit.lbl(note, 13, UiKit.MUTED))

	# --- ladder snapshot ----------------------------------------------------
	var lp := UiKit.panel(UiKit.PANEL, 12)
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(lp)
	var lv := UiKit.vbox(4)
	lp.add_child(lv)
	lv.add_child(UiKit.lbl("Ladder", 17, UiKit.GOLD, true))
	var grid := _ladder_grid(8)
	lv.add_child(UiKit.scroll(grid))

	# --- controls -----------------------------------------------------------
	var ctrl := UiKit.hbox(10)
	ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(ctrl)

	if season.is_season_over():
		var rev := UiKit.btn("Season Review", 17, true)
		rev.custom_minimum_size = Vector2(240, 50)
		rev.pressed.connect(func(): Router.go("season_review"))
		ctrl.add_child(rev)
		var menu := UiKit.btn("Main Menu", 17)
		menu.custom_minimum_size = Vector2(200, 50)
		menu.pressed.connect(func(): Router.to_main_menu())
		ctrl.add_child(menu)
	elif _upcoming_match().is_empty():
		var fwd := UiKit.btn("Sim to Grand Final", 18, true)
		fwd.custom_minimum_size = Vector2(260, 52)
		fwd.pressed.connect(_on_sim_to_end)
		ctrl.add_child(fwd)
		ctrl.add_child(_nav_button("Full Ladder", func(): Router.go("ladder")))
		ctrl.add_child(_nav_button("My List", func(): Router.go("list")))
	else:
		var play := UiKit.btn("Play Match", 18, true)
		play.custom_minimum_size = Vector2(240, 52)
		play.pressed.connect(_on_play_match)
		ctrl.add_child(play)

		ctrl.add_child(_nav_button("Sim Round", _on_sim_round))
		ctrl.add_child(_nav_button("Full Ladder", func(): Router.go("ladder")))
		ctrl.add_child(_nav_button("My List", func(): Router.go("list")))


func _nav_button(text: String, cb: Callable) -> Button:
	var b := UiKit.btn(text, 17)
	b.custom_minimum_size = Vector2(190, 52)
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


func _ladder_grid(limit: int) -> Control:
	var v := UiKit.vbox(2)
	var rows := GameState.season.ladder_sorted()
	v.add_child(_ladder_header())
	for i in range(rows.size()):
		if limit > 0 and i >= limit:
			break
		v.add_child(_ladder_row(rows[i], i + 1))
		if i == Season.FINALISTS - 1:
			v.add_child(_finals_line())
	return v


func _finals_line() -> Control:
	var l := UiKit.lbl("- - -  top 8 make the finals  - - -", 11, UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _ladder_header() -> Control:
	var h := UiKit.hbox(6)
	h.add_child(_cell("#", 34, UiKit.MUTED, 12))
	h.add_child(_cell("Club", 0, UiKit.MUTED, 12, true))
	for t in [["P", 30], ["W", 30], ["L", 30], ["D", 30], ["%", 56], ["Pts", 44]]:
		h.add_child(_cell(t[0], t[1], UiKit.MUTED, 12))
	return h


func _ladder_row(r: Dictionary, pos: int) -> Control:
	var h := UiKit.hbox(6)
	var mine: bool = r["code"] == GameState.my_club
	var col := UiKit.TEXT if mine else UiKit.MUTED
	if mine:
		col = UiKit.GOLD
	h.add_child(_cell(str(pos), 34, col, 14, mine))
	var badge := UiKit.club_badge(str(r["code"]), 14)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(badge)
	h.add_child(_cell(str(int(r["p"])), 30, col, 14))
	h.add_child(_cell(str(int(r["w"])), 30, col, 14))
	h.add_child(_cell(str(int(r["l"])), 30, col, 14))
	h.add_child(_cell(str(int(r["d"])), 30, col, 14))
	h.add_child(_cell("%.1f" % r["pct"], 56, col, 14))
	h.add_child(_cell(str(int(r["pts"])), 44, col, 14, true))
	return h


func _cell(text: String, min_w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.lbl(text, fs, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
	return l


# ---------------------------------------------------------------------------
# Round control
# ---------------------------------------------------------------------------
func _on_play_match() -> void:
	if _upcoming_match().is_empty():
		_on_sim_round()
		return
	if not GameState.season.is_regular_done() and GameState.prepare_interactive_match():
		Router.go("match")
		return
	GameState.advance()
	if GameState.last_match.is_empty():
		_on_sim_round()
		return
	Router.go("match")


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


func _show_results(results: Array) -> void:
	if _results_overlay != null and is_instance_valid(_results_overlay):
		_results_overlay.queue_free()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_results_overlay = overlay

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)

	var p := UiKit.panel(UiKit.PANEL, 20, 12)
	p.custom_minimum_size = Vector2(660, 0)
	centre.add_child(p)
	var v := UiKit.vbox(8)
	p.add_child(v)

	v.add_child(UiKit.lbl(GameState.last_label, 22, UiKit.GOLD, true))
	v.add_child(UiKit.scroll(_results_list(results)))

	if GameState.season.is_season_over():
		v.add_child(UiKit.lbl("Premiers: %s" % GameDB.club_name(GameState.premier()),
				18, UiKit.TEXT, true))

	var ok := UiKit.btn("Continue", 17, true)
	ok.pressed.connect(func():
		overlay.queue_free()
		_results_overlay = null
		_build())
	v.add_child(ok)


func _results_list(results: Array) -> Control:
	var v := UiKit.vbox(3)
	for res in results:
		var h := UiKit.hbox(8)
		var mine: bool = GameState.is_my_match(res)
		var col := UiKit.GOLD if mine else UiKit.TEXT
		var s: Array = res["score"]

		var hb := UiKit.club_badge(str(res["home"]), 14)
		hb.custom_minimum_size = Vector2(150, 0)
		h.add_child(hb)
		var hs := UiKit.lbl(UiKit.scoreline(int(res["goals"][0]), int(res["behinds"][0])), 15, col, true)
		hs.custom_minimum_size = Vector2(90, 0)
		hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(hs)
		h.add_child(UiKit.lbl("def", 12, UiKit.MUTED))
		var asc := UiKit.lbl(UiKit.scoreline(int(res["goals"][1]), int(res["behinds"][1])), 15, col, true)
		asc.custom_minimum_size = Vector2(90, 0)
		h.add_child(asc)
		var ab := UiKit.club_badge(str(res["away"]), 14)
		ab.custom_minimum_size = Vector2(150, 0)
		h.add_child(ab)
		if str(res.get("tag", "")) != "":
			h.add_child(UiKit.lbl(str(res["tag"]), 11, UiKit.MUTED))
		if mine:
			var home_is_me: bool = str(res["home"]) == GameState.my_club
			var won: bool = (s[0] > s[1] and home_is_me) \
					or (s[1] > s[0] and not home_is_me)
			var drew: bool = s[0] == s[1]
			var tag := UiKit.lbl("DRAW" if drew else ("WON" if won else "LOST"),
					13, UiKit.MUTED if drew else UiKit.margin_colour(won), true)
			tag.custom_minimum_size = Vector2(56, 0)
			h.add_child(tag)
		v.add_child(h)
	return v
