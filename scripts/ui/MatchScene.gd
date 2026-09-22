extends Control
## Live match view: scoreboard, the animated oval, a commentary feed and
## playback controls. The match is already simulated by the time we get here -
## GameState.advance() ran it - so this scene only replays the event log.

const FEED_LIMIT := 60
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
## Routine disposals drive the animation but would drown the commentary.
const QUIET_KINDS := ["kick", "handball"]

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
var _event_cursor := 0
var _my_side := 0

var _margin: MarginContainer
var _stacked := false
var _last_tactics := {}
var _skipping := false
var _fulltime_shown := false
var _coach_overlay: Control
var _reflow_queued := false
var _shown_goals := [0, 0]
var _shown_behinds := [0, 0]
var _shown_q := 1
var _shown_min := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_interactive = GameState.pending_sim != null and not GameState.pending_match.is_empty()
	if _interactive:
		_res = GameState.pending_sim.result()
		_res["home"] = GameState.pending_match["home"]
		_res["away"] = GameState.pending_match["away"]
		_res["label"] = GameState.pending_match["label"]
		_res["events"] = []
		_my_side = 0 if str(_res["home"]) == GameState.my_club else 1
	else:
		_res = GameState.last_match
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
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_stretch_ratio = 1.5
	_body.add_child(_pitch)

	if _side_panel == null:
		_side_panel = UiKit.panel(UiKit.PANEL, 10)
		var sv := UiKit.vbox(6)
		_side_panel.add_child(sv)
		sv.add_child(UiKit.lbl("Commentary", 15, UiKit.GOLD, true))
		_feed = UiKit.vbox(3)
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
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	h.add_child(_score_column(str(_res["home"]), true, narrow))
	h.add_child(_score_middle(narrow))
	h.add_child(_score_column(str(_res["away"]), false, narrow))
	return p


func _score_column(code: String, home: bool, narrow: bool) -> Control:
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_text := GameDB.club_short(code) if narrow else GameDB.club_name(code)
	var name := UiKit.ellipsis(name_text, 13 if narrow else 16, UiKit.TEXT, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home \
			else HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var cols: Array = GameDB.club_colours(code)
	var score := UiKit.line("0.0 (0)", 16 if narrow else 26, cols[2], true)
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


func _score_middle(narrow: bool) -> Control:
	var mid := UiKit.vbox(0)
	mid.custom_minimum_size = Vector2(52 if narrow else 112, 0)
	var label := UiKit.ellipsis(str(_res.get("label", "Match")), 11, UiKit.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(label)
	_clock = UiKit.line("Q%d %d'" % [_shown_q, _shown_min], 15 if narrow else 20, UiKit.TEXT, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_clock)
	var venue := UiKit.ellipsis(str(GameDB.club(str(_res["home"])).get("ground", "")),
			11, UiKit.MUTED)
	venue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(venue)
	return mid


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

	var leave := UiKit.btn("Back to Hub", 13)
	leave.custom_minimum_size = Vector2(0, 40)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.disabled = _interactive
	leave.pressed.connect(func(): Router.back())
	row2.add_child(leave)

	_sync_controls()
	return v


func _sync_controls() -> void:
	if _play_btn == null:
		return
	_play_btn.text = "Play" if not _pitch.playing else "Pause"
	for i in range(SPEEDS.size()):
		var b: Button = _speed_btns[i]
		var on := is_equal_approx(_pitch.speed, SPEEDS[i])
		b.modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.45)


func _on_toggle() -> void:
	_pitch.toggle()
	_sync_controls()


func _on_speed(s: float) -> void:
	_pitch.set_speed(s)
	_sync_controls()


func _on_skip() -> void:
	_skipping = true
	_close_coach()
	if _interactive and GameState.pending_sim != null:
		_simulate_remaining()
	if _pitch != null:
		_pitch.skip_to_end()


func _close_coach() -> void:
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
	var t := _last_tactics
	if t.is_empty():
		t = {"gameplan": "balanced", "focus_id": "", "tag_id": "", "pep": "steady"}
	while sim.current_quarter <= 4:
		_apply_quarter_tactics(t)
		_res = sim.run_quarter()
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


func _show_coach_box() -> void:
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	_pitch.pause()
	_sync_controls()
	var box := UiKit.modal_box(self, 620.0, 640.0)
	var overlay: Control = box["overlay"]
	_coach_overlay = overlay
	var v: VBoxContainer = box["body"]
	var q := GameState.pending_sim.current_quarter
	v.add_child(UiKit.ellipsis("Coach Box - Quarter %d" % q, 22, UiKit.GOLD, true))
	v.add_child(UiKit.lbl("Set the plan before this quarter is simulated. The opposition has not been rolled yet.",
			13, UiKit.MUTED))

	var plan := OptionButton.new()
	for i in range(GAMEPLANS.size()):
		plan.add_item(str(GAMEPLANS[i][1]), i)
	v.add_child(_field("Gameplan", plan))

	var focus := OptionButton.new()
	focus.add_item("No specific player", 0)
	var mine := _roster_side(_my_side)
	for i in range(mine.size()):
		var r: Dictionary = mine[i]
		focus.add_item("%s #%d" % [GameDB.player_display_name_by_id(str(r.get("id", "")), str(r.get("name", "Player"))), int(r["num"])], i + 1)
	v.add_child(_field("Run play through", focus))

	var tag := OptionButton.new()
	tag.add_item("No tag", 0)
	var opp := _roster_side(1 - _my_side)
	for i in range(opp.size()):
		var r2: Dictionary = opp[i]
		tag.add_item("%s #%d" % [GameDB.player_display_name_by_id(str(r2.get("id", "")), str(r2.get("name", "Player"))), int(r2["num"])], i + 1)
	v.add_child(_field("Tag opponent", tag))

	var pep := OptionButton.new()
	for i in range(PEP_TALKS.size()):
		pep.add_item(str(PEP_TALKS[i][1]), i)
	v.add_child(_field("Pep talk", pep))

	var start := UiKit.btn("Start Quarter", 18, true)
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func():
		var focus_id := ""
		if focus.selected > 0:
			focus_id = str(mine[focus.selected - 1]["id"])
		var tag_id := ""
		if tag.selected > 0:
			tag_id = str(opp[tag.selected - 1]["id"])
		var t := {
			"gameplan": str(GAMEPLANS[plan.selected][0]),
			"focus_id": focus_id,
			"tag_id": tag_id,
			"pep": str(PEP_TALKS[pep.selected][0]),
		}
		_close_coach()
		_simulate_next_quarter(t))
	box["footer"].add_child(start)
	var skip := UiKit.btn("Skip to full time", 15)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(_on_skip)
	box["footer"].add_child(skip)


