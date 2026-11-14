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
## The score figure on a wide window that keeps the scoreboard across the top
## (a phone on its side); _fit_scores shrinks from here.
const WIDE_SCORE := 46
## A PC's score figure, in the column beside the oval; _fit_scores shrinks from here.
const PC_SCORE := 36
## A PC (director, 2026-11-12: "oval left, panels right"): the oval's share of
## the width against the column's, and the least the column is given.
const PC_OVAL_SHARE := 2.0
const PC_COLUMN_MIN_W := 300.0

## The scenes' kick-off light (its own script; this screen runs without it).

var _res := {}
var _pitch: PitchView
var _root: VBoxContainer
var _score_home: Label
var _score_away: Label
## The band behind both scores: its width is what the two scores must share.
var _score_band: Control
var _clock: Label
## What the clock says while no football is being played: "Pre-match" until the
## first bounce, the break's name at each break, "Full time" at the end. Empty
## while a quarter is on, when the clock shows its minute ("Q3 12'").
var _clock_word := ""
## Each stoppage's words, longest first: the clock takes the first that fits its
## place between the scores (a phone's is 84 wide).
const CLOCK_WORDS := {
	"pre": ["Pre-match"],
	"q1": ["Quarter time", "Qtr time"],
	"q2": ["Half time"],
	"q3": ["Three-quarter time", "3/4 time"],
	"full": ["Full time"],
}
const CLOCK_BREAKS := {1: "pre", 2: "q1", 3: "q2", 4: "q3"}
## The play, speed and skip buttons, under the oval or beside it. Out of sight
## and out of reach while a sheet is up over them (_sync_under_sheet).
var _controls_box: Control
var _feed: VBoxContainer
var _feed_scroll: ScrollContainer
var _feed_waiting: Label     # a PC, before the bounce: what the feed will hold
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
## Your side's legs (id -> energy) when the stretch now playing was simulated:
## the tired marks read these until the oval catches up with the sim.
var _legs_seen := {}
var _my_side := 0
var _margin: MarginContainer
var _stacked := false
## A PC: the oval takes the left two-thirds, and the scoreboard, the feed, the
## numbers and the controls stand in one column to its right (_right).
var _pc := false
var _right: VBoxContainer
var _board: Control          # the scoreboard: across the top, or first in a PC's column
## A PC's numbers beside the oval (LiveStats): scoring shots and inside 50s as
## they happen, the rest as the stats sheet had them at the last break.
var _live_stats: VBoxContainer
var _live_i50 := [0, 0]
var _live_break := 0         # the break those totals are from: 0 none yet, 1-3, 4 or more the end
var _last_tactics := {}
var _skipping := false
## Skip to the next break (director, 2026-11-06): beside Skip to full time in
## the first three quarters. Quarter breaks opened so far (set as each opens).
var _break_skip: Button
var _breaks_played := 0
const BREAK_NAMES := ["quarter time", "half time", "three-quarter time"]
var _crowd: CrowdSound = null    # FL-004: the crowd (presentation only)
var _fulltime_shown := false
## FL-007: the milestone this match honours after the siren (GameState's banner
## milestone, read before full time counts the game), or {} for none.
var _farewell := {}
var _coach_overlay: Control
var _sheet_overlay: Control
var _over: Control   # T3.R42: every sheet, call and scene opens here, under the scoreboard
var _reflow_queued := false
var _shown_goals := [0, 0]
var _shown_behinds := [0, 0]
var _shown_q := 1
var _shown_min := 0
var _moment_overlay: Control
var _warmed_call := false   # _warm_call_scene ran this match
const WARM_FRAMES := 3
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
var _mom_bar: Button          # the meter (its foot is the scoreboard's, the line aside)
const SCORE_BAND_PAD := 8
## The break is the PC sheet (four columns): player cards say their detail
## on one line and choices sit PC_CHOICE_H tall (a mouse, not a thumb).
var _pc_break := false
## True on a PC break from quarter time on: one line a call, the chosen call in a wide pane.
var _pc_one_line := false
var _pos_before := 0          # your ladder spot before this match
var _lead: Label
var _setup_line: RichTextLabel
var _report_overlay: Control
var _ft_box := {}               # the full-time review: overlay, body, footer
var _ft_tabs: HBoxContainer
var _ft_tab := "summary"        # summary (home), stats or report
var _run_side := -1            # who kicked the last goal, and how many in a row
var _run_len := 0
var _press_said := [false, false]  # the High Press line, once a side
var _call_mem := MatchNotes.call_state()  # the structural calls' lines (MatchNotes.call_lines)
var _name_index := {}           # name -> club for NameInk, built once per match
var _duel_mem := {}             # the feed's memory of the forward-50 duels (MatchNotes.duel_feed_line)
var _break_refresh := Callable()   # the one-line break: say each call's answer again after a pick
var _break_sheets: Array = []      # the one-line break: open sheets, the top one last ({overlay, close})


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_interactive = GameState.pending_sim != null and not GameState.pending_match.is_empty()
	if _interactive and GameState.side_from_match:
		# Back from Change the side: the match is made again from the new side.
		GameState.rebuild_pending_side()
	if _interactive:
		_res = GameState.pending_sim.result()
		_res["home"] = GameState.pending_match["home"]
		_res["away"] = GameState.pending_match["away"]
		_res["label"] = GameState.pending_match["label"]
		_res["venue"] = str(GameState.pending_match.get("venue", ""))
		_res["events"] = []
		_my_side = 0 if str(_res["home"]) == GameState.my_club else 1
		_pos_before = GameState.my_position()
		# A pre-season practice match is nobody's debut, farewell or first goal.
		_farewell = {} if _is_practice(GameState.pending_match) else _farewell_for(GameState.pending_match)
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
	# Report a problem (Settings) quotes this match's last feed lines.
	ProblemReport.start_feed("%s, %s v %s" % [str(_res.get("label", "")),
			GameDB.club_name(str(_res["home"])), GameDB.club_name(str(_res["away"]))])
	# The ground the vignettes draw: the MCG has its own stands (FL-003); every other
	# venue keeps the plain ground. Set every match, as the static outlives the scene.
	# The same call sets the match's sky: day, twilight or night (VignetteKickoff).
	VignetteGround.use_match(_res)
	_crowd = CrowdSound.new()
	_crowd.name = "Crowd"
	add_child(_crowd)
	_build()
	_pitch.setup(_res)
	_refresh_rings()
	# Whose first AFL goal the feed can say, if it comes today (MatchNotes).
	if _interactive and not _is_practice(_res):
		_duel_mem["first_goal"] = GameState.first_goal_candidates()
		_duel_mem["career_high"] = GameState.career_high_candidates()
	_pitch.event_played.connect(_on_event)
	_pitch.finished.connect(_on_finished)
	_pitch.ends_changed.connect(_on_ends_changed)
	_update_scoreboard({"q": 1, "min": 0, "score": [0, 0], "kind": "info"})
	_set_clock_word("pre")
	if _interactive and GameState.match_way_live == "skip":
		# Skip (the poster): straight to full time on the plan you took in,
		# as Skip to full time before the first bounce.
		GameState.match_way_live = "watch"
		_on_skip.call_deferred()
	elif _interactive:
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

	_mount_body(UiKit.view_width(self) < 640.0)
	_root.add_child(_body)
	_board = _scoreboard()
	_place_board()
	# T3.R42 (P-26): on a phone the score and the clock never leave the screen.
	# Breaks, sheets, calls and scenes open in the space under the scoreboard.
	_over = Control.new()
	_over.name = "UnderScoreboard"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.child_entered_tree.connect(func(_n: Node) -> void: _sync_under_sheet.call_deferred())
	_over.child_exiting_tree.connect(func(_n: Node) -> void: _sync_under_sheet.call_deferred())
	_pitch.item_rect_changed.connect(_fit_docked)


## The scoreboard's place: across the top, or the head of a PC's column.
func _place_board() -> void:
	if _board.get_parent() != null:
		_board.get_parent().remove_child(_board)
	var host: Node = _right if _pc and _right != null else _root
	host.add_child(_board)
	host.move_child(_board, 0)


## A PC: a break, a call, a scene, a replay or full time opens over the oval and
## no wider, so the score, the feed and the numbers beside it stay in view
## (director, 2026-11-12). A phone's take the room under the scoreboard, as ever.
func _dock(ov: Control) -> void:
	if ov == null or not is_instance_valid(ov):
		return
	ov.set_meta("docked", true)
	_shut_bench()
	_fit_docked()


## The bench's drawer shuts when anything opens over the oval (a break, a call, a
## scene, a replay, a sheet, full time): left open underneath, it took the first Back
## that the thing on top should have had.
func _shut_bench() -> void:
	if _pitch != null:
		_pitch.close_bench()


func _undock(ov: Control) -> void:
	if ov == null or not is_instance_valid(ov) or not ov.has_meta("docked"):
		return
	ov.remove_meta("docked")
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The oval's place on screen, in _over's own units; nothing until it is laid out.
func _dock_rect() -> Rect2:
	if not _pc or _pitch == null or _over == null:
		return Rect2()
	var r := _pitch.get_global_rect()
	if r.size.x < 40.0 or r.size.y < 40.0:
		return Rect2()
	return Rect2(r.position - _over.get_global_rect().position, r.size)


func _fit_docked() -> void:
	if _over == null:
		return
	var r := _dock_rect()
	for c in _over.get_children():
		var ov := c as Control
		if ov == null or not ov.has_meta("docked") or ov.is_queued_for_deletion():
			continue
		if r.size == Vector2.ZERO:
			ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		else:
			ov.set_anchors_preset(Control.PRESET_TOP_LEFT)
			ov.position = r.position
			ov.size = r.size


## The play, speed and skip buttons are not drawn and take no tap, click or key
## while a break, a call, a sheet or full time is up: they showed through the
## dimmed page under every sheet, as buttons that looked live and were not.
## They keep their place, so the oval and the feed do not move when a sheet closes.
func _sync_under_sheet() -> void:
	if _controls_box == null or not is_instance_valid(_controls_box) or _over == null:
		return
	var covered := false
	for c in _over.get_children():
		if c is Control and (c as Control).visible and not c.is_queued_for_deletion() \
				and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			covered = true
	_controls_box.modulate.a = 0.0 if covered else 1.0
	for b in _controls_box.find_children("*", "BaseButton", true, false):
		(b as BaseButton).mouse_filter = Control.MOUSE_FILTER_IGNORE if covered else Control.MOUSE_FILTER_STOP
		(b as BaseButton).focus_mode = Control.FOCUS_NONE if covered else Control.FOCUS_ALL


## The overlays' top: the scoreboard's foot on a phone; a wide screen's break
## keeps the whole height (its band carries the score).
func _fit_over() -> void:
	if _over == null or _board == null or not is_instance_valid(_board):
		return
	var foot := _board.get_global_rect().end.y
	# The first match's momentum line keeps its room under the meter, but a scene
	# opening under the scoreboard never gives that room up: it starts where it
	# would without the line, over it, so every match frames its scenes the same.
	# Measured from the meter, which stays put while the line's wrap settles, so a
	# sheet opened in the first frames is never resized under itself.
	if _mom_note != null and _mom_note.visible and _mom_bar != null:
		foot = _mom_bar.get_global_rect().end.y + SCORE_BAND_PAD
	# A phone on its side keeps the whole height; a PC's open over the oval (_dock).
	_over.offset_top = foot - get_global_rect().position.y if _stacked else 0.0
	_fit_docked()


func _mount_body(stack: bool) -> void:
	# Stack the feed under the oval on a narrow phone. Landscape keeps the
	# oval beside the feed, and the pitch itself is never rebuilt.
	_stacked = stack
	_pc = not stack and _wide_break()
	_right = null
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
	_pitch.size_flags_stretch_ratio = 2.2 if stack else (PC_OVAL_SHARE if _pc else 1.5)
	_body.add_child(_pitch)

	if _side_panel == null:
		_side_panel = UiKit.panel(UiKit.PANEL, 10)
		var sv := UiKit.vbox(6)
		_side_panel.add_child(sv)
		# Your match: the calls you have on, so the setup is never a guess.
		# Every call in full: a long name or several calls wrap, never trim.
		# The calls on right now: the coach reads them, so not in grey (row T3.R9).
		_setup_line = NameInk.rich(UiKit.SECONDARY, UiKit.TEXT)
		_setup_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_setup_line.name = "SetupLine"
		_setup_line.visible = false
		sv.add_child(_setup_line)
		_feed_waiting = UiKit.lbl("Play by play from the first bounce.", UiKit.SECONDARY, UiKit.MUTED)
		_feed_waiting.name = "FeedWaiting"
		_feed_waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sv.add_child(_feed_waiting)
		_feed = UiKit.vbox(4)
		_feed.name = "Feed"
		_feed.child_entered_tree.connect(func(_n: Node) -> void:
			if is_instance_valid(_feed_waiting):
				_feed_waiting.visible = false)
		_feed_scroll = UiKit.scroll(_feed)
		# Following the play, a line cut off at the top would leave a stray end of
		# a sentence ("time.") over the newest lines: see _hide_cut_rows.
		var bar := _feed_scroll.get_v_scroll_bar()
		bar.value_changed.connect(func(_v: float) -> void: _hide_cut_rows())
		bar.changed.connect(_hide_cut_rows)
		# Room for a two-line row whatever wraps above it (a two-line plan with
		# a tag left the feed one clipped line on a phone).
		_feed_scroll.custom_minimum_size.y = ceil(UiKit.px(UiKit.SMALL) * 2.7)
		sv.add_child(_feed_scroll)
		_live_stats = UiKit.vbox(2)
		_live_stats.name = "LiveStats"
		sv.add_child(_live_stats)
		sv.add_child(_controls())
	_fit_side_panel()
	if _pc:
		# The column beside the oval: the scoreboard (_place_board), then the panel.
		_right = UiKit.vbox(8)
		_right.name = "MatchColumn"
		_right.custom_minimum_size = Vector2(PC_COLUMN_MIN_W, 0)
		_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_right.size_flags_stretch_ratio = 1.0
		_right.add_child(_side_panel)
		_body.add_child(_right)
	else:
		_body.add_child(_side_panel)
	_feed_waiting.visible = _pc and _feed.get_child_count() == 0
	_paint_live_stats()


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
		# Grown with the text size (Settings), so a larger size keeps the same
		# lines of the feed in view above the buttons.
		_side_panel.custom_minimum_size = Vector2(0, UiKit.px(120 if short else 168))
		_side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side_panel.size_flags_stretch_ratio = 1.0
	elif _pc:
		_side_panel.custom_minimum_size = Vector2.ZERO
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
	var narrow := _board_narrow()
	# Both clubs' colours behind the score (director, 2026-10-08: not boring).
	var v := UiKit.vbox(4)
	var p := ClubDuel.band(str(_res["home"]), str(_res["away"]), v, SCORE_BAND_PAD, 0.35)
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(_score_column(str(_res["home"]), true, narrow))
	h.add_child(_score_middle(narrow))
	h.add_child(_score_column(str(_res["away"]), false, narrow))
	v.add_child(_momentum_bar())
	p.item_rect_changed.connect(_fit_over)
	p.item_rect_changed.connect(_fit_scores)
	_score_band = p
	return p


## Who has the run of play: the engine's momentum (MatchSim.momentum), which
## goals swing, time fades and a goal the other way turns. The side it
## favours wins a little more of the ball at stoppages and loose balls.
## Director, 2026-10-07: always labelled, the club on top named in words and
## its colour growing from the centre toward it (one colour at a time, so
## like colours cannot confuse it); a tap explains it, and the first match
## you watch says so once, under it.
const MOMENTUM_EVEN := 0.12
## Row 78: a side well ahead can run away with it, so the sheet says what a runaway does.
const MOMENTUM_INFO_RUNAWAY := [
	"Momentum is the run of play. A goal swings it toward the side that kicked it, a behind a little; it fades as play goes on and halves at every break.",
	"The side on top wins a little more of the ball at centre bounces, stoppages and loose balls - never a guarantee. A goal the other way turns it.",
	"A side more than four goals up with the run of play can run away with it: the further ahead, the more of the ball it wins, the longer the run lasts and the more goals it takes to turn. A call to win the ball back still counts in full.",
]


## The line the first match you watch shows under the meter.
const MOMENTUM_NOTE := "Momentum swings with each goal and fades with time; the side on top wins a little more of the ball. %s it for more."


static func momentum_info() -> Array:
	return MOMENTUM_INFO_RUNAWAY


## The scoreboard's short form (short club names, the smaller figures): a phone,
## and a PC's column beside the oval, which is about a phone wide.
func _board_narrow() -> bool:
	return _pc or UiKit.view_width(self) < 640.0


