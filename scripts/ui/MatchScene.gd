extends Control
## Live match view: scoreboard, the animated oval, a commentary feed and
## playback controls. Your own match (home-and-away or final) is simulated a
## quarter at a time around the coach box; any other result is a replay of
## the event log GameState.advance() recorded.

const FEED_LIMIT := 60
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
## Routine play drives the animation but would drown the feed; the feed
## keeps what MatchNotes.FEED_KINDS names (goals, behinds, breaks, calls).
const QUIET_KINDS := ["kick", "handball", "sub", "ballup", "mark", "tackle", "pressure", "inside50",
		"rebound", "clanger", "free"]
## A run of goals worth a line in the feed.
const RUN_LINE := 3
## MatchSim's minutes per quarter (it stamps Q2 from 31, Q3 from 61...).
const QUARTER_MINUTES := 30

var _res := {}
var _pitch: PitchView
var _root: VBoxContainer
var _score_home: Label
var _score_away: Label
var _clock: Label
var _feed: VBoxContainer
var _feed_scroll: ScrollContainer
var _play_btn: Button
var _speed_btns: Array = []
var _finished := false
var _side_panel: Control
var _body: BoxContainer
var _interactive := false
## Reviewing a match already played (Sim round, or Review last match): straight
## to full time, nothing played or applied again.
var _review := false
var _event_cursor := 0
var _my_side := 0
var _margin: MarginContainer
var _stacked := false
var _last_tactics := {}
var _skipping := false
var _fulltime_shown := false
var _coach_overlay: Control
var _sheet_overlay: Control
var _reflow_queued := false
var _shown_goals := [0, 0]
var _shown_behinds := [0, 0]
var _shown_q := 1
var _shown_min := 0
var _moment_overlay: Control
var _momentum := 0.0            # the engine's momentum as shown: -1 (away on top) .. 1 (home on top)
var _mom_home: ColorRect
var _mom_away: ColorRect
var _rotation := "normal"
var _pos_before := 0          # your ladder spot before this match
var _lead: Label
var _setup_line: Label
var _report_overlay: Control
var _ft_box := {}               # the full-time review: overlay, body, footer
var _ft_tabs: HBoxContainer
var _ft_tab := "summary"        # summary (home), stats or report
var _run_side := -1            # who kicked the last goal, and how many in a row
var _run_len := 0
var _duel_mem := {}             # the feed's memory of the key match-ups (MatchNotes.duel_feed_line)
var _matchup_overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_interactive = GameState.pending_sim != null and not GameState.pending_match.is_empty()
	if _interactive:
		_res = GameState.pending_sim.result()
		_res["home"] = GameState.pending_match["home"]
		_res["away"] = GameState.pending_match["away"]
		_res["label"] = GameState.pending_match["label"]
		_res["venue"] = str(GameState.pending_match.get("venue", ""))
		_res["events"] = []
		_my_side = 0 if str(_res["home"]) == GameState.my_club else 1
		_pos_before = GameState.my_position()
	else:
		_res = GameState.last_match
		_review = GameState.review_requested
		GameState.review_requested = false
		if not _res.is_empty() and GameState.my_club != "":
			_my_side = 0 if str(_res.get("home", "")) == GameState.my_club else 1
		_pos_before = GameState.last_pos_before
	if _res.is_empty():
		Router.replace("hub")
		return
	_build()
	_pitch.setup(_res)
	_pitch.event_played.connect(_on_event)
	_pitch.finished.connect(_on_finished)
	_update_scoreboard({"q": 1, "min": 0, "score": [0, 0], "kind": "info"})
	if _interactive:
		_show_coach_box()
	elif _review:
		_on_finished()
	else:
		# Give the eye a beat to find the oval before the bounce.
		get_tree().create_timer(0.55).timeout.connect(func():
			if not _finished:
				_pitch.play()
				_sync_controls())


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(_margin, 10)
	add_child(_margin)

	_root = UiKit.vbox(8)
	_margin.add_child(_root)

	_root.add_child(_scoreboard())
	_mount_body(UiKit.view_width(self) < 640.0)
	_root.add_child(_body)


func _mount_body(stack: bool) -> void:
	# Stack the feed under the oval on a narrow phone. Landscape keeps the
	# oval beside the feed, and the pitch itself is never rebuilt.
	_stacked = stack
	if stack:
		_body = UiKit.vbox(8)
	else:
		_body = HBoxContainer.new()
		_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _pitch == null:
		_pitch = PitchView.new()
		_pitch.speed = GameState.match_speed()
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The feed is a handful of lines (scores, breaks, calls): on a phone the
	# oval gets the height.
	_pitch.size_flags_stretch_ratio = 2.2 if stack else 1.5
	_body.add_child(_pitch)

	if _side_panel == null:
		_side_panel = UiKit.panel(UiKit.PANEL, 10)
		var sv := UiKit.vbox(6)
		_side_panel.add_child(sv)
		# Your match: the calls you have on, so the setup is never a guess.
		_setup_line = UiKit.ellipsis("", UiKit.SMALL, UiKit.MUTED)
		_setup_line.name = "SetupLine"
		_setup_line.visible = false
		sv.add_child(_setup_line)
		_feed = UiKit.vbox(4)
		_feed.name = "Feed"
		_feed_scroll = UiKit.scroll(_feed)
		sv.add_child(_feed_scroll)
		sv.add_child(_controls())
	_fit_side_panel()
	_body.add_child(_side_panel)


func _fit_side_panel() -> void:
	if _side_panel == null:
		return
	if _stacked:
		var short := UiKit.view_height(self) < 520.0
		_side_panel.custom_minimum_size = Vector2(0, 120 if short else 168)
		_side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side_panel.size_flags_stretch_ratio = 1.0
	else:
		_side_panel.custom_minimum_size = Vector2(220, 0)
		_side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side_panel.size_flags_stretch_ratio = 0.7
	_side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Names sit above the score, not beside it. A wrapping label in a tight hbox
## collapses to one character per line and pushes the oval off the phone.
func _scoreboard() -> Control:
	var narrow := UiKit.view_width(self) < 640.0
	var p := UiKit.panel(UiKit.PANEL, 8)
	var v := UiKit.vbox(4)
	p.add_child(v)
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(_score_column(str(_res["home"]), true, narrow))
	h.add_child(_score_middle(narrow))
	h.add_child(_score_column(str(_res["away"]), false, narrow))
	v.add_child(_momentum_bar())
	return p


## Who has the run of play: the engine's momentum (MatchSim.momentum), which
## goals swing, time fades and a goal the other way turns. The side it
## favours wins a little more of the ball at stoppages and loose balls.
func _momentum_bar() -> Control:
	var bar := UiKit.hbox(0)
	bar.name = "MomentumBar"
	bar.custom_minimum_size = Vector2(0, 6)
	bar.tooltip_text = "Momentum"
	_mom_home = ColorRect.new()
	_mom_away = ColorRect.new()
	_mom_home.color = (GameDB.club_colours(str(_res["home"])) as Array)[0]
	_mom_away.color = (GameDB.club_colours(str(_res["away"])) as Array)[0]
	for r in [_mom_home, _mom_away]:
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 6)
		bar.add_child(r)
	_paint_momentum()
	return bar


func _paint_momentum() -> void:
	if _mom_home == null or not is_instance_valid(_mom_home):
		return
	# Kept short of the ends so both clubs' colours always show.
	_mom_home.size_flags_stretch_ratio = 1.0 + 0.9 * _momentum
	_mom_away.size_flags_stretch_ratio = 1.0 - 0.9 * _momentum


## Every event carries the engine's momentum as it stood ("mom"): the meter
## shows exactly that, nothing of its own.
func _track_momentum(ev: Dictionary) -> void:
	if not ev.has("mom"):
		return
	_momentum = clampf(float(ev["mom"]), -1.0, 1.0)
	_paint_momentum()


func _score_column(code: String, home: bool, narrow: bool) -> Control:
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_text := GameDB.club_short(code) if narrow else GameDB.club_name(code)
	var name := UiKit.ellipsis(name_text, 13 if narrow else 16, UiKit.TEXT, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var cols: Array = GameDB.club_colours(code)
	var score := UiKit.figure("0.0 (0)", 30 if narrow else 36, cols[2])
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	# A fixed minimum wider than the phone column is what shoved the oval
	# off screen. Let the score take its own width in portrait.
	if not narrow:
		score.custom_minimum_size = Vector2(136, 0)
	v.add_child(score)
	if home:
		_score_home = score
	else:
		_score_away = score
	return v


## The clock and who leads, between the two scores. The round and the
## ground are for the build-up (the first coach box), not the live glance.
func _score_middle(narrow: bool) -> Control:
	var mid := UiKit.vbox(0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(84 if narrow else 132, 0)
	_clock = UiKit.line("Q%d %d'" % [_shown_q, _shown_min], 17 if narrow else 20, UiKit.TEXT, true)
	_clock.name = "Clock"
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_clock)
	_lead = UiKit.ellipsis("", UiKit.SMALL, UiKit.MUTED)
	_lead.name = "LeadLine"
	_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_lead)
	return mid


