extends RefCounted
## The live match view (PitchView, MatchDirector, MatchMotion) is presentation
## only: these checks hold it to that. Run through
## tests/run_match_visual_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
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
	_test_no_wrong_way_kicks(res)
	_test_match_flow(res)
	_test_boundary_collect(res)
	_test_play_when_idle(res)
	_test_numbers_readable()
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
	scene._track_momentum({"kind": "ballup", "side": -1, "fp": 20.0})
	_check(is_equal_approx(scene._momentum, 0.5), "A ball-up does not move the momentum meter")
	scene._track_momentum({"kind": "kick", "side": 0, "fp": 20.0})
	_check(scene._momentum < 0.5, "Ordinary play still ages the momentum meter")
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
		var last := [Vector2.INF, Vector2.INF]
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
			if from == last[0] and to == last[1]:
				if pv.period != period:
					flipped += 1   # the ends changed with the ball in the air
					period = pv.period
				continue
			last = [from, to]
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
		var k := int(d._beat.get("k", -1))
		if k != beat_k:
			worst = maxf(worst, beat_t)
			beat_k = k
			beat_t = 0.0
		beat_t += h
	pv.free()
	_check(worst <= 8.0, "No moment of a watched match hangs (longest beat %.1f s)" % worst)
	_check(far <= 0.12 * t, "The ball is rarely left waiting on a far-off receiver (%.0f s of %.0f)" % [far, t])


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
