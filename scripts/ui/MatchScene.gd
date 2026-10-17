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
## FL-007: the milestone this match honours after the siren (GameState's banner
## milestone, read before full time counts the game), or {} for none.
var _farewell := {}
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
## The break is the PC sheet (four columns): player cards say their detail
## on one line and choices sit 40 tall (a mouse, not a thumb).
var _pc_break := false
var _pos_before := 0          # your ladder spot before this match
var _lead: Label
var _setup_line: RichTextLabel
var _report_overlay: Control
var _ft_box := {}               # the full-time review: overlay, body, footer
var _ft_tabs: HBoxContainer
var _ft_tab := "summary"        # summary (home), stats or report
var _run_side := -1            # who kicked the last goal, and how many in a row
var _run_len := 0
var _press_said := [false, false]  # the Defensive press line, once a side
var _name_index := {}           # name -> club for NameInk, built once per match
var _duel_mem := {}             # the feed's memory of the key match-ups (MatchNotes.duel_feed_line)
var _matchup_overlay: Control
var _break_refresh := Callable()   # the one-line break: say each call's answer again after a pick
var _break_sheets: Array = []      # the one-line break: open sheets, the top one last ({overlay, close})


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
		_my_side = GameDB.coach_side(str(_res["home"]), str(_res["away"]), GameState.my_club)
		_pos_before = GameState.my_position()
		_farewell = _farewell_for(GameState.pending_match)
	else:
		_res = GameState.last_match
		_review = GameState.review_requested
		GameState.review_requested = false
		if not _res.is_empty() and GameState.my_club != "":
			_my_side = GameDB.coach_side(str(_res.get("home", "")), str(_res.get("away", "")), GameState.my_club)
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
	_pitch.ends_changed.connect(_on_ends_changed)
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
	# A phone follows the ball close up because its screen is small (and so does
	# any narrow, stacked window); a wide window shows the whole ground whatever
	# the platform (director, 2026-10-09; the web build on a PC, 2026-10-12).
	_orient_pitch(stack)
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
		_setup_line = NameInk.rich(UiKit.SMALL, UiKit.MUTED)
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


## A phone held upright shows the whole ground running top to bottom, goals at
## the top and the bottom, nothing cut off (director, 2026-10-14). A phone on its
## side, and any narrow window wider than it is tall, keeps the close-up that
## follows the ball; a wide window shows the whole ground left to right.
func _orient_pitch(stack: bool) -> void:
	if _pitch == null:
		return
	var tall := UiKit.view_height(self) > UiKit.view_width(self)
	_pitch.upright = stack and tall
	_pitch.camera_enabled = (stack or ScreenLayout.is_phone()) and not _pitch.upright


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
		_mom_note.text = "Momentum swings with each goal and fades with time; the side on top wins a little more of the ball. %s it for more." % ScreenLayout.tap_word()
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
	_close_break_sheets()
	_break_refresh = Callable()
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
	["heat", "Bring the heat"],
]
## The policies named for what they are for (director, 2026-10-07). Their full names
## (Protect freshness, Balanced rotations, Prioritise key players) are
## MatchSim.ROTATION_POLICIES' labels; the break's three side-by-side buttons
## carry the short form so a phone row fits.
const ROTATION_SHORT := {"hard": "Freshness", "normal": "Balanced", "stars": "Key players"}