## A final names its venue (the Grand Final is always at the MCG); any
## other match is at the home club's ground.
func _venue() -> String:
	var ground := str(_res.get("venue", ""))
	if ground == "":
		ground = str(GameDB.club(str(_res["home"])).get("ground", ""))
	return ground


func _controls() -> Control:
	var v := UiKit.vbox(6)

	var row := UiKit.hbox(5)
	v.add_child(row)
	_play_btn = UiKit.btn("Pause", 13)
	_play_btn.custom_minimum_size = Vector2(0, 40)
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.clip_text = true
	_play_btn.pressed.connect(_on_toggle)
	row.add_child(_play_btn)

	for s in SPEEDS:
		var b := UiKit.btn("%dx" % int(s), 13)
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_on_speed.bind(s))
		_speed_btns.append(b)
		row.add_child(b)

	var row2 := UiKit.hbox(5)
	v.add_child(row2)
	var skip := UiKit.btn("Skip to full time", 13)
	skip.custom_minimum_size = Vector2(0, 40)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_on_skip)
	row2.add_child(skip)

	# Your own match cannot be left half way (Back says so); a replay can.
	if not _interactive:
		var leave := UiKit.btn("Back to hub", 13)
		leave.custom_minimum_size = Vector2(0, 40)
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.pressed.connect(func(): Router.back())
		row2.add_child(leave)

	_sync_controls()
	return v


func _sync_controls() -> void:
	if _play_btn == null:
		return
	_play_btn.text = "Play" if not _pitch.playing else "Pause"
	for i in range(SPEEDS.size()):
		UiKit.set_selected(_speed_btns[i], is_equal_approx(_pitch.speed, SPEEDS[i]))


func _on_toggle() -> void:
	_pitch.toggle()
	_sync_controls()


func _on_speed(s: float) -> void:
	_pitch.set_speed(s)
	_sync_controls()


func _on_skip() -> void:
	_skipping = true
	_close_coach()
	_close_moment()
	if _interactive and GameState.pending_sim != null:
		_simulate_remaining()
	if _pitch != null:
		_pitch.skip_to_end()


func _close_moment() -> void:
	if _moment_overlay != null and is_instance_valid(_moment_overlay):
		if _moment_overlay.has_meta("scene") and not _skipping:
			# Cut back to the match: the scene fades out over play resuming.
			var leaving := _moment_overlay
			leaving.name = "MomentLeaving"
			leaving.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for c in leaving.find_children("*", "Control", true, false):
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw := leaving.create_tween()
			tw.tween_property(leaving, "modulate:a", 0.0, 0.3)
			tw.tween_callback(leaving.queue_free)
		else:
			_moment_overlay.queue_free()
	_moment_overlay = null


func _close_coach() -> void:
	_close_sheet()
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		_coach_overlay.queue_free()
		_coach_overlay = null


## Finish every quarter that has not been rolled yet, using the last plan the
## coach set. Skip used to drain only the events already on the pitch, which
## stopped at the quarter break.
func _simulate_remaining() -> void:
	var sim: MatchSim = GameState.pending_sim
	if sim == null or sim.current_quarter > 4:
		return
	# A quarter paused on a moment finishes first; the moment takes the
	# default call.
	if sim.quarter_in_progress():
		_res = sim.run_quarter()
		_stamp_match_meta()
	var t := _last_tactics
	if t.is_empty():
		# Skipped before the first bounce: the plan you took in still plays.
		t = {"gameplan": _current_plan(sim), "focus_id": "", "tag_id": "", "pep": "steady"}
	while sim.current_quarter <= 4:
		_apply_quarter_tactics(t)
		_res = sim.run_quarter()
		_stamp_match_meta()
	if sim.needs_extra_time():
		_res = sim.run_extra_time()
		_stamp_match_meta()
	_append_new_events()


# ---------------------------------------------------------------------------
# Quarter-by-quarter coaching
# ---------------------------------------------------------------------------
const GAMEPLANS := [
	["balanced", "Balanced"], ["attacking", "Attack corridor"],
	["defensive", "Defensive press"], ["contest", "Win contest"],
	["controlled", "Controlled tempo"], ["through_stars", "Through stars"],
]
const PEP_TALKS := [
	["steady", "Stay composed"], ["fire_up", "Fire them up"], ["calm", "Calm the group"],
]
## Short labels for the break, where the three sit side by side.
const PEP_SHORT := [["steady", "Composed"], ["fire_up", "Fire them up"], ["calm", "Calm them"]]
const ROTATION_SHORT := {"hard": "Hard", "normal": "Normal", "stars": "Ride stars"}


## The break: what happened, then your calls for the next quarter. It
## surfaces the problem - their midfield on top, a forward hurting you - and
## leaves the answer to you. No advice, no expected points.
func _show_coach_box() -> void:
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	_pitch.pause()
	_sync_controls()
	var sim: MatchSim = GameState.pending_sim
	var q := sim.current_quarter
	# The calls fill the screen at every break, so the actions sit at the
	# bottom with the choices just above them.
	var box := UiKit.modal_box(self, 640.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CoachBox"
	_coach_overlay = overlay
	var v: VBoxContainer = box["body"]
	var titles := {1: "Before the first bounce", 2: "Quarter time", 3: "Half time", 4: "Three-quarter time"}
	var title := UiKit.ellipsis(str(titles.get(q, "Quarter %d" % q)), UiKit.H1, UiKit.TEXT, true)
	title.name = "BreakTitle"
	v.add_child(title)
	if q == 1:
		var where := UiKit.ellipsis("%s  ·  %s" % [str(_res.get("label", "Match")), _venue()], UiKit.SMALL, UiKit.MUTED)
		v.add_child(where)
	else:
		var sc := UiKit.lbl(MatchNotes.break_score(str(_res["home"]), str(_res["away"]),
				_res.get("goals", [0, 0]), _res.get("behinds", [0, 0])), UiKit.BODY, UiKit.TEXT, true)
		sc.name = "BreakScore"
		sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sc)
		v.add_child(UiKit.spacer(UiKit.GAP))
		v.add_child(UiKit.section("What's happening"))
		v.add_child(_quarter_view(q - 1))
		var did := MatchNotes.calls_lines(_res, _my_side, q - 1) \
				+ MatchNotes.duel_change_lines(_res, _my_side, q - 1)
		if not did.is_empty():
			v.add_child(UiKit.spacer(UiKit.GAP))
			v.add_child(UiKit.section("What your calls did"))
			var dv := UiKit.vbox(4)
			dv.name = "CallsDid"
			for t in did:
				var dl := UiKit.lbl(str(t), UiKit.BODY, UiKit.TEXT)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dv.add_child(dl)
			v.add_child(dv)
		if q == 3:
			var report := UiKit.btn("Assistant's report", 15)
			report.name = "HalfTimeReport"
			report.custom_minimum_size = Vector2(0, 44)
			report.pressed.connect(func(): _show_half_time_popup(CoachReport.half_time_report(_res, _my_side)))
			v.add_child(report)
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section("Your calls" if q == 1 else "Next quarter"))

	# Your calls, as taps: nothing here is a settings form. Short lists sit
	# in plain view; a player list shows the few in the game so far and
	# keeps everyone else one tap away.
	# The plan in force is the engine's: your club plan before the first
	# bounce (GameState.prepare_interactive_match), your last call after.
	var calls := {
		"gameplan": _current_plan(sim),
		"tag_id": str((sim.tactics[_my_side] as Dictionary).get("tag_id", _last_tactics.get("tag_id", ""))),
		"focus_id": str(_last_tactics.get("focus_id", "")),
		"pep": "steady",
		"rotation": _rotation,
	}
	var narrow := UiKit.view_width(self) < 560.0

	var plan_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	plan_note.name = "PlanNote"
	plan_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var my_ground: Array = (sim.squads[_my_side] as Squad).ground
	var sync_note := func(key: String) -> void:
		var t := CoachReport.plan_summary(key)
		# Who makes it work: the plan's upside rests on them (PlanFit).
		var fit := GameState.plan_fit_line(my_ground, key)
		if fit != "":
			t += " " + fit
		plan_note.text = t
	var plan := _choice_grid("PlanPicker", GAMEPLANS, calls, "gameplan", 2 if narrow else 3, sync_note)
	v.add_child(_call_block("Gameplan", plan))
	v.add_child(plan_note)
	sync_note.call(str(calls["gameplan"]))

	# Tag: their most influential so far first, anyone on the ground a tap away.
	# A tag is a midfield job: only their midfielders can be tagged.
	var opp := _roster_side(1 - _my_side).filter(func(r): return MatchSim.taggable(r))
	var tag := _player_choice("TagPicker", "No tag", opp, _in_the_game(opp, 4), calls, "tag_id",
			"Tag which midfielder?")
	v.add_child(_call_block("Tag", tag))
	# Who goes to him - a fact, not advice (Roles: a tagger makes a tag bite
	# harder than a midfielder doing the job).
	var tagger = MatchSim.tagger_for(my_ground)
	var tag_text := "No midfielder on the ground to tag with."
	if tagger != null:
		tag_text = ("%s, your tagger, goes to him." if Roles.is_tagger(tagger)
				else "No specialist tagger on the ground: %s goes to him and gives up his own game.") % GameDB.player_display_name(tagger)
	var tag_note := UiKit.lbl(tag_text, UiKit.SMALL, UiKit.MUTED)
	tag_note.name = "TagNote"
	tag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag_note)

	# Key match-ups: who is on their key forwards, how the contests went last
	# quarter, and yours against their defenders. Change one in a tap.
	var mv := _matchups_view(sim, q)
	if mv != null:
		v.add_child(mv)

	# The rest of the calls, one tap away: the plan and the tag are the
	# decisions most breaks turn on.
	var more := UiKit.vbox(8)
	more.name = "MoreCalls"
	more.visible = false
	var more_btn := UiKit.btn("More calls", 15)
	more_btn.name = "MoreCallsToggle"
	more_btn.custom_minimum_size = Vector2(0, 44)
	more_btn.pressed.connect(func():
		more.visible = not more.visible
		more_btn.text = "Fewer calls" if more.visible else "More calls")
	v.add_child(more_btn)
	v.add_child(more)
	var syn_line := _synergy_line()
	if syn_line != "":
		var sl := UiKit.lbl(syn_line, UiKit.SMALL, UiKit.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.add_child(sl)

	var mine := _roster_side(_my_side)
	var focus := _player_choice("FocusPicker", "No one", mine, _in_the_game(mine, 4), calls, "focus_id",
			"Play through which player?")
	var focus_block := _call_block("Play through", focus)
	var focus_note := UiKit.lbl("Favour this player in possession chains and attacking transition.",
			UiKit.SMALL, UiKit.MUTED)
	focus_note.name = "FocusNote"
	focus_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_block.add_child(focus_note)
	more.add_child(focus_block)

	var pep_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	pep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_pep := func(key: String) -> void:
		pep_note.text = CoachReport.pep_summary(key)
		pep_note.visible = pep_note.text != ""
	var pep := _choice_grid("PepPicker", PEP_SHORT, calls, "pep", 3, sync_pep)
	more.add_child(_call_block("Pep talk", pep))
	more.add_child(pep_note)
	sync_pep.call("steady")

	var rot_opts := []
	for k in MatchSim.ROTATION_POLICIES:
		rot_opts.append([str(k), str(ROTATION_SHORT.get(k, MatchSim.ROTATION_POLICIES[k]["label"]))])
	var rot_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	rot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_rot := func(key: String) -> void:
		rot_note.text = str(MatchSim.ROTATION_POLICIES[key]["text"])
		rot_note.visible = key != "normal"
	var rot := _choice_grid("RotationPicker", rot_opts, calls, "rotation", 3, sync_rot)
	more.add_child(_call_block("Rotations", rot))
	more.add_child(rot_note)
	sync_rot.call(_rotation)
	more.add_child(_legs_view())

	var start := UiKit.btn("Start quarter" if q > 1 else "Bounce the ball", 18, true)
	start.name = "StartQuarter"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func():
		_rotation = str(calls["rotation"])
		var t := {
			"gameplan": str(calls["gameplan"]),
			"focus_id": str(calls["focus_id"]),
			"tag_id": str(calls["tag_id"]),
			"pep": str(calls["pep"]),
			"rotation": _rotation,
		}
		_close_coach()
		_simulate_next_quarter(t))
	box["footer"].add_child(start)
	var skip := UiKit.btn("Skip to full time", 15)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(_on_skip)
	box["footer"].add_child(skip)


