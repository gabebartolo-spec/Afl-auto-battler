extends Control
## Live match view: scoreboard, the animated oval, a commentary feed and
## playback controls. Your own match (home-and-away or final) is simulated a
## quarter at a time around the coach box; any other result is a replay of
## the event log GameState.advance() recorded.

const FEED_LIMIT := 60
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
## Routine disposals drive the animation but would drown the commentary.
const QUIET_KINDS := ["kick", "handball", "sub", "ballup"]

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
var _half_time_report := {}
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
var _moment_overlay: Control
var _momentum := 0.0            # -1 (away on top) .. 1 (home on top)
var _mom_home: ColorRect
var _mom_away: ColorRect
var _rotation := "normal"


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
	else:
		_res = GameState.last_match
		if not _res.is_empty() and GameState.my_club != "":
			_my_side = 0 if str(_res.get("home", "")) == GameState.my_club else 1
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


## Who has the run of play: a bar that swings to the side kicking the goals
## and pumping it inside 50, and drifts back to even when nothing happens.
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
	_mom_home.size_flags_stretch_ratio = 1.0 + _momentum
	_mom_away.size_flags_stretch_ratio = 1.0 - _momentum


func _track_momentum(ev: Dictionary) -> void:
	# A ball-up is staging for the oval, not a play: it must not age the meter
	# (the log carries ~57 a match).
	if str(ev.get("kind", "")) == "ballup":
		return
	var side := int(ev.get("side", -1))
	var sign := 1.0 if side == 0 else -1.0
	_momentum *= 0.985
	match str(ev.get("kind", "")):
		"goal":
			_momentum += 0.30 * sign
		"behind":
			_momentum += 0.10 * sign
		"inside50":
			_momentum += 0.05 * sign
		"quarter":
			_momentum *= 0.5
	_momentum = clampf(_momentum, -0.9, 0.9)
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
	# A final names its venue (the Grand Final is always at the MCG); any
	# other match is at the home club's ground.
	var ground := str(_res.get("venue", ""))
	if ground == "":
		ground = str(GameDB.club(str(_res["home"])).get("ground", ""))
	var venue := UiKit.ellipsis(ground, 11, UiKit.MUTED)
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
	_close_moment()
	if _interactive and GameState.pending_sim != null:
		_simulate_remaining()
	if _pitch != null:
		_pitch.skip_to_end()


func _close_moment() -> void:
	if _moment_overlay != null and is_instance_valid(_moment_overlay):
		_moment_overlay.queue_free()
	_moment_overlay = null


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
	# A quarter paused on a moment finishes first; the moment takes the
	# default call.
	if sim.quarter_in_progress():
		_res = sim.run_quarter()
		_stamp_match_meta()
	var t := _last_tactics
	if t.is_empty():
		t = {"gameplan": "balanced", "focus_id": "", "tag_id": "", "pep": "steady"}
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


