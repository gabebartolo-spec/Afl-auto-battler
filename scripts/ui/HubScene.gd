extends Control
## Season hub: your next match, the ladder snapshot, and the round controls.

var _settings: Control
var _root: VBoxContainer
var _results_overlay: Control
var _media_overlay: Control
var _news_overlay: Control
var _sim_confirm: Control
var _quick_sim: Control
var _onboarding_overlay: Control
## A long press on Play round opens the play-ahead menu instead of playing one round.
var _hold_fired := false
var _hold_id := 0
var _pre_match: PreMatchVignette    # the scene over the wait after Play match
var _starting_match := false        # Play match with vignettes off: on the way to the match
const HOLD_SECONDS := 0.5
## How long the pre-match scene runs before the side goes through the banner: a
## moment of the warm-up, time to jog in to the huddle unhurried and stand together,
## then the run - still a couple of seconds of match day, not a wait (a tap goes straight
## to the run).
const PRE_MATCH_SECONDS := 3.8


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
	# The first visit's orientation comes before anything else waiting here;
	# a pending press conference follows when it closes.
	if GameState.needs_season_wrap():
		_show_season_wrap()
	elif not bool(GameState.get_setting("seen_weekly_loop_intro", false)):
		_show_weekly_loop_intro()
	elif GameState.media_conference_pending():
		_show_media_conference()


## A short first-hub orientation, shown where the weekly loop actually lives
## instead of front-loading a tutorial on the main menu.
func _show_weekly_loop_intro() -> void:
	if bool(GameState.get_setting("seen_weekly_loop_intro", false)):
		return
	if _onboarding_overlay != null and is_instance_valid(_onboarding_overlay):
		return
	var box := UiKit.modal_box(self, 520.0, 0.0)
	_onboarding_overlay = box["overlay"]
	_onboarding_overlay.name = "WeeklyLoopIntro"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Your week", UiKit.TITLE))
	for line in [
		"This is home base. Check the next opponent, then use Team to pick the side and Coaching if you want to change how you play.",
		"Play match when you want the live coaching calls. Play round plays the week out for you quickly; the match itself is the same either way.",
		"After the game, review what happened and change selection or training only when you have a reason. There is no weekly checklist to clear.",
	]:
		var l := UiKit.lbl(line, 14, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var skip := UiKit.btn("Skip", UiKit.BODY)
	skip.name = "SkipOnboarding"
	skip.flat = true
	skip.pressed.connect(_close_weekly_loop_intro)
	(box["footer"] as VBoxContainer).add_child(skip)
	var ok := UiKit.btn("Got it", 17, true)
	ok.name = "FinishOnboarding"
	ok.pressed.connect(_close_weekly_loop_intro)
	(box["footer"] as VBoxContainer).add_child(ok)


func _close_weekly_loop_intro() -> void:
	GameState.set_setting("seen_weekly_loop_intro", true)
	if _onboarding_overlay != null and is_instance_valid(_onboarding_overlay):
		_onboarding_overlay.queue_free()
	_onboarding_overlay = null
	if GameState.media_conference_pending():
		_show_media_conference()


## The off-season, wrapped up before Round 1 (ARD-M6-007): who came, who
## went, any staff change, what the board expects. Then begin the season.
func _show_season_wrap() -> void:
	var w: Dictionary = GameState.season_wrap
	var box := UiKit.modal_box(self, 520.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "SeasonWrap"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Off-season complete", 20, UiKit.TEXT, true))
	v.add_child(UiKit.lbl("Your %d list is set." % int(w.get("year", GameState.season_year)), 14, UiKit.MUTED))
	for part in [["In", "ins", "WrapIn"], ["Out", "outs", "WrapOut"]]:
		var rows: Array = w.get(part[1], [])
		if rows.is_empty():
			continue
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl(str(part[0]), 14, UiKit.MUTED, true))
		for i in range(rows.size()):
			var r: Dictionary = rows[i]
			var l := UiKit.lbl("%s  ·  %s" % [str(r["name"]), str(r["how"])], 14, UiKit.TEXT)
			l.name = "%s_%d" % [part[2], i]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	var trades: Array = w.get("trades", [])
	if not trades.is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("Trade period", 14, UiKit.MUTED, true))
		for i in range(trades.size()):
			var l := UiKit.lbl(str(trades[i]), 14, UiKit.TEXT)
			l.name = "WrapTrade_%d" % i
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	var staff: Array = w.get("staff", [])
	if not staff.is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("Coaching", 14, UiKit.MUTED, true))
		for line in staff:
			var l := UiKit.lbl(str(line), 14, UiKit.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	var league: Array = w.get("league_coaches", [])
	if not league.is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("New senior coaches", 14, UiKit.MUTED, true))
		for i in range(league.size()):
			var l := UiKit.lbl(str(league[i]), 14, UiKit.TEXT)
			l.name = "WrapLeagueCoach_%d" % i
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	if str(w.get("goal", "")) != "":
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("The board expects", 14, UiKit.MUTED, true))
		var goal := UiKit.lbl(str(w["goal"]), UiKit.NAME, UiKit.TEXT, true)
		goal.name = "WrapGoal"
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(goal)
		var why := UiKit.lbl(str(w.get("reason", "")), 14, UiKit.MUTED)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(why)
	var go := UiKit.btn("Begin season", UiKit.BODY, true)
	go.name = "BeginSeason"
	go.custom_minimum_size.y = 48
	go.pressed.connect(func():
		GameState.begin_season_from_wrap()
		overlay.queue_free())
	(box["footer"] as VBoxContainer).add_child(go)


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
	var settings := UiKit.btn("Settings", 14)
	settings.name = "HubSettings"
	settings.flat = true
	settings.custom_minimum_size = Vector2(64, 44)
	settings.add_theme_color_override("font_color", UiKit.MUTED)
	settings.pressed.connect(func(): _settings = OptionsSheet.open(self, true))
	_root.add_child(UiKit.top_bar(_week_title(season), false, settings))
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
	# The whole season - ladder, every player's numbers, awards, fixture,
	# trophy room (director, 2026-10-07: replaces Full ladder).
	var full := UiKit.btn("Season stats", 14)
	full.name = "SeasonStats"
	full.custom_minimum_size = Vector2(124, 44)
	full.pressed.connect(func(): Router.go("stats"))
	head.add_child(full)
	var width := _content_width() if _narrow() else _content_width() * 0.45
	v.add_child(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club, width, 0, false))
	return v