## The quarter just played: what stood out, what they ran, how your calls
## and your tag came off. Facts only.
func _quarter_view(q: int) -> Control:
	var v := UiKit.vbox(4)
	v.name = "QuarterFacts"
	var lines: Array = MatchNotes.quarter_facts(_res, _my_side, q)
	var opp_last := _opp_last_plan()
	if opp_last != "" and opp_last != "balanced":
		lines.append("They played %s." % CoachReport.plan_label(opp_last))
	for m in _res.get("moments", []):
		if int(m.get("q", 0)) == q:
			lines.append(MatchNotes.moment_line(m))
	if lines.is_empty():
		lines.append("An even quarter.")
	for t in lines:
		var l := UiKit.lbl(str(t), UiKit.BODY, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


func _synergy_line() -> String:
	var syn: Array = GameState.pending_sim.synergies
	var names := func(keys: Array) -> String:
		var out: PackedStringArray = []
		for k in keys:
			out.append(Traits.with_effect(str(k)))
		return ", ".join(out) if not out.is_empty() else "none"
	return "Your synergies: %s. Theirs: %s." % [names.call(syn[_my_side]), names.call(syn[1 - _my_side])]


## The opposition's plan in the quarter just played ("" before the bounce).
func _opp_last_plan() -> String:
	var hist: Array = GameState.pending_sim.tactics_history
	if hist.is_empty():
		return ""
	return str(((hist[hist.size() - 1]["plans"] as Array)[1 - _my_side] as Dictionary).get("gameplan", "balanced"))


## "Your calls" for quarter `q` (0 = the whole match): what each cause was
## worth in expected points, the moments and how they came off, and the tag.
func _calls_view(q: int) -> Control:
	var v := UiKit.vbox(3)
	v.name = "CallsReadout"
	var snaps: Array = _res.get("quarter_teams", [])
	var now: Array = _res.get("impact", [{}, {}])
	var before: Array = [{}, {}]
	if q > 0 and snaps.size() >= q:
		now = (snaps[q - 1] as Dictionary).get("impact", now)
		if q >= 2:
			before = (snaps[q - 2] as Dictionary).get("impact", [{}, {}])
	v.add_child(UiKit.section("What your calls did" + (" in Q%d" % q if q > 0 else "")))
	var lines := CoachReport.impact_lines(now, before, _my_side)
	for l in lines.slice(0, 5):
		var pts := float(l["pts"])
		var row := UiKit.hbox(8)
		var name_l := UiKit.ellipsis(str(l["label"]), 13, UiKit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(UiKit.line("%+.1f pts" % pts, 13, UiKit.GOOD if pts > 0 else UiKit.BAD, true))
		v.add_child(row)
	var moments: Array = _res.get("moments", [])
	for m in moments:
		if q > 0 and int(m.get("q", 0)) != q:
			continue
		var l2 := UiKit.lbl("%s  %s: %s. %s" % [_clock_text(int(m["q"]), int(m["min"])),
				str(m.get("title", "")), str(m.get("choice_label", "")), str(m.get("outcome", ""))],
				12, UiKit.EMPH if int(m.get("points", 0)) >= 6 else UiKit.TEXT)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	var tag_line := _tag_line(q)
	if tag_line != "":
		v.add_child(UiKit.lbl(tag_line, 12, UiKit.TEXT))
	if lines.is_empty() and v.get_child_count() == 1:
		v.add_child(UiKit.lbl("An even quarter: no call moved the needle much.", 12, UiKit.MUTED))
	v.add_child(UiKit.lbl("Expected points each call added or cost, from the chances it changed.", 11, UiKit.MUTED))
	return v


## How your tag went in quarter q (or the match): the tagged player's line.
func _tag_line(q: int) -> String:
	var hist: Array = _res.get("tactics_history", [])
	var snaps: Array = _res.get("quarter_teams", [])
	var tag_id := ""
	for h in hist:
		if q > 0 and int(h.get("quarter", 0)) != q:
			continue
		var t := str(((h["plans"] as Array)[_my_side] as Dictionary).get("tag_id", ""))
		if t != "":
			tag_id = t
	if tag_id == "":
		return ""
	var d := 0.0
	var g := 0.0
	if q > 0 and snaps.size() >= q:
		var now: Dictionary = ((snaps[q - 1] as Dictionary)["players"] as Dictionary).get(tag_id, {})
		var was: Dictionary = {}
		if q >= 2:
			was = ((snaps[q - 2] as Dictionary)["players"] as Dictionary).get(tag_id, {})
		d = float(now.get("disposals", 0.0)) - float(was.get("disposals", 0.0))
		g = float(now.get("goals", 0.0)) - float(was.get("goals", 0.0))
	else:
		var st: Dictionary = (_res.get("players", {}) as Dictionary).get(tag_id, {})
		d = float(st.get("disposals", 0.0))
		g = float(st.get("goals", 0.0))
	return "Your tag on %s: %d disposals, %d goals." % [
			GameDB.player_display_name_by_id(tag_id, "their player"), int(d), int(g)]


## Legs in words: how both midfields are going, and who is running on empty.
func _legs_view() -> Control:
	var v := UiKit.vbox(2)
	v.name = "LegsView"
	var l := UiKit.lbl(MatchNotes.legs_line(_group_energy(_my_side), _group_energy(1 - _my_side)),
			UiKit.SMALL, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var cooked := MatchNotes.cooked(GameState.pending_sim.legs(_my_side))
	if not cooked.is_empty():
		var c := UiKit.lbl("Running on empty: %s." % ", ".join(cooked), UiKit.SMALL, UiKit.TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(c)
	return v


func _group_energy(side: int) -> float:
	var total := 0.0
	var n := 0
	for r in GameState.pending_sim.legs(side):
		if bool(r["on"]) and (str(r["role"]) == "MID" or str(r["role"]) == "RUCK"):
			total += float(r["energy"])
			n += 1
	return total / float(maxi(1, n))


# ---------------------------------------------------------------------------
# Match moments
# ---------------------------------------------------------------------------
func _show_moment() -> void:
	_close_moment()
	_pitch.pause()
	var m: Dictionary = GameState.pending_sim.pending_moment
	if str(m.get("kind", "")) == "bounce":
		_show_bounce_moment(m)
		return
	# Sized for its few lines, not the whole phone.
	var box := UiKit.modal_box(self, 560.0, 440.0)
	_moment_overlay = box["overlay"]
	_moment_overlay.name = "MomentCard"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Coach's call  ·  %s" % _clock_text(int(m.get("q", 1)), int(m.get("min", 0))),
			UiKit.SMALL, UiKit.MUTED))
	var title := UiKit.lbl(str(m.get("title", "")), 20, UiKit.EMPH, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var text := UiKit.lbl(str(m.get("text", "")), 14, UiKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	var options: Array = m.get("options", [])
	for i in range(options.size()):
		var o: Dictionary = options[i]
		var b := UiKit.btn(str(o.get("label", "")), 16, i == 0)
		b.name = "Moment_%d" % i
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(_on_moment_choice.bind(i))
		v.add_child(b)
		var d := UiKit.lbl(str(o.get("detail", "")), 12, UiKit.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)


## The late centre-bounce call as a scene (ARD-M8-007 prototype): the match
## cuts to a close-up of that stoppage, the players set up, the ball goes up
## and it freezes; the call slides up over the frozen scene; the choice cuts
## back to the match. The options and what they do are MatchSim's; the scene
## only shows the state of the match.
func _show_bounce_moment(m: Dictionary) -> void:
	var overlay := UiKit.cover(self)
	overlay.color = Color(0, 0, 0, 0)
	overlay.name = "MomentCard"
	overlay.set_meta("scene", true)
	_moment_overlay = overlay
	var vignette := StoppageVignette.new()
	vignette.name = "StoppageVignette"
	overlay.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.setup(GameState.pending_sim, _my_side, str(m.get("title", "")))
	# The call, held below the screen until the scene freezes.
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hold := UiKit.vbox(0)
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hold)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hold.add_child(spacer)
	var panel := UiKit.panel(UiKit.PANEL, 14)
	panel.name = "BounceCall"
	hold.add_child(panel)
	var call := UiKit.vbox(6)
	panel.add_child(call)
	for f in vignette.facts:
		var fl := UiKit.lbl(str(f), UiKit.BODY, UiKit.TEXT, true)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		call.add_child(fl)
	var text := UiKit.lbl(str(m.get("text", "")), UiKit.SMALL, UiKit.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	call.add_child(text)
	var buttons: Array = []
	var options: Array = m.get("options", [])
	for i in range(options.size()):
		var o: Dictionary = options[i]
		var b := UiKit.btn(str(o.get("label", "")), 16, i == 0)
		b.name = "Moment_%d" % i
		b.custom_minimum_size = Vector2(0, 46)
		b.disabled = true
		b.pressed.connect(_on_moment_choice.bind(i))
		call.add_child(b)
		buttons.append(b)
		var d := UiKit.lbl(str(o.get("detail", "")), 12, UiKit.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		call.add_child(d)
	panel.modulate.a = 0.0
	margin.add_theme_constant_override("margin_bottom", -600)
	vignette.ready_for_call.connect(func() -> void:
		for b in buttons:
			if is_instance_valid(b):
				b.disabled = false
		if not is_instance_valid(margin):
			return
		panel.modulate.a = 1.0
		var tw := margin.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: margin.add_theme_constant_override("margin_bottom", int(v)),
				-600.0, 0.0, 0.3))


func _on_moment_choice(i: int) -> void:
	_close_moment()
	var sim: MatchSim = GameState.pending_sim
	if sim == null or sim.pending_moment.is_empty():
		return
	# The call and how it came off reach the feed as the "moment" event,
	# when play reaches it.
	sim.resolve_moment(i)
	_advance_segment()


## A call and its choices, heading above.
func _call_block(label: String, control: Control) -> Control:
	var v := UiKit.vbox(6)
	v.add_child(UiKit.lbl(label, UiKit.SMALL, UiKit.MUTED, true))
	v.add_child(control)
	return v


## One tap picks one (UiKit.choice_grid); the key lands in calls[field]
## and on_change(key) runs.
func _choice_grid(node_name: String, options: Array, calls: Dictionary, field: String, columns: int,
		on_change: Callable = Callable()) -> Control:
	return UiKit.choice_grid(node_name, options, str(calls[field]), columns, func(key: String):
		calls[field] = key
		if on_change.is_valid():
			on_change.call(key))


## A player call: "none", the few in the game so far, whoever is chosen,
## and "Other player..." for the whole side on the ground. Nobody is left
## out; the list is just ordered.
func _player_choice(node_name: String, none_label: String, roster: Array, first: Array,
		calls: Dictionary, field: String, sheet_title: String) -> Control:
	var box := UiKit.vbox(0)
	box.name = node_name
	var rebuild := func(self_ref: Callable) -> void:
		UiKit.clear(box)
		var shown := [["", none_label]]
		var ids := {}
		for r in first:
			shown.append([str(r["id"]), _short_name(r)])
			ids[str(r["id"])] = true
		var cur := str(calls[field])
		if cur != "" and not ids.has(cur):
			for r in roster:
				if str(r["id"]) == cur:
					shown.append([cur, _short_name(r)])
		var grid := _choice_grid(node_name + "Grid", shown, calls, field, 2)
		box.add_child(grid)
		var other := UiKit.btn("Other player…", 14)
		other.name = node_name + "Other"
		other.custom_minimum_size = Vector2(0, 44)
		other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other.pressed.connect(func():
			_player_sheet(sheet_title, roster, str(calls[field]), func(id: String):
				calls[field] = id
				self_ref.call(self_ref)))
		grid.add_child(other)
	rebuild.call(rebuild)
	return box


func _short_name(r: Dictionary) -> String:
	return GameDB.player_display_name_by_id(str(r.get("id", "")), str(r.get("name", "Player")))


## Everyone on the ground for one side, one tap each; the current choice is
## marked. Back or Close leaves it as it was.
func _player_sheet(title: String, roster: Array, current: String, on_pick: Callable) -> void:
	_close_sheet()
	var box := UiKit.modal_box(self, 480.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "PlayerSheet"
	_sheet_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis(title, UiKit.H2, UiKit.TEXT, true))
	var players: Dictionary = _res.get("players", {})
	var ordered := roster.duplicate()
	ordered.sort_custom(func(a, b): return int(a.get("num", 0)) < int(b.get("num", 0)))
	for r in ordered:
		var id := str(r["id"])
		var st: Dictionary = players.get(id, {})
		var line := "#%d  %s" % [int(r.get("num", 0)), _short_name(r)]
		if not st.is_empty():
			line += "  ·  " + MatchNotes.game_line(st)
		var b := UiKit.btn(line, 14)
		b.name = "Sheet_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0, 44)
		UiKit.paint_choice(b, id == current)
		b.pressed.connect(func():
			_close_sheet()
			on_pick.call(id))
		v.add_child(b)
	var close := UiKit.btn("Close", 16)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_sheet)
	box["footer"].add_child(close)


func _close_sheet() -> void:
	if _sheet_overlay != null and is_instance_valid(_sheet_overlay):
		_sheet_overlay.queue_free()
	_sheet_overlay = null


## The players most in the game so far (before the bounce, the best rated):
## ordered, never filtered.
func _in_the_game(roster: Array, n: int) -> Array:
	var players: Dictionary = _res.get("players", {})
	var out := roster.duplicate()
	out.sort_custom(func(a, b):
		var x := CoachReport.influence(players.get(str(a["id"]), {}))
		var y := CoachReport.influence(players.get(str(b["id"]), {}))
		if x != y:
			return x > y
		return int(a["overall"]) > int(b["overall"]))
	return out.slice(0, n)


func _roster_side(side: int) -> Array:
	var roster: Array = _res.get("roster", [[], []])
	if roster.size() <= side:
		return []
	var out: Array = roster[side].duplicate()
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return out


# ---------------------------------------------------------------------------
# Half-time assistant coach report
# ---------------------------------------------------------------------------
func _show_half_time_popup(report: Dictionary) -> void:
	_close_report()
	var box := UiKit.modal_box(self, 640.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "AssistantReport"
	_report_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiKit.ellipsis("Assistant's report", UiKit.H1, UiKit.TEXT, true))
	# The report covers the scoreboard: say where the game stands, once.
	var margin := int(report.get("margin", 0))
	var where := "Half time, scores level" if margin == 0 else ("Half time, up by %d" % margin
			if margin > 0 else "Half time, down by %d" % absi(margin))
	v.add_child(UiKit.lbl(where, UiKit.SMALL, UiKit.MUTED))
	v.add_child(_report_glance(report))
	var close := UiKit.btn("Close report", 16, true)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_report)
	box["footer"].add_child(close)


## The assistant's report: the match in a few lines, who matters and what
## to work on. The one report; the numbers behind it are on the Stats tab.
func _report_glance(report: Dictionary, full_time := false) -> Control:
	var v := UiKit.vbox(6)
	v.name = "ReportGlance"
	var g := CoachReport.glance(report, full_time)
	_glance_section(v, "Match read", "MatchRead", g["read"])
	_glance_people(v, "Your best", "ReportBest", g["best"])
	_glance_people(v, "Needs a lift", "ReportLift", g["lift"])
	_glance_people(v, "Opposition danger", "ReportDanger", g["danger"])
	_glance_section(v, "Worth working on" if full_time else "Second-half notes", "ReportNotes", g["notes"])
	return v


func _glance_section(v: VBoxContainer, title: String, node_name: String, lines: Array) -> void:
	if lines.is_empty():
		return
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section(title))
	var box := UiKit.vbox(4)
	box.name = node_name
	for t in lines:
		var l := UiKit.lbl(str(t), UiKit.BODY, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	v.add_child(box)


func _glance_people(v: VBoxContainer, title: String, node_name: String, people: Array) -> void:
	if people.is_empty():
		return
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section(title))
	var box := UiKit.vbox(6)
	box.name = node_name
	for p in people:
		var row := UiKit.vbox(0)
		row.add_child(UiKit.ellipsis(str(p["name"]), UiKit.BODY, UiKit.TEXT, true))
		row.add_child(UiKit.ellipsis(str(p["line"]), UiKit.SMALL, UiKit.MUTED))
		box.add_child(row)
	v.add_child(box)


func _close_report() -> void:
	if _report_overlay != null and is_instance_valid(_report_overlay):
		_report_overlay.queue_free()
	_report_overlay = null


## The plan your side is playing right now, as the engine has it.
func _current_plan(sim: MatchSim) -> String:
	var plan := str((sim.tactics[_my_side] as Dictionary).get("gameplan", ""))
	if plan == "":
		plan = str(_last_tactics.get("gameplan", ""))
	return plan if plan != "" else "balanced"


func _simulate_next_quarter(t: Dictionary) -> void:
	_last_tactics = t.duplicate()
	_apply_quarter_tactics(t)
	_show_setup(t)
	GameState.pending_sim.begin_quarter()
	_advance_segment()


## Simulate on to the end of the quarter or the next moment, then play it.
func _advance_segment() -> void:
	var sim: MatchSim = GameState.pending_sim
	if sim.continue_quarter():
		_res = sim.end_quarter()
	else:
		_res = sim.result()
	_stamp_match_meta()
	_append_new_events()
	_pitch.play()
	_sync_controls()


func _apply_quarter_tactics(t: Dictionary) -> void:
	var sim: MatchSim = GameState.pending_sim
	sim.set_tactics(_my_side, t)
	sim.set_rotation_policy(_my_side, str(t.get("rotation", _rotation)))
	# The rival coach plays its usual game, protects a lead, chases a
	# deficit, and tags your best midfielder after half time.
	sim.set_tactics(1 - _my_side, sim.ai_tactics(1 - _my_side))


## "Defensive press · tagging Walsh": your calls for this quarter, one line.
func _show_setup(t: Dictionary) -> void:
	if _setup_line == null or not is_instance_valid(_setup_line):
		return
	var bits := PackedStringArray(["Your plan: " + CoachReport.plan_label(str(t.get("gameplan", "balanced")))])
	var tag_id := str(t.get("tag_id", ""))
	if tag_id != "":
		bits.append("tagging " + GameDB.player_display_name_by_id(tag_id, "their player"))
	var focus_id := str(t.get("focus_id", ""))
	if focus_id != "":
		bits.append("through " + GameDB.player_display_name_by_id(focus_id, "your player"))
	_setup_line.text = "  ·  ".join(bits)
	_setup_line.visible = true


func _stamp_match_meta() -> void:
	_res["home"] = GameState.pending_match["home"]
	_res["away"] = GameState.pending_match["away"]
	_res["label"] = GameState.pending_match["label"]
	_res["venue"] = str(GameState.pending_match.get("venue", ""))


func _append_new_events() -> void:
	var all_events: Array = _res.get("events", [])
	var new_events := all_events.slice(_event_cursor)
	_event_cursor = all_events.size()
	if not new_events.is_empty():
		_pitch.append_events(new_events)


# ---------------------------------------------------------------------------
# Playback hooks
# ---------------------------------------------------------------------------
func _on_event(ev: Dictionary) -> void:
	_update_scoreboard(ev)
	_track_momentum(ev)
	_feed_add(ev)
	_duel_feed(ev)
	_story_feed(ev)
	if str(ev.get("kind", "")) == "goal":
		_flash_score(int(ev.get("side", 0)))
		_track_run(int(ev.get("side", 0)))


## "Carlton have kicked three in a row." - a fact from the goals in the log.
func _track_run(side: int) -> void:
	if side == _run_side:
		_run_len += 1
	else:
		_run_side = side
		_run_len = 1
	if _run_len >= RUN_LINE:
		var code := str(_res["home"] if side == 0 else _res["away"])
		_feed_text(MatchNotes.run_line(code, _run_len), UiKit.TEXT, true, "RunLine")


## A goal in the feed: the scoring club's colour down the side, "Goal" and
## the kicker in large type, then the score. Nothing else in the feed looks
## like it.
func _goal_row(ev: Dictionary, stamp: String) -> Control:
	var side := int(ev.get("side", 0))
	var code := str(_res["home"] if side == 0 else _res["away"])
	var row := UiKit.hbox(8)
	row.name = "GoalRow"
	row.set_meta("feed_kind", "goal")
	var stripe := ColorRect.new()
	stripe.color = (GameDB.club_colours(code) as Array)[0]
	if stripe.color.get_luminance() < 0.12:
		stripe.color = (GameDB.club_colours(code) as Array)[2]
	stripe.custom_minimum_size = Vector2(4, 0)
	row.add_child(stripe)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var who := str(ev.get("name", ""))
	var head := "Goal  " + (who if who != "" else GameDB.club_short(code))
	var hl := UiKit.lbl(head, 17, UiKit.TEXT, true)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hl)
	var g: Array = ev.get("goals", [0, 0])
	var b: Array = ev.get("behinds", [0, 0])
	# A Crumber's goal off the deck is his trait at work: say so.
	if str(ev.get("trait", "")) == "crumber":
		stamp = "Crumbing goal  ·  " + stamp
	v.add_child(UiKit.lbl("%s  ·  %s %s  %s %s" % [stamp,
			GameDB.club_short(str(_res["home"])), UiKit.scoreline(int(g[0]), int(b[0])),
			GameDB.club_short(str(_res["away"])), UiKit.scoreline(int(g[1]), int(b[1]))],
			UiKit.SMALL, UiKit.MUTED))
	return row