func _momentum_bar() -> Control:
	var b := Button.new()
	b.name = "MomentumBar"
	b.flat = true
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(_show_momentum_info)
	_mom_bar = b
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
	# The first match you watch keeps the line's room from the first frame,
	# unseen until momentum first moves, so the ground never shifts under it.
	if _interactive and GameState.intro_due("momentum"):
		_mom_note.text = MOMENTUM_NOTE % ScreenLayout.tap_word()
		_mom_note.visible = true
		_mom_note.modulate.a = 0.0
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
	# Its room is kept from the first frame (_momentum_bar); here it only shows.
	if _mom_note.visible and _mom_note.modulate.a < 1.0 and absf(_momentum) >= MOMENTUM_EVEN:
		GameState.set_setting("seen_momentum_intro", true)
		_mom_note.modulate.a = 1.0


func _show_momentum_info() -> void:
	_close_sheet()
	var box := UiKit.modal_box(_over, 520.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "MomentumInfo"
	_dock(overlay)
	_sheet_overlay = overlay
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Momentum", UiKit.TITLE))
	for line in momentum_info():
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


## A PC's numbers beside the oval. Scoring shots are the scoreboard's and inside
## 50s are counted as each is played, so both are right to the second. The rest
## (disposals, marks, tackles, clearances) are the stats sheet's own totals at
## the last break, and say which break: the feed of play cannot count them.
const LIVE_STATS := [["disposals", "Disposals"], ["marks", "Marks"], ["tackles", "Tackles"], ["clearances", "Clearances"]]
const LIVE_BREAKS := {1: "At quarter time", 2: "At half time", 3: "At three-quarter time"}


func _track_live_stats(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if kind == "inside50":
		var side := int(ev.get("side", -1))
		if side == 0 or side == 1:
			_live_i50[side] = int(_live_i50[side]) + 1
	elif kind == "quarter":
		_live_break = maxi(_live_break, int(ev.get("q", 0)))
	elif kind != "goal" and kind != "behind":
		return
	if not _skipping:
		_paint_live_stats()


## Both sides' totals as the stats sheet has them at break n (at the end: the match's), or [].
func _team_at_break(n: int) -> Array:
	if _finished:
		return _res.get("team", [])
	var quarters: Array = _res.get("quarter_teams", [])
	if n >= 1 and quarters.size() >= n:
		return (quarters[n - 1] as Dictionary).get("team", [])
	return []


func _paint_live_stats() -> void:
	if _live_stats == null or not is_instance_valid(_live_stats):
		return
	# A PC's column has the room; a phone keeps the oval and the feed.
	_live_stats.visible = _pc
	if not _pc:
		return
	UiKit.clear(_live_stats)
	var team := _team_at_break(_live_break)
	# At the end the sheet's own count of inside 50s stands (a match skipped to
	# its end played none of them here).
	if team.size() == 2 and _finished:
		_live_i50 = [int(round(float((team[0] as Dictionary).get("inside50", 0.0)))),
				int(round(float((team[1] as Dictionary).get("inside50", 0.0))))]
	var inks := UiKit.club_ink_pair(str(_res["home"]), str(_res["away"]))
	var head := UiKit.hbox(4)
	head.name = "LiveStatsHead"
	for side in [0, 1]:
		var club := UiKit.ellipsis(GameDB.club_short(str(_res["home"] if side == 0 else _res["away"])),
				UiKit.SMALL, UiKit.club_name_colour(inks[side]), true)
		club.name = "LiveClub_%d" % side
		club.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		club.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(club)
	_live_stats.add_child(UiKit.rule())
	_live_stats.add_child(head)
	_live_stats.add_child(_live_row("shots", "Scoring shots",
			int(_shown_goals[0]) + int(_shown_behinds[0]), int(_shown_goals[1]) + int(_shown_behinds[1])))
	_live_stats.add_child(_live_row("inside50", "Inside 50s", int(_live_i50[0]), int(_live_i50[1])))
	if team.size() != 2:
		return
	var when := UiKit.line(str(LIVE_BREAKS.get(_live_break, "At full time" if _finished else "After four quarters")),
			UiKit.SMALL, UiKit.MUTED)
	when.name = "LiveStatsWhen"
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live_stats.add_child(when)
	for row in LIVE_STATS:
		_live_stats.add_child(_live_row(str(row[0]), str(row[1]),
				int(round(float((team[0] as Dictionary).get(str(row[0]), 0.0)))),
				int(round(float((team[1] as Dictionary).get(str(row[0]), 0.0))))))


## One number for each side, home on the left as on the scoreboard, the larger
## in bold (more is not always better, so no good or bad colour).
func _live_row(key: String, label: String, home: int, away: int) -> Control:
	var h := UiKit.hbox(4)
	h.name = "LiveRow_" + key
	var a := UiKit.figure(str(home), UiKit.NAME, UiKit.TEXT if home >= away else UiKit.MUTED)
	a.name = "Home"
	a.custom_minimum_size = Vector2(44, 0)
	h.add_child(a)
	var lab := UiKit.ellipsis(label, UiKit.SECONDARY, UiKit.TEXT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lab)
	var b := UiKit.figure(str(away), UiKit.NAME, UiKit.TEXT if away >= home else UiKit.MUTED)
	b.name = "Away"
	b.custom_minimum_size = Vector2(44, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	return h


## Every event carries the engine's momentum as it stood ("mom"): the meter
## shows exactly that, nothing of its own.
func _track_momentum(ev: Dictionary) -> void:
	if not ev.has("mom"):
		return
	_momentum = clampf(float(ev["mom"]), -1.0, 1.0)
	if not _skipping:
		_paint_momentum()


func _score_column(code: String, home: bool, narrow: bool) -> Control:
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_text := GameDB.club_short(code) if narrow else GameDB.club_name(code)
	var name := UiKit.ellipsis(name_text, UiKit.SECONDARY if narrow else UiKit.NAME, UiKit.TEXT, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	ClubDuel.on_colour(name)
	v.add_child(name)
	# A wide screen's score is the headline across a 1920 band, not a caption in it (row T3.R9).
	var score := UiKit.figure("0.0 (0)", PC_SCORE if _pc else (UiKit.RATING if narrow else WIDE_SCORE), Color.WHITE)
	ClubDuel.on_colour(score)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	# A fixed minimum wider than the phone column is what shoved the oval
	# off screen. Let the score take its own width in portrait.
	if not narrow:
		score.custom_minimum_size = Vector2(170, 0)
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
	_clock = UiKit.line(_clock_text(_shown_q, _shown_min), 17 if narrow else 24, UiKit.TEXT, true)
	_clock.name = "Clock"
	_clock.set_meta("fs", 17 if narrow else 24)
	_clock.set_meta("room", 84.0 if narrow else 132.0)
	_paint_clock()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ClubDuel.on_colour(_clock)
	mid.add_child(_clock)
	_lead = UiKit.ellipsis("", UiKit.SMALL, UiKit.TEXT)
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
	v.name = "MatchControls"
	_controls_box = v

	var row := UiKit.hbox(5)
	v.add_child(row)
	_play_btn = UiKit.btn("Pause", UiKit.SECONDARY)
	_play_btn.custom_minimum_size = Vector2(0, 44)
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.clip_text = true
	_play_btn.pressed.connect(_on_toggle)
	row.add_child(_play_btn)

	for s in SPEEDS:
		var b := UiKit.btn("%dx" % int(s), UiKit.SECONDARY)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_on_speed.bind(s))
		_speed_btns.append(b)
		row.add_child(b)

	var row2 := UiKit.hbox(5)
	v.add_child(row2)
	var skip := UiKit.btn("Skip to full time", UiKit.SECONDARY)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_on_skip)
	row2.add_child(skip)

	# The rest of this quarter at once, then the break and its calls as ever.
	# Only in a match you coach, and not in the last quarter (it would be
	# Skip to full time).
	if _interactive:
		_break_skip = UiKit.btn("Skip to quarter time", UiKit.SECONDARY)
		_break_skip.name = "SkipToBreak"
		_break_skip.custom_minimum_size = Vector2(0, 44)
		_break_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_break_skip.clip_text = true
		_break_skip.pressed.connect(_on_skip_to_break)
		_break_skip.ready.connect(_fit_break_skip, CONNECT_ONE_SHOT)
		row2.add_child(_break_skip)
		row2.move_child(_break_skip, 0)

	# Your own match cannot be left half way (Back says so); a replay can.
	if not _interactive:
		var leave := UiKit.btn("Back to hub", UiKit.SECONDARY)
		leave.custom_minimum_size = Vector2(0, 44)
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.pressed.connect(func(): Router.back())
		row2.add_child(leave)

	_sync_controls()
	return v


## The break button is never narrower than its longest name: on a 320-wide
## screen half the row would cut "Skip to three-quarter time" short, so it
## takes what it needs and Skip to full time the rest.
func _fit_break_skip() -> void:
	var fnt := _break_skip.get_theme_font("font")
	var fs := _break_skip.get_theme_font_size("font_size")
	var sty := _break_skip.get_theme_stylebox("normal")
	var pad := (sty.get_margin(SIDE_LEFT) + sty.get_margin(SIDE_RIGHT)) if sty else 0.0
	var need := 0.0
	for n in BREAK_NAMES:
		need = maxf(need, fnt.get_string_size("Skip to " + str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	_break_skip.custom_minimum_size.x = ceilf(need + pad + 4.0)


func _sync_controls() -> void:
	if _play_btn == null:
		return
	_play_btn.text = "Play" if not _pitch.playing else "Pause"
	for i in range(SPEEDS.size()):
		UiKit.set_selected(_speed_btns[i], is_equal_approx(_pitch.speed, SPEEDS[i]))
	if _break_skip != null:
		var at := _breaks_played + 1
		_break_skip.visible = at < 4 and not _finished
		if at < 4:
			_break_skip.text = "Skip to " + str(BREAK_NAMES[at - 1])


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


## Skip to the break: this quarter is rolled to its end exactly as watching it
## would roll it (MatchSim.run_quarter; a call still to come takes its default,
## as Skip to full time does), every event reaches the feed and the
## scoreboard without the animation, and the break comes up with every call.
func _on_skip_to_break() -> void:
	var sim: MatchSim = GameState.pending_sim
	if not _interactive or sim == null or _pitch == null or _skipping or _finished or _breaks_played >= 3:
		return
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	_close_moment()
	# A close-up queued for this frame is dropped with the play it would show.
	_broadcast_pending = false
	# The rest of the quarter takes a moment on a phone: the button says so
	# and the oval holds still while it is played.
	_pitch.pause()
	_skipping = true
	_break_skip.disabled = true
	_break_skip.text = "Playing on..."
	await get_tree().process_frame
	await get_tree().process_frame
	# Skip to full time in those two frames has already ended the match.
	if not is_inside_tree() or GameState.pending_sim != sim or _finished:
		return
	if sim.quarter_in_progress():
		_res = sim.run_quarter()
		_stamp_match_meta()
		_append_new_events()
	# No crowd or close-ups on the way.
	_pitch.release_all()
	_skipping = false
	_break_skip.disabled = false
	_refresh_rings()
	_paint_momentum()
	_paint_live_stats()
	_on_finished()


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


## The first coach's call of a match froze the oval for seconds (TODO row T2.42,
## traced by tools/visual/trace_stall_live.gd): its first frame paints this ground's
## crowd for the home and away colours (the preview paints yours first, a different
## picture), and compiles and uploads the figures' shader and sheets. Here that work is
## done while the opening break waits on the coach: the real call scene draws behind
## the break, clipped to one pixel, for a few frames, then goes. It reads the match
## and changes nothing in it.
func _warm_call_scene() -> void:
	if not GameState.vignettes_on() or _warmed_call:
		return
	_warmed_call = true
	var holder := Control.new()
	holder.name = "CallSceneWarm"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	holder.size = Vector2.ONE
	_over.add_child(holder)
	_over.move_child(holder, 0)
	var vignette := StoppageVignette.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vignette)
	# The size the first real call draws at: the oval's place on a PC (where calls are
	# docked), the whole screen on a phone.
	vignette.size = warm_size()
	vignette.setup(GameState.pending_sim, _my_side, "")
	for i in range(WARM_FRAMES):
		await get_tree().process_frame
	if is_instance_valid(holder):
		holder.queue_free()


## The size the warm-up scene draws at: the docked scene's on a PC; on a phone the
## overlay layer's, which is the screen under the score header.
func warm_size() -> Vector2:
	var r := _dock_rect()
	if r.size != Vector2.ZERO:
		return r.size
	return _over.size if _over != null and _over.size.x > 1.0 and _over.size.y > 1.0 else get_viewport_rect().size


func _close_coach() -> void:
	_close_sheet()
	_close_break_sheets()
	_break_refresh = Callable()
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		# The closing break stays in the tree until the frame ends; a quarter that
		# ends in the same frame (its play skipped through) opens the next break beside it, which would
		# then be named CoachBox2. The closing one gives the name up first.
		_coach_overlay.name = "CoachBoxClosing"
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
		t = {"gameplan": _current_plan(sim), "tag_id": "", "pep": "steady"}
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
	["balanced", "Balanced"], ["attacking", "Attack Corridor"],
	["defensive", "High Press"], ["contest", "Win Contest"],
	["controlled", "Controlled Tempo"],
]
## The plans at a break: the five, then your own when it is built (CustomPlan).
func _gameplans() -> Array:
	var out := GAMEPLANS.duplicate()
	if CustomPlan.ready(CoachEffects.my_custom):
		out.append([CustomPlan.KEY, CoachReport.plan_label(CustomPlan.KEY)])
	return out


## A PC break's choice buttons: a mouse, not a thumb (phones keep 44).
const PC_CHOICE_H := 34.0

const PEP_TALKS := [
	["steady", "Stay composed"], ["fire_up", "Fire them up"], ["calm", "Calm the group"],
	["heat", "Bring the heat"],
]


## The break: what happened, then your calls for the next quarter. It
## surfaces the problem - their midfield on top, a forward hurting you - and
## leaves the answer to you. No advice, no expected points.
## The forecast before the first bounce: "Forecast: wet · 31% chance it turns
## at a break". The odds are left off for a roofed ground, where it can't turn.
func _forecast_line(sim: MatchSim) -> String:
	var odds := Weather.turn_odds_line(sim.weather_odds)
	var day := "Forecast: %s" % Weather.label(sim.weather).to_lower()
	return day if odds == "" else "%s  ·  %s" % [day, odds]


func _show_coach_box() -> void:
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	_pitch.pause()
	var sim: MatchSim = GameState.pending_sim
	var q := sim.current_quarter
	# The skip button names the next break from here. Counted when the break
	# opens, not at the siren: in the moment between the two, a tap still
	# lands on the break that has just sounded, and the button says so.
	_breaks_played = q - 1
	_set_clock_word(str(CLOCK_BREAKS.get(q, "")))
	_sync_controls()
	# The calls fill the screen at every break, so the actions sit at the
	# bottom with the choices just above them.
	# On a PC the break is a wide landscape sheet with every call in view
	# (director, 2026-10-09: "it looks like we are using a mobile UI on a PC").
	var wide := _wide_break()
	_pc_break = wide
	_pc_one_line = wide
	var stats_pc: Button = null
	var box := UiKit.modal_box(_over, minf(UiKit.view_width(self) - 48.0, 1560.0) if wide else 640.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "CoachBox"
	_coach_overlay = overlay
	if wide:
		# Over the oval the sheet has the oval's height, not the window's: it
		# keeps less of it for its own edge.
		var shell: Node = box["body"]
		while shell != null and not (shell is PanelContainer):
			shell = shell.get_parent()
		if shell != null:
			var edge := (shell as PanelContainer).get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if edge != null:
				edge.content_margin_top = 8.0
				edge.content_margin_bottom = 8.0
				(shell as PanelContainer).add_theme_stylebox_override("panel", edge)
	_dock(overlay)
	if q == 1:
		_warm_call_scene()
	var v: VBoxContainer = box["body"]
	var titles := {1: "Before the first ball-up", 2: "Quarter time", 3: "Half time", 4: "Three-quarter time"}
	# The break leads with both clubs' colours (director, 2026-10-08).
	# On a PC the title and the score share one line: the band is wide.
	var bv: BoxContainer = UiKit.hbox(16) if wide else UiKit.vbox(2)
	var band := ClubDuel.band(str(_res["home"]), str(_res["away"]), bv, 6 if wide else 14)
	band.name = "BreakBand"
	(band.get_child(0) as ClubDuel).live()   # match day's atmosphere settles in (Feel)
	v.add_child(band)
	# One line a call, before the bounce and at every break (director,
	# 2026-10-14; before the bounce too, 2026-11-12: "one screen, tap to
	# change"): every call is built into a store, out of sight, and laid out by
	# _mount_one_line as a row that shows its pick and opens on a tap.
	# How many from the game so far each player call shows before "Other
	# player...": two on a wide screen, so every call fits without scrolling.
	var quick := 2 if wide else 0
	var store := UiKit.vbox(6)
	store.name = "CallStore"
	store.visible = false
	var rep: VBoxContainer = store
	var col_a: VBoxContainer = store
	var col_b: VBoxContainer = store
	var col_c: VBoxContainer = store
	var title := UiKit.heading(str(titles.get(q, "Quarter %d" % q)), UiKit.H1)
	title.name = "BreakTitle"
	if wide:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ClubDuel.on_colour(title)
	bv.add_child(title)
	if q == 1:
		# Gather Round: the event's name stands for the round number, and the line
		# may wrap, so the host ground is never cut short on a phone.
		var label := str(_res.get("label", "Match"))
		var gather := label.ends_with(GatherRound.NAME)
		if gather:
			label = GatherRound.NAME
		var where := UiKit.ellipsis("%s  ·  %s v %s  ·  %s" % [label,
				GameDB.club_short(str(_res["home"])), GameDB.club_short(str(_res["away"])), GameDB.ground_shown(_venue())], UiKit.BODY, UiKit.TEXT, true)
		where.name = "BreakWhere"
		if gather:
			where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			where.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		ClubDuel.on_colour(where)
		if wide:
			where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bv.add_child(where)
		# The forecast, with the odds it turns at a break (row 160, director
		# 2026-11-12: "Yes, at a break"): numbers at the gate, a fact, no advice.
		var fc := _forecast_line(sim)
		if fc != "":
			var fcl := UiKit.lbl(fc, UiKit.BODY, UiKit.TEXT)
			fcl.name = "BreakForecast"
			fcl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ClubDuel.on_colour(fcl)
			if wide:
				fcl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bv.add_child(fcl)
	else:
		var sc := UiKit.lbl(MatchNotes.break_score(str(_res["home"]), str(_res["away"]),
				_res.get("goals", [0, 0]), _res.get("behinds", [0, 0]), not wide), UiKit.NAME, UiKit.TEXT, true)
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
		var stats := UiKit.text_action("Match stats", UiKit.BODY)
		stats.name = "BreakStats"
		stats.custom_minimum_size = Vector2(0, 48)
		stats.pressed.connect(_show_break_stats)
		if wide:
			stats_pc = stats
		else:
			rep.add_child(stats)
			rep.add_child(UiKit.spacer(UiKit.GAP))
		# The weather turns at this break (row 160): said first, in bold, as
		# it changes how the rest is played.
		var wt := sim.weather_turn_now()
		if not wt.is_empty():
			var news := UiKit.lbl(Weather.turn_news(int(wt["after"]), str(wt["to"])), UiKit.BODY, UiKit.TEXT, true)
			news.name = "BreakWeatherTurn"
			news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rep.add_child(news)
		var played := UiKit.section(str({2: "First quarter", 3: "Second quarter",
				4: "Third quarter"}.get(q, "Last quarter")))
		played.name = "QuarterHeading"
		rep.add_child(played)
		rep.add_child(_quarter_view(q - 1))
		var did := MatchNotes.calls_lines(_res, _my_side, q - 1) \
				+ MatchNotes.tag_drop_lines(_res, _my_side, q - 1) \
				+ MatchNotes.lasting_moment_lines(_res, q - 1)
		if not did.is_empty():
			rep.add_child(UiKit.spacer(UiKit.GAP))
			var did_head := UiKit.section("What your calls did")
			did_head.name = "CallsDidHeading"
			rep.add_child(did_head)
			var dnote := UiKit.lbl(MatchNotes.CALLS_DID_NOTE, UiKit.SMALL, UiKit.MUTED)
			dnote.name = "CallsDidNote"
			dnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rep.add_child(dnote)
			var dv := UiKit.vbox(4)
			dv.name = "CallsDid"
			for t in did:
				var dl := _say(str(t), UiKit.BODY, UiKit.TEXT)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dv.add_child(dl)
			rep.add_child(dv)
	rep.add_child(UiKit.spacer(UiKit.GAP))
	var calls_head := UiKit.section("Your calls" if q == 1 else "Next quarter")
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
		"interceptor_id": str(sim.interceptor[_my_side]),
		"minder_id": str((sim.tactics[_my_side] as Dictionary).get("spare_minder_id", "")) 				if bool((sim.tactics[_my_side] as Dictionary).get("spare_accountable", false)) else "",
		"focus_mid": str((sim.tactics[_my_side] as Dictionary).get("focus_mid", _last_tactics.get("focus_mid", ""))),
		"focus_fwd": str((sim.tactics[_my_side] as Dictionary).get("focus_fwd", _last_tactics.get("focus_fwd", ""))),
		"focus_def": str((sim.tactics[_my_side] as Dictionary).get("focus_def", _last_tactics.get("focus_def", ""))),
		# Before the bounce, a talk you set before Change the side is kept.
		"pep": str((sim.tactics[_my_side] as Dictionary).get("pep", "steady")) if q == 1 else "steady",
	}
	calls["defence"] = MatchNotes.defence_key(str(calls["interceptor_id"]) != "", str(calls["minder_id"]) != "")
	var loose_was := str(calls["interceptor_id"])
	# A tag or a minder you change here is yours from then on: the assistant
	# stops making that call at the breaks (MatchSim._assistant_calls).
	var tag_was := str(calls["tag_id"])
	var minder_was := str(calls["minder_id"])
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
		# Sized for this list today: its fit, coaches, familiarity and the
		# day's weather (M1, director 2026-11-10).
		# At a break the weather turns at, the plans are sized for the new one (row 160).
		var sized := GateOdds.plan_texts_for(sim.squads[_my_side], key, sim.weather_ahead())
		plan_note.add_child(_plan_row("Gain:", str(sized[0]), "PlanGain"))
		plan_note.add_child(_plan_row("Cost:", str(sized[1]), "PlanCost"))
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
	var plan := _choice_grid("PlanPicker", _gameplans(), calls, "gameplan", 2 if narrow else 3, sync_note)
	# The heading and the plan under it stay together.
	var plan_block := _call_block("Gameplan", plan)
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
	# The tagger the coach named stays his call at every break (director,
	# 2026-10-14); only a man gone from the match hands the job back.
	if not my_mids.has(str(calls["tagger_id"])) and not sim.taking_part(_my_side, str(calls["tagger_id"])):
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
	# What the tag does and costs, as labelled Gain / Cost rows like every other
	# break call (director 2026-11-10, "Gain / Cost everywhere"), the touches
	# inside the line. A name in either line opens his profile on a tap.
	var tag_note := UiKit.vbox(2)
	tag_note.name = "TagNote"
	var tag_rows: Array = []
	for mark in ["Gain:", "Cost:"]:
		var row := UiKit.hbox(6)
		row.name = "Tag" + mark.trim_suffix(":")
		var mk := UiKit.lbl(mark, UiKit.NOTE, UiKit.label_ink(), true)
		mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mk.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(mk)
		var line := NameInk.rich(UiKit.NOTE, UiKit.TEXT)
		line.name = "Text"
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		tag_note.add_child(row)
		tag_rows.append(line)
	# On a phone the rows with a tag run to four lines and with none to three:
	# they keep room for four, so a tag tap never pushes the calls below it
	# down (A2).
	if not _pc_break:
		tag_note.custom_minimum_size.y = ceilf(UiKit.FONT.get_height(UiKit.px(UiKit.NOTE)) * 4.0) + 2.0
	# Their midfielder who goes untagged with No tag (set once the choices are known).
	var untagged: Array = [""]
	# Who goes to him is only a question once there is a him: shown faded and
	# shut with no tag, so it never appears and shoves the calls below it.
	var who_block: Array = []
	var who_wb: Control = null
	var who_hook: Array = [Callable()]
	var sync_tag := func(_key: String) -> void:
		if (who_hook[0] as Callable).is_valid():
			(who_hook[0] as Callable).call()
		# Who tags is always there, under the tag (A2, director 2026-10-14: the
		# tag screen jumping about was "heinous, awful UI design"): faded and
		# shut until there is a man to tag, so picking one moves nothing, not
		# sideways and not down.
		var has_tag := str(calls["tag_id"]) != ""
		for b in who_block:
			(b as Control).modulate.a = 1.0 if has_tag else 0.4
			for wbtn in (b as Node).find_children("*", "Button", true, false):
				(wbtn as Button).disabled = not has_tag
		var who = my_mids.get(str(calls["tagger_id"]), tagger)
		var target := GameDB.player_display_name_by_id(str(calls["tag_id"]), "Their man") if str(calls["tag_id"]) != "" else ""
		var benched := ""
		if str(calls["tagger_id"]) != "" and not my_mids.has(str(calls["tagger_id"])):
			benched = GameDB.player_display_name_by_id(str(calls["tagger_id"]), "your tagger")
		var who_name := GameDB.player_display_name(who) if who != null else ""
		var kept := GateOdds.tag_kept(who, float(sim.energy.get(str(who["id"]), 100.0))) if who != null else 0
		var gc := GateOdds.tag_break_texts(target, who_name, kept, benched, str(untagged[0]))
		NameInk.set_line(tag_rows[0], str(gc[0]), _names())
		NameInk.set_line(tag_rows[1], str(gc[1]), _names())
		tag_note.set_meta("plain", GateOdds.gain(str(gc[0])) + "\n" + GateOdds.cost(str(gc[1])))
	# The tag is offered on their listed midfielders only (director, 2026-10-14:
	# "Only listed midfielders"): the names, and "Other midfielder..." for the
	# listed midfielders not already shown, which is not drawn when none is
	# left. A ruck or a defender running through the middle is not offered, so
	# "Tag which midfielder?" stays true.
	var opp_listed := opp.filter(func(r): return _can_play_midfield(sim, r))
	var tag_first := _in_the_game(opp_listed, quick if quick > 0 else 4)
	# The player the break names as their best is always on offer, if he can
	# play midfield at all.
	for best_p in MatchNotes.standouts(_res, 1 - _my_side, 1):
		var bid := str(best_p.get("id", ""))
		for r in opp_listed:
			if str(r["id"]) == bid and not tag_first.any(func(x): return str(x["id"]) == bid):
				tag_first.append(r)
	# No tag leaves their busiest midfielder free, the man the sheet's fact line
	# names; before anyone has had the ball, the first one offered.
	var busiest := _busiest_mid(sim)
	if not busiest.is_empty():
		untagged[0] = str(busiest["name"])
	elif not tag_first.is_empty():
		untagged[0] = GameDB.player_display_name_by_id(str(tag_first[0]["id"]), "")
	var tag := _player_choice("TagPicker", "No tag", opp_listed, tag_first, calls, "tag_id",
			MatchNotes.tag_question(), sync_tag, Callable(), Callable(), "Other player…", true)
	# The question is drawn over the choices, as the loose interceptor's is.
	var tag_block := _call_block("Tag", tag)
	var tag_ask := UiKit.lbl(MatchNotes.tag_question(), UiKit.BODY, UiKit.TEXT, true)
	tag_ask.name = "TagQuestion"
	tag_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_block.add_child(tag_ask)
	tag_block.move_child(tag_ask, 1)
	col_a.add_child(tag_block)
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
		who_wb = wb
		col_a.add_child(wb)
	sync_tag.call("")
	col_a.add_child(tag_note)

	# Play through, three calls (director, 2026-10-07; back 2026-11-07): each
	# offers the men who fill that job now, and says what it does or that it
	# waits. They sit where Key match-ups sat (director, 2026-11-07: "Roles
	# replace match-ups"): in three columns under the quarter just played, so
	# no column stands half empty (director, 2026-10-10).
	var mine := _roster_side(_my_side)
	for slot in MatchNotes.FOCUS_ORDER:
		var fits := mine.filter(func(r): return (MatchSim.FOCUS_SLOT_ROLES[slot] as Array).has(
				str(_focus_player(str(r["id"])).get("role", r.get("role", "")))))
		var note := UiKit.lbl("", UiKit.NOTE, UiKit.MUTED)
		note.name = "FocusNote_" + slot
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# What the call gains and costs (M5, director 2026-11-10), as the plan's rows.
		var gc_rows := UiKit.vbox(2)
		gc_rows.name = "FocusGainCost_" + slot
		var sync := func(id: String) -> void:
			note.text = _focus_note_text(slot, id)
			# Gain / Cost below says what the pick does; the note stays only
			# when the call waits (he is benched or out of the spot).
			note.visible = _focus_waits(slot, id)
			_gain_cost_rows(gc_rows, GateOdds.focus_texts(slot,
					GameDB.player_display_name_by_id(id, "your player") if id != "" else ""), "Focus")
		var text: Array = MatchNotes.FOCUS_SLOT_TEXT[slot]
		var pick := _player_choice("FocusPicker_" + slot, "No one", fits, _in_the_game(fits, quick if quick > 0 else 3), calls, slot,
				"Play through: %s" % str(text[0]).to_lower(), sync)
		var block := _call_block("Play through: %s" % str(text[0]).to_lower(), pick)
		sync.call(str(calls[slot]))
		block.add_child(note)
		block.add_child(gc_rows)
		(rep if rep != v else col_a).add_child(block)

	# Defensive set-up (director, 2026-11-03: Defensive forward and Loose
	# interceptor fold into one call). The coach picks the shape; the men are
	# the ones a coach would send: your loose man stays the one in the job
	# (your assistant's pick), else your best reader of the ball; a forward on
	# their loose man is the best one for it (Matchups.minder_candidates).
	var opp_spare := sim._roaming_interceptor(1 - _my_side)
	var def_ground: Array = []
	for p in my_ground:
		if str(p.get("role", "")) == "DEF":
			def_ground.append(p)
	var interceptors := Matchups.interceptor_candidates(def_ground)
	var loose_pick := str(calls["interceptor_id"])
	if loose_pick == "" and not interceptors.is_empty():
		loose_pick = str(interceptors[0]["id"])
	var fwds := Matchups.minder_candidates(my_ground)
	var minder_pick := str(calls["minder_id"])
	if minder_pick == "" and not fwds.is_empty():
		minder_pick = str(fwds[0]["id"])
	var def_opts: Array = []
	for o in MatchNotes.DEFENCE_SETUPS:
		var k := str(o[0])
		if (k == "cover" or k == "both") and (opp_spare.is_empty() or minder_pick == ""):
			continue
		if (k == "loose" or k == "both") and loose_pick == "":
			continue
		def_opts.append(o)
	if not def_opts.any(func(o): return str(o[0]) == str(calls["defence"])):
		calls["defence"] = "loose" if str(calls["defence"]) == "both" and loose_pick != "" else "man"
	var def_note := UiKit.lbl("", UiKit.NOTE, UiKit.MUTED)
	def_note.name = "DefenceNote"
	def_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var df_how: Array = [null]
	var def_rows := UiKit.vbox(2)
	def_rows.name = "DefenceGainCost"
	var sync_def := func(key: String) -> void:
		var loose_on := key == "loose" or key == "both"
		var cover_on := key == "cover" or key == "both"
		calls["interceptor_id"] = loose_pick if loose_on else ""
		calls["minder_id"] = minder_pick if cover_on else ""
		def_note.text = MatchNotes.defence_setup_line(key,
				GameDB.player_display_name_by_id(loose_pick, "your best interceptor"),
				GameDB.player_display_name_by_id(minder_pick, "a forward"),
				GameDB.player_display_name(opp_spare) if not opp_spare.is_empty() else "")
		# Sized for the men in the jobs (M6, director 2026-11-10).
		var gc := GateOdds.defence_texts(key, _focus_player(loose_pick) if loose_on else {},
				_focus_player(minder_pick) if cover_on else {}, opp_spare)
		_gain_cost_rows(def_rows, gc, "Defence")
		if df_how[0] != null and is_instance_valid(df_how[0]):
			(df_how[0] as Control).visible = cover_on
			if cover_on:
				_fill_df_duel(df_how[0], sim, calls, opp_spare)
	var def_pick := _choice_grid("DefenceSetupPicker", def_opts, calls, "defence", 2, sync_def)
	var def_block := _call_block("Defensive set-up", def_pick)
	def_block.name = "DefenceBlock"
	var def_ask := UiKit.lbl(MatchNotes.defence_question(), UiKit.BODY, UiKit.TEXT, true)
	def_ask.name = "DefenceQuestion"
	def_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	def_block.add_child(def_ask)
	def_block.move_child(def_ask, 1)
	def_block.add_child(def_note)
	def_block.add_child(def_rows)
	# From quarter time on: how your loose man and your forward on theirs are going.
	var loose_now := str(sim.interceptor[_my_side])
	if q > 1 and loose_now != "":
		var tally := _say(MatchNotes.loose_tally_line(GameDB.player_display_name_by_id(loose_now, "Your loose man"),
				maxi(0, sim.intercepts_since_call(_my_side))), UiKit.NOTE, UiKit.TEXT)
		tally.name = "LooseTally"
		tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def_block.add_child(tally)
	if q > 1 and not opp_spare.is_empty():
		var how := UiKit.vbox(4)
		how.name = "DfHowItsGoing"
		def_block.add_child(how)
		df_how[0] = how
	sync_def.call(str(calls["defence"]))

	# The rest of the calls, all in view (director, 2026-10-09: no "More
	# calls" button).
	var more: VBoxContainer = col_c
	var syn_label: Control = _synergy_block()
	if syn_label != null:
		more.add_child(syn_label)
	more.add_child(def_block)

	# Wide: the pep talk sits under the tag, so every column fits a 720-unit
	# screen. Rotations are no longer a call (director, 2026-11-03): they
	# follow the season plan and the legs (MatchSim.auto_rotation).
	var tail: VBoxContainer = col_b
	var pep_note := UiKit.vbox(3)
	pep_note.name = "PepNote"
	var sync_pep := func(key: String) -> void:
		# What the talk does and costs this quarter, sized (M3).
		for c in pep_note.get_children():
			pep_note.remove_child(c)
			c.queue_free()
		var psim: MatchSim = GameState.pending_sim
		var sized := GateOdds.pep_texts(key, psim.fire_up_contest(_my_side) if psim != null else MatchSim.PEP_FIRE_CONTEST)
		pep_note.add_child(_plan_row("Gain:", str(sized[0]), "PepGain"))
		pep_note.add_child(_plan_row("Cost:", str(sized[1]), "PepCost"))
	# Four talks: a two-column grid of their full names, which fits a 360 phone
	# and the PC column alike (one row of four ran off a phone).
	var pep := _choice_grid("PepPicker", PEP_TALKS, calls, "pep", 2, sync_pep)
	var pep_block := _call_block("Pep talk", pep)
	col_a.add_child(pep_block)
	col_a.add_child(pep_note)
	sync_pep.call(str(calls["pep"]))

	if wide:
		def_block.get_parent().remove_child(def_block)
		tail.add_child(def_block)
	var legs := _legs_view()
	(rep if rep != v else tail).add_child(legs)
	# The synergies line is about the two sides' strengths, like the legs line:
	# on a PC sheet it sits right under it, never alone at the top of a column
	# without a heading (BOSS QC, 2026-10-11).
	if wide and syn_label != null and syn_label.get_parent() != null:
		syn_label.get_parent().remove_child(syn_label)
		(rep if rep != v else tail).add_child(syn_label)
	# Who is playing well, on the break (director, 2026-10-11): on a PC in the
	# report column; on a phone below the choices, so nothing the next quarter
	# depends on is pushed under the pinned Start button.
	# Before the first ball-up nobody has played: no zeros (director, 2026-10-14).
	if q > 1:
		(rep if rep != v else tail).add_child(_best_so_far())

	# Every pre-match call sits before Start, the side included (TODO row 25).
	var start := UiKit.btn("Start quarter" if q > 1 else "Start", UiKit.HEADING, true)
	start.name = "StartQuarter"
	start.custom_minimum_size = Vector2(0, 48)
	var take_calls := func() -> Dictionary:
		return {
			"gameplan": str(calls["gameplan"]),
			"focus_mid": str(calls["focus_mid"]),
			"focus_fwd": str(calls["focus_fwd"]),
			"focus_def": str(calls["focus_def"]),
			"tag_id": str(calls["tag_id"]),
			"tagger_id": str(calls["tagger_id"]),
			"interceptor_id": str(calls["interceptor_id"]),
			"interceptor_set": str(calls["interceptor_id"]) != loose_was,
			"spare_accountable": str(calls["minder_id"]) != "",
			"spare_minder_id": str(calls["minder_id"]),
			"tag_set": str(calls["tag_id"]) != tag_was,
			"minder_set": str(calls["minder_id"]) != minder_was,
			"pep": str(calls["pep"]),
		}
	start.pressed.connect(func():
		var t: Dictionary = take_calls.call()
		_close_coach()
		_simulate_next_quarter(t))
	# One primary action on the break; the way out is said as words.
	var skip := UiKit.text_action("Skip to full time", UiKit.BODY)
	skip.pressed.connect(_on_skip)
	_mount_one_line({"box": box, "store": store, "calls": calls, "wide": wide, "start": start, "skip": skip,
			"stats_pc": stats_pc, "tagger": tagger, "my_mids": my_mids, "who_wb": who_wb, "who_hook": who_hook,
			"opp_spare": opp_spare, "sim": sim, "syn": syn_label})
	if q == 1 and GameState.match_day_setup_open():
		# The side is its own row above the calls (director, 2026-11-12): what it
		# is, quietly, and what a tap does in bold, as every call's row reads.
		var side := _call_row("side", "Your side")
		side.name = "ChangeSide"
		NameInk.set_line(side.get_meta("answer") as RichTextLabel, "Change the side", {})
		side.pressed.connect(func():
			# Your calls go into the match before you leave, so they are still
			# set when you come back (GameState.rebuild_pending_side).
			var t: Dictionary = take_calls.call()
			if bool(t["interceptor_set"]):
				sim.coach_interceptor(_my_side, str(t["interceptor_id"]))
			sim.set_tactics(_my_side, t)
			GameState.side_from_match = true
			_close_coach()
			Router.go("selection"))
		var side_at: Node = overlay.find_child("SideRow", true, false)
		if side_at != null:
			side_at.add_child(side)
			side_at.add_child(UiKit.rule())
	# A call the quarter broke brightens twice (Feel; never a nag).
	for picker in MatchNotes.broken_calls(_res, sim.injuries, _my_side, q, _last_tactics):
		var found := overlay.find_child(str(picker) + "*", true, false)
		if found != null:
			# The call's row brightens: its picker is behind the row.
			var up: Node = found
			while up != null and not str(up.name).begins_with("CallBody_"):
				up = up.get_parent()
			var row: Node = overlay.find_child("CallRow_" + str(up.name).trim_prefix("CallBody_"), true, false) if up != null else null
			if row != null:
				UiKit.attention(row as CanvasItem)


# ---------------------------------------------------------------------------
# The break from quarter time on: one line a call (director, 2026-10-14)
# ---------------------------------------------------------------------------
## What a call's sheet is headed, and what its row says it is.
const CALL_TITLES := {"plan": "Game plan", "pep": "Pep talk", "tag": "Tag",
		"def": "Defensive set-up", "pt": "Play through"}
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
		rtag.autowrap_mode = TextServer.AUTOWRAP_OFF
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
		# The sheet or the pane says what the call is: its own small heading
		# goes (the three play-through calls keep theirs: one heading each).
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
	if who_wb != null:
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
	body.call("plan", [take.call("PlanPicker", true), take.call("PlanNote"), _calls_record("gameplan"), c["syn"]])
	body.call("pep", [take.call("PepPicker", true), take.call("PepNote"), _calls_record("pep")])
	body.call("tag", [fact, take.call("TagPicker", true), who_line, take.call("TagNote")])
	var through: Array = []
	for slot in MatchNotes.FOCUS_ORDER:
		through.append(take.call("FocusPicker_" + str(slot), true))
	body.call("pt", through)
	body.call("def", [take.call("DefenceBlock")])
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
			NameInk.set_line(r.get_meta("answer") as RichTextLabel, a, _names_named(_answer_ids(str(key), calls, c)))
			var changed := a != str(first[key])
			(r.get_meta("changed") as Label).visible = changed
			(r.get_meta("rule") as ColorRect).color = UiKit.club_vivid(str(GameState.my_club), UiKit.SURFACE) if changed else Color.TRANSPARENT
	_break_refresh.call()

	var q := sim.current_quarter
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
	# The page, on a phone and beside the open call on a PC: the quarter just
	# played (from quarter time on) or your side (before the bounce), then the
	# rows. Best so far, what your calls did and the full numbers are one tap
	# away, so the break keeps the same height whatever the quarter threw up.
	var page: VBoxContainer = v
	var pane: MarginContainer = null
	var pane_title: Label = null
	if wide:
		var cols := UiKit.hbox(24)
		cols.name = "BreakColumns"
		page = UiKit.vbox(6)
		page.name = "BreakPage"
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		page.size_flags_stretch_ratio = 0.85
		cols.add_child(page)
		var right := UiKit.vbox(6)
		right.name = "BreakOpenCall"
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		right.size_flags_stretch_ratio = 1.15
		cols.add_child(right)
		pane_title = UiKit.section("")
		pane_title.name = "CallPaneTitle"
		right.add_child(pane_title)
		pane = MarginContainer.new()
		pane.name = "CallPane"
		right.add_child(pane)
		for key in order:
			put.call(pane, bodies[key])
		v.add_child(cols)
	if q > 1:
		# The weather's turn, when it turns at this break, leads the page (row 160).
		var turn_news: Control = take.call("BreakWeatherTurn")
		if turn_news != null:
			put.call(page, turn_news)
		var head := UiKit.hbox(8)
		if quarter_head != null:
			quarter_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			put.call(head, quarter_head)
		if best != null:
			var open_best := UiKit.text_action("Best so far", UiKit.BODY)
			open_best.name = "BestSoFarOpen"
			# In the sheet the two ways to the full numbers share one row of text
			# links, not two more bars above Done. A PC has "All player stats" in
			# the sheet's heading and Match stats beside Start.
			var links: HBoxContainer = null
			if not wide:
				links = UiKit.hbox(8)
				links.name = "BreakLinks"
				var stats: Control = take.call("BreakStats")
				var all_link: Control = best.find_child("BestSoFarAll", true, false)
				for lk in [stats, all_link]:
					if lk == null:
						continue
					if lk.get_parent() != null:
						lk.get_parent().remove_child(lk)
					lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_outline_link(lk as Button)
					links.add_child(lk)
			open_best.pressed.connect(func(): _open_break_sheet("best", "", [best, links], store))
			head.add_child(open_best)
		page.add_child(head)
		for n in [facts, legs]:
			put.call(page, n)
		# What your calls did can run long (every call, tag and lasting moment):
		# it is one row that opens the lot in a sheet.
		if did != null:
			if did_head != null and did_head.get_parent() != null:
				did_head.get_parent().remove_child(did_head)
				did_head.queue_free()
			if did.get_parent() != null:
				did.get_parent().remove_child(did)
			store.add_child(did)
			var open_did := UiKit.text_action("What your calls did", UiKit.BODY)
			open_did.name = "CallsDidOpen"
			open_did.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var did_note: Node = store.find_child("CallsDidNote", true, false)
			open_did.pressed.connect(func(): _open_break_sheet("did", "What your calls did", [did_note, did], store))
			page.add_child(open_did)
	else:
		# Before the bounce: the side (its row is added by _show_coach_box while
		# the side can still change), then your calls. Nobody has played, so
		# there is no quarter to read and no Best so far.
		var side_row := UiKit.vbox(0)
		side_row.name = "SideRow"
		page.add_child(side_row)
	var calls_head := UiKit.section("Your calls" if q == 1 else "Next quarter")
	calls_head.name = "CallsHeading"
	page.add_child(calls_head)
	page.add_child(rows)
	if q == 1:
		put.call(page, legs)
	if not wide:
		page.add_child(_skip_note(q, false))
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
		# A PC: the chosen call sits open beside the rows. The pane keeps the
		# room of its tallest call, so choosing another row never moves the sheet.
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
		# A PC sheet's actions sit together at the right, not as full-width bars.
		var acts := UiKit.hbox(12)
		acts.name = "BreakActions"
		acts.alignment = BoxContainer.ALIGNMENT_END
		# What Skip does reads beside it, at the left of the same row.
		acts.add_child(_skip_note(q, true))
		skip.custom_minimum_size = Vector2(150, 48)
		start.custom_minimum_size = Vector2(200, 48)
		var stats_pc: Button = c["stats_pc"]
		if stats_pc != null:
			stats_pc.custom_minimum_size = Vector2(110, 48)
			acts.add_child(stats_pc)
		acts.add_child(skip)
		acts.add_child(start)
		box["footer"].add_child(acts)
		# A mouse, not a thumb: the choices sit a little shorter on the PC sheet.
		for b in pane.find_children("*", "Button", true, false):
			if (b as Button).custom_minimum_size.y == 44.0:
				(b as Button).custom_minimum_size.y = PC_CHOICE_H
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
	# Before the bounce there is no break to have changed it at.
	var before_bounce := GameState.pending_sim != null and GameState.pending_sim.current_quarter <= 1
	var changed := UiKit.line("· changed" if before_bounce else "· changed this break", UiKit.SECONDARY, UiKit.TEXT)
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
			for g in _gameplans():
				if str(g[0]) == str(calls["gameplan"]):
					return str(g[1])
			return str(calls["gameplan"])
		"pep":
			for t in PEP_TALKS:
				if str(t[0]) == str(calls["pep"]):
					return str(t[1])
			return str(calls["pep"])
		"tag":
			if str(calls["tag_id"]) == "":
				return "No tag"
			var target: String = named.call(str(calls["tag_id"]), "their player")
			var who = (c["my_mids"] as Dictionary).get(str(calls["tagger_id"]), c["tagger"])
			return target if who == null else "%s, by %s" % [target, _initial_name(GameDB.player_display_name(who))]
		"def":
			return MatchNotes.defence_answer(str(calls["defence"]))
		"pt":
			# Same order as the row's label: forward, midfield, back. An empty
			# slot says "no one", so each name stays under its own heading.
			var who_through := PackedStringArray()
			var any_through := false
			for slot in MatchNotes.FOCUS_ORDER:
				any_through = any_through or str(calls[slot]) != ""
				who_through.append(named.call(str(calls[slot]), "no one"))
			return ", ".join(who_through) if any_through else "No one"
	return ""


## The players a call's answer names (by id), so its row can ink a surname two
## clubs share ("McDonald on van Rooyen") from who he is, not from the word.
func _answer_ids(key: String, calls: Dictionary, c: Dictionary) -> Array:
	var sim: MatchSim = c["sim"]
	var ids: Array = []
	match key:
		"tag":
			ids = [str(calls["tag_id"]), str(calls["tagger_id"])]
		"def":
			ids = [str(calls["interceptor_id"]), str(calls["minder_id"])]
		"pt":
			for slot in MatchNotes.FOCUS_ORDER:
				ids.append(str(calls[slot]))
	return ids.filter(func(i): return str(i) != "")


## `_names()` with the surname of each of these players pinned to his own club:
## a surname both clubs carry is left plain by the index (a guess could be
## wrong), but a line that says which player it means can say whose he is. Two
## of them sharing one surname across the clubs stay plain.
func _names_named(ids: Array) -> Dictionary:
	var out := _names().duplicate()
	var seen := {}
	var clash := {}
	for id in ids:
		var code := _club_code_of(str(id))
		var sur := _surname(GameDB.player_display_name_by_id(str(id), ""))
		if code == "" or sur == "":
			continue
		if seen.has(sur) and str(seen[sur]) != code:
			clash[sur] = true
		seen[sur] = code
	for sur in seen:
		if not clash.has(sur):
			out[sur] = seen[sur]
	return out


## The club (code) a player of this match plays for, "" if he is in neither side.
func _club_code_of(id: String) -> String:
	for side in [0, 1]:
		for r in _roster_side(side):
			if str(r.get("id", "")) == id:
				return str(_res["home"] if side == 0 else _res["away"])
	return ""


## The fact beside the tag: their busiest midfielder so far ("" before anyone
## has had the ball). A fact, never a suggestion.
func _tag_fact_line(sim: MatchSim) -> String:
	var busiest := _busiest_mid(sim)
	if busiest.is_empty():
		return ""
	var most := int(busiest["disposals"])
	return "%s has had %d disposal%s, the most of their midfielders." % [
			str(busiest["name"]), most, "" if most == 1 else "s"]


## Their busiest midfielder so far, {name, disposals}; {} before anyone has had the ball.
func _busiest_mid(sim: MatchSim) -> Dictionary:
	var top := {}
	var most := 0
	for r in _roster_side(1 - _my_side):
		if not _taggable_now(sim, r) or not _listed_midfielder(sim, r):
			continue
		var st: Dictionary = (_res.get("players", {}) as Dictionary).get(str(r["id"]), {})
		var n := int(float(st.get("disposals", 0.0)))
		if n > most:
			most = n
			top = {"name": GameDB.player_display_name(r), "disposals": n}
	return top


## A sheet over the break: one call (or who tags, or Best so far) with Done.
## Its parts are the break's own blocks, lent to the sheet and handed back to
## `home` when it closes, so a pick made here is the pick the quarter starts
## with. Back closes the top sheet (handle_back).
## What Skip to full time keeps and drops (G11; GateOdds.skip_line): beside
## the actions on a PC, at the foot of the calls on a phone.
func _skip_note(q: int, wide: bool) -> Label:
	var l := UiKit.lbl(GateOdds.skip_line(q), UiKit.NOTE, UiKit.TEXT)
	l.name = "SkipNote"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if wide:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _open_break_sheet(node_name: String, title: String, parts: Array, home: Node) -> void:
	# Best so far is a bottom sheet: the thumb's end of the screen, not floating.
	# A PC's sits over the oval like the break under it, centred; a mouse has no thumb's end.
	var foot := node_name == "best" and not _pc_break
	var box := UiKit.modal_box(_over, 640.0, 0.0, _wash(), foot, foot)
	var ov: Control = box["overlay"]
	ov.name = "CallSheet_" + node_name
	_dock(ov)
	# The break behind a sheet is out of sight: nothing of it reads, or shows
	# half-cut, past the sheet's edge.
	(ov as ColorRect).color = Color(0, 0, 0, 1.0)
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
		# Best so far: the links sit at the thumb's end with Done, the votes above.
		(box["footer"] as Node if foot and (p as Node).name == "BreakLinks" else v).add_child(p)
	var done := UiKit.btn("Done", UiKit.HEADING, true)
	done.name = "CallDone"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(_close_top_break_sheet)
	if foot:
		# Done is the one primary action, in the club fill.
		_club_fill_button(done)
		box["footer"].add_child(done)
		var wash_best := UiKit.team_wash() if _wash() == UiKit.AUTO_COLOUR else _wash()
		UiKit.edge_fade(box["body"].get_parent() as ScrollContainer, Color(wash_best, 0.2))
		_break_sheets.append({"overlay": ov, "close": _best_close(parts, home, ov)})
		return
	# Done stands 16 px clear of the links above it (the body's own gap is 8).
	v.add_child(UiKit.spacer(8))
	_club_fill_button(done)
	box["footer"].add_child(done)
	var wash_col := UiKit.team_wash() if _wash() == UiKit.AUTO_COLOUR else _wash()
	UiKit.edge_fade(box["body"].get_parent() as ScrollContainer, Color(wash_col, 0.2))
	_break_sheets.append({"overlay": ov, "close": _best_close(parts, home, ov)})


## A club-colour button on a sheet washed in a club colour needs an edge, and
## a fill that stands off the sheet: the club colour lifted until it reads
## 3:1 or better against the panel (never a dark purple on dark purple).
func _club_fill_button(done: Button) -> void:
	var lead := UiKit.team_colour()
	var fill := lead
	var v_up := lead.v
	for i in 20:
		if UiKit.contrast(fill, UiKit.tinted("sheet", lead)) >= 3.0:
			break
		v_up = minf(1.0, v_up + 0.05)
		fill = Color.from_hsv(lead.h, lead.s, v_up)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := done.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		sb.bg_color = fill if state == "normal" else (fill.lightened(0.08) if state == "hover" else fill.darkened(0.08))
		sb.set_border_width_all(2)
		sb.border_color = Color(UiKit.TEXT, 0.55)
		done.add_theme_stylebox_override(state, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		done.add_theme_color_override(k, Color.WHITE if UiKit.contrast(fill, Color.WHITE) >= UiKit.contrast(fill, Color("161512")) else Color("161512"))


## Closing a break sheet hands its parts back to the break they came from.
func _best_close(parts: Array, home: Node, ov: Control) -> Callable:
	return func() -> void:
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


## A text link made a real button: a 48 px outlined bar, easy to hit.
func _outline_link(b: Button) -> void:
	b.flat = false
	b.custom_minimum_size = Vector2(0, 48)
	var sb := UiKit.style(UiKit.SURFACE, 8, UiKit.RADIUS, Color(UiKit.TEXT, 0.45))
	sb.set_border_width_all(1)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = UiKit.SURFACE.lightened(0.06)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = UiKit.SURFACE.lightened(0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_color_override("font_pressed_color", UiKit.TEXT)


func _close_top_break_sheet() -> void:
	if _break_sheets.is_empty():
		return
	var s: Dictionary = _break_sheets.pop_back()
	if is_instance_valid(s["overlay"]):
		(s["close"] as Callable).call()


func _close_break_sheets() -> void:
	while not _break_sheets.is_empty():
		_close_top_break_sheet()


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
	# A break the weather turns at leads with the turn (row 160): it takes one of
	# the facts' places, so the break keeps its height on a phone.
	var room := MatchNotes.MAX_FACTS
	var sim: MatchSim = GameState.pending_sim
	if sim != null and not sim.weather_turn_now().is_empty():
		room -= 1
	lines = lines.slice(0, room)
	var opp_last := _opp_last_plan()
	if opp_last != "":
		lines = lines.slice(0, room - 1)
		# What they played, their answer to yours, their mood (RivalRead).
		lines.append(RivalRead.break_line(GameState.pending_sim, _my_side))
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
	return out


## A "Gain:" / "Cost:" style row: the marker bold, the sentence beside it, both
## in full ink (the card-stakes pattern).
## Fill `box` with a call's "Gain:" and "Cost:" rows ([gain, cost], unlabelled),
## the plan's look: the label in the label ink, the line in body text.
func _gain_cost_rows(box: Control, gc: Array, prefix: String) -> void:
	UiKit.clear(box)
	box.add_child(_plan_row("Gain:", str(gc[0]), prefix + "Gain"))
	box.add_child(_plan_row("Cost:", str(gc[1]), prefix + "Cost"))


func _plan_row(mark: String, text: String, node_name: String, traits := false, size := UiKit.SECONDARY) -> Control:
	var item := UiKit.hbox(6)
	item.name = node_name
	var mk := UiKit.lbl(mark, size, UiKit.label_ink(), true)
	mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mk.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.add_child(mk)
	# Synergies named here explain themselves on a tap (TraitLink).
	var l: Control = TraitLink.line(text, size, UiKit.TEXT) if traits else _say(text, size, UiKit.TEXT)
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
## "Q1  Demons: High Press  ·  Crows: Attack Corridor". Game plans are
## shown for both clubs (the break already tells you theirs). Pep talks and
## rotations of the other club are hidden from the coach, so those show only
## yours. Nothing before the first bounce.
func _calls_record(kind: String) -> Control:
	var hist: Array = GameState.pending_sim.tactics_history
	if hist.is_empty():
		return null
	var inks := UiKit.club_ink_pair(str(_res["home"]), str(_res["away"]))
	var v := UiKit.vbox(3)
	v.name = "CallsRecord_" + kind
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.subhead("Calls so far"))
	for e in hist:
		var plans: Array = e["plans"]
		var side_words := func(side: int) -> String:
			if kind == "gameplan":
				return CoachReport.plan_label(str((plans[side] as Dictionary).get("gameplan", "balanced")), side == _my_side)
			return CoachReport.pep_label(str((plans[side] as Dictionary).get("pep", "steady")))
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
			# The club in its own ink, both clubs alike (director A1, 2026-10-14), and
			# named in full as the break's title names it (Fremantle, not Dockers).
			var nm := UiKit.lbl(GameDB.club_name(code) + ": ", UiKit.SECONDARY, UiKit.club_name_colour(inks[side]), true)
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
	v.add_child(UiKit.subhead("Synergies"))
	v.add_child(_plan_row("Yours:", _synergy_names(syn[_my_side]), "SynYours", true))
	v.add_child(_plan_row("Theirs:", _synergy_names(syn[1 - _my_side]), "SynTheirs", true))
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
	var lines := CoachReport.impact_lines(now, before, _my_side, 0.3)
	if not lines.is_empty():
		var wnote := UiKit.lbl(MatchNotes.CALLS_WORTH_NOTE, UiKit.SMALL, UiKit.MUTED)
		wnote.name = "CallsWorthNote"
		wnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(wnote)
	# Each cause beside what it was worth (director, 2026-10-14: a figure at the far
	# end of the row "divorces the number from the source").
	var worth := GridContainer.new()
	worth.name = "CallsWorth"
	worth.columns = 2
	worth.add_theme_constant_override("h_separation", 24)
	worth.add_theme_constant_override("v_separation", 3)
	worth.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for l in lines.slice(0, 5):
		var pts := float(l["pts"])
		worth.add_child(UiKit.line(str(l["label"]), UiKit.SECONDARY, UiKit.TEXT))
		worth.add_child(UiKit.line("%+.1f pts" % pts, UiKit.SECONDARY, UiKit.GOOD if pts > 0 else UiKit.BAD, true))
	if worth.get_child_count() > 0:
		v.add_child(worth)
	# The calls, a quarter at a time.
	var moments: Array = _res.get("moments", [])
	var last_q := -1
	for m in moments:
		if q > 0 and int(m.get("q", 0)) != q:
			continue
		var mq := int(m["q"])
		if q == 0 and mq != last_q:
			last_q = mq
			var qh := UiKit.lbl("Q%d" % mq if mq <= 4 else "Extra time", UiKit.SMALL, UiKit.MUTED, true)
			qh.name = "CallsQuarter_%d" % mq
			v.add_child(UiKit.spacer(4))
			v.add_child(qh)
		var clock := _clock_text(mq, int(m["min"]))
		if q == 0:
			clock = clock.substr(clock.find(" ") + 1) if clock.contains(" ") else clock
		var l2 := _say("%s  %s: %s. %s" % [clock,
				str(m.get("title", "")), str(m.get("choice_label", "")), str(m.get("outcome", ""))],
				UiKit.SMALL, UiKit.EMPH if int(m.get("points", 0)) >= 6 else UiKit.TEXT)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	var tag_line := _tag_line(q)
	if tag_line != "":
		v.add_child(_say(tag_line, UiKit.SMALL, UiKit.TEXT))
	if lines.is_empty() and v.get_child_count() == 1:
		v.add_child(UiKit.lbl("An even quarter: no call moved the needle much.", UiKit.SMALL, UiKit.MUTED))
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
	return "Your tag on %s: %d disposal%s, %d goal%s." % [
			GameDB.player_display_name_by_id(tag_id, "their player"), int(d), "" if int(d) == 1 else "s",
			int(g), "" if int(g) == 1 else "s"]


## Legs in words: how both midfields are going, and who is running on empty.
func _legs_view() -> Control:
	var v := UiKit.vbox(2)
	v.name = "LegsView"
	var l := UiKit.lbl(MatchNotes.legs_line(_group_energy(_my_side), _group_energy(1 - _my_side),
			_opp_legs_reason()), UiKit.NOTE, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var cooked := MatchNotes.cooked(GameState.pending_sim.legs(_my_side))
	if not cooked.is_empty():
		var c := UiKit.lbl("Running on empty: %s." % ", ".join(cooked), UiKit.NOTE, UiKit.TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(c)
	return v


## Why their legs are going (RivalRead.legs_reason): the plans and fire-ups
## that cost them legs, when their calls cost more than yours. "" otherwise.
func _opp_legs_reason() -> String:
	var sim: MatchSim = GameState.pending_sim
	return RivalRead.legs_reason(RivalRead.calls_of(sim, 1 - _my_side), RivalRead.calls_of(sim, _my_side))


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
	# The late centre ball-up call, and the run of goals against (row 14), both
	# put to the coach over a centre ball-up.
	var bounce := str(m.get("kind", "")) == "bounce" or bool(m.get("moves", false))
	if bounce and GameState.vignettes_on():
		_show_bounce_moment(m)
		return
	# Row 13: every other call with a scene is a scene too.
	if GameState.vignettes_on() and DecisionVignette.has_scene(str(m.get("kind", ""))):
		_show_bounce_moment(m)
		return
	# Sized for its few lines, not the whole phone.
	var box := UiKit.modal_box(_over, 560.0, 440.0, _wash())
	_moment_overlay = box["overlay"]
	_moment_overlay.name = "MomentCard"
	_dock(_moment_overlay)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Coach's call  ·  %s" % _clock_text(int(m.get("q", 1)), int(m.get("min", 0))),
			UiKit.SMALL, UiKit.MUTED))
	var title := UiKit.lbl(str(m.get("title", "")), 20, UiKit.EMPH, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	if bounce and not bool(m.get("moves", false)):
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
		_moment_lines(v, o)


## The late centre-bounce call as a scene (ARD-M8-007 prototype): the match
## cuts to a close-up of that stoppage, the players set up, the ball goes up
## and it freezes; the call slides up over the frozen scene; the choice cuts
## back to the match. The options and what they do are MatchSim's; the scene
## only shows the state of the match.
func _show_bounce_moment(m: Dictionary) -> void:
	var overlay := UiKit.cover(_over)
	overlay.color = Color(0, 0, 0, 0)
	overlay.name = "MomentCard"
	overlay.set_meta("scene", true)
	_moment_overlay = overlay
	_dock(overlay)
	var vignette: StoppageVignette
	if str(m.get("kind", "")) == "bounce" or bool(m.get("moves", false)):
		vignette = StoppageVignette.new()
		vignette.name = "StoppageVignette"
	else:
		vignette = DecisionVignette.new()
		vignette.name = "DecisionVignette"
	overlay.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.clip_contents = true   # its stand and light towers stay off the scoreboard
	# A scene that takes the score is handed the one the scoreboard shows, so the
	# two never disagree while the oval catches up with the sim.
	var shown := {"goals": _shown_goals.duplicate(), "behinds": _shown_behinds.duplicate()}
	vignette.live_spots = _live_spots()
	if vignette is DecisionVignette:
		(vignette as DecisionVignette).setup_decision(GameState.pending_sim, _my_side, m, shown)
	else:
		vignette.setup(GameState.pending_sim, _my_side, str(m.get("title", "")), shown)
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
	# The run-of-goals call is about the goals, not the stoppages: no ruck line.
	for f in ([] if bool(m.get("moves", false)) else vignette.facts):
		var fl := _say(str(f), UiKit.BODY, UiKit.TEXT, true)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		call.add_child(fl)
	var text := _say(str(m.get("text", "")), UiKit.SMALL, UiKit.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	call.add_child(text)
	var buttons: Array = []
	var options: Array = m.get("options", [])
	# A PC's call sits over the oval's place, wider than it is tall: its choices stand
	# side by side, each over its own gain and cost, so the call is a low band and
	# the scene shows above it. A phone stacks them, as ever.
	var across: HBoxContainer = null
	if _pc and options.size() > 1:
		across = UiKit.hbox(12)
		across.name = "MomentOptions"
		call.add_child(across)
	for i in range(options.size()):
		var o: Dictionary = options[i]
		var into: Container = call
		if across != null:
			into = UiKit.vbox(6)
			into.name = "MomentOption_%d" % i
			into.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			across.add_child(into)
		# Every choice stands equal: no filled first button that reads as the
		# recommended one (director's PC playtest, 2026-10-07).
		var b := UiKit.btn(str(o.get("label", "")), 16, false)
		b.name = "Moment_%d" % i
		b.custom_minimum_size = Vector2(0, 46)
		b.disabled = true
		b.pressed.connect(_on_moment_choice.bind(i))
		into.add_child(b)
		buttons.append(b)
		_moment_lines(into, o)
	panel.modulate.a = 0.0
	# The scene keeps its men above the call: it is told the call's height once the
	# call is up, and again whenever the laid-out panel changes height (its wrapped
	# lines settle a frame or two after it is first shown).
	var call_up := [false]
	var tell_room := func() -> void:
		if call_up[0] and is_instance_valid(vignette) and is_instance_valid(panel):
			vignette.call_room = panel.size.y
	panel.resized.connect(tell_room)
	margin.add_theme_constant_override("margin_bottom", -600)
	vignette.ready_for_call.connect(func() -> void:
		for b in buttons:
			if is_instance_valid(b):
				b.disabled = false
		if not is_instance_valid(margin):
			return
		panel.modulate.a = 1.0
		call_up[0] = true
		tell_room.call()
		var tw := margin.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: margin.add_theme_constant_override("margin_bottom", int(v)),
				-600.0, 0.0, 0.3))


## Under a call's choice: what it does for you and what it costs, sized
## (GateOdds; "gain" and "cost" on the option), or its one line of words.
func _moment_lines(to: Container, o: Dictionary) -> void:
	if o.has("gain"):
		# The break's look: "Gain:" and "Cost:" in the label ink, the line in body
		# text, at the card's small size so the men stay in view above it.
		# Its two lines held tight together, one block under its button.
		var pair := UiKit.vbox(0)
		pair.name = "MomentOdds"
		to.add_child(pair)
		for f in [["gain", "MomentGain"], ["cost", "MomentCost"]]:
			var line := str(o[f[0]])
			var cut := line.find(": ")
			pair.add_child(_plan_row(line.substr(0, cut + 1) if cut > 0 else "", line.substr(cut + 2) if cut > 0 else line, str(f[1]), false, UiKit.SMALL))
		return
	var d := UiKit.lbl(str(o.get("detail", "")), UiKit.SMALL, UiKit.MUTED)
	d.name = "MomentDetail"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	to.add_child(d)


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
	# The call's name owns the choices under it: name weight in your club's ink (STYLE-03).
	var l := UiKit.lbl(label, UiKit.NAME, UiKit.label_ink(), true)
	l.name = "CallHeading"
	return l


func _call_block(label: String, control: Control) -> Control:
	var v := UiKit.vbox(4 if _pc_break else 6)
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
			# Cards set their own facts (_dress_tagger_card): one man to a
			# row, the column's full width, so his facts never wrap a word to a
			# line (A2); "Other player..." last.
			grid.columns = 1
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
				(gb as Control).custom_minimum_size.y = PC_CHOICE_H
			# From quarter time the chosen call has a wide pane: five or six
			# choices (none, the few in the game, Other) sit three to a row
			# there, so the Tag call is two rows, not three, and the fullest
			# break still fits 1280x720.
			if _pc_one_line and grid.get_child_count() >= 5:
				grid.columns = 3
	rebuild.call(rebuild)
	return box


## A player's card text: his name, then what `detail` says about him.
func _card_text(r: Dictionary, detail: Callable) -> String:
	# A card keeps its groups on their own lines (MatchNotes.card_detail).
	var extra := str(detail.call(r, false)) if detail.is_valid() else ""
	return _short_name(r) if extra == "" else "%s\n%s" % [_short_name(r), extra]


## A "Who tags" card (director, 2026-10-13: it must read at a glance): his name
## in bold with where he plays small beside it, then his Pressure and his legs
## along one line (label quiet, value clear), their man's touches with him on
## (row 120) and what he gives up of his own game under them. One man to a row, the column's full
## width (A2). Your club's colour is the rule down the left edge;
## selection stays the button's own text outline. The button stays the card's
## background and its tap target, under the words; its words are kept in the
## "card_text" meta for the tests.
func _dress_tagger_card(b: Button, who_name: String, c: Dictionary, is_pick: bool) -> void:
	var gives_value := str(c["gives"]).left(1).to_upper() + str(c["gives"]).substr(1)
	var press_value := "%s · their man: %s" % [c["pressure"], c["holds"]]
	var plain := "%s\n%s\nPressure %s\nLegs %s\n%s %s" % [who_name, c["where"], press_value, c["legs"],
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
		nm.add_theme_color_override("font_color", UiKit.club_name_colour(UiKit.club_ink(str(_names()[who_name]))))
	head.add_child(nm)
	var where := UiKit.line(str(c["where"]), UiKit.SECONDARY, UiKit.MUTED)
	where.name = "CardWhere"
	head.add_child(where)
	col.add_child(head)
	# The short facts flow along one line, each label quiet beside its value,
	# and wrap whole (never a word to a line, A2); their man's touches and what
	# he gives up are the long ones, a line of their own each under them.
	var rows := [["Pressure", str(c["pressure"]), false], ["Legs", str(c["legs"]), bool(c["legs_bad"])]]
	if _pc_break:
		# His season rating, which sits with "Gives up" on a phone card.
		var season := str(c["gives"]).trim_prefix(GateOdds.tag_gives()).strip_edges().trim_prefix("(").trim_suffix(")")
		rows.append(["Season", season.trim_prefix("season rating ").replace("yet to play this season", "yet to play"), false])
	var facts := HFlowContainer.new()
	facts.name = "CardFacts"
	facts.add_theme_constant_override("h_separation", 16)
	facts.add_theme_constant_override("v_separation", 0)
	for f in rows:
		var one := UiKit.hbox(5)
		one.add_child(UiKit.line(str(f[0]), UiKit.SECONDARY, UiKit.MUTED))
		one.add_child(UiKit.line(str(f[1]), UiKit.BODY, UiKit.BAD if bool(f[2]) else UiKit.TEXT))
		facts.add_child(one)
	col.add_child(facts)
	# Their man's touches: the label quiet, the counts clear, wrapping inside
	# the card rather than pushing it past the screen's edge.
	var holds := UiKit.hbox(5)
	holds.name = "CardHolds"
	holds.add_child(UiKit.line(str(c["holds_label"]), UiKit.SECONDARY, UiKit.MUTED))
	var holds_value := UiKit.lbl(str(c["holds"]), UiKit.BODY, UiKit.TEXT)
	holds_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holds_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holds.add_child(holds_value)
	col.add_child(holds)
	# On a PC the Cost row under the cards says what the tagger gives up, the
	# same for every man, so the card leaves it out (his season rating is in
	# its facts) and the fullest break still fits 1280x720.
	if not _pc_break:
		var gives := UiKit.lbl("%s %s" % [c["gives_label"], c["gives"]], UiKit.SECONDARY, UiKit.TEXT)
		gives.name = "CardGives"
		gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(gives)
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
	var box := UiKit.modal_box(_over, 480.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "PlayerSheet"
	_sheet_overlay = overlay
	_dock(overlay)
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
		var b := UiKit.btn(line if extra == "" else line + "\n" + extra, 14)
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
	var w := UiKit.AUTO_COLOUR
	if mine == home:
		w = UiKit.opponent_wash(away)
	elif mine == away:
		w = UiKit.opponent_wash(home)
	# No usable opponent colour (opponent_wash answers plain text): the sheet
	# carries your own club's colour instead of a neutral grey.
	return UiKit.AUTO_COLOUR if w == UiKit.TEXT else w


## The sheet's wash colour, resolved (AUTO is your club's colour).
func _wash_col() -> Color:
	return UiKit.team_wash() if _wash() == UiKit.AUTO_COLOUR else _wash()


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
func _can_play_midfield(sim: MatchSim, r: Dictionary) -> bool:
	return sim.tag_target_ok(1 - _my_side, str(r["id"]))


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
	var box := UiKit.modal_box(_over, SHEET_MAX_W if _stats_wide() else 640.0, 0.0, _wash())
	var overlay: Control = box["overlay"]
	overlay.name = "BreakStatsSheet"
	_report_overlay = overlay
	_shut_bench()
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis("Match stats", UiKit.H1, UiKit.TEXT, true))
	var box_score := _stats_page(v, true, players_first)
	box_score.name = "BreakBoxScore"
	var close := UiKit.btn("Back to your calls", UiKit.NAME, true)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_report)
	box["footer"].add_child(close)


## Best so far, on the break: the three best of each side by match rating so
## far (yours first), each with the numbers that stand out, as full time's best
## players read, but no votes (they come at full time); "All player stats"
## opens the full table.
# A PC break is tight (the fullest one, GWS with both loose men, has 8 px to
# spare and Best so far may be at most ~213 px tall), so the rows sit 4 px apart
# there; a phone scrolls and has room for more.
const BEST_ROW_GAP_PC := 2


func _best_so_far() -> Control:
	var box := UiKit.vbox(4 if _pc_break else VOTES_STEP)
	box.name = "BestSoFar"
	var head := UiKit.hbox(8)
	var title := UiKit.section("Best so far")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var all := UiKit.text_action("All player stats", UiKit.BODY)
	all.name = "BestSoFarAll"
	all.custom_minimum_size = Vector2(0, 24 if _pc_break else 48)
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
	# No votes yet: the coaches give theirs once, at full time (director,
	# 2026-11-08). The break ranks each side by match rating so far.
	for side in [_my_side, 1 - _my_side]:
		var code := str(_res["home"] if side == 0 else _res["away"])
		var players := MatchNotes.best_so_far(_res, side, 3)
		var wrap := _votes_side(code, inks[side], players, {}, _pc_break)
		wrap.name = "BestSide_%d" % side
		(wrap.find_child("ClubName", true, false) as Node).name = "BestClub_%d" % side
		(wrap.get_child(1) as Node).name = "BestSideBox_%d" % side
		box.add_child(wrap)
	if not _pc_break:
		box.add_child(UiKit.spacer(8))   # with the body's 8: 16 clear of the buttons
		box.add_child(all)
	return box


func _glance_section(v: VBoxContainer, title: String, node_name: String, lines: Array, traits := false) -> void:
	if lines.is_empty():
		return
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section(title))
	var box := UiKit.vbox(4)
	box.name = node_name
	for t in lines:
		var l: Control = TraitLink.line(str(t), UiKit.BODY, UiKit.TEXT) if traits else _say(str(t), UiKit.BODY, UiKit.TEXT)
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
	_set_clock_word("")
	GameState.pending_sim.begin_quarter()
	_advance_segment()


## Simulate on to the end of the quarter or the next moment, then play it.
func _advance_segment() -> void:
	var sim: MatchSim = GameState.pending_sim
	_legs_seen = _legs_now(sim)
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
	# Rotations are the assistant's (director, 2026-11-03): the season plan
	# and the legs set them each quarter (MatchSim.auto_rotation).
	sim.set_rotation_policy(_my_side, sim.auto_rotation(_my_side, GameState.fitness_plan(str(GameState.my_club))))
	# The rival coach plays its usual game, protects a lead, chases a
	# deficit, and tags your best midfielder after half time.
	sim.set_tactics(1 - _my_side, sim.ai_tactics(1 - _my_side))
	# Every club rotates as a competent coach would, the rival included.
	var rival := str((sim.squads[1 - _my_side] as Squad).code)
	sim.set_rotation_policy(1 - _my_side, sim.auto_rotation(1 - _my_side, GameState.fitness_plan(rival)))


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


## Under a Play through control: his job and what it does for him; the
## general description with nobody picked; that it waits while he is off the spot.
func _focus_waits(slot: String, id: String) -> bool:
	if id == "":
		return false
	var sim: MatchSim = GameState.pending_sim
	if sim == null:
		return false
	for p in (sim.squads[_my_side] as Squad).ground:
		if str(p["id"]) == id:
			return not (MatchSim.FOCUS_SLOT_ROLES[slot] as Array).has(str(p["role"]))
	return true


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


## "High Press · tagging Walsh": your calls for this quarter, one line.
func _show_setup(t: Dictionary) -> void:
	if _setup_line == null or not is_instance_valid(_setup_line):
		return
	var bits := PackedStringArray(["Your plan: " + CoachReport.plan_label(str(t.get("gameplan", "balanced")))])
	var tag_id := str(t.get("tag_id", ""))
	if tag_id != "":
		bits.append("tagging " + GameDB.player_display_name_by_id(tag_id, "their player"))
	for slot in MatchNotes.FOCUS_ORDER:
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
## Tired and hurt players carry a short mark on the oval and in the bench's drawer
## (PlayerMarks): the hurt from the injuries played so far, either side; the
## tired from your own side's legs, in a match you coach.
func _refresh_marks() -> void:
	var injuries: Array = _res.get("injuries", [])
	var energy := {}
	var sim_now = GameState.pending_sim if _interactive else null
	if sim_now != null:
		injuries = sim_now.injuries
		# The sim has run ahead of the oval: its legs now are the end of the stretch
		# still playing, so the marks use the legs from when that stretch began.
		energy = _legs_now(sim_now) if _pitch.current_index() >= _pitch.events.size() else _legs_seen
	_pitch.set_marks(PlayerMarks.build(_pitch.events, _pitch.current_index(), injuries, energy))


## Your side's legs in the sim right now: id -> energy.
func _legs_now(sim: MatchSim) -> Dictionary:
	var out := {}
	for r in sim.legs(_my_side):
		out[str(r["id"])] = float(r["energy"])
	return out


## The ring on the oval: the players of yours you have made a call on or
## promised a run (MatchRings). Calls change at the breaks and at the moments,
## so it is read again with every event: a few lookups, and the view only
## redraws when the set moved. Only a match you coach has calls to show.
func _refresh_rings() -> void:
	if _pitch == null:
		return
	_refresh_marks()
	if _interactive and GameState.pending_sim != null:
		_pitch.set_rings(MatchRings.ids(GameState.pending_sim, _my_side, GameState.my_list))
	else:
		_pitch.set_rings([])


func _on_event(ev: Dictionary) -> void:
	var shown_usec := Time.get_ticks_usec()     # row 6.51: the crowd's gap is measured from here
	# The crowd first, so the roar and the siren start on the tick, not after the
	# feed and the scoreboard are built (about 6 ms later, measured). A goal skipped
	# past still counts toward the run the crowd is riding; it makes no sound.
	if _crowd != null:
		_crowd.event(str(ev.get("kind", "")), int(ev.get("side", 0)), shown_usec, not _skipping, int(ev.get("q", 0)))
	var event_index := _playback_event_index
	_playback_event_index += 1
	# Skipping to the break releases a quarter's events at once: the rings and
	# the meter are painted once at the end, not for every event.
	if not _skipping:
		_refresh_rings()
	_update_scoreboard(ev)
	_track_momentum(ev)
	_track_live_stats(ev)
	_feed_add(ev)
	# A career best at a goal is that goal's one extra line: no battle or
	# story line stacks on it.
	if not _career_high_feed(ev) or str(ev.get("kind", "")) != "goal":
		_duel_feed(ev)
		_story_feed(ev)
	_press_feed(event_index, ev)
	_call_feed(event_index, ev)
	if str(ev.get("kind", "")) == "goal":
		_flash_score(int(ev.get("side", 0)))
		_track_run(int(ev.get("side", 0)))
	_queue_broadcast(ev, event_index)


## Where the live oval has each man right now, by his id, in a call scene's metres (x
## across, y toward the goal your side kicks at): the scene shows the same ground the
## coach was watching (director, 2026-11-12: "Why not show people in their actual
## positions?"). Read only.
func _live_spots() -> Dictionary:
	var out := {}
	if _pitch == null or _pitch.director == null:
		return out
	var sgn := MatchDirector._dir(_my_side)
	for token in _pitch.director.tokens:
		var p: Vector2 = token.get("pos", Vector2.ZERO)
		out[str(token.get("pid", ""))] = Vector2(p.y, p.x) * sgn
	return out


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
		next_ev = BroadcastVignette.next_play_event(_pitch.events, event_index)
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
	var overlay := UiKit.cover(_over)
	overlay.name = "BroadcastVignetteOverlay"
	_dock(overlay)
	overlay.color = Color(0.015, 0.018, 0.02, 1.0)
	_broadcast_overlay = overlay
	# STYLE-06 (row 6.34): the cut to the close-up eases in with the figures
	# instead of the oval snapping to black (motion rule: a screen eases in).
	if UiKit.motion_on():
		overlay.modulate.a = 0.0
		overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, UiKit.Motion.DUR_FAST) 				.set_trans(UiKit.Motion.TRANS_IN).set_ease(UiKit.Motion.EASE_IN)
	var vignette := BroadcastVignette.new()
	vignette.name = "BroadcastVignette"
	overlay.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.setup(kind, ev, snap, _res)
	vignette.finished.connect(_finish_broadcast)


func _finish_broadcast() -> void:
	if _broadcast_overlay != null and is_instance_valid(_broadcast_overlay):
		var gone := _broadcast_overlay
		gone.name = "BroadcastVignetteLeaving"
		if UiKit.motion_on():
			# Back to the oval the same way: the cover eases off over the ground,
			# which is already playing again under it; it takes no taps while it goes.
			gone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw := gone.create_tween()
			tw.tween_property(gone, "modulate:a", 0.0, UiKit.Motion.DUR_FAST) 					.set_trans(UiKit.Motion.TRANS_OUT).set_ease(UiKit.Motion.EASE_OUT)
			tw.tween_callback(gone.queue_free)
		else:
			gone.queue_free()
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
	var head := MatchNotes.goal_head(who, code)
	# The scorer's club is the event's own, whatever the index knows.
	var names := _names().duplicate()
	if who != "":
		names[who] = code
	var tone := MatchNotes.feed_tone(ev, _my_side)
	row.set_meta("tone", tone)
	var head_col: Color = UiKit.GOOD if tone == "good" else (UiKit.BAD if tone == "bad" else UiKit.TEXT)
	var hl := NameInk.label(head, names, UiKit.NAME, head_col, true)
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
	if str(ev.get("kind", "")) == "final":
		_clock_word = "full"
	elif _clock_word != "" and (_skipping or (_pitch != null and _pitch.playing)):
		# The ball is in play (a match watched, not coached, has no break sheet to
		# say so; nor has a skip to full time).
		_clock_word = ""
	_paint_scoreboard()


## The sides have changed ends: the next period is starting, so the clock shows
## it from its first minute rather than the last minute of the one before.
## The period is the pitch's own count (2 for the second quarter, 5 for extra
## time), not one more than shown: a substitute's change logged at the break
## already shows the next quarter.
func _on_ends_changed(period: int) -> void:
	if _finished or _skipping:
		return
	_shown_q = period
	_shown_min = (_shown_q - 1) * QUARTER_MINUTES
	_paint_scoreboard()


func _paint_scoreboard() -> void:
	if _score_home == null or _score_away == null:
		return
	_score_home.text = UiKit.scoreline(_shown_goals[0], _shown_behinds[0])
	_score_away.text = UiKit.scoreline(_shown_goals[1], _shown_behinds[1])
	_fit_scores()
	_paint_clock()
	if _lead != null and is_instance_valid(_lead):
		var narrow := _board_narrow()
		var name_of := func(c): return GameDB.club_short(str(c)) if narrow else GameDB.club_name(str(c))
		_lead.text = MatchNotes.lead_text(str(_res["home"]), str(_res["away"]), [
				_shown_goals[0] * 6 + _shown_behinds[0], _shown_goals[1] * 6 + _shown_behinds[1]], name_of)


## Both scores at one size: the largest at which the longer one fits its half
## of the band (row 6.29; a phone's 28.18 (186) ran past the band's clipped
## edge). They step down together, so neither club's score reads smaller.
func _fit_scores() -> void:
	if _score_band == null or not is_instance_valid(_score_band) or _score_home == null:
		return
	var narrow := _board_narrow()
	# A PC's band is its column's width; a phone's never runs past the screen's edge.
	var band := _score_band.size.x if _pc else minf(_score_band.size.x, UiKit.view_width(self) - 2.0 * _score_band.global_position.x)
	# The band's padding (8 a side), the row's two gaps (6) and the clock between.
	var room := (band - 16.0 - 12.0 - (84.0 if narrow else 132.0)) / 2.0
	var sizes := [UiKit.RATING, UiKit.SCORE, UiKit.NUMBER] if narrow else [WIDE_SCORE, 36, UiKit.RATING, UiKit.SCORE]
	if _pc:
		sizes = [PC_SCORE, UiKit.RATING, UiKit.SCORE, UiKit.NUMBER]
	var font: Font = _score_home.get_theme_font("font")
	var fs: int = sizes[-1]
	for s: int in sizes:
		var wide := maxf(font.get_string_size(_score_home.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.px(s)).x,
				font.get_string_size(_score_away.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.px(s)).x)
		if wide <= room:
			fs = s
			break
	for l: Label in [_score_home, _score_away]:
		UiKit.set_font_size(l, fs)


## The stoppage the clock names ("pre", "q1", "q2", "q3", "full"), or "" once
## the ball is in play again.
func _set_clock_word(word: String) -> void:
	if _clock_word == word:
		return
	_clock_word = word
	_paint_clock()


## The clock between the scores: the stoppage's name while one is on, else the
## minute of the quarter. A stoppage's name is longer than a minute: it steps
## down in size, then to its shorter form, until it fits between the scores.
## The scores never give up room to it.
func _paint_clock() -> void:
	if _clock == null or not is_instance_valid(_clock):
		return
	var base := int(_clock.get_meta("fs", 17))
	if _clock_word == "":
		_clock.text = _clock_text(_shown_q, _shown_min)
		UiKit.set_font_size(_clock, base)
		return
	var room := float(_clock.get_meta("room", 84.0))
	var font: Font = _clock.get_theme_font("font")
	var words: Array = CLOCK_WORDS[_clock_word]
	var floor_fs := mini(base, UiKit.SMALL)
	for w in words:
		var fs := base
		while fs >= floor_fs:
			if font.get_string_size(str(w), HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.px(fs)).x <= room:
				_clock.text = str(w)
				UiKit.set_font_size(_clock, fs)
				return
			fs -= 1
	_clock.text = str(words[words.size() - 1])
	UiKit.set_font_size(_clock, floor_fs)


## "Q3 12'": the minute of the quarter, like a ground's clock. MatchSim
## stamps each quarter 30 minutes on from the last; extra time counts its
## own minutes from zero.
func _clock_text(q: int, minute: int) -> String:
	if q >= 5:
		return "ET %d'" % clampi(minute - 120, 0, 99)
	var into := clampi(minute - (q - 1) * QUARTER_MINUTES, 0, QUARTER_MINUTES)
	return "Q%d %d'" % [q, EraFootball.clock_minutes(into, GameState.season_year)]


func _feed_add(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if QUIET_KINDS.has(kind) and not bool(ev.get("substitute", false)):
		return
	var line := MatchNotes.feed_line(ev, str(_res["home"]), str(_res["away"]))
	if line.is_empty():
		return
	var stamp := _clock_text(int(ev.get("q", 1)), int(ev.get("min", 0)))
	if str(line["tier"]) == "goal":
		_feed.add_child(_goal_row(ev, stamp))
		ProblemReport.note_feed("%s  %s" % [stamp, str(line["text"])])
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


## A line whose words change later: always tinted-capable.
func _say_live(text: String, fs: int, col: Color, ids := []) -> RichTextLabel:
	var r := NameInk.rich(fs, col)
	NameInk.set_line(r, text, _names_named(ids) if not ids.is_empty() else _names())
	return r


## A line of the match's talk: plain, or with each player's name in his club's ink.
## `ids`: the players the line means, so a surname two clubs share still wears
## his club's ink (see _names_named).
func _say(text: String, fs: int, col: Color, bold := false, ids := []) -> Control:
	return NameInk.label(text, _names_named(ids) if not ids.is_empty() else _names(), fs, col, bold)


func _feed_text(text: String, col: Color, strong: bool, node_name: String) -> void:
	if _feed == null:
		return
	var l := _say(text, UiKit.SMALL, col, strong)
	l.name = node_name
	# Siblings cannot share a name, so the row's kind rides as metadata.
	l.set_meta("feed_kind", node_name)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)
	ProblemReport.note_feed(text)
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
		# The newest row taller than the feed's room (a two-line row under a
		# two-line plan): open on its first line, never hide it as cut.
		var last := _feed.get_child(_feed.get_child_count() - 1) as Control if _feed.get_child_count() > 0 else null
		if last != null and last.size.y > _feed_scroll.size.y:
			_feed_scroll.scroll_vertical = int(last.position.y)
		_hide_cut_rows()


## While the feed sits at its newest line, a row whose top has scrolled out of
## view is not drawn, so the feed never opens on the tail of a wrapped line
## (at a larger text size a two-line row showed only its last word). Scrolled
## back up by the coach, every row shows as it is.
func _hide_cut_rows() -> void:
	if not is_instance_valid(_feed_scroll) or not is_instance_valid(_feed):
		return
	var bar := _feed_scroll.get_v_scroll_bar()
	var top := float(_feed_scroll.scroll_vertical)
	var following := top >= bar.max_value - bar.page - 1.0
	for c in _feed.get_children():
		if c is CanvasItem:
			var cut := following and (c as Control).position.y < top - 0.5
			(c as CanvasItem).modulate.a = 0.0 if cut else 1.0


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
		_legs_seen = _legs_now(GameState.pending_sim)
		_res = GameState.pending_sim.run_extra_time()
		_stamp_match_meta()
		_append_new_events()
		_pitch.play()
		_sync_controls()
		return
	_skipping = false
	_finished = true
	# A match skipped to its end never painted the meter on the way (_track_momentum):
	# it says who had the run of play at the siren, not the "Even" it started on.
	_paint_momentum()
	_live_break = 5
	_paint_live_stats()
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
		v.offset_top = _over.offset_top   # under the scoreboard, as every scene (T3.R42)
		v.clip_contents = true            # its stand's roof stays off the scoreboard
		_farewell = {}
		var wv: WeakRef = weakref(v)   # not the node: it frees itself when it ends
		tree_exiting.connect(func():            # Back out of the match: it goes too
			var n = wv.get_ref()
			if n != null:
				n.finish_now())


## Who the scene after the siren honours, and both sides' players: {} unless your
## side has a milestone man (FarewellVignette.caption) who is in the side today.
## The pre-season practice match (GameState.prepare_practice_match): played
## for its own sake, so it carries no ladder, finals, debut or milestone talk.
func _is_practice(m: Dictionary) -> bool:
	return str(m.get("label", "")) == "Practice match"


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
	# A PC's Stats tab holds the score and the team numbers side by side, so the
	# sheet is wider there; the Summary keeps its own reading width inside it.
	var box := UiKit.modal_box(_over, SHEET_MAX_W if _stats_wide() else 640.0, 0.0, _wash())
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
	var wash_col := UiKit.team_wash() if _wash() == UiKit.AUTO_COLOUR else _wash()
	UiKit.edge_fade(box["body"].get_parent() as ScrollContainer, Color(wash_col, 0.2))

	var home: String = _res["home"]
	var away: String = _res["away"]
	var mine := GameState.my_club != "" and (home == GameState.my_club or away == GameState.my_club)
	# On a PC the two actions sit side by side at the sheet's right, one row tall, so the
	# stats page keeps the height (a phone stacks them).
	var actions: Control = box["footer"]
	if _stats_wide():
		var row := HBoxContainer.new()
		row.name = "FullTimeActions"
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 12)
		actions.add_child(row)
		actions = row
	if mine and (_interactive or _review):
		var train := UiKit.btn("Training", UiKit.BODY)
		train.name = "FullTimeTraining"
		train.custom_minimum_size = Vector2(240 if _stats_wide() else 0, 48)
		train.pressed.connect(func():
			overlay.queue_free()
			Router.replace("training"))
		actions.add_child(train)
	# The week is over: back to the hub, where next week starts.
	var leave := UiKit.btn("Continue", UiKit.HEADING, true)
	leave.name = "FullTimeContinue"
	leave.custom_minimum_size = Vector2(240 if _stats_wide() else 0, 48)
	_club_fill_button(leave)
	leave.pressed.connect(func(): Router.back())
	UiKit.feel(leave, "end")     # the end of the match: the siren
	actions.add_child(leave)
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
		b.custom_minimum_size.y = 48
		b.pressed.connect(func():
			_ft_tab = key
			_render_ft())
		_ft_tabs.add_child(b)
	# A PC: the Summary reads over the oval, the score and the feed still beside
	# it; the Stats tab is the one page of every number, and takes the screen.
	if _ft_tab == "stats":
		_undock(_ft_box["overlay"])
	else:
		_dock(_ft_box["overlay"])
	match _ft_tab:
		"stats":
			_ft_stats(v)
		_:
			if _stats_wide():
				var inner := UiKit.vbox(8)
				v.add_child(UiKit.reading_column(inner, 640.0))
				_ft_summary(inner)
			else:
				_ft_summary(v)
	var sc := v.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 0


## The match story at the top of the Summary: the hero and his game, the
## turning point, and why it was won or lost. Read from MatchStory; it never
## changes the result. Returns what it told (MatchStory.told_facts), so the
## sections below say each fact once.
func _ft_story(v: VBoxContainer, me: int) -> Dictionary:
	var st := MatchStory.build(_res, me)
	if st.is_empty():
		return {}
	var box := UiKit.vbox(4)
	box.name = "MatchStory"
	box.add_child(UiKit.spacer(UiKit.GAP))
	# Best players above already gives a player's numbers: the hero's line
	# keeps only what it adds (director's bug report, 2026-11-06).
	var shown := {}
	var votes := MatchNotes.coaches_votes(_res)
	for side in [0, 1]:
		for p in MatchNotes.standouts_by_votes(_res, side, 99, votes):
			shown[str(p["id"])] = str(p["line"])
	var hero: Dictionary = st["hero"]
	if not hero.is_empty():
		box.add_child(UiKit.section("Hero of the match"))
		var hl := UiKit.lbl(str(hero["name"]), UiKit.NAME,
				UiKit.club_name_colour(UiKit.club_ink(str(hero["club"]))), true)
		hl.name = "MatchHero"
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hl)
		var hero_line := MatchStory.line_less(hero, str(shown.get(str(hero["id"]), "")))
		if hero_line != "":
			var gl := UiKit.lbl(hero_line, UiKit.BODY, UiKit.TEXT)
			gl.name = "MatchHeroLine"
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(gl)
	# A loss: your best player too (director, 2026-11-03).
	if int(st["margin"]) < 0:
		var mb := MatchStory.my_best(_res, me)
		if not mb.is_empty():
			var mb_line := MatchStory.line_less(mb, str(shown.get(str(mb["id"]), "")))
			var ml := UiKit.lbl("Your best: %s" % str(mb["name"]) + (", " + mb_line.left(1).to_lower() + mb_line.substr(1) if mb_line != "" else ""),
					UiKit.BODY, UiKit.TEXT)
			ml.name = "MatchMyBest"
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(ml)
	if str(st["turning_point"]) != "":
		box.add_child(UiKit.section("Turning point"))
		var tl := UiKit.lbl(str(st["turning_point"]), UiKit.BODY, UiKit.TEXT)
		tl.name = "TurningPoint"
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(tl)
	var why: Array = st["reasons"]
	if not why.is_empty():
		box.add_child(UiKit.section("Why you won" if bool(st["won"])
				else ("Why it was a draw" if bool(st["drawn"]) else "Why you lost")))
		var rv := UiKit.vbox(4)
		rv.name = "WhyReasons"
		for r in why:
			var rl := UiKit.lbl(str(r["text"]), UiKit.BODY, UiKit.TEXT)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rv.add_child(rl)
		box.add_child(rv)
	_ft_calls(box, me)
	v.add_child(box)
	return MatchStory.told_facts(st)