func _show_coach_box() -> void:
	if _coach_overlay != null and is_instance_valid(_coach_overlay):
		return
	_pitch.pause()
	_sync_controls()
	var sim: MatchSim = GameState.pending_sim
	var q := sim.current_quarter
	var is_half_time := q == 3
	var box := UiKit.modal_box(self, 860.0 if is_half_time else 640.0, 0.0 if is_half_time else 680.0)
	var overlay: Control = box["overlay"]
	overlay.name = "CoachBox"
	_coach_overlay = overlay
	var v: VBoxContainer = box["body"]
	if q > 1:
		v.add_child(_calls_view(q - 1))
	if is_half_time:
		v.add_child(UiKit.ellipsis("Half Time - Assistant Coach Report", 22, UiKit.GOLD, true))
		var report := CoachReport.half_time_report(_res, _my_side)
		_half_time_report = report
		v.add_child(_half_time_report_view(report))
		v.add_child(UiKit.spacer(10))
		v.add_child(UiKit.ellipsis("Coach Box - Quarter 3", 20, UiKit.GOLD, true))
		_feed_note("Assistant report delivered - see the Coach Box.")
	else:
		v.add_child(UiKit.ellipsis("Coach Box - Quarter %d" % q, 22, UiKit.GOLD, true))
		if q == 4 and not _half_time_report.is_empty():
			var review := UiKit.btn("Review half-time report", 14)
			review.pressed.connect(func(): _show_half_time_popup(_half_time_report))
			v.add_child(review)
	var syn_line := _synergy_line()
	if syn_line != "":
		var sl := UiKit.lbl(syn_line, 12, UiKit.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	var opp_last := _opp_last_plan()
	if opp_last != "":
		v.add_child(UiKit.lbl("They played %s last quarter." % CoachReport.plan_label(opp_last),
				13, UiKit.TEXT, true))
	var my_last := str(_last_tactics.get("gameplan", ""))
	if q >= 2 and my_last != "" and my_last != "balanced" and MatchSim.counter_to(my_last) != "":
		v.add_child(UiKit.lbl("Run %s again and they may read it: its counter is %s." % [
				CoachReport.plan_label(my_last), CoachReport.plan_label(MatchSim.counter_to(my_last))],
				12, UiKit.MUTED))

	var plan := OptionButton.new()
	plan.name = "PlanPicker"
	for i in range(GAMEPLANS.size()):
		plan.add_item(str(GAMEPLANS[i][1]), i)
		if str(GAMEPLANS[i][0]) == my_last:
			plan.select(i)
	v.add_child(_field("Gameplan", plan))
	var plan_note := UiKit.lbl("", 12, UiKit.MUTED)
	plan_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(plan_note)
	var sync_note := func(idx: int) -> void:
		plan_note.text = CoachReport.plan_effect(str(GAMEPLANS[idx][0]))
	sync_note.call(plan.selected)
	plan.item_selected.connect(sync_note)

	var focus := OptionButton.new()
	focus.add_item("No specific player", 0)
	var mine := _roster_side(_my_side)
	for i in range(mine.size()):
		var r: Dictionary = mine[i]
		focus.add_item("%s #%d" % [GameDB.player_display_name_by_id(str(r.get("id", "")), str(r.get("name", "Player"))), int(r["num"])], i + 1)
		if str(r["id"]) == str(_last_tactics.get("focus_id", "")):
			focus.select(i + 1)
	v.add_child(_field("Run play through", focus))

	var tag := OptionButton.new()
	tag.add_item("No tag", 0)
	var opp := _roster_side(1 - _my_side)
	var cur_tag := str((sim.tactics[_my_side] as Dictionary).get("tag_id", _last_tactics.get("tag_id", "")))
	for i in range(opp.size()):
		var r2: Dictionary = opp[i]
		tag.add_item("%s #%d" % [GameDB.player_display_name_by_id(str(r2.get("id", "")), str(r2.get("name", "Player"))), int(r2["num"])], i + 1)
		if str(r2["id"]) == cur_tag:
			tag.select(i + 1)
	v.add_child(_field("Tag opponent", tag))

	var pep := OptionButton.new()
	pep.name = "PepPicker"
	for i in range(PEP_TALKS.size()):
		pep.add_item(str(PEP_TALKS[i][1]), i)
	v.add_child(_field("Pep talk", pep))
	var pep_note := UiKit.lbl("", 12, UiKit.MUTED)
	pep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pep_note)
	var sync_pep := func(idx: int) -> void:
		pep_note.text = CoachReport.pep_effect(str(PEP_TALKS[idx][0]))
	sync_pep.call(pep.selected)
	pep.item_selected.connect(sync_pep)

	var rot := OptionButton.new()
	rot.name = "RotationPicker"
	var rot_keys: Array = MatchSim.ROTATION_POLICIES.keys()
	for i in range(rot_keys.size()):
		rot.add_item(str(MatchSim.ROTATION_POLICIES[rot_keys[i]]["label"]), i)
		if str(rot_keys[i]) == _rotation:
			rot.select(i)
	v.add_child(_field("Rotations", rot))
	var rot_note := UiKit.lbl("", 12, UiKit.MUTED)
	rot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rot_note)
	var sync_rot := func(idx: int) -> void:
		rot_note.text = str(MatchSim.ROTATION_POLICIES[rot_keys[idx]]["text"])
	sync_rot.call(rot.selected)
	rot.item_selected.connect(sync_rot)
	v.add_child(_legs_view())

	var start := UiKit.btn("Start Quarter", 18, true)
	start.name = "StartQuarter"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func():
		var focus_id := ""
		if focus.selected > 0:
			focus_id = str(mine[focus.selected - 1]["id"])
		var tag_id := ""
		if tag.selected > 0:
			tag_id = str(opp[tag.selected - 1]["id"])
		_rotation = str(rot_keys[rot.selected])
		var t := {
			"gameplan": str(GAMEPLANS[plan.selected][0]),
			"focus_id": focus_id,
			"tag_id": tag_id,
			"pep": str(PEP_TALKS[pep.selected][0]),
			"rotation": _rotation,
		}
		_close_coach()
		_simulate_next_quarter(t))
	box["footer"].add_child(start)
	var skip := UiKit.btn("Skip to full time", 15)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(_on_skip)
	box["footer"].add_child(skip)


