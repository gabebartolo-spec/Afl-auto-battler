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
	UiKit.apply_insets(margin, 12)
	add_child(margin)

	_root = UiKit.vbox(9)
	margin.add_child(_root)
	get_viewport().size_changed.connect(func():
		if is_inside_tree() and GameState.season != null:
			_build())
	_build()


func _content_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


func _build() -> void:
	UiKit.clear(_root)
	var season: Season = GameState.season
	_root.add_child(UiKit.top_bar("Season Review", true))

	# --- premiership --------------------------------------------------------
	var champ := UiKit.panel(UiKit.PANEL_ALT, 18, 12)
	_root.add_child(champ)
	var cv := UiKit.vbox(4)
	champ.add_child(cv)
	var premier := str(season.finals.get("premier", ""))
	var runner := str(season.finals.get("runner_up", ""))
	cv.add_child(UiKit.lbl("%d Premiers" % GameState.season_year, 14, UiKit.MUTED))
	var champ_row := UiKit.hbox(10)
	champ_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(champ_row)
	if premier != "":
		champ_row.add_child(UiKit.club_badge(premier, 22, false, true))
	var mine_won: bool = premier == GameState.my_club
	cv.add_child(UiKit.lbl("Grand Final: %s" % _gf_line(season), 15,
			UiKit.GOLD if mine_won else UiKit.TEXT, true))
	cv.add_child(UiKit.lbl("PREMIERSHIP!" if mine_won else
			"%s take the flag. You finished %s." % [GameDB.club_name(premier),
			_ordinal(GameState.my_position())], 13,
			UiKit.GOOD if mine_won else UiKit.MUTED))

	# --- your season --------------------------------------------------------
	var narrow := _content_width() < 720.0
	var body: BoxContainer
	if narrow:
		body = UiKit.vbox(10)
	else:
		body = UiKit.hbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(body)

	var mine := _my_results()
	var stats := _season_stats(mine)

	var left := UiKit.panel(UiKit.PANEL, 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		h.add_child(UiKit.ellipsis(row[0], 12, UiKit.MUTED))
		h.add_child(UiKit.line(row[1], 13, UiKit.TEXT, true))

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
	var ladder_w := _content_width() - 24.0 if narrow else (_content_width() * 0.5)
	rv.add_child(UiKit.scroll(UiKit.ladder_table(season.ladder_sorted(),
			GameState.my_club, ladder_w, 0, true)))

	# --- the board -----------------------------------------------------------
	var verdict := str(GameState.board.get("verdict", ""))
	if verdict != "" and season.is_season_over():
		var bp := UiKit.panel(UiKit.PANEL, 10, 8)
		bp.name = "BoardVerdict"
		var bv := UiKit.vbox(3)
		bp.add_child(bv)
		var hist: Array = GameState.board.get("history", [])
		var last: Dictionary = hist[hist.size() - 1] if not hist.is_empty() else {}
		bv.add_child(UiKit.lbl("The board: %s" % verdict, 16,
				UiKit.GOOD if bool(last.get("met", false)) else UiKit.BAD, true))
		bv.add_child(UiKit.lbl("Goal: %s  -  %s  -  confidence now %d%%" % [str(last.get("goal", "")),
				"met" if bool(last.get("met", false)) else "missed", GameState.board_confidence()], 13, UiKit.MUTED))
		_root.add_child(bp)

	# --- awards -------------------------------------------------------------
	if not GameState.season_awards.is_empty():
		_root.add_child(_awards_panel())

	# --- club achievements ----------------------------------------------------
	_root.add_child(_achievements_panel())

	# --- actions ------------------------------------------------------------
	var ctrl: BoxContainer
	if _content_width() < 460.0:
		ctrl = UiKit.vbox(8)
	else:
		ctrl = UiKit.hbox(8)
	_root.add_child(ctrl)

	# The season ends the way the real AFL year does: with the national draft.
	var draft_btn := UiKit.btn("%d NATIONAL DRAFT" % GameState.season_year, 18, true)
	draft_btn.name = "NationalDraft"
	draft_btn.custom_minimum_size = Vector2(0, 48)
	draft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_btn.pressed.connect(_on_intake_draft)
	ctrl.add_child(draft_btn)

	var again := UiKit.btn("New Career", 18, false)
	again.name = "NewCareer"
	again.custom_minimum_size = Vector2(0, 48)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		GameState.reset()
		GameState.begin_draft()
		Router.replace("draft"))
	ctrl.add_child(again)
	var menu := UiKit.btn("Main Menu", 17)
	menu.custom_minimum_size = Vector2(0, 48)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	grid.columns = 8 if _content_width() < 420.0 else 12
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


## Continue the career: run the intake draft, or roll on directly when the
## prospect pool is empty.
func _on_intake_draft() -> void:
	if GameState.begin_intake_draft():
		Router.go("draft")
		return
	if GameState.start_next_season():
		Router.replace("hub")


