extends Control
## Full ladder, plus the finals bracket once the season proper is done.

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
	get_viewport().size_changed.connect(_on_resize)
	_build()


func _on_resize() -> void:
	if is_inside_tree() and GameState.season != null:
		_build()


func _content_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


func _build() -> void:
	UiKit.clear(_root)
	var season: Season = GameState.season
	_root.add_child(UiKit.top_bar("Ladder", true))

	var info := "Home and away complete" if season.is_regular_done() \
			else "After %d of %d rounds" % [season.round_index, Season.REGULAR_ROUNDS]
	_root.add_child(UiKit.subtitle(info))

	# The ladder, then the season's subplots below it; the page scrolls only
	# when the finals bracket or a short screen needs it.
	var body := UiKit.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(UiKit.scroll(body))
	var p := UiKit.panel(UiKit.PANEL, 12)
	body.add_child(p)
	p.add_child(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club,
			_content_width() - 24.0, 0, true))

	var coleman := _coleman()
	if coleman != null:
		# Rows line up with the ladder's, inside its panel padding.
		var inset := MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 12)
		inset.add_theme_constant_override("margin_right", 12)
		inset.add_child(coleman)
		# On a wide screen, keep a name within reach of his goals.
		if _content_width() > 640.0:
			inset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			coleman.custom_minimum_size.x = 460
		body.add_child(inset)

	var coaches := _coaches_award()
	if coaches != null:
		var cinset := MarginContainer.new()
		cinset.add_theme_constant_override("margin_left", 12)
		cinset.add_theme_constant_override("margin_right", 12)
		cinset.add_child(coaches)
		if _content_width() > 640.0:
			cinset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			coaches.custom_minimum_size.x = 460
		body.add_child(cinset)

	if not season.finals.is_empty():
		body.add_child(UiKit.lbl("Finals Series", UiKit.HEADING, UiKit.EMPH, true))
		var fp := UiKit.panel(UiKit.PANEL, 12)
		body.add_child(fp)
		var fv := UiKit.vbox(4)
		fp.add_child(fv)
		for week in season.finals.get("weeks", []):
			fv.add_child(_week_block(week))
		if season.is_season_over():
			fv.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(
					str(season.finals["premier"])), 17, UiKit.TEXT, true))
		else:
			fv.add_child(UiKit.ellipsis("Next: %s" % _next_finals_label(), UiKit.SECONDARY, UiKit.MUTED))


## The Coaches Award race: accumulated through the home-and-away season.
func _coaches_award() -> Control:
	var leaders := GameState.coaches_award_leaders(5)
	if leaders.is_empty() or int(leaders[0]["votes"]) <= 0:
		return null
	var v := UiKit.vbox(4)
	v.name = "CoachesAwardLeaders"
	v.add_child(UiKit.section("Coaches Award"))
	var header := UiKit.hbox(10)
	for column in [["Rank", 32], ["Player", 0], ["Club", 72], ["Votes", 40]]:
		var label := UiKit.line(str(column[0]), 12, UiKit.MUTED)
		label.custom_minimum_size.x = float(column[1])
		if column[0] == "Player": label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif column[0] == "Votes": label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(label)
	v.add_child(header)
	var rank := 0
	for i in range(leaders.size()):
		var r: Dictionary = leaders[i]
		if int(r["votes"]) <= 0: break
		if i == 0 or int(r["votes"]) != int(leaders[i - 1]["votes"]): rank = i + 1
		var h := UiKit.hbox(10)
		h.name = "CoachesAward_%d" % (i + 1)
		var n := UiKit.line(str(rank), UiKit.BODY, UiKit.MUTED); n.custom_minimum_size.x = 32; h.add_child(n)
		var who := UiKit.ellipsis(GameState.award_name(r), UiKit.NAME, UiKit.TEXT, str(r["club"]) == GameState.my_club); who.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(who)
		var club := UiKit.ellipsis(GameDB.club_short(str(r["club"])), 14, UiKit.MUTED); club.custom_minimum_size.x = 72; h.add_child(club)
		var votes := UiKit.line(str(int(r["votes"])), 17, UiKit.TEXT, true); votes.custom_minimum_size.x = 40; votes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(votes)
		v.add_child(h)
	return v