## Our calls (row 144): each call beside what it added to the margin or took
## off it, then theirs and the players and the bounce, adding up to the final
## margin on the last row. Read from MatchStory.calls; nothing when the result
## carries no impact ledger (a match saved before it was kept).
func _ft_calls(box: VBoxContainer, me: int) -> void:
	var c := MatchStory.calls(_res, me)
	if c.is_empty():
		return
	box.add_child(UiKit.section("Our calls"))
	var note := UiKit.lbl("What each call added to our margin, in points.", UiKit.SMALL, UiKit.MUTED)
	note.name = "CallsStoryNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var grid := GridContainer.new()
	grid.name = "CallsStory"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for r in c["rows"]:
		var pts := int(r["pts"])
		var nm := UiKit.lbl(str(r["name"]), UiKit.BODY, UiKit.TEXT if str(r["kind"]) == "call" else UiKit.MUTED)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nm)
		var fig := UiKit.line("%+d" % pts, UiKit.BODY, UiKit.GOOD if pts > 0 else UiKit.BAD, true)
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(fig)
	var m := int(c["margin"])
	var total := UiKit.lbl("Final margin", UiKit.BODY, UiKit.TEXT, true)
	total.name = "CallsStoryMargin"
	grid.add_child(total)
	var mf := UiKit.line("%+d" % m if m != 0 else "0", UiKit.BODY, UiKit.margin_colour(m > 0) if m != 0 else UiKit.TEXT, true)
	mf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(mf)
	box.add_child(grid)


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
	v.add_child(UiKit.ellipsis(head, UiKit.SECONDARY, VOTES_SUB))

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
	var score_inks := UiKit.club_ink_pair(home, away)
	for side in [0, 1]:
		var row := UiKit.hbox(8)
		row.name = "FinalScore_%d" % side
		# Both clubs read in full text; the winner is bold, the loser plain, and
		# each name carries its club's colour (a red club's is white).
		var nm := UiKit.ellipsis(GameDB.club_name(home if side == 0 else away), UiKit.NAME,
				UiKit.readable_ink(UiKit.club_name_colour(score_inks[side]), UiKit.tinted("sheet", _wash_col())), winner != 1 - side)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var fig := UiKit.figure(UiKit.scoreline(int(_res["goals"][side]), int(_res["behinds"][side])),
				UiKit.SCORE, UiKit.TEXT)
		row.add_child(fig)
		# The same right edge as the votes below: clear of the scrollbar.
		var edge := Control.new()
		edge.name = "ScoreGutter"
		edge.custom_minimum_size.x = VOTES_GUTTER
		row.add_child(edge)
		v.add_child(row)

	# Best players and the coaches' votes, first under the result (director's
	# review 2026-11-04: they were below the fold). Yours first, then their
	# best, each club in its colour with its crest.
	_ft_best_players(v, me, mine, winner)

	# The match story: the hero, the turning point and why.
	var told_above := {}
	if mine:
		told_above = _ft_story(v, me)

	# What it means: finals, the ladder, who is next. (Nothing, for a practice match.)
	if mine and not _is_practice(_res):
		# A clear section gap after the votes, so the ladder lines do not run on.
		v.add_child(UiKit.spacer(UiKit.GAP * 2))
		var outlook := GameState.finals_outcome_line(_res)
		if outlook != "":
			var tag_now := str(_res.get("tag", ""))
			var slots: Dictionary = GameState.season.finals.get("slots", {})
			var through: bool = str(slots.get("W_" + tag_now, "")) == GameState.my_club
			var ol := UiKit.lbl(outlook, 20 if tag_now == "GF" else UiKit.BODY,
					UiKit.EMPH if through else UiKit.MUTED, true)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(ol)
		# A debut is said once, here, in the fuller words ("kicked a goal on
		# debut"); the payoff lines below leave it out (director, 2026-11-06).
		var debut_ids := {}
		if Milestones.shown():
			var ms_texts := []
			for e in Milestones.summary_items(GameState, _res):
				if str(e.get("kind", "")) == "debut" and str(e.get("id", "")) != "":
					debut_ids[str(e["id"])] = true
					var kicked := int(((_res.get("players", {}) as Dictionary).get(str(e["id"]), {}) as Dictionary).get("goals", 0))
					ms_texts.append(Firsts.debut_line(str(e.get("name", "")), kicked))
				else:
					ms_texts.append(str(e.get("text", "")))
			if not ms_texts.is_empty():
				# A heading, then the milestone in plain weight: the ladder and the next game follow it.
				v.add_child(UiKit.section("Milestones"))
				var msl := UiKit.lbl(" ".join(ms_texts), UiKit.BODY, UiKit.TEXT)
				msl.name = "MilestoneLine"
				msl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				v.add_child(msl)
		if (_interactive or _review) and str(_res.get("tag", "")) == "":
			var moved := GameState.ladder_move_line(_pos_before)
			if moved != "":
				var ml := UiKit.lbl(moved, UiKit.BODY, VOTES_SUB)
				ml.name = "LadderMove"
				v.add_child(ml)
			var nxt := GameState.next_fixture_line()
			if nxt != "":
				var nl := UiKit.lbl(nxt, UiKit.NAME, UiKit.TEXT, true)
				nl.name = "NextFixture"
				v.add_child(nl)
		# The people it was about: a debut, a first goal, a promised run done.
		# Said only when the facts kept on the players say it; otherwise silent.
		if _interactive or _review:
			var told := []
			for it in GameState.payoff_items(_res):
				if not (str(it["kind"]) == "debut" and debut_ids.has(str(it["id"]))):
					told.append(str(it["text"]))
			told = told.slice(0, Firsts.MAX_LINES)
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

	# How it went: the few things that decided it, in football words, less
	# what the story above already said (director, 2026-11-06).
	var hiw_gap := UiKit.spacer(UiKit.GAP)
	v.add_child(hiw_gap)
	var hiw_head := UiKit.section("How it went")
	hiw_head.name = "HowItWentHead"
	v.add_child(hiw_head)
	var factors := VBoxContainer.new()
	factors.name = "MatchFactors"
	factors.add_theme_constant_override("separation", 4)
	var shown_factors := MatchNotes.match_factors(_res, me if mine else 0, told_above)
	# What is now said on the screen, for the notes below to leave out.
	var said_now := told_above.duplicate()
	for it in MatchNotes.match_factor_items(_res, me if mine else 0):
		if shown_factors.has(str(it["text"])):
			said_now[str(it["fact"])] = true
	for f in shown_factors:
		var fl := _say(str(f), UiKit.BODY, UiKit.TEXT)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		factors.add_child(fl)
	# The one who got away (P-16): what a former player of yours did against
	# you, when he played most of it or kicked a goal.
	if mine:
		var opp_code := str(_res["away"] if me == 0 else _res["home"])
		var gone := FormerPlayers.report_lines(_res, me, GameState.former_players(opp_code))
		for i in range(gone.size()):
			var gl := NameInk.label(str(gone[i]["text"]), _names(), UiKit.BODY, UiKit.TEXT)
			gl.name = "FormerAgainst_%d" % i
			factors.add_child(gl)
	v.add_child(factors)
	# Everything was said above: no empty heading. The node stays, hidden.
	if factors.get_child_count() == 0:
		hiw_gap.visible = false
		hiw_head.visible = false
		factors.visible = false

	# The coach's side of it: who needs a lift, and what to work on. Only
	# for your match, and only what the result above does not already say.
	if mine and (_res.get("quarter_teams", []) as Array).size() >= 2:
		var g := CoachReport.glance(CoachReport.match_report(_res, me), true)
		_glance_people(v, "Needs a lift", "ReportLift", g["lift"])
		_glance_section(v, "Coaching notes", "ReportNotes",
				CoachReport.notes_not_told(g["notes"], said_now).slice(0, 2))

	if mine:
		# Your synergies: the stat each one shows up in, from this match.
		_glance_section(v, "Your synergies", "FullTimeSynergies", MatchNotes.synergy_lines(_res, me).slice(0, 3), true)

	# Your calls, quarter by quarter: what each was about and how that went.
	if mine and (_interactive or _review):
		var did := MatchNotes.full_time_calls(_res, me, told_above, 5)
		if not did.is_empty():
			_glance_section(v, "Your calls", "FullTimeCalls", did)

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
		# One line per sitting, the first headed "Medical panel:". A cleared
		# player is good news: body ink; a career ended is the injury red.
		var panel := GameState.my_medical_rows()
		for i in range(panel.size()):
			var ok := bool(panel[i]["cleared"])
			var md := UiKit.lbl(("Medical panel: " if i == 0 else "") + str(panel[i]["text"]),
					UiKit.BODY, UiKit.TEXT if ok else UiKit.BAD, not ok)
			md.name = "YourMedical_%d" % i
			md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			week.add_child(md)
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