## Your season in a few lines: where you sit, your form, the board.
func _standing_card() -> Control:
	var cv := UiKit.vbox(3)
	cv.name = "SeasonBlock"
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := UiKit.club_badge(GameState.my_club, 16, false, true)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(badge)
	var lr := GameState.my_ladder_row()
	var title := UiKit.lbl("%s of %d  ·  %s  ·  %d pts" % [GameState.ordinal(GameState.my_position()),
			GameState.season.ladder.size(), GameState.my_record(), int(lr.get("pts", 0))],
			UiKit.H2, UiKit.TEXT, true)
	cv.add_child(title)
	var form := GameState.club_form_info(GameState.my_club)
	cv.add_child(_form_row(form))
	var last := _last_match_button()
	if last != null:
		cv.add_child(last)
	# The board lives in Coaching; here only when your job is at risk.
	if GameState.board_goal_text() != "":
		var conf := GameState.board_confidence()
		var warned := bool(GameState.board.get("warned", false))
		if warned or conf < ClubLife.WARN_LINE:
			var board_l := UiKit.lbl("Board: %s  ·  %s%s" % [GameState.board_state(), GameState.board_goal_text(),
					"  (final warning)" if warned else ""], UiKit.SMALL, UiKit.BAD)
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


## This week's decision. Answer it here; unanswered when the round is
## played, it changes nothing - or costs what its hint says (ClubLife).
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
		var silence := str((e.get("unanswered", {}) as Dictionary).get("hint", ""))
		if silence != "":
			hints.append(silence)
		var h := UiKit.lbl("\n".join(hints), UiKit.FINE, UiKit.MUTED)
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
	v.add_child(UiKit.lbl("You have been sacked", UiKit.TITLE, UiKit.BAD, true))
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
			v.add_child(UiKit.lbl(when, UiKit.SECONDARY, UiKit.EMPH, true))
			last_when = when
		var l := UiKit.lbl(str(item["text"]), UiKit.SECONDARY, UiKit.TEXT)
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
	var notice := _staff_notice()
	if notice != null:
		nv.add_child(notice)
	if not GameState.pending_mro_challenges().is_empty():
		nv.add_child(_tribunal_card())
	if season.is_season_over():
		nv.add_child(UiKit.lbl("Season complete", UiKit.H1, UiKit.TEXT, true))
		nv.add_child(UiKit.ellipsis("Premiers: %s" % GameDB.club_name(GameState.premier()),
				16, UiKit.TEXT))
		var ru: String = str(season.finals.get("runner_up", ""))
		nv.add_child(UiKit.ellipsis("Runners-up: %s" % GameDB.club_name(ru),
				UiKit.SECONDARY, UiKit.MUTED))
		var medal: Array = GameState.season_awards.get("brownlow", [])
		var medallist: Dictionary = GameState.season_awards.get("brownlow_winner", {})
		if medallist.is_empty() and not medal.is_empty():
			medallist = medal[0]
		if not medallist.is_empty():
			nv.add_child(UiKit.ellipsis("Brownlow: %s (%d votes)" % [
					GameState.award_name(medallist), int(medallist["votes"])], 13, UiKit.TEXT))
	elif _regular_bye(season):
		nv.add_child(UiKit.lbl("Bye", UiKit.H1, UiKit.TEXT, true))
		nv.add_child(UiKit.lbl(
				"No game for you in Round %d. The rest of the league plays on." % (season.round_index + 1),
				UiKit.BODY, UiKit.MUTED))
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
						"Your finals campaign is over. Play out the rest of the series to see who lifts the cup.",
						UiKit.BODY, UiKit.MUTED))
			_:
				nv.add_child(UiKit.lbl("Season over for you", UiKit.H1, UiKit.BAD, true))
				nv.add_child(UiKit.lbl(
						"You missed the top %d. Play out the finals series to see who lifts the cup." % Season.FINALISTS,
						UiKit.BODY, UiKit.MUTED))
	else:
		var mine: Dictionary = _upcoming_match()
		var opp: String = mine["away"] if mine["home"] == GameState.my_club else mine["home"]
		var is_home: bool = mine["home"] == GameState.my_club
		var ground := str(mine.get("venue", ""))
		if ground == "":
			ground = str(GameDB.club(str(mine["home"])).get("ground", ""))
		# Who, then where: "Essendon", "Away · Marvel Stadium" (the director's
		# PC playtest, 2026-10-07: "Marvel Stadium / at Essendon" read as if
		# Essendon were the ground).
		var who := UiKit.lbl(GameDB.club_name(opp), 26 if _narrow() else 30, UiKit.TEXT, true)
		who.name = "Opponent"
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(who)
		# The forecast is known in the week (ARD-M4-016): a fact beside the
		# ground, not advice.
		var wx := str(mine.get("weather", ""))
		var where_text := "%s · %s" % ["Home" if is_home else "Away", ground]
		if wx != "":
			where_text += " · " + Weather.label(wx)
		var where := UiKit.lbl(where_text, UiKit.BODY, UiKit.MUTED)
		where.name = "MatchVenue"
		where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(where)
		var marquee := MarqueeGames.tradition(str(mine["home"]), str(mine["away"]))
		if not marquee.is_empty():
			var marquee_line := UiKit.lbl(str(marquee["name"]), UiKit.SMALL, UiKit.EMPH, true)
			marquee_line.name = "MarqueeContext"
			nv.add_child(marquee_line)
		var rivalry := GameState.rivalry_context(GameState.my_club, opp)
		if not rivalry.is_empty():
			var rivalry_line := UiKit.lbl(str(rivalry["title"]), UiKit.SMALL, UiKit.EMPH, true)
			rivalry_line.name = "RivalryContext"
			nv.add_child(rivalry_line)
			if str(rivalry.get("detail", "")) != "":
				var rivalry_detail := UiKit.lbl(str(rivalry["detail"]), UiKit.SMALL, UiKit.MUTED)
				rivalry_detail.name = "RivalryDetail"
				nv.add_child(rivalry_detail)
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
			var nl := UiKit.lbl(str(notes[i]["text"]), UiKit.BODY,
					UiKit.BAD if str(notes[i].get("key", "")) == "own_injury" else UiKit.TEXT)
			nl.name = "OwnNote_%d" % i
			nv.add_child(nl)
	if not GameState.week_event.is_empty() and not season.is_season_over():
		nv.add_child(UiKit.spacer(4))
		nv.add_child(_event_card())
	nv.add_child(UiKit.spacer(4))
	nv.add_child(_week_actions(season))
	return nv


