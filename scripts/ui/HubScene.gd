extends Control
## Season hub: your next match, the ladder snapshot, and the round controls.

var _name_index := {}
var _settled := false   # the hub has shown once this visit; no more entrances
## Where your club sat the last time the hub showed it (this run of the game
## only; presentation, never saved): {"key": season instance, "pos": n}.
static var _ladder_seen := {}
var _finals_overlay: Control = null
var _settings: Control
var _root: VBoxContainer
var _results_overlay: Control
var _media_overlay: Control
var _talk_overlay: Control
var _midseason_overlay: Control
var _news_overlay: Control
var _rule_overlay: Control
var _sim_confirm: Control
var _onboarding_overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	# A pre-season is running: it has its own screen until Round 1 is next.
	# The off-season wrap is read here first.
	if GameState.preseason_active() and not GameState.needs_season_wrap():
		Router.replace("preseason")
		return
	# A response tapped last time that never reached a match does not wait here.
	GameState.call_intent = {}
	MatchKickoff.reset()
	_warm_pre_match.call_deferred()

	add_child(ClubBackdrop.new().setup(GameState.my_club).live())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	# The club's stripes sweep in first (ClubBackdrop.live, 0.6 s); the screen's
	# own content fades up 0.2 s later, so the slide is what you see.
	if UiKit.motion_on():
		margin.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_interval(0.2)
		fade.tween_property(margin, "modulate:a", 1.0, 0.3)

	_root = UiKit.vbox(10)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_on_resize)
	# A draft pick with nobody left to take is no choice: it passes here,
	# before the news is built, instead of opening a card with only Pass.
	MidseasonDraft.pass_if_nobody_left(GameState)
	RookieList.pass_if_nobody_left(GameState)
	_build()
	# The first visit's orientation comes before anything else waiting here;
	# a pending press conference follows when it closes.
	if GameState.needs_season_wrap():
		_show_season_wrap()
	elif GameState.intro_due("weekly_loop"):
		_show_weekly_loop_intro()
	else:
		_show_week_ask()