# ---------------------------------------------------------------------------
# Awards night
# ---------------------------------------------------------------------------
func _awards_panel() -> Control:
	var aw: Dictionary = GameState.season_awards
	var panel := UiKit.panel(UiKit.PANEL, 14)
	panel.name = "AwardsPanel"
	var v := UiKit.vbox(5)
	panel.add_child(v)
	v.add_child(UiKit.heading("%d AWARDS" % int(aw.get("year", GameState.season_year)), 22))
	var brownlow: Array = aw.get("brownlow", [])
	if not brownlow.is_empty():
		v.add_child(_award_line("Brownlow Medal", brownlow[0], "%d votes" % int(brownlow[0]["votes"]), true))
		var rest := []
		for r in brownlow.slice(1, 5):
			rest.append("%s %d" % [GameState.award_name(r), int(r["votes"])])
		v.add_child(_small("Then: " + ", ".join(rest)))
	var coleman: Array = aw.get("coleman", [])
	if not coleman.is_empty():
		v.add_child(_award_line("Coleman Medal", coleman[0], "%d goals" % int(coleman[0]["goals"]), true))
		var rest2 := []
		for r in coleman.slice(1, 3):
			rest2.append("%s %d" % [GameState.award_name(r), int(r["goals"])])
		v.add_child(_small("Then: " + ", ".join(rest2)))
	var rising: Array = aw.get("rising_star", [])
	if not rising.is_empty():
		v.add_child(_award_line("Rising Star", rising[0], "age %d" % int(rising[0]["age"]), false))
	var mine: Array = (aw.get("best_and_fairest", {}) as Dictionary).get(GameState.my_club, [])
	if not mine.is_empty():
		var bf := []
		for r in mine:
			bf.append("%s (%d)" % [GameState.award_name(r), int(r["bf"])])
		v.add_child(UiKit.lbl("%s best & fairest" % GameDB.club_name(GameState.my_club), 15, UiKit.GOLD, true))
		v.add_child(_small(", ".join(bf)))
	var aa: Array = aw.get("all_australian", [])
	if not aa.is_empty():
		v.add_child(UiKit.lbl("All-Australian team", 15, UiKit.GOLD, true))
		for slot in [["RUCK", "Ruck"], ["MID", "Midfield"], ["DEF", "Defence"], ["FWD", "Forwards"], ["BENCH", "Interchange"]]:
			var names := []
			for r in aa:
				if str(r["slot"]) == str(slot[0]):
					var mine_tag := "*" if str(r["club"]) == GameState.my_club else ""
					names.append("%s%s (%s)" % [GameState.award_name(r), mine_tag, GameDB.club_short(str(r["club"]))])
			v.add_child(_small("%s: %s" % [str(slot[1]), ", ".join(names)]))
	var rec := GameState.records
	if not rec.is_empty():
		v.add_child(UiKit.lbl("League records", 15, UiKit.GOLD, true))
		for row in [["most_goals", "Most goals in a season", "goals"],
				["most_votes", "Most Brownlow votes", "votes"],
				["highest_score", "Highest score", "pts"],
				["biggest_win", "Biggest win", "pts"]]:
			var r: Dictionary = rec.get(str(row[0]), {})
			if r.is_empty():
				continue
			var who := GameState.award_name(r) + " (%s)" % GameDB.club_short(str(r["club"])) if r.has("id") \
					else "%s v %s" % [GameDB.club_short(str(r["club"])), GameDB.club_short(str(r.get("opp", "")))]
			v.add_child(_small("%s: %d %s - %s, %d" % [str(row[1]), int(r["value"]), str(row[2]), who, int(r["year"])]))
	if GameState.honour_roll.size() > 1:
		v.add_child(UiKit.lbl("Honour roll", 15, UiKit.GOLD, true))
		for h in GameState.honour_roll:
			var b: Array = h.get("brownlow", [])
			v.add_child(_small("%d  Premiers %s  ·  Brownlow %s  ·  you finished %s" % [int(h["year"]),
					GameDB.club_short(str(h["premier"])),
					GameState.award_name(b[0]) if not b.is_empty() else "-",
					_ordinal(int(h.get("my_position", 0)))]))
	return panel


func _award_line(title: String, row: Dictionary, detail: String, big: bool) -> Control:
	var mine := str(row["club"]) == GameState.my_club
	var l := UiKit.lbl("%s: %s (%s), %s" % [title, GameState.award_name(row),
			GameDB.club_name(str(row["club"])), detail], 16 if big else 14,
			UiKit.GOOD if mine else UiKit.TEXT, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ---------------------------------------------------------------------------
# Club achievements
# ---------------------------------------------------------------------------
## Every club's achievement is written into its history; the ones that came
## true are celebrated here, and yours (while still locked) is teased.
func _achievements_panel() -> Control:
	var unlocked: Dictionary = GameState.achievements
	var panel := UiKit.panel(UiKit.PANEL, 14)
	panel.name = "AchievementsPanel"
	var v := UiKit.vbox(5)
	panel.add_child(v)
	v.add_child(UiKit.heading("CLUB ACHIEVEMENTS", 22))
	if unlocked.is_empty():
		v.add_child(_small("Nothing unlocked yet - every club's achievement is a piece of its history."))
	for d in Achievements.DEFINITIONS:
		var id := str(d["id"])
		if not unlocked.has(id):
			continue
		var club := str(d["club"])
		var mine := club == GameState.my_club
		var l := UiKit.lbl("%s - %s, %d" % [GameDB.club_name(club), str(d["name"]),
				int(unlocked[id].get("year", 0))], 15,
				UiKit.GOOD if mine else UiKit.TEXT, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var note := _small(str(d["desc"]))
		v.add_child(note)
	var mine_def := Achievements.definition_by_club(GameState.my_club)
	if mine_def != {} and not unlocked.has(str(mine_def["id"])):
		v.add_child(_small("Still chasing - %s: %s" % [str(mine_def["name"]), str(mine_def["desc"])]))
	return panel


func _small(text: String) -> Label:
	var l := UiKit.lbl(text, 12, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