## The scoring side's score swells for a moment on a goal.
func _flash_score(side: int) -> void:
	var l: Label = _score_home if side == 0 else _score_away
	if l == null or not is_instance_valid(l) or _skipping:
		return
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_scoreboard(ev: Dictionary) -> void:
	if ev.has("goals") and ev.has("behinds"):
		var g: Array = ev["goals"]
		var b: Array = ev["behinds"]
		_shown_goals = [int(g[0]), int(g[1])]
		_shown_behinds = [int(b[0]), int(b[1])]
	_shown_q = int(ev.get("q", _shown_q))
	_shown_min = int(ev.get("min", _shown_min))
	_paint_scoreboard()


func _paint_scoreboard() -> void:
	if _score_home == null or _score_away == null:
		return
	_score_home.text = UiKit.scoreline(_shown_goals[0], _shown_behinds[0])
	_score_away.text = UiKit.scoreline(_shown_goals[1], _shown_behinds[1])
	if _clock != null:
		_clock.text = _clock_text(_shown_q, _shown_min)
	if _lead != null and is_instance_valid(_lead):
		var narrow := UiKit.view_width(self) < 640.0
		var name_of := func(c): return GameDB.club_short(str(c)) if narrow else GameDB.club_name(str(c))
		_lead.text = MatchNotes.lead_text(str(_res["home"]), str(_res["away"]), [
				_shown_goals[0] * 6 + _shown_behinds[0], _shown_goals[1] * 6 + _shown_behinds[1]], name_of)