## The week's one optional ask, if any (director, 2026-10-09: one a week): a
## sit-down with a player whose promised run just ended, or the press.
func _show_week_ask() -> void:
	# Sacked, the week's asks (carnival, mid-season pick, press) are the club's,
	# not his: the card is the only thing on the hub.
	if GameState.is_sacked():
		return
	if not MidseasonDraft.carnival_lines(GameState).is_empty():
		_show_carnival()
	elif MidseasonDraft.waiting(GameState):
		_show_midseason_pick()
	elif RookieList.waiting(GameState):
		RookieDraftSheet.open(self, _build, RookieDraftSheet.PASS_HUB)
	elif GameState.backing_talk_pending():
		_show_backing_talk()
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
		"Play match when you want the live coaching calls. Sim the week plays the round out for you quickly; the match itself is the same either way.",
		"After the game, review what happened and change selection or training only when you have a reason. There is no weekly checklist to clear.",
	] if not WeekChecklist.on(GameState) else [
		"This is home base. Check the next opponent, then use Team to pick the side and Coaching if you want to change how you play.",
		"Each week a short list here shows the jobs still open: look over the side, check training, and anything waiting on you. Tap a job to go to it; it ticks when done.",
		"The list is a guide, never a gate. Play match or Sim the week whenever you are ready, jobs left or not.",
	]:
		var l := UiKit.lbl(line, 14, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var skip := UiKit.btn("Skip", UiKit.BODY)
	skip.name = "SkipOnboarding"
	skip.flat = true
	skip.pressed.connect(_close_weekly_loop_intro)
	(box["footer"] as VBoxContainer).add_child(skip)
	var ok := UiKit.btn("Got it", UiKit.NAME, true)
	ok.name = "FinishOnboarding"
	ok.pressed.connect(_close_weekly_loop_intro)
	(box["footer"] as VBoxContainer).add_child(ok)


func _close_weekly_loop_intro() -> void:
	GameState.set_setting("seen_weekly_loop_intro", true)
	if _onboarding_overlay != null and is_instance_valid(_onboarding_overlay):
		_onboarding_overlay.queue_free()
	_onboarding_overlay = null
	_show_week_ask()


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
	# Free agents you were after who chose a rival, and why (P-18): the
	# rival's name in its ink. This session's market only (not saved).
	var lost: Array = GameState.fa_lost_lines()
	if not lost.is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(UiKit.lbl("Free agency", 14, UiKit.MUTED, true))
		for i in range(lost.size()):
			var club := str(lost[i]["club"])
			var l := NameInk.label(str(lost[i]["text"]), {GameDB.club_name(club): club}, 14, UiKit.TEXT)
			l.name = "WrapFreeAgent_%d" % i
			if l is Label:
				(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# With a pre-season to come, the wrap leads into it; a career saved at the
	# wrap before pre-seasons existed begins its season as it always did.
	# Last season's page in the club almanac.
	var page: Dictionary = GameState.almanac.back() if not GameState.almanac.is_empty() else {}
	var first := Almanac.first_sentence(str(page.get(Almanac.STORY_KEY, "")))
	if first != "":
		var lead := UiKit.lbl(first, 14, UiKit.MUTED)
		lead.name = "WrapAlmanacStory"
		lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(box["footer"] as VBoxContainer).add_child(lead)
	var alm := UiKit.btn("Club almanac", UiKit.BODY)
	alm.name = "WrapAlmanac"
	alm.flat = true
	alm.pressed.connect(func(): Router.go("almanac"))
	(box["footer"] as VBoxContainer).add_child(alm)
	var to_preseason: bool = GameState.preseason_active()
	var go := UiKit.btn("Start the pre-season" if to_preseason else "Begin season", UiKit.BODY, true)
	go.name = "BeginSeason"
	go.custom_minimum_size.y = 48
	go.pressed.connect(func():
		GameState.begin_season_from_wrap()
		overlay.queue_free()
		if to_preseason:
			Router.replace("preseason"))
	(box["footer"] as VBoxContainer).add_child(go)


func _on_resize() -> void:
	if not is_inside_tree() or GameState.season == null or UiKit.keyboard_resize(self):
		return
	_build()


func _content_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


func _narrow() -> bool:
	return _content_width() < 680.0


func _build() -> void:
	UiKit.clear(_root)
	_name_index = {}
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
		# The jobs on offer and the record run past a phone's height: it scrolls.
		var sp := UiKit.vbox(UiKit.SECTION)
		_root.add_child(UiKit.scroll(sp))
		# A finished career (retired, or no second chance left) has one job:
		# the record. The club's standing, pick and board mean nothing now.
		if not ClubMoves.career_over(GameState):
			sp.add_child(_standing_card())
		sp.add_child(_sacked_card())
		return

	# One page that scrolls: this week first, then your season, the news and
	# the whole ladder at its natural height. Nothing is squeezed to fit.
	var page := UiKit.vbox(UiKit.SECTION)
	var page_scroll := UiKit.scroll(page)
	_root.add_child(page_scroll)
	var week := _week_section(season)
	# PC: the ladder and the league's front page stand side by side in the right
	# column, both in view without scrolling (director, 2026-10-14).
	var right_w := (_content_width() - 28.0) * 0.56
	# With no news yet the ladder has the column to itself: its table is laid out
	# for that width, so the record stays beside its club (row-gap rule).
	var ladder_w := right_w * (1.0 if GameState.news.is_empty() else 0.42)
	var ladder := _ladder_section(season, -1.0 if _narrow() else ladder_w)
	var ladder_hugs := false
	if _narrow():
		if TrainingReport.hub_due(GameState):
			page.add_child(TrainingReportSheet.hub_card(self, _go_retrain))
		page.add_child(week)
		page.add_child(UiKit.rule())
		page.add_child(_standing_card())
		if not GameState.news.is_empty():
			page.add_child(_news_card())
		page.add_child(ladder)
	else:
		var cols := UiKit.hbox(28)
		cols.name = "HubColumns"
		page.add_child(cols)
		var left := UiKit.vbox(UiKit.SECTION)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(left)
		if TrainingReport.hub_due(GameState):
			left.add_child(TrainingReportSheet.hub_card(self, _go_retrain))
		left.add_child(week)
		left.add_child(UiKit.rule())
		left.add_child(_standing_card())
		# The front page sits under the ladder, in the space it leaves empty.
		var right := UiKit.hbox(20)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 1.25
		left.size_flags_stretch_ratio = 1.0
		cols.add_child(right)
		# A table whose club column stops at the names ends at its last column:
		# the column hugs it and the front page (or, with no news, the week)
		# takes the rest, so no dead space opens right of the ladder on a wide
		# screen (6.Q18).
		ladder_hugs = _ladder_hugs(ladder)
		ladder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if ladder_hugs \
				else Control.SIZE_EXPAND_FILL
		ladder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		right.add_child(ladder)
		if ladder_hugs and GameState.news.is_empty():
			right.size_flags_horizontal = Control.SIZE_SHRINK_END
		if not GameState.news.is_empty():
			var news := _news_card()
			news.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			news.size_flags_stretch_ratio = 1.2
			news.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			right.add_child(news)
	if _narrow():
		_root.add_child(_bar_air(UiKit.BG, page_scroll))
		_root.add_child(_footer(season))
	else:
		# On a wide screen the rest of the club stays pinned, but only under
		# the ladder column, not stretched across the page (director: no
		# full-width bars on PC).
		_root.add_child(_bar_air(UiKit.BG, page_scroll))
		var foot := UiKit.hbox(28)
		foot.name = "HubFooterWide"
		_root.add_child(foot)
		# Under the week column, the week's own decisions (Pick the side, Play
		# match): pinned, so the live coaching option is always in view beside
		# the quick Play round (director, web's pass 2026-10-12).
		var week_row := _week_actions(season)
		week_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		week_row.size_flags_vertical = Control.SIZE_SHRINK_END
		# Play round sits with the match choices (Pick the side | Play match |
		# Play round), so the bar reads as one group of match actions on the
		# left and the club's screens on the right.
		if not season.is_season_over() and not _upcoming_match().is_empty():
			week_row.add_child(_sim_round_button())
		# The same split as the columns above, so the club buttons stand under the ladder.
		week_row.size_flags_stretch_ratio = 1.0
		foot.add_child(_with_jobs_note(week_row))
		var row := _footer(season, false)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_stretch_ratio = 1.25
		if ladder_hugs and GameState.news.is_empty():
			# The ladder's column hugs its table: the club buttons keep under it.
			row.size_flags_horizontal = Control.SIZE_SHRINK_END
			row.custom_minimum_size.x = ladder.get_combined_minimum_size().x
		foot.add_child(row)
	# Motion plays once per visit, not on every rebuild after an answer.
	_settled = true


## From the training report: Training, at that player's choice.
func _go_retrain(id: String) -> void:
	TrainingScene.open_player_id = id
	Router.go("training")


## "Round 4", a finals week, or the season.
func _week_title(season: Season) -> String:
	if season.is_season_over():
		return "%d season" % GameState.season_year
	if not season.is_regular_done():
		return "Round %d of %d" % [season.round_index + 1, Season.REGULAR_ROUNDS]
	return _finals_label()


func _ladder_section(season: Season, table_width := -1.0) -> Control:
	var v := UiKit.vbox(6)
	v.name = "LadderSection"
	var head := UiKit.hbox(8)
	v.add_child(head)
	# The heading is the way in: the whole season (ladder, every player's
	# numbers, awards, fixture; director, 2026-10-07) sits
	# behind "Ladder". One nav idiom on the hub (audit §8 Phase 1.1): the
	# footer row and this heading, no third kind of button.
	var full := UiKit.section_link("Ladder", "Season stats ›", "SeasonStats")
	full.pressed.connect(func(): Router.go("stats"))
	head.add_child(full)
	# September: the series beside the ladder it came from, said as words.
	if not season.finals.is_empty():
		var series := UiKit.text_action("Finals ›")
		series.name = "FinalsOpen"
		series.pressed.connect(_show_finals)
		head.add_child(series)
	var width := _content_width() if _narrow() else _content_width() * 0.45
	if table_width > 0.0:
		width = table_width
	v.add_child(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club, width, 0, false))
	return v


## True when the ladder table ends at its last column (its club column stops
## at the names) rather than stretching to the width it was given.
static func _ladder_hugs(section: Control) -> bool:
	for c in section.get_children():
		if c is VBoxContainer and (c as Control).size_flags_horizontal == Control.SIZE_SHRINK_BEGIN:
			return true
	return false


## Your season in a few lines: where you sit, your form, the board.
func _standing_card() -> Control:
	var cv := UiKit.vbox(3)
	cv.name = "SeasonBlock"
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := UiKit.club_badge(GameState.my_club, 16, false, true)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(badge)
	var lr := GameState.my_ladder_row()
	# Where you sit, big, in your colour; the record beside it.
	var pos_row := UiKit.hbox(10)
	var pos := UiKit.figure(GameState.ordinal(GameState.my_position()), UiKit.HERO, UiKit.club_vivid(GameState.my_club))
	pos.name = "LadderPosition"
	if not _settled:
		# Arriving at the hub, your spot climbs (or slides) into place from
		# where you were last time you looked (the first look of a season
		# counts from the foot of the ladder). It lands with weight at full
		# time, where the move is on screen (MatchScene), not here, below
		# the fold on a phone.
		var now := GameState.my_position()
		var key := GameState.season.get_instance_id()
		var was := int(_ladder_seen.get("pos", 0)) if int(_ladder_seen.get("key", 0)) == key else 0
		_ladder_seen = {"key": key, "pos": now}
		UiKit.count_up(pos, now, func(n): return GameState.ordinal(n), 0.8,
				was if was > 0 else GameState.season.ladder.size())
	pos_row.add_child(pos)
	var title := UiKit.ellipsis("of %d  ·  %s  ·  %d pts" % [GameState.season.ladder.size(),
			GameState.my_record(), int(lr.get("pts", 0))], UiKit.H2, UiKit.TEXT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pos_row.add_child(title)
	cv.add_child(pos_row)
	# Your list as one number and where the club is in its cycle (TeamRating).
	var outlook := GameState.team_outlook(GameState.my_club)
	if not outlook.is_empty():
		var tl := UiKit.lbl(str(outlook["line"]), UiKit.SECONDARY, UiKit.MUTED)
		tl.name = "MyTeamOutlook"
		cv.add_child(tl)
	# The last rounds on: where your first pick falls if the season ended today.
	# Sacked, the pick and the board belong to the club he is leaving.
	var pick_line := "" if GameState.is_sacked() else GameState.pick_order_line()
	if pick_line != "":
		var pl := UiKit.lbl(pick_line, UiKit.SECONDARY, UiKit.TEXT)
		pl.name = "DraftPickLine"
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(pl)
	var form := GameState.club_form_info(GameState.my_club)
	cv.add_child(_form_row(form))
	var last := _last_match_button()
	if last != null:
		cv.add_child(last)
	# The club almanac: your career, season by season.
	var alm := UiKit.text_action("Club almanac  ›", UiKit.SECONDARY)
	alm.name = "HubAlmanac"
	alm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	alm.pressed.connect(func(): Router.go("almanac"))
	cv.add_child(alm)
	# The board lives in Coaching; here only when your job is at risk.
	if GameState.board_goal_text() != "" and not GameState.is_sacked():
		var warned := bool(GameState.board.get("warned", false))
		# The warning fires under ClubLife.POOR_LINE on every board type.
		var warning := GameState.board_warning()
		if warned or warning != "":
			var board_l := UiKit.lbl("Board: %s  ·  %s%s" % [GameState.board_state(), GameState.board_goal_text(),
					"  (final warning)" if warned else ""], UiKit.SMALL, UiKit.BAD)
			board_l.name = "BoardLine"
			cv.add_child(board_l)
			if warning != "":
				var warn_l := UiKit.lbl(warning, UiKit.SMALL, UiKit.BAD)
				warn_l.name = "BoardWarning"
				warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cv.add_child(warn_l)
		# What a sacking would mean, plainly (rule 60).
		if warned or warning != "":
			var rep := UiKit.lbl(ClubMoves.reprieve_line(GameState), UiKit.SMALL, UiKit.BAD)
			rep.name = "ReprieveLine"
			rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(rep)
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


## One of this week's decisions (usually one, two in a big week). Answer it
## here; unanswered when the round is played, it changes nothing - or costs
## what its hint says (data/stories, StoryEngine).
func _event_card(index: int) -> Control:
	return EventCardView.build(index, _narrow(), func(): _build(), _show_rule, _league_names())


## The exact rule behind a choice's line, looked up on purpose.
func _show_rule(text: String) -> void:
	if _rule_overlay != null and is_instance_valid(_rule_overlay):
		return
	var box := UiKit.modal_box(self, 460.0)
	_rule_overlay = box["overlay"]
	_rule_overlay.name = "RuleSheet"
	var v: VBoxContainer = box["body"]
	var l := UiKit.lbl(text, 15, UiKit.TEXT)
	l.name = "RuleText"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var ok := UiKit.btn("Close", UiKit.NAME, true)
	ok.name = "RuleClose"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(_close_rule)
	(box["footer"] as VBoxContainer).add_child(ok)


func _close_rule() -> void:
	if _rule_overlay != null and is_instance_valid(_rule_overlay):
		_rule_overlay.queue_free()
	_rule_overlay = null


func _sacked_card() -> Control:
	var card := UiKit.panel(UiKit.PANEL, 14)
	card.name = "SackedCard"
	var v := UiKit.vbox(8)
	card.add_child(v)
	var retired := ClubMoves.retired(GameState)
	var jobs := ClubMoves.offers(GameState)
	v.add_child(UiKit.lbl("You have retired" if retired else "You have been sacked", UiKit.TITLE, UiKit.TEXT if retired else UiKit.BAD, true))
	var club := GameDB.club_name(GameState.my_club)
	var why := "Two seasons short of the board's goals. Your time at %s is over." % club
	if retired:
		why = "Sacked by %s, you chose to retire from coaching." % club
	elif jobs.is_empty():
		why += " You had used your second chance. That's the end of your coaching career."
	var t := UiKit.lbl(why, UiKit.BODY, UiKit.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if not jobs.is_empty():
		_job_offers(v, jobs)
	else:
		v.add_child(UiKit.rule())
		_record(v)
	var review := _nav_button("Season review", func(): Router.go("season_review"))
	review.name = "SackedSeasonReview"
	v.add_child(review)
	# While he is choosing, the jobs are the main move, not the way out.
	var menu := _nav_button("Main menu", func(): Router.to_main_menu(), jobs.is_empty())
	menu.name = "SackedMainMenu"
	v.add_child(menu)
	return card


## The clubs with a job open after a sacking: facts only (where they
## finished, the list, the board's goal, why the job is open), each with its
## own button, in ladder order. Then what the next sacking would mean, and
## the way out: retire, with the record read out first.
func _job_offers(v: VBoxContainer, jobs: Array) -> void:
	var head := UiKit.lbl("Clubs with a job open", UiKit.H2, UiKit.TEXT, true)
	head.name = "JobOffersHead"
	v.add_child(head)
	for o in jobs:
		var code := str(o["code"])
		var row := UiKit.vbox(3)
		row.name = "JobOffer_%s" % code
		v.add_child(UiKit.rule())
		v.add_child(row)
		var name_row := UiKit.hbox(8)
		name_row.add_child(UiKit.club_marker(code))
		var nm := UiKit.lbl(str(o["name"]), UiKit.NAME, UiKit.club_vivid(code), true)
		# A wrapping label in a row takes no width of its own: it fills the row.
		nm.name = "JobOfferName_%s" % code
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_row.add_child(nm)
		row.add_child(name_row)
		row.add_child(_offer_line("Finished %s of %d. %s" % [GameState.ordinal(int(o["finish"])), int(o["clubs"]), str(o["why_open"])], UiKit.TEXT))
		if str(o.get("list", "")) != "":
			row.add_child(_offer_line("The list: " + str(o["list"]), UiKit.TEXT))
		row.add_child(_offer_line("The board's goal: " + str(o["goal"]), UiKit.TEXT))
		var take := _nav_button("Take the job", func():
			if ClubMoves.take_job(GameState, code):
				_build())
		take.name = "TakeJob_%s" % code
		row.add_child(take)
	v.add_child(UiKit.rule())
	var left := ClubMoves.reprieves(GameState) - 1
	var line := "Take a job and it is your last chance: sacked again and your coaching career is over. A premiership earns you another." \
			if left <= 0 else "Take a job and you still have a second chance left after it."
	var rl := UiKit.lbl(line, UiKit.SECONDARY, UiKit.BAD)
	rl.name = "ReprieveLine"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	var retire := _nav_button("Retire from coaching", _confirm_retire)
	retire.name = "RetireCoach"
	v.add_child(retire)


func _offer_line(text: String, colour: Color) -> Label:
	var l := UiKit.lbl(text, UiKit.SECONDARY, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Your coaching record, read out.
func _record(v: VBoxContainer) -> void:
	var rec := UiKit.vbox(3)
	rec.name = "CoachRecord"
	rec.add_child(UiKit.lbl("Your record", UiKit.H2, UiKit.TEXT, true))
	var lines := ClubMoves.record_lines(GameState)
	for i in range(lines.size()):
		var l := UiKit.lbl(lines[i], UiKit.BODY if i < 2 else UiKit.SECONDARY, UiKit.TEXT if i < 2 else UiKit.MUTED, i == 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rec.add_child(l)
	v.add_child(rec)


## Retiring ends the career for good: the record is read out before he says so.
func _confirm_retire() -> void:
	var box := UiKit.modal_box(self, 560.0)
	var overlay: Control = box["overlay"]
	overlay.name = "RetireSheet"
	var body: VBoxContainer = box["body"]
	var q := UiKit.lbl("Retire from coaching?", UiKit.H2, UiKit.TEXT, true)
	body.add_child(q)
	var warn := UiKit.lbl("Your coaching career ends here. You can still look back over it.", UiKit.SECONDARY, UiKit.MUTED)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(warn)
	_record(body)
	var row := UiKit.hbox(8)
	var no := _nav_button("Not yet", func(): overlay.queue_free())
	no.name = "RetireNotYet"
	var yes := _nav_button("Retire", func():
		ClubMoves.retire_coach(GameState)
		overlay.queue_free()
		_build(), true)
	yes.name = "RetireConfirm"
	row.add_child(no)
	row.add_child(yes)
	(box["footer"] as VBoxContainer).add_child(row)


## Every club's players by name, from the season's lists (they follow trades),
## so a name in a sentence wears his club's colour (NameInk). Built once per
## build of the hub; a name two clubs share is left plain.
func _league_names() -> Dictionary:
	if _name_index.is_empty() and GameState.season != null:
		_name_index = NameInk.from_lists(GameState.season.lists)
	return _name_index


## The league's front page in small: the lead story and a few headlines; a
## tap opens the whole page.
func _news_card() -> Control:
	return NewsFront.mini(GameState.news, GameState.my_club, _show_news, _league_names())


func _show_news() -> void:
	var wide := ScreenLayout.roomy(UiKit.view_width(self), UiKit.view_height(self))
	var box := UiKit.modal_box(self, 1080.0 if wide else 620.0, 0.0 if wide else 560.0)
	_news_overlay = box["overlay"]
	_news_overlay.name = "NewsFeed"
	NewsFront.fill(box["body"], GameState.news, GameState.my_club, wide, _league_names())
	var ok := UiKit.btn("Close", UiKit.NAME, true)
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
	var approaches := _approach_cards()
	if approaches != null:
		nv.add_child(approaches)
	var letter := _letter_card()
	if letter != null:
		nv.add_child(letter)
	if not GameState.pending_mro_challenges().is_empty():
		nv.add_child(_tribunal_card())
	var jobs_card := _week_jobs_card()
	if jobs_card != null:
		nv.add_child(jobs_card)
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
		# The forecast is known in the week (ARD-M4-016): a fact beside the
		# ground, not advice.
		var wx := str(mine.get("weather", ""))
		var where_text := "%s · %s" % ["Home" if is_home else "Away", ground]
		# Gather Round: neither club is at home; the round's name stands in.
		if str(mine.get("label", "")).ends_with(GatherRound.NAME):
			where_text = "%s · %s" % [GatherRound.NAME, ground]
		if wx != "":
			where_text += " · " + Weather.label(wx)
		# The week's hero: the match as a poster (director, 2026-10-08).
		var poster := MatchPoster.new().setup(GameState.my_club, opp, is_home, where_text, _narrow())
		if not _settled:
			UiKit.reveal(poster)
		nv.add_child(poster)
		nv.add_child(_match_way())
		var marquee := MarqueeGames.tradition(str(mine["home"]), str(mine["away"]))
		if not marquee.is_empty():
			var marquee_line := UiKit.lbl(str(marquee["name"]), UiKit.SMALL, UiKit.EMPH, true)
			marquee_line.name = "MarqueeContext"
			nv.add_child(marquee_line)
		# Sir Doug Nicholls Round (row 75): the name only,
		# in the round your club marks it (the factual line lives on the fixture
		# page, so the week's decision stays in view). A tribute, not a factor.
		if not GameState.season.is_regular_done() and SirDougRound.round_for(GameState,
				GameState.my_club) == GameState.season.round_index:
			var sd_name := UiKit.lbl(SirDougRound.NAME, UiKit.SMALL, UiKit.EMPH, true)
			sd_name.name = "SirDougContext"
			nv.add_child(sd_name)
		var rivalry :=GameState.rivalry_context(GameState.my_club, opp)
		if not rivalry.is_empty():
			var rivalry_line := UiKit.lbl(str(rivalry["title"]), UiKit.SMALL, UiKit.EMPH, true)
			rivalry_line.name = "RivalryContext"
			nv.add_child(rivalry_line)
			if str(rivalry.get("detail", "")) != "":
				var rivalry_detail := UiKit.lbl(str(rivalry["detail"]), UiKit.SMALL, UiKit.MUTED)
				rivalry_detail.name = "RivalryDetail"
				nv.add_child(rivalry_detail)
		var their := GameState.club_form_info(opp)
		# Named: under the poster an unnamed "4th on the ladder" read as yours.
		# "Form:" like your own line below, so the two read as parallel facts.
		# Before the opponent's first game the ladder and form say nothing yet:
		# last year's finish instead (nothing at all in a first season).
		var standing_text := ""
		if str(their["last"]) == "":
			var fin := GameState.last_finish_of(opp)
			if fin > 0:
				standing_text = "%s finished %s last year" % [GameDB.club_short(opp), GameState.ordinal(fin)]
		else:
			standing_text = "%s are %s on the ladder  ·  %s" % [
					GameDB.club_short(opp), GameState.ordinal(GameState.club_position(opp)),
					GameState.form_line(their)]
		if standing_text != "":
			var standing := UiKit.lbl(standing_text, UiKit.SECONDARY, UiKit.MUTED)
			standing.name = "OppFormLine"
			nv.add_child(standing)
		# Their list: the club's guernsey and name, then its line (TeamRating).
		var their_list := GameState.team_outlook(opp)
		if not their_list.is_empty():
			var row := UiKit.hbox(6)
			row.name = "OppTeamOutlookRow"
			var mark := UiKit.club_marker(opp, 18.0)
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mark)
			var tl := UiKit.lbl("%s  %s" % [GameDB.club_short(opp), str(their_list["line"])], UiKit.SECONDARY, UiKit.MUTED)
			tl.name = "OppTeamOutlook"
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(tl)
			nv.add_child(row)
		# The football: two or three facts, then anything on our side.
		var facts := GameState.opponent_facts(opp)
		var notes := GameState.my_week_notes()
		# The one who got away (P-16): a player who left you and lines up for
		# them, from what the club kept. Nothing when there is no one.
		var former := GameState.former_players(opp).slice(0, FormerPlayers.SHOWN)
		# Storylines before the bounce (T5.Q9): a man meeting a club he played
		# 100+ games for, after the one who got away, three lines at most.
		var told := {}
		for row in former:
			told[str(row["id"])] = true
		var old_club := GameState.old_club_lines(opp, told).slice(0, maxi(0, OldClubLines.MATCH_CAP - former.size()))
		if not facts.is_empty() or not notes.is_empty() or not former.is_empty() or not old_club.is_empty():
			nv.add_child(UiKit.spacer(4))
		# The first fact leads (the danger man, the thing to plan for); the
		# rest follow in body copy, so three lines are not three equals.
		# Every response the rules allow sits under the fact it answers (P-13): all
		# shown, in a fixed order, none marked best (FactOptions).
		var fact_options := GameState.opponent_fact_options(opp, facts)
		for i in range(facts.size()):
			var f: Dictionary = facts[i]
			var fl := NameInk.label(str(f["text"]), _league_names(), UiKit.NAME if i == 0 else UiKit.BODY, UiKit.TEXT, i == 0)
			fl.name = "Fact_%d" % i
			nv.add_child(fl)
			if i < fact_options.size() and not (fact_options[i] as Array).is_empty():
				var opt_row := FactOptionsRow.new().setup(i, fact_options[i], _narrow(),
						_on_fact_option.bind(str(f["text"])), str(f["text"]))
				nv.add_child(opt_row)
				FactOptionsRow.paint_chosen(opt_row, GameState.call_intent)
				nv.add_child(UiKit.spacer(2))
		for i in range(former.size()):
			var row: Dictionary = former[i]
			var gl := NameInk.label(FormerPlayers.poster_line(row, GameDB.player_display_name(row["p"]),
					GameDB.club_name(opp)), _league_names(), UiKit.BODY, UiKit.TEXT)
			gl.name = "FormerPlayer_%d" % i
			nv.add_child(gl)
		for i in range(old_club.size()):
			var row: Dictionary = old_club[i]
			var oc := NameInk.label(OldClubLines.line(row, GameDB.player_display_name(row["p"]),
					GameDB.club_name(str(row["old"]))), _league_names(), UiKit.BODY, UiKit.TEXT)
			oc.name = "OldClub_%d" % i
			nv.add_child(oc)
		for i in range(notes.size()):
			var nl := NameInk.label(str(notes[i]["text"]), _league_names(), UiKit.BODY,
					UiKit.BAD if str(notes[i].get("key", "")) == "own_injury" else UiKit.TEXT)
			nl.name = "OwnNote_%d" % i
			nv.add_child(nl)
	if not season.is_season_over():
		# Where the legs are at, one tap from the season line and the plan.
		var plan_line := SeasonPlanSheet.line(self, func(): _build())
		if plan_line != null:
			nv.add_child(UiKit.spacer(4))
			nv.add_child(plan_line)
		var ms_card := _milestone_card()
		if ms_card != null:
			nv.add_child(UiKit.spacer(4))
			nv.add_child(ms_card)
	# The week your season ends has its card, the Grand Final played or not.
	for i in range(GameState.week_events.size()):
		nv.add_child(UiKit.spacer(4))
		var ev := _event_card(i)
		nv.add_child(ev)
		# A question still waiting on the coach: it brightens twice, once.
		if not bool((GameState.week_events[i] as Dictionary).get("resolved", false)) and not _settled:
			UiKit.attention(ev)

	# On a wide screen the week's decisions are pinned under the page beside the
	# rest of the club (_build), so Play match is never below the fold; on a
	# phone they close the week's section.
	if _narrow():
		nv.add_child(UiKit.spacer(4))
		nv.add_child(_with_jobs_note(_week_actions(season)))
	return nv


## The week's milestones (Milestones.gd), always shown:
## a small card in the event-card style, or nothing. The note lines above
## keep their "plays his 100th" lines; the card leaves those out.
func _milestone_card() -> Control:
	if not Milestones.shown():
		return null
	var items := Milestones.card_items(GameState)
	if items.is_empty():
		return null
	var panel := UiKit.panel(UiKit.PANEL, 12)
	panel.name = "MilestoneCard"
	var v := UiKit.vbox(4)
	panel.add_child(v)
	v.add_child(UiKit.lbl("Milestones this week", UiKit.SMALL, UiKit.MUTED, true))
	for i in range(items.size()):
		var l := NameInk.label(str(items[i]["text"]), _league_names(), UiKit.BODY, UiKit.TEXT)
		l.name = "Milestone_%d" % i
		v.add_child(l)
	return panel


## The week's jobs (WeekChecklist; setting "weekly_checklist", off by
## default): the big call's slot first, then the routine jobs, each one tap
## from its screen and ticked when done. null when off or with no jobs.
func _week_jobs_card() -> Control:
	var items := WeekChecklist.items(GameState)
	var call := WeekChecklist.big_call(GameState)
	if items.is_empty() and call.is_empty():
		return null
	var panel := UiKit.panel(UiKit.PANEL, 12)
	panel.name = "WeekJobs"
	var v := UiKit.vbox(2)
	panel.add_child(v)
	var left := WeekChecklist.left(GameState)
	var head := UiKit.lbl("This week" if left == 0 else "This week  ·  %d to do" % left,
			UiKit.SECONDARY, UiKit.MUTED, true)
	head.name = "WeekJobsHead"
	v.add_child(head)
	# The big call's slot (WeekChecklist.big_call). Nothing shows without one.
	if not call.is_empty():
		var bc := _week_job_row(str(call.get("text", "")), bool(call.get("done", false)), str(call.get("route", "")), true)
		bc.name = "BigCall"
		v.add_child(bc)
	for it in items:
		var row := _week_job_row(str(it["text"]), bool(it["done"]), str(it["route"]))
		row.name = "WeekJob_%s" % str(it["key"])
		v.add_child(row)
	return panel


## One job: open ones in TEXT and a tap to their screen; done ones ticked
## in GOOD, the job itself MUTED. A job on this page itself is a plain line.
func _week_job_row(text: String, done: bool, route: String, big := false) -> Button:
	var b := UiKit.text_action("", UiKit.NAME if big else UiKit.BODY)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 44)
	var h := UiKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var mark := UiKit.lbl("Done" if done else "To do", UiKit.FINE, UiKit.GOOD if done else UiKit.MUTED, true)
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(48, 0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mark)
	var t := UiKit.ellipsis(text + ("  ›" if route != "" and not done else ""),
			UiKit.NAME if big else UiKit.BODY, UiKit.MUTED if done else UiKit.TEXT, big)
	t.name = "Text"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	b.tooltip_text = text
	if route != "":
		# A call answered here (press, approach) reloads the Hub in place so the
		# conference reopens, without stacking the Hub twice.
		b.pressed.connect(func():
			if route == Router.current():
				Router.replace(route)
			else:
				Router.go(route))
	else:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## The match row with a gentle "N jobs left" over it when the week's
## checklist has jobs open and Play match is there. Never a block.
func _with_jobs_note(row: Control) -> Control:
	var left := WeekChecklist.left(GameState)
	if left == 0 or row.find_child("PlayMatch", true, false) == null:
		return row
	var box := UiKit.vbox(2)
	box.name = "WeekActionsBox"
	box.size_flags_horizontal = row.size_flags_horizontal
	box.size_flags_vertical = row.size_flags_vertical
	box.size_flags_stretch_ratio = row.size_flags_stretch_ratio
	var note := UiKit.lbl("1 job left this week" if left == 1 else "%d jobs left this week" % left,
			UiKit.FINE, UiKit.MUTED)
	note.name = "JobsLeftNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(note)
	box.add_child(row)
	return box


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
		var line := NameInk.label("%s — %s. %s case: %s." % [
				name, sanction, hearing, str(row.get("case", "Difficult"))], _league_names(), 13, UiKit.TEXT, true)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.name = "TribunalLine"
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
			GameState.form_line(form).trim_suffix(last), UiKit.SECONDARY, _form_colour(float(form["value"])))
	head.name = "FormLine"
	row.add_child(head)
	var streak := UiKit.hbox(1)
	streak.name = "FormStreak"
	row.add_child(streak)
	for ch in last:
		var col := UiKit.GOOD if ch == "W" else (UiKit.BAD if ch == "L" else UiKit.MUTED)
		var l := UiKit.line(ch, UiKit.SECONDARY, col, true)
		l.name = "Result_%s" % ch
		streak.add_child(l)
	return row


func _form_colour(f: float) -> Color:
	if f >= 0.25:
		return UiKit.GOOD
	if f <= -0.25:
		return UiKit.BAD
	return UiKit.MUTED


## How you take the match (director, 2026-10-18, P-14): Watch it, Key moments
## (top speed, stopping for your calls, the goals and the breaks) or Skip
## straight to full time. The last one chosen comes up chosen; the main button
## takes the match that way and says so (_play_label).
func _match_way() -> Control:
	return UiKit.choice_grid("MatchWay", [["watch", "Watch"], ["key", "Key moments"], ["skip", "Skip"]],
			GameState.match_way(), 3, func(key: String) -> void:
				GameState.set_match_way(key)
				for b in find_children("PlayMatch", "Button", true, false):
					(b as Button).text = _play_label())


## The main button's words: Skip chosen says what the match screen's own
## control says; Watch and Key moments play the match. A response chosen under
## a fact opens the match on that call, so Skip gives way to it this once.
func _play_label() -> String:
	return "Skip to full time" if GameState.match_way() == "skip" and GameState.call_intent.is_empty() \
			else "Play match"


## The week's decision buttons: the primary action last, where the thumb is.
func _week_actions(season: Season) -> Control:
	var buttons: Array = []
	if season.is_season_over():
		var resume := GameState.draft != null and GameState.draft.intake_mode
		# A rival's letter is answered before the off-season opens: its two
		# buttons are the week's move until then.
		if not ClubMoves.letter_open(GameState):
			if not resume:
				buttons.append(_nav_button("Trades & Contracts", func(): Router.go("offseason")))
			buttons.append(_nav_button("Resume national draft" if resume
					else "%d National Draft" % GameState.season_year, _on_intake_draft, true))
	elif _regular_bye(season):
		# A home-and-away bye: the season goes on, one round at a time.
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		var bye := _nav_button("Play Round %d" % (season.round_index + 1), _on_sim_round_pressed, true)
		bye.name = "SimByeRound"
		buttons.append(bye)
	elif _upcoming_match().is_empty() and GameState.my_finals_status() == "bye":
		# Still alive: sim only this week, never past your own final.
		buttons.append(_nav_button("Team", func(): Router.go("selection")))
		var off := _nav_button(_finals_play_label(), _on_sim_round_pressed, true)
		off.name = "SimFinalsWeekOff"
		buttons.append(off)
	elif _upcoming_match().is_empty():
		# Out of the finals, the league still plays them week by week: each
		# week's results come up before the next.
		var week := _nav_button(_finals_play_label(), _on_sim_round_pressed, true)
		week.name = "SimFinalsWeek"
		buttons.append(week)
	else:
		buttons.append(_nav_button("Pick the side", func(): Router.go("selection")))
		var play := _nav_button(_play_label(), _on_play_pressed, true)
		play.name = "PlayMatch"
		buttons.append(play)
	var row := UiKit.hbox(8)
	row.name = "WeekActions"
	for b in buttons:
		row.add_child(b)
	return row


## Sim the week: the one quick sim, a single round.
func _sim_round_button() -> Button:
	var sim := _nav_button("Sim the week", _on_sim_round_pressed)
	sim.name = "SimRound"
	return sim


## A little air above a pinned bar and a soft fade over the clip edge, so scrolled
## content never reads as cut mid-button by the bar (phone and PC). Given the scroll
## it sits under, the fade says only that there is more: it thins as the end comes
## into view and is gone at the end, so it never hides the last real row (director,
## 2026-11-07: "the bottom row is faded by the UI effect").
func _bar_air(col: Color = UiKit.BG, sc: ScrollContainer = null) -> Control:
	var air := Control.new()
	air.custom_minimum_size = Vector2(0, 10)
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := TextureRect.new()
	fade.name = "BarFade"
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 28
	fade.texture = gt
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_left = 0.0
	fade.anchor_right = 1.0
	fade.anchor_top = 0.0
	fade.anchor_bottom = 0.0
	fade.offset_top = -28
	fade.offset_bottom = 0
	air.add_child(fade)
	if sc != null:
		_fade_follows(fade, sc)
	return air


## The fade's strength follows what is left below: full while more than its own
## height is hidden, nothing at the scroll's end (or when nothing scrolls).
func _fade_follows(fade: Control, sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	var follow := func() -> void:
		if not is_instance_valid(fade) or not is_instance_valid(bar):
			return
		var left := bar.max_value - bar.page - bar.value
		var span := maxf(1.0, fade.size.y if fade.size.y > 0.0 else 28.0)
		fade.modulate.a = clampf(left / span, 0.0, 1.0)
	bar.value_changed.connect(follow.unbind(1))
	bar.changed.connect(follow)
	sc.resized.connect(follow)
	fade.resized.connect(follow)
	follow.call()


## Everything else, one quiet row pinned under the page.
func _footer(season: Season, with_sim := true) -> Control:
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
		if with_sim and not _upcoming_match().is_empty():
			buttons.append(_sim_round_button())
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
		# Each button is at least as wide as its own label, so the row's spare
		# width is shared out beyond that and none is cut short ("Sim the we...").
		var sb_n: StyleBox = b.get_theme_stylebox("normal")
		var pad := sb_n.get_margin(SIDE_LEFT) + sb_n.get_margin(SIDE_RIGHT) if sb_n != null else 16.0
		var font: Font = b.get_theme_font("font")
		var fs: int = b.get_theme_font_size("font_size")
		b.custom_minimum_size.x = ceilf(font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad) + 1.0
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


## Rival clubs after your coaches (found when the home-and-away season
## ends): who, for what job, and your answer - the senior assistant's job, a
## request to stay, or your blessing. Answered ones stay as a line until the
## off-season settles them.
func _approach_cards() -> Control:
	if GameState.coach_approaches.is_empty():
		return null
	var v := UiKit.vbox(6)
	v.name = "CoachApproaches"
	for i in range(GameState.coach_approaches.size()):
		var a: Dictionary = GameState.coach_approaches[i]
		var c: Dictionary = GameState.coaches.get(str(a["cid"]), {})
		var who := CoachMarket._name(c) if not c.is_empty() else "Your coach"
		if str(a.get("choice", "")) != "":
			var done := UiKit.lbl(str(a["text"]), UiKit.BODY, UiKit.MUTED)
			done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(done)
			continue
		var card := UiKit.vbox(4)
		card.name = "Approach_%d" % i
		card.add_child(UiKit.lbl("%s want %s" % [GameDB.club_name(str(a["club"])), who], UiKit.NAME, UiKit.TEXT, true))
		var why := UiKit.lbl("Your %s. They have offered him the %s job." % [
				CoachMarket._job_word(str(a["from_job"])), CoachMarket._job_word(str(a["job"]))], UiKit.BODY, UiKit.MUTED)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(why)
		var row := UiKit.hbox(8)
		var block := GameState.approach_promote_block(i)
		if block == "":
			row.add_child(_approach_button(i, "promote", "Offer senior assistant", true))
		row.add_child(_approach_button(i, "stay", "Ask him to stay"))
		row.add_child(_approach_button(i, "go", "Let him go"))
		card.add_child(row)
		v.add_child(card)
	v.add_child(UiKit.rule())
	return v


## A rival board's letter after a strong season (T5.r23): who they are, where
## they finished, why the job is open, their list, their board's goal and the
## risk, then his answer. Facts only; neither button is the suggested one.
## Answered, one line says where he stands until the season rolls on.
func _letter_card() -> Control:
	var l := ClubMoves.letter(GameState)
	if l.is_empty() or not GameState.season.is_season_over():
		return null
	var code := str(l["code"])
	var mine := GameDB.club_name(GameState.my_club)
	var v := UiKit.vbox(4)
	v.name = "RivalLetter"
	var answer := str(l.get("answer", ""))
	if answer != "":
		var old := GameDB.club_name(str(l["from"]))
		var after := ("%s coaches %s now." % [str(l["successor"]), old]) if str(l.get("successor", "")) != "" \
				else "%s carries on under a new coach." % old
		var done := "You are %s's senior coach now: their contracts, trades and draft are yours this off-season. %s" % [
				str(l["name"]), after] if answer == "taken" \
				else "You turned %s down. You stay at %s." % [str(l["name"]), mine]
		var dl := UiKit.lbl(done, UiKit.BODY, UiKit.TEXT if answer == "taken" else UiKit.MUTED)
		dl.name = "RivalLetterAnswered"
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		v.add_child(UiKit.rule())
		return v
	var name_row := UiKit.hbox(8)
	name_row.add_child(UiKit.club_marker(code))
	var nm := UiKit.lbl("A letter from %s" % str(l["name"]), UiKit.NAME, UiKit.club_vivid(code), true)
	nm.name = "RivalLetterHead"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(nm)
	v.add_child(name_row)
	v.add_child(_offer_line("%s, their president, offers you the senior job. You would start now, with their contracts, trades and draft." % str(l["president"]), UiKit.TEXT))
	v.add_child(_offer_line("Finished %s of %d. %s" % [GameState.ordinal(int(l["finish"])), int(l["clubs"]), str(l["why_open"])], UiKit.TEXT))
	if str(l.get("list", "")) != "":
		v.add_child(_offer_line("Their list: " + str(l["list"]), UiKit.TEXT))
	v.add_child(_offer_line("Their board's goal: " + str(l["goal"]), UiKit.TEXT))
	var risk_head := UiKit.lbl("The risk", UiKit.SECONDARY, UiKit.TEXT, true)
	risk_head.name = "RivalLetterRisk"
	v.add_child(risk_head)
	for line in ClubMoves.letter_risk(GameState):
		v.add_child(_offer_line(line, UiKit.TEXT))
	var row := UiKit.hbox(8)
	var stay := _nav_button("Stay put", func():
		if ClubMoves.decline_letter(GameState):
			_build())
	stay.name = "RivalLetterStay"
	var take := _nav_button("Take the job", func():
		if ClubMoves.accept_letter(GameState):
			_build())
	take.name = "RivalLetterTake"
	row.add_child(stay)
	row.add_child(take)
	v.add_child(row)
	v.add_child(UiKit.rule())
	return v


func _approach_button(i: int, choice: String, text: String, primary := false) -> Button:
	var b := UiKit.btn(text, UiKit.SMALL + 1, primary)
	b.name = "Approach_%d_%s" % [i, choice]
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func():
		GameState.answer_approach(i, choice)
		_build())
	return b


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


## The button that plays the week: short enough for half a phone's width beside Team
## ("Play Wildcard Round" ran off the edge at 390).
func _finals_play_label() -> String:
	var w := int(GameState.season.finals.get("week", 1))
	return ["Play the wildcard", "Play the finals", "Play semi finals",
			"Play the prelims", "Play Grand Final"][clampi(w - 1, 0, 4)]


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
## While the hub sits idle, paint what the banner scene will need on its first frame
## (the crowd), so Play match doesn't freeze for it. Looks the same; nothing is drawn.
func _warm_pre_match() -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree() or not GameState.vignettes_on():
		return
	var m := _upcoming_match()
	if m.is_empty():
		return
	var mine := GameState.my_club
	PreMatchVignette.warm(mine, str(m["away"]) if str(m["home"]) == mine else str(m["home"]))


func _upcoming_match() -> Dictionary:
	return MatchKickoff.upcoming_match()


func _ladder_grid(_limit: int) -> Control:
	return UiKit.ladder_table(GameState.season.ladder_sorted(), GameState.my_club,
			_content_width() - 24.0, 8, false)


# ---------------------------------------------------------------------------
# Round control
# ---------------------------------------------------------------------------
## Play match: the match preview first, its own step before the setup (director,
## 2026-11-07: "It deserves its own place in the pre game flow"); its Continue
## starts the match. Skip to full time has no setup to read for, so it starts here.
func _on_play_pressed() -> void:
	if MatchKickoff.busy or _upcoming_match().is_empty() \
			or (GameState.match_way() == "skip" and GameState.call_intent.is_empty()):
		_on_play_match()
		return
	Router.go("preview")


## Start the match now (MatchKickoff): the pre-match scene, then the match-day setup.
func _on_play_match() -> void:
	if not await MatchKickoff.start(get_tree()):
		_on_sim_round()


## A response beside an opposition fact was tapped (P-13): it is chosen and
## shown chosen, or let go again when it already was. It never starts the
## match: Play match does, and the pre-bounce pane then opens on that call with
## the fact above it. Nothing is saved.
func _on_fact_option(option: Dictionary, fact_text: String) -> void:
	if MatchKickoff.busy:
		return
	var intent := {"call": str(option["call"]), "plan": str(option["plan"]),
			"player_id": str(option["player_id"]), "fact": fact_text}
	var again := str(GameState.call_intent.get("fact", "")) == fact_text \
			and FactOptionsRow.is_chosen(option, GameState.call_intent)
	GameState.call_intent = {} if again else intent
	FactOptionsRow.paint_chosen(self, GameState.call_intent)
	for b in find_children("PlayMatch", "Button", true, false):
		(b as Button).text = _play_label()


## Every button that sims the week comes here. "Ask before simming" asks only
## when the sim would play a match you could have played yourself: your
## home-and-away round or your final (row 102). A bye, a finals week off, a
## finals week you are out of and the off-season sim nothing of yours, so they
## go straight ahead. The pre-season's Sim to Round 1 (PreSeasonScene) asks
## too, because it plays the practice match, and follows the same setting.
## Settings turns the question back on after Don't ask again.
func _sim_asks_first() -> bool:
	return GameState.confirm_sim_round() and not _upcoming_match().is_empty()


func _on_sim_round_pressed() -> void:
	var m := _upcoming_match()
	if not _sim_asks_first():
		_on_sim_round()
		return
	var box := UiKit.modal_box(self, 420.0, 290.0)
	_sim_confirm = box["overlay"]
	_sim_confirm.name = "SimConfirm"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Sim %s?" % str(m["label"]), UiKit.H1))
	var why := UiKit.lbl("Your match will be played out without you.", UiKit.BODY, UiKit.TEXT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var go := UiKit.btn("Sim the week", UiKit.NAME, true)
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


func _on_sim_round() -> void:
	# The week's sim takes seconds on a phone: the cover and its line are on
	# screen first, and a second tap meanwhile is ignored (ScreenTransition).
	ScreenTransition.run(_sim_line(), _sim_week)


func _sim_week() -> void:
	GameState.advance()
	_build()
	if not GameState.last_results.is_empty():
		_show_results(GameState.last_results)


## What the cover says while the week is simmed.
func _sim_line() -> String:
	var season: Season = GameState.season
	if season == null or season.is_season_over():
		return "Simming the week..."
	if not season.is_regular_done():
		return "Playing %s..." % season.round_label(season.round_index)
	var w := int(season.finals.get("week", 1))
	return ["Playing the wildcard round...", "Playing the first week of the finals...", "Playing the semi finals...",
			"Playing the prelims...", "Playing the Grand Final..."][clampi(w - 1, 0, 4)]


## Router back hook: close the results popup before leaving the hub.
## The finals series, wildcard to the Grand Final (FinalsBracket).
func _show_finals() -> void:
	if _finals_overlay != null and is_instance_valid(_finals_overlay):
		return
	var box := UiKit.modal_box(self, 1100.0, 0.0)
	_finals_overlay = box["overlay"]
	_finals_overlay.name = "FinalsSheet"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Finals series", UiKit.TITLE))
	v.add_child(FinalsBracket.new().setup(GameState.season, GameState.my_club))
	var done := UiKit.btn("Done", UiKit.NAME)
	done.name = "FinalsDone"
	done.pressed.connect(_close_finals)
	(box["footer"] as VBoxContainer).add_child(done)


func _close_finals() -> void:
	if _finals_overlay != null and is_instance_valid(_finals_overlay):
		_finals_overlay.queue_free()
	_finals_overlay = null


func handle_back() -> bool:
	if MatchKickoff.busy:
		return true     # the side is on its way out
	if TrainingReportSheet.close_top(self):
		return true
	var plan_sheet := get_node_or_null("SeasonPlanSheet")
	if plan_sheet != null and is_instance_valid(plan_sheet) and not plan_sheet.is_queued_for_deletion():
		plan_sheet.queue_free()
		_build()
		return true
	if _finals_overlay != null and is_instance_valid(_finals_overlay):
		_close_finals()
		return true
	if _onboarding_overlay != null and is_instance_valid(_onboarding_overlay):
		_close_weekly_loop_intro()
		return true
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
		_settings = null
		return true
	if _sim_confirm != null and is_instance_valid(_sim_confirm):
		_close_sim_confirm()
		return true
	if _rule_overlay != null and is_instance_valid(_rule_overlay):
		_close_rule()
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
	if _talk_overlay != null and is_instance_valid(_talk_overlay):
		_close_backing_talk()
		return true
	if _midseason_overlay != null and is_instance_valid(_midseason_overlay):
		_close_midseason(true)
		return true
	if RookieDraftSheet.close_open(self):
		return true
	if DraftSpotsSheet.close_open(self):
		return true
	# Back skips the press conference, as its Skip button does (natural
	# Android Back); an overlay opened over it closes first.
	if _media_overlay != null and is_instance_valid(_media_overlay) and _media_overlay is PressScene:
		return (_media_overlay as PressScene).handle_back()
	return false



## The sit-down when a run you promised ends (Backing.talk): what he did with
## it and how he took it, reported. Nothing to decide; Done closes it.
func _show_backing_talk() -> void:
	if not GameState.backing_talk_pending():
		return
	if _talk_overlay != null and is_instance_valid(_talk_overlay):
		return
	var t: Dictionary = GameState.backing_talk
	var box := UiKit.modal_box(self, 520.0, 0.0)
	_talk_overlay = box["overlay"]
	_talk_overlay.name = "BackingTalk"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading(str(t.get("title", "")), UiKit.TITLE))
	var i := 0
	for line in t.get("lines", []):
		var l := UiKit.lbl(str(line), 15, UiKit.TEXT)
		l.name = "BackingTalkLine_%d" % i
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		i += 1
	var ok := UiKit.btn("Done", UiKit.NAME, true)
	ok.name = "BackingTalkDone"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(_close_backing_talk)
	(box["footer"] as VBoxContainer).add_child(ok)


## Under-18 carnival week (row 54): three who starred, by position and
## state, no grades. Words only; Done closes it for the season.
func _show_carnival() -> void:
	if _midseason_overlay != null and is_instance_valid(_midseason_overlay):
		return
	var box := UiKit.modal_box(self, 520.0, 0.0)
	_midseason_overlay = box["overlay"]
	_midseason_overlay.name = "CarnivalWeek"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Under-18 championships", UiKit.TITLE))
	var intro := UiKit.lbl("Three from this year's draft class who starred at the carnival:", 15, UiKit.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	var i := 0
	for line in MidseasonDraft.carnival_lines(GameState):
		var l := UiKit.lbl(str(line), 15, UiKit.TEXT, true)
		l.name = "CarnivalLine_%d" % i
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		i += 1
	var ok := UiKit.btn("Done", UiKit.NAME, true)
	ok.name = "CarnivalDone"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(_close_midseason.bind(true))
	(box["footer"] as VBoxContainer).add_child(ok)


## Mid-season rookie draft, your turn: the best eight left, Pick or Pass.
## Sim the week passes an unmade pick.
const MIDSEASON_SHOWN := 8

func _show_midseason_pick() -> void:
	if _midseason_overlay != null and is_instance_valid(_midseason_overlay):
		return
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_midseason_overlay = box["overlay"]
	_midseason_overlay.name = "MidseasonDraft"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Mid-season rookie draft", UiKit.TITLE))
	var note := UiKit.lbl("Your pick: whoever you take signs a rookie deal to the end of next season. Sim the week without picking passes it.", 15, UiKit.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var shown := MidseasonDraft.pool(GameState).slice(0, MIDSEASON_SHOWN)
	for p in shown:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var txt := UiKit.lbl("%s  %d
%s, %d, %s" % [GameDB.player_display_name(p), int(p.get("overall", 0)),
				DraftNight.position_words(p), int(p.get("age", 0)), MidseasonDraft.from_word(GameState, p)], 14, UiKit.TEXT)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(txt)
		var pick := UiKit.btn("Pick", UiKit.NAME)
		pick.name = "MidseasonPick_%s" % str(p["id"])
		pick.custom_minimum_size = Vector2(88, 48)
		# Your challenge bars him: said on the button and in a line under
		# him, never only on hover (a phone has none).
		var barred := Challenge.block_reason(GameState, p)
		if barred != "":
			pick.text = Challenge.short_tag(GameState, p)
			pick.disabled = true
		pick.pressed.connect(_midseason_choose.bind(str(p["id"])))
		row.add_child(pick)
		v.add_child(row)
		if barred != "":
			var why := UiKit.lbl(barred, UiKit.SMALL, UiKit.MUTED)
			why.name = "ChallengeWhy_%s" % str(p["id"])
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(why)
	var pass_btn := UiKit.btn("Pass", UiKit.NAME, true)
	pass_btn.name = "MidseasonPass"
	pass_btn.custom_minimum_size = Vector2(0, 48)
	pass_btn.pressed.connect(_midseason_choose.bind(""))
	(box["footer"] as VBoxContainer).add_child(pass_btn)


func _midseason_choose(player_id: String) -> void:
	MidseasonDraft.choose(GameState, player_id)
	GameState.autosave()
	_close_midseason(false)


## Closing the carnival marks it seen; closing the draft sheet with Back
## leaves the pick open (Sim the week passes it).
func _close_midseason(_back: bool) -> void:
	if _midseason_overlay != null and is_instance_valid(_midseason_overlay):
		if _midseason_overlay.name == "CarnivalWeek":
			MidseasonDraft.close_carnival(GameState)
		_midseason_overlay.queue_free()
	_midseason_overlay = null
	_build()


func _close_backing_talk() -> void:
	GameState.close_backing_talk()
	if _talk_overlay != null and is_instance_valid(_talk_overlay):
		_talk_overlay.queue_free()
	_talk_overlay = null
	_build()


## The press conference is its own full screen (ruling 3.52; director
## 2026-11-06, Q4): the hub hands over to PressScene, which shows the result in
## the room and comes back here. A hub built by hand (not the running scene)
## lays the same screen over itself.
func _show_media_conference() -> void:
	if not GameState.media_conference_pending():
		return
	if _media_overlay != null and is_instance_valid(_media_overlay):
		return
	if is_inside_tree() and get_tree().current_scene == self:
		_media_overlay = self
		Router.go.call_deferred("press")
		return
	var press := PressScene.embed(self)
	_media_overlay = press
	press.closed.connect(func():
		_media_overlay = null
		_build())

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
		var review := UiKit.btn("Review match", UiKit.NAME)
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
	var medal := {}
	for r in results:
		if medal.is_empty():
			medal = GameState.norm_smith_for(r)
	if not medal.is_empty():
		var ml := UiKit.lbl(str(medal["text"]), UiKit.BODY, UiKit.TEXT, true)
		ml.name = "NormSmithMedal"
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ml)
	if not others.is_empty():
		v.add_child(UiKit.spacer(UiKit.GAP))
		v.add_child(UiKit.lbl("Other results" if others.size() < results.size() else "Results",
				UiKit.SMALL, UiKit.MUTED, true))
		v.add_child(_results_list(others))

	var ok := UiKit.btn("Continue", UiKit.NAME, true)
	ok.name = "ResultsContinue"
	ok.pressed.connect(func():
		overlay.queue_free()
		_results_overlay = null
		_build()
		_show_week_ask())
	# The list scrolls under Continue: air and a soft edge so a row is never sliced by the button.
	if not others.is_empty():
		var air := _bar_air(UiKit.PANEL, (box["body"] as Control).get_parent() as ScrollContainer)
		# The fade ends exactly on the scroll's clip edge (8 px above the footer) and is fully
		# solid there, so a row is eased out, never sliced.
		var edge: TextureRect = air.get_node("BarFade")
		edge.offset_top = -48
		edge.offset_bottom = -8
		(edge.texture as GradientTexture2D).height = 48
		(edge.texture as GradientTexture2D).gradient.set_color(1, UiKit.PANEL)
		box["footer"].add_child(air)
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
	# A win lands by scale alone (all text is solid from frame 0, the
	# scores are true at once); a loss and a draw are only shown, sober.
	if won and not drew:
		UiKit.land(verdict, 0.12)
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
	var turned := ComebackTelling.turn_line(res, me)
	# The turn sentence says the comeback or the lost lead in full, so the headline that states
	# the same ("From 29 points down at quarter time.", "Led by 37 at half-time.") is dropped.
	if turned != "" and (line.begins_with("From ") or line.begins_with("Led by ")):
		line = ""
	if line != "":
		var hl := UiKit.lbl(line, UiKit.BODY, UiKit.MUTED)
		hl.name = "MyHeadline"
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hl)
	# The quarter that turned a comeback win or a lost lead, and who did it.
	if turned != "":
		var tl := UiKit.lbl(turned, UiKit.BODY, UiKit.MUTED)
		tl.name = "MyTurn"
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)
	var best := MatchNotes.standouts(res, me, 1)
	if not best.is_empty():
		var bl := UiKit.lbl("Best: %s %s  ·  %s" % [str(best[0]["name"]),
				MatchNotes.rating_text(float(best[0]["rating"])), str(best[0]["line"])],
				UiKit.SMALL, UiKit.TEXT)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.name = "MyBest"
		v.add_child(bl)
	var hurt := GameState.my_new_injuries()
	if not hurt.is_empty():
		var inj := UiKit.lbl("Injured: " + ", ".join(hurt), UiKit.SMALL, UiKit.BAD, true)
		inj.name = "MyInjured"
		inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(inj)
	var mro := GameState.my_mro_lines()
	if not mro.is_empty():
		var mr := UiKit.lbl("MRO: " + ", ".join(mro), UiKit.SMALL, UiKit.BAD, true)
		mr.name = "MyMRO"
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