## A live MRO sanction can be challenged once before the next round. Keep it
## on the weekly hub rather than hiding the decision in the result popup.
func _tribunal_card() -> Control:
	var panel := UiKit.panel(UiKit.PANEL, 12)
	panel.name = "TribunalCard"
	var v := UiKit.vbox(6)
	panel.add_child(v)
	v.add_child(UiKit.lbl("Tribunal", UiKit.BODY, UiKit.TEXT, true))
	for row in GameState.pending_mro_challenges():
		var p := GameState.list_player(str(row.get("id", "")))
		var name := str(row.get("name", "")) if p.is_empty() else GameDB.player_display_name(p)
		var sanction := ""
		if str(row.get("outcome", "")) == "suspension":
			var w := int(row.get("weeks", 0))
			sanction = "%d-match suspension" % w
		else:
			sanction = "MRO fine"
		var stage := str(row.get("stage", "tribunal"))
		var hearing := "Appeals Board" if stage == "appeal" else "Tribunal"
		var line := UiKit.lbl("%s — %s. %s case: %s." % [
				name, sanction, hearing, str(row.get("case", "Difficult"))], 13, UiKit.TEXT, true)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(line)
		var status := UiKit.lbl("Brownlow: ineligible unless the %s succeeds." % (
				"appeal" if stage == "appeal" else "challenge"), 12, UiKit.MUTED, true)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(status)
		var b := UiKit.btn("Appeal to Appeals Board" if stage == "appeal" else "Challenge at Tribunal",
				14, false)
		b.custom_minimum_size.y = 44
		b.pressed.connect(func():
			if stage == "appeal":
				GameState.appeal_mro(str(row.get("id", "")))
			else:
				GameState.challenge_mro(str(row.get("id", "")))
			_build.call_deferred())
		v.add_child(b)
	return panel