func _field(label: String, control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UiKit.view_width(self) < 560.0:
		var v := UiKit.vbox(4)
		v.add_child(UiKit.lbl(label, 13, UiKit.MUTED, true))
		v.add_child(control)
		return v
	var h := UiKit.hbox(8)
	var l := UiKit.lbl(label, 13, UiKit.MUTED, true)
	l.custom_minimum_size = Vector2(132, 0)
	h.add_child(l)
	h.add_child(control)
	return h


func _roster_side(side: int) -> Array:
	var roster: Array = _res.get("roster", [[], []])
	if roster.size() <= side:
		return []
	var out: Array = roster[side].duplicate()
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return out


func _simulate_next_quarter(t: Dictionary) -> void:
	_last_tactics = t.duplicate()
	_apply_quarter_tactics(t)
	_res = GameState.pending_sim.run_quarter()
	_stamp_match_meta()
	_append_new_events()
	_pitch.play()
	_sync_controls()


func _apply_quarter_tactics(t: Dictionary) -> void:
	GameState.pending_sim.set_tactics(_my_side, t)
	# Basic AI counter-plan: leaders protect a lead, trailers take more risk.
	var s: Array = GameState.pending_sim.result()["score"]
	var opp_plan := "balanced"
	if int(s[1 - _my_side]) > int(s[_my_side]) + 18:
		opp_plan = "controlled"
	elif int(s[1 - _my_side]) + 18 < int(s[_my_side]):
		opp_plan = "attacking"
	GameState.pending_sim.set_tactics(1 - _my_side, {"gameplan": opp_plan, "pep": "steady"})


func _stamp_match_meta() -> void:
	_res["home"] = GameState.pending_match["home"]
	_res["away"] = GameState.pending_match["away"]
	_res["label"] = GameState.pending_match["label"]


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
	_feed_add(ev)


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
		_clock.text = "Q%d %d'" % [_shown_q, _shown_min]


func _feed_add(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if QUIET_KINDS.has(kind):
		return
	var col := UiKit.TEXT
	match kind:
		"goal": col = UiKit.GOLD
		"behind": col = Color(0.72, 0.82, 0.95)
		"tackle": col = Color(0.80, 0.72, 0.95)
		"clanger", "free": col = Color(0.95, 0.70, 0.62)
		"inside50": col = Color(0.66, 0.90, 0.70)
		"quarter", "final": col = UiKit.GOOD
		"mark": col = Color(0.85, 0.90, 0.95)
		_: col = UiKit.MUTED

	var text := str(ev.get("text", ""))
	var stamp := "Q%d %2d'" % [int(ev.get("q", 1)), int(ev.get("min", 0))]
	var l := UiKit.lbl("%s  %s" % [stamp, text], 12, col,
			kind == "goal" or kind == "quarter" or kind == "final")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)
	while _feed.get_child_count() > FEED_LIMIT:
		var first := _feed.get_child(0)
		_feed.remove_child(first)
		first.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_feed_scroll):
		_feed_scroll.scroll_vertical = int(_feed_scroll.get_v_scroll_bar().max_value)