## The break: what happened, then your calls for the next quarter. It
## surfaces the problem - their midfield on top, a forward hurting you - and
## leaves the answer to you. No advice, no expected points.
func _show_coach_box() -> void:
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	# A new break: nothing to pack again until this one is built.
	_break_pack_cols = []
	_break_reading = []
	_pitch.pause()
	_sync_controls()
	var sim: MatchSim = GameState.pending_sim
	var q := sim.current_quarter
	# The calls fill the screen at every break, so the actions sit at the
	# bottom with the choices just above them.
	# On a PC the break is a wide landscape sheet with every call in view
	# (director, 2026-10-09: "it looks like we are using a mobile UI on a PC").
	var wide := _wide_break()
	_pc_break = wide
	var stats_pc: Button = null
	var box := UiKit.modal_box(self, minf(UiKit.view_width(self) - 48.0, 1560.0) if wide else 640.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "CoachBox"
	_coach_overlay = overlay
	var v: VBoxContainer = box["body"]
	var titles := {1: "Before the first ball-up", 2: "Quarter time", 3: "Half time", 4: "Three-quarter time"}
	# The break leads with both clubs' colours (director, 2026-10-08).
	# On a PC the title and the score share one line: the band is wide.
	var bv: BoxContainer = UiKit.hbox(16) if wide else UiKit.vbox(2)
	var band := ClubDuel.band(str(_res["home"]), str(_res["away"]), bv, 14)
	band.name = "BreakBand"
	(band.get_child(0) as ClubDuel).live()   # match day's atmosphere settles in (Feel)
	v.add_child(band)
	# Wide (PC, director 2026-10-11: no column scrolls at 1280x720): the
	# quarter just played and the key match-ups, then the calls in three
	# columns - the plan, the tag and the talk; the rotations and the loose
	# men; the three play-through calls. A phone keeps one column, every call
	# in it.
	# Below 1200 units the first column sits above the other three.
	var rep: VBoxContainer = v
	var col_a: VBoxContainer = v
	var col_b: VBoxContainer = v
	var col_c: VBoxContainer = v
	var cols: HBoxContainer = null
	# How many from the game so far each player call shows before "Other
	# player...": two on a wide screen, so every call fits without scrolling.
	var quick := 0
	# From quarter time on the break is one line a call (director, 2026-10-14):
	# every call is built as before, into a store, and laid out by
	# _mount_one_line. The menu before the first ball-up is unchanged.
	var one_line := q > 1
	var store: VBoxContainer = null
	if one_line:
		quick = 2 if wide else 0
		store = UiKit.vbox(6)
		store.name = "CallStore"
		store.visible = false
		rep = store
		col_a = store
		col_b = store
		col_c = store
	if wide and not one_line:
		var four := UiKit.view_width(self) >= 1200.0
		quick = 2
		cols = HBoxContainer.new()
		cols.name = "BreakColumns"
		cols.add_theme_constant_override("separation", 24 if four else 32)
		col_a = UiKit.vbox(6)
		col_b = UiKit.vbox(6)
		col_c = UiKit.vbox(6)
		if four:
			rep = UiKit.vbox(6)
			v.add_child(cols)
		for c in ([rep, col_a, col_b, col_c] if four else [col_a, col_b, col_c]):
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			cols.add_child(c)
	var title := UiKit.heading(str(titles.get(q, "Quarter %d" % q)), UiKit.H1)
	title.name = "BreakTitle"
	if wide:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ClubDuel.on_colour(title)
	bv.add_child(title)
	if q == 1:
		var where := UiKit.ellipsis("%s  ·  %s v %s  ·  %s" % [str(_res.get("label", "Match")),
				GameDB.club_short(str(_res["home"])), GameDB.club_short(str(_res["away"])), _venue()], UiKit.BODY, UiKit.TEXT, true)
		ClubDuel.on_colour(where)
		if wide:
			where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bv.add_child(where)
	else:
		var sc := UiKit.lbl(MatchNotes.break_score(str(_res["home"]), str(_res["away"]),
				_res.get("goals", [0, 0]), _res.get("behinds", [0, 0])), UiKit.NAME, UiKit.TEXT, true)
		sc.name = "BreakScore"
		sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ClubDuel.on_colour(sc)
		if wide:
			sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bv.add_child(sc)
		# The full numbers, both clubs, at every break (director's PC
		# playtest, 2026-10-07): a tap, never a compulsory report.
		# On a PC it is a word in the actions row, beside Skip to full time.
		var stats := UiKit.text_action("Match stats", UiKit.BODY) if wide else UiKit.btn("Match stats", UiKit.BODY)
		stats.name = "BreakStats"
		stats.custom_minimum_size = Vector2(0, 44)
		stats.pressed.connect(_show_break_stats)
		if wide:
			stats_pc = stats
		else:
			rep.add_child(stats)
			rep.add_child(UiKit.spacer(UiKit.GAP))
		var played := UiKit.section(str({2: "First quarter", 3: "Second quarter",
				4: "Third quarter"}.get(q, "Last quarter")))
		played.name = "QuarterHeading"
		played.set_meta("break_unit", true)
		rep.add_child(played)
		rep.add_child(_quarter_view(q - 1))
		var did := MatchNotes.calls_lines(_res, _my_side, q - 1) \
				+ MatchNotes.duel_change_lines(_res, _my_side, q - 1) \
				+ MatchNotes.tag_drop_lines(_res, _my_side, q - 1) \
				+ MatchNotes.lasting_moment_lines(_res, q - 1)
		if not did.is_empty():
			rep.add_child(UiKit.spacer(UiKit.GAP))
			var did_head := UiKit.section("What your calls did")
			did_head.name = "CallsDidHeading"
			did_head.set_meta("break_unit", true)
			rep.add_child(did_head)
			var dv := UiKit.vbox(4)
			dv.name = "CallsDid"
			for t in did:
				var dl := _say(str(t), UiKit.BODY, UiKit.TEXT)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dv.add_child(dl)
			rep.add_child(dv)
	rep.add_child(UiKit.spacer(UiKit.GAP))
	if cols != null and cols.get_parent() == null:
		v.add_child(cols)
	var calls_head := UiKit.section("Your calls" if q == 1 else "Next quarter")
	calls_head.set_meta("break_unit", true)
	col_a.add_child(calls_head)

	# Your calls, as taps: nothing here is a settings form. Short lists sit
	# in plain view; a player list shows the few in the game so far and
	# keeps everyone else one tap away.
	# The plan in force is the engine's: your club plan before the first
	# bounce (GameState.prepare_interactive_match), your last call after.
	var calls := {
		"gameplan": _current_plan(sim),
		"tag_id": str((sim.tactics[_my_side] as Dictionary).get("tag_id", _last_tactics.get("tag_id", ""))),
		"tagger_id": str((sim.tactics[_my_side] as Dictionary).get("tagger_id", _last_tactics.get("tagger_id", ""))),
		"focus_mid": str(_last_tactics.get("focus_mid", "")),
		"focus_fwd": str(_last_tactics.get("focus_fwd", "")),
		"focus_def": str(_last_tactics.get("focus_def", "")),
		"main_ruck": str(_last_tactics.get("main_ruck", "")),
		"interceptor_id": str(sim.interceptor[_my_side]),
		"minder_id": str((sim.tactics[_my_side] as Dictionary).get("spare_minder_id", "")) 				if bool((sim.tactics[_my_side] as Dictionary).get("spare_accountable", false)) else "",
		"pep": "steady",
		"rotation": _rotation,
	}
	var loose_was := str(calls["interceptor_id"])
	var narrow := UiKit.view_width(self) < 560.0

	var plan_known := UiKit.lbl("", UiKit.SECONDARY, UiKit.TEXT, true)
	plan_known.name = "PlanKnown"
	plan_known.visible = false
	# The plan under the buttons, in short separate lines: what it does, what
	# it gains and costs, what it beats, and who makes it work.
	var plan_note := UiKit.vbox(3)
	plan_note.name = "PlanNote"
	var my_ground: Array = (sim.squads[_my_side] as Squad).ground
	var sync_note := func(key: String) -> void:
		for c in plan_note.get_children():
			plan_note.remove_child(c)
			c.queue_free()
		var d := CoachReport.plan_parts(key)
		var does := UiKit.lbl(str(d["does"]), UiKit.BODY, UiKit.TEXT, true)
		does.name = "PlanDoes"
		does.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plan_note.add_child(does)
		for part in [["gain", "Gain:", "PlanGain"], ["cost", "Cost:", "PlanCost"]]:
			if d.has(part[0]):
				plan_note.add_child(_plan_row(str(part[1]), str(d[part[0]]), str(part[2])))
		if d.has("beats"):
			var beats := UiKit.lbl(str(d["beats"]), UiKit.SECONDARY, UiKit.TEXT)
			beats.name = "PlanBeats"
			beats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			plan_note.add_child(beats)
		# Who makes it work: the plan's upside rests on them (PlanFit).
		var fit := GameState.plan_fit_short(my_ground, key)
		if not fit.is_empty():
			var who := UiKit.vbox(0)
			who.name = "PlanWho"
			var judged := _say(str(fit["judged"]), UiKit.SECONDARY, UiKit.TEXT)
			judged.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			who.add_child(judged)
			who.add_child(_plan_row("Best for it:", str(fit["names"]), "PlanBest"))
			plan_note.add_child(UiKit.spacer(2))
			plan_note.add_child(who)
		# How well the side knows it (plan familiarity): a decision, so at full strength.
		var known := GameState.plan_known_line(key)
		plan_known.text = known
		plan_known.visible = known != ""
	var plan := _choice_grid("PlanPicker", GAMEPLANS, calls, "gameplan", 2 if narrow else 3, sync_note)
	# The heading and the plan under it stay together.
	var plan_block := _call_block("Gameplan", plan)
	plan_block.remove_meta("break_unit")
	col_a.add_child(plan_block)
	col_a.add_child(plan_known)
	col_a.add_child(plan_note)
	sync_note.call(str(calls["gameplan"]))

	# Tag: their most influential so far first, anyone on the ground a tap away.
	# A tag is a midfield job: only their midfielders can be tagged.
	# Only players still in the match: the roster keeps anyone hurt and gone.
	var opp := _roster_side(1 - _my_side).filter(func(r): return _taggable_now(sim, r))
	# Who goes to him - a fact, not advice (Roles: a tagger makes a tag bite
	# harder than a midfielder doing the job). With no tag, say that instead.
	# Who does the job is the coach's call too (director, 2026-10-10: the
	# side's best player was sent to tag, with no say in it). Any of your
	# midfielders on the ground can go; your assistant's man is the default.
	var tagger = MatchSim.tagger_for(my_ground)
	var my_mids := {}
	for p in my_ground:
		if MatchSim.midfielder_on_ground(p):
			my_mids[str(p["id"])] = p
	if not my_mids.has(str(calls["tagger_id"])):
		calls["tagger_id"] = ""
	var others := _roster_side(_my_side).filter(func(r):
		return my_mids.has(str(r["id"])) and (tagger == null or str(r["id"]) != str(tagger["id"])))
	# Most able first, by the number on the card: Pressure.
	var press := func(r: Dictionary) -> float:
		return float((my_mids.get(str(r["id"]), r) as Dictionary).get("attr", {}).get("pressure", 0.0))
	others.sort_custom(func(a, b): return press.call(a) > press.call(b))
	# What he gives up: his Player rating for the season so far, the figure the
	# Ratings screen shows (a game's average); -1 before he has played.
	var season_rating := func(id: String) -> float:
		var book: Dictionary = GameState.season_stats.get(id, {})
		var games := int(book.get("games", 0))
		return StatsPlayers.season_rating(book.get("s", {}) as Dictionary) / float(games) if games > 0 else -1.0
	var tag_detail := func(r: Dictionary, wide: bool) -> String:
		var p: Dictionary = my_mids.get(str(r["id"]), r)
		return MatchNotes.tagger_card_detail(p, float(sim.energy.get(str(r["id"]), 100.0)), wide, season_rating.call(str(r["id"])))
	var tag_note := NameInk.rich(UiKit.SMALL, UiKit.MUTED)
	tag_note.name = "TagNote"
	tag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Who goes to him is only a question once there is a him: hidden with no
	# tag (the fullest PC break then still fits without scrolling).
	var who_block: Array = []
	var who_wb: Control = null
	var who_hook: Array = [Callable()]
	var sync_tag := func(_key: String) -> void:
		if (who_hook[0] as Callable).is_valid():
			(who_hook[0] as Callable).call()
		for b in who_block:
			(b as Control).visible = str(calls["tag_id"]) != ""
		# The columns are dealt once, with Who tags counted in its room (see
		# _unit_heights): a call never changes column when it expands.
		var who = my_mids.get(str(calls["tagger_id"]), tagger)
		var target := GameDB.player_display_name_by_id(str(calls["tag_id"]), "")
		if str(calls["tag_id"]) == "":
			NameInk.set_line(tag_note, "No tag: your midfielders play their own game.", _names())
		elif who == null:
			NameInk.set_line(tag_note, "No midfielder on the ground to tag with.", _names())
		elif Roles.is_tagger(who):
			NameInk.set_line(tag_note, "%s, your tagger, tags %s." % [GameDB.player_display_name(who), target], _names())
		else:
			NameInk.set_line(tag_note, "%s tags %s. He gives up his own game." % [GameDB.player_display_name(who), target], _names())
	# The tag is offered on their listed midfielders only (director, 2026-10-14:
	# "Only listed midfielders"): the names, and "Other midfielder..." for the
	# listed midfielders not already shown, which is not drawn when none is
	# left. A ruck or a defender running through the middle is not offered, so
	# "Tag which midfielder?" stays true.
	var opp_listed := opp.filter(func(r): return _listed_midfielder(sim, r))
	var tag := _player_choice("TagPicker", "No tag", opp_listed, _in_the_game(opp_listed, quick if quick > 0 else 4), calls, "tag_id",
			"Tag which midfielder?", sync_tag, Callable(), Callable(), "Other midfielder…", true)
	col_a.add_child(_call_block("Tag", tag))
	if tagger != null and not others.is_empty():
		# Your assistant's man carries the same facts as the others, so
		# they can be compared card for card.
		# On a PC two alternatives beside his card (two rows, so the fullest
		# break still fits 1280x720); the rest are behind Other player....
		var card := func(b: Button, id: String) -> void:
			var who: Dictionary = tagger if id == "" else my_mids.get(id, {})
			if who.is_empty():
				return
			var pid := str(who.get("id", ""))
			_dress_tagger_card(b, _short_name(who), MatchNotes.tagger_card(who, float(sim.energy.get(pid, 100.0)), season_rating.call(pid)), id == "")
		var who_tags := _player_choice("TaggerPicker", _card_text(tagger, tag_detail) + "\nYour assistant's pick", others,
				others.slice(0, 2 if _pc_break else 3),
				calls, "tagger_id", "Who goes to him?", sync_tag, tag_detail, card, "Other tagger…")
		var wb := _call_block("Who tags", who_tags)
		# The follow-up to Tag: packed with its question, never ahead of it.
		wb.set_meta("break_follow", true)
		if not one_line:
			who_block.append(wb)
		who_wb = wb
		col_a.add_child(wb)
	sync_tag.call("")
	col_a.add_child(tag_note)

	# Key match-ups: who is on their key forwards, how the contests went last
	# quarter, and yours against their defenders. Change one in a tap.
	# In three columns they sit under the quarter just played, so no column
	# stands half empty (director, 2026-10-10).
	var mv := _matchups_view(sim, q)
	if mv != null:
		mv.set_meta("break_unit", true)
		(rep if rep != v else col_a).add_child(mv)
	# Assign defensive forward (director, 2026-10-07): one of your forwards goes
	# up the ground with their loose defender. Facts only: each card says where
	# he plays, whether he is a Defensive forward and his Pressure, the one
	# attribute the job runs on; the choice is yours.
	var opp_spare := sim._roaming_interceptor(1 - _my_side)
	var minder_box := UiKit.vbox(4 if _pc_break else 6)
	minder_box.name = "MinderBlock"
	minder_box.set_meta("break_unit", true)
	minder_box.add_child(_call_heading("Assign defensive forward"))
	if opp_spare.is_empty():
		var none_note := UiKit.lbl(MatchNotes.minder_none_line(), UiKit.SMALL, UiKit.MUTED)
		none_note.name = "MinderNote"
		none_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		minder_box.add_child(none_note)
	else:
		var fwds := Matchups.minder_candidates(my_ground)
		var ask := _say(MatchNotes.minder_question(GameDB.player_display_name(opp_spare),
				GameDB.club_name(str((sim.squads[1 - _my_side] as Squad).code))), UiKit.BODY, UiKit.TEXT, true)
		ask.name = "MinderQuestion"
		ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		minder_box.add_child(ask)
		# From the first break on there is a match to read: how the two are
		# going (director, 2026-10-14). It follows the pick.
		var df_how: VBoxContainer = null
		if q > 1:
			df_how = UiKit.vbox(4)
			df_how.name = "DfHowItsGoing"
			minder_box.add_child(df_how)
			_fill_df_duel(df_how, sim, calls, opp_spare)
		minder_box.add_child(_player_choice("SpareMinderPicker", "No defensive forward assigned", fwds,
				fwds.slice(0, mini(quick if quick > 0 else 3, fwds.size())), calls, "minder_id", "Who covers him?",
				func(_id: String) -> void:
					if df_how != null:
						_fill_df_duel(df_how, sim, calls, opp_spare),
				func(p: Dictionary, wide: bool) -> String: return MatchNotes.minder_card_detail(p, wide)))
		var minder_note := UiKit.lbl(MatchNotes.minder_cost_line(), UiKit.SMALL, UiKit.MUTED)
		minder_note.name = "MinderNote"
		minder_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		minder_box.add_child(minder_note)
	col_a.add_child(minder_box)
	var minder_nodes: Array = [minder_box]

	# The rest of the calls, all in view (director, 2026-10-09: no "More
	# calls" button).
	var more: VBoxContainer = col_c
	var syn_label: Control = _synergy_block()
	if syn_label != null:
		syn_label.set_meta("break_unit", true)
		more.add_child(syn_label)

	var mine := _roster_side(_my_side)

	# Structural defence: one real defender can roam as the spare. Picking him
	# releases him from a direct opponent; the engine reallocates that matchup.
	var def_ground: Array = []
	for p in my_ground:
		if str(p.get("role", "")) == "DEF":
			def_ground.append(p)
	var interceptors := Matchups.interceptor_candidates(def_ground)
	var roam_first: Array = interceptors.slice(0, mini(quick if quick > 0 else 3, interceptors.size()))
	var roam := _player_choice("InterceptorPicker", "No loose defender", def_ground, roam_first,
			calls, "interceptor_id", MatchNotes.loose_question(), Callable(),
			func(p: Dictionary, wide_line: bool) -> String: return MatchNotes.loose_card_detail(p, wide_line))
	# Loose interceptor (director, 2026-10-11): the question in a coach's
	# words, a card per defender, and how your loose man is going so far.
	var roam_block := UiKit.vbox(4 if _pc_break else 6)
	roam_block.set_meta("break_unit", true)
	roam_block.name = "LooseBlock"
	roam_block.add_child(_call_heading("Loose interceptor"))
	var roam_ask := UiKit.lbl(MatchNotes.loose_question(), UiKit.BODY, UiKit.TEXT, true)
	roam_ask.name = "LooseQuestion"
	roam_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roam_block.add_child(roam_ask)
	roam_block.add_child(roam)
	# His intercepts this match, from quarter time on: only your loose man's,
	# only while one is named.
	var loose_now := str(sim.interceptor[_my_side])
	if q > 1 and loose_now != "":
		var stats: Dictionary = (_res.get("players", {}) as Dictionary).get(loose_now, {})
		var tally := _say(MatchNotes.loose_tally_line(GameDB.player_display_name_by_id(loose_now, "Your loose man"),
				int(float(stats.get("intercepts", 0.0)))), UiKit.SMALL, UiKit.TEXT)
		tally.name = "LooseTally"
		tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		roam_block.add_child(tally)
	more.add_child(roam_block)
	var roam_note := UiKit.lbl(
			"He leaves his direct man to attack aerial balls. Another defender covers where possible; if he flies and loses, space opens behind him.",
			UiKit.SMALL, UiKit.MUTED)
	roam_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.add_child(roam_note)

	# Play through, three calls (director, 2026-10-07): each offers the men who
	# fill that job now, and says what it does or that it waits.
	for slot in MatchSim.FOCUS_SLOTS:
		var fits := mine.filter(func(r): return (MatchSim.FOCUS_SLOT_ROLES[slot] as Array).has(
				str(_focus_player(str(r["id"])).get("role", r.get("role", "")))))
		var note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
		note.name = "FocusNote_" + slot
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sync := func(id: String) -> void:
			note.text = _focus_note_text(slot, id)
		var text: Array = MatchNotes.FOCUS_SLOT_TEXT[slot]
		var pick := _player_choice("FocusPicker_" + slot, "No one", fits, _in_the_game(fits, quick if quick > 0 else 3), calls, slot,
				"Play through: %s" % str(text[0]).to_lower(), sync)
		var block := _call_block("Play through: %s" % str(text[0]).to_lower(), pick)
		sync.call(str(calls[slot]))
		block.add_child(note)
		more.add_child(block)

	# Main ruck (director, 2026-10-07), after the play-through calls: who
	# goes up is a job like theirs. Only for a side with two rucks in the
	# team. The one you name goes up whenever he is on the ground; with none
	# named, whoever stands in the ruck spot does.
	var rucks := _my_rucks(sim)
	if rucks.size() >= 2:
		var ruck_opts := [["", "No main ruck"]]
		for r in rucks:
			# His Ruck and Contested ratings, named as the Ratings screen names
			# them, so a weak tap man is plain before he is named. The position
			# line keeps only what "Ruck 73" does not already say.
			var at := r["attr"] as Dictionary
			var skills := "Ruck %d · Contested %d" % [roundi(float(at.get("ruck", 0.0))), roundi(float(at.get("contested", 0.0)))]
			var places := PackedStringArray()
			for pos in Ratings.positions(r):
				if str(pos) != "RUCK":
					places.append(str(UiKit.ROLE_LABEL.get(str(pos), str(pos))))
			var detail := skills if places.is_empty() else "/".join(places) + "
" + skills
			ruck_opts.append([str(r["id"]), "%s
%s" % [GameDB.player_display_name(r), detail]])
		var ruck_note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
		ruck_note.name = "MainRuckNote"
		ruck_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sync_ruck := func(id: String) -> void:
			ruck_note.text = _main_ruck_note(rucks, id)
		var ruck := _choice_grid("MainRuckPicker", ruck_opts, calls, "main_ruck", 2, sync_ruck)
		more.add_child(_call_block("Main ruck", ruck))
		more.add_child(ruck_note)
		sync_ruck.call(str(calls["main_ruck"]))

	# Wide: the pep talk sits under the tag; rotations and both loose men,
	# yours and theirs, share a column, so every column fits a 720-unit
	# screen.
	var tail: VBoxContainer = col_b
	var pep_note := UiKit.vbox(3)
	pep_note.name = "PepNote"
	var sync_pep := func(key: String) -> void:
		_fill_note_lines(pep_note, CoachReport.pep_summary(key))
	# Four talks: a two-column grid of their full names, which fits a 360 phone
	# and the PC column alike (one row of four ran off a phone).
	var pep := _choice_grid("PepPicker", PEP_TALKS, calls, "pep", 2, sync_pep)
	col_a.add_child(_call_block("Pep talk", pep))
	col_a.add_child(pep_note)
	sync_pep.call("steady")

	var rot_opts := []
	for k in MatchSim.ROTATION_POLICIES:
		rot_opts.append([str(k), str(ROTATION_SHORT.get(k, MatchSim.ROTATION_POLICIES[k]["label"]))])
	var rot_note := UiKit.vbox(3)
	rot_note.name = "RotationNote"
	var sync_rot := func(key: String) -> void:
		_fill_note_lines(rot_note, str(MatchSim.ROTATION_POLICIES[key]["text"]))
	var rot := _segmented("RotationPicker", rot_opts, calls, "rotation", sync_rot)
	var rot_block := _call_block("Rotations", rot)
	rot_block.name = "RotationsBlock"
	if wide:
		# A gap above Rotations on a PC, so the pep note above it does not run
		# into the heading; hidden when the block lands at a column's top.
		var gap := UiKit.spacer(6)
		gap.name = "RotationsGap"
		rot_block.add_child(gap)
		rot_block.move_child(gap, 0)
	tail.add_child(rot_block)
	tail.add_child(rot_note)
	sync_rot.call(_rotation)
	# On a wide screen the three play-through calls fill the last column, so the
	# loose interceptor sits under the rotations, their loose defender after
	# him, and no column has to scroll.
	if wide:
		for n in [roam_block, roam_note] + minder_nodes:
			n.get_parent().remove_child(n)
			tail.add_child(n)
	(rep if rep != v else tail).add_child(_legs_view())
	# The synergies line is about the two sides' strengths, like the legs line:
	# on a PC sheet it sits right under it, never alone at the top of a column
	# without a heading (BOSS QC, 2026-10-11).
	if wide and syn_label != null and syn_label.get_parent() != null:
		syn_label.get_parent().remove_child(syn_label)
		syn_label.remove_meta("break_unit")
		(rep if rep != v else tail).add_child(syn_label)
	# Who is playing well, on the break (director, 2026-10-11): on a PC in the
	# report column; on a phone below the choices, so nothing the next quarter
	# depends on is pushed under the pinned Start button.
	# Before the first ball-up nobody has played: no zeros (director, 2026-10-14).
	if q > 1:
		(rep if rep != v else tail).add_child(_best_so_far())

	var start := UiKit.btn("Start quarter" if q > 1 else "Ball it up", UiKit.HEADING, true)
	start.name = "StartQuarter"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func():
		_rotation = str(calls["rotation"])
		var t := {
			"gameplan": str(calls["gameplan"]),
			"focus_mid": str(calls["focus_mid"]),
			"focus_fwd": str(calls["focus_fwd"]),
			"focus_def": str(calls["focus_def"]),
			"main_ruck": str(calls["main_ruck"]),
			"tag_id": str(calls["tag_id"]),
			"tagger_id": str(calls["tagger_id"]),
			"interceptor_id": str(calls["interceptor_id"]),
			"interceptor_set": str(calls["interceptor_id"]) != loose_was,
			"spare_accountable": str(calls["minder_id"]) != "",
			"spare_minder_id": str(calls["minder_id"]),
			"pep": str(calls["pep"]),
			"rotation": _rotation,
		}
		_close_coach()
		_simulate_next_quarter(t))
	# One primary action on the break; the way out is said as words.
	var skip := UiKit.text_action("Skip to full time", UiKit.BODY)
	skip.pressed.connect(_on_skip)
	if one_line:
		_mount_one_line({"box": box, "store": store, "calls": calls, "wide": wide, "start": start, "skip": skip,
				"stats_pc": stats_pc, "tagger": tagger, "my_mids": my_mids, "who_wb": who_wb, "who_hook": who_hook,
				"opp_spare": opp_spare, "sim": sim, "syn": syn_label, "roam_note": roam_note})
	elif wide:
		# A PC sheet's actions sit together at the right, not as full-width bars.
		var acts := UiKit.hbox(12)
		acts.alignment = BoxContainer.ALIGNMENT_END
		skip.custom_minimum_size = Vector2(220, 48)
		start.custom_minimum_size = Vector2(300, 48)
		if stats_pc != null:
			stats_pc.custom_minimum_size = Vector2(180, 48)
			acts.add_child(stats_pc)
		acts.add_child(skip)
		acts.add_child(start)
		box["footer"].add_child(acts)
		# A mouse, not a thumb: the choices sit 34 tall on the PC sheet, so the
		# fullest break (both loose men, a tag card, your tally) fits 1280x720.
		for b in cols.find_children("*", "Button", true, false):
			if (b as Button).custom_minimum_size.y == 44.0:
				(b as Button).custom_minimum_size.y = 40.0
		_break_pack_cols = [rep, col_a, col_b, col_c] if rep != v else [col_a, col_b, col_c]
		_break_reading = []
		_balance_break_columns.call_deferred(_break_pack_cols)
	else:
		box["footer"].add_child(start)
		box["footer"].add_child(skip)
	# A call the quarter broke brightens twice (Feel; never a nag).
	for picker in MatchNotes.broken_calls(_res, sim.injuries, _my_side, q, _last_tactics):
		var found := overlay.find_child(str(picker) + "*", true, false)
		if found != null and one_line:
			# The call's row brightens: its picker is behind the row.
			var up: Node = found
			while up != null and not str(up.name).begins_with("CallBody_"):
				up = up.get_parent()
			var row: Node = overlay.find_child("CallRow_" + str(up.name).trim_prefix("CallBody_"), true, false) if up != null else null
			if row != null:
				UiKit.attention(row as CanvasItem)
		elif found != null:
			UiKit.attention(found.get_parent() as CanvasItem)


# ---------------------------------------------------------------------------
# The break from quarter time on: one line a call (director, 2026-10-14)
# ---------------------------------------------------------------------------
## What a call's sheet is headed, and what its row says it is.
const CALL_TITLES := {"plan": "Game plan", "pep": "Pep talk", "rot": "Rotations", "tag": "Tag", "mu": "Key match-ups",
		"minder": "Defensive forward", "loose": "Loose interceptor", "pt": "Play through", "ruck": "Main ruck"}
const CALL_ROW_LABELS := {"pt": "Play through (forward, midfield, back)"}


## "How it's going" for the Defensive forward and their loose defender, this
## match so far: both ratings side by side in the scoreboard face under their
## names in club colour, then the contests between them and his intercepts.
func _fill_df_duel(box: VBoxContainer, sim: MatchSim, calls: Dictionary, roamer: Dictionary) -> void:
	UiKit.clear(box)
	var df_id := str(calls["minder_id"])
	var roamer_id := str(roamer.get("id", ""))
	var d := MatchNotes.df_duel(_res, df_id, roamer_id)
	var inks := UiKit.club_ink_pair(str(_res["home"]), str(_res["away"]))
	var head := UiKit.lbl("How it's going", UiKit.SMALL, UiKit.TEXT, true)
	head.name = "DfHeading"
	box.add_child(head)
	var row := UiKit.hbox(12)
	row.name = "DfRatings"
	var who := [[df_id, _my_side], [roamer_id, 1 - _my_side]]
	for w in who:
		if str(w[0]) == "":
			continue
		var col := UiKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UiKit.ellipsis(_surname(GameDB.player_display_name_by_id(str(w[0]), "Player")), UiKit.NAME,
				UiKit.club_name_colour(inks[int(w[1])]), true)
		nm.name = "DfName_" + str(w[0])
		col.add_child(nm)
		var rr := UiKit.figure(MatchNotes.rating_text(MatchNotes.match_rating(_res, str(w[0]))), UiKit.NUMBER)
		rr.name = "DfRating_" + str(w[0])
		var rrow := UiKit.hbox(6)
		rrow.add_child(rr)
		var rtag := UiKit.lbl("rating", UiKit.SECONDARY, UiKit.MUTED)
		rtag.size_flags_vertical = Control.SIZE_SHRINK_END
		rrow.add_child(rtag)
		col.add_child(rrow)
		row.add_child(col)
	box.add_child(row)
	var lines := MatchNotes.df_duel_lines(d,
			_surname(GameDB.player_display_name_by_id(df_id, "")),
			_surname(GameDB.player_display_name_by_id(roamer_id, "")))
	for i in range(lines.size()):
		if str(lines[i]) == "":
			continue
		var l := UiKit.lbl(str(lines[i]), UiKit.BODY, UiKit.TEXT)
		l.name = "DfLine_%d" % i
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)


## Lays the break out as one line a call. Every call was built by
## _show_coach_box into c["store"]; here each becomes a body (its choices, its
## follow-up and its words) behind a row that shows its answer. A phone opens a
## call as its own sheet; a PC shows the chosen call beside the list, in room
## kept for the tallest, so nothing appears or shoves the page. "Who tags" lives
## inside the Tag call: a line with Change on a phone (its cards are their own
## sheet), its cards in the pane on a PC, there from the start.
func _mount_one_line(c: Dictionary) -> void:
	var box: Dictionary = c["box"]
	var v: VBoxContainer = box["body"]
	var overlay: Control = box["overlay"]
	var store: VBoxContainer = c["store"]
	var calls: Dictionary = c["calls"]
	var wide: bool = c["wide"]
	var sim: MatchSim = c["sim"]
	var take := func(nm: String, parent := false) -> Control:
		var n: Control = store.find_child(nm, true, false)
		if n != null and parent:
			n = n.get_parent() as Control
		return n
	var bodies := {}
	var order: Array = []
	var body := func(key: String, parts: Array) -> void:
		var b := UiKit.vbox(4 if wide else 6)
		b.name = "CallBody_" + key
		for p in parts:
			if p == null:
				continue
			if (p as Node).get_parent() != null:
				(p as Node).get_parent().remove_child(p)
			b.add_child(p)
		if b.get_child_count() == 0:
			b.free()
			return
		# The sheet or the pane says what the call is: its own small heading goes.
		if key != "pt":
			var h: Node = b.find_child("CallHeading", true, false)
			if h != null:
				(h as Control).visible = false
		bodies[key] = b
		order.append(key)
		store.add_child(b)

	# Who tags, inside the Tag call from the start.
	var who_wb: Control = c["who_wb"]
	var who_line: HBoxContainer = null
	var who_name: Label = null
	var who_sub: Label = null
	var who_change: Button = null
	if who_wb != null and not wide:
		who_line = UiKit.hbox(8)
		who_line.name = "WhoTagsLine"
		var wc := UiKit.vbox(0)
		wc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wc.add_child(UiKit.line("Who tags", UiKit.SECONDARY, UiKit.MUTED))
		who_name = UiKit.ellipsis("", UiKit.NAME, UiKit.TEXT, true)
		who_name.name = "WhoTagsName"
		wc.add_child(who_name)
		who_sub = UiKit.line("", UiKit.SECONDARY, UiKit.MUTED)
		who_sub.name = "WhoTagsSub"
		wc.add_child(who_sub)
		who_line.add_child(wc)
		who_change = UiKit.text_action("Change", UiKit.SECONDARY)
		who_change.name = "WhoTagsChange"
		who_change.pressed.connect(func():
			_open_break_sheet("who", "Who tags %s?" % GameDB.player_display_name_by_id(str(calls["tag_id"]), "him"),
					[who_wb], store))
		who_line.add_child(who_change)
		var wh: Node = who_wb.find_child("CallHeading", true, false)
		if wh != null:
			(wh as Control).visible = false
	if who_wb != null:
		who_wb.visible = true
	(c["who_hook"] as Array)[0] = func() -> void:
		var has_tag := str(calls["tag_id"]) != ""
		if who_name != null and is_instance_valid(who_name):
			var who = (c["my_mids"] as Dictionary).get(str(calls["tagger_id"]), c["tagger"])
			who_name.text = GameDB.player_display_name(who) if has_tag and who != null else "Nobody"
			who_sub.text = "There is no tag." if not has_tag else ("Your assistant's pick" if str(calls["tagger_id"]) == "" else "Your pick")
			who_change.disabled = not has_tag
		elif who_wb != null and is_instance_valid(who_wb):
			who_wb.modulate.a = 1.0 if has_tag else 0.4
			for b in who_wb.find_children("*", "Button", true, false):
				(b as Button).disabled = not has_tag

	var fact: Label = null
	var fact_text := _tag_fact_line(sim)
	if fact_text != "":
		fact = UiKit.lbl(fact_text, UiKit.BODY, UiKit.TEXT)
		fact.name = "TagFact"
		fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap: Node = store.find_child("RotationsGap", true, false)
	if gap != null:
		(gap as Control).visible = false
	var mu: Control = take.call("BreakMatchups")
	if mu != null:
		# Its spacer and its own heading: the sheet or the pane is headed already.
		for i in range(mini(2, mu.get_child_count())):
			(mu.get_child(i) as Control).visible = false
	body.call("plan", [take.call("PlanPicker", true), take.call("PlanNote"), _calls_record("gameplan"), c["syn"]])
	body.call("pep", [take.call("PepPicker", true), take.call("PepNote"), _calls_record("pep")])
	body.call("rot", [take.call("RotationsBlock"), take.call("RotationNote"), _calls_record("rotation")])
	body.call("tag", [fact, take.call("TagPicker", true), who_wb if wide else who_line, take.call("TagNote")])
	body.call("mu", [mu])
	body.call("minder", [take.call("MinderBlock")])
	body.call("loose", [take.call("LooseBlock"), c["roam_note"]])
	var through: Array = []
	for slot in MatchSim.FOCUS_SLOTS:
		through.append(take.call("FocusPicker_" + str(slot), true))
	body.call("pt", through)
	body.call("ruck", [take.call("MainRuckPicker", true), take.call("MainRuckNote")])
	((c["who_hook"] as Array)[0] as Callable).call()

	# The rows: what each call is, and its answer now.
	var rows := UiKit.vbox(0)
	rows.name = "CallRows"
	var row_of := {}
	for key in order:
		var r := _call_row(str(key), str(CALL_ROW_LABELS.get(key, CALL_TITLES[key])))
		row_of[key] = r
		rows.add_child(r)
		rows.add_child(UiKit.rule())
	var first := {}
	for key in order:
		first[key] = _call_answer(str(key), calls, c)
	_break_refresh = func() -> void:
		if not is_instance_valid(rows):
			return
		for key in order:
			var r: Button = row_of[key]
			var a := _call_answer(str(key), calls, c)
			NameInk.set_line(r.get_meta("answer") as RichTextLabel, a, _names())
			var changed := a != str(first[key])
			(r.get_meta("changed") as Label).visible = changed
			(r.get_meta("rule") as ColorRect).color = UiKit.club_vivid(str(GameState.my_club), UiKit.SURFACE) if changed else Color.TRANSPARENT
	_break_refresh.call()

	var quarter_head: Control = take.call("QuarterHeading")
	var facts: Control = take.call("QuarterFacts")
	var did_head: Control = take.call("CallsDidHeading")
	var did: Control = take.call("CallsDid")
	var legs: Control = take.call("LegsView")
	var best: Control = take.call("BestSoFar")
	var start: Button = c["start"]
	var skip: Button = c["skip"]
	var put := func(to: Control, n: Control) -> void:
		if n == null:
			return
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		to.add_child(n)
	if not wide:
		# A phone: the quarter, what your calls did, the rows. Best so far and
		# the full numbers are one tap away, beside the heading.
		var head := UiKit.hbox(8)
		if quarter_head != null:
			quarter_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			put.call(head, quarter_head)
		var stats: Control = take.call("BreakStats")
		var open_best := UiKit.text_action("Best so far ›", UiKit.BODY)
		open_best.name = "BestSoFarOpen"
		open_best.pressed.connect(func(): _open_break_sheet("best", "", [best, stats], store))
		head.add_child(open_best)
		v.add_child(head)
		for n in [facts, legs]:
			put.call(v, n)
		if did_head != null:
			v.add_child(UiKit.spacer(2))
		for n in [did_head, did]:
			put.call(v, n)
		v.add_child(rows)
		for key in order:
			var k := str(key)
			(row_of[key] as Button).pressed.connect(func(): _open_break_sheet(k, str(CALL_TITLES[k]), [bodies[k]], store))
		var one := UiKit.hbox(8)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skip.custom_minimum_size = Vector2(0, 48)
		one.add_child(skip)
		one.add_child(start)
		box["footer"].add_child(one)
	else:
		# A PC: the quarter and Best so far, the rows, and the chosen call beside
		# them. The pane keeps the room of its tallest call, so choosing another
		# row never moves the sheet.
		var cols := UiKit.hbox(28)
		cols.name = "BreakColumns"
		var left := UiKit.vbox(6)
		var mid := UiKit.vbox(6)
		var right := UiKit.vbox(6)
		for col in [left, mid, right]:
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			cols.add_child(col)
		right.size_flags_stretch_ratio = 1.15
		for n in [quarter_head, facts, legs]:
			put.call(left, n)
		if did_head != null:
			left.add_child(UiKit.spacer(4))
		for n in [did_head, did]:
			put.call(left, n)
		left.add_child(UiKit.spacer(4))
		put.call(left, best)
		var next_head := UiKit.section("Next quarter")
		mid.add_child(next_head)
		mid.add_child(rows)
		var pane_title := UiKit.section("")
		pane_title.name = "CallPaneTitle"
		right.add_child(pane_title)
		var pane := MarginContainer.new()
		pane.name = "CallPane"
		right.add_child(pane)
		for key in order:
			put.call(pane, bodies[key])
		v.add_child(cols)
		var plain := UiKit.style(Color.TRANSPARENT, 8, 0)
		plain.set_border_width_all(0)
		var chosen_sb := UiKit.style(Color.TRANSPARENT, 8, UiKit.RADIUS, UiKit.TEXT)
		chosen_sb.set_border_width_all(2)
		var select := func(key: String) -> void:
			pane_title.text = str(CALL_TITLES[key])
			pane.set_meta("call", key)
			for k in order:
				(bodies[k] as Control).visible = str(k) == key
				# A flat button draws no surface: the chosen row needs its outline.
				(row_of[k] as Button).flat = false
				for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
					(row_of[k] as Button).add_theme_stylebox_override(state, chosen_sb if str(k) == key else plain)
		for key in order:
			var k := str(key)
			(row_of[key] as Button).pressed.connect(func(): select.call(k))
		var acts := UiKit.hbox(12)
		acts.alignment = BoxContainer.ALIGNMENT_END
		skip.custom_minimum_size = Vector2(220, 48)
		start.custom_minimum_size = Vector2(300, 48)
		var stats_pc: Button = c["stats_pc"]
		if stats_pc != null:
			stats_pc.custom_minimum_size = Vector2(180, 48)
			acts.add_child(stats_pc)
		acts.add_child(skip)
		acts.add_child(start)
		box["footer"].add_child(acts)
		# A mouse, not a thumb: the choices sit a little shorter on the PC sheet.
		for b in cols.find_children("*", "Button", true, false):
			if (b as Button).custom_minimum_size.y == 44.0 and not str(b.name).begins_with("CallRow_"):
				(b as Button).custom_minimum_size.y = 40.0
		# Every call is laid out once, unseen, so the pane can keep the room of
		# the tallest; then only the first shows.
		pane.modulate.a = 0.0
		_settle_call_pane.call_deferred(pane, select, str(order[0]) if not order.is_empty() else "")
	v.add_child(store)
	overlay.set_meta("one_line", true)


## The PC pane measures every call once, keeps the tallest one's room and shows
## the first call.
func _settle_call_pane(pane: MarginContainer, select: Callable, first_key: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(pane):
		return
	pane.custom_minimum_size.y = pane.get_combined_minimum_size().y
	if first_key != "":
		select.call(first_key)
	pane.modulate.a = 1.0


## One call as one row: what it is, quietly, and its answer in bold under it.
## A call changed at this break carries your club's colour down its edge and
## says so. The whole row is the tap.
func _call_row(key: String, label: String) -> Button:
	var b := UiKit.text_action("", UiKit.NAME)
	b.name = "CallRow_" + key
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UiKit.hbox(8)
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 2.0
	h.offset_right = -6.0
	var rule := ColorRect.new()
	rule.name = "RowRule"
	rule.custom_minimum_size = Vector2(4, 0)
	rule.color = Color.TRANSPARENT
	h.add_child(rule)
	var col := UiKit.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UiKit.hbox(6)
	var what := UiKit.line(label, UiKit.SECONDARY, UiKit.MUTED)
	what.name = "RowLabel"
	top.add_child(what)
	var changed := UiKit.line("· changed this break", UiKit.SECONDARY, UiKit.TEXT)
	changed.name = "RowChanged"
	changed.visible = false
	top.add_child(changed)
	col.add_child(top)
	var answer := NameInk.rich(UiKit.NAME, UiKit.TEXT, true, false)
	answer.name = "RowAnswer"
	answer.clip_contents = true
	answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(answer)
	h.add_child(col)
	var chev := UiKit.line("›", UiKit.HEADING, UiKit.MUTED)
	chev.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chev.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(chev)
	for n in b.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("answer", answer)
	b.set_meta("changed", changed)
	b.set_meta("rule", rule)
	return b


## "Max Gawn" as "M. Gawn": a row has one line for two names.
static func _initial_name(full: String) -> String:
	var parts := full.split(" ", false, 1)
	return full if parts.size() < 2 else "%s. %s" % [parts[0].left(1), parts[1]]


static func _surname(full: String) -> String:
	var parts := full.split(" ", false, 1)
	return full if parts.size() < 2 else parts[1]


## A call's answer as its row says it, from the calls as they stand.
func _call_answer(key: String, calls: Dictionary, c: Dictionary) -> String:
	var sim: MatchSim = c["sim"]
	var named := func(id: String, none: String) -> String:
		return none if id == "" else _initial_name(GameDB.player_display_name_by_id(id, none))
	match key:
		"plan":
			for g in GAMEPLANS:
				if str(g[0]) == str(calls["gameplan"]):
					return str(g[1])
			return str(calls["gameplan"])
		"pep":
			for t in PEP_TALKS:
				if str(t[0]) == str(calls["pep"]):
					return str(t[1])
			return str(calls["pep"])
		"rot":
			return str(ROTATION_SHORT.get(str(calls["rotation"]), str(calls["rotation"])))
		"tag":
			if str(calls["tag_id"]) == "":
				return "No tag"
			var target: String = named.call(str(calls["tag_id"]), "their player")
			var who = (c["my_mids"] as Dictionary).get(str(calls["tagger_id"]), c["tagger"])
			return target if who == null else "%s, by %s" % [target, _initial_name(GameDB.player_display_name(who))]
		"mu":
			var duels: Dictionary = sim.duels[_my_side]
			var parts := PackedStringArray()
			for fid in duels:
				parts.append("%s on %s" % [_surname(MatchNotes._pname(str(duels[fid]))), _surname(MatchNotes._pname(str(fid)))])
			if parts.is_empty():
				return "None on their forwards"
			return ", ".join(parts.slice(0, 2)) + ("" if parts.size() <= 2 else " +%d" % (parts.size() - 2))
		"minder":
			var spare: Dictionary = c["opp_spare"]
			if spare.is_empty():
				return "They have no loose defender"
			var him := _initial_name(GameDB.player_display_name(spare))
			if str(calls["minder_id"]) == "":
				return "No one on %s" % him
			return "%s on %s" % [named.call(str(calls["minder_id"]), "No one"), him]
		"loose":
			return named.call(str(calls["interceptor_id"]), "No loose defender")
		"pt":
			var who_through := PackedStringArray()
			for slot in MatchSim.FOCUS_SLOTS:
				if str(calls[slot]) != "":
					who_through.append(named.call(str(calls[slot]), ""))
			return "No one" if who_through.is_empty() else ", ".join(who_through)
		"ruck":
			return named.call(str(calls["main_ruck"]), "No main ruck")
	return ""


## The fact beside the tag: their busiest midfielder so far ("" before anyone
## has had the ball). A fact, never a suggestion.
func _tag_fact_line(sim: MatchSim) -> String:
	var top := ""
	var most := 0
	for r in _roster_side(1 - _my_side):
		if not _taggable_now(sim, r) or not _listed_midfielder(sim, r):
			continue
		var st: Dictionary = (_res.get("players", {}) as Dictionary).get(str(r["id"]), {})
		var n := int(float(st.get("disposals", 0.0)))
		if n > most:
			most = n
			top = GameDB.player_display_name(r)
	return "" if top == "" else "%s has had %d disposals, the most of their midfielders." % [top, most]


## A sheet over the break: one call (or who tags, or Best so far) with Done.
## Its parts are the break's own blocks, lent to the sheet and handed back to
## `home` when it closes, so a pick made here is the pick the quarter starts
## with. Back closes the top sheet (handle_back).
func _open_break_sheet(node_name: String, title: String, parts: Array, home: Node) -> void:
	var box := UiKit.modal_box(self, 640.0, 0.0, _wash())
	var ov: Control = box["overlay"]
	ov.name = "CallSheet_" + node_name
	var v: VBoxContainer = box["body"]
	if title != "":
		var t := UiKit.heading(title, UiKit.H1)
		t.name = "CallSheetTitle"
		v.add_child(t)
	for p in parts:
		if p == null or not is_instance_valid(p):
			continue
		if (p as Node).get_parent() != null:
			(p as Node).get_parent().remove_child(p)
		v.add_child(p)
	var done := UiKit.btn("Done", UiKit.HEADING, true)
	done.name = "CallDone"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(_close_top_break_sheet)
	box["footer"].add_child(done)
	var close := func() -> void:
		for p in parts:
			if p == null or not is_instance_valid(p):
				continue
			if (p as Node).get_parent() != null:
				(p as Node).get_parent().remove_child(p)
			if is_instance_valid(home):
				home.add_child(p)
		ov.queue_free()
		if _break_refresh.is_valid():
			_break_refresh.call()
	_break_sheets.append({"overlay": ov, "close": close})


func _close_top_break_sheet() -> void:
	if _break_sheets.is_empty():
		return
	var s: Dictionary = _break_sheets.pop_back()
	if is_instance_valid(s["overlay"]):
		(s["close"] as Callable).call()


func _close_break_sheets() -> void:
	while not _break_sheets.is_empty():
		_close_top_break_sheet()


## The PC break's call columns and its calls in the order it was built, so a
## call shown later (Who tags, once there is a tag) packs the break again.
var _break_pack_cols: Array = []
var _break_reading: Array = []


## A PC break's calls read in one order down and across the call columns;
## where each column ends follows what is in it this break (a loose defender
## of theirs, a second ruck), so the tallest column is as short as it can be
## and nothing scrolls on a 720-unit screen. A call keeps its words under it.
func _balance_break_columns(cols: Array, again := false) -> void:
	if not again:
		await get_tree().process_frame
	if not is_instance_valid(cols[0]):
		return
	# Packed again (a call shown or hidden since): from the reading order the
	# break was built in, never from the last packing.
	if _break_reading.is_empty():
		for c in cols:
			for n in (c as Node).get_children():
				_break_reading.append(n)
	else:
		for n in _break_reading:
			if is_instance_valid(n):
				(n as Node).get_parent().remove_child(n)
				(cols[0] as Node).add_child(n)
	# Calls in reading order: a call starts a unit; its notes go with it.
	var units := _break_units(cols)
	var sep := float((cols[0] as VBoxContainer).get_theme_constant("separation"))
	var h: Array = _unit_heights(units, sep)
	# Where each column ends, so the tallest column is as short as it can be
	# (every split of the units, in order, into that many columns).
	var n_units := units.size()
	var ends := _best_split(h, cols.size())
	var col := 0
	for k in range(n_units):
		while col < cols.size() - 1 and k >= int(ends[col]):
			col += 1
		var dest: Node = cols[col]
		for n in units[k]:
			(n as Node).get_parent().remove_child(n)
			dest.add_child(n)
	# The reading order is kept while it fits. When even the best run of units
	# is too tall for the screen (both loose men, a tag card, your tally), pack
	# by height instead: the tallest call goes to the shortest column, and each
	# column still lists its calls in reading order.
	if not again:
		await get_tree().process_frame
	if not is_instance_valid(cols[0]):
		return
	var sc: ScrollContainer = null
	var up: Node = cols[0]
	while up != null and sc == null:
		sc = up as ScrollContainer
		up = up.get_parent()
	# Tight counts too: under 8 px to spare, the next line or a longer name
	# would tip it over, so look for the shorter deal.
	if sc == null or (sc.get_child(0) as Control).get_combined_minimum_size().y <= sc.size.y - 8.0:
		_settle_rotations_gap()
		return
	var order := range(n_units)
	order.sort_custom(func(a, b): return float(h[a]) > float(h[b]))
	var load_h: Array = []
	var picks: Array = []
	for c in range(cols.size()):
		load_h.append(0.0)
		picks.append([])
	for k in order:
		var lo := 0
		for c in range(1, cols.size()):
			if float(load_h[c]) < float(load_h[lo]):
				lo = c
		load_h[lo] = float(load_h[lo]) + float(h[k])
		(picks[lo] as Array).append(k)
	# Then improve it: move or swap units out of the tallest column while that
	# lowers the tallest column.
	var improved := true
	while improved:
		improved = false
		var tall := 0
		for c in range(1, cols.size()):
			if float(load_h[c]) > float(load_h[tall]):
				tall = c
		var top := float(load_h[tall])
		for k in (picks[tall] as Array).duplicate():
			for c in range(cols.size()):
				if c == tall:
					continue
				if float(load_h[c]) + float(h[k]) < top - 0.5:
					(picks[tall] as Array).erase(k)
					(picks[c] as Array).append(k)
					load_h[tall] = float(load_h[tall]) - float(h[k])
					load_h[c] = float(load_h[c]) + float(h[k])
					improved = true
					break
				for k2 in (picks[c] as Array).duplicate():
					var d := float(h[k]) - float(h[k2])
					if d > 0.5 and float(load_h[c]) + d < top - 0.5:
						(picks[tall] as Array).erase(k)
						(picks[c] as Array).erase(k2)
						(picks[tall] as Array).append(k2)
						(picks[c] as Array).append(k)
						load_h[tall] = float(load_h[tall]) - d
						load_h[c] = float(load_h[c]) + d
						improved = true
						break
				if improved:
					break
			if improved:
				break
	# The greedy answer can sit a whole call above the best there is (Best so
	# far on the fullest PC break: 551 against 532 with the same blocks), so
	# look for the true shortest tallest column before placing anything.
	var exact := _shortest_tallest(h, cols.size(), load_h.max())
	if not exact.is_empty():
		picks = exact
	for c in range(cols.size()):
		(picks[c] as Array).sort()
		for k in picks[c]:
			for n in units[k]:
				(n as Node).get_parent().remove_child(n)
				(cols[c] as Node).add_child(n)
	_settle_rotations_gap()
	# Best so far shows three a side on a PC, as on a phone, while the break
	# still fits 720 high; when even the best deal overflows, the third of each
	# side goes (the older two-a-side break) and the calls are dealt again.
	if _coach_overlay == null or not is_instance_valid(_coach_overlay):
		return
	if (sc.get_child(0) as Control).get_combined_minimum_size().y > sc.size.y - 8.0:
		var dropped := false
		for r in _coach_overlay.find_children("BestRow_*", "", true, false):
			if (r as Node).has_meta("best_third"):
				(r as Node).get_parent().remove_child(r)
				(r as Node).queue_free()
				dropped = true
		if dropped:
			_balance_break_columns(cols, true)
			return
		# Still too tall: the gap above Rotations is the first thing to give.
		var gap: Node = _coach_overlay.find_child("RotationsGap", true, false)
		if gap != null:
			(gap as Control).visible = false


## The gap above Rotations is only for a block that has something above it.
func _settle_rotations_gap() -> void:
	if _coach_overlay == null or not is_instance_valid(_coach_overlay):
		return
	var blk: Node = _coach_overlay.find_child("RotationsBlock", true, false)
	var gap: Node = blk.find_child("RotationsGap", false, false) if blk != null else null
	if gap != null:
		(gap as Control).visible = blk.get_index() > 0


func _unit_heights(units: Array, sep: float) -> Array:
	var h: Array = []
	for u in units:
		var t := 0.0
		for n in u:
			# Who tags keeps its room hidden or not, so showing it later never
			# moves a call to another column (director, 2026-10-14).
			if (n as Control).visible or (n as Node).has_meta("break_follow"):
				t += (n as Control).get_combined_minimum_size().y + sep
		h.append(t)
	return h


## Every way of dealing the units (heights h) into `parts` columns, searched
## for the one whose tallest column is shortest; tallest calls first, and a
## branch is dropped the moment it cannot beat the best so far. Returns the
## unit numbers in each column, or an empty array when nothing beats `above`
## (the answer the caller already has).
static func _shortest_tallest(h: Array, parts: int, above: float) -> Array:
	var order := range(h.size())
	order.sort_custom(func(a, b): return float(h[a]) > float(h[b]))
	var state := {"best": above - 0.5, "picks": [], "steps": 0}
	var load_h: Array = []
	var cur: Array = []
	for c in range(parts):
		load_h.append(0.0)
		cur.append([])
	_deal(order, 0, h, load_h, cur, state)
	return state["picks"] as Array


static func _deal(order: Array, i: int, h: Array, load_h: Array, cur: Array, state: Dictionary) -> void:
	state["steps"] = int(state["steps"]) + 1
	if int(state["steps"]) > 400000:
		return
	if i == order.size():
		var top := 0.0
		for l in load_h:
			top = maxf(top, float(l))
		if top < float(state["best"]):
			state["best"] = top
			var copy := []
			for col in cur:
				copy.append((col as Array).duplicate())
			state["picks"] = copy
		return
	var k: int = order[i]
	var seen := []
	for c in range(load_h.size()):
		# Two columns with the same load so far are the same choice.
		if seen.has(float(load_h[c])):
			continue
		seen.append(float(load_h[c]))
		var after := float(load_h[c]) + float(h[k])
		if after >= float(state["best"]):
			continue
		load_h[c] = after
		(cur[c] as Array).append(k)
		_deal(order, i + 1, h, load_h, cur, state)
		(cur[c] as Array).pop_back()
		load_h[c] = after - float(h[k])


## The break's calls as units in reading order: a node marked "break_unit"
## starts one, and the nodes after it (its notes) go with it. A node marked
## "break_follow" is the follow-up to the question before it (Tag, then who
## tags; a loose man, then his cards): it never starts a unit, so a packing
## pass can never put the answer before its question or in another column.
static func _break_units(cols: Array) -> Array:
	var units: Array = []
	for c in cols:
		for n in (c as Node).get_children():
			if units.is_empty() or ((n as Node).has_meta("break_unit") and not (n as Node).has_meta("break_follow")):
				units.append([n])
			else:
				(units[-1] as Array).append(n)
	return units


## Split heights h, in order, into `parts` runs so the largest run is
## smallest; returns where each run ends (exclusive).
static func _best_split(h: Array, parts: int) -> Array:
	var n := h.size()
	var pre := [0.0]
	for x in h:
		pre.append(float(pre[-1]) + float(x))
	# best[p][i]: the tallest column splitting the first i units into p columns.
	var best: Array = []
	var cut: Array = []
	for p in range(parts + 1):
		best.append([])
		cut.append([])
		for i in range(n + 1):
			(best[p] as Array).append(INF)
			(cut[p] as Array).append(0)
	best[0][0] = 0.0
	for p in range(1, parts + 1):
		for i in range(n + 1):
			for j in range(i + 1):
				var top := maxf(float(best[p - 1][j]), float(pre[i]) - float(pre[j]))
				if top < float(best[p][i]) - 0.5:
					best[p][i] = top
					cut[p][i] = j
	var ends: Array = []
	ends.resize(parts)
	var i := n
	for p in range(parts, 0, -1):
		ends[p - 1] = i
		i = int(cut[p][i])
	return ends


## A landscape PC window wide enough for the break sheet's columns (the
## Large and TV screen sizes included).
func _wide_break() -> bool:
	var w := UiKit.view_width(self)
	return ScreenLayout.roomy(w, UiKit.view_height(self))


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
		var l := _say(str(t), UiKit.BODY, UiKit.TEXT)
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
	var tagger = sim.tagger_of(_my_side)
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


## A "Gain:" / "Cost:" style row: the marker bold, the sentence beside it, both
## in full ink (the card-stakes pattern).
func _plan_row(mark: String, text: String, node_name: String) -> Control:
	var item := UiKit.hbox(6)
	item.name = node_name
	var mk := UiKit.lbl(mark, UiKit.SECONDARY, UiKit.TEXT, true)
	mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mk.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.add_child(mk)
	var l := _say(text, UiKit.SECONDARY, UiKit.TEXT)
	l.name = "Text"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(l)
	return item


## A call's words as short separate lines in full ink: the first bold, then one
## line for each clause ("; " and ": " break a line).
func _fill_note_lines(into: VBoxContainer, text: String) -> void:
	for c in into.get_children():
		into.remove_child(c)
		c.queue_free()
	var bits := text.replace(": ", "|").replace("; ", "|").split("|", false)
	for i in range(bits.size()):
		var piece := str(bits[i]).strip_edges()
		piece = piece.substr(0, 1).to_upper() + piece.substr(1)
		var l := UiKit.lbl(piece, UiKit.BODY if i == 0 else UiKit.SECONDARY, UiKit.TEXT, i == 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		into.add_child(l)


## The calls so far this match, one line a quarter played, under a call's words:
## "Q1  Demons: Defensive press  ·  Crows: Attack corridor". Game plans are
## shown for both clubs (the break already tells you theirs). Pep talks and
## rotations of the other club are hidden from the coach, so those show only
## yours. Nothing before the first bounce.
func _calls_record(kind: String) -> Control:
	var hist: Array = GameState.pending_sim.tactics_history
	if hist.is_empty():
		return null
	var v := UiKit.vbox(3)
	v.name = "CallsRecord_" + kind
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.lbl("Calls so far", UiKit.SECONDARY, UiKit.TEXT, true))
	for e in hist:
		var plans: Array = e["plans"]
		var side_words := func(side: int) -> String:
			if kind == "gameplan":
				return CoachReport.plan_label(str((plans[side] as Dictionary).get("gameplan", "balanced")))
			if kind == "pep":
				return CoachReport.pep_label(str((plans[side] as Dictionary).get("pep", "steady")))
			var rot := str((e.get("rotations", ["normal", "normal"]) as Array)[side])
			return str(ROTATION_SHORT.get(rot, rot))
		var sides: Array = [_my_side, 1 - _my_side] if kind == "gameplan" else [_my_side]
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 0)
		row.name = "CallsRecordRow_Q%d" % int(e["quarter"])
		var qn := UiKit.lbl("Q%d  " % int(e["quarter"]), UiKit.SECONDARY, UiKit.TEXT, true)
		qn.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(qn)
		for i in range(sides.size()):
			var side: int = sides[i]
			var code := str((sim_squad_code(side)))
			if i > 0:
				var dot := UiKit.lbl("  ·  ", UiKit.SECONDARY, UiKit.TEXT)
				dot.autowrap_mode = TextServer.AUTOWRAP_OFF
				row.add_child(dot)
			var nm := UiKit.lbl(GameDB.club_short(code) + ": ", UiKit.SECONDARY,
					UiKit.club_name_colour(UiKit.club_ink(code)), true)
			nm.name = "ClubName%d" % i
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(nm)
			var w := UiKit.lbl(str(side_words.call(side)), UiKit.SECONDARY, UiKit.TEXT)
			w.name = "CallWords%d" % i
			w.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(w)
		v.add_child(row)
	return v


func sim_squad_code(side: int) -> String:
	return str((GameState.pending_sim.squads[side] as Squad).code)


func _synergy_names(keys: Array) -> String:
	var out: PackedStringArray = []
	for k in keys:
		out.append(Traits.with_effect(str(k)))
	return ", ".join(out) if not out.is_empty() else "none"


## The two sides' synergies, a block of their own under a heading: yours, then theirs.
func _synergy_block() -> Control:
	var syn: Array = GameState.pending_sim.synergies
	var v := UiKit.vbox(3)
	v.name = "SynergyBlock"
	v.add_child(UiKit.lbl("Synergies", UiKit.SECONDARY, UiKit.TEXT, true))
	v.add_child(_plan_row("Yours:", _synergy_names(syn[_my_side]), "SynYours"))
	v.add_child(_plan_row("Theirs:", _synergy_names(syn[1 - _my_side]), "SynTheirs"))
	return v


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
		var l2 := _say("%s  %s: %s. %s" % [_clock_text(int(m["q"]), int(m["min"])),
				str(m.get("title", "")), str(m.get("choice_label", "")), str(m.get("outcome", ""))],
				12, UiKit.EMPH if int(m.get("points", 0)) >= 6 else UiKit.TEXT)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	var tag_line := _tag_line(q)
	if tag_line != "":
		v.add_child(_say(tag_line, 12, UiKit.TEXT))
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
			var fl := _say(str(f), UiKit.BODY, UiKit.TEXT, true)
			fl.name = "BounceFact"
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(fl)
	var text := _say(str(m.get("text", "")), 14, UiKit.TEXT)
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
		var fl := _say(str(f), UiKit.BODY, UiKit.TEXT, true)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		call.add_child(fl)
	var text := _say(str(m.get("text", "")), UiKit.SMALL, UiKit.MUTED)
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
## A call's heading on the break: bold, in the text colour rather than
## muted, so it reads at a glance (director, 2026-10-11); the lines under it
## stay regular.
func _call_heading(label: String) -> Label:
	var l := UiKit.lbl(label, UiKit.SMALL, UiKit.TEXT, true)
	l.name = "CallHeading"
	return l


func _call_block(label: String, control: Control) -> Control:
	var v := UiKit.vbox(4 if _pc_break else 6)
	v.set_meta("break_unit", true)
	v.add_child(_call_heading(label))
	v.add_child(control)
	return v


## One tap picks one (UiKit.choice_grid); the key lands in calls[field]
## and on_change(key) runs.
func _choice_grid(node_name: String, options: Array, calls: Dictionary, field: String, columns: int,
		on_change: Callable = Callable()) -> Control:
	var grid_box := [null]
	var grid := UiKit.choice_grid(node_name, options, str(calls[field]), columns, func(key: String):
		calls[field] = key
		_ink_choices(grid_box[0])
		if on_change.is_valid():
			on_change.call(key)
		if _break_refresh.is_valid():
			_break_refresh.call())
	grid_box[0] = grid
	_ink_choices(grid)
	return grid


## The choices of a call are what the coach is deciding between: every one
## reads at body-text strength, and only the chosen one is outlined (lead's QC,
## 2026-10-14: the names not chosen read as faint grey; design bible, second
## pillar: nothing he decides on sits in grey). UiKit.paint_choice greys the
## rest for the screens where the rest can be skipped; not here.
func _ink_choices(grid: Node) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	for b in grid.get_children():
		if b is Button:
			(b as Button).add_theme_color_override("font_color", UiKit.TEXT)


## Three short words in one line (UiKit.segmented): the plan and the tag
## keep their grids, where the labels are names and whole phrases.
func _segmented(node_name: String, options: Array, calls: Dictionary, field: String,
		on_change: Callable = Callable()) -> Control:
	return UiKit.segmented(node_name, options, str(calls[field]), func(key: String):
		calls[field] = key
		if on_change.is_valid():
			on_change.call(key)
		if _break_refresh.is_valid():
			_break_refresh.call())


## A player call: "none", the few in the game so far, whoever is chosen,
## and "Other player..." for everyone in `roster` (the caller's choice: the
## whole side for a tag, only forwards for their loose defender). Nobody in
## it is left out; the list is just ordered.
## `detail` (optional): player, wide -> the lines under his name on his card
## ("" for none); wide is the list sheet's one-line form.
func _player_choice(node_name: String, none_label: String, roster: Array, first: Array,
		calls: Dictionary, field: String, sheet_title: String, on_change: Callable = Callable(),
		detail: Callable = Callable(), card: Callable = Callable(), other_label := "Other player…",
		rest_only := false) -> Control:
	var box := UiKit.vbox(0)
	box.name = node_name
	var rebuild := func(self_ref: Callable) -> void:
		UiKit.clear(box)
		var shown := [["", none_label]]
		var ids := {}
		for r in first:
			shown.append([str(r["id"]), _card_text(r, detail)])
			ids[str(r["id"])] = true
		var cur := str(calls[field])
		if cur != "" and not ids.has(cur):
			for r in roster:
				if str(r["id"]) == cur:
					shown.append([cur, _card_text(r, detail)])
		var grid := _choice_grid(node_name + "Grid", shown, calls, field, 2, on_change)
		box.add_child(grid)
		# rest_only: the list behind the button is who is not already a button
		# here, and with nobody left there is no button.
		var listed: Array = roster
		if rest_only:
			var on_show := {}
			for o in shown:
				on_show[str(o[0])] = true
			listed = roster.filter(func(r): return not on_show.has(str(r["id"])))
		var other: Button = null
		if not (rest_only and listed.is_empty()):
			other = UiKit.btn(other_label, 14)
			other.name = node_name + "Other"
			other.custom_minimum_size = Vector2(0, 44)
			other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			other.pressed.connect(func():
				_player_sheet(sheet_title, listed, str(calls[field]), detail, func(id: String):
					calls[field] = id
					if on_change.is_valid():
						on_change.call(id)
					self_ref.call(self_ref)
					if _break_refresh.is_valid():
						_break_refresh.call()))
			grid.add_child(other)
		if card.is_valid():
			# Cards set their own facts (_dress_tagger_card): one to a line on
			# a phone, side by side on a PC, "Other player..." last.
			grid.columns = 2 if _pc_break else 1
			for gb in grid.get_children().duplicate():
				if gb is Button and gb != other:
					card.call(gb, str(gb.name).trim_prefix(node_name + "Grid_"))
			return
		# On a PC, cards with a detail line sit together in their own row and
		# "Other player..." beside the none choice: two short buttons share a
		# row instead of each standing beside a tall card.
		if _pc_break and detail.is_valid() and not none_label.contains("\n") and other != null:
			grid.move_child(other, 1)
		if _pc_break:
			for gb in grid.get_children():
				(gb as Control).custom_minimum_size.y = 38.0
	rebuild.call(rebuild)
	return box


## A player's card text: his name, then what `detail` says about him.
func _card_text(r: Dictionary, detail: Callable) -> String:
	# A card keeps its groups on their own lines (MatchNotes.card_detail).
	var extra := str(detail.call(r, false)) if detail.is_valid() else ""
	return _short_name(r) if extra == "" else "%s
%s" % [_short_name(r), extra]


## A "Who tags" card (director, 2026-10-13: it must read at a glance): his name
## in bold with where he plays small beside it, then three short facts, one to
## a line, label quiet and value clear (his Pressure, his legs, what he gives
## up of his own game). Your club's colour is the rule down the left edge;
## selection stays the button's own text outline. The button stays the card's
## background and its tap target, under the words; its words are kept in the
## "card_text" meta for the tests.
func _dress_tagger_card(b: Button, who_name: String, c: Dictionary, is_pick: bool) -> void:
	var gives_value := str(c["gives"]).left(1).to_upper() + str(c["gives"]).substr(1)
	var plain := "%s\n%s\nPressure %s\nLegs %s\n%s %s" % [who_name, c["where"], c["pressure"], c["legs"],
			c["gives_label"], gives_value]
	if is_pick:
		plain += "\nYour assistant's pick"
	b.set_meta("card_text", plain)
	b.text = ""
	var grid := b.get_parent()
	var at := b.get_index()
	var wrap := MarginContainer.new()
	wrap.name = "Card_" + str(b.name)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.remove_child(b)
	grid.add_child(wrap)
	grid.move_child(wrap, at)
	wrap.add_child(b)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	wrap.add_child(pad)
	var row := UiKit.hbox(10)
	pad.add_child(row)
	# Your side's colour, in the shade of it that reads on the card.
	var rule := ColorRect.new()
	rule.name = "ClubRule"
	rule.color = UiKit.club_vivid(str(GameState.my_club), UiKit.SURFACE)
	rule.custom_minimum_size = Vector2(4, 0)
	row.add_child(rule)
	var col := UiKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	head.add_theme_constant_override("v_separation", 0)
	var nm := UiKit.line(who_name, UiKit.NAME, UiKit.TEXT, true)
	nm.name = "CardName"
	if _names().has(who_name):
		nm.add_theme_color_override("font_color", UiKit.club_ink(str(_names()[who_name])))
	head.add_child(nm)
	var where := UiKit.line(str(c["where"]), UiKit.SECONDARY, UiKit.MUTED)
	where.name = "CardWhere"
	head.add_child(where)
	col.add_child(head)
	var rows := [["Pressure", str(c["pressure"]), false], ["Legs", str(c["legs"]), bool(c["legs_bad"])],
			[str(c["gives_label"]), gives_value, false]]
	# A phone card is wide: label and value in two columns. A PC's card is a
	# narrow half of a column: the label above the long value instead.
	var facts: Container = VBoxContainer.new() if _pc_break else GridContainer.new()
	if _pc_break:
		facts.add_theme_constant_override("separation", 2)
	else:
		(facts as GridContainer).columns = 2
		facts.add_theme_constant_override("h_separation", 10)
		facts.add_theme_constant_override("v_separation", 2)
	for f in rows:
		var k := UiKit.line(str(f[0]), UiKit.SECONDARY, UiKit.MUTED)
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var v := UiKit.lbl(str(f[1]), UiKit.BODY, UiKit.BAD if bool(f[2]) else UiKit.TEXT)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pc_break and str(f[0]) != str(c["gives_label"]):
			var one := HBoxContainer.new()
			one.add_theme_constant_override("separation", 8)
			one.add_child(k)
			one.add_child(v)
			facts.add_child(one)
		elif _pc_break:
			facts.add_child(k)
			facts.add_child(v)
		else:
			facts.add_child(k)
			facts.add_child(v)
	facts.name = "CardFacts"
	col.add_child(facts)
	if is_pick:
		var pick := UiKit.line("Your assistant's pick", UiKit.SECONDARY, UiKit.MUTED)
		pick.name = "CardPick"
		pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(pick)
	for n in wrap.find_children("*", "Control", true, false):
		if n != b:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _short_name(r: Dictionary) -> String:
	return GameDB.player_display_name_by_id(str(r.get("id", "")), str(r.get("name", "Player")))


## Everyone on the ground for one side, one tap each; the current choice is
## marked. Back or Close leaves it as it was.
func _player_sheet(title: String, roster: Array, current: String, detail: Callable, on_pick: Callable) -> void:
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
		var extra := str(detail.call(r, true)) if detail.is_valid() else ""
		var game := "" if st.is_empty() else MatchNotes.game_line(st)
		if extra == "":
			if game != "":
				line += "  ·  " + game
		elif game != "":
			extra += "  ·  " + game
		var b := UiKit.btn(line if extra == "" else line + "
" + extra, 14)
		b.name = "Sheet_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if extra == "":
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			# Two lines of facts about him: wrapped in full, never cut.
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 44 if extra == "" else 60)
		UiKit.paint_choice(b, id == current)
		NameInk.dress_button(b, _names())
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


## A listed midfielder of theirs: midfield is his own position, wherever he
## lines up now. The break's tag names offer only these (director, 2026-10-14:
## a ruck in a midfield slot and a defender with midfield second were offered
## under "Tag which midfielder?"). The sim's own rule (MatchSim.tag_target_ok)
## is untouched; the tag's names and "Other midfielder..." both offer only these.
func _listed_midfielder(sim: MatchSim, r: Dictionary) -> bool:
	var id := str(r["id"])
	var p := sim._on_ground(1 - _my_side, id)
	if p.is_empty():
		for b in (sim.squads[1 - _my_side] as Squad).bench:
			if str(b["id"]) == id:
				p = b
	return str(p.get("own_role", p.get("role", ""))) == "MID"


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
func _show_break_stats(players_first := false) -> void:
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
	var msv := MatchStatsView.new()
	msv.players_first = players_first
	v.add_child(msv.setup(_res, _my_side, true))
	var close := UiKit.btn("Back to your calls", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_report)
	box["footer"].add_child(close)


## Best so far, on the break: the three best of each side by match rating so
## far (yours first), each with his rating and the numbers that stand out, as
## full time's best players read; "All player stats" opens the full table.
# A PC break is tight (the fullest one, GWS with both loose men, has 8 px to
# spare and Best so far may be at most ~213 px tall), so the rows sit 4 px apart
# there; a phone scrolls and has room for more.
const BEST_ROW_GAP_PC := 2


func _best_so_far() -> Control:
	var box := UiKit.vbox(4 if _pc_break else 6)
	box.name = "BestSoFar"
	box.set_meta("break_unit", true)
	var head := UiKit.hbox(8)
	var title := UiKit.section("Best so far")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var all := UiKit.btn("All player stats", UiKit.BODY)
	all.name = "BestSoFarAll"
	all.custom_minimum_size = Vector2(0, 24 if _pc_break else 44)
	all.pressed.connect(func(): _show_break_stats(true))
	# On a PC the way to the table sits in the heading row (shorter block: the
	# fullest break still fits 1280x720); a phone has it under the list.
	if _pc_break:
		head.add_child(all)
	box.add_child(head)
	# Your club first, then theirs, each under its own name, best rated first;
	# the same number each side: three, as on a phone, and on a PC the third
	# goes (row meta best_third) when the break would not fit 720 high with it.
	# Allegiance (director 2026-10-13): each side carries its club's colour (bar,
	# guernsey, name, rating) where it reads; see UiKit.club_heading.
	# One screen, both clubs: the pair helper gives the away side its second ink
	# when the two first inks look alike (a clash guernsey).
	var inks := UiKit.club_ink_pair(str(_res["home"]), str(_res["away"]))
	for side in [_my_side, 1 - _my_side]:
		var code := str(_res["home"] if side == 0 else _res["away"])
		var side_box := UiKit.vbox(4 if _pc_break else 6)
		var rows_box := UiKit.vbox(BEST_ROW_GAP_PC if _pc_break else 8)
		# The column heading is a label he can skip: quiet, lighter than the
		# figures under it.
		# Said once, in the first club's heading: both columns line up under it.
		var rh: Label = null
		if side == _my_side:
			rh = UiKit.lbl("Rating", UiKit.SECONDARY, UiKit.MUTED)
			rh.name = "RatingHeading"
			rh.custom_minimum_size.x = 56
			rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var sh := UiKit.club_heading(code, rh, UiKit.BODY if _pc_break else UiKit.NAME, 20.0 if _pc_break else 22.0, inks[side])
		sh.get_node("ClubName").name = "BestClub_%d" % side
		side_box.add_child(sh)
		var shown := 0
		for p in MatchNotes.standouts(_res, side, 3):
			shown += 1
			var row := UiKit.hbox(8)
			row.name = "BestRow_%s" % str(p["id"])
			if _pc_break and shown == 3:
				row.set_meta("best_third", true)
			var col := UiKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UiKit.emphasis(str(p["name"]), UiKit.BODY if _pc_break else UiKit.NAME))
			# A PC column is narrow: two numbers fit on the line, a third ran
			# off it ("6 rebound 5...", capture 2026-10-12).
			var bits: PackedStringArray = str(p["line"]).split(", ")
			var line := ", ".join(bits.slice(0, 2)) if _pc_break else str(p["line"])
			# Under the bold name, a step down in size and tone, still readable.
			col.add_child(UiKit.ellipsis(line, UiKit.SECONDARY, UiKit.TEXT.lerp(UiKit.MUTED, 0.4)))
			row.add_child(col)
			# The figure says how well, in bold TEXT: the club colour says who, and
			# a red or pink number would read as BAD beside the red Start button.
			var r := UiKit.line(MatchNotes.rating_text(float(p["rating"])), 20, UiKit.TEXT, true)
			r.name = "StandoutRating"
			r.custom_minimum_size.x = 56
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r)
			rows_box.add_child(row)
		side_box.add_child(rows_box)
		var wrap := UiKit.club_section_body(code, side_box, inks[side])
		wrap.name = "BestSide_%d" % side
		side_box.name = "BestSideBox_%d" % side
		box.add_child(wrap)
	if not _pc_break:
		box.add_child(all)
	return box


