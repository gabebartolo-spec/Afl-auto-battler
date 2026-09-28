extends Control
## Season hub: your next match, the ladder snapshot, and the round controls.

var _root: VBoxContainer
var _results_overlay: Control
var _news_overlay: Control
var _sim_confirm: Control
var _quick_sim: Control
## A long press on Sim round opens the quick-sim menu instead of a sim.
var _hold_fired := false
var _hold_id := 0
const HOLD_SECONDS := 0.5


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
	_root.add_child(UiKit.top_bar(_week_title(season), false))
	if GameState.is_sacked():
		_root.add_child(_standing_card())
		_root.add_child(_sacked_card())
		return

	# One page that scrolls: this week first, then your season, the news and
	# the whole ladder at its natural height. Nothing is squeezed to fit.
	var page := UiKit.vbox(UiKit.SECTION)
	_root.add_child(UiKit.scroll(page))
	var week := _week_section(season)
	var ladder := _ladder_section(season)
	if _narrow():
		page.add_child(week)
		page.add_child(UiKit.rule())
		page.add_child(_standing_card())
		if not GameState.news.is_empty():
			page.add_child(_news_card())
		page.add_child(ladder)
	else:
		var cols := UiKit.hbox(28)
		page.add_child(cols)
		var left := UiKit.vbox(UiKit.SECTION)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(left)
		left.add_child(week)
		left.add_child(UiKit.rule())
		left.add_child(_standing_card())
		if not GameState.news.is_empty():
			left.add_child(_news_card())
		ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(ladder)
	_root.add_child(_footer(season))


## "Round 4", a finals week, or the season.
func _week_title(season: Season) -> String:
	if season.is_season_over():
		return "%d season" % GameState.season_year
	if not season.is_regular_done():
		return "Round %d of %d" % [season.round_index + 1, Season.REGULAR_ROUNDS]
	return _finals_label()


func _ladder_section(season: Season) -> Control:
	var v := UiKit.vbox(6)
	v.name = "LadderSection"
	var head := UiKit.hbox(8)
	v.add_child(head)
	var title := UiKit.section("Ladder")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var full := UiKit.btn("Full ladder", 14)
	full.name = "FullLadder"
	full.custom_minimum_size = Vector2(112, 44)
	full.pressed.connect(func(): Router.go("ladder"))
	head.add_child(full)
	var width := _content_width() if _narrow() else _content_width() * 0.45
	v.add_child(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club, width, 0, false))
	return v


## Your season in a few lines: where you sit, your form, the board.
func _standing_card() -> Control:
	var cv := UiKit.vbox(3)
	cv.name = "SeasonBlock"
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Your club, with its coaching staff one quiet tap away.
	var club_row := UiKit.hbox(8)
	var badge := UiKit.club_badge(GameState.my_club, 16, false, true)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club_row.add_child(badge)
	var staff := UiKit.btn("Staff", 14)
	staff.name = "HubStaff"
	staff.flat = true
	staff.custom_minimum_size = Vector2(64, 44)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		staff.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	staff.add_theme_color_override("font_color", UiKit.MUTED)
	staff.pressed.connect(func(): Router.go("staff"))
	club_row.add_child(staff)
	cv.add_child(club_row)
	var lr := GameState.my_ladder_row()
	var title := UiKit.lbl("%s of %d  ·  %s  ·  %d pts" % [GameState.ordinal(GameState.my_position()),
			GameState.season.ladder.size(), GameState.my_record(), int(lr.get("pts", 0))],
			UiKit.H2, UiKit.TEXT, true)
	cv.add_child(title)
	var form := GameState.club_form_info(GameState.my_club)
	var form_l := UiKit.lbl(GameState.form_line(form), UiKit.SMALL, _form_colour(float(form["value"])))
	form_l.name = "FormLine"
	cv.add_child(form_l)
	var last := _last_match_button()
	if last != null:
		cv.add_child(last)
	if GameState.board_goal_text() != "":
		var conf := GameState.board_confidence()
		var col := UiKit.GOOD if conf >= 60 else (UiKit.MUTED if conf >= ClubLife.WARN_LINE else UiKit.BAD)
		var board_l := UiKit.lbl("Board %d%%  ·  %s%s" % [conf, GameState.board_goal_text(),
				"  (final warning)" if bool(GameState.board.get("warned", false)) else ""], UiKit.SMALL, col)
		board_l.name = "BoardLine"
		cv.add_child(board_l)
	return cv


