extends SceneTree
## Display audit of the live match view: plays one whole match you coach through the
## real MatchScene (the scoreboard, the oval, the feed, every break and coach's call)
## and saves frames with the match's own state beside each, so what is drawn can be
## checked against what the engine says. It changes nothing: it only reads.
## Needs a real renderer (capture.yml):
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_oval_audit.gd -- \
##       --home FRE --away MEL --size 390x844 --seed 2026 --out /tmp/oval
##   --home/--away CODE  the pairing (you coach the home side; default FRE v MEL)
##   --size WxH          the window (390x844 a phone in portrait, 1280x720 a PC)
##   --seed N            the career seed (default 2026)
##   --speed S           playback speed 1, 2, 4 or 8 (default: the game's own, 4)
##   --every N           an evenly spaced frame every N events (default 40)
##   --figures           the mini-figure prototype on (Settings > Match view)
##   --maxsecs S         give up after S seconds of real time (default 1500)
##   --fullnudge         every disc drawn fully apart (PitchView.nudge_full), for the comparison
##   --strip N           a frame at each of the eight events from event N (the same events in any window)
##   --maxevents N       stop after N events (a short look at the kits, say)
## Writes <out>_NNN_<what>.png, <out>_log.jsonl (one line per frame: the last event
## the engine released, the ball, every token in metres and in pixels, the words on
## the scoreboard) and <out>_trace.jsonl (the same positions every few frames, no
## image, for speeds, stacking and frozen play). Dark theme. Never touches a real save.

var W := 390
var H := 844
var _out := "/tmp/oval"
var _state
var _scene
var _pitch
var _n := 0
var _queue: Array = []        # [path, Image] waiting to be written while play is paused
var _log: FileAccess
var _trace: FileAccess
var _new_events: Array = []
var _emitted_events: Array = []
var _tally := [[0, 0], [0, 0]]  # side -> [goals, behinds], counted from the released events
var _caps := {}
var _pending: Array = []      # [{at: frame, what}]
var _frame := 0
var _last_mode := ""
var _pressed := {}
var _overlay_frames := 0
var _since_even := 0
var _even_n := 0
var _burst_left := 0
var _burst_tag := ""
var _after_behind := -1
var _moment_shots := 0
var _every := 40
var _pending_now := ""
var _strip_from := -1


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


func _r(r: Rect2) -> Array:
	return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]