## Team form reads green when good, red when poor, muted when steady.
## "Form: Poor  ·  LLWL" with each result in its own colour - a win reads
## as a win inside a poor run - and the letters kept, so colour is never the
## only signal.
func _form_row(form: Dictionary) -> Control:
	var row := UiKit.hbox(0)
	var last := str(form.get("last", ""))
	var head := UiKit.line(GameState.form_line(form) if last == "" else
			GameState.form_line(form).trim_suffix(last), UiKit.SMALL, _form_colour(float(form["value"])))
	head.name = "FormLine"
	row.add_child(head)
	var streak := UiKit.hbox(1)
	streak.name = "FormStreak"
	row.add_child(streak)
	for ch in last:
		var col := UiKit.GOOD if ch == "W" else (UiKit.BAD if ch == "L" else UiKit.MUTED)
		var l := UiKit.line(ch, UiKit.SMALL, col, true)
		l.name = "Result_%s" % ch
		streak.add_child(l)
	return row


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
	elif _regular_bye(season):
		# A home-and-away bye: the season goes on, one round at a time.
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		var bye := _nav_button("Play Round %d" % (season.round_index + 1), _on_sim_round, true)
		bye.name = "SimByeRound"
		buttons.append(bye)
	elif _upcoming_match().is_empty() and GameState.my_finals_status() == "bye":
		# Still alive: sim only this week, never past your own final.
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		buttons.append(_nav_button("Play %s" % _finals_label(), _on_sim_round, true))
	elif _upcoming_match().is_empty():
		# Out of the finals, the league still plays them week by week: each
		# week's results come up before the next, and the rest of the series
		# is one tap further if you would rather skip it.
		var skip := _nav_button("Play to Grand Final", _on_sim_to_end)
		skip.name = "SimToGrandFinal"
		buttons.append(skip)
		var week := _nav_button("Play %s" % _finals_label(), _on_sim_round, true)
		week.name = "SimFinalsWeek"
		buttons.append(week)
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
		buttons.append(_coaching_button())
		buttons.append(_nav_button("Main menu", func(): Router.to_main_menu()))
	else:
		buttons.append(_nav_button("Training", func(): Router.go("training")))
		buttons.append(_nav_button("My list", func(): Router.go("list")))
		buttons.append(_coaching_button())
		if not _upcoming_match().is_empty():
			var sim := _nav_button("Play round", _on_sim_round_pressed)
			sim.name = "SimRound"
			_wire_long_press(sim)
			buttons.append(sim)
	# Four across a 360 px phone: tighter type and padding there, so no
	# label is cut short.
	var tight := _content_width() < 380.0 and buttons.size() >= 4
	var row := UiKit.hbox(4 if tight else 6)
	row.name = "HubFooter"
	for b in buttons:
		b.add_theme_font_size_override("font_size", 13 if tight else 15)
		b.custom_minimum_size = Vector2(0, 44)
		if tight:
			for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				var sb: StyleBox = b.get_theme_stylebox(state)
				if sb != null:
					sb = sb.duplicate()
					sb.content_margin_left = 4
					sb.content_margin_right = 4
					b.add_theme_stylebox_override(state, sb)
		row.add_child(b)
	return row