func _synergy_line() -> String:
	var syn: Array = GameState.pending_sim.synergies
	var names := func(keys: Array) -> String:
		var out: PackedStringArray = []
		for k in keys:
			out.append(Traits.label(str(k)))
		return ", ".join(out) if not out.is_empty() else "none"
	return "Synergies - yours: %s. Theirs: %s." % [names.call(syn[_my_side]), names.call(syn[1 - _my_side])]


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
	v.add_child(UiKit.lbl("What your calls did" + (" in Q%d" % q if q > 0 else ""), 16, UiKit.GOLD, true))
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
				12, UiKit.GOLD if int(m.get("points", 0)) >= 6 else UiKit.TEXT)
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


## Legs: the five most tired on the ground and the bench's freshness.
func _legs_view() -> Control:
	var v := UiKit.vbox(3)
	v.name = "LegsView"
	var sim: MatchSim = GameState.pending_sim
	v.add_child(UiKit.lbl("Legs  -  your midfield %d%%, theirs %d%%" % [
			int(_group_energy(_my_side)), int(_group_energy(1 - _my_side))], 14, UiKit.GOLD, true))
	var rows: Array = sim.legs(_my_side)
	var shown := 0
	for r in rows:
		if not bool(r["on"]) or shown >= 5:
			continue
		shown += 1
		var row := UiKit.hbox(6)
		var name_l := UiKit.ellipsis("#%d %s" % [int(r["num"]), str(r["name"])], 12, UiKit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(90, 10)
		bar.value = float(r["energy"])
		bar.modulate = UiKit.GOOD if float(r["energy"]) >= 70.0 else (UiKit.GOLD if float(r["energy"]) >= 50.0 else UiKit.BAD)
		row.add_child(bar)
		row.add_child(UiKit.line("%d%%" % int(r["energy"]), 12, UiKit.MUTED))
		v.add_child(row)
	var bench := PackedStringArray()
	for r in rows:
		if not bool(r["on"]):
			bench.append("#%d %d%%" % [int(r["num"]), int(r["energy"])])
	if not bench.is_empty():
		v.add_child(UiKit.ellipsis("Bench: " + ", ".join(bench), 12, UiKit.MUTED))
	v.add_child(UiKit.lbl("Tired players win less ball and kick fewer goals; tired midfields lose the stoppages.", 11, UiKit.MUTED))
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
	var box := UiKit.modal_box(self, 560.0, 0.0)
	_moment_overlay = box["overlay"]
	_moment_overlay.name = "MomentCard"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("COACH'S CALL  -  %s" % _clock_text(int(m.get("q", 1)), int(m.get("min", 0))),
			13, UiKit.MUTED, true))
	var title := UiKit.lbl(str(m.get("title", "")), 20, UiKit.GOLD, true)
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