## The votes lists at the break and at full time are one piece: a club's
## crest (and its name, at the break), then every player the coaches voted for,
## best-voted first, each a white name with his votes on the same baseline at
## the right, and his two best numbers under it. One line over both clubs says
## what the votes are (_votes_header). Club colour is the bar and the crest
## only, so a name can never pass for a button.
const VOTES_BAR_W := 5.0        # the club's bar down its block
const VOTES_MARKER := 44.0      # the crest's height: about 32 px wide
const VOTES_SUB := Color("cfcabe")   # the stat line under a name: a step dimmer than the name
const VOTES_GUTTER := 8.0       # plus the row's 8 gap: 16 clear of the scrollbar and the card's edge; the score lines use it too
const VOTES_STEP := 12          # one spacing step between blocks and rows


## One club's block: its crest (and name when `named`), then its voted players.
func _votes_side(code: String, ink: Color, players: Array, votes: Dictionary, pc := false, named := true) -> Control:
	var side_box := UiKit.vbox(4 if pc else VOTES_STEP)
	var rows_box := UiKit.vbox(BEST_ROW_GAP_PC if pc else VOTES_STEP)
	var sh := UiKit.club_heading(code, null, UiKit.BODY if pc else UiKit.NAME, 22.0 if pc else VOTES_MARKER, ink, false, named)
	side_box.add_child(sh)
	var shown := 0
	for p in players:
		shown += 1
		var row := UiKit.vbox(0)
		row.name = "BestRow_%s" % str(p["id"])
		if pc and shown == 3:
			row.set_meta("best_third", true)
		# Name and votes share one line, bottom-aligned so their baselines meet.
		var top := UiKit.hbox(8)
		var pn := UiKit.lbl(str(p["name"]), UiKit.BODY if pc else UiKit.NAME, UiKit.TEXT, true)
		pn.name = "StandoutName"
		pn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pn.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(pn)
		var fig := _votes_figure(votes, str(p["id"]))
		fig.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(fig)
		var gap := Control.new()
		gap.name = "VotesGutter"
		gap.custom_minimum_size.x = VOTES_GUTTER
		top.add_child(gap)
		row.add_child(top)
		# The line sits on the sheet's wash (the opponent's colour) and near its
		# club's bar; lift it only as far as 4.5:1 against both needs.
		var sub_ink := UiKit.readable_ink(VOTES_SUB, UiKit.tinted("sheet", ink))
		sub_ink = UiKit.readable_ink(sub_ink, UiKit.tinted("sheet", _wash_col()))
		var sub := UiKit.lbl(str(p["line"]), UiKit.SECONDARY, sub_ink)
		sub.name = "StandoutLine"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(sub)
		rows_box.add_child(row)
	# At full time a club neither coach voted for still has its block, saying so.
	if players.is_empty() and not votes.is_empty():
		var none := UiKit.lbl("No votes", UiKit.BODY, UiKit.MUTED)
		none.name = "NoVotes"
		rows_box.add_child(none)
	side_box.add_child(rows_box)
	return UiKit.club_section_body(code, side_box, ink, VOTES_BAR_W)