## "Last match: lost to Fremantle by 12": a tap reopens it at full time.
func _last_match_button() -> Control:
	var res: Dictionary = GameState.last_match
	if res.is_empty() or not GameState.is_my_match(res) or not res.has("players"):
		return null
	var s: Array = res["score"]
	var me := 0 if str(res["home"]) == GameState.my_club else 1
	var opp := GameDB.club_name(str(res["away"] if me == 0 else res["home"]))
	var margin := absi(int(s[0]) - int(s[1]))
	var what := "drew with %s" % opp
	if int(s[me]) > int(s[1 - me]):
		what = "beat %s by %d" % [opp, margin]
	elif int(s[me]) < int(s[1 - me]):
		what = "lost to %s by %d" % [opp, margin]
	var b := UiKit.btn("Last match: %s  ›" % what, UiKit.SMALL)
	b.name = "ReviewLastMatch"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(_review_match)
	return b


## This week's decision. Answer it here; unanswered, it takes the default
## when the round is played.
func _event_card() -> Control:
	var e: Dictionary = GameState.week_event
	var card := UiKit.panel(UiKit.PANEL, 12)
	card.name = "WeekEvent"
	var v := UiKit.vbox(6)
	card.add_child(v)
	v.add_child(UiKit.lbl(str(e.get("title", "")), UiKit.BODY, UiKit.TEXT, true))
	if GameState.week_event_pending():
		var t := UiKit.lbl(str(e.get("text", "")), 12, UiKit.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var opts: Array = e.get("options", [])
		var row: BoxContainer = UiKit.vbox(4) if _narrow() else UiKit.hbox(6)
		v.add_child(row)
		for i in range(opts.size()):
			var o: Dictionary = opts[i]
			var b := UiKit.btn(str(o.get("label", "")), 14, false)
			b.name = "Event_%d" % i
			b.custom_minimum_size = Vector2(0, 44)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = str(o.get("detail", ""))
			b.pressed.connect(func():
				GameState.resolve_week_event(i)
				_build())
			row.add_child(b)
		var hints: PackedStringArray = []
		for o in opts:
			hints.append("%s: %s" % [str(o.get("label", "")), str(o.get("detail", ""))])
		var h := UiKit.lbl("\n".join(hints), 11, UiKit.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(h)
	else:
		v.add_child(UiKit.lbl(str(e.get("outcome", "")), 13, UiKit.GOOD))
	return card


func _sacked_card() -> Control:
	var card := UiKit.panel(UiKit.PANEL, 14)
	card.name = "SackedCard"
	var v := UiKit.vbox(8)
	card.add_child(v)
	v.add_child(UiKit.lbl("You have been sacked", 24, UiKit.BAD, true))
	var t := UiKit.lbl("Two seasons short of the board's goals. Your time at %s is over. Start a new career and prove them wrong." % GameDB.club_name(GameState.my_club), 14, UiKit.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(_nav_button("Season review", func(): Router.go("season_review")))
	v.add_child(_nav_button("Main menu", func(): Router.to_main_menu(), true))
	return card


## The latest league headlines; More opens the whole feed.
func _news_card() -> Control:
	var card := HBoxContainer.new()
	card.name = "NewsCard"
	var row := card
	row.add_theme_constant_override("separation", 8)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiKit.lbl("League news", UiKit.BODY, UiKit.TEXT, true))
	for item in GameState.news.slice(0, 2):
		v.add_child(UiKit.ellipsis(str(item["text"]), 12, UiKit.TEXT))
	var more := UiKit.btn("More", 14)
	more.name = "NewsMore"
	more.custom_minimum_size = Vector2(72, 44)
	more.pressed.connect(_show_news)
	row.add_child(more)
	return card


func _show_news() -> void:
	var box := UiKit.modal_box(self, 620.0, 560.0)
	_news_overlay = box["overlay"]
	_news_overlay.name = "NewsFeed"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("League news", UiKit.H1))
	v.add_child(UiKit.lbl("Difficulty: %s" % str(GameState.difficulty_rules()["label"]), 12, UiKit.MUTED))
	var last_when := ""
	for item in GameState.news:
		var when := "%d  %s" % [int(item["year"]), str(item["when"])]
		if when != last_when:
			v.add_child(UiKit.lbl(when, 13, UiKit.EMPH, true))
			last_when = when
		var l := UiKit.lbl(str(item["text"]), 13, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var ok := UiKit.btn("Close", 17, true)
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func(): _news_overlay.queue_free())
	box["footer"].add_child(ok)


## This week: who you play, the two or three things worth knowing about
## them, anything on your side that matters, and the way into the match.
func _week_section(season: Season) -> Control:
	var nv := UiKit.vbox(6)
	nv.name = "ThisWeek"
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if season.is_season_over():
		nv.add_child(UiKit.lbl("Season complete", UiKit.H1, UiKit.TEXT, true))
		nv.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(GameState.premier()),
				16, UiKit.TEXT))
		var ru: String = str(season.finals.get("runner_up", ""))
		nv.add_child(UiKit.ellipsis("Runners-up: %s" % GameDB.club_name(ru),
				13, UiKit.MUTED))
		var medal: Array = GameState.season_awards.get("brownlow", [])
		if not medal.is_empty():
			nv.add_child(UiKit.ellipsis("Brownlow: %s (%d votes)" % [
					GameState.award_name(medal[0]), int(medal[0]["votes"])], 13, UiKit.TEXT))
	elif _upcoming_match().is_empty():
		match GameState.my_finals_status():
			"bye":
				nv.add_child(UiKit.lbl("Week off", UiKit.H1, UiKit.TEXT, true))
				nv.add_child(UiKit.lbl(
						"You have a week off while the rest of the series plays on.",
						UiKit.BODY, UiKit.MUTED))
			"eliminated":
				nv.add_child(UiKit.lbl("Knocked out", UiKit.H1, UiKit.BAD, true))
				nv.add_child(UiKit.lbl(
						"Your finals campaign is over. Sim the rest of the series to see who lifts the cup.",
						UiKit.BODY, UiKit.MUTED))
			_:
				nv.add_child(UiKit.lbl("Season over for you", UiKit.H1, UiKit.BAD, true))
				nv.add_child(UiKit.lbl(
						"You missed the top %d. Sim the finals series to see who lifts the cup." % Season.FINALISTS,
						UiKit.BODY, UiKit.MUTED))
	else:
		var mine: Dictionary = _upcoming_match()
		var opp: String = mine["away"] if mine["home"] == GameState.my_club else mine["home"]
		var is_home: bool = mine["home"] == GameState.my_club
		var ground := str(mine.get("venue", ""))
		if ground == "":
			ground = str(GameDB.club(str(mine["home"])).get("ground", ""))
		nv.add_child(UiKit.ellipsis(ground, UiKit.SMALL, UiKit.MUTED))
		var who := UiKit.lbl("%s %s" % ["v" if is_home else "at", GameDB.club_name(opp)],
				26 if _narrow() else 30, UiKit.TEXT, true)
		who.name = "Opponent"
		nv.add_child(who)
		var their := GameState.club_form_info(opp)
		var standing := UiKit.lbl("%s on the ladder  ·  %s" % [
				GameState.ordinal(GameState.club_position(opp)),
				GameState.form_line(their, "form").trim_prefix("form: ")], UiKit.SMALL, UiKit.MUTED)
		standing.name = "OppFormLine"
		nv.add_child(standing)
		# The football: two or three facts, then anything on our side.
		var facts := GameState.opponent_facts(opp)
		var notes := GameState.my_week_notes()
		if not facts.is_empty() or not notes.is_empty():
			nv.add_child(UiKit.spacer(4))
		for i in range(facts.size()):
			var f: Dictionary = facts[i]
			var fl := UiKit.lbl(str(f["text"]), UiKit.BODY, UiKit.TEXT)
			fl.name = "Fact_%d" % i
			nv.add_child(fl)
		for i in range(notes.size()):
			var nl := UiKit.lbl(str(notes[i]["text"]), UiKit.BODY, UiKit.BAD)
			nl.name = "OwnNote_%d" % i
			nv.add_child(nl)
	if not GameState.week_event.is_empty() and not season.is_season_over():
		nv.add_child(UiKit.spacer(4))
		nv.add_child(_event_card())
	nv.add_child(UiKit.spacer(4))
	nv.add_child(_week_actions(season))
	return nv