func _on_finished() -> void:
	if _fulltime_shown:
		return
	# Skip sims the rest of the match first, then drains the pitch. Without
	# this flag the quarter-end signal reopens the coach box.
	if _interactive and not _skipping and GameState.pending_sim != null \
			and GameState.pending_sim.current_quarter <= 4:
		_sync_controls()
		_show_coach_box()
		return
	_skipping = false
	_finished = true
	_fulltime_shown = true
	_close_coach()
	if _res.has("goals") and _res.has("behinds"):
		_update_scoreboard({
			"q": 4, "min": 20, "kind": "final",
			"goals": _res["goals"], "behinds": _res["behinds"],
		})
	if _interactive:
		GameState.finish_interactive_match(_res)
	_sync_controls()
	_show_fulltime()


# ---------------------------------------------------------------------------
# Full time
# ---------------------------------------------------------------------------
func _show_fulltime() -> void:
	var box := UiKit.modal_box(self, 860.0, 0.0)
	var overlay: Control = box["overlay"]
	var v: VBoxContainer = box["body"]

	var s: Array = _res["score"]
	var home: String = _res["home"]
	var away: String = _res["away"]
	var i_am_home: bool = home == GameState.my_club
	var my_score: int = int(s[0]) if i_am_home else int(s[1])
	var opp_score: int = int(s[1]) if i_am_home else int(s[0])
	var drew: bool = my_score == opp_score
	var won: bool = my_score > opp_score

	var tag := str(_res.get("label", "Match"))
	v.add_child(UiKit.ellipsis("Full Time - %s" % tag, 15, UiKit.MUTED))

	var hs := UiKit.scoreline(int(_res["goals"][0]), int(_res["behinds"][0]))
	var ascore := UiKit.scoreline(int(_res["goals"][1]), int(_res["behinds"][1]))
	var verb := "drew with"
	if int(s[0]) > int(s[1]):
		verb = "defeated"
	elif int(s[1]) > int(s[0]):
		verb = "lost to"
	v.add_child(UiKit.lbl("%s %s  %s  %s %s" % [
			GameDB.club_name(str(home)), hs, verb,
			GameDB.club_name(str(away)), ascore], 18, UiKit.TEXT, true))

	if GameState.my_club != "":
		var verdict := "DRAW" if drew else ("WIN by %d" % absi(my_score - opp_score) \
				if won else "LOSS by %d" % absi(my_score - opp_score))
		v.add_child(UiKit.lbl(verdict, 24,
				UiKit.MUTED if drew else UiKit.margin_colour(won), true))

	var narrow := UiKit.view_width(self) < 720.0
	var body: BoxContainer
	if narrow:
		body = UiKit.vbox(14)
	else:
		body = UiKit.hbox(16)
	v.add_child(body)

	var left := UiKit.vbox(5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(UiKit.lbl("Quarter by Quarter", 14, UiKit.GOLD, true))
	left.add_child(_quarters_table())
	left.add_child(UiKit.spacer(6))
	left.add_child(UiKit.lbl("Team Stats", 14, UiKit.GOLD, true))
	left.add_child(_team_stats_table())

	var right := UiKit.vbox(5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(UiKit.lbl("Best On Ground", 14, UiKit.GOLD, true))
	right.add_child(_best_table())

	var report: Dictionary = GameState.last_training_report
	if int(report.get("count", 0)) > 0 and str(report.get("home", "")) == str(_res.get("home", "")) \
			and str(report.get("away", "")) == str(_res.get("away", "")):
		v.add_child(UiKit.lbl("%d players gained %d XP. Spend it on any stat in Training." % [
				int(report["count"]), int(report["total"])], 14, UiKit.TEXT, true))
	var cont := UiKit.btn("Training", 18, true)
	cont.custom_minimum_size = Vector2(0, 48)
	cont.pressed.connect(func():
		overlay.queue_free()
		Router.replace("training"))
	box["footer"].add_child(cont)
	var leave := UiKit.btn("Back to Hub", 16)
	leave.custom_minimum_size = Vector2(0, 44)
	leave.pressed.connect(func(): Router.back())
	box["footer"].add_child(leave)


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
	for i in range(4):
		qh.add_child(_qcell("Q%d" % (i + 1), 48, UiKit.MUTED, 12))
	qh.add_child(_qcell("Final", 96, UiKit.MUTED, 12))
	for side in range(2):
		var code: String = home if side == 0 else away
		var qr := UiKit.hbox(4)
		v.add_child(qr)
		qr.add_child(UiKit.club_badge(code, 12, true, false))
		for i in range(4):
			qr.add_child(_qcell("%d.%d" % [int(qg[i][side]), int(qb[i][side])],
					48, UiKit.TEXT, 12))
		qr.add_child(_qcell(UiKit.scoreline(int(_res["goals"][side]),
				int(_res["behinds"][side])), 96, UiKit.GOLD, 13, true))
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
				int(_res["behinds"][side])), 15, UiKit.GOLD, true))
		block.add_child(head)
		var parts: PackedStringArray = []
		for i in range(4):
			parts.append("Q%d %d.%d" % [i + 1, int(qg[i][side]), int(qb[i][side])])
		block.add_child(UiKit.ellipsis("   ".join(parts), 12, UiKit.MUTED))
		v.add_child(block)
	return v