## What the votes are, said once over both clubs: who voted, how the list runs.
## Hidden in a season before the coaches voted (2003, EraRules coaches_votes;
## director 2026-11-13: "Hide before 2003"): the best players still show.
func _votes_header() -> Control:
	var l := UiKit.lbl("Coaches' votes: each coach gives his best five 5, 4, 3, 2, 1", UiKit.BODY, UiKit.TEXT)
	l.name = "VotesHeading"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.visible = EraRules.on("coaches_votes")
	return l


## A player's coaches' votes at the right of his row, as the AFL publishes
## them: every player either coach voted for, with his total ("10 votes",
## "1 vote"). Hidden on a row with none (Best so far at a break). Plain text
## colour: club colour says who, not how well.
func _votes_figure(votes: Dictionary, id: String) -> Label:
	var n := int(votes.get(id, 0))
	var l := UiKit.line("%d vote%s" % [n, "" if n == 1 else "s"] if n > 0 else "", UiKit.BODY, UiKit.TEXT, true)
	l.name = "StandoutVotes"
	l.visible = n > 0 and EraRules.on("coaches_votes")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## Best players, from the coaches' votes, as the AFL publishes them (director,
## 2026-11-08: "One ranked list"): every player either coach voted for, from
## both clubs in one list, most votes first (his side's match-rating order
## breaks a tie). Each name is in its club's colour beside its club's bar.
func _ft_best_players(v: VBoxContainer, _me: int, _mine: bool, _winner: int) -> void:
	v.add_child(UiKit.spacer(UiKit.GAP))
	v.add_child(UiKit.section("Best players"))
	v.add_child(_votes_header())
	var best_box := UiKit.vbox(VOTES_STEP)
	best_box.name = "BestPlayers"
	var votes := MatchNotes.coaches_votes(_res)
	var inks := UiKit.club_ink_pair(str(_res["home"]), str(_res["away"]))
	for r in _ranked_votes(votes):
		best_box.add_child(_ranked_row(r, votes, inks[int(r["side"])]))
	v.add_child(best_box)