func _glance_section(v: VBoxContainer, title: String, node_name: String, lines: Array) -> void:
	if lines.is_empty():
		return
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section(title))
	var box := UiKit.vbox(4)
	box.name = node_name
	for t in lines:
		var l := _say(str(t), UiKit.BODY, UiKit.TEXT)
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
		row.add_child(_say(str(p["name"]), UiKit.BODY, UiKit.TEXT, true))
		row.add_child(_say(str(p["line"]), UiKit.SMALL, UiKit.MUTED))
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


## Your rucks on the ground now, the best tap man first: a ruckman by his own
## listing, wherever he lines up. Two of them is a dual-ruck side, where the
## call changes who goes up (BOSS 2026-10-11; audit mainruck_impl: a second
## ruck on the bench mostly comes on for the first, through the ruck spot).
func _my_rucks(sim: MatchSim) -> Array:
	var sq: Squad = sim.squads[_my_side]
	var out := sq.ground.filter(func(p): return MatchSim._is_ruckman(p))
	out.sort_custom(func(a, b): return float(a["attr"]["ruck"]) > float(b["attr"]["ruck"]))
	return out


## Under the Main ruck call: who goes up, and who does while he rests.
func _main_ruck_note(rucks: Array, id: String) -> String:
	if id == "":
		return "No main ruck: whoever is in the ruck spot goes up. While he is on the bench, another ruck does."
	var others := rucks.filter(func(r): return str(r["id"]) != id)
	var next := GameDB.player_display_name(others[0]) if others.size() == 1 else "another ruck"
	return "%s goes up at every stoppage while he is on the ground, wherever he lines up, and tires like a ruck for it. While he is on the bench, %s does." % [
			GameDB.player_display_name_by_id(id, "Your ruck"), next]


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
func _focus_note_text(slot: String, id: String) -> String:
	if id == "":
		return MatchNotes.focus_slot_note(slot, "", false, false)
	var who := GameDB.player_display_name_by_id(id, "your player")
	var on := false
	var working := false
	var sim: MatchSim = GameState.pending_sim
	if sim != null:
		for p in (sim.squads[_my_side] as Squad).ground:
			if str(p["id"]) == id:
				on = true
				working = (MatchSim.FOCUS_SLOT_ROLES[slot] as Array).has(str(p["role"]))
	return MatchNotes.focus_slot_note(slot, who, working, not on)