## "Q3 12'": the minute of the quarter, like a ground's clock. MatchSim
## stamps each quarter 30 minutes on from the last; extra time counts its
## own minutes from zero.
func _clock_text(q: int, minute: int) -> String:
	if q >= 5:
		return "ET %d'" % clampi(minute - 120, 0, 99)
	return "Q%d %d'" % [q, clampi(minute - (q - 1) * QUARTER_MINUTES, 0, QUARTER_MINUTES)]


func _feed_add(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if QUIET_KINDS.has(kind):
		return
	var line := MatchNotes.feed_line(ev, str(_res["home"]), str(_res["away"]))
	if line.is_empty():
		return
	var stamp := _clock_text(int(ev.get("q", 1)), int(ev.get("min", 0)))
	if str(line["tier"]) == "goal":
		_feed.add_child(_goal_row(ev, stamp))
		_trim_feed()
	elif str(line["tier"]) == "break":
		_feed_text(str(line["text"]), UiKit.TEXT, true, "BreakLine")
	else:
		_feed_text("%s  %s" % [stamp, str(line["text"])], UiKit.TEXT, false, "PlayLine")


func _feed_text(text: String, col: Color, strong: bool, node_name: String) -> void:
	if _feed == null:
		return
	var l := UiKit.lbl(text, UiKit.SMALL, col, strong)
	l.name = node_name
	# Siblings cannot share a name, so the row's kind rides as metadata.
	l.set_meta("feed_kind", node_name)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)
	_trim_feed()