## Both clubs' voted players in one list: most votes first; a tie keeps each
## side's own order (match rating) and, between sides, the home club first.
func _ranked_votes(votes: Dictionary) -> Array:
	var all := []
	for side in [0, 1]:
		var k := 0
		for p in MatchNotes.standouts_by_votes(_res, side, 99, votes):
			var r: Dictionary = (p as Dictionary).duplicate()
			r["side"] = side
			r["order"] = k
			k += 1
			all.append(r)
	all.sort_custom(func(a, b):
		var va := int(votes.get(str(a["id"]), 0))
		var vb := int(votes.get(str(b["id"]), 0))
		if va != vb:
			return va > vb
		if int(a["order"]) != int(b["order"]):
			return int(a["order"]) < int(b["order"])
		return int(a["side"]) < int(b["side"]))
	return all


## One row of the ranked list: the club's bar, the name in the club's colour
## with the votes at the right, and the player's two best stats under it.
func _ranked_row(p: Dictionary, votes: Dictionary, ink: Color) -> Control:
	var side := int(p["side"])
	var code := str(_res["home"] if side == 0 else _res["away"])
	var row := UiKit.vbox(0)
	row.name = "BestRow_%s" % str(p["id"])
	row.set_meta("side", side)
	var top := UiKit.hbox(8)
	var name_ink := UiKit.readable_ink(UiKit.club_name_colour(ink), UiKit.tinted("sheet", _wash_col()))
	var pn := UiKit.lbl(str(p["name"]), UiKit.NAME, name_ink, true)
	pn.name = "StandoutName"
	pn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pn.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(pn)
	var fig := _votes_figure(votes, str(p["id"]))
	fig.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(fig)
	var gap := Control.new()
	gap.name = "VotesGutter"
	gap.custom_minimum_size.x = VOTES_GUTTER
	top.add_child(gap)
	row.add_child(top)
	var sub_ink := UiKit.readable_ink(VOTES_SUB, UiKit.tinted("sheet", ink))
	sub_ink = UiKit.readable_ink(sub_ink, UiKit.tinted("sheet", _wash_col()))
	var sub := UiKit.lbl("%s  ·  %s" % [GameDB.club_short(code), str(p["line"])], UiKit.SECONDARY, sub_ink)
	sub.name = "StandoutLine"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(sub)
	var wrap := UiKit.club_section_body(code, row, ink, VOTES_BAR_W)
	wrap.name = "BestRank_%s" % str(p["id"])
	return wrap


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