## "Defensive press · tagging Walsh": your calls for this quarter, one line.
func _show_setup(t: Dictionary) -> void:
	if _setup_line == null or not is_instance_valid(_setup_line):
		return
	var bits := PackedStringArray(["Your plan: " + CoachReport.plan_label(str(t.get("gameplan", "balanced")))])
	var tag_id := str(t.get("tag_id", ""))
	if tag_id != "":
		bits.append("tagging " + GameDB.player_display_name_by_id(tag_id, "their player"))
	for slot in MatchSim.FOCUS_SLOTS:
		var fid := str(t.get(slot, ""))
		if fid != "":
			bits.append("%s %s" % [GameDB.player_display_name_by_id(fid, "your player"),
					str(MatchNotes.FOCUS_SLOT_TEXT[slot][1])])
	var legacy := str(t.get("focus_id", ""))
	if legacy != "":
		bits.append(_focus_text(legacy))
	var intercept_id := str(t.get("interceptor_id", ""))
	if intercept_id != "":
		bits.append(GameDB.player_display_name_by_id(intercept_id, "your defender") + " loose behind the ball")
	if bool(t.get("spare_accountable", false)):
		# Whoever is on him now: the named forward, or his stand-in if he's off.
		var sim_now = GameState.pending_sim
		var on_him: Dictionary = sim_now._spare_minder(_my_side) if sim_now != null else {}
		var who := GameDB.player_display_name(on_him) if not on_him.is_empty() 				else GameDB.player_display_name_by_id(str(t.get("spare_minder_id", "")), "a forward")
		bits.append(who + " on their spare")
	var ruck_id := str(t.get("main_ruck", ""))
	if ruck_id != "":
		bits.append(GameDB.player_display_name_by_id(ruck_id, "your ruck") + " the main ruck")
	NameInk.set_line(_setup_line, "  ·  ".join(bits), _names())
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
	_press_feed(event_index, ev)
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
	# The scorer's club is the event's own, whatever the index knows.
	var names := _names().duplicate()
	if who != "":
		names[who] = code
	var hl := NameInk.label(head, names, UiKit.NAME, UiKit.TEXT, true)
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