## The Coleman Medal race: the leading goalkickers, one to a row. Null
## before anyone has kicked a goal.
func _coleman() -> Control:
	var leaders := GameState.coleman_leaders(5)
	if leaders.is_empty() or int(leaders[0]["goals"]) <= 0:
		return null
	var v := UiKit.vbox(4)
	v.name = "ColemanLeaders"
	v.add_child(UiKit.section("Coleman Medal"))
	var header := UiKit.hbox(10)
	for column in [["Rank", 32], ["Player", 0], ["Club", 72], ["Goals", 40]]:
		var label := UiKit.line(str(column[0]), 12, UiKit.MUTED)
		label.custom_minimum_size.x = float(column[1])
		if column[0] == "Player":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif column[0] == "Goals":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(label)
	v.add_child(header)
	var rank := 0
	for i in range(leaders.size()):
		var r: Dictionary = leaders[i]
		if int(r["goals"]) <= 0:
			break
		# Level on goals, level in the race.
		if i == 0 or int(r["goals"]) != int(leaders[i - 1]["goals"]):
			rank = i + 1
		var mine := str(r["club"]) == GameState.my_club
		var h := UiKit.hbox(10)
		h.name = "Coleman_%d" % (i + 1)
		var n := UiKit.line(str(rank), UiKit.BODY, UiKit.MUTED)
		n.custom_minimum_size.x = 32
		h.add_child(n)
		var who := UiKit.ellipsis(GameState.award_name(r), UiKit.NAME, UiKit.TEXT, mine)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		var club := UiKit.ellipsis(GameDB.club_short(str(r["club"])), 14, UiKit.MUTED)
		club.custom_minimum_size.x = 72
		club.size_flags_horizontal = Control.SIZE_FILL
		h.add_child(club)
		var g := UiKit.line(str(int(r["goals"])), 17, UiKit.TEXT, true)
		g.custom_minimum_size.x = 40
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(g)
		v.add_child(h)
	return v


func _next_finals_label() -> String:
	var ms: Array = GameState.season.finals_week_matches()
	var parts := []
	for m in ms:
		if str(m["home"]) != "" and str(m["away"]) != "":
			parts.append("%s: %s v %s" % [m["tag"], GameDB.club_short(str(m["home"])),
					GameDB.club_short(str(m["away"]))])
	return "   ".join(parts)


func _week_block(week: Array) -> Control:
	var v := UiKit.vbox(2)
	var narrow := _content_width() < 520.0
	for res in week:
		v.add_child(_finals_row(res, narrow))
	return v


## The word between a finals row's two scores, home side first: "d." when
## the home side won, "lost to" when the away side won, "drew with" when
## level (a level final is then decided on the ladder).
static func result_word(res: Dictionary) -> String:
	var s: Array = res.get("score", [0, 0])
	if int(s[0]) > int(s[1]):
		return "d."
	if int(s[1]) > int(s[0]):
		return "lost to"
	return "drew with"


func _finals_row(res: Dictionary, narrow: bool) -> Control:
	var h := UiKit.hbox(6)
	var tag := UiKit.line("%s" % str(res.get("tag", "")), 12, UiKit.MUTED, true)
	tag.custom_minimum_size = Vector2(36, 0)
	h.add_child(tag)
	h.add_child(UiKit.club_badge(str(res["home"]), 13, narrow, true))
	var hs := UiKit.line(UiKit.scoreline(int(res["goals"][0]), int(res["behinds"][0])),
			13, UiKit.TEXT, true)
	hs.custom_minimum_size = Vector2(78, 0)
	h.add_child(hs)
	h.add_child(UiKit.line(result_word(res), 12, UiKit.MUTED))
	var asc := UiKit.line(UiKit.scoreline(int(res["goals"][1]), int(res["behinds"][1])),
			13, UiKit.TEXT, true)
	asc.custom_minimum_size = Vector2(78, 0)
	h.add_child(asc)
	h.add_child(UiKit.club_badge(str(res["away"]), 13, narrow, true))
	if bool(res.get("extra_time", false)) and not narrow:
		h.add_child(UiKit.ellipsis("(aet)", UiKit.FINE, UiKit.MUTED))
	if bool(res.get("decided_on_ladder", false)) and not narrow:
		h.add_child(UiKit.ellipsis("(level: the higher-placed side goes through)", UiKit.FINE, UiKit.MUTED))
	return h