func _trim_feed() -> void:
	while _feed.get_child_count() > FEED_LIMIT:
		var first := _feed.get_child(0)
		_feed.remove_child(first)
		first.queue_free()
	# Wait a frame: the scroll range only grows once the new row is laid out.
	await get_tree().process_frame
	if is_instance_valid(_feed_scroll):
		_feed_scroll.scroll_vertical = int(_feed_scroll.get_v_scroll_bar().max_value)


func _on_finished() -> void:
	if _fulltime_shown:
		return
	if _interactive and not _skipping and GameState.pending_sim != null \
			and not GameState.pending_sim.pending_moment.is_empty():
		_sync_controls()
		_show_moment()
		return
	# Skip sims the rest of the match first, then drains the pitch. Without
	# this flag the quarter-end signal reopens the coach box.
	if _interactive and not _skipping and GameState.pending_sim != null \
			and GameState.pending_sim.current_quarter <= 4:
		_sync_controls()
		_show_coach_box()
		return
	# A level final plays on: extra time is rolled now and fed to the pitch.
	if _interactive and not _skipping and GameState.pending_sim != null \
			and GameState.pending_sim.needs_extra_time():
		_res = GameState.pending_sim.run_extra_time()
		_stamp_match_meta()
		_append_new_events()
		_pitch.play()
		_sync_controls()
		return
	_skipping = false
	_finished = true
	_fulltime_shown = true
	_close_coach()
	if _res.has("goals") and _res.has("behinds"):
		var end_q := 4
		var end_min := 4 * QUARTER_MINUTES
		var evs: Array = _res.get("events", [])
		if bool(_res.get("extra_time", false)) and not evs.is_empty():
			end_q = 5
			end_min = int((evs[evs.size() - 1] as Dictionary).get("min", 128))
		_update_scoreboard({
			"q": end_q, "min": end_min, "kind": "final",
			"goals": _res["goals"], "behinds": _res["behinds"],
		})
	if _interactive:
		GameState.finish_interactive_match(_res)
	_sync_controls()
	_show_fulltime()


# ---------------------------------------------------------------------------
# Full time
# ---------------------------------------------------------------------------
## Full time is one review with two tabs - the Summary (the one coaching
## report) and Stats - and one way out: Continue. Back on Stats returns to
## Summary. Review match (Sim round) opens the same screen.
func _show_fulltime() -> void:
	var box := UiKit.modal_box(self, 640.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "FullTime"
	_ft_box = box
	_ft_tab = "summary"
	# The tabs sit above the scrolling body, so they never scroll away.
	var outer: Node = (box["body"] as Control).get_parent().get_parent()
	_ft_tabs = UiKit.hbox(2)
	_ft_tabs.name = "ReviewTabs"
	outer.add_child(_ft_tabs)
	outer.move_child(_ft_tabs, 0)

	var home: String = _res["home"]
	var away: String = _res["away"]
	var mine := GameState.my_club != "" and (home == GameState.my_club or away == GameState.my_club)
	if mine and (_interactive or _review):
		var train := UiKit.btn("Training", 15)
		train.name = "FullTimeTraining"
		train.custom_minimum_size = Vector2(0, 44)
		train.pressed.connect(func():
			overlay.queue_free()
			Router.replace("training"))
		box["footer"].add_child(train)
	# The week is over: back to the hub, where next week starts.
	var leave := UiKit.btn("Continue", 18, true)
	leave.name = "FullTimeContinue"
	leave.custom_minimum_size = Vector2(0, 48)
	leave.pressed.connect(func(): Router.back())
	box["footer"].add_child(leave)
	_render_ft()


func _ft_tab_list() -> Array:
	return [["summary", "Summary"], ["stats", "Stats"]]


func _render_ft() -> void:
	var v: VBoxContainer = _ft_box["body"]
	UiKit.clear(v)
	UiKit.clear(_ft_tabs)
	for t in _ft_tab_list():
		var key := str(t[0])
		var b := UiKit.tab(str(t[1]), key == _ft_tab)
		b.name = "ReviewTab_" + key
		b.custom_minimum_size.y = 44
		b.pressed.connect(func():
			_ft_tab = key
			_render_ft())
		_ft_tabs.add_child(b)
	match _ft_tab:
		"stats":
			_ft_stats(v)
		_:
			_ft_summary(v)
	var sc := v.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 0


## The Summary tab: the result, what it means, how it went, the best
## players, a few numbers and your week.
func _ft_summary(v: VBoxContainer) -> void:

	var s: Array = _res["score"]
	var home: String = _res["home"]
	var away: String = _res["away"]
	var mine := GameState.my_club != "" and (home == GameState.my_club or away == GameState.my_club)
	var me := 0 if home == GameState.my_club else 1
	var margin := absi(int(s[0]) - int(s[1]))
	var winner := -1 if int(s[0]) == int(s[1]) else (0 if int(s[0]) > int(s[1]) else 1)

	var head := "Full time  ·  %s" % str(_res.get("label", "Match"))
	if bool(_res.get("extra_time", false)):
		head += "  ·  after extra time"
	v.add_child(UiKit.ellipsis(head, UiKit.SMALL, UiKit.MUTED))

	# The result first, big: who won and by how much.
	var verdict := "Draw"
	var col := UiKit.TEXT
	if winner >= 0 and mine:
		verdict = ("Won by %d" if winner == me else "Lost by %d") % margin
		col = UiKit.margin_colour(winner == me)
	elif winner >= 0:
		verdict = "%s by %d" % [GameDB.club_name(home if winner == 0 else away), margin]
	var vl := UiKit.lbl(verdict, 30, col, true)
	vl.name = "Verdict"
	v.add_child(vl)
	for side in [0, 1]:
		var row := UiKit.hbox(8)
		row.name = "FinalScore_%d" % side
		var nm := UiKit.ellipsis(GameDB.club_name(home if side == 0 else away), UiKit.BODY,
				UiKit.TEXT if winner != 1 - side else UiKit.MUTED, winner == side)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var fig := UiKit.figure(UiKit.scoreline(int(_res["goals"][side]), int(_res["behinds"][side])),
				24, UiKit.TEXT if winner != 1 - side else UiKit.MUTED)
		row.add_child(fig)
		# Clear of the scrollbar.
		row.add_child(UiKit.spacer(10))
		v.add_child(row)

	# What it means: finals, the ladder, who is next.
	if mine:
		var outlook := GameState.finals_outcome_line(_res)
		if outlook != "":
			var tag_now := str(_res.get("tag", ""))
			var slots: Dictionary = GameState.season.finals.get("slots", {})
			var through: bool = str(slots.get("W_" + tag_now, "")) == GameState.my_club
			var ol := UiKit.lbl(outlook, 20 if tag_now == "GF" else UiKit.BODY,
					UiKit.EMPH if through else UiKit.MUTED, true)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(ol)
		if (_interactive or _review) and str(_res.get("tag", "")) == "":
			var moved := GameState.ladder_move_line(_pos_before)
			if moved != "":
				var ml := UiKit.lbl(moved, UiKit.BODY, UiKit.TEXT, true)
				ml.name = "LadderMove"
				v.add_child(ml)
			var nxt := GameState.next_fixture_line()
			if nxt != "":
				var nl := UiKit.lbl(nxt, UiKit.BODY, UiKit.MUTED)
				nl.name = "NextFixture"
				v.add_child(nl)

	# How it went: the few things that decided it, in football words.
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section("How it went"))
	var factors := VBoxContainer.new()
	factors.name = "MatchFactors"
	factors.add_theme_constant_override("separation", 4)
	for f in MatchNotes.match_factors(_res, me if mine else 0):
		var fl := UiKit.lbl(str(f), UiKit.BODY, UiKit.TEXT)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		factors.add_child(fl)
	v.add_child(factors)

	# Best players: best on ground, then the rest of yours and their best.
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section("Best players"))
	var best_box := UiKit.vbox(6)
	best_box.name = "BestPlayers"
	var first := me if mine else (winner if winner >= 0 else 0)
	var ours := MatchNotes.standouts(_res, first, 3)
	var theirs := MatchNotes.standouts(_res, 1 - first, 1)
	var bog: Dictionary = ours[0] if not ours.is_empty() else {}
	if not theirs.is_empty() and (bog.is_empty() or float(theirs[0]["inf"]) > float(bog["inf"])):
		bog = theirs[0]
	for p in ours:
		best_box.add_child(_standout_row(p, first, p == bog))
	if not theirs.is_empty():
		best_box.add_child(UiKit.spacer(2))
	for p in theirs:
		best_box.add_child(_standout_row(p, 1 - first, p == bog))
	v.add_child(best_box)

	# The coach's side of it: who needs a lift, and what to work on. Only
	# for your match, and only what the result above does not already say.
	if mine and (_res.get("quarter_teams", []) as Array).size() >= 2:
		var g := CoachReport.glance(CoachReport.match_report(_res, me), true)
		_glance_people(v, "Needs a lift", "ReportLift", g["lift"])
		_glance_section(v, "Coaching notes", "ReportNotes", (g["notes"] as Array).slice(0, 2))

	# The key match-ups: who had the better of whom, from the contests.
	if mine:
		_glance_section(v, "Key match-ups", "FullTimeMatchups", MatchNotes.duel_story(_res, me).slice(0, 3))
		# Your synergies: the stat each one shows up in, from this match.
		_glance_section(v, "Your synergies", "FullTimeSynergies", MatchNotes.synergy_lines(_res, me).slice(0, 3))

	# Your calls, quarter by quarter: what each was about and how that went.
	if mine and _interactive:
		var did := []
		for qq in range(1, 5):
			for t in MatchNotes.calls_lines(_res, me, qq) + MatchNotes.duel_change_lines(_res, me, qq):
				did.append("Q%d  ·  %s" % [qq, str(t)])
		if not did.is_empty():
			_glance_section(v, "Your calls", "FullTimeCalls", did.slice(0, 5))

	# A handful of numbers worth a glance; the full table is a tap away.
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(_key_stats_view(me if mine else 0))

	# Your week: who is hurt, who improved.
	if mine and (_interactive or _review):
		var week := UiKit.vbox(4)
		week.name = "YourWeek"
		var hurt := GameState.my_new_injuries()
		if not hurt.is_empty():
			var inj := UiKit.lbl("Injured: " + ", ".join(hurt), UiKit.BODY, UiKit.BAD, true)
			inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			week.add_child(inj)
		var report: Dictionary = GameState.last_training_report
		if str(report.get("home", "")) == home and str(report.get("away", "")) == away:
			# Who improved, and how, lives in Training (a tap below); here
			# just that it happened.
			var rises: Array = (report.get("auto", {}) as Dictionary).get("rises", [])
			if not rises.is_empty():
				var gl := UiKit.lbl("%d %s at training." % [rises.size(),
						"player improved" if rises.size() == 1 else "players improved"], UiKit.SMALL, UiKit.TEXT)
				gl.name = "TrainingCount"
				week.add_child(gl)
		if week.get_child_count() > 0:
			v.add_child(UiKit.spacer(UiKit.GAP))
			v.add_child(UiKit.section("Your week"))
			v.add_child(week)


