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
var _training_done := false


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
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_root = UiKit.vbox(8)
	margin.add_child(_root)

	_root.add_child(_scoreboard())

	_narrow_wanted()
	_root.add_child(_body)


func _narrow_wanted() -> void:
	# Stack the feed under the oval on phones, side by side on desktop.
	var narrow := UiKit.view_width(self) < 900.0
	if narrow:
		_body = UiKit.vbox(8)
	else:
		_body = HBoxContainer.new()
		_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_pitch = PitchView.new()
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_pitch)

	_side_panel = UiKit.panel(UiKit.PANEL, 12)
	if narrow:
		_side_panel.custom_minimum_size = Vector2(0, 210)
	else:
		_side_panel.custom_minimum_size = Vector2(340, 0)
	_side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_side_panel)

	var sv := UiKit.vbox(6)
	_side_panel.add_child(sv)
	sv.add_child(UiKit.lbl("Commentary", 15, UiKit.GOLD, true))
	_feed = UiKit.vbox(3)
	_feed_scroll = UiKit.scroll(_feed)
	sv.add_child(_feed_scroll)
	sv.add_child(_controls())


func _scoreboard() -> Control:
	var p := UiKit.panel(UiKit.PANEL, 10)
	var h := UiKit.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)

	var hc: Array = GameDB.club_colours(str(_res["home"]))
	var ac: Array = GameDB.club_colours(str(_res["away"]))

	var left := UiKit.hbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(left)
	left.add_child(_club_name(str(_res["home"]), true))
	_score_home = UiKit.lbl("0.0 (0)", 28, hc[2], true)
	left.add_child(_score_home)

	var mid := UiKit.vbox(0)
	mid.custom_minimum_size = Vector2(140, 0)
	h.add_child(mid)
	var label := str(_res.get("label", "Match"))
	var ll := UiKit.lbl(label, 12, UiKit.MUTED)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.autowrap_mode = TextServer.AUTOWRAP_OFF
	mid.add_child(ll)
	_clock = UiKit.lbl("Q1 0'", 20, UiKit.TEXT, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_clock)
	var venue := UiKit.lbl(str(GameDB.club(str(_res["home"])).get("ground", "")),
			11, UiKit.MUTED)
	venue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	venue.autowrap_mode = TextServer.AUTOWRAP_OFF
	mid.add_child(venue)

	var right := UiKit.hbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_score_away = UiKit.lbl("0.0 (0)", 28, ac[2], true)
	right.add_child(_score_away)
	right.add_child(_club_name(str(_res["away"]), false))
	return p


func _club_name(code: String, right_aligned: bool) -> Label:
	var l := UiKit.lbl(GameDB.club_name(code), 16, UiKit.TEXT, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_aligned \
			else HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(90, 0)
	return l


func _controls() -> Control:
	var v := UiKit.vbox(6)

	var row := UiKit.hbox(5)
	v.add_child(row)
	_play_btn = UiKit.btn("Pause", 13)
	_play_btn.custom_minimum_size = Vector2(84, 40)
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.pressed.connect(_on_toggle)
	row.add_child(_play_btn)

	for s in SPEEDS:
		var b := UiKit.btn("%dx" % int(s), 13)
		b.custom_minimum_size = Vector2(44, 40)
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
	_pitch.skip_to_end()


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
	_pitch.pause()
	_sync_controls()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.76)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var p := UiKit.panel(UiKit.PANEL, 18, 12)
	p.custom_minimum_size = Vector2(620, 0)
	centre.add_child(p)
	var v := UiKit.vbox(9)
	p.add_child(v)
	var q := GameState.pending_sim.current_quarter
	v.add_child(UiKit.lbl("Coach Box - Quarter %d" % q, 23, UiKit.GOLD, true))
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
		focus.add_item("%s #%d" % [str(r["name"]), int(r["num"])], i + 1)
	v.add_child(_field("Run play through", focus))

	var tag := OptionButton.new()
	tag.add_item("No tag", 0)
	var opp := _roster_side(1 - _my_side)
	for i in range(opp.size()):
		var r2: Dictionary = opp[i]
		tag.add_item("%s #%d" % [str(r2["name"]), int(r2["num"])], i + 1)
	v.add_child(_field("Tag opponent", tag))

	var pep := OptionButton.new()
	for i in range(PEP_TALKS.size()):
		pep.add_item(str(PEP_TALKS[i][1]), i)
	v.add_child(_field("Pep talk", pep))

	var start := UiKit.btn("Start Quarter", 18, true)
	start.custom_minimum_size = Vector2(0, 52)
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
		overlay.queue_free()
		_simulate_next_quarter(t))
	v.add_child(start)