func _on_moment_choice(i: int) -> void:
	_close_moment()
	var sim: MatchSim = GameState.pending_sim
	if sim == null or sim.pending_moment.is_empty():
		return
	var m := sim.resolve_moment(i)
	var note := UiKit.lbl("%s - %s" % [str(m.get("choice_label", "")), str(m.get("outcome", ""))],
			13, UiKit.GOLD, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(note)
	_advance_segment()


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


# ---------------------------------------------------------------------------
# Half-time assistant coach report
# ---------------------------------------------------------------------------
func _show_half_time_popup(report: Dictionary) -> void:
	var box := UiKit.modal_box(self, 860.0, 0.0)
	var overlay: Control = box["overlay"]
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.ellipsis("Half Time - Assistant Coach Report", 20, UiKit.GOLD, true))
	v.add_child(_half_time_report_view(report))
	var close := UiKit.btn("Close report", 16, true)
	close.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(close)


func _half_time_report_view(report: Dictionary) -> Control:
	var v := UiKit.vbox(8)
	var margin := int(report.get("margin", 0))
	var my_code := str(report.get("my_code", ""))
	var opp_code := str(report.get("opp_code", ""))
	var my_sc := UiKit.scoreline(int(report.get("my_goals", 0)), int(report.get("my_behinds", 0)))
	var opp_sc := UiKit.scoreline(int(report.get("opp_goals", 0)), int(report.get("opp_behinds", 0)))
	var verb := "level"
	if margin > 0:
		verb = "up by %d" % margin
	elif margin < 0:
		verb = "down by %d" % absi(margin)
	v.add_child(UiKit.lbl("Half time: %s %s vs %s %s (%s)" % [
		GameDB.club_name(my_code), my_sc, GameDB.club_name(opp_code), opp_sc, verb],
		15, UiKit.TEXT, true))

	v.add_child(UiKit.lbl("Opposition strategy (Q1-Q2)", 15, UiKit.GOLD, true))
	v.add_child(_report_opp_plans(report))

	v.add_child(UiKit.lbl("Where the game is being won", 15, UiKit.GOLD, true))
	v.add_child(_report_edges_table(report))

	var narrow := UiKit.view_width(self) < 720.0
	var cols: BoxContainer
	if narrow:
		cols = UiKit.vbox(10)
	else:
		cols = UiKit.hbox(12)
	v.add_child(cols)

	var left := UiKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(UiKit.lbl("Your best", 14, UiKit.GOOD, true))
	for e in report.get("my_best", []):
		left.add_child(_report_player_row(e, true))
	left.add_child(UiKit.spacer(4))
	left.add_child(UiKit.lbl("Your quiet ones - need a lift", 14, UiKit.BAD, true))
	for e in report.get("my_worst", []):
		left.add_child(_report_player_row(e, false))

	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UiKit.lbl("Opposition danger", 14, UiKit.GOLD, true))
	for e in report.get("opp_best", []):
		right.add_child(_report_player_row(e, true))
	right.add_child(UiKit.spacer(4))
	right.add_child(UiKit.lbl("Opposition quiet", 14, UiKit.MUTED, true))
	for e in report.get("opp_worst", []):
		right.add_child(_report_player_row(e, false))

	v.add_child(UiKit.lbl("Second-half keys", 15, UiKit.GOLD, true))
	for k in report.get("keys", []):
		v.add_child(UiKit.lbl("- " + str(k), 13, UiKit.TEXT))

	var my_plans: Array = report.get("my_plans", [])
	if not my_plans.is_empty():
		var bits := PackedStringArray()
		for p in my_plans:
			var d: Dictionary = p
			bits.append("Q%d %s" % [int(d.get("quarter", 0)), str(d.get("gameplan_label", "Balanced"))])
		v.add_child(UiKit.lbl("Your first half: " + ", ".join(bits), 12, UiKit.MUTED))
	return v