## One standout: the name (marked if best on ground), his game in words and
## his match rating at the end of the line.
func _standout_row(p: Dictionary, side: int, best: bool) -> Control:
	var h := UiKit.hbox(8)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var code := str(_res["home"] if side == 0 else _res["away"])
	var name := "%s  ·  %s" % [str(p["name"]), GameDB.club_short(code)]
	if best:
		name += "  ·  best on ground"
	v.add_child(UiKit.ellipsis(name, UiKit.BODY, UiKit.TEXT, true))
	v.add_child(UiKit.ellipsis(str(p["line"]), UiKit.SMALL, UiKit.MUTED))
	var r := UiKit.line(MatchNotes.rating_text(float(p["rating"])), 20, UiKit.TEXT, true)
	r.name = "StandoutRating"
	r.tooltip_text = "Player rating for this match"
	h.add_child(r)
	# Clear of the scrollbar.
	var gap := Control.new()
	gap.custom_minimum_size.x = 10
	h.add_child(gap)
	return h


func _key_stats_view(me: int) -> Control:
	var v := UiKit.vbox(2)
	v.name = "KeyStats"
	var codes := [str(_res["home"]), str(_res["away"])]
	var h0 := UiKit.hbox(4)
	h0.add_child(_qcell(GameDB.club_short(codes[me]), 64, UiKit.MUTED, UiKit.SMALL, true))
	var gap := UiKit.line("", UiKit.SMALL, UiKit.MUTED)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.add_child(gap)
	h0.add_child(_qcell(GameDB.club_short(codes[1 - me]), 64, UiKit.MUTED, UiKit.SMALL, true))
	v.add_child(h0)
	for row in MatchNotes.key_stats(_res, me):
		var h := UiKit.hbox(4)
		var a := int(row[1])
		var b := int(row[2])
		h.add_child(_qcell(str(a), 64, UiKit.TEXT, UiKit.BODY, a > b))
		var lab := UiKit.ellipsis(str(row[0]), UiKit.SMALL, UiKit.MUTED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lab)
		h.add_child(_qcell(str(b), 64, UiKit.TEXT, UiKit.BODY, b > a))
		v.add_child(h)
	return v


## The Stats tab: quarter by quarter, every team stat, every player of both
## clubs, and what your calls did.
func _ft_stats(v: VBoxContainer) -> void:
	var box := UiKit.vbox(8)
	box.name = "MatchStats"
	v.add_child(box)
	box.add_child(UiKit.section("Quarter by quarter"))
	box.add_child(_quarters_table())
	box.add_child(UiKit.spacer(UiKit.GAP))
	box.add_child(UiKit.section("Team stats"))
	box.add_child(_team_stats_table())
	box.add_child(UiKit.spacer(UiKit.GAP))
	box.add_child(UiKit.section("Player stats"))
	box.add_child(PlayerStatsTable.new().setup(_res, _my_side))
	if _interactive:
		box.add_child(UiKit.spacer(UiKit.GAP))
		box.add_child(_calls_view(0))


func _quarters_table() -> Control:
	# Badge plus four quarters plus a full scoreline does not fit a phone
	# modal. Stack each club there, and keep the wide table for landscape.
	if UiKit.view_width(self) < 560.0:
		return _quarters_stacked()
	var v := UiKit.vbox(3)
	var home: String = _res["home"]
	var away: String = _res["away"]
	var qg: Array = _res["q_goals"]
	var qb: Array = _res["q_behinds"]
	var qh := UiKit.hbox(4)
	v.add_child(qh)
	qh.add_child(_qcell("", 36, UiKit.MUTED, 12))
	for i in range(qg.size()):
		qh.add_child(_qcell(_period_label(i), 48, UiKit.MUTED, 12))
	qh.add_child(_qcell("Final", 96, UiKit.MUTED, 12))
	for side in range(2):
		var code: String = home if side == 0 else away
		var qr := UiKit.hbox(4)
		v.add_child(qr)
		qr.add_child(UiKit.club_badge(code, 12, true, false))
		for i in range(qg.size()):
			qr.add_child(_qcell("%d.%d" % [int(qg[i][side]), int(qb[i][side])],
					48, UiKit.TEXT, 12))
		qr.add_child(_qcell(UiKit.scoreline(int(_res["goals"][side]),
				int(_res["behinds"][side])), 96, UiKit.EMPH, 13, true))
	return v


func _quarters_stacked() -> Control:
	var v := UiKit.vbox(8)
	var codes := [str(_res["home"]), str(_res["away"])]
	var qg: Array = _res["q_goals"]
	var qb: Array = _res["q_behinds"]
	for side in range(2):
		var block := UiKit.vbox(2)
		var head := UiKit.hbox(6)
		head.add_child(UiKit.club_badge(codes[side], 13, true, true))
		head.add_child(UiKit.line(UiKit.scoreline(int(_res["goals"][side]),
				int(_res["behinds"][side])), 15, UiKit.EMPH, true))
		block.add_child(head)
		var parts: PackedStringArray = []
		for i in range(qg.size()):
			parts.append("%s %d.%d" % [_period_label(i), int(qg[i][side]), int(qb[i][side])])
		block.add_child(UiKit.ellipsis("   ".join(parts), 12, UiKit.MUTED))
		v.add_child(block)
	return v