func _qcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


const TEAM_STAT_ROWS := [
	["disposals", "Disposals"], ["kicks", "Kicks"], ["handballs", "Handballs"],
	["marks", "Marks"], ["tackles", "Tackles"], ["inside50", "Inside 50s"],
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
	for row in TEAM_STAT_ROWS:
		var h := UiKit.hbox(4)
		v.add_child(h)
		var a := int(float(t[0].get(row[0], 0.0)))
		var b := int(float(t[1].get(row[0], 0.0)))
		h.add_child(_qcell(str(a), 44, UiKit.GOOD if a > b else UiKit.TEXT, 12))
		var lab := UiKit.ellipsis(str(row[1]), 12, UiKit.MUTED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(lab)
		h.add_child(_qcell(str(b), 44, UiKit.GOOD if b > a else UiKit.TEXT, 12))
	return v


func _best_table() -> Control:
	var v := UiKit.vbox(2)
	var roster: Array = _res.get("roster", [[], []])
	var players: Dictionary = _res.get("players", {})
	var codes := [str(_res["home"]), str(_res["away"])]
	for side in range(2):
		if side == 1:
			v.add_child(UiKit.spacer(10))
		v.add_child(UiKit.club_badge(codes[side], 13, true, true))
		var hdr := UiKit.hbox(4)
		v.add_child(hdr)
		hdr.add_child(_qcell("#", 26, UiKit.MUTED, 10))
		hdr.add_child(_lcell("Player", 0, UiKit.MUTED, 10))
		for c in ["D", "G", "M", "T", "HO"]:
			hdr.add_child(_qcell(c, 28, UiKit.MUTED, 10))
		var best := _rank_side(roster[side], players)
		for i in range(mini(7, best.size())):
			var p: Dictionary = best[i]
			var st: Dictionary = p["stats"]
			var row := UiKit.hbox(4)
			v.add_child(row)
			var col := UiKit.GOLD if i == 0 else UiKit.TEXT
			row.add_child(_qcell(str(int(p["num"])), 26, col, 12))
			row.add_child(_lcell(str(p.get("name", "Player")), 0, col, 12, i == 0))
			row.add_child(_qcell(str(int(st.get("disposals", 0))), 28, col, 12))
			row.add_child(_qcell(str(int(st.get("goals", 0))), 28, col, 12))
			row.add_child(_qcell(str(int(st.get("marks", 0))), 28, col, 12))
			row.add_child(_qcell(str(int(st.get("tackles", 0))), 28, col, 12))
			row.add_child(_qcell(str(int(st.get("hitouts", 0))), 28, col, 12))
	return v


func _lcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.ellipsis(text, fs, col, bold)
	if w > 0:
		l.custom_minimum_size = Vector2(w, 0)
	return l


func _rank_side(list: Array, players: Dictionary) -> Array:
	var out := []
	for p in list:
		var st: Dictionary = players.get(str(p["id"]), {})
		out.append({"num": int(p["num"]),
				"name": GameDB.player_display_name_by_id(str(p.get("id", "")), str(p.get("name", "Player"))),
				"stats": st, "inf": _influence(st)})
	out.sort_custom(func(a, b): return a["inf"] > b["inf"])
	return out


## Rough best-on-ground measure: weight goals and inside 50s above raw touches.
func _influence(st: Dictionary) -> float:
	return float(st.get("disposals", 0.0)) \
			+ float(st.get("goals", 0.0)) * 5.0 \
			+ float(st.get("marks", 0.0)) * 0.8 \
			+ float(st.get("inside50", 0.0)) * 2.0 \
			+ float(st.get("tackles", 0.0)) * 0.8 \
			+ float(st.get("hitouts", 0.0)) * 0.7 \
			+ float(st.get("clearances", 0.0)) * 1.2 \
			+ float(st.get("one_percenters", 0.0)) * 0.6 \
			- float(st.get("clangers", 0.0)) * 2.0


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