func _report_opp_plans(report: Dictionary) -> Control:
	var v := UiKit.vbox(4)
	var opp_plans: Array = report.get("opp_plans", [])
	if opp_plans.is_empty():
		v.add_child(UiKit.lbl("No gameplan data recorded for the first half.", 13, UiKit.MUTED))
		return v
	for p in opp_plans:
		var d: Dictionary = p
		v.add_child(UiKit.lbl("Q%d: %s" % [int(d.get("quarter", 0)),
			str(d.get("gameplan_label", "Balanced"))], 14, UiKit.TEXT, true))
		v.add_child(UiKit.lbl(str(d.get("effect", "")), 12, UiKit.MUTED))
		var extras := PackedStringArray()
		if str(d.get("focus_name", "")) != "":
			extras.append("Ran play through %s" % str(d.get("focus_name", "")))
		if str(d.get("tag_name", "")) != "":
			extras.append("Tagged %s" % str(d.get("tag_name", "")))
		var pep := str(d.get("pep", "steady"))
		if pep == "fire_up":
			extras.append("Fired up (+contest, +ball-winning)")
		elif pep != "steady" and pep != "":
			extras.append("Pep: %s" % str(d.get("pep_label", pep)))
		if not extras.is_empty():
			v.add_child(UiKit.lbl("  " + "; ".join(extras), 12, UiKit.TEXT))
	for o in report.get("opp_observed", []):
		v.add_child(UiKit.lbl(str(o), 12, UiKit.MUTED))
	return v