func _run() -> void:
	var args := _args()
	var home := str(args.get("home", "FRE"))
	var away := str(args.get("away", "MEL"))
	_out = str(args.get("out", "/tmp/oval"))
	if args.has("size"):
		var wh := str(args["size"]).split("x")
		W = int(wh[0])
		H = int(wh[1])
	var every := int(args.get("every", "40"))
	var maxsecs := float(args.get("maxsecs", "1500"))
	await process_frame
	_state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	_state.autosave_enabled = false
	_state.save_path = "user://capture_oval_audit.save"
	_state.settings_path = "user://capture_oval_audit.cfg"
	_state.reset()
	_state.career_seed = int(args.get("seed", "2026"))
	_state.replay_seed = int(args.get("seed", "2026"))
	_state.set_setting("seen_training_intro", true)
	_state.set_setting("seen_weekly_loop_intro", true)
	_state.set_vignettes_on(false)
	_state.set_match_figures_on(args.has("figures"))
	if args.has("speed"):
		_state.set_setting("match_speed", float(args["speed"]))
	_state.start_season(home, db.club_list(home))
	_state.tutorials = false
	UK.apply_appearance("dark")
	# The pairing: this round's fixture has the two clubs meet, the home side at home
	# (whoever each was to play swaps across), so the season stays a whole round.
	var season = _state.season
	var rnd: Array = season.fixture[season.round_index]
	var mine = null
	var theirs = null
	for m in rnd:
		if str(m["home"]) == home or str(m["away"]) == home:
			mine = m
		if str(m["home"]) == away or str(m["away"]) == away:
			theirs = m
	if mine == null:
		push_error("no fixture for %s this round" % home)
		quit(1)
		return
	if theirs != null and not is_same(mine, theirs):
		var old_opp := str(mine["away"]) if str(mine["home"]) == home else str(mine["home"])
		if str(theirs["home"]) == away:
			theirs["home"] = old_opp
		else:
			theirs["away"] = old_opp
	mine["home"] = home
	mine["away"] = away
	if not _state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	await process_frame
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(_scene)
	_pitch = _scene.get("_pitch")
	if args.has("fullnudge"):
		load("res://scripts/ui/PitchView.gd").set("nudge_full", true)
	var maxevents := int(args.get("maxevents", "0"))
	_strip_from = int(args.get("strip", "-1"))
	_pitch.event_played.connect(_released)
	_log = FileAccess.open(_out + "_log.jsonl", FileAccess.WRITE)
	_trace = FileAccess.open(_out + "_trace.jsonl", FileAccess.WRITE)

	# What the view is drawing with: the kits, the type, the figure sheets.
	var sim = _state.pending_sim
	var SV = load("res://scripts/ui/match/StoppageVignette.gd")
	var meta := {
		"what": "meta", "home": home, "away": away, "size": [W, H],
		"window": [root.size.x, root.size.y], "logical": [root.content_scale_size.x, root.content_scale_size.y],
		"visible": _v(root.get_visible_rect().size), "display": DisplayServer.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"video": RenderingServer.get_video_adapter_name(),
		"pending_match": _state.pending_match, "my_club": str(_state.my_club),
		"speed": float(_pitch.speed), "mini_figures": bool(_pitch.mini_figures),
		"camera_enabled": bool(_pitch.camera_enabled), "stacked": bool(_scene.get("_stacked")),
		"kits": [_kit(db.club_guernsey(home)), _kit(db.club_guernsey(away))],
		"club_colours": [_cols(db.club_colours(home)), _cols(db.club_colours(away))],
		"font_bold": str(UK.BOLD.resource_path),
		"figure_sheet": str(SV.FIGURE_SHADE.resource_path), "figure_mask": str(SV.FIGURE_MASK.resource_path),
		"figure_design": str(SV.FIGURE_DESIGN.resource_path), "figure_digits": str(SV.FIGURE_DIGITS.resource_path),
		"ground": [sim.squads[0].ground.size(), sim.squads[1].ground.size()],
		"bench": [sim.squads[0].bench.size(), sim.squads[1].bench.size()],
		"tokens": _token_meta(),
	}
	_log.store_line(JSON.stringify(meta))
	print("OVAL meta ", JSON.stringify(meta).left(1500))

	var t0 := Time.get_ticks_msec()
	var last_progress := t0
	var last_emitted := -1
	var done := false
	var code := 0
	while not done:
		# On the frame clock, not the draw: the game only redraws when something
		# changed, so a still screen (a coach's call waiting) draws nothing, and a
		# loop waiting on a drawn frame never woke to answer it.
		await process_frame
		_frame += 1
		var now := Time.get_ticks_msec()
		_every = every
		_drain()
		if _emitted_events.size() != last_emitted:
			last_emitted = _emitted_events.size()
			last_progress = now

		var ft: Node = _scene.find_child("FullTime", true, false)
		var start: Node = _scene.find_child("StartQuarter", true, false)
		var card: Node = _scene.find_child("MomentCard", true, false)
		if ft != null:
			_overlay_frames += 1
			last_progress = now
			if _overlay_frames == 45:
				await _shot("fulltime")
				done = true
		elif start != null and not _pressed.has(start.get_instance_id()):
			_overlay_frames += 1
			last_progress = now
			if _overlay_frames == 30:
				await _shot("break_q%d" % int(_state.pending_sim.current_quarter))
				_flush()
			elif _overlay_frames >= 36:
				_pressed[start.get_instance_id()] = true
				_overlay_frames = 0
				(start as Button).emit_signal("pressed")
		elif card != null and not _pressed.has(card.get_instance_id()):
			_overlay_frames += 1
			last_progress = now
			var m: Dictionary = _state.pending_sim.pending_moment
			if _overlay_frames == 24 and _moment_shots < 4:
				_moment_shots += 1
				await _shot("moment_%s" % str(m.get("kind", "")))
				_flush()
			elif _overlay_frames >= 30:
				_pressed[card.get_instance_id()] = true
				_overlay_frames = 0
				var b: Node = card.find_child("Moment_%d" % int(m.get("default", 0)), true, false)
				if b == null:
					b = card.find_child("Moment_0", true, false)
				if b != null:
					(b as Button).emit_signal("pressed")
		else:
			_overlay_frames = 0
			await _in_play()
		if _frame % 6 == 0 and bool(_pitch.playing):
			_trace.store_line(JSON.stringify(_state_line("trace", false)))
		if _queue.size() >= 14:
			_flush()
		if maxevents > 0 and _emitted_events.size() >= maxevents and not done:
			await _shot("stopped")
			done = true
		if now - last_progress > 90000:
			await _shot("stalled")
			print("OVAL STALLED: no event released for 90 s at event %d" % _emitted_events.size())
			code = 2
			done = true
		if now - t0 > int(maxsecs * 1000.0):
			await _shot("timeout")
			print("OVAL TIMEOUT at event %d of %d" % [_emitted_events.size(), int(_pitch.events.size())])
			code = 3
			done = true
	_flush()
	var res: Dictionary = _state.last_match
	_log.store_line(JSON.stringify({"what": "end", "frames": _n, "events": _emitted_events.size(),
			"tally": _tally, "result_goals": res.get("goals", []), "result_behinds": res.get("behinds", []),
			"secs": float(Time.get_ticks_msec() - t0) / 1000.0, "process_frames": _frame}))
	_log.close()
	_trace.close()
	print("OVAL done: %d frames, %d events, tally %s, %.0f s" % [_n, _emitted_events.size(), str(_tally),
			float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(code)


func _released(ev: Dictionary) -> void:
	_new_events.append(ev)


func _kit(k: Dictionary) -> Dictionary:
	return {"design": str(k["design"]), "base": (k["base"] as Color).to_html(false),
			"pattern": (k["pattern"] as Color).to_html(false), "pattern2": (k["pattern2"] as Color).to_html(false)}


func _cols(cols: Array) -> Array:
	var out := []
	for c in cols:
		out.append((c as Color).to_html(false))
	return out


func _token_meta() -> Array:
	var out := []
	for t in _pitch.director.tokens:
		out.append({"id": int(t["id"]), "side": int(t["side"]), "num": int(t["num"]), "role": str(t["role"]),
				"slot": str(t["slot"]), "surname": str(t["surname"])})
	return out


## One capture of each kind a quarter at most (two for the common ones), so a
## match gives every moment without hundreds of the same frame.
func _want(what: String, delay: int, limit := 2) -> void:
	if what != "even":
		var key := "%s_q%d" % [what, int(_pitch.period)]
		if int(_caps.get(key, 0)) >= limit:
			return
		_caps[key] = int(_caps.get(key, 0)) + 1
	_pending.append({"at": _frame + delay, "what": what})


func _on_event(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	match kind:
		"goal":
			_want("goal", 0)
			_want("goal_after", 10)
		"behind":
			_want("behind", 0)
			_after_behind = _emitted_events.size()
		"quarter":
			_want("quarter_siren", 0, 1)
		"throwin":
			_want("throwin", 0)
			_want("throwin_after", 12)
		"ballup":
			_want("ballup", 0, 1)
		"out_on_full", "last_disposal":
			_want("boundary_free", 4, 1)
		"sub":
			_want("interchange", 2, 1)
		"tackle":
			_want("tackle", 2, 1)
		"mark":
			_want("mark", 0, 1)
	if _after_behind >= 0 and kind in ["kick", "handball", "mark"]:
		# The kick-in: the first possession after a behind.
		_after_behind = -1
		_want("kickin_played", 0)


func _in_play() -> void:
	var mode := str(_pitch.director.mode)
	if mode != _last_mode:
		_last_mode = mode
		match mode:
			"centre":
				_want("centre_setup", 14)
				_want("centre_bounce", 40)
			"kickin":
				_want("kickin_setup", 16)
			"shot":
				_want("shot", 10)
				_want("shot_late", 26, 1)
			"stoppage":
				var by: float = absf((_pitch.director.ball["pos"] as Vector2).y)
				if by > 38.0:
					_want("stoppage_boundary", 14)
				else:
					_want("stoppage", 14, 1)
	var keep: Array = []
	var fired := false
	for p in _pending:
		if int(p["at"]) <= _frame and not fired:
			fired = true
			_pending_now = str(p["what"])
		else:
			keep.append(p)
	_pending = keep
	if fired:
		await _shot(_pending_now)
	elif _burst_left > 0 and _frame % 2 == 0:
		_burst_left -= 1
		await _shot(_burst_tag)


## The events the view released since the last look, in order.
func _drain() -> void:
	var batch := _new_events
	_new_events = []
	for ev in batch:
		_emitted_events.append(ev)
		var kind := str(ev.get("kind", ""))
		var side := int(ev.get("side", -1))
		if kind == "goal" and side >= 0:
			_tally[side][0] += 1
		elif kind == "behind" and side >= 0:
			_tally[side][1] += 1
		_on_event(ev)
		if _strip_from >= 0 and _emitted_events.size() > _strip_from and _emitted_events.size() <= _strip_from + 8:
			_want("strip", 0, 99)
		_since_even += 1
		if _since_even >= _every:
			_since_even = 0
			_even_n += 1
			_want("even", 0)
			if _even_n % 5 == 0:
				_burst_left = 4
				_burst_tag = "burst%02d" % int(_even_n / 5.0)


## A frame and the match's state at that frame: ask for a draw, wait for it,
## then read both (the events released meanwhile are counted first, so the
## log's score is the one on the screen).
func _shot(what: String) -> void:
	(_pitch as Control).queue_redraw()
	await RenderingServer.frame_post_draw
	_drain()
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s_%03d_%s.png" % [_out, _n, what]
	_queue.append([path, img])
	var line := _state_line(what, true)
	line["file"] = path.get_file()
	line["n"] = _n
	_log.store_line(JSON.stringify(line))
	_n += 1


func _flush() -> void:
	for q in _queue:
		(q[1] as Image).save_png(str(q[0]))
	_queue.clear()
	_log.flush()
	_trace.flush()


## The match as the engine has it and as the view draws it, this frame.
func _state_line(what: String, full: bool) -> Dictionary:
	var d = _pitch.director
	var ball: Dictionary = d.ball
	var origin: Vector2 = (_pitch as Control).get_global_rect().position
	var toks := []
	for t in d.tokens:
		var pos: Vector2 = t["pos"]
		var vel: Vector2 = t["vel"]
		var row := [int(t["side"]), int(t["num"]), snappedf(pos.x, 0.1), snappedf(pos.y, 0.1),
				snappedf(vel.length(), 0.1), 1 if float(t["down"]) > 0.0 else 0]
		if full:
			var sp: Vector2 = _pitch._w2s(pos)
			row.append(roundi(origin.x + sp.x))
			row.append(roundi(origin.y + sp.y))
		toks.append(row)
	var ball_pos: Vector2 = ball["pos"]
	var line := {
		"what": what, "frame": _frame, "ms": Time.get_ticks_msec(), "dtime": snappedf(float(d.time), 0.01),
		"emitted": _emitted_events.size(), "staged": int(d.cursor), "logged": int(_pitch.events.size()),
		"mode": str(d.mode), "period": int(_pitch.period), "playing": bool(_pitch.playing),
		"ball": _v(ball_pos), "ball_h": snappedf(float(ball["h"]), 0.1), "ball_mode": str(ball["mode"]),
		"holder": int(ball["holder"]), "actor": int(d.actor), "tok": toks,
	}
	if not full:
		return line
	var bs: Vector2 = _pitch._w2s(ball_pos)
	var cam: Vector2 = _pitch._cam
	line["ball_px"] = [roundi(origin.x + bs.x), roundi(origin.y + bs.y)]
	line["cam"] = _v(cam)
	line["zoom"] = snappedf(float(_pitch._zoom), 0.01)
	line["scale"] = snappedf(float(_pitch._scale()), 0.01)
	line["speed"] = float(_pitch.speed)
	line["caption"] = str(_pitch.caption_text())
	if _pitch.has_method("bench_spots"):
		var drawn := []
		for dp in _pitch._disc:
			drawn.append([roundi(origin.x + dp.x), roundi(origin.y + dp.y)])
		line["drawn"] = drawn
		line["tr"] = snappedf(float(_pitch.token_radius()), 0.1)
		var bench := []
		for sp in _pitch.bench_spots(_pitch.token_radius()):
			bench.append([int(sp["side"]), int(sp["num"]), roundi(origin.x + sp["pos"].x), roundi(origin.y + sp["pos"].y)])
		line["bench_drawn"] = bench
		line["clash"] = bool(_pitch.clash)
	line["rings"] = (_pitch.rings as Dictionary).size()
	line["role_labels"] = d.role_labels()
	line["tally"] = _tally.duplicate(true)
	if not _emitted_events.is_empty():
		var ev: Dictionary = _emitted_events[-1]
		var slim := {}
		for k in ["q", "min", "kind", "side", "fp", "name", "num", "score", "goals", "behinds", "set_shot", "text"]:
			if ev.has(k):
				slim[k] = ev[k]
		line["last_ev"] = slim
		var recent := []
		for i in range(maxi(0, _emitted_events.size() - 6), _emitted_events.size()):
			var e: Dictionary = _emitted_events[i]
			recent.append("%s:%d:%d:%s" % [str(e.get("kind", "")), int(e.get("side", -1)), roundi(float(e.get("fp", 0.0))),
					str(e.get("num", ""))])
		line["recent"] = recent
	var sim = _state.pending_sim
	if sim != null:
		line["sim_q"] = int(sim.current_quarter)
		line["sim_goals"] = [int(sim.goals(0)), int(sim.goals(1))]
		line["sim_behinds"] = [int(sim.behinds(0)), int(sim.behinds(1))]
		line["sim_ground"] = [sim.squads[0].ground.size(), sim.squads[1].ground.size()]
		line["sim_bench"] = [sim.squads[0].bench.size(), sim.squads[1].bench.size()]
	# The words on the screen.
	var words := {}
	for pair in [["score_home", _scene.get("_score_home")], ["score_away", _scene.get("_score_away")],
			["clock", _scene.get("_clock")], ["lead", _scene.get("_lead")], ["setup", _scene.get("_setup_line")],
			["momentum", _scene.get("_mom_word")], ["play_btn", _scene.get("_play_btn")]]:
		var c = pair[1]
		if c == null or not is_instance_valid(c):
			continue
		var ctl: Control = c
		var text := str(c.text)
		var font: Font = ctl.get_theme_font("font")
		var fs: int = ctl.get_theme_font_size("font_size")
		words[pair[0]] = {"text": text, "rect": _r(ctl.get_global_rect()), "visible": ctl.is_visible_in_tree(),
				"text_w": roundi(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x), "fs": fs}
	line["words"] = words
	var ground: Rect2 = _pitch.pitch_rect()
	var panel: Control = _scene.get("_side_panel")
	var feed_scroll: Control = _scene.get("_feed_scroll")
	line["rects"] = {
		"pitch": _r((_pitch as Control).get_global_rect()),
		"ground": _r(Rect2(origin + ground.position, ground.size)),
		"side_panel": _r(panel.get_global_rect()),
		"feed": _r(feed_scroll.get_global_rect()),
		"view": _r(root.get_visible_rect()),
	}
	var feed: Node = _scene.get("_feed")
	if feed != null:
		var rows := []
		for i in range(maxi(0, feed.get_child_count() - 4), feed.get_child_count()):
			var row: Node = feed.get_child(i)
			rows.append(str(row.get("text")) if row is Label else str(row.name))
		line["feed_tail"] = rows
	return line
