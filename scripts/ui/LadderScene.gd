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

	var p := UiKit.panel(UiKit.PANEL, 12)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(p)
	var v := UiKit.vbox(2)
	p.add_child(v)
	v.add_child(UiKit.scroll(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club,
			_content_width() - 24.0, 0, true)))

	var leaders := GameState.coleman_leaders(5)
	if not leaders.is_empty() and int(leaders[0]["goals"]) > 0:
		var names := []
		for r in leaders:
			names.append("%s (%s) %d" % [GameState.award_name(r), GameDB.club_short(str(r["club"])), int(r["goals"])])
		var cl := UiKit.lbl("Coleman: " + ",  ".join(names), 13, UiKit.TEXT)
		cl.name = "ColemanLeaders"
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_root.add_child(cl)

	if not season.finals.is_empty():
		_root.add_child(UiKit.lbl("Finals Series", 18, UiKit.EMPH, true))
		var fp := UiKit.panel(UiKit.PANEL, 12)
		_root.add_child(fp)
		var fv := UiKit.vbox(4)
		fp.add_child(fv)
		for week in season.finals.get("weeks", []):
			fv.add_child(_week_block(week))
		if season.is_season_over():
			fv.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(
					str(season.finals["premier"])), 17, UiKit.GOOD, true))
		else:
			fv.add_child(UiKit.ellipsis("Next: %s" % _next_finals_label(), 13, UiKit.MUTED))


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
		h.add_child(UiKit.ellipsis("(aet)", 11, UiKit.MUTED))
	if bool(res.get("decided_on_ladder", false)) and not narrow:
		h.add_child(UiKit.ellipsis("(level - higher seed advances)", 11, UiKit.MUTED))
	return h