func _report_edges_table(report: Dictionary) -> Control:
	var v := UiKit.vbox(2)
	var edges: Array = report.get("edges", [])
	var h0 := UiKit.hbox(4)
	v.add_child(h0)
	h0.add_child(_qcell(str(report.get("my_code", "US")), 52, UiKit.TEXT, 12, true))
	var gap := UiKit.line("", 12, UiKit.MUTED)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.add_child(gap)
	h0.add_child(_qcell(str(report.get("opp_code", "OPP")), 52, UiKit.TEXT, 12, true))
	for e in edges:
		var d: Dictionary = e
		var h := UiKit.hbox(4)
		v.add_child(h)
		var my_v := int(d.get("my", 0))
		var opp_v := int(d.get("opp", 0))
		var lower_better := bool(d.get("lower_better", false))
		var my_win := (my_v > opp_v) if (not lower_better) else (my_v < opp_v)
		var opp_win := (opp_v > my_v) if (not lower_better) else (opp_v < my_v)
		h.add_child(_qcell(str(my_v), 52, UiKit.GOOD if my_win else UiKit.TEXT, 12, my_win))
		var lab := UiKit.ellipsis(str(d.get("label", "")), 12, UiKit.MUTED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(lab)
		h.add_child(_qcell(str(opp_v), 52, UiKit.GOOD if opp_win else UiKit.TEXT, 12, opp_win))
	var eff: Dictionary = report.get("efficiency", {})
	if not eff.is_empty():
		v.add_child(UiKit.lbl("Shot conversion: us %.0f%% (%d entries) vs them %.0f%% (%d entries)" % [
			float(eff.get("my_conv", 0.0)), int(eff.get("my_i50", 0)),
			float(eff.get("opp_conv", 0.0)), int(eff.get("opp_i50", 0))], 12, UiKit.MUTED))
	return v


func _report_player_row(entry, good: bool) -> Control:
	var e: Dictionary = entry
	var v := UiKit.vbox(1)
	var verdict := CoachReport.verdict_for(e, good)
	var col := UiKit.GOOD if good else UiKit.BAD
	if not good and verdict == "Par game":
		col = UiKit.MUTED
	v.add_child(UiKit.lbl("#%d %s (%s, OVR %d) - %s" % [
		int(e.get("num", 0)), str(e.get("name", "Player")),
		str(e.get("role", "")), int(e.get("overall", 0)), verdict], 13, col, true))
	v.add_child(UiKit.lbl("%s  (%s vs par)" % [
		str(e.get("line", "")), _signed_f(float(e.get("delta", 0.0)))], 12, UiKit.MUTED))
	return v


func _signed_f(x: float) -> String:
	if x >= 0.0:
		return "+%.1f" % x
	return "%.1f" % x


func _feed_note(text: String) -> void:
	if _feed == null:
		return
	var l := UiKit.lbl("Half time  " + text, 12, UiKit.GOOD, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)


func _simulate_next_quarter(t: Dictionary) -> void:
	_last_tactics = t.duplicate()
	_apply_quarter_tactics(t)
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
	# The rival coach protects a lead, chases a deficit, counters a plan you
	# keep running, and tags your best player after half time.
	sim.set_tactics(1 - _my_side, sim.ai_tactics(1 - _my_side))


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


## "Q3 12'" in normal time; extra time counts its own minutes from zero.
func _clock_text(q: int, minute: int) -> String:
	if q >= 5:
		return "ET %d'" % clampi(minute - 120, 0, 99)
	return "Q%d %2d'" % [q, minute]


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
		"moment": col = UiKit.GOLD
		"mark": col = Color(0.85, 0.90, 0.95)
		_: col = UiKit.MUTED

	var text := str(ev.get("text", ""))
	var stamp := _clock_text(int(ev.get("q", 1)), int(ev.get("min", 0)))
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
		var end_min := 20
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
		if bool(_res.get("extra_time", false)):
			v.add_child(UiKit.lbl("After extra time", 14, UiKit.MUTED, true))
		var outlook := GameState.finals_outcome_line(_res)
		if outlook != "":
			var tag_now := str(_res.get("tag", ""))
			var slots: Dictionary = GameState.season.finals.get("slots", {})
			var through: bool = str(slots.get("W_" + tag_now, "")) == GameState.my_club
			v.add_child(UiKit.lbl(outlook, 22 if tag_now == "GF" else 16,
					UiKit.GOLD if through else UiKit.MUTED, true))

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

	if _interactive:
		v.add_child(_calls_view(0))
	var report: Dictionary = GameState.last_training_report
	if int(report.get("count", 0)) > 0 and str(report.get("home", "")) == str(_res.get("home", "")) \
			and str(report.get("away", "")) == str(_res.get("away", "")):
		v.add_child(UiKit.lbl("%d players gained %d XP." % [
				int(report["count"]), int(report["total"])], 14, UiKit.TEXT, true))
		var spent := GameState.training_summary_line()
		if spent != "":
			v.add_child(UiKit.lbl(spent + " Adjust plans in Training.", 13, UiKit.GOOD))
		var hurt := GameState.my_new_injuries()
		if not hurt.is_empty():
			var inj := UiKit.lbl("Injured: " + ", ".join(hurt), 13, UiKit.BAD, true)
			inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(inj)
	var snaps: Array = _res.get("quarter_teams", [])
	if snaps.size() >= 2:
		var ht_btn := UiKit.btn("Half-time report", 15)
		ht_btn.custom_minimum_size = Vector2(0, 44)
		ht_btn.pressed.connect(func():
			_show_half_time_popup(CoachReport.half_time_report(_res, _my_side)))
		box["footer"].add_child(ht_btn)
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
## Shared with the half-time report so both screens rank players identically.
func _influence(st: Dictionary) -> float:
	return CoachReport.influence(st)


## Router back hook. A live match cannot be abandoned half way (the rest of
## the round is already on the ladder), so back is swallowed until full time.
func handle_back() -> bool:
	if _interactive and not _finished:
		_feed_hint("Finish the match first - use Skip to full time to jump ahead.")
		return true
	return false


func _feed_hint(text: String) -> void:
	if _feed == null:
		return
	var l := UiKit.lbl(text, 12, UiKit.MUTED, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)


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