## A coach has left your staff (retired, or taken a job elsewhere): say who
## and where, and lead to the appointment. Until the job is filled it waits
## here, not only as a badge on the Coaching tab.
func _staff_notice() -> Control:
	var reasons := []
	for vac in GameState.staff_vacancies:
		if str(vac.get("reason", "")) != "":
			reasons.append(str(vac["reason"]))
	if reasons.is_empty():
		return null
	var v := UiKit.vbox(4)
	v.name = "StaffNotice"
	for r in reasons:
		var l := UiKit.lbl(r, UiKit.BODY, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var go := UiKit.btn("Appoint a replacement" if reasons.size() == 1 else "Appoint replacements", UiKit.BODY)
	go.name = "StaffNoticeGo"
	go.custom_minimum_size = Vector2(0, 44)
	go.pressed.connect(func(): Router.go("staff"))
	v.add_child(go)
	v.add_child(UiKit.rule())
	return v


## Coaching: staff, how we play, form, the list and the board. An open job
## on your staff shows on the tab until it is filled.
func _coaching_button() -> Button:
	var jobs := GameState.staff_vacancies.size()
	var b := _nav_button("Coaching" if jobs == 0 else "Coaching · %d" % jobs, func(): Router.go("coaching"))
	b.name = "HubCoaching"
	return b


func _nav_button(text: String, cb: Callable, primary := false) -> Button:
	var b := UiKit.btn(text, UiKit.NAME, primary)
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


## A home-and-away round your club sits out: an odd club count (expansion)
## rotates a bye. Not the end of your season - that is only once the
## home-and-away rounds are done.
func _regular_bye(season: Season) -> bool:
	return season != null and not season.is_season_over() \
			and not season.is_regular_done() and _upcoming_match().is_empty()


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
						"label": "Round %d" % (season.round_index + 1), "tag": "",
						"weather": season.weather_for(str(m["home"]), str(m["away"]), season.round_index)}
		return {}
	for m in season.finals_week_matches():
		if str(m["home"]) == "" or str(m["away"]) == "":
			continue
		if m["home"] == GameState.my_club or m["away"] == GameState.my_club:
			return {"home": m["home"], "away": m["away"],
					"label": str(m["label"]), "tag": str(m["tag"]),
					"venue": season.finals_venue(m),
					"weather": season.weather_for(str(m["home"]), str(m["away"]),
							Season.REGULAR_ROUNDS + int(season.finals["week"]), m)}
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
	if _pre_match != null or _starting_match:
		return
	if not GameState.vignettes_on():
		# Vignettes off (Settings): no banner scene, straight to the match.
		_starting_match = true
		if not GameState.prepare_interactive_match():
			_starting_match = false
			_on_sim_round()
			return
		Router.go("match")
		return
	# The pre-match scene goes up in this frame: a couple of seconds of
	# match day (warm-up, final words, through the banner) while the match
	# is set up underneath. A tap sends them through the banner at once.
	var m := _upcoming_match()
	var mine := GameState.my_club
	var opp := str(m["away"]) if str(m["home"]) == mine else str(m["home"])
	var season: Season = GameState.season
	# Everyone named runs out: the 18 on the ground and the interchange.
	var opp_squad := Squad.new(opp, season.lists[opp], false, opp, season.selections.get(opp, {}))
	var opp_ground: Array = opp_squad.ground + opp_squad.bench
	var heading := "%s  ·  %s v %s" % [str(m["label"]), GameDB.club_name(str(m["home"])),
			GameDB.club_name(str(m["away"]))]
	# The banner's occasion (Banners.pick): finals week, marquee game, must-win, spoon
	# bowl, milestones (GameState.banner_context).
	var label := str(m["label"])
	var banner_ctx := GameState.banner_context(m)
	_pre_match = PreMatchVignette.open(get_tree().root, mine, opp,
			GameState.my_squad().ground + GameState.my_squad().bench, opp_ground, heading,
			PreMatchVignette.is_final(label), banner_ctx)
	# Home-and-away rounds and finals both play live with the coach box.
	await get_tree().process_frame
	if not GameState.prepare_interactive_match():
		_pre_match.get_parent().queue_free()
		_pre_match = null
		_on_sim_round()
		return
	_pre_match.play_through(PRE_MATCH_SECONDS)
	await _pre_match.done
	Router.go("match")


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
	v.add_child(UiKit.heading("Play %s?" % str(m["label"]), UiKit.H1))
	var why := UiKit.lbl("Your match will be played out without you.", UiKit.BODY, UiKit.TEXT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var go := UiKit.btn("Play round", 17, true)
	go.name = "SimConfirmGo"
	go.custom_minimum_size = Vector2(0, 48)
	go.pressed.connect(func():
		_close_sim_confirm()
		_on_sim_round())
	box["footer"].add_child(go)
	var cancel := UiKit.btn("Cancel", UiKit.NAME)
	cancel.name = "SimConfirmCancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_close_sim_confirm)
	box["footer"].add_child(cancel)
	var never := UiKit.btn("Don't ask again", UiKit.NAME)
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
	v.add_child(UiKit.heading("Play ahead", UiKit.H1))
	var why := UiKit.lbl("Your matches are played out for you. It always stops before the finals.",
			UiKit.SMALL, UiKit.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var four_to := mini(now + 3, last)
	var options := [
		["QuickSimOne", "Play this round (Round %d)" % now, 1],
		["QuickSimFour", "Skip to Round %d" % (four_to + 1) if four_to < last
				else "Skip to the end of the home and away", 4],
		["QuickSimAll", "Skip to the end of the home and away (after Round %d)" % last, -1],
	]
	for o in options:
		var b := UiKit.btn(str(o[1]), UiKit.BODY)
		b.name = str(o[0])
		b.custom_minimum_size = Vector2(0, 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var n := int(o[2])
		b.pressed.connect(func(): _run_quick_sim(n))
		box["footer"].add_child(b)
	var cancel := UiKit.btn("Cancel", UiKit.BODY)
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
	# Only ever the finals: never sim through home-and-away rounds.
	if not GameState.season.is_regular_done():
		return
	var guard := 0
	while not GameState.season.is_season_over() and guard < 10:
		GameState.advance()
		guard += 1
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## Router back hook: close the results popup before leaving the hub.
func handle_back() -> bool:
	if _pre_match != null:
		return true     # the side is on its way out
	if _onboarding_overlay != null and is_instance_valid(_onboarding_overlay):
		_close_weekly_loop_intro()
		return true
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
		_settings = null
		return true
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
	# Back skips the press conference, as its Skip button does (natural
	# Android Back); an overlay opened over it closes first.
	if _media_overlay != null and is_instance_valid(_media_overlay):
		GameState.skip_media_conference()
		_media_overlay.queue_free()
		_media_overlay = null
		_build()
		return true
	return false



func _show_media_conference() -> void:
	if not GameState.media_conference_pending():
		return
	if _media_overlay != null and is_instance_valid(_media_overlay):
		return
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_media_overlay = box["overlay"]
	_media_overlay.name = "MediaConference"
	var v: VBoxContainer = box["body"]
	# Vignettes off (Settings): no stage, the question straight away.
	var scene: MediaConferenceVignette = null
	if GameState.vignettes_on():
		var stage := Control.new()
		stage.name = "MediaConferenceStage"
		stage.custom_minimum_size = Vector2(0, minf(300.0, get_viewport_rect().size.y * 0.38))
		v.add_child(stage)
		scene = MediaConferenceVignette.open(stage, GameState.my_club)
	var prompt := UiKit.vbox(6)
	prompt.visible = scene == null
	v.add_child(prompt)
	prompt.add_child(UiKit.lbl("Journalist", UiKit.SMALL, UiKit.MUTED, true))
	var q := UiKit.lbl(str(GameState.media_conference.get("question", "")), 16, UiKit.TEXT)
	q.name = "MediaQuestion"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_child(q)
	var footer: VBoxContainer = box["footer"]
	footer.visible = false
	var opts: Array = GameState.media_conference.get("options", [])
	for i in range(opts.size()):
		var b := UiKit.btn(str((opts[i] as Dictionary).get("label", "")), 15)
		b.name = "MediaAnswer_%d" % i
		b.custom_minimum_size = Vector2(0, 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var choice := i
		b.pressed.connect(func():
			GameState.resolve_media_conference(choice)
			_media_overlay.queue_free()
			_media_overlay = null
			_build())
		footer.add_child(b)
	var skip := UiKit.btn("Skip press conference", 14)
	skip.name = "MediaSkip"
	skip.flat = true
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(func():
		GameState.skip_media_conference()
		_media_overlay.queue_free()
		_media_overlay = null
		_build())
	footer.add_child(skip)
	if scene == null:
		footer.visible = true
		return
	scene.ready_for_question.connect(func():
		prompt.visible = true
		footer.visible = true)


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
		v.add_child(UiKit.lbl(outlook, UiKit.BODY, UiKit.EMPH, true))
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
		_build()
		if GameState.media_conference_pending():
			_show_media_conference())
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
				UiKit.NUMBER, UiKit.MUTED if lost_side else UiKit.TEXT))
		v.add_child(row)
	# FL-006: editorial flavour, only when the match's facts support it - quiet
	# text under the facts, never coloured like a result.
	var line := Headlines.for_match(res, me)
	if line != "":
		var hl := UiKit.lbl(line, UiKit.BODY, UiKit.MUTED)
		hl.name = "MyHeadline"
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hl)
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
	var mro := GameState.my_mro_lines()
	if not mro.is_empty():
		var mr := UiKit.lbl("MRO: " + ", ".join(mro), UiKit.SMALL, UiKit.BAD, true)
		mr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(mr)
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
				var tag := UiKit.line(verdict, UiKit.SECONDARY,
						UiKit.MUTED if drew else UiKit.margin_colour(won), true)
				tag.custom_minimum_size = Vector2(48, 0)
				h.add_child(tag)
			v.add_child(h)
	return v


func _result_side(code: String, goals: int, behinds: int, col: Color, verdict: String,
		vcol: Color = UiKit.AUTO_COLOUR) -> Control:
	if vcol == UiKit.AUTO_COLOUR:
		vcol = UiKit.TEXT
	var h := UiKit.hbox(6)
	h.add_child(UiKit.club_badge(code, 13, true, true))
	var score := UiKit.line(UiKit.scoreline(goals, behinds), 14, col, true)
	score.custom_minimum_size = Vector2(78, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(score)
	# Every row keeps the verdict column, so the scores line up.
	var tag := UiKit.line(verdict, UiKit.SECONDARY, vcol, true)
	tag.custom_minimum_size = Vector2(40, 0)
	h.add_child(tag)
	return h


func _on_intake_draft() -> void:
	if GameState.begin_intake_draft():
		Router.go("draft")
		return
	if GameState.start_next_season():
		_build()