## The sides have changed ends: the next period is starting, so the clock shows
## it from its first minute rather than the last minute of the one before.
func _on_ends_changed(_period: int) -> void:
	if _finished or _skipping:
		return
	_shown_q += 1
	_shown_min = (_shown_q - 1) * QUARTER_MINUTES
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


## The players of both clubs in this match, by name, so a name in a sentence can
## wear his club's colour (NameInk). Built from the squads, never from the text.
func _names() -> Dictionary:
	if not _name_index.is_empty():
		return _name_index
	var lists := []
	var codes := []
	var sim: MatchSim = GameState.pending_sim
	if sim != null and sim.squads.size() == 2:
		for sq in sim.squads:
			lists.append((sq as Squad).list + (sq as Squad).ground + (sq as Squad).bench)
			codes.append(str((sq as Squad).code))
	else:
		var roster: Array = _res.get("roster", [])
		for side in range(mini(2, roster.size())):
			lists.append(roster[side])
			codes.append(str(_res["home"]) if side == 0 else str(_res["away"]))
	_name_index = NameInk.from_squads(lists, codes)
	return _name_index


## A line whose words change later (the break match-up line): always tinted-capable.
func _say_live(text: String, fs: int, col: Color) -> RichTextLabel:
	var r := NameInk.rich(fs, col)
	NameInk.set_line(r, text, _names())
	return r