func _period_label(i: int) -> String:
	return "ET" if i >= 4 else "Q%d" % (i + 1)


func _qcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Pressure leads the comparison: how much each side applied, how well
## (MatchSim.pressure_rating), and the tackles among it.
const PRESSURE_ROWS := [
	["pressure_acts", "Pressure acts"], ["pressure_rating", "Pressure rating"],
	["tackles", "Tackles"],
]
const TEAM_STAT_ROWS := [
	["disposals", "Disposals"], ["kicks", "Kicks"], ["handballs", "Handballs"],
	["marks", "Marks"], ["inside50", "Inside 50s"],
	["rebounds", "Rebound 50s"], ["clearances", "Clearances"],
	["hitouts", "Hit-outs"], ["one_percenters", "One percenters"],
	["frees_for", "Frees for"], ["frees_against", "Frees against"],
	["clangers", "Clangers"], ["chains", "Possession chains"],
]


func _team_stats_table() -> Control:
	var v := UiKit.vbox(2)
	var h0 := UiKit.hbox(4)
	v.add_child(h0)
	h0.add_child(_qcell(str(_res["home"]), 44, UiKit.TEXT, 12, true))
	var gap := UiKit.line("", 12, UiKit.MUTED)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.add_child(gap)
	h0.add_child(_qcell(str(_res["away"]), 44, UiKit.TEXT, 12, true))
	var t: Array = _res["team"]
	var pressure := UiKit.vbox(2)
	pressure.name = "TeamPressure"
	v.add_child(pressure)
	for row in PRESSURE_ROWS:
		var a: int
		var b: int
		if str(row[0]) == "pressure_rating":
			a = MatchSim.pressure_rating(t[0], t[1])
			b = MatchSim.pressure_rating(t[1], t[0])
		else:
			a = int(float(t[0].get(row[0], 0.0)))
			b = int(float(t[1].get(row[0], 0.0)))
		pressure.add_child(_team_row(str(row[1]), a, b))
	v.add_child(UiKit.spacer(6))
	for row in TEAM_STAT_ROWS:
		v.add_child(_team_row(str(row[1]), int(float(t[0].get(row[0], 0.0))),
				int(float(t[1].get(row[0], 0.0)))))
	return v


func _team_row(label: String, a: int, b: int) -> Control:
	var h := UiKit.hbox(4)
	# The bigger number in bold: more is not always better (clangers,
	# frees against), so no good/bad colour here.
	h.add_child(_qcell(str(a), 44, UiKit.TEXT, 12, a > b))
	var lab := UiKit.ellipsis(label, 12, UiKit.MUTED)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lab)
	h.add_child(_qcell(str(b), 44, UiKit.TEXT, 12, b > a))
	return h


func _lcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.ellipsis(text, fs, col, bold)
	if w > 0:
		l.custom_minimum_size = Vector2(w, 0)
	return l


## Router back hook. A live match cannot be abandoned half way (the rest of
## the round is already on the ladder), so back is swallowed until full time.
func handle_back() -> bool:
	# A player list opened from the break closes first.
	if _sheet_overlay != null and is_instance_valid(_sheet_overlay):
		_close_sheet()
		return true
	# An open report closes first, live or at full time.
	if _report_overlay != null and is_instance_valid(_report_overlay):
		_close_report()
		return true
	# In the full-time review, Stats and Report go back to Summary.
	if _fulltime_shown and _ft_tab != "summary" and not _ft_box.is_empty() \
			and is_instance_valid(_ft_box["overlay"]):
		_ft_tab = "summary"
		_render_ft()
		return true
	if _interactive and not _finished:
		_feed_hint("Finish the match first - use Skip to full time to jump ahead.")
		return true
	return false


func _feed_hint(text: String) -> void:
	_feed_text(text, UiKit.MUTED, false, "Hint")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _pitch != null and is_inside_tree():
		if not _reflow_queued:
			_reflow_queued = true
			_reflow.call_deferred()
	elif what == NOTIFICATION_EXIT_TREE and _pitch != null:
		_pitch.pause()


func _reflow() -> void:
	_reflow_queued = false
	if not is_inside_tree() or _pitch == null or _root == null or _body == null:
		return
	if _margin != null:
		UiKit.apply_insets(_margin, 10)
	var stack := UiKit.view_width(self) < 640.0
	if stack != _stacked:
		_body.remove_child(_pitch)
		_body.remove_child(_side_panel)
		var idx := _body.get_index()
		_root.remove_child(_body)
		_body.queue_free()
		_mount_body(stack)
		_root.add_child(_body)
		_root.move_child(_body, idx)
	else:
		_fit_side_panel()
	var old := _root.get_child(0)
	_root.remove_child(old)
	old.queue_free()
	var board := _scoreboard()
	_root.add_child(board)
	_root.move_child(board, 0)
	_paint_scoreboard()



# ---------------------------------------------------------------------------
# Key match-ups (Matchups): the named forward-50 contests
# ---------------------------------------------------------------------------
## At a break: their key forwards and who is on them - with last quarter's
## contests and a tap to change - then yours against their defenders.
func _matchups_view(sim: MatchSim, q: int) -> Control:
	var theirs: Dictionary = sim.duels[_my_side]
	var ours: Dictionary = sim.duels[1 - _my_side]
	if theirs.is_empty() and ours.is_empty():
		return null
	var v := UiKit.vbox(4)
	v.name = "BreakMatchups"
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.lbl("Key match-ups", UiKit.BODY, UiKit.TEXT, true))
	for fid in theirs.keys():
		var row := UiKit.hbox(8)
		row.name = "BreakMatchup_" + str(fid)
		var l := UiKit.lbl(_matchup_text(str(fid), str(theirs[fid]), q), UiKit.BODY, UiKit.TEXT)
		l.name = "MatchupLine"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UiKit.btn("Change", 14)
		b.name = "ChangeMatchup"
		b.custom_minimum_size = Vector2(96, 44)
		var f := str(fid)
		b.pressed.connect(func(): _show_break_matchup(sim, f, l, q))
		row.add_child(b)
		v.add_child(row)
	for fid in ours.keys():
		var l2 := UiKit.lbl("Yours: " + _matchup_text(str(fid), str(ours[fid]), q), UiKit.SMALL, UiKit.MUTED)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	return v


func _matchup_text(fid: String, did: String, q: int) -> String:
	if q <= 1:
		return "%s: %s on him." % [MatchNotes._pname(fid), MatchNotes._pname(did)]
	return MatchNotes.duel_quarter_line(_res, fid, did, q - 1)


## Who goes to their forward, from your defenders on the ground. The change
## is made in the engine at once and takes effect from the next bounce.
func _show_break_matchup(sim: MatchSim, fid: String, line: Label, q: int) -> void:
	if _matchup_overlay != null and is_instance_valid(_matchup_overlay):
		_matchup_overlay.queue_free()
	var box := UiKit.modal_box(self, 480.0, 0.0)
	_matchup_overlay = box["overlay"]
	_matchup_overlay.name = "MatchupChooser"
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	var fwd := sim._on_ground(1 - _my_side, fid)
	v.add_child(UiKit.lbl("Who goes to %s?" % MatchNotes._pname(fid), UiKit.H1, UiKit.TEXT, true))
	if not fwd.is_empty():
		v.add_child(UiKit.lbl(Matchups.describe(fwd), UiKit.SMALL, UiKit.MUTED))
	var cur := str((sim.duels[_my_side] as Dictionary).get(fid, ""))
	for p in Matchups.defenders((sim.squads[_my_side] as Squad).ground):
		var b := UiKit.btn("%s\n%s" % [GameDB.player_display_name(p), Matchups.describe(p)], 15)
		b.name = "Defender_" + str(p["id"])
		b.custom_minimum_size = Vector2(0, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.paint_choice(b, str(p["id"]) == cur)
		var pid := str(p["id"])
		b.pressed.connect(func():
			sim.set_matchup(_my_side, fid, pid)
			line.text = _matchup_text(fid, pid, 1).trim_suffix(".") + " from the next bounce."
			_matchup_overlay.queue_free()
			_matchup_overlay = null)
		v.add_child(b)
	var close := UiKit.btn("Close", 16)
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func():
		_matchup_overlay.queue_free()
		_matchup_overlay = null)
	box["footer"].add_child(close)


## Injuries and the odd turning point in the feed (MatchNotes.story_feed_line).
func _story_feed(ev: Dictionary) -> void:
	var text := MatchNotes.story_feed_line(_duel_mem, ev)
	if text != "":
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), text],
				UiKit.TEXT, false, "StoryLine")


## The battle in the feed, rarely (MatchNotes.duel_feed_line).
func _duel_feed(ev: Dictionary) -> void:
	var text := MatchNotes.duel_feed_line(_duel_mem, ev)
	if text != "":
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), text],
				UiKit.TEXT, false, "DuelLine")