func _field(label: String, control: Control) -> Control:
	var h := UiKit.hbox(8)
	var l := UiKit.lbl(label, 13, UiKit.MUTED, true)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	GameState.pending_sim.set_tactics(_my_side, t)
	# Basic AI counter-plan: leaders protect a lead, trailers take more risk.
	var s: Array = GameState.pending_sim.result()["score"]
	var opp_plan := "balanced"
	if int(s[1 - _my_side]) > int(s[_my_side]) + 18:
		opp_plan = "controlled"
	elif int(s[1 - _my_side]) + 18 < int(s[_my_side]):
		opp_plan = "attacking"
	GameState.pending_sim.set_tactics(1 - _my_side, {"gameplan": opp_plan, "pep": "steady"})
	_res = GameState.pending_sim.run_quarter()
	_res["home"] = GameState.pending_match["home"]
	_res["away"] = GameState.pending_match["away"]
	_res["label"] = GameState.pending_match["label"]
	var all_events: Array = _res.get("events", [])
	var new_events := all_events.slice(_event_cursor)
	_event_cursor = all_events.size()
	_pitch.append_events(new_events)
	_pitch.play()
	_sync_controls()


# ---------------------------------------------------------------------------
# Playback hooks
# ---------------------------------------------------------------------------
func _on_event(ev: Dictionary) -> void:
	_update_scoreboard(ev)
	_feed_add(ev)


func _update_scoreboard(ev: Dictionary) -> void:
	var s: Array = ev.get("score", [0, 0])
	_score_home.text = _from_total(int(s[0]))
	_score_away.text = _from_total(int(s[1]))
	_clock.text = "Q%d %d'" % [int(ev.get("q", 1)), int(ev.get("min", 0))]


## Events carry the running total, so back out goals and behinds from it.
func _from_total(total: int) -> String:
	var t := maxi(0, total)
	var g := int(t / 6.0)
	return "%d.%d (%d)" % [g, t - g * 6, t]


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
	if _interactive and GameState.pending_sim != null and GameState.pending_sim.current_quarter <= 4:
		_sync_controls()
		_show_coach_box()
		return
	_finished = true
	# Skip-to-full-time applies the remaining events without emitting them, so
	# force the board to the real result before the overlay goes up.
	_update_scoreboard({"q": 4, "min": 20, "kind": "final", "score": _res["score"]})
	if _interactive:
		GameState.finish_interactive_match(_res)
	_sync_controls()
	_show_fulltime()