## Team form reads green when good, red when poor, muted when steady.
func _form_colour(f: float) -> Color:
	if f >= 0.25:
		return UiKit.GOOD
	if f <= -0.25:
		return UiKit.BAD
	return UiKit.MUTED


## The week's decision buttons: the primary action last, where the thumb is.
func _week_actions(season: Season) -> Control:
	var buttons: Array = []
	if season.is_season_over():
		var resume := GameState.draft != null and GameState.draft.intake_mode
		if not resume:
			buttons.append(_nav_button("Trades & Contracts", func(): Router.go("offseason")))
		buttons.append(_nav_button("Resume national draft" if resume
				else "%d National Draft" % GameState.season_year, _on_intake_draft, true))
	elif _upcoming_match().is_empty() and GameState.my_finals_status() == "bye":
		# Still alive: sim only this week, never past your own final.
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		buttons.append(_nav_button("Sim %s" % _finals_label(), _on_sim_round, true))
	elif _upcoming_match().is_empty():
		buttons.append(_nav_button("Sim to Grand Final", _on_sim_to_end, true))
	else:
		buttons.append(_nav_button("Pick the side", func(): Router.go("selection")))
		buttons.append(_nav_button("Play match", _on_play_match, true))
	var row := UiKit.hbox(8)
	row.name = "WeekActions"
	for b in buttons:
		row.add_child(b)
	return row