## A PC (landscape, roomy) shows the score and the team numbers side by side on one
## page, so nothing needs scrolling to reach the stats (director, 2026-10-14: "having to
## scroll down to see the stats part is bad"); a phone stacks them and scrolls.
func _stats_wide() -> bool:
	return ScreenLayout.roomy(UiKit.view_width(self), UiKit.view_height(self))


## The sheet on a PC grows with the screen (the canvas the player's window gives, which
## ScreenLayout sizes: a 2560x1440 window is a 1280x720 canvas at twice the pixels), up
## to its margins.
const SHEET_MAX_W := 4096.0
## The three columns of a PC stats page: the score (box score), the team numbers and, at
## full time, what the calls did. Each keeps its own width and shares what is left.
const COL_SCORE_W := 400.0
const COL_CALLS_W := 270.0
const SCORE_SHARE := 1.0
const TEAM_SHARE := 1.4
const CALLS_SHARE := 0.9


func _stats_page(host: VBoxContainer, live: bool, players_first: bool, calls: Control = null) -> BoxScore:
	var bs := BoxScore.new()
	var msv := MatchStatsView.new()
	msv.players_first = players_first
	if _stats_wide():
		bs.compact = true
		msv.compact = true
		var cols := UiKit.hbox(20)
		cols.name = "StatsColumns"
		var gaps := 20.0 * (2.0 if calls != null else 1.0)
		var room := UiKit.view_width(self) - 24.0 - 40.0 - gaps
		var shares := SCORE_SHARE + TEAM_SHARE + (CALLS_SHARE if calls != null else 0.0)
		# The width the team numbers will have: how many groups sit across, and how wide each is.
		msv.room = room * TEAM_SHARE / shares
		bs.custom_minimum_size.x = COL_SCORE_W if calls != null else 460.0
		bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bs.size_flags_stretch_ratio = SCORE_SHARE
		bs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		msv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msv.size_flags_stretch_ratio = TEAM_SHARE
		msv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cols.add_child(bs.setup(_res, live))
		cols.add_child(msv.setup(_res, _my_side, live))
		if calls != null:
			calls.custom_minimum_size.x = COL_CALLS_W
			calls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			calls.size_flags_stretch_ratio = CALLS_SHARE
			calls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			cols.add_child(calls)
		host.add_child(cols)
	else:
		host.add_child(bs.setup(_res, live))
		host.add_child(UiKit.spacer(UiKit.GAP))
		host.add_child(msv.setup(_res, _my_side, live))
		if calls != null:
			host.add_child(UiKit.spacer(UiKit.GAP))
			host.add_child(calls)
	return bs