# ---------------------------------------------------------------------------
# Full time
# ---------------------------------------------------------------------------
func _show_fulltime() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)

	var p := UiKit.panel(UiKit.PANEL, 20, 12)
	p.custom_minimum_size = Vector2(mini(860, int(UiKit.view_width(self)) - 40), 0)
	centre.add_child(p)
	var v := UiKit.vbox(9)
	p.add_child(v)

	var s: Array = _res["score"]
	var home: String = _res["home"]
	var away: String = _res["away"]
	var i_am_home: bool = home == GameState.my_club
	var my_score: int = int(s[0]) if i_am_home else int(s[1])
	var opp_score: int = int(s[1]) if i_am_home else int(s[0])
	var drew: bool = my_score == opp_score
	var won: bool = my_score > opp_score

	var tag := str(_res.get("label", "Match"))
	v.add_child(UiKit.lbl("Full Time - %s" % tag, 15, UiKit.MUTED))

	var hs := UiKit.scoreline(int(_res["goals"][0]), int(_res["behinds"][0]))
	var ascore := UiKit.scoreline(int(_res["goals"][1]), int(_res["behinds"][1]))
	var verb := "drew with"
	if int(s[0]) > int(s[1]):
		verb = "defeated"
	elif int(s[1]) > int(s[0]):
		verb = "lost to"
	var head := UiKit.lbl("%s %s  %s  %s %s" % [
			GameDB.club_name(str(home)), hs, verb,
			GameDB.club_name(str(away)), ascore], 19, UiKit.TEXT, true)
	v.add_child(head)

	if GameState.my_club != "":
		var verdict := "DRAW" if drew else ("WIN by %d" % absi(my_score - opp_score) \
				if won else "LOSS by %d" % absi(my_score - opp_score))
		var vl := UiKit.lbl(verdict, 26,
				UiKit.MUTED if drew else UiKit.margin_colour(won), true)
		v.add_child(vl)

	# Two columns inside a scroll, so the box score fits a phone in landscape.
	var body := UiKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := UiKit.scroll(body)
	sc.custom_minimum_size = Vector2(0,
			maxf(180.0, UiKit.view_height(self) - 330.0))
	v.add_child(sc)

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

	var cont := UiKit.btn("Training Session", 18, true)
	cont.custom_minimum_size = Vector2(0, 52)
	cont.pressed.connect(func():
		overlay.queue_free()
		_show_training())
	v.add_child(cont)


func _show_training() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var p := UiKit.panel(UiKit.PANEL, 20, 12)
	p.custom_minimum_size = Vector2(640, 0)
	centre.add_child(p)
	var v := UiKit.vbox(9)
	p.add_child(v)
	v.add_child(UiKit.lbl("Post-Match Training", 24, UiKit.GOLD, true))
	v.add_child(UiKit.lbl("Choose one focus. Less-experienced players have more development upside; established players improve more slowly.",
			13, UiKit.MUTED))
	var result_box := UiKit.vbox(4)
	var choices := [
		["skills", "Skills - disposal, carry, discipline"],
		["contest", "Contest - contested ball, pressure, ruck craft"],
		["goal", "Forward craft - goal kicking, accuracy, marking"],
		["recovery", "Recovery - durability and repeat pressure"],
	]
	for c in choices:
		var b := UiKit.btn(str(c[1]), 15)
		b.pressed.connect(_apply_training.bind(str(c[0]), result_box, choices))
		v.add_child(b)
	v.add_child(result_box)
	var done := UiKit.btn("Back to Hub", 17, true)
	done.pressed.connect(func(): Router.back())
	v.add_child(done)


func _apply_training(focus: String, result_box: VBoxContainer, _choices: Array) -> void:
	if _training_done:
		return
	_training_done = true
	for child in result_box.get_children():
		child.queue_free()
	var gains := GameState.train_my_list(focus)
	result_box.add_child(UiKit.lbl("Training gains", 16, UiKit.GOLD, true))
	for g in gains:
		var plus := "+%d %s" % [int(g["gain"]), str(g["attr"])]
		if int(g["overall_gain"]) > 0:
			plus += "  (+%d OVR)" % int(g["overall_gain"])
		result_box.add_child(UiKit.lbl("%s: %s" % [str(g["name"]), plus], 13, UiKit.TEXT))


