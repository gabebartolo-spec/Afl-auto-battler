extends RefCounted
## The live match view (PitchView, MatchDirector, MatchMotion) is presentation
## only: these checks hold it to that. Run through
## tests/run_match_visual_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	var res := _result(42)
	_test_sim_untouched(res)
	_test_full_playback(res)
	_test_open_play_shots(res)
	_test_speed_sequencing(res)
	_test_rng_isolation(res)
	_test_appended_segments()
	_test_pitch_view_api(res)
	_test_empty_view()
	_test_ends_swap(res)
	_test_ballup_is_informational()
	_test_wings_and_lineups()
	_test_score_colour()
	_test_no_wrong_way_kicks(res)
	_test_match_flow(res)
	_test_boundary_collect(res)
	_test_smother_at_the_kick(res)
	_test_tactical_timeline()
	var truth_hb := _test_truth(res)
	_test_tail_seeds(truth_hb)
	_test_play_when_idle(res)
	_test_numbers_readable()
	_test_oval_people(res)
	_test_broadcast_vignettes()
	_test_set_shot_calls()
	_test_role_labels(res)
	_test_flood_shape(res)
	_test_press_shape(res)
	_test_centre_setups(res)
	_test_call_shapes(res)
	_test_call_playback(res)
	_test_call_lines(res)
	_test_farewell()
	_test_match_ground()
	_test_discs_apart()
	_test_clash_kit()
	_test_label_overlap()
	_test_sides()
	_test_bench_strip()
	_test_ends_change_at_restart(res)
	_test_upright_oval(res)
	GameState.replay_seed = 0
	print("Match visual tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _sim(seed: int, a := "RIC", b := "SYD") -> MatchSim:
	return MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)


func _result(seed: int) -> Dictionary:
	var res := _sim(seed).run()
	res["home"] = "RIC"
	res["away"] = "SYD"
	res["label"] = "Round 1"
	return res


## Play `events` through a director in steps of `dt` until everything is
## released. Returns the released events and what was seen on the way.
func _play(res: Dictionary, events: Array, dt: float, watch := true) -> Dictionary:
	var d := MatchDirector.new()
	d.setup(res, events)
	var out := []
	var nan := 0
	var outside := 0
	var max_step := 0.0
	var prev := []
	for t in d.tokens:
		prev.append(t["pos"])
	var guard := 0
	var limit := int(6000.0 / dt)
	while not d.idle() and guard < limit:
		guard += 1
		out.append_array(d.advance(dt))
		if not watch:
			continue
		for i in range(d.tokens.size()):
			var p: Vector2 = d.tokens[i]["pos"]
			if not p.is_finite():
				nan += 1
			elif not MatchMotion.inside_oval(p, -0.01):
				outside += 1
			max_step = maxf(max_step, p.distance_to(prev[i]))
			prev[i] = p
		if not (d.ball["pos"] as Vector2).is_finite() or not is_finite(float(d.ball["h"])):
			nan += 1
	return {"out": out, "director": d, "nan": nan, "outside": outside,
			"max_step": max_step, "stalled": guard >= limit}


# ---------------------------------------------------------------------------
func _test_sim_untouched(res: Dictionary) -> void:
	var before: Array = (res["events"] as Array).duplicate(true)
	var played := _play(res, res["events"], 1.0 / 15.0, false)
	_check(played["out"].size() == before.size(), "Every event is released once")
	_check(res["events"] == before, "Playback never writes to an event")
	# The same fixture replayed from scratch is identical: the view has no
	# path back into the match.
	var again := _result(42)
	_check(again["events"] == before, "Event log identical after a playback")
	_check(again["score"] == res["score"] and again["winner"] == res["winner"],
			"Score and winner identical after a playback")
	_check(again["players"] == res["players"] and again["team"] == res["team"],
			"Player and team stats identical after a playback")


func _test_full_playback(res: Dictionary) -> void:
	var played := _play(res, res["events"], 1.0 / 60.0 * 4.0)
	var d: MatchDirector = played["director"]
	var out: Array = played["out"]
	_check(not played["stalled"], "Playback reaches the end of the log")
	_check(out.size() == (res["events"] as Array).size(), "All %d events released (%d)" % [
			(res["events"] as Array).size(), out.size()])
	var in_order := true
	for i in range(mini(out.size(), (res["events"] as Array).size())):
		if not is_same(out[i], res["events"][i]):
			in_order = false
			break
	_check(in_order, "Events are released in log order, as the same dictionaries")
	_check(int(played["nan"]) == 0, "No NaN positions (%d)" % int(played["nan"]))
	_check(int(played["outside"]) == 0, "Every player stays on the oval (%d outside)" % int(played["outside"]))
	# 4x at 60 fps: a sprinter covers well under 2 m a frame. More would be a
	# visible jump.
	_check(float(played["max_step"]) < 2.2, "No player jumps (largest frame step %.2f m)" % float(played["max_step"]))
	var arrivals: Array = d.arrivals
	var close := 0
	var worst := 0.0
	for a in arrivals:
		var err := absf((a["pos"] as Vector2).x - float(a["want_x"]))
		worst = maxf(worst, err)
		if err <= 3.0:
			close += 1
	_check(arrivals.size() > 800, "Arrivals are logged (%d)" % arrivals.size())
	_check(float(close) >= 0.99 * float(arrivals.size()),
			"The ball is at the logged spot when the event is released (%d of %d within 3 m)" % [close, arrivals.size()])
	_check(worst < 15.0, "No release far from the logged spot (worst %.1f m)" % worst)
	var scores := 0
	for a in arrivals:
		if str(a["kind"]) == "goal" or str(a["kind"]) == "behind":
			scores += 1
			if absf((a["pos"] as Vector2).x) < 84.0:
				scores -= 1000
	_check(scores > 0, "Every goal and behind is released at the goal line")


func _test_speed_sequencing(res: Dictionary) -> void:
	var evs: Array = (res["events"] as Array).slice(0, 220)
	var slow: Array = _play(res, evs, 1.0 / 60.0, false)["out"]
	var fast: Array = _play(res, evs, 1.0 / 60.0 * 8.0, false)["out"]
	var lumpy: Array = _play(res, evs, 0.4, false)["out"]
	_check(slow.size() == evs.size() and fast.size() == evs.size() and lumpy.size() == evs.size(),
			"Every speed releases every event")
	var same := true
	for i in range(evs.size()):
		if i >= slow.size() or i >= fast.size() or i >= lumpy.size() \
				or not is_same(slow[i], evs[i]) or not is_same(fast[i], evs[i]) \
				or not is_same(lumpy[i], evs[i]):
			same = false
			break
	_check(same, "1x, 8x and long frames release the same events in the same order")


func _test_rng_isolation(res: Dictionary) -> void:
	var evs: Array = (res["events"] as Array).slice(0, 150)
	seed(12345)
	var expect := [randi(), randi(), randi()]
	seed(12345)
	var a := _play(res, evs, 1.0 / 15.0, false)
	var got := [randi(), randi(), randi()]
	_check(got == expect, "Playback draws nothing from the global random stream")
	var b := _play(res, evs, 1.0 / 15.0, false)
	var sa: Dictionary = (a["director"] as MatchDirector).snapshot()
	var sb: Dictionary = (b["director"] as MatchDirector).snapshot()
	_check(var_to_str(sa) == var_to_str(sb), "The same match plays out the same way twice")
	# A different fixture label reseeds the presentation only.
	var other := res.duplicate()
	other["label"] = "Round 2"
	var c := _play(other, evs, 1.0 / 15.0, false)
	_check(c["out"].size() == evs.size(), "Another presentation seed still releases every event")


func _test_appended_segments() -> void:
	var res := _result(7)
	var all: Array = res["events"]
	var cut := 0
	for i in range(all.size()):
		if str(all[i]["kind"]) == "quarter":
			cut = i + 1
			break
	var events := all.slice(0, cut)
	var d := MatchDirector.new()
	d.setup(res, events)
	var out := []
	var guard := 0
	while not d.idle() and guard < 100000:
		guard += 1
		out.append_array(d.advance(1.0 / 15.0))
	_check(out.size() == cut, "The first segment plays to its end (%d/%d)" % [out.size(), cut])
	events.append_array(all.slice(cut))
	_check(not d.idle(), "Appended events wake the view")
	guard = 0
	while not d.idle() and guard < 200000:
		guard += 1
		out.append_array(d.advance(1.0 / 15.0))
	var ok := out.size() == all.size()
	for i in range(mini(out.size(), all.size())):
		if not is_same(out[i], all[i]):
			ok = false
			break
	_check(ok, "Appended segments release every event in order (%d/%d)" % [out.size(), all.size()])