## Everything else, one quiet row pinned under the page.
func _footer(season: Season) -> Control:
	var buttons: Array = []
	if season.is_season_over():
		buttons.append(_nav_button("Season review", func(): Router.go("season_review")))
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("Main menu", func(): Router.to_main_menu()))
	else:
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("My list", func(): Router.go("list")))
		if not _upcoming_match().is_empty():
			var sim := _nav_button("Sim round", _on_sim_round_pressed)
			sim.name = "SimRound"
			_wire_long_press(sim)
			buttons.append(sim)
	var row := UiKit.hbox(6)
	row.name = "HubFooter"
	for b in buttons:
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 44)
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
	return ["Wildcard Round", "Qualifying & Elimination", "Semi Finals",
			"Preliminary Finals", "Grand Final"][clampi(w - 1, 0, 4)]


## The match you are about to play, or {} if you have none coming up
## (missed the finals, or already eliminated). Unified across the home and
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
						"label": "Round %d" % (season.round_index + 1), "tag": ""}
		return {}
	for m in season.finals_week_matches():
		if str(m["home"]) == "" or str(m["away"]) == "":
			continue
		if m["home"] == GameState.my_club or m["away"] == GameState.my_club:
			return {"home": m["home"], "away": m["away"],
					"label": str(m["label"]), "tag": str(m["tag"]),
					"venue": season.finals_venue(m)}
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


## Sim round skips your own match for good, so it asks first (unless you
## have said not to; Settings turns the question back on).
func _on_sim_round_pressed() -> void:
	if _hold_fired:
		_hold_fired = false
		return
	var m := _upcoming_match()
	if m.is_empty() or not GameState.confirm_sim_round():
		_on_sim_round()
		return
	var box := UiKit.modal_box(self, 420.0, 290.0)
	_sim_confirm = box["overlay"]
	_sim_confirm.name = "SimConfirm"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Simulate %s?" % str(m["label"]), UiKit.H1))
	var why := UiKit.lbl("Your match will be simulated instead of played.", UiKit.BODY, UiKit.TEXT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var go := UiKit.btn("Sim round", 17, true)
	go.name = "SimConfirmGo"
	go.custom_minimum_size = Vector2(0, 48)
	go.pressed.connect(func():
		_close_sim_confirm()
		_on_sim_round())
	box["footer"].add_child(go)
	var cancel := UiKit.btn("Cancel", 16)
	cancel.name = "SimConfirmCancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_close_sim_confirm)
	box["footer"].add_child(cancel)
	var never := UiKit.btn("Don't ask again", 16)
	never.name = "SimConfirmNever"
	never.custom_minimum_size = Vector2(0, 44)
	never.pressed.connect(func():
		GameState.set_confirm_sim_round(false)
		_close_sim_confirm()
		_on_sim_round())
	box["footer"].add_child(never)


func _close_sim_confirm() -> void:
	if _sim_confirm != null and is_instance_valid(_sim_confirm):
		_sim_confirm.queue_free()
	_sim_confirm = null


## Hold Sim round (or right-click it) for the quick-sim menu.
func _wire_long_press(b: Button) -> void:
	b.button_down.connect(func():
		_hold_id += 1
		var id := _hold_id
		# Still held: no button_up has moved the counter on since.
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
			if id == _hold_id and is_instance_valid(b):
				_hold_fired = true
				_open_quick_sim()))
	b.button_up.connect(func(): _hold_id += 1)
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_open_quick_sim())