func _quarters_table() -> Control:
	var v := UiKit.vbox(3)
	var home: String = _res["home"]
	var away: String = _res["away"]
	var qg: Array = _res["q_goals"]
	var qb: Array = _res["q_behinds"]

	var qh := UiKit.hbox(6)
	v.add_child(qh)
	qh.add_child(_qcell("", 44, UiKit.MUTED, 12))
	for i in range(4):
		qh.add_child(_qcell("Q%d" % (i + 1), 52, UiKit.MUTED, 12))
	qh.add_child(_qcell("Final", 70, UiKit.MUTED, 12))

	for side in range(2):
		var code: String = home if side == 0 else away
		var qr := UiKit.hbox(6)
		v.add_child(qr)
		var badge := UiKit.club_badge(code, 12)
		badge.custom_minimum_size = Vector2(44, 0)
		qr.add_child(badge)
		for i in range(4):
			qr.add_child(_qcell("%d.%d" % [int(qg[i][side]), int(qb[i][side])],
					52, UiKit.TEXT, 13))
		qr.add_child(_qcell(UiKit.scoreline(int(_res["goals"][side]),
				int(_res["behinds"][side])), 70, UiKit.GOLD, 14, true))
	return v


func _qcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.lbl(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	var h0 := UiKit.hbox(6)
	v.add_child(h0)
	h0.add_child(_qcell(str(GameDB.club_short(str(_res["home"]))), 70, UiKit.TEXT, 13, true))
	h0.add_child(_qcell("", 150, UiKit.MUTED, 12))
	h0.add_child(_qcell(str(GameDB.club_short(str(_res["away"]))), 70, UiKit.TEXT, 13, true))
	var t: Array = _res["team"]
	for row in TEAM_STAT_ROWS:
		var h := UiKit.hbox(6)
		v.add_child(h)
		var a := int(float(t[0].get(row[0], 0.0)))
		var b := int(float(t[1].get(row[0], 0.0)))
		h.add_child(_qcell(str(a), 70, UiKit.GOOD if a > b else UiKit.TEXT, 13))
		h.add_child(_qcell(str(row[1]), 150, UiKit.MUTED, 12))
		h.add_child(_qcell(str(b), 70, UiKit.GOOD if b > a else UiKit.TEXT, 13))
	return v


func _best_table() -> Control:
	var v := UiKit.vbox(2)
	var roster: Array = _res.get("roster", [[], []])
	var players: Dictionary = _res.get("players", {})
	var codes := [str(_res["home"]), str(_res["away"])]
	for side in range(2):
		if side == 1:
			v.add_child(UiKit.spacer(10))
		v.add_child(UiKit.club_badge(codes[side], 13))
		var hdr := UiKit.hbox(4)
		v.add_child(hdr)
		hdr.add_child(_qcell("#", 26, UiKit.MUTED, 10))
		hdr.add_child(_lcell("Player", 128, UiKit.MUTED, 10))
		for c in ["D", "G", "M", "T", "HO"]:
			hdr.add_child(_qcell(c, 30, UiKit.MUTED, 10))
		var best := _rank_side(roster[side], players)
		for i in range(mini(7, best.size())):
			var p: Dictionary = best[i]
			var st: Dictionary = p["stats"]
			var row := UiKit.hbox(4)
			v.add_child(row)
			var col := UiKit.GOLD if i == 0 else UiKit.TEXT
			row.add_child(_qcell(str(int(p["num"])), 26, col, 12))
			row.add_child(_lcell(str(p["name"]), 128, col, 12, i == 0))
			row.add_child(_qcell(str(int(st.get("disposals", 0))), 30, col, 12))
			row.add_child(_qcell(str(int(st.get("goals", 0))), 30, col, 12))
			row.add_child(_qcell(str(int(st.get("marks", 0))), 30, col, 12))
			row.add_child(_qcell(str(int(st.get("tackles", 0))), 30, col, 12))
			row.add_child(_qcell(str(int(st.get("hitouts", 0))), 30, col, 12))
	return v


func _lcell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.lbl(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _rank_side(list: Array, players: Dictionary) -> Array:
	var out := []
	for p in list:
		var st: Dictionary = players.get(str(p["id"]), {})
		out.append({"num": int(p["num"]), "name": str(p["name"]), "stats": st,
				"inf": _influence(st)})
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
	if what == NOTIFICATION_EXIT_TREE and _pitch != null:
		_pitch.pause()
