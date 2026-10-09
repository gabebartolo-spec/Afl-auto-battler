extends Control
## Live match view: scoreboard, the animated oval, a commentary feed and
## playback controls. Your own match (home-and-away or final) is simulated a
## quarter at a time around the coach box; any other result is a replay of
## the event log GameState.advance() recorded.

const FEED_LIMIT := 60
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
## Routine play drives the animation but would drown the feed; the feed
## keeps what MatchNotes.FEED_KINDS names (goals, behinds, breaks, calls).
const QUIET_KINDS := ["kick", "handball", "sub", "ballup", "throwin", "mark", "tackle", "smother", "spoil", "pressure", "inside50",
		"rebound", "clanger", "free", "fifty", "last_disposal", "out_on_full"]
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
var _crowd: CrowdSound = null    # FL-004: the crowd (presentation only)
var _fulltime_shown := false
var _coach_overlay: Control
var _sheet_overlay: Control
var _reflow_queued := false
var _shown_goals := [0, 0]
var _shown_behinds := [0, 0]
var _shown_q := 1
var _shown_min := 0
var _moment_overlay: Control
## Broadcast vignettes sit over the live oval and never touch MatchSim. They
## are deliberately sparse: at most three ordinary close-ups per watched
## match, with the final-kick set shot allowed as a separate special beat.
var _broadcast_overlay: Control
var _broadcast_pending := false
var _broadcast_busy := false
var _broadcast_finish_waiting := false
var _broadcast_seen := {}
var _broadcast_count := 0
var _broadcast_speccies := 0
var _broadcast_last_event := -1000
var _playback_event_index := 0
var _momentum := 0.0            # the engine's momentum as shown: -1 (away on top) .. 1 (home on top)
var _mom_meter: Control       # MomentumMeter: draws the engine's momentum
var _mom_word: Label          # who has it, in words
var _mom_note: Label          # first match only: what it is
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
	# The ground the vignettes draw: the MCG has its own stands (FL-003); every other
	# venue keeps the plain ground. Set every match, as the static outlives the scene.
	VignetteGround.use_match(_res)
	_crowd = CrowdSound.new()
	_crowd.name = "Crowd"
	add_child(_crowd)
	_build()
	_pitch.setup(_res)
	_refresh_rings()
	# Whose first AFL goal the feed can say, if it comes today (MatchNotes).
	if _interactive:
		_duel_mem["first_goal"] = GameState.first_goal_candidates()
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
		# A phone follows the ball close up because its screen is small; a PC
		# shows the whole ground (director, 2026-10-09).
		_pitch.camera_enabled = not ScreenLayout.is_desktop()
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
		# Every call in full: a long name or several calls wrap, never trim.
		_setup_line = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
		_setup_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Both clubs' colours behind the score (director, 2026-10-08: not boring).
	var v := UiKit.vbox(4)
	var p := ClubDuel.band(str(_res["home"]), str(_res["away"]), v, 8, 0.35)
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
## Director, 2026-10-07: always labelled, the club on top named in words and
## its colour growing from the centre toward it (one colour at a time, so
## like colours cannot confuse it); a tap explains it, and the first match
## you watch says so once, under it.
const MOMENTUM_EVEN := 0.12
const MOMENTUM_INFO := [
	"Momentum is the run of play. A goal swings it toward the side that kicked it, a behind a little; it fades as play goes on and halves at every break.",
	"The side on top wins a little more of the ball at centre bounces, stoppages and loose balls - a small edge, never a guarantee. A goal the other way turns it.",
]


func _momentum_bar() -> Control:
	var b := Button.new()
	b.name = "MomentumBar"
	b.flat = true
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(_show_momentum_info)
	var v := UiKit.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var h := UiKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiKit.line("Momentum", UiKit.SMALL, UiKit.MUTED)
	ClubDuel.on_colour(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)
	_mom_word = UiKit.ellipsis("", UiKit.SMALL, UiKit.TEXT, true)
	_mom_word.name = "MomentumWord"
	_mom_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mom_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_mom_word)
	v.add_child(h)
	_mom_meter = MomentumMeter.new()
	_mom_meter.call("setup", UiKit.score_colour(str(_res["home"])), UiKit.score_colour(str(_res["away"])))
	v.add_child(_mom_meter)
	var box := UiKit.vbox(2)
	box.add_child(b)
	_mom_note = UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	_mom_note.name = "MomentumNote"
	_mom_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mom_note.visible = false
	box.add_child(_mom_note)
	_paint_momentum()
	return box


func _paint_momentum() -> void:
	if _mom_meter == null or not is_instance_valid(_mom_meter):
		return
	_mom_meter.call("show_value", _momentum)
	if absf(_momentum) < MOMENTUM_EVEN:
		_mom_word.text = "Even"
		ClubDuel.on_colour(_mom_word)
	else:
		var code := str(_res["home"] if _momentum > 0.0 else _res["away"])
		_mom_word.text = "%s on top" % GameDB.club_short(code)
		ClubDuel.on_colour(_mom_word)
	# The first match you watch: once it first moves, one line says what it is.
	if _interactive and not _mom_note.visible and absf(_momentum) >= MOMENTUM_EVEN \
			and GameState.intro_due("momentum"):
		GameState.set_setting("seen_momentum_intro", true)
		_mom_note.text = "Momentum swings with each goal and fades with time; the side on top wins a little more of the ball. %s it for more." % ("Click" if ScreenLayout.is_desktop() else "Tap")
		_mom_note.visible = true