## Quick sim: this round, the next four, or the rest of the home-and-away
## season - each shows where it lands. Never plays a final. Always opens on
## a long press, whether or not Sim round asks first.
func _open_quick_sim() -> void:
	_close_sim_confirm()
	_close_quick_sim()
	var season: Season = GameState.season
	if season == null or season.is_regular_done():
		return
	var now := season.round_index + 1
	var last := season.fixture.size()
	var box := UiKit.modal_box(self, 420.0, 330.0)
	_quick_sim = box["overlay"]
	_quick_sim.name = "QuickSim"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Quick sim", UiKit.H1))
	var why := UiKit.lbl("Your matches are simulated. It always stops before the finals.",
			UiKit.SMALL, UiKit.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var four_to := mini(now + 3, last)
	var options := [
		["QuickSimOne", "Sim this round (Round %d)" % now, 1],
		["QuickSimFour", "Skip to Round %d" % (four_to + 1) if four_to < last
				else "Skip to the end of the home and away", 4],
		["QuickSimAll", "Skip to the end of the home and away (after Round %d)" % last, -1],
	]
	for o in options:
		var b := UiKit.btn(str(o[1]), 15)
		b.name = str(o[0])
		b.custom_minimum_size = Vector2(0, 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var n := int(o[2])
		b.pressed.connect(func(): _run_quick_sim(n))
		box["footer"].add_child(b)
	var cancel := UiKit.btn("Cancel", 15)
	cancel.name = "QuickSimCancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_close_quick_sim)
	box["footer"].add_child(cancel)


func _close_quick_sim() -> void:
	if _quick_sim != null and is_instance_valid(_quick_sim):
		_quick_sim.queue_free()
	_quick_sim = null


func _run_quick_sim(rounds: int) -> void:
	_close_quick_sim()
	GameState.quick_sim(rounds)
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


func _on_sim_round() -> void:
	GameState.advance()
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## You are out of the finals: run the remaining weeks out and show the winner.
func _on_sim_to_end() -> void:
	var guard := 0
	while not GameState.season.is_season_over() and guard < 10:
		GameState.advance()
		guard += 1
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## Router back hook: close the results popup before leaving the hub.
func handle_back() -> bool:
	if _quick_sim != null and is_instance_valid(_quick_sim):
		_close_quick_sim()
		return true
	if _sim_confirm != null and is_instance_valid(_sim_confirm):
		_close_sim_confirm()
		return true
	if _news_overlay != null and is_instance_valid(_news_overlay):
		_news_overlay.queue_free()
		_news_overlay = null
		return true
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
	overlay.name = "RoundResults"
	_results_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis(GameState.last_label, UiKit.BODY, UiKit.MUTED, true))
	var res: Dictionary = GameState.last_match
	var others := results
	if not res.is_empty() and GameState.is_my_match(res):
		# Your match first and biggest; the rest of the round underneath.
		_my_result(v, res)
		others = []
		for r in results:
			if not GameState.is_my_match(r):
				others.append(r)
		var review := UiKit.btn("Review match", 17)
		review.name = "ReviewMatch"
		review.custom_minimum_size = Vector2(0, 48)
		review.pressed.connect(_review_match)
		v.add_child(review)
	var outlook := GameState.finals_outcome_line(res)
	if outlook != "":
		v.add_child(UiKit.lbl(outlook, 15, UiKit.EMPH, true))
	if GameState.season.is_season_over():
		v.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(GameState.premier()),
				18, UiKit.TEXT, true))
	if not others.is_empty():
		v.add_child(UiKit.spacer(UiKit.GAP))
		v.add_child(UiKit.lbl("Other results" if others.size() < results.size() else "Results",
				UiKit.SMALL, UiKit.MUTED, true))
		v.add_child(_results_list(others))

	var ok := UiKit.btn("Continue", 17, true)
	ok.name = "ResultsContinue"
	ok.pressed.connect(func():
		overlay.queue_free()
		_results_overlay = null
		_build())
	box["footer"].add_child(ok)