## A line of the match's talk: plain, or with each player's name in his club's ink.
func _say(text: String, fs: int, col: Color, bold := false) -> Control:
	return NameInk.label(text, _names(), fs, col, bold)


func _feed_text(text: String, col: Color, strong: bool, node_name: String) -> void:
	if _feed == null:
		return
	var l := _say(text, UiKit.SMALL, col, strong)
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
	# Full time is built at once (its controls exist and work the moment the siren goes);
	# a milestone game's farewell plays over it on its own layer, and a tap or its end
	# shows full time underneath.
	_show_fulltime()
	if not _farewell.is_empty():
		var v := FarewellVignette.open(get_tree().root, _farewell["ms"], _farewell["man"],
				GameState.my_club, str(_farewell["opp"]), _farewell["mine"], _farewell["theirs"],
				"Full time", str(GameState.pending_match.get("weather", "")) == "wet")
		_farewell = {}
		tree_exiting.connect(func():            # Back out of the match: it goes too
			if is_instance_valid(v):
				v.finish_now())


## Who the scene after the siren honours, and both sides' players: {} unless your
## side has a milestone man (FarewellVignette.caption) who is in the side today.
func _farewell_for(match: Dictionary) -> Dictionary:
	# Vignettes off (Settings) means no scene at all, this one included.
	if GameState.season == null or GameState.my_club == "" or not GameState.vignettes_on():
		return {}
	var ms: Dictionary = GameState.banner_context(match).get("milestone", {})
	if FarewellVignette.caption(ms) == "":
		return {}
	var sq := GameState.my_squad()
	var mine: Array = sq.ground + sq.bench
	var man := {}
	for p in mine:
		if str(p.get("id", "")) == str(ms.get("id", "")):
			man = p
	if man.is_empty():
		return {}
	var opp := str(match["away"]) if str(match["home"]) == GameState.my_club else str(match["home"])
	var season: Season = GameState.season
	var theirs: Array = []
	if season.lists.has(opp):
		var osq := Squad.new(opp, season.lists[opp], false, opp, season.selections.get(opp, {}))
		theirs = osq.ground + osq.bench
	return {"ms": ms, "man": man, "opp": opp, "mine": mine, "theirs": theirs}


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
	UiKit.feel(leave, "end")     # the end of the match: the siren
	box["footer"].add_child(leave)
	_render_ft()
	UiKit.land(overlay.find_child("Verdict", true, false) as Control, 0.3)   # the result lands (Feel)
	UiKit.land(overlay.find_child("LadderMove", true, false) as Control, 1.0, false)   # then the ladder move


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

	# The Grand Final's best on ground, from either side.
	var medal := GameState.norm_smith_for(_res)
	if not medal.is_empty():
		v.add_child(UiKit.spacer(UiKit.GAP))
		v.add_child(UiKit.section("Norm Smith Medal"))
		var mc := UiKit.club_ink(str(medal["club"]))
		var ml := UiKit.lbl("%s (%s)" % [str(medal["name"]), GameDB.club_name(str(medal["club"]))],
				UiKit.NAME, UiKit.club_name_colour(mc), true)
		ml.name = "NormSmithMedal"
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ml)
		var ms := UiKit.lbl(str(medal["line"]), UiKit.BODY, UiKit.TEXT)
		ms.name = "NormSmithLine"
		ms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ms)

	# How it went: the few things that decided it, in football words.
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section("How it went"))
	var factors := VBoxContainer.new()
	factors.name = "MatchFactors"
	factors.add_theme_constant_override("separation", 4)
	for f in MatchNotes.match_factors(_res, me if mine else 0):
		var fl := _say(str(f), UiKit.BODY, UiKit.TEXT)
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
	v.add_child(UiKit.ellipsis(name, UiKit.BODY, UiKit.club_ink(code), true))
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
	# A call's sheet on the break closes next, the top one first; the break stays.
	if not _break_sheets.is_empty():
		_close_top_break_sheet()
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
		# A farewell shown at full time lives on the root: leaving by Back must not
		# leave it standing over the next screen.
		var tree := get_tree()
		if tree != null:
			var fv := tree.root.find_child("FarewellVignette", true, false)
			if fv != null:
				var holder := fv.get_parent()
				(holder if holder is CanvasLayer else fv).queue_free()


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
		_orient_pitch(stack)
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
		var loose := _say("%s is roaming loose behind their backline." % GameDB.player_display_name(their_spare),
				UiKit.BODY, UiKit.TEXT)
		loose.name = "OppInterceptor"
		loose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(loose)
	var our_spare := sim._roaming_interceptor(_my_side)
	if not our_spare.is_empty():
		var loose2 := _say("Yours: %s is roaming as the spare." % GameDB.player_display_name(our_spare),
				UiKit.SMALL, UiKit.MUTED)
		loose2.name = "MyInterceptor"
		loose2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(loose2)
	for fid in theirs.keys():
		var row := UiKit.hbox(8)
		row.name = "BreakMatchup_" + str(fid)
		var l := _say_live(_matchup_text(str(fid), str(theirs[fid]), q), UiKit.BODY, UiKit.TEXT)
		l.name = "MatchupLine"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		# An editorial row with its action as a word (audit §8 Phase 1.5).
		var b := UiKit.text_action("Change", UiKit.SECONDARY)
		b.name = "ChangeMatchup"
		var f := str(fid)
		b.pressed.connect(func(): _show_break_matchup(sim, f, l, q))
		row.add_child(b)
		v.add_child(row)
	for fid in ours.keys():
		var l2 := _say("Yours: " + _matchup_text(str(fid), str(ours[fid]), q), UiKit.SMALL, UiKit.MUTED)
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
func _show_break_matchup(sim: MatchSim, fid: String, line: RichTextLabel, q: int) -> void:
	if _matchup_overlay != null and is_instance_valid(_matchup_overlay):
		_matchup_overlay.queue_free()
	var box := UiKit.modal_box(self, 480.0, 0.0, _wash())
	_matchup_overlay = box["overlay"]
	_matchup_overlay.name = "MatchupChooser"
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	var fwd := sim._on_ground(1 - _my_side, fid)
	v.add_child(_say("Who goes to %s?" % MatchNotes._pname(fid), UiKit.H1, UiKit.TEXT, true))
	if not fwd.is_empty():
		v.add_child(UiKit.lbl(Matchups.describe(fwd), UiKit.SMALL, UiKit.MUTED))
	var cur := str((sim.duels[_my_side] as Dictionary).get(fid, ""))
	for p in Matchups.defenders((sim.squads[_my_side] as Squad).ground):
		var b := UiKit.btn("%s\n%s" % [GameDB.player_display_name(p), Matchups.describe(p)], 15)
		b.name = "Defender_" + str(p["id"])
		b.custom_minimum_size = Vector2(0, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.paint_choice(b, str(p["id"]) == cur)
		NameInk.dress_button(b, _names())
		var pid := str(p["id"])
		b.pressed.connect(func():
			sim.coach_matchup(_my_side, fid, pid)
			NameInk.set_line(line, _matchup_text(fid, pid, 1).trim_suffix(".") + " from the next bounce.", _names())
			if _break_refresh.is_valid():
				_break_refresh.call()
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


## The Defensive press taking hold, once a side a match: the first time the
## side whose plan it is defends after setting it (V2, press pilot).
func _press_feed(event_index: int, ev: Dictionary) -> void:
	var presser := MatchNotes.press_trigger(_res.get("timeline", []), event_index, ev, _press_said)
	if presser < 0:
		return
	_press_said[presser] = true
	var code := str(_res["home"] if presser == 0 else _res["away"])
	_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), MatchNotes.press_line(code)],
			UiKit.TEXT, false, "PressLine")


## The battle in the feed, rarely (MatchNotes.duel_feed_line).
func _duel_feed(ev: Dictionary) -> void:
	var text := MatchNotes.duel_feed_line(_duel_mem, ev)
	if text != "":
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), text],
				UiKit.TEXT, false, "DuelLine")