func _test_pitch_view_api(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(800, 600)
	var seen := []
	var fin := [0]
	pv.event_played.connect(func(ev): seen.append(ev))
	pv.finished.connect(func(): fin[0] += 1)
	pv.setup(res)
	_check(pv.events == res["events"] and not is_same(pv.events, res["events"]),
			"The view keeps its own copy of the event list")
	pv.set_speed(8.0)
	pv.play()
	for i in range(400):
		pv._process(1.0 / 60.0)
	_check(seen.size() > 0 and pv.current_index() == seen.size(), "current_index() counts released events")
	var before := seen.size()
	pv.skip_to_end()
	_check(fin[0] == 1, "skip_to_end() finishes at once")
	_check(seen.size() == before, "skip_to_end() does not replay the feed")
	_check(pv.current_index() == (res["events"] as Array).size() and is_equal_approx(pv.progress(), 1.0),
			"skip_to_end() leaves the view at the end of the log")
	_check(not pv.playing, "Nothing plays after a skip")
	# Playing to the final siren closes playback with one finished signal.
	var pv2 := PitchView.new()
	pv2.size = Vector2(800, 600)
	var fin2 := [0]
	var last := [""]
	pv2.finished.connect(func(): fin2[0] += 1)
	pv2.event_played.connect(func(ev): last[0] = str(ev["kind"]))
	var short := res.duplicate()
	short["events"] = (res["events"] as Array).slice(0, 40) + [(res["events"] as Array)[-1]]
	pv2.setup(short)
	pv2.set_speed(8.0)
	pv2.play()
	var guard := 0
	while pv2.playing and guard < 20000:
		guard += 1
		pv2._process(1.0 / 60.0)
	_check(last[0] == "final" and fin2[0] == 1 and not pv2.playing,
			"The final siren ends playback with one finished signal")
	pv.free()
	pv2.free()


func _test_empty_view() -> void:
	# The main menu draws the oval with no match behind it.
	var pv := PitchView.new()
	pv.size = Vector2(640, 480)
	pv.setup({"events": [], "roster": [[], []], "home": "", "away": ""})
	pv.play()
	pv._process(0.1)
	_check(not pv.playing and pv.director.tokens.is_empty(), "An empty view idles safely")
	pv.free()


## A logged ball-up only stages the stoppage: it leaves the momentum meter and
## the commentary feed exactly as they were.
func _test_ballup_is_informational() -> void:
	var scene = load("res://scripts/ui/MatchScene.gd").new()
	scene._momentum = 0.5
	scene._track_momentum({"kind": "sub", "side": 0, "fp": 20.0})
	_check(is_equal_approx(scene._momentum, 0.5), "An event without the engine's momentum leaves the meter")
	scene._track_momentum({"kind": "ballup", "side": -1, "fp": 20.0, "mom": 0.5})
	_check(is_equal_approx(scene._momentum, 0.5), "A ball-up does not move the momentum meter")
	scene._track_momentum({"kind": "kick", "side": 0, "fp": 20.0, "mom": -0.32})
	_check(is_equal_approx(scene._momentum, -0.32), "The meter shows the engine's momentum, nothing of its own")
	_check(scene.QUIET_KINDS.has("ballup"), "Ball-ups stay out of the commentary feed")
	scene.free()



## The players the match plays on the wings are drawn on the wings, a replay
## opens with the 18 who started (not the 18 who finished), and the player
## each event names is on the oval when it plays.
func _test_wings_and_lineups() -> void:
	var named := 0
	var drawn := 0
	var starters_ok := true
	var seen := 0
	var found := 0
	for i in range(3):
		var sim := _sim(200 + i, ["COL", "SYD", "MEL"][i], ["CAR", "GEE", "ESS"][i])
		var wings := [[], []]
		var start := [[], []]
		for s in range(2):
			for p in (sim.squads[s] as Squad).ground:
				start[s].append(int(p["num"]))
				if Roles.on_wing(p):
					wings[s].append(int(p["num"]))
		var res := sim.run()
		res["home"] = "A%d" % i
		res["away"] = "B%d" % i
		var fresh := MatchDirector.new()
		fresh.setup(res, (res["events"] as Array).duplicate())
		for t in fresh.tokens:
			var s := int(t["side"])
			if not (start[s] as Array).has(int(t["num"])):
				starters_ok = false
			if str(t["slot"]) == "WL" or str(t["slot"]) == "WR":
				drawn += 1
				if (wings[s] as Array).has(int(t["num"])):
					named += 1
		# Play the log, counting who is on the oval as each event plays.
		var guard := 0
		while not fresh.idle() and guard < 200000:
			guard += 1
			for ev in fresh.advance(0.25):
				if int(ev.get("num", 0)) > 0 and str(ev.get("kind", "")) != "sub":
					seen += 1
					if fresh._actor_id(ev) >= 0:
						found += 1
	_check(drawn == 12 and named == drawn, "The named wings play the wings (%d of %d)" % [named, drawn])
	_check(starters_ok, "A replay opens with the players who started")
	_check(float(found) >= 0.95 * float(seen), "The player an event names is on the oval (%d of %d)" % [found, seen])


## A set shot is staged (the shooter steps back and the ground holds); a shot
## in open play is kicked on the move while forwards crumb and defenders chase.
func _test_open_play_shots(res: Dictionary) -> void:
	var set_k := -1
	var open_k := -1
	var tagged := true
	var evs: Array = res["events"]
	for i in range(evs.size()):
		var ev: Dictionary = evs[i]
		if not ["goal", "behind"].has(str(ev.get("kind", ""))):
			continue
		if not ev.has("set_shot"):
			tagged = false
		elif bool(ev["set_shot"]) and set_k < 0:
			set_k = i
		elif not bool(ev["set_shot"]) and open_k < 0:
			open_k = i
	_check(tagged, "Every score says whether it came from a set shot")
	_check(set_k >= 0 and open_k >= 0, "A match has set shots and open-play shots")
	if set_k < 0 or open_k < 0:
		return
	var d := MatchDirector.new()
	d.setup(res, evs)
	var staged := func(k: int) -> Dictionary:
		var ph: Array = d._shot_phases(k)
		var hold := 0.0
		var crumb := false
		for p in ph:
			if str(p["t"]) == "hold":
				hold = maxf(hold, float(p.get("dur", 0.0)))
			if str(p["t"]) == "crumb":
				crumb = true
		return {"hold": hold, "crumb": crumb}
	var a: Dictionary = staged.call(set_k)
	var b: Dictionary = staged.call(open_k)
	_check(a["hold"] > 0.3 and not a["crumb"], "A set shot is lined up")
	_check(b["hold"] == 0.0 and b["crumb"], "An open-play shot is kicked on the run, the play going on around it")


## Teams change ends every quarter: the home side attacks one end of the
## screen in the 1st and 3rd quarters and the other in the 2nd and 4th.
func _test_ends_swap(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(400, 700)
	pv.camera_enabled = false
	var ok := [true]
	var sides := {}
	pv.event_played.connect(func(ev):
		var q := int(ev.get("q", 0))
		if str(ev.get("kind", "")) == "quarter" or q < 1 or q > 4:
			return
		if pv.period != q:
			ok[0] = false
		# Which side of the screen the home side's goal (field +x) is on.
		var home_goal: Vector2 = pv._w2s(Vector2(MatchMotion.GOAL_X, 0.0))
		sides[q] = home_goal.x > pv.size.x * 0.5)
	pv.setup(res)
	pv.set_speed(8.0)
	pv.play()
	var guard := 0
	while pv.playing and guard < 200000:
		guard += 1
		pv._process(1.0 / 30.0)
	_check(ok[0], "The ground shows the quarter being played")
	_check(sides.size() == 4 and sides[1] and not sides[2] and sides[3] and not sides[4],
			"The home side kicks to one end in Q1 and Q3, the other in Q2 and Q4 (%s)" % str(sides))
	pv.setup(res)
	_check(pv.period == 1, "A new match starts at the first end again")
	pv.free()



## ARD-M1-005: no staged kick sails back towards the kicker's own goal. Every
## flight on screen is checked against where the side in possession attacks
## that quarter (ends change each quarter), with your club home and away.
func _test_no_wrong_way_kicks(res: Dictionary) -> void:
	var away := _sim(43, "SYD", "RIC").run()
	away["home"] = "SYD"
	away["away"] = "RIC"
	for r in [res, away]:
		var pv := PitchView.new()
		pv.size = Vector2(400, 700)
		pv.camera_enabled = false
		pv.setup(r)
		pv.playing = true
		var events: Array = pv.events
		var last := [Vector2.INF, Vector2.INF, -2]
		var flights := 0
		var wrong := 0
		var flipped := 0
		var period := 1
		var first_bad := ""
		var guard := 0
		while pv.playing and guard < 120000:
			guard += 1
			pv._process(1.0 / 15.0)
			var ball: Dictionary = pv.director.ball
			if str(ball.get("mode", "")) != "flight":
				continue
			var from: Vector2 = ball["from"]
			var to: Vector2 = ball["to"]
			# The same flight is the same beat too: two centre bounces either side
			# of a break both fly (0,0) to (0,0) and are not one ball in the air.
			var beat_k := int(pv.director._beat.get("k", -1))
			if from == last[0] and to == last[1] and beat_k == int(last[2]):
				if pv.period != period:
					flipped += 1   # the ends changed with the ball in the air
					period = pv.period
				continue
			last = [from, to, beat_k]
			period = pv.period
			flights += 1
			var k := int(pv.director._beat.get("k", -1))
			if k < 0:
				continue
			var ev: Dictionary = events[k]
			var pk := pv.director._prev_real(k)
			var kicker := int(ev.get("side", 0))
			if pk >= 0 and not (str(ev.get("kind", "")) in ["goal", "behind", "inside50"]):
				kicker = int((events[pk] as Dictionary).get("side", kicker))
			var attack := (1.0 if kicker == 0 else -1.0) * PitchView.end_sign(pv.period)
			var metres := (pv._w2s(to).x - pv._w2s(from).x) / pv._scale()
			if -metres * attack > 30.0:
				wrong += 1
				if first_bad == "":
					first_bad = "event %d (%s), period %d" % [k, str(ev.get("kind", "")), pv.period]
		pv.free()
		_check(flights > 500 and wrong == 0,
				"No kick flies 30 m+ back towards the kicker's own goal (%s: %d flights, %d wrong way %s)" % [
				str(r["home"]), flights, wrong, first_bad])
		_check(flipped == 0, "The ends never change with the ball in the air (%s)" % str(r["home"]))


## Playtest gate (roadmap 1.11): a watched match flows. No beat hangs (a
## freeze), and the ball is not left on the deck while a far-off receiver
## runs half the ground to it: a loose ball is scrapped for and knocked on.
func _test_match_flow(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(400, 700)
	pv.camera_enabled = false
	pv.setup(res)
	pv.set_speed(1.0)
	pv.playing = true
	var d = pv.director
	var h := 1.0 / 30.0
	var t := 0.0
	var far := 0.0
	var far_entry := 0.0
	var worst := 0.0
	var beat_k := -1
	var beat_t := 0.0
	var last: Vector2 = d.ball["pos"]
	var guard := 0
	while pv.playing and guard < 400000:
		guard += 1
		pv._process(h)
		t += h
		var pos: Vector2 = d.ball["pos"]
		var moving := pos.distance_to(last) > 0.05
		last = pos
		var ph: Dictionary = d._phases[d._pi] if d._pi < d._phases.size() else {}
		if str(ph.get("t", "")) == "collect" and not moving:
			var who := int(ph.get("who", -1))
			if who >= 0 and (d.tokens[who]["pos"] as Vector2).distance_to(pos) > 12.0:
				far += h
				var pk: int = d._prev_real(int(d._beat.get("k", 0)))
				if pk >= 0 and str((d.events[pk] as Dictionary).get("kind", "")) == "inside50":
					far_entry += h
		var k := int(d._beat.get("k", -1))
		if k != beat_k:
			worst = maxf(worst, beat_t)
			beat_k = k
			beat_t = 0.0
		beat_t += h
	pv.free()
	_check(worst <= 8.0, "No moment of a watched match hangs (longest beat %.1f s)" % worst)
	_check(far <= 0.12 * t, "The ball is rarely left waiting on a far-off receiver (%.0f s of %.0f)" % [far, t])
	# Playtest: after a forward-50 entry the rebounding defender used to run
	# 30 m to a ball landing among others. The entry now lands toward him and
	# he starts for it during the play before.
	_check(far_entry <= 0.012 * t, "An entry is not left waiting on a far-off rebounder (%.1f s of %.0f)" % [far_entry, t])


## ARD-M8-003 step 2: the match records its calls as it plays, without
## touching the dice, and the view puts the named players on each other.
func _test_tactical_timeline() -> void:
	var a := _sim(11)
	var b := _sim(11)
	var before := a.rng.state
	for i in range(3):
		a._note_tactics()
	_check(a.rng.state == before, "Recording the calls draws no dice")
	a.timeline.clear()
	a._timeline_last = ["", ""]
	_check(a.run()["events"] == b.run()["events"], "A match is the same with its calls recorded")
	var res := _result(42)
	var tl: Array = res.get("timeline", [])
	var starts := [false, false]
	for e in tl:
		if int(e["at"]) == 0:
			starts[int(e["side"])] = true
	_check(starts[0] and starts[1], "Both sides' calls are recorded from the first bounce")
	# A match-up changed at quarter time shows from the next quarter.
	var sim := _sim(5)
	sim.run_quarter()
	var duels: Dictionary = sim.duels[0]
	var fwd := ""
	var def := ""
	for fid in duels:
		for p in (sim.squads[0] as Squad).ground:
			if str(p.get("role", "")) == "DEF" and str(p["id"]) != str(duels[fid]) 					and str(p["id"]) != str(sim.interceptor[0]):
				fwd = str(fid)
				def = str(p["id"])
				break
		if fwd != "":
			break
	var cut := sim.events.size()
	_check(fwd != "" and sim.coach_matchup(0, fwd, def), "A defender can be moved onto a forward at the break")
	while sim.current_quarter <= 4:
		sim.run_quarter()
	var full := sim.result()
	full["home"] = "RIC"
	full["away"] = "SYD"
	var entry := {}
	for e in full["timeline"]:
		if int(e["side"]) == 0 and int(e["at"]) >= cut and str((e["duels"] as Dictionary).get(fwd, "")) == def:
			entry = e
			break
	_check(not entry.is_empty(), "The change is in the timeline, from the next quarter")
	if entry.is_empty():
		return
	var d := MatchDirector.new()
	d.setup(full, full["events"])
	var guard := 0
	while d.cursor <= int(entry["at"]) and not d.idle() and guard < 200000:
		guard += 1
		d.advance(1.0 / 15.0)
	var di := -1
	var fi := -1
	for t in d.tokens:
		if str(t["pid"]) == def:
			di = int(t["id"])
		elif str(t["pid"]) == fwd:
			fi = int(t["id"])
	_check(di >= 0 and fi >= 0 and int(d.tokens[di]["match"]) == fi and int(d.tokens[fi]["match"]) == di,
			"On the oval, the moved defender now stands on that forward")
	var loose := str((d._tac[0] as Dictionary).get("loose", ""))
	var named := 0
	for t in d.tokens:
		if int(t["side"]) == 0 and bool(t.get("loose", false)):
			named += 1
			_check(str(t["pid"]) == loose, "The loose man on the oval is the one the match named")
	_check(named == (1 if loose != "" else 0), "At most one loose man a side")


## Playtest freeze (near the boundary): a ball resting against the fence sat
## where the collector's run could never reach within touching distance, and
## collecting had no time limit, so play stopped. It now always completes.
func _test_boundary_collect(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(400, 700)
	pv.camera_enabled = false
	pv.setup(res)
	var d = pv.director
	var worst := 0.0
	var all_done := true
	for ang in [0.3, 1.2, 1.57, 2.4, 3.0, 4.4]:
		# The ball on the fence (as a loose ball can settle), the collector
		# well away, and team-mates crowding in beside the ball.
		var at := MatchMotion.clamp_to_oval(Vector2(cos(ang), sin(ang)) * 200.0, 1.0)
		d.ball["pos"] = at
		d.ball["mode"] = "dead"
		d.ball["holder"] = -1
		var who := 5
		d.tokens[who]["pos"] = at * 0.7
		for j in range(6, 9):
			d.tokens[j]["pos"] = at + Vector2(0.4 * j - 3.0, 0.3)
			MatchMotion.set_goal(d.tokens[j], at, 1.0, true)
		var p := {"t": "collect", "who": who, "roll": true}
		d._pt = 0.0
		var done := false
		for step in range(600):
			d._pt += 1.0 / 30.0
			for t in d.tokens:
				MatchMotion.step(t, 1.0 / 30.0)
			MatchMotion.separate(d.tokens)
			if d._done(p):
				done = true
				break
		worst = maxf(worst, d._pt)
		all_done = all_done and done
	pv.free()
	_check(all_done and worst <= MatchDirector.COLLECT_LIMIT + 0.1,
			"A ball against the fence is always collected, never a freeze (longest %.1f s)" % worst)


## A smother is released at the kick it blocks. Fixture log (no seed): after a
## centre kick, SYD 27 kicks to a spot and RIC 42 smothers it there, with the
## receiver a long way off. The kick used to roll the ball on toward its
## receiver, so the smother came out 15.8 m from its logged spot (seed 42,
## event 1322).
func _test_smother_at_the_kick(res: Dictionary) -> void:
	var worst := 0.0
	var released := true
	for fp in [-6.755, 25.0, -45.0]:
		var stamp := {"q": 4, "min": 117, "score": [70, 72], "goals": [10, 11], "behinds": [10, 6]}
		var kick := {"kind": "kick", "side": 1, "num": 27, "player_id": "SYD_27",
				"name": "Fixture Kicker", "club": "SYD", "fp": fp, "text": "Fixture Kicker kicks"}
		var smother := {"kind": "smother", "side": 0, "num": 42, "player_id": "RIC_42",
				"name": "Fixture Smotherer", "club": "RIC", "fp": fp, "text": "Fixture Smotherer smothers the kick"}
		var bounce := {"kind": "kick", "side": 1, "num": 4, "player_id": "SYD_4",
				"name": "Fixture Ruck", "club": "SYD", "fp": 0.0, "text": "Fixture Ruck kicks"}
		bounce.merge(stamp)
		kick.merge(stamp)
		smother.merge(stamp)
		var events := [bounce, kick, smother]
		var d := MatchDirector.new()
		d.setup(res, events)
		var guard := 0
		while not d.idle() and guard < 20000:
			guard += 1
			d.advance(1.0 / 30.0)
		released = released and d.arrivals.size() == 3
		for a in d.arrivals:
			worst = maxf(worst, absf((a["pos"] as Vector2).x - float(a["want_x"])))
	_check(released, "The kick and its smother are both released")
	_check(worst < 5.0, "A smother is released at the kick it blocks (worst %.1f m)" % worst)


## Research truth fixes (ARD-M8-003 step 1): a handball is drawn as a
## handball, a bobbling ball never steers toward its collector, and the ball is
## not left waiting long on a receiver.
func _test_truth(res: Dictionary) -> Array:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var h := 1.0 / 30.0
	var hb_total := 0
	var hb_as_kick := 0
	var hb_dists := []
	var steer := 0
	var roll_ticks := 0
	var last_vel := Vector2.ZERO
	var last_pos: Vector2 = d.ball["pos"]
	var last_from := Vector2.INF
	var collect_t := {}
	var snaps := 0
	var takes := 0
	var prev_mode := str(d.ball["mode"])
	var guard := 0
	while not d.idle() and guard < 400000:
		guard += 1
		d.advance(h)
		var mode := str(d.ball["mode"])
		var pos: Vector2 = d.ball["pos"]
		if mode == "flight" and (d.ball["from"] as Vector2) != last_from:
			last_from = d.ball["from"]
			var k := int(d._beat.get("k", -1))
			var pk: int = d._prev_real(k) if k >= 0 else -1
			if pk >= 0 and str((d.events[pk] as Dictionary).get("kind", "")) == "handball" 					and MatchDirector.DISPOSALS.has(str((d.events[k] as Dictionary).get("kind", ""))) 					and d._restart(k) == "open":
				hb_total += 1
				var dist := (d.ball["from"] as Vector2).distance_to(d.ball["to"])
				hb_dists.append(dist)
				if float(d.ball["apex"]) >= 2.5:
					hb_as_kick += 1
		# A ball on the ground runs straight: its heading changes only when it
		# is pushed afresh (a knock, a bobble) or slides along the fence, never
		# by bending toward a player.
		if mode == "roll_to":
			roll_ticks += 1
		if mode == "loose" and prev_mode == "loose":
			var v: Vector2 = d.ball["vel"]
			var pushed := v.distance_to(last_vel * exp(-3.0 * h * MatchDirector.TEMPO)) > 0.05 * maxf(1.0, v.length())
			var fence := not MatchMotion.inside_oval(pos, 2.0)
			if not pushed and not fence and v.length() > 0.5 and last_vel.length() > 0.5 					and absf(v.angle_to(last_vel)) > 0.05:
				steer += 1
		last_vel = d.ball["vel"] if d.ball.has("vel") else Vector2.ZERO
		if mode == "held" and prev_mode != "held":
			takes += 1
			var holder: Dictionary = d.tokens[int(d.ball["holder"])]
			if last_pos.distance_to(holder["pos"]) > 3.0:
				snaps += 1
		var ph: Dictionary = d._phases[d._pi] if d._pi < d._phases.size() else {}
		if str(ph.get("t", "")) == "collect" and ph.has("roll"):
			var key := "%d:%d" % [int(d._beat.get("k", -1)), d._pi]
			collect_t[key] = float(collect_t.get(key, 0.0)) + h * MatchDirector.TEMPO
		last_pos = pos
		prev_mode = mode
	var long2 := 0
	var long4 := 0
	var worst := 0.0
	for key in collect_t:
		var t := float(collect_t[key])
		worst = maxf(worst, t)
		if t > 2.0:
			long2 += 1
		if t > 4.0:
			long4 += 1
	hb_dists.sort()
	var med := float(hb_dists[hb_dists.size() / 2]) if not hb_dists.is_empty() else 0.0
	var p90 := float(hb_dists[int(hb_dists.size() * 0.9)]) if not hb_dists.is_empty() else 0.0
	print("TRUTH handballs %d, drawn as kicks %d, median %.1f m, p90 %.1f m" % [hb_total, hb_as_kick, med, p90])
	print("TRUTH homing ticks %d, unpushed turns %d" % [roll_ticks, steer])
	print("TRUTH collects %d, over 2 s %d, over 4 s %d, longest %.1f s; snaps into hands %d" % [collect_t.size(), long2, long4, worst, snaps])
	_check(roll_ticks == 0 and steer == 0,
			"A ball on the ground never bends toward a player (%d homing ticks, %d turns without a push)" % [roll_ticks, steer])
	# Sim-sensitive, so a share and the hard cap, not an exact count.
	_check(long4 * 40 <= collect_t.size() and worst <= MatchDirector.COLLECT_LIMIT + 0.1,
			"The ball is rarely left waiting on its collector (%d of %d over 4 s, longest %.1f s)" % [long4, collect_t.size(), worst])
	# A share too: any sim change redraws the seeded match.
	_check(snaps * 40 <= takes, "The ball rarely jumps into a player's hands (%d of %d takes from more than 3 m)" % [snaps, takes])
	return [hb_total, hb_as_kick]


## The two tail checks, over four fixed seeds (42 and 1-3) rather than one:
## one match is a coin flip at a tail.
##  - A release is never far from its logged spot (under 15 m) on every seed.
##  - A handball is drawn as a handball: pooled over the seeds at most 2% are
##    drawn as kicks, no seed over 3%, each with over 100 handballs.
## Why 3% a seed and not 2%: a match has about 240 handballs and the true rate
## of drawing one as a kick is about 0.7% (1.7 expected). Five or more is a
## 3% chance, so a 2% bar per match fails at random on a healthy build (seed 42
## did, at 5 of 241, with the rate unchanged: 48 paired seeds showed no shift).
## Eight or more (3%) is about 0.04%, so a real fault still trips the cap, and
## pooled over about 1000 handballs the 2% bar is much stricter than the old
## single-match one. Do not tighten the per-seed cap back to 2%.
func _test_tail_seeds(truth_hb: Array) -> void:
	var hb_total := int(truth_hb[0])
	var hb_kick := int(truth_hb[1])
	var worst_all := 0.0
	var worst_share := float(hb_kick) / maxf(1.0, float(hb_total))
	var all_over_100 := hb_total > 100
	for seed in [1, 2, 3]:
		var res := _result(seed)
		worst_all = maxf(worst_all, _worst_release(res))
		var hb := _handball_counts(res)
		hb_total += hb[0]
		hb_kick += hb[1]
		worst_share = maxf(worst_share, float(hb[1]) / maxf(1.0, float(hb[0])))
		all_over_100 = all_over_100 and hb[0] > 100
	_check(worst_all < 15.0, "No release far from the logged spot on seeds 1-3 either (worst %.1f m)" % worst_all)
	_check(all_over_100 and hb_kick <= hb_total / 50,
			"A handball is drawn as a handball over four seeds (%d of %d drawn as kicks)" % [hb_kick, hb_total])
	_check(worst_share <= 0.03, "No seed draws over 3%% of its handballs as kicks (worst %.1f%%)" % (worst_share * 100.0))


func _worst_release(res: Dictionary) -> float:
	var played := _play(res, res["events"], 1.0 / 60.0 * 4.0, false)
	var worst := 0.0
	for a in (played["director"] as MatchDirector).arrivals:
		worst = maxf(worst, absf((a["pos"] as Vector2).x - float(a["want_x"])))
	return worst


## Handballs of a match, and how many are drawn as kicks (a high arc), counted
## the way _test_truth counts them.
func _handball_counts(res: Dictionary) -> Array:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var hb_total := 0
	var hb_kick := 0
	var last_from := Vector2.INF
	var guard := 0
	while not d.idle() and guard < 400000:
		guard += 1
		d.advance(1.0 / 30.0)
		if str(d.ball["mode"]) == "flight" and (d.ball["from"] as Vector2) != last_from:
			last_from = d.ball["from"]
			var k := int(d._beat.get("k", -1))
			var pk: int = d._prev_real(k) if k >= 0 else -1
			if pk >= 0 and str((d.events[pk] as Dictionary).get("kind", "")) == "handball" 					and MatchDirector.DISPOSALS.has(str((d.events[k] as Dictionary).get("kind", ""))) 					and d._restart(k) == "open":
				hb_total += 1
				if float(d.ball["apex"]) >= 2.5:
					hb_kick += 1
	return [hb_total, hb_kick]


## Playtest freeze (mid play, live): resuming after a moment with no new
## events to show left the view idle without saying so, so the next moment
## card never came. play() on an idle view now reports finished.
func _test_play_when_idle(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.setup(res)
	pv.director.flush()
	var got := [false]
	pv.finished.connect(func(): got[0] = true)
	pv.play()
	_check(got[0] and not pv.playing, "Resuming with nothing new to show still hands back to the match screen")
	pv.free()


## Every club's numbers read on its own token: the number sits on the inner
## (secondary) disc, so it must contrast with that, not the outer ring.
func _test_numbers_readable() -> void:
	var pv := PitchView.new()
	var bad := []
	for code in GameDB.active_clubs(2027):
		var cols: Array = GameDB.club_colours(str(code))
		var disc: Color = cols[1]
		var num: Color = pv._readable_on(disc)
		var lum := func(c: Color) -> float: return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
		if absf(float(lum.call(disc)) - float(lum.call(num))) < 0.35:
			bad.append(str(code))
	_check(bad.is_empty(), "Every club's player numbers stand out on the token (%s)" % ", ".join(bad))
	pv.free()


## Your people on the oval: every token knows its player, a substitute takes the
## ring and the name with the slot, MatchRings picks the calls and the runs
## (yours only, capped), and the view names a scorer, and a ringed player with
## the ball, for a moment in real seconds. All of it presentation: nothing
## here writes to the match.
func _test_oval_people(res: Dictionary) -> void:
	var before: Array = (res["events"] as Array).duplicate(true)
	# Tokens carry the player, and a surname that fits a caption.
	var played := _play(res, res["events"], 1.0 / 15.0, false)
	var d: MatchDirector = played["director"]
	var by_num := [{}, {}]
	for side in range(2):
		for r in (res["roster"] as Array)[side]:
			(by_num[side] as Dictionary)[int(r["num"])] = str(r["id"])
	var who_ok := not d.tokens.is_empty()
	var swapped_ok := true
	for t in d.tokens:
		var sn := str(t.get("surname", ""))
		if str(t.get("pid", "")) == "" or sn == "" or sn.length() > 10:
			who_ok = false
		# After every interchange, the token is the player on now.
		if str((by_num[int(t["side"])] as Dictionary).get(int(t["num"]), "")) != str(t["pid"]):
			swapped_ok = false
	_check(who_ok, "Every token carries its player's id and a surname that fits a caption")
	var subs := 0
	for ev in res["events"]:
		if str(ev.get("kind", "")) == "sub":
			subs += 1
	_check(subs > 0 and swapped_ok, "A substitute takes the ring and the name with the slot (%d interchanges)" % subs)
	_check(GameDB.player_surname({"name": "Ari Bramble"}) == "Bramble"
			and GameDB.player_surname({"name": "Jack Papaioannou"}) == "Papaioann."
			and GameDB.player_surname({"name": ""}) == "Player",
			"A surname is the last word, and a long one is cut")

	# The ring: the runs, then the calls, yours only, no repeats, capped.
	var sim := _sim(7)
	var me := 0
	var mine: Array = (sim.squads[me] as Squad).ground
	var theirs: Array = (sim.squads[1] as Squad).ground
	var their_mid := {}
	var their_fwds := []
	for p in theirs:
		if their_mid.is_empty() and str(p["role"]) == "MID":
			their_mid = p
		if str(p["role"]) == "FWD":
			their_fwds.append(p)
	var defenders: Array = Matchups.defenders(mine)
	# A forward, so he is none of the defenders below nor the midfielder who tags.
	var focus := {}
	for p in mine:
		if focus.is_empty() and str(p["role"]) == "FWD":
			focus = p
	var on_sim := {}
	for p in mine + (sim.squads[me] as Squad).bench:
		on_sim[str(p["id"])] = true
	var list := []
	for p in GameDB.club_list("RIC"):
		list.append((p as Dictionary).duplicate(true))
	var tagger_id := str(MatchSim.tagger_for(mine)["id"])
	sim.set_tactics(me, {"gameplan": "balanced", "focus_id": str(focus["id"]),
			"tag_id": str(their_mid["id"]), "pep": "steady"})
	# The sim sets up its own match-ups; those are not your calls, so not ringed.
	_check(MatchRings.ids(sim, me, list) == [str(focus["id"]), tagger_id],
			"With a play-through and a tag, the player and the tagger are ringed, not the default match-ups (%s)" % str(MatchRings.ids(sim, me, list)))
	_check(sim.set_interceptor(me, str(defenders[0]["id"]), false)
			and sim.set_matchup(me, str(their_fwds[0]["id"]), str(defenders[1]["id"]), false),
			"A spare and a match-up are set on the sim")
	var kid := {}
	for p in list:
		if not on_sim.has(str(p["id"])):
			kid = p
			break
	Backing.start(kid, 2027, 1, 0)
	var picks := {str(their_fwds[0]["id"]): str(defenders[1]["id"])}
	var ids := MatchRings.ids(sim, me, list, picks)
	_check(ids == [str(kid["id"]), str(focus["id"]), tagger_id, str(defenders[0]["id"]), str(defenders[1]["id"])],
			"A run comes first, then the calls: play-through, tagger, spare, match-up (%s)" % str(ids))
	# A defender not already on that forward, so it is a change (the sim records
	# only a real one).
	var on_him := str((sim.duels[me] as Dictionary).get(str(their_fwds[1]["id"]), ""))
	var switched := {}
	for p in defenders:
		var pid := str(p["id"])
		if switched.is_empty() and pid != on_him and pid != str(defenders[0]["id"]) \
				and pid != str(defenders[1]["id"]):
			switched = p
	var changed := sim.set_matchup(me, str(their_fwds[1]["id"]), str(switched["id"]), true)
	ids = MatchRings.ids(sim, me, list, picks)
	_check(changed and ids.has(str(switched["id"])) and ids.size() == 6,
			"A match-up changed during the match is ringed too (%s)" % str(ids))
	var theirs_ids := {}
	for p in (sim.squads[1] as Squad).ground + (sim.squads[1] as Squad).bench:
		theirs_ids[str(p["id"])] = true
	var only_mine := true
	for id in ids:
		if theirs_ids.has(str(id)):
			only_mine = false
	_check(only_mine, "Only your own players are ringed, never the man you tag or the forward you match up")
	(sim.tactics[me] as Dictionary)["focus_id"] = str(defenders[0]["id"])
	_check(MatchRings.ids(sim, me, list).count(str(defenders[0]["id"])) == 1,
			"A player with two calls on him is ringed once")
	for i in range(12):
		Backing.start(list[i], 2027, 1, 0)
	var capped := MatchRings.ids(sim, me, list)
	_check(capped.size() == MatchRings.MAX, "The most rings on the oval is %d" % MatchRings.MAX)

	# The view: rings, a scorer's name, a ringed player's name.
	var pv := PitchView.new()
	pv.size = Vector2(800, 600)
	pv.setup(res)
	var tok: Dictionary = pv.director.tokens[3]
	pv.set_rings([tok["pid"]])
	_check(pv.ringed(str(tok["pid"])) and not pv.ringed("nobody"), "The view rings the players it is given")
	pv.set_rings([])
	_check(not pv.ringed(str(tok["pid"])), "Clearing the rings clears them")
	var named := [""]
	var scorer := [""]
	pv.event_played.connect(func(ev):
		if str(ev.get("kind", "")) == "goal" and scorer[0] == "":
			var k: int = pv.director.token_of(ev)
			scorer[0] = str(pv.director.tokens[k]["surname"]) if k >= 0 else "?"
			named[0] = pv.caption_text())
	pv.set_speed(8.0)
	pv.play()
	var guard := 0
	while scorer[0] == "" and guard < 60000:
		guard += 1
		pv._process(1.0 / 60.0)
	_check(scorer[0] != "" and named[0] == scorer[0],
			"A goal names its scorer on the oval (%s)" % named[0])
	pv.pause()
	for i in range(20):
		pv._process(0.05)
	_check(pv.caption_text() == scorer[0], "The name is still there a second later, whatever the playback speed")
	for i in range(20):
		pv._process(0.05)
	_check(pv.caption_text() == "", "The name goes after a couple of seconds")
	# A ringed player who gets the ball is named, and a goal's name outranks it.
	var pv2 := PitchView.new()
	pv2.size = Vector2(800, 600)
	pv2.setup(res)
	var a: Dictionary = pv2.director.tokens[5]
	var b: Dictionary = pv2.director.tokens[6]
	pv2.set_rings([a["pid"]])
	pv2.director.actor = int(b["id"])
	pv2._process(0.0)
	_check(pv2.caption_text() == "", "A player with no ring is not named when he has the ball")
	pv2.director.actor = int(a["id"])
	pv2._process(0.0)
	_check(pv2.caption_text() == str(a["surname"]), "A ringed player is named when he has the ball")
	pv2.director.actor = int(b["id"])
	pv2._process(0.5)
	_check(pv2.caption_text() == str(a["surname"]), "His name stays long enough to read after the ball moves on")
	# A change of possession in open play says "Turnover" over the winner; a
	# restart (a ball-up) between the two sides' possessions does not.
	var pv3 := PitchView.new()
	pv3.size = Vector2(800, 600)
	pv3.setup(res)
	var home := -1
	var away := -1
	for t in pv3.director.tokens:
		if int(t["side"]) == 0 and home < 0:
			home = int(t["num"])
		if int(t["side"]) == 1 and away < 0:
			away = int(t["num"])
	pv3._cue_turnover({"kind": "kick", "side": 0, "num": home})
	_check(pv3.caption_text() == "", "The first possession of a passage is not a turnover")
	pv3._cue_turnover({"kind": "handball", "side": 1, "num": away})
	_check(pv3.caption_text() == "Turnover", "The other side winning it in play says Turnover")
	for i in range(30):
		pv3._process(0.05)
	_check(pv3.caption_text() == "", "The word goes after a second or so")
	pv3._cue_turnover({"kind": "ballup", "side": -1})
	pv3._cue_turnover({"kind": "kick", "side": 0, "num": home})
	_check(pv3.caption_text() == "", "Winning a ball-up is not a turnover")
	pv3._cue_turnover({"kind": "tackle", "side": 1, "num": away})
	_check(pv3.caption_text() == "", "A tackle alone is not a turnover")
	pv3._cue_turnover({"kind": "pressure", "side": 1, "num": away})
	_check(pv3.caption_text() == "Turnover", "A forced turnover always says so")
	_check(not pv3.shaking(), "A turnover is an ordinary event: no shake")
	# The club banner's light (UiKit.drift) is smooth: a pure function of time, monotone,
	# near-constant change per unit time, the same position at 30 and 60 fps.
	for fps in [30.0, 60.0]:
		var prev := 0.0
		var prev_step := -1.0
		var smooth := true
		var mono := true
		for f in range(1, 61):
			var v := UiKit.drift_at(float(f) / fps, 12.0)
			var step := v - prev
			if step < 0.0:
				mono = false
			if prev_step > 0.0 and absf(step - prev_step) > prev_step * 0.05:
				smooth = false
			prev = v
			prev_step = step
		_check(mono and smooth, "The banner light moves monotonically and smoothly across 60 frames at %d fps" % int(fps))
	_check(is_equal_approx(UiKit.drift_at(1.0, 12.0), UiKit.drift_at(30.0 / 30.0, 12.0)),
			"The light's place depends on time, not on the frame rate")
	# A layout refresh mid-sweep does not reset it.
	var duel := ClubDuel.new().setup("COL", "CAR")
	duel.size = Vector2(390, 120)
	duel._settle = 0.5
	duel.resized.emit()
	duel.size = Vector2(380, 120)
	_check(is_equal_approx(duel._settle, 0.5), "A layout refresh mid-sweep leaves the light where it is")
	duel.free()
	# The goal shake: the only one. Capped at a share of the oval's height at any screen
	# size (about 4 px on a phone), replaced and not stacked, and zero with it off.
	var was := GameState.screen_shake_on()
	GameState.set_screen_shake_on(true)
	for sz in [Vector2(390, 844), Vector2(1920, 1080)]:
		var pv4 := PitchView.new()
		pv4.size = sz
		pv4.setup(res)
		var sc := -1
		for t in pv4.director.tokens:
			if sc < 0:
				sc = int(t["num"])
		var cap := minf(pv4.pitch_rect().size.y * PitchView.SHAKE_SHARE, PitchView.SHAKE_MAX_PX)
		var worst := 0.0
		pv4._name_the_scorer({"kind": "goal", "side": 0, "num": sc})
		pv4._name_the_scorer({"kind": "goal", "side": 0, "num": sc})
		_check(pv4.shaking(), "A goal shakes the oval at %s" % [sz])
		for i in range(200):
			worst = maxf(worst, pv4.shake_offset().length())
			pv4._shake = maxf(0.0, pv4._shake - 0.001)
		_check(worst <= cap + 0.001 and worst > 0.0, "Shake offset %.2f px stays within the cap %.2f at %s" % [worst, cap, sz])
		_check(PitchView.SHAKE_TIME <= 0.2, "The shake lasts under a fifth of a second")
		if sz.x < 500:
			_check(cap <= 4.5, "On a phone the cap is about 4 px (%.2f)" % cap)
		else:
			_check(cap <= 4.0, "On a big monitor the cap stays small (%.2f)" % cap)
		pv4._shake = PitchView.SHAKE_TIME
		GameState.set_screen_shake_on(false)
		pv4._name_the_scorer({"kind": "goal", "side": 0, "num": sc})
		_check(pv4.shake_offset() == Vector2.ZERO, "With Screen shake off the offset is zero at %s" % [sz])
		GameState.set_screen_shake_on(true)
	GameState.set_screen_shake_on(false)
	pv3._cue_turnover({"kind": "rebound", "side": 0, "num": home})
	_check(pv3.caption_text() == "Turnover" and not pv3.shaking(), "With it off, the label shows and the screen stays still")
	GameState.set_screen_shake_on(was)
	pv2._process(0.6)
	_check(pv2.caption_text() == "", "...and goes")
	pv2._name_the_scorer({"kind": "goal", "side": int(b["side"]), "num": int(b["num"])})
	pv2.director.actor = int(a["id"])
	pv2._process(0.0)
	_check(pv2.caption_text() == str(b["surname"]), "A goal's name outranks a touch")
	pv.free()
	pv2.free()
	_check(res["events"] == before, "Rings and names never write to an event")



## The dramatic close-ups are chosen from the presentation facts already in
## the log. They never roll their own football outcome, and every sequence is
## short enough to stay a beat rather than become a cutscene.
func _test_broadcast_vignettes() -> void:
	var final := {"kind": "final"}
	var close_set := {
		"kind": "goal", "side": 0, "q": 4, "set_shot": true,
		"goals": [10, 9], "behinds": [5, 4], "num": 10,
	}
	var ordinary_snap := {
		"kind": "goal", "side": 0, "q": 3, "set_shot": false,
		"goals": [8, 7], "behinds": [6, 8], "num": 23,
	}
	var mark := {"kind": "mark", "side": 0, "q": 2, "num": 4, "speccy": true}
	var ordinary_mark := {"kind": "mark", "side": 0, "q": 2, "num": 5, "speccy": false}
	var front := {"actor_pos": Vector2(10, 2), "ball_pos": Vector2(10, 2), "nearby": 4}
	var flank := {"actor_pos": Vector2(18, 31), "ball_pos": Vector2(18, 31), "nearby": 4}
	var defensive := {"actor_pos": Vector2(-32, 4), "ball_pos": Vector2(-32, 4), "nearby": 4}
	var boundary := {"actor_pos": Vector2(50, 38), "ball_pos": Vector2(83, 18), "nearby": 2}
	var line := {"actor_pos": Vector2(62, 4), "ball_pos": Vector2(85, 3), "nearby": 4}

	_check(BroadcastVignette.pick_kind(close_set, {}, final, front) == BroadcastVignette.AFTER_SIREN,
			"A close final set shot gets the final-kick broadcast scene")
	var easy_set := close_set.duplicate(true)
	easy_set["goals"] = [15, 9]
	_check(BroadcastVignette.pick_kind(easy_set, {}, final, front) != BroadcastVignette.AFTER_SIREN,
			"A comfortable final set shot is not dressed up as a dramatic final kick")
	_check(BroadcastVignette.pick_kind(ordinary_mark, {}, {}, front) == "",
			"An ordinary crowded mark is not silently promoted to a speccy")
	_check(BroadcastVignette.pick_kind(mark, {}, {}, front) == BroadcastVignette.SPECCY_FRONT,
			"A real speccy through the corridor gets the front-on speccy shot")
	# The front-on shot is behind the "speccy_front" switch (director, 2026-10-14): off (the default) a speccy plays
	# the earlier shot and runs as long as it did; on it is the low, tight staging frozen on the grab.
	Features.clear("speccy_front")
	_check(not BroadcastVignette._sf_ready() and is_equal_approx(BroadcastVignette.duration_for(BroadcastVignette.SPECCY_FRONT), 3.8),
			"With the speccy_front switch off a speccy plays the earlier shot, 3.8 s")
	Features.set_on("speccy_front", true)
	_check(BroadcastVignette._sf_ready(), "With the switch on the sheets hold the front-on speccy moves (the low, tight staging)")
	_check(BroadcastVignette.duration_for(BroadcastVignette.SPECCY_FRONT) > BroadcastVignette.SF_FREEZE,
			"On, the front-on speccy runs past the grab, so the still holds on it")
	var vig_on := BroadcastVignette.new()
	vig_on.setup(BroadcastVignette.SPECCY_FRONT, {"kind": "mark", "side": 0, "num": 4, "speccy": true}, {}, {"home": "FRE", "away": "MEL"})
	var on_figures := vig_on._sf_ready()
	vig_on.free()
	Features.clear("speccy_front")
	var vig_off := BroadcastVignette.new()
	vig_off.setup(BroadcastVignette.SPECCY_FRONT, {"kind": "mark", "side": 0, "num": 4, "speccy": true}, {}, {"home": "FRE", "away": "MEL"})
	var off_figures := vig_off._sf_ready()
	vig_off.free()
	_check(on_figures and not off_figures, "The same speccy event draws the new shot with the switch on and the earlier one with it off")
	_check(BroadcastVignette.pick_kind(mark, {}, {}, flank) == BroadcastVignette.SPECCY_SIDE,
			"A crowded mark near the flank gets the side-sit speccy shot")
	_check(BroadcastVignette.pick_kind(mark, {}, {}, defensive) == BroadcastVignette.SPECCY_DEFENSIVE,
			"A crowded mark running back in defence gets the defensive-mark shot")
	_check(BroadcastVignette.pick_kind(ordinary_snap, {}, {}, boundary) == BroadcastVignette.BOUNDARY_SNAP,
			"An open-play score from the pocket gets the boundary-snap shot")
	_check(BroadcastVignette.pick_kind(ordinary_snap, {}, {}, line) == "",
			"A snap from 23 metres is not a goal-line scramble, however crowded the goal square")
	var crumb := ordinary_snap.duplicate(true)
	crumb["crumb"] = true
	_check(BroadcastVignette.pick_kind(crumb, {}, {}, line) == BroadcastVignette.GOAL_LINE,
			"A crumb off a spoil gets the goal-line scramble")
	var crumb_behind := crumb.duplicate(true)
	crumb_behind["kind"] = "behind"
	_check(BroadcastVignette.pick_kind(crumb_behind, {}, {}, line) == BroadcastVignette.GOAL_LINE,
			"A crumb that misses gets the same scene")
	_check(BroadcastVignette.category(BroadcastVignette.SPECCY_FRONT)
			== BroadcastVignette.category(BroadcastVignette.SPECCY_SIDE),
			"Speccy variations share one frequency category")

	var quotas := []
	var quota_total := 0
	for i in range(200):
		var q := MatchSim.speccy_quota(8100 + i)
		quotas.append(q)
		quota_total += q
	var mean := float(quota_total) / float(quotas.size())
	_check(quotas.min() >= 0 and quotas.max() <= 2,
			"MatchSim hard-caps speccies at two in every match")
	_check(mean >= 0.65 and mean <= 0.95,
			"The deterministic MatchSim allowance averages about 0.8 per match (%.2f)" % mean)

	var all := [
		BroadcastVignette.SPECCY_FRONT, BroadcastVignette.SPECCY_SIDE,
		BroadcastVignette.SPECCY_DEFENSIVE, BroadcastVignette.AFTER_SIREN,
		BroadcastVignette.GOAL_LINE, BroadcastVignette.BOUNDARY_SNAP,
	]
	var short := true
	for kind in all:
		short = short and BroadcastVignette.duration_for(kind) <= 6.0
	_check(short, "Every broadcast vignette stays under six seconds")

	seed(271828)
	var expect := [randi(), randi(), randi()]
	seed(271828)
	BroadcastVignette.pick_kind(mark, {}, {}, front)
	BroadcastVignette.pick_kind(ordinary_snap, {}, {}, line)
	var got := [randi(), randi(), randi()]
	_check(got == expect, "Vignette selection draws nothing from the match/global RNG")

	# The close-ups are drawn with the pre-rendered figures (ARD-M8-007), not
	# silhouettes: the sheet holds every move they play, from the side they play it.
	var moves := {"idle": ["front", "back"], "jog": ["back_r"], "leap": ["front", "back"],
			"kick": ["back_r"], "snap": ["back_r"], "gather": ["back_r"], "lunge": ["side_l"]}
	var sheet_ok := true
	for anim in moves:
		for facing in moves[anim]:
			var strip: Dictionary = ((VignetteFigures.BODIES["average"]["anims"] as Dictionary).get(anim, {}) \
					as Dictionary).get(facing, {})
			sheet_ok = sheet_ok and int(strip.get("frames", 0)) > 0
	_check(sheet_ok, "The figure sheet holds every move the broadcast close-ups play")
	# Small men are drawn small: a crumber is a small forward, from his real height.
	var small_ok := BroadcastVignette.build_for({"height_cm": 178.0}) == "small" 			and BroadcastVignette.build_for({"height_cm": 190.0}) == "average" 			and BroadcastVignette.build_for({}) == "average"
	for anim in ["ready", "jog", "gather", "snap", "kick"]:
		small_ok = small_ok and VignetteFigures.has("small", anim, "back_r" if anim in ["gather", "snap", "kick", "jog"] else "back")
	_check(small_ok, "Small players are drawn on the small build, which holds the crumb and snap")
	# Both clubs wear their own guernseys; the featured player wears his own look.
	var star: Dictionary = GameDB.club_list("COL")[0]
	var vig := BroadcastVignette.new()
	vig.setup(BroadcastVignette.GOAL_LINE, {"kind": "goal", "side": 0, "crumb": true,
			"num": int(star["num"]), "player_id": str(star["id"])}, {}, {"home": "COL", "away": "CAR"})
	var bases: Array = (vig.material as ShaderMaterial).get_shader_parameter("kit_base")
	_check(bases.size() == 4 and bases[0] == GameDB.club_guernsey("COL")["base"]
			and bases[1] == GameDB.club_guernsey("CAR")["base"]
			and vig.get("_look") == GameDB.figure_look(star),
			"A broadcast close-up dresses both clubs and shows the featured player's own look")
	vig.free()


## A live score is painted in a club's own colour only where it can be read.
## Sydney's black accent on the dark panel was invisible (1.00:1).
func _test_score_colour() -> void:
	var was: String = UiKit.appearance()
	var unreadable: Array = []
	for mode in ["dark", "light"]:
		UiKit.apply_appearance(mode)
		for code in GameDB.club_order:
			if UiKit.contrast(UiKit.score_colour(str(code)), UiKit.PANEL) < 4.5:
				unreadable.append("%s (%s)" % [code, mode])
	# Collected and checked once: a floor counts rules, not data.
	_check(unreadable.is_empty(), "Every club's live score reads at 4.5:1 on the panel, in both appearances (%s)" % ", ".join(unreadable))
	UiKit.apply_appearance("dark")
	var syd: Color = UiKit.score_colour("SYD")
	_check(syd != (GameDB.club_colours("SYD") as Array)[2], "Sydney's black accent is not used for its score on the dark panel")
	var legible: String = ""
	for code in GameDB.club_order:
		var cols: Array = GameDB.club_colours(str(code))
		if UiKit.contrast(cols[2], UiKit.PANEL) >= 4.5:
			legible = str(code)
			break
	_check(legible != "" and UiKit.score_colour(legible) == (GameDB.club_colours(legible) as Array)[2],
			"A club whose accent reads keeps its own colour for its score")
	UiKit.apply_appearance(was)


## ARD-M4-013: the three set-shot calls are three visibly different
## sequences, staged only from the players the log names.
func _test_set_shot_calls() -> void:
	var played_all := true
	var pass_ok := 0
	var pass_seen := 0
	var pack_ok := 0
	var pack_seen := 0
	var outcomes := {}
	for key in ["pass", "bomb"]:
		var res := _set_call_match(String(key))
		if res.is_empty():
			played_all = false
			continue
		var evs: Array = res["events"]
		var d := MatchDirector.new()
		d.setup(res, evs)
		for k in range(evs.size()):
			var ev: Dictionary = evs[k]
			var kind := str(ev.get("kind", ""))
			if kind == "pass":
				pass_seen += 1
				var nk := d._next_real(k)
				var want := d._actor_id(evs[nk]) if nk >= 0 else -1
				for ph in d._pass_phases(k):
					if str(ph["t"]) == "flight" and int(ph.get("recv", -1)) == want and want >= 0:
						pass_ok += 1
			elif kind == "pack":
				pack_seen += 1
				var out := str(ev.get("outcome", ""))
				outcomes[out] = true
				var phs: Array = d._pack_phases(k)
				var members := []
				var recv := -2
				for ph in phs:
					if str(ph["t"]) == "pack":
						members = ph["members"]
					if str(ph["t"]) == "flight":
						recv = int(ph.get("recv", -1))
				var good := members.size() >= 4
				for id_key in ["marker_id", "spoiler_id", "defender_id"]:
					var tk := d._token_by_pid(str(ev.get(id_key, "")))
					if tk >= 0 and not members.has(tk):
						good = false
				if out == "marked":
					good = good and recv == d._token_by_pid(str(ev.get("marker_id", "")))
				if good:
					pack_ok += 1
		var played := _play(res, evs, 1.0 / 60.0 * 4.0, false)
		if played["stalled"] or (played["out"] as Array).size() != evs.size():
			played_all = false
	_check(pass_seen > 0 and pass_ok == pass_seen,
			"Playing on is a kick to the teammate leading up, or to the man who cuts it off (%d of %d)" % [pass_ok, pass_seen])
	_check(pack_seen > 0 and pack_ok == pack_seen and outcomes.size() >= 2,
			"A bomb goes up into a pack of the players the log names, and ends as logged (%d of %d, %s)" % [
					pack_ok, pack_seen, str(outcomes.keys())])
	_check(played_all, "Matches with every set-shot call play through to the end")


## A live match where the home coach makes `key` at every set shot offered.
func _set_call_match(key: String) -> Dictionary:
	for i in range(40):
		var sim := _sim(600 + i)
		sim.moment_side = 0
		var picked := 0
		var guard := 0
		while sim.current_quarter <= 4 and guard < 8:
			guard += 1
			sim.begin_quarter()
			while not sim.continue_quarter():
				var m := sim.pending_moment
				var c := int(m.get("default", 0))
				if str(m["kind"]) == "set_shot":
					var opts: Array = m["options"]
					for j in range(opts.size()):
						if str((opts[j] as Dictionary).get("key", "")) == key:
							c = j
							picked += 1
				sim.resolve_moment(c)
			sim.end_quarter()
		if picked >= 3:
			var res := sim.result()
			res["home"] = "RIC"
			res["away"] = "SYD"
			res["label"] = "Round 1"
			return res
	return {}

## ARD-M8-003 persistent identity: only the players whose job the match
## recorded are named on the oval (tagger and his man, the loose defender),
## and nobody is when the match recorded no jobs.
func _test_role_labels(res: Dictionary) -> void:
	var plain := MatchDirector.new()
	var bare := res.duplicate()
	bare["timeline"] = []
	plain.setup(bare, res["events"])
	_check(plain.role_labels().is_empty(), "No recorded jobs, no names on the oval")
	var d := MatchDirector.new()
	d.setup(bare, res["events"])
	var pick := func(side: int, role: String) -> Dictionary:
		for t in d.tokens:
			if int(t["side"]) == side and str(t["role"]) == role:
				return t
		return {}
	var tagger: Dictionary = pick.call(1, "MID")
	var target: Dictionary = pick.call(0, "MID")
	var loose: Dictionary = pick.call(1, "DEF")
	d._tac[1] = {"side": 1, "bursts": [], "tagger": str(tagger["pid"]), "tag": str(target["pid"]),
			"loose": str(loose["pid"]), "duels": {}}
	d._assign()
	var got: Array = d.role_labels()
	var want := [int(tagger["id"]), int(target["id"]), int(loose["id"])]
	var same := got.size() == want.size()
	for id in want:
		same = same and got.has(id)
	_check(same, "The tagger, his man and the loose defender are named, and only them (%s against %s)" % [str(got), str(want)])

## ARD-M8-003 step 3, the first demonstration: a side that floods behind the
## ball (its own recorded call) has visibly more players between the ball and
## its goal on the opposition's entries than ordinary coverage, and only when
## the match recorded the call.
func _test_flood_shape(res: Dictionary) -> void:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var behind := func(bursts: Array) -> int:
		d._tac[1] = {"side": 1, "bursts": bursts}
		var n := 0
		# Side 0 attacks toward +x: the ball in side 1's half, near and far.
		for bx in [20.0, 40.0, 55.0]:
			for t in d.tokens:
				if int(t["side"]) == 1 and (d._structure_spot(t, Vector2(bx, 0.0), 0) as Vector2).x > bx:
					n += 1
		return n
	var plain: int = behind.call([])
	var other: int = behind.call(["surge"])
	var flood: int = behind.call(["flood"])
	_check(flood >= plain + 6,
			"Flooding puts more players behind the ball on the opposition's entries (%d against %d over three entries)" % [flood, plain])
	_check(other == plain, "Only a recorded flood changes the shape (%d with another call, %d without)" % [other, plain])
	d._tac[1] = {}


## Defensive press pilot, V1-V3 (director, 2026-10-11): from its recorded plan, a
## side that presses stands higher while the ball is in its opponents' back half
## or the middle, narrower, and only then; the plan changes nothing else.
func _test_press_shape(res: Dictionary) -> void:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	# Side 0 attacks toward +x; side 1 defends the +x goal and presses (or not).
	# Its height is how far up the ground it stands, from its own goal end, over
	# three balls in its opponents' back half, plus its width (spread across).
	var stand := func(plan: String, bx0: float) -> Dictionary:
		d._tac[1] = {"side": 1, "plan": plan, "bursts": []}
		var high := 0.0
		var wide := 0.0
		var n := 0
		var front := -1.0e9
		var back := 1.0e9
		var mid_gap := 0.0
		var mids := 0
		var back_h := 0.0
		var backs := 0
		for t in d.tokens:
			if int(t["side"]) == 1:
				var p: Vector2 = d._structure_spot(t, Vector2(bx0, 0.0), 0)
				high += -p.x
				wide += absf(p.y)
				front = maxf(front, -p.x)
				back = minf(back, -p.x)
				if str(t["role"]) == "DEF":
					back_h += -p.x
					backs += 1
				if str(t["role"]) != "FWD" and str(t["role"]) != "DEF":
					mid_gap += absf(p.x - bx0)
					mids += 1
				n += 1
		return {"high": high / n, "wide": wide / n, "span": front - back, "mid_gap": mid_gap / maxi(1, mids), "back": back_h / maxi(1, backs)}
	var worst := 1.0e9
	for bx in [5.0, -10.0, -30.0, -50.0]:
		# Side 1 faces -x, so its own goal end is +x: "up the ground" is -x.
		var base: Dictionary = stand.call("balanced", bx)
		var press: Dictionary = stand.call("defensive", bx)
		worst = minf(worst, float(press["back"]) - float(base["back"]))
		_check(float(press["wide"]) < float(base["wide"]), "The press stands narrower (ball at %d: %.1f v %.1f)" % [int(bx), float(press["wide"]), float(base["wide"])])
	# One band around the ball: front to back inside 70 m, the midfield within
	# 25 m of the ball (balls in the opponents' back half and the middle).
	for bx in [5.0, -10.0, -30.0]:
		var pb: Dictionary = stand.call("defensive", bx)
		_check(float(pb["span"]) <= 70.0 and float(pb["mid_gap"]) <= 25.0,
				"The press is one band round the ball (ball at %d: %.0f m front to back, midfield %.0f m off it)" % [int(bx), float(pb["span"]), float(pb["mid_gap"])])
	_check(worst >= 12.0, "The press side's back line stands at least 12 m higher with the ball in their opponents' back half or the middle (least gain %.1f m)" % worst)
	# The ball deep at the press side's own end (world x of 60): no change.
	var far_base: Dictionary = stand.call("balanced", 60.0)
	var far_press: Dictionary = stand.call("defensive", 60.0)
	_check(absf(float(far_press["high"]) - float(far_base["high"])) < 0.01, "The shape is the same when the ball is at their own end")
	# The faint press zone (director, 2026-10-11): strongest over the opponents'
	# back third, a quarter of it in the middle, none in their forward third (the
	# sim's own zone table); it fades in and out, never pops.
	_check(is_equal_approx(MatchDirector.press_zone_strength(40.0), 1.0)
			and is_equal_approx(MatchDirector.press_zone_strength(0.0), 0.25)
			and MatchDirector.press_zone_strength(-40.0) == 0.0,
			"The press zone follows the sim's zones: full in their back third, a quarter in the middle, none in their forward third")
	# The field is soft-edged (no step between zones, none anywhere), and full / none far in.
	var jump := 0.0
	var xs := -70.0
	while xs < 70.0:
		jump = maxf(jump, absf(MatchDirector.press_zone_field(xs + 0.5) - MatchDirector.press_zone_field(xs)))
		xs += 0.5
	_check(jump < 0.06 and is_equal_approx(MatchDirector.press_zone_field(60.0), 1.0) and MatchDirector.press_zone_field(-60.0) == 0.0,
			"The press zone's edges are feathered, never a step (largest change per half metre %.3f)" % jump)
	d._tac[1] = {"side": 1, "plan": "defensive", "bursts": []}
	d._poss = 0
	d.ball["pos"] = Vector2(-30.0, 0.0)
	_check(d.press_zone_on(1) and not d.press_zone_on(0), "The zone is on for the press side only, while it hunts")
	d._poss = 1
	_check(not d.press_zone_on(1), "...and off when it has the ball")
	d._poss = 0
	MatchDirector.debug_no_press_shape = true
	_check(not d.press_zone_on(1), "No zone when the shape is off")
	MatchDirector.debug_no_press_shape = false
	var pvs = load("res://scripts/ui/PitchView.gd")
	_check(pvs.ease_fade(0.0) == 0.0 and pvs.ease_fade(1.0) == 1.0 and pvs.ease_fade(0.1) < 0.05
			and is_equal_approx(pvs.ease_fade(0.5), 0.5) and float(pvs.PRESS_FADE_SECS) >= 0.9,
			"The zone eases in and out over 0.9 s, not linearly")
	# The tint is the press club's own colour and shows on a phone (director,
	# 2026-10-13: 0.12 moved a channel 8-11 of 255, a darker turf stripe). At full
	# strength the mix with the turf must move a channel by at least 12% of the range
	# (30/255) and keep the club's hue, whatever the club (navy and brown included).
	var turf: Color = pvs.PRESS_TURF
	var pa := float(pvs.PRESS_ZONE_ALPHA)
	# Director, 2026-10-13: "right colour, about half as strong" (0.4 -> 0.3: 0.2 lost the hue).
	_check(is_equal_approx(pa, 0.3), "The press tint is laid at 0.3, lighter than the first 0.4 and not so light the club colour is lost")
	var tint_ok := true
	var tint_note := ""
	for code in ["FRE", "MEL", "WBD", "STK", "CAR", "HAW"]:
		var w: Color = pvs.press_zone_colour(code)
		var mix := Color(turf.r * (1.0 - pa) + w.r * pa, turf.g * (1.0 - pa) + w.g * pa, turf.b * (1.0 - pa) + w.b * pa)
		var shift := maxf(absf(mix.r - turf.r), maxf(absf(mix.g - turf.g), absf(mix.b - turf.b)))
		var slot := 1 if code == "WBD" else 0
		var club_h: float = (GameDB.club_colours(code)[slot] as Color).h * 360.0
		var dh := absf(fposmod(mix.h * 360.0 - club_h + 180.0, 360.0) - 180.0)
		if shift < 0.12 or dh > 30.0:
			tint_ok = false
			tint_note += " %s shift %.0f/255 hue off %.0f" % [code, shift * 255.0, dh]
	_check(tint_ok, "The press tint shows on a phone and is the press club's colour:" + tint_note)
	var black: Color = pvs.press_zone_colour("COL")
	_check(black.v < 0.2 and float(turf.g) - (turf.g * (1.0 - pa) + black.g * pa) >= 0.05,
			"A club with no hue (Collingwood) gets a dark wash that still darkens the turf visibly")
	d._tac[1] = {}
	# The line, once: only the pressing side's opponents' disposals open it.
	var tl := [{"at": 0, "side": 1, "plan": "defensive"}, {"at": 0, "side": 0, "plan": "balanced"}]
	var said := [false, false]
	_check(MatchNotes.press_trigger(tl, 3, {"kind": "kick", "side": 1}, said) == -1, "No line when the press side has the ball")
	_check(MatchNotes.press_trigger(tl, 3, {"kind": "goal", "side": 0}, said) == -1, "No line on a goal")
	_check(MatchNotes.press_trigger(tl, 3, {"kind": "kick", "side": 0}, said) == 1, "The line comes the first time the press side defends")
	said[1] = true
	_check(MatchNotes.press_trigger(tl, 9, {"kind": "kick", "side": 0}, said) == -1, "...and only once")
	_check(MatchNotes.press_trigger([{"at": 5, "side": 1, "plan": "defensive"}], 3, {"kind": "kick", "side": 0}, [false, false]) == -1, "No line before the plan is set")
	_check(MatchNotes.press_line("RIC").ends_with("push up to press."), "The line reads as a commentator would say it")


## ARD-M8-003 step 3, the second demonstration: attacking (stack) against
## defensive (flood) setups at the 2026 centre ball-up, each from the side's
## recorded call, and every setup legal under 6-6-6 (four in the square, six
## in each arc, the wings outside the square).
func _test_centre_setups(res: Dictionary) -> void:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var wings := func(bursts: Array) -> Array:
		d._tac[0] = {"side": 0, "bursts": bursts}
		var out := []
		for t in d.tokens:
			if int(t["side"]) == 0 and (str(t["slot"]) == "WL" or str(t["slot"]) == "WR"):
				out.append(d._centre_spot(t, -1))
		return out
	var legal := true
	for bursts in [[], ["stack"], ["flood"]]:
		d._tac[0] = {"side": 0, "bursts": bursts}
		var sq := 0
		var arcs := [0, 0]
		for t in d.tokens:
			if int(t["side"]) != 0:
				continue
			var p: Vector2 = d._centre_spot(t, -1)
			if absf(p.x) <= 25.0 and absf(p.y) <= 25.0:
				sq += 1
			if p.x >= MatchMotion.GOAL_X - 50.0:
				arcs[0] += 1
			elif p.x <= -(MatchMotion.GOAL_X - 50.0):
				arcs[1] += 1
		if sq != 4 or arcs[0] != 6 or arcs[1] != 6:
			legal = false
	var plain: Array = wings.call([])
	var stack: Array = wings.call(["stack"])
	var flood: Array = wings.call(["flood"])
	var crashed := stack.size() == 2
	for w in stack:
		crashed = crashed and absf((w as Vector2).x) <= 5.0 and absf((w as Vector2).y) > 25.0 and absf((w as Vector2).y) < absf((plain[0] as Vector2).y)
	var dropped := flood.size() == 2
	for w in flood:
		dropped = dropped and (w as Vector2).x < -12.0
	_check(legal, "Every centre ball-up setup keeps 6-6-6: four in the square, six in each arc")
	_check(crashed and dropped,
			"Stacking puts the wings on the square's edge; flooding drops them behind the ball (%s / %s / %s)" % [str(plain), str(stack), str(flood)])
	d._tac[0] = {}


## P-12 (director, 2026-10-18: "the oval answers a structural call"): each call
## that had no drawn shape now has one, from what the engine does with it,
## measured against Balanced at three balls (side 0's back half, the middle, its
## forward half), and only for the side whose recorded call it is.
func _test_call_shapes(res: Dictionary) -> void:
	var d := MatchDirector.new()
	d.setup(res, res["events"])
	var balls := [Vector2(-30.0, 6.0), Vector2(0.0, -4.0), Vector2(30.0, 8.0)]
	# Side 0 (attacking +x) with `call`, `poss` in possession: where each of its
	# players stands for each ball, and what the shape is made of.
	var stand := func(call: Dictionary, poss: int, side := 0) -> Dictionary:
		d._tac[side] = call.duplicate()
		d._tac[side]["side"] = side
		var pos := []
		var wide := 0.0
		var deep := 0.0
		var ahead := 0
		var mid_gap := 0.0
		var star_gap := 0.0
		var span := 0.0
		var back := 0.0
		var n := 0
		for bp in balls:
			var front := -1.0e9
			var rear := 1.0e9
			for t in d.tokens:
				if int(t["side"]) != 0:
					continue
				var p: Vector2 = d._structure_spot(t, bp, poss)
				pos.append(p)
				wide += absf(p.y)
				deep += p.x
				n += 1
				front = maxf(front, p.x)
				rear = minf(rear, p.x)
				if p.x > (bp as Vector2).x:
					ahead += 1
				if str(t["role"]) == "MID" or str(t["role"]) == "RUCK":
					mid_gap += p.distance_to(bp)
				if str(t["role"]) == "DEF":
					back += p.x
				if d._is_star(t):
					star_gap += p.distance_to(bp)
			span += front - rear
		d._tac[side] = {}
		return {"pos": pos, "wide": wide / n, "deep": deep / n, "ahead": ahead, "mid_gap": mid_gap,
				"star_gap": star_gap / 9.0, "span": span / 3.0, "back": back}
	var same := func(a: Dictionary, b: Dictionary) -> bool:
		for i in range((a["pos"] as Array).size()):
			if ((a["pos"] as Array)[i] as Vector2).distance_to((b["pos"] as Array)[i]) > 0.01:
				return false
		return true
	var plain := {"plan": "balanced", "bursts": []}
	var bal_has: Dictionary = stand.call(plain, 0)
	var bal_not: Dictionary = stand.call(plain, 1)
	# Attack corridor: narrower with the ball, the corridor full; nothing without it.
	var att: Dictionary = stand.call({"plan": "attacking", "bursts": []}, 0)
	_check(float(att["wide"]) <= 0.75 * float(bal_has["wide"]) and same.call(stand.call({"plan": "attacking", "bursts": []}, 1), bal_not),
			"Attack corridor narrows into the corridor with the ball, by a quarter or more (%.1f m from the centre line against %.1f), and only with it" % [float(att["wide"]), float(bal_has["wide"])])
	# Controlled tempo: wider with the ball and its lines in short around it.
	var con: Dictionary = stand.call({"plan": "controlled", "bursts": []}, 0)
	_check(float(con["wide"]) >= 1.15 * float(bal_has["wide"]) and float(con["span"]) <= float(bal_has["span"]) - 8.0
			and same.call(stand.call({"plan": "controlled", "bursts": []}, 1), bal_not),
			"Controlled tempo spreads wide with the ball (%.1f m against %.1f) and its lines come in short (%.0f m front to back against %.0f), only with the ball" % [float(con["wide"]), float(bal_has["wide"]), float(con["span"]), float(bal_has["span"])])
	# Win contest: the midfield on the ball, both ways.
	var ctn_has: Dictionary = stand.call({"plan": "contest", "bursts": []}, 0)
	var ctn_not: Dictionary = stand.call({"plan": "contest", "bursts": []}, 1)
	_check(float(ctn_has["mid_gap"]) <= 0.7 * float(bal_has["mid_gap"]) and float(ctn_not["mid_gap"]) <= 0.7 * float(bal_not["mid_gap"]),
			"Win contest keeps its midfield on the ball, a third closer or more (%.0f and %.0f m in all against %.0f and %.0f)" % [float(ctn_has["mid_gap"]), float(ctn_not["mid_gap"]), float(bal_has["mid_gap"]), float(bal_not["mid_gap"])])
	# ...and extra numbers at every stoppage: the centre bounce set up as a
	# stack (a flood or stack burst still has the say), and a bigger pack at a
	# ball-up.
	d._tac[0] = {"side": 0, "plan": "contest", "bursts": []}
	var centre_ok := d._centre_setup(0) == "stack" and d._centre_setup(1) == ""
	d._tac[0] = {"side": 0, "plan": "contest", "bursts": ["flood"]}
	centre_ok = centre_ok and d._centre_setup(0) == "flood"
	var bu := -1
	for i in range((res["events"] as Array).size()):
		if str(res["events"][i].get("kind", "")) == "ballup" and d._next_real(i) >= 0:
			bu = i
			break
	var packs := func(plan: String) -> Array:
		d._tac[0] = {"side": 0, "plan": plan, "bursts": []}
		var per := [0, 0]
		for ph in d._ballup_phases(bu):
			if str((ph as Dictionary)["t"]) == "pack":
				for id in (ph as Dictionary)["members"]:
					per[int(d.tokens[id]["side"])] += 1
		return per
	var pack_bal: Array = packs.call("balanced")
	var pack_ctn: Array = packs.call("contest")
	_check(centre_ok and bu >= 0 and int(pack_ctn[0]) > int(pack_bal[0]) and int(pack_ctn[0]) >= 3 + MatchDirector.CONTEST_PACK and int(pack_ctn[1]) == int(pack_bal[1]),
			"Win contest sends extra numbers to every stoppage: a stacked centre bounce, a ball-up pack of %d against %d (the other side's %d unchanged)" % [int(pack_ctn[0]), int(pack_bal[0]), int(pack_ctn[1])])
	d._tac[0] = {}
	# Through stars: the three stars stand closest to the ball, with it only.
	var st: Dictionary = stand.call({"plan": "through_stars", "bursts": []}, 0)
	_check(float(st["star_gap"]) <= float(bal_has["star_gap"]) - 10.0 and same.call(stand.call({"plan": "through_stars", "bursts": []}, 1), bal_not),
			"Through stars brings its three stars at least 10 m closer to the ball (%.0f m against %.0f), only with the ball" % [float(st["star_gap"]), float(bal_has["star_gap"])])
	# ...and the men on them play them tighter (they know where it's going).
	var tight := func(plan: String) -> float:
		d._tac[0] = {"side": 0, "plan": plan, "bursts": []}
		var gap := 0.0
		for t in d.tokens:
			if int(t["side"]) == 0 and d._is_star(t):
				t["goal"] = d._structure_spot(t, balls[1], 0)
		for t in d.tokens:
			var o := int(t["match"])
			if int(t["side"]) == 1 and o >= 0 and d._is_star(d.tokens[o]):
				gap += (d._structure_spot(t, balls[1], 0) as Vector2).distance_to(d.tokens[o]["goal"])
		d._tac[0] = {}
		return gap
	var gap_bal: float = tight.call("balanced")
	var gap_st: float = tight.call("through_stars")
	_check(gap_st < gap_bal - 3.0, "Their opponents stand tighter on the stars (%.0f m in all against %.0f)" % [gap_st, gap_bal])
	# Throw numbers at it: numbers ahead of the ball with it, the backs high without it.
	var sg_has: Dictionary = stand.call({"plan": "balanced", "bursts": ["surge"]}, 0)
	var sg_not: Dictionary = stand.call({"plan": "balanced", "bursts": ["surge"]}, 1)
	_check(int(sg_has["ahead"]) >= int(bal_has["ahead"]) + 6 and same.call(sg_not, bal_not),
			"Throw numbers at it puts at least six more players ahead of the ball with it (%d against %d over three balls), a flood in reverse, and only with it" % [int(sg_has["ahead"]), int(bal_has["ahead"])])
	# Slow it down: deeper both ways, wider with the ball.
	var hd_has: Dictionary = stand.call({"plan": "balanced", "bursts": ["hold"]}, 0)
	var hd_not: Dictionary = stand.call({"plan": "balanced", "bursts": ["hold"]}, 1)
	_check(float(hd_has["deep"]) <= float(bal_has["deep"]) - 10.0 and float(hd_not["deep"]) <= float(bal_not["deep"]) - 10.0
			and float(hd_has["wide"]) >= 1.15 * float(bal_has["wide"]),
			"Slow it down sits at least 10 m deeper both ways (%.0f / %.0f against %.0f / %.0f) and spreads wide with the ball" % [float(hd_has["deep"]), float(hd_not["deep"]), float(bal_has["deep"]), float(bal_not["deep"])])
	# The pace each call moves at comes from the engine's legs.
	var paces := []
	for c in [{"plan": "balanced", "bursts": []}, {"plan": "attacking", "bursts": []}, {"plan": "controlled", "bursts": []},
			{"plan": "balanced", "bursts": ["surge"]}, {"plan": "balanced", "bursts": ["hold"]}]:
		d._tac[0] = c
		paces.append(d._call_pace(0))
	d._tac[0] = {}
	_check(is_equal_approx(float(paces[0]), 1.0) and float(paces[1]) > 1.0 and float(paces[2]) < 1.0 and float(paces[3]) > 1.0 and float(paces[4]) < 1.0,
			"Attack corridor and Throw numbers at it move quicker, Controlled tempo and Slow it down slower (%s)" % str(paces))
	# Only the recorded call: another side's call, a call with no shape here
	# (the stack) and the capture switch all leave Balanced as it was.
	var only := true
	# (Through stars is left out: the men on its stars answering it is the point.)
	for c in [{"plan": "attacking", "bursts": []}, {"plan": "controlled", "bursts": ["hold"]}, {"plan": "contest", "bursts": ["surge"]}]:
		d._tac[1] = c.duplicate()
		only = only and same.call(stand.call(plain, 0), bal_has) and same.call(stand.call(plain, 1), bal_not)
		d._tac[1] = {}
	only = only and same.call(stand.call({"plan": "balanced", "bursts": ["stack"]}, 0), bal_has)
	MatchDirector.debug_no_press_shape = true
	for c in [{"plan": "attacking", "bursts": ["surge"]}, {"plan": "contest", "bursts": ["hold"]}]:
		only = only and same.call(stand.call(c, 0), bal_has)
	MatchDirector.debug_no_press_shape = false
	_check(only, "A shape changes only for the side whose call it is, and --noshape draws every call as Balanced")


## Every call drawn through real playback: the calls change each passage (both
## sides, every plan and short call), and nobody jumps, leaves the oval or
## holds up the log.
func _test_call_playback(res: Dictionary) -> void:
	var evs: Array = (res["events"] as Array).slice(0, 640)
	var opening := [{}, {}]
	for e in res["timeline"]:
		if int(e["at"]) == 0:
			opening[int(e["side"])] = e
	var calls := [[["attacking", ["surge"]], ["contest", ["hold"]]],
			[["controlled", ["hold"]], ["through_stars", ["surge"]]],
			[["through_stars", []], ["attacking", ["flood"]]],
			[["contest", ["surge"]], ["controlled", []]]]
	var tl := []
	for k in range(calls.size()):
		for side in range(2):
			var e: Dictionary = (opening[side] as Dictionary).duplicate(true)
			e["at"] = k * 160
			e["side"] = side
			e["plan"] = calls[k][side][0]
			e["bursts"] = calls[k][side][1]
			tl.append(e)
	var r2 := res.duplicate()
	r2["timeline"] = tl
	var played := _play(r2, evs, 1.0 / 60.0 * 4.0)
	_check(not played["stalled"] and (played["out"] as Array).size() == evs.size(),
			"With every call drawn, playback releases all %d events (%d)" % [evs.size(), (played["out"] as Array).size()])
	_check(int(played["nan"]) == 0 and int(played["outside"]) == 0 and float(played["max_step"]) < 2.2,
			"With every call drawn, nobody leaves the oval or jumps (%d outside, largest step %.2f m)" % [int(played["outside"]), float(played["max_step"])])


## The feed marks a call (P-12): a plan set at quarter time gives one start line,
## carried on over a break it says so, and a short call running out gives one
## end line - mid-quarter or at the break, never both. A short call's start
## has the coach's call line already, so no second line.
func _test_call_lines(res: Dictionary) -> void:
	var evs: Array = res["events"]
	var qs := []
	for i in range(evs.size()):
		if str(evs[i].get("kind", "")) == "quarter":
			qs.append(i)
	var walk := func(tl: Array) -> Array:
		var mem := MatchNotes.call_state()
		var out := []
		for i in range(evs.size()):
			for text in MatchNotes.call_lines(tl, i, evs[i], mem, "RIC", "SYD"):
				out.append([i, str(text)])
		return out
	var ric := GameDB.club_name("RIC")
	var open := [{"at": 0, "side": 0, "plan": "balanced", "bursts": []}, {"at": 0, "side": 1, "plan": "balanced", "bursts": []}]
	var lines: Array = walk.call(open + [{"at": int(qs[0]) + 1, "side": 0, "plan": "attacking", "bursts": []}])
	var starts := lines.filter(func(l): return str(l[1]).contains("is on until"))
	var kept := lines.filter(func(l): return str(l[1]).contains("stays on until"))
	_check(starts.size() == 1 and int(starts[0][0]) == int(qs[0]) + 1
			and str(starts[0][1]) == "%s: Attack corridor is on until half time." % ric,
			"A plan set at quarter time gives one start line, at the next bounce (%s)" % str(starts))
	_check(kept.size() == 2 and str(kept[0][1]) == "%s: Attack corridor stays on until three-quarter time." % ric,
			"...and a line at each later break while it stays on (%s)" % str(kept))
	var burst: Array = walk.call(open + [{"at": 10, "side": 0, "plan": "balanced", "bursts": ["surge"]},
			{"at": 40, "side": 0, "plan": "balanced", "bursts": []}])
	_check(burst.size() == 1 and int(burst[0][0]) == 40 and str(burst[0][1]) == "%s: Throw numbers at it ends." % ric,
			"A short call running out gives one end line, and its start none of its own (%s)" % str(burst))
	var at_break: Array = walk.call(open + [{"at": 10, "side": 0, "plan": "balanced", "bursts": ["flood"]},
			{"at": int(qs[0]) + 1, "side": 0, "plan": "balanced", "bursts": []}])
	_check(at_break.size() == 1 and int(at_break[0][0]) == int(qs[0]) and str(at_break[0][1]) == "%s: Flood behind the ball ends at the break." % ric,
			"A short call the break ends gives one line, at the break (%s)" % str(at_break))
	var off: Array = walk.call([{"at": 0, "side": 0, "plan": "defensive", "bursts": []}, open[1],
			{"at": int(qs[0]) + 1, "side": 0, "plan": "balanced", "bursts": []}])
	_check(off.size() == 2 and str(off[0][1]) == "%s: Defensive press is on until quarter time." % ric
			and str(off[1][1]) == "%s: Defensive press ends." % ric,
			"A plan from the first bounce is marked, and so is its end (%s)" % str(off))


## FL-007: the guard of honour and chaired off after a milestone game. Who it honours,
## and that every move it draws is on the figure sheet, no frame past a strip's end.
func _test_farewell() -> void:
	_check(FarewellVignette.caption({"player": "Smith", "games": 200}) == "Smith's 200th game",
			"A 200th game is honoured")
	_check(FarewellVignette.caption({"player": "Smith", "games": 250, "club": true}) == "Smith's 250th game for the club",
			"A club milestone says so (%s)" % FarewellVignette.caption({"player": "Smith", "games": 250, "club": true}))
	_check(FarewellVignette.caption({"player": "Smith", "games": "farewell"}) == "A farewell for Smith",
			"His last game is honoured")
	_check(FarewellVignette.caption({"player": "Smith", "games": 150}) == ""
			and FarewellVignette.caption({"player": "Smith", "games": 100, "club": true}) == ""
			and FarewellVignette.caption({"player": "Smith", "games": 50}) == ""
			and FarewellVignette.caption({"player": "Smith", "games": 1}) == ""
			and FarewellVignette.caption({}) == "", "Under 200 games (director), a debut or no milestone gets no scene")
	_check(FarewellVignette._ordinal(111) == "111th" and FarewellVignette._ordinal(122) == "122nd"
			and FarewellVignette._ordinal(253) == "253rd", "Ordinals read as said")
	# Director, 2026-10-10: "A on PC, B on phone" - the framing follows the screen's shape.
	_check(FarewellVignette.framing(Vector2(390, 844)) == FarewellVignette.PORTRAIT
			and FarewellVignette.PORTRAIT == Vector2(1.25, 0.43),
			"A portrait phone gets the pulled-back framing (B: lens 1.25, horizon 0.43)")
	_check(FarewellVignette.framing(Vector2(1920, 1080)) == FarewellVignette.LANDSCAPE
			and FarewellVignette.framing(Vector2(3840, 2160)) == FarewellVignette.LANDSCAPE
			and FarewellVignette.LANDSCAPE == Vector2(1.68, 0.508),
			"A wide window gets the close framing (A: lens 1.68, horizon 0.508)")
	for need in [["clap", "side_l"], ["walk_wave", "front"], ["carrier", "front"], ["carrier_near", "front"], ["chaired", "front"]]:
		_check(VignetteFigures.has("average", need[0], need[1]), "The sheet has the farewell's %s (%s)" % need)
	var mine := []
	var theirs := []
	for i in range(23):
		mine.append({"id": "m%d" % i, "num": i + 1})
		theirs.append({"id": "t%d" % i, "num": i + 1})
	var v := FarewellVignette.new()
	v.setup_farewell({"player": "Smith", "games": 200, "id": "m0"}, mine[0], "COL", "GEE", mine, theirs)
	_check(v.tokens.size() == 2 * FarewellVignette.LINE, "Two lines of the guard (%d)" % v.tokens.size())
	_check(v.tokens.all(func(t): return str(t["id"]) != "m0"), "He walks through the guard, not in it")
	StoppageVignette.log_frames = true
	StoppageVignette.frame_log.clear()
	var t := 0.0
	while t < FarewellVignette.END:
		v.set("_t", t)
		for tok in v.tokens:
			var pick: Array = v._frame(tok, 0.0)
			StoppageVignette.figure_frame(VignetteFigures.strip("average", pick[0], pick[3]), int(pick[1]), pick[0], pick[3])
		for role in (["walker"] if t < FarewellVignette.GUARD else ["carrier", "rider", "carrier_hand"]):
			for mirror in [false, true]:
				var pick: Array = v._frame(v._role(v._man, role, {"mirror": mirror}), 0.0)
				StoppageVignette.figure_frame(VignetteFigures.strip("average", pick[0], pick[3]), int(pick[1]), pick[0], pick[3])
		t += 0.05
	var past := StoppageVignette.frame_log.filter(func(e): return int(e["wanted"]) >= int(e["frames"]))
	_check(past.is_empty(), "No farewell frame past the end of its move (%s)" % str(past.slice(0, 3)))
	StoppageVignette.log_frames = false
	v.free()


## FL-003: the vignettes draw the MCG where the match is played there - a club's home
## game at its MCG home, and the Grand Final - and the plain ground everywhere else.
func _test_match_ground() -> void:
	VignetteGround.use_match({"home": "COL", "away": "GEE", "venue": ""})
	_check(VignetteGround.venue == "MCG", "A Collingwood home game draws the MCG")
	VignetteGround.use_match({"home": "GEE", "away": "COL", "venue": ""})
	_check(VignetteGround.venue != "MCG", "A Geelong home game draws its own ground (%s)" % VignetteGround.venue)
	VignetteGround.use_match({"home": "GEE", "away": "COL", "venue": "MCG"})
	_check(VignetteGround.venue == "MCG", "A final at the MCG draws the MCG (the Grand Final)")
	VignetteGround.venue = ""


## Discs that would overlap are drawn apart (director, 2026-10-14): on a phone
## and on a PC no two drawn centres are closer than a disc's diameter, the
## players stay where the match has them, a disc never jumps from one frame to
## the next, and a held ball is drawn at its holder's disc.
func _test_discs_apart() -> void:
	var res := _sim(31, "FRE", "MEL").run()
	res["home"] = "FRE"
	res["away"] = "MEL"
	res["label"] = "Round 1"
	# The first quarter is enough: every kind of pack and set-up happens in it.
	var all: Array = res["events"]
	var cut := all.size()
	for k in range(all.size()):
		if str(all[k].get("kind", "")) == "quarter":
			cut = k + 1
			break
	res["events"] = all.slice(0, cut)
	for view in [[Vector2(370, 490), true, "phone", false], [Vector2(760, 590), false, "PC", false],
			[Vector2(370, 490), true, "phone, fully apart", true]]:
		PitchView.nudge_full = view[3]
		var pv := PitchView.new()
		pv.size = view[0]
		pv.camera_enabled = view[1]
		pv.setup(res)
		pv.set_speed(4.0)
		var worst_nudge_discs := 0.0
		var top_ok := true
		pv.play()
		var closest := INF
		var real_closest := INF
		var moved_engine := 0
		var worst_nudge_m := 0.0
		var ball_off := 0.0
		var guard := 0
		while pv.playing and guard < 60000:
			guard += 1
			pv._process(1.0 / 30.0)
			var before := []
			for t in pv.director.tokens:
				before.append(t["pos"])
			var drawn := pv.disc_positions()
			var tr := pv.token_radius()
			var real := PackedVector2Array()
			for i in range(before.size()):
				real.append(pv._w2s(before[i]))
			for i in range(pv.director.tokens.size()):
				if pv.director.tokens[i]["pos"] != before[i]:
					moved_engine += 1
				worst_nudge_m = maxf(worst_nudge_m, drawn[i].distance_to(real[i]) / pv._scale())
				worst_nudge_discs = maxf(worst_nudge_discs, drawn[i].distance_to(real[i]) / (2.0 * tr))
				for j in range(i + 1, drawn.size()):
					closest = minf(closest, drawn[i].distance_squared_to(drawn[j]) / (4.0 * tr * tr))
					real_closest = minf(real_closest, real[i].distance_squared_to(real[j]) / (4.0 * tr * tr))
			var holder := int(pv.director.ball.get("holder", -1))
			if str(pv.director.ball.get("mode", "")) == "held" and holder >= 0:
				ball_off = maxf(ball_off, pv.ball_point().distance_to(drawn[holder]) / pv._scale())
				var order := pv.draw_order()
				if order.size() != drawn.size() or int(order[-1]) != holder \
						or int(pv.director.tokens[order[-2]]["side"]) == int(pv.director.tokens[holder]["side"]) \
						or int(pv.director.tokens[order[-3]]["side"]) == int(pv.director.tokens[holder]["side"]):
					top_ok = false
		closest = sqrt(closest)
		real_closest = sqrt(real_closest)
		if bool(view[3]):
			_check(not pv.playing and closest >= 0.97,
					"%s: no two discs are drawn closer than a diameter (closest %.2f of one; the players themselves get to %.2f)" % [
					str(view[2]), closest, real_closest])
		else:
			_check(not pv.playing and worst_nudge_discs <= PitchView.NUDGE_CAP + 0.01,
					"%s: a disc is drawn within half its width of its player (%.2f of a disc at most; closest pair %.2f of one, the players %.2f)" % [
					str(view[2]), worst_nudge_discs, closest, real_closest])
		_check(top_ok, "%s: the man with the ball is drawn last, over the two opponents nearest him" % str(view[2]))
		_check(moved_engine == 0, "%s: drawing the discs apart moves no player" % str(view[2]))
		_check(ball_off <= 1.0, "%s: a held ball is drawn at its holder's disc (%.2f m off)" % [str(view[2]), ball_off])
		_check(worst_nudge_m < 20.0, "%s: no disc is drawn far from its player (%.1f m at most)" % [str(view[2]), worst_nudge_m])
		print("  discs apart, %s: closest %.2f diameters (players %.2f), biggest nudge %.1f m" % [
				str(view[2]), closest, real_closest, worst_nudge_m])
		pv.free()
	PitchView.nudge_full = false
	# Frame to frame: two players standing still on one spot are drawn the same
	# way every frame (no jitter, no swapping sides).
	var pv2 := PitchView.new()
	pv2.size = Vector2(370, 490)
	pv2.setup(res)
	var first := pv2.disc_positions().duplicate()
	var settled := PackedVector2Array()
	var drift := 0.0
	for k in range(40):
		var now := pv2.disc_positions().duplicate()
		if k >= 20:
			if settled.is_empty():
				settled = now
			for i in range(now.size()):
				drift = maxf(drift, now[i].distance_to(settled[i]))
	_check(drift < 0.5, "Discs at rest are drawn in the same place every frame (%.2f px of drift)" % drift)
	var sides_kept := true
	for i in range(first.size()):
		for j in range(i + 1, first.size()):
			if first[i].distance_to(first[j]) < 40.0 and (first[j] - first[i]).dot(settled[j] - settled[i]) < 0.0:
				sides_kept = false
	_check(sides_kept, "Two discs drawn apart keep their sides of each other")
	pv2.free()


## Two sides whose discs look alike: the away side wears its clash strip, its
## own kit with the two colours changed over. Fremantle v Melbourne is one; the
## Bulldogs v St Kilda is not. And the call over the play covers no disc.
func _test_clash_kit() -> void:
	var fm: Array = PitchView.kits_for("FRE", "MEL")
	var mel: Dictionary = GameDB.club_guernsey("MEL")
	_check(bool(fm[1].get("clash", false)) and fm[1]["base"] != mel["base"],
			"Melbourne change their body colour at Fremantle")
	_check(fm[0]["base"] == GameDB.club_guernsey("FRE")["base"] and fm[0]["design"] == GameDB.club_guernsey("FRE")["design"],
			"The home side always wears its own kit")
	var hw: Array = PitchView.kits_for("HAW", "WCE")
	_check(not hw[1].has("clash") and hw[1]["base"] == GameDB.club_guernsey("WCE")["base"],
			"Hawthorn and West Coast do not clash: both wear their own kit")
	# Adelaide v Melbourne, the pair the director found alike (2026-10-14): each way.
	for pair in [["ADE", "MEL"], ["MEL", "ADE"]]:
		var k: Array = PitchView.kits_for(str(pair[0]), str(pair[1]))
		_check(PitchView.disc_distance(k[0], k[1]) >= PitchView.DISC_CLASH,
				"%s v %s: the two discs are plainly different (%.0f)" % [pair[0], pair[1], PitchView.disc_distance(k[0], k[1])])
	# The third colour defines the club: Adelaide's disc carries its gold.
	var ade: Dictionary = PitchView.with_trim("ADE", GameDB.club_guernsey("ADE"))
	_check(ade.get("ring", null) != null and (ade["ring"] as Color).is_equal_approx(GameDB.club_colours("ADE")[2]),
			"Adelaide's disc has a ring of its gold")
	_check(PitchView.with_trim("MEL", GameDB.club_guernsey("MEL")).get("ring", null) == null,
			"Melbourne's disc has no third colour")
	# Every one of the 306 home-and-away pairs of today's 18 clubs, after the clash rule.
	var swaps := 0
	var worst := 1000.0
	var alike := []
	var foreign := []
	for h in GameDB.CLUB_ORDER.slice(0, 18):
		for a in GameDB.CLUB_ORDER.slice(0, 18):
			if h == a:
				continue
			var k2: Array = PitchView.kits_for(str(h), str(a))
			var d: float = PitchView.disc_distance(k2[0], k2[1])
			worst = minf(worst, d)
			if bool(k2[1].get("clash", false)):
				swaps += 1
				# Only the club's own colours (or its white) are ever used.
				var own: Array = GameDB.club_colours(str(a))
				var okc := false
				own.append(Color.WHITE)
				for c in own:
					if (c as Color).is_equal_approx(k2[1]["base"]):
						okc = true
				if not okc:
					foreign.append("%s v %s" % [h, a])
			if d < PitchView.DISC_CLASH:
				alike.append("%s v %s (%.0f)" % [h, a, d])
	print("  clash strips, %d of 306 home-and-away pairs; closest pair %.0f" % [swaps, worst])
	_check(alike.is_empty(), "All 306 pairs: the two discs are plainly different (%s)" % ", ".join(alike))
	_check(swaps > 0 and swaps < 306, "Some, not all, of the pairs put the away side in a clash strip (%d)" % swaps)
	_check(foreign.is_empty(), "A clash strip uses only that club's own colours (%s)" % ", ".join(foreign))
	# The number reads: near-black on a light body, white on a dark one.
	var ric: Array = PitchView.number_inks(GameDB.club_guernsey("RIC").merged({"base": Color("#FFD200"), "design": "plain", "pattern": Color("#FFD200")}))
	_check((ric[0] as Color).get_luminance() < 0.2, "The number is dark on a yellow disc")
	_check((PitchView.number_inks(GameDB.club_guernsey("MEL"))[0] as Color).get_luminance() > 0.8, "The number is white on a navy disc")
	var pv := PitchView.new()
	pv.size = Vector2(370, 490)
	var res := _sim(31, "FRE", "MEL").run()
	res["home"] = "FRE"
	res["away"] = "MEL"
	pv.setup(res)
	_check(pv.clash, "The view knows the away side is in its clash strip")
	# The call over the play ("Turnover", a scorer's name) never covers a disc.
	pv.set_speed(4.0)
	pv.play()
	var covered := 0
	var shown := 0
	var guard := 0
	while pv.playing and guard < 4000:
		guard += 1
		pv._process(1.0 / 30.0)
		var drawn := pv.disc_positions()
		var box := pv.caption_box()
		if box.size.x <= 0.0:
			continue
		shown += 1
		var tr := pv.token_radius()
		for d2 in drawn:
			if box.grow(tr).has_point(d2):
				covered += 1
	_check(shown > 50 and covered == 0, "The call over the play covers no disc (%d frames with a call, %d discs covered)" % [shown, covered])
	pv.free()


## The surnames under the discs never run over one another or over another
## player's disc and number (director, 2026-10-14: "van Rooyenrell"), and the
## ball carrier's is never dropped. Seeded match, every frame of play at a phone
## size, checked on the frames with the most names.
func _test_label_overlap() -> void:
	# A real match (three of your players ringed) and the most names a frame can
	# carry (everyone ringed).
	_label_run("a few ringed", 3)
	_label_run("everyone ringed", 99)


func _label_run(what: String, ringed_count: int) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(370, 490)
	var res := _sim(31, "ADE", "MEL").run()
	res["home"] = "ADE"
	res["away"] = "MEL"
	pv.setup(res)
	var ringed := {}
	for t in pv.director.tokens:
		if ringed.size() < ringed_count:
			ringed[str(t.get("pid", ""))] = true
	pv.rings = ringed
	pv.set_speed(4.0)
	pv.play()
	var frames := 0
	var names := 0
	var bad := 0
	var far := 0
	var twice := 0
	var missing := 0
	var guard := 0
	while pv.playing and guard < 3000:
		guard += 1
		pv._process(1.0 / 30.0)
		if guard % 6 != 0:
			continue
		var tr := pv.token_radius()
		var fs := clampi(int(tr * 1.15), 9, 12)
		var discs := pv.disc_positions()
		var lay := pv.role_label_layout(tr, fs)
		var wanted := pv.label_wanted()
		var captioned := int(pv._caption["tok"]) if not pv._caption.is_empty() else -1
		frames += 1
		names += lay.size()
		var seen := {}
		for i in range(lay.size()):
			var id := int(lay[i]["id"])
			var r: Rect2 = lay[i]["rect"]
			if seen.has(id) or id == captioned:
				twice += 1
			seen[id] = true
			for j in range(i + 1, lay.size()):
				if r.intersects(lay[j]["rect"] as Rect2):
					bad += 1
			var c: Vector2 = discs[id]
			if Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y)).distance_to(c) > tr * 2.2:
				far += 1
		# Every player who should be named, and is on screen, has his name.
		for id in wanted:
			var t: Dictionary = pv.director.tokens[id]
			var p: Vector2 = discs[id]
			if int(id) == captioned or float(t.get("down", 0.0)) > 0.0 or str(t.get("surname", "")) == "" 					or p.x < 0.0 or p.y < 0.0 or p.x > pv.size.x or p.y > pv.size.y:
				continue
			if not seen.has(int(id)):
				missing += 1
	print("  labels (%s): frames %d, names %d, name overlaps %d, far from disc %d, named twice %d, missing %d" % [what, frames, names, bad, far, twice, missing])
	_check(frames > 50 and names > frames, "The name test saw busy frames, %s (%d frames, %d names)" % [what, frames, names])
	_check(bad == 0, "No name overlaps another name, %s (%d)" % [what, bad])
	# With everyone ringed 36 names cannot all fit beside their discs; a real
	# match (a few ringed) must, but for a pack so tight that a name finds no free
	# place beside its disc: that is allowed in at most 1 frame in 50.
	var real_match := ringed_count < 10
	_check(far == 0 or not real_match, "Every name sits beside its own disc, %s (%d too far)" % [what, far])
	_check(twice == 0, "A player's name is drawn once, not under his disc and again in the caption, %s (%d)" % [what, twice])
	_check(missing <= frames / 50 or not real_match, "Every named player on screen has his name, %s (%d missing in %d frames)" % [what, missing, frames])
	pv.free()


## Everything a screen can ask about every club and every pair of clubs: names,
## colours, kits, inks. The same before a club's two sides are registered,
## while they are, and after they are taken out again.
func _look_of_every_club() -> String:
	var parts := []
	for a in GameDB.club_order:
		parts.append([a, GameDB.club_name(str(a)), GameDB.club_short(str(a)), str(GameDB.club_colours(str(a))),
				str(GameDB.club_marker_colours(str(a))), str(GameDB.club_guernsey(str(a))),
				str(UiKit.club_ink(str(a))), str(UiKit.club_ink_second(str(a))), str(PitchView.press_zone_colour(str(a))),
				GameDB.side_base(str(a)), GameDB.is_side(str(a))])
		for b in GameDB.club_order:
			parts.append([str(PitchView.kits_for(str(a), str(b))), str(UiKit.club_ink_pair(str(a), str(b))),
					GameDB.coach_side(str(a), str(b), GameState.my_club)])
	return str(hash(str(parts)))


## A club playing itself (an intra-club match): each side is its own entry
## beside the real clubs, with its own name and kit, and a normal club-v-club
## match is untouched by it.
func _test_sides() -> void:
	var order_before: Array = GameDB.club_order.duplicate()
	var clubs_before := GameDB.clubs.size()
	GameState.my_club = "FRE"
	var before := _look_of_every_club()
	var plain := _sim(77, "FRE", "MEL").run()
	_check(not GameDB.is_side("FRE") and GameDB.side_base("FRE") == "FRE" and not GameDB.side_is_coach("FRE")
			and GameDB.coach_side("FRE", "MEL", GameState.my_club) == 0 and GameDB.coach_side("MEL", "FRE", GameState.my_club) == 1
			and GameDB.coach_side("MEL", "GEE", GameState.my_club) == 1,
			"With no sides registered a club is itself, and the coach's side is his club's, as always")

	var codes: Array = GameDB.register_sides("FRE")
	var home := str(codes[0])
	var clash := str(codes[1])
	_check(GameDB.club_name(home) == "Fremantle Purple" and GameDB.club_name(clash) == "Fremantle White"
			and GameDB.club_short(home) == "Purple" and GameDB.club_short(clash) == "White",
			"Fremantle's two sides are named by their strips: Fremantle Purple and Fremantle White")
	_check(GameDB.is_side(home) and GameDB.is_side(clash) and GameDB.side_base(home) == "FRE" and GameDB.side_base(clash) == "FRE"
			and GameDB.side_is_coach(home) and not GameDB.side_is_coach(clash)
			and GameDB.coach_side(home, clash, GameState.my_club) == 0 and GameDB.coach_side(clash, home, GameState.my_club) == 1,
			"The coach's side is the one flagged as his, the side in the home strip, whichever end it is listed")
	_check(GameDB.club_order == order_before and not GameDB.active_clubs(2030).has(home)
			and not GameDB.players_by_club.has(home) and GameDB.clubs.size() == clubs_before + 2,
			"A side is in no competition and holds no list: it is only a name and a kit")
	var kits: Array = PitchView.kits_for(home, clash)
	var as_away: Array = PitchView.kits_for("FRE", "FRE")
	_check((kits[0]["base"] as Color).is_equal_approx(GameDB.club_guernsey("FRE")["base"])
			and (kits[1]["base"] as Color).is_equal_approx(as_away[1]["base"])
			and (kits[1]["base"] as Color).is_equal_approx(GameDB.club_guernsey("FRE")["pattern"])
			and UiKit.colour_distance(kits[0]["base"], kits[1]["base"]) >= PitchView.DISC_CLASH,
			"The first side wears the club's kit colour and the second the oval's own clash colour for that club, its kit's other colour (no invented colour), and the two read apart")
	_check((kits[0]["pattern"] as Color).is_equal_approx(kits[0]["base"]) and (kits[1]["pattern"] as Color).is_equal_approx(kits[1]["base"]),
			"Each side wears its colour plain, so two sides of a half-and-half kit are never mirror images of each other")
	_check(GameDB.club_guernsey(clash) == kits[1] and GameDB.club_guernsey(home) == kits[0],
			"Each side's kit is its own wherever a kit is asked for (crests, the close-ups)")
	var inks: Array = UiKit.club_ink_pair(home, clash)
	_check(UiKit.club_ink(home).is_equal_approx(UiKit.club_ink("FRE")) and UiKit.club_ink(clash).is_equal_approx(UiKit.club_ink_second("FRE"))
			and (inks[0] as Color).is_equal_approx(UiKit.club_ink("FRE")) and (inks[1] as Color).is_equal_approx(UiKit.club_ink_second("FRE")),
			"On the scoreboard and the stats Fremantle Purple is in the club's purple ink and Fremantle White in its white")
	GameDB.register_sides("MEL")
	var mel: Array = PitchView.kits_for("MEL_H", "MEL_A")
	_check(GameDB.club_name("MEL_H") == "Melbourne Navy" and GameDB.club_name("MEL_A") == "Melbourne Red"
			and (mel[1]["base"] as Color).is_equal_approx(GameDB.club_guernsey("MEL")["pattern"])
			and UiKit.club_ink("MEL_A").is_equal_approx(UiKit.club_ink("MEL"))
			and UiKit.club_ink("MEL_H").is_equal_approx(UiKit.club_ink_second("MEL")),
			"Melbourne Navy is in the club's blue ink and Melbourne Red in its red: each side's ink is the colour of the strip it wears")
	GameDB.register_sides("RIC")
	var ric: Array = UiKit.club_ink_pair("RIC_H", "RIC_A")
	_check(GameDB.club_name("RIC_H") == "Richmond Black" and GameDB.club_name("RIC_A") == "Richmond Yellow"
			and (ric[0] as Color).s < 0.1 and UiKit.contrast(ric[0], UiKit.PANEL) >= 4.5
			and (ric[1] as Color).is_equal_approx(UiKit.club_ink("RIC")),
			"Richmond Black is in a readable grey (no hue invented for black) and Richmond Yellow in the club's yellow")
	_check(_look_of_every_club() == before, "With the two sides registered, every real club and every real pair looks exactly as before")
	var pv := PitchView.new()
	pv.size = Vector2(370, 490)
	var res := _sim(31, "FRE", "FRE").run()
	res["home"] = home
	res["away"] = clash
	pv.setup(res)
	_check(pv._kits[0] == kits[0] and pv._kits[1] == kits[1] and pv.clash,
			"The oval draws the two sides in the home strip and the clash strip")
	pv.free()
	# Every club has two named strips, and a created club falls back to plain words.
	var named := true
	var worn := []
	for c in GameDB.CLUB_ORDER:
		var two: Array = GameDB.register_sides(str(c))
		var k: Array = PitchView.kits_for(str(two[0]), str(two[1]))
		named = named and GameDB.SIDE_COLOUR_NAMES.has(str(c)) and GameDB.club_short(str(two[0])) != GameDB.club_short(str(two[1])) \
				and GameDB.club_name(str(two[0])).begins_with(GameDB.club_name(str(c)) + " ")
		var two_inks: Array = UiKit.club_ink_pair(str(two[0]), str(two[1]))
		if UiKit.colour_distance(k[0]["base"], k[1]["base"]) < PitchView.DISC_CLASH \
				or (two_inks[0] as Color).is_equal_approx(two_inks[1]) \
				or UiKit.contrast(two_inks[0], UiKit.PANEL) < 4.5 or UiKit.contrast(two_inks[1], UiKit.PANEL) < 4.5:
			worn.append(str(c))
		var own: Array = [GameDB.club_colours(str(c))[0], GameDB.club_colours(str(c))[1], GameDB.club_colours(str(c))[2],
				GameDB.club_guernsey(str(c))["base"], GameDB.club_guernsey(str(c))["pattern"]]
		var is_own := false
		for col in own:
			is_own = is_own or (k[1]["base"] as Color).is_equal_approx(col)
		named = named and is_own
	_check(named and worn.is_empty(), "Every club has two strips with their own colour names, the second strip is always one of the club's own colours, and no club's two sides look alike on the oval or the scoreboard (%s)" % ", ".join(worn))
	GameDB.unregister_sides()
	_check(GameDB.clubs.size() == clubs_before and not GameDB.is_side(home) and GameDB.club_name(home) == home
			and _look_of_every_club() == before,
			"Taken out again, nothing of the sides is left and every club looks as it did")
	var again := _sim(77, "FRE", "MEL").run()
	_check(again["score"] == plain["score"] and again["goals"] == plain["goals"] and again["behinds"] == plain["behinds"]
			and (again["events"] as Array).size() == (plain["events"] as Array).size()
			and str(again["players"]) == str(plain["players"]),
			"A club-v-club match on the same seed plays out identically after sides have come and gone")
	GameState.my_club = ""


## The bench strip: five a side, inside the view, and an interchange swaps the
## man coming on for the man going off, when the oval shows it.
func _test_bench_strip() -> void:
	var res := _sim(31, "FRE", "MEL").run()
	res["home"] = "FRE"
	res["away"] = "MEL"
	_check((res["bench"] as Array).size() == 2 and (res["bench"][0] as Array).size() == 5
			and (res["bench"][1] as Array).size() == 5, "A match says who started on each bench: five a side")
	for view in [[Vector2(370, 490), true, "phone"], [Vector2(900, 590), false, "PC"]]:
		var pv := PitchView.new()
		pv.size = view[0]
		pv.camera_enabled = view[1]
		pv.setup(res)
		var spots := pv.bench_spots(pv.token_radius())
		var per := [0, 0]
		var inside := true
		for sp in spots:
			per[int(sp["side"])] += 1
			var p: Vector2 = sp["pos"]
			var r: float = sp["r"]
			if p.x - r < 0.0 or p.y - r < 0.0 or p.x + r > pv.size.x or p.y + r > pv.size.y:
				inside = false
		_check(per == [5, 5] and inside, "%s: five bench discs a side, all inside the view (%s)" % [str(view[2]), str(per)])
		if str(view[2]) == "PC":
			_check(bool(spots[0]["column"]), "PC: the bench runs down the sides of the ground, using the width")
			var a := MatchMotion.HALF_LEN * pv._scale()
			var clear := true
			for sp in spots:
				if absf((sp["pos"] as Vector2).x - pv.size.x * 0.5) < a + float(sp["r"]):
					clear = false
			_check(clear, "PC: no bench disc sits on the ground")
		else:
			_check(not bool(spots[0]["column"]), "Phone: the bench runs along the bottom of the view")
			var ground_bottom: float = pv.size.y * 0.5 + MatchMotion.HALF_WID * pv.pitch_rect().size.x / (2.0 * MatchMotion.HALF_LEN) * 1.5
			_check((spots[0]["pos"] as Vector2).y - float(spots[0]["r"]) > ground_bottom,
					"Phone: the bench sits below the oval at its closest zoom, in the stand's band")
		pv.free()
	# Rotations: at every interchange the bench stays five, the man on leaves it
	# and the man off joins it, and nobody is on the ground and the bench at once.
	var pv3 := PitchView.new()
	pv3.size = Vector2(370, 490)
	var wrong := []
	var subs := [0]
	pv3.event_played.connect(func(ev):
		if str(ev.get("kind", "")) != "sub":
			return
		subs[0] += 1
		var side := int(ev["side"])
		var nums := []
		for b in pv3.director.bench[side]:
			nums.append(int(b["num"]))
		var on_ground := []
		for t in pv3.director.tokens:
			if int(t["side"]) == side:
				on_ground.append(int(t["num"]))
		var both := nums.filter(func(n): return on_ground.has(n))
		if nums.size() != 5 or nums.has(int(ev["num"])) or not nums.has(int(ev["off_num"])) or not both.is_empty():
			wrong.append("event %d" % pv3.current_index()))
	pv3.setup(res)
	var opening := []
	for b in pv3.director.bench[0]:
		opening.append(int(b["num"]))
	pv3.set_speed(8.0)
	pv3.play()
	var guard := 0
	while pv3.playing and guard < 200000:
		guard += 1
		pv3._process(1.0 / 30.0)
	var closing := []
	for b in pv3.director.bench[0]:
		closing.append(int(b["num"]))
	_check(subs[0] > 0 and wrong.is_empty(), "Every interchange swaps one man on the bench strip (%d interchanges; wrong at %s)" % [
			subs[0], ", ".join(wrong.slice(0, 5))])
	_check(opening != closing, "The bench changes as the match rotates")
	pv3.free()
	var old := res.duplicate()
	old.erase("bench")
	var pv4 := PitchView.new()
	pv4.size = Vector2(370, 490)
	pv4.setup(old)
	_check(pv4.bench_spots(pv4.token_radius()).is_empty(), "An old result with no bench shows no strip, and plays")
	pv4.free()


## The sides change ends when the next quarter restarts, not at the siren, and
## never after the last one; the match itself is the same watched or not.
func _test_ends_change_at_restart(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(370, 490)
	var at_siren := []
	var changes := []
	pv.ends_changed.connect(func(p): changes.append(p))
	pv.event_played.connect(func(ev):
		if str(ev.get("kind", "")) == "quarter":
			at_siren.append([int(ev.get("q", 0)), pv.period]))
	var copy: Array = (res["events"] as Array).duplicate(true)
	pv.setup(res)
	pv.set_speed(8.0)
	pv.play()
	var guard := 0
	while pv.playing and guard < 200000:
		guard += 1
		pv._process(1.0 / 30.0)
	var held := true
	for row in at_siren:
		if int(row[1]) != int(row[0]):
			held = false
	_check(at_siren.size() >= 3 and held, "At each siren the ground still shows the quarter just played (%s)" % str(at_siren))
	_check(changes == [2, 3, 4] and pv.period == 4, "Ends change three times, at each restart, and not after the final siren (%s)" % str(changes))
	_check(res["events"] == copy, "Watching the match changes nothing in it")
	var again := _result(42)
	_check(again["score"] == res["score"] and again["goals"] == res["goals"] and again["behinds"] == res["behinds"]
			and (again["events"] as Array).size() == (res["events"] as Array).size(),
			"The same seed gives the same score and the same match after one has been watched")
	# Skipped, not watched: the same ends.
	var pv2 := PitchView.new()
	pv2.size = Vector2(370, 490)
	pv2.setup(res)
	pv2.skip_to_end()
	_check(pv2.period == 4, "A skipped match ends at the fourth quarter's ends (%d)" % pv2.period)
	pv.free()
	pv2.free()


## The oval upright (a phone held upright): the same picture as the ground lying
## flat, turned a quarter turn, the whole ground in view, the home side kicking
## up the screen first and down it after the change of ends, the bench clear of
## the turf, and a point on a disc finding that player, upright and flat.
func _test_upright_oval(res: Dictionary) -> void:
	var up := PitchView.new()
	up.size = Vector2(370, 490)
	up.camera_enabled = false
	up.upright = true
	var flat := PitchView.new()
	flat.size = Vector2(490, 370)
	flat.camera_enabled = false
	var turn := func(q: Vector2) -> Vector2:
		var v := q - flat.size * 0.5
		return up.size * 0.5 + Vector2(v.y, -v.x)
	var ends := []
	up.ends_changed.connect(func(_p): ends.append(up._w2s(Vector2(MatchMotion.GOAL_X, 0.0)).y < up.size.y * 0.5))
	up.setup(res)
	flat.setup(res)
	var gr: Rect2 = up.pitch_rect()
	_check(Rect2(Vector2.ZERO, up.size).encloses(gr) and gr.size.y > gr.size.x * 1.2
			and is_equal_approx(gr.size.x, flat.pitch_rect().size.y) and is_equal_approx(gr.size.y, flat.pitch_rect().size.x),
			"Upright, the whole ground is in view and runs top to bottom (%s)" % str(gr))
	var home_goal: Vector2 = up._w2s(Vector2(MatchMotion.GOAL_X, 0.0))
	_check(home_goal.y < up.size.y * 0.5 and absf(home_goal.x - up.size.x * 0.5) < 0.5,
			"In the first quarter the home side kicks up the screen, the goal on the centre line")
	up.set_speed(8.0)
	flat.set_speed(8.0)
	up.play()
	flat.play()
	var worst := 0.0
	var ball_worst := 0.0
	var wrong_hit := 0
	var carrier_missed := 0
	var guard := 0
	while up.playing and guard < 200000:
		guard += 1
		up._process(1.0 / 30.0)
		flat._process(1.0 / 30.0)
		if guard % 5 != 0:
			continue
		for i in range(up.director.tokens.size()):
			var a2: Vector2 = up._w2s(up.director.tokens[i]["pos"])
			var b2: Vector2 = turn.call(flat._w2s(flat.director.tokens[i]["pos"]))
			worst = maxf(worst, a2.distance_to(b2))
		ball_worst = maxf(ball_worst, up._w2s(up.director.ball["pos"]).distance_to(turn.call(flat._w2s(flat.director.ball["pos"]))))
		if guard % 50 != 0:
			continue
		for pv in [up, flat]:
			var drawn: PackedVector2Array = pv.disc_positions()
			var tr: float = pv.token_radius()
			for i in range(drawn.size()):
				var hit: int = pv.disc_at_point(drawn[i])
				if hit < 0 or drawn[hit].distance_to(drawn[i]) > tr * 1.25:
					wrong_hit += 1
			var holder := int(pv.director.ball.get("holder", -1))
			if holder >= 0 and pv.disc_at_point(drawn[holder]) != holder:
				carrier_missed += 1
	_check(not up.playing and worst < 0.01 and ball_worst < 0.01,
			"Every player and the ball are in the same place upright as flat, turned (%.3f px, ball %.3f px)" % [worst, ball_worst])
	_check(ends == [false, true, false], "Upright, the home side kicks down, up, then down the screen after each change of ends (%s)" % str(ends))
	_check(wrong_hit == 0, "A point on a disc finds a player drawn there, upright and flat (%d misses)" % wrong_hit)
	_check(carrier_missed == 0, "A point on the ball carrier's disc finds him, upright and flat (%d misses)" % carrier_missed)
	up.free()
	flat.free()
	# The bench, upright: five a side in the bottom corners, inside the view, off the turf.
	var bres := _sim(31, "FRE", "MEL").run()
	bres["home"] = "FRE"
	bres["away"] = "MEL"
	var pv2 := PitchView.new()
	pv2.size = Vector2(370, 490)
	pv2.camera_enabled = false
	pv2.upright = true
	pv2.setup(bres)
	var spots := pv2.bench_spots(pv2.token_radius())
	var s := pv2._scale()
	var on_turf := 0
	var outside := 0
	for sp in spots:
		var q: Vector2 = (sp["pos"] as Vector2) - pv2.size * 0.5
		var r: float = sp["r"]
		var ex := (absf(q.x) - r) / (MatchMotion.HALF_WID * s)
		var ey := (absf(q.y) - r) / (MatchMotion.HALF_LEN * s)
		if ex * ex + ey * ey < 1.0:
			on_turf += 1
		var at: Vector2 = sp["pos"]
		if at.x - r < 0.0 or at.y - r < 0.0 or at.x + r > pv2.size.x or at.y + r > pv2.size.y:
			outside += 1
	_check(spots.size() == 10 and on_turf == 0 and outside == 0,
			"Upright, the bench's ten discs sit in the view and off the turf (%d, %d on the turf, %d outside)" % [spots.size(), on_turf, outside])
	_check(absf(float(spots[0]["r"]) - pv2.token_radius()) < 0.5, "Upright, a bench disc is as big as a player's on the ground")
	# A goal's ring at either end: never past the view's edge, never over the bench.
	var bad := []
	for gx in [MatchMotion.GOAL_X, -MatchMotion.GOAL_X]:
		var at: Vector2 = pv2._w2s(Vector2(gx, 0.0))
		var biggest := minf(MatchMotion.HALF_LEN * s, MatchMotion.HALF_WID * s) * 0.42
		var r := minf(biggest, pv2.flash_room(at, pv2.token_radius()))
		if at.y - r < 0.0 or at.y + r > pv2.size.y or at.x - r < 0.0 or at.x + r > pv2.size.x:
			bad.append("off the view at %s" % str(at))
		for sp in spots:
			if (sp["pos"] as Vector2).distance_to(at) < r + float(sp["r"]):
				bad.append("over bench disc %d" % int(sp["num"]))
	_check(bad.is_empty(), "Upright, a goal's ring stays in the view and off the bench at both ends (%s)" % ", ".join(bad))
	pv2.free()