## The rest of the round (director, 2026-11-07: "really hard to read and know which game
## they belong to"). Each game is one unit, a rule between games; the winner's code and
## score in full ink, the loser's muted, a draw both alike. Your game comes first, edged
## in your club's colour. The score sits right after the club code, not across the row.
func _results_list(results: Array) -> Control:
	var v := UiKit.vbox(UiKit.GAP)
	v.name = "ResultsList"
	var narrow := _content_width() < 520.0
	var ordered: Array = []
	for res in results:
		if GameState.is_my_match(res):
			ordered.append(res)
	for res in results:
		if not GameState.is_my_match(res):
			ordered.append(res)
	for i in range(ordered.size()):
		var res: Dictionary = ordered[i]
		if i > 0:
			v.add_child(UiKit.rule())
		var mine: bool = GameState.is_my_match(res)
		var s: Array = res["score"]
		var drew: bool = int(s[0]) == int(s[1])
		var verdict := ""
		var vcol := UiKit.MUTED
		if mine:
			var me := 0 if str(res["home"]) == GameState.my_club else 1
			var won: bool = int(s[me]) > int(s[1 - me])
			verdict = "Draw" if drew else ("Won" if won else "Lost")
			vcol = UiKit.MUTED if drew else UiKit.margin_colour(won)
		var sides: BoxContainer = UiKit.vbox(2) if narrow else UiKit.hbox(8)
		sides.name = "Sides"
		for side in [0, 1]:
			var code := str(res["home"] if side == 0 else res["away"])
			var role := "draw" if drew else ("win" if int(s[side]) > int(s[1 - side]) else "lose")
			var row := _result_side(code, int(res["goals"][side]), int(res["behinds"][side]), role,
					verdict if mine and code == GameState.my_club else "", vcol, narrow or side == 0)
			if not narrow and side == 1:
				# "v", not "def": the home side is listed first, not the winner.
				sides.add_child(UiKit.line("v", UiKit.SMALL, UiKit.MUTED))
			sides.add_child(row)
		# Every game keeps the edge's room, so the columns line up; only yours is inked.
		var game := HBoxContainer.new()
		game.name = "ResultGame_%d" % i
		game.add_theme_constant_override("separation", 8)
		game.set_meta("mine", mine)
		var edge := ColorRect.new()
		edge.name = "ClubBar"
		edge.color = UiKit.club_ink(GameState.my_club) if mine else Color(0, 0, 0, 0)
		edge.custom_minimum_size = Vector2(3, 0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.add_child(edge)
		sides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game.add_child(sides)
		v.add_child(game)
	return v


## One club's line of a result: guernsey, code, score right after it, and (your
## game only) the verdict. `role` is win, lose or draw: the winner in full ink and
## bold, the loser muted, a draw both in full ink and neither bold.
func _result_side(code: String, goals: int, behinds: int, role: String, verdict: String,
		vcol: Color, code_first := true) -> Control:
	var ink := UiKit.MUTED if role == "lose" else UiKit.TEXT
	var h := UiKit.hbox(8)
	h.name = "ResultRow_%s" % code
	h.set_meta("result", role)
	var marker := UiKit.club_marker(code)
	var code_l := UiKit.line(code, UiKit.NAME, ink, role == "win")
	code_l.name = "Code"
	code_l.custom_minimum_size = Vector2(46, 0)
	var score := UiKit.line(UiKit.scoreline(goals, behinds), UiKit.NAME, ink, role == "win")
	score.name = "Score"
	score.custom_minimum_size = Vector2(88, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if code_first:
		h.add_child(marker)
		h.add_child(code_l)
		h.add_child(score)
	else:
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		h.add_child(score)
		code_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(code_l)
		h.add_child(marker)
	if verdict != "":
		var tag := UiKit.line(verdict, UiKit.SECONDARY, vcol, true)
		tag.name = "Verdict"
		h.add_child(tag)
	return h


## The draft button: when a pick of yours has no senior list spot, the sheet
## says so first (DraftSpotsSheet); otherwise the draft starts.
func _on_intake_draft() -> void:
	if GameState.is_sacked():
		_build()
		return
	if DraftSpotsSheet.needed():
		DraftSpotsSheet.open(self, _start_intake_draft)
		return
	_start_intake_draft()


func _start_intake_draft() -> void:
	# The rollover takes a couple of seconds on a phone: the cover and its
	# line go up first. The draft screen, when there is one, joins the cover.
	ScreenTransition.run("Starting the new season...", func():
		if GameState.begin_intake_draft():
			Router.go("draft")
			return
		if GameState.start_next_season():
			_build())