## Your match in the round popup: the result, both scores, your best player,
## a serious injury, and what it did to the ladder. The rest is one tap away.
func _my_result(v: VBoxContainer, res: Dictionary) -> void:
	var s: Array = res["score"]
	var me := 0 if str(res["home"]) == GameState.my_club else 1
	var margin := absi(int(s[0]) - int(s[1]))
	var won := int(s[me]) > int(s[1 - me])
	var drew := int(s[0]) == int(s[1])
	var verdict := UiKit.lbl("Draw" if drew else ("Won by %d" if won else "Lost by %d") % margin,
			30, UiKit.TEXT if drew else UiKit.margin_colour(won), true)
	verdict.name = "MyVerdict"
	v.add_child(verdict)
	for side in [0, 1]:
		var row := UiKit.hbox(8)
		row.name = "MyScore_%d" % side
		var lost_side := not drew and int(s[side]) < int(s[1 - side])
		var nm := UiKit.ellipsis(GameDB.club_name(str(res["home"] if side == 0 else res["away"])),
				UiKit.BODY, UiKit.MUTED if lost_side else UiKit.TEXT, not lost_side and not drew)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UiKit.figure(UiKit.scoreline(int(res["goals"][side]), int(res["behinds"][side])),
				22, UiKit.MUTED if lost_side else UiKit.TEXT))
		v.add_child(row)
	var best := MatchNotes.standouts(res, me, 1)
	if not best.is_empty():
		var bl := UiKit.ellipsis("Best: %s %s  ·  %s" % [str(best[0]["name"]),
				MatchNotes.rating_text(float(best[0]["rating"])), str(best[0]["line"])],
				UiKit.SMALL, UiKit.TEXT)
		bl.name = "MyBest"
		v.add_child(bl)
	var hurt := GameState.my_new_injuries()
	if not hurt.is_empty():
		var inj := UiKit.lbl("Injured: " + ", ".join(hurt), UiKit.SMALL, UiKit.BAD, true)
		inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(inj)
	if GameState.last_phase == "regular":
		var moved := GameState.ladder_move_line(GameState.last_pos_before)
		if moved != "":
			var ml := UiKit.lbl(moved, UiKit.SMALL, UiKit.TEXT)
			ml.name = "LadderMove"
			v.add_child(ml)
		var nxt := GameState.next_fixture_line()
		if nxt != "":
			var nl := UiKit.lbl(nxt, UiKit.SMALL, UiKit.MUTED)
			nl.name = "NextFixture"
			v.add_child(nl)


## Open your last match at full time: the same summary and stats as after
## watching it. Nothing is played or applied again.
func _review_match() -> void:
	if GameState.last_match.is_empty():
		return
	if _results_overlay != null and is_instance_valid(_results_overlay):
		_results_overlay.queue_free()
		_results_overlay = null
	GameState.review_requested = true
	Router.go("match")


func _results_list(results: Array) -> Control:
	var v := UiKit.vbox(6)
	var narrow := _content_width() < 520.0
	for res in results:
		var mine: bool = GameState.is_my_match(res)
		var col := UiKit.TEXT if mine else UiKit.MUTED
		var s: Array = res["score"]
		var home_is_me: bool = str(res["home"]) == GameState.my_club
		var won: bool = (s[0] > s[1] and home_is_me) or (s[1] > s[0] and not home_is_me)
		var drew: bool = s[0] == s[1]
		var verdict := ""
		if mine:
			verdict = "Draw" if drew else ("Won" if won else "Lost")
		if narrow:
			var block := UiKit.vbox(2)
			var vcol := UiKit.MUTED if drew else UiKit.margin_colour(won)
			block.add_child(_result_side(str(res["home"]), int(res["goals"][0]),
					int(res["behinds"][0]), col, verdict if home_is_me else "", vcol))
			block.add_child(_result_side(str(res["away"]), int(res["goals"][1]),
					int(res["behinds"][1]), col, verdict if not home_is_me else "", vcol))
			v.add_child(block)
		else:
			var h := UiKit.hbox(6)
			h.add_child(UiKit.club_badge(str(res["home"]), 13, true, true))
			var hs := UiKit.line(UiKit.scoreline(int(res["goals"][0]), int(res["behinds"][0])),
					14, col, true)
			hs.custom_minimum_size = Vector2(78, 0)
			h.add_child(hs)
			# "v", not "def": the home side is listed first, not the winner.
			h.add_child(UiKit.line("v", 12, UiKit.MUTED))
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


func _result_side(code: String, goals: int, behinds: int, col: Color, verdict: String,
		vcol: Color = UiKit.TEXT) -> Control:
	var h := UiKit.hbox(6)
	h.add_child(UiKit.club_badge(code, 13, true, true))
	var score := UiKit.line(UiKit.scoreline(goals, behinds), 14, col, true)
	score.custom_minimum_size = Vector2(78, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(score)
	# Every row keeps the verdict column, so the scores line up.
	var tag := UiKit.line(verdict, 13, vcol, true)
	tag.custom_minimum_size = Vector2(40, 0)
	h.add_child(tag)
	return h


func _on_intake_draft() -> void:
	if GameState.begin_intake_draft():
		Router.go("draft")
		return
	if GameState.start_next_season():
		_build()