func _show_momentum_info() -> void:
	_close_sheet()
	var box := UiKit.modal_box(self, 520.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "MomentumInfo"
	_sheet_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Momentum", UiKit.TITLE))
	for line in MOMENTUM_INFO:
		var l := UiKit.lbl(line, UiKit.BODY, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var ok := UiKit.btn("Got it", UiKit.NAME, true)
	ok.name = "MomentumInfoOk"
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(_close_sheet)
	box["footer"].add_child(ok)


## A centre line; the club on top's colour grows from it toward his end, as
## far as the engine's momentum (-1 away .. 1 home).
class MomentumMeter extends Control:
	var _home := Color.WHITE
	var _away := Color.WHITE
	var _v := 0.0

	func setup(home: Color, away: Color) -> void:
		_home = home
		_away = away
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_value(v: float) -> void:
		_v = v
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var mid := w / 2.0
		var y := size.y / 2.0
		draw_rect(Rect2(0, y - 1.0, w, 2.0), UiKit.LINE)
		var reach := mid * clampf(absf(_v), 0.0, 1.0)
		if reach >= 1.0:
			if _v > 0.0:
				draw_rect(Rect2(mid - reach, 0, reach, size.y), _home)
			else:
				draw_rect(Rect2(mid, 0, reach, size.y), _away)
		draw_rect(Rect2(mid - 1.0, 0, 2.0, size.y), UiKit.TEXT)


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
	var name := UiKit.ellipsis(name_text, UiKit.SECONDARY if narrow else 16, UiKit.TEXT, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	ClubDuel.on_colour(name)
	v.add_child(name)
	var score := UiKit.figure("0.0 (0)", 30 if narrow else 36, Color.WHITE)
	ClubDuel.on_colour(score)
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
	ClubDuel.on_colour(_clock)
	mid.add_child(_clock)
	_lead = UiKit.ellipsis("", UiKit.SMALL, UiKit.MUTED)
	_lead.name = "LeadLine"
	_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ClubDuel.on_colour(_lead)
	mid.add_child(_lead)
	return mid


## A final names its venue (the Grand Final is always at the MCG); any
## other match is at the home club's ground.
func _venue() -> String:
	return VignetteGround.ground_of(_res)


func _controls() -> Control:
	var v := UiKit.vbox(6)

	var row := UiKit.hbox(5)
	v.add_child(row)
	_play_btn = UiKit.btn("Pause", UiKit.SECONDARY)
	_play_btn.custom_minimum_size = Vector2(0, 40)
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.clip_text = true
	_play_btn.pressed.connect(_on_toggle)
	row.add_child(_play_btn)

	for s in SPEEDS:
		var b := UiKit.btn("%dx" % int(s), UiKit.SECONDARY)
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_on_speed.bind(s))
		_speed_btns.append(b)
		row.add_child(b)

	var row2 := UiKit.hbox(5)
	v.add_child(row2)
	var skip := UiKit.btn("Skip to full time", UiKit.SECONDARY)
	skip.custom_minimum_size = Vector2(0, 40)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_on_skip)
	row2.add_child(skip)

	# Your own match cannot be left half way (Back says so); a replay can.
	if not _interactive:
		var leave := UiKit.btn("Back to hub", UiKit.SECONDARY)
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
	# On a PC the break is a wide landscape sheet with every call in view
	# (director, 2026-10-09: "it looks like we are using a mobile UI on a PC").
	var wide := _wide_break()
	var box := UiKit.modal_box(self, minf(UiKit.view_width(self) - 48.0, 1560.0) if wide else 640.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "CoachBox"
	_coach_overlay = overlay
	var v: VBoxContainer = box["body"]
	var titles := {1: "Before the first ball-up", 2: "Quarter time", 3: "Half time", 4: "Three-quarter time"}
	# The break leads with both clubs' colours (director, 2026-10-08).
	var bv := UiKit.vbox(2)
	var band := ClubDuel.band(str(_res["home"]), str(_res["away"]), bv, 14)
	band.name = "BreakBand"
	v.add_child(band)
	# Wide: the quarter just played, then the calls in two columns. A phone
	# keeps one column, every call in it.
	# Below 1100 units the quarter just played sits above two columns.
	var rep: VBoxContainer = v
	var col_a: VBoxContainer = v
	var col_b: VBoxContainer = v
	var cols: HBoxContainer = null
	if wide:
		var three := q > 1 and UiKit.view_width(self) >= 1100.0
		cols = HBoxContainer.new()
		cols.name = "BreakColumns"
		cols.add_theme_constant_override("separation", 32)
		col_a = UiKit.vbox(8)
		col_b = UiKit.vbox(8)
		if three:
			rep = UiKit.vbox(8)
			v.add_child(cols)
		for c in ([rep, col_a, col_b] if three else [col_a, col_b]):
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			cols.add_child(c)
	var title := UiKit.heading(str(titles.get(q, "Quarter %d" % q)), UiKit.H1)
	title.name = "BreakTitle"
	ClubDuel.on_colour(title)
	bv.add_child(title)
	if q == 1:
		var where := UiKit.ellipsis("%s  ·  %s v %s  ·  %s" % [str(_res.get("label", "Match")),
				GameDB.club_short(str(_res["home"])), GameDB.club_short(str(_res["away"])), _venue()], UiKit.BODY, UiKit.TEXT, true)
		ClubDuel.on_colour(where)
		bv.add_child(where)
	else:
		var sc := UiKit.lbl(MatchNotes.break_score(str(_res["home"]), str(_res["away"]),
				_res.get("goals", [0, 0]), _res.get("behinds", [0, 0])), UiKit.NAME, UiKit.TEXT, true)
		sc.name = "BreakScore"
		sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ClubDuel.on_colour(sc)
		bv.add_child(sc)
		# The full numbers, both clubs, at every break (director's PC
		# playtest, 2026-10-07): a tap, never a compulsory report.
		var stats := UiKit.btn("Match stats", UiKit.BODY)
		stats.name = "BreakStats"
		stats.custom_minimum_size = Vector2(0, 44)
		stats.pressed.connect(_show_break_stats)
		rep.add_child(stats)
		rep.add_child(UiKit.spacer(UiKit.GAP))
		# The quarter just played, by name: what happened, not what is happening.
		var played := UiKit.section(str({2: "First quarter", 3: "Second quarter",
				4: "Third quarter"}.get(q, "Last quarter")))
		played.name = "QuarterHeading"
		rep.add_child(played)
		rep.add_child(_quarter_view(q - 1))
		var did := MatchNotes.calls_lines(_res, _my_side, q - 1) \
				+ MatchNotes.duel_change_lines(_res, _my_side, q - 1) \
				+ MatchNotes.tag_drop_lines(_res, _my_side, q - 1) \
				+ MatchNotes.lasting_moment_lines(_res, q - 1)
		if not did.is_empty():
			rep.add_child(UiKit.spacer(UiKit.GAP))
			rep.add_child(UiKit.section("What your calls did"))
			var dv := UiKit.vbox(4)
			dv.name = "CallsDid"
			for t in did:
				var dl := UiKit.lbl(str(t), UiKit.BODY, UiKit.TEXT)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dv.add_child(dl)
			rep.add_child(dv)
	rep.add_child(UiKit.spacer(UiKit.GAP))
	if cols != null and cols.get_parent() == null:
		v.add_child(cols)
	col_a.add_child(UiKit.section("Your calls" if q == 1 else "Next quarter"))

	# Your calls, as taps: nothing here is a settings form. Short lists sit
	# in plain view; a player list shows the few in the game so far and
	# keeps everyone else one tap away.
	# The plan in force is the engine's: your club plan before the first
	# bounce (GameState.prepare_interactive_match), your last call after.
	var calls := {
		"gameplan": _current_plan(sim),
		"tag_id": str((sim.tactics[_my_side] as Dictionary).get("tag_id", _last_tactics.get("tag_id", ""))),
		"focus_id": str(_last_tactics.get("focus_id", "")),
		"interceptor_id": str(sim.interceptor[_my_side]),
		"minder_id": str((sim.tactics[_my_side] as Dictionary).get("spare_minder_id", "")) 				if bool((sim.tactics[_my_side] as Dictionary).get("spare_accountable", false)) else "",
		"pep": "steady",
		"rotation": _rotation,
	}
	var loose_was := str(calls["interceptor_id"])
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
	col_a.add_child(_call_block("Gameplan", plan))
	col_a.add_child(plan_note)
	sync_note.call(str(calls["gameplan"]))

	# Tag: their most influential so far first, anyone on the ground a tap away.
	# A tag is a midfield job: only their midfielders can be tagged.
	# Only players still in the match: the roster keeps anyone hurt and gone.
	var opp := _roster_side(1 - _my_side).filter(func(r): return _taggable_now(sim, r))
	# Who goes to him - a fact, not advice (Roles: a tagger makes a tag bite
	# harder than a midfielder doing the job). With no tag, say that instead.
	var tagger = MatchSim.tagger_for(my_ground)
	var tag_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	tag_note.name = "TagNote"
	tag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_tag := func(key: String) -> void:
		if key == "":
			tag_note.text = "No tag: your midfielders play their own game."
		elif tagger == null:
			tag_note.text = "No midfielder on the ground to tag with."
		else:
			tag_note.text = ("%s, your tagger, goes to him." if Roles.is_tagger(tagger)
					else "No specialist tagger on the ground: %s goes to him and gives up his own game.") % GameDB.player_display_name(tagger)
	var tag := _player_choice("TagPicker", "No tag", opp, _in_the_game(opp, 4), calls, "tag_id",
			"Tag which midfielder?", sync_tag)
	col_a.add_child(_call_block("Tag", tag))
	sync_tag.call(str(calls["tag_id"]))
	col_a.add_child(tag_note)

	# Key match-ups: who is on their key forwards, how the contests went last
	# quarter, and yours against their defenders. Change one in a tap.
	# In three columns they sit under the quarter just played, so no column
	# stands half empty (director, 2026-10-10).
	var mv := _matchups_view(sim, q)
	if mv != null:
		(rep if rep != v else col_a).add_child(mv)
	# Their loose defender, answered by a person: one of your forwards goes up
	# the ground with him. Facts only - who is a Defensive forward shows on
	# his name; the choice is yours.
	var opp_spare := sim._roaming_interceptor(1 - _my_side)
	if not opp_spare.is_empty():
		var fwds := Matchups.minder_candidates(my_ground)
		var minder := _player_choice("SpareMinderPicker", "Nobody", fwds, fwds.slice(0, mini(3, fwds.size())),
				calls, "minder_id", "Who goes to him?")
		col_a.add_child(_call_block("Their loose defender", minder))
		var dfs := fwds.filter(func(p): return Traits.has(p, "def_forward")).map(func(p): return GameDB.player_display_name(p))
		var who := ("Defensive forwards on the ground: %s." % ", ".join(dfs)) if not dfs.is_empty() 				else "No Defensive forward on the ground."
		var minder_note := UiKit.lbl(
				"%s is roaming behind the ball. The forward you send goes up the ground with him: he keeps him out of contests, a Defensive forward best, and stops being a target himself. %s" % [
						GameDB.player_display_name(opp_spare), who],
				UiKit.SMALL, UiKit.MUTED)
		minder_note.name = "MinderNote"
		minder_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col_a.add_child(minder_note)

	# The rest of the calls, all in view (director, 2026-10-09: no "More
	# calls" button).
	var more: VBoxContainer = col_b
	var syn_line := _synergy_line()
	if syn_line != "":
		var sl := UiKit.lbl(syn_line, UiKit.SMALL, UiKit.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.add_child(sl)

	var mine := _roster_side(_my_side)

	# Structural defence: one real defender can roam as the spare. Picking him
	# releases him from a direct opponent; the engine reallocates that matchup.
	var def_ground: Array = []
	for p in my_ground:
		if str(p.get("role", "")) == "DEF":
			def_ground.append(p)
	var interceptors := Matchups.interceptor_candidates(def_ground)
	var roam_first: Array = interceptors.slice(0, mini(3, interceptors.size()))
	var roam := _player_choice("InterceptorPicker", "No loose defender", def_ground, roam_first,
			calls, "interceptor_id", "Who roams behind the ball?")
	more.add_child(_call_block("Loose interceptor", roam))
	var roam_note := UiKit.lbl(
			"He leaves his direct man to attack aerial balls. Another defender covers where possible; if he flies and loses, space opens behind him.",
			UiKit.SMALL, UiKit.MUTED)
	roam_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.add_child(roam_note)

	var focus_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	focus_note.name = "FocusNote"
	focus_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_focus := func(id: String) -> void:
		focus_note.text = _focus_note_text(id)
	var focus := _player_choice("FocusPicker", "No one", mine, _in_the_game(mine, 4), calls, "focus_id",
			"Play through which player?", sync_focus)
	var focus_block := _call_block("Play through", focus)
	sync_focus.call(str(calls["focus_id"]))
	focus_block.add_child(focus_note)
	more.add_child(focus_block)

	# Three columns: pep talk and rotations sit under the tag, so the columns
	# end level and the whole sheet fits a 720-unit screen.
	var tail: VBoxContainer = col_a if rep != v else more
	var pep_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	pep_note.name = "PepNote"
	pep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_pep := func(key: String) -> void:
		pep_note.text = CoachReport.pep_summary(key)
	var pep := _choice_grid("PepPicker", PEP_SHORT, calls, "pep", 3, sync_pep)
	tail.add_child(_call_block("Pep talk", pep))
	tail.add_child(pep_note)
	sync_pep.call("steady")

	var rot_opts := []
	for k in MatchSim.ROTATION_POLICIES:
		rot_opts.append([str(k), str(ROTATION_SHORT.get(k, MatchSim.ROTATION_POLICIES[k]["label"]))])
	var rot_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	rot_note.name = "RotationNote"
	rot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sync_rot := func(key: String) -> void:
		rot_note.text = str(MatchSim.ROTATION_POLICIES[key]["text"])
	var rot := _choice_grid("RotationPicker", rot_opts, calls, "rotation", 3, sync_rot)
	tail.add_child(_call_block("Rotations", rot))
	tail.add_child(rot_note)
	sync_rot.call(_rotation)
	(rep if rep != v else tail).add_child(_legs_view())

	var start := UiKit.btn("Start quarter" if q > 1 else "Ball it up", UiKit.HEADING, true)
	start.name = "StartQuarter"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func():
		_rotation = str(calls["rotation"])
		var t := {
			"gameplan": str(calls["gameplan"]),
			"focus_id": str(calls["focus_id"]),
			"tag_id": str(calls["tag_id"]),
			"interceptor_id": str(calls["interceptor_id"]),
			"interceptor_set": str(calls["interceptor_id"]) != loose_was,
			"spare_accountable": str(calls["minder_id"]) != "",
			"spare_minder_id": str(calls["minder_id"]),
			"pep": str(calls["pep"]),
			"rotation": _rotation,
		}
		_close_coach()
		_simulate_next_quarter(t))
	var skip := UiKit.btn("Skip to full time", UiKit.BODY)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(_on_skip)
	if wide:
		# A PC sheet's actions sit together at the right, not as full-width bars.
		var acts := UiKit.hbox(12)
		acts.alignment = BoxContainer.ALIGNMENT_END
		skip.custom_minimum_size = Vector2(220, 48)
		start.custom_minimum_size = Vector2(300, 48)
		acts.add_child(skip)
		acts.add_child(start)
		box["footer"].add_child(acts)
	else:
		box["footer"].add_child(start)
		box["footer"].add_child(skip)


## A landscape PC window wide enough for the break sheet's columns (the
## Large and TV screen sizes included).
func _wide_break() -> bool:
	var w := UiKit.view_width(self)
	return ScreenLayout.is_desktop() and w >= 760.0 and w > UiKit.view_height(self) * 1.2


## The quarter just played: what stood out, what they ran, how your calls
## and your tag came off. Facts only.
func _quarter_view(q: int) -> Control:
	var v := UiKit.vbox(4)
	v.name = "QuarterFacts"
	# The few things that stood out, readable in a glance: no more than
	# three, their plan kept (it is what the next quarter's calls answer).
	# Moments already played out in the feed are not replayed here; the
	# ones that carry on are under "What your calls did".
	var lines: Array = MatchNotes.quarter_facts(_res, _my_side, q, _break_answers())
	var opp_last := _opp_last_plan()
	if opp_last != "":
		lines = lines.slice(0, MatchNotes.MAX_FACTS - 1)
		lines.append("They played a balanced game." if opp_last == "balanced"
				else "They played %s." % CoachReport.plan_label(opp_last))
	if lines.is_empty():
		lines.append("An even quarter.")
	for t in lines:
		var l := UiKit.lbl(str(t), UiKit.BODY, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


## What a call can do about each of their players now: the defender on a key
## forward, your tag, or a midfielder you could tag (only with a midfielder
## of yours on the ground to send). Facts for the break, never advice.
func _break_answers() -> Dictionary:
	var out := {}
	var sim: MatchSim = GameState.pending_sim
	if sim == null:
		return out
	var tagger = MatchSim.tagger_for((sim.squads[_my_side] as Squad).ground)
	if tagger != null:
		var tag_id := str((sim.tactics[_my_side] as Dictionary).get("tag_id", ""))
		for r in _roster_side(1 - _my_side):
			if not _taggable_now(sim, r):
				continue
			var id := str(r["id"])
			out[id] = {"kind": "tagged", "who": GameDB.player_display_name(tagger)} if id == tag_id 					else {"kind": "tag"}
	var theirs: Dictionary = sim.duels[_my_side]
	for fid in theirs:
		out[str(fid)] = {"kind": "matchup", "who": MatchNotes._pname(str(theirs[fid]))}
	return out


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
		var name_l := UiKit.ellipsis(str(l["label"]), UiKit.SECONDARY, UiKit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(UiKit.line("%+.1f pts" % pts, UiKit.SECONDARY, UiKit.GOOD if pts > 0 else UiKit.BAD, true))
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
	var bounce := str(m.get("kind", "")) == "bounce"
	if bounce and GameState.vignettes_on():
		_show_bounce_moment(m)
		return
	# Sized for its few lines, not the whole phone.
	var box := UiKit.modal_box(self, 560.0, 440.0, _wash())
	_moment_overlay = box["overlay"]
	_moment_overlay.name = "MomentCard"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Coach's call  ·  %s" % _clock_text(int(m.get("q", 1)), int(m.get("min", 0))),
			UiKit.SMALL, UiKit.MUTED))
	var title := UiKit.lbl(str(m.get("title", "")), 20, UiKit.EMPH, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	if bounce:
		# Vignettes off: the centre ball-up call without its scene, the same
		# facts the scene would have put over it.
		for f in StoppageVignette.call_facts(GameState.pending_sim, _my_side):
			var fl := UiKit.lbl(str(f), UiKit.BODY, UiKit.TEXT, true)
			fl.name = "BounceFact"
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(fl)
	var text := UiKit.lbl(str(m.get("text", "")), 14, UiKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	var options: Array = m.get("options", [])
	for i in range(options.size()):
		var o: Dictionary = options[i]
		# Every choice stands equal: no filled first button that reads as the
		# recommended one (director's PC playtest, 2026-10-07).
		var b := UiKit.btn(str(o.get("label", "")), 16, false)
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
		# Every choice stands equal: no filled first button that reads as the
		# recommended one (director's PC playtest, 2026-10-07).
		var b := UiKit.btn(str(o.get("label", "")), 16, false)
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
## and "Other player..." for everyone in `roster` (the caller's choice: the
## whole side for a tag, only forwards for their loose defender). Nobody in
## it is left out; the list is just ordered.
func _player_choice(node_name: String, none_label: String, roster: Array, first: Array,
		calls: Dictionary, field: String, sheet_title: String, on_change: Callable = Callable()) -> Control:
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
		var grid := _choice_grid(node_name + "Grid", shown, calls, field, 2, on_change)
		box.add_child(grid)
		var other := UiKit.btn("Other player…", 14)
		other.name = node_name + "Other"
		other.custom_minimum_size = Vector2(0, 44)
		other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other.pressed.connect(func():
			_player_sheet(sheet_title, roster, str(calls[field]), func(id: String):
				calls[field] = id
				if on_change.is_valid():
					on_change.call(id)
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
	var box := UiKit.modal_box(self, 480.0, 0.0, _wash())
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
	var close := UiKit.btn("Close", UiKit.NAME)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_sheet)
	box["footer"].add_child(close)


## Match-day sheets wash in the opponent's colour (director, 2026-10-08);
## a match you are not in keeps the usual wash.
func _wash() -> Color:
	var mine := str(GameState.my_club)
	var home := str(_res.get("home", ""))
	var away := str(_res.get("away", ""))
	if mine == home:
		return UiKit.opponent_wash(away)
	if mine == away:
		return UiKit.opponent_wash(home)
	return UiKit.AUTO_COLOUR


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


## Their midfielders only, by where each plays now (the roster copy carries
## the slot but not the position, so the sim's live copy decides).
func _taggable_now(sim: MatchSim, r: Dictionary) -> bool:
	return sim.tag_target_ok(1 - _my_side, str(r["id"]))


func _roster_side(side: int) -> Array:
	var roster: Array = _res.get("roster", [[], []])
	if roster.size() <= side:
		return []
	var out: Array = roster[side].duplicate()
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return out


# ---------------------------------------------------------------------------
# Match stats at a break
# ---------------------------------------------------------------------------
## The match so far in full, over the break: team and player stats for both
## clubs, any quarter on its own. Close (or Back) returns to your calls.
func _show_break_stats() -> void:
	_close_report()
	var box := UiKit.modal_box(self, 1100.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "BreakStatsSheet"
	_report_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis("Match stats", UiKit.H1, UiKit.TEXT, true))
	var box_score := BoxScore.new().setup(_res, true)
	box_score.name = "BreakBoxScore"
	v.add_child(box_score)
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(MatchStatsView.new().setup(_res, _my_side, true))
	var close := UiKit.btn("Back to your calls", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_report)
	box["footer"].add_child(close)


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
	# Your calls are in force from here, so the rings are up for the bounce.
	_refresh_rings()
	_pitch.play()
	_sync_controls()


func _apply_quarter_tactics(t: Dictionary) -> void:
	var sim: MatchSim = GameState.pending_sim
	# A loose defender you picked yourself stays your call; one left as the
	# assistant set it stays his to change at the breaks.
	if bool(t.get("interceptor_set", false)):
		sim.coach_interceptor(_my_side, str(t.get("interceptor_id", "")))
	sim.set_tactics(_my_side, t)
	sim.set_rotation_policy(_my_side, str(t.get("rotation", _rotation)))
	# The rival coach plays its usual game, protects a lead, chases a
	# deficit, and tags your best midfielder after half time.
	sim.set_tactics(1 - _my_side, sim.ai_tactics(1 - _my_side))


## The player you play through, with his job this match: the slot he fills on
## the ground (or filled last, off it) - "Matthew Jefferson our key forward target".
func _focus_player(id: String) -> Dictionary:
	var sim: MatchSim = GameState.pending_sim
	if sim != null:
		var sq: Squad = sim.squads[_my_side]
		for p in sq.ground + sq.bench:
			if str(p["id"]) == id:
				return p
	for r in _roster_side(_my_side):
		if str(r["id"]) == id:
			return r
	return {}


func _focus_text(id: String) -> String:
	var p := _focus_player(id)
	return MatchNotes.focus_role_text(GameDB.player_display_name_by_id(id, "your player"), str(p.get("role", "")))


## Under the Play through control: his job and what it does for him; the
## general description with nobody picked.
func _focus_note_text(id: String) -> String:
	if id == "":
		return "Favour this player in possession chains and attacking transition."
	var p := _focus_player(id)
	# A sentence: "Jacob van Rooyen is our key forward target: ...".
	var role := str(p.get("role", ""))
	var who := GameDB.player_display_name_by_id(id, "your player")
	var job := str(MatchNotes.FOCUS_ROLES[role][0]) if MatchNotes.FOCUS_ROLES.has(role) else "the one we play through"
	return "%s is %s: %s." % [who, job, MatchNotes.focus_effect_text(role)]


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
		bits.append(_focus_text(focus_id))
	var intercept_id := str(t.get("interceptor_id", ""))
	if intercept_id != "":
		bits.append(GameDB.player_display_name_by_id(intercept_id, "your defender") + " loose behind the ball")
	if bool(t.get("spare_accountable", false)):
		# Whoever is on him now: the named forward, or his stand-in if he's off.
		var sim_now = GameState.pending_sim
		var on_him: Dictionary = sim_now._spare_minder(_my_side) if sim_now != null else {}
		var who := GameDB.player_display_name(on_him) if not on_him.is_empty() 				else GameDB.player_display_name_by_id(str(t.get("spare_minder_id", "")), "a forward")
		bits.append(who + " on their spare")
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
		_pitch.append_events(new_events, _res.get("timeline", []))


# ---------------------------------------------------------------------------
# Playback hooks
# ---------------------------------------------------------------------------
## The ring on the oval: the players of yours you have made a call on or
## promised a run (MatchRings). Calls change at the breaks and at the moments,
## so it is read again with every event: a few lookups, and the view only
## redraws when the set moved. Only a match you coach has calls to show.
func _refresh_rings() -> void:
	if _pitch == null:
		return
	if _interactive and GameState.pending_sim != null:
		_pitch.set_rings(MatchRings.ids(GameState.pending_sim, _my_side, GameState.my_list,
				GameState.my_matchups))
	else:
		_pitch.set_rings([])


func _on_event(ev: Dictionary) -> void:
	var event_index := _playback_event_index
	_playback_event_index += 1
	_refresh_rings()
	_update_scoreboard(ev)
	_track_momentum(ev)
	_feed_add(ev)
	_duel_feed(ev)
	_story_feed(ev)
	if str(ev.get("kind", "")) == "goal":
		_flash_score(int(ev.get("side", 0)))
		_track_run(int(ev.get("side", 0)))
	if _crowd != null and not _skipping:
		_crowd.event(str(ev.get("kind", "")))
	_queue_broadcast(ev, event_index)


## A vignette reads the positions the presentation has already staged. It
## cannot alter those positions, the event log, the score or any match RNG.
func _broadcast_snapshot(ev: Dictionary) -> Dictionary:
	if _pitch == null or _pitch.director == null:
		return {}
	var d: MatchDirector = _pitch.director
	var ball: Vector2 = d.ball.get("pos", Vector2.ZERO)
	var actor_pos := ball
	var actor_id := d.actor
	if actor_id >= 0 and actor_id < d.tokens.size():
		actor_pos = d.tokens[actor_id].get("pos", ball)
	var at: Vector2 = actor_pos if str(ev.get("kind", "")) == "mark" else ball
	var nearby := 0
	for token in d.tokens:
		if (token.get("pos", Vector2.ZERO) as Vector2).distance_to(at) <= 8.0:
			nearby += 1
	return {"actor_pos": actor_pos, "ball_pos": ball, "nearby": nearby}


## Trigger selection is deterministic and presentation-only. Categories are
## sparse, with enough football between them that a watched game does not
## become a highlights reel interrupting itself.
func _queue_broadcast(ev: Dictionary, event_index: int) -> void:
	if _skipping or _finished or _broadcast_pending or _broadcast_busy or _pitch == null:
		return
	# Vignettes off (Settings): no replays. They decide nothing.
	if not GameState.vignettes_on():
		return
	var prev_ev := {}
	var next_ev := {}
	if event_index > 0 and event_index - 1 < _pitch.events.size():
		prev_ev = _pitch.events[event_index - 1]
	if event_index + 1 < _pitch.events.size():
		next_ev = _pitch.events[event_index + 1]
	var snap := _broadcast_snapshot(ev)
	var kind := BroadcastVignette.pick_kind(ev, prev_ev, next_ev, snap)
	if kind == "":
		return
	var special := kind == BroadcastVignette.AFTER_SIREN
	var cat := BroadcastVignette.category(kind)
	if cat == "speccy":
		# MatchSim now owns whether the mark was actually spectacular and
		# enforces the 0/1/2 distribution. Presentation only guards the hard cap.
		if _broadcast_speccies >= 2:
			return
	elif _broadcast_seen.has(cat):
		return
	if not special and (_broadcast_count >= 3 or event_index - _broadcast_last_event < 70):
		return
	if cat == "speccy":
		_broadcast_speccies += 1
	else:
		_broadcast_seen[cat] = true
	if not special:
		_broadcast_count += 1
		_broadcast_last_event = event_index
	_broadcast_pending = true
	_pitch.pause()
	_show_broadcast.call_deferred(kind, ev.duplicate(true), snap)



func _show_broadcast(kind: String, ev: Dictionary, snap: Dictionary) -> void:
	if not _broadcast_pending or _finished:
		_broadcast_pending = false
		return
	_broadcast_pending = false
	_broadcast_busy = true
	var overlay := UiKit.cover(self)
	overlay.name = "BroadcastVignetteOverlay"
	overlay.color = Color(0.015, 0.018, 0.02, 1.0)
	_broadcast_overlay = overlay
	var vignette := BroadcastVignette.new()
	vignette.name = "BroadcastVignette"
	overlay.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.setup(kind, ev, snap, _res)
	vignette.finished.connect(_finish_broadcast)


func _finish_broadcast() -> void:
	if _broadcast_overlay != null and is_instance_valid(_broadcast_overlay):
		_broadcast_overlay.queue_free()
	_broadcast_overlay = null
	_broadcast_busy = false
	if _broadcast_finish_waiting:
		_broadcast_finish_waiting = false
		_on_finished()
		return
	if not _finished and _coach_overlay == null and _moment_overlay == null and _pitch != null:
		_pitch.play()
		_sync_controls()


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
	# A quarter/final can be released in the same PitchView frame as a close-up
	# candidate. Let the vignette finish before opening the next modal.
	if _broadcast_pending or _broadcast_busy:
		_broadcast_finish_waiting = true
		return
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
	if _crowd != null:
		_crowd.full_time()
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
	var box := UiKit.modal_box(self, 640.0, 0.0, _wash())
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
		var train := UiKit.btn("Training", UiKit.BODY)
		train.name = "FullTimeTraining"
		train.custom_minimum_size = Vector2(0, 44)
		train.pressed.connect(func():
			overlay.queue_free()
			Router.replace("training"))
		box["footer"].add_child(train)
	# The week is over: back to the hub, where next week starts.
	var leave := UiKit.btn("Continue", UiKit.HEADING, true)
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
				UiKit.SCORE, UiKit.TEXT if winner != 1 - side else UiKit.MUTED)
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
		# The people it was about: a debut, a first goal, a promised run done.
		# Said only when the facts kept on the players say it; otherwise silent.
		if _interactive or _review:
			var told := GameState.payoff_lines(_res)
			if not told.is_empty():
				v.add_child(UiKit.spacer(UiKit.GAP))
				var payoffs := UiKit.vbox(4)
				payoffs.name = "PayoffLines"
				for line in told:
					var pl := UiKit.lbl(str(line), UiKit.BODY, UiKit.TEXT)
					pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					payoffs.add_child(pl)
				v.add_child(payoffs)

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
		var matchup_lines: Array = MatchNotes.interceptor_story(_res, me) + MatchNotes.duel_story(_res, me)
		_glance_section(v, "Key match-ups", "FullTimeMatchups", matchup_lines.slice(0, 3))
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


## The Stats tab: the box score (BoxScore), then team and player stats a tab apart
## (MatchStatsView, the same view as at the breaks), and what your calls did.
func _ft_stats(v: VBoxContainer) -> void:
	var box := UiKit.vbox(8)
	box.name = "MatchStats"
	v.add_child(box)
	box.add_child(BoxScore.new().setup(_res))
	box.add_child(UiKit.spacer(UiKit.GAP))
	box.add_child(MatchStatsView.new().setup(_res, _my_side))
	if _interactive:
		box.add_child(UiKit.spacer(UiKit.GAP))
		box.add_child(_calls_view(0))


func _qcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var their_spare := sim._roaming_interceptor(1 - _my_side)
	if not their_spare.is_empty():
		var loose := UiKit.lbl("%s is roaming loose behind their backline." % GameDB.player_display_name(their_spare),
				UiKit.BODY, UiKit.TEXT)
		loose.name = "OppInterceptor"
		loose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(loose)
	var our_spare := sim._roaming_interceptor(_my_side)
	if not our_spare.is_empty():
		var loose2 := UiKit.lbl("Yours: %s is roaming as the spare." % GameDB.player_display_name(our_spare),
				UiKit.SMALL, UiKit.MUTED)
		loose2.name = "MyInterceptor"
		loose2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(loose2)
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
	# Who made these calls: your assistant, until you make them yourself.
	if sim.assistant_active(_my_side):
		var a := UiKit.lbl("Your assistant sets the match-ups and the spare. Change one and it stays your call.",
				UiKit.SMALL, UiKit.MUTED)
		a.name = "AssistantNote"
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(a)
	return v


func _matchup_text(fid: String, did: String, q: int) -> String:
	if q <= 1:
		return MatchNotes.matchup_line(MatchNotes._pname(fid), MatchNotes._pname(did))
	return MatchNotes.duel_quarter_line(_res, fid, did, q - 1)


## Who goes to their forward, from your defenders on the ground. The change
## is made in the engine at once and takes effect from the next bounce.
func _show_break_matchup(sim: MatchSim, fid: String, line: Label, q: int) -> void:
	if _matchup_overlay != null and is_instance_valid(_matchup_overlay):
		_matchup_overlay.queue_free()
	var box := UiKit.modal_box(self, 480.0, 0.0, _wash())
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
			sim.coach_matchup(_my_side, fid, pid)
			line.text = _matchup_text(fid, pid, 1).trim_suffix(".") + " from the next bounce."
			_matchup_overlay.queue_free()
			_matchup_overlay = null)
		v.add_child(b)
	var close := UiKit.btn("Close", UiKit.NAME)
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