## The Stats tab: the box score (BoxScore), then team and player stats a tab apart
## (MatchStatsView, the same view as at the breaks), and what your calls did - on a
## PC a third column beside them, so the whole page shows at once.
func _ft_stats(v: VBoxContainer) -> void:
	var box := UiKit.vbox(8)
	box.name = "MatchStats"
	v.add_child(box)
	_stats_page(box, false, false, _calls_view(0) if _interactive else null)


func _qcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Router back hook. A live match cannot be abandoned half way (the rest of
## the round is already on the ladder), so back is swallowed until full time.
func handle_back() -> bool:
	# The bench's drawer on the oval shuts first.
	if _pitch != null and _pitch.close_bench():
		return true
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
	# The scoreboard is made again for the new width, in its new place.
	if _board != null and is_instance_valid(_board):
		if _board.get_parent() != null:
			_board.get_parent().remove_child(_board)
		_board.queue_free()
	if stack != _stacked or (not stack and _wide_break()) != _pc:
		_pitch.get_parent().remove_child(_pitch)
		_side_panel.get_parent().remove_child(_side_panel)
		_root.remove_child(_body)
		_body.queue_free()
		_mount_body(stack)
		_root.add_child(_body)
	else:
		_orient_pitch(stack)
		_fit_side_panel()
	_board = _scoreboard()
	_place_board()
	_paint_scoreboard()
	_paint_live_stats()
	_fit_docked.call_deferred()



## Injuries and the odd turning point in the feed (MatchNotes.story_feed_line).
func _story_feed(ev: Dictionary) -> void:
	var text := MatchNotes.story_feed_line(_duel_mem, ev)
	if text != "":
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), text],
				UiKit.TEXT, false, "StoryLine")


## A career best for one of yours, in bold so a once-in-a-career moment is
## not lost among routine lines (MatchNotes.career_high_lines). True when a
## line was added.
func _career_high_feed(ev: Dictionary) -> bool:
	var sim = GameState.pending_sim
	var extra := int(ev.get("q", 1)) == 4 and (bool(_res.get("extra_time", false))
			or (_interactive and sim != null and sim.needs_extra_time()))
	var lines := MatchNotes.career_high_lines(_duel_mem, ev, _res, extra)
	for text in lines:
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), str(text)],
				UiKit.TEXT, true, "CareerHighLine")
	return not lines.is_empty()


## The High Press taking hold, once a side a match: the first time the
## side whose plan it is defends after setting it (V2, press pilot).
func _press_feed(event_index: int, ev: Dictionary) -> void:
	var presser := MatchNotes.press_trigger(_res.get("timeline", []), event_index, ev, _press_said)
	if presser < 0:
		return
	_press_said[presser] = true
	var code := str(_res["home"] if presser == 0 else _res["away"])
	_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), MatchNotes.press_line(code)],
			UiKit.TEXT, false, "PressLine")


## A side's game plan starting, carrying on over a break or ending, and a short
## call running out (P-12, MatchNotes.call_lines). A break's line comes after
## the break's own score line. A plan dropped at the break is said at the
## next bounce, once the break's calls are made, without the new quarter's clock.
func _call_feed(event_index: int, ev: Dictionary) -> void:
	var lines := MatchNotes.call_lines(_res.get("timeline", []), event_index, ev, _call_mem,
			str(_res["home"]), str(_res["away"]))
	var unstamped := int(_call_mem.get("break_lines", 0))
	for i in range(lines.size()):
		var stamp := "" if i < unstamped else "%s  " % _clock_text(int(ev.get("q", 1)), int(ev.get("min", 0)))
		_feed_text(stamp + str(lines[i]), UiKit.TEXT, false, "CallLine")


## The battle in the feed, rarely (MatchNotes.duel_feed_line).
func _duel_feed(ev: Dictionary) -> void:
	var text := MatchNotes.duel_feed_line(_duel_mem, ev)
	if text != "":
		_feed_text("%s  %s" % [_clock_text(int(ev.get("q", 1)), int(ev.get("min", 0))), text],
				UiKit.TEXT, false, "DuelLine")
