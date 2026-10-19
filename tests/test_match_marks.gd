extends RefCounted
## The oval marks the call (P-12 pass 5, director 2026-10-18: "Merge, then mark
## the oval"): a faint corridor shade for Attack corridor and a faint ring for
## Win contest, on the grass in the side's colour, under the players. Run
## through tests/run_match_marks_tests.gd.
##
## Each marking shows only while its call is on and its moment holds (the
## corridor while the side has the ball in play; the ring at a ball-up or
## throw-in until the clearance, and round the ball in open play), at the press
## wash's faint strength at most, easing in and out over half a second, under the
## discs, never on the other side or under another call, never adding on top of
## the press wash, and never moving a player.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2027
const PHONE := Vector2(300, 387)
const FRAME := 1.0 / 30.0
## A marking takes at least this long to come in or go out (real seconds).
const FADE_LEAST := 0.4
## The faint band: the press wash's faint state (0.3 at half strength) at most,
## and at least this much, or it would not show on the turf at all.
const FAINT_TOP := 0.15
const FAINT_LEAST := 0.08


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	var res := _result(42)
	_t("_test_when_marked", [res])
	_t("_test_fades", [res])
	_t("_test_over_the_press", [res])
	_t("_test_corridor_playback", [res])
	_t("_test_contest_playback", [res])
	for sp in [1.0, 4.0]:
		_t("_test_ball_in_the_ring", [res, sp])
	_t("_test_other_calls", [res])
	_t("_test_moves_nobody", [res])
	await _t("_test_under_the_discs", [res])
	GameState.replay_seed = 0
	print(Ran.line("Match marks", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


## Fremantle v Melbourne (two clubs with real colour), as the clips show them.
func _result(seed: int) -> Dictionary:
	var res := MatchSim.new(Squad.new("FRE", GameDB.club_list("FRE"), true, "FRE"),
			Squad.new("MEL", GameDB.club_list("MEL"), false, "MEL"), seed).run()
	res["home"] = "FRE"
	res["away"] = "MEL"
	res["label"] = "Round 1"
	return res


## The result with Fremantle (side 0) on `plan` and `bursts` all match, the first
## `n` events.
static func _with_call(res: Dictionary, plan: String, bursts: Array, n: int) -> Dictionary:
	var r2 := res.duplicate()
	r2["events"] = (res["events"] as Array).slice(0, n)
	var tl := []
	for e in res["timeline"]:
		var e2: Dictionary = (e as Dictionary).duplicate(true)
		if int(e2["side"]) == 0:
			e2["plan"] = plan
			e2["bursts"] = bursts
		else:
			e2["plan"] = "balanced"
			e2["bursts"] = []
		tl.append(e2)
	r2["timeline"] = tl
	return r2


func _phone(r: Dictionary, speed: float) -> PitchView:
	var pv := PitchView.new()
	pv.size = PHONE
	pv.camera_enabled = false
	pv.upright = true
	pv.setup(r)
	pv.set_speed(speed)
	pv.play()
	return pv


static func _alpha(pv: PitchView, kind: String, side: int) -> float:
	return float((pv.mark_alphas()[kind] as Array)[side])


## When each marking shows, from the director's own state.
func _test_when_marked(res: Dictionary) -> void:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	d._beat = {}
	d._ring_at = Vector2.INF
	d.mode = "open"
	d.ball["mode"] = "held"
	d._tac[0] = {"side": 0, "plan": "attacking", "bursts": []}
	d._tac[1] = {"side": 1, "plan": "balanced", "bursts": []}
	d._poss = 0
	_check(d.corridor_mark_on(0), "Attack corridor: the corridor shows while the side has the ball in play")
	_check(not d.corridor_mark_on(1), "...and never for the other side")
	d._poss = 1
	_check(not d.corridor_mark_on(0), "...and not while the other side has the ball")
	d._poss = 0
	for m in ["centre", "stoppage", "break"]:
		d.mode = m
		_check(not d.corridor_mark_on(0), "...and not at a %s (nobody has it in play)" % m)
	d.mode = "open"
	MatchDirector.debug_no_press_shape = true
	_check(not d.corridor_mark_on(0), "...and not with the shapes off (capture_match --noshape)")
	MatchDirector.debug_no_press_shape = false
	# Win contest.
	d._tac[0] = {"side": 0, "plan": "contest", "bursts": []}
	d._ring_at = Vector2(12.0, -20.0)
	var m0: Dictionary = d.contest_mark(0)
	_check(not m0.is_empty() and bool(m0["stop"]) and (m0["at"] as Vector2) == Vector2(12.0, -20.0)
			and is_equal_approx(float(m0["r"]), MatchDirector.PACK_RING),
			"Win contest: a ball-up's ring sits on the contest at the pack's ring (%s)" % str(m0))
	_check(d.contest_mark(1).is_empty(), "...and never for the other side")
	d._poss = 1
	_check(not d.contest_mark(0).is_empty(), "...whoever is to win it")
	d._ring_at = Vector2.INF
	d.ball["pos"] = Vector2(-30.0, 8.0)
	d._struct_ball = Vector2(-10.0, -8.0)
	var m1: Dictionary = d.contest_mark(0)
	_check(not m1.is_empty() and not bool(m1["stop"]) and (m1["at"] as Vector2) == Vector2(-30.0, 8.0)
			and is_equal_approx(float(m1["r"]), MatchDirector.CONTEST_MID_RING),
			"...in open play a ring round the ball itself (not its next spot) at the midfield's ring (%s)" % str(m1))
	for m in ["centre", "stoppage", "break", "kickin", "shot"]:
		d.mode = m
		_check(d.contest_mark(0).is_empty(), "...and not with the ball out of open play (%s)" % m)
	d.mode = "open"
	d._beat = {"k": 0, "kind": "ballup"}
	_check(d.contest_mark(0).is_empty(), "...nor through a stoppage's clearance (the stoppage's own ring's time)")
	# From the umpire's call: the ball dead in a tackle before a ball-up, the
	# ring is already on the ball-up's spot, and reading it changes nothing.
	var nb := -1
	for i in range(1, (res["events"] as Array).size()):
		if str((res["events"][i] as Dictionary).get("kind", "")) == "ballup" and d._prev_real(i) >= 0:
			nb = i
			break
	if nb >= 0:
		var pk: int = d._prev_real(nb)
		d._locs[pk] = Vector2(14.0, -7.0)
		d._beat = {"k": pk, "kind": str((res["events"][pk] as Dictionary).get("kind", ""))}
		d.mode = "stoppage"
		# Not yet called (the ball still held): no ring.
		d.ball["mode"] = "held"
		d.ball["pos"] = Vector2(-3.0, 11.0)
		d._pin_called_ballup()
		var early: Dictionary = d.contest_mark(0)
		# The call: the ball dead in the tackle. The ball-up is pinned to the ball.
		d.ball["mode"] = "dead"
		var st: int = d._rng.state
		d._pin_called_ballup()
		var had: bool = d._locs.has(nb)
		var mc: Dictionary = d.contest_mark(0)
		var same: bool = d._rng.state == st and d._locs.has(nb) == had
		var want: Vector2 = d._loc(nb)
		_check(early.is_empty() and not mc.is_empty() and bool(mc["stop"]) and (mc["at"] as Vector2).distance_to(Vector2(-3.0, 11.0)) < 0.001
				and want.distance_to(Vector2(-3.0, 11.0)) < 0.001 and same,
				"...from the call (the ball dead before a ball-up) the ring and the ball-up are where the ball is (%s, the ball-up %s, before the call %s), reading it changes nothing (%s)" % [str(mc), str(want), str(early), str(same)])
	d._beat = {}
	d.mode = "open"
	_check(not d.corridor_mark_on(0), "Win contest has no corridor")
	d._tac[0] = {"side": 0, "plan": "attacking", "bursts": []}
	_check(d.contest_mark(0).is_empty(), "Attack corridor has no ring")
	MatchDirector.debug_no_press_shape = true
	d._tac[0] = {"side": 0, "plan": "contest", "bursts": []}
	_check(d.contest_mark(0).is_empty(), "No ring with the shapes off")
	MatchDirector.debug_no_press_shape = false


## Faint, and eased in and out over half a second: never a one-frame appearance.
func _test_fades(res: Dictionary) -> void:
	var pv := _phone(res, 1.0)
	pv.playing = false
	var d: MatchDirector = pv.director
	d._beat = {}
	d._ring_at = Vector2.INF
	d.mode = "open"
	d.ball["mode"] = "held"
	d._tac[0] = {"side": 0, "plan": "attacking", "bursts": []}
	d._tac[1] = {"side": 1, "plan": "balanced", "bursts": []}
	d._poss = 0
	var cases := [["corridor", func(): d._tac[0] = {"side": 0, "plan": "attacking", "bursts": []}],
			["stop", func():
				d._tac[0] = {"side": 0, "plan": "contest", "bursts": []}
				d._ring_at = Vector2(0.0, 0.0)],
			["open", func():
				d._tac[0] = {"side": 0, "plan": "contest", "bursts": []}
				d._ring_at = Vector2.INF]]
	var full := {}
	var off := func(): d._tac[0] = {"side": 0, "plan": "balanced", "bursts": []}
	for c in cases:
		var kind: String = c[0]
		off.call()
		for i in range(90):
			pv._step_marks(1.0 / 60.0)
		(c[1] as Callable).call()
		# In: from nothing to full, frame by frame at 60 fps.
		# (The open ring first waits for a touch of MARK_OPEN_LEAST: timed from its first frame.)
		var first := -1.0
		var reached := 0.0
		var waited := 0.0
		var step_most := 0.0
		var prev := 0.0
		var top := PitchView.MARK_ALPHA * (PitchView.MARK_OPEN_SHARE if kind == "open" else 1.0)
		while reached < 3.0 and waited < 3.0:
			pv._step_marks(1.0 / 60.0)
			var a := _alpha(pv, kind, 0)
			if first < 0.0 and a <= 0.0:
				waited += 1.0 / 60.0
				continue
			reached += 1.0 / 60.0
			if first < 0.0:
				first = a
			step_most = maxf(step_most, a - prev)
			prev = a
			if a >= top - 0.0001:
				break
		full[kind] = _alpha(pv, kind, 0)
		var other := _alpha(pv, kind, 1)
		# Out: from full to nothing.
		off.call()
		var t_out := 0.0
		while _alpha(pv, kind, 0) > 0.0 and t_out < 3.0:
			pv._step_marks(1.0 / 60.0)
			t_out += 1.0 / 60.0
		_check(first < top * 0.05, "%s: the first frame shows under a twentieth of it (%.4f of %.3f): it never pops" % [kind, first, top])
		_check(reached >= FADE_LEAST and reached <= 0.75, "%s: it fades in over %.2f s (at least %.1f)" % [kind, reached, FADE_LEAST])
		_check(t_out >= FADE_LEAST and t_out <= 0.75, "%s: ...and out over %.2f s" % [kind, t_out])
		_check(step_most <= top / (FADE_LEAST * 60.0) * 1.6, "%s: no frame jumps more than an eased fade allows (%.4f)" % [kind, step_most])
		_check(other == 0.0, "%s: nothing for the other side" % kind)
		var wait_want := PitchView.MARK_OPEN_LEAST if kind == "open" else 0.0
		_check(absf(waited - wait_want) <= 1.5 / 60.0,
				"%s: it starts coming in %.2f s after its moment begins (%.2f s wanted: the open ring waits for a touch of %.1f s)" % [kind, waited, wait_want, PitchView.MARK_OPEN_LEAST])
	_check(float(full["corridor"]) <= FAINT_TOP + 0.0001 and float(full["corridor"]) >= FAINT_LEAST,
			"The corridor is faint: %.3f, the press wash's faint state (%.2f) at most" % [float(full["corridor"]), FAINT_TOP])
	_check(float(full["stop"]) <= FAINT_TOP + 0.0001 and float(full["stop"]) >= FAINT_LEAST,
			"The stoppage ring is faint: %.3f" % float(full["stop"]))
	_check(float(full["open"]) <= FAINT_TOP + 0.0001 and float(full["open"]) >= FAINT_LEAST,
			"The open-play ring is faint: %.3f" % float(full["open"]))
	# The corridor runs at full strength from the side's defensive 50 to the goal
	# square (its soft ends lie outside those), and nothing in front of the 50.
	var ce := func(x: float) -> float: return PitchView.corridor_end(x)
	_check(is_equal_approx(float(ce.call(MatchDirector.CORRIDOR_FROM)), 1.0) and is_equal_approx(float(ce.call(0.0)), 1.0)
			and is_equal_approx(float(ce.call(MatchDirector.CORRIDOR_TO)), 1.0)
			and float(ce.call(MatchDirector.CORRIDOR_FROM - PitchView.MARK_END_FEATHER)) == 0.0
			and float(ce.call(MatchDirector.CORRIDOR_TO + PitchView.MARK_END_FEATHER)) == 0.0
			and is_equal_approx(MatchDirector.CORRIDOR_FROM, -(MatchMotion.GOAL_X - 50.0))
			and is_equal_approx(MatchDirector.CORRIDOR_TO, MatchMotion.GOAL_X - 9.0),
			"The corridor is at full strength from the defensive 50 (%.0f m) to the goal square (%.0f m)" % [MatchDirector.CORRIDOR_FROM, MatchDirector.CORRIDOR_TO])
	_check(is_equal_approx(PitchView.MARK_ALPHA, PitchView.PRESS_ZONE_ALPHA * MatchDirector.PRESS_ZONE_STANDING),
			"The markings are laid at the press wash's faint strength (%.2f)" % PitchView.MARK_ALPHA)
	pv.free()


## Where the press wash lies, a marking never adds on top of it: the two together
## are never stronger than the stronger alone, and the press wash is untouched.
func _test_over_the_press(res: Dictionary) -> void:
	var pv := _phone(res, 1.0)
	pv.playing = false
	var worst := 0.0
	var hid := true
	var clear := true
	for fade in [0.0, 0.5, 1.0]:
		pv._zone_fade = [0.0, fade]
		var x := -80.0
		while x <= 80.0:
			var p := pv.press_alpha_at(x)
			var m := pv.mark_over_press(PitchView.MARK_ALPHA, x)
			# Two layers at alphas p and m cover 1 - (1-p)(1-m) of the turf.
			var both := 1.0 - (1.0 - p) * (1.0 - m)
			worst = maxf(worst, both - maxf(p, PitchView.MARK_ALPHA))
			if fade == 1.0 and p >= PitchView.MARK_ALPHA and m > 0.0:
				hid = false
			if p == 0.0 and not is_equal_approx(m, PitchView.MARK_ALPHA):
				clear = false
			x += 2.0
	_check(worst <= 0.0001, "A marking over the press wash never adds a flash (most over the stronger alone %.4f)" % worst)
	_check(hid, "Under a full-strength hunting press the marking gives way to it")
	_check(clear, "Off the press wash the marking is laid at its own strength")
	# The press wash itself follows its own rule (A13): a marking changes nothing in it.
	pv._zone_fade = [0.0, 0.0]
	var d: MatchDirector = pv.director
	d._tac[1] = {"side": 1, "plan": "defensive", "bursts": []}
	d._tac[0] = {"side": 0, "plan": "attacking", "bursts": []}
	d._poss = 0
	d.mode = "open"
	d._beat = {}
	d.ball["pos"] = Vector2(-30.0, 0.0)
	_check(d.press_zone_level(1) == 1.0 and d.corridor_mark_on(0),
			"With the corridor showing, the press still hunts at full strength (A13 unchanged)")
	pv.free()


## Attack corridor on the oval: Fremantle's corridor shows while Fremantle has
## the ball, and is gone once Melbourne has had it half a second.
func _test_corridor_playback(res: Dictionary) -> void:
	var r2 := _with_call(res, "attacking", [], 260)
	var pv := _phone(r2, 1.0)
	var d: MatchDirector = pv.director
	var since_lost := 0.0
	var own_frames := 0
	var own_full := 0
	var opp_shown := 0
	var other := 0.0
	var top := 0.0
	var step_most := 0.0
	var prev := 0.0
	var rings := 0.0
	# Frame by frame through each turnover from a full corridor in open play:
	# it starts going the frame Melbourne has the ball, falls every frame (never
	# back up), no frame drops more than an eased fade allows, and it is gone
	# within half a second, taking at least FADE_LEAST over it.
	var turn := -1.0           # real seconds since the turnover being followed
	var turns := 0
	var turns_ok := 0
	var turn_prev := 0.0
	var turn_bad := ""
	var turn_step := 0.0
	var prev_poss := -1
	var guard := 0
	while not d.idle() and guard < 40000:
		guard += 1
		pv._process(FRAME)
		var a := _alpha(pv, "corridor", 0)
		if turn < 0.0 and prev_poss == 0 and d._poss == 1 and d.mode == "open" and prev >= PitchView.MARK_ALPHA - 0.0001:
			turn = 0.0
			turn_prev = prev
			turn_bad = ""
			turn_step = 0.0
		elif turn >= 0.0:
			turn += FRAME
		if turn >= 0.0:
			if d._poss != 1:
				turn = -1.0    # won straight back: not a clean turnover to follow
			else:
				if a > turn_prev or (turn <= FRAME * 0.5 and a >= turn_prev):
					turn_bad = "rose or held at %.2f s (%.4f after %.4f)" % [turn, a, turn_prev]
				turn_step = maxf(turn_step, turn_prev - a)
				turn_prev = a
				if a <= 0.0:
					turns += 1
					if turn_bad == "" and turn >= FADE_LEAST - FRAME and turn <= PitchView.MARK_FADE_SECS + FRAME 							and turn_step <= PitchView.MARK_ALPHA / (FADE_LEAST * 30.0) * 1.6:
						turns_ok += 1
					elif turn_bad == "":
						turn_bad = "gone after %.2f s, largest drop %.4f" % [turn, turn_step]
					if turn_bad != "":
						print("  corridor turnover: %s" % turn_bad)
					turn = -1.0
		prev_poss = d._poss
		top = maxf(top, a)
		step_most = maxf(step_most, absf(a - prev))
		prev = a
		other = maxf(other, _alpha(pv, "corridor", 1))
		rings = maxf(rings, maxf(_alpha(pv, "stop", 0), _alpha(pv, "open", 0)))
		if d._poss == 0:
			since_lost = 0.0
			if d.mode == "open":
				own_frames += 1
				if a >= PitchView.MARK_ALPHA - 0.0001:
					own_full += 1
		else:
			since_lost += FRAME
			if since_lost > PitchView.MARK_FADE_SECS + FRAME and a > 0.0:
				opp_shown += 1
	var share := float(own_full) / float(maxi(1, own_frames))
	print("  corridor: full in %.0f%% of Fremantle's open-play frames (%d)" % [share * 100.0, own_frames])
	_check(own_frames > 300 and share >= 0.6, "The corridor shows at full in most of Fremantle's open play (%.0f%% of %d frames)" % [share * 100.0, own_frames])
	_check(opp_shown == 0, "...and is gone once Melbourne has had the ball half a second (%d frames)" % opp_shown)
	print("  corridor: %d of %d turnovers from full fade out cleanly" % [turns_ok, turns])
	_check(turns >= 3 and turns_ok == turns,
			"...frame by frame at each turnover from full: it starts going at once, falls every frame, and is gone in 0.4 to 0.5 s (%d of %d)" % [turns_ok, turns])
	_check(other == 0.0 and rings == 0.0, "No marking for Melbourne on Balanced, and no ring under Attack corridor")
	_check(top <= FAINT_TOP + 0.0001, "...faint all the way (%.3f)" % top)
	_check(step_most <= PitchView.MARK_ALPHA / (FADE_LEAST * 30.0) * 1.6,
			"...and it never pops between frames at 1x (largest change %.4f)" % step_most)
	pv.free()


## Win contest on the oval: the ring at every ball-up and throw-in, planted on the
## contest from the call to the clearance; in open play on the ball (_test_ball_in_the_ring).
func _test_contest_playback(res: Dictionary) -> void:
	var r2 := _with_call(res, "contest", [], 400)
	var pv := _phone(r2, 1.0)
	var d: MatchDirector = pv.director
	var stoppages := 0
	var full_at := 0
	var on_spot := true
	var cur_k := -1
	var cur_max := 0.0
	var cur_at := Vector2.INF
	var after := -1.0          # real seconds since the clearance (beat after a stoppage)
	var gone_late := 0
	var open_wrong := 0
	var since_open_off := 0.0
	var other := 0.0
	var corr := 0.0
	var glide_most := 0.0
	var prev_at := Vector2.INF
	var top := 0.0
	var open_full := 0
	# Planted: while the stoppage ring shows, its centre never moves.
	var planted_at := Vector2.INF
	var planted_moves := 0
	var spans := 0
	# From the call: a ball-up called in the play before it (the ball dead in a
	# tackle or a pack) already has its ring showing when its own beat begins.
	var was_stoppage := false
	var called := 0
	var called_on := 0
	var guard := 0
	while not d.idle() and guard < 60000:
		guard += 1
		var kind_before := str(d._beat.get("kind", ""))
		pv._process(FRAME)
		var kind := str(d._beat.get("kind", ""))
		var k := int(d._beat.get("k", -1))
		var sa := _alpha(pv, "stop", 0)
		var oa := _alpha(pv, "open", 0)
		var sring: Dictionary = pv._stop_ring[0]
		if sa > 0.0 and not sring.is_empty():
			if not planted_at.is_finite():
				planted_at = sring["at"]
				spans += 1
			elif (sring["at"] as Vector2).distance_to(planted_at) > 0.01:
				planted_moves += 1
				planted_at = sring["at"]
		else:
			planted_at = Vector2.INF
		if kind == "ballup" and kind_before != "ballup" and was_stoppage:
			called += 1
			called_on += 1 if sa > 0.0 else 0
		was_stoppage = d.mode == "stoppage" and kind != "ballup" and kind != "throwin"
		top = maxf(top, maxf(sa, oa))
		other = maxf(other, maxf(_alpha(pv, "stop", 1), _alpha(pv, "open", 1)))
		corr = maxf(corr, _alpha(pv, "corridor", 0))
		if (kind == "ballup" or kind == "throwin") and k != cur_k:
			if cur_k >= 0:
				stoppages += 1
				full_at += 1 if cur_max >= PitchView.MARK_ALPHA - 0.0001 else 0
			cur_k = k
			cur_max = 0.0
			cur_at = d._ring_at
			after = -1.0
		if cur_k >= 0 and k == cur_k:
			cur_max = maxf(cur_max, sa)
			var ring: Dictionary = pv._stop_ring[0]
			if sa > 0.0 and (ring.is_empty() or (ring["at"] as Vector2).distance_to(cur_at) > 0.01):
				on_spot = false
		elif cur_k >= 0:
			if after < 0.0:
				after = 0.0
			else:
				after += FRAME
			# (unless the next ball-up is already called: its own ring, on its own spot)
			var nxt: Dictionary = d.contest_mark(0)
			if after > PitchView.MARK_FADE_SECS + FRAME and sa > 0.0 and (nxt.is_empty() or not bool(nxt["stop"])):
				gone_late += 1
		# The open-play ring only in live open play (after its fade).
		if d.contest_mark(0).is_empty() or bool(d.contest_mark(0).get("stop", false)):
			since_open_off += FRAME
			if since_open_off > PitchView.MARK_FADE_SECS + FRAME and oa > 0.0:
				open_wrong += 1
		else:
			since_open_off = 0.0
			if oa >= PitchView.MARK_ALPHA * PitchView.MARK_OPEN_SHARE - 0.0001:
				open_full += 1
		var orr: Dictionary = pv._open_ring[0]
		if oa > 0.0 and not orr.is_empty():
			var at: Vector2 = orr["at"]
			if prev_at.is_finite():
				glide_most = maxf(glide_most, at.distance_to(prev_at))
			prev_at = at
		else:
			prev_at = Vector2.INF
	if cur_k >= 0:
		stoppages += 1
		full_at += 1 if cur_max >= PitchView.MARK_ALPHA - 0.0001 else 0
	print("  contest: %d of %d stoppages reach the full ring; %d open-play frames at full" % [full_at, stoppages, open_full])
	_check(stoppages >= 5 and float(full_at) / float(stoppages) >= 0.8,
			"Win contest: the ring comes in fully at the stoppages as the pack forms (%d of %d)" % [full_at, stoppages])
	_check(on_spot, "...on the contest itself")
	print("  contest: the ring planted in %d showings (%d moves); %d of %d called ball-ups ringed from the call" % [spans, planted_moves, called_on, called])
	_check(spans >= 5 and planted_moves == 0, "...planted there from the call to the clearance: it never follows the ball in (%d moves in %d showings)" % [planted_moves, spans])
	_check(called >= 3 and called_on == called, "...and on from the umpire's call, before the ball-up itself (%d of %d)" % [called_on, called])
	_check(gone_late == 0, "...and goes out at the clearance, gone half a second after it (%d late frames)" % gone_late)
	_check(open_full > 200, "In open play the ring round the ball shows (%d frames at full)" % open_full)
	_check(open_wrong == 0, "...and only in live open play (%d frames off it)" % open_wrong)
	_check(glide_most <= MatchMotion.SPRINT * FRAME * MatchDirector.TEMPO + 0.01,
			"...moving with the ball no faster than a sprint (%.2f m in a frame)" % glide_most)
	_check(other == 0.0 and corr == 0.0, "No ring for Melbourne on Balanced, and no corridor under Win contest")
	_check(top <= FAINT_TOP + 0.0001, "...faint all the way (%.3f)" % top)
	pv.free()


## In open play the ball is inside the ring's pad in every frame the ring shows
## (motion critic, 2026-10-18: the ring trailed the ball by its own radius). The
## ring is on the ball while it moves at a player's pace; a ball faster than a
## sprint (a kick or handball in flight) leaves the ring where it was, easing out,
## and the ring eases back in where the ball comes down. So the ball is outside
## the pad only in a frame the ring is already easing out, and never then with the
## ring growing stronger. Drawn positions, on the phone, at 1x and 4x.
func _test_ball_in_the_ring(res: Dictionary, speed: float) -> void:
	var r2 := _with_call(res, "contest", [], 400)
	var pv := _phone(r2, speed)
	var d: MatchDirector = pv.director
	var shown := 0
	var on_ball := 0
	var outside := 0
	var outside_bad := 0
	var worst_on := -INF       # metres past the pad (negative: room to spare)
	var leavings := 0
	var was_leaving := false
	var prev := 0.0
	var sc := pv._scale()
	# A ball-up under Win contest: from the umpire's call to the clearance the ball
	# is inside the ring's pad in every frame (motion critic, 2026-10-18: the ring
	# came in 15 m from the ball and the ball flew to it).
	var bu_frames := 0
	var bu_out := 0
	var bu_worst := -INF
	var bu_calls := 0
	var bu_seen := {}
	# No ring shows for less than MARK_OPEN_LEAST (a pad blinked on for 5 frames).
	var run := {"stop": 0.0, "open": 0.0}
	var runs := {"stop": 0, "open": 0}
	var shortest := {"stop": INF, "open": INF}
	var guard := 0
	while not d.idle() and guard < 60000:
		guard += 1
		pv._process(FRAME)
		for kind in ["stop", "open"]:
			if _alpha(pv, kind, 0) > 0.0:
				run[kind] = float(run[kind]) + FRAME
			elif float(run[kind]) > 0.0:
				runs[kind] = int(runs[kind]) + 1
				shortest[kind] = minf(float(shortest[kind]), float(run[kind]))
				run[kind] = 0.0
		var bk := str(d._beat.get("kind", ""))
		var bkk := int(d._beat.get("k", -1))
		var cm: Dictionary = d.contest_mark(0)
		if not cm.is_empty() and bool(cm["stop"]) and bkk >= 0:
			var bu := -1
			if bk == "ballup":
				bu = bkk
			elif bk != "throwin":
				var nk := d._next_real(bkk)
				if nk >= 0 and str((d.events[nk] as Dictionary).get("kind", "")) == "ballup":
					bu = nk
					if not bu_seen.has(nk):
						bu_calls += 1
			if bu >= 0:
				bu_seen[bu] = true
				bu_frames += 1
				var bd := pv._w2s(cm["at"]).distance_to(pv.ball_point()) / sc
				var broom := pv.mark_pad_radius(float(cm["r"])) - pv.mark_ball_radius()
				bu_worst = maxf(bu_worst, bd - broom)
				if bd > broom:
					bu_out += 1
		var oa := _alpha(pv, "open", 0)
		var orr: Dictionary = pv._open_ring[0]
		var leaving := pv.open_ring_leaving(0)
		if leaving and not was_leaving:
			leavings += 1
		was_leaving = leaving
		if oa > 0.0 and not orr.is_empty():
			shown += 1
			var dist := pv._w2s(orr["at"]).distance_to(pv.ball_point()) / sc
			var room := pv.mark_pad_radius(float(orr["r"])) - pv.mark_ball_radius()
			if not leaving:
				on_ball += 1
				worst_on = maxf(worst_on, dist - room)
			elif dist > room:
				outside += 1
				if oa > prev + 0.000001:
					outside_bad += 1
			if dist > room and not leaving:
				outside_bad += 1
		prev = oa
	print("  ball in the ring at %.0fx: %d frames shown, %d on the ball (at least %.2f m of pad to spare), %d easing out with the ball gone (%d eases)" % [
			speed, shown, on_ball, -worst_on, outside, leavings])
	_check(on_ball > 150 and worst_on <= 0.0,
			"%.0fx: in open play the ball is inside the ring's pad in every frame the ring is on it (%d frames, worst %.2f m past the pad)" % [speed, on_ball, worst_on])
	_check(outside_bad == 0 and leavings >= 5,
			"%.0fx: ...and outside it only while the ring eases out after a ball faster than a sprint, never growing (%d bad frames, %d eases)" % [speed, outside_bad, leavings])
	print("  ball-ups at %.0fx: %d ball-ups (%d called before their beat), %d frames from the call to the clearance, the ball at least %.2f m inside the pad" % [
			speed, bu_seen.size(), bu_calls, bu_frames, -bu_worst])
	_check(bu_seen.size() >= 5 and bu_calls >= 3 and bu_out == 0,
			"%.0fx: at a ball-up the ball is inside the ring's pad from the umpire's call to the clearance (%d ball-ups, %d called, %d frames outside, worst %.2f m past the pad)" % [speed, bu_seen.size(), bu_calls, bu_out, bu_worst])
	print("  shortest showing at %.0fx: stoppage ring %.2f s (%d), open ring %.2f s (%d)" % [
			speed, float(shortest["stop"]), int(runs["stop"]), float(shortest["open"]), int(runs["open"])])
	_check(int(runs["open"]) >= 5 and int(runs["stop"]) >= 3
			and float(shortest["open"]) >= PitchView.MARK_OPEN_LEAST - FRAME * 0.5
			and float(shortest["stop"]) >= PitchView.MARK_OPEN_LEAST - FRAME * 0.5,
			"%.0fx: no ring shows for less than %.1f s (shortest: open %.2f s of %d, stoppage %.2f s of %d)" % [
			speed, PitchView.MARK_OPEN_LEAST, float(shortest["open"]), int(runs["open"]), float(shortest["stop"]), int(runs["stop"])])
	pv.free()


## Balanced and the other four calls (and the press) mark nothing.
func _test_other_calls(res: Dictionary) -> void:
	for c in [["balanced", []], ["controlled", []], ["through_stars", []], ["balanced", ["surge"]],
			["balanced", ["hold"]], ["defensive", []]]:
		var r2 := _with_call(res, str(c[0]), c[1], 160)
		var pv := _phone(r2, 4.0)
		var d: MatchDirector = pv.director
		var most := 0.0
		var guard := 0
		while not d.idle() and guard < 20000:
			guard += 1
			pv._process(FRAME)
			for kind in ["corridor", "stop", "open"]:
				for side in [0, 1]:
					most = maxf(most, _alpha(pv, kind, side))
		_check(most == 0.0, "No marking under %s%s (most %.3f)" % [str(c[0]), "" if (c[1] as Array).is_empty() else " + " + str(c[1]), most])
		pv.free()


## The markings only draw: the players are where the match has them with or
## without the view (a director played alone lands every token on the same spot).
func _test_moves_nobody(res: Dictionary) -> void:
	for plan in ["attacking", "contest"]:
		var r2 := _with_call(res, plan, [], 120)
		var pv := _phone(r2, 4.0)
		var bare := MatchDirector.new()
		bare.setup(r2, (r2["events"] as Array).duplicate())
		var worst := 0.0
		var shown := 0.0
		for i in range(900):
			if not pv.playing:
				break   # the view stops at the end of the log; so does the match alone
			pv._process(FRAME)
			bare.advance(FRAME * 4.0)
			shown = maxf(shown, maxf(_alpha(pv, "corridor", 0), _alpha(pv, "stop", 0)))
		for t in range(bare.tokens.size()):
			worst = maxf(worst, (bare.tokens[t]["pos"] as Vector2).distance_to(pv.director.tokens[t]["pos"]))
		_check(shown > 0.0 and worst < 0.0001, "%s: marked, and every player is where the match alone puts him (%.5f m off)" % [plan, worst])
		pv.free()


## Drawn under the discs (and over the press wash's layer), on the phone and the PC oval.
func _test_under_the_discs(res: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for setup in [["phone", PHONE, true], ["PC", Vector2(1280, 720), false]]:
		for plan in ["attacking", "contest"]:
			var pv := PitchView.new()
			pv.camera_enabled = false
			pv.upright = bool(setup[2])
			pv.position = Vector2.ZERO
			tree.root.add_child(pv)
			pv.size = setup[1]
			pv.setup(_with_call(res, plan, [], 120))
			pv.playing = false
			var d: MatchDirector = pv.director
			d._beat = {}
			d.mode = "open"
			d.ball["mode"] = "held"
			d._poss = 0
			d._tac[0] = {"side": 0, "plan": plan, "bursts": []}
			d._ring_at = Vector2(0.0, 0.0) if plan == "contest" else Vector2.INF
			for i in range(40):
				await tree.process_frame
			var layers: Array = pv.drawn_layers
			var mi := layers.find("marks")
			var di := layers.find("discs")
			var pi := layers.find("press")
			_check(mi >= 0 and di > mi and pi >= 0 and pi < mi,
					"%s, %s: the marking is drawn over the turf and under the discs (%s)" % [str(setup[0]), plan, str(layers)])
			pv.queue_free()
			await tree.process_frame
