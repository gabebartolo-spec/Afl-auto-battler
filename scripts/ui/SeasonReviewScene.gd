extends Control
## End-of-season wrap-up: who won the flag, how your list went, and the final
## ladder.

var _root: VBoxContainer


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

	_root = UiKit.vbox(9)
	margin.add_child(_root)
	_build()


func _build() -> void:
	var season: Season = GameState.season
	_root.add_child(UiKit.top_bar("Season Review", true))

	# --- premiership --------------------------------------------------------
	var champ := UiKit.panel(UiKit.PANEL_ALT, 18, 12)
	_root.add_child(champ)
	var cv := UiKit.vbox(4)
	champ.add_child(cv)
	var premier := str(season.finals.get("premier", ""))
	var runner := str(season.finals.get("runner_up", ""))
	cv.add_child(UiKit.lbl("2026 Premiers", 14, UiKit.MUTED))
	var champ_row := UiKit.hbox(10)
	champ_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(champ_row)
	if premier != "":
		champ_row.add_child(UiKit.club_badge(premier, 26))
	var mine_won: bool = premier == GameState.my_club
	cv.add_child(UiKit.lbl("Grand Final: %s" % _gf_line(season), 15,
			UiKit.GOLD if mine_won else UiKit.TEXT, true))
	cv.add_child(UiKit.lbl("PREMIERSHIP!" if mine_won else
			"%s take the flag. You finished %s." % [GameDB.club_name(premier),
			_ordinal(GameState.my_position())], 13,
			UiKit.GOOD if mine_won else UiKit.MUTED))

	# --- your season --------------------------------------------------------
	var body := UiKit.hbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(body)

	var mine := _my_results()
	var stats := _season_stats(mine)

	var left := UiKit.panel(UiKit.PANEL, 14)
	left.custom_minimum_size = Vector2(340, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := UiKit.vbox(5)
	left.add_child(lv)
	lv.add_child(UiKit.club_badge(GameState.my_club, 20))
	lv.add_child(UiKit.lbl("Finished %s" % _ordinal(GameState.my_position()),
			24, UiKit.GOLD, true))
	lv.add_child(UiKit.lbl("%s   -   %d pts" % [GameState.my_record(),
			int(GameState.my_ladder_row().get("pts", 0))], 14, UiKit.TEXT))
	lv.add_child(UiKit.spacer(4))
	for row in [
			["Points for", str(stats["pf"])],
			["Points against", str(stats["pa"])],
			["Percentage", "%.1f%%" % stats["pct"]],
			["Best win", "%d pts (%s)" % [stats["best_margin"], stats["best_opp"]]],
			["Worst loss", "%d pts (%s)" % [stats["worst_margin"], stats["worst_opp"]]],
			["Longest win streak", "%d games" % stats["streak"]],
			["Goals kicked", str(stats["goals"])],
	]:
		var h := UiKit.hbox(6)
		lv.add_child(h)
		var k := UiKit.lbl(row[0], 12, UiKit.MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UiKit.lbl(row[1], 13, UiKit.TEXT, true))

	lv.add_child(UiKit.spacer(6))
	lv.add_child(UiKit.lbl("Game by game", 12, UiKit.MUTED, true))
	lv.add_child(_form_strip(mine))

	# --- final ladder -------------------------------------------------------
	var right := UiKit.panel(UiKit.PANEL, 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rv := UiKit.vbox(4)
	right.add_child(rv)
	rv.add_child(UiKit.lbl("Final Ladder", 17, UiKit.GOLD, true))
	var table := UiKit.vbox(2)
	var rows := season.ladder_sorted()
	for i in rows.size():
		table.add_child(_ladder_line(rows[i], i + 1))
	rv.add_child(UiKit.scroll(table))

	# --- actions ------------------------------------------------------------
	var ctrl := UiKit.hbox(10)
	ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(ctrl)
	var again := UiKit.btn("New Career", 18, true)
	again.custom_minimum_size = Vector2(240, 52)
	again.pressed.connect(func():
		GameState.reset()
		GameState.begin_draft()
		Router.replace("draft"))
	ctrl.add_child(again)
	var menu := UiKit.btn("Main Menu", 17)
	menu.custom_minimum_size = Vector2(200, 52)
	menu.pressed.connect(func(): Router.to_main_menu())
	ctrl.add_child(menu)


func _gf_line(season: Season) -> String:
	var weeks: Array = season.finals.get("weeks", [])
	if weeks.is_empty():
		return "not played"
	var last: Array = weeks[weeks.size() - 1]
	if last.is_empty():
		return "not played"
	var gf: Dictionary = last[0]
	var s: Array = gf["score"]
	var extra := "  (level - %s advance on ladder position)" % \
			GameDB.club_short(str(gf["home"])) if bool(gf.get("decided_on_ladder", false)) else ""
	return "%s %s  d.  %s %s%s" % [
			GameDB.club_name(str(gf["home"])),
			UiKit.scoreline(int(gf["goals"][0]), int(gf["behinds"][0])),
			GameDB.club_name(str(gf["away"])),
			UiKit.scoreline(int(gf["goals"][1]), int(gf["behinds"][1])), extra]


func _my_results() -> Array:
	var out := []
	for res in GameState.season_log:
		if GameState.is_my_match(res):
			out.append(res)
	return out


func _season_stats(mine: Array) -> Dictionary:
	var lr := GameState.my_ladder_row()
	var best := 0
	var worst := 0
	var best_opp := "-"
	var worst_opp := "-"
	var streak := 0
	var run := 0
	var goals := 0
	for res in mine:
		var home_is_me: bool = str(res["home"]) == GameState.my_club
		var s: Array = res["score"]
		var mine_score: int = int(s[0]) if home_is_me else int(s[1])
		var theirs: int = int(s[1]) if home_is_me else int(s[0])
		var margin := mine_score - theirs
		var opp: String = str(res["away"]) if home_is_me else str(res["home"])
		goals += int(res["goals"][0]) if home_is_me else int(res["goals"][1])
		if margin > best:
			best = margin
			best_opp = GameDB.club_short(opp)
		if margin < worst:
			worst = margin
			worst_opp = GameDB.club_short(opp)
		if margin > 0:
			run += 1
			streak = maxi(streak, run)
		else:
			run = 0
	return {
		"pf": int(lr.get("pf", 0)), "pa": int(lr.get("pa", 0)),
		"pct": float(lr.get("pct", 0.0)), "best_margin": best,
		"worst_margin": absi(worst), "best_opp": best_opp, "worst_opp": worst_opp,
		"streak": streak, "goals": goals,
	}


## W/L/D chips for every game you played. Up to 28 of them, so they wrap.
func _form_strip(mine: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for res in mine:
		var home_is_me: bool = str(res["home"]) == GameState.my_club
		var s: Array = res["score"]
		var mine_score: int = int(s[0]) if home_is_me else int(s[1])
		var theirs: int = int(s[1]) if home_is_me else int(s[0])
		var letter := "D"
		var col := UiKit.MUTED
		if mine_score > theirs:
			letter = "W"
			col = UiKit.GOOD
		elif theirs > mine_score:
			letter = "L"
			col = UiKit.BAD
		var c := UiKit.chip(letter, col)
		c.custom_minimum_size = Vector2(24, 20)
		grid.add_child(c)
	return grid


func _ladder_line(r: Dictionary, pos: int) -> Control:
	var h := UiKit.hbox(6)
	var mine: bool = str(r["code"]) == GameState.my_club
	var col := UiKit.GOLD if mine else UiKit.TEXT
	var p := UiKit.lbl(str(pos), 13, col, mine)
	p.custom_minimum_size = Vector2(30, 0)
	h.add_child(p)
	var badge := UiKit.club_badge(str(r["code"]), 14)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(badge)
	var rec := UiKit.lbl("%d-%d-%d" % [int(r["w"]), int(r["l"]), int(r["d"])],
			12, UiKit.MUTED)
	rec.custom_minimum_size = Vector2(70, 0)
	h.add_child(rec)
	var pct := UiKit.lbl("%.1f%%" % float(r["pct"]), 12, col)
	pct.custom_minimum_size = Vector2(58, 0)
	h.add_child(pct)
	var pts := UiKit.lbl(str(int(r["pts"])), 14, col, true)
	pts.custom_minimum_size = Vector2(34, 0)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pts)
	return h


func _ordinal(n: int) -> String:
	if n <= 0:
		return "unranked"
	var suffix := "th"
	match n % 10:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	return "%d%s" % [n, suffix]
